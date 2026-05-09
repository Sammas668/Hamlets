extends Node

const MAX_LEVEL: int = 120

# xp_table[level] = total XP required to be that level.
# Valid level range: 1..MAX_LEVEL
var xp_table: Array[int] = []


func _ready() -> void:
	_ensure_xp_table()


func _ensure_xp_table() -> void:
	if xp_table.size() >= MAX_LEVEL + 1:
		return

	xp_table.clear()
	xp_table.resize(MAX_LEVEL + 1)

	xp_table[0] = 0
	xp_table[1] = 0

	var points := 0.0
	for lvl in range(1, MAX_LEVEL):
		points += floor(float(lvl) + 300.0 * pow(2.0, float(lvl) / 7.0))
		xp_table[lvl + 1] = int(floor(points / 4.0))


func get_xp_for_level(level: int) -> int:
	_ensure_xp_table()
	level = clampi(level, 1, MAX_LEVEL)
	return int(xp_table[level])


func get_level_for_xp(total_xp: int) -> int:
	_ensure_xp_table()

	total_xp = max(0, total_xp)

	var result := 1
	for lvl in range(1, MAX_LEVEL + 1):
		if total_xp >= int(xp_table[lvl]):
			result = lvl
		else:
			break

	return result


func get_xp_into_level(total_xp: int) -> int:
	_ensure_xp_table()

	var level := get_level_for_xp(total_xp)
	if level >= MAX_LEVEL:
		return 0

	return max(0, total_xp - get_xp_for_level(level))


func get_xp_to_next(total_xp: int) -> int:
	_ensure_xp_table()

	var level := get_level_for_xp(total_xp)
	if level >= MAX_LEVEL:
		return 0

	var next_level_xp := get_xp_for_level(level + 1)
	return max(0, next_level_xp - max(0, total_xp))


func get_level_progress(total_xp: int) -> float:
	_ensure_xp_table()

	var level := get_level_for_xp(total_xp)
	if level >= MAX_LEVEL:
		return 1.0

	var this_level_xp := get_xp_for_level(level)
	var next_level_xp := get_xp_for_level(level + 1)
	var span := float(next_level_xp - this_level_xp)

	if span <= 0.0:
		return 0.0

	return clampf(float(total_xp - this_level_xp) / span, 0.0, 1.0)
