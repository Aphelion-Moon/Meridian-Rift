// compiled in, since CI's test world is deployed without code/
#define DIRT_CORPUS 'code/modules/unit_tests/~nova/dirt_corpus.json'

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

/**
 * The game's limbs feed the dirt template the sprites the corpus names, so the parity manifest's surfaces are the ones
 * the game builds: a consistent human gives the corpus's human_m sources, and the same body at the Muscular size gives
 * human_muscular's, its size sheet included.
 */
/datum/unit_test/dirt_zone_sources

/datum/unit_test/dirt_zone_sources/Run()
	var/list/corpus = json_decode(file2text(DIRT_CORPUS) || "{}")
	var/list/templates = corpus["templates"]
	TEST_ASSERT(length(templates), "[DIRT_CORPUS] has no templates.")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
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
 * SSdirt makes mess masks in the background and caches them: the first ask queues them, finish_all() makes them, and
 * the body that asked is drawn again. The masks are made from the splats as they were when asked for, whatever happens
 * to the splats meanwhile. Skin's masks are clipped to each limb, and cloth's are made too. If a request's limb names a
 * missing state, the request is dropped, cached as failed and never queued again. The queue goes on past it. Masks
 * asked for on more body types than the template cache holds are all made, though templates drop while they wait.
 */
/datum/unit_test/dirt_mask_queue
	parent_type = /datum/unit_test/dirt_genital_test
	// about 2 s: it builds templates for more body types than the template cache holds, twice over
	priority = TEST_LONGER
	/// SSdirt.masks.limit while the mask-queue pin runs on a smaller cache, until restore_mask_limit().
	var/mask_limit

/// Puts the mask cache back at its own limit if the pin stopped on its smaller one.
/datum/unit_test/dirt_mask_queue/Destroy()
	restore_mask_limit()
	return ..()

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
	SSdirt.masks.forget(chest_key)
	TEST_ASSERT_NULL(SSdirt.masks_for(chest, body, DIRT_REDRAW_BODY), "Mess masks were made as they were asked for, rather than queued.")
	// the body's splat levels up and another lands while the masks wait: they're still made from what was asked for
	chest_splat.level = 3
	chest_splats += new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 7, SSdirt.next_serial())
	SSdirt.finish_all()
	TEST_ASSERT(body.redrawn_flags & DIRT_REDRAW_BODY, "The body that asked for the masks wasn't drawn again once they were made.")
	var/datum/dirt_masks/masks = SSdirt.masks.fetch(chest_key)
	TEST_ASSERT(istype(masks), "finish_all() didn't make the queued masks.")
	TEST_ASSERT(length(masks.baked_by_limb) == 1 && masks.baked_by_limb[BODY_ZONE_CHEST], "A chest splat's masks lie on other limbs than the chest.")
	// the chest's runs from a fresh request, with the splats as they were asked for
	var/datum/dirt_mask_request/as_asked = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 0, 0)))
	var/alist/chest_runs = baked_runs(as_asked, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(masks.limb_keys[BODY_ZONE_CHEST], dirt_runs_key(chest_runs), "The queued chest masks aren't baked from the splats as they were asked for.")
	// a solid film pixel takes the film's tint: #F1EEE6 at 0.42, alpha 107
	var/alist/mess_runs = chest_runs[DIRT_MATERIAL_MESS]
	var/alist/film_runs = mess_runs[DIRT_ROLE_FILM]
	var/list/film_run = film_runs[SOUTH][1]
	var/icon/chest_baked = icon(masks.baked_by_limb[BODY_ZONE_CHEST])
	TEST_ASSERT_EQUAL(chest_baked.GetPixel(film_run[2], film_run[1], null, SOUTH), "#f1eee66b", "A solid film pixel isn't baked in the film's tint.")
	var/datum/dirt_mask_request/cloth = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_CLOTH, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 0, SSdirt.next_serial())))
	SSdirt.masks.forget(cloth.mask_key())
	SSdirt.masks_for(cloth, body, DIRT_REDRAW_UNIFORM)
	SSdirt.finish_all()
	masks = SSdirt.masks_for(cloth, body, DIRT_REDRAW_UNIFORM)
	TEST_ASSERT(istype(masks) && masks.baked, "finish_all() didn't make the queued cloth masks.")

	var/alist/missing_sources = dirt_zone_sources(body)
	var/list/chest_source = missing_sources[BODY_ZONE_CHEST]
	missing_sources[BODY_ZONE_CHEST] = list(chest_source[1], "dirt_missing_state")
	var/datum/dirt_mask_request/missing = new(DIRT_MASKS_BODY, missing_sources, DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 0, SSdirt.next_serial())))
	TEST_ASSERT_NULL(SSdirt.masks_for(missing, body, DIRT_REDRAW_BODY), "Masks for a missing state were made as they were asked for.")
	SSdirt.finish_all()
	var/failed = SSdirt.masks.fetch(missing.mask_key())
	TEST_ASSERT(!isnull(failed) && !failed, "Masks for a missing state weren't cached as failed: [failed || "nothing is cached"].")
	TEST_ASSERT_NULL(SSdirt.masks_for(missing, body, DIRT_REDRAW_BODY), "Failed masks were drawn.")
	TEST_ASSERT(!length(SSdirt.queue), "Failed masks asked for again queued [length(SSdirt.queue)] jobs.")

	var/datum/dirt_mask_request/pair = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 0, SSdirt.next_serial()), new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, 7, SSdirt.next_serial())))
	SSdirt.masks.forget(pair.mask_key())
	TEST_ASSERT_NULL(SSdirt.masks_for(pair, body, DIRT_REDRAW_BODY), "Two splats' masks were made as they were asked for.")
	SSdirt.finish_all()
	masks = SSdirt.masks_for(pair, body, DIRT_REDRAW_BODY)
	TEST_ASSERT(istype(masks), "Masks asked for after a failed request weren't made.")

	// more masks asked for than the mask cache holds while they wait: the first, asked for again by a draw, waits for its
	// job rather than queueing another. On a cache of four, so the asks are few; emptied first, so the keys it holds fit
	SSdirt.masks.clear()
	mask_limit = SSdirt.masks.limit
	SSdirt.masks.limit = 4
	var/list/zones = dirt_mess_zones()
	var/datum/dirt_mask_request/first_waiting
	for(var/request_number in 1 to SSdirt.masks.limit + 1)
		var/zone = zones[(request_number - 1) % length(zones) + 1]
		var/variant = floor((request_number - 1) / length(zones)) % DIRT_VARIANTS
		var/level = floor((request_number - 1) / (length(zones) * DIRT_VARIANTS)) % DIRT_MESS_MAX_LEVEL + 1
		var/datum/dirt_mask_request/waiting_request = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_CLOTH, list(new /datum/dirt_splat(zone, level, variant, SSdirt.next_serial())))
		SSdirt.masks.forget(waiting_request.mask_key())
		SSdirt.masks_for(waiting_request, null, NONE)
		first_waiting ||= waiting_request
	var/queued = length(SSdirt.queue)
	var/datum/dirt_drawing/drawing = new
	drawing.start(first_waiting)
	drawing.current(null, NONE)
	TEST_ASSERT_EQUAL(length(SSdirt.queue), queued, "Masks still waiting were queued again once [SSdirt.masks.limit] newer ones were asked for.")
	SSdirt.finish_all()
	restore_mask_limit()

	// more body types than the template cache holds, asked for in turn twice: the second round's templates drop ones
	// queued jobs were given, which they draw on all the same
	var/alist/body_types = template_bodies(SSdirt.templates.limit + 2)
	TEST_ASSERT(length(body_types) > SSdirt.templates.limit, "Only [length(body_types)] body types for a template cache of [SSdirt.templates.limit].")
	var/list/asked = list()
	for(var/round_number in 1 to 2)
		for(var/template_key, sources in body_types)
			var/datum/dirt_mask_request/request = new(DIRT_MASKS_BODY, sources, DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, round_number, SSdirt.next_serial())))
			var/request_key = request.mask_key()
			SSdirt.masks.forget(request_key)
			SSdirt.masks_for(request, null, NONE)
			asked[request_key] = template_key
		SSdirt.finish_all()
	// a template the cache drops while a queued job holds it is taken back from that job, not built a second time
	var/datum/dirt_template/held
	var/list/held_sources
	for(var/template_key, sources in body_types)
		held = SSdirt.templates.fetch(template_key)
		if(istype(held))
			held_sources = sources
			break
	TEST_ASSERT(istype(held), "No body type's template is cached after the asks, so one a job holds can't be checked.")
	for(var/variant in 3 to 4)
		var/datum/dirt_mask_request/request = new(DIRT_MASKS_BODY, held_sources, DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 1, variant, SSdirt.next_serial())))
		SSdirt.masks.forget(request.mask_key())
		SSdirt.masks_for(request, null, NONE)
		asked[request.mask_key()] = held.key
		SSdirt.templates.clear()
	TEST_ASSERT(!SSdirt.template_jobs[held.key], "A template a queued job holds was queued to be built again once the template cache dropped it.")
	SSdirt.finish_all()
	for(var/request_key, template_key in asked)
		var/made = SSdirt.masks.fetch(request_key)
		TEST_ASSERT(istype(made, /datum/dirt_masks), "Masks on template [template_key] weren't made with more body types than the template cache holds: [isnull(made) ? "nothing is cached" : (made || "cached as failed")].")
#endif

/**
 * Puts SSdirt.masks back at its own limit after the mask-queue pin, emptied, as its order was kept for the smaller one.
 */
/datum/unit_test/dirt_mask_queue/proc/restore_mask_limit()
	if(!mask_limit)
		return
	SSdirt.masks.limit = mask_limit
	mask_limit = null
	SSdirt.masks.clear()

/**
 * Returns the sprites of bodies drawn from different templates, one for each: alist(template key = dirt_zone_sources()).
 *
 * Arguments:
 * - wanted: How many.
 */
/datum/unit_test/dirt_mask_queue/proc/template_bodies(wanted)
	RETURN_TYPE(/alist)
	var/static/list/species_types = list(/datum/species/human, /datum/species/lizard, /datum/species/moth, /datum/species/mammal, /datum/species/akula, /datum/species/skrell, /datum/species/vulpkanin, /datum/species/tajaran, /datum/species/unathi, /datum/species/aquatic, /datum/species/insect, /datum/species/humanoid)
	var/alist/bodies = alist()
	for(var/species_type in species_types)
		for(var/physique in list(MALE, FEMALE))
			if(length(bodies) >= wanted)
				return bodies
			var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
			body.physique = physique
			if(species_type != /datum/species/human)
				body.set_species(species_type)
			body.update_body(is_creating = TRUE)
			var/list/sources = dirt_zone_sources(body)
			bodies[dirt_template_key(sources)] = sources
	return bodies

/**
 * Returns the runs a skin request's masks bake a limb from (/datum/dirt_mask_job/proc/limb_runs()). A job of its own
 * makes the masks from start to end (made_job()). Returns null if that job made no masks.
 *
 * Arguments:
 * - request: The request.
 * - zone: The limb's body zone.
 */
/datum/unit_test/dirt_mask_queue/proc/baked_runs(datum/dirt_mask_request/request, zone)
	RETURN_TYPE(/alist)
	var/datum/dirt_mask_job/job = made_job(request)
	if(!job.masks)
		return null
	var/alist/by_limb = job.limb_runs()
	return by_limb[zone]

/**
 * The mess on bare skin draws through the limbs' own images. A landing gives each limb it reaches one container image
 * at DIRT_SKIN_LAYER, holding the baked image SSdirt makes, and gives the other limbs nothing. At a height, the
 * container's emissive blocker is one of the limb's images beside it, stretched as the container is. Washing takes the
 * mess off, even while its masks are still being made. They finish without bringing it back. Mess on every zone at once
 * gives each limb that carries mess (the head, the chest and the legs) a container and its blocker. The chest's splats
 * go in its one container. The body's images share one holder per layer, and their blockers one group
 * (prepare_bodypart_overlays()). So skin dirt adds a holder and a group, and underclothes dirt the same, four at most.
 * A shot's amount adds levels to the zone's newest splat. Past the top level, what's left starts another splat, of a
 * variant the zone doesn't have yet. A steady draw only compares what each is drawn from. Even so, if a limb is drawn
 * from other sprites with no limb swapped, the masks are made again for what the body draws. The cases are the chest at
 * another physique, a restyled arm, which the chest checks, and eyes drawn from another state. A 64x64 hat covers the
 * skin where it's drawn over the body (check_wide_cover()). A body hidden under a sleeping bag draws no skin dirt, but
 * keeps it (check_body_hidden()).
 */
/datum/unit_test/dirt_skin_mess
	parent_type = /datum/unit_test/dirt_genital_test

