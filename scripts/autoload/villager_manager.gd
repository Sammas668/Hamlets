# res://autoloads/villager_manager.gd
extends Node
## Manages villager jobs, timed execution, and integration with Scrying / Astromancy / Crafting.

signal job_changed(index: int, job_id: StringName)
signal job_progress(v_idx: int, job: StringName, elapsed: float, duration: float)
signal job_completed(v_idx: int, job: StringName, xp: int, loot_desc: String)

# --- Job IDs ---
const JOB_NONE: StringName         = &"none"
const JOB_SCRYING: StringName      = &"scrying"
const JOB_ASTROMANCY: StringName   = &"astromancy"
const JOB_MINING: StringName       = &"mining"
const JOB_WOODCUTTING: StringName  = &"woodcutting"  # NEW
const JOB_FISHING: StringName      = &"fishing"      
const JOB_SMITHING: StringName     = &"smithing"   
const JOB_CONSTRUCTION: StringName = &"construction"

# Later you can add: const JOB_SMITHING := &"smithing", etc.

# v_idx:int -> { "job": StringName, "ax": Vector2i, "recipe": StringName, "elapsed": float, "duration": float, "remaining": int }
var _jobs: Dictionary = {}


func _ready() -> void:
	# Hook into the global tick once
	if typeof(GameLoop) != TYPE_NIL and GameLoop.has_signal("tick"):
		if not GameLoop.tick.is_connected(_on_tick):
			GameLoop.tick.connect(_on_tick)


# -------------------------------------------------------------------
# Public API (TaskPicker / CraftMenu use these)
# -------------------------------------------------------------------


## Main entry: assign a job at a tile, with an optional recipe id
## and optional multi-craft count (for Craft 1 / X / All).
func assign_job_with_recipe(
		v_idx: int,
		job: StringName,
		ax: Vector2i,
		recipe_id: StringName,
		remaining: int = 1,
		repeat: bool = false
) -> void:
	if not _is_valid_index(v_idx):
		return

	remaining = max(1, remaining)
	var duration: float = _job_duration(job, recipe_id)

	# --- NEW: per-job node_detail (used only for woodcutting right now) ---
	var node_detail: String = ""
	if job == JOB_WOODCUTTING:
		# Look up the recipe spec so we can grab its node_detail
		var specs: Array = get_recipes_for_job(v_idx, job, ax)
		for spec_v in specs:
			if not (spec_v is Dictionary):
				continue
			var spec: Dictionary = spec_v
			var sid: StringName = spec.get("id", StringName(""))
			if sid == recipe_id:
				node_detail = String(spec.get("node_detail", ""))
				break

	_jobs[v_idx] = {
		"job": job,
		"ax": ax,
		"recipe": recipe_id,
		"elapsed": 0.0,
		"duration": duration,
		"remaining": remaining,
		"repeat": repeat,
		# NEW: stored so WoodcuttingSystem can use the correct node
		"node_detail": node_detail,
	}

	var world := get_tree().get_first_node_in_group("World")
	if world and world.has_method("assign_villager_to_tile"):
		world.call("assign_villager_to_tile", v_idx, ax)

	job_changed.emit(v_idx, job)
	job_progress.emit(v_idx, job, 0.0, duration)


func _assign_job_with_custom_duration(
		v_idx: int,
		job: StringName,
		ax: Vector2i,
		recipe_id: StringName,
		remaining: int,
		repeat: bool,
		duration: float
) -> void:
	if not _is_valid_index(v_idx):
		return

	remaining = max(1, remaining)

	if duration <= 0.0:
		duration = _job_duration(job, recipe_id)

	_jobs[v_idx] = {
		"job": job,
		"ax": ax,
		"recipe": recipe_id,
		"elapsed": 0.0,
		"duration": duration,
		"remaining": remaining,
		"repeat": repeat,
	}

	var world := get_tree().get_first_node_in_group("World")
	if world and world.has_method("assign_villager_to_tile"):
		world.call("assign_villager_to_tile", v_idx, ax)

	job_changed.emit(v_idx, job)
	job_progress.emit(v_idx, job, 0.0, duration)


# For Mining: map keywords in modifier text -> Mining node_id
const MINING_KEYWORD_TO_NODE_ID := {
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

	"limestone":  &"limestone",
	"sandstone":  &"sandstone",
	"basalt":     &"basalt",
	"granite":    &"granite",
	"marble":     &"marble",
	"clay":       &"clay",      #
}

# NEW: match your actual modifier names as substrings
const WOODCUTTING_KEYWORD_TO_TARGET_ID := {
	# Tier 1 – Forest
	"pine grove":           &"pine_grove",      # normal pine grove
	"overgrown pine grove": &"pine_grove",
	"thick pine grove":     &"pine_grove",      # thick variant uses same tree target

	# Tier 2 – Maplewood Vale
	"vale orchard":         &"birch_grove",     # or swap to maple_grove
	"hedgerow grove":     &"birch_grove",

	# Tier 3 – Silkwood
	"silkwood grove":   &"oakwood",
	"mulberry grove":   &"oakwood",

	# Generic fallbacks if you ever add literal tree names into text
	"pine":      &"pine_grove",
	"birch":     &"birch_grove",
	"oak":       &"oakwood",
	"willow":    &"willow_grove",
	"maple":     &"maple_grove",
	"yew":       &"yew_grove",
	"ironwood":  &"ironwood_grove",
	"redwood":   &"redwood_grove",
	"sakura":    &"sakura_grove",
	"elder":     &"elder_grove",
	"ivy":       &"climbing_ivy",
}

