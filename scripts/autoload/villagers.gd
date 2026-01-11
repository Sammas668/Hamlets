extends Node
# Minimal villager model + selection + XP/leveling (stable IDs)

signal list_changed
signal selected_changed(index: int)
signal xp_changed(index: int, new_xp: int, new_level: int)

# --- Skills (24 skills) ---
const SKILL_IDS: PackedStringArray = [
	"mining", "fishing", "woodcutting", "herbalism", "scrying", "farming",
	"smithing", "construction", "tailoring", "cooking", "gemcrafting", "entertaining",
	"slayer", "runecrafting", "transmutation", "divination", "astromancy", "spiritbinding",
	"attack", "ranged", "defence", "prayer", "magic", "summoning",
]

# --- Gender + portrait data ---------------------------------------

const GENDER_MALE   := "male"
const GENDER_FEMALE := "female"
const GENDER_OTHER  := "other"

const DEFAULT_ICON_PATH := "res://assets/villagers/default.png"

const NAME_POOLS := {
	# Fallback / generic pool
	"default": {
		"male_first": [
			"Aren", "Bran", "Corin", "Darin", "Edrin",
			"Fen", "Garran", "Hale", "Isen", "Jarek",
			"Kael", "Loric", "Merek", "Niall", "Orrin",
			"Perrin", "Rian", "Soren", "Tomas", "Varric",
		],
		"female_first": [
			"Aela", "Bria", "Cera", "Daya", "Elin",
			"Fara", "Gwyn", "Hessa", "Isla", "Kira",
			"Lysa", "Maera", "Neris", "Orla", "Pela",
			"Reya", "Sela", "Talia", "Vera", "Yara",
		],
		"last": [
			"Stone", "Reed", "Hollow", "Vale", "Ash",
			"Brook", "Thorn", "Dale", "Marsh", "Kite",
			"Fernlow", "Wilde", "Ridgeway", "Mistvale",
		],
	},

	# Human-specific pool
	"human": {
		"male_first": [
			"Aldren", "Beren", "Calen", "Darrow", "Edrik",
			"Faelan", "Garrick", "Hadren", "Ivar", "Jorin",
			"Kael", "Lukan", "Marek", "Nolan", "Orric",
			"Pascal", "Roder", "Seren", "Tristan", "Wyatt",
		],
		"female_first": [
			"Asha", "Brielle", "Celia", "Darya", "Elira",
			"Fiona", "Galenna", "Helena", "Isolde", "Jessa",
			"Kara", "Liora", "Mira", "Nerine", "Orielle",
			"Perra", "Rhea", "Serin", "Tarin", "Velena",
		],
		"last": [
			"Greywind", "Hearthborn", "Ironglen", "Mistvale",
			"Ridgeway", "Stormholt", "Fernbrook", "Oakshield",
			"Deepwater", "Highfield",
		],
	},

	# Ratfolk example – flavourful, still split by gender
	"ratfolk": {
		"male_first": [
			"Nib", "Skit", "Riff", "Scrap", "Twitch",
			"Patch", "Gnaw", "Rattle", "Scuff", "Whisk",
		],
		"female_first": [
			"Merri", "Talla", "Whisp", "Serri", "Ketta",
			"Nettle", "Pip", "Rella", "Squeak", "Trill",
		],
		"last": [
			"Underbarrow", "Quicktail", "Dustpaw", "Narrowstep",
			"Hearthburrow", "Cobblerun", "Tangleburrow",
		],
	},
}

