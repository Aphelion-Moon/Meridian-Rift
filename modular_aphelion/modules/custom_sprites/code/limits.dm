/**
 * Keeps the custom sprite editors cheap for the server, whatever a window sends.
 *
 * Window actions only change the draft and note what needs drawing. Views, previews and resource
 * rebuilds are drawn afterwards by SScustom_sprite_work, once for a burst of actions, in tick time
 * other subsystems leave over, so no window can hold up a tick however fast it sends actions. The
 * work that costs tens of milliseconds a time, resource rebuilds, new editors and previews of a
 * previous saved style, is paced per player across all their editors by /datum/custom_sprite_pace.
 */

/// Deferred work: draw the visible view's stale guide and preview.
#define CUSTOM_SPRITE_WORK_VIEW (1<<0)
/// Deferred work: refresh the preview after edits settle.
#define CUSTOM_SPRITE_WORK_REFRESH (1<<1)
/// Deferred work: rebuild the preview body's resources, then the preview.
#define CUSTOM_SPRITE_WORK_REBUILD (1<<2)
/// Deferred work: the rebuild needs a fresh preview body rather than the current one.
#define CUSTOM_SPRITE_WORK_NEW_BODY (1<<3)
/// Deferred work: draw the previews of the import or restoration waiting for confirmation.
#define CUSTOM_SPRITE_WORK_CANDIDATE (1<<4)

/// The shortest time between two pieces of a player's costly work. Faster changes still end on the latest state.
#define CUSTOM_SPRITE_REBUILD_SPACING (0.5 SECONDS)
/// Pieces of costly work a player may run back to back at the shortest spacing.
#define CUSTOM_SPRITE_BURST 4
/// How long a used piece of the burst takes to come back, and so the pace of costly work that keeps coming.
#define CUSTOM_SPRITE_REFILL (1.5 SECONDS)
/// How long base hairstyle changes picked after one applies wait, to apply together as the latest pick.
#define CUSTOM_SPRITE_HAIRSTYLE_WINDOW (0.5 SECONDS)
/// The most history steps one undo or redo action may take. Windows only ever send one.
#define CUSTOM_SPRITE_MAX_HISTORY_JUMP 10
/// Stroke pixels a player may apply inside the action per second: four full tall-canvas strokes, far above a hand's pace. The rest queue.
#define CUSTOM_SPRITE_STROKE_BUDGET 6000
/// Strokes an editor holds for the background before refusing more; no person reaches it.
#define CUSTOM_SPRITE_STROKE_QUEUE 50
/// Deferred work: apply the strokes that were over budget, in order.
#define CUSTOM_SPRITE_WORK_STROKES (1<<5)

SUBSYSTEM_DEF(custom_sprite_work)
	name = "Custom Sprite Work"
	wait = 1
	priority = FIRE_PRIORITY_ASSETS
	ss_flags = SS_NO_INIT | SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	/// Editors with deferred work, in the order they asked.
	var/list/queue = list()

/// Runs queued editors' work in order until the tick runs short. Work that has to wait goes back in the queue.
/datum/controller/subsystem/custom_sprite_work/fire(resumed)
	var/list/waiting = list()
	while(length(queue))
		var/datum/custom_sprite_editor/editor = queue[1]
		queue.Cut(1, 2)
		if(!QDELETED(editor) && !editor.run_deferred_work())
			waiting += editor
		if(MC_TICK_CHECK)
			break
	queue += waiting

/// Shows how many editors are waiting.
/datum/controller/subsystem/custom_sprite_work/stat_entry(msg)
	msg = "Q:[length(queue)]"
	return ..()

/**
 * Paces one player's costly custom sprite work: resource rebuilds, new editors and previews of a
 * previous saved style. Up to CUSTOM_SPRITE_BURST pieces run CUSTOM_SPRITE_REBUILD_SPACING apart,
 * and each piece used comes back after CUSTOM_SPRITE_REFILL. A few changes in a row never wait more
 * than the shortest spacing, while a window asking for such work nonstop gets one piece per refill.
 */
