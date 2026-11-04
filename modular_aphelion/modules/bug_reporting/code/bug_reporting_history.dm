/// The current connection's report list. Submitted reports offer their issue, never the editor.
/datum/bug_report_history
	var/client/owner
	var/refreshing = FALSE
	var/status
	COOLDOWN_DECLARE(refresh_cooldown)

/datum/bug_report_history/New(client/owner)
	src.owner = owner

/datum/bug_report_history/Destroy()
	if(owner?.bug_report_browser == src)
		owner.bug_report_browser = null
	owner = null
	return ..()

/datum/bug_report_history/ui_state(mob/user)
	return GLOB.always_state

/datum/bug_report_history/ui_status(mob/user)
	return owner && user.client == owner ? UI_INTERACTIVE : UI_CLOSE

/datum/bug_report_history/ui_close(mob/user)
	qdel(src)

/datum/bug_report_history/ui_interact(mob/user, datum/tgui/ui)
	if(user.client != owner)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		return
	ui = new(user, src, "BugReportHistory", "View recent bug reports")
	ui.set_autoupdate(FALSE)
	ui.open()
	INVOKE_ASYNC(src, PROC_REF(refresh_reports))

/// Resolves only this connection's reports; browser-supplied ids never select another player's report.
/datum/bug_report_history/proc/find_report(id)
	for(var/datum/bug_report/report as anything in owner?.bug_report_history)
		if(report.request_id == id)
			return report

/// Checking and accepted submissions cannot be reopened, including through a stale or forged action.
/datum/bug_report_history/proc/draft_for(id)
	var/datum/bug_report/report = find_report(id)
	return report && !report.busy && !report.sealed_results[report.result?["kind"]] ? report : null

/datum/bug_report_history/ui_data(mob/user)
	var/list/reports = list()
	for(var/index in LAZYLEN(owner?.bug_report_history) to 1 step -1)
		var/datum/bug_report/report = owner.bug_report_history[index]
		var/submitted = !!report.sealed_results[report.result?["kind"]]
		reports += list(list(
			"id" = report.request_id,
			"title" = report.fields["title"],
			"fieldsEpoch" = report.fields_epoch,
			"startedAt" = report.started_at,
			"submitted" = submitted,
			"checking" = report.result?["kind"] == "checking",
			"canOpen" = !submitted && !report.busy,
			"hasIssue" = !!report.issue_url(),
		))
	return list("reports" = reports, "refreshing" = refreshing, "status" = status)

/// Refreshes only submissions, without replacing the active draft or opening a submitted report.
/datum/bug_report_history/proc/refresh_reports()
	if(refreshing || !COOLDOWN_FINISHED(src, refresh_cooldown))
		return
	COOLDOWN_START(src, refresh_cooldown, 5 SECONDS)
	refreshing = TRUE
	status = null
	SStgui.update_uis(src)
	var/list/reports = owner?.bug_report_history?.Copy()
	for(var/datum/bug_report/report as anything in reports)
		if(QDELETED(src) || !owner)
			return
		if(QDELETED(report) || report.busy || report.requesting || !(report in owner.bug_report_history))
			continue
		if(report.result?["kind"] == "accepted")
			if(report.issue_url())
				continue
			report.refresh_receipt()
		else if(report.result?["kind"] == "checking")
			// Refresh is the history equivalent of the editor's Try again.
			report.polling_paused = FALSE
			report.poll_failures = 0
			report.check_submission()
		else
			continue
		if(report.unreachable || report.refused)
			status = "Some reports couldn't be refreshed. Try again in a moment."
		report.push_update()
	if(QDELETED(src))
		return
	refreshing = FALSE
	SStgui.update_uis(src)

/datum/bug_report_history/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !owner || usr.client != owner)
		return
	switch(action)
		if("refresh")
			INVOKE_ASYNC(src, PROC_REF(refresh_reports))
			return TRUE
		if("open")
			var/datum/bug_report/report = draft_for(params["id"])
			if(!report)
				return FALSE
			owner.bug_report_draft = report
			report.ui_interact(owner.mob)
			return TRUE
		if("issue")
			var/datum/bug_report/report = find_report(params["id"])
			var/url = report?.issue_url()
			if(url)
				DIRECT_OUTPUT(owner, link(url))
			return TRUE
