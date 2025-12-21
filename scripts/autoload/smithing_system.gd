# res://autoloads/SmithingSystem.gd
extends Node

## SmithingSystem:
## - Smelts bars from Mining ores.
## - Smiths bars into equipment (tools, fishing tools, hardware, weapons, armour).
## - All costs/XP/reqs are generated from pattern tables (no giant hand-coded list).
## - Returns { "xp": int, "loot_desc": String } for villager jobs.
##
## Usage:
##  - CraftMenu asks get_*_recipes_for_level(smith_lv)
##  - Villager job calls do_smithing_work(recipe_id)
##  - BASE_ACTION_TIME is the per-action time for job system.

signal smithing_recipes_changed

const BASE_ACTION_TIME := 2.4  # seconds per smithing action

# -------------------------------------------------------------------
# Metal + bar definitions
# -------------------------------------------------------------------
# metal key = StringName("bronze"), "iron", etc.
# M = base level (same as Mining req for ore).
# smelt_xp = XP per bar when smelting.
# ore_inputs = cost in ores for 1 bar.
# supports_gear: whether this metal can be used for tools/gear (no for Silver/Gold).

const METALS := {
	&"bronze": {
		"m": 1,
		"smelt_xp": 10.0,
		"ore_inputs": [
			{ "item": Items.ORE_COPPER, "qty": 1 },
			{ "item": Items.ORE_TIN,    "qty": 1 },
		],
		"supports_gear": true,
	},
	&"iron": {
		"m": 15,
		"smelt_xp": 13.0,
		"ore_inputs": [
			{ "item": Items.ORE_IRON, "qty": 1 },
		],
		"supports_gear": true,
	},
	&"steel": {
		"m": 30,
		"smelt_xp": 18.0,
		"ore_inputs": [
			{ "item": Items.ORE_IRON, "qty": 1 },
			{ "item": Items.ORE_COAL, "qty": 2 },
		],
		"supports_gear": true,
	},
	&"mithrite": {
		"m": 60,
		"smelt_xp": 30.0,
		"ore_inputs": [
			{ "item": Items.ORE_MITHRITE, "qty": 1 },
			{ "item": Items.ORE_COAL,     "qty": 4 },
		],
		"supports_gear": true,
	},
	&"adamantite": {
		"m": 70,
		"smelt_xp": 38.0,
		"ore_inputs": [
			{ "item": Items.ORE_ADAMANTITE, "qty": 1 },
			{ "item": Items.ORE_COAL,       "qty": 6 },
		],
		"supports_gear": true,
	},
	&"orichalcum": {
		"m": 85,
		"smelt_xp": 55.0,
		"ore_inputs": [
			{ "item": Items.ORE_ORICHALCUM, "qty": 1 },
			{ "item": Items.ORE_COAL,       "qty": 8 },
		],
		"supports_gear": true,
	},
	&"aether": {
		"m": 95,
		"smelt_xp": 80.0,
		"ore_inputs": [
			{ "item": Items.ORE_AETHER, "qty": 1 },
			{ "item": Items.ORE_COAL,   "qty": 10 }, # later: add "flux"
		],
		"supports_gear": true,
	},
	&"silver": {
		"m": 40,
		"smelt_xp": 14.0,
		"ore_inputs": [
			{ "item": Items.ORE_SILVER, "qty": 1 },
		],
		"supports_gear": false,   # jewellery later
	},
	&"gold": {
		"m": 50,
		"smelt_xp": 22.0,
		"ore_inputs": [
			{ "item": Items.ORE_GOLD, "qty": 1 },
		],
		"supports_gear": false,   # jewellery later
	},
}

# Bar item IDs (string-based; Items.gd should define matching entries later).
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
# Family tables (tools, fishing, hardware, weapons, armour)
# All use the same pattern:
#  - bars:      number of bars consumed
#  - delta_lv:  level offset: req = M + delta_lv
#  - xp_mult:   XP multiplier: xp = xp_mult * XP_per_bar(metal)
#  - output_qty per craft
# -------------------------------------------------------------------

