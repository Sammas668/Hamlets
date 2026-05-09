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

# Modifier dictionaries:
# { "name": String, "kind": String, "rarity": String, "skill": String?, "id": StringName/String? }
# For herbalism patches, "id" should ideally be the slug id:
# "forest_thyme_plot", "stoneedge_flax_verge", etc.
var modifiers: Array[Dictionary] = []

var recruit_triggered: bool = false
var recruited_villager_idx: int = -1

# Biome meta
var tier: int = 0
var region: String = ""

const HEX_SIZE: float = 60.0
const SQRT3: float = 1.7320508075688772
const MOD_ICON_MAX_SIZE: float = 36.0

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

	"Cloudpine Terraces": "res://assets/icons/biomes/Cloudpine Terraces.png",
	"Karst Cascade Gorge": "res://assets/icons/biomes/Karst Cascade Gorge.png",
	"Deep Underground Mines": "res://assets/icons/biomes/Deep Underground Mines.png",

	"Baobab Savanna": "res://assets/icons/biomes/Baobab Savanna.png",
	"Floodplain": "res://assets/icons/biomes/Floodplain.png",
	"Rift Valley": "res://assets/icons/biomes/Rift Valley.png",

	"Rainforest Highwood": "res://assets/icons/biomes/Rainforest Highwood.png",
	"River Gorge": "res://assets/icons/biomes/River Gorge.png",
	"Mesas": "res://assets/icons/biomes/Mesas.png",

	"Incense Groves": "res://assets/icons/biomes/Incense Groves.png",
	"Floating Oasis": "res://assets/icons/biomes/Floating Oasis.png",
	"Salt Dome Escarpments": "res://assets/icons/biomes/Salt Dome Escarpments.png",

	"Boreal Ridge": "res://assets/icons/biomes/Boreal Ridge.png",
	"Frozen Tarn": "res://assets/icons/biomes/Frozen Tarn.png",
	"Permafrost Steppe": "res://assets/icons/biomes/Permafrost Steppe.png",

	"Ashfield Cinderwood": "res://assets/icons/biomes/Ashfield Cinderwood.png",
	"Drakefire Geyser Basin": "res://assets/icons/biomes/Drakefire Geyser Basin.png",
	"Magmaforge Undercaverns": "res://assets/icons/biomes/Magmaforge Undercaverns.png",

	"Celestial Grove": "res://assets/icons/biomes/Celestial Grove.png",
	"Starsea Rift": "res://assets/icons/biomes/Starsea Rift.png",
	"Void Scar": "res://assets/icons/biomes/Void Scar.png",
}

# ---------------------------------------------------
# Modifier icons: kinds + generic skill icons
# ---------------------------------------------------
const MOD_KIND_ICON_PATHS := {
	"Recruit Event":   "res://assets/icons/modifiers/recruit.png",
	"Structure":       "res://assets/icons/modifiers/structure.png",
	"Dungeon / Delve": "res://assets/icons/modifiers/dungeon.png",
	"Hazard":          "res://assets/icons/modifiers/hazard.png",
}

const MOD_SKILL_ICON_PATHS := {
	"mining":      "res://assets/icons/modifiers/mining_node.png",
	"woodcutting": "res://assets/icons/modifiers/woodcutting_node.png",
	"fishing":     "res://assets/icons/modifiers/fishing_node.png",
	"herbalism":   "res://assets/icons/modifiers/herbalism_node.png",
	"farming":     "res://assets/icons/modifiers/farming_node.png",
}

# ---------------------------------------------------
# Modifier icon scale overrides
# ---------------------------------------------------
const MOD_ICON_SCALE_OVERRIDES_BY_NAME := {
	# "Copper Vein": 0.9,
	# "Forest Thyme Plot": 1.1,
}

const MOD_ICON_SCALE_OVERRIDES_BY_PATH := {
	"res://assets/icons/modifiers/recruit.png": 0.8,
	# "res://assets/icons/modifiers/structure.png": 0.85,
}

# ---------------------------------------------------
# Resource Spawn icon resolution
# Keys match BIOME_MODIFIERS "name" fields.
# ---------------------------------------------------

