/datum/dna
	/// This owner's hair drawing; DNA and head snapshots are copied independently.
	var/list/custom_hair
	/// This owner's facial hair drawing; DNA and head snapshots are copied independently.
	var/list/custom_facial_hair
	/// Body zone -> paint inherited by newly created limbs.
	var/list/custom_limb_markings

/// Appearance copies honor the master preference without changing saved layer settings.
/proc/custom_sprite_appearance_drawing(list/drawing, allow_emissives)
	if(!drawing)
		return null
	var/list/result = deep_copy_list(drawing)
	result["emissive"] = custom_sprite_emissive_settings(allow_emissives ? result["emissive"] : FALSE)
	return result

/obj/item/bodypart/head
	/// This owner's hair drawing; DNA and head snapshots are copied independently.
	var/list/custom_hair
	/// This owner's facial hair drawing; DNA and head snapshots are copied independently.
	var/list/custom_facial_hair

/// The drawing this head carries for one head target.
/obj/item/bodypart/head/proc/custom_head_drawing(target)
	return target == "facial_hair" ? custom_facial_hair : custom_hair

/// Replaces the drawing this head carries for one head target.
/obj/item/bodypart/head/proc/set_custom_head_drawing(target, list/drawing)
	if(target == "facial_hair")
		custom_facial_hair = drawing
	else
		custom_hair = drawing

/// Hairstyles without an icon state, such as Bald, register no accessory datum. This nameless
/// accessory is never selectable; it only lets those heads carry custom paint.
/datum/sprite_accessory/hair/custom_sprite_blank
	icon_state = SPRITE_ACCESSORY_NONE

/obj/item/bodypart/head/proc/custom_sprite_hair_accessory()
	var/datum/sprite_accessory/hair/accessory = SSaccessories.hairstyles_list[hairstyle]
	if(accessory || !custom_hair)
		return accessory
	var/static/datum/sprite_accessory/hair/custom_sprite_blank/blank = new
	return blank

/// Shaved faces register no accessory datum either, so paint needs the same nameless stand-in.
/datum/sprite_accessory/facial_hair/custom_sprite_blank
	icon_state = SPRITE_ACCESSORY_NONE

/obj/item/bodypart/head/proc/custom_sprite_facial_hair_accessory()
	var/datum/sprite_accessory/facial_hair/accessory = SSaccessories.facial_hairstyles_list[facial_hairstyle]
	if(accessory || !custom_facial_hair)
		return accessory
	var/static/datum/sprite_accessory/facial_hair/custom_sprite_blank/blank = new
	return blank

/// Include explicit blank frames: a missing facing would fall back to the South mask.
/proc/custom_sprite_directional_mask(icon/source, geometry_key, list/directions, glowing)
	// Bounded cache of directional drawing emission and blocker masks.
	var/static/list/emissive_icons = list()
	var/list/selected = list()
	for(var/direction in GLOB.cardinals)
		if((directions?["[direction]"] == TRUE) == glowing)
			selected += direction
	if(!length(selected))
		return null
	if(length(selected) == 4)
		return source
	var/key = "[geometry_key]|[jointext(selected, ",")]"
	var/icon/cached = emissive_icons[key]
	if(cached)
		return cached
	var/icon/source_icon = icon(source)
	var/icon/masked = custom_sprite_blank_icon(source_icon.Width())
	for(var/direction in selected)
		masked.Insert(icon(source_icon, "", direction), "", direction)
	return custom_sprite_cache_put(emissive_icons, key, masked)

/// Each head gets a private masked copy; the shared accessory cache is never painted.
/obj/item/bodypart/head/proc/get_custom_hair_paint(datum/sprite_accessory/hair/hairstyle, target = "hair")
	var/icon/cached = custom_sprite_paint_icon(custom_head_drawing(target))
	if(!cached)
		return null
	var/icon/paint = icon(cached)
	if(target == "facial_hair")
		return paint
	for(var/datum/hair_mask/mask as anything in owner?.hair_masks)
		var/icon/mask_icon = icon(mask.icon, mask.icon_state)
		mask_icon.Shift(SOUTH, hairstyle.y_offset)
		paint.Blend(mask_icon, ICON_ADD)
	return paint

