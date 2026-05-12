# res://scripts/world/selection_hud.gd
extends Panel

signal building_equip_requested(ax: Vector2i, building_id: String)
signal building_slot_requested(ax: Vector2i, slot_type: String, slot_index: int)

const HUD_KIND_ICON_PATHS := {
	"recruit event":   "res://assets/icons/modifiers/recruit.png",
	"structure":       "res://assets/icons/modifiers/structure.png",
	"dungeon / delve": "res://assets/icons/modifiers/dungeon.png",
	"hazard":          "res://assets/icons/modifiers/hazard.png",
}

@export var debug_logging: bool = false

@export var force_top_level: bool = true
@export var dock_to_bottom_left: bool = true
@export var dock_padding: Vector2 = Vector2(16, 16)
@export var force_on_top: bool = true

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

# Selection apply sequencing (fixes “need to click off/on”)
var _apply_seq: int = 0
var _last_applied_seq: int = -1


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
		if vp_node:
			var cb_vp := Callable(self, "_on_viewport_size_changed")
			if not vp_node.size_changed.is_connected(cb_vp):
				vp_node.size_changed.connect(cb_vp)

	_setup_mode_tabs()
	_apply_slot_styles()

	if _tile_modifiers_expand:
		var cb_mods := Callable(self, "_on_modifiers_expand_pressed")
		if not _tile_modifiers_expand.pressed.is_connected(cb_mods):
			_tile_modifiers_expand.pressed.connect(cb_mods)

	# Wire selection autoload
	if _selection and _selection.has_signal("fragment_selected"):
		var cb_sel: Callable = Callable(self, "_on_fragment_selected")
		if not _selection.is_connected("fragment_selected", cb_sel):
			_selection.connect("fragment_selected", cb_sel)
	else:
		if debug_logging:
			print("[SelectionHUD] Selection autoload missing or has no fragment_selected signal.")

	# Wire ConstructionSystem placed-building / project refresh.
	# ConstructionSystem emits building_changed when buildings or active projects mutate.
	if _construction != null and _construction.has_signal("building_changed"):
		var cb_building_changed := Callable(self, "_on_construction_building_changed")
		if not _construction.is_connected("building_changed", cb_building_changed):
			_construction.connect("building_changed", cb_building_changed)

	# Make sure tab visibility matches current tab
	if _mode_tabs:
		_on_tab_changed(_mode_tabs.current_tab, true)


func _get_drag_data(_at_position: Vector2) -> Variant:
	# HUD should NEVER be a drag source.
	if debug_logging:
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
	var tile_header_row: Control = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow") as Control
	if tile_header_row:
		tile_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tile_header_text: Control = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText") as Control
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

	var building_inputs_col: Control = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs") as Control
	if building_inputs_col:
		building_inputs_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _building_inputs_list:
		_building_inputs_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var building_outputs_col: Control = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs") as Control
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
		var cb_tab := Callable(self, "_on_tab_changed")
		if not _mode_tabs.tab_changed.is_connected(cb_tab):
			_mode_tabs.tab_changed.connect(cb_tab)

	if _tile_tab_button:
		var cb_tile := Callable(self, "_on_tile_tab_pressed")
		if not _tile_tab_button.pressed.is_connected(cb_tile):
			_tile_tab_button.pressed.connect(cb_tile)

	if _building_tab_button:
		var cb_build := Callable(self, "_on_building_tab_pressed")
		if not _building_tab_button.pressed.is_connected(cb_build):
			_building_tab_button.pressed.connect(cb_build)

	_sync_tab_buttons()
	_wire_slot_buttons()
	_on_tab_changed(_mode_tabs.current_tab, true)


func _fmt_mmss(seconds: float) -> String:
	var s := int(ceil(max(0.0, seconds)))
	var m := s / 60
	var r := s % 60
	return "%d:%02d" % [m, r]


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

	add_theme_font_size_override("font_size", font_body)
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
	btn.add_theme_font_size_override("font_size", font_small)


func _on_viewport_size_changed() -> void:
	if dock_to_bottom_left:
		_dock_bottom_left()
	_apply_full_width_constraints()


