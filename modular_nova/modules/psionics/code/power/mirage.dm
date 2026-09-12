#define PSIONIC_MIRAGE_STATIONARY "Stationary"
#define PSIONIC_MIRAGE_FLEE "Flee"
#define PSIONIC_MIRAGE_DISTRACT "Distract"
#define PSIONIC_MIRAGE_LIFETIME (20 SECONDS)
#define PSIONIC_MIRAGE_MOVE_DELAY (0.4 SECONDS)
#define PSIONIC_MIRAGE_DISTRACTION_RANGE 5

/** A Gamma illusion with no school-spending prerequisite. */
/datum/psionic_power/mirage
	action_type = /datum/action/cooldown/psionic/pointed/mirage

/** One fragile double; movement commands do not extend its lifetime or charge strain. */
/datum/psionic_rank_variant/mirage
	rank = PSIONIC_RANK_GAMMA
	variant_name = "false double"
	description = "Create one harmless, passable double for 20 seconds. Touch or damage destroys it. Allows strain recovery."
	strain_gain = 20
	cooldown_time = 8 SECONDS
	cast_range = 5

/** Creates and commands one disposable copy without granting remote interaction or vision. */
/datum/action/cooldown/psionic/pointed/mirage
	name = "Mirage"
	desc = "Left-click to create or replace your double. Right-click the world to cycle Stationary, Flee, and Distract for both the current double and future casts. Shift-click a visible destination to send the current double there. Alt-click to dismiss it. The button toggles targeting."
	button_icon_state = "psi_mirage" // NOVA EDIT CHANGE - ORIGINAL: button_icon_state = "chrono_phase"
	point_cost = 2
	school = PSIONIC_SCHOOL_HALLUCINATION
	psionic_flags = PSIONIC_SENSORY
	allow_self_target = TRUE
	unset_after_click = FALSE
	variant_type = /datum/psionic_rank_variant/mirage
	rank_variant_types = list(/datum/psionic_rank_variant/mirage)
	/// The only double owned by this action; its deletion signal clears this reference.
	var/mob/living/basic/illusion/psionic_mirage/active_mirage
	/// Default for future casts, also applied to the current double when cycled.
	var/mirage_mode = PSIONIC_MIRAGE_STATIONARY

/datum/action/cooldown/psionic/pointed/mirage/Remove(mob/remove_from)
	QDEL_NULL(active_mirage)
	return ..()

/datum/action/cooldown/psionic/pointed/mirage/IsAvailable(feedback = FALSE)
	if(active_mirage && can_command_mirage())
		return TRUE
	return ..()

/** Commands bypass the cast cooldown, but retain consciousness, rank, burnout, and suppression checks. */
/datum/action/cooldown/psionic/pointed/mirage/proc/can_command_mirage()
	var/mob/living/living_owner = owner
	return get_form() && can_maintain(living_owner, living_owner?.get_psionic_profile()) && isturf(living_owner.loc)

/datum/action/cooldown/psionic/pointed/mirage/before_psionic(atom/target)
	if(next_use_time > world.time)
		owner.balloon_alert(owner, "mirage recovering!")
		return FALSE
	return can_command_mirage()

/datum/action/cooldown/psionic/pointed/mirage/is_valid_target(atom/target)
	if(!..())
		return FALSE
	var/turf/destination = get_turf(target)
	var/mob/living/living_owner = owner
	if(!isturf(living_owner.loc) || living_owner.is_blind() || destination.z != living_owner.z)
		return FALSE
	if(!isopenturf(destination) || destination.is_blocked_turf(exclude_mobs = TRUE))
		owner.balloon_alert(owner, "no space for a mirage!")
		return FALSE
	return TRUE

/datum/action/cooldown/psionic/pointed/mirage/InterceptClickOn(mob/living/clicker, params, atom/target)
	if(clicker != owner || istype(target, /atom/movable/screen))
		return FALSE
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, ALT_CLICK))
		QDEL_NULL(active_mirage)
		clicker.balloon_alert(clicker, "mirage dismissed")
		return TRUE
	if(!can_command_mirage())
		return FALSE
	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		switch(mirage_mode)
			if(PSIONIC_MIRAGE_STATIONARY)
				mirage_mode = PSIONIC_MIRAGE_FLEE
			if(PSIONIC_MIRAGE_FLEE)
				mirage_mode = PSIONIC_MIRAGE_DISTRACT
			else
				mirage_mode = PSIONIC_MIRAGE_STATIONARY
		active_mirage?.set_mode(mirage_mode)
		to_chat(clicker, span_notice("Mirage: [mirage_mode]. [active_mirage ? "Your current double and future casts use this behavior." : "Your next double will use this behavior."]"))
		return TRUE
	if(LAZYACCESS(modifiers, SHIFT_CLICK))
		if(!active_mirage)
			clicker.balloon_alert(clicker, "create a mirage first!")
			return TRUE
		if(!is_valid_target(target))
			return TRUE
		active_mirage.set_mode(PSIONIC_MIRAGE_FLEE, get_turf(target))
		to_chat(clicker, span_notice("Your current mirage flees toward that destination. Future casts remain set to [mirage_mode]."))
		return TRUE
	return ..()

