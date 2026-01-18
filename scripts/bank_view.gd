extends Control
class_name BankView

# 1.0 = same as the Button’s icon size
# 0.5 = half that size, etc.
const DRAG_ICON_SCALE := 0.15  
const DRAG_THRESHOLD := 8.0

@export var columns: int = 5   # 5 columns = nice wide tokens

@onready var _title: Label        = get_node_or_null("VBoxContainer/TitleLabel")
@onready var _capacity: Label     = get_node_or_null("VBoxContainer/Capacity")
@onready var _grid: GridContainer = get_node_or_null("VBoxContainer/Grid")

var _cells: Array[Button] = []   # Array of bank slot buttons (BankSlotButton extends Button)
var _sb_cell_normal: StyleBoxFlat
var _sb_cell_hover: StyleBoxFlat
var _sb_cell_pressed: StyleBoxFlat
var _sb_cell_focus: StyleBoxFlat


# --- Local drag-enabled bank button class ---
class BankSlotButton:
	extends Button

	# Extra debounce so “click jitter” never triggers a drag.
	const DRAG_HOLD_MS: int = 140

	var _drag_start_pos: Vector2 = Vector2.ZERO
	var _drag_tracking: bool = false
	var _drag_initiated: bool = false
	var _press_time_ms: int = 0

	func _gui_input(event: InputEvent) -> void:
		# Only track drags when this slot actually has something draggable.
		# (Prevents noise from empty slots.)
		var has_item: bool = (String(get_meta("item_id", "")) != "" and icon != null)

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				if not has_item:
					_drag_tracking = false
					_drag_initiated = false
					return
				_drag_start_pos = mb.position
				_press_time_ms = Time.get_ticks_msec()
				_drag_tracking = true
				_drag_initiated = false
				accept_event()
			else:
				_drag_tracking = false
				_drag_initiated = false
				accept_event()
			return

		if event is InputEventMouseMotion and _drag_tracking:
			# If mouse is no longer down, stop tracking.
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_drag_tracking = false
				_drag_initiated = false
				return

			# Already started a drag this press.
			if _drag_initiated:
				return

			# Hold-time gate: prevents micro-moves during click from triggering drag.
			var elapsed_ms: int = Time.get_ticks_msec() - _press_time_ms
			if elapsed_ms < DRAG_HOLD_MS:
				return

			var mm := event as InputEventMouseMotion
			var dist: float = (mm.position - _drag_start_pos).length()

			# Distance gate
			if dist >= BankView.DRAG_THRESHOLD:
				_start_drag()
				accept_event()
			return

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			_drag_tracking = false
			_drag_initiated = false

	# IMPORTANT:
	# We are using force_drag() manually, so we don't want Godot's automatic
	# drag pipeline to kick in at all. Removing _get_drag_data prevents any
	# automatic drag start attempts.
	#
	# (If you leave _get_drag_data in, it usually still works, but this is
	# the cleanest way to guarantee no ghost drag starts.)
	# func _get_drag_data(_at_position: Vector2) -> Variant:
	# 	return null

	func _start_drag() -> void:
		_drag_tracking = false
		_drag_initiated = true

		var data: Variant = _build_drag_data()
		if data == null:
			_drag_initiated = false
			return

		var preview: Control = _build_drag_preview(data as Dictionary)
		if preview:
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

		print("DRAG START ", get_path())
		print_stack()
		
		force_drag(data, preview)

	func _build_drag_data() -> Variant:
		var item_id: String = String(get_meta("item_id", ""))
		if item_id == "" or icon == null:
			return null

		var tex := icon as Texture2D
		if tex == null:
			return null

		return {
			"kind": "bank_item",
			"item_id": item_id,
			"icon": tex,
		}

	func _build_drag_preview(data: Dictionary) -> Control:
		if not data.has("icon") or not (data["icon"] is Texture2D):
			return null

		var tex := data["icon"] as Texture2D

		var w: int = max(1, tex.get_width())
		var h: int = max(1, tex.get_height())

		var max_w: int = get_theme_constant("icon_max_width", "Button")
		var max_h: int = get_theme_constant("icon_max_height", "Button")
		if max_w > 0:
			w = min(w, max_w)
		if max_h > 0:
			h = min(h, max_h)

		var icon_size := Vector2(w, h)

		var preview := TextureRect.new()
		preview.texture = tex
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = icon_size
		preview.size = icon_size

		var s := BankView.DRAG_ICON_SCALE
		preview.scale = Vector2(s, s)
		preview.position = -(icon_size * s * 0.5)

		return preview




