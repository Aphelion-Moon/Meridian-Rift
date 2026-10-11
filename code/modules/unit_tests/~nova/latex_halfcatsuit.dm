/// The latex half-catsuit takes the sprite of its wearer's body type, whatever their gender, and redraws itself, on a
/// player and on a preview dummy (which only gets visual_equipped()); every sheet it draws from has both sprites.
/datum/unit_test/latex_halfcatsuit

/datum/unit_test/latex_halfcatsuit/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/obj/item/clothing/under/misc/latex_halfcatsuit/suit = allocate(__IMPLIED_TYPE__)
	for(var/state in list("latex_halfcatsuit_female", "latex_halfcatsuit_male"))
		for(var/sheet in list(suit.icon, suit.worn_icon, suit.worn_icon_digi, suit.worn_icon_vox, suit.worn_icon_better_vox,
			suit.worn_icon_teshari))
			TEST_ASSERT(icon_exists(sheet, state), "[sheet] has no [state]")
	for(var/wearer_type in list(/mob/living/carbon/human/consistent, /mob/living/carbon/human/dummy/consistent))
		for(var/body in list(MALE, FEMALE)) // the suit starts female and ends each wearer female, so every turn swaps it
			var/mob/living/carbon/human/wearer = allocate(wearer_type)
			wearer.gender = PLURAL
			wearer.physique = body
			TEST_ASSERT(wearer.equip_to_slot_if_possible(suit, ITEM_SLOT_ICLOTHING), "[wearer_type] could not wear it")
			var/state = "latex_halfcatsuit_[body]"
			TEST_ASSERT_EQUAL(suit.icon_state, state, "the half-catsuit's sprite on a [body]-bodied [wearer_type]")
			if(body == MALE) // the female mask draws a new icon, with no state
				TEST_ASSERT((state in drawn_states(wearer)), "[wearer_type] still draws the old sprite after the swap")
			wearer.temporarilyRemoveItemFromInventory(suit, force = TRUE)

/// The icon states drawn in `wearer`'s uniform slot, whose cache entry is an appearance or a list of them (split from
/// its emissive blocker, or with the Vox hand covers).
/datum/unit_test/latex_halfcatsuit/proc/drawn_states(mob/living/carbon/human/wearer)
	var/drawn = wearer.overlays_standing[UNIFORM_LAYER]
	. = list()
	for(var/mutable_appearance/entry as anything in (islist(drawn) ? drawn : list(drawn)))
		. += entry?.icon_state

/// A Vox wears the fitted Vox half, with the latex hand covers and without the female mask its body would take, and
/// both Vox sheets have the covers of both sprites.
/datum/unit_test/latex_halfcatsuit/vox

/datum/unit_test/latex_halfcatsuit/vox/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/obj/item/clothing/under/misc/latex_halfcatsuit/suit = allocate(__IMPLIED_TYPE__)
	for(var/sheet in list(suit.worn_icon_vox, suit.worn_icon_better_vox))
		for(var/state in list("latex_halfcatsuit_female_hands", "latex_halfcatsuit_male_hands"))
			TEST_ASSERT(icon_exists(sheet, state), "[sheet] has no [state]")
	var/mob/living/carbon/human/consistent/vox = allocate(__IMPLIED_TYPE__)
	vox.set_species(/datum/species/vox)
	vox.gender = FEMALE
	vox.physique = FEMALE
	TEST_ASSERT(vox.equip_to_slot_if_possible(suit, ITEM_SLOT_ICLOTHING), "a Vox could not wear it")
	var/list/states = drawn_states(vox)
	TEST_ASSERT(("latex_halfcatsuit_female_hands" in states), "a Vox wears the half-catsuit without its hand covers")
	TEST_ASSERT(("latex_halfcatsuit_female" in states), "a female mask cut the Vox half-catsuit's sprite")
