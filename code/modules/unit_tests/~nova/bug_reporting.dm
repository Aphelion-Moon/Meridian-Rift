/// A mock connection that can own bug reports
/datum/client_interface/bug_report
	var/datum/bug_report/bug_report_draft
	var/list/bug_report_history
	var/bug_report_session_id
	var/list/tgui_windows = list()
	var/tgui_oversized_log_cooldown = 0
	var/atom/eye

/datum/client_interface/bug_report/Destroy(force)
	// The test windows hold us as their client, so we let go of them or neither is ever collected
	bug_report_draft = null
	bug_report_history = null
	tgui_windows = null
	return ..()

/// A report whose bridge is a script, so no request ever leaves a test
/datum/bug_report/test
	/// Replies the next bridge calls get, in order
	var/list/replies = list()
	/// Every call this report made - its route, decoded body, headers and whether its body file existed
	var/list/calls = list()

/datum/bug_report/test/bridge_call(route, body = "", list/headers, body_file, output_file, timeout = 10)
	calls += list(list("route" = route, "body" = length(body) ? json_decode(body) : null, "headers" = headers, "file_existed" = body_file && fexists(body_file)))
	refused = FALSE
	// The saved file exists whatever the answer, so only the answer can say it's a preview
	if(output_file)
		text2file("preview", output_file)
	if(!length(replies))
		return null
	var/reply = replies[1]
	replies.Cut(1, 2)
	// A scripted HTTP answer is read like a real one
	if(istype(reply, /datum/http_response))
		return bridge_reply(reply, output_file)
	return reply

/// An answer from the bridge with this status and JSON body, for the scripted bridge to read like a real one
/proc/bug_report_test_answer(status_code, list/body)
	var/datum/http_response/answer = new
	answer.status_code = status_code
	answer.body = json_encode(body)
	return answer

/// An open report window with nobody behind it, keeping what it was sent
/datum/tgui/bug_report_test
	var/list/updates = list()

/datum/tgui/bug_report_test/New()
	return

/datum/tgui/bug_report_test/send_update(custom_data, force)
	updates += list(custom_data)

/datum/tgui/bug_report_test/close(can_be_suspended = TRUE)
	return

/// A test window that breaks on its second update, for whatever breaks once a render has started
/datum/tgui/bug_report_test/broken

/datum/tgui/bug_report_test/broken/send_update(custom_data, force)
	if(length(updates))
		throw EXCEPTION("The test window broke")
	return ..()

/// A TGUI window with nobody behind it, keeping what it was sent
/datum/tgui_window/bug_report_test
	var/list/messages = list()
	/// Whether it breaks when it's brought forward, for whatever has to be done before a capture's answer
	var/broken = FALSE

/datum/tgui_window/bug_report_test/New(client, id)
	src.client = client
	src.id = id
	status = TGUI_WINDOW_READY
	visible = TRUE

/datum/tgui_window/bug_report_test/send_message(type, list/payload, force)
	messages += list(list("type" = type, "payload" = payload))

/datum/tgui_window/bug_report_test/close(can_be_suspended = TRUE, logout = FALSE)
	return

/datum/tgui_window/bug_report_test/bring_to_front()
	if(broken)
		throw EXCEPTION("The test window broke")
	messages += list(list("type" = "focus"))

/// A test window that keeps every message reaching it instead of acting on it
/datum/tgui_window/bug_report_test/inbox

/datum/tgui_window/bug_report_test/inbox/on_message(type, list/payload, list/href_list)
	messages += list(list("type" = type, "payload" = payload))

/// Stands in for usr, so tgui_Topic() finds its windows on a mock connection
/datum/bug_report_test_sender
	var/datum/client_interface/bug_report/client

/// Makes a report owned by a fresh mock connection, its context already with the bridge
/proc/bug_report_test_report(datum/unit_test/test)
	var/datum/client_interface/bug_report/reporter = test.allocate(/datum/client_interface/bug_report)
	var/datum/bug_report/test/report = test.allocate(/datum/bug_report/test, reporter)
	reporter.bug_report_draft = report
	LAZYADD(reporter.bug_report_history, report)
	report.context_saved = TRUE
	return report

/// Gives the report another of its owner's TGUI windows to capture, showing some other UI
/proc/bug_report_test_window(datum/bug_report/test/report, id = "tgui-window-2", title = "Vending machine")
	var/datum/tgui_window/bug_report_test/window = new(report.owner, id)
	var/datum/tgui/bug_report_test/ui = new
	ui.interface = "Vending"
	ui.title = title
	window.locked = TRUE
	window.locked_by = ui
	report.owner.tgui_windows[id] = window
	return window

/// Gives the report a picture whose image the service holds and checked
/proc/bug_report_test_picture(datum/bug_report/test/report, attachment_id = "image", source = "file")
	var/datum/bug_report_picture/picture = report.picture_for(null, source)
	LAZYADD(report.pictures, picture)
	picture.update_attachment(list("id" = attachment_id, "state" = "ready", "publicConsent" = FALSE))
	return picture

/// The payload of the last chunk acknowledgement a test window got, or null with none
/proc/bug_report_test_last_ack(datum/tgui_window/bug_report_test/window)
	for(var/position in length(window.messages) to 1 step -1)
		var/list/message = window.messages[position]
		if(message["type"] == "bug-report/capture-ack")
			return message["payload"]

/// A staged image for an upload to send
/proc/bug_report_test_image()
	var/path = bug_report_temporary_path("upload")
	text2file("image", path)
	return path

/// Every guard on a picture action holds, which DM's loose `in` once let through
/datum/unit_test/bug_report_guards

/datum/unit_test/bug_report_guards/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(report)
	var/datum/bug_report_picture/picture = bug_report_test_picture(report)
	report.busy = TRUE
	report.begin_ui_capture(window.id)
	report.choose_screenshot()
	report.begin_view_capture()
	report.remove_picture(picture.id)
	report.picture_consent(picture.id, TRUE)
	TEST_ASSERT_EQUAL(length(report.calls), 0, "A busy report started a bridge call")
	TEST_ASSERT_NULL(report.capture_nonce, "A busy report started a capture")
	TEST_ASSERT_EQUAL(LAZYLEN(report.pictures), 1, "A busy report added or lost a picture")
	report.busy = FALSE
	report.picture_consent(picture.id, TRUE)
	TEST_ASSERT_EQUAL(length(report.calls), 0, "Public sharing went out before the reporter saw the preview")
	picture.preview_seen = TRUE
	report.picture_consent(picture.id + 1, TRUE)
	report.remove_picture(picture.id + 1)
	TEST_ASSERT_EQUAL(length(report.calls), 0, "A picture the report doesn't have reached the bridge")
	report.replies = list(list("attachment" = list("id" = "image", "state" = "ready", "publicConsent" = TRUE)))
	report.picture_consent(picture.id, TRUE)
	TEST_ASSERT_EQUAL(length(report.calls), 1, "Sharing a picture whose preview was seen made no call")
	var/list/consent = report.calls[1]
	TEST_ASSERT_EQUAL(consent["headers"]["x-public-consent"], "true", "Sharing sent the wrong answer")
	TEST_ASSERT_EQUAL(consent["headers"]["x-report-attachment"], "image", "Sharing named the wrong image")
	TEST_ASSERT(picture.public_consent, "The sharing reply wasn't taken")
	report.begin_ui_capture(window.id)
	TEST_ASSERT_NOTNULL(report.capture_nonce, "A capture of an owned window didn't start")
	window.on_message("close", null, list())
	TEST_ASSERT_NULL(report.capture_nonce, "Closing the captured window left its capture running")
	TEST_ASSERT(!report.busy, "Closing the captured window left the report busy")
	TEST_ASSERT_EQUAL(report.status, "That window closed or changed, so nothing was added.", "Closing the captured window didn't say so")
	TEST_ASSERT_EQUAL(LAZYLEN(report.pictures), 1, "The closed capture's new picture stayed")

/// The capture protocol stages ordered, bounded base64 straight to a file and hands it to the upload
/datum/unit_test/bug_report_capture

