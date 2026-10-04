/// -- Outfit and mob helpers to equip our loadout items. --

/// An empty outfit we fill in with our loadout items to dress our dummy.
/datum/outfit/player_loadout
	name = "Player Loadout"

/datum/outfit/player_loadout/equip(mob/living/carbon/human/user, visualsOnly)
	. = ..()
	if(!user.client)
		return // no client to pull a loadout from (e.g. a preview dummy) - nothing to equip
	user.equip_outfit_and_loadout(new /datum/outfit(), user.client.prefs)

/*
 * Actually equip our mob with our job outfit and our loadout items.
 * Loadout items override the pre-existing item in the corresponding slot of the job outfit.
 * Some job items are preserved after being overridden - belt items, ear items, and glasses.
 * The rest of the slots, the items are overridden completely and deleted.
 *
 * Plasmamen are snowflaked to not have any envirosuit pieces removed just in case.
 * Their loadout items for those slots will be added to their backpack on spawn.
 *
 * outfit - the job outfit we're equipping
 * visuals_only - whether we call special equipped procs, or if we just look like we equipped it
 * preference_source - the preferences of the thing we're equipping
 * equipping_job - The job that's being applied.
 */
/mob/living/carbon/human/equip_outfit_and_loadout(
	datum/outfit/outfit = /datum/outfit,
	datum/preferences/preference_source = GLOB.preference_entries_by_key[ckey],
	visuals_only = FALSE,
	datum/job/equipping_job,
	allow_mechanical_loadout_items = TRUE,
)
	if (!preference_source)
		equipOutfit(outfit, visuals_only) // no prefs for loadout items, but we should still equip the outfit.
		return FALSE

	var/datum/outfit/equipped_outfit

	if(ispath(outfit))
		equipped_outfit = new outfit()
	else if(istype(outfit))
		equipped_outfit = outfit
	else
		CRASH("Outfit passed to equip_outfit_and_loadout was neither a path nor an instantiated type!")

	var/override_preference = preference_source.read_preference(/datum/preference/choiced/loadout_override_preference)

	var/list/item_details = preference_source.read_preference(/datum/preference/loadout)
	var/list/loadout_list = item_details[preference_source.read_preference(/datum/preference/loadout_index)]
	var/list/loadout_datums = loadout_list_to_datums(loadout_list)
	var/obj/item/storage/briefcase/empty/briefcase
	var/obj/item/storage/box/cache_pouch/erp/erpbox // NOVA EDIT CHANGE - PERSONAL_CACHE - ORIGINAL: var/obj/item/storage/box/erp/erpbox
	var/obj/item/storage/box/cache_pouch/loadout/pouch // NOVA EDIT ADDITION - PERSONAL_CACHE
	var/erp_enabled = !CONFIG_GET(flag/disable_erp_preferences)
	var/pouch_in_hand = FALSE
	// APHELION EDIT CHANGE START - PERSONAL_CACHE
	if(override_preference == LOADOUT_OVERRIDE_CASE && !visuals_only)
		briefcase = new(loc)
		briefcase.name = "[preference_source.read_preference(/datum/preference/name/real_name)]'s travel suitcase"
	else if(override_preference == LOADOUT_OVERRIDE_CACHE_POUCH && !visuals_only)
		// This destination lives in the outfit's survival box, so equip that first.
		equipOutfit(equipped_outfit, visuals_only)
		var/obj/item/storage/box/survival/cache_box = locate(/obj/item/storage/box/survival) in get_all_gear()
		pouch_in_hand = !istype(cache_box, /obj/item/storage/box/personal_cache) || cache_box.cache_locked
		pouch = new /obj/item/storage/box/cache_pouch/loadout(pouch_in_hand ? loc : cache_box)

	var/obj/item/storage/loadout_container = briefcase || pouch
	for(var/datum/loadout_item/item as anything in loadout_datums)
		if(istype(item, /datum/loadout_item/cache))
			continue // Spawn directly into the customization pass after the outfit exists.
		if(erp_enabled && item.erp_box)
			if(isnull(erpbox))
				erpbox = new(loc)
			new item.item_path(erpbox)
			continue
		if(!item.can_be_applied_to(src, preference_source, equipping_job, allow_mechanical_loadout_items, visuals_only))
			continue
		if(loadout_container)
			var/obj/item/loadout_item = new item.item_path(loadout_container)
			if(pouch)
				loadout_item.AddElement(/datum/element/loadout_pouch_item, REF(pouch))
			continue

		// Preserve species-critical clothing when applying loadout overrides.
		var/datum/outfit/outfit_important_for_life = dna.species.outfit_important_for_life
		if(!outfit_important_for_life || !item.pre_equip_item(equipped_outfit, outfit_important_for_life, src, visuals_only))
			item.insert_path_into_outfit(equipped_outfit, src, visuals_only, override_preference)
	if(!pouch)
		equipOutfit(equipped_outfit, visuals_only)
	if(briefcase || pouch_in_hand)
		INVOKE_ASYNC(src, PROC_REF(put_in_hands), loadout_container)

	var/list/new_contents = loadout_container ? loadout_container.get_all_contents() : get_all_gear()
	var/obj/item/storage/box/personal_cache/cache = locate(/obj/item/storage/box/personal_cache) in get_all_gear()
	// APHELION EDIT CHANGE END

	var/update = NONE
	for(var/datum/loadout_item/item as anything in loadout_datums)
		if(!item.is_equippable(src, loadout_list?[item.item_path] || list()))
			continue
		if(item.restricted_roles && equipping_job && !(equipping_job.title in item.restricted_roles))
			continue

		// APHELION EDIT CHANGE START - PERSONAL_CACHE
		var/obj/item/equipped
		if(istype(item, /datum/loadout_item/cache))
			if(visuals_only || !item.can_be_applied_to(src, preference_source, equipping_job, allow_mechanical_loadout_items, visuals_only))
				continue
			// Use the selected instance, never a matching stock survival item.
			equipped = new item.item_path(loc)
		else if(erpbox && item.erp_box)
			equipped = locate(item.item_path) in erpbox
		else
			equipped = locate(item.item_path) in new_contents
		// APHELION EDIT CHANGE END

		if(isnull(equipped))
			continue

		update |= item.on_equip_item(
			equipped_item = equipped,
			item_details = loadout_list?[item.item_path] || list(),
			equipper = src,
			outfit = equipped_outfit,
			visuals_only = visuals_only,
		)

	if(preference_source?.read_preference(/datum/preference/toggle/green_pin))
		var/obj/item/clothing/under/uniform = w_uniform
		uniform?.attach_accessory(new /obj/item/clothing/accessory/green_pin(), src, FALSE)

	// NOVA EDIT CHANGE START - PERSONAL_CACHE - ORIGINAL: erpbox always went to the briefcase, or was equipped to the best slot (pocket) otherwise
	if (!isnull(erpbox))
		if (!isnull(briefcase))
			briefcase.contents += erpbox
		else if (!isnull(cache))
			erpbox.forceMove(cache)
		else
			erpbox.equip_to_best_slot(src)

	cache?.set_owner(src)
	// NOVA EDIT CHANGE END

	if(update)
		update_clothing(update)

	return TRUE

