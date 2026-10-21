/**
 * The bulge look of a covered penis (bulge.dm): the garment that covers it, how that garment bulges (its family and its
 * vars, garment_families.dm and families.dm), and what the look draws. A look is resolved only when something it reads
 * has changed; every decision is a scalar check on the garment's vars, its family's data and the wearer.
 */

/// A suit hides the bulge: it covers the groin and is not reviewed to let it show.
#define BULGE_SUIT_HIDES 0
/// A suit leaves the groin clear: the bulge shows on what is worn under it.
#define BULGE_SUIT_PASSES 1
/// A suit is itself the cover: its family's bulge is drawn over it (the outer denim overalls).
#define BULGE_SUIT_COVERS 2
/// The colour treatment a worn garment is drawn through, as color_atom_overlay() applies it: its colour filter, else its
/// colour matrix (a list colour), else null. No print follows it; the adaptive cloth takes it (bulge_cloth_images()).
#define BULGE_COLOUR_TREATMENT(garment) ((garment).cached_color_filter || (islist((garment).color) ? (garment).color : null))
/// Whether a garment drawn at mob layer `garment_layer` is in front of a penis drawn at `penis_layer` (null: the
/// normal layering, under any garment). The smaller layer draws in front.
#define BULGE_IN_FRONT(garment_layer, penis_layer) (isnull(penis_layer) || (garment_layer) < (penis_layer))

