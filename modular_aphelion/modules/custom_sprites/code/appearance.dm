/datum/dna
	var/list/custom_hair
	var/list/custom_markings
	var/list/custom_limb_markings

/// Appearance copies honor the master preference without changing saved layer settings.
/proc/custom_sprite_appearance_drawing(list/drawing, allow_emissives)
	if(!drawing)
		return null
	var/list/result = deep_copy_list(drawing)
	result["emissive"] = custom_sprite_emissive_settings(allow_emissives ? result["emissive"] : FALSE)
	return result

/obj/item/bodypart/head
	var/list/custom_hair

GLOBAL_LIST_EMPTY(custom_sprite_emissive_icons)

/// Include explicit blank frames: a missing facing would fall back to the South mask.
/proc/custom_sprite_directional_mask(icon/source, geometry_key, list/directions, glowing)
	var/list/selected = list()
	for(var/direction in GLOB.cardinals)
		if((directions?["[direction]"] == TRUE) == glowing)
			selected += direction
	if(!length(selected))
		return null
	if(length(selected) == 4)
		return source
	var/key = "[geometry_key]|[jointext(selected, ",")]"
	var/icon/cached = GLOB.custom_sprite_emissive_icons[key]
	if(cached)
		return cached
	var/icon/masked = custom_sprite_blank_icon()
	for(var/direction in selected)
		masked.Insert(icon(source, "", direction), "", direction)
	return custom_sprite_cache_put(GLOB.custom_sprite_emissive_icons, key, masked)

/// Each head gets a private masked copy; the shared hairstyle cache is never painted.
/obj/item/bodypart/head/proc/get_custom_hair_paint(datum/sprite_accessory/hair/hairstyle)
	var/icon/cached = custom_sprite_paint_icon(custom_hair)
	if(!cached)
		return null
	var/icon/paint = icon(cached)
	for(var/datum/hair_mask/mask as anything in owner?.hair_masks)
		var/icon/mask_icon = icon(mask.icon, mask.icon_state)
		mask_icon.Shift(SOUTH, hairstyle.y_offset)
		paint.Blend(mask_icon, ICON_ADD)
	return paint

/obj/item/bodypart/head/proc/append_custom_hair_tint_overlays(list/overlays, icon/paint, datum/sprite_accessory/hair/hairstyle, dropped)
	if(!paint)
		return
	var/image/tinted = image(paint, layer = -HAIR_LAYER, dir = dropped ? SOUTH : null)
	tinted.appearance_flags |= RESET_COLOR
	tinted.color = custom_hair["tint"]
	tinted.alpha = hair_alpha
	tinted.pixel_z = hairstyle.y_offset
	if(LAZYFIND(owner?.dna?.species?.offset_features, OFFSET_HAIR))
		tinted.pixel_x += owner.dna.species.offset_features[OFFSET_HAIR][INDEX_W]
		tinted.pixel_z += owner.dna.species.offset_features[OFFSET_HAIR][INDEX_Z]
	worn_face_offset?.apply_offset(tinted)
	var/list/geometry = list("hair", custom_sprite_pixel_hash(custom_hair), hairstyle.type, hairstyle.y_offset)
	for(var/datum/hair_mask/mask as anything in owner?.hair_masks)
		geometry += "[mask.icon]|[mask.icon_state]"
	var/geometry_key = json_encode(geometry)
	// Legacy paint is merged into the base hair; its OFF mask must still cover base hair emission.
	var/icon/blocking = custom_sprite_directional_mask(paint, geometry_key, custom_hair["emissive"], FALSE)
	if(blocking)
		var/mutable_appearance/blocker = custom_sprite_emissive_mask(tinted, loc || owner || src, FALSE)
		blocker.icon = blocking
		if(dropped)
			blocker = make_mutable_appearance_directional(blocker, SOUTH)
		overlays += blocker
	if(custom_hair["tint"])
		overlays += tinted
	var/icon/emitting = custom_sprite_directional_mask(paint, geometry_key, custom_hair["emissive"], TRUE)
	if(emitting)
		var/mutable_appearance/glow = custom_sprite_emissive_mask(tinted, loc || owner || src, TRUE)
		glow.icon = emitting
		if(dropped)
			glow = make_mutable_appearance_directional(glow, SOUTH)
		overlays += glow

/// Reuse the visible paint's placement; shared worn/bodypart preparation owns pose transforms.
/proc/custom_sprite_emissive_mask(image/source, atom/location, glowing)
	var/mutable_appearance/mask = glowing \
		? emissive_appearance(source.icon, source.icon_state, location, source.layer, source.alpha) \
		: emissive_blocker(source.icon, source.icon_state, location, source.layer, source.alpha)
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
	var/list/drawing
	var/drawing_hash
	var/drawing_pixel_hash

/datum/bodypart_overlay/custom_marking/proc/set_drawing(list/new_drawing, obj/item/bodypart/limb)
	drawing = new_drawing ? deep_copy_list(new_drawing) : null
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
	if(split_leg)
		var/list/split_overlays = list()
		var/key = jointext(pixel_render_key(limb), "|")
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
		var/geometry_key = "marking|[jointext(pixel_render_key(limb), "|")]|split=[split_leg]|[index]|[overlay.layer]"
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

/// Separate overlay identity lets whole-body and limb drawings coexist.
/datum/bodypart_overlay/custom_marking/zone

/obj/item/bodypart/proc/apply_custom_marking(list/drawing, overlay_type = /datum/bodypart_overlay/custom_marking)
	var/datum/bodypart_overlay/custom_marking/overlay
	for(var/datum/bodypart_overlay/custom_marking/candidate in bodypart_overlays)
		if(candidate.type == overlay_type)
			overlay = candidate
			break
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
		limb.apply_custom_marking(dna.custom_markings)
		limb.apply_custom_marking(dna.custom_limb_markings?[limb.body_zone], /datum/bodypart_overlay/custom_marking/zone)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(head)
		head.custom_hair = dna.custom_hair ? deep_copy_list(dna.custom_hair) : null

/// Reapply on regenerated/species-replaced limbs; detached limbs retain their own snapshots.
/datum/component/custom_sprite_appearance
	dupe_mode = COMPONENT_DUPE_UNIQUE

/datum/component/custom_sprite_appearance/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/custom_sprite_appearance/RegisterWithParent()
	RegisterSignal(parent, COMSIG_CARBON_BODYPART_UPDATED, PROC_REF(on_limb_updated))

/datum/component/custom_sprite_appearance/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_CARBON_BODYPART_UPDATED)

/datum/component/custom_sprite_appearance/proc/on_limb_updated(mob/living/carbon/human/source, obj/item/bodypart/limb, dropping_limb, is_creating)
	SIGNAL_HANDLER
	if(!dropping_limb && is_creating)
		limb.apply_custom_marking(source.dna.custom_markings)
		limb.apply_custom_marking(source.dna.custom_limb_markings?[limb.body_zone], /datum/bodypart_overlay/custom_marking/zone)
