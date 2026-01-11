extends Control

signal request_place(index: int)
signal request_details(index: int)

var _root_vbox: VBoxContainer = null
var _rows_vbox: VBoxContainer = null
var _place_btn: Button = null
var _details_btn: Button = null

var _rows: Array[Button] = []
var _selected_index: int = -1

# Realtime job animation: v_idx -> { "start_time": float, "duration": float }
var _job_anim: Dictionary = {}
var _repeat_job: Dictionary = {}

var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_row_index: int = -1
var _dragging: bool = false
const DRAG_THRESHOLD := 8.0

# Map job ids -> skill ids (for icons)
# Add the ones you actually use. Fallback logic below covers the rest.
const JOB_SKILL_ID := {
	&"scrying":      "scrying",
	&"astromancy":   "astromancy",
	&"chop":         "woodcutting",
	&"mine":         "mining",
	&"fish":         "fishing",
	&"herbalism":    "herbalism",
	&"forage":       "herbalism",
	&"cook":         "cooking",
	&"smith":        "smithing",
	&"tailor":       "tailoring",
	&"construct":    "construction",
	&"farm":         "farming",
}

# Layout constants so alignment is identical for every row
const PORTRAIT_SIZE := Vector2(80, 80)
const ICON_SIZE := Vector2(48, 48)
const BAR_SIZE := Vector2(160, 20)
const CANCEL_SIZE := Vector2(24, 24)
const STATUS_GAP := 8.0

# Popup text: allow wrapping without growing forever
const POPUP_LINES := 2
const POPUP_LINE_H := 16
const POPUP_PANEL_H := 6 + POPUP_LINES * POPUP_LINE_H  # padding + lines


func _ready() -> void:
	_build_layout()
	_wire_signals()
	_rebuild_rows()
	set_process(true)


# ---------------------------------------------------------
# Layout: scrollable rows + buttons
# ---------------------------------------------------------
func _build_layout() -> void:
	for c in get_children():
		c.queue_free()

	var vb := VBoxContainer.new()
	vb.name = "MainVBox"
	vb.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vb)
	_root_vbox = vb

	var title := Label.new()
	title.text = "Villagers"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	_root_vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.clip_contents = true
	_root_vbox.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	_rows_vbox = rows

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	buttons.add_theme_constant_override("separation", 4)
	_root_vbox.add_child(buttons)

	var place_btn := Button.new()
	place_btn.name = "PlaceBtn"
	place_btn.text = "Place"
	place_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(place_btn)
	_place_btn = place_btn

	var details_btn := Button.new()
	details_btn.name = "DetailsBtn"
	details_btn.text = "Details"
	details_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(details_btn)
	_details_btn = details_btn


# ---------------------------------------------------------
# Wiring signals
# ---------------------------------------------------------
func _wire_signals() -> void:
	if _place_btn:
		_place_btn.pressed.connect(func() -> void:
			if _selected_index >= 0:
				request_place.emit(_selected_index)
		)

	if _details_btn:
		_details_btn.pressed.connect(func() -> void:
			if _selected_index >= 0:
				request_details.emit(_selected_index)
		)

	if typeof(Villagers) != TYPE_NIL:
		if Villagers.has_signal("list_changed") and not Villagers.list_changed.is_connected(_on_villagers_list_changed):
			Villagers.list_changed.connect(_on_villagers_list_changed)
		if Villagers.has_signal("selected_changed") and not Villagers.selected_changed.is_connected(_on_villager_selected_changed):
			Villagers.selected_changed.connect(_on_villager_selected_changed)

	if typeof(VillagerManager) != TYPE_NIL:
		if VillagerManager.has_signal("job_progress") and not VillagerManager.job_progress.is_connected(_on_job_progress):
			VillagerManager.job_progress.connect(_on_job_progress)
		if VillagerManager.has_signal("job_completed") and not VillagerManager.job_completed.is_connected(_on_job_completed):
			VillagerManager.job_completed.connect(_on_job_completed)


# ---------------------------------------------------------
# Rebuild list from Villagers
# ---------------------------------------------------------
func _rebuild_rows() -> void:
	if _rows_vbox == null:
		return

	for r in _rows:
		if is_instance_valid(r):
			r.queue_free()
	_rows.clear()

	var arr: Array = []
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("as_list"):
		arr = Villagers.as_list()

	for i in range(arr.size()):
		var data_v: Variant = arr[i]
		var dict: Dictionary = {}
		if data_v is Dictionary:
			dict = data_v as Dictionary
		_add_row(i, dict)

	var sel_idx: int = -1
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_selected_index"):
		sel_idx = int(Villagers.get_selected_index())
	_set_selected(sel_idx)