func _dock_bottom_left() -> void:
	if not is_inside_tree():
		return

	var vp: Vector2 = get_viewport_rect().size

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


func _on_tab_changed(_tab_index: int, reset_scroll: bool = true) -> void:
	if _mode_tabs == null:
		return

	_sync_tab_buttons()

	if _tile_tab:
		_tile_tab.visible = (_mode_tabs.current_tab == 0)
	if _building_tab:
		_building_tab.visible = (_mode_tabs.current_tab == 1)

	if reset_scroll and _scroll_container:
		_scroll_container.scroll_vertical = 0


func _on_tile_tab_pressed() -> void:
	if _mode_tabs:
		_mode_tabs.current_tab = 0
	_on_tab_changed(0, true)
	_sync_tab_buttons()


func _on_building_tab_pressed() -> void:
	if _mode_tabs:
		_mode_tabs.current_tab = 1
	_on_tab_changed(1, true)
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

	if is_inside_tree():
		_apply_fragment()

	call_deferred("_apply_fragment_seq", seq, fragment)


func _apply_fragment_seq(seq: int, frag: Node) -> void:
	if seq != _apply_seq:
		return

	if not is_inside_tree():
		call_deferred("_apply_fragment_seq", seq, frag)
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	for _i in range(6):
		await tree.process_frame
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


func _on_construction_building_changed(ax: Vector2i) -> void:
	if ax != _current_coord:
		return

	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	_apply_fragment()


func _apply_fragment() -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		visible = false
		return

	_sync_coord_from_fragment(_current_fragment)
	visible = true

	var first_apply_this_selection: bool = (_last_applied_seq != _apply_seq)
	_last_applied_seq = _apply_seq

	_enforce_layout_floors()

	_update_tile_tab()
	_update_building_tab()

	if _mode_tabs:
		_on_tab_changed(_mode_tabs.current_tab, first_apply_this_selection)

	if debug_logging:
		var biome_str: String = _get_biome_string(_current_fragment)
		var tier_val: int = _get_tile_tier(_current_fragment)
		var mods: Array = _get_modifiers_from_fragment(_current_fragment)
		var resources: Array = _get_resource_nodes_for_tile(_current_coord)
		var building_id: String = _get_equipped_building_id(_current_fragment)
		var modules: Array[String] = _get_equipped_modules(_current_fragment)
		print("[SelectionHUD] coord=%s biome=%s tier=%s mods=%d resources=%d building=%s modules=%s" % [
			_current_coord, biome_str, tier_val, mods.size(), resources.size(), building_id, modules
		])

	if dock_to_bottom_left and first_apply_this_selection:
		_dock_bottom_left()
		_apply_full_width_constraints()


# -------------------------
# Tile tab
# -------------------------
func _on_modifiers_expand_pressed() -> void:
	_mods_expanded = not _mods_expanded
	_update_tile_tab()


func _update_tile_tab() -> void:
	var biome_str: String = _get_biome_string(_current_fragment)
	var tile_name: String = _get_tile_name(_current_fragment, biome_str)
	var tier_val: int = _get_tile_tier(_current_fragment)
	var coord_text: String = "%d,%d" % [_current_coord.x, _current_coord.y]

	if _tile_icon:
		_tile_icon.custom_minimum_size = header_icon_size
		_tile_icon.texture = _get_biome_icon(_current_fragment, biome_str)

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

	var p1 := "res://assets/icons/biomes/%s.png" % key
	if ResourceLoader.exists(p1):
		return load(p1) as Texture2D

	var p2 := "res://assets/icons/biomes/%s_icon.png" % key
	if ResourceLoader.exists(p2):
		return load(p2) as Texture2D

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
		label.add_theme_font_size_override("font_size", font_body)
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
		var name_str: String = String(d.get("name", d.get("detail", ""))).strip_edges()
		if name_str != "":
			return name_str

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
		var kind_raw: String = String(d.get("kind", ""))
		var kind: String = kind_raw.strip_edges().to_lower().replace("_", " ")
		var skill: String = String(d.get("skill", "")).strip_edges().to_lower()

		if kind == "resource spawn" and skill != "":
			var p0 := "res://assets/icons/modifiers/%s_node.png" % skill
			if ResourceLoader.exists(p0):
				return load(p0) as Texture2D

		if HUD_KIND_ICON_PATHS.has(kind):
			var p1: String = String(HUD_KIND_ICON_PATHS[kind])
			if ResourceLoader.exists(p1):
				return load(p1) as Texture2D

	return null


