/**
 * The bulge renderer (bulge.dm, look.dm, cut_cover.dm, redraw.dm) through the game's own paths: arousal from soft and
 * back on every kind of cover, cover changes, recolours and dye, legs, length and height, anatomy and testicles behind a
 * cover, the refusals, two wearers of one garment, and deletion.
 */
/datum/unit_test/portal_test/bulge_renderer
	abstract_type = /datum/unit_test/portal_test/bulge_renderer

/datum/unit_test/portal_test/bulge_renderer/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Bulges need genitals, which the ERP config disables.")
		return
	check()

/// The test proper, once the config allows genitals.
/datum/unit_test/portal_test/bulge_renderer/proc/check()
	return

/// A consistent human with the test penis (with a sheath, if named), on digitigrade legs when asked; null on failure.
/datum/unit_test/portal_test/bulge_renderer/proc/make_wearer(digitigrade = FALSE, sheath = SPRITE_ACCESSORY_NONE)
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent)
	if(digitigrade && !set_legs(owner, DIGITIGRADE_LEGS))
		return null
	owner.socks = "Nude"
	return configure_test_penis(owner, sheath) ? owner : null

/// Swaps a wearer's legs the way the legs preference does.
/datum/unit_test/portal_test/bulge_renderer/proc/set_legs(mob/living/carbon/human/owner, legs)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/preference/choiced/digitigrade_legs/preference = GLOB.preference_entries[/datum/preference/choiced/digitigrade_legs]
	return preference.apply_to_human(owner, legs, preferences)

/// The wearer's penis overlay, which draws the bulge.
/datum/unit_test/portal_test/bulge_renderer/proc/look(mob/living/carbon/human/owner)
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	return penis?.bodypart_overlay

/// The chest's drawn images at the look's layer just above its cover ("front") or just below it ("behind"), or null.
/datum/unit_test/portal_test/bulge_renderer/proc/look_images(mob/living/carbon/human/owner, where = "front")
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = look(owner)
	if(!overlay?.bulge_key)
		return null
	var/wanted = where == "behind" ? -(overlay.bulge_layer + BULGE_BEHIND_COVER) : -(overlay.bulge_layer - BULGE_ABOVE_COVER)
	for(var/image/part as anything in owner.drawn_limb_icons(BODY_ZONE_CHEST))
		if(part.plane == FLOAT_PLANE && part.layer == wanted)
			LAZYADD(., part)

/// The drawn sprite of a worn slot, as the look reads it.
/datum/unit_test/portal_test/bulge_renderer/proc/drawn_leaf(mob/living/carbon/human/owner, slot)
	RETURN_TYPE(/image)
	return bulge_drawn_leaf(bulge_drawn_root(owner.overlays_standing[slot]))

/// Arousal from soft and back, through the arousal menu's writer, on a uniform, underwear, a suit that is itself the
/// cover, a suit the bulge shows through, and a revealing skirt, which is cut when hard.
/datum/unit_test/portal_test/bulge_renderer/activation

/datum/unit_test/portal_test/bulge_renderer/activation/check()
	activate("uniform", /obj/item/clothing/under/color/grey, null, null, UNIFORM_LAYER)
	activate("underwear", null, "Boxers", null, UNDER_UNIFORM_LAYER)
	activate("covering suit", /obj/item/clothing/under/color/grey, null, /obj/item/clothing/suit/apron/overalls, SUIT_LAYER)
	activate("open suit", /obj/item/clothing/under/color/grey, null, /obj/item/clothing/suit/armor/hos/trenchcoat, UNIFORM_LAYER)
	activate("revealing skirt", /obj/item/clothing/under/dress/skirt/plaid, null, null, UNIFORM_LAYER)

