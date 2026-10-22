/// Most base64 characters one capture may send - 2 MiB of image, the bridge's own cap for captures
#define BUG_REPORT_CAPTURE_MAX 2796204

/datum/bug_report
	/// The window a capture was asked of
	var/datum/tgui_window/capture_window
	/// The UI that window showed when asked, so a reused window can't answer for it
	var/datum/tgui/capture_ui
	/// Ties a capture's messages to the request that started it
	var/capture_nonce
	/// Where the capture's base64 is staged
	var/capture_path
	/// When an unfinished capture gives up
	var/capture_until = 0
	/// The next chunk index we take
	var/capture_next = 0
	/// Base64 characters staged so far
	var/capture_received = 0
	/// The capture's whole base64 length, fixed by its first chunk
	var/capture_total = 0
	COOLDOWN_DECLARE(capture_cooldown)

/// The reporter's other open TGUI windows a capture could be taken of, for the page's picker
/datum/bug_report/proc/capture_targets()
	var/list/targets = list()
	if(!valid_owner())
		return targets
	for(var/id in owner.tgui_windows)
		var/datum/tgui_window/window = owner.tgui_windows[id]
		if(capture_window_allowed(window))
			targets += list(list("id" = id, "title" = "[window.locked_by.title || window.locked_by.interface] ([id])"))
	return targets

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
 */
/datum/bug_report/proc/begin_ui_capture(window_id)
	if(busy || capture_nonce || !valid_owner() || (result?["kind"] in list("accepted", "checking")) || !istext(window_id))
		return
	if(!COOLDOWN_FINISHED(src, capture_cooldown))
		status = "Wait a few seconds before taking another snapshot."
		push_update()
		return
	if(!take_allowance("uploads", spend = FALSE))
		push_update()
		return
	var/datum/tgui_window/window = owner.tgui_windows[window_id]
	if(!capture_window_allowed(window))
		status = "That TGUI is no longer open. Select one of your active windows."
		push_update()
		return
	var/datum/tgui/selected_ui = window.locked_by
	busy = TRUE
	push_update()
	if(!save_fields() || !capture_window_allowed(window) || window.locked_by != selected_ui)
		busy = FALSE
		push_update()
		return
	COOLDOWN_START(src, capture_cooldown, 10 SECONDS)
	capture_window = window
	capture_ui = selected_ui
	// Only correlates messages, the owner and the exact window and UI are what we trust
	capture_nonce = GUID()
	capture_until = world.time + 3 MINUTES
	capture_next = 0
	capture_received = 0
	capture_total = 0
	status = "Preview and optionally crop the snapshot in the selected TGUI."
	window.send_message("bug-report/capture", list("nonce" = capture_nonce, "chunk" = BUG_REPORT_CAPTURE_CHUNK, "limit" = BUG_REPORT_CAPTURE_MAX))
	addtimer(CALLBACK(src, PROC_REF(expire_ui_capture), capture_nonce), 3 MINUTES)
	push_update()

/// Gives up on a capture still unfinished when its time runs out
/datum/bug_report/proc/expire_ui_capture(nonce)
	if(capture_nonce == nonce)
		cancel_ui_capture("UI snapshot expired. Try again or choose a screenshot file.")

/// Ends the capture, telling its window to stop and deleting whatever was staged
/datum/bug_report/proc/cancel_ui_capture(message = "UI snapshot cancelled.")
	if(capture_nonce)
		capture_window?.send_message("bug-report/capture-abort", list("nonce" = capture_nonce))
	if(capture_path)
		fdel(capture_path)
	capture_path = null
	capture_nonce = null
	capture_window = null
	capture_ui = null
	busy = FALSE
	status = message
	push_update()

/**
 * Takes one message of a capture from its window - a chunk to stage, or the reporter cancelling.
 *
 * Chunks come in order, each acknowledged before the next, and go straight to a file as the base64 they
 * are. We never decode or hold the image. Returns whether the message belonged to the capture.
 * Arguments:
 * * window - the window the message came from
 * * type - bug-report/capture-chunk or bug-report/capture-cancel
 * * payload - the message's decoded payload
 */
/datum/bug_report/proc/receive_ui_capture(datum/tgui_window/window, type, list/payload)
	if(!islist(payload) || !capture_nonce || window != capture_window || payload["nonce"] != capture_nonce)
		return FALSE
	if(!capture_window_allowed(window) || window.locked_by != capture_ui || world.time >= capture_until)
		cancel_ui_capture("The selected TGUI changed or closed. No snapshot was attached.")
		return FALSE
	if(type == "bug-report/capture-cancel")
		cancel_ui_capture()
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
		cancel_ui_capture("UI snapshot transfer was interrupted. Try again.")
		return FALSE
	capture_path ||= bug_report_temporary_path("capture")
	if(rustg_file_append(chunk, capture_path))
		cancel_ui_capture("Could not stage the UI snapshot.")
		return FALSE
	capture_received += length(chunk)
	capture_total = total
	capture_next++
	window.send_message("bug-report/capture-ack", list("nonce" = capture_nonce, "index" = index))
	if(capture_received < capture_total)
		return TRUE
	var/path = capture_path
	capture_path = null
	capture_nonce = null
	capture_window = null
	capture_ui = null
	// The upload owns the file now, including deleting it
	INVOKE_ASYNC(src, PROC_REF(upload_staged_screenshot), path, "base64")
	return TRUE

#undef BUG_REPORT_CAPTURE_MAX