/datum/custom_sprite_pace
	/// When the next piece of costly work may start at the soonest.
	COOLDOWN_DECLARE(spacing)
	/// Pieces that may still run at the shortest spacing.
	var/burst = CUSTOM_SPRITE_BURST
	/// When burst was last topped up.
	var/refilled_at = 0
	/// When the next base hairstyle change may apply at once.
	COOLDOWN_DECLARE(hairstyle_window)
	/// Stroke pixels applied inside actions this second.
	var/stroke_pixels = 0
	/// The second stroke_pixels counts.
	COOLDOWN_DECLARE(stroke_window)

/// Tops burst up with the pieces that came back since it was last topped up.
/datum/custom_sprite_pace/proc/refill()
	if(burst >= CUSTOM_SPRITE_BURST)
		refilled_at = world.time
		return
	var/gained = round((world.time - refilled_at) / CUSTOM_SPRITE_REFILL)
	if(gained < 1)
		return
	burst = min(burst + gained, CUSTOM_SPRITE_BURST)
	refilled_at += gained * CUSTOM_SPRITE_REFILL

/// Whether costly work may start now.
/datum/custom_sprite_pace/proc/due()
	refill()
	return burst > 0 && COOLDOWN_FINISHED(src, spacing)

/// Notes a piece of costly work starting now.
/datum/custom_sprite_pace/proc/start()
	refill()
	burst--
	COOLDOWN_START(src, spacing, CUSTOM_SPRITE_REBUILD_SPACING)

/// How long until costly work may start again.
/datum/custom_sprite_pace/proc/time_left()
	refill()
	var/wait = COOLDOWN_TIMELEFT(src, spacing)
	return burst > 0 ? wait : max(wait, refilled_at + CUSTOM_SPRITE_REFILL - world.time)

/// Whether a base hairstyle change may apply at once.
/datum/custom_sprite_pace/proc/hairstyle_due()
	return COOLDOWN_FINISHED(src, hairstyle_window)

/// Notes a base hairstyle change applying now; ones picked in the next moments wait.
/datum/custom_sprite_pace/proc/start_hairstyle_window()
	COOLDOWN_START(src, hairstyle_window, CUSTOM_SPRITE_HAIRSTYLE_WINDOW)

/// How long a base hairstyle change picked now waits.
/datum/custom_sprite_pace/proc/hairstyle_time_left()
	return COOLDOWN_TIMELEFT(src, hairstyle_window)

/// Whether a stroke of `pixels` may apply inside its action, counting it if so.
/datum/custom_sprite_pace/proc/stroke_fits(pixels)
	if(COOLDOWN_FINISHED(src, stroke_window))
		stroke_pixels = 0
		COOLDOWN_START(src, stroke_window, 1 SECONDS)
	if(stroke_pixels + pixels > CUSTOM_SPRITE_STROKE_BUDGET)
		return FALSE
	stroke_pixels += pixels
	return TRUE

/datum/preferences
	/// Paces this player's costly custom sprite work across all their editors.
	var/datum/custom_sprite_pace/custom_sprite_pace = new

/datum/custom_sprite_editor
	/// CUSTOM_SPRITE_WORK_* flags waiting for SScustom_sprite_work.
	var/pending_work = NONE
	/// Paces this editor's costly work when there are no preferences to share a player's pace with.
	var/datum/custom_sprite_pace/own_pace
	/// The draft revision the last Ctrl+S wrote, so saving an unchanged draft again does no work.
	var/saved_draft_revision = -1
	/// A base hairstyle picked while the last change settled, applied when its window ends.
	var/pending_hairstyle
	/// Strokes over the budget, oldest first, applied by the subsystem.
	var/list/stroke_queue = list()
	/// Why the latest stroke was refused, shown quietly until the queue drains.
	var/stroke_notice
	/// A push was due while strokes waited; the drain sends it.
	var/push_after_drain = FALSE
	/// The body a deferred rebuild built in its first fire; the window keeps the old resources until the second swaps it in.
	var/mob/living/carbon/human/dummy/pending_body
	/// Whether pending_body was built (it may be null when the context has no body right now).
	var/pending_body_ready = FALSE
	/// Rebuilds that asked for a new body so far, so a body built for an older request is rebuilt.
	var/body_requests = 0
	/// The body_requests count pending_body was built for.
	var/pending_body_for = 0

