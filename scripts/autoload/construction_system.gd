# res://autoloads/ConstructionSystem.gd
extends Node

## ConstructionSystem (JSON-driven)
##
## Now supports:
## - New buildings.json structure with "tiers" per base building.
## - Old flat entries (modules etc.) still supported as a fallback.
## - Material pattern → item mapping from construction_materials.
##
## buildings.json (base shells) looks like:
## {
##   "foragers_hut_base": {
##     "kind": "base",
##     "attr": "con",
##     "building": "Forager’s Hut",
##     "skill": "herbalism",
##     "label": "Forager’s Hut",
##     "tiers": {
##       "1": {
##         "label": "Forager’s Hut (Herbalism)",
##         "desc": "Tier I shell...",
##         "level_req": 10,
##         "inputs": {
##           "struct": [ { "item": "frame", "qty": 4 }, ... ],
##           "hardware": [ { "item": "nails", "qty": 100 }, ... ]
##         }
##       },
##       "2": { ... },
##       "3": { ... }
##     }
##   },
##   ...
## }
##
## Craft_Menu still expects each recipe as:
## { id, label, desc, level_req, xp, icon, inputs }

signal construction_recipes_changed
signal item_constructed(item_id: StringName, count: int)

const BASE_ACTION_TIME := 2.4               # seconds per action
const CONSTRUCTION_SKILL_ID := "construction"

const BUILDINGS_JSON_PATH := "res://data/specs/resources/buildings.json"
const MODULES_JSON_PATH   := "res://data/specs/resources/modules.json"
const MATERIALS_JSON_PATH := "res://data/specs/resources/construction_materials.json"
const MATERIALS_TRES_PATH := "res://data/specs/resources/construction_materials.tres"  # 🔧 adjust if needed

# Raw JSON data: { id:String -> blueprint:Dictionary }
var _blueprints: Dictionary = {}

# Cache of built recipes for CraftMenu:
# { item_id:StringName -> recipe:Dictionary }
var _recipe_cache: Dictionary = {}

# Pattern → { tier:int -> item_id:StringName }
var _materials_by_pattern: Dictionary = {}


func _ready() -> void:
	reload_blueprints()


# -------------------------------------------------------------------
# Loading JSON + materials
# -------------------------------------------------------------------
func _load_json_into(dst: Dictionary, path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("[Construction] JSON file missing: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Construction] Could not open %s" % path)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[Construction] Failed to parse %s (err=%d)" % [path, err])
		return

	var data_any: Variant = json.data

	# Accept both a Dictionary root and an Array-of-entries root
	if typeof(data_any) == TYPE_DICTIONARY:
		var data_dict: Dictionary = data_any as Dictionary
		for k in data_dict.keys():
			dst[k] = data_dict[k]
	elif typeof(data_any) == TYPE_ARRAY:
		var data_arr: Array = data_any as Array
		for entry_v: Variant in data_arr:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_v as Dictionary
			var id_str: String = String(entry.get("id", ""))
			if id_str == "":
				continue
			dst[id_str] = entry
	else:
		push_error("[Construction] Root of %s is neither Dictionary nor Array." % path)


func _register_material(pattern: StringName, tier: int, item_id: StringName) -> void:
	if String(pattern) == "" or tier <= 0 or String(item_id) == "":
		return

	if not _materials_by_pattern.has(pattern):
		_materials_by_pattern[pattern] = {}

	var tier_map: Dictionary = _materials_by_pattern[pattern]
	tier_map[tier] = item_id
	_materials_by_pattern[pattern] = tier_map


# *** FIXED: now wires cut_log_* / cut_stone_* to timber_units / stone_units ***
func _load_materials_from_json(path: String) -> void:
	if not FileAccess.file_exists(path):
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Construction] Could not open materials JSON: %s" % path)
		return

	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("[Construction] Failed to parse materials JSON %s (err=%d)" % [path, err])
		return

	var data_any: Variant = json.data
	if typeof(data_any) != TYPE_DICTIONARY:
		push_error("[Construction] materials JSON root must be a Dictionary.")
		return

	var data: Dictionary = data_any as Dictionary

	for id_key in data.keys():
		var entry_any: Variant = data[id_key]
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_any as Dictionary

		# Only care about entries marked kind: "material"
		if String(entry.get("kind", "")) != "material":
			continue

		var id_str: String = String(id_key)
		var mat_tier: int = int(entry.get("mat_tier", entry.get("tier", 0)))
		var item_str: String = String(entry.get("item", id_str))
		var item_id: StringName = StringName(item_str)

		# 1) Explicit string pattern from JSON (if you ever add them)
		var pattern_raw: Variant = entry.get("pattern", "")
		if typeof(pattern_raw) == TYPE_STRING:
			var pattern_str: String = String(pattern_raw)
			var pattern_id: StringName = StringName(pattern_str)
			_register_material(pattern_id, mat_tier, item_id)

		# 2) Implicit patterns for your tiered base materials:
		#    - cut_log_*    → timber_units  (and cut_log)
		#    - cut_stone_*  → stone_units   (and cut_stone)
		if mat_tier > 0 and item_str != "":
			if id_str.begins_with("cut_log_"):
				_register_material(&"timber_units", mat_tier, item_id)
				_register_material(&"cut_log", mat_tier, item_id)
			elif id_str.begins_with("cut_stone_"):
				_register_material(&"stone_units", mat_tier, item_id)
				_register_material(&"cut_stone", mat_tier, item_id)