/datum/action/cooldown/psionic/pointed/mirage/psionic_activate(atom/target)
	QDEL_NULL(active_mirage)
	active_mirage = new(get_turf(target), owner, src)
	RegisterSignal(active_mirage, COMSIG_QDELETING, PROC_REF(on_mirage_deleted))
	active_mirage.set_mode(mirage_mode)
	owner.log_message("created a [mirage_mode] Mirage at [AREACOORD(active_mirage)].", LOG_GAME)
	playsound(active_mirage, 'sound/effects/magic/magic_missile.ogg', 35, TRUE)
	owner.balloon_alert(owner, "mirage formed")
	return TRUE

/datum/action/cooldown/psionic/pointed/mirage/proc/on_mirage_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	active_mirage = null

/** A nonphysical snapshot of its caster. It has no AI, hands, attacks, or independent senses for the caster. */
/mob/living/basic/illusion/psionic_mirage
	ai_controller = null
	health = 1
	maxHealth = 1
	melee_damage_lower = 0
	melee_damage_upper = 0
	obj_damage = 0
	density = FALSE
	pass_flags = PASSMOB
	status_flags = NONE
	mob_size = MOB_SIZE_SMALL
	sentience_type = SENTIENCE_BOSS
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	environment_smash = ENVIRONMENT_SMASH_NONE
	/// Owning action, which validates the caster and selected rank.
	var/datum/weakref/mirage_action_ref
	/// Alternate appearance owned by this double and removed on deletion.
	var/datum/atom_hud/alternate_appearance/basic/psionic_mirage/revealed_appearance
	/// Current behavior; commands may differ from the action's next-cast default.
	var/current_mode = PSIONIC_MIRAGE_STATIONARY
	/// Timer prevents an expired double from surviving between mob life ticks.
	var/expiry_timer

/mob/living/basic/illusion/psionic_mirage/Initialize(mapload, mob/living/original, datum/action/cooldown/psionic/pointed/mirage/action)
	. = ..()
	if(!original || !action)
		return INITIALIZE_HINT_QDEL
	parent_mob_ref = WEAKREF(original)
	mirage_action_ref = WEAKREF(action)
	appearance = original.appearance
	setDir(original.dir)
	SET_FACTION_AND_ALLIES_FROM(src, original)
	ADD_TRAIT(src, TRAIT_UNDENSE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_PULL_BLOCKED, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_HANDS_BLOCKED, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_FLOATING_ANIM, INNATE_TRAIT)
	RegisterSignals(original, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT), PROC_REF(on_caster_lost))
	RegisterSignal(original, COMSIG_ATOM_PSIONIC_DISPEL, PROC_REF(on_caster_dispelled))
	RegisterSignal(original, SIGNAL_ADDTRAIT(TRAIT_PSIONIC_DAMPENER), PROC_REF(on_caster_dampened))
	RegisterSignal(src, COMSIG_ATOM_DIR_CHANGE, PROC_REF(on_direction_changed))
	AddElement(/datum/element/psionic_dispellable)
	var/image/revealed_image = image(loc = src)
	revealed_image.appearance = appearance
	revealed_image.alpha = 90
	revealed_image.color = get_psionic_school(PSIONIC_SCHOOL_HALLUCINATION).ui_color
	revealed_image.override = TRUE
	revealed_appearance = add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/psionic_mirage, "psionic_mirage", revealed_image, src)
	expiry_timer = addtimer(CALLBACK(src, PROC_REF(fade)), PSIONIC_MIRAGE_LIFETIME, TIMER_STOPPABLE|TIMER_DELETE_ME)

