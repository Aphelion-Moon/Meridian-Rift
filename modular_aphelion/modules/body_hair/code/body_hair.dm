// Armpit and pubic hair. Each is a mutant bodypart like a tail or genitals: the choice lives in
// dna.mutant_bodyparts, species regeneration grows the matching organ, and the organ's overlay draws the hair.

/datum/sprite_accessory/body_hair
	icon = 'modular_aphelion/modules/body_hair/icons/body_hair.dmi'
	color_src = USE_ONE_COLOR

/// Hidden while anything covers it: see get_body_hair_cover().
/datum/sprite_accessory/body_hair/is_hidden(mob/living/carbon/human/owner, datum/bodypart_overlay/mutant/bodypart_overlay)
	return !isnull(owner.get_body_hair_cover(key))

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

/// Draws the hair as "<style>_<m|f>" over the skin and under underwear and clothes. Only what bares it is ever drawn over it: anything else hides it.
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
	. = list()
	.[hair] = overlay_flags // Textured with the skin under it, as every mutant part is by default.

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

// Pubic hair under a baring underwear keeps only its pixels on bare skin (pubic_hair_clip()); the cache key follows what it's
// clipped to, so the chest is drawn again when the underwear, the legs or a muscle size changes.
/datum/bodypart_overlay/mutant/body_hair/pubes/icon_render_key(obj/item/bodypart/limb)
	. = ..()
	var/list/parts = pubic_hair_clip(limb)
	if(parts)
		. += parts[1]

/datum/bodypart_overlay/mutant/body_hair/pubes/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	. = ..()
	var/list/parts = pubic_hair_clip(limb)
	if(!parts)
		return
	var/clipped = clip_pubic_hair(sprite_datum.icon, "[sprite_datum.icon_state]_[limb.limb_gender || "m"]", parts)
	for(var/mutable_appearance/hair as anything in .)
		hair.icon = clipped
		hair.icon_state = ""

/**
 * Returns what this pubic hair is clipped to on `limb`'s owner, while a baring underwear (GLOB.body_hair_baring_clothing) is
 * worn and drawn over it, its only cover (Pol, 2026-10-14: "on the body, outside the underwear"). The hair is drawn past the
 * crotch's outline to frame the genitals: over a bare groin that's as drawn, and under such underwear it would float in the
 * air or show through the underwear's gaps.
 *
 * Arguments:
 * - limb: The chest the hair is drawn on.
 *
 * Returns:
 * - A list: the clip's key first; the underwear, then its state, female cut and whether the GAGS digitigrade mask draws its
 *   legs, all as make_appearance() draws it before any fitting; then the sheet and state the chest, right leg and left leg
 *   each draw their own sprite from (/obj/item/bodypart/proc/drawn_sheet()), both null for a part that draws none, like a taur's
 *   legs.
 * - null: The hair isn't clipped. Nothing it's drawn under covers the groin, or the hair is on no one.
 */
/datum/bodypart_overlay/mutant/body_hair/pubes/proc/pubic_hair_clip(obj/item/bodypart/limb)
	var/mob/living/carbon/human/owner = limb?.owner
	if(!ishuman(owner) || owner.underwear == "Nude" || (owner.underwear_visibility & UNDERWEAR_HIDE_UNDIES))
		return null
	if(HAS_TRAIT(owner, TRAIT_HUSK) || HAS_TRAIT(owner, TRAIT_INVISIBLE_MAN) || HAS_TRAIT(owner, TRAIT_NO_UNDERWEAR))
		return null
	var/datum/sprite_accessory/clothing/underwear/pants = SSaccessories.underwear_list[owner.underwear]
	if(!pants || !GLOB.body_hair_baring_clothing[pants.type])
		return null
	// As the underwear's make_appearance() draws it.
	var/shape = owner.bodyshape
	if(isvoxprimalis(owner))
		shape |= BODYSHAPE_DIGITIGRADE
	var/digi = pants.digi_icon_state && (shape & BODYSHAPE_DIGITIGRADE)
	var/cut = owner.physique == FEMALE ? pants.female_sprite_flags : NONE
	if(cut && (digi || (shape & (BODYSHAPE_TAUR|BODYSHAPE_CERULEAN))))
		cut = FEMALE_UNIFORM_TOP_ONLY
	cut = female_cut_over_pecs(owner, cut)
	var/state = pants.get_icon_state(owner.physique, shape, owner)
	var/list/body = list()
	for(var/zone in list(BODY_ZONE_CHEST, BODY_ZONE_R_LEG, BODY_ZONE_L_LEG))
		var/obj/item/bodypart/part = zone == BODY_ZONE_CHEST ? limb : owner.get_bodypart(zone)
		var/sheet = part?.drawn_sheet()
		body += list(sheet, sheet ? custom_sprite_limb_state(part) : null)
	return list("[pants.type]|[state]|[cut]|[!!digi]|[jointext(body, "|")]", pants, state, cut, !!digi) + body

/**
 * Returns the sheet this limb's own sprite is drawn from, as get_limb_icon() draws it, or null when it draws none of its own:
 * a stump, an invisible limb, or a taur's legs, which its taur body stands in for.
 */
