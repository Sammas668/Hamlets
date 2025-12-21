# res://autoloads/MiningSystem.gd
extends Node

## MiningSystem:
## - Static node definitions (req, xp, charges, respawn, item_id).
## - Lightweight per-tile charges + respawn timers.
## - Awards items and XP on job completion, like Scrying/Astromancy.

const BASE_ACTION_TIME := 2.4  # seconds per Mining action (for job system reference)

# Preload the Items script so we can use its consts in our own const tables
const ITEMS := preload("res://scripts/autoload/items.gd")  # 🔴 adjust path if needed

# -------------------------------------------------------------------
# Node definitions (data-only)
# -------------------------------------------------------------------
const STONE_NODES := {
	&"limestone": {
		"kind": "stone",
		"req": 1,
		"xp": 5,
		"charges": 19,
		"respawn_s": 30.0,
		"item_id": ITEMS.STONE_LIMESTONE,
	},
	&"sandstone": {
		"kind": "stone",
		"req": 18,
		"xp": 16,
		"charges": 19,
		"respawn_s": 45.0,
		"item_id": ITEMS.STONE_SANDSTONE,
	},
	&"basalt": {
		"kind": "stone",
		"req": 35,
		"xp": 34,
		"charges": 17,
		"respawn_s": 60.0,
		"item_id": ITEMS.STONE_BASALT,
	},
	&"granite": {
		"kind": "stone",
		"req": 55,
		"xp": 65,
		"charges": 18,
		"respawn_s": 90.0,
		"item_id": ITEMS.STONE_GRANITE,
	},
	&"marble": {
		"kind": "stone",
		"req": 75,
		"xp": 100,
		"charges": 16,
		"respawn_s": 120.0,
		"item_id": ITEMS.STONE_MARBLE,
	},
	&"clay": {
		"kind": "stone",
		"req": 5,
		"xp": 5,
		"charges": 16,
		"respawn_s": 45.0,
		"item_id": ITEMS.STONE_CLAY,
	},
}

const ORE_NODES := {
	&"copper": {
		"kind": "ore",
		"req": 1,
		"xp": 7,
		"charges": 12,
		"respawn_s": 45.0,
		"item_id": ITEMS.ORE_COPPER,
	},
	&"tin": {
		"kind": "ore",
		"req": 1,
		"xp": 7,
		"charges": 13,
		"respawn_s": 60.0,
		"item_id": ITEMS.ORE_TIN,
	},
	&"iron": {
		"kind": "ore",
		"req": 15,
		"xp": 15,
		"charges": 13,
		"respawn_s": 75.0,
		"item_id": ITEMS.ORE_IRON,
	},
	&"coal": {
		"kind": "ore",
		"req": 30,
		"xp": 30,
		"charges": 12,
		"respawn_s": 90.0,
		"item_id": ITEMS.ORE_COAL,
	},
	&"silver": {
		"kind": "ore",
		"req": 40,
		"xp": 40,
		"charges": 12,
		"respawn_s": 105.0,
		"item_id": ITEMS.ORE_SILVER,
	},
	&"gold": {
		"kind": "ore",
		"req": 50,
		"xp": 60,
		"charges": 11,
		"respawn_s": 120.0,
		"item_id": ITEMS.ORE_GOLD,
	},
	&"mithrite": {
		"kind": "ore",
		"req": 60,
		"xp": 85,
		"charges": 10,
		"respawn_s": 135.0,
		"item_id": ITEMS.ORE_MITHRITE,
	},
	&"adamantite": {
		"kind": "ore",
		"req": 70,
		"xp": 120,
		"charges": 9,
		"respawn_s": 150.0,
		"item_id": ITEMS.ORE_ADAMANTITE,
	},
	&"orichalcum": {
		"kind": "ore",
		"req": 85,
		"xp": 200,
		"charges": 8,
		"respawn_s": 165.0,
		"item_id": ITEMS.ORE_ORICHALCUM,
	},
	&"aether": {
		"kind": "ore",
		"req": 95,
		"xp": 300,
		"charges": 8,
		"respawn_s": 180.0,
		"item_id": ITEMS.ORE_AETHER,
	},
}

