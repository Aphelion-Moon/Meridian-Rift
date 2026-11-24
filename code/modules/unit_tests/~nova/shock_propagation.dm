/// A SHOCK_NOGLOVES shock on a carbon jumps to whoever pulls it, but without the flag, so the helper's insulated
/// gloves still stop it. The shocked carbon still ignores its own gloves. A helper without gloves still gets shocked.
/datum/unit_test/shock_propagation_gloves

/datum/unit_test/shock_propagation_gloves/Run()
	var/mob/living/carbon/human/consistent/shocked = allocate(/mob/living/carbon/human/consistent)
	shocked.equip_to_slot(allocate(/obj/item/clothing/gloves/color/yellow), ITEM_SLOT_GLOVES)
	var/mob/living/carbon/human/consistent/gloved_helper = allocate(/mob/living/carbon/human/consistent)
	gloved_helper.equip_to_slot(allocate(/obj/item/clothing/gloves/color/yellow), ITEM_SLOT_GLOVES)
	var/mob/living/carbon/human/consistent/plain_helper = allocate(/mob/living/carbon/human/consistent)

	gloved_helper.start_pulling(shocked)
	TEST_ASSERT_EQUAL(shocked.pulledby, gloved_helper, "The gloved helper didn't start pulling, so the shock has no one to jump to.")
	shocked.electrocute_act(20, src, flags = SHOCK_NOGLOVES)
	TEST_ASSERT(shocked.get_fire_loss() > 0, "A SHOCK_NOGLOVES shock was stopped by the shocked carbon's own gloves.")
	TEST_ASSERT_EQUAL(gloved_helper.get_fire_loss(), 0, "A SHOCK_NOGLOVES shock jumped to a helper through their insulated gloves.")

	gloved_helper.stop_pulling()
	plain_helper.start_pulling(shocked)
	TEST_ASSERT_EQUAL(shocked.pulledby, plain_helper, "The plain helper didn't start pulling, so the shock has no one to jump to.")
	shocked.electrocute_act(20, src, flags = SHOCK_NOGLOVES)
	TEST_ASSERT(plain_helper.get_fire_loss() > 0, "A SHOCK_NOGLOVES shock didn't jump to a helper without gloves.")

/// System Shock reboots a synth on a shock that gets through, but not on one their insulated gloves stop.
/datum/unit_test/system_shock_gloves

/datum/unit_test/system_shock_gloves/Run()
	var/mob/living/carbon/human/species/synth/shocked_synth = allocate(/mob/living/carbon/human/species/synth)
	var/obj/item/clothing/gloves/insulated_gloves = allocate(/obj/item/clothing/gloves/color/yellow)
	shocked_synth.equip_to_slot(insulated_gloves, ITEM_SLOT_GLOVES)
	shocked_synth.add_quirk(/datum/quirk/system_shock)

	shocked_synth.electrocute_act(20, src)
	TEST_ASSERT(!shocked_synth.has_status_effect(/datum/status_effect/static_vision), "System Shock rebooted a synth on a shock their insulated gloves stopped.")

	shocked_synth.dropItemToGround(insulated_gloves, force = TRUE)
	shocked_synth.electrocute_act(20, src)
	TEST_ASSERT(shocked_synth.has_status_effect(/datum/status_effect/static_vision), "System Shock didn't reboot a synth on a shock that got through.")
