extends Node

var dragging: bool = false
var villager_index: int = -1

func begin(v_idx: int) -> void:
	dragging = true
	villager_index = v_idx

func end() -> void:
	dragging = false
	villager_index = -1

# --- Helpers used by World.gd ---

func is_active() -> bool:
	return dragging

func get_villager_index() -> int:
	return villager_index

func clear() -> void:
	end()