/datum/unit_test/dirt_skin_mess/Run()
	// whatever earlier tests left queued is made first
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.update_body()
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST), "A mess aimed at a bare chest didn't land.")
	SSdirt.finish_all()
	var/list/chest_images = skin_images(body, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(length(chest_images), 1, "A chest splat's chest images hold [length(chest_images)] mess containers, not one.")
	var/image/container = chest_images[1]
	TEST_ASSERT(length(container.overlays), "The chest's mess container holds no baked image.")
	for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		TEST_ASSERT(!length(skin_images(body, zone)), "A chest splat drew mess on the [zone].")
	// at a height, the chest's blocker is one of its images, stretched as its container is
	body.set_mob_height(HUMAN_HEIGHT_TALL)
	SSdirt.finish_all()
	chest_images = skin_images(body, BODY_ZONE_CHEST)
	var/list/blockers = skin_images(body, BODY_ZONE_CHEST, DIRT_SKIN_LAYER, TRUE)
	TEST_ASSERT(length(chest_images) == 1 && length(blockers) == 1, "A Tall body's chest splat draws [length(chest_images)] mess containers and [length(blockers)] emissive blockers among the chest's images, not one of each.")
	container = chest_images[1]
	var/image/blocker = blockers[1]
	TEST_ASSERT(length(container.filters) && length(blocker.filters) == length(container.filters), "A Tall body's chest blocker takes [length(blocker.filters)] filters, not the [length(container.filters)] height filters of its mess container.")
	body.set_mob_height(HUMAN_HEIGHT_MEDIUM)
	SSdirt.finish_all()
	body.wash(CLEAN_WASH)
	body.update_body_parts()
	TEST_ASSERT(!length(skin_images(body, BODY_ZONE_CHEST)), "Washing left mess drawn on the chest.")

	// washed while its masks are made: once they're done, they don't bring it back
	forget_masks(body, DIRT_ZONE_STOMACH)
	dirt_mess_land(body, DIRT_ZONE_STOMACH)
	TEST_ASSERT(length(SSdirt.queue), "A stomach splat's masks weren't queued, so washing can't be checked against them.")
	body.wash(CLEAN_WASH)
	SSdirt.finish_all()
	TEST_ASSERT(!length(skin_images(body, BODY_ZONE_CHEST)), "Masks finished after a wash drew the washed mess.")

	var/clean_overlays = length(body.overlays)
	for(var/zone in dirt_mess_zones())
		dirt_mess_land(body, zone)
	SSdirt.finish_all()
	var/added = length(body.overlays) - clean_overlays
	TEST_ASSERT(added > 0 && added <= 4, "The mess on every zone added [added] overlays to the body, not one to four.")
	TEST_ASSERT_EQUAL(length(skin_images(body, BODY_ZONE_CHEST)), 1, "The mess on every zone drew [length(skin_images(body, BODY_ZONE_CHEST))] mess containers on the chest, not one.")

	// a shot's amount adds levels to the zone's newest splat, and past the top what's left starts another splat
	body.wash(CLEAN_WASH)
	dirt_mess_land(body, DIRT_ZONE_CHEST, levels = 2)
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(describe_levels(carrier, DIRT_ZONE_CHEST), "2", "A heavy shot on a bare chest didn't start a level 2 splat.")
	dirt_mess_land(body, DIRT_ZONE_CHEST)
	dirt_mess_land(body, DIRT_ZONE_CHEST, levels = 2)
	TEST_ASSERT_EQUAL(describe_levels(carrier, DIRT_ZONE_CHEST), "[DIRT_MESS_MAX_LEVEL] 1", "Two levels on a level 3 chest splat didn't top it and start a level 1 splat.")
	var/datum/dirt_splat/topped = carrier.mess_splats[1]
	var/datum/dirt_splat/started = carrier.mess_splats[2]
	TEST_ASSERT_NOTEQUAL(started.variant, topped.variant, "The splat a shot started past the top took the variant already on the chest.")

	// drawn from other sprites in place, with no limb swapped: no signal tells the mess, only the draws' checks
	SSdirt.finish_all()
	body.physique = FEMALE
	body.update_body(is_creating = TRUE)
	SSdirt.finish_all()
	TEST_ASSERT(skin_drawn_for(body, carrier), "Skin mess is drawn from masks made for the sprites before the physique changed.")
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	arm.change_appearance(BODYPART_ICON_HUMANOID, SPECIES_HUMANOID, TRUE, FALSE)
	SSdirt.finish_all()
	TEST_ASSERT(skin_drawn_for(body, carrier), "Skin mess is drawn from masks made before the left arm was restyled.")
	// as luminescent eyes do as their light turns on, keeping their organ
	var/obj/item/organ/eyes/eyes = body.get_organ_slot(ORGAN_SLOT_EYES)
	eyes.eye_icon_state = /obj/item/organ/eyes/moth::eye_icon_state
	body.update_body_parts()
	SSdirt.finish_all()
	TEST_ASSERT(skin_drawn_for(body, carrier), "Skin mess is drawn from masks made for the eyes' sprites before they changed.")
	check_wide_cover()
	check_body_hidden()

/**
 * Checks that a 64x64 hat on a body with skin mess covers the pixels of the body's tile it's drawn on. The skin's masks
 * use that cover for their fades. The cover is the hat's sprite moved by the offsets tg draws it with, not the corner
 * of the sprite that a 32x32 read finds.
 */
/datum/unit_test/dirt_skin_mess/proc/check_wide_cover()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	// nothing else worn covers the skin
	body.underwear = /datum/sprite_accessory/clothing/underwear/nude::name
	body.undershirt = /datum/sprite_accessory/clothing/undershirt/nude::name
	body.bra = /datum/sprite_accessory/clothing/bra/nude::name
	body.socks = /datum/sprite_accessory/clothing/socks/nude::name
	body.update_body()
	var/obj/item/clothing/head/hats/hos/shako/hat = allocate(/obj/item/clothing/head/hats/hos/shako)
	TEST_ASSERT(body.equip_to_slot_if_possible(hat, ITEM_SLOT_HEAD), "Couldn't put a 64x64 hat on the human.")
	var/image/root = bulge_drawn_root(body.overlays_standing[HEAD_LAYER])
	var/image/leaf = bulge_drawn_leaf(root)
	var/list/size = leaf && get_icon_dimensions(leaf.icon)
	TEST_ASSERT(size?["width"] > ICON_SIZE_X, "The hat isn't drawn wider than a tile, so a wide sprite's cover can't be checked.")
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST), "A chest shot didn't land on the bare chest under a 64x64 hat.")
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(carrier?.skin?.request, "The chest shot asks for no skin masks.")
	var/datum/dirt_mask_job/job = made_job(carrier.skin.request)
	var/alist/covered = job.sprite_pixels["cover"]
	var/shift_x = root.pixel_x + root.pixel_w + (leaf == root ? 0 : leaf.pixel_x + leaf.pixel_w)
	var/shift_y = root.pixel_y + root.pixel_z + (leaf == root ? 0 : leaf.pixel_y + leaf.pixel_z)
	var/icon/sprite = icon(leaf.icon, leaf.icon_state)
	var/on_tile = 0
	var/wrong = 0
	for(var/direction in dirt_mask_directions())
		var/list/cover = covered?[direction]
		for(var/icon_y in 1 to ICON_SIZE_Y)
			for(var/icon_x in 1 to ICON_SIZE_X)
				var/sprite_x = icon_x - shift_x
				var/sprite_y = icon_y - shift_y
				var/drawn = sprite_x >= 1 && sprite_y >= 1 && sprite_x <= size["width"] && sprite_y <= size["height"] && !isnull(sprite.GetPixel(sprite_x, sprite_y, null, direction))
				on_tile += drawn
				wrong += drawn != !!cover?[(ICON_SIZE_Y - icon_y) * ICON_SIZE_X + icon_x]
	TEST_ASSERT(on_tile, "The 64x64 hat draws nothing over the body's tile, so its cover can't be checked.")
	TEST_ASSERT(!wrong, "The skin's masks read [wrong] pixels of the body's tile otherwise than as covered where the 64x64 hat is drawn over it.")

/**
 * Checks that a body with skin mess and walking mud, put in a sleeping bag, draws no skin dirt but keeps its splats.
 * The bag is a worn sprite larger than its tile. Taken out of it, the body draws them again. Each time, the body is
 * drawn by update_body_parts() alone, so whether it's hidden is read from the suit it wears now, not kept from before.
 */
/datum/unit_test/dirt_skin_mess/proc/check_body_hidden()
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "The sleeping bag is a lewd item, which the config disables.")
		return
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.update_body()
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST), "A mess aimed at a bare chest didn't land.")
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud landed nowhere on a bare human.")
	SSdirt.finish_all()
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	var/splats = length(carrier.mess_splats)
	TEST_ASSERT(length(skin_images(body, BODY_ZONE_CHEST)), "Skin mess on a bare chest isn't drawn.")
	var/drawn = skin_containers(body)
	var/obj/item/clothing/suit/straight_jacket/kinky_sleepbag/bag = allocate(/obj/item/clothing/suit/straight_jacket/kinky_sleepbag)
	// unfolded, the way it's worn, and put on without its preference check, which needs a client
	bag.bag_fold = FALSE
	bag.update_icon_state()
	body.equip_to_slot(bag, ITEM_SLOT_OCLOTHING)
	TEST_ASSERT(body.wear_suit == bag, "Couldn't put the sleeping bag on the human.")
	var/image/sprite = bulge_drawn_leaf(bulge_drawn_root(body.overlays_standing[SUIT_LAYER]))
	var/list/size = sprite && get_icon_dimensions(sprite.icon)
	TEST_ASSERT(size && size["width"] != ICON_SIZE_X, "The sleeping bag isn't drawn wider than a tile, so a hidden body can't be checked.")
	body.update_body_parts()
	TEST_ASSERT_EQUAL(skin_containers(body), 0, "A body in a sleeping bag draws skin dirt.")
	TEST_ASSERT_EQUAL(length(carrier.mess_splats), splats, "A body in a sleeping bag lost skin splats.")
	TEST_ASSERT(body.temporarilyRemoveItemFromInventory(bag, force = TRUE), "Couldn't take the sleeping bag off the human.")
	body.update_body_parts()
	TEST_ASSERT_EQUAL(skin_containers(body), drawn, "A body out of a sleeping bag draws [skin_containers(body)] skin dirt containers, not the [drawn] it drew before.")

/**
 * Returns how many skin dirt containers a body's limbs draw (skin_images()), summed over every zone skin dirt draws on.
 *
 * Arguments:
 * - body: The body.
 */
/datum/unit_test/dirt_skin_mess/proc/skin_containers(mob/living/carbon/human/body)
	. = 0
	for(var/zone in dirt_skin_zone_limbs())
		. += length(skin_images(body, zone))

/**
 * Returns whether a body's skin masks are asked for from the sprites it draws now (dirt_zone_sources_match()).
 *
 * Arguments:
 * - body: The body.
 * - carrier: Its carrier.
 */
/datum/unit_test/dirt_skin_mess/proc/skin_drawn_for(mob/living/carbon/human/body, datum/component/dirtiness/carrier)
	var/datum/dirt_mask_request/request = carrier.skin?.request
	return request && dirt_zone_sources_match(body, request.zone_sources)

/**
 * Returns the levels of a carrier's skin splats on one zone, oldest first, joined by spaces.
 *
 * Arguments:
 * - carrier: The carrier.
 * - zone: A DIRT_ZONE_* define.
 */
/datum/unit_test/dirt_skin_mess/proc/describe_levels(datum/component/dirtiness/carrier, zone)
	var/list/levels = list()
	for(var/datum/dirt_splat/splat as anything in carrier.mess_splats)
		if(splat.zone == zone)
			levels += splat.level
	return jointext(levels, " ")

/**
 * Drops any cached masks a level 1 splat on a zone could ask for on this body, so the next one is made afresh.
 *
 * Arguments:
 * - body: The body.
 * - zone: A DIRT_ZONE_* define.
 */
/datum/unit_test/dirt_skin_mess/proc/forget_masks(mob/living/carbon/human/body, zone)
	for(var/variant in 0 to DIRT_VARIANTS - 1)
		var/datum/dirt_mask_request/request = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_SKIN, list(new /datum/dirt_splat(zone, 1, variant, 0)))
		SSdirt.masks.forget(request.mask_key())

/**
 * The mess on clothes. A shot at a covered region lands on the outermost garment over it. The garment draws it inset
 * in its own worn wrapper, where the bulge can copy it. Washing the garment takes it off. If only underclothes cover a
 * region, the shot lands on the piece that shows the most of it. It's drawn over that piece, kept to its pixels, and
 * kept with the piece while it's hidden or swapped. Skin mess lies under the underclothes, and fades out beside them.
 */
/datum/unit_test/dirt_worn_mess
	parent_type = /datum/unit_test/dirt_genital_test

