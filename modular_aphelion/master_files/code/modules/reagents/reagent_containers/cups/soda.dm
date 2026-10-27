/**
 * Gives the crushed can this can just became its sprite: this can's icon_state in the janitor icons.
 * Cans whose crushed sprite lives elsewhere override it.
 *
 * Arguments:
 * - crushed_can: The crushed can.
 */
/obj/item/reagent_containers/cup/soda_cans/proc/style_crushed_can(obj/item/trash/can/crushed_can)
	crushed_can.icon_state = icon_state
