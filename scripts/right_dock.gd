extends Control

# Drawer sizing/anim
const WIDTH_COLLAPSED: int = 48
const WIDTH_EXPANDED: int  = 440  
const ANIM_S: float = 0.18

# Views
const VIEW_VILLAGERS_LIST := 0
const VIEW_VILLAGER_DETAIL := 1
const VIEW_BANK := 2 

# Optional scenes (guarded by exists checks)
const VILLAGERS_LIST_PATH := "res://ui/VillagersListView.tscn"
const VILLAGER_DETAIL_PATH := "res://ui/VillagerDetailView.tscn"
const TASK_PICKER_PATH := "res://ui/TaskPicker.tscn"
const BANK_VIEW_PATH := "res://ui/BankView.tscn"


@onready var _root_hbox: HBoxContainer = $RootHBox
@onready var _slide: PanelContainer = $RootHBox/SlidePanel
@onready var _views: TabContainer = $RootHBox/SlidePanel/MarginContainer/Views
@onready var _tab_villagers: Button = $RootHBox/IndexBar/TabVillagers
@onready var _tab_bank: Button = $RootHBox/IndexBar/TabBank


var _is_open := false
var _enabled := true
var _current_tab := VIEW_VILLAGERS_LIST

var _villagers_list: Control = null
var _villager_detail: Control = null
var _bank_view: Control = null  
var _fallback_list: ItemList = null


func _ready() -> void:
	add_to_group("RightDock")
	# Align drawer to right edge
	_root_hbox.alignment = BoxContainer.ALIGNMENT_END

	# Drawer starts collapsed & non-blocking
	_slide.custom_minimum_size.x = WIDTH_COLLAPSED
	_slide.visible = false
	_views.tabs_visible = false

	# Wire tabs (toggle behavior)
	_tab_villagers.pressed.connect(func(): _on_tab_pressed(VIEW_VILLAGERS_LIST))
	_tab_bank.pressed.connect(func(): _on_tab_pressed(VIEW_BANK))

	# Build/instance views (with fallbacks)
	_instance_views()

	_tab_bank.visible = true
	_tab_bank.disabled = false

	_set_open(false)
	_apply_root_filters()

# ----------------- Toggle & state -----------------

func _on_tab_pressed(view_idx: int) -> void:
	if not _enabled:
		return
	# Toggle: same tab closes, different tab opens/switches
	if _is_open and _current_tab == view_idx:
		_set_open(false)
	else:
		_open_to(view_idx)


func _open_to(view_idx: int) -> void:
	_current_tab = view_idx
	_views.current_tab = view_idx

	# If we're switching to the Villagers tab, nudge it to refresh
	if view_idx == VIEW_VILLAGERS_LIST and _villagers_list != null:
		if _villagers_list.has_method("_refresh"):
			_villagers_list.call("_refresh")

	_set_open(true)

func _set_open(open_now: bool) -> void:
	if _is_open == open_now:
		return
	_is_open = open_now

	if open_now:
		_slide.visible = true
		var tw := get_tree().create_tween()
		tw.tween_property(_slide, "custom_minimum_size:x", WIDTH_EXPANDED, ANIM_S)
	else:
		var tw2 := get_tree().create_tween()
		tw2.tween_property(_slide, "custom_minimum_size:x", WIDTH_COLLAPSED, ANIM_S)
		tw2.tween_callback(func():
			_slide.visible = false
		)

	_apply_root_filters() # ensure only correct bits capture input

# Called by World when ESC opens/closes
func set_enabled(v: bool) -> void:
	_enabled = v
	if not v:
		_set_open(false) # collapse while menus are up
	_tab_villagers.disabled = not v
	_tab_bank.disabled = not v
	_apply_root_filters()


# Root/container pass-through; only tabs and open drawer block input
func _apply_root_filters() -> void:
	# Root and container ignore input
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Index bar tabs capture when enabled
	_tab_villagers.mouse_filter = (Control.MOUSE_FILTER_STOP if (_enabled and not _tab_villagers.disabled) else Control.MOUSE_FILTER_IGNORE)
	_tab_bank.mouse_filter = (Control.MOUSE_FILTER_STOP if (_enabled and not _tab_bank.disabled) else Control.MOUSE_FILTER_IGNORE)

	# Drawer captures only when open & enabled
	_slide.mouse_filter = (Control.MOUSE_FILTER_STOP if (_is_open and _enabled) else Control.MOUSE_FILTER_IGNORE)

# ----------------- Build views -----------------