/mob/living/basic/illusion/psionic_mirage/Destroy()
	deltimer(expiry_timer)
	GLOB.move_manager.stop_looping(src)
	var/mob/living/original = parent_mob_ref?.resolve()
	if(original)
		UnregisterSignal(original, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT, COMSIG_ATOM_PSIONIC_DISPEL, SIGNAL_ADDTRAIT(TRAIT_PSIONIC_DAMPENER)))
	UnregisterSignal(src, COMSIG_ATOM_DIR_CHANGE)
	QDEL_NULL(revealed_appearance)
	parent_mob_ref = null
	mirage_action_ref = null
	return ..()

/mob/living/basic/illusion/psionic_mirage/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(QDELETED(src))
		return
	var/datum/action/cooldown/psionic/pointed/mirage/action = mirage_action_ref?.resolve()
	var/turf/caster_turf = get_turf(action?.owner)
	if(!action?.can_command_mirage() || caster_turf?.z != z)
		fade()
		return
	for(var/mob/viewer as anything in GLOB.player_list)
		revealed_appearance.check_hud(viewer)
	if(current_mode == PSIONIC_MIRAGE_DISTRACT)
		distract_pursuers()

/** Changes this double immediately. A destination applies only to this instance's fleeing behavior. */
/mob/living/basic/illusion/psionic_mirage/proc/set_mode(new_mode, turf/destination)
	if(!(new_mode in list(PSIONIC_MIRAGE_STATIONARY, PSIONIC_MIRAGE_FLEE, PSIONIC_MIRAGE_DISTRACT)))
		return FALSE
	GLOB.move_manager.stop_looping(src)
	current_mode = new_mode
	if(current_mode == PSIONIC_MIRAGE_FLEE)
		if(destination)
			GLOB.move_manager.move_to(src, destination, min_dist = 0, delay = PSIONIC_MIRAGE_MOVE_DELAY)
		else
			GLOB.move_manager.move_away(src, parent_mob_ref.resolve(), max_dist = PSIONIC_MIRAGE_DISTRACTION_RANGE, delay = PSIONIC_MIRAGE_MOVE_DELAY)
	else if(current_mode == PSIONIC_MIRAGE_DISTRACT)
		distract_pursuers()
	return TRUE

/** Redirects eligible basic NPCs already pursuing the caster, retaining each NPC's normal target validation. */
/mob/living/basic/illusion/psionic_mirage/proc/distract_pursuers()
	var/mob/living/original = parent_mob_ref.resolve()
	for(var/mob/living/basic/pursuer in oview(PSIONIC_MIRAGE_DISTRACTION_RANGE, src))
		if(pursuer.client || pursuer.mind || IS_UNCONSCIOUS_OR_CRIT(pursuer) || pursuer.sentience_type == SENTIENCE_BOSS || (FACTION_BOSS in pursuer.faction))
			continue
		var/datum/ai_controller/controller = pursuer.ai_controller
		if(!controller || controller.blackboard[BB_CURRENT_TARGET] != original || is_revealed_to(pursuer))
			continue
		var/strategy_type = controller.blackboard[BB_TARGETING_STRATEGY]
		if(!ispath(strategy_type, /datum/targeting_strategy))
			continue
		var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(strategy_type)
		if(!strategy.is_valid_target(pursuer, src, PSIONIC_MIRAGE_DISTRACTION_RANGE, controller))
			continue
		controller.cancel_current_plan()
		controller.set_blackboard_key(BB_CURRENT_TARGET, src)
		original.log_message("distracted [pursuer] with Mirage at [AREACOORD(src)].", LOG_GAME)

/** Queries mental protection without consuming charges or invoking protection feedback. */
/mob/living/basic/illusion/psionic_mirage/proc/is_revealed_to(mob/viewer)
	if(!viewer)
		return FALSE
	if(viewer == parent_mob_ref?.resolve() || isobserver(viewer) || viewer.has_free_psionic_block(PSIONIC_SENSORY))
		return TRUE
	var/list/protection_sources = list()
	var/list/protection_components = list()
	SEND_SIGNAL(viewer, COMSIG_MOB_RECEIVE_PSIONICS, PSIONIC_SENSORY, 0, protection_sources, protection_components)
	return length(protection_components) > 0

/mob/living/basic/illusion/psionic_mirage/examine(mob/user)
	if(is_revealed_to(user))
		return list(span_notice("A translucent red mirage of [name]. A touch will unravel it."))
	return list(span_notice("This figure looks just like [name]."))

