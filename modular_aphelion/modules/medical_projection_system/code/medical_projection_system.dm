/// The field sprayer's low-efficiency treatment mode.
#define LIFELINE_MODE_HEAL "heal"
/// The field sprayer's temporary transport-support mode.
#define LIFELINE_MODE_STABILIZE "stabilize"
/// The field sprayer's recovery-cocoon mode.
#define LIFELINE_MODE_STASIS "stasis"
/// The maximum amount of medium stored by the station-wide network.
#define LIFELINE_NETWORK_CAPACITY 1000
/// The maximum amount of medium stored by one field sprayer.
#define LIFELINE_PROJECTOR_CAPACITY 100
/// Medium consumed by heal mode.
#define LIFELINE_HEAL_COST 10
/// Medium consumed by stabilize mode.
#define LIFELINE_STABILIZE_COST 25
/// Medium consumed by stasis mode.
#define LIFELINE_STASIS_COST 50
/// Damage removed by one heal-mode use.
#define LIFELINE_HEAL_AMOUNT 8
/// Progress applied to one random wound. Default wounds require 9 Moderate, 17 Severe or
/// 25 Critical sprays from zero progress, across refills.
#define LIFELINE_WOUND_PROGRESS 4
/// Number of non-empty fluid levels in the field sprayer icon.
#define LIFELINE_FUEL_ICON_LEVELS 4
/// Duration of the transport-support field.
#define LIFELINE_STABILIZE_DURATION (2 MINUTES)
/// Delay between recovery-cocoon beacon pings.
// Original: 8 SECONDS
#define LIFELINE_RECOVERY_PING_INTERVAL (20 SECONDS)

/// Current medium available to all connected first aid stations.
GLOBAL_VAR_INIT(lifeline_fuel, 0)
/// Maximum medium available to the station-wide network.
GLOBAL_VAR_INIT(lifeline_fuel_capacity, LIFELINE_NETWORK_CAPACITY)
/// One singleton per concrete /datum/lifeline_request subtype.
GLOBAL_LIST_INIT(lifeline_requests, build_lifeline_requests())
/// The contribution the reservoir currently accepts.
GLOBAL_VAR(lifeline_request)

/**
 * One hands-on contribution the Lifeline network asks the crew for.
 *
 * Add a request by adding a subtype and nothing else. The rollable set is built from the subtype
 * tree, so a request cannot be offered without the values that describe it.
 */
/datum/lifeline_request
	/// Reagent or item type the reservoir accepts. Null marks an abstract half of the tree.
	var/requested_type
	/// Player-facing name of what the reservoir wants.
	var/requested_name
	/// Reagent units, or item count, that one contribution must supply.
	var/requested_amount
	/// Medium the network gains when staff complete this request.
	var/yield

/// Returns the player-facing phrase for one contribution.
/datum/lifeline_request/proc/describe()
	return "[requested_amount] [requested_name]"

/// Returns whether this item is worth offering to the intake, so unrelated items fall through it.
/datum/lifeline_request/proc/is_contribution(obj/item/tool)
	return FALSE

/**
 * Takes the contribution out of the item.
 *
 * Returns whether the item carried enough. Reports its own refusal through the reservoir when not.
 *
 * Arguments:
 * * tool - the item offered to the intake.
 * * user - the person feeding the intake.
 * * reservoir - the machine the contribution went into, used for feedback.
 */
/datum/lifeline_request/proc/consume(obj/item/tool, mob/living/user, obj/machinery/lifeline_reservoir/reservoir)
	return FALSE

/// A measured sample of one reagent, carried in any container.
/datum/lifeline_request/reagent

/datum/lifeline_request/reagent/describe()
	return "[requested_amount] units of [requested_name]"

/datum/lifeline_request/reagent/is_contribution(obj/item/tool)
	return !isnull(tool.reagents)

/datum/lifeline_request/reagent/consume(obj/item/tool, mob/living/user, obj/machinery/lifeline_reservoir/reservoir)
	if(tool.reagents.get_reagent_amount(requested_type) < requested_amount)
		reservoir.balloon_alert(user, "needs [requested_amount]u [requested_name]!")
		return FALSE
	tool.reagents.remove_reagent(requested_type, requested_amount)
	user.visible_message(span_notice("[user] manually feeds a measured sample into [reservoir]."), span_notice("You feed the requested sample into [reservoir]."))
	return TRUE

