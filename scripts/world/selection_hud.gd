# res://scripts/world/selection_hud.gd
extends Panel

signal building_equip_requested(ax: Vector2i, building_id: String)
signal building_slot_requested(ax: Vector2i, slot_type: String, slot_index: int)

@export var debug_logging: bool = false

# If your HUD is inside a Container, the Container will override anchors/position.
# Turning this on makes the panel ignore parent layout and lets us dock it reliably.
@export var force_top_level: bool = true

# Dock this panel to bottom-left of the viewport.
@export var dock_to_bottom_left: bool = true
@export var dock_padding: Vector2 = Vector2(16, 16)

# Keep the HUD above other UI/world drawing
@export var force_on_top: bool = true

# Larger, readable defaults (tweak in inspector if desired)
@export var min_panel_size: Vector2 = Vector2(720, 620)
@export var min_scroll_height: float = 520.0

@export var font_tile_title: int = 34
@export var font_section_title: int = 26
@export var font_body: int = 22
@export var font_small: int = 20

@export var header_icon_size: Vector2 = Vector2(64, 64)
@export var list_icon_size: Vector2 = Vector2(28, 28)
@export var list_row_sep: int = 10


const MAX_MODIFIERS_COLLAPSED: int = 9
const MODIFIER_ICON_SIZE: Vector2 = Vector2(36, 36)

const LIST_ICON_SIZE: Vector2 = Vector2(22, 22) # icons before names in lists
const LIST_ROW_SEP: int = 8


var _current_fragment: Node = null
var _current_coord: Vector2i = Vector2i.ZERO
var _mods_expanded: bool = false

# UI refs
var _root_vbox: Control = null
var _scroll_content: Control = null
var _mode_tabs: TabContainer = null
var _mode_header: Control = null
var _tile_tab_button: Button = null
var _building_tab_button: Button = null
var _scroll_container: ScrollContainer = null
var _tile_tab: Control = null
var _building_tab: Control = null

var _tile_icon: TextureRect = null
var _tile_name_label: Label = null
var _tile_coord_label: Label = null
var _tile_tier_label: Label = null

var _tile_modifiers_section: Control = null
var _tile_modifiers_grid: GridContainer = null
var _tile_modifiers_expand: Button = null

var _tile_resources_section: Control = null
var _tile_resources_list: VBoxContainer = null

var _tile_effects_section: Control = null
var _tile_effects_list: VBoxContainer = null

var _building_slot: Button = null
var _building_name_label: Label = null
var _building_status_label: Label = null
var _building_tier_label: Label = null

# Legacy "chips" row (we keep nodes for scene compatibility, but hide it)
var _building_chips_row: Control = null
var _chip_workers_label: Label = null
var _chip_queue_label: Label = null
var _chip_upkeep_label: Label = null
var _chip_integrity_label: Label = null

var _building_io_row: Control = null
var _building_inputs_list: VBoxContainer = null
var _building_outputs_list: VBoxContainer = null

var _building_buttons_row: Control = null

# Slots
var _base_slot: Button = null
var _module_slots: Array[Button] = []

# Autoload refs (safe)
var _selection: Node = null
var _bank: Node = null
var _resource_nodes: Node = null
var _construction: Node = null
var _items: Node = null
var _apply_seq: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	if force_on_top:
		z_as_relative = false
		z_index = 2000

	_selection = get_node_or_null("/root/Selection")
	_bank = get_node_or_null("/root/Bank")
	_resource_nodes = get_node_or_null("/root/ResourceNodes")
	_construction = get_node_or_null("/root/ConstructionSystem")
	_items = get_node_or_null("/root/Items")

	if force_top_level:
		top_level = true
		set_anchors_preset(Control.PRESET_TOP_LEFT, true)

	_apply_panel_style()
	_cache_nodes()
	_apply_readability_pass()
	_enforce_layout_floors()

	call_deferred("_apply_full_width_constraints")

	if dock_to_bottom_left:
		call_deferred("_dock_bottom_left")
		var vp_node: Viewport = get_viewport()
		if vp_node and not vp_node.size_changed.is_connected(_on_viewport_size_changed):
			vp_node.size_changed.connect(_on_viewport_size_changed)

	_setup_mode_tabs()
	_apply_slot_styles()

	if _tile_modifiers_expand:
		if not _tile_modifiers_expand.pressed.is_connected(_on_modifiers_expand_pressed):
			_tile_modifiers_expand.pressed.connect(_on_modifiers_expand_pressed)

	# Wire selection autoload
	if _selection and _selection.has_signal("fragment_selected"):
		var cb: Callable = Callable(self, "_on_fragment_selected")
		if not _selection.is_connected("fragment_selected", cb):
			_selection.connect("fragment_selected", cb)
	else:
		if debug_logging:
			print("[SelectionHUD] Selection autoload missing or has no fragment_selected signal.")

	# Make sure tab visibility matches current tab
	if _mode_tabs:
		_on_tab_changed(_mode_tabs.current_tab)

func _get_drag_data(_at_position: Vector2) -> Variant:
	# HUD should NEVER be a drag source.
	print("[SelectionHUD] DRAG START ", get_path())
	print_stack()
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.gui_cancel_drag()
	return null
