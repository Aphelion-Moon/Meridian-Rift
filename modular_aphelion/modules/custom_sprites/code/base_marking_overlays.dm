/// Blended runs of body marking states by content key, bounded by custom_sprite_cache_put(). See merge_body_marking_run().
GLOBAL_LIST_EMPTY(merged_body_marking_icons)

/**
 * Appends this limb's native base markings before height and body textures are applied.
 *
 * The ordinary limb renderer passes its existing overlay list, preserving native layer order
 * without allocating another list. An editor may request one body or auxiliary zone, omit the
 * separate emissive appearances and replace the live marking opacity while sampling its pixels.
 * No body, custom paint or external-organ overlays are included. A marking draws only the state its
 * drawn_state() answers, and nothing where it has no art: see zone_icon_state().
 *
 * Consecutive markings of one colour on sheets of one size draw as one appearance, and a zone's glows on one sheet size as
 * one glow, each where its first marking was: see merge_body_marking_run(). Only at full opacity: translucent markings, and
 * the glows fading with them, darken where they overlap, which one blended layer cannot repeat (markings_copy.dm notes the
 * same), so a reduced markings_alpha draws them one by one. So does an editor's single-zone request, which samples them.
 *
 * Arguments:
 * - output: The caller-owned list of overlays to their flags to append to. Markings texture like the limb itself.
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
	var/marking_alpha = isnull(alpha_override) ? markings_alpha : alpha_override
	var/merge = marking_alpha == 255 && isnull(zone)
	// We need to check that the owner exists(could be a placed bodypart) and that it's not a chainsawhand and that they're a human with usable DNA.
	if(!(bodypart_flags & (BODYPART_PSEUDOPART | BODYPART_STUMP)) && (!(bodyshape & BODYSHAPE_TAUR))) // taur legs never ever render
		if(isnull(zone) || zone == body_zone)
			// Per limb, not per marking: its leg shape, the chest art a gendered marking draws on it, and the request both make.
			var/digitigrade = bodyshape & BODYSHAPE_DIGITIGRADE
			var/chest_gender = is_dimorphic ? limb_gender : "m"
			var/request = "[body_zone][digitigrade ? "_digitigrade" : ""][body_zone == BODY_ZONE_CHEST ? "_[chest_gender]" : ""]"
			// The open run of same-coloured markings and the zone's first glow, as drawn into output, and once another marking
			// joins either, the sheets and states it draws. Null while merging is off.
			var/image/run_first
			var/run_color
			var/list/run_parts
			var/image/glow_first
			var/list/glow_parts
			for(var/datum/body_marking_entry/marking_entry as anything in markings) // Cycle through all of our currently selected markings.
				var/datum/body_marking/body_marking = marking_entry.marking
				if (!body_marking) // Edge case prevention.
					continue
				// FALSE where the marking has no art for this leg shape or its sheet lacks the state, as on a zone a save holds but
				// the marking no longer claims: nothing is drawn rather than the sheet's default state.
				var/marking_state = BODY_MARKING_DRAWN_STATE(body_marking, request, body_zone, digitigrade, chest_gender)
				if(!marking_state)
					continue
				var/marking_color = override_color || marking_entry.get_color()
				// Drawn right on top of the run's markings in their colour, so blending it in first draws the same.
				if(run_first && marking_color == run_color && body_marking_sheets_blend(run_first.icon, body_marking.icon))
					run_parts ||= list(run_first.icon, run_first.icon_state)
					run_parts += body_marking.icon
					run_parts += marking_state
				else
					if(run_parts)
						merge_body_marking_run(run_first, run_parts)
						run_parts = null
					var/mutable_appearance/accessory_overlay = mutable_appearance(body_marking.icon, marking_state, -BODYPARTS_LAYER)
					accessory_overlay.alpha = marking_alpha
					accessory_overlay.color = marking_color
					// Only image() with a dir keeps an overlay's own facing, so a dropped limb's markings face south with it.
					var/image/drawn = image_dir ? image(accessory_overlay, dir = image_dir) : accessory_overlay
					output[drawn] = LIMB_OVERLAY_TEXTURED|LIMB_OVERLAY_CORE
					if(merge)
						run_first = drawn
						run_color = marking_color
				if(!include_emissive || !marking_entry.get_emissive())
					continue
				// Every glow draws in the one emissive colour, so glows of one sheet size blend alike in any order. One of another
				// size than the zone's first glow draws alone.
				if(glow_first && body_marking_sheets_blend(glow_first.icon, body_marking.icon))
					glow_parts ||= list(glow_first.icon, glow_first.icon_state)
					glow_parts += body_marking.icon
					glow_parts += marking_state
					continue
				// The glow fades with the marking, as a limb's own glow follows the limb's alpha.
				var/mutable_appearance/emissive = emissive_appearance(body_marking.icon, marking_state, offset_spokesman, layer = -BODYPARTS_LAYER, alpha = marking_alpha)
				var/image/drawn_glow = image_dir ? image(emissive, dir = image_dir) : emissive
				output[drawn_glow] = LIMB_OVERLAY_META
				if(merge && !glow_first)
					glow_first = drawn_glow
			if(run_parts)
				merge_body_marking_run(run_first, run_parts)
			if(glow_parts)
				merge_body_marking_run(glow_first, glow_parts)

		if(aux_zone && (isnull(zone) || zone == aux_zone))
			// As the body zone above, on the aux layer.
			var/image/run_first
			var/run_color
			var/list/run_parts
			var/image/glow_first
			var/list/glow_parts
			for(var/datum/body_marking_entry/marking_entry as anything in aux_zone_markings)
				var/datum/body_marking/body_marking = marking_entry.marking
				if (!body_marking) // Edge case prevention.
					continue
				var/marking_state = BODY_MARKING_DRAWN_STATE(body_marking, aux_zone, aux_zone, FALSE, "m")
				if(!marking_state)
					continue
				var/marking_color = override_color || marking_entry.get_color()
				if(run_first && marking_color == run_color && body_marking_sheets_blend(run_first.icon, body_marking.icon))
					run_parts ||= list(run_first.icon, run_first.icon_state)
					run_parts += body_marking.icon
					run_parts += marking_state
				else
					if(run_parts)
						merge_body_marking_run(run_first, run_parts)
						run_parts = null
					var/mutable_appearance/accessory_overlay = mutable_appearance(body_marking.icon, marking_state, -aux_layer)
					accessory_overlay.alpha = marking_alpha
					accessory_overlay.color = marking_color
					var/image/drawn = image_dir ? image(accessory_overlay, dir = image_dir) : accessory_overlay
					output[drawn] = LIMB_OVERLAY_TEXTURED|LIMB_OVERLAY_CORE
					if(merge)
						run_first = drawn
						run_color = marking_color
				if(!include_emissive || !marking_entry.get_emissive())
					continue
				if(glow_first && body_marking_sheets_blend(glow_first.icon, body_marking.icon))
					glow_parts ||= list(glow_first.icon, glow_first.icon_state)
					glow_parts += body_marking.icon
					glow_parts += marking_state
					continue
				var/mutable_appearance/emissive = emissive_appearance(body_marking.icon, marking_state, offset_spokesman, layer = -aux_layer, alpha = marking_alpha)
				var/image/drawn_glow = image_dir ? image(emissive, dir = image_dir) : emissive
				output[drawn_glow] = LIMB_OVERLAY_META
				if(merge && !glow_first)
					glow_first = drawn_glow
			if(run_parts)
				merge_body_marking_run(run_first, run_parts)
			if(glow_parts)
				merge_body_marking_run(glow_first, glow_parts)
	return output

/**
 * Returns the size of a body marking sheet as "[width]x[height]", read once per sheet. moth_markings.dmi is 45x34, every
 * other sheet 32x32. Null for an icon built at runtime, whose text names no file ("/icon" for every one), so a content key
 * could not tell two apart.
 *
 * Arguments:
 * - sheet: a body marking's icon.
 */
