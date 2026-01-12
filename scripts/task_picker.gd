# res://ui/task_picker.gd
class_name TaskPicker
extends PopupMenu

const CraftMenuScript := preload("res://ui/Craft_Menu.gd")
const GatheringMenuScript := preload("res://ui/Gathering_Menu.gd")

var _v_idx: int = -1
var _ax: Vector2i
var _specs: Array = []

func open_for(villager_index: int, axial: Vector2i, screen_pos: Vector2 = Vector2(-1, -1)) -> void:
	_v_idx = villager_index
	_ax = axial

	clear()
	_populate_items()

	var cb := Callable(self, "_on_pick")
	if not is_connected("id_pressed", cb):
		connect("id_pressed", cb, CONNECT_ONE_SHOT)

	# If no position given, fall back to mouse position
	if screen_pos.x < 0.0:
		screen_pos = get_viewport().get_mouse_position()

	# PopupMenu expects a Rect2i. Size can be tiny; it will auto-size.
	popup(Rect2i(Vector2i(screen_pos), Vector2i(1, 1)))

# ------------------------------------------------------------
# NEW: read tile modifiers directly (so we can infer gather jobs)
# ------------------------------------------------------------
func _get_world() -> Node:
	return get_tree().get_first_node_in_group("World")

func _mods_at(ax: Vector2i) -> Array:
	var w := _get_world()
	if w and w.has_method("get_modifiers_at"):
		return w.call("get_modifiers_at", ax)
	return []

func _skills_from_modifiers(mods: Array) -> Dictionary:
	# returns { "herbalism": true, "mining": true, ... }
	var out := {}
	for m in mods:
		if typeof(m) == TYPE_DICTIONARY:
			var md: Dictionary = m
			var kind := String(md.get("kind", "")).strip_edges()
			if kind == "Resource Spawn":
				var skill := String(md.get("skill", "")).strip_edges().to_lower()
				if skill != "":
					out[skill] = true
			continue

		var s := str(m).to_lower()
		# Expecting: "resource spawn [herbalism]: ..."
		var lb := s.find("[")
		var rb := s.find("]", lb + 1)
		if lb != -1 and rb != -1:
			var skill := s.substr(lb + 1, rb - lb - 1).strip_edges()
			if skill != "":
				out[skill] = true
	return out

func _specs_has_job(specs: Array, job_name: StringName) -> bool:
	for s_v in specs:
		if typeof(s_v) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s_v
		if StringName(s.get("job", &"none")) == job_name:
			return true
	return false

func _ensure_gather_specs_from_tile(specs: Array) -> Array:
	# If VillagerManager forgot to include a gather job, inject it
	var mods := _mods_at(_ax)
	var skills := _skills_from_modifiers(mods)

	# Only add gather skills that are actually present on this tile
	var gather_jobs := [
		{ "skill": "mining",       "label": "Mining" },
		{ "skill": "woodcutting",  "label": "Woodcutting" },
		{ "skill": "fishing",      "label": "Fishing" },
		{ "skill": "herbalism",    "label": "Herbalism" },
	]

	var next_id := 1000
	for gj in gather_jobs:
		var skill_id := String(gj["skill"])
		if not skills.has(skill_id):
			continue

		var job_sn := StringName(skill_id)
		if _specs_has_job(specs, job_sn):
			continue

		specs.append({
			"label": String(gj["label"]),
			"job": job_sn,
			"id": next_id,
			"disabled": false,
			"reason": ""
		})
		next_id += 1

	return specs

func _populate_items() -> void:
	var specs: Array = []

	# Ask the VillagerManager which jobs are valid for this villager+tile
	if typeof(VillagerManager) != TYPE_NIL and VillagerManager.has_method("get_jobs_for_tile"):
		specs = VillagerManager.get_jobs_for_tile(_v_idx, _ax)
	else:
		specs = _fallback_specs()

	# NEW: safety-net based on tile modifiers (fixes herbalism missing due to parsing mismatch)
	specs = _ensure_gather_specs_from_tile(specs)

	_specs = specs

	clear()

	var line: int = 0
	for s_v in specs:
		if typeof(s_v) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s_v

		# Skip disabled tasks
		if bool(s.get("disabled", false)):
			continue

		var label: String = String(s.get("label", "Job"))
		var id: int = int(s.get("id", line + 1))

		add_item(label, id)
		line += 1