const MINING_SPAWN_NAME_TO_ICON := {
	# Stone
	"Exposed Limestone Face": "res://assets/icons/modifiers/limestone_stone.png",
	"Limestone Cutface":      "res://assets/icons/modifiers/limestone_stone.png",
	"Sandstone Shelf":        "res://assets/icons/modifiers/sandstone_stone.png",
	"Basalt Quarry":          "res://assets/icons/modifiers/basalt_stone.png",
	"Basalt Pillar Quarry":   "res://assets/icons/modifiers/basalt_stone.png",
	"Granite Face":           "res://assets/icons/modifiers/granite_stone.png",
	"Marble Shelf":           "res://assets/icons/modifiers/marble_stone.png",
	"Marble Pillar Quarry":   "res://assets/icons/modifiers/marble_stone.png",
	"Claybank Exposure":      "res://assets/icons/modifiers/clay_stone.png",
	"Blue Clay Lens":         "res://assets/icons/modifiers/clay_stone.png",
	"Ice Geode Outcrop":      "res://assets/icons/modifiers/gem_lesser_gem.png",

	# Ores
	"Copper Vein":            "res://assets/icons/modifiers/copper_ore.png",
	"Surface Copper Vein":    "res://assets/icons/modifiers/copper_ore.png",
	"Tin Vein":               "res://assets/icons/modifiers/tin_ore.png",
	"Surface Tin Vein":       "res://assets/icons/modifiers/tin_ore.png",
	"Iron Seam":              "res://assets/icons/modifiers/iron_ore.png",
	"Coal Seam":              "res://assets/icons/modifiers/coal_ore.png",
	"Coal Vein":              "res://assets/icons/modifiers/coal_ore.png",
	"Silver Vein":            "res://assets/icons/modifiers/silver_ore.png",
	"Silver Seam":            "res://assets/icons/modifiers/silver_ore.png",
	"Gold Vein":              "res://assets/icons/modifiers/gold_ore.png",
	"Gold Seam":              "res://assets/icons/modifiers/gold_ore.png",
	"Mithrite Seam":          "res://assets/icons/modifiers/mithrite_ore.png",
	"Adamantite Seam":        "res://assets/icons/modifiers/adamantite_ore.png",
	"Adamantite Vein":        "res://assets/icons/modifiers/adamantite_ore.png",
	"Orichalcum Vein":        "res://assets/icons/modifiers/orichalcum_ore.png",
	"Aetheric Rift":          "res://assets/icons/modifiers/aether_ore.png",

	# Gems
	"Lesser Gem Geode":       "res://assets/icons/modifiers/gem_lesser_gem.png",
	"Precious Gem Geode":     "res://assets/icons/modifiers/gem_precious_gem.png",
	"Rare Gem Geode":         "res://assets/icons/modifiers/gem_rare_gem.png",
	"Mythic Gem Geode":       "res://assets/icons/modifiers/gem_mythic_gem.png",

	# Misc / special ore names
	"Rift Ore Ledge":         "res://assets/icons/modifiers/mining_node.png",
	"Opaline Seam":           "res://assets/icons/modifiers/mining_node.png",
	"Permafrost Seam Cut":    "res://assets/icons/modifiers/mining_node.png",
	"Frost-Heave Bluff":      "res://assets/icons/modifiers/mining_node.png",
	"Brimstone Crust":        "res://assets/icons/modifiers/mining_node.png",
}

const WOODCUTTING_SPAWN_NAME_TO_ICON := {
	"Pine Grove":            "res://assets/icons/modifiers/tree_pine.png",
	"Thick Pine Grove":      "res://assets/icons/modifiers/tree_pine_thick.png",

	"Birch Grove":           "res://assets/icons/modifiers/tree_birch.png",
	"Thick Birch Grove":     "res://assets/icons/modifiers/tree_birch_thick.png",

	"Oakwood Grove":         "res://assets/icons/modifiers/tree_oak.png",
	"Thick Oakwood Grove":   "res://assets/icons/modifiers/tree_oak_thick.png",

	"Willow Grove":          "res://assets/icons/modifiers/tree_willow.png",
	"Thick Willow Grove":    "res://assets/icons/modifiers/tree_willow_thick.png",

	"Maple Grove":           "res://assets/icons/modifiers/tree_maple.png",
	"Thick Maple Grove":     "res://assets/icons/modifiers/tree_maple_thick.png",

	"Yew Grove":             "res://assets/icons/modifiers/tree_yew.png",
	"Thick Yew Grove":       "res://assets/icons/modifiers/tree_yew_thick.png",

	"Ironwood Grove":        "res://assets/icons/modifiers/tree_ironwood.png",
	"Thick Ironwood Grove":  "res://assets/icons/modifiers/tree_ironwood_thick.png",

	"Redwood Grove":         "res://assets/icons/modifiers/tree_redwood.png",
	"Thick Redwood Grove":   "res://assets/icons/modifiers/tree_redwood_thick.png",

	"Sakura Grove":          "res://assets/icons/modifiers/tree_sakura.png",
	"Thick Sakura Grove":    "res://assets/icons/modifiers/tree_sakura_thick.png",

	"Elder Grove":           "res://assets/icons/modifiers/tree_elder.png",
	"Thick Elder Grove":     "res://assets/icons/modifiers/tree_elder_thick.png",

	"Ivy Grove":             "res://assets/icons/modifiers/tree_ivy.png",
	"Thick Ivy Grove":       "res://assets/icons/modifiers/tree_ivy_thick.png",

	"Baobab Grove":          "res://assets/icons/modifiers/tree_baobab.png",
	"Palm Grove":            "res://assets/icons/modifiers/tree_palm.png",
}

