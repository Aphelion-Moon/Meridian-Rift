/** Zero-damage cafe lava must not ignite objects or enqueue ongoing burning work. */
/turf/open/lava/fake/burn_stuff(atom/movable/to_burn, seconds_per_tick = 1)
	return FALSE

#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/** Harmless cafe lava must preserve objects; ordinary lava must still ignite them. */
/datum/unit_test/cafe_lava_does_not_ignite/Run()
	var/original_type = run_loc_floor_bottom_left.type
	var/original_baseturfs = run_loc_floor_bottom_left.baseturfs
	var/obj/item/cafe_object = allocate(/obj/item/stack/sheet/iron, run_loc_floor_top_right)
	var/original_resistance = cafe_object.resistance_flags
	var/turf/open/lava/fake/cafe_lava = run_loc_floor_bottom_left.ChangeTurf(/turf/open/lava/fake)
	var/cafe_processing = cafe_lava.burn_stuff(cafe_object)
	var/cafe_burning = cafe_object.GetComponent(/datum/component/burning)
	var/cafe_resistance = cafe_object.resistance_flags
	var/turf/open/lava/real_lava = cafe_lava.ChangeTurf(/turf/open/lava)
	// Reuse the surviving object: another sheet stack on this tile would auto-merge away.
	var/real_processing = real_lava.burn_stuff(cafe_object)
	var/real_burning = cafe_object.GetComponent(/datum/component/burning)
	real_lava.ChangeTurf(original_type, original_baseturfs)
	if(cafe_processing || cafe_burning || cafe_resistance != original_resistance)
		return Fail("Harmless cafe lava ignited an object, altered its resistance, or requested burning processing.", __FILE__, __LINE__)
	if(!real_processing || !real_burning)
		return Fail("Ordinary lava stopped igniting objects.", __FILE__, __LINE__)

#endif