func _fallback_specs() -> Array:
	var specs: Array = []

	specs.append({
		"label": "Scrying",
		"job": &"scrying",
		"id": 1,
		"disabled": false,
		"reason": ""
	})

	specs.append({
		"label": "Astromancy",
		"job": &"astromancy",
		"id": 2,
		"disabled": false,
		"reason": ""
	})

	specs.append({
		"label": "Smithing",
		"job": &"smithing",
		"id": 3,
		"disabled": false,
		"reason": ""
	})

	return specs

func _on_pick(id: int) -> void:
	var job: StringName = &"none"

	# Look up the spec with this id
	for s_v in _specs:
		if typeof(s_v) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s_v
		if int(s.get("id", -1)) == id:
			job = StringName(s.get("job", &"none"))
			break

	if job == &"none":
		queue_free()
		return

	var job_str := String(job)
	print("TaskPicker: picked job ", job_str, " at ", _ax, " for villager ", _v_idx)

	# ------------------------------------------------
	# 1) GATHER JOBS → Gathering menu
	#    NEW: includes herbalism
	# ------------------------------------------------
	if job == VillagerManager.JOB_MINING \
	or job == VillagerManager.JOB_WOODCUTTING \
	or job == VillagerManager.JOB_FISHING \
	or job_str == "mining" \
	or job_str == "woodcutting" \
	or job_str == "fishing" \
	or job_str == "herbalism":

		var recipes: Array = []
		if typeof(VillagerManager) != TYPE_NIL and VillagerManager.has_method("get_recipes_for_job"):
			recipes = VillagerManager.get_recipes_for_job(_v_idx, job, _ax)
			print("TaskPicker: gather recipes for job ", job, " at ", _ax, " -> ", recipes)

		_open_gather_menu(job, recipes)
		queue_free()
		return

	# ------------------------------------------------
	# 2) SCRYING → simple auto job, NO menus
	# ------------------------------------------------
	if job == &"scrying" or job_str == "scrying":
		print("TaskPicker: assigning simple SCRYING job (no menu)")
		_assign_simple_job(job)
		queue_free()
		return

	# ------------------------------------------------
	# 3) CRAFT JOBS → Craft menu
	# ------------------------------------------------
	var recipes_other: Array = []

	if typeof(VillagerManager) != TYPE_NIL and VillagerManager.has_method("get_recipes_for_job"):
		recipes_other = VillagerManager.get_recipes_for_job(_v_idx, job, _ax)
		print("TaskPicker: recipes for job ", job, " at ", _ax, " -> ", recipes_other)

	if job == &"smithing" \
	or job == &"construction" \
	or job == &"astromancy":
		_open_craft_menu(job, recipes_other)
		queue_free()
		return

	# ------------------------------------------------
	# 4) Anything else → simple timed job
	# ------------------------------------------------
	_assign_simple_job(job)
	queue_free()

func _assign_simple_job(job: StringName) -> void:
	if typeof(VillagerManager) == TYPE_NIL:
		return

	if VillagerManager.has_method("assign_job_with_recipe"):
		VillagerManager.assign_job_with_recipe(_v_idx, job, _ax, StringName())
	elif VillagerManager.has_method("assign_job_at"):
		VillagerManager.assign_job_at(_v_idx, job, _ax)
	elif VillagerManager.has_method("assign_job"):
		VillagerManager.assign_job(_v_idx, job)

func _open_craft_menu(job: StringName, recipes: Array) -> void:
	var cm := CraftMenuScript.new() as Control

	var ui_parent: Node = null
	var world := get_tree().get_first_node_in_group("World")
	if world and world.has_node("CanvasLayer"):
		ui_parent = world.get_node("CanvasLayer")
	else:
		var scene := get_tree().current_scene
		if scene and scene.has_node("CanvasLayer"):
			ui_parent = scene.get_node("CanvasLayer")
		else:
			ui_parent = get_tree().root

	ui_parent.add_child(cm)

	if cm.has_method("setup"):
		cm.call("setup", _v_idx, job, _ax, recipes)

func _open_gather_menu(job: StringName, recipes: Array) -> void:
	var gm := GatheringMenuScript.new() as Control

	var ui_parent: Node = null
	var world := get_tree().get_first_node_in_group("World")
	if world and world.has_node("CanvasLayer"):
		ui_parent = world.get_node("CanvasLayer")
	else:
		var scene := get_tree().current_scene
		if scene and scene.has_node("CanvasLayer"):
			ui_parent = scene.get_node("CanvasLayer")
		else:
			ui_parent = get_tree().root

	ui_parent.add_child(gm)

	if gm.has_method("setup"):
		gm.call("setup", _v_idx, job, _ax, recipes)
