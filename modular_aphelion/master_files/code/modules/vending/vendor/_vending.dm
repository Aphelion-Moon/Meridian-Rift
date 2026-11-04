/obj/machinery/vending
	/// Set when the open panel sits over part of the light mask, so the panel's wires don't glow
	var/panel_over_light_mask = FALSE

/obj/machinery/vending/update_overlays()
	. = ..()
	if(panel_open && panel_over_light_mask)
		. += emissive_blocker(icon, panel_type, src)
