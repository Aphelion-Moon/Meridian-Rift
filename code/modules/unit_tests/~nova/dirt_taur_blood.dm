/**
 * Blood below a taur's waist starts one row under its garment's stain, at every height. The stain is cut at the waist.
 * The rider's height filter then moves the stain's last row while the taur body under it stays put, so the start row
 * follows the height (dirt_blood_seam_row()). This test works out the stain's last row from the crop and the height
 * maps the game puts on it, so a change to either, or to the start rows, fails. Drawing the blood must also settle.
 * What it's drawn from is read on the render path, and checked again as worn sprites change. If the two disagree, the
 * taur redraws forever. That's most likely where the most is read: a bloodied uniform under a bloodied suit, and a
 * taur-fitted apron that carries the blood on its cloth and on the body under its hem. A taur-fitted suit draws its
 * share through a carrier of its own, made outside the render. A carrier made for the blood alone goes once the blood
 * is washed off or its garment is taken off. The newest landing draws on top. On a garment, its blood is ordered
 * against its own dirt. Below the waist, the blood is ordered against the taur body's own dirt. When blood lands again
 * over a garment's dirt, the order turns over with no masks made again. A garment holding the blood list of the one it
 * replaced counts as blood landing.
 */
/datum/unit_test/dirt_taur_blood
	parent_type = /datum/unit_test/dirt_genital_test

