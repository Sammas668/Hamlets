# res://scripts/world/selection_hud.gd
extends Panel

signal building_equip_requested(ax: Vector2i, building_id: String)

@export var debug_logging: bool = false

# If your HUD is inside a Container, the Container will override anchors/position.
@export var force_top_level: bool = true

# Dock this panel to bottom-left of the viewport.
@export var dock_to_bottom_left: bool = true
@export var dock_padding: Vector2 = Vector2(16, 16)

var _current_fragment: Node = null
var _current_coord: Vector2i = Vector2i.ZERO

# UI refs (found by name; keep these node names in your scene)
var _tile_tab: Control = null
var _build_tab: Control = null

var _biome_label: Label = null
var _tier_label: Label = null
var _mods_text: Control = null   # Label or RichTextLabel
var _effects_text: Control = null

var _current_building_label: Label = null
var _base_slot: Button = null
var _module_slots: Array[Button] = []

# Autoload refs (safe)
var _selection: Node = null
var _bank: Node = null
var _resource_nodes: Node = null
var _construction: Node = null


func _ready() -> void:
	visible = false

	_selection = get_node_or_null("/root/Selection")
	_bank = get_node_or_null("/root/Bank")
	_resource_nodes = get_node_or_null("/root/ResourceNodes")
	_construction = get_node_or_null("/root/ConstructionSystem")

	# Optional: make sure layout can’t be overridden by Containers
	if force_top_level:
		top_level = true
		set_anchors_preset(Control.PRESET_TOP_LEFT, true)

	# Dock (fixes “top-left” panel issues)
	if dock_to_bottom_left:
		call_deferred("_dock_bottom_left")
		var vp := get_viewport()
		if vp and not vp.size_changed.is_connected(_on_viewport_size_changed):
			vp.size_changed.connect(_on_viewport_size_changed)

	# Find tabs / controls by name (keeps the script resilient)
	_tile_tab = find_child("TileTab", true, false) as Control
	if _tile_tab == null:
		_tile_tab = find_child("Info", true, false) as Control

	_build_tab = find_child("BuildTab", true, false) as Control
	if _build_tab == null:
		_build_tab = find_child("Buildings", true, false) as Control

	_biome_label = find_child("BiomeLabel", true, false) as Label
	if _biome_label == null:
		_biome_label = find_child("Biome", true, false) as Label

	_tier_label = find_child("TierLabel", true, false) as Label
	if _tier_label == null:
		_tier_label = find_child("Coord", true, false) as Label

	_mods_text = find_child("ModifiersText", true, false) as Control
	_effects_text = find_child("EffectsText", true, false) as Control

	_current_building_label = find_child("CurrentBuildingLabel", true, false) as Label
	if _current_building_label == null:
		_current_building_label = find_child("CurrentBuilding", true, false) as Label

	_base_slot = find_child("BaseSlot", true, false) as Button

	# Module slots: ModuleSlot1, ModuleSlot2, ModuleSlot3
	_module_slots.clear()
	for i in range(1, 4):
		var btn := find_child("ModuleSlot%d" % i, true, false) as Button
		if btn:
			_module_slots.append(btn)

	# Wire selection
	if _selection and _selection.has_signal("fragment_selected"):
		_selection.connect("fragment_selected", Callable(self, "_on_fragment_selected"))
	elif debug_logging:
		print("[SelectionHUD] Selection autoload missing or has no fragment_selected signal.")

	if debug_logging:
		print("[SelectionHUD] Ready. tile_tab=", _tile_tab, " build_tab=", _build_tab)


func _on_viewport_size_changed() -> void:
	if dock_to_bottom_left:
		_dock_bottom_left()


func _dock_bottom_left() -> void:
	if not is_inside_tree():
		return

	# Make sure we have a sensible size before docking
	var min_size: Vector2 = get_combined_minimum_size()
	if size.x < min_size.x or size.y < min_size.y:
		size = min_size

	var vp: Vector2 = get_viewport_rect().size
	var x: float = dock_padding.x
	var y: float = vp.y - size.y - dock_padding.y

	# Clamp in case the viewport is tiny
	if y < dock_padding.y:
		y = dock_padding.y

	position = Vector2(x, y)


# Called by Selection autoload
func _on_fragment_selected(fragment: Node) -> void:
	_current_fragment = fragment
	_current_coord = Vector2i.ZERO

	if _current_fragment != null and is_instance_valid(_current_fragment):
		var coord_v: Variant = _current_fragment.get("coord")
		if coord_v is Vector2i:
			_current_coord = coord_v

	_apply_fragment() # ✅ THIS WAS MISSING


func _apply_fragment() -> void:
	if _current_fragment == null or not is_instance_valid(_current_fragment):
		visible = false
		return

	visible = true
	_update_tile_tab()
	_update_building_tab()

	# Re-dock after content changes (size may change due to text)
	if dock_to_bottom_left:
		call_deferred("_dock_bottom_left")


