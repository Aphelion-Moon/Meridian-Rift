// THIS IS A MODULAR NOVA SECTOR ITEM - PERSONAL_CACHE
/// Storage for the Bluespace Cache. 6 slots = room for every standing/optional matrix plus one spare for the auto-sort catch-all below.
/datum/storage/box/personal_cache
	// Has to be at least as big as our biggest matrix (loadout/erp, both NORMAL) so they can be filled, and no bigger than NORMAL or the cache itself gets rejected going into an ordinary backpack (see can_insert()'s bigger_fish check in storage.dm).
	max_specific_storage = WEIGHT_CLASS_NORMAL
	max_slots = 6
	allow_big_nesting = TRUE // lets NORMAL-sized storage (ration packs) get far enough in for the matrices to claim it
	allow_quick_gather = TRUE // click a pile on the floor to sweep it straight into the matrices
	allow_quick_empty = TRUE // and drag the cache onto a tile to shake every matrix back out

/datum/storage/box/personal_cache/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	// Backpacks and duffels are already turned away for being BULKY, so this is just the short list of NORMAL things we don't want swallowed.
	set_holdable(cant_hold_list = list(
		/obj/item/storage/box/personal_cache, // no cache in a cache. That's a bag of holding with extra steps.
		/obj/item/storage/medkit, // out of scope on purpose - the cache tidies your kit, it doesn't replace medbay
	))

// Reskinned survival box. PopulateContents gives it the usual mask/tank/medipen, we just tidy them into the survival matrix after.
/obj/item/storage/box/personal_cache
	parent_type = /obj/item/storage/box/survival
	name = "bluespace cache"
	desc = "A survival kit stabilized by a personal bluespace field, calibrated to your own specifications and quietly organized whether you like it or not."
	icon_state = "alienbox"
	illustration = "writing_syndie"
	foldable_result = null // it's a bluespace field in a shell, not a cardboard box you can flatten
	resistance_flags = FIRE_PROOF // and a fire shouldn't take someone's whole kit with it
	storage_type = /datum/storage/box/personal_cache

	/// ckey of the bound owner. Null if unbound.
	var/owner_ckey
	/// Display name of the bound owner, used to build the box's name and GPS tag.
	var/owner_name
	/// Whether a GPS component is currently attached (box is lost/stolen).
	var/gps_active = FALSE
	/// The sole active hacking session, including an owner's practice attempt.
	var/datum/cache_lock_session/active_hack
	/// Failed or abandoned real attempts prevent immediate brute-force retries.
	var/hack_cooldown_until = 0
	/// Matrices every cache is born with. Add a pouch type here to give every cache one for free - sort order isn't decided here, it lives on each pouch's sort_priority.
	var/static/list/standing_pouches = list(
		/obj/item/storage/box/cache_pouch/survival,
		/obj/item/storage/box/cache_pouch/rations,
		/obj/item/storage/box/cache_pouch/general,
	)
	/// cache_slot -> which standing pouch swallows Cache tab picks of that slot (unlisted slots just fall to the box root). New slot? New line here, and add its pouch to standing_pouches above.
	var/static/list/slot_to_pouch = list(
		CACHE_SLOT_TANK = /obj/item/storage/box/cache_pouch/survival,
		CACHE_SLOT_MASK = /obj/item/storage/box/cache_pouch/survival,
		CACHE_SLOT_RATION = /obj/item/storage/box/cache_pouch/rations,
		CACHE_SLOT_GENERAL = /obj/item/storage/box/cache_pouch/general,
	)

/obj/item/storage/box/personal_cache/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/connect_containers, src, list(COMSIG_MOVABLE_MOVED = PROC_REF(on_container_moved)))

/obj/item/storage/box/personal_cache/Destroy()
	QDEL_NULL(active_hack)
	return ..()

/// A containing backpack can change hands without moving the cache itself.
/obj/item/storage/box/personal_cache/proc/on_container_moved()
	SIGNAL_HANDLER
	update_gps_state()

/obj/item/storage/box/personal_cache/get_pouch_for_slot(cache_slot)
	var/pouch_type = slot_to_pouch[cache_slot]
	return pouch_type ? (locate(pouch_type) in src) : null

