/// Of each second, how many ms account saves may take, across all players. Past it accounts wait their turn with the
/// latest state still winning, so many players saving at once write each account less often instead of costing more.
#define CYBORG_SAVE_BUDGET 50
/// How many ms of saves may build up for a burst.
#define CYBORG_SAVE_BURST 50

/**
 * Saves cyborg layout accounts in tick time other subsystems leave over.
 *
 * Editor actions and their debounce only change the draft and ask for a save. Here the draft is encoded into its
 * character and the account's file written, once per account in the order they asked, with whatever the draft holds
 * by then. An account writes at most once per CYBORG_LAYOUT_SAVE_SPACING, and all saves together take at most
 * CYBORG_SAVE_BUDGET ms of each second: a save can't be split, so what one runs over comes out of the next. It only
 * fires while accounts are waiting.
 */
SUBSYSTEM_DEF(cyborg_layout_saves)
	name = "Cyborg Layout Saves"
	wait = 1
	priority = FIRE_PRIORITY_ASSETS
	ss_flags = SS_NO_INIT | SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	can_fire = FALSE
	/// Accounts owing a save, in the order they asked.
	var/list/queue = list()
	/// How many ms saves may still take now. Below zero, they went over, and that is paid back first.
	var/budget = CYBORG_SAVE_BURST
	/// When budget was last topped up.
	var/budget_at = 0

/// Saves queued accounts in order while the budget and the tick last. Accounts still inside their spacing keep their place.
/datum/controller/subsystem/cyborg_layout_saves/fire(resumed)
	var/time = world.time
	budget = min(budget + (time - budget_at) * CYBORG_SAVE_BUDGET / (1 SECONDS), CYBORG_SAVE_BURST)
	budget_at = time
	var/list/spaced
	var/index = 0
	// Saves only append to the queue, so walking it by index stays in step.
	while(index < length(queue) && budget > 0)
		index++
		var/datum/json_savefile/cyborg_customization/store = queue[index]
		if(store.path && time < store.next_write_at)
			LAZYADD(spaced, store)
			continue
		var/started = TICK_USAGE
		store.run_save()
		budget -= TICK_DELTA_TO_MS(TICK_USAGE - started)
		if(MC_TICK_CHECK)
			break
	queue.Cut(1, index + 1)
	if(spaced)
		queue.Insert(1, spaced)
	if(!length(queue))
		can_fire = FALSE

/// Writes every waiting account before the world goes, whatever its spacing or the budget.
/datum/controller/subsystem/cyborg_layout_saves/Shutdown()
	for(var/datum/json_savefile/cyborg_customization/store as anything in queue)
		store.run_save()
	queue.Cut()

/// Shows how many accounts are waiting, and what is left of the budget.
/datum/controller/subsystem/cyborg_layout_saves/stat_entry(msg)
	msg = "Q:[length(queue)]|B:[round(budget)]ms"
	return ..()

/// Asks for a save of this account. Whatever the editor's draft holds when it runs is what gets saved.
/datum/json_savefile/cyborg_customization/proc/request_save()
	SScyborg_layout_saves.queue |= src
	SScyborg_layout_saves.can_fire = TRUE

/// The queued save: stages the editor's draft if it asked for that, then writes the account and tells the editor.
/datum/json_savefile/cyborg_customization/proc/run_save()
	var/datum/preferences/preferences = preferences_ref?.resolve()
	var/datum/preference_middleware/cyborg_character/editor = preferences?.cyborg_session()
	var/staged = TRUE
	if(editor?.save_requested)
		staged = editor.stage_draft()
	if(write_pending)
		flush_pending(force = TRUE)
	else if(!staged)
		// Nothing was written, but the editor now shows why its draft is waiting.
		editor.sidecar_write_completed()

#undef CYBORG_SAVE_BUDGET
#undef CYBORG_SAVE_BURST