/datum/unit_test/dirt_taur_blood/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTNULL(give_taur(taur), "A human must be able to take a horse taur body")
	var/obj/item/clothing/suit/toggle/labcoat/coat = allocate(/obj/item/clothing/suit/toggle/labcoat)
	TEST_ASSERT(taur.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "A horse taur must be able to wear a labcoat")
	coat.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	for(var/height in list(HUMAN_HEIGHT_SHORTEST, HUMAN_HEIGHT_SHORT, HUMAN_HEIGHT_MEDIUM, HUMAN_HEIGHT_TALL, HUMAN_HEIGHT_TALLER, HUMAN_HEIGHT_TALLEST))
		taur.set_mob_height(height)
		check_start_row(taur, "height [height]")
	TEST_ASSERT(!coat.worn_x_offset, "A labcoat must be cut at a horse taur's waist, not taur-fitted, for its blood to run down the taur body")
	// a dwarf's height comes from the trait alone
	ADD_TRAIT(taur, TRAIT_DWARF, TRAIT_SOURCE_UNIT_TESTS)
	taur.update_mob_height()
	TEST_ASSERT_EQUAL(taur.mob_height, HUMAN_HEIGHT_DWARF, "A horse taur's rider with dwarfism must be a dwarf's height")
	check_start_row(taur, "a dwarf's height")
	REMOVE_TRAIT(taur, TRAIT_DWARF, TRAIT_SOURCE_UNIT_TESTS)
	taur.set_mob_height(HUMAN_HEIGHT_MEDIUM)

	var/obj/item/clothing/under/color/grey/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(taur.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "A horse taur must be able to wear a jumpsuit under its labcoat")
	jumpsuit.add_blood_DNA(list("Other DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	settles(taur, "in a bloodied jumpsuit under a bloodied labcoat")
	var/datum/component/dirtiness/carrier = taur.GetComponent(/datum/component/dirtiness)
	var/list/stains = carrier?.taur_blood?.request?.blood?[1]
	TEST_ASSERT_EQUAL(length(stains), 2, "A horse taur's bloodied jumpsuit and the bloodied labcoat over it must both run down its taur body")
	coat.wash(CLEAN_WASH)
	jumpsuit.wash(CLEAN_WASH)
	SSdirt.finish_all()
	TEST_ASSERT_NULL(taur.GetComponent(/datum/component/dirtiness), "A horse taur keeps the carrier of dirt made for the blood below its waist after its clothes are washed")

	var/obj/item/clothing/suit/apron/apron = allocate(/obj/item/clothing/suit/apron)
	TEST_ASSERT(taur.dropItemToGround(coat, force = TRUE) && taur.equip_to_slot_if_possible(apron, ITEM_SLOT_OCLOTHING), "A horse taur must be able to swap its labcoat for an apron")
	apron.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	for(var/height in list(HUMAN_HEIGHT_MEDIUM, HUMAN_HEIGHT_TALLEST))
		taur.set_mob_height(height)
		settles(taur, "in a bloodied apron at height [height]")
		TEST_ASSERT(apron.worn_x_offset, "An apron must be taur-fitted on a horse taur for its cloth to carry the blood - if it has no hoof sprite now, wear one that has")
		var/datum/component/dirtiness/apron_carrier = apron.GetComponent(/datum/component/dirtiness)
		TEST_ASSERT(apron_carrier?.taur_blood?.masks?.baked, "A horse taur's bloodied apron draws no blood on its cloth at height [height]")
		carrier = taur.GetComponent(/datum/component/dirtiness)
		TEST_ASSERT(carrier?.taur_blood?.masks && carrier.taur_blood.masks.key == carrier.taur_blood.key, "A horse taur in a bloodied apron at height [height] draws no blood on its body under the hem, or draws it for another height")
	TEST_ASSERT(taur.dropItemToGround(apron, force = TRUE), "A horse taur must be able to take off its apron")
	SSdirt.finish_all()
	TEST_ASSERT_NULL(apron.GetComponent(/datum/component/dirtiness), "A bloodied apron taken off a horse taur keeps the carrier of dirt made for the blood on its cloth")
	TEST_ASSERT_NULL(taur.GetComponent(/datum/component/dirtiness), "A horse taur that took off its bloodied apron keeps the carrier of dirt made for the blood below its waist")

	var/mob/living/carbon/human/consistent/feline = allocate(/mob/living/carbon/human/consistent)
	give_feline_taur(feline)
	var/obj/item/clothing/suit/space/eva/suit = allocate(/obj/item/clothing/suit/space/eva)
	TEST_ASSERT(feline.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "A feline taur must be able to wear an EVA suit")
	suit.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	settles(feline, "in a bloodied EVA suit")
	TEST_ASSERT(suit.worn_x_offset, "The EVA suit must be drawn from its taur sheet for its cloth to carry the blood - if it has no paw sprite now, wear one that has")
	var/datum/component/dirtiness/suit_carrier = suit.GetComponent(/datum/component/dirtiness)
	TEST_ASSERT(suit_carrier?.taur_blood?.masks?.baked, "A feline taur's bloodied EVA suit draws no blood on its cloth below the waist")
	check_newest_on_top()
	check_shared_blood_list()

/**
 * Checks that on a horse taur in a labcoat, the newest landing draws on top. Below the waist, the blood is ordered
 * against the taur body's own mud alone. Blood landing on a clean coat after the mud draws over it. Mud landing again
 * draws over the blood. Blood landing again draws over the mud through the cover check alone. Soot that lands on the
 * coat after its blood draws over the stain, and the blood below the waist stays over the older mud. Blood landing
 * again draws the stain over the soot, with no masks made again, and settles.
 */
/datum/unit_test/dirt_taur_blood/proc/check_newest_on_top()
	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTNULL(give_taur(taur), "A human must be able to take a horse taur body")
	var/obj/item/clothing/suit/toggle/labcoat/coat = allocate(/obj/item/clothing/suit/toggle/labcoat)
	TEST_ASSERT(taur.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "A horse taur must be able to wear a labcoat")
	var/datum/component/dirtiness/own = taur.LoadComponent(/datum/component/dirtiness)
	own.add_dirt(DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 2, NONE, 0, organ_slot = ORGAN_SLOT_EXTERNAL_TAUR)
	settles(taur, "with mud on its taur body")
	coat.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	settles(taur, "after blood landed on its clean labcoat")
	TEST_ASSERT_NULL(coat.GetComponent(/datum/component/dirtiness), "A clean bloodied labcoat on a horse taur has a carrier of dirt, so its blood's landing isn't read from the taur alone")
	var/datum/dirt_drawing/pools = own.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	TEST_ASSERT(own.taur_blood?.masks && pools?.masks, "A horse taur in a bloodied labcoat with mud on its taur body doesn't draw both below its waist")
	var/list/held = container_places(taur, own)
	TEST_ASSERT_NOTNULL(held, "No container on a horse taur's chest holds both the mud on its taur body and the blood below its waist")
	TEST_ASSERT(held[1] > held[2], "Blood landed on a clean labcoat draws under the older mud on a horse taur's body")

	// the mud is drawn as a landing draws a part's dirt (dirt_draw_landing())
	own.add_dirt(DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 2, NONE, 0, organ_slot = ORGAN_SLOT_EXTERNAL_TAUR)
	own.mess_changed(ORGAN_SLOT_EXTERNAL_TAUR)
	settles(taur, "after mud landed again on its taur body")
	held = container_places(taur, own)
	TEST_ASSERT(held && held[1] < held[2], "Mud landed again on a horse taur's body draws under the older blood below its waist")

	coat.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	// the landing draws the coat, and the cover check that follows draws the taur body
	SSdirt.finish_all()
	held = container_places(taur, own)
	TEST_ASSERT(held && held[1] > held[2], "Blood landed again on a clean labcoat draws under the older mud on a horse taur's body")

	var/datum/component/dirtiness/coat_carrier = coat.LoadComponent(/datum/component/dirtiness)
	coat_carrier.add_dirt(DIRT_CAUSE_SMOKE, DIRT_MATERIAL_SOOT, 2, DIRT_LIMB_BIT(DIRT_LIMB_TORSO), 0)
	settles(taur, "with soot landed on its labcoat after the coat's blood")
	var/soot = coat_carrier.cloth?.masks?.baked
	TEST_ASSERT_NOTNULL(soot, "A horse taur's sooty labcoat draws no soot")
	var/list/worn = worn_places(taur, soot)
	TEST_ASSERT(worn[1] && worn[2], "A horse taur's sooty, bloodied labcoat draws its stain at [worn[1]] and its soot at [worn[2]], not both")
	TEST_ASSERT(worn[1] < worn[2], "Soot landed after a labcoat's blood draws under the coat's stain")
	held = container_places(taur, own)
	TEST_ASSERT(held && held[1] > held[2], "Soot landing on a horse taur's labcoat puts the blood below its waist under the older mud on its body")
	var/cloth_key = coat_carrier.cloth.key
	var/blood_key = own.taur_blood.key

	coat.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	SSdirt.finish_all()
	worn = worn_places(taur, soot)
	TEST_ASSERT(worn[2] && worn[1] > worn[2], "Blood landed again on a sooty labcoat draws its stain at [worn[1]], under its soot at [worn[2]]")
	TEST_ASSERT_EQUAL(coat_carrier.cloth.key, cloth_key, "Blood landing on a sooty labcoat has the soot's masks made again")
	TEST_ASSERT_EQUAL(own.taur_blood?.key, blood_key, "Blood landing again on a horse taur's labcoat has the blood below its waist made again")
	settles(taur, "after blood landed again on its sooty labcoat")

/**
 * Checks that a labcoat put on in place of another counts as blood landing on a horse taur. Both labcoats are first
 * bloodied from one source, so they hold one blood DNA list. Once the second is on, the blood below the waist draws
 * over the mud that landed on the taur body after the first coat's blood.
 */
/datum/unit_test/dirt_taur_blood/proc/check_shared_blood_list()
	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NOTNULL(give_taur(taur), "A human must be able to take a horse taur body")
	var/obj/item/clothing/suit/toggle/labcoat/first = allocate(/obj/item/clothing/suit/toggle/labcoat)
	var/obj/item/clothing/suit/toggle/labcoat/second = allocate(/obj/item/clothing/suit/toggle/labcoat)
	// one list handed to both, as add_blood_DNA_to_items() hands one to every worn item
	var/list/source_blood = list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus))
	first.add_blood_DNA(source_blood)
	second.add_blood_DNA(source_blood)
	TEST_ASSERT(GET_ATOM_BLOOD_DNA(first) == GET_ATOM_BLOOD_DNA(second), "Two labcoats first bloodied from one list don't hold that one list, so this check checks nothing")
	TEST_ASSERT(taur.equip_to_slot_if_possible(first, ITEM_SLOT_OCLOTHING), "A horse taur must be able to wear a labcoat")
	var/datum/component/dirtiness/own = taur.LoadComponent(/datum/component/dirtiness)
	// the mud is drawn as a landing draws a part's dirt (dirt_draw_landing())
	own.add_dirt(DIRT_CAUSE_WALK, DIRT_MATERIAL_MUD, 2, NONE, 0, organ_slot = ORGAN_SLOT_EXTERNAL_TAUR)
	own.mess_changed(ORGAN_SLOT_EXTERNAL_TAUR)
	settles(taur, "with mud on its taur body after its labcoat's blood")
	var/list/held = container_places(taur, own)
	TEST_ASSERT(held && held[1] < held[2], "Mud landed after a labcoat's blood draws under that blood below a horse taur's waist")

	TEST_ASSERT(taur.dropItemToGround(first, force = TRUE) && taur.equip_to_slot_if_possible(second, ITEM_SLOT_OCLOTHING), "A horse taur must be able to swap its labcoat for another")
	settles(taur, "after putting on a second labcoat holding the first's blood list")
	held = container_places(taur, own)
	TEST_ASSERT(held && held[1] > held[2], "A labcoat put on that holds the blood list of the one it replaced draws its blood below a horse taur's waist under the older mud on its body")

