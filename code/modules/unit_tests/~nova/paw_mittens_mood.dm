/// Every kind of paw mittens - the cat paws too - puts its wearer in the paw mood while worn as gloves, not while held;
/// taking them off ends it, and dropping another pair held in hand does not.
/datum/unit_test/paw_mittens_mood

/datum/unit_test/paw_mittens_mood/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/mob/living/carbon/human/consistent/wearer = allocate(__IMPLIED_TYPE__)
	var/obj/item/clothing/gloves/held = allocate(/obj/item/clothing/gloves/ball_mittens/paw_mittens)
	for(var/paws_type in typesof(/obj/item/clothing/gloves/ball_mittens/paw_mittens))
		var/obj/item/clothing/gloves/paws = allocate(paws_type)
		wearer.put_in_hands(paws)
		wearer.put_in_hands(held)
		TEST_ASSERT(!in_paw_mood(wearer), "Holding [paws] put the wearer in the paw mood.")
		wearer.equip_to_slot(paws, ITEM_SLOT_GLOVES)
		TEST_ASSERT(in_paw_mood(wearer), "Wearing [paws] did not put the wearer in the paw mood.")
		wearer.dropItemToGround(held, force = TRUE)
		TEST_ASSERT(in_paw_mood(wearer), "Dropping a held pair ended the paw mood from [paws].")
		wearer.dropItemToGround(paws, force = TRUE)
		TEST_ASSERT(!in_paw_mood(wearer), "Taking off [paws] left the wearer in the paw mood.")

/// Whether `wearer` is in the paw mood, whichever pair put them there.
/datum/unit_test/paw_mittens_mood/proc/in_paw_mood(mob/living/wearer)
	for(var/category in wearer.mob_mood.mood_events)
		if(istype(wearer.mob_mood.mood_events[category], /datum/mood_event/paw_mittens))
			return TRUE
	return FALSE
