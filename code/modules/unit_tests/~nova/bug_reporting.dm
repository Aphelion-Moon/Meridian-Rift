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
	if(!length(replies))
		return null
	. = replies[1]
	replies.Cut(1, 2)

/// An open report window with nobody behind it, keeping what it was sent
/datum/tgui/bug_report_test
	var/list/updates = list()

/datum/tgui/bug_report_test/New()
	return

/datum/tgui/bug_report_test/send_update(custom_data, force)
	updates += list(custom_data)

/datum/tgui/bug_report_test/close(can_be_suspended = TRUE)
	return

/// A TGUI window with nobody behind it, keeping what it was sent
/datum/tgui_window/bug_report_test
	var/list/messages = list()

/datum/tgui_window/bug_report_test/New(client, id)
	src.client = client
	src.id = id
	status = TGUI_WINDOW_READY
	visible = TRUE

/datum/tgui_window/bug_report_test/send_message(type, list/payload, force)
	messages += list(list("type" = type, "payload" = payload))

/datum/tgui_window/bug_report_test/close(can_be_suspended = TRUE, logout = FALSE)
	return

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

	report.submission_key = "key"
	report.result = list("kind" = "checking")
	report.replies = list(list("result" = list("kind" = "accepted", "receipt" = list("publication" = "retryable", "nextAttemptAt" = 1729700000123, "nextAttemptIn" = 60000))))
	report.check_submission()
	// Ten seconds pass
	report.retry_until -= 100
	var/wait = report.result_data()["receipt"]["nextAttemptIn"]
	TEST_ASSERT(wait > 49000 && wait <= 50000, "The receipt's wait wasn't counted from now")
	TEST_ASSERT_EQUAL(report.result["receipt"]["nextAttemptIn"], 60000, "Counting the wait from now changed the receipt we hold")

	var/datum/bug_report/test/capturer = bug_report_test_report(src)
	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(capturer)
	for(var/capture in 1 to 30)
		bug_report_budget(capturer.context["ckey"], "captures")
	capturer.begin_ui_capture(window.id)
	TEST_ASSERT(findtext(capturer.status, "30 captures this hour") && !capturer.capture_nonce && !capturer.pictures, "A capture past the service's hourly cap went ahead")
