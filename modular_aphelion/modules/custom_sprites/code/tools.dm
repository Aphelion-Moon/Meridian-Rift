/**
 * Offers new custom work or restoration of the previous round style, then starts the request. Sleeps.
 *
 * Arguments:
 * - tool: The scissors or tattoo machine in the artist's hand.
 * - target: "hair", "facial_hair" or "markings". Markings cover the whole body.
 */
/proc/custom_sprite_salon_tool_menu(obj/item/tool, mob/living/carbon/human/artist, mob/living/carbon/human/recipient, target)
	var/label = custom_sprite_salon_label(target)
	var/problem = custom_sprite_salon_start_problem(tool, artist, recipient, target)
	if(problem)
		to_chat(artist, span_warning(problem))
		return
	var/choice = "Draw"
	if(length(custom_sprite_salon_previous(recipient, target)))
		choice = tgui_alert(artist, "Draw a new custom [label] for [recipient], or restore the [label] they had before their last change?", "Custom [label]", list("Draw", "Restore previous", "Cancel"))
	switch(choice)
		if("Draw")
			custom_sprite_salon_request(tool, artist, recipient, target)
		if("Restore previous")
			custom_sprite_salon_request_restore(tool, artist, recipient, target)

/obj/item/scissors/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	custom_sprite_salon_resume(src, user)
	return TRUE

/obj/item/tattoo_machine
	name = "tattoo machine"
	desc = "A reusable coil tattoo machine. Use it on someone, sketch the design anywhere on their body, then apply it once they approve. Use it in hand to resume unfinished work."
	icon = 'modular_nova/modules/salon/icons/items.dmi'
	icon_state = "tattoo_machine"
	inhand_icon_state = "tattoo_machine"
	lefthand_file = 'modular_nova/modules/salon/icons/items_lefthand.dmi'
	righthand_file = 'modular_nova/modules/salon/icons/items_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2)

/obj/item/tattoo_machine/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	custom_sprite_salon_resume(src, user)
	return TRUE

/obj/item/tattoo_machine/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ishuman(interacting_with) || !ishuman(user))
		return NONE
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(custom_sprite_salon_tool_menu), src, user, interacting_with, "markings")
	return ITEM_INTERACT_SUCCESS

/// The finishing action stays audible too; interruption and completion release both channels.
/proc/do_salon_work(mob/living/user, duration, atom/recipient, tattoo = FALSE, datum/callback/extra_checks)
	var/sound_type = tattoo ? /datum/looping_sound/salon_snipping/drawing/tattoo : /datum/looping_sound/salon_snipping
	var/datum/looping_sound/work_sound = new sound_type(recipient, TRUE)
	var/datum/looping_sound/ambience
	if(tattoo)
		ambience = new /datum/looping_sound/salon_tattoo_ambience(recipient, TRUE)
	. = do_after(user, duration, recipient, extra_checks = extra_checks)
	qdel(ambience)
	qdel(work_sound)

/datum/looping_sound/salon_snipping
	mid_sounds = 'modular_nova/modules/salon/sound/haircut.ogg'
	mid_length = 6 SECONDS
	mid_length_vary = 1 SECONDS
	volume = 100
	reserve_random_channel = TRUE
	/// Current clip's listeners, held weakly so an open editor cannot retain deleted mobs.
	var/list/listeners

/datum/looping_sound/salon_snipping/play(soundfile, volume_override, repeat_sound = FALSE, delete_when_finished = FALSE)
	listeners = null
	for(var/mob/listener in playsound(parent, soundfile, volume_override || volume, vary = vary, channel = sound_channel))
		LAZYOR(listeners, WEAKREF(listener))

/datum/looping_sound/salon_snipping/stop_current()
	for(var/datum/weakref/listener_ref as anything in listeners)
		var/mob/listener = listener_ref.resolve()
		listener?.stop_sound_channel(sound_channel)
	listeners = null
	return ..()

/datum/looping_sound/salon_snipping/handle_parent_del(datum/source)
	stop()
	..()

/datum/looping_sound/salon_snipping/drawing
	mid_length = 5 SECONDS
	mid_length_vary = 0

/datum/looping_sound/salon_snipping/drawing/on_start()
	loop_started = TRUE
	play(get_sound())
	timer_id = addtimer(CALLBACK(src, PROC_REF(stop)), mid_length, TIMER_CLIENT_TIME | TIMER_DELETE_ME | TIMER_STOPPABLE, SSsound_loops)

/datum/looping_sound/salon_snipping/drawing/tattoo
	mid_sounds = 'modular_nova/modules/salon/sound/tattoo1.ogg'
	mid_length = 12 SECONDS
	volume = 60
	vary = TRUE

/datum/looping_sound/salon_tattoo_ambience
	mid_sounds = 'modular_nova/modules/salon/sound/tattoo_ambience.ogg'
	volume = 30
	use_sound_tokens = TRUE
