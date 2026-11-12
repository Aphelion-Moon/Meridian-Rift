// compiled in, since CI's test world is deployed without code/
#define DIRT_CORPUS 'code/modules/unit_tests/~nova/dirt_corpus.json'
/// What check_mess_bake() bakes, one MD5 per baked icon.
#define DIRT_MESS_BAKE_DIGESTS "skin chest fd2daa4aab43b36d289b26fbbd3d00dc, skin head ee484de9840ee7476a8b79ae62896440, cloth 665142bb968ef2e94bd80c434b246333"
/// Where wag_containers() writes a baked icon out to read its frames.
#define DIRT_WAG_CHECK_FILE "data/dirt_drawing_wag.dmi"
/// Where tail_along() takes a tail to join the body: the tile's middle column, and the row 13 px over its floor.
#define DIRT_TAIL_HIP_COLUMN 15.5
#define DIRT_TAIL_HIP_ROW 18

/**
 * Dirt of every material drawn through the paths mess draws through. General dirt lands on each carrier that shows
 * where its cause reaches, kept to those limbs. It stacks, paints bare bodies, lands on odd bodies and washes off.
 * Sweat darkens the garments it lands on and is never left over. Parts drawn over the skin take the body's dirt. Taur
 * bodies, taur suits, tails, wings, ears and horns carry their own, and the hair carries its own while it shows.
 */
/datum/unit_test/dirt_drawing
	parent_type = /datum/unit_test/dirt_genital_test
	// a monkey's, a lizard's and a one-armed body's templates, and many bodies' masks made start to end
	priority = TEST_LONGER
	/// What a check put in SSdirt's caches under the keys real requests use, each list(cache, key), until
	/// forget_planted().
	var/list/planted = list()

/// Takes out of SSdirt's caches what a check that stopped early planted, so no later test draws it.
/datum/unit_test/dirt_drawing/Destroy()
	forget_planted()
	return ..()

/// Takes what the checks planted out of SSdirt's caches.
/datum/unit_test/dirt_drawing/proc/forget_planted()
	for(var/list/entry as anything in planted)
		var/datum/bulge_bounded_cache/cache = entry[1]
		cache.forget(entry[2])
	planted.Cut()

/datum/unit_test/dirt_drawing/Run()
	check_slime_colours()
	check_mess_bake()
	check_walk_carriers()
	check_stacking()
	check_bare_flips()
	check_odd_bodies()
	check_wash()
	check_wash_covered()
	check_band_interrupted()
	check_bare_shares()
	check_fields_shared()
	check_features_shared()
	check_painted_grease()
	check_sweat()
	check_wet_pending()
	check_parts_take_body_dirt()
	check_taur()
	check_appendages()
	check_wag_frames()
	check_wag_still()
	check_wag_moves()
	check_wag_carried()
	check_wag_cached()
	check_hair()
	check_hair_with_head()
	check_hat_hides_hair()
	check_hair_outer()
	check_shape_memo()
	check_packed_runs()
	check_limb_icons_kept()
	check_stain_over_sweat()
	check_raise_merge()
	check_dropped_jobs()
	check_waist_blood_direct()
	check_worn_after_body_change()
	check_one_direction_read()

/**
 * Cut hair (the parity corpus's hair_c) blasted with soot below the hair's first level holds the deposit but draws
 * nothing over the hair. A second blast raises it past that level, to 3. The hair draws it a band at a time, the same
 * as the blast drawn whole. It goes in one container over the hair, from the hair's own masks, on the hair's own
 * pixels alone. Restyled as a bob, the hair draws the masks a fresh body with bob hair draws for the same blast.
 * Washed, the hair draws clean.
 */
/datum/unit_test/dirt_drawing/proc/check_hair()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.set_hairstyle(/datum/sprite_accessory/hair/cut::name)
	var/datum/component/dirtiness/own = right_sided(body)
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_BLAST, DIRT_MATERIAL_SOOT, 1, 0), "A blast of soot landed nowhere on a human with cut hair.")
	var/list/held = deposits_in(own?.part_splats?[DIRT_CARRIER_HAIR])
	TEST_ASSERT_EQUAL(length(held), 1, "The hair holds [length(held)] deposits of a blast, not one.")
	SSdirt.finish_all()
	TEST_ASSERT(length(body.overlays_standing[HAIR_LAYER]), "The cut hair isn't drawn.")
	var/datum/dirt_drawing/drawing = own.part_drawings?[DIRT_CARRIER_HAIR]
	TEST_ASSERT(drawing?.masks, "The hair's level 1 blast wasn't made.")
	TEST_ASSERT(!drawing.masks.baked, "A level 1 blast, under the hair's first level, draws on the hair.")
	TEST_ASSERT(!length(hair_containers(body)), "The hair draws dirt of a level 1 blast.")
	dirt_land(body, DIRT_CAUSE_BLAST, DIRT_MATERIAL_SOOT, 2, 0)
	var/datum/dirt_splat/deposit = held[1]
	TEST_ASSERT_EQUAL(deposit.level, 3, "A second blast didn't raise the hair's deposit to level 3.")
	drawing = own.part_drawings?[DIRT_CARRIER_HAIR]
	var/datum/dirt_mask_job/job = drawing && SSdirt.mask_jobs[drawing.key]
	TEST_ASSERT(job, "The hair's level 3 blast wasn't queued.")
	SSdirt.finish_all()
	var/baked = drawing.masks?.baked
	TEST_ASSERT(baked, "The hair's level 3 blast wasn't made.")
	// drawn a band at a time, then kept to the crown (dirt_hair_crown()), and compared with the blast drawn whole
	var/datum/dirt_shape_source/hair_shape = drawing.request.shape_source
	var/datum/dirt_splat/blast = drawing.request.splats[1]
	var/datum/dirt_material/soot = dirt_material(blast.material)
	var/alist/blast_rasters = job.splat_rasters[1]
	for(var/direction in list(SOUTH, EAST))
		var/datum/dirt_pixels/whole = dirt_shape_rasterise(dirt_shape_mask(dirt_taur_owners(hair_shape, null, direction)), blast.cause, soot, blast.level, blast.variant, hair_shape.canvas, direction, DIRT_SURFACE_HAIR, drawing.request.side)
		TEST_ASSERT(blast_rasters[direction] == whole.drawn(), "The hair's blast facing [dir2text(direction)], drawn a band at a time, isn't the blast drawn whole.")
	var/list/containers = hair_containers(body)
	TEST_ASSERT_EQUAL(length(containers), 1, "The hair draws [length(containers)] containers of its dirt, not one.")
	var/mutable_appearance/container = containers[1]
	TEST_ASSERT(!container.icon && container.layer == -HAIR_LAYER, "The hair's dirt isn't drawn in a container at the hair's layer.")
	TEST_ASSERT_EQUAL(length(container.overlays), 1, "The hair's container holds [length(container.overlays)] images, not one.")
	var/mutable_appearance/held_image = container.overlays[1]
	TEST_ASSERT_EQUAL(held_image.icon, baked, "The hair's container doesn't draw the hair's masks.")
	var/datum/sprite_accessory/hair/hairstyle = SSaccessories.hairstyles_list[body.hairstyle]
	var/icon/baked_icon = icon(baked)
	var/drawn = 0
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/alist/on_hair = alist()
		for(var/index in dirt_sprite_pixels(hairstyle.icon, hairstyle.icon_state, direction))
			on_hair[index] = TRUE
		for(var/icon_y in 1 to ICON_SIZE_Y)
			for(var/icon_x in 1 to ICON_SIZE_X)
				if(!baked_icon.GetPixel(icon_x, icon_y, null, direction))
					continue
				drawn++
				var/index = (ICON_SIZE_Y - icon_y) * ICON_SIZE_X + icon_x
				TEST_ASSERT(on_hair[index], "The hair's blast draws off the hair at [icon_x],[icon_y] facing [dir2text(direction)].")
	TEST_ASSERT(drawn, "The hair's level 3 blast draws no pixels.")

	body.set_hairstyle(/datum/sprite_accessory/hair/bob::name)
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/fresh = allocate(/mob/living/carbon/human/consistent)
	fresh.set_hairstyle(/datum/sprite_accessory/hair/bob::name)
	var/datum/component/dirtiness/fresh_own = right_sided(fresh)
	TEST_ASSERT(dirt_land(fresh, DIRT_CAUSE_BLAST, DIRT_MATERIAL_SOOT, 3, 0), "A blast of soot landed nowhere on a human with bob hair.")
	SSdirt.finish_all()
	var/datum/dirt_drawing/fresh_hair = fresh_own.part_drawings?[DIRT_CARRIER_HAIR]
	var/datum/dirt_masks/fresh_masks = fresh_hair?.masks
	TEST_ASSERT(fresh_masks?.baked, "A fresh body's bob hair draws no blast, so the restyled hair can't be checked against it.")
	TEST_ASSERT_EQUAL(drawing.masks?.key, fresh_masks.key, "The hair restyled as a bob draws other masks than a fresh body's bob hair.")
	TEST_ASSERT_EQUAL(length(hair_containers(body)), 1, "The hair restyled as a bob draws [length(hair_containers(body))] containers of its dirt, not one.")

	body.wash(CLEAN_WASH)
	TEST_ASSERT(!length(own.part_splats?[DIRT_CARRIER_HAIR]), "A wash left dirt on the hair.")
	SSdirt.finish_all()
	TEST_ASSERT(!length(hair_containers(body, list(baked))) && !length(hair_containers(body)), "The washed hair still draws dirt.")

/**
 * A head that leaves the body takes the hair's dirt with it. A head swapped without the usual effects, as a species
 * change swaps it, leaves the hair's dirt on the body for the head that takes its place.
 */
/datum/unit_test/dirt_drawing/proc/check_hair_with_head()
	for(var/special in list(FALSE, TRUE))
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		body.set_hairstyle(/datum/sprite_accessory/hair/cut::name)
		var/datum/component/dirtiness/own = right_sided(body)
		// put on undrawn, so no masks are asked for
		own.add_dirt(DIRT_CAUSE_BLAST, DIRT_MATERIAL_SOOT, 3, NONE, 0, organ_slot = DIRT_CARRIER_HAIR)
		var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
		head.drop_limb(special)
		qdel(head)
		var/kept = length(own.part_splats?[DIRT_CARRIER_HAIR])
		TEST_ASSERT(special ? kept : !kept, special ? "A head taken off as a species change swaps it took the hair's dirt with it." : "A head that left the body left the hair's dirt on the body.")

/**
 * A helmet that hides the hair takes a blast of soot in its place. The hair under it takes none and draws none. With
 * the helmet off, the hair shows clean and takes the next blast.
 */
/datum/unit_test/dirt_drawing/proc/check_hat_hides_hair()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.set_hairstyle(/datum/sprite_accessory/hair/cut::name)
	var/obj/item/clothing/head/helmet/helmet = allocate(/obj/item/clothing/head/helmet)
	TEST_ASSERT(body.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD), "Couldn't put a helmet on the human.")
	TEST_ASSERT(body.obscured_slots & HIDEHAIR, "The helmet doesn't hide the hair, so a hat hiding it can't be checked.")
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_BLAST, DIRT_MATERIAL_SOOT, 3, 0), "A blast of soot landed nowhere on a human in a helmet.")
	var/datum/component/dirtiness/helmet_carrier = helmet.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT_EQUAL(length(deposits_in(helmet_carrier?.mess_splats)), 1, "The helmet hiding the hair didn't take the blast.")
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(!length(own?.part_splats?[DIRT_CARRIER_HAIR]), "The hair under a helmet that hides it took the blast.")
	SSdirt.finish_all()
	TEST_ASSERT(!length(hair_containers(body)), "The hair under a helmet that hides it draws dirt.")
	TEST_ASSERT(body.temporarilyRemoveItemFromInventory(helmet, force = TRUE), "Couldn't take the helmet off.")
	SSdirt.finish_all()
	TEST_ASSERT(length(body.overlays_standing[HAIR_LAYER]), "The hair isn't drawn with the helmet off.")
	TEST_ASSERT(!length(hair_containers(body)), "The hair draws dirt once the helmet that hid it comes off.")
	dirt_land(body, DIRT_CAUSE_BLAST, DIRT_MATERIAL_SOOT, 3, 0)
	TEST_ASSERT_EQUAL(length(deposits_in(own.part_splats?[DIRT_CARRIER_HAIR])), 1, "The hair the helmet hid doesn't take a blast once it's off.")

/**
 * Braided hair (Braid (Floorlength)) has its braid drawn over hats too. Blasted with soot, it takes the blast on the
 * braid together with the hair. It draws two containers of its dirt: the hair's at the hair's layer, and the braid's
 * at the braid's layer, after the braid. The braid's container draws only on the braid's own pixels, and draws facing
 * north too, where the braid shows. A helmet that hides the hair hides both. Hair without such a piece draws one
 * container (check_hair()).
 */
/datum/unit_test/dirt_drawing/proc/check_hair_outer()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.set_hairstyle(/datum/sprite_accessory/hair/braid::name)
	var/datum/sprite_accessory/hair/braid = SSaccessories.hairstyles_list[body.hairstyle]
	var/braid_state = braid?.hair_appendages_outer?[1]
	TEST_ASSERT(braid_state, "Braid (Floorlength) draws no piece over hats, so its dirt there can't be checked.")
	var/datum/component/dirtiness/own = right_sided(body)
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_BLAST, DIRT_MATERIAL_SOOT, 3, 0), "A blast of soot landed nowhere on a human with braided hair.")
	SSdirt.finish_all()
	var/datum/dirt_drawing/drawing = own.part_drawings?[DIRT_CARRIER_HAIR]
	var/datum/dirt_masks/masks = drawing?.masks
	var/braid_baked = masks?.baked_by_layer[DIRT_HAIR_OUTER]
	TEST_ASSERT(braid_baked && masks.baked_by_layer[DIRT_CARRIER_HAIR], "The braided hair's blast wasn't made on the hair and on the braid drawn over hats.")
	TEST_ASSERT_EQUAL(length(hair_containers(body)), 2, "Braided hair draws [length(hair_containers(body))] containers of its dirt, not two.")
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	var/list/images = head.get_hair_overlays()
	var/braid_at = 0
	var/container_at = 0
	for(var/position in 1 to length(images))
		var/image/drawn = images[position]
		if(drawn.layer != -OUTER_HAIR_LAYER)
			continue
		if(drawn.icon_state == braid_state)
			braid_at = position
		for(var/image/held as anything in drawn.overlays)
			if(held.icon == braid_baked)
				container_at = position
	TEST_ASSERT(braid_at, "The braid isn't drawn over hats.")
	TEST_ASSERT(container_at > braid_at, "The braid's dirt isn't drawn at the braid's layer, after it.")
	var/icon/baked_icon = icon(braid_baked)
	var/facing_north = 0
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/alist/on_braid = alist()
		for(var/index in dirt_sprite_pixels(braid.icon, braid_state, direction))
			on_braid[index] = TRUE
		for(var/icon_y in 1 to ICON_SIZE_Y)
			for(var/icon_x in 1 to ICON_SIZE_X)
				if(!baked_icon.GetPixel(icon_x, icon_y, null, direction))
					continue
				TEST_ASSERT(on_braid[(ICON_SIZE_Y - icon_y) * ICON_SIZE_X + icon_x], "The braid's dirt draws off the braid at [icon_x],[icon_y] facing [dir2text(direction)].")
				if(direction == NORTH)
					facing_north++
	TEST_ASSERT(facing_north, "The braid's dirt draws nothing facing north, where the braid shows.")

	var/obj/item/clothing/head/helmet/helmet = allocate(/obj/item/clothing/head/helmet)
	TEST_ASSERT(body.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD), "Couldn't put a helmet on the human with braided hair.")
	TEST_ASSERT(body.obscured_slots & HIDEHAIR, "The helmet doesn't hide the hair, so a hat hiding the braid's dirt can't be checked.")
	SSdirt.finish_all()
	TEST_ASSERT(!length(hair_containers(body)), "Braided hair under a helmet that hides it draws dirt on the hair or the braid.")

/**
 * Returns the images a body's hair layer draws its dirt in: those holding a baked image of dirt. That's one of `bakes`,
 * or if none are given, one from any masks SSdirt keeps or the body's drawn parts and hair draw. Only the hair's dirt
 * containers hold one, and the hair's own images never do. The search looks a few levels down into the layer's images.
 * That's because apply_overlay() nests the sprites sharing a layer in one holder, and its emissive blockers in a group
 * (prepare_bodypart_overlays()). The groups are left out, because the dirt's blockers in them are drawn from the same
 * bakes.
 *
 * Arguments:
 * - body: The body.
 * - bakes: The baked icons to look for, or null for every one held.
 */
/datum/unit_test/dirt_drawing/proc/hair_containers(mob/living/carbon/human/body, list/bakes)
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
	looked_at = islist(looked_at) ? looked_at.Copy() : list(looked_at)
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
 * A bare horse taur walking through mud takes it on its taur body, which draws it in a container over each of its
 * layers' images. The rider's skin takes it only off the legs, which the rider doesn't draw. The coat, drawn a band a
 * piece by its job, is the coat drawn whole (/datum/dirt_canvas_field/taur_coat). In a taur suit, the suit takes the
 * mud, and the taur body it hides takes none. The suit's upper part asks for walking's share off the legs alone. Its
 * hem band, drawn a band a piece by its job, is the coat of the taur body it hides. Smoke reaching the rider's torso
 * lands on the suit's upper part over it, and none lands on the skin the suit hides. The suit draws its walking mud as
 * its hem band, one inset image on the taur canvas round its tile. The suit's upper part draws its dirt as clothing,
 * one inset image on the body's tile over the hem band. Each lands on the suit's sprite, and a wash clears both.
 * The suit then walks in mud again, and is taken off and worn by a biped. It draws the mud from the biped's template,
 * kept to the limbs walking reaches, the legs among them. Another taur suit walks through dust, which reaches the legs
 * alone. It draws its hem band and asks for nothing over the rider until a splash lands. Worn by a biped, it draws that
 * dust on the legs. A 64x64 hat on a taur isn't drawn as a taur suit.
 */
