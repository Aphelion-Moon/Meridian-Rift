//! Contains admin and CC varianted robot models
// Admin Cyborg Models.
// TODO: player usable cc model, admin cc model, subspace borg, administrative (like literally about paperwork and shit)
// TODO: Fine tune the perfect vision action, right now it needs to be used alongside thermal to work correctly. Works well enough rn though, it's REAL perfect vision not augmented, so like, see through walls but no highlights
// TODO: sprites, finish compiling the dmi and organizing all the bits and bobs of the tachikoma stuff in place, help wanted
// TODO: modules

// code\modules\mob\living\silicon\robot\robot.dm:L152 absolutely unholy shit going on here.
/* A solution that is not a solution. The glob is made inside the proc. I am in misery.
		if(!client?.holder)
			GLOB.cyborg_model_list += list(
			"Admin" = /obj/item/robot_model/admin,
			"CC Frontline" = /obj/item/robot_model/admin/frontline,
			"CC Backline" = /obj/item/robot_model/admin/backline,
			"CC Engineer" = /obj/item/robot_model/admin/engineer,
		)
*/
// Currently looks like you'll only be able to directly create these borgs and not have a switchable selector, until I can figure out a way to run a holder check to expand that list. But then its updating a glob, which is for everyone.
// Someone smarter than me will have to fix this one
//
// TODO: Needs custom icons
// TODO: Explore more borg hands? How many hands can a borg reasonably have?
// Baseline CC model, total generalist. Can do a bit of everything but lacks specialized tools.
// When you need a general ERT or CC Borg, pick this.
// The CC walkers (this one, Frontline, Backline, Technical) are meant to be piloted by players, so their kits avoid anything
// gated behind client.holder. Each specialist should also out-equip a fully upgraded station cyborg of the same job.
// The gated admin tools live on the Bluespace and Subspace walkers instead. CC-only cyborg gear is in admin_robot_items.dm.
/obj/item/robot_model/admin
	name = "Central Command"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/extinguisher,
		/obj/item/weldingtool/advanced/admin,
		/obj/item/multitool/admin,
		/obj/item/crowbar/power/alien/admin,
		/obj/item/screwdriver/power/alien/admin,
		/obj/item/construction/rcd/borg/centcom,
		/obj/item/lightreplacer/blue/admin,
		/obj/item/stack/sheet/iron,
		/obj/item/stack/sheet/glass,
		/obj/item/borg/apparatus/sheet_manipulator,
		/obj/item/stack/rods/cyborg,
		/obj/item/stack/tile/iron/base/cyborg,
		/obj/item/stack/cable_coil,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/stack/medical/wrap/gauze,
		/obj/item/shockpaddles/syndicate/nanotrasen/cyborg,
		/obj/item/healthanalyzer/advanced/admin,
		/obj/item/surgical_drapes,
		/obj/item/scalpel/advanced/alien/admin,
		/obj/item/retractor/advanced/alien/admin,
		/obj/item/cautery/advanced/alien/admin,
		/obj/item/blood_filter/advanced/alien/admin,
		/obj/item/gun/medbeam,
		/obj/item/reagent_containers/borghypo/medical/centcom,
		/obj/item/borg/lollipop,
		/obj/item/holosign_creator/cyborg,
		/obj/item/stamp/centcom,
		/obj/item/pinpointer/response_team_cyborg,
		/obj/item/borg_shapeshifter,
	)
	radio_channels = list(RADIO_CHANNEL_COMMAND)
	model_traits = list(TRAIT_NEGATES_GRAVITY, TRAIT_PUSHIMMUNE)
	canDispose = TRUE
	cyborg_base_icon = "tachi"
	model_select_icon = "malf"
	hat_offset = INFINITY
	breakable_modules = FALSE
//	interaction_range = INFINITY
	borg_skins = list(
		/// 32x32 Skins
		"Walker Tank" = list(SKIN_ICON_STATE = "tachi", SKIN_ICON = 'modular_aphelion/modules/admin_tech/icons/admin_robots.dmi'),
	)
	// This is where we begin the setup of the special features on the admin borgs themselves
	var/datum/weakref/thermal_vision_ref
	var/datum/weakref/disguise_action_ref
	var/datum/weakref/xray_vision_ref