/// Asks SScustom_sprite_work for work. Whatever the draft holds when it runs is what gets drawn.
/datum/custom_sprite_editor/proc/request_work(work)
	pending_work |= work
	SScustom_sprite_work.queue |= src

/// Sends the window an update, unless strokes are still waiting: their drain sends it instead, so no update shows frames without them.
/datum/custom_sprite_editor/proc/push()
	if(length(stroke_queue))
		push_after_drain = TRUE
		return
	SStgui.update_uis(src)

/// Drops every kind of waiting work but strokes, which still apply after the window closes.
/datum/custom_sprite_editor/proc/keep_only_strokes()
	pending_work &= CUSTOM_SPRITE_WORK_STROKES

/**
 * Takes a stroke from the window: applied at once within the player's budget, else queued for the
 * subsystem, else refused once the queue is full. Returns whether the window should update now.
 */
/datum/custom_sprite_editor/proc/take_stroke(list/transaction)
	var/datum/custom_sprite_pace/pace = pace()
	if(!length(stroke_queue) && pace.stroke_fits(custom_sprite_transaction_pixels(transaction, workspace.width, workspace.height)))
		// A refused stroke still resends the canvas, so the window drops what it drew ahead of the server.
		if(!workspace.new_transaction(transaction))
			return TRUE
		// A fill's size is known once it has flooded: it's charged then, and the next stroke sees the true count.
		if(transaction["type"] == "bucket")
			pace.stroke_pixels += length(workspace.last_transaction()["points"]) - 1
		draft_edited()
		return TRUE
	if(length(stroke_queue) >= CUSTOM_SPRITE_STROKE_QUEUE)
		stroke_notice = "Too many strokes are waiting; the last one was dropped."
		push_after_drain = TRUE
		return FALSE
	stroke_queue += list(transaction)
	request_work(CUSTOM_SPRITE_WORK_STROKES)
	return FALSE

/// Applies waiting strokes in order until the tick runs short, at least one per call, then sends the window everything that waited for them. Returns whether the queue is empty.
/datum/custom_sprite_editor/proc/drain_strokes()
	do
		var/list/transaction = stroke_queue[1]
		stroke_queue.Cut(1, 2)
		workspace.new_transaction(transaction)
	while(length(stroke_queue) && TICK_USAGE < Master.current_ticklimit)
	draft_edited()
	if(length(stroke_queue))
		return FALSE
	stroke_notice = null
	push_after_drain = FALSE
	SStgui.update_uis(src)
	return TRUE

/// Rebuilds resources and the preview once a burst of changes settles, instead of inside the action.
/datum/custom_sprite_editor/proc/request_rebuild(reuse_body = FALSE)
	// A hair canvas that just changed size has no bounds until its rebuild; all of it is paintable meanwhile, as the rebuild leaves it.
	if(isnull(workspace.draw_bounds) && custom_style_hair_target(target))
		workspace.draw_bounds = custom_sprite_canvas_bounds(workspace.width, workspace.height)
		unlocked_bounds = deep_copy_list(workspace.draw_bounds)
	if(!reuse_body)
		body_requests++
	request_work(CUSTOM_SPRITE_WORK_REBUILD | (reuse_body ? NONE : CUSTOM_SPRITE_WORK_NEW_BODY))

/// Throws a body built for an older request away.
/datum/custom_sprite_editor/proc/drop_pending_body()
	QDEL_NULL(pending_body)
	pending_body_ready = FALSE

