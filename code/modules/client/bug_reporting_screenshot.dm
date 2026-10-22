/// Raw uploads stay opaque to DreamDaemon. Only the host's bounded decoder reads pixels.
GLOBAL_VAR_INIT(bug_report_temporary_cleaned, bug_report_cleanup_temporary())

/// Different DreamDaemon processes may overlap on a persistent data root. The
/// 24-hour age floor exceeds every bounded capture/upload lifetime. Unknown-age
/// legacy files are preserved; normal request completion deletes immediately.
/proc/bug_report_cleanup_temporary(force = FALSE)
	var/static/last_sweep
	if(!force && last_sweep && world.realtime - last_sweep < 1 HOURS)
		return TRUE
	last_sweep = world.realtime
	var/root = "data/bug-report-temporary/"
	var/regex/generated = regex(@"^bug-report-([0-9]{1,20})-\{[a-fA-F0-9-]{1,100}\}\.(upload|capture|preview)$")
	for(var/name in flist(root))
		if(generated.Find(name))
			var/created_at = text2num(generated.group[1])
			if(created_at >= 0 && created_at < world.realtime - 24 HOURS)
				fdel("[root][name]")
	return TRUE

/proc/bug_report_temporary_path(kind)
	bug_report_cleanup_temporary()
	return "data/bug-report-temporary/bug-report-[num2text(world.realtime, 20)]-[GUID()].[kind]"

/proc/bug_report_image_upload_allowed(filename, bytes)
	return istext(filename) && bytes > 0 && bytes <= 10 * 1024 * 1024 && (lowertext(copytext(filename, findlasttext(filename, ".") + 1)) in list("png", "jpg", "jpeg", "webp"))

/datum/http_request/bug_report_file
	var/body_file

/datum/http_request/bug_report_file/build_options()
	return json_encode(list("body_filename" = body_file, "output_filename" = output_file, "timeout_seconds" = 30))

/datum/bug_report/proc/choose_screenshot_file()
	var/client/reporting_client = owner
	reporting_client.bug_report_upload = src
	reporting_client.bug_report_upload_until = world.time + 5 MINUTES
	var/upload = input(reporting_client, "Choose your screenshot (PNG, JPEG or WebP; maximum 10 MiB). F2 saves the map under BYOND/screenshots.", "Attach report screenshot") as null|file
	if(reporting_client?.bug_report_upload == src)
		reporting_client.bug_report_upload = null
		reporting_client.bug_report_upload_until = 0
	return upload

/datum/bug_report/proc/choose_screenshot()
	if(busy || !valid_owner() || result?["kind"] in list("accepted", "checking"))
		return
	busy = TRUE
	SStgui.update_uis(src)
	if(!registered)
		register_context()
	if(!valid_owner() || !save_fields())
		busy = FALSE
		SStgui.update_uis(src)
		return
	var/upload = choose_screenshot_file()
	// The file prompt yields. A disconnected client or another incident cannot inherit it.
	if(!upload || !valid_owner() || result?["kind"] == "accepted")
		busy = FALSE
		SStgui.update_uis(src)
		return
	var/path = bug_report_temporary_path("upload")
	if(!fcopy(upload, path))
		status = "Could not stage the screenshot. Choose it again."
		busy = FALSE
		SStgui.update_uis(src)
		return
	upload_staged_screenshot(path)

/datum/bug_report/proc/upload_staged_screenshot(path, encoding)
	if(!valid_owner() || result?["kind"] in list("accepted", "checking"))
		fdel(path)
		busy = FALSE
		return
	attachment_pending = TRUE
	pending_previous_id = attachment?["id"]
	preview = null
	preview_confirmed = FALSE
	attachment_until = world.time + 15 MINUTES
	var/list/response
	try
		response = attachment_request("upload", path, encoding = encoding)
	catch
		status = "Screenshot upload failed. Retry connection to recover its status, or choose it again."
	fdel(path)
	if(valid_owner())
		if(response?["attachment"])
			update_attachment(response["attachment"])
		else
			status = "Screenshot upload was not confirmed. Retry connection or choose it again; submission remains paused."
	busy = FALSE
	queue_attachment_refresh()
	SStgui.update_uis(src)