/datum/unit_test/dirt_worn_mess/Run()
	// whatever earlier tests left queued is made first
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	var/obj/item/clothing/suit/coat = allocate(/obj/item/clothing/suit/toggle/labcoat)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING) && body.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "Couldn't dress the body in a jumpsuit and a labcoat.")
	dirt_mess_land(body, DIRT_ZONE_CHEST)
	var/datum/component/dirtiness/coat_carrier = coat.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(coat_carrier?.mess_count(), 1, "A chest shot under a labcoat didn't land on the labcoat.")
	var/datum/component/dirtiness/skin_carrier = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(!skin_carrier?.mess_count(), "A chest shot under a labcoat landed on the body too.")
	SSdirt.finish_all()
	var/list/drawn = inset_images(body, SUIT_LAYER)
	TEST_ASSERT(length(drawn), "The labcoat draws no mess over itself.")
	for(var/image/mess_image as anything in drawn)
		TEST_ASSERT(mess_image.plane == FLOAT_PLANE && !mess_image.pixel_x && !mess_image.pixel_y && !mess_image.pixel_w && !mess_image.pixel_z, "The labcoat's mess is off the float plane or offset, which the bulge can't copy over its cloth.")
	coat.wash(CLEAN_WASH)
	TEST_ASSERT(!coat_carrier.mess_count(), "Washing the labcoat left its mess.")
	TEST_ASSERT(!length(inset_images(body, SUIT_LAYER)), "The washed labcoat still draws mess.")

	// a labcoat that leaves the groin bare leaves a groin shot to the jumpsuit under it
	dirt_mess_land(body, DIRT_ZONE_GROIN)
	var/datum/component/dirtiness/jumpsuit_carrier = jumpsuit.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(jumpsuit_carrier?.mess_count(), 1, "A groin shot under a jumpsuit and a labcoat that leaves the groin bare didn't land on the jumpsuit.")

	// two garments asking for the same masks while they're made: both are drawn again once they are
	var/list/twins = list()
	for(var/twin in 1 to 2)
		var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
		TEST_ASSERT(wearer.equip_to_slot_if_possible(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING), "Couldn't dress a twin in a jumpsuit.")
		twins += wearer
	var/datum/dirt_mask_request/twin_request = new(DIRT_MASKS_BODY, dirt_zone_sources(twins[1]), DIRT_SURFACE_CLOTH, list(new /datum/dirt_splat(DIRT_ZONE_STOMACH, 2, 3, 0)))
	SSdirt.masks.forget(twin_request.mask_key())
	for(var/mob/living/carbon/human/consistent/wearer as anything in twins)
		dirt_mess_place(wearer, DIRT_ZONE_STOMACH, 2, 3)
	TEST_ASSERT(SSdirt.mask_jobs[twin_request.mask_key()], "The twins' jumpsuit masks weren't queued, so waiting for them can't be checked.")
	SSdirt.finish_all()
	for(var/twin in 1 to 2)
		TEST_ASSERT(length(inset_images(twins[twin], UNIFORM_LAYER)), "Twin [twin]'s jumpsuit wasn't drawn again once the masks it waited for were made.")

	// boxers under a tank top whose hem reaches the waistband: a groin shot lands on the boxers, drawn over them and kept
	// to their pixels, and stays with them while they're hidden or swapped for others
	var/mob/living/carbon/human/consistent/boxed = allocate(/mob/living/carbon/human/consistent)
	boxed.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	boxed.undershirt = /datum/sprite_accessory/clothing/undershirt/tank_black::name
	boxed.update_body()
	SSdirt.finish_all()
	var/icon/clean_flat = getFlatIcon(boxed, SOUTH)
	var/list/boxer_pixels = underclothes_pixels(boxed, SOUTH, /datum/sprite_accessory/clothing/underwear/male_boxers::icon_state)
	TEST_ASSERT(length(boxer_pixels), "The boxers draw nothing facing south.")
	dirt_mess_place(boxed, DIRT_ZONE_GROIN, 2, 0)
	var/datum/component/dirtiness/boxed_carrier = boxed.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(boxed_carrier?.mess_count(), 1, "A groin shot on boxers wasn't held by the body.")
	TEST_ASSERT(!length(boxed_carrier.mess_splats), "A groin shot on boxers landed on the skin under them.")
	TEST_ASSERT(on_piece(boxed_carrier, DIRT_UNDERCLOTHES_UNDERWEAR), "A groin shot on boxers under a tank top landed elsewhere than the boxers.")
	SSdirt.finish_all()
	var/image/boxers_drawn = underclothes_image(boxed, /datum/sprite_accessory/clothing/underwear/male_boxers::icon_state)
	var/image/stain = drawn_at(boxed, -DIRT_UNDERCLOTHES_LAYER)
	TEST_ASSERT(boxers_drawn && stain, "The boxers or the mess on them isn't drawn.")
	TEST_ASSERT(stain.layer > boxers_drawn.layer, "The mess on the boxers draws at [stain.layer], under the boxers at [boxers_drawn.layer].")
	TEST_ASSERT(shows_on(boxed, clean_flat, boxer_pixels), "The mess on the boxers isn't drawn over them, or draws past them.")
	boxed.set_underwear_visibility("Underwear", TRUE)
	SSdirt.finish_all()
	TEST_ASSERT_EQUAL(boxed_carrier.mess_count(), 1, "Hiding the boxers lost the mess on them.")
	TEST_ASSERT(!drawn_at(boxed, -DIRT_UNDERCLOTHES_LAYER), "The mess on hidden boxers is still drawn.")
	boxed.set_underwear_visibility("Underwear", FALSE)
	SSdirt.finish_all()
	TEST_ASSERT(shows_on(boxed, clean_flat, boxer_pixels), "The mess on the boxers isn't drawn again once they're shown.")
	boxed.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	boxed.update_body()
	SSdirt.finish_all()
	TEST_ASSERT_EQUAL(boxed_carrier.mess_count(), 1, "Changing the boxers for briefs lost the mess on the boxers.")
	TEST_ASSERT(!drawn_at(boxed, -DIRT_UNDERCLOTHES_LAYER), "The mess on the boxers draws on the briefs worn instead.")
	boxed.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	boxed.update_body()
	SSdirt.finish_all()
	TEST_ASSERT(shows_on(boxed, clean_flat, boxer_pixels), "The mess on the boxers isn't drawn again once they're back on.")
	boxed.wash(CLEAN_WASH)
	TEST_ASSERT(!boxed_carrier.mess_count(), "Washing left the mess on the boxers.")

	// of several underclothes over a zone, the one showing the most of it takes the shot, ties to the kind that belongs
	// there: a hem over boxers doesn't, a polo or corset over them does, a swimsuit over a bra does, a leotard's low cut
	// doesn't, longjohns over the thighs do and briefs leave them to the skin. Zone, underwear, undershirt, bra, the piece
	// that takes it.
	var/mob/living/carbon/human/consistent/layered = allocate(/mob/living/carbon/human/consistent)
	var/boxers = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	var/corset = /datum/sprite_accessory/clothing/undershirt/nova/corset::name
	var/leotard = /datum/sprite_accessory/clothing/undershirt/nova/leotard::name
	var/list/outfits = list(
		list(DIRT_ZONE_GROIN, boxers, /datum/sprite_accessory/clothing/undershirt/tank_black::name, "Nude", DIRT_UNDERCLOTHES_UNDERWEAR),
		list(DIRT_ZONE_GROIN, boxers, /datum/sprite_accessory/clothing/undershirt/whitepolo::name, "Nude", DIRT_UNDERCLOTHES_UNDERSHIRT),
		list(DIRT_ZONE_GROIN, boxers, corset, "Nude", DIRT_UNDERCLOTHES_UNDERSHIRT),
		list(DIRT_ZONE_BUTT, boxers, corset, "Nude", DIRT_UNDERCLOTHES_UNDERSHIRT),
		list(DIRT_ZONE_CHEST, /datum/sprite_accessory/clothing/underwear/swimsuit_strapless_onepiece::name, "Nude", /datum/sprite_accessory/clothing/bra/bra_neko::name, DIRT_UNDERCLOTHES_UNDERWEAR),
		list(DIRT_ZONE_GROIN, boxers, leotard, "Nude", DIRT_UNDERCLOTHES_UNDERWEAR),
		list(DIRT_ZONE_BUTT, boxers, leotard, "Nude", DIRT_UNDERCLOTHES_UNDERWEAR),
		list(DIRT_ZONE_THIGHS, /datum/sprite_accessory/clothing/underwear/male_longjohns::name, "Nude", "Nude", DIRT_UNDERCLOTHES_UNDERWEAR),
		list(DIRT_ZONE_THIGHS, /datum/sprite_accessory/clothing/underwear/male_briefs::name, "Nude", "Nude", "skin"),
		list(DIRT_ZONE_CHEST, /datum/sprite_accessory/clothing/underwear/swimsuit_onepiece::name, /datum/sprite_accessory/clothing/undershirt/shirt::name, "Nude", DIRT_UNDERCLOTHES_UNDERSHIRT),
	)
	var/list/wrong = list()
	for(var/list/outfit as anything in outfits)
		layered.underwear = outfit[2]
		layered.undershirt = outfit[3]
		layered.bra = outfit[4]
		var/landed = dirt_underclothes_on(layered, outfit[1]) || "skin"
		if(landed != outfit[5])
			wrong += "[outfit[1]] on [outfit[2]], [outfit[3]] and [outfit[4]] went to the [landed]"
	// the last outfit by the rules, which judge until the human template is built: the shirt over the swimsuit takes it
	var/by_rules = dirt_underclothes_by_rules(layered, dirt_underclothes_sprites(layered), DIRT_ZONE_CHEST) || "skin"
	if(by_rules != DIRT_UNDERCLOTHES_UNDERSHIRT)
		wrong += "by the rules, [DIRT_ZONE_CHEST] on [layered.underwear] under [layered.undershirt] went to the [by_rules]"
	TEST_ASSERT(!length(wrong), "Shots on layered underclothes landed on the wrong piece: [jointext(wrong, "; ")].")

	// landed bare, then covered: under the boxers, and fading out beside them
	var/mob/living/carbon/human/consistent/bare = allocate(/mob/living/carbon/human/consistent)
	dirt_mess_place(bare, DIRT_ZONE_GROIN, DIRT_MESS_MAX_LEVEL, 0)
	SSdirt.finish_all()
	var/datum/component/dirtiness/bare_carrier = bare.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_masks/bare_masks = bare_carrier?.skin?.masks
	TEST_ASSERT(bare_masks, "The mess on a bare groin wasn't drawn.")
	bare.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	bare.update_body()
	SSdirt.finish_all()
	var/datum/dirt_masks/covered_masks = bare_carrier.skin?.masks
	var/beside = 0
	var/apart = 0
	var/under = 0
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/list/covered_pixels = underclothes_pixels(bare, direction)
		for(var/zone, baked in bare_masks.baked_by_limb)
			var/icon/bare_mask = icon(baked)
			var/icon/covered_mask = covered_masks.baked_by_limb[zone] && icon(covered_masks.baked_by_limb[zone])
			for(var/index in 1 to ICON_SIZE_X * ICON_SIZE_Y)
				var/icon_x = (index - 1) % ICON_SIZE_X + 1
				var/icon_y = floor((index - 1) / ICON_SIZE_X) + 1
				var/bare_alpha = mask_alpha(bare_mask.GetPixel(icon_x, icon_y, null, direction))
				if(!bare_alpha)
					continue
				if(covered_pixels[index])
					under += direction == SOUTH
					continue
				var/covered_alpha = covered_mask ? mask_alpha(covered_mask.GetPixel(icon_x, icon_y, null, direction)) : 0
				var/distance = cover_distance(covered_pixels, icon_x, icon_y)
				if(distance == 1)
					TEST_ASSERT(covered_alpha < bare_alpha, "Skin mess right beside the boxers doesn't fade, at [icon_x],[icon_y] facing [dir2text(direction)].")
					beside++
				else if(!distance)
					TEST_ASSERT_EQUAL(covered_alpha, bare_alpha, "Skin mess well clear of the boxers faded, at [icon_x],[icon_y] facing [dir2text(direction)].")
					apart++
	TEST_ASSERT(beside && apart && under, "Groin mess covered by boxers lay [beside] pixels beside them, [apart] clear of them and [under] under them facing south; the check needs some of each.")
	var/icon/covered_flat = getFlatIcon(bare, SOUTH)
	bare.wash(CLEAN_WASH)
	SSdirt.finish_all()
	var/icon/washed_flat = getFlatIcon(bare, SOUTH)
	var/list/south_boxers = underclothes_pixels(bare, SOUTH)
	for(var/index in 1 to ICON_SIZE_X * ICON_SIZE_Y)
		if(!south_boxers[index])
			continue
		var/icon_x = (index - 1) % ICON_SIZE_X + 1
		var/icon_y = floor((index - 1) / ICON_SIZE_X) + 1
		TEST_ASSERT_EQUAL(covered_flat.GetPixel(icon_x, icon_y), washed_flat.GetPixel(icon_x, icon_y), "Skin mess shows through the boxers at [icon_x],[icon_y].")

/**
 * Returns whether some of a carrier's underclothes splats are on a kind of underclothes.
 *
 * Arguments:
 * - carrier: The carrier.
 * - piece: A DIRT_UNDERCLOTHES_* define.
 */
/datum/unit_test/dirt_worn_mess/proc/on_piece(datum/component/dirtiness/carrier, piece)
	for(var/key in carrier?.underclothes_splats)
		if(findtext(key, piece) == 1)
			return TRUE
	return FALSE

/**
 * Returns the image a body draws for one of its underclothes, or null.
 *
 * Arguments:
 * - body: The body.
 * - state: The underclothes' icon state.
 */
/datum/unit_test/dirt_worn_mess/proc/underclothes_image(mob/living/carbon/human/body, state)
	var/list/standing = body.overlays_standing[BODY_LAYER]
	for(var/image/root as anything in (islist(standing) ? standing : list(standing)))
		var/image/leaf = bulge_drawn_leaf(root)
		if(leaf && root.plane == FLOAT_PLANE && leaf.icon_state == state)
			return root
	return null

/**
 * Returns an image a body draws at a layer, at the top of its overlays, or null.
 *
 * Arguments:
 * - body: The body.
 * - layer: The layer.
 */
/datum/unit_test/dirt_worn_mess/proc/drawn_at(mob/living/carbon/human/body, layer)
	for(var/image/drawn as anything in body.overlays)
		if(drawn.layer == layer && drawn.plane == FLOAT_PLANE)
			return drawn
	return null

/**
 * Returns whether a body facing south differs from a clean shot of it only on some pixels, and on some of them.
 *
 * Arguments:
 * - body: The body.
 * - clean_flat: The clean shot, facing south.
 * - allowed: The pixels it may differ on, from underclothes_pixels().
 */
/datum/unit_test/dirt_worn_mess/proc/shows_on(mob/living/carbon/human/body, icon/clean_flat, list/allowed)
	var/icon/flat = getFlatIcon(body, SOUTH)
	var/shown = 0
	for(var/index in 1 to ICON_SIZE_X * ICON_SIZE_Y)
		var/icon_x = (index - 1) % ICON_SIZE_X + 1
		var/icon_y = floor((index - 1) / ICON_SIZE_X) + 1
		if(clean_flat.GetPixel(icon_x, icon_y) == flat.GetPixel(icon_x, icon_y))
			continue
		if(!allowed[index])
			return FALSE
		shown++
	return shown > 0

/**
 * Returns which pixels a body's underclothes draw in one direction: a list of TRUE or null, indexed by icon y * width +
 * icon x, both from 0.
 *
 * Arguments:
 * - body: The body.
 * - direction: The direction.
 * - state: Only the underclothes with this icon state, or null for all.
 */
/datum/unit_test/dirt_worn_mess/proc/underclothes_pixels(mob/living/carbon/human/body, direction, state)
	var/list/pixels = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	var/list/standing = body.overlays_standing[BODY_LAYER]
	for(var/image/root as anything in (islist(standing) ? standing : list(standing)))
		var/image/leaf = bulge_drawn_leaf(root)
		if(!leaf || root.plane != FLOAT_PLANE || (state && leaf.icon_state != state))
			continue
		var/icon/sprite = icon(leaf.icon, leaf.icon_state)
		for(var/index in 1 to length(pixels))
			if(sprite.GetPixel((index - 1) % ICON_SIZE_X + 1, floor((index - 1) / ICON_SIZE_X) + 1, null, direction))
				pixels[index] = TRUE
	return pixels

/**
 * Returns a pixel's alpha, 0 to 255.
 *
 * Arguments:
 * - pixel: From GetPixel(): null, "#rrggbb" or "#rrggbbaa".
 */
/datum/unit_test/dirt_worn_mess/proc/mask_alpha(pixel)
	if(!pixel)
		return 0
	return length(pixel) > 7 ? hex2num(copytext(pixel, 8, 10)) : 255

/**
 * Returns how many steps up, down or across a pixel lies from the nearest covered one, up to 2, or 0 further off.
 * A covered pixel isn't asked about.
 *
 * Arguments:
 * - covered: From underclothes_pixels().
 * - icon_x, icon_y: The pixel.
 */
/datum/unit_test/dirt_worn_mess/proc/cover_distance(list/covered, icon_x, icon_y)
	for(var/distance in 1 to 2)
		for(var/step_x in -distance to distance)
			var/step_y = distance - abs(step_x)
			for(var/sign in list(-1, 1))
				var/near_x = icon_x + step_x
				var/near_y = icon_y + step_y * sign
				if(near_x >= 1 && near_y >= 1 && near_x <= ICON_SIZE_X && near_y <= ICON_SIZE_Y && covered[(near_y - 1) * ICON_SIZE_X + near_x])
					return distance
	return 0

/// The dirt tests that draw dirt on bodies, with the helpers they share: genitals built from DNA as a real character's,
/// taurs, and reads of what a body draws.
/datum/unit_test/dirt_genital_test
	parent_type = /datum/unit_test/portal_test
	abstract_type = /datum/unit_test/dirt_genital_test

/**
 * Returns the images a worn slot draws inset over its garment.
 *
 * Arguments:
 * - body: The wearer.
 * - layer: The slot's overlays_standing index.
 */
/datum/unit_test/dirt_genital_test/proc/inset_images(mob/living/carbon/human/body, layer)
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
 * - body: The body.
 * - zone: The limb's body zone.
 * - layer: DIRT_SKIN_LAYER, or DIRT_HAND_SKIN_LAYER for an arm's hand.
 * - blockers: Whether it returns the blockers, off the float plane, in place of the containers.
 */
/datum/unit_test/dirt_genital_test/proc/skin_images(mob/living/carbon/human/body, zone, layer = DIRT_SKIN_LAYER, blockers = FALSE)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/drawn as anything in body.drawn_limb_icons(zone))
		if(drawn.layer == -layer && (drawn.plane != FLOAT_PLANE) == blockers)
			. += drawn

/**
 * Returns the chest's cached images at a layer that draw no sprite of their own but hold others. They're parts' shares.
 *
 * Arguments:
 * - body: The body.
 * - layer: The layer.
 */
/datum/unit_test/dirt_genital_test/proc/share_images(mob/living/carbon/human/body, layer)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/drawn as anything in body.drawn_limb_icons(BODY_ZONE_CHEST))
		if(drawn.layer == layer && !drawn.icon && length(drawn.overlays))
			. += drawn

/// Returns a new job that made a request's masks from start to end, outside the queue and the mask cache.
/datum/unit_test/dirt_genital_test/proc/made_job(datum/dirt_mask_request/request)
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
 *
 * Arguments:
 * - body: The person.
 */
/datum/unit_test/dirt_genital_test/proc/held_serials(mob/living/carbon/human/body)
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

/**
 * Gives a test human bare breasts of a size, built from DNA as a real character's.
 *
 * Arguments:
 * - owner: The human.
 * - size: The breasts' size.
 */
/datum/unit_test/dirt_genital_test/proc/make_breasts(mob/living/carbon/human/owner, size)
	RETURN_TYPE(/obj/item/organ/genital/breasts)
	return make_genital(owner, /obj/item/organ/genital/breasts, ORGAN_SLOT_BREASTS, /datum/sprite_accessory/genital/breasts/pair::name, list("breasts_size" = size, "breasts_uses_skincolor" = FALSE, "breasts_uses_skintones" = FALSE, "breasts_lactation" = FALSE))

