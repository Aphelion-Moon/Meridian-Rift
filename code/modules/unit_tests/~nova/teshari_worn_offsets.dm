/**
 * A Teshari's raptoral prosthetics are drawn in her own shape, so what she wears and holds sits on them as it does on her
 * own limbs - whether they were put on as a spawning character's augments are, or attached by surgery.
 */
/datum/unit_test/teshari_worn_offsets

/datum/unit_test/teshari_worn_offsets/Run()
	var/mob/living/carbon/human/consistent/bird = allocate(/mob/living/carbon/human/consistent)
	bird.set_species(/datum/species/teshari)
	var/list/own_offsets = list()
	for(var/obj/item/bodypart/limb as anything in bird.bodyparts)
		own_offsets[limb.body_zone] = offsets_text(limb)

	// The report - a headset sat where a human's would on the raptoral cybernetic head. The robotics headset has no
	// Teshari sprite, so it is drawn from the human one and the head's offset places it, like the reported one.
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_rob)
	TEST_ASSERT(bird.equip_to_slot_if_possible(headset, ITEM_SLOT_EARS), "A Teshari must be able to wear a headset")
	bird.update_worn_ears()
	var/mutable_appearance/on_own_head = drawn_on(bird, EARS_LAYER)
	TEST_ASSERT_NOTNULL(on_own_head, "A Teshari's headset must be drawn")
	var/own_head_x = on_own_head.pixel_w
	var/own_head_y = on_own_head.pixel_z
	TEST_ASSERT(own_head_y < 0, "A robotics headset must sit lower on a Teshari's own head than on a human's - if it has a Teshari sprite now, wear one that has none")
	var/obj/item/bodypart/head/cybernetic_head = put_on(bird, /obj/item/bodypart/head/robot/teshari)
	TEST_ASSERT_EQUAL(cybernetic_head.owner, bird, "A raptoral cybernetic head must replace a Teshari's own")
	bird.update_worn_ears()
	var/mutable_appearance/on_cybernetic_head = drawn_on(bird, EARS_LAYER)
	TEST_ASSERT_NOTNULL(on_cybernetic_head, "A headset on a raptoral cybernetic head must be drawn")
	TEST_ASSERT_EQUAL(on_cybernetic_head.pixel_w, own_head_x, "A headset must sit across a raptoral cybernetic head as on a Teshari's own")
	TEST_ASSERT_EQUAL(on_cybernetic_head.pixel_z, own_head_y, "A headset must sit as low on a raptoral cybernetic head as on a Teshari's own")

	// Every raptoral limb the augment preferences offer
	for(var/augment_path, augment_instance in GLOB.augment_items)
		var/datum/augment_item/limb/augment = augment_instance
		if(!istype(augment) || !LAZYACCESS(augment.species_whitelist, SPECIES_TESHARI))
			continue
		var/obj/item/bodypart/limb = put_on(bird, augment.path)
		if(limb.owner != bird)
			TEST_FAIL("[augment.path] from the augment preferences must replace a Teshari's [limb.body_zone]")
			continue
		var/limb_offsets = offsets_text(limb)
		if(limb_offsets != own_offsets[limb.body_zone])
			TEST_FAIL("[augment.path] from the augment preferences carries the worn offsets [limb_offsets], not a Teshari's own [limb.body_zone]'s [own_offsets[limb.body_zone]]")

	// The advanced raptoral forelimbs, which only surgery attaches
	for(var/obj/item/bodypart/arm/forelimb_type as anything in list(/obj/item/bodypart/arm/left/robot/teshari_advanced, /obj/item/bodypart/arm/right/robot/teshari_advanced))
		var/obj/item/bodypart/old_arm = bird.get_bodypart(forelimb_type::body_zone)
		old_arm.drop_limb()
		qdel(old_arm)
		var/obj/item/bodypart/arm/forelimb = allocate(forelimb_type)
		if(!forelimb.try_attach_limb(bird))
			TEST_FAIL("[forelimb_type] must attach to a Teshari's empty shoulder")
			continue
		var/limb_offsets = offsets_text(forelimb)
		if(limb_offsets != own_offsets[forelimb.body_zone])
			TEST_FAIL("[forelimb_type] attached by surgery carries the worn offsets [limb_offsets], not a Teshari's own [forelimb.body_zone]'s [own_offsets[forelimb.body_zone]]")

/// Replaces a body's limb with a new one of the given type, as the augment preferences do for a spawning character
/datum/unit_test/teshari_worn_offsets/proc/put_on(mob/living/carbon/human/body, obj/item/bodypart/limb_type)
	var/obj/item/bodypart/limb = new limb_type(body)
	allocated += limb
	var/obj/item/bodypart/old_limb = body.get_bodypart(limb.body_zone, include_stumps = TRUE)
	if(limb.replace_limb(body))
		qdel(old_limb)
	return limb

/// What a body draws for the item it wears on a layer - the worn emissives keep a list there, with any glow apart
/datum/unit_test/teshari_worn_offsets/proc/drawn_on(mob/living/carbon/human/body, layer)
	var/standing = body.overlays_standing[layer]
	if(!islist(standing))
		return standing
	for(var/mutable_appearance/drawn as anything in standing)
		if(drawn.plane != EMISSIVE_PLANE)
			return drawn

/// A limb's worn offsets by feature key, as text to compare two limbs by
/datum/unit_test/teshari_worn_offsets/proc/offsets_text(obj/item/bodypart/limb)
	var/list/offsets = list()
	for(var/feature_key, offset in limb.feature_offsets)
		var/datum/worn_feature_offset/worn_offset = offset
		offsets[feature_key] = list(worn_offset.offset_x, worn_offset.offset_y)
	return json_encode(offsets)
