/**
 * Bulges: a covered penis, at least half hard, draws the cloth it pushes out over the garment covering it.
 *
 * One renderer, on the penis's own bodypart overlay. A body update asks the overlay whether it draws
 * (can_draw_on_bodypart()); a covered penis then resolves its look (look.dm) and keeps it, memoised by the scalars it
 * was resolved from, so an update that changed none of them compares a few vars and reuses the look. The look's key
 * stands in for the penis's own render key, so the chest's limb icon cache holds a drawn bulge like any other limb
 * image, and its images are built only when that key changes (get_overlay()).
 *
 * What a look draws, at the cover's layer: just above the cover, and, for anatomy shown behind it, just below
 * (BULGE_ABOVE_COVER, BULGE_BEHIND_COVER), whatever layer the penis itself is set to draw at.
 * - A printed garment: one patch derived from the cover's drawn sprite (print_derivation.dm), its emissive blocker.
 * - Any other garment: the shape's kinds as white masks tinted with the adaptive palette, and one emissive blocker.
 * - The heart boxers past size 4: their precoloured patch alone.
 * - A hard loincloth: its drape over the penis, which shows through the cover cut away under it (cut_cover.dm).
 * - A revealing or curtain skirt: the penis behind the skirt, and over the cloth inside the skirt's clearance.
 * - Past a family's small_cap: the bare part of the penis, inside the exposed mask, over the cloth.
 * - What the cover draws over its own sprite (its blood, its dirt), over the cloth too, kept to the cloth's pixels.
 * Anatomy is the penis overlay's own images (and the testicles' behind a cover), restricted by masks where it shows
 * over the cloth; it keeps their colours, emissives and skin textures. The cloth is clothing: it carries
 * BULGE_CLOTH_NAME, and the textures a limb draws its skin with leave it alone.
 */

/// The bulge size, 1 to 4, of a penis this long in inches.
/proc/bulge_size_for_length(length_inches)
	if(length_inches < 5)
		return 1
	if(length_inches < 8)
		return 2
	if(length_inches < 11)
		return 3
	return 4

/// The bulge size, 1 to 8, of a penis this long in inches: past 36 inches the penis sprite's own size thresholds
/// (penis/get_sprite_size_string()) carry on, at 37, 49, 57 and 65 inches.
/proc/bulge_size(length_inches)
	var/measured = max(floor(length_inches), 1)
	if(measured >= 65)
		return 8
	if(measured >= 57)
		return 7
	if(measured >= 49)
		return 6
	if(measured >= 37)
		return 5
	return bulge_size_for_length(length_inches)

/// The size affix, 1 to 7, the game draws a penis this long with (penis/get_sprite_size_string()), within `cap`.
/proc/bulge_sprite_size(length_inches, cap)
	var/affix = 7
	switch(max(floor(length_inches), 1))
		if(1 to 6)
			affix = 1
		if(7 to 11)
			affix = 2
		if(12 to 36)
			affix = 3
		if(37 to 48)
			affix = 4
		if(49 to 56)
			affix = 5
		if(57 to 64)
			affix = 6
	return clamp(affix, 1, max(cap, 1))

