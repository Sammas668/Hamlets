extends PanelContainer
class_name SavePanel

signal request_close
signal saved(slot_id: String, label: String)

@export var slot_count: int = 8
@export var slot_prefix: String = "slot_"

@onready var name_edit: LineEdit               = $VBox/NameRow/NameEdit
@onready var grid: GridContainer               = $VBox/SlotsGrid
@onready var save_btn: Button                  = $VBox/Buttons/SaveButton
@onready var cancel_btn: Button                = $VBox/Buttons/CancelButton
@onready var confirm: ConfirmationDialog       = $VBox/ConfirmDialog
@onready var title_lbl: Label                  = $VBox/Title

var _selected_slot_id: String = ""
var _buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	_build_slot_buttons()
	_wire_buttons()
	_refresh()

	var SL := _SL()
	if SL and SL.has_signal("saves_changed"):
		SL.connect("saves_changed", Callable(self, "_refresh"))

func open(default_label: String = "") -> void:
	_refresh()
	name_edit.text = (default_label if default_label != "" else "Save " + Time.get_datetime_string_from_system().replace("T", " "))
	_selected_slot_id = ""
	_mark_selection("")
	visible = true
	await get_tree().process_frame
	name_edit.grab_focus()

func close() -> void:
	visible = false
	emit_signal("request_close")

func _wire_buttons() -> void:
	save_btn.pressed.connect(_on_save_pressed)
	cancel_btn.pressed.connect(close)
	confirm.canceled.connect(confirm.hide)
	confirm.confirmed.connect(_do_overwrite)

func _build_slot_buttons() -> void:
	for c in grid.get_children():
		c.queue_free()
	_buttons.clear()

	var group := ButtonGroup.new()
	for i in range(1, slot_count + 1):
		var id: String = "%s%d" % [slot_prefix, i]
		var b := Button.new()
		b.name = id
		b.text = _slot_label_text(id, null)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_on_slot_clicked.bind(id))
		grid.add_child(b)
		_buttons.append(b)

func _on_slot_clicked(bid: String) -> void:
	_selected_slot_id = bid
	_mark_selection(bid)

func _mark_selection(bid: String) -> void:
	for b in _buttons:
		b.button_pressed = (b.name == bid)

func _SL() -> Node:
	var n: Node = get_node_or_null("/root/SaveLoad")
	return n if n != null else get_node_or_null("/root/SaveLoadData")

func _refresh() -> void:
	var SL := _SL()
	var by_id: Dictionary = {}
	if SL and SL.has_method("list_saves"):
		var arr: Variant = SL.call("list_saves")
		if arr is Array:
			for s in (arr as Array):
				var d: Dictionary = s
				by_id[String(d.get("id",""))] = d
	for b in _buttons:
		var id := b.name
		b.text = _slot_label_text(id, by_id.get(id, null))

func _slot_label_text(id: String, meta: Variant) -> String:
	if meta == null:
		return "%s  (empty)" % id
	var d: Dictionary = meta
	var label := String(d.get("label", id))
	var t := int(d.get("timestamp", 0))
	var when := (Time.get_datetime_string_from_unix_time(t) if t > 0 else "Unknown")
	return "%s\n%s\n%s" % [id, label, when]

func _on_save_pressed() -> void:
	if _selected_slot_id == "":
		_selected_slot_id = "%s1" % slot_prefix
		_mark_selection(_selected_slot_id)

	var SL := _SL()
	if SL == null or not SL.has_method("list_saves"):
		push_error("Save system not available.")
		return

	var occupied := false
	var arr: Variant = SL.call("list_saves")
	if arr is Array:
		for s in (arr as Array):
			var d: Dictionary = s
			if String(d.get("id","")) == _selected_slot_id:
				occupied = true
				break

	if occupied:
		confirm.dialog_text = "Overwrite %s?\nThis will replace the existing save." % _selected_slot_id
		confirm.popup_centered()
	else:
		_do_save_now()

func _do_overwrite() -> void:
	confirm.hide()
	_do_save_now()

func _do_save_now() -> void:
	var SL := _SL()
	if SL == null or not SL.has_method("save_grove"):
		push_error("Save system not available.")
		return
	var label: String = name_edit.text.strip_edges()
	if label == "":
		label = _selected_slot_id
	var ok: bool = bool(SL.call("save_grove", _selected_slot_id, label))
	if ok:
		emit_signal("saved", _selected_slot_id, label)
		close()
	else:
		push_error("Save failed.")
