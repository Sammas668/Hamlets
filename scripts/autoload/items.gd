# autoload/Items.gd
extends Node
# No class_name when autoloading as "Items"

# -------------------------------------------------------------------
# Item IDs (StringNames for speed)
# -------------------------------------------------------------------

# Augury tiers (Scrying)
const AUGURY_A1: StringName  = &"Whisper"
const AUGURY_A2: StringName  = &"Glimmer"
const AUGURY_A3: StringName  = &"Trace"
const AUGURY_A4: StringName  = &"Auspice"
const AUGURY_A5: StringName  = &"Omen"
const AUGURY_A6: StringName  = &"Portent"
const AUGURY_A7: StringName  = &"Harbinger"
const AUGURY_A8: StringName  = &"Oracle"
const AUGURY_A9: StringName  = &"Totality"
const AUGURY_A10: StringName = &"Zenith"

# Shards (Astromancy, plain R1–R10)
const R1_PLAIN: StringName  = &"Whisper Shard"
const R2_PLAIN: StringName  = &"Glimmer Shard"
const R3_PLAIN: StringName  = &"r3_plain"
const R4_PLAIN: StringName  = &"r4_plain"
const R5_PLAIN: StringName  = &"r5_plain"
const R6_PLAIN: StringName  = &"r6_plain"
const R7_PLAIN: StringName  = &"r7_plain"
const R8_PLAIN: StringName  = &"r8_plain"
const R9_PLAIN: StringName  = &"r9_plain"
const R10_PLAIN: StringName = &"r10_plain"

# Mining – Stones
const STONE_LIMESTONE: StringName = &"stone_limestone"
const STONE_SANDSTONE: StringName = &"stone_sandstone"
const STONE_BASALT: StringName    = &"stone_basalt"
const STONE_GRANITE: StringName   = &"stone_granite"
const STONE_MARBLE: StringName    = &"stone_marble"
const STONE_CLAY: StringName    = &"stone_clay"

# Mining – Ores
const ORE_COPPER: StringName      = &"ore_copper"
const ORE_TIN: StringName         = &"ore_tin"
const ORE_IRON: StringName        = &"ore_iron"
const ORE_COAL: StringName        = &"ore_coal"
const ORE_SILVER: StringName      = &"ore_silver"
const ORE_GOLD: StringName        = &"ore_gold"
const ORE_MITHRITE: StringName    = &"ore_mithrite"
const ORE_ADAMANTITE: StringName  = &"ore_adamantite"
const ORE_ORICHALCUM: StringName  = &"ore_orichalcum"
const ORE_AETHER: StringName      = &"ore_aether"

# Mining – Gems
const GEM_OPAL: StringName        = &"gem_opal"
const GEM_JADE: StringName        = &"gem_jade"
const GEM_BLUE_TOPAZ: StringName   = &"gem_blue_topaz"
const GEM_SAPPHIRE: StringName    = &"gem_sapphire"
const GEM_EMERALD: StringName     = &"gem_emerald"
const GEM_RUBY: StringName        = &"gem_ruby"
const GEM_DIAMOND: StringName     = &"gem_diamond"
const GEM_DRAGONSTONE: StringName = &"gem_dragonstone"
const GEM_ONYX: StringName        = &"gem_onyx"

# Woodcutting – Logs (T1–T10)
const LOG_PINE: StringName     = &"log_pine"      # T1
const LOG_BIRCH: StringName    = &"log_birch"     # T2
const LOG_OAK: StringName      = &"log_oak"       # T3
const LOG_WILLOW: StringName   = &"log_willow"    # T4
const LOG_MAPLE: StringName    = &"log_maple"     # T5
const LOG_YEW: StringName      = &"log_yew"       # T6
const LOG_IRONWOOD: StringName = &"log_ironwood"  # T7
const LOG_REDWOOD: StringName  = &"log_redwood"   # T8
const LOG_SAKURA: StringName   = &"log_sakura"    # T9
const LOG_ELDER: StringName    = &"log_elder"     # T10