/datum/unit_test/dirt_drawing/proc/check_taur()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(rider), "Couldn't make the human a horse taur.")
	var/datum/component/dirtiness/own = right_sided(rider)
	TEST_ASSERT(dirt_land(rider, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud landed nowhere on a bare taur.")
	var/list/held = deposits_in(own?.part_splats?[ORGAN_SLOT_EXTERNAL_TAUR])
	TEST_ASSERT_EQUAL(length(held), 1, "A bare taur's body holds [length(held)] deposits of walking mud, not one.")
	var/legs = DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG)
	for(var/datum/dirt_splat/deposit as anything in deposits_in(own.mess_splats))
		TEST_ASSERT(!(deposit.limbs & legs), "The rider's skin took walking mud on legs it doesn't draw: limbs [deposit.limbs].")
	var/datum/dirt_drawing/drawing = own.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	if(drawing?.request && !SSdirt.mask_jobs[drawing.key])
		// another test made them before, so they're made again and the job makes the rasters
		SSdirt.masks.forget(drawing.key)
		drawing.forget(TRUE)
		rider.update_body_parts()
	var/datum/dirt_mask_job/job = drawing?.request && SSdirt.mask_jobs[drawing.key]
	TEST_ASSERT(job, "The bare taur's walking mud wasn't queued.")
	var/datum/dirt_mask_request/request = drawing.request
	var/datum/dirt_splat/walked = held[1]
	var/datum/dirt_material/mud = dirt_material(walked.material)
	// the queued job draws the coat a band a piece, never from rasters kept before
	SSdirt.rasters.forget(shape_raster_key(request, walked))
	SSdirt.finish_all()
	TEST_ASSERT(length(drawing.masks?.baked_by_layer), "The taur body's walking mud wasn't made.")
	for(var/layer_key, baked in drawing.masks.baked_by_layer)
		TEST_ASSERT(holds_baked(rider, BODY_ZONE_CHEST, baked), "The taur body's [layer_key] layer draws no container of its walking mud.")
	// the coat as its job drew it, a band a piece
	var/alist/coat_rasters = job.splat_rasters[1]
	for(var/direction in list(SOUTH, EAST))
		var/datum/dirt_pixels/whole = dirt_taur_coat(request.shape_source, DIRT_CAUSE_WALK, mud, walked.level, walked.variant, direction)
		TEST_ASSERT_EQUAL(coat_rasters[direction], whole.drawn(), "The bare taur's walking mud facing [dir2text(direction)], drawn a band a piece, isn't the coat drawn whole.")

	var/mob/living/carbon/human/consistent/suited = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(suited), "Couldn't make a second human a horse taur.")
	var/obj/item/clothing/suit/utility/bomb_suit/suit = allocate(/obj/item/clothing/suit/utility/bomb_suit)
	TEST_ASSERT(suited.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Couldn't put a taur suit on the taur.")
	TEST_ASSERT(dirt_taur_fitted(suit, suited), "The bomb suit isn't drawn as a taur suit, so a taur suit's dirt can't be checked.")
	var/datum/component/dirtiness/suited_own = right_sided(suited)
	TEST_ASSERT(dirt_land(suited, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud landed nowhere on a taur in a taur suit.")
	var/datum/component/dirtiness/suit_carrier = suit.GetComponent(/datum/component/dirtiness)
	held = deposits_in(suit_carrier?.mess_splats)
	TEST_ASSERT_EQUAL(length(held), 1, "A taur suit holds [length(held)] deposits of walking mud, not one.")
	TEST_ASSERT(!length(suited_own?.part_splats?[ORGAN_SLOT_EXTERNAL_TAUR]), "The taur body under a taur suit took walking mud.")
	walked = held[1]
	TEST_ASSERT(walked.limbs & legs, "A taur suit's walking mud doesn't hold the legs: limbs [walked.limbs].")
	// the hem band draws walking on the legs as the coat, so the upper part asks only for the hands walking reaches
	request = suit_carrier.cloth?.request
	TEST_ASSERT(request, "A taur suit's upper part asked for no masks of its walking mud.")
	TEST_ASSERT_EQUAL(length(deposits_in(request.splats)), 1, "A taur suit's upper part asked for [length(deposits_in(request.splats))] deposits of walking mud, not one.")
	for(var/datum/dirt_splat/deposit as anything in deposits_in(request.splats))
		TEST_ASSERT_EQUAL(deposit.limbs, walked.limbs & ~legs, "A taur suit's upper part asked for walking mud on limbs [deposit.limbs], not on those walking reaches off the legs.")
	// the queued job draws the hem band a band a piece, never from rasters kept before
	drawing = suit_carrier.taur_cloth
	if(drawing?.request && !SSdirt.mask_jobs[drawing.key])
		SSdirt.masks.forget(drawing.key)
		drawing.forget(TRUE)
		suit.update_slot_icon()
	job = drawing?.request && SSdirt.mask_jobs[drawing.key]
	TEST_ASSERT(job, "The taur suit's walking mud on the taur canvas wasn't queued.")
	request = drawing.request
	SSdirt.rasters.forget(shape_raster_key(request, walked))
	// the suit covers the rider's torso, so smoke reaching it lands on the suit there, and on none of the skin it hides
	dirt_land(suited, DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 3, 0)
	for(var/datum/dirt_splat/deposit as anything in deposits_in(suited_own.mess_splats))
		TEST_ASSERT(!(deposit.limbs & DIRT_LIMB_BIT(DIRT_LIMB_TORSO)), "The skin under a taur suit's torso took smoke: limbs [deposit.limbs].")
	var/datum/dirt_splat/smoked
	for(var/datum/dirt_splat/deposit as anything in deposits_in(suit_carrier.mess_splats))
		if(deposit.cause == DIRT_CAUSE_SMOKE)
			smoked = deposit
	TEST_ASSERT(smoked && (smoked.limbs & DIRT_LIMB_BIT(DIRT_LIMB_TORSO)), "A taur suit's upper part over the rider's torso didn't take smoke reaching it.")
	SSdirt.finish_all()
	// smoke isn't the taur body's, so the hem band's job still holds the walking mud alone, the bare horse's coat
	TEST_ASSERT(length(job.splat_rasters) && job.splat_rasters[1], "The taur suit's job for its walking mud on the taur canvas holds no rasters.")
	for(var/direction in list(SOUTH, EAST))
		TEST_ASSERT_EQUAL(job.splat_rasters[1][direction], coat_rasters[direction], "A taur suit's walking mud facing [dir2text(direction)] on the taur canvas isn't the coat of the taur body it hides.")
	var/image/root = bulge_drawn_root(suited.overlays_standing[SUIT_LAYER])
	var/image/sprite = bulge_drawn_leaf(root)
	TEST_ASSERT(sprite, "The taur suit isn't drawn.")
	var/list/shift = dirt_worn_shift(suit)
	var/hem_insets = 0
	var/hem_at = 0
	var/top_at = 0
	var/on_suit = 0
	var/top_on_suit = 0
	var/position = 0
	for(var/image/child as anything in root.overlays)
		position++
		if(child.blend_mode != BLEND_INSET_OVERLAY)
			continue
		var/icon/inset = icon(child.icon)
		if(get_icon_dimensions(child.icon)["width"] != DIRT_TAUR_WIDTH)
			TEST_ASSERT(!top_at, "A taur suit's upper part draws more than one inset image on the body's tile.")
			top_at = position
			for(var/direction in list(SOUTH, NORTH, EAST, WEST))
				for(var/index in dirt_sprite_pixels(sprite.icon, sprite.icon_state, direction, DIRT_TAUR_WIDTH))
					var/row = floor((index - 1) / DIRT_TAUR_WIDTH)
					var/column = index - row * DIRT_TAUR_WIDTH - shift[1]
					if(column >= 1 && column <= ICON_SIZE_X && inset.GetPixel(column, ICON_SIZE_Y - row, null, direction))
						top_on_suit++
			continue
		hem_insets++
		hem_at = position
		for(var/direction in list(SOUTH, NORTH, EAST, WEST))
			for(var/index in dirt_sprite_pixels(sprite.icon, sprite.icon_state, direction, DIRT_TAUR_WIDTH))
				var/row = floor((index - 1) / DIRT_TAUR_WIDTH)
				if(inset.GetPixel(index - row * DIRT_TAUR_WIDTH, ICON_SIZE_Y - row, null, direction))
					on_suit++
	TEST_ASSERT_EQUAL(hem_insets, 1, "A taur suit draws [hem_insets] inset images on the taur canvas, not one.")
	TEST_ASSERT(on_suit, "A taur suit's walking mud misses its sprite.")
	TEST_ASSERT(top_at > hem_at, "A taur suit's upper part draws no smoke or walking mud on the hands, or draws them under its hem band.")
	TEST_ASSERT(top_on_suit, "A taur suit's upper part's smoke and walking mud miss its sprite.")
	suited.wash(CLEAN_WASH)
	TEST_ASSERT(!suit_carrier.mess_count(), "A wash left dirt on the taur suit.")
	SSdirt.finish_all()
	TEST_ASSERT(!length(inset_images(suited, SUIT_LAYER)), "The washed taur suit still draws dirt on its hem band or its upper part.")
	TEST_ASSERT(dirt_land(suited, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud again landed nowhere on the washed taur suit.")
	// the wash deleted the suit's carrier, so the landing made it another
	suit_carrier = suit.GetComponent(/datum/component/dirtiness)
	held = deposits_in(suit_carrier.mess_splats)

	var/mob/living/carbon/human/consistent/biped = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(suited.temporarilyRemoveItemFromInventory(suit, force = TRUE) && biped.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Couldn't move the taur suit from the taur to a biped.")
	SSdirt.finish_all()
	var/datum/dirt_drawing/cloth = suit_carrier.cloth
	TEST_ASSERT(cloth?.masks?.baked && dirt_holds_deposits(cloth.request.splats), "The taur suit on a biped doesn't draw its walking mud.")
	TEST_ASSERT_EQUAL(dirt_template_key(cloth.request.zone_sources), dirt_template_key(dirt_zone_sources(biped)), "The taur suit on a biped draws its walking mud from another template than the biped's.")
	TEST_ASSERT_EQUAL(length(inset_images(biped, SUIT_LAYER)), 1, "The taur suit on a biped draws [length(inset_images(biped, SUIT_LAYER))] inset images, not one.")
	// walking's reach, which the suit took on the taur: the legs, and the hands beside them
	var/datum/dirt_splat/suit_deposit = held[1]
	var/datum/dirt_template/template = dirt_build_template_now(cloth.request.zone_sources)
	var/icon/baked_icon = icon(cloth.masks.baked)
	var/on_legs = 0
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/datum/dirt_surface/surface = template.surfaces[direction]
		for(var/icon_y in 1 to ICON_SIZE_Y)
			for(var/icon_x in 1 to ICON_SIZE_X)
				if(!baked_icon.GetPixel(icon_x, icon_y, null, direction))
					continue
				var/limb = DIRT_PIXEL_LIMB(surface.flags_of[(ICON_SIZE_Y - icon_y) * ICON_SIZE_X + icon_x])
				TEST_ASSERT(limb && (suit_deposit.limbs & DIRT_LIMB_BIT(limb)), "The taur suit on a biped draws walking mud off the limbs it reaches ([suit_deposit.limbs]) at [icon_x],[icon_y] facing [dir2text(direction)].")
				if(limb == DIRT_LIMB_R_LEG || limb == DIRT_LIMB_L_LEG)
					on_legs++
	TEST_ASSERT(on_legs, "The taur suit on a biped draws no walking mud on the legs.")

	// walking in dust reaches the legs alone, which the hem band draws, so the upper part has nothing to draw
	suited = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(suited), "Couldn't make a third human a horse taur.")
	suit = allocate(/obj/item/clothing/suit/utility/bomb_suit)
	TEST_ASSERT(suited.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Couldn't put a second taur suit on a taur.")
	right_sided(suited)
	dirt_land(suited, DIRT_CAUSE_WALK, DIRT_MATERIAL_DUST, 3, 0)
	SSdirt.finish_all()
	suit_carrier = suit.GetComponent(/datum/component/dirtiness)
	held = deposits_in(suit_carrier?.mess_splats)
	walked = LAZYACCESS(held, 1)
	TEST_ASSERT(dirt_taur_fitted(suit, suited) && length(held) == 1 && walked.limbs == legs, "A taur suit walking through dust isn't drawn as one, or holds [length(held)] deposits, not one on the legs alone (limbs [walked?.limbs]).")
	cloth = suit_carrier.cloth
	TEST_ASSERT(cloth?.absent && !cloth.request, "A taur suit's upper part asks for masks with only walking dust on the legs to draw, which its hem band draws.")
	var/list/worn = taur_suit_places(suited)
	TEST_ASSERT(worn[1] && suit_carrier.taur_cloth?.masks?.baked, "A taur suit's walking dust draws no hem band on the taur canvas.")
	TEST_ASSERT(!worn[2], "A taur suit's upper part draws an inset image on the body's tile with only walking dust on the legs to draw.")
	dirt_land(suited, DIRT_CAUSE_SPLASH, DIRT_MATERIAL_MUD, 3, 0)
	SSdirt.finish_all()
	cloth = suit_carrier.cloth
	worn = taur_suit_places(suited)
	TEST_ASSERT(cloth?.request && !cloth.absent && worn[2], "A taur suit's upper part that had nothing to draw draws nothing once a splash lands on it.")
	biped = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(suited.temporarilyRemoveItemFromInventory(suit, force = TRUE) && biped.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Couldn't move the second taur suit from the taur to a biped.")
	SSdirt.finish_all()
	cloth = suit_carrier.cloth
	// the splash covers the legs too, so the walking dust's own deposit is read rather than the pixels on the legs
	suit_deposit = LAZYACCESS(cloth?.request?.splats, 1)
	TEST_ASSERT(suit_deposit?.cause == DIRT_CAUSE_WALK && (suit_deposit.limbs & legs) && cloth.masks?.key == cloth.key, "A taur suit worn by a biped doesn't draw its walking dust on the legs.")

	var/obj/item/clothing/head/hats/hos/shako/hat = allocate(/obj/item/clothing/head/hats/hos/shako)
	TEST_ASSERT(rider.equip_to_slot_if_possible(hat, ITEM_SLOT_HEAD), "Couldn't put a 64x64 hat on the taur.")
	var/image/hat_sprite = bulge_drawn_leaf(bulge_drawn_root(rider.overlays_standing[HEAD_LAYER]))
	var/list/hat_size = hat_sprite && get_icon_dimensions(hat_sprite.icon)
	TEST_ASSERT(hat_size?["width"] == DIRT_TAUR_WIDTH && hat_size["height"] > ICON_SIZE_Y, "The hat isn't drawn 64x64, so it can't be told from a taur suit.")
	TEST_ASSERT(!dirt_taur_fitted(hat, rider), "A 64x64 hat on a taur is drawn as a taur suit.")

/**
 * Returns where a body's taur suit draws its inset images in its worn wrapper, as list(the hem band's place on the
 * taur canvas, the upper part's on the body's tile). Each is 0 if it isn't drawn.
 *
 * Arguments:
 * - body: The taur.
 */
/datum/unit_test/dirt_drawing/proc/taur_suit_places(mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	. = list(0, 0)
	var/image/root = bulge_drawn_root(body.overlays_standing[SUIT_LAYER])
	var/position = 0
	for(var/image/child as anything in root?.overlays)
		position++
		if(child.blend_mode == BLEND_INSET_OVERLAY)
			.[get_icon_dimensions(child.icon)["width"] == DIRT_TAUR_WIDTH ? 1 : 2] = position

/**
 * A winged lizard with horns and ears plunging into mud takes it on its tail, its wings, its horns and its ears. Each
 * draws it in a container over each of its layers' images. The tail never draws its still dirt while it wags. Once it
 * stops, it shows that dirt again from the same masks, which aren't made again. With its plunge taken off, its wag's
 * job goes. Washed and walking through mud, the lizard takes it on its tail, and at most two drips on its wings. Smoke
 * lands on its tail and wings but not its ears, which take only the field causes. The tail taken out while its smoke is
 * queued takes its dirt and that job with it. The lizard deleted then takes the jobs of its skin's and wings' smoke.
 */
/datum/unit_test/dirt_drawing/proc/check_appendages()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/lizard = allocate(/mob/living/carbon/human/consistent)
	lizard.set_species(/datum/species/lizard)
	var/list/colours = list("#5A8A4A", "#C8D8B0", "#3A2A20")
	lizard.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part(/datum/sprite_accessory/tails/lizard/short/twotone::name, colours)
	lizard.dna.mutant_bodyparts[FEATURE_HORNS] = build_mutant_part(/datum/sprite_accessory/horns/ram::name, colours)
	lizard.dna.mutant_bodyparts[FEATURE_WINGS] = build_mutant_part(/datum/sprite_accessory/wings/mammal/bat::name, colours)
	lizard.dna.mutant_bodyparts[FEATURE_EARS] = build_mutant_part(/datum/sprite_accessory/ears/external/bat::name, colours)
	lizard.dna.species.regenerate_organs(lizard)
	lizard.update_body(is_creating = TRUE)
	var/obj/item/organ/tail = lizard.get_organ_by_type(/obj/item/organ/tail)
	var/obj/item/organ/wings = lizard.get_organ_by_type(/obj/item/organ/wings)
	var/obj/item/organ/horns = lizard.get_organ_by_type(/obj/item/organ/horns)
	var/obj/item/organ/ears = lizard.get_organ_by_type(/obj/item/organ/ears_external)
	TEST_ASSERT(tail && wings && horns && ears, "Couldn't give the lizard a tail, wings, horns and ears.")
	var/list/parts = list(tail, wings, horns, ears)

	var/datum/component/dirtiness/own = right_sided(lizard)
	TEST_ASSERT(dirt_land(lizard, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), "A plunge into mud landed nowhere on a lizard.")
	for(var/obj/item/organ/part as anything in parts)
		var/list/held = deposits_in(own?.part_splats?[part.slot])
		TEST_ASSERT_EQUAL(length(held), 1, "The lizard's [part.name] holds [length(held)] deposits of a plunge, not one.")
	SSdirt.finish_all()
	for(var/obj/item/organ/part as anything in parts)
		var/datum/dirt_drawing/drawing = own.part_drawings?[part.slot]
		TEST_ASSERT(length(drawing?.masks?.baked_by_layer), "The lizard's [part.name] draws no plunge.")
		for(var/layer_key, baked in drawing.masks.baked_by_layer)
			TEST_ASSERT(holds_baked(lizard, part.bodypart_owner.body_zone, baked), "The lizard's [part.name] draws no container of its plunge at its [layer_key] layer.")

	var/datum/dirt_drawing/tail_drawing = own.part_drawings[tail.slot]
	var/datum/dirt_masks/tail_masks = tail_drawing.masks
	var/datum/bodypart_overlay/mutant/tail_overlay = tail.bodypart_overlay
	var/datum/dirt_shape_source/still_tail = tail_overlay.dirt_shape
	var/tail_zone = tail.bodypart_owner.body_zone
	TEST_ASSERT(lizard.wag_tail(), "Couldn't wag the lizard's tail.")
	var/wagging_drawn = FALSE
	for(var/image/drawn as anything in lizard.drawn_limb_icons(tail_zone))
		if(drawn.icon_state && findtextEx(drawn.icon_state, "wagging"))
			wagging_drawn = TRUE
	TEST_ASSERT(wagging_drawn, "The lizard's tail isn't drawn wagging, so its dirt over a wag can't be checked.")
	TEST_ASSERT(still_tail && tail_overlay.dirt_shape_source_of(tail.bodypart_owner) == still_tail, "The lizard's wagging tail isn't read still.")
	for(var/layer_key, baked in tail_masks.baked_by_layer)
		TEST_ASSERT(!holds_baked(lizard, tail_zone, baked), "The lizard's wagging tail draws its plunge at its [layer_key] layer.")
	lizard.unwag_tail()
	for(var/layer_key, baked in tail_masks.baked_by_layer)
		TEST_ASSERT(holds_baked(lizard, tail_zone, baked), "The lizard's tail draws no container of its plunge at its [layer_key] layer once it stops wagging.")
	TEST_ASSERT(tail_drawing.masks == tail_masks && !SSdirt.mask_jobs[tail_drawing.key], "A wag made the lizard's tail's masks again.")
	var/datum/dirt_mask_job/stopped = tail_drawing.wag && SSdirt.mask_jobs[tail_drawing.wag.key]
	TEST_ASSERT(stopped && own.remove_mess(own.part_splats[tail.slot][1]) == tail.slot, "The lizard's frames weren't queued, or its tail's plunge couldn't be taken off.")
	TEST_ASSERT(!(stopped in SSdirt.queue) && !SSdirt.mask_jobs[stopped.key], "The lizard's frames are still made after its tail's last splat was taken off.")

	lizard.wash(CLEAN_WASH)
	TEST_ASSERT(!length(own.part_splats), "A wash left dirt on the lizard's parts.")
	TEST_ASSERT(dirt_land(lizard, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud landed nowhere on a lizard.")
	TEST_ASSERT(length(deposits_in(own.part_splats?[tail.slot])) == 1 && length(deposits_in(own.part_splats?[wings.slot])) == 1, "Walking through mud didn't land on the lizard's tail and wings.")
	TEST_ASSERT(!length(own.part_splats?[ears.slot]) && !length(own.part_splats?[horns.slot]), "Walking through mud landed on the lizard's ears or horns.")
	SSdirt.finish_all()
	var/tail_drawn = 0
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		tail_drawn += part_pixels(own, tail, direction)
		var/wing_drawn = part_pixels(own, wings, direction)
		// two soft drips of five pixels at most
		TEST_ASSERT(wing_drawn <= 10, "Walking through mud draws [wing_drawn] pixels on the lizard's wings facing [dir2text(direction)], more than two drips.")
	TEST_ASSERT(tail_drawn, "Walking through mud draws nothing on the lizard's tail.")

	TEST_ASSERT(dirt_land(lizard, DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 3, 0), "Smoke landed nowhere on a lizard.")
	TEST_ASSERT(length(deposits_in(own.part_splats?[tail.slot])) == 2 && length(deposits_in(own.part_splats?[wings.slot])) == 2, "Smoke didn't land on the lizard's tail and wings.")
	TEST_ASSERT(!length(own.part_splats?[ears.slot]), "Smoke landed on the lizard's ears, which take only the field causes.")

	var/tail_slot = tail.slot
	var/datum/dirt_drawing/tail_smoke = own.part_drawings?[tail_slot]
	var/datum/dirt_mask_job/tail_job = tail_smoke && SSdirt.mask_jobs[tail_smoke.key]
	TEST_ASSERT(tail_job, "The lizard's tail's smoke wasn't queued, so its job going with the tail can't be checked.")
	tail.Remove(lizard, special = TRUE)
	TEST_ASSERT(!length(own.part_splats?[tail_slot]), "The tail taken out left its dirt on the lizard.")
	TEST_ASSERT(!(tail_job in SSdirt.queue) && SSdirt.mask_jobs[tail_job.key] != tail_job, "The tail taken out left the job of its smoke queued.")
	qdel(tail)
	var/list/drawings = list(own.skin)
	for(var/organ_slot, part_drawing in own.part_drawings)
		drawings += part_drawing
	var/list/waiting = list()
	for(var/datum/dirt_drawing/drawing in drawings)
		var/datum/dirt_mask_job/job = SSdirt.mask_jobs[drawing.key]
		if(job)
			waiting += job
	TEST_ASSERT(length(waiting) >= 2, "The lizard's skin and wings have [length(waiting)] jobs of their smoke queued, so the jobs going with the lizard can't be checked.")
	qdel(lizard)
	for(var/datum/dirt_mask_job/job as anything in waiting)
		TEST_ASSERT(!(job in SSdirt.queue) && SSdirt.mask_jobs[job.key] != job, "The lizard deleted left a job of its dirt queued.")

/**
 * Returns how many pixels a part's dirt draws in one direction, over its layers' baked images.
 *
 * Arguments:
 * - carrier: Its owner's carrier.
 * - part: The part's organ.
 * - direction: The direction.
 */
/datum/unit_test/dirt_drawing/proc/part_pixels(datum/component/dirtiness/carrier, obj/item/organ/part, direction)
	. = 0
	var/datum/dirt_drawing/drawing = carrier.part_drawings?[part.slot]
	for(var/layer_key, baked in drawing?.masks?.baked_by_layer)
		var/icon/sprite = icon(baked)
		for(var/icon_y in 1 to sprite.Height())
			for(var/icon_x in 1 to sprite.Width())
				if(sprite.GetPixel(icon_x, icon_y, null, direction))
					.++

/**
 * Returns whether a limb's cached images hold a container drawing a baked icon.
 *
 * Arguments:
 * - body: The body.
 * - zone: The limb's body zone.
 * - baked: The baked icon.
 */
/datum/unit_test/dirt_drawing/proc/holds_baked(mob/living/carbon/human/body, zone, baked)
	for(var/image/drawn as anything in body.drawn_limb_icons(zone))
		if(drawn.icon || !length(drawn.overlays))
			continue
		for(var/image/held as anything in drawn.overlays)
			if(held.icon == baked)
				return TRUE
	return FALSE

/**
 * What a body's drawn parts are read from is kept between draws, and read again on every change to it. Each change
 * below is drawn through update_body_parts() alone. A lizard's tail swapped for another accessory draws masks made for
 * the new tail. A taur body holding a pool takes walking mud, and its masks take both. The rider's leg swapped for a
 * digitigrade one has them made again. After each, the part draws the masks a fresh body in the same state draws. If
 * the rider's chest is drawn female by its gender alone, which nothing signals, the taur body's masks are asked for
 * from the sprites the rider draws now.
 */
/datum/unit_test/dirt_drawing/proc/check_shape_memo()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/lizard = shape_memo_lizard(/datum/sprite_accessory/tails/lizard/short/twotone::name)
	var/obj/item/organ/tail = lizard.get_organ_by_type(/obj/item/organ/tail)
	var/datum/component/dirtiness/own = lizard.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_drawing/tail_drawing = own?.part_drawings?[tail?.slot]
	TEST_ASSERT(tail_drawing?.masks, "The lizard's tail draws no plunge, so swapping it can't be checked.")
	var/short_key = tail_drawing.masks.key
	var/datum/bodypart_overlay/mutant/tail_overlay = tail.bodypart_overlay
	tail_overlay.set_appearance(/datum/sprite_accessory/tails/lizard/smooth)
	lizard.update_body_parts()
	SSdirt.finish_all()
	TEST_ASSERT(tail_drawing.masks?.key != short_key, "The lizard's tail swapped for a smooth one draws the short tail's masks.")
	var/mob/living/carbon/human/consistent/smooth = shape_memo_lizard(/datum/sprite_accessory/tails/lizard/smooth::name)
	var/obj/item/organ/smooth_tail = smooth.get_organ_by_type(/obj/item/organ/tail)
	var/datum/bodypart_overlay/mutant/smooth_overlay = smooth_tail?.bodypart_overlay
	TEST_ASSERT(smooth_overlay?.sprite_datum == tail_overlay.sprite_datum, "A fresh lizard's smooth tail isn't the accessory the swapped one draws.")
	check_drawn_as(lizard, smooth, tail.slot, "the lizard's tail swapped")

	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(rider), "Couldn't make the human a horse taur.")
	var/datum/component/dirtiness/rider_own = right_sided(rider)
	rider_own.add_mess(DIRT_ZONE_BACK, ORGAN_SLOT_EXTERNAL_TAUR, 2, 0)
	SSdirt.finish_all()
	var/datum/dirt_drawing/taur_drawing = rider_own.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	TEST_ASSERT(taur_drawing?.masks, "The taur body draws no pool, so a deposit joining it can't be checked.")
	TEST_ASSERT(dirt_land(rider, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud landed nowhere on a bare taur.")
	SSdirt.finish_all()
	TEST_ASSERT_EQUAL(length(taur_drawing.request?.splats), 2, "The taur body's masks once walking mud joins its pool take [length(taur_drawing.request?.splats)] splats, not the pool and the mud.")
	check_drawn_as(rider, shape_memo_taur(), ORGAN_SLOT_EXTERNAL_TAUR, "walking mud joining the taur body's pool")

	var/walked_key = taur_drawing.masks?.key
	var/obj/item/bodypart/taur_leg = rider.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(shape_memo_leg(rider), "Couldn't swap the rider's left leg for a digitigrade one.")
	qdel(taur_leg)
	TEST_ASSERT(dirt_zone_sources(rider)[BODY_ZONE_L_LEG], "The rider's digitigrade leg draws no sprite of its own, so the taur body's masks can't be checked against it.")
	rider.update_body_parts()
	SSdirt.finish_all()
	TEST_ASSERT(taur_drawing.masks?.key != walked_key, "The rider's leg swapped for a digitigrade one, the taur body draws the masks made before.")
	check_drawn_as(rider, shape_memo_taur(TRUE), ORGAN_SLOT_EXTERNAL_TAUR, "the rider's leg swapped for a digitigrade one")

	var/obj/item/bodypart/chest = rider.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(chest.is_dimorphic && chest.limb_gender == "m", "The rider's chest isn't drawn male, so drawing it female can't be checked.")
	var/datum/dirt_mask_request/male_request = taur_drawing.request
	chest.limb_gender = "f"
	rider.update_body_parts()
	TEST_ASSERT(taur_drawing.request && taur_drawing.request != male_request && dirt_template_key(taur_drawing.request.zone_sources) == dirt_template_key(dirt_zone_sources(rider)), "The rider's chest drawn female by its gender alone, the taur body's masks aren't asked for from the sprites it draws now.")
	// nothing more is checked of them, so they aren't made
	rider.wash(CLEAN_WASH)

/**
 * Checks that a part of a body draws the masks a fresh body in the same state draws. Their keys match, and each of the
 * part's layers holds its baked image in a container.
 *
 * Arguments:
 * - body: The body.
 * - fresh: The fresh body.
 * - organ_slot: The part's ORGAN_SLOT_* define.
 * - what: What changed on the body, for the messages.
 */
/datum/unit_test/dirt_drawing/proc/check_drawn_as(mob/living/carbon/human/body, mob/living/carbon/human/fresh, organ_slot, what)
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	var/datum/component/dirtiness/fresh_own = fresh?.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_drawing/drawing = own?.part_drawings?[organ_slot]
	var/datum/dirt_drawing/fresh_drawing = fresh_own?.part_drawings?[organ_slot]
	TEST_ASSERT(fresh_drawing?.masks, "A fresh body draws no masks to check [what] against.")
	TEST_ASSERT_EQUAL(drawing?.masks?.key, fresh_drawing.masks.key, "After [what], the part draws other masks than a fresh body in the same state.")
	var/obj/item/organ/part = body.get_organ_slot(organ_slot)
	for(var/layer_key, baked in drawing.masks.baked_by_layer)
		TEST_ASSERT(holds_baked(body, part.bodypart_owner.body_zone, baked), "After [what], the part draws no container of its masks at its [layer_key] layer.")

/**
 * Returns a lizard growing a tail, its dirtier side 1, plunged into mud with its masks made.
 *
 * Arguments:
 * - tail_name: The name of the tail's sprite accessory.
 */
/datum/unit_test/dirt_drawing/proc/shape_memo_lizard(tail_name)
	RETURN_TYPE(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/lizard = allocate(/mob/living/carbon/human/consistent)
	lizard.set_species(/datum/species/lizard)
	lizard.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part(tail_name, list("#5A8A4A", "#C8D8B0", "#3A2A20"))
	lizard.dna.species.regenerate_organs(lizard)
	lizard.update_body(is_creating = TRUE)
	right_sided(lizard)
	dirt_land(lizard, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0)
	SSdirt.finish_all()
	return lizard

/**
 * Returns a fresh horse taur, its dirtier side 1, with its masks made. Its taur body holds a pool and then walking mud,
 * and is drawn first with both. When asked, its left leg is swapped for a digitigrade one before either lands.
 *
 * Arguments:
 * - digitigrade: Whether to swap the left leg first.
 */
/datum/unit_test/dirt_drawing/proc/shape_memo_taur(digitigrade = FALSE)
	RETURN_TYPE(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	if(!give_taur(rider))
		return null
	if(digitigrade)
		var/obj/item/bodypart/taur_leg = rider.get_bodypart(BODY_ZONE_L_LEG)
		shape_memo_leg(rider)
		qdel(taur_leg)
		rider.update_body_parts()
	var/datum/component/dirtiness/own = right_sided(rider)
	// drawn by the landing after, so its masks are first asked for with both
	own.add_mess(DIRT_ZONE_BACK, ORGAN_SLOT_EXTERNAL_TAUR, 2, 0, redraw = FALSE)
	dirt_land(rider, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0)
	SSdirt.finish_all()
	return rider

/**
 * Swaps a body's left leg for a digitigrade one, as an attached leg would be, and returns whether it took. The leg it
 * had is left for the caller.
 *
 * Arguments:
 * - body: The body.
 */
/datum/unit_test/dirt_drawing/proc/shape_memo_leg(mob/living/carbon/human/body)
	var/obj/item/bodypart/leg/left/digitigrade/leg = allocate(/obj/item/bodypart/leg/left/digitigrade)
	return leg.replace_limb(body)

/**
 * A lizard's short tail wags in nine frames that rewind. It's plunged into mud and doused in ash. Its plunge, clipped
 * from a field drawn a band at a time, is the plunge drawn whole. Its douse drawn a band at a time is the douse drawn
 * whole. With the douse taken off and the tail wagging, it draws its dirt once its frames are made. Each layer gets a
 * container that plays the wag's frames forward and back at their delays, and the second frame's dirt lies on that
 * frame's sprite. Stopped and wagged again, it queues nothing. Smoke landing while it wags drops the frames, and none
 * are drawn until they're made anew. Mud landing before they're made drops their job. The same mud landing again
 * changes nothing, and keeps the job being made. Stopped while its frames for dried mud are made, it keeps their job
 * until red clay lands, and asks for none while it's still.
 */
/datum/unit_test/dirt_drawing/proc/check_wag_frames()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/lizard = allocate(/mob/living/carbon/human/consistent)
	lizard.set_species(/datum/species/lizard)
	lizard.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part(/datum/sprite_accessory/tails/lizard/short/twotone::name, list("#5A8A4A", "#C8D8B0", "#3A2A20"))
	lizard.dna.species.regenerate_organs(lizard)
	lizard.update_body(is_creating = TRUE)
	var/obj/item/organ/tail = lizard.get_organ_by_type(/obj/item/organ/tail)
	TEST_ASSERT(tail, "Couldn't give the lizard a tail.")
	var/zone = tail.bodypart_owner.body_zone
	var/datum/component/dirtiness/own = right_sided(lizard)
	TEST_ASSERT(dirt_land(lizard, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), "A plunge into mud landed nowhere on a lizard.")
	TEST_ASSERT(dirt_land(lizard, DIRT_CAUSE_DOUSE, DIRT_MATERIAL_ASH, 3, 0), "A douse of ash landed nowhere on a lizard.")
	var/datum/dirt_drawing/drawing = own.part_drawings[tail.slot]
	var/datum/dirt_mask_job/still_job = SSdirt.mask_jobs[drawing.key]
	TEST_ASSERT(still_job, "The lizard's tail's plunge and douse weren't queued.")
	SSdirt.finish_all()
	// compare the plunge's field, drawn a band a piece and clipped (field_for()), and the douse, drawn a band a piece,
	// with each drawn whole
	var/datum/dirt_shape_source/still = drawing.request.shape_source
	TEST_ASSERT_EQUAL(length(drawing.request.splats), 2, "The lizard's tail holds [length(drawing.request.splats)] deposits of a plunge and a douse, not two.")
	for(var/position in 1 to length(drawing.request.splats))
		var/datum/dirt_splat/deposit = drawing.request.splats[position]
		var/datum/dirt_material/material = dirt_material(deposit.material)
		var/alist/rasters = still_job.splat_rasters[position]
		for(var/direction in list(SOUTH, EAST))
			var/datum/dirt_pixels/whole = dirt_shape_deposit(still, dirt_taur_owners(still, null, direction), deposit.cause, material, deposit.level, deposit.variant, direction, DIRT_SURFACE_FUR, drawing.request.side)
			TEST_ASSERT(rasters[direction] == whole.drawn(), "The lizard's tail's [deposit.cause] facing [dir2text(direction)], drawn a band at a time, isn't the [deposit.cause] drawn whole.")
	// the wag checks take the plunge alone
	var/datum/dirt_splat/doused
	for(var/datum/dirt_splat/tail_splat as anything in own.part_splats[tail.slot])
		if(tail_splat.cause == DIRT_CAUSE_DOUSE)
			doused = tail_splat
	TEST_ASSERT(doused && own.remove_mess(doused) == tail.slot, "The lizard's tail's douse couldn't be taken off.")
	SSdirt.finish_all()
	TEST_ASSERT(lizard.wag_tail(), "Couldn't wag the lizard's tail.")
	SSdirt.finish_all()
	var/list/frames = wag_containers(lizard, zone)
	TEST_ASSERT(length(frames), "The lizard's wagging tail draws no dirt once its frames are made.")
	var/list/baked = list()
	for(var/list/drawn as anything in frames)
		TEST_ASSERT(length(drawn[2]) > 1 && drawn[3] ~= drawn[2], "The lizard's wagging tail's dirt plays at [json_encode(drawn[3])], not its wag's [json_encode(drawn[2])].")
		baked += drawn[1]
	// each layer's dirt in the second frame lies on that frame of the layer's own sprites
	var/dirty_pixels = 0
	var/off_sprite = 0
	for(var/list/layer_drawn as anything in frames)
		var/icon/dirt_icon = icon(layer_drawn[1])
		var/list/sprite_icons = list()
		for(var/image/sprite as anything in layer_drawn[4])
			sprite_icons += icon(sprite.icon, sprite.icon_state)
		for(var/direction in list(SOUTH, NORTH, EAST, WEST))
			for(var/icon_y in 1 to ICON_SIZE_Y)
				for(var/icon_x in 1 to ICON_SIZE_X)
					if(!dirt_icon.GetPixel(icon_x, icon_y, null, direction, 2))
						continue
					dirty_pixels++
					var/on_sprite = FALSE
					for(var/icon/sprite_icon as anything in sprite_icons)
						on_sprite ||= !isnull(sprite_icon.GetPixel(icon_x, icon_y, null, direction, 2))
					off_sprite += !on_sprite
	TEST_ASSERT(dirty_pixels && !off_sprite, "The lizard's wagging tail's dirt in its second frame draws [off_sprite] of its [dirty_pixels] pixels off that frame of its sprite.")
	lizard.unwag_tail()
	TEST_ASSERT(lizard.wag_tail() && !length(SSdirt.queue), "Wagging the lizard's tail again queued a job.")
	for(var/held in baked)
		TEST_ASSERT(holds_baked(lizard, zone, held), "The lizard's tail wagged again doesn't draw the frames it made.")
	TEST_ASSERT(dirt_land(lizard, DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 3, 0), "Smoke landed nowhere on the lizard.")
	TEST_ASSERT(!length(wag_containers(lizard, zone)), "The lizard's wagging tail draws dirt while its frames are made again for smoke.")
	var/datum/dirt_mask_job/pending = drawing.wag && SSdirt.mask_jobs[drawing.wag.key]
	TEST_ASSERT(pending && dirt_land(lizard, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "The lizard's frames for smoke weren't queued, or walking through mud landed nowhere on it.")
	TEST_ASSERT(!(pending in SSdirt.queue) && !SSdirt.mask_jobs[pending.key], "The lizard's frames for smoke are still made after mud landed on its tail before they were.")
	var/datum/dirt_mask_job/walked = drawing.wag && SSdirt.mask_jobs[drawing.wag.key]
	TEST_ASSERT(walked && dirt_land(lizard, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "The lizard's frames for smoke and mud weren't queued, or walking through mud again landed nowhere on it.")
	TEST_ASSERT((walked in SSdirt.queue) && SSdirt.mask_jobs[walked.key] == walked, "Walking through the same mud again, which changes nothing, dropped the lizard's frames being made.")
	SSdirt.finish_all()
	frames = wag_containers(lizard, zone)
	TEST_ASSERT(length(frames), "The lizard's wagging tail draws no dirt once its frames are made again for smoke and mud.")
	for(var/list/drawn as anything in frames)
		TEST_ASSERT(!(drawn[1] in baked) && drawn[3] ~= drawn[2], "The lizard's wagging tail draws its old frames after smoke and mud, or frames not playing its wag.")
	TEST_ASSERT(dirt_land(lizard, DIRT_CAUSE_WALK, DIRT_MATERIAL_DRIED_MUD, 3, 0), "Walking through dried mud landed nowhere on the lizard.")
	var/datum/dirt_mask_job/stopped = drawing.wag && SSdirt.mask_jobs[drawing.wag.key]
	lizard.unwag_tail()
	TEST_ASSERT((stopped in SSdirt.queue) && dirt_land(lizard, DIRT_CAUSE_WALK, DIRT_MATERIAL_RED_CLAY, 3, 0), "The lizard's frames for dried mud weren't queued, or were dropped as it stopped wagging, or walking through red clay landed nowhere on it.")
	TEST_ASSERT(!(stopped in SSdirt.queue) && !SSdirt.mask_jobs[stopped.key] && !(drawing.wag && SSdirt.mask_jobs[drawing.wag.key]), "The lizard's frames for dried mud are still made after red clay landed on its still tail, or its still tail queued frames.")

/**
 * A horse tail's wagging states are one frame each, drawing its still sprite's pixels. Plunged into mud and wagging, it
 * draws its still dirt at once, while a job finds out whether the wag shows the still's pixels. That job queues ahead
 * of animated wags' frames, but never ahead of the first job. Once the job finds it out, the tail draws only its still
 * dirt. Wagged again, it queues nothing.
 */
/datum/unit_test/dirt_drawing/proc/check_wag_still()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part(/datum/sprite_accessory/tails/mammal/wagging/horse::name, list("#8A6A4A", "#D8C8B0", "#3A2A20"))
	body.dna.species.regenerate_organs(body)
	body.update_body(is_creating = TRUE)
	var/obj/item/organ/tail = body.get_organ_by_type(/obj/item/organ/tail)
	TEST_ASSERT(tail, "Couldn't give the human a horse tail.")
	var/datum/component/dirtiness/own = right_sided(body)
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), "A plunge into mud landed nowhere on a human with a horse tail.")
	SSdirt.finish_all()
	var/datum/dirt_drawing/drawing = own.part_drawings?[tail.slot]
	TEST_ASSERT(length(drawing?.masks?.baked_by_layer), "The horse tail draws no plunge.")
	// two animated wags' frames queued first, taken out again before anything makes them
	var/datum/dirt_wag_source/animated = new
	animated.frames = 2
	var/datum/dirt_mask_request/animated_request = new(DIRT_MASKS_SHAPE, shape_source = animated)
	var/list/animated_jobs = list(new /datum/dirt_mask_job(animated_request, "first"), new /datum/dirt_mask_job(animated_request, "waiting"))
	for(var/datum/dirt_mask_job/animated_job as anything in animated_jobs)
		SSdirt.add(animated_job)
	var/wagged = body.wag_tail()
	var/list/order = list(SSdirt.queue.Find(animated_jobs[1]), SSdirt.queue.Find(drawing.wag && SSdirt.mask_jobs[drawing.wag.key]), SSdirt.queue.Find(animated_jobs[2]))
	SSdirt.queue -= animated_jobs
	TEST_ASSERT(wagged, "Couldn't wag the horse tail.")
	TEST_ASSERT(order ~= list(1, 2, 3), "The horse tail's one-frame wag's job queued at [order[2]], not between two animated wags' frames at [order[1]] and [order[3]].")
	var/zone = tail.bodypart_owner.body_zone
	var/wagging_drawn = FALSE
	for(var/image/drawn as anything in body.drawn_limb_icons(zone))
		wagging_drawn ||= findtextEx("[drawn.icon_state]", "wagging")
	TEST_ASSERT(wagging_drawn, "The horse tail isn't drawn wagging, so its dirt over a wag can't be checked.")
	var/list/still_baked = list()
	for(var/layer_key, baked in drawing.masks.baked_by_layer)
		TEST_ASSERT(holds_baked(body, zone, baked), "The wagging horse tail doesn't draw its still plunge at its [layer_key] layer while its wag is read.")
		still_baked += baked
	SSdirt.finish_all()
	// the still masks draw all the same if the job fails
	var/datum/dirt_masks/decided = drawing.wag && SSdirt.masks.fetch(drawing.wag.key)
	TEST_ASSERT(istype(decided) && decided.shows_still, "The horse tail's one-frame wag wasn't found to show its still sprite.")
	for(var/held in still_baked)
		TEST_ASSERT(holds_baked(body, zone, held), "The wagging horse tail doesn't draw its still plunge once its wag is read.")
	for(var/list/drawn as anything in wag_containers(body, zone))
		TEST_ASSERT(drawn[1] in still_baked, "The wagging horse tail, whose wag is its still sprite, draws dirt other than its still plunge.")
	body.unwag_tail()
	TEST_ASSERT(body.wag_tail() && !length(SSdirt.queue), "Wagging the horse tail again, its wag read as its still sprite, queued a job.")

/**
 * A wagging fox tail, its still dirt a patchy scatter (plant_still_dirt()), moves its dirt with it. Where two of its
 * frames that move it off its still sprite draw the same pixel of the tile, some draw other dirt there. So no one
 * pattern lies still on the screen as the tail sweeps through it.
 */
/datum/unit_test/dirt_drawing/proc/check_wag_moves()
	SSdirt.finish_all()
	var/mob/living/carbon/human/body = fox_tailed()
	var/obj/item/organ/tail = body.get_organ_by_type(/obj/item/organ/tail)
	TEST_ASSERT(tail, "Couldn't give the human a fox tail.")
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_FALL, DIRT_MATERIAL_MUD, 2, 0), "A fall of mud landed nowhere on a human with a fox tail.")
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_drawing/drawing = own.part_drawings?[tail.slot]
	TEST_ASSERT(drawing?.request && SSdirt.mask_jobs[drawing.key], "The fox tail's fall wasn't queued.")
	var/datum/dirt_shape_source/still = drawing.request.shape_source
	var/datum/dirt_mask_job/still_job = SSdirt.mask_jobs[drawing.key]
	var/raster_key = plant_still_dirt(drawing, FALSE)
	SSdirt.finish_all()
	TEST_ASSERT(took_planted(still_job, raster_key), "The fox tail's still masks weren't made from the dirt planted for them.")
	TEST_ASSERT(body.wag_tail(), "Couldn't wag the fox tail.")
	planted += list(list(SSdirt.masks, drawing.wag?.key))
	SSdirt.finish_all()
	TEST_ASSERT(drawing.wag?.masks, "The fox tail's frames weren't made.")
	var/shared = 0
	var/differ = 0
	for(var/direction, frames_entry in wag_frame_pixels(body, tail.bodypart_owner.body_zone, drawing.wag))
		var/list/still_shown = new /list(ICON_SIZE_X * ICON_SIZE_Y)
		for(var/index in dirt_shape_mask(dirt_taur_owners(still, null, direction)))
			still_shown[index] = TRUE
		// the frames showing the still sprite's pixels draw its dirt as it is
		var/list/moved = list()
		for(var/list/frame_entry as anything in frames_entry)
			if(!(frame_entry[1] ~= still_shown))
				moved += list(frame_entry)
		if(length(moved) < 2)
			continue
		var/list/first = moved[1]
		var/list/first_shown = first[1]
		var/list/first_colours = first[2]
		for(var/list/later as anything in moved.Copy(2))
			var/list/later_shown = later[1]
			var/list/later_colours = later[2]
			for(var/index in 1 to length(first_shown))
				if(first_shown[index] && later_shown[index])
					shared++
					differ += first_colours[index] != later_colours[index]
	TEST_ASSERT(shared, "The fox tail's frames share no pixel, so whether its dirt moves with it can't be checked.")
	TEST_ASSERT(differ, "The fox tail's patchy dirt draws the same on all [shared] pixels its frames share with its first: it lies still on the screen as the tail sweeps through it.")
	forget_planted()

/**
 * A tail's plunge into mud, as its still tail draws it, is painted on the tail's far third alone (plant_still_dirt()).
 * While it wags, every frame draws the plunge on its own far third, as far along the tail from where it joins the body
 * as the still tail draws it, however the frame moves the tail. The tails are a fox's, and a feline taur's, whose tail
 * joins its rump far behind the rider and swings its tip nearer the rider than its base mid-wag.
 */
/datum/unit_test/dirt_drawing/proc/check_wag_carried()
	SSdirt.finish_all()
	carried_far_third(fox_tailed(), "fox tail")
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(taur, /datum/sprite_accessory/taur/feline), "Couldn't make the human a feline taur.")
	right_sided(taur)
	carried_far_third(taur, "feline taur's tail")

/**
 * Checks that a body's tail carries its still dirt, painted on its far third, onto every frame of its wag
 * (check_wag_carried()).
 *
 * Arguments:
 * - body: The body, its tail still, its dirtier side its right.
 * - tail_name: What the failures call the tail.
 */
/datum/unit_test/dirt_drawing/proc/carried_far_third(mob/living/carbon/human/body, tail_name)
	var/obj/item/organ/tail = body.get_organ_by_type(/obj/item/organ/tail)
	TEST_ASSERT(tail, "Couldn't give the body a [tail_name].")
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), "A plunge into mud landed nowhere on a body with a [tail_name].")
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_drawing/drawing = own.part_drawings?[tail.slot]
	TEST_ASSERT(drawing?.request && SSdirt.mask_jobs[drawing.key], "The [tail_name]'s plunge wasn't queued.")
	var/list/size = dirt_canvases()[drawing.request.shape_source.canvas]
	var/alist/still_roots = alist()
	var/list/painted_along = list(0, 0)
	var/datum/dirt_mask_job/still_job = SSdirt.mask_jobs[drawing.key]
	var/raster_key = plant_still_dirt(drawing, TRUE, still_roots, painted_along)
	SSdirt.finish_all()
	TEST_ASSERT(took_planted(still_job, raster_key), "The [tail_name]'s still masks weren't made from the dirt planted for them.")
	TEST_ASSERT(body.wag_tail(), "Couldn't wag the [tail_name].")
	planted += list(list(SSdirt.masks, drawing.wag?.key))
	SSdirt.finish_all()
	TEST_ASSERT(painted_along[2] && length(drawing.masks?.baked_by_layer), "The [tail_name] draws no plunge painted on its far third.")
	TEST_ASSERT(drawing.wag?.masks, "The [tail_name]'s frames weren't made.")
	var/dirty = 0
	var/frame_along = 0
	for(var/direction, frames_entry in wag_frame_pixels(body, tail.bodypart_owner.body_zone, drawing.wag))
		var/frame = 0
		for(var/list/frame_entry as anything in frames_entry)
			frame++
			var/list/shown = frame_entry[1]
			var/list/colours = frame_entry[2]
			// measured from the frame's pixel nearest the still tail's root, because a base doesn't move as it wags
			var/list/along = tail_along(shown, size[1], tail_root(shown, size[1], still_roots[direction]))
			var/frame_dirty = 0
			var/near = 0
			for(var/index in 1 to length(along))
				if(isnull(along[index]) || !colours[index])
					continue
				frame_dirty++
				near += along[index] < 1 / 3
				frame_along += along[index]
			dirty += frame_dirty
			TEST_ASSERT(near <= frame_dirty * 0.05, "The [tail_name]'s frame [frame] facing [dir2text(direction)] draws [near] of its [frame_dirty] pixels of its plunge on the third of the tail by the body, painted on its far third: its dirt isn't the still tail's, carried along it.")
	TEST_ASSERT(dirty, "The [tail_name]'s frames draw none of its plunge painted on its far third.")
	var/gap = abs(frame_along / dirty - painted_along[1] / painted_along[2])
	TEST_ASSERT(gap <= 0.1, "The [tail_name]'s frames draw its plunge [round(gap, 0.01)] of the tail's length from where its still tail draws it.")
	forget_planted()

/**
 * A wolf tail's wag reads no sprite while SSdirt.wag_sprites keeps its sprites, whatever dirt they were kept under. A
 * body plunged in mud bakes its wag from what a splashed body's bake kept: its still sprite's and each frame's pixels,
 * and where each takes the still's dirt from. It draws what the same plunge baked cold draws, pixel for pixel, the
 * pixels the splash doesn't draw included.
 */
/datum/unit_test/dirt_drawing/proc/check_wag_cached()
	// an earlier check's wolf tail would have kept them
	SSdirt.wag_sprites.clear()
	var/list/jobs = list()
	// the splash's bake keeps the sprites, the first plunge bakes from them, and the second bakes cold
	for(var/list/landing as anything in list(list(DIRT_CAUSE_SPLASH, 2), list(DIRT_CAUSE_PLUNGE, 3), list(DIRT_CAUSE_PLUNGE, 3)))
		SSdirt.finish_all()
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		body.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part(/datum/sprite_accessory/tails/mammal/wagging/wolf::name, list("#8A6A4A", "#D8C8B0", "#3A2A20"))
		body.dna.species.regenerate_organs(body)
		body.update_body(is_creating = TRUE)
		var/datum/component/dirtiness/own = right_sided(body)
		var/obj/item/organ/tail = body.get_organ_by_type(/obj/item/organ/tail)
		TEST_ASSERT(tail && dirt_land(body, landing[1], DIRT_MATERIAL_MUD, landing[2], 0), "Couldn't land a [landing[1]] of mud on a human with a wolf tail.")
		SSdirt.finish_all()
		// drop the warm plunge's frames, kept under the same key, and the kept sprites, so the last bakes cold
		if(length(jobs) == 2)
			var/datum/dirt_mask_job/plunged = jobs[2]
			SSdirt.masks.forget(plunged.key)
			SSdirt.wag_sprites.clear()
		TEST_ASSERT(body.wag_tail(), "Couldn't wag the wolf tail.")
		var/datum/dirt_drawing/drawing = own.part_drawings?[tail.slot]
		var/datum/dirt_mask_job/job = drawing?.wag && SSdirt.mask_jobs[drawing.wag.key]
		TEST_ASSERT(job, "The wolf tail's frames weren't queued.")
		SSdirt.finish_all()
		TEST_ASSERT(length(job.masks?.baked_by_layer), "The wolf tail's frames weren't made.")
		jobs += job
	var/datum/dirt_mask_job/splashed = jobs[1]
	var/datum/dirt_mask_job/warm = jobs[2]
	var/datum/dirt_mask_job/cold = jobs[3]
	TEST_ASSERT(!length(warm.wanted_sprites) && !length(warm.frame_sheets), "The plunged wolf tail's wag, the splashed one's sprites kept, read [length(warm.wanted_sprites)] directions of its still sprite and loaded [length(warm.frame_sheets)] wagging states.")
	TEST_ASSERT(length(cold.wanted_sprites) && length(cold.frame_sheets), "The plunged wolf tail's wag read no sprite with none kept, so a bake reading none can't be told from it.")
	var/datum/dirt_wag_source/wag = cold.request.shape_source
	var/list/size = dirt_canvases()[wag.canvas]
	var/alist/warm_bakes = warm.masks.baked_by_layer
	TEST_ASSERT_EQUAL(length(warm_bakes), length(cold.masks.baked_by_layer), "The plunged wolf tail's wag, its sprites kept, bakes another number of layers than baked cold.")
	// a pixel the plunge draws and the splash doesn't, which a cache keeping the splash's dirt would lose
	var/fresh = FALSE
	for(var/layer_key, cold_baked in cold.masks.baked_by_layer)
		TEST_ASSERT(warm_bakes[layer_key], "The plunged wolf tail's wag, its sprites kept, bakes no [layer_key] layer.")
		var/list/layer_entry = wag.layer_frames[layer_key]
		// where it rewinds, its frames play back again after its last (frame_masks())
		var/frames = length(layer_entry[1])
		if(layer_entry[2])
			frames = 2 * frames - 2
		var/icon/cold_icon = icon(cold_baked)
		var/icon/warm_icon = icon(warm_bakes[layer_key])
		var/splashed_baked = splashed.masks.baked_by_layer[layer_key]
		var/icon/splashed_icon = splashed_baked ? icon(splashed_baked) : null
		var/differ = 0
		for(var/direction in list(SOUTH, NORTH, EAST, WEST))
			for(var/frame in 1 to frames)
				for(var/icon_y in 1 to size[2])
					for(var/icon_x in 1 to size[1])
						var/drawn = cold_icon.GetPixel(icon_x, icon_y, null, direction, frame)
						differ += drawn != warm_icon.GetPixel(icon_x, icon_y, null, direction, frame)
						if(drawn && !fresh)
							fresh = !splashed_icon?.GetPixel(icon_x, icon_y, null, direction, frame)
		TEST_ASSERT(!differ, "The plunged wolf tail's [layer_key] frames, its sprites kept from the splashed one's, draw [differ] pixels other than baked cold.")
	TEST_ASSERT(fresh, "The plunged wolf tail's frames draw no pixel the splashed one's don't, so sprites kept with the splash's dirt can't be told from sprites kept whatever the dirt.")

/// Returns a naked human growing a fox tail, their dirtier side their right, as the parity corpus draws a side.
/datum/unit_test/dirt_drawing/proc/fox_tailed()
	RETURN_TYPE(/mob/living/carbon/human)
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part(/datum/sprite_accessory/tails/mammal/wagging/vulpkanin/fox::name, list("#8A6A4A", "#D8C8B0", "#3A2A20"))
	body.dna.species.regenerate_organs(body)
	body.update_body(is_creating = TRUE)
	right_sided(body)
	return body

/**
 * Puts a tail's still dirt where the job for its still masks takes it from, as its first splat's rasters in
 * SSdirt.rasters, before that job runs. The dirt is painted on the still tail's far third (tail_along()), or as a
 * patchy scatter of 2x2 blocks over it, in a thickness the bake already packs. The rasters and the still masks made
 * from them are noted in `planted`. Returns the rasters' key (shape_raster_key()), for took_planted().
 *
 * Arguments:
 * - drawing: The tail's drawing, its masks queued.
 * - far: Whether to paint the far third rather than the scatter.
 * - roots: alist(direction = the still tail's root, tail_root()), filled in, or null.
 * - painted_along: list(the sum of the painted pixels' places along the tail, how many there are), added to, or null.
 */
/datum/unit_test/dirt_drawing/proc/plant_still_dirt(datum/dirt_drawing/drawing, far, alist/roots, list/painted_along)
	var/datum/dirt_shape_source/still = drawing.request.shape_source
	var/datum/dirt_splat/splat = drawing.request.splats[1]
	var/list/size = dirt_canvases()[still.canvas]
	var/width = size[1]
	// a thickness already packed takes no new one of the 16 codes (dirt_thickness_code())
	var/list/packed = dirt_packed_thicknesses()
	var/thickness = length(packed) ? packed[1] : 0.6
	. = shape_raster_key(drawing.request, splat)
	planted += list(list(SSdirt.rasters, .), list(SSdirt.masks, drawing.key))
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/list/shown = new /list(width * size[2])
		for(var/index in dirt_shape_mask(dirt_taur_owners(still, null, direction)))
			shown[index] = TRUE
		var/root = tail_root(shown, width, null)
		if(roots)
			roots[direction] = root
		var/list/along = tail_along(shown, width, root)
		var/datum/dirt_pixels/painted = new(width, size[2])
		for(var/index in 1 to length(along))
			if(isnull(along[index]))
				continue
			var/row = floor((index - 1) / width)
			var/column = index - 1 - row * width
			if(far ? along[index] < 2 / 3 : (floor(column / 2) + floor(row / 2)) % 2)
				continue
			painted.put_index(index, DIRT_ROLE_BODY, thickness)
			if(painted_along)
				painted_along[1] += along[index]
				painted_along[2] += 1
		SSdirt.rasters.store_direction(., direction, painted.drawn())

/**
 * Returns where these checks measure a tail from, independently of the module: its pixel nearest an index of its
 * canvas. Without an index, it's the pixel nearest the hips (DIRT_TAIL_HIP_COLUMN, DIRT_TAIL_HIP_ROW, on a wider canvas
 * centred on the tile as dirt_canvases() places it). A wag frame's root is its pixel nearest the still tail's root,
 * because a base doesn't move.
 *
 * Arguments:
 * - shown: The tail's pixels, TRUE or null by index.
 * - width: Its canvas's width.
 * - near: The index, or null.
 */
/datum/unit_test/dirt_drawing/proc/tail_root(list/shown, width, near)
	var/target_column = DIRT_TAIL_HIP_COLUMN + (width - ICON_SIZE_X) / 2
	var/target_row = DIRT_TAIL_HIP_ROW
	if(near)
		target_row = floor((near - 1) / width)
		target_column = near - 1 - target_row * width
	var/root_reach = INFINITY
	for(var/index in 1 to length(shown))
		if(!shown[index])
			continue
		var/row = floor((index - 1) / width)
		var/reach = (index - 1 - row * width - target_column) ** 2 + (row - target_row) ** 2
		if(reach < root_reach)
			. = index
			root_reach = reach

/**
 * Returns how far along a tail each of its pixels lies, by index, as these checks measure it independently of the
 * module. That's its steps inside the tail from the root (tail_root()), across, down or diagonal, over the most steps
 * any pixel takes, so 0 to 1. It's null off the tail and where the steps don't reach.
 *
 * Arguments:
 * - shown: The tail's pixels, TRUE or null by index.
 * - width: Its canvas's width.
 * - root: The pixel it's measured from, or null for none.
 */
/datum/unit_test/dirt_drawing/proc/tail_along(list/shown, width, root)
	RETURN_TYPE(/list)
	var/count = length(shown)
	var/height = count / width
	var/list/steps = new /list(count)
	if(!root)
		return steps
	steps[root] = 0
	var/list/queue = list(root)
	var/longest = 0
	for(var/position in 1 to count)
		if(position > length(queue))
			break
		var/index = queue[position]
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		for(var/near_row in max(0, row - 1) to min(height - 1, row + 1))
			for(var/near_column in max(0, column - 1) to min(width - 1, column + 1))
				var/near = near_row * width + near_column + 1
				if(shown[near] && isnull(steps[near]))
					steps[near] = steps[index] + 1
					longest = max(longest, steps[near])
					queue += near
	for(var/index in 1 to count)
		if(!isnull(steps[index]))
			steps[index] = longest ? steps[index] / longest : 0
	return steps

/**
 * Returns a limb's wagging sprites and the dirt a wag's masks draw over them, their layers taken together, frame by
 * frame as the wag plays forward, on the wag's canvas: alist(direction = one list(its sprites' pixels as TRUE or null
 * by index, the dirt's colour on them by index) per frame).
 *
 * Arguments:
 * - body: The body.
 * - zone: The limb's body zone.
 * - frames_drawing: The wag's drawing (/datum/dirt_drawing/var/wag), its masks made.
 */
/datum/unit_test/dirt_drawing/proc/wag_frame_pixels(mob/living/carbon/human/body, zone, datum/dirt_drawing/frames_drawing)
	RETURN_TYPE(/alist)
	var/datum/dirt_wag_source/wag = frames_drawing.request.shape_source
	var/list/size = dirt_canvases()[wag.canvas]
	var/width = size[1]
	var/height = size[2]
	var/list/sprites = list()
	var/list/sprite_frames = list()
	for(var/image/sprite as anything in body.drawn_limb_icons(zone))
		if(!findtextEx("[sprite.icon_state]", "wagging"))
			continue
		sprites += icon(sprite.icon, sprite.icon_state)
		var/list/delays
		for(var/list/state_data as anything in icon_metadata(sprite.icon)?["states"])
			if(state_data["name"] == sprite.icon_state)
				delays = state_data["delay"]
				break
		sprite_frames += max(1, length(delays))
	var/list/dirt_icons = list()
	var/list/dirt_frames = list()
	for(var/layer_key, baked in frames_drawing.masks.baked_by_layer)
		dirt_icons += icon(baked)
		var/list/layer_entry = wag.layer_frames[layer_key]
		dirt_frames += length(layer_entry[1])
	var/frames = 1
	for(var/count in sprite_frames)
		frames = max(frames, count)
	. = alist()
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/list/by_frame = list()
		for(var/frame in 1 to frames)
			var/list/shown = new /list(width * height)
			var/list/colours = new /list(width * height)
			for(var/row in 0 to height - 1)
				for(var/column in 0 to width - 1)
					var/index = row * width + column + 1
					for(var/position in 1 to length(sprites))
						var/icon/sprite = sprites[position]
						if(sprite.GetPixel(column + 1, height - row, null, direction, min(frame, sprite_frames[position])))
							shown[index] = TRUE
							break
					// check_wag_frames() checks the dirt off the sprite
					if(!shown[index])
						continue
					for(var/position in 1 to length(dirt_icons))
						var/icon/dirt_icon = dirt_icons[position]
						colours[index] ||= dirt_icon.GetPixel(column + 1, height - row, null, direction, min(frame, dirt_frames[position]))
			by_frame += list(list(shown, colours))
		.[direction] = by_frame

/**
 * Returns the dirt a limb draws over its wagging images: list(its icon, the delays the wagging state at its layer plays,
 * the delays its icon plays, the wagging images at its layer) for each image of a dirt container at a wagging sprite's
 * layer (holds_baked()). A state's delays are its DMI's, then back again for a state that rewinds. An icon built at run
 * time can't flag a rewind, and the dirt's delays are read from its icon written out.
 *
 * Arguments:
 * - body: The body.
 * - zone: The limb's body zone.
 */
/datum/unit_test/dirt_drawing/proc/wag_containers(mob/living/carbon/human/body, zone)
	RETURN_TYPE(/list)
	. = list()
	var/list/drawn = body.drawn_limb_icons(zone)
	for(var/image/container as anything in drawn)
		if(container.icon || !length(container.overlays))
			continue
		var/list/wagged
		var/list/layer_sprites = list()
		for(var/image/sprite as anything in drawn)
			if(sprite.layer != container.layer || !findtextEx("[sprite.icon_state]", "wagging"))
				continue
			layer_sprites += sprite
			if(wagged)
				continue
			for(var/list/state_data as anything in icon_metadata(sprite.icon)?["states"])
				if(state_data["name"] != sprite.icon_state)
					continue
				var/list/delays = state_data["delay"] || list(1)
				wagged = delays.Copy()
				if(state_data["rewind"])
					for(var/frame in length(delays) - 1 to 2 step -1)
						wagged += delays[frame]
				break
		// the limb's other dirt, such as the skin's, draws at no wagging sprite's layer
		if(!wagged)
			continue
		for(var/image/held as anything in container.overlays)
			fdel(DIRT_WAG_CHECK_FILE)
			fcopy(held.icon, DIRT_WAG_CHECK_FILE)
			// the macro's call can't take ?[] after it
			var/list/metadata = rustg_dmi_read_metadata(DIRT_WAG_CHECK_FILE)
			var/list/states = metadata?["states"]
			fdel(DIRT_WAG_CHECK_FILE)
			var/list/state_data = length(states) ? states[1] : null
			. += list(list(held.icon, wagged, state_data?["delay"] || list(1), layer_sprites))

/**
 * Large bare breasts take the body's general dirt on their own pixels. Smoke's soot at level 3 lands on the skin and
 * gives them no share. They draw it in a container just over their front image, every pixel on their own sprite in a
 * direction they draw over the skin. A chest shot then gives them a share, drawn over the soot in the same container
 * from their own masks.
 */
/datum/unit_test/dirt_drawing/proc/check_parts_take_body_dirt()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Parts need genitals, which the config disables.")
		return
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/breasts/breasts = make_breasts(body, 7)
	TEST_ASSERT(breasts, "Couldn't give the body breasts.")
	var/datum/component/dirtiness/own = right_sided(body)
	// variant 2 wears the design whose soot reaches the chest below the collarbones, where the breasts lie
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 3, 2), "Smoke's soot landed nowhere on a bare body with breasts.")
	TEST_ASSERT(!length(own.part_mess_splats[ORGAN_SLOT_BREASTS]), "Smoke's soot gave the breasts a share.")
	SSdirt.finish_all()
	var/datum/dirt_part_source/drawn = dirt_part_drawn(breasts, body)
	TEST_ASSERT(drawn, "The breasts don't draw.")
	var/list/held = part_container_images(body, drawn)
	TEST_ASSERT_EQUAL(length(held), 1, "The breasts' container holds [length(held)] baked images of the body's soot, not one.")
	var/list/counted = pixels_off_part(held[1], drawn)
	TEST_ASSERT(counted[2] && !counted[1], "The body's soot on the breasts draws [counted[2]] pixels, [counted[1]] of them off their sprite where it draws over the skin.")

	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST), "A chest shot didn't land.")
	TEST_ASSERT_EQUAL(length(own.part_mess_splats[ORGAN_SLOT_BREASTS]), 1, "The breasts didn't take one share of a chest shot.")
	SSdirt.finish_all()
	var/datum/dirt_drawing/share = own.part_drawings?[ORGAN_SLOT_BREASTS]
	TEST_ASSERT(share?.masks?.baked, "The breasts' share wasn't made.")
	held = part_container_images(body, drawn)
	TEST_ASSERT_EQUAL(length(held), 2, "The breasts' container holds [length(held)] baked images with their share, not the body's soot and the share.")
	var/image/top = held[2]
	TEST_ASSERT_EQUAL(top.icon, share.masks.baked, "The breasts' share doesn't draw over the body's soot.")
	counted = pixels_off_part(held[1], drawn)
	TEST_ASSERT(counted[2] && !counted[1], "The body's soot under the breasts' share draws [counted[2]] pixels, [counted[1]] of them off their sprite where it draws over the skin.")

/**
 * Returns the baked images in the container a part draws over its front image (share_images()), in the order drawn. The
 * list is empty while the part draws no container.
 *
 * Arguments:
 * - body: The body.
 * - source: The part as it draws (dirt_part_drawn()).
 */
/datum/unit_test/dirt_drawing/proc/part_container_images(mob/living/carbon/human/body, datum/dirt_part_source/source)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/drawn as anything in share_images(body, -source.state_layers[length(source.state_layers)]))
		for(var/image/baked as anything in drawn.overlays)
			. += baked

/**
 * Returns list(how many of a baked image's pixels lie off a part's sprite or in a direction the part draws under the
 * skin, how many it has), over its four directions.
 *
 * Arguments:
 * - baked: The baked image.
 * - source: The part as it draws (dirt_part_drawn()).
 */
/datum/unit_test/dirt_drawing/proc/pixels_off_part(image/baked, datum/dirt_part_source/source)
	RETURN_TYPE(/list)
	var/icon/sprite = icon(baked.icon)
	var/off = 0
	var/total = 0
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/list/on_part = new /list(ICON_SIZE_X * ICON_SIZE_Y)
		if(!source.under(direction, DIRT_SKIN_LAYER))
			for(var/index in source.pixels(direction))
				on_part[index] = TRUE
		for(var/row in 0 to ICON_SIZE_Y - 1)
			for(var/column in 0 to ICON_SIZE_X - 1)
				if(sprite.GetPixel(column + 1, ICON_SIZE_Y - row, null, direction))
					total++
					if(!on_part[row * ICON_SIZE_X + column + 1])
						off++
	return list(off, total)

/**
 * Sweat lands on a tank top and on a jumpsuit. Each draws one BLEND_MULTIPLY image, its multiplier, whose pixels all
 * lie on the garment's own, and bakes no colour for it. The bare arms beside the tank top take none. Dropped by
 * SSdirt, the jumpsuit's multiplier is still drawn, and isn't made again. An armband pinned on the jumpsuit where its
 * sweat lies stays dry: the multiplier lies on none of the armband's pixels.
 */
/datum/unit_test/dirt_drawing/proc/check_sweat()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.undershirt = /datum/sprite_accessory/clothing/undershirt/tank_white::name
	body.update_body()
	var/datum/component/dirtiness/own = right_sided(body)
	// variant 0, which check_wet_pending() never lands
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 3, 0), "Sweat landed nowhere on a body in a tank top.")
	TEST_ASSERT(!length(deposits_in(own.mess_splats)), "Sweat landed on the bare skin beside a tank top.")
	SSdirt.finish_all()
	var/datum/dirt_drawing/tank_top = own.underclothes_drawings?[dirt_underclothes_key(DIRT_UNDERCLOTHES_UNDERSHIRT, /datum/sprite_accessory/clothing/undershirt/tank_white::name)]
	TEST_ASSERT(tank_top?.masks, "The tank top's masks weren't made.")
	TEST_ASSERT_NULL(tank_top.masks.baked, "The tank top bakes its sweat in a colour.")
	var/list/multipliers = multiply_images(body.drawn_limb_icons(BODY_ZONE_CHEST))
	TEST_ASSERT_EQUAL(length(multipliers), 1, "The tank top draws [length(multipliers)] multiply images, not one.")
	var/list/drawn_sprite
	for(var/list/entry as anything in dirt_underclothes_sprites(body))
		if(entry[1] == DIRT_UNDERCLOTHES_UNDERSHIRT)
			drawn_sprite = entry
	TEST_ASSERT(drawn_sprite, "The tank top isn't drawn.")
	var/list/counted = multiplier_pixels(multipliers[1], drawn_sprite[2], drawn_sprite[3])
	TEST_ASSERT(counted[2] && !counted[1], "The tank top's multiplier has [counted[2]] pixels, [counted[1]] of them off the tank top's own.")
	for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM))
		TEST_ASSERT(!length(skin_images(body, zone, DIRT_SKIN_LAYER)), "The bare [zone] draws sweat.")

	// a worn garment draws its multiplier in its worn wrapper
	var/mob/living/carbon/human/consistent/worker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(worker.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	right_sided(worker)
	TEST_ASSERT(dirt_land(worker, DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 3, 0), "Sweat landed nowhere on a body in a jumpsuit.")
	SSdirt.finish_all()
	TEST_ASSERT(!length(inset_images(worker, UNIFORM_LAYER)), "The jumpsuit draws its sweat inset in a colour.")
	var/image/root = bulge_drawn_root(worker.overlays_standing[UNIFORM_LAYER])
	multipliers = multiply_images(root?.overlays)
	TEST_ASSERT_EQUAL(length(multipliers), 1, "The jumpsuit draws [length(multipliers)] multiply images, not one.")
	var/image/leaf = bulge_drawn_leaf(root)
	counted = multiplier_pixels(multipliers[1], leaf.icon, leaf.icon_state)
	TEST_ASSERT(counted[2] && !counted[1], "The jumpsuit's multiplier has [counted[2]] pixels, [counted[1]] of them off the jumpsuit's own.")
	var/datum/component/dirtiness/suit_carrier = jumpsuit.GetComponent(/datum/component/dirtiness)
	var/held_key = suit_carrier?.cloth?.wet_key
	TEST_ASSERT(held_key, "The jumpsuit holds no multiplier.")
	SSdirt.wet_icons.forget(held_key)
	worker.update_worn_undersuit()
	root = bulge_drawn_root(worker.overlays_standing[UNIFORM_LAYER])
	TEST_ASSERT_EQUAL(length(multiply_images(root?.overlays)), 1, "The jumpsuit stops drawing its multiplier once SSdirt drops it.")
	TEST_ASSERT_NULL(SSdirt.mask_jobs[held_key], "The jumpsuit's multiplier is made again once SSdirt drops it.")

	// the armband draws over the jumpsuit in its worn wrapper, under the multiplier
	var/obj/item/clothing/accessory/armband/armband = allocate(/obj/item/clothing/accessory/armband)
	var/armband_state = armband.icon_state_is_worn ? armband.icon_state : armband.worn_icon_state
	multipliers = multiply_images(root?.overlays)
	counted = multiplier_pixels(multipliers[1], armband.worn_icon, armband_state)
	TEST_ASSERT(counted[2] > counted[1], "None of the jumpsuit's sweat lies where an armband goes, so an armband staying dry can't be checked.")
	TEST_ASSERT(jumpsuit.attach_accessory(armband, null, FALSE), "Couldn't pin an armband on the jumpsuit.")
	SSdirt.finish_all()
	root = bulge_drawn_root(worker.overlays_standing[UNIFORM_LAYER])
	multipliers = multiply_images(root?.overlays)
	TEST_ASSERT_EQUAL(length(multipliers), 1, "The jumpsuit with an armband draws [length(multipliers)] multiply images, not one.")
	counted = multiplier_pixels(multipliers[1], armband.worn_icon, armband_state)
	TEST_ASSERT_EQUAL(counted[2] - counted[1], 0, "The jumpsuit's sweat darkens its armband.")

/**
 * A tank top whose sweat rises draws the multiplier it holds while its new one is made. If it's washed or hidden
 * meanwhile, it draws none once the new one is made. If SSdirt drops a new one before the tank top is drawn with it,
 * the tank top asks for it again as it's drawn.
 */
/datum/unit_test/dirt_drawing/proc/check_wet_pending()
	SSdirt.finish_all()
	for(var/hide in list(FALSE, TRUE))
		var/what = hide ? "hidden" : "washed"
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		body.undershirt = /datum/sprite_accessory/clothing/undershirt/tank_white::name
		body.update_body()
		right_sided(body)
		// variants check_sweat() never lands, so nothing of them is made yet
		TEST_ASSERT(dirt_land(body, DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 2, hide ? 2 : 1), "Sweat landed nowhere on a body in a tank top.")
		SSdirt.finish_all()
		var/list/multipliers = multiply_images(body.drawn_limb_icons(BODY_ZONE_CHEST))
		TEST_ASSERT_EQUAL(length(multipliers), 1, "A sweaty tank top draws [length(multipliers)] multiply images, not one.")
		// more sweat: one round makes the new masks and draws the body again, which asks for the new multiplier
		dirt_land(body, DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 1)
		SSdirt.finish_all(1)
		var/waiting = FALSE
		for(var/datum/dirt_mask_job/job in SSdirt.queue)
			if(job.request.kind == DIRT_MASKS_WET)
				waiting = TRUE
		TEST_ASSERT(waiting, "The tank top's new multiplier wasn't queued, so what's drawn while it's made can't be checked.")
		TEST_ASSERT_EQUAL(length(multiply_images(body.drawn_limb_icons(BODY_ZONE_CHEST))), 1, "A tank top draws no multiplier while its new one is made.")
		if(hide)
			body.underwear_visibility |= UNDERWEAR_HIDE_SHIRT
			body.update_body()
		else
			body.wash(CLEAN_WASH)
		SSdirt.finish_all()
		TEST_ASSERT(!length(multiply_images(body.drawn_limb_icons(BODY_ZONE_CHEST))), "A tank top [what] while its multiplier was made draws it once it's made.")

	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.undershirt = /datum/sprite_accessory/clothing/undershirt/tank_white::name
	wearer.update_body()
	var/datum/component/dirtiness/own = right_sided(wearer)
	// a variant no other check lands
	TEST_ASSERT(dirt_land(wearer, DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 1, 3), "Sweat landed nowhere on a body in a tank top.")
	SSdirt.finish_all()
	dirt_land(wearer, DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 1)
	SSdirt.finish_all(1)
	var/datum/dirt_mask_job/wet_job
	for(var/datum/dirt_mask_job/job in SSdirt.queue)
		if(job.request.kind == DIRT_MASKS_WET)
			wet_job = job
	TEST_ASSERT(wet_job, "The tank top's new multiplier wasn't queued, so its being dropped before it's drawn can't be checked.")
	// made, then dropped before the body is drawn with it
	SSdirt.queue -= wet_job
	SSdirt.run_now(wet_job)
	SSdirt.wet_icons.forget(wet_job.key)
	SSdirt.finish_all()
	var/datum/dirt_drawing/tank_top = own?.underclothes_drawings?[dirt_underclothes_key(DIRT_UNDERCLOTHES_UNDERSHIRT, /datum/sprite_accessory/clothing/undershirt/tank_white::name)]
	TEST_ASSERT_EQUAL(tank_top?.wet_key, wet_job.key, "A tank top never asked again for the new multiplier SSdirt dropped before the tank top was drawn with it.")

/**
 * Returns the images among some that draw BLEND_MULTIPLY.
 *
 * Arguments:
 * - images: The images, or null.
 */
/datum/unit_test/dirt_drawing/proc/multiply_images(list/images)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/drawn as anything in images)
		if(drawn.blend_mode == BLEND_MULTIPLY)
			. += drawn