/obj/item/bodypart/head/proc/append_custom_hair_paint_overlays(list/hair_overlays, icon/paint, datum/sprite_accessory/hair/hairstyle, dropped, target = "hair")
	if(!paint)
		return
	var/list/drawing = custom_head_drawing(target)
	var/facial = target == "facial_hair"
	var/offset_x = 0
	var/offset_z = facial ? 0 : hairstyle.y_offset
	if(!facial && LAZYFIND(owner?.dna?.species?.offset_features, OFFSET_HAIR))
		offset_x = owner.dna.species.offset_features[OFFSET_HAIR][INDEX_W]
		offset_z += owner.dna.species.offset_features[OFFSET_HAIR][INDEX_Z]
	var/alpha_to_use = facial ? facial_hair_alpha : hair_alpha
	var/image/tinted = image(paint, layer = -HAIR_LAYER, dir = dropped ? SOUTH : null)
	tinted.appearance_flags |= RESET_COLOR
	tinted.color = drawing["tint"]
	tinted.alpha = alpha_to_use
	tinted.pixel_x = offset_x
	tinted.pixel_z = offset_z
	worn_face_offset?.apply_offset(tinted)
	var/list/geometry = list(target, custom_sprite_pixel_hash(drawing), hairstyle.type, facial ? 0 : hairstyle.y_offset)
	if(!facial)
		for(var/datum/hair_mask/mask as anything in owner?.hair_masks)
			geometry += "[mask.icon]|[mask.icon_state]"
	var/geometry_key = json_encode(geometry)
	// Legacy paint is merged into the base hair; its OFF mask must still cover base hair emission.
	var/icon/blocking = custom_sprite_directional_mask(paint, geometry_key, drawing["emissive"], FALSE)
	if(blocking)
		var/mutable_appearance/blocker = custom_sprite_emissive_mask(tinted, loc || owner || src, FALSE)
		blocker.icon = blocking
		if(dropped)
			blocker = make_mutable_appearance_directional(blocker, SOUTH)
		hair_overlays += blocker
	if(drawing["tint"])
		hair_overlays += tinted
		// The base gradient is built from the accessory alone, so painted pixels need their own copy.
		var/gradient_key = custom_style_gradient_key(target)
		var/gradient_style = get_hair_gradient_style(gradient_key)
		var/list/gradients = custom_style_hair_gradients(target)
		if(gradient_style != SPRITE_ACCESSORY_NONE && gradients[gradient_style])
			var/image/paint_gradient = get_gradient_overlay(paint, -HAIR_LAYER, gradients[gradient_style], get_hair_gradient_color(gradient_key), dropped)
			paint_gradient.pixel_x += offset_x
			paint_gradient.pixel_z += offset_z
			if(alpha_to_use == 255)
				hair_overlays += paint_gradient
			else
				// Match native hair composition: blend first, then apply opacity once.
				hair_overlays -= tinted
				var/image/shared_holder = image(layer = -HAIR_LAYER, dir = dropped ? SOUTH : null)
				shared_holder.alpha = alpha_to_use
				shared_holder.appearance_flags |= KEEP_TOGETHER
				var/image/opaque_paint = image(tinted)
				opaque_paint.alpha = 255
				shared_holder.overlays += opaque_paint
				shared_holder.overlays += paint_gradient
				hair_overlays += shared_holder
	var/icon/emitting = custom_sprite_directional_mask(paint, geometry_key, drawing["emissive"], TRUE)
	if(emitting)
		var/mutable_appearance/glow = custom_sprite_emissive_mask(tinted, loc || owner || src, TRUE)
		glow.icon = emitting
		if(dropped)
			glow = make_mutable_appearance_directional(glow, SOUTH)
		hair_overlays += glow

/// Reuse the visible paint's placement; shared worn/bodypart preparation owns pose transforms.
/proc/custom_sprite_emissive_mask(image/source, atom/location, glowing)
	var/mutable_appearance/mask = glowing ? emissive_appearance(source.icon, source.icon_state, location, source.layer, source.alpha) : emissive_blocker(source.icon, source.icon_state, location, source.layer, source.alpha)
	// Leave dir unassigned so nested masks inherit the character's facing.
	// Copying an image's default South fixes the frame inside the emissive group.
	mask.pixel_x = source.pixel_x
	mask.pixel_y = source.pixel_y
	mask.pixel_w = source.pixel_w
	mask.pixel_z = source.pixel_z
	mask.transform = source.transform
	mask.filters = source.filters
	return mask

/datum/bodypart_overlay/custom_marking
	layers = list("" = BODYPARTS_LAYER)
	draw_on_husks = HUSK_OVERLAY_NONE
	offset_location = ENTIRE_BODY
	/// Private drawing snapshot owned by this limb overlay.
	var/list/drawing
	/// Full drawing identity used to skip unchanged overlay updates.
	var/drawing_hash
	/// Pixel identity shared by cached masks with different appearance settings.
	var/drawing_pixel_hash

