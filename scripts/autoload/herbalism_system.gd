# res://autoloads/HerbalismSystem.gd
extends Node

## HerbalismSystem:
## - Static patch definitions (tier, req, xp, quick_charges, regrow, drop_table 70/15/15).
## - Per-tile quick charges + regrow timers (Mining-style).
## - Gather choice:
##     • Careful Pick: 2 actions, steady yield, DOES NOT consume charges.
##     • Quick Pick:   1 action, 5× yield, consumes 1 quick charge.
## - When quick charges hit 0: patch enters long regrow; Careful is disabled until regrow completes.

const BASE_ACTION_TIME := 2.4

# -------------------------------------------------------------------
# Tuning
# -------------------------------------------------------------------

const CAREFUL_ACTIONS := 2
const QUICK_ACTIONS := 1
const CAREFUL_QTY := 1
const QUICK_YIELD_MULT := 5

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
# Patch definitions (built at runtime; cannot be const because of helper calls)
# -------------------------------------------------------------------

var PATCHES: Dictionary = {}

# -------------------------------------------------------------------
# Keyword → patch_id mapping
# IMPORTANT: include BOTH legacy names (Greenveil/Brineback/etc.)
# and the NEW "patch modifier" display strings from the PDF (Herb-Circle Plot, etc.)
# -------------------------------------------------------------------

