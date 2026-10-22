/// Incident context is captured once, before HTTP or UI work can yield.
GLOBAL_VAR_INIT(bug_report_boot_id, GUID())

/client
	var/datum/bug_report/bug_report_draft
	var/bug_report_session_id
	var/list/bug_report_history = list()
	var/datum/bug_report/bug_report_upload
	var/bug_report_upload_until = 0

/datum/config_entry/string/bug_report_bridge_url
	default = ""

/datum/config_entry/string/bug_report_bridge_token
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/string/bug_report_server_id
	default = "meridian-rift-main"

/client/proc/open_bug_report()
	if(!bug_report_draft || bug_report_draft.result?["kind"] == "accepted")
		new_bug_report()
	bug_report_draft.ui_interact(mob)

/client/proc/new_bug_report()
	bug_report_draft = new(src)
	bug_report_history += bug_report_draft
	if(length(bug_report_history) > 20)
		var/datum/bug_report/oldest = bug_report_history[1]
		bug_report_history.Cut(1, 2)
		qdel(oldest)

GAME_VERB_DESC(/client, recent_bug_reports, "Recent bug reports", "Reopen a report or receipt from this connection", "OOC")
	var/list/choices = list()
	for(var/datum/bug_report/report as anything in bug_report_history)
		choices["[report.fields["title"] || "Untitled"] ([report.request_id])"] = report
	var/choice = input(src, "Choose a report", "Recent bug reports") as null|anything in choices
	if(!choice || !choices[choice])
		return
	bug_report_draft = choices[choice]
	bug_report_draft.ui_interact(mob)
	INVOKE_ASYNC(bug_report_draft, TYPE_PROC_REF(/datum/bug_report, refresh_draft))

GAME_VERB_DESC(/client, report_upstream_issue, "Report upstream issue", "Open the manual upstream GitHub issue form", "OOC")
	DIRECT_OUTPUT(src, link("https://github.com/tgstation/tgstation/issues/new?template=bug_report_form.yml"))

GAME_VERB_DESC(/client, link_discord_bug_reports, "Link Discord for reports", "Create a one-time proof for linking report identity", "OOC")
	if(!bug_report_draft)
		new_bug_report()
	INVOKE_ASYNC(bug_report_draft, TYPE_PROC_REF(/datum/bug_report, link_discord))

/datum/bug_report/proc/link_discord()
	if(!registered)
		register_context()
	var/list/response = bridge_request("action", action_body("link"))
	if(valid_owner() && response?["code"])
		to_chat(owner, span_notice("Use this one-time code with the Discord reporting identity-link command when available. It expires in ten minutes. Keep it private: [response["code"]]"))

/datum/bug_report
	var/client/owner
	var/session_id
	var/request_id
	var/list/context
	var/list/fields = list("title" = "", "observed" = "", "expected" = "", "reproduction" = "", "category" = "Other", "severity" = "unspecified", "incidentAt" = null)
	var/revision = 0
	var/status = "Saving incident context"
	var/registered = FALSE
	var/busy = FALSE
	var/list/result
	var/list/attachment
	var/submission_key
	var/last_polled = 0
	var/fields_dirty = FALSE
	var/fields_epoch = 0
	var/list/remote_draft
	var/attachment_pending = FALSE
	var/attachment_until = 0
	var/pending_previous_id
	var/preview
	var/preview_confirmed = FALSE
	var/poll_failures = 0
	var/polling_paused = FALSE
	var/poll_generation = 0
	var/poll_inflight = FALSE

/datum/bug_report/New(client/reporting_client)
	owner = reporting_client
	if(!owner.bug_report_session_id)
		owner.bug_report_session_id = GUID()
	session_id = owner.bug_report_session_id
	request_id = GUID()
	context = capture_context(owner)
	INVOKE_ASYNC(src, PROC_REF(register_context))
	return ..()