/**
 * Returns list(how many of a multiplier's pixels lie off a sprite's, how many it has), over its four directions, on the
 * body's 32x32 canvas.
 *
 * Arguments:
 * - multiplier: The multiply image.
 * - sheet, state: The sprite.
 */
/datum/unit_test/dirt_drawing/proc/multiplier_pixels(image/multiplier, sheet, state)
	RETURN_TYPE(/list)
	var/icon/factors = icon(multiplier.icon)
	var/off = 0
	var/total = 0
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/list/on_sprite = new /list(ICON_SIZE_X * ICON_SIZE_Y)
		for(var/index in dirt_sprite_pixels(sheet, state, direction))
			on_sprite[index] = TRUE
		for(var/row in 0 to ICON_SIZE_Y - 1)
			for(var/column in 0 to ICON_SIZE_X - 1)
				if(factors.GetPixel(column + 1, ICON_SIZE_Y - row, null, direction))
					total++
					if(!on_sprite[row * ICON_SIZE_X + column + 1])
						off++
	return list(off, total)

/**
 * A body walks through mud in shorts and boots. The boots, the shorts and the bare shins each take the deposit on the
 * legs alone (the hands, drawn over the shorts, are the skin's). The boots draw it inset over themselves, and the skin
 * draws it on both legs.
 */
