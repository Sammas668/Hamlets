# res://autoloads/SmithingSystem.gd
extends Node

signal smithing_recipes_changed

const BASE_ACTION_TIME := 2.4
# OPTION A: rename your json to smithing_items.json
# const SMITHING_ITEMS_PATH := "res://data/smithing_items.json"
# OPTION B: keep your current name:
const SMITHING_ITEMS_PATH := "res://data/specs/resources/smithing_items.json"

# -------------------------------------------------------------------
# Metal + bar definitions
# -------------------------------------------------------------------

const METALS := {
	&"bronze": {
		"m": 1, "smelt_xp": 10.0,
		"ore_inputs": [
			{ "item": Items.ORE_COPPER, "qty": 1 },
			{ "item": Items.ORE_TIN,    "qty": 1 },
		],
		"supports_gear": true,
	},
	&"iron": {
		"m": 15, "smelt_xp": 13.0,
		"ore_inputs": [ { "item": Items.ORE_IRON, "qty": 1 } ],
		"supports_gear": true,
	},
	&"steel": {
		"m": 30, "smelt_xp": 18.0,
		"ore_inputs": [
			{ "item": Items.ORE_IRON, "qty": 1 },
			{ "item": Items.ORE_COAL, "qty": 2 },
		],
		"supports_gear": true,
	},
	&"mithrite": {
		"m": 60, "smelt_xp": 30.0,
		"ore_inputs": [
			{ "item": Items.ORE_MITHRITE, "qty": 1 },
			{ "item": Items.ORE_COAL,     "qty": 4 },
		],
		"supports_gear": true,
	},
	&"adamantite": {
		"m": 70, "smelt_xp": 38.0,
		"ore_inputs": [
			{ "item": Items.ORE_ADAMANTITE, "qty": 1 },
			{ "item": Items.ORE_COAL,       "qty": 6 },
		],
		"supports_gear": true,
	},
	&"orichalcum": {
		"m": 85, "smelt_xp": 55.0,
		"ore_inputs": [
			{ "item": Items.ORE_ORICHALCUM, "qty": 1 },
			{ "item": Items.ORE_COAL,       "qty": 8 },
		],
		"supports_gear": true,
	},
	&"aether": {
		"m": 95, "smelt_xp": 80.0,
		"ore_inputs": [
			{ "item": Items.ORE_AETHER, "qty": 1 },
			{ "item": Items.ORE_COAL,   "qty": 10 },
		],
		"supports_gear": true,
	},
	&"silver": {
		"m": 40, "smelt_xp": 14.0,
		"ore_inputs": [ { "item": Items.ORE_SILVER, "qty": 1 } ],
		"supports_gear": false, # jewellery later
	},
	&"gold": {
		"m": 50, "smelt_xp": 22.0,
		"ore_inputs": [ { "item": Items.ORE_GOLD, "qty": 1 } ],
		"supports_gear": false, # jewellery later
	},
}

const BAR_ITEM_IDS := {
	&"bronze":     &"bar_bronze",
	&"iron":       &"bar_iron",
	&"steel":      &"bar_steel",
	&"mithrite":   &"bar_mithrite",
	&"adamantite": &"bar_adamantite",
	&"orichalcum": &"bar_orichalcum",
	&"aether":     &"bar_aether",
	&"silver":     &"bar_silver",
	&"gold":       &"bar_gold",
}

# -------------------------------------------------------------------
# Family numbers keyed by family_id
# -------------------------------------------------------------------

