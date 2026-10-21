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

/// Chest tests on a body built from DNA.
/datum/unit_test/breast_bounce
	abstract_type = /datum/unit_test/breast_bounce

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

/// A top over flexing pecs moves with them from their first flex, a frame for each of the flex's, and stops with them: its fits
/// over every flex are made in the background as soon as it's drawn over the pecs, before any flex asks for one.
/datum/unit_test/breast_bounce/flexing_top

/datum/unit_test/breast_bounce/flexing_top/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Pec flexes need genitals, which the ERP config disables.")
		return

	var/mob/living/carbon/human/consistent/flexer = allocate(/mob/living/carbon/human/consistent)
	flexer.physique = MALE
	flexer.socks = "Nude"
	var/obj/item/organ/genital/breasts/pecs = give_breasts(flexer, /datum/sprite_accessory/genital/breasts/pecs/big::name, 0)
	TEST_ASSERT_NOTNULL(pecs, "The test human did not get pecs.")
	flexer.undershirt = /datum/sprite_accessory/clothing/undershirt/shirt::name
	flexer.update_body()
	SSgarment_fitting.finish_all()
	var/still_top = drawn_underclothes(flexer)?.icon
	TEST_ASSERT(isfile(still_top), "A top over pecs wasn't fitted to them.")

	TEST_ASSERT(pecs.start_flex(), "The pec flex did not start.")
	var/flexing_top = drawn_underclothes(flexer)?.icon
	TEST_ASSERT(isfile(flexing_top) && flexing_top != still_top, "A top over pecs stayed still through their first flex.")
	TEST_ASSERT_EQUAL(garment_frame_count(icon(flexing_top)), length(garment_pec_flex(BREASTS_ICON_PEC_BOUNCE)["delays"]), "A top over flexing pecs isn't animated a frame for each of the flex's.")
	pecs.stop_bounce()
	TEST_ASSERT_EQUAL(drawn_underclothes(flexer)?.icon, still_top, "A top kept moving once the flex stopped.")
	TEST_ASSERT(pecs.start_flex(alternating = TRUE, slow = TRUE), "The alternating slow flex did not start.")
	var/alternating_top = drawn_underclothes(flexer)?.icon
	TEST_ASSERT(isfile(alternating_top) && alternating_top != still_top && alternating_top != flexing_top, "A top over pecs stayed still through their first alternating slow flex.")
	pecs.stop_bounce()

/// Pecs keep a female body's torso out of the female cut, which then shapes its lower body alone: a top-only uniform is drawn
/// over them as on a male body, and a full one is cut apart from both a male body's and a female body's without pecs.
/datum/unit_test/breast_bounce/female_cut

/datum/unit_test/breast_bounce/female_cut/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Pecs need genitals, which the ERP config disables.")
		return

	var/list/bodies = list()
	for(var/physique in list(MALE, FEMALE, FEMALE))
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		body.physique = physique
		bodies += body
	TEST_ASSERT_NOTNULL(give_breasts(bodies[3], /datum/sprite_accessory/genital/breasts/pecs::name, 0), "The test human did not get pecs.")
	for(var/mob/living/carbon/human/body as anything in bodies)
		body.update_body(is_creating = TRUE)
	var/list/drawn = drawn_uniforms(bodies, /obj/item/clothing/under/color/jumpskirt/grey)
	TEST_ASSERT_NOTEQUAL(drawn[2], drawn[1], "A female body's top-only uniform isn't cut.")
	TEST_ASSERT_EQUAL(drawn[3], drawn[1], "A top-only uniform over pecs on a female body is cut.")
	var/list/jumpsuits = drawn_uniforms(bodies, /obj/item/clothing/under/color/grey)
	TEST_ASSERT(jumpsuits[3] != jumpsuits[1] && jumpsuits[3] != jumpsuits[2], "A full uniform over pecs on a female body isn't cut to its lower body alone.")

/**
 * Returns the icon each body draws a uniform of `uniform_type` with, in order, and takes the uniforms off again.
 *
 * Arguments:
 * - bodies: The test humans.
 * - uniform_type: The uniform's type.
 */
/datum/unit_test/breast_bounce/female_cut/proc/drawn_uniforms(list/bodies, uniform_type)
	. = list()
	for(var/mob/living/carbon/human/body as anything in bodies)
		var/obj/item/clothing/under/uniform = allocate(uniform_type)
		if(!body.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING))
			TEST_FAIL("Could not dress the test human in [uniform_type].")
		. += list(drawn_worn_sprite(body, UNIFORM_LAYER)?.icon)
		qdel(uniform)