const GEM_NODES := {
	&"gem_lesser": {
		"kind": "gem",
		"req": 40,
		"xp": 38,
		"charges": 6,
		"respawn_s": 166.0,
		"drops": [
			{ "id": ITEMS.GEM_OPAL,      "weight": 45.0 },
			{ "id": ITEMS.GEM_JADE,      "weight": 35.0 },
			{ "id": ITEMS.GEM_BLUE_TOPAZ, "weight": 20.0 },
		],
	},
	&"gem_precious": {
		"kind": "gem",
		"req": 45,
		"xp": 52,
		"charges": 5,
		"respawn_s": 188.0,
		"drops": [
			{ "id": ITEMS.GEM_SAPPHIRE, "weight": 34.0 },
			{ "id": ITEMS.GEM_EMERALD,  "weight": 34.0 },
			{ "id": ITEMS.GEM_RUBY,     "weight": 28.0 },
			{ "id": ITEMS.GEM_DIAMOND,  "weight": 4.0  },
		],
	},
	&"gem_rare": {
		"kind": "gem",
		"req": 70,
		"xp": 65,
		"charges": 4,
		"respawn_s": 230.0,
		"drops": [
			{ "id": ITEMS.GEM_DIAMOND,     "weight": 70.0 },
			{ "id": ITEMS.GEM_DRAGONSTONE, "weight": 30.0 },
		],
	},
	&"gem_mythic": {
		"kind": "gem",
		"req": 90,
		"xp": 80,
		"charges": 3,
		"respawn_s": 263.0,
		"drops": [
			{ "id": ITEMS.GEM_DIAMOND,     "weight": 50.0 },
			{ "id": ITEMS.GEM_DRAGONSTONE, "weight": 50.0 },
		],
		"override_chance": 0.003,
		"override_item_id": ITEMS.GEM_ONYX,
	},
}

const MINING_KEYWORD_TO_NODE_ID := {
	# Ore
	"copper":     &"copper",
	"tin":        &"tin",
	"iron":       &"iron",
	"coal":       &"coal",
	"silver":     &"silver",
	"gold":       &"gold",
	"mithrite":   &"mithrite",
	"adamantite": &"adamantite",
	"orichalcum": &"orichalcum",
	"aether":     &"aether",

	# Rock
	"limestone":  &"limestone",
	"sandstone":  &"sandstone",
	"basalt":     &"basalt",
	"granite":    &"granite",
	"marble":     &"marble",
	"clay":       &"clay",

}


# For convenience
func _all_tables() -> Array:
	return [STONE_NODES, ORE_NODES, GEM_NODES]


# -------------------------------------------------------------------
# Per-tile node state (charges + respawn_at)
# -------------------------------------------------------------------

var _node_state: Dictionary = {}


func _ready() -> void:
	randomize()


func get_node_def(node_id: StringName) -> Dictionary:
	for table in _all_tables():
		if table.has(node_id):
			return table[node_id]
	return {}


func is_node_unlocked(node_id: StringName, lv: int) -> bool:
	var def := get_node_def(node_id)
	if def.is_empty():
		return false
	return lv >= int(def.get("req", 1))


func _get_or_init_state(axial: Vector2i, node_id: StringName) -> Dictionary:
	var per_tile := _node_state.get(axial, {}) as Dictionary
	if per_tile.is_empty():
		per_tile = {}
		_node_state[axial] = per_tile

	var st: Dictionary = per_tile.get(node_id, {})
	if st.is_empty():
		var def := get_node_def(node_id)
		if def.is_empty():
			return {}
		st = {
			"charges": int(def.get("charges", 0)),
			"respawn_at": 0.0,
		}
		per_tile[node_id] = st

	return st


func _ensure_respawn(axial: Vector2i, node_id: StringName) -> Dictionary:
	var st := _get_or_init_state(axial, node_id)
	if st.is_empty():
		return st

	var charges: int = int(st.get("charges", 0))
	var respawn_at: float = float(st.get("respawn_at", 0.0))

	if charges <= 0 and respawn_at > 0.0:
		var now := Time.get_unix_time_from_system()
		if now >= respawn_at:
			var def := get_node_def(node_id)
			st["charges"] = int(def.get("charges", 0))
			st["respawn_at"] = 0.0

	return st