const FISHING_SPAWN_NAME_TO_ICON := {
	"Riverbank Shallows":     "res://assets/icons/modifiers/fishing_n1_riverbank_shallows.png",
	"Minnow Ford Pool":       "res://assets/icons/modifiers/fishing_r1_minnow_ford_pool.png",

	"Rocky Estuary Bank":     "res://assets/items/Fishing/fishing_n2_rocky_estuary_nets.png",
	"Brackwater Channel":     "res://assets/items/Fishing/fishing_r2_brackwater_channel.png",

	"Sinkhole Plunge Pool":   "res://assets/items/Fishing/fishing_r3_sinkhole_plunge_pool.png",

	"Cascade Shelf Nets":     "res://assets/items/Fishing/fishing_n4_cascade_shelf_nets.png",
	"Echofall Basin":         "res://assets/items/Fishing/fishing_r4_echofall_basin.png",

	"Oxbow Bend Pool":        "res://assets/items/Fishing/fishing_r5_oxbow_bend_pool.png",
	"Leviathan Channel":      "res://assets/items/Fishing/fishing_h5_leviathan_channel.png",

	"Chasm Surge Run":        "res://assets/items/Fishing/fishing_h6_chasm_surge_run.png",

	"Hanging Oasis Nets":     "res://assets/items/Fishing/fishing_n7_hanging_oasis_nets.png",
	"Skywell Sink":           "res://assets/items/Fishing/fishing_h7_skywell_sink.png",

	"Ice-Crack Nets":         "res://assets/items/Fishing/fishing_n8_ice_crack_nets.png",

	"Boiling Runoff Nets":    "res://assets/items/Fishing/fishing_n9_boiling_runoff_nets.png",
	"Geyser Cone Pool":       "res://assets/items/Fishing/fishing_r9_geyser_cone_pool.png",
	"Steamvent Pit":          "res://assets/items/Fishing/fishing_h9_steamvent_pit.png",

	"Abyssal Star Trench":    "res://assets/items/Fishing/fishing_h10_abyssal_star_trench.png",
}

