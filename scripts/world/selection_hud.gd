# res://scripts/world/selection_hud.gd
extends Panel

signal building_equip_requested(ax: Vector2i, building_id: String)
signal building_slot_requested(ax: Vector2i, slot_type: String, slot_index: int)

@export var debug_logging: bool = false

# If your HUD is inside a Container, the Container will override anchors/position.
@export var force_top_level: bool = true

# Dock this panel to bottom-left of the viewport.
@export var dock_to_bottom_left: bool = true
@export var dock_padding: Vector2 = Vector2(16, 16)

const MAX_MODIFIERS_COLLAPSED := 9
const MODIFIER_ICON_SIZE := Vector2(28, 28)

var _current_fragment: Node = null
var _current_coord: Vector2i = Vector2i.ZERO
var _mods_expanded: bool = false

# UI refs
var _mode_tabs: TabContainer = null
var _mode_header: Control = null
var _tile_tab_button: Button = null
var _building_tab_button: Button = null
var _scroll_container: ScrollContainer = null

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

var _building_chips_row: Control = null
var _chip_workers_label: Label = null
var _chip_queue_label: Label = null
var _chip_upkeep_label: Label = null
var _chip_integrity_label: Label = null

var _building_io_row: Control = null
var _building_inputs_list: VBoxContainer = null
var _building_outputs_list: VBoxContainer = null

var _building_buttons_row: Control = null

# Legacy slots (optional)
var _base_slot: Button = null
var _module_slots: Array[Button] = []

# Autoload refs (safe)
var _selection: Node = null
var _bank: Node = null
var _resource_nodes: Node = null
var _construction: Node = null
var _items: Node = null


func _ready() -> void:
	visible = false

	_selection = get_node_or_null("/root/Selection")
	_bank = get_node_or_null("/root/Bank")
	_resource_nodes = get_node_or_null("/root/ResourceNodes")
	_construction = get_node_or_null("/root/ConstructionSystem")
	_items = get_node_or_null("/root/Items")

	if force_top_level:
		top_level = true
		set_anchors_preset(Control.PRESET_TOP_LEFT, true)

	if dock_to_bottom_left:
		call_deferred("_dock_bottom_left")
		var vp := get_viewport()
		if vp and not vp.size_changed.is_connected(_on_viewport_size_changed):
			vp.size_changed.connect(_on_viewport_size_changed)

	_apply_panel_style()
	_cache_nodes()
	_setup_mode_tabs()
	_apply_slot_styles()

	if _tile_modifiers_expand:
		_tile_modifiers_expand.pressed.connect(_on_modifiers_expand_pressed)

	# Wire selection
	if _selection and _selection.has_signal("fragment_selected"):
		_selection.connect("fragment_selected", Callable(self, "_on_fragment_selected"))
	elif debug_logging:
		print("[SelectionHUD] Selection autoload missing or has no fragment_selected signal.")


func _cache_nodes() -> void:
	_mode_tabs = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs") as TabContainer
	_mode_header = get_node_or_null("Margin/RootVBox/ModeHeader") as Control
	_tile_tab_button = get_node_or_null("Margin/RootVBox/ModeHeader/TileTabButton") as Button
	_building_tab_button = get_node_or_null("Margin/RootVBox/ModeHeader/BuildingTabButton") as Button
	_scroll_container = get_node_or_null("Margin/RootVBox/Scroll") as ScrollContainer

	_tile_icon = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileIcon") as TextureRect
	_tile_name_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText/TileName") as Label
	_tile_coord_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileHeaderText/TileCoord") as Label
	_tile_tier_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileHeaderRow/TileTierChip/TileTierLabel") as Label

	_tile_modifiers_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection") as Control
	_tile_modifiers_grid = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersGrid") as GridContainer
	_tile_modifiers_expand = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileModifiersSection/TileModifiersHeader/TileModifiersExpand") as Button

	_tile_resources_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileResourcesSection") as Control
	_tile_resources_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileResourcesSection/TileResourcesList") as VBoxContainer

	_tile_effects_section = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileEffectsSection") as Control
	_tile_effects_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/TileTab/TileEffectsSection/TileEffectsList") as VBoxContainer

	_building_slot = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSlot") as Button
	_building_name_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingName") as Label
	_building_status_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingStatus") as Label
	_building_tier_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/BuildingRow/BuildingSummary/BuildingTierChip/BuildingTierLabel") as Label

	_building_chips_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow") as Control
	_chip_workers_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipWorkers/ChipWorkersLabel") as Label
	_chip_queue_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipQueue/ChipQueueLabel") as Label
	_chip_upkeep_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipUpkeep/ChipUpkeepLabel") as Label
	_chip_integrity_label = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingChipsRow/ChipIntegrity/ChipIntegrityLabel") as Label

	_building_io_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow") as Control
	_building_inputs_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingInputs/BuildingInputsList") as VBoxContainer
	_building_outputs_list = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingIORow/BuildingOutputs/BuildingOutputsList") as VBoxContainer

	_building_buttons_row = get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/BuildingButtonsRow") as Control

	_base_slot = _building_slot
	_module_slots.clear()
	for i in range(1, 4):
		var btn := get_node_or_null("Margin/RootVBox/Scroll/ScrollContent/ModeTabs/BuildingTab/EquippedSection/ModulesRow/ModuleSlot%d" % i) as Button
		if btn:
			_module_slots.append(btn)


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


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.08, 0.92)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.24, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)
	add_theme_font_size_override("font_size", 18)
	add_theme_constant_override("line_spacing", 2)


