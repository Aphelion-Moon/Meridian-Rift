/**
 * The bulge template sheets, the templates derived past small_cap, and their accessors (templates.dm).
 *
 * bulge_templates: the three approved looks the garment vars could not carry until the families said them (the
 * heart boxers' large prints, the shorter loincloths' own drapes and cuts, each revealing skirt's hem).
 *
 * bulge_template_identities: every identity the families declare resolves to a template, in a sheet or derived; every
 * state of the sheets is reached by one and holds what its sheet may hold, as `tools/bulge_assets.py verify` checks
 * them (CI runs this test, not the tool); and the identities resolved, by kind, are the frozen record's.
 *
 * bulge_derivation: what is derived past small_cap is the frozen record of the sheet states it replaced;
 * bulge_derivation/pin pins what it is derived from.
 */
/// The hash of what the shapes past small_cap are derived from (bulge_derivation/pin): change it only with approval.
/// It was e9c65cbf69fa29aaca40e9a9858bb5d0 until the pin sorted its lines before hashing them, so that the order
/// the types are defined in no longer changes it: what it pins did not change.
#define BULGE_DERIVATION_INPUTS "0364ce1abfeb2cce921ca59c264e523c"
/// What bulge_derivation derives: its states by kind, the shapes that cover the whole penis, and the digest of every
/// pixel derived. Frozen when the sheets those states lived in were deleted, after it had matched them pixel for pixel
/// (0 differed): change it only with approval, after checking the corpus.
#define BULGE_DERIVATION_RECORD "{\"shape\":630,\"bare\":577,\"drape\":353,\"cut\":16}; 53 covering; digest b60eb5968107a3f0418b2b301e126c5a"
/// The identities bulge_template_identities resolves, by kind, and the states of the sheets they reach.
#define BULGE_IDENTITIES_RECORD "{\"shape\":3816,\"exposed\":2932,\"patch\":212,\"covering shape\":218,\"drape\":840,\"cut\":840,\"clearance\":200,\"flap\":256}; 656 states in 5 sheets"

/datum/unit_test/bulge_templates