/datum/unit_test/bug_report_capture/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(report)
	report.begin_ui_capture(window.id)
	var/nonce = report.capture_nonce
	TEST_ASSERT_NOTNULL(nonce, "The capture didn't start")
	var/list/request = window.messages[1]
	TEST_ASSERT_EQUAL(request["payload"]["chunk"], BUG_REPORT_CAPTURE_CHUNK, "The window wasn't told the chunk size")
	var/total = BUG_REPORT_CAPTURE_CHUNK + 4
	var/first = random_string(BUG_REPORT_CAPTURE_CHUNK, list("A"))
	TEST_ASSERT(!report.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = "wrong", "index" = 0, "totalLength" = total, "data" = first)), "A wrong nonce was taken")
	TEST_ASSERT_NULL(report.capture_path, "A wrong nonce staged a file")
	TEST_ASSERT(report.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = nonce, "index" = 0, "totalLength" = total, "data" = first)), "The first chunk was refused")
	var/path = report.capture_path
	TEST_ASSERT_EQUAL(length(file2text(path)), BUG_REPORT_CAPTURE_CHUNK, "The first chunk wasn't staged whole")
	TEST_ASSERT(report.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = nonce, "index" = 0, "totalLength" = total, "data" = first)), "A resent chunk wasn't acknowledged again")
	TEST_ASSERT_EQUAL(length(file2text(path)), BUG_REPORT_CAPTURE_CHUNK, "A resent chunk was staged twice")
	TEST_ASSERT_EQUAL(LAZYLEN(report.pictures), 1, "The capture's picture wasn't added")
	var/datum/bug_report_picture/picture = report.pictures[1]
	TEST_ASSERT_EQUAL(picture.window_data()["state"], "waiting", "The capture's picture doesn't wait on its window")
	TEST_ASSERT_EQUAL(picture.title, "Vending machine", "The capture's picture doesn't name its window")
	report.replies = list(list("attachment" = list("id" = "capture", "state" = "processing", "publicConsent" = FALSE)))
	TEST_ASSERT(report.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = nonce, "index" = 1, "totalLength" = total, "data" = "AA==")), "The last chunk was refused")
	UNTIL(!report.busy)
	TEST_ASSERT_EQUAL(length(report.calls), 1, "The finished capture wasn't uploaded once")
	var/list/upload = report.calls[1]
	TEST_ASSERT_EQUAL(upload["headers"]["x-report-encoding"], "base64", "The capture went up without its encoding")
	TEST_ASSERT_EQUAL(upload["headers"]["x-report-source"], "window", "The capture went up without where it came from")
	TEST_ASSERT(upload["file_existed"], "The staged capture was gone before its upload")
	TEST_ASSERT(!fexists(path), "The staged capture outlived its upload")
	TEST_ASSERT_EQUAL(picture.attachment_id, "capture", "The upload's image wasn't taken")
	TEST_ASSERT_EQUAL(picture.window_data()["state"], "processing", "The picture doesn't wait on the service's check")
	TEST_ASSERT_EQUAL(bug_report_test_last_ack(window)?["forward"], FALSE, "The last chunk's answer brought forward a report window that isn't open")

	// With the report window open, the capture arriving brings it forward, and the overlay hears so
	var/datum/bug_report/test/forwarded = bug_report_test_report(src)
	var/datum/tgui/bug_report_test/report_ui = allocate(/datum/tgui/bug_report_test)
	report_ui.window = new /datum/tgui_window/bug_report_test(forwarded.owner, "tgui-window-1")
	LAZYADD(forwarded.open_uis, report_ui)
	window = bug_report_test_window(forwarded)
	forwarded.begin_ui_capture(window.id)
	forwarded.replies = list(list("attachment" = list("id" = "forwarded", "state" = "processing", "publicConsent" = FALSE)))
	TEST_ASSERT(forwarded.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = forwarded.capture_nonce, "index" = 0, "totalLength" = 4, "data" = "AAAA")), "A one-chunk capture was refused")
	UNTIL(!forwarded.busy)
	TEST_ASSERT_EQUAL(bug_report_test_last_ack(window)?["forward"], TRUE, "The overlay wasn't told the report window came forward")
	var/datum/tgui_window/bug_report_test/report_window = report_ui.window
	var/list/last_message = LAZYACCESS(report_window.messages, length(report_window.messages))
	TEST_ASSERT_EQUAL(last_message?["type"], "focus", "The report window wasn't brought forward when its capture arrived")
	LAZYREMOVE(forwarded.open_uis, report_ui)

	// A report window that breaks as it comes forward still gets its capture, and leaves no transfer open
	var/datum/bug_report/test/stuck = bug_report_test_report(src)
	var/datum/tgui/bug_report_test/stuck_ui = allocate(/datum/tgui/bug_report_test)
	var/datum/tgui_window/bug_report_test/stuck_window = new(stuck.owner, "tgui-window-1")
	stuck_window.broken = TRUE
	stuck_ui.window = stuck_window
	LAZYADD(stuck.open_uis, stuck_ui)
	window = bug_report_test_window(stuck)
	stuck.begin_ui_capture(window.id)
	stuck.replies = list(list("attachment" = list("id" = "stuck", "state" = "processing", "publicConsent" = FALSE)))
	var/broke = FALSE
	try
		stuck.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = stuck.capture_nonce, "index" = 0, "totalLength" = 4, "data" = "AAAA"))
	catch
		broke = TRUE
	TEST_ASSERT(broke, "The report window didn't break as it came forward, so this proves nothing")
	// Bounded, since a capture stuck open keeps the report busy for minutes
	var/give_up = world.time + 5 SECONDS
	UNTIL(!stuck.busy || world.time > give_up)
	TEST_ASSERT_NULL(stuck.capture_nonce, "A report window breaking as it came forward left its capture's transfer open")
	TEST_ASSERT_EQUAL(length(stuck.calls), 1, "A report window breaking as it came forward kept its capture from uploading")
	LAZYREMOVE(stuck.open_uis, stuck_ui)

	var/datum/bug_report/test/oversized = bug_report_test_report(src)
	window = bug_report_test_window(oversized)
	oversized.begin_ui_capture(window.id)
	TEST_ASSERT(!oversized.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = oversized.capture_nonce, "index" = 0, "totalLength" = 2796208, "data" = first)), "A capture over 2 MiB was taken")
	TEST_ASSERT_NULL(oversized.capture_nonce, "An oversized capture kept running")

	var/datum/bug_report/test/unordered = bug_report_test_report(src)
	window = bug_report_test_window(unordered)
	unordered.begin_ui_capture(window.id)
	TEST_ASSERT(!unordered.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = unordered.capture_nonce, "index" = 1, "totalLength" = 4, "data" = "AAAA")), "An out of order chunk was taken")

	var/datum/bug_report/test/cancelled = bug_report_test_report(src)
	window = bug_report_test_window(cancelled)
	cancelled.begin_ui_capture(window.id)
	cancelled.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = cancelled.capture_nonce, "index" = 0, "totalLength" = total, "data" = first))
	path = cancelled.capture_path
	cancelled.cancel_ui_capture()
	TEST_ASSERT(!fexists(path) && !cancelled.busy, "Cancelling left the staged file or a busy report")
	TEST_ASSERT_NULL(cancelled.pictures, "Cancelling a new capture left its picture")

/// A window that never shows its preview, like one whose renderer died drawing it, loses its capture in seconds
/datum/unit_test/bug_report_capture_ready

/datum/unit_test/bug_report_capture_ready/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(report)
	report.begin_ui_capture(window.id)
	TEST_ASSERT_NOTNULL(report.capture_nonce, "The capture didn't start")
	var/datum/timedevent/ready_check
	for(var/datum/timedevent/timer as anything in report._active_timers)
		if(timer.callBack.delegate == TYPE_PROC_REF(/datum/bug_report, expire_unready_capture))
			ready_check = timer
	TEST_ASSERT_NOTNULL(ready_check, "The capture doesn't wait for its window to answer")
	TEST_ASSERT(ready_check.wait < 1 MINUTES, "The capture waits minutes on a window that may be dead")
	ready_check.callBack.Invoke()
	TEST_ASSERT_NULL(report.capture_nonce, "A capture whose window never answered kept running")
	TEST_ASSERT(!report.busy, "A capture whose window never answered left the report busy")
	TEST_ASSERT(findtext(report.status, "didn't answer"), "The report didn't say the window never answered")
	var/list/abort = window.messages[length(window.messages)]
	TEST_ASSERT_EQUAL(abort["type"], "bug-report/capture-abort", "The silent window wasn't told to stop")

	var/datum/bug_report/test/answered = bug_report_test_report(src)
	window = bug_report_test_window(answered)
	answered.begin_ui_capture(window.id)
	var/nonce = answered.capture_nonce
	window.on_message("bug-report/capture-ready", list("nonce" = "wrong"), list())
	TEST_ASSERT(!answered.capture_ready, "A ready for another capture was taken")
	window.on_message("bug-report/capture-ready", list("nonce" = nonce), list())
	TEST_ASSERT(answered.capture_ready, "The window's ready didn't reach its capture")
	answered.expire_unready_capture(nonce)
	TEST_ASSERT_EQUAL(answered.capture_nonce, nonce, "A capture whose window answered was ended")
	answered.cancel_ui_capture()
	COOLDOWN_RESET(answered, capture_cooldown)
	answered.begin_ui_capture(window.id)
	TEST_ASSERT(answered.capture_nonce && answered.capture_nonce != nonce, "The next capture didn't start")
	TEST_ASSERT(!answered.capture_ready, "The last capture's ready carried over to the next")
	window.on_message("bug-report/capture-ready", list("nonce" = nonce), list())
	TEST_ASSERT(!answered.capture_ready, "A late ready from the ended capture was taken")
	answered.expire_unready_capture(nonce)
	TEST_ASSERT_NOTNULL(answered.capture_nonce, "The ended capture's ready check ended the next one")

/// The biggest report a page can send reaches its window whole, while a pasted novel is dropped before we decode it
/datum/unit_test/bug_report_payload_bound

