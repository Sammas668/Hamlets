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
const JOB_WOODCUTTING: StringName  = &"woodcutting"
const JOB_FISHING: StringName      = &"fishing"
const JOB_SMITHING: StringName     = &"smithing"
const JOB_CONSTRUCTION: StringName = &"construction"
const JOB_HERBALISM: StringName    = &"herbalism"

# v_idx:int -> {
#   "job": StringName,
#   "ax": Vector2i,
#   "recipe": StringName,
#   "elapsed": float,
#   "duration": float,
#   "remaining": int,
#   "repeat": bool,
#   "node_detail": String
# }
var _jobs: Dictionary = {}


func _ready() -> void:
	# Hook into the global tick once.
	if typeof(GameLoop) != TYPE_NIL and GameLoop.has_signal("tick"):
		if not GameLoop.tick.is_connected(_on_tick):
			GameLoop.tick.connect(_on_tick)


# -------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------

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

	remaining = maxi(1, remaining)
	var duration: float = _job_duration(job, recipe_id)

	# VillagerManager is the authority: re-check the selected recipe here.
	var selected_recipe: Dictionary = {}
	if recipe_id != StringName(""):
		selected_recipe = _find_recipe_for_job(v_idx, job, ax, recipe_id)
		if selected_recipe.is_empty():
			return

		if not _can_villager_use_recipe(v_idx, job, selected_recipe):
			return

		duration = float(selected_recipe.get("duration", duration))

	# Per-job node_detail; woodcutting uses this.
	var node_detail: String = ""
	if job == JOB_WOODCUTTING and not selected_recipe.is_empty():
		node_detail = String(selected_recipe.get("node_detail", ""))

	_jobs[v_idx] = {
		"job": job,
		"ax": ax,
		"recipe": recipe_id,
		"elapsed": 0.0,
		"duration": duration,
		"remaining": remaining,
		"repeat": repeat,
		"node_detail": node_detail,
	}

	var world: Node = get_tree().get_first_node_in_group("World")
	if world != null and world.has_method("assign_villager_to_tile"):
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
		duration: float,
		node_detail: String = ""
) -> void:
	if not _is_valid_index(v_idx):
		return

	var rem: int = maxi(1, remaining)
	var dur: float = duration
	if dur <= 0.0:
		dur = _job_duration(job, recipe_id)

	# Internal repeat/multi-craft assignment still re-checks recipe authority.
	var selected_recipe: Dictionary = {}
	if recipe_id != StringName(""):
		selected_recipe = _find_recipe_for_job(v_idx, job, ax, recipe_id)
		if selected_recipe.is_empty():
			return

		if not _can_villager_use_recipe(v_idx, job, selected_recipe):
			return

		if duration <= 0.0:
			dur = float(selected_recipe.get("duration", dur))

	if job == JOB_WOODCUTTING and node_detail == "" and not selected_recipe.is_empty():
		node_detail = String(selected_recipe.get("node_detail", ""))

	_jobs[v_idx] = {
		"job": job,
		"ax": ax,
		"recipe": recipe_id,
		"elapsed": 0.0,
		"duration": dur,
		"remaining": rem,
		"repeat": repeat,
		"node_detail": node_detail,
	}

	var world: Node = get_tree().get_first_node_in_group("World")
	if world != null and world.has_method("assign_villager_to_tile"):
		world.call("assign_villager_to_tile", v_idx, ax)

	job_changed.emit(v_idx, job)
	job_progress.emit(v_idx, job, 0.0, dur)


func assign_job_at(v_idx: int, job: StringName, ax: Vector2i) -> void:
	assign_job_with_recipe(v_idx, job, ax, StringName())


func assign_job(v_idx: int, job: StringName) -> void:
	assign_job_with_recipe(v_idx, job, Vector2i.ZERO, StringName())


func stop_job(v_idx: int) -> void:
	if _jobs.has(v_idx):
		_jobs.erase(v_idx)

	var world: Node = get_tree().get_first_node_in_group("World")
	if world != null and world.has_method("clear_villager_from_tile"):
		world.call("clear_villager_from_tile", v_idx)

	job_changed.emit(v_idx, JOB_NONE)


func get_job(v_idx: int) -> StringName:
	if _jobs.has(v_idx):
		var st_v: Variant = _jobs[v_idx]
		if st_v is Dictionary:
			var st: Dictionary = st_v as Dictionary
			return StringName(st.get("job", JOB_NONE))
	return JOB_NONE


func get_job_state(v_idx: int) -> Dictionary:
	if _jobs.has(v_idx):
		var st_v: Variant = _jobs[v_idx]
		if st_v is Dictionary:
			return (st_v as Dictionary).duplicate(true)
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
		JOB_FISHING:
			return "Fishing"
		JOB_HERBALISM:
			return "Herbalism"
		JOB_SMITHING:
			return "Smithing"
		JOB_CONSTRUCTION:
			return "Construction"
		_:
			return "None"


# -------------------------------------------------------------------
# Job / skill helpers
# -------------------------------------------------------------------

func _skill_for_job(job: StringName) -> String:
	match job:
		JOB_SCRYING:
			return "scrying"
		JOB_ASTROMANCY:
			return "astromancy"
		JOB_MINING:
			return "mining"
		JOB_WOODCUTTING:
			return "woodcutting"
		JOB_FISHING:
			return "fishing"
		JOB_HERBALISM:
			return "herbalism"
		JOB_SMITHING:
			return "smithing"
		JOB_CONSTRUCTION:
			return "construction"
		_:
			return ""


func _default_skill_for_job(job: StringName) -> StringName:
	match job:
		JOB_SCRYING:
			return &"scrying"
		JOB_ASTROMANCY:
			return &"astromancy"
		JOB_MINING:
			return &"mining"
		JOB_WOODCUTTING:
			return &"woodcutting"
		JOB_FISHING:
			return &"fishing"
		JOB_HERBALISM:
			return &"herbalism"
		JOB_SMITHING:
			return &"smithing"
		JOB_CONSTRUCTION:
			return &"construction"
		_:
			return StringName("")


func _get_villager_skill_level(v_idx: int, skill_id: String) -> int:
	if v_idx < 0:
		return 1

	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
		return maxi(1, int(Villagers.get_skill_level(v_idx, skill_id)))

	return 1


func _award_job_xp(v_idx: int, job: StringName, xp: int) -> void:
	if xp <= 0:
		return

	var skill_id: String = _skill_for_job(job)
	if skill_id == "":
		return

	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("add_skill_xp"):
		Villagers.add_skill_xp(v_idx, skill_id, xp)


# -------------------------------------------------------------------
# Recipe contract / gating
# -------------------------------------------------------------------

func _normalize_outputs(raw: Dictionary) -> Array:
	var outputs: Array = []

	# Preferred new field.
	var outputs_v: Variant = raw.get("outputs", [])
	if outputs_v is Array:
		for out_v: Variant in outputs_v:
			if out_v is Dictionary:
				var out_d: Dictionary = out_v as Dictionary
				var item_id: StringName = StringName(out_d.get("item", out_d.get("id", StringName(""))))
				var qty: int = int(out_d.get("qty", 1))
				if item_id != StringName("") and qty > 0:
					outputs.append({
						"item": item_id,
						"qty": qty,
					})

	if outputs.size() > 0:
		return outputs

	# Legacy field: "output": { "item": id, "qty": n }
	var output_v: Variant = raw.get("output", {})
	if output_v is Dictionary:
		var output_d: Dictionary = output_v as Dictionary
		var output_item: StringName = StringName(output_d.get("item", output_d.get("id", StringName(""))))
		var output_qty: int = int(output_d.get("qty", 1))
		if output_item != StringName("") and output_qty > 0:
			outputs.append({
				"item": output_item,
				"qty": output_qty,
			})

	if outputs.size() > 0:
		return outputs

	# Legacy fields: "output_item" + "output_qty"
	var item_v: Variant = raw.get("output_item", raw.get("output_id", StringName("")))
	var item_id2: StringName = StringName(item_v)
	var qty2: int = int(raw.get("output_qty", 1))
	if item_id2 != StringName("") and qty2 > 0:
		outputs.append({
			"item": item_id2,
			"qty": qty2,
		})

	return outputs


