/// The only bridge we ever talk to. A test build defines its own fixture origin before this file
#ifndef BUG_REPORT_BRIDGE_ORIGIN
#define BUG_REPORT_BRIDGE_ORIGIN "http://127.0.0.1:18764"
#endif
/// Longest title the reporting service takes
#define BUG_REPORT_TITLE_MAX 160
/// Longest observed, expected or reproduction text the reporting service takes
#define BUG_REPORT_TEXT_MAX 8000
/// Earlier reports a connection keeps for Recent bug reports
#define BUG_REPORT_HISTORY 20
/// Bridge requests in flight across the whole server, so no crowd of reporters can pile up rust-g jobs
#define BUG_REPORT_MAX_REQUESTS 8
/// First wait between background polls of a report, growing while nothing changes
#define BUG_REPORT_POLL_MIN (2 SECONDS)
/// Longest wait between background polls of a report
#define BUG_REPORT_POLL_MAX (1 MINUTES)
/// Accepted reports per ckey per hour, the reporting service's own cap
#define BUG_REPORT_ACCEPTED_PER_HOUR 5
/// Submissions with new text per ckey per hour, the service's cap on live checks
#define BUG_REPORT_SUBMITS_PER_HOUR 10
/// New reports per ckey per hour, kept under the service's 30 so it never refuses to register one
#define BUG_REPORT_DRAFTS_PER_HOUR 20
/// Screenshot uploads per ckey per hour, the service's own cap
#define BUG_REPORT_UPLOADS_PER_HOUR 10

/// Tells the bridge which server run a report came from
GLOBAL_VAR_INIT(bug_report_boot_id, GUID())
/// Bridge requests in flight across the server, held under BUG_REPORT_MAX_REQUESTS
GLOBAL_VAR_INIT(bug_report_requests, 0)
/// Hourly allowance uses - "ckey:kind" to the world.time of each use in the last hour
GLOBAL_LIST_EMPTY(bug_report_budgets)

/client
	/// The report this connection is writing, or the last one it sent
	var/datum/bug_report/bug_report_draft
	/// This connection's reports, oldest first, so a receipt can be reopened
	var/list/bug_report_history
	/// Shared by every report from this connection, and checked by the bridge on every call
	var/bug_report_session_id

/datum/config_entry/string/bug_report_bridge_url
	default = ""

/datum/config_entry/string/bug_report_bridge_token
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/string/bug_report_server_id
	default = "meridian-rift-main"

/// Whether reports go to the reporting bridge, which only ever means the one on this machine
/proc/bug_reports_enabled()
	return CONFIG_GET(string/bug_report_bridge_url) == BUG_REPORT_BRIDGE_ORIGIN

/**
 * Spends one of a ckey's hourly allowances, mirroring the reporting service's own caps.
 *
 * Returns 0 when there was one to spend, otherwise how long until one frees up.
 * They live for the round, so a reconnect doesn't refill them.
 * Arguments:
 * * ckey - whose allowance
 * * kind - accepted, submits, drafts or uploads
 * * spend - FALSE to only check
 */
/proc/bug_report_budget(ckey, kind, spend = TRUE)
	var/static/list/caps = list(
		"accepted" = BUG_REPORT_ACCEPTED_PER_HOUR,
		"submits" = BUG_REPORT_SUBMITS_PER_HOUR,
		"drafts" = BUG_REPORT_DRAFTS_PER_HOUR,
		"uploads" = BUG_REPORT_UPLOADS_PER_HOUR,
	)
	var/key = "[ckey]:[kind]"
	var/list/uses = GLOB.bug_report_budgets[key] || list()
	GLOB.bug_report_budgets[key] = uses
	while(length(uses) && uses[1] <= world.time - 1 HOURS)
		uses.Cut(1, 2)
	if(length(uses) >= caps[kind])
		return uses[1] + 1 HOURS - world.time
	if(spend)
		uses += world.time
	return 0

