/// Exercise fallback selection, color changes, adjusted uniforms, and the worn overlay path.
/datum/unit_test/vox_clothing_templates

/datum/unit_test/vox_clothing_templates/Run()
	check_species(/datum/species/vox)
	check_species(/datum/species/vox_primalis)
	check_primalis_coverage()

/datum/unit_test/vox_clothing_templates/proc/check_species(species_type)
	var/mob/living/carbon/human/consistent/body = allocate(__IMPLIED_TYPE__)
	body.dna.features[FEATURE_LEGS] = DIGITIGRADE_LEGS
	body.set_species(species_type)
	var/datum/species/species = body.dna.species
	var/is_primalis = species_type == /datum/species/vox_primalis
	var/pants_config = is_primalis ? /datum/greyscale_config/vox_primalis_pants : /datum/greyscale_config/vox_pants
	var/feet_config = is_primalis ? /datum/greyscale_config/vox_feet/primalis : /datum/greyscale_config/vox_feet
	var/obj/item/clothing/under/color/uniform = allocate(__IMPLIED_TYPE__)
	var/obj/item/clothing/shoes/sneakers/shoes = allocate(__IMPLIED_TYPE__)
	var/obj/item/clothing/shoes/combat/boots = allocate(__IMPLIED_TYPE__)
	var/obj/item/clothing/gloves/color/black/gloves = allocate(__IMPLIED_TYPE__)
	var/list/items = list(uniform, shoes, boots, gloves)
	var/list/slots = list(LOADOUT_ITEM_UNIFORM, LOADOUT_ITEM_SHOES, LOADOUT_ITEM_SHOES, LOADOUT_ITEM_GLOVES)
	var/list/configs = list(pants_config, feet_config, feet_config, /datum/greyscale_config/vox_hands)
	var/list/template_states = list("pants", "sneakers_worn", "boots_worn", "gloves_worn")
	for(var/index in 1 to length(items))
		var/obj/item/item = items[index]
		var/source_file = item.worn_icon || (index == 4 ? 'icons/mob/clothing/hands.dmi' : (index == 1 ? DEFAULT_UNIFORM_FILE : DEFAULT_SHOES_FILE))
		var/source_state = item.worn_icon_state || item.icon_state
		TEST_ASSERT(icon_exists(source_file, source_state), "[item.type] test source is missing")
		var/icon/source = icon(source_file, source_state)
		var/icon/renamed = icon()
		renamed.Insert(source, "vox_template_test")
		if(index == 1)
			TEST_ASSERT(icon_exists(source_file, "[source_state]_d"), "Test uniform needs a rolled-down state")
			renamed.Insert(icon(source_file, "[source_state]_d"), "vox_template_test_d")
		item.worn_icon = fcopy_rsc(renamed)
		item.worn_icon_state = "vox_template_test"
		if(!is_primalis && slots[index] == LOADOUT_ITEM_SHOES)
			var/old_bodyshape = body.bodyshape
			body.bodyshape &= ~BODYSHAPE_DIGITIGRADE
			TEST_ASSERT_EQUAL(species.generate_custom_worn_icon(slots[index], item, body), item.worn_icon, "Plantigrade Vox should retain human footwear")
			body.bodyshape = old_bodyshape
		item.icon_state = "vox_template_test"
		item.worn_icon_vox = null
		item.worn_icon_better_vox = null
		item.greyscale_colors = "#9b3cda"
		var/icon/generated = species.generate_custom_worn_icon(slots[index], item, body)
		if(is_primalis && index == 4)
			TEST_ASSERT_NULL(generated, "Primalis gloves should retain their existing behavior")
			continue
		TEST_ASSERT_NOTNULL(generated, "[species_type] [template_states[index]] fallback missing")
		var/icon/template = icon(SSgreyscale.GetColoredIconByType(configs[index], item.greyscale_colors), template_states[index])
		for(var/direction in GLOB.cardinals)
			var/icon/expected = icon(template, dir = direction)
			if(index == 1)
				expected = replace_icon_legs(icon(source, dir = direction), expected)
			var/icon/actual = icon(generated, "vox_template_test", direction)
			if(!pixels_equal(actual, expected))
				TEST_FAIL("[species_type] [template_states[index]] wrong pixels, direction [direction]; states=[json_encode(icon_states(generated))], size=[actual.Width()]x[actual.Height()]")
		TEST_ASSERT_EQUAL(species.generate_custom_worn_icon(slots[index], item, body), generated, "Identical requests should reuse their cached file")
		item.greyscale_colors = "#31c65c"
		var/icon/recolored = species.generate_custom_worn_icon(slots[index], item, body)
		TEST_ASSERT(!pixels_equal(icon(generated, "vox_template_test"), icon(recolored, "vox_template_test")), "Recoloring reused stale pixels")
		item.greyscale_colors = null
		TEST_ASSERT_NOTNULL(species.generate_custom_worn_icon(slots[index], item, body), "Static clothing needs a sampled-color fallback")
		item.greyscale_colors = "#9b3cda"
		// A subsequently available dedicated sprite must still take priority.
		species.set_custom_worn_icon(slots[index], item, source_file)
		item.worn_icon_state = source_state
		TEST_ASSERT_EQUAL(species.generate_custom_worn_icon(slots[index], item, body), source_file, "Dedicated species sprites lost priority")
		species.set_custom_worn_icon(slots[index], item, null)
		item.worn_icon_state = "missing_vox_template_test"
		TEST_ASSERT_NULL(species.generate_custom_worn_icon(slots[index], item, body), "Missing human states must not invent clothing")
		item.worn_icon_state = "vox_template_test"

	// Preserve both rolled-down states and explicit worn-state aliases.
	uniform.icon_state = "vox_template_alias"
	var/icon/pants = species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform, body)
	for(var/state in list("vox_template_test", "vox_template_test_d", "vox_template_alias", "vox_template_alias_d"))
		TEST_ASSERT(icon_exists(pants, state), "Missing adjusted/aliased state [state]")
	for(var/direction in GLOB.cardinals)
		var/icon/rolled_source = icon(uniform.worn_icon, "vox_template_test_d", direction)
		var/icon/rolled_result = icon(pants, "vox_template_alias_d", direction)
		for(var/x in 1 to 32)
			for(var/y in 12 to 32)
				TEST_ASSERT_EQUAL(rolled_result.GetPixel(x, y), rolled_source.GetPixel(x, y), "Pants mask changed the rolled-down upper garment")
	uniform.body_parts_covered &= ~LEGS
	TEST_ASSERT_NULL(species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform, body), "Skirts must not receive pants")
	if(is_primalis)
		uniform.vox_primalis_force_pants = TRUE
		TEST_ASSERT_NOTNULL(species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform, body), "Explicit Primalis pants override was lost")
		uniform.vox_primalis_force_pants = FALSE
	uniform.body_parts_covered |= LEGS
	TEST_ASSERT_NULL(species.generate_custom_worn_icon(LOADOUT_ITEM_HEAD, uniform, body), "Unrelated slots must not receive templates")

	// Exercise rendering after equip, including digitigrade priority and mask suppression.
	body.equip_to_slot_or_del(uniform, ITEM_SLOT_ICLOTHING)
	body.equip_to_slot_or_del(shoes, ITEM_SLOT_FEET)
	if(!is_primalis)
		body.equip_to_slot_or_del(gloves, ITEM_SLOT_GLOVES)
	TEST_ASSERT_EQUAL(body.shoes, shoes, "Vox could not equip sneakers")
	body.update_worn_undersuit()
	body.update_worn_shoes()
	var/mutable_appearance/pants_overlay = get_worn_overlay(body, UNIFORM_LAYER)
	var/mutable_appearance/shoes_overlay = get_worn_overlay(body, SHOES_LAYER)
	TEST_ASSERT_NOTNULL(pants_overlay, "Equipped pants have no overlay")
	TEST_ASSERT_NOTNULL(shoes_overlay, "Equipped shoes have no overlay")
	TEST_ASSERT_EQUAL(shoes_overlay.icon, species.generate_custom_worn_icon(LOADOUT_ITEM_SHOES, shoes, body), "Rendering replaced the fitted Vox shoes with a generic digitigrade mask")
	if(!is_primalis)
		body.physique = FEMALE
		body.update_worn_undersuit()
		pants_overlay = get_worn_overlay(body, UNIFORM_LAYER)
		var/icon/female_pants = icon(pants_overlay.icon, pants_overlay.icon_state)
		var/icon/fitted_pants = icon(pants, uniform.icon_state)
		for(var/x in 1 to 32)
			for(var/y in 1 to 11)
				TEST_ASSERT_EQUAL(female_pants.GetPixel(x, y), fitted_pants.GetPixel(x, y), "Female shaping changed the fitted Vox legs")
		body.physique = MALE
		body.update_worn_undersuit()
	for(var/direction in GLOB.cardinals)
		body.setDir(direction)
		fcopy(getFlatIcon(body, no_anim = TRUE), "data/vox_templates_[species.id]_sneakers_[direction].png")
	body.temporarilyRemoveItemFromInventory(shoes)
	body.equip_to_slot_or_del(boots, ITEM_SLOT_FEET)
	TEST_ASSERT_EQUAL(body.shoes, boots, "Vox could not equip boots")
	uniform.adjusted = ALT_STYLE
	body.update_worn_undersuit()
	body.update_worn_shoes()
	for(var/direction in GLOB.cardinals)
		body.setDir(direction)
		fcopy(getFlatIcon(body, no_anim = TRUE), "data/vox_templates_[species.id]_boots_[direction].png")

