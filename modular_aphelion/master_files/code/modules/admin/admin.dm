// Toggle Combohud Hotkey
/datum/keybinding/admin/combo_hud
	hotkey_keys = list(UNBOUND_KEY)
	name = "combo_hud"
	full_name = "Toggle Combo HUD"
	description = "Toggles the Admin Combo HUD"
	keybind_signal = COMSIG_KB_ADMIN_COMBOHUD_DOWN

/datum/keybinding/admin/combo_hud/down(client/user, turf/target, mousepos_x, mousepos_y)
	. = ..()
	if(.)
		return
	SSadmin_verbs.dynamic_invoke_verb(user, /datum/admin_verb/combo_hud)
	return TRUE

// Toggle Wallhacks Hotkey
/datum/keybinding/admin/wallhacks
	hotkey_keys = list(UNBOUND_KEY)
	name = "wallhacks"
	full_name = "Admin Wallhacks"
	description = "Toggles full-bright, perfect vision through walls, and hearing through walls"
	keybind_signal = COMSIG_KB_ADMIN_WALLHACKS_DOWN

/datum/keybinding/admin/wallhacks/down(client/user, turf/target, mousepos_x, mousepos_y)
	. = ..()
	if(.)
		return
	SSadmin_verbs.dynamic_invoke_verb(user, /datum/admin_verb/wallhacks)
	return TRUE

/client
	/// Whether Admin Wallhacks are currently on. Tracked on the client, like combo_hud_enabled, so the toggle keeps
	/// working across aghosting and possessions instead of reading a trait off whichever mob happens to be current.
	var/admin_wallhacks_enabled = FALSE
	/// Weakref to the mob wallhacks were applied to, so disabling cleans up that mob even after a body change.
	var/datum/weakref/admin_wallhacks_mob_ref
	/// The mob's sight bits from before wallhacks were switched on.
	var/admin_wallhacks_prior_sight
	/// The mob's see_invisible from before wallhacks were switched on.
	var/admin_wallhacks_prior_see_invisible
	/// The mob's lighting_cutoff from before wallhacks were switched on.
	var/admin_wallhacks_prior_lighting_cutoff

/// Switches wallhacks on for the client's current mob, remembering the sight state being replaced.
/client/proc/enable_admin_wallhacks()
	var/mob/target = mob
	if(isnull(target))
		return
	admin_wallhacks_mob_ref = WEAKREF(target)
	admin_wallhacks_prior_sight = target.sight
	admin_wallhacks_prior_see_invisible = target.see_invisible
	admin_wallhacks_prior_lighting_cutoff = target.lighting_cutoff
	admin_wallhacks_enabled = TRUE

	ADD_TRAIT(target, TRAIT_XRAY_HEARING, ADMIN_TRAIT)
	ADD_TRAIT(target, TRAIT_ADMIN_WALLHACKS, ADMIN_TRAIT)
	target.sight |= (SEE_TURFS|SEE_MOBS|SEE_OBJS)
	target.see_invisible = SEE_INVISIBLE_LIVING
	target.lighting_cutoff = LIGHTING_CUTOFF_FULLBRIGHT
	target.update_sight()

/**
 * Switches wallhacks off again, restoring the sight state captured when they were enabled.
 *
 * Restores rather than clearing, so sight bits owned by something else - mesons, an x-ray implant, a cyborg's
 * sight_mode - survive the toggle. Targets the mob wallhacks were applied to, which may not be the current one.
 */
/client/proc/disable_admin_wallhacks()
	admin_wallhacks_enabled = FALSE
	var/mob/target = admin_wallhacks_mob_ref?.resolve()
	admin_wallhacks_mob_ref = null
	if(isnull(target))
		return

	REMOVE_TRAIT(target, TRAIT_XRAY_HEARING, ADMIN_TRAIT)
	REMOVE_TRAIT(target, TRAIT_ADMIN_WALLHACKS, ADMIN_TRAIT)
	target.sight = admin_wallhacks_prior_sight
	target.see_invisible = admin_wallhacks_prior_see_invisible
	target.lighting_cutoff = admin_wallhacks_prior_lighting_cutoff
	target.update_sight()