/datum/bug_report/Destroy()
	if(capture_nonce)
		cancel_ui_capture()
	if(owner?.bug_report_upload == src)
		owner.bug_report_upload = null
		owner.bug_report_upload_until = 0
	if(owner?.bug_report_draft == src)
		owner.bug_report_draft = null
	owner = null
	context = null
	fields = null
	result = null
	return ..()

/datum/bug_report/proc/capture_context(client/reporting_client)
	return bug_report_context_snapshot(reporting_client.mob, reporting_client.ckey, session_id, reporting_client.byond_version, reporting_client.byond_build)

/datum/bug_report/proc/valid_owner()
	return owner && owner.bug_report_session_id == session_id && owner.bug_report_draft == src

/datum/bug_report/proc/bridge_request(route, list/body)
	var/bridge_url = CONFIG_GET(string/bug_report_bridge_url)
	// No user-supplied URL or public inbound game endpoint.
	if(bridge_url != "http://127.0.0.1:18764")
		status = "Reporting bridge is not configured. Your text is preserved; retry when reporting is available."
		return
	var/datum/http_request/request = new()
	request.prepare(RUSTG_HTTP_METHOD_POST, "[bridge_url]/game/[route]", json_encode(body), list(
		"Authorization" = "Bearer [CONFIG_GET(string/bug_report_bridge_token)]",
		"Content-Type" = "application/json",
	), timeout_seconds = 10)
	request.begin_async()
	var/deadline = world.time + 15 SECONDS
	while(!request.is_complete() && world.time < deadline)
		sleep(2)
	if(!valid_owner())
		return
	if(!request.is_complete())
		status = "Reporting service timed out. Your text is preserved; retry connection."
		return
	var/datum/http_response/response = request.into_response()
	if(!response.errored && response.status_code == 409)
		return list("revisionConflict" = TRUE)
	if(response.errored || response.status_code < 200 || response.status_code >= 300)
		status = "Reporting service unavailable ([response.status_code]). Your text is preserved."
		return
	var/list/data
	try
		data = json_decode(response.body)
	catch
		status = "Reporting service returned an invalid response. Your text is preserved."
		return
	return data

/datum/bug_report/proc/register_context()
	var/list/response = bridge_request("context", list("context" = context, "requestId" = request_id))
	if(!response)
		return
	registered = response["status"] == "ready"
	status = registered ? "Ready" : "Incident context saved locally; waiting for reporting service"
	SStgui.update_uis(src)

/datum/bug_report/proc/action_body(action)
	return list("ckey" = context["ckey"], "sessionId" = session_id, "requestId" = request_id, "action" = action)

/datum/bug_report/proc/save_fields()
	if(result?["kind"] == "accepted")
		return FALSE
	if(remote_draft)
		status = "Choose Load saved draft or Keep my local text before saving."
		return FALSE
	var/list/body = action_body("save")
	body["fields"] = fields.Copy()
	body["revision"] = revision
	var/list/response = bridge_request("action", body)
	if(!response)
		return FALSE
	if(response["revisionConflict"])
		var/list/current = bridge_request("action", action_body("read"))
		if(current?["draft"])
			remote_draft = current["draft"]
		status = "The saved draft changed. Your local text is preserved. Load the saved draft or explicitly keep your local text."
		return FALSE
	var/list/draft = response["draft"]
	if(!draft)
		status = "Context saved locally; service registration is pending."
		return FALSE
	revision = draft["revision"]
	update_attachment(draft["attachment"])
	fields_dirty = FALSE
	return TRUE