# Woodcutting – Misc drops
const TWIGS: StringName        = &"twigs"
const BARK_SCRAP: StringName   = &"bark_scrap"
const BARK: StringName         = &"bark"
const RESIN_GLOB: StringName   = &"resin_glob"

# Woodcutting – Global specials
const BIRD_NEST: StringName    = &"bird_nest"
const AMBER_SAP: StringName    = &"amber_sap"

# Farming – Tree seeds (one per Woodcutting tree)
const SEED_PINE: StringName      = &"seed_pine"      # T1
const SEED_BIRCH: StringName     = &"seed_birch"     # T2
const SEED_OAK: StringName       = &"seed_oak"       # T3
const SEED_WILLOW: StringName    = &"seed_willow"    # T4
const SEED_MAPLE: StringName     = &"seed_maple"     # T5
const SEED_YEW: StringName       = &"seed_yew"       # T6
const SEED_IRONWOOD: StringName  = &"seed_ironwood"  # T7
const SEED_REDWOOD: StringName   = &"seed_redwood"   # T8
const SEED_SAKURA: StringName    = &"seed_sakura"    # T9
const SEED_ELDER: StringName     = &"seed_elder"     # T10

# Fishing – Junk + Fish
const FISHING_JUNK: StringName       = &"fishing_junk"

# Net species
const FISH_BROOK_SHRIMP: StringName  = &"fish_brook_shrimp"
const FISH_COAST_SPRAT: StringName   = &"fish_coast_sprat"
const FISH_GLACIER_HERRING: StringName = &"fish_glacier_herring"
const FISH_RIVER_BLEAK: StringName   = &"fish_river_bleak"
const FISH_SANDFLOUNDER: StringName  = &"fish_sandflounder"
const FISH_SHELF_COD: StringName     = &"fish_shelf_cod"
const FISH_STRIPED_MACKEREL: StringName = &"fish_striped_mackerel"
const FISH_SKIPJACK_TUNA: StringName = &"fish_skipjack_tuna"
const FISH_SUNFIN_TUNA: StringName   = &"fish_sunfin_tuna"
const FISH_NIGHT_EEL: StringName     = &"fish_night_eel"
const FISH_ABYSSAL_FIN: StringName   = &"fish_abyssal_fin"

# Rod species
const FISH_PUDDLE_PERCH: StringName  = &"fish_puddle_perch"
const FISH_MIRROR_CARP: StringName   = &"fish_mirror_carp"
const FISH_STREAM_DACE: StringName   = &"fish_stream_dace"
const FISH_BROWN_TROUT: StringName   = &"fish_brown_trout"
const FISH_RIVER_CHAR: StringName    = &"fish_river_char"
const FISH_SILVER_SALMON: StringName = &"fish_silver_salmon"
const FISH_DEEPWHITE: StringName     = &"fish_deepwhite"
const FISH_REED_PIKE: StringName     = &"fish_reed_pike"
const FISH_MUSKFANG_PIKE: StringName = &"fish_muskfang_pike"
const FISH_MUDCAT: StringName        = &"fish_mudcat"
const FISH_KING_CARP: StringName     = &"fish_king_carp"
const FISH_MOONFANG_EEL: StringName  = &"fish_moonfang_eel"
const FISH_RIFTFIN: StringName       = &"fish_riftfin"

# Harpoon species
const FISH_CLIFF_LOBSTER: StringName   = &"fish_cliff_lobster"
const FISH_SAILSKIP_TUNA: StringName   = &"fish_sailskip_tuna"
const FISH_YELLOWCREST_TUNA: StringName = &"fish_yellowcrest_tuna"
const FISH_AZUREFIN_TUNA: StringName   = &"fish_azurefin_tuna"
const FISH_SKYBLADE_MARLIN: StringName = &"fish_skyblade_marlin"
const FISH_CORAL_REEF_SHARK: StringName = &"fish_coral_reef_shark"
const FISH_STORM_MAKO: StringName      = &"fish_storm_mako"
const FISH_DREADJAW_SHARK: StringName  = &"fish_dreadjaw_shark"
const FISH_WHALEFIN_GIANT: StringName  = &"fish_whalefin_giant"
const FISH_LEVIATHAN_WHALE: StringName = &"fish_leviathan_whale"
const FISH_ABYSSAL_LEVIATHAN: StringName = &"fish_abyssal_leviathan"

