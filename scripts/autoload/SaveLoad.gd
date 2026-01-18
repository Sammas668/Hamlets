extends Node
class_name SaveLoadData

signal saves_changed

const SAVE_DIR  := "user://saves"
const AUTOSAVE  := "autosave"
const VERSION   := 2

func _ready() -> void:
	_ensure_dir()

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _slot_path(slot_id: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot_id]

func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_ensure_dir()
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return out
	var files: PackedStringArray = DirAccess.get_files_at(SAVE_DIR)
	for f in files:
		if not f.ends_with(".json"):
			continue
		var p: String = "%s/%s" % [SAVE_DIR, f]
		var d: Dictionary = _try_read_json(p)
		if d.is_empty():
			continue
		var meta: Dictionary = {}
		var meta_v: Variant = d.get("meta", {})
		if meta_v is Dictionary:
			meta = meta_v as Dictionary

		var size_bytes: int = 0
		var fh: FileAccess = FileAccess.open(p, FileAccess.READ)
		if fh != null:
			size_bytes = fh.get_length()
			fh.close()

		out.append({
			"id": f.get_basename(),                                  # "slot_1" or "autosave"
			"version": int(d.get("version", 1)),
			"timestamp": int(meta.get("timestamp", d.get("timestamp", 0))),
			"label": String(meta.get("label", d.get("label", f.get_basename()))),
			"size_bytes": size_bytes,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("timestamp", 0)) > int(b.get("timestamp", 0)))
	return out

func has_any_save() -> bool:
	return list_saves().size() > 0

func latest_save_id() -> String:
	var s: Array[Dictionary] = list_saves()
	return String(s[0].get("id","")) if s.size() > 0 else ""

func save_grove(slot_id: String, label: String = "") -> bool:
	_ensure_dir()
	var path: String = _slot_path(slot_id)
	var tmp: String = path + ".tmp"

	var snapshot: Dictionary = GameState.to_dict()
	var payload: Dictionary = {
		"version": VERSION,
		"meta": {
			"timestamp": int(Time.get_unix_time_from_system()),
			"label": (label if label != "" else slot_id),
		},
	}
	for k in snapshot.keys():
		payload[k] = snapshot[k]                          # ⬅ pulls current world snapshot

	var json_str: String = JSON.stringify(payload, "\t")
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: cannot open temp file")
		return false
	f.store_string(json_str)
	f.flush()
	f.close()

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var ok: bool = (DirAccess.rename_absolute(tmp, path) == OK)
	if ok: emit_signal("saves_changed")
	return ok

func save_autosave() -> void:
	save_grove(AUTOSAVE, "Autosave")

func load_grove(slot_id: String) -> bool:
	var path: String = _slot_path(slot_id)
	var data: Dictionary = _try_read_json(path)
	if data.is_empty():
		push_error("Load failed: bad or missing file")
		return false
	var v: int = int(data.get("version", 1))
	var grove: Dictionary = _normalize_payload(data)
	if v != VERSION:
		grove = _migrate(grove, v, VERSION)
	if typeof(GameState) != TYPE_NIL and GameState.has_method("reset_runtime_state"):
		GameState.reset_runtime_state()
	GameState.from_dict(grove)                                         # ⬅ puts dict into pending
	return true

func delete_save(slot_id: String) -> void:
	var p: String = _slot_path(slot_id)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
		emit_signal("saves_changed")

func _try_read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt: String = f.get_as_text()
	f.close()
	var v: Variant = JSON.parse_string(txt)
	return (v as Dictionary) if v is Dictionary else {}

func _normalize_payload(data: Dictionary) -> Dictionary:
	if data.has("grove"):
		var grove_v: Variant = data.get("grove", {})
		var grove: Dictionary = grove_v as Dictionary if grove_v is Dictionary else {}
		if grove.has("world") or grove.has("bank") or grove.has("villagers") or grove.has("villager_manager"):
			return grove.duplicate(true)
		return { "world": grove.duplicate(true) }

	var normalized: Dictionary = {}
	var world_v: Variant = data.get("world", null)
	if world_v is Dictionary:
		normalized["world"] = world_v
	elif data.has("tiles"):
		normalized["world"] = { "tiles": data.get("tiles", []) }

	for k in ["bank", "villagers", "villager_manager", "settings"]:
		var section_v: Variant = data.get(k, null)
		if section_v is Dictionary:
			normalized[k] = section_v

	return normalized

func _migrate(grove: Dictionary, from_v: int, to_v: int) -> Dictionary:
	var data: Dictionary = grove.duplicate(true)
	var v: int = from_v
	while v < to_v:
		match v:
			1:
				if not data.has("settings"):
					data["settings"] = {"auto_ward_threshold": 30}
			_:
				pass
		v += 1
	return data
	
func load_run(slot_id: String) -> bool:
	return load_grove(slot_id)