const FAMILY_STATS := {
	&"pickaxe": { "bars": 2, "delta_lv": 1, "xp_mult": 2.0, "output_qty": 1 },
	&"axe":     { "bars": 2, "delta_lv": 1, "xp_mult": 2.0, "output_qty": 1 },
	&"sickle":  { "bars": 2, "delta_lv": 1, "xp_mult": 2.0, "output_qty": 1 },
	&"hoe":     { "bars": 2, "delta_lv": 1, "xp_mult": 2.0, "output_qty": 1 },
	&"knife":   { "bars": 1, "delta_lv": 0, "xp_mult": 1.0, "output_qty": 1 },
	&"hammer":  { "bars": 1, "delta_lv": 1, "xp_mult": 1.0, "output_qty": 1 },
	&"chisel":  { "bars": 1, "delta_lv": 3, "xp_mult": 1.0, "output_qty": 1 },

	&"fishing_net":     { "bars": 1, "delta_lv": 0, "xp_mult": 1.0, "output_qty": 1 },
	&"fishing_rod":     { "bars": 1, "delta_lv": 1, "xp_mult": 1.0, "output_qty": 1 },
	&"fishing_harpoon": { "bars": 2, "delta_lv": 4, "xp_mult": 2.0, "output_qty": 1 },

	&"nails":             { "bars": 1, "delta_lv": 0,  "xp_mult": 1.0, "output_qty": 15 },
	&"rivets":            { "bars": 1, "delta_lv": 0,  "xp_mult": 1.0, "output_qty": 15 },
	&"bolts":             { "bars": 1, "delta_lv": 0,  "xp_mult": 1.0, "output_qty": 10 },
	&"spikes":            { "bars": 1, "delta_lv": 3,  "xp_mult": 1.0, "output_qty": 10 },
	&"straps":            { "bars": 1, "delta_lv": 5,  "xp_mult": 1.0, "output_qty": 3 },
	&"hinges":            { "bars": 2, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 4 },
	&"brackets":          { "bars": 2, "delta_lv": 6,  "xp_mult": 2.0, "output_qty": 2 },
	&"chains":            { "bars": 2, "delta_lv": 8,  "xp_mult": 2.0, "output_qty": 1 },
	&"reinforcement_rod": { "bars": 2, "delta_lv": 8,  "xp_mult": 2.0, "output_qty": 1 },
	&"flat_plate":        { "bars": 3, "delta_lv": 10, "xp_mult": 3.0, "output_qty": 1 },
	&"beam_shoe":         { "bars": 2, "delta_lv": 10, "xp_mult": 2.0, "output_qty": 2 },
	&"gear":              { "bars": 3, "delta_lv": 12, "xp_mult": 3.0, "output_qty": 1 },
	&"counterweight":     { "bars": 4, "delta_lv": 14, "xp_mult": 4.0, "output_qty": 1 },
	&"lockwork":          { "bars": 4, "delta_lv": 16, "xp_mult": 4.0, "output_qty": 1 },

	&"dagger":           { "bars": 1, "delta_lv": 0,  "xp_mult": 1.0, "output_qty": 1 },
	&"mace":             { "bars": 1, "delta_lv": 1,  "xp_mult": 1.0, "output_qty": 1 },
	&"shortsword":       { "bars": 1, "delta_lv": 1,  "xp_mult": 1.0, "output_qty": 1 },
	&"scimitar":         { "bars": 2, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 1 },
	&"longsword":        { "bars": 2, "delta_lv": 5,  "xp_mult": 2.0, "output_qty": 1 },
	&"warhammer":        { "bars": 3, "delta_lv": 8,  "xp_mult": 3.0, "output_qty": 1 },
	&"battleaxe":        { "bars": 3, "delta_lv": 9,  "xp_mult": 3.0, "output_qty": 1 },
	&"two_handed_sword": { "bars": 3, "delta_lv": 13, "xp_mult": 3.0, "output_qty": 1 },
	&"spear":            { "bars": 1, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 1 },
	&"hasta":            { "bars": 1, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 1 },

	&"med_helm":      { "bars": 1, "delta_lv": 2,  "xp_mult": 1.0, "output_qty": 1 },
	&"full_helm":     { "bars": 2, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 1 },
	&"chainbody":     { "bars": 3, "delta_lv": 6,  "xp_mult": 3.0, "output_qty": 1 },
	&"gauntlets":     { "bars": 1, "delta_lv": 4,  "xp_mult": 1.0, "output_qty": 1 },
	&"square_shield": { "bars": 2, "delta_lv": 5,  "xp_mult": 2.0, "output_qty": 1 },
	&"kiteshield":    { "bars": 3, "delta_lv": 8,  "xp_mult": 3.0, "output_qty": 1 },
	&"platelegs":     { "bars": 3, "delta_lv": 10, "xp_mult": 3.0, "output_qty": 1 },
	&"platebody":     { "bars": 5, "delta_lv": 17, "xp_mult": 5.0, "output_qty": 1 },
}