// Destroys tailing references on admin borg destruction
/obj/item/robot_model/admin/Destroy(force)
	var/datum/action/thermal_vision = thermal_vision_ref?.resolve()
	var/datum/action/disguise = disguise_action_ref?.resolve()
	var/datum/action/xray_vision = xray_vision_ref?.resolve()
	qdel(thermal_vision)
	qdel(disguise)
	qdel(xray_vision)
	thermal_vision_ref = null
	disguise_action_ref = null
	xray_vision_ref = null
	return ..()

// Handles the setup of the cyborg. This is run at the cyborg being built and is part of the stall on interacting during spawn.
/obj/item/robot_model/admin/be_transformed_to(obj/item/robot_model/old_model, forced = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/silicon/robot/borg = loc
	if(!istype(borg))
		return FALSE
	if(!istype(borg.radio, /obj/item/radio/borg/centcom))
		QDEL_NULL(borg.radio)
		borg.radio = new /obj/item/radio/borg/centcom(borg)
	var/datum/action/cooldown/borg_thermal/thermal_vision = new(borg)
	var/datum/action/cooldown/borg_disguise/disguise = new(borg)
	var/datum/action/cooldown/borg_xray/xray_vision = new(borg)
	thermal_vision.Grant(borg)
	thermal_vision_ref = WEAKREF(thermal_vision)
	disguise.Grant(borg)
	disguise_action_ref = WEAKREF(disguise)
	xray_vision.Grant(borg)
	xray_vision_ref = WEAKREF(xray_vision)
	ADD_TRAIT(borg, TRAIT_XRAY_VISION, ACTION_TRAIT)

// Sets up a new action to divorce the shapeshifter item into a hard function, so admin borgs can remain stealthed as whatever regardless what they are doing.
// This does use a lot of the original item code. I don't know if this can be done better.
/datum/action/cooldown/borg_disguise
	name = "Change Appearance"
	desc = "Reversibly change your outward model appearance. Unlike the standard chameleon projector module, this cannot be disrupted by force."
	button_icon = 'icons/obj/devices/syndie_gadget.dmi'
	button_icon_state = "shield0"
	cooldown_time = 0.5 SECONDS
	var/active = FALSE
	var/saved_icon
	var/saved_icon_override
	var/saved_name
	var/saved_model_features
	var/saved_special_light_key
	var/saved_hat_offset
	var/saved_bubble_icon

// Main disguise application and removal loop
/datum/action/cooldown/borg_disguise/Activate()
	var/mob/living/silicon/robot/borg = owner
	if(!istype(borg))
		return
	if(active)
		revert_disguise(borg)
		..()
		return TRUE
	if(apply_disguise(borg))
		..()
		return TRUE
	return FALSE

// Sanity catches
/datum/action/cooldown/borg_disguise/proc/check_menu(mob/user)
	if(!istype(user))
		return FALSE
	if(user.incapacitated)
		return FALSE
	return TRUE

// This should really be kept in parity with the original list, but really who cares if admin tools decay past what the public uses.
/datum/action/cooldown/borg_disguise/proc/apply_disguise(mob/living/silicon/robot/borg)
	var/static/list/model_icons = sort_list(list(
		"Medical" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "medical"),
		"Cargo" = image(icon = CYBORG_ICON_CARGO, icon_state = "cargoborg"),
		"Engineer" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "engineer"),
		"Security" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "sec"),
		"Service" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "service_f"),
		"Janitor" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "janitor"),
		"Miner" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "miner"),
		"Peacekeeper" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "peace"),
		"Clown" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "clown"),
		"Syndicate" = image(icon = 'icons/mob/silicon/robots.dmi', icon_state = "synd_sec"),
		"Spider Clan" = image(icon = CYBORG_ICON_NINJA, icon_state = "ninja_engi"),
	))
	var/model_selection = show_radial_menu(borg, borg, model_icons, custom_check = CALLBACK(src, PROC_REF(check_menu), borg), radius = 42, require_near = TRUE)
	if(!model_selection)
		return