/// The preview debounce's callback: the refresh runs as deferred work.
/datum/custom_sprite_editor/proc/request_refresh()
	request_work(CUSTOM_SPRITE_WORK_REFRESH)

/**
 * Shows the visible view, drawing its stale guide or preview afterwards rather than inside the action.
 *
 * A preview about to be refreshed isn't drawn again; the refresh draws whichever view is visible.
 *
 * Returns TRUE when everything the view needs is already drawn, so the window can update now.
 */
/datum/custom_sprite_editor/proc/request_view()
	if(!stale_guides[visible_direction] && (!stale_previews[visible_direction] || preview_timer))
		return TRUE
	request_work(CUSTOM_SPRITE_WORK_VIEW)
	return FALSE

/**
 * Rebuilds resources for a window being opened, unless that would come too soon after the last rebuild.
 *
 * Returns TRUE when resources are ready now; otherwise the rebuild runs as deferred work.
 */
/datum/custom_sprite_editor/proc/rebuild_for_opening()
	var/datum/custom_sprite_pace/pace = pace()
	if(!pace.due())
		request_rebuild()
		return FALSE
	pace.start()
	return rebuild_resources()

/// The pace this editor's costly work shares with the rest of its player's editors.
/datum/custom_sprite_editor/proc/pace()
	if(preferences)
		return preferences.custom_sprite_pace
	if(!own_pace)
		own_pace = new
	return own_pace

/// Asks for the waiting candidate's previews to be drawn in the background.
/datum/custom_sprite_editor/proc/request_candidate()
	request_work(CUSTOM_SPRITE_WORK_CANDIDATE)

/**
 * Does this editor's deferred work and sends the window what changed.
 *
 * Returns FALSE when the work has to wait, such as for the rebuild spacing, so it stays queued.
 */
/datum/custom_sprite_editor/proc/run_deferred_work()
	if(closing)
		pending_work = NONE
		return TRUE
	// Waiting strokes come before anything else, and nothing is pushed until they're all in.
	if(length(stroke_queue) && !drain_strokes())
		pending_work |= CUSTOM_SPRITE_WORK_STROKES
		return FALSE
	pending_work &= ~CUSTOM_SPRITE_WORK_STROKES
	if(!resources_ready && !(pending_work & CUSTOM_SPRITE_WORK_REBUILD))
		pending_work = NONE
		return TRUE
	var/datum/custom_sprite_pace/pace = pace()
	if((pending_work & CUSTOM_SPRITE_WORK_REBUILD) && !pending_body_ready && !pace.due())
		return FALSE
	var/work = pending_work
	pending_work = NONE
	if(!work)
		return TRUE
	if(work & CUSTOM_SPRITE_WORK_REBUILD)
		if(pending_body_ready && pending_body_for != body_requests)
			// A newer request wants the latest state: build again, when the pace allows.
			drop_pending_body()
			if(!pace.due())
				pending_work |= work
				return FALSE
		if((work & CUSTOM_SPRITE_WORK_NEW_BODY) && !pending_body_ready)
			// Fire one: the body alone. The window keeps its guides and previews until the next fire renders new ones.
			pace.start()
			pending_body = create_preview_body()
			pending_body_ready = TRUE
			pending_body_for = body_requests
			pending_work |= work & ~CUSTOM_SPRITE_WORK_NEW_BODY
			return FALSE
		if(pending_body_ready)
			QDEL_NULL(preview_body)
			preview_body = pending_body
			pending_body = null
			pending_body_ready = FALSE
		else
			pace.start()
		if(rebuild_resources(reuse_body = TRUE))
			refresh_preview(push = FALSE)
	else if(work & CUSTOM_SPRITE_WORK_REFRESH)
		refresh_preview(push = FALSE)
	if((work & CUSTOM_SPRITE_WORK_VIEW) && resources_ready)
		if(stale_guides[visible_direction])
			render_guide(visible_direction)
		if(stale_previews[visible_direction] && !preview_timer)
			render_preview(visible_direction)
	if((work & CUSTOM_SPRITE_WORK_CANDIDATE) && resources_ready && candidate && isnull(candidate["previews"]))
		render_candidate()
	SStgui.update_uis(src)
	return TRUE

