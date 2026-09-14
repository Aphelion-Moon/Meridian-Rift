/// Normal in-round selection stays restricted to its existing departments.
/proc/cyborg_selectable_models()
	var/list/models = list(
		"Engineering" = /obj/item/robot_model/engineering,
		"Medical" = /obj/item/robot_model/medical,
		"Cargo" = /obj/item/robot_model/cargo,
		"Miner" = /obj/item/robot_model/miner,
		"Janitor" = /obj/item/robot_model/janitor,
		"Service" = /obj/item/robot_model/service,
	)
	if(!CONFIG_GET(flag/disable_peaceborg))
		models["Peacekeeper"] = /obj/item/robot_model/peacekeeper
	if(!CONFIG_GET(flag/disable_secborg))
		models["Security"] = /obj/item/robot_model/security
	return models

/// Appearance previews/defaults also support bodies obtained through antagonist roles.
/proc/cyborg_appearance_models()
	var/list/models = cyborg_selectable_models()
	models["Syndicate"] = /obj/item/robot_model/syndicatejack
	models["Syndicate Assault"] = /obj/item/robot_model/syndicate
	models["Syndicate Medical"] = /obj/item/robot_model/syndicate_medical
	models["Syndicate Saboteur"] = /obj/item/robot_model/saboteur
	models["Ninja"] = /obj/item/robot_model/ninja
	return models

/// Display names and mutable icon states are deliberately not identities.
/proc/cyborg_appearance_model_id(model_type, skin_id)
	if(!ispath(model_type, /obj/item/robot_model) || !istext(skin_id) || !length(skin_id))
		return null
	// These role variants share one appearance family, while retaining their tools/laws.
	switch(model_type)
		if(/obj/item/robot_model/syndicatejack/marauder)
			model_type = /obj/item/robot_model/syndicatejack
		if(/obj/item/robot_model/ninja/ninja_medical, /obj/item/robot_model/ninja_saboteur)
			model_type = /obj/item/robot_model/ninja
	return "[model_type]#[skin_id]"

/// Canonicalize stored IDs too, so old variant defaults remain usable.
/proc/cyborg_canonical_model_id(model_id)
	if(!istext(model_id))
		return null
	var/separator = findtext(model_id, "#")
	if(!separator)
		return null
	return cyborg_appearance_model_id(text2path(copytext(model_id, 1, separator)), copytext(model_id, separator + 1))

/// Cached descriptors contain resources and copied lists only; temporary models have no host.
/proc/cyborg_model_catalog()
	var/static/list/catalogs = list()
	var/list/models = cyborg_appearance_models()
	var/cache_key = models.Join("|")
	if(catalogs[cache_key])
		return catalogs[cache_key]
	var/list/catalog = list()
	for(var/department in models)
		var/obj/item/robot_model/model_type = models[department]
		// BYOND initial() returns null for list-valued instance initializers.
		// The existing null-location model path skips tools/storage/robot registrations.
		// Medical/miner Initialize overrides only append type paths before that guard.
		var/obj/item/robot_model/snapshot = new model_type(null)
		var/list/skins = deep_copy_list(snapshot.borg_skins)
		qdel(snapshot)
		for(var/skin in skins)
			var/list/details = skins[skin]
			// Ignore malformed declarations without manufacturing a playable skin.
			if(!istext(skin) || !islist(details) || !istext(details[SKIN_ICON_STATE]))
				continue
			var/skin_icon = details[SKIN_ICON] || 'icons/mob/silicon/robots.dmi'
			var/skin_state = details[SKIN_ICON_STATE]
			var/list/states = icon_states(skin_icon)
			if(!(skin_state in states))
				continue
			var/list/poses = list("idle")
			for(var/pose in list("rest", "sit", "bellyup", "rest_deep", "rest_alt", "sit_alt"))
				if("[skin_state]-[pose]" in states)
					poses += pose
			var/id = cyborg_appearance_model_id(model_type, skin)
			var/list/features = details[SKIN_FEATURES]
			catalog[id] = list(
				"id" = id,
				"department" = department,
				"skin" = skin,
				"model_type" = model_type,
				"icon" = skin_icon,
				"icon_state" = skin_state,
				"pixel_x" = details[SKIN_PIXEL_X] || 0,
				"pixel_y" = details[SKIN_PIXEL_Y] || 0,
				"features" = islist(features) ? features.Copy() : list(),
				"poses" = poses,
			)
	// Only two config flags affect this catalog (at most four variants).
	catalogs[cache_key] = catalog
	return catalog

/proc/cyborg_catalog_for(datum/preferences/preferences, context)
	return cyborg_model_catalog()

/// Donor keys are accepted only when exactly one current descriptor matches.
/proc/cyborg_model_legacy_id(alias)
	if(!istext(alias))
		return null
	var/list/catalog = cyborg_model_catalog()
	var/match
	for(var/id in catalog)
		var/list/descriptor = catalog[id]
		if(LOWER_TEXT(alias) != LOWER_TEXT("[descriptor["department"]]#[descriptor["skin"]]") && LOWER_TEXT(alias) != LOWER_TEXT(descriptor["icon_state"]))
			continue
		if(match)
			return null
		match = id
	return match

/obj/item/robot_model
	/// Chosen skin identity survives renaming and temporary visual disguises.
	var/cyborg_customization_skin

/obj/item/robot_model/proc/cyborg_customization_id()
	return cyborg_appearance_model_id(type, cyborg_customization_skin)
