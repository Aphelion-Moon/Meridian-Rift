// Controllers, stocks, optics and sound suppressors. Gameplay values live with their parts.

/obj/item/ballistic_module/silencer
	name = "Parallax sound suppressor"
	desc = "A ceramic-sleeved baffle assembly for compact and carbine accelerators. Reduces the firing report while adding bulk and trapping 25% more firing heat. Install or remove it through the unloaded frame's service latch."
	socket = "silencer"
	icon_state = "silencer"
	heat_multiplier = 1.25

/obj/item/ballistic_module/control
	name = "Parallax semi-automatic controller"
	desc = "A fire-control cartridge that authorizes one shot per trigger pull. Its metered pulse generates 20% less heat than burst or automatic fire."
	socket = "controller"
	icon_state = "control_semi"
	var/automatic = FALSE
	var/shots_per_burst = 1
	var/burst_recovery = 0
	heat_multiplier = 0.8

/obj/item/ballistic_module/control/proc/fire_mode()
	return automatic ? "automatic" : (shots_per_burst > 1 ? "[shots_per_burst]-round burst" : "semi-automatic")

/obj/item/ballistic_module/control/examine(mob/user)
	. = ..()
	. += span_notice("Fire mode: [fire_mode()].")

/obj/item/ballistic_module/control/burst
	name = "Parallax burst controller"
	desc = "A fire-control cartridge that commits to three rounds per trigger pull. Reduces dispersion by 1, but adds 0.15 seconds of recovery between bursts and lacks semi-auto heat savings."
	icon_state = "control_burst"
	shots_per_burst = 3
	burst_recovery = 0.15 SECONDS
	dispersion = -1
	heat_multiplier = 1

/obj/item/ballistic_module/control/automatic
	name = "Parallax automatic controller"
	desc = "A fire-control cartridge that sustains fire while the trigger is held. The accelerator still determines cycle speed."
	icon_state = "control_auto"
	automatic = TRUE
	dispersion = 2
	heat_multiplier = 1

/** General-purpose rifle stock that improves control without delaying shots. */
/obj/item/ballistic_module/stock
	name = "Parallax compact stock"
	desc = "The standard Parallax rifle stock. Reduces dispersion and recoil without slowing the firing cycle, at the cost of a bulkier profile."
	socket = "stock"
	icon_state = "stock_compact"
	dispersion = -2
	kick = -0.15
	is_long = TRUE

/obj/item/ballistic_module/stock/precision
	name = "Parallax precision stock"
	desc = "An extended shoulder support for scoped fire. Reduces hip dispersion by 1 and scoped dispersion by a further 3, with stronger recoil control than the compact stock. Adds 0.05 seconds between shots."
	icon_state = "stock_precision"
	dispersion = -1
	scoped_accuracy = 3
	kick = -0.3
	cycle_cost = 0.05 SECONDS

/** Standard reflex sight and shared scope configuration for interchangeable optics. */
/obj/item/ballistic_module/optic
	name = "Parallax reflex optic"
	desc = "The standard Parallax sight: a recessed holographic aiming window that reduces shot dispersion without slowing the firing cycle."
	socket = "optic"
	icon_state = "optic_reflex"
	dispersion = -1
	var/scope_range = 0

/obj/item/ballistic_module/optic/examine(mob/user)
	. = ..()
	if(scope_range)
		. += span_notice("Enables right-click aiming. While scoped with this weapon, reduces dispersion by [scoped_accuracy]; hip-fire modifier remains included.")

/obj/item/ballistic_module/optic/scope
	name = "Parallax precision optic"
	desc = "An elongated ballistic sight with a cyan objective. Right-click to scope in. Excellent aimed accuracy, but awkward hip fire and a slower firing cycle."
	icon_state = "optic_scope"
	dispersion = 2
	cycle_cost = 0.05 SECONDS
	scope_range = 2
	scoped_accuracy = 4
