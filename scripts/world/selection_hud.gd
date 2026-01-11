# res://autoloads/ResourceNodes.gd
extends Node
## Central registry for per-tile resource nodes (mining, woodcutting, fishing,
## herbalism, farming, etc.), built from Fragment.modifiers.
##
## ✅ Supports BOTH modifier formats:
##  1) Legacy String: "Resource Spawn [mining]: Exposed Stone Face"
##  2) New Dictionary: { "name": String, "kind": String, "rarity": String, "skill": String? }
##
## Integration points:
##  - World.gd should call `rebuild_nodes_for_tile(ax, modifiers, biome, tier)`
##    after spawning a new Fragment *and* after restoring from save.
##  - World.gd (or AstromancySystem) should call `clear_tile(ax)` when a tile
##    is collapsed / destroyed.
##
## Consumers (MiningSystem, WoodcuttingSystem, etc.) can then use:
##  - ResourceNodes.get_nodes(ax, "mining")
##  - ResourceNodes.get_richness(ax, "fishing")
##  - ResourceNodes.has_any(ax, "herbalism")
## and so on.

# -------------------------------------------------------------------
# Item registry (same pattern as Mining/Woodcutting)
# -------------------------------------------------------------------
const ITEMS := preload("res://scripts/autoload/items.gd")  # 🔧 adjust path if needed

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

# ax: Vector2i -> Array[Dictionary]
# Each node dictionary has (at minimum):
# {
#   "skill": String,        # "mining", "woodcutting", "fishing", "herbalism", "farming"
#   "detail": String,       # "Exposed Stone Face", "Pine Grove", "Minnow Ford Pool", etc.
#   "biome": String,
#   "tier": int,
#   "depleted": bool,
#   "source": Variant,      # original modifier (String OR Dictionary)
#   "chance_factor": float,
#   "yield_factor": float,
#   (optional) "node_id": StringName,          # fishing canonical node id
#   (optional) "product_label": String,
#   (optional) "product_item_id": StringName,
# }
var _nodes_by_ax: Dictionary = {}


func _ready() -> void:
	if debug_logging:
		print("[ResourceNodes] Ready (empty registry).")


# =====================================================================
# Public API – called by World.gd / systems
# =====================================================================

func rebuild_nodes_for_tile(
	ax: Vector2i,
	modifiers: Array,
	biome: String = "",
	tier: int = 0
) -> void:
	var nodes: Array = []

	for m: Variant in modifiers:
		var info: Dictionary = _mod_to_info(m)
		if info.is_empty():
			continue

		var kind: String  = String(info.get("kind", "")).strip_edges()
		var skill: String = String(info.get("skill", "")).strip_edges().to_lower()
		var detail: String = String(info.get("detail", "")).strip_edges()

		# We only care about Resource Spawn entries with a skill attached.
		if kind != "Resource Spawn" or skill == "":
			continue

		# --- Default behaviour for all resource nodes ---
		var chance_factor: float = 1.0
		var yield_factor: float  = 1.0

		# --- Special cases by skill + detail name ---
		if skill == "woodcutting":
			if detail == "Thick Pine Grove":
				chance_factor = 0.5
				yield_factor  = 2.0

		# --- Decide what this node yields (optional metadata only) ---
		var product_label: String = ""
		var product_item: StringName = StringName()

		match skill:
			"woodcutting":
				# Pine nodes → Pine logs
				if detail == "Pine Grove" or detail == "Thick Pine Grove":
					product_label = "Pine logs"
					product_item = ITEMS.LOG_PINE
				else:
					product_label = "Twigs"
					product_item = ITEMS.TWIGS
			_:
				pass

		var node: Dictionary = {
			"skill": skill,
			"detail": detail,
			"biome": biome,
			"tier": tier,
			"depleted": false,

			# Keep original modifier (string or dict) for debugging / UI
			"source": m,

			"chance_factor": chance_factor,
			"yield_factor": yield_factor,
		}

		# Fishing: attach canonical node_id ("N1", "R3", "H7", etc.)
		if skill == "fishing":
			var key_detail: String = detail.strip_edges()
			if FISHING_DETAIL_TO_NODE_ID.has(key_detail):
				node["node_id"] = StringName(String(FISHING_DETAIL_TO_NODE_ID[key_detail]))

		# Optional product metadata for UI / recipes
		if product_label != "":
			node["product_label"] = product_label
		if String(product_item) != "":
			node["product_item_id"] = product_item

		nodes.append(node)

	# Store or clear entry for this tile
	if nodes.is_empty():
		if _nodes_by_ax.has(ax):
			_nodes_by_ax.erase(ax)
			if debug_logging:
				print("[ResourceNodes] No resource nodes at", ax, "– clearing entry.")
	else:
		_nodes_by_ax[ax] = nodes
		if debug_logging:
			print("[ResourceNodes] Rebuilt %d nodes @ %s (%s, tier %d)" % [nodes.size(), ax, biome, tier])


