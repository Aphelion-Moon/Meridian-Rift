/// This protocol belongs only to an authenticated client's explicitly selected
/// active TGUI. It never uses the generic oversized TGUI payload assembler.
/datum/bug_report
	var/datum/tgui_window/capture_window
	var/datum/tgui/capture_ui
	var/capture_nonce
	var/capture_path
	var/capture_until = 0
	var/capture_next = 0
	var/capture_received = 0
	var/capture_total = 0
	var/capture_last_hash

/datum/bug_report/proc/capture_targets()
	var/list/targets = list()
	if(!valid_owner())
		return targets
	for(var/id in owner.tgui_windows)
		var/datum/tgui_window/window = owner.tgui_windows[id]
		if(capture_window_allowed(window))
			targets += list(list("id" = id, "title" = "[window.locked_by.title || window.locked_by.interface] ([id])"))
	return targets

/datum/bug_report/proc/capture_window_allowed(datum/tgui_window/window)
	if(!valid_owner() || !owner || !window)
		return FALSE
	if(window.client != owner || !window.visible || window.status != TGUI_WINDOW_READY || !window.locked)
		return FALSE
	var/datum/tgui/ui = window.locked_by
	return ui && !ui.closing && ui.user == owner.mob && ui.src_object != src && ui.interface != "BugReport"

/datum/bug_report/proc/begin_ui_capture(window_id)
	if(busy || capture_nonce || !valid_owner() || (result?["kind"] in list("accepted", "checking")) || !istext(window_id))
		return
	var/datum/tgui_window/window = owner.tgui_windows[window_id]
	if(!capture_window_allowed(window))
		status = "That TGUI is no longer open. Select one of your active windows."
		return
	var/datum/tgui/selected_ui = window.locked_by
	busy = TRUE
	SStgui.update_uis(src)
	if(!registered)
		register_context()
	if(!valid_owner() || !save_fields() || !capture_window_allowed(window) || window.locked_by != selected_ui)
		busy = FALSE
		SStgui.update_uis(src)
		return
	capture_window = window
	capture_ui = selected_ui
	// Correlation nonce only; authenticated owner + exact window/UI are authority.
	capture_nonce = GUID()
	capture_until = world.time + 3 MINUTES
	capture_next = 0
	capture_received = 0
	capture_total = 0
	capture_last_hash = null
	status = "Preview and optionally crop the snapshot in the selected TGUI."
	window.send_message("bug-report/capture", list("nonce" = capture_nonce))
	addtimer(CALLBACK(src, PROC_REF(expire_ui_capture), capture_nonce), 3 MINUTES)
	SStgui.update_uis(src)

/datum/bug_report/proc/expire_ui_capture(nonce)
	if(capture_nonce == nonce)
		cancel_ui_capture("UI snapshot expired. Try again or choose a screenshot file.")

/datum/bug_report/proc/cancel_ui_capture(message = "UI snapshot cancelled.")
	if(capture_nonce)
		capture_window?.send_message("bug-report/capture-abort", list("nonce" = capture_nonce))
	if(capture_path)
		fdel(capture_path)
	capture_path = null
	capture_nonce = null
	capture_window = null
	capture_ui = null
	capture_received = 0
	capture_total = 0
	capture_next = 0
	busy = FALSE
	status = message
	SStgui.update_uis(src)

/datum/bug_report/proc/receive_ui_capture(datum/tgui_window/window, type, list/payload)
	if(!islist(payload) || !capture_nonce || window != capture_window || payload["nonce"] != capture_nonce)
		return FALSE
	if(!capture_window_allowed(window) || window.locked_by != capture_ui || world.time >= capture_until)
		cancel_ui_capture("The selected TGUI changed or closed. No snapshot was attached.")
		return FALSE
	if(type == "bug-report/capture-cancel")
		cancel_ui_capture()
		return TRUE
	if(type != "bug-report/capture-chunk")
		return FALSE
	var/chunk = payload["data"]
	var/index = payload["index"]
	var/total = payload["totalLength"]
	if(!istext(chunk) || !length(chunk) || length(chunk) > 32768 || !isnum(index) || round(index) != index || !isnum(total) || round(total) != total || total <= 0 || total > 2796204 || total % 4)
		cancel_ui_capture("Invalid UI snapshot transfer. Choose a screenshot file instead.")
		return FALSE
	// A repeated, identical last chunk is acknowledged without appending it twice.
	if(index == capture_next - 1 && total == capture_total && md5(chunk) == capture_last_hash)
		window.send_message("bug-report/capture-ack", list("nonce" = capture_nonce, "index" = index, "accepted" = TRUE))
		return TRUE
	var/static/regex/encoded_chunk = regex(@"^[A-Za-z0-9+/]*={0,2}$")
	if(index != capture_next || (capture_total && total != capture_total) || length(chunk) != min(32768, total - capture_received) || !encoded_chunk.Find(chunk) || (capture_received + length(chunk) < total && findtext(chunk, "=")))
		cancel_ui_capture("UI snapshot transfer was interrupted. Try again.")
		return FALSE
	if(!capture_path)
		capture_path = bug_report_temporary_path("capture")
	// Small ASCII chunks go straight to a generated file; no image decode, no
	// complete base64 string, and no pixels are retained in the game VM.
	append_capture_chunk(chunk, capture_path)
	if(!fexists(capture_path))
		cancel_ui_capture("Could not stage the UI snapshot.")
		return FALSE
	capture_received += length(chunk)
	capture_total = total
	capture_next++
	capture_last_hash = md5(chunk)
	window.send_message("bug-report/capture-ack", list("nonce" = capture_nonce, "index" = index, "accepted" = TRUE))
	if(capture_received == capture_total)
		var/path = capture_path
		capture_path = null
		capture_nonce = null
		capture_window = null
		capture_ui = null
		// The upload coroutine now owns cleanup, including owner loss or timeout.
		INVOKE_ASYNC(src, PROC_REF(upload_staged_screenshot), path, "base64")
	return TRUE

/datum/bug_report/proc/append_capture_chunk(chunk, path)
	rustg_file_append(chunk, path)
