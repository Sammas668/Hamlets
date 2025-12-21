# res://autoloads/AstromancySystem.gd
extends Node

## Handles consuming Augury to forge Shards, summoning Fragments,
## and support actions like dissolving and infusing shards.

signal fragment_summon_ready(axial: Vector2i, shard_id: StringName)

# -------------------------------------------------------------------
# Cost + gating tables
# -------------------------------------------------------------------

# Cost in Augury grades for each Astromancy rank
const COST_BY_RANK := {
	1: { "grade": 1, "qty": 1 },
	2: { "grade": 2, "qty": 2 },
	3: { "grade": 3, "qty": 3 },
	4: { "grade": 4, "qty": 5 },
	5: { "grade": 5, "qty": 8 },
	6: { "grade": 6, "qty": 12 },
	7: { "grade": 7, "qty": 18 },
	8: { "grade": 8, "qty": 27 },
	9: { "grade": 9, "qty": 40 },
	10: { "grade": 10, "qty": 60 },
}

# Minimum Astromancy level required to forge each rank
const RANK_GATE_LEVEL := {
	1: 1, 2: 10, 3: 20, 4: 30, 5: 40,
	6: 50, 7: 60, 8: 70, 9: 80, 10: 90,
}

# XP tuning (returned in dictionaries; XP is actually applied by VillagerManager)
const FORGE_XP_PER_RANK     := 10   # forging shards
const SUMMON_XP_PER_RANK    := 15    # summoning from shards
const TRANSFUSE_XP_PER_RANK := 4

# Use Items.gd as the single source of truth for IDs
const AUGURY_IDS := {
	1: Items.AUGURY_A1,
	2: Items.AUGURY_A2,
	3: Items.AUGURY_A3,
	4: Items.AUGURY_A4,
	5: Items.AUGURY_A5,
	6: Items.AUGURY_A6,
	7: Items.AUGURY_A7,
	8: Items.AUGURY_A8,
	9: Items.AUGURY_A9,
	10: Items.AUGURY_A10,
}

const SHARD_IDS := {
	1: Items.R1_PLAIN,
	2: Items.R2_PLAIN,
	3: Items.R3_PLAIN,
	4: Items.R4_PLAIN,
	5: Items.R5_PLAIN,
	6: Items.R6_PLAIN,
	7: Items.R7_PLAIN,
	8: Items.R8_PLAIN,
	9: Items.R9_PLAIN,
	10: Items.R10_PLAIN,
}

# Special action ids (not real item ids)
const ACTION_COLLAPSE_FRAGMENT := &"__collapse_fragment__"


func _ready() -> void:
	randomize()


# -------------------------------------------------------------------
# Internal helpers
# -------------------------------------------------------------------

func _augury_item_id_for_grade(grade: int) -> StringName:
	var g: int = clampi(grade, 1, 10)
	return AUGURY_IDS.get(g, Items.AUGURY_A1)


func _shard_item_id_for_rank(rank: int) -> StringName:
	var r: int = clampi(rank, 1, 10)
	return SHARD_IDS.get(r, Items.R1_PLAIN)


func _infused_shard_item_id(rank: int, aspect: StringName) -> StringName:
	# Pattern: r{rank}_{aspect}
	var r: int = clampi(rank, 1, 10)
	return StringName("r%d_%s" % [r, String(aspect)])


func _rank_from_shard_id(id: StringName) -> int:
	# First, try to parse ids like "r1_plain", "r10_plain", "r4_woodcutting"
	var id_str: String = String(id)
	if id_str.begins_with("r"):
		var underscore_pos: int = id_str.find("_")
		var digits: String
		if underscore_pos == -1:
			digits = id_str.substr(1)
		else:
			digits = id_str.substr(1, underscore_pos - 1)

		if digits.is_valid_int():
			var r := int(digits)
			return clampi(r, 1, 10)

	# If the string pattern doesn't match, fall back to the SHARD_IDS map
	# (plain shards) by reverse lookup.
	for r_key in SHARD_IDS.keys():
		var r := int(r_key)
		if SHARD_IDS[r] == id:
			return clampi(r, 1, 10)

	# Last-resort fallback
	return 1



func _ensure_bank_with(methods: Array[StringName]) -> bool:
	if typeof(Bank) == TYPE_NIL:
		push_error("[Astromancy] Bank autoload missing.")
		return false
	for m in methods:
		if not Bank.has_method(m):
			push_error("[Astromancy] Bank is missing method: %s" % String(m))
			return false
	return true


# -------------------------------------------------------------------
# Forging (Augury → Plain Shards)
# -------------------------------------------------------------------