func _on_viewport_size_changed() -> void:
	if dock_to_bottom_left:
		_dock_bottom_left()


func _dock_bottom_left() -> void:
	if not is_inside_tree():
		return

	var vp: Vector2 = get_viewport_rect().size
	var min_size: Vector2 = get_combined_minimum_size()
	var available := Vector2(
		max(0.0, vp.x - (dock_padding.x * 2.0)),
		max(0.0, vp.y - (dock_padding.y * 2.0))
	)
	var target := Vector2(
		min(min_size.x, available.x),
		min(min_size.y, available.y)
	)
	if target.x <= 0.0:
		target.x = min_size.x
	if target.y <= 0.0:
		target.y = min_size.y
	size = target
	var x: float = dock_padding.x
	var y: float = vp.y - size.y - dock_padding.y

	if y < dock_padding.y:
		y = dock_padding.y

	position = Vector2(x, y)


func _on_tab_changed(tab_index: int) -> void:
	if _mode_tabs == null:
		return
	_sync_tab_buttons()
	if _scroll_container:
		_scroll_container.scroll_vertical = 0


func _on_tile_tab_pressed() -> void:
	if _mode_tabs:
		_mode_tabs.current_tab = 0
	_sync_tab_buttons()


func _on_building_tab_pressed() -> void:
	if _mode_tabs:
		_mode_tabs.current_tab = 1
	_sync_tab_buttons()


func _sync_tab_buttons() -> void:
	if _mode_tabs == null:
		return
	if _tile_tab_button:
		_tile_tab_button.button_pressed = _mode_tabs.current_tab == 0
	if _building_tab_button:
		_building_tab_button.button_pressed = _mode_tabs.current_tab == 1


func _wire_slot_buttons() -> void:
	if _building_slot and not _building_slot.pressed.is_connected(_on_building_slot_pressed):
		_building_slot.pressed.connect(_on_building_slot_pressed)
	for i in range(_module_slots.size()):
		var btn := _module_slots[i]
		if btn and not btn.pressed.is_connected(_on_module_slot_pressed.bind(i)):
			btn.pressed.connect(_on_module_slot_pressed.bind(i))


func _apply_slot_styles() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.18, 0.18, 0.22)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6

	var hover := normal.duplicate()
	hover.border_color = Color(0.35, 0.55, 0.9)

	var pressed := normal.duplicate()
	pressed.border_color = Color(0.7, 0.7, 0.85)

	var focus := normal.duplicate()
	focus.border_color = Color(0.45, 0.8, 1.0)

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
		slot.text = ""
		slot.clip_text = true
		slot.expand_icon = true


func set_fragment(fragment: Node) -> void:
	_current_fragment = fragment
	_current_coord = Vector2i.ZERO

	if _current_fragment != null and is_instance_valid(_current_fragment):
		var coord_v: Variant = _current_fragment.get("coord")
		if coord_v is Vector2i:
			_current_coord = coord_v

	_apply_fragment()


func show_fragment(fragment: Node) -> void:
	set_fragment(fragment)


func _on_fragment_selected(fragment: Node) -> void:
	set_fragment(fragment)


func _apply_fragment() -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		visible = false
		return

	visible = true
	_update_tile_tab()
	_update_building_tab()

	if dock_to_bottom_left:
		call_deferred("_dock_bottom_left")


