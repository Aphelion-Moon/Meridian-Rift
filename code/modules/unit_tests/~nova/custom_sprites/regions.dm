/datum/unit_test/custom_sprite_region_map/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/list/zones = custom_sprite_present_regions(human)
	for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		TEST_ASSERT((zone in zones), "A whole human must have a [zone] region.")
	TEST_ASSERT(!(CUSTOM_MARKING_ZONE_TAUR in zones), "A body without a taur organ has no taur region.")
	TEST_ASSERT(zones.Find(BODY_ZONE_PRECISE_L_HAND) == zones.Find(BODY_ZONE_L_ARM) + 1, "Each hand must come straight after its arm.")
	var/list/map = custom_sprite_region_map(human, zones, 32)
	TEST_ASSERT(map == custom_sprite_region_map(human, zones, 32), "Unchanged geometry must reuse the cached map.")
	for(var/direction in GLOB.custom_style_directions)
		var/list/rows = map[direction]
		TEST_ASSERT(!(length(rows) != 32 || length(rows[1]) != 32), "Region maps must be 32 rows of 32 pixels.")
		var/list/masks = list()
		for(var/zone in zones)
			masks[zone] = custom_sprite_body_draw_mask(human, zone, 32)[direction]
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/list/covering = list()
				for(var/zone in zones)
					if(copytext(masks[zone][y], x, x + 1) == "1")
						covering += zone
				var/owner = custom_sprite_region_owner(rows, zones, x - 1, y - 1)
				TEST_ASSERT(!(length(covering) && !(owner in covering)), "Pixel [x],[y] in view [direction] must belong to a region whose mask covers it.")
				TEST_ASSERT(!(!length(covering) && owner), "Pixel [x],[y] in view [direction] is outside every mask and must have no region.")
				if(length(covering) == 1)
					TEST_ASSERT(owner == covering[1], "A pixel only one region covers must belong to it.")
				// Arms and the torso share a layer, so whichever the body draws later owns their overlap.
				for(var/arm in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM))
					var/hand = custom_marking_partner(arm)
					if((BODY_ZONE_CHEST in covering) && (arm in covering) && !(hand in covering))
						TEST_ASSERT(owner == (zones.Find(BODY_ZONE_CHEST) > zones.Find(arm) ? BODY_ZONE_CHEST : arm), "The torso/arm overlap at [x],[y] must follow draw order.")
		// A hand's own pixels sit on the high layer, over every ordinary limb on a plain human.
		// Its wrist band shares the arm's layer, so the torso may cover it in side views.
		for(var/hand in list(BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND))
			var/icon/palm = custom_sprite_silhouette(human.get_bodypart(GLOB.custom_marking_hand_arms[hand]), TRUE)
			for(var/y in 1 to 32)
				for(var/x in 1 to 32)
					if(palm.GetPixel(x, 33 - y, "", text2num(direction)))
						TEST_ASSERT(custom_sprite_region_owner(rows, zones, x - 1, y - 1) == hand, "[hand] must own its own pixels in view [direction].")
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb(special = TRUE)
	qdel(arm)
	zones = custom_sprite_present_regions(human)
	TEST_ASSERT(!((BODY_ZONE_L_ARM in zones) || (BODY_ZONE_PRECISE_L_HAND in zones)), "A missing arm takes its hand region with it.")
	TEST_ASSERT((BODY_ZONE_PRECISE_R_HAND in zones), "The other arm keeps its hand.")

/datum/unit_test/custom_sprite_region_map_taur/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(custom_sprite_test_taur(human), "The fixture needs a real taur organ.")
	var/list/zones = custom_sprite_present_regions(human)
	TEST_ASSERT(!((BODY_ZONE_L_LEG in zones) || (BODY_ZONE_R_LEG in zones)), "Invisible taur legs have no region.")
	TEST_ASSERT(zones[length(zones)] == CUSTOM_MARKING_ZONE_TAUR, "The taur region comes last.")
	var/list/map = custom_sprite_region_map(human, zones, CUSTOM_SPRITE_TAUR_WIDTH)
	var/index = "[length(zones)]"
	var/owned = FALSE
	for(var/_direction, rows in map)
		TEST_ASSERT(length(rows[1]) == CUSTOM_SPRITE_TAUR_WIDTH, "Taur maps are 64 pixels wide.")
		for(var/row in rows)
			owned ||= !!findtext(row, index)
	TEST_ASSERT(owned, "The taur region must own pixels.")
	// Each owned pixel lies in its owner's own mask; ordinary regions sit in the central 32 columns.
	for(var/direction, rows in map)
		for(var/y in 1 to 32)
			for(var/x in 1 to CUSTOM_SPRITE_TAUR_WIDTH)
				var/owner = custom_sprite_region_owner(rows, zones, x - 1, y - 1)
				if(!owner)
					continue
				var/zone_width = custom_marking_zone_width(owner)
				var/zone_x = x - (CUSTOM_SPRITE_TAUR_WIDTH - zone_width) / 2
				TEST_ASSERT(!(zone_x < 1 || zone_x > zone_width), "[owner] owns [x],[y] in view [direction], outside its [zone_width]-wide area.")
				TEST_ASSERT(copytext(custom_sprite_body_draw_mask(human, owner, zone_width)[direction][y], zone_x, zone_x + 1) == "1", "[owner] owns [x],[y] in view [direction], which its own mask doesn't cover.")

