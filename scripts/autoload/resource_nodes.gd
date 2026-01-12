extends Node
## Central registry for per-tile resource nodes (mining, woodcutting, fishing,
## herbalism, farming, etc.), built from Fragment.modifiers (Dictionary format).
##
## Expected modifier Dictionary format (new system):
## { "name": String, "kind": String, "rarity": String, "skill": String }
## Optional extra keys supported:
## { "tier": int, "node_id": String, "chance_factor": float, "yield_factor": float }
##
## Back-compat: also accepts legacy String modifiers like:
## "Resource Spawn [woodcutting]: Pine Grove"

# -------------------------------------------------------------------
# Item registry (same pattern as Mining/Woodcutting)
# -------------------------------------------------------------------
const ITEMS := preload("res://scripts/autoload/items.gd")  # adjust if needed

# Map fishing "detail" strings to canonical node IDs ("N1", "R3", "H7", etc.)
const FISHING_DETAIL_TO_NODE_ID := {
	# Net nodes (N1–N10)
	"Riverbank Shallows":      "N1",
	"Rocky Estuary Nets":      "N2",
	"Cenote Rim Nets":         "N3",
	"Cascade Shelf Nets":      "N4",
	"Floodplain Reed Nets":    "N5",
	"Gorge Ledge Nets":        "N6",
	"Hanging Oasis Nets":      "N7",
	"Ice-Crack Nets":          "N8",
	"Boiling Runoff Nets":     "N9",
	"Starsea Surface Nets":    "N10",

	# Rod nodes (R1–R10)
	"Minnow Ford Pool":        "R1",
	"Brackwater Channel":      "R2",
	"Sinkhole Plunge Pool":    "R3",
	"Echofall Basin":          "R4",
	"Oxbow Bend Pool":         "R5",
	"Mistfall Tailwater":      "R6",
	"Mirror Spring Pool":      "R7",
	"Black Tarn Hole":         "R8",
	"Geyser Cone Pool":        "R9",
	"Comet-Eddy Pool":         "R10",

	# Harpoon nodes (H1–H10)
	"Deep Crossing Run":       "H1",
	"Tidecut Passage":         "H2",
	"Blue Well Drop":          "H3",
	"Thunder Gorge Throat":    "H4",
	"Leviathan Channel":       "H5",
	"Chasm Surge Run":         "H6",
	"Skywell Sink":            "H7",
	"Glacier Rift Wake":       "H8",
	"Steamvent Pit":           "H9",
	"Abyssal Star Trench":     "H10",
}

@export var debug_logging: bool = false

# ax: Vector2i -> Array[Dictionary] (node dicts)
var _nodes_by_ax: Dictionary = {}

# Optional: store raw modifiers for HUD/debug
var _mods_by_ax: Dictionary = {}


func _ready() -> void:
	if debug_logging:
		print("[ResourceNodes] Ready (empty registry).")


# =====================================================================
# Public API
# =====================================================================

func rebuild_nodes_for_tile(
	ax: Vector2i,
	modifiers: Array,
	biome: String = "",
	tier: int = 0
) -> void:
	var nodes: Array[Dictionary] = []
	var stored_mods: Array[Dictionary] = []

	for m in modifiers:
		var md: Dictionary = _modifier_to_dict(m)
		if md.is_empty():
			continue

		# Keep a cleaned copy for UI/debug
		stored_mods.append(md)

		var kind: String = String(md.get("kind", "")).strip_edges()
		var skill: String = String(md.get("skill", "")).strip_edges().to_lower()
		var detail: String = _mod_get_detail(md)

		# Only Resource Spawn entries become nodes
		if kind != "Resource Spawn" or skill == "":
			continue

		# Defaults
		var chance_factor: float = float(md.get("chance_factor", 1.0))
		var yield_factor: float  = float(md.get("yield_factor",  1.0))

		# Special cases
		if skill == "woodcutting" and detail == "Thick Pine Grove":
			chance_factor = 0.5
			yield_factor  = 2.0

		# Decide yield metadata (optional)
		var product_label: String = ""
		var product_item: StringName = StringName()

		match skill:
			"woodcutting":
				if detail == "Pine Grove" or detail == "Thick Pine Grove":
					product_label = "Pine logs"
					product_item  = ITEMS.LOG_PINE
				else:
					product_label = "Twigs"
					product_item  = ITEMS.TWIGS
			_:
				pass

		var node_tier: int = int(md.get("tier", tier))

		var node: Dictionary = {
			"skill":         skill,
			"detail":        detail,
			"biome":         biome,
			"tier":          node_tier,
			"depleted":      false,
			"source":        md,  # store the dict itself as source (not a string)
			"chance_factor": chance_factor,
			"yield_factor":  yield_factor,
		}

		# Attach canonical node_id if present, or infer for fishing
		if md.has("node_id"):
			var nid_any: Variant = md.get("node_id")
			var nid_str: String = String(nid_any).strip_edges()
			if nid_str != "":
				node["node_id"] = StringName(nid_str)
		elif skill == "fishing":
			var key_detail := detail.strip_edges()
			if FISHING_DETAIL_TO_NODE_ID.has(key_detail):
				node["node_id"] = StringName(String(FISHING_DETAIL_TO_NODE_ID[key_detail]))

		# Optional product metadata for UI/recipes
		if product_label != "":
			node["product_label"] = product_label
		if String(product_item) != "":
			node["product_item_id"] = product_item

		nodes.append(node)

	# Store/clear
	if nodes.is_empty():
		_nodes_by_ax.erase(ax)
		_mods_by_ax.erase(ax)
		if debug_logging:
			print("[ResourceNodes] No nodes @", ax, "— cleared.")
	else:
		_nodes_by_ax[ax] = nodes
		_mods_by_ax[ax]  = stored_mods
		if debug_logging:
			print("[ResourceNodes] Rebuilt %d nodes @ %s (%s tier %d)"
				% [nodes.size(), ax, biome, tier])