func _normalize_recipe(job: StringName, raw: Dictionary) -> Dictionary:
	var recipe_id: StringName = StringName(raw.get("id", StringName("")))
	if recipe_id == StringName(""):
		return {}

	var default_skill: StringName = _default_skill_for_job(job)

	# "skill" means the skill used to perform/gate this recipe.
	# Do NOT use "use_skill" here: in Smithing that describes what the crafted tool is used for.
	# Do NOT use "linked_skill" here: in Construction that describes the building's linked role.
	var skill: StringName = StringName(raw.get("skill", StringName("")))
	if skill == StringName(""):
		skill = default_skill

	var inputs_v: Variant = raw.get("inputs", [])
	var inputs: Array = []
	if inputs_v is Array:
		inputs = inputs_v as Array

	var outputs: Array = _normalize_outputs(raw)

	var duration: float = float(raw.get("duration", _job_duration(job, recipe_id)))

	var normalized: Dictionary = raw.duplicate(true)

	normalized["id"] = recipe_id
	normalized["label"] = String(raw.get("label", String(recipe_id)))
	normalized["skill"] = skill
	normalized["level_req"] = int(raw.get("level_req", 1))
	normalized["xp"] = int(raw.get("xp", 0))
	normalized["duration"] = duration
	normalized["inputs"] = inputs
	normalized["outputs"] = outputs
	normalized["desc"] = String(raw.get("desc", ""))
	normalized["icon"] = raw.get("icon", null)

	# Temporary compatibility for older UI/systems.
	# Remove later after Craft_Menu/Gathering_Menu read only "outputs".
	if not normalized.has("output") and outputs.size() == 1:
		normalized["output"] = outputs[0]

	if not normalized.has("output_item") and outputs.size() == 1:
		var out0: Dictionary = outputs[0] as Dictionary
		normalized["output_item"] = out0.get("item", StringName(""))
		normalized["output_qty"] = int(out0.get("qty", 1))

	return normalized


func _normalize_recipe_list(job: StringName, raw_recipes: Array) -> Array:
	var out: Array = []

	for rec_v: Variant in raw_recipes:
		if not (rec_v is Dictionary):
			continue

		var rec: Dictionary = _normalize_recipe(job, rec_v as Dictionary)
		if rec.is_empty():
			continue

		out.append(rec)

	return out


func _recipe_skill_id(job: StringName, recipe: Dictionary) -> String:
	var skill: StringName = StringName(recipe.get("skill", _default_skill_for_job(job)))
	return String(skill)


func _can_villager_use_recipe(v_idx: int, job: StringName, recipe: Dictionary) -> bool:
	if recipe.is_empty():
		return false

	if bool(recipe.get("disabled", false)):
		return false

	var skill_id: String = _recipe_skill_id(job, recipe)
	if skill_id == "":
		return true

	var level_req: int = int(recipe.get("level_req", 1))
	var lv: int = _get_villager_skill_level(v_idx, skill_id)

	return lv >= level_req


func _find_recipe_for_job(v_idx: int, job: StringName, ax: Vector2i, recipe_id: StringName) -> Dictionary:
	var recipes: Array = get_recipes_for_job(v_idx, job, ax)

	for rec_v: Variant in recipes:
		if not (rec_v is Dictionary):
			continue

		var rec: Dictionary = rec_v as Dictionary
		if StringName(rec.get("id", StringName(""))) == recipe_id:
			return rec

	return {}


func _abort_job(v_idx: int) -> void:
	if _jobs.has(v_idx):
		_jobs.erase(v_idx)

	var world: Node = get_tree().get_first_node_in_group("World")
	if world != null and world.has_method("clear_villager_from_tile"):
		world.call("clear_villager_from_tile", v_idx)

	job_changed.emit(v_idx, JOB_NONE)


# -------------------------------------------------------------------
# Keyword inference
# -------------------------------------------------------------------

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
	"clay":       &"clay",
}

const WOODCUTTING_KEYWORD_TO_TARGET_ID := {
	"pine grove":           &"pine_grove",
	"overgrown pine grove": &"pine_grove",
	"thick pine grove":     &"pine_grove",

	"vale orchard":         &"birch_grove",
	"hedgerow grove":       &"birch_grove",

	"silkwood grove":       &"oakwood",
	"mulberry grove":       &"oakwood",

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


func _infer_mining_node_id_from_text(text: String) -> StringName:
	var lower: String = text.to_lower()
	for kw_v: Variant in MINING_KEYWORD_TO_NODE_ID.keys():
		var kw: String = String(kw_v)
		if lower.find(kw) != -1:
			return StringName(MINING_KEYWORD_TO_NODE_ID[kw_v])
	return StringName("")


func _infer_woodcut_target_id_from_text(text: String) -> StringName:
	var lower: String = text.to_lower()
	for kw_v: Variant in WOODCUTTING_KEYWORD_TO_TARGET_ID.keys():
		var kw: String = String(kw_v)
		if lower.find(kw) != -1:
			return StringName(WOODCUTTING_KEYWORD_TO_TARGET_ID[kw_v])
	return StringName("")


func _infer_fishing_node_id_from_text(text: String) -> StringName:
	var lower: String = text.to_lower()

	# Best: match FishingSystem node display_name → node_id.
	if typeof(FishingSystem) != TYPE_NIL and FishingSystem.has_method("get_node_def"):
		var nodes_v: Variant = FishingSystem.get("FISH_NODES")
		if nodes_v is Dictionary:
			var nodes: Dictionary = nodes_v as Dictionary
			for nid_v: Variant in nodes.keys():
				var def_v: Variant = nodes[nid_v]
				if not (def_v is Dictionary):
					continue

				var def: Dictionary = def_v as Dictionary
				var dn: String = String(def.get("display_name", "")).to_lower()
				if dn != "" and lower.find(dn) != -1:
					return StringName(nid_v)

	return StringName("")


# -------------------------------------------------------------------
# Herbalism autoload lookup
# -------------------------------------------------------------------

func _get_herbalism() -> Node:
	var n: Node = get_node_or_null("/root/HerbalismSystem")
	if n != null:
		return n

	n = get_node_or_null("/root/herbalism_system")
	if n != null:
		return n

	n = get_node_or_null("/root/herbalism")
	if n != null:
		return n

	return null


# Convert "Frost Kava Patch" -> "frost_kava_patch".
func _to_snake_id(s: String) -> String:
	var out: String = ""
	var prev_us: bool = false

	for i: int in range(s.length()):
		var cp: int = s.unicode_at(i)
		var ch: String = s.substr(i, 1)

		var is_digit: bool = (cp >= 48 and cp <= 57)
		var is_upper: bool = (cp >= 65 and cp <= 90)
		var is_lower: bool = (cp >= 97 and cp <= 122)
		var is_alnum: bool = is_digit or is_upper or is_lower

		if is_alnum:
			out += ch.to_lower()
			prev_us = false
		else:
			if not prev_us and out.length() > 0:
				out += "_"
				prev_us = true

	while out.begins_with("_"):
		out = out.substr(1)
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)

	while out.find("__") != -1:
		out = out.replace("__", "_")

	return out


func _infer_herbal_patch_id_from_text(text: String) -> StringName:
	var hs: Node = _get_herbalism()
	if hs == null:
		return StringName("")

	var lower: String = text.to_lower()

	# 1) Use HerbalismSystem keyword map if it exists.
	var map_v: Variant = hs.get("HERBALISM_KEYWORD_TO_PATCH_ID")
	if map_v is Dictionary:
		var map: Dictionary = map_v as Dictionary
		for kw_v: Variant in map.keys():
			var kw: String = String(kw_v).to_lower()
			if lower.find(kw) != -1:
				return StringName(map[kw_v])

	# 2) If Herbalism provides a helper, use it.
	if hs.has_method("infer_patch_id_from_text"):
		var v: Variant = hs.call("infer_patch_id_from_text", text)
		return StringName(v)

	# 3) Fallback: slugify and validate.
	var base: String = _to_snake_id(text)
	if base == "":
		return StringName("")

	var candidates: Array[String] = [base]
	if not base.ends_with("_patch"):
		candidates.append(base + "_patch")

	if hs.has_method("get_patch_def"):
		for c: String in candidates:
			var def_v: Variant = hs.call("get_patch_def", StringName(c))
			if def_v is Dictionary and not (def_v as Dictionary).is_empty():
				return StringName(c)

	return StringName("")


# -------------------------------------------------------------------
# Tile helpers
# -------------------------------------------------------------------

func _tile_modifiers(world: Node, ax: Vector2i) -> Array:
	if world != null and world.has_method("get_modifiers_at"):
		var mods_v: Variant = world.call("get_modifiers_at", ax)
		if mods_v is Array:
			return mods_v as Array
	return []