/datum/bodypart_overlay/custom_marking/proc/set_drawing(list/new_drawing, obj/item/bodypart/limb)
	drawing = deep_copy_list(new_drawing)
	drawing_hash = custom_sprite_hash(drawing)
	drawing_pixel_hash = custom_sprite_pixel_hash(drawing)
	if(limb.aux_zone)
		set_layer("aux", limb.aux_layer)

/datum/bodypart_overlay/custom_marking/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	return ..() && drawing && !(bodypart_owner.bodyshape & BODYSHAPE_TAUR)

/datum/bodypart_overlay/custom_marking/icon_render_key(obj/item/bodypart/limb)
	return list("custom-marking", drawing_hash, drawing?["tint"], limb.body_zone, limb.bodyshape, limb.limb_gender, limb.is_dimorphic, limb.custom_sprite_icon_file(), custom_sprite_limb_state(limb), limb.aux_zone, limb.aux_layer, limb.markings_alpha)

/// Pixel caches depend on paint and mask geometry, not tint, opacity, emission or layer.
/datum/bodypart_overlay/custom_marking/proc/pixel_render_key(obj/item/bodypart/limb)
	return list("custom-marking", drawing_pixel_hash, limb.custom_sprite_icon_file(), custom_sprite_limb_state(limb), limb.aux_zone ? custom_sprite_limb_state(limb, TRUE) : null)

/datum/bodypart_overlay/custom_marking/get_image(obj/item/bodypart/limb, layer_index, layer_real)
	var/key = "[jointext(pixel_render_key(limb), "|")]|[layer_index]"
	var/icon/clipped = GLOB.custom_sprite_limb_icons[key]
	if(!clipped)
		var/icon/paint = custom_sprite_paint_icon(drawing)
		clipped = paint ? icon(paint) : icon('icons/blanks/32x32.dmi', "nothing")
		clipped.Blend(custom_sprite_silhouette(limb, layer_index == "aux"), ICON_MULTIPLY)
		custom_sprite_cache_put(GLOB.custom_sprite_limb_icons, key, clipped)
	var/image/result = image(clipped, layer = layer_real)
	result.appearance_flags |= RESET_COLOR
	result.alpha = limb.markings_alpha
	return result

/datum/bodypart_overlay/custom_marking/color_image(image/overlay, obj/item/bodypart/limb, layer_index)
	overlay.color = drawing?["tint"]

/// Bodypart overlays are collected after the normal leg split, so split our own overlays here.
/// Content keys avoid the runtime-icon reference reuse issue in generate_masked_leg().
/datum/bodypart_overlay/custom_marking/get_all_overlays(obj/item/bodypart/limb)
	. = ..()
	var/split_leg = !!limb.owner && (limb.body_zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
	var/key = jointext(pixel_render_key(limb), "|")
	if(split_leg)
		var/list/split_overlays = list()
		var/overlay_index = 0
		for(var/image/overlay as anything in .)
			overlay_index++
			for(var/lower_layer in list(FALSE, TRUE))
				var/cache_key = "[key]|leg|[overlay_index]|[lower_layer]"
				var/icon/masked = GLOB.custom_sprite_limb_icons[cache_key]
				if(!masked)
					masked = icon(overlay.icon, overlay.icon_state)
					var/leg = limb.body_zone == BODY_ZONE_R_LEG ? "right_leg" : "left_leg"
					masked.Blend(icon('icons/mob/leg_masks.dmi', "[leg][lower_layer ? "_lower" : ""]"), ICON_MULTIPLY)
					custom_sprite_cache_put(GLOB.custom_sprite_limb_icons, cache_key, masked)
				var/image/split_overlay = image(overlay)
				split_overlay.icon = masked
				split_overlay.icon_state = ""
				split_overlay.layer = lower_layer ? -BODYPARTS_LOW_LAYER : -BODYPARTS_LAYER
				split_overlays += split_overlay
		. = split_overlays
	var/list/visible_overlays = list()
	var/list/masks = list()
	var/index = 0
	for(var/image/overlay as anything in .)
		if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE)
			continue
		visible_overlays += overlay
		index++
		var/geometry_key = "marking|[key]|split=[split_leg]|[index]|[overlay.layer]"
		var/icon/emitting = custom_sprite_directional_mask(overlay.icon, geometry_key, drawing?["emissive"], TRUE)
		if(emitting)
			var/mutable_appearance/glow = custom_sprite_emissive_mask(overlay, limb, TRUE)
			glow.icon = emitting
			masks += glow
		var/icon/blocking = custom_sprite_directional_mask(overlay.icon, geometry_key, drawing?["emissive"], FALSE)
		if(blocking && blocks_emissive != EMISSIVE_BLOCK_NONE)
			var/mutable_appearance/blocker = custom_sprite_emissive_mask(overlay, limb, FALSE)
			blocker.icon = blocking
			masks += blocker
	// Each facing emits OR blocks; translucent edges must not receive both masks.
	. = visible_overlays + masks

