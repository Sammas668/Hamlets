# res://autoloads/HerbalismSystem.gd
extends Node

## HerbalismSystem:
## - Patch definitions are DATA-DRIVEN via PATCH_ROWS (easy add/remove).
## - Per-tile quick charges + regrow timers (Mining-style).
## - Gather choice:
##     • Careful Pick: 2 actions, steady yield, DOES NOT consume charges.
##     • Quick Pick:   1 action, 5× yield, consumes 1 quick charge.
## - When quick charges hit 0: patch enters long regrow; patch is unavailable until regrow completes.

const BASE_ACTION_TIME := 2.4

# -------------------------------------------------------------------
# Tuning
# -------------------------------------------------------------------

const CAREFUL_ACTIONS := 2
const QUICK_ACTIONS := 1
const CAREFUL_QTY := 1
const QUICK_YIELD_MULT := 5

# Tier-based tuning (still used for cook/chem tiers and for patch tier “feel”)
const REQ_BY_TIER := {
	1: 1,  2: 11, 3: 21, 4: 31, 5: 41,
	6: 51, 7: 61, 8: 71, 9: 81, 10: 91,
}

const XP_BY_TIER := {
	1: 6,   2: 10,  3: 16,  4: 24,  5: 34,
	6: 48,  7: 66,  8: 90,  9: 125, 10: 170,
}

const QUICK_CHARGES_BY_TIER := {
	1: 20, 2: 18, 3: 16, 4: 14, 5: 12,
	6: 10, 7: 9,  8: 8,  9: 7,  10: 6,
}

const REGROW_S_BY_TIER := {
	1: 120.0, 2: 150.0, 3: 180.0, 4: 210.0, 5: 240.0,
	6: 300.0, 7: 360.0, 8: 420.0, 9: 480.0, 10: 600.0,
}

# -------------------------------------------------------------------
# Item IDs (cook/chem remain tiered; fibre is ONLY 4 items)
# -------------------------------------------------------------------

const COOK_HERB_BY_TIER := {
	1: &"cook_herb_thyme_t1",
	2: &"cook_herb_sage_t2",
	3: &"cook_herb_fennel_t3",
	4: &"cook_herb_rosemary_t4",
	5: &"cook_herb_lemongrass_t5",
	6: &"cook_herb_ginger_t6",
	7: &"cook_herb_coriander_t7",
	8: &"cook_herb_juniper_t8",
	9: &"cook_herb_oregano_t9",
	10: &"cook_herb_star_anise_t10",
}

const CHEM_HERB_BY_TIER := {
	1: &"chem_herb_marshmallow_root_t1",
	2: &"chem_herb_sea_wormwood_t2",
	3: &"chem_herb_gotu_kola_t3",
	4: &"chem_herb_water_hemlock_t4",
	5: &"chem_herb_bittersweet_nightshade_t5",
	6: &"chem_herb_valerian_t6",
	7: &"chem_herb_aloe_vera_t7",
	8: &"chem_herb_frost_kava_t8",
	9: &"chem_herb_datura_t9",
	10: &"chem_herb_bladderwrack_t10",
}

# ONLY 4 fibre items (renamed IDs to reflect actual names)
const FIBRE_FLAX        : StringName = &"flax_fibre"
const FIBRE_SILK_COCOON : StringName = &"silk_cocoons"
const FIBRE_COTTON      : StringName = &"cotton_fibre"
const FIBRE_HEMP        : StringName = &"hemp_fibre"

# Used as the “15% fibre” in cook/chem patches (still tier-shaped, but only 4 items)
func _fibre_for_tier(tier: int) -> StringName:
	if tier <= 2:
		return FIBRE_FLAX
	if tier <= 5:
		return FIBRE_SILK_COCOON
	if tier <= 8:
		return FIBRE_COTTON
	return FIBRE_HEMP

# -------------------------------------------------------------------
# Patch definitions (easy add/remove: edit PATCH_ROWS only)
# -------------------------------------------------------------------

var PATCHES: Dictionary = {}
var _label_to_patch_id: Dictionary = {}

# Each row:
# {
#   "id": StringName,            # ✅ MUST match label (slug form)
#   "group": "cook"|"chem"|"fibre",
#   "tier": int,                 # affects xp/charges/regrow + secondary drops
#   "req": int,                  # unlock level (explicit so you can skip tiers)
#   "label": String,             # MUST match your modifier display string
#   "primary": StringName?       # ONLY needed for fibre patches (explicit fibre item)
# }