## Backwards compatible: no recipe, explicit tile
func assign_job_at(v_idx: int, job: StringName, ax: Vector2i) -> void:
	assign_job_with_recipe(v_idx, job, ax, StringName())


## Optional API if someone calls without a tile
func assign_job(v_idx: int, job: StringName) -> void:
	assign_job_with_recipe(v_idx, job, Vector2i.ZERO, StringName())


func stop_job(v_idx: int) -> void:
	# Always ask World to clear this villager's icon / tile mapping
	var world := get_tree().get_first_node_in_group("World")
	if world and world.has_method("clear_villager_from_tile"):
		world.call("clear_villager_from_tile", v_idx)

	if _jobs.has(v_idx):
		_jobs.erase(v_idx)
	job_changed.emit(v_idx, JOB_NONE)


func get_job(v_idx: int) -> StringName:
	if _jobs.has(v_idx):
		var st: Dictionary = _jobs[v_idx]
		return StringName(st.get("job", JOB_NONE))
	return JOB_NONE


func get_job_state(v_idx: int) -> Dictionary:
	if _jobs.has(v_idx):
		return _jobs[v_idx]
	return {}


func job_label(job_id: StringName) -> String:
	match job_id:
		JOB_SCRYING:
			return "Scrying"
		JOB_ASTROMANCY:
			return "Astromancy"
		JOB_MINING:
			return "Mining"
		JOB_WOODCUTTING:
			return "Woodcutting"
		JOB_CONSTRUCTION:
			return "Construction"
		JOB_FISHING:
			return "Fishing"
		JOB_SMITHING:
			return "Smithing"
		_:
			return "None"






func _tile_modifiers(world: Node, ax: Vector2i) -> Array:
	if world and world.has_method("get_modifiers_at"):
		var mods_v: Variant = world.call("get_modifiers_at", ax)
		if mods_v is Array:
			return mods_v
	return []


func _tile_has_resource_for_skill(mods: Array, skill_id: String) -> bool:
	var needle := "[" + skill_id.to_lower() + "]"
	for m in mods:
		var s := String(m).to_lower()
		if s.begins_with("resource spawn") and s.find(needle) != -1:
			return true
	return false


func _infer_mining_node_id_from_text(text: String) -> StringName:
	var lower := text.to_lower()
	for kw in MINING_KEYWORD_TO_NODE_ID.keys():
		if lower.find(kw) != -1:
			return MINING_KEYWORD_TO_NODE_ID[kw]
	return StringName("")

# NEW: infer woodcutting target id from modifier text
func _infer_woodcut_target_id_from_text(text: String) -> StringName:
	var lower := text.to_lower()
	for kw in WOODCUTTING_KEYWORD_TO_TARGET_ID.keys():
		if lower.find(kw) != -1:
			return WOODCUTTING_KEYWORD_TO_TARGET_ID[kw]
	return StringName("")


# Context-aware specs for TaskPicker: { label, job, id, disabled, reason }
func get_jobs_for_tile(_v_idx: int, ax: Vector2i) -> Array:
	var specs: Array = []

	var world := get_tree().get_first_node_in_group("World")
	var has_frag := false
	var adjacent := false
	var mods: Array = []

	if world:
		if world.has_method("_has_fragment_at"):
			has_frag = bool(world.call("_has_fragment_at", ax))
		if world.has_method("_is_adjacent_to_any"):
			adjacent = bool(world.call("_is_adjacent_to_any", ax))
		# New: pull tile modifiers (if World exposes them)
		mods = _tile_modifiers(world, ax)

	# 1) On an existing fragment tile → normal jobs (Scrying / Astromancy / Mining / Woodcutting)
	if has_frag:
		specs.append({
			"label": "Scrying",
			"job": JOB_SCRYING,
			"id": 1,
			"disabled": false,
			"reason": "",
		})

		specs.append({
			"label": "Astromancy",
			"job": JOB_ASTROMANCY,
			"id": 2,
			"disabled": false,
			"reason": "",
		})

		# 🆕 Smithing – for now, available on any fragment tile
		specs.append({
			"label": "Smithing",
			"job": JOB_SMITHING,
			"id": 3,
			"disabled": false,
			"reason": "",
		})

		specs.append({
			"label": "Construction",
			"job": JOB_CONSTRUCTION,
			"id": 4,
			"disabled": false,
			"reason": "",
		})

		# Mining only if this tile has at least one Mining resource
		if _tile_has_resource_for_skill(mods, "mining"):
			specs.append({
				"label": "Mining",
				"job": JOB_MINING,
				"id": 10,
				"disabled": false,
				"reason": "",
			})


		# NEW: Woodcutting only if this tile has at least one Woodcutting resource
		var has_wood := _tile_has_resource_for_skill(mods, "woodcutting")

		# Extra safety: also check ResourceNodes registry if available
		if not has_wood \
		and typeof(ResourceNodes) != TYPE_NIL \
		and ResourceNodes.has_method("has_any"):
			has_wood = ResourceNodes.has_any(ax, "woodcutting")

		if has_wood:
			specs.append({
				"label": "Woodcutting",
				"job": JOB_WOODCUTTING,
				"id": 11,
				"disabled": false,
				"reason": "",
			})

		# 🆕 Fishing only if this tile has at least one Fishing resource
		var has_fish := _tile_has_resource_for_skill(mods, "fishing")

		# Extra safety: also check ResourceNodes registry if available
		if not has_fish \
		and typeof(ResourceNodes) != TYPE_NIL \
		and ResourceNodes.has_method("has_any"):
			has_fish = ResourceNodes.has_any(ax, "fishing")

		if has_fish:
			specs.append({
				"label": "Fishing",
				"job": JOB_FISHING,
				"id": 12,          # next free menu id
				"disabled": false,
				"reason": "",
			})


	# 2) Empty but adjacent → ONLY Astromancy, for summoning a new fragment
	elif adjacent and not has_frag:
		specs.append({
			"label": "Astromancy — Summon Fragment",
			"job": JOB_ASTROMANCY,
			"id": 100,
			"disabled": false,
			"reason": "",
		})

	# 3) Empty and NOT adjacent → no valid tasks
	else:
		specs.append({
			"label": "No valid tasks here",
			"job": JOB_NONE,
			"id": 999,
			"disabled": true,
			"reason": "Must be on a fragment or empty hex adjacent to one.",
		})

	return specs