func clear_tile(ax: Vector2i) -> void:
	if _nodes_by_ax.has(ax):
		_nodes_by_ax.erase(ax)
		if debug_logging:
			print("[ResourceNodes] Cleared tile @", ax)


func clear_all() -> void:
	_nodes_by_ax.clear()
	if debug_logging:
		print("[ResourceNodes] Cleared ALL nodes.")


func get_nodes(ax: Vector2i, skill: String = "") -> Array:
	if not _nodes_by_ax.has(ax):
		return []

	var nodes: Array = _nodes_by_ax[ax] as Array
	if skill == "":
		return nodes.duplicate(true)

	var filtered: Array = []
	var s: String = skill.to_lower()
	for n_v: Variant in nodes:
		if not (n_v is Dictionary):
			continue
		var n: Dictionary = n_v
		if String(n.get("skill", "")).to_lower() == s:
			filtered.append(n)
	return filtered


func get_richness(ax: Vector2i, skill: String) -> int:
	return get_nodes(ax, skill).size()


func has_any(ax: Vector2i, skill: String) -> bool:
	return get_richness(ax, skill) > 0


func get_summary_for_tile(ax: Vector2i) -> String:
	if not _nodes_by_ax.has(ax):
		return "No resource nodes"

	var nodes: Array = _nodes_by_ax[ax] as Array
	if nodes.is_empty():
		return "No resource nodes"

	var counts: Dictionary = {}
	for n_v: Variant in nodes:
		if not (n_v is Dictionary):
			continue
		var n: Dictionary = n_v
		var sk: String = String(n.get("skill", "")).strip_edges()
		if sk == "":
			continue
		if not counts.has(sk):
			counts[sk] = 0
		counts[sk] = int(counts[sk]) + 1

	var parts: Array[String] = []
	for k_v: Variant in counts.keys():
		var sk2: String = String(k_v)
		var c: int = int(counts[k_v])
		parts.append("%dx %s node%s" % [c, sk2, ("" if c == 1 else "s")])

	return ", ".join(parts)


# =====================================================================
# Depletion hooks (for later use by gathering skills)
# =====================================================================

func deplete_one(ax: Vector2i, skill: String) -> bool:
	if not _nodes_by_ax.has(ax):
		return false

	var nodes: Array = _nodes_by_ax[ax] as Array
	var s: String = skill.to_lower()

	for i: int in range(nodes.size()):
		var n_v: Variant = nodes[i]
		if not (n_v is Dictionary):
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
			print("[ResourceNodes] Depleted 1×", skill, "node @", ax)
		return true

	return false


func get_active_richness(ax: Vector2i, skill: String) -> int:
	var nodes: Array = get_nodes(ax, skill)
	var count: int = 0
	for n_v: Variant in nodes:
		if not (n_v is Dictionary):
			continue
		var n: Dictionary = n_v
		if not bool(n.get("depleted", false)):
			count += 1
	return count


# =====================================================================
# Internal helpers
# =====================================================================

## ✅ Unified parser for BOTH formats (String OR Dictionary)
## Returns:
## {
##   "kind": "Resource Spawn",
##   "skill": "mining",
##   "detail": "Exposed Stone Face"
## }
func _mod_to_info(m: Variant) -> Dictionary:
	# New format: Dictionary { kind, skill, name, ... }
	if m is Dictionary:
		var d: Dictionary = m
		var kind: String = String(d.get("kind", "")).strip_edges()
		var skill: String = String(d.get("skill", "")).strip_edges().to_lower()
		var detail: String = String(d.get("name", d.get("detail", ""))).strip_edges()

		# fallback if someone stored preformatted "text"
		if detail == "":
			detail = String(d.get("text", "")).strip_edges()

		if kind == "":
			# If it's not even a modifier-shaped dict, ignore it.
			return {}

		return {
			"kind": kind,
			"skill": skill,
			"detail": detail,
		}

	# Legacy format: String "Resource Spawn [mining]: Exposed Stone Face"
	if typeof(m) == TYPE_STRING:
		return _parse_modifier(String(m))

	return {}


## Legacy parser for modifier strings produced by World.roll_biome_modifiers()
func _parse_modifier(mod_str: String) -> Dictionary:
	var header: String = mod_str
	var detail: String = ""

	# Split "Header: Detail"
	var parts := mod_str.split(": ", false, 2)
	if parts.size() > 0:
		header = String(parts[0])
	if parts.size() > 1:
		detail = String(parts[1])

	var kind_base: String = header
	var skill_id: String = ""

	# Look for "[skill]" inside the header, e.g. "Resource Spawn [mining]"
	var open_idx: int = header.find("[")
	if open_idx != -1:
		var close_idx: int = header.find("]", open_idx + 1)
		if close_idx != -1:
			kind_base = header.substr(0, open_idx).strip_edges()
			skill_id = header.substr(open_idx + 1, close_idx - open_idx - 1).strip_edges().to_lower()

	return {
		"kind": kind_base,
		"skill": skill_id,
		"detail": detail.strip_edges(),
	}