/datum/bodypart_overlay/mutant/genital/penis
	// What the current look was resolved from (look.dm): a body update that finds all of these unchanged reuses it.
	/// The wearer the look was resolved for.
	var/mob/living/carbon/human/bulge_wearer
	/// The penis's arousal.
	var/bulge_aroused
	/// The penis's length.
	var/bulge_length
	/// The penis overlay's sprite suffix: its shape, sprite size, erection and skin tones.
	var/bulge_suffix
	/// The penis overlay's sprite accessory.
	var/datum/sprite_accessory/bulge_accessory
	/// The wearer's body shape: digitigrade, custom and taur bodies.
	var/bulge_bodyshape
	/// The suit slot's appearance as last drawn; a new one is a new render of the suit.
	var/bulge_suit_drawn
	/// The uniform slot's appearance as last drawn.
	var/bulge_uniform_drawn
	/// The underclothes' appearances as last drawn.
	var/bulge_body_drawn
	/// What the anatomy a look draws (the penis's own images, and the shown testicles' behind a cover) is drawn from
	/// beyond its sprite, as bulge_anatomy_record() lists it; compared on every pass (bulge_anatomy_unchanged()). Null
	/// while the look draws no anatomy.
	var/list/bulge_anatomy
	/// The cover's type (see bulge_cover_unchanged()).
	var/bulge_cover_type
	/// The cover's drawn sprite; null for underclothes.
	var/bulge_cover_icon
	/// The cover's drawn state; for underclothes, the wearer's physique.
	var/bulge_cover_state
	/// The cover's drawn tint; for underclothes, the wearer's colour for them.
	var/bulge_cover_tint
	/// The cover's drawn alpha, root times leaf.
	var/bulge_cover_alpha
	/// The colour treatment the cover is drawn through (its colour filter or colour matrix, as color_atom_overlay()
	/// applies it), or null: no print follows it, and an adaptive cloth is drawn through it too (bulge_cloth_images()).
	var/bulge_cover_filtered
	/// What the cover draws over its sprite (blood, dirt), as bulge_over_signature() reads it; null for nothing.
	var/bulge_cover_over
	/// The cover's worn offset from the left, as drawn; everything the look draws is moved by it.
	var/bulge_cover_x
	/// The cover's worn offset from the bottom, as drawn.
	var/bulge_cover_y

	// The current look; bulge_key is null when there is none.
	/// The look's render key, standing in for the penis's own.
	var/bulge_key
	/// The layer of the garment the look draws over.
	var/bulge_layer
	/// The shape an adaptive look draws: a decoded kind map with its white masks.
	var/datum/bulge_print_template/bulge_template
	/// The patch a printed look draws: a registered icon.
	var/bulge_patch
	/// The precoloured patch a printed look draws past its family's small_cap (the heart boxers).
	var/datum/bulge_sheet_state/bulge_sheet_patch
	/// An adaptive look's palette: the cloth colour.
	var/bulge_cloth
	/// The light kind's colour.
	var/bulge_light
	/// The highlight kind's colour.
	var/bulge_highlight
	/// The shade kind's colour.
	var/bulge_shade
	/// The deep shade kind's colour.
	var/bulge_deep_shade
	/// The mask restricting the anatomy drawn over the cloth (exposed or clearance), or null for none.
	var/datum/bulge_sheet_state/bulge_anatomy_mask
	/// Whether the look draws the anatomy behind its cover.
	var/bulge_anatomy_behind = FALSE
	/// The alpha the cover is drawn with, for a printed patch.
	var/bulge_alpha = 255
	/// What the cover draws over its sprite, kept to the cloth's pixels and drawn over it: appearances, or null.
	var/list/bulge_over

	// The cut each cover slot was last drawn with (cut_cover.dm): a flap template, a loincloth's derived cut, or null.
	/// The uniform's cut.
	var/datum/bulge_uniform_cut
	/// The underwear's cut.
	var/datum/bulge_body_cut
	/// The drawn sprite the uniform's cut was made from: a printed skirt's patch is derived from it, not from its cut.
	var/bulge_uncut_icon
	/// Its state.
	var/bulge_uncut_state
	/// The cut swapped in for it.
	var/bulge_cut_icon
	/// The overlays of the uniform's KEEP_TOGETHER root as built, before the cut also cut what it draws over its sprite
	/// (its blood): the look's cloth carries them uncut. Null when the uniform is not drawn cut or holds no such root.
	var/list/bulge_uncut_over
	/// Set while the look re-draws a cover whose cut no longer matches it, so the re-draw cannot recurse. Reset after the
	/// re-draw and by bulge_clear(), whenever the look is cleared: on every full resolve, one nested in the re-draw
	/// included (which can draw a cover once more), when the penis stops drawing a look, and on removing the penis.
	var/bulge_redrawing = FALSE

/**
 * Whether the overlay draws, the existing visibility chain first: genital devices, husks and clothing. A covered penis
 * (or one layered under clothes) draws its bulge look instead when it has one.
 */