const FAMILY_GROUPS := {
	# -----------------------------
	# 3.1 Core gathering tools
	# -----------------------------
	&"tool": {
		&"pickaxe": {
			"bars": 2, "delta_lv": 1, "xp_mult": 2.0, "output_qty": 1,
		},
		&"axe": {
			"bars": 2, "delta_lv": 1, "xp_mult": 2.0, "output_qty": 1,
		},
		&"sickle": {
			"bars": 2, "delta_lv": 1, "xp_mult": 2.0, "output_qty": 1,
		},
		&"hoe": {
			"bars": 2, "delta_lv": 1, "xp_mult": 2.0, "output_qty": 1,
		},
		&"knife": {
			"bars": 1, "delta_lv": 0, "xp_mult": 1.0, "output_qty": 1,
		},
		&"hammer": {
			"bars": 1, "delta_lv": 1, "xp_mult": 1.0, "output_qty": 1,
		},
		&"chisel": {
			"bars": 1, "delta_lv": 3, "xp_mult": 1.0, "output_qty": 1,
		},
	},

	# -----------------------------
	# 3.2 Fishing tools
	# -----------------------------
	&"fishing": {
		&"fishing_net": {
			"bars": 1, "delta_lv": 0, "xp_mult": 1.0, "output_qty": 1,
			# Tailoring mats TBD – leave empty for now
		},
		&"fishing_rod": {
			"bars": 1, "delta_lv": 1, "xp_mult": 1.0, "output_qty": 1,
		},
		&"fishing_harpoon": {
			"bars": 2, "delta_lv": 4, "xp_mult": 2.0, "output_qty": 1,
		},
	},

	# -----------------------------
	# 4. Construction hardware
	# -----------------------------
	&"hardware": {
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
	},

	# -----------------------------
	# 5. Melee weapons
	# -----------------------------
	&"weapon": {
		&"dagger":           { "bars": 1, "delta_lv": 0,  "xp_mult": 1.0, "output_qty": 1 },
		&"mace":             { "bars": 1, "delta_lv": 1,  "xp_mult": 1.0, "output_qty": 1 },
		&"shortsword":       { "bars": 1, "delta_lv": 1,  "xp_mult": 1.0, "output_qty": 1 },
		&"sword":            { "bars": 1, "delta_lv": 3,  "xp_mult": 1.0, "output_qty": 1 },
		&"scimitar":         { "bars": 2, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 1 },
		&"longsword":        { "bars": 2, "delta_lv": 5,  "xp_mult": 2.0, "output_qty": 1 },
		&"warhammer":        { "bars": 3, "delta_lv": 8,  "xp_mult": 3.0, "output_qty": 1 },
		&"battleaxe":        { "bars": 3, "delta_lv": 9,  "xp_mult": 3.0, "output_qty": 1 },
		&"two_handed_sword": { "bars": 3, "delta_lv": 13, "xp_mult": 3.0, "output_qty": 1 },
		# OSRS quirk: spear/hasta = 2× XP per bar despite 1 bar
		&"spear":            { "bars": 1, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 1 },
		&"hasta":            { "bars": 1, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 1 },
	},

	# -----------------------------
	# 6. Armour
	# -----------------------------
	&"armour": {
		&"med_helm":     { "bars": 1, "delta_lv": 2,  "xp_mult": 1.0, "output_qty": 1 },
		&"full_helm":    { "bars": 2, "delta_lv": 4,  "xp_mult": 2.0, "output_qty": 1 },
		&"chainbody":    { "bars": 3, "delta_lv": 6,  "xp_mult": 3.0, "output_qty": 1 },
		&"square_shield":{ "bars": 2, "delta_lv": 5,  "xp_mult": 2.0, "output_qty": 1 },
		&"kiteshield":   { "bars": 3, "delta_lv": 8,  "xp_mult": 3.0, "output_qty": 1 },
		&"platelegs":    { "bars": 3, "delta_lv": 10, "xp_mult": 3.0, "output_qty": 1 },
		&"plateskirt":   { "bars": 3, "delta_lv": 10, "xp_mult": 3.0, "output_qty": 1 },
		&"platebody":    { "bars": 5, "delta_lv": 17, "xp_mult": 5.0, "output_qty": 1 },
	},
}


# -------------------------------------------------------------------
# Internal helpers
# -------------------------------------------------------------------

func _ready() -> void:
	randomize()


func _ensure_bank_with(methods: Array[StringName]) -> bool:
	if typeof(Bank) == TYPE_NIL:
		push_error("[Smithing] Bank autoload missing.")
		return false
	for m in methods:
		if not Bank.has_method(m):
			push_error("[Smithing] Bank is missing method: %s" % String(m))
			return false
	return true


