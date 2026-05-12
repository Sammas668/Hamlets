# res://scripts/world/selection_hud.gd
extends Panel

signal building_equip_requested(ax: Vector2i, building_id: String)
signal building_slot_requested(ax: Vector2i, slot_type: String, slot_index: int)

const HUD_KIND_ICON_PATHS := {
	"recruit event": "res://assets/icons/modifiers/recruit.png",
	"structure": "res://assets/icons/modifiers/structure.png",
	"dungeon / delve": "res://assets/icons/modifiers/dungeon.png",
	"hazard": "res://assets/icons/modifiers/hazard.png",
}

const MAX_MODIFIERS_COLLAPSED: int = 6
const MODIFIER_ICON_SIZE: Vector2 = Vector2(30.0, 30.0)

@export var debug_logging: bool = false

@export var force_top_level: bool = true
@export var dock_to_bottom_left: bool = true
@export var dock_padding: Vector2 = Vector2(16.0, 16.0)
@export var force_on_top: bool = true

@export var min_panel_size: Vector2 = Vector2(560.0, 430.0)
@export var min_scroll_height: float = 300.0

@export var font_tile_title: int = 28
@export var font_section_title: int = 22
@export var font_body: int = 18
@export var font_small: int = 16

@export var header_icon_size: Vector2 = Vector2(52.0, 52.0)
@export var list_icon_size: Vector2 = Vector2(24.0, 24.0)
@export var list_row_sep: int = 8

var _current_fragment: Node = null
var _current_coord: Vector2i = Vector2i.ZERO
var _mods_expanded: bool = false

var _root_vbox: Control = null
var _scroll_content: Control = null
var _mode_tabs: TabContainer = null
var _mode_header: Control = null
var _tile_tab_button: Button = null
var _building_tab_button: Button = null
var _scroll_container: ScrollContainer = null
var _tile_tab: Control = null
var _building_tab: Control = null

var _tile_header_row: Control = null
var _tile_header_text: Control = null
var _tile_icon: TextureRect = null
var _tile_name_label: Label = null
var _tile_coord_label: Label = null
var _tile_tier_chip: Control = null
var _tile_tier_label: Label = null

var _tile_modifiers_section: Control = null
var _tile_modifiers_header: HBoxContainer = null
var _tile_modifiers_header_spacer: Control = null
var _tile_modifiers_title: Label = null
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

var _building_chips_row: Control = null
var _building_io_row: Control = null
var _building_inputs_title: Label = null
var _building_outputs_title: Label = null
var _building_inputs_list: VBoxContainer = null
var _building_outputs_list: VBoxContainer = null
var _building_buttons_row: Control = null

var _base_slot: Button = null
var _module_slots: Array[Button] = []

var _selection: Node = null
var _resource_nodes: Node = null
var _construction: Node = null
var _items: Node = null

var _apply_seq: int = 0
var _last_applied_seq: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	if force_on_top:
		z_as_relative = false
		z_index = 2000

	_selection = get_node_or_null("/root/Selection")
	_resource_nodes = get_node_or_null("/root/ResourceNodes")
	_construction = get_node_or_null("/root/ConstructionSystem")
	_items = get_node_or_null("/root/Items")

	if force_top_level:
		top_level = true
		set_anchors_preset(Control.PRESET_TOP_LEFT, true)

	_apply_panel_style()
	_cache_nodes()
	_hide_duplicate_scene_nodes()
	_apply_compact_layout_defaults()
	_apply_readability_pass()
	_prepare_tile_tab_layout()
	_enforce_layout_floors()

	call_deferred("_apply_full_width_constraints")

	if dock_to_bottom_left:
		call_deferred("_dock_bottom_left")
		var vp_node: Viewport = get_viewport()
		if vp_node != null:
			var cb_vp: Callable = Callable(self, "_on_viewport_size_changed")
			if not vp_node.size_changed.is_connected(cb_vp):
				vp_node.size_changed.connect(cb_vp)

	_setup_mode_tabs()
	_apply_slot_styles()

	if _tile_modifiers_expand != null:
		var cb_mods: Callable = Callable(self, "_on_modifiers_expand_pressed")
		if not _tile_modifiers_expand.pressed.is_connected(cb_mods):
			_tile_modifiers_expand.pressed.connect(cb_mods)

	if _selection != null and _selection.has_signal("fragment_selected"):
		var cb_sel: Callable = Callable(self, "_on_fragment_selected")
		if not _selection.is_connected("fragment_selected", cb_sel):
			_selection.connect("fragment_selected", cb_sel)

	if _construction != null and _construction.has_signal("building_changed"):
		var cb_building_changed: Callable = Callable(self, "_on_construction_building_changed")
		if not _construction.is_connected("building_changed", cb_building_changed):
			_construction.connect("building_changed", cb_building_changed)

	if _mode_tabs != null:
		_on_tab_changed(_mode_tabs.current_tab, true)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.gui_cancel_drag()

	return null


# -------------------------------------------------------------------
# Node caching / layout
# -------------------------------------------------------------------

