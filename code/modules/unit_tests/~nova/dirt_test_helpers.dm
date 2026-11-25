/// Drops `key` and its value, so it's made afresh when next asked for. The keys left keep their order.
/datum/bulge_bounded_cache/proc/forget(key)
	if(isnull(LAZYACCESS(entries, key)))
		return
	entries -= key
	// put the oldest at the start of the list, so the next key stored goes after the newest
	if(cursor > 1)
		keys = keys.Copy(cursor) + keys.Copy(1, cursor)
		cursor = 1
	keys -= key

/// Returns the images a zone's limb was last drawn with, from either store (limb_icons_for()), or null while it isn't
/// drawn.
/mob/living/carbon/proc/drawn_limb_icons(zone)
	RETURN_TYPE(/list)
	var/key = icon_render_keys[zone]
	if(isnull(key))
		return null
	if(!findtextEx(key, DIRT_PRIVATE_KEY))
		return limb_icon_cache[key]
	var/list/entry = private_limb_icons?[zone]
	return entry?[1] == key ? entry[2] : null

/**
 * Returns what a body draws at one of its overlays_standing layers as a list, though tg keeps a lone image there bare.
 *
 * Arguments:
 * - standing: The layer's overlays_standing entry.
 */
/proc/standing_images(standing)
	RETURN_TYPE(/list)
	return islist(standing) ? standing : list(standing)

/**
 * Returns the height maps on an image's displacement filters, in the order they're drawn, each list(the map's icon,
 * the filter's size). Its filters are read, not its filter_data, which the copy of it kept for drawing leaves behind.
 */
/proc/height_filter_maps(image/drawn)
	RETURN_TYPE(/list)
	. = list()
	for(var/dm_filter/height_filter as anything in drawn.filters)
		if(height_filter.type == "displace")
			. += list(list(icon(height_filter.icon), height_filter.size))

/**
 * Returns the parity corpus beside the dirt tests (dirt_corpus.json), decoded. It's compiled in, since CI's test world
 * is deployed without code/.
 */
/proc/dirt_parity_corpus()
	RETURN_TYPE(/list)
	return json_decode(file2text('code/modules/unit_tests/~nova/dirt_corpus.json') || "{}")

/**
 * Seeds BYOND's random number generator so that the next variant drawn is `variant`. Returns a number to seed it with
 * after that draw, so the rest of the run stays random. A new splat's variant is drawn at random, and a test that
 * checks its pixels needs a set one. The call made next must draw the variant before any other random call, as
 * dirt_land() and dirt_fresh_variant() do.
 *
 * Arguments:
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - splats, zone: For mess, the splats of the surface the shot hits and its DIRT_ZONE_* define, as dirt_fresh_variant()
 *   reads them. Null for a general deposit.
 */
/proc/dirt_test_seed_variant(variant, list/splats, zone)
	. = rand(1, 16777215)
	for(var/seed in 1 to 1000)
		rand_seed(seed)
		if((zone ? dirt_fresh_variant(splats, zone) : rand(0, DIRT_VARIANTS - 1)) == variant)
			rand_seed(seed)
			return
	CRASH("No seed up to 1000 draws variant [variant].")

/**
 * Seeds BYOND's random number generator so that the next roll passes one chance and fails another. Returns a number to
 * seed it with after that roll, so the rest of the run stays random. A source rolls its own chance, and a test needs a
 * set outcome. The call made next must roll before any other random call, as dirt_source_land() does.
 *
 * Arguments:
 * - passing: The chance, in percent, the roll passes.
 * - failing: A chance, in percent, the same roll fails, or 0.
 */
/proc/dirt_test_seed_roll(passing, failing = 0)
	. = rand(1, 16777215)
	for(var/seed in 1 to 1000)
		rand_seed(seed)
		if(!prob(passing))
			continue
		rand_seed(seed)
		if(prob(failing))
			continue
		rand_seed(seed)
		return
	CRASH("No seed up to 1000 passes a chance of [passing] and fails one of [failing].")

