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
var _detail_inputs_vbox: VBoxContainer
var _close_btn: Button

# New: multi-craft buttons + X input
var _craft_1_btn: Button
var _craft_x_btn: Button
var _craft_all_btn: Button
var _x_input: LineEdit

# Extra references so we can scale text
var _title_label: Label
var _left_label: Label
var _inputs_label: Label

# New: tier selector (for tiered recipes, e.g. construction)
var _tier_panel: PanelContainer
var _tier_box: HBoxContainer
var _tier_label: Label
var _tier_value_label: Label
var _tier_prev_btn: Button
var _tier_next_btn: Button
var _selected_tier: int = 0
var _tier_min: int = 0
var _tier_max: int = 0

var _ui_scale: float = 1.0

# Is this menu being used to summon a fragment (empty adjacent hex) rather than forge?
var _is_summon: bool = false


func _ready() -> void:
	# Make this overlay independent of the world/camera
	set_as_top_level(true)

	_build_layout()
	_wire_basic()

	_resize_to_viewport()
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_resize_to_viewport)


# Called by TaskPicker
func setup(v_idx: int, job: StringName, ax: Vector2i, recipes: Array) -> void:
	_v_idx = v_idx
	_job = job
	_ax = ax

	# IMPORTANT: take a copy so later mutations in VillagerManager don't affect us
	_recipes = recipes.duplicate(true)

	# Detect summon vs forge for Astromancy
	_is_summon = false
	if _job == &"astromancy":
		var world := get_tree().get_first_node_in_group("World")
		var has_frag := false
		if world and world.has_method("_has_fragment_at"):
			has_frag = bool(world.call("_has_fragment_at", _ax))
		_is_summon = (not has_frag)

	# --- titles + labels per job ---
	if _title_label:
		match _job:
			&"mining":
				_title_label.text = "Gather resources"
			&"scrying":
				_title_label.text = "Scrying"
			&"astromancy":
				if _is_summon:
					_title_label.text = "Summon fragment"
				else:
					_title_label.text = "Astromancy forge"
			&"smithing":
				_title_label.text = "Smithing forge"
			&"construction":
				_title_label.text = "Construction yard"
			_:
				_title_label.text = "Choose what to do"

	if _left_label:
		match _job:
			&"mining":
				_left_label.text = "Deposits"
			&"scrying":
				_left_label.text = "Options"
			&"astromancy":
				_left_label.text = "Recipes"
			&"smithing":
				_left_label.text = "Recipes"
			&"construction":
				_left_label.text = "Blueprints"
			_:
				_left_label.text = "Recipes"

	if _inputs_label:
		if _job == &"mining":
			_inputs_label.text = "Result:"
		else:
			_inputs_label.text = "Required materials:"

	# Button labels
	if _craft_1_btn:
		if _job == &"mining":
			_craft_1_btn.text = "Gather"
		elif _job == &"astromancy" and _is_summon:
			_craft_1_btn.text = "Summon"
		else:
			_craft_1_btn.text = "Craft 1"

	if _craft_x_btn:
		if _job == &"mining":
			_craft_x_btn.text = "Gather X"
		else:
			_craft_x_btn.text = "Craft X"

	if _craft_all_btn:
		if _job == &"mining":
			_craft_all_btn.text = "Gather All"
		else:
			_craft_all_btn.text = "Craft All"

	# --- populate recipes ---
	_populate_recipes()
	if _recipes.size() > 0:
		_select_recipe(0)
	else:
		_update_start_button_state()