func _cache_nodes() -> void:
	_root_vbox = get_node_or_null("Margin/RootVBox") as Control
	_scroll_container = get_node_or_null("Margin/RootVBox/Scroll") as ScrollContainer
	_scroll_content = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent") as Control
	_mode_tabs = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs") as TabContainer

	_tile_tab = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab") as Control
	_building_tab = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab") as Control

	_mode_header = get_node_or_null("Margin/RootVBox/ModeHeader") as Control
	_tile_tab_button = get_node_or_null("Margin/RootVBox/ModeHeader/TileTabButton") as Button
	_building_tab_button = get_node_or_null("Margin/RootVBox/ModeHeader/BuildingTabButton") as Button

	_tile_header_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow") as Control
	_tile_header_text = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText") as Control
	_tile_icon = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileIcon") as TextureRect
	_tile_name_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText/TileName") as Label
	_tile_coord_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText/TileCoord") as Label
	_tile_tier_chip = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileTierChip") as Control
	_tile_tier_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileTierChip/TileTierLabel") as Label

	_tile_modifiers_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection") as Control
	_tile_modifiers_header = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersHeader") as HBoxContainer
	_tile_modifiers_title = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersHeader/TileModifiersTitle") as Label
	_tile_modifiers_expand = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersHeader/TileModifiersExpand") as Button
	_tile_modifiers_grid = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersGrid") as GridContainer

	_tile_resources_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileResourcesSection") as Control
	_tile_resources_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileResourcesSection/TileResourcesList") as VBoxContainer

	_tile_effects_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileEffectsSection") as Control
	_tile_effects_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileEffectsSection/TileEffectsList") as VBoxContainer

	_building_slot = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSlot") as Button
	_building_name_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingName") as Label
	_building_status_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingStatus") as Label
	_building_tier_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingTierChip/BuildingTierLabel") as Label

	_building_chips_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow") as Control
	_building_io_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow") as Control
	_building_inputs_title = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs/BuildingInputsTitle") as Label
	_building_outputs_title = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs/BuildingOutputsTitle") as Label
	_building_inputs_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs/BuildingInputsList") as VBoxContainer
	_building_outputs_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs/BuildingOutputsList") as VBoxContainer
	_building_buttons_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingButtonsRow") as Control

	_base_slot = _building_slot

	_module_slots.clear()
	for i in range(1, 4):
		var btn: Button = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/ModulesRow/ModuleSlot%d" % i) as Button
		if btn != null:
			_module_slots.append(btn)

	var labels: Array = [
		_tile_name_label,
		_tile_coord_label,
		_building_name_label,
		_building_status_label,
	]

	for label_v in labels:
		var label: Label = label_v as Label
		if label != null:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.clip_text = false


func _hide_duplicate_scene_nodes() -> void:
	var duplicate_paths: Array[String] = [
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipIntegrity/ChipIntegrityLabel2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipIntegrity2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs/BuildingInputsTitle2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs/BuildingInputsList2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs/BuildingOutputsTitle2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs/BuildingOutputsList2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingButtonsRow2",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileIcon2",
	]

	for p in duplicate_paths:
		var n: CanvasItem = get_node_or_null(p) as CanvasItem
		if n != null:
			n.visible = false


func _apply_compact_layout_defaults() -> void:
	custom_minimum_size = min_panel_size
	size = min_panel_size

	var margin: MarginContainer = get_node_or_null("Margin") as MarginContainer
	if margin != null:
		margin.custom_minimum_size = Vector2.ZERO
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)

	if _root_vbox != null:
		_root_vbox.add_theme_constant_override("separation", 8)

	if _mode_header != null:
		_mode_header.custom_minimum_size = Vector2(0.0, 34.0)

	if _scroll_container != null:
		_scroll_container.custom_minimum_size = Vector2(0.0, min_scroll_height)
		_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	if _scroll_content != null:
		_scroll_content.custom_minimum_size = Vector2.ZERO
		_scroll_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if _mode_tabs != null:
		_mode_tabs.custom_minimum_size = Vector2.ZERO
		_mode_tabs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if _tile_modifiers_grid != null:
		_tile_modifiers_grid.columns = 4

	if _building_chips_row != null:
		_building_chips_row.visible = false

	if _building_buttons_row != null:
		_building_buttons_row.visible = false

	_apply_building_details_layout()
	_prepare_tile_tab_layout()
	_apply_square_slot_button(_building_slot, 56.0)

	for slot in _module_slots:
		_apply_square_slot_button(slot, 44.0)


