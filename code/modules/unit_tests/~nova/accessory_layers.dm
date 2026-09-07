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

/// Visible accessories and their emissive masks must rotate around the same 32x32 body origin.
/datum/unit_test/accessory_icon_canvases

/datum/unit_test/accessory_icon_canvases/Run()
	var/list/canvases = list()
	for(var/datum/sprite_accessory/accessory_path as anything in subtypesof(/datum/sprite_accessory))
		// Abstract parents and "None" choices do not draw an accessory.
		if(!initial(accessory_path.icon) || !initial(accessory_path.icon_state) || !initial(accessory_path.factual))
			continue
		var/icon_file = initial(accessory_path.icon)
		var/icon/canvas = canvases[icon_file]
		if(!canvas)
			canvas = icon(icon_file)
			canvases[icon_file] = canvas
		var/centered = initial(accessory_path.center)
		var/width = centered ? initial(accessory_path.dimension_x) : ICON_SIZE_X
		var/height = centered ? initial(accessory_path.dimension_y) : ICON_SIZE_Y
		if(width != canvas.Width() || height != canvas.Height())
			TEST_FAIL("[accessory_path] uses a [canvas.Width()]x[canvas.Height()] canvas in [icon_file], but centers for [width]x[height] (center = [centered]).")