/datum/unit_test/bug_report_payload_bound/Run()
	var/datum/client_interface/bug_report/reporter = allocate(/datum/client_interface/bug_report)
	var/datum/tgui_window/bug_report_test/inbox/window = new(reporter, "tgui-window-1")
	reporter.tgui_windows[window.id] = window
	var/datum/bug_report_test_sender/sender = new
	sender.client = reporter
	// The form's four fields at their limits in three-byte letters, the most an honest page sends
	var/full_text = ascii2text(23383)
	while(length_char(full_text) < 8000)
		full_text += full_text
	full_text = copytext_char(full_text, 1, 8001)
	var/report = "{\"fields\":{\"title\":\"[copytext_char(full_text, 1, 161)]\",\"observed\":\"[full_text]\",\"expected\":\"[full_text]\",\"reproduction\":\"[full_text]\",\"category\":\"Other\",\"severity\":\"unspecified\",\"incidentAt\":null},\"fieldsEpoch\":1}"
	var/pasted = "a"
	while(length(pasted) < 2 * 1024 * 1024)
		pasted += pasted
	var/old_usr = usr
	usr = sender
	tgui_Topic(list("tgui" = "1", "type" = "act/submit", "window_id" = window.id, "payload" = report))
	tgui_Topic(list("tgui" = "1", "type" = "act/Save", "window_id" = window.id, "payload" = "{\"note\":\"[pasted]\"}"))
	var/logged = reporter.tgui_oversized_log_cooldown
	tgui_Topic(list("tgui" = "1", "type" = "act/Save", "window_id" = window.id, "payload" = "{\"note\":\"[pasted]\"}"))
	usr = old_usr
	TEST_ASSERT(length(report) > 72000, "The report is smaller than the most an honest page sends")
	TEST_ASSERT_EQUAL(length(window.messages), 1, "The novel reached its window, or the report didn't")
	var/list/received = window.messages[1]
	TEST_ASSERT_EQUAL(received["type"], "act/submit", "The report didn't reach its window")
	TEST_ASSERT_EQUAL(length_char(received["payload"]["fields"]["reproduction"]), 8000, "The report arrived cut short")
	TEST_ASSERT(logged > world.time, "The dropped novel wasn't logged")
	TEST_ASSERT_EQUAL(reporter.tgui_oversized_log_cooldown, logged, "A second novel inside the minute was logged again")

/// The hourly allowances mirror the reporting service's caps, and the service never sees a refused one
/datum/unit_test/bug_report_budgets

/datum/unit_test/bug_report_budgets/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/ckey = report.context["ckey"]
	for(var/accepted in 1 to 5)
		bug_report_budget(ckey, "accepted")
	report.fields = list("title" = "Door", "expected" = "Open", "reproduction" = "1. Click it", "category" = "Other", "severity" = "minor", "incidentAt" = null)
	report.submit_fields()
	TEST_ASSERT_EQUAL(length(report.calls), 0, "A sixth report in the hour reached the service")
	var/list/limit = report.ui_data()["limit"]
	TEST_ASSERT_EQUAL(limit?["kind"], "reports", "The window wasn't told which limit holds sending")
	TEST_ASSERT(limit["retryIn"] > 59 MINUTES * 100 && limit["retryIn"] <= 1 HOURS * 100, "The wait didn't reach the window in ms")
	var/list/uses = GLOB.bug_report_budgets["[ckey]:accepted"]
	uses[1] = world.time - 1 HOURS
	TEST_ASSERT_EQUAL(bug_report_budget(ckey, "accepted", spend = FALSE), 0, "An hour-old acceptance still counted")
	TEST_ASSERT_EQUAL(bug_report_uses_left(ckey, "submits"), 10, "Checking an allowance used it")
	TEST_ASSERT_NULL(GLOB.bug_report_budgets["[ckey]:submits"], "Checking an allowance kept an empty list")
	for(var/upload in 1 to 5)
		TEST_ASSERT_EQUAL(bug_report_budget(ckey, "uploads"), 0, "Upload [upload] of 5 was refused")
	TEST_ASSERT(bug_report_budget(ckey, "uploads") > 0, "A sixth upload of their own in the hour was allowed")
	TEST_ASSERT_EQUAL(report.ui_data()["uploadsLeft"], 0, "The window wasn't told no uploads are left")
	var/datum/bug_report_picture/own = report.picture_for(null, "file")
	LAZYADD(report.pictures, own)
	var/path = bug_report_test_image()
	report.upload_picture(own, path)
	TEST_ASSERT_EQUAL(length(report.calls), 0, "An upload past the allowance reached the bridge")
	TEST_ASSERT(!fexists(path), "A refused upload kept its staged file")
	TEST_ASSERT_NULL(report.pictures, "A refused upload kept its new picture")
	TEST_ASSERT(findtext(report.status, "Captures still work"), "The refusal didn't say captures still work")
	var/datum/bug_report_picture/capture = report.picture_for(null, "window")
	LAZYADD(report.pictures, capture)
	report.replies = list(list("attachment" = list("id" = "capture", "state" = "ready", "publicConsent" = FALSE)))
	report.upload_picture(capture, bug_report_test_image(), "base64")
	TEST_ASSERT_EQUAL(length(report.calls), 1, "A capture was held by the reporter's own uploads")

/// Typed text stays local until an action, a stale page can't overwrite newer text, and an accepted report is fixed
/datum/unit_test/bug_report_fields

/datum/unit_test/bug_report_fields/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/list/fields = list("title" = "Door", "expected" = "Open", "reproduction" = "1. Click it", "category" = "Gameplay", "severity" = "minor", "observed" = "Closed", "incidentAt" = "2026-10-22T12:34:56.789Z")
	TEST_ASSERT(report.update_local_fields(fields, 0), "Valid fields were refused")
	TEST_ASSERT(report.fields_dirty, "New text wasn't marked unsaved")
	TEST_ASSERT_EQUAL(report.fields["category"], "Gameplay", "A category the window offers wasn't taken")
	TEST_ASSERT_NULL(report.fields["incidentAt"], "The page set an incident time the window no longer asks for")
	TEST_ASSERT(!("observed" in report.fields), "What happened? came back from the page")
	TEST_ASSERT(!report.update_local_fields(fields, -1), "A stale page's text was taken")
	var/list/static_data = report.ui_static_data()
	TEST_ASSERT(!("context" in static_data), "The window was sent the incident context")
	TEST_ASSERT(!("incidentAt" in static_data["fields"]), "The window was sent the incident time")
	TEST_ASSERT_EQUAL(length(static_data["kinds"]), 6, "The window wasn't sent every category")
	report.fields_dirty = FALSE
	TEST_ASSERT(report.update_local_fields(fields.Copy(), 0) && !report.fields_dirty, "Unchanged text was marked unsaved")
	report.result = list("kind" = "checking")
	report.submission_key = "old"
	report.polling_paused = TRUE
	fields["title"] = "Edited after a paused check"
	report.update_local_fields(fields, 0)
	TEST_ASSERT(!report.submission_key && !report.result && !report.polling_paused, "Editing a paused submission kept it")
	report.result = list("kind" = "accepted")
	TEST_ASSERT(!report.update_local_fields(fields, 0), "An accepted report's text changed")
	report.result = null
	report.replies = list(list("revisionConflict" = TRUE), list("draft" = list("revision" = 3, "fields" = fields, "attachment" = null, "intake" = "draft")))
	report.fields_dirty = TRUE
	TEST_ASSERT(!report.save_fields(), "A conflicting save claimed success")
	TEST_ASSERT_EQUAL(report.remote_draft?["revision"], 3, "The conflicting draft wasn't kept for the reporter to choose")
	report.resolve_draft(TRUE)
	TEST_ASSERT(report.revision == 3 && report.fields_dirty && !report.remote_draft, "Keeping local text didn't move onto the saved revision")
	report.adopt_draft(list("revision" = 4, "fields" = fields))
	TEST_ASSERT(report.fields["title"] == "Edited after a paused check" && !("observed" in report.fields), "A saved draft's What happened? text came back")

/// One poll timer at most, none without an open window or a wait, and a closed window stops polling
/datum/unit_test/bug_report_polling