func _bar_item_id(metal: StringName) -> StringName:
	if BAR_ITEM_IDS.has(metal):
		return BAR_ITEM_IDS[metal]
	# Fallback: pattern "bar_bronze" etc.
	return StringName("bar_%s" % String(metal))


func _xp_per_bar_for_items(metal: StringName) -> float:
	if not METALS.has(metal):
		return 0.0
	var def: Dictionary = METALS[metal]
	var smelt_xp: float = float(def.get("smelt_xp", 0.0))
	return smelt_xp * 1.25


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


func _smithing_level_req_for(metal: StringName, delta_lv: int) -> int:
	if not METALS.has(metal):
		return 1
	var def: Dictionary = METALS[metal]
	var m: int = int(def.get("m", 1))
	return clampi(m + delta_lv, 1, 99)


func _output_item_id(group: StringName, family_id: StringName, metal: StringName) -> StringName:
	# Simple, readable pattern:
	#   tool:    "pickaxe_bronze"
	#   weapon:  "sword_steel"
	#   armour:  "platebody_orichalcum"
	#   hardware:"nails_mithrite"
	#   fishing: "fishing_rod_bronze"
	return StringName("%s_%s" % [String(family_id), String(metal)])


# -------------------------------------------------------------------
# Smelting: ores -> bars
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


## Smelt one bar of `metal`.
## Returns { "xp": int, "loot_desc": String }.
func smelt_bar(metal: StringName) -> Dictionary:
	var result := {
		"xp": 0,
		"loot_desc": "",
	}

	if not METALS.has(metal):
		result["loot_desc"] = "Unknown metal for smelting."
		return result

	if not _ensure_bank_with([&"amount", &"take", &"add"]):
		result["loot_desc"] = "Bank API missing amount/take/add."
		return result

	var def: Dictionary = METALS[metal]
	var inputs: Array = def.get("ore_inputs", [])

	# Check we have all costs
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

	# Spend ores
	for row_v2 in inputs:
		if typeof(row_v2) != TYPE_DICTIONARY:
			continue
		var row2: Dictionary = row_v2
		var item_id2: StringName = row2.get("item", StringName(""))
		var qty2: int = int(row2.get("qty", 0))
		if item_id2 == StringName("") or qty2 <= 0:
			continue
		Bank.take(item_id2, qty2)

	# Add bar
	var bar_id: StringName = _bar_item_id(metal)
	Bank.add(bar_id, 1)

	var smelt_xp: float = float(def.get("smelt_xp", 0.0))
	var xp_gain: int = int(round(smelt_xp))

	var bar_label := _resolve_item_label(bar_id)
	if bar_label == String(bar_id):
		bar_label = "%s bar" % String(metal).capitalize()

	result["xp"] = xp_gain
	result["loot_desc"] = "Smelted 1× %s." % bar_label
	return result


# -------------------------------------------------------------------
# Smithing items: bars -> gear
# -------------------------------------------------------------------

## Smith one item from bars, using group/family/metal (e.g. weapon/sword/orichalcum).
## Returns { "xp": int, "loot_desc": String }.
func _smith_item(group: StringName, family_id: StringName, metal: StringName) -> Dictionary:
	var result := {
		"xp": 0,
		"loot_desc": "",
	}

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

	# Spend bars
	Bank.take(bar_id, bars_needed)

	# Output item
	var out_id: StringName = _output_item_id(group, family_id, metal)
	var out_qty: int = int(fam.get("output_qty", 1))
	if out_qty <= 0:
		out_qty = 1
	Bank.add(out_id, out_qty)

	# XP
	var xp_per_bar: float = _xp_per_bar_for_items(metal)
	var xp_mult: float = float(fam.get("xp_mult", float(bars_needed)))
	var xp_gain: int = int(round(xp_per_bar * xp_mult))

	var label := _resolve_item_label(out_id)
	if label == String(out_id):
		# Fallback readable label if Items doesn't know this id yet
		label = "%s %s" % [String(metal).capitalize().strip_edges(), String(family_id).replace("_", " ")]

	result["xp"] = xp_gain
	if out_qty == 1:
		result["loot_desc"] = "Forged 1× %s." % label
	else:
		result["loot_desc"] = "Forged %d× %s." % [out_qty, label]
	return result