/**
 * Whether an action has to wait. A previous saved style is previewed only when the player's pace
 * allows, and never while a preview is already waiting for an answer.
 */
/datum/custom_sprite_editor/proc/act_blocked(action)
	if(action != "restorePrevious")
		return FALSE
	if(candidate)
		return TRUE
	var/datum/custom_sprite_pace/pace = pace()
	if(!pace.due())
		transfer_notice = "Wait a moment before trying that again."
		return TRUE
	pace.start()
	return FALSE

/**
 * Picks a base hairstyle. A change applies at once; ones picked in the moments after it wait for
 * CUSTOM_SPRITE_HAIRSTYLE_WINDOW and apply together as the latest pick, so a burst of picks lands at
 * most twice and never on the styles in between, such as a tall canvas or lifted hair it would
 * grow into and straight out of. The window shows the latest pick throughout.
 *
 * Returns TRUE when the window should update.
 */
/datum/custom_sprite_editor/proc/request_hairstyle(style)
	var/current = workspace.hair_context?["style"]
	if(style == (pending_hairstyle || current))
		return FALSE
	var/datum/custom_sprite_pace/pace = pace()
	if(!pending_hairstyle && pace.hairstyle_due())
		pace.start_hairstyle_window()
		apply_hairstyle(style)
		return TRUE
	// Picking the applied style again only drops the one waiting.
	pending_hairstyle = style == current ? null : style
	addtimer(CALLBACK(src, PROC_REF(apply_pending_hairstyle), TRUE), pace.hairstyle_time_left(), TIMER_UNIQUE)
	return TRUE

/// Applies a hairstyle that was waiting, when its window ends or before anything else the window does.
/datum/custom_sprite_editor/proc/apply_pending_hairstyle(push = FALSE)
	if(!pending_hairstyle || closing)
		return
	var/style = pending_hairstyle
	pending_hairstyle = null
	var/datum/custom_sprite_pace/pace = pace()
	pace.start_hairstyle_window()
	apply_hairstyle(style)
	if(push)
		SStgui.update_uis(src)

/// Puts a base hairstyle on the draft, if the draft can still take it.
/datum/custom_sprite_editor/proc/apply_hairstyle(style)
	var/list/hair = workspace.hair_context?.Copy()
	if(!can_change_hair() || !hair || style == hair["style"])
		return FALSE
	hair["style"] = style
	return apply_hair_context(hair, "Change hairstyle")

/// Whether Ctrl+S would write exactly what the last one did. It's still acknowledged, so the window flashes Saved.
/datum/custom_sprite_editor/proc/save_unchanged()
	if(save_error || saved_draft_revision != draft_revision)
		return FALSE
	save_revision++
	return TRUE

/**
 * Whether opening an editor that doesn't exist yet has to wait for the player's pace, as a new
 * editor builds a preview body. A waiting open happens by itself once the pace allows, however many
 * times it was asked for.
 */
/datum/preference_middleware/custom_sprites/proc/open_deferred(target, body_zone, mob/user)
	if(preferences.custom_sprite_editors?[target])
		return FALSE
	var/datum/custom_sprite_pace/pace = preferences.custom_sprite_pace
	if(pace.due())
		pace.start()
		return FALSE
	addtimer(CALLBACK(src, PROC_REF(open_later), target, body_zone, user), pace.time_left(), TIMER_UNIQUE)
	return TRUE

/// Opens an editor whose creation waited out the spacing.
/datum/preference_middleware/custom_sprites/proc/open_later(target, body_zone, mob/user)
	if(!QDELETED(user))
		open_editor(list("target" = target, "body_zone" = body_zone), user)

