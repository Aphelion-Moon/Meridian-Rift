/**
 * Appends this limb's native base markings before height and body textures are applied.
 *
 * The ordinary limb renderer passes its existing overlay list, preserving native layer order
 * without allocating another list. An editor may request one body or auxiliary zone, omit the
 * separate emissive appearances and replace the live marking opacity while sampling its pixels.
 * No body, custom paint or external-organ overlays are included. A marking draws only the state its
 * drawn_state() answers, and nothing where it has no art: see zone_icon_state().
 *
 * Arguments:
 * - output: The caller-owned overlay list to append to.
 * - zone: A body or auxiliary zone to include, or null for both in native order.
 * - include_emissive: Whether native emissive appearances accompany the visible markings.
 * - alpha_override: An explicit visible marking opacity, or null to use markings_alpha.
 * - image_dir: A facing every appearance keeps whichever way its holder faces, SOUTH for a dropped limb as its own
 *   images have, or null to follow the holder.
 *
 * Returns the same output list.
 */
/obj/item/bodypart/proc/append_base_marking_overlays(list/output, zone = null, include_emissive = TRUE, alpha_override = null, image_dir = null)
	var/override_color
	var/atom/offset_spokesman = owner || src
	// First, check to see if this bodypart is husked. If so, we don't want to apply our sparkledog colors to the limb.
	if(is_husked)
		override_color = "#888888"
	// We need to check that the owner exists(could be a placed bodypart) and that it's not a chainsawhand and that they're a human with usable DNA.
	if(!(bodypart_flags & (BODYPART_PSEUDOPART | BODYPART_STUMP)) && (!(bodyshape & BODYSHAPE_TAUR))) // taur legs never ever render
		if(isnull(zone) || zone == body_zone)
			// Per limb, not per marking: its leg shape, the chest art a gendered marking draws on it, and the request both make.
			var/digitigrade = bodyshape & BODYSHAPE_DIGITIGRADE
			var/chest_gender = is_dimorphic ? limb_gender : "m"
			var/request = "[body_zone][digitigrade ? "_digitigrade" : ""][body_zone == BODY_ZONE_CHEST ? "_[chest_gender]" : ""]"
			for(var/datum/body_marking_entry/marking_entry as anything in markings) // Cycle through all of our currently selected markings.
				var/datum/body_marking/body_marking = marking_entry.marking
				if (!body_marking) // Edge case prevention.
					continue
				// FALSE where the marking has no art for this leg shape or its sheet lacks the state, as on a zone a save holds but
				// the marking no longer claims: nothing is drawn rather than the sheet's default state.
				var/marking_state = BODY_MARKING_DRAWN_STATE(body_marking, request, body_zone, digitigrade, chest_gender)
				if(!marking_state)
					continue
				var/mutable_appearance/accessory_overlay
				var/mutable_appearance/emissive
				accessory_overlay = mutable_appearance(body_marking.icon, marking_state, -BODYPARTS_LAYER)
				accessory_overlay.alpha = isnull(alpha_override) ? markings_alpha : alpha_override
				if(include_emissive && marking_entry.get_emissive())
					// The glow fades with the marking, as a limb's own glow follows the limb's alpha.
					emissive = emissive_appearance(accessory_overlay.icon, accessory_overlay.icon_state, offset_spokesman, offset_spokesman = offset_spokesman, layer = accessory_overlay.layer, alpha = accessory_overlay.alpha)
				if(override_color)
					accessory_overlay.color = override_color
				else
					accessory_overlay.color = marking_entry.get_color()
				// Only image() with a dir keeps an overlay's own facing, so a dropped limb's markings face south with it.
				output += image_dir ? image(accessory_overlay, dir = image_dir) : accessory_overlay
				if (emissive)
					output += image_dir ? image(emissive, dir = image_dir) : emissive

		if(aux_zone && (isnull(zone) || zone == aux_zone))
			for(var/datum/body_marking_entry/marking_entry as anything in aux_zone_markings)
				var/datum/body_marking/body_marking = marking_entry.marking
				if (!body_marking) // Edge case prevention.
					continue
				var/marking_state = BODY_MARKING_DRAWN_STATE(body_marking, aux_zone, aux_zone, FALSE, "m")
				if(!marking_state)
					continue
				var/mutable_appearance/emissive
				var/mutable_appearance/accessory_overlay
				accessory_overlay = mutable_appearance(body_marking.icon, marking_state, -aux_layer)
				accessory_overlay.alpha = isnull(alpha_override) ? markings_alpha : alpha_override
				if(include_emissive && marking_entry.get_emissive())
					emissive = emissive_appearance(accessory_overlay.icon, accessory_overlay.icon_state, offset_spokesman = offset_spokesman, layer = accessory_overlay.layer, alpha = accessory_overlay.alpha)
				if(override_color)
					accessory_overlay.color = override_color
				else
					accessory_overlay.color = marking_entry.get_color()
				output += image_dir ? image(accessory_overlay, dir = image_dir) : accessory_overlay
				if (emissive)
					output += image_dir ? image(emissive, dir = image_dir) : emissive
	return output