# -------------------------------------------------------------------
# Runtime-built tables from JSON
# -------------------------------------------------------------------

var FAMILY_GROUPS: Dictionary = {
	&"tool": {}, &"fishing": {}, &"hardware": {}, &"weapon": {}, &"armour": {}
}

var _metal_order: Array[StringName] = []
var _cfg_metals: Dictionary = {}
var _cfg_families: Dictionary = {}

# NEW: optional JSON keys
var _cfg_version: int = 0
var _icon_root: String = ""


func _ready() -> void:
	randomize()
	_load_smithing_items_json()
	emit_signal("smithing_recipes_changed")


func _ensure_bank_with(methods: Array[StringName]) -> bool:
	if typeof(Bank) == TYPE_NIL:
		push_error("[Smithing] Bank autoload missing.")
		return false
	for m in methods:
		if not Bank.has_method(m):
			push_error("[Smithing] Bank is missing method: %s" % String(m))
			return false
	return true

func _load_smithing_items_json() -> void:
	if not FileAccess.file_exists(SMITHING_ITEMS_PATH):
		push_warning("[Smithing] Missing %s. Using fallback ordering." % SMITHING_ITEMS_PATH)
		_build_fallback_orders()
		return

	var f: FileAccess = FileAccess.open(SMITHING_ITEMS_PATH, FileAccess.READ)
	if f == null:
		push_error("[Smithing] Failed to open %s" % SMITHING_ITEMS_PATH)
		_build_fallback_orders()
		return

	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[Smithing] JSON parse failed (check trailing commas): %s" % SMITHING_ITEMS_PATH)
		_build_fallback_orders()
		return

	var root: Dictionary = parsed as Dictionary

	# Optional keys
	_cfg_version = int(root.get("version", 0))
	_icon_root = String(root.get("icon_root", "")).strip_edges()

	# IMPORTANT: .get() returns Variant → type these locals
	var metals_v: Variant = root.get("metals")
	_cfg_metals = metals_v as Dictionary if typeof(metals_v) == TYPE_DICTIONARY else {}

	var families_v: Variant = root.get("families")
	_cfg_families = families_v as Dictionary if typeof(families_v) == TYPE_DICTIONARY else {}

	_build_metal_order_from_json()
	_build_family_groups_from_json()


func _build_fallback_orders() -> void:
	_metal_order = []
	for mk in METALS.keys():
		_metal_order.append(mk)

	FAMILY_GROUPS = { &"tool": {}, &"fishing": {}, &"hardware": {}, &"weapon": {}, &"armour": {} }


func _build_metal_order_from_json() -> void:
	_metal_order = []

	var keys: Array = _cfg_metals.keys()
	keys.sort_custom(Callable(self, "_sort_metal_key_by_tier"))

	for k in keys:
		var mk := StringName(String(k))
		if METALS.has(mk):
			_metal_order.append(mk)

	if _metal_order.is_empty():
		for mk2 in METALS.keys():
			_metal_order.append(mk2)


func _sort_metal_key_by_tier(a: Variant, b: Variant) -> bool:
	var ad: Dictionary = _cfg_metals.get(a, {}) if typeof(_cfg_metals.get(a, {})) == TYPE_DICTIONARY else {}
	var bd: Dictionary = _cfg_metals.get(b, {}) if typeof(_cfg_metals.get(b, {})) == TYPE_DICTIONARY else {}
	return int(ad.get("tier", 9999)) < int(bd.get("tier", 9999))


