/**
 * Every fitness limb's sheet holds the states the limb draws, its hand's too: a hand draws from its arm's sheet, so a missing
 * one vanishes. A plain sheet's fitness sheets are the ones its fitness limbs draw, so a human with skin tones off is drawn
 * at their levels from the humanoid ones. A digitigrade leg keeps its plain sheet and draws its level's (fitness_sheet()), where
 * a missing state would leave it drawing today's leg.
 */
/datum/unit_test/fitness_sheet_states

/datum/unit_test/fitness_sheet_states/Run()
	var/checked = 0
	for(var/obj/item/bodypart/limb_type as anything in subtypesof(/obj/item/bodypart))
		var/level = limb_type::fitness_level
		if(!level)
			continue
		var/sheet = UNLINT(limb_type::icon_greyscale)
		var/state = "[limb_type::limb_id]_[limb_type::body_zone]"
		if(limb_type::bodyshape & BODYSHAPE_DIGITIGRADE)
			sheet = GLOB.fitness_limb_sheets[sheet]?[level]
			state += "_[ICON_KEY_DIGI]"
		else
			var/obj/item/bodypart/base_type = GLOB.fitness_limb_families[limb_type][1]
			TEST_ASSERT_EQUAL(GLOB.fitness_limb_sheets[UNLINT(base_type::icon_greyscale)]?[level], sheet, "[limb_type] draws [sheet], not the level [level] sheet of its plain sheet.")
		var/list/states = limb_type::is_dimorphic ? list("[state]_m", "[state]_f") : list(state)
		if(limb_type::aux_zone)
			states += "[limb_type::limb_id]_[limb_type::aux_zone]"
		for(var/needed in states)
			TEST_ASSERT(icon_exists(sheet, needed), "[limb_type] has no [needed] state in [sheet].")
		checked++
	TEST_ASSERT(checked, "No limb has fitness subtypes.")

/// Garments fitted to fitness limbs as they're drawn, and the limb changes that fit them again.
/datum/unit_test/fitted_garments
	abstract_type = /datum/unit_test/fitted_garments

/**
 * Underclothes are fitted to their wearer's fitness limbs as they're drawn, cached apart from a baseline body's, and fitted
 * again when a limb changes: a fitness arm refits a long-sleeved shirt, and an augment in its place draws it as it is again.
 * A digitigrade body's fitness leg refits the digitigrade state its underwear draws.
 */
/datum/unit_test/fitted_garments/underclothes

/datum/unit_test/fitted_garments/underclothes/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wear_only(wearer, /datum/sprite_accessory/clothing/undershirt/nova/longsleeve::name, "Nude")
	var/sheet = /datum/sprite_accessory/clothing/undershirt/nova/longsleeve::icon
	TEST_ASSERT_EQUAL(drawn_underclothes(wearer)?.icon, sheet, "A baseline body's shirt isn't drawn straight from its sheet.")
	swap_limb(wearer, /obj/item/bodypart/arm/right/fitness/level_5)
	SSgarment_fitting.finish_all()
	TEST_ASSERT_NOTEQUAL(drawn_underclothes(wearer)?.icon, sheet, "A fitness arm put on didn't refit the shirt.")
	swap_limb(wearer, /obj/item/bodypart/arm/right/robot)
	TEST_ASSERT_EQUAL(drawn_underclothes(wearer)?.icon, sheet, "An augment in place of the fitness arm left the shirt fitted.")

	var/mob/living/carbon/human/consistent/digi_wearer = allocate(/mob/living/carbon/human/consistent)
	swap_limb(digi_wearer, /obj/item/bodypart/leg/right/digitigrade)
	swap_limb(digi_wearer, /obj/item/bodypart/leg/left/digitigrade)
	wear_only(digi_wearer, "Nude", /datum/sprite_accessory/clothing/underwear/male_longjohns::name)
	var/mutable_appearance/digi_drawn = drawn_underclothes(digi_wearer)
	var/digi_state = "[/datum/sprite_accessory/clothing/underwear/male_longjohns::icon_state]_d"
	TEST_ASSERT(digi_drawn?.icon == /datum/sprite_accessory/clothing/underwear/male_longjohns::icon && digi_drawn.icon_state == digi_state, "A baseline digitigrade body's long johns aren't drawn straight from [digi_state].")
	swap_limb(digi_wearer, /obj/item/bodypart/leg/right/digitigrade/fitness/level_5)
	SSgarment_fitting.finish_all()
	TEST_ASSERT_NOTEQUAL(drawn_underclothes(digi_wearer)?.icon, /datum/sprite_accessory/clothing/underwear/male_longjohns::icon, "A digitigrade fitness leg put on didn't refit the long johns.")