# -------------------------------------------------------------------
# Layout
# -------------------------------------------------------------------
func _build_layout() -> void:
	# Full-screen overlay, locked to viewport (camera-independent)
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

	# Center container: always fills screen and keeps frame centered
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Frame: size is controlled by _resize_to_viewport()
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
	_title_label.text = "Choose what to craft"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 32)
	header.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(40, 40)
	_close_btn.focus_mode = Control.FOCUS_NONE
	header.add_child(_close_btn)

	# Body: [ Recipes list | Details ]
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root_v.add_child(body)

	# Left column: recipes list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)

	_left_label = Label.new()
	_left_label.text = "Recipes"
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

	# Right column: selected recipe details
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

	# Tier selector row in its own highlighted panel (hidden by default)
	_tier_panel = PanelContainer.new()
	_tier_panel.visible = false
	_tier_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_box.add_child(_tier_panel)

	# Subtle cool highlight style (not gold)
	var tier_style := StyleBoxFlat.new()
	tier_style.bg_color = Color(0.10, 0.13, 0.18, 0.95)  # deep blue-grey
	tier_style.set_border_width_all(2.0)
	tier_style.border_color = Color(0.55, 0.75, 1.0)      # soft blue border
	tier_style.corner_radius_top_left = 4
	tier_style.corner_radius_top_right = 4
	tier_style.corner_radius_bottom_left = 4
	tier_style.corner_radius_bottom_right = 4
	_tier_panel.add_theme_stylebox_override("panel", tier_style)

	var tier_margin := MarginContainer.new()
	tier_margin.add_theme_constant_override("margin_left", 6)
	tier_margin.add_theme_constant_override("margin_right", 6)
	tier_margin.add_theme_constant_override("margin_top", 4)
	tier_margin.add_theme_constant_override("margin_bottom", 4)
	_tier_panel.add_child(tier_margin)

	_tier_box = HBoxContainer.new()
	_tier_box.add_theme_constant_override("separation", 6)
	_tier_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_margin.add_child(_tier_box)

	_tier_label = Label.new()
	_tier_label.text = "Material tier:"
	_tier_box.add_child(_tier_label)

	_tier_prev_btn = Button.new()
	_tier_prev_btn.text = "<"
	_tier_prev_btn.custom_minimum_size = Vector2(40, 32)
	_tier_prev_btn.focus_mode = Control.FOCUS_NONE
	_tier_box.add_child(_tier_prev_btn)

	_tier_value_label = Label.new()
	_tier_value_label.text = "-"
	_tier_box.add_child(_tier_value_label)

	_tier_next_btn = Button.new()
	_tier_next_btn.text = ">"
	_tier_next_btn.custom_minimum_size = Vector2(40, 32)
	_tier_next_btn.focus_mode = Control.FOCUS_NONE
	_tier_box.add_child(_tier_next_btn)

	_inputs_label = Label.new()
	_inputs_label.text = "Required materials:"
	_inputs_label.add_theme_font_size_override("font_size", 24)
	right.add_child(_inputs_label)

	_detail_inputs_vbox = VBoxContainer.new()
	_detail_inputs_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_inputs_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_inputs_vbox.add_theme_constant_override("separation", 6)
	right.add_child(_detail_inputs_vbox)

	# Footer: Craft 1 / X / All in bottom right
	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	footer.add_theme_constant_override("separation", 8)
	root_v.add_child(footer)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	# X input
	var x_label := Label.new()
	x_label.text = "X:"
	x_label.add_theme_font_size_override("font_size", 18)
	footer.add_child(x_label)

	_x_input = LineEdit.new()
	_x_input.custom_minimum_size = Vector2(70, 32)
	_x_input.text = "1"
	_x_input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_x_input)

	_craft_1_btn = Button.new()
	_craft_1_btn.text = "Craft 1"
	_craft_1_btn.custom_minimum_size = Vector2(110, 40)
	_craft_1_btn.focus_mode = Control.FOCUS_NONE
	footer.add_child(_craft_1_btn)

	_craft_x_btn = Button.new()
	_craft_x_btn.text = "Craft X"
	_craft_x_btn.custom_minimum_size = Vector2(110, 40)
	_craft_x_btn.focus_mode = Control.FOCUS_NONE
	footer.add_child(_craft_x_btn)

	_craft_all_btn = Button.new()
	_craft_all_btn.text = "Craft All"
	_craft_all_btn.custom_minimum_size = Vector2(110, 40)
	_craft_all_btn.focus_mode = Control.FOCUS_NONE
	footer.add_child(_craft_all_btn)


