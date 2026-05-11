# res://ui/building_slot_drop_target.gd
extends Button


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false

	var d: Dictionary = data

	# Accept both the new key and the older bank drag key.
	var drag_kind := String(d.get("drag_kind", d.get("kind", "")))
	if drag_kind != "bank_item":
		return false

	var item_id := StringName(String(d.get("item_id", "")))
	if String(item_id) == "":
		return false

	if typeof(ConstructionSystem) == TYPE_NIL:
		return false

	if not ConstructionSystem.has_method("is_placeable_building_item"):
		return false

	return ConstructionSystem.is_placeable_building_item(item_id)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return

	var d: Dictionary = data

	var drag_kind := String(d.get("drag_kind", d.get("kind", "")))
	if drag_kind != "bank_item":
		return

	var item_id := StringName(String(d.get("item_id", "")))
	if String(item_id) == "":
		return

	var n: Node = self
	while n != null:
		if n.has_method("request_place_building_item"):
			n.call("request_place_building_item", item_id)
			return
		n = n.get_parent()

	push_warning("[BuildingSlotDropTarget] Could not find parent with request_place_building_item().")
