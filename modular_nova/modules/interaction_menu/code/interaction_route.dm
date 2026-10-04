/**
 * How a single interaction is reaching its target.
 *
 * Most interactions happen face to face and don't need one of these at all - a null route means exactly that.
 * A route exists for the cases where the target is being reached through something standing in for them, and it
 * owns the two things the interaction system can't answer on its own: whether that connection is still legal,
 * and what the target should be called to someone who can only see them through it.
 *
 * Anything can change while an interaction is in flight, so a route is asked to revalidate rather than trusted
 * once up front. It holds weak references for the same reason - a route outlives nothing.
 */
/datum/interaction_route

/**
 * TRUE while this route can still legally carry `interaction` between these two.
 *
 * Called once before the interaction runs and again before its deferred effects land.
 *
 * Arguments
 * * `ignore_cooldown` - Set for the deferred pass, which must not fail on the cooldown its own act() just paid.
 */
/datum/interaction_route/proc/is_still_valid(datum/interaction/interaction, mob/living/carbon/human/user, mob/living/carbon/human/target, ignore_cooldown = FALSE)
	return FALSE

/// Consent required by this transport, including for ordinary interactions. Checked at both execution boundaries.
/datum/interaction_route/proc/participants_accept(mob/living/carbon/human/user, mob/living/carbon/human/target)
	return TRUE

/// Whether one mob can fill both ends of an "other" interaction through this route.
/datum/interaction_route/proc/allows_same_participant()
	return FALSE

/// Whether this route validates access to its required parts itself.
/datum/interaction_route/proc/validates_part_access()
	return FALSE

/// Whether the user is hidden from the target by this route.
/datum/interaction_route/proc/user_is_anonymous()
	return FALSE

/// Whether the target is hidden from the user by this route.
/datum/interaction_route/proc/target_is_anonymous()
	return FALSE

/// What to call the target to someone seeing them only through this route. Null falls back to plain "Unknown".
/datum/interaction_route/proc/get_target_name()
	return null

/// Runs after a successful interaction's effects land, for routes with something to redraw or tear down.
/datum/interaction_route/proc/after_effects(mob/living/carbon/human/user, mob/living/carbon/human/target)
	return

/**
 * The route to use when this movable is standing in for `represented` in an interaction.
 *
 * Anything that can represent or reach someone elsewhere overrides this. Null means it cannot route this interaction,
 * which is the answer for almost every movable in the game.
 */
/atom/movable/proc/interaction_route_for(
	mob/living/carbon/human/represented,
	datum/interaction/interaction,
	mob/living/carbon/human/user,
)
	return null