/obj/item/bodypart/proc/drawn_sheet()
	if(IS_STUMP(src) || is_invisible || is_actually_just_invisible)
		return null
	return custom_sprite_icon_file()

/**
 * Returns pubic hair clipped to the bare skin under a baring underwear: each of its pixels is kept only where the body is drawn,
 * the chest and legs, and outside the underwear's span in its row, from the underwear's leftmost pixel there to its rightmost,
 * each direction on its own (hairclip.py, rule "on the body, outside the underwear"). The hair's colour is the overlay's, so
 * it's left out: made once a round for each hair state, underwear sprite and body, a cached resource.
 *
 * All of it is icon operations on the four directions at once. A row's span is the pixels with underwear at or left of them,
 * and at or right of them: each found by spreading the underwear's pixels right, or left, by 1, 2, 4, 8 and 16.
 *
 * Arguments:
 * - hair_icon, icon_state: The hair's sheet and state.
 * - parts: What it's clipped to, from /datum/bodypart_overlay/mutant/body_hair/pubes/proc/pubic_hair_clip().
 */
/proc/clip_pubic_hair(hair_icon, icon_state, list/parts)
	var/static/alist/clipped
	var/key = "[hair_icon]|[icon_state]|[parts[1]]"
	. = clipped?[key]
	if(.)
		return
	var/datum/sprite_accessory/clothing/underwear/pants = parts[2]
	var/state = parts[3]
	var/cut = parts[4]
	// The underwear's pixels, then its span in each row, opaque white.
	var/sheet = pants.greyscale_config ? SSgreyscale.GetColoredIconByType(pants.greyscale_config, pants.greyscale_colors) : pants.icon
	var/icon/left = cut ? wear_female_version(state, sheet, pants.icon, cut) : icon(sheet, state)
	if(parts[5])
		left = apply_icon_mask(left, LEGS_MASK, icon(SSgreyscale.GetColoredIconByType(/datum/greyscale_config/digitigrade_underwear, pants.greyscale_colors), pants.digi_icon_state))
	left.MapColors(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0)
	var/icon/right = icon(left)
	for(var/distance in list(1, 2, 4, 8, 16))
		var/icon/spread = icon(left)
		spread.Shift(EAST, distance)
		left.Blend(spread, ICON_OVERLAY)
		spread = icon(right)
		spread.Shift(WEST, distance)
		right.Blend(spread, ICON_OVERLAY)
	left.Blend(right, ICON_MULTIPLY)
	// Everything outside the span.
	left.MapColors(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1, 1, 1, 1)
	// The body: the chest, then each leg that draws its own sprite.
	var/icon/body = icon(parts[6], parts[7])
	for(var/index in list(8, 10))
		if(parts[index])
			body.Blend(icon(parts[index], parts[index + 1]), ICON_OVERLAY)
	body.MapColors(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0)
	body.Blend(left, ICON_MULTIPLY)
	var/icon/hair = icon(hair_icon, icon_state)
	hair.Blend(body, ICON_MULTIPLY)
	. = fcopy_rsc(hair)
	clipped ||= alist()
	clipped[key] = .

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

/**
 * Returns what hides this body hair, or null when it shows. Armpit hair shows on a bare chest and under clothing that bares
 * the armpits (GLOB.body_hair_baring_clothing); no bra or underwear hides it. Pubic hair shows on a bare groin and under
 * underwear that bares it. Drawing asks on every body update (is_hidden()), so this allocates nothing.
 *
 * Arguments:
 * - feature: FEATURE_PITS or FEATURE_PUBES.
 *
 * Returns:
 * - The suit or uniform over the hair, the undershirt or underwear accessory worn over it, or null.
 */
/mob/living/carbon/human/proc/get_body_hair_cover(feature)
	var/pubes = feature == FEATURE_PUBES
	var/zone = pubes ? GROIN : CHEST
	var/list/baring = GLOB.body_hair_baring_clothing
	// Clothing only ever bares the armpits.
	if((wear_suit?.body_parts_covered & zone) && (pubes || !baring[wear_suit.type]))
		return wear_suit
	if((w_uniform?.body_parts_covered & zone) && (pubes || !baring[w_uniform.type]))
		return w_uniform
	if(undershirt != "Nude" && !(underwear_visibility & UNDERWEAR_HIDE_SHIRT))
		var/datum/sprite_accessory/clothing/undershirt/shirt = SSaccessories.undershirt_list[undershirt]
		if(shirt && (pubes ? shirt.hides_groin : !baring[shirt.type]))
			return shirt
	if(pubes && underwear != "Nude" && !(underwear_visibility & UNDERWEAR_HIDE_UNDIES))
		var/datum/sprite_accessory/clothing/underwear/pants = SSaccessories.underwear_list[underwear]
		if(pants && !baring[pants.type])
			return pants
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
		// Underclothes are accessories, not items: name them as the wearer's.
		if(istype(covering, /datum/sprite_accessory))
			covering = "[target.p_their()] [istype(covering, /datum/sprite_accessory/clothing/undershirt) ? "undershirt" : "underwear"]"
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