/datum/unit_test/dirt_drawing/proc/check_walk_carriers()
	// whatever earlier tests left queued is made first
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/shorts = allocate(/obj/item/clothing/under/shorts/red)
	var/obj/item/clothing/shoes/boots = allocate(/obj/item/clothing/shoes/workboots)
	TEST_ASSERT(body.equip_to_slot_if_possible(shorts, ITEM_SLOT_ICLOTHING) && body.equip_to_slot_if_possible(boots, ITEM_SLOT_FEET), "Couldn't dress the body in shorts and boots.")
	var/datum/component/dirtiness/own = right_sided(body)
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud in shorts and boots landed nowhere.")
	var/legs = DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG)
	for(var/obj/item/garment as anything in list(boots, shorts))
		var/datum/component/dirtiness/garment_carrier = garment.GetComponent(/datum/component/dirtiness)
		var/list/held = deposits_in(garment_carrier?.mess_splats)
		TEST_ASSERT_EQUAL(length(held), 1, "The [garment.name] hold [length(held)] deposits of walking mud, not one.")
		var/datum/dirt_splat/deposit = held[1]
		TEST_ASSERT_EQUAL(deposit.limbs, legs, "The [garment.name] hold walking mud on limbs [deposit.limbs], not the legs alone ([legs]).")
	TEST_ASSERT_EQUAL(length(deposits_in(own?.mess_splats)), 1, "The skin holds [length(deposits_in(own?.mess_splats))] deposits of walking mud, not one.")
	SSdirt.finish_all()
	TEST_ASSERT_EQUAL(length(inset_images(body, SHOES_LAYER)), 1, "The boots draw [length(inset_images(body, SHOES_LAYER))] inset images, not one.")
	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		TEST_ASSERT(length(skin_images(body, zone, DIRT_SKIN_LAYER)), "The skin draws no walking mud on the [zone].")

