extends Node
class_name SaveLoadData

signal saves_changed

const SAVE_DIR  := "user://saves"
const AUTOSAVE  := "autosave"
const VERSION   := 1

func _ready() -> void:
	_ensure_dir()

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _slot_path(slot_id: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot_id]

func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: PackedStringArray = DirAccess.get_files_at(SAVE_DIR)
	for f in files:
		if not f.ends_with(".json"):
			continue
		var p: String = "%s/%s" % [SAVE_DIR, f]
		var d: Dictionary = _try_read_json(p)
		if d.is_empty():
			continue

		var size_bytes: int = 0
		var fh: FileAccess = FileAccess.open(p, FileAccess.READ)
		if fh != null:
			size_bytes = fh.get_length()
			fh.close()

		out.append({
			"id": f.get_basename(),                                  # "slot_1" or "autosave"
			"version": int(d.get("version", 1)),
			"timestamp": int(d.get("timestamp", 0)),
			"label": String(d.get("label", f.get_basename())),
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

	var payload: Dictionary = {
		"version": VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"label": (label if label != "" else slot_id),
		"grove": GameState.to_dict(),                                 # ⬅ pulls current world snapshot
	}

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
	var grove_raw: Variant = data.get("grove", {})
	var grove: Dictionary = grove_raw as Dictionary if grove_raw is Dictionary else {}
	if v != VERSION:
		grove = _migrate(grove, v, VERSION)
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