/datum/unit_test/bug_report_polling/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	report.schedule_poll()
	TEST_ASSERT_EQUAL(LAZYLEN(report._active_timers), 0, "A poll was armed with no window open")
	var/datum/tgui/bug_report_test/ui = allocate(/datum/tgui/bug_report_test)
	LAZYADD(report.open_uis, ui)
	report.schedule_poll()
	TEST_ASSERT_EQUAL(LAZYLEN(report._active_timers), 0, "A poll was armed with nothing to wait for")
	report.result = list("kind" = "checking")
	report.submission_key = "key"
	for(var/tick in 1 to 50)
		report.schedule_poll()
	TEST_ASSERT_EQUAL(LAZYLEN(report._active_timers), 1, "Repeated scheduling stacked poll timers")
	report.replies = list(list("result" = list("kind" = "accepted", "receipt" = list("reportId" = "accepted"))))
	report.refresh()
	TEST_ASSERT_EQUAL(length(report.calls), 1, "One refresh made more than one call")
	TEST_ASSERT_EQUAL(report.result["kind"], "accepted", "The check's answer wasn't taken")
	TEST_ASSERT(length(ui.updates), "The open window wasn't sent the answer")
	LAZYREMOVE(report.open_uis, ui)
	report.poll()
	TEST_ASSERT_EQUAL(length(report.calls), 1, "A poll ran after the window closed")
	// Polls the server turns down got their answers, so however many come they never read as losing touch
	for(var/tick in 1 to 4)
		report.replies = list(bug_report_test_answer(404, list("error" = "receipt_not_found")))
		report.refresh()
	TEST_ASSERT(!report.polling_paused && report.status == "Your report is sent, but the report server didn't say how it's doing. This window asks again within a minute.", "Receipt polls the server turned down read as losing touch, or worried about a sent report's text")
	report.replies = list(list("receipt" = list("reportId" = "accepted")))
	report.refresh()
	TEST_ASSERT_NULL(report.status, "The receipt came and the line saying the server held it back stayed")
	// The sent page has no Try again, so a report server that stops answering never pauses its polls or worries about its text
	for(var/tick in 1 to 4)
		report.replies = list(bug_report_test_answer(503, list()))
		report.refresh()
	TEST_ASSERT(!report.polling_paused && report.waiting_on_service(), "Polls with no answer lost touch on a sent report, whose page has no Try again")
	TEST_ASSERT_EQUAL(report.status, "Your report is sent, but the report server isn't answering. This window asks again within a minute.", "A sent report out of reach worried about its text or asked for a Try again its page doesn't have")
	report.replies = list(bug_report_test_answer(200, list("receipt" = list("reportId" = "accepted"))))
	report.refresh()
	TEST_ASSERT(isnull(report.status) && !report.unreachable, "The receipt came and the line saying the server isn't answering stayed")
	// A reply we can't read only means the receipt's news waits as well, so the sent page says that until the receipt comes
	var/datum/http_response/garbled = new
	garbled.status_code = 200
	garbled.body = "<html>down for maintenance</html>"
	report.replies = list(garbled)
	report.refresh()
	TEST_ASSERT_EQUAL(report.status, "Your report is sent, but the report server didn't say how it's doing. This window asks again within a minute.", "A receipt reply we couldn't read worried about a sent report's text, or asked for a Try again its page doesn't have")
	report.replies = list(bug_report_test_answer(200, list("receipt" = list("reportId" = "accepted"))))
	report.refresh()
	TEST_ASSERT_NULL(report.status, "The receipt came and the line about the reply we couldn't read stayed")
	// A published report's page already has its issue and polls for nothing more, so a look out of reach or turned down has nothing to say
	report.result = list("kind" = "accepted", "receipt" = list("reportId" = "accepted", "issueUrl" = "https://example.invalid/issues/1"))
	report.replies = list(bug_report_test_answer(503, list()))
	report.refresh()
	TEST_ASSERT_NULL(report.status, "A published report out of reach said it would ask again, which nothing does")
	report.replies = list(bug_report_test_answer(404, list("error" = "receipt_not_found")))
	report.refresh()
	TEST_ASSERT_NULL(report.status, "A published report's look turned down said it would ask again, which nothing does")
	// A draft read that finds the report submitted is still on the unsent page, where nothing polls, so it keeps the read's own line
	report.result = null
	report.replies = list(list("draft" = list("revision" = report.revision, "fields" = report.fields, "intake" = "submitted")), bug_report_test_answer(503, list()))
	report.refresh()
	TEST_ASSERT_EQUAL(report.status, "Couldn't reach the report server. Your text is kept. Try again in a minute.", "The unsent page took the sent page's line, which promises a poll nothing arms there")
	// A look turned down there keeps its line too, until the receipt comes and the page it was about is gone
	report.replies = list(list("draft" = list("revision" = report.revision, "fields" = report.fields, "intake" = "submitted")), bug_report_test_answer(404, list("error" = "receipt_not_found")))
	report.refresh()
	TEST_ASSERT_EQUAL(report.status, "The report server turned that down. Your text is kept.", "The unsent page lost the line saying its receipt look was turned down")
	report.replies = list(list("draft" = list("revision" = report.revision, "fields" = report.fields, "intake" = "submitted")), bug_report_test_answer(200, list("receipt" = list("reportId" = "accepted"))))
	report.refresh()
	TEST_ASSERT(report.result?["kind"] == "accepted" && isnull(report.status), "The receipt turned the page sent and a line from the unsent page stayed under it")
	report.result = null
	for(var/tick in 1 to 4)
		report.replies = list(bug_report_test_answer(429, list("error" = "draft_request_limit")))
		report.refresh()
	TEST_ASSERT(!report.polling_paused, "Draft reads the server turned down read as losing touch")
	// A refusal between lost polls ends their run, so the lost one after it is the first of four again
	for(var/tick in 1 to 3)
		report.refresh()
	report.replies = list(bug_report_test_answer(429, list("error" = "draft_request_limit")))
	report.refresh()
	report.refresh()
	TEST_ASSERT(!report.polling_paused, "A poll the server turned down didn't end the run of lost ones")
	for(var/tick in 1 to 3)
		report.refresh()
	TEST_ASSERT(report.polling_paused && findtext(report.status, "Lost touch"), "Four polls with no answer didn't pause polling")

/// With no bridge configured a report sends nothing, and says so
/datum/unit_test/bug_report_unconfigured

/datum/unit_test/bug_report_unconfigured/Run()
	var/datum/client_interface/bug_report/reporter = allocate(/datum/client_interface/bug_report)
	var/datum/bug_report/report = allocate(/datum/bug_report, reporter)
	reporter.bug_report_draft = report
	TEST_ASSERT(!bug_reports_enabled(), "The test server has a reporting bridge configured")
	TEST_ASSERT_NULL(report.bridge_action("read"), "An unconfigured server got a bridge reply")
	TEST_ASSERT(findtext(report.status, "aren't set up"), "The report didn't say reporting is off")
	TEST_ASSERT_EQUAL(GLOB.bug_report_requests, 0, "An unconfigured call held a request slot")

/// Crash cleanup removes only our staged files a day old, whatever else shares the folder
/datum/unit_test/bug_report_temporary_cleanup

/datum/unit_test/bug_report_temporary_cleanup/Run()
	var/old_file = "data/bug-report-temporary/bug-report-[num2text(world.realtime - 25 HOURS, 20)]-{ab-cd}.capture"
	var/recent_file = "data/bug-report-temporary/bug-report-[num2text(world.realtime, 20)]-{bc-de}.upload"
	var/undated_file = "data/bug-report-temporary/{ab-cd}.capture"
	var/other_file = "data/bug-report-temporary/keep-fixture.txt"
	for(var/path in list(old_file, recent_file, undated_file, other_file))
		text2file("fixture", path)
	bug_report_cleanup_temporary(force = TRUE)
	TEST_ASSERT(!fexists(old_file), "A day-old staged file survived")
	TEST_ASSERT(fexists(recent_file), "Another server's recent staged file went")
	TEST_ASSERT(fexists(undated_file) && fexists(other_file), "A file we can't date, or not ours, went")
	for(var/path in list(old_file, recent_file, undated_file, other_file))
		fdel(path)

/// Only whitespace counts as empty, by the same table the window tests, and each required box holds a send while it's empty
/datum/unit_test/bug_report_blank_fields

/datum/unit_test/bug_report_blank_fields/Run()
	var/list/empty = list("", " ", "\t[ascii2text(13)]\n", ascii2text(160), ascii2text(12288), ascii2text(8232), ascii2text(65279), ascii2text(133))
	for(var/text in empty)
		TEST_ASSERT(bug_report_blank(text), "[url_encode(text)] didn't count as empty")
	for(var/text in list("a", ascii2text(8203)))
		TEST_ASSERT(!bug_report_blank(text), "[url_encode(text)] counted as empty")
	TEST_ASSERT(bug_report_blank("1. \n2.\t\n 3.", numbered = TRUE), "Steps that are only their numbers counted as written")
	TEST_ASSERT(!bug_report_blank("1. Click the door", numbered = TRUE), "A written step counted as empty")
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/list/filled = list("title" = "Door", "expected" = "Open", "reproduction" = "1. Click it", "category" = "Other", "severity" = "minor")
	var/static/list/limits = list("title" = 160, "expected" = 8000, "reproduction" = 8000)
	for(var/name, limit in limits)
		for(var/text in empty + (name == "reproduction" ? list("1. \n2. ") : list()))
			var/list/blank = filled.Copy()
			blank[name] = text
			report.status = null
			TEST_ASSERT(!report.update_local_fields(blank, 0, required = TRUE), "A send with [name] as [url_encode(text)] was taken")
			TEST_ASSERT_EQUAL(report.status, "Some boxes are empty. Fill them in, then send it again.", "A send with an empty [name] didn't say why")
		var/list/saved = filled.Copy()
		saved[name] = ""
		TEST_ASSERT(report.update_local_fields(saved, 0), "Text with an empty [name] wasn't kept while writing")
		var/list/long = filled.Copy()
		long[name] = random_string(limit + 1, list("a"))
		report.status = null
		TEST_ASSERT(!report.update_local_fields(long, 0), "A [name] over the service's limit was taken")
		TEST_ASSERT_EQUAL(report.status, "Some of it is too long. Cut it down, then send it again.", "A [name] over the limit didn't say why")
		long[name] = random_string(limit, list("a"))
		TEST_ASSERT(report.update_local_fields(long, 0, required = TRUE), "A [name] right at the service's limit was refused")
	var/list/odd = filled.Copy()
	odd["category"] = "Bananas"
	odd["severity"] = 3
	TEST_ASSERT(report.update_local_fields(odd, 0), "Choices the window never offers held the text back")
	TEST_ASSERT(report.fields["category"] == "Other" && report.fields["severity"] == "unspecified", "A choice the window never offers was taken")
	var/list/steps = list()
	for(var/number in 1 to 20)
		steps += "[number]. Click it"
	odd = filled.Copy()
	odd["reproduction"] = jointext(steps, "\n")
	TEST_ASSERT(report.update_local_fields(odd, 0, required = TRUE), "Twenty steps, the most the window offers, were refused")
	odd["reproduction"] += "\n21. Click it again"
	report.status = null
	TEST_ASSERT(!report.update_local_fields(odd, 0), "A twenty-first step was taken")
	TEST_ASSERT_EQUAL(report.status, "Some of it is too long. Cut it down, then send it again.", "A twenty-first step didn't say why")