/**
 * Dresses the wearer in only the given undershirt and underwear, by name, with a male cut, and draws them.
 *
 * Arguments:
 * - wearer: The test human.
 * - undershirt_name: The undershirt's name, or "Nude".
 * - underwear_name: The underwear's name, or "Nude".
 */
/datum/unit_test/fitted_garments/underclothes/proc/wear_only(mob/living/carbon/human/wearer, undershirt_name, underwear_name)
	wearer.physique = MALE
	wearer.undershirt = undershirt_name
	wearer.underwear = underwear_name
	wearer.bra = "Nude"
	wearer.socks = "Nude"
	wearer.underwear_visibility = NONE
	wearer.update_body()

/**
 * Returns the appearance a test human's only underclothes are drawn as. Their layer also holds what their worn emissives are
 * drawn with (prepare_worn_emissive_overlays()), which has no sprite.
 *
 * Arguments:
 * - wearer: The test human.
 */
/proc/drawn_underclothes(mob/living/carbon/human/wearer)
	RETURN_TYPE(/mutable_appearance)
	for(var/mutable_appearance/drawn as anything in wearer.overlays_standing[BODY_LAYER])
		if(drawn.icon)
			return drawn
	return null

/**
 * Worn clothing is fitted to its wearer's fitness limbs as it's drawn, and drawn again when they change, where a limb put on
 * redraws only some slots and a level swap draws nothing: a fitness arm put on refits a jumpsuit, an augment in its place draws
 * it as it is again, and a level for the legs from the preferences refits it. A firesuit's separate glow is fitted with its
 * sprite, and its emissive blocker is the fitted sprite's.
 */
/datum/unit_test/fitted_garments/worn_clothing

/datum/unit_test/fitted_garments/worn_clothing/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.physique = MALE
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/rank/engineering/engineer)
	wearer.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING)
	var/sheet = jumpsuit.worn_icon
	TEST_ASSERT_EQUAL(drawn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "A baseline body's jumpsuit isn't drawn straight from its sheet.")
	swap_limb(wearer, /obj/item/bodypart/arm/right/fitness/level_5)
	SSgarment_fitting.finish_all()
	TEST_ASSERT_NOTEQUAL(drawn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "A fitness arm put on didn't refit the jumpsuit.")
	swap_limb(wearer, /obj/item/bodypart/arm/right/robot)
	TEST_ASSERT_EQUAL(drawn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "An augment in place of the fitness arm left the jumpsuit fitted.")
	var/datum/preference/choiced/fitness_level/legs = GLOB.preference_entries[/datum/preference/choiced/fitness_level/legs]
	legs.apply_to_human(wearer, FITNESS_LEVEL_MAX)
	SSgarment_fitting.finish_all()
	TEST_ASSERT_NOTEQUAL(drawn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "A level for the legs from the preferences didn't refit the jumpsuit.")

	var/obj/item/clothing/suit/firesuit = allocate(/obj/item/clothing/suit/utility/fire/firefighter)
	wearer.equip_to_slot_if_possible(firesuit, ITEM_SLOT_OCLOTHING)
	SSgarment_fitting.finish_all()
	var/mutable_appearance/fitted_sprite = drawn_sprite(wearer, SUIT_LAYER)
	TEST_ASSERT(fitted_sprite && fitted_sprite.icon != firesuit.worn_icon, "The firesuit isn't fitted to the legs.")
	var/raw_glow = "[firesuit.icon_state]-emissive"
	var/blocker = FALSE
	var/glow = FALSE
	for(var/mutable_appearance/drawn as anything in drawn_appearances(wearer.overlays_standing[SUIT_LAYER]))
		TEST_ASSERT_NOTEQUAL(drawn.icon_state, raw_glow, "The firesuit's glow isn't fitted with its sprite.")
		if(drawn == fitted_sprite || !drawn.icon)
			continue
		if(drawn.icon == fitted_sprite.icon)
			blocker = TRUE
		else if(drawn.icon != firesuit.worn_icon)
			glow = TRUE
	TEST_ASSERT(blocker, "The firesuit's emissive blocker isn't drawn from its fitted sprite.")
	TEST_ASSERT(glow, "The firesuit's fitted glow is missing.")

/**
 * A garment's first fit to a new fit waits for SSgarment_fitting: the garment is drawn as it is meanwhile, and drawn again,
 * fitted, once the fit is made, a uniform in its slot and underclothes with the body. A level changed while it's worn queues
 * the garment's new fit the same way, and a fit once made is found again whenever the garment is drawn.
 */
/datum/unit_test/fitted_garments/deferred

