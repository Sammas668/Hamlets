extends Control

# ---- Authoring fields (fill these in Inspector) ----
@export var title: String = ""
@export_multiline var body_bbcode: String = ""
# Even-length list: ["Key","Value","Key2","Value2", ...]
@export var kv: Array[String] = []

# Optional behavior knobs
@export var show_delay_s: float = 0.0     # e.g. 0.15 to feel like Old World
@export var lock_on_left_click: bool = true

# ---- Internal ----
var _data: Dictionary
var _hovering: bool = false
var _delay_t: float = 0.0

func _ready() -> void:
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	gui_input.connect(_on_gui_input)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rebuild_dict()

	# Ensure we actually receive mouse input
	mouse_filter = Control.MOUSE_FILTER_PASS  # or STOP; PASS lets children handle too

func _process(dt: float) -> void:
	if _hovering and show_delay_s > 0.0:
		_delay_t += dt
		if _delay_t >= show_delay_s:
			_show_now()
			_hovering = false  # we’ve done the delayed show

# Rebuild data from Inspector fields (call this if you change fields at grovetime)
func _rebuild_dict() -> void:
	var pairs: Array = []
	for i in range(0, kv.size(), 2):
		var k: String = kv[i]
		var v: String = kv[i + 1] if (i + 1) < kv.size() else ""
		pairs.append([k, v])
	_data = {
		"title": title,
		"body_bbcode": body_bbcode,
		"kv": pairs
	}

# Public helper if you want to set content from code
func set_tooltip_content(p_title: String, p_body_bbcode: String, p_kv_pairs: Array) -> void:
	title = p_title
	body_bbcode = p_body_bbcode
	kv = []
	for p in p_kv_pairs:
		# Expecting [["Key","Val"], ["K2","V2"], ...]
		if p.size() >= 2:
			kv.append(str(p[0]))
			kv.append(str(p[1]))
	_rebuild_dict()

# ------------- signal handlers -------------

func _on_enter() -> void:
	_hovering = true
	_delay_t = 0.0
	if show_delay_s <= 0.0:
		_show_now()

func _on_exit() -> void:
	_hovering = false
	_delay_t = 0.0
	var tt := get_tree().root.get_node_or_null("Tooltip")
	if tt:
		tt.call("maybe_hide")

func _on_gui_input(event: InputEvent) -> void:
	if lock_on_left_click and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tt := get_tree().root.get_node_or_null("Tooltip")
		if tt:
			tt.call("lock")

# ------------- helpers -------------

func _show_now() -> void:
	var tt := get_tree().root.get_node_or_null("Tooltip")
	if tt:
		tt.call("request_for_control", self, _data)