func _build_family_groups_from_json() -> void:
	FAMILY_GROUPS = { &"tool": {}, &"fishing": {}, &"hardware": {}, &"weapon": {}, &"armour": {} }

	for fam_key: Variant in _cfg_families.keys():
		var fam_id: StringName = StringName(String(fam_key))

		if not FAMILY_STATS.has(fam_id):
			continue

		var fam_def_v: Variant = _cfg_families.get(fam_key)
		if typeof(fam_def_v) != TYPE_DICTIONARY:
			continue
		var fam_def: Dictionary = fam_def_v

		var group: StringName = StringName(String(fam_def.get("group", "")))
		if not FAMILY_GROUPS.has(group):
			continue

		FAMILY_GROUPS[group][fam_id] = FAMILY_STATS[fam_id]


func _bar_item_id(metal: StringName) -> StringName:
	if BAR_ITEM_IDS.has(metal):
		return BAR_ITEM_IDS[metal]
	return StringName("bar_%s" % String(metal))


func _xp_per_bar_for_items(metal: StringName) -> float:
	if not METALS.has(metal):
		return 0.0
	var def: Dictionary = METALS[metal]
	return float(def.get("smelt_xp", 0.0)) * 1.25


func _resolve_item_label(id: StringName) -> String:
	var label := String(id)
	if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(id):
		label = Items.display_name(id)
	return label


func _resolve_item_icon_path(id: StringName) -> Variant:
	# Primary: Items registry
	if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("get_icon_path") and Items.is_valid(id):
		return Items.get_icon_path(id)

	# Fallback: icon_root from JSON (if you want the system to work even before Items.gd is complete)
	if _icon_root != "":
		# simplest convention: res://.../<id>.png
		var p := "%s/%s.png" % [_icon_root.rstrip("/"), String(id)]
		if ResourceLoader.exists(p):
			return p

	return ""


func _smithing_level_req_for(metal: StringName, delta_lv: int) -> int:
	if not METALS.has(metal):
		return 1
	var m: int = int((METALS[metal] as Dictionary).get("m", 1))
	return clampi(m + delta_lv, 1, 99)


func _output_item_id(family_id: StringName, metal: StringName) -> StringName:
	return StringName("%s_%s" % [String(family_id), String(metal)])

# -------------------------------------------------------------------
# Smelting
# -------------------------------------------------------------------

func can_smelt(metal: StringName) -> bool:
	if not METALS.has(metal):
		return false
	if not _ensure_bank_with([&"amount"]):
		return false

	var def: Dictionary = METALS[metal]
	var inputs: Array = def.get("ore_inputs", [])
	for row_v in inputs:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var item_id: StringName = row.get("item", StringName(""))
		var qty: int = int(row.get("qty", 0))
		if item_id == StringName("") or qty <= 0:
			continue
		if int(Bank.amount(item_id)) < qty:
			return false
	return true


func smelt_bar(metal: StringName) -> Dictionary:
	var result := { "xp": 0, "loot_desc": "" }

	if not METALS.has(metal):
		result["loot_desc"] = "Unknown metal for smelting."
		return result

	if not _ensure_bank_with([&"amount", &"take", &"add"]):
		result["loot_desc"] = "Bank API missing amount/take/add."
		return result

	var def: Dictionary = METALS[metal]
	var inputs: Array = def.get("ore_inputs", [])

	for row_v in inputs:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var item_id: StringName = row.get("item", StringName(""))
		var qty: int = int(row.get("qty", 0))
		if item_id == StringName("") or qty <= 0:
			continue
		if int(Bank.amount(item_id)) < qty:
			result["loot_desc"] = "Not enough ore to smelt this bar."
			return result

	for row_v2 in inputs:
		if typeof(row_v2) != TYPE_DICTIONARY:
			continue
		var row2: Dictionary = row_v2
		var item_id2: StringName = row2.get("item", StringName(""))
		var qty2: int = int(row2.get("qty", 0))
		if item_id2 == StringName("") or qty2 <= 0:
			continue
		Bank.take(item_id2, qty2)

	var bar_id: StringName = _bar_item_id(metal)
	Bank.add(bar_id, 1)

	var xp_gain: int = int(round(float(def.get("smelt_xp", 0.0))))

	var bar_label := _resolve_item_label(bar_id)
	if bar_label == String(bar_id):
		bar_label = "%s bar" % String(metal).capitalize()

	result["xp"] = xp_gain
	result["loot_desc"] = "Smelted 1× %s." % bar_label
	return result