/// Low priority first - the picky matrices get first refusal, the junk drawer eats last. sortTim is stable, so ties keep contents order.
/proc/cmp_cache_pouch_priority(obj/item/storage/box/cache_pouch/a, obj/item/storage/box/cache_pouch/b)
	return a.sort_priority - b.sort_priority

/// Every matrix currently threaded into the cache, lowest sort_priority first. The bulk paths below all work off this so nothing has to know which matrices exist.
/obj/item/storage/box/personal_cache/proc/get_sorted_matrices()
	. = list()
	for(var/obj/item/storage/box/cache_pouch/pouch in contents)
		. += pouch
	if(length(.) > 1)
		sortTim(., GLOBAL_PROC_REF(cmp_cache_pouch_priority))

/// Which matrix would take thing? Asked in sort_priority order, so the optional ones (loadout, love) get first refusal on their own gear instead of watching general scoop it up. Null means nobody wants it - which is the cache's cue to turn it away at the door rather than let it squat in the root.
/obj/item/storage/box/personal_cache/proc/find_matrix_for(obj/item/thing, mob/user)
	if(istype(thing, /obj/item/storage/box/cache_pouch)) // matrices don't nest inside each other
		return null
	for(var/obj/item/storage/box/cache_pouch/pouch as anything in get_sorted_matrices())
		if(pouch.atom_storage.can_insert(thing, user, messages = FALSE))
			return pouch
	return null

/// Files thing into whichever matrix find_matrix_for() picked. Used at spawn (see PopulateContents) and on every drop-in (see attempt_insert below). Returns the matrix it landed in, or null if nothing wanted it.
/obj/item/storage/box/personal_cache/proc/sort_into_matrix(obj/item/thing, mob/user)
	var/obj/item/storage/box/cache_pouch/destination = find_matrix_for(thing, user)
	if(isnull(destination))
		return null
	if(!destination.atom_storage.attempt_insert(thing, user, override = TRUE, messages = FALSE))
		return null
	return destination

// Matrices first, then let survival's PopulateContents do its normal thing, evict the candle, and sweep whatever's left loose (mask, tank, medipen, and anything else survival felt like giving us) into its matrix.
/obj/item/storage/box/personal_cache/PopulateContents()
	for(var/pouch_type in standing_pouches)
		new pouch_type(src)

	. = ..()

	qdel(locate(/obj/item/oxygen_candle) in src)// Fuck you go away dumb candle you suck

	for(var/obj/item/loose_item in contents.Copy())
		sort_into_matrix(loose_item)

// Survival's version pokes at src's direct contents, but by now the mask and tank are tucked inside the survival matrix, so it finds nothing and dumps the replacement tank loose in the root. Dig properly, then file the new one like anything else. No parent call - it'd no-op on the search and spawn us a second tank.
/obj/item/storage/box/personal_cache/wardrobe_removal()
	if(!isplasmaman(loc) && !isvox(loc))
		return

	var/obj/item/tank/replacement = isvox(loc) ? new /obj/item/tank/internals/nitrogen/belt/emergency(src) : new /obj/item/tank/internals/plasmaman/belt(src)
	for(var/obj/item/thing in get_all_contents())
		if(thing == replacement)
			continue
		if(istype(thing, mask_type) || istype(thing, internal_type))
			qdel(thing)
	sort_into_matrix(replacement)

// The pitch: what it does, who it answers to, and how to work its lock
/obj/item/storage/box/personal_cache/examine(mob/user)
	. = ..()
	. += span_notice("A personal bluespace field keeps its contents auto-sorted into dedicated matrices - no more digging for your gas mask.")

	if(isnull(owner_ckey))
		. += span_notice("Its bluespace lock is unattuned. Use a multitool on [src] to claim it.")
	else if(user.ckey == owner_ckey)
		. += span_notice("It's attuned to you. Multitool it again to wipe that, or Ctrl-Shift-click it in hand to test the lock.")
	else
		. += span_notice("It's attuned to [owner_name || "someone else"]. A multitool gets you a shot at cracking the lock, nothing more.")
	. += span_notice("While attuned and out of its owner's hands, it broadcasts a GPS signal.")

// Multitool tap = the owner dance.
/obj/item/storage/box/personal_cache/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/multitool))
		return ..()
	return rebind_owner(user)

