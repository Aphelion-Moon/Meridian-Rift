/// Every pec shape has its still states, and twins on its jiggle and every flex sheet, with and without skin tone shading.
/// A shape drawn with a back (an ADJ state) has its back on every sheet too: the back draws from the animation sheet while one plays.
/datum/unit_test/pec_states

/datum/unit_test/pec_states/Run()
	var/list/suffixes = list("", "_s")
	for(var/datum/sprite_accessory/genital/breasts/shape as anything in typesof(/datum/sprite_accessory/genital/breasts/pecs))
		var/list/sheets = list(initial(shape.icon), initial(shape.jiggle_icon), BREASTS_ICON_PEC_BOUNCE, BREASTS_ICON_PEC_BOUNCE_ALTERNATE, BREASTS_ICON_PEC_BOUNCE_SLOW, BREASTS_ICON_PEC_BOUNCE_ALTERNATE_SLOW)
		for(var/suffix in suffixes)
			var/state = "m_breasts_[initial(shape.icon_state)]_0[suffix]"
			var/has_back = icon_exists(initial(shape.icon), "[state]_ADJ")
			for(var/sheet in sheets)
				TEST_ASSERT(icon_exists(sheet, "[state]_FRONT_UNDER"), "[shape] has no [state]_FRONT_UNDER state in [sheet].")
				TEST_ASSERT(!has_back || icon_exists(sheet, "[state]_ADJ"), "[shape] has no [state]_ADJ state in [sheet], so its back vanishes while it animates.")

/// Every state on a breast sheet has a bouncing twin, under the same name, on that sheet's jiggle sheet.
/datum/unit_test/breast_jiggle_states

/datum/unit_test/breast_jiggle_states/Run()
	var/list/checked_sheets
	for(var/shape_name, shape_entry in SSaccessories.sprite_accessories[ORGAN_SLOT_BREASTS])
		var/datum/sprite_accessory/genital/breasts/shape = shape_entry
		if(!shape.jiggle_icon || (shape.icon in checked_sheets))
			continue
		LAZYADD(checked_sheets, shape.icon)
		var/list/bouncing = icon_states(shape.jiggle_icon)
		for(var/state in icon_states(shape.icon))
			if(!(state in bouncing))
				TEST_FAIL("[shape.jiggle_icon] has no bouncing twin of [shape.icon] state [state].")
	TEST_ASSERT(LAZYLEN(checked_sheets), "No breast shape has a jiggle sheet.")

/// A bare, upright chest bounces on its jiggle sheet and settles back; a covered, flat, lying or fighting one can't.
/datum/unit_test/breast_bounce

