# SkillProgress.gd
extends Node

signal xp_changed(skill_id: String, new_xp: int, new_level: int)
signal level_changed(skill_id: String, new_level: int)

const MAX_LEVEL: int = 120

# xp_table[level] = total XP required to be that level (1..MAX_LEVEL)
var xp_table: Array[int] = []

# grovetime state: per-skill XP + level
var xp: Dictionary = {}      # skill_id -> total xp
var level: Dictionary = {}   # skill_id -> current level


func _ready() -> void:
	# Build the XP table once
	_ensure_xp_table()

	# Initialise skills once SkillsDB is ready
	if Skills.skills.is_empty():
		Skills.loaded.connect(_on_skills_loaded)
	else:
		_on_skills_loaded()


# --- XP TABLE (groveeScape-esque curve) ---

func _ensure_xp_table() -> void:
	if xp_table.size() >= MAX_LEVEL + 1:
		return

	xp_table.clear()
	xp_table.resize(MAX_LEVEL + 1)

	# Convention:
	# level 1 = 0 XP, stored at xp_table[1]
	xp_table[0] = 0
	xp_table[1] = 0

	var points := 0.0
	for lvl in range(1, MAX_LEVEL):
		# Classic groveeScape-like formula:
		# Accumulate "points", then divide by 4 and floor.
		points += floor(float(lvl) + 300.0 * pow(2.0, float(lvl) / 7.0))
		xp_table[lvl + 1] = int(floor(points / 4.0))
	# Now:
	#   xp_table[1] = 0       (level 1)
	#   xp_table[2] ≈ 83      (level 2)
	#   xp_table[10] ≈ 4511   (level 10)
	#   ...
	#   xp_table[99] ≈ 13M    (level 99)
	#   xp_table[120] ≈ 104M  (level 120)


# --- Initialise skills from SkillsDB ---

func _on_skills_loaded() -> void:
	xp.clear()
	level.clear()

	for rec in Skills.get_all():
		var id := String(rec.get("id", ""))
		if id.is_empty():
			continue
		if not xp.has(id):
			xp[id] = 0
			level[id] = 1


# --- Queries ---

func get_xp(skill_id: String) -> int:
	return int(xp.get(skill_id, 0))


func get_level(skill_id: String) -> int:
	return int(level.get(skill_id, 1))


func get_xp_for_level(target_level: int) -> int:
	_ensure_xp_table()
	target_level = clamp(target_level, 1, MAX_LEVEL)
	return xp_table[target_level]


func get_xp_to_next(skill_id: String) -> int:
	_ensure_xp_table()

	var cur_lv := get_level(skill_id)
	if cur_lv >= MAX_LEVEL:
		return 0

	var cur_xp := get_xp(skill_id)
	var next_lv_xp := get_xp_for_level(cur_lv + 1)

	return max(0, next_lv_xp - cur_xp)


func get_level_progress(skill_id: String) -> float:
	# 0.0–1.0 progress within the current level (for your XP bar)
	_ensure_xp_table()

	var cur_lv := get_level(skill_id)
	if cur_lv >= MAX_LEVEL:
		return 1.0

	var cur_xp := get_xp(skill_id)
	var this_lv_xp := get_xp_for_level(cur_lv)
	var next_lv_xp := get_xp_for_level(cur_lv + 1)
	var span := float(next_lv_xp - this_lv_xp)
	if span <= 0.0:
		return 0.0

	return clamp((float(cur_xp - this_lv_xp) / span), 0.0, 1.0)

# --- Mutations ---

func add_xp(skill_id: String, amount: int) -> void:
	if amount <= 0:
		return

	_ensure_xp_table()

	if not xp.has(skill_id):
		xp[skill_id] = 0
		level[skill_id] = 1

	var old_xp := int(xp[skill_id])
	var new_xp := old_xp + amount
	xp[skill_id] = new_xp

	var old_lv := int(level[skill_id])
	var new_lv := _level_for_xp(new_xp)

	if new_lv != old_lv:
		level[skill_id] = new_lv
		level_changed.emit(skill_id, new_lv)

	xp_changed.emit(skill_id, new_xp, int(level[skill_id]))


func _level_for_xp(total_xp: int) -> int:
	_ensure_xp_table()

	var result := 1
	for lvl in range(1, MAX_LEVEL + 1):
		if total_xp >= xp_table[lvl]:
			result = lvl
		else:
			break
	return result