/**
 * Resolves the penis's bulge look for a body update; TRUE when it draws one. A look resolved from the same inputs as
 * the last is kept as it is: a body update that changed nothing compares a few vars, and one that drew a slot again
 * without changing the cover or how it is drawn (drawn at all, included) also checks the cover
 * (bulge_cover_unchanged()) and the underwear under it (bulge_restraint()).
 *
 * Underwear always takes precedence over what is worn over it: the look is still drawn on the outermost cover, but
 * underwear under that cover holds the penis in, unless it lets it out itself (bulge_held_size()).
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_resolve(mob/living/carbon/human/wearer)
	var/obj/item/organ/genital/penis/penis = wearer.organs_slot[ORGAN_SLOT_PENIS]
	// How the penis is layered under what covers it, while it shows a bulge at all (bulge_layering()). It matters only
	// through the garment that covers it, so it is not kept: whatever changes it (the genital menus' writers) ends in a
	// body update that draws the underclothes again, and that re-checks the cover below.
	var/mode = (penis?.bodypart_overlay == src && penis.aroused >= AROUSAL_PARTIAL) ? bulge_layering(wearer, penis) : NONE
	if(!mode)
		if(bulge_key)
			bulge_clear()
		if(bulge_uniform_cut || bulge_body_cut)
			bulge_redraw_cuts(wearer, null, null) // A cover still cut for a look that is gone.
		return FALSE
	var/list/drawn = wearer.overlays_standing
	var/same_penis = bulge_wearer == wearer && bulge_aroused == penis.aroused && bulge_length == penis.genital_size \
		&& bulge_suffix == sprite_suffix && bulge_accessory == sprite_datum && bulge_bodyshape == wearer.bodyshape \
		&& (!bulge_anatomy || bulge_anatomy_unchanged(wearer))
	if(same_penis && bulge_suit_drawn == drawn[SUIT_LAYER] && bulge_uniform_drawn == drawn[UNIFORM_LAYER] && bulge_body_drawn == drawn[BODY_LAYER])
		return !!bulge_key

	// A slot was drawn again, or the penis changed. The cover, how it is drawn, and the underwear under it.
	var/chosen_layer = bulge_custom_layer(mode)
	var/datum/cover = wearer.bulge_cover(chosen_layer)
	var/datum/sprite_accessory/clothing/underwear/restraint = wearer.bulge_restraint(chosen_layer, cover)
	var/slot = bulge_cover_slot(cover)
	var/standing = slot ? drawn[slot] : null
	var/image/root = bulge_drawn_root(standing)
	var/image/leaf = bulge_drawn_leaf(root)
	// What the cover draws over its sprite (its blood), read once for the check and the record below.
	var/over = bulge_over_signature(bulge_over_overlays(root, leaf))
	var/same_cover = bulge_cover_unchanged(wearer, cover, root, leaf, over)
	if(same_penis && same_cover && bulge_restraint == restraint)
		// Drawn again as it was: the look stands. (A cover that stopped being drawn, as underwear on a species that
		// wears none, is not drawn as it was.)
		bulge_suit_drawn = drawn[SUIT_LAYER]
		bulge_uniform_drawn = drawn[UNIFORM_LAYER]
		bulge_body_drawn = drawn[BODY_LAYER]
		return !!bulge_key
	// A cover drawn as before keeps the palette it was sampled for.
	var/kept_cloth = same_cover ? bulge_cloth : null
	var/kept_light = bulge_light
	var/kept_highlight = bulge_highlight
	var/kept_shade = bulge_shade
	var/kept_deep_shade = bulge_deep_shade

	// The identity the look is drawn for.
	var/datum/bulge_family/family = bulge_cover_family(cover)
	var/hard = penis.aroused == AROUSAL_FULL
	var/size = bulge_size(penis.genital_size)
	var/digi = isvox(wearer) || (wearer.bodyshape & BODYSHAPE_DIGITIGRADE)
	var/shape = sprite_datum.type
	var/toned = penis.uses_skintones
	var/sprite_size = bulge_sprite_size(penis.genital_size, penis.max_sprite_size_affix)
	// Underwear under the cover holding the penis in: at a size it caps, with none of the penis drawn and nothing cut.
	var/held = restraint ? bulge_held_size(restraint, hard, size, digi, shape, toned) : null
	if(held)
		size = held
	// A cover drawn with a cut the look no longer wants is drawn again first: the body update that follows resolves
	// the look from the new drawing.
	var/datum/cut = (hard && family && isnull(held)) ? bulge_cut_for(family, size, digi, shape, toned, sprite_size) : null
	if(bulge_redraw_cuts(wearer, slot == UNIFORM_LAYER ? cut : null, slot == BODY_LAYER ? cut : null))
		return !!bulge_key

	bulge_clear()
	bulge_remember(wearer, penis, cover, restraint, root, leaf, over)
	if(!family || family == /datum/bulge_family/none || !standing || held == 0)
		return FALSE // Nothing covers it with a bulge, the cover is not drawn, or the underwear holds it in completely.
	bulge_layer = bulge_cover_layer(cover, standing)
	var/printed = bulge_cover_printed(cover)
	if(printed)
		bulge_sheet_patch = bulge_printed_patch(family, hard, size, digi, shape, toned) // The heart boxers past size 4.
	if(bulge_sheet_patch)
		// The patch stands in for the shape of the family whose shapes it draws, over the anatomy that shape leaves bare.
		if(!held)
			bulge_anatomy_mask = bulge_exposed(initial(family.large_shapes_of) || family, hard, size, digi, shape, toned)
	else
		if(hard && initial(family.loincloth))
			// A hard loincloth: its drape over the penis, shown behind the cover cut away under it. Held in by underwear
			// it is not lifted, and a loincloth has no hard shape of its own: no look.
			if(!held)
				bulge_template = bulge_drape(family, size, sprite_size, shape, toned)
				bulge_anatomy_behind = !!bulge_template
		else
			bulge_template = bulge_shape(family, hard, size, digi, shape, toned)
			if(bulge_template)
				if(printed && bulge_shape_size(family, hard, size, shape) <= initial(family.print_cap))
					bulge_print(standing, slot)
				if(!held)
					bulge_anatomy_mask = bulge_exposed(family, hard, size, digi, shape, toned)
					if(!bulge_anatomy_mask && initial(family.clearance))
						// A skirt the shaft shows through: behind it, and over its cloth inside the clearance where that
						// shows any of it (an empty clearance shows none, and nothing is derived for it).
						var/datum/bulge_sheet_state/clearance = bulge_clearance(family, hard, size)
						bulge_anatomy_behind = !!clearance
						if(clearance && bulge_mask_shows(clearance))
							bulge_anatomy_mask = clearance
		if(bulge_template && !bulge_patch)
			if(kept_cloth)
				bulge_template_masks(bulge_template)
				if(bulge_template.mask_union)
					bulge_cloth = kept_cloth
					bulge_light = kept_light
					bulge_highlight = kept_highlight
					bulge_shade = kept_shade
					bulge_deep_shade = kept_deep_shade
				else
					bulge_template = null
			else if(!bulge_tint(wearer, cover, initial(family.finish)))
				bulge_template = null // No colour to draw its cloth in: what it shows of the penis still draws.
	if(!bulge_template && !bulge_patch && !bulge_sheet_patch && !bulge_anatomy_behind)
		bulge_clear()
		bulge_remember(wearer, penis, cover, restraint, root, leaf, over) // Nothing to draw for these inputs.
		return FALSE
	if(bulge_cover_over && bulge_template)
		bulge_over_cloth(bulge_over_overlays(root, leaf), root) // Blood or dirt on the cover: over the cloth too.
	var/kept = (bulge_anatomy_behind || bulge_anatomy_mask) ? bulge_anatomy_record(penis, wearer) : null
	bulge_key = "bulge:[bulge_layer]:[bulge_patch ? ref(bulge_patch) : null]:[bulge_sheet_patch ? ref(bulge_sheet_patch) : null]:[bulge_template ? ref(bulge_template) : null]:[bulge_cloth][bulge_light][bulge_highlight][bulge_shade][bulge_deep_shade]:[bulge_anatomy_mask ? ref(bulge_anatomy_mask) : null]:[bulge_anatomy_behind]:[kept]:[bulge_alpha]:[bulge_cover_x],[bulge_cover_y]:[bulge_cover_over]:[bulge_cover_filtered ? json_encode(bulge_cover_filtered) : null]"
	return TRUE

/// Records what a look was resolved from (see bulge_resolve()): the penis, the slots as drawn, the cover and how it is
/// drawn (its drawn appearance's root and leaf, and what it draws over its sprite, as bulge_cover_unchanged() reads
/// them), and the underwear under it (bulge_restraint()). The cover's worn offset, as drawn, is the offset of everything
/// the look draws.
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_remember(mob/living/carbon/human/wearer, obj/item/organ/genital/penis/penis, datum/cover, datum/sprite_accessory/clothing/underwear/restraint, image/root, image/leaf, over)
	var/list/drawn = wearer.overlays_standing
	bulge_wearer = wearer
	bulge_restraint = restraint
	bulge_aroused = penis.aroused
	bulge_length = penis.genital_size
	bulge_suffix = sprite_suffix
	bulge_accessory = sprite_datum
	bulge_bodyshape = wearer.bodyshape
	bulge_suit_drawn = drawn[SUIT_LAYER]
	bulge_uniform_drawn = drawn[UNIFORM_LAYER]
	bulge_body_drawn = drawn[BODY_LAYER]
	bulge_cover_type = cover?.type
	if(istype(cover, /datum/sprite_accessory/clothing))
		// Underclothes are drawn from the accessory, the wearer's colour for it and physique (make_appearance()), or
		// not at all (a species that wears none): alpha 0.
		bulge_cover_icon = null
		bulge_cover_state = wearer.physique
		bulge_cover_tint = istype(cover, /datum/sprite_accessory/clothing/undershirt) ? wearer.undershirt_color : wearer.underwear_color
		bulge_cover_alpha = root ? 255 : 0
		bulge_cover_x = 0
		bulge_cover_y = 0
		return
	var/obj/item/clothing/garment = cover
	bulge_cover_icon = leaf?.icon
	bulge_cover_state = leaf?.icon_state
	bulge_cover_tint = leaf?.color
	bulge_cover_alpha = root ? root.alpha * leaf?.alpha : null
	bulge_alpha = leaf ? (root == leaf ? leaf.alpha : round(root.alpha * leaf.alpha / 255)) : 255
	bulge_cover_filtered = istype(garment) ? BULGE_COLOUR_TREATMENT(garment) : null
	bulge_cover_over = over
	bulge_cover_x = root ? root.pixel_x + root.pixel_w : 0
	bulge_cover_y = root ? root.pixel_y + root.pixel_z : 0

/**
 * Whether the cover is the one the look was resolved for, drawn as it was then: the same garment type, and for a worn
 * garment the same drawn sprite, tint, alpha, colour treatment (a matrix or a filter, compared by value), worn offset
 * and what it draws over its sprite (its colour, cut, masks and fit are all in its sprite); for underclothes the same
 * colour and physique, and drawn or not as they were. A look whose cover is unchanged needs nothing else resolved
 * again.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_cover_unchanged(mob/living/carbon/human/wearer, datum/cover, image/root, image/leaf, over)
	if(bulge_cover_type != cover?.type)
		return FALSE
	if(istype(cover, /datum/sprite_accessory/clothing))
		return bulge_cover_state == wearer.physique && bulge_cover_tint == (istype(cover, /datum/sprite_accessory/clothing/undershirt) ? wearer.undershirt_color : wearer.underwear_color) \
			&& bulge_cover_alpha == (root ? 255 : 0)
	var/obj/item/clothing/garment = cover
	return bulge_cover_icon == leaf?.icon && bulge_cover_state == leaf?.icon_state && bulge_cover_tint == leaf?.color \
		&& bulge_cover_alpha == (root ? root.alpha * leaf?.alpha : null) && bulge_cover_x == (root ? root.pixel_x + root.pixel_w : 0) \
		&& bulge_cover_y == (root ? root.pixel_y + root.pixel_z : 0) && (bulge_cover_filtered ~= (istype(garment) ? BULGE_COLOUR_TREATMENT(garment) : null)) \
		&& bulge_cover_over == over

/**
 * How the penis is layered under what covers it, while it shows a bulge through it: GENITAL_LAYER_NORMAL (hidden by
 * clothes, or Custom and Normal), or Custom below or above the underwear (GENITAL_LAYER_BELOW_UNDIES,
 * GENITAL_LAYER_ABOVE_UNDIES); NONE when it shows none: closed off by a device, in its sheath, never shown, drawn over
 * all clothing, or on a taur or Cerulean body (no legs for the templates). Arousal is checked by the caller.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_layering(mob/living/carbon/human/wearer, obj/item/organ/genital/penis/penis)
	if(penis.blocked_by || (sheath_datum && penis.aroused != AROUSAL_FULL) || (wearer.bodyshape & (BODYSHAPE_TAUR|BODYSHAPE_CERULEAN)))
		return NONE
	switch(penis.visibility_preference)
		if(GENITAL_HIDDEN_BY_CLOTHES)
			return GENITAL_LAYER_NORMAL
		if(GENITAL_CUSTOM)
			return layer_mode == GENITAL_LAYER_ABOVE_ALL ? NONE : layer_mode
	return NONE // Never shown.

/**
 * Where a penis layered `mode` (bulge_layering()) draws, as a layer of the mob's overlays (the greater, the
 * further back): where Nova's genital get_overlay() puts one set to Custom below or above the underwear. Null for the
 * normal layering, under whatever covers it. A penis drawn at a layer is covered only by what is drawn in front of it
 * (bulge_cover()): Custom above the underwear, it is drawn over the underwear and shows no bulge through it.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_custom_layer(mode)
	switch(mode)
		if(GENITAL_LAYER_BELOW_UNDIES)
			return UNDER_UNIFORM_SOCKS_LAYER + genital_stack_rank * GENITAL_STACK_STEP
		if(GENITAL_LAYER_ABOVE_UNDIES)
			return UNDER_UNIFORM_LAYER - 0.1 + genital_stack_rank * GENITAL_STACK_STEP
	return null

/**
 * Draws a cover cut away for a look again when its cut is not the one the look wants (uniform_cut and body_cut, for
 * the two slots a cover can be cut in). TRUE when it drew one again: the body update that drawing ends with has
 * resolved the look already. A slot not drawn holds no cut.
 *
 * No try here: a runtime in a render below (an accessory's worn overlay, a limb's) ends only the proc it happens in, and
 * the render around it carries on, so the guard is always reset below. A try would abandon every frame in between and
 * leave the cover undrawn. bulge_clear() resets the guard too, which every full resolve calls (one nested in these
 * draws included, so a nested resolve can draw a cover once more) and so does removing the penis.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_redraw_cuts(mob/living/carbon/human/wearer, datum/uniform_cut, datum/body_cut)
	var/list/drawn = wearer.overlays_standing
	if(!drawn[UNIFORM_LAYER])
		bulge_uniform_cut = uniform_cut
	if(!drawn[BODY_LAYER])
		bulge_body_cut = body_cut
	var/uniform_stale = bulge_uniform_cut != uniform_cut
	var/body_stale = bulge_body_cut != body_cut
	if((!uniform_stale && !body_stale) || bulge_redrawing || (wearer.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS))
		return FALSE
	bulge_redrawing = TRUE
	if(uniform_stale)
		wearer.update_worn_undersuit()
	if(body_stale)
		wearer.update_body()
	bulge_redrawing = FALSE
	// The draws above recorded their cuts; a cover that could not be drawn cut does not ask to be drawn again.
	bulge_uniform_cut = uniform_cut
	bulge_body_cut = body_cut
	return TRUE

/**
 * A printed look's patch: derived from the cover's drawn sprite (the sprite before its cut, for a revealing skirt), as
 * tinted by the garment's colour, drawn at the garment's alpha. A garment tinted by a colour matrix or filter, or whose
 * sprite gives no patch, is drawn adaptive instead.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_print(standing, slot)
	var/image/root = bulge_drawn_root(standing)
	var/image/leaf = bulge_drawn_leaf(root)
	if(!leaf || bulge_cover_filtered)
		return
	var/sprite = leaf.icon
	var/state = leaf.icon_state
	if(slot == UNIFORM_LAYER && bulge_cut_icon && sprite == bulge_cut_icon)
		sprite = bulge_uncut_icon
		state = bulge_uncut_state
	var/colour = (leaf.color && leaf.color != COLOR_WHITE && leaf.color != "#ffffff") ? leaf.color : null
	bulge_patch = bulge_print_patch(sprite, state, bulge_template, colour)

/**
 * An adaptive look's palette, from the cover's cloth colour in the family's finish; FALSE when the cover has no colour
 * to sample: no cloth is drawn then.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_tint(mob/living/carbon/human/wearer, datum/cover, finish)
	var/list/palette = get_bulge_palette(wearer.bulge_cover_colour(cover), finish)
	if(length(palette) != 5)
		return FALSE
	bulge_template_masks(bulge_template)
	if(!bulge_template.mask_union)
		return FALSE
	bulge_cloth = palette[1]
	bulge_light = palette[2]
	bulge_highlight = palette[3]
	bulge_shade = palette[4]
	bulge_deep_shade = palette[5]
	return TRUE

/**
 * What the cover draws over its sprite (`overlays`, from bulge_over_overlays(): blood, dirt), over the look's cloth
 * too: each such overlay's sprite kept to the cloth's pixels (bulge_clipped_icon()), in its own colour and the alpha of
 * the cover's `root`, just above the cloth, as the garment draws its blood over itself. An overlay drawn off the tile
 * is left out, and so is a glow on it (the cloth's emissive blocker covers that glow beneath the cloth, as before).
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_over_cloth(list/overlays, image/root)
	bulge_template_masks(bulge_template)
	if(!bulge_template.mask_union)
		return
	for(var/index in 2 to length(overlays))
		var/image/over = overlays[index]
		if(over.plane != FLOAT_PLANE || over.pixel_x || over.pixel_y || over.pixel_w || over.pixel_z)
			continue
		var/clipped = bulge_clipped_icon(over.icon, over.icon_state, bulge_template)
		if(!clipped)
			continue
		var/mutable_appearance/drawn = mutable_appearance(clipped, "", -(bulge_layer - BULGE_ABOVE_COVER))
		drawn.color = over.color
		drawn.alpha = round(root.alpha * over.alpha / 255)
		drawn.name = BULGE_CLOTH_NAME
		LAZYADD(bulge_over, drawn)

/// The testicles a look shows behind its cover with the penis: present, hidden by that cover, and not closed off.
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_shown_testicles(mob/living/carbon/human/wearer)
	var/obj/item/organ/genital/testicles/testicles = wearer?.get_organ_slot(ORGAN_SLOT_TESTICLES)
	var/datum/bodypart_overlay/mutant/genital/testicles_overlay = testicles?.bodypart_overlay
	if(isnull(testicles_overlay?.sprite_datum) || testicles.blocked_by || testicles_overlay.hidden_by_device || testicles_overlay.device_state || testicles.bodypart_owner?.is_husked)
		return null
	switch(testicles.visibility_preference)
		if(GENITAL_HIDDEN_BY_CLOTHES)
			return testicles
		if(GENITAL_CUSTOM)
			return testicles_overlay.layer_mode == GENITAL_LAYER_NORMAL ? testicles : null // Otherwise drawn by itself.
	return null

/**
 * Records what the anatomy a look draws is drawn from beyond its sprite (bulge_anatomy): the penis's colours, alpha,
 * emissive colours and dye, and the shown testicles' overlay with their sprite suffix, the same of theirs and their
 * sprite accessory; and returns the hash of the render keys the penis and those testicles draw with in the open, for
 * the look's key. Those keys (the mutant overlays' icon_render_key()) read nothing else that can change while a look
 * draws: the penis's sprites, the layering and the body shape are in the look's memo (bulge_resolve()), and taur, MOD
 * and device sprites draw no look. When the mutant key comes to read more, record it here and compare it in
 * bulge_anatomy_unchanged().
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_anatomy_record(obj/item/organ/genital/penis/penis, mob/living/carbon/human/wearer)
	var/obj/item/bodypart/chest = penis.bodypart_owner
	var/obj/item/organ/genital/testicles/testicles = bulge_anatomy_behind ? bulge_shown_testicles(wearer) : null
	var/datum/bodypart_overlay/mutant/genital/testicles_overlay = testicles?.bodypart_overlay
	// Colours and emissive flags are kept as copies, so that a list changed in place still compares as changed.
	var/list/colours = draw_color
	bulge_anatomy = list(islist(colours) ? colours.Copy() : colours, alpha, emissive_eligibility_by_color_index?.Copy(), dye_color, testicles_overlay)
	var/list/keys = icon_render_key(chest) // The penis's own key: the look's is not set yet.
	if(testicles_overlay)
		colours = testicles_overlay.draw_color
		bulge_anatomy += list(testicles_overlay.sprite_suffix, islist(colours) ? colours.Copy() : colours, testicles_overlay.alpha,
			testicles_overlay.emissive_eligibility_by_color_index?.Copy(), testicles_overlay.dye_color, testicles_overlay.sprite_datum)
		keys += testicles_overlay.icon_render_key(chest)
	return md5(jointext(keys, "-"))

/**
 * Whether the anatomy a look draws is drawn from what it was recorded for (bulge_anatomy_record()), compared by value
 * (a list changed in place counts): once per pass, for a look that draws anatomy, with the shown testicles looked up
 * once here.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_anatomy_unchanged(mob/living/carbon/human/wearer)
	var/list/known = bulge_anatomy
	if(!(known[1] ~= draw_color) || known[2] != alpha || !(known[3] ~= emissive_eligibility_by_color_index) || known[4] != dye_color)
		return FALSE
	var/obj/item/organ/genital/testicles/testicles = bulge_anatomy_behind ? bulge_shown_testicles(wearer) : null
	var/datum/bodypart_overlay/mutant/genital/testicles_overlay = testicles?.bodypart_overlay
	if(testicles_overlay != known[5])
		return FALSE
	return !testicles_overlay || (known[6] == testicles_overlay.sprite_suffix && (known[7] ~= testicles_overlay.draw_color) \
		&& known[8] == testicles_overlay.alpha && (known[9] ~= testicles_overlay.emissive_eligibility_by_color_index) \
		&& known[10] == testicles_overlay.dye_color && known[11] == testicles_overlay.sprite_datum)

/**
 * What of the penis its bulge look still shows, for interactions (INTERACTION_REQUIRE_SELF_POKES_OUT and
 * INTERACTION_REQUIRE_TARGET_POKES_OUT) and anything else: BULGE_POKES_PAST_CLOTH while the look draws some of it over
 * the cloth (the tip or head past the garment, what a printed patch leaves bare, the shaft over a revealing skirt), and
 * BULGE_POKES_UNDER_COVER while it draws it behind a cover cut or lifted for it (a revealing skirt or a loincloth,
 * hard); NONE with no look, or one that covers all of it. Any pixel the look draws counts, in any facing: the two-pixel
 * tip past a waistband facing east and west too.
 *
 * It reads the look as drawn (bulge_resolve()), so it follows the layering, Custom "Above underwear" and suits as the
 * renderer does, and is current as has_bulge() is: a few var reads, no icons. Two looks it does not answer exactly, as
 * the look does not record what of them shows: a penis drawn behind a cover not cut for it (a skirt half hard, a long
 * curtain skirt) shows wherever it reaches past the cover, below the hem or past the curtain, and is not counted; and
 * the smallest Tentacled (Alt) penis under a hard loincloth counts as under the cover, though its drape hides all of it.
 */