/// Native layer ownership stays with the external organ; paint only reads this cached list.
/datum/bodypart_overlay/mutant/taur_body/proc/custom_sprite_layers()
	return layers

/// Lower-body paint uses the actual taur organ, never its invisible leg slots.
/datum/bodypart_overlay/custom_marking/taur

/datum/bodypart_overlay/custom_marking/taur/set_drawing(list/new_drawing, obj/item/bodypart/limb)
	. = ..()
	var/datum/bodypart_overlay/mutant/taur_body/taur = custom_sprite_taur_overlay(limb.owner)
	if(taur)
		set_layers(taur.custom_sprite_layers())

/datum/bodypart_overlay/custom_marking/taur/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	if(!..())
		return FALSE
	var/datum/bodypart_overlay/mutant/taur_body/taur = custom_sprite_taur_overlay(owner)
	return taur && taur.can_draw_on_bodypart(bodypart_owner, owner)

/datum/bodypart_overlay/custom_marking/taur/pixel_render_key(obj/item/bodypart/limb)
	var/datum/bodypart_overlay/mutant/taur_body/taur = custom_sprite_taur_overlay(limb.owner)
	return list("custom-taur-marking", drawing_pixel_hash, limb.limb_gender, taur ? json_encode(taur.icon_render_key(limb)) : "missing")

/datum/bodypart_overlay/custom_marking/taur/icon_render_key(obj/item/bodypart/limb)
	return pixel_render_key(limb) + list(drawing_hash, limb.markings_alpha)

/datum/bodypart_overlay/custom_marking/taur/get_image(obj/item/bodypart/limb, layer_index, layer_real)
	var/key = "[jointext(pixel_render_key(limb), "|")]|[layer_index]"
	var/icon/clipped = GLOB.custom_sprite_limb_icons[key]
	if(!clipped)
		var/icon/paint = custom_sprite_paint_icon(drawing)
		clipped = paint ? icon(paint) : custom_sprite_blank_icon(64)
		clipped.Blend(custom_sprite_taur_silhouette(limb.owner, layer_index), ICON_MULTIPLY)
		custom_sprite_cache_put(GLOB.custom_sprite_limb_icons, key, clipped)
	var/image/result = image(clipped, layer = layer_real)
	result.appearance_flags |= RESET_COLOR
	center_image(result, 64, 32)
	result.alpha = limb.markings_alpha
	return result

/// The taur zone's own paint on the chest.
/datum/bodypart_overlay/custom_marking/taur/zone

/// Refresh only the lower-body snapshot; ordinary limb and donor paint remain independent.
/mob/living/carbon/human/proc/sync_custom_taur_markings()
	var/obj/item/bodypart/chest = get_bodypart(BODY_ZONE_CHEST)
	if(!chest)
		return
	chest.apply_custom_marking(custom_sprite_taur_overlay(src) ? dna.custom_limb_markings?[CUSTOM_MARKING_ZONE_TAUR] : null, /datum/bodypart_overlay/custom_marking/taur/zone)

/// A limb zone's own paint.
/datum/bodypart_overlay/custom_marking/zone

/// Hand paint belongs to the arm limb, alongside that arm's own zone drawing.
/datum/bodypart_overlay/custom_marking/zone/hand

/// Applies this limb's zone drawing and, for arms, its hand drawing.
/obj/item/bodypart/proc/sync_custom_zone_markings(list/zone_drawings)
	apply_custom_marking(zone_drawings?[body_zone], /datum/bodypart_overlay/custom_marking/zone)
	for(var/hand_zone in GLOB.custom_marking_hand_arms)
		if(GLOB.custom_marking_hand_arms[hand_zone] == body_zone)
			apply_custom_marking(zone_drawings?[hand_zone], /datum/bodypart_overlay/custom_marking/zone/hand)

/// This limb's custom marking overlay of exactly this type. Hand paint is a subtype of zone paint on the same arm.
/obj/item/bodypart/proc/get_custom_marking(overlay_type)
	for(var/datum/bodypart_overlay/custom_marking/candidate in bodypart_overlays)
		if(candidate.type == overlay_type)
			return candidate

