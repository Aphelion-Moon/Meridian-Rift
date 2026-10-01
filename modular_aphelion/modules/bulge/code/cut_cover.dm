/**
 * Cut covers: a cover that reveals when hard (a revealing skirt, a loincloth) is drawn with its lifted part cut away,
 * so the penis the bulge draws behind it shows through (bulge.dm). The cut is swapped in for the drawn sprite of the
 * cover's freshly built worn appearance, after the female and digitigrade masks, the way the digitigrade leg mask
 * swaps a uniform's icon; tg's worn icon caches only ever see the garment's own file and state. What the sprite carries
 * over its own pixels (its emissive blocker, the damaged-clothes overlay, a glow) is cut the same way; a uniform's
 * accessories, worn over the garment, are not. This is the only place a cover's own render is touched, and only for a
 * wearer whose look cuts that cover.
 *
 * The uniform and underwear renders call bulge_cut_worn() for a wearer with a penis. The look (look.dm) checks the
 * cut each slot was drawn with against the one it wants and draws a cover again when they differ; the penis's
 * genital-updated signal does the same for a uniform as soon as an erection or a size changes, and underclothes are
 * drawn again by the body update an arousal change ends with (redraw.dm).
 */

/**
 * Returns a cover's freshly built worn appearance with its drawn sprite swapped for its cut, where the wearer's look
 * cuts this cover, and records the cut (or none) the slot is drawn with.
 *
 * Arguments:
 * * slot - the slot the cover is drawn in: UNIFORM_LAYER, or BODY_LAYER for the underwear.
 * * standing - the appearance build_worn_icon() or make_appearance() built, before height and offsets.
 */
/mob/living/carbon/human/proc/bulge_cut_worn(slot, mutable_appearance/standing)
	var/obj/item/organ/genital/penis/penis = organs_slot[ORGAN_SLOT_PENIS]
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis?.bodypart_overlay
	if(!istype(overlay))
		return standing
	var/datum/cut = overlay.bulge_wanted_cut(src, slot)
	if(slot == UNIFORM_LAYER)
		overlay.bulge_uniform_cut = cut
		overlay.bulge_cut_icon = null
		overlay.bulge_uncut_over = null
	else
		overlay.bulge_body_cut = cut
	if(!cut || !standing)
		return standing
	overlay.bulge_swap_cut(standing, cut, slot, slot == UNIFORM_LAYER ? w_uniform : null)
	return standing

