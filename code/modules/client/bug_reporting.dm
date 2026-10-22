/// Incident context is captured once, before HTTP or UI work can yield.
GLOBAL_VAR_INIT(bug_report_boot_id, GUID())

/client
	var/datum/bug_report/bug_report_draft
	var/bug_report_session_id
	var/list/bug_report_history = list()

/datum/config_entry/string/bug_report_bridge_url
	default = ""

/datum/config_entry/string/bug_report_bridge_token
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/string/bug_report_web_url
	default = "https://meridian.a13.info/bug-report/"

/datum/config_entry/string/bug_report_server_id
	default = "meridian-rift-main"

GAME_VERB_DESC(/client, report_issue_browser, "Report in browser", "Report a Meridian issue without TGUI", "OOC")
	if(!CONFIG_GET(string/bug_report_bridge_url))
		DIRECT_OUTPUT(src, link(CONFIG_GET(string/bug_report_web_url)))
		return
	if(!bug_report_draft || bug_report_draft.result?["kind"] == "accepted")
		new_bug_report()
	INVOKE_ASYNC(bug_report_draft, TYPE_PROC_REF(/datum/bug_report, open_browser), "form")

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
		to_chat(owner, span_notice("Sign in with Discord on the browser report form and paste this one-time code under Link your game identity. It expires in ten minutes. Keep it private: [response["code"]]"))

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
		status = "Reporting bridge is not configured. Use Report in browser."
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
		status = "Reporting service timed out. Your text is preserved; retry or use Report in browser."
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
	var/list/body = action_body("save")
	body["fields"] = fields.Copy()
	body["revision"] = revision
	var/list/response = bridge_request("action", body)
	if(!response)
		return FALSE
	if(response["revisionConflict"])
		var/list/current = bridge_request("action", action_body("read"))
		if(current?["draft"])
			revision = current["draft"]["revision"]
		status = "The draft changed in another window. Your text is preserved. Review it, then submit again to save this version."
		return FALSE
	var/list/draft = response["draft"]
	if(!draft)
		status = "Context saved locally; service registration is pending."
		return FALSE
	revision = draft["revision"]
	attachment = draft["attachment"]
	return TRUE

/datum/bug_report/proc/submit_fields()
	if(busy)
		return
	busy = TRUE
	if(save_fields())
		submission_key = GUID()
		poll_submission()
	busy = FALSE
	SStgui.update_uis(src)

/datum/bug_report/proc/poll_submission()
	if(!valid_owner())
		return
	var/list/body = action_body("submit")
	body["revision"] = revision
	body["key"] = submission_key
	var/list/response = bridge_request("action", body)
	if(!response)
		return
	result = response["result"]
	if(!result)
		return
	status = result["kind"]
	if(status == "checking")
		addtimer(CALLBACK(src, PROC_REF(poll_submission)), 2 SECONDS)
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

/datum/bug_report/proc/open_browser(capability)
	if(busy)
		return
	busy = TRUE
	if(!registered)
		register_context()
	if(result?["kind"] != "accepted" && !save_fields())
		busy = FALSE
		return
	var/list/body = action_body("handoff")
	body["capability"] = capability
	var/list/response = bridge_request("action", body)
	if(valid_owner() && response?["url"])
		DIRECT_OUTPUT(owner, link(response["url"]))
	else if(valid_owner())
		DIRECT_OUTPUT(owner, link(CONFIG_GET(string/bug_report_web_url)))
	busy = FALSE
	if(capability == "attachment")
		addtimer(CALLBACK(src, PROC_REF(refresh_draft)), 5 SECONDS)
	SStgui.update_uis(src)

/datum/bug_report/proc/refresh_draft()
	if(!valid_owner() || busy)
		return
	if(result?["kind"] == "accepted")
		refresh_receipt()
		return
	var/list/response = bridge_request("action", action_body("read"))
	var/list/draft = response?["draft"]
	if(draft)
		if(draft["revision"] != revision)
			status = "The draft changed in another window. Submitting will ask you to review your text before replacing it."
		attachment = draft["attachment"]
		if(draft["intake"] == "submitted")
			refresh_receipt()
		else if(attachment?["state"] == "processing")
			addtimer(CALLBACK(src, PROC_REF(refresh_draft)), 5 SECONDS)
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

/datum/bug_report/ui_data(mob/user)
	return list("fields" = fields, "revision" = revision, "status" = status, "busy" = busy, "result" = result, "attachment" = attachment)

/datum/bug_report/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !valid_owner() || usr.client != owner || busy)
		return
	if(action == "submit" || action == "screenshot" || action == "browser")
		var/list/incoming = params["fields"]
		if(!islist(incoming))
			return
		// Never accept report IDs, context or identity from TGUI parameters.
		for(var/name in list("title", "observed", "expected", "reproduction"))
			var/value = incoming[name]
			if(!istext(value) || (action == "submit" && !length(trim(value))) || length_char(value) > (name == "title" ? 160 : 8000))
				status = "Fill each required field within its limit."
				return TRUE
		var/category = incoming["category"]
		var/severity = incoming["severity"]
		fields = list("title" = incoming["title"], "observed" = incoming["observed"], "expected" = incoming["expected"], "reproduction" = incoming["reproduction"], "category" = (category in list("Other", "UI", "Gameplay", "Crash", "Performance", "Map")) ? category : "Other", "severity" = (severity in list("unspecified", "minor", "major", "critical")) ? severity : "unspecified", "incidentAt" = null)
		if(action == "submit")
			INVOKE_ASYNC(src, PROC_REF(submit_fields))
		else if(action == "screenshot")
			INVOKE_ASYNC(src, PROC_REF(open_browser), "attachment")
		else
			INVOKE_ASYNC(src, PROC_REF(open_browser), "form")
	else if(action == "new" && result?["kind"] == "accepted")
		owner.new_bug_report()
		owner.bug_report_draft.ui_interact(owner.mob)
	else if(action == "issue")
		var/list/receipt = result?["receipt"]
		if(receipt?["issueUrl"])
			DIRECT_OUTPUT(owner, link(receipt["issueUrl"]))
	else if(action == "refresh")
		INVOKE_ASYNC(src, PROC_REF(refresh_draft))
	return TRUE
