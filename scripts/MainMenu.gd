# MainMenu.gd
extends Control

@export var background_image: Texture2D
@export var title_text: String = "Hamlet: Rise of the Village"
@export var play_music: bool = false
@export var music_stream: AudioStream

# --- Main menu nodes (explicit $ where guaranteed, else null-safe) ---
@onready var bg: TextureRect            = $Background
@onready var dim: ColorRect             = $Dim
@onready var panel: PanelContainer      = $MenuPanel
@onready var vbox: VBoxContainer        = $MenuPanel/VBox

@onready var new_btn: Button            = $MenuPanel/VBox/NewButton
@onready var cont_btn: Button           = $MenuPanel/VBox/ContinueButton
@onready var load_btn: Button           = $MenuPanel/VBox/LoadButton
@onready var settings_btn: Button       = $MenuPanel/VBox/SettingsButton
@onready var quit_btn: Button           = $MenuPanel/VBox/QuitButton

# Use null-safe lookups for nodes that may be elsewhere/renamed in your scene:
@onready var title_lbl: Label           = get_node_or_null(^"Title") as Label
@onready var version_lbl: Label         = get_node_or_null(^"Version") as Label
@onready var latest_lbl: Label          = get_node_or_null(^"LatestSave") as Label
@onready var music: AudioStreamPlayer   = get_node_or_null(^"Music") as AudioStreamPlayer

# Overlay (merged in-scene panels) — null-safe as well
@onready var overlay: Control                 = get_node_or_null(^"Overlay") as Control
@onready var modal_dim: ColorRect             = get_node_or_null(^"Overlay/ModalDim") as ColorRect
@onready var load_panel: PanelContainer       = get_node_or_null(^"Overlay/LoadPanel") as PanelContainer
@onready var settings_panel: PanelContainer   = get_node_or_null(^"Overlay/SettingsPanel") as PanelContainer

var game_scene: PackedScene = preload("res://scenes/World.tscn")

# ----------- helper: autoload resolver (SaveLoad or SaveLoadData) ------------
func _SL() -> Node:
	var n: Node = get_node_or_null("/root/SaveLoad")
	if n != null:
		return n
	return get_node_or_null("/root/SaveLoadData")

func _ready() -> void:
	_sanity_log_missing()

	# Background & blockers
	if background_image and bg:
		bg.texture = background_image
	if bg:  bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim: dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel: panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Title & theming
	if title_lbl:
		title_lbl.text = title_text
	_apply_panel_style()

	# Wire buttons
	if quit_btn:     quit_btn.pressed.connect(_on_QuitButton_pressed)
	if new_btn:      new_btn.pressed.connect(_on_NewButton_pressed)
	if cont_btn:     cont_btn.pressed.connect(_on_ContinueButton_pressed)
	if load_btn:     load_btn.pressed.connect(_on_LoadButton_pressed)
	if settings_btn: settings_btn.pressed.connect(_on_SettingsButton_pressed)

	# Overlay defaults (hidden; hide both panels)
	if overlay:
		overlay.visible = false
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if modal_dim:
		modal_dim.visible = false
		modal_dim.mouse_filter = Control.MOUSE_FILTER_STOP
		modal_dim.color = Color(0, 0, 0, 0.5)
	if load_panel:
		load_panel.visible = false
		# LoadPanel signals → menu handlers
		if load_panel.has_signal("request_close"):
			load_panel.connect("request_close", Callable(self, "_close_overlay"))
		if load_panel.has_signal("load_slot"):
			load_panel.connect("load_slot", Callable(self, "_on_menu_load_slot"))
			
	if settings_panel:
		settings_panel.visible = false
		if settings_panel.has_signal("request_close"):
			settings_panel.connect("request_close", Callable(self, "_close_overlay"))

	# Buttons state (and react to save list changes)
	_update_buttons()
	var SL := _SL()
	if SL and SL.has_signal("saves_changed"):
		SL.connect("saves_changed", Callable(self, "_update_buttons"))

	# Footer
	if version_lbl:
		version_lbl.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1")
	if latest_lbl:
		latest_lbl.text = _latest_save_text()

	# Focus wiring (guarded)
	if new_btn:
		new_btn.grab_focus()
	if new_btn and cont_btn:
		new_btn.focus_neighbor_bottom = cont_btn.get_path()
		cont_btn.focus_neighbor_top   = new_btn.get_path()
	if cont_btn and load_btn:
		cont_btn.focus_neighbor_bottom = load_btn.get_path()
		load_btn.focus_neighbor_top    = cont_btn.get_path()
	if load_btn and settings_btn:
		load_btn.focus_neighbor_bottom = settings_btn.get_path()
		settings_btn.focus_neighbor_top = load_btn.get_path()
	if settings_btn and quit_btn:
		settings_btn.focus_neighbor_bottom = quit_btn.get_path()
		quit_btn.focus_neighbor_top        = settings_btn.get_path()

	# Music
	if play_music and music_stream and music:
		music.stream = music_stream
		music.play()

	# Fade-in
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)

