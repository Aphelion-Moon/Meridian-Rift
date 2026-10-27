/**
 * The bulge renderer through play sequences beyond bulge_renderer.dm's: Custom genital layering, skin textures,
 * underwear a species does not wear, a jumpsuit rolled down, accessories and damage on a cut cover, a suit hiding the
 * jumpsuit, suits opened and hooded, a penis moved between wearers while aroused, a husk, a device and deletion while a
 * cover is cut, the underwear loincloth's cut handed to a skirt over it, colour matrices and filters on a printed
 * garment, an empty anatomy clearance, blood and dirt on the cover, blood on a cut cover, the guard of a cover's
 * redraw, and legs swapped under a uniform.
 * Each asserts on what is drawn: the chest's images and their layers, and the cover slots' drawn sprites.
 */

/// The chest's cached images on the float plane at `layer`, or null.
/datum/unit_test/portal_test/bulge_renderer/proc/chest_images_at(mob/living/carbon/human/owner, layer)
	for(var/image/part as anything in owner.drawn_limb_icons(BODY_ZONE_CHEST))
		if(part.plane == FLOAT_PLANE && part.layer == layer)
			LAZYADD(., part)

/// A wearer with the test penis at `length` inches, wearing `uniform_type` and the underwear `accessory_type`.
/datum/unit_test/portal_test/bulge_renderer/proc/dressed_wearer(length, uniform_type, accessory_type)
	var/mob/living/carbon/human/owner = make_wearer()
	if(!owner)
		return null
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	penis.set_size(length)
	if(uniform_type)
		var/obj/item/clothing/under/uniform = allocate(uniform_type)
		if(!owner.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING))
			return null
	if(accessory_type)
		var/datum/sprite_accessory/clothing/underwear/bottom_type = accessory_type
		var/datum/sprite_accessory/clothing/underwear/bottom = SSaccessories.underwear_list[initial(bottom_type.name)]
		if(!istype(bottom, accessory_type))
			return null
		owner.underwear = bottom.name
		owner.update_body()
	return owner

/// Whether a cover slot is drawn cut: its drawn sprite is the look's uniform cut, or a derived icon with no state.
/datum/unit_test/portal_test/bulge_renderer/proc/drawn_cut(mob/living/carbon/human/owner, slot)
	var/image/leaf = drawn_leaf(owner, slot)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = look(owner)
	if(!leaf)
		return FALSE
	if(slot == UNIFORM_LAYER)
		return !!overlay?.bulge_cut_icon && leaf.icon == overlay.bulge_cut_icon
	return !leaf.icon_state

/// Custom visibility, the penis set below or above the underwear. Under a garment drawn in front of it (a uniform,
/// either way; the underwear, below it), what a look draws of the penis stays at the look's layers (behind its cover,
/// over its cloth), never at the custom layer, for an exposed tip, a skirt's clearance and a loincloth's drape. Above
/// the underwear, with nothing else over it, the penis is drawn over the underwear as Nova draws it: no bulge, no cut,
/// and the bulge comes back when the penis is layered under the underwear again. Both layers the look takes for Custom
/// layering are pinned to where Nova draws the penis itself: above the underwear with no look, below it soft.
/datum/unit_test/portal_test/bulge_renderer/custom_layering

/datum/unit_test/portal_test/bulge_renderer/custom_layering/check()
	for(var/mode in list("Above underwear", "Below underwear"))
		layered(mode, "jeans", 49, /obj/item/clothing/under/pants/jeans, null)
		layered(mode, "plaid skirt", 37, /obj/item/clothing/under/dress/skirt/plaid, null)
	layered("Below underwear", "loincloth underwear", 12, null, /datum/sprite_accessory/clothing/underwear/loincloth)
	layered("Below underwear", "boxers", 49, null, /datum/sprite_accessory/clothing/underwear/male_boxers)
	layered("Below underwear", "heart boxers", 49, null, /datum/sprite_accessory/clothing/underwear/male_hearts)
	drawn_over("loincloth underwear", 12, /datum/sprite_accessory/clothing/underwear/loincloth)
	drawn_over("boxers", 49, /datum/sprite_accessory/clothing/underwear/male_boxers)
	drawn_over("heart boxers", 49, /datum/sprite_accessory/clothing/underwear/male_hearts)