/**
 * General deposits stack. The same cause and material raise one deposit, keeping its variant. A fourth deposit on one
 * carrier drops the one that landed longest ago. A deposit raised counts as landed when it was raised. Past
 * DIRT_MAX_SPLATS, a person's splat that landed longest ago goes as a shot lands. The cap counts their skin and what
 * they wear, an item in suit storage included. That item draws the splat no more, and its carrier, left holding
 * nothing, is deleted. A splat raised counts there as landed when it was raised too.
 */
/datum/unit_test/dirt_drawing/proc/check_stacking()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	dirt_land(body, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 1)
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	var/list/held = deposits_in(own?.mess_splats)
	TEST_ASSERT_EQUAL(length(held), 1, "Walking through mud barefoot left [length(held)] deposits on the skin, not one.")
	var/datum/dirt_splat/walked = held[1]
	var/first_variant = walked.variant
	dirt_land(body, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 1)
	held = deposits_in(own.mess_splats)
	TEST_ASSERT(length(held) == 1 && walked.level == 2 && walked.variant == first_variant, "Walking through mud twice didn't raise the one deposit to level 2 with its variant: [length(held)] deposits, level [walked.level], variant [walked.variant] (was [first_variant]).")
	for(var/list/deposit as anything in list(list(DIRT_CAUSE_DUST, DIRT_MATERIAL_DUST), list(DIRT_CAUSE_KNEEL, DIRT_MATERIAL_GRIME), list(DIRT_CAUSE_CRAWL, DIRT_MATERIAL_ASH)))
		dirt_land(body, deposit[1], deposit[2], 1)
	held = deposits_in(own.mess_splats)
	TEST_ASSERT_EQUAL(length(held), DIRT_CARRIER_DEPOSITS, "Four deposits on the skin left [length(held)], not [DIRT_CARRIER_DEPOSITS].")
	TEST_ASSERT(!(walked in held), "A fourth deposit on the skin didn't drop its oldest, the walking mud.")
	// put on undrawn, so no masks are asked for, and the raised dust lands after the kneeling grime the fall then drops
	var/datum/dirt_splat/dust
	var/datum/dirt_splat/kneeled
	for(var/datum/dirt_splat/deposit as anything in held)
		if(deposit.cause == DIRT_CAUSE_DUST)
			dust = deposit
		else if(deposit.cause == DIRT_CAUSE_KNEEL)
			kneeled = deposit
	own.add_dirt(DIRT_CAUSE_DUST, DIRT_MATERIAL_DUST, 1, DIRT_LIMBS_ALL, 0)
	own.add_dirt(DIRT_CAUSE_FALL, DIRT_MATERIAL_MUD, 1, DIRT_LIMBS_ALL, 0)
	held = deposits_in(own.mess_splats)
	TEST_ASSERT(dust && (dust in held) && !(kneeled in held), "A deposit past the skin's three dropped one raised after it rather than the kneeling grime, which landed longest ago.")
	SSdirt.finish_all()

	// a tank in suit storage holds the oldest splat, drawn, then the face's, raised after the chest's that land between
	var/mob/living/carbon/human/consistent/capped = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/suit/space/eva/suit = allocate(/obj/item/clothing/suit/space/eva)
	var/obj/item/tank/internals/oxygen/tank = allocate(/obj/item/tank/internals/oxygen)
	TEST_ASSERT(capped.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING) && capped.equip_to_slot_if_possible(tank, ITEM_SLOT_SUITSTORE), "Couldn't put an oxygen tank in an EVA suit's storage.")
	var/datum/component/dirtiness/tank_carrier = tank.LoadComponent(/datum/component/dirtiness)
	tank_carrier.add_mess(DIRT_ZONE_CHEST)
	SSdirt.finish_all()
	TEST_ASSERT(length(inset_images(capped, SUIT_STORE_LAYER)), "An oxygen tank in an EVA suit's storage draws no mess, so its going past the cap can't be seen.")
	var/datum/component/dirtiness/capped_own = capped.LoadComponent(/datum/component/dirtiness)
	var/datum/dirt_splat/face = capped_own.add_mess(DIRT_ZONE_FACE, null, 1, redraw = FALSE)
	var/datum/dirt_splat/first_chest
	for(var/added in 1 to DIRT_MAX_SPLATS - 2)
		var/datum/dirt_splat/chest = capped_own.add_mess(DIRT_ZONE_CHEST, null, DIRT_MESS_MAX_LEVEL, redraw = FALSE)
		first_chest ||= chest
	capped_own.add_mess(DIRT_ZONE_FACE, null, 1, redraw = FALSE)
	capped_own.add_mess(DIRT_ZONE_CHEST, null, DIRT_MESS_MAX_LEVEL, redraw = FALSE)
	// the shot on the EVA suit is the second past the cap, and the landing takes the two oldest off
	TEST_ASSERT(dirt_mess_land(capped, DIRT_ZONE_CHEST), "A chest shot landed nowhere on the EVA suit.")
	TEST_ASSERT(!tank.GetComponent(/datum/component/dirtiness) && !length(inset_images(capped, SUIT_STORE_LAYER)), "Past the cap, the oldest splat, on an oxygen tank in suit storage, wasn't taken off, or the tank keeps a carrier holding nothing or still draws the splat.")
	TEST_ASSERT((face in capped_own.mess_splats) && !(first_chest in capped_own.mess_splats), "Past the cap, a face splat raised after the chest's was taken off before them, or the chest's oldest stayed.")
	// nothing more is checked of them, so they aren't made
	capped.wash(CLEAN_WASH)

/**
 * A bare body's skin, and the underwear it wears, are asked for their painted designs. If the body is dressed in a
 * jumpsuit while those masks are made, the masks drawn once they're done are the clothed ones, never the bare ones.
 * The underwear's masks are then asked for unpainted. Once the jumpsuit comes off, the skin and the underwear are asked
 * for their painted designs again.
 */
/datum/unit_test/dirt_drawing/proc/check_bare_flips()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	body.update_body()
	var/datum/component/dirtiness/own = right_sided(body)
	dirt_land(body, DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 2, 6)
	TEST_ASSERT(own?.skin?.request?.painted, "A bare body's skin masks weren't asked for painted.")
	var/datum/dirt_drawing/underwear = own.underclothes_drawings?[dirt_underclothes_key(DIRT_UNDERCLOTHES_UNDERWEAR, /datum/sprite_accessory/clothing/underwear/male_boxers::name)]
	var/bare_underwear = underwear?.request?.painted && dirt_holds_deposits(underwear.request.splats)
	var/bare_key = own.skin.key
	if(!SSdirt.mask_jobs[bare_key])
		// another test made them before, so they're made again and the dressing comes while they're made
		SSdirt.masks.forget(bare_key)
		own.skin.forget(TRUE)
		body.update_body_parts()
	TEST_ASSERT(SSdirt.mask_jobs[bare_key], "The bare skin's masks weren't queued, so dressing while they're made can't be checked.")
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	SSdirt.finish_all()
	TEST_ASSERT(own.skin.request && !own.skin.request.painted, "The skin's masks are still asked for painted under a jumpsuit.")
	TEST_ASSERT(bare_underwear && underwear.request && !underwear.request.painted, "The underwear's soot wasn't asked for painted on the bare body, or still is under a jumpsuit.")
	TEST_ASSERT_NOTEQUAL(own.skin.key, bare_key, "The clothed skin's masks have the bare ones' key.")
	TEST_ASSERT(own.skin.masks && own.skin.masks.key == own.skin.key, "The clothed skin's masks aren't the ones drawn.")
	var/list/drawn = skin_images(body, BODY_ZONE_CHEST, DIRT_SKIN_LAYER)
	TEST_ASSERT(length(drawn), "The skin draws no soot on the chest under the jumpsuit.")
	for(var/image/container as anything in drawn)
		for(var/image/baked as anything in container.overlays)
			TEST_ASSERT(baked.icon == own.skin.masks.baked_by_limb[BODY_ZONE_CHEST], "The chest draws soot from other masks than the clothed ones.")
	TEST_ASSERT(body.temporarilyRemoveItemFromInventory(jumpsuit, force = TRUE), "Couldn't take the jumpsuit off.")
	SSdirt.finish_all()
	TEST_ASSERT(own.skin.request?.painted && underwear.request?.painted, "The skin's or the underwear's masks aren't asked for painted again once the jumpsuit comes off.")

/**
 * Bodies the plain human template doesn't fit take a plunge into mud. They're a monkey, whose skin draws masks made for
 * it, a lizard, and a body without its left arm, which draws nothing there. The lizard's head isn't a human's, so the
 * face's stamps keep off it.
 */
/datum/unit_test/dirt_drawing/proc/check_odd_bodies()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/monkey = allocate(/mob/living/carbon/human/consistent)
	monkey.set_species(/datum/species/monkey)
	var/datum/component/dirtiness/monkey_carrier = right_sided(monkey)
	TEST_ASSERT(dirt_land(monkey, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), "A plunge into mud landed nowhere on a monkey.")
	SSdirt.finish_all()
	TEST_ASSERT(length(monkey_carrier.skin?.masks?.baked_by_limb) && monkey_carrier.skin.masks.key == monkey_carrier.skin.key, "A monkey's plunge into mud draws no skin masks, or not the ones its skin asks for.")

	var/mob/living/carbon/human/consistent/one_armed = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/left_arm = one_armed.get_bodypart(BODY_ZONE_L_ARM)
	left_arm.drop_limb()
	qdel(left_arm)
	TEST_ASSERT(dirt_land(one_armed, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3), "A plunge into mud landed nowhere on a body without its left arm.")
	SSdirt.finish_all()
	var/datum/component/dirtiness/one_armed_carrier = one_armed.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(one_armed_carrier.skin_overlays[BODY_ZONE_R_ARM], "The right arm draws no plunge.")
	TEST_ASSERT_NULL(one_armed_carrier.skin_overlays[BODY_ZONE_L_ARM], "The missing left arm has a skin container.")
	for(var/datum/dirt_splat/deposit as anything in deposits_in(one_armed_carrier.mess_splats))
		TEST_ASSERT(!(deposit.limbs & DIRT_LIMB_BIT(DIRT_LIMB_L_ARM)), "The skin took the plunge on the missing left arm.")

	var/mob/living/carbon/human/consistent/lizard = allocate(/mob/living/carbon/human/consistent)
	lizard.set_species(/datum/species/lizard)
	var/datum/component/dirtiness/lizard_carrier = right_sided(lizard)
	TEST_ASSERT(dirt_land(lizard, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), "A plunge into mud landed nowhere on a lizard.")
	SSdirt.finish_all()
	var/list/zone_sources = lizard_carrier.skin?.request?.zone_sources
	TEST_ASSERT(zone_sources && !zone_sources["human_head"], "The lizard's skin masks weren't asked for, or count its head a human's.")
	TEST_ASSERT(lizard_carrier.skin.masks?.key == lizard_carrier.skin.key, "The lizard's skin masks weren't made.")
	var/datum/dirt_feature/stamps/stamps = locate() in dirt_cause_features(DIRT_CAUSE_PLUNGE, 3, 0, lizard_carrier.dirtier_side())
	TEST_ASSERT(stamps, "A level 3 plunge has no stamps, so the lizard's face can't be checked.")
	// the same stamps land on a human head, so the check below can't pass for want of any
	var/datum/dirt_template/human = dirt_build_template_now(dirt_zone_sources(one_armed), list(SOUTH))
	TEST_ASSERT(length(stamps.pixels(human.surfaces[SOUTH])), "A level 3 plunge stamps nothing on a human face, so the lizard's can't be checked.")
	var/datum/dirt_template/template = dirt_build_template_now(zone_sources)
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		TEST_ASSERT(!length(stamps.pixels(template.surfaces[direction])), "A plunge stamps the lizard's face facing [dir2text(direction)].")

/**
 * A shower's wash takes general dirt off the skin, the garments nothing covers and the underclothes.
 */
/datum/unit_test/dirt_drawing/proc/check_wash()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.undershirt = /datum/sprite_accessory/clothing/undershirt/tank_black::name
	body.update_body()
	var/obj/item/clothing/under/shorts = allocate(/obj/item/clothing/under/shorts/red)
	var/obj/item/clothing/shoes/boots = allocate(/obj/item/clothing/shoes/workboots)
	TEST_ASSERT(body.equip_to_slot_if_possible(shorts, ITEM_SLOT_ICLOTHING) && body.equip_to_slot_if_possible(boots, ITEM_SLOT_FEET), "Couldn't dress the body in shorts and boots.")
	dirt_land(body, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3)
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	var/datum/component/dirtiness/shorts_carrier = shorts.GetComponent(/datum/component/dirtiness)
	var/datum/component/dirtiness/boots_carrier = boots.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(length(own?.mess_splats) && length(own.underclothes_splats) && shorts_carrier?.mess_count() && boots_carrier?.mess_count(), "A plunge into mud didn't land on the skin, the tank top, the shorts and the boots, so washing them can't be checked.")
	SSdirt.finish_all()
	// as a shower washes whoever stands under it
	body.wash(CLEAN_WASH | CLEAN_RAD)
	TEST_ASSERT(!own.mess_count(), "A wash left the dirt on the skin or the tank top.")
	TEST_ASSERT(!shorts_carrier.mess_count() && !boots_carrier.mess_count(), "A wash left the dirt on the shorts or the boots.")
	SSdirt.finish_all()
	TEST_ASSERT(!length(inset_images(body, SHOES_LAYER)) && !length(inset_images(body, UNIFORM_LAYER)), "The washed shorts or boots still draw dirt.")
	for(var/zone in dirt_skin_zone_limbs())
		TEST_ASSERT(!length(skin_images(body, zone, DIRT_SKIN_LAYER)), "The washed skin still draws dirt on the [zone].")

/**
 * A shower's wash deletes the carrier of an EVA suit that it leaves holding nothing. Once SSdirt settles, the person's
 * carrier is still there, with the dirtier side that the jumpsuit under the suit draws on.
 */
/datum/unit_test/dirt_drawing/proc/check_wash_covered()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	var/obj/item/clothing/suit/space/eva/suit = allocate(/obj/item/clothing/suit/space/eva)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	var/datum/component/dirtiness/own = body.LoadComponent(/datum/component/dirtiness)
	// the left, which a carrier made afresh draws on only by chance
	own.side = -1
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud landed nowhere on the body in a jumpsuit.")
	TEST_ASSERT(body.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING) && (body.covered_slots & HIDEJUMPSUIT), "Couldn't put an EVA suit over the jumpsuit, or it doesn't cover the jumpsuit, so a covered garment's wash can't be checked.")
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), "Walking through mud landed nowhere on the EVA suit.")
	TEST_ASSERT(suit.GetComponent(/datum/component/dirtiness), "The EVA suit holds no walking mud, so its carrier going with the wash can't be checked.")
	body.wash(CLEAN_WASH)
	TEST_ASSERT_NULL(suit.GetComponent(/datum/component/dirtiness), "The EVA suit's carrier, which the wash left holding nothing, wasn't deleted.")
	// so any cover check left waiting has run
	SSdirt.finish_all()
	TEST_ASSERT(body.GetComponent(/datum/component/dirtiness) == own && own.side == -1, "The wash deleted the person's carrier, or changed the dirtier side the covered jumpsuit draws on.")

/**
 * A field half drawn when its job stops. A bare body's level 3 douse has its job worked a piece at a time until two
 * bands of its first field are drawn. The field holds the lattice they sampled. Between pieces, SSdirt is neither
 * drafting nor holding the lattice. So a shot of mess drawn then draws as it does with no field open. The shot gives
 * the skin a new key, so no body waits for the douse's job, and the job is dropped as the skin draws. When the body is
 * washed, the shot's job goes with the wash. The field goes with its job, and SSdirt holds none of its lattice. When
 * the douse lands again, it draws cold. It matches the masks a second bare body's douse made start to end, in their key
 * and every limb's pixels. Facing south and east, its rasters drawn a band a piece are the douse drawn whole.
 */