# -------------------------
# Node caching
# -------------------------
func _cache_nodes() -> void:
	_root_vbox = get_node_or_null("Margin/RootVBox") as Control
	_log_missing_node("Margin/RootVBox", _root_vbox)

	_scroll_container = get_node_or_null("Margin/RootVBox/Scroll") as ScrollContainer
	_log_missing_node("Margin/RootVBox/Scroll", _scroll_container)

	_scroll_content = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent") as Control
	_log_missing_node("Margin/RootVBox/Scroll/ScrollContent", _scroll_content)

	_mode_tabs = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs") as TabContainer
	_log_missing_node("Margin/RootVBox/Scroll/ScrollContent/ModeTabs", _mode_tabs)

	_tile_tab = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab") as Control
	_log_missing_node(".../ModeTabs/TileTab", _tile_tab)

	_building_tab = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab") as Control
	_log_missing_node(".../ModeTabs/BuildingTab", _building_tab)

	_mode_header = get_node_or_null("Margin/RootVBox/ModeHeader") as Control
	_log_missing_node("Margin/RootVBox/ModeHeader", _mode_header)

	_tile_tab_button = get_node_or_null("Margin/RootVBox/ModeHeader/TileTabButton") as Button
	_log_missing_node(".../TileTabButton", _tile_tab_button)

	_building_tab_button = get_node_or_null("Margin/RootVBox/ModeHeader/BuildingTabButton") as Button
	_log_missing_node(".../BuildingTabButton", _building_tab_button)

	_tile_icon = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileIcon") as TextureRect
	_log_missing_node(".../TileIcon", _tile_icon)

	_tile_name_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText/TileName") as Label
	_log_missing_node(".../TileName", _tile_name_label)

	_tile_coord_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText/TileCoord") as Label
	_log_missing_node(".../TileCoord", _tile_coord_label)

	_tile_tier_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileTierChip/TileTierLabel") as Label
	_log_missing_node(".../TileTierLabel", _tile_tier_label)

	_tile_modifiers_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection") as Control
	_log_missing_node(".../TileModifiersSection", _tile_modifiers_section)

	_tile_modifiers_grid = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersGrid") as GridContainer
	_log_missing_node(".../TileModifiersGrid", _tile_modifiers_grid)

	_tile_modifiers_expand = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersHeader/TileModifiersExpand") as Button
	_log_missing_node(".../TileModifiersExpand", _tile_modifiers_expand)

	_tile_resources_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileResourcesSection") as Control
	_log_missing_node(".../TileResourcesSection", _tile_resources_section)

	_tile_resources_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileResourcesSection/TileResourcesList") as VBoxContainer
	_log_missing_node(".../TileResourcesList", _tile_resources_list)

	_tile_effects_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileEffectsSection") as Control
	_log_missing_node(".../TileEffectsSection", _tile_effects_section)

	_tile_effects_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileEffectsSection/TileEffectsList") as VBoxContainer
	_log_missing_node(".../TileEffectsList", _tile_effects_list)

	_building_slot = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSlot") as Button
	_log_missing_node(".../BuildingSlot", _building_slot)

	_building_name_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingName") as Label
	_log_missing_node(".../BuildingName", _building_name_label)

	_building_status_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingStatus") as Label
	_log_missing_node(".../BuildingStatus", _building_status_label)

	_building_tier_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingTierChip/BuildingTierLabel") as Label
	_log_missing_node(".../BuildingTierLabel", _building_tier_label)

	_building_chips_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow") as Control
	_log_missing_node(".../BuildingChipsRow", _building_chips_row)

	_chip_workers_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipWorkers/ChipWorkersLabel") as Label
	_log_missing_node(".../ChipWorkersLabel", _chip_workers_label)

	_chip_queue_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipQueue/ChipQueueLabel") as Label
	_log_missing_node(".../ChipQueueLabel", _chip_queue_label)

	_chip_upkeep_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipUpkeep/ChipUpkeepLabel") as Label
	_log_missing_node(".../ChipUpkeepLabel", _chip_upkeep_label)

	_chip_integrity_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipIntegrity/ChipIntegrityLabel") as Label
	_log_missing_node(".../ChipIntegrityLabel", _chip_integrity_label)

	_building_io_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow") as Control
	_log_missing_node(".../BuildingIORow", _building_io_row)

	_building_inputs_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs/BuildingInputsList") as VBoxContainer
	_log_missing_node(".../BuildingInputsList", _building_inputs_list)

	_building_outputs_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs/BuildingOutputsList") as VBoxContainer
	_log_missing_node(".../BuildingOutputsList", _building_outputs_list)

	_building_buttons_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingButtonsRow") as Control
	_log_missing_node(".../BuildingButtonsRow", _building_buttons_row)

	_base_slot = _building_slot
	_module_slots.clear()
	for i in range(1, 4):
		var btn: Button = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/ModulesRow/ModuleSlot%d" % i) as Button
		if btn:
			_module_slots.append(btn)

	# --- Critical: make cross-axis containers fill width (fixes “wrap at 1/5”)
	_apply_horizontal_fill_fixes()

	# Improve header labels behaviour
	if _tile_name_label:
		_tile_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tile_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_tile_name_label.clip_text = false
	if _tile_coord_label:
		_tile_coord_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tile_coord_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_tile_coord_label.clip_text = false

	if _building_name_label:
		_building_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_building_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_building_name_label.clip_text = false
	if _building_status_label:
		_building_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_building_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_building_status_label.clip_text = false


func _apply_horizontal_fill_fixes() -> void:
	var tile_header_row: Control = get_node_or_null(
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow"
	) as Control
	if tile_header_row:
		tile_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tile_header_text: Control = get_node_or_null(
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText"
	) as Control
	if tile_header_text:
		tile_header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _tile_modifiers_section:
		_tile_modifiers_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _tile_modifiers_grid:
		_tile_modifiers_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _tile_resources_section:
		_tile_resources_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _tile_resources_list:
		_tile_resources_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _tile_effects_section:
		_tile_effects_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _tile_effects_list:
		_tile_effects_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _building_io_row:
		_building_io_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var building_inputs_col: Control = get_node_or_null(
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs"
	) as Control
	if building_inputs_col:
		building_inputs_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _building_inputs_list:
		_building_inputs_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var building_outputs_col: Control = get_node_or_null(
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs"
	) as Control
	if building_outputs_col:
		building_outputs_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _building_outputs_list:
		_building_outputs_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _building_buttons_row:
		_building_buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _enforce_layout_floors() -> void:
	if custom_minimum_size.x < min_panel_size.x or custom_minimum_size.y < min_panel_size.y:
		custom_minimum_size = min_panel_size
	if size.x < min_panel_size.x or size.y < min_panel_size.y:
		size = min_panel_size

	if _root_vbox:
		_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if _scroll_container:
		_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS

		if _scroll_container.custom_minimum_size.y < min_scroll_height:
			_scroll_container.custom_minimum_size = Vector2(0, min_scroll_height)

	if _scroll_content:
		_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll_content.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if _mode_tabs:
		_mode_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mode_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if _mode_tabs.custom_minimum_size.y < (min_scroll_height - 40.0):
			_mode_tabs.custom_minimum_size = Vector2(0, min_scroll_height - 40.0)

	if _tile_tab:
		_tile_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tile_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if _building_tab:
		_building_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_building_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_apply_horizontal_fill_fixes()


func _setup_mode_tabs() -> void:
	if _mode_tabs == null:
		return

	if _mode_tabs.get_tab_count() >= 2:
		_mode_tabs.set_tab_title(0, "Tile")
		_mode_tabs.set_tab_title(1, "Building")
		if not _mode_tabs.tab_changed.is_connected(_on_tab_changed):
			_mode_tabs.tab_changed.connect(_on_tab_changed)

	if _tile_tab_button:
		if not _tile_tab_button.pressed.is_connected(_on_tile_tab_pressed):
			_tile_tab_button.pressed.connect(_on_tile_tab_pressed)

	if _building_tab_button:
		if not _building_tab_button.pressed.is_connected(_on_building_tab_pressed):
			_building_tab_button.pressed.connect(_on_building_tab_pressed)

	_sync_tab_buttons()
	_wire_slot_buttons()
	_on_tab_changed(_mode_tabs.current_tab)


