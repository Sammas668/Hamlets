extends Control

var _v_idx: int = -1
var _job: StringName = &"none"
var _ax: Vector2i = Vector2i.ZERO
var _recipes: Array = []
var _selected_idx: int = -1

var _dim: ColorRect
var _frame: PanelContainer
var _recipes_vbox: VBoxContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_desc: Label
var _detail_req: Label
var _close_btn: Button
var _start_btn: Button

var _title_label: Label
var _left_label: Label
var _drop_label: Label              # bottom-right drops summary

var _ui_scale: float = 1.0


func _ready() -> void:
	set_as_top_level(true)

	_build_layout()
	_wire_basic()

	_resize_to_viewport()
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_resize_to_viewport)


# Turn drop_preview data into a readable string, e.g.
# "Copper Ore ×2 100%, Clay ×1 15%, Fail 5%"
func _format_drop_preview(preview: Array) -> String:
	var parts: Array[String] = []

	for entry_v in preview:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v

		var chance: float = float(entry.get("chance", 0.0))
		var is_fail: bool = bool(entry.get("is_fail", false))

		if chance <= 0.0:
			continue

		var pct := chance * 100.0
		var pct_str := ""

		# Show tiny chances nicely for mythic stuff
		if pct < 0.1 and pct > 0.0:
			pct_str = "<0.1%"
		elif pct < 1.0:
			pct_str = "%.1f%%" % pct
		else:
			pct_str = "%.0f%%" % pct

		if is_fail:
			parts.append("Fail %s" % pct_str)
		else:
			var item_id: StringName = entry.get("item_id", StringName(""))
			var item_name := str(item_id)

			# Nicer display names if Items autoload is available
			if typeof(Items) != TYPE_NIL \
			and Items.has_method("is_valid") \
			and Items.has_method("display_name") \
			and Items.is_valid(item_id):
				item_name = Items.display_name(item_id)

			# NEW: include quantity (avg per cycle, including 2× from thick groves)
			var qty: int = int(entry.get("qty", 1))
			if qty < 1:
				qty = 1

			# e.g. "Pine Logs ×2 65%"
			parts.append("%s ×%d %s" % [item_name, qty, pct_str])

	return ", ".join(parts)


# Helper: which skill to use for level gating, based on job
func _skill_id_for_job() -> String:
	match String(_job):
		"woodcutting":
			return "woodcutting"
		"fishing":
			return "fishing"
		"mining":
			return "mining"
		"herbalism":
			return "herbalism"
		_:
			return "mining"


# Helper: left column label based on job
func _resource_label_for_job() -> String:
	match String(_job):
		"woodcutting":
			return "Trees"
		"fishing":
			return "Spots"
		"herbalism":
			return "Patches"
		_:
			return "Deposits"

# Called by TaskPicker
func setup(v_idx: int, job: StringName, ax: Vector2i, recipes: Array) -> void:
	_v_idx = v_idx
	_job = job
	_ax = ax

	# Take a deep copy so later changes don't mutate our view
	_recipes = recipes.duplicate(true)

	_populate_recipes()
	if _recipes.size() > 0:
		_select_recipe(0)
	else:
		_update_start_button_state()

	# Update left label based on job (Mining vs Woodcutting)
	if _left_label:
		_left_label.text = _resource_label_for_job()