/mob/living/carbon/human/proc/bulge_pokes_out()
	var/obj/item/organ/genital/penis/penis = get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis?.bodypart_overlay
	if(!istype(overlay) || isnull(overlay.bulge_key) || overlay.bulge_wearer != src)
		return NONE
	. = overlay.bulge_anatomy_mask ? BULGE_POKES_PAST_CLOTH : NONE
	if(overlay.bulge_anatomy_behind && (overlay.bulge_uniform_cut || overlay.bulge_body_cut))
		. |= BULGE_POKES_UNDER_COVER

/**
 * The cover garment a bulge shows through, outermost first: a suit unless it is reviewed to leave the groin clear,
 * else a uniform over the groin, else a groin-length undershirt, else the underwear. Null for none, or for a suit that
 * hides the bulge. A garment covers the penis only when it is drawn in front of it: for a penis the player has layered
 * at `chosen_layer` (bulge_custom_layer()), a garment drawn behind that layer is passed over, as Nova draws the penis
 * over it (Custom "Above underwear" wins over the underwear).
 */
/mob/living/carbon/human/proc/bulge_cover(chosen_layer)
	if(wear_suit && BULGE_IN_FRONT(wear_suit.alternate_worn_layer || SUIT_LAYER, chosen_layer))
		switch(bulge_suit_verdict(wear_suit))
			if(BULGE_SUIT_HIDES)
				return null
			if(BULGE_SUIT_COVERS)
				return wear_suit
	if((w_uniform?.body_parts_covered & GROIN) && BULGE_IN_FRONT(w_uniform.alternate_worn_layer || UNIFORM_LAYER, chosen_layer))
		return w_uniform
	if(!(underwear_visibility & UNDERWEAR_HIDE_SHIRT))
		var/datum/sprite_accessory/clothing/undershirt/shirt = SSaccessories.undershirt_list[undershirt]
		if(shirt?.hides_groin && BULGE_IN_FRONT(shirt.layer, chosen_layer))
			return shirt
	if(!(underwear_visibility & UNDERWEAR_HIDE_UNDIES))
		var/datum/sprite_accessory/clothing/underwear/bottom = SSaccessories.underwear_list[underwear]
		if(bottom && BULGE_IN_FRONT(bottom.layer, chosen_layer))
			return bottom
	return null

