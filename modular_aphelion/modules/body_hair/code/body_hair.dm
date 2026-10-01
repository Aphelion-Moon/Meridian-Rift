// Armpit and pubic hair. Each is a mutant bodypart like a tail or genitals: the choice lives in
// dna.mutant_bodyparts, species regeneration grows the matching organ, and the organ's overlay draws the hair.

/datum/sprite_accessory/body_hair
	icon = 'modular_aphelion/modules/body_hair/icons/body_hair.dmi'
	color_src = USE_ONE_COLOR

/datum/sprite_accessory/body_hair/pits
	key = FEATURE_PITS
	organ_type = /obj/item/organ/body_hair/pits

/datum/sprite_accessory/body_hair/pits/none
	name = SPRITE_ACCESSORY_NONE
	icon_state = "none"
	factual = FALSE

/datum/sprite_accessory/body_hair/pits/trimmed
	name = "Trimmed"
	icon_state = "pits_trimmed"

/datum/sprite_accessory/body_hair/pits/natural
	name = "Natural"
	icon_state = "pits_natural"

/datum/sprite_accessory/body_hair/pits/untamed
	name = "Untamed"
	icon_state = "pits_untamed"

/datum/sprite_accessory/body_hair/pubes
	key = FEATURE_PUBES
	organ_type = /obj/item/organ/body_hair/pubes

/datum/sprite_accessory/body_hair/pubes/none
	name = SPRITE_ACCESSORY_NONE
	icon_state = "none"
	factual = FALSE

/datum/sprite_accessory/body_hair/pubes/trimmed
	name = "Trimmed"
	icon_state = "pubes_trimmed"

/datum/sprite_accessory/body_hair/pubes/natural
	name = "Natural"
	icon_state = "pubes_natural"

/datum/sprite_accessory/body_hair/pubes/untamed
	name = "Untamed"
	icon_state = "pubes_untamed"

/datum/sprite_accessory/body_hair/pubes/landing_strip
	name = "Landing Strip"
	icon_state = "pubes_strip"

/datum/sprite_accessory/body_hair/pubes/heart
	name = "Heart"
	icon_state = "pubes_heart"

/datum/sprite_accessory/body_hair/pubes/arrow
	name = "Arrow"
	icon_state = "pubes_arrow"

/obj/item/organ/body_hair
	name = "body hair"
	desc = "Hair, from somewhere other than the head."
	organ_flags = ORGAN_UNREMOVABLE | ORGAN_HIDDEN | ORGAN_EXTERNAL

/obj/item/organ/body_hair/pits
	name = "armpit hair"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_EXTERNAL_PITS
	mutantpart_key = FEATURE_PITS
	bodypart_overlay = /datum/bodypart_overlay/mutant/body_hair/pits

/obj/item/organ/body_hair/pubes
	name = "pubic hair"
	zone = BODY_ZONE_PRECISE_GROIN
	slot = ORGAN_SLOT_EXTERNAL_PUBES
	mutantpart_key = FEATURE_PUBES
	bodypart_overlay = /datum/bodypart_overlay/mutant/body_hair/pubes

/// Draws the hair as "<style>_<m|f>" over the skin and under underwear and clothes, which cover it where they overlap.
/datum/bodypart_overlay/mutant/body_hair
	layers = list(EXTERNAL_FRONT = BODY_HAIR_LAYER)
	color_source = ORGAN_COLOR_OVERRIDE
	offset_location = ENTIRE_BODY

/datum/bodypart_overlay/mutant/body_hair/pits
	feature_key = FEATURE_PITS

/datum/bodypart_overlay/mutant/body_hair/pubes
	feature_key = FEATURE_PUBES

/datum/bodypart_overlay/mutant/body_hair/override_color(rgb_value)
	return draw_color

/datum/bodypart_overlay/mutant/body_hair/get_global_feature_list()
	return SSaccessories.sprite_accessories[feature_key]

/datum/bodypart_overlay/mutant/body_hair/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	var/mutable_appearance/hair = mutable_appearance(sprite_datum.icon, "[sprite_datum.icon_state]_[limb?.limb_gender || "m"]", layer = layer_real)
	hair.color = get_hair_colour(limb)
	return list(hair)

/datum/bodypart_overlay/mutant/body_hair/icon_render_key(obj/item/bodypart/limb)
	return list(feature_key, sprite_datum.icon_state, limb?.limb_gender, get_hair_colour(limb))

/// The hair's own colour, or the head hair's when the owner set it to match.
/datum/bodypart_overlay/mutant/body_hair/proc/get_hair_colour(obj/item/bodypart/limb)
	var/own = islist(draw_color) ? draw_color[1] : draw_color
	var/mob/living/carbon/human/owner = limb?.owner
	if(!istype(owner) || !owner.dna?.features[FEATURE_BODY_HAIR_MATCHES_HAIR])
		return own
	var/obj/item/bodypart/head/head = owner.get_bodypart(BODY_ZONE_HEAD)
	return head?.get_rendered_hair_color() || own