# Smithing – Metal bars
const BAR_BRONZE: StringName      = &"bar_bronze"
const BAR_IRON: StringName        = &"bar_iron"
const BAR_STEEL: StringName       = &"bar_steel"
const BAR_MITHRITE: StringName    = &"bar_mithrite"
const BAR_ADAMANTITE: StringName  = &"bar_adamantite"
const BAR_ORICHALCUM: StringName  = &"bar_orichalcum"
const BAR_AETHER: StringName      = &"bar_aether"
const BAR_SILVER: StringName      = &"bar_silver"
const BAR_GOLD: StringName        = &"bar_gold"


# -------------------------------------------------------------------
# Smithing: auto-generated item IDs (tools, weapons, armour, hardware, fishing)
# -------------------------------------------------------------------

const _SMITHING_METAL_LABELS := {
	"bronze": "Bronze",
	"iron": "Iron",
	"steel": "Steel",
	"mithrite": "Mithrite",
	"adamantite": "Adamantite",
	"orichalcum": "Orichalcum",
	"aether": "Aether",
	"silver": "Silver",
	"gold": "Gold",
}

const _SMITHING_FAMILY_LABELS := {
	# Core gathering tools
	"pickaxe": "Pickaxe",
	"axe": "Axe",
	"sickle": "Sickle",
	"hoe": "Hoe",
	"knife": "Knife",
	"hammer": "Hammer",
	"chisel": "Chisel",

	# Fishing tools
	"fishing_net": "Fishing Net",
	"fishing_rod": "Fishing Rod",
	"fishing_harpoon": "Fishing Harpoon",

	# Construction hardware
	"nails": "Nails",
	"rivets": "Rivets",
	"bolts": "Bolts",
	"spikes": "Spikes",
	"straps": "Straps",
	"hinges": "Hinges",
	"brackets": "Brackets",
	"chains": "Chains",
	"reinforcement_rod": "Reinforcement Rod",
	"flat_plate": "Flat Plate",
	"beam_shoe": "Beam Shoe",
	"gear": "Gear",
	"counterweight": "Counterweight",
	"lockwork": "Lockwork",

	# Melee weapons
	"dagger": "Dagger",
	"mace": "Mace",
	"shortsword": "Shortsword",
	"sword": "Sword",
	"scimitar": "Scimitar",
	"longsword": "Longsword",
	"warhammer": "Warhammer",
	"battleaxe": "Battleaxe",
	"two_handed_sword": "Two-handed Sword",
	"spear": "Spear",
	"hasta": "Hasta",

	# Armour
	"med_helm": "Medium Helm",
	"full_helm": "Full Helm",
	"chainbody": "Chainbody",
	"square_shield": "Square Shield",
	"kiteshield": "Kiteshield",
	"platelegs": "Platelegs",
	"plateskirt": "Plateskirt",
	"platebody": "Platebody",
}

# Map smithing family keys -> smithing group folders
# Groups match SmithingSystem.FAMILY_GROUPS keys: "tool", "fishing", "hardware", "weapon", "armour".
const _SMITHING_FAMILY_GROUP := {
	# Core gathering tools
	"pickaxe": "tool",
	"axe": "tool",
	"sickle": "tool",
	"hoe": "tool",
	"knife": "tool",
	"hammer": "tool",
	"chisel": "tool",

	# Fishing tools
	"fishing_net": "fishing",
	"fishing_rod": "fishing",
	"fishing_harpoon": "fishing",

	# Construction hardware
	"nails": "hardware",
	"rivets": "hardware",
	"bolts": "hardware",
	"spikes": "hardware",
	"straps": "hardware",
	"hinges": "hardware",
	"brackets": "hardware",
	"chains": "hardware",
	"reinforcement_rod": "hardware",
	"flat_plate": "hardware",
	"beam_shoe": "hardware",
	"gear": "hardware",
	"counterweight": "hardware",
	"lockwork": "hardware",

	# Melee weapons
	"dagger": "weapon",
	"mace": "weapon",
	"shortsword": "weapon",
	"sword": "weapon",
	"scimitar": "weapon",
	"longsword": "weapon",
	"warhammer": "weapon",
	"battleaxe": "weapon",
	"two_handed_sword": "weapon",
	"spear": "weapon",
	"hasta": "weapon",

	# Armour
	"med_helm": "armour",
	"full_helm": "armour",
	"chainbody": "armour",
	"square_shield": "armour",
	"kiteshield": "armour",
	"platelegs": "armour",
	"plateskirt": "armour",
	"platebody": "armour",
}