/datum/unit_test/bulge_templates/Run()
	// The heart boxers keep their print past size 4, in the large hearts mal approved; their shapes are the loose boxers'.
	var/datum/sprite_accessory/clothing/underwear/hearts = /datum/sprite_accessory/clothing/underwear/male_hearts
	TEST_ASSERT_EQUAL(initial(hearts.bulge_family), /datum/bulge_family/loose_boxers/hearts, "The heart boxers' family")
	TEST_ASSERT(initial(hearts.bulge_printed), "The heart boxers are printed")
	var/datum/bulge_family/hearts_family = /datum/bulge_family/loose_boxers/hearts
	TEST_ASSERT_EQUAL(initial(hearts_family.print_cap), 8, "The heart boxers' prints go to size 8")
	for(var/hard in list(FALSE, TRUE))
		for(var/digi in list(FALSE, TRUE))
			for(var/size in 1 to 8)
				var/datum/bulge_sheet_state/patch = bulge_printed_patch(hearts_family, hard, size, digi)
				TEST_ASSERT_EQUAL(!!patch, size > 4, "Heart boxers [hard ? "hard" : "half"] [size] [digi ? "digi" : "plain"]: a precoloured patch past size 4 only")
				var/datum/bulge_print_template/shape = bulge_shape(hearts_family, hard, size, digi, /datum/sprite_accessory/genital/penis/human, TRUE)
				if(size > 4)
					// The patch is drawn in place of a shape: no cloth shape of their own. The anatomy it leaves bare is the
					// boxers' (bulge_resolve(), bulge_renderer/custom_layering).
					TEST_ASSERT_NULL(shape, "Heart boxers past size 4 draw their patch in place of a shape")
					TEST_ASSERT_NULL(bulge_exposed(hearts_family, hard, size, digi, /datum/sprite_accessory/genital/penis/human, TRUE), "Heart boxers past size 4 have no shapes of their own")
				else
					TEST_ASSERT_EQUAL(shape, bulge_shape(/datum/bulge_family/loose_boxers, hard, size, digi, /datum/sprite_accessory/genital/penis/human, TRUE), "Heart boxers draw the loose boxers' shapes up to size 4")
	var/datum/sprite_accessory/clothing/underwear/accessory = /datum/sprite_accessory/clothing/underwear/male_stripe
	TEST_ASSERT_NULL(bulge_printed_patch(initial(accessory.bulge_family), TRUE, 6, FALSE), "Other loose boxers have no hand-drawn patches")
	// Past size 4 a penis shape draws the patch drawn for its profile where the sheet has one (facing east and west; mal,
	// 2026-10-06), any other the human penis's; drawn without skin tones, a shape whose untoned sprites draw differently
	// draws its untoned patch where the sheet has one.
	var/datum/bulge_sheet_state/where = bulge_printed_patch(hearts_family, TRUE, 7, FALSE, /datum/sprite_accessory/genital/penis/knotted, TRUE)
	TEST_ASSERT_EQUAL(where?.icon_state, "heart_boxers_hard_7_plain_knotted", "A knotted penis's own patch, hard 7")
	where = bulge_printed_patch(hearts_family, TRUE, 7, FALSE, /datum/sprite_accessory/genital/penis/flared, TRUE)
	TEST_ASSERT_EQUAL(where?.icon_state, "heart_boxers_hard_7_plain_flared", "A flared penis's own patch, hard 7")
	where = bulge_printed_patch(hearts_family, FALSE, 5, TRUE, /datum/sprite_accessory/genital/penis/hemi, FALSE)
	TEST_ASSERT_EQUAL(where?.icon_state, "heart_boxers_half_5_digi_hemi", "An untoned hemi penis's own patch, half 5 on digitigrade legs: the sheet has no untoned one")
	where = bulge_printed_patch(hearts_family, TRUE, 7, FALSE, /datum/sprite_accessory/genital/penis/human/alt, FALSE)
	TEST_ASSERT_EQUAL(where?.icon_state, "heart_boxers_hard_7_plain_human_alt_untoned", "An untoned Human (Alt) penis's own untoned patch, hard 7")
	where = bulge_printed_patch(hearts_family, TRUE, 5, FALSE, /datum/sprite_accessory/genital/penis/human/alt, FALSE)
	TEST_ASSERT_EQUAL(where?.icon_state, "heart_boxers_hard_5_plain_human_alt", "Hard 5, where the sheet has no untoned Human (Alt) patch, its skin-toned one")
	TEST_ASSERT_EQUAL(bulge_printed_patch(hearts_family, TRUE, 6, FALSE, /datum/sprite_accessory/genital/penis/knotted, TRUE), bulge_printed_patch(hearts_family, TRUE, 6, FALSE), "Hard 6, where the sheet has no knotted patch, a knotted penis draws the human penis's")
	TEST_ASSERT_EQUAL(bulge_printed_patch(hearts_family, TRUE, 7, FALSE, /datum/sprite_accessory/genital/penis/human, TRUE), bulge_printed_patch(hearts_family, TRUE, 7, FALSE), "The human penis draws the human penis's patch")
	// The tentacles, and Nondescript (Alt), Tapered (Alt) and Hemi (Alt) past their print_cap (4), draw the size 4 shape
	// and its print under the heart boxers, and no patch (mal, 2026-10-06).
	for(var/penis in list(/datum/sprite_accessory/genital/penis/tentacle, /datum/sprite_accessory/genital/penis/nondescript/alt, /datum/sprite_accessory/genital/penis/tapered/alt, /datum/sprite_accessory/genital/penis/hemi/alt))
		TEST_ASSERT_NULL(bulge_printed_patch(hearts_family, TRUE, 7, FALSE, penis, TRUE), "[penis] draws no patch under the heart boxers past size 4")
		TEST_ASSERT_EQUAL(bulge_shape(hearts_family, TRUE, 7, FALSE, penis, TRUE), bulge_shape(hearts_family, TRUE, 4, FALSE, penis, TRUE), "[penis] draws the size 4 shape under the heart boxers past size 4")

	// The shorter loincloths: the long ones' half-hard shapes, their own drapes and cuts.
	var/datum/sprite_accessory/clothing/underwear/short_bottom = /datum/sprite_accessory/clothing/underwear/loincloth_alt
	var/obj/item/clothing/under/short_uniform = /obj/item/clothing/under/dress/skirt/nova/loincloth/loincloth_alt
	var/datum/sprite_accessory/clothing/underwear/long_bottom = /datum/sprite_accessory/clothing/underwear/loincloth
	var/obj/item/clothing/under/long_uniform = /obj/item/clothing/under/dress/skirt/nova/loincloth
	TEST_ASSERT_EQUAL(initial(short_bottom.bulge_family), /datum/bulge_family/colourable_loincloth/short, "The shorter loincloth's family")
	TEST_ASSERT_EQUAL(initial(short_uniform.bulge_family), /datum/bulge_family/colourable_loincloth/short, "The shorter loincloth skirt's family")
	TEST_ASSERT_EQUAL(initial(long_bottom.bulge_family), /datum/bulge_family/colourable_loincloth, "The loincloth's family")
	TEST_ASSERT_EQUAL(initial(long_uniform.bulge_family), /datum/bulge_family/colourable_loincloth, "The loincloth skirt's family")
	var/datum/bulge_print_template/short_drape = bulge_drape(/datum/bulge_family/colourable_loincloth/short, 3, 3, /datum/sprite_accessory/genital/penis/human, TRUE)
	var/datum/bulge_print_template/long_drape = bulge_drape(/datum/bulge_family/colourable_loincloth, 3, 3, /datum/sprite_accessory/genital/penis/human, TRUE)
	TEST_ASSERT(short_drape && long_drape, "Both loincloths drape a human penis at size 3")
	TEST_ASSERT_EQUAL(short_drape.icon_state, "short_loincloth_human_3", "The shorter loincloth's own drape")
	var/datum/bulge_sheet_state/short_cut = bulge_loincloth_cut(/datum/bulge_family/colourable_loincloth/short, 3, 3, /datum/sprite_accessory/genital/penis/human, TRUE)
	TEST_ASSERT(short_cut && findtext(short_cut.icon_state, "short_loincloth_cut_") == 1, "The shorter loincloth's own cut")
	TEST_ASSERT_EQUAL(bulge_shape(/datum/bulge_family/colourable_loincloth/short, FALSE, 2, FALSE, null, TRUE), bulge_shape(/datum/bulge_family/colourable_loincloth, FALSE, 2, FALSE, null, TRUE), "Half hard, the shorter loincloth is the loincloth")
	TEST_ASSERT_NULL(bulge_shape(/datum/bulge_family/colourable_loincloth/short, TRUE, 2, FALSE, null, TRUE), "Hard, a loincloth drapes instead")

	// Each revealing skirt's hem: its own hard shape where its hem differs, the common one elsewhere.
	var/obj/item/clothing/under/jumpskirt = /obj/item/clothing/under/color/jumpskirt
	TEST_ASSERT_EQUAL(initial(jumpskirt.bulge_family), /datum/bulge_family/skirt/short_reveal/hem_24, "The jumpskirt's hem")
	var/datum/bulge_print_template/own = bulge_shape(/datum/bulge_family/skirt/short_reveal/hem_24, TRUE, 1, FALSE, null, TRUE)
	TEST_ASSERT_EQUAL(own?.icon_state, "short_reveal_hem_24_hard_1_plain", "A hem draws its own shape at its own sizes")
	TEST_ASSERT_EQUAL(bulge_shape(/datum/bulge_family/skirt/short_reveal/hem_24, TRUE, 2, FALSE, null, TRUE), bulge_shape(/datum/bulge_family/skirt/short_reveal, TRUE, 2, FALSE, null, TRUE), "and the common shape elsewhere")
	TEST_ASSERT_EQUAL(bulge_shape(/datum/bulge_family/skirt/short_reveal/hem_24, FALSE, 1, FALSE, null, TRUE), bulge_shape(/datum/bulge_family/skirt/short_reveal, FALSE, 1, FALSE, null, TRUE), "and the common half-hard shape")
	var/datum/bulge_print_template/flap = bulge_flap(/datum/bulge_family/skirt/short_reveal/hem_24, 1, FALSE)
	TEST_ASSERT_EQUAL(flap?.icon_state, "short_reveal_hem_24_hard_1_plain", "A hem's own flap")
	// A hem owns each kind of data apart: the lone skirt has only its own flap, at size 4.
	var/datum/bulge_family/lone = /datum/bulge_family/skirt/short_reveal/lone_skirt
	var/datum/bulge_family/common = /datum/bulge_family/skirt/short_reveal
	TEST_ASSERT_EQUAL(bulge_shape(lone, TRUE, 4, FALSE, null, TRUE), bulge_shape(common, TRUE, 4, FALSE, null, TRUE), "The lone skirt's shape at size 4 is the common one")
	TEST_ASSERT_EQUAL(bulge_clearance(lone, TRUE, 4), bulge_clearance(common, TRUE, 4), "and so is its clearance")
	var/datum/bulge_print_template/lone_flap = bulge_flap(lone, 4, FALSE)
	TEST_ASSERT_EQUAL(lone_flap?.icon_state, "short_reveal_lone_skirt_hard_4_plain", "but its flap is its own")
	TEST_ASSERT_EQUAL(bulge_flap(lone, 3, FALSE), bulge_flap(common, 3, FALSE), "and the common flap elsewhere")
	var/count = 0
	for(var/typepath in typesof(/obj/item/clothing/under))
		var/obj/item/clothing/under/garment = typepath
		var/family = initial(garment.bulge_family)
		if(!ispath(family, /datum/bulge_family/skirt/short_reveal))
			continue
		count++
		for(var/size in 1 to 8)
			TEST_ASSERT(bulge_clearance(family, TRUE, size), "[typepath] has a clearance at [size]")
			for(var/digi in list(FALSE, TRUE))
				TEST_ASSERT(bulge_shape_where(family, TRUE, size, digi, null, TRUE), "[typepath] has a hard shape at [size]")
				TEST_ASSERT(bulge_flap(family, size, digi), "[typepath] has a flap at [size]")
	TEST_ASSERT_EQUAL(count, 162, "Revealing skirts")

