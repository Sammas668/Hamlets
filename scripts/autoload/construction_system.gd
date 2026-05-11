# res://autoloads/ConstructionSystem.gd
extends Node

## ConstructionSystem
##
## Locked Construction design:
## - Construction Materials recipes craft boxed kits from logs, stone, and Smithing hardware.
## - Building base tiers consume only construction kits.
## - Module installs consume only construction kits.
## - No timber-processing pattern remapping.
## - No cut_log / cut_stone material tier resolver.
## - Base buildings expose one recipe per tier: "<base_id>:t1", "<base_id>:t2", "<base_id>:t3".
##
## Expected data:
##
## construction_materials.json
## {
##   "fastener_kit_t1": {
##     "id": "fastener_kit_t1",
##     "building": "Construction Materials",
##     "skill": "construction",
##     "kind": "material",
##     "part": "Fastener Kit (T1)",
##     "req_con_lv": 1,
##     "struct": { "log_pine": 1 },
##     "hardware": { "nails": 40, "rivets": 8 }
##   }
## }
##
## buildings.json
## {
##   "hearth_kitchen_base": {
##     "kind": "base",
##     "building": "Hearth Kitchen",
##     "skill": "cooking",
##     "tiers": {
##       "1": {
##         "level_req": 10,
##         "inputs": {
##           "struct": [
##             { "item": "wall_kit_limestone", "qty": 4 },
##             { "item": "floor_kit_limestone", "qty": 3 }
##           ],
##           "hardware": [
##             { "item": "fastener_kit_t1", "qty": 2 },
##             { "item": "fittings_kit_t1", "qty": 1 }
##           ]
##         }
##       }
##     }
##   }
## }
##
## modules.json
## {
##   "hearth_kitchen_oven": {
##     "kind": "module",
##     "building": "Hearth Kitchen",
##     "skill": "cooking",
##     "part": "Oven",
##     "construction_level_req": 20,
##     "req_skill_lv": 1,
##     "struct": { "wall_kit_clay": 1, "floor_kit_clay": 1 },
##     "hardware": { "fastener_kit_t2": 1, "fittings_kit_t2": 1 }
##   }
## }

signal construction_recipes_changed
signal item_constructed(item_id: StringName, count: int)
signal construction_recipe_completed(recipe_id: StringName, output_id: StringName, count: int, recipe: Dictionary)

const BASE_ACTION_TIME := 2.4
const CONSTRUCTION_SKILL_ID := "construction"

const BUILDINGS_JSON_PATH := "res://data/specs/resources/buildings.json"
const MODULES_JSON_PATH := "res://data/specs/resources/modules.json"
const MATERIALS_JSON_PATH := "res://data/specs/resources/construction_materials.json"

const GROUP_BASE := &"building_base"
const GROUP_MODULE := &"building_module"
const GROUP_MATERIAL := &"building_material"

const KIND_BASE := "base"
const KIND_MODULE := "module"
const KIND_MATERIAL := "material"

## If true, base/module recipes warn when they consume anything outside the locked kit list.
## Material recipes are allowed to consume raw logs, raw stone, and smithing parts.
const WARN_ON_NON_KIT_BUILD_INPUTS := true

## Locked kit list:
## 14 general kits + wall/floor kits for each stone tier.
const CONSTRUCTION_KIT_IDS := {
	"fastener_kit_t1": true,
	"fittings_kit_t1": true,
	"fastener_kit_t2": true,
	"fittings_kit_t2": true,
	"fastener_kit_t3": true,
	"fittings_kit_t3": true,
	"reinforcement_kit_t3": true,
	"mechanism_kit_t4": true,
	"security_kit_t5": true,
	"reinforcement_kit_t6": true,
	"fastener_kit_t7": true,
	"fittings_kit_t7": true,
	"mechanism_kit_t8": true,
	"security_kit_t9": true,

	"wall_kit_limestone": true,
	"floor_kit_limestone": true,
	"wall_kit_sandstone": true,
	"floor_kit_sandstone": true,
	"wall_kit_basalt": true,
	"floor_kit_basalt": true,
	"wall_kit_granite": true,
	"floor_kit_granite": true,
	"wall_kit_marble": true,
	"floor_kit_marble": true,
	"wall_kit_clay": true,
	"floor_kit_clay": true
}

## Raw loaded blueprints:
## { blueprint_id:String -> blueprint:Dictionary }
var _blueprints: Dictionary = {}

## Built CraftMenu recipes:
## { recipe_id:StringName -> recipe:Dictionary }
var _recipe_cache: Dictionary = {}