## Returns true if the player has enough Augury to forge this rank right now.
## (No level gating here; you can gate outside using RANK_GATE_LEVEL.)
func can_forge(rank: int) -> bool:
	if not COST_BY_RANK.has(rank):
		return false
	if not _ensure_bank_with([&"amount"]):
		return false

	var cost: Dictionary = COST_BY_RANK[rank]
	var grade: int = int(cost.get("grade", 1))
	var qty: int   = int(cost.get("qty", 0))

	var augury_id: StringName = _augury_item_id_for_grade(grade)
	var have: int = int(Bank.amount(augury_id))
	return have >= qty


## Forge a plain shard Rk from Augury.
## Returns { "xp": int, "loot_desc": String }.
func forge_plain_shard(rank: int) -> Dictionary:
	var result: Dictionary = {
		"xp": 0,
		"loot_desc": "",
	}

	if not COST_BY_RANK.has(rank):
		result["loot_desc"] = "Invalid rank"
		return result

	# Use Bank.amount / Bank.take / Bank.add (matches Scrying/degrade)
	if not _ensure_bank_with([&"amount", &"take", &"add"]):
		result["loot_desc"] = "Bank API missing amount/take/add"
		return result

	var cost: Dictionary = COST_BY_RANK[rank]
	var grade: int = int(cost.get("grade", 1))
	var qty: int   = int(cost.get("qty", 0))

	var augury_id: StringName = _augury_item_id_for_grade(grade)
	var have: int = int(Bank.amount(augury_id))
	if have < qty:
		result["loot_desc"] = "Not enough Augury"
		return result

	var shard_id: StringName = _shard_item_id_for_rank(rank)

	# Spend Augury and add shard
	Bank.take(augury_id, qty)
	Bank.add(shard_id, 1)

	# XP reward (actual XP is applied by VillagerManager)
	var xp_gain: int = FORGE_XP_PER_RANK * rank

	# Nice loot text
	var shard_name: String = "Plain Shard (R%d)" % rank
	if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(shard_id):
		shard_name = Items.display_name(shard_id)

	var aug_name: String = "Augury G%d" % grade
	if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(augury_id):
		aug_name = Items.display_name(augury_id)

	result["xp"] = xp_gain
	result["loot_desc"] = "+1 %s, spent %d× %s" % [shard_name, qty, aug_name]
	return result


## Helper for villager jobs: forge the highest rank shard we can afford.
func forge_best_plain_shard() -> Dictionary:
	for rank in range(10, 0, -1):
		if can_forge(rank):
			return forge_plain_shard(rank)

	return {
		"xp": 0,
		"loot_desc": "Not enough Augury to forge any shard",
	}


# -------------------------------------------------------------------
# Summoning & Dissolving
# -------------------------------------------------------------------

## Internal helper used by villager jobs:
## Spend *one* shard and emit a signal to summon a Fragment at `ax`.
## Returns { "xp": int, "loot_desc": String }.
func _do_fragment_summon(shard_id: StringName, ax: Vector2i) -> Dictionary:
	var result: Dictionary = {
		"xp": 0,
		"loot_desc": "",
	}

	if ax == Vector2i.ZERO:
		result["loot_desc"] = "Invalid summon location."
		return result

	if not _ensure_bank_with([&"amount", &"take"]):
		result["loot_desc"] = "Bank API missing amount/take"
		return result

	var have: int = int(Bank.amount(shard_id))
	if have <= 0:
		result["loot_desc"] = "No shard available to summon."
		return result

	# Spend 1 shard
	Bank.take(shard_id, 1)

	# Emit signal so World can actually spawn the fragment at this axial
	if has_signal("fragment_summon_ready"):
		fragment_summon_ready.emit(ax, shard_id)

	var rank: int = _rank_from_shard_id(shard_id)
	var label: String = String(shard_id)
	if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(shard_id):
		label = Items.display_name(shard_id)

	var xp_gain: int = SUMMON_XP_PER_RANK * rank
	result["xp"] = xp_gain
	result["loot_desc"] = "Summoned a new fragment using %s." % label
	return result


## Dissolve a shard back into Augury of matching rank.
## Returns { "xp": 0, "loot_desc": String } (no XP by default).
func dissolve_shard(id: StringName) -> Dictionary:
	var result: Dictionary = {
		"xp": 0,
		"loot_desc": "",
	}

	if not _ensure_bank_with([&"amount", &"take", &"add"]):
		result["loot_desc"] = "Bank API missing amount/take/add"
		return result

	if int(Bank.amount(id)) <= 0:
		result["loot_desc"] = "No shard to dissolve"
		return result

	var rank: int = _rank_from_shard_id(id)
	var augury_id: StringName = _augury_item_id_for_grade(rank)

	Bank.take(id, 1)
	Bank.add(augury_id, 1)

	result["loot_desc"] = "Dissolved shard (R%d) → +1 Augury G%d" % [rank, rank]
	return result