func _reload_materials() -> void:
	_materials_by_pattern.clear()

	# Prefer JSON if present
	_load_materials_from_json(MATERIALS_JSON_PATH)

	print("[Construction] Loaded %d material patterns" % _materials_by_pattern.size())


func reload_blueprints() -> void:
	_blueprints.clear()
	_recipe_cache.clear()
	_reload_materials()

	# Load base shells (buildings)
	_load_json_into(_blueprints, BUILDINGS_JSON_PATH)

	# Load modules (flat entries)
	_load_json_into(_blueprints, MODULES_JSON_PATH)

	# Load construction materials as craftable blueprints too
	_load_json_into(_blueprints, MATERIALS_JSON_PATH)

	var base_count := 0
	var module_count := 0
	var material_count := 0

	for bp_v in _blueprints.values():
		if typeof(bp_v) != TYPE_DICTIONARY:
			continue
		var bp: Dictionary = bp_v
		var k := String(bp.get("kind", "")).to_lower()
		match k:
			"base":
				base_count += 1
			"module":
				module_count += 1
			"material":
				material_count += 1

	print("[Construction] Loaded %d blueprints (base=%d, module=%d, material=%d)" % [
		_blueprints.size(),
		base_count,
		module_count,
		material_count
	])

	emit_signal("construction_recipes_changed")


# -------------------------------------------------------------------
# Helpers – Bank / Items
# -------------------------------------------------------------------

# Example IDs:
#   "frame"      -> base_id="frame", forced_tier=0
#   "frame:t3"   -> base_id="frame", forced_tier=3
#   "frame:3"    -> base_id="frame", forced_tier=3
func _parse_tier_from_id(recipe_id: StringName) -> Dictionary:
	var s := String(recipe_id)
	var base := s
	var forced_tier := 0

	var colon := s.find(":")
	if colon != -1:
		base = s.substr(0, colon)
		var suffix := s.substr(colon + 1)
		if suffix.begins_with("t"):
			suffix = suffix.substr(1)
		var t := int(suffix)
		if t > 0:
			forced_tier = t

	return {
		"base_id": StringName(base),
		"forced_tier": forced_tier
	}


func _ensure_bank_with(methods: Array[StringName]) -> bool:
	if typeof(Bank) == TYPE_NIL:
		push_error("[Construction] Bank autoload missing.")
		return false
	for m in methods:
		if not Bank.has_method(m):
			push_error("[Construction] Bank is missing method: %s" % String(m))
			return false
	return true


func _resolve_item_label(id: StringName) -> String:
	var label := String(id)
	if typeof(Items) != TYPE_NIL \
	and Items.has_method("is_valid") \
	and Items.has_method("display_name") \
	and Items.is_valid(id):
		label = Items.display_name(id)
	return label


func _resolve_item_icon_path(id: StringName) -> Variant:
	if typeof(Items) != TYPE_NIL \
	and Items.has_method("is_valid") \
	and Items.has_method("get_icon_path") \
	and Items.is_valid(id):
		return Items.get_icon_path(id)
	return ""


# -------------------------------------------------------------------
# Tier helpers (build_tier / module_tier / mat_tier + material mapping)
# -------------------------------------------------------------------

