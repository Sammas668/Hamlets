# res://scripts/autoload/construction_system.gd
# Also safe if your project path comment says: res://autoloads/ConstructionSystem.gd
extends Node

## ConstructionSystem
##
## Current locked design:
## - Construction Materials recipes craft boxed kits from logs, stone, and Smithing hardware.
## - Tier 1 base building recipes craft placeable building inventory items.
## - Tier 2+ building tiers are NOT placeable items; they are tile-stored upgrade projects.
## - Placeable building items are dragged from inventory into the SelectionHUD building slot.
## - Placed buildings are stored by tile coordinate.
## - Placed buildings may store one active construction project at a time.
## - Construction projects are repeated worker actions resolved by ConstructionSystem.
## - Each project action consumes the next action packet, rolls success/failure, and stores progress on the tile.
## - Success adds +1 project progress and awards XP.
## - Failure adds no progress and refunds floor(consumed_qty * 25%) per consumed item.
## - Building tier controls module slots and max module level.
## - Module installs and module upgrades are tile projects, not instant output recipes.
## - Removing a placed building refunds 25% of stored building/module kit inputs.
## - No timber-processing pattern remapping.
## - No cut_log / cut_stone material tier resolver.

signal construction_recipes_changed
signal item_constructed(item_id: StringName, count: int)
signal construction_recipe_completed(recipe_id: StringName, output_id: StringName, count: int, recipe: Dictionary)
signal building_changed(ax: Vector2i)

const BASE_ACTION_TIME := 2.4
const BUILDING_REMOVE_ACTION_TIME := 6.0
const BUILDING_REMOVE_REFUND_RATE := 0.25
const PROJECT_FAILURE_REFUND_RATE := 0.25

const CONSTRUCTION_SKILL_ID := "construction"

const BUILDINGS_JSON_PATH := "res://data/specs/resources/buildings.json"
const MODULES_JSON_PATH := "res://data/specs/resources/modules.json"
const MATERIALS_JSON_PATH := "res://data/specs/resources/construction_materials.json"

const CONSTRUCTION_ICON_ROOT := "res://assets/items/Construction"

const GROUP_BASE := &"building_base"
const GROUP_MODULE := &"building_module"
const GROUP_MATERIAL := &"building_material"
const GROUP_REMOVE := &"building_remove"
const GROUP_PROJECT := &"tile_project"

const KIND_BASE := "base"
const KIND_MODULE := "module"
const KIND_MATERIAL := "material"
const KIND_REMOVE_BUILDING := "remove_building"
const KIND_PROJECT := "construction_project"

const REMOVE_BUILDING_RECIPE_PREFIX := "remove_building:"
const PROJECT_RECIPE_PREFIX := "construction_project:"

const PROJECT_TYPE_UPGRADE_BUILDING := "upgrade_building"
const PROJECT_TYPE_INSTALL_MODULE := "install_module"
const PROJECT_TYPE_UPGRADE_MODULE := "upgrade_module"

const PROJECT_STATUS_WORKING := "working"
const PROJECT_STATUS_PAUSED := "paused"
const PROJECT_STATUS_MISSING_RESOURCES := "missing_resources"
const PROJECT_STATUS_COMPLETE := "complete"

const MODULE_LEVEL_CAP_DEFAULT := 3

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

## Built normal CraftMenu recipes:
## { recipe_id:StringName -> recipe:Dictionary }
## Project recipes are normally generated live per tile and are not cached globally.
var _recipe_cache: Dictionary = {}

## Used to prevent repeated warning spam.
var _warned_messages: Dictionary = {}

## Placed building state:
## key "x,y" -> {
##   "base_item_id": "building_grand_smithy_t1",
##   "base_id": "grand_smithy_base",
##   "recipe_id": "grand_smithy_base:t1",
##   "building": "Grand Smithy",
##   "tier": 1,
##   "inputs": [],
##   "modules": [
##     { "id": "grand_smithy_hardware_bench", "level": 1, "inputs": [] }
##   ],
##   "active_project": {}
## }
var _placed_buildings: Dictionary = {}


func _ready() -> void:
	reload_blueprints()


# -------------------------------------------------------------------
# Save / load runtime state
# -------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	_normalize_all_placed_buildings()
	return {
		"placed_buildings": _placed_buildings.duplicate(true),
	}


func from_save_dict(d: Dictionary) -> void:
	_placed_buildings.clear()

	var placed_v: Variant = d.get("placed_buildings", {})
	if placed_v is Dictionary:
		_placed_buildings = (placed_v as Dictionary).duplicate(true)

	_normalize_all_placed_buildings()


func reset_runtime_state() -> void:
	_placed_buildings.clear()


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

		var bp: Dictionary = bp_v as Dictionary
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
		var data_dict: Dictionary = data_any as Dictionary
		for key_v in data_dict.keys():
			var key := String(key_v)
			var entry_v: Variant = data_dict[key_v]

			if typeof(entry_v) != TYPE_DICTIONARY:
				_warn_once("[Construction] Skipping non-dictionary entry '%s' in %s." % [key, path])
				continue

			var entry: Dictionary = (entry_v as Dictionary).duplicate(true)
			var id_str := String(entry.get("id", key)).strip_edges()
			if id_str == "":
				id_str = key

			entry["id"] = id_str
			entry["_source_path"] = path
			dst[id_str] = entry

	elif typeof(data_any) == TYPE_ARRAY:
		var data_arr: Array = data_any as Array
		for i in range(data_arr.size()):
			var entry_v: Variant = data_arr[i]

			if typeof(entry_v) != TYPE_DICTIONARY:
				_warn_once("[Construction] Skipping non-dictionary array entry %d in %s." % [i, path])
				continue

			var entry: Dictionary = (entry_v as Dictionary).duplicate(true)
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


func _make_building_item_id(base_id: StringName, tier: int) -> StringName:
	var s := String(base_id)

	# grand_smithy_base -> grand_smithy
	if s.ends_with("_base"):
		s = s.substr(0, s.length() - "_base".length())

	return StringName("building_%s_t%d" % [s, tier])


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


func _is_remove_building_recipe_id(recipe_id: StringName) -> bool:
	return String(recipe_id).begins_with(REMOVE_BUILDING_RECIPE_PREFIX)


func _make_remove_building_recipe_id(ax: Vector2i) -> StringName:
	return StringName("%s%d,%d" % [REMOVE_BUILDING_RECIPE_PREFIX, ax.x, ax.y])


func _parse_remove_building_recipe_id(recipe_id: StringName) -> Dictionary:
	var s := String(recipe_id)
	if not s.begins_with(REMOVE_BUILDING_RECIPE_PREFIX):
		return {}

	var payload := s.substr(REMOVE_BUILDING_RECIPE_PREFIX.length()).strip_edges()
	var parts := payload.split(",", false)

	if parts.size() != 2:
		return {}

	return {
		"ax": Vector2i(int(parts[0]), int(parts[1])),
	}


func is_construction_project_recipe(recipe_id: StringName) -> bool:
	return String(recipe_id).begins_with(PROJECT_RECIPE_PREFIX)


func _make_project_recipe_id(project_type: String, ax: Vector2i, payload: String) -> StringName:
	return StringName("%s%s:%d,%d:%s" % [
		PROJECT_RECIPE_PREFIX,
		project_type,
		ax.x,
		ax.y,
		payload
	])


func _parse_project_recipe_id(recipe_id: StringName) -> Dictionary:
	var s := String(recipe_id)
	if not s.begins_with(PROJECT_RECIPE_PREFIX):
		return {}

	# construction_project:<type>:<x,y>:<payload>
	# payload may itself contain ":" such as grand_smithy_base:t2.
	var parts := s.split(":", false, 3)
	if parts.size() < 4:
		return {}

	var coord_parts := String(parts[2]).split(",", false)
	if coord_parts.size() != 2:
		return {}

	return {
		"type": String(parts[1]),
		"ax": Vector2i(int(coord_parts[0]), int(coord_parts[1])),
		"payload": String(parts[3]),
	}