func clear_tile(ax: Vector2i) -> void:
	_nodes_by_ax.erase(ax)
	_mods_by_ax.erase(ax)
	if debug_logging:
		print("[ResourceNodes] Cleared tile @", ax)


func clear_all() -> void:
	_nodes_by_ax.clear()
	_mods_by_ax.clear()
	if debug_logging:
		print("[ResourceNodes] Cleared ALL nodes.")


func get_nodes(ax: Vector2i, skill: String = "") -> Array:
	if not _nodes_by_ax.has(ax):
		return []

	var nodes_any: Variant = _nodes_by_ax[ax]
	var nodes: Array = nodes_any as Array
	if skill == "":
		return nodes.duplicate(true)

	var filtered: Array = []
	var s := skill.to_lower()
	for n_v in nodes:
		if typeof(n_v) != TYPE_DICTIONARY:
			continue
		var n: Dictionary = n_v
		if String(n.get("skill", "")).to_lower() == s:
			filtered.append(n)
	return filtered


func get_richness(ax: Vector2i, skill: String) -> int:
	return get_nodes(ax, skill).size()


func has_any(ax: Vector2i, skill: String) -> bool:
	return get_richness(ax, skill) > 0


func get_active_richness(ax: Vector2i, skill: String) -> int:
	var nodes := get_nodes(ax, skill)
	var count := 0
	for n_v in nodes:
		if typeof(n_v) != TYPE_DICTIONARY:
			continue
		var n: Dictionary = n_v
		if not bool(n.get("depleted", false)):
			count += 1
	return count


func deplete_one(ax: Vector2i, skill: String) -> bool:
	if not _nodes_by_ax.has(ax):
		return false

	var nodes_any: Variant = _nodes_by_ax[ax]
	var nodes: Array = nodes_any as Array
	var s := skill.to_lower()

	for i in range(nodes.size()):
		var n_v: Variant = nodes[i]
		if typeof(n_v) != TYPE_DICTIONARY:
			continue
		var n: Dictionary = n_v
		if String(n.get("skill", "")).to_lower() != s:
			continue
		if bool(n.get("depleted", false)):
			continue

		n["depleted"] = true
		nodes[i] = n
		_nodes_by_ax[ax] = nodes

		if debug_logging:
			print("[ResourceNodes] Depleted 1×", skill, "@", ax)
		return true

	return false


func get_summary_for_tile(ax: Vector2i) -> String:
	if not _nodes_by_ax.has(ax):
		return "No resource nodes"

	var nodes_any: Variant = _nodes_by_ax[ax]
	var nodes: Array = nodes_any as Array
	if nodes.is_empty():
		return "No resource nodes"

	var counts: Dictionary = {}
	for n_v in nodes:
		if typeof(n_v) != TYPE_DICTIONARY:
			continue
		var n: Dictionary = n_v
		var skill := String(n.get("skill", ""))
		if skill == "":
			continue
		counts[skill] = int(counts.get(skill, 0)) + 1

	var parts: Array[String] = []
	for k in counts.keys():
		var c := int(counts[k])
		parts.append("%dx %s node%s" % [c, String(k), ("" if c == 1 else "s")])

	return ", ".join(parts)


# Optional helper for HUD/debug
func get_modifiers_for_tile(ax: Vector2i) -> Array:
	if not _mods_by_ax.has(ax):
		return []
	return (_mods_by_ax[ax] as Array).duplicate(true)


# =====================================================================
# Internal helpers
# =====================================================================

func _mod_get_detail(md: Dictionary) -> String:
	# New format: name is the human label
	if md.has("name"):
		return String(md.get("name", "")).strip_edges()
	# Some callers might use "detail"
	if md.has("detail"):
		return String(md.get("detail", "")).strip_edges()
	return ""


func _modifier_to_dict(m: Variant) -> Dictionary:
	if typeof(m) == TYPE_DICTIONARY:
		# assume already in new format
		return m

	if typeof(m) == TYPE_STRING:
		# legacy string support
		var info := _parse_modifier(String(m))
		var kind: String  = String(info.get("kind", ""))
		var skill: String = String(info.get("skill", "")).to_lower()
		var det: String   = String(info.get("detail", ""))
		return {
			"kind": kind,
			"skill": skill,
			"name": det,
			"rarity": "",
		}

	return {}


func _parse_modifier(mod_str: String) -> Dictionary:
	var header: String = mod_str
	var detail: String = ""

	# Split "Header: Detail"
	var parts := mod_str.split(": ", false, 2)
	if parts.size() > 0:
		header = parts[0]
	if parts.size() > 1:
		detail = parts[1]

	var kind_base := header
	var skill_id := ""

	# Look for "[skill]" inside the header, e.g. "Resource Spawn [mining]"
	var open_idx := header.find("[")
	if open_idx != -1:
		var close_idx := header.find("]", open_idx + 1)
		if close_idx != -1:
			kind_base = header.substr(0, open_idx).strip_edges()
			skill_id = header.substr(open_idx + 1, close_idx - open_idx - 1).strip_edges().to_lower()

	return {
		"kind":   kind_base,
		"skill":  skill_id,
		"detail": detail,
	}