/datum/unit_test/fitted_garments/deferred/Run()
#ifndef GARMENT_FITS_DEFERRED
	TEST_NOTICE(src, "Garment fits are made as they're drawn: GARMENT_FITS_DEFERRED is off.")
#else
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.physique = MALE
	wearer.undershirt = /datum/sprite_accessory/clothing/undershirt/nova/longsleeve::name
	wearer.underwear = "Nude"
	wearer.bra = "Nude"
	wearer.socks = "Nude"
	wearer.underwear_visibility = NONE
	// Colours no other test draws it in, so every fit of it here is new.
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	jumpsuit.set_greyscale("#2d5b3a")
	wearer.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING)
	var/sheet = jumpsuit.worn_icon
	var/shirt_sheet = /datum/sprite_accessory/clothing/undershirt/nova/longsleeve::icon
	var/datum/preference/choiced/fitness_level/arms = GLOB.preference_entries[/datum/preference/choiced/fitness_level/arms]
	arms.apply_to_human(wearer, 4)
	wearer.update_body()
	TEST_ASSERT_EQUAL(drawn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "The jumpsuit's new fit was made as it was drawn, rather than queued.")
	TEST_ASSERT_EQUAL(drawn_underclothes(wearer)?.icon, shirt_sheet, "The shirt's new fit was made as it was drawn, rather than queued.")
	SSgarment_fitting.finish_all()
	var/fitted_icon = drawn_sprite(wearer, UNIFORM_LAYER)?.icon
	TEST_ASSERT_NOTEQUAL(fitted_icon, sheet, "The jumpsuit wasn't drawn again, fitted, once its fit was made.")
	TEST_ASSERT_NOTEQUAL(drawn_underclothes(wearer)?.icon, shirt_sheet, "The shirt wasn't drawn again, fitted, once its fit was made.")
	arms.apply_to_human(wearer, 2)
	wearer.update_body()
	TEST_ASSERT_EQUAL(drawn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "A level changed while the jumpsuit is worn didn't queue its new fit.")
	SSgarment_fitting.finish_all()
	var/refitted_icon = drawn_sprite(wearer, UNIFORM_LAYER)?.icon
	TEST_ASSERT(refitted_icon != sheet && refitted_icon != fitted_icon, "The jumpsuit wasn't drawn again, fitted to the new level.")
	// A made fit is found again, also for a suit drawn without a state of its own: drawing them again queues nothing.
	wearer.equip_to_slot_if_possible(allocate(/obj/item/clothing/suit/hooded), ITEM_SLOT_OCLOTHING)
	SSgarment_fitting.finish_all()
	wearer.update_worn_oversuit()
	wearer.update_worn_undersuit()
	wearer.update_body()
	TEST_ASSERT(!length(SSgarment_fitting.queue), "Garments whose fits were made queued [length(SSgarment_fitting.queue)] fits again when drawn again.")
#endif

/**
 * Puts a new limb of `limb_type` on the wearer, as surgery does, and deletes the old one.
 *
 * Arguments:
 * - wearer: The test human.
 * - limb_type: The new limb's type.
 */
/datum/unit_test/fitted_garments/proc/swap_limb(mob/living/carbon/human/wearer, limb_type)
	var/obj/item/bodypart/new_limb = allocate(limb_type)
	var/obj/item/bodypart/old_limb = wearer.get_bodypart(new_limb.body_zone)
	new_limb.replace_limb(wearer)
	qdel(old_limb)

/**
 * Returns the sprite a test human's worn item is drawn as in one of its overlay layers: the first appearance drawn there with
 * an icon. The layer also holds what the item's emissives are drawn with (prepare_worn_emissive_overlays()).
 *
 * Arguments:
 * - wearer: The test human.
 * - layer: The overlay layer, as UNIFORM_LAYER.
 */
/datum/unit_test/fitted_garments/proc/drawn_sprite(mob/living/carbon/human/wearer, layer)
	RETURN_TYPE(/mutable_appearance)
	for(var/mutable_appearance/drawn as anything in drawn_appearances(wearer.overlays_standing[layer]))
		if(drawn.icon)
			return drawn
	return null

/**
 * Returns every appearance drawn in an overlay layer, each before what it holds.
 *
 * Arguments:
 * - appearances: The layer's cached appearance, or list of them.
 */
/datum/unit_test/fitted_garments/proc/drawn_appearances(appearances)
	. = list()
	for(var/mutable_appearance/drawn as anything in (islist(appearances) ? appearances : list(appearances)))
		if(!drawn)
			continue
		. += drawn
		. += drawn_appearances(drawn.underlays)
		. += drawn_appearances(drawn.overlays)
