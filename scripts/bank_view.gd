extends Control
class_name BankView

# 1.0 = same as the Button’s icon size
# 0.5 = half that size, etc.
const DRAG_ICON_SCALE := 0.15  

@export var columns: int = 5   # 5 columns = nice wide tokens

@onready var _title: Label        = get_node_or_null("VBoxContainer/TitleLabel")
@onready var _capacity: Label     = get_node_or_null("VBoxContainer/Capacity")
@onready var _grid: GridContainer = get_node_or_null("VBoxContainer/Grid")

var _cells: Array[Button] = []   # Array of bank slot buttons (BankSlotButton extends Button)


# --- Local drag-enabled bank button class ---
class BankSlotButton:
	extends Button

	func _get_drag_data(at_position: Vector2) -> Variant:
		# Read item id stored in this slot
		var item_id: String = String(get_meta("item_id", ""))
		if item_id == "" or icon == null:
			return null

		var tex := icon as Texture2D
		if tex == null:
			return null

		var data: Dictionary = {
			"kind": "bank_item",
			"item_id": item_id,
			"icon": tex,
		}

		# --- Drag preview: match the Button's icon sizing rules ---

		# Start from texture pixel size
		var w: int = tex.get_width()
		var h: int = tex.get_height()

		# Clamp using the same theme constants the Button uses for its icon
		var max_w := get_theme_constant("icon_max_width", "Button")
		var max_h := get_theme_constant("icon_max_height", "Button")

		if max_w > 0:
			w = min(w, max_w)
		if max_h > 0:
			h = min(h, max_h)

		# Safety fallback
		if w <= 0:
			w = 16
		if h <= 0:
			h = 16

		var icon_size := Vector2(w, h)

		var preview := TextureRect.new()
		preview.texture = tex
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# This defines the logical icon box before scaling
		preview.custom_minimum_size = icon_size
		preview.size = icon_size

		# Apply a visual scale so you can nudge the size.
		# DRAG_ICON_SCALE is defined on BankView.
		var s := BankView.DRAG_ICON_SCALE
		preview.scale = Vector2(s, s)

		# Center under the cursor, taking scale into account
		var half_size_scaled: Vector2 = icon_size * s * 0.5
		preview.position = -half_size_scaled

		set_drag_preview(preview)
		return data


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
