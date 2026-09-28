/// A layer without art for some colour slots must skip them while the others keep their slot's colour and emissive pref.
/datum/unit_test/matrixed_accessory_sparse_layers/Run()
	var/obj/item/bodypart/head/lizard/head = allocate(__IMPLIED_TYPE__)
	var/obj/item/organ/horns/horns = allocate(__IMPLIED_TYPE__)
	var/datum/bodypart_overlay/mutant/overlay = horns.bodypart_overlay
	// Primary stalk on ADJ, secondary lamp on the emissive FRONT layer.
	overlay.set_appearance(/datum/sprite_accessory/horns/angler/polish)
	overlay.draw_color = list("#ff0000", "#00ff00", "#0000ff")
	overlay.emissive_eligibility_by_color_index = list(FALSE, TRUE, FALSE)
	overlay.blocks_emissive = EMISSIVE_BLOCK_NONE // Only real emissives reach the emissive plane.

	var/list/colors_by_state = list()
	var/list/lit_states = list()
	for(var/mutable_appearance/drawn as anything in overlay.get_all_overlays(head))
		TEST_ASSERT(icon_exists(drawn.icon, drawn.icon_state), "Drew missing state \"[drawn.icon_state]\".")
		if(drawn.plane == EMISSIVE_PLANE)
			lit_states += drawn.icon_state
		else
			colors_by_state[drawn.icon_state] = drawn.color

	TEST_ASSERT_EQUAL(colors_by_state["m_horns_angler_ADJ_primary"], "#ff0000", "The stalk is not the primary colour.")
	TEST_ASSERT_EQUAL(colors_by_state["m_horns_angler_FRONT_secondary"], "#00ff00", "The lamp is not the secondary colour.")
	TEST_ASSERT(("m_horns_angler_FRONT_secondary" in lit_states), "The lamp on the emissive FRONT layer does not glow.")
	TEST_ASSERT(!("m_horns_angler_ADJ_primary" in lit_states), "The stalk glows from the secondary colour's emissive pref.")