# Per-race portrait definitions.
# 🔧 Tweak these paths to match your actual PNGs.
const RACE_PORTRAITS := {
	"human": {
		# Humans can be male or female
		"genders": [GENDER_MALE, GENDER_FEMALE],
		"icons": {
			GENDER_MALE: [
				"res://assets/villagers/human/Human Male 1.png",
				# Add more human male variants here if you have them
			],
			GENDER_FEMALE: [
				"res://assets/villagers/human/Human Female 1.png",
				# Add more human female variants here if you have them
			],
		},
	},

	"hill_dwarf": {
		# Single-gender race: only male
		"genders": [GENDER_MALE],
		"icons": {
			GENDER_MALE: [
				"res://assets/villagers/dwarf/Dwarf Male 1.png",
				"res://assets/villagers/dwarf/Dwarf Male 2.png",
				"res://assets/villagers/dwarf/Dwarf Male 3.png",
				"res://assets/villagers/dwarf/Dwarf Male 4.png",
				"res://assets/villagers/dwarf/Dwarf Male 5.png",
				"res://assets/villagers/dwarf/Dwarf Male 6.png",
			],
		},
	},

	"wood_elf": {
		"genders": [GENDER_MALE, GENDER_FEMALE],
		"icons": {
			GENDER_MALE: [
				"res://assets/villagers/elf/Wood Elf Male 1.png",
				"res://assets/villagers/elf/Wood Elf Male 2.png",
				"res://assets/villagers/elf/Wood Elf Male 3.png",
				"res://assets/villagers/elf/Wood Elf Male 4.png",
				"res://assets/villagers/elf/Wood Elf Male 5.png",
			],
			GENDER_FEMALE: [
				"res://assets/villagers/elf/Wood Elf Female 1.png",
				"res://assets/villagers/elf/Wood Elf Female 2.png",
				"res://assets/villagers/elf/Wood Elf Female 3.png",
				"res://assets/villagers/elf/Wood  Elf Female 4.png",
				"res://assets/villagers/elf/Wood Elf Female 5.png",
			],
		},
	},

	"naiad": {
		# Single-gender race: only female
		"genders": [GENDER_FEMALE],
		"icons": {
			GENDER_FEMALE: [
				"res://assets/villagers/Naiad/Naiad Female 1.png",
				"res://assets/villagers/Naiad/Naiad Female 2.png",
				"res://assets/villagers/Naiad/Naiad Female 3.png",
				"res://assets/villagers/Naiad/Naiad Female 4.png",
				"res://assets/villagers/Naiad/Naiad Female 5.png",
			],
		},
	},
}


class Villager:
	var id: int
	var name: String
	var level: int = 1
	var xp: int = 0  # XP within current villager-level (global)
	var attributes: Dictionary = {}  # e.g. {"STR":{"base":10}}
	var race: String = "human"
	var gender: String = ""          # "male", "female", etc.
	var icon: String = ""
	var skills: Dictionary = {}      # skill_id -> { "level": int, "xp": int }

	func _init(_id: int, _name: String, _race: String = "human", _gender: String = "") -> void:
		id = _id
		name = _name
		race = _race
		gender = _gender



# --- Data ----------------------------------------------------------

var _villagers: Array[Villager] = []
var _selected_idx: int = -1

# Stable ID counter + lookup map (id -> index)
var _next_id: int = 1
var _id_to_index: Dictionary = {}     # { id:int : index:int }

# Track which portrait paths are already in use → to avoid duplicates
var _used_icons: Dictionary = {}      # { "res://path.png": true }

# Founder tracking (bound to starting Hamlet tile)
var _founder_id: int = -1             # id of the founder villager (if any)

# Each villager-level requires (level * xp_per_level) XP
@export var xp_per_level: int = 100

# Each skill level requires (level * skill_xp_per_level) XP.
@export var skill_xp_per_level: int = 50


func _init_skills_for(v: Villager) -> void:
	v.skills = {}
	for sid in SKILL_IDS:
		v.skills[sid] = {
			"level": 1,
			"xp": 0,
		}


# --- Helpers/UI feeds ----------------------------------------------

func _get_first_name_list(base_name: String, gender_id: String) -> Array:
	var key := base_name.to_lower()
	if not NAME_POOLS.has(key):
		key = "default"

	var pool: Dictionary = NAME_POOLS[key]
	var g := gender_id.to_lower()

	if g == GENDER_MALE:
		return pool.get("male_first", [])
	elif g == GENDER_FEMALE:
		return pool.get("female_first", [])

	# GENDER_OTHER or unknown → merge both lists
	var both: Array = []
	both.append_array(pool.get("male_first", []))
	both.append_array(pool.get("female_first", []))
	return both


func as_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in _villagers.size():
		var v: Villager = _villagers[i]
		out.append({
			"id": v.id,
			"name": v.name,
			"level": v.level,
			"xp": v.xp,
			"race": v.race,
			"gender": v.gender,
			"icon": v.icon,
		})
	return out

func count() -> int:
	return _villagers.size()

func get_selected_index() -> int:
	return _selected_idx

func has_selected() -> bool:
	return _selected_idx >= 0 and _selected_idx < _villagers.size()

func get_selected() -> Villager:
	assert(has_selected())
	return _villagers[_selected_idx]

func get_selected_or_null() -> Variant:
	if has_selected():
		return _villagers[_selected_idx]
	return null