# --- NEW: recipes for jobs ------------------------------------------
# Returns: Array[Dictionary] of per-job recipes:
# {
#   id: StringName,
#   label: String,
#   icon: String (path),
#   level_req: int,
#   xp: int,
#   inputs: Array[{ item: StringName, qty: int }],
#   output: Dictionary { item: StringName, qty: int },
#   desc: String,
# }

func get_recipes_for_job(v_idx: int, job: StringName, ax: Vector2i) -> Array:
	var recipes: Array = []
	var world := get_tree().get_first_node_in_group("World")

	# --- ASTROMANCY recipes (existing logic) ---
	if job == JOB_ASTROMANCY:
		var has_frag := false
		var adjacent := false

		if world:
			if world.has_method("_has_fragment_at"):
				has_frag = bool(world.call("_has_fragment_at", ax))
			if world.has_method("_is_adjacent_to_any"):
				adjacent = bool(world.call("_is_adjacent_to_any", ax))

		# Astromancy level for gating (prefer villager’s own skill)
		var astro_lv: int = 1

		if v_idx >= 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
			astro_lv = max(1, int(Villagers.get_skill_level(v_idx, "astromancy")))
		elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
			astro_lv = max(1, int(Skills.get_skill_level("astromancy")))

		var max_rank: int = 10
		if typeof(AstromancySystem) != TYPE_NIL and AstromancySystem.has_method("get_max_rank_for_level"):
			max_rank = AstromancySystem.get_max_rank_for_level(astro_lv)
		max_rank = clampi(max_rank, 1, 10)

		# CASE A: On an existing fragment → forging recipes + collapse
		if has_frag:
			# Normal forge recipes (Augury -> Plain Shards)
			for rank in range(1, max_rank + 1):
				if typeof(AstromancySystem) == TYPE_NIL:
					break

				var cost: Dictionary = AstromancySystem.get_cost_for_rank(rank)
				if cost.is_empty():
					continue

				var grade: int = int(cost.get("grade", rank))
				var qty: int   = int(cost.get("qty", 0))

				var shard_id: StringName  = AstromancySystem.SHARD_IDS.get(rank, Items.R1_PLAIN)
				var augury_id: StringName = AstromancySystem.AUGURY_IDS.get(grade, Items.AUGURY_A1)

				var label: String    = "Plain Shard (R%d)" % rank
				var aug_name: String = "Augury G%d" % grade

				if typeof(Items) != TYPE_NIL:
					if Items.has_method("is_valid") and Items.has_method("display_name"):
						if Items.is_valid(shard_id):
							label = Items.display_name(shard_id)
						if Items.is_valid(augury_id):
							aug_name = Items.display_name(augury_id)

				var desc: String = "Forge %s by spending %d× %s." % [label, qty, aug_name]

				var icon_tex: Texture2D = null
				if typeof(Items) != TYPE_NIL and Items.has_method("get_icon"):
					icon_tex = Items.get_icon(shard_id)

				var level_req: int = 1
				if typeof(AstromancySystem) != TYPE_NIL:
					level_req = int(AstromancySystem.RANK_GATE_LEVEL.get(rank, 1))

				recipes.append({
					"id": shard_id,
					"label": label,
					"icon": icon_tex,
					"level_req": level_req,
					"xp": AstromancySystem.FORGE_XP_PER_RANK * rank,
					"inputs": [
						{ "item": augury_id, "qty": qty },
					],
					"output": { "item": shard_id, "qty": 1 },
					"desc": desc,
				})

			# EXTRA: Collapse Fragment recipe (no materials, no XP)
			if typeof(AstromancySystem) != TYPE_NIL:
				var collapse_label := "Collapse Fragment"
				var collapse_desc := "Collapse this fragment, refunding some Augury and freeing the tile."
				var collapse_icon: Texture2D = null

				recipes.append({
					"id": AstromancySystem.ACTION_COLLAPSE_FRAGMENT,
					"label": collapse_label,
					"icon": collapse_icon,
					"level_req": 1,
					"xp": 0,
					"inputs": [],
					"output": {},
					"desc": collapse_desc,
				})

			return recipes

		# CASE B: Empty but adjacent → summon fragment using shards
		if adjacent and not has_frag:
			if typeof(Bank) == TYPE_NIL or not Bank.has_method("amount"):
				return recipes

			for rank in range(1, max_rank + 1):
				if typeof(AstromancySystem) == TYPE_NIL:
					break
				if not AstromancySystem.SHARD_IDS.has(rank):
					continue

				var shard_id2: StringName = AstromancySystem.SHARD_IDS[rank]
				var have := int(Bank.amount(shard_id2))
				if have <= 0:
					continue

				var label2: String = "Plain Shard (R%d)" % rank
				if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name"):
					if Items.is_valid(shard_id2):
						label2 = Items.display_name(shard_id2)

				var level_req2: int = 1
				if typeof(AstromancySystem) != TYPE_NIL:
					level_req2 = int(AstromancySystem.RANK_GATE_LEVEL.get(rank, 1))

				var desc2: String = "Spend 1× %s to summon a new fragment here." % label2

				var icon_tex2: Texture2D = null
				if typeof(Items) != TYPE_NIL and Items.has_method("get_icon"):
					icon_tex2 = Items.get_icon(shard_id2)

				recipes.append({
					"id": shard_id2,
					"label": label2,
					"icon": icon_tex2,
					"level_req": level_req2,
					"xp": AstromancySystem.FORGE_XP_PER_RANK * rank,
					"inputs": [
						{ "item": shard_id2, "qty": 1 },
					],
					"output": { "item": shard_id2, "qty": 0 },
					"desc": desc2,
				})

			return recipes

		return recipes


	# 🆕 --- SMITHING recipes (global, level-gated) ---
	if job == JOB_SMITHING:
		# Work out Smithing level (prefer villager, fallback to global)
		var smith_lv: int = 1
		if v_idx >= 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
			smith_lv = int(Villagers.get_skill_level(v_idx, "smithing"))
		elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
			smith_lv = int(Skills.get_skill_level("smithing"))

		if typeof(SmithingSystem) == TYPE_NIL:
			return recipes
		if not SmithingSystem.has_method("get_recipes_for_level"):
			return recipes

		return SmithingSystem.get_recipes_for_level(smith_lv)

	# --- CONSTRUCTION recipes (JSON-driven building blueprints) ---
	# --- CONSTRUCTION recipes (JSON-driven building blueprints) ---
	if job == JOB_CONSTRUCTION:
		var con_lv: int = 1
		if v_idx >= 0 \
		and typeof(Villagers) != TYPE_NIL \
		and Villagers.has_method("get_skill_level"):
			con_lv = int(Villagers.get_skill_level(v_idx, "construction"))
		elif typeof(Skills) != TYPE_NIL \
		and Skills.has_method("get_skill_level"):
			con_lv = int(Skills.get_skill_level("construction"))

		if typeof(ConstructionSystem) == TYPE_NIL:
			return recipes

		# Prefer the kind-filtered API if it exists
		if ConstructionSystem.has_method("get_recipes_for_level_and_kind"):
			# We only want the **struct materials** here, not the whole building list.
			var all_mat: Array = ConstructionSystem.get_recipes_for_level_and_kind(con_lv, "material")
			var out: Array = []

			for rec_v in all_mat:
				if typeof(rec_v) != TYPE_DICTIONARY:
					continue
				var rec: Dictionary = rec_v

				# Only keep entries that actually have a part (Frame, Floor Section, etc.)
				var part_str := String(rec.get("part", "")).strip_edges()
				if part_str == "":
					continue

				out.append(rec)

			return out

		# Fallback if you ever remove the kind-filtered helper
		if ConstructionSystem.has_method("get_recipes_for_level"):
			return ConstructionSystem.get_recipes_for_level(con_lv)

		return recipes


	# --- WOODCUTTING recipes (NODE-DRIVEN) ---
	if job == JOB_WOODCUTTING:
		if world == null:
			return recipes
		# Use the helper so we get proper log items instead of "Twigs"
		return _build_woodcutting_recipes_for_tile(v_idx, ax, world)

	# --- MINING recipes (NODE-DRIVEN) ---
	if job == JOB_MINING:
		if world == null:
			return recipes
		return _build_mining_recipes_for_tile(v_idx, ax, world)

	# 🆕 --- FISHING recipes (NODE-DRIVEN) ---
	if job == JOB_FISHING:
		if world == null:
			return recipes
		return _build_fishing_recipes_for_tile(v_idx, ax, world)

	# --- Other jobs (e.g. Scrying currently has no recipes) ---
	return recipes