/// Opens this connection's report, starting a new one once the last was accepted
/client/proc/open_bug_report()
	if(!bug_report_draft || bug_report_draft.result?["kind"] == "accepted")
		new_bug_report()
	bug_report_draft?.ui_interact(mob)

/// Starts a new report, unless this ckey has started too many this hour
/client/proc/new_bug_report()
	var/wait = bug_report_budget(ckey, "drafts")
	if(wait)
		to_chat(src, span_warning("You've started a lot of bug reports this hour. Try again in [DisplayTimeText(wait)], or reopen one with Recent bug reports."))
		return FALSE
	// Only the report being written keeps its preview image in memory
	bug_report_draft?.forget_preview()
	bug_report_draft = new(src)
	LAZYADD(bug_report_history, bug_report_draft)
	if(length(bug_report_history) > BUG_REPORT_HISTORY)
		var/datum/bug_report/oldest = bug_report_history[1]
		bug_report_history.Cut(1, 2)
		qdel(oldest)
	return TRUE

GAME_VERB_DESC(/client, recent_bug_reports, "Recent bug reports", "Reopen a report or receipt from this connection", "OOC")
	var/list/choices = list()
	for(var/datum/bug_report/report as anything in bug_report_history)
		choices["[report.fields["title"] || "Untitled"] ([report.request_id])"] = report
	var/choice = input(src, "Choose a report", "Recent bug reports") as null|anything in choices
	var/datum/bug_report/report = choices[choice]
	if(QDELETED(report))
		return
	if(report != bug_report_draft)
		bug_report_draft?.forget_preview()
	bug_report_draft = report
	report.ui_interact(mob)

GAME_VERB_DESC(/client, report_upstream_issue, "Report upstream issue", "Open the manual upstream GitHub issue form", "OOC")
	DIRECT_OUTPUT(src, link("https://github.com/tgstation/tgstation/issues/new?template=bug_report_form.yml"))

/**
 * One bug report from one connection, from the moment its form opens to its receipt.
 *
 * The incident context is frozen in New(), before anything can yield. Everything after goes through the
 * reporting bridge on this machine, one request at a time per report. The window only updates when
 * something here changes, and we poll only while it is open and the report waits on the service.
 */
/datum/bug_report
	/// The connection writing this report
	var/client/owner
	/// The connection's session id, frozen into the context
	var/session_id
	/// This report's id at the bridge
	var/request_id
	/// What the game looked like when the report was opened, never changed after
	var/list/context
	/// Whether the bridge holds our context, which every other call needs
	var/context_saved = FALSE
	/// The reporter's text and choices as the page last sent them
	var/list/fields = list(
		"title" = "",
		"observed" = "",
		"expected" = "",
		"reproduction" = "",
		"category" = "Other",
		"severity" = "unspecified",
		"incidentAt" = null,
	)
	/// Whether fields changed since the bridge last saved them
	var/fields_dirty = FALSE
	/// Bumped whenever we replace the page's text, so a page holding older text can't write it back
	var/fields_epoch = 0
	/// The saved draft revision our fields are based on
	var/revision = 0
	/// A saved draft that moved on while we had unsaved text, waiting for the reporter to choose
	var/list/remote_draft
	/// One line telling the reporter what is happening
	var/status = "Saving incident context"
	/// Whether a reporter's action is running, which holds every other action
	var/busy = FALSE
	/// Whether a bridge request for this report is in flight
	var/requesting = FALSE
	/// The submission's outcome - checking, needs_revision, limited, or accepted with its receipt
	var/list/result
	/// The idempotency key of the submission being checked
	var/submission_key
	/// Failed polls in a row, which pause polling at four
	var/poll_failures = 0
	/// Whether polling stopped after failures until the reporter retries
	var/polling_paused = FALSE
	/// The wait before the next background poll, growing while nothing changes
	var/poll_delay = BUG_REPORT_POLL_MIN
	COOLDOWN_DECLARE(refresh_cooldown)
	COOLDOWN_DECLARE(action_cooldown)

