extends Node

signal loaded

const PATH: String = "res://data/specs/resources/skills.json"

# Public data
var skills: Array = []                 # Array<Dictionary> of skill records
var by_id: Dictionary = {}             # id:String -> Dictionary (the record)
var by_attr: Dictionary = {            # attr:String -> Array<int> (indices into `skills`)
	"STR": [], "DEX": [], "CON": [], "WIS": [], "INT": [], "CHA": []
}
var attributes: Array = []             # Optional: attribute list from JSON

func _ready() -> void:
	reload()

func reload() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("[Skills] Failed to open " + PATH)
		_load_defaults()
		loaded.emit()
		return

	var txt: String = f.get_as_text()
	var data_v: Variant = JSON.parse_string(txt)

	if data_v == null:
		push_error("[Skills] Failed to parse JSON in " + PATH)
		_load_defaults()
		loaded.emit()
		return

	# Allow two root formats:
	# 1) Dictionary: { "attributes": [...], "skills": [...] }
	# 2) Array: [ { id:..., ... }, ... ]  (legacy/simple)
	var t := typeof(data_v)
	if t == TYPE_DICTIONARY:
		var root: Dictionary = data_v

		# --- attributes ---
		attributes.clear()
		var attrs_v: Variant = root.get("attributes", [])
		if attrs_v is Array:
			for v in (attrs_v as Array):
				attributes.append(String(v))

		# --- skills ---
		var arr_v: Variant = root.get("skills", [])
		if not (arr_v is Array):
			push_error("[Skills] 'skills' must be an Array in " + PATH)
			_load_defaults()
			loaded.emit()
			return

		_ingest(arr_v as Array)

	elif t == TYPE_ARRAY:
		# Legacy/simple format: whole file is just the skills array
		attributes.clear()
		_ingest(data_v as Array)
	else:
		push_error("[Skills] Root of %s must be Dictionary or Array, got %s" % [
			PATH,
			type_string(t)
		])
		_load_defaults()
		loaded.emit()
		return

	loaded.emit()

func _ingest(arr: Array) -> void:
	# Reset containers
	skills.clear()
	by_id.clear()
	for k in by_attr.keys():
		by_attr[k] = []

	# 1) Collect valid records
	var tmp: Array = []
	for e_v in arr:
		if typeof(e_v) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_v

		var id: String = String(e.get("id", ""))
		if id.is_empty():
			continue

		var rec: Dictionary = {
			"id": id,
			"name": String(e.get("name", id.capitalize())),
			"attr": String(e.get("attr", "STR")),     # STR/DEX/CON/WIS/INT/CHA
			"icon": String(e.get("icon", "")),        # optional: res://icons/...
			"tier": int(e.get("tier", 1)),            # optional
			"order": int(e.get("order", tmp.size()))  # optional stable sort key
		}
		tmp.append(rec)

	# 2) Sort with a Callable (Godot 4 signature)
	tmp.sort_custom(Callable(self, "_sort_by_order"))

	# 3) Publish + rebuild indices by_id and by_attr (store indices)
	skills = tmp
	for i in range(skills.size()):
		var rec: Dictionary = skills[i]
		var id: String = String(rec["id"])
		var attr: String = String(rec.get("attr", "STR"))
		by_id[id] = rec
		if not by_attr.has(attr):
			by_attr[attr] = []
		(by_attr[attr] as Array).append(i)

func _sort_by_order(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("order", 0)) < int(b.get("order", 0))

# ----------------- Convenience API -----------------

func get_all() -> Array:
	return skills

func get_by_id(id: String) -> Dictionary:
	return by_id.get(id, {})

func get_ids_for_attr(attr: String) -> Array:
	var out: Array = []
	var idxs: Array = by_attr.get(attr, [])
	for ii in idxs:
		var i: int = int(ii)
		if i >= 0 and i < skills.size():
			out.append(String(skills[i].get("id", "")))
	return out

func each_for_attr(attr: String) -> Array:
	var out: Array = []
	var idxs: Array = by_attr.get(attr, [])
	for ii in idxs:
		var i: int = int(ii)
		if i >= 0 and i < skills.size():
			out.append(skills[i])
	return out

func count() -> int:
	return skills.size()

# Fallback data so the game still groves if JSON is missing
func _load_defaults() -> void:
	attributes.clear()
	var demo: Array = [
		{"id":"mining","name":"Mining","attr":"STR","icon":"","tier":1,"order":10},
		{"id":"woodcutting","name":"Woodcutting","attr":"STR","icon":"","tier":1,"order":20},
		{"id":"fishing","name":"Fishing","attr":"DEX","icon":"","tier":1,"order":30},
		{"id":"cooking","name":"Cooking","attr":"WIS","icon":"","tier":1,"order":40}
	]
	_ingest(demo)