/// The dirt tests that draw dirt on bodies, with the helpers they share: genitals built from DNA as a real character's,
/// taurs, and reads of what a body draws.
/datum/unit_test/dirt_test
	parent_type = /datum/unit_test/portal_test
	abstract_type = /datum/unit_test/dirt_test

/**
 * Returns the images a worn slot draws inset over its garment.
 *
 * Arguments:
 * - body: The wearer.
 * - layer: The slot's overlays_standing index.
 */
/datum/unit_test/dirt_test/proc/inset_images(mob/living/carbon/human/body, layer)
	RETURN_TYPE(/list)
	. = list()
	var/image/root = bulge_drawn_root(body.overlays_standing[layer])
	for(var/image/drawn as anything in root?.overlays)
		if(drawn.blend_mode == BLEND_INSET_OVERLAY)
			. += drawn

/**
 * Returns the skin dirt containers in a limb's cached images at a layer, or the emissive blockers beside them. Each
 * container holds a baked image, since a container draws only while the masks hold one for its limb.
 *
 * Arguments:
 * - zone: The limb's body zone.
 * - layer: DIRT_SKIN_LAYER, or DIRT_HAND_SKIN_LAYER for an arm's hand.
 * - blockers: Whether it returns the blockers, off the float plane, in place of the containers.
 */
/datum/unit_test/dirt_test/proc/skin_images(mob/living/carbon/human/body, zone, layer = DIRT_SKIN_LAYER, blockers = FALSE)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/drawn as anything in body.drawn_limb_icons(zone))
		if(drawn.layer == -layer && (drawn.plane != FLOAT_PLANE) == blockers)
			. += drawn

/// Returns the chest's cached images at a layer that draw no sprite of their own but hold others, its parts' shares.
/datum/unit_test/dirt_test/proc/share_images(mob/living/carbon/human/body, layer)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/container as anything in limb_containers(body, BODY_ZONE_CHEST))
		if(container.layer == layer)
			. += container

/// Returns the four directions in the masks' order, written out here so a direction dirt_mask_directions() drops
/// fails a test. You should NEVER modify it.
/datum/unit_test/dirt_test/proc/four_directions()
	RETURN_TYPE(/list)
	var/static/list/directions = list(SOUTH, NORTH, EAST, WEST)
	return directions

/// Returns a new job that made a request's masks from start to end, outside the queue and the mask cache.
/datum/unit_test/dirt_test/proc/made_job(datum/dirt_mask_request/request)
	RETURN_TYPE(/datum/dirt_mask_job)
	var/datum/dirt_mask_job/job = new(request, request.mask_key())
	job.template_source = SSdirt.template_for(request.zone_sources)
	// a template queued for it is built first
	SSdirt.finish_all()
	SSdirt.work_on(job, FALSE)
	return job

/**
 * Returns when every splat a person carries last landed (/datum/dirt_splat/var/last_serial). It reads the splats on
 * their skin, parts, drawn parts, hair and underclothes, and on what they wear.
 */
/datum/unit_test/dirt_test/proc/held_serials(mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/component/dirtiness/carrier as anything in dirt_carriers(body))
		var/list/surfaces = list(carrier.mess_splats)
		for(var/alist/slots as anything in list(carrier.part_mess_splats, carrier.part_splats, carrier.underclothes_splats))
			for(var/key, splats in slots)
				surfaces += list(splats)
		for(var/list/splats as anything in surfaces)
			for(var/datum/dirt_splat/splat as anything in splats)
				. += splat.last_serial

/// Gives a test human bare breasts of a size, built from DNA as a real character's.
/datum/unit_test/dirt_test/proc/make_breasts(mob/living/carbon/human/owner, size)
	RETURN_TYPE(/obj/item/organ/genital/breasts)
	return make_genital(owner, /obj/item/organ/genital/breasts, ORGAN_SLOT_BREASTS, /datum/sprite_accessory/genital/breasts/pair::name, list("breasts_size" = size, "breasts_uses_skincolor" = FALSE, "breasts_uses_skintones" = FALSE, "breasts_lactation" = FALSE))

