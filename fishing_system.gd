# res://autoloads/FishingSystem.gd
extends Node

## FishingSystem:
## - Static fishing node definitions (level req, XP, fish tables, junk, etc.).
## - Single-action API (do_fish) similar to MiningSystem.do_mine / WoodcuttingSystem.do_chop.
## - Handles success/junk, rolls grade, picks a fish by weighted table.
## - Does NOT award XP directly – it returns xp/time/items so caller can apply XP.

const ITEMS := preload("res://scripts/autoload/items.gd")

# Core pacing – keep in line with Mining / Woodcutting
const BASE_ACTION_TIME := 2.4  # seconds per fishing action

# Simple XP curve by grade (tweak to match MiningSystem if needed)
const XP_BY_GRADE := {
	1: 6,
	2: 10,
	3: 16,
	4: 24,
	5: 36,
	6: 52,
	7: 72,
	8: 96,
	9: 128,
	10: 170,
}



var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()


# -------------------------------------------------------------------
# Node definitions
# -------------------------------------------------------------------
# Each node:
#  - display_name: shown in UI (Riverbank Shallows, etc.)
#  - family: "net", "rod", or "harpoon"
#  - req_level: minimum Fishing level to use effectively
#  - base_junk: base junk chance at req_level (falls to 2% at +15 Lv)
#  - max_grade: highest grade (F1–F10) this node can roll
#  - species_by_grade: { grade: [ {fish, weight}, ... ] }
#
# Fish IDs are ITEMS.FISH_* constants you define in items.gd

