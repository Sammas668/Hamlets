extends Panel

@onready var _title  : Label         = $Content/Title
@onready var _body   : RichTextLabel = $Content/Body
@onready var _kv     : GridContainer = $Content/KV
@onready var _sub    : Panel         = $SubTip
@onready var _subtxt : RichTextLabel = $SubTip/SubBody

var locked: bool = false

func _ready() -> void:
	visible = false
	_sub.visible = false
	_body.bbcode_enabled = true
	_subtxt.bbcode_enabled = true
	_body.meta_hover_started.connect(_on_meta_hover_started)
	_body.meta_hover_ended.connect(_on_meta_hover_ended)

func set_data(data: Dictionary) -> void:
	_title.text = data.get("title", "")
	_body.clear()
	_body.append_text(str(data.get("body_bbcode", "")))

	# rebuild key/value pairs
	for c in _kv.get_children():
		c.queue_free()
	var pairs: Array = data.get("kv", [])
	for p in pairs:
		var k := Label.new(); k.text = str(p[0])
		var v := Label.new(); v.text = str(p[1])
		_kv.add_child(k); _kv.add_child(v)

	reset_size()

func show_panel() -> void: visible = true
func hide_panel() -> void:
	visible = false
	_sub.visible = false
	locked = false
func lock() -> void: locked = true
func unlock() -> void: locked = false

func set_subtip(text_bbcode: String, anchor: Vector2) -> void:
	_subtxt.clear()
	_subtxt.append_text(text_bbcode)
	_sub.visible = true
	_sub.global_position = anchor + Vector2(8, 8)

func hide_subtip() -> void:
	_sub.visible = false

func _on_meta_hover_started(meta: Variant) -> void:
	if typeof(meta) == TYPE_STRING and str(meta).begins_with("sub:"):
		Tooltip.request_subtip(str(meta).substr(4), self)

func _on_meta_hover_ended(meta: Variant) -> void:
	if typeof(meta) == TYPE_STRING and str(meta).begins_with("sub:"):
		Tooltip.hide_subtip()  # <-- no argument
		
func is_locked() -> bool:
	return locked