// The list of skins
	var/obj/item/robot_model/model
	switch(model_selection)
		if("Medical")
			model = new /obj/item/robot_model/medical
		if("Cargo")
			model = new /obj/item/robot_model/cargo
		if("Engineer")
			model = new /obj/item/robot_model/engineering
		if("Security")
			model = new /obj/item/robot_model/security
		if("Service")
			model = new /obj/item/robot_model/service
		if("Janitor")
			model = new /obj/item/robot_model/janitor
		if("Miner")
			model = new /obj/item/robot_model/miner
		if("Peacekeeper")
			model = new /obj/item/robot_model/peacekeeper
		if("Clown")
			model = new /obj/item/robot_model/clown
		if("Syndicate")
			model = new /obj/item/robot_model/syndicatejack
		if("Spider Clan")
			model = new /obj/item/robot_model/ninja
		else
			return
// Handles the icon conversions
	var/list/reskin_icons = list()
	for(var/skin in model.borg_skins)
		var/list/details = model.borg_skins[skin]
		var/image/reskin = image(icon = details[SKIN_ICON] || 'icons/mob/silicon/robots.dmi', icon_state = details[SKIN_ICON_STATE])
		if(!isnull(details[SKIN_FEATURES]) && (TRAIT_R_WIDE in details[SKIN_FEATURES]))
			reskin.pixel_x -= 16
		reskin_icons[skin] = reskin
	var/borg_skin = show_radial_menu(borg, borg, reskin_icons, custom_check = CALLBACK(src, PROC_REF(check_menu), borg), radius = 38, require_near = TRUE)
	if(!borg_skin)
		qdel(model)
		return

	var/list/details = model.borg_skins[borg_skin]
	var/disguise_icon_state = details[SKIN_ICON_STATE]
	var/disguise_icon_override = details[SKIN_ICON]
	var/disguise_special_light_key = details[SKIN_LIGHT_KEY]
	var/disguise_model_features = details[SKIN_FEATURES]
	var/picked_name = model.name
	qdel(model)

	if(!active)
		saved_icon = borg.model.cyborg_base_icon
		saved_bubble_icon = borg.bubble_icon
		saved_icon_override = borg.model.cyborg_icon_override
		saved_name = borg.model.name
		saved_model_features = borg.model.model_features
		saved_special_light_key = borg.model.special_light_key
		saved_hat_offset = borg.model.hat_offset

	borg.model.name = picked_name
	borg.model.cyborg_base_icon = disguise_icon_state
	borg.model.cyborg_icon_override = disguise_icon_override
	borg.model.model_features = disguise_model_features
	borg.model.special_light_key = disguise_special_light_key
	borg.bubble_icon = "robot"
	active = TRUE
	to_chat(borg, span_notice("You are now disguised as [picked_name]."))// Successful function tochat
	borg.update_icons()
	borg.model.update_quadborg()
	borg.model.update_tallborg()
	build_all_button_icons()// Finalizes rebuild
	return TRUE

// Reverting to Tachi.
/datum/action/cooldown/borg_disguise/proc/revert_disguise(mob/living/silicon/robot/borg)
	borg.model.name = saved_name
	borg.model.cyborg_base_icon = saved_icon
	borg.model.cyborg_icon_override = saved_icon_override
	borg.model.model_features = saved_model_features
	borg.model.special_light_key = saved_special_light_key
	borg.model.hat_offset = saved_hat_offset
	borg.bubble_icon = saved_bubble_icon
	active = FALSE
	to_chat(borg, span_notice("You revert to your true appearance."))
	borg.update_icons()
	borg.model.update_quadborg()
	borg.model.update_tallborg()
	build_all_button_icons()
	return TRUE

// Borg / drone vision.
/datum/action/cooldown/borg_xray
	name = "Toggle Perfect Vision"
	desc = "Toggles perfect vision - full sight regardless of lighting, plus the ability to see mobs through walls."
	button_icon = 'icons/mob/actions/actions_mecha.dmi'
	button_icon_state = "meson"
	cooldown_time = 0.5 SECONDS