func get_at(i: int) -> Villager:
	assert(i >= 0 and i < _villagers.size())
	return _villagers[i]

func index_from_id(id: int) -> int:
	return int(_id_to_index.get(id, -1))

# Founder helpers
func get_founder_id() -> int:
	return _founder_id

func get_founder_index() -> int:
	if _founder_id < 0:
		return -1
	return index_from_id(_founder_id)

func is_founder(index: int) -> bool:
	if index < 0 or index >= _villagers.size():
		return false
	return _villagers[index].id == _founder_id

# Returns numbers for UI bars: { "cur": current_xp_in_level, "need": xp_needed_for_this_level }
func xp_progress(index: int) -> Dictionary:
	if index < 0 or index >= _villagers.size():
		return {"cur": 0, "need": 1}
	var v: Villager = _villagers[index]
	var need: int = max(1, v.level * xp_per_level)
	var cur: int = int(clamp(v.xp, 0, need))
	return {"cur": cur, "need": need}

func ensure_seed_one() -> void:
	if _villagers.is_empty():
		var idx: int = add("Founder", true, "human")
		if idx >= 0:
			_founder_id = _villagers[idx].id


# --- Mutators ------------------------------------------------------

func add(
		villager_name: String = "Founder",
		select_new: bool = false,
		race: String = "human",
		gender: String = ""
) -> int:
	var id: int = _next_id
	_next_id += 1

	var v: Villager = Villager.new(id, villager_name, race, gender)
	_init_skills_for(v)
	_apply_portrait_to_villager(v)  # sets gender if needed + unique icon

	_villagers.append(v)

	var idx: int = _villagers.size() - 1
	_id_to_index[id] = idx

	list_changed.emit()

	if _selected_idx == -1 or select_new:
		_selected_idx = idx
		selected_changed.emit(_selected_idx)

	return idx


func add_villager(villager_name: String, race: String = "human", gender: String = "") -> int:
	return add(villager_name, false, race, gender)


func remove_at(idx: int) -> void:
	if idx < 0 or idx >= _villagers.size():
		return

	var removed_icon: String = _villagers[idx].icon
	if removed_icon != "" and _used_icons.has(removed_icon):
		_used_icons.erase(removed_icon)

	var removed_id: int = _villagers[idx].id
	_villagers.remove_at(idx)
	_id_to_index.erase(removed_id)

	# Rebuild id->index for shifted entries
	for i in _villagers.size():
		_id_to_index[_villagers[i].id] = i

	# If we removed the founder, clear the founder flag (or you can choose a new founder)
	if removed_id == _founder_id:
		_founder_id = -1

	# Fix selection
	if _villagers.is_empty():
		_selected_idx = -1
	else:
		_selected_idx = clamp(_selected_idx, 0, _villagers.size() - 1)

	list_changed.emit()
	selected_changed.emit(_selected_idx)

func remove_villager(v_idx: int) -> void:
	# Convenience wrapper so other systems can remove a villager by index.
	# Used by Astromancy when collapsing a fragment that has a villager on it.
	remove_at(v_idx)


func set_selected(idx: int) -> void:
	if idx >= 0 and idx < _villagers.size() and idx != _selected_idx:
		_selected_idx = idx
		selected_changed.emit(idx)

func select(idx: int) -> void:
	set_selected(idx)

# Add XP to a specific villager (by index), with level-ups
func add_xp(index: int, amount: int) -> void:
	if amount <= 0 or index < 0 or index >= _villagers.size():
		return
	var v: Villager = _villagers[index]
	v.xp += amount
	while v.xp >= v.level * xp_per_level:
		v.xp -= v.level * xp_per_level
		v.level += 1
	xp_changed.emit(index, v.xp, v.level)

func grant_xp_to_selected(amount: int) -> void:
	if has_selected():
		add_xp(_selected_idx, amount)


# --- Save/Load -----------------------------------------------------
# --- Save/Load -----------------------------------------------------
func to_save_dict() -> Dictionary:
	var arr: Array[Dictionary] = []
	for v: Villager in _villagers:
		arr.append({
			"id": v.id,
			"name": v.name,
			"level": v.level,
			"xp": v.xp,
			"race": v.race,
			"gender": v.gender,
			"icon": v.icon,
			"skills": v.skills,  # full per-skill dictionary
		})

	return {
		"villagers":  arr,
		"selected":   _selected_idx,
		"next_id":    _next_id,
		"founder_id": _founder_id,
	}


