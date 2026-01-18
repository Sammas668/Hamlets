# World.gd
extends Node2D

const TILE_SCENE: PackedScene = preload("res://scenes/Fragment.tscn")

@onready var fragments_root: Node2D       = $Fragments
@onready var cam: Camera2D                = $Cam

@onready var essence_label: Label = get_node_or_null("CanvasLayer/Panel/EssenceLabel") as Label
@onready var summon_button: Button = get_node_or_null("CanvasLayer/Panel/SummonButton") as Button
@onready var selection_hud: Control = get_node_or_null("CanvasLayer/SelectionHUD") as Control

# Pause / overlays (all null-safe)
@onready var pause_menu: Node             = get_node_or_null("CanvasLayer/Panel/EscMenu")
@onready var dim_pause: ColorRect         = get_node_or_null("CanvasLayer/Panel/DimPause") as ColorRect
@onready var save_panel: PanelContainer   = get_node_or_null("CanvasLayer/Panel/SavePanel") as PanelContainer
@onready var load_panel: PanelContainer   = get_node_or_null("CanvasLayer/Panel/LoadPanel") as PanelContainer
@onready var settings_panel: PanelContainer = get_node_or_null("CanvasLayer/Panel/SettingsPanel") as PanelContainer

# Camera / zoom
var is_dragging: bool = false
const DRAG_BUTTON := MOUSE_BUTTON_RIGHT
const ZOOM_STEP  := 0.1
const MIN_ZOOM   := 0.5
const MAX_ZOOM   := 3.0

const SELECTION_HUD_OFFSET: Vector2 = Vector2(24.0, -24.0)

const TASK_PICKER_SCENE: PackedScene = preload("res://ui/TaskPicker.tscn")

# Hex layout (pointy-top) — keep in sync with Fragment.gd
const HEX_SIZE: float = 60.0
const SQRT3: float = 1.7320508075688772
# RNG
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
# --- Worker overlays on tiles ---
@export var worker_icon_texture: Texture2D

# ax:Vector2i -> v_idx:int (only one worker per tile)
var _tile_worker_by_ax: Dictionary = {}

# v_idx:int -> icon Node2D (so we can free/move it)
var _worker_icon_by_v: Dictionary = {}

# Drag ghost (villager icon following the mouse while dragging)
var _drag_ghost: Node2D = null
var _drag_ghost_v_idx: int = -1


# Shards that can be spent to summon new Fragments (Astromancy outputs)
# Shard → rank mapping (Astromancy shards defined in Items.gd)
const SHARD_RANK: Dictionary = {
	Items.R1_PLAIN: 1,
	Items.R2_PLAIN: 2,
	Items.R3_PLAIN: 3,
	Items.R4_PLAIN: 4,
	Items.R5_PLAIN: 5,
	Items.R6_PLAIN: 6,
	Items.R7_PLAIN: 7,
	Items.R8_PLAIN: 8,
	Items.R9_PLAIN: 9,
	Items.R10_PLAIN: 10,
}

func get_modifiers_at(ax: Vector2i) -> Array:
	for c in fragments_root.get_children():
		var coord_v: Variant = c.get("coord")
		if coord_v is Vector2i and coord_v == ax:
			# Try Fragment-style access first
			if c is Fragment:
				var frag := c as Fragment
				var mods_v: Variant = frag.get("modifiers")
				if mods_v is Array:
					return mods_v
				# Fallback for older script versions
				mods_v = frag.get("local_modifiers")
				if mods_v is Array:
					return mods_v

			# Generic node path: look for a "modifiers" property
			var mods2_v: Variant = c.get("modifiers")
			if mods2_v is Array:
				return mods2_v

	return []


# Biome table by rank (R1–R10) from Biome Summary Table
const BIOMES_BY_RANK: Dictionary = {
	1: [
		"Mountain",
		"Forest",
		"River",
	],
	2: [
		"Maplewood Vale",
		"Rocky Estuary",
		"Foothill Valleys",
	],
	3: [
		"Silkwood",
		"Cenote Sinkholes",
		"Painted Canyon",
	],
	4: [
		"Cloudpine Terraces",
		"Karst Cascade Gorge",
		"Painted Talus Mines",
	],
	5: [
		"Baobab Savanna",
		"Floodplain",
		"Rift Valley",
	],
	6: [
		"Rainforest Highwood",
		"River Gorge",
		"Mesas",
	],
	7: [
		"Incense Groves",
		"Floating Oasis",
		"Salt Dome Escarpments",
	],
	8: [
		"Boreal Ridge",
		"Frozen Tarn",
		"Permafrost Steppe",
	],
	9: [
		"Ashfield Cinderwood",
		"Drakefire Geyser Basin",
		"Magmaforge Undercaverns",
	],
	10: [
		"Celestial Grove",
		"Starsea Rift",
		"Void Scar",
	],
}

# How many modifiers max, by Astromancy level
const ASTRO_MOD_CAP_BY_LEVEL := {
	1: 1,
	20: 2,
	40: 3,
	60: 4,
	80: 5,
}

# Simple mapping from rarity -> weight
const MOD_RARITY_WEIGHT := {
	"Common": 3,
	"Uncommon": 2,
	"Rare": 1,
}

# Per-biome modifier pools (Tier 1–3 fully filled out).
# Keys MUST match your biome names from the Biome Summary Table.