/datum/bug_report/New(client/reporting_client)
	owner = reporting_client
	owner.bug_report_session_id ||= GUID()
	session_id = owner.bug_report_session_id
	request_id = GUID()
	context = bug_report_context_snapshot(owner.mob, owner.ckey, session_id, owner.byond_version, owner.byond_build)
	return ..()

/datum/bug_report/Destroy()
	if(capture_nonce)
		cancel_ui_capture()
	if(owner?.bug_report_draft == src)
		owner.bug_report_draft = null
	owner = null
	return ..()

/// Whether this is still the report its connection is writing - a reconnect or another report ends that
/datum/bug_report/proc/valid_owner()
	return owner?.bug_report_draft == src

/// A bridge request that can send a generated file as its body
/datum/http_request/bug_report
	/// The file rust-g sends instead of the body text
	var/body_file

/datum/http_request/bug_report/build_options()
	return json_encode(list("body_filename" = body_file, "output_filename" = output_file, "timeout_seconds" = timeout_seconds))

/**
 * Sends one request to the reporting bridge and waits for it.
 *
 * Returns the decoded reply, TRUE for a reply saved to output_file, or null with status saying why.
 * One request runs per report and BUG_REPORT_MAX_REQUESTS across the server, so nothing a reporter does
 * can pile up rust-g jobs. We skip SShttp on purpose, it would log the bearer token and the report text.
 * Arguments:
 * * route - the bridge's game route, like action or attachment/preview
 * * body - the request body as text
 * * headers - headers besides the bearer token
 * * body_file - a generated file rust-g sends as the body instead
 * * output_file - a generated file rust-g saves the reply into
 * * timeout - seconds rust-g waits for the bridge
 */
/datum/bug_report/proc/bridge_call(route, body = "", list/headers, body_file, output_file, timeout = 10)
	if(!bug_reports_enabled())
		status = "Reporting isn't set up on this server. Your text is kept."
		return
	UNTIL(!valid_owner() || (!requesting && GLOB.bug_report_requests < BUG_REPORT_MAX_REQUESTS))
	if(!valid_owner())
		return
	requesting = TRUE
	GLOB.bug_report_requests++
	var/list/request_headers = list("Authorization" = "Bearer [CONFIG_GET(string/bug_report_bridge_token)]")
	if(headers)
		request_headers += headers
	var/datum/http_request/bug_report/request = new
	request.body_file = body_file
	request.prepare(RUSTG_HTTP_METHOD_POST, "[BUG_REPORT_BRIDGE_ORIGIN]/game/[route]", body, request_headers, output_file, timeout)
	try
		request.begin_async()
	catch
		status = "Reporting service unavailable (rust-g refused the request). Your text is kept."
	UNTIL(request.is_complete())
	GLOB.bug_report_requests--
	requesting = FALSE
	if(!valid_owner())
		return
	var/datum/http_response/response = request.into_response()
	if(!response.errored && response.status_code == 409)
		return list("revisionConflict" = TRUE)
	if(response.errored || response.status_code < 200 || response.status_code >= 300)
		status = "Reporting service unavailable ([response.status_code || "no answer"]). Your text is kept."
		return
	if(output_file)
		return TRUE
	var/list/data
	try
		data = json_decode(response.body)
	catch
		data = null
	if(islist(data))
		return data
	status = "Reporting service sent a reply we couldn't read. Your text is kept."

/**
 * Runs an action on this report's draft at the bridge, handing it our context first if it doesn't hold it.
 *
 * Arguments:
 * * action - read, save, submit or receipt
 * * extra - more fields for the action's body
 */