## Used to prevent repeated warning spam.
var _warned_messages: Dictionary = {}


func _ready() -> void:
	reload_blueprints()


# -------------------------------------------------------------------
# Loading
# -------------------------------------------------------------------

func reload_blueprints() -> void:
	_blueprints.clear()
	_recipe_cache.clear()
	_warned_messages.clear()

	_load_json_into(_blueprints, BUILDINGS_JSON_PATH)
	_load_json_into(_blueprints, MODULES_JSON_PATH)
	_load_json_into(_blueprints, MATERIALS_JSON_PATH)

	var base_count := 0
	var module_count := 0
	var material_count := 0
	var other_count := 0

	for bp_v in _blueprints.values():
		if typeof(bp_v) != TYPE_DICTIONARY:
			continue

		var bp: Dictionary = bp_v
		var kind := String(bp.get("kind", "")).strip_edges().to_lower()

		match kind:
			KIND_BASE:
				base_count += 1
			KIND_MODULE:
				module_count += 1
			KIND_MATERIAL:
				material_count += 1
			_:
				other_count += 1

	print("[Construction] Loaded %d blueprints (base=%d, module=%d, material=%d, other=%d)" % [
		_blueprints.size(),
		base_count,
		module_count,
		material_count,
		other_count
	])

	emit_signal("construction_recipes_changed")


func _load_json_into(dst: Dictionary, path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("[Construction] JSON file missing: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Construction] Could not open JSON file: %s" % path)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[Construction] Failed to parse %s. Error=%d Line=%d Message=%s" % [
			path,
			err,
			json.get_error_line(),
			json.get_error_message()
		])
		return

	var data_any: Variant = json.data

	if typeof(data_any) == TYPE_DICTIONARY:
		var data_dict: Dictionary = data_any
		for key_v in data_dict.keys():
			var key := String(key_v)
			var entry_v: Variant = data_dict[key_v]

			if typeof(entry_v) != TYPE_DICTIONARY:
				_warn_once("[Construction] Skipping non-dictionary entry '%s' in %s." % [key, path])
				continue

			var entry: Dictionary = entry_v
			var id_str := String(entry.get("id", key)).strip_edges()
			if id_str == "":
				id_str = key

			entry["id"] = id_str
			entry["_source_path"] = path
			dst[id_str] = entry

	elif typeof(data_any) == TYPE_ARRAY:
		var data_arr: Array = data_any
		for i in range(data_arr.size()):
			var entry_v: Variant = data_arr[i]

			if typeof(entry_v) != TYPE_DICTIONARY:
				_warn_once("[Construction] Skipping non-dictionary array entry %d in %s." % [i, path])
				continue

			var entry: Dictionary = entry_v
			var id_str := String(entry.get("id", "")).strip_edges()
			if id_str == "":
				_warn_once("[Construction] Skipping array entry %d in %s because it has no id." % [i, path])
				continue

			entry["_source_path"] = path
			dst[id_str] = entry

	else:
		push_error("[Construction] Root of %s must be a Dictionary or Array." % path)


func _warn_once(message: String) -> void:
	if _warned_messages.has(message):
		return

	_warned_messages[message] = true
	push_warning(message)


# -------------------------------------------------------------------
# Recipe id helpers
# -------------------------------------------------------------------

func _make_tier_recipe_id(base_id: StringName, tier: int) -> StringName:
	if tier <= 0:
		return base_id

	return StringName("%s:t%d" % [String(base_id), tier])


## Supports:
## - "hearth_kitchen_base:t1"
## - "hearth_kitchen_base:1"
## - "hearth_kitchen_base"
func _parse_recipe_id(recipe_id: StringName) -> Dictionary:
	var s := String(recipe_id)
	var base := s
	var tier := 0

	var colon := s.find(":")
	if colon >= 0:
		base = s.substr(0, colon)
		var suffix := s.substr(colon + 1).strip_edges().to_lower()

		if suffix.begins_with("t"):
			suffix = suffix.substr(1)

		var parsed_tier := int(suffix)
		if parsed_tier > 0:
			tier = parsed_tier

	return {
		"base_id": StringName(base),
		"tier": tier
	}


## Backwards compatibility for older callers.
func _parse_tier_from_id(recipe_id: StringName) -> Dictionary:
	var parsed := _parse_recipe_id(recipe_id)
	return {
		"base_id": parsed.get("base_id", recipe_id),
		"forced_tier": int(parsed.get("tier", 0))
	}


