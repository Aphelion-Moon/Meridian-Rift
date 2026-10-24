/mob/living/silicon/robot
	/// The spawn snapshot of the character's layouts (see cyborg_body_snapshot()), null when the slot holds a newer schema
	var/list/cyborg_appearance_store
	/// The layout the body shows now - its chassis's saved default, or else the active layout
	var/list/cyborg_appearance_layout
	/// The sprite each part slot shows, from the current layout or else the character's preferences
	var/list/cyborg_appearance_choices
	/// The sprite for each part slot from the character's preferences, for layouts that don't carry their own
	var/list/cyborg_appearance_base_choices
	/// Which part slots the borg has turned on, by slot
	var/list/cyborg_appearance_active = list()
	/// The arousal state of each part slot, by slot. A slot that isn't here is none
	var/list/cyborg_appearance_arousal = list()
	/// Catalog id of the chassis the current layout was picked for
	var/cyborg_appearance_model
	/// The body size the character's preferences ask for
	var/cyborg_appearance_requested_size = 1
	/// The size factor we last applied to the transform, so a change undoes only ours
	var/cyborg_appearance_applied_size = 1
	/// The character slot the spawn snapshot came from
	var/cyborg_appearance_slot
	/// Ckey of the player whose preferences the spawn snapshot came from
	var/cyborg_appearance_owner
	/// Goes up with every change that needs the parts redrawn, and is part of the holder's render key
	var/cyborg_appearance_revision = 0
	/// Whether or not the parts may show at all - the config, the character's genitals toggle and the player's ERP preference together
	var/cyborg_appearance_allowed = FALSE
	/// Whether or not the spawn character allows genitals
	var/cyborg_appearance_character_allowed = FALSE
	/// The image holder that shows the parts to viewers
	var/obj/effect/client_image_holder/cyborg_customization/cyborg_appearance_holder

/// Read by canonical savefile key without introducing a second preference registry.
/proc/cyborg_preference_value(datum/preferences/preferences, key)
	if(!preferences)
		return null
	var/datum/preference/preference = GLOB.preference_entries_by_key[key]
	return preference ? preferences.read_preference(preference.type) : null

/proc/cyborg_visuals_allowed(datum/preferences/preferences)
	return preferences && !CONFIG_GET(flag/disable_erp_preferences) \
		&& preferences.read_preference(/datum/preference/toggle/master_erp_preferences) \
		&& preferences.read_preference(/datum/preference/toggle/allow_genitals)

/// Silicons other than cyborgs have no customization to apply.
/mob/living/silicon/proc/transfer_cyborg_customization_pref(client/player_client)
	return

/// Called through transfer_silicon_prefs(), which covers job spawns, ghost roles and mind transfers.
/mob/living/silicon/robot/transfer_cyborg_customization_pref(client/player_client)
	apply_cyborg_customization(src, player_client?.prefs)