func _modifier_to_tooltip(mod: Variant) -> String:
	if mod is Dictionary:
		var d: Dictionary = mod as Dictionary
		var name_str: String = String(d.get("name", d.get("detail", ""))).strip_edges()
		var kind: String = String(d.get("kind", "")).strip_edges()
		var rarity: String = String(d.get("rarity", "")).strip_edges()
		var skill: String = String(d.get("skill", "")).strip_edges()

		var bits: Array[String] = []
		if name_str != "":
			bits.append(name_str)
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


# -------------------------
# Resource nodes
# -------------------------
func _get_resource_nodes_for_tile(coord: Vector2i) -> Array:
	if _resource_nodes != null:
		if _resource_nodes.has_method("get_nodes_for_tile"):
			var v1: Variant = _resource_nodes.call("get_nodes_for_tile", coord)
			if v1 is Array:
				return v1 as Array

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
		var kind: String = String(md.get("kind", "")).strip_edges().to_lower().replace("_", " ")
		if kind != "resource spawn":
			continue

		var detail: String = String(md.get("name", md.get("detail", ""))).strip_edges()
		var skill: String = String(md.get("skill", "")).strip_edges()

		nodes.append({
			"detail": detail,
			"skill": skill
		})

	return nodes


func _build_resource_entries(nodes: Array) -> Array:
	var totals: Dictionary = {}
	var actives: Dictionary = {}
	var has_charges: Dictionary = {}
	var left_charges: Dictionary = {}
	var max_charges: Dictionary = {}
	var cooldown_min: Dictionary = {}
	var display: Dictionary = {}
	var icons: Dictionary = {}

	for n_v in nodes:
		if typeof(n_v) != TYPE_DICTIONARY:
			continue

		var n: Dictionary = n_v as Dictionary

		var skill: String = String(n.get("skill", "")).strip_edges()
		var detail: String = String(n.get("detail", "")).strip_edges()
		var label: String = detail if detail != "" else skill
		if label == "":
			continue

		var skill_l: String = skill.to_lower()
		var key: String = "%s|%s" % [skill_l, label]

		display[key] = label
		if not icons.has(key):
			icons[key] = _resource_icon_for_skill(skill)

		totals[key] = int(totals.get(key, 0)) + 1

		var dep: bool = bool(n.get("depleted", false))
		actives[key] = int(actives.get(key, 0)) + (0 if dep else 1)

		if dep and n.has("cooldown_s"):
			var cd: float = float(n.get("cooldown_s", 0.0))
			if cd > 0.0:
				if not cooldown_min.has(key):
					cooldown_min[key] = cd
				else:
					cooldown_min[key] = min(float(cooldown_min[key]), cd)

		var explicit: bool = (n.has("charges_left") or n.has("max_charges") or n.has("charges_max") or n.has("charges"))
		if explicit:
			has_charges[key] = true

			var left: int = 0
			if n.has("charges_left"):
				left = int(n.get("charges_left", 0))
			elif n.has("charges"):
				left = int(n.get("charges", 0))

			var maxc: int = 0
			if n.has("max_charges"):
				maxc = int(n.get("max_charges", left))
			elif n.has("charges_max"):
				maxc = int(n.get("charges_max", left))
			else:
				maxc = left

			left_charges[key] = int(left_charges.get(key, 0)) + max(0, left)
			max_charges[key] = int(max_charges.get(key, 0)) + max(0, maxc)

	var keys: Array = display.keys()
	keys.sort_custom(func(a, b):
		return String(display[a]) < String(display[b])
	)

	var entries: Array = []
	for k_v in keys:
		var k: String = String(k_v)
		var label2: String = String(display.get(k, ""))

		var tex: Texture2D = null
		var icon_v: Variant = icons.get(k, null)
		if icon_v is Texture2D:
			tex = icon_v as Texture2D

		var line: String = label2
		var t: int = int(totals.get(k, 0))
		var a: int = int(actives.get(k, 0))

		if bool(has_charges.get(k, false)) and int(max_charges.get(k, 0)) > 0:
			var lc: int = int(left_charges.get(k, 0))
			var mc: int = int(max_charges.get(k, 0))
			line = "%s — %d/%d charges" % [label2, lc, mc]
			if lc <= 0 and cooldown_min.has(k):
				line = "%s — 0/%d charges ⏳ %s" % [label2, mc, _fmt_mmss(float(cooldown_min[k]))]
		else:
			if t > 1:
				line = "%s ×%d" % [label2, t]
			if a <= 0 and cooldown_min.has(k):
				line = "%s%s ⏳ %s" % [
					label2,
					(" ×%d —" % t) if t > 1 else " —",
					_fmt_mmss(float(cooldown_min[k]))
				]

		entries.append({
			"text": line,
			"icon": tex,
			"header": false
		})

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

	if icon_tex == null:
		icon_holder.modulate = Color(1, 1, 1, 0)

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
		label.add_theme_font_size_override("font_size", font_body)
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
# Building tab
# -------------------------
func _on_building_slot_pressed() -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	emit_signal("building_slot_requested", _current_coord, "base", 0)