func _get_blueprint(id: StringName) -> Dictionary:
	var key := String(id)
	if not _blueprints.has(key):
		return {}

	var bp_v: Variant = _blueprints[key]
	if typeof(bp_v) != TYPE_DICTIONARY:
		return {}

	return bp_v as Dictionary


# -------------------------------------------------------------------
# Tier helpers
# -------------------------------------------------------------------

func _has_tiers(bp: Dictionary) -> bool:
	return typeof(bp.get("tiers", null)) == TYPE_DICTIONARY


func _get_tiers(bp: Dictionary) -> Dictionary:
	var tiers_v: Variant = bp.get("tiers", {})
	if typeof(tiers_v) != TYPE_DICTIONARY:
		return {}

	return tiers_v as Dictionary


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


func _get_tier_max(bp: Dictionary) -> int:
	var sorted := _get_sorted_tier_numbers(bp)
	if sorted.is_empty():
		return 0

	return int(sorted[sorted.size() - 1])


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

	return tier_v as Dictionary


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


func get_module_slot_count_for_tier(tier: int) -> int:
	return clampi(tier, 1, 3)


func get_max_module_level_for_tier(tier: int) -> int:
	return clampi(tier, 1, MODULE_LEVEL_CAP_DEFAULT)


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

	# Avoid recursion for generated construction building items.
	if String(id).begins_with("building_"):
		var info := get_building_item_info(id)
		if not info.is_empty():
			return String(info.get("label", info.get("building", fallback)))
		return fallback

	if typeof(Items) != TYPE_NIL \
	and Items.has_method("is_valid") \
	and Items.has_method("display_name") \
	and Items.is_valid(id):
		return String(Items.display_name(id))

	return fallback


func _resolve_item_icon_path(id: StringName) -> Variant:
	# Avoid Items -> ConstructionSystem -> Items recursion for generated building IDs.
	if String(id).begins_with("building_"):
		return "%s/%s.png" % [CONSTRUCTION_ICON_ROOT, String(id)]

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


func _has_inputs(inputs: Array) -> Dictionary:
	if not _ensure_bank_with([&"has_at_least"]):
		return {
			"ok": false,
			"reason": "Bank API missing has_at_least().",
		}

	for input_v in inputs:
		if typeof(input_v) != TYPE_DICTIONARY:
			continue

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
		var qty := int(input.get("qty", 0))

		if String(item_id) == "" or qty <= 0:
			continue

		if not Bank.has_at_least(item_id, qty):
			return {
				"ok": false,
				"reason": "Missing %s." % _resolve_item_label(item_id),
				"missing_item": item_id,
				"missing_qty": qty,
			}

	return {
		"ok": true,
		"reason": "",
	}


func _take_inputs(inputs: Array) -> void:
	if not _ensure_bank_with([&"take"]):
		return

	for input_v in inputs:
		if typeof(input_v) != TYPE_DICTIONARY:
			continue

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
		var qty := int(input.get("qty", 0))

		if String(item_id) == "" or qty <= 0:
			continue

		Bank.take(item_id, qty)


func _refund_inputs(inputs: Array, rate: float) -> Dictionary:
	var refunded: Dictionary = {}

	if typeof(Bank) == TYPE_NIL:
		return refunded

	if not Bank.has_method("add"):
		return refunded

	for input_v in inputs:
		if typeof(input_v) != TYPE_DICTIONARY:
			continue

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
		var qty := int(input.get("qty", 0))

		if String(item_id) == "" or qty <= 0:
			continue

		var refund_qty := int(floor(float(qty) * rate))
		if refund_qty <= 0:
			continue

		Bank.add(item_id, refund_qty)
		refunded[String(item_id)] = int(refunded.get(String(item_id), 0)) + refund_qty

	return refunded


# -------------------------------------------------------------------
# Placed building state
# -------------------------------------------------------------------

func _coord_key(ax: Vector2i) -> String:
	return "%d,%d" % [ax.x, ax.y]


func _normalize_all_placed_buildings() -> void:
	var keys := _placed_buildings.keys()
	for key_v in keys:
		var key := String(key_v)
		var state_v: Variant = _placed_buildings[key_v]

		if state_v is Dictionary:
			_placed_buildings[key] = _normalize_building_state(state_v as Dictionary)
		else:
			_placed_buildings.erase(key_v)


func _normalize_building_state(state: Dictionary) -> Dictionary:
	var out := state.duplicate(true)

	if not out.has("tier"):
		out["tier"] = 1

	if not out.has("inputs") or not (out["inputs"] is Array):
		out["inputs"] = []

	if not out.has("modules") or not (out["modules"] is Array):
		out["modules"] = []

	out["modules"] = _normalize_module_list(out["modules"])

	if not out.has("active_project") or not (out["active_project"] is Dictionary):
		out["active_project"] = {}

	return out


func _normalize_module_list(raw_modules: Variant) -> Array:
	var out: Array = []

	if not (raw_modules is Array):
		return out

	for m_v in raw_modules:
		if m_v is Dictionary:
			var m: Dictionary = (m_v as Dictionary).duplicate(true)
			var id := String(m.get("id", ""))
			if id == "":
				continue

			m["id"] = id
			m["level"] = maxi(1, int(m.get("level", 1)))

			if not m.has("inputs") or not (m["inputs"] is Array):
				m["inputs"] = []

			out.append(m)

		else:
			var id2 := String(m_v)
			if id2 == "":
				continue

			out.append({
				"id": id2,
				"level": 1,
				"inputs": [],
			})

	return out


func has_building_at(ax: Vector2i) -> bool:
	return _placed_buildings.has(_coord_key(ax))


func get_building_at(ax: Vector2i) -> Dictionary:
	var key := _coord_key(ax)
	if not _placed_buildings.has(key):
		return {}

	var v: Variant = _placed_buildings[key]
	if not (v is Dictionary):
		return {}

	var state := _normalize_building_state(v as Dictionary)
	_placed_buildings[key] = state

	return state.duplicate(true)


func get_all_placed_buildings() -> Dictionary:
	_normalize_all_placed_buildings()
	return _placed_buildings.duplicate(true)


func clear_building_at(ax: Vector2i) -> void:
	var key := _coord_key(ax)
	if not _placed_buildings.has(key):
		return

	_placed_buildings.erase(key)
	building_changed.emit(ax)


func get_active_project(ax: Vector2i) -> Dictionary:
	var building := get_building_at(ax)
	if building.is_empty():
		return {}

	var project_v: Variant = building.get("active_project", {})
	if project_v is Dictionary:
		return (project_v as Dictionary).duplicate(true)

	return {}


func _set_active_project(ax: Vector2i, project: Dictionary) -> void:
	var key := _coord_key(ax)
	if not _placed_buildings.has(key):
		return

	var state_v: Variant = _placed_buildings[key]
	if not (state_v is Dictionary):
		return

	var state := _normalize_building_state(state_v as Dictionary)
	state["active_project"] = project.duplicate(true)
	_placed_buildings[key] = state
	building_changed.emit(ax)


func _clear_active_project(ax: Vector2i) -> void:
	var key := _coord_key(ax)
	if not _placed_buildings.has(key):
		return

	var state_v: Variant = _placed_buildings[key]
	if not (state_v is Dictionary):
		return

	var state := _normalize_building_state(state_v as Dictionary)
	state["active_project"] = {}
	_placed_buildings[key] = state
	building_changed.emit(ax)


func cancel_active_project(ax: Vector2i) -> Dictionary:
	var active := get_active_project(ax)
	if active.is_empty():
		return {
			"ok": false,
			"reason": "No active construction project.",
		}

	_clear_active_project(ax)

	return {
		"ok": true,
		"reason": "",
	}