/**
 * Gives a test human a bare genital built from DNA as a real character's, hidden only by clothes.
 *
 * Arguments:
 * - owner: The human.
 * - organ_type: The genital's type.
 * - slot: Its ORGAN_SLOT_* define.
 * - accessory_name: Its sprite accessory's name.
 * - features: The DNA features it's built from.
 */
/datum/unit_test/dirt_genital_test/proc/make_genital(mob/living/carbon/human/owner, organ_type, slot, accessory_name, list/features)
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
 *
 * Arguments:
 * - body: The body.
 */
/datum/unit_test/dirt_genital_test/proc/right_sided(mob/living/carbon/human/body)
	RETURN_TYPE(/datum/component/dirtiness)
	var/datum/component/dirtiness/own = body.LoadComponent(/datum/component/dirtiness)
	own.side = 1
	return own

/**
 * Makes a test human a taur and returns its taur body.
 *
 * Arguments:
 * - rider: The human. It must not have a taur body yet.
 * - kind: The taur's sprite accessory type. By default it's the horse, the kind the parity corpus uses.
 */
/datum/unit_test/dirt_genital_test/proc/give_taur(mob/living/carbon/human/rider, datum/sprite_accessory/taur/kind = /datum/sprite_accessory/taur/horse)
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
 * A shot on someone offers the zones mess draws on them (dirt_mess_regions()): all seven on a human, none below the
 * waist on a taur, the groin and butt through a wall-stuck portal and the penis alone through a one-part portal, while
 * it draws. Odd bodies get only what draws on them: a monkey nothing, a kobold everything, a human without legs no
 * thighs. A full amount from size 4 testicles, as climax() spends it, lands at the top level.
 */
/datum/unit_test/dirt_mess_regions
	parent_type = /datum/unit_test/dirt_genital_test

/datum/unit_test/dirt_mess_regions/Run()
	var/upper_body = jointext(list(DIRT_ZONE_FACE, DIRT_ZONE_CHEST, DIRT_ZONE_STOMACH, DIRT_ZONE_BACK), " ")
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(body), " "), jointext(dirt_mess_zones(), " "), "A human isn't offered every zone, in order.")
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(body, DIRT_PORTAL_LOWER_BODY), " "), "[DIRT_ZONE_GROIN] [DIRT_ZONE_BUTT]", "A wall-stuck human isn't offered just the groin and butt.")

	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	give_feline_taur(taur)
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(taur), " "), upper_body, "A taur isn't offered just the zones above the waist.")
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(taur, DIRT_PORTAL_LOWER_BODY), " "), "", "A wall-stuck taur is offered zones.")

	var/mob/living/carbon/human/consistent/legless = allocate(/mob/living/carbon/human/consistent)
	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/leg = legless.get_bodypart(zone)
		leg.drop_limb(special = TRUE)
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(legless), " "), "[upper_body] [DIRT_ZONE_GROIN] [DIRT_ZONE_BUTT]", "A human without legs isn't offered every zone but the thighs.")

	var/mob/living/carbon/human/consistent/monkey = allocate(/mob/living/carbon/human/consistent)
	monkey.set_species(/datum/species/monkey)
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(monkey), " "), "", "A monkey is offered zones.")
	var/mob/living/carbon/human/consistent/kobold = allocate(/mob/living/carbon/human/consistent)
	kobold.set_species(/datum/species/monkey/kobold/roundstart)
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(kobold), " "), jointext(dirt_mess_zones(), " "), "A kobold, a monkey's kin mess draws on, isn't offered every zone.")

	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "The one-part portal and the amount need genitals, which the config disables.")
		return
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(body, DIRT_PORTAL_PENIS), " "), "", "A one-part portal offers a person without a penis zones.")
	var/obj/item/organ/genital/penis/penis = configure_test_penis(body)
	TEST_ASSERT(penis, "Couldn't give the body a penis.")
	// only a penis that draws can show what lands on it
	penis.visibility_preference = GENITAL_NEVER_SHOW
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(body, DIRT_PORTAL_PENIS), " "), "", "A one-part portal offers a penis that's never shown.")
	penis.visibility_preference = GENITAL_HIDDEN_BY_CLOTHES
	TEST_ASSERT_EQUAL(jointext(dirt_mess_regions(body, DIRT_PORTAL_PENIS), " "), DIRT_ZONE_COCK, "A one-part portal doesn't offer just the penis.")

	// the amount climax() spends: 60% of what the testicles hold
	body.dna.features["balls_size"] = 4
	var/obj/item/organ/genital/testicles/testicles = allocate(/obj/item/organ/genital/testicles)
	testicles.build_from_dna(body.dna, ORGAN_SLOT_TESTICLES)
	testicles.adjust_internal_fluid(testicles.internal_fluid_maximum)
	dirt_mess_land(body, DIRT_ZONE_FACE, levels = dirt_mess_amount_levels(testicles.internal_fluid_count * 0.6))
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_splat/splat = length(carrier?.mess_splats) ? carrier.mess_splats[1] : null
	TEST_ASSERT_EQUAL(splat?.level, DIRT_MESS_MAX_LEVEL, "A full shot from size 4 testicles landed at level [splat?.level || "none"], not the top.")

/**
 * Parts take their own share of the mess aimed at them. Breasts drawn above all clothing take theirs over a jumpsuit,
 * which takes the rest, and draw it with their own front layer. Through a one-part portal a shot lands on the penis
 * alone, and the relay draws it; a wall-stuck relay draws no legs, and draws the mess on the hips and butt, on the skin
 * and on a jumpsuit, under a winter coat too, but not a skirt, nor ever a bulge: a shot lands on what the relay shows
 * under the skirt. A share follows the part: an erection draws it again for the erect sprite, a butt set to draw above
 * its underwear is read again at its new layer, and a part removed takes its splats with it. A bulge's cloth over
 * boxers draws their mess over itself, a bulge's in a jumpsuit draws the jumpsuit's again once another splat lands, and
 * testicles a bulge look draws lose theirs to a wash. A butt shot takes the butt's share facing north, where its front
 * image draws over the skin, and in profile, where its back image draws under it, shapes the skin's mess past the
 * body's edge. Boxers put on over a butt drawn below them leave its share nothing to draw; put on under a vulva drawn
 * above them, they have its share made again for cloth. A part hidden while underclothes carry mess no longer shapes
 * the skin's mess. While a gloryhole's relay alone draws the penis, a groin shot on its owner's side gives the penis no
 * share, and the penis doesn't shape the skin's mess.
 */
/datum/unit_test/dirt_part_mess
	parent_type = /datum/unit_test/dirt_genital_test

/datum/unit_test/dirt_part_mess/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Parts need genitals, which the config disables.")
		return
	// whatever earlier tests left queued is made first
	SSdirt.finish_all()
	check_over_clothing()
	check_part_portal()
	check_relayed_penis()
	check_wall()
	check_wall_skirt()
	check_state_changes()
	check_bulge()
	check_bulge_jumpsuit()
	check_bulge_wash()
	check_butt()
	check_butt_layering()
	check_butt_under_boxers()
	check_vulva_over_boxers()
	check_hidden_butt()
	check_hidden_breasts()

/// Breasts above all clothing over a jumpsuit: each takes its share, and the breasts draw theirs.
/datum/unit_test/dirt_part_mess/proc/check_over_clothing()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/breasts = make_breasts(body, 7)
	TEST_ASSERT(breasts, "Couldn't give the body breasts.")
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	TEST_ASSERT(breasts.apply_visibility_label("Custom") && breasts.apply_layering_label("Above all clothing"), "Couldn't draw the breasts above all clothing.")
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST), "A chest shot didn't land.")
	var/datum/component/dirtiness/jumpsuit_carrier = jumpsuit.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(jumpsuit_carrier?.mess_count(), 1, "A chest shot on breasts over a jumpsuit didn't leave the jumpsuit one splat.")
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	var/list/breast_splats = carrier?.part_mess_splats[ORGAN_SLOT_BREASTS]
	TEST_ASSERT_EQUAL(length(breast_splats), 1, "Breasts drawn over the jumpsuit didn't take one splat of their own.")
	SSdirt.finish_all()
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = breasts.bodypart_overlay
	var/front_layer = -(BODY_FRONT_LAYER - 0.1 + overlay.genital_stack_rank * GENITAL_STACK_STEP)
	TEST_ASSERT(length(share_images(body, front_layer)), "The breasts' front layer draws no mess over the jumpsuit.")

/// A one-part portal: a shot on the penis alone, which the relay draws, and nothing else through it.
/datum/unit_test/dirt_part_mess/proc/check_part_portal()
	var/list/portal_pair = make_portal_pair("gloryhole")
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(configure_test_penis(occupant), "Couldn't give the occupant an exposed penis.")
	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The one-part portal couldn't start a session.")
	var/obj/effect/lewd_portal_relay/relay = source_portal.relayed_body
	TEST_ASSERT(!dirt_mess_land(occupant, DIRT_ZONE_GROIN, DIRT_PORTAL_PENIS), "A groin shot landed through a one-part portal, which shows only the penis.")
	TEST_ASSERT(dirt_mess_land(occupant, DIRT_ZONE_COCK, DIRT_PORTAL_PENIS), "A shot on the penis through a one-part portal didn't land.")
	var/datum/component/dirtiness/carrier = occupant.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(carrier?.mess_count(), 1, "A shot on the penis left [carrier?.mess_count() || 0] splats, not one.")
	TEST_ASSERT_EQUAL(length(carrier.part_mess_splats[ORGAN_SLOT_PENIS]), 1, "A shot at the penis zone didn't land on the penis.")
	// the relay draws again on the timer the occupant's redraws queue; run it as it would
	source_portal.flush_current_mob_visual_refresh()
	SSdirt.finish_all()
	source_portal.flush_current_mob_visual_refresh()
	var/shown = FALSE
	for(var/image/drawn as anything in relay.overlays)
		if(!drawn.icon && length(drawn.overlays))
			shown = TRUE
	TEST_ASSERT(shown, "The one-part portal's relay doesn't draw the mess on the penis.")
	source_portal.unbuckle_mob(occupant, force = TRUE, can_fall = FALSE)
	qdel(source_portal)

/**
 * A gloryhole's occupant, whose penis the relay alone draws, takes a groin shot on their own side. The penis takes no
 * share of it and doesn't shape the skin's mess. Once the session ends, a second groin shot gives the penis its share,
 * and the penis shapes the skin's mess.
 */
/datum/unit_test/dirt_part_mess/proc/check_relayed_penis()
	var/list/portal_pair = make_portal_pair("gloryhole")
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(configure_test_penis(occupant), "Couldn't give the occupant an exposed penis.")
	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The one-part portal couldn't start a session.")
	TEST_ASSERT(dirt_mess_land(occupant, DIRT_ZONE_GROIN), "A groin shot on a gloryhole's occupant didn't land.")
	var/datum/component/dirtiness/carrier = occupant.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(carrier?.skin?.request, "A groin shot on a gloryhole's occupant asks for no skin masks.")
	TEST_ASSERT(!length(carrier.part_mess_splats[ORGAN_SLOT_PENIS]) && !skin_shaped_by(carrier, ORGAN_SLOT_PENIS), "A gloryhole occupant's penis, which the relay alone draws, took a share of a groin shot on their side or shapes the skin's.")
	source_portal.unbuckle_mob(occupant, force = TRUE, can_fall = FALSE)
	TEST_ASSERT(dirt_mess_land(occupant, DIRT_ZONE_GROIN), "A second groin shot on the occupant didn't land.")
	TEST_ASSERT(length(carrier.part_mess_splats[ORGAN_SLOT_PENIS]) && skin_shaped_by(carrier, ORGAN_SLOT_PENIS), "Once the session ends, a groin shot gives the occupant's penis no share or leaves the skin's unshaped by it, so the session leaving it out can't be checked.")
	qdel(source_portal)

/**
 * Returns whether the skin masks a carrier asks for are shaped by the part in an organ slot (dirt_surface_parts()).
 *
 * Arguments:
 * - carrier: The person's carrier.
 * - organ_slot: The part's ORGAN_SLOT_* define.
 */
/datum/unit_test/dirt_part_mess/proc/skin_shaped_by(datum/component/dirtiness/carrier, organ_slot)
	for(var/datum/dirt_part_source/part as anything in carrier.skin?.request?.parts)
		if(part.organ_slot == organ_slot)
			return TRUE
	return FALSE

