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
const STONE_CLAY: StringName      = &"stone_clay"

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
const GEM_OPAL: StringName         = &"gem_opal"
const GEM_JADE: StringName         = &"gem_jade"
const GEM_BLUE_TOPAZ: StringName   = &"gem_blue_topaz"
const GEM_SAPPHIRE: StringName     = &"gem_sapphire"
const GEM_EMERALD: StringName      = &"gem_emerald"
const GEM_RUBY: StringName         = &"gem_ruby"
const GEM_DIAMOND: StringName      = &"gem_diamond"
const GEM_DRAGONSTONE: StringName  = &"gem_dragonstone"
const GEM_ONYX: StringName         = &"gem_onyx"

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
const FISHING_JUNK: StringName = &"fishing_junk"

# Net species
const FISH_BROOK_SHRIMP: StringName     = &"fish_brook_shrimp"
const FISH_COAST_SPRAT: StringName      = &"fish_coast_sprat"
const FISH_GLACIER_HERRING: StringName  = &"fish_glacier_herring"
const FISH_RIVER_BLEAK: StringName      = &"fish_river_bleak"
const FISH_SANDFLOUNDER: StringName     = &"fish_sandflounder"
const FISH_SHELF_COD: StringName        = &"fish_shelf_cod"
const FISH_STRIPED_MACKEREL: StringName = &"fish_striped_mackerel"
const FISH_SKIPJACK_TUNA: StringName    = &"fish_skipjack_tuna"
const FISH_SUNFIN_TUNA: StringName      = &"fish_sunfin_tuna"
const FISH_NIGHT_EEL: StringName        = &"fish_night_eel"
const FISH_ABYSSAL_FIN: StringName      = &"fish_abyssal_fin"

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
const FISH_CLIFF_LOBSTER: StringName        = &"fish_cliff_lobster"
const FISH_SAILSKIP_TUNA: StringName        = &"fish_sailskip_tuna"
const FISH_YELLOWCREST_TUNA: StringName     = &"fish_yellowcrest_tuna"
const FISH_AZUREFIN_TUNA: StringName        = &"fish_azurefin_tuna"
const FISH_SKYBLADE_MARLIN: StringName      = &"fish_skyblade_marlin"
const FISH_CORAL_REEF_SHARK: StringName     = &"fish_coral_reef_shark"
const FISH_STORM_MAKO: StringName           = &"fish_storm_mako"
const FISH_DREADJAW_SHARK: StringName       = &"fish_dreadjaw_shark"
const FISH_WHALEFIN_GIANT: StringName       = &"fish_whalefin_giant"
const FISH_LEVIATHAN_WHALE: StringName      = &"fish_leviathan_whale"
const FISH_ABYSSAL_LEVIATHAN: StringName    = &"fish_abyssal_leviathan"

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

# ------------------------------------------------------------
# Herbalism – Cooking herbs (T1–T10)
# ------------------------------------------------------------
const COOK_HERB_THYME_T1: StringName      = &"cook_herb_thyme_t1"
const COOK_HERB_SAGE_T2: StringName       = &"cook_herb_sage_t2"
const COOK_HERB_FENNEL_T3: StringName     = &"cook_herb_fennel_t3"
const COOK_HERB_ROSEMARY_T4: StringName   = &"cook_herb_rosemary_t4"
const COOK_HERB_LEMONGRASS_T5: StringName = &"cook_herb_lemongrass_t5"
const COOK_HERB_GINGER_T6: StringName     = &"cook_herb_ginger_t6"
const COOK_HERB_CORIANDER_T7: StringName  = &"cook_herb_coriander_t7"
const COOK_HERB_JUNIPER_T8: StringName    = &"cook_herb_juniper_t8"
const COOK_HERB_OREGANO_T9: StringName    = &"cook_herb_oregano_t9"
const COOK_HERB_STAR_ANISE_T10: StringName = &"cook_herb_star_anise_t10"