func _get_blueprint(id: StringName) -> Dictionary:
	var key := String(id)
	if not _blueprints.has(key):
		return {}

	var bp_v: Variant = _blueprints[key]
	if typeof(bp_v) != TYPE_DICTIONARY:
		return {}

	return bp_v


# -------------------------------------------------------------------
# Tier helpers
# -------------------------------------------------------------------

func _has_tiers(bp: Dictionary) -> bool:
	return typeof(bp.get("tiers", null)) == TYPE_DICTIONARY


func _get_tiers(bp: Dictionary) -> Dictionary:
	var tiers_v: Variant = bp.get("tiers", {})
	if typeof(tiers_v) != TYPE_DICTIONARY:
		return {}

	return tiers_v


func _get_sorted_tier_numbers(bp: Dictionary) -> Array:
	var out: Array = []
	var tiers := _get_tiers(bp)

	for key_v in tiers.keys():
		var n := int(String(key_v))
		if n > 0:
			out.append(n)

	out.sort()
	return out


func _get_primary_tier_index(bp: Dictionary) -> int:
	var tiers := _get_tiers(bp)
	if tiers.is_empty():
		return 0

	if tiers.has("1"):
		return 1

	var sorted := _get_sorted_tier_numbers(bp)
	if sorted.is_empty():
		return 0

	return int(sorted[0])


func _get_tier_data(bp: Dictionary, tier: int) -> Dictionary:
	if tier <= 0:
		tier = _get_primary_tier_index(bp)

	if tier <= 0:
		return {}

	var tiers := _get_tiers(bp)
	var key := str(tier)

	if not tiers.has(key):
		return {}

	var tier_v: Variant = tiers[key]
	if typeof(tier_v) != TYPE_DICTIONARY:
		return {}

	return tier_v


func _get_build_tier_from_recipe_id(recipe_id: StringName, bp: Dictionary) -> int:
	var parsed := _parse_recipe_id(recipe_id)
	var requested_tier := int(parsed.get("tier", 0))

	if requested_tier > 0:
		return requested_tier

	if String(bp.get("kind", "")).strip_edges().to_lower() == KIND_BASE:
		return _get_primary_tier_index(bp)

	return int(bp.get("build_tier", bp.get("tier", 0)))


func _get_module_tier(bp: Dictionary) -> int:
	var value := int(bp.get("module_tier", 0))
	if value > 0:
		return value

	return int(bp.get("min_building_tier", 1))


func _get_mat_tier(bp: Dictionary) -> int:
	var value := int(bp.get("mat_tier", bp.get("tier", 0)))
	if value > 0:
		return value

	return 0


# -------------------------------------------------------------------
# Items / Bank helpers
# -------------------------------------------------------------------

func _ensure_bank_with(methods: Array[StringName]) -> bool:
	if typeof(Bank) == TYPE_NIL:
		push_error("[Construction] Bank autoload missing.")
		return false

	for method_name in methods:
		if not Bank.has_method(method_name):
			push_error("[Construction] Bank is missing method: %s" % String(method_name))
			return false

	return true


func _resolve_item_label(id: StringName) -> String:
	var fallback := String(id)

	if typeof(Items) != TYPE_NIL \
	and Items.has_method("is_valid") \
	and Items.has_method("display_name") \
	and Items.is_valid(id):
		return String(Items.display_name(id))

	return fallback


func _resolve_item_icon_path(id: StringName) -> Variant:
	if typeof(Items) != TYPE_NIL \
	and Items.has_method("is_valid") \
	and Items.has_method("get_icon_path") \
	and Items.is_valid(id):
		return Items.get_icon_path(id)

	return ""


func _is_construction_kit_item(item_id: StringName) -> bool:
	return CONSTRUCTION_KIT_IDS.has(String(item_id))


func is_locked_construction_kit(item_id: StringName) -> bool:
	return _is_construction_kit_item(item_id)


func get_locked_construction_kit_ids() -> Array:
	var out: Array = []
	for key in CONSTRUCTION_KIT_IDS.keys():
		out.append(StringName(String(key)))

	out.sort()
	return out


# -------------------------------------------------------------------
# Input composition
# -------------------------------------------------------------------

func _append_input(inputs: Array, item_id: StringName, qty: int, section: String) -> void:
	if String(item_id) == "" or qty <= 0:
		return

	for i in range(inputs.size()):
		var existing_v: Variant = inputs[i]
		if typeof(existing_v) != TYPE_DICTIONARY:
			continue

		var existing: Dictionary = existing_v
		if StringName(existing.get("item", StringName(""))) == item_id:
			existing["qty"] = int(existing.get("qty", 0)) + qty

			var sections: Array = existing.get("sections", []) as Array
			if not sections.has(section):
				sections.append(section)
			existing["sections"] = sections

			inputs[i] = existing
			return

	inputs.append({
		"item": item_id,
		"qty": qty,
		"sections": [section]
	})