const HERBALISM_KEYWORD_TO_PATCH_ID := {
	# -----------------------------
	# Cooking (woodcut biomes)
	# -----------------------------
	"greenveil": &"greenveil_patch",
	"greenveil patch": &"greenveil_patch",
	"greenveil forestglade": &"greenveil_patch",

	"maplefold": &"maplefold_patch",
	"maplefold patch": &"maplefold_patch",
	"maplefold vale understory": &"maplefold_patch",

	"silkshade": &"silkshade_patch",
	"silkshade patch": &"silkshade_patch",
	"silkshade canopy beds": &"silkshade_patch",

	"cloudpine": &"cloudpine_patch",
	"cloudpine patch": &"cloudpine_patch",
	"cloudpine terrace needlebed": &"cloudpine_patch",

	"baobab": &"baobab_patch",
	"baobab patch": &"baobab_patch",
	"baobab sunleaf flats": &"baobab_patch",

	"highwood": &"highwood_patch",
	"highwood patch": &"highwood_patch",
	"highwood rain-thicket": &"highwood_patch",

	"incense": &"incense_patch",
	"incense patch": &"incense_patch",
	"incense grove resinwalk": &"incense_patch",

	"boreal": &"boreal_patch",
	"boreal patch": &"boreal_patch",
	"boreal needleheath": &"boreal_patch",

	"cinder": &"cinder_patch",
	"cinder patch": &"cinder_patch",
	"cinderwood ashgarden": &"cinder_patch",

	"starbloom": &"starbloom_patch",
	"starbloom patch": &"starbloom_patch",
	"starbloom skymeadow": &"starbloom_patch",

	# -----------------------------
	# Chemical (fish biomes)
	# -----------------------------
	"reedrun": &"reedrun_patch",
	"reedrun patch": &"reedrun_patch",
	"reedrun riverbank reeds": &"reedrun_patch",

	"brineback": &"brineback_patch",
	"brineback patch": &"brineback_patch",
	"brineback estuary saltbeds": &"brineback_patch",

	"sinkbloom": &"sinkbloom_patch",
	"sinkbloom patch": &"sinkbloom_patch",
	"sinkbloom cenote bloomring": &"sinkbloom_patch",

	"echofall": &"echofall_patch",
	"echofall patch": &"echofall_patch",
	"echofall sprayroot ledge": &"echofall_patch",

	"lotusbank": &"lotusbank_patch",
	"lotusbank patch": &"lotusbank_patch",
	"lotusbank floodplain pools": &"lotusbank_patch",

	"mistshelf": &"mistshelf_patch",
	"mistshelf patch": &"mistshelf_patch",
	"mistshelf gorge vaporgrowth": &"mistshelf_patch",

	"skywell": &"skywell_patch",
	"skywell patch": &"skywell_patch",
	"skywell oasis dewbeds": &"skywell_patch",

	"frostlip": &"frostlip_patch",
	"frostlip patch": &"frostlip_patch",
	"frostlip tarn iceleaf beds": &"frostlip_patch",

	"steamroot": &"steamroot_patch",
	"steamroot patch": &"steamroot_patch",
	"steamroot geysergarden": &"steamroot_patch",

	"starkelp": &"starkelp_patch",
	"starkelp patch": &"starkelp_patch",
	"starkelp rift kelpfields": &"starkelp_patch",

	# -----------------------------
	# Fibre (mining biomes)
	# -----------------------------
	"stoneedge": &"stoneedge_patch",
	"stoneedge patch": &"stoneedge_patch",
	"stoneedge cragweave beds": &"stoneedge_patch",

	"tanninbush": &"tanninbush_patch",
	"tanninbush patch": &"tanninbush_patch",
	"tanninbush foothill thicket": &"tanninbush_patch",

	"ochreshelf": &"ochreshelf_patch",
	"ochreshelf patch": &"ochreshelf_patch",
	"ochreshelf canyon fibreflats": &"ochreshelf_patch",

	"ironmoss": &"ironmoss_patch",
	"ironmoss patch": &"ironmoss_patch",
	"ironmoss talus mats": &"ironmoss_patch",

	"redroot": &"redroot_patch",
	"redroot patch": &"redroot_patch",
	"redroot riftvine beds": &"redroot_patch",

	"caprock": &"caprock_patch",
	"caprock patch": &"caprock_patch",
	"caprock mesa cordfields": &"caprock_patch",

	"saltbloom": &"saltbloom_patch",
	"saltbloom patch": &"saltbloom_patch",
	"saltbloom dome brinefields": &"saltbloom_patch",

	"lichencrust": &"lichencrust_patch",
	"lichencrust patch": &"lichencrust_patch",
	"lichencrust steppe threadflats": &"lichencrust_patch",

	"pitchcap": &"pitchcap_patch",
	"pitchcap patch": &"pitchcap_patch",
	"pitchcap underforge caps": &"pitchcap_patch",

	# Renamed (legacy kept for backwards compatibility)
	"umbralweave": &"voidbark_patch",
	"umbralweave voidbeds": &"voidbark_patch",

	# legacy terms (so old saves / old strings still resolve)
	"voidbark": &"voidbark_patch",
	"voidbark patch": &"voidbark_patch",
	"void scar": &"voidbark_patch",
}

func _ready() -> void:
	randomize()
	_build_patches()

# -------------------------------------------------------------------
# Robust text normalization so UI strings with odd hyphens/spaces still match
# -------------------------------------------------------------------

func _norm(s: String) -> String:
	var t := s.to_lower()
	# normalize common unicode punctuation
	t = t.replace("’", "'")
	t = t.replace("–", "-").replace("—", "-").replace("-", "-")
	# keep only letters/numbers/spaces; treat everything else as space
	var out := ""
	for i in t.length():
		var ch := t[i]
		var code := int(ch.unicode_at(0))
		var is_num := (code >= 48 and code <= 57)
		var is_low := (code >= 97 and code <= 122)
		var is_space := (ch == " ")
		out += ch if (is_num or is_low or is_space) else " "
	out = out.strip_edges()
	while out.find("  ") != -1:
		out = out.replace("  ", " ")
	return out

func infer_patch_id_from_text(text: String) -> StringName:
	var ntext := _norm(text)
	for kw_v in HERBALISM_KEYWORD_TO_PATCH_ID.keys():
		var nkw := _norm(String(kw_v))
		if nkw != "" and ntext.find(nkw) != -1:
			return HERBALISM_KEYWORD_TO_PATCH_ID[kw_v]
	return StringName("")

