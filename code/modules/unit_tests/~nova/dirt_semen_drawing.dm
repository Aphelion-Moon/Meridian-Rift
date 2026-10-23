#define DIRT_SEMEN_CORPUS "code/modules/unit_tests/~nova/dirt_semen_corpus.json"

/**
 * The game's limbs feed the dirt template the sprites the corpus names, so the parity manifest's surfaces are the ones the
 * game builds: a consistent human gives the corpus's human_m sources, and the same body at the Muscular size gives
 * human_muscular's, its size sheet included.
 */
/datum/unit_test/dirt_zone_sources

/datum/unit_test/dirt_zone_sources/Run()
	var/list/corpus = json_decode(file2text(DIRT_SEMEN_CORPUS) || "{}")
	var/list/templates = corpus["templates"]
	TEST_ASSERT(length(templates), "[DIRT_SEMEN_CORPUS] is missing or has no templates.")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.undershirt = "Nude"
	body.underwear = "Nude"
	body.bra = "Nude"
	body.socks = "Nude"
	TEST_ASSERT_EQUAL(describe_sources(dirt_zone_sources(body)), describe_sources(dirt_parity_zone_sources(templates["human_m"])), "A consistent human's sprites aren't the corpus's human_m.")
	body.dna.features[FEATURE_MUSCLE_SIZE] = MUSCLE_SIZE_MUSCULAR
	body.update_fitness_limbs()
	TEST_ASSERT_EQUAL(describe_sources(dirt_zone_sources(body)), describe_sources(dirt_parity_zone_sources(templates["human_muscular"])), "A Muscular human's sprites aren't the corpus's human_muscular.")

/**
 * Returns zone sources as one line of text, zones in draw order, to compare and to read in a failure.
 *
 * Arguments:
 * - zone_sources: Zone sources, as dirt_zone_sources() returns them.
 */
/datum/unit_test/dirt_zone_sources/proc/describe_sources(list/zone_sources)
	var/list/parts = list()
	for(var/zone in dirt_zone_draw_order())
		var/list/source = zone_sources[zone]
		parts += source ? "[zone] [source[1]] [source[2]]" : "[zone] none"
	var/list/eyes = zone_sources["eyes"]
	parts += eyes ? "eyes [eyes[1]] [eyes[2]] [eyes[3]]" : "eyes none"
	parts += "human head [zone_sources["human_head"] ? "yes" : "no"]"
	return jointext(parts, ", ")

/// A body that notes what SSdirt draws again on it.
/mob/living/carbon/human/consistent/dirt_redraw_fixture
	/// Every DIRT_REDRAW_* flag redraw_dirt() was called with.
	var/redrawn_flags = NONE

/// Notes the flags, then draws as any body does.
/mob/living/carbon/human/consistent/dirt_redraw_fixture/redraw_dirt(redraw_flags)
	redrawn_flags |= redraw_flags
	return ..()

/**
 * SSdirt makes semen masks in the background and caches them: the first ask queues them, finish_all() makes them, and the
 * body that asked is drawn again. They're made from the splats as they were when asked for, whatever happens to them
 * meanwhile. Skin's masks are clipped to each limb and cloth's cover the canvas, and both match the parity manifest's
 * cases, one splat or two merged, the second drawn over a first cached from an earlier ask. A request whose limb names a
 * missing state is dropped, cached as failed, and never queued again, and the queue goes on past it.
 */
/datum/unit_test/dirt_mask_queue

/datum/unit_test/dirt_mask_queue/Run()
#ifndef DIRT_MASKS_DEFERRED
	TEST_NOTICE(src, "Dirt masks are made as they're asked for: DIRT_MASKS_DEFERRED is off.")