/datum/unit_test/custom_sprite_region_mask/Run()
	var/list/map = list("2" = list("0120" + repeat_string(28, "0")))
	var/list/mask = custom_sprite_region_mask(map)
	TEST_ASSERT(mask["2"][1] == "0110" + repeat_string(28, "0"), "Every owned pixel is paintable; unowned pixels aren't.")
	var/list/bounds = custom_sprite_mask_bounds(mask, 32)
	TEST_ASSERT(json_encode(bounds["2"]) == json_encode(list(0, 0, 3, 1)), "Mask bounds pad the painted box by one pixel.")
	TEST_ASSERT(custom_marking_partner(BODY_ZONE_L_ARM) == BODY_ZONE_PRECISE_L_HAND && custom_marking_partner(BODY_ZONE_PRECISE_R_HAND) == BODY_ZONE_R_ARM && !custom_marking_partner(BODY_ZONE_CHEST), "Arms and hands pair up; other regions have no partner.")

/// A hand's drawing may paint the arm rows just above it, but on the canvas they're the arm's, so the arm runs its whole length.
/datum/unit_test/custom_sprite_region_map_wrist/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/list/zones = custom_sprite_present_regions(human)
	var/list/map = custom_sprite_region_map(human, zones, 32)
	for(var/hand in list(BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND))
		var/list/mask = custom_sprite_body_draw_mask(human, hand, 32)
		var/icon/palm = custom_sprite_silhouette(human.get_bodypart(GLOB.custom_marking_hand_arms[hand]), TRUE)
		var/wrist = 0
		// Front and back only: the torso can cover the wrist band in side views.
		for(var/direction in list("[SOUTH]", "[NORTH]"))
			for(var/y in 1 to 32)
				for(var/x in 1 to 32)
					if(copytext(mask[direction][y], x, x + 1) != "1" || palm.GetPixel(x, 33 - y, "", text2num(direction)))
						continue
					wrist++
					TEST_ASSERT(custom_sprite_region_owner(map[direction], zones, x - 1, y - 1) == GLOB.custom_marking_hand_arms[hand], "[GLOB.custom_marking_hand_arms[hand]] must own [hand]'s wrist band at [x],[y] in view [direction].")
		TEST_ASSERT(wrist, "The fixture needs [hand]'s wrist band.")

/datum/unit_test/custom_sprite_region_colors/Run()
	var/list/colors = list()
	for(var/index in 1 to 9)
		var/color = custom_sprite_region_color(index)
		TEST_ASSERT(!(length(color) != 7 || color != LOWER_TEXT(color)), "Region ID colors are lowercase #rrggbb, as the map reads them back.")
		TEST_ASSERT(!(color in colors), "Region ID colors must be distinct.")
		colors += color
	// An antialiased edge blends two regions; the blend must never read as a third one.
	for(var/first in 1 to 9)
		for(var/second in 1 to 9)
			if(first == second)
				continue
			var/list/a = rgb2num(colors[first])
			var/list/b = rgb2num(colors[second])
			for(var/weight in list(0.25, 0.5, 0.75))
				var/blend = LOWER_TEXT(rgb(round(a[1] * weight + b[1] * (1 - weight), 1), round(a[2] * weight + b[2] * (1 - weight), 1), round(a[3] * weight + b[3] * (1 - weight), 1)))
				var/found = colors.Find(blend)
				TEST_ASSERT(!(found && found != first && found != second), "A [weight] blend of regions [first] and [second] must not read as region [found].")

/datum/unit_test/custom_sprite_region_fallback/Run()
	// A faint edge of region 1 drawn over solid region 3.
	var/icon/faint = custom_sprite_blank_icon(32)
	faint.DrawBox(rgb(0, 0, 0, 77), 5, 28)
	var/icon/solid = custom_sprite_blank_icon(32)
	solid.DrawBox(rgb(0, 0, 0, 255), 5, 28)
	TEST_ASSERT(custom_sprite_region_fallback(list(list(1, 3, 1, 1, solid), list(2, 1, 1, 1, faint)), 4, 4, SOUTH) == "3", "A blended edge pixel goes to the region that dominates it, not just the topmost one.")
	TEST_ASSERT(custom_sprite_region_fallback(list(list(1, 3, 1, 1, faint), list(2, 1, 1, 1, solid)), 4, 4, SOUTH) == "1", "A solid region on top still owns the pixel.")

/datum/unit_test/custom_sprite_region_map_uncached/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/limb = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/zone/scratch = new
	scratch.blocks_emissive = EMISSIVE_BLOCK_NONE
	scratch.cache_icons = FALSE
	scratch.set_drawing(custom_sprite_region_id_drawing(1, custom_sprite_body_draw_mask(human, BODY_ZONE_L_ARM, 32), 32), limb)
	scratch.get_all_overlays(limb)
	for(var/key in GLOB.custom_sprite_limb_icons)
		TEST_ASSERT(!findtext(key, scratch.drawing_pixel_hash), "Region-map scratch overlays must not fill the shared limb icon cache.")
	qdel(scratch)

/// A region map's paintable mask keeps every owned pixel except the locked regions', region 1 included.
/datum/unit_test/custom_sprite_region_mask_locks/Run()
	var/list/map = list("2" = list("0123456789", "9876543210"))
	TEST_ASSERT(json_encode(custom_sprite_region_mask(map)) == json_encode(list("2" = list("0111111111", "1111111110"))), "With nothing locked, every owned pixel must be paintable.")
	TEST_ASSERT(json_encode(custom_sprite_region_mask(map, list("1", "9"))) == json_encode(list("2" = list("0011111110", "0111111100"))), "Locked regions must leave the mask, region 1 included.")