const FISH_NODES := {
	# ---------------------------------------------------------------
	# NET FAMILY (N1–N10)
	# ---------------------------------------------------------------
	"N1": {
		"display_name": "Riverbank Shallows",
		"family": "net",
		"req_level": 1,
		"base_junk": 0.40,
		"max_grade": 2,
		"species_by_grade": {
			1: [
				{ "fish": ITEMS.FISH_BROOK_SHRIMP,  "weight": 80 },
				{ "fish": ITEMS.FISH_COAST_SPRAT,   "weight": 20 },
			],
			2: [
				{ "fish": ITEMS.FISH_COAST_SPRAT,   "weight": 100 },
			],
		},
	},
	"N2": {
		"display_name": "Rocky Estuary Nets",
		"family": "net",
		"req_level": 10,
		"base_junk": 0.38,
		"max_grade": 2,
		"species_by_grade": {
			1: [
				{ "fish": ITEMS.FISH_BROOK_SHRIMP,  "weight": 50 },
				{ "fish": ITEMS.FISH_RIVER_BLEAK,   "weight": 50 },
			],
			2: [
				{ "fish": ITEMS.FISH_COAST_SPRAT,   "weight": 60 },
				{ "fish": ITEMS.FISH_RIVER_BLEAK,   "weight": 40 },
			],
		},
	},
	"N3": {
		"display_name": "Cenote Rim Nets",
		"family": "net",
		"req_level": 20,
		"base_junk": 0.36,
		"max_grade": 4,
		"species_by_grade": {
			2: [
				{ "fish": ITEMS.FISH_GLACIER_HERRING, "weight": 80 },
				{ "fish": ITEMS.FISH_SANDFLOUNDER,    "weight": 20 },
			],
			4: [
				{ "fish": ITEMS.FISH_SANDFLOUNDER,    "weight": 70 },
				{ "fish": ITEMS.FISH_GLACIER_HERRING, "weight": 30 },
			],
		},
	},
	"N4": {
		"display_name": "Cascade Shelf Nets",
		"family": "net",
		"req_level": 30,
		"base_junk": 0.34,
		"max_grade": 4,
		"species_by_grade": {
			2: [
				{ "fish": ITEMS.FISH_COAST_SPRAT,      "weight": 80 },
				{ "fish": ITEMS.FISH_STRIPED_MACKEREL, "weight": 20 },
			],
			4: [
				{ "fish": ITEMS.FISH_STRIPED_MACKEREL, "weight": 80 },
				{ "fish": ITEMS.FISH_COAST_SPRAT,      "weight": 20 },
			],
		},
	},
	"N5": {
		"display_name": "Floodplain Reed Nets",
		"family": "net",
		"req_level": 40,
		"base_junk": 0.32,
		"max_grade": 4,
		"species_by_grade": {
			4: [
				{ "fish": ITEMS.FISH_SHELF_COD,      "weight": 60 },
				{ "fish": ITEMS.FISH_SANDFLOUNDER,   "weight": 40 },
			],
		},
	},
	"N6": {
		"display_name": "Gorge Ledge Nets",
		"family": "net",
		"req_level": 50,
		"base_junk": 0.30,
		"max_grade": 7,
		"species_by_grade": {
			4: [
				{ "fish": ITEMS.FISH_SHELF_COD,        "weight": 70 },
				{ "fish": ITEMS.FISH_STRIPED_MACKEREL, "weight": 30 },
			],
			7: [
				{ "fish": ITEMS.FISH_SKIPJACK_TUNA,    "weight": 70 },
				{ "fish": ITEMS.FISH_STRIPED_MACKEREL, "weight": 30 },
			],
		},
	},
	"N7": {
		"display_name": "Hanging Oasis Nets",
		"family": "net",
		"req_level": 60,
		"base_junk": 0.28,
		"max_grade": 7,
		"species_by_grade": {
			4: [
				{ "fish": ITEMS.FISH_STRIPED_MACKEREL, "weight": 100 },
			],
			7: [
				{ "fish": ITEMS.FISH_SKIPJACK_TUNA,    "weight": 70 },
				{ "fish": ITEMS.FISH_STRIPED_MACKEREL, "weight": 30 },
			],
		},
	},
	"N8": {
		"display_name": "Ice-Crack Nets",
		"family": "net",
		"req_level": 70,
		"base_junk": 0.26,
		"max_grade": 8,
		"species_by_grade": {
			7: [
				{ "fish": ITEMS.FISH_SUNFIN_TUNA, "weight": 70 },
				{ "fish": ITEMS.FISH_NIGHT_EEL,   "weight": 30 },
			],
			8: [
				{ "fish": ITEMS.FISH_NIGHT_EEL,   "weight": 80 },
				{ "fish": ITEMS.FISH_SUNFIN_TUNA, "weight": 20 },
			],
		},
	},
	"N9": {
		"display_name": "Boiling Runoff Nets",
		"family": "net",
		"req_level": 80,
		"base_junk": 0.24,
		"max_grade": 9,
		"species_by_grade": {
			8: [
				{ "fish": ITEMS.FISH_NIGHT_EEL,   "weight": 60 },
				{ "fish": ITEMS.FISH_ABYSSAL_FIN, "weight": 40 },
			],
			9: [
				{ "fish": ITEMS.FISH_ABYSSAL_FIN, "weight": 90 },
				{ "fish": ITEMS.FISH_NIGHT_EEL,   "weight": 10 },
			],
		},
	},
	"N10": {
		"display_name": "Starsea Surface Nets",
		"family": "net",
		"req_level": 90,
		"base_junk": 0.22,
		"max_grade": 9,
		"species_by_grade": {
			8: [
				{ "fish": ITEMS.FISH_ABYSSAL_FIN, "weight": 80 },
				{ "fish": ITEMS.FISH_NIGHT_EEL,   "weight": 20 },
			],
			9: [
				{ "fish": ITEMS.FISH_ABYSSAL_FIN, "weight": 96 },
				{ "fish": ITEMS.FISH_NIGHT_EEL,   "weight": 4 },
			],
		},
	},

	# ---------------------------------------------------------------
	# ROD FAMILY (R1–R10)
	# (only uses grades F1, F2, F3, F4, F5, F9)
	# ---------------------------------------------------------------
	"R1": {
		"display_name": "Minnow Ford Pool",
		"family": "rod",
		"req_level": 1,
		"base_junk": 0.40,
		"max_grade": 2,
		"species_by_grade": {
			1: [
				{ "fish": ITEMS.FISH_PUDDLE_PERCH, "weight": 80 },
				{ "fish": ITEMS.FISH_MIRROR_CARP,  "weight": 20 },
			],
			2: [
				{ "fish": ITEMS.FISH_MIRROR_CARP,  "weight": 70 },
				{ "fish": ITEMS.FISH_PUDDLE_PERCH, "weight": 30 },
			],
		},
	},
	"R2": {
		"display_name": "Brackwater Channel",
		"family": "rod",
		"req_level": 10,
		"base_junk": 0.38,
		"max_grade": 3,
		"species_by_grade": {
			1: [
				{ "fish": ITEMS.FISH_PUDDLE_PERCH, "weight": 60 },
				{ "fish": ITEMS.FISH_MIRROR_CARP,  "weight": 40 },
			],
			2: [
				{ "fish": ITEMS.FISH_MIRROR_CARP,  "weight": 60 },
				{ "fish": ITEMS.FISH_PUDDLE_PERCH, "weight": 40 },
			],
			3: [
				{ "fish": ITEMS.FISH_REED_PIKE,    "weight": 70 },
				{ "fish": ITEMS.FISH_MIRROR_CARP,  "weight": 30 },
			],
		},
	},
	"R3": {
		"display_name": "Sinkhole Plunge Pool",
		"family": "rod",
		"req_level": 20,
		"base_junk": 0.36,
		"max_grade": 4,
		"species_by_grade": {
			2: [
				{ "fish": ITEMS.FISH_STREAM_DACE,  "weight": 80 },
				{ "fish": ITEMS.FISH_PUDDLE_PERCH, "weight": 20 },
			],
			3: [
				{ "fish": ITEMS.FISH_BROWN_TROUT,  "weight": 70 },
				{ "fish": ITEMS.FISH_STREAM_DACE,  "weight": 30 },
			],
			4: [
				{ "fish": ITEMS.FISH_BROWN_TROUT,  "weight": 80 },
				{ "fish": ITEMS.FISH_REED_PIKE,    "weight": 20 },
			],
		},
	},
	"R4": {
		"display_name": "Echofall Basin",
		"family": "rod",
		"req_level": 30,
		"base_junk": 0.34,
		"max_grade": 5,
		"species_by_grade": {
			3: [
				{ "fish": ITEMS.FISH_STREAM_DACE,  "weight": 40 },
				{ "fish": ITEMS.FISH_BROWN_TROUT,  "weight": 60 },
			],
			4: [
				{ "fish": ITEMS.FISH_RIVER_CHAR,   "weight": 70 },
				{ "fish": ITEMS.FISH_SILVER_SALMON,"weight": 30 },
			],
			5: [
				{ "fish": ITEMS.FISH_SILVER_SALMON,"weight": 70 },
				{ "fish": ITEMS.FISH_RIVER_CHAR,   "weight": 30 },
			],
		},
	},
	"R5": {
		"display_name": "Oxbow Bend Pool",
		"family": "rod",
		"req_level": 40,
		"base_junk": 0.32,
		"max_grade": 5,
		"species_by_grade": {
			3: [
				{ "fish": ITEMS.FISH_STREAM_DACE,  "weight": 40 },
				{ "fish": ITEMS.FISH_BROWN_TROUT,  "weight": 60 },
			],
			4: [
				{ "fish": ITEMS.FISH_RIVER_CHAR,   "weight": 50 },
				{ "fish": ITEMS.FISH_REED_PIKE,    "weight": 50 },
			],
			5: [
				{ "fish": ITEMS.FISH_SILVER_SALMON,"weight": 50 },
				{ "fish": ITEMS.FISH_REED_PIKE,    "weight": 50 },
			],
		},
	},
	"R6": {
		"display_name": "Mistfall Tailwater",
		"family": "rod",
		"req_level": 50,
		"base_junk": 0.30,
		"max_grade": 5,
		"species_by_grade": {
			4: [
				{ "fish": ITEMS.FISH_DEEPWHITE,   "weight": 60 },
				{ "fish": ITEMS.FISH_RIVER_CHAR,  "weight": 40 },
			],
			5: [
				{ "fish": ITEMS.FISH_MUSKFANG_PIKE,"weight": 60 },
				{ "fish": ITEMS.FISH_DEEPWHITE,    "weight": 40 },
			],
		},
	},
	"R7": {
		"display_name": "Mirror Spring Pool",
		"family": "rod",
		"req_level": 60,
		"base_junk": 0.28,
		"max_grade": 5,
		"species_by_grade": {
			4: [
				{ "fish": ITEMS.FISH_KING_CARP, "weight": 70 },
				{ "fish": ITEMS.FISH_MUDCAT,    "weight": 30 },
			],
			5: [
				{ "fish": ITEMS.FISH_MUDCAT,    "weight": 60 },
				{ "fish": ITEMS.FISH_KING_CARP, "weight": 40 },
			],
		},
	},
	"R8": {
		"display_name": "Black Tarn Hole",
		"family": "rod",
		"req_level": 70,
		"base_junk": 0.26,
		"max_grade": 5,
		"species_by_grade": {
			5: [
				{ "fish": ITEMS.FISH_SILVER_SALMON, "weight": 60 },
				{ "fish": ITEMS.FISH_RIVER_CHAR,    "weight": 30 },
				{ "fish": ITEMS.FISH_MOONFANG_EEL,  "weight": 10 },
			],
		},
	},
	"R9": {
		"display_name": "Geyser Cone Pool",
		"family": "rod",
		"req_level": 80,
		"base_junk": 0.24,
		"max_grade": 9,
		"species_by_grade": {
			9: [
				{ "fish": ITEMS.FISH_RIFTFIN,       "weight": 90 },
				{ "fish": ITEMS.FISH_MOONFANG_EEL,  "weight": 10 },
			],
		},
	},
	"R10": {
		"display_name": "Comet-Eddy Pool",
		"family": "rod",
		"req_level": 90,
		"base_junk": 0.22,
		"max_grade": 9,
		"species_by_grade": {
			9: [
				{ "fish": ITEMS.FISH_RIFTFIN,       "weight": 96 },
				{ "fish": ITEMS.FISH_MOONFANG_EEL,  "weight": 4 },
			],
		},
	},

	# ---------------------------------------------------------------
	# HARPOON FAMILY (H1–H10)
	# (grades F5, F6, F7, F9, F10)
	# ---------------------------------------------------------------
	"H1": {
		"display_name": "Deep Crossing Run",
		"family": "harpoon",
		"req_level": 20,
		"base_junk": 0.36,
		"max_grade": 5,
		"species_by_grade": {
			5: [
				{ "fish": ITEMS.FISH_CLIFF_LOBSTER, "weight": 60 },
				{ "fish": ITEMS.FISH_SAILSKIP_TUNA, "weight": 40 },
			],
		},
	},
	"H2": {
		"display_name": "Tidecut Passage",
		"family": "harpoon",
		"req_level": 30,
		"base_junk": 0.34,
		"max_grade": 6,
		"species_by_grade": {
			5: [
				{ "fish": ITEMS.FISH_SAILSKIP_TUNA, "weight": 70 },
				{ "fish": ITEMS.FISH_CLIFF_LOBSTER, "weight": 30 },
			],
			6: [
				{ "fish": ITEMS.FISH_YELLOWCREST_TUNA, "weight": 60 },
				{ "fish": ITEMS.FISH_CORAL_REEF_SHARK, "weight": 40 },
			],
		},
	},
	"H3": {
		"display_name": "Blue Well Drop",
		"family": "harpoon",
		"req_level": 40,
		"base_junk": 0.32,
		"max_grade": 7,
		"species_by_grade": {
			6: [
				{ "fish": ITEMS.FISH_YELLOWCREST_TUNA, "weight": 60 },
				{ "fish": ITEMS.FISH_SKYBLADE_MARLIN,  "weight": 40 },
			],
			7: [
				{ "fish": ITEMS.FISH_CORAL_REEF_SHARK, "weight": 70 },
				{ "fish": ITEMS.FISH_SKYBLADE_MARLIN,  "weight": 30 },
			],
		},
	},
	"H4": {
		"display_name": "Thunder Gorge Throat",
		"family": "harpoon",
		"req_level": 50,
		"base_junk": 0.30,
		"max_grade": 7,
		"species_by_grade": {
			6: [
				{ "fish": ITEMS.FISH_SKYBLADE_MARLIN,  "weight": 60 },
				{ "fish": ITEMS.FISH_YELLOWCREST_TUNA, "weight": 40 },
			],
			7: [
				{ "fish": ITEMS.FISH_STORM_MAKO,       "weight": 50 },
				{ "fish": ITEMS.FISH_CORAL_REEF_SHARK, "weight": 50 },
			],
		},
	},
	"H5": {
		"display_name": "Leviathan Channel",
		"family": "harpoon",
		"req_level": 60,
		"base_junk": 0.28,
		"max_grade": 7,
		"species_by_grade": {
			6: [
				{ "fish": ITEMS.FISH_YELLOWCREST_TUNA, "weight": 40 },
				{ "fish": ITEMS.FISH_STORM_MAKO,       "weight": 60 },
			],
			7: [
				{ "fish": ITEMS.FISH_STORM_MAKO,       "weight": 70 },
				{ "fish": ITEMS.FISH_SKYBLADE_MARLIN,  "weight": 30 },
			],
		},
	},
	"H6": {
		"display_name": "Chasm Surge Run",
		"family": "harpoon",
		"req_level": 70,
		"base_junk": 0.26,
		"max_grade": 7,
		"species_by_grade": {
			7: [
				{ "fish": ITEMS.FISH_STORM_MAKO,       "weight": 60 },
				{ "fish": ITEMS.FISH_AZUREFIN_TUNA,    "weight": 40 },
			],
		},
	},
	"H7": {
		"display_name": "Skywell Sink",
		"family": "harpoon",
		"req_level": 80,
		"base_junk": 0.24,
		"max_grade": 9,
		"species_by_grade": {
			7: [
				{ "fish": ITEMS.FISH_AZUREFIN_TUNA,    "weight": 60 },
				{ "fish": ITEMS.FISH_STORM_MAKO,       "weight": 40 },
			],
			9: [
				{ "fish": ITEMS.FISH_DREADJAW_SHARK,   "weight": 60 },
				{ "fish": ITEMS.FISH_AZUREFIN_TUNA,    "weight": 40 },
			],
		},
	},
	"H8": {
		"display_name": "Glacier Rift Wake",
		"family": "harpoon",
		"req_level": 85,
		"base_junk": 0.22,
		"max_grade": 9,
		"species_by_grade": {
			7: [
				{ "fish": ITEMS.FISH_STORM_MAKO,       "weight": 40 },
				{ "fish": ITEMS.FISH_DREADJAW_SHARK,   "weight": 60 },
			],
			9: [
				{ "fish": ITEMS.FISH_DREADJAW_SHARK,   "weight": 60 },
				{ "fish": ITEMS.FISH_WHALEFIN_GIANT,   "weight": 40 },
			],
		},
	},
	"H9": {
		"display_name": "Steamvent Pit",
		"family": "harpoon",
		"req_level": 90,
		"base_junk": 0.20,
		"max_grade": 9,
		"species_by_grade": {
			9: [
				{ "fish": ITEMS.FISH_ABYSSAL_LEVIATHAN,"weight": 60 },
				{ "fish": ITEMS.FISH_WHALEFIN_GIANT,   "weight": 25 },
				{ "fish": ITEMS.FISH_DREADJAW_SHARK,   "weight": 15 },
			],
		},
	},
	"H10": {
		"display_name": "Abyssal Star Trench",
		"family": "harpoon",
		"req_level": 95,
		"base_junk": 0.18,
		"max_grade": 10,
		"species_by_grade": {
			9: [
				{ "fish": ITEMS.FISH_ABYSSAL_LEVIATHAN,"weight": 70 },
				{ "fish": ITEMS.FISH_DREADJAW_SHARK,   "weight": 20 },
				{ "fish": ITEMS.FISH_WHALEFIN_GIANT,   "weight": 10 },
			],
			10: [
				{ "fish": ITEMS.FISH_LEVIATHAN_WHALE,  "weight": 40 },
				{ "fish": ITEMS.FISH_ABYSSAL_LEVIATHAN,"weight": 40 },
				{ "fish": ITEMS.FISH_WHALEFIN_GIANT,   "weight": 15 },
				{ "fish": ITEMS.FISH_DREADJAW_SHARK,   "weight": 5 },
			],
		},
	},
}


