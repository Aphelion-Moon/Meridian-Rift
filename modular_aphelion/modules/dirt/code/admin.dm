ADMIN_VERB(dirt_apply, R_ADMIN, "Apply Dirt", "Puts semen on a human's skin: a zone, then a level and variant, or at random as a climax lands it.", ADMIN_CATEGORY_DEBUG)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_VIEW, /mob/living/carbon/human)
	VERB_ARG_LIST(zone, dirt_semen_zones())
	if(!ishuman(target))
		to_chat(user, span_warning("Only humans take dirt."), confidential = TRUE)
		return
	var/list/levels = list("Random")
	for(var/level in 1 to DIRT_SEMEN_MAX_LEVEL)
		levels += "[level]"
	var/level_choice = tgui_input_list(user, "Level, or Random to land as a climax does", "Apply Dirt", levels)
	if(isnull(level_choice) || QDELETED(target))
		return
	var/described
	if(level_choice == "Random")
		dirt_semen_land(target, zone)
		described = "[zone] semen as a climax lands it"
	else
		var/list/variants = list("Random")
		for(var/variant in 0 to DIRT_SEMEN_VARIANTS - 1)
			variants += "[variant]"
		var/variant_choice = tgui_input_list(user, "Variant", "Apply Dirt", variants)
		if(isnull(variant_choice) || QDELETED(target))
			return
		// a variant always given, so a new splat starts at the level picked
		var/datum/component/dirtiness/carrier = target.LoadComponent(/datum/component/dirtiness)
		var/variant = variant_choice == "Random" ? carrier.fresh_semen_variant(zone) : text2num(variant_choice)
		var/datum/dirt_splat/splat = dirt_semen_place(target, zone, text2num(level_choice), variant)
		described = "[zone] semen at level [splat.level], variant [splat.variant]"
	to_chat(user, span_notice("You put [described] on [target]."), confidential = TRUE)
	message_admins("[key_name_admin(user)] used Apply Dirt to put [described] on [ADMIN_LOOKUPFLW(target)].")
	log_admin("[key_name(user)] used Apply Dirt to put [described] on [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Apply Dirt")

ADMIN_VERB(dirt_clear, R_ADMIN, "Clear Dirt", "Takes all dirt off a human: skin, parts and worn items.", ADMIN_CATEGORY_DEBUG)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_VIEW, /mob/living/carbon/human)
	if(!ishuman(target))
		to_chat(user, span_warning("Only humans take dirt."), confidential = TRUE)
		return
	for(var/datum/component/dirtiness/carrier as anything in dirt_semen_carriers(target))
		carrier.clear_semen()
	to_chat(user, span_notice("You took the dirt off [target]."), confidential = TRUE)
	message_admins("[key_name_admin(user)] used Clear Dirt on [ADMIN_LOOKUPFLW(target)].")
	log_admin("[key_name(user)] used Clear Dirt on [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Clear Dirt")
