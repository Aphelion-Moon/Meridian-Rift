/// A mock connection that can own bug reports
/datum/client_interface/bug_report
	var/datum/bug_report/bug_report_draft
	var/list/bug_report_history
	var/bug_report_session_id
	var/list/tgui_windows = list()

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

/// Makes a report owned by a fresh mock connection, its context already with the bridge
/proc/bug_report_test_report(datum/unit_test/test)
	var/datum/client_interface/bug_report/reporter = test.allocate(/datum/client_interface/bug_report)
	var/datum/bug_report/test/report = test.allocate(/datum/bug_report/test, reporter)
	reporter.bug_report_draft = report
	report.context_saved = TRUE
	return report

/// Gives the report another of its owner's TGUI windows to capture, showing some other UI
/proc/bug_report_test_window(datum/bug_report/test/report, id = "tgui-window-2")
	var/datum/tgui_window/bug_report_test/window = new(report.owner, id)
	var/datum/tgui/bug_report_test/ui = new
	ui.interface = "Vending"
	window.locked = TRUE
	window.locked_by = ui
	report.owner.tgui_windows[id] = window
	return window

/// Every guard on a screenshot action holds, which DM's loose `in` once let through
/datum/unit_test/bug_report_guards

/datum/unit_test/bug_report_guards/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/datum/tgui_window/bug_report_test/window = bug_report_test_window(report)
	report.attachment = list("id" = "image", "state" = "ready", "publicConsent" = FALSE)
	report.preview_id = "image"
	report.busy = TRUE
	report.begin_ui_capture(window.id)
	report.choose_screenshot()
	report.remove_screenshot("image")
	report.screenshot_consent("image", TRUE)
	TEST_ASSERT_EQUAL(length(report.calls), 0, "A busy report started a bridge call")
	TEST_ASSERT_NULL(report.capture_nonce, "A busy report started a capture")
	report.busy = FALSE
	report.screenshot_consent("image", TRUE)
	TEST_ASSERT_EQUAL(length(report.calls), 0, "Public consent went out before the reporter saw the preview")
	report.preview_confirmed = TRUE
	report.screenshot_consent("other", TRUE)
	report.remove_screenshot("other")
	TEST_ASSERT_EQUAL(length(report.calls), 0, "A stale attachment id reached the bridge")
	report.replies = list(list("attachment" = list("id" = "image", "state" = "ready", "publicConsent" = TRUE)))
	report.screenshot_consent("image", TRUE)
	TEST_ASSERT_EQUAL(length(report.calls), 1, "Consent on a confirmed preview made no call")
	var/list/consent = report.calls[1]
	TEST_ASSERT_EQUAL(consent["headers"]["x-public-consent"], "true", "Consent sent the wrong answer")
	TEST_ASSERT_EQUAL(report.attachment["publicConsent"], TRUE, "The consent reply wasn't taken")
	report.begin_ui_capture(window.id)
	TEST_ASSERT_NOTNULL(report.capture_nonce, "A capture of an owned window didn't start")
	window.on_message("close", null, list())
	TEST_ASSERT_NULL(report.capture_nonce, "Closing the captured window left its capture running")
	TEST_ASSERT(!report.busy, "Closing the captured window left the report busy")

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
	report.replies = list(list("attachment" = list("id" = "capture", "state" = "processing", "publicConsent" = FALSE)))
	TEST_ASSERT(report.receive_ui_capture(window, "bug-report/capture-chunk", list("nonce" = nonce, "index" = 1, "totalLength" = total, "data" = "AA==")), "The last chunk was refused")
	UNTIL(!report.busy)
	TEST_ASSERT_EQUAL(length(report.calls), 1, "The finished capture wasn't uploaded once")
	var/list/upload = report.calls[1]
	TEST_ASSERT_EQUAL(upload["headers"]["x-report-encoding"], "base64", "The capture went up without its encoding")
	TEST_ASSERT(upload["file_existed"], "The staged capture was gone before its upload")
	TEST_ASSERT(!fexists(path), "The staged capture outlived its upload")
	TEST_ASSERT_EQUAL(report.attachment?["id"], "capture", "The upload's attachment wasn't taken")

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

/// The hourly allowances mirror the reporting service's caps, and the service never sees a refused one
/datum/unit_test/bug_report_budgets

/datum/unit_test/bug_report_budgets/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/ckey = report.context["ckey"]
	for(var/accepted in 1 to 5)
		bug_report_budget(ckey, "accepted")
	report.fields = list("title" = "Door", "observed" = "Closed", "expected" = "Open", "reproduction" = "Click it", "category" = "Other", "severity" = "minor", "incidentAt" = null)
	report.submit_fields()
	TEST_ASSERT_EQUAL(length(report.calls), 0, "A sixth report in the hour reached the service")
	TEST_ASSERT(findtext(report.status, "accepted this hour"), "The refusal didn't say why")
	var/list/uses = GLOB.bug_report_budgets["[ckey]:accepted"]
	uses[1] = world.time - 1 HOURS
	TEST_ASSERT_EQUAL(bug_report_budget(ckey, "accepted", spend = FALSE), 0, "An hour-old acceptance still counted")
	for(var/upload in 1 to 10)
		TEST_ASSERT_EQUAL(bug_report_budget(ckey, "uploads"), 0, "Upload [upload] of 10 was refused")
	TEST_ASSERT(bug_report_budget(ckey, "uploads") > 0, "An eleventh upload in the hour was allowed")
	var/path = bug_report_temporary_path("upload")
	text2file("image", path)
	report.upload_staged_screenshot(path)
	TEST_ASSERT_EQUAL(length(report.calls), 0, "An upload past the allowance reached the bridge")
	TEST_ASSERT(!fexists(path), "A refused upload kept its staged file")

/// Typed text stays local until an action, a stale page can't overwrite newer text, and an accepted report is fixed
/datum/unit_test/bug_report_fields

/datum/unit_test/bug_report_fields/Run()
	var/datum/bug_report/test/report = bug_report_test_report(src)
	var/list/fields = list("title" = "Door", "observed" = "Closed", "expected" = "Open", "reproduction" = "Click it", "category" = "Other", "severity" = "minor", "incidentAt" = "2026-10-22T12:34:56.789Z")
	TEST_ASSERT(report.update_local_fields(fields, 0), "Valid fields were refused")
	TEST_ASSERT(report.fields_dirty, "New text wasn't marked unsaved")
	TEST_ASSERT_EQUAL(report.fields["incidentAt"], "2026-10-22T12:34:56.789Z", "The incident time didn't cross as exact text")
	TEST_ASSERT(!report.update_local_fields(fields, -1), "A stale page's text was taken")
	var/list/long = fields.Copy()
	long["observed"] = random_string(8001, list("a"))
	TEST_ASSERT(!report.update_local_fields(long, 0), "Text over the service's limit was taken")
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
	TEST_ASSERT(findtext(report.status, "isn't set up"), "The report didn't say reporting is off")
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
