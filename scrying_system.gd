# res://autoloads/ScryingSystem.gd
extends Node

const MAX_GRADE_UNLOCKS := [
	{ "level": 1,  "grade": 1 },
	{ "level": 10, "grade": 2 },
	{ "level": 20, "grade": 3 },
	{ "level": 30, "grade": 4 },
	{ "level": 40, "grade": 5 },
	{ "level": 50, "grade": 6 },
	{ "level": 60, "grade": 7 },
	{ "level": 70, "grade": 8 },
	{ "level": 85, "grade": 9 },
	{ "level": 95, "grade": 10 },
]

# OSRS-style XP curve (you can tweak)
const SCRY_XP := {
	1: 5.0,
	2: 17.5,
	3: 26.5,
	4: 35.0,
	5: 40.0,
	6: 50.0,
	7: 65.0,
	8: 80.0,
	9: 95.0,
	10: 125.0,
}
const SCRY_XP_SCALE := 0.5

# Eclipse weighting
const MIN_ALPHA := 1.0
const MAX_ALPHA := 1.2  # gentle tilt; bump to ~1.25 if you want more bias
const TOP_TILT_MULT := 1.30
const PENULT_TILT_MULT := 1.15


# Item IDs via Items.gd
const AUGURY_IDS := {
	1: Items.AUGURY_A1,
	2: Items.AUGURY_A2,
	3: Items.AUGURY_A3,
	4: Items.AUGURY_A4,
	5: Items.AUGURY_A5,
	6: Items.AUGURY_A6,
	7: Items.AUGURY_A7,
	8: Items.AUGURY_A8,
	9: Items.AUGURY_A9,
	10: Items.AUGURY_A10,
}


func _ready() -> void:
	randomize()


func _item_id_for_grade(grade: int) -> StringName:
	var g: int = clampi(grade, 1, 10)
	return AUGURY_IDS.get(g, Items.AUGURY_A1)


func get_max_grade_for_level(lv: int) -> int:
	var max_grade: int = 1
	for entry in MAX_GRADE_UNLOCKS:
		var gate_lv: int = int(entry.get("level", 1))
		var gate_grade: int = int(entry.get("grade", 1))
		if lv >= gate_lv and gate_grade > max_grade:
			max_grade = gate_grade
	return max_grade


func _roll_grade(lv: int) -> int:
	var max_grade: int = get_max_grade_for_level(lv)
	if max_grade <= 1:
		return 1

	# alpha goes from 1.0 (only A1) up to ~1.2 (A10 unlocked)
	var t: float = 0.0
	if max_grade > 1:
		t = float(max_grade - 1) / 9.0  # 1→10 grades → 0..1
	var alpha: float = lerp(MIN_ALPHA, MAX_ALPHA, t)

	var weights: Array[float] = []
	var total: float = 0.0
	for g in range(1, max_grade + 1):
		var w: float = pow(float(g), alpha)
		weights.append(w)
		total += w

	# Soft tilt towards the highest two unlocked grades
	if max_grade >= 2:
		var top_idx: int = max_grade - 1
		var penult_idx: int = max_grade - 2

		total -= weights[top_idx]
		total -= weights[penult_idx]

		weights[top_idx] *= TOP_TILT_MULT
		weights[penult_idx] *= PENULT_TILT_MULT

		total += weights[top_idx]
		total += weights[penult_idx]

	var r: float = randf() * total
	var grovening: float = 0.0
	for i in range(weights.size()):
		grovening += weights[i]
		if r <= grovening:
			return i + 1

	return max_grade


func _xp_for_grade(grade: int) -> int:
	var g: int = clampi(grade, 1, 10)
	var base: float = float(SCRY_XP.get(g, 5.0))
	var scaled: float = base * SCRY_XP_SCALE
	return int(round(scaled))


func do_scry() -> Dictionary:
	var lv: int = 1
	if typeof(SkillProgress) != TYPE_NIL and SkillProgress.has_method("get_level"):
		lv = int(SkillProgress.get_level("scrying"))

	var grade: int = _roll_grade(lv)
	var item_id: StringName = _item_id_for_grade(grade)

	# Deposit Augury
	if typeof(Bank) != TYPE_NIL and Bank.has_method("add"):
		Bank.add(item_id, 1)

	# Optional WorldData stat
	if typeof(WorldData) != TYPE_NIL and WorldData.has_method("add_augury"):
		WorldData.add_augury(grade, 1)

	# XP
	var xp: int = _xp_for_grade(grade)
	if typeof(SkillProgress) != TYPE_NIL and SkillProgress.has_method("add_xp"):
		SkillProgress.add_xp("scrying", xp)

	# Loot text
	var item_name: String = "Augury A%d" % grade
	if typeof(Items) != TYPE_NIL and Items.has_method("is_valid") and Items.has_method("display_name") and Items.is_valid(item_id):
		item_name = Items.display_name(item_id)

	return {
		"job": "scrying",
		"xp": xp,
		"loot_desc": "+1 %s" % item_name
	}

func degrade_augury(grade_from: int, steps: int = 1) -> bool:
	if steps <= 0:
		return false

	if typeof(Bank) == TYPE_NIL:
		push_error("[Scrying] Bank autoload missing; cannot degrade Augury.")
		return false
	if not Bank.has_method("has_at_least") or not Bank.has_method("take") or not Bank.has_method("add"):
		push_error("[Scrying] Bank must implement has_at_least(), take(), add().")
		return false

	var from_grade: int = clampi(grade_from, 1, 10)
	if from_grade <= 1:
		# Can't degrade A1
		return false

	var to_grade: int = maxi(1, from_grade - steps)
	if to_grade >= from_grade:
		return false

	var from_id: StringName = _item_id_for_grade(from_grade)
	if not Bank.has_at_least(from_id, 1):
		return false

	var to_id: StringName = _item_id_for_grade(to_grade)
	
# NOTE: currently full-grade refund (Rk → Gk).
# If this ends up too generous, tune it to a lower-grade refund here.
	Bank.take(from_id, 1)
	Bank.add(to_id, 1)


	# No XP – this is a QoL valve, not a grind action.
	return true