/datum/bodypart_overlay/mutant/genital/penis/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	. = ..()
	var/mob/living/carbon/human/wearer = owner || bodypart_owner.owner
	if(!bulge_key && !bulge_uniform_cut && !bulge_body_cut)
		// The common case, asked on every body update: no look and no cover cut for one. A penis that is not aroused
		// needs nothing more.
		var/obj/item/organ/genital/penis/penis = wearer ? wearer.organs_slot[ORGAN_SLOT_PENIS] : null
		if(!penis || penis.aroused < AROUSAL_PARTIAL)
			return
	if((. && layer_mode == GENITAL_LAYER_NORMAL) || !ishuman(wearer) || hidden_by_device || device_state || bodypart_owner.is_husked || isnull(sprite_datum))
		// Drawn in the open, or not drawn as a bulge: no look, and no cover left cut for one.
		if(bulge_key)
			bulge_clear()
		if((bulge_uniform_cut || bulge_body_cut) && ishuman(wearer))
			bulge_redraw_cuts(wearer, null, null)
		return
	if(bulge_resolve(wearer))
		return TRUE

/// The look's key while it draws, standing in for the penis's own key. A look that draws anatomy carries the hash of
/// the penis's own key and the shown testicles' (bulge_anatomy_record()), so the cache follows their sprites and colours
/// without their keys being built on every pass.
/datum/bodypart_overlay/mutant/genital/penis/icon_render_key(obj/item/bodypart/limb)
	if(!bulge_key)
		return ..()
	return bulge_key

/datum/bodypart_overlay/mutant/genital/penis/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	if(!bulge_key)
		return ..()
	if(layer_index != EXTERNAL_FRONT_UNDER_CLOTHES)
		return list() // The look stands in for the whole penis: nothing behind the body.
	var/front = -(bulge_layer - BULGE_ABOVE_COVER)
	var/list/images = list()
	if(bulge_anatomy_behind)
		var/behind = -(bulge_layer + BULGE_BEHIND_COVER)
		// The genital's own images come at the layer the penis is set to draw at in the open (Custom layering moves
		// it below or above the underwear); behind its cover they draw at the look's.
		for(var/mutable_appearance/anatomy as anything in ..(limb, EXTERNAL_FRONT_UNDER_CLOTHES, behind))
			anatomy.layer = behind
			images += anatomy
		var/list/testicles = bulge_testicle_images(limb, behind)
		if(testicles)
			images += testicles
	var/list/cloth = bulge_cloth_images(limb, front)
	if(cloth)
		images += cloth
	for(var/mutable_appearance/over as anything in bulge_over)
		images += new /mutable_appearance(over) // Its blood and dirt over the cloth, as over the garment around it.
	if(bulge_anatomy_mask)
		for(var/mutable_appearance/anatomy as anything in ..(limb, EXTERNAL_FRONT_UNDER_CLOTHES, front))
			// The mask is placed on the tile: an image drawn off it (a taur sprite, centred) would show the wrong part.
			if(anatomy.pixel_x || anatomy.pixel_y || anatomy.pixel_w || anatomy.pixel_z)
				continue
			var/masked = bulge_masked_icon(anatomy.icon, anatomy.icon_state, bulge_anatomy_mask)
			if(!masked)
				continue
			var/mutable_appearance/shown = new(anatomy)
			shown.icon = masked
			shown.icon_state = ""
			shown.layer = front // Over the cloth, whatever layer the penis is set to draw at.
			images += shown
	if(bulge_cover_x || bulge_cover_y)
		for(var/mutable_appearance/drawn as anything in images)
			drawn.pixel_w += bulge_cover_x
			drawn.pixel_z += bulge_cover_y
	return images