/datum/unit_test/portal_test/bulge_renderer/custom_layering/proc/drawn_over(name, length, accessory_type)
	var/mob/living/carbon/human/owner = dressed_wearer(length, null, accessory_type)
	TEST_ASSERT_NOTNULL(owner, "[name]: no dressed wearer")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "[name]: the hard writer was unavailable")
	TEST_ASSERT(overlay.bulge_key, "[name]: hidden by clothes, the underwear drew no bulge")
	var/custom = -(UNDER_UNIFORM_LAYER - 0.1 + overlay.genital_stack_rank * GENITAL_STACK_STEP)
	TEST_ASSERT_EQUAL(-overlay.bulge_custom_layer(GENITAL_LAYER_ABOVE_UNDIES), custom, "[name]: the bulge's layer for Custom above the underwear is not Nova's")
	TEST_ASSERT_EQUAL(-overlay.bulge_custom_layer(GENITAL_LAYER_BELOW_UNDIES), -(UNDER_UNIFORM_SOCKS_LAYER + overlay.genital_stack_rank * GENITAL_STACK_STEP), "[name]: the bulge's layer for Custom below the underwear is not Nova's")
	TEST_ASSERT(penis.apply_visibility_label("Custom") && penis.apply_layering_label("Above underwear"), "[name]: the layering writers were unavailable")
	TEST_ASSERT_NULL(overlay.bulge_key, "[name]: the penis layered above the underwear kept a bulge on it")
	TEST_ASSERT_NULL(overlay.bulge_body_cut, "[name]: the underwear stayed cut under the penis layered above it")
	TEST_ASSERT(!drawn_cut(owner, BODY_LAYER), "[name]: the underwear is drawn cut under the penis layered above it")
	TEST_ASSERT(length(chest_images_at(owner, custom)), "[name]: the penis is not drawn above the underwear, as Nova layers it")
	TEST_ASSERT(penis.apply_layering_label("Below underwear"), "[name]: the layering writer was unavailable")
	TEST_ASSERT(overlay.bulge_key, "[name]: layered below the underwear again while aroused, the bulge did not return")
	TEST_ASSERT_NULL(chest_images_at(owner, custom), "[name]: layered below the underwear, the penis is still drawn above it")
	// Soft, it draws no look there: Nova draws the penis itself, at the layer the look takes for Custom below.
	TEST_ASSERT(penis.apply_arousal_label("Not aroused"), "[name]: the soft writer was unavailable")
	TEST_ASSERT(length(chest_images_at(owner, -overlay.bulge_custom_layer(GENITAL_LAYER_BELOW_UNDIES))), "[name]: soft below the underwear, Nova does not draw the penis at the bulge's layer for it")
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "[name]: the hard writer was unavailable")
	TEST_ASSERT(overlay.bulge_key, "[name]: hard below the underwear again, the bulge did not return")
	TEST_ASSERT(penis.apply_layering_label("Above underwear"), "[name]: the layering writer was unavailable")
	TEST_ASSERT_NULL(overlay.bulge_key, "[name]: layered above the underwear again, the bulge stayed")
	TEST_ASSERT(penis.apply_visibility_label("Hidden by clothes"), "[name]: the visibility writer was unavailable")
	TEST_ASSERT(overlay.bulge_key, "[name]: hidden by clothes again while aroused, the bulge did not return")

/datum/unit_test/portal_test/bulge_renderer/custom_layering/proc/layered(mode, name, length, uniform_type, accessory_type)
	var/mob/living/carbon/human/owner = dressed_wearer(length, uniform_type, accessory_type)
	TEST_ASSERT_NOTNULL(owner, "[mode], [name]: no dressed wearer")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_visibility_label("Custom") && penis.apply_layering_label(mode), "[mode], [name]: the layering writers were unavailable")
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "[mode], [name]: the hard writer was unavailable")
	TEST_ASSERT(overlay.bulge_key, "[mode], [name]: no look")
	TEST_ASSERT(overlay.bulge_anatomy_mask || overlay.bulge_anatomy_behind, "[mode], [name]: the look draws none of the penis")
	var/custom = mode == "Above underwear" ? -(UNDER_UNIFORM_LAYER - 0.1 + overlay.genital_stack_rank * GENITAL_STACK_STEP) : -(UNDER_UNIFORM_SOCKS_LAYER + overlay.genital_stack_rank * GENITAL_STACK_STEP)
	TEST_ASSERT_NULL(chest_images_at(owner, custom), "[mode], [name]: the penis is drawn at its custom layer under the look")
	if(overlay.bulge_anatomy_behind)
		TEST_ASSERT(length(look_images(owner, "behind")), "[mode], [name]: nothing is drawn behind the cover")
	if(overlay.bulge_anatomy_mask)
		var/shown = 0
		for(var/image/part as anything in look_images(owner))
			if(part.name != BULGE_CLOTH_NAME)
				shown++
		TEST_ASSERT(shown, "[mode], [name]: none of the penis is drawn over the cloth")
	if(overlay.bulge_sheet_patch)
		// A precoloured patch is drawn over the anatomy it leaves bare, at the same layer.
		var/list/drawn = look_images(owner)
		var/image/last = drawn[length(drawn)]
		TEST_ASSERT_EQUAL(last.icon_state, overlay.bulge_sheet_patch.icon_state, "[mode], [name]: the patch is not drawn over the penis")

/// A textured chest (checkered, which also whitens what it textures): the cloth a look draws keeps its palette and
/// takes no texture; the anatomy it shows over the cloth takes the texture like the rest of the skin.
/datum/unit_test/portal_test/bulge_renderer/textures

/datum/unit_test/portal_test/bulge_renderer/textures/check()
	var/mob/living/carbon/human/owner = dressed_wearer(49, /obj/item/clothing/under/pants/jeans, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_anatomy_mask && overlay.bulge_cloth, "Hard jeans at size 6 drew no adaptive look with an exposed tip.")
	var/obj/item/bodypart/chest/chest = owner.get_bodypart(BODY_ZONE_CHEST)
	chest.add_bodypart_texture(/datum/bodypart_texture/checkered)
	var/list/palette = list(overlay.bulge_cloth, overlay.bulge_light, overlay.bulge_highlight, overlay.bulge_shade, overlay.bulge_deep_shade)
	var/cloth = 0
	var/anatomy = 0
	for(var/image/part as anything in look_images(owner))
		if(part.name == BULGE_CLOTH_NAME)
			cloth++
			TEST_ASSERT(!length(part.filters), "The bulge's cloth took the chest's skin texture.")
			TEST_ASSERT(part.color in palette, "The bulge's cloth lost its palette colour to the texture.")
		else
			anatomy++
			TEST_ASSERT(length(part.filters), "The penis shown over the cloth did not take the chest's skin texture.")
	TEST_ASSERT(cloth && anatomy, "The textured chest drew [cloth] cloth and [anatomy] anatomy images of the look.")
	chest.remove_bodypart_texture(/datum/bodypart_texture/checkered)
	for(var/image/part as anything in look_images(owner))
		TEST_ASSERT(!length(part.filters), "The texture outlived its removal on the look.")