/// Gives a test human a bare butt, built from DNA as a real character's.
/datum/unit_test/dirt_test/proc/make_butt(mob/living/carbon/human/owner)
	RETURN_TYPE(/obj/item/organ/genital/butt)
	return make_genital(owner, /obj/item/organ/genital/butt, ORGAN_SLOT_BUTT, /datum/sprite_accessory/genital/butt/pair::name, list("butt_size" = 6, "butt_uses_skincolor" = FALSE, "butt_uses_skintones" = FALSE))

/**
 * Gives a test human a bare genital built from DNA as a real character's, hidden only by clothes.
 *
 * Arguments:
 * - slot: Its ORGAN_SLOT_* define.
 * - features: The DNA features it's built from.
 */
/datum/unit_test/dirt_test/proc/make_genital(mob/living/carbon/human/owner, organ_type, slot, accessory_name, list/features)
	RETURN_TYPE(/obj/item/organ/genital)
	for(var/feature, value in features)
		owner.dna.features[feature] = value
	owner.dna.mutant_bodyparts[slot] = build_mutant_part(accessory_name, list("#FCCCB3"))
	var/obj/item/organ/genital/part = allocate(organ_type, owner.loc)
	part.build_from_dna(owner.dna, slot)
	var/datum/bodypart_overlay/mutant/genital/overlay = part.bodypart_overlay
	if(!overlay.set_appearance_from_dna(owner.dna) || !part.Insert(owner, special = TRUE))
		return null
	owner.underwear = "Nude"
	owner.undershirt = "Nude"
	owner.bra = "Nude"
	owner.underwear_visibility = NONE
	part.visibility_preference = GENITAL_HIDDEN_BY_CLOTHES
	owner.update_body()
	return part

/**
 * Returns a body's carrier of dirt, made if it has none, with its dirtier side set to the right. General deposits on
 * the body and on what it wears then draw the same pixels on every run.
 */
/datum/unit_test/dirt_test/proc/right_sided(mob/living/carbon/human/body)
	RETURN_TYPE(/datum/component/dirtiness)
	var/datum/component/dirtiness/own = body.LoadComponent(/datum/component/dirtiness)
	own.side = 1
	return own

/**
 * Puts general dirt on a person as dirt_land() does, with a set variant for any deposit it starts
 * (dirt_test_seed_variant()).
 *
 * Arguments:
 * - variant: 0 to DIRT_VARIANTS - 1.
 */
/datum/unit_test/dirt_test/proc/dirt_land_variant(mob/living/carbon/human/target, cause, material, level, variant, colour)
	var/restore = dirt_test_seed_variant(variant)
	. = dirt_land(target, cause, material, level, colour)
	rand_seed(restore)

/**
 * Puts a mess on a person as a shot at a zone does (dirt_mess_place()), with a set variant for the splat it starts
 * (dirt_test_seed_variant()). It fails the test if the shot starts no splat of that variant.
 *
 * Arguments:
 * - variant: 0 to DIRT_VARIANTS - 1.
 */
/datum/unit_test/dirt_test/proc/dirt_mess_place_variant(mob/living/carbon/human/target, zone, levels, variant)
	RETURN_TYPE(/datum/dirt_splat)
	var/restore = dirt_test_seed_variant(variant, surface_splats(target, zone), zone)
	var/datum/dirt_splat/placed = dirt_mess_place(target, zone, levels)
	rand_seed(restore)
	TEST_ASSERT_EQUAL(placed?.variant, variant, "A shot at [zone] started no splat of variant [variant].")
	return placed