func _get_recipe_id_for_building_item(item_id: StringName) -> StringName:
	var item_s := String(item_id)

	for key_v in _blueprints.keys():
		var bp_id := StringName(String(key_v))
		var bp := _get_blueprint(bp_id)
		if bp.is_empty():
			continue

		var kind := String(bp.get("kind", "")).strip_edges().to_lower()
		if kind != KIND_BASE:
			continue

		if _has_tiers(bp):
			for tier_v in _get_sorted_tier_numbers(bp):
				var tier := int(tier_v)

				# Only Tier 1 building shells are placeable inventory items.
				if tier != 1:
					continue

				var tier_data := _get_tier_data(bp, tier)
				var expected := String(tier_data.get(
					"output_id",
					bp.get("output_id", String(_make_building_item_id(bp_id, tier)))
				))

				if expected == item_s:
					return _make_tier_recipe_id(bp_id, tier)
		else:
			var tier := int(bp.get("build_tier", bp.get("tier", 1)))
			if tier <= 0:
				tier = 1

			# Untiered/legacy base blueprints remain placeable as Tier 1.
			if tier != 1:
				continue

			var expected := String(bp.get("output_id", String(_make_building_item_id(bp_id, tier))))
			if expected == item_s:
				return _make_tier_recipe_id(bp_id, tier)

	return StringName("")


func get_building_item_info(item_id: StringName) -> Dictionary:
	var recipe_id := _get_recipe_id_for_building_item(item_id)
	if String(recipe_id) == "":
		return {}

	var rec := _build_recipe_for(recipe_id)
	if rec.is_empty():
		return {}

	return rec.duplicate(true)


func is_placeable_building_item(item_id: StringName) -> bool:
	return not get_building_item_info(item_id).is_empty()


func get_placeable_building_item_ids() -> Array[StringName]:
	var out: Array[StringName] = []

	for rec_v in get_all_recipes():
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue

		var rec: Dictionary = rec_v as Dictionary
		if String(rec.get("kind", "")) != KIND_BASE:
			continue

		if int(rec.get("build_tier", 1)) != 1:
			continue

		var output_id := StringName(String(rec.get("output_id", "")))
		if String(output_id) != "":
			out.append(output_id)

	out.sort()
	return out


func get_place_building_block_reason(ax: Vector2i, item_id: StringName) -> String:
	if has_building_at(ax):
		return "This tile already has a building."

	if not is_placeable_building_item(item_id):
		return "Only Tier 1 building shell items can be placed directly."

	if typeof(Bank) == TYPE_NIL:
		return "Bank is unavailable."

	if not Bank.has_method("has_at_least"):
		return "Bank is missing has_at_least()."

	if not Bank.has_at_least(item_id, 1):
		return "You do not have this building item."

	return ""


func can_place_building_item_at(ax: Vector2i, item_id: StringName) -> bool:
	return get_place_building_block_reason(ax, item_id) == ""


func place_building_item_at(ax: Vector2i, item_id: StringName) -> bool:
	var reason := get_place_building_block_reason(ax, item_id)
	if reason != "":
		push_warning("[Construction] Cannot place building: %s" % reason)
		return false

	var rec := get_building_item_info(item_id)
	if rec.is_empty():
		push_warning("[Construction] Cannot place building: no recipe info for %s." % String(item_id))
		return false

	var build_tier := int(rec.get("build_tier", 1))
	if build_tier != 1:
		push_warning("[Construction] Cannot place building: only Tier 1 shells are placeable.")
		return false

	if not _ensure_bank_with([&"take"]):
		return false

	Bank.take(item_id, 1)

	var inputs_v: Variant = rec.get("inputs", [])
	var saved_inputs: Array = []
	if inputs_v is Array:
		saved_inputs = (inputs_v as Array).duplicate(true)

	var state := {
		"base_item_id": String(item_id),
		"base_id": String(rec.get("base_id", "")),
		"recipe_id": String(rec.get("id", "")),
		"building": String(rec.get("building", rec.get("label", String(item_id)))),
		"label": String(rec.get("label", rec.get("building", String(item_id)))),
		"linked_skill": String(rec.get("linked_skill", "")),
		"tier": 1,
		"inputs": saved_inputs,
		"modules": [],
		"active_project": {},
	}

	_placed_buildings[_coord_key(ax)] = _normalize_building_state(state)
	building_changed.emit(ax)
	return true


func remove_building_at(ax: Vector2i, refund: bool = true) -> Dictionary:
	var key := _coord_key(ax)

	if not _placed_buildings.has(key):
		return {
			"ok": false,
			"reason": "No building on this tile.",
			"refunded": {},
		}

	var state_v: Variant = _placed_buildings[key]
	if not (state_v is Dictionary):
		_placed_buildings.erase(key)
		building_changed.emit(ax)
		return {
			"ok": false,
			"reason": "Invalid building state.",
			"refunded": {},
		}

	var state: Dictionary = _normalize_building_state(state_v as Dictionary)
	var refunded: Dictionary = {}

	if refund:
		var inputs_v: Variant = state.get("inputs", [])
		if inputs_v is Array:
			refunded = _merge_refund_dicts(refunded, _refund_inputs(inputs_v as Array, BUILDING_REMOVE_REFUND_RATE))

		var modules_v: Variant = state.get("modules", [])
		if modules_v is Array:
			var module_arr: Array = modules_v as Array
			for module_v in module_arr:
				if not (module_v is Dictionary):
					continue

				var module_state: Dictionary = module_v as Dictionary
				var module_inputs_v: Variant = module_state.get("inputs", [])
				if module_inputs_v is Array:
					refunded = _merge_refund_dicts(refunded, _refund_inputs(module_inputs_v as Array, BUILDING_REMOVE_REFUND_RATE))

	_placed_buildings.erase(key)
	building_changed.emit(ax)

	return {
		"ok": true,
		"reason": "",
		"refunded": refunded,
	}


func _merge_refund_dicts(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)

	for key_v in b.keys():
		var key := String(key_v)
		out[key] = int(out.get(key, 0)) + int(b[key_v])

	return out


func _describe_refunded(refunded: Dictionary) -> String:
	if refunded.is_empty():
		return "No kits were refunded."

	var parts: Array[String] = []
	for key_v in refunded.keys():
		var item_id := StringName(String(key_v))
		var qty := int(refunded[key_v])
		if qty <= 0:
			continue

		parts.append("%d× %s" % [
			qty,
			_resolve_item_label(item_id)
		])

	if parts.is_empty():
		return "No kits were refunded."

	return ", ".join(parts)


func get_remove_building_recipe(ax: Vector2i) -> Dictionary:
	var building := get_building_at(ax)
	if building.is_empty():
		return {}

	var building_name := String(building.get("building", building.get("label", "Building")))
	var recipe_id := _make_remove_building_recipe_id(ax)

	return {
		"id": recipe_id,
		"base_id": recipe_id,
		"output_id": StringName(""),
		"output_qty": 0,

		"label": "Remove %s" % building_name,
		"desc": "Dismantles this building and refunds 25% of the kits used to build it and its installed modules.",
		"effect_raw": "Refunds 25% of stored building/module kit cost.",
		"level_req": 1,
		"xp": 10,
		"duration": BUILDING_REMOVE_ACTION_TIME,
		"icon": "",
		"inputs": [],
		"outputs": [],
		"group": GROUP_REMOVE,

		"building": building_name,
		"linked_skill": String(building.get("linked_skill", "")),
		"skill": CONSTRUCTION_SKILL_ID,
		"kind": KIND_REMOVE_BUILDING,
		"part": "REMOVE",
		"role": "Remove Building",

		"build_tier": int(building.get("tier", 1)),
		"module_tier": 0,
		"mat_tier": 0,
		"min_building_tier": int(building.get("tier", 1)),
		"delta_lv": 0,

		"req_skill_lv": 0,
		"construction_level_req": 1,

		"tier_min": 0,
		"tier_max": 0,
		"tier_default": 0,
		"is_pattern": false,
		"is_install_recipe": false,
		"is_remove_recipe": true,
	}


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

		var existing: Dictionary = existing_v as Dictionary
		if StringName(existing.get("item", StringName(""))) == item_id:
			existing["qty"] = int(existing.get("qty", 0)) + qty

			var sections: Array = []
			var sections_v: Variant = existing.get("sections", [])
			if sections_v is Array:
				sections = sections_v as Array

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
			var map: Dictionary = value as Dictionary
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
			var arr: Array = value as Array
			for entry_v in arr:
				if typeof(entry_v) != TYPE_DICTIONARY:
					continue

				var entry: Dictionary = entry_v as Dictionary
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

	var inputs_block: Dictionary = inputs_block_v as Dictionary
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


