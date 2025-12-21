extends Node

const PANEL_SCENE: PackedScene = preload("res://ui/TooltipPanel.tscn")

var _layer: CanvasLayer
var _panel: Panel
var _follow: bool = false
var _anchor_pos: Vector2 = Vector2.ZERO
var _hide_time: float = 0.0
var _grace_s: float = 0.2

@export var lock_action: StringName = &"tooltip_lock"
var _shift_prev: bool = false

func _shift_down() -> bool:
	if InputMap.has_action(lock_action):
		return Input.is_action_pressed(lock_action)
	return Input.is_key_pressed(KEY_SHIFT)

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	get_tree().root.call_deferred("add_child", _layer)   # correct deferred add

	_panel = PANEL_SCENE.instantiate() as Panel
	_layer.add_child(_panel)
	_panel.visible = false

	set_process(true)

func _process(dt: float) -> void:
	if _panel == null or not _panel.visible:
		return

	# Shift-hold lock/unlock
	var sd: bool = _shift_down()
	if sd and not _shift_prev:
		_panel.call("lock")
	elif (not sd) and _shift_prev:
		_panel.call("unlock")
	_shift_prev = sd

	# Follow mouse if not locked
	if _follow and not _panel.call("is_locked"):
		_place_at(get_viewport().get_mouse_position())

	# Graceful auto-hide when mouse leaves both panels
	if not _panel.call("is_locked"):
		var over_main: bool = _is_mouse_over_control(_panel)
		var sub := _panel.get_node_or_null("SubTip") as Control
		var over_sub: bool = sub != null and sub.visible and _is_mouse_over_control(sub)
		if over_main or over_sub or _is_near_anchor():
			_hide_time = 0.0
		else:
			_hide_time += dt
			if _hide_time >= _grace_s:
				hide_all()

# ---- public API ----

func show_follow(data: Dictionary) -> void:
	if _panel == null: return
	_panel.call("set_data", data)
	_panel.call("unlock")
	_panel.call("show_panel")
	_follow = true
	_anchor_pos = get_viewport().get_mouse_position()
	_place_at(_anchor_pos)

func lock() -> void:
	if _panel == null: return
	_panel.call("lock")
	_follow = false

func maybe_hide() -> void:
	if _panel == null: return
	if not _panel.call("is_locked"):
		hide_all()

func hide_all() -> void:
	if _panel == null: return
	_panel.call("hide_panel")
	_follow = false
	_hide_time = 0.0

func request_for_control(_ctrl: Control, data: Dictionary) -> void:
	show_follow(data)
	_anchor_pos = get_viewport().get_mouse_position()

func request_for_world(data: Dictionary) -> void:
	show_follow(data)

func request_subtip(key: String, owner_panel: Panel) -> void:
	if _panel == null: return
	var text := _lookup_subtip_bbcode(key)
	if text == "": return
	var anchor := get_viewport().get_mouse_position()
	owner_panel.call("set_subtip", text, anchor)

func hide_subtip(owner_panel: Panel = null) -> void:
	if _panel == null: return
	if owner_panel:
		owner_panel.call("hide_subtip")

# ---- helpers ----

func _place_at(mouse_screen: Vector2) -> void:
	var margin := Vector2(16, 16)
	var vp := get_viewport().get_visible_rect().size
	var sz := (_panel as Control).size
	var pos := mouse_screen + margin
	pos.x = clampf(pos.x, 0.0, vp.x - sz.x)
	pos.y = clampf(pos.y, 0.0, vp.y - sz.y)
	_panel.global_position = pos

func _is_mouse_over_control(c: Control) -> bool:
	if c == null or not c.visible:
		return false
	var mp := get_viewport().get_mouse_position()
	var rect := Rect2(c.global_position, c.size)
	return rect.has_point(mp)

func _is_near_anchor() -> bool:
	return _anchor_pos.distance_to(get_viewport().get_mouse_position()) < 24.0

func _lookup_subtip_bbcode(key: String) -> String:
	match key:
		"Biome":
			return "[b]Biome[/b]\nAffects yields, events, and build availability."
		"Coord":
			return "[b]Coordinates[/b]\nAxial hex coordinates (q,r)."
		_:
			return ""