# ---------- Tile tab ----------
func _update_tile_tab() -> void:
	var biome_str := _get_biome_string(_current_fragment)
	var tile_name := _get_tile_name(_current_fragment, biome_str)
	var tier_val := _get_tile_tier(_current_fragment)
	var coord_text := "%d,%d" % [_current_coord.x, _current_coord.y]

	if _tile_icon:
		_tile_icon.texture = _get_biome_icon(_current_fragment, biome_str)
	if _tile_name_label:
		_tile_name_label.text = tile_name
	if _tile_coord_label:
		_tile_coord_label.text = "Coord: %s" % coord_text
	if _tile_tier_label:
		_tile_tier_label.text = "T%d" % tier_val

	var mods: Array = _get_modifiers_from_fragment(_current_fragment)
	_populate_modifiers_grid(mods)

	var resources := _get_resource_nodes_for_tile(_current_coord)
	var resource_lines := _build_resource_lines(resources)
	_populate_list(_tile_resources_list, resource_lines)
	_set_section_visible(_tile_resources_section, not resource_lines.is_empty())

	var effect_lines := _get_effect_lines(_current_fragment)
	_populate_list(_tile_effects_list, effect_lines)
	_set_section_visible(_tile_effects_section, not effect_lines.is_empty())


func _get_biome_string(fragment: Node) -> String:
	if fragment != null and is_instance_valid(fragment) and "biome" in fragment:
		return String(fragment.biome)
	return "Unknown"


func _get_tile_name(fragment: Node, biome_str: String) -> String:
	if fragment != null and is_instance_valid(fragment):
		if "tile_name" in fragment:
			var name_str := String(fragment.tile_name)
			if name_str != "":
				return name_str
	return biome_str if biome_str != "" else "Tile"


func _get_tile_tier(fragment: Node) -> int:
	if fragment != null and is_instance_valid(fragment) and "tier" in fragment:
		return int(fragment.tier)
	return 0


func _get_biome_icon(fragment: Node, biome_str: String) -> Texture2D:
	# TODO: Wire in biome-specific icon lookups.
	return null


func _get_modifiers_from_fragment(frag: Node) -> Array:
	if frag == null or not is_instance_valid(frag):
		return []
	if not ("modifiers" in frag):
		return []
	var v: Variant = frag.get("modifiers")
	if v is Array:
		return v
	return []


func _populate_modifiers_grid(mods: Array) -> void:
	if _tile_modifiers_grid == null:
		return

	_clear_container(_tile_modifiers_grid)

	if mods.is_empty():
		_set_section_visible(_tile_modifiers_section, false)
		return

	_set_section_visible(_tile_modifiers_section, true)

	var total: int = mods.size()
	var max_visible: int = total if _mods_expanded else MAX_MODIFIERS_COLLAPSED
	var visible_count: int = min(total, max_visible)

	for i in range(visible_count):
		var m: Variant = mods[i]
		var card := _build_modifier_card(m)
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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = MODIFIER_ICON_SIZE

	var rarity := _modifier_get_rarity(mod)
	var border_color := _rarity_color(rarity)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var icon := TextureRect.new()
	icon.custom_minimum_size = MODIFIER_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _get_modifier_icon(mod)
	panel.add_child(icon)

	panel.tooltip_text = _modifier_to_tooltip(mod)
	return panel


func _modifier_get_rarity(mod: Variant) -> String:
	if mod is Dictionary:
		var d: Dictionary = mod
		return String(d.get("rarity", ""))
	return ""


func _rarity_color(rarity: String) -> Color:
	var key := rarity.strip_edges().to_lower()
	match key:
		"common":
			return Color(0.55, 0.55, 0.6)
		"uncommon":
			return Color(0.35, 0.7, 0.45)
		"rare":
			return Color(0.35, 0.55, 0.9)
		"epic":
			return Color(0.7, 0.45, 0.9)
		"legendary":
			return Color(0.95, 0.7, 0.2)
		_:
			return Color(0.4, 0.4, 0.45)


func _get_modifier_icon(mod: Variant) -> Texture2D:
	if mod is Dictionary:
		var d: Dictionary = mod
		var kind := String(d.get("kind", "")).to_lower()
		var skill := String(d.get("skill", "")).to_lower()
		if kind == "resource spawn" and skill != "":
			var path := "res://assets/icons/modifiers/%s_node.png" % skill
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
	return null


