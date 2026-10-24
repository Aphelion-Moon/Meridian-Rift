/// Most base64 characters one capture may send - 2 MiB of image, the bridge's own cap for captures
#define BUG_REPORT_CAPTURE_MAX 2796204
/// How long a window gets to show its snapshot preview before we take its renderer for dead
#define BUG_REPORT_CAPTURE_READY_WAIT (20 SECONDS)

/datum/bug_report
	/// The window a capture was asked of
	var/datum/tgui_window/capture_window
	/// The UI that window showed when asked, so a reused window can't answer for it
	var/datum/tgui/capture_ui
	/// The picture the capture is for
	var/datum/bug_report_picture/capture_picture
	/// Ties a capture's messages to the request that started it
	var/capture_nonce
	/// Where the capture's base64 is staged
	var/capture_path
	/// When an unfinished capture gives up
	var/capture_until = 0
	/// Whether the capture's window has shown its preview, which one whose renderer died never does
	var/capture_ready = FALSE
	/// The next chunk index we take
	var/capture_next = 0
	/// Base64 characters staged so far
	var/capture_received = 0
	/// The capture's whole base64 length, fixed by its first chunk
	var/capture_total = 0
	COOLDOWN_DECLARE(capture_cooldown)

/// The reporter's other open TGUI windows a capture could be taken of, for the page's picker, or null with none
/datum/bug_report/proc/capture_targets()
	if(!valid_owner())
		return null
	var/list/targets
	var/list/repeats
	for(var/id in owner.tgui_windows)
		var/datum/tgui_window/window = owner.tgui_windows[id]
		if(!capture_window_allowed(window))
			continue
		var/title = window_title(window)
		// Only a title two windows share gets a number, from the second one on
		LAZYINITLIST(repeats)
		repeats[title] += 1
		LAZYADD(targets, list(list("id" = id, "title" = repeats[title] > 1 ? "[title] ([repeats[title]])" : title)))
	return targets

/// The title a window shows the reporter, for the picker and its picture's caption
/datum/bug_report/proc/window_title(datum/tgui_window/window)
	return window.locked_by.title || window.locked_by.interface

/// Whether a window is one of the reporter's own visible TGUIs, and not a bug report
/datum/bug_report/proc/capture_window_allowed(datum/tgui_window/window)
	if(!valid_owner() || window?.client != owner || !window.visible || window.status != TGUI_WINDOW_READY || !window.locked)
		return FALSE
	var/datum/tgui/ui = window.locked_by
	return ui && !ui.closing && ui.user == owner.mob && ui.interface != "BugReport"

/**
 * Asks one of the reporter's other TGUI windows for a snapshot of itself.
 *
 * The window renders it, lets the reporter preview and crop it, then sends it back in small acknowledged
 * chunks that receive_ui_capture() stages.
 * Arguments:
 * * window_id - which of the reporter's windows, as the page picked it
 * * replace - the id of the picture it retakes, or null for a new one
 */
/datum/bug_report/proc/begin_ui_capture(window_id, replace)
	if(busy || capture_nonce || !valid_owner() || (result?["kind"] in list("accepted", "checking")) || !istext(window_id))
		return
	if(!COOLDOWN_FINISHED(src, capture_cooldown))
		return finish_action("Give it a few seconds before the next capture.")
	if(!take_allowance("captures", spend = FALSE))
		return finish_action()
	var/datum/tgui_window/window = owner.tgui_windows[window_id]
	if(!capture_window_allowed(window))
		return finish_action("That window isn't open any more. Pick another one.", targets = TRUE)
	var/datum/bug_report_picture/picture = picture_for(replace, "window")
	if(!picture)
		return finish_action()
	var/datum/tgui/selected_ui = window.locked_by
	busy = TRUE
	push_update()
	if(!save_fields() || !capture_window_allowed(window) || window.locked_by != selected_ui)
		return finish_action(targets = TRUE)
	COOLDOWN_START(src, capture_cooldown, 10 SECONDS)
	LAZYOR(pictures, picture)
	picture.pending = "waiting"
	picture.reason = null
	picture.title = window_title(window)
	capture_picture = picture
	capture_window = window
	capture_ui = selected_ui
	// Only correlates messages, the owner and the exact window and UI are what we trust
	capture_nonce = GUID()
	capture_until = world.time + 3 MINUTES
	capture_ready = FALSE
	capture_next = 0
	capture_received = 0
	capture_total = 0
	// The picture's card says where to look
	status = null
	window.send_message("bug-report/capture", list("nonce" = capture_nonce, "chunk" = BUG_REPORT_CAPTURE_CHUNK, "limit" = BUG_REPORT_CAPTURE_MAX))
	// A renderer that runs out of memory takes the page's own timers with it, so we can't wait on the window to give up
	addtimer(CALLBACK(src, PROC_REF(expire_unready_capture), capture_nonce), BUG_REPORT_CAPTURE_READY_WAIT)
	addtimer(CALLBACK(src, PROC_REF(expire_ui_capture), capture_nonce), 3 MINUTES)
	push_update()

/// Gives up on a capture whose window never showed its preview
/datum/bug_report/proc/expire_unready_capture(nonce)
	if(capture_nonce == nonce && !capture_ready)
		cancel_ui_capture("no_answer")

/// Gives up on a capture still unfinished when its time runs out
/datum/bug_report/proc/expire_ui_capture(nonce)
	if(capture_nonce == nonce)
		cancel_ui_capture("expired")