func _prepare_tile_tab_layout() -> void:
	_set_fill_control(_tile_tab)
	_set_fill_control(_tile_header_row)
	_set_fill_control(_tile_header_text)

	if _tile_icon != null:
		_tile_icon.custom_minimum_size = header_icon_size
		_tile_icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_tile_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tile_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tile_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if _tile_tier_chip != null:
		_tile_tier_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		_tile_tier_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tile_tier_chip.custom_minimum_size = Vector2.ZERO

	if _tile_name_label != null:
		_tile_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tile_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tile_name_label.clip_text = false

	if _tile_coord_label != null:
		_tile_coord_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tile_coord_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tile_coord_label.clip_text = false

	_set_fill_control(_tile_modifiers_section)

	if _tile_modifiers_header != null:
		_tile_modifiers_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tile_modifiers_header.add_theme_constant_override("separation", 8)

	_tile_modifiers_header_spacer = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersHeader/TileModifiersHeaderSpacer") as Control

	if _tile_modifiers_header != null and _tile_modifiers_expand != null and _tile_modifiers_header_spacer == null:
		_tile_modifiers_header_spacer = Control.new()
		_tile_modifiers_header_spacer.name = "TileModifiersHeaderSpacer"

		var insert_index: int = _tile_modifiers_expand.get_index()
		_tile_modifiers_header.add_child(_tile_modifiers_header_spacer)
		_tile_modifiers_header.move_child(_tile_modifiers_header_spacer, insert_index)

	if _tile_modifiers_title != null:
		_tile_modifiers_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_tile_modifiers_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tile_modifiers_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		_tile_modifiers_title.clip_text = false

	if _tile_modifiers_header_spacer != null:
		_tile_modifiers_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tile_modifiers_header_spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tile_modifiers_header_spacer.custom_minimum_size = Vector2.ZERO

	if _tile_modifiers_expand != null:
		_tile_modifiers_expand.custom_minimum_size = Vector2(72.0, 28.0)
		_tile_modifiers_expand.size_flags_horizontal = Control.SIZE_SHRINK_END
		_tile_modifiers_expand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tile_modifiers_expand.clip_text = false

	if _tile_modifiers_grid != null:
		_tile_modifiers_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tile_modifiers_grid.columns = 4

	_set_fill_control(_tile_resources_section)
	_set_fill_control(_tile_resources_list)
	_set_fill_control(_tile_effects_section)
	_set_fill_control(_tile_effects_list)


func _apply_building_details_layout() -> void:
	var inputs_col: Control = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs") as Control
	var outputs_col: Control = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs") as Control

	if _building_io_row != null:
		_building_io_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_building_io_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_building_io_row.custom_minimum_size = Vector2.ZERO
		_building_io_row.add_theme_constant_override("separation", 0)

	if inputs_col != null:
		inputs_col.visible = true
		inputs_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inputs_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		inputs_col.custom_minimum_size = Vector2.ZERO

	if outputs_col != null:
		outputs_col.visible = false
		outputs_col.size_flags_horizontal = Control.SIZE_SHRINK_END
		outputs_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		outputs_col.custom_minimum_size = Vector2.ZERO

	if _building_inputs_title != null:
		_building_inputs_title.text = "Building Details"
		_building_inputs_title.visible = true

	if _building_outputs_title != null:
		_building_outputs_title.visible = false

	if _building_inputs_list != null:
		_building_inputs_list.visible = true
		_building_inputs_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_building_inputs_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_building_inputs_list.custom_minimum_size = Vector2.ZERO

	if _building_outputs_list != null:
		_building_outputs_list.visible = false
		_building_outputs_list.custom_minimum_size = Vector2.ZERO


func _apply_square_slot_button(btn: Button, slot_px: float) -> void:
	if btn == null:
		return

	var s: Vector2 = Vector2(slot_px, slot_px)

	btn.custom_minimum_size = s
	btn.size = s
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.text = ""
	btn.clip_text = true
	btn.expand_icon = true


func _apply_horizontal_fill_fixes() -> void:
	_prepare_tile_tab_layout()
	_apply_building_details_layout()

	var controls: Array = [
		_root_vbox,
		_scroll_container,
		_scroll_content,
		_mode_tabs,
		_tile_tab,
		_building_tab,
		_tile_modifiers_section,
		_tile_modifiers_grid,
		_tile_resources_section,
		_tile_resources_list,
		_tile_effects_section,
		_tile_effects_list,
		_building_io_row,
		_building_inputs_list,
	]

	for c_v in controls:
		var c: Control = c_v as Control
		_set_fill_control(c)


func _enforce_layout_floors() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var max_w: float = maxf(360.0, vp.x - (dock_padding.x * 2.0))
	var max_h: float = maxf(300.0, vp.y - (dock_padding.y * 2.0))
	var target: Vector2 = Vector2(
		minf(min_panel_size.x, max_w),
		minf(min_panel_size.y, max_h)
	)

	custom_minimum_size = target
	size = target

	var fill_controls: Array = [
		_root_vbox,
		_scroll_container,
		_scroll_content,
		_mode_tabs,
		_tile_tab,
		_building_tab,
	]

	for c_v in fill_controls:
		var c: Control = c_v as Control
		_set_fill_control(c)

	if _scroll_container != null:
		_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll_container.custom_minimum_size = Vector2(0.0, maxf(160.0, target.y - 74.0))

	if _scroll_content != null:
		_scroll_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if _mode_tabs != null:
		_mode_tabs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_apply_horizontal_fill_fixes()


func _setup_mode_tabs() -> void:
	if _mode_tabs == null:
		return

	if _mode_tabs.get_tab_count() >= 2:
		_mode_tabs.set_tab_title(0, "Tile")
		_mode_tabs.set_tab_title(1, "Building")

		var cb_tab: Callable = Callable(self, "_on_tab_changed")
		if not _mode_tabs.tab_changed.is_connected(cb_tab):
			_mode_tabs.tab_changed.connect(cb_tab)

	if _tile_tab_button != null:
		var cb_tile: Callable = Callable(self, "_on_tile_tab_pressed")
		if not _tile_tab_button.pressed.is_connected(cb_tile):
			_tile_tab_button.pressed.connect(cb_tile)

	if _building_tab_button != null:
		var cb_build: Callable = Callable(self, "_on_building_tab_pressed")
		if not _building_tab_button.pressed.is_connected(cb_build):
			_building_tab_button.pressed.connect(cb_build)

	_sync_tab_buttons()
	_wire_slot_buttons()
	_on_tab_changed(_mode_tabs.current_tab, true)