func _parse_smithing_id(id: StringName) -> Dictionary:
	var s := String(id)
	var parts := s.split("_")
	if parts.size() < 2:
		return {}

	# Last token = metal, everything before = family_id
	var metal_key := parts[parts.size() - 1]
	var family_key := ""
	for i in range(parts.size() - 1):
		if i > 0:
			family_key += "_"
		family_key += parts[i]

	if not _SMITHING_METAL_LABELS.has(metal_key):
		return {}
	if not _SMITHING_FAMILY_LABELS.has(family_key):
		return {}

	return {
		"metal_key": metal_key,
		"family_key": family_key,
	}


func _is_smithing_generated_id(id: StringName) -> bool:
	return not _parse_smithing_id(id).is_empty()


func _smithing_generated_display_name(id: StringName) -> String:
	var info := _parse_smithing_id(id)
	if info.is_empty():
		return String(id)

	var metal_label: String = _SMITHING_METAL_LABELS[info["metal_key"]]
	var family_label: String = _SMITHING_FAMILY_LABELS[info["family_key"]]
	return "%s %s" % [metal_label, family_label]


func _smithing_generated_icon_path(id: StringName) -> String:
	var info := _parse_smithing_id(id)
	if info.is_empty():
		return ""

	var family_key: String = info["family_key"]
	if not _SMITHING_FAMILY_GROUP.has(family_key):
		return ""

	var group_key: String = _SMITHING_FAMILY_GROUP[family_key]
	# Icon files are expected at:
	#   res://assets/items/Smithing/<group>/<full_id>.png
	# e.g. weapon/sword_bronze.png or tool/pickaxe_iron.png
	return "res://assets/items/Smithing/%s/%s.png" % [group_key, String(id)]


# Later you can add infused shard IDs like:
# const R3_WOOD: StringName = &"r3_woodcutting"
# const R5_ORE: StringName  = &"r5_mining"
# etc.

# -------------------------------------------------------------------
# Construction: use building/module IDs as item tokens
# -------------------------------------------------------------------

# Optional: folder for construction item icons
const _CONSTRUCTION_ICON_ROOT := "res://assets/items/Construction"

func _get_construction_system() -> Node:
	# Assumes you have an autoload called "ConstructionSystem"
	# (set in Project Settings → Autoload as "ConstructionSystem")
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("ConstructionSystem")

func _is_construction_item(id: StringName) -> bool:
	var cs := _get_construction_system()
	if cs == null:
		return false
	if cs.has_method("has_part"):
		# has_part(String id) should return true if it's a known building/module ID
		return cs.has_part(String(id))
	return false

func _construction_display_name(id: StringName) -> String:
	var cs := _get_construction_system()
	if cs and cs.has_method("get_part_display_name"):
		# get_part_display_name(String id) → e.g. "Forager's Hut (Site)"
		return cs.get_part_display_name(String(id))
	# Fallback if ConstructionSystem doesn't know or helper not implemented
	return String(id)

func _construction_icon_path(id: StringName) -> String:
	# By default map "<id>" -> "res://assets/items/Construction/<id>.png"
	return "%s/%s.png" % [_CONSTRUCTION_ICON_ROOT, String(id)]

# -------------------------------------------------------------------
# Definitions
# -------------------------------------------------------------------