/**
 * Returns where a taur's suit draws its blood stain and an inset image of a baked icon in its worn wrapper, as
 * list(the stain's place, the image's). Each is 0 if it isn't drawn.
 *
 * Arguments:
 * - taur: The taur.
 * - baked: The baked icon.
 */
/datum/unit_test/dirt_taur_blood/proc/worn_places(mob/living/carbon/human/taur, baked)
	RETURN_TYPE(/list)
	var/image/root = bulge_drawn_root(taur.overlays_standing[SUIT_LAYER])
	var/stain_at = 0
	var/baked_at = 0
	var/position = 0
	for(var/image/child as anything in root?.overlays)
		position++
		if(child.icon == 'icons/effects/blood.dmi')
			stain_at = position
		else if(child.icon == baked && child.blend_mode == BLEND_INSET_OVERLAY)
			baked_at = position
	return list(stain_at, baked_at)

/**
 * Returns where the blood below a taur's waist and the dirt on its taur body lie, as list(the blood's place, the
 * dirt's). It reads the first container on the taur's chest that holds both, and returns null if none does.
 *
 * Arguments:
 * - taur: The taur.
 * - own: The taur's carrier of dirt, with both drawn.
 */
/datum/unit_test/dirt_taur_blood/proc/container_places(mob/living/carbon/human/taur, datum/component/dirtiness/own)
	RETURN_TYPE(/list)
	var/datum/dirt_drawing/pools = own.part_drawings[ORGAN_SLOT_EXTERNAL_TAUR]
	for(var/layer_key, blood in own.taur_blood.masks.baked_by_layer)
		var/dirt = pools.masks.baked_by_layer[layer_key]
		if(!blood || !dirt)
			continue
		for(var/image/drawn as anything in taur.drawn_limb_icons(BODY_ZONE_CHEST))
			if(drawn.icon || !length(drawn.overlays))
				continue
			var/blood_at = 0
			var/dirt_at = 0
			var/position = 0
			for(var/image/held as anything in drawn.overlays)
				position++
				if(held.icon == blood)
					blood_at = position
				else if(held.icon == dirt)
					dirt_at = position
			if(blood_at && dirt_at)
				return list(blood_at, dirt_at)
	return null

