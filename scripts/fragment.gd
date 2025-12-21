extends Node2D
class_name Fragment

signal clicked(fragment: Fragment)

@onready var hex: Polygon2D              = $Hex
@onready var label: Label                = $Label
@onready var outline: Line2D             = $Outline
@onready var colpoly: CollisionPolygon2D = $Area2D/CollisionPolygon2D
@onready var area: Area2D                = $Area2D
@onready var biome_icon: Sprite2D        = $BiomeIcon
@onready var mod_icons_root: Node2D      = $ModIcons

var biome: String = "Hamlet"
var coord: Vector2i = Vector2i.ZERO
var selected: bool = false
var modifiers: Array[String] = []   # rolled tile modifiers
var recruit_triggered: bool = false # so we don’t double-fire later

var recruited_villager_idx: int = -1  # index of villager this tile recruited (if any)


# Biome meta
var tier: int = 0                   # 0 = special (Hamlet), 1–10 = R1–R10
var region: String = ""             # e.g. "Home", "R1", "R2", ...


const HEX_SIZE: float = 60.0
const SQRT3: float = 1.7320508075688772

# ---------------------------------------------------
# Biome → icon texture path
# ---------------------------------------------------
const BIOME_ICON_PATHS := {
	"Hamlet": "res://assets/icons/biomes/hamlet.png",

	"Mountain": "res://assets/icons/biomes/Mountain.png",
	"Forest": "res://assets/icons/biomes/Forest.png",
	"River": "res://assets/icons/biomes/River.png",

	"Maplewood Vale": "res://assets/icons/biomes/Maplewood Vale.png",
	"Rocky Estuary": "res://assets/icons/biomes/Rocky Estuary.png",
	"Foothill Valleys": "res://assets/icons/biomes/Foothill Valleys.png",

	"Silkwood": "res://assets/icons/biomes/Silkwood.png",
	"Cenote Sinkholes": "res://assets/icons/biomes/Cenote Sinkholes.png",
	"Painted Canyon": "res://assets/icons/biomes/Painted Canyon.png",
	# ...fill out later tiers as you add art
}
# ---------------------------------------------------
# Modifier icons:
# - MOD_SKILL_ICON_PATHS: for [mining], [woodcutting], etc.
# - MOD_KIND_ICON_PATHS: for "Hazard", "Structure", "Recruit Event", etc.
# ---------------------------------------------------
const MOD_SKILL_ICON_PATHS := {
	"mining":      "res://assets/icons/modifiers/mining_node.png",
	"woodcutting": "res://assets/icons/modifiers/woodcutting_node.png",
	"herbalism":   "res://assets/icons/modifiers/herbalism_node.png",
	"fishing":     "res://assets/icons/modifiers/fishing_node.png",
	"farming":     "res://assets/icons/modifiers/farming_node.png",
}

const MOD_KIND_ICON_PATHS := {
	# No generic "Resource Spawn" icon on purpose – those use skill icons.
	"Recruit Event":  "res://assets/icons/modifiers/recruit.png",
	"Structure":      "res://assets/icons/modifiers/structure.png",
	"Dungeon / Delve":"res://assets/icons/modifiers/dungeon.png",
	"Hazard":         "res://assets/icons/modifiers/hazard.png",
}

const MINING_NODE_ICON_PATHS := {
	# Stone nodes
	"limestone":  "res://assets/icons/modifiers/limestone_stone.png",
	"sandstone":  "res://assets/icons/modifiers/sandstone_stone.png",
	"basalt":     "res://assets/icons/modifiers/basalt_stone.png",
	"granite":    "res://assets/icons/modifiers/granite_stone.png",
	"marble":     "res://assets/icons/modifiers/marble_stone.png",
	"clay":     "res://assets/icons/modifiers/clay_stone.png",

	# Ore nodes
	"copper":     "res://assets/icons/modifiers/copper_ore.png",
	"tin":        "res://assets/icons/modifiers/tin_ore.png",
	"iron":       "res://assets/icons/modifiers/iron_ore.png",
	"coal":       "res://assets/icons/modifiers/coal_ore.png",
	"silver":     "res://assets/icons/modifiers/silver_ore.png",
	"gold":       "res://assets/icons/modifiers/gold_ore.png",
	"mithrite":   "res://assets/icons/modifiers/mithrite_ore.png",
	"adamantite": "res://assets/icons/modifiers/adamantite_ore.png",
	"orichalcum": "res://assets/icons/modifiers/orichalcum_ore.png",
	"aether":     "res://assets/icons/modifiers/aether_ore.png",

	# Gem nodes – adjust to match your actual filenames
	"lesser gem":   "res://assets/icons/modifiers/gem_lesser_gem.png",
	"precious gem": "res://assets/icons/modifiers/gem_precious_gem.png",
	"rare gem":     "res://assets/icons/modifiers/gem_rare_gem.png",
	"mythic gem":   "res://assets/icons/modifiers/gem_mythic_gem.png",
}

