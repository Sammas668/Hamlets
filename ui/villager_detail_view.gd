extends Control
class_name CharacterMenu

signal closed

@onready var _dim: ColorRect             = $Dim
@onready var _grid: GridContainer        = $Dim/Frame/Margin/Tabs/Skills/SkillsHeader/SkillsGrid
@onready var _attr_list: VBoxContainer   = $Dim/Frame/Margin/Tabs/Attributes/AttrList
@onready var _equip_slots: GridContainer = $Dim/Frame/Margin/Tabs/Equipment/EquipSlots
@onready var _equip_info: RichTextLabel  = $Dim/Frame/Margin/Tabs/Equipment/EquipInfo
@onready var _stats_list: VBoxContainer  = $Dim/Frame/Margin/Tabs/Stats/StatsList

const SkillCellScene: PackedScene = preload("res://ui/SkillCell.tscn")
const ATTR_ORDER := ["STR", "DEX", "CON", "WIS", "INT", "CHA"]
const GROUP_ORDER := ["Gathering", "Artisan", "Arcane", "Combat"]

# Explicit mapping from skill id -> group
const SKILL_GROUPS := {
	# Gathering
	"mining":        "Gathering",
	"fishing":       "Gathering",
	"woodcutting":   "Gathering",
	"herbalism":     "Gathering",
	"scrying":       "Gathering",
	"farming":       "Gathering",

	# Artisan
	"smithing":      "Artisan",
	"construction":  "Artisan",
	"tailoring":     "Artisan",
	"cooking":       "Artisan",
	"gemcrafting":   "Artisan",
	"entertaining":  "Artisan",

	# Arcane
	"slayer":        "Arcane",
	"runecrafting":  "Arcane",  # 🔧 fixed id
	"transmutation": "Arcane",
	"divination":    "Arcane",
	"astromancy":    "Arcane",
	"spiritbinding": "Arcane",

	# Combat
	"attack":        "Combat",
	"ranged":        "Combat",
	"defence":       "Combat",
	"prayer":        "Combat",
	"magic":         "Combat",
	"summoning":     "Combat",
}

# Explicit mapping from skill id -> primary attribute
const SKILL_ATTRS := {
	# STR column
	"mining":        "STR",
	"smithing":      "STR",
	"slayer":        "STR",
	"attack":        "STR",

	# DEX column
	"fishing":       "DEX",
	"construction":  "DEX",
	"runecrafting":  "DEX",  # 🔧 fixed id
	"ranged":        "DEX",

	# CON column
	"woodcutting":   "CON",
	"tailoring":     "CON",
	"transmutation": "CON",
	"defence":       "CON",

	# WIS column
	"herbalism":     "WIS",
	"cooking":       "WIS",
	"divination":    "WIS",
	"prayer":        "WIS",

	# INT column
	"scrying":       "INT",
	"gemcrafting":   "INT",
	"astromancy":    "INT",
	"magic":         "INT",

	# CHA column
	"farming":       "CHA",
	"entertaining":  "CHA",
	"spiritbinding": "CHA",
	"summoning":     "CHA",
}

var _villager_index: int = -1

func show_villager(villager_index: int) -> void:
	open_for(villager_index)

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL  # allow this control to take keyboard focus
	# Fill whatever area we're placed in (e.g. the right-dock tab)
	set_anchors_preset(Control.PRESET_FULL_RECT, true)

	# Dim overlay setup
	if _dim:
		_dim.color = Color(0, 0, 0, 0.5)  # semi-transparent black
		_dim.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		# Click black dim area to close — guard against double-connect
		if not _dim.gui_input.is_connected(_on_dim_gui_input):
			_dim.gui_input.connect(_on_dim_gui_input)

	visible = false

	# Optional: keep in sync with XP updates and selection
	if typeof(Villagers) != TYPE_NIL:
		if Villagers.has_signal("xp_changed") and not Villagers.xp_changed.is_connected(_on_villager_xp_changed):
			Villagers.xp_changed.connect(_on_villager_xp_changed)
		if Villagers.has_signal("selected_changed") and not Villagers.selected_changed.is_connected(_on_villager_selected_changed):
			Villagers.selected_changed.connect(_on_villager_selected_changed)

func _on_dim_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		close()

func _on_villager_selected_changed(i: int) -> void:
	if visible:
		open_for(i)

func open_for(villager_index: int) -> void:
	_villager_index = villager_index
	visible = true
	_render_skills()
	_render_attributes()
	_render_equipment()
	_render_stats()
	grab_focus()  # keyboard trap