/// Starts a capture of the window, as if the last capture's wait had passed
/proc/bug_report_test_capture(datum/bug_report/test/report, datum/tgui_window/bug_report_test/window)
	COOLDOWN_RESET(report, capture_cooldown)
	report.begin_ui_capture(window.id)
	return report.capture_nonce

/// Every way a capture ends tells the reporter why in plain words, and a reason we don't know reads as a failure
/datum/unit_test/bug_report_capture_reasons

/datum/unit_test/bug_report_capture_reasons/Run()
	var/static/list/window_reasons = list(
		"cancelled" = "Capture cancelled",
		"too_big" = "That window's too big to capture. Add your own screenshot instead.",
		"empty" = "That window has nothing on screen to capture.",
		"failed" = "That window couldn't be captured. Add your own screenshot instead.",
		"timed_out" = "The capture took too long. Try again, or add your own screenshot.",
		"busy" = "That window is busy with another capture. Try again in a moment.",
		"not_allowed" = "That window can't be captured. Add your own screenshot instead.",
		"melted" = "That window couldn't be captured. Add your own screenshot instead.",
	)
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(report)
	for(var/reason, words in window_reasons)
		var/nonce = bug_report_test_capture(report, window)
		TEST_ASSERT_NOTNULL(nonce, "The capture for [reason] didn't start")
		TEST_ASSERT(report.receive_ui_capture(window, "bug-report/capture-cancel", list("nonce" = nonce, "reason" = reason)), "The window's [reason] wasn't taken")
		TEST_ASSERT_EQUAL(report.status, words, "The window's [reason] didn't say why")
		TEST_ASSERT(!report.capture_nonce && !report.busy && !report.pictures, "The window's [reason] left the capture running")
	window.on_message("bug-report/capture-cancel", list("nonce" = bug_report_test_capture(report, window)), list())
	TEST_ASSERT_EQUAL(report.status, "Capture cancelled", "A cancel without a reason didn't read as cancelled")
	window.on_message("bug-report/capture-cancel", list("nonce" = bug_report_test_capture(report, window), "reason" = 5), list())
	TEST_ASSERT_EQUAL(report.status, window_reasons["failed"], "A reason that isn't text didn't read as a failure")

	var/nonce = bug_report_test_capture(report, window)
	report.expire_unready_capture(nonce)
	TEST_ASSERT_EQUAL(report.status, "That window didn't answer. Reopen it and try again.", "A silent window didn't say so")
	nonce = bug_report_test_capture(report, window)
	report.expire_ui_capture(nonce)
	TEST_ASSERT_EQUAL(report.status, "The capture took too long. Try again, or add your own screenshot.", "An expired capture didn't say so")
	nonce = bug_report_test_capture(report, window)
	report.capture_until = world.time
	report.receive_ui_capture(window, "bug-report/capture-ready", list("nonce" = nonce))
	TEST_ASSERT_EQUAL(report.status, "The capture took too long. Try again, or add your own screenshot.", "A chunk after the capture's time didn't say it took too long")
	nonce = bug_report_test_capture(report, window)
	window.locked_by = new /datum/tgui/bug_report_test
	report.receive_ui_capture(window, "bug-report/capture-ready", list("nonce" = nonce))
	TEST_ASSERT_EQUAL(report.status, "That window closed or changed, so nothing was added.", "A window showing something else didn't say so")
	window = bug_report_test_window(report, "tgui-window-3")
	nonce = bug_report_test_capture(report, window)
	report.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = nonce, "index" = 3, "totalLength" = 4, "data" = "AAAA"))
	TEST_ASSERT_EQUAL(report.status, "The capture didn't arrive in one piece. Try again.", "A broken transfer didn't say so")
	bug_report_test_capture(report, window)
	report.cancel_ui_capture("not_saved")
	TEST_ASSERT_EQUAL(report.status, "The capture couldn't be saved. Try again.", "A capture we couldn't stage didn't say so")

	var/datum/bug_report_picture/kept = bug_report_test_picture(report, "kept", "window")
	COOLDOWN_RESET(report, capture_cooldown)
	report.begin_ui_capture(window.id, kept.id)
	TEST_ASSERT_EQUAL(kept.pending, "waiting", "A retake didn't wait on its window")
	report.cancel_ui_capture()
	TEST_ASSERT(kept.attachment_id == "kept" && kept.window_data()["state"] == "ready" && (kept in report.pictures), "A cancelled retake lost the picture it had")

/// The window picker leaves out what can't be captured, sends null with nothing to pick, and numbers only titles that repeat
/datum/unit_test/bug_report_capture_targets

/datum/unit_test/bug_report_capture_targets/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	TEST_ASSERT_NULL(report.capture_targets(), "No window to capture didn't send null")
	bug_report_test_window(report, "tgui-window-2", "Vending machine")
	bug_report_test_window(report, "tgui-window-3", "Crew monitor")
	bug_report_test_window(report, "tgui-window-4", "Vending machine")
	var/datum/tgui_window/bug_report_test/hidden = bug_report_test_window(report, "tgui-window-5", "Vending machine")
	hidden.visible = FALSE
	var/list/titles = list()
	for(var/list/target as anything in report.capture_targets())
		titles[target["id"]] = target["title"]
	TEST_ASSERT_EQUAL(length(titles), 3, "The picker didn't hold the three visible windows")
	TEST_ASSERT_EQUAL(titles["tgui-window-2"], "Vending machine", "The first of two shared titles got a number")
	TEST_ASSERT_EQUAL(titles["tgui-window-3"], "Crew monitor", "A title of its own got a number")
	TEST_ASSERT_EQUAL(titles["tgui-window-4"], "Vending machine (2)", "The second shared title didn't get (2)")

/// A report takes three pictures, each with its own sharing, and a retake swaps the image under the same card
/datum/unit_test/bug_report_pictures