# Herbalism patches by PATCH ID.
# Important: keys are plain Strings, not StringName, so loaded/saved dictionaries match reliably.
const HERBALISM_PATCH_ID_TO_ICON := {
	# Cooking band
	"forest_thyme_plot":                         "res://assets/icons/modifiers/herb_greenveil_patch.png",
	"maplewood_vale_sage_plot":                  "res://assets/icons/modifiers/herb_maplefold_patch.png",
	"silkwood_fennel_ring":                      "res://assets/icons/modifiers/herb_silkshade_patch.png",
	"cloudpine_terraces_rosemary_bed":           "res://assets/icons/modifiers/herb_cloudpine_patch.png",
	"baobab_savanna_lemongrass_patch":           "res://assets/icons/modifiers/herb_baobab_patch.png",
	"rainforest_highwood_ginger_canopy":         "res://assets/icons/modifiers/herb_highwood_patch.png",
	"incense_groves_coriander_scrub":            "res://assets/icons/modifiers/herb_incense_patch.png",
	"boreal_ridge_juniper_bed":                  "res://assets/icons/modifiers/herb_boreal_patch.png",
	"ashfield_cinderwood_oregano_patch":         "res://assets/icons/modifiers/herb_cinder_patch.png",
	"celestial_grove_star_anise_scar":           "res://assets/icons/modifiers/herb_starbloom_patch.png",

	# Chemical band
	"river_marshmallow_root_reeds":              "res://assets/icons/modifiers/herb_reedrun_patch.png",
	"rocky_estuary_sea_wormwood_reeds":          "res://assets/icons/modifiers/herb_brineback_patch.png",
	"cenote_sinkholes_gotu_kola_ledge":          "res://assets/icons/modifiers/herb_sinkbloom_patch.png",
	"karst_cascade_gorge_water_hemlock_shelf":   "res://assets/icons/modifiers/herb_echofall_patch.png",
	"floodplain_bittersweet_nightshade_channel": "res://assets/icons/modifiers/herb_lotusbank_patch.png",
	"river_gorge_valerian_shelf":                "res://assets/icons/modifiers/herb_mistshelf_patch.png",
	"floating_oasis_aloe_garden":                "res://assets/icons/modifiers/herb_skywell_patch.png",
	"frozen_tarn_frost_kava_ledge":              "res://assets/icons/modifiers/herb_frostlip_patch.png",
	"drakefire_geyser_datura_beds":              "res://assets/icons/modifiers/herb_steamroot_patch.png",
	"starsea_rift_bladderwrack_kelpfield":       "res://assets/icons/modifiers/herb_starkelp_patch.png",

	# Fibre band
	"stoneedge_flax_verge":                      "res://assets/icons/modifiers/herb_stoneedge_patch.png",
	"ochreshelf_silk_cocoon_beds":               "res://assets/icons/modifiers/herb_ochreshelf_patch.png",
	"caprock_cotton_tufts":                      "res://assets/icons/modifiers/herb_caprock_patch.png",
	"pitchcap_hemp_caps":                        "res://assets/icons/modifiers/herb_pitchcap_patch.png",
}

# Herbalism patches by exact NAME.
const HERBALISM_PATCH_NAME_TO_ICON := {
	# Cooking band
	"Forest Thyme Plot":                         "res://assets/icons/modifiers/herb_greenveil_patch.png",
	"Maplewood Vale Sage Plot":                  "res://assets/icons/modifiers/herb_maplefold_patch.png",
	"Silkwood Fennel Ring":                      "res://assets/icons/modifiers/herb_silkshade_patch.png",
	"Cloudpine Terraces Rosemary Bed":           "res://assets/icons/modifiers/herb_cloudpine_patch.png",
	"Baobab Savanna Lemongrass Patch":           "res://assets/icons/modifiers/herb_baobab_patch.png",
	"Rainforest Highwood Ginger Canopy":         "res://assets/icons/modifiers/herb_highwood_patch.png",
	"Incense Groves Coriander Scrub":            "res://assets/icons/modifiers/herb_incense_patch.png",
	"Boreal Ridge Juniper Bed":                  "res://assets/icons/modifiers/herb_boreal_patch.png",
	"Ashfield Cinderwood Oregano Patch":         "res://assets/icons/modifiers/herb_cinder_patch.png",
	"Celestial Grove Star Anise Scar":           "res://assets/icons/modifiers/herb_starbloom_patch.png",

	# Chemical band
	"River Marshmallow Root Reeds":              "res://assets/icons/modifiers/herb_reedrun_patch.png",
	"Rocky Estuary Sea Wormwood Reeds":          "res://assets/icons/modifiers/herb_brineback_patch.png",
	"Cenote Sinkholes Gotu Kola Ledge":          "res://assets/icons/modifiers/herb_sinkbloom_patch.png",
	"Karst Cascade Gorge Water Hemlock Shelf":   "res://assets/icons/modifiers/herb_echofall_patch.png",
	"Floodplain Bittersweet Nightshade Channel": "res://assets/icons/modifiers/herb_lotusbank_patch.png",
	"River Gorge Valerian Shelf":                "res://assets/icons/modifiers/herb_mistshelf_patch.png",
	"Floating Oasis Aloe Garden":                "res://assets/icons/modifiers/herb_skywell_patch.png",
	"Frozen Tarn Frost Kava Ledge":              "res://assets/icons/modifiers/herb_frostlip_patch.png",
	"Drakefire Geyser Datura Beds":              "res://assets/icons/modifiers/herb_steamroot_patch.png",
	"Starsea Rift Bladderwrack Kelpfield":       "res://assets/icons/modifiers/herb_starkelp_patch.png",

	# Fibre band
	"Stoneedge Flax Verge":                      "res://assets/icons/modifiers/herb_stoneedge_patch.png",
	"Ochreshelf Silk Cocoon Beds":               "res://assets/icons/modifiers/herb_ochreshelf_patch.png",
	"Caprock Cotton Tufts":                      "res://assets/icons/modifiers/herb_caprock_patch.png",
	"Pitchcap Hemp Caps":                        "res://assets/icons/modifiers/herb_pitchcap_patch.png",
}