func from_save_dict(d: Dictionary) -> void:
	_villagers.clear()
	_id_to_index.clear()
	_used_icons.clear()

	var arr: Array = d.get("villagers", [])
	var max_id: int = 0

	for entry_v in arr:
		if not (entry_v is Dictionary):
			continue

		var e: Dictionary = entry_v as Dictionary

		var v_id: int = int(e.get("id", 0))
		var v_name: String = String(e.get("name", ""))
		var v_race: String = String(e.get("race", "human"))
		var v_gender: String = String(e.get("gender", ""))

		var v: Villager = Villager.new(v_id, v_name, v_race, v_gender)
		v.level = int(e.get("level", 1))
		v.xp    = int(e.get("xp", 0))
		v.icon  = String(e.get("icon", ""))

		# --- Skills (per-skill XP/levels) ---
		var skills_v: Variant = e.get("skills", {})
		if skills_v is Dictionary:
			var saved_skills: Dictionary = skills_v as Dictionary
			v.skills = {}

			# Copy saved skills
			for key in saved_skills.keys():
				var sid: String = String(key)
				var sk: Dictionary = saved_skills[key] as Dictionary
				var slv: int = int(sk.get("level", 1))
				var sxp: int = int(sk.get("xp", 0))
				v.skills[sid] = {
					"level": slv,
					"xp": sxp,
				}

			# Make sure any NEW skills in SKILL_IDS exist
			for sid2 in SKILL_IDS:
				if not v.skills.has(sid2):
					v.skills[sid2] = {
						"level": 1,
						"xp": 0,
					}
		else:
			# Older saves: no skills key → initialize all skills
			_init_skills_for(v)

		# Portrait fallback / upgrade
		if v.icon == "":
			_apply_portrait_to_villager(v)
		else:
			_used_icons[v.icon] = true

		_villagers.append(v)
		max_id = max(max_id, v_id)

	# Rebuild id → index map
	for i in range(_villagers.size()):
		_id_to_index[_villagers[i].id] = i

	# Selected index
	_selected_idx = int(d.get("selected", -1))

	# Next id counter
	_next_id = int(d.get("next_id", max_id + 1))
	if _next_id <= max_id:
		_next_id = max_id + 1

	# Founder id (backwards-compatible: default to first villager if missing)
	_founder_id = int(d.get("founder_id", -1))
	if _founder_id == -1 and not _villagers.is_empty():
		_founder_id = _villagers[0].id

	list_changed.emit()
	selected_changed.emit(_selected_idx)


# --- Attributes (base/effective) -----------------------------------

func get_attribute_base(index: int, attr: String) -> int:
	if index < 0 or index >= _villagers.size():
		return 10
	var v := _villagers[index]
	if not (v.attributes is Dictionary) or not v.attributes.has(attr):
		return 10
	return int(v.attributes[attr].get("base", 10))

func get_attribute_effective(index: int, attr: String) -> int:
	var base := get_attribute_base(index, attr)
	var delta := 0
	if has_method("get_attribute_temp_delta"):
		delta = int(call("get_attribute_temp_delta", index, attr))
	return base + delta

# --- Skill temp delta (used by menu to show +/- on the tile) ---

func get_skill_temp_delta(_index: int, _skill_id: String) -> int:
	return 0

# ---------- Per-skill level / XP API -------------------------------

func get_skill_level(v_idx: int, skill_id: String) -> int:
	var v: Villager = _get_villager_or_null(v_idx)
	if v == null:
		return 1
	if not (v.skills is Dictionary) or not v.skills.has(skill_id):
		return 1
	var s: Dictionary = v.skills[skill_id] as Dictionary
	return int(s.get("level", 1))

func add_skill_xp(v_idx: int, skill_id: String, amount: int) -> void:
	if amount <= 0:
		return

	var v: Villager = _get_villager_or_null(v_idx)
	if v == null:
		return

	# Ensure skills dictionary exists and has this skill
	if not (v.skills is Dictionary):
		_init_skills_for(v)
	if not v.skills.has(skill_id):
		v.skills[skill_id] = {
			"level": 1,
			"xp": 0,
		}

	var s: Dictionary = v.skills[skill_id] as Dictionary
	var lv: int = int(s.get("level", 1))
	var xp_cur: int = int(s.get("xp", 0))

	var remaining: int = amount

	while remaining > 0:
		var need: int = _skill_xp_to_next_level(lv)

		# Safety: avoid infinite loops if need <= 0
		if need <= 0:
			lv += 1
			xp_cur = 0
			continue

		var room: int = need - xp_cur
		if remaining < room:
			xp_cur += remaining
			remaining = 0
		else:
			remaining -= room
			lv += 1
			xp_cur = 0

	s["level"] = lv
	s["xp"] = xp_cur
	v.skills[skill_id] = s

	# Reuse xp_changed to notify UIs (CharacterMenu only cares about index).
	xp_changed.emit(v_idx, xp_cur, lv)


