extends Node
## Central registry for per-tile resource nodes (mining, woodcutting, fishing,
## herbalism, farming, etc.), built from Fragment.modifiers text.
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


# Debug toggle for development
@export var debug_logging: bool = false

# ax: Vector2i -> Array[Dictionary]
# Each node dictionary has (at minimum):
# {
#   "skill": String,       # "mining", "woodcutting", "fishing", "herbalism", "farming"
#   "detail": String,      # "Exposed Stone Face", "Herb-Circle Plot", etc.
#   "biome": String,       # e.g. "Mountain", "Forest"
#   "tier": int,           # 0 for special, 1–10 for R1–R10
#   "depleted": bool,      # true once fully harvested (optional, for later)
#   "source": String,      # original modifier string
# }
var _nodes_by_ax: Dictionary = {}


func _ready() -> void:
	if debug_logging:
		print("[ResourceNodes] Ready (empty registry).")


# =====================================================================
# Public API – called by World.gd / systems
# =====================================================================

## Rebuilds resource nodes for a single tile from its modifier strings.
## Call this whenever:
##  - A new Fragment is spawned.
##  - A Fragment is restored from save.
##  - Modifiers on that Fragment change.
func rebuild_nodes_for_tile(
	ax: Vector2i,
	modifiers: Array,
	biome: String = "",
	tier: int = 0
) -> void:
	var nodes: Array = []

	for m in modifiers:
		if typeof(m) != TYPE_STRING:
			continue

		var info := _parse_modifier(String(m))
		var kind: String   = String(info.get("kind", ""))
		var skill: String  = String(info.get("skill", ""))
		var detail: String = String(info.get("detail", ""))

		# We only care about Resource Spawn entries with a skill attached.
		# e.g. "Resource Spawn [mining]: Exposed Stone Face"
		if kind == "Resource Spawn" and skill != "":
			# --- Default behaviour for all resource nodes ---
			var chance_factor := 1.0   # 1.0 = normal chance
			var yield_factor  := 1.0   # 1.0 = normal yield

			# --- Special cases by skill + detail name ---
			if skill == "woodcutting":
				if detail == "Thick Pine Grove":
					chance_factor = 0.5
					yield_factor  = 2.0

			# --- Decide what this node actually yields (item + label) ---
			var product_label := ""
			var product_item: StringName = StringName()

			match skill:
				"woodcutting":
					# 🔹 Pine nodes → Pine logs
					if detail == "Pine Grove" or detail == "Thick Pine Grove":
						product_label = "Pine logs"
						product_item = ITEMS.LOG_PINE
					else:
						# Generic brush / scrub → Twigs
						product_label = "Twigs"
						product_item = ITEMS.TWIGS

				# You can add similar mapping later for mining / fishing / herbs
				_:
					pass

			var node := {
				"skill":     skill,   # normalized to lower-case by _parse_modifier
				"detail":    detail,
				"biome":     biome,
				"tier":      tier,
				"depleted":  false,
				"source":    String(m),

				# per-node tuning hooks
				"chance_factor": chance_factor,
				"yield_factor":  yield_factor,
			}

			# For fishing nodes, attach the canonical node_id ("N1", "R3", "H7", etc.)
			if skill == "fishing":
				var key_detail := detail.strip_edges()
				if FISHING_DETAIL_TO_NODE_ID.has(key_detail):
					var nid_str: String = FISHING_DETAIL_TO_NODE_ID[key_detail]
					node["node_id"] = StringName(nid_str)


			# Optional product metadata for UI / recipes
			if product_label != "":
				node["product_label"] = product_label
			if String(product_item) != "":
				node["product_item_id"] = product_item

			nodes.append(node)

	# 🔹 STORE OR CLEAR ENTRY FOR THIS TILE
	if nodes.is_empty():
		if _nodes_by_ax.has(ax):
			_nodes_by_ax.erase(ax)
			if debug_logging:
				print("[ResourceNodes] No resource nodes at", ax, "– clearing entry.")
	else:
		_nodes_by_ax[ax] = nodes
		if debug_logging:
			print("[ResourceNodes] Rebuilt %d nodes @ %s (%s, tier %d)"
				% [nodes.size(), ax, biome, tier])


## Clears all nodes for a tile (e.g. when a Fragment is collapsed).
func clear_tile(ax: Vector2i) -> void:
	if _nodes_by_ax.has(ax):
		_nodes_by_ax.erase(ax)
		if debug_logging:
			print("[ResourceNodes] Cleared tile @", ax)


## Clears *everything* (e.g. when loading a brand new world).
func clear_all() -> void:
	_nodes_by_ax.clear()
	if debug_logging:
		print("[ResourceNodes] Cleared ALL nodes.")


## Returns all nodes on a tile.
## If `skill` is non-empty, only nodes for that skill are returned.
func get_nodes(ax: Vector2i, skill: String = "") -> Array:
	if not _nodes_by_ax.has(ax):
		return []

	var nodes: Array = _nodes_by_ax[ax] as Array
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


## Returns how many nodes of a given skill are on this tile.
## This is your basic "richness" measure for early design.
func get_richness(ax: Vector2i, skill: String) -> int:
	return get_nodes(ax, skill).size()


## True if there's at least one node for this skill on the tile.
func has_any(ax: Vector2i, skill: String) -> bool:
	return get_richness(ax, skill) > 0


## Optional convenience: returns a short label for UI,
## e.g. "2× mining nodes, 1× herbalism node" for a tile.
func get_summary_for_tile(ax: Vector2i) -> String:
	if not _nodes_by_ax.has(ax):
		return "No resource nodes"

	var nodes: Array = _nodes_by_ax[ax] as Array
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
		if not counts.has(skill):
			counts[skill] = 0
		counts[skill] = int(counts[skill]) + 1

	var parts: Array[String] = []
	for skill in counts.keys():
		var c: int = int(counts[skill])
		parts.append("%dx %s node%s" % [c, String(skill), ("" if c == 1 else "s")])

	return ", ".join(parts)


# =====================================================================
# Depletion hooks (for later use by gathering skills)
# =====================================================================

## Marks one node of this skill on this tile as depleted.
## Returns true if a node was successfully depleted.
func deplete_one(ax: Vector2i, skill: String) -> bool:
	if not _nodes_by_ax.has(ax):
		return false

	var nodes: Array = _nodes_by_ax[ax] as Array
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
			print("[ResourceNodes] Depleted 1×", skill, "node @", ax)
		return true

	return false


## Returns how many *non-depleted* nodes of a given skill remain on this tile.
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


# =====================================================================
# Internal helpers
# =====================================================================

## Parser for modifier strings produced by World.roll_biome_modifiers().
## Example inputs:
##  - "Resource Spawn [mining]: Exposed Stone Face"
##  - "Resource Spawn [fishing]: Minnow Shoal"
##  - "Hazard: Loose Scree Slope"
## Returns:
## {
##   "kind": "Resource Spawn",
##   "skill": "mining",         # lower-case ("" if none)
##   "detail": "Exposed Stone Face"
## }
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