/// Sets this human's armpit or pubic hair to `style`, growing, restyling or removing the organ to match.
/mob/living/carbon/human/proc/set_body_hair(feature, style)
	var/datum/mutant_bodypart/part = dna.mutant_bodyparts[feature]
	if(part)
		part.name = style
	else
		dna.mutant_bodyparts[feature] = build_mutant_part(style, list(BODY_HAIR_DEFAULT_COLOR, BODY_HAIR_DEFAULT_COLOR, BODY_HAIR_DEFAULT_COLOR))
	var/datum/sprite_accessory/accessory = SSaccessories.sprite_accessories[feature]?[style]
	var/obj/item/organ/body_hair/hair = get_organ_slot(feature == FEATURE_PUBES ? ORGAN_SLOT_EXTERNAL_PUBES : ORGAN_SLOT_EXTERNAL_PITS)
	if(!accessory?.factual)
		if(hair)
			hair.Remove(src, special = TRUE)
			qdel(hair)
	else if(hair)
		var/datum/bodypart_overlay/mutant/body_hair/overlay = hair.bodypart_overlay
		overlay.set_appearance_from_name(style)
	else
		hair = new accessory.organ_type()
		hair.build_from_dna(dna, feature)
		hair.Insert(src, special = TRUE)
	update_body_parts()

/// This human's armpit or pubic hair style, "None" when there is none.
/mob/living/carbon/human/proc/get_body_hair(feature)
	var/datum/mutant_bodypart/part = dna.mutant_bodyparts[feature]
	return part?.name || SPRITE_ACCESSORY_NONE

/// What keeps a razor off this body hair: clothing or underwear over it, or null when it's bare.
/mob/living/carbon/human/proc/get_body_hair_cover(feature)
	var/zone = feature == FEATURE_PUBES ? GROIN : CHEST
	if(wear_suit?.body_parts_covered & zone)
		return wear_suit
	if(w_uniform?.body_parts_covered & zone)
		return w_uniform
	if(feature == FEATURE_PUBES)
		if(underwear != "Nude" && !(underwear_visibility & UNDERWEAR_HIDE_UNDIES))
			return "[p_their()] underwear"
	else if(undershirt != "Nude" && !(underwear_visibility & UNDERWEAR_HIDE_SHIRT))
		return "[p_their()] undershirt"
	return null

/**
 * Trims armpit or pubic hair to a picked style, or shaves it off, the way it does a beard.
 *
 * Called by the razor for the chest and groin. Grooming someone else's pubic hair needs their ERP preference.
 */
/obj/item/razor/proc/groom_body_hair(mob/living/user, mob/living/carbon/human/target, location)
	var/feature = location == BODY_ZONE_PRECISE_GROIN ? FEATURE_PUBES : FEATURE_PITS
	var/hair_name = feature == FEATURE_PUBES ? "pubic hair" : "armpit hair"
	if(feature == FEATURE_PUBES && target != user)
		var/datum/client_interface/target_client = GET_CLIENT(target)
		if(!target_client?.prefs?.read_preference(/datum/preference/toggle/erp))
			to_chat(user, span_warning("You'd rather not take a razor to [target] there."))
			return
	var/covering = target.get_body_hair_cover(feature)
	if(covering)
		to_chat(user, span_warning("[covering] is in the way!"))
		return
	var/list/choices = list("Shave it all off" = SPRITE_ACCESSORY_NONE)
	for(var/style in SSaccessories.sprite_accessories[feature])
		if(style != SPRITE_ACCESSORY_NONE)
			choices[style] = style
	var/choice = tgui_input_list(user, "Groom [target == user ? "your" : "[target]'s"] [hair_name] to:", "Grooming", choices)
	if(isnull(choice) || !user.can_perform_action(src, FORBID_TELEKINESIS_REACH) || !user.Adjacent(target))
		return
	var/style = choices[choice]
	if(target.get_body_hair(feature) == style)
		to_chat(user, span_notice("It's already like that."))
		return
	var/self_grooming = target == user
	to_chat(user, span_notice("You start on [self_grooming ? "your" : "[target]'s"] [hair_name] with [src]..."))
	if(!self_grooming)
		to_chat(target, span_notice("[user] starts on your [hair_name] with [src]."))
	playsound(src, 'sound/items/hair-clippers.ogg', 40, TRUE)
	if(!do_after(user, shaving_time, target = target) || target.get_body_hair_cover(feature))
		return
	target.set_body_hair(feature, style)
	var/done = style == SPRITE_ACCESSORY_NONE ? "shave off" : "trim"
	to_chat(user, span_notice("You [done] [self_grooming ? "your" : "[target]'s"] [hair_name][style == SPRITE_ACCESSORY_NONE ? "" : " to [LOWER_TEXT(style)]"]."))
	if(!self_grooming)
		to_chat(target, span_notice("[user] [done]s your [hair_name][style == SPRITE_ACCESSORY_NONE ? "" : " to [LOWER_TEXT(style)]"]."))