/// Preference application is separate from model selection, hardware, laws and names.
/proc/apply_cyborg_customization(mob/living/silicon/robot/robot, datum/preferences/preferences)
	if(!robot || !preferences || robot.shell)
		return
	// The player whose prefs these are. Job spawns apply them before the player enters the body, while its ckey is still null.
	var/owner = preferences.parent?.ckey || robot.ckey
	// Existing bodies keep their spawn snapshot when the same player enters them again.
	if(robot.cyborg_appearance_owner == owner && robot.cyborg_appearance_store)
		robot.cyborg_customization_sync_permissions(preferences)
		robot.cyborg_customization_refresh_model()
		return
	var/list/snapshot = preferences.cyborg_body_snapshot()
	if(!snapshot)
		robot.cyborg_appearance_store = null
		robot.cyborg_appearance_layout = null
		robot.cyborg_appearance_active = list()
		QDEL_NULL(robot.cyborg_appearance_holder)
		// The borg's own interaction panel has no controls left to show, so we close it. A null src_object would close every window it has open
		var/datum/component/interactable/panel = robot.GetComponent(/datum/component/interactable)
		if(panel)
			SStgui.close_user_uis(robot, panel)
		robot.cyborg_customization_message = "This character has a newer layout schema. Its saved data has been preserved."
		return
	var/same_owner = robot.cyborg_appearance_owner == owner && robot.cyborg_appearance_slot == preferences.default_slot
	if(!same_owner)
		robot.cyborg_appearance_active = list()
		robot.cyborg_appearance_arousal = list()
	robot.cyborg_appearance_owner = owner
	robot.cyborg_appearance_slot = preferences.default_slot
	robot.cyborg_appearance_store = snapshot
	robot.cyborg_appearance_choices = list()
	for(var/slot in cyborg_layout_supported_slots())
		robot.cyborg_appearance_choices[slot] = cyborg_preference_value(preferences, "silicon_[slot]_sprite")
	robot.cyborg_appearance_base_choices = robot.cyborg_appearance_choices.Copy()
	robot.cyborg_appearance_character_allowed = preferences.read_preference(/datum/preference/toggle/allow_genitals)
	robot.cyborg_customization_sync_permissions(preferences)
	robot.cyborg_appearance_requested_size = text2num("[cyborg_preference_value(preferences, "cyborg_size")]") || 1
	robot.cyborg_appearance_model = null
	robot.cyborg_customization_refresh_model()

/// Keep a body bound to its spawn profile even if the creator selects another slot.
/mob/living/silicon/robot/proc/cyborg_customization_sync_permissions(datum/preferences/preferences)
	if(!preferences)
		return
	if(cyborg_appearance_slot == preferences.default_slot)
		cyborg_appearance_character_allowed = preferences.read_preference(/datum/preference/toggle/allow_genitals)
	var/allowed = !CONFIG_GET(flag/disable_erp_preferences) && cyborg_appearance_character_allowed \
		&& preferences.read_preference(/datum/preference/toggle/master_erp_preferences)
	if(allowed == cyborg_appearance_allowed)
		return
	cyborg_appearance_allowed = allowed
	cyborg_appearance_revision++
	cyborg_customization_update_render()

/mob/living/silicon/robot/proc/cyborg_customization_refresh_model()
	if(!cyborg_appearance_store || !model)
		return
	var/model_id = model.cyborg_customization_id()
	if(cyborg_appearance_model != model_id || !cyborg_appearance_layout)
		cyborg_appearance_model = model_id
		var/list/model_default = cyborg_appearance_model_default(model_id)
		cyborg_appearance_layout = cyborg_layout_copy(model_default || cyborg_appearance_store["active"])
		cyborg_appearance_choices = cyborg_layout_choices(cyborg_appearance_layout, cyborg_appearance_base_choices || cyborg_appearance_choices)
		for(var/slot in cyborg_layout_supported_slots())
			if(isnull(cyborg_appearance_active[slot]) && cyborg_appearance_choices[slot] && cyborg_appearance_choices[slot] != SPRITE_ACCESSORY_NONE)
				cyborg_appearance_active[slot] = TRUE
		cyborg_appearance_revision++
	cyborg_customization_apply_size()
	cyborg_customization_update_render()

/// The body's saved default for a chassis, or null. A body that kept save text decodes each one the first time it is asked for.
/mob/living/silicon/robot/proc/cyborg_appearance_model_default(model_id)
	if(!model_id || !cyborg_appearance_store)
		return null
	var/text = cyborg_appearance_store["text"]
	if(text && !(model_id in cyborg_appearance_store["model_defaults"]))
		// FALSE remembers that there is none, so asking again decodes nothing.
		LAZYSET(cyborg_appearance_store["model_defaults"], model_id, cyborg_layout_decode_for_body(text, model_id, with_active = FALSE)?["model_default"] || FALSE)
	return LAZYACCESS(cyborg_appearance_store["model_defaults"], model_id) || null