/datum/unit_test/bug_report_pictures/Run()
	TEST_ASSERT(bug_report_image_name("dance.GIF"), "A GIF wasn't taken")
	TEST_ASSERT(!bug_report_image_name("notes.txt"), "A text file was taken as an image")
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/ckey = report.context["ckey"]
	for(var/index in 1 to 3)
		var/datum/bug_report_picture/picture = report.picture_for(null, "window")
		TEST_ASSERT_NOTNULL(picture, "Picture [index] of 3 was refused")
		LAZYADD(report.pictures, picture)
		report.replies = list(list("attachment" = list("id" = "capture-[index]", "state" = "ready", "publicConsent" = FALSE)))
		report.upload_picture(picture, bug_report_test_image(), "base64")
	TEST_ASSERT_EQUAL(bug_report_uses_left(ckey, "uploads"), 5, "Captures spent the reporter's own uploads")
	report.status = null
	TEST_ASSERT_NULL(report.picture_for(null, "view"), "A fourth picture was taken")
	TEST_ASSERT(findtext(report.status, "the most a report takes"), "A fourth picture didn't say why not")
	var/datum/bug_report_picture/second = report.pictures[2]
	second.preview_seen = TRUE
	report.replies = list(list("attachment" = list("id" = "capture-2", "state" = "ready", "publicConsent" = TRUE)))
	report.picture_consent(second.id, TRUE)
	var/list/wire = report.attachments_wire()
	TEST_ASSERT_EQUAL(length(wire), 3, "A submission didn't name every picture")
	TEST_ASSERT(wire[1]["id"] == "capture-1" && wire[1]["public"] == 0 && wire[2]["public"] == 1, "Each picture's sharing didn't go its own way")
	report.pictures = null
	TEST_ASSERT_EQUAL(json_encode(report.attachments_wire()), "\[]", "A submission without pictures didn't send an empty list")
	report.pictures = list(second)

	var/datum/bug_report_picture/first = report.picture_for(null, "window")
	LAZYADD(report.pictures, first)
	first.update_attachment(list("id" = "capture-1", "state" = "ready", "publicConsent" = TRUE))
	first.take = 1
	report.calls.Cut()
	report.replies = list(list("removed" = TRUE), list("attachment" = list("id" = "capture-4", "state" = "processing", "publicConsent" = FALSE)))
	report.upload_picture(first, bug_report_test_image(), "base64")
	TEST_ASSERT_EQUAL(length(report.calls), 2, "A retake didn't give back the last image and send the new one")
	TEST_ASSERT(report.calls[1]["route"] == "attachment/remove" && report.calls[1]["headers"]["x-report-attachment"] == "capture-1", "A retake didn't give back the last image first")
	TEST_ASSERT(first.attachment_id == "capture-4" && first.take == 2 && !first.public_consent && !first.preview_seen, "A retake didn't start the image over")
	TEST_ASSERT_EQUAL(report.pictures[2], first, "A retake moved or replaced the picture's card")

	report.replies = list(list("draft" = list("revision" = 1, "fields" = report.fields, "intake" = "draft", "attachments" = list(
		list("id" = "capture-4", "state" = "ready", "publicConsent" = FALSE),
		list("id" = "lost", "state" = "ready", "publicConsent" = FALSE),
	))))
	var/datum/bug_report_picture/unconfirmed = report.picture_for(null, "file")
	LAZYADD(report.pictures, unconfirmed)
	unconfirmed.reason = "unconfirmed"
	report.read_draft()
	TEST_ASSERT_EQUAL(first.window_data()["state"], "ready", "The service's check didn't reach the picture")
	TEST_ASSERT_EQUAL(unconfirmed.attachment_id, "lost", "An image we never heard back about didn't go to the unconfirmed picture")
	TEST_ASSERT_EQUAL(second.reason, "unconfirmed", "A picture whose image the service lost didn't say so")

	report.replies = list(list("removed" = TRUE))
	report.remove_picture(first.id)
	TEST_ASSERT(!(first in report.pictures) && report.status == "Picture removed", "Removing a picture didn't")
	report.replies = null
	report.remove_picture(unconfirmed.id)
	TEST_ASSERT((unconfirmed in report.pictures) && findtext(report.status, "still attached"), "A removal the bridge didn't confirm dropped the picture")

	var/datum/tgui/bug_report_test/ui = allocate(/datum/tgui/bug_report_test)
	LAZYADD(report.open_uis, ui)
	report.replies = list(list("revisionConflict" = TRUE), TRUE)
	report.load_preview(unconfirmed)
	var/list/preview = ui.updates[length(ui.updates)]["preview"]
	TEST_ASSERT(preview && isnull(preview["src"]), "A preview the bridge answered with a conflict was shown")
	report.load_preview(unconfirmed)
	preview = ui.updates[length(ui.updates)]["preview"]
	TEST_ASSERT(findtext(preview?["src"], "data:image/png;base64,") == 1, "A saved preview wasn't shown")
	report.status = "Picture added"
	report.replies = list(bug_report_test_answer(404, list("error" = "attachment_not_found")))
	report.load_preview(unconfirmed)
	preview = ui.updates[length(ui.updates)]["preview"]
	TEST_ASSERT(preview && isnull(preview["src"]) && report.status == "Picture added", "A preview the service turned down took the status line from its card")
	LAZYREMOVE(report.open_uis, ui)

/// The in-game capture waits between captures, holds to two across the server, says when there's nothing to see, and renders the view it sees
/datum/unit_test/bug_report_view

/datum/unit_test/bug_report_view/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	report.begin_view_capture()
	TEST_ASSERT_EQUAL(LAZYLEN(report.pictures), 1, "An in-game capture with nothing in view left no card")
	var/datum/bug_report_picture/picture = report.pictures[1]
	TEST_ASSERT(picture.reason == "nothing" && picture.window_data()["state"] == "failed", "Nothing in view didn't say so")
	TEST_ASSERT(!report.busy && !length(report.calls), "Nothing in view left the report busy or uploaded something")
	TEST_ASSERT_EQUAL(bug_report_uses_left(report.context["ckey"], "captures"), 29, "A render didn't spend its capture when it started")
	report.begin_view_capture(picture.id)
	TEST_ASSERT_EQUAL(report.status, "Give it a few seconds before the next capture.", "A second capture inside the wait didn't say to wait")
	COOLDOWN_RESET(report, view_cooldown)
	GLOB.bug_report_renders = 2
	report.begin_view_capture(picture.id)
	GLOB.bug_report_renders = 0
	TEST_ASSERT_EQUAL(report.status, "Lots of captures are running right now. Try again in a moment.", "A third render at once across the server didn't say to wait")
	TEST_ASSERT_EQUAL(picture.reason, "nothing", "A refused capture changed the picture")

	var/datum/bug_report/test/viewer = bug_report_test_report(src)
	var/datum/client_interface/bug_report/reporter = viewer.owner
	reporter.eye = run_loc_floor_bottom_left
	reporter.view = "5x5"
	viewer.replies = list(list("attachment" = list("id" = "view", "state" = "processing", "publicConsent" = FALSE)))
	viewer.begin_view_capture()
	TEST_ASSERT_EQUAL(length(viewer.calls), 1, "The in-game capture wasn't uploaded once")
	var/list/upload = viewer.calls[1]
	TEST_ASSERT(upload["file_existed"] && upload["headers"]["x-report-source"] == "view" && upload["headers"]["x-report-encoding"] == "", "The in-game capture didn't go up as a view's image")
	TEST_ASSERT_EQUAL(GLOB.bug_report_renders, 0, "A finished render kept its slot")
	var/datum/bug_report_picture/rendered = viewer.pictures[1]
	TEST_ASSERT(rendered.attachment_id == "view" && rendered.take == 1 && !viewer.busy, "The in-game capture's image wasn't taken")

	var/datum/bug_report/test/capturer = bug_report_test_report(src)
	for(var/capture in 1 to 30)
		bug_report_budget(capturer.context["ckey"], "captures")
	capturer.begin_view_capture()
	TEST_ASSERT(findtext(capturer.status, "30 captures this hour") && !capturer.pictures, "An in-game capture past the service's hourly cap went ahead")

/// The service's waits reach the window counted from now, and a submission it refuses for its pictures stops and catches up
/datum/unit_test/bug_report_service_answers

/datum/unit_test/bug_report_service_answers/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	bug_report_test_picture(report, "kept")
	report.submission_key = "key"
	report.result = list("kind" = "checking")
	report.replies = list(list("revisionConflict" = TRUE), list("draft" = list("revision" = 0, "fields" = report.fields, "intake" = "draft", "attachments" = list(
		list("id" = "kept", "state" = "ready", "publicConsent" = FALSE),
		list("id" = "stray", "state" = "ready", "publicConsent" = FALSE),
	))), list("removed" = TRUE))
	report.check_submission()
	TEST_ASSERT(!report.result && !report.submission_key, "A submission the service refused for its pictures kept checking")
	TEST_ASSERT_EQUAL(length(report.calls), 3, "The refused submission didn't catch up with the draft's pictures")
	TEST_ASSERT_EQUAL(report.calls[1]["body"]["attachments"][1]["id"], "kept", "The submission didn't name its pictures")
	TEST_ASSERT(report.calls[3]["route"] == "attachment/remove" && report.calls[3]["headers"]["x-report-attachment"] == "stray", "An image no picture claims stayed on the draft")
	TEST_ASSERT(findtext(report.status, "send it again"), "The refused submission didn't say to send it again")

	report.submission_key = "key"
	report.result = list("kind" = "checking")
	report.replies = list(list("result" = list("kind" = "limited", "reason" = "live_attempts", "retryAt" = 1729700000123, "retryIn" = 120000)))
	report.check_submission()
	var/list/limit = report.limit_data()
	TEST_ASSERT(limit?["kind"] == "sends" && limit["retryIn"] > 110000 && limit["retryIn"] <= 120000, "The service's limit didn't reach the window as a wait")
	TEST_ASSERT(!("retryAt" in report.result_data()), "The window was sent the service's Unix ms time")

	report.submission_key = "key"
	report.result = list("kind" = "checking")
	report.replies = list(list("result" = list("kind" = "accepted", "receipt" = list("publication" = "retryable", "nextAttemptAt" = 1729700000123, "nextAttemptIn" = 60000))))
	report.check_submission()
	// Ten seconds pass
	report.receipt_arrival -= 100
	var/wait = report.result_data()["receipt"]["nextAttemptIn"]
	TEST_ASSERT(wait > 49000 && wait <= 50000, "The receipt's wait wasn't counted from now")
	TEST_ASSERT_EQUAL(report.result["receipt"]["nextAttemptIn"], 60000, "Counting the wait from now changed the receipt we hold")
	TEST_ASSERT(!("nextAttemptAt" in report.result_data()["receipt"]), "The window was sent the receipt's Unix ms time")

	var/datum/bug_report/test/capturer = bug_report_test_report(src)
	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(capturer)
	for(var/capture in 1 to 30)
		bug_report_budget(capturer.context["ckey"], "captures")
	capturer.begin_ui_capture(window.id)
	TEST_ASSERT(findtext(capturer.status, "30 captures this hour") && !capturer.capture_nonce && !capturer.pictures, "A capture past the service's hourly cap went ahead")

	for(var/list/body as anything in list(list("error" = "draft_request_limit"), null))
		report.fields_dirty = TRUE
		report.replies = list(bug_report_test_answer(429, body))
		report.save_fields()
		TEST_ASSERT_EQUAL(report.status, "The report server is busy. Your text is kept. Try again in a few minutes.", "A 429 naming no limit of ours didn't say to try again in a few minutes")

