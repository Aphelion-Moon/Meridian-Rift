/// The only bridge we ever talk to. A test build defines its own fixture origin before this file
#ifndef BUG_REPORT_BRIDGE_ORIGIN
#define BUG_REPORT_BRIDGE_ORIGIN "http://127.0.0.1:18764"
#endif
/// Longest title the reporting service takes
#define BUG_REPORT_TITLE_MAX 160
/// Longest expected or reproduction text the reporting service takes
#define BUG_REPORT_TEXT_MAX 8000
/// Most numbered steps the window offers
#define BUG_REPORT_STEPS_MAX 20
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
/// Uploads of the reporter's own screenshots per ckey per hour, the service's own cap - captures don't count
#define BUG_REPORT_UPLOADS_PER_HOUR 5
/// In-game and window captures per ckey per hour, the service's own cap
#define BUG_REPORT_CAPTURES_PER_HOUR 30
/// What the sent page says when the service turns down a look at its receipt or answers one we can't read, which the next poll asks for again
#define BUG_REPORT_RECEIPT_REFUSED "Your report is sent, but the report server didn't say how it's doing. This window asks again within a minute."
/// What the sent page says when the report server doesn't answer a look at its receipt, which the next poll asks for again
#define BUG_REPORT_RECEIPT_UNREACHABLE "Your report is sent, but the report server isn't answering. This window asks again within a minute."

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
 * Counts what's left of a ckey's hourly allowance of one kind, forgetting uses over an hour old.
 *
 * Arguments:
 * * ckey - whose allowance
 * * kind - accepted, submits, drafts, uploads or captures
 */
/proc/bug_report_uses_left(ckey, kind)
	var/static/list/caps = list(
		"accepted" = BUG_REPORT_ACCEPTED_PER_HOUR,
		"submits" = BUG_REPORT_SUBMITS_PER_HOUR,
		"drafts" = BUG_REPORT_DRAFTS_PER_HOUR,
		"uploads" = BUG_REPORT_UPLOADS_PER_HOUR,
		"captures" = BUG_REPORT_CAPTURES_PER_HOUR,
	)
	var/key = "[ckey]:[kind]"
	var/list/uses = GLOB.bug_report_budgets[key]
	while(length(uses) && uses[1] <= world.time - 1 HOURS)
		uses.Cut(1, 2)
	if(uses && !length(uses))
		GLOB.bug_report_budgets -= key
	return caps[kind] - length(uses)

/**
 * Spends one of a ckey's hourly allowances, mirroring the reporting service's own caps.
 *
 * Returns 0 when there was one to spend, otherwise how long until one frees up.
 * They live for the round, so a reconnect doesn't refill them.
 * Arguments:
 * * ckey - whose allowance
 * * kind - accepted, submits, drafts, uploads or captures
 * * spend - FALSE to only check
 */
/proc/bug_report_budget(ckey, kind, spend = TRUE)
	var/key = "[ckey]:[kind]"
	if(bug_report_uses_left(ckey, kind) <= 0)
		var/list/uses = GLOB.bug_report_budgets[key]
		return uses[1] + 1 HOURS - world.time
	if(spend)
		LAZYADDASSOCLIST(GLOB.bug_report_budgets, key, world.time)
	return 0

/**
 * Spends what's left of a ckey's hourly allowance of one kind, for when the reporting service says it's all used.
 *
 * Arguments:
 * * ckey - whose allowance
 * * kind - uploads or captures
 */
/proc/bug_report_budget_fill(ckey, kind)
	while(bug_report_uses_left(ckey, kind) > 0)
		bug_report_budget(ckey, kind)

/**
 * Whether a field counts as empty, by the same rule as the reporting service.
 *
 * Only Unicode's whitespace and the zero width no-break space count as nothing, and steps that are only
 * their numbers count as nothing too. We don't use trimtext(), it also takes the zero width space.
 * Arguments:
 * * text - what the reporter wrote
 * * numbered - whether it's the steps, which arrive as numbered lines
 */
/proc/bug_report_blank(text, numbered = FALSE)
	var/static/regex/numbering = regex(@"(^|\n)[ \t]*[0-9]{1,3}\.", "g")
	// Unicode's White_Space characters, which the window's check counts, then U+FEFF, which the service's trim() takes too
	var/static/list/blank_codes = list(9, 10, 11, 12, 13, 32, 133, 160, 5760, 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8201, 8202, 8232, 8233, 8239, 8287, 12288, 65279)
	if(numbered)
		text = numbering.Replace(text, "$1")
	for(var/code in blank_codes)
		text = replacetext(text, ascii2text(code), "")
	return !length(text)