# Returns the *index* of the "primary" tier for this blueprint (for now we use tier "1").
func _get_primary_tier_index(bp: Dictionary) -> int:
	var tiers_v: Variant = bp.get("tiers", null)
	if typeof(tiers_v) != TYPE_DICTIONARY:
		return 0

	var tiers: Dictionary = tiers_v as Dictionary

	# Prefer explicit "1" if present
	if tiers.has("1"):
		return 1

	# Otherwise pick the smallest integer key
	var best: int = 0
	for k in tiers.keys():
		var i: int = int(k)
		if i <= 0:
			continue
		if best == 0 or i < best:
			best = i
	return best


# Returns the Dictionary for the primary tier (tier 1) if present.
func _get_primary_tier(bp: Dictionary) -> Dictionary:
	var idx: int = _get_primary_tier_index(bp)
	if idx <= 0:
		return {}

	var tiers_v: Variant = bp.get("tiers", null)
	if typeof(tiers_v) != TYPE_DICTIONARY:
		return {}

	var tiers: Dictionary = tiers_v as Dictionary
	var key: String = str(idx)  # use str(), not String(idx)

	if not tiers.has(key):
		return {}

	var v: Variant = tiers[key]
	if typeof(v) != TYPE_DICTIONARY:
		return {}

	return v as Dictionary


func _get_build_tier(bp: Dictionary) -> int:
	# For base shells; if not present, infer from tiers, else 0.
	if bp.has("tier"):
		return int(bp.get("tier", 0))

	var idx: int = _get_primary_tier_index(bp)
	if idx > 0:
		return idx

	return 0


func _get_module_tier(bp: Dictionary) -> int:
	# For modules; fallback 1 if not set
	var mt: int = int(bp.get("module_tier", 0))
	if mt <= 0:
		mt = 1
	return mt


func _get_mat_tier(bp: Dictionary) -> int:
	# Priority:
	# 1) explicit mat_tier override on blueprint
	# 2) base tier (for shells via _get_build_tier)
	# 3) module_tier (for modules)
	var mt: int = int(bp.get("mat_tier", 0))
	if mt > 0:
		return mt

	var bt: int = _get_build_tier(bp)
	if bt > 0:
		return bt

	return _get_module_tier(bp)


func _resolve_material_item(pattern_id: StringName, mat_tier: int) -> StringName:
	if _materials_by_pattern.has(pattern_id):
		var tier_map_v: Variant = _materials_by_pattern[pattern_id]
		if typeof(tier_map_v) == TYPE_DICTIONARY:
			var tier_map: Dictionary = tier_map_v as Dictionary

			# Exact tier match
			if tier_map.has(mat_tier):
				return StringName(tier_map[mat_tier])

			# Fallback: highest tier <= mat_tier
			var best_tier: int = 0
			for t in tier_map.keys():
				var ti: int = int(t)
				if ti <= mat_tier and ti > best_tier:
					best_tier = ti

			if best_tier > 0:
				return StringName(tier_map[best_tier])

	# If no mapping is found, fall back to the pattern id
	return pattern_id


# -------------------------------------------------------------------
# Compose inputs from struct + hardware
# -------------------------------------------------------------------