# ---------- Tile tab ----------
func _update_tile_tab() -> void:
	var biome_str: String = ""
	var tier_val: int = 0

	if _current_fragment != null and is_instance_valid(_current_fragment):
		if "biome" in _current_fragment:
			biome_str = String(_current_fragment.biome)
		if "tier" in _current_fragment:
			tier_val = int(_current_fragment.tier)

	if _biome_label:
		_biome_label.text = "Biome: %s" % (biome_str if biome_str != "" else "(unknown)")

	if _tier_label:
		var coord_text := "%d,%d" % [_current_coord.x, _current_coord.y]
		_tier_label.text = "Tier: %d  (Coord: %s)" % [tier_val, coord_text]

	# --- Modifiers ---
	var mods: Array = _get_modifiers_from_fragment(_current_fragment)
	var mod_lines: Array[String] = []
	for m: Variant in mods:
		var line: String = _modifier_to_line(m)
		if line != "":
			mod_lines.append(line)
	mod_lines.sort()

	var mods_block: String = "None"
	if not mod_lines.is_empty():
		mods_block = "\n".join(mod_lines)

	# Resource node summary (optional)
	var node_summary: String = ""
	if _resource_nodes and _resource_nodes.has_method("get_summary_for_tile"):
		node_summary = String(_resource_nodes.call("get_summary_for_tile", _current_coord))
	if node_summary == "":
		node_summary = "No resource nodes"

	var tile_text: String = "Resource nodes: %s\n\nModifiers:\n%s" % [node_summary, mods_block]
	_set_text_control(_mods_text, tile_text)

	# Local effects summary (if Fragment implements it)
	var eff_text: String = "None"
	if _current_fragment != null and is_instance_valid(_current_fragment) and _current_fragment.has_method("get_local_effects_summary"):
		eff_text = String(_current_fragment.call("get_local_effects_summary"))
	_set_text_control(_effects_text, eff_text)


func _get_modifiers_from_fragment(frag: Node) -> Array:
	if frag == null or not is_instance_valid(frag):
		return []
	if not ("modifiers" in frag):
		return []
	var v: Variant = frag.get("modifiers")
	if v is Array:
		return v
	return []


func _modifier_to_line(m: Variant) -> String:
	# New format (Dictionary)
	if m is Dictionary:
		var d: Dictionary = m
		var kind: String = String(d.get("kind", "")).strip_edges()
		var skill: String = String(d.get("skill", "")).strip_edges().to_lower()
		var name: String = String(d.get("name", d.get("detail", ""))).strip_edges()
		var rarity: String = String(d.get("rarity", "")).strip_edges()

		if name == "":
			name = String(d.get("text", "")).strip_edges()
		if kind == "":
			return ""

		var out: String = ""
		if rarity != "":
			out += "%s " % rarity
		out += kind
		if skill != "":
			out += " [%s]" % skill
		if name != "":
			out += ": %s" % name
		return out

	# Legacy format (String)
	if typeof(m) == TYPE_STRING:
		return String(m).strip_edges()

	return ""


func _set_text_control(ctrl: Control, text: String) -> void:
	if ctrl == null:
		return
	if ctrl is RichTextLabel:
		var r: RichTextLabel = ctrl as RichTextLabel
		r.clear()
		r.append_text(text)
	elif ctrl is Label:
		(ctrl as Label).text = text
	elif ctrl.has_method("set_text"):
		ctrl.call("set_text", text)


# ---------- Buildings tab ----------
func _update_building_tab() -> void:
	if _base_slot == null:
		return

	if _current_fragment == null or not is_instance_valid(_current_fragment):
		_base_slot.icon = null
		_base_slot.text = ""
		if _current_building_label:
			_current_building_label.text = "Current: (no tile)"
		_set_module_slots_visible(0)
		_set_module_slot_labels([])
		return

	var base_id: String = ""
	if _current_fragment.has_meta("building_id"):
		base_id = String(_current_fragment.get_meta("building_id"))

	var modules: Array = []
	if _current_fragment.has_meta("building_modules"):
		var m: Variant = _current_fragment.get_meta("building_modules")
		if m is Array:
			modules = m

	var max_slots: int = 0
	if base_id != "":
		max_slots = 3

	_set_module_slots_visible(max_slots)

	if _current_building_label:
		_current_building_label.text = "Current base: %s" % (base_id if base_id != "" else "(none)")

	_base_slot.text = ""
	_set_module_slot_labels(modules)


func _set_module_slots_visible(count: int) -> void:
	for i in range(_module_slots.size()):
		var btn: Button = _module_slots[i]
		if btn:
			btn.visible = (i < count)


func _set_module_slot_labels(modules: Array) -> void:
	for i in range(_module_slots.size()):
		var btn: Button = _module_slots[i]
		if btn:
			btn.text = ""  # icon-only look


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


func _is_valid_building_item_for_slot(item_id: String, slot_type: String) -> bool:
	if item_id == "":
		return false

	# Preferred: use ConstructionSystem blueprints if available.
	if _construction and _construction.has_method("get_blueprint"):
		var bp: Variant = _construction.call("get_blueprint", item_id)
		if bp is Dictionary:
			var kind: String = String((bp as Dictionary).get("kind", ""))
			if slot_type == "base":
				return kind == "base"
			if slot_type == "module":
				return kind == "module"
			return false

	# Fallback: naming convention
	if slot_type == "base":
		return item_id.ends_with("_base")
	if slot_type == "module":
		return not item_id.ends_with("_base")

	return false