/proc/body_marking_sheet_size(sheet)
	var/static/list/sizes = list()
	. = sizes[sheet]
	if(. || !isfile(sheet) || !length("[sheet]"))
		return
	var/list/dimensions = get_icon_dimensions(sheet)
	. = "[dimensions["width"]]x[dimensions["height"]]"
	sizes[sheet] = .

/**
 * Returns whether markings on two sheets can blend into one icon: sheets of one size, and never an icon built at runtime.
 *
 * Arguments:
 * - sheet, other_sheet: two body markings' icons.
 */
/proc/body_marking_sheets_blend(sheet, other_sheet)
	var/size = body_marking_sheet_size(sheet)
	return size && size == body_marking_sheet_size(other_sheet)

/**
 * Draws a run of markings, or of glows, with its first appearance as drawn into the output list, a dropped limb's image of
 * it included: that appearance takes the run's blended icon and keeps its own colour, alpha, layer, plane, flags and
 * facing, so it draws what the run's appearances drew one on another.
 *
 * The blended icon holds the run's states blended uncoloured, in order, on a canvas of their sheets' size in all four
 * cardinals. Its key, the parts joined by "|", is colour-free, so every body drawing the same states shares it, in any
 * colour and husked or not. Built on a cache miss, into a bounded cache. The blend sits under a state named by the key
 * as well. An appearance reads its runtime icon back as empty text, and the leg split keys its masked halves by that
 * text and the appearance's state (handle_masking()), so only the state tells two runs apart there. The same content
 * keys keep custom paint's own leg split safe (appearance.dm).
 *
 * Arguments:
 * - first: the run's first appearance in the output list, built for this render.
 * - parts: the run's sheets and states, alternating, in drawing order. Its sheets share one size.
 */
/proc/merge_body_marking_run(image/first, list/parts)
	var/key = jointext(parts, "|")
	var/icon/merged = GLOB.merged_body_marking_icons[key]
	if(!merged)
		var/list/dimensions = get_icon_dimensions(parts[1])
		merged = custom_sprite_blank_icon(dimensions["width"], dimensions["height"])
		for(var/index in 1 to length(parts) step 2)
			merged.Blend(icon(parts[index], parts[index + 1]), ICON_OVERLAY)
		merged.Insert(icon(merged), key)
		custom_sprite_cache_put(GLOB.merged_body_marking_icons, key, merged)
	first.icon = merged
	first.icon_state = key