# ------------------------------------------------------------
# Herbalism – Chemical herbs (T1–T10)
# ------------------------------------------------------------
const CHEM_HERB_MARSHMALLOW_ROOT_T1: StringName = &"chem_herb_marshmallow_root_t1"
const CHEM_HERB_SEA_WORMWOOD_T2: StringName     = &"chem_herb_sea_wormwood_t2"
const CHEM_HERB_GOTU_KOLA_T3: StringName        = &"chem_herb_gotu_kola_t3"
const CHEM_HERB_WATER_HEMLOCK_T4: StringName    = &"chem_herb_water_hemlock_t4"
const CHEM_HERB_BITTERSWEET_NIGHTSHADE_T5: StringName = &"chem_herb_bittersweet_nightshade_t5"
const CHEM_HERB_VALERIAN_T6: StringName         = &"chem_herb_valerian_t6"
const CHEM_HERB_ALOE_VERA_T7: StringName        = &"chem_herb_aloe_vera_t7"
const CHEM_HERB_FROST_KAVA_T8: StringName       = &"chem_herb_frost_kava_t8"
const CHEM_HERB_DATURA_T9: StringName           = &"chem_herb_datura_t9"
const CHEM_HERB_BLADDERWRACK_T10: StringName    = &"chem_herb_bladderwrack_t10"

