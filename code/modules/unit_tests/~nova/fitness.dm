/**
 * Every fitness limb's sheet holds the states the limb draws, its hand's too: a hand draws from its arm's sheet, so a missing
 * one vanishes. A plain sheet's size sheets are the ones its fitness limbs draw, so a human with skin tones off is drawn at
 * their size from the humanoid ones. A digitigrade leg keeps its plain sheet and draws its size's (fitness_sheet()), where a
 * missing state would leave it drawing today's leg. Each definition step has its overlay for what every limb but a hand or a
 * digitigrade leg draws, at the limb's size and at the Normal size, where a missing one draws nothing.
 */
/datum/unit_test/fitness_sheet_states

/datum/unit_test/fitness_sheet_states/Run()
	var/list/size_names = list("normal", "athletic", "muscular")
	var/checked = 0
	for(var/obj/item/bodypart/limb_type as anything in subtypesof(/obj/item/bodypart))
		var/size = limb_type::muscle_size
		if(!size)
			continue
		var/sheet = UNLINT(limb_type::icon_greyscale)
		var/state = "[limb_type::limb_id]_[limb_type::body_zone]"
		var/list/defined_sheets = list()
		if(limb_type::bodyshape & BODYSHAPE_DIGITIGRADE)
			sheet = GLOB.fitness_limb_sheets[sheet]?[size]
			state += "_[ICON_KEY_DIGI]"
		else
			var/obj/item/bodypart/base_type = GLOB.fitness_limb_families[limb_type][1]
			var/base_sheet = UNLINT(base_type::icon_greyscale)
			TEST_ASSERT_EQUAL(GLOB.fitness_limb_sheets[base_sheet]?[size], sheet, "[limb_type] draws [sheet], not its plain sheet's size [size] sheet.")
			defined_sheets[size_names[size + 1]] = sheet
			defined_sheets[size_names[1]] = base_sheet
		var/list/states = limb_type::is_dimorphic ? list("[state]_m", "[state]_f") : list(state)
		for(var/size_name, defined_sheet in defined_sheets)
			for(var/limb_state in states)
				for(var/step in 1 to MUSCLE_DEFINITION_MAX)
					var/overlay = "[limb_state]_[size_name]_[step]"
					TEST_ASSERT(icon_exists(GLOB.fitness_definition_sheets[defined_sheet], overlay), "[limb_type] has no [overlay] definition overlay for [defined_sheet].")
		if(limb_type::aux_zone)
			states += "[limb_type::limb_id]_[limb_type::aux_zone]"
		for(var/needed in states)
			TEST_ASSERT(icon_exists(sheet, needed), "[limb_type] has no [needed] state in [sheet].")
		checked++
	TEST_ASSERT(checked, "No limb has fitness subtypes.")

/**
 * A limb's muscle definition is its own and goes with it, and a new limb takes its body's: a Muscular, defined arm moved to a
 * plain body draws its definition there, and the arm its old body regrows comes back at the body's size and definition,
 * from its DNA, drawn.
 */
/datum/unit_test/fitness_definition_follows_limb

/datum/unit_test/fitness_definition_follows_limb/Run()
	var/mob/living/carbon/human/consistent/defined = allocate(/mob/living/carbon/human/consistent)
	defined.dna.features[FEATURE_MUSCLE_SIZE] = MUSCLE_SIZE_MUSCULAR
	defined.dna.features[FEATURE_MUSCLE_DEFINITION] = MUSCLE_DEFINITION_MAX
	defined.update_fitness_limbs()
	var/obj/item/bodypart/arm = defined.get_bodypart(BODY_ZONE_R_ARM)
	var/arm_type = arm.type
	TEST_ASSERT(draws_definition(arm), "A Muscular arm at the most definition draws none.")

	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/plain_arm = plain.get_bodypart(BODY_ZONE_R_ARM)
	arm.drop_limb()
	arm.replace_limb(plain)
	qdel(plain_arm)
	TEST_ASSERT(draws_definition(arm), "A defined arm moved to a plain body stopped drawing its definition.")

	defined.regenerate_limbs()
	var/obj/item/bodypart/regrown = defined.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_EQUAL(regrown?.type, arm_type, "An arm regrown on a Muscular body isn't Muscular.")
	TEST_ASSERT(draws_definition(regrown), "An arm regrown on a defined body draws no definition.")