func _on_module_slot_pressed(slot_index: int) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	emit_signal("building_slot_requested", _current_coord, "module", slot_index)


func _update_building_tab() -> void:
	# Hide legacy chips row (kept for scene compatibility)
	if _building_chips_row:
		_building_chips_row.visible = false

	var placed: Dictionary = _get_placed_building_state()
	var using_placed_building := not placed.is_empty()

	var building_id: String = ""
	var module_ids: Array[String] = []

	if using_placed_building:
		building_id = String(placed.get("base_item_id", placed.get("recipe_id", ""))).strip_edges()
		module_ids = _get_module_ids_from_placed_state(placed)
	else:
		building_id = _get_equipped_building_id(_current_fragment)
		module_ids = _get_equipped_modules(_current_fragment)

	# Slot icons
	_set_button_icon_from_id(_building_slot, building_id)

	for i in range(_module_slots.size()):
		var id: String = ""
		if i >= 0 and i < module_ids.size():
			id = module_ids[i]
		_set_button_icon_from_id(_module_slots[i], id)

	# No building equipped/placed
	if building_id.strip_edges() == "":
		if _building_name_label:
			_building_name_label.text = "No building installed"
			_building_name_label.add_theme_font_size_override("font_size", font_section_title)

		if _building_status_label:
			_building_status_label.text = "Drag a crafted building item from the bank into the building slot."
			_building_status_label.add_theme_font_size_override("font_size", font_body)

		if _building_tier_label:
			_building_tier_label.text = ""
			_building_tier_label.add_theme_font_size_override("font_size", font_small)

		if _building_inputs_list:
			_clear_container(_building_inputs_list)
			_building_inputs_list.add_child(_build_list_row("—", null, false))

		if _building_outputs_list:
			_clear_container(_building_outputs_list)
			_building_outputs_list.add_child(_build_list_row("—", null, false))

		_set_section_visible(_building_io_row, true)
		_set_buttons_enabled(_building_buttons_row, false)
		return

	var display_name: String = ""
	var tier_val: int = 0
	var status: String = ""
	var in_entries: Array = []
	var out_entries: Array = []

	if using_placed_building:
		display_name = String(placed.get("label", placed.get("building", building_id))).strip_edges()
		if display_name == "":
			display_name = building_id

		tier_val = int(placed.get("tier", 0))

		var linked_skill := String(placed.get("linked_skill", "")).strip_edges()
		if linked_skill != "":
			status = "Installed. Supports %s." % linked_skill.capitalize()
		else:
			status = "Installed."

		var project_status := _active_project_status_short(_current_coord)
		if project_status != "":
			status += " %s" % project_status

		in_entries = _io_to_entries(placed.get("inputs", []))
		out_entries = _placed_building_detail_entries(placed, _current_coord)
	else:
		var def: Dictionary = _get_building_def(building_id)

		if def.has("name"):
			display_name = String(def.get("name", "")).strip_edges()
		if display_name == "":
			display_name = building_id

		if def.has("tier"):
			tier_val = int(def.get("tier", 0))
		else:
			var tfrag: Variant = _p(_current_fragment, "building_tier", null)
			if tfrag != null:
				tier_val = int(tfrag)

		status = "Equipped"
		var sfrag: Variant = _p(_current_fragment, "building_status", null)
		if sfrag != null and String(sfrag).strip_edges() != "":
			status = String(sfrag)

		in_entries = _io_to_entries(def.get("inputs", null))
		out_entries = _io_to_entries(def.get("outputs", null))

		if in_entries.is_empty():
			in_entries = _io_to_entries(def.get("in", null))
		if out_entries.is_empty():
			out_entries = _io_to_entries(def.get("out", null))
		if out_entries.is_empty():
			out_entries = _io_to_entries(def.get("produces", null))

	if _building_name_label:
		_building_name_label.text = display_name
		_building_name_label.add_theme_font_size_override("font_size", font_section_title)

	if _building_status_label:
		_building_status_label.text = status
		_building_status_label.add_theme_font_size_override("font_size", font_body)

	if _building_tier_label:
		_building_tier_label.text = ("T%d" % tier_val) if tier_val > 0 else ""
		_building_tier_label.add_theme_font_size_override("font_size", font_small)

	if using_placed_building:
		_populate_entries(_building_inputs_list, in_entries, "Original kit cost unavailable")
		_populate_entries(_building_outputs_list, out_entries, "No modules or active project")
	else:
		_populate_entries(_building_inputs_list, in_entries, "No inputs")
		_populate_entries(_building_outputs_list, out_entries, "No outputs")

	_set_section_visible(_building_io_row, true)
	_set_buttons_enabled(_building_buttons_row, true)


