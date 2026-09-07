/// Gets all the layer postfixes for this bodypart overlay
/datum/bodypart_overlay/proc/get_layer_postfixes()
	var/list/result = list()
	for(var/postfix in layers)
		result += postfix
	return result

/// Ensures SSaccessories.all_layer_postfixes matches the postfixes actually declared across every bodypart_overlay's layers list, in both directions.
/datum/unit_test/accessory_layers

/datum/unit_test/accessory_layers/Run()
	var/list/declared = list() // postfix -> first type that declares it, for error messages
	for(var/overlay_path in subtypesof(/datum/bodypart_overlay))
		var/datum/bodypart_overlay/overlay = new overlay_path()
		for(var/postfix in overlay.get_layer_postfixes())
			if(isnull(declared[postfix]))
				declared[postfix] = overlay_path
		qdel(overlay)

	for(var/postfix in declared)
		if(!(postfix in SSaccessories.all_layer_postfixes))
			TEST_FAIL("[declared[postfix]] declares layer postfix \"[postfix]\" which is missing from SSaccessories.all_layer_postfixes - add it to the list.")

	for(var/postfix in SSaccessories.all_layer_postfixes)
		if(isnull(declared[postfix]))
			TEST_FAIL("SSaccessories.all_layer_postfixes contains \"[postfix]\" but no bodypart_overlay declares it in a layers list - remove it, or add the overlay layer that should use it.")

/// Centering must use the actual canvas so emissive and visible wings share a rotation pivot.
/datum/unit_test/wing_icon_canvases

/datum/unit_test/wing_icon_canvases/Run()
	var/list/canvases = list()
	for(var/datum/sprite_accessory/wing_path as anything in subtypesof(/datum/sprite_accessory/wings) + subtypesof(/datum/sprite_accessory/wings_open))
		if(!initial(wing_path.center))
			continue
		var/icon_file = initial(wing_path.icon)
		var/icon/canvas = canvases[icon_file]
		if(!canvas)
			canvas = icon(icon_file)
			canvases[icon_file] = canvas
		TEST_ASSERT_EQUAL(initial(wing_path.dimension_x), canvas.Width(), "[wing_path] centers its wings using a width that does not match [icon_file].")
		TEST_ASSERT_EQUAL(initial(wing_path.dimension_y), canvas.Height(), "[wing_path] centers its wings using a height that does not match [icon_file].")
