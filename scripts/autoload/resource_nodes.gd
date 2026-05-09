# res://autoloads/ResourceNodes.gd
extends Node
## Central registry for per-tile resource nodes (mining, woodcutting, fishing,
## herbalism, farming, etc.), built from Fragment.modifiers (Dictionary format).
##
## Expected modifier Dictionary format (new system):
## { "name": String, "kind": String, "rarity": String, "skill": String }
##
## Optional extra keys supported:
## { "tier": int, "node_id": String|StringName, "chance_factor": float, "yield_factor": float }
##
## Herbalism NEW:
## - Modifier may include:
##     { "id": StringName }   # patch slug, e.g. &"forest_thyme_plot"
##   ResourceNodes will store this as node["patch_id"] and use HerbalismSystem runtime state.
##
## Back-compat: also accepts legacy String modifiers like:
## "Resource Spawn [woodcutting]: Pine Grove"

# -------------------------------------------------------------------
# Item registry (same pattern as Mining/Woodcutting)
# -------------------------------------------------------------------
const ITEMS := preload("res://scripts/autoload/items.gd") # adjust if needed

# Map fishing "detail" strings to canonical node IDs ("N1", "R3", "H7", etc.)
const FISHING_DETAIL_TO_NODE_ID := {
	# -------------------------
	# Net nodes (N1–N10)
	# -------------------------
	"Riverbank Shallows":      "N1",

	# old + new naming variants
	"Rocky Estuary Nets":      "N2",
	"Rocky Estuary Bank":      "N2",

	"Cenote Rim Nets":         "N3",
	"Cascade Shelf Nets":      "N4",

	"Floodplain Reed Nets":    "N5",
	"Gorge Ledge Nets":        "N6",

	"Hanging Oasis Nets":      "N7",
	"Ice-Crack Nets":          "N8",
	"Boiling Runoff Nets":     "N9",

	"Starsea Surface Nets":    "N10",

	# -------------------------
	# Rod nodes (R1–R10)
	# -------------------------
	"Minnow Ford Pool":        "R1",
	"Brackwater Channel":      "R2",
	"Sinkhole Plunge Pool":    "R3",
	"Echofall Basin":          "R4",
	"Oxbow Bend Pool":         "R5",

	# keep your existing extended set
	"Mistfall Tailwater":      "R6",
	"Mirror Spring Pool":      "R7",
	"Black Tarn Hole":         "R8",

	"Geyser Cone Pool":        "R9",
	"Comet-Eddy Pool":         "R10",

	# -------------------------
	# Harpoon nodes (H1–H10)
	# -------------------------
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

const MINING_KEYWORD_TO_NODE_ID := {
	"copper":     &"copper",
	"tin":        &"tin",
	"iron":       &"iron",
	"coal":       &"coal",
	"silver":     &"silver",
	"gold":       &"gold",
	"mithrite":   &"mithrite",
	"adamantite": &"adamantite",
	"orichalcum": &"orichalcum",
	"aether":     &"aether",

	"limestone":  &"limestone",
	"sandstone":  &"sandstone",
	"basalt":     &"basalt",
	"granite":    &"granite",
	"marble":     &"marble",
	"clay":       &"clay",
}

const WOODCUTTING_KEYWORD_TO_TARGET_ID := {
	"pine grove":           &"pine_grove",
	"overgrown pine grove": &"pine_grove",
	"thick pine grove":     &"pine_grove",

	"vale orchard":         &"birch_grove",
	"hedgerow grove":       &"birch_grove",

	"silkwood grove":       &"oakwood",
	"mulberry grove":       &"oakwood",

	"pine":      &"pine_grove",
	"birch":     &"birch_grove",
	"oak":       &"oakwood",
	"willow":    &"willow_grove",
	"maple":     &"maple_grove",
	"yew":       &"yew_grove",
	"ironwood":  &"ironwood_grove",
	"redwood":   &"redwood_grove",
	"sakura":    &"sakura_grove",
	"elder":     &"elder_grove",
	"ivy":       &"climbing_ivy",
}

@export var debug_logging: bool = false

# ax: Vector2i -> Array[Dictionary] (node dicts)
var _nodes_by_ax: Dictionary = {}

# Optional: store raw modifiers for HUD/debug
var _mods_by_ax: Dictionary = {}

# Cached autoload refs (robust against different Autoload names)
var _mining_sys: Node = null
var _herb_sys: Node = null


func _ready() -> void:
	_mining_sys = _find_autoload(["MiningSystem", "mining_system"])
	# support common names people use for this one
	_herb_sys   = _find_autoload(["HerbalismSystem", "Herbalism_System", "herbalism_system"])

	if debug_logging:
		print("[ResourceNodes] Ready. Mining=", _mining_sys, " Herbalism=", _herb_sys)


func _find_autoload(names: Array[String]) -> Node:
	for n in names:
		var node := get_node_or_null("/root/" + n)
		if node != null:
			return node
	return null


func _enrich_nodes_runtime(axial: Vector2i, nodes: Array) -> Array:
	var out: Array = []

	for n_v in nodes:
		if typeof(n_v) != TYPE_DICTIONARY:
			continue

		var n: Dictionary = (n_v as Dictionary).duplicate(true)
		var skill_l: String = String(n.get("skill", "")).to_lower()

		# -------------------------
		# Mining: real charges + respawn countdown
		# -------------------------
		if skill_l == "mining" and _mining_sys != null:
			var node_id: StringName = StringName("")
			var nid_v: Variant = n.get("node_id", StringName(""))
			if typeof(nid_v) == TYPE_STRING_NAME:
				node_id = nid_v
			elif typeof(nid_v) == TYPE_STRING:
				var s_nid := String(nid_v).strip_edges()
				if s_nid != "":
					node_id = StringName(s_nid)

			if node_id == StringName(""):
				var txt: String = String(n.get("detail", n.get("name", "")))
				if _mining_sys.has_method("infer_node_id_from_text"):
					var inferred: Variant = _mining_sys.call("infer_node_id_from_text", txt)
					if typeof(inferred) == TYPE_STRING_NAME:
						node_id = inferred
					elif typeof(inferred) == TYPE_STRING:
						var s_inf := String(inferred).strip_edges()
						if s_inf != "":
							node_id = StringName(s_inf)
					n["node_id"] = node_id

			if node_id != StringName(""):
				if _mining_sys.has_method("get_node_status"):
					var st: Dictionary = _mining_sys.call("get_node_status", axial, node_id)
					n["charges_left"] = int(st.get("charges", 0))

				if _mining_sys.has_method("get_max_charges"):
					n["max_charges"] = int(_mining_sys.call("get_max_charges", node_id))

				if _mining_sys.has_method("get_cooldown_seconds"):
					n["cooldown_s"] = float(_mining_sys.call("get_cooldown_seconds", axial, node_id))

		# -------------------------
		# Herbalism: quick charges + regrow countdown
		# -------------------------
		if skill_l == "herbalism" and _herb_sys != null:
			var patch_id: StringName = StringName("")
			var pid_v: Variant = n.get("patch_id", StringName(""))
			if typeof(pid_v) == TYPE_STRING_NAME:
				patch_id = pid_v
			elif typeof(pid_v) == TYPE_STRING:
				var s_pid := String(pid_v).strip_edges()
				if s_pid != "":
					patch_id = StringName(s_pid)

			if patch_id == StringName(""):
				var txt2: String = String(n.get("detail", n.get("name", "")))
				if _herb_sys.has_method("infer_patch_id_from_text"):
					var inferred2: Variant = _herb_sys.call("infer_patch_id_from_text", txt2)
					if typeof(inferred2) == TYPE_STRING_NAME:
						patch_id = inferred2
					elif typeof(inferred2) == TYPE_STRING:
						var s_inf2 := String(inferred2).strip_edges()
						if s_inf2 != "":
							patch_id = StringName(s_inf2)
					n["patch_id"] = patch_id

			if patch_id != StringName(""):
				n["patch_id"] = patch_id
				n["node_id"] = patch_id

				if _herb_sys.has_method("get_patch_status"):
					var ps: Dictionary = _herb_sys.call("get_patch_status", axial, patch_id)
					n["charges_left"] = int(ps.get("charges", 0))

				if _herb_sys.has_method("get_cooldown_seconds"):
					n["cooldown_s"] = float(_herb_sys.call("get_cooldown_seconds", axial, patch_id))

		out.append(n)

	return out


# =====================================================================
# Public API
# =====================================================================

func rebuild_nodes_for_tile(
	ax: Vector2i,
	modifiers: Array,
	biome: String = "",
	tier: int = 0
) -> void:
	var nodes: Array = []          # Array[Dictionary] but kept untyped to avoid Variant warnings
	var stored_mods: Array = []    # Array[Dictionary]

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
		if skill == "woodcutting" and detail.to_lower().find("thick") != -1:
			chance_factor = 0.5
			yield_factor = 2.0

		# ResourceNodes identifies nodes only.
		# Actual product/drop data belongs to the skill systems.

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

		# Attach canonical IDs.
		# Phase 1D.1 rule:
		# mining      -> node_id
		# woodcutting -> target_id + node_id
		# fishing     -> node_id
		# herbalism   -> patch_id + node_id

		var explicit_node_id: StringName = _string_name_from_variant(md.get("node_id", StringName("")))
		if explicit_node_id != StringName(""):
			node["node_id"] = explicit_node_id

		match skill:
			"mining":
				var mining_node_id: StringName = explicit_node_id
				if mining_node_id == StringName(""):
					mining_node_id = _infer_mining_node_id_from_text(detail)

				if mining_node_id != StringName(""):
					node["node_id"] = mining_node_id

			"woodcutting":
				var target_id: StringName = _string_name_from_variant(md.get("target_id", StringName("")))
				if target_id == StringName(""):
					target_id = _string_name_from_variant(md.get("node_id", StringName("")))
				if target_id == StringName(""):
					target_id = _infer_woodcutting_target_id_from_text(detail)

				if target_id != StringName(""):
					node["target_id"] = target_id
					node["node_id"] = target_id

			"fishing":
				var fishing_node_id: StringName = explicit_node_id
				if fishing_node_id == StringName(""):
					fishing_node_id = _infer_fishing_node_id_from_text(detail)

				if fishing_node_id != StringName(""):
					node["node_id"] = fishing_node_id

			"herbalism":
				var patch_id: StringName = _string_name_from_variant(md.get("patch_id", StringName("")))

				# Existing biome/modifier data commonly uses "id" for the herb patch slug.
				if patch_id == StringName(""):
					patch_id = _string_name_from_variant(md.get("id", StringName("")))

				if patch_id == StringName(""):
					patch_id = explicit_node_id

				if patch_id == StringName(""):
					patch_id = _infer_herbal_patch_id_from_text(detail)

				if patch_id != StringName(""):
					node["patch_id"] = patch_id
					node["node_id"] = patch_id


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


func get_nodes_for_tile(axial: Vector2i) -> Array:
	var nodes_v: Variant = _nodes_by_ax.get(axial, [])
	var nodes: Array = []
	if nodes_v is Array:
		nodes = nodes_v
	return _enrich_nodes_runtime(axial, nodes)


func get_nodes(ax: Vector2i, skill: String) -> Array:
	var s := skill.to_lower()
	var nodes := get_nodes_for_tile(ax)
	var out: Array = []
	for n_v in nodes:
		if typeof(n_v) != TYPE_DICTIONARY:
			continue
		var n: Dictionary = n_v
		if String(n.get("skill", "")).to_lower() == s:
			out.append(n)
	return out


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
	var v: Variant = _mods_by_ax[ax]
	if v is Array:
		return (v as Array).duplicate(true)
	return []


# =====================================================================
# Internal helpers
# =====================================================================

func _string_name_from_variant(v: Variant) -> StringName:
	if typeof(v) == TYPE_STRING_NAME:
		return v as StringName

	if typeof(v) == TYPE_STRING:
		var s: String = String(v).strip_edges()
		if s != "":
			return StringName(s)

	return StringName("")


func _infer_mining_node_id_from_text(text: String) -> StringName:
	var lower: String = text.to_lower()

	# Prefer MiningSystem if it exposes its own inference helper.
	if _mining_sys != null and _mining_sys.has_method("infer_node_id_from_text"):
		var inferred: Variant = _mining_sys.call("infer_node_id_from_text", text)
		var inferred_id: StringName = _string_name_from_variant(inferred)
		if inferred_id != StringName(""):
			return inferred_id

	for kw_v: Variant in MINING_KEYWORD_TO_NODE_ID.keys():
		var kw: String = String(kw_v)
		if lower.find(kw) != -1:
			return StringName(MINING_KEYWORD_TO_NODE_ID[kw_v])

	return StringName("")


func _infer_woodcutting_target_id_from_text(text: String) -> StringName:
	var lower: String = text.to_lower()

	for kw_v: Variant in WOODCUTTING_KEYWORD_TO_TARGET_ID.keys():
		var kw: String = String(kw_v)
		if lower.find(kw) != -1:
			return StringName(WOODCUTTING_KEYWORD_TO_TARGET_ID[kw_v])

	return StringName("")


func _infer_fishing_node_id_from_text(text: String) -> StringName:
	var key_detail: String = text.strip_edges()
	if FISHING_DETAIL_TO_NODE_ID.has(key_detail):
		return StringName(String(FISHING_DETAIL_TO_NODE_ID[key_detail]))

	return StringName("")


func _infer_herbal_patch_id_from_text(text: String) -> StringName:
	if _herb_sys == null:
		return StringName("")

	if _herb_sys.has_method("infer_patch_id_from_text"):
		var inferred: Variant = _herb_sys.call("infer_patch_id_from_text", text)
		var patch_id: StringName = _string_name_from_variant(inferred)
		if patch_id != StringName(""):
			return patch_id

	return StringName("")

func _mod_get_detail(md: Dictionary) -> String:
	# New format: name is the human label
	if md.has("name"):
		return String(md.get("name", "")).strip_edges()
	# Some callers might use "detail"
	if md.has("detail"):
		return String(md.get("detail", "")).strip_edges()
	# Some systems might use "label"
	if md.has("label"):
		return String(md.get("label", "")).strip_edges()
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