# ---------------------------------------------------------
# Row layout:
# [ Portrait ] [ Name .................. ][  Icon | Bar | X ]   (fixed status block)
#                   [ popup text (wraps) ]
# ---------------------------------------------------------
func _add_row(v_idx: int, data: Dictionary) -> void:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.clip_text = false
	btn.custom_minimum_size = Vector2(0, 112)

	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_theme_constant_override("separation", 12)
	btn.add_child(h)

	# Portrait
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(portrait)
	_set_villager_portrait(portrait, v_idx, data)

	# Right side VBox
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 2)
	h.add_child(right)

	# Top row
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_theme_constant_override("separation", 8)
	right.add_child(top_row)

	# Name (clipped/ellipsized so it doesn't affect alignment unpredictably)
	var name_lbl := Label.new()
	var name_text: String = String(data.get("name", "Villager %d" % v_idx))
	name_lbl.text = name_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.clip_text = true
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(name_lbl)

	# FIX: status block has fixed width, so icon/bar never “creep”
	var status := HBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_SHRINK_END
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_theme_constant_override("separation", int(STATUS_GAP))
	status.custom_minimum_size = Vector2(
		ICON_SIZE.x + STATUS_GAP + BAR_SIZE.x + STATUS_GAP + CANCEL_SIZE.x,
		max(ICON_SIZE.y, BAR_SIZE.y)
	)
	top_row.add_child(status)

	# Icon
	var job_icon := TextureRect.new()
	job_icon.custom_minimum_size = ICON_SIZE
	job_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	job_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	job_icon.visible = false
	job_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # IMPORTANT: don't break drag
	status.add_child(job_icon)

	# Progress bar (ratio 0..1 always => no jump from changing max_value)
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.value = 0.0
	progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.custom_minimum_size = BAR_SIZE
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE  # IMPORTANT: don't break drag
	status.add_child(progress)

	# Cancel button stays clickable
	var cancel_btn := Button.new()
	cancel_btn.text = "X"
	cancel_btn.tooltip_text = "Cancel job"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel_btn.custom_minimum_size = CANCEL_SIZE
	cancel_btn.visible = false
	cancel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	status.add_child(cancel_btn)

	# Popup panel under the row (wrap to avoid going off-screen)
	var popup_panel := PanelContainer.new()
	popup_panel.name = "PopupPanel"
	popup_panel.visible = true
	popup_panel.modulate = Color(1, 1, 1, 0)
	popup_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	popup_panel.custom_minimum_size = Vector2(0, POPUP_PANEL_H)
	right.add_child(popup_panel)

	var popup_margin := MarginContainer.new()
	popup_margin.add_theme_constant_override("margin_left", 4)
	popup_margin.add_theme_constant_override("margin_right", 4)
	popup_margin.add_theme_constant_override("margin_top", 2)
	popup_margin.add_theme_constant_override("margin_bottom", 2)
	popup_panel.add_child(popup_margin)

	var popup_label := Label.new()
	popup_label.text = ""
	popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_label.clip_text = true
	popup_label.max_lines_visible = POPUP_LINES
	popup_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	popup_label.add_theme_font_size_override("font_size", 13)
	popup_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	popup_label.custom_minimum_size = Vector2(0, POPUP_LINES * POPUP_LINE_H)
	popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_margin.add_child(popup_label)

	# Cancel logic
	cancel_btn.pressed.connect(func() -> void:
		_repeat_job[v_idx] = false
		if _job_anim.has(v_idx):
			_job_anim.erase(v_idx)

		progress.value = 0.0
		progress.modulate = Color(1, 1, 1, 0.35)

		job_icon.texture = null
		job_icon.visible = false

		cancel_btn.disabled = true
		cancel_btn.modulate = Color(1, 1, 1, 0.0)

		popup_label.text = ""
		popup_panel.modulate = Color(1, 1, 1, 0.0)

		if typeof(VillagerManager) != TYPE_NIL and VillagerManager.has_method("stop_job"):
			VillagerManager.stop_job(v_idx)
	)

	# Store refs
	btn.set_meta("v_idx", v_idx)
	btn.set_meta("portrait", portrait)
	btn.set_meta("job_icon", job_icon)
	btn.set_meta("progress", progress)
	btn.set_meta("name_lbl", name_lbl)
	btn.set_meta("cancel_btn", cancel_btn)
	btn.set_meta("popup_panel", popup_panel)
	btn.set_meta("popup_label", popup_label)

	btn.pressed.connect(func() -> void:
		_on_row_pressed(btn)
	)

	btn.gui_input.connect(func(event: InputEvent) -> void:
		_on_row_gui_input(v_idx, event)
	)

	_rows_vbox.add_child(btn)
	_rows.append(btn)

	_repeat_job[v_idx] = true