/**
 * The underwear worn under a look's cover (bulge_cover()), which holds the penis in unless it lets it out itself
 * (bulge_held_size()): underwear always takes precedence over what is worn over it. It counts while it is worn and
 * drawn, as get_underwear_overlays() draws it, and in front of the penis as the player layered it at `chosen_layer`
 * (bulge_custom_layer()).
 *
 * Returns the underwear, or null for none: no underwear, underwear the body does not draw or the penis is layered above,
 * or underwear that is itself the cover.
 */
/mob/living/carbon/human/proc/bulge_restraint(chosen_layer, datum/cover)
	if((underwear_visibility & UNDERWEAR_HIDE_UNDIES) || HAS_TRAIT(src, TRAIT_HUSK) || HAS_TRAIT(src, TRAIT_INVISIBLE_MAN) || HAS_TRAIT(src, TRAIT_NO_UNDERWEAR))
		return null
	var/datum/sprite_accessory/clothing/underwear/bottom = SSaccessories.underwear_list[underwear]
	if(!bottom || bottom == cover || istype(bottom, /datum/sprite_accessory/clothing/underwear/nude) || !BULGE_IN_FRONT(bottom.layer, chosen_layer))
		return null
	return bottom

/**
 * What a worn suit does to a bulge (BULGE_SUIT_*). A suit leaves the groin clear, or is itself the cover, only in the
 * cells its bulge_suit_rule names: its own unmodified appearance in its default or toggled worn state, on plain or
 * digitigrade legs, on a body its sprites fit (no Vox, custom, taur or Cerulean body), untinted and without offsets.
 */
