/// How long the spray sound lasts, so it plays once a clip: sound/effects/spray.ogg is 1.458 s.
#define GRAFFITI_SPRAY_LENGTH (1.5 SECONDS)

/**
 * Plays the spray sound where paint lands, at most once a clip, however often a sprayer paints.
 *
 * The sprayer, such as a freehand session or a paint job, keeps the time in its own `spray_cooldown`, which it passes
 * in and stores again from the return value.
 *
 * Arguments:
 * - at: Where the paint lands.
 * - cooldown: The sprayer's spray_cooldown: when the last spray sound it played ends.
 *
 * Returns:
 * - number: The sprayer's spray_cooldown from now on.
 */
/proc/graffiti_spray(atom/at, cooldown)
	if(cooldown > world.time)
		return cooldown
	playsound(at, 'sound/effects/spray.ogg', 30, TRUE)
	return world.time + GRAFFITI_SPRAY_LENGTH

/**
 * Plays a spray can's shake, as a freehand session or a paint job starts.
 *
 * Arguments:
 * - user: Who shakes the can.
 */
/proc/graffiti_shake(mob/user)
	playsound(user, 'modular_aphelion/modules/graffiti/sound/paintcan_shake.ogg', 40, TRUE)

#undef GRAFFITI_SPRAY_LENGTH