func _append_inputs_from_value(inputs: Array, value: Variant, section: String, require_kits: bool, context_id: String) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var map: Dictionary = value
			for key_v in map.keys():
				var item_id := StringName(String(key_v).strip_edges())
				var qty := int(map[key_v])
				if String(item_id) == "" or qty <= 0:
					continue

				if require_kits and WARN_ON_NON_KIT_BUILD_INPUTS and not _is_construction_kit_item(item_id):
					_warn_once("[Construction] %s uses non-kit input '%s'. Building/module recipes should consume only construction kits." % [
						context_id,
						String(item_id)
					])

				_append_input(inputs, item_id, qty, section)

		TYPE_ARRAY:
			var arr: Array = value
			for entry_v in arr:
				if typeof(entry_v) != TYPE_DICTIONARY:
					continue

				var entry: Dictionary = entry_v
				var item_id := StringName(String(entry.get("item", "")).strip_edges())
				var qty := int(entry.get("qty", 0))
				if String(item_id) == "" or qty <= 0:
					continue

				if require_kits and WARN_ON_NON_KIT_BUILD_INPUTS and not _is_construction_kit_item(item_id):
					_warn_once("[Construction] %s uses non-kit input '%s'. Building/module recipes should consume only construction kits." % [
						context_id,
						String(item_id)
					])

				_append_input(inputs, item_id, qty, section)

		_:
			return


func _compose_inputs_for_base_tier(bp_id: StringName, bp: Dictionary, tier: int) -> Array:
	var inputs: Array = []
	var tier_data := _get_tier_data(bp, tier)

	if tier_data.is_empty():
		return inputs

	var inputs_block_v: Variant = tier_data.get("inputs", {})
	if typeof(inputs_block_v) != TYPE_DICTIONARY:
		_warn_once("[Construction] Base recipe %s:t%d has no valid inputs block." % [String(bp_id), tier])
		return inputs

	var inputs_block: Dictionary = inputs_block_v
	var context_id := "%s:t%d" % [String(bp_id), tier]

	_append_inputs_from_value(inputs, inputs_block.get("struct", []), "struct", true, context_id)
	_append_inputs_from_value(inputs, inputs_block.get("hardware", []), "hardware", true, context_id)

	return inputs


func _compose_inputs_for_flat_blueprint(bp_id: StringName, bp: Dictionary, require_kits: bool) -> Array:
	var inputs: Array = []
	var context_id := String(bp_id)

	_append_inputs_from_value(inputs, bp.get("struct", {}), "struct", require_kits, context_id)
	_append_inputs_from_value(inputs, bp.get("hardware", {}), "hardware", require_kits, context_id)
	_append_inputs_from_value(inputs, bp.get("inputs", {}), "inputs", require_kits, context_id)

	return inputs


func _compose_inputs_for_recipe(recipe_id: StringName, bp: Dictionary) -> Array:
	var kind := String(bp.get("kind", "")).strip_edges().to_lower()
	var parsed := _parse_recipe_id(recipe_id)
	var bp_id: StringName = parsed.get("base_id", recipe_id)

	match kind:
		KIND_BASE:
			var tier := _get_build_tier_from_recipe_id(recipe_id, bp)
			return _compose_inputs_for_base_tier(bp_id, bp, tier)

		KIND_MODULE:
			return _compose_inputs_for_flat_blueprint(bp_id, bp, true)

		KIND_MATERIAL:
			return _compose_inputs_for_flat_blueprint(bp_id, bp, false)

		_:
			return _compose_inputs_for_flat_blueprint(bp_id, bp, false)


## Backwards compatibility for old callers.
func _compose_inputs(bp: Dictionary) -> Array:
	var id := StringName(String(bp.get("id", "")))
	if String(id) == "":
		return []

	return _compose_inputs_for_recipe(id, bp)


# -------------------------------------------------------------------
# Recipe metadata
# -------------------------------------------------------------------

func _kind_to_group(kind: String) -> StringName:
	var clean := kind.strip_edges().to_lower()

	match clean:
		KIND_BASE, "building_base":
			return GROUP_BASE
		KIND_MODULE, "building_module":
			return GROUP_MODULE
		KIND_MATERIAL, "building_material":
			return GROUP_MATERIAL
		_:
			return StringName("")