const WOODCUTTING_NODE_ICON_PATHS := {
	# T1 – Pine
	"pine_grove":           "res://assets/icons/modifiers/tree_pine.png",
	"thick_pine_grove":     "res://assets/icons/modifiers/tree_pine_thick.png",

	# T2 – Birch
	"birch_grove":          "res://assets/icons/modifiers/tree_birch.png",
	"thick_birch_grove":    "res://assets/icons/modifiers/tree_birch_thick.png",

	# T3 – Oak / Silkwood / Mulberry
	"oak_grove":            "res://assets/icons/modifiers/tree_oak.png",
	"thick_oak_grove":      "res://assets/icons/modifiers/tree_oak_thick.png",

	# T4 – Willow
	"willow_grove":         "res://assets/icons/modifiers/tree_willow.png",
	"thick_willow_grove":   "res://assets/icons/modifiers/tree_willow_thick.png",

	# T5 – Maple
	"maple_grove":          "res://assets/icons/modifiers/tree_maple.png",
	"thick_maple_grove":    "res://assets/icons/modifiers/tree_maple_thick.png",

	# T6 – Yew
	"yew_grove":            "res://assets/icons/modifiers/tree_yew.png",
	"thick_yew_grove":      "res://assets/icons/modifiers/tree_yew_thick.png",

	# T7 – Ironwood
	"ironwood_grove":       "res://assets/icons/modifiers/tree_ironwood.png",
	"thick_ironwood_grove": "res://assets/icons/modifiers/tree_ironwood_thick.png",

	# T8 – Redwood
	"redwood_grove":        "res://assets/icons/modifiers/tree_redwood.png",
	"thick_redwood_grove":  "res://assets/icons/modifiers/tree_redwood_thick.png",

	# T9 – Sakura
	"sakura_grove":         "res://assets/icons/modifiers/tree_sakura.png",
	"thick_sakura_grove":   "res://assets/icons/modifiers/tree_sakura_thick.png",

	# T10 – Elder
	"elder_grove":          "res://assets/icons/modifiers/tree_elder.png",
	"thick_elder_grove":    "res://assets/icons/modifiers/tree_elder_thick.png",

	# Ivy (special)
	"ivy_grove":            "res://assets/icons/modifiers/tree_ivy.png",
	"thick_ivy_grove":      "res://assets/icons/modifiers/tree_ivy_thick.png",
	}

const FISHING_NODE_ICON_PATHS := {
	# F1 – River
	"riverbank shallows":  "res://assets/icons/modifiers/fishing_n1_riverbank_shallows.png",   # N1
	"minnow ford pool":    "res://assets/icons/modifiers/fishing_r1_minnow_ford_pool.png",     # R1

	# F2 – Rocky Estuary
	"rocky estuary nets":  "res://assets/items/Fishing/fishing_n2_rocky_estuary_nets.png",   # N2
	"brackwater channel":  "res://assets/items/Fishing/fishing_r2_brackwater_channel.png",   # R2

	# F3 – Cenote Sinkholes
	"sinkhole plunge pool":"res://assets/items/Fishing/fishing_r3_sinkhole_plunge_pool.png", # R3

	# F4 – Karst Cascade Gorge
	"cascade shelf nets":  "res://assets/items/Fishing/fishing_n4_cascade_shelf_nets.png",   # N4
	"echofall basin":      "res://assets/items/Fishing/fishing_r4_echofall_basin.png",       # R4

	# F5 – Floodplain
	"oxbow bend pool":     "res://assets/items/Fishing/fishing_r5_oxbow_bend_pool.png",      # R5
	"leviathan channel":   "res://assets/items/Fishing/fishing_h5_leviathan_channel.png",    # H5

	# F6 – River Gorge
	"chasm surge run":     "res://assets/items/Fishing/fishing_h6_chasm_surge_run.png",      # H6

	# F7 – Floating Oasis
	"hanging oasis nets":  "res://assets/items/Fishing/fishing_n7_hanging_oasis_nets.png",   # N7
	"skywell sink":        "res://assets/items/Fishing/fishing_h7_skywell_sink.png",         # H7

	# F8 – Frozen Tarn
	"ice-crack nets":      "res://assets/items/Fishing/fishing_n8_ice_crack_nets.png",       # N8

	# F9 – Drakefire Geyser Basin
	"boiling runoff nets": "res://assets/items/Fishing/fishing_n9_boiling_runoff_nets.png",  # N9
	"geyser cone pool":    "res://assets/items/Fishing/fishing_r9_geyser_cone_pool.png",     # R9
	"steamvent pit":       "res://assets/items/Fishing/fishing_h9_steamvent_pit.png",        # H9

	# F10 – Starsea Rift
	"abyssal star trench": "res://assets/items/Fishing/fishing_h10_abyssal_star_trench.png", # H10
}



