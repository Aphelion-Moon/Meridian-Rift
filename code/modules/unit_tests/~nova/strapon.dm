/// Dropping a strapon whose hand item was never taken out must leave that missing item alone.
/datum/unit_test/strapon_dropped_without_hand_item/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/strapon/strapon = allocate(/obj/item/clothing/strapon)
	TEST_ASSERT(wearer.put_in_hands(strapon), "The fixture must hold the strapon.")
	TEST_ASSERT(wearer.dropItemToGround(strapon), "The strapon must drop.")
	TEST_ASSERT(isnull(strapon.strapon_item), "Dropping the strapon must not create its hand item.")