/// Opens this connection's report, starting a new one once the last was accepted
/client/proc/open_bug_report()
	if(!bug_report_draft || bug_report_draft.result?["kind"] == "accepted")
		new_bug_report()
	bug_report_draft?.ui_interact(mob)

/// Starts a new report, unless this ckey has started too many this hour
/client/proc/new_bug_report()
	var/wait = bug_report_budget(ckey, "drafts")
	if(wait)
		to_chat(src, span_warning("You've started [BUG_REPORT_DRAFTS_PER_HOUR] bug reports this hour. You can start another in [DisplayTimeText(wait)], or reopen one with Recent bug reports."))
		return FALSE
	bug_report_draft = new(src)
	LAZYADD(bug_report_history, bug_report_draft)
	if(length(bug_report_history) > BUG_REPORT_HISTORY)
		var/datum/bug_report/oldest = bug_report_history[1]
		bug_report_history.Cut(1, 2)
		qdel(oldest)
	return TRUE

GAME_VERB_DESC(/client, recent_bug_reports, "Recent bug reports", "Reopen a report you started this session", "OOC")
	var/list/choices = list()
	var/list/repeats = list()
	for(var/datum/bug_report/report as anything in bug_report_history)
		var/label = "[report.fields["title"] || "Untitled report"] (started [report.started_at])"
		// Two reports with one title in the same minute would otherwise share an entry
		repeats[label] += 1
		choices[repeats[label] > 1 ? "[label] ([repeats[label]])" : label] = report
	var/choice = input(src, "Which report?", "Recent bug reports") as null|anything in choices
	var/datum/bug_report/report = choices[choice]
	if(QDELETED(report))
		return
	bug_report_draft = report
	report.ui_interact(mob)

GAME_VERB_DESC(/client, report_upstream_issue, "Report a /tg/station bug", "Open /tg/station's GitHub form, for bugs in the base game", "OOC")
	DIRECT_OUTPUT(src, link("https://github.com/tgstation/tgstation/issues/new?template=bug_report_form.yml"))

/**
 * One bug report from one connection, from the moment its form opens to its receipt.
 *
 * The incident context is frozen in New(), before anything can yield, and only ever goes to the bridge.
 * Everything after goes through the reporting bridge on this machine, one request at a time per report.
 * The window only updates when something here changes, and we poll only while it is open and the report
 * waits on the service.
 */