func _mod_get_kind_skill_detail(m: Variant) -> Dictionary:
	# Supports:
	# - Dictionary: { "kind": "Resource Spawn", "skill": "mining", "name": "Copper Vein", ... }
	# - String:     "Resource Spawn [mining]: Copper Vein"
	if m is Dictionary:
		var d: Dictionary = m as Dictionary
		var kind: String = String(d.get("kind", "")).strip_edges()
		var skill: String = String(d.get("skill", "")).strip_edges().to_lower()
		var detail: String = String(d.get("name", d.get("detail", ""))).strip_edges()

		var header: String = kind
		if skill != "":
			header += " [" + skill + "]"

		var out_text: String = header
		if detail != "":
			out_text += ": " + detail

		return {
			"kind": kind,
			"skill": skill,
			"detail": detail,
			"text": out_text,
		}

	var s: String = String(m)
	var header_s: String = s
	var detail_s: String = ""

	var parts: PackedStringArray = s.split(": ", false, 2)
	if parts.size() > 0:
		header_s = String(parts[0])
	if parts.size() > 1:
		detail_s = String(parts[1])

	var kind_base: String = header_s
	var skill_id: String = ""

	var open_idx: int = header_s.find("[")
	if open_idx != -1:
		var close_idx: int = header_s.find("]", open_idx + 1)
		if close_idx != -1:
			kind_base = header_s.substr(0, open_idx).strip_edges()
			skill_id = header_s.substr(open_idx + 1, close_idx - open_idx - 1).strip_edges().to_lower()

	return {
		"kind": kind_base,
		"skill": skill_id,
		"detail": detail_s,
		"text": s,
	}


func _tile_has_resource_for_skill(mods: Array, skill_id: String) -> bool:
	var s: String = skill_id.to_lower()

	for m_v: Variant in mods:
		var info: Dictionary = _mod_get_kind_skill_detail(m_v)
		if String(info.get("kind", "")) != "Resource Spawn":
			continue
		if String(info.get("skill", "")).to_lower() != s:
			continue

		var detail: String = String(info.get("detail", "")).strip_edges()
		var text: String = String(info.get("text", "")).strip_edges()
		if detail != "" or text != "":
			return true

	return false


# -------------------------------------------------------------------
# TaskPicker: jobs available for tile
# -------------------------------------------------------------------

func get_jobs_for_tile(_v_idx: int, ax: Vector2i) -> Array:
	var specs: Array = []

	var world: Node = get_tree().get_first_node_in_group("World")
	var has_frag: bool = false
	var adjacent: bool = false
	var mods: Array = []

	if world != null:
		if world.has_method("_has_fragment_at"):
			has_frag = bool(world.call("_has_fragment_at", ax))
		if world.has_method("_is_adjacent_to_any"):
			adjacent = bool(world.call("_is_adjacent_to_any", ax))
		mods = _tile_modifiers(world, ax)

	if has_frag:
		specs.append({ "label": "Scrying",      "job": JOB_SCRYING,      "id": 1,  "disabled": false, "reason": "" })
		specs.append({ "label": "Astromancy",   "job": JOB_ASTROMANCY,   "id": 2,  "disabled": false, "reason": "" })
		specs.append({ "label": "Smithing",     "job": JOB_SMITHING,     "id": 3,  "disabled": false, "reason": "" })
		specs.append({ "label": "Construction", "job": JOB_CONSTRUCTION, "id": 4,  "disabled": false, "reason": "" })

		if _tile_has_resource_for_skill(mods, "mining"):
			specs.append({ "label": "Mining", "job": JOB_MINING, "id": 10, "disabled": false, "reason": "" })

		var has_wood: bool = _tile_has_resource_for_skill(mods, "woodcutting")
		if not has_wood and typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("has_any"):
			has_wood = bool(ResourceNodes.has_any(ax, "woodcutting"))
		if has_wood:
			specs.append({ "label": "Woodcutting", "job": JOB_WOODCUTTING, "id": 11, "disabled": false, "reason": "" })

		var has_fish: bool = _tile_has_resource_for_skill(mods, "fishing")
		if not has_fish and typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("has_any"):
			has_fish = bool(ResourceNodes.has_any(ax, "fishing"))
		if has_fish:
			specs.append({ "label": "Fishing", "job": JOB_FISHING, "id": 12, "disabled": false, "reason": "" })

		var has_herb: bool = _tile_has_resource_for_skill(mods, "herbalism")
		if not has_herb and typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("has_any"):
			has_herb = bool(ResourceNodes.has_any(ax, "herbalism"))
		if has_herb:
			specs.append({ "label": "Herbalism", "job": JOB_HERBALISM, "id": 13, "disabled": false, "reason": "" })

	elif adjacent and not has_frag:
		specs.append({
			"label": "Astromancy — Summon Fragment",
			"job": JOB_ASTROMANCY,
			"id": 100,
			"disabled": false,
			"reason": "",
		})
	else:
		specs.append({
			"label": "No valid tasks here",
			"job": JOB_NONE,
			"id": 999,
			"disabled": true,
			"reason": "Must be on a fragment or empty hex adjacent to one.",
		})

	return specs


# -------------------------------------------------------------------
# Recipes per job
# -------------------------------------------------------------------

