// Flowing fuel leaves fuel pools under its liquid. They keep burning as tg's do, but the liquid draws the fuel, and the
// pool's sprite would draw over it.

/obj/effect/decal/cleanable/fuel_pool/Initialize(mapload, burn_stacks)
	. = ..()
	var/turf/pool_turf = get_turf(src)
	if(pool_turf?.liquids)
		set_under_liquid(TRUE)

/**
 * Hides the pool while a liquid covers its tile, or shows it again. A hidden pool keeps its click box, so it still
 * lights from a lighter.
 *
 * Arguments:
 * - under_liquid: TRUE while a liquid covers the tile.
 */
/obj/effect/decal/cleanable/fuel_pool/proc/set_under_liquid(under_liquid)
	icon_state = under_liquid ? "nothing" : initial(icon_state)

/**
 * Hides or shows this turf's fuel pool, if it has one.
 *
 * Arguments:
 * - under_liquid: TRUE while a liquid covers the turf.
 */
/turf/proc/set_fuel_pool_under_liquid(under_liquid)
	var/obj/effect/decal/cleanable/fuel_pool/pool = locate() in src
	pool?.set_under_liquid(under_liquid)