/**
 * Puts a mess on a carrier as /datum/component/dirtiness/proc/add_mess() does, with a set variant for the splat it
 * starts (dirt_test_seed_variant()). It fails the test if it starts no splat of that variant.
 *
 * Arguments:
 * - variant: 0 to DIRT_VARIANTS - 1.
 */
/datum/unit_test/dirt_test/proc/add_mess_variant(datum/component/dirtiness/carrier, zone, organ_slot, levels, variant)
	RETURN_TYPE(/datum/dirt_splat)
	var/restore = dirt_test_seed_variant(variant, organ_slot ? carrier.part_mess_splats[organ_slot] : carrier.mess_splats, zone)
	var/datum/dirt_splat/added = carrier.add_mess(zone, organ_slot, levels)
	rand_seed(restore)
	TEST_ASSERT_EQUAL(added?.variant, variant, "A mess on [zone] started no splat of variant [variant].")
	return added

/**
 * Puts a mess on the underclothes a person wears in a slot, as /datum/component/dirtiness/proc/add_underclothes_mess()
 * does, with a set variant for the splat it starts (dirt_test_seed_variant()). It fails the test if it starts no splat
 * of that variant. Returns null for no carrier.
 *
 * Arguments:
 * - variant: 0 to DIRT_VARIANTS - 1.
 */
/datum/unit_test/dirt_test/proc/add_underclothes_mess_variant(datum/component/dirtiness/carrier, zone, piece, levels, variant)
	RETURN_TYPE(/datum/dirt_splat)
	if(!carrier)
		return null
	var/datum/sprite_accessory/accessory = dirt_underclothes_worn(carrier.parent)[piece]
	var/restore = dirt_test_seed_variant(variant, carrier.underclothes_splats?[dirt_underclothes_key(piece, accessory?.name)], zone)
	var/datum/dirt_splat/added = carrier.add_underclothes_mess(zone, piece, levels)
	rand_seed(restore)
	TEST_ASSERT_EQUAL(added?.variant, variant, "A mess on [zone] of the [piece] started no splat of variant [variant].")
	return added

/// Returns the splats of the surface that a shot at a zone hits (dirt_mess_surface()), as dirt_fresh_variant() reads
/// them.
/datum/unit_test/dirt_test/proc/surface_splats(mob/living/carbon/human/target, zone)
	RETURN_TYPE(/list)
	if(zone == DIRT_ZONE_COCK)
		var/datum/component/dirtiness/own = target.GetComponent(/datum/component/dirtiness)
		return own?.part_mess_splats?[ORGAN_SLOT_PENIS]
	var/list/surface = dirt_mess_surface(target, zone)
	var/datum/component/dirtiness/carrier = surface[1]
	var/piece = surface[2]
	if(!piece)
		return carrier.mess_splats
	var/datum/sprite_accessory/accessory = dirt_underclothes_worn(target)[piece]
	return carrier.underclothes_splats?[dirt_underclothes_key(piece, accessory.name)]

/**
 * Makes a test human a taur and returns its taur body.
 *
 * Arguments:
 * - rider: The human. It must not have a taur body yet.
 * - kind: The taur's sprite accessory type. By default it's the horse, the kind the parity corpus uses.
 */
/datum/unit_test/dirt_test/proc/give_taur(mob/living/carbon/human/rider, datum/sprite_accessory/taur/kind = /datum/sprite_accessory/taur/horse)
	RETURN_TYPE(/obj/item/organ/taur_body)
	rider.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part(initial(kind.name), list("#8A6A4A", "#D8C8B0", "#3A2A20"))
	var/body_type = initial(kind.organ_type)
	var/obj/item/organ/taur_body/taur_body = new body_type
	if(!taur_body.Insert(rider, special = TRUE, movement_flags = DELETE_IF_REPLACED))
		qdel(taur_body)
		return null
	rider.update_body(is_creating = TRUE)
	return taur_body