# -------------------------------------------------------------------
# Smithing items
# -------------------------------------------------------------------

func _metal_tier(metal: StringName) -> int:
	# Prefer smithing_items.json: metals.<metal>.tier
	var md_v: Variant = _cfg_metals.get(metal)
	if typeof(md_v) == TYPE_DICTIONARY:
		return int((md_v as Dictionary).get("tier", 0))

	# Fallback: tier by order (bronze=1, iron=2, ...)
	var idx := _metal_order.find(metal)
	if idx != -1:
		return idx + 1

	return 0


func _family_use_skill(family_id: StringName) -> StringName:
	# Optional but nice: families.<family>.use_skill
	var fd_v: Variant = _cfg_families.get(family_id)
	if typeof(fd_v) == TYPE_DICTIONARY:
		var s := String((fd_v as Dictionary).get("use_skill", "")).strip_edges()
		if s != "":
			return StringName(s)
	return StringName()

func _smith_item(group: StringName, family_id: StringName, metal: StringName) -> Dictionary:
	var result := { "xp": 0, "loot_desc": "" }

	if not METALS.has(metal):
		result["loot_desc"] = "Unknown metal."
		return result

	var metal_def: Dictionary = METALS[metal]
	if not bool(metal_def.get("supports_gear", false)):
		result["loot_desc"] = "This metal cannot be used for smithing gear."
		return result

	if not FAMILY_GROUPS.has(group):
		result["loot_desc"] = "Unknown smithing category."
		return result

	var fam_table: Dictionary = FAMILY_GROUPS[group]
	if not fam_table.has(family_id):
		result["loot_desc"] = "Unknown smithing recipe."
		return result

	if not _ensure_bank_with([&"amount", &"take", &"add"]):
		result["loot_desc"] = "Bank API missing amount/take/add."
		return result

	var fam: Dictionary = fam_table[family_id]
	var bars_needed: int = int(fam.get("bars", 0))
	if bars_needed <= 0:
		result["loot_desc"] = "Invalid bar cost."
		return result

	var bar_id: StringName = _bar_item_id(metal)
	if int(Bank.amount(bar_id)) < bars_needed:
		result["loot_desc"] = "Not enough bars."
		return result

	Bank.take(bar_id, bars_needed)

	var out_id: StringName = _output_item_id(family_id, metal)
	var out_qty: int = int(fam.get("output_qty", 1))
	if out_qty <= 0:
		out_qty = 1
	Bank.add(out_id, out_qty)

	var xp_gain: int = int(round(_xp_per_bar_for_items(metal) * float(fam.get("xp_mult", float(bars_needed)))))

	var label := _resolve_item_label(out_id)
	if label == String(out_id):
		label = "%s %s" % [String(metal).capitalize().strip_edges(), String(family_id).replace("_", " ")]

	result["xp"] = xp_gain
	result["loot_desc"] = ("Forged 1× %s." % label) if out_qty == 1 else ("Forged %d× %s." % [out_qty, label])
	return result