# -------------------------------------------------------------------
# Public API
# -------------------------------------------------------------------

func get_node_def(node_id: StringName) -> Dictionary:
	return FISH_NODES.get(node_id, {})

func get_drop_preview_for_node(node_id: StringName, fishing_level: int) -> Array:
	var node: Dictionary = FISH_NODES.get(node_id, {})
	if node.is_empty():
		return []

	var req_level: int = int(node.get("req_level", 1))
	var base_junk: float = float(node.get("base_junk", 0.0))
	var max_grade: int = int(node.get("max_grade", 1))
	var species_by_grade: Dictionary = node.get("species_by_grade", {})

	# Estimate the grade this villager will usually roll
	var grade: int = _estimate_grade_for_level(fishing_level, max_grade)

	# Find the nearest lower/equal grade that actually has a table
	var g := grade
	while g > 0 and not species_by_grade.has(g):
		g -= 1

	var preview: Array = []

	if g > 0:
		var entries: Array = species_by_grade[g]
		var total_weight := 0
		for e_v in entries:
			if e_v is Dictionary:
				var e: Dictionary = e_v
				total_weight += int(e.get("weight", 0))

		if total_weight > 0:
			for e_v in entries:
				if not (e_v is Dictionary):
					continue
				var e: Dictionary = e_v
				var w: int = int(e.get("weight", 0))
				if w <= 0:
					continue
				var chance: float = float(w) / float(total_weight)
				var fish_id: StringName = e.get("fish", StringName(""))

				preview.append({
					"item_id": fish_id,
					"qty": 1,
					"chance": chance,
					"is_fail": false,
				})

	# Junk chance (shown as junk, not “Fail”)
	var junk_chance: float = _compute_junk_chance(fishing_level, req_level, base_junk)
	if junk_chance > 0.0:
		preview.append({
			"item_id": ITEMS.FISHING_JUNK,
			"qty": 1,
			"chance": junk_chance,
			"is_fail": false,
		})

	return preview