func _default_xp_for(inputs: Array, level_req: int, kind: String) -> int:
	var total_qty: int = 0

	for input_v in inputs:
		if typeof(input_v) != TYPE_DICTIONARY:
			continue

		var input: Dictionary = input_v
		total_qty += int(input.get("qty", 0))

	if total_qty <= 0:
		return max(1, level_req)

	var kind_mult: float = 1.0
	match kind:
		KIND_BASE:
			kind_mult = 2.0
		KIND_MODULE:
			kind_mult = 1.25
		KIND_MATERIAL:
			kind_mult = 0.65
		_:
			kind_mult = 1.0

	var level_factor: float = maxf(1.0, float(level_req) * 0.12)
	var xp_f: float = float(total_qty) * level_factor * kind_mult

	return max(1, int(round(xp_f)))


func _get_construction_level_req_for_flat(bp: Dictionary) -> int:
	if bp.has("construction_level_req"):
		return int(bp.get("construction_level_req", 1))

	return int(bp.get("req_con_lv", 1))


func _get_output_qty(bp: Dictionary) -> int:
	var qty := int(bp.get("output_qty", bp.get("count", bp.get("qty_out", 1))))
	return max(1, qty)


func _build_base_recipe(recipe_id: StringName, bp_id: StringName, bp: Dictionary) -> Dictionary:
	var build_tier := _get_build_tier_from_recipe_id(recipe_id, bp)
	if build_tier <= 0:
		return {}

	var tier_data := _get_tier_data(bp, build_tier)
	if tier_data.is_empty():
		return {}

	var building_name := String(bp.get("building", String(bp_id)))
	var linked_skill := String(bp.get("skill", ""))
	var attr := String(bp.get("attr", ""))

	var label := String(tier_data.get("label", bp.get("label", building_name)))
	var desc := String(tier_data.get("desc", ""))
	var level_req := int(tier_data.get("level_req", bp.get("construction_level_req", bp.get("req_con_lv", 1))))

	var inputs := _compose_inputs_for_base_tier(bp_id, bp, build_tier)
	var xp_gain := int(tier_data.get("xp", bp.get("xp", _default_xp_for(inputs, level_req, KIND_BASE))))

	var output_id := StringName(String(bp.get("output_id", String(bp_id))))

	var rec := {
		"id": recipe_id,
		"base_id": bp_id,
		"output_id": output_id,
		"output_qty": _get_output_qty(bp),

		"label": label,
		"desc": desc,
		"effect_raw": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"icon": _resolve_item_icon_path(output_id),
		"inputs": inputs,
		"group": GROUP_BASE,

		"building": building_name,
		"linked_skill": linked_skill,
		"skill": linked_skill,
		"attr": attr,
		"kind": KIND_BASE,
		"part": "BASE",
		"role": String(bp.get("role", "Base")),

		"build_tier": build_tier,
		"module_tier": 0,
		"mat_tier": 0,
		"min_building_tier": build_tier,
		"delta_lv": 0,

		"req_skill_lv": int(bp.get("req_skill_lv", 0)),
		"construction_level_req": level_req,

		"tier_min": 1,
		"tier_max": max(1, _get_sorted_tier_numbers(bp).size()),
		"tier_default": build_tier,
		"is_pattern": false,
		"is_install_recipe": true
	}

	return rec


func _build_module_recipe(recipe_id: StringName, bp_id: StringName, bp: Dictionary) -> Dictionary:
	var building_name := String(bp.get("building", String(bp_id)))
	var linked_skill := String(bp.get("skill", ""))
	var part := String(bp.get("part", "")).strip_edges()
	var role := String(bp.get("role", ""))
	var label := "%s – %s" % [building_name, part] if part != "" else building_name
	var desc := String(bp.get("effect", bp.get("desc", "")))

	var level_req := _get_construction_level_req_for_flat(bp)
	var inputs := _compose_inputs_for_flat_blueprint(bp_id, bp, true)
	var xp_gain := int(bp.get("xp", _default_xp_for(inputs, level_req, KIND_MODULE)))

	var output_id := StringName(String(bp.get("output_id", String(bp_id))))

	var rec := {
		"id": recipe_id,
		"base_id": bp_id,
		"output_id": output_id,
		"output_qty": _get_output_qty(bp),

		"label": label,
		"desc": desc,
		"effect_raw": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"icon": _resolve_item_icon_path(output_id),
		"inputs": inputs,
		"group": GROUP_MODULE,

		"building": building_name,
		"linked_skill": linked_skill,
		"skill": linked_skill,
		"kind": KIND_MODULE,
		"part": part,
		"role": role,

		"build_tier": 0,
		"module_tier": _get_module_tier(bp),
		"mat_tier": _get_mat_tier(bp),
		"min_building_tier": int(bp.get("min_building_tier", 1)),
		"delta_lv": int(bp.get("delta_lv", 0)),

		"req_skill_lv": int(bp.get("req_skill_lv", 0)),
		"construction_level_req": level_req,
		"install_profile": String(bp.get("install_profile", "")),
		"effects": bp.get("effects", {}),

		"tier_min": 0,
		"tier_max": 0,
		"tier_default": 0,
		"is_pattern": false,
		"is_install_recipe": true
	}

	return rec