/**
 * Returns the images a body's hair layer draws its dirt in: those holding a baked image of dirt. That's one of `bakes`,
 * or if none are given, one from any masks SSdirt keeps or the body's drawn parts and hair draw. Only the hair's dirt
 * containers hold one, and the hair's own images never do. The search looks a few levels down into the layer's images.
 * That's because apply_overlay() nests the sprites sharing a layer in one holder, and its emissive blockers in a group
 * (prepare_bodypart_overlays()). The groups are left out, because the dirt's blockers in them are drawn from the same
 * bakes.
 *
 * Arguments:
 * - bakes: The baked icons to look for, or null for every one held.
 */
/datum/unit_test/dirt_test/proc/hair_containers(mob/living/carbon/human/body, list/bakes)
	RETURN_TYPE(/list)
	. = list()
	if(isnull(bakes))
		bakes = list()
		var/list/held_masks = list()
		for(var/key, kept in SSdirt.masks.entries)
			held_masks += kept
		var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
		for(var/slot, drawing in own?.part_drawings)
			var/datum/dirt_drawing/drawn_parts = drawing
			held_masks += drawn_parts.masks
		for(var/datum/dirt_masks/masks in held_masks)
			bakes += masks.baked
			for(var/list/baked_icons as anything in list(masks.baked_by_limb, masks.baked_by_layer, masks.baked_by_part))
				for(var/key, baked in baked_icons)
					bakes += baked
	var/list/looked_at = body.overlays_standing[HAIR_LAYER]
	if(!looked_at)
		return
	looked_at = standing_images(looked_at)
	for(var/depth in 1 to 3)
		var/list/nested = list()
		for(var/image/drawn as anything in looked_at)
			if(PLANE_TO_TRUE(drawn.plane) == EMISSIVE_PLANE)
				continue
			var/holds_bake = FALSE
			for(var/image/held as anything in drawn.overlays)
				if(held.icon && (held.icon in bakes))
					holds_bake = TRUE
				else
					nested += held
			if(holds_bake)
				. += drawn
		looked_at = nested

/**
 * Returns whether a limb's cached images hold a container drawing a baked icon.
 *
 * Arguments:
 * - zone: The limb's body zone.
 */
/datum/unit_test/dirt_test/proc/holds_baked(mob/living/carbon/human/body, zone, baked)
	for(var/image/container as anything in limb_containers(body, zone))
		for(var/image/held as anything in container.overlays)
			if(held.icon == baked)
				return TRUE
	return FALSE

/**
 * Returns the images among some that draw BLEND_MULTIPLY.
 *
 * Arguments:
 * - images: The images, or null.
 */
/datum/unit_test/dirt_test/proc/multiply_images(list/images)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/drawn as anything in images)
		if(drawn.blend_mode == BLEND_MULTIPLY)
			. += drawn

/**
 * Returns the general deposits among splats, oldest first.
 *
 * Arguments:
 * - splats: The splats, or null.
 */
/datum/unit_test/dirt_test/proc/deposits_in(list/splats)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/dirt_splat/splat as anything in splats)
		if(splat.cause)
			. += splat

/**
 * Returns where a worn wrapper is drawn and where its inset images go in it, as one line of text: the offsets of the
 * rider's 32x32 dirt and of what's drawn on the 64x32 taur canvas, the pools or a taur suit's hem band.
 *
 * Arguments:
 * - standing: The wrapper, or null.
 */
/datum/unit_test/dirt_test/proc/describe_insets(mutable_appearance/standing)
	var/list/offsets = list("rider" = list(), "pools" = list())
	for(var/image/child as anything in standing?.overlays)
		if(child.blend_mode != BLEND_INSET_OVERLAY)
			continue
		var/list/kind_offsets = offsets[get_icon_dimensions(child.icon)["width"] == DIRT_TAUR_WIDTH ? "pools" : "rider"]
		kind_offsets |= "[child.pixel_w],[child.pixel_z]"
	return "wrapper [standing?.pixel_w],[standing?.pixel_z]; rider [jointext(offsets["rider"], " ")]; pools [jointext(offsets["pools"], " ")]"

