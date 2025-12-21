# res://ui/task_picker.gd
class_name TaskPicker
extends PopupMenu

# Preload the CraftMenu script (pure-code overlay)
const CraftMenuScript := preload("res://ui/Craft_Menu.gd")
const GatheringMenuScript := preload("res://ui/Gathering_Menu.gd")

var _v_idx: int = -1
var _ax: Vector2i
var _specs: Array = []


func open_for(villager_index: int, axial: Vector2i) -> void:
	_v_idx = villager_index
	_ax = axial

	clear()
	_populate_items()

	var cb := Callable(self, "_on_pick")
	if not is_connected("id_pressed", cb):
		connect("id_pressed", cb, CONNECT_ONE_SHOT)

	popup_centered()


func _populate_items() -> void:
	var specs: Array = []

	# Ask the VillagerManager which jobs are valid for this villager+tile
	if typeof(VillagerManager) != TYPE_NIL and VillagerManager.has_method("get_jobs_for_tile"):
		specs = VillagerManager.get_jobs_for_tile(_v_idx, _ax)
	else:
		specs = _fallback_specs()

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
	# ------------------------------------------------
	if job == VillagerManager.JOB_MINING \
	or job == VillagerManager.JOB_WOODCUTTING \
	or job == VillagerManager.JOB_FISHING \
	or job_str == "mining" \
	or job_str == "woodcutting" \
	or job_str == "fishing":

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


# -------------------------------------------------------------------
# Craft menu spawn
# -------------------------------------------------------------------
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