/datum/unit_test/portal_test/bulge_renderer/activation/proc/activate(name, uniform_type, underwear_name, suit_type, cover_layer)
	var/mob/living/carbon/human/owner = make_wearer()
	TEST_ASSERT_NOTNULL(owner, "[name]: no wearer")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	penis.set_size(12)
	if(uniform_type)
		var/obj/item/clothing/under/uniform = allocate(uniform_type)
		TEST_ASSERT(owner.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "[name]: could not wear the uniform")
	if(underwear_name)
		owner.underwear = underwear_name
		owner.update_body()
	if(suit_type)
		var/obj/item/clothing/suit = allocate(suit_type)
		TEST_ASSERT(owner.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "[name]: could not wear the suit")
	TEST_ASSERT_NULL(overlay.bulge_key, "[name]: a soft penis drew a bulge")
	TEST_ASSERT(penis.apply_arousal_label("Partly aroused"), "[name]: the half-hard writer was unavailable")
	TEST_ASSERT(overlay.bulge_key, "[name]: half hard drew no bulge")
	TEST_ASSERT_EQUAL(overlay.bulge_layer, cover_layer, "[name]: the bulge drew over the wrong cover")
	TEST_ASSERT(length(look_images(owner)), "[name]: the chest drew none of the look")
	var/half_key = overlay.bulge_key
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "[name]: the hard writer was unavailable")
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_key != half_key, "[name]: going hard kept the half-hard look")
	var/skirt = name == "revealing skirt"
	if(skirt)
		TEST_ASSERT(overlay.bulge_patch, "[name]: the skirt's print was not carried")
		TEST_ASSERT(overlay.bulge_uniform_cut, "[name]: the hard skirt was not cut")
		TEST_ASSERT(overlay.bulge_anatomy_behind, "[name]: the penis is not drawn behind the cut skirt")
		TEST_ASSERT_EQUAL(drawn_leaf(owner, UNIFORM_LAYER)?.icon, overlay.bulge_cut_icon, "[name]: the skirt is drawn uncut")
		TEST_ASSERT(length(look_images(owner, "behind")), "[name]: the chest drew no penis behind the skirt")
	TEST_ASSERT(penis.apply_arousal_label("Partly aroused"), "[name]: the half-hard writer was unavailable")
	TEST_ASSERT_EQUAL(overlay.bulge_key, half_key, "[name]: half hard again drew another look")
	if(skirt)
		TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "[name]: the skirt stayed cut when half hard")
		TEST_ASSERT(isfile(drawn_leaf(owner, UNIFORM_LAYER)?.icon) && drawn_leaf(owner, UNIFORM_LAYER)?.icon != overlay.bulge_cut_icon, "[name]: the skirt was not drawn whole again")
	TEST_ASSERT(penis.apply_arousal_label("Not aroused"), "[name]: the soft writer was unavailable")
	TEST_ASSERT_NULL(overlay.bulge_key, "[name]: the bulge outlived the arousal")
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "[name]: a cut outlived the arousal")
	TEST_ASSERT_NULL(look_images(owner), "[name]: the chest still draws a bulge")

/// Putting a cover on, taking it off, swapping it, a suit that hides the bulge, and underwear under nothing else.
/datum/unit_test/portal_test/bulge_renderer/cover_changes

