/**
 * Appends this limb's native base markings before height and body textures are applied.
 *
 * The ordinary limb renderer passes its existing overlay list, preserving native layer order
 * without allocating another list. An editor may request one body or auxiliary zone, omit the
 * separate emissive appearances and replace the live marking opacity while sampling its pixels.
 * No body, custom paint or external-organ overlays are included.
 *
 * Arguments:
 * - output: The caller-owned list of overlays to their flags to append to. Markings texture like the limb itself.
 * - zone: A body or auxiliary zone to include, or null for both in native order.
 * - include_emissive: Whether native emissive appearances accompany the visible markings.
 * - alpha_override: An explicit visible marking opacity, or null to use markings_alpha.
 *
 * Returns the same output list.
 */
/obj/item/bodypart/proc/append_base_marking_overlays(list/output, zone = null, include_emissive = TRUE, alpha_override = null)
	// Placed bodyparts, chainsaw hands and stumps have no markings, and taur legs never ever render.
	if((bodypart_flags & (BODYPART_PSEUDOPART | BODYPART_STUMP)) || (bodyshape & BODYSHAPE_TAUR))
		return output
	var/atom/offset_spokesman = owner || src
	// A husked limb doesn't get our sparkledog colors.
	var/override_color = is_husked ? "#888888" : null
	// The body zone's markings, then the auxiliary zone's on its own layer. Only the body zone has digitigrade states.
	for(var/aux in list(FALSE, TRUE))
		var/marking_zone = aux ? aux_zone : body_zone
		if((aux && !aux_zone) || (!isnull(zone) && zone != marking_zone))
			continue
		var/digi_modifier = !aux && (bodyshape & BODYSHAPE_DIGITIGRADE) ? "digitigrade_" : ""
		for(var/key, marking in aux ? aux_zone_markings : markings) // Cycle through all of our currently selected markings.
			var/datum/body_marking/body_marking = GLOB.body_markings[key]
			if(!body_marking) // Edge case prevention.
				continue
			// Chest markings have male and female versions.
			var/gender_modifier = marking_zone == BODY_ZONE_CHEST && body_marking.gendered ? (is_dimorphic ? "_[limb_gender]" : "_m") : ""
			var/mutable_appearance/accessory_overlay = mutable_appearance(body_marking.icon, "[body_marking.icon_state]_[digi_modifier][marking_zone][gender_modifier]", aux ? -aux_layer : -BODYPARTS_LAYER)
			accessory_overlay.alpha = isnull(alpha_override) ? markings_alpha : alpha_override
			accessory_overlay.color = override_color || marking[1]
			output[accessory_overlay] = LIMB_OVERLAY_TEXTURED|LIMB_OVERLAY_CORE
			if(include_emissive && marking[2])
				output[emissive_appearance(accessory_overlay.icon, accessory_overlay.icon_state, offset_spokesman = offset_spokesman, layer = accessory_overlay.layer)] = LIMB_OVERLAY_META
	return output
