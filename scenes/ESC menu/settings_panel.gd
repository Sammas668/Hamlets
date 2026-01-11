# SettingsPanel.gd
extends PanelContainer
signal request_close

const CONFIG_PATH := "user://settings.cfg"

# --- Node refs ---
@onready var mode_opt:    OptionButton = $Margin/VBox/ModeRow/ModeOption
@onready var monitor_opt: OptionButton = $Margin/VBox/MonRow/MonOption
@onready var res_opt:     OptionButton = $Margin/VBox/ResRow/ResOption
@onready var vsync_ck:    CheckBox     = $Margin/VBox/VSyncRow/VSyncCheck
@onready var fps_spin:    SpinBox      = $Margin/VBox/FpsRow/FpsSpin
@onready var vol_slider:  HSlider      = $Margin/VBox/VolRow/VolSlider
@onready var apply_btn:   Button       = $Margin/VBox/Buttons/ApplyBtn
@onready var close_btn:   Button       = $Margin/VBox/Buttons/CloseBtn



# Common PC resolutions (edit as you like)
var _res_list: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

# Display mode indices
enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }

# Add at top
@export var respect_inspector_layout := true

func _ready() -> void:
	if not respect_inspector_layout:
		set_anchors_preset(Control.PRESET_CENTER)
		custom_minimum_size = Vector2(640, 420)
	_populate_mode()
	_populate_monitors()
	_populate_resolutions()
	apply_btn.pressed.connect(_on_apply)
	close_btn.pressed.connect(func(): emit_signal("request_close"))
	_load_from_disk()

func open() -> void:
	visible = true
	await get_tree().process_frame
	grab_focus()

# ------- UI fill -------

func _populate_mode() -> void:
	mode_opt.clear()
	mode_opt.add_item("Windowed", Mode.WINDOWED)
	mode_opt.add_item("Borderless", Mode.BORDERLESS)
	mode_opt.add_item("Fullscreen", Mode.FULLSCREEN)

func _populate_monitors() -> void:
	monitor_opt.clear()
	var count: int = DisplayServer.get_screen_count()
	var primary: int = DisplayServer.get_primary_screen()
	for i in range(count):
		var sz: Vector2i = DisplayServer.screen_get_size(i)
		var label: String = "Monitor %d — %dx%d%s" % [
			i, sz.x, sz.y, (" (Primary)" if i == primary else "")
		]
		monitor_opt.add_item(label, i)

func _populate_resolutions() -> void:
	res_opt.clear()
	for r in _res_list:
		res_opt.add_item("%dx%d" % [r.x, r.y])

# ------- Apply / Save / Load -------

func _on_apply() -> void:
	var mode_id: int = mode_opt.get_selected_id()
	var mon_id: int = monitor_opt.get_selected_id()
	var res: Vector2i = _selected_resolution()
	var vsync_on: bool = vsync_ck.button_pressed
	var fps_cap: int = int(fps_spin.value)
	var vol: float = float(vol_slider.value) # 0..100

	_apply_display_mode(mode_id, mon_id)
	_apply_resolution(res, mon_id)
	_apply_vsync(vsync_on)
	_apply_fps_cap(fps_cap)
	_apply_master_volume(vol)

	_save_to_disk(mode_id, mon_id, res, vsync_on, fps_cap, vol)

func _save_to_disk(mode_id: int, mon_id: int, res: Vector2i, vsync_on: bool, fps_cap: int, vol: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "mode", mode_id)
	cfg.set_value("display", "monitor", mon_id)
	cfg.set_value("display", "width", res.x)
	cfg.set_value("display", "height", res.y)
	cfg.set_value("display", "vsync", vsync_on)
	cfg.set_value("display", "fps_cap", fps_cap)
	cfg.set_value("audio",   "master_volume", vol) # 0..100 linear
	var err: int = cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("Settings: failed to save to %s" % CONFIG_PATH)