/mob/living/carbon/human/proc/bulge_suit_verdict(obj/item/worn_suit)
	if(!istype(worn_suit, /obj/item/clothing))
		return BULGE_SUIT_HIDES
	var/obj/item/clothing/suit = worn_suit
	var/rule = suit.bulge_suit_rule
	if(!rule || isvox(src) || (bodyshape & (BODYSHAPE_CUSTOM|BODYSHAPE_TAUR|BODYSHAPE_CERULEAN)))
		return BULGE_SUIT_HIDES
	if(suit.worn_x_offset || suit.worn_y_offset || suit.worn_x_dimension != 32 || suit.worn_y_dimension != 32 || suit.alpha != 255)
		return BULGE_SUIT_HIDES
	if((suit.color && suit.color != COLOR_WHITE) || suit.cached_color_filter)
		return BULGE_SUIT_HIDES
	var/digi = bodyshape & BODYSHAPE_DIGITIGRADE
	var/state = suit.worn_icon_state || suit.icon_state
	var/default_state = initial(suit.worn_icon_state) || initial(suit.post_init_icon_state) || initial(suit.icon_state)
	var/toggle_base = initial(suit.base_icon_state) || initial(suit.post_init_icon_state) || initial(suit.icon_state)
	var/cell
	if(state == default_state)
		cell = digi ? BULGE_SUIT_DEFAULT_DIGI : BULGE_SUIT_DEFAULT_PLAIN
	else if(toggle_base && state == "[toggle_base]_t")
		cell = digi ? BULGE_SUIT_TOGGLED_DIGI : BULGE_SUIT_TOGGLED_PLAIN
	if(!(rule & cell) || !bulge_suit_unmodified(suit, digi))
		return BULGE_SUIT_HIDES
	return suit.bulge_family == /datum/bulge_family/none ? BULGE_SUIT_PASSES : BULGE_SUIT_COVERS