func _job_duration(job: StringName, _recipe_id: StringName = StringName()) -> float:
	match job:
		JOB_SCRYING:
			return 2.4

		JOB_ASTROMANCY:
			return 4.8

		JOB_MINING:
			if typeof(MiningSystem) != TYPE_NIL:
				return float(MiningSystem.BASE_ACTION_TIME)
			return 2.4

		JOB_WOODCUTTING:
			if typeof(WoodcuttingSystem) != TYPE_NIL:
				return float(WoodcuttingSystem.BASE_ACTION_TIME)
			return 2.4   # ✅ fallback so this branch always returns

		JOB_FISHING:
			if typeof(FishingSystem) != TYPE_NIL:
				return float(FishingSystem.BASE_ACTION_TIME)
			return 2.4   # ✅ fallback here too

		JOB_SMITHING:                          # 🆕
			if typeof(SmithingSystem) != TYPE_NIL:
				return float(SmithingSystem.BASE_ACTION_TIME)
			return 4.8

		JOB_CONSTRUCTION:
			if typeof(ConstructionSystem) != TYPE_NIL:
				return float(ConstructionSystem.BASE_ACTION_TIME)
			return 4.8


		_:
			return 2.4


func _complete_job(v_idx: int) -> void:
	if not _jobs.has(v_idx):
		return

	var state: Dictionary = _jobs[v_idx]
	var job: StringName = StringName(state.get("job", JOB_NONE))
	var recipe: StringName = StringName(state.get("recipe", StringName()))

	var ax: Vector2i = Vector2i.ZERO
	if state.has("ax") and state["ax"] is Vector2i:
		ax = state["ax"] as Vector2i

	var remaining: int = int(state.get("remaining", 1))
	var repeat: bool = bool(state.get("repeat", false))

	var result: Dictionary = {}

	if job == JOB_SCRYING:
		if typeof(ScryingSystem) != TYPE_NIL and ScryingSystem.has_method("do_scry"):
			result = ScryingSystem.do_scry()

	elif job == JOB_ASTROMANCY:
		if typeof(AstromancySystem) != TYPE_NIL and AstromancySystem.has_method("do_astromancy_work"):
			result = AstromancySystem.do_astromancy_work(recipe, ax)

	elif job == JOB_SMITHING:
		if typeof(SmithingSystem) != TYPE_NIL and SmithingSystem.has_method("do_smithing_work"):
			# recipe = smithing recipe id
			result = SmithingSystem.do_smithing_work(recipe)

	elif job == JOB_CONSTRUCTION:
		if typeof(ConstructionSystem) != TYPE_NIL and ConstructionSystem.has_method("do_construction_work"):
			# recipe = building/module id from ConstructionSystem
			result = ConstructionSystem.do_construction_work(recipe)


	elif job == JOB_MINING:
		if typeof(MiningSystem) != TYPE_NIL and MiningSystem.has_method("do_mine"):
			# recipe = node_id (e.g. "copper", "coal", "limestone")
			result = MiningSystem.do_mine(recipe, ax)

	elif job == JOB_WOODCUTTING:
		if typeof(WoodcuttingSystem) != TYPE_NIL and WoodcuttingSystem.has_method("do_chop"):
			# recipe = target_id (e.g. "pine_grove", "oakwood")
			# node_detail = "Pine Grove" vs "Thick Pine Grove"
			var node_detail: String = String(state.get("node_detail", ""))
			result = WoodcuttingSystem.do_chop(v_idx, recipe, ax, node_detail)
	elif job == JOB_FISHING:
		if typeof(FishingSystem) != TYPE_NIL and FishingSystem.has_method("do_fish"):
			# recipe = node_id (e.g. "N1", "R3", "H7")
			# Work out Fishing level (prefer villager, fallback to global)
			var fish_lv: int = 1
			if v_idx >= 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
				fish_lv = int(Villagers.get_skill_level(v_idx, "fishing"))
			elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
				fish_lv = int(Skills.get_skill_level("fishing"))

			# Call matches: do_fish(node_id, fishing_level, effective_grade=-1)
			result = FishingSystem.do_fish(recipe, fish_lv)






	var xp: int = int(result.get("xp", 0))
	var loot_desc: String = String(result.get("loot_desc", ""))

	# Optional Mining hints: was the node empty, and how long until it respawns?
	var is_empty: bool = bool(result.get("empty", false))
	var cooldown: float = float(result.get("cooldown", 0.0))


	if xp > 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("add_skill_xp"):
		var skill_id: String = ""
		if job == JOB_SCRYING:
			skill_id = "scrying"
		elif job == JOB_ASTROMANCY:
			skill_id = "astromancy"
		elif job == JOB_MINING:
			skill_id = "mining"
		elif job == JOB_WOODCUTTING:      
			skill_id = "woodcutting"
		elif job == JOB_FISHING:        
			skill_id = "fishing"
		elif job == JOB_SMITHING:           
			skill_id = "smithing"
		elif job == JOB_CONSTRUCTION:
			skill_id = "construction"


		if skill_id != "":
			Villagers.add_skill_xp(v_idx, skill_id, xp)

	job_completed.emit(v_idx, job, xp, loot_desc)

	# ------------------------------------------------------------
	# Non-Astromancy auto-repeat (Mining, Scrying, Woodcutting, etc.)
	# ------------------------------------------------------------
	var will_repeat := false

	if repeat and job != JOB_ASTROMANCY:
		if job == JOB_MINING:
			# For Mining we use MiningSystem's hints:
			# - is_empty: node depleted
			# - cooldown: seconds until respawn
			var next_duration: float = _job_duration(job, recipe)

			# If the node is empty and we have a cooldown, idle until respawn.
			if is_empty and cooldown > 0.0:
				next_duration = cooldown

			will_repeat = true
			call_deferred(
				"_assign_job_with_custom_duration",
				v_idx, job, ax, recipe, 1, true, next_duration
			)

		elif job == JOB_WOODCUTTING:
			# Woodcutting: just keep chopping while Repeat is on
			will_repeat = true
			call_deferred(
				"assign_job_with_recipe",
				v_idx, job, ax, recipe, 1, true
			)

		elif job == JOB_FISHING:    # 🆕 repeat fishing
			will_repeat = true
			call_deferred(
				"assign_job_with_recipe",
				v_idx, job, ax, recipe, 1, true
			)

		else:
			# Default behaviour for other repeatable jobs (e.g. Scrying):
			# keep repeating while they successfully give XP.
			if xp > 0:
				will_repeat = true
				call_deferred(
					"assign_job_with_recipe",
					v_idx, job, ax, recipe, 1, true
				)


	# Clear current job state
	_jobs.erase(v_idx)

	# Only broadcast "None" if we're not about to immediately reassign via repeat
	if not will_repeat:
		job_changed.emit(v_idx, JOB_NONE)

	# ------------------------------------------------------------
	# Multi-craft handling
	#  - Astromancy: forge multi-craft on forge tiles only (existing behaviour)
	#  - Smithing: straightforward multi-craft anywhere Smithing is allowed
	# ------------------------------------------------------------
	if job == JOB_ASTROMANCY:
		remaining -= 1

		# If no more groves requested, or this grove failed, stop.
		if remaining <= 0 or xp <= 0:
			return

		# Detect whether this tile is a fragment tile (forge) or empty (summon)
		var world := get_tree().get_first_node_in_group("World")
		var is_forge := false
		if world and world.has_method("_has_fragment_at"):
			is_forge = bool(world.call("_has_fragment_at", ax))

		# Only multi-craft on forge tiles; summoning stays strictly one-shot.
		if not is_forge:
			return

		# Re-queue the same job with the updated remaining count
		call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, remaining)

	elif job == JOB_SMITHING:
		# Simple multi-craft loop for Smithing (Craft X / All)
		remaining -= 1
		if remaining <= 0 or xp <= 0:
			return

		call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, remaining)

	elif job == JOB_CONSTRUCTION:
		# Simple multi-craft loop for Construction (Craft X / All)
		remaining -= 1
		if remaining <= 0 or xp <= 0:
			return

		call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, remaining)


	# Other jobs: no multi-craft beyond the generic repeat logic