# ===================================================
# Lifecycle
# ===================================================

func _ready() -> void:
	_build_hex()

	# Make sure the Area2D can receive mouse input
	if area != null:
		area.input_pickable = true
		if not area.input_event.is_connected(_on_area_input_event):
			area.input_event.connect(_on_area_input_event)

	# Labels can block clicks if not ignored
	if label != null:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Make sure the collision polygon is enabled
	if colpoly != null:
		colpoly.disabled = false

	# Modifier icons sit above the hex, under the outline
	if mod_icons_root != null:
		mod_icons_root.z_index = 50
		var slots := _get_mod_icon_sprites()
		if slots.is_empty():
			push_warning("Fragment: ModIcons node has no Sprite2D children; no modifier icons will be visible.")

	_set_biome_visuals()
	_update_label()
	_update_modifier_icons()
	set_selected(false)

# ===================================================
# Modifier icons
# ===================================================

func _get_mod_icon_sprites() -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	if mod_icons_root == null:
		return sprites
	_collect_sprites_recursive(mod_icons_root, sprites)
	return sprites


func _collect_sprites_recursive(node: Node, out: Array[Sprite2D]) -> void:
	for child in node.get_children():
		if child is Sprite2D:
			out.append(child)
		elif child is Node:
			_collect_sprites_recursive(child, out)

func _resolve_mining_icon_for_modifier(mod_str: String) -> String:
	var lower := mod_str.to_lower()

	# Try specific mining-node icons first
	for kw in MINING_NODE_ICON_PATHS.keys():
		if lower.find(kw) != -1:
			return String(MINING_NODE_ICON_PATHS[kw])

	# Fallback: generic mining icon if nothing matched
	return String(MOD_SKILL_ICON_PATHS.get("mining", ""))

func _resolve_fishing_icon_for_modifier(mod_str: String) -> String:
	var lower := mod_str.to_lower()

	for kw in FISHING_NODE_ICON_PATHS.keys():
		if lower.find(kw) != -1:
			return String(FISHING_NODE_ICON_PATHS[kw])

	# Fallback: generic fishing icon if nothing matched
	return String(MOD_SKILL_ICON_PATHS.get("fishing", ""))


