/datum/psionic_power/sinew_surge
	action_type = /datum/action/cooldown/psionic/sinew_surge

/datum/psionic_rank_variant/sinew_surge
	rank = PSIONIC_RANK_DELTA
	variant_name = "Power arms"
	description = "Empower your arms for 30 seconds, adding 5 punch damage and allowing strongarm-style airlock prying."
	cooldown_time = 60 SECONDS
	strain_gain = 20
	block_charge_cost = 0

/datum/action/cooldown/psionic/sinew_surge
	name = "Power Arms"
	desc = "Flood your arms with biomantic light. Your punches hit harder, and you can pry unsealed airlocks open with combat mode off."
	button_icon_state = "psi_power_arms"
	point_cost = 1
	school = PSIONIC_SCHOOL_BIOSCRAMBLER
	rank_variant_types = list(/datum/psionic_rank_variant/sinew_surge)

/datum/action/cooldown/psionic/sinew_surge/is_valid_target(atom/target)
	. = ..()
	if(!. || !ishuman(owner))
		return FALSE
	var/mob/living/carbon/human/human_owner = owner
	return human_owner.get_bodypart(BODY_ZONE_L_ARM) || human_owner.get_bodypart(BODY_ZONE_R_ARM)

/datum/action/cooldown/psionic/sinew_surge/psionic_activate(atom/target)
	var/mob/living/living_owner = owner
	living_owner.apply_status_effect(/datum/status_effect/sinew_surge)
	living_owner.visible_message(span_notice("Psionic light wells up around [owner]'s arms!"), span_purple("Your muscles tighten with biomantic power!"))
	return TRUE

/datum/status_effect/sinew_surge
	parent_type = /datum/status_effect/psionic_dispellable
	id = "sinew_surge"
	duration = 30 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/sinew_surge
	/// Original hit sounds, indexed by the limbs we have empowered.
	var/list/empowered_arms = list()
	/// Separate appearances avoid modifying the shared bodypart icon cache.
	var/list/arm_glows = list()
	var/prying = FALSE

/datum/status_effect/sinew_surge/on_apply()
	if(!ishuman(owner))
		return FALSE
	. = ..()
	RegisterSignal(owner, COMSIG_CARBON_POST_ATTACH_LIMB, PROC_REF(on_limbs_changed))
	RegisterSignal(owner, COMSIG_CARBON_POST_REMOVE_LIMB, PROC_REF(on_limbs_changed))
	RegisterSignal(owner, COMSIG_CARBON_BODYPART_UPDATED, PROC_REF(on_limbs_changed))
	refresh_arms()

/datum/status_effect/sinew_surge/on_remove()
	UnregisterSignal(owner, list(COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_CARBON_POST_REMOVE_LIMB, COMSIG_CARBON_BODYPART_UPDATED))
	for(var/obj/item/bodypart/arm as anything in empowered_arms.Copy())
		restore_arm(arm)
	owner.cut_overlay(arm_glows)
	arm_glows.Cut()
	if(prying)
		owner.RemoveElement(/datum/element/door_pryer, pry_time = 6 SECONDS, interaction_key = "sinew surge")
	return ..()

/datum/status_effect/sinew_surge/proc/on_limbs_changed(datum/source)
	SIGNAL_HANDLER
	refresh_arms()

/// Reconcile bonuses immediately when arms are removed, replaced, or regenerated.
/datum/status_effect/sinew_surge/proc/refresh_arms()
	var/mob/living/carbon/human/human_owner = owner
	var/datum/component/psionic_profile/profile = human_owner.get_psionic_profile()
	var/manifestation_color = profile?.psionic_color || PSIONIC_DEFAULT_COLOR
	var/list/current_arms = list()
	for(var/obj/item/bodypart/arm as anything in human_owner.bodyparts)
		if((arm.body_part & ARMS) && !IS_STUMP(arm))
			current_arms += arm
	for(var/obj/item/bodypart/arm as anything in empowered_arms.Copy())
		if(!(arm in current_arms))
			restore_arm(arm)
	owner.cut_overlay(arm_glows)
	arm_glows.Cut()
	for(var/obj/item/bodypart/arm as anything in current_arms)
		if(!(arm in empowered_arms))
			empowered_arms[arm] = arm.unarmed_attack_sound
			arm.unarmed_damage_low += 5
			arm.unarmed_damage_high += 5
			arm.unarmed_attack_sound = 'sound/effects/hit_punch.ogg'
		var/mutable_appearance/glow = mutable_appearance(offset_spokesman = owner, plane = ABOVE_LIGHTING_PLANE, appearance_flags = KEEP_APART|KEEP_TOGETHER)
		glow.overlays = arm.get_limb_icon()
		glow.color = manifestation_color
		glow.alpha = 140
		glow.blend_mode = BLEND_ADD
		arm_glows += glow
	owner.add_overlay(arm_glows)
	var/can_pry = length(current_arms) >= 2
	if(can_pry && !prying)
		owner.AddElement(/datum/element/door_pryer, pry_time = 6 SECONDS, interaction_key = "sinew surge")
	else if(!can_pry && prying)
		owner.RemoveElement(/datum/element/door_pryer, pry_time = 6 SECONDS, interaction_key = "sinew surge")
	prying = can_pry

/datum/status_effect/sinew_surge/proc/restore_arm(obj/item/bodypart/arm)
	if(!QDELETED(arm))
		arm.unarmed_damage_low -= 5
		arm.unarmed_damage_high -= 5
		if(arm.unarmed_attack_sound == 'sound/effects/hit_punch.ogg')
			arm.unarmed_attack_sound = empowered_arms[arm]
	empowered_arms -= arm

/atom/movable/screen/alert/status_effect/sinew_surge
	name = "Power Arms"
	desc = "Your arms glow with biomantic strength: +5 punch damage. With both arms, click an unsealed airlock outside combat mode to pry it open."
	icon_state = "slime_rainbowshield"