# New: explicit mat_tier version
func _compose_inputs_for_tier(bp: Dictionary, mat_tier: int) -> Array:
	var inputs: Array = []

	# 1) New "tiers" → "inputs" structure (base shells)
	var tier_data: Dictionary = _get_primary_tier(bp)
	if not tier_data.is_empty():
		var inputs_block_v: Variant = tier_data.get("inputs", null)
		if typeof(inputs_block_v) == TYPE_DICTIONARY:
			var inputs_block: Dictionary = inputs_block_v as Dictionary

			# struct: [ { item, qty }, ... ]
			var struct_arr_v: Variant = inputs_block.get("struct", null)
			if typeof(struct_arr_v) == TYPE_ARRAY:
				var struct_arr: Array = struct_arr_v as Array
				for entry_v in struct_arr:
					if typeof(entry_v) != TYPE_DICTIONARY:
						continue
					var entry: Dictionary = entry_v as Dictionary

					var pattern_id: StringName = StringName(String(entry.get("item", "")))
					var qty: int = int(entry.get("qty", 0))
					if String(pattern_id) == "" or qty <= 0:
						continue

					var item_id: StringName = _resolve_material_item(pattern_id, mat_tier)
					inputs.append({
						"item": item_id,
						"qty": qty,
						"mat_tier": mat_tier,
						"pattern": pattern_id
					})

			# hardware: [ { item, qty }, ... ]
			var hardware_arr_v: Variant = inputs_block.get("hardware", null)
			if typeof(hardware_arr_v) == TYPE_ARRAY:
				var hardware_arr: Array = hardware_arr_v as Array
				for h_v in hardware_arr:
					if typeof(h_v) != TYPE_DICTIONARY:
						continue
					var h: Dictionary = h_v as Dictionary

					var pattern_id2: StringName = StringName(String(h.get("item", "")))
					var qty2: int = int(h.get("qty", 0))
					if String(pattern_id2) == "" or qty2 <= 0:
						continue

					var item_id2: StringName = _resolve_material_item(pattern_id2, mat_tier)
					inputs.append({
						"item": item_id2,
						"qty": qty2,
						"mat_tier": mat_tier,
						"pattern": pattern_id2
					})

		return inputs

	# 2) Fallback: old flat blueprint shape (materials/modules)
	var struct_map: Dictionary = bp.get("struct", {}) as Dictionary
	for key in struct_map.keys():
		var pattern_id_f: StringName = StringName(String(key))
		var qty_f: int = int(struct_map[key])
		if qty_f <= 0:
			continue

		var item_id_f: StringName = _resolve_material_item(pattern_id_f, mat_tier)
		inputs.append({
			"item": item_id_f,
			"qty": qty_f,
			"mat_tier": mat_tier,
			"pattern": pattern_id_f
		})

	var hardware_map: Dictionary = bp.get("hardware", {}) as Dictionary
	for key2 in hardware_map.keys():
		var pattern_id2_f: StringName = StringName(String(key2))
		var qty2_f: int = int(hardware_map[key2])
		if qty2_f <= 0:
			continue

		var item_id2_f: StringName = _resolve_material_item(pattern_id2_f, mat_tier)
		inputs.append({
			"item": item_id2_f,
			"qty": qty2_f,
			"mat_tier": mat_tier,
			"pattern": pattern_id2_f
		})

	return inputs


# Old signature kept for non-tiered callers
func _compose_inputs(bp: Dictionary) -> Array:
	var mat_tier := _get_mat_tier(bp)
	return _compose_inputs_for_tier(bp, mat_tier)


func _default_xp_for(inputs: Array, level_req: int) -> int:
	var total_qty := 0
	for inp_v in inputs:
		if typeof(inp_v) != TYPE_DICTIONARY:
			continue
		var inp: Dictionary = inp_v
		total_qty += int(inp.get("qty", 0))

	if total_qty <= 0:
		return max(1, level_req)

	var base: float = float(total_qty) * 0.5
	var level_factor: float = max(1.0, float(level_req) * 0.1)
	var xp_f: float = base * level_factor

	return max(1, int(round(xp_f)))


func _get_blueprint(id: StringName) -> Dictionary:
	var key := String(id)
	if not _blueprints.has(key):
		return {}
	var bp_v: Variant = _blueprints[key]
	if typeof(bp_v) != TYPE_DICTIONARY:
		return {}
	return bp_v as Dictionary


func _kind_to_group(kind: String) -> StringName:
	kind = kind.to_lower().strip_edges()
	match kind:
		"base":
			return &"building_base"
		"module":
			return &"building_module"
		"material":
			return &"building_material"
		_:
			return StringName("")