#else
	// whatever earlier tests left queued is made first, so this test's asks are its own
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/dirt_redraw_fixture/body = allocate(/mob/living/carbon/human/consistent/dirt_redraw_fixture)
	var/datum/dirt_splat/chest_splat = new(DIRT_ZONE_CHEST, 1, 0, SSdirt.next_serial())
	var/list/chest_splats = list(chest_splat)
	var/datum/dirt_mask_request/chest = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_SKIN, chest_splats)
	var/chest_key = chest.mask_key()
	SSdirt.masks -= chest_key
	TEST_ASSERT_NULL(SSdirt.masks_for(chest, body, DIRT_REDRAW_BODY), "Semen masks were made as they were asked for, rather than queued.")
	// the body's splat levels up and another lands while the masks wait: they're still made from what was asked for
	chest_splat.level = 3
	chest_splats += new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 7, SSdirt.next_serial())
	SSdirt.finish_all()
	TEST_ASSERT(body.redrawn_flags & DIRT_REDRAW_BODY, "The body that asked for the masks wasn't drawn again once they were made.")
	var/datum/dirt_masks/masks = SSdirt.masks[chest_key]
	TEST_ASSERT(istype(masks), "finish_all() didn't make the queued masks.")
	TEST_ASSERT_EQUAL(describe_limbs(masks), BODY_ZONE_CHEST, "A chest splat's masks lie on other limbs than the chest.")
	// skin-human_m-chest-1-0's grid
	TEST_ASSERT_EQUAL(describe_roles(masks.roles_by_limb[BODY_ZONE_CHEST]), "haze 0 0 0 0, film 6 0 2 1, body 3 0 1 1, core 0 0 0 0, fleck 0 0 0 0, glint 1 0 1 0", "The chest's masks aren't the parity manifest's skin-human_m-chest-1-0.")
	var/datum/dirt_mask_request/cloth = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_CLOTH, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 0, SSdirt.next_serial())))
	SSdirt.masks -= cloth.mask_key()
	SSdirt.masks_for(cloth, body, DIRT_REDRAW_UNIFORM)
	SSdirt.finish_all()
	masks = SSdirt.masks_for(cloth, body, DIRT_REDRAW_UNIFORM)
	TEST_ASSERT(istype(masks), "finish_all() didn't make the queued cloth masks.")
	// cloth-human_m-chest-1-0's grid, on the whole canvas: cloth draws its rim a role lighter, film's half covered as haze
	TEST_ASSERT_EQUAL(describe_roles(masks.roles), "haze 0 0 2 1, film 6 0 1 1, body 3 0 0 0, core 0 0 0 0, fleck 0 0 0 0, glint 1 0 1 0", "The cloth masks aren't the parity manifest's cloth-human_m-chest-1-0.")

	var/alist/missing_sources = dirt_zone_sources(body)
	var/list/chest_source = missing_sources[BODY_ZONE_CHEST]
	missing_sources[BODY_ZONE_CHEST] = list(chest_source[1], "dirt_missing_state")
	var/datum/dirt_mask_request/missing = new(DIRT_MASKS_BODY, missing_sources, DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 0, SSdirt.next_serial())))
	TEST_ASSERT_NULL(SSdirt.masks_for(missing, body, DIRT_REDRAW_BODY), "Masks for a missing state were made as they were asked for.")
	SSdirt.finish_all()
	var/failed = SSdirt.masks[missing.mask_key()]
	TEST_ASSERT(!isnull(failed) && !failed, "Masks for a missing state weren't cached as failed: [failed || "nothing is cached"].")
	TEST_ASSERT_NULL(SSdirt.masks_for(missing, body, DIRT_REDRAW_BODY), "Failed masks were drawn.")
	TEST_ASSERT(!length(SSdirt.queue), "Failed masks asked for again queued [length(SSdirt.queue)] jobs.")

	var/datum/dirt_mask_request/pair = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 0, SSdirt.next_serial()), new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 7, SSdirt.next_serial())))
	SSdirt.masks -= pair.mask_key()
	TEST_ASSERT_NULL(SSdirt.masks_for(pair, body, DIRT_REDRAW_BODY), "Two splats' masks were made as they were asked for.")
	SSdirt.finish_all()
	masks = SSdirt.masks_for(pair, body, DIRT_REDRAW_BODY)
	TEST_ASSERT(istype(masks), "Masks asked for after a failed request weren't made.")
	// skin-human_m-chest-1-0+chest-1-7's grid: the second splat leaves out its pieces beside the first's semen
	TEST_ASSERT_EQUAL(describe_roles(masks.roles_by_limb[BODY_ZONE_CHEST]), "haze 0 0 0 0, film 6 0 2 1, body 5 0 1 1, core 0 0 0 0, fleck 0 0 0 0, glint 1 0 1 0", "Two chest splats' masks aren't the parity manifest's skin-human_m-chest-1-0+chest-1-7.")