/// Underwear that stops being drawn takes its bulge with it, and brings it back: the trait a species without underwear
/// has (which a limb can also give, as an ash walker or Teshari chest does) added to a body already drawing the bulge
/// and removed again, and a change to such a species (which grows a new penis: it must draw no bulge either).
/datum/unit_test/portal_test/bulge_renderer/species_change

/datum/unit_test/portal_test/bulge_renderer/species_change/check()
	var/mob/living/carbon/human/owner = dressed_wearer(12, null, /datum/sprite_accessory/clothing/underwear/male_boxers)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_key && length(look_images(owner)), "Boxers drew no bulge.")
	ADD_TRAIT(owner, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
	owner.update_body()
	TEST_ASSERT_NULL(owner.overlays_standing[BODY_LAYER], "Underwear is drawn on a body that wears none.")
	TEST_ASSERT_NULL(overlay.bulge_key, "The boxers' bulge stayed when the boxers stopped being drawn.")
	TEST_ASSERT_NULL(look_images(owner), "The chest still draws the boxers' bulge.")
	owner.update_body()
	TEST_ASSERT_NULL(overlay.bulge_key, "A second body update brought the bulge of undrawn boxers back.")
	REMOVE_TRAIT(owner, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
	owner.update_body()
	TEST_ASSERT(overlay.bulge_key && length(look_images(owner)), "The boxers' bulge did not come back with the boxers.")

	owner.set_species(/datum/species/android)
	TEST_ASSERT(HAS_TRAIT(owner, TRAIT_NO_UNDERWEAR), "Androids wear underwear: this needs another species.")
	var/obj/item/organ/genital/penis/kept = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	TEST_ASSERT_NOTNULL(kept, "The change of species left no penis.")
	if(kept.aroused != AROUSAL_FULL)
		TEST_ASSERT(kept.apply_arousal_label("Very aroused"), "The hard writer was unavailable after the change of species.")
	owner.update_body()
	overlay = kept.bodypart_overlay
	TEST_ASSERT_NULL(owner.overlays_standing[BODY_LAYER], "An android's underwear is drawn.")
	TEST_ASSERT_NULL(overlay.bulge_key, "An android draws the bulge of boxers it does not wear.")
	TEST_ASSERT_NULL(look_images(owner), "An android's chest draws a bulge.")

/// An accessory (a skull codpiece, worn over the crotch) pinned on a jumpsuit keeps its look; on a hard revealing skirt
/// that is damaged, the damage is cut with the skirt and the codpiece is not.
/datum/unit_test/portal_test/bulge_renderer/cut_children

/datum/unit_test/portal_test/bulge_renderer/cut_children/check()
	var/mob/living/carbon/human/owner = dressed_wearer(12, /obj/item/clothing/under/color/grey, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	var/obj/item/clothing/under/jumpsuit = owner.w_uniform
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	var/key = overlay.bulge_key
	var/obj/item/clothing/accessory/skullcodpiece/pinned = allocate(/obj/item/clothing/accessory/skullcodpiece)
	TEST_ASSERT(jumpsuit.attach_accessory(pinned, null, FALSE), "Could not pin the codpiece on the jumpsuit.")
	TEST_ASSERT(codpiece_child(owner, pinned), "The jumpsuit does not draw the codpiece.")
	TEST_ASSERT_EQUAL(overlay.bulge_key, key, "Pinning an accessory changed the jumpsuit's look.")
	TEST_ASSERT(length(look_images(owner)), "The jumpsuit with a codpiece drew no bulge.")
	owner.dropItemToGround(jumpsuit)

	var/obj/item/clothing/under/dress/skirt/plaid/skirt = allocate(/obj/item/clothing/under/dress/skirt/plaid)
	skirt.update_clothes_damaged_state(CLOTHING_DAMAGED)
	pinned = allocate(/obj/item/clothing/accessory/skullcodpiece)
	TEST_ASSERT(skirt.attach_accessory(pinned, null, FALSE), "Could not pin the codpiece on the skirt.")
	TEST_ASSERT(owner.equip_to_slot_if_possible(skirt, ITEM_SLOT_ICLOTHING), "Could not put the skirt on.")
	TEST_ASSERT(overlay.bulge_uniform_cut && drawn_cut(owner, UNIFORM_LAYER), "The hard skirt is drawn uncut.")
	var/cut = bulge_cut_cover_flap('icons/effects/item_damage.dmi', "damageduniform", overlay.bulge_uniform_cut)
	TEST_ASSERT(cut, "The damaged-clothes overlay cannot be cut by the skirt's flap.")
	var/found = FALSE
	var/image/leaf = drawn_leaf(owner, UNIFORM_LAYER)
	for(var/image/child as anything in leaf.overlays)
		TEST_ASSERT(!(child.icon == 'icons/effects/item_damage.dmi' && child.icon_state == "damageduniform"), "The skirt's damage is drawn whole over the revealed shaft.")
		if(child.icon == cut)
			found = TRUE
	TEST_ASSERT(found, "The skirt's damage is not drawn cut with it.")
	TEST_ASSERT(codpiece_child(owner, pinned), "The codpiece on the cut skirt was cut or lost.")
	TEST_ASSERT(penis.apply_arousal_label("Partly aroused"), "The half-hard writer was unavailable.")
	TEST_ASSERT(!drawn_cut(owner, UNIFORM_LAYER), "The half-hard skirt is drawn cut.")
	var/whole = FALSE
	leaf = drawn_leaf(owner, UNIFORM_LAYER)
	for(var/image/child as anything in leaf.overlays)
		if(child.icon == 'icons/effects/item_damage.dmi' && child.icon_state == "damageduniform")
			whole = TRUE
	TEST_ASSERT(whole, "The half-hard skirt's damage is not drawn whole again.")
	TEST_ASSERT(codpiece_child(owner, pinned), "The codpiece on the whole skirt was lost.")

/// Whether the wearer's uniform draws an accessory, whole, as a child of its drawn sprite.
/datum/unit_test/portal_test/bulge_renderer/cut_children/proc/codpiece_child(mob/living/carbon/human/owner, obj/item/clothing/accessory/accessory)
	var/state = accessory.icon_state_is_worn ? accessory.icon_state : accessory.worn_icon_state
	for(var/image/child as anything in drawn_leaf(owner, UNIFORM_LAYER)?.overlays)
		if(child.icon == accessory.worn_icon && child.icon_state == state)
			return TRUE
	return FALSE

/// A suit that hides the jumpsuit (HIDEJUMPSUIT) over a cut skirt: the skirt is not drawn and holds no cut, nor the
/// look; the suit off draws the skirt cut and the look again.
/datum/unit_test/portal_test/bulge_renderer/hidden_jumpsuit

/datum/unit_test/portal_test/bulge_renderer/hidden_jumpsuit/check()
	var/mob/living/carbon/human/owner = dressed_wearer(37, /obj/item/clothing/under/dress/skirt/plaid, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_uniform_cut && drawn_cut(owner, UNIFORM_LAYER), "The hard skirt is drawn uncut.")
	var/obj/item/clothing/suit/bio_suit/suit = allocate(/obj/item/clothing/suit/bio_suit)
	TEST_ASSERT(owner.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Could not put the bio suit on.")
	TEST_ASSERT(owner.obscured_slots & HIDEJUMPSUIT, "The bio suit does not hide the skirt.")
	TEST_ASSERT_NULL(owner.overlays_standing[UNIFORM_LAYER], "The hidden skirt is drawn.")
	TEST_ASSERT_NULL(overlay.bulge_key, "The look stayed under a suit that hides it.")
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "A skirt that is not drawn keeps a cut.")
	TEST_ASSERT_NULL(look_images(owner), "The chest still draws the look under the suit.")
	owner.dropItemToGround(suit)
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_uniform_cut, "The skirt's look did not come back with the suit off.")
	TEST_ASSERT(drawn_cut(owner, UNIFORM_LAYER), "The skirt came back uncut.")
	TEST_ASSERT(length(look_images(owner, "behind")), "The penis is not drawn behind the skirt again.")

/// A coat that leaves the crotch clear only when open, opened and closed; a winter coat that leaves it clear only with
/// its hood down, its hood put up and down.
/datum/unit_test/portal_test/bulge_renderer/suit_states

/datum/unit_test/portal_test/bulge_renderer/suit_states/check()
	var/mob/living/carbon/human/owner = dressed_wearer(12, /obj/item/clothing/under/color/grey, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	var/key = overlay.bulge_key
	TEST_ASSERT(key, "The jumpsuit drew no bulge.")

	var/obj/item/clothing/suit/toggle/labcoat/research_director/coat = allocate(/obj/item/clothing/suit/toggle/labcoat/research_director)
	TEST_ASSERT(owner.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "Could not put the coat on.")
	TEST_ASSERT_NULL(overlay.bulge_key, "The closed coat did not hide the bulge.")
	var/datum/component/toggle_icon/buttons = coat.GetComponent(/datum/component/toggle_icon)
	TEST_ASSERT_NOTNULL(buttons, "The coat cannot be opened.")
	buttons.do_icon_toggle(coat, owner)
	TEST_ASSERT_EQUAL(overlay.bulge_key, key, "Opening the coat did not show the jumpsuit's bulge.")
	TEST_ASSERT(length(look_images(owner)), "The open coat's wearer draws no bulge.")
	buttons.do_icon_toggle(coat, owner)
	TEST_ASSERT_NULL(overlay.bulge_key, "Closing the coat left the bulge drawn.")
	owner.dropItemToGround(coat)

	var/obj/item/clothing/suit/hooded/wintercoat/wintercoat = allocate(/obj/item/clothing/suit/hooded/wintercoat)
	TEST_ASSERT(owner.equip_to_slot_if_possible(wintercoat, ITEM_SLOT_OCLOTHING), "Could not put the winter coat on.")
	TEST_ASSERT_EQUAL(overlay.bulge_key, key, "The winter coat with its hood down hid the bulge.")
	var/datum/component/toggle_attached_clothing/hood = wintercoat.GetComponent(/datum/component/toggle_attached_clothing)
	TEST_ASSERT_NOTNULL(hood, "The winter coat has no hood.")
	hood.toggle_deployable()
	TEST_ASSERT(owner.head, "The hood did not go up.")
	TEST_ASSERT_NULL(overlay.bulge_key, "The winter coat with its hood up did not hide the bulge.")
	hood.toggle_deployable()
	TEST_ASSERT_NULL(owner.head, "The hood did not go down.")
	TEST_ASSERT_EQUAL(overlay.bulge_key, key, "The winter coat with its hood down again hid the bulge.")
	TEST_ASSERT(length(look_images(owner)), "The winter coat's wearer draws no bulge.")

/// A hard penis taken out of a wearer whose skirt it cuts, and put into another wearer in a loincloth: the skirt is
/// drawn whole again, and the loincloth is cut for it at once.
/datum/unit_test/portal_test/bulge_renderer/organ_transfer

/datum/unit_test/portal_test/bulge_renderer/organ_transfer/check()
	var/mob/living/carbon/human/first = dressed_wearer(12, /obj/item/clothing/under/dress/skirt/plaid, null)
	var/mob/living/carbon/human/second = dressed_wearer(12, /obj/item/clothing/under/costume/loincloth, null)
	TEST_ASSERT(first && second, "No dressed wearers.")
	var/obj/item/organ/genital/penis/penis = first.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_uniform_cut && drawn_cut(first, UNIFORM_LAYER), "The first wearer's hard skirt is drawn uncut.")
	var/front = -(UNIFORM_LAYER - BULGE_ABOVE_COVER)
	TEST_ASSERT(length(chest_images_at(first, front)), "The first wearer's chest draws no look.")
	penis.Remove(first, special = TRUE)
	TEST_ASSERT_NULL(overlay.bulge_key, "The penis taken out kept its look.")
	TEST_ASSERT_NULL(overlay.bulge_wearer, "The penis taken out still holds its old wearer.")
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "The penis taken out keeps the skirt's cut.")
	var/image/leaf = drawn_leaf(first, UNIFORM_LAYER)
	TEST_ASSERT(isfile(leaf?.icon) && leaf.icon_state, "The first wearer's skirt is not drawn whole again.")
	TEST_ASSERT_NULL(chest_images_at(first, front), "The first wearer's chest still draws the look.")

	var/obj/item/organ/genital/penis/replaced = second.get_organ_slot(ORGAN_SLOT_PENIS)
	replaced.Remove(second, special = TRUE)
	qdel(replaced)
	TEST_ASSERT(penis.Insert(second, special = TRUE), "Could not put the penis in the second wearer.")
	if(penis.aroused != AROUSAL_FULL)
		TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable in the second wearer.")
	second.update_body()
	TEST_ASSERT_EQUAL(overlay.bulge_wearer, second, "The moved penis's look is not the second wearer's.")
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_anatomy_behind, "The moved penis drew no look through the loincloth.")
	TEST_ASSERT(overlay.bulge_uniform_cut && drawn_cut(second, UNIFORM_LAYER), "The second wearer's loincloth is not cut for the moved penis.")
	TEST_ASSERT(length(look_images(second, "behind")), "The moved penis is not drawn behind the loincloth.")