/// Scalar local edits survive TGUI unmount. This performs no HTTP or AI work.
/datum/bug_report/proc/update_local_fields(list/incoming, epoch, required = FALSE)
	if(result?["kind"] == "accepted" || epoch != fields_epoch || !islist(incoming))
		return FALSE
	for(var/name in list("title", "observed", "expected", "reproduction"))
		var/value = incoming[name]
		if(!istext(value) || (required && !length(trim(value))) || length_char(value) > (name == "title" ? 160 : 8000))
			status = "Fill each required field within its limit."
			return FALSE
	var/category = incoming["category"]
	var/severity = incoming["severity"]
	var/incident_at = incoming["incidentAt"]
	if(!isnull(incident_at) && (!istext(incident_at) || length(incident_at) > 40))
		return FALSE
	// Exact UTC text crosses DM unchanged; the authenticated host validates it.
	var/list/next_fields = list("title" = incoming["title"], "observed" = incoming["observed"], "expected" = incoming["expected"], "reproduction" = incoming["reproduction"], "category" = (category in list("Other", "UI", "Gameplay", "Crash", "Performance", "Map")) ? category : "Other", "severity" = (severity in list("unspecified", "minor", "major", "critical")) ? severity : "unspecified", "incidentAt" = incident_at)
	if(json_encode(next_fields) != json_encode(fields))
		fields = next_fields
		fields_dirty = TRUE
		if(polling_paused)
			poll_generation++
			submission_key = null
			result = null
			polling_paused = FALSE
	return TRUE

/datum/bug_report/proc/adopt_draft(list/draft)
	fields = draft["fields"].Copy()
	revision = draft["revision"]
	fields_dirty = FALSE
	fields_epoch++
	remote_draft = null
	result = null
	status = "Saved draft loaded."

/datum/bug_report/proc/resolve_draft(keep_local)
	if(!remote_draft || result?["kind"] == "accepted")
		return FALSE
	if(keep_local)
		revision = remote_draft["revision"]
		remote_draft = null
		fields_dirty = TRUE
		status = "Local text selected. Submit to save this version."
	else
		adopt_draft(remote_draft)
	return TRUE

/datum/bug_report/proc/submit_fields()
	if(busy)
		return
	busy = TRUE
	if(save_fields())
		if(attachment_pending || (attachment && attachment["state"] != "ready"))
			status = "Wait for the screenshot, retry it, or explicitly remove it before submitting."
			busy = FALSE
			SStgui.update_uis(src)
			return
		submission_key = GUID()
		poll_generation++
		poll_failures = 0
		polling_paused = FALSE
		result = list("kind" = "checking")
		poll_submission()
	busy = FALSE
	SStgui.update_uis(src)

/datum/bug_report/proc/poll_submission(generation = null)
	if(isnull(generation))
		generation = poll_generation
	if(!valid_owner() || !submission_key || generation != poll_generation || poll_inflight || result?["kind"] == "accepted")
		return
	poll_inflight = TRUE
	var/list/body = action_body("submit")
	body["revision"] = revision
	body["key"] = submission_key
	var/list/response = bridge_request("action", body)
	poll_inflight = FALSE
	if(!valid_owner() || generation != poll_generation || result?["kind"] == "accepted")
		return
	if(!response)
		poll_failures++
		if(poll_failures <= 3)
			addtimer(CALLBACK(src, PROC_REF(poll_submission), generation), (2 ** poll_failures) SECONDS)
		else
			polling_paused = TRUE
			status = "Checking paused after connection failures. Your text is preserved. Retry connection to recover the result, or edit and submit again."
		SStgui.update_uis(src)
		return
	poll_failures = 0
	polling_paused = FALSE
	result = response["result"]
	if(!result)
		return
	status = result["kind"]
	if(status == "checking")
		addtimer(CALLBACK(src, PROC_REF(poll_submission), generation), 2 SECONDS)
	else if(status == "accepted")
		addtimer(CALLBACK(src, PROC_REF(refresh_receipt)), 5 SECONDS)
	SStgui.update_uis(src)

/datum/bug_report/proc/refresh_receipt()
	if(!valid_owner())
		return
	var/list/response = bridge_request("action", action_body("receipt"))
	if(response?["receipt"])
		result = list("kind" = "accepted", "receipt" = response["receipt"])
		var/list/receipt = result["receipt"]
		if(!receipt["issueUrl"])
			addtimer(CALLBACK(src, PROC_REF(refresh_receipt)), 10 SECONDS)
	SStgui.update_uis(src)