# ===================================================
# Lifecycle
# ===================================================

func _ready() -> void:
	_build_hex()

	if area != null:
		area.input_pickable = true
		if not area.input_event.is_connected(_on_area_input_event):
			area.input_event.connect(_on_area_input_event)

	if label != null:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if colpoly != null:
		colpoly.disabled = false

	if mod_icons_root != null:
		mod_icons_root.z_index = 50

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

func _resolve_resource_spawn_icon(name: String, skill: String, md: Dictionary) -> String:
	match skill:
		"mining":
			return String(MINING_SPAWN_NAME_TO_ICON.get(name, MOD_SKILL_ICON_PATHS["mining"]))

		"woodcutting":
			return String(WOODCUTTING_SPAWN_NAME_TO_ICON.get(name, MOD_SKILL_ICON_PATHS["woodcutting"]))

		"fishing":
			return String(FISHING_SPAWN_NAME_TO_ICON.get(name, MOD_SKILL_ICON_PATHS["fishing"]))

		"herbalism":
			return _resolve_herbalism_spawn_icon(name, md)

		_:
			if MOD_SKILL_ICON_PATHS.has(skill):
				return String(MOD_SKILL_ICON_PATHS[skill])
			return ""

func _resolve_herbalism_spawn_icon(name: String, md: Dictionary) -> String:
	# 1) Prefer any available ID-like field.
	# This prevents the one-frame/default-icon problem when name labels are not final yet.
	var id_fields := [
		"id",
		"patch_id",
		"node_id",
		"resource_id",
		"spawn_id",
	]

	for field in id_fields:
		if md.has(field):
			var id_key := _slug_key(String(md.get(field, "")))
			if id_key != "" and HERBALISM_PATCH_ID_TO_ICON.has(id_key):
				return String(HERBALISM_PATCH_ID_TO_ICON[id_key])

	# 2) Exact display-name match.
	if HERBALISM_PATCH_NAME_TO_ICON.has(name):
		return String(HERBALISM_PATCH_NAME_TO_ICON[name])

	# 3) Normalized display-name match.
	var normalized_name_icon: Variant = _dict_get_norm(HERBALISM_PATCH_NAME_TO_ICON, name)
	if normalized_name_icon != null:
		return String(normalized_name_icon)

	# 4) Slugged display-name match against ID table.
	var name_slug := _slug_key(name)
	if name_slug != "" and HERBALISM_PATCH_ID_TO_ICON.has(name_slug):
		return String(HERBALISM_PATCH_ID_TO_ICON[name_slug])

	# 5) Backstop: if the name contains one of the known patch names, use that.
	# This helps if UI text becomes "Forest Thyme Plot [herbalism]" or similar.
	var name_norm := _norm_key(name)
	for patch_name in HERBALISM_PATCH_NAME_TO_ICON.keys():
		var patch_norm := _norm_key(String(patch_name))
		if patch_norm != "" and name_norm.find(patch_norm) != -1:
			return String(HERBALISM_PATCH_NAME_TO_ICON[patch_name])

	# 6) Final fallback: generic Herbalism icon.
	return String(MOD_SKILL_ICON_PATHS["herbalism"])

func _get_modifier_icon_scale(name: String, kind: String, icon_path: String) -> float:
	var scale_key := name if name != "" else kind
	if MOD_ICON_SCALE_OVERRIDES_BY_NAME.has(scale_key):
		return float(MOD_ICON_SCALE_OVERRIDES_BY_NAME[scale_key])
	if MOD_ICON_SCALE_OVERRIDES_BY_PATH.has(icon_path):
		return float(MOD_ICON_SCALE_OVERRIDES_BY_PATH[icon_path])
	return 1.0