# ------------------------------------------------------------
# Tailoring fibres (dropped by Herbalism patches)
# ------------------------------------------------------------
const TAILOR_FIBRE_FLAX: StringName        = &"tailor_fibre_flax"
const TAILOR_FIBRE_SILK_COCOONS: StringName = &"tailor_fibre_silk_cocoons"
const TAILOR_FIBRE_COTTON: StringName      = &"tailor_fibre_cotton"
const TAILOR_FIBRE_HEMP: StringName        = &"tailor_fibre_hemp"


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

	# Augury A1–A10 (Scrying)
	AUGURY_A1: {
		"name": "Whisper (A1)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Whisper.png",
		"use_skill": &"scrying",
	},
	AUGURY_A2: {
		"name": "Glimmer (A2)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Glimmer.png",
		"use_skill": &"scrying",
	},
	AUGURY_A3: {
		"name": "Trace (A3)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Trace.png",
		"use_skill": &"scrying",
	},
	AUGURY_A4: {
		"name": "Auspice (A4)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Auspice.png",
		"use_skill": &"scrying",
	},
	AUGURY_A5: {
		"name": "Omen (A5)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Omen.png",
		"use_skill": &"scrying",
	},
	AUGURY_A6: {
		"name": "Portent (A6)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Portent.png",
		"use_skill": &"scrying",
	},
	AUGURY_A7: {
		"name": "Harbinger (A7)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Harbinger.png",
		"use_skill": &"scrying",
	},
	AUGURY_A8: {
		"name": "Oracle (A8)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Oracle.png",
		"use_skill": &"scrying",
	},
	AUGURY_A9: {
		"name": "Totality (A9)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Totality.png",
		"use_skill": &"scrying",
	},
	AUGURY_A10: {
		"name": "Zenith (A10)",
		"stack": true,
		"icon": "res://assets/items/Scrying/Zenith.png",
		"use_skill": &"scrying",
	},

	# Plain shards R1–R10 (Astromancy)
	R1_PLAIN: {
		"name": "Plain Shard (R1)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Whisper Shard.png",
		"use_skill": &"astromancy",
	},
	R2_PLAIN: {
		"name": "Plain Shard (R2)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Glimmer Shard.png",
		"use_skill": &"astromancy",
	},
	R3_PLAIN: {
		"name": "Plain Shard (R3)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Trace Shard.png",
		"use_skill": &"astromancy",
	},
	R4_PLAIN: {
		"name": "Plain Shard (R4)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Auspice Shard.png",
		"use_skill": &"astromancy",
	},
	R5_PLAIN: {
		"name": "Plain Shard (R5)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Omen Shard.png",
		"use_skill": &"astromancy",
	},
	R6_PLAIN: {
		"name": "Plain Shard (R6)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Portent Shard.png",
		"use_skill": &"astromancy",
	},
	R7_PLAIN: {
		"name": "Plain Shard (R7)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Harbinger Shard.png",
		"use_skill": &"astromancy",
	},
	R8_PLAIN: {
		"name": "Plain Shard (R8)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Oracle Shard.png",
		"use_skill": &"astromancy",
	},
	R9_PLAIN: {
		"name": "Plain Shard (R9)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Totality Shard.png",
		"use_skill": &"astromancy",
	},
	R10_PLAIN: {
		"name": "Plain Shard (R10)",
		"stack": true,
		"icon": "res://assets/items/Astromancy/Zenith Shard.png",
		"use_skill": &"astromancy",
	},

	# --- Mining: Stones ---
	STONE_LIMESTONE: {
		"name": "Limestone",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_limestone.png",
		"use_skill": &"mining",
	},
	STONE_SANDSTONE: {
		"name": "Sandstone",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_sandstone.png",
		"use_skill": &"mining",
	},
	STONE_BASALT: {
		"name": "Basalt",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_basalt.png",
		"use_skill": &"mining",
	},
	STONE_GRANITE: {
		"name": "Granite",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_granite.png",
		"use_skill": &"mining",
	},
	STONE_MARBLE: {
		"name": "Marble",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_marble.png",
		"use_skill": &"mining",
	},
	STONE_CLAY: {
		"name": "Clay",
		"stack": true,
		"icon": "res://assets/items/Mining/stone_clay.png",
		"use_skill": &"mining",
	},

	# --- Mining: Ores ---
	ORE_COPPER: {
		"name": "Copper Ore",
		"stack": true,
		"icon": "res://assets/icons/modifiers/copper_ore.png",
		"use_skill": &"mining",
	},
	ORE_TIN: {
		"name": "Tin Ore",
		"stack": true,
		"icon": "res://assets/icons/modifiers/tin_ore.png",
		"use_skill": &"mining",
	},
	ORE_IRON: {
		"name": "Iron Ore",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	ORE_COAL: {
		"name": "Coal",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	ORE_SILVER: {
		"name": "Silver Ore",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	ORE_GOLD: {
		"name": "Gold Ore",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	ORE_MITHRITE: {
		"name": "Mithrite Ore",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	ORE_ADAMANTITE: {
		"name": "Adamantite Ore",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	ORE_ORICHALCUM: {
		"name": "Orichalcum Ore",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	ORE_AETHER: {
		"name": "Aether Ore",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},

	# --- Mining: Gems ---
	GEM_OPAL: {
		"name": "Opal",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	GEM_JADE: {
		"name": "Jade",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	GEM_BLUE_TOPAZ: {
		"name": "Blue Topaz",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	GEM_SAPPHIRE: {
		"name": "Sapphire",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	GEM_EMERALD: {
		"name": "Emerald",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	GEM_RUBY: {
		"name": "Ruby",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	GEM_DIAMOND: {
		"name": "Diamond",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	GEM_DRAGONSTONE: {
		"name": "Dragonstone",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},
	GEM_ONYX: {
		"name": "Onyx",
		"stack": true,
		"icon": "",
		"use_skill": &"mining",
	},

	# --- Woodcutting: Logs ---
	LOG_PINE: {
		"name": "Pine Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_pine.png",
		"use_skill": &"woodcutting",
	},
	LOG_BIRCH: {
		"name": "Birch Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_birch.png",
		"use_skill": &"woodcutting",
	},
	LOG_OAK: {
		"name": "Oak Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_oak.png",
		"use_skill": &"woodcutting",
	},
	LOG_WILLOW: {
		"name": "Willow Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_willow.png",
		"use_skill": &"woodcutting",
	},
	LOG_MAPLE: {
		"name": "Maple Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_maple.png",
		"use_skill": &"woodcutting",
	},
	LOG_YEW: {
		"name": "Yew Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_yew.png",
		"use_skill": &"woodcutting",
	},
	LOG_IRONWOOD: {
		"name": "Ironwood Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_ironwood.png",
		"use_skill": &"woodcutting",
	},
	LOG_REDWOOD: {
		"name": "Redwood Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_redwood.png",
		"use_skill": &"woodcutting",
	},
	LOG_SAKURA: {
		"name": "Sakura Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_sakura.png",
		"use_skill": &"woodcutting",
	},
	LOG_ELDER: {
		"name": "Elder Logs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/log_elder.png",
		"use_skill": &"woodcutting",
	},

	# --- Woodcutting: Misc ---
	TWIGS: {
		"name": "Twigs",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/twigs.png",
		"use_skill": &"woodcutting",
	},
	BARK_SCRAP: {
		"name": "Bark Scraps",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/bark_scrap.png",
		"use_skill": &"woodcutting",
	},
	BARK: {
		"name": "Bark",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/bark.png",
		"use_skill": &"woodcutting",
	},
	RESIN_GLOB: {
		"name": "Resin Glob",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/resin_glob.png",
		"use_skill": &"woodcutting",
	},

	# --- Woodcutting: Specials ---
	BIRD_NEST: {
		"name": "Bird Nest",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/bird_nest.png",
		"use_skill": &"woodcutting",
	},
	AMBER_SAP: {
		"name": "Amber Sap",
		"stack": true,
		"icon": "res://assets/items/Woodcutting/amber_sap.png",
		"use_skill": &"woodcutting",
	},

	# --- Farming: Tree Seeds ---
	SEED_PINE: {
		"name": "Pine Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_pine.png",
		"use_skill": &"farming",
	},
	SEED_BIRCH: {
		"name": "Birch Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_birch.png",
		"use_skill": &"farming",
	},
	SEED_OAK: {
		"name": "Oak Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_oak.png",
		"use_skill": &"farming",
	},
	SEED_WILLOW: {
		"name": "Willow Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_willow.png",
		"use_skill": &"farming",
	},
	SEED_MAPLE: {
		"name": "Maple Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_maple.png",
		"use_skill": &"farming",
	},
	SEED_YEW: {
		"name": "Yew Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_yew.png",
		"use_skill": &"farming",
	},
	SEED_IRONWOOD: {
		"name": "Ironwood Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_ironwood.png",
		"use_skill": &"farming",
	},
	SEED_REDWOOD: {
		"name": "Redwood Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_redwood.png",
		"use_skill": &"farming",
	},
	SEED_SAKURA: {
		"name": "Sakura Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_sakura.png",
		"use_skill": &"farming",
	},
	SEED_ELDER: {
		"name": "Elder Seed",
		"stack": true,
		"icon": "res://assets/items/Farming/seed_elder.png",
		"use_skill": &"farming",
	},

	# --- Fishing: Junk ---
	FISHING_JUNK: {
		"name": "Fishing Junk",
		"stack": true,
		"icon": "res://assets/items/Fishing/Fishing Junk.png",
		"use_skill": &"fishing",
	},

	# --- Fishing: Net species ---
	FISH_BROOK_SHRIMP: {
		"name": "Brook Shrimp",
		"stack": true,
		"icon": "res://assets/items/Fishing/Brook Shrimp.png",
		"use_skill": &"fishing",
	},
	FISH_COAST_SPRAT: {
		"name": "Coast Sprat",
		"stack": true,
		"icon": "res://assets/items/Fishing/Coast Sprat.png",
		"use_skill": &"fishing",
	},
	FISH_GLACIER_HERRING: {
		"name": "Glacier Herring",
		"stack": true,
		"icon": "res://assets/items/Fishing/Glacier Herring.png",
		"use_skill": &"fishing",
	},
	FISH_RIVER_BLEAK: {
		"name": "River Bleak",
		"stack": true,
		"icon": "res://assets/items/Fishing/River Bleak.png",
		"use_skill": &"fishing",
	},
	FISH_SANDFLOUNDER: {
		"name": "Sandflounder",
		"stack": true,
		"icon": "res://assets/items/Fishing/Sandflounder.png",
		"use_skill": &"fishing",
	},
	FISH_SHELF_COD: {
		"name": "Shelf Cod",
		"stack": true,
		"icon": "res://assets/items/Fishing/Shelf Cod.png",
		"use_skill": &"fishing",
	},
	FISH_STRIPED_MACKEREL: {
		"name": "Striped Mackerel",
		"stack": true,
		"icon": "res://assets/items/Fishing/Striped Mackerel.png",
		"use_skill": &"fishing",
	},
	FISH_SKIPJACK_TUNA: {
		"name": "Skipjack Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Skipjack Tuna.png",
		"use_skill": &"fishing",
	},
	FISH_SUNFIN_TUNA: {
		"name": "Sunfin Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Sunfin Tuna.png",
		"use_skill": &"fishing",
	},
	FISH_NIGHT_EEL: {
		"name": "Night Eel",
		"stack": true,
		"icon": "res://assets/items/Fishing/Night Eel.png",
		"use_skill": &"fishing",
	},
	FISH_ABYSSAL_FIN: {
		"name": "Abyssal Fin",
		"stack": true,
		"icon": "res://assets/items/Fishing/Abyssal Fin.png",
		"use_skill": &"fishing",
	},

	# --- Fishing: Rod species ---
	FISH_PUDDLE_PERCH: {
		"name": "Puddle Perch",
		"stack": true,
		"icon": "res://assets/items/Fishing/Puddle Perch.png",
		"use_skill": &"fishing",
	},
	FISH_MIRROR_CARP: {
		"name": "Mirror Carp",
		"stack": true,
		"icon": "res://assets/items/Fishing/Mirror Carp.png",
		"use_skill": &"fishing",
	},
	FISH_STREAM_DACE: {
		"name": "Stream Dace",
		"stack": true,
		"icon": "res://assets/items/Fishing/Stream Dace.png",
		"use_skill": &"fishing",
	},
	FISH_BROWN_TROUT: {
		"name": "Brown Trout",
		"stack": true,
		"icon": "res://assets/items/Fishing/Brown Trout.png",
		"use_skill": &"fishing",
	},
	FISH_RIVER_CHAR: {
		"name": "River Char",
		"stack": true,
		"icon": "res://assets/items/Fishing/River Char.png",
		"use_skill": &"fishing",
	},
	FISH_SILVER_SALMON: {
		"name": "Silver Salmon",
		"stack": true,
		"icon": "res://assets/items/Fishing/Silver Salmon.png",
		"use_skill": &"fishing",
	},
	FISH_DEEPWHITE: {
		"name": "Deepwhite",
		"stack": true,
		"icon": "res://assets/items/Fishing/Deepwhite.png",
		"use_skill": &"fishing",
	},
	FISH_REED_PIKE: {
		"name": "Reed Pike",
		"stack": true,
		"icon": "res://assets/items/Fishing/Reed Pike.png",
		"use_skill": &"fishing",
	},
	FISH_MUSKFANG_PIKE: {
		"name": "Muskfang Pike",
		"stack": true,
		"icon": "res://assets/items/Fishing/Muskfang Pike.png",
		"use_skill": &"fishing",
	},
	FISH_MUDCAT: {
		"name": "Mudcat",
		"stack": true,
		"icon": "res://assets/items/Fishing/Mudcat.png",
		"use_skill": &"fishing",
	},
	FISH_KING_CARP: {
		"name": "King Carp",
		"stack": true,
		"icon": "res://assets/items/Fishing/King Carp.png",
		"use_skill": &"fishing",
	},
	FISH_MOONFANG_EEL: {
		"name": "Moonfang Eel",
		"stack": true,
		"icon": "res://assets/items/Fishing/Moonfang Eel.png",
		"use_skill": &"fishing",
	},
	FISH_RIFTFIN: {
		"name": "Riftfin",
		"stack": true,
		"icon": "res://assets/items/Fishing/Riftfin.png",
		"use_skill": &"fishing",
	},

	# --- Fishing: Harpoon species ---
	FISH_CLIFF_LOBSTER: {
		"name": "Cliff Lobster",
		"stack": true,
		"icon": "res://assets/items/Fishing/Cliff Lobster.png",
		"use_skill": &"fishing",
	},
	FISH_SAILSKIP_TUNA: {
		"name": "Sailskip Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Sailskip Tuna.png",
		"use_skill": &"fishing",
	},
	FISH_YELLOWCREST_TUNA: {
		"name": "Yellowcrest Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Yellowcrest Tuna.png",
		"use_skill": &"fishing",
	},
	FISH_AZUREFIN_TUNA: {
		"name": "Azurefin Tuna",
		"stack": true,
		"icon": "res://assets/items/Fishing/Azurefin Tuna.png",
		"use_skill": &"fishing",
	},
	FISH_SKYBLADE_MARLIN: {
		"name": "Skyblade Marlin",
		"stack": true,
		"icon": "res://assets/items/Fishing/Skyblade Marlin.png",
		"use_skill": &"fishing",
	},
	FISH_CORAL_REEF_SHARK: {
		"name": "Coral Reef Shark",
		"stack": true,
		"icon": "res://assets/items/Fishing/Coral Reef Shark.png",
		"use_skill": &"fishing",
	},
	FISH_STORM_MAKO: {
		"name": "Storm Mako",
		"stack": true,
		"icon": "res://assets/items/Fishing/Storm Mako.png",
		"use_skill": &"fishing",
	},
	FISH_DREADJAW_SHARK: {
		"name": "Dreadjaw Shark",
		"stack": true,
		"icon": "res://assets/items/Fishing/Dreadjaw Shark.png",
		"use_skill": &"fishing",
	},
	FISH_WHALEFIN_GIANT: {
		"name": "Whalefin Giant",
		"stack": true,
		"icon": "res://assets/items/Fishing/Whalefin Giant.png",
		"use_skill": &"fishing",
	},
	FISH_LEVIATHAN_WHALE: {
		"name": "Leviathan Whale",
		"stack": true,
		"icon": "res://assets/items/Fishing/Leviathan Whale.png",
		"use_skill": &"fishing",
	},
	FISH_ABYSSAL_LEVIATHAN: {
		"name": "Abyssal Leviathan",
		"stack": true,
		"icon": "res://assets/items/Fishing/Abyssal Leviathan.png",
		"use_skill": &"fishing",
	},

	# --- Smithing: Metal Bars ---
	BAR_BRONZE: {
		"name": "Bronze Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_bronze.png",
		"use_skill": &"smithing",
	},
	BAR_IRON: {
		"name": "Iron Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_iron.png",
		"use_skill": &"smithing",
	},
	BAR_STEEL: {
		"name": "Steel Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_steel.png",
		"use_skill": &"smithing",
	},
	BAR_MITHRITE: {
		"name": "Mithrite Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_mithrite.png",
		"use_skill": &"smithing",
	},
	BAR_ADAMANTITE: {
		"name": "Adamantite Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_adamantite.png",
		"use_skill": &"smithing",
	},
	BAR_ORICHALCUM: {
		"name": "Orichalcum Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_orichalcum.png",
		"use_skill": &"smithing",
	},
	BAR_AETHER: {
		"name": "Aether Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_aether.png",
		"use_skill": &"smithing",
	},
	BAR_SILVER: {
		"name": "Silver Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_silver.png",
		"use_skill": &"smithing",
	},
	BAR_GOLD: {
		"name": "Gold Bar",
		"stack": true,
		"icon": "res://assets/items/Smithing/bar_gold.png",
		"use_skill": &"smithing",
	},
	# ------------------------------------------------------------
	# Herbalism – Cooking herbs
	# ------------------------------------------------------------
	COOK_HERB_THYME_T1: {
		"name": "Thyme",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_thyme_t1.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_SAGE_T2: {
		"name": "Sage",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_sage_t2.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_FENNEL_T3: {
		"name": "Fennel",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_fennel_t3.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_ROSEMARY_T4: {
		"name": "Rosemary",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_rosemary_t4.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_LEMONGRASS_T5: {
		"name": "Lemongrass",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_lemongrass_t5.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_GINGER_T6: {
		"name": "Ginger",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_ginger_t6.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_CORIANDER_T7: {
		"name": "Coriander",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_coriander_t7.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_JUNIPER_T8: {
		"name": "Juniper",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_juniper_t8.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_OREGANO_T9: {
		"name": "Oregano",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_oregano_t9.png",
		"use_skill": &"herbalism",
	},
	COOK_HERB_STAR_ANISE_T10: {
		"name": "Star Anise",
		"stack": true,
		"icon": "res://assets/items/Herbalism/cook_herb_star_anise_t10.png",
		"use_skill": &"herbalism",
	},

	# ------------------------------------------------------------
	# Herbalism – Chemical herbs
	# ------------------------------------------------------------
	CHEM_HERB_MARSHMALLOW_ROOT_T1: {
		"name": "Marshmallow Root",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_marshmallow_root_t1.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_SEA_WORMWOOD_T2: {
		"name": "Sea Wormwood",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_sea_wormwood_t2.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_GOTU_KOLA_T3: {
		"name": "Gotu Kola",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_gotu_kola_t3.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_WATER_HEMLOCK_T4: {
		"name": "Water Hemlock",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_water_hemlock_t4.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_BITTERSWEET_NIGHTSHADE_T5: {
		"name": "Bittersweet Nightshade",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_bittersweet_nightshade_t5.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_VALERIAN_T6: {
		"name": "Valerian",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_valerian_t6.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_ALOE_VERA_T7: {
		"name": "Aloe Vera",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_aloe_vera_t7.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_FROST_KAVA_T8: {
		"name": "Frost Kava",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_frost_kava_t8.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_DATURA_T9: {
		"name": "Datura",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_datura_t9.png",
		"use_skill": &"herbalism",
	},
	CHEM_HERB_BLADDERWRACK_T10: {
		"name": "Bladderwrack",
		"stack": true,
		"icon": "res://assets/items/Herbalism/chem_herb_bladderwrack_t10.png",
		"use_skill": &"herbalism",
	},

	# ------------------------------------------------------------
	# Tailoring fibres (used by Tailoring later; dropped by Herbalism now)
	# ------------------------------------------------------------
	TAILOR_FIBRE_FLAX: {
		"name": "Flax Fibre",
		"stack": true,
		"icon": "res://assets/items/Tailoring/tailor_fibre_flax.png",
		"use_skill": &"tailoring",
	},
	TAILOR_FIBRE_SILK_COCOONS: {
		"name": "Silk Cocoons",
		"stack": true,
		"icon": "res://assets/items/Tailoring/tailor_fibre_silk_cocoons.png",
		"use_skill": &"tailoring",
	},
	TAILOR_FIBRE_COTTON: {
		"name": "Cotton Fibre",
		"stack": true,
		"icon": "res://assets/items/Tailoring/tailor_fibre_cotton.png",
		"use_skill": &"tailoring",
	},
	TAILOR_FIBRE_HEMP: {
		"name": "Hemp Fibre",
		"stack": true,
		"icon": "res://assets/items/Tailoring/tailor_fibre_hemp.png",
		"use_skill": &"tailoring",
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

# -------------------------------------------------------------------
# Use-skill + tier helpers (for CraftMenu filters)
# -------------------------------------------------------------------



const _METAL_TIER := {
	"bronze": 1,
	"iron": 2,
	"steel": 3,
	"mithrite": 4,
	"adamantite": 5,
	"orichalcum": 6,
	"aether": 7,
	# you can keep these as "future tiers" or set them to 0 if you want them untiered
	"silver": 8,
	"gold": 9,
}

# Logs / seeds (explicit because these don't encode tier in the ID)
const _WC_TIER := {
	"log_pine": 1, "seed_pine": 1,
	"log_birch": 2, "seed_birch": 2,
	"log_oak": 3, "seed_oak": 3,
	"log_willow": 4, "seed_willow": 4,
	"log_maple": 5, "seed_maple": 5,
	"log_yew": 6, "seed_yew": 6,
	"log_ironwood": 7, "seed_ironwood": 7,
	"log_redwood": 8, "seed_redwood": 8,
	"log_sakura": 9, "seed_sakura": 9,
	"log_elder": 10, "seed_elder": 10,
}

func _strip_tier_suffix(s: String) -> String:
	# supports: "thing:t3", "thing_t3", "thing_tier3"
	var colon := s.find(":")
	if colon != -1:
		return s.substr(0, colon)

	# if you ever store literal tier suffixes like _t3/_tier3 on items:
	var p := s.rfind("_tier")
	if p != -1:
		return s.substr(0, p)
	p = s.rfind("_t")
	if p != -1:
		return s.substr(0, p)

	return s

func get_tier(id: StringName) -> int:
	var raw: String = String(id)
	if raw == "":
		return 0

	# Strip ":tX" etc
	var base: String = _strip_tier_suffix(raw)

	# Explicit WC tiers
	if _WC_TIER.has(base):
		return int(_WC_TIER[base])

	# Smithing-generated ids: "<family>_<metal>"
	var info := _parse_smithing_id(StringName(base))
	if not info.is_empty():
		var mk: String = String(info.get("metal_key", ""))
		if _METAL_TIER.has(mk):
			return int(_METAL_TIER[mk])

	# Bars: bar_<metal>
	if base.begins_with("bar_"):
		var mk2 := base.replace("bar_", "")
		if _METAL_TIER.has(mk2):
			return int(_METAL_TIER[mk2])

	# Ores: ore_<metal> (optional, but useful)
	if base.begins_with("ore_"):
		var mk3 := base.replace("ore_", "")
		if _METAL_TIER.has(mk3):
			return int(_METAL_TIER[mk3])
		# copper/tin/coal aren’t in _METAL_TIER; treat as early tiered if you want:
		if mk3 == "copper" or mk3 == "tin":
			return 1
		if mk3 == "iron":
			return 2
		if mk3 == "coal":
			return 3

	# Herbalism items: cook_herb_*_tX, chem_herb_*_tX
	# Note: _strip_tier_suffix() removes _tX if you implement it that way.
	# So we detect tier from the *raw* id instead, safely.
	if raw.begins_with("cook_herb_") or raw.begins_with("chem_herb_"):
		var ti := raw.rfind("_t")
		if ti != -1 and ti + 2 < raw.length():
			var maybe := raw.substr(ti + 2, raw.length() - (ti + 2))
			var n := int(maybe)
			if n >= 1 and n <= 10:
				return n

	return 0


func is_tiered(id: StringName) -> bool:
	return get_tier(id) > 0

func get_use_skill(id: StringName) -> StringName:
	var raw: String = String(id)
	if raw == "":
		return StringName()

	var base: String = _strip_tier_suffix(raw)
	var p: String = base

	# NEW: explicit per-item tag wins (solves "poor job" tagging for defined items)
	var d: Dictionary = _defs.get(StringName(p), {}) as Dictionary
	if d.has("use_skill"):
		var uv: Variant = d.get("use_skill", &"")
		if uv is StringName:
			return uv
		if typeof(uv) == TYPE_STRING:
			var s := String(uv).strip_edges()
			if s != "":
				return StringName(s)

	# Construction buildings/modules known to ConstructionSystem
	if _is_construction_item(StringName(p)):
		return &"construction"

	# Construction materials / parts (your requirement)
	if p.begins_with("cut_log_") or p.begins_with("cut_stone_") or p.begins_with("mat_"):
		return &"construction"
	if p.begins_with("frame") or p.begins_with("wall_") or p.begins_with("floor_") or p.begins_with("roof_") \
	or p.begins_with("door_") or p.begins_with("window_"):
		return &"construction"

	# Raw resources → their gathering skill (useful for filtering outputs in other menus)
	if p.begins_with("log_") or p == "twigs" or p.begins_with("bark") or p.begins_with("resin") or p.begins_with("amber_"):
		return &"woodcutting"
	if p.begins_with("stone_") or p.begins_with("ore_") or p.begins_with("gem_"):
		return &"mining"
	if p.begins_with("fish_") or p.begins_with("fishing_"):
		return &"fishing"

	# Smithing-generated gear: decide by FAMILY (this is the key part you want)
	var info := _parse_smithing_id(StringName(p))
	if not info.is_empty():
		var family_key: String = String(info.get("family_key", ""))

		# Tools used for gathering
		if family_key == "axe":
			return &"woodcutting"
		if family_key == "pickaxe":
			return &"mining"
		if family_key == "sickle":
			return &"herbalism"
		if family_key == "hoe":
			return &"farming"
		if family_key == "fishing_net" or family_key == "fishing_rod" or family_key == "fishing_harpoon":
			return &"fishing"

		# Construction hardware should count as Construction (your requirement)
		if _SMITHING_FAMILY_GROUP.has(family_key) and String(_SMITHING_FAMILY_GROUP[family_key]) == "hardware":
			return &"construction"

		# Weapons/armour → combat
		if _SMITHING_FAMILY_GROUP.has(family_key):
			var g: String = String(_SMITHING_FAMILY_GROUP[family_key])
			if g == "weapon" or g == "armour":
				return &"combat"

		# Everything else produced by smithing, but "used for" smithing itself (fallback)
		return &"smithing"

	return StringName()