const PATCH_ROWS := [
	# -----------------------------
	# Cooking band (primary cook herb)
	# IDs now reflect the label (slug)
	# -----------------------------
	{ "id": &"forest_thyme_plot",                     "group": "cook",  "tier": 1,  "req": 1,  "label": "Forest Thyme Plot" },
	{ "id": &"maplewood_vale_sage_plot",              "group": "cook",  "tier": 2,  "req": 11, "label": "Maplewood Vale Sage Plot" },
	{ "id": &"silkwood_fennel_ring",                  "group": "cook",  "tier": 3,  "req": 21, "label": "Silkwood Fennel Ring" },
	{ "id": &"cloudpine_terraces_rosemary_bed",       "group": "cook",  "tier": 4,  "req": 31, "label": "Cloudpine Terraces Rosemary Bed" },
	{ "id": &"baobab_savanna_lemongrass_patch",       "group": "cook",  "tier": 5,  "req": 41, "label": "Baobab Savanna Lemongrass Patch" },
	{ "id": &"rainforest_highwood_ginger_canopy",     "group": "cook",  "tier": 6,  "req": 51, "label": "Rainforest Highwood Ginger Canopy" },
	{ "id": &"incense_groves_coriander_scrub",        "group": "cook",  "tier": 7,  "req": 61, "label": "Incense Groves Coriander Scrub" },
	{ "id": &"boreal_ridge_juniper_bed",              "group": "cook",  "tier": 8,  "req": 71, "label": "Boreal Ridge Juniper Bed" },
	{ "id": &"ashfield_cinderwood_oregano_patch",     "group": "cook",  "tier": 9,  "req": 81, "label": "Ashfield Cinderwood Oregano Patch" },
	{ "id": &"celestial_grove_star_anise_scar",       "group": "cook",  "tier": 10, "req": 91, "label": "Celestial Grove Star Anise Scar" },

	# -----------------------------
	# Chemical band (primary chem herb)
	# IDs now reflect the label (slug)
	# -----------------------------
	{ "id": &"river_marshmallow_root_reeds",          "group": "chem",  "tier": 1,  "req": 1,  "label": "River Marshmallow Root Reeds" },
	{ "id": &"rocky_estuary_sea_wormwood_reeds",      "group": "chem",  "tier": 2,  "req": 11, "label": "Rocky Estuary Sea Wormwood Reeds" },
	{ "id": &"cenote_sinkholes_gotu_kola_ledge",      "group": "chem",  "tier": 3,  "req": 21, "label": "Cenote Sinkholes Gotu Kola Ledge" },
	{ "id": &"karst_cascade_gorge_water_hemlock_shelf","group": "chem", "tier": 4,  "req": 31, "label": "Karst Cascade Gorge Water Hemlock Shelf" },
	{ "id": &"floodplain_bittersweet_nightshade_channel","group":"chem","tier": 5,  "req": 41, "label": "Floodplain Bittersweet Nightshade Channel" },
	{ "id": &"river_gorge_valerian_shelf",            "group": "chem",  "tier": 6,  "req": 51, "label": "River Gorge Valerian Shelf" },
	{ "id": &"floating_oasis_aloe_garden",            "group": "chem",  "tier": 7,  "req": 61, "label": "Floating Oasis Aloe Garden" },
	{ "id": &"frozen_tarn_frost_kava_ledge",          "group": "chem",  "tier": 8,  "req": 71, "label": "Frozen Tarn Frost Kava Ledge" },
	{ "id": &"drakefire_geyser_datura_beds",          "group": "chem",  "tier": 9,  "req": 81, "label": "Drakefire Geyser Datura Beds" },
	{ "id": &"starsea_rift_bladderwrack_kelpfield",   "group": "chem",  "tier": 10, "req": 91, "label": "Starsea Rift Bladderwrack Kelpfield" },

	# -----------------------------
	# Fibre band (ONLY 4 patches, ONLY 4 fibres)
	# IDs now reflect the label (slug)
	# -----------------------------
	{ "id": &"stoneedge_flax_verge",                  "group": "fibre", "tier": 1, "req": 1,  "primary": FIBRE_FLAX,        "label": "Stoneedge Flax Verge" },
	{ "id": &"ochreshelf_silk_cocoon_beds",           "group": "fibre", "tier": 4, "req": 31, "primary": FIBRE_SILK_COCOON, "label": "Ochreshelf Silk Cocoon Beds" },
	{ "id": &"caprock_cotton_tufts",                  "group": "fibre", "tier": 5, "req": 41, "primary": FIBRE_COTTON,      "label": "Caprock Cotton Tufts" },
	{ "id": &"pitchcap_hemp_caps",                    "group": "fibre", "tier": 7, "req": 61, "primary": FIBRE_HEMP,        "label": "Pitchcap Hemp Caps" },
]

