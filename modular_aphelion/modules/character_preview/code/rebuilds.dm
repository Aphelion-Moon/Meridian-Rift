/**
 * Rebuilding the preferences preview mob applies every preference to it: 10 to 40 ms that can't be split. tg rebuilds
 * it inside every action that changes it, twice in some, and many players changing their characters at once ran every
 * tick over, which every player on the server felt.
 *
 * With character setup open, a change only marks the mob stale and asks the window for a drawing, which rebuilds it
 * first, once for everything an action changed. A lone change's drawing rebuilds it then and there, as the action ends,
 * if nothing waits ahead of it and the rebuild fits in what is left of the tick, as it nearly always does; one that
 * doesn't fit still goes then while such rebuilds stay within CHARACTER_PREVIEW_OVERRUN_BUDGET. Otherwise, and for a
 * burst of changes, the mob waits its turn in SScharacter_preview, which rebuilds waiting mobs in the tick time other
 * subsystems leave over. Changes that come while it waits go into the one rebuild, and the page shows its loader once
 * the wait is long enough to see. Without a window, the mob is rebuilt at once, as tg does.
 */

/// Of each second, how many ms rebuilds that don't fit in what is left of their tick may take, running it over.
#define CHARACTER_PREVIEW_OVERRUN_BUDGET 100
/// How many ms of such rebuilds may build up for a burst.
#define CHARACTER_PREVIEW_OVERRUN_BURST 60
/// The longest the queue goes without a rebuild. Once it has, its oldest is rebuilt whether the tick has room or not,
/// so a busy server still rebuilds previews, a little late, and runs a tick over for them at most this often.
#define CHARACTER_PREVIEW_REBUILD_OVERDUE (0.5 SECONDS)

SUBSYSTEM_DEF(character_preview)
	name = "Character Previews"
	// Every tick at 20 FPS.
	wait = 0.5
	priority = FIRE_PRIORITY_ASSETS
	ss_flags = SS_NO_INIT | SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	/// Previews whose mob waits to be rebuilt, oldest first.
	var/list/queue = list()
	/// How many ms a rebuild takes, on average.
	var/rebuild_cost = 30
	/// How many ms rebuilds that run a tick over may still take now. Below zero, they went over, and it is paid back first.
	var/overrun_budget = CHARACTER_PREVIEW_OVERRUN_BURST
	/// When overrun_budget was last topped up.
	var/overrun_budget_at = 0
	/// Runs out once the queue has gone CHARACTER_PREVIEW_REBUILD_OVERDUE without a rebuild.
	COOLDOWN_DECLARE(rebuild_overdue)

/datum/controller/subsystem/character_preview/Recover()
	queue = SScharacter_preview.queue
	rebuild_cost = SScharacter_preview.rebuild_cost

/// Rebuilds waiting previews' mobs in order while the tick has room. The first may take what is left of the tick, and
/// later ones only this subsystem's share of it.
/datum/controller/subsystem/character_preview/fire(resumed)
	var/limit = TICK_LIMIT_RUNNING
	while(length(queue))
		if(!has_room(limit) && !COOLDOWN_FINISHED(src, rebuild_overdue))
			return
		rebuild(queue[1])
		limit = Master.current_ticklimit
		if(MC_TICK_CHECK)
			return

/// Shows how many previews wait, what a rebuild costs, and what is left of the overrun budget.
/datum/controller/subsystem/character_preview/stat_entry(msg)
	msg = "Q:[length(queue)]|R:[round(rebuild_cost, 0.1)]ms|O:[round(overrun_budget)]ms"
	return ..()

/// Whether a rebuild would end within this tick's limit.
/datum/controller/subsystem/character_preview/proc/has_room(limit)
	return TICK_USAGE + rebuild_cost / world.tick_lag <= limit

/**
 * A stale preview mob, for a drawing. With now, as a lone change's action ends, rebuilds it at once if nothing waits
 * ahead of it and it fits in what is left of the tick, or the overrun budget allows. Rebuilds it at once as well if
 * nothing would take the turn: during init, or while this can't fire. Returns TRUE if it did; otherwise the preview
 * waits its turn in the queue.
 */
/datum/controller/subsystem/character_preview/proc/rebuild_or_wait(atom/movable/screen/map_view/char_preview/view, now)
	if(!can_fire || Master.init_stage_completed < INITSTAGE_MAX)
		rebuild(view)
		return TRUE
	if(now && !length(queue))
		if(has_room(TICK_LIMIT_RUNNING))
			rebuild(view)
			return TRUE
		var/time = world.time
		overrun_budget = min(overrun_budget + (time - overrun_budget_at) * CHARACTER_PREVIEW_OVERRUN_BUDGET / (1 SECONDS), CHARACTER_PREVIEW_OVERRUN_BURST)
		overrun_budget_at = time
		if(overrun_budget > 0)
			overrun_budget -= rebuild(view)
			return TRUE
	queue |= view
	return FALSE

/// A preview's turn: rebuilds its mob, if it is still stale, and returns how many ms that took.
/datum/controller/subsystem/character_preview/proc/rebuild(atom/movable/screen/map_view/char_preview/view)
	queue -= view
	if(QDELETED(view))
		return 0
	view.turns++
	if(!view.body_stale)
		return 0
	COOLDOWN_START(src, rebuild_overdue, CHARACTER_PREVIEW_REBUILD_OVERDUE)
	var/started = TICK_USAGE
	var/tick = world.time
	view.update_body(catching_up = TRUE)
	// One that slept ran across ticks, which says nothing of what it cost.
	if(world.time != tick)
		return rebuild_cost
	var/cost = TICK_DELTA_TO_MS(TICK_USAGE - started)
	rebuild_cost = MC_AVERAGE(rebuild_cost, cost)
	return cost

#undef CHARACTER_PREVIEW_OVERRUN_BUDGET
#undef CHARACTER_PREVIEW_OVERRUN_BURST
#undef CHARACTER_PREVIEW_REBUILD_OVERDUE

/atom/movable/screen/map_view/char_preview
	/// Set while the body waits to be rebuilt for a change; see defer_rebuild().
	var/body_stale = FALSE
	/// How many turns the body has had, so a drawing waiting for one knows when it has come.
	var/turns = 0

/**
 * A change to the preferences preview mob. With character setup open, marks the mob stale and asks the window for a
 * drawing, which rebuilds it first, and returns TRUE. Otherwise returns FALSE, and the mob is rebuilt at once.
 */
/atom/movable/screen/map_view/char_preview/proc/defer_rebuild()
	if(!preferences?.character_preview_open())
		return FALSE
	body_stale = TRUE
	preferences.character_preview_changed()
	return TRUE

/// The preview mob as the preferences have it, rebuilt first if a change is waiting, for code that reads the mob.
/atom/movable/screen/map_view/char_preview/proc/current_body()
	RETURN_TYPE(/mob/living/carbon/human/dummy)
	if(body_stale)
		SScharacter_preview.rebuild(src)
	return body