func _get_module_ids_from_placed_state(placed: Dictionary) -> Array[String]:
	var out: Array[String] = []

	var modules_v: Variant = placed.get("modules", [])
	if not (modules_v is Array):
		return out

	for m_v in modules_v as Array:
		var module_id := _module_id_from_state(m_v)
		if module_id != "":
			out.append(module_id)

	return out


func _module_id_from_state(m_v: Variant) -> String:
	if m_v is Dictionary:
		var m: Dictionary = m_v as Dictionary
		return String(m.get("id", m.get("module_id", ""))).strip_edges()

	return String(m_v).strip_edges()


func _module_level_from_state(m_v: Variant) -> int:
	if m_v is Dictionary:
		var m: Dictionary = m_v as Dictionary
		return max(1, int(m.get("level", 1)))

	return 1


func _module_label(module_id: String) -> String:
	var clean := module_id.strip_edges()
	if clean == "":
		return ""

	return _resolve_item_label(StringName(clean))


func _placed_building_detail_entries(placed: Dictionary, ax: Vector2i) -> Array:
	var entries: Array = []

	entries.append({
		"text": "Modules",
		"icon": null,
		"header": true,
	})

	var modules: Array = []
	var modules_v: Variant = placed.get("modules", [])
	if modules_v is Array:
		modules = modules_v as Array

	var tier_val := int(placed.get("tier", 1))
	var slot_count := _module_slot_count_for_tier(tier_val)

	for i in range(slot_count):
		if i < modules.size():
			var m_v: Variant = modules[i]
			var module_id := _module_id_from_state(m_v)
			var level := _module_level_from_state(m_v)

			if module_id != "":
				entries.append({
					"text": "Slot %d: %s — Level %d" % [
						i + 1,
						_module_label(module_id),
						level
					],
					"icon": _resolve_item_icon(StringName(module_id)),
					"header": false,
				})
			else:
				entries.append({
					"text": "Slot %d: Empty" % [i + 1],
					"icon": null,
					"header": false,
				})
		else:
			entries.append({
				"text": "Slot %d: Empty" % [i + 1],
				"icon": null,
				"header": false,
			})

	var max_visible_slots := maxi(slot_count, _module_slots.size())
	for locked_i in range(slot_count, max_visible_slots):
		entries.append({
			"text": "Slot %d: Locked" % [locked_i + 1],
			"icon": null,
			"header": false,
		})

	var project_text := _describe_active_construction_project(ax)
	if project_text != "":
		entries.append({
			"text": "",
			"icon": null,
			"header": false,
		})

		entries.append({
			"text": "Construction Project",
			"icon": null,
			"header": true,
		})

		for line in project_text.split("\n", false):
			entries.append({
				"text": String(line),
				"icon": null,
				"header": false,
			})

	return entries