/// A wall-stuck relay shows the groin and butt only, and draws no leg, nor the mess on one. It draws the mess on what it
/// shows: on the bare skin, the chest's included through the torso it shows, and on a jumpsuit, which takes the shot
/// under a winter coat the relay doesn't draw. Two relays each clip what's worn to a body of their own.
/datum/unit_test/dirt_part_mess/proc/check_wall()
	var/list/portal_pair = make_portal_pair("wallstuck")
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	occupant.update_body()
	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The wall portal couldn't start a session.")
	var/obj/effect/lewd_portal_relay/relay = source_portal.relayed_body
	TEST_ASSERT(!dirt_mess_land(occupant, DIRT_ZONE_CHEST, DIRT_PORTAL_LOWER_BODY), "A chest shot landed through a wall portal, which shows the lower body.")
	TEST_ASSERT(dirt_mess_land(occupant, DIRT_ZONE_GROIN, DIRT_PORTAL_LOWER_BODY), "A groin shot through a wall portal didn't land.")
	// mess on the thighs from before the portal: the relay draws no leg, so none of it
	dirt_mess_place(occupant, DIRT_ZONE_THIGHS, 2, 0)
	SSdirt.finish_all()
	source_portal.flush_current_mob_visual_refresh()
	var/list/leg_masks = leg_mess_masks(occupant)
	TEST_ASSERT(length(leg_masks), "Mess on the thighs drew nothing on the legs.")
	var/leg_mess = 0
	for(var/image/drawn as anything in relay.overlays)
		for(var/image/mess_image as anything in drawn.overlays)
			if(mess_image.icon in leg_masks)
				leg_mess++
				break
	TEST_ASSERT_EQUAL(leg_mess, 0, "The wall portal's relay draws [leg_mess] of the legs' mess containers.")
	// the stomach's mess lies on the chest alone, whose images the relay keeps to its torso (torso_only())
	occupant.wash(CLEAN_WASH)
	dirt_mess_place(occupant, DIRT_ZONE_STOMACH, 2, 0)
	SSdirt.finish_all()
	source_portal.flush_current_mob_visual_refresh()
	var/skin_shown = FALSE
	for(var/image/drawn as anything in relay.overlays)
		if(drawn.layer == -DIRT_SKIN_LAYER && length(drawn.overlays))
			skin_shown = TRUE
	TEST_ASSERT(skin_shown, "The wall portal's relay doesn't draw the mess on the chest's skin.")
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(occupant.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the occupant in a jumpsuit.")
	TEST_ASSERT(dirt_mess_land(occupant, DIRT_ZONE_GROIN, DIRT_PORTAL_LOWER_BODY), "A groin shot on a jumpsuit through a wall portal didn't land.")
	SSdirt.finish_all()
	source_portal.flush_current_mob_visual_refresh()
	TEST_ASSERT(relay_insets(relay), "The wall portal's relay doesn't draw the jumpsuit's mess.")
	// a winter coat over the jumpsuit: the relay draws no suit, so the shot lands on the jumpsuit it draws
	jumpsuit.wash(CLEAN_WASH)
	var/datum/component/dirtiness/jumpsuit_carrier = jumpsuit.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(!jumpsuit_carrier?.mess_count(), "Washing the jumpsuit left its mess.")
	var/obj/item/clothing/suit/coat = allocate(/obj/item/clothing/suit/hooded/wintercoat)
	TEST_ASSERT(occupant.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "Couldn't put a winter coat over the occupant's jumpsuit.")
	TEST_ASSERT(dirt_mess_land(occupant, DIRT_ZONE_GROIN, DIRT_PORTAL_LOWER_BODY), "A groin shot through a wall portal on a winter coat over a jumpsuit didn't land.")
	// the wash deleted the jumpsuit's carrier, so the shot made it another
	jumpsuit_carrier = jumpsuit.GetComponent(/datum/component/dirtiness)
	var/datum/component/dirtiness/coat_carrier = coat.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(!coat_carrier?.mess_count() && jumpsuit_carrier?.mess_count() == 1, "A groin shot through a wall portal landed on the winter coat its relay doesn't draw, not on the jumpsuit under it.")
	SSdirt.finish_all()
	source_portal.flush_current_mob_visual_refresh()
	TEST_ASSERT(relay_insets(relay), "The wall portal's relay doesn't draw the mess on the jumpsuit under a winter coat.")
	// two relays in view: each clips what's worn to its own body
	var/list/other_pair = make_portal_pair("wallstuck")
	var/obj/structure/lewd_portal/other_portal = other_pair[1]
	var/mob/living/carbon/human/consistent/other_occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(other_portal.buckle_mob(other_occupant, force = TRUE, check_loc = FALSE), "A second wall portal couldn't start a session.")
	var/obj/effect/lewd_portal_relay/other_relay = other_portal.relayed_body
	TEST_ASSERT(draws_body_target(relay) && draws_body_target(other_relay) && relay.body_render_target() != other_relay.body_render_target(), "Two wall relays don't each draw their body to a render target of their own.")
	other_portal.unbuckle_mob(other_occupant, force = TRUE, can_fall = FALSE)
	qdel(other_portal)
	source_portal.unbuckle_mob(occupant, force = TRUE, can_fall = FALSE)
	qdel(source_portal)

/// A wall relay leaves out a skirt, so a shot through the wall lands where the relay shows it: on the underwear
/// covering the zone, else the skin. A wall-stuck body draws no bulge (portal_hides_bulge()), on either.
/datum/unit_test/dirt_part_mess/proc/check_wall_skirt()
	var/list/portal_pair = make_portal_pair("wallstuck")
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	// before the skirt, which hides it
	var/obj/item/organ/genital/penis/penis = configure_test_penis(occupant)
	TEST_ASSERT(penis, "Couldn't give the occupant an exposed penis.")
	occupant.underwear = /datum/sprite_accessory/clothing/underwear/panties_basic::name
	var/obj/item/clothing/under/skirt = allocate(/obj/item/clothing/under/dress/skirt/plaid)
	TEST_ASSERT(occupant.equip_to_slot_if_possible(skirt, ITEM_SLOT_ICLOTHING), "Couldn't dress the occupant in a plaid skirt.")
	occupant.update_body()
	var/image/skirt_drawn = bulge_drawn_root(occupant.overlays_standing[UNIFORM_LAYER])
	TEST_ASSERT_EQUAL(skirt_drawn?.layer, -UNIFORM_LAYER, "The skirt isn't drawn at the uniform's layer, so its relay can't be checked for it.")
	TEST_ASSERT(source_portal.buckle_mob(occupant, force = TRUE, check_loc = FALSE), "The wall portal couldn't start a session.")
	var/obj/effect/lewd_portal_relay/relay = source_portal.relayed_body
	source_portal.flush_current_mob_visual_refresh()
	TEST_ASSERT_EQUAL(images_at(relay.overlays, -UNIFORM_LAYER), 0, "The wall portal's relay draws the plaid skirt.")
	var/list/groin_surface = dirt_mess_surface(occupant, DIRT_ZONE_GROIN, DIRT_PORTAL_LOWER_BODY)
	var/datum/component/dirtiness/groin_carrier = groin_surface[1]
	TEST_ASSERT(groin_carrier.parent == occupant && groin_surface[2] == DIRT_UNDERCLOTHES_UNDERWEAR, "A groin shot through a wall portal on a skirt over panties doesn't land on the panties.")
	TEST_ASSERT(dirt_mess_land(occupant, DIRT_ZONE_BUTT, DIRT_PORTAL_LOWER_BODY), "A butt shot through a wall portal on a skirt didn't land.")
	var/datum/component/dirtiness/skirt_carrier = skirt.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(!skirt_carrier?.mess_count(), "A butt shot through a wall portal landed on the skirt its relay doesn't draw.")
	// a wall-stuck body draws no bulge, on the skirt or on pants the relay draws; nothing under them, so no underwear's
	// hold shapes the look once out of the wall
	occupant.underwear = /datum/sprite_accessory/clothing/underwear/nude::name
	occupant.update_body()
	penis.set_size(12)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "Couldn't change the penis's state.")
	var/datum/bodypart_overlay/mutant/genital/penis/look = penis.bodypart_overlay
	TEST_ASSERT(occupant.portal_hides_bulge() && !look.bulge_key, "A wall-stuck body drew a bulge on its skirt.")
	source_portal.flush_current_mob_visual_refresh()
	TEST_ASSERT_EQUAL(images_at(relay.overlays, -UNIFORM_LAYER), 0, "The wall portal's relay draws the skirt over a hard penis.")
	TEST_ASSERT(dirt_mess_land(occupant, DIRT_ZONE_GROIN, DIRT_PORTAL_LOWER_BODY), "A groin shot through a wall portal on a skirt over a hard penis didn't land.")
	skirt_carrier = skirt.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(!skirt_carrier?.mess_count(), "A groin shot through a wall portal landed on the skirt over a hard penis, which its relay doesn't draw.")
	occupant.dropItemToGround(skirt)
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(occupant.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the occupant in a jumpsuit.")
	TEST_ASSERT(!look.bulge_key, "A wall-stuck body drew a bulge on its jumpsuit.")
	source_portal.flush_current_mob_visual_refresh()
	TEST_ASSERT(images_at(relay.overlays, -UNIFORM_LAYER), "The wall portal's relay doesn't draw the jumpsuit.")
	// out of the wall it draws one again, so the wall is what kept it off
	source_portal.unbuckle_mob(occupant, force = TRUE, can_fall = FALSE)
	TEST_ASSERT(look.bulge_key && look.bulge_cover_type == jumpsuit.type, "A hard penis in a jumpsuit drew no bulge once out of the wall portal.")
	qdel(source_portal)

/**
 * Returns how many images lie at a layer: at -UNIFORM_LAYER in a relay's overlays, its copies of the uniform.
 *
 * Arguments:
 * - images: The images.
 * - layer: The layer.
 */
/datum/unit_test/dirt_part_mess/proc/images_at(list/images, layer)
	. = 0
	for(var/image/drawn as anything in images)
		if(drawn.layer == layer)
			.++

/**
 * Returns whether a wall relay draws its body to its own render target (body_render_target()), as the filters that
 * clip what's worn over the body read it.
 *
 * Arguments:
 * - relay: The relay.
 */
/datum/unit_test/dirt_part_mess/proc/draws_body_target(obj/effect/lewd_portal_relay/relay)
	for(var/image/drawn as anything in relay.overlays)
		if(drawn.render_target == relay.body_render_target() && length(drawn.overlays))
			return TRUE
	return FALSE

/**
 * Returns the baked icons of the legs' skin mess containers (/datum/bodypart_overlay/dirt_skin), as their limbs draw them
 * now. A relay's copy of a container is matched by these, so a filter on the copy doesn't hide it.
 *
 * Arguments:
 * - body: The person.
 */
/datum/unit_test/dirt_part_mess/proc/leg_mess_masks(mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	. = list()
	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/leg = body.get_bodypart(zone)
		for(var/image/drawn as anything in leg?.get_limb_icon())
			if(drawn.layer != -DIRT_SKIN_LAYER)
				continue
			for(var/image/mess_image as anything in drawn.overlays)
				. += mess_image.icon

/**
 * Returns how many inset images a portal's relay draws in the wrappers it copies: a garment's mess.
 *
 * Arguments:
 * - relay: The relay.
 */
/datum/unit_test/dirt_part_mess/proc/relay_insets(obj/effect/lewd_portal_relay/relay)
	. = 0
	for(var/image/drawn as anything in relay.overlays)
		for(var/image/child as anything in drawn.overlays)
			if(child.blend_mode == BLEND_INSET_OVERLAY)
				.++

/// An erection draws the penis's share again for the erect sprite; removing the breasts takes their splats off.
/datum/unit_test/dirt_part_mess/proc/check_state_changes()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/penis/penis = configure_test_penis(body)
	TEST_ASSERT(penis, "Couldn't give the body an exposed penis.")
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_GROIN), "A groin shot didn't land.")
	SSdirt.finish_all()
	var/soft_key = share_key(body)
	TEST_ASSERT(soft_key && soft_key != "pending", "A soft penis's share isn't in the chest's render key once made: [soft_key || "none"].")
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "Couldn't change the penis's state.")
	SSdirt.finish_all()
	var/hard_key = share_key(body)
	TEST_ASSERT(hard_key && hard_key != "pending", "An erect penis's share isn't in the chest's render key once made: [hard_key || "none"].")
	TEST_ASSERT_NOTEQUAL(hard_key, soft_key, "The penis's share wasn't drawn again for the erect sprite.")

	var/obj/item/organ/genital/breasts/breasts = make_breasts(body, 3)
	TEST_ASSERT(breasts, "Couldn't give the body breasts.")
	body.update_body()
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST), "A chest shot didn't land.")
	SSdirt.finish_all()
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(length(carrier.part_mess_splats[ORGAN_SLOT_BREASTS]), "Bare breasts didn't take a share of a chest shot.")
	breasts.Remove(body)
	TEST_ASSERT(!length(carrier.part_mess_splats[ORGAN_SLOT_BREASTS]), "Removing the breasts left their splats on the body.")
	body.update_body()
	SSdirt.finish_all()

/// A bulge over boxers covers their mess with its cloth: the mess is drawn again over the cloth.
/datum/unit_test/dirt_part_mess/proc/check_bulge()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/penis/penis = configure_test_penis(body)
	TEST_ASSERT(penis, "Couldn't give the body an exposed penis.")
	penis.set_size(12)
	body.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	body.update_body()
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "Couldn't change the penis's state.")
	var/datum/bodypart_overlay/mutant/genital/penis/look = penis.bodypart_overlay
	TEST_ASSERT(look.bulge_key && look.bulge_template, "A hard penis under boxers drew no bulge with cloth of its own.")
	dirt_mess_place(body, DIRT_ZONE_GROIN, 2, 0)
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(length(carrier?.underclothes_splats), "A groin shot on boxers under a bulge didn't land on the boxers.")
	SSdirt.finish_all()
	TEST_ASSERT(length(share_images(body, -(look.bulge_layer - BULGE_ABOVE_COVER))), "The boxers' mess isn't drawn over the bulge's cloth.")

/// A bulge in a jumpsuit draws the jumpsuit's mess over its cloth, and draws it again once another splat lands, keeping
/// the chest's images off tg's shared limb icon cache: each mess state draws a key that never comes back.
/datum/unit_test/dirt_part_mess/proc/check_bulge_jumpsuit()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/penis/penis = configure_test_penis(body)
	TEST_ASSERT(penis, "Couldn't give the body an exposed penis.")
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	penis.set_size(12)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "Couldn't change the penis's state.")
	var/datum/bodypart_overlay/mutant/genital/penis/look = penis.bodypart_overlay
	TEST_ASSERT(look.bulge_key && look.bulge_template, "A hard penis in a jumpsuit drew no bulge with cloth of its own.")
	dirt_mess_place(body, DIRT_ZONE_GROIN, 2, 0)
	SSdirt.finish_all()
	var/list/first = list()
	for(var/mutable_appearance/over as anything in look.bulge_over)
		first += over.icon
	TEST_ASSERT(length(first), "The jumpsuit's mess isn't drawn over the bulge's cloth.")
	var/cached_limbs = length(body.limb_icon_cache)
	dirt_mess_place(body, DIRT_ZONE_GROIN, 2, 3)
	SSdirt.finish_all()
	var/list/second = list()
	for(var/mutable_appearance/over as anything in look.bulge_over)
		second += over.icon
	TEST_ASSERT(length(second) && !length(second & first), "The bulge's cloth draws the jumpsuit's mess as it was before another splat landed.")
	TEST_ASSERT_EQUAL(length(body.limb_icon_cache) - cached_limbs, 0, "A bulge drawing a jumpsuit's new mess added the chest to tg's shared limb icon cache.")

/// Testicles drawn behind a hard loincloth by its bulge look draw their mess there, the chest's images kept off tg's
/// shared limb icon cache meanwhile, and lose it to a wash.
/datum/unit_test/dirt_part_mess/proc/check_bulge_wash()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/penis/penis = configure_test_penis(body)
	TEST_ASSERT(penis, "Couldn't give the body an exposed penis.")
	var/obj/item/organ/genital/testicles/testicles = make_genital(body, /obj/item/organ/genital/testicles, ORGAN_SLOT_TESTICLES, /datum/sprite_accessory/genital/testicles/pair::name, list("balls_size" = 3, "testicles_uses_skincolor" = FALSE, "testicles_uses_skintones" = FALSE))
	TEST_ASSERT(testicles, "Couldn't give the body testicles.")
	var/obj/item/clothing/under/costume/loincloth/loincloth = allocate(/obj/item/clothing/under/costume/loincloth)
	TEST_ASSERT(body.equip_to_slot_if_possible(loincloth, ITEM_SLOT_ICLOTHING), "Couldn't put the loincloth on.")
	penis.set_size(12)
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "Couldn't change the penis's state.")
	var/datum/bodypart_overlay/mutant/genital/penis/look = penis.bodypart_overlay
	TEST_ASSERT(look.bulge_key && look.bulge_anatomy_behind, "A hard loincloth draws nothing behind its cut, so the testicles there can't be checked.")
	var/datum/component/dirtiness/carrier = body.LoadComponent(/datum/component/dirtiness)
	carrier.add_mess(DIRT_ZONE_GROIN, ORGAN_SLOT_TESTICLES, 2, 0)
	SSdirt.finish_all()
	var/behind = -(look.bulge_layer + BULGE_BEHIND_COVER)
	TEST_ASSERT(length(share_images(body, behind)), "The testicles drawn behind the loincloth don't draw their mess.")
	TEST_ASSERT(findtextEx(body.icon_render_keys[BODY_ZONE_CHEST], DIRT_PRIVATE_KEY), "A chest drawing dirty testicles behind a loincloth's cut is keyed for tg's shared limb icon cache.")
	body.wash(CLEAN_WASH)
	SSdirt.finish_all()
	TEST_ASSERT(!length(share_images(body, behind)), "Washed testicles behind the loincloth still draw their mess.")