func get_recipes_for_job(v_idx: int, job: StringName, ax: Vector2i) -> Array:
	var recipes: Array = []
	var world: Node = get_tree().get_first_node_in_group("World")

	# --- ASTROMANCY ---
	if job == JOB_ASTROMANCY:
		var has_frag: bool = false
		var adjacent: bool = false

		if world != null:
			if world.has_method("_has_fragment_at"):
				has_frag = bool(world.call("_has_fragment_at", ax))
			if world.has_method("_is_adjacent_to_any"):
				adjacent = bool(world.call("_is_adjacent_to_any", ax))

		var astro_lv: int = _get_villager_skill_level(v_idx, "astromancy")

		var max_rank: int = 10
		if typeof(AstromancySystem) != TYPE_NIL and AstromancySystem.has_method("get_max_rank_for_level"):
			max_rank = int(AstromancySystem.get_max_rank_for_level(astro_lv))
		max_rank = clampi(max_rank, 1, 10)

		if has_frag:
			for rank: int in range(1, max_rank + 1):
				if typeof(AstromancySystem) == TYPE_NIL:
					break

				var cost_v: Variant = AstromancySystem.get_cost_for_rank(rank)
				if not (cost_v is Dictionary):
					continue

				var cost: Dictionary = cost_v as Dictionary
				if cost.is_empty():
					continue

				var grade: int = int(cost.get("grade", rank))
				var qty: int = int(cost.get("qty", 0))

				var shard_id: StringName = StringName(AstromancySystem.SHARD_IDS.get(rank, Items.R1_PLAIN))
				var augury_id: StringName = StringName(AstromancySystem.AUGURY_IDS.get(grade, Items.AUGURY_A1))

				var label: String = "Plain Shard (R%d)" % rank
				var aug_name: String = "Augury G%d" % grade

				if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name"):
					if Items.is_valid(shard_id):
						label = String(Items.display_name(shard_id))
					if Items.is_valid(augury_id):
						aug_name = String(Items.display_name(augury_id))

				var desc: String = "Forge %s by spending %d× %s." % [label, qty, aug_name]

				var icon_tex: Texture2D = null
				if typeof(Items) != TYPE_NIL and Items.has_method("get_icon"):
					var icon_v: Variant = Items.get_icon(shard_id)
					if icon_v is Texture2D:
						icon_tex = icon_v as Texture2D

				var level_req: int = 1
				if typeof(AstromancySystem) != TYPE_NIL:
					level_req = int(AstromancySystem.RANK_GATE_LEVEL.get(rank, 1))

				recipes.append({
					"id": shard_id,
					"label": label,
					"skill": &"astromancy",
					"icon": icon_tex,
					"level_req": level_req,
					"xp": int(AstromancySystem.FORGE_XP_PER_RANK) * rank,
					"inputs": [{ "item": augury_id, "qty": qty }],
					"output": { "item": shard_id, "qty": 1 },
					"desc": desc,
				})

			if typeof(AstromancySystem) != TYPE_NIL:
				recipes.append({
					"id": AstromancySystem.ACTION_COLLAPSE_FRAGMENT,
					"label": "Collapse Fragment",
					"skill": &"astromancy",
					"icon": null,
					"level_req": 1,
					"xp": 0,
					"inputs": [],
					"output": {},
					"desc": "Collapse this fragment, refunding some Augury and freeing the tile.",
				})

			return _normalize_recipe_list(job, recipes)

		if adjacent and not has_frag:
			if typeof(Bank) == TYPE_NIL or not Bank.has_method("amount"):
				return _normalize_recipe_list(job, recipes)

			for rank2: int in range(1, max_rank + 1):
				if typeof(AstromancySystem) == TYPE_NIL:
					break
				if not AstromancySystem.SHARD_IDS.has(rank2):
					continue

				var shard_id2: StringName = StringName(AstromancySystem.SHARD_IDS[rank2])
				var have: int = int(Bank.amount(shard_id2))
				if have <= 0:
					continue

				var label2: String = "Plain Shard (R%d)" % rank2
				if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name"):
					if Items.is_valid(shard_id2):
						label2 = String(Items.display_name(shard_id2))

				var level_req2: int = 1
				if typeof(AstromancySystem) != TYPE_NIL:
					level_req2 = int(AstromancySystem.RANK_GATE_LEVEL.get(rank2, 1))

				var desc2: String = "Spend 1× %s to summon a new fragment here." % label2

				var icon_tex2: Texture2D = null
				if typeof(Items) != TYPE_NIL and Items.has_method("get_icon"):
					var icon_v2: Variant = Items.get_icon(shard_id2)
					if icon_v2 is Texture2D:
						icon_tex2 = icon_v2 as Texture2D

				recipes.append({
					"id": shard_id2,
					"label": label2,
					"skill": &"astromancy",
					"icon": icon_tex2,
					"level_req": level_req2,
					"xp": int(AstromancySystem.FORGE_XP_PER_RANK) * rank2,
					"inputs": [{ "item": shard_id2, "qty": 1 }],
					"output": { "item": shard_id2, "qty": 0 },
					"desc": desc2,
				})

			return _normalize_recipe_list(job, recipes)

		return _normalize_recipe_list(job, recipes)

	# --- SMITHING ---
	if job == JOB_SMITHING:
		var smith_lv: int = _get_villager_skill_level(v_idx, "smithing")

		if typeof(SmithingSystem) == TYPE_NIL or not SmithingSystem.has_method("get_recipes_for_level"):
			return _normalize_recipe_list(job, recipes)

		var smith_recipes_v: Variant = SmithingSystem.get_recipes_for_level(smith_lv)
		if smith_recipes_v is Array:
			return _normalize_recipe_list(job, smith_recipes_v as Array)

		return _normalize_recipe_list(job, recipes)

	# --- CONSTRUCTION ---
	if job == JOB_CONSTRUCTION:
		var con_lv: int = _get_villager_skill_level(v_idx, "construction")

		if typeof(ConstructionSystem) == TYPE_NIL:
			return _normalize_recipe_list(job, recipes)

		if ConstructionSystem.has_method("get_recipes_for_level_and_kind"):
			var all_mat_v: Variant = ConstructionSystem.get_recipes_for_level_and_kind(con_lv, "material")
			if not (all_mat_v is Array):
				return _normalize_recipe_list(job, recipes)

			var all_mat: Array = all_mat_v as Array
			var out: Array = []

			for rec_v: Variant in all_mat:
				if not (rec_v is Dictionary):
					continue

				var rec: Dictionary = rec_v as Dictionary
				var part_str: String = String(rec.get("part", "")).strip_edges()
				if part_str == "":
					continue

				out.append(rec)

			return _normalize_recipe_list(job, out)

		if ConstructionSystem.has_method("get_recipes_for_level"):
			var con_recipes_v: Variant = ConstructionSystem.get_recipes_for_level(con_lv)
			if con_recipes_v is Array:
				return _normalize_recipe_list(job, con_recipes_v as Array)

		return _normalize_recipe_list(job, recipes)

	# --- WOODCUTTING ---
	if job == JOB_WOODCUTTING:
		if world == null:
			return _normalize_recipe_list(JOB_WOODCUTTING, recipes)
		return _build_woodcutting_recipes_for_tile(v_idx, ax, world)

	# --- MINING ---
	if job == JOB_MINING:
		if world == null:
			return _normalize_recipe_list(JOB_MINING, recipes)
		return _build_mining_recipes_for_tile(v_idx, ax, world)

	# --- FISHING ---
	if job == JOB_FISHING:
		if world == null:
			return _normalize_recipe_list(JOB_FISHING, recipes)
		return _build_fishing_recipes_for_tile(v_idx, ax, world)

	# --- HERBALISM ---
	if job == JOB_HERBALISM:
		if world == null:
			return _normalize_recipe_list(JOB_HERBALISM, recipes)
		return _build_herbalism_recipes_for_tile(v_idx, ax, world)

	return _normalize_recipe_list(job, recipes)


# -------------------------------------------------------------------
# Duration per job
# -------------------------------------------------------------------

func _job_duration(job: StringName, recipe_id: StringName = StringName()) -> float:
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
			return 2.4

		JOB_FISHING:
			if typeof(FishingSystem) != TYPE_NIL:
				return float(FishingSystem.BASE_ACTION_TIME)
			return 2.4

		JOB_HERBALISM:
			var hs: Node = _get_herbalism()
			var base: float = 2.4
			if hs != null:
				var bat: Variant = hs.get("BASE_ACTION_TIME")
				if typeof(bat) == TYPE_FLOAT or typeof(bat) == TYPE_INT:
					base = float(bat)

			var s: String = String(recipe_id)
			var actions: int = 2
			if s.ends_with("_quick"):
				actions = 1

			return base * float(actions)

		JOB_SMITHING:
			if typeof(SmithingSystem) != TYPE_NIL:
				return float(SmithingSystem.BASE_ACTION_TIME)
			return 4.8

		JOB_CONSTRUCTION:
			if typeof(ConstructionSystem) != TYPE_NIL:
				return float(ConstructionSystem.BASE_ACTION_TIME)
			return 4.8

		_:
			return 2.4


# -------------------------------------------------------------------
# Resolve completion
# -------------------------------------------------------------------