/datum/bug_report/proc/bridge_action(action, list/extra)
	if(!context_saved && !save_context())
		return
	var/list/body = list("ckey" = context["ckey"], "sessionId" = session_id, "requestId" = request_id, "action" = action)
	if(extra)
		body += extra
	return bridge_call("action", json_encode(body), list("Content-Type" = "application/json"))

/// Hands our frozen context to the bridge, which keeps it before any cloud draft exists
/datum/bug_report/proc/save_context()
	var/list/response = bridge_call("context", json_encode(list("context" = context, "requestId" = request_id)), list("Content-Type" = "application/json"))
	if(!response)
		return FALSE
	context_saved = TRUE
	status = response["status"] == "ready" ? "Ready" : "Incident context saved locally; waiting for reporting service"
	return TRUE

/// Saves the reporter's text to the draft if it changed, returning whether the saved draft now matches it
/datum/bug_report/proc/save_fields()
	if(!context_saved && !save_context())
		return FALSE
	if(remote_draft)
		status = "Choose Load saved draft or Keep my local text before saving."
		return FALSE
	if(!fields_dirty)
		return TRUE
	var/list/response = bridge_action("save", list("fields" = fields, "revision" = revision))
	if(response?["revisionConflict"])
		remote_draft = bridge_action("read")?["draft"]
		status = "The saved draft changed. Your local text is preserved. Load the saved draft or explicitly keep your local text."
		return FALSE
	var/list/draft = response?["draft"]
	if(!draft)
		if(response)
			status = "Context saved locally; service registration is pending."
		return FALSE
	revision = draft["revision"]
	fields_dirty = FALSE
	update_attachment(draft["attachment"])
	return TRUE

/**
 * Takes the page's text and choices, refusing a stale page or text past the service's limits. No network.
 *
 * Returns whether the page's fields were taken.
 * Arguments:
 * * incoming - the page's fields
 * * epoch - the fields_epoch the page's text is based on
 * * required - whether every text field must be filled, as for a submission
 */
/datum/bug_report/proc/update_local_fields(list/incoming, epoch, required = FALSE)
	var/static/list/text_limits = list(
		"title" = BUG_REPORT_TITLE_MAX,
		"observed" = BUG_REPORT_TEXT_MAX,
		"expected" = BUG_REPORT_TEXT_MAX,
		"reproduction" = BUG_REPORT_TEXT_MAX,
	)
	var/static/list/categories = list("Other", "UI", "Gameplay", "Crash", "Performance", "Map")
	var/static/list/severities = list("unspecified", "minor", "major", "critical")
	if(result?["kind"] == "accepted" || epoch != fields_epoch || !islist(incoming))
		return FALSE
	for(var/name, limit in text_limits)
		var/value = incoming[name]
		if(!istext(value) || length_char(value) > limit || (required && !length(trim(value))))
			status = "Fill each required field within its limit."
			return FALSE
	var/incident_at = incoming["incidentAt"]
	// Exact UTC text crosses DM unchanged, the authenticated host validates it
	if(!isnull(incident_at) && (!istext(incident_at) || length(incident_at) > 40))
		return FALSE
	var/category = incoming["category"]
	var/severity = incoming["severity"]
	var/list/next_fields = list(
		"title" = incoming["title"],
		"observed" = incoming["observed"],
		"expected" = incoming["expected"],
		"reproduction" = incoming["reproduction"],
		"category" = (category in categories) ? category : "Other",
		"severity" = (severity in severities) ? severity : "unspecified",
		"incidentAt" = incident_at,
	)
	for(var/name, value in next_fields)
		if(fields[name] != value)
			fields = next_fields
			fields_dirty = TRUE
			// Editing a submission whose checks paused abandons it, the next submit starts a fresh one
			if(polling_paused)
				submission_key = null
				result = null
				polling_paused = FALSE
			break
	return TRUE

/// Replaces our text with a saved draft's and sends the page the new text
/datum/bug_report/proc/adopt_draft(list/draft)
	fields = draft["fields"].Copy()
	revision = draft["revision"]
	fields_dirty = FALSE
	fields_epoch++
	remote_draft = null
	result = null
	status = "Saved draft loaded."
	update_static_data_for_all_viewers()