/**
 * Ends the capture, telling its window to stop and deleting whatever was staged, and says why.
 *
 * A new picture goes with it, a retake keeps the image it had.
 * Arguments:
 * * reason - why it ended, ours (no_answer, expired, closed, interrupted, not_saved) or the window's own
 */
/datum/bug_report/proc/cancel_ui_capture(reason = "cancelled")
	var/static/list/messages = list(
		"cancelled" = "Capture cancelled",
		"no_answer" = "That window didn't answer. Reopen it and try again.",
		"expired" = "The capture took too long. Try again, or add your own screenshot.",
		"closed" = "That window closed or changed, so nothing was added.",
		"interrupted" = "The capture didn't arrive in one piece. Try again.",
		"not_saved" = "The capture couldn't be saved. Try again.",
		"too_big" = "That window's too big to capture. Add your own screenshot instead.",
		"empty" = "That window has nothing on screen to capture.",
		"failed" = "That window couldn't be captured. Add your own screenshot instead.",
		"timed_out" = "The capture took too long. Try again, or add your own screenshot.",
		"busy" = "That window is busy with another capture. Try again in a moment.",
		"not_allowed" = "That window can't be captured. Add your own screenshot instead.",
	)
	if(capture_nonce)
		capture_window?.send_message("bug-report/capture-abort", list("nonce" = capture_nonce))
	if(capture_path)
		fdel(capture_path)
	if(capture_picture)
		end_new_image(capture_picture)
	capture_path = null
	capture_nonce = null
	capture_window = null
	capture_ui = null
	capture_picture = null
	// A reason we don't know, or one that isn't text at all, reads as the capture failing
	finish_action((istext(reason) && messages[reason]) || messages["failed"], targets = TRUE)

/**
 * Takes one message of a capture from its window - its preview showing, a chunk to stage, or the reporter cancelling.
 *
 * Chunks come in order, each acknowledged before the next, and go straight to a file as the base64 they
 * are. We never decode or hold the image. Returns whether the message belonged to the capture.
 * Arguments:
 * * window - the window the message came from
 * * type - bug-report/capture-ready, bug-report/capture-chunk or bug-report/capture-cancel
 * * payload - the message's decoded payload, a cancel's with the window's reason
 */
/datum/bug_report/proc/receive_ui_capture(datum/tgui_window/window, type, list/payload)
	if(!islist(payload) || !capture_nonce || window != capture_window || payload["nonce"] != capture_nonce)
		return FALSE
	if(world.time >= capture_until)
		cancel_ui_capture("expired")
		return FALSE
	if(!capture_window_allowed(window) || window.locked_by != capture_ui)
		cancel_ui_capture("closed")
		return FALSE
	if(type == "bug-report/capture-ready")
		capture_ready = TRUE
		return TRUE
	if(type == "bug-report/capture-cancel")
		cancel_ui_capture(isnull(payload["reason"]) ? "cancelled" : payload["reason"])
		return TRUE
	var/chunk = payload["data"]
	var/index = payload["index"]
	var/total = payload["totalLength"]
	// The last chunk again means our acknowledgement was lost on the way, so we acknowledge it again
	if(index == capture_next - 1 && total == capture_total)
		window.send_message("bug-report/capture-ack", list("nonce" = capture_nonce, "index" = index))
		return TRUE
	var/static/regex/base64 = regex(@"^[A-Za-z0-9+/]*={0,2}$")
	if(index != capture_next || !istext(chunk) || !isnum(total) || total <= 0 || total > BUG_REPORT_CAPTURE_MAX || total % 4 || (capture_total && total != capture_total) || length(chunk) != min(BUG_REPORT_CAPTURE_CHUNK, total - capture_received) || !base64.Find(chunk) || (capture_received + length(chunk) < total && findtextEx(chunk, "=")))
		cancel_ui_capture("interrupted")
		return FALSE
	capture_path ||= bug_report_temporary_path("capture")
	if(rustg_file_append(chunk, capture_path))
		cancel_ui_capture("not_saved")
		return FALSE
	capture_received += length(chunk)
	capture_total = total
	capture_next++
	var/list/ack = list("nonce" = capture_nonce, "index" = index)
	if(capture_received < capture_total)
		window.send_message("bug-report/capture-ack", ack)
		return TRUE
	var/path = capture_path
	var/datum/bug_report_picture/picture = capture_picture
	capture_path = null
	capture_nonce = null
	capture_window = null
	capture_ui = null
	capture_picture = null
	// The upload owns the file now, including deleting it, so nothing the report window does next can strand it
	INVOKE_ASYNC(src, PROC_REF(upload_picture), picture, path, "base64")
	// The last one says whether the report window came forward, so the overlay knows it can close
	ack["forward"] = bring_forward()
	window.send_message("bug-report/capture-ack", ack)
	return TRUE

/// Brings the report window in front of the reporter's others, returning whether one was open to bring
/datum/bug_report/proc/bring_forward()
	for(var/datum/tgui/ui as anything in open_uis)
		if(ui.window && !ui.closing)
			ui.window.bring_to_front()
			return TRUE
	return FALSE

/// Brings this window in front of the player's others
/datum/tgui_window/proc/bring_to_front()
	winset(client, id, "focus=true")

#undef BUG_REPORT_CAPTURE_MAX
#undef BUG_REPORT_CAPTURE_READY_WAIT