/**
 * Every identity the families declare resolves through the accessors, to a state in the template sheets or to one
 * derived at run time, and every state of the sheets is reached by one: the identities `tools/bulge_assets.py verify`
 * declares. For every family that draws, in both forms, at every size up to its cap and on both legs: its shape (past
 * small_cap one per penis shape, with and without skin tones where the shape has them, derived), the anatomy that shape
 * leaves bare (derived; none where it covers the penis), a skirt's flap and (on either legs) its clearance, a printed
 * family's precoloured patch and each penis shape's own, where the sheet has one for its profile (and one for its
 * untoned sprites, where they differ); and for each loincloth its drape and cut under every penis shape, at every
 * length from 1 to 100 inches (derived). A penis shape with no shapes of its own (the tentacles) draws the family's
 * small_cap shape and no anatomy, and so does a shape past its print_cap under a printed family's patches, with no
 * patch. The counts, by kind, must be BULGE_IDENTITIES_RECORD's.
 */
/datum/unit_test/bulge_template_identities
	/// "[sheet]|[state]" -> TRUE for every sheet state an identity resolved to.
	var/list/visited = list()
	/// "[sheet]" -> the sheet, for every sheet an identity resolved to.
	var/list/sheets = list()
	/// Identities resolved, by kind.
	var/list/counts = list()