# -------------------------------------------------------------------
# Layout
# -------------------------------------------------------------------
func _build_layout() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	# Dim background
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	# Center container
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_frame = PanelContainer.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_frame.add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_theme_constant_override("separation", 14)
	margin.add_child(root_v)

	# Header: title + close
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 10)
	root_v.add_child(header)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Choose what to gather"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 32)
	header.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(40, 40)
	_close_btn.focus_mode = Control.FOCUS_NONE
	header.add_child(_close_btn)

	# Body: [ list | details ]
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root_v.add_child(body)

	# Left column: deposits / trees list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)

	_left_label = Label.new()
	_left_label.text = "Deposits"
	_left_label.add_theme_font_size_override("font_size", 24)
	left.add_child(_left_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.clip_contents = true
	left.add_child(scroll)

	_recipes_vbox = VBoxContainer.new()
	_recipes_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipes_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_recipes_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_recipes_vbox)

	# Right column: details
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	right.add_child(top_row)

	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(128, 128)
	_detail_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_row.add_child(_detail_icon)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name_box.add_theme_constant_override("separation", 6)
	top_row.add_child(name_box)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 26)
	name_box.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_desc.add_theme_font_size_override("font_size", 20)
	name_box.add_child(_detail_desc)

	_detail_req = Label.new()
	_detail_req.add_theme_font_size_override("font_size", 20)
	name_box.add_child(_detail_req)

	# Spacer so drop label hugs the bottom of the right column
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_spacer)

	# Bottom-right drop summary
	_drop_label = Label.new()
	_drop_label.name = "DropsLabel"
	_drop_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_drop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drop_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_drop_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_drop_label.add_theme_font_size_override("font_size", 18)
	right.add_child(_drop_label)

	# Footer: Start button bottom-right
	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	footer.add_theme_constant_override("separation", 8)
	root_v.add_child(footer)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	_start_btn = Button.new()
	_start_btn.text = "Start gathering"
	_start_btn.custom_minimum_size = Vector2(160, 40)
	_start_btn.focus_mode = Control.FOCUS_NONE
	footer.add_child(_start_btn)


func _resize_to_viewport() -> void:
	if _frame == null:
		return

	var vs := get_viewport_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return

	var target := vs * Vector2(0.8, 0.8)
	_frame.custom_minimum_size = target
	_frame.size = target

	var base_h := 1080.0
	_ui_scale = clampf((vs.y / base_h) * 1.3, 1.2, 2.0)

	if _title_label:
		_title_label.add_theme_font_size_override("font_size", int(32 * _ui_scale))
	if _left_label:
		_left_label.add_theme_font_size_override("font_size", int(24 * _ui_scale))
	if _detail_name:
		_detail_name.add_theme_font_size_override("font_size", int(26 * _ui_scale))
	if _detail_desc:
		_detail_desc.add_theme_font_size_override("font_size", int(20 * _ui_scale))
	if _detail_req:
		_detail_req.add_theme_font_size_override("font_size", int(20 * _ui_scale))
	if _drop_label:
		_drop_label.add_theme_font_size_override("font_size", int(18 * _ui_scale))

	if _detail_icon:
		var icon_size := 128.0 * _ui_scale
		_detail_icon.custom_minimum_size = Vector2(icon_size, icon_size)

	if _start_btn:
		_start_btn.custom_minimum_size.y = 40 * _ui_scale

	_refresh_recipe_row_fonts()


func _refresh_recipe_row_fonts() -> void:
	if _recipes_vbox == null:
		return
	for c in _recipes_vbox.get_children():
		if c is Button:
			var b := c as Button
			b.add_theme_font_size_override("font_size", int(20 * _ui_scale))
			b.custom_minimum_size = Vector2(0, 44 * _ui_scale)


func _wire_basic() -> void:
	if _close_btn:
		_close_btn.pressed.connect(func() -> void:
			queue_free()
		)

	if _dim:
		_dim.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				queue_free()
		)

	if _start_btn:
		_start_btn.pressed.connect(func() -> void:
			_start_gather())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var world := get_tree().get_first_node_in_group("World")
		if world and world.has_method("_open_menu"):
			world.call("_open_menu")
		queue_free()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


# -------------------------------------------------------------------
# Populate + selection
# -------------------------------------------------------------------
func _populate_recipes() -> void:
	if _recipes_vbox == null:
		return

	for c in _recipes_vbox.get_children():
		c.queue_free()

	for i in range(_recipes.size()):
		var rec_v: Variant = _recipes[i]
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = rec_v

		var btn := Button.new()
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 44 * _ui_scale)
		btn.add_theme_font_size_override("font_size", int(20 * _ui_scale))

		var label_str := String(rec.get("label", "Deposit"))
		var level_req := int(rec.get("level_req", 0))
		if level_req > 0:
			label_str += "  (Lv %d)" % level_req

		# If you *also* want a tiny preview in the list rows, you could
		# append it here using _format_drop_preview(rec.get("drop_preview", []))

		btn.text = label_str
		btn.set_meta("recipe_index", i)
		btn.pressed.connect(func() -> void:
			var idx := int(btn.get_meta("recipe_index", -1))
			if idx >= 0:
				_select_recipe(idx)
		)

		_recipes_vbox.add_child(btn)