func _norm_key(s: String) -> String:
	var t := s.strip_edges().to_lower()
	t = t.replace("_", " ")
	t = t.replace("-", " ")

	# Normalize slash spacing so "Dungeon/Delve" matches "Dungeon / Delve".
	t = t.replace(" / ", "/")
	t = t.replace(" /", "/")
	t = t.replace("/ ", "/")

	while t.find("  ") != -1:
		t = t.replace("  ", " ")

	return t

func _slug_key(s: String) -> String:
	var t := s.strip_edges().to_lower()

	t = t.replace("’", "")
	t = t.replace("'", "")
	t = t.replace("\"", "")
	t = t.replace(":", "")
	t = t.replace(";", "")
	t = t.replace(",", "")
	t = t.replace(".", "")
	t = t.replace("(", "")
	t = t.replace(")", "")
	t = t.replace("[", "")
	t = t.replace("]", "")
	t = t.replace("{", "")
	t = t.replace("}", "")
	t = t.replace("&", "and")

	t = t.replace("/", "_")
	t = t.replace("\\", "_")
	t = t.replace("-", "_")
	t = t.replace(" ", "_")

	while t.find("__") != -1:
		t = t.replace("__", "_")

	while t.begins_with("_"):
		t = t.substr(1)

	while t.ends_with("_"):
		t = t.substr(0, t.length() - 1)

	return t

func _dict_get_norm(d: Dictionary, key: String) -> Variant:
	var nk := _norm_key(key)
	for k in d.keys():
		if _norm_key(String(k)) == nk:
			return d[k]
	return null

func _split_kind_and_skill(kind_raw: String, skill_raw: String) -> Dictionary:
	var kind := kind_raw.strip_edges()
	var skill := skill_raw.strip_edges().to_lower()

	# Support "Resource Spawn [mining]" stored in kind.
	var open := kind.find("[")
	if open != -1:
		var close := kind.find("]", open + 1)
		if close != -1:
			if skill == "":
				skill = kind.substr(open + 1, close - open - 1).strip_edges().to_lower()
			kind = kind.substr(0, open).strip_edges()

	return {"kind": kind, "skill": skill}

func _update_modifier_icons() -> void:
	if mod_icons_root == null:
		return

	var slots := _get_mod_icon_sprites()
	if slots.is_empty():
		return

	for slot in slots:
		slot.texture = null
		slot.visible = false
		slot.scale = Vector2.ONE

	if modifiers.is_empty():
		return

	var icon_idx := 0

	for m in modifiers:
		if icon_idx >= slots.size():
			break

		var md: Dictionary = m

		var kind_raw: String  = String(md.get("kind", "")).strip_edges()
		var skill_raw: String = String(md.get("skill", "")).strip_edges()

		var ks := _split_kind_and_skill(kind_raw, skill_raw)
		var kind: String  = String(ks["kind"])
		var skill: String = String(ks["skill"])

		var name: String = String(md.get("name", md.get("detail", ""))).strip_edges()

		var icon_path := ""

		if _norm_key(kind) == "resource spawn":
			icon_path = _resolve_resource_spawn_icon(name, skill, md)

		if icon_path == "":
			var v: Variant = _dict_get_norm(MOD_KIND_ICON_PATHS, kind)
			if v != null:
				icon_path = String(v)

		if icon_path == "" and skill != "":
			var v2: Variant = _dict_get_norm(MOD_SKILL_ICON_PATHS, skill)
			if v2 != null:
				icon_path = String(v2)

		if icon_path == "":
			continue

		var tex := load(icon_path) as Texture2D
		if tex == null:
			push_warning("[Fragment] Failed to load modifier icon: %s | kind=%s skill=%s name=%s" % [
				icon_path,
				kind,
				skill,
				name,
			])
			continue

		slots[icon_idx].texture = tex

		var max_dim: float = float(max(tex.get_width(), tex.get_height()))
		if max_dim > 0.0:
			var scale_factor: float = MOD_ICON_MAX_SIZE / max_dim
			var scale_override: float = _get_modifier_icon_scale(name, kind, icon_path)
			slots[icon_idx].scale = Vector2.ONE * scale_factor * scale_override

		slots[icon_idx].visible = true
		icon_idx += 1