func _module_slot_count_for_tier(tier: int) -> int:
	if _construction != null and _construction.has_method("get_module_slot_count_for_tier"):
		return max(0, int(_construction.call("get_module_slot_count_for_tier", tier)))

	# Locked construction rule fallback:
	# T1 = 1 module slot, T2 = 2, T3 = 3.
	return clampi(tier, 1, 3)


func _active_project_status_short(ax: Vector2i) -> String:
	if _construction == null:
		return ""

	if not _construction.has_method("get_active_project"):
		return ""

	var project_v: Variant = _construction.call("get_active_project", ax)
	if not (project_v is Dictionary):
		return ""

	var project: Dictionary = project_v as Dictionary
	if project.is_empty():
		return ""

	var done := int(project.get("successful_actions", 0))
	var needed := int(project.get("required_successes", 0))
	if needed > 0:
		return "Project %d/%d." % [done, needed]

	return "Project active."


func _describe_active_construction_project(ax: Vector2i) -> String:
	if _construction == null:
		return ""

	if not _construction.has_method("get_active_project"):
		return ""

	var project_v: Variant = _construction.call("get_active_project", ax)
	if not (project_v is Dictionary):
		return ""

	var project: Dictionary = project_v as Dictionary
	if project.is_empty():
		return "No active construction project."

	var lines: Array[String] = []

	var ptype := String(project.get("type", project.get("project_type", ""))).strip_edges()
	var title := String(project.get("label", "")).strip_edges()

	if title == "":
		match ptype:
			"upgrade_building":
				title = "Upgrade to Tier %d" % int(project.get("target_tier", 0))
			"install_module":
				var module_id := String(project.get("module_id", "")).strip_edges()
				if module_id != "":
					title = "Install %s" % _module_label(module_id)
				else:
					title = "Install Module"
			"upgrade_module":
				var module_id2 := String(project.get("module_id", "")).strip_edges()
				var target_level := int(project.get("target_level", 0))
				if module_id2 != "" and target_level > 0:
					title = "Upgrade %s to Level %d" % [_module_label(module_id2), target_level]
				elif module_id2 != "":
					title = "Upgrade %s" % _module_label(module_id2)
				else:
					title = "Upgrade Module"
			_:
				title = "Construction Project"

	lines.append("Active Project: %s" % title)

	var required := int(project.get("required_successes", 1))
	lines.append("Progress: %d / %d successes" % [
		int(project.get("successful_actions", 0)),
		max(1, required)
	])

	lines.append("Failures: %d" % int(project.get("failed_actions", 0)))

	var status := String(project.get("status", "working")).strip_edges()
	if status != "":
		lines.append("Status: %s" % status.replace("_", " ").capitalize())

	var worker := int(project.get("assigned_worker", -1))
	if worker >= 0:
		lines.append("Assigned Worker: #%d" % worker)

	var req := int(project.get("req_con_lv", project.get("construction_level_req", 0)))
	if req > 0:
		lines.append("Required Construction: %d" % req)

	var fail_chance := float(project.get("fail_chance", 999.0))
	if fail_chance != 999.0:
		if fail_chance < 0.0:
			lines.append("Failure Chance: Cannot attempt")
		else:
			lines.append("Failure Chance: %d%%" % int(round(fail_chance * 100.0)))

	return "\n".join(lines)