# -------------------------------------------------------------------
# Recipe construction (for Craft_Menu)
# -------------------------------------------------------------------
func _build_recipe_for(item_id: StringName) -> Dictionary:
	# item_id may be "frame" or "frame:t3"
	if _recipe_cache.has(item_id):
		return _recipe_cache[item_id]

	var parse := _parse_tier_from_id(item_id)
	var base_id: StringName = parse.get("base_id", item_id)
	var forced_mat_tier: int = int(parse.get("forced_tier", 0))

	var bp := _get_blueprint(base_id)
	if bp.is_empty():
		return {}

	var building_name := String(bp.get("building", String(base_id)))
	var part := String(bp.get("part", "")).strip_edges()
	var kind_str := String(bp.get("kind", "")).strip_edges().to_lower()
	var role_str := String(bp.get("role", ""))
	var linked_skill := String(bp.get("skill", ""))    # e.g. "herbalism", "cooking"

	# pattern can be a bool (for tiered struct recipes) OR a string (for material mapping).
	# We treat any non-empty string as "pattern = true" for general use.
	var is_pattern: bool = false
	var pattern_v: Variant = bp.get("pattern", false)
	match typeof(pattern_v):
		TYPE_BOOL:
			is_pattern = pattern_v
		TYPE_STRING:
			is_pattern = String(pattern_v) != ""
		_:
			is_pattern = false


	# Tiered data (for base shells)
	var tier_data := _get_primary_tier(bp)

	var label := building_name
	var desc := ""
	var level_req := 1

	if not tier_data.is_empty():
		# Use tier-specific label/desc/level
		label = String(tier_data.get("label", building_name))
		desc = String(tier_data.get("desc", ""))
		level_req = int(tier_data.get("level_req", 1))
	else:
		# Fallback for non-tier blueprints (e.g. modules + materials)
		if part != "":
			if part == "BASE":
				label = "%s – Base" % building_name
			else:
				label = "%s – %s" % [building_name, part]
		desc = String(bp.get("effect", ""))
		level_req = int(bp.get("req_con_lv", 1))

	var build_tier := _get_build_tier(bp)
	var module_tier := _get_module_tier(bp)
	var mat_tier := _get_mat_tier(bp)
	if forced_mat_tier > 0:
		mat_tier = forced_mat_tier

	# Compose inputs specifically for this tier
	var inputs: Array = _compose_inputs_for_tier(bp, mat_tier)
	var xp_gain := _default_xp_for(inputs, level_req)

	# Use base_id for icon; Items won't know about "frame:t3"
	var icon_val: Variant = _resolve_item_icon_path(base_id)
	var group_id: StringName = _kind_to_group(kind_str)

	# --- NEW: tier metadata for CraftMenu ---
	var tier_min := 0
	var tier_max := 0
	var tier_default := 0

	# Treat **construction struct parts** as tiered recipes:
	# these are entries from construction_materials.json with
	# kind: "material" AND a non-empty "part" (Frame, Floor, Roof, etc.).
	var is_struct_material := (kind_str == "material" and part != "")

	if is_struct_material:
		# You can override these from JSON with tier_min/tier_max per-part if you want.
		tier_min = int(bp.get("tier_min", 1))
		tier_max = int(bp.get("tier_max", 10))  # ⬅ default up to T10 now
		if tier_max < tier_min:
			tier_max = tier_min

		# Default selection = this recipe's mat_tier, or the minimum tier.
		if mat_tier > 0:
			tier_default = mat_tier
		else:
			tier_default = tier_min



	# IMPORTANT: we **don’t** append (T1) etc to the label anymore – the tier selector handles that.
	# If you really want the label to show a tier hint, we could update it dynamically
	# when _selected_tier changes instead.

	var rec := {
		# Recipe identity (what Craft_Menu / jobs use)
		"id": item_id,           # might be "frame" or "frame:t3"

		# Actual item that appears in the bank (kept as base ID for now)
		"output_id": base_id,

		"label": label,
		"desc": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"icon": icon_val,
		"inputs": inputs,
		"group": group_id,

		"building": building_name,
		"linked_skill": linked_skill,
		"kind": kind_str,
		"part": part,
		"role": role_str,
		"min_building_tier": int(bp.get("min_building_tier", 1)),
		"delta_lv": int(bp.get("delta_lv", 0)),
		"tier_reqs": bp.get("tier_reqs", []),
		"effect_raw": desc,

		# Tier metadata:
		"build_tier": build_tier,
		"module_tier": module_tier,
		"mat_tier": mat_tier,

		# NEW: UI tier selector metadata
		"tier_min": tier_min,
		"tier_max": tier_max,
		"tier_default": tier_default,

		# Extra helpers for the UI
		"base_id": base_id,
		"is_pattern": is_pattern
	}

	_recipe_cache[item_id] = rec
	return rec

# -------------------------------------------------------------------
# Public: recipe queries for UI / jobs
# -------------------------------------------------------------------

func get_all_recipes() -> Array:
	var out: Array = []
	for key in _blueprints.keys():
		var item_id := StringName(String(key))
		var rec := _build_recipe_for(item_id)
		if not rec.is_empty():
			out.append(rec)
	return out


func get_recipes_for_level(con_lv: int) -> Array:
	var out: Array = []
	for rec_v in get_all_recipes():
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = rec_v
		var level_req := int(rec.get("level_req", 1))
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
		var g: StringName = rec.get("group", StringName(""))
		if g == desired_group:
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


# -------------------------------------------------------------------
# Public: identity helpers for building/module "items"
# -------------------------------------------------------------------

func get_recipe_by_id(recipe_id: StringName) -> Dictionary:
	return _build_recipe_for(recipe_id)


func has_part(id: String) -> bool:
	return _blueprints.has(id)