/datum/bug_report/proc/refresh_draft()
	if(!valid_owner())
		return
	if(busy)
		queue_attachment_refresh()
		return
	if(result?["kind"] == "accepted")
		refresh_receipt()
		return
	if(result?["kind"] == "checking")
		if(!polling_paused)
			poll_submission()
		return
	var/expected_generation = poll_generation
	var/list/response = bridge_request("action", action_body("read"))
	if(!valid_owner() || busy || expected_generation != poll_generation || result?["kind"] == "accepted")
		queue_attachment_refresh()
		return
	var/list/draft = response?["draft"]
	if(draft)
		if(draft["revision"] != revision)
			if(fields_dirty)
				remote_draft = draft
				status = "The saved draft changed. Your local text is preserved; choose which version to continue editing."
			else
				adopt_draft(draft)
		update_attachment(draft["attachment"])
		if(draft["intake"] == "submitted")
			refresh_receipt()
	queue_attachment_refresh()
	SStgui.update_uis(src)

/datum/bug_report/ui_state(mob/user)
	return GLOB.always_state

/datum/bug_report/ui_status(mob/user)
	return valid_owner() && user.client == owner ? UI_INTERACTIVE : UI_CLOSE

/datum/bug_report/ui_interact(mob/user, datum/tgui/ui)
	if(user.client != owner)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BugReport", "Report a Meridian bug")
		ui.open()
	if(registered)
		INVOKE_ASYNC(src, PROC_REF(refresh_draft))

/datum/bug_report/ui_data(mob/user)
	return list("fields" = fields, "context" = context, "fieldsEpoch" = fields_epoch, "reportId" = request_id, "conflict" = !!remote_draft, "pollingPaused" = polling_paused, "revision" = revision, "status" = status, "busy" = busy, "result" = result, "attachment" = attachment, "attachmentPending" = attachment_pending, "preview" = preview, "previewConfirmed" = preview_confirmed, "captureTargets" = capture_targets())

/datum/bug_report/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !valid_owner() || usr.client != owner || busy)
		return
	if(action in list("submit", "screenshot", "capture_ui", "draft", "keep"))
		// Never accept report IDs, context or identity from TGUI parameters.
		if(!update_local_fields(params["fields"], params["fieldsEpoch"], action == "submit"))
			return TRUE
		if(action == "submit")
			INVOKE_ASYNC(src, PROC_REF(submit_fields))
		else if(action == "screenshot")
			INVOKE_ASYNC(src, PROC_REF(choose_screenshot))
		else if(action == "capture_ui")
			INVOKE_ASYNC(src, PROC_REF(begin_ui_capture), params["windowId"])
		else if(action == "keep")
			resolve_draft(TRUE)
	else if(action == "preview_screenshot")
		INVOKE_ASYNC(src, PROC_REF(load_screenshot_preview), params["attachmentId"])
	else if(action == "preview_loaded")
		if(preview && attachment?["id"] == params["attachmentId"])
			preview_confirmed = TRUE
	else if(action == "remove_screenshot")
		INVOKE_ASYNC(src, PROC_REF(remove_screenshot), params["attachmentId"])
	else if(action == "screenshot_consent")
		INVOKE_ASYNC(src, PROC_REF(screenshot_consent), params["attachmentId"], !!params["publicConsent"])
	else if(action == "reload")
		resolve_draft(FALSE)
	else if(action == "new" && result?["kind"] == "accepted")
		owner.new_bug_report()
		owner.bug_report_draft.ui_interact(owner.mob)
	else if(action == "issue")
		var/list/receipt = result?["receipt"]
		if(receipt?["issueUrl"])
			DIRECT_OUTPUT(owner, link(receipt["issueUrl"]))
	else if(action == "refresh")
		poll_failures = 0
		polling_paused = FALSE
		INVOKE_ASYNC(src, PROC_REF(refresh_draft))
	return TRUE
