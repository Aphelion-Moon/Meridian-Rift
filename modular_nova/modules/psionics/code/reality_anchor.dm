/// Turfs from the anchor that each pulse reaches.
#define PSIONIC_ANCHOR_RANGE 6
/// Time between pulses while the anchor is running.
#define PSIONIC_ANCHOR_PULSE_INTERVAL (6 SECONDS)
/// How long a single pulse keeps a psion silenced. Must outlast the interval so standing
/// inside the field is a continuous lockout rather than a flicker.
#define PSIONIC_ANCHOR_SILENCE_TIME (10 SECONDS)
/// Time spent switching the anchor on or off.
#define PSIONIC_ANCHOR_TOGGLE_TIME (3 SECONDS)

/**
 * Security-issue area denial against psionics.
 *
 * While running it pulses on an interval, unmaking psionic manifestations in range and
 * silencing any psion caught inside. Unanchored while off so it can be positioned, and it
 * bolts itself down once switched on.
 */
/obj/structure/psionic_anchor
	name = "miniature reality anchor"
	desc = "A compact field generator with a steel chassis and a shielded cyan resonator. \
		Switched on, it insists loudly and continuously that nothing unusual \
		is happening anywhere near it."
	icon = 'modular_nova/modules/psionics/icons/reality_anchor.dmi'
	icon_state = "reality_anchor"
	density = TRUE
	max_integrity = 300
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/bluespace = HALF_SHEET_MATERIAL_AMOUNT,
	)
	light_system = OVERLAY_LIGHT
	light_range = 3
	light_power = 1
	light_color = LIGHT_COLOR_FAINT_CYAN
	light_on = FALSE
	/// TRUE while the anchor is pulsing.
	var/active = FALSE
	/// Filter identifier for the active distortion effect.
	var/ripple_filter_id = "psionic_anchor_ripple"

	COOLDOWN_DECLARE(pulse_cooldown)

/obj/structure/psionic_anchor/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/psionic_anchor/examine(mob/user)
	. = ..()
	. += span_notice("It is currently [active ? "running" : "idle"].")

/obj/structure/psionic_anchor/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return

	var/action_word = active ? "shutting down" : "spinning up"
	user.visible_message(
		span_warning("[user] starts [action_word] [src]..."),
		span_notice("You start [action_word] [src]..."),
	)
	if(!do_after(user, PSIONIC_ANCHOR_TOGGLE_TIME, target = src))
		return

	toggle()
	user.visible_message(
		span_warning("[user] finishes [action_word] [src]."),
		span_notice("You finish [action_word] [src]."),
	)
	return TRUE

/obj/structure/psionic_anchor/proc/toggle()
	active = !active
	set_anchored(active)
	// The resonator's area light and the ripple indicate that the anchor is running.
	set_light_on(active)

	if(!active)
		remove_filter(ripple_filter_id)
		STOP_PROCESSING(SSobj, src)
		return

	apply_ripple_filter()
	playsound(src, 'sound/effects/magic/repulse.ogg', 75, TRUE)
	pulse()
	START_PROCESSING(SSobj, src)

// SSobj ticks faster than the anchor pulses, so the interval is enforced here rather than by
// the subsystem.
/obj/structure/psionic_anchor/process(seconds_per_tick)
	if(!active)
		return PROCESS_KILL
	if(!COOLDOWN_FINISHED(src, pulse_cooldown))
		return

	pulse()

/obj/structure/psionic_anchor/proc/pulse()
	COOLDOWN_START(src, pulse_cooldown, PSIONIC_ANCHOR_PULSE_INTERVAL)
	var/turf/epicentre = get_turf(src)
	if(!epicentre)
		return

	var/obj/effect/temp_visual/circle_wave/psionic_anchor/wave = new(epicentre)
	wave.amount_to_scale = PSIONIC_ANCHOR_RANGE + 2

	for(var/atom/movable/target in range(PSIONIC_ANCHOR_RANGE, epicentre))
		target.psionic_dispel(src)
		if(!isliving(target))
			continue

		// Only psions have anything to silence, and only they should see the alert.
		var/mob/living/living_target = target
		if(!living_target.get_psionic_profile())
			continue

		// REFRESH, and the silence outlasts the interval, so staying in the field is one
		// unbroken lockout rather than a lapse between pulses.
		living_target.apply_status_effect(/datum/status_effect/psionic_silenced)

/obj/structure/psionic_anchor/proc/apply_ripple_filter()
	add_filter(ripple_filter_id, 2, list("type" = "ripple", "flags" = WAVE_BOUNDED, "radius" = 0, "size" = 2))
	var/ripple = get_filter(ripple_filter_id)
	if(!ripple)
		return

	animate(ripple, radius = 0, time = 0.2 SECONDS, size = 2, easing = JUMP_EASING, loop = -1, flags = ANIMATION_PARALLEL)
	animate(radius = 32, time = 1.5 SECONDS, size = 0)

/**
 * Suppression applied by an anchor pulse.
 *
 * Deliberately sources TRAIT_PSIONIC_DAMPENER from the status effect rather than QUIRK_TRAIT,
 * because can_cast_psionics() treats non-quirk dampener sources as a total lockout. That is the
 * whole implementation: no separate silencing plumbing.
 */
/datum/status_effect/psionic_silenced
	id = "psionic_silenced"
	status_type = STATUS_EFFECT_REFRESH
	duration = PSIONIC_ANCHOR_SILENCE_TIME
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/psionic_silenced
	show_duration = TRUE

/datum/status_effect/psionic_silenced/on_apply()
	ADD_TRAIT(owner, TRAIT_PSIONIC_DAMPENER, TRAIT_STATUS_EFFECT(id))
	owner.add_mood_event(id, /datum/mood_event/psionic_silenced)
	to_chat(owner, span_warning("A flat, insistent pressure presses your gift shut."))
	return TRUE

/datum/status_effect/psionic_silenced/on_remove()
	REMOVE_TRAIT(owner, TRAIT_PSIONIC_DAMPENER, TRAIT_STATUS_EFFECT(id))
	owner.clear_mood_event(id)
	return ..()

/datum/status_effect/psionic_silenced/get_examine_text()
	return span_warning("[owner.p_Their()] psionic presence is flattened to nothing.")

/atom/movable/screen/alert/status_effect/psionic_silenced
	name = "Silenced"
	desc = "A reality anchor is holding your psionics shut."
	icon_state = "mute"

/datum/mood_event/psionic_silenced
	description = "Something out there is holding my gift closed, and it will not let go."
	mood_change = -4

/obj/effect/temp_visual/circle_wave/psionic_anchor
	color = COLOR_SILVER
	max_alpha = 20
	duration = 0.5 SECONDS

#undef PSIONIC_ANCHOR_RANGE
#undef PSIONIC_ANCHOR_PULSE_INTERVAL
#undef PSIONIC_ANCHOR_SILENCE_TIME
#undef PSIONIC_ANCHOR_TOGGLE_TIME