/// A husk and a chastity device while a skirt is cut: the skirt is drawn whole and the look goes; both undone, the cut
/// and the look come back.
/datum/unit_test/portal_test/bulge_renderer/cut_refusals

/datum/unit_test/portal_test/bulge_renderer/cut_refusals/check()
	var/mob/living/carbon/human/owner = dressed_wearer(37, /obj/item/clothing/under/dress/skirt/plaid, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_uniform_cut && drawn_cut(owner, UNIFORM_LAYER), "The hard skirt is drawn uncut.")

	owner.become_husk(BURN)
	TEST_ASSERT_NULL(overlay.bulge_key, "A husk drew the skirt's look.")
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "A husk's skirt keeps its cut.")
	TEST_ASSERT(!drawn_cut(owner, UNIFORM_LAYER), "A husk's skirt is drawn cut.")
	owner.cure_husk(BURN)
	owner.update_body()
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_uniform_cut && drawn_cut(owner, UNIFORM_LAYER), "The cut skirt's look did not come back with the cured husk.")

	var/obj/item/clothing/sextoy/chastity/device = allocate(/obj/item/clothing/sextoy/chastity)
	owner.set_lewd_slot_item(ORGAN_SLOT_PENIS, device)
	device.forceMove(owner)
	device.lewd_equipped(owner, ORGAN_SLOT_PENIS)
	owner.update_inv_lewd()
	TEST_ASSERT_NULL(overlay.bulge_key, "A caged penis drew the skirt's look.")
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "The caged penis's skirt keeps its cut.")
	TEST_ASSERT(!drawn_cut(owner, UNIFORM_LAYER), "The caged penis's skirt is drawn cut.")
	device.come_off(owner)
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_uniform_cut && drawn_cut(owner, UNIFORM_LAYER), "The cut skirt's look did not come back with the cage off.")