func _ready() -> void:
	# Fallback grid if the scene layout is different
	if _grid == null:
		_grid = GridContainer.new()
		_grid.name = "Grid"
		add_child(_grid)

	# Wrap the Grid in a ScrollContainer so the bank can grow and scroll
	if _grid != null and not (_grid.get_parent() is ScrollContainer):
		var parent := _grid.get_parent()
		if parent:
			var idx := parent.get_children().find(_grid)
			parent.remove_child(_grid)

			var scroll := ScrollContainer.new()
			scroll.name = "Scroll"
			scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.clip_contents = true

			parent.add_child(scroll)
			if idx >= 0:
				parent.move_child(scroll, idx)

			scroll.add_child(_grid)
			_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if _capacity == null:
		_capacity = Label.new()
		_capacity.name = "Capacity"
		_capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _title:
			var vb: Node = _title.get_parent()
			vb.add_child(_capacity)
			var idx2 := vb.get_children().find(_title)
			if idx2 >= 0:
				vb.move_child(_capacity, idx2 + 1)
		else:
			add_child(_capacity)

	if _title and _title.text == "":
		_title.text = "Bank"
	_init_cell_styleboxes()
	_build_cells()
	_refresh()


	# Listen to Bank changes
	if typeof(Bank) != TYPE_NIL:
		if Bank.has_signal("changed") and not Bank.changed.is_connected(_on_bank_changed):
			Bank.changed.connect(_on_bank_changed)
		if Bank.has_signal("cleared") and not Bank.cleared.is_connected(_on_bank_cleared):
			Bank.cleared.connect(_on_bank_cleared)
		if Bank.has_signal("capacity_changed") and not Bank.capacity_changed.is_connected(_on_bank_capacity_changed):
			Bank.capacity_changed.connect(_on_bank_capacity_changed)


func _build_cells() -> void:
	if _grid == null:
		return

	# Clear any existing children
	for c in _grid.get_children():
		c.queue_free()
	_cells.clear()

	_grid.columns = columns

	# Number of visible cells = current bank capacity
	var total: int = columns * 4   # fallback if Bank missing
	if typeof(Bank) != TYPE_NIL and Bank.has_method("max_slots"):
		total = int(Bank.max_slots())

	for i in range(total):
		var b := BankSlotButton.new()
		b.add_theme_stylebox_override("normal", _sb_cell_normal)
		b.add_theme_stylebox_override("hover", _sb_cell_hover)
		b.add_theme_stylebox_override("pressed", _sb_cell_pressed)
		b.add_theme_stylebox_override("focus", _sb_cell_focus)

		# Optional: remove any leftover focus visuals
		b.focus_mode = Control.FOCUS_NONE

		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL

		# Make them chunky & square-ish like an OSRS/Melvor bank slot
		b.custom_minimum_size = Vector2(72, 72)

		# Icon-friendly
		b.text = ""              # we won't use Button.text for quantity
		b.icon = null
		b.expand_icon = true

		# Quantity overlay label (bottom-right)
		var qty_label := Label.new()
		qty_label.name = "QtyLabel"
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		qty_label.text = ""
		qty_label.add_theme_font_size_override("font_size", 14)
		qty_label.add_theme_color_override("font_color", Color.WHITE)
		qty_label.add_theme_constant_override("outline_size", 1)
		qty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))

		b.add_child(qty_label)

		_grid.add_child(b)
		_cells.append(b)