func _build_material_recipe(recipe_id: StringName, bp_id: StringName, bp: Dictionary) -> Dictionary:
	var output_id := StringName(String(bp.get("output_id", bp.get("item", String(bp_id)))))
	var building_name := String(bp.get("building", "Construction Materials"))
	var linked_skill := String(bp.get("skill", CONSTRUCTION_SKILL_ID))
	var part := String(bp.get("part", "")).strip_edges()

	var label := part
	if label == "":
		label = String(bp.get("label", ""))
	if label == "":
		label = _resolve_item_label(output_id)

	var desc := String(bp.get("effect", bp.get("desc", "")))
	var level_req := _get_construction_level_req_for_flat(bp)
	var inputs := _compose_inputs_for_flat_blueprint(bp_id, bp, false)
	var xp_gain := int(bp.get("xp", _default_xp_for(inputs, level_req, KIND_MATERIAL)))

	var rec := {
		"id": recipe_id,
		"base_id": bp_id,
		"output_id": output_id,
		"output_qty": _get_output_qty(bp),

		"label": label,
		"desc": desc,
		"effect_raw": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"icon": _resolve_item_icon_path(output_id),
		"inputs": inputs,
		"group": GROUP_MATERIAL,

		"building": building_name,
		"linked_skill": linked_skill,
		"skill": linked_skill,
		"kind": KIND_MATERIAL,
		"part": part,
		"role": String(bp.get("role", "Construction Kit")),

		"build_tier": 0,
		"module_tier": 0,
		"mat_tier": _get_mat_tier(bp),
		"min_building_tier": int(bp.get("min_building_tier", 1)),
		"delta_lv": int(bp.get("delta_lv", 0)),

		"req_skill_lv": int(bp.get("req_skill_lv", 0)),
		"construction_level_req": level_req,

		"tier_min": 0,
		"tier_max": 0,
		"tier_default": 0,
		"is_pattern": false,
		"is_install_recipe": false
	}

	if WARN_ON_NON_KIT_BUILD_INPUTS and not _is_construction_kit_item(output_id):
		_warn_once("[Construction] Material recipe '%s' outputs '%s', which is not in the locked construction kit list." % [
			String(bp_id),
			String(output_id)
		])

	return rec


func _build_fallback_recipe(recipe_id: StringName, bp_id: StringName, bp: Dictionary) -> Dictionary:
	var kind := String(bp.get("kind", "")).strip_edges().to_lower()
	var output_id := StringName(String(bp.get("output_id", String(bp_id))))
	var building_name := String(bp.get("building", String(bp_id)))
	var part := String(bp.get("part", "")).strip_edges()
	var label := String(bp.get("label", ""))

	if label == "":
		label = "%s – %s" % [building_name, part] if part != "" else building_name

	var desc := String(bp.get("effect", bp.get("desc", "")))
	var level_req := _get_construction_level_req_for_flat(bp)
	var inputs := _compose_inputs_for_flat_blueprint(bp_id, bp, false)
	var xp_gain := int(bp.get("xp", _default_xp_for(inputs, level_req, kind)))

	return {
		"id": recipe_id,
		"base_id": bp_id,
		"output_id": output_id,
		"output_qty": _get_output_qty(bp),

		"label": label,
		"desc": desc,
		"effect_raw": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"icon": _resolve_item_icon_path(output_id),
		"inputs": inputs,
		"group": _kind_to_group(kind),

		"building": building_name,
		"linked_skill": String(bp.get("skill", "")),
		"skill": String(bp.get("skill", "")),
		"kind": kind,
		"part": part,
		"role": String(bp.get("role", "")),

		"build_tier": _get_build_tier_from_recipe_id(recipe_id, bp),
		"module_tier": _get_module_tier(bp),
		"mat_tier": _get_mat_tier(bp),
		"min_building_tier": int(bp.get("min_building_tier", 1)),
		"delta_lv": int(bp.get("delta_lv", 0)),
		"req_skill_lv": int(bp.get("req_skill_lv", 0)),
		"construction_level_req": level_req,

		"tier_min": 0,
		"tier_max": 0,
		"tier_default": 0,
		"is_pattern": false,
		"is_install_recipe": false
	}