func _fmt_mmss(seconds: float) -> String:
	var safe_seconds: float = maxf(0.0, seconds)
	var total_seconds: int = int(ceil(safe_seconds))
	var minutes: int = int(total_seconds / 60)
	var remaining_seconds: int = total_seconds % 60

	return "%d:%02d" % [minutes, remaining_seconds]


# -------------------------------------------------------------------
# Visual styling
# -------------------------------------------------------------------

func _apply_panel_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.070, 0.95)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.22, 0.22, 0.28, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 8

	add_theme_stylebox_override("panel", style)
	add_theme_font_size_override("font_size", font_body)


func _apply_tab_button_style(btn: Button, active: bool) -> void:
	if btn == null:
		return

	btn.custom_minimum_size = Vector2(0.0, 34.0)

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
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

	s.x = minf(s.x, maxf(360.0, vp.x - (dock_padding.x * 2.0)))
	s.y = minf(s.y, maxf(300.0, vp.y - (dock_padding.y * 2.0)))

	size = s
	position = Vector2(
		dock_padding.x,
		maxf(dock_padding.y, vp.y - size.y - dock_padding.y)
	)


func _on_tab_changed(_tab_index: int, reset_scroll: bool = true) -> void:
	if _mode_tabs == null:
		return

	_sync_tab_buttons()

	if _tile_tab != null:
		_tile_tab.visible = (_mode_tabs.current_tab == 0)

	if _building_tab != null:
		_building_tab.visible = (_mode_tabs.current_tab == 1)

	if reset_scroll and _scroll_container != null:
		_scroll_container.scroll_vertical = 0


func _on_tile_tab_pressed() -> void:
	if _mode_tabs != null:
		_mode_tabs.current_tab = 0

	_on_tab_changed(0, true)


func _on_building_tab_pressed() -> void:
	if _mode_tabs != null:
		_mode_tabs.current_tab = 1

	_on_tab_changed(1, true)


func _sync_tab_buttons() -> void:
	if _mode_tabs == null:
		return

	var tile_active: bool = (_mode_tabs.current_tab == 0)
	var build_active: bool = (_mode_tabs.current_tab == 1)

	if _tile_tab_button != null:
		_tile_tab_button.button_pressed = tile_active
		_apply_tab_button_style(_tile_tab_button, tile_active)

	if _building_tab_button != null:
		_building_tab_button.button_pressed = build_active
		_apply_tab_button_style(_building_tab_button, build_active)


func _wire_slot_buttons() -> void:
	if _building_slot != null:
		var cb0: Callable = Callable(self, "_on_building_slot_pressed")
		if not _building_slot.pressed.is_connected(cb0):
			_building_slot.pressed.connect(cb0)

	for i in range(_module_slots.size()):
		var btn: Button = _module_slots[i]
		if btn != null:
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
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.35, 0.55, 0.90)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.border_color = Color(0.70, 0.70, 0.85)

	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.45, 0.80, 1.00)

	var slots: Array[Button] = []
	if _building_slot != null:
		slots.append(_building_slot)

	slots.append_array(_module_slots)

	for slot in slots:
		slot.add_theme_stylebox_override("normal", normal)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("pressed", pressed)
		slot.add_theme_stylebox_override("focus", focus)
		slot.add_theme_stylebox_override("disabled", normal)

		if slot == _building_slot:
			_apply_square_slot_button(slot, 56.0)
		else:
			_apply_square_slot_button(slot, 44.0)


# -------------------------------------------------------------------
# Fragment selection
# -------------------------------------------------------------------

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
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	for _i in range(4):
		await tree.process_frame

		if seq != _apply_seq:
			return

		if frag != _current_fragment:
			return

		_apply_fragment()


func show_fragment(fragment: Node) -> void:
	set_fragment(fragment)


func _on_fragment_selected(fragment: Node) -> void:
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
	_prepare_tile_tab_layout()
	_update_tile_tab()
	_update_building_tab()

	if _mode_tabs != null:
		_on_tab_changed(_mode_tabs.current_tab, first_apply_this_selection)

	if dock_to_bottom_left and first_apply_this_selection:
		_dock_bottom_left()
		_apply_full_width_constraints()


# -------------------------------------------------------------------
# Tile tab
# -------------------------------------------------------------------

func _on_modifiers_expand_pressed() -> void:
	_mods_expanded = not _mods_expanded
	_update_tile_tab()


func _update_tile_tab() -> void:
	var biome_str: String = _get_biome_string(_current_fragment)
	var tile_name: String = _get_tile_name(_current_fragment, biome_str)
	var tier_val: int = _get_tile_tier(_current_fragment)

	_prepare_tile_tab_layout()

	if _tile_icon != null:
		_tile_icon.custom_minimum_size = header_icon_size
		_tile_icon.texture = _get_biome_icon(_current_fragment, biome_str)

	if _tile_name_label != null:
		_tile_name_label.text = tile_name
		_tile_name_label.add_theme_font_size_override("font_size", font_tile_title)

	if _tile_coord_label != null:
		_tile_coord_label.text = "Coord: %d,%d" % [_current_coord.x, _current_coord.y]
		_tile_coord_label.add_theme_font_size_override("font_size", font_small)

	if _tile_tier_label != null:
		_tile_tier_label.text = "T%d" % tier_val
		_tile_tier_label.add_theme_font_size_override("font_size", font_small)

	_populate_modifiers_grid(_get_modifiers_from_fragment(_current_fragment))
	_populate_entries(
		_tile_resources_list,
		_build_resource_entries(_get_resource_nodes_for_tile(_current_coord)),
		"No resource nodes"
	)
	_populate_list(_tile_effects_list, _get_effect_lines(_current_fragment), "No effects")


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
		var s: String = String(v).strip_edges()
		if s != "":
			return s

	return biome_str if biome_str != "" else "Tile"