func _refresh() -> void:
	# If Bank autoload is missing, show a warning and clear cells
	if typeof(Bank) == TYPE_NIL:
		if _capacity:
			_capacity.text = "Bank (autoload missing)"
		for b in _cells:
			b.disabled = true
			b.icon = null
			b.text = ""
			b.set_meta("item_id", "")
			var lbl: Label = b.get_node_or_null("QtyLabel") as Label
			if lbl:
				lbl.text = ""
			b.tooltip_text = ""
		return

	var max_slots: int = _cells.size()
	if Bank.has_method("max_slots"):
		max_slots = int(Bank.max_slots())

	var used_slots: int = 0
	if Bank.has_method("used_slots"):
		used_slots = int(Bank.used_slots())

	if _capacity:
		_capacity.text = "Slots: %d / %d" % [used_slots, max_slots]

	var items: Array[Dictionary] = []
	if Bank.has_method("as_list"):
		items = Bank.as_list()

	# Sort items by name for stable ordering
	items.sort_custom(Callable(self, "_sort_items_by_name"))

	for i in range(_cells.size()):
		var b: Button = _cells[i]
		var qty_label: Label = b.get_node_or_null("QtyLabel") as Label

		if i < items.size():
			var e: Dictionary = items[i]
			var item_name: String = String(e.get("name", e.get("id", "")))
			var qty: int = int(e.get("qty", 0))
			var id_str: String = String(e.get("id", ""))

			b.disabled = false

			# --- Icon from Items ---
			var tex: Texture2D = null
			if typeof(Items) != TYPE_NIL and Items.has_method("get_icon"):
				tex = Items.get_icon(StringName(id_str))
			b.icon = tex

			# Store the id on the button so _get_drag_data can read it
			b.set_meta("item_id", id_str)

			# --- Quantity indicator via overlay label ---
			if qty_label:
				if qty > 0:
					qty_label.text = str(qty)
				else:
					qty_label.text = ""

			# Tooltip with full info
			b.tooltip_text = "%s x%d (%s)" % [item_name, qty, id_str]
		else:
			b.disabled = false
			b.icon = null
			b.text = ""
			b.set_meta("item_id", "")
			if qty_label:
				qty_label.text = ""
			b.tooltip_text = ""


func _sort_items_by_name(a: Dictionary, b: Dictionary) -> bool:
	var an: String = String(a.get("name", a.get("id", "")))
	var bn: String = String(b.get("name", b.get("id", "")))
	return an < bn


# --- Bank signal handlers ---

func _on_bank_changed(_id: StringName, _new_amount: int) -> void:
	_refresh()

func _on_bank_cleared() -> void:
	_refresh()

func _on_bank_capacity_changed(_max_slots: int) -> void:
	_build_cells()
	_refresh()


func _init_cell_styleboxes() -> void:
	_sb_cell_normal = StyleBoxFlat.new()
	_sb_cell_normal.bg_color = Color(0.08, 0.08, 0.10, 0.95)
	_sb_cell_normal.border_width_left = 2
	_sb_cell_normal.border_width_right = 2
	_sb_cell_normal.border_width_top = 2
	_sb_cell_normal.border_width_bottom = 2
	_sb_cell_normal.border_color = Color(0.18, 0.18, 0.24, 1.0)
	_sb_cell_normal.corner_radius_top_left = 10
	_sb_cell_normal.corner_radius_top_right = 10
	_sb_cell_normal.corner_radius_bottom_left = 10
	_sb_cell_normal.corner_radius_bottom_right = 10

	_sb_cell_hover = _sb_cell_normal.duplicate() as StyleBoxFlat
	_sb_cell_hover.border_color = Color(0.35, 0.55, 0.90, 1.0)

	# IMPORTANT: pressed = normal (removes the flash “ghost box”)
	_sb_cell_pressed = _sb_cell_normal.duplicate() as StyleBoxFlat

	_sb_cell_focus = _sb_cell_normal.duplicate() as StyleBoxFlat
	_sb_cell_focus.border_color = Color(0.45, 0.80, 1.00, 1.0)
