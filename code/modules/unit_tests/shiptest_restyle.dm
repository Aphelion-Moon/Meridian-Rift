/// Restyling a Shiptest garment keeps what its wearer chose - an open coat, a raised hood that follows, a design's colours, saved loadout colours
/datum/unit_test/shiptest_restyle

/datum/unit_test/shiptest_restyle/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	// Colours with a hood and one garment of its own cut, designs with a hood, and colours on a coat that opens
	for(var/garment_type in list(/obj/item/clothing/suit/shiptest/hooded/survivor_suit/grey, /obj/item/clothing/suit/shiptest/hooded/winter_coat/brown, /obj/item/clothing/suit/shiptest/toggle/trenchcoat/tan))
		var/datum/loadout_item/loadout = GLOB.all_loadout_datums[garment_type]
		TEST_ASSERT(ispath(loadout?.reskin_datum, /datum/atom_skin/shiptest), "[garment_type] offers no wardrobe styles in the loadout")
		var/datum/atom_skin/shiptest/family = loadout.reskin_datum
		for(var/datum/atom_skin/shiptest/style as anything in valid_direct_subtypesof(family))
			check_in_round(garment_type, style, family::preserve_palette, wearer)
			check_loadout(loadout, style, wearer)

/// Colours for every channel of a palette that no style uses
/datum/unit_test/shiptest_restyle/proc/wearer_colors(palette)
	var/list/colors = list()
	for(var/channel in 1 to length(SSgreyscale.ParseColorString(palette)))
		colors += "#[channel]0[channel]0[channel]0"
	return colors.Join("")

/// Wears the garment opened, in the wearer's colours, picks the style, then closes and opens it again
/datum/unit_test/shiptest_restyle/proc/check_in_round(garment_type, datum/atom_skin/shiptest/style, design, mob/living/carbon/human/consistent/wearer)
	var/obj/item/clothing/suit/garment = allocate(garment_type, run_loc_floor_bottom_left)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(garment, ITEM_SLOT_OCLOTHING), "Could not wear [garment_type]")
	var/list/style_components = garment.GetComponents(/datum/component/reskinable_item)
	TEST_ASSERT_EQUAL(length(style_components), 1, "[garment_type] does not offer its styles")
	var/datum/component/reskinable_item/styles = style_components[1]
	var/datum/component/toggle_icon/buttons = garment.GetComponent(/datum/component/toggle_icon)
	var/datum/component/toggle_attached_clothing/hood = garment.GetComponent(/datum/component/toggle_attached_clothing)
	var/own_colors = wearer_colors(garment.greyscale_colors)
	garment.set_greyscale(own_colors)
	buttons?.do_icon_toggle(garment, wearer)
	hood?.toggle_deployable()
	var/obj/item/raised_hood = hood?.deployable
	styles.set_skin_by_name(style::preview_name, wearer)
	var/obj/item/look = style::greyscale_item_path
	TEST_ASSERT_EQUAL(garment.type, garment_type, "[style] replaced the garment")
	TEST_ASSERT_EQUAL(garment.icon_state, "[look::post_init_icon_state]_t", "[style] closed the open garment")
	var/expected_colors = design ? shiptest_palette_for_style(look, own_colors) : look::greyscale_colors
	TEST_ASSERT_EQUAL(garment.greyscale_colors, expected_colors, design ? "[style] lost the wearer's colours" : "[style] kept the wearer's colours over its own")
	if(hood)
		var/obj/item/clothing/suit/hooded/hooded_look = look
		var/obj/item/hood_look = hooded_look::hoodtype
		TEST_ASSERT(hood.deployable == raised_hood && wearer.head == raised_hood, "[style] took the raised hood off")
		TEST_ASSERT_EQUAL(raised_hood.greyscale_config, hood_look::greyscale_config, "The hood did not follow [style]")
		TEST_ASSERT_EQUAL(raised_hood.icon_state, hood_look::post_init_icon_state, "The hood did not take the state of [style]")
		TEST_ASSERT_EQUAL(raised_hood.greyscale_colors, shiptest_palette_for_style(hood_look, garment.greyscale_colors), "The hood did not take the colours of [style]")
		hood.toggle_deployable()
		TEST_ASSERT_EQUAL(garment.icon_state, look::post_init_icon_state, "Lowering the hood lost [style]")
		hood.toggle_deployable()
		TEST_ASSERT_EQUAL(garment.icon_state, "[look::post_init_icon_state]_t", "Raising the hood lost [style]")
		// A hood the garment makes again is the style's
		qdel(raised_hood)
		hood.toggle_deployable()
		TEST_ASSERT(istype(hood.deployable, hood_look), "A hood made again did not follow [style]")
		TEST_ASSERT_EQUAL(hood.deployable.greyscale_colors, shiptest_palette_for_style(hood_look, garment.greyscale_colors), "A hood made again lost the colours of [style]")
		hood.toggle_deployable()
	if(buttons)
		buttons.do_icon_toggle(garment, wearer)
		TEST_ASSERT_EQUAL(garment.icon_state, look::post_init_icon_state, "Closing the garment lost [style]")
	wearer.temporarilyRemoveItemFromInventory(garment, force = TRUE)
	qdel(garment)

/// Equips the loadout entry with the style, with and without saved colours
/datum/unit_test/shiptest_restyle/proc/check_loadout(datum/loadout_item/loadout, datum/atom_skin/shiptest/style, mob/living/carbon/human/consistent/wearer)
	var/obj/item/look = style::greyscale_item_path
	var/obj/item/garment = allocate(loadout.item_path, run_loc_floor_bottom_left)
	loadout.on_equip_item(garment, list(INFO_RESKIN = style::preview_name), wearer, null, visuals_only = TRUE)
	TEST_ASSERT_EQUAL(garment.icon_state, look::post_init_icon_state, "The loadout did not put on [style]")
	TEST_ASSERT_EQUAL(garment.greyscale_colors, look::greyscale_colors, "A new garment in [style] did not start from its own palette")
	var/saved_colors = wearer_colors(look::greyscale_colors)
	loadout.on_equip_item(garment, list(INFO_RESKIN = style::preview_name, INFO_GREYSCALE = saved_colors), wearer, null, visuals_only = TRUE)
	TEST_ASSERT_EQUAL(garment.greyscale_colors, saved_colors, "Saved loadout colours did not win over [style]")
	TEST_ASSERT_EQUAL(garment.icon_state, look::post_init_icon_state, "Saved loadout colours undid [style]")
	qdel(garment)