/datum/unit_test/dirt_drawing/proc/check_band_interrupted()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/whole_body = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/dirtiness/whole_own = right_sided(whole_body)
	TEST_ASSERT(dirt_land(whole_body, DIRT_CAUSE_DOUSE, DIRT_MATERIAL_ASH, 3, 0), "A douse of ash landed nowhere on a bare body.")
	SSdirt.finish_all()
	var/datum/dirt_masks/whole = whole_own.skin?.masks
	var/datum/dirt_mask_request/request = whole_own.skin?.request
	TEST_ASSERT(whole && whole.key == whole_own.skin.key && request?.painted, "A bare body's douse wasn't made, or wasn't asked for painted.")
	// drop the masks and the rasters, keyed as rasterise_next() keys them, so the douse below draws again from neither
	SSdirt.masks.forget(whole.key)
	var/raster_key = deposit_key(request, DIRT_CAUSE_DOUSE, dirt_material(DIRT_MATERIAL_ASH))
	SSdirt.rasters.forget(raster_key)

	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/dirtiness/own = right_sided(body)
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_DOUSE, DIRT_MATERIAL_ASH, 3, 0), "A douse of ash landed nowhere on a second bare body.")
	var/douse_key = own.skin?.key
	var/datum/dirt_mask_job/job = douse_key && SSdirt.mask_jobs[douse_key]
	TEST_ASSERT(douse_key == whole.key && job, "The second bare body's douse wasn't queued under the first's key.")
	var/datum/dirt_canvas_field/body/field
	// each piece with the field open draws one of its bands
	var/bands = 0
	for(var/piece in 1 to job.most_pieces())
		// as a fire makes it, so a runtime in it stops SSdirt drafting
		var/finished = SSdirt.make_piece(job)
		TEST_ASSERT(!SSdirt.drafting && !SSdirt.lattice_points, "SSdirt is left drafting, or holding a field's lattice, after a piece of the douse's job.")
		field = open_field(job)
		bands += !!field
		if(finished || bands >= 2)
			break
	TEST_ASSERT(field && length(field.lattice) && (job in SSdirt.queue), "The douse's job didn't stop two bands into a field, still queued and holding the lattice they sampled.")

	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST), "A shot of mess landed nowhere on the doused body.")
	var/shot_key = own.skin.key
	var/datum/dirt_splat/shot
	for(var/datum/dirt_splat/splat as anything in own.mess_splats)
		if(!splat.cause)
			shot = splat
	TEST_ASSERT(shot, "The shot of mess didn't land on the doused body's skin.")
	TEST_ASSERT(shot_key != douse_key && SSdirt.mask_jobs[shot_key], "The shot of mess wasn't queued under a key of its own, so its wash can't be checked.")
	TEST_ASSERT(!(job in SSdirt.queue) && !SSdirt.mask_jobs[douse_key], "The douse's job, which no body waits for once the shot gives the skin a new key, is still queued after the skin drew.")
	var/datum/dirt_template/template = job.template
	var/datum/dirt_surface/surface = template.surfaces[SOUTH]
	var/aimed = "[DIRT_CAUSE_AIMED_PREFIX][shot.zone]"
	var/datum/dirt_pixels/open_shot = dirt_rasterise(aimed, null, shot.level, shot.variant, 1, DIRT_SURFACE_SKIN, surface)

	body.wash(CLEAN_WASH)
	TEST_ASSERT(!own.mess_count(), "A wash left the douse or the shot on the body.")
	TEST_ASSERT(!SSdirt.mask_jobs[shot_key], "A wash left the shot's job queued, which no body waits for now.")
	var/datum/weakref/field_ref = WEAKREF(field)
	field = null
	job = null
	TEST_ASSERT(!field_ref.resolve(), "The douse's field, dropped half drawn, outlives its job.")
	TEST_ASSERT(!SSdirt.drafting && !SSdirt.lattice_points && !length(SSdirt.lattice), "SSdirt is left drafting, or holding the dropped field's lattice.")
	var/datum/dirt_pixels/closed_shot = dirt_rasterise(aimed, null, shot.level, shot.variant, 1, DIRT_SURFACE_SKIN, surface)
	TEST_ASSERT_EQUAL(open_shot.drawn(), closed_shot.drawn(), "A shot of mess drawn between a field's bands draws otherwise than with no field open.")

	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_DOUSE, DIRT_MATERIAL_ASH, 3, 0), "The douse landed nowhere on the washed body.")
	SSdirt.finish_all()
	var/datum/dirt_masks/made = own.skin?.masks
	TEST_ASSERT(made && made != whole && made.key == whole.key, "The douse landed again on the washed body wasn't made anew under the first body's key.")
	TEST_ASSERT_EQUAL(length(made.baked_by_limb), length(whole.baked_by_limb), "The douse landed again on the washed body draws on another number of limbs than the first body's.")
	for(var/zone, baked in whole.baked_by_limb)
		TEST_ASSERT(made.baked_by_limb[zone] && baked_digest(made.baked_by_limb[zone]) == baked_digest(baked), "The douse landed again on the washed body draws its [zone] otherwise than the first body's.")
	// the rasters the job drew a band a piece match a whole draw's
	for(var/direction in list(SOUTH, EAST))
		var/datum/dirt_pixels/drawn_whole = dirt_rasterise(DIRT_CAUSE_DOUSE, dirt_material(DIRT_MATERIAL_ASH), 3, 0, 1, DIRT_SURFACE_SKIN, template.surfaces[direction], TRUE)
		TEST_ASSERT_EQUAL(SSdirt.rasters.fetch_direction(raster_key, direction), drawn_whole.drawn(), "The bare body's douse facing [dir2text(direction)], drawn a band a piece, isn't kept or isn't the douse drawn whole.")

/**
 * Machine work in grease on a bare body wears the hands' painted design, as machine work in oil does, in grease's own
 * colours. Each limb bakes the pixels a bare body's oil bakes there. Each of those pixels takes grease's tint of the
 * role that oil's pixel takes in oil's tints.
 */
/datum/unit_test/dirt_drawing/proc/check_painted_grease()
	SSdirt.finish_all()
	var/list/limb_bakes = list()
	var/list/materials = list(dirt_material(DIRT_MATERIAL_OIL), dirt_material(DIRT_MATERIAL_GREASE))
	for(var/datum/dirt_material/material as anything in materials)
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		var/datum/component/dirtiness/own = right_sided(body)
		TEST_ASSERT(dirt_land(body, DIRT_CAUSE_MACHINE, material.id, 3, 0), "Machine work in [material.name] landed nowhere on a bare body.")
		TEST_ASSERT(own.skin?.request?.painted, "A bare body's machine work in [material.name] wasn't asked for painted.")
		SSdirt.finish_all()
		TEST_ASSERT(length(own.skin.masks?.baked_by_limb), "A bare body's machine work in [material.name] wasn't made.")
		limb_bakes += list(own.skin.masks.baked_by_limb)
	var/datum/dirt_material/oil = materials[1]
	var/datum/dirt_material/grease = materials[2]
	var/alist/oiled = limb_bakes[1]
	var/alist/greased = limb_bakes[2]
	TEST_ASSERT_EQUAL(length(greased), length(oiled), "Machine work in grease on a bare body bakes [length(greased)] limbs, where oil bakes [length(oiled)].")
	var/drawn = 0
	for(var/zone, oil_baked in oiled)
		TEST_ASSERT(greased[zone], "Machine work in grease on a bare body bakes nothing on the [zone], where oil does.")
		var/icon/oil_icon = icon(oil_baked)
		var/icon/grease_icon = icon(greased[zone])
		for(var/direction in list(SOUTH, NORTH, EAST, WEST))
			for(var/icon_y in 1 to ICON_SIZE_Y)
				for(var/icon_x in 1 to ICON_SIZE_X)
					var/oil_pixel = oil_icon.GetPixel(icon_x, icon_y, null, direction)
					var/grease_pixel = grease_icon.GetPixel(icon_x, icon_y, null, direction)
					TEST_ASSERT(!oil_pixel == !grease_pixel, "Machine work in grease on a bare body's [zone] draws [grease_pixel ? "a pixel" : "none"] at [icon_x],[icon_y] facing [dir2text(direction)], where oil draws [oil_pixel ? "one" : "none"].")
					if(!oil_pixel)
						continue
					drawn++
					var/tinted = FALSE
					for(var/role in DIRT_ROLE_HAZE to DIRT_ROLE_GLINT)
						var/list/oil_tint = oil.tints[role]
						var/list/grease_tint = grease.tints[role]
						if(same_rgb(oil_pixel, oil_tint[1]) && same_rgb(grease_pixel, grease_tint[1]))
							tinted = TRUE
					TEST_ASSERT(tinted, "Machine work in grease on a bare body's [zone] bakes [grease_pixel] at [icon_x],[icon_y] facing [dir2text(direction)], not grease's tint of the role oil's [oil_pixel] is in.")
	TEST_ASSERT(drawn, "Machine work in oil on a bare body draws nothing, so grease wearing its design can't be checked.")

/**
 * Returns whether a baked pixel is a colour, its alpha aside.
 *
 * Arguments:
 * - pixel: The pixel, as GetPixel() reads it.
 * - colour: The colour, "#RRGGBB".
 */
/datum/unit_test/dirt_drawing/proc/same_rgb(pixel, colour)
	var/list/channels = rgb2num(pixel)
	var/list/wanted = rgb2num(colour)
	return channels[1] == wanted[1] && channels[2] == wanted[2] && channels[3] == wanted[3]

/**
 * A deposit without a painted design draws on a bare body as on a dressed one, so it's kept as a dressed body's
 * (rasterise_next()). A douse of mud made on a bare body is kept under a dressed body's key, and the body, once
 * dressed, takes it from there. A douse of grease on a bare body takes the rasters that a douse of oil, of its shape
 * class, made there. Each time, the rasters kept are, in every direction, the douse dirt_rasterise() draws for that
 * body alone. If a key left out something a raster reads, one body would draw another's pixels.
 */
/datum/unit_test/dirt_drawing/proc/check_bare_shares()
	SSdirt.finish_all()
	var/datum/dirt_material/mud = dirt_material(DIRT_MATERIAL_MUD)
	var/datum/dirt_material/oil = dirt_material(DIRT_MATERIAL_OIL)
	var/datum/dirt_material/grease = dirt_material(DIRT_MATERIAL_GREASE)

	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/dirtiness/own = right_sided(body)
	var/datum/dirt_template/template = land_bare_deposit(body, DIRT_CAUSE_DOUSE, mud)
	TEST_ASSERT(template, "A douse of mud wasn't made painted on a bare body.")
	var/mud_key = deposit_key(own.skin.request, DIRT_CAUSE_DOUSE, mud)
	check_deposit_kept(mud_key, template, DIRT_CAUSE_DOUSE, mud, TRUE, "A bare body's douse of mud")
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	SSdirt.finish_all()
	TEST_ASSERT(own.skin.request && !own.skin.request.painted && own.skin.masks?.key == own.skin.key, "The douse of mud wasn't made again unpainted on the body dressed.")
	TEST_ASSERT_EQUAL(deposit_key(own.skin.request, DIRT_CAUSE_DOUSE, mud), mud_key, "The dressed body's douse of mud is kept under another key than the bare body's.")
	check_deposit_kept(mud_key, template, DIRT_CAUSE_DOUSE, mud, FALSE, "The douse of mud the body takes dressed")

	var/mob/living/carbon/human/consistent/greased = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/dirtiness/greased_own = right_sided(greased)
	template = land_bare_deposit(greased, DIRT_CAUSE_DOUSE, oil)
	TEST_ASSERT(template, "A douse of oil wasn't made painted on a bare body.")
	var/oil_key = deposit_key(greased_own.skin.request, DIRT_CAUSE_DOUSE, oil)
	check_deposit_kept(oil_key, template, DIRT_CAUSE_DOUSE, oil, TRUE, "A bare body's douse of oil")
	TEST_ASSERT(dirt_land(greased, DIRT_CAUSE_DOUSE, DIRT_MATERIAL_GREASE, 3, 0), "A douse of grease landed nowhere on the bare body doused with oil.")
	SSdirt.finish_all()
	TEST_ASSERT(length(deposits_in(greased_own.mess_splats)) == 2 && greased_own.skin.masks?.key == greased_own.skin.key, "The bare body's douses of oil and grease weren't both made.")
	check_deposit_kept(oil_key, template, DIRT_CAUSE_DOUSE, grease, TRUE, "The douse of grease a bare body takes from a douse of oil")

/**
 * Lands a deposit at level 3, variant 0, on a bare body, with its rasters forgotten so its skin's job makes them.
 * Returns the body's template once its masks are made, or null if they weren't made or weren't asked for painted.
 *
 * Arguments:
 * - body: The body, its dirtier side the right.
 * - cause: The deposit's DIRT_CAUSE_* define.
 * - material: Its /datum/dirt_material.
 */
/datum/unit_test/dirt_drawing/proc/land_bare_deposit(mob/living/carbon/human/body, cause, datum/dirt_material/material)
	RETURN_TYPE(/datum/dirt_template)
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	if(!dirt_land(body, cause, material.id, 3, 0) || !own.skin?.request?.painted)
		return null
	SSdirt.rasters.forget(deposit_key(own.skin.request, cause, material))
	if(!SSdirt.mask_jobs[own.skin.key])
		// another test made them before, so they're made again and the job makes the rasters
		SSdirt.masks.forget(own.skin.key)
		own.skin.forget(TRUE)
		body.update_body_parts()
	SSdirt.finish_all()
	if(own.skin.masks?.key != own.skin.key)
		return null
	return SSdirt.templates.fetch(dirt_template_key(own.skin.request.zone_sources))

/**
 * Returns the key a body's deposit is kept under in SSdirt.rasters, on the surface a mask request rasterises it on, as
 * rasterise_next() keys it. It's for a check that must drop the deposit before the job that draws it runs. The key
 * names the deposit's material where it wears a painted design, or else its shape class, as a dressed body's does.
 *
 * Arguments:
 * - request: The mask request: the skin's, or a garment's on cloth.
 * - cause: The deposit's DIRT_CAUSE_* define.
 * - material: Its /datum/dirt_material.
 * - level: Its level.
 * - variant: Its variant.
 */
/datum/unit_test/dirt_drawing/proc/deposit_key(datum/dirt_mask_request/request, cause, datum/dirt_material/material, level = 3, variant = 0)
	var/designed = !!(request.painted && dirt_painted_design(cause, material))
	return "[request.template_key]|[request.deposit_surface || request.surface_kind]|[cause]:[designed ? material.id : material.shape_class(cause)]:[level]:[variant]:[request.side]:[designed]"

/**
 * Returns the key a general deposit on a taur body or a drawn part is kept under in SSdirt.rasters, as
 * rasterise_shape_deposit() keys it. It's for a check that must plant or drop the deposit before the job that reads it
 * runs.
 *
 * Arguments:
 * - request: The shape's mask request.
 * - splat: The deposit, one of the request's splats.
 */
/datum/unit_test/dirt_drawing/proc/shape_raster_key(datum/dirt_mask_request/request, datum/dirt_splat/splat)
	var/datum/dirt_material/material = dirt_material(splat.material)
	var/surface_kind = request.surface_kind == DIRT_SURFACE_CLOTH ? DIRT_SURFACE_CLOTH : DIRT_SURFACE_FUR
	return "shape|[request.shape_source.shape_key()]|[request.template_key]|[surface_kind]|[splat.cause]:[material.shape_class(splat.cause)]:[splat.level]:[splat.variant]:[request.side][request.rows ? "|rows:[jointext(request.rows, ",")]" : ""]"

/**
 * Returns whether a tail's still masks' job took its first splat's rasters, in every direction, from what
 * plant_still_dirt() put under a key. So a key that doesn't match rasterise_shape_deposit()'s fails here, rather than
 * leaving the planted dirt unread.
 *
 * Arguments:
 * - job: The still masks' job, or null.
 * - raster_key: The key, from plant_still_dirt().
 */
/datum/unit_test/dirt_drawing/proc/took_planted(datum/dirt_mask_job/job, raster_key)
	var/alist/rasters = job?.splat_rasters?[1]
	for(var/direction in dirt_mask_directions())
		if(!rasters?[direction] || rasters[direction] != SSdirt.rasters.fetch_direction(raster_key, direction))
			return FALSE
	return TRUE

/**
 * Checks that the rasters kept under a key are, in every direction, the deposit dirt_rasterise() draws alone on a
 * body's surface, its dirtier side the right.
 *
 * Arguments:
 * - raster_key: The key (deposit_key()).
 * - template: The body's template.
 * - cause: The deposit's DIRT_CAUSE_* define.
 * - material: Its /datum/dirt_material.
 * - bare: Whether the body is bare.
 * - what: The deposit, for the failure message.
 * - level: Its level.
 * - variant: Its variant.
 * - surface_kind: What it's rasterised on, DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 */
/datum/unit_test/dirt_drawing/proc/check_deposit_kept(raster_key, datum/dirt_template/template, cause, datum/dirt_material/material, bare, what, level = 3, variant = 0, surface_kind = DIRT_SURFACE_SKIN)
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_pixels/alone = dirt_rasterise(cause, material, level, variant, 1, surface_kind, template.surfaces[direction], bare)
		TEST_ASSERT_EQUAL(SSdirt.rasters.fetch_direction(raster_key, direction), alone.drawn(), "[what] facing [dir2text(direction)] isn't kept under its key, or isn't the [cause] drawn for that body alone.")

/**
 * A deposit drawn a band a piece by its job is kept, in every direction, as the deposit drawn whole. The deposits are a
 * plunge of mud and a blast of soot on a bare body, and a plunge of mud on a bare horse taur's body.
 */
/datum/unit_test/dirt_drawing/proc/check_fields_shared()
	SSdirt.finish_all()
	for(var/list/landing as anything in list(list(DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD), list(DIRT_CAUSE_BLAST, DIRT_MATERIAL_SOOT)))
		var/cause = landing[1]
		var/datum/dirt_material/material = dirt_material(landing[2])
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		var/datum/component/dirtiness/own = right_sided(body)
		var/datum/dirt_template/template = land_bare_deposit(body, cause, material)
		TEST_ASSERT(template, "A [cause] of [material.name] wasn't made painted on a bare body.")
		check_deposit_kept(deposit_key(own.skin.request, cause, material), template, cause, material, TRUE, "A bare body's [cause] of [material.name]")

	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(rider), "Couldn't make the human a horse taur.")
	var/datum/component/dirtiness/rider_own = right_sided(rider)
	TEST_ASSERT(dirt_land(rider, DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), "A plunge into mud landed nowhere on a bare taur.")
	var/list/held = deposits_in(rider_own.part_splats?[ORGAN_SLOT_EXTERNAL_TAUR])
	var/datum/dirt_drawing/drawing = rider_own.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	TEST_ASSERT(length(held) == 1 && drawing?.request, "A bare taur's body didn't take the plunge into mud, or doesn't draw it.")
	if(!SSdirt.mask_jobs[drawing.key])
		// another test made them before, so they're made again and the job makes the rasters
		SSdirt.masks.forget(drawing.key)
		drawing.forget(TRUE)
		rider.update_body_parts()
	var/datum/dirt_mask_request/request = drawing.request
	TEST_ASSERT(request && SSdirt.mask_jobs[drawing.key], "The bare taur's plunge into mud wasn't queued.")
	// the queued job draws its fields a band a piece, never from rasters kept before
	var/datum/dirt_splat/plunged = held[1]
	var/datum/dirt_material/mud = dirt_material(plunged.material)
	var/raster_key = shape_raster_key(request, plunged)
	SSdirt.rasters.forget(raster_key)
	SSdirt.finish_all()
	// a taur body takes a plunge whole from the canvas field facing the way it's seen (dirt_shape_deposit())
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_pixels/whole = dirt_canvas_rasterise(plunged.cause, mud, plunged.level, plunged.variant, request.shape_source.canvas, direction, DIRT_SURFACE_FUR, request.side)
		TEST_ASSERT_EQUAL(SSdirt.rasters.fetch_direction(raster_key, direction), whole.drawn(), "A bare taur's plunge into mud facing [dir2text(direction)], drawn a band a piece, isn't kept or isn't the plunge drawn whole.")

/**
 * A job makes a deposit's features once, in its first direction, and binds them to each of the others in turn
 * (/datum/dirt_mask_job/var/deposit_features). A job drawing deposits one after another keeps each in every direction
 * as it's drawn whole. Together with the douse and the blast that check_bare_shares() and check_fields_shared() draw,
 * these deposits make every kind of feature a general cause makes. They're drawn on a bare body's skin, and on a
 * dressed body's skin, where walking draws its own marks rather than its design. They're drawn on its cloth too, which
 * also takes sweat. On the cloth they make both backs (the tall and the wide), smoke's mantles and patches at its top
 * level, two of a kind sampling one seed, and a plunge's coat.
 */
/datum/unit_test/dirt_drawing/proc/check_features_shared()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/list/zone_sources = dirt_zone_sources(body)
	var/datum/dirt_material/slime = dirt_material(DIRT_MATERIAL_SLIME, "#4fc94a")
	// each list(cause, material, level, variant)
	var/list/bare = list(
		list(DIRT_CAUSE_SLIMED_CHEST, slime.key, 3, 0), // globs, a glint, strokes
		list(DIRT_CAUSE_SMOKE, DIRT_MATERIAL_ASH, 4, 0), // stamps, the head's veil, a collar, bands, blobs, patches, mantles
		list(DIRT_CAUSE_FALL, DIRT_MATERIAL_MUD, 3, 0), // patches, loose specks, stamps
		list(DIRT_CAUSE_CRAWL, DIRT_MATERIAL_DUST, 3, 0), // blobs, contacts, strokes, patches
		list(DIRT_CAUSE_MACHINE, DIRT_MATERIAL_MUD, 4, 0), // stamps, cloth's wipes, a fade, patches, a fleck, a coatline
		list(DIRT_CAUSE_DUST, DIRT_MATERIAL_DUST, 3, 0), // a coatline, patches, settled blobs
	)
	var/list/dressed = list(
		list(DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0), // a coatline and specks
		list(DIRT_CAUSE_WEAR, DIRT_MATERIAL_GRIME, 3, 0), // a collar and bands, ringed patches, a pocket's stroke
		list(DIRT_CAUSE_MACHINE, DIRT_MATERIAL_OIL, 3, 0),
		list(DIRT_CAUSE_SPLASH, DIRT_MATERIAL_MUD, 3, 0),
		list(DIRT_CAUSE_SLIMED_CHEST, slime.key, 3, 0),
	)
	var/list/cloth = dressed + list(
		list(DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 3, 0), // damp shapes, the back tall
		list(DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 3, 1), // the back wide
		list(DIRT_CAUSE_SMOKE, DIRT_MATERIAL_ASH, 4, 0), // the mantles and cuffs, level 3's and 4's on one seed
		list(DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD, 3, 0), // the whole-body coat
	)
	check_job_features(zone_sources, DIRT_SURFACE_SKIN, TRUE, bare, "A bare body's skin")
	check_job_features(zone_sources, DIRT_SURFACE_SKIN, FALSE, dressed, "A dressed body's skin")
	check_job_features(zone_sources, DIRT_SURFACE_CLOTH, FALSE, cloth, "A dressed body's cloth")

/**
 * Checks that one job making a body's masks on one surface keeps each deposit, in every direction, as dirt_rasterise()
 * draws it alone (check_deposit_kept()). The deposits' rasters are forgotten first, so the job draws them one after
 * another.
 *
 * Arguments:
 * - zone_sources: The body's sprites, from dirt_zone_sources().
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 * - bare: Whether the body is bare.
 * - deposits: Each list(DIRT_CAUSE_* define, material key, level, variant), its dirtier side the right.
 * - what: The surface, for the failure message.
 */
/datum/unit_test/dirt_drawing/proc/check_job_features(list/zone_sources, surface_kind, bare, list/deposits, what)
	var/list/splats = list()
	for(var/list/deposit as anything in deposits)
		splats += new /datum/dirt_splat(null, deposit[3], deposit[4], length(splats) + 1, deposit[1], deposit[2], DIRT_LIMBS_ALL)
	var/datum/dirt_mask_request/request = new(DIRT_MASKS_BODY, zone_sources, surface_kind, splats, painted = bare)
	var/list/keys = list()
	for(var/list/deposit as anything in deposits)
		var/raster_key = deposit_key(request, deposit[1], dirt_material(deposit[2]), deposit[3], deposit[4])
		SSdirt.rasters.forget(raster_key)
		keys += raster_key
	var/datum/dirt_mask_job/job = made_job(request)
	TEST_ASSERT(job.masks, "[what]'s masks of [length(deposits)] deposits weren't made.")
	var/datum/dirt_template/template = job.template
	for(var/position in 1 to length(deposits))
		var/list/deposit = deposits[position]
		var/datum/dirt_material/material = dirt_material(deposit[2])
		check_deposit_kept(keys[position], template, deposit[1], material, bare, "[what]'s [deposit[1]] of [material.name] at level [deposit[3]], variant [deposit[4]], drawn by one job after [position - 1] others,", deposit[3], deposit[4], surface_kind)

/**
 * Returns the body field a mask job is drawing a band at a time, or null.
 *
 * Arguments:
 * - job: The job.
 */
/datum/unit_test/dirt_drawing/proc/open_field(datum/dirt_mask_job/job)
	RETURN_TYPE(/datum/dirt_canvas_field/body)
	for(var/field_key, held in job.canvas_fields)
		var/datum/dirt_canvas_field/body/field = held
		if(istype(field) && !field.done)
			return field
	return null

/**
 * Returns the general deposits among splats, oldest first.
 *
 * Arguments:
 * - splats: The splats, or null.
 */