func _set_button_icon_from_id(btn: Button, id: String) -> void:
	if btn == null:
		return

	var clean: String = id.strip_edges()
	if clean == "":
		btn.icon = null
		btn.tooltip_text = "Empty"
		return

	var tex: Texture2D = _resolve_item_icon(StringName(clean))
	btn.icon = tex
	btn.tooltip_text = clean


func _get_placed_building_state() -> Dictionary:
	if _construction == null:
		return {}

	if not _construction.has_method("get_building_at"):
		return {}

	var v: Variant = _construction.call("get_building_at", _current_coord)
	if v is Dictionary:
		return v as Dictionary

	return {}


func _get_equipped_building_id(frag: Node) -> String:
	var placed := _get_placed_building_state()
	if not placed.is_empty():
		var base_item := String(placed.get("base_item_id", "")).strip_edges()
		if base_item != "":
			return base_item

		var recipe_id := String(placed.get("recipe_id", "")).strip_edges()
		if recipe_id != "":
			return recipe_id

	if frag == null or not is_instance_valid(frag):
		return ""

	var keys: Array[String] = [
		"equipped_building_id",
		"building_id",
		"equipped_building",
		"building",
		"base_building",
	]

	for k in keys:
		var v: Variant = frag.get(k)
		if v != null:
			var s: String = String(v).strip_edges()
			if s != "":
				return s

	var mv: Variant = _meta(frag, "building_id", null)
	if mv != null:
		var ms: String = String(mv).strip_edges()
		if ms != "":
			return ms

	return ""


func _get_equipped_modules(frag: Node) -> Array[String]:
	var placed := _get_placed_building_state()
	if not placed.is_empty():
		return _get_module_ids_from_placed_state(placed)

	var out: Array[String] = []
	if frag == null or not is_instance_valid(frag):
		return out

	var v: Variant = null
	var keys: Array[String] = ["equipped_modules", "modules", "module_ids"]

	for k in keys:
		var vv: Variant = frag.get(k)
		if vv is Array:
			v = vv
			break

	if v is Array:
		for it in (v as Array):
			var s2: String = String(it).strip_edges()
			if s2 != "":
				out.append(s2)

	return out


func _get_building_def(building_id: String) -> Dictionary:
	var out: Dictionary = {}
	var id: String = building_id.strip_edges()
	if id == "":
		return out

	if _construction != null:
		if _construction.has_method("get_building_def"):
			var dv: Variant = _construction.call("get_building_def", id)
			if dv is Dictionary:
				return dv as Dictionary

		if _construction.has_method("get_def"):
			var dv2: Variant = _construction.call("get_def", id)
			if dv2 is Dictionary:
				return dv2 as Dictionary

		if _construction.has_method("get_building_item_info"):
			var info_v: Variant = _construction.call("get_building_item_info", StringName(id))
			if info_v is Dictionary and not (info_v as Dictionary).is_empty():
				return info_v as Dictionary

		if _construction.has_method("get_recipe_by_id"):
			var rec_v: Variant = _construction.call("get_recipe_by_id", StringName(id))
			if rec_v is Dictionary and not (rec_v as Dictionary).is_empty():
				return rec_v as Dictionary

		var tbl_v: Variant = _construction.get("BUILDINGS")
		if tbl_v is Dictionary:
			var tbl: Dictionary = tbl_v as Dictionary
			if tbl.has(id) and tbl[id] is Dictionary:
				return tbl[id] as Dictionary

	return out