/// One organic organ, which the intake destroys.
/datum/lifeline_request/organ

/datum/lifeline_request/organ/is_contribution(obj/item/tool)
	return istype(tool, requested_type)

/datum/lifeline_request/organ/consume(obj/item/tool, mob/living/user, obj/machinery/lifeline_reservoir/reservoir)
	var/obj/item/organ/contributed_organ = tool
	if(contributed_organ.organ_flags & (ORGAN_ROBOTIC | ORGAN_MINERAL))
		reservoir.balloon_alert(user, "organic organ required!")
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(tool))
		reservoir.balloon_alert(user, "item stuck!")
		return FALSE
	user.visible_message(span_notice("[user] commits [tool] to [reservoir]'s intake."), span_notice("You commit [tool] to the current Lifeline request."))
	qdel(tool)
	return TRUE

/datum/lifeline_request/reagent/libital
	requested_type = /datum/reagent/medicine/c2/libital
	requested_name = "libital"
	requested_amount = 30
	yield = 55

/datum/lifeline_request/reagent/aiuri
	requested_type = /datum/reagent/medicine/c2/aiuri
	requested_name = "aiuri"
	requested_amount = 30
	yield = 55

/datum/lifeline_request/reagent/synthflesh
	requested_type = /datum/reagent/medicine/c2/synthflesh
	requested_name = "synthflesh"
	requested_amount = 20
	yield = 70

/datum/lifeline_request/reagent/epinephrine
	requested_type = /datum/reagent/medicine/epinephrine
	requested_name = "epinephrine"
	requested_amount = 35
	yield = 50

/datum/lifeline_request/reagent/salbutamol
	requested_type = /datum/reagent/medicine/salbutamol
	requested_name = "salbutamol"
	requested_amount = 30
	yield = 60

/datum/lifeline_request/organ/heart
	requested_type = /obj/item/organ/heart
	requested_name = "organic heart"
	requested_amount = 1
	yield = 90

/datum/lifeline_request/organ/lungs
	requested_type = /obj/item/organ/lungs
	requested_name = "set of organic lungs"
	requested_amount = 1
	yield = 75

/datum/lifeline_request/organ/liver
	requested_type = /obj/item/organ/liver
	requested_name = "organic liver"
	requested_amount = 1
	yield = 75

/// Builds one singleton per concrete request subtype.
/proc/build_lifeline_requests()
	var/list/requests = list()
	for(var/datum/lifeline_request/request_type as anything in subtypesof(/datum/lifeline_request))
		if(isnull(initial(request_type.requested_type))) // abstract type
			continue
		requests += new request_type()
	return requests

/// Chooses the next contribution requested by the station-wide Lifeline network.
/proc/roll_lifeline_request()
	var/list/other_requests = GLOB.lifeline_requests - GLOB.lifeline_request
	GLOB.lifeline_request = pick(length(other_requests) ? other_requests : GLOB.lifeline_requests)

/** Central, manually-fed server and reservoir for the Lifeline emergency-care network. */
/obj/machinery/lifeline_reservoir
	name = "Lifeline synthesis reservoir"
	desc = "A synthesis server and reservoir that turns requested medical feedstock into reconstructive medium for the station's first aid network. Its intake requires direct manual confirmation."
	icon = 'modular_aphelion/modules/medical_projection_system/icons/lifeline_reservoir.dmi'
	icon_state = "lifeline_reservoir"
	base_icon_state = "lifeline_reservoir"
	density = TRUE
	max_integrity = 300
	circuit = /obj/item/circuitboard/machine/lifeline_reservoir

/obj/machinery/lifeline_reservoir/Initialize(mapload)
	. = ..()
	if(isnull(GLOB.lifeline_request))
		roll_lifeline_request()

/obj/machinery/lifeline_reservoir/examine(mob/user)
	. = ..()
	var/datum/lifeline_request/request = GLOB.lifeline_request
	. += span_notice("The network contains <b>[GLOB.lifeline_fuel]/[GLOB.lifeline_fuel_capacity]</b> units of reconstructive medium.")
	. += span_notice("Current request: <b>[request.describe()]</b> for <b>[request.yield]</b> medium units.")