func _ready() -> void:
	randomize()
	_build_patches()

# -------------------------------------------------------------------
# Normalization + label → patch_id (NO legacy aliases)
# -------------------------------------------------------------------

func _norm(s: String) -> String:
	var t := s.to_lower()
	t = t.replace("’", "'")
	t = t.replace("–", "-").replace("—", "-")
	var out := ""
	for i in t.length():
		var code: int = t.unicode_at(i)
		var is_num := (code >= 48 and code <= 57)
		var is_low := (code >= 97 and code <= 122)
		var is_space := (code == 32)
		out += char(code) if (is_num or is_low or is_space) else " "
	out = out.strip_edges()
	while out.find("  ") != -1:
		out = out.replace("  ", " ")
	return out

func infer_patch_id_from_text(text: String) -> StringName:
	var ntext := _norm(text)
	if ntext == "":
		return StringName("")

	if _label_to_patch_id.has(ntext):
		return _label_to_patch_id[ntext]

	# Substring match, longer labels first
	var keys: Array = _label_to_patch_id.keys()
	keys.sort_custom(func(a, b): return String(a).length() > String(b).length())
	for k in keys:
		var kk := String(k)
		if kk != "" and ntext.find(kk) != -1:
			return _label_to_patch_id[k]

	return StringName("")

# -------------------------------------------------------------------
# Patch builder
# -------------------------------------------------------------------

func _mk_patch(label: String, group: String, tier: int, req: int, primary: StringName, other_a: StringName, other_b: StringName) -> Dictionary:
	var xp: int = int(XP_BY_TIER.get(tier, 1))
	var qcharges: int = int(QUICK_CHARGES_BY_TIER.get(tier, 10))
	var regrow: float = float(REGROW_S_BY_TIER.get(tier, 240.0))

	return {
		"label": label,
		"group": group,          # "cook" | "chem" | "fibre"
		"tier": tier,
		"req": req,
		"xp": xp,                # per Careful harvest
		"quick_charges": qcharges,
		"regrow_s": regrow,
		"drops": [
			{ "id": primary, "weight": 70.0 },
			{ "id": other_a, "weight": 15.0 },
			{ "id": other_b, "weight": 15.0 },
		],
	}

func _rebuild_label_index() -> void:
	_label_to_patch_id.clear()
	for pid_v in PATCHES.keys():
		var pid: StringName = pid_v
		var def_v: Variant = PATCHES.get(pid, {})
		if not (def_v is Dictionary):
			continue
		var def: Dictionary = def_v
		var label := String(def.get("label", ""))
		if label != "":
			_label_to_patch_id[_norm(label)] = pid

func _build_patches() -> void:
	PATCHES.clear()

	for row_v in PATCH_ROWS:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v

		var pid: StringName = row.get("id", StringName(""))
		var group: String = String(row.get("group", ""))
		var tier: int = int(row.get("tier", 1))
		var req: int = int(row.get("req", int(REQ_BY_TIER.get(tier, 1))))
		var label: String = String(row.get("label", ""))

		if pid == StringName("") or group == "" or label == "":
			continue

		# Clamp tier to known tuning tables (still allows “missing tiers” by just not adding rows)
		tier = clampi(tier, 1, 10)

		var primary: StringName = StringName("")
		var other_a: StringName = StringName("")
		var other_b: StringName = StringName("")

		if group == "cook":
			primary = COOK_HERB_BY_TIER.get(tier, StringName(""))
			other_a = CHEM_HERB_BY_TIER.get(tier, StringName(""))
			other_b = _fibre_for_tier(tier)

		elif group == "chem":
			primary = CHEM_HERB_BY_TIER.get(tier, StringName(""))
			other_a = COOK_HERB_BY_TIER.get(tier, StringName(""))
			other_b = _fibre_for_tier(tier)

		elif group == "fibre":
			primary = row.get("primary", StringName(""))
			other_a = COOK_HERB_BY_TIER.get(tier, StringName(""))
			other_b = CHEM_HERB_BY_TIER.get(tier, StringName(""))

		else:
			continue

		if primary == StringName("") or other_a == StringName("") or other_b == StringName(""):
			continue

		PATCHES[pid] = _mk_patch(label, group, tier, req, primary, other_a, other_b)

	_rebuild_label_index()

