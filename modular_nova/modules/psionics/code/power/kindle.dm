/// Temperature the spark exposes its target to, in kelvin.
#define KINDLE_TEMPERATURE 700
/// Volume of the spark's heat exposure.
#define KINDLE_VOLUME 10

/datum/psionic_power/kindle
	action_type = /datum/action/cooldown/psionic/pointed/kindle

/datum/psionic_rank_variant/kindle
	rank = PSIONIC_RANK_EPSILON
	variant_name = "spark"
	description = "A small thermal spark that can kindle flammable materials."
	strain_gain = 4
	cooldown_time = 5 SECONDS
	cast_range = 3
	block_charge_cost = 0

/datum/action/cooldown/psionic/pointed/kindle
	name = "Kindle"
	desc = "Create a small spark that can ignite nearby flammable materials."
	button_icon_state = "psi_kindle"
	point_cost = 1
	psionic_flags = PSIONIC_THERMAL
	school = PSIONIC_SCHOOL_FLUX
	rank_variant_types = list(/datum/psionic_rank_variant/kindle)
	active_msg = "You gather a small thermal spark..."
	deactive_msg = "You let the spark fade."

/datum/action/cooldown/psionic/pointed/kindle/is_valid_target(atom/target)
	. = ..()
	if(!.)
		return FALSE
	if(ismob(target))
		owner.balloon_alert(owner, "target an object or floor!")
		return FALSE
	if(!isturf(target) && !isturf(target.loc) && !ismob(target.loc) && !isitem(target.loc))
		owner.balloon_alert(owner, "can't reach it!")
		return FALSE

	return TRUE

/datum/action/cooldown/psionic/pointed/kindle/psionic_activate(atom/target)
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return FALSE

	new /obj/effect/particle_effect/sparks(target_turf)
	target.fire_act(KINDLE_TEMPERATURE, KINDLE_VOLUME)
	if(isturf(target) || isturf(target.loc))
		target_turf.hotspot_expose(KINDLE_TEMPERATURE, KINDLE_VOLUME, soh = TRUE)
	playsound(target_turf, 'sound/effects/sparks/sparks4.ogg', 35, TRUE)
	to_chat(owner, span_purple("You kindle a spark at [target]."))
	return TRUE

#undef KINDLE_TEMPERATURE
#undef KINDLE_VOLUME
