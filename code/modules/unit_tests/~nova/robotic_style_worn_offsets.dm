/**
 * A cyborg head in a robotic style drawn as another species' head - the Vox style draws it as a Vox head - has what is
 * worn on it sit as on that species' own head, as the augment preferences make it for a spawning character.
 */
/datum/unit_test/robotic_style_worn_offsets

/datum/unit_test/robotic_style_worn_offsets/Run()
	// Each species' own head, by the limb_id a style borrows to draw a limb as one
	var/list/species_heads = list()
	for(var/obj/item/bodypart/head/head_type as anything in subtypesof(/obj/item/bodypart/head))
		if(head_type::abstract_type != head_type && head_type::limb_id && !(head_type::bodytype & BODYTYPE_ROBOTIC))
			species_heads[head_type::limb_id] ||= head_type
	var/datum/augment_item/limb/head/cyborg_head = GLOB.augment_items[/datum/augment_item/limb/head/cyborg]
	var/styles_with_offsets = 0
	for(var/style_name, style_instance in GLOB.robotic_styles_list)
		var/datum/robotic_style/style = style_instance
		var/obj/item/bodypart/head/species_head_type = species_heads[style.limb_id_override]
		if(isnull(species_head_type) || !(style.supported_slots & HEAD))
			continue
		var/obj/item/bodypart/head/styled_head = allocate(cyborg_head.path)
		// TRUE - worn_offsets, as for a limb made to wear the style
		TEST_ASSERT(cyborg_head.apply_style_to_limb(styled_head, style, cyborg_head.slot, FALSE, null, TRUE), "A cyborg head must take the [style_name] style")
		var/styled_offsets = offsets_text(styled_head)
		var/species_offsets = offsets_text(allocate(species_head_type))
		if(species_offsets != "\[]") // only a head with offsets can show a style failing to carry them
			styles_with_offsets++
		if(styled_offsets != species_offsets)
			TEST_FAIL("A cyborg head in the [style_name] style carries the worn offsets [styled_offsets], not the [species_offsets] of a [species_head_type]")
	TEST_ASSERT(styles_with_offsets, "No robotic style draws a cyborg head as the head of a species with worn offsets any more - the Vox style did")

/// A limb's worn offsets by feature key, as text to compare two limbs by
/datum/unit_test/robotic_style_worn_offsets/proc/offsets_text(obj/item/bodypart/limb)
	var/list/offsets = list()
	for(var/feature_key, offset in limb.feature_offsets)
		var/datum/worn_feature_offset/worn_offset = offset
		offsets[feature_key] = list(worn_offset.offset_x, worn_offset.offset_y)
	return json_encode(offsets)