/// The underwear loincloth cut when hard, a revealing skirt put on over it (the skirt takes the cut, the loincloth is
/// drawn whole), and taken off again (the loincloth takes the cut back).
/datum/unit_test/portal_test/bulge_renderer/cut_handover

/datum/unit_test/portal_test/bulge_renderer/cut_handover/check()
	var/mob/living/carbon/human/owner = dressed_wearer(12, null, /datum/sprite_accessory/clothing/underwear/loincloth)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_body_cut && drawn_cut(owner, BODY_LAYER), "The hard loincloth is drawn uncut.")
	TEST_ASSERT(length(look_images(owner, "behind")), "The penis is not drawn behind the loincloth.")
	var/obj/item/clothing/under/dress/skirt/plaid/skirt = allocate(/obj/item/clothing/under/dress/skirt/plaid)
	TEST_ASSERT(owner.equip_to_slot_if_possible(skirt, ITEM_SLOT_ICLOTHING), "Could not put the skirt on.")
	TEST_ASSERT_NULL(overlay.bulge_body_cut, "The loincloth under the skirt keeps its cut.")
	TEST_ASSERT(!drawn_cut(owner, BODY_LAYER), "The loincloth under the skirt is drawn cut.")
	TEST_ASSERT(overlay.bulge_uniform_cut && drawn_cut(owner, UNIFORM_LAYER), "The skirt over the loincloth is not cut.")
	TEST_ASSERT_EQUAL(overlay.bulge_layer, UNIFORM_LAYER, "The look did not move to the skirt.")
	owner.dropItemToGround(skirt)
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "A skirt taken off keeps its cut on the look.")
	TEST_ASSERT(overlay.bulge_body_cut && drawn_cut(owner, BODY_LAYER), "The loincloth did not take the cut back.")
	TEST_ASSERT_EQUAL(overlay.bulge_layer, UNDER_UNIFORM_LAYER, "The look did not move back to the loincloth.")