/obj/machinery/lifeline_reservoir/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	var/datum/lifeline_request/request = GLOB.lifeline_request
	balloon_alert(user, "request: [request.describe()]")
	to_chat(user, span_notice("The Lifeline network has [GLOB.lifeline_fuel]/[GLOB.lifeline_fuel_capacity] units stored. It will accept [request.describe()] for [request.yield] units."))
	return TRUE

/obj/machinery/lifeline_reservoir/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	var/datum/lifeline_request/request = GLOB.lifeline_request
	if(!request.is_contribution(tool))
		return NONE
	if(!is_operational)
		balloon_alert(user, "reservoir offline!")
		return ITEM_INTERACT_BLOCKING
	if(GLOB.lifeline_fuel + request.yield > GLOB.lifeline_fuel_capacity)
		balloon_alert(user, "insufficient storage!")
		return ITEM_INTERACT_BLOCKING
	if(!request.consume(tool, user, src))
		return ITEM_INTERACT_BLOCKING

	GLOB.lifeline_fuel += request.yield
	playsound(src, 'sound/machines/ping.ogg', 40, TRUE)
	balloon_alert(user, "+[request.yield] network units")
	roll_lifeline_request()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/lifeline_reservoir/screwdriver_act(mob/living/user, obj/item/tool)
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/lifeline_reservoir/crowbar_act(mob/living/user, obj/item/tool)
	return default_deconstruction_crowbar(user, tool)

/obj/machinery/lifeline_reservoir/update_icon_state()
	if(panel_open)
		icon_state = "[base_icon_state]_open"
	else
		icon_state = is_operational ? base_icon_state : "[base_icon_state]_off"
	return ..()

/obj/item/circuitboard/machine/lifeline_reservoir
	name = "Lifeline Synthesis Reservoir"
	greyscale_colors = CIRCUIT_COLOR_MEDICAL
	build_path = /obj/machinery/lifeline_reservoir
	req_components = list(
		/datum/stock_part/matter_bin = 2,
		/datum/stock_part/capacitor = 1,
		/datum/stock_part/servo = 1,
		/obj/item/stack/cable_coil = 5,
	)

/** A pocket projector that draws reconstructive medium from the network at wall-mounted first aid stations. */
/obj/item/lifeline_projector
	name = "Lifeline field sprayer"
	desc = "A compact emergency medical projector. Its glass reservoir shows how much reconstructive medium remains. Use it in hand to apply the selected mode to yourself; right-click it in hand to change modes."
	icon = 'modular_aphelion/modules/medical_projection_system/icons/lifeline_projector.dmi'
	icon_state = "lifeline_0"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	item_flags = NOBLUDGEON
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = HALF_SHEET_MATERIAL_AMOUNT,
	)
	/// Medium currently stored in the field sprayer.
	var/fuel = 0
	/// Maximum medium stored in the field sprayer.
	var/max_fuel = LIFELINE_PROJECTOR_CAPACITY
	/// Treatment mode applied by the next use.
	var/selected_mode = LIFELINE_MODE_HEAL
	/// Prevents overlapping treatments with this sprayer.
	var/treatment_in_progress = FALSE

/** A field sprayer supplied with a full reservoir. */
/obj/item/lifeline_projector/full

/obj/item/lifeline_projector/full/Initialize(mapload)
	. = ..()
	fuel = max_fuel
	update_appearance()

/obj/item/lifeline_projector/examine(mob/user)
	. = ..()
	. += span_notice("It is set to <b>[selected_mode]</b> and holds <b>[fuel]/[max_fuel]</b> medium units.")
	. += span_notice("Heal costs [LIFELINE_HEAL_COST] units, stabilize costs [LIFELINE_STABILIZE_COST], and stasis costs [LIFELINE_STASIS_COST].")

/obj/item/lifeline_projector/update_icon_state()
	var/fuel_state = 0
	if(fuel > 0)
		fuel_state = clamp(CEILING((fuel / max_fuel) * LIFELINE_FUEL_ICON_LEVELS, 1), 1, LIFELINE_FUEL_ICON_LEVELS)
	icon_state = "lifeline_[fuel_state]"
	return ..()