func do_fish(
	node_id: StringName,
	fishing_level: int,
	effective_grade: int = -1
) -> Dictionary:
	## Main entry point – called once per fishing action.
	## Returns:
	##  {
	##    "xp": int,
	##    "time": float,
	##    "items": Array[StringName],
	##    "junk": bool,
	##    "grade": int,
	##    "node_id": StringName,
	##    "loot_desc": String,
	##  }

	var node: Dictionary = FISH_NODES.get(node_id, {}) as Dictionary
	if node.is_empty():
		push_warning("FishingSystem: unknown node_id %s" % [node_id])
		return {
			"xp": 0,
			"time": BASE_ACTION_TIME,
			"items": [],
			"junk": true,
			"grade": 0,
			"node_id": node_id,
			"loot_desc": "No catch.",
		}

	var req_level: int = int(node["req_level"])
	var max_grade: int = int(node["max_grade"])
	var base_junk: float = float(node["base_junk"])

	# Too low level: auto-junk, zero XP
	if fishing_level < req_level:
		var junk_items: Array = [ITEMS.FISHING_JUNK]

		# Resolve display name for junk (for log / loot_desc)
		var junk_name := "Junk"
		if typeof(Items) != TYPE_NIL \
		and Items.has_method("is_valid") \
		and Items.has_method("display_name") \
		and Items.is_valid(ITEMS.FISHING_JUNK):
			junk_name = Items.display_name(ITEMS.FISHING_JUNK)

		# Add junk to bank
		if typeof(Bank) != TYPE_NIL and Bank.has_method("add"):
			for item_id in junk_items:
				Bank.add(item_id, 1)

		return {
			"xp": 0,
			"time": BASE_ACTION_TIME,
			"items": junk_items,
			"junk": true,
			"grade": 0,
			"node_id": node_id,
			"loot_desc": "Caught %s (too low level)." % junk_name,
		}

	# Determine grade to roll
	var grade := 0
	if effective_grade > 0:
		grade = clamp(effective_grade, 1, max_grade)
	else:
		grade = _estimate_grade_for_level(fishing_level, max_grade)

	# Compute junk chance, then decide junk vs fish
	var junk_chance := _compute_junk_chance(fishing_level, req_level, base_junk)
	var is_junk := _rng.randf() < junk_chance

	var items: Array = []
	if is_junk:
		items.append(ITEMS.FISHING_JUNK)
	else:
		var fish_id: StringName = _pick_fish_for_grade(node["species_by_grade"], grade)
		if fish_id != StringName():
			items.append(fish_id)
		else:
			# If something went wrong, fall back to junk
			items.append(ITEMS.FISHING_JUNK)
			is_junk = true

	# Base XP by grade (you can decide whether junk should give XP; this version does)
	var xp: int = int(XP_BY_GRADE.get(grade, 0))

	# Add items to Bank and build loot_desc
	var parts: Array[String] = []
	for item_id in items:
		# Add to bank (1 each for now – extend later if you add stack sizes)
		if typeof(Bank) != TYPE_NIL and Bank.has_method("add"):
			Bank.add(item_id, 1)

		var name := String(item_id)
		if typeof(Items) != TYPE_NIL \
		and Items.has_method("is_valid") \
		and Items.has_method("display_name") \
		and Items.is_valid(item_id):
			name = Items.display_name(item_id)


		parts.append("1× %s" % name)

	var loot_desc := ""
	if parts.is_empty():
		loot_desc = "Caught nothing."
	elif is_junk:
		loot_desc = "Caught %s." % ", ".join(parts)
	else:
		loot_desc = "Caught %s." % ", ".join(parts)

	return {
		"xp": xp,
		"time": BASE_ACTION_TIME,
		"items": items,
		"junk": is_junk,
		"grade": grade,
		"node_id": node_id,
		"loot_desc": loot_desc,
	}


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