# Make the frame 80% of the viewport and scale fonts/icons
func _resize_to_viewport() -> void:
	if _frame == null:
		return

	var vs := get_viewport_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return

	# Frame size: 80% of screen
	var target := vs * Vector2(0.8, 0.8)
	_frame.custom_minimum_size = target
	_frame.size = target

	# Scale factor: base on height, but 1.3× baseline at 1080p
	var base_h := 1080.0
	_ui_scale = clampf((vs.y / base_h) * 1.3, 1.2, 2.0)

	# Fonts – all multiplied by _ui_scale
	if _title_label:
		_title_label.add_theme_font_size_override("font_size", int(32 * _ui_scale))
	if _left_label:
		_left_label.add_theme_font_size_override("font_size", int(24 * _ui_scale))
	if _inputs_label:
		_inputs_label.add_theme_font_size_override("font_size", int(24 * _ui_scale))
	if _detail_name:
		_detail_name.add_theme_font_size_override("font_size", int(26 * _ui_scale))
	if _detail_desc:
		_detail_desc.add_theme_font_size_override("font_size", int(20 * _ui_scale))
	if _detail_req:
		_detail_req.add_theme_font_size_override("font_size", int(20 * _ui_scale))
	if _tier_label:
		_tier_label.add_theme_font_size_override("font_size", int(22 * _ui_scale))
	if _tier_value_label:
		_tier_value_label.add_theme_font_size_override("font_size", int(22 * _ui_scale))
		_tier_value_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))  # soft blue

	# Main recipe icon size
	if _detail_icon:
		var icon_size := 128.0 * _ui_scale
		_detail_icon.custom_minimum_size = Vector2(icon_size, icon_size)

	# Buttons + X input height scaling (width can stay fixed)
	if _x_input:
		_x_input.custom_minimum_size.y = 32 * _ui_scale
	if _craft_1_btn:
		_craft_1_btn.custom_minimum_size.y = 40 * _ui_scale
	if _craft_x_btn:
		_craft_x_btn.custom_minimum_size.y = 40 * _ui_scale
	if _craft_all_btn:
		_craft_all_btn.custom_minimum_size.y = 40 * _ui_scale
	if _tier_prev_btn:
		_tier_prev_btn.custom_minimum_size = Vector2(40 * _ui_scale, 36 * _ui_scale)
	if _tier_next_btn:
		_tier_next_btn.custom_minimum_size = Vector2(40 * _ui_scale, 36 * _ui_scale)

	# Also refresh recipe rows to pick up new font size if already populated
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

	# Craft 1
	if _craft_1_btn:
		_craft_1_btn.pressed.connect(func() -> void:
			_start_craft(1)
		)

	# Craft All
	if _craft_all_btn:
		_craft_all_btn.pressed.connect(func() -> void:
			var max_count := _max_craftable_count()
			if max_count > 0:
				_start_craft(max_count)
		)

	# Craft X
	if _craft_x_btn:
		_craft_x_btn.pressed.connect(func() -> void:
			var x := _parse_x_input()
			if x <= 0:
				return
			var max_count := _max_craftable_count()
			if max_count > 0:
				x = min(x, max_count)
			_start_craft(x)
		)

	# Tier prev / next
	if _tier_prev_btn:
		_tier_prev_btn.pressed.connect(func() -> void:
			_change_tier(-1)
		)
	if _tier_next_btn:
		_tier_next_btn.pressed.connect(func() -> void:
			_change_tier(1)
		)


# -------------------------------------------------------------------
# ESC handling: close craft menu and open ESC menu
# -------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Ask the World to open its pause/ESC menu
		var world := get_tree().get_first_node_in_group("World")
		if world and world.has_method("_open_menu"):
			world.call("_open_menu")

		# Close this overlay
		queue_free()

		# Consume the event so World._unhandled_input doesn't double-toggle
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