# -------------------------------------------------------------------
# Recipe generation for CraftMenu / TaskPicker
# -------------------------------------------------------------------

## Smelting recipe helper
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

	var inputs: Array = def.get("ore_inputs", [])
	var icon_val: Variant = _resolve_item_icon_path(bar_id)

	return {
		"id": StringName("smelt:%s" % String(metal)),
		"label": "Smelt %s" % bar_label,
		"desc": "Smelt ore into %s." % bar_label,
		"level_req": m,
		"xp": int(round(smelt_xp)),
		"icon": icon_val,
		"inputs": inputs,
		"output_item": bar_id,
		"output_qty": 1,
	}


## Generic item recipe helper (tools, hardware, weapons, armour, fishing)
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

	var delta_lv: int = int(fam.get("delta_lv", 0))
	var level_req: int = _smithing_level_req_for(metal, delta_lv)
	var xp_mult: float = float(fam.get("xp_mult", float(bars)))
	var xp_per_bar: float = _xp_per_bar_for_items(metal)
	var xp_gain: int = int(round(xp_per_bar * xp_mult))
	var out_qty: int = int(fam.get("output_qty", 1))
	if out_qty <= 0:
		out_qty = 1

	var bar_id: StringName = _bar_item_id(metal)
	var out_id: StringName = _output_item_id(group, family_id, metal)

	var family_str := String(family_id).replace("_", " ")
	var metal_str  := String(metal).capitalize().strip_edges()
	var label := "%s %s" % [metal_str, family_str]
	var desc := "Smith %s using %d× %s bars." % [
		label,
		bars,
		metal_str,
	]

	var icon_val: Variant = _resolve_item_icon_path(out_id)

	# Inputs: just bars for now (later: add Tailoring/Carpentry extras)
	var inputs: Array = [
		{ "item": bar_id, "qty": bars }
	]

	return {
		"id": StringName("forge:%s:%s:%s" % [String(group), String(family_id), String(metal)]),
		"label": label,
		"desc": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"icon": icon_val,
		"inputs": inputs,
		"output_item": out_id,
		"output_qty": out_qty,
	}


## Public: get all smelting recipes (for CraftMenu)
func get_all_smelt_recipes() -> Array:
	var out: Array = []
	for metal in METALS.keys():
		var rec := _make_smelt_recipe(metal)
		if not rec.is_empty():
			out.append(rec)
	return out


## Public: get all item recipes (all categories) – can filter by level in UI
func get_all_item_recipes() -> Array:
	var out: Array = []
	for group in FAMILY_GROUPS.keys():
		var fam_table: Dictionary = FAMILY_GROUPS[group]
		for family_id in fam_table.keys():
			for metal in METALS.keys():
				var rec := _make_item_recipe(group, family_id, metal)
				if not rec.is_empty():
					out.append(rec)
	return out


## Filter by Smithing level (for UI)
func get_recipes_for_level(smith_lv: int) -> Array:
	var out: Array = []
	for rec in get_all_smelt_recipes():
		if int(rec.get("level_req", 1)) <= smith_lv:
			out.append(rec)
	for rec2 in get_all_item_recipes():
		if int(rec2.get("level_req", 1)) <= smith_lv:
			out.append(rec2)
	return out


# -------------------------------------------------------------------
# Villager job entry point (Astromancy-style)
# -------------------------------------------------------------------
# recipe_id:
#   "smelt:bronze"
#   "forge:tool:pickaxe:bronze"
#   "forge:fishing:fishing_rod:steel"
#
# Returns { "xp": int, "loot_desc": String }.

func do_smithing_work(recipe_id: StringName) -> Dictionary:
	var id_str := String(recipe_id)

	if id_str.begins_with("smelt:"):
		var metal_str := id_str.substr("smelt:".length())
		var metal := StringName(metal_str)
		return smelt_bar(metal)

	if id_str.begins_with("forge:"):
		var parts := id_str.split(":")
		if parts.size() >= 4:
			var group := StringName(parts[1])
			var family_id := StringName(parts[2])
			var metal := StringName(parts[3])
			return _smith_item(group, family_id, metal)

	return {
		"xp": 0,
		"loot_desc": "Unknown smithing recipe.",
	}