/// Whether a suit draws its own default sprite: its type's file, or its type's GAGS output in its type's colours.
/mob/living/carbon/human/proc/bulge_suit_unmodified(obj/item/clothing/suit, digi)
	var/digi_file = digi && (suit.supports_variations_flags & CLOTHING_DIGITIGRADE_VARIATION)
	var/file = digi_file ? (suit.worn_icon_digi || DIGITIGRADE_SUIT_FILE) : (suit.worn_icon || DEFAULT_SUIT_FILE)
	var/config = file == suit.worn_icon_digi ? suit.greyscale_config_worn_digi : suit.greyscale_config_worn
	if(!config)
		return file == (digi_file ? (initial(suit.worn_icon_digi) || DIGITIGRADE_SUIT_FILE) : (initial(suit.worn_icon) || DEFAULT_SUIT_FILE))
	if(config != (file == suit.worn_icon_digi ? initial(suit.greyscale_config_worn_digi) : initial(suit.greyscale_config_worn)))
		return FALSE
	var/colours = bulge_palette_text(suit.greyscale_colors)
	var/default_colours = initial(suit.greyscale_colors)
	if(isnull(colours) || colours != bulge_palette_text(default_colours))
		return FALSE
	return SSgreyscale.bulge_cached_output_matches(config, colours, file)

/// A GAGS palette as one string, as its producer joins a list; null for anything that is no palette.
/proc/bulge_palette_text(colours)
	if(islist(colours))
		var/list/colour_list = colours
		return colour_list.Join()
	return istext(colours) ? colours : null

/**
 * The cloth colour an adaptive bulge is tinted from: sampled from the cover garment's own sprite (or, for a GAGS
 * garment, its cloth layer), tinted as the garment is drawn. Null when it has none to sample.
 */