# -------------------------------------------------------------------
# Helper: does this recipe *really* use the tier UI?
# -------------------------------------------------------------------
func _has_real_tiers_for_recipe(rec: Dictionary) -> bool:
	# Only construction uses the tier selector UI.
	if _job != &"construction":
		return false

	# Only treat recipes that explicitly declare a tier range as "tiered".
	if not rec.has("tier_min") or not rec.has("tier_max"):
		return false

	var tmin := int(rec.get("tier_min", 0))
	var tmax := int(rec.get("tier_max", 0))

	if tmin <= 0:
		return false
	if tmax <= tmin:
		return false

	return true


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

		var label_str := String(rec.get("label", "Recipe"))
		var level_req := int(rec.get("level_req", 0))
		if level_req > 0:
			label_str += "  (Lv %d)" % level_req
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

	# Update toggle states
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

	var label_str := String(rec.get("label", "Recipe"))
	var desc_str := String(rec.get("desc", ""))
	var level_req := int(rec.get("level_req", 0))
	var xp := int(rec.get("xp", 0))

	if _detail_name:
		_detail_name.text = label_str

	if _detail_desc:
		_detail_desc.text = (desc_str if desc_str != "" else "No description yet.")

	if _detail_req:
		var req_parts: Array[String] = []
		if level_req > 0:
			req_parts.append("Level %d required" % level_req)
		if xp > 0:
			req_parts.append("%d XP per cycle" % xp)
		_detail_req.text = " • ".join(req_parts)

	# Tier config for this recipe (if any)
	_tier_min = int(rec.get("tier_min", 0))
	_tier_max = int(rec.get("tier_max", 0))
	var tier_default := int(rec.get("tier_default", 0))

	var has_real_tiers := _has_real_tiers_for_recipe(rec)

	if has_real_tiers:
		# Keep current selection if it’s in range, otherwise use default or min
		var chosen_tier := _selected_tier
		if chosen_tier < _tier_min or chosen_tier > _tier_max:
			if tier_default >= _tier_min and tier_default <= _tier_max:
				chosen_tier = tier_default
			else:
				chosen_tier = _tier_min
		_selected_tier = chosen_tier

		if _tier_panel:
			_tier_panel.visible = true
		if _tier_value_label:
			_tier_value_label.text = str(_selected_tier)
	else:
		_tier_min = 0
		_tier_max = 0
		_selected_tier = 0
		if _tier_panel:
			_tier_panel.visible = false
		if _tier_value_label:
			_tier_value_label.text = "-"

	# Icon (output item)
	if _detail_icon:
		var tex: Texture2D = null
		var icon_v: Variant = rec.get("icon", null)

		# Allow either a direct Texture2D OR a path string
		if icon_v is Texture2D:
			tex = icon_v
		elif typeof(icon_v) == TYPE_STRING:
			var path: String = icon_v
			if path != "":
				var loaded := load(path)
				if loaded is Texture2D:
					tex = loaded

		_detail_icon.texture = tex

	# Materials (have / need) with icons
	if _detail_inputs_vbox:
		for c in _detail_inputs_vbox.get_children():
			c.queue_free()

		var inputs: Array = rec.get("inputs", []) as Array
		for inp_v in inputs:
			if typeof(inp_v) != TYPE_DICTIONARY:
				continue
			var inp: Dictionary = inp_v
			var item_id := StringName(inp.get("item", &""))
			var qty_needed := int(inp.get("qty", 0))

			if String(item_id) == "":
				continue

			var have := 0
			if typeof(Bank) != TYPE_NIL and Bank.has_method("amount"):
				have = int(Bank.amount(item_id))

			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 8)

			# Input icon
			var input_tex: Texture2D = null
			if typeof(Items) != TYPE_NIL and Items.has_method("get_icon_path"):
				var ipath: String = String(Items.get_icon_path(item_id))
				if ipath != "":
					var loaded_icon := load(ipath)
					if loaded_icon is Texture2D:
						input_tex = loaded_icon

			if input_tex != null:
				var icon_rect := TextureRect.new()
				icon_rect.custom_minimum_size = Vector2(40, 40) * _ui_scale
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.texture = input_tex
				row.add_child(icon_rect)

			# Pretty item name
			var name_str := String(item_id)
			if typeof(Items) != TYPE_NIL and Items.has_method("display_name"):
				if (Items.has_method("is_valid") and Items.is_valid(item_id)) \
				or not Items.has_method("is_valid"):
					name_str = Items.display_name(item_id)

			var lbl := Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.text = "%s: %d / %d" % [
				name_str,
				have,
				qty_needed
			]

			lbl.add_theme_font_size_override("font_size", int(20 * _ui_scale))

			if have >= qty_needed:
				lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
			else:
				lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))

			row.add_child(lbl)
			_detail_inputs_vbox.add_child(row)

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
	if _detail_inputs_vbox:
		for c in _detail_inputs_vbox.get_children():
			c.queue_free()

	# Reset tier UI
	_tier_min = 0
	_tier_max = 0
	_selected_tier = 0
	if _tier_panel:
		_tier_panel.visible = false
	if _tier_value_label:
		_tier_value_label.text = "-"

	_update_start_button_state()