func _select_recipe(idx: int) -> void:
	_selected_idx = idx

	for b_v in _recipes_vbox.get_children():
		if b_v is Button:
			var b := b_v as Button
			var bi := int(b.get_meta("recipe_index", -1))
			b.button_pressed = (bi == idx)

	if idx < 0 or idx >= _recipes.size():
		_clear_detail()
		return

	var rec_v: Variant = _recipes[idx]
	if typeof(rec_v) != TYPE_DICTIONARY:
		_clear_detail()
		return
	var rec: Dictionary = rec_v

	var label_str := String(rec.get("label", "Deposit"))
	var desc_str := String(rec.get("desc", ""))
	var level_req := int(rec.get("level_req", 0))
	var xp := int(rec.get("xp", 0))
	var primary_name := String(rec.get("primary_item_name", ""))

	# If we have a primary item (like a log), append it to the description
	if primary_name != "":
		if desc_str != "":
			desc_str += "\n\nPrimary resource: %s" % primary_name
		else:
			desc_str = "Primary resource: %s" % primary_name

	var preview: Array = rec.get("drop_preview", [])
	var drops_str := ""
	if not preview.is_empty():
		drops_str = _format_drop_preview(preview)

	# Top-right title + desc
	if _detail_name:
		_detail_name.text = label_str

	if _detail_desc:
		_detail_desc.text = desc_str if desc_str != "" else "No description yet."

	# Bottom-right drops summary
	if _drop_label:
		if drops_str != "":
			_drop_label.text = "Drops: %s" % drops_str
		else:
			_drop_label.text = ""

	# Requirements line
	if _detail_req:
		var parts: Array[String] = []
		if level_req > 0:
			parts.append("Level %d required" % level_req)
		if xp > 0:
			parts.append("%d XP per cycle" % xp)
		_detail_req.text = " • ".join(parts)

	# Icon
	if _detail_icon:
		var tex: Texture2D = null
		var icon_v: Variant = rec.get("icon", null)
		if icon_v is Texture2D:
			tex = icon_v
		elif typeof(icon_v) == TYPE_STRING:
			var path: String = icon_v
			if path != "":
				var loaded := load(path)
				if loaded is Texture2D:
					tex = loaded
		_detail_icon.texture = tex

	_update_start_button_state()


func _clear_detail() -> void:
	if _detail_name:
		_detail_name.text = ""
	if _detail_desc:
		_detail_desc.text = ""
	if _detail_req:
		_detail_req.text = ""
	if _detail_icon:
		_detail_icon.texture = null
	if _drop_label:
		_drop_label.text = ""
	_update_start_button_state()


# -------------------------------------------------------------------
# Requirements + Start
# -------------------------------------------------------------------
func _can_gather_selected() -> bool:
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		return false

	var rec_v: Variant = _recipes[_selected_idx]
	if typeof(rec_v) != TYPE_DICTIONARY:
		return false
	var rec: Dictionary = rec_v

	var level_req := int(rec.get("level_req", 0))
	if level_req <= 0:
		return true

	var skill_id := _skill_id_for_job()

	var lv := 0
	if _v_idx >= 0 \
	and typeof(Villagers) != TYPE_NIL \
	and Villagers.has_method("get_skill_level"):
		lv = int(Villagers.get_skill_level(_v_idx, skill_id))
	elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
		lv = int(Skills.get_skill_level(skill_id))

	return lv >= level_req


func _update_start_button_state() -> void:
	if _start_btn:
		_start_btn.disabled = not _can_gather_selected()


func _start_gather() -> void:
	if not _can_gather_selected():
		return
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		return

	var rec_v: Variant = _recipes[_selected_idx]
	if typeof(rec_v) != TYPE_DICTIONARY:
		return
	var rec: Dictionary = rec_v

	var recipe_id := StringName(rec.get("id", &""))

	if typeof(VillagerManager) != TYPE_NIL:
		if VillagerManager.has_method("assign_job_with_recipe") and recipe_id != StringName():
			# Infinite repeat until stopped
			VillagerManager.assign_job_with_recipe(_v_idx, _job, _ax, recipe_id, 1, true)
		elif VillagerManager.has_method("assign_job_at"):
			VillagerManager.assign_job_at(_v_idx, _job, _ax)
		elif VillagerManager.has_method("assign_job"):
			VillagerManager.assign_job(_v_idx, _job)

	queue_free()
