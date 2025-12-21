extends Panel

signal building_equip_requested(coord: Vector2i, building_id: String)

# --- UI refs (wired in _ready) ---
var _tabs: TabContainer = null

# Tile tab
var _biome    : Label   = null
var _coord    : Label   = null
var _buffs    : Control = null   # Label or RichTextLabel
var _effects  : Control = null   # Label or RichTextLabel
var _modifiers: Control = null   # Label or RichTextLabel

# Buildings tab
var _current_building_label: Label         = null
var _base_row              : HBoxContainer = null
var _base_slot             : Button        = null
var _modules_row           : HBoxContainer = null

var _module_slots: Array[Button] = []

# --- State ---
var _current_fragment: Node = null
var _current_coord: Vector2i = Vector2i.ZERO

const SLOT_SIZE := Vector2(72, 72)  # square building/module slots

func _ready() -> void:
	visible = false

	_wire_ui()

	# --- Layout: bottom-left, good size ---
	anchor_left   = 0.0
	anchor_right  = 0.0
	anchor_top    = 1.0
	anchor_bottom = 1.0

	var PANEL_WIDTH: float  = 720.0
	var PANEL_HEIGHT: float = 560.0

	offset_left   = 16.0
	offset_right  = 16.0 + PANEL_WIDTH
	offset_bottom = -16.0
	offset_top    = -PANEL_HEIGHT - 16.0

	if _tabs:
		_tabs.anchor_left   = 0.0
		_tabs.anchor_top    = 0.0
		_tabs.anchor_right  = 1.0
		_tabs.anchor_bottom = 1.0
		_tabs.offset_left   = 8.0
		_tabs.offset_top    = 8.0
		_tabs.offset_right  = -8.0
		_tabs.offset_bottom = -8.0

	# Centre base row + modules row a bit
	if _base_row:
		_base_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_base_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _base_slot:
		# Make base slot a square icon slot
		_base_slot.custom_minimum_size = SLOT_SIZE
		_base_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_base_slot.text = ""
		_base_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let panel handle drops

	if _modules_row:
		_modules_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_modules_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for btn in _module_slots:
			btn.custom_minimum_size = SLOT_SIZE
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.text = ""
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect Selection autoload
	if typeof(Selection) != TYPE_NIL:
		if not Selection.fragment_selected.is_connected(_on_fragment_selected):
			Selection.fragment_selected.connect(_on_fragment_selected)
	else:
		push_error("[SelectionHUD] Autoload 'Selection' missing.")

	_update_building_tab()


func _wire_ui() -> void:
	# Tabs must exist somewhere under this panel.
	_tabs = get_node_or_null("Tabs") as TabContainer
	if _tabs == null:
		# Try to find any TabContainer under this node
		for child in get_children():
			if child is TabContainer:
				_tabs = child
				break

	if _tabs == null:
		push_error("[SelectionHUD] No TabContainer (Tabs) found under SelectionHUD.")
		return

	# Look up children by NAME anywhere under Tabs
	_biome     = _tabs.find_child("Biome",         true, false) as Label
	_coord     = _tabs.find_child("Coord",         true, false) as Label
	_buffs     = _tabs.find_child("BuffsText",     true, false) as Control
	_effects   = _tabs.find_child("EffectsText",   true, false) as Control
	_modifiers = _tabs.find_child("ModifiersText", true, false) as Control

	_current_building_label = _tabs.find_child("CurrentBuilding", true, false) as Label
	_base_row               = _tabs.find_child("BaseRow",         true, false) as HBoxContainer
	_base_slot              = _tabs.find_child("BaseSlot",        true, false) as Button
	_modules_row            = _tabs.find_child("ModulesRow",      true, false) as HBoxContainer

	# Collect module slot buttons
	_module_slots.clear()
	if _modules_row:
		for c in _modules_row.get_children():
			var b := c as Button
			if b:
				_module_slots.append(b)

	print("[SelectionHUD] wired:",
		" biome=", _biome,
		" coord=", _coord,
		" buffs=", _buffs,
		" effects=", _effects,
		" modifiers=", _modifiers,
		" current_building_label=", _current_building_label,
		" base_slot=", _base_slot,
		" module_slots=", _module_slots.size()
	)


func _on_fragment_selected(f: Node) -> void:
	show_for_fragment(f)


func show_for_fragment(f: Node) -> void:
	_apply_fragment(f)