/**
 * Whether a limb's drawn images hold a muscle definition overlay, drawn from one of the definition sheets.
 *
 * Arguments:
 * - limb: The limb.
 */
/datum/unit_test/fitness_definition_follows_limb/proc/draws_definition(obj/item/bodypart/limb)
	for(var/image/drawn as anything in limb?.get_limb_icon(FALSE))
		if(findtext("[drawn.icon]", "_definition.dmi"))
			return TRUE
	return FALSE

/// Garments fitted to fitness limbs as they're drawn, and the limb changes that fit them again.
/datum/unit_test/fitted_garments
	abstract_type = /datum/unit_test/fitted_garments

/**
 * Underclothes are fitted to their wearer's fitness limbs as they're drawn, cached apart from a Normal body's, and fitted again
 * when a limb changes: a Muscular arm refits a long-sleeved shirt, and an augment in its place draws it as it is again. A
 * digitigrade body's Muscular leg refits the digitigrade state its underwear draws.
 */
/datum/unit_test/fitted_garments/underclothes

/datum/unit_test/fitted_garments/underclothes/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wear_only(wearer, /datum/sprite_accessory/clothing/undershirt/nova/longsleeve::name, "Nude")
	var/sheet = /datum/sprite_accessory/clothing/undershirt/nova/longsleeve::icon
	TEST_ASSERT_EQUAL(drawn_underclothes(wearer)?.icon, sheet, "A Normal body's shirt isn't drawn straight from its sheet.")
	swap_limb(wearer, /obj/item/bodypart/arm/right/fitness/muscular)
	SSgarment_fitting.finish_all()
	TEST_ASSERT_NOTEQUAL(drawn_underclothes(wearer)?.icon, sheet, "A Muscular arm put on didn't refit the shirt.")
	swap_limb(wearer, /obj/item/bodypart/arm/right/robot)
	TEST_ASSERT_EQUAL(drawn_underclothes(wearer)?.icon, sheet, "An augment in place of the Muscular arm left the shirt fitted.")

	var/mob/living/carbon/human/consistent/digi_wearer = allocate(/mob/living/carbon/human/consistent)
	swap_limb(digi_wearer, /obj/item/bodypart/leg/right/digitigrade)
	swap_limb(digi_wearer, /obj/item/bodypart/leg/left/digitigrade)
	wear_only(digi_wearer, "Nude", /datum/sprite_accessory/clothing/underwear/male_longjohns::name)
	var/mutable_appearance/digi_drawn = drawn_underclothes(digi_wearer)
	var/digi_state = "[/datum/sprite_accessory/clothing/underwear/male_longjohns::icon_state]_d"
	TEST_ASSERT(digi_drawn?.icon == /datum/sprite_accessory/clothing/underwear/male_longjohns::icon && digi_drawn.icon_state == digi_state, "A Normal digitigrade body's long johns aren't drawn straight from [digi_state].")
	swap_limb(digi_wearer, /obj/item/bodypart/leg/right/digitigrade/fitness/muscular)
	SSgarment_fitting.finish_all()
	TEST_ASSERT_NOTEQUAL(drawn_underclothes(digi_wearer)?.icon, /datum/sprite_accessory/clothing/underwear/male_longjohns::icon, "A Muscular digitigrade leg put on didn't refit the long johns.")

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
 * redraws only some slots and a size swap draws nothing: a Muscular arm put on refits a jumpsuit, an augment in its place draws
 * it as it is again, and a muscle size from the preferences refits it. A firesuit's separate glow is fitted with its sprite,
 * and its emissive blocker is the fitted sprite's.
 */