/datum/unit_test/dirt_drawing/proc/deposits_in(list/splats)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/dirt_splat/splat as anything in splats)
		if(splat.cause)
			. += splat

/**
 * However many slime colours are asked for, SSdirt keeps DIRT_SLIME_COLOURS at most. A dropped colour is made again in
 * its own tints from the key a splat stores, as a bake asks for it.
 */
/datum/unit_test/dirt_drawing/proc/check_slime_colours()
	var/datum/dirt_material/green = dirt_material(DIRT_MATERIAL_SLIME, "#4fc94a")
	TEST_ASSERT(istype(green), "Slime in a colour made no material.")
	var/green_tints = json_encode(green.tints)
	for(var/colour_number in 1 to DIRT_SLIME_COLOURS + 6)
		dirt_material(DIRT_MATERIAL_SLIME, rgb(colour_number * 3, 100, 200))
	var/held = length(SSdirt.slime_materials.entries)
	TEST_ASSERT(held <= DIRT_SLIME_COLOURS, "[held] slime materials are kept, past [DIRT_SLIME_COLOURS].")
	// a queued bake asks by the key a splat stores (dirt_baked_frames())
	var/datum/dirt_material/remade = dirt_material(green.key)
	TEST_ASSERT(remade && json_encode(remade.tints) == green_tints, "Slime as a splat stores it ([green.key]), dropped past the colours kept, isn't made again in its own tints.")

/**
 * Mess bakes the pixels DIRT_MESS_BAKE_DIGESTS holds, on skin and on a jumpsuit's cloth. The mess is two splats on the
 * corpus's human_m: the chest at level 2, variant 5, and the face at level 4, variant 1.
 */
/datum/unit_test/dirt_drawing/proc/check_mess_bake()
	var/list/corpus = json_decode(file2text(DIRT_CORPUS) || "{}")
	var/list/templates = corpus["templates"]
	TEST_ASSERT(length(templates), "[DIRT_CORPUS] has no templates.")
	var/alist/zone_sources = dirt_parity_zone_sources(templates["human_m"])
	var/list/splats = list(new /datum/dirt_splat(DIRT_ZONE_CHEST, 2, 5, 1), new /datum/dirt_splat(DIRT_ZONE_FACE, 4, 1, 2))
	var/list/digests = list()
	var/datum/dirt_masks/skin = made_masks(new /datum/dirt_mask_request(DIRT_MASKS_BODY, zone_sources, DIRT_SURFACE_SKIN, splats))
	TEST_ASSERT(skin, "The skin's masks weren't made.")
	for(var/zone, baked in skin.baked_by_limb)
		digests += "skin [zone] [baked_digest(baked)]"
	var/datum/dirt_masks/cloth = made_masks(new /datum/dirt_mask_request(DIRT_MASKS_BODY, zone_sources, DIRT_SURFACE_CLOTH, splats))
	TEST_ASSERT(cloth?.baked, "The jumpsuit's masks weren't made.")
	digests += "cloth [baked_digest(cloth.baked)]"
	TEST_ASSERT_EQUAL(jointext(digests, ", "), DIRT_MESS_BAKE_DIGESTS, "Mess bakes other pixels than it did.")

/**
 * Returns a request's masks, made start to end by a job of its own, outside the queue and the mask cache, or null when
 * it made none.
 *
 * Arguments:
 * - request: The request.
 */
/datum/unit_test/dirt_drawing/proc/made_masks(datum/dirt_mask_request/request)
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_mask_job/job = made_job(request)
	return job.masks

/**
 * A mask packed as text (/datum/dirt_pixels/proc/drawn()) and read back (dirt_pixels_from_drawn()) is the same mask.
 * It has the same drawn pixels in row-major order, their roles and thicknesses and whether it covers, and it packs
 * again as the same text. The masks built by hand are: empty, one pixel at the canvas's end, a full row, seven
 * thicknesses side by side, and the whole 64x32 canvas, with a run past 64 pixels and its last index among them. A
 * jumpsuit holds three deposits and two shots of mess, with a third shot at the top level, which covers. Its merge of
 * each direction from its packed texts (dirt_merge()) matches the merge of the masks read from them. Its job's merges
 * are the masks merged that way, with the parts its mess reaches (the pecs guide a plain human chest takes,
 * dirt_merge_with_parts()). A bare taur's body holds walking mud, slime on its back and two pools. It merges each
 * direction on the 64x32 canvas, with no limbs. Its merge from its packed texts matches the merge of the masks read
 * from them. Its second pool is read on its whole mask.
 */
/datum/unit_test/dirt_drawing/proc/check_packed_runs()
	SSdirt.finish_all()
	// thicknesses the module draws with, so no code is packed that it wouldn't pack
	var/list/thicknesses = list(DIRT_HAZE_T, DIRT_FILM_T, 0.4, 0.5, 0.6, DIRT_BODY_T, 0.9)
	var/list/built = list("empty" = new /datum/dirt_pixels)
	var/datum/dirt_pixels/single = new
	single.covers = TRUE
	single.roles[length(single.roles)] = DIRT_ROLE_GLINT
	single.thicknesses[length(single.roles)] = 0.9
	built["one pixel"] = single
	var/datum/dirt_pixels/row = new
	for(var/column in 1 to ICON_SIZE_X)
		row.roles[ICON_SIZE_X * 5 + column] = DIRT_ROLE_BODY
		row.thicknesses[ICON_SIZE_X * 5 + column] = DIRT_BODY_T
	built["a full row"] = row
	var/datum/dirt_pixels/graded = new
	for(var/position in 1 to length(thicknesses))
		graded.roles[ICON_SIZE_X * 10 + position] = position % 2 ? DIRT_ROLE_FILM : DIRT_ROLE_FLECK
		graded.thicknesses[ICON_SIZE_X * 10 + position] = thicknesses[position]
	built["seven thicknesses"] = graded
	var/datum/dirt_pixels/whole = new(DIRT_TAUR_WIDTH, ICON_SIZE_Y)
	for(var/index in 1 to length(whole.roles))
		// a run of 150, then roles and thicknesses changing every pixel or two
		whole.roles[index] = index <= 150 ? DIRT_ROLE_CORE : (index % 3 ? DIRT_ROLE_FILM : DIRT_ROLE_GLINT)
		whole.thicknesses[index] = index <= 150 ? 0.9 : thicknesses[floor(index / 2) % length(thicknesses) + 1]
	built["the 64x32 canvas"] = whole
	for(var/label, entry in built)
		var/datum/dirt_pixels/pixel_map = entry
		var/drawn = pixel_map.drawn()
		var/datum/dirt_pixels/read = dirt_pixels_from_drawn(drawn, pixel_map.width, pixel_map.height)
		TEST_ASSERT_EQUAL(read.drawn(), drawn, "The mask with [label], read back from its packed text, packs as other text.")
		var/list/indexes = list()
		for(var/index in 1 to length(pixel_map.roles))
			if(pixel_map.roles[index])
				indexes += index
		TEST_ASSERT(read.drawn_indexes ~= indexes && read.roles ~= pixel_map.roles && read.thicknesses ~= pixel_map.thicknesses && read.covers == pixel_map.covers, "The mask with [label], read back from its packed text, isn't the mask packed.")

	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	right_sided(body)
	for(var/list/deposit as anything in list(list(DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD), list(DIRT_CAUSE_KNEEL, DIRT_MATERIAL_RED_CLAY), list(DIRT_CAUSE_SPLASH, DIRT_MATERIAL_GREASE)))
		TEST_ASSERT(dirt_land(body, deposit[1], deposit[2], 3, 0), "[deposit[1]] in [deposit[2]] landed nowhere on the body in a jumpsuit.")
	// the third covers, so it streams after the others rather than being read on its whole mask
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST) && dirt_mess_land(body, DIRT_ZONE_STOMACH) && dirt_mess_place(body, DIRT_ZONE_GROIN, DIRT_MESS_MAX_LEVEL, 0), "Mess landed nowhere on the body in a jumpsuit.")
	SSdirt.finish_all()
	var/datum/component/dirtiness/carrier = jumpsuit.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_mask_request/request = carrier?.cloth?.request
	TEST_ASSERT(length(request?.splats) >= 4, "The jumpsuit holds [length(request?.splats)] splats, too few to merge.")
	var/datum/dirt_mask_job/job = made_job(request)
	TEST_ASSERT(job.masks && !job.failed, "The jumpsuit's masks weren't made.")
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_surface/surface = job.template.surfaces[direction]
		var/list/pixel_maps = list()
		var/list/drawn_rasters = list()
		var/list/limbs = list()
		for(var/position in 1 to length(job.splat_rasters))
			var/alist/rasters = job.splat_rasters[position]
			var/datum/dirt_splat/splat = request.splats[position]
			var/datum/dirt_pixels/on_limbs = dirt_pixels_from_drawn(rasters[direction], surface.width, surface.height, splat.limbs, surface)
			pixel_maps += on_limbs
			drawn_rasters += rasters[direction]
			limbs += splat.limbs
		var/difference = merge_difference(dirt_merge(drawn_rasters, job.splat_materials, surface.width, surface.height, limbs, surface), dirt_merge(pixel_maps, job.splat_materials))
		TEST_ASSERT(!difference, "The jumpsuit's splats facing [dir2text(direction)], streamed from their packed texts, merge with other [difference] than the masks read from them.")
		// as merge() merges them, with the parts its mess reaches (the pecs guide here), and last because those parts
		// take pixels out of the masks
		var/datum/dirt_pixels/mapped
		if(length(job.parts))
			var/list/split = dirt_split_parts(job.parts, request.surface_layer, direction)
			mapped = dirt_merge_with_parts(pixel_maps, request.splats, split[1], split[2], job.part_owns[direction], direction, job.splat_materials)
		else
			mapped = dirt_merge(pixel_maps, job.splat_materials)
		difference = merge_difference(job.merged[direction], mapped)
		TEST_ASSERT(!difference, "The jumpsuit's merge facing [dir2text(direction)], from its packed texts with the parts its mess reaches, holds other [difference] than the masks merged so.")

	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(taur), "Couldn't make the human a horse taur.")
	right_sided(taur)
	TEST_ASSERT(dirt_land(taur, DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 3, 0) && dirt_land(taur, DIRT_CAUSE_SLIMED_BACK, DIRT_MATERIAL_SLIME, 3, 0, "#4FC94A"), "Walking mud or slime on the back landed nowhere on a bare taur.")
	TEST_ASSERT(dirt_mess_place(taur, DIRT_ZONE_BACK, 2, 0) && dirt_mess_place(taur, DIRT_ZONE_BACK, 3, 1), "Mess on the back landed nowhere on a bare taur.")
	SSdirt.finish_all()
	var/datum/component/dirtiness/taur_carrier = taur.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_drawing/taur_drawing = taur_carrier?.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	var/datum/dirt_mask_request/taur_request = taur_drawing?.request
	TEST_ASSERT(length(taur_request?.splats) >= 4, "The bare taur's body holds [length(taur_request?.splats)] splats, too few to merge.")
	var/datum/dirt_mask_job/taur_job = made_job(taur_request)
	TEST_ASSERT(taur_job.masks && !taur_job.failed, "The bare taur's body's masks weren't made.")
	for(var/direction in dirt_mask_directions())
		var/list/pixel_maps = list()
		for(var/alist/rasters as anything in taur_job.splat_rasters)
			pixel_maps += dirt_pixels_from_drawn(rasters[direction], DIRT_TAUR_WIDTH, ICON_SIZE_Y)
		var/difference = merge_difference(taur_job.merged[direction], dirt_merge(pixel_maps, taur_job.splat_materials))
		TEST_ASSERT(!difference, "The bare taur's body's splats facing [dir2text(direction)], streamed from their packed texts on the 64x32 canvas, merge with other [difference] than the masks read from them.")

/**
 * Returns what differs between two merged masks, or null where they're alike: their pixels' roles, thicknesses or
 * materials, or the pixels they list drawn, in any order (/datum/dirt_pixels/var/drawn_indexes).
 *
 * Arguments:
 * - merged: One mask, from dirt_merge().
 * - other: The other.
 */
/datum/unit_test/dirt_drawing/proc/merge_difference(datum/dirt_pixels/merged, datum/dirt_pixels/other)
	if(merged.grid_text() != other.grid_text())
		return "pixels"
	if(!(merged.thicknesses ~= other.thicknesses))
		return "thicknesses"
	if(!(merged.materials ~= other.materials))
		return "materials"
	if(!(sortTim(merged.drawn_indexes.Copy(), GLOBAL_PROC_REF(cmp_numeric_asc)) ~= sortTim(other.drawn_indexes.Copy(), GLOBAL_PROC_REF(cmp_numeric_asc))))
		return "pixels listed drawn"
	return null

/**
 * Returns an MD5 of a baked icon's pixels: GetPixel() of each, row by row in each of its four directions.
 *
 * Arguments:
 * - baked: The baked icon.
 */
/datum/unit_test/dirt_drawing/proc/baked_digest(baked)
	var/icon/baked_icon = icon(baked)
	var/list/pixels = list()
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		for(var/icon_y in 1 to ICON_SIZE_Y)
			for(var/icon_x in 1 to ICON_SIZE_X)
				pixels += "[baked_icon.GetPixel(icon_x, icon_y, null, direction)]"
	return md5(jointext(pixels, ","))

/**
 * Slime lands on a bare body's right arm, then on its left leg. Once the second masks are made, each limb draws the
 * icon its own runs bake. That holds for a limb whose runs the second deposit changed, so it doesn't keep the first
 * masks' icon. It also holds for a limb whose runs the deposit left as they were.
 */
/datum/unit_test/dirt_drawing/proc/check_limb_icons_kept()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/dirtiness/own = right_sided(body)
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_SLIMED_R_ARM, DIRT_MATERIAL_SLIME, 3, 0, "#4FC94A"), "Slime on the right arm landed nowhere on a bare body.")
	SSdirt.finish_all()
	var/datum/dirt_masks/first = own.skin?.masks
	TEST_ASSERT(first && first.key == own.skin.key, "The bare body's slimed right arm wasn't made.")
	TEST_ASSERT(dirt_land(body, DIRT_CAUSE_SLIMED_L_LEG, DIRT_MATERIAL_SLIME, 3, 0, "#4FC94A"), "Slime on the left leg landed nowhere on the bare body.")
	if(!SSdirt.mask_jobs[own.skin.key])
		// another test made them before, so they're made again, the skin still drawing the first masks
		SSdirt.masks.forget(own.skin.key)
		own.skin.forget(FALSE)
		body.update_body_parts()
	var/datum/dirt_mask_job/job = SSdirt.mask_jobs[own.skin.key]
	TEST_ASSERT(job, "The bare body's new skin masks weren't queued.")
	SSdirt.finish_all()
	var/datum/dirt_masks/second = own.skin.masks
	TEST_ASSERT(second && second == job.masks, "The skin doesn't draw its new masks.")
	var/kept = 0
	var/changed = 0
	for(var/zone, runs in job.limb_runs())
		TEST_ASSERT_EQUAL(second.baked_by_limb[zone], dirt_baked_icon(runs, null), "The skin's [zone] draws another icon than its runs bake.")
		if(first.limb_keys[zone] == second.limb_keys[zone])
			kept++
		else
			changed++
	TEST_ASSERT(kept && changed, "Slime on the left leg changed the runs of [changed] limbs and left [kept] as they were, so a limb keeping its icon can't be checked.")

/**
 * A biped's jumpsuit takes soot, then glowing blood, then sweat. The blood landed after the soot, so its stain draws
 * over the soot. On the emissive plane, the stain's glow draws over the soot's blocker. Sweat never draws over the
 * stain, so once it lands the stain still draws over the soot and the sweat. Soot landing again after the blood draws
 * its blocker over the glow.
 */
/datum/unit_test/dirt_drawing/proc/check_stain_over_sweat()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	right_sided(body)
	var/datum/component/dirtiness/carrier = jumpsuit.LoadComponent(/datum/component/dirtiness)
	var/torso_and_arms = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM)
	carrier.add_dirt(DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 2, torso_and_arms, 0)
	carrier.mess_changed()
	SSdirt.finish_all()
	// it glows when worn (/datum/blood_type/ethereal/proc/get_emissive_alpha())
	jumpsuit.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/ethereal)))
	// an item's first blood draws nothing by itself
	jumpsuit.update_slot_icon()
	SSdirt.finish_all()
	var/list/worn = uniform_places(body, carrier.cloth?.masks?.baked)
	TEST_ASSERT(worn[1] && worn[2] && worn[1] > worn[2], "Blood landed after a jumpsuit's soot draws its stain at [worn[1]], not over its soot at [worn[2]].")
	var/list/emissive = uniform_glow_places(body, carrier.cloth.masks.baked)
	TEST_ASSERT(emissive[1] && emissive[2], "A jumpsuit's glowing stain and its soot draw the stain's glow at [emissive[1]] and the soot's blocker at [emissive[2]] on the emissive plane, not both.")
	TEST_ASSERT(emissive[1] > emissive[2], "Glowing blood landed after a jumpsuit's soot draws its glow at [emissive[1]] on the emissive plane, under the soot's blocker at [emissive[2]].")
	carrier.add_dirt(DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 3, torso_and_arms, 0)
	carrier.mess_changed()
	SSdirt.finish_all()
	worn = uniform_places(body, carrier.cloth?.masks?.baked)
	TEST_ASSERT(worn[2] && worn[3], "A jumpsuit with soot and sweat draws its soot at [worn[2]] and its sweat's multiplier at [worn[3]], not both.")
	TEST_ASSERT(worn[1] > worn[2] && worn[1] > worn[3], "Sweat landed after a jumpsuit's blood moves its stain, at [worn[1]], under its older soot at [worn[2]] or its sweat at [worn[3]].")
	carrier.add_dirt(DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 1, torso_and_arms, 0)
	carrier.mess_changed()
	SSdirt.finish_all()
	emissive = uniform_glow_places(body, carrier.cloth?.masks?.baked)
	TEST_ASSERT(emissive[1] && emissive[2], "A jumpsuit whose soot landed again draws its stain's glow at [emissive[1]] and the soot's blocker at [emissive[2]] on the emissive plane, not both.")
	TEST_ASSERT(emissive[2] > emissive[1], "Soot landed after a jumpsuit's glowing blood draws its blocker at [emissive[2]] on the emissive plane, under the stain's glow at [emissive[1]].")

/**
 * Returns where a body's uniform draws its blood stain, an inset image of a baked icon and sweat's multiplier in its
 * worn wrapper, as list(the stain's place, the image's, the multiplier's). Each is 0 if it isn't drawn.
 *
 * Arguments:
 * - body: The body.
 * - baked: The baked icon, or null.
 */
/datum/unit_test/dirt_drawing/proc/uniform_places(mob/living/carbon/human/body, baked)
	RETURN_TYPE(/list)
	. = list(0, 0, 0)
	var/image/root = bulge_drawn_root(body.overlays_standing[UNIFORM_LAYER])
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
 * Returns where a body's uniform draws its blood stain's glow and the emissive blocker of a baked icon, as list(the
 * glow's place, the blocker's). Each is 0 if it isn't drawn. They're read from the slot as apply_overlay() keeps it.
 * That's the worn wrapper's mirror on the emissive plane (split_worn_emissive_branches()), where the stain's own mirror
 * holds its glow.
 *
 * Arguments:
 * - body: The body.
 * - baked: The baked icon, or null.
 */
/datum/unit_test/dirt_drawing/proc/uniform_glow_places(mob/living/carbon/human/body, baked)
	RETURN_TYPE(/list)
	. = list(0, 0)
	var/list/standing = body.overlays_standing[UNIFORM_LAYER]
	for(var/image/root as anything in (islist(standing) ? standing : list(standing)))
		if(PLANE_TO_TRUE(root.plane) != EMISSIVE_PLANE || !length(root.overlays))
			continue
		var/image/mirror = root.overlays[1]
		var/position = 0
		for(var/image/child as anything in mirror.overlays)
			position++
			if(baked && child.icon == baked)
				.[2] = position
			for(var/image/glow as anything in child.overlays)
				if(glow.icon == 'icons/effects/blood.dmi')
					.[1] = position
		return

/**
 * A taur body holding a pool, then walking mud, merges them in the order they landed. Once it's raised, the pool keeps
 * its place in that merge.
 */
/datum/unit_test/dirt_drawing/proc/check_raise_merge()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(rider), "Couldn't make the human a horse taur.")
	var/datum/component/dirtiness/own = right_sided(rider)
	var/datum/dirt_splat/pool = own.add_mess(DIRT_ZONE_BACK, ORGAN_SLOT_EXTERNAL_TAUR, 1, 0, redraw = FALSE)
	own.add_dirt(DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 1, NONE, 0, organ_slot = ORGAN_SLOT_EXTERNAL_TAUR)
	own.mess_changed(ORGAN_SLOT_EXTERNAL_TAUR)
	var/datum/dirt_drawing/drawing = own.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	var/datum/dirt_splat/first = LAZYACCESS(drawing?.request?.splats, 1)
	TEST_ASSERT(length(drawing?.request?.splats) == 2 && first.zone == DIRT_ZONE_BACK, "A taur body holding a pool, then walking mud, doesn't merge the pool first.")
	TEST_ASSERT(own.add_mess(DIRT_ZONE_BACK, ORGAN_SLOT_EXTERNAL_TAUR, 1) == pool && pool.level == 2, "A second shot on the taur body's pool didn't raise it.")
	first = LAZYACCESS(drawing.request?.splats, 1)
	TEST_ASSERT(first?.zone == DIRT_ZONE_BACK && first.level == 2, "A taur body's pool raised after walking mud landed moves after the mud in their merge.")
	// nothing more is checked of them, so they aren't made
	rider.wash(CLEAN_WASH)

/**
 * A taur body's queued pool goes with its job once the pool is taken off. Raising a pool undrawn replaces its masks'
 * request. If the taur body is then taken out, it takes the job of the masks asked for before the raise with it.
 */
/datum/unit_test/dirt_drawing/proc/check_dropped_jobs()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/taur_body/taur_body = give_taur(rider)
	TEST_ASSERT(taur_body, "Couldn't make the human a horse taur.")
	var/datum/component/dirtiness/own = right_sided(rider)
	var/datum/dirt_mask_job/job = queue_pool(rider, own)
	TEST_ASSERT(job, "The taur body's pool wasn't queued, so its job going as the pool is taken off can't be checked.")
	own.remove_mess(own.part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR][1])
	TEST_ASSERT(!(job in SSdirt.queue) && SSdirt.mask_jobs[job.key] != job, "The taur body's pool taken off left its job queued.")

	job = queue_pool(rider, own)
	TEST_ASSERT(job, "The taur body's second pool wasn't queued, so its job going with the taur body can't be checked.")
	own.add_mess(DIRT_ZONE_BACK, ORGAN_SLOT_EXTERNAL_TAUR, 1, redraw = FALSE)
	own.mess_changed(ORGAN_SLOT_EXTERNAL_TAUR, draw = FALSE)
	taur_body.Remove(rider, special = TRUE)
	TEST_ASSERT(!(job in SSdirt.queue) && SSdirt.mask_jobs[job.key] != job, "The taur body taken out left queued the job of its pool from before the pool was raised.")
	qdel(taur_body)

/**
 * Returns the job of the masks a pool landed on a taur's body asks for, or null. The pool is drawn as it lands. If
 * another check made those masks already, they're made again.
 *
 * Arguments:
 * - rider: The taur.
 * - own: Its carrier.
 */
/datum/unit_test/dirt_drawing/proc/queue_pool(mob/living/carbon/human/rider, datum/component/dirtiness/own)
	RETURN_TYPE(/datum/dirt_mask_job)
	own.add_mess(DIRT_ZONE_BACK, ORGAN_SLOT_EXTERNAL_TAUR, 1, 0)
	var/datum/dirt_drawing/drawing = own.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	if(!drawing?.request)
		return null
	if(!SSdirt.mask_jobs[drawing.key])
		SSdirt.masks.forget(drawing.key)
		drawing.forget(TRUE)
		rider.update_body()
	return SSdirt.mask_jobs[drawing.key]