/// Draws a taur again and finishes its dirt, then checks it settles, with nothing left queued or waiting to redraw.
/datum/unit_test/dirt_taur_blood/proc/settles(mob/living/carbon/human/taur, situation)
	taur.regenerate_icons()
	SSdirt.finish_all()
	TEST_ASSERT(!length(SSdirt.queue) && !length(SSdirt.redraws), "A taur's blood below the waist keeps asking to be drawn again [situation]")

/**
 * Checks that a horse taur's blood below the waist, from its bloodied labcoat, settles and starts one row under the
 * labcoat's stain facing south, east and west. It reads the stain's last row from the stain's crop and height filters.
 */
/datum/unit_test/dirt_taur_blood/proc/check_start_row(mob/living/carbon/human/taur, height_name)
	settles(taur, "at [height_name]")
	var/datum/component/dirtiness/carrier = taur.GetComponent(/datum/component/dirtiness)
	var/datum/dirt_masks/masks = carrier?.taur_blood?.masks
	TEST_ASSERT(masks && masks.key == carrier.taur_blood.key, "A horse taur in a bloodied labcoat at [height_name] draws no blood below its waist, or draws it for another height")
	var/image/stain = find_stain(taur.overlays_standing[SUIT_LAYER])
	TEST_ASSERT_NOTNULL(stain, "A horse taur's bloodied labcoat draws no blood stain at [height_name]")
	var/icon/crop
	for(var/dm_filter/stain_filter as anything in stain.filters)
		if(stain_filter.type == "alpha")
			crop = icon(stain_filter.icon)
	TEST_ASSERT_NOTNULL(crop, "A horse taur's labcoat stain isn't cut at the waist at [height_name]")
	var/list/maps = list()
	for(var/image/drawn as anything in islist(taur.overlays_standing[SUIT_LAYER]) ? taur.overlays_standing[SUIT_LAYER] : list(taur.overlays_standing[SUIT_LAYER]))
		if(drawn.plane == EMISSIVE_PLANE)
			continue
		// keep the maps in the order they're drawn
		for(var/dm_filter/height_filter as anything in drawn.filters)
			if(height_filter.type == "displace")
				maps += list(list(icon(height_filter.icon), height_filter.size))
		break
	var/drew = FALSE
	for(var/direction in list(SOUTH, EAST, WEST))
		var/top = blood_top_row(masks, direction)
		if(isnull(top))
			continue
		drew = TRUE
		TEST_ASSERT_EQUAL(top, stain_bottom(crop, maps, direction) + 1, "At [height_name] facing [dir2text(direction)], a horse taur's blood below the waist must start one row under its labcoat's stain")
	TEST_ASSERT(drew, "A horse taur in a bloodied labcoat at [height_name] draws no blood below its waist facing south, east or west")