## Manually collapse/destroy a fragment at `ax` and refund some Augury.
## Intended to be invoked via do_astromancy_work() using ACTION_COLLAPSE_FRAGMENT.
func _collapse_fragment_at(ax: Vector2i) -> Dictionary:
	var result: Dictionary = {
		"xp": 0,
		"loot_desc": "",
	}

	if ax == Vector2i.ZERO:
		result["loot_desc"] = "No target tile selected."
		return result

	# Find the World node and delegate the actual tile removal
	var world := get_tree().get_first_node_in_group("World")
	if world == null or not world.has_method("destroy_fragment_at"):
		result["loot_desc"] = "World cannot collapse fragments yet."
		return result

	# Expect:
	# {
	#   "had_fragment": bool,
	#   "rank": int,
	#   "recruited_villager_idx": int (optional, villager created by this hex)
	#   # (World should also handle kicking any worker off the tile itself)
	# }
	var info_v: Variant = world.call("destroy_fragment_at", ax)
	if typeof(info_v) != TYPE_DICTIONARY:
		result["loot_desc"] = "Failed to collapse fragment."
		return result

	var info: Dictionary = info_v
	if not bool(info.get("had_fragment", false)):
		result["loot_desc"] = "No fragment at that tile."
		return result

	var rank: int = clampi(int(info.get("rank", 1)), 1, 10)

	# Refund: 1× Augury of matching grade (A_rank)
	if _ensure_bank_with([&"add"]):
		var aug_id: StringName = _augury_item_id_for_grade(rank)
		Bank.add(aug_id, 1)

		var aug_name: String = String(aug_id)
		if typeof(Items) != TYPE_NIL \
		and Items.has_method("is_valid") \
		and Items.has_method("display_name") \
		and Items.is_valid(aug_id):
			aug_name = Items.display_name(aug_id)

		result["loot_desc"] = "Collapsed Fragment (R%d) → +1 %s" % [rank, aug_name]
	else:
		result["loot_desc"] = "Collapsed Fragment (R%d)." % rank

	# ---------------------------------------------------------
	# Only destroy the villager that was RECRUITED BY THIS HEX
	# (if any). The worker groveing on the tile should have
	# already been unassigned by World.destroy_fragment_at().
	# ---------------------------------------------------------
	var recruited_idx: int = int(info.get("recruited_villager_idx", -1))

	# Optional backward-compat: if World still uses "villager_idx"
	# to mean "recruited villager", fall back to that.
	if recruited_idx < 0 and info.has("villager_idx"):
		recruited_idx = int(info.get("villager_idx", -1))

	if recruited_idx >= 0:
		# 1) Stop any grovening job + clear world icon
		if typeof(VillagerManager) != TYPE_NIL \
		and VillagerManager.has_method("stop_job"):
			VillagerManager.stop_job(recruited_idx)

		# 2) Remove the villager from the roster
		if typeof(Villagers) != TYPE_NIL \
		and Villagers.has_method("remove_villager"):
			Villagers.remove_villager(recruited_idx)

	return result

	
# -------------------------------------------------------------------
# Transfusion / Infusion
# -------------------------------------------------------------------

## Turn a plain shard into an infused shard with an extra material cost.
## extra_cost: Dictionary { item_id: qty }
## Returns { "xp": int, "loot_desc": String }.
func transfuse_plain_shard(rank: int, aspect: StringName, extra_cost: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"xp": 0,
		"loot_desc": "",
	}

	if not _ensure_bank_with([&"amount", &"take", &"add"]):
		result["loot_desc"] = "Bank API missing amount/take/add"
		return result

	var plain_id: StringName  = _shard_item_id_for_rank(rank)
	var infused_id: StringName = _infused_shard_item_id(rank, aspect)

	if int(Bank.amount(plain_id)) <= 0:
		result["loot_desc"] = "Need a plain shard (R%d)" % rank
		return result

	for item_id in extra_cost.keys():
		var qty: int = int(extra_cost[item_id])
		if qty > 0 and int(Bank.amount(item_id)) < qty:
			result["loot_desc"] = "Missing items for infusion"
			return result

	# Spend resources
	Bank.take(plain_id, 1)
	for item_id in extra_cost.keys():
		var qty2: int = int(extra_cost[item_id])
		if qty2 > 0:
			Bank.take(item_id, qty2)

	# Grant infused shard
	Bank.add(infused_id, 1)

	var xp_gain: int = TRANSFUSE_XP_PER_RANK * rank
	result["xp"] = xp_gain
	result["loot_desc"] = "Infused Shard (R%d, %s)" % [rank, String(aspect)]
	return result


# -------------------------------------------------------------------
# Cost helpers for other systems
# -------------------------------------------------------------------