var _defs: Dictionary = {

	# Augury A1–A10
	AUGURY_A1: {
		"name": "Whisper (A1)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Whisper.png",
	},
	AUGURY_A2: {
		"name": "Glimmer (A2)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Glimmer.png",  # fill when you have the icon
	},
	AUGURY_A3: {
		"name": "Trace (A3)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Trace.png",
	},
	AUGURY_A4: {
		"name": "Auspice (A4)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Auspice.png"
	},
	AUGURY_A5: {
		"name": "Omen (A5)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Omen.png",
	},
	AUGURY_A6: {
		"name": "Portent (A6)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Portent.png",
	},
	AUGURY_A7: {
		"name": "Harbinger (A7)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Harbinger.png",
	},
	AUGURY_A8: {
		"name": "Oracle (A8)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Oracle.png",
	},
	AUGURY_A9: {
		"name": "Totality (A9)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Totality.png",
	},
	AUGURY_A10: {
		"name": "Zenith (A10)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Zenith.png",
	},

	# Plain shards R1–R10
	R1_PLAIN: {
		"name": "Plain Shard (R1)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Whisper Shard.png",  # res://icons/r1_plain.png later
	},
	R2_PLAIN: {
		"name": "Plain Shard (R2)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Glimmer Shard.png",
	},
	R3_PLAIN: {
		"name": "Plain Shard (R3)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Trace Shard.png",
	},
	R4_PLAIN: {
		"name": "Plain Shard (R4)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Auspice Shard.png",
	},
	R5_PLAIN: {
		"name": "Plain Shard (R5)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Omen Shard.png",
	},
	R6_PLAIN: {
		"name": "Plain Shard (R6)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Portent Shard.png",
	},
	R7_PLAIN: {
		"name": "Plain Shard (R7)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Harbinger Shard.png",
	},
	R8_PLAIN: {
		"name": "Plain Shard (R8)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Oracle Shard.png",
	},
	R9_PLAIN: {
		"name": "Plain Shard (R9)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Totality Shard.png",
	},
	R10_PLAIN: {
		"name": "Plain Shard (R10)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Zenith Shard.png",
	},
	# --- Mining: Stones ---
	STONE_LIMESTONE: {
		"name": "Limestone",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_limestone.png",
	},
	STONE_SANDSTONE: {
		"name": "Sandstone",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_sandstone.png",
	},
	STONE_BASALT: {
		"name": "Basalt",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_basalt.png",
	},
	STONE_GRANITE: {
		"name": "Granite",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_granite.png",
	},
	STONE_MARBLE: {
		"name": "Marble",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_marble.png",
	},
	STONE_CLAY: {
		"name": "Clay",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_clay.png",
	},

	# --- Mining: Ores ---
	ORE_COPPER: {
		"name": "Copper Ore",
		"stack": true,
		"icon": "res://assets/icons/modifiers/copper_ore.png",
	},
	ORE_TIN: {
		"name": "Tin Ore",
		"stack": true,
		"icon": "res://assets/icons/modifiers/tin_ore.png",
	},
	ORE_IRON: {
		"name": "Iron Ore",
		"stack": true,
		"icon": "",
	},
	ORE_COAL: {
		"name": "Coal",
		"stack": true,
		"icon": "",
	},
	ORE_SILVER: {
		"name": "Silver Ore",
		"stack": true,
		"icon": "",
	},
	ORE_GOLD: {
		"name": "Gold Ore",
		"stack": true,
		"icon": "",
	},
	ORE_MITHRITE: {
		"name": "Mithrite Ore",
		"stack": true,
		"icon": "",
	},
	ORE_ADAMANTITE: {
		"name": "Adamantite Ore",
		"stack": true,
		"icon": "",
	},
	ORE_ORICHALCUM: {
		"name": "Orichalcum Ore",
		"stack": true,
		"icon": "",
	},
	ORE_AETHER: {
		"name": "Aether Ore",
		"stack": true,
		"icon": "",
	},

	# --- Mining: Gems ---
	GEM_OPAL: {
		"name": "Opal",
		"stack": true,
		"icon": "",
	},
	GEM_JADE: {
		"name": "Jade",
		"stack": true,
		"icon": "",
	},
	GEM_BLUE_TOPAZ: {
		"name": "Blue Topaz",
		"stack": true,
		"icon": "",
	},
	GEM_SAPPHIRE: {
		"name": "Sapphire",
		"stack": true,
		"icon": "",
	},
	GEM_EMERALD: {
		"name": "Emerald",
		"stack": true,
		"icon": "",
	},
	GEM_RUBY: {
		"name": "Ruby",
		"stack": true,
		"icon": "",
	},
	GEM_DIAMOND: {
		"name": "Diamond",
		"stack": true,
		"icon": "",
	},
	GEM_DRAGONSTONE: {
		"name": "Dragonstone",
		"stack": true,
		"icon": "",
	},
	GEM_ONYX: {
		"name": "Onyx",
		"stack": true,
		"icon": "",
	},
	# --- Woodcutting: Logs ---
	LOG_PINE: {
		"name": "Pine Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_pine.png",
	},
	LOG_BIRCH: {
		"name": "Birch Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_birch.png",
	},
	LOG_OAK: {
		"name": "Oak Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_oak.png",
	},
	LOG_WILLOW: {
		"name": "Willow Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_willow.png",
	},
	LOG_MAPLE: {
		"name": "Maple Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_maple.png",
	},
	LOG_YEW: {
		"name": "Yew Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_yew.png",
	},
	LOG_IRONWOOD: {
		"name": "Ironwood Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_ironwood.png",
	},
	LOG_REDWOOD: {
		"name": "Redwood Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_redwood.png",
	},
	LOG_SAKURA: {
		"name": "Sakura Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_sakura.png",
	},
	LOG_ELDER: {
		"name": "Elder Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_elder.png",
	},

	# --- Woodcutting: Misc ---
	TWIGS: {
		"name": "Twigs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/twigs.png",
	},
	BARK_SCRAP: {
		"name": "Bark Scraps",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/bark_scrap.png",
	},
	BARK: {
		"name": "Bark",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/bark.png",
	},
	RESIN_GLOB: {
		"name": "Resin Glob",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/resin_glob.png",
	},

	# --- Woodcutting: Specials ---
	BIRD_NEST: {
		"name": "Bird Nest",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/bird_nest.png",
	},
	AMBER_SAP: {
		"name": "Amber Sap",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/amber_sap.png",
	},

	# --- Farming: Tree Seeds (one per tree) ---
	SEED_PINE: {
		"name": "Pine Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_pine.png",
	},
	SEED_BIRCH: {
		"name": "Birch Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_birch.png",
	},
	SEED_OAK: {
		"name": "Oak Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_oak.png",
	},
	SEED_WILLOW: {
		"name": "Willow Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_willow.png",
	},
	SEED_MAPLE: {
		"name": "Maple Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_maple.png",
	},
	SEED_YEW: {
		"name": "Yew Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_yew.png",
	},
	SEED_IRONWOOD: {
		"name": "Ironwood Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_ironwood.png",
	},
	SEED_REDWOOD: {
		"name": "Redwood Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_redwood.png",
	},
	SEED_SAKURA: {
		"name": "Sakura Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_sakura.png",
	},
	SEED_ELDER: {
		"name": "Elder Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_elder.png",
	},
	# --- Fishing: Junk ---
	FISHING_JUNK: {
		"name": "Fishing Junk",
		"stack": true,
		"icon": "res://assets/items/Fishing/Fishing Junk.png",
	},

	# --- Fishing: Net species ---
	FISH_BROOK_SHRIMP: {
		"name": "Brook Shrimp",
		"stack": true,
		"icon": "res://assets/items/Fishing/Brook Shrimp.png",
	},
	FISH_COAST_SPRAT: {
		"name": "Coast Sprat",
		"stack": true,
		"icon": "res://assets/items/Fishing/Coast Sprat.png",
	},
	FISH_GLACIER_HERRING: {
		"name": "Glacier Herring",
		"stack": true,
		"icon": "res://assets/items/Fishing/Glacier Herring.png",
	},
	FISH_RIVER_BLEAK: {
		"name": "River Bleak",
		"stack": true,
		"icon": "res://assets/items/Fishing/River Bleak.png",
	},
	FISH_SANDFLOUNDER: {
		"name": "Sandflounder",
		"stack": true,
		"icon": "res://assets/items/Fishing/Sandflounder.png",
	},
	FISH_SHELF_COD: {
		"name": "Shelf Cod",
		"stack": true,
		"icon": "res://assets/items/Fishing/Shelf Cod.png",
	},
	FISH_STRIPED_MACKEREL: {
		"name": "Striped Mackerel",
		"stack": true,
		"icon": "res://assets/items/Fishing/Striped Mackerel.png",
	},
	FISH_SKIPJACK_TUNA: {
		"name": "Skipjack Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Skipjack Tuna.png",
	},
	FISH_SUNFIN_TUNA: {
		"name": "Sunfin Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Sunfin Tuna.png",
	},
	FISH_NIGHT_EEL: {
		"name": "Night Eel",
		"stack": true,
		"icon": "res://assets/items/Fishing/Night Eel.png",
	},
	FISH_ABYSSAL_FIN: {
		"name": "Abyssal Fin",
		"stack": true,
		"icon": "res://assets/items/Fishing/Abyssal Fin.png",
	},

	# --- Fishing: Rod species ---
	FISH_PUDDLE_PERCH: {
		"name": "Puddle Perch",
		"stack": true,
		"icon": "res://assets/items/Fishing/Puddle Perch.png",
	},
	FISH_MIRROR_CARP: {
		"name": "Mirror Carp",
		"stack": true,
		"icon": "res://assets/items/Fishing/Mirror Carp.png",
	},
	FISH_STREAM_DACE: {
		"name": "Stream Dace",
		"stack": true,
		"icon": "res://assets/items/Fishing/Stream Dace.png",
	},
	FISH_BROWN_TROUT: {
		"name": "Brown Trout",
		"stack": true,
		"icon": "res://assets/items/Fishing/Brown Trout.png",
	},
	FISH_RIVER_CHAR: {
		"name": "River Char",
		"stack": true,
		"icon": "res://assets/items/Fishing/River Char.png",
	},
	FISH_SILVER_SALMON: {
		"name": "Silver Salmon",
		"stack": true,
		"icon": "res://assets/items/Fishing/Silver Salmon.png",
	},
	FISH_DEEPWHITE: {
		"name": "Deepwhite",
		"stack": true,
		"icon": "res://assets/items/Fishing/Deepwhite.png",
	},
	FISH_REED_PIKE: {
		"name": "Reed Pike",
		"stack": true,
		"icon": "res://assets/items/Fishing/Reed Pike.png",
	},
	FISH_MUSKFANG_PIKE: {
		"name": "Muskfang Pike",
		"stack": true,
		"icon": "res://assets/items/Fishing/Muskfang Pike.png",
	},
	FISH_MUDCAT: {
		"name": "Mudcat",
		"stack": true,
		"icon": "res://assets/items/Fishing/Mudcat.png",
	},
	FISH_KING_CARP: {
		"name": "King Carp",
		"stack": true,
		"icon": "res://assets/items/Fishing/King Carp.png",
	},
	FISH_MOONFANG_EEL: {
		"name": "Moonfang Eel",
		"stack": true,
		"icon": "res://assets/items/Fishing/Moonfang Eel.png",
	},
	FISH_RIFTFIN: {
		"name": "Riftfin",
		"stack": true,
		"icon": "res://assets/items/Fishing/Riftfin.png",
	},

	# --- Fishing: Harpoon species ---
	FISH_CLIFF_LOBSTER: {
		"name": "Cliff Lobster",
		"stack": true,
		"icon": "res://assets/items/Fishing/Cliff Lobster.png",
	},
	FISH_SAILSKIP_TUNA: {
		"name": "Sailskip Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Sailskip Tuna.png",
	},
	FISH_YELLOWCREST_TUNA: {
		"name": "Yellowcrest Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Yellowcrest Tuna.png",
	},
	FISH_AZUREFIN_TUNA: {
		"name": "Azurefin Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Azurefin Tuna.png",
	},
	FISH_SKYBLADE_MARLIN: {
		"name": "Skyblade Marlin",
		"stack": true,
		"icon": "res://assets/items/Fishing/Skyblade Marlin.png",
	},
	FISH_CORAL_REEF_SHARK: {
		"name": "Coral Reef Shark",
		"stack": true,
		"icon": "res://assets/items/Fishing/Coral Reef Shark.png",
	},
	FISH_STORM_MAKO: {
		"name": "Storm Mako",
		"stack": true,
		"icon": "res://assets/items/Fishing/Storm Mako.png",
	},
	FISH_DREADJAW_SHARK: {
		"name": "Dreadjaw Shark",
		"stack": true,
		"icon": "res://assets/items/Fishing/Dreadjaw Shark.png",
	},
	FISH_WHALEFIN_GIANT: {
		"name": "Whalefin Giant",
		"stack": true,
		"icon": "res://assets/items/Fishing/Whalefin Giant.png",
	},
	FISH_LEVIATHAN_WHALE: {
		"name": "Leviathan Whale",
		"stack": true,
		"icon": "res://assets/items/Fishing/Leviathan Whale.png",
	},
	FISH_ABYSSAL_LEVIATHAN: {
		"name": "Abyssal Leviathan",
		"stack": true,
		"icon": "res://assets/items/Fishing/Abyssal Leviathan.png",
	},
	# --- Smithing: Metal Bars ---
	BAR_BRONZE: {
		"name": "Bronze Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_bronze.png",
	},
	BAR_IRON: {
		"name": "Iron Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_iron.png",
	},
	BAR_STEEL: {
		"name": "Steel Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_steel.png",
	},
	BAR_MITHRITE: {
		"name": "Mithrite Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_mithrite.png",
	},
	BAR_ADAMANTITE: {
		"name": "Adamantite Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_adamantite.png",
	},
	BAR_ORICHALCUM: {
		"name": "Orichalcum Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_orichalcum.png",
	},
	BAR_AETHER: {
		"name": "Aether Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_aether.png",
	},
	BAR_SILVER: {
		"name": "Silver Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_silver.png",
	},
	BAR_GOLD: {
		"name": "Gold Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_gold.png",
	},

}