# -------------------------
# Visual styling
# -------------------------
func _apply_panel_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.075, 0.94)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.22, 0.22, 0.28, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 10
	add_theme_stylebox_override("panel", style)

	add_theme_font_size_override("font_size", 22)
	add_theme_constant_override("separation", 14)
	add_theme_constant_override("line_spacing", 8)

	add_theme_constant_override("content_margin_left", 18)
	add_theme_constant_override("content_margin_right", 18)
	add_theme_constant_override("content_margin_top", 18)
	add_theme_constant_override("content_margin_bottom", 18)



func _apply_tab_button_style(btn: Button, active: bool) -> void:
	if btn == null:
		return

	btn.custom_minimum_size = Vector2(0, 44)

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1

	if active:
		sb.bg_color = Color(0.14, 0.16, 0.20, 0.95)
		sb.border_color = Color(0.45, 0.55, 0.75, 0.95)
	else:
		sb.bg_color = Color(0.09, 0.09, 0.11, 0.85)
		sb.border_color = Color(0.22, 0.22, 0.26, 0.9)

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_font_size_override("font_size", 20)


func _on_viewport_size_changed() -> void:
	if dock_to_bottom_left:
		_dock_bottom_left()
	_apply_full_width_constraints()



func _dock_bottom_left() -> void:
	if not is_inside_tree():
		return

	var vp: Vector2 = get_viewport_rect().size

	# Keep the panel stable; don’t let content resize it.
	var s: Vector2 = min_panel_size


	var max_w: float = max(120.0, vp.x - (dock_padding.x * 2.0))
	var max_h: float = max(120.0, vp.y - (dock_padding.y * 2.0))
	s.x = min(s.x, max_w)
	s.y = min(s.y, max_h)
	size = s

	var x: float = dock_padding.x
	var y: float = vp.y - size.y - dock_padding.y
	if y < dock_padding.y:
		y = dock_padding.y

	position = Vector2(x, y)



func _on_tab_changed(_tab_index: int) -> void:
	if _mode_tabs == null:
		return

	_sync_tab_buttons()

	if _tile_tab:
		_tile_tab.visible = (_mode_tabs.current_tab == 0)
	if _building_tab:
		_building_tab.visible = (_mode_tabs.current_tab == 1)

	if _scroll_container:
		_scroll_container.scroll_vertical = 0


func _on_tile_tab_pressed() -> void:
	if _mode_tabs:
		_mode_tabs.current_tab = 0
	_on_tab_changed(0)
	_sync_tab_buttons()


func _on_building_tab_pressed() -> void:
	if _mode_tabs:
		_mode_tabs.current_tab = 1
	_on_tab_changed(1)
	_sync_tab_buttons()


func _sync_tab_buttons() -> void:
	if _mode_tabs == null:
		return

	var tile_active: bool = (_mode_tabs.current_tab == 0)
	var build_active: bool = (_mode_tabs.current_tab == 1)

	if _tile_tab_button:
		_tile_tab_button.button_pressed = tile_active
		_apply_tab_button_style(_tile_tab_button, tile_active)

	if _building_tab_button:
		_building_tab_button.button_pressed = build_active
		_apply_tab_button_style(_building_tab_button, build_active)


func _wire_slot_buttons() -> void:
	if _building_slot:
		var cb0: Callable = Callable(self, "_on_building_slot_pressed")
		if not _building_slot.pressed.is_connected(cb0):
			_building_slot.pressed.connect(cb0)

	for i in range(_module_slots.size()):
		var btn: Button = _module_slots[i]
		if btn:
			var cb: Callable = Callable(self, "_on_module_slot_pressed").bind(i)
			if not btn.pressed.is_connected(cb):
				btn.pressed.connect(cb)


func _apply_slot_styles() -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.10, 0.12, 0.92)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.18, 0.18, 0.24)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.35, 0.55, 0.90)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.border_color = Color(0.70, 0.70, 0.85)

	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.45, 0.80, 1.00)

	var slots: Array[Button] = []
	if _building_slot:
		slots.append(_building_slot)
	slots.append_array(_module_slots)

	for slot in slots:
		slot.add_theme_stylebox_override("normal", normal)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("pressed", pressed)
		slot.add_theme_stylebox_override("focus", focus)
		slot.add_theme_stylebox_override("disabled", normal)
		slot.custom_minimum_size = Vector2(54, 54)
		slot.text = ""
		slot.clip_text = true
		slot.expand_icon = true


# -------------------------
# Fragment selection
# -------------------------
func set_fragment(fragment: Node) -> void:
	_current_fragment = fragment
	_mods_expanded = false

	_apply_seq += 1
	var seq: int = _apply_seq
	call_deferred("_apply_fragment_seq", seq, fragment)

func _apply_fragment_seq(seq: int, frag: Node) -> void:
	# Outdated call? bail immediately.
	if seq != _apply_seq:
		return

	# If we're not in the tree yet, try again next idle.
	if not is_inside_tree():
		call_deferred("_apply_fragment_seq", seq, frag)
		return

	var tree := get_tree()
	if tree == null:
		call_deferred("_apply_fragment_seq", seq, frag)
		return

	# Wait for fragment data to “settle”
	await tree.process_frame
	if not is_inside_tree() or get_tree() == null:
		return

	await tree.process_frame
	if not is_inside_tree() or get_tree() == null:
		return

	# Still the latest selection?
	if seq != _apply_seq:
		return
	if frag != _current_fragment:
		return

	_apply_fragment()



func show_fragment(fragment: Node) -> void:
	set_fragment(fragment)


func _on_fragment_selected(fragment: Node) -> void:
	if debug_logging:
		print("[SelectionHUD] fragment_selected: ", fragment)
	set_fragment(fragment)


func _apply_fragment() -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		visible = false
		return

	_sync_coord_from_fragment(_current_fragment)

	visible = true

	if _scroll_container:
		_scroll_container.scroll_vertical = 0

	_enforce_layout_floors()

	_update_tile_tab()
	_update_building_tab()

	if _mode_tabs:
		_on_tab_changed(_mode_tabs.current_tab)

	if debug_logging:
		var biome_str: String = _get_biome_string(_current_fragment)
		var tier_val: int = _get_tile_tier(_current_fragment)
		var mods: Array = _get_modifiers_from_fragment(_current_fragment)
		var resources: Array = _get_resource_nodes_for_tile(_current_coord)
		var building_id: String = _get_equipped_building_id(_current_fragment)
		var modules: Array = _get_equipped_modules(_current_fragment)
		print("[SelectionHUD] coord=%s biome=%s tier=%s mods=%d resources=%d building=%s modules=%s" % [
			_current_coord, biome_str, tier_val, mods.size(), resources.size(), building_id, modules
		])

	if dock_to_bottom_left:
		_dock_bottom_left()
		_apply_full_width_constraints()


