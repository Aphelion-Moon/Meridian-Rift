#define COLOR_MODE_SPECIFIC "Specific Marking"
#define COLOR_MODE_GENERAL "General Color"

/obj/item/fur_dyer
	name = "electric fur dyer"
	desc = "Dye that is capable of recoloring fur in a mostly permanent way."
	icon = 'modular_nova/modules/salon/icons/items.dmi'
	icon_state = "fur_sprayer"
	w_class = WEIGHT_CLASS_TINY

	var/mode = COLOR_MODE_SPECIFIC

/obj/item/fur_dyer/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/cell)

/obj/item/fur_dyer/attack_self(mob/user, modifiers)
	. = ..()
	if(mode == COLOR_MODE_SPECIFIC)
		mode = COLOR_MODE_GENERAL
	else
		mode = COLOR_MODE_SPECIFIC

	balloon_alert(user, "set to [mode]!")

/obj/item/fur_dyer/attack(mob/living/M, mob/living/user, params)
	if(!ishuman(M))
		return ..()

	var/mob/living/carbon/human/target_human = M

	switch(mode)
		if(COLOR_MODE_SPECIFIC)
			dye_marking(target_human, user)
		if(COLOR_MODE_GENERAL)
			dye_general(target_human, user)

/obj/item/fur_dyer/proc/dye_general(mob/living/carbon/human/target_human, mob/living/user)
	var/selected_mutant_color = tgui_alert(user, "Please select which mutant color you'd like to change", "Select Color", list("One", "Two", "Three"))

	if(!selected_mutant_color)
		return

	if(!(item_use_power(power_use_amount, user, TRUE) & COMPONENT_POWER_SUCCESS))
		to_chat(user, span_danger("A red light blinks!"))
		return

	var/selected_color = tgui_color_picker(
			user,
			"Select marking color",
			null,
			COLOR_WHITE,
		)

	if(!selected_color)
		return

	selected_color = sanitize_hexcolor(selected_color)

	visible_message(span_notice("[user] starts to masterfully paint [target_human]!"))

	if(do_after(user, 20 SECONDS, target_human))
		switch(selected_mutant_color)
			if("One")
				target_human.dna.features[FEATURE_MUTANT_COLOR] = selected_color
			if("Two")
				target_human.dna.features[FEATURE_MUTANT_COLOR_TWO] = selected_color
			if("Three")
				target_human.dna.features[FEATURE_MUTANT_COLOR_THREE] = selected_color

		target_human.regenerate_icons()
		item_use_power(power_use_amount, user)

		visible_message(span_notice("[user] finishes painting [target_human]!"))

		playsound(src.loc, 'sound/effects/spray2.ogg', 50, TRUE)


/obj/item/fur_dyer/proc/dye_marking(mob/living/carbon/human/target_human, mob/living/user)

	var/datum/body_marking_collection/current_markings = target_human.dna.body_markings

	if(!current_markings.zone_count())
		to_chat(user, span_danger("[target_human] has no markings!"))
		return

	if(!(item_use_power(power_use_amount, user, TRUE) & COMPONENT_POWER_SUCCESS))
		to_chat(user, span_danger("A red light blinks!"))
		return

	var/selected_marking_area = user.zone_selected

	if(!current_markings.has_zone(selected_marking_area))
		to_chat(user, span_danger("[target_human] has no bodymarkings on this limb!"))
		return

	var/selected_marking_id = tgui_input_list(user, "Please select which marking you'd like to color!", "Select marking", current_markings.marking_names(selected_marking_area))

	if(!selected_marking_id)
		return

	var/selected_color = tgui_color_picker(
			user,
			"Select marking color",
			null,
			COLOR_WHITE,
		)

	if(!selected_color)
		return

	selected_color = sanitize_hexcolor(selected_color)

	visible_message(span_notice("[user] starts to masterfully paint [target_human]!"))

	if(do_after(user, 20 SECONDS, target_human))
		finish_marking_dye(target_human, selected_marking_area, selected_marking_id, selected_color)

		target_human.regenerate_icons()

		item_use_power(power_use_amount, user)

		visible_message(span_notice("[user] finishes painting [target_human]!"))

		playsound(src.loc, 'sound/effects/spray2.ogg', 50, TRUE)

/**
 * Recolours one marking on a body once its painting has finished.
 *
 * The marking is looked up among the body's markings as they are now, which may have changed while it was
 * being painted, and nothing is written when it is gone. The body's markings are its own, so the colour never
 * reaches its player's saved character.
 *
 * Arguments:
 * - target_human: the painted body.
 * - zone: the marking zone painted.
 * - marking_name: the name of the marking painted.
 * - color: the new colour.
 *
 * Returns:
 * - TRUE if the marking was recoloured. A locked marking takes no dye.
 */
/obj/item/fur_dyer/proc/finish_marking_dye(mob/living/carbon/human/target_human, zone, marking_name, color)
	return target_human.dna.body_markings.find_entry(zone, marking_name)?.set_color(color)

#undef COLOR_MODE_SPECIFIC
#undef COLOR_MODE_GENERAL