func get_modifier_lines() -> Array[String]:
	var out: Array[String] = []

	for m in modifiers:
		if typeof(m) != TYPE_DICTIONARY:
			continue

		var md: Dictionary = m
		var kind: String  = String(md.get("kind", "")).strip_edges()
		var skill: String = String(md.get("skill", "")).strip_edges()
		var name: String  = String(md.get("name", md.get("detail", ""))).strip_edges()

		if kind == "Resource Spawn" and skill != "":
			out.append("%s [%s]" % [name, skill])
		else:
			out.append(name if name != "" else kind)

	return out

func set_local_modifiers(mods: Array) -> void:
	var typed: Array[Dictionary] = []

	for m in mods:
		var md := _modifier_to_dict(m)
		if not md.is_empty():
			typed.append(md)

	modifiers = typed
	_update_modifier_icons()

# ===================================================
# Setup
# ===================================================

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

	if not meta.is_empty():
		if meta.has("tier"):
			tier = int(meta["tier"])

		if meta.has("region"):
			region = String(meta["region"])

		if meta.has("modifiers"):
			var arr: Variant = meta["modifiers"]
			if arr is Array:
				var typed: Array[Dictionary] = []
				for v in (arr as Array):
					var md := _modifier_to_dict(v)
					if not md.is_empty():
						typed.append(md)
				modifiers = typed

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
		var world := get_tree().get_first_node_in_group("World")

		if world != null:
			var v_idx: int = -1

			if world.has_method("villager_on_tile"):
				v_idx = world.call("villager_on_tile", coord)

			if v_idx >= 0 and typeof(DragState) != TYPE_NIL and DragState.has_method("begin"):
				DragState.begin(v_idx)

		clicked.emit(self)
		get_viewport().set_input_as_handled()

func _modifier_to_dict(m: Variant) -> Dictionary:
	if typeof(m) == TYPE_DICTIONARY:
		var copied: Dictionary = (m as Dictionary).duplicate(true)

		# Normalize common saved variants.
		if copied.has("detail") and not copied.has("name"):
			copied["name"] = String(copied["detail"])

		if copied.has("skill"):
			copied["skill"] = String(copied["skill"]).strip_edges().to_lower()

		if copied.has("kind"):
			copied["kind"] = String(copied["kind"]).strip_edges()

		return copied

	if typeof(m) != TYPE_STRING:
		return {}

	var mod_str: String = String(m)
	var header: String = mod_str
	var detail: String = ""

	var parts := mod_str.split(": ", false, 2)
	if parts.size() > 0:
		header = parts[0]
	if parts.size() > 1:
		detail = parts[1]

	var kind_base := header
	var skill_id := ""

	var open_idx := header.find("[")
	if open_idx != -1:
		var close_idx := header.find("]", open_idx + 1)
		if close_idx != -1:
			kind_base = header.substr(0, open_idx).strip_edges()
			skill_id = header.substr(open_idx + 1, close_idx - open_idx - 1).strip_edges().to_lower()

	var out := {
		"kind": kind_base.strip_edges(),
		"skill": skill_id,
		"name": detail.strip_edges(),
		"rarity": "",
	}

	# Important fallback for legacy string modifiers:
	# "Resource Spawn [herbalism]: Forest Thyme Plot" now gets a usable slug id.
	if skill_id == "herbalism" and detail.strip_edges() != "":
		var slug := _slug_key(detail)
		if HERBALISM_PATCH_ID_TO_ICON.has(slug):
			out["id"] = slug

	return out

func get_recruited_villager_idx() -> int:
	return recruited_villager_idx

# ===================================================
# Recruit helpers
# ===================================================

func has_recruit_modifier() -> bool:
	for d in modifiers:
		var kind := String(d.get("kind", ""))
		if kind == "Recruit Event":
			return true

	return false

func get_recruit_source_name() -> String:
	for d in modifiers:
		var kind := String(d.get("kind", ""))
		if kind == "Recruit Event":
			return String(d.get("name", ""))

	return ""

func try_trigger_recruit() -> void:
	if recruit_triggered:
		return

	if not has_recruit_modifier():
		return

	if typeof(Villagers) == TYPE_NIL:
		return

	if not Villagers.has_method("auto_recruit_from_biome"):
		return

	var v_idx: int = int(Villagers.auto_recruit_from_biome(biome))

	if v_idx >= 0:
		recruited_villager_idx = v_idx

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

		var max_dim: float = float(max(tex.get_width(), tex.get_height()))
		if max_dim > 0.0:
			var target_px: float = HEX_SIZE * 1.0
			var scale_factor: float = target_px / max_dim

			if biome == "River":
				scale_factor *= 0.65

			biome_icon.scale = Vector2(scale_factor, scale_factor)
	else:
		biome_icon.texture = null
		biome_icon.visible = false