/datum/unit_test/breast_bounce/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Bouncing needs genitals, which the ERP config disables.")
		return

	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/chest = give_breasts(human, "Pair", 3)
	TEST_ASSERT_NOTNULL(chest, "The test human did not get breasts.")
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = chest.bodypart_overlay
	var/still_sheet = overlay.sprite_datum.get_special_icon(human, overlay)

	TEST_ASSERT_NULL(chest.bounce_blocker(), "A bare, upright chest could not bounce.")
	TEST_ASSERT(chest.start_bounce(), "The bounce did not start.")
	TEST_ASSERT_EQUAL(overlay.sprite_datum.get_special_icon(human, overlay), BREASTS_ICON_JIGGLE, "Bouncing breasts did not draw from the jiggle sheet.")
	TEST_ASSERT_EQUAL(chest.bounce_cycles_left, round(BREAST_BOUNCE_DEFAULT_DURATION / BREAST_BOUNCE_CYCLE, 1) - 1, "The default bounce has the wrong number of cycles.")
	chest.stop_bounce()
	TEST_ASSERT(!chest.is_bouncing(), "The bounce did not stop.")
	TEST_ASSERT_EQUAL(overlay.sprite_datum.get_special_icon(human, overlay), still_sheet, "Settled breasts stayed on the jiggle sheet.")
	chest.start_bounce(1 MINUTES)
	TEST_ASSERT_EQUAL(chest.bounce_cycles_left, round(BREAST_BOUNCE_MAX_DURATION / BREAST_BOUNCE_CYCLE, 1) - 1, "A long bounce ran past the cap.")

	// Covering up ends a bounce at its next cycle and keeps a new one from starting.
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(human.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Could not dress the test human.")
	chest.bounce_cycle()
	TEST_ASSERT(!chest.is_bouncing(), "A covered chest kept bouncing.")
	TEST_ASSERT(!chest.start_bounce(), "A covered chest started bouncing.")
	qdel(uniform)
	TEST_ASSERT_NULL(chest.bounce_blocker(), "The chest could not bounce once bare again.")

	human.set_resting(TRUE, instant = TRUE)
	TEST_ASSERT_NOTNULL(chest.bounce_blocker(), "A chest lying down could bounce.")
	human.set_resting(FALSE, instant = TRUE)
	human.set_combat_mode(TRUE)
	TEST_ASSERT_NOTNULL(chest.bounce_blocker(), "A chest in combat mode could bounce.")
	human.set_combat_mode(FALSE)

	// The emote starts a bounce, and using it again stops it.
	var/datum/emote/living/lewd/jiggle/jiggle = locate() in GLOB.emote_list["jiggle"]
	TEST_ASSERT_NOTNULL(jiggle, "The jiggle emote is not registered.")
	jiggle.run_emote(human, "5")
	TEST_ASSERT(chest.is_bouncing(), "The jiggle emote did not start a bounce.")
	TEST_ASSERT_EQUAL(chest.bounce_cycles_left, round(5 SECONDS / BREAST_BOUNCE_CYCLE, 1) - 1, "The jiggle emote ignored its duration.")
	jiggle.run_emote(human)
	TEST_ASSERT(!chest.is_bouncing(), "Using the jiggle emote again did not stop the bounce.")

	chest.start_bounce()
	chest.Remove(human, special = TRUE)
	TEST_ASSERT(!chest.is_bouncing(), "Removed breasts kept bouncing.")

	var/mob/living/carbon/human/consistent/flat = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTNULL(give_breasts(flat, "Pair", 0)?.bounce_blocker(), "A flat chest could bounce.")

	var/mob/living/carbon/human/consistent/pec_owner = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/pecs = give_breasts(pec_owner, "Pecs", 0)
	TEST_ASSERT(pecs?.start_bounce(), "Pecs could not bounce.")
	var/datum/bodypart_overlay/mutant/genital/breasts/pec_overlay = pecs.bodypart_overlay
	TEST_ASSERT_EQUAL(pec_overlay.sprite_datum.get_special_icon(pec_owner, pec_overlay), BREASTS_ICON_JIGGLE, "Bouncing pecs did not draw from the jiggle sheet.")

	var/mob/living/carbon/human/consistent/alt_owner = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/alt = give_breasts(alt_owner, "Pair (Alt)", 3)
	TEST_ASSERT(alt?.start_bounce(), "Alt breasts could not bounce.")
	var/datum/bodypart_overlay/mutant/genital/breasts/alt_overlay = alt.bodypart_overlay
	TEST_ASSERT_EQUAL(alt_overlay.sprite_datum.get_special_icon(alt_owner, alt_overlay), BREASTS_ICON_ALT_JIGGLE, "Bouncing Alt breasts did not draw from the Alt jiggle sheet.")

/// Pec flexes draw from their own sheets, work under clothes, switch between each other, and need pecs.
/datum/unit_test/breast_bounce/pec_flex

/datum/unit_test/breast_bounce/pec_flex/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Pec flexes need genitals, which the ERP config disables.")
		return

	var/mob/living/carbon/human/consistent/flexer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/pecs = give_breasts(flexer, "Bigger pecs", 0)
	TEST_ASSERT_NOTNULL(pecs, "The test human did not get pecs.")
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = pecs.bodypart_overlay
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(flexer.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Could not dress the test human.")
	TEST_ASSERT_NULL(pecs.flex_blocker(), "Clothes stopped a pec flex.")
	TEST_ASSERT(pecs.start_flex(), "The pec flex did not start.")
	TEST_ASSERT_EQUAL(overlay.sprite_datum.get_special_icon(flexer, overlay), BREASTS_ICON_PEC_BOUNCE, "Flexing pecs did not draw from the pec bounce sheet.")

	var/datum/emote/living/carbon/human/pecbounce/alternate/alternate = locate() in GLOB.emote_list["pbounce2"]
	TEST_ASSERT_NOTNULL(alternate, "The *pbounce2 emote is not registered.")
	alternate.run_emote(flexer)
	TEST_ASSERT_EQUAL(overlay.sprite_datum.get_special_icon(flexer, overlay), BREASTS_ICON_PEC_BOUNCE_ALTERNATE, "*pbounce2 did not take over from the other flex.")
	alternate.run_emote(flexer)
	TEST_ASSERT(!pecs.is_bouncing(), "Using *pbounce2 again did not stop it.")

	var/datum/emote/living/carbon/human/pecbounce/together = locate() in GLOB.emote_list["pbounce"]
	TEST_ASSERT_NOTNULL(together, "The *pbounce emote is not registered.")
	together.run_emote(flexer, "5")
	TEST_ASSERT(pecs.is_playing(BREASTS_ICON_PEC_BOUNCE), "*pbounce did not start.")
	TEST_ASSERT_EQUAL(pecs.bounce_cycles_left, round(5 SECONDS / BREAST_BOUNCE_CYCLE, 1) - 1, "*pbounce ignored its duration.")

	// The slow flexes have keys of their own, and only one emote answers each key.
	for(var/key, sheet in list("pbounces" = BREASTS_ICON_PEC_BOUNCE_SLOW, "pbounce2s" = BREASTS_ICON_PEC_BOUNCE_ALTERNATE_SLOW))
		TEST_ASSERT_EQUAL(length(GLOB.emote_list[key]), 1, "More than one emote answers *[key].")
		var/datum/emote/living/carbon/human/pecbounce/slow_flex = GLOB.emote_list[key][1]
		slow_flex.run_emote(flexer)
		TEST_ASSERT(pecs.is_playing(sheet), "*[key] did not play its slow sheet.")
	pecs.stop_bounce()

	flexer.set_resting(TRUE, instant = TRUE)
	TEST_ASSERT_NOTNULL(pecs.flex_blocker(), "Pecs flexed lying down.")
	flexer.set_resting(FALSE, instant = TRUE)

	var/mob/living/carbon/human/consistent/breast_owner = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTNULL(give_breasts(breast_owner, "Pair", 3)?.flex_blocker(), "Breasts could do a pec flex.")

/// Gives a test human bare breasts of the named shape and size, built from DNA like a real character's.
/datum/unit_test/breast_bounce/proc/give_breasts(mob/living/carbon/human/owner, shape_name, size)
	RETURN_TYPE(/obj/item/organ/genital/breasts)
	owner.dna.features["breasts_size"] = size
	owner.dna.features["breasts_uses_skincolor"] = FALSE
	owner.dna.features["breasts_uses_skintones"] = FALSE
	owner.dna.features["breasts_lactation"] = FALSE
	owner.dna.mutant_bodyparts[ORGAN_SLOT_BREASTS] = build_mutant_part(shape_name, list("#FCCCB3"))
	var/obj/item/organ/genital/breasts/chest = allocate(/obj/item/organ/genital/breasts, owner.loc)
	chest.build_from_dna(owner.dna, ORGAN_SLOT_BREASTS)
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = chest.bodypart_overlay
	if(!overlay.set_appearance_from_dna(owner.dna) || !chest.Insert(owner, special = TRUE))
		return null
	owner.underwear = "Nude"
	owner.undershirt = "Nude"
	owner.bra = "Nude"
	owner.underwear_visibility = NONE
	chest.visibility_preference = GENITAL_HIDDEN_BY_CLOTHES
	return chest

/// Chest tokens read "pecs" for a pec owner and breast words for anyone else, and so do pec menu labels.
/datum/unit_test/interaction_chest_words

/datum/unit_test/interaction_chest_words/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Chest wording needs genitals, which the ERP config disables.")
		return

	var/mob/living/carbon/human/consistent/pec_owner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/breast_owner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/nippleless_owner = allocate(/mob/living/carbon/human/consistent)
	give_chest(pec_owner, pecs = TRUE)
	give_chest(breast_owner, pecs = FALSE)
	give_chest(nippleless_owner, pecs = TRUE, nippleless = TRUE)
	TEST_ASSERT(pec_owner.has_pecs(), "A pec chest did not report pecs.")
	TEST_ASSERT(!breast_owner.has_pecs(), "A pair of breasts reported pecs.")
	TEST_ASSERT(nippleless_owner.has_nippleless_pecs() && !pec_owner.has_nippleless_pecs(), "Nippleless pecs were not told apart.")

	var/datum/interaction/grope = allocate(/datum/interaction)
	grope.name = "Grope breasts"
	grope.name_pecs = "Grope pecs"
	grope.target_required_parts = list(ORGAN_SLOT_BREASTS)
	var/template = "%TARGET_BREASTS% %TARGET_TITS% %TARGET_BOOBS% %TARGET_BREAST% %TARGET_BOOB% %TARGET_CHEST%"
	TEST_ASSERT_EQUAL(grope.format_message_for(template, breast_owner, pec_owner), "pecs pecs pecs pec pec pecs", "A pec owner's chest words are wrong.")
	TEST_ASSERT_EQUAL(grope.format_message_for(template, pec_owner, breast_owner), "breasts tits boobs breast boob chest", "A breast owner's chest words are wrong.")
	TEST_ASSERT_EQUAL(grope.format_message_for("%USER_CHEST%", pec_owner, breast_owner), "pecs", "The user's chest token followed the target's chest.")
	TEST_ASSERT_EQUAL(grope.display_name_for(breast_owner, pec_owner), "Grope pecs", "A pec owner's menu label kept the breast wording.")
	TEST_ASSERT_EQUAL(grope.display_name_for(pec_owner, breast_owner), "Grope breasts", "A breast owner's menu label used the pec wording.")
	TEST_ASSERT_EQUAL(grope.display_name_for(breast_owner, nippleless_owner), "Grope pecs", "Nippleless pecs without their own label did not fall back to the pec label.")

	grope.user_required_parts = list(ORGAN_SLOT_BREASTS)
	TEST_ASSERT_EQUAL(grope.display_name_for(pec_owner, breast_owner), "Grope pecs", "A label for the user's own chest followed the target's chest.")

	// Nipple interactions read their nippleless label and text for nippleless pecs only.
	var/datum/interaction/suck = allocate(/datum/interaction)
	suck.name = "Suck nipples"
	suck.name_nippleless = "Kiss pecs"
	suck.target_required_parts = list(ORGAN_SLOT_BREASTS)
	suck.message = list("nipples")
	suck.message_nippleless = list("pecs")
	TEST_ASSERT_EQUAL(suck.display_name_for(breast_owner, nippleless_owner), "Kiss pecs", "Nippleless pecs kept the nipple label.")
	TEST_ASSERT_EQUAL(suck.display_name_for(breast_owner, pec_owner), "Suck nipples", "Pecs with nipples took the nippleless label.")
	var/list/nippleless_texts = suck.texts_for(suck.message, suck.message_nippleless, breast_owner, nippleless_owner)
	var/list/nipple_texts = suck.texts_for(suck.message, suck.message_nippleless, breast_owner, pec_owner)
	TEST_ASSERT_EQUAL(nippleless_texts[1], "pecs", "Nippleless pecs kept the nipple messages.")
	TEST_ASSERT_EQUAL(nipple_texts[1], "nipples", "Pecs with nipples took the nippleless messages.")

/datum/unit_test/interaction_chest_words/proc/give_chest(mob/living/carbon/human/owner, pecs, nippleless = FALSE)
	var/obj/item/organ/genital/breasts/chest = new
	chest.pecs = pecs
	chest.nippleless = nippleless
	chest.Insert(owner, special = TRUE)

/// Pecs are part of the body's shape: drawn under the underclothes that cover them, as their nippleless twin, and hidden by a
/// uniform. Examine still reads them as covered. A top over them is fitted to them, and cached apart for each pec shape, with
/// nipples and without. Breasts stay hidden by underclothes.
/datum/unit_test/breast_bounce/under_underclothes

/datum/unit_test/breast_bounce/under_underclothes/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Pecs under underclothes need genitals, which the ERP config disables.")
		return

	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/pecs = give_breasts(owner, /datum/sprite_accessory/genital/breasts/pecs::name, 0)
	TEST_ASSERT_NOTNULL(pecs, "The test human did not get pecs.")
	var/datum/bodypart_overlay/mutant/genital/breasts/pec_overlay = pecs.bodypart_overlay
	var/obj/item/bodypart/chest/chest = owner.get_bodypart(BODY_ZONE_CHEST)
	owner.undershirt = /datum/sprite_accessory/clothing/undershirt/shirt::name
	TEST_ASSERT(pec_overlay.can_draw_on_bodypart(chest, owner), "Pecs under an undershirt were hidden rather than drawn under it.")
	TEST_ASSERT(("[/datum/sprite_accessory/genital/breasts/pecs/nippleless::icon_state]_0" in pec_overlay.icon_render_key(chest)), "Pecs drawn under an undershirt kept their nipples.")
	TEST_ASSERT(!pecs.is_exposed() && !(pecs.get_description_string(pec_overlay.sprite_datum) in owner.get_genital_description_lines()), "Examine read pecs under an undershirt as bare.")

	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(owner.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Could not dress the test human.")
	TEST_ASSERT(!pec_overlay.can_draw_on_bodypart(chest, owner), "A uniform did not hide pecs.")

	// A bare chest's top is drawn straight from its sheet; each pec shape, with nipples and without, fits it its own way.
	var/list/drawn_tops = list(/datum/sprite_accessory/clothing/undershirt/shirt::icon)
	for(var/datum/sprite_accessory/genital/breasts/shape as anything in typesof(/datum/sprite_accessory/genital/breasts/pecs))
		var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
		wearer.physique = MALE
		wearer.socks = "Nude"
		TEST_ASSERT_NOTNULL(give_breasts(wearer, shape::name, 0), "The test human did not get [shape::name].")
		wearer.undershirt = /datum/sprite_accessory/clothing/undershirt/shirt::name
		wearer.update_body()
		SSgarment_fitting.finish_all()
		var/drawn_top = drawn_underclothes(wearer)?.icon
		TEST_ASSERT(!(drawn_top in drawn_tops), "A top over [shape::name] was drawn as over another chest: unfitted, or fitted and cached for other pecs.")
		drawn_tops += drawn_top

	var/mob/living/carbon/human/consistent/breast_owner = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/breasts = give_breasts(breast_owner, /datum/sprite_accessory/genital/breasts/pair::name, 3)
	breast_owner.undershirt = /datum/sprite_accessory/clothing/undershirt/shirt::name
	var/datum/bodypart_overlay/mutant/genital/breasts/breast_overlay = breasts?.bodypart_overlay
	TEST_ASSERT(breast_overlay && !breast_overlay.can_draw_on_bodypart(breast_owner.get_bodypart(BODY_ZONE_CHEST), breast_owner), "Breasts under an undershirt were drawn.")

/// Tops cut for a chest with breasts draw their version for one without on any chest without breasts, pecs or none, but a
/// female body's without pecs: pure mesh for mesh tops with a bra drawn in, and pasties where each pec size has its nipples,
/// nippled or nippleless alike. Over breasts they're drawn as they are.
/datum/unit_test/breast_bounce/flat_mesh

/datum/unit_test/breast_bounce/flat_mesh/Run()
	var/datum/sprite_accessory/clothing/mesh = allocate(/datum/sprite_accessory/clothing/bra/fishnet_sleeves)
	var/datum/sprite_accessory/clothing/pasties = allocate(/datum/sprite_accessory/clothing/bra/pasties)
	var/mob/living/carbon/human/consistent/bare = allocate(/mob/living/carbon/human/consistent)
	var/flat_mesh = mesh.get_icon_state(MALE, bare.bodyshape, bare)
	var/flat_pasties = pasties.get_icon_state(MALE, bare.bodyshape, bare)
	TEST_ASSERT(flat_mesh != mesh.icon_state && icon_exists(mesh.icon, flat_mesh), "A mesh top on a male chest without breasts didn't draw its pure mesh.")
	TEST_ASSERT(flat_pasties != pasties.icon_state && icon_exists(pasties.icon, flat_pasties), "Pasties on a male chest without breasts didn't draw their own state.")
	TEST_ASSERT_EQUAL(mesh.get_icon_state(FEMALE, bare.bodyshape, bare), mesh.icon_state, "A mesh top on a female chest without breasts lost its bra.")
	TEST_ASSERT_EQUAL(pasties.get_icon_state(FEMALE, bare.bodyshape, bare), pasties.icon_state, "Pasties on a female chest without breasts moved.")
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Tops over breasts and pecs need genitals, which the ERP config disables.")
		return

	var/mob/living/carbon/human/consistent/breast_owner = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTNULL(give_breasts(breast_owner, /datum/sprite_accessory/genital/breasts/pair::name, 3), "The test human did not get breasts.")
	TEST_ASSERT_EQUAL(mesh.get_icon_state(MALE, breast_owner.bodyshape, breast_owner), mesh.icon_state, "A mesh top over breasts lost its bra.")
	TEST_ASSERT_EQUAL(pasties.get_icon_state(MALE, breast_owner.bodyshape, breast_owner), pasties.icon_state, "Pasties over breasts moved.")
	// Each pec size's pasties are its own, and nippled and nippleless pecs of a size share them.
	var/list/pasties_by_size = list()
	for(var/datum/sprite_accessory/genital/breasts/shape as anything in typesof(/datum/sprite_accessory/genital/breasts/pecs))
		var/mob/living/carbon/human/consistent/pec_owner = allocate(/mob/living/carbon/human/consistent)
		TEST_ASSERT_NOTNULL(give_breasts(pec_owner, shape::name, 0), "The test human did not get [shape::name].")
		TEST_ASSERT_EQUAL(mesh.get_icon_state(FEMALE, pec_owner.bodyshape, pec_owner), flat_mesh, "A mesh top over [shape::name] kept its bra.")
		var/pec_pasties = pasties.get_icon_state(FEMALE, pec_owner.bodyshape, pec_owner)
		TEST_ASSERT(icon_exists(pasties.icon, pec_pasties), "Pasties over [shape::name] draw [pec_pasties], which their sheet doesn't have.")
		var/size = shape::garment_fit_shape
		TEST_ASSERT(isnull(pasties_by_size[size]) || pasties_by_size[size] == pec_pasties, "Pasties over [shape::name] aren't those over its size's other pecs.")
		pasties_by_size[size] = pec_pasties
	var/list/drawn = list(pasties.icon_state, flat_pasties)
	for(var/size, size_pasties in pasties_by_size)
		TEST_ASSERT(!(size_pasties in drawn), "Pasties over [size] are drawn as over another chest.")
		drawn += size_pasties
