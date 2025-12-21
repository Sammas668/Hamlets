extends Node

# Essence cost per summon
const SUMMON_COST: int = 3

# --- Essence pool ---
var essence: int = 30

# Store last placed coord as two ints (avoids Vector2i assignment issues)
var last_placed_q: int = 0
var last_placed_r: int = 0

# Internal maps use "q,r" string keys for stability.
# Occupied tiles (have a fragment in the scene)
var _occupied: Dictionary = {}          # key: "q,r" -> true

# Anchored tiles (should not despawn once you add despawn logic)
var _anchored: Dictionary = {}          # key: "q,r" -> true

# Biome per coord
var _biomes: Dictionary = {}            # key: "q,r" -> biome string, e.g. "Mountain"

# Tile tier / ring per coord (R1..R10 etc.)
var _tiers: Dictionary = {}             # key: "q,r" -> int tier, e.g. 1, 2, ...

# Tile modifiers per coord (names only, visuals handled by Fragment)
var _modifiers: Dictionary = {}         # key: "q,r" -> Array[String] of modifier ids

# Binding between tiles and villagers (for job assignment / recall)
# key: "q,r" -> villager index
var _bound_villagers: Dictionary = {}

# Augury grades per coord (local alt to Astromancy if still used)
var augury: Array[int] = []

# Shards (global currency) per id string, e.g. "r1_plain" -> amount
var shards: Dictionary = {}   # e.g. "r1_plain" -> 3


# ---------------------------------------------------
# Internal key helper
# ---------------------------------------------------
func _key(ax: Vector2i) -> String:
	return "%d,%d" % [ax.x, ax.y]


# ---------------------------------------------------
# Essence API
# ---------------------------------------------------
func can_summon() -> bool:
	return essence >= SUMMON_COST

func spend_summon_cost() -> void:
	essence = max(0, essence - SUMMON_COST)

func add_essence(amount: int) -> void:
	essence = max(0, essence + amount)


# ---------------------------------------------------
# Occupancy / anchoring
# ---------------------------------------------------
func set_occupied(ax: Vector2i, occupied: bool) -> void:
	var k: String = _key(ax)
	if occupied:
		_occupied[k] = true
	else:
		if _occupied.has(k):
			_occupied.erase(k)

func is_occupied(ax: Vector2i) -> bool:
	return _occupied.has(_key(ax))

func set_anchored(ax: Vector2i, anchored: bool) -> void:
	var k: String = _key(ax)
	if anchored:
		_anchored[k] = true
	else:
		if _anchored.has(k):
			_anchored.erase(k)

func is_anchored(ax: Vector2i) -> bool:
	return _anchored.has(_key(ax))


# ---------------------------------------------------
# Biome + tier per coord
# ---------------------------------------------------
func set_biome(ax: Vector2i, biome: String) -> void:
	_biomes[_key(ax)] = biome

func get_biome(ax: Vector2i) -> String:
	return String(_biomes.get(_key(ax), "Hamlet"))

func set_tier(ax: Vector2i, tier: int) -> void:
	_tiers[_key(ax)] = tier

func get_tier(ax: Vector2i) -> int:
	return int(_tiers.get(_key(ax), 1))


# ---------------------------------------------------
# Modifiers per tile
# ---------------------------------------------------
func set_modifiers(ax: Vector2i, mods: Array) -> void:
	var k: String = _key(ax)
	var out: Array[String] = []
	for m in mods:
		if m is String:
			out.append(m)
	_modifiers[k] = out

func get_modifiers(ax: Vector2i) -> Array[String]:
	var k: String = _key(ax)
	if _modifiers.has(k):
		return _modifiers[k]
	return []

func add_modifier(ax: Vector2i, mod: String) -> void:
	var k: String = _key(ax)
	var arr: Array[String] = []
	if _modifiers.has(k):
		arr = _modifiers[k]
	if not arr.has(mod):
		arr.append(mod)
	_modifiers[k] = arr

func clear_modifiers(ax: Vector2i) -> void:
	var k: String = _key(ax)
	if _modifiers.has(k):
		_modifiers.erase(k)


# ---------------------------------------------------
# Villager bindings
# ---------------------------------------------------
func bind_villager(ax: Vector2i, villager_id: int) -> void:
	var k: String = _key(ax)
	if villager_id >= 0:
		_bound_villagers[k] = villager_id
	else:
		if _bound_villagers.has(k):
			_bound_villagers.erase(k)

func get_bound_villager_id(ax: Vector2i) -> int:
	return int(_bound_villagers.get(_key(ax), -1))

func is_bound(ax: Vector2i) -> bool:
	return get_bound_villager_id(ax) >= 0

func clear_villager_binding(ax: Vector2i) -> void:
	var k: String = _key(ax)
	if _bound_villagers.has(k):
		_bound_villagers.erase(k)


# ---------------------------------------------------
# Augury (local version – if still used anywhere)
# ---------------------------------------------------
func _augury_index(grade: int) -> int:
	# Clamp grade to [1, augury.size()] and map to [0 .. size-1]
	var g: int = clampi(grade, 1, augury.size())
	return g - 1

func get_augury_grade(_ax: Vector2i) -> int:
	# Example stub – adapt if you still use augury this way
	if augury.is_empty():
		return 0
	var idx: int = _augury_index(1)
	return augury[idx]


# ---------------------------------------------------
# Shards
# ---------------------------------------------------
func add_shards(shard_id: String, amount: int) -> void:
	var cur: int = int(shards.get(shard_id, 0))
	cur += amount
	if cur < 0:
		cur = 0
	shards[shard_id] = cur

func get_shards(shard_id: String) -> int:
	return int(shards.get(shard_id, 0))


# ---------------------------------------------------
# Save / load support
# ---------------------------------------------------
func to_dict() -> Dictionary:
	var d: Dictionary = {}

	d["essence"] = essence
	d["last_placed_q"] = last_placed_q
	d["last_placed_r"] = last_placed_r

	d["occupied"] = _occupied
	d["anchored"] = _anchored
	d["biomes"] = _biomes
	d["tiers"] = _tiers
	d["modifiers"] = _modifiers
	d["bound_villagers"] = _bound_villagers

	d["augury"] = augury
	d["shards"] = shards

	return d

func from_dict(d: Dictionary) -> void:
	essence = int(d.get("essence", essence))
	last_placed_q = int(d.get("last_placed_q", last_placed_q))
	last_placed_r = int(d.get("last_placed_r", last_placed_r))

	var occ_v: Variant = d.get("occupied", {})
	if occ_v is Dictionary:
		_occupied = occ_v

	var anch_v: Variant = d.get("anchored", {})
	if anch_v is Dictionary:
		_anchored = anch_v

	var bi_v: Variant = d.get("biomes", {})
	if bi_v is Dictionary:
		_biomes = bi_v

	var t_v: Variant = d.get("tiers", {})
	if t_v is Dictionary:
		_tiers = t_v

	var mods_v: Variant = d.get("modifiers", {})
	if mods_v is Dictionary:
		_modifiers = mods_v

	var bound_v: Variant = d.get("bound_villagers", {})
	if bound_v is Dictionary:
		_bound_villagers = bound_v

	var aug_v: Variant = d.get("augury", [])
	if aug_v is Array:
		augury.clear()
		for v in (aug_v as Array):
			augury.append(int(v))

	var shards_v: Variant = d.get("shards", {})
	if shards_v is Dictionary:
		shards.clear()
		var sd: Dictionary = shards_v
		for k in sd.keys():
			var key_str: String = String(k)
			shards[key_str] = int(sd[k])