// cyborgs can wear hats from loadout
/*
 * Actually equip our mob with our job outfit and our loadout items.
 * Loadout items override the pre-existing item in the corresponding slot of the job outfit.
 * Some job items are preserved after being overridden - belt items, ear items, and glasses.
 * The rest of the slots, the items are overridden completely and deleted.
 *
 * Plasmamen are snowflaked to not have any envirosuit pieces removed just in case.
 * Their loadout items for those slots will be added to their backpack on spawn.
 *
 * outfit - the job outfit we're equipping
 * visuals_only - whether we call special equipped procs, or if we just look like we equipped it
 * preference_source - the preferences of the thing we're equipping
 * equipping_job - The job that's being applied.
 */
/mob/living/silicon/robot/proc/equip_outfit_and_loadout(datum/outfit/outfit, datum/preferences/preference_source = GLOB.preference_entries_by_key[ckey], visuals_only = FALSE, datum/job/equipping_job)
	var/list/item_details = preference_source.read_preference(/datum/preference/loadout)
	var/list/loadout_datums = loadout_list_to_datums(item_details[preference_source.read_preference(/datum/preference/loadout_index)])
	for (var/datum/loadout_item/head/item in loadout_datums)
		if (!item.can_be_applied_to(src, preference_source, equipping_job, visuals_only))
			continue
		place_on_head(new item.item_path)
		break