/datum/unit_test/fitted_garments/worn_clothing

/datum/unit_test/fitted_garments/worn_clothing/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.physique = MALE
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/rank/engineering/engineer)
	wearer.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING)
	var/sheet = jumpsuit.worn_icon
	TEST_ASSERT_EQUAL(drawn_worn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "A Normal body's jumpsuit isn't drawn straight from its sheet.")
	swap_limb(wearer, /obj/item/bodypart/arm/right/fitness/muscular)
	SSgarment_fitting.finish_all()
	TEST_ASSERT_NOTEQUAL(drawn_worn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "A Muscular arm put on didn't refit the jumpsuit.")
	swap_limb(wearer, /obj/item/bodypart/arm/right/robot)
	TEST_ASSERT_EQUAL(drawn_worn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "An augment in place of the Muscular arm left the jumpsuit fitted.")
	var/datum/preference/numeric/muscles/size = GLOB.preference_entries[/datum/preference/numeric/muscles/size]
	size.apply_to_human(wearer, MUSCLE_SIZE_MUSCULAR)
	SSgarment_fitting.finish_all()
	TEST_ASSERT_NOTEQUAL(drawn_worn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "A muscle size from the preferences didn't refit the jumpsuit.")

	var/obj/item/clothing/suit/firesuit = allocate(/obj/item/clothing/suit/utility/fire/firefighter)
	wearer.equip_to_slot_if_possible(firesuit, ITEM_SLOT_OCLOTHING)
	SSgarment_fitting.finish_all()
	var/mutable_appearance/fitted_sprite = drawn_worn_sprite(wearer, SUIT_LAYER)
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
 * fitted, once the fit is made, a uniform in its slot and underclothes with the body. A size changed while it's worn queues
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
	var/datum/preference/numeric/muscles/size = GLOB.preference_entries[/datum/preference/numeric/muscles/size]
	size.apply_to_human(wearer, MUSCLE_SIZE_MUSCULAR)
	wearer.update_body()
	TEST_ASSERT_EQUAL(drawn_worn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "The jumpsuit's new fit was made as it was drawn, rather than queued.")
	TEST_ASSERT_EQUAL(drawn_underclothes(wearer)?.icon, shirt_sheet, "The shirt's new fit was made as it was drawn, rather than queued.")
	SSgarment_fitting.finish_all()
	var/fitted_icon = drawn_worn_sprite(wearer, UNIFORM_LAYER)?.icon
	TEST_ASSERT_NOTEQUAL(fitted_icon, sheet, "The jumpsuit wasn't drawn again, fitted, once its fit was made.")
	TEST_ASSERT_NOTEQUAL(drawn_underclothes(wearer)?.icon, shirt_sheet, "The shirt wasn't drawn again, fitted, once its fit was made.")
	size.apply_to_human(wearer, MUSCLE_SIZE_ATHLETIC)
	wearer.update_body()
	TEST_ASSERT_EQUAL(drawn_worn_sprite(wearer, UNIFORM_LAYER)?.icon, sheet, "A size changed while the jumpsuit is worn didn't queue its new fit.")
	SSgarment_fitting.finish_all()
	var/refitted_icon = drawn_worn_sprite(wearer, UNIFORM_LAYER)?.icon
	TEST_ASSERT(refitted_icon != sheet && refitted_icon != fitted_icon, "The jumpsuit wasn't drawn again, fitted to the new size.")
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
/proc/drawn_worn_sprite(mob/living/carbon/human/wearer, layer)
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
/proc/drawn_appearances(appearances)
	. = list()
	for(var/mutable_appearance/drawn as anything in (islist(appearances) ? appearances : list(appearances)))
		if(!drawn)
			continue
		. += drawn
		. += drawn_appearances(drawn.underlays)
		. += drawn_appearances(drawn.overlays)