/**
 * Settles a conflict between our unsaved text and a saved draft that moved on.
 *
 * Arguments:
 * * keep_local - TRUE keeps our text over the saved draft, FALSE loads the saved draft
 */
/datum/bug_report/proc/resolve_draft(keep_local)
	if(!remote_draft || result?["kind"] == "accepted")
		return FALSE
	if(!keep_local)
		adopt_draft(remote_draft)
		return TRUE
	revision = remote_draft["revision"]
	remote_draft = null
	fields_dirty = TRUE
	status = "Local text selected. Submit to save this version."
	return TRUE

/**
 * Spends one of the reporter's hourly allowances, or says in status how long until one frees up.
 *
 * Returns whether there was one.
 * Arguments:
 * * kind - accepted, submits or uploads
 * * spend - FALSE to only check
 */
/datum/bug_report/proc/take_allowance(kind, spend = TRUE)
	var/static/list/refusals = list(
		"accepted" = "You've had [BUG_REPORT_ACCEPTED_PER_HOUR] reports accepted this hour. You can send another in",
		"submits" = "You've submitted [BUG_REPORT_SUBMITS_PER_HOUR] times this hour. You can submit again in",
		"uploads" = "You've attached [BUG_REPORT_UPLOADS_PER_HOUR] screenshots this hour. You can attach another in",
	)
	var/wait = bug_report_budget(context["ckey"], kind, spend)
	if(wait)
		status = "[refusals[kind]] [DisplayTimeText(wait)]."
	return !wait

/// Saves and submits the report, then checks it until the service answers
/datum/bug_report/proc/submit_fields()
	if(busy)
		return
	if(!take_allowance("accepted", spend = FALSE))
		return finish_action()
	busy = TRUE
	push_update()
	if(save_fields())
		if(attachment_pending || (attachment && attachment["state"] != "ready"))
			status = "Wait for the screenshot, retry it, or explicitly remove it before submitting."
		else if(take_allowance("submits"))
			submission_key = GUID()
			poll_failures = 0
			polling_paused = FALSE
			result = list("kind" = "checking")
			check_submission()
	finish_action()
	schedule_poll(restart = TRUE)

/// Asks the service how the submission's check is going
/datum/bug_report/proc/check_submission()
	var/key = submission_key
	if(!key || polling_paused)
		return
	var/list/response = bridge_action("submit", list("revision" = revision, "key" = key))
	// An edit, a new submission or an acceptance while we waited makes this answer stale
	if(key != submission_key || result?["kind"] == "accepted")
		return
	if(!response)
		poll_failed()
		return
	poll_failures = 0
	var/list/next_result = response["result"]
	if(!next_result)
		return
	if(next_result["kind"] != result?["kind"])
		poll_delay = BUG_REPORT_POLL_MIN
	result = next_result
	status = result["kind"]
	if(status == "accepted")
		bug_report_budget(context["ckey"], "accepted")

/// Fetches the accepted report's receipt, which gains its issue link once published
/datum/bug_report/proc/refresh_receipt()
	var/list/response = bridge_action("receipt")
	if(!response)
		poll_failed()
		return
	poll_failures = 0
	if(response["receipt"])
		result = list("kind" = "accepted", "receipt" = response["receipt"])

/// Reads the saved draft and its image, keeping unsaved text when the saved draft moved on
/datum/bug_report/proc/read_draft()
	var/list/response = bridge_action("read")
	// A reporter's action or an acceptance while we waited makes this read stale
	if(busy || result?["kind"] == "accepted")
		return
	if(!response)
		poll_failed()
		return
	poll_failures = 0
	var/list/draft = response["draft"]
	if(!draft)
		return
	if(draft["revision"] != revision)
		if(fields_dirty)
			remote_draft = draft
			status = "The saved draft changed. Your local text is preserved; choose which version to continue editing."
		else
			adopt_draft(draft)
	update_attachment(draft["attachment"])
	if(draft["intake"] == "submitted")
		refresh_receipt()