func _load_from_disk() -> void:
	var cfg := ConfigFile.new()
	var _err: int = cfg.load(CONFIG_PATH)

	var default_mon: int = DisplayServer.get_primary_screen()
	var mode_id: int = int(cfg.get_value("display", "mode", Mode.WINDOWED))
	var mon_id: int = int(cfg.get_value("display", "monitor", default_mon))
	var w: int = int(cfg.get_value("display", "width", 1280))
	var h: int = int(cfg.get_value("display", "height", 720))
	var vsync_on: bool = bool(cfg.get_value("display", "vsync", true))
	var fps_cap: int = int(cfg.get_value("display", "fps_cap", 0))
	var vol: float = float(cfg.get_value("audio", "master_volume", 100.0))

	var mon_count: int = DisplayServer.get_screen_count()
	if mon_id < 0 or mon_id >= mon_count:
		mon_id = min(default_mon, max(mon_count - 1, 0))

	_select_mode_safely(mode_id)
	_select_monitor_safely(mon_id)
	_select_resolution_closest(Vector2i(w, h))

	vsync_ck.button_pressed = vsync_on
	fps_spin.min_value = 0
	fps_spin.max_value = 500
	fps_spin.step = 10
	fps_spin.value = fps_cap

	vol_slider.min_value = 0.0
	vol_slider.max_value = 100.0
	vol_slider.step = 1.0
	vol_slider.value = vol

	_apply_display_mode(mode_id, mon_id)
	_apply_resolution(Vector2i(w, h), mon_id)
	_apply_vsync(vsync_on)
	_apply_fps_cap(fps_cap)
	_apply_master_volume(vol)

# ------- Apply helpers -------

func _apply_display_mode(mode_id: int, screen: int) -> void:
	var win: Window = get_window()
	win.current_screen = screen

	match mode_id:
		Mode.WINDOWED:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
		Mode.BORDERLESS:
			win.mode = Window.MODE_WINDOWED
			win.borderless = true
			var origin: Vector2i = DisplayServer.screen_get_position(screen)
			var mon_size: Vector2i = DisplayServer.screen_get_size(screen)   # renamed
			win.position = origin
			win.size = mon_size
		Mode.FULLSCREEN:
			win.borderless = false
			win.mode = Window.MODE_FULLSCREEN

func _apply_resolution(res: Vector2i, screen: int) -> void:
	var win: Window = get_window()
	if win.mode == Window.MODE_WINDOWED and not win.borderless:
		var origin: Vector2i = DisplayServer.screen_get_position(screen)
		var mon_size: Vector2i = DisplayServer.screen_get_size(screen)      # renamed
		var pos: Vector2i = origin + (mon_size - res) / 2
		win.size = res
		win.position = pos

func _apply_vsync(on: bool) -> void:
	var mode: int = DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _apply_fps_cap(cap: int) -> void:
	Engine.max_fps = max(cap, 0)

func _apply_master_volume(linear_0_100: float) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx == -1:
		push_warning("Audio bus 'Master' not found")
		return
	var lin: float = clampf(linear_0_100 / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(lin))

func linear_to_db(v: float) -> float:
	if v <= 0.00001:
		return -80.0
	return 20.0 * log(v) / log(10.0)

# ------- selection helpers -------

func _selected_resolution() -> Vector2i:
	var i: int = res_opt.get_selected()
	i = clampi(i, 0, _res_list.size() - 1)
	return _res_list[i]

func _select_mode_safely(mode_id: int) -> void:
	for i in range(mode_opt.item_count):
		if mode_opt.get_item_id(i) == mode_id:
			mode_opt.select(i)
			return
	mode_opt.select(0)

func _select_monitor_safely(mon_id: int) -> void:
	for i in range(monitor_opt.item_count):
		if monitor_opt.get_item_id(i) == mon_id:
			monitor_opt.select(i)
			return
	monitor_opt.select(0)

func _select_resolution_closest(target: Vector2i) -> void:
	var best_i: int = 0
	var best_d: float = 1e12
	for i in range(_res_list.size()):
		var r: Vector2i = _res_list[i]
		var d: float = (Vector2(r) - Vector2(target)).length()
		if d < best_d:
			best_d = d
			best_i = i
	res_opt.select(best_i)