/datum/unit_test/bulge_template_identities/Run()
	var/list/shapes = list()
	for(var/datum/sprite_accessory/genital/penis/shape as anything in subtypesof(/datum/sprite_accessory/genital/penis))
		if(initial(shape.icon_state) && initial(shape.icon_state) != "none")
			shapes += shape
	for(var/datum/bulge_family/family as anything in subtypesof(/datum/bulge_family))
		if(!initial(family.shapes) && !initial(family.half_shapes_of) && !initial(family.hard_shapes_of) \
			&& !initial(family.large_shapes_of) && !initial(family.drapes))
			continue // An abstract parent: nothing draws it.
		for(var/hard in list(FALSE, TRUE))
			for(var/size in 1 to (hard ? initial(family.hard_cap) : initial(family.half_cap)))
				if(initial(family.clearance))
					var/datum/bulge_sheet_state/clearance = bulge_clearance(family, hard, size)
					resolve("clearance", "[family] [hard ? "hard" : "half"] [size]", clearance?.icon, clearance?.icon_state)
				for(var/digi in list(FALSE, TRUE))
					var/what = "[family] [hard ? "hard" : "half"] [size] [digi ? "digi" : "plain"]"
					if(!hard || !initial(family.loincloth))
						if(size <= initial(family.small_cap))
							var/datum/bulge_sheet_state/where = bulge_shape_where(family, hard, size, digi, null, TRUE)
							resolve("shape", what, where?.icon, where?.icon_state)
						else if(initial(family.printed_patches) && size <= initial(family.print_cap))
							var/datum/bulge_sheet_state/patch = bulge_printed_patch(family, hard, size, digi)
							resolve("patch", what, patch?.icon, patch?.icon_state)
							var/datum/bulge_sheet_state/capped = bulge_shape_where(family, hard, initial(family.small_cap), digi, null, TRUE)
							for(var/datum/sprite_accessory/genital/penis/penis as anything in shapes)
								if(bulge_shape_size(family, hard, size, penis) <= initial(family.small_cap))
									// The tentacles, and a shape past its print_cap: the small_cap shape and its print, no patch.
									var/datum/bulge_sheet_state/where = bulge_printed_patch(family, hard, size, digi, penis, TRUE)
									if(where || bulge_shape_where(family, hard, size, digi, penis, TRUE) != capped || bulge_exposed(family, hard, size, digi, penis, TRUE))
										TEST_FAIL("[what] [penis]: not the small_cap shape alone (patch [where?.icon_state])")
									continue
								// Its own patch where it differs from the human penis's, then, drawn without skin tones, its untoned one
								// where that differs from its own.
								var/datum/bulge_sheet_state/known = patch
								for(var/toned in (initial(penis.bulge_untoned) ? list(TRUE, FALSE) : list(TRUE)))
									var/datum/bulge_sheet_state/where = bulge_printed_patch(family, hard, size, digi, penis, toned)
									if(where != known)
										resolve("patch", "[what] [penis][toned ? "" : " untoned"]", where?.icon, where?.icon_state)
									known = where
							if(bulge_shape_where(family, hard, size, digi, /datum/sprite_accessory/genital/penis/human, TRUE))
								TEST_FAIL("[what]: a precoloured patch is drawn alone, with no shape")
						else
							check_large(family, hard, size, digi, shapes, what)
					if(hard && initial(family.flaps))
						var/datum/bulge_print_template/flap = bulge_flap(family, size, digi)
						resolve("flap", what, flap?.icon, flap?.icon_state)
		if(initial(family.drapes))
			check_drapes(family, shapes)
	var/missing = 0
	var/bad = 0
	for(var/sheet_name, sheet in sheets)
		var/list/metadata = list()
		for(var/list/state_data as anything in icon_metadata(sheet)?["states"])
			metadata[state_data["name"]] = state_data
		for(var/state in icon_states(sheet))
			if(!visited["[sheet_name]|[state]"])
				missing++
				if(missing <= 20)
					TEST_FAIL("[sheet_name] [state]: no identity reaches it")
				continue
			var/problem = check_content(sheet, state, metadata[state])
			if(problem)
				bad++
				if(bad <= 20)
					TEST_FAIL("[sheet_name] [state]: [problem]")
	var/identities = "[json_encode(counts)]; [length(visited)] states in [length(sheets)] sheets"
	TEST_NOTICE(src, "Identities resolved: [identities] visited.")
	TEST_ASSERT_EQUAL(identities, BULGE_IDENTITIES_RECORD, "Identities resolved, by kind, and sheet states reached")