func _instance_views() -> void:
	for c in _views.get_children():
		c.queue_free()

	# Villagers List
	if ResourceLoader.exists(VILLAGERS_LIST_PATH):
		_villagers_list = (load(VILLAGERS_LIST_PATH) as PackedScene).instantiate()
	else:
		_villagers_list = _make_list_fallback()
	_villagers_list.name = "Villagers"
	_views.add_child(_villagers_list)

	# Villager Detail (fallback OK)
	if ResourceLoader.exists(VILLAGER_DETAIL_PATH):
		_villager_detail = (load(VILLAGER_DETAIL_PATH) as PackedScene).instantiate()
	else:
		_villager_detail = _make_detail_fallback()
	_villager_detail.name = "Details"
	_views.add_child(_villager_detail)

	# Bank View (uses your BankView.tscn)
	if ResourceLoader.exists(BANK_VIEW_PATH):
		_bank_view = (load(BANK_VIEW_PATH) as PackedScene).instantiate()
	else:
		var fallback := Label.new()
		fallback.text = "Bank view missing"
		_bank_view = fallback
	_bank_view.name = "Bank"
	_views.add_child(_bank_view)

	# Hook list view signals (if present)
	if _villagers_list.has_signal("request_place"):
		_villagers_list.connect("request_place", Callable(self, "_on_request_place"))
	if _villagers_list.has_signal("request_details"):
		_villagers_list.connect("request_details", Callable(self, "_on_request_details"))

# ----------------- Placement / Details flow -----------------

func _on_request_place(v_idx: int) -> void:
	_hint_pick_tile(true)
	_request_tile_pick(func(ax: Vector2i):
		_hint_pick_tile(false)
		_open_task_picker(v_idx, ax)
	)

func _on_request_details(v_idx: int) -> void:
	_open_to(VIEW_VILLAGER_DETAIL)
	if _villager_detail and _villager_detail.has_method("show_villager"):
		_villager_detail.call("show_villager", v_idx)

func _on_back_to_list() -> void:
	_open_to(VIEW_VILLAGERS_LIST)

func _hint_pick_tile(_show: bool) -> void:
	# Optional: flash hint, etc.
	pass

func _request_tile_pick(cb: Callable) -> void:
	var world := get_tree().get_first_node_in_group("World")
	if world and world.has_method("request_tile_pick"):
		world.request_tile_pick(cb)

func _open_task_picker(v_idx: int, axial: Vector2i) -> void:
	if ResourceLoader.exists(TASK_PICKER_PATH):
		var scn: PackedScene = load(TASK_PICKER_PATH) as PackedScene
		var picker := scn.instantiate()
		get_tree().root.add_child(picker)
		if picker.has_method("open_for"):
			picker.call("open_for", v_idx, axial)

# ----------------- Simple fallbacks -----------------

func _make_list_fallback() -> Control:
	var root := VBoxContainer.new()
	root.name = "VillagersListFallback"
	root.custom_minimum_size = Vector2(320, 220)

	var label := Label.new()
	label.text = "Villagers"
	root.add_child(label)

	var list := ItemList.new()
	list.name = "List"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(list)

	var hb := HBoxContainer.new()
	root.add_child(hb)

	var place_btn := Button.new()
	place_btn.name = "PlaceBtn"
	place_btn.text = "Place"
	hb.add_child(place_btn)

	var details_btn := Button.new()
	details_btn.name = "DetailsBtn"
	details_btn.text = "Details"
	hb.add_child(details_btn)

	# Buttons call the same handlers RightDock uses for the real list view
	place_btn.pressed.connect(func() -> void:
		var sel := _fallback_list_sel(list)
		if sel != -1:
			_on_request_place(sel)
	)
	details_btn.pressed.connect(func() -> void:
		var sel := _fallback_list_sel(list)
		if sel != -1:
			_on_request_details(sel)
	)
	list.item_activated.connect(func(i: int) -> void:
		_on_request_details(i)
	)

	# Remember the list so we can refresh it from a named signal handler
	_fallback_list = list

	# Initial populate (may be empty if Founder isn't created yet)
	_refresh_fallback_list(list)

	# Auto-refresh when the Villagers list changes (no lambdas capturing `list`)
	if typeof(Villagers) != TYPE_NIL and Villagers.has_signal("list_changed"):
		if not Villagers.list_changed.is_connected(_on_villagers_list_changed):
			Villagers.list_changed.connect(_on_villagers_list_changed)

	return root

func _refresh_fallback_list(list: ItemList) -> void:
	list.clear()

	var arr: Array = []
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("as_list"):
		arr = Villagers.as_list()

	for i in arr.size():
		var e: Dictionary = arr[i]
		var nm: String = String(e.get("name", "?"))
		var lv: int = int(e.get("level", 1))
		list.add_item("%s  (Lv %d)" % [nm, lv])

	# sync selection with Villagers
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_selected_index"):
		var si: int = Villagers.get_selected_index()
		if si >= 0 and si < list.item_count:
			list.select(si)


func _fallback_list_sel(list: ItemList) -> int:
	var sel := list.get_selected_items()
	return sel[0] if sel.size() > 0 else -1

func _make_detail_fallback() -> Control:
	var root := VBoxContainer.new()
	root.name = "VillagerDetailFallback"
	var label := Label.new()
	label.text = "Villager Details (WIP)"
	root.add_child(label)
	return root
	
func _on_villagers_list_changed() -> void:
	if _fallback_list != null and is_instance_valid(_fallback_list):
		_refresh_fallback_list(_fallback_list)