func _estimate_grade_for_level(level: int, max_grade: int) -> int:
	# Very simple: 10 levels per grade, clamped to node max.
	# Lv 1–9 -> F1, 10–19 -> F2, etc.
	var guessed := int(ceil(level / 10.0))
	return clamp(guessed, 1, max_grade)


func _compute_junk_chance(
	fishing_level: int,
	req_level: int,
	base_junk: float
) -> float:
	# At req_level      -> base_junk (e.g. 0.30–0.40)
	# At req_level +15  -> 0.02
	# Between: linear interpolation, below: clamp to base_junk

	if fishing_level <= req_level:
		return base_junk

	var above: float = float(fishing_level - req_level)
	var t: float = clampf(above / 15.0, 0.0, 1.0)
	return lerpf(base_junk, 0.02, t)


func _pick_fish_for_grade(
	species_by_grade: Dictionary,
	grade: int
) -> StringName:
	# If this exact grade has no table, walk downwards until we find one.
	var g := grade
	while g > 0 and not species_by_grade.has(g):
		g -= 1

	if g <= 0:
		return StringName()

	var entries: Array = species_by_grade[g]
	if entries.is_empty():
		return StringName()

	# Weighted random selection
	var total_weight := 0
	for e in entries:
		total_weight += int(e["weight"])

	if total_weight <= 0:
		return StringName()

	var roll := _rng.randi_range(1, total_weight)
	var running := 0
	for e in entries:
		running += int(e["weight"])
		if roll <= running:
			return e["fish"]

	return StringName()