/**
 * Returns the row, from the top, that a height map shows on a row of a sprite. The map tells each row which row it
 * shows by its green channel down its middle, rounded to the nearest row. 128 shows its own row, 0 the row a size
 * above, and 255 the row a size below.
 *
 * Arguments:
 * - map: The map's icon.
 * - size: Its displacement filter's size.
 * - row: The row, from the top.
 */
/datum/unit_test/dirt_test/proc/row_shown(icon/map, size, row)
	var/colour = map.GetPixel(floor(map.Width() / 2), ICON_SIZE_Y - row)
	return colour ? floor(row + (rgb2num(colour)[2] - 128) / 127 * size + 0.5) : row

/**
 * Returns where a worn slot draws its blood stain, an inset image of a baked icon and sweat's multiplier in its worn
 * wrapper, as list(the stain's place, the image's, the multiplier's). Each is 0 if it isn't drawn.
 *
 * Arguments:
 * - body: The wearer.
 * - layer: The slot's overlays_standing index.
 * - baked: The baked icon, or null.
 */
/datum/unit_test/dirt_test/proc/worn_places(mob/living/carbon/human/body, layer, baked)
	RETURN_TYPE(/list)
	. = list(0, 0, 0)
	var/image/root = bulge_drawn_root(body.overlays_standing[layer])
	var/position = 0
	for(var/image/child as anything in root?.overlays)
		position++
		if(child.icon == 'icons/effects/blood.dmi')
			.[1] = position
		else if(baked && child.icon == baked && child.blend_mode == BLEND_INSET_OVERLAY)
			.[2] = position
		else if(child.blend_mode == BLEND_MULTIPLY)
			.[3] = position

/**
 * Returns the pixels a baked icon draws facing one way, as indexes on its canvas, row by row from the top.
 *
 * Arguments:
 * - baked: The baked icon, as /datum/dirt_masks holds it, or null.
 * - width, height: Its canvas's size.
 */
/datum/unit_test/dirt_test/proc/mask_pixels(baked, direction, width = ICON_SIZE_X, height = ICON_SIZE_Y)
	RETURN_TYPE(/list)
	. = list()
	if(!baked)
		return
	var/icon/sprite = icon(baked)
	for(var/index in 1 to width * height)
		var/row = floor((index - 1) / width)
		if(sprite.GetPixel(index - row * width, height - row, null, direction))
			. += index

/**
 * Returns the images among a limb's cached images that draw no sprite of their own but hold others: dirt's
 * containers.
 *
 * Arguments:
 * - zone: The limb's body zone.
 */
/datum/unit_test/dirt_test/proc/limb_containers(mob/living/carbon/human/body, zone)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/drawn as anything in body.drawn_limb_icons(zone))
		if(!drawn.icon && length(drawn.overlays))
			. += drawn

/**
 * Gives a test human drawn parts built from DNA as a real character's, all in the same colours, and draws it again.
 *
 * Arguments:
 * - accessories: list(FEATURE_* define = its sprite accessory's name), set in that order.
 */
/datum/unit_test/dirt_test/proc/give_parts(mob/living/carbon/human/body, list/accessories, list/colours)
	for(var/feature, accessory_name in accessories)
		body.dna.mutant_bodyparts[feature] = build_mutant_part(accessory_name, colours)
	body.dna.species.regenerate_organs(body)
	body.update_body(is_creating = TRUE)

/**
 * Returns whether a baked pixel is a colour, its alpha aside.
 *
 * Arguments:
 * - pixel: The pixel, as GetPixel() reads it.
 * - colour: The colour, "#RRGGBB".
 */
/datum/unit_test/dirt_test/proc/same_rgb(pixel, colour)
	var/list/channels = rgb2num(pixel)
	var/list/wanted = rgb2num(colour)
	return channels[1] == wanted[1] && channels[2] == wanted[2] && channels[3] == wanted[3]