/// Old presets inherit character choices; newer presets carry their selected parts.
/proc/cyborg_layout_choices(list/layout, list/fallback)
	var/list/choices = list()
	for(var/slot in cyborg_layout_supported_slots())
		var/sprite = layout?[slot]?["sprite"]
		choices[slot] = isnull(sprite) ? fallback?[slot] : sprite
	return choices

/proc/cyborg_effective_base_size(requested, list/model_features, eligible = TRUE)
	if(!eligible || !(requested in list(0.75, 1, 1.6, 2, 2.5)))
		return 1
	if(TRAIT_R_SMALL in model_features)
		return max(1, requested)
	if((TRAIT_R_WIDE in model_features) || (TRAIT_R_TALL in model_features))
		return min(requested, 1.6)
	return requested

/mob/living/silicon/robot/proc/cyborg_customization_apply_size()
	if(!model || HAS_TRAIT(src, TRAIT_NO_TRANSFORM))
		return
	var/list/catalog = cyborg_model_catalog()
	var/model_id = model.cyborg_customization_id()
	// A null would take the argument's default, TRUE, and give a chassis outside the catalog the cosmetic size.
	var/effective = cyborg_effective_base_size(cyborg_appearance_requested_size, model.model_features, !!(model_id && catalog[model_id]))
	if(effective == cyborg_appearance_applied_size)
		return
	// Remove only our previous factor. Hardware's existing transform remains intact.
	var/ratio = effective / cyborg_appearance_applied_size
	cyborg_appearance_applied_size = effective
	update_transform(ratio)

/mob/living/silicon/robot/proc/cyborg_customization_pose()
	switch(robot_resting)
		if(ROBOT_REST_NORMAL)
			return "rest"
		if(ROBOT_REST_SITTING)
			return "sit"
		if(ROBOT_REST_BELLY_UP)
			return "bellyup"
		if(ROBOT_REST_SLEEP)
			return "rest_deep"
		if(ROBOT_REST_NORMAL_ALT)
			return "rest_alt"
		if(ROBOT_REST_SITTING_ALT)
			return "sit_alt"
	return "idle"

/proc/cyborg_part_capability(mob/living/silicon/robot/robot, slot)
	var/configured = robot.cyborg_appearance_allowed && robot.cyborg_appearance_choices?[slot] && robot.cyborg_appearance_choices[slot] != SPRITE_ACCESSORY_NONE
	var/enabled = configured && robot.cyborg_appearance_active[slot]
	var/list/placement = robot.cyborg_appearance_layout?[slot]
	var/list/directional = placement ? cyborg_resolve_placement(placement, robot.dir, robot.cyborg_customization_pose(), robot.cyborg_appearance_arousal[slot] || "none") : null
	return list("configured" = !!configured, "enabled" = !!enabled, "exposed" = !!(enabled && directional?["visible"] && cyborg_body_visuals_visible(robot)))

/// Rendering and examine share this - death, a disguise or being tipped over hide the parts, lockdown and stuns do not
/proc/cyborg_body_visuals_visible(mob/living/silicon/robot/robot)
	if(!robot || !robot.model || !robot.cyborg_appearance_allowed || CONFIG_GET(flag/disable_erp_preferences) || robot.stat == DEAD || HAS_TRAIT_FROM(robot, TRAIT_IMMOBILIZED, TIPPED_OVER))
		return FALSE
	var/list/catalog = cyborg_model_catalog()
	var/list/descriptor = robot.cyborg_appearance_model ? catalog[robot.cyborg_appearance_model] : null
	if(!descriptor || robot.icon != descriptor["icon"] || robot.model.cyborg_base_icon != descriptor["icon_state"])
		return FALSE
	var/expected_state = descriptor["icon_state"]
	var/pose = robot.cyborg_customization_pose()
	if(pose != "idle")
		expected_state += "-[pose]"
	return robot.icon_state == expected_state
