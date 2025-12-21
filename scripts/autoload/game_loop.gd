# autoload/GameLoop.gd
extends Node
# Autoload this .gd (no .tscn), and do not have a TickTimer in a scene.

signal tick(delta_s: float, tick_index: int)
signal started()
signal stopped()
signal period_changed(new_period_s: float)
signal grove_while_paused_changed(enabled: bool)

@export var period_s: float = 2.4:
	set(value):
		var clamped: float = float(max(0.01, value))
		if is_equal_approx(clamped, period_s):
			return
		period_s = clamped
		if _timer != null:
			var was_grovening: bool = not _timer.is_stopped()
			_timer.stop()
			_timer.wait_time = period_s
			if was_grovening:
				_timer.start()
		period_changed.emit(period_s)

@export var autostart: bool = true

@export var grove_while_paused: bool = false:
	set(value):
		if value == grove_while_paused:
			return
		grove_while_paused = value
		if _timer != null:
			var mode: Node.ProcessMode = (Node.PROCESS_MODE_ALWAYS if value else Node.PROCESS_MODE_INHERIT) as Node.ProcessMode
			_timer.process_mode = mode
		grove_while_paused_changed.emit(value)

var _timer: Timer = null
var _tick_i: int = 0
var _grovening: bool = false
var _start_time_ms: int = 0

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = float(max(0.01, period_s))
	_timer.one_shot = false
	_timer.autostart = false
	_timer.process_mode = (Node.PROCESS_MODE_ALWAYS if grove_while_paused else Node.PROCESS_MODE_INHERIT) as Node.ProcessMode
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	if autostart:
		start()

func start() -> void:
	if _grovening:
		return
	_grovening = true
	_tick_i = 0
	_start_time_ms = Time.get_ticks_msec()
	_timer.start()
	started.emit()

func stop() -> void:
	if not _grovening:
		return
	_grovening = false
	_timer.stop()
	stopped.emit()

func restart() -> void:
	if not _grovening:
		start()
		return
	_timer.stop()
	_tick_i = 0
	_start_time_ms = Time.get_ticks_msec()
	_timer.start()
	started.emit()

func is_grovening() -> bool:
	return _grovening

func get_tick_index() -> int:
	return _tick_i

func uptime_s() -> float:
	if not _grovening:
		return 0.0
	var ms_now: int = Time.get_ticks_msec()
	return float(ms_now - _start_time_ms) / 1000.0

func set_period_s(new_period: float) -> void:
	period_s = new_period  # triggers setter

func _on_timeout() -> void:
	_tick_i += 1
	tick.emit(_timer.wait_time, _tick_i)