/// Counts a failed poll, pausing polling after four in a row until the reporter retries
/datum/bug_report/proc/poll_failed()
	if(++poll_failures > 3)
		polling_paused = TRUE
		status = "Checking paused after connection failures. Your text is preserved. Retry connection to recover the result, or edit and submit again."

/// Reads whatever this report waits on - its new context, its submission check, its receipt, or its draft and image
/datum/bug_report/proc/refresh()
	if(!valid_owner())
		return
	if(!context_saved)
		save_context()
	else if(result?["kind"] == "accepted")
		refresh_receipt()
	else if(result?["kind"] == "checking")
		check_submission()
	else
		read_draft()
	push_update()
	schedule_poll()

/// Whether this report waits on the service for something a poll would bring
/datum/bug_report/proc/waiting_on_service()
	if(polling_paused || !context_saved)
		return FALSE
	switch(result?["kind"])
		if("checking")
			return TRUE
		if("accepted")
			return !result["receipt"]?["issueUrl"]
	return attachment_pending && attachment?["state"] != "failed" && world.time < attachment_until

/**
 * Arms the one background poll while the window is open and the report waits on the service.
 *
 * Arguments:
 * * restart - poll soon again, since something new just started waiting
 */
/datum/bug_report/proc/schedule_poll(restart = FALSE)
	if(!LAZYLEN(open_uis) || !waiting_on_service())
		poll_delay = BUG_REPORT_POLL_MIN
		return
	if(restart)
		poll_delay = BUG_REPORT_POLL_MIN
	addtimer(CALLBACK(src, PROC_REF(poll)), poll_delay, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_NO_HASH_WAIT)
	poll_delay = min(poll_delay * 1.5, BUG_REPORT_POLL_MAX)

/// The background poll - waits out anything else talking to the bridge, and stops once the window closes
/datum/bug_report/proc/poll()
	if(!valid_owner() || !LAZYLEN(open_uis))
		return
	if(busy || requesting)
		schedule_poll()
		return
	refresh()

/// Sends the window this report's data now, plus any keys only sent on request
/datum/bug_report/proc/push_update(list/extra)
	if(!LAZYLEN(open_uis))
		return
	var/list/data = ui_data(owner?.mob)
	if(extra)
		data += extra
	send_partial(data)

/**
 * Ends the reporter's action, saying how it went when there's news, and shows the window where things stand.
 *
 * Arguments:
 * * message - a new status line, or null to keep the current one
 * * extra - keys only sent on request, like the preview
 */
/datum/bug_report/proc/finish_action(message, list/extra)
	if(message)
		status = message
	busy = FALSE
	push_update(extra)

/// Sends the window only these keys
/datum/bug_report/proc/send_partial(list/data)
	for(var/datum/tgui/ui as anything in open_uis)
		ui.send_update(data)

/datum/bug_report/ui_state(mob/user)
	return GLOB.always_state

/datum/bug_report/ui_status(mob/user)
	return valid_owner() && user.client == owner ? UI_INTERACTIVE : UI_CLOSE

/datum/bug_report/ui_interact(mob/user, datum/tgui/ui)
	if(user.client != owner)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		return
	ui = new(user, src, "BugReport", "Report a Meridian bug")
	// Every change here pushes its own update, so an open window costs nothing while it sits there
	ui.set_autoupdate(FALSE)
	ui.open()
	poll_delay = BUG_REPORT_POLL_MIN
	if(COOLDOWN_FINISHED(src, refresh_cooldown))
		COOLDOWN_START(src, refresh_cooldown, 5 SECONDS)
		INVOKE_ASYNC(src, PROC_REF(refresh))