# ---------------------------------------------------------
# Portrait helper
# ---------------------------------------------------------
func _set_villager_portrait(node: TextureRect, v_idx: int, data: Dictionary) -> void:
	if node == null:
		return

	var tex_path: String = ""
	if data.has("icon"):
		tex_path = String(data["icon"])
	elif typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_icon_path"):
		tex_path = String(Villagers.get_icon_path(v_idx))

	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex := load(tex_path)
		if tex is Texture2D:
			node.texture = tex


# ---------------------------------------------------------
# Selection handling
# ---------------------------------------------------------
func _on_row_pressed(btn: Button) -> void:
	var v_idx: int = int(btn.get_meta("v_idx", -1))
	if v_idx < 0:
		return

	_set_selected(v_idx)

	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("set_selected"):
		Villagers.set_selected(v_idx)

func _set_selected(idx: int) -> void:
	_selected_index = idx
	for r in _rows:
		var b: Button = r
		if b == null:
			continue
		var v_idx: int = int(b.get_meta("v_idx", -1))
		b.button_pressed = (v_idx == idx)

func _on_row_gui_input(v_idx: int, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_drag_row_index = v_idx
			_drag_start_pos = mb.position
			_dragging = false
		else:
			_drag_row_index = -1
			_dragging = false

	elif event is InputEventMouseMotion and _drag_row_index == v_idx:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		var mm := event as InputEventMouseMotion
		if not _dragging:
			var dist := (mm.position - _drag_start_pos).length()
			if dist >= DRAG_THRESHOLD:
				_start_drag_villager(v_idx)

func _start_drag_villager(v_idx: int) -> void:
	_dragging = true

	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("set_selected"):
		Villagers.set_selected(v_idx)

	if typeof(DragState) != TYPE_NIL and DragState.has_method("begin"):
		DragState.begin(v_idx)

func _on_villagers_list_changed() -> void:
	_rebuild_rows()

func _on_villager_selected_changed(i: int) -> void:
	_set_selected(i)

func _refresh() -> void:
	_rebuild_rows()


# ---------------------------------------------------------
# Job progress / completion
# ---------------------------------------------------------
func _on_job_progress(v_idx: int, job: StringName, elapsed: float, duration: float) -> void:
	var should_repeat := false
	match job:
		&"scrying":
			should_repeat = true
		_:
			should_repeat = false
	_repeat_job[v_idx] = should_repeat

	var row: Button = _get_row_for(v_idx)
	if row == null:
		return

	var progress: ProgressBar = row.get_meta("progress") as ProgressBar
	var job_icon: TextureRect = row.get_meta("job_icon") as TextureRect
	var cancel_btn: Button = row.get_meta("cancel_btn") as Button

	var dur: float = maxf(duration, 0.001)
	var ratio: float = clampf(elapsed / dur, 0.0, 1.0)

	if progress:
		progress.visible = true
		progress.value = ratio
		progress.modulate = Color(1, 1, 1, 1)

	if job_icon:
		_set_job_icon(job_icon, job)

	if cancel_btn:
		cancel_btn.visible = true
		cancel_btn.disabled = false
		cancel_btn.modulate = Color(1, 1, 1, 1)

	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_job_anim[v_idx] = {
		"start_time": now - elapsed,
		"duration": dur,
	}

func _on_job_completed(v_idx: int, job: StringName, xp: int, loot_desc: String) -> void:
	var row: Button = _get_row_for(v_idx)
	if row == null:
		return

	var progress: ProgressBar = row.get_meta("progress") as ProgressBar
	var job_icon: TextureRect = row.get_meta("job_icon") as TextureRect
	var cancel_btn: Button = row.get_meta("cancel_btn") as Button
	var popup_panel: PanelContainer = row.get_meta("popup_panel") as PanelContainer
	var popup_label: Label = row.get_meta("popup_label") as Label

	if progress:
		progress.value = 1.0
		progress.modulate = Color(1, 1, 1, 1)

	if job_icon:
		job_icon.visible = (job_icon.texture != null)

	if cancel_btn:
		cancel_btn.disabled = true
		cancel_btn.modulate = Color(1, 1, 1, 0.0)

	if _job_anim.has(v_idx):
		_job_anim.erase(v_idx)

	if popup_panel and popup_label:
		var villager_name: String = "Villager %d" % v_idx
		if typeof(Villagers) != TYPE_NIL and Villagers.has_method("as_list"):
			var arr: Array = Villagers.as_list()
			if v_idx >= 0 and v_idx < arr.size():
				var d_v: Variant = arr[v_idx]
				if d_v is Dictionary:
					villager_name = String((d_v as Dictionary).get("name", villager_name))

		var job_str: String = String(job)
		var loot_part: String = ((" – " + loot_desc) if loot_desc != "" else "")
		popup_label.text = "%s finished %s: +%d XP%s" % [villager_name, job_str.capitalize(), xp, loot_part]
		popup_panel.modulate = Color(1, 1, 1, 1)

		var timer: Timer = popup_panel.get_node_or_null("HideTimer") as Timer
		if timer == null:
			timer = Timer.new()
			timer.name = "HideTimer"
			timer.one_shot = true
			timer.wait_time = 3.0
			popup_panel.add_child(timer)
			timer.timeout.connect(func() -> void:
				popup_label.text = ""
				popup_panel.modulate = Color(1, 1, 1, 0)
			)
		timer.start()

	var repeat := bool(_repeat_job.get(v_idx, false))
	if job == &"astromancy":
		repeat = false
	if xp <= 0:
		repeat = false
	_repeat_job[v_idx] = repeat

	if repeat and typeof(VillagerManager) != TYPE_NIL:
		var ax := Vector2i.ZERO
		if VillagerManager.has_method("get_job_state"):
			var st: Dictionary = VillagerManager.get_job_state(v_idx)
			if st.has("ax"):
				ax = st["ax"]

		if VillagerManager.has_method("assign_job_at"):
			call_deferred("_restart_job_at", v_idx, job, ax)
		elif VillagerManager.has_method("assign_job"):
			call_deferred("_restart_job_simple", v_idx, job)


func _restart_job_at(v_idx: int, job: StringName, ax: Vector2i) -> void:
	if typeof(VillagerManager) != TYPE_NIL and VillagerManager.has_method("assign_job_at"):
		VillagerManager.assign_job_at(v_idx, job, ax)

func _restart_job_simple(v_idx: int, job: StringName) -> void:
	if typeof(VillagerManager) != TYPE_NIL and VillagerManager.has_method("assign_job"):
		VillagerManager.assign_job(v_idx, job)


func _process(_delta: float) -> void:
	if _job_anim.is_empty():
		return

	var now: float = float(Time.get_ticks_msec()) / 1000.0
	for k in _job_anim.keys():
		_update_job_bar_for(int(k), now)

func _update_job_bar_for(v_idx: int, now: float) -> void:
	if not _job_anim.has(v_idx):
		return

	var info: Dictionary = _job_anim[v_idx]
	var start_time: float = float(info.get("start_time", now))
	var duration: float = maxf(float(info.get("duration", 0.001)), 0.001)

	var elapsed: float = clampf(now - start_time, 0.0, duration)
	var ratio: float = clampf(elapsed / duration, 0.0, 1.0)

	var row: Button = _get_row_for(v_idx)
	if row == null:
		return

	var progress: ProgressBar = row.get_meta("progress") as ProgressBar
	if progress:
		progress.value = ratio


func _get_row_for(v_idx: int) -> Button:
	for r in _rows:
		var b: Button = r
		if b == null:
			continue
		if int(b.get_meta("v_idx", -1)) == v_idx:
			return b
	return null


# --- Icon resolution that matches your SkillCell approach ---
func _set_job_icon(node: TextureRect, job: StringName) -> void:
	if node == null:
		return

	var skill_id: String = _resolve_skill_id_for_job(job)
	if skill_id == "":
		node.visible = false
		node.texture = null
		return

	# Same source of truth as SkillCell: Skills.get_by_id(id) -> { icon = "res://..." }
	if typeof(Skills) == TYPE_NIL or not Skills.has_method("get_by_id"):
		node.visible = false
		node.texture = null
		return

	var rec: Dictionary = Skills.get_by_id(skill_id)
	var icon_path: String = String(rec.get("icon", ""))

	if icon_path == "" or not ResourceLoader.exists(icon_path):
		node.visible = false
		node.texture = null
		return

	var tex := load(icon_path)
	if tex is Texture2D:
		node.texture = tex
		node.visible = true
	else:
		node.texture = null
		node.visible = false


func _resolve_skill_id_for_job(job: StringName) -> String:
	# 1) Explicit mapping
	var mapped: String = String(JOB_SKILL_ID.get(job, ""))
	if mapped != "":
		return mapped

	# 2) Fallback: if job name itself is a skill id (this is what you want for herbalism etc.)
	var cand: String = String(job)
	if cand != "" and typeof(Skills) != TYPE_NIL and Skills.has_method("get_by_id"):
		var rec: Dictionary = Skills.get_by_id(cand)
		if not rec.is_empty():
			return cand

	return ""
