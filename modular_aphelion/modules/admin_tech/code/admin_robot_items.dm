//! Cyborg-side equipment for the Central Command walkers in admin_robots.dm.
// The CC walkers were built as straight copies of the syndicate kits, so they shipped with syndicate hyposprays, paddles,
// RCDs, pinpointers and radios. These are the Central Command replacements. Everything here has to work for a player
// piloting the walker, so nothing in this file is gated behind client.holder - the gated admin tools stay on the
// Bluespace and Subspace walkers instead.

// Hypospray - the full upgraded medical suite, plus a CentCom-only shelf, with piercing and a fast recharge.
// Subtyping the medical hypo means upgrade_hypo() supplies the expanded list, so it can't drift out of sync with the station one.
/obj/item/reagent_containers/borghypo/medical/centcom
	name = "Central Command cyborg hypospray"
	desc = "A Central Command pattern chemical synthesizer. It carries the full station formulary, a shelf of reagents the station isn't trusted with, \
		and a needle that goes through hardsuits."
	possible_transfer_amounts = list(2, 5, 10, 15)
	max_volume_per_reagent = 50
	charge_cost = 0.02 * STANDARD_CELL_CHARGE
	recharge_time = 3
	bypass_protection = TRUE
	/// Reagents on top of the station base and expanded lists.
	var/static/list/centcom_reagent_types = list(
		/datum/reagent/medicine/atropine,
		/datum/reagent/medicine/coagulant,
		/datum/reagent/medicine/leporazine,
		/datum/reagent/medicine/neurine,
		/datum/reagent/medicine/omnizine,
		/datum/reagent/medicine/salbutamol,
	)

/obj/item/reagent_containers/borghypo/medical/centcom/Initialize(mapload)
	// The parent sizes its holder off this list, so the extras have to be in it before ..() runs.
	default_reagent_types = default_reagent_types | centcom_reagent_types
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)
	upgrade_hypo()

// Combat paddles that aren't the syndicate ones. The NT elite paddles already exist for ERT defibs, this is just the cyborg mount.
/obj/item/shockpaddles/syndicate/nanotrasen/cyborg
	name = "Central Command cyborg defibrillator paddles"
	desc = "A pair of elite Nanotrasen paddles hardwired into a cyborg chassis. They punch through armour and can deliver disabling shocks."
	req_defib = FALSE

/obj/item/shockpaddles/syndicate/nanotrasen/cyborg/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

// RCD - beats the syndicate borg RCD on every axis: reinforced walls, range, speed, every design unlocked and a cheaper draw.
/obj/item/construction/rcd/borg/centcom
	name = "\improper Central Command cyborg RCD"
	desc = "A professional-grade RCD wired into a cyborg's power supply. It works at range, deconstructs reinforced walls, and comes with every design disk Central Command has."
	icon_state = "cercd"
	inhand_icon_state = "cercd"
	inside_belt_icon_state = "cercd"
	energyfactor = 0.05 * STANDARD_CELL_CHARGE
	canRturf = TRUE
	ranged = TRUE
	delay_mod = 0.5
	construction_upgrades = RCD_ALL_UPGRADES & ~RCD_UPGRADE_SILO_LINK

/obj/item/construction/rcd/borg/centcom/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

// Radio - the walkers spawned on the syndicate frequency with a syndicate key. This puts them on CentCom like the rest of the ERT.
/obj/item/radio/borg/centcom
	keyslot = /obj/item/encryptionkey/headset_cent

// Pinpointer - the syndicate cyborg one hunts nuclear operatives, which a CentCom unit has no use for. This finds the nearest living responder instead.
/obj/item/pinpointer/response_team_cyborg
	name = "cyborg response team pinpointer"
	desc = "An integrated tracking device keyed to the transponders carried by Central Command response personnel. Points to the nearest one still alive."
	flags_1 = NONE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF

/obj/item/pinpointer/response_team_cyborg/cyborg_unequip(mob/user)
	if(!active)
		return
	toggle_on()

/obj/item/pinpointer/response_team_cyborg/scan_for_target()
	target = null
	var/turf/here = get_turf(src)
	if(!here)
		return ..()
	var/list/possible_targets = list()
	for(var/datum/mind/responder as anything in get_antag_minds(/datum/antagonist/ert))
		var/mob/living/responder_body = responder.current
		// The walker itself is usually a responder too, so skip whoever is carrying this.
		if(!isliving(responder_body) || responder_body == loc || responder_body.stat == DEAD)
			continue
		var/turf/responder_turf = get_turf(responder_body)
		if(!responder_turf || responder_turf.z != here.z)
			continue
		possible_targets |= responder_body
	target = get_closest_atom(/mob/living, possible_targets, here)
	return ..()

// Pulse carbine - the NT answer to the syndicate cyborg LMG. Same three modes as the ERT carbine, fed from the cyborg's cell.
/obj/item/gun/energy/pulse/carbine/cyborg
	name = "Central Command cyborg pulse carbine"
	desc = "A pulse carbine mounted to a cyborg chassis and fed from its internal cell. Pulse, taser and laser modes, same as the ones the response teams carry."
	can_charge = FALSE
	selfcharge = FALSE
	use_cyborg_cell = TRUE

/obj/item/gun/energy/pulse/carbine/cyborg/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/gun/energy/pulse/carbine/cyborg/add_seclight_point()
	return

// Emag - a CentCom-branded sequencer. It is a stock emag underneath, with none of the subspace emag's range or blacklist bypass.
/obj/item/card/emag/centcom
	name = "Central Command cryptographic sequencer"
	desc = "A Central Command issue override card, for when a response unit needs into something that won't let it. Unlike the subspace one, it still has to touch what it's opening."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_items.dmi'
	icon_state = "sub-emag"

/obj/item/card/emag/centcom/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

// The medical cyborg only gets crew monitor access through its pinpointer upgrade. The backline walker gets it built in.
/datum/action/cooldown/borg_crew_monitor
	name = "Interface With Crew Monitor"
	desc = "Open the station crew monitor."
	button_icon = 'icons/obj/devices/tracker.dmi'
	button_icon_state = "pinpointer_crew"
	cooldown_time = 0.5 SECONDS

/datum/action/cooldown/borg_crew_monitor/Activate(atom/target)
	GLOB.crewmonitor.show(owner, owner)
	..()
	return TRUE