/mob/living/basic/illusion/psionic_mirage/attack_hand(mob/living/carbon/human/user, list/modifiers)
	user.log_message("dispelled [name]'s Mirage by touch at [AREACOORD(src)].", LOG_GAME)
	fade()
	return TRUE

/mob/living/basic/illusion/psionic_mirage/UnarmedAttack(atom/target, proximity_flag, list/modifiers)
	return FALSE

/mob/living/basic/illusion/psionic_mirage/melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	return FALSE

/mob/living/basic/illusion/psionic_mirage/Bump(atom/bumped_atom)
	return

/mob/living/basic/illusion/psionic_mirage/can_be_pulled(user, force)
	return FALSE

/** Dissolves the visible double before deleting its movement, signals, timer, and alternate appearance. */
/mob/living/basic/illusion/psionic_mirage/proc/fade()
	if(QDELETED(src))
		return
	visible_message(span_notice("[src] unravels into a red shimmer."))
	qdel(src)

/mob/living/basic/illusion/psionic_mirage/proc/on_caster_lost(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/mob/living/basic/illusion/psionic_mirage/proc/on_caster_dispelled(atom/source, atom/dispeller)
	SIGNAL_HANDLER
	fade()
	return COMPONENT_PSIONIC_DISPELLED

/mob/living/basic/illusion/psionic_mirage/proc/on_caster_dampened(datum/source)
	SIGNAL_HANDLER
	var/datum/action/cooldown/psionic/pointed/mirage/action = mirage_action_ref.resolve()
	if(!action?.can_command_mirage())
		fade()

/mob/living/basic/illusion/psionic_mirage/proc/on_direction_changed(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	var/image/revealed_image = revealed_appearance?.image
	if(revealed_image)
		revealed_image.dir = new_dir

/** Shows the false red silhouette to the creator, ghosts, and observers with active mental protection. */
/datum/atom_hud/alternate_appearance/basic/psionic_mirage
	signals_registering = list(COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, COMSIG_MOB_RESET_PERSPECTIVE)
	/// Double whose observer-specific protection checks determine visibility.
	var/datum/weakref/mirage_ref

/datum/atom_hud/alternate_appearance/basic/psionic_mirage/New(key, image/revealed_image, mob/living/basic/illusion/psionic_mirage/mirage)
	mirage_ref = WEAKREF(mirage)
	. = ..(key, revealed_image, NONE)
	for(var/mob/viewer as anything in GLOB.player_list)
		check_hud(viewer)

/datum/atom_hud/alternate_appearance/basic/psionic_mirage/mobShouldSee(mob/viewer)
	var/mob/living/basic/illusion/psionic_mirage/mirage = mirage_ref?.resolve()
	return !!mirage?.is_revealed_to(viewer)

/datum/atom_hud/alternate_appearance/basic/psionic_mirage/check_hud(mob/source)
	. = ..()
	if(!source.client || !image)
		return
	// The HUD normally filters by the viewer's body z-level; the image must also follow camera perspectives.
	if(hud_users_all_z_levels[source])
		source.client.images |= image
	else
		source.client.images -= image

/datum/atom_hud/alternate_appearance/basic/psionic_mirage/track_mob(mob/new_viewer)
	. = ..()
	RegisterSignal(new_viewer, COMSIG_MOB_LOGOUT, PROC_REF(on_viewer_logout))

/datum/atom_hud/alternate_appearance/basic/psionic_mirage/untrack_mob(mob/former_viewer)
	UnregisterSignal(former_viewer, COMSIG_MOB_LOGOUT)
	return ..()

/datum/atom_hud/alternate_appearance/basic/psionic_mirage/proc/on_viewer_logout(datum/source)
	SIGNAL_HANDLER
	hide_from(source, absolute = TRUE)

/datum/atom_hud/alternate_appearance/basic/psionic_mirage/hide_from(mob/former_viewer, absolute)
	. = ..()
	if(!former_viewer || hud_users_all_z_levels[former_viewer])
		return
	former_viewer.client?.images -= image
	// Looking between z-levels can put a viewer in a different HUD bucket from their body's turf.
	for(var/list/viewers_on_level as anything in hud_users)
		viewers_on_level -= former_viewer

#undef PSIONIC_MIRAGE_STATIONARY
#undef PSIONIC_MIRAGE_FLEE
#undef PSIONIC_MIRAGE_DISTRACT
#undef PSIONIC_MIRAGE_LIFETIME
#undef PSIONIC_MIRAGE_MOVE_DELAY
#undef PSIONIC_MIRAGE_DISTRACTION_RANGE