func _get_tile_tier(fragment: Node) -> int:
	if fragment == null or not is_instance_valid(fragment):
		return 0

	var v: Variant = fragment.get("tier")
	if v == null:
		return 0

	return int(v)


func _get_biome_icon(_fragment: Node, biome_str: String) -> Texture2D:
	var key: String = biome_str.strip_edges().to_lower()
	if key == "":
		return null

	var paths: Array[String] = [
		"res://assets/icons/biomes/%s.png" % key,
		"res://assets/icons/biomes/%s_icon.png" % key,
		"res://assets/icons/biomes/default.png",
	]

	for p in paths:
		if ResourceLoader.exists(p):
			return load(p) as Texture2D

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
	_prepare_tile_tab_layout()

	if mods.is_empty():
		_tile_modifiers_grid.add_child(_simple_label("No modifiers", font_body, false))

		if _tile_modifiers_expand != null:
			_tile_modifiers_expand.visible = false

		return

	var total: int = int(mods.size())
	var max_visible: int = total
	if not _mods_expanded:
		max_visible = MAX_MODIFIERS_COLLAPSED

	var visible_count: int = mini(total, max_visible)

	for i in range(visible_count):
		_tile_modifiers_grid.add_child(_build_modifier_card(mods[i]))

	var remaining: int = total - visible_count

	if _tile_modifiers_expand != null:
		if remaining > 0 and not _mods_expanded:
			_tile_modifiers_expand.visible = true
			_tile_modifiers_expand.text = "+%d" % remaining
		elif _mods_expanded and total > MAX_MODIFIERS_COLLAPSED:
			_tile_modifiers_expand.visible = true
			_tile_modifiers_expand.text = "Less"
		else:
			_tile_modifiers_expand.visible = false


func _build_modifier_card(mod: Variant) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(MODIFIER_ICON_SIZE.x + 10.0, MODIFIER_ICON_SIZE.y + 10.0)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.115, 0.115, 0.135, 0.96)
	style.border_color = _rarity_color(_modifier_get_rarity(mod))
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var tex: Texture2D = _get_modifier_icon(mod)
	if tex != null:
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = MODIFIER_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = tex
		margin.add_child(icon)
	else:
		var lbl: Label = Label.new()
		lbl.custom_minimum_size = MODIFIER_ICON_SIZE
		lbl.text = _modifier_get_name(mod)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.clip_text = true
		lbl.add_theme_font_size_override("font_size", 10)
		margin.add_child(lbl)

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
	match rarity.strip_edges().to_lower():
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
		var kind: String = String(d.get("kind", "")).strip_edges().to_lower().replace("_", " ")
		var skill: String = String(d.get("skill", "")).strip_edges().to_lower()

		if kind == "resource spawn" and skill != "":
			var p0: String = "res://assets/icons/modifiers/%s_node.png" % skill
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
		var bits: Array[String] = []

		var name_str: String = String(d.get("name", d.get("detail", ""))).strip_edges()
		var rarity: String = String(d.get("rarity", "")).strip_edges()
		var kind: String = String(d.get("kind", "")).strip_edges()
		var skill: String = String(d.get("skill", "")).strip_edges()

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


# -------------------------------------------------------------------
# Resource nodes / effects
# -------------------------------------------------------------------

func _get_resource_nodes_for_tile(coord: Vector2i) -> Array:
	if _resource_nodes != null and _resource_nodes.has_method("get_nodes_for_tile"):
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

	var mods: Array = mods_v as Array
	for m_v in mods:
		if not (m_v is Dictionary):
			continue

		var md: Dictionary = m_v as Dictionary
		var kind: String = String(md.get("kind", "")).strip_edges().to_lower().replace("_", " ")
		if kind != "resource spawn":
			continue

		nodes.append({
			"detail": String(md.get("name", md.get("detail", ""))).strip_edges(),
			"skill": String(md.get("skill", "")).strip_edges(),
		})

	return nodes


func _build_resource_entries(nodes: Array) -> Array:
	var entries: Array = []

	for n_v in nodes:
		if not (n_v is Dictionary):
			continue

		var n: Dictionary = n_v as Dictionary
		var skill: String = String(n.get("skill", "")).strip_edges()
		var label: String = String(n.get("detail", skill)).strip_edges()

		if label == "":
			continue

		var line: String = label

		var has_charge_data: bool = (
			n.has("charges_left")
			or n.has("charges")
			or n.has("max_charges")
			or n.has("charges_max")
		)

		if has_charge_data:
			var left: int = int(n.get("charges_left", n.get("charges", 0)))
			var maxc: int = int(n.get("max_charges", n.get("charges_max", left)))
			line = "%s — %d/%d charges" % [label, maxi(0, left), maxi(0, maxc)]

		if bool(n.get("depleted", false)) and n.has("cooldown_s"):
			var cooldown: float = float(n.get("cooldown_s", 0.0))
			if cooldown > 0.0:
				line += " ⏳ %s" % _fmt_mmss(cooldown)

		entries.append({
			"text": line,
			"icon": _resource_icon_for_skill(skill),
			"header": false,
		})

	return entries