/// Returns the first image drawn from icons/effects/blood.dmi among some worn images, searching their overlays too.
/datum/unit_test/dirt_taur_blood/proc/find_stain(standing)
	RETURN_TYPE(/image)
	for(var/image/drawn as anything in islist(standing) ? standing : list(standing))
		if(drawn.icon == 'icons/effects/blood.dmi')
			return drawn
		var/image/found = find_stain(drawn.overlays)
		if(found)
			return found
	return null

/**
 * Returns the row, from the top, that the stain's last row is drawn on: the crop's last whole row, moved by each height
 * map in turn. A map tells each row which row it shows, by its green channel (128 shows its own, 0 the row a size
 * above, 255 the row a size below), rounded to the nearest row. A row that shows a row past the stain's last shows no
 * stain.
 */
/datum/unit_test/dirt_taur_blood/proc/stain_bottom(icon/crop, list/maps, direction)
	var/bottom = -1
	for(var/row in 0 to ICON_SIZE_Y - 1)
		var/whole = TRUE
		for(var/column in 1 to ICON_SIZE_X)
			if(length(crop.GetPixel(column, ICON_SIZE_Y - row, null, direction)) != 7)
				whole = FALSE
				break
		if(!whole)
			break
		bottom = row
	for(var/list/map_entry as anything in maps)
		var/icon/map = map_entry[1]
		var/size = map_entry[2]
		var/moved = -1
		for(var/row in 0 to ICON_SIZE_Y - 1)
			var/shown = row
			var/colour = map.GetPixel(floor(map.Width() / 2), ICON_SIZE_Y - row)
			if(colour)
				shown += (rgb2num(colour)[2] - 128) / 127 * size
			if(floor(shown + 0.5) <= bottom)
				moved = row
		bottom = moved
	return bottom

/// Returns the highest row, from the top, any layer of a taur body's blood masks draws in a direction, or null if none.
/datum/unit_test/dirt_taur_blood/proc/blood_top_row(datum/dirt_masks/masks, direction)
	var/list/layer_icons = list()
	for(var/layer_key, entry in masks.baked_by_layer)
		var/icon/baked = entry
		layer_icons += icon(baked)
	for(var/row in 0 to ICON_SIZE_Y - 1)
		for(var/icon/layer_icon as anything in layer_icons)
			for(var/column in 1 to DIRT_TAUR_WIDTH)
				if(layer_icon.GetPixel(column, ICON_SIZE_Y - row, null, direction))
					return row
	return null
