/// Contiguous traversal selectors: visit underlays before overlays without allocating a selector list.
#define WORN_EMISSIVE_UNDERLAYS 1
#define WORN_EMISSIVE_OVERLAYS 2
/// The shared out-parameter's only slot; the proc's ordinary return value holds the emissive tree.
#define WORN_EMISSIVE_VISIBLE_RESULT 1

/// Clothing and held-item layers shared by worn-mask preparation and dressed previews.
GLOBAL_LIST_INIT(worn_overlay_layers, list(
	HANDS_LAYER, LEGCUFF_LAYER, HANDCUFF_LAYER, HEAD_LAYER, FACEMASK_LAYER, BACK_LAYER, NECK_LAYER,
	SUIT_STORE_LAYER, BELT_LAYER, GLASSES_LAYER, SUIT_LAYER, EARS_LAYER, SHOES_LAYER, GLOVES_LAYER,
	ID_LAYER, UNIFORM_LAYER, BODY_LAYER,
))

/// Finish worn masks after the slot has applied centering, limb offsets and height/missing-limb filters.
/// Cache the actual sibling appearances: remove_overlay and multiz plane rebuilding must see them too.
/// apply_overlay stores the result in overlays_standing; normal human rendering/resting reuses it.
/// This is not a memoization lookup: explicitly preparing a cached tree still checks its visible branches.
/mob/living/carbon/proc/prepare_worn_emissive_overlays(cache_index, worn_overlays)
	if(cache_index == BODYPARTS_LAYER || cache_index == HAIR_LAYER)
		return prepare_bodypart_overlays(worn_overlays)
	if(!(cache_index in GLOB.worn_overlay_layers))
		return worn_overlays

	var/list/appearances = islist(worn_overlays) ? worn_overlays : null
	var/list/result
	var/list/visible_result
	// Layer key -> this slot's open group, so items sharing a slot and layer share one top-level root.
	var/list/open_groups
	for(var/index in 1 to (isnull(appearances) ? 1 : length(appearances)))
		var/mutable_appearance/worn = isnull(appearances) ? worn_overlays : appearances[index]
		var/layer_key = num2text(worn.layer, 12)
		var/mutable_appearance/mask
		// Leaves and already-split emissive roots require neither traversal nor temporary lists.
		if(worn.plane == FLOAT_PLANE && (length(worn.overlays) || length(worn.underlays)))
			visible_result ||= list(null)
			mask = split_worn_emissive_branches(worn, visible_result)
		if(mask)
			if(isnull(result))
				result = isnull(appearances) ? list() : appearances.Copy(1, index)
			result += visible_result[WORN_EMISSIVE_VISIBLE_RESULT]
			var/mutable_appearance/group = LAZYACCESS(open_groups, layer_key)
			if(isnull(group))
				group = mutable_appearance(layer = worn.layer, offset_spokesman = src, plane = EMISSIVE_PLANE, appearance_flags = EMISSIVE_APPEARANCE_FLAGS)
				LAZYSET(open_groups, layer_key, group)
				result += group
			// Offsets stay INSIDE this group so the mob rotates them with the worn silhouette.
			group.overlays += mask
			continue
		if(!isnull(result))
			result += worn
		// An emissive root already in the slot keeps its draw order: later masks at its layer start a new group.
		if(PLANE_TO_TRUE(worn.plane) == EMISSIVE_PLANE)
			LAZYREMOVE(open_groups, layer_key)
	return isnull(result) ? worn_overlays : result

