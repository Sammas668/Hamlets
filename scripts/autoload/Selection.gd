# autoload/Selection.gd
extends Node

signal fragment_selected(f: Node)

@export var debug_logging: bool = true
@export var debug_drag_probe: bool = true
@export var cancel_gui_drag_on_world_click: bool = true
@export var cancel_drag_extra_frames: int = 2  # cancel again for N frames after click

var current: Node = null
var by_axial: Dictionary = {}   # Vector2i -> Node

var _dragging_last: bool = false
var _cancel_seq: int = 0


func _ready() -> void:
	set_process(debug_drag_probe)


func _process(_dt: float) -> void:
	if not debug_drag_probe:
		return

	var vp: Viewport = get_viewport()
	if vp == null:
		return

	var dragging: bool = vp.gui_is_dragging()
	if dragging != _dragging_last:
		_dragging_last = dragging

		if dragging:
			var data: Variant = vp.gui_get_drag_data()
			var hovered: Control = vp.gui_get_hovered_control()
			if debug_logging:
				print("[Drag] BEGIN data=", data, " hovered=", _describe_control(hovered))
		else:
			if debug_logging:
				print("[Drag] END")


func _input(event: InputEvent) -> void:
	# Catch the click early (before unhandled), so we can cancel any GUI drag fast.
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var vp: Viewport = get_viewport()
			if vp == null:
				return

			var hovered: Control = vp.gui_get_hovered_control()
			var hovered_desc: String = _describe_control(hovered)

			if debug_logging:
				print("[Selection] LMB press pos=", mb.position, " hovered=", hovered_desc)

			# If the click is on the world (no hovered Control), kill any GUI drag.
			if cancel_gui_drag_on_world_click and hovered == null:
				_cancel_seq += 1
				var seq: int = _cancel_seq

				_cancel_gui_drag_now("press", vp)

				if cancel_drag_extra_frames > 0:
					call_deferred("_cancel_gui_drag_for_frames", seq, cancel_drag_extra_frames)


func _cancel_gui_drag_now(reason: String, vp: Viewport) -> void:
	if vp == null:
		return

	# If a drag is active, cancelling it will remove the preview immediately.
	if vp.gui_is_dragging():
		var data: Variant = vp.gui_get_drag_data()
		if debug_logging:
			print("[Drag] cancel reason=", reason, " data=", data)
		vp.gui_cancel_drag()


func _cancel_gui_drag_for_frames(seq: int, frames: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var vp: Viewport = get_viewport()
	if vp == null:
		return

	var i: int = 0
	while i < frames:
		await tree.process_frame

		# If another click happened, this run is obsolete.
		if seq != _cancel_seq:
			return

		_cancel_gui_drag_now("frame+" + str(i + 1), get_viewport())
		i += 1


func _describe_control(c: Control) -> String:
	if c == null:
		return "<none>"
	return str(c.get_path()) + " (" + c.get_class() + ")"


# -------------------------
# Fragment registry
# -------------------------
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

	for k_v: Variant in by_axial.keys():
		if by_axial.get(k_v) == f:
			by_axial.erase(k_v)
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

	if current != null and is_instance_valid(current) and current.has_method("set_selected"):
		current.set_selected(false)

	current = f

	if current != null and is_instance_valid(current) and current.has_method("set_selected"):
		current.set_selected(true)

	fragment_selected.emit(current)


func has_fragment_at(ax: Vector2i) -> bool:
	return by_axial.has(ax)


func fragment_at(ax: Vector2i) -> Node:
	var v: Variant = by_axial.get(ax, null)
	return v as Node


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
	for d: Vector2i in dirs:
		if not by_axial.has(ax + d):
			free += 1
	return free


func clear() -> void:
	current = null
	by_axial.clear()