# --- Save / Load jobs ----------------------------------------------

func to_save_dict() -> Dictionary:
	var jobs_save: Dictionary = {}

	for k in _jobs.keys():
		var v_idx: int = int(k)
		var st_v: Variant = _jobs[k]
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v

		var ax: Vector2i = Vector2i.ZERO
		if st.has("ax") and st["ax"] is Vector2i:
			ax = st["ax"] as Vector2i

		jobs_save[v_idx] = {
			"job":        StringName(st.get("job", JOB_NONE)),
			"recipe":     StringName(st.get("recipe", StringName())),
			"ax":         ax,
			"elapsed":    float(st.get("elapsed", 0.0)),
			"duration":   float(st.get("duration", 0.0)),
			"remaining":  int(st.get("remaining", 1)),
			"repeat":     bool(st.get("repeat", false)),
			# NEW: keep which grove this job was for
			"node_detail": String(st.get("node_detail", "")),
		}


	return {
		"jobs": jobs_save,
	}


func from_save_dict(d: Dictionary) -> void:
	_jobs.clear()

	var jobs_v: Variant = d.get("jobs", {})
	if not (jobs_v is Dictionary):
		return

	var jobs_d: Dictionary = jobs_v as Dictionary
	for k in jobs_d.keys():
		var v_idx: int = int(k)
		var st_v: Variant = jobs_d[k]
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v

		var ax: Vector2i = Vector2i.ZERO
		if st.has("ax") and st["ax"] is Vector2i:
			ax = st["ax"] as Vector2i

		_jobs[v_idx] = {
			"job":        StringName(st.get("job", JOB_NONE)),
			"recipe":     StringName(st.get("recipe", StringName())),
			"ax":         ax,
			"elapsed":    float(st.get("elapsed", 0.0)),
			"duration":   float(st.get("duration", 0.0)),
			"remaining":  int(st.get("remaining", 1)),
			"repeat":     bool(st.get("repeat", false)),
			"node_detail": String(st.get("node_detail", "")),
		}


	# Re-emit signals so UIs (task list / progress bars) can rebuild after load
	for k in _jobs.keys():
		var v_idx: int = int(k)
		var st: Dictionary = _jobs[v_idx]
		var job: StringName = StringName(st.get("job", JOB_NONE))
		var elapsed: float = float(st.get("elapsed", 0.0))
		var duration: float = float(st.get("duration", 0.0))

		job_changed.emit(v_idx, job)
		job_progress.emit(v_idx, job, elapsed, duration)


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