func _resolve_woodcutting_icon_for_modifier(mod_str: String) -> String:
	var lower := mod_str.to_lower()

	# -----------------------------------------
	# 1) Decide base GROVE id from the text
	# -----------------------------------------
	var base := ""

	# Ivy first (doesn't mention a tree species)
	if lower.find("ivy") != -1:
		base = "ivy_grove"
	elif lower.find("pine") != -1:
		base = "pine_grove"
	elif lower.find("birch") != -1:
		base = "birch_grove"
	# Silkwood / Mulberry are visually oak
	elif lower.find("silkwood") != -1 or lower.find("mulberry") != -1 or lower.find("oak") != -1:
		base = "oak_grove"
	elif lower.find("willow") != -1:
		base = "willow_grove"
	# Maplewood Vale – includes things like "Maple Grove", "Hedgerow grove", "Vale Orchard"
	elif lower.find("maple") != -1 \
		or lower.find("vale orchard") != -1 \
		or lower.find("hedgerow") != -1:
		base = "maple_grove"
	elif lower.find("yew") != -1:
		base = "yew_grove"
	elif lower.find("ironwood") != -1:
		base = "ironwood_grove"
	elif lower.find("redwood") != -1:
		base = "redwood_grove"
	elif lower.find("sakura") != -1 or lower.find("blossom") != -1:
		base = "sakura_grove"
	elif lower.find("elder") != -1:
		base = "elder_grove"

	# -----------------------------------------
	# 2) Thick variants:
	#    - any explicit "Thick"
	#    - Overgrown / Choking Ivy
	#    (Light Ivy stays non-thick)
	# -----------------------------------------
	var is_thick := false

	if lower.find("thick") != -1:
		is_thick = true

	# Ivy special cases
	if lower.find("overgrown ivy") != -1 or lower.find("choking ivy") != -1:
		is_thick = true

	var key := base
	if is_thick and base != "":
		var thick_key := "thick_" + base
		if WOODCUTTING_NODE_ICON_PATHS.has(thick_key):
			key = thick_key

	# -----------------------------------------
	# 3) Resolve to an icon path
	# -----------------------------------------
	if key != "" and WOODCUTTING_NODE_ICON_PATHS.has(key):
		return String(WOODCUTTING_NODE_ICON_PATHS[key])

	# Fallback: generic woodcutting icon so we never break icons entirely
	return String(MOD_SKILL_ICON_PATHS.get("woodcutting", ""))

func _update_modifier_icons() -> void:
	if mod_icons_root == null:
		return

	var sprites: Array[Sprite2D] = _get_mod_icon_sprites()

	# Hide & clear everything by default
	for s in sprites:
		s.visible = false
		s.texture = null

	if modifiers.is_empty() or sprites.is_empty():
		return

	var icon_index: int = 0

	for m in modifiers:
		if icon_index >= sprites.size():
			break
		if typeof(m) != TYPE_STRING:
			continue

		var mod_str := String(m)
		var icon_path: String = ""

		# Split "Header: Detail"
		# e.g. "Resource Spawn [mining]: Exposed Stone Face"
		#      "Hazard: Sinking Mire"
		var parts := mod_str.split(": ", false, 2)
		var header := parts[0] if parts.size() > 0 else mod_str

		var kind_base := header         # "Resource Spawn [mining]" or "Hazard"
		var skill_id := ""              # "mining" if present

		# Extract [skill] if present: "Resource Spawn [mining]"
		var open_idx := header.find("[")
		if open_idx != -1:
			var close_idx := header.find("]", open_idx + 1)
			if close_idx != -1:
				kind_base = header.substr(0, open_idx).strip_edges()  # "Resource Spawn"
				skill_id = header.substr(open_idx + 1, close_idx - open_idx - 1).strip_edges().to_lower()

		# 1) If it has a [skill], prefer the skill icon
		if skill_id != "":
			if skill_id == "mining":
				icon_path = _resolve_mining_icon_for_modifier(mod_str)
			elif skill_id == "fishing":
				icon_path = _resolve_fishing_icon_for_modifier(mod_str)
			elif skill_id == "woodcutting":
				icon_path = _resolve_woodcutting_icon_for_modifier(mod_str)
			else:
				icon_path = String(MOD_SKILL_ICON_PATHS.get(skill_id, ""))



		# 2) Otherwise (or if skill icon missing), fall back to kind icon
		if icon_path == "":
			icon_path = String(MOD_KIND_ICON_PATHS.get(kind_base, ""))

		if icon_path == "":
			# Nothing configured for this modifier; skip but keep iterating
			continue

		var tex := load(icon_path)
		if tex is Texture2D:
			var spr := sprites[icon_index]
			spr.texture = tex
			spr.visible = true

			# Icon size: default ~half hex height
			var max_dim := float(max(tex.get_width(), tex.get_height()))
			if max_dim > 0.0:
				var target_px := HEX_SIZE * 0.5  # default

				# 🔹 Override per-skill if you want them bigger
				if skill_id == "fishing":
					target_px = HEX_SIZE * 0.6  # tweak per-skill
				elif skill_id == "woodcutting":
					target_px = HEX_SIZE * 0.55
				elif skill_id == "herbalism":
					target_px = HEX_SIZE * 0.65

				var scale_factor := target_px / max_dim
				spr.scale = Vector2(scale_factor, scale_factor)

			icon_index += 1
		else:
			push_warning("Failed to load modifier icon texture: %s" % icon_path)