func get_node_status(axial: Vector2i, node_id: StringName) -> Dictionary:
	var def := get_node_def(node_id)
	if def.is_empty():
		return { "is_available": false, "charges": 0, "respawn_at": 0.0 }

	var st := _ensure_respawn(axial, node_id)
	if st.is_empty():
		return { "is_available": false, "charges": 0, "respawn_at": 0.0 }

	var charges: int = int(st.get("charges", 0))
	var respawn_at: float = float(st.get("respawn_at", 0.0))
	var now := Time.get_unix_time_from_system()

	var available := (charges > 0) and (respawn_at <= 0.0 or now >= respawn_at)
	return {
		"is_available": available,
		"charges": charges,
		"respawn_at": respawn_at,
	}


func is_node_available(axial: Vector2i, node_id: StringName) -> bool:
	return bool(get_node_status(axial, node_id).get("is_available", false))


func _consume_charge(axial: Vector2i, node_id: StringName) -> void:
	var def := get_node_def(node_id)
	if def.is_empty():
		return

	var st := _ensure_respawn(axial, node_id)
	if st.is_empty():
		return

	var charges: int = int(st.get("charges", 0))
	if charges <= 0:
		return

	charges -= 1
	st["charges"] = charges

	if charges <= 0:
		var respawn_s: float = float(def.get("respawn_s", 0.0))
		if respawn_s > 0.0:
			st["respawn_at"] = Time.get_unix_time_from_system() + respawn_s


func clear_all_state() -> void:
	_node_state.clear()

# -------------------------------------------------------------------
# Drop preview for UI (used by gathering menu)
# -------------------------------------------------------------------

func get_drop_preview_for_node(node_id: StringName) -> Array:
	# Returns an Array of:
	#   { "item_id": StringName, "chance": float(0..1), "is_fail": bool }
	# Mining currently has no "fail" per action, only depletion,
	# so we never generate a fail row here.
	var def := get_node_def(node_id)
	if def.is_empty():
		return []

	var kind := String(def.get("kind", ""))

	if kind == "gem":
		return _get_gem_drop_preview(def)
	else:
			# Stone + ore nodes: fixed item, always 1 per successful action
		var item_id: StringName = def.get("item_id", StringName(""))
		if item_id == StringName(""):
			return []
		return [
			{
				"item_id": item_id,
				"chance": 1.0,     # 100% per action
				"qty": 1,          # NEW
				"is_fail": false,
			}
		]


# -------------------------------------------------------------------
# Drop preview helper for UI (Gathering Menu)
# -------------------------------------------------------------------


func _get_gem_drop_preview(def: Dictionary) -> Array:
	var drops_any: Variant = def.get("drops", [])
	if not (drops_any is Array):
		return []
	var drops: Array = drops_any
	if drops.is_empty():
		return []

	# Sum weights
	var total_weight := 0.0
	for row_v in drops:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		total_weight += float(row.get("weight", 0.0))

	if total_weight <= 0.0:
		return []

	var override_chance: float = float(def.get("override_chance", 0.0))
	override_chance = clamp(override_chance, 0.0, 1.0)
	var override_item: StringName = def.get("override_item_id", StringName(""))

	var result: Array = []

	# 1) Mythic override (e.g. Onyx)
	if override_item != StringName("") and override_chance > 0.0:
		result.append({
			"item_id": override_item,
			"chance": override_chance,  # e.g. 0.003 = 0.3%
			"qty": 1,                   # NEW
			"is_fail": false,
		})


	# 2) Base gem table scaled by (1 - override_chance)
	var scale := 1.0 - override_chance
	if scale <= 0.0:
		# Override takes 100% of the probability mass
		return result

	for row_v in drops:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v

		var base_item: StringName = row.get("id", StringName(""))
		if base_item == StringName(""):
			continue

		var w := float(row.get("weight", 0.0))
		if w <= 0.0:
			continue

		var base_chance := w / total_weight
		var final_chance := base_chance * scale

		result.append({
			"item_id": base_item,
			"chance": final_chance,
			"qty": 1,             # NEW
			"is_fail": false,
		})


	# Sort so highest chance first
	result.sort_custom(func(a, b):
		return float(a["chance"]) > float(b["chance"])
	)

	return result