# NEW: build Woodcutting recipes for a tile
func _build_woodcutting_recipes_for_tile(v_idx: int, ax: Vector2i, world: Node) -> Array:
	var recipes: Array = []
	var mods: Array = _tile_modifiers(world, ax)
	if mods.is_empty():
		return recipes

	# Work out Woodcutting level (prefer villager, fallback to global)
	var wc_lv: int = 1
	if v_idx >= 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
		wc_lv = int(Villagers.get_skill_level(v_idx, "woodcutting"))
	elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
		wc_lv = int(Skills.get_skill_level("woodcutting"))

	for m in mods:
		var text := String(m)
		var lower := text.to_lower()

		# Be tolerant: just require "resource spawn" and "[woodcutting]" anywhere
		if lower.find("resource spawn") == -1:
			continue
		if lower.find("[woodcutting]") == -1:
			continue

		var target_id: StringName = _infer_woodcut_target_id_from_text(text)
		if target_id == StringName(""):
			continue

		if typeof(WoodcuttingSystem) == TYPE_NIL or not WoodcuttingSystem.has_method("get_target_def"):
			continue

		var def: Dictionary = WoodcuttingSystem.get_target_def(target_id)
		if def.is_empty():
			continue

		var req: int = int(def.get("lvl_req", 1))
		if wc_lv < req:
			continue

		var xp: int = int(def.get("xp", 1))

		# Choose a representative log for the icon + display name
		var icon_tex: Texture2D = null
		var log_item: StringName = StringName("")
		var log_name: String = ""

		if typeof(Items) != TYPE_NIL:
			var drops_any: Variant = def.get("drops", [])
			if drops_any is Array:
				var drops: Array = drops_any
				if drops.size() > 0:
					# Design rule: FIRST entry in drops is the MAIN log
					var first_any: Variant = drops[0]
					if first_any is Dictionary:
						var first_row: Dictionary = first_any
						log_item = first_row.get("item", StringName(""))

			if log_item != StringName(""):
				if Items.has_method("get_icon"):
					icon_tex = Items.get_icon(log_item)
				if Items.has_method("is_valid") \
				and Items.has_method("display_name") \
				and Items.is_valid(log_item):
					log_name = Items.display_name(log_item)

		# Extract just the tree name part after the colon, if present
		var deposit_name: String = text
		var colon_idx: int = text.find(":")
		if colon_idx >= 0 and colon_idx + 1 < text.length():
			deposit_name = text.substr(colon_idx + 1).strip_edges()

		# This is exactly what ResourceNodes uses as "detail"
		var node_detail: String = deposit_name

		# Label + description including log type
		var label: String = "Chop %s" % deposit_name
		if log_name != "":
			label = "Chop %s (%s)" % [deposit_name, log_name]

		var desc: String = "Chop this %s." % deposit_name
		if log_name != "":
			desc = "Chop this %s for %s." % [deposit_name, log_name]

		# 🔍 Ask WoodcuttingSystem for a drop preview (logs, bonus drops, nests, amber, etc.)
		var drop_preview: Array = []
		if typeof(WoodcuttingSystem) != TYPE_NIL \
		and WoodcuttingSystem.has_method("get_drop_preview_for_target"):
			drop_preview = WoodcuttingSystem.get_drop_preview_for_target(
				target_id,
				ax,
				node_detail,
				wc_lv   # <-- use THIS villager's woodcutting level
			)

		recipes.append({
			"id":               target_id,   # recipe_id => Woodcutting target_id ("pine_grove", etc.)
			"label":            label,
			"icon":             icon_tex,
			"level_req":        req,
			"xp":               xp,
			"inputs": [],                   # tools etc. could go here later
			"output": {},                   # WoodcuttingSystem.do_chop actually gives the items
			"desc":             desc,
			"primary_item":     log_item,
			"primary_item_name": log_name,
			"drop_preview":     drop_preview,
			# NEW: used when we actually start the job
			"node_detail":      node_detail,
		})

	return recipes