func set_local_modifiers(mods: Array) -> void:
	var typed_mods: Array[String] = []
	for m in mods:
		typed_mods.append(String(m))

	modifiers = typed_mods

	print("Fragment", biome, coord, "local modifiers set to:", modifiers)

	_update_modifier_icons()

# ===================================================
# Setup
# ===================================================

# Accepts (Vector2i, String) OR (String, Vector2i)
# Optional 3rd argument: meta dictionary { "tier": int, "region": String, "modifiers": Array[String] }
func setup(a: Variant, b: Variant, meta: Dictionary = {}) -> void:
	if typeof(a) == TYPE_VECTOR2I and typeof(b) == TYPE_STRING:
		coord = a
		biome = b
	elif typeof(a) == TYPE_STRING and typeof(b) == TYPE_VECTOR2I:
		biome = a
		coord = b
	else:
		push_error("Fragment.setup(): expected (Vector2i, String) or (String, Vector2i)")
		return

	# Optional meta (tier / region / modifiers) – used by World.gd
	if not meta.is_empty():
		if meta.has("tier"):
			tier = int(meta["tier"])
		if meta.has("region"):
			region = String(meta["region"])
		if meta.has("modifiers"):
			var arr: Variant = meta["modifiers"]
			if arr is Array:
				var typed_mods: Array[String] = []
				for v in (arr as Array):
					typed_mods.append(String(v))
				modifiers = typed_mods

	_update_label()
	_set_biome_visuals()
	_update_modifier_icons()

# ===================================================
# Selection & input
# ===================================================

func set_selected(v: bool) -> void:
	selected = v
	if is_instance_valid(outline):
		outline.visible = v


func _on_area_input_event(_vp: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 1) Ask the World which villager (if any) is on this tile
		var world := get_tree().get_first_node_in_group("World")
		if world != null:
			var v_idx: int = -1

			# Your World script already uses this helper in other places
			if world.has_method("villager_on_tile"):
				v_idx = world.call("villager_on_tile", coord)

			# 2) If there is a villager here, start a drag exactly like the list does
			if v_idx >= 0 and typeof(DragState) != TYPE_NIL and DragState.has_method("begin"):
				DragState.begin(v_idx)

		# 3) Still emit the click so selection etc. keeps working
		clicked.emit(self)
		get_viewport().set_input_as_handled()


func get_recruited_villager_idx() -> int:
	return recruited_villager_idx

# ===================================================
# Recruit helpers
# ===================================================

func has_recruit_modifier() -> bool:
	for m in modifiers:
		if typeof(m) == TYPE_STRING:
			var s := String(m)
			# World.gd builds strings like "Recruit Event: Hillstead Quarry Camp"
			if s.begins_with("Recruit Event"):
				return true
	return false


func get_recruit_source_name() -> String:
	# Returns the bit after "Recruit Event: " for flavour / race mapping
	for m in modifiers:
		if typeof(m) == TYPE_STRING:
			var s := String(m)
			if s.begins_with("Recruit Event"):
				var parts := s.split(": ", false, 2)
				if parts.size() == 2:
					return parts[1]  # e.g. "Hillstead Quarry Camp"
				return s
	return ""

func try_trigger_recruit() -> void:
	# Prevent double-join if this is called multiple times
	if recruit_triggered:
		return
	if not has_recruit_modifier():
		return

	# LATER: when anchoring is real, you can gate it here:
	# if not is_anchored():
	#     return

	if typeof(Villagers) == TYPE_NIL:
		return
	if not Villagers.has_method("auto_recruit_from_biome"):
		return

	# Ask Villagers autoload to create an appropriate recruit for this biome.
	# It should return the new villager’s index, or -1 on failure.
	var v_idx: int = int(Villagers.auto_recruit_from_biome(biome))

	if v_idx >= 0:
		# 🔹 NEW: remember who this fragment recruited
		recruited_villager_idx = v_idx

		# Look up the World node via its group (World.gd calls add_to_group("World") in _ready)
		var world := get_tree().get_first_node_in_group("World")
		if world and world.has_method("place_villager_at_hamlet"):
			world.call("place_villager_at_hamlet", v_idx)

	recruit_triggered = true

# ===================================================
# Visuals
# ===================================================