/// Owners can practice without a tool or changing their attunement.
/obj/item/storage/box/personal_cache/click_ctrl_shift(mob/user)
	if(!isliving(user) || user.ckey != owner_ckey)
		return NONE
	var/mob/living/living_user = user
	crack_bluespace_lock(living_user, self_test = TRUE)
	return CLICK_ACTION_SUCCESS

// Unowned? Claim it. Yours? Drop it. Someone else's? Go crack it.
/obj/item/storage/box/personal_cache/proc/rebind_owner(mob/living/user)
	if(!user.ckey || user.incapacitated || !user.can_perform_action(src, NEED_DEXTERITY))
		return ITEM_INTERACT_BLOCKING
	if(isnull(owner_ckey))
		set_owner(user)
		to_chat(user, span_notice("You attune [src]'s bluespace lock to yourself. It will transmit a GPS signal whenever you're not holding it."))
		return ITEM_INTERACT_SUCCESS

	if(user.ckey == owner_ckey)
		to_chat(user, span_notice("You wipe [src]'s bluespace attunement. Use a multitool again to attune a new owner."))
		clear_owner()
		return ITEM_INTERACT_SUCCESS

	return crack_bluespace_lock(user)

// Cache hacking
/// Starts a routing puzzle, or reopens this user's existing attempt.
/obj/item/storage/box/personal_cache/proc/crack_bluespace_lock(mob/living/user, self_test = FALSE)
	if(!user.ckey || user.incapacitated || isnull(owner_ckey) || (self_test != (user.ckey == owner_ckey)))
		return ITEM_INTERACT_BLOCKING
	if(!user.is_holding(src))
		balloon_alert(user, "pick it up first!")
		return ITEM_INTERACT_BLOCKING

	if(active_hack)
		if(active_hack.ui_status(active_hack.hacker, GLOB.hands_state) == UI_CLOSE)
			qdel(active_hack)
		else
			if(active_hack.hacker == user)
				active_hack.ui_interact(user)
			else
				to_chat(user, span_warning("[src]'s lock is already being tampered with!"))
			return ITEM_INTERACT_BLOCKING
	if(!self_test && world.time < hack_cooldown_until)
		to_chat(user, span_warning("The lock is recovering. Try again in [CEILING((hack_cooldown_until - world.time) / (1 SECONDS), 1)] seconds."))
		return ITEM_INTERACT_BLOCKING

	active_hack = new(src, user, self_test)
	active_hack.ui_interact(user)
	return ITEM_INTERACT_SUCCESS

/// The puzzle solved itself. Real crack = attunement's toast. Self-test = just bragging rights.
/obj/item/storage/box/personal_cache/proc/on_lock_cracked(mob/living/user, self_test)
	if(self_test)
		to_chat(user, span_notice("[src]'s bluespace lock clicks open cleanly - your own security holds up. This time."))
		return
	to_chat(user, span_notice("You feel [src]'s bluespace lock give way. Its attunement dissolves."))
	clear_owner()

/// Slaps new_owner's name on the cache and syncs the GPS
/obj/item/storage/box/personal_cache/proc/set_owner(mob/living/new_owner)
	if(!new_owner.ckey)
		return
	QDEL_NULL(active_hack)
	remove_gps_signal()
	owner_ckey = new_owner.ckey
	owner_name = new_owner.real_name
	name = "[owner_name]'s bluespace cache"
	update_gps_state()

/// Scrubs ownership clean, name and GPS included
/obj/item/storage/box/personal_cache/proc/clear_owner()
	QDEL_NULL(active_hack)
	owner_ckey = null
	owner_name = null
	name = initial(name)
	update_gps_state()

/// Are we in our owner's hands? No GPS needed then. Anywhere else, start beeping.
/obj/item/storage/box/personal_cache/proc/update_gps_state()
	if(QDELETED(src) || isnull(owner_ckey))
		remove_gps_signal()
		return

	var/mob/holder = get(src, /mob) // walks up through backpacks, pockets, whatever it's buried in
	if(holder && holder.ckey == owner_ckey)
		remove_gps_signal()
	else
		add_gps_signal()

// Adds and removes the GPS signal
/obj/item/storage/box/personal_cache/proc/add_gps_signal()
	if(gps_active || QDELETED(src))// Prevents a runtime through the preview dummy
		return
	gps_active = TRUE
	AddComponent(/datum/component/gps, "[owner_name || "UNKNOWN"]'s Bluespace Cache")