func _biome_color(b: String) -> Color:
	match b:
		"Hamlet":
			return Color(0.455, 0.537, 0.667, 1.0)
		"Mountain":
			return Color(0.545, 0.561, 0.631, 1.0)
		"Forest":
			return Color(0.180, 0.490, 0.196, 1.0)
		"River":
			return Color(0.118, 0.533, 0.898, 1.0)
		"Maplewood Vale":
			return Color(0.816, 0.506, 0.235, 1.0)
		"Rocky Estuary":
			return Color(0.310, 0.486, 0.482, 1.0)
		"Foothill Valleys":
			return Color(0.557, 0.616, 0.302, 1.0)
		"Silkwood":
			return Color(0.431, 0.310, 0.639, 1.0)
		"Cenote Sinkholes":
			return Color(0.122, 0.620, 0.588, 1.0)
		"Painted Canyon":
			return Color(0.851, 0.369, 0.255, 1.0)
		"Cloudpine Terraces":
			return Color(0.494, 0.776, 0.890, 1.0)
		"Karst Cascade Gorge":
			return Color(0.369, 0.478, 0.549, 1.0)
		"Deep Underground Mines":
			return Color(0.420, 0.420, 0.470, 1.0)
		"Baobab Savanna":
			return Color(0.851, 0.761, 0.451, 1.0)
		"Floodplain":
			return Color(0.373, 0.655, 0.412, 1.0)
		"Rift Valley":
			return Color(0.706, 0.541, 0.353, 1.0)
		"Rainforest Highwood":
			return Color(0.118, 0.435, 0.302, 1.0)
		"River Gorge":
			return Color(0.082, 0.396, 0.753, 1.0)
		"Mesas":
			return Color(0.761, 0.431, 0.239, 1.0)
		"Incense Groves":
			return Color(0.663, 0.510, 0.741, 1.0)
		"Floating Oasis":
			return Color(0.200, 0.725, 0.776, 1.0)
		"Salt Dome Escarpments":
			return Color(0.878, 0.839, 0.769, 1.0)
		"Boreal Ridge":
			return Color(0.200, 0.361, 0.435, 1.0)
		"Frozen Tarn":
			return Color(0.561, 0.816, 0.910, 1.0)
		"Permafrost Steppe":
			return Color(0.784, 0.831, 0.847, 1.0)
		"Ashfield Cinderwood":
			return Color(0.353, 0.227, 0.200, 1.0)
		"Drakefire Geyser Basin":
			return Color(0.941, 0.431, 0.235, 1.0)
		"Magmaforge Undercaverns":
			return Color(0.502, 0.188, 0.290, 1.0)
		"Celestial Grove":
			return Color(0.361, 0.604, 0.784, 1.0)
		"Starsea Rift":
			return Color(0.235, 0.239, 0.569, 1.0)
		"Void Scar":
			return Color(0.133, 0.106, 0.227, 1.0)
		_:
			return Color(0.55, 0.55, 0.55, 1.0)

# ===================================================
# World bindings
# ===================================================

func get_local_effects_summary() -> String:
	var parts: Array[String] = []

	if biome == "Hamlet":
		parts.append("Home fragment")

	if is_anchored():
		parts.append("Anchored")

	var bound_name: String = get_bound_villager_name()
	if bound_name != "":
		if typeof(Villagers) != TYPE_NIL \
		and Villagers.has_method("get_founder_id") \
		and get_bound_villager_id() == Villagers.get_founder_id():
			parts.append("Founder bound: %s" % bound_name)
		else:
			parts.append("Bound villager: %s" % bound_name)

	if has_meta("building_id"):
		var base_id := String(get_meta("building_id"))
		if base_id != "":
			parts.append("Building: %s" % base_id)

			if has_meta("building_modules"):
				var mvar: Variant = get_meta("building_modules")
				if mvar is Array:
					var module_labels: Array[String] = []

					for mm in (mvar as Array):
						var s := String(mm)
						if s != "":
							module_labels.append(s)

					if not module_labels.is_empty():
						parts.append("Modules: " + ", ".join(module_labels))

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