func _build_hex() -> void:
	var pts: PackedVector2Array = _hex_points_open()

	if is_instance_valid(hex):
		hex.polygon = pts
		hex.z_index = 0

	if is_instance_valid(outline):
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		outline.points = closed
		outline.width = 4.0
		outline.z_index = 100

	if is_instance_valid(colpoly):
		colpoly.polygon = pts


func _hex_points_open() -> PackedVector2Array:
	var s: float = HEX_SIZE
	return PackedVector2Array([
		Vector2(0.0, -s),
		Vector2(SQRT3 * 0.5 * s, -0.5 * s),
		Vector2(SQRT3 * 0.5 * s,  0.5 * s),
		Vector2(0.0, s),
		Vector2(-SQRT3 * 0.5 * s, 0.5 * s),
		Vector2(-SQRT3 * 0.5 * s, -0.5 * s),
	])


func _update_label() -> void:
	if label != null:
		var tier_prefix := ""
		if tier > 0:
			tier_prefix = "T%d " % tier
		label.text = "%s%s\n(%d,%d)" % [tier_prefix, biome, coord.x, coord.y]


func _set_biome_visuals() -> void:
	if not is_instance_valid(hex):
		return
	hex.color = _biome_color(biome)
	_update_biome_icon()


func _update_biome_icon() -> void:
	if biome_icon == null:
		return

	var path: String = String(BIOME_ICON_PATHS.get(biome, ""))
	if path == "":
		biome_icon.texture = null
		biome_icon.visible = false
		return

	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		biome_icon.texture = tex
		biome_icon.visible = true

		# Auto-scale to a fraction of HEX_SIZE
		var max_dim: float = float(max(tex.get_width(), tex.get_height()))
		if max_dim > 0.0:
			var target_px: float = HEX_SIZE * 1.0
			var scale_factor: float = target_px / max_dim

			# Make the River icon 80% of the usual size
			if biome == "River":
				scale_factor *= 0.65

			biome_icon.scale = Vector2(scale_factor, scale_factor)
	else:
		biome_icon.texture = null
		biome_icon.visible = false


func _biome_color(b: String) -> Color:
	match b:
		# Home / special
		"Hamlet":
			return Color(0.455, 0.537, 0.667, 1.0) # muted blue-slate

		# Tier 1 — Local Frontier (R1)
		"Mountain":
			return Color(0.545, 0.561, 0.631, 1.0) # cool slate
		"Forest":
			return Color(0.180, 0.490, 0.196, 1.0) # rich forest green
		"River":
			return Color(0.118, 0.533, 0.898, 1.0) # bright river blue

		# Tier 2 — Mixed Lowlands (R2)
		"Maplewood Vale":
			return Color(0.816, 0.506, 0.235, 1.0) # orange-maple woodland
		"Rocky Estuary":
			return Color(0.310, 0.486, 0.482, 1.0) # blue-grey tidal rock
		"Foothill Valleys":
			return Color(0.557, 0.616, 0.302, 1.0) # warm olive valley

		# Tier 3 — Frontier Biomes (R3)
		"Silkwood":
			return Color(0.431, 0.310, 0.639, 1.0) # dusky violet silk-forest
		"Cenote Sinkholes":
			return Color(0.122, 0.620, 0.588, 1.0) # teal cenote water
		"Painted Canyon":
			return Color(0.851, 0.369, 0.255, 1.0) # red/orange canyon walls

		# Tier 4 — Mountain Girdle (R4)
		"Cloudpine Terraces":
			return Color(0.494, 0.776, 0.890, 1.0) # airy sky terraces
		"Karst Cascade Gorge":
			return Color(0.369, 0.478, 0.549, 1.0) # blue-grey karst rock
		"Painted Talus Mines":
			return Color(0.690, 0.424, 0.314, 1.0) # rusty talus/mine earth

		# Tier 5 — Great River Rift (R5)
		"Baobab Savanna":
			return Color(0.851, 0.761, 0.451, 1.0) # dry golden savanna
		"Floodplain":
			return Color(0.373, 0.655, 0.412, 1.0) # lush green wetlands
		"Rift Valley":
			return Color(0.706, 0.541, 0.353, 1.0) # brown rift earth

		# Tier 6 — Crownlands (R6)
		"Rainforest Highwood":
			return Color(0.118, 0.435, 0.302, 1.0) # deep emerald canopy
		"River Gorge":
			return Color(0.082, 0.396, 0.753, 1.0) # dark gorge blue
		"Mesas":
			return Color(0.761, 0.431, 0.239, 1.0) # terracotta mesas

		# Tier 7 — Desert Threshold (R7)
		"Incense Groves":
			return Color(0.663, 0.510, 0.741, 1.0) # smoky lavender groves
		"Floating Oasis":
			return Color(0.200, 0.725, 0.776, 1.0) # bright teal oasis
		"Salt Dome Escarpments":
			return Color(0.878, 0.839, 0.769, 1.0) # pale salt/stone

		# Tier 8 — Glacial Edge (R8)
		"Boreal Ridge":
			return Color(0.200, 0.361, 0.435, 1.0) # dark boreal pine
		"Frozen Tarn":
			return Color(0.561, 0.816, 0.910, 1.0) # icy tarn blue
		"Permafrost Steppe":
			return Color(0.784, 0.831, 0.847, 1.0) # cold grey steppe

		# Tier 9 — Volcanic / Infernal Threshold (R9)
		"Ashfield Cinderwood":
			return Color(0.353, 0.227, 0.200, 1.0) # scorched brown/ash
		"Drakefire Geyser Basin":
			return Color(0.941, 0.431, 0.235, 1.0) # bright magma/orange
		"Magmaforge Undercaverns":
			return Color(0.502, 0.188, 0.290, 1.0) # deep magmatic crimson

		# Tier 10 —balances Celestial / Void Boundary (R10)
		"Celestial Grove":
			return Color(0.361, 0.604, 0.784, 1.0) # teal-azure celestial forest
		"Starsea Rift":
			return Color(0.235, 0.239, 0.569, 1.0) # deep indigo starsea
		"Void Scar":
			return Color(0.133, 0.106, 0.227, 1.0) # almost-black void

		_:
			return Color(0.55, 0.55, 0.55, 1.0) # unknown / debug