func get_part_display_name(id: String) -> String:
	var bp: Dictionary = _blueprints.get(id, {}) as Dictionary
	if bp.is_empty():
		return id

	var building_name: String = String(bp.get("building", id))
	var part: String = String(bp.get("part", "")).strip_edges()

	if part == "":
		return building_name

	if part == "BASE":
		return "%s (Base)" % building_name

	return "%s – %s" % [building_name, part]


# -------------------------------------------------------------------
# Job entrypoint – used by VillagerManager
# -------------------------------------------------------------------
func do_construction_work(recipe_id: StringName) -> Dictionary:
	var result := {
		"xp": 0,
		"loot_desc": "",
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
	var xp_gain := int(rec.get("xp", 0))
	if xp_gain < 0:
		xp_gain = 0

	var kind_str := String(rec.get("kind", "")).to_lower()
	var part_str := String(rec.get("part", "")).strip_edges()

	# Decode base id for blueprint lookup (handles "frame:t3" etc.)
	var parse: Dictionary = _parse_tier_from_id(recipe_id)
	var base_bp_id: StringName = parse.get("base_id", recipe_id)

	# ---------------------------------------------------------
	# 1) Work out effective mat tier for MATERIAL recipes,
	#    based on the materials actually being consumed.
	#    (We use the LOWEST positive mat_tier as the bottleneck.)
	# ---------------------------------------------------------
	var mat_tier := int(rec.get("mat_tier", 0))

	if kind_str == "material":
		var best_tier: int = 0

		for inp_v in inputs:
			if typeof(inp_v) != TYPE_DICTIONARY:
				continue
			var inp: Dictionary = inp_v
			var in_item: StringName = inp.get("item", StringName(""))
			if String(in_item) == "":
				continue

			var in_bp := _get_blueprint(in_item)
			if in_bp.is_empty():
				continue

			var t := _get_mat_tier(in_bp)
			if t <= 0:
				continue

			# bottleneck: lowest positive tier wins
			if best_tier == 0 or t < best_tier:
				best_tier = t

		if best_tier > 0:
			mat_tier = best_tier

		if mat_tier <= 0:
			mat_tier = 1  # safety fallback

	# ---------------------------------------------------------
	# 2) Check you HAVE the materials
	# ---------------------------------------------------------
	for inp_v in inputs:
		if typeof(inp_v) != TYPE_DICTIONARY:
			continue
		var inp: Dictionary = inp_v
		var item_id: StringName = inp.get("item", StringName(""))
		var qty_needed := int(inp.get("qty", 0))

		if String(item_id) == "" or qty_needed <= 0:
			continue

		var have := int(Bank.amount(item_id))
		if have < qty_needed:
			result["loot_desc"] = "Not enough materials to construct %s." % label
			return result

	# ---------------------------------------------------------
	# 3) Spend materials
	# ---------------------------------------------------------
	for inp_v2 in inputs:
		if typeof(inp_v2) != TYPE_DICTIONARY:
			continue
		var inp2: Dictionary = inp_v2
		var item_id2: StringName = inp2.get("item", StringName(""))
		var qty2 := int(inp2.get("qty", 0))

		if String(item_id2) == "" or qty2 <= 0:
			continue

		Bank.take(item_id2, qty2)

	# ---------------------------------------------------------
	# 4) Decide **what item** we actually produce
	#     - For bases/modules: use output_id/base_id from the recipe
	#     - For struct materials: redirect via pattern + mat_tier
	# ---------------------------------------------------------
	var out_id: StringName = StringName(
		rec.get("output_id", String(rec.get("base_id", recipe_id)))
	)
	var out_qty := 1

	# Only treat CONSTRUCTION struct materials as tiered outputs:
	# kind: "material" AND non-empty "part" (Frame, Floor, Roof, etc.).
	if kind_str == "material" and part_str != "":
		var bp := _get_blueprint(base_bp_id)
		if not bp.is_empty():
			var pattern_raw: Variant = bp.get("pattern", "")
			if typeof(pattern_raw) == TYPE_STRING:
				var pattern_str: String = String(pattern_raw)
				if pattern_str != "":
					var pattern_id: StringName = StringName(pattern_str)
					out_id = _resolve_material_item(pattern_id, mat_tier)

	Bank.add(out_id, out_qty)

	result["xp"] = xp_gain

	var final_label := label
	if kind_str == "material":
		final_label = _resolve_item_label(out_id)

	result["loot_desc"] = "Constructed %d× %s." % [out_qty, final_label]

	emit_signal("item_constructed", out_id, out_qty)
	return result
