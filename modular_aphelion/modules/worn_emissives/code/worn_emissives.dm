/// Contiguous traversal selectors: visit underlays before overlays without allocating a selector list.
#define WORN_EMISSIVE_UNDERLAYS 1
#define WORN_EMISSIVE_OVERLAYS 2
/// The shared out-parameter's only slot; the proc's ordinary return value holds the emissive tree.
#define WORN_EMISSIVE_VISIBLE_RESULT 1

/// Finish worn masks after the slot has applied centering, limb offsets and height/missing-limb filters.
/// Cache the actual sibling appearances: remove_overlay and multiz plane rebuilding must see them too.
/// apply_overlay stores the result in overlays_standing; normal human rendering/resting reuses it.
/// This is not a memoization lookup: explicitly preparing a cached tree still checks its visible branches.
/mob/living/carbon/proc/prepare_worn_emissive_overlays(cache_index, worn_overlays)
	var/static/list/worn_layers = list(HANDS_LAYER, LEGCUFF_LAYER, HANDCUFF_LAYER, HEAD_LAYER, FACEMASK_LAYER, BACK_LAYER, NECK_LAYER, SUIT_STORE_LAYER, BELT_LAYER, GLASSES_LAYER, SUIT_LAYER, EARS_LAYER, SHOES_LAYER, GLOVES_LAYER, ID_LAYER, UNIFORM_LAYER)
	if(!(cache_index in worn_layers))
		return worn_overlays

	var/list/appearances = islist(worn_overlays) ? worn_overlays : null
	var/list/result
	var/list/visible_result
	for(var/index in 1 to (isnull(appearances) ? 1 : length(appearances)))
		var/mutable_appearance/worn = isnull(appearances) ? worn_overlays : appearances[index]
		var/mutable_appearance/mask
		// Leaves and already-split emissive roots require neither traversal nor temporary lists.
		if(worn.plane == FLOAT_PLANE && (length(worn.overlays) || length(worn.underlays)))
			visible_result ||= list(null)
			mask = split_worn_emissive_branches(worn, visible_result)
		if(mask)
			if(isnull(result))
				result = isnull(appearances) ? list() : appearances.Copy(1, index)
			result += visible_result[WORN_EMISSIVE_VISIBLE_RESULT]
			var/mutable_appearance/group = mutable_appearance(layer = worn.layer, offset_spokesman = src, plane = EMISSIVE_PLANE, appearance_flags = EMISSIVE_APPEARANCE_FLAGS)
			// Offsets stay INSIDE this group so the mob rotates them with the worn silhouette.
			group.overlays += mask
			result += group
		else if(!isnull(result))
			result += worn
	return isnull(result) ? worn_overlays : result

/**
 * Return the emissive-only tree, or null if nothing changed.
 * visible_result[WORN_EMISSIVE_VISIBLE_RESULT] receives the visible tree (null for a moved mask leaf).
 * The caller reuses this single return slot throughout the traversal; each node consumes its child's
 * result immediately. Unchanged branches retain their original appearances and allocate no lists.
 * Nested cross-plane masks escape the mob's KEEP_TOGETHER group. Moving the plane boundary to a
 * sibling root lets BYOND inherit the mob transform normally, without baking a pose into the cache.
 * Only floating equipment masks are moved; absolute-layer effects and other planes retain their behavior.
 */
/proc/split_worn_emissive_branches(mutable_appearance/source, list/visible_result)
	visible_result[WORN_EMISSIVE_VISIBLE_RESULT] = source
	if(source.plane != FLOAT_PLANE)
		if(PLANE_TO_TRUE(source.plane) != EMISSIVE_PLANE || source.layer >= 0)
			return null
		var/mutable_appearance/mask = new(source)
		mask.plane = FLOAT_PLANE
		mask.appearance_flags &= ~KEEP_APART
		visible_result[WORN_EMISSIVE_VISIBLE_RESULT] = null
		return mask
	if(!length(source.underlays) && !length(source.overlays))
		return null

	var/mutable_appearance/visible
	var/mutable_appearance/mask_parent
	for(var/child_set in WORN_EMISSIVE_UNDERLAYS to WORN_EMISSIVE_OVERLAYS)
		var/list/children = child_set == WORN_EMISSIVE_UNDERLAYS ? source.underlays : source.overlays
		var/list/visible_children
		var/list/mask_children
		for(var/index in 1 to length(children))
			var/mutable_appearance/child = children[index]
			var/mutable_appearance/child_mask = split_worn_emissive_branches(child, visible_result)
			if(child_mask)
				if(isnull(visible_children))
					visible_children = children.Copy(1, index)
					mask_children = list()
				if(!(source.appearance_flags & KEEP_TOGETHER) && child.plane != FLOAT_PLANE && child.icon == source.icon && child.icon_state == source.icon_state)
					// A base mask includes filters added AFTER build_worn_icon. Replace its
					// propagated filters instead of applying height displacement twice.
					child_mask.filters = source.filters
				mask_children += child_mask
			if(!isnull(visible_children) && visible_result[WORN_EMISSIVE_VISIBLE_RESULT])
				visible_children += visible_result[WORN_EMISSIVE_VISIBLE_RESULT]
		if(isnull(mask_children))
			continue
		if(isnull(mask_parent))
			visible = new(source)
			mask_parent = new(source)
			mask_parent.icon = null
			mask_parent.maptext = null
			mask_parent.render_source = null
			mask_parent.render_target = null
			mask_parent.color = null
			mask_parent.alpha = source.alpha
			mask_parent.underlays = null
			mask_parent.overlays = null
			// Keep existing group boundaries: ungrouped icons put filters on their base mask;
			// KEEP_TOGETHER wrappers apply filters to the composite instead.
			if(!(source.appearance_flags & KEEP_TOGETHER))
				mask_parent.filters = null
		if(child_set == WORN_EMISSIVE_UNDERLAYS)
			visible.underlays = visible_children
			mask_parent.underlays = mask_children
		else
			visible.overlays = visible_children
			mask_parent.overlays = mask_children
	visible_result[WORN_EMISSIVE_VISIBLE_RESULT] = visible || source
	return mask_parent

#undef WORN_EMISSIVE_UNDERLAYS
#undef WORN_EMISSIVE_OVERLAYS
#undef WORN_EMISSIVE_VISIBLE_RESULT
