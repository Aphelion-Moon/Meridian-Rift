/* Apply Dirt is a debugging helper, temporarily disabled.
ADMIN_VERB(dirt_apply, R_ADMIN, "Apply Dirt", "Puts dirt on a human: mess where a shot at a zone lands it, or a cause's dirt in a material, at a level and variant, or at random.", ADMIN_CATEGORY_DEBUG)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_VIEW, /mob/living/carbon/human)
	VERB_ARG_LIST(kind, dirt_apply_kinds())
	if(!ishuman(target))
		to_chat(user, span_warning("Only humans take dirt."), confidential = TRUE)
		return
	var/described
	if(kind == "Mess")
		var/zone = tgui_input_list(user, "Zone", "Apply Dirt", dirt_mess_zones())
		if(isnull(zone) || QDELETED(target))
			return
		var/list/levels = list("Random")
		for(var/level in 1 to DIRT_MESS_MAX_LEVEL)
			levels += "[level]"
		var/level_choice = tgui_input_list(user, "Level, or Random to land as a shot does", "Apply Dirt", levels)
		if(isnull(level_choice) || QDELETED(target))
			return
		if(level_choice == "Random")
			dirt_mess_land(target, zone)
			described = "[zone] mess as a shot lands it"
		else
			var/list/variants = list("Random")
			for(var/variant in 0 to DIRT_VARIANTS - 1)
				variants += "[variant]"
			var/variant_choice = tgui_input_list(user, "Variant", "Apply Dirt", variants)
			if(isnull(variant_choice) || QDELETED(target))
				return
			// a variant always given, so a new splat starts at the level picked
			var/list/surface = dirt_mess_surface(target, zone)
			var/datum/component/dirtiness/carrier = surface[1]
			var/variant = variant_choice == "Random" ? carrier.fresh_mess_variant(zone, surface[2]) : text2num(variant_choice)
			var/datum/dirt_splat/splat = dirt_mess_place(target, zone, text2num(level_choice), variant)
			described = "[zone] mess at level [splat.level], variant [splat.variant]"
	else
		var/list/causes = dirt_apply_kinds() - list("Mess", "Random")
		var/cause = kind == "Random" ? pick(causes) : kind
		var/material = kind == "Random" ? pick(dirt_general_materials()) : tgui_input_list(user, "Material", "Apply Dirt", dirt_general_materials())
		if(isnull(material) || QDELETED(target))
			return
		var/colour
		if(material == DIRT_MATERIAL_SLIME)
			colour = kind == "Random" ? rgb(rand(0, 255), rand(0, 255), rand(0, 255)) : tgui_input_text(user, "Slime colour, #RRGGBB", "Apply Dirt", "#4FC94A", max_length = 7)
		var/datum/dirt_material/made = dirt_material(material, colour)
		if(!made || QDELETED(target))
			to_chat(user, span_warning("That isn't a colour slime takes."), confidential = TRUE)
			return
		var/top = dirt_cause_max_level(cause)
		var/level = rand(1, top)
		var/variant
		if(kind != "Random")
			var/list/levels = list()
			for(var/each_level in 1 to top)
				levels += "[each_level]"
			var/level_choice = tgui_input_list(user, "Level", "Apply Dirt", levels)
			if(isnull(level_choice) || QDELETED(target))
				return
			level = text2num(level_choice)
			var/list/variants = list("Random")
			for(var/each_variant in 0 to DIRT_VARIANTS - 1)
				variants += "[each_variant]"
			var/variant_choice = tgui_input_list(user, "Variant", "Apply Dirt", variants)
			if(isnull(variant_choice) || QDELETED(target))
				return
			if(variant_choice != "Random")
				variant = text2num(variant_choice)
		var/landed = dirt_land(target, cause, material, level, variant, colour)
		if(!landed)
			to_chat(user, span_warning("Nothing on [target] shows where [cause] dirt lies."), confidential = TRUE)
			return
		described = "[cause] dirt in [made.name][colour ? " ([made.base_colour])" : ""] at level [level], variant [isnull(variant) ? "at random" : variant], on [landed] carrier\s"
	to_chat(user, span_notice("You put [described] on [target]."), confidential = TRUE)
	message_admins("[key_name_admin(user)] used Apply Dirt to put [described] on [ADMIN_LOOKUPFLW(target)].")
	log_admin("[key_name(user)] used Apply Dirt to put [described] on [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Apply Dirt")

/// Returns what Apply Dirt offers: mess, at random, and every general cause. Literals, as a verb's options are read as
/// the world starts. You should NEVER modify it.
/proc/dirt_apply_kinds()
	RETURN_TYPE(/list)
	var/static/list/kinds = list("Mess", "Random", DIRT_CAUSE_WALK, DIRT_CAUSE_KNEEL, DIRT_CAUSE_CRAWL, DIRT_CAUSE_FALL, DIRT_CAUSE_SPLASH, DIRT_CAUSE_MACHINE, DIRT_CAUSE_SMOKE, DIRT_CAUSE_DUST, DIRT_CAUSE_WEAR, DIRT_CAUSE_SWEAT, DIRT_CAUSE_SLIMED, DIRT_CAUSE_PLUNGE, DIRT_CAUSE_BLAST, DIRT_CAUSE_DOUSE, DIRT_CAUSE_SLIMED_HEAD, DIRT_CAUSE_SLIMED_CHEST, DIRT_CAUSE_SLIMED_BACK, DIRT_CAUSE_SLIMED_R_ARM, DIRT_CAUSE_SLIMED_L_ARM, DIRT_CAUSE_SLIMED_R_LEG, DIRT_CAUSE_SLIMED_L_LEG)
	return kinds

/**
 * Returns the general materials, as dirt_land() takes them: every material but mess, slime needing a colour. You
 * should NEVER modify it.
 */
/proc/dirt_general_materials()
	RETURN_TYPE(/list)
	var/static/list/materials = list(DIRT_MATERIAL_MUD, DIRT_MATERIAL_DRIED_MUD, DIRT_MATERIAL_RED_CLAY, DIRT_MATERIAL_DUST, DIRT_MATERIAL_PLASTER, DIRT_MATERIAL_ASH, DIRT_MATERIAL_GRIME, DIRT_MATERIAL_OIL, DIRT_MATERIAL_GREASE, DIRT_MATERIAL_SOOT, DIRT_MATERIAL_SWEAT, DIRT_MATERIAL_SLIME)
	return materials
*/

ADMIN_VERB(dirt_clear, R_ADMIN, "Clear Dirt", "Takes all dirt off a human: skin, parts and worn items.", ADMIN_CATEGORY_DEBUG)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_VIEW, /mob/living/carbon/human)
	if(!ishuman(target))
		to_chat(user, span_warning("Only humans take dirt."), confidential = TRUE)
		return
	for(var/datum/component/dirtiness/carrier as anything in dirt_carriers(target))
		carrier.clear_mess()
	to_chat(user, span_notice("You took the dirt off [target]."), confidential = TRUE)
	message_admins("[key_name_admin(user)] used Clear Dirt on [ADMIN_LOOKUPFLW(target)].")
	log_admin("[key_name(user)] used Clear Dirt on [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Clear Dirt")