/obj/item/lifeline_projector/attack_self_secondary(mob/user)
	if(treatment_in_progress)
		balloon_alert(user, "treatment in progress!")
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	switch(selected_mode)
		if(LIFELINE_MODE_HEAL)
			selected_mode = LIFELINE_MODE_STABILIZE
		if(LIFELINE_MODE_STABILIZE)
			selected_mode = LIFELINE_MODE_STASIS
		else
			selected_mode = LIFELINE_MODE_HEAL
	balloon_alert(user, "mode: [selected_mode]")
	playsound(src, 'sound/machines/beep/beep.ogg', 25, TRUE)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/item/lifeline_projector/attack_self(mob/user)
	if(!isliving(user))
		return
	use_on_target(user, user)
	return TRUE

/obj/item/lifeline_projector/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with))
		return NONE
	use_on_target(interacting_with, user)
	return ITEM_INTERACT_SUCCESS

/obj/item/lifeline_projector/proc/use_on_target(mob/living/target, mob/living/user)
	if(treatment_in_progress)
		balloon_alert(user, "treatment in progress!")
		return FALSE
	treatment_in_progress = TRUE
	. = perform_treatment(target, user, selected_mode)
	treatment_in_progress = FALSE

/// Check eligibility before calibration and again before spending medium.
/obj/item/lifeline_projector/proc/can_treat(mob/living/target, mob/living/user, treatment_mode, fuel_cost)
	if(QDELETED(target) || QDELETED(user))
		return FALSE
	if(fuel < fuel_cost)
		balloon_alert(user, "insufficient medium!")
		return FALSE
	if(treatment_mode != LIFELINE_MODE_STASIS && target.stat == DEAD)
		balloon_alert(user, "no viable response!")
		return FALSE
	if(treatment_mode == LIFELINE_MODE_STASIS && target == user)
		balloon_alert(user, "requires another operator!")
		return FALSE
	if(treatment_mode == LIFELINE_MODE_STABILIZE)
		if(target.health > target.crit_threshold)
			balloon_alert(user, "patient is not critical!")
			return FALSE
		if(target.has_status_effect(/datum/status_effect/lifeline_stabilized))
			balloon_alert(user, "already stabilized!")
			return FALSE
	return TRUE

/// Capture the mode before yielding so its effect and price always agree.
/obj/item/lifeline_projector/proc/perform_treatment(mob/living/target, mob/living/user, treatment_mode)
	var/fuel_cost
	switch(treatment_mode)
		if(LIFELINE_MODE_HEAL)
			fuel_cost = LIFELINE_HEAL_COST
		if(LIFELINE_MODE_STABILIZE)
			fuel_cost = LIFELINE_STABILIZE_COST
		if(LIFELINE_MODE_STASIS)
			fuel_cost = LIFELINE_STASIS_COST
		else
			return FALSE
	if(!can_treat(target, user, treatment_mode, fuel_cost))
		return FALSE

	user.visible_message(span_notice("[user] aims [src] at [target], tracing a lattice of pale light over [target.p_them()]."), span_notice("You begin calibrating [src] on [target]."))
	if(!do_after(user, target == user ? 2 SECONDS : 1.5 SECONDS, target = target))
		return FALSE
	if(!can_treat(target, user, treatment_mode, fuel_cost))
		return FALSE

	switch(treatment_mode)
		if(LIFELINE_MODE_HEAL)
			if(target.stat == DEAD)
				balloon_alert(user, "no viable response!")
				return FALSE
			if(!apply_healing(target))
				balloon_alert(user, "nothing to treat!")
				return FALSE
		if(LIFELINE_MODE_STABILIZE)
			// Rechecked after the do_after, since somebody else may have stabilized this patient while
			// this sprayer was calibrating. The effect is unique, so the second application is refused
			// silently and would otherwise spend the medium for nothing.
			if(!target.apply_status_effect(/datum/status_effect/lifeline_stabilized))
				balloon_alert(user, "already stabilized!")
				return FALSE
			target.visible_message(span_notice("A supportive field settles around [target]."), span_notice("The field suppresses critical collapse, but locks your hands. Injuries and bleeding remain. Click the Field Stabilized alert to end it."))
		if(LIFELINE_MODE_STASIS)
			var/obj/structure/closet/body_bag/environmental/stasis/lifeline/recovery_bag = new(get_turf(target))
			// insert() refuses anchored, buckled, incorporeal and oversized patients.
			if(recovery_bag.insert(target) != TRUE)
				qdel(recovery_bag)
				balloon_alert(user, "patient is secured!")
				return FALSE
			recovery_bag.dissolve_when_opened = TRUE
			recovery_bag.visible_message(span_notice("A translucent recovery cocoon assembles around [target]."))

	log_combat(user, target, "applied Lifeline [treatment_mode] to", src)
	fuel -= fuel_cost
	update_appearance()
	playsound(target, 'sound/effects/spray.ogg', 40, TRUE)
	return TRUE