func _build_recipe_for(recipe_id: StringName) -> Dictionary:
	if _recipe_cache.has(recipe_id):
		return _recipe_cache[recipe_id]

	var parsed := _parse_recipe_id(recipe_id)
	var bp_id: StringName = parsed.get("base_id", recipe_id)

	var bp := _get_blueprint(bp_id)
	if bp.is_empty():
		return {}

	var kind := String(bp.get("kind", "")).strip_edges().to_lower()

	var rec: Dictionary = {}
	match kind:
		KIND_BASE:
			rec = _build_base_recipe(recipe_id, bp_id, bp)
		KIND_MODULE:
			rec = _build_module_recipe(recipe_id, bp_id, bp)
		KIND_MATERIAL:
			rec = _build_material_recipe(recipe_id, bp_id, bp)
		_:
			rec = _build_fallback_recipe(recipe_id, bp_id, bp)

	if rec.is_empty():
		return {}

	_recipe_cache[recipe_id] = rec
	return rec


# -------------------------------------------------------------------
# Public recipe queries
# -------------------------------------------------------------------

func get_all_recipes() -> Array:
	var out: Array = []

	for key_v in _blueprints.keys():
		var bp_id := StringName(String(key_v))
		var bp := _get_blueprint(bp_id)
		if bp.is_empty():
			continue

		var kind := String(bp.get("kind", "")).strip_edges().to_lower()

		if kind == KIND_BASE and _has_tiers(bp):
			for tier_v in _get_sorted_tier_numbers(bp):
				var tier := int(tier_v)
				var recipe_id := _make_tier_recipe_id(bp_id, tier)
				var rec := _build_recipe_for(recipe_id)
				if not rec.is_empty():
					out.append(rec)
		else:
			var rec := _build_recipe_for(bp_id)
			if not rec.is_empty():
				out.append(rec)

	return out


func get_recipes_for_level(con_lv: int) -> Array:
	var out: Array = []

	for rec_v in get_all_recipes():
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue

		var rec: Dictionary = rec_v
		var level_req := int(rec.get("level_req", rec.get("construction_level_req", 1)))

		if level_req <= con_lv:
			out.append(rec)

	return out


func get_recipes_for_level_and_kind(con_lv: int, kind: String) -> Array:
	var desired_group := _kind_to_group(kind)
	if desired_group == StringName(""):
		return get_recipes_for_level(con_lv)

	var out: Array = []

	for rec_v in get_recipes_for_level(con_lv):
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue

		var rec: Dictionary = rec_v
		if StringName(rec.get("group", StringName(""))) == desired_group:
			out.append(rec)

	return out


func get_recipes_for_building(con_lv: int, building_name: String) -> Array:
	var out: Array = []

	for rec_v in get_recipes_for_level(con_lv):
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue

		var rec: Dictionary = rec_v
		if String(rec.get("building", "")) == building_name:
			out.append(rec)

	return out


func get_material_recipes_for_level(con_lv: int) -> Array:
	return get_recipes_for_level_and_kind(con_lv, KIND_MATERIAL)


func get_module_recipes_for_level(con_lv: int) -> Array:
	return get_recipes_for_level_and_kind(con_lv, KIND_MODULE)


func get_base_recipes_for_level(con_lv: int) -> Array:
	return get_recipes_for_level_and_kind(con_lv, KIND_BASE)


func get_recipe_by_id(recipe_id: StringName) -> Dictionary:
	return _build_recipe_for(recipe_id)


func has_recipe(recipe_id: StringName) -> bool:
	return not _build_recipe_for(recipe_id).is_empty()


func has_part(id: String) -> bool:
	var parsed := _parse_recipe_id(StringName(id))
	var bp_id: StringName = parsed.get("base_id", StringName(id))
	var tier := int(parsed.get("tier", 0))

	if not _blueprints.has(String(bp_id)):
		return false

	if tier <= 0:
		return true

	var bp := _get_blueprint(bp_id)
	if bp.is_empty():
		return false

	return not _get_tier_data(bp, tier).is_empty()