# -------------------------------------------------------------------
# Gem drop helper
# -------------------------------------------------------------------

func _roll_gem_drop(def: Dictionary) -> StringName:
	var drops: Array = def.get("drops", [])
	if drops.is_empty():
		return StringName("")

	var total := 0.0
	for row in drops:
		total += float(row.get("weight", 0.0))
	if total <= 0.0:
		return StringName("")

	var r := randf() * total
	var running_total := 0.0
	var base_item := StringName("")

	for row in drops:
		running_total += float(row.get("weight", 0.0))
		if r <= running_total:
			base_item = row.get("id", StringName(""))
			break

	if base_item == StringName(""):
		base_item = drops.back().get("id", StringName(""))

	var override_chance := float(def.get("override_chance", 0.0))
	if override_chance > 0.0 and randf() < override_chance:
		return def.get("override_item_id", base_item)

	return base_item

func _get_cooldown_seconds(axial: Vector2i, node_id: StringName) -> float:
	# We deliberately read _node_state directly to avoid creating new state.
	var per_tile_v: Variant = _node_state.get(axial, {})
	if not (per_tile_v is Dictionary):
		return 0.0
	var per_tile: Dictionary = per_tile_v

	if not per_tile.has(node_id):
		return 0.0

	var st_v: Variant = per_tile[node_id]
	if not (st_v is Dictionary):
		return 0.0
	var st: Dictionary = st_v

	var respawn_at: float = float(st.get("respawn_at", 0.0))
	if respawn_at <= 0.0:
		return 0.0

	var now := Time.get_unix_time_from_system()
	return max(0.0, respawn_at - now)

# -------------------------------------------------------------------
# Core action: do_mine (Mining-side equivalent of do_astromancy_work)
# -------------------------------------------------------------------
func do_mine(node_id: StringName, ax: Vector2i) -> Dictionary:
	var def: Dictionary = get_node_def(node_id)
	if def.is_empty():
		return {
			"xp": 0,
			"loot_desc": "",
			"empty": true,
			"cooldown": 0.0,
		}

	# --- 1) If node is not available, report depletion + cooldown ---
	if not is_node_available(ax, node_id):
		var cd := _get_cooldown_seconds(ax, node_id)
		return {
			"xp": 0,
			"loot_desc": "This node is depleted.",
			"empty": true,
			"cooldown": cd,
		}

	# --- 2) Node is available → actually mine one charge ---
	_consume_charge(ax, node_id)

	var xp: int = int(def.get("xp", 1))

	# Decide what item to give
	var kind := String(def.get("kind", ""))
	var item_id: StringName = def.get("item_id", StringName(""))
	var qty: int = int(def.get("qty", 1))
	if qty <= 0:
		qty = 1

	# Gem nodes use the weighted drop table instead of a fixed item_id
	if kind == "gem":
		item_id = _roll_gem_drop(def)

	# Drop into Bank (if the singleton exists)
	if item_id != StringName("") and typeof(Bank) != TYPE_NIL and Bank.has_method("add"):
		Bank.add(item_id, qty)

	# Build a readable loot message (if Items singleton exists)
	var loot_desc := "Gained mining loot."
	if typeof(Items) != TYPE_NIL \
	and Items.has_method("display_name") \
	and Items.has_method("is_valid") \
	and Items.is_valid(item_id):
		loot_desc = "Gained %dx %s" % [qty, Items.display_name(item_id)]

	# --- 3) Optional: detect if we JUST depleted the node ---
	# (i.e., next time it won't be available).
	var empty_now: bool = not is_node_available(ax, node_id)
	var cooldown_now: float = 0.0
	if empty_now:
		cooldown_now = _get_cooldown_seconds(ax, node_id)

	return {
		"xp": xp,
		"loot_desc": loot_desc,
		"empty": empty_now,
		"cooldown": cooldown_now,
	}