# -------------------------
# Tile tab
# -------------------------
func _update_tile_tab() -> void:
	var biome_str: String = _get_biome_string(_current_fragment)
	var tile_name: String = _get_tile_name(_current_fragment, biome_str)
	var tier_val: int = _get_tile_tier(_current_fragment)
	var coord_text: String = "%d,%d" % [_current_coord.x, _current_coord.y]

	if _tile_icon:
		_tile_icon.custom_minimum_size = header_icon_size

	if _tile_name_label:
		_tile_name_label.text = tile_name
		_tile_name_label.add_theme_font_size_override("font_size", font_tile_title)

	if _tile_coord_label:
		_tile_coord_label.text = "Coord: %s" % coord_text
		_tile_coord_label.add_theme_font_size_override("font_size", font_small)

	if _tile_tier_label:
		_tile_tier_label.text = "T%d" % tier_val
		_tile_tier_label.add_theme_font_size_override("font_size", font_small)
		

	var mods: Array = _get_modifiers_from_fragment(_current_fragment)
	_populate_modifiers_grid(mods)

	var resources: Array = _get_resource_nodes_for_tile(_current_coord)
	var resource_entries: Array = _build_resource_entries(resources)
	_populate_entries(_tile_resources_list, resource_entries, "No resource nodes")

	_set_section_visible(_tile_resources_section, true)

	var effect_lines: Array[String] = _get_effect_lines(_current_fragment)
	_populate_list(_tile_effects_list, effect_lines, "No effects")
	_set_section_visible(_tile_effects_section, true)


func _get_biome_string(fragment: Node) -> String:
	if fragment == null or not is_instance_valid(fragment):
		return "Unknown"
	var v: Variant = fragment.get("biome")
	if v == null:
		return "Unknown"
	return String(v)


func _get_tile_name(fragment: Node, biome_str: String) -> String:
	if fragment == null or not is_instance_valid(fragment):
		return biome_str if biome_str != "" else "Tile"
	var v: Variant = fragment.get("tile_name")
	if v != null:
		var name_str: String = String(v)
		if name_str.strip_edges() != "":
			return name_str
	return biome_str if biome_str != "" else "Tile"


func _get_tile_tier(fragment: Node) -> int:
	if fragment == null or not is_instance_valid(fragment):
		return 0
	var v: Variant = fragment.get("tier")
	if v == null:
		return 0
	return int(v)


func _get_biome_icon(_fragment: Node, biome_str: String) -> Texture2D:
	var key := biome_str.strip_edges().to_lower()
	if key == "":
		return null

	# Try a biome icon first
	var p1 := "res://assets/icons/biomes/%s.png" % key
	if ResourceLoader.exists(p1):
		return load(p1) as Texture2D

	# Fallback to your existing biome icon set if it's somewhere else
	var p2 := "res://assets/icons/biomes/%s_icon.png" % key
	if ResourceLoader.exists(p2):
		return load(p2) as Texture2D

	# Final fallback
	var p3 := "res://assets/icons/biomes/default.png"
	if ResourceLoader.exists(p3):
		return load(p3) as Texture2D

	return null



func _get_modifiers_from_fragment(frag: Node) -> Array:
	if frag == null or not is_instance_valid(frag):
		return []
	var v: Variant = frag.get("modifiers")
	if v is Array:
		return v as Array
	return []


func _populate_modifiers_grid(mods: Array) -> void:
	if _tile_modifiers_grid == null:
		return

	_clear_container(_tile_modifiers_grid)
	_set_section_visible(_tile_modifiers_section, true)

	if mods.is_empty():
		var label: Label = Label.new()
		label.text = "No modifiers"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		label.add_theme_font_size_override("font_size", 18)
		_tile_modifiers_grid.add_child(label)
		if _tile_modifiers_expand:
			_tile_modifiers_expand.visible = false
		return

	var total: int = mods.size()
	var max_visible: int = total if _mods_expanded else MAX_MODIFIERS_COLLAPSED
	var visible_count: int = min(total, max_visible)

	for i in range(visible_count):
		var m: Variant = mods[i]
		var card: Control = _build_modifier_card(m)
		_tile_modifiers_grid.add_child(card)

	var remaining: int = total - visible_count
	if _tile_modifiers_expand:
		if remaining > 0 and not _mods_expanded:
			_tile_modifiers_expand.visible = true
			_tile_modifiers_expand.text = "+%d" % remaining
		elif _mods_expanded and total > MAX_MODIFIERS_COLLAPSED:
			_tile_modifiers_expand.visible = true
			_tile_modifiers_expand.text = "Show less"
		else:
			_tile_modifiers_expand.visible = false


func _build_modifier_card(mod: Variant) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(MODIFIER_ICON_SIZE.x + 12.0, MODIFIER_ICON_SIZE.y + 12.0)

	var rarity: String = _modifier_get_rarity(mod)
	var border_color: Color = _rarity_color(rarity)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.115, 0.115, 0.135, 0.96)
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = MODIFIER_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _get_modifier_icon(mod)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.add_child(icon)
	panel.add_child(margin)

	if icon.texture == null:
		var label: Label = Label.new()
		label.text = _modifier_get_name(mod)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		panel.add_child(label)

	panel.tooltip_text = _modifier_to_tooltip(mod)
	return panel


func _modifier_get_name(mod: Variant) -> String:
	if mod is Dictionary:
		var d: Dictionary = mod as Dictionary
		var name: String = String(d.get("name", d.get("detail", ""))).strip_edges()
		if name != "":
			return name
		var kind: String = String(d.get("kind", "")).strip_edges()
		if kind != "":
			return kind
	if typeof(mod) == TYPE_STRING:
		return String(mod)
	return "Modifier"


func _modifier_get_rarity(mod: Variant) -> String:
	if mod is Dictionary:
		var d: Dictionary = mod as Dictionary
		return String(d.get("rarity", ""))
	return ""


func _rarity_color(rarity: String) -> Color:
	var key: String = rarity.strip_edges().to_lower()
	match key:
		"common":
			return Color(0.55, 0.55, 0.60)
		"uncommon":
			return Color(0.35, 0.70, 0.45)
		"rare":
			return Color(0.35, 0.55, 0.90)
		"epic":
			return Color(0.70, 0.45, 0.90)
		"legendary":
			return Color(0.95, 0.70, 0.20)
		_:
			return Color(0.40, 0.40, 0.45)