// Processes the action and toggles our x-ray vision
/datum/action/cooldown/borg_xray/Activate()
	if(HAS_TRAIT_FROM(owner, TRAIT_XRAY_VISION, ACTION_TRAIT))
		REMOVE_TRAIT(owner, TRAIT_XRAY_VISION, ACTION_TRAIT)
	else
		ADD_TRAIT(owner, TRAIT_XRAY_VISION, ACTION_TRAIT)
	..()
	return TRUE

/datum/action/cooldown/borg_xray/Remove(mob/remove_from)
	REMOVE_TRAIT(remove_from, TRAIT_XRAY_VISION, ACTION_TRAIT)
	return ..()

// Spawnable Mob for the base model + additional config and benefits
/mob/living/silicon/robot/model/admin
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_robots.dmi'
	icon_state = "tachi"
	designation = "CC"
	faction = list(FACTION_ERT)
	bubble_icon = "guardian"
	req_access = list(ACCESS_CENT_GENERAL)
	lawupdate = FALSE
	scrambledcodes = FALSE
	ionpulse = TRUE
	set_model = /obj/item/robot_model/admin
	cell = /obj/item/stock_parts/power_store/cell/infinite
	radio = /obj/item/radio/borg/centcom

// Bluespace Walker, a bluespace technician stand-alone.
// This is the admin walker, so unlike the CC walkers it carries the admin tool set, holder-gated items included.
/obj/item/robot_model/admin/bluespace
	name = "Bluespace Walker"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/crowbar/power/alien/admin,
		/obj/item/screwdriver/power/alien/admin,
		/obj/item/weldingtool/advanced/admin,
		/obj/item/multitool/admin,
		/obj/item/extinguisher/subspace,
		/obj/item/card/emag/admin,
		/obj/item/door_remote/admin,
		/obj/item/construction/rcd/arcd/mattermanipulator/admin,
		/obj/item/construction/rld/admin,
		/obj/item/construction/plumbing/admin,
		/obj/item/lightreplacer/blue/admin,
		/obj/item/holosign_creator/atmos/admin,
		/obj/item/forcefield_projector/admin,
		/obj/item/storage/part_replacer/bluespace/admin,
		/obj/item/healthanalyzer/advanced/admin,
		/obj/item/ph_meter/admin,
		/obj/item/surgical_drapes,
		/obj/item/scalpel/advanced/alien/admin,
		/obj/item/retractor/advanced/alien/admin,
		/obj/item/cautery/advanced/alien/admin,
		/obj/item/blood_filter/advanced/alien/admin,
		/obj/item/shears/admin,
		/obj/item/reagent_containers/hypospray/combat/subspace,
		/obj/item/reagent_containers/syringe/admin,
		/obj/item/handheld_debug_chem_synth,
		/obj/item/gun/chem/admin,
		/obj/item/gun/energy/recharge/fisher/admin,
		/obj/item/gun/magic/subspace/dagenblicky,
		/obj/item/pneumatic_cannon/subspace,
		/obj/item/melee/baseball_bat/admin,
		/obj/item/laser_pointer/admin,
		/obj/item/pinpointer/crew/admin,
		/obj/item/modular_computer/pda/admin,
		/obj/item/summon_beacon/vendors/debug,
		/obj/item/borg_shapeshifter,
	)
	radio_channels = list(
		RADIO_CHANNEL_COMMAND,
		RADIO_CHANNEL_SECURITY,
		RADIO_CHANNEL_ENGINEERING,
		RADIO_CHANNEL_MEDICAL,
		RADIO_CHANNEL_SCIENCE,
		RADIO_CHANNEL_SUPPLY,
		RADIO_CHANNEL_SERVICE,
	)

// The mob for the walker itself.
/mob/living/silicon/robot/model/admin/bluespace
	set_model = /obj/item/robot_model/admin/bluespace
	icon_state = "tachi"

// Subspace Walker - this is the flagship/showcase model for the subspace-tech-rework branch, so its kit doubles as a demo case for the admin_tech items themselves.
/obj/item/robot_model/admin/subspace
	parent_type = /obj/item/robot_model/admin/bluespace
	name = "Subspace Walker"