/obj/item/storage/box/personal_cache/proc/remove_gps_signal()
	if(!gps_active)
		return
	gps_active = FALSE
	qdel(GetComponent(/datum/component/gps))

// Runs the GPS proc every time the box itself is handled
/obj/item/storage/box/personal_cache/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	update_gps_state()

// The root is a hallway, not a shelf. If no matrix would claim it, it doesn't come in at all - that spare slot exists so sorting has somewhere to breathe, not for loose junk to squat in.
/datum/storage/box/personal_cache/can_insert(obj/item/to_insert, mob/user, messages = TRUE, force = STORAGE_NOT_LOCKED)
	. = ..()
	if(!.)
		return

	var/obj/item/storage/box/personal_cache/cache = parent
	if(!length(cache.get_sorted_matrices())) // no matrices at all (admin-spawned oddity) - don't brick the box, just behave like a normal one
		return
	if(isnull(cache.find_matrix_for(to_insert, user)))
		if(messages && user)
			user.balloon_alert(user, "no matrix for that!")
		return FALSE

// Nobody drops stuff loose in a nicely organized box. If it lands in the root, file it - and say where, so the auto-sort doesn't just read as the box eating things.
/datum/storage/box/personal_cache/attempt_insert(obj/item/to_insert, mob/user, override = FALSE, force = STORAGE_NOT_LOCKED, messages = TRUE)
	. = ..()
	if(!. || QDELETED(to_insert) || to_insert.loc != parent)
		return

	var/obj/item/storage/box/personal_cache/cache = parent
	var/obj/item/storage/box/cache_pouch/landed_in = cache.sort_into_matrix(to_insert, user)
	if(messages && user && landed_in)
		parent.balloon_alert(user, "filed: [landed_in.name]")

// Drag the cache onto a tile to shake every matrix out at once. Vanilla would dump the box's own contents - which is just the matrices, and those are fused in - so we reach one level deeper and empty each of them instead. Takes a while; you're collapsing a bluespace field by hand.
/datum/storage/box/personal_cache/dump_content_at(atom/dest_object, dump_loc, mob/user)
	if(locked)
		user.balloon_alert(user, "closed!")
		return
	if(!parent.IsReachableBy(user) || !dest_object.IsReachableBy(user))
		return
	var/obj/item/storage/box/personal_cache/cache = parent
	var/list/matrices = cache.get_sorted_matrices()
	if(!length(matrices))
		return ..()

	to_chat(user, span_notice("You start destabilizing [parent]'s matrices over [dest_object]..."))
	if(!do_after(user, 5 SECONDS, target = dest_object))
		return
	if(QDELETED(parent) || QDELETED(dest_object))
		return
	if(locked || !parent.IsReachableBy(user) || !dest_object.IsReachableBy(user))
		return

	if(do_rustle && rustle_sound)
		playsound(parent, rustle_sound, 50, TRUE, -5)

	// Dumping into another container hands over the contents, never the matrices themselves.
	var/datum/storage/receiver = dest_object.atom_storage
	for(var/obj/item/storage/box/cache_pouch/pouch as anything in matrices)
		if(QDELETED(pouch) || pouch.loc != parent || pouch.atom_storage.locked)
			continue
		if(SEND_SIGNAL(dest_object, COMSIG_STORAGE_DUMP_CONTENT, pouch.atom_storage, user) & STORAGE_DUMP_HANDLED)
			continue
		if(isnull(receiver))
			pouch.atom_storage.remove_all(dump_loc)
			continue
		for(var/obj/item/thing in pouch.contents.Copy())
			receiver.attempt_insert(thing, user, messages = FALSE)

	parent.update_appearance()
	SEND_SIGNAL(src, COMSIG_STORAGE_DUMP_POST_TRANSFER, dest_object, user)

// If you somehow manage to target the damn things to try and remove them, throw a special balloon alert.
/datum/storage/box/personal_cache/attempt_remove(obj/item/thing, atom/remove_to_loc, silent = FALSE, visual_updates = TRUE)
	if(istype(thing, /obj/item/storage/box/cache_pouch))
		var/mob/holder = get(parent, /mob) // not ismob(parent.loc) - the cache normally lives in a backpack, not a hand
		if(!silent && holder)
			parent.balloon_alert(holder, "fused into the bluespace field!")
		return FALSE
	return ..()