/**
 * Prepares the final bodypart or hair slot, where direct glow/blocker masks already have their centering and
 * height adjustments. Each mask moves inside a neutral emissive boundary so rotation does not depend
 * on icon size; masks sharing a plane and layer share one boundary. Plain visible sprites sharing a
 * layer share one holder. Only the mob's top-level overlays count toward MAX_ATOM_OVERLAYS, and a
 * matrixed accessory otherwise spends a sprite and a mask per colour slot on every layer it draws.
 *
 * Draw order is kept: an entry that cannot join stays in place, and later entries at its layer start
 * a new boundary or holder. Shared limb-cache appearances are copied or nested, never modified.
 * Prepared roots cannot join again and single sprites are not wrapped, so repeating the pass adds nothing.
 *
 * Arguments:
 * * bodypart_overlays - the BODYPARTS_LAYER or HAIR_LAYER cache entry, a list or a single appearance
 *
 * Returns a new list for the cache.
 */
/proc/prepare_bodypart_overlays(list/bodypart_overlays)
	if(!islist(bodypart_overlays))
		bodypart_overlays = list(bodypart_overlays)
	var/list/result = list()
	// Layer key -> sprites collected for one holder; the list sits in result as a placeholder until the end.
	var/list/open_holders = list()
	// Plane and layer key -> the open emissive boundary for masks there.
	var/list/open_groups = list()
	for(var/mutable_appearance/source as anything in bodypart_overlays)
		var/layer_key = num2text(source.layer, 12)
		if(is_plain_bodypart_mask(source))
			var/group_key = "[source.plane]|[layer_key]"
			var/mutable_appearance/group = open_groups[group_key]
			if(isnull(group))
				group = mutable_appearance(layer = source.layer, appearance_flags = EMISSIVE_APPEARANCE_FLAGS)
				group.plane = source.plane // The source plane already includes its multiz offset.
				open_groups[group_key] = group
				result += group
			var/mutable_appearance/mask = new(source)
			mask.plane = FLOAT_PLANE
			mask.appearance_flags &= ~KEEP_APART
			group.overlays += mask
		else if(is_plain_bodypart_sprite(source))
			var/list/holder_contents = open_holders[layer_key]
			if(isnull(holder_contents))
				holder_contents = list()
				open_holders[layer_key] = holder_contents
				result += list(holder_contents)
			holder_contents += source
		else
			if(PLANE_TO_TRUE(source.plane) == EMISSIVE_PLANE)
				open_groups -= "[source.plane]|[layer_key]"
			else
				open_holders -= layer_key
			result += source

	for(var/index in 1 to length(result))
		var/list/holder_contents = result[index]
		if(!islist(holder_contents))
			continue
		if(length(holder_contents) == 1)
			result[index] = holder_contents[1]
			continue
		var/mutable_appearance/first = holder_contents[1]
		var/mutable_appearance/holder = mutable_appearance(layer = first.layer)
		holder.overlays += holder_contents
		result[index] = holder
	return result

/**
 * Whether a bodypart appearance is a standard glow/blocker sprite that can move into a shared emissive
 * boundary. Inset husk blood, other composite effects and prepared boundaries keep their own roots.
 */
/proc/is_plain_bodypart_mask(mutable_appearance/source)
	return source.icon && PLANE_TO_TRUE(source.plane) == EMISSIVE_PLANE && source.layer < 0 \
		&& source.appearance_flags == EMISSIVE_APPEARANCE_FLAGS && source.blend_mode == BLEND_DEFAULT \
		&& !length(source.overlays) && !length(source.underlays) && !source.maptext && !source.render_source && !source.render_target

/**
 * Whether a bodypart appearance draws the same nested in an unshifted holder as it does on the mob:
 * floating, default blending, and not reaching past its parent with KEEP_APART or RESET_* flags.
 * Iconless holders such as inner ears and MOD textures qualify; their contents are unchanged.
 */
/proc/is_plain_bodypart_sprite(mutable_appearance/source)
	return source.plane == FLOAT_PLANE && source.layer < 0 && source.blend_mode == BLEND_DEFAULT \
		&& !(source.appearance_flags & (KEEP_APART|RESET_COLOR|RESET_ALPHA|RESET_TRANSFORM)) \
		&& !source.maptext && !source.render_source && !source.render_target

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