/mob/living/carbon/human/proc/bulge_cover_colour(datum/cover)
	if(istype(cover, /obj/item/clothing/under))
		var/obj/item/clothing/under/uniform = cover
		var/state = uniform.adjusted == ALT_STYLE ? "[uniform.icon_state]_d" : uniform.icon_state
		var/file = bulge_uniform_file(uniform)
		var/config = file == uniform.worn_icon_digi ? uniform.greyscale_config_worn_digi : uniform.greyscale_config_worn
		var/tint = istext(uniform.color) ? uniform.color : null
		if(config)
			return bulge_gags_colour(config, bulge_palette_text(uniform.greyscale_colors), file, state, uniform.bulge_cloth_layer, tint)
		return sample_fabric_colour(file, state, tint)
	if(istype(cover, /obj/item/clothing))
		var/obj/item/clothing/suit = cover
		var/file = (bodyshape & BODYSHAPE_DIGITIGRADE) && (suit.supports_variations_flags & CLOTHING_DIGITIGRADE_VARIATION) ? (suit.worn_icon_digi || DIGITIGRADE_SUIT_FILE) : (suit.worn_icon || DEFAULT_SUIT_FILE)
		var/config = file == suit.worn_icon_digi ? suit.greyscale_config_worn_digi : suit.greyscale_config_worn
		var/state = suit.worn_icon_state || suit.icon_state
		var/tint = istext(suit.color) ? suit.color : null
		if(config)
			return bulge_gags_colour(config, bulge_palette_text(suit.greyscale_colors), file, state, 1, tint)
		return sample_fabric_colour(file, state, tint)
	if(istype(cover, /datum/sprite_accessory/clothing))
		var/datum/sprite_accessory/clothing/accessory = cover
		var/shape = bodyshape
		var/tint = underwear_color
		if(istype(accessory, /datum/sprite_accessory/clothing/undershirt))
			tint = undershirt_color
		else if(isvoxprimalis(src))
			shape |= BODYSHAPE_DIGITIGRADE // As the underwear's make_appearance() draws it.
		if(accessory.use_static)
			tint = null
		var/state = accessory.get_icon_state(physique, shape)
		if(accessory.greyscale_config)
			return bulge_gags_colour(accessory.greyscale_config, bulge_palette_text(accessory.greyscale_colors), accessory.icon, state, 1, tint)
		return sample_fabric_colour(accessory.icon, state, tint)
	return null

/**
 * The sprite file a uniform is drawn from on this body before any mask, as update_worn_undersuit() picks it: its
 * digitigrade file on digitigrade legs where it has the state, else its own worn file. A uniform fitted to a species
 * (Vox, Teshari and other custom bodies) is sampled from its own worn file.
 */
/mob/living/carbon/human/proc/bulge_uniform_file(obj/item/clothing/under/uniform)
	var/icon_file
	var/species_file
	if(isvox(src) && (bodyshape & BODYSHAPE_CUSTOM))
		species_file = dna.species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform, src)
		icon_file = species_file
	if(!icon_file && (bodyshape & BODYSHAPE_DIGITIGRADE) && (uniform.supports_variations_flags & CLOTHING_DIGITIGRADE_VARIATION))
		icon_file = uniform.worn_icon_digi || DIGITIGRADE_UNIFORM_FILE
	else if(!icon_file && (bodyshape & BODYSHAPE_CUSTOM))
		species_file = dna.species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform, src)
		icon_file = species_file
	if(!icon_exists(icon_file, uniform.worn_icon_state || uniform.icon_state) || (species_file && icon_file == species_file))
		return uniform.worn_icon || DEFAULT_UNIFORM_FILE
	return icon_file

/**
 * The cloth colour of a GAGS garment: its cloth layer's greyscale sprite in that layer's palette colour, tinted as
 * the garment is drawn. Only while the garment draws its config's own output (SSgreyscale), so a stale config after a
 * run-time override samples nothing; null then.
 */
/mob/living/carbon/human/proc/bulge_gags_colour(config_type, palette, file, state, layer, tint)
	var/datum/greyscale_config/config = SSgreyscale.configurations["[config_type]"]
	if(!config || isnull(palette) || !SSgreyscale.bulge_cached_output_matches(config_type, palette, file))
		return null
	var/list/layers = config.icon_states[state]
	if(layer < 1 || layer > length(layers))
		return null
	var/datum/greyscale_layer/icon_state/cloth = layers[layer]
	if(!istype(cloth) || length(cloth.color_ids) > 1)
		return null
	var/cloth_tint
	if(length(cloth.color_ids))
		var/colour_id = cloth.color_ids[1]
		if(isnum(colour_id))
			cloth_tint = copytext(palette, (colour_id - 1) * 7 + 1, colour_id * 7 + 1)
			if(length(cloth_tint) != 7)
				return null
		else
			cloth_tint = colour_id
	return sample_fabric_colour(cloth.icon_file, cloth.icon_state, cloth_tint, tint, "[config.icon_file_hash]|[config.json_config_hash]")

/// The family a cover garment bulges with, or null.
/proc/bulge_cover_family(datum/cover)
	if(istype(cover, /obj/item/clothing))
		var/obj/item/clothing/garment = cover
		return garment.bulge_family
	if(istype(cover, /datum/sprite_accessory/clothing))
		var/datum/sprite_accessory/clothing/accessory = cover
		return accessory.bulge_family
	return null