/// A butt shot on a bare butt: its own share facing north, none in profile, where its back image lies under the skin.
/datum/unit_test/dirt_part_mess/proc/check_butt()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(make_genital(body, /obj/item/organ/genital/butt, ORGAN_SLOT_BUTT, /datum/sprite_accessory/genital/butt/pair::name, list("butt_size" = 6, "butt_uses_skincolor" = FALSE, "butt_uses_skintones" = FALSE)), "Couldn't give the body a butt.")
	dirt_mess_place(body, DIRT_ZONE_BUTT, 3, 0)
	SSdirt.finish_all()
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(length(carrier?.part_mess_splats[ORGAN_SLOT_BUTT]), "A bare butt drawn over the skin facing north took no share of its own.")
	var/datum/dirt_drawing/drawing = carrier.part_drawings?[ORGAN_SLOT_BUTT]
	var/share = drawing?.masks?.baked
	TEST_ASSERT(length(mask_pixels(share, NORTH)), "The butt's own share draws nothing facing north.")
	TEST_ASSERT(!length(mask_pixels(share, EAST)) && !length(mask_pixels(share, WEST)), "The butt's own share draws in profile, where its back image lies under the skin's mess.")

/// A bare butt with mess of its own, hidden under boxers, then set to draw above them: its share is read at its new
/// layer.
/datum/unit_test/dirt_part_mess/proc/check_butt_layering()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/butt/butt = make_genital(body, /obj/item/organ/genital/butt, ORGAN_SLOT_BUTT, /datum/sprite_accessory/genital/butt/pair::name, list("butt_size" = 6, "butt_uses_skincolor" = FALSE, "butt_uses_skintones" = FALSE))
	TEST_ASSERT(butt, "Couldn't give the body a butt.")
	var/datum/component/dirtiness/carrier = body.LoadComponent(/datum/component/dirtiness)
	carrier.add_mess(DIRT_ZONE_BUTT, ORGAN_SLOT_BUTT, 2, 0)
	SSdirt.finish_all()
	body.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	body.update_body()
	SSdirt.finish_all()
	TEST_ASSERT(butt.apply_visibility_label("Custom") && butt.apply_layering_label("Above underwear"), "Couldn't draw the butt above its underwear.")
	SSdirt.finish_all()
	var/datum/bodypart_overlay/mutant/genital/overlay = butt.bodypart_overlay
	var/datum/dirt_part_source/drawn = overlay.dirt_share_source(body.get_bodypart(BODY_ZONE_CHEST))
	TEST_ASSERT(drawn, "The butt drawn above its underwear isn't read as a part.")
	var/datum/dirt_part_source/remembered = overlay.dirt_source
	TEST_ASSERT_EQUAL(remembered ? jointext(remembered.state_layers, ",") : "none", jointext(drawn.state_layers, ","), "The butt's share is read at the layers it drew at before its layering changed.")

/// A butt drawn below its underwear, with mess of its own facing north over the bare skin, then boxers put on: its
/// front image draws under them now, so its share draws nothing.
/datum/unit_test/dirt_part_mess/proc/check_butt_under_boxers()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/butt/butt = make_genital(body, /obj/item/organ/genital/butt, ORGAN_SLOT_BUTT, /datum/sprite_accessory/genital/butt/pair::name, list("butt_size" = 6, "butt_uses_skincolor" = FALSE, "butt_uses_skintones" = FALSE))
	TEST_ASSERT(butt?.apply_visibility_label("Custom") && butt.apply_layering_label("Below underwear"), "Couldn't give the body a butt drawn below its underwear.")
	var/datum/component/dirtiness/carrier = body.LoadComponent(/datum/component/dirtiness)
	carrier.add_mess(DIRT_ZONE_BUTT, ORGAN_SLOT_BUTT, 2, 0)
	SSdirt.finish_all()
	var/datum/dirt_drawing/drawing = carrier.part_drawings?[ORGAN_SLOT_BUTT]
	TEST_ASSERT(length(mask_pixels(drawing?.masks?.baked, NORTH)), "The bare butt's own share draws nothing facing north, so boxers over it can't be checked.")
	body.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	body.update_body()
	SSdirt.finish_all()
	TEST_ASSERT(!length(mask_pixels(drawing.masks?.baked, NORTH)), "A butt drawn under boxers still draws its own share over them facing north.")

/// A vulva drawn above its underwear, with mess of its own on the bare skin, then boxers put on: it lies on them now,
/// so its share is made again for cloth, without the ring of skin.
/datum/unit_test/dirt_part_mess/proc/check_vulva_over_boxers()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/vagina/vulva = make_genital(body, /obj/item/organ/genital/vagina, ORGAN_SLOT_VAGINA, /datum/sprite_accessory/genital/vagina/human::name, list("vagina_uses_skincolor" = FALSE, "vagina_uses_skintones" = FALSE))
	TEST_ASSERT(vulva?.apply_visibility_label("Custom") && vulva.apply_layering_label("Above underwear"), "Couldn't give the body a vulva drawn above its underwear.")
	var/datum/component/dirtiness/carrier = body.LoadComponent(/datum/component/dirtiness)
	carrier.add_mess(DIRT_ZONE_GROIN, ORGAN_SLOT_VAGINA, 2, 0)
	SSdirt.finish_all()
	var/datum/dirt_drawing/drawing = carrier.part_drawings?[ORGAN_SLOT_VAGINA]
	var/datum/dirt_masks/skin_masks = drawing?.masks
	TEST_ASSERT(skin_masks, "The bare vulva's own share wasn't made, so boxers under it can't be checked.")
	body.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	body.update_body()
	SSdirt.finish_all()
	TEST_ASSERT(drawing.masks && drawing.masks != skin_masks, "A vulva drawn over boxers still draws the share made for it on bare skin.")

/// A butt shot and a stained bra, then the butt never shown: the skin's mess is left nowhere past the body.
/datum/unit_test/dirt_part_mess/proc/check_hidden_butt()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/butt/butt = make_genital(body, /obj/item/organ/genital/butt, ORGAN_SLOT_BUTT, /datum/sprite_accessory/genital/butt/pair::name, list("butt_size" = 6, "butt_uses_skincolor" = FALSE, "butt_uses_skintones" = FALSE))
	TEST_ASSERT(butt, "Couldn't give the body a butt.")
	body.bra = /datum/sprite_accessory/clothing/bra/bra::name
	body.update_body()
	dirt_mess_place(body, DIRT_ZONE_BUTT, 3, 0)
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(carrier?.add_underclothes_mess(DIRT_ZONE_CHEST, DIRT_UNDERCLOTHES_BRA, 2, 0), "Couldn't put a mess on the bra.")
	SSdirt.finish_all()
	var/datum/dirt_template/template = SSdirt.templates.fetch(dirt_template_key(dirt_zone_sources(body)))
	TEST_ASSERT(template, "The body's template isn't built.")
	TEST_ASSERT(length(skin_past_body(carrier, template)), "The skin's mess doesn't reach the butt past the body, so hiding it can't be checked.")
	TEST_ASSERT(butt.apply_visibility_label("Never show"), "Couldn't hide the butt.")
	SSdirt.finish_all()
	var/list/floating = skin_past_body(carrier, template)
	TEST_ASSERT(!length(floating), "A butt never shown leaves the skin's mess past the body where it drew: [jointext(floating, ", ")].")

/// Breasts never shown while socks carry mess: the chest's mess covers where they drew.
/datum/unit_test/dirt_part_mess/proc/check_hidden_breasts()
	var/mob/living/carbon/human/consistent/chested = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/breasts = make_breasts(chested, 7)
	TEST_ASSERT(breasts, "Couldn't give the body breasts.")
	chested.socks = /datum/sprite_accessory/clothing/socks/black_thigh::name
	chested.update_body()
	dirt_mess_place(chested, DIRT_ZONE_CHEST, DIRT_MESS_MAX_LEVEL, 0)
	var/datum/component/dirtiness/chest_carrier = chested.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(chest_carrier?.add_underclothes_mess(DIRT_ZONE_THIGHS, DIRT_UNDERCLOTHES_SOCKS, 2, 0), "Couldn't put a mess on the socks.")
	SSdirt.finish_all()
	var/datum/dirt_part_source/drawn_breasts = dirt_part_drawn(breasts, chested)
	var/list/breast_pixels = drawn_breasts?.pixels(SOUTH)
	TEST_ASSERT(length(breast_pixels), "The breasts draw nothing facing south.")
	var/list/chest_mess = mask_pixels(chest_carrier.skin?.masks?.baked_by_limb[BODY_ZONE_CHEST], SOUTH)
	TEST_ASSERT(length(chest_mess) && !length(chest_mess & breast_pixels), "The chest's mess doesn't leave out the breasts drawn over it, so hiding them can't be checked.")
	TEST_ASSERT(breasts.apply_visibility_label("Never show"), "Couldn't hide the breasts.")
	SSdirt.finish_all()
	chest_mess = mask_pixels(chest_carrier.skin?.masks?.baked_by_limb[BODY_ZONE_CHEST], SOUTH)
	TEST_ASSERT(length(chest_mess & breast_pixels), "Breasts never shown leave holes in the chest's mess where they drew.")

/**
 * Returns the pixels the chest's skin mask draws off the body, in any direction, each as "direction:index".
 *
 * Arguments:
 * - carrier: The body's carrier.
 * - template: The body's template.
 */
/datum/unit_test/dirt_part_mess/proc/skin_past_body(datum/component/dirtiness/carrier, datum/dirt_template/template)
	RETURN_TYPE(/list)
	. = list()
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_surface/surface = template.surfaces[direction]
		for(var/index in mask_pixels(carrier.skin?.masks?.baked_by_limb[BODY_ZONE_CHEST], direction))
			if(!DIRT_PIXEL_ZONE(surface.flags_of[index]))
				. += "[direction]:[index]"

/**
 * Returns the pixels a baked icon draws facing one way, as surface indexes.
 *
 * Arguments:
 * - baked: The baked icon, as /datum/dirt_masks holds it, or null.
 * - direction: The direction.
 */
/datum/unit_test/dirt_part_mess/proc/mask_pixels(baked, direction)
	RETURN_TYPE(/list)
	. = list()
	if(!baked)
		return
	var/icon/sprite = icon(baked)
	for(var/index in 1 to ICON_SIZE_X * ICON_SIZE_Y)
		var/row = floor((index - 1) / ICON_SIZE_X)
		if(sprite.GetPixel(index - row * ICON_SIZE_X, ICON_SIZE_Y - row, null, direction))
			. += index

/**
 * Returns what the chest's render key carries for the penis's share: its masks' key, "pending", or null for none.
 *
 * Arguments:
 * - body: The body.
 */
/datum/unit_test/dirt_part_mess/proc/share_key(mob/living/carbon/human/body)
	var/key = body.icon_render_keys[BODY_ZONE_CHEST]
	var/start = findtext(key, "mess=")
	if(!start)
		return null
	var/finish = findtext(key, "-", start)
	return copytext(key, start + length("mess="), finish || 0)

/**
 * A back shot on a taur lands on the rider's back and along the taur body's: the rider's skin and the taur body's slot
 * each take a splat of the same variant. The game reads the rider and the taur body as the parity corpus names them.
 * Once the masks are made, the taur body's images carry the pools beside them. At another height, a taur body's dirt
 * is its Average dirt, less what the rider covers, and carried onto what the rider uncovers. A Big Legs body has its
 * legs under the rider and no taur back, so it takes the shot on the rider alone. A taur suit takes the pools itself,
 * inset over its 64x32 sprite. The rider's mess on the suit lands on the body's tile, not 16 px off. At a height, the
 * suit's mirror on the emissive plane is moved as the suit is. Its mess's blockers in the mirror lie where the mess
 * does. Removing the taur body takes its pools with it. A taur's penis drawn only behind the body takes no share.
 */
/datum/unit_test/dirt_taur_mess
	parent_type = /datum/unit_test/dirt_genital_test

/datum/unit_test/dirt_taur_mess/Run()
	// whatever earlier tests left queued is made first
	SSdirt.finish_all()
	var/list/corpus = json_decode(file2text(DIRT_CORPUS) || "{}")
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/taur_body/taur_body = give_taur(rider)
	TEST_ASSERT(taur_body, "Couldn't make the human a horse taur.")
	TEST_ASSERT_EQUAL(dirt_template_key(dirt_zone_sources(rider)), dirt_template_key(dirt_parity_zone_sources(corpus["templates"]["human_legless"])), "A taur's rider isn't drawn from the corpus's human_legless sprites.")
	TEST_ASSERT_EQUAL(describe_layers(dirt_taur_source(rider)), describe_layers(dirt_parity_taur(corpus["taurs"]["horse"])), "A horse taur isn't read from the corpus's horse states.")

	TEST_ASSERT(dirt_mess_land(rider, DIRT_ZONE_BACK), "A back shot on a taur didn't land.")
	var/datum/component/dirtiness/carrier = rider.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(length(carrier?.mess_splats), 1, "A back shot on a bare taur didn't leave the rider's skin one splat.")
	var/list/pools = carrier.part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR]
	TEST_ASSERT_EQUAL(length(pools), 1, "A back shot on a bare taur didn't leave its taur body one splat.")
	var/datum/dirt_splat/rider_splat = carrier.mess_splats[1]
	var/datum/dirt_splat/pool_splat = pools[1]
	TEST_ASSERT_EQUAL(pool_splat.variant, rider_splat.variant, "The taur body's splat isn't the rider's variant.")
	SSdirt.finish_all()
	TEST_ASSERT(length(pool_images(rider)), "The taur body's images carry no pools once they're made.")
	check_rider_heights()
	check_big_legs()

	// a taur suit hides the taur body and takes the shot: its own splat draws the pools too
	var/obj/item/clothing/suit/utility/bomb_suit/suit = allocate(/obj/item/clothing/suit/utility/bomb_suit)
	TEST_ASSERT(rider.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Couldn't put a taur suit on the taur.")
	TEST_ASSERT(dirt_mess_place(rider, DIRT_ZONE_BACK, 2, 0), "A back shot on a taur suit didn't land.")
	var/datum/component/dirtiness/suit_carrier = suit.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(suit_carrier?.mess_count(), 1, "A back shot on a taur suit didn't leave the suit one splat.")
	TEST_ASSERT_EQUAL(length(carrier.part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR]), 1, "A back shot on a taur suit landed on the taur body it hides too.")
	SSdirt.finish_all()
	var/mutable_appearance/standing = bulge_drawn_root(rider.overlays_standing[SUIT_LAYER])
	// measured: center_image() leaves the suit (its worn_x_dimension is 32), and worn_x_offset moves its 64x32 sprite left
	TEST_ASSERT_EQUAL(describe_insets(standing), "wrapper -16,0; rider 16,0; pools 0,0", "A taur suit's mess isn't drawn on the body's tile and the taur canvas round it.")
	var/image/sprite = bulge_drawn_leaf(standing)
	var/list/covered = list()
	for(var/direction in dirt_mask_directions())
		covered["[direction]"] = dirt_sprite_pixels(sprite.icon, sprite.icon_state, direction, DIRT_TAUR_WIDTH)
	var/pools_on_suit = 0
	var/rider_on_suit = 0
	for(var/image/child as anything in standing.overlays)
		if(child.blend_mode != BLEND_INSET_OVERLAY)
			continue
		var/wide = get_icon_dimensions(child.icon)["width"] == DIRT_TAUR_WIDTH
		for(var/direction in dirt_mask_directions())
			for(var/index in inset_pixels(child.icon, direction, wide))
				if(index in covered["[direction]"])
					if(wide)
						pools_on_suit++
					else
						rider_on_suit++
	TEST_ASSERT(pools_on_suit, "The taur suit doesn't take the pools as inset images on its sprite.")
	TEST_ASSERT(rider_on_suit, "The rider's mess on the taur suit misses its sprite.")
	// at a height, the suit's emissive mirror moves as the suit does, and each blocker as its mess does
	rider.set_mob_height(HUMAN_HEIGHT_TALL)
	SSdirt.finish_all()
	standing = bulge_drawn_root(rider.overlays_standing[SUIT_LAYER])
	var/image/mirror
	var/list/suit_drawn = rider.overlays_standing[SUIT_LAYER]
	for(var/image/root as anything in (islist(suit_drawn) ? suit_drawn : list(suit_drawn)))
		if(PLANE_TO_TRUE(root.plane) == EMISSIVE_PLANE && length(root.overlays))
			mirror = root.overlays[1]
	TEST_ASSERT(mirror && length(standing?.filters), "A Tall taur's suit isn't stretched, or draws nothing on the emissive plane, so its blockers can't be checked.")
	TEST_ASSERT_EQUAL(describe_insets(standing), "wrapper -16,0; rider 16,0; pools 0,0", "A Tall taur's suit doesn't draw its mess on the body's tile and the taur canvas round it.")
	TEST_ASSERT_EQUAL(describe_insets(mirror), describe_insets(standing), "A Tall taur suit's blockers on the emissive plane aren't drawn where its mess is.")

	taur_body.Remove(rider, special = TRUE)
	TEST_ASSERT(!length(carrier.part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR]), "Removing the taur body left its pools on the person.")
	qdel(taur_body)

	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "The taur's penis needs genitals, which the config disables.")
		return
	var/mob/living/carbon/human/consistent/stallion = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(stallion), "Couldn't make a second human a horse taur.")
	// the knotted kind has taur art, drawn as a human's until penis_taur_mode is set
	var/obj/item/organ/genital/penis/penis = make_genital(stallion, /obj/item/organ/genital/penis, ORGAN_SLOT_PENIS, /datum/sprite_accessory/genital/penis/knotted::name, list("penis_size" = 4, "penis_girth" = 3, "penis_uses_skincolor" = FALSE, "penis_uses_skintones" = FALSE, "penis_sheath" = SPRITE_ACCESSORY_NONE, "penis_taur_mode" = FALSE))
	TEST_ASSERT(penis, "Couldn't give the taur a penis.")
	TEST_ASSERT(dirt_part_drawn(penis, stallion), "A taur's penis drawn as a human's, over the join, draws no front image, so its taur art can't be checked.")
	stallion.dna.features["penis_taur_mode"] = TRUE
	stallion.update_body()
	TEST_ASSERT(!dirt_part_drawn(penis, stallion), "A taur's penis drawn only behind the body is drawn for mess.")
	TEST_ASSERT(!(DIRT_ZONE_COCK in dirt_mess_regions(stallion, DIRT_PORTAL_PENIS)), "A one-part portal offers a taur's penis drawn only behind the body.")