/**
 * The cut the wearer's look wants for the cover drawn in `slot`: that cover's flap or derived cut while the penis
 * shows hard through it (bulge_cut_for()), else null. Decided as bulge_resolve() decides it, without the drawn
 * appearance.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_wanted_cut(mob/living/carbon/human/wearer, slot)
	var/obj/item/organ/genital/penis/penis = wearer.get_organ_slot(ORGAN_SLOT_PENIS)
	var/obj/item/bodypart/chest = penis?.bodypart_owner
	if(penis?.bodypart_overlay != src || penis.aroused != AROUSAL_FULL || !chest || chest.is_husked || hidden_by_device || device_state || isnull(sprite_datum))
		return null
	var/mode = bulge_layering(wearer, penis)
	if(!mode)
		return null
	var/datum/cover = wearer.bulge_cover(bulge_custom_layer(mode))
	if(!cover || bulge_cover_slot(cover) != slot)
		return null
	var/datum/bulge_family/family = bulge_cover_family(cover)
	if(!family)
		return null
	var/digi = isvox(wearer) || (wearer.bodyshape & BODYSHAPE_DIGITIGRADE)
	return bulge_cut_for(family, bulge_size(penis.genital_size), digi, sprite_datum.type, penis.uses_skintones, bulge_sprite_size(penis.genital_size, penis.max_sprite_size_affix))

/**
 * Swaps the drawn sprite of a worn appearance for its cut: the appearance itself, or the first child of the
 * KEEP_TOGETHER root build_worn_icon() nests separate overlays under. The sprite's own children are cut with it
 * (bulge_cut_children()), and so is what the garment draws over its sprite beside it in that root (its blood), which
 * would otherwise draw over what the cut reveals (bulge_cut_siblings()). A uniform's root as built, uncut, is kept for
 * the look's cloth, which carries the blood as the garment had it (bulge_over_overlays()).
 *
 * Arguments:
 * * standing - the appearance build_worn_icon() or make_appearance() built.
 * * cut - the cut: a flap (/datum/bulge_print_template) or a loincloth's derived cut (/datum/bulge_sheet_state).
 * * slot - UNIFORM_LAYER or BODY_LAYER.
 * * uniform - the uniform drawn, for a uniform: its accessories keep their pixels.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_swap_cut(mutable_appearance/standing, datum/cut, slot, obj/item/clothing/under/uniform)
	var/mutable_appearance/leaf = standing
	var/nested = !standing.icon && (standing.appearance_flags & KEEP_TOGETHER) && length(standing.overlays)
	if(nested)
		leaf = new /mutable_appearance(standing.overlays[1])
	var/sprite = leaf.icon
	var/state = leaf.icon_state
	if(!isfile(sprite))
		return
	var/cut_icon = bulge_cut_sprite(sprite, state, cut)
	if(!cut_icon)
		return
	leaf.icon = cut_icon
	leaf.icon_state = ""
	var/list/children = bulge_cut_children(leaf.overlays, sprite, state, cut, cut_icon, uniform)
	if(children)
		leaf.overlays = children
	children = bulge_cut_children(leaf.underlays, sprite, state, cut, cut_icon, uniform)
	if(children)
		leaf.underlays = children
	if(nested)
		var/list/copied_overlays = standing.overlays.Copy()
		var/list/siblings = bulge_cut_siblings(copied_overlays, cut) || copied_overlays.Copy()
		siblings[1] = leaf
		standing.overlays = siblings
		if(slot == UNIFORM_LAYER)
			bulge_uncut_over = copied_overlays
	if(slot == UNIFORM_LAYER)
		bulge_uncut_icon = sprite
		bulge_uncut_state = state
		bulge_cut_icon = cut_icon

/**
 * A cut sprite's children (its overlays or its underlays) as they are drawn over the cut, or null when none changes:
 * its emissive blocker, which draws the same sprite, takes the sprite's cut; any other child is cut the same way (the
 * damaged-clothes overlay, a glow), except a uniform's accessories, worn over the garment, and a child drawn off the
 * tile, which the cut would not fit. A child's own children are drawn as they are.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_cut_children(list/children, sprite, state, datum/cut, cut_icon, obj/item/clothing/under/uniform)
	var/list/cut_children
	for(var/index in 1 to length(children))
		var/image/child = children[index]
		var/child_cut
		if(child.icon == sprite && child.icon_state == state)
			child_cut = cut_icon
		else if(!child.pixel_x && !child.pixel_y && !child.pixel_w && !child.pixel_z && !bulge_is_accessory(uniform, child))
			child_cut = bulge_cut_sprite(child.icon, child.icon_state, cut)
		if(!child_cut)
			continue
		cut_children ||= children.Copy()
		var/mutable_appearance/cut_child = new(child)
		cut_child.icon = child_cut
		cut_child.icon_state = ""
		cut_children[index] = cut_child
	return cut_children

/**
 * The overlays of a nested worn appearance's root as they are drawn over its cut sprite, or null when none changes:
 * from the second on (the first is the drawn sprite), what the garment draws over its sprite (its blood), each on the
 * tile cut the same way, its own children cut as bulge_cut_children() cuts the sprite's (a stain's glow, drawn from the
 * stain's sprite, takes the stain's cut).
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_cut_siblings(list/overlays, datum/cut)
	var/list/siblings
	for(var/index in 2 to length(overlays))
		var/image/over = overlays[index]
		if(over.pixel_x || over.pixel_y || over.pixel_w || over.pixel_z)
			continue // Drawn off the tile: the cut would not fit it.
		var/child_cut = bulge_cut_sprite(over.icon, over.icon_state, cut)
		if(!child_cut)
			continue
		siblings ||= overlays.Copy()
		var/mutable_appearance/cut_child = new(over)
		cut_child.icon = child_cut
		cut_child.icon_state = ""
		var/list/glow = bulge_cut_children(cut_child.overlays, over.icon, over.icon_state, cut, child_cut, null)
		if(glow)
			cut_child.overlays = glow
		siblings[index] = cut_child
	return siblings

/// A sprite cut by a flap (/datum/bulge_print_template) or by a loincloth's derived cut (/datum/bulge_sheet_state),
/// or null.
/proc/bulge_cut_sprite(sprite, state, datum/cut)
	if(istype(cut, /datum/bulge_print_template))
		return bulge_cut_cover_flap(sprite, state, cut)
	return bulge_cut_cover_patch(sprite, state, cut)

/// Whether a child of a uniform's drawn sprite is one of its accessories (get_accessory_overlays()): drawn in the
/// accessory's worn state, whichever file the wearer's species draws it from.
/proc/bulge_is_accessory(obj/item/clothing/under/uniform, image/child)
	if(child.plane != FLOAT_PLANE)
		return FALSE
	for(var/obj/item/clothing/accessory/accessory as anything in uniform?.attached_accessories)
		if(child.icon_state == (accessory.icon_state_is_worn ? accessory.icon_state : accessory.worn_icon_state))
			return TRUE
	return FALSE
