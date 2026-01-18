# res://autoloads/WoodcuttingSystem.gd
extends Node

## WoodcuttingSystem:
## - Static tree definitions (lvl req, xp, drops, etc.).
## - Single-action API (do_chop) similar to MiningSystem.do_mine.
## - Handles success/fail, logs, Bird Nests, Amber, small bonus drops.
## - Does NOT award XP directly to villagers – it returns xp like MiningSystem.

# Preload Items so we can safely use constants in our tables
const ITEMS := preload("res://scripts/autoload/items.gd")  # 🔧 adjust path if needed

# Core pacing – match MiningSystem
const BASE_ACTION_TIME := 2.4  # seconds per woodcutting action

# Global rare drops (per action)
const NEST_RATE_TREES := 0.0025   # 0.25% per tree action
const NEST_RATE_IVY   := 0.0040   # 0.40% per ivy action
const AMBER_RATE      := 0.0005   # 0.05% per action

enum TargetKind { TREE, IVY }

# -------------------------------------------------------------------
# Woodcutting targets – Pine → Elder + Ivy
# -------------------------------------------------------------------
const TARGETS := {
	&"pine_grove": {
		"name": "Pine grove",
		"kind": TargetKind.TREE,
		"tier": 1,
		"lvl_req": 1,
		"xp": 6,
		"axe_req": 1,
		"yield_min": 1,
		"yield_max": 1,
		"drops": [
			{ "item": ITEMS.LOG_PINE,  "weight": 95, "lvl_req": 1 },
			{ "item": ITEMS.TWIGS,     "weight": 5,  "lvl_req": 1 },  # now bonus, not main
		],
	},

	# T2 – Birch
	&"birch_grove": {
		"name": "Birch grove",
		"kind": TargetKind.TREE,
		"tier": 2,
		"lvl_req": 10,
		"xp": 10,
		"axe_req": 1,
		"yield_min": 1,
		"yield_max": 1,
		"drops": [
			{ "item": ITEMS.LOG_BIRCH, "weight": 93, "lvl_req": 10 },
			{ "item": ITEMS.LOG_PINE,  "weight": 6,  "lvl_req": 1 },
			{ "item": ITEMS.TWIGS,     "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# T3 – Oak
	&"oakwood": {
		"name": "Oakwood",
		"kind": TargetKind.TREE,
		"tier": 3,
		"lvl_req": 20,
		"xp": 16,
		"axe_req": 1,
		"yield_min": 1,
		"yield_max": 2,
		"drops": [
			{ "item": ITEMS.LOG_OAK,   "weight": 90, "lvl_req": 20 },
			{ "item": ITEMS.LOG_BIRCH, "weight": 9,  "lvl_req": 10 },
			{ "item": ITEMS.TWIGS,     "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# T4 – Willow
	&"willow_grove": {
		"name": "Willow grove",
		"kind": TargetKind.TREE,
		"tier": 4,
		"lvl_req": 30,
		"xp": 24,
		"axe_req": 2, # Iron+
		"yield_min": 1,
		"yield_max": 2,
		"drops": [
			{ "item": ITEMS.LOG_WILLOW, "weight": 90, "lvl_req": 30 },
			{ "item": ITEMS.LOG_OAK,    "weight": 9,  "lvl_req": 20 },
			{ "item": ITEMS.BARK_SCRAP, "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# T5 – Maple
	&"maple_grove": {
		"name": "Maple Grove",
		"kind": TargetKind.TREE,
		"tier": 5,
		"lvl_req": 40,
		"xp": 36,
		"axe_req": 2,
		"yield_min": 1,
		"yield_max": 2,
		"drops": [
			{ "item": ITEMS.LOG_MAPLE,  "weight": 92, "lvl_req": 40 },
			{ "item": ITEMS.LOG_WILLOW, "weight": 7,  "lvl_req": 30 },
			{ "item": ITEMS.BARK_SCRAP, "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# T6 – Yew
	&"yew_grove": {
		"name": "Yew Grove",
		"kind": TargetKind.TREE,
		"tier": 6,
		"lvl_req": 50,
		"xp": 52,
		"axe_req": 3, # Steel+
		"yield_min": 1,
		"yield_max": 2,
		"drops": [
			{ "item": ITEMS.LOG_YEW,   "weight": 94, "lvl_req": 50 },
			{ "item": ITEMS.LOG_MAPLE, "weight": 5,  "lvl_req": 40 },
			{ "item": ITEMS.BARK,      "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# T7 – Ironwood
	&"ironwood_run": {
		"name": "Ironwood Run",
		"kind": TargetKind.TREE,
		"tier": 7,
		"lvl_req": 60,
		"xp": 72,
		"axe_req": 3,
		"yield_min": 1,
		"yield_max": 2,
		"drops": [
			{ "item": ITEMS.LOG_IRONWOOD, "weight": 95, "lvl_req": 60 },
			{ "item": ITEMS.LOG_YEW,      "weight": 4,  "lvl_req": 50 },
			{ "item": ITEMS.BARK,         "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# T8 – Redwood
	&"redwood_reach": {
		"name": "Redwood Reach",
		"kind": TargetKind.TREE,
		"tier": 8,
		"lvl_req": 75,
		"xp": 110,
		"axe_req": 4, # Mithrite+
		"yield_min": 1,
		"yield_max": 3,
		"drops": [
			{ "item": ITEMS.LOG_REDWOOD, "weight": 95, "lvl_req": 75 },
			{ "item": ITEMS.LOG_IRONWOOD,"weight": 4,  "lvl_req": 60 },
			{ "item": ITEMS.RESIN_GLOB,  "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# T9 – Sakura
	&"sakura_grove": {
		"name": "Sakura Grove",
		"kind": TargetKind.TREE,
		"tier": 9,
		"lvl_req": 90,
		"xp": 170,
		"axe_req": 5, # Adamantite+
		"yield_min": 1,
		"yield_max": 3,
		"drops": [
			{ "item": ITEMS.LOG_SAKURA,  "weight": 96, "lvl_req": 90 },
			{ "item": ITEMS.LOG_REDWOOD, "weight": 3,  "lvl_req": 75 },
			{ "item": ITEMS.RESIN_GLOB,  "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# T10 – Elder
	&"elder_grove": {
		"name": "Elder Grove",
		"kind": TargetKind.TREE,
		"tier": 10,
		"lvl_req": 95,
		"xp": 220,
		"axe_req": 6, # Orichalcum+
		"yield_min": 1,
		"yield_max": 3,
		"drops": [
			{ "item": ITEMS.LOG_ELDER,   "weight": 97, "lvl_req": 95 },
			{ "item": ITEMS.LOG_SAKURA,  "weight": 2,  "lvl_req": 90 },
			{ "item": ITEMS.RESIN_GLOB,  "weight": 1,  "lvl_req": 1 },  # bonus
		],
	},

	# Ivy – pure XP, better Nests, no direct log drops
	&"climbing_ivy": {
		"name": "Climbing Ivy",
		"kind": TargetKind.IVY,
		"tier": 0,
		"lvl_req": 60,
		"xp": 80,
		"axe_req": 3,
		"yield_min": 0,
		"yield_max": 0,
		"drops": [],  # no logs, just nests/amber/xp
	},
}

# -------------------------------------------------------------------
# Seed mapping – one seed per tree tier
# -------------------------------------------------------------------
const TREE_SEEDS := {
	1: ITEMS.SEED_PINE,
	2: ITEMS.SEED_BIRCH,
	3: ITEMS.SEED_OAK,
	4: ITEMS.SEED_WILLOW,
	5: ITEMS.SEED_MAPLE,
	6: ITEMS.SEED_YEW,
	7: ITEMS.SEED_IRONWOOD,
	8: ITEMS.SEED_REDWOOD,
	9: ITEMS.SEED_SAKURA,
	10: ITEMS.SEED_ELDER,
}

# ===================================================================
# Public API – Mining-style helpers
# ===================================================================

# Look up per-tile modifiers for a specific woodcutting node
# Returns { chance_factor: float, yield_factor: float, is_thick: bool }
func _get_tile_node_modifiers(ax: Vector2i, node_detail: String) -> Dictionary:
	var result: Dictionary = {
		"chance_factor": 1.0,
		"yield_factor": 1.0,
		"is_thick": false,
	}

	if typeof(ResourceNodes) == TYPE_NIL or not ResourceNodes.has_method("get_nodes"):
		return result

	var nodes_any: Variant = ResourceNodes.get_nodes(ax, "woodcutting")
	if not (nodes_any is Array):
		return result

	var nodes: Array = nodes_any
	if nodes.is_empty():
		return result

	# 1) Try to find a node whose "detail" matches node_detail
	var selected: Dictionary = {}
	if node_detail != "":
		for n_v in nodes:
			if not (n_v is Dictionary):
				continue
			var n: Dictionary = n_v
			if String(n.get("detail", "")) == node_detail:
				selected = n
				break

	# 2) Fallback to the first node if nothing matched
	if selected.is_empty():
		var first_any: Variant = nodes[0]
		if first_any is Dictionary:
			selected = first_any

	if selected.is_empty():
		return result

	if selected.has("chance_factor"):
		result["chance_factor"] = float(selected.get("chance_factor"))
	if selected.has("yield_factor"):
		result["yield_factor"] = float(selected.get("yield_factor"))

	# Treat any detail containing "thick" as a thick grove
	var detail_str: String = String(selected.get("detail", ""))
	if detail_str.to_lower().find("thick") != -1:
		result["is_thick"] = true

	return result


func get_target_def(target_id: StringName) -> Dictionary:
	if TARGETS.has(target_id):
		return TARGETS[target_id]
	return {}

func get_drop_preview_for_target(
		target_id: StringName,
		ax: Vector2i,
		node_detail: String = "",
		wc_lv: int = -1
) -> Array:


	var result: Array = []

	if not TARGETS.has(target_id):
		return result

	var def: Dictionary = TARGETS[target_id]

	# ------------------------------
	# 1) Split base logs vs bonus
	# ------------------------------
	var drops_v: Variant = def.get("drops", [])
	if not (drops_v is Array):
		drops_v = []
	var drops: Array = drops_v

	var base_rows: Array = []   # main logs (pine/birch/oak/etc.)
	var bonus_rows: Array = []  # twigs / bark / resin extras

	for row_v in drops:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v
		var item_id: StringName = row.get("item", StringName(""))
		if item_id == StringName(""):
			continue

		if _is_bonus_drop(item_id):
			bonus_rows.append(row)
		else:
			base_rows.append(row)

	# ------------------------------
	# 2) Base yield, tile multipliers
	# ------------------------------
	var yield_min: int = int(def.get("yield_min", 1))
	var yield_max: int = int(def.get("yield_max", yield_min))
	if yield_max < yield_min:
		yield_max = yield_min

	var avg_yield: float = (float(yield_min) + float(yield_max)) * 0.5

	# Pull per-tile modifiers for this particular grove
	var node_mods: Dictionary = _get_tile_node_modifiers(ax, node_detail)
	var chance_factor: float = float(node_mods.get("chance_factor", 1.0))
	var yield_factor: float  = float(node_mods.get("yield_factor", 1.0))
	var is_thick: bool       = bool(node_mods.get("is_thick", false))

	avg_yield *= yield_factor
	var avg_qty: int = max(1, int(round(avg_yield)))

	# --- Skill-based success chance for preview ---
	var req_level: int = int(def.get("lvl_req", 1))

	# If no explicit wc_lv was supplied, assume "at requirement" for preview
	var skill_level: int = wc_lv
	if skill_level < 0:
		skill_level = req_level

	var base_skill_chance: float = _success_chance(skill_level, req_level)
	var success_chance: float = base_skill_chance * chance_factor

	# Same hard guarantee rules as do_chop
	var guarantee_offset: int = 19
	if is_thick:
		guarantee_offset = 29

	if skill_level >= req_level + guarantee_offset:
		success_chance = 1.0

	success_chance = clampf(success_chance, 0.05, 1.0)

	# ------------------------------
	# 3) Main logs — weight-based chance
	# ------------------------------
	var total_weight: float = 0.0
	for row_v2 in base_rows:
		var row2: Dictionary = row_v2
		total_weight += max(float(row2.get("weight", 0.0)), 0.0)

	if total_weight > 0.0 and success_chance > 0.0:
		for row_v3 in base_rows:
			var row3: Dictionary = row_v3
			var w: float = max(float(row3.get("weight", 0.0)), 0.0)
			if w <= 0.0:
				continue

			var item_id2: StringName = row3.get("item", StringName(""))
			if item_id2 == StringName(""):
				continue

			var cond_chance: float = w / total_weight
			var final_chance: float = success_chance * cond_chance

			result.append({
				"item_id": item_id2,
				"chance": final_chance,   # 0.0–1.0
				"qty": avg_qty,           # includes 2× from thick groves
				"is_fail": false,
			})

	# ------------------------------
	# 4) Bonus extras – weight as % chance
	# ------------------------------
	for row_v4 in bonus_rows:
		var row4: Dictionary = row_v4
		var item_id3: StringName = row4.get("item", StringName(""))
		if item_id3 == StringName(""):
			continue

		var weight_raw: float = float(row4.get("weight", 0.0))
		if weight_raw <= 0.0:
			continue

		var base_chance: float = clampf(weight_raw / 100.0, 0.0, 1.0)
		var bonus_chance: float = base_chance * success_chance

		result.append({
			"item_id": item_id3,
			"chance": bonus_chance,
			"qty": 1,
			"is_fail": false,
		})

	# ------------------------------
	# 5) Global rare drops: Nests + Amber
	# ------------------------------
	var target_kind: int = int(def.get("kind", TargetKind.TREE))
	var nest_rate: float = NEST_RATE_TREES
	if target_kind == TargetKind.IVY:
		nest_rate = NEST_RATE_IVY

	nest_rate *= success_chance

	if nest_rate > 0.0:
		result.append({
			"item_id": ITEMS.BIRD_NEST,
			"chance": nest_rate,
			"qty": 1,
			"is_fail": false,
		})

	var amber_rate: float = AMBER_RATE * success_chance
	if amber_rate > 0.0:
		result.append({
			"item_id": ITEMS.AMBER_SAP,
			"chance": amber_rate,
			"qty": 1,
			"is_fail": false,
		})

	# ------------------------------
	# 6) Fail entry so UI can show it
	# ------------------------------
	if success_chance < 1.0:
		var fail_chance: float = 1.0 - success_chance
		result.append({
			"item_id": StringName(""),
			"chance": fail_chance,
			"qty": 0,
			"is_fail": true,
		})

	return result


func is_target_unlocked_for_villager(v_idx: int, target_id: StringName) -> bool:
	var def: Dictionary = get_target_def(target_id)
	if def.is_empty():
		return false
	var req: int = int(def.get("lvl_req", 1))
	var lv: int = _get_skill_level_safe(v_idx, "woodcutting")
	return lv >= req


func do_chop(
		v_idx: int,
		target_id: StringName,
		ax: Vector2i,
		node_detail: String = ""
) -> Dictionary:

	var result: Dictionary = {
		"xp": 0,
		"loot_desc": "",
	}

	# 0) Look up the tree definition (pine_grove, oakwood, etc.)
	var def: Dictionary = get_target_def(target_id)
	if def.is_empty():
		return result

	# --- Levels ---
	var wc_lv: int = _get_skill_level_safe(v_idx, "woodcutting")
	var req_level: int = int(def.get("lvl_req", 1))

	# --- Yield + XP from def ---
	var base_yield_min: int = int(def.get("yield_min", 1))
	var base_yield_max: int = int(def.get("yield_max", base_yield_min))
	if base_yield_max < base_yield_min:
		base_yield_max = base_yield_min

	var xp_per_chop: int = int(def.get("xp", 5))

	# --- Per-node multipliers from ResourceNodes (Thick Pine Grove, etc.) ---
	var node_mods: Dictionary = _get_tile_node_modifiers(ax, node_detail)
	var chance_factor: float = float(node_mods.get("chance_factor", 1.0))
	var yield_factor: float = float(node_mods.get("yield_factor", 1.0))
	var is_thick: bool = bool(node_mods.get("is_thick", false))


	# --- Skill-based success chance ---
	var skill_chance: float = _success_chance(wc_lv, req_level)
	var final_chance: float = skill_chance * chance_factor

	# 🔒 Hard guarantee:
	# - Normal groves: 100% at req + 19 levels
	# - Thick groves: 100% at req + 29 levels
	var guarantee_offset: int = 19
	if is_thick:
		guarantee_offset = 29

	if wc_lv >= req_level + guarantee_offset:
		final_chance = 1.0

	final_chance = clampf(final_chance, 0.05, 1.0)



	# --- Roll success / failure ---
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	if rng.randf() > final_chance:
		# 20% of success XP (minimum 1)
		var fail_xp: int = int(round(float(xp_per_chop) * 0.2))
		if fail_xp < 1:
			fail_xp = 1

		result["xp"] = fail_xp
		result["loot_desc"] = "You fail to get any usable logs."
		return result

	# --- Success → roll base yield and apply multiplier ---
	var rolled_yield: int = rng.randi_range(base_yield_min, base_yield_max)
	var final_yield: int = max(1, int(round(float(rolled_yield) * yield_factor)))

	# --- Main log drop (weighted table based on level) ---
	var item_id: StringName = _roll_tree_drop(rng, def, wc_lv)

	# Fallback: if drop table is weird/missing, grab the first entry
	if item_id == StringName(""):
		if def.has("drops"):
			var table_any: Variant = def.get("drops")
			if table_any is Array:
				var table: Array = table_any
				if table.size() > 0:
					var first_any: Variant = table[0]
					if first_any is Dictionary:
						var first_row: Dictionary = first_any
						item_id = first_row.get("item", StringName(""))

	var log_name: String = "logs"
	if item_id != StringName(""):
		_add_item(item_id, final_yield)

		if typeof(Items) != TYPE_NIL \
		and Items.has_method("is_valid") \
		and Items.has_method("display_name") \
		and Items.is_valid(item_id):
			log_name = Items.display_name(item_id)

	var loot_lines: Array = []
	loot_lines.append("Gained %d× %s" % [final_yield, log_name])

	# ----------------------------------------------------------------
	# 6) Global rare drops: Bird Nest + Amber Sap (level-scaled)
	# ----------------------------------------------------------------
	var target_kind: int = TargetKind.TREE
	if def.has("kind"):
		target_kind = int(def.get("kind"))

	var nest_rate: float = NEST_RATE_TREES
	if target_kind == TargetKind.IVY:
		nest_rate = NEST_RATE_IVY

	var above: int = 0
	if wc_lv > req_level:
		above = wc_lv - req_level

	# Slight nest rate boost with level
	var nest_level_factor: float = 1.0 + float(above) * 0.01
	nest_rate = clampf(
		nest_rate * nest_level_factor * _nest_rate_multiplier(v_idx),
		0.0,
		0.05
	)

	if rng.randf() < nest_rate:
		_add_item(ITEMS.BIRD_NEST, 1)
		var nest_name: String = "Bird Nest"
		if typeof(Items) != TYPE_NIL and Items.has_method("display_name"):
			nest_name = Items.display_name(ITEMS.BIRD_NEST)
		loot_lines.append("A %s falls from the branches" % nest_name)

	var amber_rate: float = AMBER_RATE
	var amber_level_factor: float = 1.0 + float(above) * 0.005
	amber_rate = clampf(amber_rate * amber_level_factor, 0.0, 0.01)

	if rng.randf() < amber_rate:
		_add_item(ITEMS.AMBER_SAP, 1)
		var amber_name: String = "Amber Sap"
		if typeof(Items) != TYPE_NIL and Items.has_method("display_name"):
			amber_name = Items.display_name(ITEMS.AMBER_SAP)
		loot_lines.append("You chip off a glint of %s" % amber_name)

	# ----------------------------------------------------------------
	# 7) Final XP + description
	# ----------------------------------------------------------------
	result["xp"] = xp_per_chop
	result["loot_desc"] = ". ".join(loot_lines) + "."

	return result


# ===================================================================
# Core action helpers
# ===================================================================

# Main log drop – ignores twigs/bark/resin so they can be bonus extras
func _roll_tree_drop(
		rng: RandomNumberGenerator,
		def: Dictionary,
		level: int
) -> StringName:
	var table_v: Variant = def.get("drops", [])
	if not (table_v is Array):
		return StringName("")
	var table: Array = table_v

	# Only keep rows the villager is high enough level to get AND not bonus items
	var candidates: Array = []
	for row_v in table:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v
		var item_id: StringName = row.get("item", StringName(""))
		if _is_bonus_drop(item_id):
			continue

		var req: int = int(row.get("lvl_req", 1))
		if level >= req:
			candidates.append(row)

	if candidates.is_empty():
		return StringName("")

	# Sum total weight
	var total_weight: int = 0
	for row_v2 in candidates:
		var row2: Dictionary = row_v2
		total_weight += int(row2.get("weight", 0))

	if total_weight <= 0:
		return StringName("")

	# Roll a weighted random choice
	var roll: int = rng.randi_range(1, total_weight)
	var running: int = 0
	for row_v3 in candidates:
		var row3: Dictionary = row_v3
		running += int(row3.get("weight", 0))
		if roll <= running:
			return row3.get("item", StringName("")) as StringName

	return StringName("")


# Helper to flag which items are treated as "bonus extras"
func _is_bonus_drop(item_id: StringName) -> bool:
	return (
		item_id == ITEMS.TWIGS
		or item_id == ITEMS.BARK_SCRAP
		or item_id == ITEMS.BARK
		or item_id == ITEMS.RESIN_GLOB
	)


# Bonus drops (twigs, bark, resin) as extra loot, not instead of logs
func _roll_bonus_drops(
		rng: RandomNumberGenerator,
		def: Dictionary,
		level: int,
		base_yield: int,
		loot_lines: Array
) -> void:
	var drops_v: Variant = def.get("drops", [])
	if not (drops_v is Array):
		return
	var drops: Array = drops_v

	for row_v in drops:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v
		var item_id: StringName = row.get("item", StringName(""))
		if not _is_bonus_drop(item_id):
			continue

		var req: int = int(row.get("lvl_req", 1))
		if level < req:
			continue

		var weight_raw: float = float(row.get("weight", 0))
		if weight_raw <= 0.0:
			continue

		# Interpret "weight" as a % chance up to 100%
		var chance: float = clampf(weight_raw / 100.0, 0.0, 1.0)
		if rng.randf() >= chance:
			continue

		var qty: int = 1
		if item_id == ITEMS.TWIGS:
			qty = rng.randi_range(1, max(1, base_yield))
		elif item_id == ITEMS.BARK or item_id == ITEMS.BARK_SCRAP:
			qty = rng.randi_range(1, max(1, base_yield / 2))
		elif item_id == ITEMS.RESIN_GLOB:
			qty = 1

		_add_item(item_id, qty)

		if typeof(Items) != TYPE_NIL \
		and Items.has_method("is_valid") \
		and Items.has_method("display_name") \
		and Items.is_valid(item_id):
			name = Items.display_name(item_id)
		else:
			name = "bonus item"

		loot_lines.append("You also gain %d× %s" % [qty, name])


func _check_woodcut_success(level: int, req_level: int, rng: RandomNumberGenerator) -> bool:
	var chance: float = _success_chance(level, req_level)
	return rng.randf() < chance


func _success_chance(level: int, req_level: int) -> float:
	# Below requirement: low success
	# At requirement: ~35% success
	# Above requirement: steadily increases
	# Clamped between 5% and 98%

	var below: int = max(req_level - level, 0)
	var above: int = max(level - req_level, 0)

	var chance: float = 0.35  # at requirement
	chance += float(above) * 0.03  # +3% per level above
	chance -= float(below) * 0.05  # -5% per level below

	return clampf(chance, 0.05, 0.98)

# ===================================================================
# Bird Nest → Seed helper (for Farming)
# ===================================================================

func choose_seed_for_tier(tree_tier: int, rng: RandomNumberGenerator) -> StringName:
	var t: int = clampi(tree_tier, 1, 10)

	var weighted: Array[Dictionary] = []
	weighted.append({ "tier": t, "w": 80 })

	if t > 1:
		weighted.append({ "tier": t - 1, "w": 15 })
	if t < 10:
		weighted.append({ "tier": t + 1, "w": 5 })

	var total: int = 0
	for r: Dictionary in weighted:
		total += int(r["w"])

	if total <= 0:
		return StringName("")

	var roll: int = rng.randi_range(1, total)
	var running: int = 0
	for r2: Dictionary in weighted:
		running += int(r2["w"])
		if roll <= running:
			var tt: int = int(r2["tier"])
			return TREE_SEEDS.get(tt, StringName("")) as StringName

	return StringName("")

# ===================================================================
# Modifiers / perks – stubs (hook Logging Yard, axes, perks here)
# ===================================================================

func _compute_action_time(v_idx: int, def: Dictionary) -> float:
	var t: float = BASE_ACTION_TIME
	t *= _axe_speed_multiplier(v_idx, def)
	t *= _site_speed_multiplier(v_idx)
	t *= _perk_speed_multiplier(v_idx)
	return t


func _axe_speed_multiplier(_v_idx: int, _def: Dictionary) -> float:
	# TODO: check villager axe vs def["axe_req"]
	return 1.0


func _site_speed_multiplier(_v_idx: int) -> float:
	# TODO: Logging Yard modules / tile bonuses
	return 1.0


func _perk_speed_multiplier(_v_idx: int) -> float:
	# TODO: Woodcutting perks, auras, consumables
	return 1.0


func _apply_xp_modifiers(_v_idx: int, base_xp: float, _def: Dictionary) -> float:
	# TODO: XP boosts from buildings / perks
	return base_xp


func _nest_rate_multiplier(_v_idx: int) -> float:
	# TODO: Nest Whisperer-style bonuses
	return 1.0

# ===================================================================
# Bridges into VillagerManager + Inventory
# ===================================================================

func _get_skill_level_safe(v_idx: int, skill_id: String) -> int:
	var lv: int = 1
	if v_idx >= 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
		lv = int(Villagers.get_skill_level(v_idx, skill_id))
	return lv


func _add_item(item_id: StringName, qty: int) -> void:
	if item_id == StringName("") or qty <= 0:
		return
	if typeof(Bank) != TYPE_NIL and Bank.has_method("add"):
		Bank.add(item_id, qty)

# Legacy compatibility – some older code might still call this.
# It just forwards to the shared Bank inventory.
func _give_logs_to_villager(_v_idx: int, item_id: StringName, qty: int) -> void:
	_add_item(item_id, qty)