// The mob for the walker itself.
/mob/living/silicon/robot/model/admin/subspace
	set_model = /obj/item/robot_model/admin/subspace
	icon_state = "tachi"

// Frontline Walker - the laser pointer needs a hitscan icon
// Out-guns a station security cyborg: pulse carbine and e-sword on top of the disabler, baton and hailer it would have had.
/obj/item/robot_model/admin/frontline
	name = "Frontline Walker"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/melee/energy/sword/saber/cyborg,
		/obj/item/melee/baton/security/loaded,
		/obj/item/melee/baseball_bat/admin,
		/obj/item/gun/energy/pulse/carbine/cyborg,
		/obj/item/gun/energy/disabler/cyborg,
		/obj/item/laser_pointer/admin,
		/obj/item/card/emag/centcom,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/clothing/mask/gas/sechailer/cyborg,
		/obj/item/crowbar/power/alien/admin,
		/obj/item/extinguisher/mini,
		/obj/item/pinpointer/response_team_cyborg,
	)
	radio_channels = list(RADIO_CHANNEL_COMMAND, RADIO_CHANNEL_SECURITY)

// The mob for the walker itself.
/mob/living/silicon/robot/model/admin/frontline
	set_model = /obj/item/robot_model/admin/frontline
	icon_state = "tachi"

// Backline Walker
// Covers everything a fully upgraded station medical cyborg gets from its upgrade chips, then beats each of them:
// a bigger and faster piercing hypo, combat paddles, subspace surgical tools, the subspace analyzers, and a built-in crew monitor.
// The subspace reagent projector used to live here, but it only works for admins, so it stays on the Bluespace Walker.
/obj/item/robot_model/admin/backline
	name = "Backline Walker"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/reagent_containers/borghypo/medical/centcom,
		/obj/item/shockpaddles/syndicate/nanotrasen/cyborg,
		/obj/item/healthanalyzer/advanced/admin,
		/obj/item/ph_meter/admin,
		/obj/item/autopsy_scanner,
		/obj/item/surgical_processor,
		/obj/item/surgical_drapes,
		/obj/item/scalpel/advanced/alien/admin,
		/obj/item/retractor/advanced/alien/admin,
		/obj/item/cautery/advanced/alien/admin,
		/obj/item/blood_filter/advanced/alien/admin,
		/obj/item/melee/energy/sword/saber/cyborg/saw,
		/obj/item/gun/medbeam,
		/obj/item/borg/apparatus/beaker,
		/obj/item/borg/apparatus/beaker/extra,
		/obj/item/borg/apparatus/sheet_manipulator/chemistry,
		/obj/item/reagent_containers/dropper,
		/obj/item/reagent_containers/syringe/admin,
		/obj/item/emergency_bed/silicon,
		/obj/item/holosign_creator/medical/treatment_zone,
		/obj/item/borg/cyborghug/medical,
		/obj/item/stack/medical/wrap/gauze,
		/obj/item/stack/medical/bone_gel,
		/obj/item/borg/apparatus/organ_storage,
		/obj/item/storage/bag/chemistry,
		/obj/item/pinpointer/crew,
		/obj/item/pinpointer/response_team_cyborg,
		/obj/item/borg/lollipop,
		/obj/item/crowbar/cyborg,
		/obj/item/extinguisher/mini,
	)
	radio_channels = list(RADIO_CHANNEL_COMMAND, RADIO_CHANNEL_MEDICAL)
	model_traits = list(TRAIT_NEGATES_GRAVITY, TRAIT_PUSHIMMUNE, TRAIT_FASTMED)
	var/datum/weakref/crew_monitor_ref

/obj/item/robot_model/admin/backline/Destroy(force)
	var/datum/action/crew_monitor = crew_monitor_ref?.resolve()
	qdel(crew_monitor)
	crew_monitor_ref = null
	return ..()