func get_skill_xp(v_idx: int, skill_id: String) -> int:
	var v: Villager = _get_villager_or_null(v_idx)
	if v == null:
		return 0
	if not (v.skills is Dictionary) or not v.skills.has(skill_id):
		return 0
	var s: Dictionary = v.skills[skill_id] as Dictionary
	return int(s.get("xp", 0))


func get_skill_xp_to_next(v_idx: int, skill_id: String) -> int:
	var v: Villager = _get_villager_or_null(v_idx)
	if v == null:
		return 0
	if not (v.skills is Dictionary) or not v.skills.has(skill_id):
		# If this skill wasn't initialized somehow, treat as level 1 with 0 XP.
		var need0: int = _skill_xp_to_next_level(1)
		return need0

	var s: Dictionary = v.skills[skill_id] as Dictionary
	var lv: int = int(s.get("level", 1))
	var xp_cur: int = int(s.get("xp", 0))
	var need: int = _skill_xp_to_next_level(lv)
	return max(0, need - xp_cur)


func get_skill_xp_fraction(v_idx: int, skill_id: String) -> float:
	var v: Villager = _get_villager_or_null(v_idx)
	if v == null:
		return 0.0
	if not (v.skills is Dictionary) or not v.skills.has(skill_id):
		return 0.0

	var s: Dictionary = v.skills[skill_id] as Dictionary
	var lv: int = int(s.get("level", 1))
	var xp_cur: int = int(s.get("xp", 0))
	var need: int = max(1, _skill_xp_to_next_level(lv))

	return clampf(float(xp_cur) / float(need), 0.0, 1.0)


# --- Equipment surface API (for Equipment tab) ---------------------

func get_equipped_item_name(_index: int, _slot: String) -> String:
	return ""

func get_equipped_item_stats(_index: int, _slot: String) -> Dictionary:
	return {}

# --- Derived stats for Stats tab (stringified for simple UI) -------

func get_stat_string(_index: int, stat_name: String) -> String:
	match stat_name:
		"attack_rating":   return "112"
		"defense_rating":  return "97"
		"damage_range":    return "6–12"
		"crit_chance":     return "4%"
		"resist_phys":     return "S 8% / P 6% / C 5%"
		"resist_elem":     return "F 2% / W 0% / E 1% / A 0%"
		_:
			return "-"


# --- Internal helpers ----------------------------------------------

func _get_villager_or_null(index: int) -> Villager:
	if index < 0 or index >= _villagers.size():
		return null
	return _villagers[index]

func _skill_xp_to_next_level(level: int) -> int:
	var lv: int = max(1, level)
	return max(1, lv * skill_xp_per_level)


# --- Portrait + gender logic ---------------------------------------

func _roll_gender_for_race(race_id: String) -> String:
	if RACE_PORTRAITS.has(race_id):
		var race_data: Dictionary = RACE_PORTRAITS[race_id]
		var g_v: Variant = race_data.get("genders", [])
		if g_v is Array:
			var genders: Array = g_v
			if not genders.is_empty():
				var rng := RandomNumberGenerator.new()
				rng.randomize()
				var idx := rng.randi_range(0, genders.size() - 1)
				return String(genders[idx])

	# Fallback 50/50 (Godot 4 ternary)
	var rng2 := RandomNumberGenerator.new()
	rng2.randomize()
	return GENDER_MALE if rng2.randi() % 2 == 0 else GENDER_FEMALE


