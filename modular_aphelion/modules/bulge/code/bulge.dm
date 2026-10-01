/// Bulge shading states are "<semi|tent>_<1-4>"; each has a "_fabric" twin for the cloth pushed out past the body.
#define BULGE_ICON 'modular_aphelion/modules/bulge/icons/bulge.dmi'
/// Drawn over the uniform, beneath everything worn on top of it.
#define BULGE_FABRIC_LAYER (UNIFORM_LAYER - 0.05)
#define BULGE_SHADE_LAYER (UNIFORM_LAYER - 0.06)

/**
 * The bulge a covered penis shows through the clothes, as a bulge sheet state, or null for none.
 *
 * Half hard it's a soft bulge ("semi"), fully hard a tent; its size follows the penis's length. A suit over the groin
 * hides it, and taur bodies don't draw one.
 */
/mob/living/carbon/human/proc/get_bulge_look()
	if(!has_bulge() || (wear_suit?.body_parts_covered & GROIN))
		return null
	var/obj/item/organ/genital/penis/penis = get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = penis.bodypart_overlay
	var/datum/sprite_accessory/genital/penis_style = penis_overlay?.sprite_datum
	if(penis_style?.uses_taur_sprite(src))
		return null
	var/size = 4
	if(penis.genital_size < 5)
		size = 1
	else if(penis.genital_size < 8)
		size = 2
	else if(penis.genital_size < 11)
		size = 3
	return "[penis.aroused == AROUSAL_FULL ? "tent" : "semi"]_[size]"

/// The bulge as drawn: the pushed-out cloth in the garment's colour, and its shading over it.
/mob/living/carbon/human/proc/get_bulge_appearances(look)
	var/mutable_appearance/cloth = mutable_appearance(BULGE_ICON, "[look]_fabric", layer = -BULGE_FABRIC_LAYER)
	cloth.color = get_groin_fabric_colour()
	return list(cloth, mutable_appearance(BULGE_ICON, look, layer = -BULGE_SHADE_LAYER))

/// The colour of the cloth over the groin: the uniform, else a groin-length undershirt, else the underwear.
/mob/living/carbon/human/proc/get_groin_fabric_colour()
	if(w_uniform?.body_parts_covered & GROIN)
		return sample_fabric_colour(w_uniform.worn_icon || DEFAULT_UNIFORM_FILE, w_uniform.worn_icon_state || w_uniform.icon_state, istext(w_uniform.color) ? w_uniform.color : null)
	var/datum/sprite_accessory/clothing/undershirt/shirt = SSaccessories.undershirt_list[undershirt]
	if(shirt?.hides_groin && !(underwear_visibility & UNDERWEAR_HIDE_SHIRT))
		return sample_fabric_colour(shirt.icon, shirt.icon_state, shirt.use_static ? null : undershirt_color)
	var/datum/sprite_accessory/clothing/underwear/briefs = SSaccessories.underwear_list[underwear]
	if(briefs)
		return sample_fabric_colour(briefs.icon, briefs.icon_state, briefs.use_static ? null : underwear_color)
	return "#808080"

/**
 * The commonest colour on a worn sprite's crotch, tinted by `tint`, read once per sprite and tint.
 *
 * It looks at the rows just above where the legs part on our bodies, facing south.
 */
/proc/sample_fabric_colour(file, state, tint)
	var/static/list/sampled = list()
	var/key = "[file]|[state]|[tint]"
	. = sampled[key]
	if(.)
		return
	. = tint || "#808080"
	if(icon_exists(file, state))
		var/icon/sprite = icon(file, state, SOUTH, 1)
		var/list/counts = list()
		// GetPixel counts rows from the bottom: rows 21 to 23 from the top, columns 13 to 17.
		for(var/y in 9 to 11)
			for(var/x in 14 to 18)
				var/pixel = sprite.GetPixel(x, y)
				if(pixel)
					counts[copytext(pixel, 1, 8)] += 1
		var/best_count = 0
		for(var/colour, count in counts)
			if(count > best_count)
				best_count = count
				. = colour
		if(best_count && tint)
			var/list/base = rgb2num(.)
			var/list/by = rgb2num(tint)
			. = rgb(round(base[1] * by[1] / 255, 1), round(base[2] * by[2] / 255, 1), round(base[3] * by[3] / 255, 1))
	sampled[key] = .

// The penis's own overlay draws its bulge while the penis is covered, so it updates with arousal and clothing.

/datum/bodypart_overlay/mutant/genital/penis/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	. = ..()
	if(.)
		return
	var/mob/living/carbon/human/human_owner = owner || bodypart_owner.owner
	return istype(human_owner) && !isnull(human_owner.get_bulge_look())

/datum/bodypart_overlay/mutant/genital/penis/icon_render_key(obj/item/bodypart/limb)
	. = ..()
	var/mob/living/carbon/human/human_owner = limb?.owner
	var/look = istype(human_owner) ? human_owner.get_bulge_look() : null
	if(look)
		. += "bulge=[look]:[human_owner.get_groin_fabric_colour()]"

/datum/bodypart_overlay/mutant/genital/penis/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	var/mob/living/carbon/human/human_owner = limb?.owner
	var/look = istype(human_owner) ? human_owner.get_bulge_look() : null
	if(!look)
		return ..()
	if(layer_index != EXTERNAL_FRONT_UNDER_CLOTHES)
		return list()
	return human_owner.get_bulge_appearances(look)

#undef BULGE_ICON
#undef BULGE_FABRIC_LAYER
#undef BULGE_SHADE_LAYER