# ---------- overlay helper (ensure only one panel is shown) ----------
func _show_overlay(which: Control) -> void:
	if not overlay or which == null:
		push_error("Overlay or target panel missing.")
		return

	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.position = Vector2.ZERO
	overlay.size = get_viewport().get_visible_rect().size
	overlay.visible = true

	if modal_dim:
		modal_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		modal_dim.position = Vector2.ZERO
		modal_dim.size = overlay.size
		modal_dim.visible = true

	# Hide both panels first, then show exactly one.
	if load_panel:     load_panel.visible = false
	if settings_panel: settings_panel.visible = false

	which.visible = true
	which.set_anchors_preset(Control.PRESET_CENTER)
	if which.has_method("open"):
		which.call_deferred("open")

# ---------- Buttons ----------
func _on_QuitButton_pressed() -> void:
	get_tree().quit()

func _on_NewButton_pressed() -> void:
	# Start a fresh grove: clear any pending loaded world so World.tscn boots clean.
	var GS := get_node_or_null("/root/GameState")
	if GS and GS.has_method("from_dict"):
		GS.call("from_dict", {})  # reset pending
	_change_to_game()

func _on_ContinueButton_pressed() -> void:
	var SL := _SL()
	if SL == null: return
	if not SL.has_method("latest_save_id"): return
	var id: String = SL.call("latest_save_id")
	if id != "" and SL.call("load_grove", id):
		_change_to_game()

func _on_LoadButton_pressed() -> void:
	_show_overlay(load_panel)

func _on_SettingsButton_pressed() -> void:
	_show_overlay(settings_panel)

# LoadPanel → MainMenu handler
func _on_menu_load_slot(id: String) -> void:
	var SL := _SL()
	if SL and SL.call("load_grove", id):
		_change_to_game()
	else:
		push_error("Failed to load: %s" % id)

# ---------- Overlay close ----------
func _close_overlay() -> void:
	if overlay: overlay.visible = false
	if modal_dim: modal_dim.visible = false
	if load_panel: load_panel.visible = false
	if settings_panel: settings_panel.visible = false

# ---------- Styling ----------
func _apply_panel_style() -> void:
	if not panel: return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.12, 0.82)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.35)
	panel.add_theme_stylebox_override("panel", sb)

	for b in [new_btn, cont_btn, load_btn, settings_btn, quit_btn]:
		if b:
			b.add_theme_constant_override("h_separation", 12)
			b.add_theme_constant_override("outline_size", 1)
			b.add_theme_font_size_override("font_size", 20)

	if title_lbl:
		title_lbl.add_theme_font_size_override("font_size", 28)

# ---------- Save UI ----------
func _update_buttons() -> void:
	var SL := _SL()
	var has: bool = false
	if SL:
		if SL.has_method("has_any_save"):
			has = bool(SL.call("has_any_save"))
		elif SL.has_method("list_saves"):
			var arr: Array = SL.call("list_saves") as Array
			has = arr.size() > 0

	if cont_btn:
		cont_btn.disabled = not has
	if load_btn:
		load_btn.disabled = false
	if latest_lbl:
		latest_lbl.text = _latest_save_text()

func _latest_save_text() -> String:
	var SL := _SL()
	if SL == null:
		return "No saves"
	# Try using latest_save_id() first
	if SL.has_method("latest_save_id"):
		var id: String = SL.call("latest_save_id")
		if id == "":
			return "No saves"
		# find timestamp for that id
		var saves: Array = (SL.call("list_saves") if SL.has_method("list_saves") else []) as Array
		for s_var in saves:
			var d: Dictionary = s_var as Dictionary
			if String(d.get("id","")) == id:
				var t: int = int(d.get("timestamp", 0))
				var when: String = (Time.get_datetime_string_from_unix_time(t) if t > 0 else "Unknown")
				return "Latest: %s — %s" % [id, when]
		return "Latest: %s" % id
	# Fallback: list only
	if SL.has_method("list_saves"):
		var ls: Array = SL.call("list_saves") as Array
		return "No saves" if ls.is_empty() else "Latest: %s" % String((ls[0] as Dictionary).get("id",""))
	return "No saves"

# ---------- Scene change ----------
func _change_to_game() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(Callable(self, "_go_game"))

func _go_game() -> void:
	get_tree().change_scene_to_packed(game_scene)

# ---------- Sanity helper ----------
func _sanity_log_missing() -> void:
	var missing := []
	if bg == null: missing.append("Background")
	if dim == null: missing.append("Dim")
	if panel == null: missing.append("MenuPanel")
	if vbox == null: missing.append("MenuPanel/VBox")
	if new_btn == null: missing.append("MenuPanel/VBox/NewButton")
	if cont_btn == null: missing.append("MenuPanel/VBox/ContinueButton")
	if load_btn == null: missing.append("MenuPanel/VBox/LoadButton")
	if settings_btn == null: missing.append("MenuPanel/VBox/SettingsButton")
	if quit_btn == null: missing.append("MenuPanel/VBox/QuitButton")
	if overlay == null: missing.append("Overlay")
	if modal_dim == null: missing.append("Overlay/ModalDim")
	if load_panel == null: missing.append("Overlay/LoadPanel")
	if settings_panel == null: missing.append("Overlay/SettingsPanel")
	if not missing.is_empty():
		push_error("MainMenu missing nodes: " + ", ".join(missing))