func _modifier_to_tooltip(mod: Variant) -> String:
	if mod is Dictionary:
		var d: Dictionary = mod
		var name := String(d.get("name", d.get("detail", ""))).strip_edges()
		var kind := String(d.get("kind", "")).strip_edges()
		var rarity := String(d.get("rarity", "")).strip_edges()
		var skill := String(d.get("skill", "")).strip_edges()
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
		return []
	if not _resource_nodes.has_method("get_nodes"):
		return []
	var nodes_v: Variant = _resource_nodes.call("get_nodes", coord)
	if nodes_v is Array:
		return nodes_v
	return []


func _build_resource_lines(nodes: Array) -> Array[String]:
	var counts: Dictionary = {}
	for n_v in nodes:
		if typeof(n_v) != TYPE_DICTIONARY:
			continue
		var n: Dictionary = n_v
		var skill := String(n.get("skill", "")).strip_edges()
		var detail := String(n.get("detail", "")).strip_edges()
		var label := detail if detail != "" else skill
		if label == "":
			continue
		counts[label] = int(counts.get(label, 0)) + 1

	var lines: Array[String] = []
	for key in counts.keys():
		var qty := int(counts[key])
		if qty > 1:
			lines.append("%s ×%d" % [String(key), qty])
		else:
			lines.append(String(key))
	lines.sort()
	return lines


func _get_effect_lines(fragment: Node) -> Array[String]:
	if fragment == null or not is_instance_valid(fragment):
		return []
	if fragment.has_method("get_local_effects_list"):
		var eff_v: Variant = fragment.call("get_local_effects_list")
		if eff_v is Array:
			var lines: Array[String] = []
			for entry in eff_v:
				lines.append(String(entry))
			return lines
	if fragment.has_method("get_local_effects_summary"):
		var summary := String(fragment.call("get_local_effects_summary")).strip_edges()
		if summary != "":
			var lines: Array[String] = []
			for entry in summary.split("\n", false):
				lines.append(String(entry))
			return lines
	return []


func _populate_list(list_node: VBoxContainer, lines: Array[String]) -> void:
	if list_node == null:
		return
	_clear_container(list_node)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		list_node.add_child(label)


func _set_section_visible(section: Control, should_show: bool) -> void:
	if section:
		section.visible = should_show


# ---------- Buildings tab ----------
func _update_building_tab() -> void:
	var base_id := _get_equipped_building_id(_current_fragment)
	var has_building := base_id != ""

	_refresh_building_equipment(_current_fragment)

	var building_data := _get_building_data(_current_fragment)
	if _chip_workers_label:
		_chip_workers_label.text = "Workers: %s" % String(building_data.get("workers", "0"))
	if _chip_queue_label:
		_chip_queue_label.text = "Queue: %s" % String(building_data.get("queue", "0"))
	if _chip_upkeep_label:
		_chip_upkeep_label.text = "Upkeep: %s" % String(building_data.get("upkeep", "-"))
	if _chip_integrity_label:
		_chip_integrity_label.text = "Integrity: %s" % String(building_data.get("integrity", "-"))

	var inputs: Array = building_data.get("inputs", [])
	var outputs: Array = building_data.get("outputs", [])
	_populate_list(_building_inputs_list, _normalize_string_array(inputs))
	_populate_list(_building_outputs_list, _normalize_string_array(outputs))

	if _building_chips_row:
		_building_chips_row.visible = has_building
	if _building_io_row:
		_building_io_row.visible = has_building and (not inputs.is_empty() or not outputs.is_empty())
	if _building_buttons_row:
		_building_buttons_row.visible = has_building


func _normalize_string_array(arr: Array) -> Array[String]:
	var out: Array[String] = []
	for entry in arr:
		out.append(String(entry))
	return out


func _get_building_data(fragment: Node) -> Dictionary:
	if fragment == null or not is_instance_valid(fragment):
		return {}

	var base_id := _get_equipped_building_id(fragment)
	if base_id == "":
		return {}

	var data: Dictionary = {
		"workers": _get_building_workers(base_id, fragment),
		"queue": _get_building_queue(base_id, fragment),
		"upkeep": _get_building_upkeep(base_id, fragment),
		"integrity": _get_building_integrity(base_id, fragment),
		"inputs": _get_building_inputs(base_id, fragment),
		"outputs": _get_building_outputs(base_id, fragment),
	}
	return data


func _get_building_label(base_id: String) -> String:
	if _items and _items.has_method("display_name"):
		return String(_items.call("display_name", StringName(base_id)))
	if _construction and _construction.has_method("get_recipe_by_id"):
		var rec: Dictionary = _construction.call("get_recipe_by_id", StringName(base_id))
		return String(rec.get("label", base_id))
	return base_id