func _pick_portrait_path_for(race_id: String, gender: String) -> String:
	if not RACE_PORTRAITS.has(race_id):
		return DEFAULT_ICON_PATH

	var race_data: Dictionary = RACE_PORTRAITS[race_id]

	var icon_sets_v: Variant = race_data.get("icons", {})
	if not (icon_sets_v is Dictionary):
		return DEFAULT_ICON_PATH
	var icon_sets: Dictionary = icon_sets_v as Dictionary

	var all_icons: Array = []

	# Try gender-specific icons first
	if icon_sets.has(gender):
		var arr_v: Variant = icon_sets[gender]
		if arr_v is Array:
			var arr: Array = arr_v
			all_icons = arr.duplicate()

	# If no icons for this gender, flatten all available icons
	if all_icons.is_empty():
		for key in icon_sets.keys():
			var arr2_v: Variant = icon_sets[key]
			if arr2_v is Array:
				var arr2: Array = arr2_v
				for p in arr2:
					all_icons.append(p)

	if all_icons.is_empty():
		return DEFAULT_ICON_PATH

	# Filter out already-used portraits
	var candidates: Array[String] = []
	for p in all_icons:
		var path: String = String(p)
		if not _used_icons.has(path):
			candidates.append(path)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	if not candidates.is_empty():
		var idx := rng.randi_range(0, candidates.size() - 1)
		return candidates[idx]
	else:
		# All portraits used already → allow reuse
		var idx2 := rng.randi_range(0, all_icons.size() - 1)
		return String(all_icons[idx2])


func _apply_portrait_to_villager(v: Villager) -> void:
	# If icon already set (e.g. from save), just track it and bail
	if v.icon != "":
		if not _used_icons.has(v.icon):
			_used_icons[v.icon] = true
		return

	var race_id: String = v.race
	var gender: String = v.gender

	if gender == "" or gender == "unspecified":
		gender = _roll_gender_for_race(race_id)
		v.gender = gender

	var chosen: String = _pick_portrait_path_for(race_id, gender)
	if chosen == "":
		chosen = DEFAULT_ICON_PATH

	v.icon = chosen
	if chosen != "":
		_used_icons[chosen] = true


func get_icon_path(v_idx: int) -> String:
	if v_idx < 0 or v_idx >= _villagers.size():
		return ""

	var v: Villager = _villagers[v_idx]

	# If already set, just return it
	if v.icon != "":
		return v.icon

	# Otherwise compute from race/gender and cache the result
	_apply_portrait_to_villager(v)
	return v.icon


# --- Name generation helper ----------------------------------------

func _generate_villager_name(pool_key: String, gender_id: String) -> String:
	# pool_key is usually something like "human", "ratfolk", or "default"
	var first_list: Array = _get_first_name_list(pool_key, gender_id)

	var key := pool_key.to_lower()
	if not NAME_POOLS.has(key):
		key = "default"
	var pool: Dictionary = NAME_POOLS[key]
	var last_list: Array = pool.get("last", [])

	# If somehow empty, fall back to old "Base 12" pattern
	if first_list.is_empty() and last_list.is_empty():
		return "%s %d" % [pool_key, _next_id]

	# Stable-ish RNG so the same id+race+gender combo gives the same name
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%d" % [pool_key, gender_id, _next_id])

	var first: String = pool_key
	if not first_list.is_empty():
		first = first_list[rng.randi_range(0, first_list.size() - 1)]

	var last: String = ""
	if not last_list.is_empty():
		last = last_list[rng.randi_range(0, last_list.size() - 1)]

	if last == "":
		return first
	return "%s %s" % [first, last]


# --- Auto-recruit from biome ---------------------------------------

func auto_recruit_from_biome(biome: String) -> int:
	var race_id := "human"
	# This controls which name pool to use ("human", "ratfolk", or "default")
	var name_pool_key := "default"

	match biome:
		# Mountain-family biomes → Hill Dwarf
		"Mountain", "Foothill Valleys", "Painted Canyon":
			race_id = "hill_dwarf"
			name_pool_key = "default"  # until you define a dwarf-specific pool

		# Forest-family biomes → Wood Elf
		"Forest", "Maplewood Vale", "Silkwood":
			race_id = "wood_elf"
			name_pool_key = "default"  # until you define an elf-specific pool

		# River-family biomes → Naiad
		"River", "Rocky Estuary", "Cenote Sinkholes":
			race_id = "naiad"
			name_pool_key = "default"  # ditto

		# Fallback → Human with human name pool
		_:
			race_id = "human"
			name_pool_key = "human"

	# Roll a gender that obeys the race's allowed genders
	var gender: String = _roll_gender_for_race(race_id)

	# Generate a name from the chosen pool
	var villager_name := _generate_villager_name(name_pool_key, gender)

	# Create the villager and return its index
	var v_idx: int = add_villager(villager_name, race_id, gender)
	return v_idx