/**
 * Heals the greater of brute and burn damage, and progresses one random wound.
 * Brute wins ties. Returns whether there was anything to treat at all.
 */
/obj/item/lifeline_projector/proc/apply_healing(mob/living/target)
	var/brute_damage = target.get_brute_loss()
	var/burn_damage = target.get_fire_loss()

	var/datum/wound/chosen_wound
	if(iscarbon(target))
		var/mob/living/carbon/carbon_target = target
		if(length(carbon_target.all_wounds))
			chosen_wound = pick(carbon_target.all_wounds)

	if(brute_damage <= 0 && burn_damage <= 0 && isnull(chosen_wound))
		return FALSE

	if(brute_damage > 0 || burn_damage > 0)
		target.heal_damage_type(LIFELINE_HEAL_AMOUNT, brute_damage >= burn_damage ? BRUTE : BURN)
	chosen_wound?.on_xadone(LIFELINE_WOUND_PROGRESS)

	target.visible_message(span_notice("[src] mists [target] with flickering reconstructive droplets."), span_notice("Cool light crawls over one of your injuries."))
	return TRUE

/**
 * Keeps a critical patient mobile long enough to be moved.
 *
 * Suppresses the critical rungs only. Injuries, bleeding and anything still hitting the patient run
 * exactly as they would otherwise.
 */
/datum/status_effect/lifeline_stabilized
	id = "lifeline_stabilized"
	duration = LIFELINE_STABILIZE_DURATION
	alert_type = /atom/movable/screen/alert/status_effect/lifeline_stabilized

/datum/status_effect/lifeline_stabilized/on_apply()
	. = ..()
	if(!.)
		return
	owner.add_traits(list(TRAIT_NOSOFTCRIT, TRAIT_NOHARDCRIT, TRAIT_HANDS_BLOCKED), TRAIT_STATUS_EFFECT(id))
	owner.add_filter("lifeline_support", 2, outline_filter(1, "#70eaff80"))

/datum/status_effect/lifeline_stabilized/on_remove()
	owner.remove_traits(list(TRAIT_NOSOFTCRIT, TRAIT_NOHARDCRIT, TRAIT_HANDS_BLOCKED), TRAIT_STATUS_EFFECT(id))
	owner.remove_filter("lifeline_support")
	return ..()

/atom/movable/screen/alert/status_effect/lifeline_stabilized
	name = "Field Stabilized"
	desc = "A support field suppresses critical collapse, but does not heal injuries or stop bleeding. Your hands are immobilized. Click this alert to end the field and regain hand use; critical collapse may return. Seek proper treatment."
	use_user_hud_icon = USER_HUD_STYLE_INHERIT
	overlay_state = "stasis"
	clickable_glow = TRUE

/atom/movable/screen/alert/status_effect/lifeline_stabilized/Click(location, control, params)
	. = ..()
	if(!. || owner.stat == DEAD || IS_UNCONSCIOUS(owner))
		return
	var/mob/living/patient = owner
	patient.remove_status_effect(/datum/status_effect/lifeline_stabilized)

/** Temporary projected cocoon with an audible recovery beacon. */
/obj/structure/closet/body_bag/environmental/stasis/lifeline
	name = "Lifeline recovery cocoon"
	desc = "A temporary projected stasis enclosure. Its recovery beacon periodically pings to guide responders to its patient."
	max_integrity = 150
	breakout_time = 4 SECONDS
	obj_flags = parent_type::obj_flags | NO_DEBRIS_AFTER_DECONSTRUCTION
	/// Whether the cocoon has finished deploying and should disappear the next time it opens.
	var/dissolve_when_opened = FALSE
	COOLDOWN_DECLARE(recovery_ping_cooldown)