/**
 * What is wrong with a state of a template sheet (`metadata`: its DMI metadata, icon_metadata()), or null, as
 * `tools/bulge_assets.py verify` judges it: four directions and one frame; a kind map (the small cloth shapes, skirt
 * shapes) holds only the five kind greys, opaque, and a mask (skirt clearances and flaps) only opaque white, neither
 * drawn facing north; a precoloured patch (the large heart boxers) holds any colour, any way. The PNG's bit depth is the
 * tool's to check.
 */
/datum/unit_test/bulge_template_identities/proc/check_content(sheet, state, list/metadata)
	var/list/allowed = list("#808080" = TRUE, "#a3a3a3" = TRUE, "#b7b7b7" = TRUE, "#646464" = TRUE, "#4b4b4b" = TRUE)
	if(metadata?["dirs"] != 4 || length(metadata["delays"]) > 1)
		return "[metadata?["dirs"] || "no"] directions and [length(metadata?["delays"]) || 1] frames, where four and one are wanted"
	var/sheet_name = "[sheet]"
	if(findtext(sheet_name, "printed_patches"))
		return null
	var/mask = findtext(sheet_name, "skirt_clearance") || findtext(sheet_name, "skirt_flaps")
	for(var/facing in list(SOUTH, NORTH, EAST, WEST))
		var/icon/frame = icon(sheet, state, facing, 1, 0)
		var/width = frame.Width()
		var/height = frame.Height()
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				var/pixel = frame.GetPixel(x, y)
				if(!pixel)
					continue
				if(facing == NORTH)
					return "drawn facing north at [x],[y]"
				if(mask ? pixel != "#ffffff" : !allowed[pixel])
					return "[pixel] at [x],[y] facing [dir2text(facing)], which is no [mask ? "white mask" : "kind's grey"]"
	return null

/// Records an identity of `kind` resolved to a state, a sheet's or (no sheet) a derived one, or fails it when it resolved
/// to none.
/datum/unit_test/bulge_template_identities/proc/resolve(kind, what, sheet, state)
	counts[kind] = (counts[kind] || 0) + 1
	if(isnull(state))
		TEST_FAIL("[what]: no [kind]")
		return FALSE
	if(sheet)
		visited["[sheet]|[state]"] = TRUE
		sheets["[sheet]"] = sheet
	return TRUE

/// A family's shapes past small_cap, one per penis shape, derived, and the anatomy each leaves bare.
/datum/unit_test/bulge_template_identities/proc/check_large(datum/bulge_family/family, hard, size, digi, list/shapes, what)
	var/datum/bulge_sheet_state/capped = bulge_shape_where(family, hard, initial(family.small_cap), digi, null, TRUE)
	for(var/datum/sprite_accessory/genital/penis/shape as anything in shapes)
		for(var/toned in (initial(shape.has_skintone_shading) ? list(TRUE, FALSE) : list(FALSE)))
			var/identity = "[what] [shape] [toned ? "toned" : "untoned"]"
			var/datum/bulge_sheet_state/where = bulge_shape_where(family, hard, size, digi, shape, toned)
			var/datum/bulge_sheet_state/exposed = bulge_exposed(family, hard, size, digi, shape, toned)
			if(!initial(shape.bulge_hyper))
				if(where != capped || exposed)
					TEST_FAIL("[identity]: draws [where?.icon_state] and [exposed?.icon_state], not the small_cap shape alone")
				continue
			if(where?.icon)
				TEST_FAIL("[identity]: [where.icon_state] is read from [where.icon], not derived")
			if(!resolve("shape", identity, where?.icon, where?.icon_state))
				continue
			if(!bulge_shape(family, hard, size, digi, shape, toned))
				TEST_FAIL("[identity]: nothing derived for [where.icon_state]")
			if(!exposed)
				counts["covering shape"] = (counts["covering shape"] || 0) + 1 // The shape covers the whole penis.
				continue
			resolve("exposed", identity, exposed.icon, exposed.icon_state)