func _compose_inputs_for_module(bp_id: StringName, bp: Dictionary) -> Array:
	return _compose_inputs_for_flat_blueprint(bp_id, bp, true)


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


func _clone_inputs(inputs: Array) -> Array:
	var out: Array = []

	for input_v in inputs:
		if not (input_v is Dictionary):
			continue

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
		var qty := int(input.get("qty", 0))
		if String(item_id) == "" or qty <= 0:
			continue

		var clone := input.duplicate(true)
		clone["item"] = item_id
		clone["qty"] = qty
		out.append(clone)

	return out


func _merge_input_arrays(a: Array, b: Array) -> Array:
	var out: Array = _clone_inputs(a)

	for input_v in b:
		if not (input_v is Dictionary):
			continue

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
		var qty := int(input.get("qty", 0))
		if String(item_id) == "" or qty <= 0:
			continue

		_append_input(out, item_id, qty, "project")

	return out


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
		KIND_REMOVE_BUILDING, "building_remove":
			return GROUP_REMOVE
		KIND_PROJECT:
			return GROUP_PROJECT
		_:
			return StringName("")


func _default_xp_for(inputs: Array, level_req: int, kind: String) -> int:
	var total_qty: int = 0

	for input_v in inputs:
		if typeof(input_v) != TYPE_DICTIONARY:
			continue

		var input: Dictionary = input_v as Dictionary
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
		KIND_PROJECT:
			kind_mult = 1.15
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

	# Only Tier 1 base recipes craft placeable building items.
	# Tier 2+ are generated as tile-stored construction project recipes.
	if build_tier != 1:
		return {}

	var tier_data := _get_tier_data(bp, build_tier)
	if tier_data.is_empty():
		return {}

	var building_name := String(bp.get("building", String(bp_id)))
	var linked_skill := String(bp.get("skill", ""))
	var attr := String(bp.get("attr", ""))

	var label := String(tier_data.get("label", bp.get("label", building_name)))
	var desc := String(tier_data.get("desc", "Tier I placeable building shell."))
	var level_req := int(tier_data.get("level_req", bp.get("construction_level_req", bp.get("req_con_lv", 1))))

	var inputs := _compose_inputs_for_base_tier(bp_id, bp, build_tier)
	var xp_gain := int(tier_data.get("xp", bp.get("xp", _default_xp_for(inputs, level_req, KIND_BASE))))

	var output_id := StringName(String(tier_data.get(
		"output_id",
		bp.get("output_id", String(_make_building_item_id(bp_id, build_tier)))
	)))

	var rec := {
		"id": recipe_id,
		"base_id": bp_id,
		"output_id": output_id,
		"output_qty": 1,

		"label": label,
		"desc": desc,
		"effect_raw": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"duration": BASE_ACTION_TIME,
		"icon": _resolve_item_icon_path(output_id),
		"inputs": inputs,
		"outputs": [
			{ "item": output_id, "qty": 1 }
		],
		"group": GROUP_BASE,

		"building": building_name,
		"linked_skill": linked_skill,
		"skill": CONSTRUCTION_SKILL_ID,
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
		"tier_max": 1,
		"tier_default": build_tier,
		"is_pattern": false,
		"is_install_recipe": false,
		"is_remove_recipe": false,
		"is_construction_project": false,
		"placeable_kind": "building_base",
	}

	return rec


func _build_module_recipe(_recipe_id: StringName, _bp_id: StringName, _bp: Dictionary) -> Dictionary:
	# Modules are no longer normal item-output recipes.
	# They are exposed through get_available_projects_for_tile() as install projects.
	return {}


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
		"duration": BASE_ACTION_TIME,
		"icon": _resolve_item_icon_path(output_id),
		"inputs": inputs,
		"outputs": [
			{ "item": output_id, "qty": _get_output_qty(bp) }
		],
		"group": GROUP_MATERIAL,

		"building": building_name,
		"linked_skill": linked_skill,
		"skill": CONSTRUCTION_SKILL_ID,
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
		"is_install_recipe": false,
		"is_remove_recipe": false,
		"is_construction_project": false,
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
		"duration": BASE_ACTION_TIME,
		"icon": _resolve_item_icon_path(output_id),
		"inputs": inputs,
		"outputs": [
			{ "item": output_id, "qty": _get_output_qty(bp) }
		],
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
		"is_install_recipe": false,
		"is_remove_recipe": false,
		"is_construction_project": false,
	}


func _build_recipe_for(recipe_id: StringName) -> Dictionary:
	if _is_remove_building_recipe_id(recipe_id):
		var parsed_remove := _parse_remove_building_recipe_id(recipe_id)
		if parsed_remove.is_empty():
			return {}

		var ax: Vector2i = parsed_remove.get("ax", Vector2i.ZERO)
		return get_remove_building_recipe(ax)

	if is_construction_project_recipe(recipe_id):
		return _build_project_recipe_for_id(recipe_id)

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
			# Only expose Tier 1 as a normal item-output recipe.
			var recipe_id := _make_tier_recipe_id(bp_id, 1)
			var rec := _build_recipe_for(recipe_id)
			if not rec.is_empty():
				out.append(rec)
		elif kind == KIND_MODULE:
			# Modules are install projects, not inventory outputs.
			continue
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

		var rec: Dictionary = rec_v as Dictionary
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

		var rec: Dictionary = rec_v as Dictionary
		if StringName(rec.get("group", StringName(""))) == desired_group:
			out.append(rec)

	return out


func get_recipes_for_building(con_lv: int, building_name: String) -> Array:
	var out: Array = []

	for rec_v in get_recipes_for_level(con_lv):
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue

		var rec: Dictionary = rec_v as Dictionary
		if String(rec.get("building", "")) == building_name:
			out.append(rec)

	return out


func get_material_recipes_for_level(con_lv: int) -> Array:
	return get_recipes_for_level_and_kind(con_lv, KIND_MATERIAL)


func get_module_recipes_for_level(_con_lv: int) -> Array:
	# Modules are now tile install projects.
	return []


func get_base_recipes_for_level(con_lv: int) -> Array:
	return get_recipes_for_level_and_kind(con_lv, KIND_BASE)


func get_recipe_by_id(recipe_id: StringName) -> Dictionary:
	return _build_recipe_for(recipe_id)


func has_recipe(recipe_id: StringName) -> bool:
	return not _build_recipe_for(recipe_id).is_empty()


func has_part(id: String) -> bool:
	var id_name := StringName(id)

	if is_placeable_building_item(id_name):
		return true

	if is_construction_project_recipe(id_name):
		return not _build_project_recipe_for_id(id_name).is_empty()

	var parsed := _parse_recipe_id(id_name)
	var bp_id: StringName = parsed.get("base_id", id_name)
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
	var item_id := StringName(id)

	var placeable := get_building_item_info(item_id)
	if not placeable.is_empty():
		return String(placeable.get("label", placeable.get("building", id)))

	var recipe := _build_recipe_for(item_id)
	if not recipe.is_empty():
		return String(recipe.get("label", id))

	var parsed := _parse_recipe_id(item_id)
	var bp_id: StringName = parsed.get("base_id", item_id)
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


func get_action_time(recipe_id: StringName = StringName("")) -> float:
	if _is_remove_building_recipe_id(recipe_id):
		return BUILDING_REMOVE_ACTION_TIME

	return BASE_ACTION_TIME


# -------------------------------------------------------------------
# Construction project generation
# -------------------------------------------------------------------

