/obj/item
	/// How much power would this item use?
	var/power_use_amount = POWER_CELL_USE_NORMAL

	/// Worn overlay will be shifted by this along x axis
	var/worn_x_offset = 0
	/// While this is drawn from a sprite shaped to its wearer's species, list("x", "y") moving its blood and rips, which
	/// are drawn for a human body, onto that body. The worn offsets put human sprites there, but skip shaped ones.
	var/list/worn_effect_offset

/// Use the power of an attached component that posesses power handling, will return the signal bitflag.
/obj/item/proc/item_use_power(use_amount, mob/user, check_only)
	SHOULD_CALL_PARENT(TRUE)
	return SEND_SIGNAL(src, COMSIG_ITEM_POWER_USE, use_amount, user, check_only)
