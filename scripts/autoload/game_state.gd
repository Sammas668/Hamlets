extends Node
# (no class_name needed when autoloaded)

var _pending_world: Dictionary = {}   # consumed by World.gd


func has_pending_world() -> bool:
	return not _pending_world.is_empty()


func take_pending_world() -> Dictionary:
	var d: Dictionary = _pending_world
	_pending_world = {}
	return d


func from_dict(d: Dictionary) -> void:
	# -------------------------
	# 1) World data
	# -------------------------
	_pending_world = {}

	# New-style saves: { world: {...}, bank: {...}, villagers: {...}, ... }
	if d.has("world"):
		var w_raw: Variant = d["world"]
		if w_raw is Dictionary:
			_pending_world = (w_raw as Dictionary).duplicate(true)
	else:
		# Old-style saves: whole dict is just the world snapshot
		_pending_world = d.duplicate(true)

	# -------------------------
	# 2) Bank
	# -------------------------
	if d.has("bank") \
	and typeof(Bank) != TYPE_NIL \
	and Bank.has_method("from_save_dict"):
		var b_raw: Variant = d["bank"]
		if b_raw is Dictionary:
			Bank.from_save_dict(b_raw as Dictionary)

	# -------------------------
	# 3) Villagers
	# -------------------------
	if d.has("villagers") \
	and typeof(Villagers) != TYPE_NIL \
	and Villagers.has_method("from_save_dict"):
		var v_raw: Variant = d["villagers"]
		if v_raw is Dictionary:
			Villagers.from_save_dict(v_raw as Dictionary)

	# -------------------------
	# 4) VillagerManager (jobs)
	# -------------------------
	if d.has("villager_manager") \
	and typeof(VillagerManager) != TYPE_NIL \
	and VillagerManager.has_method("from_save_dict"):
		var jm_raw: Variant = d["villager_manager"]
		if jm_raw is Dictionary:
			VillagerManager.from_save_dict(jm_raw as Dictionary)

	# (later you can add: global skills, settings, etc.)


func to_dict() -> Dictionary:
	var data: Dictionary = {}

	# -------------------------
	# 1) World / current scene
	# -------------------------
	var cs: Node = get_tree().current_scene
	if cs and cs.has_method("get_save_dict"):
		var w_raw: Variant = cs.call("get_save_dict")
		if w_raw is Dictionary:
			data["world"] = (w_raw as Dictionary)

	# -------------------------
	# 2) Bank
	# -------------------------
	if typeof(Bank) != TYPE_NIL and Bank.has_method("to_save_dict"):
		data["bank"] = Bank.to_save_dict()

	# -------------------------
	# 3) Villagers
	# -------------------------
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("to_save_dict"):
		data["villagers"] = Villagers.to_save_dict()

	# -------------------------
	# 4) VillagerManager (jobs)
	# -------------------------
	if typeof(VillagerManager) != TYPE_NIL and VillagerManager.has_method("to_save_dict"):
		data["villager_manager"] = VillagerManager.to_save_dict()

	return data