func get_available_projects_for_tile(ax: Vector2i, v_idx: int = -1) -> Array:
	var out: Array = []

	var building := get_building_at(ax)
	if building.is_empty():
		return out

	var active := get_active_project(ax)
	if not active.is_empty():
		var active_recipe := _build_recipe_for_active_project(ax, active, v_idx)
		if not active_recipe.is_empty():
			out.append(active_recipe)
		return out

	out.append_array(_get_building_upgrade_projects_for_tile(ax, building, v_idx))
	out.append_array(_get_module_install_projects_for_tile(ax, building, v_idx))
	out.append_array(_get_module_upgrade_projects_for_tile(ax, building, v_idx))

	return out


func _build_project_recipe_for_id(recipe_id: StringName, v_idx: int = -1) -> Dictionary:
	var parsed := _parse_project_recipe_id(recipe_id)
	if parsed.is_empty():
		return {}

	var ax: Vector2i = parsed.get("ax", Vector2i.ZERO)
	var projects := get_available_projects_for_tile(ax, v_idx)

	for project_v in projects:
		if not (project_v is Dictionary):
			continue

		var project: Dictionary = project_v as Dictionary
		if StringName(project.get("id", StringName(""))) == recipe_id:
			return project

	return {}


func _get_building_upgrade_projects_for_tile(ax: Vector2i, building: Dictionary, v_idx: int = -1) -> Array:
	var out: Array = []

	var base_id := StringName(String(building.get("base_id", "")))
	if String(base_id) == "":
		return out

	var bp := _get_blueprint(base_id)
	if bp.is_empty():
		return out

	var current_tier := int(building.get("tier", 1))
	var target_tier := current_tier + 1

	if target_tier > _get_tier_max(bp):
		return out

	var rec := _build_building_upgrade_project_recipe(ax, building, bp, base_id, current_tier, target_tier, {}, v_idx)
	if not rec.is_empty():
		out.append(rec)

	return out


func _build_building_upgrade_project_recipe(ax: Vector2i, building: Dictionary, bp: Dictionary, base_id: StringName, from_tier: int, target_tier: int, active: Dictionary = {}, v_idx: int = -1) -> Dictionary:
	var tier_data := _get_tier_data(bp, target_tier)
	if tier_data.is_empty():
		return {}

	var building_name := String(building.get("building", bp.get("building", String(base_id))))
	var req_lv := int(tier_data.get("level_req", bp.get("construction_level_req", bp.get("req_con_lv", 1))))
	var total_inputs := _compose_inputs_for_base_tier(base_id, bp, target_tier)
	var required_successes := _estimate_required_successes(total_inputs)
	var successful_actions := int(active.get("successful_actions", 0))
	var failed_actions := int(active.get("failed_actions", 0))
	var action_inputs := _make_action_packet_for_progress(total_inputs, successful_actions)
	var xp_total := int(tier_data.get("xp", bp.get("xp", _default_xp_for(total_inputs, req_lv, KIND_PROJECT))))
	var xp_per_success := _xp_per_success(xp_total, required_successes)

	var recipe_id := _make_project_recipe_id(
		PROJECT_TYPE_UPGRADE_BUILDING,
		ax,
		"%s:t%d" % [String(base_id), target_tier]
	)

	var fail_chance := 0.0
	if v_idx >= 0:
		fail_chance = get_construction_fail_chance(_get_construction_level_for_villager(v_idx), req_lv)

	return _make_project_recipe_common({
		"id": recipe_id,
		"project_type": PROJECT_TYPE_UPGRADE_BUILDING,
		"label": "Upgrade %s to Tier %d" % [building_name, target_tier],
		"desc": "Improves this placed building shell. Progress is stored on the tile.",
		"effect_raw": "Upgrades building shell to Tier %d." % target_tier,
		"building": building_name,
		"linked_skill": String(building.get("linked_skill", bp.get("skill", ""))),
		"base_id": base_id,
		"from_tier": from_tier,
		"target_tier": target_tier,
		"module_id": "",
		"target_level": 0,
		"req_con_lv": req_lv,
		"level_req": max(1, req_lv - 15),
		"xp": xp_per_success,
		"total_xp": xp_total,
		"required_successes": required_successes,
		"successful_actions": successful_actions,
		"failed_actions": failed_actions,
		"inputs": action_inputs,
		"per_action_inputs": action_inputs,
		"project_total_inputs": total_inputs,
		"fail_chance": fail_chance,
		"build_tier": target_tier,
		"module_tier": 0,
		"min_building_tier": target_tier,
	})


func _get_module_install_projects_for_tile(ax: Vector2i, building: Dictionary, v_idx: int = -1) -> Array:
	var out: Array = []

	var building_name := String(building.get("building", ""))
	if building_name == "":
		return out

	var building_tier := int(building.get("tier", 1))
	var modules: Array = _normalize_module_list(building.get("modules", []))
	var slot_count := get_module_slot_count_for_tier(building_tier)

	if modules.size() >= slot_count:
		return out

	for key_v in _blueprints.keys():
		var bp_id := StringName(String(key_v))
		var bp := _get_blueprint(bp_id)
		if bp.is_empty():
			continue

		if String(bp.get("kind", "")).strip_edges().to_lower() != KIND_MODULE:
			continue

		if String(bp.get("building", "")) != building_name:
			continue

		if _has_module_installed(building, String(bp_id)):
			continue

		var min_tier := int(bp.get("min_building_tier", 1))
		if building_tier < min_tier:
			continue

		var rec := _build_module_install_project_recipe(ax, building, bp_id, bp, {}, v_idx)
		if not rec.is_empty():
			out.append(rec)

	return out


func _build_module_install_project_recipe(ax: Vector2i, building: Dictionary, module_id: StringName, bp: Dictionary, active: Dictionary = {}, v_idx: int = -1) -> Dictionary:
	var req_lv := _get_construction_level_req_for_flat(bp)
	var total_inputs := _compose_inputs_for_module(module_id, bp)
	var required_successes := _estimate_required_successes(total_inputs)
	var successful_actions := int(active.get("successful_actions", 0))
	var failed_actions := int(active.get("failed_actions", 0))
	var action_inputs := _make_action_packet_for_progress(total_inputs, successful_actions)
	var xp_total := int(bp.get("xp", _default_xp_for(total_inputs, req_lv, KIND_PROJECT)))
	var xp_per_success := _xp_per_success(xp_total, required_successes)
	var part := String(bp.get("part", module_id))
	var building_name := String(building.get("building", bp.get("building", "")))

	var recipe_id := _make_project_recipe_id(
		PROJECT_TYPE_INSTALL_MODULE,
		ax,
		String(module_id)
	)

	var fail_chance := 0.0
	if v_idx >= 0:
		fail_chance = get_construction_fail_chance(_get_construction_level_for_villager(v_idx), req_lv)

	return _make_project_recipe_common({
		"id": recipe_id,
		"project_type": PROJECT_TYPE_INSTALL_MODULE,
		"label": "Install %s" % part,
		"desc": String(bp.get("effect", bp.get("desc", "Installs this module on the selected building."))),
		"effect_raw": String(bp.get("effect", bp.get("desc", ""))),
		"building": building_name,
		"linked_skill": String(bp.get("skill", building.get("linked_skill", ""))),
		"base_id": String(building.get("base_id", "")),
		"from_tier": int(building.get("tier", 1)),
		"target_tier": int(building.get("tier", 1)),
		"module_id": module_id,
		"target_level": 1,
		"req_con_lv": req_lv,
		"level_req": max(1, req_lv - 15),
		"xp": xp_per_success,
		"total_xp": xp_total,
		"required_successes": required_successes,
		"successful_actions": successful_actions,
		"failed_actions": failed_actions,
		"inputs": action_inputs,
		"per_action_inputs": action_inputs,
		"project_total_inputs": total_inputs,
		"fail_chance": fail_chance,
		"build_tier": 0,
		"module_tier": _get_module_tier(bp),
		"min_building_tier": int(bp.get("min_building_tier", 1)),
		"part": part,
		"role": String(bp.get("role", "")),
		"effects": bp.get("effects", {}),
	})


