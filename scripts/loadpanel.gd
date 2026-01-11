# res://scenes/LoadPanel.gd
extends PanelContainer
signal request_close
signal load_slot(id: String)

@export var columns: int = 3
@export var tile_height: float = 72.0
@export var include_autosave: bool = true

@onready var grid: GridContainer   = $Margin/VBox/Header/SlotsGrid
@onready var title_lbl: Label      = $Margin/VBox/Header/Title 
@onready var delete_btn: Button    = $Margin/VBox/Header/Buttons/DeleteBtn
@onready var close_btn: Button     = $Margin/VBox/Header/Buttons/CloseBtn

var _selected_id: String = ""
var _buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(720, 520)
	if grid: grid.columns = columns
	_apply_panel_style()

	# Wire buttons
	if close_btn: close_btn.pressed.connect(func(): emit_signal("request_close"))
	if delete_btn: delete_btn.pressed.connect(_delete_selected)


	# Listen for save-system changes
	var SL := _SL()
	if SL and SL.has_signal("saves_changed"):
		SL.connect("saves_changed", Callable(self, "_refresh"))

	# Debug so you can see what the panel sees
	_debug_log_nodes()
	_refresh()

func open() -> void:
	visible = true
	_refresh()
	await get_tree().process_frame
	if _buttons.size() > 0:
		_buttons[0].grab_focus()

# ---------- data ----------
func _SL() -> Node:
	var n := get_node_or_null("/root/SaveLoad")
	return n if n != null else get_node_or_null("/root/SaveLoadData")

func _list_saves() -> Array[Dictionary]:
	var SL: Node = _SL()
	if SL == null or not SL.has_method("list_saves"):
		print("[LoadPanel] Save system unavailable.")
		return []

	var out: Array[Dictionary] = []
	var res: Variant = SL.call("list_saves")
	if res is Array:
		for v in (res as Array):
			if v is Dictionary:
				out.append(v as Dictionary)

	if not include_autosave:
		var filtered: Array[Dictionary] = []
		for d in out:
			if String(d.get("id","")) != "autosave":
				filtered.append(d)
		out = filtered

	return out

# ---------- UI build / refresh ----------
func _refresh() -> void:
	if not grid:
		print("[LoadPanel] grid is NULL — check node path.")
		return

	var saves := _list_saves()
	print("[LoadPanel] _refresh -> found saves:", saves.size())
	_build_cards(saves)

func _build_cards(saves: Array[Dictionary]) -> void:
	for c in grid.get_children():
		c.queue_free()
	_buttons.clear()

	for d in saves:
		var id := String(d.get("id",""))
		var b := _make_tile_button(id, d)
		grid.add_child(b)
		_buttons.append(b)

	if saves.is_empty():
		var lbl := Label.new()
		lbl.text = "No saves found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(0, tile_height)
		grid.add_child(lbl)

func _make_tile_button(id: String, meta: Dictionary) -> Button:
	var b := Button.new()
	b.name = id
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, tile_height)
	b.text = _label_for(id, meta)
	_apply_tile_style(b)

	b.pressed.connect(func():
		_selected_id = id
		_mark_selection(id)
		emit_signal("load_slot", id)   # parent (MainMenu) does SaveLoad.load_grove + scene swap
	)
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventKey and e.pressed and e.keycode == KEY_ENTER:
			_selected_id = id
			_mark_selection(id)
			emit_signal("load_slot", id)
	)
	return b

func _label_for(id: String, d: Dictionary) -> String:
	var label := String(d.get("label", id))
	var ts: int = int(d.get("timestamp", 0))
	var when := (Time.get_datetime_string_from_unix_time(ts) if ts > 0 else "Unknown")
	return "%s\n%s\n%s" % [id, label, when]

func _mark_selection(id: String) -> void:
	for b in _buttons:
		b.button_pressed = (b.name == id)

# ---------- actions ----------
func _delete_selected() -> void:
	if _selected_id == "": return
	var SL := _SL()
	if SL and SL.has_method("delete_save"):
		SL.call("delete_save", _selected_id)
	_refresh()
	_selected_id = ""

# ---------- styling ----------
func _apply_panel_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.12, 0.86)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	add_theme_stylebox_override("panel", sb)
	if title_lbl:
		# If your Label already has text in the scene, we don’t overwrite it;
		# but ensure it’s visible and sized nicely.
		title_lbl.visible = true
		title_lbl.add_theme_font_size_override("font_size", 22)

func _apply_tile_style(b: Button) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.18, 0.20, 0.24, 1.0)
	base.corner_radius_top_left = 10
	base.corner_radius_top_right = 10
	base.corner_radius_bottom_left = 10
	base.corner_radius_bottom_right = 10
	base.content_margin_left = 10
	base.content_margin_right = 10
	base.content_margin_top = 8
	base.content_margin_bottom = 8
	base.set_border_width_all(1)                  # Godot 4 API
	base.border_color = Color(0, 0, 0, 0.55)

	var hover: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	hover.bg_color = base.bg_color.lerp(Color(0.28, 0.30, 0.34, 1.0), 0.35)
	hover.border_color = Color(0.35, 0.55, 0.90, 0.65)
	hover.set_border_width_all(1)

	var pressed: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	pressed.bg_color = base.bg_color.darkened(0.15)
	pressed.border_color = Color(0.35, 0.75, 1.0, 0.85)
	pressed.set_border_width_all(2)

	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))

# ---------- debug ----------
func _debug_log_nodes() -> void:
	print("[LoadPanel] title_lbl=", title_lbl, " grid=", grid, " del=", delete_btn, " close=", close_btn)
	var SL := _SL()
	print("[LoadPanel] SL autoload=", SL, " has list_saves?=", (SL and SL.has_method("list_saves")))
	if SL and SL.has_method("list_saves"):
		var arr := SL.call("list_saves") as Array
		print("[LoadPanel] list_saves raw size=", arr.size())