func _apply_fragment(f: Node) -> void:
	if f == null or not is_instance_valid(f):
		visible = false
		_current_fragment = null
		_current_coord = Vector2i.ZERO
		_update_building_tab()
		return

	visible = true
	_current_fragment = f

	print("[SelectionHUD] _apply_fragment: f=", f, " is Fragment? ", f is Fragment)

	# --- Biome ---
	var biome_v: Variant = f.get("biome")
	if _biome:
		var b_str: String = ""
		if biome_v is String:
			b_str = biome_v
		elif biome_v is StringName:
			b_str = String(biome_v)
		else:
			b_str = str(biome_v)
		_biome.text = "Biome: %s" % (b_str if b_str != "" else "—")

	# --- Coord ---
	var coord_v: Variant = f.get("coord")
	if coord_v is Vector2i:
		var ax: Vector2i = coord_v
		_current_coord = ax
		if _coord:
			_coord.text = "Coord: q=%d, r=%d" % [ax.x, ax.y]
	else:
		_current_coord = Vector2i.ZERO
		if _coord:
			_coord.text = "Coord: —"

	# --- Detailed effects (big box) ---
	var eff_text: String = "None"
	if f.has_method("get_local_effects_summary"):
		eff_text = String(f.call("get_local_effects_summary"))
	_set_text_control(_effects, eff_text)

	# --- Total buffs/debuffs summary ---
	var buffs_text: String = eff_text
	_set_text_control(_buffs, "Total buffs/debuffs:\n" + buffs_text)

	# --- Modifiers list (read from Fragment.modifiers) ---
	var mods: Array[String] = []

	if f is Fragment:
		var frag: Fragment = f as Fragment
		mods = frag.modifiers.duplicate()
		print("[SelectionHUD] frag.modifiers =", frag.modifiers)
	else:
		var mods_var: Variant = f.get("modifiers")
		if mods_var is Array:
			for m in (mods_var as Array):
				mods.append(String(m))

	if mods.is_empty() and typeof(ResourceNodes) != TYPE_NIL:
		if ResourceNodes.has_method("get_modifiers_for_tile"):
			var rn_mods: Variant = ResourceNodes.get_modifiers_for_tile(_current_coord)
			if rn_mods is Array:
				for m2 in (rn_mods as Array):
					mods.append(String(m2))

	var mods_text: String = "None"
	if mods.size() > 0:
		var parts: Array[String] = []
		for m in mods:
			parts.append(String(m))
		mods_text = ", ".join(parts)

	_set_text_control(_modifiers, "Modifiers: " + mods_text)

	print("[SelectionHUD] coord=", _current_coord, " mods(final)=", mods)

	_update_building_tab()


func _set_text_control(ctrl: Control, text: String) -> void:
	if ctrl == null:
		return
	if ctrl is RichTextLabel:
		var r: RichTextLabel = ctrl as RichTextLabel
		r.clear()
		r.append_text(text)
	elif ctrl is Label:
		var l: Label = ctrl as Label
		l.text = text
	elif ctrl.has_method("set_text"):
		ctrl.call("set_text", text)


# ---------- Buildings tab (display only, ready for drag-drop) ----------

func _update_building_tab() -> void:
	if _base_slot == null:
		return

	if _current_fragment == null or not is_instance_valid(_current_fragment):
		# No tile selected – clear visuals
		_base_slot.icon = null
		_base_slot.text = ""
		if _current_building_label:
			_current_building_label.text = "Current: (no tile)"
		_set_module_slots_visible(0)
		_set_module_slot_labels([])
		return

	# Read base + modules from fragment meta
	var base_id: String = ""
	if _current_fragment.has_meta("building_id"):
		base_id = String(_current_fragment.get_meta("building_id"))

	var modules: Array = []
	if _current_fragment.has_meta("building_modules"):
		var m: Variant = _current_fragment.get_meta("building_modules")
		if m is Array:
			modules = m

	# Show module slots only if there is a base
	var max_slots: int = 0
	if base_id != "":
		max_slots = 3

	_set_module_slots_visible(max_slots)

	# We only use the label to show current base; slots themselves are icon-only.
	if _current_building_label:
		_current_building_label.text = "Current base: %s" % (base_id if base_id != "" else "(none)")

	# Keep slot texts empty so icons dominate
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
			var label: String = ""
			if i < modules.size() and modules[i] is String and modules[i] != "":
				label = String(modules[i])
			# If you want the text visible, uncomment:
			# btn.text = "Module %d: %s" % [i + 1, label]
			btn.text = ""  # icon-only look