func _complete_job(v_idx: int) -> void:
	if not _jobs.has(v_idx):
		return

	var state_v: Variant = _jobs[v_idx]
	if not (state_v is Dictionary):
		_jobs.erase(v_idx)
		return

	var state: Dictionary = state_v as Dictionary
	var job: StringName = StringName(state.get("job", JOB_NONE))
	var recipe: StringName = StringName(state.get("recipe", StringName()))

	var ax: Vector2i = Vector2i.ZERO
	if state.has("ax") and state["ax"] is Vector2i:
		ax = state["ax"] as Vector2i

	# Re-check before completion in case the job came from an old save,
	# a direct code path, or the villager/state changed while working.
	if recipe != StringName(""):
		var selected_recipe: Dictionary = _find_recipe_for_job(v_idx, job, ax, recipe)
		if selected_recipe.is_empty() or not _can_villager_use_recipe(v_idx, job, selected_recipe):
			_abort_job(v_idx)
			return

	var remaining: int = int(state.get("remaining", 1))
	var repeat: bool = bool(state.get("repeat", false))

	var result: Dictionary = {}

	if job == JOB_SCRYING:
		if typeof(ScryingSystem) != TYPE_NIL and ScryingSystem.has_method("do_scry"):
			var r: Variant = ScryingSystem.do_scry(v_idx)
			if r is Dictionary:
				result = r as Dictionary

	elif job == JOB_ASTROMANCY:
		if typeof(AstromancySystem) != TYPE_NIL and AstromancySystem.has_method("do_astromancy_work"):
			var r2: Variant = AstromancySystem.do_astromancy_work(recipe, ax)
			if r2 is Dictionary:
				result = r2 as Dictionary

	elif job == JOB_SMITHING:
		if typeof(SmithingSystem) != TYPE_NIL and SmithingSystem.has_method("do_smithing_work"):
			var r3: Variant = SmithingSystem.do_smithing_work(recipe)
			if r3 is Dictionary:
				result = r3 as Dictionary

	elif job == JOB_CONSTRUCTION:
		if typeof(ConstructionSystem) != TYPE_NIL and ConstructionSystem.has_method("do_construction_work"):
			var r4: Variant = ConstructionSystem.do_construction_work(recipe)
			if r4 is Dictionary:
				result = r4 as Dictionary

	elif job == JOB_MINING:
		if typeof(MiningSystem) != TYPE_NIL and MiningSystem.has_method("do_mine"):
			var r5: Variant = MiningSystem.do_mine(recipe, ax)
			if r5 is Dictionary:
				result = r5 as Dictionary

	elif job == JOB_WOODCUTTING:
		if typeof(WoodcuttingSystem) != TYPE_NIL and WoodcuttingSystem.has_method("do_chop"):
			var node_detail: String = String(state.get("node_detail", ""))
			var r6: Variant = WoodcuttingSystem.do_chop(v_idx, recipe, ax, node_detail)
			if r6 is Dictionary:
				result = r6 as Dictionary

	elif job == JOB_FISHING:
		if typeof(FishingSystem) != TYPE_NIL and FishingSystem.has_method("do_fish"):
			var fish_lv: int = _get_villager_skill_level(v_idx, "fishing")
			var r7: Variant = FishingSystem.do_fish(recipe, fish_lv)
			if r7 is Dictionary:
				result = r7 as Dictionary

	elif job == JOB_HERBALISM:
		var hs2: Node = _get_herbalism()
		if hs2 != null and hs2.has_method("do_forage"):
			var s2: String = String(recipe)
			var quick: bool = s2.ends_with("_quick")
			var patch_str: String = s2.replace("_careful", "").replace("_quick", "")
			var patch_id: StringName = StringName(patch_str)

			var r8: Variant = hs2.call("do_forage", patch_id, ax, quick)
			if r8 is Dictionary:
				result = r8 as Dictionary

	var xp: int = int(result.get("xp", 0))
	var loot_desc: String = String(result.get("loot_desc", ""))

	var is_empty: bool = bool(result.get("empty", false))
	var cooldown: float = float(result.get("cooldown", 0.0))

	# Canonical XP attribution:
	# job completion XP always goes to the acting villager's matching skill.
	_award_job_xp(v_idx, job, xp)

	job_completed.emit(v_idx, job, xp, loot_desc)

	# ------------------------------------------------------------
	# Continue logic: repeat OR multi-craft
	# ------------------------------------------------------------
	var will_continue: bool = false

	# Repeat logic for gathering / repeatable jobs.
	if repeat and job != JOB_ASTROMANCY:
		if job == JOB_MINING:
			var next_duration: float = _job_duration(job, recipe)
			if is_empty and cooldown > 0.0:
				next_duration = cooldown

			will_continue = true
			call_deferred(
				"_assign_job_with_custom_duration",
				v_idx,
				job,
				ax,
				recipe,
				1,
				true,
				next_duration,
				String(state.get("node_detail", ""))
			)

		elif job == JOB_HERBALISM:
			var next_duration_h: float = _job_duration(job, recipe)
			if is_empty and cooldown > 0.0:
				next_duration_h = cooldown

			will_continue = true
			call_deferred(
				"_assign_job_with_custom_duration",
				v_idx,
				job,
				ax,
				recipe,
				1,
				true,
				next_duration_h,
				String(state.get("node_detail", ""))
			)

		elif job == JOB_WOODCUTTING:
			will_continue = true
			call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, 1, true)

		elif job == JOB_FISHING:
			will_continue = true
			call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, 1, true)

		else:
			if xp > 0:
				will_continue = true
				call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, 1, true)

	# Multi-craft logic.
	if not will_continue:
		if job == JOB_ASTROMANCY:
			var next_remaining: int = remaining - 1
			if next_remaining > 0 and xp > 0:
				var world2: Node = get_tree().get_first_node_in_group("World")
				var is_forge: bool = false
				if world2 != null and world2.has_method("_has_fragment_at"):
					is_forge = bool(world2.call("_has_fragment_at", ax))
				if is_forge:
					will_continue = true
					call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, next_remaining)

		elif job == JOB_SMITHING:
			var next_remaining2: int = remaining - 1
			if next_remaining2 > 0 and xp > 0:
				will_continue = true
				call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, next_remaining2)

		elif job == JOB_CONSTRUCTION:
			var next_remaining3: int = remaining - 1
			if next_remaining3 > 0 and xp > 0:
				will_continue = true
				call_deferred("assign_job_with_recipe", v_idx, job, ax, recipe, next_remaining3)

	# Clear current job state.
	_jobs.erase(v_idx)

	# Only clear villager->tile assignment if we are actually stopping.
	if not will_continue:
		var world3: Node = get_tree().get_first_node_in_group("World")
		if world3 != null and world3.has_method("clear_villager_from_tile"):
			world3.call("clear_villager_from_tile", v_idx)
		job_changed.emit(v_idx, JOB_NONE)


# -------------------------------------------------------------------
# Save / Load
# -------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	var jobs_save: Dictionary = {}

	for k_v: Variant in _jobs.keys():
		var v_idx: int = int(k_v)
		var st_v: Variant = _jobs[k_v]
		if not (st_v is Dictionary):
			continue

		var st: Dictionary = st_v as Dictionary

		var ax: Vector2i = Vector2i.ZERO
		if st.has("ax") and st["ax"] is Vector2i:
			ax = st["ax"] as Vector2i

		jobs_save[v_idx] = {
			"job":         StringName(st.get("job", JOB_NONE)),
			"recipe":      StringName(st.get("recipe", StringName())),
			"ax":          ax,
			"elapsed":     float(st.get("elapsed", 0.0)),
			"duration":    float(st.get("duration", 0.0)),
			"remaining":   int(st.get("remaining", 1)),
			"repeat":      bool(st.get("repeat", false)),
			"node_detail": String(st.get("node_detail", "")),
		}

	return { "jobs": jobs_save }


func from_save_dict(d: Dictionary) -> void:
	_jobs.clear()

	var jobs_v: Variant = d.get("jobs", {})
	if not (jobs_v is Dictionary):
		return

	var jobs_d: Dictionary = jobs_v as Dictionary

	for k_v: Variant in jobs_d.keys():
		var v_idx: int = int(k_v)
		var st_v: Variant = jobs_d[k_v]
		if not (st_v is Dictionary):
			continue

		var st: Dictionary = st_v as Dictionary

		var ax: Vector2i = Vector2i.ZERO
		if st.has("ax") and st["ax"] is Vector2i:
			ax = st["ax"] as Vector2i

		_jobs[v_idx] = {
			"job":         StringName(st.get("job", JOB_NONE)),
			"recipe":      StringName(st.get("recipe", StringName())),
			"ax":          ax,
			"elapsed":     float(st.get("elapsed", 0.0)),
			"duration":    float(st.get("duration", 0.0)),
			"remaining":   int(st.get("remaining", 1)),
			"repeat":      bool(st.get("repeat", false)),
			"node_detail": String(st.get("node_detail", "")),
		}

	for k2_v: Variant in _jobs.keys():
		var v2: int = int(k2_v)
		var st2_v: Variant = _jobs[v2]
		if not (st2_v is Dictionary):
			continue

		var st2: Dictionary = st2_v as Dictionary
		var job2: StringName = StringName(st2.get("job", JOB_NONE))
		var elapsed2: float = float(st2.get("elapsed", 0.0))
		var duration2: float = float(st2.get("duration", 0.0))

		job_changed.emit(v2, job2)
		job_progress.emit(v2, job2, elapsed2, duration2)


func reset_runtime_state() -> void:
	_jobs.clear()