/// The request owns only generated paths. No user-supplied path reaches rust-g.
/datum/bug_report/proc/attachment_request(operation, upload_file, expected_id, public_consent = FALSE, encoding)
	var/bridge_url = CONFIG_GET(string/bug_report_bridge_url)
	if(bridge_url != "http://127.0.0.1:18764")
		status = "Reporting bridge is not configured. Your report is preserved."
		return
	var/datum/http_request/bug_report_file/request = new
	if(operation == "upload")
		request.body_file = upload_file
	var/route = operation == "upload" ? "attachment" : "attachment/[operation]"
	request.prepare(RUSTG_HTTP_METHOD_POST, "[bridge_url]/game/[route]", "", list(
		"Authorization" = "Bearer [CONFIG_GET(string/bug_report_bridge_token)]",
		"Content-Type" = "application/octet-stream",
		"x-report-ckey" = context["ckey"],
		"x-report-session" = session_id,
		"x-report-request" = request_id,
		"x-report-attachment" = expected_id || "",
		"x-public-consent" = public_consent ? "true" : "false",
		"x-report-encoding" = encoding || "",
	), output_file = operation == "preview" ? upload_file : null, timeout_seconds = 30)
	request.begin_async()
	// rust-g enforces the request timeout. Wait for completion before deleting its file.
	while(!request.is_complete())
		sleep(2)
	var/datum/http_response/response = request.into_response()
	if(!valid_owner())
		return
	if(response.errored || response.status_code < 200 || response.status_code >= 300)
		status = "Screenshot request failed ([response.status_code]). Retry connection or remove the screenshot."
		return
	if(operation == "preview")
		return list("ready" = TRUE)
	try
		return json_decode(response.body)
	catch
		status = "Screenshot service returned an invalid response. Retry connection."

/datum/bug_report/proc/update_attachment(list/next_attachment)
	if(next_attachment?["id"] != attachment?["id"])
		preview = null
		preview_confirmed = FALSE
	attachment = next_attachment
	if(!attachment)
		return
	if(attachment["state"] == "ready" && attachment["id"] != pending_previous_id)
		attachment_pending = FALSE
		pending_previous_id = null
		status = "Screenshot ready. Review its preview before choosing public sharing."
	else if(attachment["state"] == "failed")
		attachment_pending = TRUE
		status = "The screenshot could not be validated. Choose another image or remove it before submitting."
	else if(attachment["state"] == "processing")
		attachment_pending = TRUE
		if(!attachment_until)
			attachment_until = world.time + 15 MINUTES
		status = "Screenshot saved; validating image."

/datum/bug_report/proc/queue_attachment_refresh()
	if(!valid_owner() || result?["kind"] == "accepted")
		return
	if(attachment?["state"] == "ready" && !preview && !attachment_pending)
		INVOKE_ASYNC(src, PROC_REF(load_screenshot_preview), attachment["id"])
	if(attachment_pending && attachment?["state"] != "failed" && world.time < attachment_until)
		addtimer(CALLBACK(src, PROC_REF(refresh_draft)), 5 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE)

/datum/bug_report/proc/load_screenshot_preview(expected_id)
	if(busy || !valid_owner() || attachment?["id"] != expected_id || attachment?["state"] != "ready")
		return
	busy = TRUE
	var/name = "bug-report-[GUID()].png"
	var/path = bug_report_temporary_path("preview")
	var/list/response
	try
		response = attachment_request("preview", path, expected_id)
		if(response?["ready"] && valid_owner() && attachment?["id"] == expected_id && fexists(path))
			DIRECT_OUTPUT(owner, browse_rsc(file(path), name))
			preview = name
			preview_confirmed = FALSE
	catch
		status = "Preview unavailable. Reload the preview to try again."
	fdel(path)
	busy = FALSE
	SStgui.update_uis(src)

/datum/bug_report/proc/remove_screenshot(expected_id)
	if(busy || !valid_owner() || result?["kind"] in list("accepted", "checking") || attachment?["id"] != expected_id)
		return
	busy = TRUE
	var/list/response
	try
		if(!expected_id)
			// An upload response may have been lost before an ID was received.
			// Only an authoritative read can distinguish no image from a saved one.
			var/list/current = bridge_request("action", action_body("read"))
			var/list/draft = current?["draft"]
			if(valid_owner() && draft && draft["intake"] != "submitted")
				var/list/cloud_attachment = draft["attachment"]
				if(cloud_attachment)
					expected_id = cloud_attachment["id"]
					update_attachment(cloud_attachment)
				else
					response = list("removed" = TRUE)
		if(expected_id && valid_owner())
			response = attachment_request("remove", null, expected_id)
	catch
		status = "Screenshot removal was not confirmed. Retry connection; your image remains attached."
	if(response && valid_owner())
		attachment = null
		attachment_pending = FALSE
		pending_previous_id = null
		preview = null
		preview_confirmed = FALSE
		attachment_until = 0
		status = "Screenshot removed."
	busy = FALSE
	SStgui.update_uis(src)

/datum/bug_report/proc/screenshot_consent(expected_id, public_consent)
	if(busy || !valid_owner() || !preview_confirmed || !preview || result?["kind"] in list("accepted", "checking") || attachment?["id"] != expected_id)
		return
	busy = TRUE
	var/list/response
	try
		response = attachment_request("consent", null, expected_id, public_consent)
	catch
		status = "Sharing change was not confirmed. Retry connection to check its current state."
	if(response?["attachment"] && valid_owner())
		update_attachment(response["attachment"])
	busy = FALSE
	SStgui.update_uis(src)