func get_part_display_name(id: String) -> String:
	var recipe := _build_recipe_for(StringName(id))
	if not recipe.is_empty():
		return String(recipe.get("label", id))

	var parsed := _parse_recipe_id(StringName(id))
	var bp_id: StringName = parsed.get("base_id", StringName(id))
	var bp := _get_blueprint(bp_id)

	if bp.is_empty():
		return id

	var building_name := String(bp.get("building", id))
	var part := String(bp.get("part", "")).strip_edges()

	if part == "":
		return building_name

	if part == "BASE":
		return "%s (Base)" % building_name

	return "%s – %s" % [building_name, part]


func get_action_time(_recipe_id: StringName = StringName("")) -> float:
	return BASE_ACTION_TIME


# -------------------------------------------------------------------
# Affordability / missing inputs
# -------------------------------------------------------------------

func get_missing_inputs(recipe_id: StringName) -> Array:
	var missing: Array = []

	if not _ensure_bank_with([&"amount"]):
		return missing

	var rec := _build_recipe_for(recipe_id)
	if rec.is_empty():
		return missing

	var inputs: Array = rec.get("inputs", []) as Array

	for input_v in inputs:
		if typeof(input_v) != TYPE_DICTIONARY:
			continue

		var input: Dictionary = input_v
		var item_id := StringName(input.get("item", StringName("")))
		var need := int(input.get("qty", 0))
		if String(item_id) == "" or need <= 0:
			continue

		var have := int(Bank.amount(item_id))
		if have < need:
			missing.append({
				"item": item_id,
				"need": need,
				"have": have,
				"missing": need - have,
				"label": _resolve_item_label(item_id)
			})

	return missing


func can_construct(recipe_id: StringName) -> bool:
	if _build_recipe_for(recipe_id).is_empty():
		return false

	return get_missing_inputs(recipe_id).is_empty()


func describe_missing_inputs(recipe_id: StringName) -> String:
	var missing := get_missing_inputs(recipe_id)
	if missing.is_empty():
		return ""

	var parts: Array[String] = []
	for entry_v in missing:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_v
		parts.append("%s %d/%d" % [
			String(entry.get("label", entry.get("item", ""))),
			int(entry.get("have", 0)),
			int(entry.get("need", 0))
		])

	return ", ".join(parts)


# -------------------------------------------------------------------
# Job entrypoint – used by VillagerManager
# -------------------------------------------------------------------

func do_construction_work(recipe_id: StringName) -> Dictionary:
	var result := {
		"ok": false,
		"xp": 0,
		"loot_desc": "",
		"recipe_id": recipe_id,
		"output_id": StringName(""),
		"output_count": 0
	}

	if String(recipe_id) == "":
		result["loot_desc"] = "No construction recipe selected."
		return result

	if not _ensure_bank_with([&"amount", &"take", &"add"]):
		result["loot_desc"] = "Bank API missing required methods."
		return result

	var rec := _build_recipe_for(recipe_id)
	if rec.is_empty():
		result["loot_desc"] = "Unknown construction recipe."
		return result

	var inputs: Array = rec.get("inputs", []) as Array
	var label := String(rec.get("label", String(recipe_id)))

	if inputs.is_empty():
		result["loot_desc"] = "Construction recipe %s has no inputs." % label
		return result

	var missing := get_missing_inputs(recipe_id)
	if not missing.is_empty():
		result["loot_desc"] = "Not enough materials to construct %s. Missing: %s." % [
			label,
			describe_missing_inputs(recipe_id)
		]
		return result

	for input_v in inputs:
		if typeof(input_v) != TYPE_DICTIONARY:
			continue

		var input: Dictionary = input_v
		var item_id := StringName(input.get("item", StringName("")))
		var qty := int(input.get("qty", 0))

		if String(item_id) == "" or qty <= 0:
			continue

		Bank.take(item_id, qty)

	var output_id := StringName(rec.get("output_id", recipe_id))
	var output_qty := int(rec.get("output_qty", 1))
	if output_qty <= 0:
		output_qty = 1

	Bank.add(output_id, output_qty)

	var xp_gain := int(rec.get("xp", 0))
	if xp_gain < 0:
		xp_gain = 0

	result["ok"] = true
	result["xp"] = xp_gain
	result["output_id"] = output_id
	result["output_count"] = output_qty

	var kind := String(rec.get("kind", "")).strip_edges().to_lower()
	var final_label := label

	if kind == KIND_MATERIAL:
		final_label = _resolve_item_label(output_id)
		if final_label == String(output_id):
			final_label = label

	result["loot_desc"] = "Constructed %d× %s." % [output_qty, final_label]

	emit_signal("item_constructed", output_id, output_qty)
	emit_signal("construction_recipe_completed", recipe_id, output_id, output_qty, rec)

	return result