const BIOME_MODIFIERS := {
	# -------------------------
	# Tier 1 — Local Frontier (R1)
	# -------------------------

	# 1. Mountain (Hill Dwarf, Mining)
	"Mountain": [
		{ "name": "Hillstead Quarry Camp", "kind": "Recruit Event",   "rarity": "Rare" },
		{ "name": "Boundary Stone Ring",   "kind": "Structure",       "rarity": "Uncommon" },

		# Resource spawns
		{ "name": "Exposed Limestone Face","kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Copper Vein",           "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Tin Vein",              "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },

		# ✅ T1 mining-biome herb patch (tailoring fibre band)
		{ "name": "Stoneedge Cragweave Beds", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Deep Warrens",          "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Loose Scree Slope",     "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 2. Forest (Wood Elf, Woodcutting)
	"Forest": [
		{ "name": "Grove-Warden Encampment","kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Pine Grove",            "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Pine Grove",      "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "woodcutting" },
		{ "name": "Exposed Limestone Face","kind": "Resource Spawn",  "rarity": "Rare",     "skill": "mining" },
		{ "name": "Surface Copper Vein",   "kind": "Resource Spawn",  "rarity": "Rare",     "skill": "mining" },

		# ✅ T1 woodcutting-biome herb patch (cooking herb)
		{ "name": "Greenveil Forestglade", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Hollow Log Den",        "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Shrine of Growth",      "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Forester’s Cache",      "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Briar Tangle",          "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 3. River (Naiad, Fishing)
	"River": [
		{ "name": "Naiad Jetty",           "kind": "Recruit Event",   "rarity": "Rare" },

		# F1 fishing nodes
		{ "name": "Riverbank Shallows",    "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" }, # N1
		{ "name": "Minnow Ford Pool",      "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" }, # R1

		{ "name": "Surface Tin Vein",      "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },
		{ "name": "Willow Grove",          "kind": "Resource Spawn",  "rarity": "Rare",     "skill": "woodcutting" },

		# ✅ T1 fishing-biome herb patch (chemical herb)
		{ "name": "Reedrun Riverbank Reeds", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Abandoned Den",         "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Waterside Shrine",      "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Slick Stones",          "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 2 — Settled Lowlands (R2)
	# -------------------------

	# 1. Maplewood Vale (Dryad-born, Woodcutting)
	"Maplewood Vale": [
		{ "name": "Orchard-Tender Camp",   "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Maple Grove",           "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Willow Grove",          "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Willow Grove",    "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "woodcutting" },

		# Secondary early fishing
		{ "name": "Minnow Ford Pool",      "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "fishing" }, # R1

		# ✅ T2 woodcutting-biome herb patch (cooking herb)
		{ "name": "Maplefold Vale Understory", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Old Root Cellar",       "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Wayside Shrine",        "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Morning Fog Hollow",    "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 2. Rocky Estuary (Triton, Fishing)
	"Rocky Estuary": [
		{ "name": "Triton Tidal Camp",     "kind": "Recruit Event",   "rarity": "Rare" },

		# F2 fishing nodes
		{ "name": "Rocky Estuary Bank",    "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" }, # N2
		{ "name": "Brackwater Channel",    "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" }, # R2

		{ "name": "Claybank Exposure",     "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },
		{ "name": "Sandstone Shelf",       "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },

		# ✅ T2 fishing-biome herb patch (chemical herb)
		{ "name": "Brineback Estuary Saltbeds", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Wrecked Keel",          "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Beacon Pile",           "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Spring Tide Surge",     "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 3. Foothill Valleys (Kobold, Mining)
	"Foothill Valleys": [
		{ "name": "Kobold Prospector Camp","kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Copper Vein",           "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Tin Vein",              "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Iron Seam",             "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Coal Seam",             "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Limestone Cutface",     "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },
		{ "name": "Claybank Exposure",     "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T2 mining-biome herb patch (tailoring fibre band)
		{ "name": "Tanninbush Foothill Thicket", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Abandoned Adit",        "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Survey Cairn",          "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Unstable Spoil Pile",   "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 3 — Frontier Biomes (R3)
	# -------------------------

	# 1. Silkwood (Ratfolk, Woodcutting)
	"Silkwood": [
		{ "name": "Ratfolk Loom-Camp",     "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Oakwood Grove",         "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Oakwood Grove",   "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },

		# ✅ T3 woodcutting-biome herb patch (cooking herb)
		{ "name": "Silkshade Canopy Beds", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Warren Hollow",         "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Charm-Strung Shrine",   "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Webbed Underbrush",     "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 2. Cenote Sinkholes (Serpentfolk, Fishing)
	"Cenote Sinkholes": [
		{ "name": "Serpent Diver Camp",    "kind": "Recruit Event",   "rarity": "Rare" },

		# F3 fishing node
		{ "name": "Sinkhole Plunge Pool",  "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },

		{ "name": "Ivy Grove",             "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },

		# ✅ T3 fishing-biome herb patch (chemical herb)
		{ "name": "Sinkbloom Cenote Bloomring", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Submerged Cave Grotto", "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Cenote Offering Shrine","kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Crumbly Sink Rim",      "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 3. Painted Canyon (Goblin, Mining)
	"Painted Canyon": [
		{ "name": "Goblin Shelf Camp",     "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Iron Seam",             "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Sandstone Shelf",       "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Lesser Gem Geode",      "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T3 mining-biome herb patch (tailoring fibre band)
		{ "name": "Ochreshelf Canyon Fibreflats", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Smuggler’s Bolt-Hole",  "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Painted Marker Totems", "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Crumbly Hoodoo Ridge",  "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 4 — High Slopes (R4)
	# -------------------------

	# 1. Cloudpine Terraces (Rock Gnome, Woodcutting)
	"Cloudpine Terraces": [
		{ "name": "Gnome Terrace Hamlet",  "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Willow Grove",          "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Willow Grove",    "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Pine Grove",            "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Pine Grove",      "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "woodcutting" },

		# ✅ T4 woodcutting-biome herb patch (cooking herb)
		{ "name": "Cloudpine Terrace Needlebed", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Terrace Burrow",        "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Hillside Waystone",     "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Muddy Switchback",      "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 2. Karst Cascade Gorge (Halfling, Fishing)
	"Karst Cascade Gorge": [
		{ "name": "Halfling Mill-Bridge",  "kind": "Recruit Event",   "rarity": "Rare" },

		# F4 fishing nodes
		{ "name": "Cascade Shelf Nets",    "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },
		{ "name": "Echofall Basin",        "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },

		{ "name": "Lesser Gem Geode",      "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T4 fishing-biome herb patch (chemical herb)
		{ "name": "Echofall Sprayroot Ledge", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Flooded Cavern",        "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Overlook Shrine",       "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Flash-Flood Channel",   "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 3. Deep Underground Mines (Deep Dwarf, Mining)
	"Deep Underground Mines": [
		{ "name": "Duergar Mine Ramp",     "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Iron Seam",             "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Silver Vein",           "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },
		{ "name": "Lesser Gem Geode",      "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T4 mining-biome herb patch (tailoring fibre band)
		{ "name": "Ironmoss Talus Mats", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Collapsed Drift Tunnel","kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Survey Obelisk",        "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Shifting Talus Chute",  "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 5 — African Heartlands (R5)
	# -------------------------

	# 1. Baobab Savanna (Half-Orc, Woodcutting)
	"Baobab Savanna": [
		{ "name": "Half-Orc Logging Kraal","kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Baobab Grove",          "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Maple Grove",           "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Maple Grove",     "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },

		# ✅ T5 woodcutting-biome herb patch (cooking herb)
		{ "name": "Baobab Sunleaf Flats", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Oxbow Bend Pool",       "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "fishing" },

		{ "name": "Predator Koppie",       "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Ancestor Cairn Circle", "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Grassfire Front",       "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 2. Floodplain (Half-Elf, Fishing)
	"Floodplain": [
		{ "name": "Half-Elf Reed-Boat Camp","kind": "Recruit Event",  "rarity": "Rare" },

		{ "name": "Oxbow Bend Pool",       "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },
		{ "name": "Leviathan Channel",     "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },

		# ✅ T5 fishing-biome herb patch (chemical herb)
		{ "name": "Lotusbank Floodplain Pools", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Hidden Hippo Path",     "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "River Spirit Marker",   "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Seasonal Inundation",   "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# 3. Rift Valley (Changeling, Mining)
	"Rift Valley": [
		{ "name": "Changeling Switchback Camp","kind": "Recruit Event","rarity": "Rare" },

		{ "name": "Basalt Quarry",         "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Rift Ore Ledge",        "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Gold Vein",             "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },
		{ "name": "Precious Gem Geode",    "kind": "Resource Spawn",  "rarity": "Rare",     "skill": "mining" },
		{ "name": "Opaline Seam",          "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T5 mining-biome herb patch (tailoring fibre band)
		{ "name": "Redroot Riftvine Beds", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Collapsed Rift Tunnel", "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Old Survey Beacon",     "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Rockfall Fault Line",   "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 6 — South American Crownlands (R6)
	# -------------------------

	"Rainforest Highwood": [
		{ "name": "Canopy Lodge",          "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Yew Grove",             "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Yew Grove",       "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },

		# ✅ T6 cooking herb
		{ "name": "Highwood Rain-Thicket", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Canopy Nest Hollow",    "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Rain-Spirit Totem",     "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Quicksink Root Mat",    "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"River Gorge": [
		{ "name": "Forged Winch Station",  "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Chasm Surge Run",       "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },

		# ✅ T6 chemical herb
		{ "name": "Mistshelf Gorge Vaporgrowth", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Mithrite Seam",         "kind": "Resource Spawn",  "rarity": "Rare",     "skill": "mining" },

		{ "name": "Collapsed Bridge Cavern","kind":"Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Cataract Pillar",       "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Sudden Torrent Run",    "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Mesas": [
		{ "name": "Oread Shelf-Camp",      "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Mithrite Seam",         "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Gold Seam",             "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Silver Seam",           "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T6 fibre herb
		{ "name": "Caprock Mesa Cordfields", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Windcleft Crevasse",    "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Sun-Table Waystone",    "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Dustfall Chute",        "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 7 — Desert Threshold (R7)
	# -------------------------

	"Incense Groves": [
		{ "name": "Centaur Incense Caravan","kind":"Recruit Event",   "rarity": "Rare" },

		{ "name": "Ironwood Grove",        "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Ironwood Grove",  "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },

		# ✅ T7 cooking herb
		{ "name": "Incense Grove Resinwalk", "kind": "Resource Spawn", "rarity": "Common", "skill": "herbalism" },

		{ "name": "Mithrite Seam",         "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		{ "name": "Perfumed Cavern",       "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Desert Incense Shrine", "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Mirage Heat-Haze",      "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Floating Oasis": [
		{ "name": "Satyr Pool-Camp",       "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Hanging Oasis Nets",    "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },
		{ "name": "Skywell Sink",          "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },

		{ "name": "Palm Grove",            "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "woodcutting" },

		# ✅ T7 chemical herb
		{ "name": "Skywell Oasis Dewbeds", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Bandit Balcony Hideout","kind":"Dungeon / Delve",  "rarity": "Rare" },
		{ "name": "Oasis Wayhouse",        "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Shimmering Rim",        "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Salt Dome Escarpments": [
		{ "name": "Elephantfolk Salt Quarry","kind":"Recruit Event",  "rarity": "Rare" },

		{ "name": "Granite Face",          "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Adamantite Seam",       "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T7 fibre herb
		{ "name": "Saltbloom Dome Brinefields", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Dome-Heart Cavern",     "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Crystal Survey Stele",  "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Toxic Fumarole Fissure","kind":"Hazard",           "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 8 — High Latitudes (R8)
	# -------------------------

	"Boreal Ridge": [
		{ "name": "Catfolk Ridge Camp",    "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Redwood Grove",         "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Redwood Grove",   "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },

		# ✅ T8 cooking herb
		{ "name": "Boreal Needleheath", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Wolf-Warren Ravine",    "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Aurora Stone",          "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Snow-Laden Slope",      "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Frozen Tarn": [
		{ "name": "Firbolg Ice Camp",      "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Ice-Crack Nets",        "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },

		{ "name": "Ice Geode Outcrop",     "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T8 chemical herb
		{ "name": "Frostlip Tarn Iceleaf Beds", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Subglacial Grotto",     "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Prayer Cairn",          "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Thin Ice Field",        "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Permafrost Steppe": [
		{ "name": "Goliath Quarry Encampment","kind":"Recruit Event", "rarity": "Rare" },

		{ "name": "Permafrost Seam Cut",   "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Frost-Heave Bluff",     "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Blue Clay Lens",        "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		{ "name": "Orichalcum Vein",       "kind": "Resource Spawn",  "rarity": "Rare",     "skill": "mining" },
		{ "name": "Adamantite Vein",       "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T8 fibre herb
		{ "name": "Lichencrust Steppe Threadflats", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Buried Relic Pit",      "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Wind-Altar Monolith",   "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Whiteout Gale Front",   "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 9 — Volcanic / Infernal Threshold (R9)
	# -------------------------

	"Ashfield Cinderwood": [
		{ "name": "Tiefling Ember Camp",   "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Sakura Grove",          "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Sakura Grove",    "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },

		# ✅ T9 cooking herb
		{ "name": "Cinderwood Ashgarden", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Brimstone Crust",       "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		{ "name": "Smouldering Hollow",    "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Cinder Shrine",         "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Ashstorm Front",        "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Drakefire Geyser Basin": [
		{ "name": "Drakekin Ventwatch Post","kind":"Recruit Event",   "rarity": "Rare" },

		{ "name": "Boiling Runoff Nets",   "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },
		{ "name": "Geyser Cone Pool",      "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },
		{ "name": "Steamvent Pit",         "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },

		{ "name": "Marble Shelf",          "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },

		# ✅ T9 chemical herb
		{ "name": "Steamroot Geysergarden", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Steam Tunnel",          "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Geyser Obelisk",        "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Flash-Scald Zone",      "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Magmaforge Undercaverns": [
		{ "name": "Hobgoblin Forge-Redoubt","kind":"Recruit Event",   "rarity": "Rare" },

		{ "name": "Coal Vein",             "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Orichalcum Vein",       "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },
		{ "name": "Basalt Pillar Quarry",  "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Marble Pillar Quarry",  "kind": "Resource Spawn",  "rarity": "Uncommon", "skill": "mining" },
		{ "name": "Rare Gem Geode",        "kind": "Resource Spawn",  "rarity": "Rare",     "skill": "mining" },

		# ✅ T9 fibre herb
		{ "name": "Pitchcap Underforge Caps", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Lava Bridge Delve",     "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "War-Forge Shrine",      "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Gravity-Slip Shaft",    "kind": "Hazard",          "rarity": "Uncommon" },
	],

	# -------------------------
	# Tier 10 — Celestial / Void Boundary (R10)
	# -------------------------

	"Celestial Grove": [
		{ "name": "Gray Elf Halo Enclave", "kind": "Recruit Event",   "rarity": "Rare" },

		{ "name": "Elder Grove",           "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },
		{ "name": "Thick Elder Grove",     "kind": "Resource Spawn",  "rarity": "Common",   "skill": "woodcutting" },

		# ✅ T10 cooking herb
		{ "name": "Starbloom Skymeadow", "kind": "Resource Spawn", "rarity": "Common", "skill": "herbalism" },

		{ "name": "Moonshadow Thicket",    "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Radiant Stone Circle",  "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Fallen Ray Column",     "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Starsea Rift": [
		{ "name": "Minotaur Rift-Anchor Camp","kind":"Recruit Event", "rarity": "Rare" },

		{ "name": "Abyssal Star Trench",   "kind": "Resource Spawn",  "rarity": "Common",   "skill": "fishing" },

		# ✅ T10 chemical herb
		{ "name": "Starkelp Kelpfields", "kind": "Resource Spawn", "rarity": "Uncommon", "skill": "herbalism" },

		{ "name": "Inverted Rain Cavern",  "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Rift Anchor Monolith",  "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Gravity-Tilt Edge",     "kind": "Hazard",          "rarity": "Uncommon" },
	],

	"Void Scar": [
		{ "name": "Aasimar Judgement Encampment","kind":"Recruit Event","rarity":"Rare" },

		{ "name": "Orichalcum Vein",       "kind": "Resource Spawn",  "rarity": "Common",   "skill": "mining" },
		{ "name": "Aetheric Rift",         "kind": "Resource Spawn",  "rarity": "Rare",     "skill": "mining" },
		{ "name": "Mythic Gem Geode",      "kind": "Resource Spawn",  "rarity": "Rare",     "skill": "mining" },

		# ✅ T10 fibre herb (renamed from Voidbark Patch)
		{ "name": "Umbralweave Voidbeds", "kind": "Resource Spawn", "rarity": "Rare", "skill": "herbalism" },

		{ "name": "Fault of Fallen Wings", "kind": "Dungeon / Delve", "rarity": "Rare" },
		{ "name": "Chain of Light Pylon",  "kind": "Structure",       "rarity": "Uncommon" },
		{ "name": "Null Pocket",           "kind": "Hazard",          "rarity": "Uncommon" },
	],
}


# Main gathering skill per biome for resource spawns
const BIOME_MAIN_SKILL := {
	# Tier 1
	"Mountain": "mining",
	"Forest": "woodcutting",
	"River": "fishing",

	# Tier 2
	"Maplewood Vale": "woodcutting",
	"Rocky Estuary": "fishing",
	"Foothill Valleys": "mining",

	# Tier 3
	"Silkwood": "woodcutting",
	"Cenote Sinkholes": "fishing",
	"Painted Canyon": "mining",

	# Tier 4
	"Cloudpine Terraces": "woodcutting",
	"Karst Cascade Gorge": "fishing",
	"Deep Underground Mines": "mining",

	# Tier 5
	"Baobab Savanna": "woodcutting",
	"Floodplain": "fishing",
	"Rift Valley": "mining",

	# Tier 6
	"Rainforest Highwood": "woodcutting",
	"River Gorge": "fishing",
	"Mesas": "mining",

	# Tier 7
	"Incense Groves": "woodcutting",
	"Floating Oasis": "fishing",
	"Salt Dome Escarpments": "mining",

	# Tier 8
	"Boreal Ridge": "woodcutting",
	"Frozen Tarn": "fishing",
	"Permafrost Steppe": "mining",

	# Tier 9
	"Ashfield Cinderwood": "woodcutting",
	"Drakefire Geyser Basin": "fishing",
	"Magmaforge Undercaverns": "mining",

	# Tier 10
	"Celestial Grove": "woodcutting",
	"Starsea Rift": "fishing",
	"Void Scar": "mining",
}

# --- Early-game recruit guarantee state ---
var _early_spawn_count: int = 0              # how many *player-spawned* tiles so far (excluding Hamlet)
var _early_recruit_guaranteed: bool = false  # did any of the first 5 tiles have a recruit?

func _get_recruit_name_for_biome(biome_name: String) -> String:
	# Look up the "Recruit Event" row in the BIOME_MODIFIERS table.
	var pool: Array = BIOME_MODIFIERS.get(biome_name, []) as Array
	for row in pool:
		if row is Dictionary:
			var d: Dictionary = row as Dictionary
			var kind: String = String(d.get("kind", ""))
			if kind.begins_with("Recruit"):
				return String(d.get("name", ""))
	return ""


func _resource_skill_id_for_biome(biome_name: String) -> String:
	return String(BIOME_MAIN_SKILL.get(biome_name, ""))


# How many shards it costs to summon one fragment
const SUMMON_SHARD_COST: int = 1

# Empty-slot selection & preview
var selected_empty: Variant = null
var empty_marker: Line2D = null

# === One-shot tile picker API (used by UI) ===
var _tile_pick_cb: Callable = Callable()   # empty = no pending pick

func request_tile_pick(cb: Callable) -> void:
	# Store a one-shot callback that will receive a Vector2i axial.
	_tile_pick_cb = cb
# === /One-shot tile picker API ===

func _ready() -> void:
	rng.randomize()
	add_to_group("World")
	_sanity_log_missing()

	# 🔹 Fresh run: clear any leftover resource node cache
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("clear_all"):
		ResourceNodes.clear_all()

	set_process(true)

	var viewport: Viewport = get_viewport()
	# ✅ FIX: connect using an explicit Callable so GDScript doesn't treat the identifier
	# as an undeclared variable (and to avoid scope/typing weirdness).
	var _cb := Callable(self, "_on_viewport_resized")
	if not viewport.size_changed.is_connected(_cb):
		viewport.size_changed.connect(_cb)

	if typeof(Selection) != TYPE_NIL and Selection.has_signal("fragment_selected"):
		var selection_cb := Callable(self, "_on_fragment_selected")
		if not Selection.fragment_selected.is_connected(selection_cb):
			Selection.fragment_selected.connect(selection_cb)

	_connect_astromancy()

	var origin: Vector2i = Vector2i(0, 0)

	# Try to apply pending load; only if NON-EMPTY.
	# If there is no pending/valid save, bootstrap a fresh Hamlet run.
	if not _apply_pending_load_if_any():
		# Spawn starting Hamlet fragment at (0,0)
		_spawn_fragment("Hamlet", origin)

		# Mark origin as occupied in world data (for adjacency checks etc.)
		if typeof(WorldData) != TYPE_NIL and WorldData.has_method("occupy"):
			WorldData.occupy(origin)

		# Ensure we have a Founder villager and bind them to the Hamlet tile
		if typeof(Villagers) != TYPE_NIL and Villagers.has_method("ensure_seed_one"):
			Villagers.ensure_seed_one()

			if WorldData.has_method("bind_villager_to_axial") and Villagers.has_method("get_founder_id"):
				var founder_id: int = Villagers.get_founder_id()
				if founder_id >= 0:
					WorldData.bind_villager_to_axial(origin, founder_id)

	# At this point we either:
	# - loaded an existing world (with villagers & bindings restored), or
	# - just created a fresh Hamlet + Founder and bound them.

	_refresh_ui()

	# Ghost ring for empty selection
	empty_marker = Line2D.new()
	empty_marker.width = 4.0
	empty_marker.default_color = Color(0.2, 1.0, 0.2, 0.9)
	empty_marker.z_index = 1000
	empty_marker.visible = false
	empty_marker.points = _hex_points_closed()
	fragments_root.add_child(empty_marker)

	# ESC overlay wiring (non-pausing)
	if is_instance_valid(dim_pause):
		dim_pause.visible = false
		dim_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_center_dim_overlay()

	if is_instance_valid(pause_menu):
		pause_menu.hide()
		_center_pause_menu()
		if pause_menu.has_signal("save_requested"):
			pause_menu.connect("save_requested", Callable(self, "_on_pause_save"))
		if pause_menu.has_signal("load_requested"):
			pause_menu.connect("load_requested", Callable(self, "_on_pause_load"))
		if pause_menu.has_signal("settings_requested"):
			pause_menu.connect("settings_requested", Callable(self, "_on_pause_settings"))
		if pause_menu.has_signal("main_menu_requested"):
			pause_menu.connect("main_menu_requested", Callable(self, "_on_pause_main_menu"))
		if pause_menu.has_signal("quit_requested"):
			pause_menu.connect("quit_requested", Callable(self, "_on_pause_quit"))

	# Save panel wiring (in-scene)
	if is_instance_valid(save_panel):
		save_panel.hide()
		_center_control(save_panel)
		save_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if save_panel.has_signal("saved"):
			save_panel.connect("saved", Callable(self, "_on_savepanel_saved"))
		if save_panel.has_signal("request_close"):
			save_panel.connect("request_close", Callable(self, "_on_savepanel_closed"))

	# Load panel wiring (in-scene; optional)
	if is_instance_valid(load_panel):
		load_panel.hide()
		_center_control(load_panel)
		load_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if load_panel.has_signal("load_slot"):
			load_panel.connect("load_slot", Callable(self, "_on_loadpanel_load_slot"))
		if load_panel.has_signal("request_close"):
			load_panel.connect("request_close", Callable(self, "_on_loadpanel_closed"))

	# Settings panel wiring (in-scene; optional)
	if is_instance_valid(settings_panel):
		settings_panel.hide()
		_center_control(settings_panel)
		settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if settings_panel.has_signal("request_close"):
			settings_panel.connect("request_close", Callable(self, "_on_settingspanel_closed"))

func _astro_mod_cap(astromancy_level: int) -> int:
	var cap: int = 0
	for gate_level in ASTRO_MOD_CAP_BY_LEVEL.keys():
		var lvl: int = int(gate_level)
		if astromancy_level >= lvl:
			cap = max(cap, int(ASTRO_MOD_CAP_BY_LEVEL[gate_level]))
	return cap


func _mod_weight(row: Dictionary) -> int:
	var rarity: String = String(row.get("rarity", "Common"))
	return int(MOD_RARITY_WEIGHT.get(rarity, 1))


func _pick_weighted(source: Array, count: int, rng_src: RandomNumberGenerator) -> Array:
	var chosen: Array = []
	var choices: Array = source.duplicate()

	for _i in range(count):
		if choices.is_empty():
			break

		var total_weight: int = 0
		for r in choices:
			total_weight += _mod_weight(r)

		var roll: int = rng_src.randi_range(1, total_weight)
		var accum: int = 0
		for j in range(choices.size()):
			accum += _mod_weight(choices[j])
			if roll <= accum:
				chosen.append(choices[j])
				choices.remove_at(j)
				break

	return chosen
func _modifier_to_dict(m: Variant) -> Dictionary:
	if typeof(m) == TYPE_DICTIONARY:
		return m
	if typeof(m) != TYPE_STRING:
		return {}

	var mod_str: String = String(m)
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
		"kind": kind_base.strip_edges(),
		"skill": skill_id,
		"name": detail.strip_edges(),
		"rarity": "",
	}


func _normalize_modifiers(mods: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in mods:
		var md := _modifier_to_dict(m)
		if not md.is_empty():
			out.append(md)
	return out


func _is_recruit_modifier(m: Variant) -> bool:
	if typeof(m) == TYPE_DICTIONARY:
		var kind: String = String((m as Dictionary).get("kind", ""))
		return kind.begins_with("Recruit")
	if typeof(m) == TYPE_STRING:
		return String(m).begins_with("Recruit Event")
	return false

func roll_biome_modifiers(
	biome_name: String,
	astromancy_level: int,
	rng_src: RandomNumberGenerator
) -> Array[Dictionary]:
	# BIOME_MODIFIERS.get(...) returns Variant, so we cast and type the var explicitly.
	var pool: Array = BIOME_MODIFIERS.get(biome_name, []) as Array
	if pool.is_empty():
		return []

	# Split into resource vs non-resource so we can guarantee at least one node.
	var resource_rows: Array = []
	var other_rows: Array = []

	for row in pool:
		var kind: String = String(row.get("kind", ""))
		if kind.begins_with("Resource"):
			resource_rows.append(row)
		else:
			other_rows.append(row)

	var results: Array[Dictionary] = []

	# ------------------------------------------------
	# 1) GUARANTEED RESOURCE NODE (if the biome has any)
	# ------------------------------------------------
	if not resource_rows.is_empty():
		var picked_res: Array = _pick_weighted(resource_rows, 1, rng_src)
		for row in picked_res:
			results.append(row.duplicate(true))
	else:
		# Biome has no Resource rows – pick any row as the first modifier.
		var picked_any: Array = _pick_weighted(pool, 1, rng_src)
		for row in picked_any:
			results.append(row.duplicate(true))

	# ------------------------------------------------
	# 2) EXTRA MODIFIERS
	#    • Always at least ONE extra (so 2 total) if there are enough rows.
	#    • Astromancy level controls how MANY extras beyond that.
	# ------------------------------------------------
	var extra_cap: int = _astro_mod_cap(astromancy_level)  # how many extras level *can* add

	# How many distinct modifiers are still available?
	var max_extra_possible: int = max(0, pool.size() - results.size())
	if max_extra_possible <= 0:
		return results

	# We want at least one extra so every tile ends up with 2 modifiers minimum,
	# as long as the biome actually has that many rows.
	var extra_min: int = min(1, max_extra_possible)

	# Level-based ceiling for extras — can't exceed what the pool can supply.
	var extra_max_by_level: int = min(extra_cap, max_extra_possible)

	var extra_to_pick: int = 0
	if extra_max_by_level <= 0:
		# Astromancy is too low to "unlock" extras, but we still take 1
		# so the tile has 2 modifiers minimum.
		extra_to_pick = extra_min
	else:
		# Random between "at least 1 extra" and the level-based maximum.
		extra_to_pick = rng_src.randi_range(extra_min, extra_max_by_level)

	if extra_to_pick <= 0:
		return results

	# Build a list of remaining rows so we don't duplicate what we already picked.
	var remaining_rows: Array = []
	for row in pool:
		if not results.has(row):
			remaining_rows.append(row)

	if remaining_rows.is_empty():
		return results

	extra_to_pick = min(extra_to_pick, remaining_rows.size())
	var picked_extra: Array = _pick_weighted(remaining_rows, extra_to_pick, rng_src)
	for row in picked_extra:
		results.append(row.duplicate(true))

	return results

# ---------- pending load (returns true only when a NON-EMPTY dict was applied) ----------
func _apply_pending_load_if_any() -> bool:
	var GS := get_node_or_null("/root/GameState")
	if GS and GS.has_method("has_pending_world") and GS.call("has_pending_world"):
		var d_v: Variant = GS.call("take_pending_world")
		var d: Dictionary = d_v as Dictionary if d_v is Dictionary else {}
		if d.is_empty():
			# Nothing meaningful to load — do NOT clear bootstrap, let caller spawn Hamlet.
			return false

		# Clear any villager icon mappings BEFORE we nuke children
		_clear_only_fragments()

		# Clear whatever is in the scene and rebuild from payload
		if typeof(Selection) != TYPE_NIL and Selection.has_method("set_selected"):
			Selection.set_selected(null)
		# WorldData may not expose a reset — safe to skip
		_restore_from_dict(d)
		_refresh_ui()
		return true

	# If there is no GameState or no pending world, nothing was applied.
	return false

# ---------- viewport / overlay layout ----------
func _on_viewport_resized() -> void:
	if _is_menu_open():
		_center_pause_menu()
		_center_dim_overlay()
	if is_instance_valid(save_panel) and save_panel.visible:
		_center_control(save_panel)
	if is_instance_valid(load_panel) and load_panel.visible:
		_center_control(load_panel)
	if is_instance_valid(settings_panel) and settings_panel.visible:
		_center_control(settings_panel)


func _is_menu_open() -> bool:
	return (is_instance_valid(pause_menu) and pause_menu.visible) \
		or (is_instance_valid(save_panel) and save_panel.visible) \
		or (is_instance_valid(load_panel) and load_panel.visible) \
		or (is_instance_valid(settings_panel) and settings_panel.visible) \
		or (is_instance_valid(dim_pause) and dim_pause.visible)

func _open_menu() -> void:
	is_dragging = false

	if is_instance_valid(save_panel): save_panel.hide()
	if is_instance_valid(load_panel): load_panel.hide()

	if is_instance_valid(pause_menu):
		_center_pause_menu()
		if pause_menu.has_method("open_menu"): pause_menu.call("open_menu")
		else: pause_menu.visible = true

	if is_instance_valid(dim_pause):
		_center_dim_overlay()
		dim_pause.visible = true

	# --- New: collapse & disable RightDock while menus are open ---
	var rd := get_node_or_null("CanvasLayer/RightDock")
	if rd:
		if rd.has_method("force_collapse"):
			rd.call("force_collapse")
		if rd.has_method("set_enabled"):
			rd.call("set_enabled", false)

func _close_menu() -> void:
	is_dragging = false

	if is_instance_valid(pause_menu):
		if pause_menu.has_method("close_menu"):
			pause_menu.call("close_menu")
		else:
			pause_menu.visible = false

	if is_instance_valid(save_panel):
		save_panel.hide()
	if is_instance_valid(load_panel):
		load_panel.hide()
	if is_instance_valid(settings_panel):
		settings_panel.hide()
	if is_instance_valid(dim_pause):
		dim_pause.visible = false

	# Re-enable RightDock after menus close
	var rd := get_node_or_null("CanvasLayer/RightDock")
	if rd and rd.has_method("set_enabled"):
		rd.call("set_enabled", true)

	# Optional fallback via group, in case the path changes
	var dock := get_tree().get_first_node_in_group("RightDock")
	if dock and dock.has_method("set_enabled"):
		dock.call("set_enabled", true)


func _center_pause_menu() -> void:
	if pause_menu is Control:
		var pm := pause_menu as Control
		pm.set_as_top_level(true)
		pm.z_index = 100
		pm.mouse_filter = Control.MOUSE_FILTER_STOP
		pm.reset_size()
		pm.set_anchors_preset(Control.PRESET_CENTER, false)
		pm.set_offsets_preset(Control.PRESET_CENTER)

func _center_dim_overlay() -> void:
	if dim_pause is Control:
		var d := dim_pause as Control
		d.set_as_top_level(true)
		d.set_anchors_preset(Control.PRESET_FULL_RECT, false)
		d.set_offsets_preset(Control.PRESET_FULL_RECT)

func _center_control(ctrl: Control) -> void:
	if ctrl == null: return
	ctrl.set_as_top_level(true)
	ctrl.reset_size()
	ctrl.set_anchors_preset(Control.PRESET_CENTER, false)
	ctrl.set_offsets_preset(Control.PRESET_CENTER)
	ctrl.z_index = 120


func _open_task_picker_for_villager(v_idx: int, ax: Vector2i) -> void:
	if v_idx < 0:
		return

	var has_frag := _has_fragment_at(ax)
	var can_use_empty := (not has_frag) and _is_adjacent_to_any(ax)

	if not has_frag and not can_use_empty:
		_flash_message("You can only summon new fragments on empty hexes adjacent to existing fragments.")
		return

	var picker := TASK_PICKER_SCENE.instantiate() as TaskPicker
	if picker == null:
		return

	var ui_parent: Node = null
	if has_node("CanvasLayer"):
		ui_parent = get_node("CanvasLayer")
	else:
		ui_parent = get_tree().root

	ui_parent.add_child(picker)

	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	picker.open_for(v_idx, ax, screen_pos)


func _open_task_picker_for_drop(ax: Vector2i) -> void:
	# Must be dragging a villager
	if typeof(DragState) == TYPE_NIL:
		return
	if not DragState.has_method("is_active") or not DragState.is_active():
		return

	var v_idx: int = -1
	if DragState.has_method("get_villager_index"):
		v_idx = DragState.get_villager_index()

	# Clear drag state immediately so it doesn't trigger twice
	if DragState.has_method("clear"):
		DragState.clear()

	_open_task_picker_for_villager(v_idx, ax)


# ---------- SAVE / LOAD helpers ----------
func _SL() -> Node:
	var n := get_node_or_null("/root/SaveLoad")
	return n if n != null else get_node_or_null("/root/SaveLoadData")

# ESC: Save
func _on_pause_save() -> void:
	if not is_instance_valid(save_panel):
		var s := _SL()
		if s and s.has_method("save_autosave"): s.call("save_autosave")
		return
	if is_instance_valid(pause_menu): pause_menu.hide()
	if is_instance_valid(dim_pause):
		_center_dim_overlay()
		dim_pause.visible = true
	_center_control(save_panel)
	if save_panel.has_method("open"): save_panel.call("open")
	save_panel.visible = true

func _on_savepanel_closed() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.show()
		_center_pause_menu()

func _on_savepanel_saved(_slot_id: String, _label: String) -> void:
	_on_savepanel_closed()

# ESC: Load
func _on_pause_load() -> void:
	if is_instance_valid(load_panel):
		if is_instance_valid(pause_menu): pause_menu.hide()
		if is_instance_valid(dim_pause):
			_center_dim_overlay()
			dim_pause.visible = true
		_center_control(load_panel)
		if load_panel.has_method("open"): load_panel.call("open")
		load_panel.visible = true
		return
	# Fallback: autosave into running world
	_load_autosave_into_running_world()

func _on_loadpanel_closed() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.show()
		_center_pause_menu()

func _on_loadpanel_load_slot(id: String) -> void:
	var s := _SL()
	if s and s.has_method("load_run") and bool(s.call("load_run", id)):
		_rebuild_world_from_pending()
	else:
		push_error("Failed to load: %s" % id)

func _load_autosave_into_running_world() -> void:
	var s := _SL()
	if s and s.has_method("load_run") and bool(s.call("load_run", "autosave")):
		_rebuild_world_from_pending()

func _rebuild_world_from_pending() -> void:
	var GS := get_node_or_null("/root/GameState")
	if not (GS and GS.has_method("has_pending_world") and GS.call("has_pending_world")):
		push_error("Loaded, but GameState had no pending world.")
		return

	var d_v: Variant = GS.call("take_pending_world")
	var d: Dictionary = d_v as Dictionary if d_v is Dictionary else {}
	if d.is_empty():
		push_error("Pending world was empty.")
		return

	# --- NEW: hard reset Selection & UI state BEFORE we free nodes ---
	if typeof(Selection) != TYPE_NIL and Selection.has_method("clear"):
		Selection.clear()
	if typeof(Selection) != TYPE_NIL and Selection.has_method("set_selected"):
		Selection.set_selected(null)
	selected_empty = null
	if empty_marker: empty_marker.visible = false

	# Also clear all villager icon mappings so we don't hold freed objects
	_worker_icon_by_v.clear()
	_tile_worker_by_ax.clear()

	# 🔹 NEW: clear all resource node data
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("clear_all"):
		ResourceNodes.clear_all()
	# ---------------------------------------------------------------

	# Replace tiles
	for c in fragments_root.get_children():
		c.queue_free()

	_restore_from_dict(d)
	_refresh_ui()

	# Optionally set a sane default selection for WorldQuery
	if typeof(WorldQuery) != TYPE_NIL and d.has("tiles"):
		var arr: Array = d["tiles"]
		if arr.size() > 0:
			var t0: Dictionary = arr[0]
			var ax0 := Vector2i(int(t0.get("q", 0)), int(t0.get("r", 0)))
			if WorldQuery.has_method("set_selected"):
				WorldQuery.set_selected(ax0)

	# Close load panel, keep pause up for UX clarity
	if is_instance_valid(load_panel): load_panel.hide()
	if is_instance_valid(pause_menu): pause_menu.show()

func _on_pause_settings() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.hide()
	if is_instance_valid(dim_pause):
		_center_dim_overlay()
		dim_pause.visible = true
	if is_instance_valid(settings_panel):
		_center_control(settings_panel)
		if settings_panel.has_method("open"):
			settings_panel.call("open")
		settings_panel.visible = true

func _on_pause_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_pause_quit() -> void:
	get_tree().quit()

# ---------- WORLD SNAPSHOT / RESTORE ----------
func get_save_dict() -> Dictionary:
	var tiles: Array = []
	for c in fragments_root.get_children():
		var td := _node_to_tile_dict(c)
		if not td.is_empty():
			tiles.append(td)
	return {
		"tiles": tiles,
		"early_spawn_count": _early_spawn_count,
		"early_recruit_guaranteed": _early_recruit_guaranteed,
	}

func _node_to_tile_dict(c: Node) -> Dictionary:
	if c is Line2D:
		return {}

	# Explicit Fragment save payload
	if c is Fragment:
		var f: Fragment = c as Fragment

		# Copy modifiers into a plain Array so save data is stable
		var save_mods: Array = []
		for m in f.modifiers:
			save_mods.append(m)

		# 🔹 Ask WorldData if this coord is anchored
		var anchored: bool = false
		if typeof(WorldData) != TYPE_NIL and WorldData.has_method("is_anchored"):
			anchored = bool(WorldData.is_anchored(f.coord))

		return {
			"q": f.coord.x,
			"r": f.coord.y,
			"biome": f.biome,
			"tier": f.tier,
			"region": f.region,
			"modifiers": save_mods,
			"recruit_triggered": f.recruit_triggered,
			"anchored": anchored,                 # ← already there
			"recruited_villager_idx": f.recruited_villager_idx,  # ← ADD THIS
		}

	# Legacy / generic case – nodes with a `coord` property
	var coord_v: Variant = c.get("coord")
	if coord_v is Vector2i:
		var biome_v: Variant = c.get("biome")
		var biome_s: String = ""
		if biome_v is String:
			biome_s = String(biome_v)
		var coord: Vector2i = coord_v as Vector2i
		return { "q": coord.x, "r": coord.y, "biome": biome_s }

	# Very old fallback – infer axial from position
	if c is Node2D:
		var p: Vector2 = (c as Node2D).position
		var ax: Vector2i = _pixel_to_axial(p)
		var biome4_v: Variant = c.get("biome")
		var biome4_s: String = ""
		if biome4_v is String:
			biome4_s = String(biome4_v)
		return { "q": ax.x, "r": ax.y, "biome": biome4_s }

	return {}

func _restore_from_dict(d: Dictionary) -> void:
	# 🔹 Clear Selection map before we rebuild all tiles
	if typeof(Selection) != TYPE_NIL and Selection.has_method("clear"):
		Selection.clear()

	# Restore early recruit guarantee state (defaults for old saves)
	_early_spawn_count = int(d.get("early_spawn_count", 0))
	_early_recruit_guaranteed = bool(d.get("early_recruit_guaranteed", false))

	var tiles: Array = d.get("tiles", [])
	for t in tiles:
		if not (t is Dictionary):
			continue

		var td: Dictionary = t as Dictionary
		var q: int = int(td.get("q", 0))
		var r: int = int(td.get("r", 0))
		var ax: Vector2i = Vector2i(q, r)

		# --- Biome restore with NO global Hamlet fallback ---
		var biome4_v: Variant = td.get("biome4", null)
		var biome_v: Variant  = td.get("biome", biome4_v)

		var b: String = ""
		if biome_v is String:
			b = String(biome_v)
		elif biome4_v is String:
			b = String(biome4_v)

		# Only force Hamlet for the origin tile if biome is missing
		if b == "":
			if ax == Vector2i.ZERO:
				b = "Hamlet"
			else:
				b = "Forest"

		var anchored: bool = bool(td.get("anchored", false))

		var frag: Node2D = TILE_SCENE.instantiate()
		fragments_root.add_child(frag)

		frag.position = _axial_to_pixel(ax.x, ax.y)
		frag.set("coord", ax)
		frag.set("biome", b)

		if frag is Fragment:
			var f: Fragment = frag as Fragment

			var meta: Dictionary = {}
			if td.has("tier"):
				meta["tier"] = int(td["tier"])
			if td.has("region"):
				meta["region"] = String(td["region"])

			var mods_v: Variant = td.get("modifiers", [])
			if mods_v is Array:
				meta["modifiers"] = _normalize_modifiers(mods_v)

			if meta.is_empty():
				f.setup(ax, b)
			else:
				f.setup(ax, b, meta)

			f.recruit_triggered = bool(td.get("recruit_triggered", false))
			f.recruited_villager_idx = int(td.get("recruited_villager_idx", -1))

			f.set_local_modifiers(f.modifiers)

			if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("rebuild_nodes_for_tile"):
				ResourceNodes.rebuild_nodes_for_tile(ax, f.modifiers, b, f.tier)

			if not f.clicked.is_connected(_on_fragment_clicked):
				f.clicked.connect(_on_fragment_clicked)
		else:
			var mods2_v: Variant = td.get("modifiers", [])
			if mods2_v is Array and frag.has_method("set_local_modifiers"):
				frag.call("set_local_modifiers", _normalize_modifiers(mods2_v))
			if frag.has_signal("clicked") and not frag.is_connected("clicked", Callable(self, "_on_fragment_clicked")):
				frag.connect("clicked", Callable(self, "_on_fragment_clicked"))

			if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("rebuild_nodes_for_tile"):
				var mods_for_tile: Array = []
				if mods2_v is Array:
					mods_for_tile = _normalize_modifiers(mods2_v)
				var tier_for_tile: int = _get_rank_for_biome(b)
				ResourceNodes.rebuild_nodes_for_tile(ax, mods_for_tile, b, tier_for_tile)

		# 🔹 Register EVERY frag with Selection (inside the loop!)
		if typeof(Selection) != TYPE_NIL and Selection.has_method("register_fragment"):
			Selection.register_fragment(frag)

		# Keep WorldData in sync
		if typeof(WorldData) != TYPE_NIL:
			if WorldData.has_method("occupy"):
				WorldData.occupy(ax)

			if anchored:
				if WorldData.has_method("set_anchored"):
					WorldData.set_anchored(ax, true)
				elif WorldData.has_method("anchor"):
					WorldData.anchor(ax)

# ---------- normal world flow ----------
func _on_summon_pressed() -> void:
	# Summon flow is now handled entirely by Astromancy.
	_flash_message("To expand, drag a villager to an empty adjacent hex and start an Astromancy job.")
	_clear_empty_selection()
	_refresh_ui()


func _get_rank_for_shard(id: StringName) -> int:
	if SHARD_RANK.has(id):
		return int(SHARD_RANK[id])

	# Fallback: parse "rX_..." pattern if someone adds new shard ids
	var s := String(id)
	if s.begins_with("r"):
		var parts := s.split("_", false, 2)
		if parts.size() >= 1:
			var n_str := parts[0].substr(1)
			if n_str.is_valid_int():
				return int(n_str.to_int())
	return 1


func _roll_biome_for_rank(rank: int) -> String:
	if BIOMES_BY_RANK.has(rank):
		var arr: Array = BIOMES_BY_RANK[rank]
		if arr.size() > 0:
			var i := rng.randi_range(0, arr.size() - 1)
			return String(arr[i])

	# Fallback to the old flat set if something goes wrong
	var options: Array[String] = ["Forest", "River", "Mountain"]
	return options[rng.randi_range(0, options.size() - 1)]


# Backwards-compatible wrapper (if anything still calls _roll_biome())
func _roll_biome() -> String:
	return _roll_biome_for_rank(1)


func _get_rank_for_biome(biome: String) -> int:
	for rank in BIOMES_BY_RANK.keys():
		var arr: Array = BIOMES_BY_RANK[rank]
		for biome_entry in arr:
			if String(biome_entry) == biome:
				return int(rank)
	return 0


# Placeholder for future: roll modifiers using Biome Summary weights
func _roll_modifiers_for_biome(_biome: String) -> Array[String]:
	# TODO: hook this into the full modifier tables (Resources / Dungeons / Hazards)
	return []


func _spawn_fragment(biome_name: String, ax: Vector2i) -> Node2D:
	var frag: Node2D = TILE_SCENE.instantiate()
	fragments_root.add_child(frag)

	# Position in world
	frag.position = _axial_to_pixel(ax.x, ax.y)

	# Make sure every fragment has coord/biome properties
	frag.set("coord", ax)
	frag.set("biome", biome_name)

	# 🔹 NEW: register this fragment with Selection so WorldQuery can see it
	if typeof(Selection) != TYPE_NIL and Selection.has_method("register_fragment"):
		Selection.register_fragment(frag)

	# Determine tier / region from the biome
	var tier := _get_rank_for_biome(biome_name)  # 0 if Hamlet / unknown
	var region_str := ""
	if tier > 0:
		region_str = "R%d" % tier

	# --- EARLY RECRUIT GUARANTEE TRACKING ---
	# Only count *player-spawned* tiles, not the starting Hamlet.
	var is_player_tile: bool = (biome_name != "Hamlet")
	if is_player_tile and not _early_recruit_guaranteed and _early_spawn_count < 5:
		_early_spawn_count += 1
	# ---------------------------------------

	# Roll Astromancy-based modifiers, using the villager on this tile if present
	var astro_level := 0

	# 1) Try per-villager Astromancy based on whoever is groveing on this hex
	var v_idx := villager_on_tile(ax)
	if v_idx >= 0 and typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_skill_level"):
		astro_level = int(Villagers.get_skill_level(v_idx, "astromancy"))
	# 2) Fallback: use global Skills autoload (if you still track a player-wide level)
	elif typeof(Skills) != TYPE_NIL and Skills.has_method("get_skill_level"):
		astro_level = int(Skills.get_skill_level("astromancy"))

	var mods := roll_biome_modifiers(biome_name, astro_level, rng)

	# --- EARLY RECRUIT GUARANTEE ENFORCEMENT ---
	# If this is one of the first 5 player tiles AND no recruit has appeared yet,
	# then on the *5th* tile we force a recruit modifier if RNG didn't roll one.
	if is_player_tile and not _early_recruit_guaranteed and _early_spawn_count == 5:
		var has_recruit: bool = false
		for m in mods:
			if _is_recruit_modifier(m):
				has_recruit = true
				break

		if not has_recruit:
			var recruit_name: String = _get_recruit_name_for_biome(biome_name)
			if recruit_name != "":
				mods.append({
					"kind": "Recruit Event",
					"name": recruit_name,
					"rarity": "Rare",
				})
			else:
				# Fallback, in case the biome table is missing a recruit row
				mods.append({
					"kind": "Recruit Event",
					"name": "Local Wanderer",
					"rarity": "Rare",
				})
	# ---------------------------------------------------


	# If this is our Fragment class, use setup + local modifiers
	if frag is Fragment:
		var f := frag as Fragment
		f.setup(ax, biome_name, {
			"tier": tier,
			"region": region_str,
		})
		f.set_local_modifiers(mods)

		# Mark guarantee satisfied if any of the first 5 tiles actually has a recruit
		if is_player_tile and _early_spawn_count <= 5 and f.has_recruit_modifier():
			_early_recruit_guaranteed = true

		# NEW: auto-recruit if this tile rolled a recruit modifier
		if f.has_recruit_modifier():
			f.try_trigger_recruit()

		# Hook up click signal
		if not f.clicked.is_connected(_on_fragment_clicked):
			f.clicked.connect(_on_fragment_clicked)

	else:
		# Fallback for non-Fragment scenes
		if frag.has_method("set_local_modifiers"):
			frag.call("set_local_modifiers", mods)
		elif frag.has_meta("local_modifiers"):
			frag.set("local_modifiers", mods)
		# Try to connect a generic "clicked" signal if present
		if frag.has_signal("clicked") and not frag.is_connected("clicked", Callable(self, "_on_fragment_clicked")):
			frag.connect("clicked", Callable(self, "_on_fragment_clicked"))

	# 🔹 NEW: update ResourceNodes for this tile
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("rebuild_nodes_for_tile"):
		ResourceNodes.rebuild_nodes_for_tile(ax, mods, biome_name, tier)

	return frag


func _on_settingspanel_closed() -> void:
	if is_instance_valid(settings_panel): settings_panel.hide()
	if is_instance_valid(pause_menu):
		pause_menu.show()
		_center_pause_menu()

func _on_fragment_clicked(f) -> void:
	if typeof(Selection) != TYPE_NIL and Selection.has_method("set_selected"):
		Selection.set_selected(f)

	if f == null:
		_clear_empty_selection()
		return

	var ax := Vector2i.ZERO
	var c_v: Variant = f.get("coord")
	if c_v is Vector2i:
		ax = c_v
		# Keep WorldQuery in sync
		if typeof(WorldQuery) != TYPE_NIL:
			if WorldQuery.has_method("set_selected"):
				WorldQuery.set_selected(ax)
			else:
				WorldQuery.selected_axial = ax

	_clear_empty_selection()

func _on_fragment_selected(f: Node) -> void:
	if f == null or not is_instance_valid(f):
		return

	# If HUD is docked, NEVER position it near the clicked tile.
	if selection_hud != null and is_instance_valid(selection_hud) and selection_hud.has_method("get"):
		if bool(selection_hud.get("dock_to_bottom_left")):
			return

	if f is Node2D:
		var frag := f as Node2D
		_update_selection_hud_position(frag.global_position)

func _update_selection_hud_position(world_pos: Vector2) -> void:
	if selection_hud == null or not is_instance_valid(selection_hud):
		return

	var viewport_rect := get_viewport().get_visible_rect()
	var screen_pos := _world_to_screen(world_pos)
	var target := screen_pos + SELECTION_HUD_OFFSET
	var hud_size := selection_hud.size
	var min_pos := viewport_rect.position
	var max_pos := viewport_rect.position + viewport_rect.size - hud_size
	max_pos.x = max(min_pos.x, max_pos.x)
	max_pos.y = max(min_pos.y, max_pos.y)

	target.x = clampf(target.x, min_pos.x, max_pos.x)
	target.y = clampf(target.y, min_pos.y, max_pos.y)
	selection_hud.global_position = target

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var canvas_xform := get_viewport().get_canvas_transform()
	return canvas_xform * world_pos


func _connect_astromancy() -> void:
	# Optional: wire Astromancy → World expansion
	if typeof(AstromancySystem) == TYPE_NIL:
		return
	if AstromancySystem.has_signal("fragment_summon_ready"):
		if not AstromancySystem.fragment_summon_ready.is_connected(_on_fragment_summon_ready):
			AstromancySystem.fragment_summon_ready.connect(_on_fragment_summon_ready)


func _on_fragment_summon_ready(ax: Vector2i, shard_id: StringName) -> void:
	# Called by Astromancy when a summon job completes.
	# ax = target axial coord; shard_id = which shard the player chose.
	if _has_fragment_at(ax):
		push_warning("Astromancy tried to summon on occupied tile %s" % [ax])
		return
	if not _is_adjacent_to_any(ax):
		push_warning("Astromancy tried to summon on non-adjacent tile %s" % [ax])
		return

	var rank: int = _get_rank_for_shard(shard_id)
	var biome: String = _roll_biome_for_rank(rank)
	_spawn_fragment(biome, ax)

	if WorldData.has_method("occupy"):
		WorldData.occupy(ax)

	if selected_empty != null and selected_empty == ax:
		_clear_empty_selection()

	_refresh_ui()


# ---------- UI helpers ----------
func _refresh_ui() -> void:
	if essence_label == null:
		return

	var tile_count: int = 0
	for c in fragments_root.get_children():
		if c is Line2D:
			continue
		tile_count += 1

	essence_label.text = "Fragments: %d   (expand via Astromancy)" % tile_count


func _flash_message(msg: String) -> void:
	if essence_label == null:
		return
	essence_label.text = msg


# ---------- input ----------
func _unhandled_input(event: InputEvent) -> void:
	# ESC → toggle pause/menus
	if event.is_action_pressed("ui_cancel"):
		is_dragging = false

		# If a tile-pick is pending, cancel it (early exit)
		if _tile_pick_cb.is_valid():
			_tile_pick_cb = Callable()
			get_viewport().set_input_as_handled()
			return

		# Otherwise, toggle the pause/menus
		if _is_menu_open():
			_close_menu()
		else:
			_open_menu()

		get_viewport().set_input_as_handled()
		return

	# If a menu is open, swallow input
	if _is_menu_open():
		is_dragging = false
		get_viewport().set_input_as_handled()
		return

	# Mouse buttons
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# RMB drag to pan
		if mb.button_index == DRAG_BUTTON:
			is_dragging = mb.pressed
			get_viewport().set_input_as_handled()
			return

		if mb.pressed:
			# Wheel zoom
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(cam.zoom.x * (1.0 - ZOOM_STEP))
				get_viewport().set_input_as_handled()
				return
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(cam.zoom.x * (1.0 + ZOOM_STEP))
				get_viewport().set_input_as_handled()
				return

			# LMB: either click a fragment (let Fragment handle) or select empty hex
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				var ax: Vector2i = _mouse_to_axial(get_global_mouse_position())

				# One-shot picker intercept (UI asked World to capture the next tile click)
				if _tile_pick_cb.is_valid():
					var cb := _tile_pick_cb
					_tile_pick_cb = Callable()  # consume it (one-shot)
					cb.call(ax)
					get_viewport().set_input_as_handled()
					return

				# If there’s a fragment here, let its own click handler deal with it
				if _has_fragment_at(ax):
					return  # ← do NOT set_input_as_handled(); pass-through to Fragment

				# Clear any fragment selection
				if typeof(Selection) != TYPE_NIL and Selection.has_method("set_selected"):
					Selection.set_selected(null)

				# Publish selection + show ghost ring
				selected_empty = ax
				if typeof(WorldQuery) != TYPE_NIL:
					if WorldQuery.has_method("set_selected"):
						WorldQuery.set_selected(ax)
					else:
						WorldQuery.selected_axial = ax
				_show_empty_marker(ax)

				get_viewport().set_input_as_handled()
				return

	# Mouse move while dragging → pan camera
	if event is InputEventMouseMotion and is_dragging:
		var mm := event as InputEventMouseMotion
		cam.position -= mm.relative / cam.zoom.x
		get_viewport().set_input_as_handled()
		return

func _input(event: InputEvent) -> void:
	# Don’t react while menus are open
	if _is_menu_open():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# ------------------------------------------------
		# NEW: LMB press on a world worker icon → start drag
		# ------------------------------------------------
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# If the click is over the RightDock UI, don't treat it as a world drag
			var rd := get_node_or_null("CanvasLayer/RightDock")
			if rd is Control:
				var dock_ctrl := rd as Control
				if dock_ctrl.get_global_rect().has_point(mb.position):
					# Let the UI (villager list) handle this; this is how your existing drag works.
					return

			# Don't start a new drag if one is already in progress (e.g. from the RightDock)
			var dragging_already := false
			if typeof(DragState) != TYPE_NIL and DragState.has_method("is_active"):
				dragging_already = DragState.is_active()

			if not dragging_already:
				var ax_pressed: Vector2i = _mouse_to_axial(get_global_mouse_position())
				var v_idx := villager_on_tile(ax_pressed)
				if v_idx >= 0:
					_start_villager_drag_from_world(v_idx)

					# Optional: mirror the normal click selection behaviour
					if typeof(Selection) != TYPE_NIL and Selection.has_method("set_selected"):
						for c in fragments_root.get_children():
							var coord_v: Variant = c.get("coord")
							if coord_v is Vector2i and coord_v == ax_pressed:
								Selection.set_selected(c)
								break
					_clear_empty_selection()
					if typeof(WorldQuery) != TYPE_NIL:
						if WorldQuery.has_method("set_selected"):
							WorldQuery.set_selected(ax_pressed)
						else:
							WorldQuery.selected_axial = ax_pressed



					get_viewport().set_input_as_handled()
					return

		# ------------------------------------------------
		# LMB release while dragging a villager → open TaskPicker
		# ------------------------------------------------
		if (not mb.pressed) and mb.button_index == MOUSE_BUTTON_LEFT:
			if typeof(DragState) != TYPE_NIL \
			and DragState.has_method("is_active") \
			and DragState.is_active():
				var ax_release: Vector2i = _mouse_to_axial(get_global_mouse_position())
				_open_task_picker_for_drop(ax_release)
				# IMPORTANT: do NOT call set_input_as_handled() here,
				# so UI drag/drop visuals still work.


func _process(_delta: float) -> void:
	_update_drag_ghost()


func _update_drag_ghost() -> void:
	# Don’t show the ghost while menus are open
	if _is_menu_open():
		_free_drag_ghost()
		return

	var dragging := false
	var v_idx := -1

	# Read current state from the DragState autoload
	if typeof(DragState) != TYPE_NIL \
	and DragState.has_method("is_active") \
	and DragState.is_active():
		dragging = true
		if DragState.has_method("get_villager_index"):
			v_idx = DragState.get_villager_index()

	if dragging and v_idx >= 0:
		# If the ghost is missing or for a different villager, recreate it
		if _drag_ghost == null or not is_instance_valid(_drag_ghost) or _drag_ghost_v_idx != v_idx:
			_free_drag_ghost()
			_drag_ghost = _make_worker_icon(v_idx)
			_drag_ghost_v_idx = v_idx

			# Add it to the world so it uses world coordinates with the camera
			add_child(_drag_ghost)
			_drag_ghost.z_index = 900

		# Move ghost to follow the mouse (world-space)
		if _drag_ghost != null and is_instance_valid(_drag_ghost):
			_drag_ghost.position = get_global_mouse_position()
	else:
		# No active drag → hide/remove ghost
		_free_drag_ghost()


func _free_drag_ghost() -> void:
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null
	_drag_ghost_v_idx = -1

func _start_villager_drag_from_world(v_idx: int) -> void:
	if v_idx < 0:
		return
	if typeof(DragState) == TYPE_NIL:
		return

	# This is exactly what the list view does.
	if DragState.has_method("begin"):
		DragState.begin(v_idx)
	else:
		DragState.dragging = true
		DragState.villager_index = v_idx


func _set_zoom(z: float) -> void:
	var clamped: float = clampf(z, MIN_ZOOM, MAX_ZOOM)
	cam.zoom = Vector2(clamped, clamped)

# ---------- empty selection helpers ----------
func _select_empty_at_mouse() -> void:
	var ax: Vector2i = _mouse_to_axial(get_global_mouse_position())
	selected_empty = ax
	if typeof(WorldQuery) != TYPE_NIL:
		WorldQuery.selected_axial = ax
	_show_empty_marker(ax)


func _clear_empty_selection() -> void:
	selected_empty = null
	if empty_marker:
		empty_marker.visible = false

func _show_empty_marker(ax: Vector2i) -> void:
	if empty_marker == null: return
	empty_marker.position = _axial_to_pixel(ax.x, ax.y)
	var ok: bool = (not _has_fragment_at(ax)) and _is_adjacent_to_any(ax)
	empty_marker.default_color = (Color(0.2, 1.0, 0.2, 0.9) if ok else Color(1.0, 0.2, 0.2, 0.9))
	empty_marker.visible = true

	# If docked, don't "follow" the marker.
	if selection_hud != null and is_instance_valid(selection_hud) and selection_hud.has_method("get"):
		if bool(selection_hud.get("dock_to_bottom_left")):
			return

	_update_selection_hud_position(to_global(empty_marker.position))


func _has_fragment_at(ax: Vector2i) -> bool:
	# Authoritative: scan children and check their coord
	for c in fragments_root.get_children():
		var coord_v: Variant = c.get("coord")
		if coord_v is Vector2i and coord_v == ax:
			return true
	return false

## Called by AstromancySystem when a collapse job completes.
## Removes the fragment/tile at `ax`, clears anchoring/occupancy, and
## returns info used for Augury refunds and villager cleanup.
##
## Returns:
##   "had_fragment": bool,
##   "rank": int,          # 1–10, inferred from biome
##   "villager_idx": int,  # -1 if none
func destroy_fragment_at(ax: Vector2i) -> Dictionary:
	var info: Dictionary = {
		"had_fragment": false,
		"rank": 1,
		"recruited_villager_idx": -1,
		"worker_idx": -1,
	}

	# --- Find the fragment node at this axial ---
	var frag: Node2D = null
	for c in fragments_root.get_children():
		var coord_v: Variant = c.get("coord")
		if coord_v is Vector2i and coord_v == ax:
			frag = c
			break

	if frag == null:
		return info

	# --- Work out the fragment's biome ---
	var biome_v: Variant = frag.get("biome")
	var biome_s: String = ""
	if biome_v is String:
		biome_s = String(biome_v)

	# 🔹 PROTECT HAMLET
	if biome_s == "Hamlet" or ax == Vector2i.ZERO:
		return info

	info["had_fragment"] = true

	# --- Determine rank for refund purposes ---
	var rank: int = _get_rank_for_biome(biome_s)
	if rank <= 0:
		rank = 1
	info["rank"] = rank

	# --- NEW: read the villager this fragment recruited, if any ---
	var recruited_idx: int = -1
	if frag is Fragment:
		var f := frag as Fragment
		recruited_idx = int(f.get_recruited_villager_idx())
	info["recruited_villager_idx"] = recruited_idx

	# --- Kick off any worker groveing on this tile (but DON'T destroy them) ---
	var worker_idx: int = villager_on_tile(ax)
	if worker_idx >= 0:
		info["worker_idx"] = worker_idx
		_clear_villager_icon(worker_idx)

	# --- Clear occupancy / anchoring / villager binding ---
	if typeof(WorldData) != TYPE_NIL:
		if WorldData.has_method("vacate"):
			WorldData.vacate(ax)
		elif WorldData.has_method("release"):
			WorldData.release(ax)

		if WorldData.has_method("set_anchored"):
			WorldData.set_anchored(ax, false)
		elif WorldData.has_method("unanchor"):
			WorldData.unanchor(ax)
		elif WorldData.has_method("clear_anchor"):
			WorldData.clear_anchor(ax)

		# 🔹 NEW: also clear any bound villager on this tile
		if WorldData.has_method("clear_villager_binding"):
			WorldData.clear_villager_binding(ax)

	# --- Remove the fragment node itself ---
	if is_instance_valid(frag):
		frag.queue_free()

	# 🔹 NEW: clear resource nodes for this tile
	if typeof(ResourceNodes) != TYPE_NIL and ResourceNodes.has_method("clear_tile"):
		ResourceNodes.clear_tile(ax)

	return info

func _is_adjacent_to_any(ax: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	for d in dirs:
		var neighbor: Vector2i = ax + d
		if _has_fragment_at(neighbor):
			return true
	return false


# ---------- hex math ----------
func _hex_points_closed() -> PackedVector2Array:
	var s: float = HEX_SIZE
	var half: float = s * 0.5
	var dx: float = (SQRT3 * s) * 0.5
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0, -s),
		Vector2(dx, -half),
		Vector2(dx,  half),
		Vector2(0,  s),
		Vector2(-dx, half),
		Vector2(-dx, -half)
	])
	return pts + PackedVector2Array([pts[0]])

func _mouse_to_axial(p: Vector2) -> Vector2i:
	var qf: float = (SQRT3 / 3.0 * p.x - 1.0 / 3.0 * p.y) / HEX_SIZE
	var rf: float = (2.0 / 3.0 * p.y) / HEX_SIZE
	return _axial_round(qf, rf)

func _pixel_to_axial(p: Vector2) -> Vector2i:
	return _mouse_to_axial(p)

func _axial_to_pixel(q: int, r: int) -> Vector2:
	var x: float = HEX_SIZE * SQRT3 * (q + r * 0.5)
	var y: float = HEX_SIZE * 1.5 * r
	return Vector2(x, y)

func _axial_round(qf: float, rf: float) -> Vector2i:
	var x: float = qf
	var z: float = rf
	var y: float = -x - z
	var rx: float = round(x)
	var ry: float = round(y)
	var rz: float = round(z)
	var dx: float = abs(rx - x)
	var dy: float = abs(ry - y)
	var dz: float = abs(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))

func _make_worker_icon(v_idx: int) -> Node2D:
	var s := Sprite2D.new()
	var tex: Texture2D = null

	# 1) Try to get this villager's own icon via the Villagers autoload
	if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_icon_path"):
		var path: String = String(Villagers.get_icon_path(v_idx))
		if path != "":
			var loaded := load(path)
			if loaded is Texture2D:
				tex = loaded

	# 2) If that failed, fall back to the generic worker_icon_texture (exported in inspector)
	if tex == null and worker_icon_texture != null:
		tex = worker_icon_texture

	if tex != null:
		s.texture = tex

		# Auto-scale so the icon is clearly *smaller* than the hex
		# HEX_SIZE is the hex radius; tile height ≈ HEX_SIZE * 2
		var max_dim := float(max(tex.get_width(), tex.get_height()))
		if max_dim > 0.0:
			var target_px := HEX_SIZE * 0.7  # ~0.4 of tile height; tweak smaller if needed
			var scale_factor := target_px / max_dim
			s.scale = Vector2(scale_factor, scale_factor)
		else:
			s.scale = Vector2(0.25, 0.25)
	else:
		# Fallback debug square if textures are missing
		var rect := ColorRect.new()
		rect.color = Color(0.2, 1.0, 0.2, 0.9)
		rect.custom_minimum_size = Vector2(12, 12)
		s.add_child(rect)
		s.scale = Vector2(0.25, 0.25)

	s.z_index = 500
	return s

# ---------- villager placement helpers ----------

func _cancel_any_job_for_villager(v_idx: int) -> void:
	# Look up autoloads safely (no compile-time symbol required)

	var vm := get_node_or_null("/root/VillagerManager")
	if vm and vm.has_method("stop_job"):
		vm.call("stop_job", v_idx)
		return

	var villagers := get_node_or_null("/root/Villagers")
	if villagers and villagers.has_method("stop_job"):
		villagers.call("stop_job", v_idx)
		return

	var js := get_node_or_null("/root/JobSystem")
	if js and js.has_method("stop_job"):
		js.call("stop_job", v_idx)
		return

func assign_villager_to_tile(v_idx: int, ax: Vector2i) -> void:
	var has_frag := _has_fragment_at(ax)
	var can_grove_on_empty := (not has_frag) and _is_adjacent_to_any(ax)

	if not has_frag and not can_grove_on_empty:
		_flash_message("Villagers can only grove on tiles or empty adjacent hexes.")
		return

	# Enforce: only one villager per tile
	# NEW RULE: placing onto an occupied tile evicts the old villager and cancels their job.
	if _tile_worker_by_ax.has(ax):
		var other_v := int(_tile_worker_by_ax[ax])
		if other_v != v_idx:
			_cancel_any_job_for_villager(other_v)   # cancel whatever they were doing
			_clear_villager_icon(other_v)          # remove icon + unbind from WorldData

	# If this villager was on another tile, clear old icon/mapping
	_clear_villager_icon(v_idx)

	# Create & place icon
	var icon := _make_worker_icon(v_idx)
	fragments_root.add_child(icon)
	icon.position = _axial_to_pixel(ax.x, ax.y)

	_worker_icon_by_v[v_idx] = icon
	_tile_worker_by_ax[ax] = v_idx

	# Bind by *ID*, not index
	if typeof(WorldData) != TYPE_NIL and WorldData.has_method("bind_villager_to_axial"):
		if typeof(Villagers) != TYPE_NIL and Villagers.has_method("get_at"):
			var v = Villagers.get_at(v_idx)
			var vid: int = v.id
			WorldData.bind_villager_to_axial(ax, vid)


func clear_villager_from_tile(v_idx: int) -> void:
	_clear_villager_icon(v_idx)


func villager_on_tile(ax: Vector2i) -> int:
	if _tile_worker_by_ax.has(ax):
		return int(_tile_worker_by_ax[ax])
	return -1


func _clear_villager_icon(v_idx: int) -> void:
	# Remove icon if we know about this villager
	if _worker_icon_by_v.has(v_idx):
		var icon_obj = _worker_icon_by_v[v_idx]
		_worker_icon_by_v.erase(v_idx)

		if is_instance_valid(icon_obj):
			icon_obj.queue_free()

	# Remove any tile entries for this villager AND clear bindings
	var to_erase: Array = []
	for ax in _tile_worker_by_ax.keys():
		if int(_tile_worker_by_ax[ax]) == v_idx:
			to_erase.append(ax)
	for ax in to_erase:
		_tile_worker_by_ax.erase(ax)
		if typeof(WorldData) != TYPE_NIL and WorldData.has_method("clear_villager_binding"):
			WorldData.clear_villager_binding(ax)


func place_villager_at_hamlet(v_idx: int) -> void:
	var origin := Vector2i(0, 0)
	assign_villager_to_tile(v_idx, origin)

func _clear_only_fragments() -> void:
	# Clear selection state that refers to tiles/icons
	selected_empty = null
	if empty_marker and is_instance_valid(empty_marker):
		empty_marker.visible = false

	# Clear icon maps BEFORE freeing nodes, so we don't keep dead refs
	_worker_icon_by_v.clear()
	_tile_worker_by_ax.clear()

	# Free everything except Line2D overlays (empty_marker lives here)
	for c in fragments_root.get_children():
		if c is Line2D:
			continue
		c.queue_free()

	# Ensure marker exists
	if empty_marker == null or not is_instance_valid(empty_marker):
		empty_marker = Line2D.new()
		empty_marker.width = 4.0
		empty_marker.default_color = Color(0.2, 1.0, 0.2, 0.9)
		empty_marker.z_index = 1000
		empty_marker.visible = false
		empty_marker.points = _hex_points_closed()
		fragments_root.add_child(empty_marker)

	# If the marker was freed for any reason, recreate it
	if empty_marker == null or not is_instance_valid(empty_marker):
		empty_marker = Line2D.new()
		empty_marker.width = 4.0
		empty_marker.default_color = Color(0.2, 1.0, 0.2, 0.9)
		empty_marker.z_index = 1000
		empty_marker.visible = false
		empty_marker.points = _hex_points_closed()
		fragments_root.add_child(empty_marker)


# ---------- sanity ----------
func _sanity_log_missing() -> void:
	var missing: Array[String] = []
	if fragments_root == null: missing.append("Fragments")
	if essence_label == null:  missing.append("CanvasLayer/Panel/EssenceLabel")
	if summon_button == null:  missing.append("CanvasLayer/Panel/SummonButton")
	if cam == null:            missing.append("Cam")
	if pause_menu == null:     missing.append("CanvasLayer/Panel/EscMenu")
	if dim_pause == null:      missing.append("CanvasLayer/Panel/DimPause")
	if save_panel == null:     missing.append("CanvasLayer/Panel/SavePanel")
	if load_panel == null:     missing.append("CanvasLayer/Panel/LoadPanel")
	if settings_panel == null: missing.append("CanvasLayer/Panel/SettingsPanel")

	if missing.size() > 0:
		push_warning("World.gd missing nodes: %s" % ", ".join(missing))