/datum/unit_test/portal_test/bulge_renderer/cover_changes/check()
	var/mob/living/carbon/human/owner = make_wearer()
	TEST_ASSERT_NOTNULL(owner, "No wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	penis.set_size(12)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT_NULL(overlay.bulge_key, "A penis in the open drew a bulge.")
	var/obj/item/clothing/under/color/grey/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(owner.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Could not put the jumpsuit on.")
	var/datum/bulge_print_template/shape = bulge_shape(/datum/bulge_family/jumpsuits, TRUE, 4, FALSE, /datum/sprite_accessory/genital/penis/human, penis.uses_skintones)
	TEST_ASSERT_EQUAL(overlay.bulge_template, shape, "Putting a jumpsuit on drew the wrong shape.")
	var/old_key = overlay.bulge_key
	owner.dropItemToGround(jumpsuit)
	TEST_ASSERT_NULL(overlay.bulge_key, "Taking the jumpsuit off left its bulge drawn.")
	var/obj/item/clothing/under/pants/jeans/pants = allocate(/obj/item/clothing/under/pants/jeans)
	TEST_ASSERT(owner.equip_to_slot_if_possible(pants, ITEM_SLOT_ICLOTHING), "Could not put the jeans on.")
	TEST_ASSERT_EQUAL(overlay.bulge_template, bulge_shape(/datum/bulge_family/jeans, TRUE, 4, FALSE, /datum/sprite_accessory/genital/penis/human, penis.uses_skintones), "Swapping to jeans drew the wrong shape.")
	TEST_ASSERT(overlay.bulge_key != old_key, "Swapping to jeans kept the jumpsuit's look.")
	var/obj/item/clothing/suit/apron/suit = allocate(/obj/item/clothing/suit/apron)
	TEST_ASSERT(owner.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Could not put the apron on.")
	TEST_ASSERT_NULL(overlay.bulge_key, "An apron that hides the bulge left it drawn.")
	owner.dropItemToGround(suit)
	TEST_ASSERT(overlay.bulge_key, "Taking the apron off did not draw the jeans' bulge again.")
	owner.dropItemToGround(pants)
	owner.underwear = "Boxers"
	owner.update_body()
	TEST_ASSERT_EQUAL(overlay.bulge_layer, UNDER_UNIFORM_LAYER, "Underwear under nothing else did not draw the bulge.")
	TEST_ASSERT_EQUAL(overlay.bulge_template, bulge_shape(/datum/bulge_family/boxers, TRUE, 4, FALSE, /datum/sprite_accessory/genital/penis/human, penis.uses_skintones), "Boxers drew the wrong shape.")
	owner.underwear = "Nude"
	owner.update_body()
	TEST_ASSERT_NULL(overlay.bulge_key, "Taking the underwear off left its bulge drawn.")

/// Underwear under an outer cover holds the penis in, unless it lets it out itself: a hard skirt over
/// briefs still tents but shows none of the penis and is drawn whole, a chastity sprite leaves no bulge at all, and a
/// jockstrap under the leotard keeps its bulge to the jockstrap's size. Each is swapped under a cover left as it is, which
/// the look follows.
/datum/unit_test/portal_test/bulge_renderer/underwear_restrains

/datum/unit_test/portal_test/bulge_renderer/underwear_restrains/check()
	var/mob/living/carbon/human/owner = make_wearer()
	TEST_ASSERT_NOTNULL(owner, "No wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	penis.set_size(12)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	var/obj/item/clothing/under/dress/skirt/plaid/skirt = allocate(/obj/item/clothing/under/dress/skirt/plaid)
	TEST_ASSERT(owner.equip_to_slot_if_possible(skirt, ITEM_SLOT_ICLOTHING), "Could not put the skirt on.")
	var/cut_skirt = drawn_leaf(owner, UNIFORM_LAYER)?.icon
	TEST_ASSERT(overlay.bulge_anatomy_behind && cut_skirt && cut_skirt == overlay.bulge_cut_icon, "A hard revealing skirt over nothing is not drawn cut to show the penis: the test needs one that is.")

	owner.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	owner.update_body()
	TEST_ASSERT(owner.has_bulge(), "A hard skirt over briefs no longer tents.")
	TEST_ASSERT(!overlay.bulge_anatomy_mask && !overlay.bulge_anatomy_behind, "The penis was drawn through a skirt over briefs.")
	TEST_ASSERT(isnull(overlay.bulge_uniform_cut) && drawn_leaf(owner, UNIFORM_LAYER)?.icon != cut_skirt, "A skirt over briefs is still drawn cut.")
	TEST_ASSERT_EQUAL(owner.bulge_pokes_out(), NONE, "The penis poked out of a skirt over briefs.")
	owner.underwear = "Nude"
	owner.update_body()
	TEST_ASSERT(overlay.bulge_anatomy_behind && drawn_leaf(owner, UNIFORM_LAYER)?.icon == cut_skirt, "The skirt was not cut again once the briefs came off under it.")

	owner.underwear = /datum/sprite_accessory/clothing/underwear/chastcage::name
	owner.update_body()
	TEST_ASSERT(!owner.has_bulge(), "A chastity cage under a skirt left a bulge.")
	TEST_ASSERT(isnull(overlay.bulge_uniform_cut) && drawn_leaf(owner, UNIFORM_LAYER)?.icon != cut_skirt, "A skirt over a chastity cage was drawn cut.")
	owner.dropItemToGround(skirt)

	// The leotard over nothing shows the head at size 6; a jockstrap under it holds the bulge to the jockstrap's size.
	var/datum/bulge_family/leotard = /datum/sprite_accessory/clothing/undershirt/nova/leotard::bulge_family
	var/datum/bulge_family/jockstrap = /datum/sprite_accessory/clothing/underwear/male_kinky::bulge_family
	owner.underwear = "Nude"
	owner.undershirt = /datum/sprite_accessory/clothing/undershirt/nova/leotard::name
	penis.set_size(49)
	owner.update_body()
	TEST_ASSERT(overlay.bulge_anatomy_mask, "The leotard over nothing shows no head at size 6: the test needs one that does.")
	owner.underwear = /datum/sprite_accessory/clothing/underwear/male_kinky::name
	owner.update_body()
	TEST_ASSERT_EQUAL(overlay.bulge_template, bulge_shape(leotard, TRUE, initial(jockstrap.hard_cap), FALSE, overlay.sprite_datum.type, penis.uses_skintones), "A jockstrap under the leotard did not hold its bulge to the jockstrap's size.")
	TEST_ASSERT_NULL(overlay.bulge_anatomy_mask, "The head showed over a leotard worn over a jockstrap.")
	owner.underwear = "Nude"
	owner.update_body()
	TEST_ASSERT(overlay.bulge_anatomy_mask, "The head did not show again once the jockstrap came off under the leotard.")

/// A GAGS recolour of an adaptive garment (a new palette, no new icon) and of a printed one (the print follows), a
/// dyed garment, and an admin's refresh of the garment's GAGS config from disk.
/datum/unit_test/portal_test/bulge_renderer/recolours

/datum/unit_test/portal_test/bulge_renderer/recolours/check()
	var/mob/living/carbon/human/owner = make_wearer()
	TEST_ASSERT_NOTNULL(owner, "No wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	penis.set_size(12)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	var/obj/item/clothing/under/color/grey/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(owner.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Could not put the jumpsuit on.")
	var/grey_cloth = overlay.bulge_cloth
	var/datum/bulge_print_template/shape = overlay.bulge_template
	var/masks = shape?.mask_union
	var/list/counts = derived_counts()
	jumpsuit.set_greyscale("#2255aa")
	TEST_ASSERT(overlay.bulge_cloth && overlay.bulge_cloth != grey_cloth, "Recolouring the jumpsuit left the bulge grey.")
	TEST_ASSERT_EQUAL(overlay.bulge_template, shape, "Recolouring the jumpsuit changed its shape.")
	TEST_ASSERT_EQUAL(shape?.mask_union, masks, "Recolouring the jumpsuit made new masks.")
	TEST_ASSERT_EQUAL(json_encode(derived_counts()), json_encode(counts), "Recolouring an adaptive garment derived an icon.")
	owner.dropItemToGround(jumpsuit)

	var/obj/item/clothing/under/camo/gags/camo = allocate(/obj/item/clothing/under/camo/gags)
	TEST_ASSERT(owner.equip_to_slot_if_possible(camo, ITEM_SLOT_ICLOTHING), "Could not put the camouflage on.")
	var/patch = overlay.bulge_patch
	TEST_ASSERT(patch, "The printed camouflage drew no print.")
	var/count = length(GLOB.bulge_print_patches)
	camo.set_greyscale("#aa3311#44aa22#2233cc")
	TEST_ASSERT(overlay.bulge_patch && overlay.bulge_patch != patch, "The print did not follow the camouflage's new colours.")
	TEST_ASSERT_EQUAL(length(GLOB.bulge_print_patches), count + 1, "A recoloured print derived other than one patch.")
	owner.dropItemToGround(camo)

	var/obj/item/clothing/under/color/grey/dyed = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(dyed.dye_item("red"), "The jumpsuit could not be dyed.")
	TEST_ASSERT(owner.equip_to_slot_if_possible(dyed, ITEM_SLOT_ICLOTHING), "Could not put the dyed jumpsuit on.")
	TEST_ASSERT(overlay.bulge_cloth && overlay.bulge_cloth != grey_cloth, "A dyed jumpsuit drew its bulge in the old colour.")

	// An admin's refresh of the GAGS configs from disk (RefreshConfigsFromFile()) while the files on disk are the ones
	// compiled in: the jumpsuit is still sampled, so its bulge keeps a cloth through a recolour. A config
	// whose files changed on disk (here its json's hash) is not: the garment's iconforge outputs were made from the
	// compiled files. The config is put back as initialisation left it before anything is asserted.
	var/datum/greyscale_config/config = SSgreyscale.configurations["[dyed.greyscale_config_worn]"]
	TEST_ASSERT(config && isnull(config.json_config_hash) && isnull(config.icon_file_hash), "The jumpsuit's worn config is missing, or was refreshed from disk before the test.")
	var/before = overlay.bulge_cloth
	config.Refresh(TRUE)
	var/list/hashes = list(config.json_config_hash, md5(initial(config.json_config)))
	dyed.set_greyscale("#2255aa")
	var/recovered = overlay.bulge_cloth
	config.json_config_hash = "changed on disk"
	dyed.set_greyscale("#aa3311")
	var/changed = overlay.bulge_cloth
	config.json_config_hash = null
	config.icon_file_hash = null
	config.json_config = initial(config.json_config)
	config.icon_file = initial(config.icon_file)
	config.Refresh()
	dyed.set_greyscale("#2255aa")
	TEST_ASSERT(hashes[1] == hashes[2], "Refreshed from an unchanged json, the config's hash ([hashes[1]]) is not its compiled json's ([hashes[2]]).")
	TEST_ASSERT(recovered && recovered != before, "After a refresh from unchanged files, the recoloured jumpsuit's bulge has no cloth in its new colour.")
	TEST_ASSERT_NULL(changed, "A jumpsuit whose config changed on disk is still sampled for its bulge.")
	TEST_ASSERT(overlay.bulge_cloth, "With the config as initialisation left it, the jumpsuit's bulge has no cloth.")

/// The derived icon caches' sizes.
/datum/unit_test/portal_test/bulge_renderer/recolours/proc/derived_counts()
	return list(length(GLOB.bulge_print_patches), length(GLOB.bulge_cut_covers), length(GLOB.bulge_masked_icons), length(GLOB.bulge_mask_tiles))

/// Legs swapped to digitigrade and back, a length change, height, a body update that changes nothing, a look that draws
/// anatomy keyed by the penis's own key as it was when the look was resolved, and a dyed penis.
/datum/unit_test/portal_test/bulge_renderer/body_changes

/datum/unit_test/portal_test/bulge_renderer/body_changes/check()
	var/mob/living/carbon/human/owner = make_wearer()
	TEST_ASSERT_NOTNULL(owner, "No wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	var/obj/item/clothing/under/color/grey/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(owner.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Could not put the jumpsuit on.")
	penis.set_size(4)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	var/human = /datum/sprite_accessory/genital/penis/human
	TEST_ASSERT_EQUAL(overlay.bulge_template, bulge_shape(/datum/bulge_family/jumpsuits, TRUE, 1, FALSE, human, penis.uses_skintones), "A short penis drew the wrong size.")

	// A body update that changes nothing keeps the look and the chest's cached images.
	var/chest_key = owner.icon_render_keys[BODY_ZONE_CHEST]
	var/list/chest_images = owner.drawn_limb_icons(BODY_ZONE_CHEST)
	owner.update_body_parts()
	TEST_ASSERT_EQUAL(owner.icon_render_keys[BODY_ZONE_CHEST], chest_key, "An idle body update changed the chest's key.")
	TEST_ASSERT_EQUAL(owner.drawn_limb_icons(BODY_ZONE_CHEST), chest_images, "An idle body update rebuilt the chest.")

	// The length alone, under the sprite's thresholds, still changes the bulge size.
	penis.set_size(12)
	TEST_ASSERT_EQUAL(overlay.bulge_template, bulge_shape(/datum/bulge_family/jumpsuits, TRUE, 4, FALSE, human, penis.uses_skintones), "A longer penis kept its old bulge.")
	TEST_ASSERT_EQUAL(overlay.bulge_length, 12, "The look was not resolved for the new length.")

	TEST_ASSERT(set_legs(owner, DIGITIGRADE_LEGS), "Could not give the wearer digitigrade legs.")
	TEST_ASSERT_EQUAL(overlay.bulge_template, bulge_shape(/datum/bulge_family/jumpsuits, TRUE, 4, TRUE, human, penis.uses_skintones), "Digitigrade legs kept the plain shape.")
	TEST_ASSERT(set_legs(owner, NORMAL_LEGS), "Could not give the wearer plain legs back.")
	TEST_ASSERT_EQUAL(overlay.bulge_template, bulge_shape(/datum/bulge_family/jumpsuits, TRUE, 4, FALSE, human, penis.uses_skintones), "Plain legs again kept the digitigrade shape.")

	// The cover is drawn at the wearer's height; so is its bulge.
	owner.set_mob_height(HUMAN_HEIGHT_TALL)
	var/list/cover_filters = filter_names(bulge_drawn_root(owner.overlays_standing[UNIFORM_LAYER]))
	TEST_ASSERT(length(cover_filters), "A tall wearer's jumpsuit has no height filter.")
	for(var/image/part as anything in look_images(owner))
		TEST_ASSERT_EQUAL(json_encode(filter_names(part)), json_encode(cover_filters), "A tall wearer's bulge is not drawn at the jumpsuit's height.")

	// A look that draws anatomy (hard jeans at size 6: the exposed tip) carries a hash of the penis's own key taken when
	// it was resolved: a body update that changes nothing keeps the chest's key and images; the penis's colours changed,
	// even in place, draw the chest again; back as they were, the chest's key comes back.
	owner.dropItemToGround(jumpsuit)
	// A dyed penis (set_dye_color(), the dye spray) is drawn in the dye, in the open as by a look's exposed tip below;
	// undyed, the chest's key comes back.
	chest_key = owner.icon_render_keys[BODY_ZONE_CHEST]
	overlay.set_dye_color("#123456", penis)
	TEST_ASSERT(owner.icon_render_keys[BODY_ZONE_CHEST] != chest_key, "A dyed penis in the open kept the chest's drawing.")
	var/dyed = 0
	for(var/image/part as anything in owner.drawn_limb_icons(BODY_ZONE_CHEST))
		if(part.plane == FLOAT_PLANE && part.icon == overlay.sprite_datum.icon && part.color == "#123456")
			dyed++
	TEST_ASSERT(dyed, "The penis in the open is not drawn in the dye.")
	overlay.set_dye_color(null, penis)
	TEST_ASSERT_EQUAL(owner.icon_render_keys[BODY_ZONE_CHEST], chest_key, "Undyed in the open, the chest's key did not come back.")
	var/obj/item/clothing/under/pants/jeans/pants = allocate(/obj/item/clothing/under/pants/jeans)
	TEST_ASSERT(owner.equip_to_slot_if_possible(pants, ITEM_SLOT_ICLOTHING), "Could not put the jeans on.")
	penis.set_size(49)
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_anatomy_mask, "Hard jeans at size 6 drew no exposed tip.")
	chest_key = owner.icon_render_keys[BODY_ZONE_CHEST]
	chest_images = owner.drawn_limb_icons(BODY_ZONE_CHEST)
	owner.update_body_parts()
	TEST_ASSERT_EQUAL(owner.icon_render_keys[BODY_ZONE_CHEST], chest_key, "An idle body update changed the chest's key under the jeans.")
	TEST_ASSERT_EQUAL(owner.drawn_limb_icons(BODY_ZONE_CHEST), chest_images, "An idle body update rebuilt the chest under the jeans.")
	var/list/colours = overlay.draw_color
	TEST_ASSERT(islist(colours), "The test penis has no colour list.")
	var/first = colours[1]
	colours[1] = "#00ff00"
	owner.update_body_parts()
	TEST_ASSERT(owner.icon_render_keys[BODY_ZONE_CHEST] != chest_key, "A penis recoloured in place kept the chest's drawing.")
	colours[1] = first
	owner.update_body_parts()
	TEST_ASSERT_EQUAL(owner.icon_render_keys[BODY_ZONE_CHEST], chest_key, "The penis's own colours back did not give the chest's key back.")
	overlay.set_dye_color("#123456", penis)
	TEST_ASSERT(owner.icon_render_keys[BODY_ZONE_CHEST] != chest_key, "A dyed penis kept the bulge look's drawing of its tip.")
	dyed = 0
	for(var/image/part as anything in look_images(owner))
		if(part.name != BULGE_CLOTH_NAME && part.color == "#123456")
			dyed++
	TEST_ASSERT(dyed, "The penis's tip over the jeans is not drawn in the dye.")
	overlay.set_dye_color(null, penis)
	TEST_ASSERT_EQUAL(owner.icon_render_keys[BODY_ZONE_CHEST], chest_key, "Undyed under the jeans, the chest's key did not come back.")

/// The names of an appearance's filters, in order.
/datum/unit_test/portal_test/bulge_renderer/body_changes/proc/filter_names(image/drawn)
	. = list()
	for(var/filter in drawn?.filters)
		. += "[filter:name]"

/// A hard loincloth shows the penis, and the testicles, behind its cut; each way of taking them away is followed.
/datum/unit_test/portal_test/bulge_renderer/anatomy

/datum/unit_test/portal_test/bulge_renderer/anatomy/check()
	var/mob/living/carbon/human/owner = make_wearer()
	TEST_ASSERT_NOTNULL(owner, "No wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	owner.dna.features["balls_size"] = 3
	owner.dna.features["testicles_uses_skincolor"] = FALSE
	owner.dna.features["testicles_uses_skintones"] = FALSE
	owner.dna.mutant_bodyparts[ORGAN_SLOT_TESTICLES] = build_mutant_part("Pair", list("#FCCCB3"))
	var/obj/item/organ/genital/testicles/testicles = allocate(/obj/item/organ/genital/testicles, owner.loc)
	testicles.build_from_dna(owner.dna, ORGAN_SLOT_TESTICLES)
	var/datum/bodypart_overlay/mutant/genital/testicles_overlay = testicles.bodypart_overlay
	TEST_ASSERT(testicles_overlay.set_appearance_from_dna(owner.dna), "The testicles take no shape.")
	TEST_ASSERT(testicles.Insert(owner, special = TRUE), "The testicles could not be put in.")
	TEST_ASSERT(testicles.apply_visibility_label("Hidden by clothes"), "The testicles' visibility writer was unavailable.")
	var/obj/item/clothing/under/costume/loincloth/loincloth = allocate(/obj/item/clothing/under/costume/loincloth)
	TEST_ASSERT(owner.equip_to_slot_if_possible(loincloth, ITEM_SLOT_ICLOTHING), "Could not put the loincloth on.")
	penis.set_size(12)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_anatomy_behind, "A hard loincloth showed nothing behind its cut.")
	TEST_ASSERT(overlay.bulge_uniform_cut, "A hard loincloth was not cut.")
	TEST_ASSERT_EQUAL(drawn_leaf(owner, UNIFORM_LAYER)?.icon, overlay.bulge_cut_icon, "The loincloth is drawn uncut.")
	var/with_testicles = length(look_images(owner, "behind"))
	var/found = FALSE
	for(var/image/part as anything in look_images(owner, "behind"))
		found ||= part.icon == testicles_overlay.sprite_datum.icon
	TEST_ASSERT(found, "The testicles hidden by the loincloth are not drawn behind it.")

	// Testicles drawn in another colour redraw the chest.
	var/chest_key = owner.icon_render_keys[BODY_ZONE_CHEST]
	testicles_overlay.draw_color = "#00FF00"
	owner.update_body_parts()
	TEST_ASSERT(owner.icon_render_keys[BODY_ZONE_CHEST] != chest_key, "Recoloured testicles behind the loincloth kept the old drawing.")
	// Testicles drawn from another sprite accessory are not the anatomy the look was resolved for, even with their suffix
	// unchanged: the anatomy memo compares the accessory too.
	var/datum/sprite_accessory/genital/testicles/shape = testicles_overlay.sprite_datum
	testicles_overlay.sprite_datum = SSaccessories.sprite_accessories[ORGAN_SLOT_TESTICLES]["Internal"]
	TEST_ASSERT(shape && testicles_overlay.sprite_datum && testicles_overlay.sprite_datum != shape, "The test needs a second testicles accessory.")
	TEST_ASSERT(!overlay.bulge_anatomy_unchanged(owner), "Testicles drawn from another sprite accessory kept the look resolved for the old one.")
	testicles_overlay.sprite_datum = shape
	TEST_ASSERT(overlay.bulge_anatomy_unchanged(owner), "The testicles' own sprite accessory back did not match the look again.")
	TEST_ASSERT(testicles.apply_visibility_label("Never show"), "The testicles' visibility writer was unavailable.")
	found = FALSE
	for(var/image/part as anything in look_images(owner, "behind"))
		found ||= part.icon == testicles_overlay.sprite_datum.icon
	TEST_ASSERT(!found, "Testicles set never to show are still drawn behind the loincloth.")
	TEST_ASSERT(length(look_images(owner, "behind")) < with_testicles, "Testicles set never to show still draw.")

	// Drawn over clothing: no look, and the loincloth whole again.
	TEST_ASSERT(penis.apply_visibility_label("Custom") && penis.apply_layering_label("Above all clothing"), "The penis's layering writers were unavailable.")
	TEST_ASSERT_NULL(overlay.bulge_key, "A penis drawn over clothing kept its look.")
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "A penis drawn over clothing left the loincloth cut.")
	TEST_ASSERT(drawn_leaf(owner, UNIFORM_LAYER)?.icon != overlay.bulge_cut_icon || isnull(overlay.bulge_cut_icon), "The loincloth was not drawn whole again.")
	TEST_ASSERT(penis.apply_layering_label("Normal") && penis.apply_visibility_label("Hidden by clothes"), "The penis's layering writers were unavailable.")
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_uniform_cut, "The loincloth's look did not come back.")

	// The penis taken out: no look, no cut, nothing left of the wearer on the overlay.
	penis.Remove(owner, special = TRUE)
	TEST_ASSERT_NULL(overlay.bulge_key, "A removed penis kept its look.")
	TEST_ASSERT_NULL(overlay.bulge_wearer, "A removed penis's overlay still holds its old wearer.")
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "A removed penis left the loincloth cut.")
	var/image/leaf = drawn_leaf(owner, UNIFORM_LAYER)
	TEST_ASSERT(isfile(leaf?.icon) && "[leaf.icon]" != "", "The loincloth was not drawn whole after the penis came out.")
	qdel(penis)

