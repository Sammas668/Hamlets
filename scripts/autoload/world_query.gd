extends Node
# Stores current selection and offers adjacency + modifier queries.

var selected_axial: Vector2i = Vector2i(0, 0)

# Axial neighbors for pointy-top axial (q,r).
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, -1), Vector2i(-1, 1)
]

# -------------------------------------------------
# Biome helpers
# -------------------------------------------------

# Internal helper: get the biome of a tile as a plain String.
func _get_biome_string(ax: Vector2i) -> String:
	if typeof(Selection) == TYPE_NIL:
		return ""
	if not Selection.has_method("fragment_at"):
		return ""

	var frag: Node = Selection.fragment_at(ax)
	if frag == null:
		return ""

	var biome_v: Variant = frag.get("biome")

	# Handle String, StringName, and anything else gracefully
	if biome_v is String:
		return biome_v as String
	elif biome_v is StringName:
		return String(biome_v)
	else:
		return str(biome_v)

# Return true if tile at 'ax' has the given biome tag (e.g., "Forest").
func tile_has_biome(ax: Vector2i, biome_tag: StringName) -> bool:
	var biome_s: String = _get_biome_string(ax)
	if biome_s == "":
		return false

	# biome_tag is a StringName, compare as String for safety
	return biome_s == String(biome_tag)

func has_adjacent_biome(center: Vector2i, biome_tag: StringName) -> bool:
	for d in NEIGHBORS:
		if tile_has_biome(center + d, biome_tag):
			return true
	return false

func set_selected(ax: Vector2i) -> void:
	selected_axial = ax

# -------------------------------------------------
# Modifier helpers
# -------------------------------------------------

func get_tile_modifiers(ax: Vector2i) -> Array:
	# Safely look up the fragment for this axial and return its modifiers.
	if typeof(Selection) == TYPE_NIL:
		return []

	if not Selection.has_method("fragment_at"):
		return []

	var frag: Node = Selection.fragment_at(ax)
	if frag == null:
		return []

	# Normal case: Fragment.gd has `var modifiers: Array`
	var mods_v: Variant = frag.get("modifiers")
	if mods_v is Array:
		return mods_v as Array

	# Optional fallback: if you also track this in ResourceNodes
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("get_modifiers_for_tile"):
		var alt: Variant = ResourceNodes.get_modifiers_for_tile(ax)
		if alt is Array:
			return alt as Array

	return []

# -------------------------------------------------
# Debug helper
# -------------------------------------------------

func debug_tile(ax: Vector2i) -> void:
	if typeof(Selection) == TYPE_NIL:
		print("Selection is NIL")
		return

	print("--- Debug tile ", ax, " ---")
	if Selection.has_method("has_fragment_at"):
		print(" has_fragment_at: ", Selection.has_fragment_at(ax))

	var frag: Node = null
	if Selection.has_method("fragment_at"):
		frag = Selection.fragment_at(ax)
	print(" frag: ", frag)

	if frag:
		var biome_v: Variant = frag.get("biome")
		print(" biome_v: ", biome_v, " (type: ", typeof(biome_v), ")")
		print(" biome_string: ", _get_biome_string(ax))

		var mods_v: Variant = frag.get("modifiers")
		print(" frag.modifiers: ", mods_v)

	# Optional: from ResourceNodes if you use it
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("get_modifiers_for_tile"):
		print(" ResourceNodes.get_modifiers_for_tile: ", ResourceNodes.get_modifiers_for_tile(ax))

	# And finally from our helper
	print(" WorldQuery.get_tile_modifiers: ", get_tile_modifiers(ax))
