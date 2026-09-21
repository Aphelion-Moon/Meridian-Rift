/datum/action/item_action/organ_action/toggle/toolkit/uplink
	name = "Engineering Toolkit"
	desc = "Select one of six integrated tools. The right hand must be empty; drop retracts a tool."

/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink
	name = "Uplink engineering toolkit"
	actions_types = list(/datum/action/item_action/organ_action/toggle/toolkit/uplink)
	custom_materials = null
	var/datum/uplink_registry/registry

/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/proc/authorized(datum/ai_shell_session/session)
	if(!owner || !hand || (organ_flags & ORGAN_FAILING) || owner.stat || HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED))
		return FALSE
	if(!session?.matches() || session.endpoint != owner || !session.brain || session.core.shell_control_denial(owner))
		return FALSE
	var/mob/living/carbon/human/uplink/body = owner
	return istype(body) && registry?.authorize(body, session.brain, session.core)

/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/ui_action_click()
	if(active_item && active_item.loc != src)
		Retract()
		return
	var/datum/ai_shell_session/session = owner?.ai_shell_session
	if(!authorized(session))
		to_chat(owner, span_warning("Toolkit unavailable: a functional arm and current authorized Uplink controller are required."))
		return
	var/list/choices = list()
	for(var/datum/weakref/tool_ref as anything in items_list)
		var/obj/item/tool = tool_ref.resolve()
		if(tool)
			choices[tool] = image(tool)
	var/obj/item/chosen = show_radial_menu(owner, owner, choices)
	if(owner != usr || !authorized(session) || active_item || !(chosen in contents))
		return
	Extend(chosen)

/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/Extend(obj/item/tool)
	if(!authorized(owner?.ai_shell_session))
		return
	if(!owner.get_empty_held_index_for_side(RIGHT_HANDS))
		to_chat(owner, span_warning("Empty your right hand before extending a tool."))
		return
	return ..()

/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/Retract()
	if(istype(active_item, /obj/item/weldingtool))
		var/obj/item/weldingtool/welder = active_item
		welder.set_welding(FALSE)
	return ..()

/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/on_limb_detached(obj/item/bodypart/source)
	if(source == hand)
		Retract()
	return ..()

/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE
