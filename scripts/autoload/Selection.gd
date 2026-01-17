# autoload/Selection.gd
extends Node
signal fragment_selected(f: Node)

var current: Node = null
var by_axial: Dictionary = {}   # Vector2i -> Node

# Drag watchdog state
var _was_dragging: bool = false

func _ready() -> void:
	# Make sure _process runs (autoloads usually do, but keep it explicit)
	set_process(true)

func _process(_delta: float) -> void:
	_drag_watchdog()

func _drag_watchdog() -> void:
	if not is_inside_tree():
		return

	var vp: Viewport = get_viewport()
	if vp == null:
		return

	var dragging: bool = vp.gui_is_dragging()

	# Only act on the transition: not dragging -> dragging
	if dragging and not _was_dragging:
		var data: Variant = vp.gui_get_drag_data()
		if not _is_allowed_drag(data):
			# Log who started it (this is the key to fixing the real cause)
			var owner: Control = vp.gui_get_drag_owner()
			var owner_path: String = ""
			if owner != null and is_instance_valid(owner):
				owner_path = String(owner.get_path())

			print("[Selection] CANCELLED unintended GUI drag. owner=", owner_path, " data=", data)
			vp.gui_cancel_drag()

	_was_dragging = dragging

func _is_allowed_drag(data: Variant) -> bool:
	# Allow only your bank-item drag payloads.
	if typeof(data) == TYPE_DICTIONARY:
		var d: Dictionary = data as Dictionary
		return String(d.get("kind", "")) == "bank_item"
	return false


func register_fragment(f: Node) -> void:
	if f == null or not is_instance_valid(f):
		return

	var v: Variant = f.get("coord")
	if not (v is Vector2i):
		return
	var ax: Vector2i = v as Vector2i
	by_axial[ax] = f

	# Clicks from the fragment (Fragment has: signal clicked(fragment))
	if f.has_signal("clicked") and not f.clicked.is_connected(_on_fragment_clicked):
		f.clicked.connect(_on_fragment_clicked)

	# Clean up when it leaves the tree (bind the fragment we registered)
	var exit_cb: Callable = Callable(self, "_on_fragment_exited").bind(f)
	if not f.tree_exiting.is_connected(exit_cb):
		f.tree_exiting.connect(exit_cb)

func unregister_fragment(f: Node) -> void:
	if f == null:
		return
	for k in by_axial.keys():
		if by_axial[k] == f:
			by_axial.erase(k)
			break
	if current == f:
		set_selected(null)

func _on_fragment_clicked(f: Node) -> void:
	set_selected(f)

func _on_fragment_exited(f: Node) -> void:
	unregister_fragment(f)

func set_selected(f: Node) -> void:
	if current == f:
		return
	if current and is_instance_valid(current) and current.has_method("set_selected"):
		current.set_selected(false)
	current = f
	if current and is_instance_valid(current) and current.has_method("set_selected"):
		current.set_selected(true)
	fragment_selected.emit(current)

func has_fragment_at(ax: Vector2i) -> bool:
	return by_axial.has(ax)

func fragment_at(ax: Vector2i) -> Node:
	return by_axial.get(ax, null)

func current_axial() -> Variant:
	if current == null or not is_instance_valid(current):
		return null
	var v: Variant = current.get("coord")
	return v if v is Vector2i else null

func adjacent_free_count(ax: Vector2i) -> int:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	var free: int = 0
	for d in dirs:
		if not by_axial.has(ax + d):
			free += 1
	return free

func clear() -> void:
	current = null
	by_axial.clear()
