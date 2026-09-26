/obj/item/mod/control/seal_part(obj/item/clothing/part, is_sealed)
	var/was_sealed = get_part_datum(part).sealed
	. = ..()
	if(was_sealed == is_sealed || !theme?.hardlight || !wearer)
		return
	// Sealing can change hardlight without changing any clothing visibility flags.
	wearer.update_body_parts()

/obj/item/mod/control/control_activation(is_on)
	var/was_active = active
	. = ..()
	if(was_active == active || activating || !theme?.hardlight || !wearer)
		return
	// During a toggle, sealed parts project while activating is true; only their sealing changes the image.
	// Direct activation, shutdown and rollback still need a refresh here.
	wearer.update_body_parts()