func get_cost_for_rank(rank: int) -> Dictionary:
	if not COST_BY_RANK.has(rank):
		return {}
	return COST_BY_RANK[rank]  # { "grade": int, "qty": int }


func get_max_rank_for_level(lv: int) -> int:
	var best: int = 1
	for r in RANK_GATE_LEVEL.keys():
		var gate_lv: int = int(RANK_GATE_LEVEL[r])
		if lv >= gate_lv and r > best:
			best = r
	return best

# -------------------------------------------------------------------
# Crafting recipes (for CraftMenu / TaskPicker)
# -------------------------------------------------------------------

func _make_forge_recipe(rank: int) -> Dictionary:
	if not COST_BY_RANK.has(rank):
		return {}

	var cost: Dictionary = COST_BY_RANK[rank]
	var grade: int = int(cost.get("grade", 1))
	var qty: int   = int(cost.get("qty", 0))

	var augury_id: StringName = _augury_item_id_for_grade(grade)
	var shard_id: StringName  = _shard_item_id_for_rank(rank)
	var level_req: int        = int(RANK_GATE_LEVEL.get(rank, 1))
	var xp_gain: int          = FORGE_XP_PER_RANK * rank

	# Default text
	var shard_name := "Plain Shard (R%d)" % rank
	var aug_name   := "Augury G%d" % grade

	if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name"):
		if Items.is_valid(shard_id):
			shard_name = Items.display_name(shard_id)
		if Items.is_valid(augury_id):
			aug_name   = Items.display_name(augury_id)

	var label := "Forge %s" % shard_name
	var desc  := "Forge %s using %d× %s." % [shard_name, qty, aug_name]

	# Icon path for the output shard (CraftMenu can load a string path)
	var icon_val: Variant = ""
	if typeof(Items) != TYPE_NIL and Items.has_method("get_icon_path"):
		icon_val = Items.get_icon_path(shard_id)

	var inputs: Array = [
		{
			"item": augury_id,
			"qty": qty,
		}
	]

	return {
		"id": shard_id,        # IMPORTANT: this is what do_astromancy_work receives
		"label": label,
		"desc": desc,
		"level_req": level_req,
		"xp": xp_gain,
		"icon": icon_val,
		"inputs": inputs,
	}


## Public helper for TaskPicker / CraftMenu:
## Get all forge recipes the player can *see* at this Astromancy level.
## (CraftMenu will still disable ones they can’t actually craft due to
##  materials, via _max_craftable_count / _can_craft_selected.)
func get_forge_recipes_for_level(astromancy_lv: int) -> Array:
	var recipes: Array = []

	var max_rank: int = get_max_rank_for_level(astromancy_lv)
	for rank in range(1, max_rank + 1):
		var rec := _make_forge_recipe(rank)
		if not rec.is_empty():
			recipes.append(rec)

	return recipes


## If you ever want "show all 10 ranks regardless of level", use this:
func get_all_forge_recipes() -> Array:
	var out: Array = []
	for rank in range(1, 11):
		var rec := _make_forge_recipe(rank)
		if not rec.is_empty():
			out.append(rec)
	return out


# -------------------------------------------------------------------
# Villager job entry point
# -------------------------------------------------------------------
# If `ax` is an empty but adjacent tile, treat this as "summon a fragment
# here using this shard".
# Otherwise, forge shards as before.
#
# Returns { "xp": int, "loot_desc": String }.
func do_astromancy_work(recipe_id: StringName = &"", ax: Vector2i = Vector2i.ZERO) -> Dictionary:
	# Interpret some ids as "special actions" rather than real shard items
	var rid_str := String(recipe_id)

	# --- Collapse branch: explicit action id, requires an existing fragment at ax ---
	if rid_str == String(ACTION_COLLAPSE_FRAGMENT):
		return _collapse_fragment_at(ax)

	# --- Summon branch: empty + adjacent tile (existing code continues below) ---
	var world := get_tree().get_first_node_in_group("World")
	if world \
	and world.has_method("_has_fragment_at") \
	and world.has_method("_is_adjacent_to_any") \
	and ax != Vector2i.ZERO:
		var has_frag: bool = bool(world.call("_has_fragment_at", ax))
		var adjacent: bool = bool(world.call("_is_adjacent_to_any", ax))

		if (not has_frag) and adjacent:
			if String(recipe_id) != "":
				return _do_fragment_summon(recipe_id, ax)
			else:
				return {
					"xp": 0,
					"loot_desc": "No shard selected for summoning.",
				}

	# --- Forge branch (normal Astromancy work on an existing fragment) ---
	if String(recipe_id) != "":
		var rank: int = _rank_from_shard_id(recipe_id)
		return forge_plain_shard(rank)

	# Fallback: original behaviour — forge the best rank we can afford.
	return forge_best_plain_shard()