func _get_modifier_icon(mod: Variant) -> Texture2D:
	if mod is Dictionary:
		var d: Dictionary = mod as Dictionary
		var kind: String = String(d.get("kind", "")).to_lower()
		var skill: String = String(d.get("skill", "")).to_lower()
		if kind == "resource spawn" and skill != "":
			var path: String = "res://assets/icons/modifiers/%s_node.png" % skill
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
	return null


func _modifier_to_tooltip(mod: Variant) -> String:
	if mod is Dictionary:
		var d: Dictionary = mod as Dictionary
		var name: String = String(d.get("name", d.get("detail", ""))).strip_edges()
		var kind: String = String(d.get("kind", "")).strip_edges()
		var rarity: String = String(d.get("rarity", "")).strip_edges()
		var skill: String = String(d.get("skill", "")).strip_edges()

		var bits: Array[String] = []
		if name != "":
			bits.append(name)
		if rarity != "":
			bits.append("Rarity: %s" % rarity)
		if kind != "":
			bits.append("Kind: %s" % kind)
		if skill != "":
			bits.append("Skill: %s" % skill)
		return "\n".join(bits)

	if typeof(mod) == TYPE_STRING:
		return String(mod)

	return ""


func _get_resource_nodes_for_tile(coord: Vector2i) -> Array:
	if _resource_nodes == null:
		return _build_resource_nodes_from_modifiers(_current_fragment)
	if not _resource_nodes.has_method("get_nodes"):
		return _build_resource_nodes_from_modifiers(_current_fragment)

	var nodes_v: Variant = _resource_nodes.call("get_nodes", coord)
	if nodes_v is Array:
		var nodes: Array = nodes_v as Array
		if not nodes.is_empty():
			return nodes

	return _build_resource_nodes_from_modifiers(_current_fragment)


func _build_resource_nodes_from_modifiers(fragment: Node) -> Array:
	var nodes: Array = []
	if fragment == null or not is_instance_valid(fragment):
		return nodes

	var mods_v: Variant = fragment.get("modifiers")
	if not (mods_v is Array):
		return nodes

	for m in (mods_v as Array):
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var md: Dictionary = m as Dictionary

		var kind: String = String(md.get("kind", "")).strip_edges()
		var kind_key: String = kind.to_lower().replace("_", " ")
		if kind_key != "resource spawn":
			continue

		var detail: String = String(md.get("name", md.get("detail", ""))).strip_edges()
		var skill: String = String(md.get("skill", "")).strip_edges()

		nodes.append({"detail": detail, "skill": skill})

	return nodes


func _build_resource_entries(nodes: Array) -> Array:
	# Aggregates duplicates and keeps an icon per entry (based on skill)
	var counts: Dictionary = {}  # label -> int
	var icons: Dictionary = {}   # label -> Texture2D

	for n_v in nodes:
		if typeof(n_v) != TYPE_DICTIONARY:
			continue
		var n: Dictionary = n_v as Dictionary

		var skill: String = String(n.get("skill", "")).strip_edges()
		var detail: String = String(n.get("detail", "")).strip_edges()

		var label: String = detail if detail != "" else skill
		if label == "":
			continue

		counts[label] = int(counts.get(label, 0)) + 1
		if not icons.has(label):
			icons[label] = _resource_icon_for_skill(skill)

	var labels: Array = counts.keys()
	labels.sort()

	var entries: Array = []
	for k_v in labels:
		var k: String = String(k_v)
		var qty: int = int(counts[k])
		var line: String = k if qty <= 1 else ("%s ×%d" % [k, qty])

		var tex: Texture2D = null
		if icons.has(k) and icons[k] is Texture2D:
			tex = icons[k] as Texture2D

		entries.append({"text": line, "icon": tex, "header": false})

	return entries



func _get_effect_lines(fragment: Node) -> Array[String]:
	if fragment == null or not is_instance_valid(fragment):
		return []

	if fragment.has_method("get_local_effects_list"):
		var eff_v: Variant = fragment.call("get_local_effects_list")
		if eff_v is Array:
			var lines: Array[String] = []
			for entry in eff_v as Array:
				lines.append(String(entry))
			return lines

	if fragment.has_method("get_local_effects_summary"):
		var summary: String = String(fragment.call("get_local_effects_summary")).strip_edges()
		if summary != "":
			var lines2: Array[String] = []
			for entry2 in summary.split("\n", false):
				lines2.append(String(entry2))
			return lines2

	return []

func _resolve_item_icon(id: StringName) -> Texture2D:
	if _items and _items.has_method("get_icon"):
		var t_v: Variant = _items.call("get_icon", id)
		if t_v is Texture2D:
			return t_v as Texture2D
	if _items and _items.has_method("get_icon_path"):
		var p_v: Variant = _items.call("get_icon_path", id)
		var path: String = String(p_v)
		if path != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _resource_icon_for_skill(skill: String) -> Texture2D:
	var s: String = skill.strip_edges().to_lower()
	if s == "":
		return null
	var path: String = "res://assets/icons/modifiers/%s_node.png" % s
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_list_row(text: String, icon_tex: Texture2D, header: bool = false) -> Control:
	if text.strip_edges() == "":
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		return spacer

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", list_row_sep)

	var icon_holder := TextureRect.new()
	icon_holder.custom_minimum_size = list_icon_size
	icon_holder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_holder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_holder.texture = icon_tex
	row.add_child(icon_holder)

	# Keep alignment even if no icon
	if icon_tex == null:
		icon_holder.modulate = Color(1, 1, 1, 0) # invisible but keeps spacing

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", font_body if not header else font_section_title)
	label.add_theme_constant_override("outline_size", 2)


	row.add_child(label)
	return row


func _populate_entries(list_node: VBoxContainer, entries: Array, placeholder: String = "") -> void:
	if list_node == null:
		return
	_clear_container(list_node)

	var out: Array = entries
	if out.is_empty() and placeholder != "":
		out = [{"text": placeholder, "icon": null, "header": false}]

	for e_v in out:
		var text: String = ""
		var icon_tex: Texture2D = null
		var header: bool = false

		if e_v is Dictionary:
			var d: Dictionary = e_v as Dictionary
			text = String(d.get("text", ""))
			var icon_v: Variant = d.get("icon", null)
			if icon_v is Texture2D:
				icon_tex = icon_v as Texture2D
			header = bool(d.get("header", false))
		else:
			text = String(e_v)

		list_node.add_child(_build_list_row(text, icon_tex, header))


func _populate_list(list_node: VBoxContainer, lines: Array[String], placeholder: String = "") -> void:
	if list_node == null:
		return
	_clear_container(list_node)

	var output_lines: Array[String] = lines
	if output_lines.is_empty() and placeholder != "":
		output_lines = [placeholder]

	for line in output_lines:
		var label: Label = Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		label.clip_text = false
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.92))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
		label.add_theme_constant_override("outline_size", 1)
		list_node.add_child(label)