/// The window's acts keep their own checks - a send needs every box, removing a picture ends its capture, sharing waits for this image's preview, and acts that reach the bridge wait between goes
/datum/unit_test/bug_report_acts

/datum/unit_test/bug_report_acts/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/datum/tgui/bug_report_test/ui = allocate(/datum/tgui/bug_report_test)
	ui.status = UI_INTERACTIVE
	var/datum/bug_report_test_sender/sender = new
	sender.client = report.owner
	var/old_usr = usr
	usr = sender
	var/list/filled = list("title" = "Door", "expected" = "Open", "reproduction" = "1. Click it", "category" = "Other", "severity" = "minor")
	var/list/empty = list("title" = " ", "expected" = "\t\n", "reproduction" = "1. ")
	for(var/name, text in empty)
		var/list/blank = filled.Copy()
		blank[name] = text
		report.status = null
		report.ui_act("submit", list("fields" = blank, "fieldsEpoch" = 0), ui)
		TEST_ASSERT_EQUAL(report.status, "Some boxes are empty. Fill them in, then send it again.", "A send with an empty [name] didn't say why")
	TEST_ASSERT_EQUAL(length(report.calls), 0, "A send with an empty box reached the bridge")
	report.ui_act("submit", list("fields" = filled, "fieldsEpoch" = 0), ui)
	TEST_ASSERT_EQUAL(length(report.calls), 1, "A send with every box filled didn't reach the bridge")
	report.ui_act("submit", list("fields" = filled, "fieldsEpoch" = 0), ui)
	TEST_ASSERT_EQUAL(length(report.calls), 1, "A second send inside a second reached the bridge")
	report.ui_act("refresh", null, ui)
	report.ui_act("refresh", null, ui)
	TEST_ASSERT_EQUAL(length(report.calls), 2, "A second refresh inside five seconds reached the bridge")

	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(report)
	report.fields_dirty = FALSE
	COOLDOWN_RESET(report, action_cooldown)
	report.ui_act("capture_ui", list("fields" = filled, "fieldsEpoch" = 0, "windowId" = window.id), ui)
	TEST_ASSERT(report.busy && report.capture_picture, "The window capture didn't start")
	report.ui_act("remove_screenshot", list("pictureId" = report.capture_picture.id), ui)
	TEST_ASSERT(!report.busy && !report.capture_nonce && !report.pictures, "Removing the picture a capture waits on didn't end the capture")

	var/datum/bug_report_picture/picture = bug_report_test_picture(report)
	picture.take = 2
	report.ui_act("preview_loaded", list("pictureId" = picture.id, "take" = 1), ui)
	COOLDOWN_RESET(report, action_cooldown)
	report.ui_act("screenshot_consent", list("pictureId" = picture.id, "publicConsent" = TRUE), ui)
	TEST_ASSERT(!picture.preview_seen && length(report.calls) == 2, "The last image's preview let this one go public")
	report.ui_act("preview_loaded", list("pictureId" = picture.id, "take" = 2), ui)
	COOLDOWN_RESET(report, action_cooldown)
	report.replies = list(list("attachment" = list("id" = "image", "state" = "ready", "publicConsent" = TRUE)))
	report.ui_act("screenshot_consent", list("pictureId" = picture.id, "publicConsent" = TRUE), ui)
	TEST_ASSERT(picture.preview_seen && picture.public_consent, "Sharing an image whose preview was shown didn't go out")
	// The window sends it again once we aren't busy, which changes nothing
	var/made = length(report.calls)
	report.ui_act("preview_loaded", list("pictureId" = picture.id, "take" = 2), ui)
	TEST_ASSERT(picture.preview_seen && picture.public_consent && length(report.calls) == made, "A second preview_loaded for the same image changed something")

	// Try again moves its marker in the update with the status its read found, and one we drop moves it too
	LAZYADD(report.open_uis, ui)
	COOLDOWN_RESET(report, refresh_cooldown)
	report.answered = 0
	report.replies = list(bug_report_test_answer(410, list("error" = "draft_expired")))
	report.ui_act("refresh", null, ui)
	var/list/answer = ui.updates[length(ui.updates)]
	TEST_ASSERT(answer["refreshAnswered"] == 1 && answer["status"] == "The report server turned that down. Your text is kept.", "Try again's answer didn't come with the status its read found")
	report.ui_act("refresh", null, ui)
	TEST_ASSERT_EQUAL(report.answered, 2, "A Try again inside five seconds got no answer")
	COOLDOWN_RESET(report, refresh_cooldown)
	report.busy = TRUE
	report.ui_act("refresh", null, ui)
	report.busy = FALSE
	TEST_ASSERT_EQUAL(report.answered, 3, "A Try again while busy got no answer")
	report.refresh()
	TEST_ASSERT_EQUAL(report.answered, 3, "A background poll answered a Try again")
	LAZYREMOVE(report.open_uis, ui)
	usr = old_usr

/// Something opaque on the floor, for the sight test
/obj/bug_report_test_blocker
	name = "test blocker"
	opacity = TRUE
	density = TRUE
	anchored = TRUE

/// A living reporter's in-game capture leaves out what's behind something opaque, and a ghost's keeps it
/datum/unit_test/bug_report_sight

/datum/unit_test/bug_report_sight/Run()
	var/turf/center = run_loc_floor_bottom_left
	var/turf/blocked = locate(center.x + 1, center.y, center.z)
	var/turf/behind = locate(center.x + 2, center.y, center.z)
	TEST_ASSERT(behind.x <= run_loc_floor_top_right.x, "The test room is too narrow for the sight test")
	allocate(/obj/bug_report_test_blocker, blocked)
	var/obj/item/camera/bug_report/camera = new
	var/list/living = camera.seen_turfs(center, 5, 5, FALSE, FALSE)
	var/list/ghost = camera.seen_turfs(center, 5, 5, TRUE, FALSE)
	qdel(camera)
	TEST_ASSERT((blocked in living) && !(behind in living), "A living reporter's capture took what's behind something opaque")
	TEST_ASSERT((behind in ghost) && length(ghost) == 25, "A ghost's capture left out some of its view")

/// The report server turning a request down says what it was, never that the server was out of reach, and its hourly limits fill ours
/datum/unit_test/bug_report_refusals

/datum/unit_test/bug_report_refusals/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/datum/bug_report_picture/own = report.picture_for(null, "file")
	LAZYADD(report.pictures, own)
	report.replies = list(bug_report_test_answer(429, list("error" = "upload_request_limit")))
	report.upload_picture(own, bug_report_test_image())
	TEST_ASSERT_EQUAL(report.status, "You've reached this hour's limit on your own screenshots. Captures still work.", "The service's upload limit didn't say so")
	TEST_ASSERT(!report.unreachable && !report.pictures, "The service's upload limit read as no answer, or kept the picture it turned down")
	TEST_ASSERT_EQUAL(report.ui_data()["uploadsLeft"], 0, "The service's upload limit didn't reach the window")
	var/datum/bug_report_picture/capture = report.picture_for(null, "view")
	LAZYADD(report.pictures, capture)
	report.replies = list(bug_report_test_answer(429, list("error" = "capture_request_limit")))
	report.upload_picture(capture, bug_report_test_image())
	TEST_ASSERT_EQUAL(report.status, "You've reached this hour's limit on captures. Add your own screenshot instead.", "The service's capture limit didn't say so")
	TEST_ASSERT_EQUAL(bug_report_uses_left(report.context["ckey"], "captures"), 0, "The service's capture limit didn't fill ours")

	var/datum/bug_report/test/crowded = bug_report_test_report(src)
	var/datum/bug_report_picture/third = crowded.picture_for(null, "window")
	LAZYADD(crowded.pictures, third)
	crowded.replies = list(bug_report_test_answer(409, list("error" = "too_many_attachments")))
	crowded.upload_picture(third, bug_report_test_image(), "base64")
	TEST_ASSERT(crowded.status == "The report server already has 3 pictures for this report. Remove one to add another." && !crowded.pictures, "A picture the service had no room for didn't say so")
	crowded.fields_dirty = TRUE
	crowded.replies = list(bug_report_test_answer(410, list("error" = "draft_expired")))
	TEST_ASSERT(!crowded.save_fields(), "A save the service turned down claimed success")
	TEST_ASSERT(crowded.status == "The report server turned that down. Your text is kept." && !crowded.unreachable, "A save the service turned down read as no answer")
	crowded.submission_key = "key"
	crowded.result = list("kind" = "checking")
	crowded.replies = list(bug_report_test_answer(400, list("error" = "invalid_attachments")))
	crowded.check_submission()
	TEST_ASSERT(!crowded.result && !crowded.submission_key && !crowded.polling_paused, "A check the service turned down kept checking")
	crowded.replies = list(bug_report_test_answer(409, list("error" = "revision_conflict")), list("draft" = list("revision" = 2, "fields" = crowded.fields, "intake" = "draft")))
	crowded.save_fields()
	TEST_ASSERT_EQUAL(crowded.remote_draft?["revision"], 2, "A conflict stopped meaning the draft moved on")
	crowded.remote_draft = null
	crowded.replies = list(bug_report_test_answer(503, list("error" = "service_unavailable")))
	crowded.save_fields()
	TEST_ASSERT(crowded.unreachable && crowded.status == "Couldn't reach the report server. Your text is kept. Try again in a minute.", "A 5xx didn't read as out of reach")
	crowded.unreachable = FALSE
	var/datum/http_response/answer = new
	answer.errored = TRUE
	crowded.replies = list(answer)
	crowded.save_fields()
	TEST_ASSERT(crowded.unreachable, "No answer didn't read as out of reach")

	var/datum/tgui/bug_report_test/ui = allocate(/datum/tgui/bug_report_test)
	ui.status = UI_INTERACTIVE
	var/datum/bug_report_test_sender/sender = new
	sender.client = crowded.owner
	var/old_usr = usr
	usr = sender
	var/datum/bug_report_picture/kept = bug_report_test_picture(crowded, "kept")
	crowded.replies = list(bug_report_test_answer(404, list("error" = "attachment_not_found")))
	crowded.ui_act("remove_screenshot", list("pictureId" = kept.id), ui)
	usr = old_usr
	TEST_ASSERT((kept in crowded.pictures) && crowded.status == "The report server turned that down. Your text is kept.", "A removal the service turned down didn't keep the picture and say why")