# -------------------------------------------------------------------
# Helper (runtime OK)
# -------------------------------------------------------------------

func _mk_patch(label: String, group: String, tier: int, primary: StringName, other_a: StringName, other_b: StringName) -> Dictionary:
	var req: int = int(REQ_BY_TIER.get(tier, 1))
	var xp: int = int(XP_BY_TIER.get(tier, 1))
	var qcharges: int = int(QUICK_CHARGES_BY_TIER.get(tier, 10))
	var regrow: float = float(REGROW_S_BY_TIER.get(tier, 240.0))

	return {
		"label": label,          # display name / patch modifier (matches PDF naming)
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

func _build_patches() -> void:
	PATCHES = {
		# -----------------------------
		# Cooking herbs (Woodcutting biomes) - primary 70% cook herb
		# Names updated to match the PDF "Patch modifier" renames
		# -----------------------------
		&"greenveil_patch": _mk_patch("Herb-Circle Plot", "cook", 1,
			&"cook_herb_thyme_t1", &"chem_herb_marshmallow_root_t1", &"tailor_fibre_flax"),
		&"maplefold_patch": _mk_patch("Maplefold Patch", "cook", 2,
			&"cook_herb_sage_t2", &"chem_herb_sea_wormwood_t2", &"tailor_fibre_flax"),
		&"silkshade_patch": _mk_patch("Dye-Mushroom Ring", "cook", 3,
			&"cook_herb_fennel_t3", &"chem_herb_gotu_kola_t3", &"tailor_fibre_silk_cocoons"),
		&"cloudpine_patch": _mk_patch("Cloudpine Patch", "cook", 4,
			&"cook_herb_rosemary_t4", &"chem_herb_water_hemlock_t4", &"tailor_fibre_silk_cocoons"),
		&"baobab_patch": _mk_patch("Medicinal Bush Patch", "cook", 5,
			&"cook_herb_lemongrass_t5", &"chem_herb_bittersweet_nightshade_t5", &"tailor_fibre_silk_cocoons"),
		&"highwood_patch": _mk_patch("Fruit Canopy Grove", "cook", 6,
			&"cook_herb_ginger_t6", &"chem_herb_valerian_t6", &"tailor_fibre_cotton"),
		&"incense_patch": _mk_patch("Wadi Scrub Herbs", "cook", 7,
			&"cook_herb_coriander_t7", &"chem_herb_aloe_vera_t7", &"tailor_fibre_cotton"),
		&"boreal_patch": _mk_patch("Underbough Moss Patch", "cook", 8,
			&"cook_herb_juniper_t8", &"chem_herb_frost_kava_t8", &"tailor_fibre_cotton"),
		&"cinder_patch": _mk_patch("Ash Herb Patch", "cook", 9,
			&"cook_herb_oregano_t9", &"chem_herb_datura_t9", &"tailor_fibre_hemp"),
		&"starbloom_patch": _mk_patch("Starlit Sap Wound", "cook", 10,
			&"cook_herb_star_anise_t10", &"chem_herb_bladderwrack_t10", &"tailor_fibre_hemp"),

		# -----------------------------
		# Chemical herbs (Fishing biomes) - primary 70% chem herb
		# -----------------------------
		&"reedrun_patch": _mk_patch("Reed Bed", "chem", 1,
			&"chem_herb_marshmallow_root_t1", &"cook_herb_thyme_t1", &"tailor_fibre_flax"),
		&"brineback_patch": _mk_patch("Saltmarsh Reeds", "chem", 2,
			&"chem_herb_sea_wormwood_t2", &"cook_herb_sage_t2", &"tailor_fibre_flax"),
		&"sinkbloom_patch": _mk_patch("Root-Hung Ledge", "chem", 3,
			&"chem_herb_gotu_kola_t3", &"cook_herb_fennel_t3", &"tailor_fibre_silk_cocoons"),
		&"echofall_patch": _mk_patch("Echofall Patch", "chem", 4,
			&"chem_herb_water_hemlock_t4", &"cook_herb_rosemary_t4", &"tailor_fibre_silk_cocoons"),
		&"lotusbank_patch": _mk_patch("Lotus Channel", "chem", 5,
			&"chem_herb_bittersweet_nightshade_t5", &"cook_herb_lemongrass_t5", &"tailor_fibre_silk_cocoons"),
		&"mistshelf_patch": _mk_patch("Mist-Covered Herb Shelf", "chem", 6,
			&"chem_herb_valerian_t6", &"cook_herb_ginger_t6", &"tailor_fibre_cotton"),
		&"skywell_patch": _mk_patch("Oasis Herb Garden", "chem", 7,
			&"chem_herb_aloe_vera_t7", &"cook_herb_coriander_t7", &"tailor_fibre_cotton"),
		&"frostlip_patch": _mk_patch("Frost Herb Ledge", "chem", 8,
			&"chem_herb_frost_kava_t8", &"cook_herb_juniper_t8", &"tailor_fibre_cotton"),
		&"steamroot_patch": _mk_patch("Steamroot Patch", "chem", 9,
			&"chem_herb_datura_t9", &"cook_herb_oregano_t9", &"tailor_fibre_hemp"),
		&"starkelp_patch": _mk_patch("Starkelp Patch", "chem", 10,
			&"chem_herb_bladderwrack_t10", &"cook_herb_star_anise_t10", &"tailor_fibre_hemp"),

		# -----------------------------
		# Tailoring fibres (Mining biomes) - primary 70% fibre
		# -----------------------------
		&"stoneedge_patch": _mk_patch("Field Edge Herb Patch", "fibre", 1,
			&"tailor_fibre_flax", &"cook_herb_thyme_t1", &"chem_herb_marshmallow_root_t1"),
		&"tanninbush_patch": _mk_patch("Tanninbush Patch", "fibre", 2,
			&"tailor_fibre_flax", &"cook_herb_sage_t2", &"chem_herb_sea_wormwood_t2"),
		&"ochreshelf_patch": _mk_patch("Ochreshelf Patch", "fibre", 3,
			&"tailor_fibre_silk_cocoons", &"cook_herb_fennel_t3", &"chem_herb_gotu_kola_t3"),
		&"ironmoss_patch": _mk_patch("Ironmoss Patch", "fibre", 4,
			&"tailor_fibre_silk_cocoons", &"cook_herb_rosemary_t4", &"chem_herb_water_hemlock_t4"),
		&"redroot_patch": _mk_patch("Redroot Patch", "fibre", 5,
			&"tailor_fibre_silk_cocoons", &"cook_herb_lemongrass_t5", &"chem_herb_bittersweet_nightshade_t5"),
		&"caprock_patch": _mk_patch("Caprock Patch", "fibre", 6,
			&"tailor_fibre_cotton", &"cook_herb_ginger_t6", &"chem_herb_valerian_t6"),
		&"saltbloom_patch": _mk_patch("Saltbloom Patch", "fibre", 7,
			&"tailor_fibre_cotton", &"cook_herb_coriander_t7", &"chem_herb_aloe_vera_t7"),
		&"lichencrust_patch": _mk_patch("Lichencrust Patch", "fibre", 8,
			&"tailor_fibre_cotton", &"cook_herb_juniper_t8", &"chem_herb_frost_kava_t8"),
		&"pitchcap_patch": _mk_patch("Pitchcap Patch", "fibre", 9,
			&"tailor_fibre_hemp", &"cook_herb_oregano_t9", &"chem_herb_datura_t9"),
		&"voidbark_patch": _mk_patch("Voidbark Patch", "fibre", 10,
			&"tailor_fibre_hemp", &"cook_herb_star_anise_t10", &"chem_herb_bladderwrack_t10"),
	}

# -------------------------------------------------------------------
# Per-tile patch state (charges + regrow_at)
# -------------------------------------------------------------------

var _patch_state: Dictionary = {}

func get_patch_def(patch_id: StringName) -> Dictionary:
	if PATCHES.has(patch_id):
		return PATCHES[patch_id]
	return {}

func is_patch_unlocked(patch_id: StringName, herb_lv: int) -> bool:
	var def := get_patch_def(patch_id)
	if def.is_empty():
		return false
	return herb_lv >= int(def.get("req", 1))

func _get_or_init_state(axial: Vector2i, patch_id: StringName) -> Dictionary:
	var per_tile_v: Variant = _patch_state.get(axial, {})
	var per_tile: Dictionary
	if per_tile_v is Dictionary:
		per_tile = per_tile_v
	else:
		per_tile = {}
		_patch_state[axial] = per_tile

	var st_v: Variant = per_tile.get(patch_id, {})
	var st: Dictionary
	if st_v is Dictionary:
		st = st_v
	else:
		st = {}

	if st.is_empty():
		var def := get_patch_def(patch_id)
		if def.is_empty():
			return {}
		st = {
			"charges": int(def.get("quick_charges", 0)),
			"regrow_at": 0.0,
		}
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
	return {
		"is_available": available,
		"charges": charges,
		"regrow_at": regrow_at,
	}

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

func clear_all_state() -> void:
	_patch_state.clear()

func _get_cooldown_seconds(axial: Vector2i, patch_id: StringName) -> float:
	var per_tile_v: Variant = _patch_state.get(axial, {})
	if not (per_tile_v is Dictionary):
		return 0.0
	var per_tile: Dictionary = per_tile_v

	if not per_tile.has(patch_id):
		return 0.0

	var st_v: Variant = per_tile[patch_id]
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
		if item_id == StringName(""):
			continue
		var w := float(row.get("weight", 0.0))
		if w <= 0.0:
			continue
		result.append({
			"item_id": item_id,
			"chance": w / total_weight,
			"qty": qty,
			"is_fail": false,
		})

	result.sort_custom(func(a, b):
		return float(a["chance"]) > float(b["chance"])
	)
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

	var last: Dictionary = drops.back()
	return last.get("id", StringName(""))

# -------------------------------------------------------------------
# Core action: do_forage (Mining-style)
# -------------------------------------------------------------------

func do_forage(patch_id: StringName, ax: Vector2i, quick: bool = false) -> Dictionary:
	var def: Dictionary = get_patch_def(patch_id)
	if def.is_empty():
		return {
			"xp": 0,
			"loot_desc": "",
			"empty": true,
			"cooldown": 0.0,
			"actions": 0,
			"mode": "",
		}

	if not is_patch_available(ax, patch_id):
		var cd := _get_cooldown_seconds(ax, patch_id)
		return {
			"xp": 0,
			"loot_desc": "This patch is regrowing.",
			"empty": true,
			"cooldown": cd,
			"actions": 0,
			"mode": ("quick" if quick else "careful"),
		}

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
	if typeof(Items) != TYPE_NIL \
	and Items.has_method("display_name") \
	and Items.has_method("is_valid") \
	and Items.is_valid(item_id):
		loot_desc = "Gained %dx %s" % [qty, Items.display_name(item_id)]
	else:
		loot_desc = "Gained %dx %s" % [qty, String(item_id)]

	var empty_now: bool = not is_patch_available(ax, patch_id)
	var cooldown_now: float = 0.0
	if empty_now:
		cooldown_now = _get_cooldown_seconds(ax, patch_id)

	return {
		"xp": xp,
		"loot_desc": loot_desc,
		"empty": empty_now,
		"cooldown": cooldown_now,
		"actions": actions,
		"mode": mode,
	}