/**
 * A stroke's points from its compact mask: CUSTOM_SPRITE_INDEX_ALPHABET characters, six canvas
 * pixels each, row-major from the top left, lowest bit first. A whole view fits in one short string,
 * so a long stroke reaches the server as one message instead of a point list tgui splits into many.
 *
 * Returns list(list(x, y), ...), or null when the mask isn't exactly this canvas's size.
 */
/proc/custom_sprite_mask_points(mask, width, height)
	var/cells = width * height
	if(!istext(mask) || length(mask) != CEILING(cells / 6, 1))
		return null
	var/list/values = custom_sprite_index_values()
	. = list()
	for(var/index in 1 to length(mask))
		var/bits = values[copytext(mask, index, index + 1)]
		if(isnull(bits))
			return null
		if(!bits)
			continue
		for(var/bit in 0 to 5)
			if(!(bits & (1 << bit)))
				continue
			var/position = (index - 1) * 6 + bit
			if(position >= cells)
				return null
			. += list(list(position % width, round(position / width)))

/// How many pixels a stroke or placement touches, from what the window sent, before any validation.
/proc/custom_sprite_transaction_pixels(list/transaction, width, height)
	if(!islist(transaction))
		return 0
	if("mask" in transaction)
		return custom_sprite_mask_pixels(transaction["mask"]) || width * height
	if(islist(transaction["area"]) && length(transaction["area"]) == 4)
		var/list/area = transaction["area"]
		return isnum(area[1]) && isnum(area[2]) && isnum(area[3]) && isnum(area[4]) ? max(0, (area[3] - area[1] + 1) * (area[4] - area[2] + 1)) : width * height
	if(islist(transaction["rect"]) && length(transaction["rect"]) == 4)
		var/list/rect = transaction["rect"]
		return isnum(rect[1]) && isnum(rect[2]) && isnum(rect[3]) && isnum(rect[4]) ? max(0, (rect[3] - rect[1] + 1) * (rect[4] - rect[2] + 1)) : width * height
	return islist(transaction["points"]) ? length(transaction["points"]) : 1

/// The pixels a compact stroke mask marks, or null when a character isn't in the alphabet.
/proc/custom_sprite_mask_pixels(mask)
	var/static/list/bit_counts
	if(!bit_counts)
		bit_counts = list()
		for(var/value in 0 to 63)
			var/bits = 0
			for(var/bit in 0 to 5)
				bits += (value >> bit) & 1
			bit_counts += bits
	if(!istext(mask))
		return null
	var/list/values = custom_sprite_index_values()
	. = 0
	for(var/index in 1 to length(mask))
		var/value = values[copytext(mask, index, index + 1)]
		if(isnull(value))
			return null
		. += bit_counts[value + 1]

/// Clamps an undo or redo step count to what a window can ask for. Anything else passes through for the history to refuse.
/proc/custom_sprite_history_jump(count)
	return isnum(count) ? min(count, CUSTOM_SPRITE_MAX_HISTORY_JUMP) : count

#undef CUSTOM_SPRITE_WORK_VIEW
#undef CUSTOM_SPRITE_WORK_REFRESH
#undef CUSTOM_SPRITE_WORK_REBUILD
#undef CUSTOM_SPRITE_WORK_NEW_BODY
#undef CUSTOM_SPRITE_WORK_CANDIDATE
#undef CUSTOM_SPRITE_REBUILD_SPACING
#undef CUSTOM_SPRITE_BURST
#undef CUSTOM_SPRITE_REFILL
#undef CUSTOM_SPRITE_HAIRSTYLE_WINDOW
#undef CUSTOM_SPRITE_MAX_HISTORY_JUMP
#undef CUSTOM_SPRITE_STROKE_BUDGET
#undef CUSTOM_SPRITE_STROKE_QUEUE
#undef CUSTOM_SPRITE_WORK_STROKES