# -------------------------------------------------------------------
# Helpers: build recipes for node-driven gathering jobs
# -------------------------------------------------------------------
func _build_mining_recipes_for_tile(v_idx: int, ax: Vector2i, world: Node) -> Array:
	var recipes: Array = []
	var mining_lv: int = _get_villager_skill_level(v_idx, "mining")

	# ------------------------------------------------------------
	# 1) Preferred: ResourceNodes-backed mining nodes
	# ------------------------------------------------------------
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("get_nodes"):
		var mining_nodes_v: Variant = ResourceNodes.get_nodes(ax, "mining")
		if mining_nodes_v is Array:
			var mining_nodes: Array = mining_nodes_v as Array

			for n_v: Variant in mining_nodes:
				if not (n_v is Dictionary):
					continue

				var n: Dictionary = n_v as Dictionary

				var node_id: StringName = StringName(n.get("node_id", StringName("")))
				if node_id == StringName(""):
					continue

				if typeof(MiningSystem) == TYPE_NIL or not MiningSystem.has_method("get_node_def"):
					continue

				var def_v: Variant = MiningSystem.get_node_def(node_id)
				if not (def_v is Dictionary):
					continue

				var def: Dictionary = def_v as Dictionary
				if def.is_empty():
					continue

				var req: int = int(def.get("req", 1))
				if mining_lv < req:
					continue

				var xp: int = int(def.get("xp", 1))
				var item_id: StringName = StringName(def.get("item_id", StringName("")))

				var icon_tex: Texture2D = null
				if typeof(Items) != TYPE_NIL and Items.has_method("get_icon") and item_id != StringName(""):
					icon_tex = Items.get_icon(item_id)

				var item_name: String = ""
				if typeof(Items) != TYPE_NIL \
				and Items.has_method("is_valid") \
				and Items.has_method("display_name") \
				and item_id != StringName("") \
				and Items.is_valid(item_id):
					item_name = Items.display_name(item_id)

				var drop_preview: Array = []
				if typeof(MiningSystem) != TYPE_NIL and MiningSystem.has_method("get_drop_preview_for_node"):
					var pv: Variant = MiningSystem.get_drop_preview_for_node(node_id)
					if pv is Array:
						drop_preview = pv as Array

				var deposit_name: String = String(n.get("detail", n.get("name", ""))).strip_edges()
				if deposit_name == "":
					deposit_name = String(def.get("display_name", String(node_id))).strip_edges()
				if deposit_name == "":
					deposit_name = String(node_id)

				recipes.append({
					"id": node_id,
					"label": "Mine %s" % deposit_name,
					"skill": &"mining",
					"level_req": req,
					"xp": xp,
					"duration": _job_duration(JOB_MINING, node_id),
					"inputs": [],
					"outputs": [],
					"desc": "Mine this %s deposit." % deposit_name,
					"icon": icon_tex,
					"drop_preview": drop_preview,
					"primary_item": item_id,
					"primary_item_name": item_name,
				})

			if recipes.size() > 0:
				return _normalize_recipe_list(JOB_MINING, recipes)

	# ------------------------------------------------------------
	# 2) Fallback: parse modifiers directly
	# ------------------------------------------------------------
	var mods: Array = _tile_modifiers(world, ax)
	if mods.is_empty():
		return _normalize_recipe_list(JOB_MINING, recipes)

	for m_v: Variant in mods:
		var info: Dictionary = _mod_get_kind_skill_detail(m_v)
		if String(info.get("kind", "")) != "Resource Spawn":
			continue
		if String(info.get("skill", "")).to_lower() != "mining":
			continue

		var detail: String = String(info.get("detail", "")).strip_edges()
		var probe: String = detail if detail != "" else String(info.get("text", "")).strip_edges()

		var node_id: StringName = _infer_mining_node_id_from_text(probe)
		if node_id == StringName(""):
			continue

		if typeof(MiningSystem) == TYPE_NIL or not MiningSystem.has_method("get_node_def"):
			continue

		var def_v: Variant = MiningSystem.get_node_def(node_id)
		if not (def_v is Dictionary):
			continue

		var def: Dictionary = def_v as Dictionary
		if def.is_empty():
			continue

		var req: int = int(def.get("req", 1))
		if mining_lv < req:
			continue

		var xp: int = int(def.get("xp", 1))
		var item_id: StringName = StringName(def.get("item_id", StringName("")))

		var icon_tex: Texture2D = null
		if typeof(Items) != TYPE_NIL and Items.has_method("get_icon") and item_id != StringName(""):
			icon_tex = Items.get_icon(item_id)

		var item_name: String = ""
		if typeof(Items) != TYPE_NIL \
		and Items.has_method("is_valid") \
		and Items.has_method("display_name") \
		and item_id != StringName("") \
		and Items.is_valid(item_id):
			item_name = Items.display_name(item_id)

		var drop_preview: Array = []
		if typeof(MiningSystem) != TYPE_NIL and MiningSystem.has_method("get_drop_preview_for_node"):
			var pv: Variant = MiningSystem.get_drop_preview_for_node(node_id)
			if pv is Array:
				drop_preview = pv as Array

		var deposit_name: String = detail if detail != "" else probe
		if deposit_name == "":
			deposit_name = String(def.get("display_name", String(node_id))).strip_edges()
		if deposit_name == "":
			deposit_name = String(node_id)

		recipes.append({
			"id": node_id,
			"label": "Mine %s" % deposit_name,
			"skill": &"mining",
			"level_req": req,
			"xp": xp,
			"duration": _job_duration(JOB_MINING, node_id),
			"inputs": [],
			"outputs": [],
			"desc": "Mine this %s deposit." % deposit_name,
			"icon": icon_tex,
			"drop_preview": drop_preview,
			"primary_item": item_id,
			"primary_item_name": item_name,
		})

	return _normalize_recipe_list(JOB_MINING, recipes)


func _build_woodcutting_recipes_for_tile(v_idx: int, ax: Vector2i, world: Node) -> Array:
	var recipes: Array = []
	var wc_lv: int = _get_villager_skill_level(v_idx, "woodcutting")

	# ------------------------------------------------------------
	# 1) Preferred: ResourceNodes-backed woodcutting nodes
	# ------------------------------------------------------------
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("get_nodes"):
		var nodes_v: Variant = ResourceNodes.get_nodes(ax, "woodcutting")

		if nodes_v is Array:
			var nodes: Array = nodes_v as Array

			for n_v: Variant in nodes:
				if not (n_v is Dictionary):
					continue

				var n: Dictionary = n_v as Dictionary
				var target_id: StringName = StringName(n.get("target_id", n.get("node_id", StringName(""))))
				if target_id == StringName(""):
					continue

				if typeof(WoodcuttingSystem) == TYPE_NIL or not WoodcuttingSystem.has_method("get_target_def"):
					continue

				var def_v: Variant = WoodcuttingSystem.get_target_def(target_id)
				if not (def_v is Dictionary):
					continue

				var def: Dictionary = def_v as Dictionary
				if def.is_empty():
					continue

				var req: int = int(def.get("lvl_req", 1))
				if wc_lv < req:
					continue

				var xp: int = int(def.get("xp", 1))

				var detail: String = String(n.get("detail", n.get("name", ""))).strip_edges()
				if detail == "":
					detail = String(target_id)

				var icon_tex: Texture2D = null
				var log_item: StringName = StringName("")
				var log_name: String = ""

				if typeof(Items) != TYPE_NIL:
					var drops_any: Variant = def.get("drops", [])

					if drops_any is Array:
						var drops: Array = drops_any as Array
						if drops.size() > 0 and drops[0] is Dictionary:
							log_item = StringName((drops[0] as Dictionary).get("item", StringName("")))

					if log_item != StringName(""):
						if Items.has_method("get_icon"):
							var icon_v: Variant = Items.get_icon(log_item)
							if icon_v is Texture2D:
								icon_tex = icon_v as Texture2D
						if Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(log_item):
							log_name = String(Items.display_name(log_item))

				var node_detail: String = detail

				var drop_preview: Array = []
				if typeof(WoodcuttingSystem) != TYPE_NIL and WoodcuttingSystem.has_method("get_drop_preview_for_target"):
					var pv: Variant = WoodcuttingSystem.get_drop_preview_for_target(target_id, ax, node_detail, wc_lv)
					if pv is Array:
						drop_preview = pv as Array

				var label: String = "Chop %s" % detail
				if log_name != "":
					label = "Chop %s (%s)" % [detail, log_name]

				var desc: String = "Chop this %s." % detail
				if log_name != "":
					desc = "Chop this %s for %s." % [detail, log_name]

				recipes.append({
					"id": target_id,
					"label": label,
					"skill": &"woodcutting",
					"icon": icon_tex,
					"level_req": req,
					"xp": xp,
					"inputs": [],
					"output": {},
					"desc": desc,
					"primary_item": log_item,
					"primary_item_name": log_name,
					"drop_preview": drop_preview,
					"node_detail": node_detail,
				})

			if recipes.size() > 0:
				return _normalize_recipe_list(JOB_WOODCUTTING, recipes)

	# ------------------------------------------------------------
	# 2) Fallback: parse modifiers
	# ------------------------------------------------------------
	var mods: Array = _tile_modifiers(world, ax)
	if mods.is_empty():
		return _normalize_recipe_list(JOB_WOODCUTTING, recipes)

	for m_v: Variant in mods:
		var info: Dictionary = _mod_get_kind_skill_detail(m_v)

		if String(info.get("kind", "")) != "Resource Spawn":
			continue
		if String(info.get("skill", "")).to_lower() != "woodcutting":
			continue

		var detail2: String = String(info.get("detail", ""))
		var probe2: String = detail2 if detail2 != "" else String(info.get("text", ""))

		var target_id2: StringName = _infer_woodcut_target_id_from_text(probe2)
		if target_id2 == StringName(""):
			continue

		if typeof(WoodcuttingSystem) == TYPE_NIL or not WoodcuttingSystem.has_method("get_target_def"):
			continue

		var def_v2: Variant = WoodcuttingSystem.get_target_def(target_id2)
		if not (def_v2 is Dictionary):
			continue

		var def2: Dictionary = def_v2 as Dictionary
		if def2.is_empty():
			continue

		var req2: int = int(def2.get("lvl_req", 1))
		if wc_lv < req2:
			continue

		var xp2: int = int(def2.get("xp", 1))

		var icon_tex2: Texture2D = null
		var log_item2: StringName = StringName("")
		var log_name2: String = ""

		if typeof(Items) != TYPE_NIL:
			var drops_any2: Variant = def2.get("drops", [])

			if drops_any2 is Array:
				var drops2: Array = drops_any2 as Array
				if drops2.size() > 0 and drops2[0] is Dictionary:
					log_item2 = StringName((drops2[0] as Dictionary).get("item", StringName("")))

			if log_item2 != StringName(""):
				if Items.has_method("get_icon"):
					var icon_v2: Variant = Items.get_icon(log_item2)
					if icon_v2 is Texture2D:
						icon_tex2 = icon_v2 as Texture2D
				if Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(log_item2):
					log_name2 = String(Items.display_name(log_item2))

		var deposit_name: String = detail2 if detail2 != "" else probe2
		var node_detail2: String = deposit_name

		var drop_preview2: Array = []
		if typeof(WoodcuttingSystem) != TYPE_NIL and WoodcuttingSystem.has_method("get_drop_preview_for_target"):
			var pv2: Variant = WoodcuttingSystem.get_drop_preview_for_target(target_id2, ax, node_detail2, wc_lv)
			if pv2 is Array:
				drop_preview2 = pv2 as Array

		var label2: String = "Chop %s" % deposit_name
		if log_name2 != "":
			label2 = "Chop %s (%s)" % [deposit_name, log_name2]

		var desc2: String = "Chop this %s." % deposit_name
		if log_name2 != "":
			desc2 = "Chop this %s for %s." % [deposit_name, log_name2]

		recipes.append({
			"id": target_id2,
			"label": label2,
			"skill": &"woodcutting",
			"icon": icon_tex2,
			"level_req": req2,
			"xp": xp2,
			"inputs": [],
			"output": {},
			"desc": desc2,
			"primary_item": log_item2,
			"primary_item_name": log_name2,
			"drop_preview": drop_preview2,
			"node_detail": node_detail2,
		})

	return _normalize_recipe_list(JOB_WOODCUTTING, recipes)


