/datum/psionic_power/spit_image
	action_type = /datum/action/cooldown/psionic/spit_image

/datum/psionic_rank_variant/spit_image
	rank = PSIONIC_RANK_GAMMA
	variant_name = "spit image"
	description = "Maintain two overlapping afterimages, giving incoming attacks a 35% chance to miss."
	maintained = TRUE
	cooldown_time = 0
	strain_gain = 10
	active_strain_gain_per_second = 8
	block_charge_cost = 0

/datum/action/cooldown/psionic/spit_image
	name = "Spit Image"
	desc = "Blur your outline with two overlapping afterimages. Incoming attacks have a 35% chance to miss, at a cost of 8 strain per second. Toggle to dismiss."
	button_icon_state = "psi_spit_image"
	point_cost = 2
	school = PSIONIC_SCHOOL_HALLUCINATION
	psionic_flags = PSIONIC_SENSORY
	variant_type = /datum/psionic_rank_variant/spit_image
	rank_variant_types = list(/datum/psionic_rank_variant/spit_image)
	maintain_end_message = "Your afterimages merge back into your outline."
	/// Chance for an incoming attack to strike a false outline.
	var/miss_chance = 45
	/// Noninteractive copies attached to the caster, following movement automatically.
	var/list/afterimages = list()

/datum/action/cooldown/psionic/spit_image/psionic_activate(atom/target)
	var/mob/living/living_owner = owner
	if(!can_maintain(living_owner, living_owner.get_psionic_profile()))
		return FALSE
	for(var/offset in list(-4, 4))
		var/obj/effect/abstract/afterimage = new
		afterimages += afterimage
		living_owner.vis_contents += afterimage
	RegisterSignal(living_owner, COMSIG_ATOM_UPDATED_ICON, PROC_REF(update_afterimages))
	RegisterSignal(living_owner, COMSIG_ATOM_PRE_BULLET_ACT, PROC_REF(on_pre_bullet))
	RegisterSignal(living_owner, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(on_check_block))
	start_maintaining(living_owner)
	update_afterimages(living_owner)
	living_owner.visible_message(span_notice("[living_owner]'s outline blurs into overlapping afterimages."))
	return TRUE

/// Copy the complete worn appearance without adding overlays back onto the caster.
/datum/action/cooldown/psionic/spit_image/proc/update_afterimages(mob/living/source)
	SIGNAL_HANDLER
	var/offset = -4
	for(var/obj/effect/abstract/afterimage as anything in afterimages)
		afterimage.appearance = copy_appearance_filter_overlays(source.appearance)
		afterimage.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		afterimage.vis_flags = VIS_INHERIT_DIR | VIS_INHERIT_PLANE
		afterimage.pixel_x = offset
		afterimage.pixel_y = 0
		afterimage.alpha = 75
		offset += 8

/datum/action/cooldown/psionic/spit_image/maintain_tick(mob/living/living_owner, datum/component/psionic_profile/profile, seconds_per_tick)
	if(!get_form() || !..())
		return FALSE
	update_afterimages(living_owner)
	return TRUE

/// Validate upkeep at impact time so suppression cannot leave a stale dodge active.
/datum/action/cooldown/psionic/spit_image/proc/try_miss(mob/living/source)
	if(!is_maintaining() || source != owner)
		return FALSE
	if(!get_form() || !can_maintain(source, source.get_psionic_profile()))
		stop_maintaining(source)
		return FALSE
	if(!prob(miss_chance))
		return FALSE
	source.balloon_alert_to_viewers("miss!")
	return TRUE

/datum/action/cooldown/psionic/spit_image/proc/on_pre_bullet(mob/living/source, obj/projectile/hitting_projectile, def_zone, piercing_hit)
	SIGNAL_HANDLER
	return try_miss(source) ? COMPONENT_BULLET_PIERCED : NONE

/datum/action/cooldown/psionic/spit_image/proc/on_check_block(mob/living/source, atom/hit_by, damage, attack_text, attack_type, armour_penetration, damage_type)
	SIGNAL_HANDLER
	// Projectiles already rolled before bullet_act; never give them a second roll.
	if(attack_type == PROJECTILE_ATTACK)
		return FAILED_BLOCK
	return try_miss(source) ? SUCCESSFUL_BLOCK : FAILED_BLOCK

/datum/action/cooldown/psionic/spit_image/on_maintain_stopped(mob/living/living_owner, silent = FALSE)
	if(living_owner)
		UnregisterSignal(living_owner, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_PRE_BULLET_ACT, COMSIG_LIVING_CHECK_BLOCK))
		living_owner.vis_contents -= afterimages
	QDEL_LIST(afterimages)