func open_for_selected() -> void:
	var idx := -1
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_selected_index"):
		idx = int(Villagers.get_selected_index())
	if idx >= 0:
		open_for(idx)

func close() -> void:
	visible = false
	emit_signal("closed")

# ---------- Skills tab ----------
func _render_skills() -> void:
	# Clear old cells
	for c in _grid.get_children():
		c.queue_free()

	var list: Array = []

	# Load skill list
	if typeof(Skills) != TYPE_NIL and Skills.has_method("get_all"):
		list = Skills.get_all()
	elif Engine.has_singleton("Skills"):
		list = Skills.skills.duplicate()

	# One column per attribute (STR, DEX, CON, WIS, INT, CHA)
	_grid.columns = ATTR_ORDER.size()  # 6

	# Sort so rows = GROUP_ORDER and columns = ATTR_ORDER
	list.sort_custom(Callable(self, "_sort_skill_dicts"))

	for s_v in list:
		var s: Dictionary = s_v
		var id: String = String(s.get("id", ""))  # e.g. "mining"
		if id == "":
			continue

		var skill_name: String = String(s.get("name", id))

		# Icon
		var icon_tex: Texture2D = null
		var icon_path: String = String(s.get("icon", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var tex = load(icon_path)
			if tex is Texture2D:
				icon_tex = tex

		# Base + effective levels
		var base_lv: int = 1
		if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
			base_lv = int(Villagers.get_skill_level(_villager_index, id))

		var eff_lv: int = _effective_skill_level(_villager_index, id, base_lv)
		var delta: int = eff_lv - base_lv

		# XP fraction towards next level (0.0–1.0)
		var xp_frac: float = 0.0
		if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_xp_fraction"):
			xp_frac = clampf(float(Villagers.get_skill_xp_fraction(_villager_index, id)), 0.0, 1.0)

		# Create the cell
		var cell := SkillCellScene.instantiate() as SkillCell
		_grid.add_child(cell)
		cell.set_data(id, skill_name, icon_tex, eff_lv, delta, xp_frac)

		# Tooltip with XP details
		var tooltip: String = _build_skill_tooltip(id, skill_name, eff_lv, delta, xp_frac)
		cell.tooltip_text = tooltip

		# Optional: click handling if you want later
		# cell.pressed.connect(Callable(self, "_on_skill_pressed").bind(id))

func _build_skill_tooltip(
	skill_id: String,
	skill_name: String,
	eff_lv: int,
	delta: int,
	xp_frac: float
) -> String:
	var lines: Array[String] = []

	# --- Skill name ---
	lines.append("[b]%s[/b]" % skill_name)

	# --- Level (with temp bonus if any) ---
	var delta_str := ""
	if delta != 0:
		delta_str = " (%+d)" % delta
	lines.append("Level: %d%s" % [eff_lv, delta_str])

	# --- XP info ---
	var cur_xp: int = -1
	var xp_to_next: int = -1

	if typeof(Villagers) != TYPE_NIL:
		if Villagers.has_method("get_skill_xp"):
			cur_xp = int(Villagers.get_skill_xp(_villager_index, skill_id))
		if Villagers.has_method("get_skill_xp_to_next"):
			xp_to_next = int(Villagers.get_skill_xp_to_next(_villager_index, skill_id))

	# Current XP
	if cur_xp >= 0:
		lines.append("Current XP: %d" % cur_xp)

	# XP to next level
	if xp_to_next >= 0:
		lines.append("XP to next level: %d" % xp_to_next)

	# Progress percent
	var frac01: float = clampf(xp_frac, 0.0, 1.0)
	if cur_xp >= 0 and xp_to_next > 0:
		var frac_pct: int = int(round(frac01 * 100.0))
		lines.append("Progress: %d%%" % frac_pct)

	return "\n".join(lines)

func _sort_skill_dicts(a: Dictionary, b: Dictionary) -> bool:
	# Use the skill id as the source of truth
	var ida: String = String(a.get("id", ""))
	var idb: String = String(b.get("id", ""))

	# --- Row: group order (Gathering → Artisan → Arcane → Combat) ---
	var ga: String = SKILL_GROUPS.get(ida, "")
	var gb: String = SKILL_GROUPS.get(idb, "")

	var gia: int = GROUP_ORDER.find(ga)
	var gib: int = GROUP_ORDER.find(gb)

	if gia == -1:
		gia = 999
	if gib == -1:
		gib = 999

	if gia != gib:
		return gia < gib

	# --- Column: attribute order (STR → DEX → CON → WIS → INT → CHA) ---
	var aa: String = SKILL_ATTRS.get(ida, "")
	var ab: String = SKILL_ATTRS.get(idb, "")

	var aia: int = ATTR_ORDER.find(aa)
	var aib: int = ATTR_ORDER.find(ab)

	if aia == -1:
		aia = 999
	if aib == -1:
		aib = 999

	if aia != aib:
		return aia < aib

	# --- Tie-breaker: id, so sort is stable ---
	return ida < idb

func _effective_skill_level(v_idx: int, skill_id: String, base_lv: int) -> int:
	# Optional temporary bonuses from Villagers singleton
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_temp_delta"):
		var delta: int = int(Villagers.get_skill_temp_delta(v_idx, skill_id))
		return base_lv + delta
	return base_lv

# ---------- Attributes tab ----------
func _render_attributes() -> void:
	for c in _attr_list.get_children():
		c.queue_free()

	var attrs: PackedStringArray = PackedStringArray(["STR", "DEX", "CON", "WIS", "INT", "CHA"])

	if typeof(Skills) != TYPE_NIL and Skills.attributes.size() > 0:
		attrs = PackedStringArray(Skills.attributes)
	elif Engine.has_singleton("Skills") and Skills.attributes.size() > 0:
		attrs = Skills.attributes

	for attr in attrs:
		var row := HBoxContainer.new()

		var attr_label := Label.new()
		attr_label.text = attr
		attr_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var base := 10
		if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_attribute_base"):
			base = int(Villagers.get_attribute_base(_villager_index, attr))

		var eff := base
		if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_attribute_effective"):
			eff = int(Villagers.get_attribute_effective(_villager_index, attr))

		var delta := eff - base

		var value_label := Label.new()
		value_label.text = "%d (%+d)" % [eff, delta]

		row.add_child(attr_label)
		row.add_child(value_label)
		_attr_list.add_child(row)

# ---------- Equipment tab ----------
func _render_equipment() -> void:
	for c in _equip_slots.get_children():
		c.queue_free()
	_equip_info.clear()

	var slots = [
		"Head", "Cape", "Amulet", "Weapon",
		"Body", "Shield", "Legs", "Hands",
		"Feet", "Ring", "Ammo", "Charm"
	]

	for slot in slots:
		var b := Button.new()
		b.text = slot
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = _equip_slot_tooltip(slot)
		b.pressed.connect(func() -> void:
			_on_equip_slot_pressed(slot)
		)
		_equip_slots.add_child(b)

func _equip_slot_tooltip(slot: String) -> String:
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_equipped_item_name"):
		var nm: String = String(Villagers.get_equipped_item_name(_villager_index, slot))
		if nm != "":
			return "%s: %s" % [slot, nm]
	return "%s: (empty)" % slot

func _on_equip_slot_pressed(slot: String) -> void:
	if not (typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_equipped_item_stats")):
		return
	var d: Dictionary = Villagers.get_equipped_item_stats(_villager_index, slot)
	_equip_info.text = _format_item_stats(d)

func _format_item_stats(d: Dictionary) -> String:
	if d.is_empty():
		return "[i](empty)[/i]"
	var out := "[b]" + String(d.get("name", "Item")) + "[/b]\n"
	for k in d.keys():
		if k == "name":
			continue
		out += "%s: %s\n" % [k, str(d[k])]
	return out

# ---------- Stats tab ----------
func _render_stats() -> void:
	for c in _stats_list.get_children():
		c.queue_free()

	var pairs := {
		"Attack Rating": _try_stat("attack_rating"),
		"Defense Rating": _try_stat("defense_rating"),
		"Damage (min–max)": _try_stat("damage_range"),
		"Crit Chance": _try_stat("crit_chance"),
		"Resistance (Slash/Pierce/Crush)": _try_stat("resist_phys"),
		"Elemental Resists": _try_stat("resist_elem")
	}

	for label_text in pairs.keys():
		var row := HBoxContainer.new()

		var label_name := Label.new()
		label_name.text = label_text
		label_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label_value := Label.new()
		label_value.text = pairs[label_text]

		row.add_child(label_name)
		row.add_child(label_value)
		_stats_list.add_child(row)

func _try_stat(stat_name: String) -> String:
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_stat_string"):
		return String(Villagers.get_stat_string(_villager_index, stat_name))
	return "-"

func _on_skill_pressed(id: String) -> void:
	# For now just debug; later you can open a detail popup etc.
	print("Skill pressed:", id)

func _on_villager_xp_changed(idx: int, _xp: int, _lv: int) -> void:
	if not visible:
		return
	if idx == _villager_index:
		_render_skills()