func _build_fishing_recipes_for_tile(v_idx: int, ax: Vector2i, world: Node) -> Array:
	var recipes: Array = []

	# ------------------------------------------------------------
	# 1) Preferred: ResourceNodes-backed fishing nodes
	# ------------------------------------------------------------
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("get_nodes"):
		var fish_nodes_v: Variant = ResourceNodes.get_nodes(ax, "fishing")
		if fish_nodes_v is Array:
			var fish_nodes: Array = fish_nodes_v as Array
			if fish_nodes.size() > 0:
				return _build_fishing_recipes_from_nodes(v_idx, fish_nodes)

	# ------------------------------------------------------------
	# 2) Fallback: parse modifiers to find fishing nodes
	# ------------------------------------------------------------
	var mods: Array = _tile_modifiers(world, ax)
	if mods.is_empty():
		return _normalize_recipe_list(JOB_FISHING, recipes)

	var fish_lv: int = _get_villager_skill_level(v_idx, "fishing")

	for m_v: Variant in mods:
		var info: Dictionary = _mod_get_kind_skill_detail(m_v)

		if String(info.get("kind", "")) != "Resource Spawn":
			continue
		if String(info.get("skill", "")).to_lower() != "fishing":
			continue

		var detail: String = String(info.get("detail", "")).strip_edges()
		var probe: String = detail if detail != "" else String(info.get("text", ""))

		var node_id: StringName = _infer_fishing_node_id_from_text(probe)
		if node_id == StringName(""):
			continue

		if typeof(FishingSystem) == TYPE_NIL or not FishingSystem.has_method("get_node_def"):
			continue

		var def_v: Variant = FishingSystem.get_node_def(node_id)
		if not (def_v is Dictionary):
			continue

		var def: Dictionary = def_v as Dictionary
		if def.is_empty():
			continue

		var req: int = int(def.get("req_level", 1))
		if fish_lv < req:
			continue

		var display_name: String = String(def.get("display_name", "Fishing Spot"))
		var max_grade: int = int(def.get("max_grade", 1))

		var grade: int = int(ceil(fish_lv / 10.0))
		grade = clampi(grade, 1, max_grade)

		var xp: int = 0
		var xpg_v: Variant = FishingSystem.get("XP_BY_GRADE")
		if xpg_v is Dictionary:
			xp = int((xpg_v as Dictionary).get(grade, 0))

		var icon_tex: Texture2D = null
		var fish_item: StringName = StringName("")
		var fish_name: String = ""

		var species_by_grade: Dictionary = {}
		var sbg_v: Variant = def.get("species_by_grade", {})
		if sbg_v is Dictionary:
			species_by_grade = sbg_v as Dictionary

		if typeof(Items) != TYPE_NIL:
			var g: int = grade
			while g > 0 and not species_by_grade.has(g):
				g -= 1

			if g > 0:
				var entries_v: Variant = species_by_grade.get(g, [])
				if entries_v is Array:
					var entries: Array = entries_v as Array
					if entries.size() > 0 and entries[0] is Dictionary:
						fish_item = StringName((entries[0] as Dictionary).get("fish", StringName("")))

			if fish_item != StringName(""):
				if Items.has_method("get_icon"):
					var icon_v: Variant = Items.get_icon(fish_item)
					if icon_v is Texture2D:
						icon_tex = icon_v as Texture2D
				if Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(fish_item):
					fish_name = String(Items.display_name(fish_item))

		var detail_label: String = detail if detail != "" else display_name
		var label: String = "Fish %s" % detail_label
		if fish_name != "":
			label = "Fish %s (%s)" % [detail_label, fish_name]

		var desc: String = "Fish at %s." % detail_label
		if fish_name != "":
			desc = "Fish at %s for %s." % [detail_label, fish_name]

		var drop_preview: Array = []
		if typeof(FishingSystem) != TYPE_NIL and FishingSystem.has_method("get_drop_preview_for_node"):
			var pv: Variant = FishingSystem.get_drop_preview_for_node(node_id, fish_lv)
			if pv is Array:
				drop_preview = pv as Array

		recipes.append({
			"id": node_id,
			"label": label,
			"skill": &"fishing",
			"icon": icon_tex,
			"level_req": req,
			"xp": xp,
			"inputs": [],
			"output": {},
			"desc": desc,
			"primary_item": fish_item,
			"primary_item_name": fish_name,
			"drop_preview": drop_preview,
		})

	return _normalize_recipe_list(JOB_FISHING, recipes)


func _build_fishing_recipes_from_nodes(v_idx: int, fish_nodes: Array) -> Array:
	var recipes: Array = []
	var fish_lv: int = _get_villager_skill_level(v_idx, "fishing")

	for n_v: Variant in fish_nodes:
		if not (n_v is Dictionary):
			continue

		var n: Dictionary = n_v as Dictionary

		var node_id: StringName = StringName(n.get("node_id", StringName("")))
		if node_id == StringName(""):
			continue

		if typeof(FishingSystem) == TYPE_NIL or not FishingSystem.has_method("get_node_def"):
			continue

		var def_v: Variant = FishingSystem.get_node_def(node_id)
		if not (def_v is Dictionary):
			continue

		var def: Dictionary = def_v as Dictionary
		if def.is_empty():
			continue

		var req: int = int(def.get("req_level", 1))
		if fish_lv < req:
			continue

		var display_name: String = String(def.get("display_name", "Fishing Spot"))
		var max_grade: int = int(def.get("max_grade", 1))

		var species_by_grade: Dictionary = {}
		var sbg_v: Variant = def.get("species_by_grade", {})
		if sbg_v is Dictionary:
			species_by_grade = sbg_v as Dictionary

		var grade: int = int(ceil(fish_lv / 10.0))
		grade = clampi(grade, 1, max_grade)

		var xp: int = 0
		var xpg_v: Variant = FishingSystem.get("XP_BY_GRADE")
		if xpg_v is Dictionary:
			xp = int((xpg_v as Dictionary).get(grade, 0))

		var icon_tex: Texture2D = null
		var fish_item: StringName = StringName("")
		var fish_name: String = ""

		if typeof(Items) != TYPE_NIL:
			var g: int = grade
			while g > 0 and not species_by_grade.has(g):
				g -= 1

			if g > 0:
				var entries_v: Variant = species_by_grade.get(g, [])
				if entries_v is Array:
					var entries: Array = entries_v as Array
					if entries.size() > 0 and entries[0] is Dictionary:
						fish_item = StringName((entries[0] as Dictionary).get("fish", StringName("")))

			if fish_item != StringName(""):
				if Items.has_method("get_icon"):
					var icon_v: Variant = Items.get_icon(fish_item)
					if icon_v is Texture2D:
						icon_tex = icon_v as Texture2D
				if Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(fish_item):
					fish_name = String(Items.display_name(fish_item))

		var detail: String = String(n.get("detail", display_name))

		var label: String = "Fish %s" % detail
		if fish_name != "":
			label = "Fish %s (%s)" % [detail, fish_name]

		var desc: String = "Fish at %s." % detail
		if fish_name != "":
			desc = "Fish at %s for %s." % [detail, fish_name]

		var drop_preview: Array = []
		if typeof(FishingSystem) != TYPE_NIL and FishingSystem.has_method("get_drop_preview_for_node"):
			var pv: Variant = FishingSystem.get_drop_preview_for_node(node_id, fish_lv)
			if pv is Array:
				drop_preview = pv as Array

		recipes.append({
			"id": node_id,
			"label": label,
			"skill": &"fishing",
			"icon": icon_tex,
			"level_req": req,
			"xp": xp,
			"inputs": [],
			"output": {},
			"desc": desc,
			"primary_item": fish_item,
			"primary_item_name": fish_name,
			"drop_preview": drop_preview,
		})

	return _normalize_recipe_list(JOB_FISHING, recipes)