func get_icon_path(id: StringName) -> String:
	# 1) Explicit definitions win
	var d: Dictionary = _defs.get(id, {}) as Dictionary
	var path: String = String(d.get("icon", ""))
	if path != "":
		return path

	# 2) Smithing generated items: derive path from pattern
	if _is_smithing_generated_id(id):
		var smith_path := _smithing_generated_icon_path(id)
		if smith_path != "":
			return smith_path

	# 3) Construction buildings/modules as items
	if _is_construction_item(id):
		return _construction_icon_path(id)

	# 4) Fallback: no icon
	return ""

# -------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------

func is_valid(id: StringName) -> bool:
	# 1) Any explicit item defined in _defs is valid
	if _defs.has(id):
		return true

	# 2) Any smithing-generated gear ID (<family>_<metal>) is valid
	if _is_smithing_generated_id(id):
		return true

	# 3) Any construction building/module ID known to ConstructionSystem is valid
	if _is_construction_item(id):
		return true

	# 4) Unknown
	return false



func display_name(id: StringName) -> String:
	# 1) Explicit name if present
	var d: Dictionary = _defs.get(id, {}) as Dictionary
	if d.has("name"):
		return String(d["name"])

	# 2) Smithing-generated item: "Bronze Pickaxe", "Steel Platebody", etc.
	if _is_smithing_generated_id(id):
		return _smithing_generated_display_name(id)

	# 3) Construction building/module item: ask ConstructionSystem
	if _is_construction_item(id):
		return _construction_display_name(id)

	# 4) Fallback: raw ID string
	return String(id)

func is_stackable(id: StringName) -> bool:
	var d: Dictionary = _defs.get(id, {}) as Dictionary
	if d.has("stack"):
		return bool(d["stack"])

	# Smithing gear defaults to stackable (can later override specific ones in _defs if needed)
	if _is_smithing_generated_id(id):
		return true

	# Construction building/module tokens: stackable by default
	if _is_construction_item(id):
		return true

	# Fallback: assume stackable
	return true


func get_icon(id: StringName) -> Texture2D:
	var path: String = get_icon_path(id)
	if path == "":
		return null

	var tex: Texture2D = load(path) as Texture2D
	if tex is Texture2D:
		return tex

	return null
