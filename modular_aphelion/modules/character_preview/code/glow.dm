/**
 * What of a look glows in the dark, for the pages that show it with the lights off.
 *
 * The game lights a glowing pixel through its emissive plane: every emissive overlay and every blocker over one sits
 * there, at the layer of what it belongs to, so a blocker drawn later hides the glow under it. An emissive's colour
 * turns it red when it blooms and green when it doesn't; a blocker's turns it black. Flattening a look's emissive
 * overlays alone, as the plane holds them, gives that mask: get_flat_uni_icon() leaves them out of the look itself, as
 * they are on another plane. The worn-emissive grouping puts every emissive and blocker of a mob at its top level.
 */

/**
 * A look's own emissive overlays and underlays, the glowing and the blocking, layered in (low, high], as
 * list(overlays, underlays), each null when there are none. Underlays come only with the lowest layers, as a slice of
 * the look takes them.
 */
/proc/emissive_branches(image/look, low = -INFINITY, high = INFINITY)
	var/list/over
	var/list/under
	for(var/image/overlay as anything in look.overlays)
		if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE && overlay.layer > low && overlay.layer <= high)
			LAZYADD(over, overlay)
	if(low == -INFINITY)
		for(var/image/underlay as anything in look.underlays)
			if(PLANE_TO_TRUE(underlay.plane) == EMISSIVE_PLANE)
				LAZYADD(under, underlay)
	return list(over, under)

/// Whether any of emissive_branches() glows, rather than only blocking.
/proc/emissive_branches_lit(list/branches)
	for(var/list/side as anything in branches)
		for(var/image/branch as anything in side)
			if(emissive_branch_lit(branch))
				return TRUE
	return FALSE

/**
 * Whether an emissive-plane branch glows anywhere. An emissive's colour is a matrix whose constant row turns it red
 * (blooming) or green; BYOND keeps a blocker's, which only multiplies, as plain black. `inherited` is the colour the
 * branch takes from above it.
 */
/proc/emissive_branch_lit(image/node, inherited)
	var/color = node.color
	if(isnull(color) && !(node.appearance_flags & RESET_COLOR))
		color = inherited
	if(node.icon && islist(color))
		var/list/matrix = color
		if(length(matrix) >= 20 && (matrix[17] > 0 || matrix[18] > 0))
			return TRUE
	for(var/image/child as anything in node.overlays)
		if(emissive_branch_lit(child, color))
			return TRUE
	for(var/image/child as anything in node.underlays)
		if(emissive_branch_lit(child, color))
			return TRUE
	return FALSE

/**
 * emissive_branches() of `look` in a holder that get_flat_uni_icon() draws as the emissive plane holds them, placed as
 * they are on the look: its layer and facing, and a blank tile of its own at the look's lower left, where the look's
 * own icon is. Null when there are none.
 */
/proc/emissive_holder(list/branches, image/look)
	var/list/over = branches[1]
	var/list/under = branches[2]
	if(!length(over) && !length(under))
		return null
	var/mutable_appearance/holder = new()
	holder.icon = 'icons/blanks/32x32.dmi'
	holder.icon_state = "nothing"
	// The flatten takes only overlays on its own plane.
	var/image/first = length(over) ? over[1] : under[1]
	holder.plane = first.plane
	holder.layer = look.layer
	holder.dir = look.dir
	if(length(over))
		holder.overlays = over
	if(length(under))
		holder.underlays = under
	return holder

/**
 * A look's glow, flattened facing `dir` onto `box`, its drawing's canvas as list(x1, y1, width, height) from the look's
 * own lower left pixel, or null when nothing in it glows. `always` draws it whatever it holds, blank if nothing, for a
 * facing whose drawing's other facings glow.
 */
/proc/character_preview_glow(image/look, dir, list/box, always = FALSE)
	var/list/branches = emissive_branches(look)
	if(!always && !emissive_branches_lit(branches))
		return null
	var/mutable_appearance/holder = emissive_holder(branches, look)
	var/datum/universal_icon/flat = holder ? get_flat_uni_icon(holder, dir, grow = TRUE) : uni_icon('icons/blanks/32x32.dmi', "nothing")
	var/list/glow_box = character_preview_flat_box(flat)
	flat.crop(box[1] - glow_box[1] + 1, box[2] - glow_box[2] + 1, box[1] + box[3] - glow_box[1], box[2] + box[4] - glow_box[2])
	return flat