/datum/bug_report
	/// The connection writing this report
	var/client/owner
	/// The connection's session id, frozen into the context
	var/session_id
	/// This report's id at the bridge
	var/request_id
	/// The round time the report was started, so Recent bug reports can tell them apart
	var/started_at
	/// What the game looked like when the report was opened, never changed after and never sent to the window
	var/list/context
	/// Whether the bridge holds our context, which every other call needs
	var/context_saved = FALSE
	/// Whether the reporting service holds our draft, which the bridge registers after it takes our context
	var/registered = FALSE
	/// The reporter's text and choices as the page last sent them - the window never asks for incidentAt
	var/list/fields = list(
		"title" = "",
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
	/// One line telling the reporter what is happening, or null with nothing to say
	var/status
	/// Whether a reporter's action is running, which holds every other action
	var/busy = FALSE
	/// Whether a bridge request for this report is in flight
	var/requesting = FALSE
	/// Whether the last bridge request went unanswered, which the window shows until one gets through
	var/unreachable = FALSE
	/// Whether the report server turned down the last bridge request, which status then explains
	var/refused = FALSE
	/// Which hourly limit holds sending, reports or sends, while its wait_time from start_time runs
	var/limit_kind
	/// When the hourly limit holding sending began, in REALTIMEOFDAY
	var/start_time = 0
	/// How long the hourly limit holds sending from start_time, in deciseconds
	var/wait_time = 0
	/// The submission's outcome - checking, needs_revision, limited, or accepted with its receipt
	var/list/result
	/// When the receipt we hold came, in REALTIMEOFDAY, which its wait to publish again counts from, or 0 when it has no wait
	var/receipt_arrival = 0
	/// The window's Try agains that have their answer, from zero each time it opens, which it waits on to say how it went
	var/answered = 0
	/// The idempotency key of the submission being checked
	var/submission_key
	/// Failed polls in a row, which pause polling at four
	var/poll_failures = 0
	/// Whether polling stopped after failures until the reporter retries
	var/polling_paused = FALSE
	/// The wait before the next background poll, growing while nothing changes
	var/poll_delay = BUG_REPORT_POLL_MIN
	/// What a report can be about, in the order the window offers them - the service's category, its words and icon
	var/static/list/kinds = list(
		list("value" = "Gameplay", "label" = "Gameplay", "icon" = "gamepad"),
		list("value" = "UI", "label" = "Windows and menus", "icon" = "window-maximize"),
		list("value" = "Map", "label" = "The map", "icon" = "map"),
		list("value" = "Performance", "label" = "Lag", "icon" = "gauge-high"),
		list("value" = "Crash", "label" = "Crash", "icon" = "burst"),
		list("value" = "Other", "label" = "Something else", "icon" = "circle-question"),
	)
	/// How much a bug gets in the way, worst first - the service's severity and its words
	var/static/list/impacts = list(
		list("value" = "critical", "label" = "It stops me playing"),
		list("value" = "major", "label" = "It gets in the way, but I can keep playing"),
		list("value" = "minor", "label" = "It's small, or it just looks wrong"),
	)
	COOLDOWN_DECLARE(refresh_cooldown)
	COOLDOWN_DECLARE(action_cooldown)

/datum/bug_report/New(client/reporting_client)
	owner = reporting_client
	owner.bug_report_session_id ||= GUID()
	session_id = owner.bug_report_session_id
	request_id = GUID()
	started_at = round_timestamp("hh:mm")
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
	refused = FALSE
	if(!bug_reports_enabled())
		status = "Bug reports aren't set up on this server right now. Your text is kept."
		return
	UNTIL(!valid_owner() || (!requesting && GLOB.bug_report_requests < BUG_REPORT_MAX_REQUESTS))
	// Another request of this report may have been turned down while we waited, and only our own answer counts
	refused = FALSE
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
		unreachable = TRUE
		status = "Couldn't reach the report server. Your text is kept. Try again in a minute."
	UNTIL(request.is_complete())
	GLOB.bug_report_requests--
	requesting = FALSE
	if(!valid_owner())
		return
	return bridge_reply(request.into_response(), output_file)

/**
 * Reads the bridge's answer to one request.
 *
 * Returns the decoded reply, TRUE for a reply saved to output_file, or null with status saying why. Only no
 * answer or a 5xx means we couldn't reach the report server. A 4xx is it turning the request down, which sets
 * refused and says why in status, or on a preview's card, except a conflict, which means the draft moved on.
 * Arguments:
 * * response - the bridge's answer
 * * output_file - the file rust-g saved the reply into, if any
 */
/datum/bug_report/proc/bridge_reply(datum/http_response/response, output_file)
	if(response.errored || response.status_code < 200 || response.status_code >= 500)
		unreachable = TRUE
		status = "Couldn't reach the report server. Your text is kept. Try again in a minute."
		return
	// Any answer means the bridge is back, so its failure line goes with it
	if(unreachable)
		unreachable = FALSE
		status = null
	var/list/data
	if(response.status_code >= 400)
		try
			data = json_decode(response.body)
		catch
			data = null
		var/error = islist(data) && istext(data["error"]) ? data["error"] : null
		if(response.status_code == 409 && error != "too_many_attachments")
			return list("revisionConflict" = TRUE)
		refused = TRUE
		// A preview, the one request whose reply goes to a file, says it didn't load on its own card
		if(output_file)
			return
		switch(error)
			// The service also counts what the reporter does outside the game, which our hourly mirror never sees
			if("upload_request_limit")
				bug_report_budget_fill(context["ckey"], "uploads")
				status = "You've reached this hour's limit on your own screenshots. Captures still work."
			if("capture_request_limit")
				bug_report_budget_fill(context["ckey"], "captures")
				status = "You've reached this hour's limit on captures. Add your own screenshot instead."
			if("too_many_attachments")
				status = "The report server already has [BUG_REPORT_MAX_PICTURES] pictures for this report. Remove one to add another."
			else
				// Every other 429, like the drafts limit or the bridge's own, lets go in a few minutes
				status = response.status_code == 429 ? "The report server is busy. Your text is kept. Try again in a few minutes." : "The report server turned that down. Your text is kept."
		return
	if(response.status_code < 300)
		if(output_file)
			return TRUE
		try
			data = json_decode(response.body)
		catch
			data = null
	if(islist(data))
		return data
	status = "Something went wrong on the report server. Your text is kept. Try again in a minute."

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
	// A bridge that answers quickly never shows it
	addtimer(CALLBACK(src, PROC_REF(show_getting_ready)), 1 SECONDS)
	var/list/response = bridge_call("context", json_encode(list("context" = context, "requestId" = request_id)), list("Content-Type" = "application/json"))
	if(!response)
		return FALSE
	context_saved = TRUE
	registered = response["status"] == "ready"
	status = registered ? null : "Waiting for the report server…"
	return TRUE

/// Says we're getting ready when the bridge takes over a second to take our context
/datum/bug_report/proc/show_getting_ready()
	if(context_saved || status)
		return
	status = "Getting ready…"
	push_update()

/// Notes that the service holds our draft, ending the wait for it
/datum/bug_report/proc/took_draft()
	if(registered)
		return
	registered = TRUE
	status = null

/// Saves the reporter's text to the draft if it changed, returning whether the saved draft now matches it
/datum/bug_report/proc/save_fields()
	if(!context_saved && !save_context())
		return FALSE
	if(remote_draft)
		status = "Pick which version to keep first."
		return FALSE
	if(!fields_dirty)
		return TRUE
	var/list/response = bridge_action("save", list("fields" = fields, "revision" = revision))
	if(response?["revisionConflict"])
		remote_draft = bridge_action("read")?["draft"]
		// The window's own notice asks which version to keep
		status = null
		return FALSE
	var/list/draft = response?["draft"]
	if(!draft)
		if(response)
			status = "Still connecting to the report server. Your text is kept."
		return FALSE
	revision = draft["revision"]
	fields_dirty = FALSE
	took_draft()
	update_pictures(draft)
	return TRUE

/**
 * Takes the page's text and choices, refusing a stale page or text past the service's limits. No network.
 *
 * Returns whether the page's fields were taken.
 * Arguments:
 * * incoming - the page's fields
 * * epoch - the fields_epoch the page's text is based on
 * * required - whether the title, steps and what should have happened must be filled, as for a submission
 */
/datum/bug_report/proc/update_local_fields(list/incoming, epoch, required = FALSE)
	var/static/list/text_limits = list(
		"title" = BUG_REPORT_TITLE_MAX,
		"expected" = BUG_REPORT_TEXT_MAX,
		"reproduction" = BUG_REPORT_TEXT_MAX,
	)
	if(result?["kind"] == "accepted" || epoch != fields_epoch || !islist(incoming))
		return FALSE
	for(var/name, limit in text_limits)
		var/value = incoming[name]
		if(!istext(value))
			return FALSE
		if(length_char(value) > limit)
			status = "Some of it is too long. Cut it down, then send it again."
			return FALSE
	// The steps arrive as numbered lines, and the window offers no more than BUG_REPORT_STEPS_MAX of them
	var/static/regex/numbering = regex(@"^[ \t]*[0-9]{1,3}\.")
	var/steps = 0
	for(var/line in splittext(incoming["reproduction"], "\n"))
		if(numbering.Find(line) && ++steps > BUG_REPORT_STEPS_MAX)
			status = "Some of it is too long. Cut it down, then send it again."
			return FALSE
	if(required)
		for(var/name in text_limits)
			if(bug_report_blank(incoming[name], numbered = (name == "reproduction")))
				status = "Some boxes are empty. Fill them in, then send it again."
				return FALSE
	var/category = "Other"
	for(var/list/kind as anything in kinds)
		if(incoming["category"] == kind["value"])
			category = kind["value"]
	var/severity = "unspecified"
	for(var/list/impact as anything in impacts)
		if(incoming["severity"] == impact["value"])
			severity = impact["value"]
	var/list/next_fields = list(
		"title" = incoming["title"],
		"expected" = incoming["expected"],
		"reproduction" = incoming["reproduction"],
		"category" = category,
		"severity" = severity,
		"incidentAt" = fields["incidentAt"],
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
	var/list/saved = draft["fields"]
	var/list/next_fields = fields.Copy()
	// Only the fields we know, so an older draft's What happened? text stays behind
	for(var/name in next_fields)
		if(!isnull(saved?[name]))
			next_fields[name] = saved[name]
	fields = next_fields
	revision = draft["revision"]
	fields_dirty = FALSE
	fields_epoch++
	remote_draft = null
	result = null
	status = "Loaded the saved version."
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
	status = "Kept yours. It's saved when you send it."
	return TRUE

/**
 * Spends one of the reporter's hourly allowances, or says how long until one frees up.
 *
 * Returns whether there was one.
 * Arguments:
 * * kind - accepted, submits, uploads or captures
 * * spend - FALSE to only check
 */
/datum/bug_report/proc/take_allowance(kind, spend = TRUE)
	var/wait = bug_report_budget(context["ckey"], kind, spend)
	if(!wait)
		return TRUE
	switch(kind)
		if("uploads")
			status = "You've uploaded [BUG_REPORT_UPLOADS_PER_HOUR] of your own screenshots this hour, which is the limit. Captures still work."
		if("captures")
			status = "You've taken [BUG_REPORT_CAPTURES_PER_HOUR] captures this hour, which is the limit. You can take another in [DisplayTimeText(wait)]."
		else
			hold_sending(kind == "accepted" ? "reports" : "sends", wait)
	return FALSE

/**
 * Holds sending under an hourly limit, which the window shows with the time it lets go.
 *
 * Arguments:
 * * kind - reports for accepted reports, sends for submissions
 * * wait - deciseconds until it lets go
 */
/datum/bug_report/proc/hold_sending(kind, wait)
	limit_kind = kind
	// We keep them apart, since a time of day near a million deciseconds plus the wait rounds in DM's floats and could outlast it
	start_time = REALTIMEOFDAY
	wait_time = wait
	// The window's notice says it all
	status = null

/// The hourly limit holding sending as the window takes it, with the wait in ms since DM can't hold a Unix ms time
/datum/bug_report/proc/limit_data()
	var/wait = wait_time - (REALTIMEOFDAY - start_time)
	if(!limit_kind || wait <= 0)
		return null
	return list("kind" = limit_kind, "retryIn" = wait * 100)

/// Saves and submits the report, then checks it until the service answers
/datum/bug_report/proc/submit_fields()
	if(busy)
		return
	if(!take_allowance("accepted", spend = FALSE))
		return finish_action()
	busy = TRUE
	status = null
	push_update()
	if(save_fields())
		if(!pictures_ready())
			status = "Wait for the picture to finish, or remove it."
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
	var/list/response = bridge_action("submit", list("revision" = revision, "key" = key, "attachments" = attachments_wire()))
	// An edit, a new submission or an acceptance while we waited makes this answer stale
	if(key != submission_key || result?["kind"] == "accepted")
		return
	if(!response)
		// Asking again would only be turned down again, so the check stops and the status says why
		if(refused)
			submission_key = null
			result = null
			return
		poll_failed()
		return
	poll_failures = 0
	// The service takes a submission only when it names exactly the draft's pictures, so we catch up and stop
	if(response["revisionConflict"])
		submission_key = null
		result = null
		var/list/draft = bridge_action("read")?["draft"]
		if(draft)
			update_pictures(draft)
			remove_unclaimed(draft)
		status = "Something changed while it was sending. Check your report, then send it again."
		return
	var/list/next_result = response["result"]
	if(!islist(next_result))
		return
	drop_unix_times(next_result)
	if(next_result["kind"] != result?["kind"])
		poll_delay = BUG_REPORT_POLL_MIN
	result = next_result
	switch(result["kind"])
		if("accepted")
			bug_report_budget(context["ckey"], "accepted")
			note_retry()
		if("limited")
			// The service's own hourly limits, which ours mirror, so its wait arrives as ms from now
			var/retry_in = result["retryIn"]
			if(isnum(retry_in) && retry_in > 0)
				hold_sending(result["reason"] == "admission" ? "reports" : "sends", retry_in / 100)

/// Fetches the accepted report's receipt, which gains its issue link once published
/datum/bug_report/proc/refresh_receipt()
	var/list/response = bridge_action("receipt")
	if(!response)
		// The sent page's report is in, so a failed look only means its news waits for the next poll, and a published one has nothing left to wait for
		// A draft read that found the report submitted is still on the unsent page, where nothing polls, so the read's own line stays
		if(result?["kind"] == "accepted")
			status = result["receipt"]?["issueUrl"] ? null : (unreachable ? BUG_REPORT_RECEIPT_UNREACHABLE : BUG_REPORT_RECEIPT_REFUSED)
		poll_failed()
		return
	poll_failures = 0
	// This answer is the news the refusal held back
	if(status == BUG_REPORT_RECEIPT_REFUSED)
		status = null
	if(islist(response["receipt"]))
		// A line from the unsent page, like a look turned down there, doesn't belong under the receipt that turns it sent
		if(result?["kind"] != "accepted")
			status = null
		result = drop_unix_times(list("kind" = "accepted", "receipt" = response["receipt"]))
		note_retry()

/**
 * Drops the service's Unix ms times from its answer, keeping the waits beside them.
 *
 * DM can't hold a Unix ms time exactly, and the window only reads the waits, which we count from now.
 * Returns the answer.
 * Arguments:
 * * answer - a submission's result or an accepted report's
 */
/datum/bug_report/proc/drop_unix_times(list/answer)
	answer -= "retryAt"
	var/list/receipt = answer["receipt"]
	if(islist(receipt))
		receipt -= "nextAttemptAt"
	return answer

/// Notes when the receipt came, since the wait to publish again it sends is only true the moment it answers
/datum/bug_report/proc/note_retry()
	receipt_arrival = isnum(result["receipt"]?["nextAttemptIn"]) ? REALTIMEOFDAY : 0

/// The submission's outcome as the window takes it, with the receipt's wait counted from now
/datum/bug_report/proc/result_data()
	if(!receipt_arrival || !result?["receipt"])
		return result
	var/list/receipt = result["receipt"].Copy()
	receipt["nextAttemptIn"] = max(receipt["nextAttemptIn"] - (REALTIMEOFDAY - receipt_arrival) * 100, 0)
	var/list/sent = result.Copy()
	sent["receipt"] = receipt
	return sent

/// Reads the saved draft and its pictures, keeping unsaved text when the saved draft moved on
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
	took_draft()
	if(draft["revision"] != revision)
		if(fields_dirty)
			remote_draft = draft
			// The window's own notice asks which version to keep
			status = null
		else
			adopt_draft(draft)
	update_pictures(draft)
	if(draft["intake"] == "submitted")
		refresh_receipt()

/// Counts a failed poll, pausing polling after four in a row until the reporter retries - one turned down still got its answer, whose status says why
/datum/bug_report/proc/poll_failed()
	// A sent report's page has no Try again to start it up again, so its polls back off to once a minute and never pause
	if(refused || result?["kind"] == "accepted")
		poll_failures = 0
		return
	if(++poll_failures > 3)
		polling_paused = TRUE
		status = "Lost touch with the report server while it was checking. Your text is kept."

/**
 * Reads whatever this report waits on - its new context, its submission check, its receipt, or its draft and pictures.
 *
 * Arguments:
 * * asked - whether the reporter asked with Try again, whose answer the window waits on
 */
/datum/bug_report/proc/refresh(asked = FALSE)
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
	// In the same update as the status the read found, so the window says how its Try again went
	if(asked)
		answered++
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
	for(var/datum/bug_report_picture/picture as anything in pictures)
		if(!picture.pending && picture.image_state == "processing" && world.time < picture.check_until)
			return TRUE
	return FALSE

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
 * * extra - keys only sent on request
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
	ui = new(user, src, "BugReport", "Report a bug")
	answered = 0
	// Every change here pushes its own update, so an open window costs nothing while it sits there
	ui.set_autoupdate(FALSE)
	ui.open()
	poll_delay = BUG_REPORT_POLL_MIN
	if(COOLDOWN_FINISHED(src, refresh_cooldown))
		COOLDOWN_START(src, refresh_cooldown, 5 SECONDS)
		INVOKE_ASYNC(src, PROC_REF(refresh))

/datum/bug_report/ui_static_data(mob/user)
	var/static/list/limits = list(
		"title" = BUG_REPORT_TITLE_MAX,
		"text" = BUG_REPORT_TEXT_MAX,
		"steps" = BUG_REPORT_STEPS_MAX,
		"reports" = BUG_REPORT_ACCEPTED_PER_HOUR,
		"sends" = BUG_REPORT_SUBMITS_PER_HOUR,
		"uploads" = BUG_REPORT_UPLOADS_PER_HOUR,
	)
	var/list/page_fields = fields.Copy()
	page_fields -= "incidentAt"
	// No context here, the round, map, build and ids only ever go to the bridge
	return list(
		"reportId" = request_id,
		"enabled" = bug_reports_enabled(),
		"fields" = page_fields,
		"fieldsEpoch" = fields_epoch,
		"limits" = limits,
		"maxPictures" = BUG_REPORT_MAX_PICTURES,
		"kinds" = kinds,
		"impacts" = impacts,
	)

/datum/bug_report/ui_data(mob/user)
	var/list/picture_data
	for(var/datum/bug_report_picture/picture as anything in pictures)
		LAZYADD(picture_data, list(picture.window_data()))
	return list(
		"status" = status,
		"busy" = busy,
		"result" = result_data(),
		"conflict" = !!remote_draft,
		"pollingPaused" = polling_paused,
		"unreachable" = unreachable,
		"refreshAnswered" = answered,
		"limit" = limit_data(),
		"pictures" = picture_data,
		"uploadsLeft" = bug_report_uses_left(context["ckey"], "uploads"),
		"captureTargets" = capture_targets(),
	)

/datum/bug_report/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !valid_owner() || usr.client != owner)
		return
	// Removing a picture that's waiting on its window only ends that capture, which is the action keeping us busy
	if(action == "remove_screenshot" && capture_picture && capture_picture == find_picture(params["pictureId"]))
		cancel_ui_capture()
		return TRUE
	if(action == "refresh")
		// Every Try again gets its answer, one we drop too, so the window never waits on it for good
		if(busy || !COOLDOWN_FINISHED(src, refresh_cooldown))
			answered++
			return TRUE
		COOLDOWN_START(src, refresh_cooldown, 5 SECONDS)
		poll_failures = 0
		polling_paused = FALSE
		poll_delay = BUG_REPORT_POLL_MIN
		INVOKE_ASYNC(src, PROC_REF(refresh), TRUE)
		return TRUE
	if(busy)
		return
	switch(action)
		if("submit", "screenshot", "capture_ui", "capture_view", "keep")
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
					INVOKE_ASYNC(src, PROC_REF(choose_screenshot), params["replace"])
				if("capture_ui")
					INVOKE_ASYNC(src, PROC_REF(begin_ui_capture), params["windowId"], params["replace"])
				if("capture_view")
					INVOKE_ASYNC(src, PROC_REF(begin_view_capture), params["replace"])
			return TRUE
		if("reload")
			return resolve_draft(FALSE)
		if("remove_screenshot", "screenshot_consent")
			if(!COOLDOWN_FINISHED(src, action_cooldown))
				return
			COOLDOWN_START(src, action_cooldown, 1 SECONDS)
			if(action == "remove_screenshot")
				INVOKE_ASYNC(src, PROC_REF(remove_picture), params["pictureId"])
			else
				INVOKE_ASYNC(src, PROC_REF(picture_consent), params["pictureId"], !!params["publicConsent"])
			return TRUE
		if("preview")
			send_preview(params["pictureId"])
		if("preview_loaded")
			var/datum/bug_report_picture/picture = find_picture(params["pictureId"])
			if(picture && !picture.pending && picture.image_state == "ready" && params["take"] == picture.take)
				picture.preview_seen = TRUE
				return TRUE
		if("targets")
			ui.send_update(list("captureTargets" = capture_targets()))
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
#undef BUG_REPORT_STEPS_MAX
#undef BUG_REPORT_HISTORY
#undef BUG_REPORT_MAX_REQUESTS
#undef BUG_REPORT_POLL_MIN
#undef BUG_REPORT_POLL_MAX
#undef BUG_REPORT_ACCEPTED_PER_HOUR
#undef BUG_REPORT_SUBMITS_PER_HOUR
#undef BUG_REPORT_DRAFTS_PER_HOUR
#undef BUG_REPORT_UPLOADS_PER_HOUR
#undef BUG_REPORT_CAPTURES_PER_HOUR
#undef BUG_REPORT_RECEIPT_REFUSED
#undef BUG_REPORT_RECEIPT_UNREACHABLE