# -------------------------------------------------------------------
# Tier selector helpers
# -------------------------------------------------------------------
func _change_tier(delta: int) -> void:
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		return

	var rec_v: Variant = _recipes[_selected_idx]
	if typeof(rec_v) != TYPE_DICTIONARY:
		return
	var rec: Dictionary = rec_v

	if not _has_real_tiers_for_recipe(rec):
		return

	_selected_tier = clampi(_selected_tier + delta, _tier_min, _tier_max)

	if _tier_value_label:
		_tier_value_label.text = str(_selected_tier)

	# For Construction, rebuild this recipe from ConstructionSystem using the chosen tier
	if _job == &"construction" \
	and typeof(ConstructionSystem) != TYPE_NIL \
	and ConstructionSystem.has_method("get_recipe_by_id"):

		var base_id: StringName = rec.get("base_id", rec.get("id", &""))
		var tiered_id_str := "%s:t%d" % [String(base_id), _selected_tier]
		var tiered_id: StringName = StringName(tiered_id_str)

		var new_rec: Dictionary = ConstructionSystem.get_recipe_by_id(tiered_id)
		if not new_rec.is_empty():
			_recipes[_selected_idx] = new_rec
			# Re-run selection to refresh UI with the new per-tier inputs, XP etc.
			_select_recipe(_selected_idx)
			return

	# If we didn’t rebuild the recipe, at least refresh button state
	_update_start_button_state()


# -------------------------------------------------------------------
# Requirements + Buttons
# -------------------------------------------------------------------
func _can_craft_selected() -> bool:
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		return false

	var rec_v: Variant = _recipes[_selected_idx]
	if typeof(rec_v) != TYPE_DICTIONARY:
		return false
	var rec: Dictionary = rec_v

	var level_req := int(rec.get("level_req", 0))

	# Skill level check – prefer villager skill, fallback to global Skills if needed
	if level_req > 0:
		var skill_id := ""
		if _job == &"scrying":
			skill_id = "scrying"
		elif _job == &"astromancy":
			skill_id = "astromancy"
		elif _job == &"smithing":
			skill_id = "smithing"
		elif _job == &"construction":
			skill_id = "construction"

		if skill_id != "":
			var lv := 0

			# 1) Per-villager skill
			if _v_idx >= 0 \
			and typeof(Villagers) != TYPE_NIL \
			and Villagers.has_method("get_skill_level"):
				lv = int(Villagers.get_skill_level(_v_idx, skill_id))

			# 2) Fallback: global Skills autoload (if you still keep it)
			elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
				lv = int(Skills.get_skill_level(skill_id))

			if lv < level_req:
				return false

	# Material check: at least one craft
	return _max_craftable_count() > 0


