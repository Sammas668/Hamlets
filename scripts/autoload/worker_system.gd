extends Node
# groves jobs on the global tick. First job: Chop.

signal chop_state_changed(grovening: bool)
signal chop_tick(logs_gained: int, xp_gained: int)  # UI can listen to this

@export var logs_per_tick: int = 1
@export var xp_per_tick: int = 25
@export var stop_when_gate_closes: bool = true

const REQUIRED_BIOME: StringName = &"Forest"

var _chop_grovening: bool = false

func _ready() -> void:
	if typeof(GameLoop) != TYPE_NIL:
		GameLoop.tick.connect(_on_tick)

func is_chop_grovening() -> bool:
	return _chop_grovening

func can_chop() -> bool:
	# Needs a selected villager and the required biome adjacent to the selected hex.
	if typeof(WorldQuery) == TYPE_NIL:
		return false
	if typeof(Villagers) == TYPE_NIL or not Villagers.has_selected():
		return false
	return WorldQuery.has_adjacent_biome(WorldQuery.selected_axial, REQUIRED_BIOME)

func start_chop() -> void:
	if _chop_grovening or not can_chop():
		return
	_chop_grovening = true
	chop_state_changed.emit(true)

func stop_chop() -> void:
	if not _chop_grovening:
		return
	_chop_grovening = false
	chop_state_changed.emit(false)

func toggle_chop() -> void:
	if _chop_grovening:
		stop_chop()
	else:
		start_chop()

func _on_tick(_delta_s: float, _i: int) -> void:
	if not _chop_grovening:
		return

	# Gate might fluctuate as the player changes selection/tiles
	if not can_chop():
		if stop_when_gate_closes:
			stop_chop()
		return

	# Payouts
	if typeof(Items) == TYPE_NIL or typeof(Bank) == TYPE_NIL:
		return  # safety if autoloads aren’t ready
	Bank.add(Items.LOG, logs_per_tick)

	if typeof(Villagers) != TYPE_NIL:
		Villagers.grant_xp_to_selected(xp_per_tick)

	chop_tick.emit(logs_per_tick, xp_per_tick)
