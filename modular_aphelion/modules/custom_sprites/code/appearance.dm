/datum/dna
	var/list/custom_hair
	var/list/custom_markings

/obj/item/bodypart/head
	var/list/custom_hair

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
	if(!paint || !custom_hair?["tint"])
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
	if(blocks_emissive != EMISSIVE_BLOCK_NONE)
		var/mutable_appearance/blocker = emissive_blocker(paint, "", loc || owner || src, -HAIR_LAYER, alpha = hair_alpha)
		blocker.pixel_x = tinted.pixel_x
		blocker.pixel_z = tinted.pixel_z
		if(dropped)
			blocker = image(blocker, dir = SOUTH)
		overlays += blocker
	overlays += tinted

/datum/bodypart_overlay/custom_marking
	layers = list("" = BODYPARTS_LAYER)
	draw_on_husks = HUSK_OVERLAY_NONE
	offset_location = ENTIRE_BODY
	var/list/drawing
	var/drawing_hash

/datum/bodypart_overlay/custom_marking/proc/set_drawing(list/new_drawing, obj/item/bodypart/limb)
	drawing = new_drawing ? deep_copy_list(new_drawing) : null
	drawing_hash = custom_sprite_hash(drawing)
	if(limb.aux_zone)
		set_layer("aux", limb.aux_layer)

/datum/bodypart_overlay/custom_marking/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	return ..() && drawing && !(bodypart_owner.bodyshape & BODYSHAPE_TAUR)

/datum/bodypart_overlay/custom_marking/icon_render_key(obj/item/bodypart/limb)
	return list("custom-marking", drawing_hash, drawing?["tint"], limb.body_zone, limb.bodyshape, limb.limb_gender, limb.is_dimorphic, custom_sprite_limb_file(limb), custom_sprite_limb_state(limb), limb.aux_zone, limb.aux_layer, limb.markings_alpha)

/datum/bodypart_overlay/custom_marking/get_image(obj/item/bodypart/limb, layer_index, layer_real)
	var/key = "[jointext(icon_render_key(limb), "|")]|[layer_index]"
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
	if(!limb.owner || !(limb.body_zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)))
		return
	var/list/split_overlays = list()
	var/key = jointext(icon_render_key(limb), "|")
	for(var/image/overlay as anything in .)
		for(var/lower_layer in list(FALSE, TRUE))
			var/cache_key = "[key]|leg|[lower_layer]"
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
	return split_overlays

/obj/item/bodypart/proc/apply_custom_marking(list/drawing)
	var/datum/bodypart_overlay/custom_marking/overlay = locate() in bodypart_overlays
	if(!drawing)
		if(overlay)
			remove_bodypart_overlay(overlay, FALSE)
			qdel(overlay)
		return
	var/hash = custom_sprite_hash(drawing)
	if(overlay?.drawing_hash == hash)
		return
	if(!overlay)
		overlay = new
		add_bodypart_overlay(overlay, FALSE)
	overlay.set_drawing(drawing, src)

/mob/living/carbon/human/proc/sync_custom_sprite_appearance()
	AddComponent(/datum/component/custom_sprite_appearance)
	for(var/obj/item/bodypart/limb as anything in bodyparts)
		limb.apply_custom_marking(dna.custom_markings)
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