func _max_craftable_count() -> int:
	# For summoning, we still compute max (for X clamp), but we only expose "Craft 1"
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		return 0

	var rec_v: Variant = _recipes[_selected_idx]
	if typeof(rec_v) != TYPE_DICTIONARY:
		return 0
	var rec: Dictionary = rec_v

	var inputs: Array = rec.get("inputs", []) as Array
	if inputs.is_empty():
		# If no inputs, treat as 1 for safety.
		return 1

	if typeof(Bank) == TYPE_NIL or not Bank.has_method("amount"):
		return 0

	var max_count := 1_000_000_000
	for inp_v in inputs:
		if typeof(inp_v) != TYPE_DICTIONARY:
			continue
		var inp: Dictionary = inp_v
		var item_id := StringName(inp.get("item", &""))
		var qty_needed := int(inp.get("qty", 0))
		if String(item_id) == "" or qty_needed <= 0:
			continue

		var have := int(Bank.amount(item_id))
		if have <= 0:
			return 0

		# Integer “how many crafts possible from this one ingredient”.
		var possible: int = int(have / qty_needed)
		if possible < max_count:
			max_count = possible

	if max_count == 1_000_000_000:
		return 0

	return max_count


func _parse_x_input() -> int:
	if _x_input == null:
		return 1
	var text := _x_input.text.strip_edges()
	if text == "":
		return 1
	var n := int(text)
	if n <= 0:
		return 0
	return n


func _update_start_button_state() -> void:
	var can1 := _can_craft_selected()
	var max_count := 0
	if can1:
		max_count = _max_craftable_count()

	# Summoning OR Mining: only show the single button
	if _is_summon or _job == &"mining":
		if _x_input:
			_x_input.visible = false
		if _craft_x_btn:
			_craft_x_btn.visible = false
			_craft_x_btn.disabled = true
		if _craft_all_btn:
			_craft_all_btn.visible = false
			_craft_all_btn.disabled = true

		if _craft_1_btn:
			_craft_1_btn.disabled = not can1
		return

	# Forge mode (normal multi-craft)
	if _x_input:
		_x_input.visible = true

	if _craft_1_btn:
		_craft_1_btn.disabled = not can1

	if _craft_x_btn:
		_craft_x_btn.visible = true
		_craft_x_btn.disabled = not can1

	if _craft_all_btn:
		_craft_all_btn.visible = true
		_craft_all_btn.disabled = (not can1 or max_count <= 1)


func _start_craft(count: int) -> void:
	if count <= 0:
		return
	if not _can_craft_selected():
		return
	if _selected_idx < 0 or _selected_idx >= _recipes.size():
		return

	var rec_v: Variant = _recipes[_selected_idx]
	if typeof(rec_v) != TYPE_DICTIONARY:
		return

	var rec: Dictionary = rec_v
	var recipe_id := StringName(rec.get("id", &""))

	# For tiered construction recipes, embed tier in the id:
	# e.g. "frame" + tier 3 -> "frame:t3"
	if _job == &"construction" and _has_real_tiers_for_recipe(rec) and _selected_tier > 0:
		var id_str := String(recipe_id)
		# Only append :tX if the id doesn’t already carry a tier
		if id_str.find(":") == -1:
			var tiered_id := "%s:t%d" % [id_str, _selected_tier]
			recipe_id = StringName(tiered_id)

	if typeof(VillagerManager) != TYPE_NIL:
		if VillagerManager.has_method("assign_job_with_recipe") and recipe_id != StringName():
			VillagerManager.assign_job_with_recipe(_v_idx, _job, _ax, recipe_id, count, false)
		elif VillagerManager.has_method("assign_job_at"):
			VillagerManager.assign_job_at(_v_idx, _job, _ax)
		elif VillagerManager.has_method("assign_job"):
			VillagerManager.assign_job(_v_idx, _job)

	queue_free()
