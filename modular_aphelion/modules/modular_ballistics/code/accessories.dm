// Controllers, stocks, optics and sound suppressors. Gameplay values live with their parts.

/obj/item/ballistic_module/silencer
	name = "Parallax sound suppressor"
	desc = "A ceramic-sleeved baffle assembly for compact and carbine accelerators. Reduces the firing report while adding bulk. Install or remove it through the unloaded frame's service latch."
	socket = "silencer"
	icon_state = "silencer"
	overlay_state = "silencer"

/obj/item/ballistic_module/control
	name = "Parallax semi-automatic controller"
	desc = "A fire-control cartridge that authorizes one shot per trigger pull."
	socket = "controller"
	icon_state = "control_semi"
	overlay_state = "control_semi"

/obj/item/ballistic_module/control/burst
	name = "Parallax burst controller"
	desc = "A fire-control cartridge that authorizes three rounds per trigger pull."
	icon_state = "control_burst"
	overlay_state = "control_burst"
	shots_per_burst = 3

/obj/item/ballistic_module/control/automatic
	name = "Parallax automatic controller"
	desc = "A fire-control cartridge that sustains fire while the trigger is held. The accelerator still determines cycle speed."
	icon_state = "control_auto"
	overlay_state = "control_auto"
	automatic = TRUE
	dispersion = 2

/obj/item/ballistic_module/stock
	name = "Parallax compact stock"
	desc = "A curved shoulder support that reduces dispersion and recoil, at the cost of a bulkier profile."
	socket = "stock"
	icon_state = "stock_compact"
	overlay_state = "stock_compact"
	dispersion = -2
	kick = -0.3
	is_long = TRUE

/obj/item/ballistic_module/stock/precision
	name = "Parallax precision stock"
	desc = "An extended triangular shoulder support with a recessed stabilizer. Greater stability than the compact stock, but adds 0.1 seconds between shots."
	icon_state = "stock_precision"
	overlay_state = "stock_precision"
	dispersion = -3
	kick = -0.5
	cycle_cost = 0.1 SECONDS

/obj/item/ballistic_module/optic
	name = "Parallax reflex optic"
	desc = "A recessed holographic aiming window that reduces shot dispersion."
	socket = "optic"
	icon_state = "optic_reflex"
	overlay_state = "optic_reflex"
	dispersion = -1

/obj/item/ballistic_module/optic/scope
	name = "Parallax precision optic"
	desc = "An elongated ballistic sight with a cyan objective. Right-click to scope in. Excellent aimed accuracy, but awkward hip fire and a slower firing cycle."
	icon_state = "optic_scope"
	overlay_state = "optic_scope"
	dispersion = 1
	cycle_cost = 0.1 SECONDS
	scope_range = 2
	scoped_accuracy = 4