/// Whether a cover garment's own print carries onto its bulge.
/proc/bulge_cover_printed(datum/cover)
	if(istype(cover, /obj/item/clothing/under))
		var/obj/item/clothing/under/uniform = cover
		return uniform.bulge_printed
	if(istype(cover, /datum/sprite_accessory/clothing))
		var/datum/sprite_accessory/clothing/accessory = cover
		return accessory.bulge_printed
	return FALSE

/// The overlays_standing slot a cover garment is drawn in, or null.
/proc/bulge_cover_slot(datum/cover)
	if(istype(cover, /obj/item/clothing/under))
		return UNIFORM_LAYER
	if(istype(cover, /obj/item/clothing))
		return SUIT_LAYER
	if(istype(cover, /datum/sprite_accessory/clothing))
		return BODY_LAYER
	return null

/// The layer a cover garment is drawn at: an underclothes accessory's own, else its drawn appearance's.
/proc/bulge_cover_layer(datum/cover, standing)
	if(istype(cover, /datum/sprite_accessory/clothing))
		var/datum/sprite_accessory/clothing/accessory = cover
		return accessory.layer
	var/image/root = bulge_drawn_root(standing)
	if(root)
		return -root.layer
	return istype(cover, /obj/item/clothing/under) ? UNIFORM_LAYER : SUIT_LAYER

/**
 * The overlays of a worn cover's KEEP_TOGETHER root as the garment built them: the drawn sprite first, then what it
 * draws over that sprite (build_worn_icon()'s separate overlays: blood, dirt), uncut where the cover is drawn cut
 * (bulge_swap_cut() keeps them). Null when the root is the sprite itself, as for every clean garment: one comparison.
 */
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_over_overlays(image/root, image/leaf)
	if(!root || root == leaf)
		return null
	if(bulge_uncut_over && leaf.icon == bulge_cut_icon)
		return bulge_uncut_over
	return root.overlays

/// What a worn cover draws over its own sprite (`overlays`, from bulge_over_overlays()), as one string: each overlay
/// after the first on the float plane. Null for none.
/proc/bulge_over_signature(list/overlays)
	for(var/index in 2 to length(overlays))
		var/image/over = overlays[index]
		if(over.plane == FLOAT_PLANE)
			. = "[.][over.icon]|[over.icon_state]|[over.color]|[over.alpha];"

/// The first visible appearance of a drawn slot (a slot holds one, or a list with emissive roots beside them).
/proc/bulge_drawn_root(standing)
	RETURN_TYPE(/image)
	if(!islist(standing))
		return standing
	for(var/image/entry as anything in standing)
		if(entry.plane == FLOAT_PLANE)
			return entry
	return null

/// The drawn sprite of a worn appearance: the appearance itself, or the first child of the KEEP_TOGETHER root
/// build_worn_icon() nests separate overlays under. Null when it draws none.
/proc/bulge_drawn_leaf(image/root)
	RETURN_TYPE(/image)
	var/image/leaf = root
	if(leaf && !leaf.icon && (leaf.appearance_flags & KEEP_TOGETHER) && length(leaf.overlays))
		leaf = leaf.overlays[1]
	return leaf?.icon ? leaf : null

/**
 * The cut a cover of `family` is drawn with under a hard penis of this identity: a revealing skirt's flap (a
 * /datum/bulge_print_template) or a loincloth's derived cut (a /datum/bulge_sheet_state); null when it is drawn whole.
 */
/proc/bulge_cut_for(datum/bulge_family/family, size, digi, shape, toned, sprite_size)
	if(initial(family.loincloth))
		return bulge_loincloth_cut(family, size, sprite_size, shape, toned)
	if(initial(family.flaps))
		return bulge_flap(family, size, digi)
	return null

/**
 * What the underwear under a look's cover (bulge_restraint()) leaves of the look. Underwear always takes precedence: it
 * holds the penis in, unless its own look would show some of it at this size and arousal, the anatomy
 * its exposed mask leaves bare (briefs from size 5, long johns' tip hard from size 5) or a loincloth's drape when hard.
 * bulge_resolve() and bulge_wanted_cut() both decide by it, so a cover is drawn cut only for a look that shows the penis
 * through it.
 *
 * Arguments:
 * - restraint: The underwear.
 * - hard, size, digi, shape, toned: The look's identity, as bulge_shape() takes it.
 *
 * Returns:
 * - null: The underwear lets the penis out, and the cover's look is what it would be without it.
 * - 0: It holds the penis in completely (/datum/bulge_family/none: the chastity sprites, groin plating): no look.
 * - 1 to 8: It holds the penis in at this size, its family's cap for the arousal where the bulge is bigger: the cover
 *   draws its own shape at it, and none of the penis (no exposed anatomy, clearance, drape or cut).
 */
/proc/bulge_held_size(datum/sprite_accessory/clothing/underwear/restraint, hard, size, digi, shape, toned)
	var/datum/bulge_family/family = restraint.bulge_family
	var/held = bulge_family_size(family, hard, size)
	if(!held)
		return 0
	if(hard && initial(family.loincloth))
		return null
	var/datum/bulge_family/baring = family
	if(restraint.bulge_printed && bulge_printed_patch(family, hard, size, digi, shape, toned))
		baring = initial(family.large_shapes_of) || family // The heart boxers' patch shows what the boxers' shape leaves bare.
	return bulge_exposed(baring, hard, size, digi, shape, toned) ? null : held

#undef BULGE_SUIT_HIDES
#undef BULGE_SUIT_PASSES
#undef BULGE_SUIT_COVERS
#undef BULGE_COLOUR_TREATMENT
#undef BULGE_IN_FRONT