# ---------- Helpers for future drag/drop equip (manual calls) ----------

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

	var max_index: int = _module_slots.size() - 1
	if max_index < 0:
		max_index = 0

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

	# 1) Validate payload
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

	# 2) Convert local drop position (relative to this Panel) to global coords
	var global_pos: Vector2 = global_position + at_position
	# If you're on Godot 4 and prefer, you *could* use:
	# var global_pos: Vector2 = get_global_transform_with_canvas().xform(at_position)

	# 3) Check base slot
	if _base_slot and _base_slot.get_global_rect().has_point(global_pos):
		info["slot_type"] = "base"
		info["slot_index"] = 0
		info["item_id"] = item_id
		info["icon"] = icon_tex
		return info

	# 4) Check module slots
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

	# 1) Only allow valid building items for this slot
	if not _is_valid_building_item_for_slot(item_id, slot_type):
		return false

	# 2) Don't allow modules unless there's already a base on this tile
	if slot_type == "module":
		var has_base := false
		if _current_fragment and _current_fragment.has_meta("building_id"):
			var base_id := String(_current_fragment.get_meta("building_id"))
			has_base = base_id != ""
		if not has_base:
			return false

	# 3) Check bank has at least one of the item
	if typeof(Bank) == TYPE_NIL:
		return false
	if not Bank.has_method("has_at_least"):
		return true

	return Bank.has_at_least(item_id, 1)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var info := _get_drop_slot_info(at_position, data)
	if info.is_empty():
		return

	var building_id: String = String(info["item_id"])
	var icon_tex: Texture2D = null
	if info.has("icon") and info["icon"] is Texture2D:
		icon_tex = info["icon"] as Texture2D

	# Pay cost: remove 1 from bank
	if typeof(Bank) != TYPE_NIL and Bank.has_method("has_at_least") and Bank.has_method("add"):
		if not Bank.has_at_least(building_id, 1):
			return
		Bank.add(building_id, -1)

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

	# Update base slot icon
	if _base_slot:
		if icon_tex:
			_base_slot.icon = icon_tex
		_base_slot.text = ""

	# Clear module slot icons (since modules were reset)
	for btn in _module_slots:
		if btn:
			btn.icon = null
			btn.text = ""

	# Return old base + modules to bank
	if typeof(Bank) != TYPE_NIL and Bank.has_method("add"):
		if old_base != "":
			Bank.add(old_base, 1)
		for m_id in old_modules:
			if m_id is String and String(m_id) != "":
				Bank.add(String(m_id), 1)

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

	# Update icon for that module slot
	if idx < _module_slots.size():
		var btn: Button = _module_slots[idx]
		if btn:
			if icon_tex:
				btn.icon = icon_tex
			btn.text = ""
			btn.visible = true

	# Return replaced module to bank
	if old_id != "" and typeof(Bank) != TYPE_NIL and Bank.has_method("add"):
		Bank.add(old_id, 1)

	emit_signal("building_equip_requested", _current_coord, building_id)
	_update_building_tab()
func _is_valid_building_item_for_slot(item_id: String, slot_type: String) -> bool:
	if item_id == "":
		return false

	# Preferred: use ConstructionSystem blueprints if available.
	# Expecting blueprints with a "kind" field: "base" or "module".
	if typeof(ConstructionSystem) != TYPE_NIL and ConstructionSystem.has_method("get_blueprint"):
		var bp = ConstructionSystem.get_blueprint(item_id)  # no ':=' → no type inference error

		# If we actually got a Dictionary back, use its "kind" field
		if bp is Dictionary:
			var bp_dict: Dictionary = bp
			var kind: String = String(bp_dict.get("kind", ""))  # "base" or "module"

			if slot_type == "base":
				return kind == "base"
			elif slot_type == "module":
				return kind == "module"
			return false
		# If bp is not a Dictionary or is null, we just fall through to the naming fallback below.

	# Fallback: naming convention if ConstructionSystem is not usable
	# or the blueprint was not a Dictionary.
	if slot_type == "base":
		# e.g. "foragers_hut_base"
		return item_id.ends_with("_base")
	elif slot_type == "module":
		# anything that is *not* a base is treated as module
		return not item_id.ends_with("_base")

	return false
