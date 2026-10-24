/// Of each second, how many ms account saves may run past the ends of ticks, across all players. The budget refills
/// whatever the server does, so waiting saves always get their turn.
#define CYBORG_SAVE_OVERRUN_BUDGET 50
/// How many ms past the ends of ticks may build up for a burst of saves.
#define CYBORG_SAVE_OVERRUN_BURST 50

/**
 * Saves cyborg layout accounts in tick time other subsystems leave over.
 *
 * Editor actions and their debounce only change the draft and ask for a save. Here the draft is encoded into its
 * character and the account's file written, once per account in the order they asked, with whatever the draft holds
 * by then. An account writes at most once per CYBORG_SAVE_SPACING, and a save can't be split: what it runs past the
 * end of its tick comes out of CYBORG_SAVE_OVERRUN_BUDGET, so many accounts saving at once spread over ticks instead
 * of stacking in one.
 */
SUBSYSTEM_DEF(cyborg_layout_saves)
	name = "Cyborg Layout Saves"
	wait = 1
	priority = FIRE_PRIORITY_ASSETS
	ss_flags = SS_NO_INIT | SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	/// Accounts owing a save, in the order they asked.
	var/list/queue = list()
	/// How many ms saves may still run past the ends of ticks now. Below zero, they went over, and that is paid back first.
	var/overrun_budget = CYBORG_SAVE_OVERRUN_BURST
	/// When overrun_budget was last topped up.
	var/overrun_budget_at = 0

/// Saves queued accounts in order until the tick runs short. Accounts still inside their spacing keep their place.
/datum/controller/subsystem/cyborg_layout_saves/fire(resumed)
	if(!length(queue))
		return
	var/time = world.time
	overrun_budget = min(overrun_budget + (time - overrun_budget_at) * CYBORG_SAVE_OVERRUN_BUDGET / (1 SECONDS), CYBORG_SAVE_OVERRUN_BURST)
	overrun_budget_at = time
	var/list/spaced
	var/index = 0
	// Saves only append to the queue, so walking it by index stays in step.
	while(index < length(queue) && overrun_budget > 0)
		index++
		var/datum/json_savefile/cyborg_customization/store = queue[index]
		if(store.path && time < store.next_write_at)
			LAZYADD(spaced, store)
			continue
		var/started = TICK_USAGE
		store.run_save()
		overrun_budget -= TICK_DELTA_TO_MS(max(0, TICK_USAGE - max(started, TICK_LIMIT_RUNNING)))
		if(MC_TICK_CHECK)
			break
	queue.Cut(1, index + 1)
	if(spaced)
		queue.Insert(1, spaced)

/// Shows how many accounts are waiting, and what is left of the overrun budget.
/datum/controller/subsystem/cyborg_layout_saves/stat_entry(msg)
	msg = "Q:[length(queue)]|O:[round(overrun_budget)]ms"
	return ..()

/// Asks for a save of this account. Whatever the editor's draft holds when it runs is what gets saved.
/datum/json_savefile/cyborg_customization/proc/request_save()
	SScyborg_layout_saves.queue |= src

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

#undef CYBORG_SAVE_OVERRUN_BUDGET
#undef CYBORG_SAVE_OVERRUN_BURST