/// The cloth a look draws at `front`: its patch, or its kinds tinted with its palette, and one emissive blocker. The
/// cloth carries BULGE_CLOTH_NAME, so the textures a limb draws its skin with leave it alone.
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_cloth_images(obj/item/bodypart/limb, front)
	if(bulge_patch)
		var/mutable_appearance/patch = mutable_appearance(bulge_patch, "", front)
		patch.alpha = bulge_alpha
		patch.name = BULGE_CLOTH_NAME
		return list(patch, emissive_blocker(bulge_patch, "", limb, front, bulge_alpha))
	if(bulge_sheet_patch)
		var/mutable_appearance/patch = mutable_appearance(bulge_sheet_patch.icon, bulge_sheet_patch.icon_state, front)
		var/mutable_appearance/blocker = emissive_blocker(bulge_sheet_patch.icon, bulge_sheet_patch.icon_state, limb, front)
		patch.name = BULGE_CLOTH_NAME
		patch.pixel_x = bulge_sheet_patch.pixel_x
		patch.pixel_y = bulge_sheet_patch.pixel_y
		blocker.pixel_x = bulge_sheet_patch.pixel_x
		blocker.pixel_y = bulge_sheet_patch.pixel_y
		return list(patch, blocker)
	if(!bulge_template?.mask_union)
		return null
	// A cover drawn through a colour treatment draws its cloth through it too: its colour filter as it is, or its colour
	// matrix made the filter color_atom_overlay() makes of it. The palette is sampled from the cover's untreated sprite,
	// so the cloth and the cover around it take the same treatment over the same colours.
	var/list/filter = bulge_cover_filtered
	if(filter && isnull(filter["type"]))
		filter = color_matrix_filter(color_to_full_rgba_matrix(filter), FILTER_COLOR_RGB)
	. = list()
	if(bulge_template.mask_cloth)
		. += bulge_kind_image(bulge_template.mask_cloth, bulge_cloth, front, filter)
	if(bulge_template.mask_light)
		. += bulge_kind_image(bulge_template.mask_light, bulge_light, front, filter)
	if(bulge_template.mask_highlight)
		. += bulge_kind_image(bulge_template.mask_highlight, bulge_highlight, front, filter)
	if(bulge_template.mask_shade)
		. += bulge_kind_image(bulge_template.mask_shade, bulge_shade, front, filter)
	if(bulge_template.mask_deep_shade)
		. += bulge_kind_image(bulge_template.mask_deep_shade, bulge_deep_shade, front, filter)
	. += emissive_blocker(bulge_template.mask_union, "", limb, front)

/// One kind of an adaptive look: its white mask in its palette colour, through the cover's colour filter, if any.
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_kind_image(mask, colour, front, list/filter)
	var/mutable_appearance/kind = mutable_appearance(mask, "", front)
	kind.color = colour
	kind.name = BULGE_CLOTH_NAME
	if(filter)
		kind.add_filter(ATOM_PRIORITY_COLOR_FILTER, ATOM_PRIORITY_COLOR_FILTER_PRIORITY, filter)
	return kind

/// The testicles' own images at `layer`, while they are hidden by the cover a look shows the penis behind.
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_testicle_images(obj/item/bodypart/limb, layer)
	var/obj/item/organ/genital/testicles/testicles = bulge_shown_testicles(bulge_wearer)
	if(!testicles)
		return null
	var/datum/bodypart_overlay/mutant/genital/testicles_overlay = testicles.bodypart_overlay
	return testicles_overlay.bulge_front_images(limb, layer)

/// The genital's own front images at `layer`, for a bulge drawing it behind a cover, whatever layer it is set to draw
/// at.
/datum/bodypart_overlay/mutant/genital/proc/bulge_front_images(obj/item/bodypart/limb, layer)
	. = get_overlay(limb, EXTERNAL_FRONT_UNDER_CLOTHES, layer)
	for(var/mutable_appearance/drawn as anything in .)
		drawn.layer = layer

/// Forgets the current look and what it was resolved from, and resets the redraw guard.
/datum/bodypart_overlay/mutant/genital/penis/proc/bulge_clear()
	bulge_wearer = null
	bulge_accessory = null
	bulge_suit_drawn = null
	bulge_uniform_drawn = null
	bulge_body_drawn = null
	bulge_anatomy = null
	bulge_cover_type = null
	bulge_cover_icon = null
	bulge_cover_state = null
	bulge_cover_tint = null
	bulge_cover_alpha = null
	bulge_cover_filtered = null
	bulge_cover_over = null
	bulge_cover_x = null
	bulge_cover_y = null
	bulge_key = null
	bulge_template = null
	bulge_patch = null
	bulge_sheet_patch = null
	bulge_cloth = null
	bulge_light = null
	bulge_highlight = null
	bulge_shade = null
	bulge_deep_shade = null
	bulge_anatomy_mask = null
	bulge_anatomy_behind = FALSE
	bulge_alpha = 255
	bulge_over = null
	bulge_redrawing = FALSE