func _get_building_tier_label(base_id: String) -> String:
	if _construction and _construction.has_method("get_recipe_by_id"):
		var rec: Dictionary = _construction.call("get_recipe_by_id", StringName(base_id))
		var tier := int(rec.get("build_tier", 0))
		if tier > 0:
			return "T%d" % tier
	return "T0"


func _get_building_desc(base_id: String) -> String:
	if _construction and _construction.has_method("get_recipe_by_id"):
		var rec: Dictionary = _construction.call("get_recipe_by_id", StringName(base_id))
		var desc := String(rec.get("desc", "")).strip_edges()
		if desc != "":
			return desc
		var effect := String(rec.get("effect_raw", "")).strip_edges()
		return effect
	return ""


func _get_building_icon(base_id: String) -> Texture2D:
	if _items and _items.has_method("get_icon"):
		return _items.call("get_icon", StringName(base_id)) as Texture2D
	return null


func _get_building_workers(_base_id: String, fragment: Node) -> String:
	# TODO: connect to your workforce system.
	if fragment.has_meta("workers"):
		return String(fragment.get_meta("workers"))
	return "0"


func _get_building_queue(_base_id: String, fragment: Node) -> String:
	# TODO: connect to building queue system.
	if fragment.has_meta("queue"):
		return String(fragment.get_meta("queue"))
	return "0"


func _get_building_upkeep(_base_id: String, fragment: Node) -> String:
	# TODO: connect upkeep values.
	if fragment.has_meta("upkeep"):
		return String(fragment.get_meta("upkeep"))
	return "-"


func _get_building_integrity(_base_id: String, fragment: Node) -> String:
	# TODO: connect building integrity.
	if fragment.has_meta("integrity"):
		return String(fragment.get_meta("integrity"))
	return "-"


func _get_building_inputs(_base_id: String, fragment: Node) -> Array:
	# TODO: connect building inputs.
	if fragment.has_meta("inputs"):
		var v: Variant = fragment.get_meta("inputs")
		if v is Array:
			return v
	return []


func _get_building_outputs(_base_id: String, fragment: Node) -> Array:
	# TODO: connect building outputs.
	if fragment.has_meta("outputs"):
		var v: Variant = fragment.get_meta("outputs")
		if v is Array:
			return v
	return []


func _get_equipped_building_id(fragment: Node) -> String:
	if fragment == null or not is_instance_valid(fragment):
		return ""
	if fragment.has_meta("building_id"):
		return String(fragment.get_meta("building_id"))
	return ""


func _get_equipped_modules(fragment: Node) -> Array:
	if fragment == null or not is_instance_valid(fragment):
		return []
	if fragment.has_meta("building_modules"):
		var m: Variant = fragment.get_meta("building_modules")
		if m is Array:
			return m
	return []


func _refresh_building_equipment(fragment: Node) -> void:
	var base_id := _get_equipped_building_id(fragment)
	var modules := _get_equipped_modules(fragment)

	if _building_slot:
		if base_id != "":
			var icon := _get_building_icon(base_id)
			_building_slot.icon = icon
			var title := _get_building_label(base_id)
			var desc := _get_building_desc(base_id)
			_building_slot.tooltip_text = _build_tooltip(title, desc)
		else:
			_building_slot.icon = null
			_building_slot.tooltip_text = "Empty"

	if _building_name_label:
		_building_name_label.text = "No Building" if base_id == "" else _get_building_label(base_id)
	if _building_status_label:
		_building_status_label.text = "Empty" if base_id == "" else "Equipped"
	if _building_tier_label:
		_building_tier_label.text = _get_building_tier_label(base_id) if base_id != "" else "T0"

	for i in range(_module_slots.size()):
		var slot := _module_slots[i]
		if slot == null:
			continue
		var module_id := ""
		if i < modules.size() and modules[i] is String:
			module_id = String(modules[i])
		if module_id != "":
			slot.icon = _get_building_icon(module_id)
			var title_m := _get_building_label(module_id)
			var desc_m := _get_building_desc(module_id)
			slot.tooltip_text = _build_tooltip(title_m, desc_m)
		else:
			slot.icon = null
			slot.tooltip_text = "Empty"


func _build_tooltip(title: String, desc: String) -> String:
	if title == "":
		return desc
	if desc == "":
		return title
	return "%s\n%s" % [title, desc]