# NEW: build Fishing recipes for a tile
func _build_fishing_recipes_for_tile(v_idx: int, ax: Vector2i, _world: Node) -> Array:
	var recipes: Array = []

	# Prefer ResourceNodes if you've wired fishing there
	if typeof(ResourceNodes) == TYPE_NIL or not ResourceNodes.has_method("get_nodes"):
		return recipes

	# Expect ResourceNodes to store fishing nodes like:
	# { "skill": "fishing", "node_id": "N1", "detail": "Riverbank Shallows" }
	var fish_nodes: Array = ResourceNodes.get_nodes(ax, "fishing")
	if fish_nodes.is_empty():
		return recipes

	# Work out Fishing level (prefer villager, fallback to global)
	var fish_lv: int = 1
	if v_idx >= 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
		fish_lv = int(Villagers.get_skill_level(v_idx, "fishing"))
	elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
		fish_lv = int(Skills.get_skill_level("fishing"))

	for n_v in fish_nodes:
		if not (n_v is Dictionary):
			continue
		var n: Dictionary = n_v

		# Canonical node id, e.g. "N1", "R3", "H7"
		var node_id: StringName = n.get("node_id", StringName(""))
		if node_id == StringName(""):
			continue

		if typeof(FishingSystem) == TYPE_NIL or not FishingSystem.has_method("get_node_def"):
			continue

		var def: Dictionary = FishingSystem.get_node_def(node_id)
		if def.is_empty():
			continue

		var req: int = int(def.get("req_level", 1))
		if fish_lv < req:
			continue

		var display_name: String = String(def.get("display_name", "Fishing Spot"))
		var max_grade: int = int(def.get("max_grade", 1))
		var species_by_grade: Dictionary = def.get("species_by_grade", {})

		# Estimate grade and XP per cycle from FishingSystem.XP_BY_GRADE
		var grade: int = int(ceil(fish_lv / 10.0))
		grade = clampi(grade, 1, max_grade)

		var xp: int = 0
		if typeof(FishingSystem) != TYPE_NIL and FishingSystem.has_method("get_node_def"):
			xp = int(FishingSystem.XP_BY_GRADE.get(grade, 0))


		# Primary fish for icon/name
		var icon_tex: Texture2D = null
		var fish_item: StringName = StringName("")
		var fish_name: String = ""

		if typeof(Items) != TYPE_NIL:
			# Use first entry from the table at this (or lower) grade
			var g := grade
			while g > 0 and not species_by_grade.has(g):
				g -= 1
			if g > 0:
				var entries: Array = species_by_grade[g]
				if entries.size() > 0:
					var first_any: Variant = entries[0]
					if first_any is Dictionary:
						var first_row: Dictionary = first_any
						fish_item = first_row.get("fish", StringName(""))

			if fish_item != StringName(""):
				if Items.has_method("get_icon"):
					icon_tex = Items.get_icon(fish_item)
				if Items.has_method("is_valid") \
				and Items.has_method("display_name") \
				and Items.is_valid(fish_item):
					fish_name = Items.display_name(fish_item)

		# Human-facing detail string from ResourceNodes, fallback to display_name
		var detail: String = String(n.get("detail", display_name))

		var label: String = "Fish %s" % detail
		if fish_name != "":
			label = "Fish %s (%s)" % [detail, fish_name]

		var desc: String = "Fish at %s." % detail
		if fish_name != "":
			desc = "Fish at %s for %s." % [detail, fish_name]

		# Drop preview for the GatheringMenu bottom-right summary
		var drop_preview: Array = []
		if typeof(FishingSystem) != TYPE_NIL \
		and FishingSystem.has_method("get_drop_preview_for_node"):
			drop_preview = FishingSystem.get_drop_preview_for_node(
				node_id,
				fish_lv
			)

		recipes.append({
			"id":                node_id,   # recipe_id => Fishing node_id ("N1", "R3", "H7")
			"label":             label,
			"icon":              icon_tex,
			"level_req":         req,
			"xp":                xp,
			"inputs": [],
			"output": {},
			"desc":              desc,
			"primary_item":      fish_item,
			"primary_item_name": fish_name,
			"drop_preview":      drop_preview,
		})

	return recipes