# -------------------------------------------------------------------
# Public helpers
# -------------------------------------------------------------------

func get_patch_def(patch_id: StringName) -> Dictionary:
	var v: Variant = PATCHES.get(patch_id, {})
	return v if (v is Dictionary) else {}

func is_patch_unlocked(patch_id: StringName, herb_lv: int) -> bool:
	var def := get_patch_def(patch_id)
	if def.is_empty():
		return false
	return herb_lv >= int(def.get("req", 1))

func get_max_charges(patch_id: StringName) -> int:
	var def := get_patch_def(patch_id)
	return int(def.get("quick_charges", 0))

func get_cooldown_seconds(axial: Vector2i, patch_id: StringName) -> float:
	return _get_cooldown_seconds(axial, patch_id)

# -------------------------------------------------------------------
# Per-tile patch state (charges + regrow_at)
# -------------------------------------------------------------------

var _patch_state: Dictionary = {}

func clear_all_state() -> void:
	_patch_state.clear()

func _get_or_init_state(axial: Vector2i, patch_id: StringName) -> Dictionary:
	var per_tile_v: Variant = _patch_state.get(axial, {})
	var per_tile: Dictionary = per_tile_v if (per_tile_v is Dictionary) else {}
	if not (_patch_state.get(axial, null) is Dictionary):
		_patch_state[axial] = per_tile

	var st_v: Variant = per_tile.get(patch_id, {})
	var st: Dictionary = st_v if (st_v is Dictionary) else {}

	if st.is_empty():
		var def := get_patch_def(patch_id)
		if def.is_empty():
			return {}
		st = { "charges": int(def.get("quick_charges", 0)), "regrow_at": 0.0 }
		per_tile[patch_id] = st

	return st

func _ensure_regrow(axial: Vector2i, patch_id: StringName) -> Dictionary:
	var st := _get_or_init_state(axial, patch_id)
	if st.is_empty():
		return st

	var charges: int = int(st.get("charges", 0))
	var regrow_at: float = float(st.get("regrow_at", 0.0))

	if charges <= 0 and regrow_at > 0.0:
		var now := Time.get_unix_time_from_system()
		if now >= regrow_at:
			var def := get_patch_def(patch_id)
			st["charges"] = int(def.get("quick_charges", 0))
			st["regrow_at"] = 0.0

	return st

func get_patch_status(axial: Vector2i, patch_id: StringName) -> Dictionary:
	var def := get_patch_def(patch_id)
	if def.is_empty():
		return { "is_available": false, "charges": 0, "regrow_at": 0.0 }

	var st := _ensure_regrow(axial, patch_id)
	if st.is_empty():
		return { "is_available": false, "charges": 0, "regrow_at": 0.0 }

	var charges: int = int(st.get("charges", 0))
	var regrow_at: float = float(st.get("regrow_at", 0.0))
	var now := Time.get_unix_time_from_system()

	var available := (charges > 0) and (regrow_at <= 0.0 or now >= regrow_at)
	return { "is_available": available, "charges": charges, "regrow_at": regrow_at }

func is_patch_available(axial: Vector2i, patch_id: StringName) -> bool:
	return bool(get_patch_status(axial, patch_id).get("is_available", false))

func _consume_quick_charge(axial: Vector2i, patch_id: StringName) -> void:
	var def := get_patch_def(patch_id)
	if def.is_empty():
		return

	var st := _ensure_regrow(axial, patch_id)
	if st.is_empty():
		return

	var charges: int = int(st.get("charges", 0))
	if charges <= 0:
		return

	charges -= 1
	st["charges"] = charges

	if charges <= 0:
		var regrow_s: float = float(def.get("regrow_s", 0.0))
		if regrow_s > 0.0:
			st["regrow_at"] = Time.get_unix_time_from_system() + regrow_s

