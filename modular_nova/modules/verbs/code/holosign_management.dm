/// Tracks each player's currently-active holosigns placed via Manage Holosigns, keyed by ckey. Admins are exempt from the CONFIG max_player_holosigns cap.
GLOBAL_LIST_EMPTY(holosign_privacy_tracker)

/// How many holosigns one person can have up before admins get a heads-up. Deliberately below the config cap.
#define HOLOSIGN_ADMIN_NOTIFY_THRESHOLD 5

/obj/structure/holosign/privacy
	/// ckey of whoever placed this through Manage Holosigns, if anyone. Null for signs made any other way.
	var/managed_by_ckey

/obj/structure/holosign/privacy/Destroy()
	// Cleaning up here rather than from a signal the placer listens for: the placer can be deleted, ghost out or
	// disconnect first, and if that happened the tracker would keep a reference to a deleted sign and hard-delete it.
	if(managed_by_ckey)
		LAZYREMOVE(GLOB.holosign_privacy_tracker[managed_by_ckey], src)
		if(!LAZYLEN(GLOB.holosign_privacy_tracker[managed_by_ckey]))
			GLOB.holosign_privacy_tracker -= managed_by_ckey
		managed_by_ckey = null
	return ..()

GAME_VERB_DESC(/mob/living, manage_holosigns, "Manage Holosigns", "Place or clear your own privacy holosigns.", "IC")

	var/list/options = list(
		"Privacy Holosign" = /obj/structure/holosign/privacy,
		"Clear All Holosigns" = "clear",
	)
	if(!CONFIG_GET(flag/disable_erp_preferences) && client?.prefs?.read_preference(/datum/preference/toggle/master_erp_preferences)) // Only if they have ERP preferences setup
		options["Lewd Advisory Holosign"] = /obj/structure/holosign/privacy/erp

	var/choice = tgui_input_list(src, "Choose an action", "Manage Holosigns", options)
	if(isnull(choice))
		return
	if(choice == "Clear All Holosigns")
		clear_managed_holosigns()
		return
	place_managed_holosign(options[choice])

/**
 * Puts a single privacy holosign down on the user's own turf and books it against their ckey.
 *
 * Non-admins are held to the max_player_holosigns config cap, and admins are pinged once someone is sitting on an
 * unusual number of them. The sign records the placer's ckey so it can take itself back out of the tracker when it goes.
 * Arguments:
 * * sign_type - typepath of the holosign to place, taken from the verb's option list
 */
/mob/living/proc/place_managed_holosign(sign_type)
	var/turf/target_turf = get_turf(src)
	if(target_turf.is_blocked_turf(TRUE))
		to_chat(src, span_warning("There's no room to place a holosign here!"))
		return
	if(locate(/obj/structure/holosign/privacy) in target_turf)
		to_chat(src, span_warning("There's already a holosign here!"))
		return

	var/max_holosigns = CONFIG_GET(number/max_player_holosigns)
	if(!client?.holder && LAZYLEN(GLOB.holosign_privacy_tracker[ckey]) >= max_holosigns)
		to_chat(src, span_warning("You've already placed the maximum number of privacy holosigns ([max_holosigns])!"))
		return

	var/obj/structure/holosign/privacy/new_holosign = new sign_type(target_turf)
	new_holosign.add_hiddenprint(src)
	new_holosign.desc += " It appears to have been placed by [name]."
	new_holosign.managed_by_ckey = ckey
	LAZYADD(GLOB.holosign_privacy_tracker[ckey], new_holosign)

	var/total_placed = LAZYLEN(GLOB.holosign_privacy_tracker[ckey])
	if(total_placed >= HOLOSIGN_ADMIN_NOTIFY_THRESHOLD)
		message_admins("[ADMIN_LOOKUPFLW(src)] has placed [total_placed] privacy holosigns.")

/// Deletes every holosign the user currently has up. Each one removes itself from the tracker as it is destroyed.
/mob/living/proc/clear_managed_holosigns()
	var/list/placed = GLOB.holosign_privacy_tracker[ckey]
	if(!LAZYLEN(placed))
		to_chat(src, span_notice("You have no privacy holosigns active."))
		return
	// Copied because qdel makes each sign take itself back out of this very list mid-loop.
	for(var/obj/structure/holosign/privacy/hologram as anything in placed.Copy())
		qdel(hologram)
	to_chat(src, span_notice("You clear all of your active holosigns."))

#undef HOLOSIGN_ADMIN_NOTIFY_THRESHOLD