/obj/item/bodypart/proc/apply_custom_marking(list/drawing, overlay_type = /datum/bodypart_overlay/custom_marking/zone)
	var/datum/bodypart_overlay/custom_marking/overlay = get_custom_marking(overlay_type)
	if(!drawing)
		if(overlay)
			remove_bodypart_overlay(overlay, FALSE)
			qdel(overlay)
		return
	var/hash = custom_sprite_hash(drawing)
	if(overlay?.drawing_hash == hash)
		return
	if(!overlay)
		overlay = new overlay_type
		add_bodypart_overlay(overlay, FALSE)
	overlay.set_drawing(drawing, src)

/mob/living/carbon/human/proc/sync_custom_sprite_appearance(refresh_body = FALSE)
	AddComponent(/datum/component/custom_sprite_appearance)
	// A body refresh already snapshots markings through the component and hair through update_limb().
	if(refresh_body)
		update_body(is_creating = TRUE)
		return
	for(var/obj/item/bodypart/limb as anything in bodyparts)
		limb.sync_custom_zone_markings(dna.custom_limb_markings)
	sync_custom_taur_markings()
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(head)
		head.custom_hair = deep_copy_list(dna.custom_hair)
		head.custom_facial_hair = deep_copy_list(dna.custom_facial_hair)

/mob/living/carbon/human/set_haircolor(hex_string, override, update = TRUE)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	var/old_color = custom_style_normal_color(head?.hair_color || hair_color)
	. = ..(hex_string, override, FALSE)
	custom_sprite_recolor_hair(old_color)
	if(update)
		update_hair()

/mob/living/carbon/human/set_facial_haircolor(hex_string, override, update = TRUE)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	var/old_color = custom_style_normal_color(head?.facial_hair_color || facial_hair_color)
	. = ..(hex_string, override, FALSE)
	custom_sprite_recolor_hair(old_color, "facial_hair")
	if(update)
		update_hair()

/**
 * Carries painted hair shades along with a hair color change, the way the editor's palette does.
 *
 * Dyeing or recoloring hair moves paint drawn in the old shades to the matching new shade. Saved
 * custom colors and paint that isn't a hair shade keep their color. Temporary color overrides,
 * which leave the character's own hair color alone, change nothing.
 */
/mob/living/carbon/human/proc/custom_sprite_recolor_hair(old_color, target = "hair")
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	var/facial = target == "facial_hair"
	var/list/dna_drawing = facial ? dna?.custom_facial_hair : dna?.custom_hair
	var/list/head_drawing = head?.custom_head_drawing(target)
	if(!dna_drawing?["tint"] && !head_drawing?["tint"])
		return
	var/list/new_hair = custom_style_live_hair_context(src, target)
	if(new_hair["color"] == old_color)
		return
	var/list/old_hair = new_hair.Copy()
	old_hair["color"] = old_color
	var/datum/preferences/preferences = GLOB.preferences_datums[ckey]
	var/list/color_map = custom_style_hair_color_map(old_hair, new_hair, preferences?.read_preference(/datum/preference/custom_sprite_palette), target)
	if(!color_map)
		return
	if(facial)
		dna.custom_facial_hair = custom_style_recolor_drawing(dna_drawing, color_map) || dna_drawing
	else
		dna.custom_hair = custom_style_recolor_drawing(dna_drawing, color_map) || dna_drawing
	head?.set_custom_head_drawing(target, custom_style_recolor_drawing(head_drawing, color_map) || head_drawing)

/// Reapply on regenerated/species-replaced limbs; detached limbs retain their own snapshots.
/datum/component/custom_sprite_appearance
	dupe_mode = COMPONENT_DUPE_UNIQUE

/datum/component/custom_sprite_appearance/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/custom_sprite_appearance/RegisterWithParent()
	RegisterSignal(parent, COMSIG_CARBON_BODYPART_UPDATED, PROC_REF(on_limb_updated))
	RegisterSignals(parent, list(COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN), PROC_REF(on_organ_changed))

/datum/component/custom_sprite_appearance/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_CARBON_BODYPART_UPDATED, COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN))

/datum/component/custom_sprite_appearance/proc/on_limb_updated(mob/living/carbon/human/source, obj/item/bodypart/limb, dropping_limb, is_creating)
	SIGNAL_HANDLER
	if(!dropping_limb && is_creating)
		limb.sync_custom_zone_markings(source.dna.custom_limb_markings)
		if(limb.body_zone == BODY_ZONE_CHEST)
			source.sync_custom_taur_markings()

/datum/component/custom_sprite_appearance/proc/on_organ_changed(mob/living/carbon/human/source, obj/item/organ/organ, special)
	SIGNAL_HANDLER
	if(istype(organ, /obj/item/organ/taur_body))
		source.sync_custom_taur_markings()