/obj/structure/closet/body_bag/environmental/stasis/lifeline/Initialize(mapload)
	. = ..()
	set_light(2, 0.7, LIGHT_COLOR_CYAN)
	AddComponent(/datum/component/gps, "Lifeline Recovery Signal")
	COOLDOWN_START(src, recovery_ping_cooldown, 2 SECONDS)

/obj/structure/closet/body_bag/environmental/stasis/lifeline/after_open(mob/living/user, force = FALSE)
	. = ..()
	if(!dissolve_when_opened)
		return
	visible_message(span_notice("[src] dissolves into fading motes of light."))
	qdel(src)

/// Pings its recovery beacon.
/obj/structure/closet/body_bag/environmental/stasis/lifeline/process(seconds_per_tick)
	. = ..()
	if(QDELETED(src) || . == PROCESS_KILL)
		return
	if(COOLDOWN_FINISHED(src, recovery_ping_cooldown))
		playsound(src, 'sound/machines/ping.ogg', 45, TRUE, MEDIUM_RANGE_SOUND_EXTRARANGE)
		visible_message(span_notice("[src]'s beacon pulses."), vision_distance = 5)
		COOLDOWN_START(src, recovery_ping_cooldown, LIFELINE_RECOVERY_PING_INTERVAL)

/** Refills a field sprayer from the station-wide reservoir. */
/obj/machinery/wall_healer/proc/refill_lifeline_projector(obj/item/lifeline_projector/projector, mob/living/user)
	if(!is_operational)
		balloon_alert(user, "station offline!")
		return ITEM_INTERACT_BLOCKING
	var/needed_fuel = projector.max_fuel - projector.fuel
	if(needed_fuel <= 0)
		balloon_alert(user, "already full!")
		return ITEM_INTERACT_BLOCKING
	var/transferred_fuel = min(needed_fuel, GLOB.lifeline_fuel)
	if(transferred_fuel <= 0)
		balloon_alert(user, "network reservoir empty!")
		return ITEM_INTERACT_BLOCKING
	projector.fuel += transferred_fuel
	GLOB.lifeline_fuel -= transferred_fuel
	projector.update_appearance()
	user.visible_message(span_notice("[user] seats [projector] in [src]'s service port."), span_notice("[src] transfers [transferred_fuel] medium units into [projector]."))
	playsound(src, 'sound/machines/machine_vend.ogg', 40, TRUE)
	return ITEM_INTERACT_SUCCESS

/datum/loadout_item/pocket_items/lifeline_projector
	name = "Lifeline Field Sprayer (Full)"
	item_path = /obj/item/lifeline_projector/full
	group = "Gear"

/datum/design/lifeline_projector
	name = "Lifeline Field Sprayer"
	desc = "A refillable emergency medical projector with healing, stabilization, and remote stasis modes."
	build_path = /obj/item/lifeline_projector
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = HALF_SHEET_MATERIAL_AMOUNT,
	)
	category = list(RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MEDICAL)
	departmental_flags = DEPARTMENT_BITFLAG_MEDICAL

/datum/design/board/lifeline_reservoir
	name = "Lifeline Synthesis Reservoir Board"
	desc = "Allows for the construction of a Lifeline synthesis server and reservoir."
	build_path = /obj/item/circuitboard/machine/lifeline_reservoir
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_MEDICAL)
	departmental_flags = DEPARTMENT_BITFLAG_MEDICAL | DEPARTMENT_BITFLAG_SCIENCE

/datum/techweb_node/cryostasis/New()
	. = ..()
	unlocked_designs += list(
		/datum/design/lifeline_projector,
		/datum/design/board/lifeline_reservoir,
	)

#undef LIFELINE_MODE_HEAL
#undef LIFELINE_MODE_STABILIZE
#undef LIFELINE_MODE_STASIS
#undef LIFELINE_NETWORK_CAPACITY
#undef LIFELINE_PROJECTOR_CAPACITY
#undef LIFELINE_HEAL_COST
#undef LIFELINE_STABILIZE_COST
#undef LIFELINE_STASIS_COST
#undef LIFELINE_HEAL_AMOUNT
#undef LIFELINE_WOUND_PROGRESS
#undef LIFELINE_FUEL_ICON_LEVELS
#undef LIFELINE_STABILIZE_DURATION
#undef LIFELINE_RECOVERY_PING_INTERVAL