/*
 * Removes all invalid paths from loadout lists.
 *
 * passed_list - the loadout list we're sanitizing.
 *
 * returns a list
 */
/proc/update_loadout_list(list/passed_list)
	RETURN_TYPE(/list)

	var/list/list_to_update = LAZYLISTDUPLICATE(passed_list)
	for(var/thing in list_to_update) //thing, 'cause it could be a lot of things
		if(ispath(thing))
			break
		var/our_path = text2path(list_to_update[thing])

		LAZYREMOVE(list_to_update, thing)
		if(ispath(our_path))
			LAZYSET(list_to_update, our_path, list())

	return list_to_update

/*
 * Removes all invalid paths from loadout lists.
 *
 * passed_list - the loadout list we're sanitizing.
 *
 * returns a list
 */
/proc/sanitize_loadout_list(list/passed_list)
	RETURN_TYPE(/list)

	var/list/list_to_clean = LAZYLISTDUPLICATE(passed_list)
	for(var/path in list_to_clean)
		if(!ispath(path))
			stack_trace("invalid path found in loadout list! (Path: [path])")
			LAZYREMOVE(list_to_clean, path)

		else if(!(path in GLOB.all_loadout_datums))
			stack_trace("invalid loadout slot found in loadout list! Path: [path]")
			LAZYREMOVE(list_to_clean, path)

	return list_to_clean

/obj/item/storage/briefcase/empty/PopulateContents()
	return

// Cyborg loadouts (currently used for hats)
/mob/living/silicon/robot/on_job_equipping(datum/job/equipping, client/player_client)
	. = ..()
	dress_up_as_job(
		equipping = equipping,
		visual_only = FALSE,
		player_client = player_client,
		consistent = FALSE,
	)

// Cyborg loadouts (currently used for hats)
/mob/living/silicon/robot/dress_up_as_job(datum/job/equipping, visual_only = FALSE, client/player_client, consistent = FALSE)
	. = ..()
	equip_outfit_and_loadout(equipping.get_outfit(consistent), player_client?.prefs, visual_only, equipping)

// originally made as a workaround the fact borgs lose their hats on module change, this
// is how borgs can pick up and drop hats

// if a borg clicks a hat, they try to put it on
/obj/item/clothing/head/attack_robot_secondary(mob/living/silicon/robot/user, list/modifiers)
	. = ..()
	if (. != SECONDARY_ATTACK_CALL_NORMAL)
		return

	if (!Adjacent(user))
		return

	balloon_alert(user, "picking up hat...")
	if (!do_after(user, 3 SECONDS, src))
		return
	if (QDELETED(src) || !Adjacent(user) || user.incapacitated)
		return
	user.place_on_head(src)
	balloon_alert(user, "picked up hat")

// if a borg right clicks themself, they try to drop their hat
/mob/living/silicon/robot/attack_robot_secondary(mob/user, list/modifiers)
	. = ..()
	if (. != SECONDARY_ATTACK_CALL_NORMAL)
		return

	if (user != src || isnull(hat))
		return

	balloon_alert(user, "dropping hat...")
	if (!do_after(user, 3 SECONDS, src))
		return
	if (QDELETED(src) || !Adjacent(user) || user.incapacitated || isnull(hat))
		return
	hat.forceMove(get_turf(src))
	hat = null
	update_icons()
	balloon_alert(user, "dropped hat")