/// A wearer deleted while their skirt is cut: the penis goes with them, and its overlay holds nothing of theirs.
/datum/unit_test/portal_test/bulge_renderer/deleted_while_cut

/datum/unit_test/portal_test/bulge_renderer/deleted_while_cut/check()
	var/mob/living/carbon/human/owner = dressed_wearer(37, /obj/item/clothing/under/dress/skirt/plaid, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_uniform_cut && drawn_cut(owner, UNIFORM_LAYER), "The hard skirt is drawn uncut.")
	qdel(owner)
	TEST_ASSERT(QDELETED(penis), "A deleted wearer's penis survived.")
	TEST_ASSERT_NULL(overlay.bulge_wearer, "A deleted wearer's overlay still holds them.")
	TEST_ASSERT_NULL(overlay.bulge_key, "A deleted wearer's overlay keeps its look.")
	TEST_ASSERT_NULL(overlay.bulge_uniform_cut, "A deleted wearer's overlay keeps the skirt's cut.")
	TEST_ASSERT_NULL(overlay.bulge_cut_icon, "A deleted wearer's overlay keeps the cut sprite.")

/// A colour matrix, then a colour filter changed straight to another, on a worn printed garment: the look falls back to
/// the adaptive palette at once, its cloth drawn through the colour filter the garment is drawn through, follows the
/// garment from one filter to the next, and prints again when the colour comes off.
/datum/unit_test/portal_test/bulge_renderer/colour_filters

/datum/unit_test/portal_test/bulge_renderer/colour_filters/check()
	var/mob/living/carbon/human/owner = dressed_wearer(12, /obj/item/clothing/under/camo/gags, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	var/obj/item/clothing/under/camo = owner.w_uniform
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_patch, "The printed camouflage drew no print.")
	var/key
	for(var/list/colour as anything in list(COLOR_MATRIX_GRAYSCALE, color_matrix_filter(COLOR_MATRIX_GRAYSCALE), color_matrix_filter(COLOR_MATRIX_INVERT)))
		var/how = isnull(colour["type"]) ? "a colour matrix" : (key ? "a second colour filter" : "a colour filter")
		camo.add_atom_colour(colour, FIXED_COLOUR_PRIORITY)
		TEST_ASSERT(islist(camo.color) || camo.cached_color_filter, "The camouflage did not take [how].")
		TEST_ASSERT_NULL(overlay.bulge_patch, "Under [how], the printed camouflage kept its print.")
		TEST_ASSERT(overlay.bulge_key && overlay.bulge_cloth && length(look_images(owner)), "Under [how], the camouflage drew no adaptive look.")
		// Every piece of the look's cloth is drawn through the colour filter the camouflage itself is drawn through, as
		// color_atom_overlay() names it.
		var/image/leaf = drawn_leaf(owner, UNIFORM_LAYER)
		var/cover
		for(var/filter in leaf?.filters)
			if(filter:name == ATOM_PRIORITY_COLOR_FILTER)
				cover = filter
		TEST_ASSERT(cover, "Under [how], the camouflage is drawn through no colour filter.")
		var/cloth = 0
		for(var/image/part as anything in look_images(owner))
			if(part.name != BULGE_CLOTH_NAME)
				continue
			cloth++
			var/drawn
			for(var/found in part.filters)
				if(found:name == ATOM_PRIORITY_COLOR_FILTER)
					drawn = found
			TEST_ASSERT(drawn && json_encode(drawn:color) == json_encode(cover:color), "Under [how], the bulge's cloth is not drawn through the camouflage's colour filter.")
		TEST_ASSERT(cloth, "Under [how], the look draws no cloth.")
		if(colour["type"] && !key)
			// The next filter replaces this one at once, with no colour off between (bulge_cover_unchanged() compares the
			// two by value).
			key = overlay.bulge_key
			continue
		if(key)
			TEST_ASSERT(overlay.bulge_key != key, "Changed straight from one colour filter to another, the look kept the first one's key.")
		camo.remove_atom_colour(FIXED_COLOUR_PRIORITY)
		TEST_ASSERT(overlay.bulge_patch && length(look_images(owner)), "The print did not come back without [how].")