/datum/bug_report/ui_static_data(mob/user)
	return list("reportId" = request_id, "context" = context, "fields" = fields, "fieldsEpoch" = fields_epoch)

/datum/bug_report/ui_data(mob/user)
	return list(
		"status" = status,
		"busy" = busy,
		"result" = result,
		"conflict" = !!remote_draft,
		"pollingPaused" = polling_paused,
		"attachment" = attachment,
		"attachmentPending" = attachment_pending,
		"previewConfirmed" = preview_confirmed,
		"captureTargets" = capture_targets(),
	)

/datum/bug_report/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !valid_owner() || usr.client != owner || busy)
		return
	switch(action)
		if("submit", "screenshot", "capture_ui", "keep")
			// Never take report ids, context or identity from the page, only its text and choices
			if(!update_local_fields(params["fields"], params["fieldsEpoch"], action == "submit"))
				return TRUE
			if(action == "keep")
				return resolve_draft(TRUE)
			// These reach the bridge, so a page can't fire them faster than one a second
			if(!COOLDOWN_FINISHED(src, action_cooldown))
				return TRUE
			COOLDOWN_START(src, action_cooldown, 1 SECONDS)
			switch(action)
				if("submit")
					INVOKE_ASYNC(src, PROC_REF(submit_fields))
				if("screenshot")
					INVOKE_ASYNC(src, PROC_REF(choose_screenshot))
				if("capture_ui")
					INVOKE_ASYNC(src, PROC_REF(begin_ui_capture), params["windowId"])
			return TRUE
		if("reload")
			return resolve_draft(FALSE)
		if("remove_screenshot", "screenshot_consent")
			if(!COOLDOWN_FINISHED(src, action_cooldown))
				return
			COOLDOWN_START(src, action_cooldown, 1 SECONDS)
			if(action == "remove_screenshot")
				INVOKE_ASYNC(src, PROC_REF(remove_screenshot), params["attachmentId"])
			else
				INVOKE_ASYNC(src, PROC_REF(screenshot_consent), params["attachmentId"], !!params["publicConsent"])
			return TRUE
		if("preview")
			send_preview(params["attachmentId"], !!params["reload"])
		if("preview_loaded")
			if(preview_id && preview_id == attachment?["id"] && params["attachmentId"] == preview_id)
				preview_confirmed = TRUE
				return TRUE
		if("targets")
			ui.send_update(list("captureTargets" = capture_targets()))
		if("refresh")
			if(!COOLDOWN_FINISHED(src, refresh_cooldown))
				return
			COOLDOWN_START(src, refresh_cooldown, 5 SECONDS)
			poll_failures = 0
			polling_paused = FALSE
			poll_delay = BUG_REPORT_POLL_MIN
			INVOKE_ASYNC(src, PROC_REF(refresh))
			return TRUE
		if("new")
			if(result?["kind"] == "accepted" && owner.new_bug_report())
				owner.bug_report_draft.ui_interact(owner.mob)
		if("issue")
			var/issue_url = result?["receipt"]?["issueUrl"]
			// Only ever a GitHub issue, whatever the service sends
			if(istext(issue_url) && findtextEx(issue_url, "https://github.com/") == 1)
				DIRECT_OUTPUT(owner, link(issue_url))

#undef BUG_REPORT_BRIDGE_ORIGIN
#undef BUG_REPORT_TITLE_MAX
#undef BUG_REPORT_TEXT_MAX
#undef BUG_REPORT_HISTORY
#undef BUG_REPORT_MAX_REQUESTS
#undef BUG_REPORT_POLL_MIN
#undef BUG_REPORT_POLL_MAX
#undef BUG_REPORT_ACCEPTED_PER_HOUR
#undef BUG_REPORT_SUBMITS_PER_HOUR
#undef BUG_REPORT_DRAFTS_PER_HOUR
#undef BUG_REPORT_UPLOADS_PER_HOUR