func _get_module_upgrade_projects_for_tile(ax: Vector2i, building: Dictionary, v_idx: int = -1) -> Array:
	var out: Array = []

	var building_tier := int(building.get("tier", 1))
	var max_level := get_max_module_level_for_tier(building_tier)
	var modules: Array = _normalize_module_list(building.get("modules", []))

	for module_v in modules:
		if not (module_v is Dictionary):
			continue

		var module_state: Dictionary = module_v as Dictionary
		var module_id := StringName(String(module_state.get("id", "")))
		if String(module_id) == "":
			continue

		var current_level := int(module_state.get("level", 1))
		var target_level := current_level + 1

		if target_level > max_level:
			continue

		var bp := _get_blueprint(module_id)
		if bp.is_empty():
			continue

		var rec := _build_module_upgrade_project_recipe(ax, building, module_state, module_id, bp, target_level, {}, v_idx)
		if not rec.is_empty():
			out.append(rec)

	return out


func _build_module_upgrade_project_recipe(ax: Vector2i, building: Dictionary, module_state: Dictionary, module_id: StringName, bp: Dictionary, target_level: int, active: Dictionary = {}, v_idx: int = -1) -> Dictionary:
	var base_req_lv := _get_construction_level_req_for_flat(bp)
	var req_lv := base_req_lv + ((target_level - 1) * 10)
	var install_inputs := _compose_inputs_for_module(module_id, bp)
	var total_inputs := _scale_inputs_for_module_upgrade(install_inputs, target_level)
	var required_successes := _estimate_required_successes(total_inputs)
	var successful_actions := int(active.get("successful_actions", 0))
	var failed_actions := int(active.get("failed_actions", 0))
	var action_inputs := _make_action_packet_for_progress(total_inputs, successful_actions)
	var xp_total := int(bp.get("xp", _default_xp_for(total_inputs, req_lv, KIND_PROJECT))) * target_level
	var xp_per_success := _xp_per_success(xp_total, required_successes)
	var part := String(bp.get("part", module_id))
	var current_level := int(module_state.get("level", 1))

	var recipe_id := _make_project_recipe_id(
		PROJECT_TYPE_UPGRADE_MODULE,
		ax,
		"%s:l%d" % [String(module_id), target_level]
	)

	var fail_chance := 0.0
	if v_idx >= 0:
		fail_chance = get_construction_fail_chance(_get_construction_level_for_villager(v_idx), req_lv)

	return _make_project_recipe_common({
		"id": recipe_id,
		"project_type": PROJECT_TYPE_UPGRADE_MODULE,
		"label": "Upgrade %s to Level %d" % [part, target_level],
		"desc": "Improves this installed module. Building tier caps maximum module level.",
		"effect_raw": String(bp.get("effect", bp.get("desc", ""))),
		"building": String(building.get("building", bp.get("building", ""))),
		"linked_skill": String(bp.get("skill", building.get("linked_skill", ""))),
		"base_id": String(building.get("base_id", "")),
		"from_tier": int(building.get("tier", 1)),
		"target_tier": int(building.get("tier", 1)),
		"module_id": module_id,
		"current_level": current_level,
		"target_level": target_level,
		"req_con_lv": req_lv,
		"level_req": max(1, req_lv - 15),
		"xp": xp_per_success,
		"total_xp": xp_total,
		"required_successes": required_successes,
		"successful_actions": successful_actions,
		"failed_actions": failed_actions,
		"inputs": action_inputs,
		"per_action_inputs": action_inputs,
		"project_total_inputs": total_inputs,
		"fail_chance": fail_chance,
		"build_tier": 0,
		"module_tier": _get_module_tier(bp),
		"min_building_tier": int(bp.get("min_building_tier", 1)),
		"part": part,
		"role": String(bp.get("role", "")),
		"effects": bp.get("effects", {}),
	})


func _make_project_recipe_common(raw: Dictionary) -> Dictionary:
	var rec := raw.duplicate(true)
	var recipe_id := StringName(String(rec.get("id", "")))
	var req_lv := int(rec.get("req_con_lv", rec.get("level_req", 1)))
	var successful_actions := int(rec.get("successful_actions", 0))
	var required_successes := maxi(1, int(rec.get("required_successes", 1)))

	rec["id"] = recipe_id
	rec["kind"] = KIND_PROJECT
	rec["skill"] = CONSTRUCTION_SKILL_ID
	rec["group"] = GROUP_PROJECT
	rec["duration"] = BASE_ACTION_TIME
	rec["outputs"] = []
	rec["output_id"] = StringName("")
	rec["output_qty"] = 0

	rec["construction_level_req"] = req_lv
	rec["req_con_lv"] = req_lv
	rec["level_req"] = int(rec.get("level_req", max(1, req_lv - 15)))

	rec["is_construction_project"] = true
	rec["is_install_recipe"] = String(rec.get("project_type", "")) == PROJECT_TYPE_INSTALL_MODULE
	rec["is_remove_recipe"] = false
	rec["is_pattern"] = false

	rec["progress_label"] = "%d / %d successes" % [successful_actions, required_successes]
	rec["remaining_successes"] = maxi(0, required_successes - successful_actions)

	rec["tier_min"] = 0
	rec["tier_max"] = 0
	rec["tier_default"] = 0
	rec["mat_tier"] = int(rec.get("mat_tier", 0))
	rec["delta_lv"] = int(rec.get("delta_lv", 0))
	rec["req_skill_lv"] = int(rec.get("req_skill_lv", 0))

	return rec


func _build_recipe_for_active_project(ax: Vector2i, active: Dictionary, v_idx: int = -1) -> Dictionary:
	var ptype := String(active.get("type", active.get("project_type", "")))

	match ptype:
		PROJECT_TYPE_UPGRADE_BUILDING:
			var building := get_building_at(ax)
			if building.is_empty():
				return {}

			var base_id := StringName(String(active.get("base_id", building.get("base_id", ""))))
			if String(base_id) == "":
				return {}

			var bp := _get_blueprint(base_id)
			if bp.is_empty():
				return {}

			return _build_building_upgrade_project_recipe(
				ax,
				building,
				bp,
				base_id,
				int(active.get("from_tier", building.get("tier", 1))),
				int(active.get("target_tier", int(building.get("tier", 1)) + 1)),
				active,
				v_idx
			)

		PROJECT_TYPE_INSTALL_MODULE:
			var building2 := get_building_at(ax)
			if building2.is_empty():
				return {}

			var module_id := StringName(String(active.get("module_id", "")))
			var bp2 := _get_blueprint(module_id)
			if bp2.is_empty():
				return {}

			return _build_module_install_project_recipe(ax, building2, module_id, bp2, active, v_idx)

		PROJECT_TYPE_UPGRADE_MODULE:
			var building3 := get_building_at(ax)
			if building3.is_empty():
				return {}

			var module_id2 := StringName(String(active.get("module_id", "")))
			var module_state := _get_installed_module_state(building3, String(module_id2))
			if module_state.is_empty():
				return {}

			var bp3 := _get_blueprint(module_id2)
			if bp3.is_empty():
				return {}

			return _build_module_upgrade_project_recipe(
				ax,
				building3,
				module_state,
				module_id2,
				bp3,
				int(active.get("target_level", int(module_state.get("level", 1)) + 1)),
				active,
				v_idx
			)

		_:
			return {}

	return {}


func _estimate_required_successes(inputs: Array) -> int:
	var max_qty := 0

	for input_v in inputs:
		if not (input_v is Dictionary):
			continue

		var input: Dictionary = input_v as Dictionary
		max_qty = maxi(max_qty, int(input.get("qty", 0)))

	return maxi(1, max_qty)


func _make_action_packet_for_progress(total_inputs: Array, successful_actions: int) -> Array:
	var packet: Array = []

	for input_v in total_inputs:
		if not (input_v is Dictionary):
			continue

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
		var qty := int(input.get("qty", 0))

		if String(item_id) == "" or qty <= 0:
			continue

		if qty > successful_actions:
			packet.append({
				"item": item_id,
				"qty": 1,
			})

	return packet


func _xp_per_success(total_xp: int, required_successes: int) -> int:
	if total_xp <= 0:
		return 0

	return maxi(1, int(round(float(total_xp) / float(maxi(1, required_successes)))))


