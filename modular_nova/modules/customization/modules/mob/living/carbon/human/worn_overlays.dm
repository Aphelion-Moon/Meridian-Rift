/**
 * Setup the final version of accessory's overlay given custom species options.
 */
/obj/item/clothing/accessory/generate_accessory_overlay(obj/item/clothing/under/attached_to)
	if(!ishuman(attached_to.loc))
		return ..()

	var/mob/living/carbon/human/human_wearer = attached_to.loc
	// list[key] is null when absent, so this covers species with no custom accessory icon too
	var/icon/custom_accessory_icon = human_wearer.dna.species.custom_worn_icons[LOADOUT_ITEM_ACCESSORY]
	var/icon_state_to_check_for = icon_state_is_worn ? icon_state : worn_icon_state
	var/use_custom_icon = custom_accessory_icon && (icon_state_to_check_for in icon_states(custom_accessory_icon))

	var/mutable_appearance/appearance
	if(use_custom_icon)
		var/prev_worn_icon = worn_icon
		// Make new appearance so we don't break the real accessory overlay for other species, and treat it as final.
		worn_icon = custom_accessory_icon
		appearance = ..()
		worn_icon = prev_worn_icon // put it back how it was, so we don't break anything for whoever wears this next
	else
		appearance = ..()
		// Only apply the offset to the fallback sprite. it's drawn for a default human torso.
		// Species-specific sprites are already fitted and need no correction.
		var/obj/item/bodypart/chest/my_chest = human_wearer.get_bodypart(BODY_ZONE_CHEST)
		my_chest?.worn_accessory_offset?.apply_offset(appearance)

	return appearance

/**
 * Called before drawing an item. Gives it the offset that its blood and rips, drawn for a human body, need to land on a
 * sprite shaped to this body's species. Clears the offset for any other sprite, which the worn offsets already place,
 * and for an item with no blood or rips to place.
 *
 * * worn_item - the item about to be drawn
 * * species_icon - the sheet the species gave for it (generate_custom_worn_icon()), or null when it's drawn from a human one
 * * loadout_slot - one of LOADOUT_ITEM_*, the slot the species shaped it for
 * * zone - the body zone holding the offset
 * * offset_key - one of OFFSET_*, the zone's offset to take
 * * vertical_only - take only the offset's height, for an item drawn over both sides of the body, as gloves are
 */
/mob/living/carbon/human/proc/fit_worn_effects(obj/item/worn_item, species_icon, loadout_slot, zone, offset_key, vertical_only = FALSE)
	worn_item.worn_effect_offset = null
	var/obj/item/clothing/garment = worn_item
	if(!species_icon || !isclothing(garment) || !(garment.damaged_clothes || GET_ATOM_BLOOD_DNA_LENGTH(garment)))
		return
	var/obj/item/bodypart/part = get_bodypart(zone)
	var/datum/worn_feature_offset/offset = LAZYACCESS(part?.feature_offsets, offset_key)
	if(!offset)
		return
	var/list/moved
	// The species' own sheets follow its body in each direction. One it builds from a human sheet, as a Teshari's snouted
	// hats moved by the south offset, sits at that offset in all of them, as everything does under a one-direction offset.
	if((length(offset.offset_x) > 1 || length(offset.offset_y) > 1) && species_icon == dna.species.get_custom_worn_icon(loadout_slot, worn_item))
		moved = offset.get_offset()
	else
		moved = list("x" = offset.offset_x["south"] || 0, "y" = offset.offset_y["south"] || 0)
	if(vertical_only)
		moved["x"] = 0
	worn_item.worn_effect_offset = moved