/**
 * Fails unless a Big Legs body, its legs under the rider and no taur back, takes a back shot on the rider alone: no
 * splat in its taur slot, and no pools with its images.
 */
/datum/unit_test/dirt_taur_mess/proc/check_big_legs()
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(rider, /datum/sprite_accessory/taur/biglegs), "Couldn't make a human a Big Legs taur.")
	TEST_ASSERT(dirt_mess_land(rider, DIRT_ZONE_BACK), "A back shot on a Big Legs body didn't land.")
	var/datum/component/dirtiness/carrier = rider.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(length(carrier?.mess_splats), 1, "A back shot on a Big Legs body didn't leave the rider's skin one splat.")
	TEST_ASSERT(!length(carrier.part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR]), "A back shot on a Big Legs body splatted its taur slot.")
	SSdirt.finish_all()
	TEST_ASSERT(!length(pool_images(rider)), "A Big Legs body draws pools.")

/**
 * Fails unless a taur body's dirt at Tall, Tallest and Short height is its Average dirt moved by the rider's height
 * alone. A horse takes a light back shot, whose pools keep off its rider's waist. A naga takes four heavy ones, whose
 * pools reach that waist (check_rider_height()). A second naga takes them and a plunge into mud, drawn under its rider
 * too.
 */
/datum/unit_test/dirt_taur_mess/proc/check_rider_heights()
	var/mob/living/carbon/human/consistent/horse = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(horse), "Couldn't make a human a horse taur.")
	TEST_ASSERT(dirt_mess_place(horse, DIRT_ZONE_BACK, 2, 0), "A back shot on a horse taur didn't land.")
	var/mob/living/carbon/human/consistent/naga = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(naga, /datum/sprite_accessory/taur/naga), "Couldn't make a human a naga taur.")
	var/mob/living/carbon/human/consistent/plunged = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(plunged, /datum/sprite_accessory/taur/naga), "Couldn't make a second human a naga taur.")
	for(var/variant in 0 to 3)
		TEST_ASSERT(dirt_mess_place(naga, DIRT_ZONE_BACK, 4, variant) && dirt_mess_place(plunged, DIRT_ZONE_BACK, 4, variant), "A heavy back shot on a naga taur didn't land.")
	TEST_ASSERT(dirt_land(plunged, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), "A plunge into mud landed nowhere on a naga taur.")
	SSdirt.finish_all()
	check_rider_height(horse, "A horse taur")
	check_rider_height(naga, "A naga taur", TRUE)
	check_rider_height(plunged, "A naga taur plunged into mud", TRUE, TRUE)

/**
 * Fails unless a taur body's dirt at Tall, Tallest and Short height is its Average dirt moved by the rider's height
 * alone. The rider owns the pixels its sprites are drawn on once its chest's height filters stretch them. It doesn't
 * own those where the taur body's layers are drawn over it, or any others. Each pixel the taur body shows at both
 * heights keeps its Average dirt. Each pixel the rider uncovers keeps the dirt a deposit drew there under the Average
 * rider. Else it takes the dirt of the pixel just below its run of uncovered pixels, and a glint there goes on as body.
 * It takes none if the taur body doesn't show that pixel at Average height. Each layer shows its own pixels alone, so
 * nothing the rider covers is drawn.
 *
 * Arguments:
 * - rider: The taur, at Average height, holding back shots.
 * - kind_name: The taur's kind, as the failures name it.
 * - reaches_waist: Whether its dirt reaches its rider's waist, so a taller rider uncovers some of it.
 * - deposit_under: Whether it holds a deposit drawn under its Average rider, which a taller rider uncovers in places
 *   where the dirt just below differs.
 */
/datum/unit_test/dirt_taur_mess/proc/check_rider_height(mob/living/carbon/human/rider, kind_name, reaches_waist = FALSE, deposit_under = FALSE)
	var/datum/component/dirtiness/carrier = rider.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_drawing/drawing = carrier?.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	TEST_ASSERT(drawing?.request, "[kind_name]'s body asks for no masks.")
	var/datum/dirt_mask_job/average = made_job(drawing.request)
	TEST_ASSERT(average.masks && !average.failed, "[kind_name]'s body's masks weren't made at Average height.")
	var/list/stack = dirt_taur_stack()
	var/list/over_rider = stack.Copy(stack.Find(DIRT_TAUR_RIDER) + 1)
	for(var/height in list(HUMAN_HEIGHT_TALL, HUMAN_HEIGHT_TALLEST, HUMAN_HEIGHT_SHORT))
		rider.set_mob_height(height)
		SSdirt.finish_all()
		drawing = carrier.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
		var/datum/dirt_mask_request/request = drawing?.request
		TEST_ASSERT(request?.rows, "[kind_name]'s body asks for masks without its rider's rows at height [height].")
		// the row of the rider's sprites each row shows, through its chest's height filters in the order they're drawn
		var/list/shows = list()
		for(var/row in 0 to ICON_SIZE_Y - 1)
			shows += row
		var/stretched = FALSE
		for(var/image/chest_image as anything in rider.drawn_limb_icons(BODY_ZONE_CHEST))
			for(var/dm_filter/height_filter as anything in chest_image.filters)
				if(height_filter.type != "displace")
					continue
				stretched = TRUE
				var/icon/map = icon(height_filter.icon)
				var/list/moved_rows = new /list(ICON_SIZE_Y)
				for(var/row in 0 to ICON_SIZE_Y - 1)
					var/colour = map.GetPixel(floor(map.Width() / 2), ICON_SIZE_Y - row)
					var/source_row = colour ? floor(row + (rgb2num(colour)[2] - 128) / 127 * height_filter.size + 0.5) : row
					if(source_row >= 0 && source_row < ICON_SIZE_Y)
						moved_rows[row + 1] = shows[source_row + 1]
				shows = moved_rows
			if(stretched)
				break
		TEST_ASSERT(stretched, "[kind_name]'s chest isn't stretched at height [height].")
		var/datum/dirt_mask_job/job = made_job(request)
		TEST_ASSERT(job.masks && !job.failed, "[kind_name]'s body's masks weren't made at height [height].")
		var/alist/shown_by_layer = job.layers_shown()
		var/ridden = 0
		var/misplaced = 0
		var/unowned = 0
		var/compared = 0
		var/moved = 0
		var/misfilled = 0
		var/uncovered_dirt = 0
		// uncovered pixels whose own deposit isn't the dirt just below them
		var/kept_apart = 0
		var/unshown = 0
		var/wrong_layer = 0
		for(var/direction in dirt_mask_directions())
			var/datum/dirt_surface/surface = job.template.surfaces[direction]
			var/list/owners = dirt_taur_owners(request.shape_source, surface, direction, rows = request.rows)
			var/list/average_owners = average.taur_owners[direction]
			var/datum/dirt_pixels/average_map = average.merged[direction]
			var/datum/dirt_pixels/pixel_map = job.merged[direction]
			for(var/layer_key, entry in shown_by_layer)
				var/alist/shown = entry
				for(var/index in shown[direction])
					if(owners[index] != layer_key)
						wrong_layer++
			var/last_index = length(owners)
			for(var/index in 1 to last_index)
				var/owner = owners[index]
				var/row = floor((index - 1) / DIRT_TAUR_WIDTH)
				var/column = index - 1 - row * DIRT_TAUR_WIDTH - DIRT_TAUR_INSET
				var/source_row = shows[row + 1]
				var/on_sprite = column >= 0 && column < ICON_SIZE_X && !isnull(source_row) && DIRT_PIXEL_ZONE(surface.flags_of[source_row * ICON_SIZE_X + column + 1])
				if(owner == DIRT_TAUR_RIDER)
					ridden++
					if(!on_sprite)
						misplaced++
					continue
				if(on_sprite && !(owner in over_rider))
					unowned++
				if(!owner)
					continue
				var/role = pixel_map.roles[index]
				if(role)
					var/alist/layer_shown = shown_by_layer[owner]
					var/list/indexes = layer_shown[direction]
					if(!(index in indexes))
						unshown++
				var/average_owner = average_owners[index]
				if(average_owner != DIRT_TAUR_RIDER)
					if(average_map.roles[index])
						compared++
					if(role != average_map.roles[index] || pixel_map.thicknesses[index] != average_map.thicknesses[index])
						moved++
					continue
				// an uncovered pixel takes its dirt from the pixel just below the run of uncovered pixels under it
				var/below
				for(below = index + DIRT_TAUR_WIDTH, below <= last_index, below += DIRT_TAUR_WIDTH)
					if(average_owners[below] != DIRT_TAUR_RIDER || !owners[below] || owners[below] == DIRT_TAUR_RIDER)
						break
				var/wanted_role = null
				var/wanted_thickness = null
				if(below <= last_index && average_owners[below] && average_owners[below] != DIRT_TAUR_RIDER)
					wanted_role = average_map.roles[below]
					wanted_thickness = average_map.thicknesses[below]
				if(wanted_role == DIRT_ROLE_GLINT)
					wanted_role = DIRT_ROLE_BODY
				var/own_role = average_map.roles[index]
				if(own_role)
					if(wanted_role && (wanted_role != own_role || wanted_thickness != average_map.thicknesses[index]))
						kept_apart++
					wanted_role = own_role
					wanted_thickness = average_map.thicknesses[index]
				if(role != wanted_role || (role && pixel_map.thicknesses[index] != wanted_thickness))
					misfilled++
				if(role)
					uncovered_dirt++
		TEST_ASSERT(ridden, "[kind_name]'s body gives its rider no pixels at height [height], so the height can't be checked.")
		TEST_ASSERT(!misplaced, "[kind_name]'s body gives its rider [misplaced] pixels at height [height] where its stretched sprites draw nothing.")
		TEST_ASSERT(!unowned, "[kind_name]'s body keeps [unowned] pixels at height [height] that its rider's stretched sprites are drawn over.")
		TEST_ASSERT(!wrong_layer, "[kind_name]'s body shows [wrong_layer] pixels at height [height] on a layer that doesn't show them there.")
		TEST_ASSERT(compared, "[kind_name]'s body has no Average dirt on what it shows at height [height], so its dirt can't be compared.")
		TEST_ASSERT(!moved, "[kind_name]'s body's dirt differs from its Average dirt on [moved] pixels it shows at both heights, at height [height].")
		TEST_ASSERT(!misfilled, "[kind_name]'s body's dirt on [misfilled] pixels its rider uncovers at height [height] isn't their own deposit or the dirt just below them.")
		TEST_ASSERT(!unshown, "[kind_name]'s body leaves [unshown] pixels of its dirt at height [height] off the layer that shows them.")
		if(reaches_waist && height > HUMAN_HEIGHT_MEDIUM)
			TEST_ASSERT(uncovered_dirt, "[kind_name]'s dirt reaching its rider's waist draws nothing on what its rider uncovers at height [height].")
		if(deposit_under && height > HUMAN_HEIGHT_MEDIUM)
			TEST_ASSERT(kept_apart, "[kind_name]'s deposit under its Average rider differs nowhere its rider uncovers at height [height] from the dirt just below, so keeping it can't be checked.")

/**
 * Returns the chest's cached images at the taur body's layers that draw no sprite of their own but hold others: the
 * pools.
 *
 * Arguments:
 * - body: The taur.
 */