#endif

/**
 * Returns the zones a body's masks lie on, in draw order, joined by commas.
 *
 * Arguments:
 * - masks: A body's masks.
 */
/datum/unit_test/dirt_mask_queue/proc/describe_limbs(datum/dirt_masks/masks)
	var/list/zones = list()
	for(var/zone in dirt_zone_draw_order())
		if(masks.roles_by_limb[zone])
			zones += zone
	return jointext(zones, ", ")

/**
 * Returns how many pixels each role's mask covers facing south, north, east and west, as one line of text. Haze is the
 * film mask's half-covered pixels, film its fully covered ones.
 *
 * Arguments:
 * - roles: alist(DIRT_ROLE_* define = registered icon), as /datum/dirt_masks holds them.
 */
/datum/unit_test/dirt_mask_queue/proc/describe_roles(alist/roles)
	var/list/counts = list("haze" = list(0, 0, 0, 0), "film" = list(0, 0, 0, 0), "body" = list(0, 0, 0, 0), "core" = list(0, 0, 0, 0), "fleck" = list(0, 0, 0, 0), "glint" = list(0, 0, 0, 0))
	var/list/names = list("film" = DIRT_ROLE_FILM, "body" = DIRT_ROLE_BODY, "core" = DIRT_ROLE_CORE, "fleck" = DIRT_ROLE_FLECK, "glint" = DIRT_ROLE_GLINT)
	var/list/facings = list(SOUTH, NORTH, EAST, WEST)
	for(var/name, role in names)
		if(!roles?[role])
			continue
		var/icon/mask = icon(roles[role])
		for(var/facing_number in 1 to length(facings))
			for(var/icon_y in 1 to ICON_SIZE_Y)
				for(var/icon_x in 1 to ICON_SIZE_X)
					var/pixel = mask.GetPixel(icon_x, icon_y, null, facings[facing_number])
					if(!pixel)
						continue
					var/list/role_counts = (name == "film" && pixel == "#ffffff80") ? counts["haze"] : counts[name]
					role_counts[facing_number]++
	var/list/parts = list()
	for(var/name, numbers in counts)
		parts += "[name] [jointext(numbers, " ")]"
	return jointext(parts, ", ")

/**
 * Semen on bare skin draws through the limbs' own images: a landing gives each limb it reaches one container image at
 * DIRT_SKIN_LAYER, holding the role masks SSdirt makes, and the other limbs nothing. Washing takes it off, even while its
 * masks are still being made: they finish without bringing it back. Every zone at once adds one overlay per limb that
 * carries semen, the head, the chest and the legs, so four at most. A climax's load adds levels to the zone's newest
 * splat, and past the top one what's left starts another, still drawn in the limb's one container.
 */
/datum/unit_test/dirt_skin_semen

