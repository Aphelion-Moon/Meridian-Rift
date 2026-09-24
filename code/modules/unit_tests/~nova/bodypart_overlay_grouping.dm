/// Plain bodypart sprites share a holder and masks share an emissive group per layer, while anything else keeps its draw-order place.
/datum/unit_test/bodypart_overlay_grouping

/datum/unit_test/bodypart_overlay_grouping/Run()
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent)
	var/limb_layer = -BODYPARTS_LAYER
	var/mutable_appearance/chest = mutable_appearance('icons/mob/human/bodyparts.dmi', "human_chest_m", limb_layer)
	var/mutable_appearance/chest_block = emissive_blocker(chest.icon, chest.icon_state, dummy, layer = limb_layer)
	var/mutable_appearance/head = mutable_appearance('icons/mob/human/bodyparts.dmi', "human_head_m", limb_layer)
	var/mutable_appearance/head_block = emissive_blocker(head.icon, head.icon_state, dummy, layer = limb_layer)
	var/mutable_appearance/inset = mutable_appearance('icons/mob/human/bodyparts.dmi', "human_l_arm", limb_layer)
	inset.blend_mode = BLEND_INSET_OVERLAY
	var/mutable_appearance/arm = mutable_appearance('icons/mob/human/bodyparts.dmi', "human_r_arm", limb_layer)
	var/mutable_appearance/front = mutable_appearance('icons/mob/human/bodyparts.dmi', "human_l_leg", -BODY_FRONT_LAYER)

	var/list/prepared = prepare_bodypart_overlays(list(chest, chest_block, head, head_block, inset, arm, front))
	TEST_ASSERT_EQUAL(length(prepared), 5, "Expected a sprite holder, a mask group, the inset sprite, the sprite after it and the other layer's sprite")

	var/mutable_appearance/holder = prepared[1]
	TEST_ASSERT(isnull(holder.icon) && holder.plane == FLOAT_PLANE && holder.layer == limb_layer, "The first entry should be an iconless floating holder at the limb layer")
	TEST_ASSERT_EQUAL(length(holder.overlays), 2, "The chest and head sprites should share one holder")

	var/mutable_appearance/group = prepared[2]
	TEST_ASSERT(isnull(group.icon) && PLANE_TO_TRUE(group.plane) == EMISSIVE_PLANE && group.layer == limb_layer, "The second entry should be an iconless emissive group at the limb layer")
	TEST_ASSERT_EQUAL(length(group.overlays), 2, "The chest and head blockers should share one emissive group")

	TEST_ASSERT_EQUAL(prepared[3], inset, "The inset sprite should keep its own root")
	TEST_ASSERT_EQUAL(prepared[4], arm, "A single sprite after the inset one should stay unwrapped, behind it in draw order")
	TEST_ASSERT_EQUAL(prepared[5], front, "A single sprite on another layer should stay unwrapped")

	var/list/prepared_again = prepare_bodypart_overlays(prepared)
	TEST_ASSERT_EQUAL(length(prepared_again), length(prepared), "Preparing twice should not change the entry count")
	for(var/index in 1 to length(prepared))
		TEST_ASSERT_EQUAL(prepared_again[index], prepared[index], "Preparing twice should not wrap entry [index] again")