func _build_herbalism_recipes_for_tile(v_idx: int, ax: Vector2i, world: Node) -> Array:
	var recipes: Array = []

	var hs: Node = _get_herbalism()
	if hs == null:
		return _normalize_recipe_list(JOB_HERBALISM, recipes)

	var herb_lv: int = _get_villager_skill_level(v_idx, "herbalism")

	# Collect patch ids: ResourceNodes preferred, else parse modifiers.
	var patch_ids: Array[StringName] = []

	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("get_nodes"):
		var herb_nodes_v: Variant = ResourceNodes.get_nodes(ax, "herbalism")
		if herb_nodes_v is Array:
			var herb_nodes: Array = herb_nodes_v as Array

			for n_v: Variant in herb_nodes:
				if not (n_v is Dictionary):
					continue

				var n: Dictionary = n_v as Dictionary
				var pid: StringName = StringName(n.get("patch_id", n.get("node_id", StringName(""))))

				if pid == StringName(""):
					var d: String = String(n.get("detail", ""))
					pid = _infer_herbal_patch_id_from_text(d)

				if pid != StringName("") and not patch_ids.has(pid):
					patch_ids.append(pid)

	if patch_ids.is_empty():
		var mods: Array = _tile_modifiers(world, ax)

		for m_v: Variant in mods:
			var info: Dictionary = _mod_get_kind_skill_detail(m_v)

			if String(info.get("kind", "")) != "Resource Spawn":
				continue
			if String(info.get("skill", "")).to_lower() != "herbalism":
				continue

			var detail: String = String(info.get("detail", "")).strip_edges()
			if detail == "":
				detail = String(info.get("text", ""))

			var pid2: StringName = _infer_herbal_patch_id_from_text(detail)
			if pid2 != StringName("") and not patch_ids.has(pid2):
				patch_ids.append(pid2)

	for patch_id: StringName in patch_ids:
		if patch_id == StringName(""):
			continue

		if hs.has_method("is_patch_unlocked"):
			var ok_v: Variant = hs.call("is_patch_unlocked", patch_id, herb_lv)
			if not bool(ok_v):
				continue

		if not hs.has_method("get_patch_def"):
			continue

		var def_v: Variant = hs.call("get_patch_def", patch_id)
		if not (def_v is Dictionary):
			continue

		var def: Dictionary = def_v as Dictionary
		if def.is_empty():
			continue

		var req: int = int(def.get("req", 1))
		if herb_lv < req:
			continue

		var xp_base: int = int(def.get("xp", 1))
		var label_base: String = String(def.get("label", "Herb Patch"))

		var is_available: bool = true
		var charges: int = 0

		if hs.has_method("get_patch_status"):
			var status_v: Variant = hs.call("get_patch_status", ax, patch_id)
			if status_v is Dictionary:
				var status: Dictionary = status_v as Dictionary
				is_available = bool(status.get("is_available", true))
				charges = int(status.get("charges", 0))

		var icon_tex: Texture2D = null
		var primary_item: StringName = StringName("")
		var primary_name: String = ""

		var drops_any: Variant = def.get("drops", [])
		if drops_any is Array:
			var drops: Array = drops_any as Array
			if drops.size() > 0 and drops[0] is Dictionary:
				primary_item = StringName((drops[0] as Dictionary).get("id", StringName("")))

		if typeof(Items) != TYPE_NIL and primary_item != StringName(""):
			if Items.has_method("get_icon"):
				var icon_v: Variant = Items.get_icon(primary_item)
				if icon_v is Texture2D:
					icon_tex = icon_v as Texture2D
			if Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(primary_item):
				primary_name = String(Items.display_name(primary_item))

		var preview_careful: Array = []
		var preview_quick: Array = []

		if hs.has_method("get_drop_preview_for_patch"):
			var p1: Variant = hs.call("get_drop_preview_for_patch", patch_id, false)
			if p1 is Array:
				preview_careful = p1 as Array

			var p2: Variant = hs.call("get_drop_preview_for_patch", patch_id, true)
			if p2 is Array:
				preview_quick = p2 as Array

		var careful_id: StringName = StringName(String(patch_id) + "_careful")
		var careful_desc: String = "Careful pick: steady yield (2 actions)."
		if primary_name != "":
			careful_desc = "Careful pick: steady yield (2 actions). Primary: %s." % primary_name

		recipes.append({
			"id": careful_id,
			"label": "Gather %s (Careful)" % label_base,
			"skill": &"herbalism",
			"icon": icon_tex,
			"level_req": req,
			"xp": xp_base,
			"inputs": [],
			"output": {},
			"desc": careful_desc,
			"drop_preview": preview_careful,
			"disabled": (not is_available),
			"reason": ("Regrowing" if not is_available else ""),
			"patch_id": patch_id,
			"mode": "careful",
			"charges": charges,
		})

		var quick_id: StringName = StringName(String(patch_id) + "_quick")
		var quick_desc: String = "Quick pick: 5× yield (1 action), consumes 1 charge."
		if primary_name != "":
			quick_desc = "Quick pick: 5× yield (1 action), consumes 1 charge. Primary: %s." % primary_name

		var quick_disabled: bool = (not is_available) or (charges <= 0)
		var quick_reason: String = ""
		if not is_available:
			quick_reason = "Regrowing"
		elif charges <= 0:
			quick_reason = "No charges"

		recipes.append({
			"id": quick_id,
			"label": "Gather %s (Quick)" % label_base,
			"skill": &"herbalism",
			"icon": icon_tex,
			"level_req": req,
			"xp": xp_base * 5,
			"inputs": [],
			"output": {},
			"desc": quick_desc,
			"drop_preview": preview_quick,
			"disabled": quick_disabled,
			"reason": quick_reason,
			"patch_id": patch_id,
			"mode": "quick",
			"charges": charges,
		})

	return _normalize_recipe_list(JOB_HERBALISM, recipes)


# -------------------------------------------------------------------
# Tick
# -------------------------------------------------------------------

func _on_tick(delta_s: float, _tick_index: int) -> void:
	var keys: Array = _jobs.keys()

	for k_v: Variant in keys:
		var v_idx: int = int(k_v)

		if not _jobs.has(v_idx):
			continue

		var st_v: Variant = _jobs[v_idx]
		if not (st_v is Dictionary):
			_jobs.erase(v_idx)
			continue

		var st: Dictionary = st_v as Dictionary
		var job: StringName = StringName(st.get("job", JOB_NONE))

		if job == JOB_NONE:
			continue

		var duration: float = float(st.get("duration", 0.0))
		if duration <= 0.0:
			var recipe_id: StringName = StringName(st.get("recipe", StringName()))
			duration = _job_duration(job, recipe_id)
			st["duration"] = duration

		var elapsed: float = float(st.get("elapsed", 0.0))

		# Emit progress at the START of the tick (pre-advance).
		job_progress.emit(v_idx, job, elapsed, duration)

		# Advance time.
		elapsed += delta_s
		st["elapsed"] = elapsed
		_jobs[v_idx] = st

		# Emit post-advance for smoother UI.
		job_progress.emit(v_idx, job, min(elapsed, duration), duration)

		if elapsed >= duration:
			_complete_job(v_idx)


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

func _is_valid_index(i: int) -> bool:
	return (
		typeof(Villagers) != TYPE_NIL
		and Villagers.has_method("count")
		and i >= 0
		and i < int(Villagers.count())
	)