func _on_modifiers_expand_pressed() -> void:
	_mods_expanded = not _mods_expanded
	_update_tile_tab()


func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()


# ---------- Helpers for future equip ----------
func equip_base(building_id: String) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return
	_current_fragment.set_meta("building_id", building_id)
	_current_fragment.set_meta("building_modules", [])
	emit_signal("building_equip_requested", _current_coord, building_id)
	_update_building_tab()


func equip_module(slot_index: int, building_id: String) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	var modules: Array = []
	if _current_fragment.has_meta("building_modules"):
		var m: Variant = _current_fragment.get_meta("building_modules")
		if m is Array:
			modules = m.duplicate()

	var max_index: int = max(_module_slots.size() - 1, 0)
	var idx: int = clampi(slot_index, 0, max_index)

	if modules.size() <= idx:
		modules.resize(idx + 1)
	modules[idx] = building_id

	_current_fragment.set_meta("building_modules", modules)
	emit_signal("building_equip_requested", _current_coord, building_id)
	_update_building_tab()


# ---------- Drag-and-drop from Bank into slots ----------
func _get_drop_slot_info(at_position: Vector2, data: Variant) -> Dictionary:
	var info: Dictionary = {}

	if typeof(data) != TYPE_DICTIONARY:
		return info

	var d: Dictionary = data
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
	var info := _get_drop_slot_info(at_position, data)
	if info.is_empty():
		return false

	var slot_type: String = String(info.get("slot_type", ""))
	var item_id: String = String(info.get("item_id", ""))

	if not _is_valid_building_item_for_slot(item_id, slot_type):
		return false

	if slot_type == "module":
		var has_base := false
		if _current_fragment and _current_fragment.has_meta("building_id"):
			var base_id := String(_current_fragment.get_meta("building_id"))
			has_base = base_id != ""
		if not has_base:
			return false

	if _bank == null:
		return false
	if not _bank.has_method("has_at_least"):
		return true

	return bool(_bank.call("has_at_least", item_id, 1))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var info := _get_drop_slot_info(at_position, data)
	if info.is_empty():
		return

	var building_id: String = String(info["item_id"])
	var icon_tex: Texture2D = info.get("icon", null)

	# Pay cost: remove 1 from bank
	if _bank and _bank.has_method("has_at_least") and _bank.has_method("add"):
		if not bool(_bank.call("has_at_least", building_id, 1)):
			return
		_bank.call("add", building_id, -1)

	var slot_type: String = String(info.get("slot_type", ""))
	if slot_type == "base":
		_equip_base_from_drop(building_id, icon_tex)
	else:
		_equip_module_from_drop(int(info.get("slot_index", 0)), building_id, icon_tex)


func _equip_base_from_drop(building_id: String, icon_tex: Texture2D) -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		return

	var old_base: String = ""
	if _current_fragment.has_meta("building_id"):
		old_base = String(_current_fragment.get_meta("building_id"))

	var old_modules: Array = []
	if _current_fragment.has_meta("building_modules"):
		var m: Variant = _current_fragment.get_meta("building_modules")
		if m is Array:
			old_modules = m

	_current_fragment.set_meta("building_id", building_id)
	_current_fragment.set_meta("building_modules", [])

	if _base_slot:
		_base_slot.icon = icon_tex
		_base_slot.text = ""

	for btn in _module_slots:
		if btn:
			btn.icon = null
			btn.text = ""

	# Return old base + modules to bank
	if _bank and _bank.has_method("add"):
		if old_base != "":
			_bank.call("add", old_base, 1)
		for m_id in old_modules:
			if m_id is String and String(m_id) != "":
				_bank.call("add", String(m_id), 1)

	emit_signal("building_equip_requested", _current_coord, building_id)
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
		var m: Variant = _current_fragment.get_meta("building_modules")
		if m is Array:
			modules = m.duplicate()

	var old_id: String = ""
	if idx < modules.size() and modules[idx] is String:
		old_id = String(modules[idx])

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

	if old_id != "" and _bank and _bank.has_method("add"):
		_bank.call("add", old_id, 1)

	emit_signal("building_equip_requested", _current_coord, building_id)
	_update_building_tab()


func _on_building_slot_pressed() -> void:
	emit_signal("building_slot_requested", _current_coord, "building", -1)


func _on_module_slot_pressed(slot_index: int) -> void:
	emit_signal("building_slot_requested", _current_coord, "module", slot_index)


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