func _io_to_entries(io_v: Variant) -> Array:
	var entries: Array = []
	if io_v == null:
		return entries

	# Dictionary: { "item_id": qty, ... }
	if io_v is Dictionary:
		var d: Dictionary = io_v as Dictionary
		for k_v in d.keys():
			var id: String = String(k_v).strip_edges()
			var qty: int = int(d.get(k_v, 0))
			if id == "":
				continue
			var icon_tex: Texture2D = _resolve_item_icon(StringName(id))
			var txt: String = "%s ×%d" % [_resolve_item_label(StringName(id)), max(1, qty)]
			entries.append({"text": txt, "icon": icon_tex, "header": false})
		return entries

	# Array: could be ["id", ...] OR [{id, qty}, ...]
	if io_v is Array:
		for e in (io_v as Array):
			if e is Dictionary:
				var ed: Dictionary = e as Dictionary
				var id2: String = String(ed.get("id", ed.get("item", ""))).strip_edges()
				var qty2: int = int(ed.get("qty", ed.get("count", 1)))
				if id2 == "":
					continue
				var icon2: Texture2D = _resolve_item_icon(StringName(id2))
				var txt2: String = "%s ×%d" % [_resolve_item_label(StringName(id2)), max(1, qty2)]
				entries.append({"text": txt2, "icon": icon2, "header": false})
			else:
				var id3: String = String(e).strip_edges()
				if id3 == "":
					continue
				var icon3: Texture2D = _resolve_item_icon(StringName(id3))
				entries.append({"text": _resolve_item_label(StringName(id3)), "icon": icon3, "header": false})
		return entries

	return entries


func _resolve_item_label(id: StringName) -> String:
	if _items and _items.has_method("is_valid") and _items.has_method("display_name"):
		var ok_v: Variant = _items.call("is_valid", id)
		if bool(ok_v):
			return String(_items.call("display_name", id))

	if _construction and _construction.has_method("get_part_display_name"):
		var label_v: Variant = _construction.call("get_part_display_name", String(id))
		var label := String(label_v).strip_edges()
		if label != "":
			return label

	return String(id)


# -------------------------
# Building placement
# -------------------------
func request_place_building_item(item_id: StringName) -> void:
	if _construction == null:
		push_warning("[SelectionHUD] Cannot place building: ConstructionSystem missing.")
		return

	if not _construction.has_method("get_place_building_block_reason"):
		push_warning("[SelectionHUD] Cannot place building: ConstructionSystem missing get_place_building_block_reason().")
		return

	if not _construction.has_method("place_building_item_at"):
		push_warning("[SelectionHUD] Cannot place building: ConstructionSystem missing place_building_item_at().")
		return

	var block_reason: String = String(_construction.call(
		"get_place_building_block_reason",
		_current_coord,
		item_id
	))

	if block_reason != "":
		push_warning("[SelectionHUD] Cannot place building: %s" % block_reason)
		return

	var item_name := _resolve_item_label(item_id)

	var dialog := ConfirmationDialog.new()
	dialog.title = "Install Building"
	dialog.dialog_text = "Install %s on this tile?\n\nThis will consume 1x %s from your bank." % [
		item_name,
		item_name,
	]

	add_child(dialog)

	dialog.confirmed.connect(func() -> void:
		var placed := bool(_construction.call("place_building_item_at", _current_coord, item_id))
		if placed:
			_apply_fragment()
		dialog.queue_free()
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	dialog.popup_centered()


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


func _meta(obj: Object, key: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value

	if obj.has_meta(StringName(key)):
		return obj.get_meta(StringName(key))

	return default_value


func _clear_container(c: Node) -> void:
	if c == null:
		return

	for child in c.get_children():
		child.queue_free()


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

	var meta_ax: Variant = _meta(frag, "coord", null)
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

	if _tile_modifiers_expand:
		_tile_modifiers_expand.add_theme_font_size_override("font_size", font_small)

	if _building_name_label:
		_building_name_label.add_theme_font_size_override("font_size", font_section_title)
	if _building_status_label:
		_building_status_label.add_theme_font_size_override("font_size", font_body)
	if _building_tier_label:
		_building_tier_label.add_theme_font_size_override("font_size", font_small)

	if _tile_name_label:
		_tile_name_label.add_theme_font_size_override("font_size", font_tile_title)
	if _tile_coord_label:
		_tile_coord_label.add_theme_font_size_override("font_size", font_small)
	if _tile_tier_label:
		_tile_tier_label.add_theme_font_size_override("font_size", font_small)
