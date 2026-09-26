/mob/living/silicon/robot
	var/list/cyborg_appearance_store
	var/list/cyborg_appearance_layout
	var/list/cyborg_appearance_choices
	var/list/cyborg_appearance_base_choices
	var/list/cyborg_appearance_active = list()
	var/list/cyborg_appearance_arousal = list()
	var/cyborg_appearance_model
	var/cyborg_appearance_requested_size = 1
	var/cyborg_appearance_applied_size = 1
	var/cyborg_appearance_slot
	var/cyborg_appearance_owner
	var/cyborg_appearance_revision = 0
	var/cyborg_appearance_allowed = FALSE
	var/cyborg_appearance_character_allowed = FALSE
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

/// Preference application is separate from model selection, hardware, laws and names.
/proc/apply_cyborg_customization(mob/living/silicon/robot/robot, datum/preferences/preferences, reason)
	if(!robot || !preferences || robot.shell)
		return
	// Existing bodies keep their spawn snapshot, including across reconnects.
	if(reason == "login" && robot.cyborg_appearance_owner == robot.ckey && robot.cyborg_appearance_store)
		robot.cyborg_customization_sync_permissions(preferences)
		robot.cyborg_customization_refresh_model()
		return
	var/list/current
	if(!robot.cyborg_appearance_store || robot.cyborg_appearance_slot == preferences.default_slot || robot.cyborg_appearance_owner != robot.ckey)
		var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
		current = editor.begin_draft()
		if(!current)
			robot.cyborg_appearance_store = null
			robot.cyborg_appearance_layout = null
			robot.cyborg_appearance_active = list()
			QDEL_NULL(robot.cyborg_appearance_holder)
			robot.cyborg_customization_message = "This character has a newer layout schema. Its saved data has been preserved."
			return
	var/same_owner = robot.cyborg_appearance_owner == robot.ckey && robot.cyborg_appearance_slot == preferences.default_slot
	if(!same_owner)
		robot.cyborg_appearance_active = list()
		robot.cyborg_appearance_arousal = list()
	robot.cyborg_appearance_owner = robot.ckey
	robot.cyborg_appearance_slot = preferences.default_slot
	robot.cyborg_appearance_store = cyborg_layout_copy(current)
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
		var/list/model_default = model_id ? cyborg_appearance_store["model_defaults"][model_id] : null
		cyborg_appearance_layout = cyborg_layout_copy(model_default || cyborg_appearance_store["active"])
		cyborg_appearance_choices = cyborg_layout_choices(cyborg_appearance_layout, cyborg_appearance_base_choices || cyborg_appearance_choices)
		for(var/slot in cyborg_layout_supported_slots())
			if(isnull(cyborg_appearance_active[slot]) && cyborg_appearance_choices[slot] && cyborg_appearance_choices[slot] != SPRITE_ACCESSORY_NONE)
				cyborg_appearance_active[slot] = TRUE
		cyborg_appearance_revision++
	cyborg_customization_apply_size()
	cyborg_customization_update_render()

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
	var/effective = cyborg_effective_base_size(cyborg_appearance_requested_size, model.model_features, model_id && !!catalog[model_id])
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

/// Rendering and examine share the same body-level exposure policy.
/proc/cyborg_body_visuals_visible(mob/living/silicon/robot/robot)
	if(!robot || !robot.model || !robot.cyborg_appearance_allowed || CONFIG_GET(flag/disable_erp_preferences) || robot.stat == DEAD || HAS_TRAIT(robot, TRAIT_IMMOBILIZED))
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