/// A loincloth's drapes and cuts under every penis shape, at every length from 1 to 100 inches.
/datum/unit_test/bulge_template_identities/proc/check_drapes(datum/bulge_family/family, list/shapes)
	for(var/datum/sprite_accessory/genital/penis/shape as anything in shapes)
		for(var/toned in (initial(shape.has_skintone_shading) ? list(TRUE, FALSE) : list(FALSE)))
			var/cap = initial(shape.max_sprite_size_affix)
			if(toned && initial(shape.skintone_max_sprite_size_affix))
				cap = initial(shape.skintone_max_sprite_size_affix)
			var/list/seen = list()
			for(var/length_inches in 1 to 100)
				var/size = bulge_size(length_inches)
				var/sprite_size = bulge_sprite_size(length_inches, cap)
				var/key = "[size] [sprite_size]"
				if(seen[key])
					continue
				seen[key] = TRUE
				var/identity = "[family] [shape] [toned ? "toned" : "untoned"] size [size] sprite [sprite_size]"
				var/datum/bulge_print_template/drape = bulge_drape(family, size, sprite_size, shape, toned)
				resolve("drape", identity, drape?.icon, drape?.icon_state)
				var/datum/bulge_sheet_state/cut = bulge_loincloth_cut(family, size, sprite_size, shape, toned)
				resolve("cut", identity, cut?.icon, cut?.icon_state)

/**
 * Every shape past small_cap, the anatomy each leaves bare, and every loincloth drape and cut, as derived from the
 * game's sprites (templates.dm), against BULGE_DERIVATION_RECORD: the states derived, by kind, the shapes that leave
 * nothing bare, and a digest of every pixel derived, the bare anatomy's mask tiles and the cuts' keep masks with them.
 * The record was frozen from the sheet states these replaced, which they matched pixel for pixel. Each state is derived
 * once, from the family that owns it, so the families that share a stem must agree on the vars it is derived from.
 * Logs the time it took.
 */
/datum/unit_test/bulge_derivation
	priority = TEST_LONGER
	/// "[kind] [state]" -> TRUE for every state derived.
	var/list/visited = list()
	/// States derived, by kind.
	var/list/counts = list()
	/// States derived as nothing, and pixels of mask tiles and keep masks that are not what they must draw.
	var/errors = 0
	/// What was derived, a line per state and direction, for the digest.
	var/list/raw = list()