func _scale_inputs_for_module_upgrade(inputs: Array, target_level: int) -> Array:
	var out: Array = []
	var mult := maxi(1, target_level)

	for input_v in inputs:
		if not (input_v is Dictionary):
			continue

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
		var qty := int(input.get("qty", 0))

		if String(item_id) == "" or qty <= 0:
			continue

		out.append({
			"item": item_id,
			"qty": qty * mult,
		})

	return out


func _has_module_installed(building: Dictionary, module_id: String) -> bool:
	return not _get_installed_module_state(building, module_id).is_empty()


func _get_installed_module_state(building: Dictionary, module_id: String) -> Dictionary:
	var modules: Array = _normalize_module_list(building.get("modules", []))

	for module_v in modules:
		if not (module_v is Dictionary):
			continue

		var module_state: Dictionary = module_v as Dictionary
		if String(module_state.get("id", "")) == module_id:
			return module_state.duplicate(true)

	return {}


# -------------------------------------------------------------------
# Construction project execution
# -------------------------------------------------------------------

func _get_construction_level_for_villager(v_idx: int) -> int:
	if v_idx < 0:
		return 1

	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
		return maxi(1, int(Villagers.get_skill_level(v_idx, CONSTRUCTION_SKILL_ID)))

	return 1


func get_construction_fail_chance(worker_level: int, required_level: int) -> float:
	var gap := required_level - worker_level

	if gap <= 0:
		return 0.0

	if gap > 15:
		return -1.0

	return min(gap * 0.02, 0.25)


func _find_available_project_recipe(ax: Vector2i, project_id: StringName, v_idx: int = -1) -> Dictionary:
	var projects := get_available_projects_for_tile(ax, v_idx)

	for project_v in projects:
		if not (project_v is Dictionary):
			continue

		var project: Dictionary = project_v as Dictionary
		if StringName(project.get("id", StringName(""))) == project_id:
			return project

	return {}


func can_start_project(ax: Vector2i, project_id: StringName, v_idx: int) -> Dictionary:
	if not is_construction_project_recipe(project_id):
		return {
			"ok": false,
			"reason": "Recipe is not a construction project.",
		}

	var building := get_building_at(ax)
	if building.is_empty():
		return {
			"ok": false,
			"reason": "No building on this tile.",
		}

	var active := get_active_project(ax)
	if not active.is_empty() and String(active.get("project_id", "")) != String(project_id):
		return {
			"ok": false,
			"reason": "This tile already has another active construction project.",
		}

	var project_recipe := _find_available_project_recipe(ax, project_id, v_idx)
	if project_recipe.is_empty():
		return {
			"ok": false,
			"reason": "Project is not available for this tile.",
		}

	var req_lv := int(project_recipe.get("req_con_lv", project_recipe.get("level_req", 1)))
	var worker_lv := _get_construction_level_for_villager(v_idx)
	var fail_chance := get_construction_fail_chance(worker_lv, req_lv)

	if fail_chance < 0.0:
		return {
			"ok": false,
			"reason": "Construction level too low.",
		}

	return {
		"ok": true,
		"reason": "",
		"fail_chance": fail_chance,
		"recipe": project_recipe,
	}


func start_or_continue_project(ax: Vector2i, project_id: StringName, v_idx: int) -> Dictionary:
	var check := can_start_project(ax, project_id, v_idx)
	if not bool(check.get("ok", false)):
		return check

	var current := get_active_project(ax)
	if not current.is_empty():
		current["assigned_worker"] = v_idx
		current["status"] = PROJECT_STATUS_WORKING
		_set_active_project(ax, current)

		return {
			"ok": true,
			"reason": "",
			"project": current,
		}

	var recipe_v: Variant = check.get("recipe", {})
	var recipe: Dictionary = {}
	if recipe_v is Dictionary:
		recipe = recipe_v as Dictionary

	var project := {
		"type": String(recipe.get("project_type", "")),
		"project_type": String(recipe.get("project_type", "")),
		"project_id": String(recipe.get("id", project_id)),
		"base_id": String(recipe.get("base_id", "")),
		"module_id": String(recipe.get("module_id", "")),
		"from_tier": int(recipe.get("from_tier", 0)),
		"target_tier": int(recipe.get("target_tier", 0)),
		"target_level": int(recipe.get("target_level", 0)),
		"req_con_lv": int(recipe.get("req_con_lv", recipe.get("level_req", 1))),
		"required_successes": int(recipe.get("required_successes", 1)),
		"successful_actions": int(recipe.get("successful_actions", 0)),
		"failed_actions": int(recipe.get("failed_actions", 0)),
		"assigned_worker": v_idx,
		"status": PROJECT_STATUS_WORKING,
		"total_inputs": _clone_inputs(recipe.get("project_total_inputs", [])),
	}

	_set_active_project(ax, project)

	return {
		"ok": true,
		"reason": "",
		"project": project,
	}


func resolve_project_action(ax: Vector2i, v_idx: int, project_id: StringName) -> Dictionary:
	var building := get_building_at(ax)
	if building.is_empty():
		return {
			"ok": false,
			"reason": "No building on this tile.",
		}

	var active := get_active_project(ax)

	if active.is_empty():
		var started := start_or_continue_project(ax, project_id, v_idx)
		if not bool(started.get("ok", false)):
			return started
		active = get_active_project(ax)

	if String(active.get("project_id", "")) != String(project_id):
		return {
			"ok": false,
			"reason": "A different construction project is already active on this tile.",
		}

	var recipe := _build_recipe_for_active_project(ax, active, v_idx)
	if recipe.is_empty():
		return {
			"ok": false,
			"reason": "Could not rebuild active project recipe.",
		}

	var req_lv := int(active.get("req_con_lv", recipe.get("req_con_lv", 1)))
	var worker_lv := _get_construction_level_for_villager(v_idx)
	var fail_chance := get_construction_fail_chance(worker_lv, req_lv)

	if fail_chance < 0.0:
		active["status"] = PROJECT_STATUS_PAUSED
		_set_active_project(ax, active)
		return {
			"ok": false,
			"reason": "Construction level too low.",
		}

	var inputs_v: Variant = recipe.get("per_action_inputs", recipe.get("inputs", []))
	var inputs: Array = inputs_v as Array if inputs_v is Array else []

	if inputs.is_empty():
		return {
			"ok": false,
			"reason": "Construction project has no action inputs.",
		}

	var has_check := _has_inputs(inputs)
	if not bool(has_check.get("ok", false)):
		active["status"] = PROJECT_STATUS_MISSING_RESOURCES
		_set_active_project(ax, active)
		return has_check

	_take_inputs(inputs)

	var failed := randf() < fail_chance
	if failed:
		active["failed_actions"] = int(active.get("failed_actions", 0)) + 1
		active["assigned_worker"] = v_idx
		active["status"] = PROJECT_STATUS_WORKING

		var refund := _refund_inputs(inputs, PROJECT_FAILURE_REFUND_RATE)
		_set_active_project(ax, active)

		return {
			"ok": true,
			"success": false,
			"failed": true,
			"completed": false,
			"xp": 0,
			"refund": refund,
			"message": "Construction failed. Some materials were returned.",
			"loot_desc": "Construction failed. Some materials were returned.",
		}

	active["successful_actions"] = int(active.get("successful_actions", 0)) + 1
	active["assigned_worker"] = v_idx
	active["status"] = PROJECT_STATUS_WORKING

	var xp := int(recipe.get("xp", 0))
	var required := int(active.get("required_successes", 1))
	var current := int(active.get("successful_actions", 0))

	if current >= required:
		_set_active_project(ax, active)
		var complete := complete_project(ax)
		complete["xp"] = xp
		return complete

	_set_active_project(ax, active)

	return {
		"ok": true,
		"success": true,
		"failed": false,
		"completed": false,
		"xp": xp,
		"message": "Construction progress increased.",
		"loot_desc": "Construction progress increased.",
	}


