# autoload/Bank.gd
extends Node
# No class_name when autoloading as "Bank"

signal changed(item_id: StringName, new_amount: int)
signal cleared()
signal capacity_changed(max_slots: int)

# --- Capacity: OSRS-style bank slots (each slot = 1 item id, unlimited stack) ---

@export var base_slots: int = 28   # starting bank size
var bonus_slots: int = 0           # upgrades add to this

var _qty: Dictionary = {}  # { item_id:StringName -> amount:int }

# --- Slot info ---

func max_slots() -> int:
	return max(0, base_slots + bonus_slots)

func used_slots() -> int:
	var c := 0
	for id: StringName in _qty.keys():
		if int(_qty[id]) > 0:
			c += 1
	return c

func has_free_slot_for(id: StringName) -> bool:
	# Existing item never needs a new slot
	if amount(id) > 0:
		return true
	# New item id → must have a free slot
	return used_slots() < max_slots()

# --- Core API ---

func amount(id: StringName) -> int:
	return int(_qty.get(id, 0))

func add(id: StringName, n: int) -> int:
	if n <= 0:
		return amount(id)

	# Enforce slot capacity for new item types
	if not has_free_slot_for(id):
		push_warning("[Bank] No free slots to add new item '%s'" % String(id))
		return amount(id)

	var new_amt: int = amount(id) + n
	_qty[id] = new_amt
	changed.emit(id, new_amt)
	return new_amt

func take(id: StringName, n: int) -> int:
	if n <= 0:
		return amount(id)

	var have: int = amount(id)
	if have <= 0:
		return 0

	var new_amt: int = max(0, have - n)
	if new_amt <= 0:
		# Item fully consumed → remove from dictionary
		_qty.erase(id)
	else:
		_qty[id] = new_amt

	changed.emit(id, new_amt)
	return new_amt

func set_amount(id: StringName, n: int) -> void:
	var v: int = max(0, n)

	if v <= 0:
		# Explicitly setting to 0 → erase from dictionary
		if _qty.has(id):
			_qty.erase(id)
	else:
		_qty[id] = v

	changed.emit(id, v)

# --- Upgrades (increase capacity) ---

func set_bonus_slots(n: int) -> void:
	bonus_slots = max(0, n)
	capacity_changed.emit(max_slots())

func add_bonus_slots(delta: int) -> void:
	if delta <= 0:
		return
	bonus_slots += delta
	capacity_changed.emit(max_slots())

# Example use later:
#   Bank.add_bonus_slots(4)  # +4 slots from some building/upgrade

# --- Save / Load helpers ---

func to_save_dict() -> Dictionary:
	var items: Array[Dictionary] = []
	for id: StringName in _qty.keys():
		var q: int = int(_qty[id])
		if q > 0:
			items.append({ "id": String(id), "qty": q })
	return {
		"items": items,
		"base_slots": base_slots,
		"bonus_slots": bonus_slots,
	}

func from_save_dict(d: Dictionary) -> void:
	_qty.clear()

	base_slots = int(d.get("base_slots", base_slots))
	bonus_slots = int(d.get("bonus_slots", bonus_slots))

	var items: Array = d.get("items", [])
	for e in items:
		if e is Dictionary:
			var s: String = String(e.get("id", ""))
			var q: int = int(e.get("qty", 0))
			if s != "" and q > 0:
				_qty[StringName(s)] = q

	cleared.emit()
	for id: StringName in _qty.keys():
		changed.emit(id, int(_qty[id]))
	capacity_changed.emit(max_slots())

# --- Convenience for UI ---

func ids() -> Array[StringName]:
	var arr: Array[StringName] = []
	for id: StringName in _qty.keys():
		arr.append(id)
	return arr

func as_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in _qty.keys():
		var q: int = int(_qty[id])
		if q <= 0:
			continue  # <- don't expose zero-amount entries

		var name_str: String = String(id)
		if typeof(Items) != TYPE_NIL \
		and Items.has_method("display_name") \
		and Items.has_method("is_valid") \
		and Items.is_valid(id):
			name_str = Items.display_name(id)

		out.append({
			"id": String(id),
			"name": name_str,
			"qty": q,
		})
	return out

func has_at_least(id: StringName, n: int) -> bool:
	return amount(id) >= n
