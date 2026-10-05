#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/// Shrinking an active light must release outer grid cells and update holder visibility.
/datum/unit_test/overlay_light_range

/datum/unit_test/overlay_light_range/Run()
	// The radius crosses the 17-turf grid boundary at six, but not at one.
	var/turf/location = locate(13, 8, run_loc_floor_bottom_left.z)
	var/obj/item/flashlight/light = allocate(/obj/item/flashlight, location)
	light.set_light_range(6)
	light.set_light_on(TRUE)
	var/datum/component/overlay_lighting/component = light.GetComponent(/datum/component/overlay_lighting)
	TEST_ASSERT_NOTNULL(component, "Flashlight should use overlay lighting")
	var/list/old_cells = SSspatial_grid.get_cells_in_range(location, 6)
	var/list/new_cells = SSspatial_grid.get_cells_in_range(location, 1)
	TEST_ASSERT(length(old_cells) > length(new_cells), "Test range must cross a spatial grid boundary")
	for(var/datum/spatial_grid_cell/cell as anything in old_cells)
		TEST_ASSERT(component in cell.dynamic_light_sources, "Initial light registration missing")
	light.set_light_range(1)
	for(var/datum/spatial_grid_cell/cell as anything in old_cells)
		if((component in cell.dynamic_light_sources) != (cell in new_cells))
			TEST_FAIL("Range shrink left incorrect grid ownership")
	if(light.affected_dynamic_lights[component] != 2)
		TEST_FAIL("Holder visibility still uses the previous light radius")
	qdel(light)
	for(var/datum/spatial_grid_cell/cell as anything in old_cells)
		if(component in cell.dynamic_light_sources)
			TEST_FAIL("Deleted light remains referenced by a grid cell")

TEST_FOCUS(/datum/unit_test/overlay_light_range)
#endif