/// What draws no bulge: a chastity device, a husk, a taur, a sheathed penis, and a penis that never shows.
/datum/unit_test/portal_test/bulge_renderer/refusals

/datum/unit_test/portal_test/bulge_renderer/refusals/check()
	var/mob/living/carbon/human/owner = make_wearer(sheath = "Slit")
	TEST_ASSERT_NOTNULL(owner, "No wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	var/obj/item/clothing/under/color/grey/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(owner.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Could not put the jumpsuit on.")
	penis.set_size(12)
	TEST_ASSERT(penis.apply_arousal_label("Partly aroused"), "The half-hard writer was unavailable.")
	TEST_ASSERT_NULL(overlay.bulge_key, "A half-hard penis in its sheath drew a bulge.")
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_key, "A hard penis out of its sheath drew no bulge.")

	var/obj/item/clothing/sextoy/chastity/device = allocate(/obj/item/clothing/sextoy/chastity)
	owner.set_lewd_slot_item(ORGAN_SLOT_PENIS, device)
	device.forceMove(owner)
	device.lewd_equipped(owner, ORGAN_SLOT_PENIS)
	owner.update_inv_lewd()
	TEST_ASSERT_NULL(overlay.bulge_key, "A caged penis drew a bulge.")
	device.come_off(owner)
	TEST_ASSERT(overlay.bulge_key, "The bulge did not come back when the cage came off.")

	owner.become_husk(BURN)
	TEST_ASSERT_NULL(overlay.bulge_key, "A husk drew a bulge.")
	owner.cure_husk(BURN)
	owner.update_body()
	TEST_ASSERT(overlay.bulge_key, "The bulge did not come back with the cured husk.")

	var/obj/item/bodypart/chest/chest = owner.get_bodypart(BODY_ZONE_CHEST)
	var/shape = chest.bodyshape
	chest.bodyshape |= BODYSHAPE_TAUR_GENERIC
	owner.synchronize_bodyshapes()
	owner.update_body()
	TEST_ASSERT_NULL(overlay.bulge_key, "A taur drew a bulge.")
	chest.bodyshape = shape
	owner.synchronize_bodyshapes()
	owner.update_body()
	TEST_ASSERT(overlay.bulge_key, "The bulge did not come back off the taur body.")

	TEST_ASSERT(penis.apply_visibility_label("Never show"), "The visibility writer was unavailable.")
	TEST_ASSERT_NULL(overlay.bulge_key, "A penis that never shows drew a bulge.")