/datum/unit_test/vox_clothing_templates/proc/pixels_equal(icon/left, icon/right)
	// Compare both after serialization, as they will be sent to a client.
	left = icon(fcopy_rsc(left))
	right = icon(fcopy_rsc(right))
	if(left.Width() != right.Width() || left.Height() != right.Height())
		return FALSE
	for(var/x in 1 to left.Width())
		for(var/y in 1 to left.Height())
			if(left.GetPixel(x, y) != right.GetPixel(x, y))
				return FALSE
	return TRUE

/// Worn emissive preparation stores a list with the visible appearance first.
/datum/unit_test/vox_clothing_templates/proc/get_worn_overlay(mob/living/carbon/human/body, layer)
	var/list/appearances = body.overlays_standing[layer]
	return islist(appearances) ? appearances[1] : appearances

/// Check fitted clothing against the actual anatomy rather than only its template pixels.
/datum/unit_test/vox_clothing_templates/proc/check_primalis_coverage()
	var/body_file = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	var/pants_file = SSgreyscale.GetColoredIconByType(/datum/greyscale_config/vox_primalis_pants, "#9b3cda")
	var/boots_file = SSgreyscale.GetColoredIconByType(/datum/greyscale_config/vox_feet/primalis, "#9b3cda")
	for(var/direction in GLOB.cardinals)
		var/icon/pants = icon(pants_file, "pants", direction)
		var/icon/boots = icon(boots_file, "boots_worn", direction)
		// The tailored pants intentionally leave a three-pixel bottom notch.
		if(direction == SOUTH || direction == NORTH)
			for(var/x in 15 to 17)
				TEST_ASSERT_NULL(pants.GetPixel(x, 6), "Primalis pants filled the bottom notch at [x],6, direction [direction]")
		for(var/state in list("vox_primalis_chest", "vox_primalis_l_leg", "vox_primalis_r_leg"))
			var/icon/anatomy = icon(body_file, state, direction)
			for(var/x in 1 to 32)
				for(var/y in 1 to 11)
					if(!anatomy.GetPixel(x, y))
						continue
					if(y >= 6)
						if(y == 6 && x >= 15 && x <= 17 && (direction == SOUTH || direction == NORTH))
							continue
						TEST_ASSERT_NOTNULL(pants.GetPixel(x, y), "Primalis pants expose hip/crotch at [x],[y], direction [direction]")
					else
						TEST_ASSERT_NOTNULL(boots.GetPixel(x, y), "Primalis boots expose foot at [x],[y], direction [direction]")