func _get_effect_lines(fragment: Node) -> Array[String]:
	if fragment == null or not is_instance_valid(fragment):
		return []

	if fragment.has_method("get_local_effects_list"):
		var eff_v: Variant = fragment.call("get_local_effects_list")
		if eff_v is Array:
			var lines: Array[String] = []
			var eff_arr: Array = eff_v as Array
			for entry in eff_arr:
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
	if _items != null and _items.has_method("get_icon"):
		var t_v: Variant = _items.call("get_icon", id)
		if t_v is Texture2D:
			return t_v as Texture2D

	if _items != null and _items.has_method("get_icon_path"):
		var path: String = String(_items.call("get_icon_path", id))
		if path != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D

	return null


func _resource_icon_for_skill(skill: String) -> Texture2D:
	var clean: String = skill.strip_edges().to_lower()
	if clean == "":
		return null

	var path: String = "res://assets/icons/modifiers/%s_node.png" % clean
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	return null


# -------------------------------------------------------------------
# Shared list UI
# -------------------------------------------------------------------

func _build_list_row(text: String, icon_tex: Texture2D, header: bool = false) -> Control:
	if text.strip_edges() == "":
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0.0, 6.0)
		return spacer

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", list_row_sep)

	var icon_holder: TextureRect = TextureRect.new()
	icon_holder.custom_minimum_size = list_icon_size
	icon_holder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_holder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_holder.texture = icon_tex

	if icon_tex == null:
		icon_holder.modulate = Color(1.0, 1.0, 1.0, 0.0)

	row.add_child(icon_holder)

	var label: Label = _simple_label(text, font_section_title if header else font_body, header)
	row.add_child(label)

	return row


func _simple_label(text: String, font_size: int, header: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.custom_minimum_size = Vector2.ZERO
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_font_size_override("font_size", font_size)

	if header:
		label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	else:
		label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.92))

	return label


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
		list_node.add_child(_simple_label(line, font_body, false))


# -------------------------------------------------------------------
# Building tab
# -------------------------------------------------------------------

func _on_building_slot_pressed() -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	emit_signal("building_slot_requested", _current_coord, "base", 0)


func _on_module_slot_pressed(slot_index: int) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	emit_signal("building_slot_requested", _current_coord, "module", slot_index)


func _update_building_tab() -> void:
	if _building_chips_row != null:
		_building_chips_row.visible = false

	if _building_buttons_row != null:
		_building_buttons_row.visible = false

	_apply_building_details_layout()

	var placed: Dictionary = _get_placed_building_state()
	var using_placed_building: bool = not placed.is_empty()

	var building_id: String = ""
	var module_ids: Array[String] = []

	if using_placed_building:
		building_id = String(placed.get("base_item_id", placed.get("recipe_id", ""))).strip_edges()
		module_ids = _get_module_ids_from_placed_state(placed)
	else:
		building_id = _get_equipped_building_id(_current_fragment)
		module_ids = _get_equipped_modules(_current_fragment)

	_set_button_icon_from_id(_building_slot, building_id)
	_apply_square_slot_button(_building_slot, 56.0)

	for i in range(_module_slots.size()):
		var id: String = ""
		if i < module_ids.size():
			id = module_ids[i]

		_set_button_icon_from_id(_module_slots[i], id)
		_apply_square_slot_button(_module_slots[i], 44.0)

	if building_id == "":
		if _building_name_label != null:
			_building_name_label.text = "No building installed"

		if _building_status_label != null:
			_building_status_label.text = "Place a Tier 1 building shell here to unlock modules and upgrades."

		if _building_tier_label != null:
			_building_tier_label.text = ""

		_populate_entries(_building_inputs_list, [
			{"text": "Empty building slot", "icon": null, "header": true},
			{"text": "No modules installed.", "icon": null, "header": false},
			{"text": "No active construction project.", "icon": null, "header": false},
		], "")

		return

	var display_name: String = building_id
	var tier_val: int = 0
	var linked_skill: String = ""

	if using_placed_building:
		display_name = String(placed.get("label", placed.get("building", building_id))).strip_edges()
		tier_val = int(placed.get("tier", 0))
		linked_skill = String(placed.get("linked_skill", "")).strip_edges()
	else:
		var def: Dictionary = _get_building_def(building_id)
		display_name = String(def.get("name", def.get("label", building_id))).strip_edges()
		tier_val = int(def.get("tier", _p(_current_fragment, "building_tier", 0)))
		linked_skill = String(def.get("skill", def.get("linked_skill", ""))).strip_edges()

	if display_name == "":
		display_name = building_id

	if _building_name_label != null:
		_building_name_label.text = display_name

	if _building_status_label != null:
		var bits: Array[String] = []

		if tier_val > 0:
			bits.append("Tier %d" % tier_val)

		if linked_skill != "":
			bits.append("%s building" % linked_skill.capitalize())

		var status: String = "Installed building"
		if not bits.is_empty():
			status = " • ".join(bits)

		var project_status: String = _active_project_status_short(_current_coord)
		if project_status != "":
			status += " • " + project_status

		_building_status_label.text = status

	if _building_tier_label != null:
		_building_tier_label.text = ("T%d" % tier_val) if tier_val > 0 else ""

	var combined_entries: Array = _building_summary_entries(placed, tier_val, linked_skill)
	combined_entries.append({"text": "", "icon": null, "header": false})
	combined_entries.append_array(_placed_building_detail_entries(placed, _current_coord))

	_populate_entries(_building_inputs_list, combined_entries, "No building details")