/datum/unit_test/bulge_derivation/Run()
	rustg_time_reset("bulge_derivation")
	// What is derived is kept for the round by its name, which says the family's stem but not these vars: the families
	// that share a stem (a shapes stem past small_cap, bulge_large_name(); a drapes stem, bulge_drape_name()) must
	// agree on them, or whichever is drawn first in a round decides for all of them.
	var/list/known = list()
	for(var/datum/bulge_family/family as anything in subtypesof(/datum/bulge_family))
		var/list/found = list()
		if(initial(family.shapes) && !initial(family.large_shapes_of))
			found["shapes stem [initial(family.shapes)]"] = list("top_row" = initial(family.top_row), "hem" = initial(family.hem), "long" = initial(family.long), "contained" = initial(family.contained), "curtain" = initial(family.curtain))
		if(initial(family.drapes))
			found["drapes stem [initial(family.drapes)]"] = list("worn_icon" = initial(family.worn_icon), "worn_icon_state" = initial(family.worn_icon_state), "start_x" = initial(family.start_x), "start_y" = initial(family.start_y), "drop" = initial(family.drop), "first_column" = initial(family.first_column), "last_column" = initial(family.last_column))
		for(var/stem in found)
			var/list/values = found[stem]
			var/list/first = known[stem]
			if(!first)
				values["family"] = family
				known[stem] = values
				continue
			for(var/var_name in values)
				if("[values[var_name]]" != "[first[var_name]]")
					TEST_FAIL("[family] and [first["family"]] share the [stem] but not its [var_name] ([values[var_name]], [first[var_name]]): what is derived for the stem is kept by its names.")
	var/list/shapes = list()
	for(var/datum/sprite_accessory/genital/penis/shape as anything in subtypesof(/datum/sprite_accessory/genital/penis))
		if(initial(shape.icon_state) && initial(shape.icon_state) != "none")
			shapes += shape
	var/list/covering = list()
	// The shapes past small_cap and the anatomy each leaves bare, every state once, from the family that owns it.
	for(var/datum/bulge_family/family as anything in subtypesof(/datum/bulge_family))
		if(initial(family.large_shapes_of))
			continue
		for(var/hard in list(FALSE, TRUE))
			if(hard && initial(family.loincloth))
				continue
			for(var/size in initial(family.small_cap) + 1 to (hard ? initial(family.hard_cap) : initial(family.half_cap)))
				for(var/digi in list(FALSE, TRUE))
					for(var/datum/sprite_accessory/genital/penis/shape as anything in shapes)
						if(!initial(shape.bulge_hyper))
							continue
						for(var/toned in (initial(shape.has_skintone_shading) ? list(TRUE, FALSE) : list(FALSE)))
							var/datum/bulge_sheet_state/where = bulge_shape_where(family, hard, size, digi, shape, toned)
							if(!where || visited["shape [where.icon_state]"])
								continue
							record(where.icon_state, "shape")
							compare(bulge_shape(family, hard, size, digi, shape, toned), where.icon_state)
							var/datum/bulge_print_template/bare = bulge_derive_large(family, hard, size, digi, shape, toned, TRUE)
							var/datum/bulge_sheet_state/exposed = bulge_exposed(family, hard, size, digi, shape, toned)
							if(!bare)
								covering += where.icon_state
								if(exposed)
									TEST_FAIL("[where.icon_state]: covers the penis, yet shows [exposed.icon_state].")
								continue
							if(!exposed)
								TEST_FAIL("[where.icon_state]: leaves anatomy bare, but has no exposed mask.")
								continue
							record(exposed.icon_state, "bare")
							compare(bare, "bare [exposed.icon_state]")
							// Its mask tile: white where the derived mask has a pixel, clear elsewhere and facing north.
							var/list/wanted = list()
							for(var/facing in list(SOUTH, NORTH, EAST, WEST))
								var/list/mask = new /list(1024)
								var/list/pixels = bare.pixels_facing(facing)
								for(var/index = 1; index <= length(pixels); index += 3)
									mask[pixels[index + 1] * 32 + pixels[index] + 1] = TRUE
								wanted += list(mask)
							check(bulge_mask_tile(exposed), wanted, "[exposed.icon_state] mask tile")
	// Every loincloth's drapes and cuts, at every length from 1 to 100 inches.
	for(var/datum/bulge_family/family as anything in subtypesof(/datum/bulge_family))
		if(!initial(family.drapes))
			continue
		for(var/datum/sprite_accessory/genital/penis/shape as anything in shapes)
			for(var/toned in (initial(shape.has_skintone_shading) ? list(TRUE, FALSE) : list(FALSE)))
				var/cap = initial(shape.max_sprite_size_affix)
				if(toned && initial(shape.skintone_max_sprite_size_affix))
					cap = initial(shape.skintone_max_sprite_size_affix)
				for(var/length_inches in 1 to 100)
					var/size = bulge_size(length_inches)
					var/sprite_size = bulge_sprite_size(length_inches, cap)
					var/datum/bulge_print_template/drape = bulge_drape(family, size, sprite_size, shape, toned)
					if(drape && !visited["drape [drape.icon_state]"])
						record(drape.icon_state, "drape")
						compare(drape, drape.icon_state)
					var/datum/bulge_sheet_state/cut = bulge_loincloth_cut(family, size, sprite_size, shape, toned)
					if(!cut || visited["cut [cut.icon_state]"])
						continue
					record(cut.icon_state, "cut")
					check(bulge_patch_keep(cut), null, "[cut.icon_state] keep mask")
	sortTim(raw, GLOBAL_PROC_REF(cmp_text_asc))
	var/derivation = "[json_encode(counts)]; [length(covering)] covering; digest [md5(jointext(raw, "\n"))]"
	TEST_NOTICE(src, "Derived [derivation]; [errors] errors, in [round(rustg_time_microseconds("bulge_derivation") / 1000)] ms.")
	TEST_ASSERT_EQUAL(errors, 0, "States derived as nothing, or masks drawn otherwise than their pixels")
	TEST_ASSERT_EQUAL(derivation, BULGE_DERIVATION_RECORD, "What is derived past small_cap: a change to it needs approval (check the corpus), then a new record")

/// Records a state as derived.
/datum/unit_test/bulge_derivation/proc/record(state, kind)
	visited["[kind] [state]"] = TRUE
	counts[kind] = (counts[kind] || 0) + 1

/// Adds a derived template's pixels, facing south, east and west, to the digest; fails it when nothing was derived.
/datum/unit_test/bulge_derivation/proc/compare(datum/bulge_print_template/mine, what)
	if(!mine)
		errors++
		TEST_FAIL("[what]: nothing derived")
		return
	for(var/facing in list(SOUTH, EAST, WEST))
		var/list/found = mine.pixels_facing(facing)
		raw += "[what] [facing] [found ? jointext(found, ",") : ""]"

/**
 * Adds a derived icon (a mask tile or a keep mask, its state "" facing four ways) to the digest, and reports its pixels
 * that are neither opaque white nor clear or, given `wanted`, that differ from it: facing south, north, east and west,
 * a list by row * 32 + column + 1 (from the top left) that is TRUE where the icon must be opaque white; everywhere else
 * it must be clear.
 */