/// One reporter renders one in-game capture at a time and waits between them, however many reports they switch between
/datum/unit_test/bug_report_render_per_player

/datum/unit_test/bug_report_render_per_player/Run()
	var/datum/bug_report/test/first = bug_report_test_report(src)
	var/datum/client_interface/bug_report/reporter = first.owner
	reporter.eye = run_loc_floor_bottom_left
	reporter.view = "5x5"
	var/datum/bug_report/test/second = allocate(/datum/bug_report/test, reporter)
	second.context_saved = TRUE
	LAZYADD(reporter.bug_report_history, second)
	// The render waits a tick before its PNG, and the reporter switches reports then
	INVOKE_ASYNC(first, TYPE_PROC_REF(/datum/bug_report, begin_view_capture))
	TEST_ASSERT(first.rendering, "The render finished without waiting a tick")
	reporter.bug_report_draft = second
	// Only the render running holds the second report, not the wait the first one started
	var/wait_time = first.view_cooldown
	COOLDOWN_RESET(first, view_cooldown)
	second.begin_view_capture()
	first.view_cooldown = wait_time
	TEST_ASSERT(second.status == "Give it a few seconds before the next capture." && !second.pictures && !length(second.calls), "A reporter rendered in two reports at once")
	for(var/tick in 1 to 100)
		if(!first.busy)
			break
		stoplag()
	TEST_ASSERT(!first.busy && !first.rendering && !length(first.calls), "A render dropped on the way kept rendering or uploaded")
	TEST_ASSERT_EQUAL(bug_report_uses_left(first.context["ckey"], "captures"), 29, "A render dropped on the way didn't spend its capture")
	second.begin_view_capture()
	TEST_ASSERT_EQUAL(second.status, "Give it a few seconds before the next capture.", "The wait between captures belonged to one report")

/// A render that breaks part way gives back its slot and the reporter's, and leaves nothing waiting on it
/datum/unit_test/bug_report_render_breaks

/datum/unit_test/bug_report_render_breaks/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/datum/client_interface/bug_report/reporter = report.owner
	reporter.eye = run_loc_floor_bottom_left
	// A view with no size, which reading it can't take
	reporter.view = ""
	var/thrown = FALSE
	try
		report.begin_view_capture()
	catch
		thrown = TRUE
	var/renders = GLOB.bug_report_renders
	GLOB.bug_report_renders = 0
	TEST_ASSERT(thrown, "A view that can't be read didn't break the render")
	TEST_ASSERT(!report.busy && !report.rendering && !renders, "A broken render left the report, the reporter or the server rendering")
	var/datum/bug_report_picture/picture = LAZYACCESS(report.pictures, 1)
	TEST_ASSERT(picture?.reason == "render" && picture.window_data()["state"] == "failed", "A broken render didn't say it didn't work")

	// Breaking before it looks at the view, as the window's update can, gives everything back too
	var/datum/bug_report/test/second = bug_report_test_report(src)
	second.owner.eye = run_loc_floor_bottom_left
	second.owner.view = "5x5"
	var/datum/tgui/bug_report_test/broken/ui = allocate(/datum/tgui/bug_report_test/broken)
	LAZYADD(second.open_uis, ui)
	thrown = FALSE
	try
		second.begin_view_capture()
	catch
		thrown = TRUE
	renders = GLOB.bug_report_renders
	GLOB.bug_report_renders = 0
	LAZYREMOVE(second.open_uis, ui)
	TEST_ASSERT(thrown && !second.busy && !second.rendering && !renders, "Breaking once the render started left the report or the server rendering")

/// A retake gives back the image a lost upload reply left with the service before sending its own, so the report never holds one too many
/datum/unit_test/bug_report_retake_unclaimed

/datum/unit_test/bug_report_retake_unclaimed/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	bug_report_test_picture(report, "first", "window")
	bug_report_test_picture(report, "second", "window")
	var/datum/bug_report_picture/lost = report.picture_for(null, "window")
	LAZYADD(report.pictures, lost)
	// The service took it, but its reply never came back
	report.upload_picture(lost, bug_report_test_image(), "base64")
	TEST_ASSERT_EQUAL(lost.reason, "unconfirmed", "An upload without a reply wasn't unconfirmed")
	report.calls.Cut()
	report.replies = list(
		list("draft" = list("revision" = 0, "fields" = report.fields, "intake" = "draft", "attachments" = list(
			list("id" = "first", "state" = "ready", "publicConsent" = FALSE),
			list("id" = "second", "state" = "ready", "publicConsent" = FALSE),
			list("id" = "orphan", "state" = "ready", "publicConsent" = FALSE),
		))),
		list("removed" = TRUE),
		list("attachment" = list("id" = "retaken", "state" = "processing", "publicConsent" = FALSE)),
	)
	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(report)
	report.begin_ui_capture(window.id, lost.id)
	report.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = report.capture_nonce, "index" = 0, "totalLength" = 4, "data" = "AAAA"))
	TEST_ASSERT_EQUAL(length(report.calls), 3, "A retake didn't read the draft, give back what it left and send its own")
	TEST_ASSERT(report.calls[2]["route"] == "attachment/remove" && report.calls[2]["headers"]["x-report-attachment"] == "orphan", "A retake didn't give back the image a lost reply left")
	TEST_ASSERT(lost.attachment_id == "retaken" && lost.take == 2 && !lost.reason, "The retake's image wasn't taken")

	// Removing a picture whose upload went unconfirmed and whose retake then broke gives back the image too
	var/datum/bug_report/test/second = bug_report_test_report(src)
	var/datum/bug_report_picture/picture = second.picture_for(null, "view")
	LAZYADD(second.pictures, picture)
	picture.take = 1
	picture.reason = "render"
	second.replies = list(list("draft" = list("revision" = 0, "fields" = second.fields, "intake" = "draft", "attachments" = list(
		list("id" = "orphan", "state" = "ready", "publicConsent" = FALSE),
	))), list("removed" = TRUE))
	var/datum/tgui/bug_report_test/ui = allocate(/datum/tgui/bug_report_test)
	ui.status = UI_INTERACTIVE
	var/datum/bug_report_test_sender/sender = new
	sender.client = second.owner
	var/old_usr = usr
	usr = sender
	second.ui_act("remove_screenshot", list("pictureId" = picture.id), ui)
	usr = old_usr
	TEST_ASSERT(!second.pictures && length(second.calls) == 2 && second.calls[2]["headers"]["x-report-attachment"] == "orphan", "Removing a picture whose upload went unconfirmed left its image with the service")

/// A say box with no client or window, since alter_entry() reads only the payload and its phrases
/datum/tgui_say/bug_report_test

/datum/tgui_say/bug_report_test/New()
	return

/// A hurt player's forced say is cut by letter, so it comes out the same length in any alphabet
/datum/unit_test/tgui_say_cut_by_letter

/datum/unit_test/tgui_say_cut_by_letter/Run()
	var/datum/tgui_say/bug_report_test/say = new
	var/list/cases = list(
		list("letter" = 1076, "count" = 25, "low" = 24, "high" = 24),
		list("letter" = 1076, "count" = 30, "low" = 29, "high" = 29),
		list("letter" = 100, "count" = 30, "low" = 29, "high" = 29),
		list("letter" = 1076, "count" = 60, "low" = 39, "high" = 49),
	)
	for(var/list/test_case as anything in cases)
		var/entry = ""
		for(var/letter in 1 to test_case["count"])
			entry += ascii2text(test_case["letter"])
		var/said = say.alter_entry(list("entry" = entry, "channel" = SAY_CHANNEL))
		var/kept = length_char(copytext(said, 1, findtext(said, "-")))
		TEST_ASSERT(kept >= test_case["low"] && kept <= test_case["high"], "[test_case["count"]] of letter [test_case["letter"]] kept [kept], not [test_case["low"]] to [test_case["high"]]")