/obj/item/robot_model/admin/backline/be_transformed_to(obj/item/robot_model/old_model, forced = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/silicon/robot/borg = loc
	var/datum/action/cooldown/borg_crew_monitor/crew_monitor = new(borg)
	crew_monitor.Grant(borg)
	crew_monitor_ref = WEAKREF(crew_monitor)

// The mob for the walker itself.
/mob/living/silicon/robot/model/admin/backline
	set_model = /obj/item/robot_model/admin/backline
	icon_state = "tachi"

// Technical / Engie Walker
// Covers everything a fully upgraded station engineering cyborg gets (RPED, RLD, inducer, both apparatus, advanced materials)
// and replaces the omnitool with the subspace tool set. The saboteur's chameleon projector is gone, since the walker
// already has its own disguise action.
/obj/item/robot_model/admin/engineer
	name = "Technical Walker"
	basic_modules = list(
		/obj/item/assembly/flash/cyborg,
		/obj/item/construction/rcd/borg/centcom,
		/obj/item/pipe_dispenser,
		/obj/item/construction/rtd/borg,
		/obj/item/construction/rld/admin,
		/obj/item/extinguisher,
		/obj/item/weldingtool/advanced/admin,
		/obj/item/crowbar/power/alien/admin,
		/obj/item/screwdriver/power/alien/admin,
		/obj/item/multitool/admin,
		/obj/item/t_scanner,
		/obj/item/analyzer,
		/obj/item/holosign_creator/atmos/admin,
		/obj/item/assembly/signaler/cyborg,
		/obj/item/blueprints/cyborg,
		/obj/item/shuttle_blueprints/borg,
		/obj/item/electroadaptive_pseudocircuit,
		/obj/item/inducer/cyborg,
		/obj/item/storage/part_replacer/bluespace,
		/obj/item/lightreplacer/blue/admin,
		/obj/item/stack/sheet/iron,
		/obj/item/stack/sheet/glass,
		/obj/item/stack/sheet/plasteel/cyborg,
		/obj/item/stack/sheet/titaniumglass/cyborg,
		/obj/item/borg/apparatus/sheet_manipulator,
		/obj/item/borg/apparatus/engineering,
		/obj/item/borg/apparatus/engineering,
		/obj/item/stack/rods/cyborg,
		/obj/item/stack/tile/iron/base/cyborg,
		/obj/item/stack/cable_coil,
		/obj/item/airlock_painter/decal/cyborg,
		/obj/item/dest_tagger/borg,
		/obj/item/restraints/handcuffs/cable/zipties,
		/obj/item/card/emag/centcom,
		/obj/item/pinpointer/response_team_cyborg,
	)
	radio_channels = list(RADIO_CHANNEL_COMMAND, RADIO_CHANNEL_ENGINEERING)

// The mob for the walker itself.
/mob/living/silicon/robot/model/admin/engineer
	set_model = /obj/item/robot_model/admin/engineer
	icon_state = "tachi"

/*
The Syndicate Jack does exist but ew. Clean paths for us please.
Modules to transform pre-existing borgs into an admin borg type
*/
/obj/item/borg/upgrade/transform/admin
	name = "borg module picker (Central Command Administrative Walker)"
	desc = "Allows you to turn a cyborg into an experimental Central Command Administrative Walker."
	icon_state = "module_illegal"
	new_model = /obj/item/robot_model/admin

/obj/item/borg/upgrade/transform/admin/backline
	name = "borg module picker (Central Command Backline Walker)"
	desc = "Allows you to turn a cyborg into an experimental Central Command Backline Walker."
	icon_state = "module_illegal"
	new_model = /obj/item/robot_model/admin/backline

/obj/item/borg/upgrade/transform/admin/frontline
	name = "borg module picker (Central Command Frontline Walker)"
	desc = "Allows you to turn a cyborg into an experimental Central Command Frontline Walker."
	icon_state = "module_illegal"
	new_model = /obj/item/robot_model/admin/frontline

/obj/item/borg/upgrade/transform/admin/engineer
	name = "borg module picker (Central Command Engineer Walker)"
	desc = "Allows you to turn a cyborg into an experimental Central Command Technical Walker."
	icon_state = "module_illegal"
	new_model = /obj/item/robot_model/admin/engineer