func _set_section_visible(section: Control, should_show: bool) -> void:
	if section:
		section.visible = should_show


func _set_buttons_enabled(container: Control, is_enabled: bool) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is Button:
			(child as Button).disabled = not is_enabled


# -------------------------
# Building tab (ConstructionSystem-truthful)
# -------------------------
func _update_building_tab() -> void:
	var base_id: String = _get_equipped_building_id(_current_fragment)
	var has_base: bool = (base_id != "")

	# Equipment slots (icons + tooltips)
	_refresh_building_equipment(_current_fragment)

	# Hide fabricated chips row (workers/queue/upkeep/integrity not part of ConstructionSystem)
	if _building_chips_row:
		_building_chips_row.visible = false

	# No base building -> disable/hide modules and IO
	if not has_base:
		if _building_name_label:
			_building_name_label.text = "No Building"
			_building_name_label.add_theme_font_size_override("font_size", 26)
		if _building_status_label:
			_building_status_label.text = "No building placed"
			_building_status_label.add_theme_font_size_override("font_size", 20)
		if _building_tier_label:
			_building_tier_label.text = ""
		for btn0 in _module_slots:
			if btn0:
				btn0.disabled = true
				btn0.visible = false

		if _building_io_row:
			_building_io_row.visible = false
		if _building_buttons_row:
			_building_buttons_row.visible = false

		# Clear lists safely
		_populate_list(_building_inputs_list, [], "No inputs")
		_populate_list(_building_outputs_list, [], "(not defined)")
		return

	# Base exists -> show module slots + IO row
	for btn1 in _module_slots:
		if btn1:
			btn1.visible = true
			btn1.disabled = false

	if _building_buttons_row:
		_building_buttons_row.visible = true
		_set_buttons_enabled(_building_buttons_row, true)

	if _building_io_row:
		_building_io_row.visible = true

	# Pull recipe data from ConstructionSystem
	var base_rec: Dictionary = _get_construction_recipe(base_id)

	var b_label: String = String(base_rec.get("label", base_id))
	var b_desc: String = String(base_rec.get("desc", "")).strip_edges()
	var b_skill: String = String(base_rec.get("linked_skill", "")).strip_edges()
	var b_level_req: int = int(base_rec.get("level_req", 0))
	var b_build_tier: int = int(base_rec.get("build_tier", 0))

	if _building_name_label:
		_building_name_label.text = b_label
		_building_name_label.add_theme_font_size_override("font_size", 22)

	# Status text: only real data (linked_skill / level_req / modules summary)
	var status_lines: Array[String] = []
	if b_skill != "":
		status_lines.append("Linked skill: %s" % b_skill)
	if b_level_req > 0:
		status_lines.append("Construction req: %d" % b_level_req)
	if b_desc != "":
		status_lines.append(b_desc)

	# Modules summary
	var mods: Array = _get_equipped_modules(_current_fragment)
	var mod_summaries: Array[String] = []
	for m_v in mods:
		if typeof(m_v) != TYPE_STRING:
			continue
		var mid: String = String(m_v).strip_edges()
		if mid == "":
			continue
		var mrec: Dictionary = _get_construction_recipe(mid)
		var mlab: String = String(mrec.get("label", mid))
		var mtier: int = int(mrec.get("module_tier", 0))
		if mtier > 0:
			mod_summaries.append("%s (T%d)" % [mlab, mtier])
		else:
			mod_summaries.append(mlab)

	if mod_summaries.is_empty():
		status_lines.append("Modules: (none)")
	else:
		status_lines.append("Modules: %s" % ", ".join(mod_summaries))

	if _building_status_label:
		_building_status_label.text = "\n".join(status_lines)
		_building_status_label.add_theme_font_size_override("font_size", 20)

	if _building_tier_label:
		_building_tier_label.text = ("T%d" % b_build_tier) if b_build_tier > 0 else ""
		_building_tier_label.add_theme_font_size_override("font_size", 20)

	# Inputs: entries with icons
	var input_entries: Array = []
	input_entries.append({"text":"Base inputs:", "icon": null, "header": true})
	input_entries.append_array(_format_input_entries_from_recipe(base_rec))

	# Add module inputs
	for m_v2 in mods:
		if typeof(m_v2) != TYPE_STRING:
			continue
		var mid2: String = String(m_v2).strip_edges()
		if mid2 == "":
			continue
		var mrec2: Dictionary = _get_construction_recipe(mid2)
		var mlabel2: String = String(mrec2.get("label", mid2))

		input_entries.append({"text":"", "icon": null, "header": false, "spacer": true})
		input_entries.append({"text":"Module: %s" % mlabel2, "icon": null, "header": true})
		input_entries.append_array(_format_input_entries_from_recipe(mrec2))

	_populate_entries(_building_inputs_list, input_entries, "No inputs")

	# Outputs: do not fabricate (ConstructionSystem recipes don’t define outputs for buildings)
	_populate_list(_building_outputs_list, ["(not defined)"], "(not defined)")


func _get_construction_recipe(id: String) -> Dictionary:
	if id == "":
		return {}
	if _construction and _construction.has_method("get_recipe_by_id"):
		var rec_v: Variant = _construction.call("get_recipe_by_id", StringName(id))
		if rec_v is Dictionary:
			return rec_v as Dictionary
	return {}