func _get_cooldown_seconds(axial: Vector2i, patch_id: StringName) -> float:
	var per_tile_v: Variant = _patch_state.get(axial, {})
	if not (per_tile_v is Dictionary):
		return 0.0
	var per_tile: Dictionary = per_tile_v

	if not per_tile.has(patch_id):
		return 0.0

	var st_v: Variant = per_tile.get(patch_id, {})
	if not (st_v is Dictionary):
		return 0.0
	var st: Dictionary = st_v

	var regrow_at: float = float(st.get("regrow_at", 0.0))
	if regrow_at <= 0.0:
		return 0.0

	var now := Time.get_unix_time_from_system()
	return max(0.0, regrow_at - now)

# -------------------------------------------------------------------
# Drop preview for UI
# -------------------------------------------------------------------

func get_drop_preview_for_patch(patch_id: StringName, quick: bool = false) -> Array:
	var def := get_patch_def(patch_id)
	if def.is_empty():
		return []

	var drops_v: Variant = def.get("drops", [])
	if not (drops_v is Array):
		return []
	var drops: Array = drops_v
	if drops.is_empty():
		return []

	var total_weight := 0.0
	for row_v in drops:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		total_weight += float(row.get("weight", 0.0))
	if total_weight <= 0.0:
		return []

	var qty := CAREFUL_QTY * (QUICK_YIELD_MULT if quick else 1)

	var result: Array = []
	for row_v in drops:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var item_id: StringName = row.get("id", StringName(""))
		var w := float(row.get("weight", 0.0))
		if item_id == StringName("") or w <= 0.0:
			continue
		result.append({ "item_id": item_id, "chance": w / total_weight, "qty": qty, "is_fail": false })

	result.sort_custom(func(a, b): return float(a["chance"]) > float(b["chance"]))
	return result

# -------------------------------------------------------------------
# Weighted roll helper
# -------------------------------------------------------------------

func _roll_weighted_drop(def: Dictionary) -> StringName:
	var drops_v: Variant = def.get("drops", [])
	if not (drops_v is Array):
		return StringName("")
	var drops: Array = drops_v
	if drops.is_empty():
		return StringName("")

	var total := 0.0
	for row_v in drops:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		total += float(row.get("weight", 0.0))
	if total <= 0.0:
		return StringName("")

	var r := randf() * total
	var run := 0.0
	for row_v in drops:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		run += float(row.get("weight", 0.0))
		if r <= run:
			return row.get("id", StringName(""))

	return (drops.back() as Dictionary).get("id", StringName(""))

# -------------------------------------------------------------------
# Core action: do_forage
# -------------------------------------------------------------------

func do_forage(patch_id: StringName, ax: Vector2i, quick: bool = false) -> Dictionary:
	var def := get_patch_def(patch_id)
	if def.is_empty():
		return { "xp": 0, "loot_desc": "", "empty": true, "cooldown": 0.0, "actions": 0, "mode": "" }

	if not is_patch_available(ax, patch_id):
		var cd := _get_cooldown_seconds(ax, patch_id)
		return { "xp": 0, "loot_desc": "This patch is regrowing.", "empty": true, "cooldown": cd, "actions": 0, "mode": ("quick" if quick else "careful") }

	var actions := CAREFUL_ACTIONS
	var qty := CAREFUL_QTY
	var xp := int(def.get("xp", 1))
	var mode := "careful"

	if quick:
		mode = "quick"
		actions = QUICK_ACTIONS
		qty = CAREFUL_QTY * QUICK_YIELD_MULT
		xp = xp * QUICK_YIELD_MULT
		_consume_quick_charge(ax, patch_id)

	var item_id: StringName = _roll_weighted_drop(def)
	if item_id != StringName("") and typeof(Bank) != TYPE_NIL and Bank.has_method("add"):
		Bank.add(item_id, qty)

	var loot_desc := "Gained herbalism loot."
	if typeof(Items) != TYPE_NIL and Items.has_method("display_name") and Items.has_method("is_valid") and Items.is_valid(item_id):
		loot_desc = "Gained %dx %s" % [qty, Items.display_name(item_id)]
	else:
		loot_desc = "Gained %dx %s" % [qty, String(item_id)]

	var empty_now: bool = not is_patch_available(ax, patch_id)
	var cooldown_now: float = _get_cooldown_seconds(ax, patch_id) if empty_now else 0.0

	return { "xp": xp, "loot_desc": loot_desc, "empty": empty_now, "cooldown": cooldown_now, "actions": actions, "mode": mode }