func complete_project(ax: Vector2i) -> Dictionary:
	var key := _coord_key(ax)
	if not _placed_buildings.has(key):
		return {
			"ok": false,
			"reason": "No building on this tile.",
		}

	var state_v: Variant = _placed_buildings[key]
	if not (state_v is Dictionary):
		return {
			"ok": false,
			"reason": "Invalid building state.",
		}

	var state := _normalize_building_state(state_v as Dictionary)
	var active_v: Variant = state.get("active_project", {})

	if not (active_v is Dictionary):
		return {
			"ok": false,
			"reason": "No active project.",
		}

	var active: Dictionary = active_v as Dictionary
	if active.is_empty():
		return {
			"ok": false,
			"reason": "No active project.",
		}

	var ptype := String(active.get("type", active.get("project_type", "")))
	var total_inputs: Array = _clone_inputs(active.get("total_inputs", []))
	if total_inputs.is_empty():
		var active_recipe := _build_recipe_for_active_project(ax, active, -1)
		if not active_recipe.is_empty():
			total_inputs = _clone_inputs(active_recipe.get("project_total_inputs", []))

	match ptype:
		PROJECT_TYPE_UPGRADE_BUILDING:
			var target_tier := int(active.get("target_tier", 0))
			if target_tier <= 0:
				return {
					"ok": false,
					"reason": "Invalid target tier.",
				}

			state["tier"] = target_tier

			var base_id := StringName(String(state.get("base_id", "")))
			if String(base_id) != "":
				state["recipe_id"] = String(_make_tier_recipe_id(base_id, target_tier))
				state["base_item_id"] = String(_make_building_item_id(base_id, target_tier))

				var bp := _get_blueprint(base_id)
				var tier_data := _get_tier_data(bp, target_tier)
				if not tier_data.is_empty():
					state["label"] = String(tier_data.get("label", state.get("label", "")))

			state["inputs"] = _merge_input_arrays(state.get("inputs", []), total_inputs)
			state["active_project"] = {}
			_placed_buildings[key] = _normalize_building_state(state)
			building_changed.emit(ax)

			return {
				"ok": true,
				"success": true,
				"failed": false,
				"completed": true,
				"message": "Building upgraded to Tier %d." % target_tier,
				"loot_desc": "Building upgraded to Tier %d." % target_tier,
			}

		PROJECT_TYPE_INSTALL_MODULE:
			var module_id := String(active.get("module_id", ""))
			if module_id == "":
				return {
					"ok": false,
					"reason": "Invalid module id.",
				}

			var modules: Array = _normalize_module_list(state.get("modules", []))
			modules.append({
				"id": module_id,
				"level": 1,
				"installed_by": int(active.get("assigned_worker", -1)),
				"inputs": total_inputs,
			})

			state["modules"] = modules
			state["active_project"] = {}
			_placed_buildings[key] = _normalize_building_state(state)
			building_changed.emit(ax)

			return {
				"ok": true,
				"success": true,
				"failed": false,
				"completed": true,
				"message": "Module installed.",
				"loot_desc": "Module installed.",
			}

		PROJECT_TYPE_UPGRADE_MODULE:
			var module_id2 := String(active.get("module_id", ""))
			var target_level := int(active.get("target_level", 0))
			if module_id2 == "" or target_level <= 0:
				return {
					"ok": false,
					"reason": "Invalid module upgrade target.",
				}

			var modules2: Array = _normalize_module_list(state.get("modules", []))
			var found := false

			for i in range(modules2.size()):
				var module_state: Dictionary = modules2[i] as Dictionary
				if String(module_state.get("id", "")) != module_id2:
					continue

				module_state["level"] = target_level
				module_state["inputs"] = _merge_input_arrays(module_state.get("inputs", []), total_inputs)
				modules2[i] = module_state
				found = true
				break

			if not found:
				return {
					"ok": false,
					"reason": "Installed module not found.",
				}

			state["modules"] = modules2
			state["active_project"] = {}
			_placed_buildings[key] = _normalize_building_state(state)
			building_changed.emit(ax)

			return {
				"ok": true,
				"success": true,
				"failed": false,
				"completed": true,
				"message": "Module upgraded to Level %d." % target_level,
				"loot_desc": "Module upgraded to Level %d." % target_level,
			}

		_:
			return {
				"ok": false,
				"reason": "Unsupported project type.",
			}

	return {
		"ok": false,
		"reason": "Unsupported project type.",
	}


# -------------------------------------------------------------------
# Affordability / missing inputs
# -------------------------------------------------------------------

func get_missing_inputs(recipe_id: StringName) -> Array:
	var missing: Array = []

	if _is_remove_building_recipe_id(recipe_id):
		return missing

	if not _ensure_bank_with([&"amount"]):
		return missing

	var rec := _build_recipe_for(recipe_id)
	if rec.is_empty():
		return missing

	var inputs_v: Variant = rec.get("inputs", [])
	if not (inputs_v is Array):
		return missing

	var inputs: Array = inputs_v as Array

	for input_v in inputs:
		if typeof(input_v) != TYPE_DICTIONARY:
			continue

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
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
	if _is_remove_building_recipe_id(recipe_id):
		var parsed_remove := _parse_remove_building_recipe_id(recipe_id)
		if parsed_remove.is_empty():
			return false

		var ax: Vector2i = parsed_remove.get("ax", Vector2i.ZERO)
		return has_building_at(ax)

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

		var entry: Dictionary = entry_v as Dictionary
		parts.append("%s %d/%d" % [
			String(entry.get("label", entry.get("item", ""))),
			int(entry.get("have", 0)),
			int(entry.get("need", 0))
		])

	return ", ".join(parts)


# -------------------------------------------------------------------
# Job entrypoint – used by VillagerManager for normal construction
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

	if is_construction_project_recipe(recipe_id):
		var parsed_project := _parse_project_recipe_id(recipe_id)
		if parsed_project.is_empty():
			result["loot_desc"] = "Invalid construction project recipe."
			return result

		result["loot_desc"] = "Construction project recipes require resolve_project_action(ax, v_idx, recipe_id)."
		return result

	if _is_remove_building_recipe_id(recipe_id):
		return _do_remove_building_work(recipe_id)

	if not _ensure_bank_with([&"amount", &"take", &"add"]):
		result["loot_desc"] = "Bank API missing required methods."
		return result

	var rec := _build_recipe_for(recipe_id)
	if rec.is_empty():
		result["loot_desc"] = "Unknown construction recipe."
		return result

	var inputs_v: Variant = rec.get("inputs", [])
	if not (inputs_v is Array):
		result["loot_desc"] = "Construction recipe has invalid inputs."
		return result

	var inputs: Array = inputs_v as Array
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

		var input: Dictionary = input_v as Dictionary
		var item_id := StringName(String(input.get("item", "")))
		var qty := int(input.get("qty", 0))

		if String(item_id) == "" or qty <= 0:
			continue

		Bank.take(item_id, qty)

	var output_id := StringName(String(rec.get("output_id", recipe_id)))
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


func _do_remove_building_work(recipe_id: StringName) -> Dictionary:
	var result := {
		"ok": false,
		"xp": 0,
		"loot_desc": "",
		"recipe_id": recipe_id,
		"output_id": StringName(""),
		"output_count": 0
	}

	var parsed := _parse_remove_building_recipe_id(recipe_id)
	if parsed.is_empty():
		result["loot_desc"] = "Invalid remove-building recipe."
		return result

	var ax: Vector2i = parsed.get("ax", Vector2i.ZERO)
	var rec := get_remove_building_recipe(ax)
	if rec.is_empty():
		result["loot_desc"] = "No building to remove."
		return result

	var remove_result := remove_building_at(ax, true)
	if not bool(remove_result.get("ok", false)):
		result["loot_desc"] = String(remove_result.get("reason", "Could not remove building."))
		return result

	var refunded: Dictionary = remove_result.get("refunded", {})
	var xp_gain := int(rec.get("xp", 0))

	result["ok"] = true
	result["xp"] = xp_gain
	result["loot_desc"] = "Building removed. Refunded: %s" % _describe_refunded(refunded)

	emit_signal("construction_recipe_completed", recipe_id, StringName(""), 0, rec)

	return result