func _format_inputs_from_recipe(rec: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var inputs_v: Variant = rec.get("inputs", [])
	if typeof(inputs_v) != TYPE_ARRAY:
		return lines

	var inputs: Array = inputs_v as Array
	if inputs.is_empty():
		lines.append("(none)")
		return lines

	for inp_v in inputs:
		if typeof(inp_v) != TYPE_DICTIONARY:
			continue
		var inp: Dictionary = inp_v as Dictionary
		var qty: int = int(inp.get("qty", 0))
		if qty <= 0:
			continue

		var item_any: Variant = inp.get("item", "")
		var item_id: StringName = StringName("")
		if item_any is StringName:
			item_id = item_any as StringName
		else:
			item_id = StringName(String(item_any))

		var item_label: String = _resolve_item_label(item_id)
		lines.append("%d× %s" % [qty, item_label])

	if lines.is_empty():
		lines.append("(none)")
	return lines

func _format_input_entries_from_recipe(rec: Dictionary) -> Array:
	var entries: Array = []
	var inputs_v: Variant = rec.get("inputs", [])
	if typeof(inputs_v) != TYPE_ARRAY:
		return entries

	var inputs: Array = inputs_v as Array
	if inputs.is_empty():
		entries.append({"text":"(none)", "icon": null, "header": false})
		return entries

	for inp_v in inputs:
		if typeof(inp_v) != TYPE_DICTIONARY:
			continue
		var inp: Dictionary = inp_v as Dictionary
		var qty: int = int(inp.get("qty", 0))
		if qty <= 0:
			continue

		var item_any: Variant = inp.get("item", "")
		var item_id: StringName = StringName("")
		if item_any is StringName:
			item_id = item_any as StringName
		else:
			item_id = StringName(String(item_any))

		var item_label: String = _resolve_item_label(item_id)
		var icon_tex: Texture2D = _resolve_item_icon(item_id)

		entries.append({"text":"%d× %s" % [qty, item_label], "icon": icon_tex, "header": false})

	if entries.is_empty():
		entries.append({"text":"(none)", "icon": null, "header": false})
	return entries


func _resolve_item_label(id: StringName) -> String:
	var label: String = String(id)
	if _items and _items.has_method("is_valid") and _items.has_method("display_name"):
		if bool(_items.call("is_valid", id)):
			label = String(_items.call("display_name", id))
	return label


func _resolve_building_icon(id: String) -> Texture2D:
	if id == "":
		return null
	# Prefer Items.get_icon if present
	if _items and _items.has_method("get_icon"):
		var t: Variant = _items.call("get_icon", StringName(id))
		if t is Texture2D:
			return t as Texture2D
	# Fallback: Items.get_icon_path
	if _items and _items.has_method("get_icon_path"):
		var p: Variant = _items.call("get_icon_path", StringName(id))
		var path: String = String(p)
		if path != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _build_tooltip_from_recipe(id: String) -> String:
	var rec: Dictionary = _get_construction_recipe(id)
	if rec.is_empty():
		return id
	var title: String = String(rec.get("label", id))
	var desc: String = String(rec.get("desc", "")).strip_edges()
	if desc == "":
		desc = String(rec.get("effect_raw", "")).strip_edges()
	if desc == "":
		return title
	return "%s\n%s" % [title, desc]


func _get_equipped_building_id(fragment: Node) -> String:
	if fragment == null or not is_instance_valid(fragment):
		return ""

	if fragment.has_meta("building_id"):
		var m: String = String(fragment.get_meta("building_id", ""))
		if m != "":
			return m

	var p_id: String = _p_str(fragment, "building_id", "")
	if p_id != "":
		return p_id

	var b: Variant = _p(fragment, "building", null)
	if b is Dictionary:
		var base_v: Variant = (b as Dictionary).get("base", "")
		return String(base_v)

	return ""


func _get_equipped_modules(fragment: Node) -> Array:
	if fragment == null or not is_instance_valid(fragment):
		return []

	if fragment.has_meta("building_modules"):
		var m: Variant = fragment.get_meta("building_modules", [])
		if m is Array:
			return m as Array

	var pv: Variant = _p(fragment, "building_modules", null)
	if pv is Array:
		return pv as Array

	var b: Variant = _p(fragment, "building", null)
	if b is Dictionary:
		var mods_v: Variant = (b as Dictionary).get("modules", [])
		if mods_v is Array:
			return mods_v as Array

	return []


func _refresh_building_equipment(fragment: Node) -> void:
	var base_id: String = _get_equipped_building_id(fragment)
	var modules: Array = _get_equipped_modules(fragment)

	if _building_slot:
		_building_slot.custom_minimum_size = Vector2(64, 64)
		if base_id != "":
			_building_slot.icon = _resolve_building_icon(base_id)
			_building_slot.tooltip_text = _build_tooltip_from_recipe(base_id)
		else:
			_building_slot.icon = null
			_building_slot.tooltip_text = "Empty"

	for i in range(_module_slots.size()):
		var slot: Button = _module_slots[i]
		if slot == null:
			continue

		slot.custom_minimum_size = Vector2(54, 54)

		var module_id: String = ""
		if i < modules.size() and modules[i] is String:
			module_id = String(modules[i])

		if module_id != "":
			slot.icon = _resolve_building_icon(module_id)
			slot.tooltip_text = _build_tooltip_from_recipe(module_id)
		else:
			slot.icon = null
			slot.tooltip_text = "Empty"


func _on_modifiers_expand_pressed() -> void:
	_mods_expanded = not _mods_expanded
	_update_tile_tab()


func _clear_container(container: Control) -> void:
	if container == null:
		return
	while container.get_child_count() > 0:
		var child: Node = container.get_child(0)
		container.remove_child(child)  # remove immediately so layout updates now
		child.queue_free()



# -------------------------
# Helpers for future equip
# -------------------------
func equip_base(building_id: String) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return
	_current_fragment.set_meta("building_id", building_id)
	_current_fragment.set_meta("building_modules", [])
	building_equip_requested.emit(_current_coord, building_id)
	_update_building_tab()


func equip_module(slot_index: int, building_id: String) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	var modules: Array = []
	if _current_fragment.has_meta("building_modules"):
		var m: Variant = _current_fragment.get_meta("building_modules", [])
		if m is Array:
			modules = (m as Array).duplicate()

	var max_index: int = max(_module_slots.size() - 1, 0)
	var idx: int = clampi(slot_index, 0, max_index)

	if modules.size() <= idx:
		modules.resize(idx + 1)
	modules[idx] = building_id

	_current_fragment.set_meta("building_modules", modules)
	building_equip_requested.emit(_current_coord, building_id)
	_update_building_tab()


# -------------------------
# Drag-and-drop from Bank into slots
# NOTE: HUD does NOT consume Bank items (per requirement).
# -------------------------
func _get_drop_slot_info(at_position: Vector2, data: Variant) -> Dictionary:
	var info: Dictionary = {}

	if typeof(data) != TYPE_DICTIONARY:
		return info

	var d: Dictionary = data as Dictionary
	if String(d.get("kind", "")) != "bank_item":
		return info

	var item_id: String = String(d.get("item_id", ""))
	if item_id == "":
		return info

	var icon_tex: Texture2D = null
	if d.has("icon") and d["icon"] is Texture2D:
		icon_tex = d["icon"] as Texture2D

	var global_pos: Vector2 = global_position + at_position

	if _base_slot and _base_slot.get_global_rect().has_point(global_pos):
		info["slot_type"] = "base"
		info["slot_index"] = 0
		info["item_id"] = item_id
		info["icon"] = icon_tex
		return info

	for i in range(_module_slots.size()):
		var btn: Button = _module_slots[i]
		if btn and btn.visible and btn.get_global_rect().has_point(global_pos):
			info["slot_type"] = "module"
			info["slot_index"] = i
			info["item_id"] = item_id
			info["icon"] = icon_tex
			return info

	return info


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var viewport := get_viewport()
	if viewport and viewport.has_method("gui_is_dragging"):
		if not viewport.gui_is_dragging():
			return false

	var info: Dictionary = _get_drop_slot_info(at_position, data)
	if info.is_empty():
		return false

	var slot_type: String = String(info.get("slot_type", ""))
	var item_id: String = String(info.get("item_id", ""))

	if not _is_valid_building_item_for_slot(item_id, slot_type):
		return false

	if slot_type == "module":
		var has_base: bool = false
		if _current_fragment and _current_fragment.has_meta("building_id"):
			var base_id: String = String(_current_fragment.get_meta("building_id", ""))
			has_base = (base_id != "")
		if not has_base:
			return false

	# Bank is only used to check existence (optional)
	if _bank == null:
		return true
	if not _bank.has_method("has_at_least"):
		return true

	return bool(_bank.call("has_at_least", item_id, 1))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var info: Dictionary = _get_drop_slot_info(at_position, data)
	if info.is_empty():
		return

	var building_id: String = String(info["item_id"])
	var icon_tex: Texture2D = null
	if info.has("icon") and info["icon"] is Texture2D:
		icon_tex = info["icon"] as Texture2D

	var slot_type: String = String(info.get("slot_type", ""))
	if slot_type == "base":
		_equip_base_from_drop(building_id, icon_tex)
	else:
		_equip_module_from_drop(int(info.get("slot_index", 0)), building_id, icon_tex)


func _equip_base_from_drop(building_id: String, icon_tex: Texture2D) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	_current_fragment.set_meta("building_id", building_id)
	_current_fragment.set_meta("building_modules", [])

	if _base_slot:
		_base_slot.icon = icon_tex
		_base_slot.text = ""

	for btn in _module_slots:
		if btn:
			btn.icon = null
			btn.text = ""

	building_equip_requested.emit(_current_coord, building_id)
	_update_building_tab()


func _equip_module_from_drop(slot_index: int, building_id: String, icon_tex: Texture2D) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	var max_index: int = _module_slots.size() - 1
	if max_index < 0:
		return

	var idx: int = clampi(slot_index, 0, max_index)

	var modules: Array = []
	if _current_fragment.has_meta("building_modules"):
		var m: Variant = _current_fragment.get_meta("building_modules", [])
		if m is Array:
			modules = (m as Array).duplicate()

	if modules.size() <= idx:
		modules.resize(idx + 1)
	modules[idx] = building_id
	_current_fragment.set_meta("building_modules", modules)

	if idx < _module_slots.size():
		var btn: Button = _module_slots[idx]
		if btn:
			btn.icon = icon_tex
			btn.text = ""
			btn.visible = true

	building_equip_requested.emit(_current_coord, building_id)
	_update_building_tab()


func _on_building_slot_pressed() -> void:
	# REQUIRED: base slot uses ("base", 0)
	building_slot_requested.emit(_current_coord, "base", 0)


func _on_module_slot_pressed(slot_index: int) -> void:
	building_slot_requested.emit(_current_coord, "module", slot_index)


func _is_valid_building_item_for_slot(item_id: String, slot_type: String) -> bool:
	if item_id == "":
		return false

	if _construction and _construction.has_method("get_recipe_by_id"):
		var rec: Variant = _construction.call("get_recipe_by_id", StringName(item_id))
		if rec is Dictionary:
			var kind: String = String((rec as Dictionary).get("kind", ""))
			if slot_type == "base":
				return kind == "base"
			if slot_type == "module":
				return kind == "module"
			return false

	if slot_type == "base":
		return item_id.ends_with("_base")
	if slot_type == "module":
		return not item_id.ends_with("_base")

	return false


# -------------------------
# Generic property helpers
# -------------------------
func _p(obj: Object, key: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	var v: Variant = obj.get(key)
	if v == null:
		return default_value
	return v


func _p_str(obj: Object, key: String, default_value: String = "") -> String:
	var v: Variant = _p(obj, key, null)
	if v == null:
		return default_value
	return String(v)


func _log_missing_node(path: String, node: Node) -> void:
	if debug_logging and node == null:
		print("[SelectionHUD] Missing node at path: ", path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_apply_full_width_constraints")


func _apply_full_width_constraints() -> void:
	if not is_inside_tree():
		return

	_apply_horizontal_fill_fixes()

	var inner_w: float = max(120.0, size.x - 32.0)

	_force_fill_control(_root_vbox)
	_force_fill_control(_scroll_container)
	_force_fill_control(_scroll_content)
	_force_fill_control(_mode_tabs)
	_force_fill_control(_tile_tab)
	_force_fill_control(_building_tab)

	if _scroll_content:
		var cm: Vector2 = _scroll_content.custom_minimum_size
		if cm.x < inner_w:
			_scroll_content.custom_minimum_size = Vector2(inner_w, cm.y)

	if _mode_tabs:
		var cm2: Vector2 = _mode_tabs.custom_minimum_size
		if cm2.x < inner_w:
			_mode_tabs.custom_minimum_size = Vector2(inner_w, cm2.y)

	_force_fill_control(_tile_modifiers_section)
	_force_fill_control(_tile_modifiers_grid)
	_force_fill_control(_tile_resources_section)
	_force_fill_control(_tile_resources_list)
	_force_fill_control(_tile_effects_section)
	_force_fill_control(_tile_effects_list)

	_force_fill_control(_building_io_row)
	_force_fill_control(_building_inputs_list)
	_force_fill_control(_building_outputs_list)
	_force_fill_control(_building_buttons_row)


func _force_fill_control(c: Control) -> void:
	if c == null:
		return
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.offset_left = 0.0
	c.offset_right = 0.0

func _sync_coord_from_fragment(frag: Node) -> void:
	_current_coord = Vector2i.ZERO
	if frag == null or not is_instance_valid(frag):
		return

	var coord_v: Variant = _p(frag, "coord", null)
	if coord_v is Vector2i:
		_current_coord = coord_v as Vector2i
		return

	var ax_v: Variant = _p(frag, "axial", null)
	if ax_v is Vector2i:
		_current_coord = ax_v as Vector2i
		return

	var meta_ax: Variant = frag.get_meta("coord", null)
	if meta_ax is Vector2i:
		_current_coord = meta_ax as Vector2i

func _apply_readability_pass() -> void:
	var section_titles := [
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersHeader/TileModifiersTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileResourcesSection/TileResourcesTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileEffectsSection/TileEffectsTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/EquippedTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs/BuildingInputsTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs/BuildingOutputsTitle",
	]

	for p in section_titles:
		var lbl := get_node_or_null(p) as Label
		if lbl:
			lbl.add_theme_font_size_override("font_size", font_section_title)