/// Blood put on a worn cover while the bulge shows draws over the bulge's cloth too, kept to its pixels, in the blood's
/// colour and just after the cloth; washed off, it goes from both. Any overlay the cover draws over its own sprite does
/// the same (here a stain added the way clothing_dirt adds its dirt).
/datum/unit_test/portal_test/bulge_renderer/blood

/datum/unit_test/portal_test/bulge_renderer/blood/check()
	var/mob/living/carbon/human/owner = dressed_wearer(12, /obj/item/clothing/under/color/grey, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	var/obj/item/clothing/under/jumpsuit = owner.w_uniform
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	var/key = overlay.bulge_key
	var/clean = length(look_images(owner))
	TEST_ASSERT(clean && !overlay.bulge_over && !overlay.bulge_cover_over, "The clean jumpsuit's look draws something over its cloth.")

	jumpsuit.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	owner.update_clothing(ITEM_SLOT_ICLOTHING)
	TEST_ASSERT(overlay.bulge_key && overlay.bulge_key != key, "Blood on the jumpsuit did not change its look.")
	var/cut = bulge_clipped_icon('icons/effects/blood.dmi', "uniformblood", overlay.bulge_template)
	TEST_ASSERT(cut, "The jumpsuit's blood cannot be kept to the bulge's cloth.")
	TEST_ASSERT(over_last(owner, cut, jumpsuit.get_blood_dna_color()), "The jumpsuit's blood is not drawn over the bulge's cloth, in its colour, after the cloth.")
	TEST_ASSERT_EQUAL(length(look_images(owner)), clean + 1, "Blood added other than one image over the cloth.")
	jumpsuit.wash(CLEAN_TYPE_BLOOD)
	TEST_ASSERT_EQUAL(overlay.bulge_key, key, "Washing the blood off did not give the clean look back.")
	TEST_ASSERT(!overlay.bulge_over && length(look_images(owner)) == clean, "Blood washed off is still drawn over the cloth.")

	RegisterSignal(jumpsuit, COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS, PROC_REF(add_stain))
	owner.update_clothing(ITEM_SLOT_ICLOTHING)
	cut = bulge_clipped_icon('icons/effects/item_damage.dmi', "damageduniform", overlay.bulge_template)
	TEST_ASSERT(cut && over_last(owner, cut, "#664422"), "A stain the jumpsuit draws over itself is not drawn over the bulge's cloth.")
	UnregisterSignal(jumpsuit, COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS)
	owner.update_clothing(ITEM_SLOT_ICLOTHING)
	TEST_ASSERT_EQUAL(overlay.bulge_key, key, "The stain outlived its removal on the look.")

/// Whether the last image the look draws over its cloth is `cut` in `colour`, a cloth image (no skin texture), after
/// every other cloth image.
/datum/unit_test/portal_test/bulge_renderer/blood/proc/over_last(mob/living/carbon/human/owner, cut, colour)
	var/image/found
	for(var/image/part as anything in look_images(owner))
		if(part.name == BULGE_CLOTH_NAME)
			found = part
	return found?.icon == cut && found.color == LOWER_TEXT(colour) // Appearances hold colours in lower case.

/// Adds a stain over the jumpsuit's sprite, as clothing_dirt adds dirt over the garments it applies to.
/datum/unit_test/portal_test/bulge_renderer/blood/proc/add_stain(obj/item/source, list/overlays, mutable_appearance/standing, mutable_appearance/draw_target, isinhands, icon_file, bodyshape)
	SIGNAL_HANDLER
	if(isinhands)
		return
	var/mutable_appearance/stain = mutable_appearance('icons/effects/item_damage.dmi', "damageduniform")
	stain.color = "#664422"
	overlays += stain

/// Blood on a revealing skirt that is cut when hard is cut with it, or it would draw over the shaft the cut reveals;
/// the look's cloth carries the blood as the skirt had it, uncut. Half hard, the blood is drawn whole again.
/datum/unit_test/portal_test/bulge_renderer/blood_on_cut

/datum/unit_test/portal_test/bulge_renderer/blood_on_cut/check()
	var/mob/living/carbon/human/owner = dressed_wearer(37, /obj/item/clothing/under/dress/skirt/plaid, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis.bodypart_overlay
	var/obj/item/clothing/under/skirt = owner.w_uniform
	skirt.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	owner.update_clothing(ITEM_SLOT_ICLOTHING)
	TEST_ASSERT_EQUAL(blood_drawn(owner), 'icons/effects/blood.dmi', "The soft skirt does not draw its blood.")
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	TEST_ASSERT(overlay.bulge_uniform_cut && drawn_cut(owner, UNIFORM_LAYER), "The hard bloody skirt is drawn uncut.")
	var/cut = bulge_cut_cover_flap('icons/effects/blood.dmi', "uniformblood", overlay.bulge_uniform_cut)
	TEST_ASSERT(cut, "The skirt's blood cannot be cut by its flap.")
	TEST_ASSERT_EQUAL(blood_drawn(owner), cut, "The hard skirt's blood is not cut with it.")
	var/kept = bulge_clipped_icon('icons/effects/blood.dmi', "uniformblood", overlay.bulge_template)
	TEST_ASSERT(kept, "The skirt's blood cannot be kept to the look's cloth.")
	var/found = FALSE
	for(var/image/part as anything in look_images(owner))
		if(part.name == BULGE_CLOTH_NAME && part.icon == kept)
			found = TRUE
	TEST_ASSERT(found, "The look's cloth does not carry the skirt's blood uncut.")
	TEST_ASSERT(penis.apply_arousal_label("Partly aroused"), "The half-hard writer was unavailable.")
	TEST_ASSERT_EQUAL(blood_drawn(owner), 'icons/effects/blood.dmi', "The half-hard skirt's blood is not drawn whole again.")

/// The sprite of the first overlay the drawn skirt's root holds beside the skirt's own sprite on the float plane (its
/// blood), or null.
/datum/unit_test/portal_test/bulge_renderer/blood_on_cut/proc/blood_drawn(mob/living/carbon/human/owner)
	var/image/root = bulge_drawn_root(owner.overlays_standing[UNIFORM_LAYER])
	var/list/siblings = root?.overlays
	for(var/index in 2 to length(siblings))
		var/image/sibling = siblings[index]
		if(sibling.plane == FLOAT_PLANE)
			return sibling.icon
	return null

/// Legs swapped to digitigrade by the legs preference and back, then a digitigrade leg attached as surgery attaches one:
/// each time the uniform is drawn again for the new legs at once (the leg-swap refresh in try_attach_limb() and in the
/// legs preference), so the bulge, whose shapes follow the legs, never sits on a sprite drawn for the old ones.
/datum/unit_test/portal_test/bulge_renderer/leg_swap

/datum/unit_test/portal_test/bulge_renderer/leg_swap/check()
	var/mob/living/carbon/human/owner = dressed_wearer(12, /obj/item/clothing/under/color/grey, null)
	TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	var/before = drawn_leaf(owner, UNIFORM_LAYER)?.icon
	TEST_ASSERT(set_legs(owner, DIGITIGRADE_LEGS), "Could not give the wearer digitigrade legs.")
	check_fresh(owner, before, "the legs preference")
	TEST_ASSERT(set_legs(owner, NORMAL_LEGS), "Could not give the wearer plain legs back.")
	TEST_ASSERT_EQUAL(drawn_leaf(owner, UNIFORM_LAYER)?.icon, before, "Plain legs again still drew the jumpsuit for digitigrade legs.")
	var/obj/item/bodypart/leg/left/digitigrade/leg = allocate(/obj/item/bodypart/leg/left/digitigrade)
	TEST_ASSERT(leg.replace_limb(owner), "Could not attach a digitigrade leg.")
	check_fresh(owner, before, "an attached leg")

/// After a swap to digitigrade legs: the uniform as drawn is the one a fresh render draws for them, not `before`.
/datum/unit_test/portal_test/bulge_renderer/leg_swap/proc/check_fresh(mob/living/carbon/human/owner, before, how)
	var/drawn = drawn_leaf(owner, UNIFORM_LAYER)?.icon
	owner.update_worn_undersuit()
	var/fresh = drawn_leaf(owner, UNIFORM_LAYER)?.icon
	TEST_ASSERT(fresh && fresh != before, "The jumpsuit draws one sprite for both legs; the test needs one that does not.")
	TEST_ASSERT_EQUAL(drawn, fresh, "After [how] the jumpsuit was still drawn for the old legs.")

/// Adaptive and printed cloth follow changes to the worn garment's alpha.
/datum/unit_test/portal_test/bulge_renderer/cover_alpha

/datum/unit_test/portal_test/bulge_renderer/cover_alpha/check()
	for(var/garment_type in list(/obj/item/clothing/under/color/grey, /obj/item/clothing/under/camo/gags))
		for(var/bloodied in list(FALSE, TRUE))
			var/mob/living/carbon/human/owner = dressed_wearer(12, garment_type, null)
			TEST_ASSERT_NOTNULL(owner, "No dressed wearer.")
			var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
			TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The arousal writer was unavailable.")
			if(bloodied)
				owner.w_uniform.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
			for(var/opacity in list(128, 0, 255))
				owner.w_uniform.alpha = opacity
				owner.update_worn_undersuit()
				var/image/root = bulge_drawn_root(owner.overlays_standing[UNIFORM_LAYER])
				TEST_ASSERT_EQUAL(root.alpha, opacity, "The garment did not take its requested alpha.")
				if(bloodied)
					TEST_ASSERT(root != bulge_drawn_leaf(root), "Blood did not create a nested worn appearance.")
				var/cloth_count = 0
				for(var/image/part as anything in look_images(owner))
					if(part.name != BULGE_CLOTH_NAME)
						continue
					cloth_count++
					TEST_ASSERT_EQUAL(part.alpha, opacity, "The bulge cloth did not follow its garment's alpha.")
				TEST_ASSERT(cloth_count, "No cloth was available for the alpha check.")
				var/datum/bodypart_overlay/mutant/genital/penis/overlay = look(owner)
				var/blockers = 0
				for(var/image/part, flags in overlay.bulge_cloth_images(penis.bodypart_owner, -(overlay.bulge_layer - BULGE_ABOVE_COVER)))
					if(!(flags & LIMB_OVERLAY_META))
						continue
					blockers++
					TEST_ASSERT_EQUAL(part.alpha, opacity, "The cloth emissive blocker did not follow garment alpha.")
				TEST_ASSERT(blockers, "The alpha check found no cloth emissive blocker.")
