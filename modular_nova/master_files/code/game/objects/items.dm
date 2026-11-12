/obj/item
	/// How much power would this item use?
	var/power_use_amount = POWER_CELL_USE_NORMAL

	/// Worn overlay will be shifted by this along x axis
	var/worn_x_offset = 0
	/// The list("x", "y") that moves this garment's blood or rips onto its wearer's body, as they're drawn for a human
	/// one. It's set while the garment is drawn from a sprite shaped to the wearer's species and holds blood or
	/// rips. The worn offsets put human sprites on that body, but skip shaped ones.
	var/list/worn_effect_offset

/// Use the power of an attached component that posesses power handling, will return the signal bitflag.
/obj/item/proc/item_use_power(use_amount, mob/user, check_only)
	SHOULD_CALL_PARENT(TRUE)
	return SEND_SIGNAL(src, COMSIG_ITEM_POWER_USE, use_amount, user, check_only)