/// Two wearers of the same garment in other states keep their own looks; deleting a worn garment and a wearer with a
/// look leaves nothing behind.
/datum/unit_test/portal_test/bulge_renderer/sharing

/datum/unit_test/portal_test/bulge_renderer/sharing/check()
	var/mob/living/carbon/human/first = make_wearer()
	var/mob/living/carbon/human/second = make_wearer()
	TEST_ASSERT(first && second, "No wearers.")
	var/obj/item/organ/genital/penis/first_penis = first.get_organ_slot(ORGAN_SLOT_PENIS)
	var/obj/item/organ/genital/penis/second_penis = second.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/first_look = first_penis.bodypart_overlay
	var/datum/bodypart_overlay/mutant/genital/penis/second_look = second_penis.bodypart_overlay
	var/obj/item/clothing/under/dress/skirt/plaid/first_skirt = allocate(/obj/item/clothing/under/dress/skirt/plaid)
	var/obj/item/clothing/under/dress/skirt/plaid/second_skirt = allocate(/obj/item/clothing/under/dress/skirt/plaid)
	TEST_ASSERT(first.equip_to_slot_if_possible(first_skirt, ITEM_SLOT_ICLOTHING) && second.equip_to_slot_if_possible(second_skirt, ITEM_SLOT_ICLOTHING), "Could not dress the wearers.")
	first_penis.set_size(12)
	second_penis.set_size(7)
	TEST_ASSERT(first_penis.apply_arousal_label("Very aroused") && second_penis.apply_arousal_label("Partly aroused"), "The arousal writers were unavailable.")
	TEST_ASSERT(first_look.bulge_key && second_look.bulge_key && first_look.bulge_key != second_look.bulge_key, "Two wearers in other states share a look.")
	TEST_ASSERT(first_look.bulge_uniform_cut && !second_look.bulge_uniform_cut, "One wearer's cut reached the other.")
	TEST_ASSERT(drawn_leaf(second, UNIFORM_LAYER)?.icon != first_look.bulge_cut_icon, "The half-hard wearer's skirt is drawn cut.")
	var/second_key = second_look.bulge_key
	first_penis.set_size(37)
	TEST_ASSERT_EQUAL(second_look.bulge_key, second_key, "One wearer's change redrew the other's look.")

	// A worn garment deleted: its look and cut go with it.
	qdel(first_skirt)
	TEST_ASSERT_NULL(first_look.bulge_key, "A deleted skirt's look stayed drawn.")
	TEST_ASSERT_NULL(first_look.bulge_uniform_cut, "A deleted skirt's cut stayed recorded.")
	// A wearer deleted with a look: its penis goes, and its overlay lets go of it.
	qdel(second)
	TEST_ASSERT(QDELETED(second_penis), "A deleted wearer's penis survived.")
	TEST_ASSERT_NULL(second_look.bulge_wearer, "A deleted wearer's overlay still holds them.")