func _building_summary_entries(_placed: Dictionary, tier_val: int, linked_skill: String) -> Array:
	var entries: Array = [
		{"text": "Building", "icon": null, "header": true},
	]

	if tier_val > 0:
		entries.append({"text": "Tier %d" % tier_val, "icon": null, "header": false})

	if linked_skill.strip_edges() != "":
		entries.append({"text": "Supports %s" % linked_skill.capitalize(), "icon": null, "header": false})

	var slots: int = _module_slot_count_for_tier(tier_val)
	entries.append({
		"text": "%d module slot%s" % [slots, "" if slots == 1 else "s"],
		"icon": null,
		"header": false,
	})

	return entries


func _get_module_ids_from_placed_state(placed: Dictionary) -> Array[String]:
	var out: Array[String] = []

	var modules_v: Variant = placed.get("modules", [])
	if modules_v is Array:
		var modules: Array = modules_v as Array
		for m_v in modules:
			var module_id: String = _module_id_from_state(m_v)
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
		return maxi(1, int(m.get("level", 1)))

	return 1


func _module_label(module_id: String) -> String:
	var clean: String = module_id.strip_edges()
	if clean == "":
		return ""

	return _resolve_item_label(StringName(clean))


func _placed_building_detail_entries(placed: Dictionary, ax: Vector2i) -> Array:
	var entries: Array = [
		{"text": "Modules", "icon": null, "header": true},
	]

	var modules: Array = []
	var modules_v: Variant = placed.get("modules", [])
	if modules_v is Array:
		modules = modules_v as Array

	var slot_count: int = _module_slot_count_for_tier(int(placed.get("tier", 1)))

	for i in range(slot_count):
		if i < modules.size():
			var module_id: String = _module_id_from_state(modules[i])

			if module_id != "":
				entries.append({
					"text": "Slot %d: %s — Level %d" % [
						i + 1,
						_module_label(module_id),
						_module_level_from_state(modules[i]),
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

	var max_visible_slots: int = maxi(slot_count, _module_slots.size())
	for locked_i in range(slot_count, max_visible_slots):
		entries.append({
			"text": "Slot %d: Locked" % [locked_i + 1],
			"icon": null,
			"header": false,
		})

	var project_text: String = _describe_active_construction_project(ax)
	if project_text != "":
		entries.append({"text": "", "icon": null, "header": false})
		entries.append({"text": "Construction Project", "icon": null, "header": true})

		for line in project_text.split("\n", false):
			entries.append({
				"text": String(line),
				"icon": null,
				"header": false,
			})

	return entries


func _module_slot_count_for_tier(tier: int) -> int:
	if _construction != null and _construction.has_method("get_module_slot_count_for_tier"):
		return maxi(0, int(_construction.call("get_module_slot_count_for_tier", tier)))

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

	var needed: int = int(project.get("required_successes", 0))
	if needed > 0:
		return "Project %d/%d" % [
			int(project.get("successful_actions", 0)),
			needed,
		]

	return "Project active"


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
		return ""

	var lines: Array[String] = []

	var title: String = String(project.get("label", "")).strip_edges()
	if title == "":
		var ptype: String = String(project.get("type", project.get("project_type", ""))).strip_edges()

		match ptype:
			"upgrade_building":
				title = "Upgrade to Tier %d" % int(project.get("target_tier", 0))
			"install_module":
				var module_id: String = String(project.get("module_id", "")).strip_edges()
				title = "Install %s" % _module_label(module_id) if module_id != "" else "Install Module"
			"upgrade_module":
				var module_id2: String = String(project.get("module_id", "")).strip_edges()
				var target_level: int = int(project.get("target_level", 0))
				if module_id2 != "" and target_level > 0:
					title = "Upgrade %s to Level %d" % [_module_label(module_id2), target_level]
				elif module_id2 != "":
					title = "Upgrade %s" % _module_label(module_id2)
				else:
					title = "Upgrade Module"
			_:
				title = "Construction Project"

	lines.append("Active Project: %s" % title)
	lines.append("Progress: %d / %d successes" % [
		int(project.get("successful_actions", 0)),
		maxi(1, int(project.get("required_successes", 1))),
	])
	lines.append("Failures: %d" % int(project.get("failed_actions", 0)))

	var status: String = String(project.get("status", "")).strip_edges()
	if status != "":
		lines.append("Status: %s" % status.replace("_", " ").capitalize())

	var worker: int = int(project.get("assigned_worker", -1))
	if worker >= 0:
		lines.append("Assigned Worker: #%d" % worker)

	var req: int = int(project.get("req_con_lv", project.get("construction_level_req", 0)))
	if req > 0:
		lines.append("Required Construction: %d" % req)

	var fail_chance: float = float(project.get("fail_chance", 999.0))
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

	btn.icon = _resolve_item_icon(StringName(clean))
	btn.tooltip_text = _resolve_item_label(StringName(clean))


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
	var placed: Dictionary = _get_placed_building_state()
	if not placed.is_empty():
		var base_item: String = String(placed.get("base_item_id", "")).strip_edges()
		if base_item != "":
			return base_item

		var recipe_id: String = String(placed.get("recipe_id", "")).strip_edges()
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

	return ""


func _get_equipped_modules(frag: Node) -> Array[String]:
	var placed: Dictionary = _get_placed_building_state()
	if not placed.is_empty():
		return _get_module_ids_from_placed_state(placed)

	var out: Array[String] = []

	if frag == null or not is_instance_valid(frag):
		return out

	var keys: Array[String] = [
		"equipped_modules",
		"modules",
		"module_ids",
	]

	for k in keys:
		var vv: Variant = frag.get(k)
		if vv is Array:
			var arr: Array = vv as Array
			for it in arr:
				var s2: String = String(it).strip_edges()
				if s2 != "":
					out.append(s2)
			break

	return out


func _get_building_def(building_id: String) -> Dictionary:
	var id: String = building_id.strip_edges()
	if id == "":
		return {}

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
			if info_v is Dictionary:
				var info: Dictionary = info_v as Dictionary
				if not info.is_empty():
					return info

		if _construction.has_method("get_recipe_by_id"):
			var rec_v: Variant = _construction.call("get_recipe_by_id", StringName(id))
			if rec_v is Dictionary:
				var rec: Dictionary = rec_v as Dictionary
				if not rec.is_empty():
					return rec

		var tbl_v: Variant = _construction.get("BUILDINGS")
		if tbl_v is Dictionary:
			var tbl: Dictionary = tbl_v as Dictionary
			if tbl.has(id) and tbl[id] is Dictionary:
				return tbl[id] as Dictionary

	return {}


func _resolve_item_label(id: StringName) -> String:
	if _items != null and _items.has_method("is_valid") and _items.has_method("display_name"):
		if bool(_items.call("is_valid", id)):
			return String(_items.call("display_name", id))

	if _construction != null and _construction.has_method("get_part_display_name"):
		var label: String = String(_construction.call("get_part_display_name", String(id))).strip_edges()
		if label != "":
			return label

	return String(id)


# -------------------------------------------------------------------
# Building placement
# -------------------------------------------------------------------

func request_place_building_item(item_id: StringName) -> void:
	if _construction == null:
		push_warning("[SelectionHUD] Cannot place building: ConstructionSystem missing.")
		return

	if _construction.has_method("get_place_building_block_reason"):
		var block_reason: String = String(_construction.call(
			"get_place_building_block_reason",
			_current_coord,
			item_id
		))

		if block_reason != "":
			push_warning("[SelectionHUD] Cannot place building: %s" % block_reason)
			return

	if not _construction.has_method("place_building_item_at"):
		push_warning("[SelectionHUD] Cannot place building: ConstructionSystem missing place_building_item_at().")
		return

	var placed: bool = bool(_construction.call("place_building_item_at", _current_coord, item_id))
	if placed:
		_apply_fragment()


# -------------------------------------------------------------------
# Generic helpers
# -------------------------------------------------------------------

func _p(obj: Object, key: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value

	var v: Variant = obj.get(key)
	if v == null:
		return default_value

	return v


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
		c.remove_child(child)
		child.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_apply_full_width_constraints")


func _apply_full_width_constraints() -> void:
	if not is_inside_tree():
		return

	_apply_horizontal_fill_fixes()
	_apply_building_details_layout()
	_prepare_tile_tab_layout()
	_apply_square_slot_button(_building_slot, 56.0)

	for slot in _module_slots:
		_apply_square_slot_button(slot, 44.0)


func _set_fill_control(c: Control) -> void:
	if c == null:
		return

	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cm: Vector2 = c.custom_minimum_size
	c.custom_minimum_size = Vector2(0.0, cm.y)


func _force_fill_control(c: Control) -> void:
	_set_fill_control(c)


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
	var section_titles: Array[String] = [
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersHeader/TileModifiersTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileResourcesSection/TileResourcesTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileEffectsSection/TileEffectsTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/EquippedTitle",
		"Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs/BuildingInputsTitle",
	]

	for p in section_titles:
		var lbl: Label = get_node_or_null(p) as Label
		if lbl != null:
			lbl.add_theme_font_size_override("font_size", font_section_title)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.clip_text = false

	if _tile_modifiers_expand != null:
		_tile_modifiers_expand.add_theme_font_size_override("font_size", font_small)

	if _building_name_label != null:
		_building_name_label.add_theme_font_size_override("font_size", font_section_title)

	if _building_status_label != null:
		_building_status_label.add_theme_font_size_override("font_size", font_body)

	if _building_tier_label != null:
		_building_tier_label.add_theme_font_size_override("font_size", font_small)

	if _tile_name_label != null:
		_tile_name_label.add_theme_font_size_override("font_size", font_tile_title)

	if _tile_coord_label != null:
		_tile_coord_label.add_theme_font_size_override("font_size", font_small)

	if _tile_tier_label != null:
		_tile_tier_label.add_theme_font_size_override("font_size", font_small)