func _build_mining_recipes_for_tile(v_idx: int, ax: Vector2i, world: Node) -> Array:
	var recipes: Array = []
	var mods: Array = _tile_modifiers(world, ax)
	if mods.is_empty():
		return recipes

	# Work out Mining level (prefer villager, fallback to global)
	var mining_lv: int = 1
	if v_idx >= 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
		mining_lv = int(Villagers.get_skill_level(v_idx, "mining"))
	elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
		mining_lv = int(Skills.get_skill_level("mining"))

	for m in mods:
		var text := String(m)
		var lower := text.to_lower()

		if not lower.begins_with("resource spawn"):
			continue
		if lower.find("[mining]") == -1:
			continue

		var node_id: StringName = _infer_mining_node_id_from_text(text)
		if node_id == StringName(""):
			continue

		if typeof(MiningSystem) == TYPE_NIL or not MiningSystem.has_method("get_node_def"):
			continue

		var def: Dictionary = MiningSystem.get_node_def(node_id)
		if def.is_empty():
			continue

		var req: int = int(def.get("req", 1))
		if mining_lv < req:
			continue

		var xp: int = int(def.get("xp", 1))
		var item_id: StringName = def.get("item_id", StringName(""))

		var icon_tex: Texture2D = null
		if typeof(Items) != TYPE_NIL and Items.has_method("get_icon") and item_id != StringName(""):
			icon_tex = Items.get_icon(item_id)

		# 🔍 NEW: ask MiningSystem for a drop preview for this node
		var drop_preview: Array = []
		if typeof(MiningSystem) != TYPE_NIL and MiningSystem.has_method("get_drop_preview_for_node"):
			drop_preview = MiningSystem.get_drop_preview_for_node(node_id)

		# Extract just the deposit name part after the colon, if present
		var deposit_name: String = text
		var colon_idx: int = text.find(":")
		if colon_idx >= 0 and colon_idx + 1 < text.length():
			deposit_name = text.substr(colon_idx + 1).strip_edges()

		var label: String = "Mine %s" % deposit_name
		var desc: String = "Mine this %s deposit." % deposit_name

		recipes.append({
			"id": node_id,           # recipe_id => Mining node_id ("copper", "coal", etc.)
			"label": label,
			"icon": icon_tex,
			"level_req": req,
			"xp": xp,
			"inputs": [],            # tools etc. could go here later
			"output": {},            # MiningSystem.do_mine actually gives the item
			"desc": desc,

			# 🔍 NEW: UI can now show chances
			"drop_preview": drop_preview,
		})

	return recipes


# -------------------------------------------------------------------
# Tick → advance timers and complete jobs
# -------------------------------------------------------------------
func _on_tick(delta_s: float, _tick_index: int) -> void:
	# Advance all active jobs based on the GameLoop tick.
	# Use a copy of keys so we can safely erase jobs inside the loop.
	var keys := _jobs.keys()
	for k in keys:
		var v_idx: int = int(k)
		if not _jobs.has(v_idx):
			continue

		var st: Dictionary = _jobs[v_idx]
		var job: StringName = StringName(st.get("job", JOB_NONE))
		if job == JOB_NONE:
			continue

		var duration: float = float(st.get("duration", 0.0))
		if duration <= 0.0:
			# Recompute if somehow missing
			var recipe_id: StringName = StringName(st.get("recipe", StringName()))
			duration = _job_duration(job, recipe_id)
			st["duration"] = duration

		var elapsed: float = float(st.get("elapsed", 0.0))
		elapsed += delta_s
		st["elapsed"] = elapsed
		_jobs[v_idx] = st

		# Notify UI of progress
		job_progress.emit(v_idx, job, elapsed, duration)

		# Job finished → resolve it
		if elapsed >= duration:
			_complete_job(v_idx)


func _is_valid_index(i: int) -> bool:
	return (
		typeof(Villagers) != TYPE_NIL
		and Villagers.has_method("count")
		and i >= 0
		and i < Villagers.count()
	)