# ===================================================
# World bindings (Founder / villager-bound tiles)
# ===================================================
func get_local_effects_summary() -> String:
	var parts: Array[String] = []

	# Base modifier: this is the original Hamlet fragment
	if biome == "Hamlet":
		parts.append("Home fragment")

	# Tile is anchored (so it cannot despawn)
	if is_anchored():
		parts.append("Anchored")

	# Bound villager (Founder or later villagers)
	var bound_name: String = get_bound_villager_name()
	if bound_name != "":
		if typeof(Villagers) != TYPE_NIL \
		and Villagers.has_method("get_founder_id") \
		and get_bound_villager_id() == Villagers.get_founder_id():
			parts.append("Founder bound: %s" % bound_name)
		else:
			parts.append("Bound villager: %s" % bound_name)

	# 🔹 Building & modules are **effects**, not modifiers
	if has_meta("building_id"):
		var base_id := String(get_meta("building_id"))
		if base_id != "":
			parts.append("Building: %s" % base_id)

			if has_meta("building_modules"):
				var mvar: Variant = get_meta("building_modules")
				if mvar is Array:
					var module_labels: Array[String] = []
					for m in (mvar as Array):
						var s := String(m)
						if s != "":
							module_labels.append(s)
					if not module_labels.is_empty():
						parts.append("Modules: " + ", ".join(module_labels))

	# ❌ DO **NOT** include tile modifiers here – those are permanent
	# and are shown in SelectionHUD's Modifiers box instead.

	if parts.is_empty():
		return "No active effects"

	return ", ".join(parts)



func get_bound_villager_id() -> int:
	if typeof(WorldData) == TYPE_NIL:
		return -1
	if not WorldData.has_method("get_bound_villager_id"):
		return -1
	return WorldData.get_bound_villager_id(coord)


func has_bound_villager() -> bool:
	return get_bound_villager_id() >= 0


func is_anchored() -> bool:
	if typeof(WorldData) == TYPE_NIL:
		return false
	if not WorldData.has_method("is_anchored"):
		return false
	return WorldData.is_anchored(coord)


func get_bound_villager_name() -> String:
	var vid: int = get_bound_villager_id()
	if vid < 0:
		return ""

	if typeof(Villagers) == TYPE_NIL:
		return ""
	if not Villagers.has_method("index_from_id"):
		return ""
	if not Villagers.has_method("get_at"):
		return ""

	var idx: int = Villagers.index_from_id(vid)
	if idx < 0:
		return ""

	var v = Villagers.get_at(idx)
	if not v:
		return ""
	return v.name