/datum/unit_test/dirt_taur_mess/proc/pool_images(mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	. = list()
	var/static/list/taur_layers = list(-BODY_BEHIND_LAYER, -BODY_ADJ_LAYER, -UNDER_UNIFORM_LAYER, -BODY_FRONT_LAYER, -ABOVE_BODY_FRONT_HEAD_LAYER)
	for(var/image/drawn as anything in body.drawn_limb_icons(BODY_ZONE_CHEST))
		if((drawn.layer in taur_layers) && !drawn.icon && length(drawn.overlays))
			. += drawn

/**
 * Returns a taur source's states, layer by layer in the order they stack, as one line of text.
 *
 * Arguments:
 * - source: The source, or null.
 */
/datum/unit_test/dirt_taur_mess/proc/describe_layers(datum/dirt_taur_source/source)
	if(!source)
		return "none"
	var/list/parts = list()
	for(var/layer_key in dirt_taur_stack())
		var/list/states = source.layer_states[layer_key]
		if(length(states))
			parts += "[layer_key]: [jointext(states, " ")]"
	return "[source.icon] [jointext(parts, "; ")]"

/**
 * Returns where a worn wrapper is drawn and where its inset images go in it, as one line of text: the offsets of the
 * rider's 32x32 mess and of the pools on the 64x32 taur canvas.
 *
 * Arguments:
 * - standing: The wrapper, or null.
 */
/datum/unit_test/dirt_taur_mess/proc/describe_insets(mutable_appearance/standing)
	var/list/offsets = list("rider" = list(), "pools" = list())
	for(var/image/child as anything in standing?.overlays)
		if(child.blend_mode != BLEND_INSET_OVERLAY)
			continue
		var/list/kind_offsets = offsets[get_icon_dimensions(child.icon)["width"] == DIRT_TAUR_WIDTH ? "pools" : "rider"]
		kind_offsets |= "[child.pixel_w],[child.pixel_z]"
	return "wrapper [standing?.pixel_w],[standing?.pixel_z]; rider [jointext(offsets["rider"], " ")]; pools [jointext(offsets["pools"], " ")]"

/**
 * Returns the pixels an inset mask draws facing one way, as indexes on the taur canvas: the pools' own, or the rider's
 * 32x32 mask moved onto the body's tile in its middle.
 *
 * Arguments:
 * - mask: The registered mask icon.
 * - direction: The direction.
 * - wide: Whether it's a 64x32 mask on the taur canvas.
 */
/datum/unit_test/dirt_taur_mess/proc/inset_pixels(mask, direction, wide)
	RETURN_TYPE(/list)
	. = list()
	var/icon/sprite = icon(mask)
	var/width = wide ? DIRT_TAUR_WIDTH : ICON_SIZE_X
	for(var/row in 0 to ICON_SIZE_Y - 1)
		for(var/column in 0 to width - 1)
			if(sprite.GetPixel(column + 1, ICON_SIZE_Y - row, null, direction))
				. += row * DIRT_TAUR_WIDTH + column + (wide ? 0 : DIRT_TAUR_INSET) + 1

/**
 * A person carries DIRT_MAX_SPLATS splats at most, counted across their skin, their parts and what they wear, and
 * past it the oldest go first. A human in a jumpsuit and a labcoat, breasts drawn above all clothing, takes
 * DIRT_MAX_SPLATS + 1 huge shots: on the face's skin, on the labcoat with the breasts' share, and on the jumpsuit.
 * At the cap a landing takes the oldest splat off before anything is drawn, so a face landing that evicts a face splat
 * asks for one mask at most, and a heavy shot that tops the face's newest splat and starts another asks for exactly
 * one, counted with the mask cache at its limit. Drawn, it all adds four overlays at most, and nothing to tg's shared
 * limb icon cache: a dirty limb's images are kept on its mob, which a wash drops, mess landed again draws afresh, and a
 * limb severed or swapped takes with it, the new limb drawn afresh, even every limb at once as a species change swaps
 * them.
 */
/datum/unit_test/dirt_mess_cap
	parent_type = /datum/unit_test/dirt_genital_test
	/// The keys put in SSdirt.masks to fill it to its limit, until forget_fillers().
	var/list/fillers = list()

/// Takes the fillers out of the mask cache if the cap's checks stopped before they did.
/datum/unit_test/dirt_mess_cap/Destroy()
	forget_fillers()
	return ..()

/// Takes the keys that filled SSdirt.masks out of it, so it keeps real masks again.
/datum/unit_test/dirt_mess_cap/proc/forget_fillers()
	for(var/filler in fillers)
		SSdirt.masks.forget(filler)
	fillers.Cut()

/datum/unit_test/dirt_mess_cap/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "The breasts need genitals, which the config disables.")
		return
	// whatever earlier tests left queued is made first
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/breasts = make_breasts(body, 7)
	TEST_ASSERT(breasts, "Couldn't give the body breasts.")
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	var/obj/item/clothing/suit/coat = allocate(/obj/item/clothing/suit/toggle/labcoat)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING) && body.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "Couldn't dress the body in a jumpsuit and a labcoat.")
	TEST_ASSERT(breasts.apply_visibility_label("Custom") && breasts.apply_layering_label("Above all clothing"), "Couldn't draw the breasts above all clothing.")
	SSdirt.finish_all()
	var/clean_overlays = length(body.overlays)
	var/first_serial = SSdirt.serial + 1
	var/huge = dirt_mess_amount_levels(DIRT_MESS_AMOUNT_HUGE)
	// the face first, so at the cap the oldest splats lie on the surface a face landing changes
	var/face_landings = ceil(DIRT_MAX_SPLATS / 2)
	var/list/other_zones = dirt_mess_zones() - DIRT_ZONE_FACE
	// tg's limb cache is shared by every body: a dirty limb's key almost never comes back, so it mustn't add entries
	var/cached_limbs = length(body.limb_icon_cache)
	for(var/landing in 1 to DIRT_MAX_SPLATS + 1)
		var/zone = landing <= face_landings ? DIRT_ZONE_FACE : other_zones[(landing - face_landings - 1) % length(other_zones) + 1]
		dirt_mess_land(body, zone, levels = huge)
		SSdirt.finish_all()
	TEST_ASSERT_EQUAL(length(body.limb_icon_cache) - cached_limbs, 0, "Filling the cap added entries to tg's limb icon cache.")
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	var/datum/component/dirtiness/coat_carrier = coat.GetComponent(/datum/component/dirtiness)
	var/datum/component/dirtiness/jumpsuit_carrier = jumpsuit.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(length(own?.part_mess_splats[ORGAN_SLOT_BREASTS]) && coat_carrier?.mess_count() && jumpsuit_carrier?.mess_count(), "The landings left nothing on the breasts, the labcoat or the jumpsuit, so the cap can't be checked across them.")
	var/list/serials = held_serials(body)
	TEST_ASSERT_EQUAL(length(serials), DIRT_MAX_SPLATS, "The skin, the breasts and the clothes hold [length(serials)] splats past the cap, not [DIRT_MAX_SPLATS].")
	TEST_ASSERT(!(first_serial in serials), "The first splat wasn't taken off past the cap.")
	TEST_ASSERT_EQUAL(min(serials), SSdirt.serial - DIRT_MAX_SPLATS + 1, "The splats kept past the cap aren't the newest.")

	// the mask cache at its limit, as a long round leaves it: each key asked for drops another
	for(var/filler in 1 to SSdirt.masks.limit)
		fillers += "dirt_mess_cap filler [filler]"
		SSdirt.masks.store_value(fillers[filler], FALSE)
	var/heavy = dirt_mess_amount_levels(DIRT_MESS_AMOUNT_HEAVY)
	var/added_keys = face_keys_added(body, heavy)
	TEST_ASSERT(added_keys <= 1, "A heavy shot at the cap asked for [added_keys] new masks, not one at most.")
	// a normal shot takes the new level 2 splat to 3, then a heavy one tops it and starts a level 1 splat
	face_keys_added(body, 1)
	added_keys = face_keys_added(body, heavy)
	var/list/skin_splats = own.mess_splats
	var/datum/dirt_splat/topped = skin_splats[length(skin_splats) - 1]
	var/datum/dirt_splat/started = skin_splats[length(skin_splats)]
	TEST_ASSERT(topped.level == DIRT_MESS_MAX_LEVEL && started.level == 1, "A heavy shot on a level 3 face splat left levels [topped.level] and [started.level], not [DIRT_MESS_MAX_LEVEL] and 1.")
	TEST_ASSERT_EQUAL(added_keys, 1, "A heavy shot overflowing into a new splat at the cap asked for [added_keys] new masks, not one.")
	TEST_ASSERT_EQUAL(length(held_serials(body)), DIRT_MAX_SPLATS, "Shots at the cap left [length(held_serials(body))] splats, not [DIRT_MAX_SPLATS].")
	forget_fillers()

	var/added_overlays = length(body.overlays) - clean_overlays
	TEST_ASSERT(added_overlays > 0 && added_overlays <= 4, "A mess at the cap added [added_overlays] overlays to the body, not one to four.")

	// a dirty limb's images are kept on its mob (limb_icons_for()): a wash drops them, and mess landed again draws afresh
	// under the key the limb is drawn with
	body.wash(CLEAN_WASH)
	// back to null: only then does a clean body's redraw read tg's cache without calling limb_icons_for()
	TEST_ASSERT_NULL(body.private_limb_icons, "Washing left the body's private limb images set, so its redraws still call limb_icons_for().")
	body.dropItemToGround(coat)
	body.dropItemToGround(jumpsuit)
	// the stomach rather than the chest, which the size 7 breasts cover; at the top level, which glazes the zone, so the
	// thighs' shot reaches both legs
	dirt_mess_land(body, DIRT_ZONE_STOMACH, levels = huge)
	dirt_mess_land(body, DIRT_ZONE_THIGHS, levels = huge)
	SSdirt.finish_all()
	var/list/chest_entry = body.private_limb_icons?[BODY_ZONE_CHEST]
	TEST_ASSERT(chest_entry, "A stomach shot on bare skin after a wash kept no private images for the chest.")
	TEST_ASSERT_EQUAL(chest_entry[1], body.icon_render_keys[BODY_ZONE_CHEST], "The chest's private images aren't kept under the key it's drawn with.")
	var/datum/dirt_masks/skin_masks = own.skin?.masks
	TEST_ASSERT(skin_masks, "A stomach shot on bare skin after a wash made no skin masks.")
	var/list/drawn_masks = list()
	for(var/image/drawn as anything in body.drawn_limb_icons(BODY_ZONE_CHEST))
		if(drawn.layer != -DIRT_SKIN_LAYER)
			continue
		for(var/image/mess_image as anything in drawn.overlays)
			drawn_masks |= mess_image.icon
	TEST_ASSERT(length(drawn_masks) == 1 && drawn_masks[1] == skin_masks.baked_by_limb[BODY_ZONE_CHEST], "After a wash the chest draws [length(drawn_masks)] baked icons, not the one its new skin masks hold.")

	// a limb leaving takes its private images with it: one severed, and one swapped while the body's drawing is held,
	// as a species change swaps them, so the new limb is drawn afresh under the same key
	TEST_ASSERT(body.private_limb_icons?[BODY_ZONE_R_LEG], "A thigh shot on bare skin kept no private images for the right leg.")
	var/obj/item/bodypart/right_leg = body.get_bodypart(BODY_ZONE_R_LEG)
	right_leg.drop_limb()
	qdel(right_leg)
	TEST_ASSERT_NULL(body.private_limb_icons?[BODY_ZONE_R_LEG], "A severed right leg left its private images on the body.")
	// the body left draws its mess once its new masks are made
	SSdirt.finish_all()
	var/list/left_entry = body.private_limb_icons?[BODY_ZONE_L_LEG]
	TEST_ASSERT(left_entry, "A thigh shot on bare skin kept no private images for the left leg.")
	var/left_key = body.icon_render_keys[BODY_ZONE_L_LEG]
	var/obj/item/bodypart/left_leg = body.get_bodypart(BODY_ZONE_L_LEG)
	var/obj/item/bodypart/new_left_leg = allocate(left_leg.type)
	// as /datum/species/proc/replace_body() swaps a limb
	body.living_flags |= STOP_OVERLAY_UPDATE_BODY_PARTS
	new_left_leg.replace_limb(body)
	new_left_leg.update_limb(is_creating = TRUE)
	body.living_flags &= ~STOP_OVERLAY_UPDATE_BODY_PARTS
	qdel(left_leg)
	body.update_body_parts()
	SSdirt.finish_all()
	TEST_ASSERT_EQUAL(body.icon_render_keys[BODY_ZONE_L_LEG], left_key, "The swapped left leg isn't drawn under the old leg's key, so keeping the old leg's images off it can't be checked.")
	var/list/new_left_entry = body.private_limb_icons?[BODY_ZONE_L_LEG]
	TEST_ASSERT(new_left_entry, "The swapped left leg draws no mess.")
	TEST_ASSERT_EQUAL(new_left_entry[1], left_key, "The swapped left leg's private images aren't kept under the key it's drawn with.")
	TEST_ASSERT(new_left_entry[2] != left_entry[2], "The swapped left leg was drawn with the old leg's private images.")

	// a species change between species sharing limbs swaps every limb, so a body is drawn holding no private images: a
	// chest whose only mess is its breasts' share, which a swap doesn't make again, comes back under its private key,
	// which tg's cache never holds
	var/mob/living/carbon/human/consistent/dressed = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/dressed_breasts = make_breasts(dressed, 7)
	var/obj/item/clothing/under/dressed_jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	var/obj/item/clothing/suit/dressed_coat = allocate(/obj/item/clothing/suit/toggle/labcoat)
	TEST_ASSERT(dressed_breasts && dressed.equip_to_slot_if_possible(dressed_jumpsuit, ITEM_SLOT_ICLOTHING) && dressed.equip_to_slot_if_possible(dressed_coat, ITEM_SLOT_OCLOTHING), "Couldn't give a second body breasts, a jumpsuit and a labcoat.")
	TEST_ASSERT(dressed_breasts.apply_visibility_label("Custom") && dressed_breasts.apply_layering_label("Above all clothing"), "Couldn't draw the second body's breasts above all clothing.")
	SSdirt.finish_all()
	dirt_mess_land(dressed, DIRT_ZONE_CHEST, levels = huge)
	SSdirt.finish_all()
	var/list/private_zones = list()
	for(var/private_zone in dressed.private_limb_icons)
		private_zones += private_zone
	TEST_ASSERT(length(private_zones) == 1 && private_zones[1] == BODY_ZONE_CHEST, "A chest shot on a labcoat kept private images for [english_list(private_zones)], not the chest alone, so a swap taking the last of them can't be checked.")
	var/chest_key = dressed.icon_render_keys[BODY_ZONE_CHEST]
	dressed.living_flags |= STOP_OVERLAY_UPDATE_BODY_PARTS
	dressed.dna.species.replace_body(dressed, old_species = dressed.dna.species)
	TEST_ASSERT_NULL(dressed.private_limb_icons, "The species swap left the body private images, so drawing it holding none isn't checked.")
	dressed.living_flags &= ~STOP_OVERLAY_UPDATE_BODY_PARTS
	dressed.update_body_parts()
	TEST_ASSERT_EQUAL(dressed.icon_render_keys[BODY_ZONE_CHEST], chest_key, "The chest isn't drawn under its key from before the species swap, so drawing it while the body holds no private images can't be checked.")
	var/list/dressed_entry = dressed.private_limb_icons?[BODY_ZONE_CHEST]
	TEST_ASSERT(dressed_entry?[1] == chest_key, "A chest swapped with every limb, taking the body's last private images, was drawn without them.")

/**
 * Lands a shot on a body's face, draws it once its masks are made, and returns how many masks SSdirt was asked for that
 * it hadn't been before.
 *
 * Arguments:
 * - body: The body.
 * - levels: How many levels the shot adds, from dirt_mess_amount_levels().
 */
/datum/unit_test/dirt_mess_cap/proc/face_keys_added(mob/living/carbon/human/body, levels)
	var/alist/before = alist()
	for(var/key in SSdirt.masks.entries)
		before[key] = TRUE
	dirt_mess_land(body, DIRT_ZONE_FACE, levels = levels)
	SSdirt.finish_all()
	. = 0
	// at the cache's limit each new key drops an old one, so the count of keys can't tell
	for(var/key in SSdirt.masks.entries)
		if(!before[key])
			.++

#undef DIRT_CORPUS
