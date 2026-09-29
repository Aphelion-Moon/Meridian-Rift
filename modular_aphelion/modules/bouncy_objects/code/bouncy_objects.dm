// Bounce profiles for specific objects. Each tuning describes how the object feels when it rebounds.

/// Lively and springy: keeps most of its travel and hops across hard floors several times.
/obj/item/toy/tennis/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/bouncy, restitution = 0.7, max_bounces = 4, floor_bounces = TRUE, bounce_sound = 'sound/items/basketball_bounce.ogg', bounce_sound_volume = 30)

/// Soft and squishy: a single sluggish, wobbly rebound before it settles with a splat.
/obj/item/slime_extract/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/bouncy, restitution = 0.35, max_bounces = 1, floor_bounces = TRUE, deflect_chance = 25, bounce_sound = 'sound/effects/splat.ogg', bounce_sound_volume = 20)

/**
 * Bouncier than a tennis ball: keeps most of its travel through a long, wobbly chain of boings.
 * It also pops away when its slimeperson's body melts; see the marked edit in core_ejection().
 */
/obj/item/organ/brain/slime/Initialize(mapload, mob/living/carbon/organ_owner, list/examine_list)
	. = ..()
	AddElement(/datum/element/bouncy, restitution = 0.85, max_bounces = 6, floor_bounces = TRUE, deflect_chance = 15, bounce_sound = 'sound/effects/boing.ogg', bounce_sound_volume = 25, eject_hop_range = 4)

/**
 * Light and skittery: live rounds and spent casings rattle off at unpredictable angles.
 * Ejected casings also hop a tile from the gun. Casings already play their turf's bullet bounce sound.
 */
/obj/item/ammo_casing/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/bouncy, restitution = 0.5, max_bounces = 2, floor_bounces = TRUE, deflect_chance = 50, eject_hop_range = 1)

/// Heavy and dead: little rebound, clattering off at angles. The metal landing sound already plays.
/obj/item/stack/rods/Initialize(mapload, new_amount, merge = TRUE, list/mat_override = null, mat_amt = 1)
	. = ..()
	AddElement(/datum/element/bouncy, restitution = 0.3, max_bounces = 2, floor_bounces = TRUE, deflect_chance = 50)