/**
 * Blood that lands on a horse taur's clean labcoat by the item's own call draws no slot. Mud then lands on the taur
 * body, and then the coat's slot is drawn. The mud draws over the blood below the waist, because the blood counts as
 * landed when it landed, not when the slot drew it.
 */
/datum/unit_test/dirt_drawing/proc/check_waist_blood_direct()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(give_taur(taur), "Couldn't make the human a horse taur.")
	var/obj/item/clothing/suit/toggle/labcoat/coat = allocate(/obj/item/clothing/suit/toggle/labcoat)
	TEST_ASSERT(taur.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "Couldn't put a labcoat on the taur.")
	var/datum/component/dirtiness/own = right_sided(taur)
	TEST_ASSERT_NULL(coat.forensics, "The new labcoat holds forensics already, so its first blood would draw its slot.")
	coat.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	own.add_dirt(DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 2, NONE, 0, organ_slot = ORGAN_SLOT_EXTERNAL_TAUR)
	own.mess_changed(ORGAN_SLOT_EXTERNAL_TAUR)
	// as anything changing the coat draws it
	taur.update_worn_oversuit()
	SSdirt.finish_all()
	TEST_ASSERT(own.taur_blood?.masks, "A horse taur's bloodied labcoat draws no blood below its waist.")
	var/drawn_key = taur.icon_render_keys[BODY_ZONE_CHEST]
	TEST_ASSERT(!own.waist_blood_over() && drawn_key && !findtextEx(drawn_key, DIRT_TAUR_BLOOD_OVER_KEY), "Mud landed on a horse taur's body after blood landed on its labcoat by the coat's own call draws under that blood once the coat's slot is drawn.")

/**
 * A jumpsuit with mess is worn by a body that has a carrier of its own. At its next draw, the jumpsuit draws masks made
 * for the sprites the body draws then. That holds once the body's eyes are drawn from another state, and once its left
 * arm is restyled. Neither swaps an organ or a limb, so nothing but the jumpsuit's draw sees the change. The jumpsuit
 * matches the body's sprites through what the body's carrier noted of them for the garments it wears.
 */
/datum/unit_test/dirt_drawing/proc/check_worn_after_body_change()
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(body.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Couldn't dress the body in a jumpsuit.")
	right_sided(body)
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_CHEST), "A chest shot landed nowhere on the jumpsuit.")
	SSdirt.finish_all()
	var/datum/component/dirtiness/carrier = jumpsuit.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(worn_drawn_for(body, carrier), "The jumpsuit's mess isn't drawn from masks made for the body.")
	var/drawn_key = dirt_template_key(dirt_zone_sources(body))
	// as luminescent eyes do as their light turns on, keeping their organ
	var/obj/item/organ/eyes/eyes = body.get_organ_slot(ORGAN_SLOT_EYES)
	eyes.eye_icon_state = /obj/item/organ/eyes/moth::eye_icon_state
	body.update_body_parts()
	TEST_ASSERT_NOTEQUAL(dirt_template_key(dirt_zone_sources(body)), drawn_key, "Moth eyes leave the body drawn from the same sprites, so the jumpsuit's masks being made again for them can't be checked.")
	drawn_key = dirt_template_key(dirt_zone_sources(body))
	// as anything changing the jumpsuit draws it
	body.update_worn_undersuit()
	SSdirt.finish_all()
	TEST_ASSERT(worn_drawn_for(body, carrier), "The jumpsuit's mess is drawn from masks made for the eyes' sprites before they changed.")
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	arm.change_appearance(BODYPART_ICON_HUMANOID, SPECIES_HUMANOID, TRUE, FALSE)
	TEST_ASSERT_NOTEQUAL(dirt_template_key(dirt_zone_sources(body)), drawn_key, "The restyled left arm leaves the body drawn from the same sprites, so the jumpsuit's masks being made again for it can't be checked.")
	body.update_worn_undersuit()
	SSdirt.finish_all()
	TEST_ASSERT(worn_drawn_for(body, carrier), "The jumpsuit's mess is drawn from masks made before the left arm was restyled.")

/**
 * Returns whether a body's uniform draws its mess from masks made for the sprites the body draws
 * (dirt_zone_sources_match()).
 *
 * Arguments:
 * - body: The body.
 * - carrier: The uniform's carrier.
 */
/datum/unit_test/dirt_drawing/proc/worn_drawn_for(mob/living/carbon/human/body, datum/component/dirtiness/carrier)
	var/datum/dirt_drawing/cloth = carrier?.cloth
	if(!cloth?.request || !cloth.masks?.baked || cloth.masks.key != cloth.key || !dirt_zone_sources_match(body, cloth.request.zone_sources))
		return FALSE
	var/list/worn = uniform_places(body, cloth.masks.baked)
	return !!worn[2]

/**
 * A worn sprite with one direction, the cargo ribbon's, is drawn as its south view facing every way. So it shows
 * facing every way. Facing north, east and west, it reads the same pixels it reads facing south.
 */
/datum/unit_test/dirt_drawing/proc/check_one_direction_read()
	// a ribbon is drawn worn in its icon_state (icon_state_is_worn)
	var/sheet = /obj/item/clothing/accessory/medal/ribbon/cargo::worn_icon
	var/state = /obj/item/clothing/accessory/medal/ribbon/cargo::icon_state
	TEST_ASSERT(!length(icon_states(icon(sheet, state, EAST))), "The cargo ribbon's worn sprite has a view facing east, so a sprite with one direction can't be checked. Read one that has one.")
	TEST_ASSERT(dirt_sprite_shows(icon(sheet, state), SOUTH), "The cargo ribbon's worn sprite draws nothing facing south, so a sprite with one direction can't be checked. Read one that draws.")
	// read its facings first, so they come from the sprite rather than from the reads below
	TEST_ASSERT_EQUAL(dirt_sprite_facings(sheet, state), SOUTH | NORTH | EAST | WEST, "A worn sprite with one direction, drawn facing every way, doesn't show facing every way.")
	var/south = jointext(dirt_sprite_pixels(sheet, state, SOUTH), ",")
	TEST_ASSERT(length(south), "The cargo ribbon's worn sprite reads no pixels facing south.")
	for(var/direction in list(NORTH, EAST, WEST))
		TEST_ASSERT_EQUAL(jointext(dirt_sprite_pixels(sheet, state, direction), ","), south, "A worn sprite with one direction, drawn as its south view facing every way, reads otherwise facing [dir2text(direction)].")

/**
 * The heaviest body. It's dressed in every slot that takes dirt but the gloves, so a hand shows. It has a tail, wings,
 * horns, braided hair (its braid drawn over hats too) and a butt drawn on two layers above its clothes. It takes mess
 * to the cap, and then every general cause but the seven slime causes aimed at one zone. Each cause comes in a material
 * of its own. Then it takes soot and sweat on its tank top, sweat on its bra, and a shot on the butt. It holds
 * DIRT_MAX_SPLATS, and the mess, which landed first, goes first. It draws every surface's dirt within MAX_ATOM_OVERLAYS
 * less 40. Where its mud and its oil meet on a garment, each pixel takes the thicker one's colour.
 */
/datum/unit_test/dirt_budget
	parent_type = /datum/unit_test/dirt_drawing
	// the dirt of each cause it lands is made on a dressed body, many times over
	priority = TEST_LONGER

/datum/unit_test/dirt_budget/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "The butt needs genitals, which the config disables.")
		return
	// whatever earlier tests left queued is made first
	SSdirt.finish_all()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.set_hairstyle(/datum/sprite_accessory/hair/braid::name)
	var/list/colours = list("#5A8A4A", "#C8D8B0", "#3A2A20")
	body.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part(/datum/sprite_accessory/tails/lizard/short/twotone::name, colours)
	body.dna.mutant_bodyparts[FEATURE_WINGS] = build_mutant_part(/datum/sprite_accessory/wings/mammal/bat::name, colours)
	body.dna.mutant_bodyparts[FEATURE_HORNS] = build_mutant_part(/datum/sprite_accessory/horns/ram::name, colours)
	body.dna.species.regenerate_organs(body)
	body.update_body(is_creating = TRUE)
	var/list/parts = list(body.get_organ_by_type(/obj/item/organ/tail), body.get_organ_by_type(/obj/item/organ/wings), body.get_organ_by_type(/obj/item/organ/horns))
	TEST_ASSERT(!(null in parts), "Couldn't give the body a tail, wings and horns.")
	var/obj/item/organ/genital/butt/butt = make_genital(body, /obj/item/organ/genital/butt, ORGAN_SLOT_BUTT, /datum/sprite_accessory/genital/butt/pair::name, list("butt_size" = 6, "butt_uses_skincolor" = FALSE, "butt_uses_skintones" = FALSE))
	TEST_ASSERT(butt?.apply_visibility_label("Custom") && butt.apply_layering_label("Above all clothing"), "Couldn't give the body a butt drawn above all clothing.")
	body.underwear = /datum/sprite_accessory/clothing/underwear/male_boxers::name
	body.undershirt = /datum/sprite_accessory/clothing/undershirt/tank_white::name
	body.bra = /datum/sprite_accessory/clothing/bra/halterneck_bra::name
	body.update_body()
	// in this order, because the belt needs the jumpsuit
	var/list/outfit = list(
		/obj/item/clothing/under/color/grey = ITEM_SLOT_ICLOTHING,
		/obj/item/clothing/suit/toggle/labcoat = ITEM_SLOT_OCLOTHING,
		/obj/item/clothing/shoes/workboots = ITEM_SLOT_FEET,
		/obj/item/clothing/head/beret = ITEM_SLOT_HEAD,
		/obj/item/clothing/mask/breath = ITEM_SLOT_MASK,
		/obj/item/clothing/neck/tie = ITEM_SLOT_NECK,
		/obj/item/storage/belt/utility = ITEM_SLOT_BELT,
		/obj/item/storage/backpack = ITEM_SLOT_BACK,
		/obj/item/clothing/glasses/regular = ITEM_SLOT_EYES,
		/obj/item/radio/headset = ITEM_SLOT_EARS,
	)
	for(var/garment_type, slot in outfit)
		var/obj/item/garment = allocate(garment_type)
		TEST_ASSERT(body.equip_to_slot_if_possible(garment, slot), "Couldn't put the [garment.name] on the body.")
	SSdirt.finish_all()
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(head.dirt_hair_source(), "The beret hides the hair, so the hair's dirt can't be checked.")
	for(var/obj/item/organ/part as anything in parts)
		var/datum/bodypart_overlay/mutant/overlay = part.bodypart_overlay
		TEST_ASSERT(overlay.can_draw_on_bodypart(part.bodypart_owner, body) && overlay.dirt_shape_source_of(part.bodypart_owner), "The body's [part.name] isn't drawn as dirt reads it, so its dirt can't be checked.")
	var/datum/dirt_part_source/drawn_butt = dirt_part_drawn(butt, body)
	TEST_ASSERT(drawn_butt?.layered(), "The butt isn't drawn on two layers, so a part drawn on several can't be checked.")
	var/clean_overlays = length(body.overlays)
	right_sided(body)

	// mess to the cap, on each zone in turn
	var/list/zones = dirt_mess_zones()
	var/huge = dirt_mess_amount_levels(DIRT_MESS_AMOUNT_HUGE)
	for(var/landing in 1 to DIRT_MAX_SPLATS)
		dirt_mess_land(body, zones[(landing - 1) % length(zones) + 1], levels = huge)
	var/last_mess = SSdirt.serial
	// list(cause, material, slime's colour), machine work's oil and the plunge's mud last, so the garments hold both
	var/list/landings = list(
		list(DIRT_CAUSE_WALK, DIRT_MATERIAL_RED_CLAY),
		list(DIRT_CAUSE_KNEEL, DIRT_MATERIAL_GRIME),
		list(DIRT_CAUSE_CRAWL, DIRT_MATERIAL_DRIED_MUD),
		list(DIRT_CAUSE_DUST, DIRT_MATERIAL_DUST),
		list(DIRT_CAUSE_WEAR, DIRT_MATERIAL_PLASTER),
		list(DIRT_CAUSE_SPLASH, DIRT_MATERIAL_GREASE),
		list(DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT),
		list(DIRT_CAUSE_BLAST, DIRT_MATERIAL_ASH),
		list(DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT),
		list(DIRT_CAUSE_FALL, DIRT_MATERIAL_SLIME, "#C86E3C"),
		list(DIRT_CAUSE_SLIMED, DIRT_MATERIAL_SLIME, "#4FC94A"),
		list(DIRT_CAUSE_DOUSE, DIRT_MATERIAL_SLIME, "#3C64C8"),
		list(DIRT_CAUSE_MACHINE, DIRT_MATERIAL_OIL),
		list(DIRT_CAUSE_PLUNGE, DIRT_MATERIAL_MUD),
	)
	for(var/list/landing as anything in landings)
		TEST_ASSERT(dirt_land(body, landing[1], landing[2], 3, 0, LAZYACCESS(landing, 3)), "[landing[1]] in [landing[2]] landed nowhere on the dressed body.")
	// nothing lands on the underclothes under the jumpsuit and labcoat, so they hold dirt from before those went on
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	var/torso_and_arms = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM)
	// variant 5's sweat wets the halterneck's straps past the tank top
	TEST_ASSERT(own.add_underclothes_dirt(DIRT_UNDERCLOTHES_UNDERSHIRT, DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 3, torso_and_arms, 0) && own.add_underclothes_dirt(DIRT_UNDERCLOTHES_UNDERSHIRT, DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 3, torso_and_arms, 5) && own.add_underclothes_dirt(DIRT_UNDERCLOTHES_BRA, DIRT_CAUSE_SWEAT, DIRT_MATERIAL_SWEAT, 3, torso_and_arms, 5), "Couldn't put soot and sweat on the tank top and sweat on the bra.")
	var/list/changed = list()
	changed[own] = list(null)
	dirt_draw_landing(body, changed)
	TEST_ASSERT(dirt_mess_land(body, DIRT_ZONE_BUTT), "A shot on the butt above the clothes didn't land.")
	TEST_ASSERT(length(own.part_mess_splats[ORGAN_SLOT_BUTT]), "The butt drawn above the clothes took no share of a shot on it.")
	SSdirt.finish_all()

	var/list/serials = held_serials(body)
	TEST_ASSERT_EQUAL(length(serials), DIRT_MAX_SPLATS, "Past the cap the body holds [length(serials)] splats, not [DIRT_MAX_SPLATS].")
	TEST_ASSERT(min(serials) > last_mess && (SSdirt.serial in serials), "Past the cap the body holds splats [min(serials)] to [max(serials)], not the newest: the mess, landed first (up to [last_mess]), should go first.")
	var/drawn_overlays = length(body.overlays)
	TEST_NOTICE(src, "Dressed, with a tail, wings, horns, braided hair and a butt, the body draws [clean_overlays] overlays clean and [drawn_overlays] dirty at the cap, of the [MAX_ATOM_OVERLAYS] it may.")
	// room for whatever else a round puts on a body
	TEST_ASSERT(drawn_overlays < MAX_ATOM_OVERLAYS - 40, "A body dirty everywhere at the cap draws [drawn_overlays] overlays, within 40 of MAX_ATOM_OVERLAYS ([MAX_ATOM_OVERLAYS]).")
	check_surfaces(body, parts)
	check_merge(body)

/**
 * Checks that every surface of the dirty body draws its dirt. The skin draws it in a container on each limb its masks
 * hold a baked image for, a hand's among them. The tank top's soot draws in the underclothes' container, and the tank
 * top's and the bra's sweat in a multiplier each. Each garment holding dirt draws it in an inset image. The tail, the
 * wings and the horns draw it in a container at each of their layers. The hair and its braid draw it in a container
 * each, and the butt's share draws in a container over its front image.
 *
 * Arguments:
 * - body: The body.
 * - parts: Its tail, wings and horns.
 */
/datum/unit_test/dirt_budget/proc/check_surfaces(mob/living/carbon/human/body, list/parts)
	var/datum/component/dirtiness/own = body.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_masks/skin_masks = own.skin?.masks
	TEST_ASSERT(skin_masks, "The dressed body's skin draws no dirt.")
	var/dirty_hands = 0
	for(var/zone in dirt_skin_zone_limbs())
		if(skin_masks.baked_by_limb[zone])
			TEST_ASSERT(length(skin_images(body, zone, DIRT_SKIN_LAYER)), "The skin's dirt on the [zone] isn't drawn.")
		var/obj/item/bodypart/limb = body.get_bodypart(zone)
		if((zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM) && skin_masks.baked_by_limb[limb.aux_zone])
			TEST_ASSERT(length(skin_images(body, zone, DIRT_HAND_SKIN_LAYER)), "The skin's dirt on the [limb.aux_zone] isn't drawn.")
			dirty_hands++
	TEST_ASSERT(dirty_hands, "Neither hand's skin holds dirt, so a hand's container can't be checked.")

	var/list/multipliers = list()
	for(var/image/drawn as anything in multiply_images(body.drawn_limb_icons(BODY_ZONE_CHEST)))
		multipliers += drawn.icon
	// list(DIRT_UNDERCLOTHES_* define, accessory name)
	for(var/list/entry as anything in list(list(DIRT_UNDERCLOTHES_UNDERSHIRT, /datum/sprite_accessory/clothing/undershirt/tank_white::name), list(DIRT_UNDERCLOTHES_BRA, /datum/sprite_accessory/clothing/bra/halterneck_bra::name)))
		var/datum/dirt_drawing/sweaty = own.underclothes_drawings?[dirt_underclothes_key(entry[1], entry[2])]
		TEST_ASSERT(sweaty?.wet && (sweaty.wet in multipliers), "The sweaty [entry[2]] draws no multiplier of its own.")
	var/datum/dirt_drawing/tank_top = own.underclothes_drawings?[dirt_underclothes_key(DIRT_UNDERCLOTHES_UNDERSHIRT, /datum/sprite_accessory/clothing/undershirt/tank_white::name)]
	TEST_ASSERT(tank_top?.masks?.baked && holds_baked(body, BODY_ZONE_CHEST, tank_top.masks.baked), "The tank top's soot isn't drawn in the underclothes' container.")

	var/list/dirty_garments = list()
	for(var/obj/item/worn as anything in body.get_equipped_items())
		var/datum/component/dirtiness/carrier = worn.GetComponent(/datum/component/dirtiness)
		if(!carrier?.mess_count())
			continue
		TEST_ASSERT(length(inset_images(body, dirt_slot_layer(body.get_slot_by_item(worn)))), "The [worn.name] holds dirt but draws none.")
		dirty_garments += worn
	TEST_ASSERT((body.w_uniform in dirty_garments) && (body.wear_suit in dirty_garments) && (body.shoes in dirty_garments), "The jumpsuit, the labcoat or the boots hold no dirt, so their drawing can't be checked.")

	for(var/obj/item/organ/part as anything in parts)
		var/datum/dirt_drawing/drawing = own.part_drawings?[part.slot]
		TEST_ASSERT(length(drawing?.masks?.baked_by_layer), "The body's [part.name] draws no dirt.")
		for(var/layer_key, baked in drawing.masks.baked_by_layer)
			TEST_ASSERT(holds_baked(body, part.bodypart_owner.body_zone, baked), "The body's [part.name] draws no container of its dirt at its [layer_key] layer.")
	TEST_ASSERT_EQUAL(length(hair_containers(body)), 2, "The braided hair draws [length(hair_containers(body))] containers of its dirt, not two: the hair's and the braid's drawn over hats.")
	var/datum/dirt_drawing/share = own.part_drawings?[ORGAN_SLOT_BUTT]
	TEST_ASSERT(share?.masks?.baked && holds_baked(body, BODY_ZONE_CHEST, share.masks.baked), "The butt draws no container of its share over its front image.")

/**
 * Checks that where a garment's mud and oil alone draw, one a role thicker than the other, the thicker one's colour is
 * baked in its role's tint. Each deposit is rasterised as the garment's mask job rasterises it (packed, then kept to
 * its limbs), on the template its masks were made on.
 *
 * Arguments:
 * - body: The body wearing it.
 */
/datum/unit_test/dirt_budget/proc/check_merge(mob/living/carbon/human/body)
	var/datum/component/dirtiness/garment_carrier
	var/datum/dirt_splat/mud
	var/datum/dirt_splat/oil
	for(var/datum/component/dirtiness/carrier as anything in dirt_carriers(body))
		// a garment with no mess, whose masks are made
		if(!isitem(carrier.parent) || length(deposits_in(carrier.mess_splats)) != length(carrier.mess_splats) || !carrier.cloth?.masks?.baked || carrier.cloth.masks.key != carrier.cloth.key)
			continue
		mud = null
		oil = null
		for(var/datum/dirt_splat/deposit as anything in carrier.mess_splats)
			if(deposit.material == DIRT_MATERIAL_MUD)
				mud = deposit
			else if(deposit.material == DIRT_MATERIAL_OIL)
				oil = deposit
		if(mud && oil)
			garment_carrier = carrier
			break
	TEST_ASSERT(garment_carrier, "No garment without mess holds both the plunge's mud and machine work's oil, so their merge can't be checked.")
	var/obj/item/garment = garment_carrier.parent
	var/datum/dirt_mask_request/request = garment_carrier.cloth.request
	var/datum/dirt_template/template = dirt_build_template_now(request.zone_sources)
	var/icon/baked = icon(garment_carrier.cloth.masks.baked)
	var/list/ranks = dirt_role_ranks()
	var/checked = 0
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_surface/surface = template.surfaces[direction]
		// each deposit -> its roles
		var/list/roles_of = list()
		for(var/datum/dirt_splat/deposit as anything in garment_carrier.mess_splats)
			var/datum/dirt_pixels/raster = dirt_rasterise(deposit.cause, dirt_material(deposit.material), deposit.level, deposit.variant, request.side, DIRT_SURFACE_CLOTH, surface)
			raster = dirt_pixels_from_drawn(raster.drawn(), surface.width, surface.height, deposit.limbs, surface)
			roles_of[deposit] = raster.roles
		var/list/mud_roles = roles_of[mud]
		var/list/oil_roles = roles_of[oil]
		for(var/index in 1 to length(mud_roles))
			var/mud_role = mud_roles[index]
			var/oil_role = oil_roles[index]
			if(!mud_role || !oil_role || ranks[mud_role] == ranks[oil_role])
				continue
			var/alone = TRUE
			for(var/datum/dirt_splat/other, roles in roles_of)
				var/list/other_roles = roles
				if(other != mud && other != oil && other_roles[index])
					alone = FALSE
			if(!alone)
				continue
			var/mud_thicker = ranks[mud_role] > ranks[oil_role]
			var/role = mud_thicker ? mud_role : oil_role
			var/datum/dirt_material/thicker = dirt_material(mud_thicker ? mud.material : oil.material)
			// haze is baked as film at half its alpha
			var/list/tint = thicker.tints[role == DIRT_ROLE_HAZE ? DIRT_ROLE_FILM : role]
			var/list/wanted = rgb2num(tint[1])
			var/row = floor((index - 1) / surface.width)
			var/pixel = baked.GetPixel(index - row * surface.width, surface.height - row, null, direction)
			var/list/channels = pixel ? rgb2num(pixel) : list(null, null, null)
			TEST_ASSERT(channels[1] == wanted[1] && channels[2] == wanted[2] && channels[3] == wanted[3], "Where the [garment.name]'s mud and oil meet facing [dir2text(direction)] at pixel [index], the thicker [thicker.name] should bake [tint[1]], not [pixel || "nothing"].")
			checked++
	TEST_ASSERT(checked, "The [garment.name]'s mud and oil never meet alone with one a role thicker, so their merge can't be checked.")

#undef DIRT_CORPUS
#undef DIRT_MESS_BAKE_DIGESTS
#undef DIRT_WAG_CHECK_FILE
#undef DIRT_TAIL_HIP_COLUMN
#undef DIRT_TAIL_HIP_ROW