/datum/unit_test/dirt_skin_semen/Run()
	// whatever earlier tests left queued is made first
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.undershirt = "Nude"
	body.underwear = "Nude"
	body.bra = "Nude"
	body.socks = "Nude"
	body.update_body()
	TEST_ASSERT(dirt_semen_land(body, DIRT_ZONE_CHEST), "Semen aimed at a bare chest didn't land.")
	SSdirt.finish_all()
	var/list/chest_images = skin_images(body, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(length(chest_images), 1, "A chest splat's chest images hold [length(chest_images)] semen containers, not one.")
	var/image/container = chest_images[1]
	TEST_ASSERT(length(container.overlays), "The chest's semen container holds no role images.")
	for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		TEST_ASSERT(!length(skin_images(body, zone)), "A chest splat drew semen on the [zone].")
	body.wash(CLEAN_WASH)
	body.update_body_parts()
	TEST_ASSERT(!length(skin_images(body, BODY_ZONE_CHEST)), "Washing left semen drawn on the chest.")

	// washed while its masks are made: once they're done, they don't bring it back
	forget_masks(body, DIRT_ZONE_STOMACH)
	dirt_semen_land(body, DIRT_ZONE_STOMACH)
	TEST_ASSERT(length(SSdirt.queue), "A stomach splat's masks weren't queued, so washing can't be checked against them.")
	body.wash(CLEAN_WASH)
	SSdirt.finish_all()
	TEST_ASSERT(!length(skin_images(body, BODY_ZONE_CHEST)), "Masks finished after a wash drew the washed semen.")

	var/clean_overlays = length(body.overlays)
	for(var/zone in dirt_semen_zones())
		dirt_semen_land(body, zone)
	SSdirt.finish_all()
	var/added = length(body.overlays) - clean_overlays
	TEST_ASSERT(added > 0 && added <= 4, "Semen on every zone added [added] overlays to the body, not one to four.")

	// a climax's load adds levels to the zone's newest splat, and past the top what's left starts another splat
	body.wash(CLEAN_WASH)
	dirt_semen_land(body, DIRT_ZONE_CHEST, levels = 2)
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(describe_levels(carrier, DIRT_ZONE_CHEST), "2", "A heavy load on a bare chest didn't start a level 2 splat.")
	dirt_semen_land(body, DIRT_ZONE_CHEST)
	dirt_semen_land(body, DIRT_ZONE_CHEST, levels = 2)
	TEST_ASSERT_EQUAL(describe_levels(carrier, DIRT_ZONE_CHEST), "[DIRT_SEMEN_MAX_LEVEL] 1", "Two levels on a level 3 chest splat didn't top it and start a level 1 splat.")
	var/datum/dirt_splat/topped = carrier.semen_splats[1]
	var/datum/dirt_splat/started = carrier.semen_splats[2]
	TEST_ASSERT_NOTEQUAL(started.variant, topped.variant, "The splat a load started past the top took the variant already on the chest.")
	dirt_semen_land(body, DIRT_ZONE_STOMACH, levels = dirt_semen_load_levels(DIRT_SEMEN_LOAD_HUGE))
	TEST_ASSERT_EQUAL(describe_levels(carrier, DIRT_ZONE_STOMACH), "[DIRT_SEMEN_MAX_LEVEL]", "A huge load didn't go straight to the top level.")
	SSdirt.finish_all()
	TEST_ASSERT_EQUAL(length(skin_images(body, BODY_ZONE_CHEST)), 1, "Top-level and level 1 splats drew [length(skin_images(body, BODY_ZONE_CHEST))] semen containers on the chest, not one.")

/**
 * Returns the levels of a carrier's skin splats on one zone, oldest first, joined by spaces.
 *
 * Arguments:
 * - carrier: The carrier.
 * - zone: A DIRT_ZONE_* define.
 */
/datum/unit_test/dirt_skin_semen/proc/describe_levels(datum/component/dirtiness/carrier, zone)
	var/list/levels = list()
	for(var/datum/dirt_splat/splat as anything in carrier.semen_splats)
		if(splat.zone == zone)
			levels += splat.level
	return jointext(levels, " ")

/**
 * Returns the semen containers in a limb's cached images: the images at DIRT_SKIN_LAYER.
 *
 * Arguments:
 * - body: The body.
 * - zone: The limb's body zone.
 */
/datum/unit_test/dirt_skin_semen/proc/skin_images(mob/living/carbon/human/body, zone)
	var/list/found = list()
	for(var/image/drawn as anything in body.limb_icon_cache[body.icon_render_keys[zone]])
		if(drawn.layer == -DIRT_SKIN_LAYER)
			found += drawn
	return found

/**
 * Drops any cached masks a level 1 splat on a zone could ask for on this body, so the next one is made afresh.
 *
 * Arguments:
 * - body: The body.
 * - zone: A DIRT_ZONE_* define.
 */
/datum/unit_test/dirt_skin_semen/proc/forget_masks(mob/living/carbon/human/body, zone)
	for(var/variant in 0 to DIRT_SEMEN_VARIANTS - 1)
		var/datum/dirt_mask_request/request = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(zone, 1, variant, 0)))
		SSdirt.masks -= request.mask_key()

#undef DIRT_SEMEN_CORPUS
