/**
 * Appends this limb's native base markings before height and body textures are applied.
 *
 * The ordinary limb renderer passes its existing overlay list, preserving native layer order
 * without allocating another list. An editor may request one body or auxiliary zone, omit the
 * separate emissive appearances and replace the live marking opacity while sampling its pixels.
 * No body, custom paint or external-organ overlays are included.
 *
 * Arguments:
 * - output: The caller-owned overlay list to append to.
 * - zone: A body or auxiliary zone to include, or null for both in native order.
 * - include_emissive: Whether native emissive appearances accompany the visible markings.
 * - alpha_override: An explicit visible marking opacity, or null to use markings_alpha.
 *
 * Returns the same output list.
 */
/obj/item/bodypart/proc/append_base_marking_overlays(list/output, zone = null, include_emissive = TRUE, alpha_override = null)
	var/override_color
	var/atom/offset_spokesman = owner || src
	// First, check to see if this bodypart is husked. If so, we don't want to apply our sparkledog colors to the limb.
	if(is_husked)
		override_color = "#888888"
	// We need to check that the owner exists(could be a placed bodypart) and that it's not a chainsawhand and that they're a human with usable DNA.
	if(!(bodypart_flags & (BODYPART_PSEUDOPART | BODYPART_STUMP)) && (!(bodyshape & BODYSHAPE_TAUR))) // taur legs never ever render
		if(isnull(zone) || zone == body_zone)
			for(var/datum/body_marking_entry/marking_entry as anything in markings) // Cycle through all of our currently selected markings.
				var/datum/body_marking/body_marking = marking_entry.marking
				if (!body_marking) // Edge case prevention.
					continue

				var/gender_modifier = ""
				if(body_zone == BODY_ZONE_CHEST) // Chest markings have male and female versions.
					if(body_marking.gendered)
						gender_modifier = is_dimorphic ? "_[limb_gender]" : "_m"
				var/digi_modifier = ""
				if(bodyshape & BODYSHAPE_DIGITIGRADE)
					digi_modifier = "digitigrade_"
				var/mutable_appearance/accessory_overlay
				var/mutable_appearance/emissive
				accessory_overlay = mutable_appearance(body_marking.icon, "[body_marking.icon_state]_[digi_modifier][body_zone][gender_modifier]", -BODYPARTS_LAYER)
				accessory_overlay.alpha = isnull(alpha_override) ? markings_alpha : alpha_override
				if(include_emissive && marking_entry.get_emissive())
					emissive = emissive_appearance(accessory_overlay.icon, accessory_overlay.icon_state, offset_spokesman, offset_spokesman = offset_spokesman, layer = accessory_overlay.layer)
				if(override_color)
					accessory_overlay.color = override_color
				else
					accessory_overlay.color = marking_entry.get_color()
				output += accessory_overlay
				if (emissive)
					output += emissive

		if(aux_zone && (isnull(zone) || zone == aux_zone))
			for(var/datum/body_marking_entry/marking_entry as anything in aux_zone_markings)
				var/datum/body_marking/body_marking = marking_entry.marking
				if (!body_marking) // Edge case prevention.
					continue

				var/render_limb_string = aux_zone

				var/mutable_appearance/emissive
				var/mutable_appearance/accessory_overlay
				accessory_overlay = mutable_appearance(body_marking.icon, "[body_marking.icon_state]_[render_limb_string]", -aux_layer)
				accessory_overlay.alpha = isnull(alpha_override) ? markings_alpha : alpha_override
				if(include_emissive && marking_entry.get_emissive())
					emissive = emissive_appearance(accessory_overlay.icon, accessory_overlay.icon_state, offset_spokesman = offset_spokesman, layer = accessory_overlay.layer)
				if(override_color)
					accessory_overlay.color = override_color
				else
					accessory_overlay.color = marking_entry.get_color()
				output += accessory_overlay
				if (emissive)
					output += emissive
	return output