/datum/unit_test/bulge_derivation/proc/check(icon/built, list/wanted, what)
	var/static/list/facings = list(SOUTH, NORTH, EAST, WEST)
	var/bad = 0
	for(var/index in 1 to length(facings))
		var/list/mask = wanted?[index]
		var/list/pixels = list()
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/pixel = built.GetPixel(x, y, "", facings[index])
				pixels += pixel || "-"
				if(mask ? (mask[(32 - y) * 32 + x] ? pixel != "#ffffff" : !isnull(pixel)) : (pixel && pixel != "#ffffff"))
					bad++
		raw += "[what] [facings[index]] [jointext(pixels, ",")]"
	if(bad)
		errors += bad
		TEST_FAIL("[what]: [bad] pixels are not what it must draw")

/**
 * What the shapes past small_cap are derived from (templates.dm), pinned: every penis sprite state a derivation can
 * read, and the testicles drawn under them, facing south, east and west; each loincloth's own sprite, every way; and
 * the penis shapes' data the derivation reads. A change to any of them changes bulges on screen, so it needs approval.
 * Every penis and testicle sprite must also stay inside the window a derivation reads of it, the ways it reads it: a
 * penis sprite facing south, east and west, or only facing east, for a drape, where the penis shape has no shapes past
 * small_cap (the tentacles).
 */
/datum/unit_test/bulge_derivation/pin
	priority = TEST_DEFAULT

/datum/unit_test/bulge_derivation/pin/Run()
	var/list/text = list()
	var/list/sprites = list()
	for(var/datum/sprite_accessory/genital/penis/shape as anything in subtypesof(/datum/sprite_accessory/genital/penis))
		if(!initial(shape.icon_state) || initial(shape.icon_state) == "none")
			continue
		text += "[shape] [initial(shape.icon)] [initial(shape.icon_state)] [initial(shape.max_sprite_size_affix)] [initial(shape.skintone_max_sprite_size_affix)] [initial(shape.has_skintone_shading)] [initial(shape.color_src)] [initial(shape.bulge_hyper)] [initial(shape.bulge_untoned)]"
		for(var/size in 1 to 7)
			for(var/hard in list(FALSE, TRUE))
				for(var/untoned in list(FALSE, TRUE))
					var/state = bulge_penis_state(shape, size, hard, untoned)
					if(state)
						sprites["[initial(shape.icon)]|[state]"] = list(initial(shape.icon), state, initial(shape.bulge_hyper) ? list(SOUTH, EAST, WEST) : list(EAST))
	// The testicles under every penis (templates.dm's BULGE_TESTICLES_SPRITE and BULGE_TESTICLES_STATE).
	sprites["testicles"] = list('modular_nova/master_files/icons/mob/sprite_accessory/genitals/testicles_onmob.dmi', "m_testicles_pair_3_s_FRONT_UNDER", list(SOUTH, EAST, WEST))
	for(var/datum/bulge_family/family as anything in subtypesof(/datum/bulge_family))
		if(initial(family.drapes))
			sprites["[family]"] = list(initial(family.worn_icon), initial(family.worn_icon_state), null)
	var/list/names = list()
	for(var/name in sprites)
		names += name
	sortTim(names, GLOBAL_PROC_REF(cmp_text_asc))
	// Each sprite's frames as GetPixel() reads them, bottom row first, "-" where clear: a penis or testicle sprite facing
	// south, east and west, a loincloth every way.
	for(var/name in names)
		var/list/sprite = sprites[name]
		var/list/facings = sprite[3] // The ways a derivation reads a penis or testicle sprite inside its window.
		for(var/facing in (facings ? list(SOUTH, EAST, WEST) : list(SOUTH, NORTH, EAST, WEST)))
			var/icon/frame = icon(sprite[1], sprite[2], facing, 1, 0)
			var/list/pixels = list()
			var/count = 0
			for(var/y in 1 to 32)
				for(var/x in 1 to 32)
					var/pixel = frame.GetPixel(x, y)
					if(pixel)
						count++
					pixels += pixel || "-"
			text += "[name] [facing] [jointext(pixels, ",")]"
			if(facings && (facing in facings) && count * 2 != length(bulge_sprite_pixels(sprite[1], sprite[2], facing)))
				TEST_FAIL("[sprite[2]] facing [dir2text(facing)] draws outside the window bulges past small_cap read of it.")
	// Sorted, so that the order the types are defined in does not change the hash.
	sortTim(text, GLOBAL_PROC_REF(cmp_text_asc))
	var/hash = md5(jointext(text, "\n"))
	TEST_ASSERT_EQUAL(hash, BULGE_DERIVATION_INPUTS, "Bulges past small_cap are derived from these sprites and penis shapes: a change to them needs approval (check bulge_derivation and the corpus), then pin the new hash here.")

#undef BULGE_DERIVATION_INPUTS
#undef BULGE_DERIVATION_RECORD
#undef BULGE_IDENTITIES_RECORD