# -------------------------------------------------------------------
# Recipe generation
# -------------------------------------------------------------------
func _make_smelt_recipe(metal: StringName) -> Dictionary:
	if not METALS.has(metal):
		return {}

	var def: Dictionary = METALS[metal]
	var m: int = int(def.get("m", 1))
	var smelt_xp: float = float(def.get("smelt_xp", 0.0))
	var bar_id: StringName = _bar_item_id(metal)

	var bar_label := _resolve_item_label(bar_id)
	if bar_label == String(bar_id):
		bar_label = "%s bar" % String(metal).capitalize()

	var tier: int = _metal_tier(metal)

	return {
		"id": StringName("smelt:%s" % String(metal)),
		"label": "Smelt %s" % bar_label,
		"desc": "Smelt ore into %s." % bar_label,
		"level_req": m,
		"xp": int(round(smelt_xp)),
		"icon": _resolve_item_icon_path(bar_id),
		"inputs": def.get("ore_inputs", []),
		"output_item": bar_id,
		"output_qty": 1,

		# NEW
		"tier": tier,
		"use_skill": &"smithing",
	}

func _make_item_recipe(group: StringName, family_id: StringName, metal: StringName) -> Dictionary:
	if not METALS.has(metal):
		return {}

	var metal_def: Dictionary = METALS[metal]
	if not bool(metal_def.get("supports_gear", false)):
		return {}

	if not FAMILY_GROUPS.has(group):
		return {}
	var fam_table: Dictionary = FAMILY_GROUPS[group]
	if not fam_table.has(family_id):
		return {}

	var fam: Dictionary = fam_table[family_id]
	var bars: int = int(fam.get("bars", 0))
	if bars <= 0:
		return {}

	var level_req: int = _smithing_level_req_for(metal, int(fam.get("delta_lv", 0)))
	var xp_gain: int = int(round(_xp_per_bar_for_items(metal) * float(fam.get("xp_mult", float(bars)))))

	var out_qty: int = int(fam.get("output_qty", 1))
	if out_qty <= 0:
		out_qty = 1

	var bar_id: StringName = _bar_item_id(metal)
	var out_id: StringName = _output_item_id(family_id, metal)

	var label := "%s %s" % [String(metal).capitalize().strip_edges(), String(family_id).replace("_", " ")]
	var desc := "Smith %s using %d× %s bars." % [label, bars, String(metal).capitalize().strip_edges()]

	var tier: int = _metal_tier(metal)
	var use_skill: StringName = _family_use_skill(family_id)

	return {
		"id": StringName("forge:%s:%s:%s" % [String(group), String(family_id), String(metal)]),
		"label": label,
		"desc": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"icon": _resolve_item_icon_path(out_id),
		"inputs": [ { "item": bar_id, "qty": bars } ],
		"output_item": out_id,
		"output_qty": out_qty,

		# NEW
		"tier": tier,
		"use_skill": use_skill,
	}


func get_all_smelt_recipes() -> Array:
	var out: Array = []
	var metals := _metal_order if _metal_order.size() > 0 else METALS.keys()
	for metal in metals:
		var rec := _make_smelt_recipe(metal)
		if not rec.is_empty():
			out.append(rec)
	return out


func get_all_item_recipes() -> Array:
	var out: Array = []
	var metals := _metal_order if _metal_order.size() > 0 else METALS.keys()

	for group in FAMILY_GROUPS.keys():
		var fam_table: Dictionary = FAMILY_GROUPS[group]
		for family_id in fam_table.keys():
			for metal in metals:
				var rec := _make_item_recipe(group, family_id, metal)
				if not rec.is_empty():
					out.append(rec)
	return out


func get_recipes_for_level(smith_lv: int) -> Array:
	var out: Array = []
	for rec in get_all_smelt_recipes():
		if int(rec.get("level_req", 1)) <= smith_lv:
			out.append(rec)
	for rec2 in get_all_item_recipes():
		if int(rec2.get("level_req", 1)) <= smith_lv:
			out.append(rec2)
	return out


func do_smithing_work(recipe_id: StringName) -> Dictionary:
	var id_str := String(recipe_id)

	if id_str.begins_with("smelt:"):
		return smelt_bar(StringName(id_str.substr("smelt:".length())))

	if id_str.begins_with("forge:"):
		var parts := id_str.split(":")
		if parts.size() >= 4:
			return _smith_item(StringName(parts[1]), StringName(parts[2]), StringName(parts[3]))

	return { "xp": 0, "loot_desc": "Unknown smithing recipe." }
