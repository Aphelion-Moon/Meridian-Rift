/// Where staged screenshot files wait for their upload
#define BUG_REPORT_TEMPORARY "data/bug-report-temporary/"

/**
 * Removes staged screenshot files a day old or more, at most once an hour.
 *
 * DreamDaemon processes can overlap on one data folder, and a day is longer than any capture or upload
 * lives, so only files that old go. A file we can't date stays for an operator to look at. Finished
 * requests delete their own files at once.
 * Arguments:
 * * force - sweep even if we swept within the hour
 */
/proc/bug_report_cleanup_temporary(force = FALSE)
	var/static/last_sweep
	if(!force && last_sweep && world.realtime - last_sweep < 1 HOURS)
		return
	last_sweep = world.realtime
	var/static/regex/generated = regex(@"^bug-report-([0-9]{1,20})-\{[a-fA-F0-9-]{1,100}\}\.(upload|capture|preview)$")
	for(var/name in flist(BUG_REPORT_TEMPORARY))
		if(generated.Find(name))
			var/created_at = text2num(generated.group[1])
			if(created_at >= 0 && created_at < world.realtime - 24 HOURS)
				fdel("[BUG_REPORT_TEMPORARY][name]")

/// A fresh generated path for a staged screenshot file, sweeping old ones now and then
/proc/bug_report_temporary_path(kind)
	bug_report_cleanup_temporary()
	return "[BUG_REPORT_TEMPORARY]bug-report-[num2text(world.realtime, 20)]-[GUID()].[kind]"

/// Whether a file name is one of the image types the reporting service decodes
/proc/bug_report_image_name(filename)
	var/static/list/extensions = list("png" = TRUE, "jpg" = TRUE, "jpeg" = TRUE, "webp" = TRUE)
	return istext(filename) && extensions[LOWER_TEXT(copytext(filename, findlasttext(filename, ".") + 1))]

/datum/bug_report
	/// The service's view of the attached image - id, state and publicConsent
	var/list/attachment
	/// Whether an image is on its way, which holds submission
	var/attachment_pending = FALSE
	/// When we stop waiting on a pending image
	var/attachment_until = 0
	/// The attachment an upload is replacing, ignored until the new one shows up
	var/pending_previous_id
	/// The attachment our preview belongs to
	var/preview_id
	/// The private preview as a data URL, kept only while this is the connection's report
	var/preview_src
	/// Whether the page showed the reporter this attachment's preview, which public consent needs
	var/preview_confirmed = FALSE
	/// Until when BYOND's file prompt may upload one image past the usual upload limit
	var/upload_until = 0
	COOLDOWN_DECLARE(preview_cooldown)

/// Lets the reporter pick a screenshot with BYOND's file prompt, then uploads it
/datum/bug_report/proc/choose_screenshot()
	if(busy || !valid_owner() || (result?["kind"] in list("accepted", "checking")))
		return
	if(!take_allowance("uploads", spend = FALSE))
		push_update()
		return
	busy = TRUE
	push_update()
	var/upload = save_fields() && prompt_screenshot()
	// The prompt yields, so a disconnected client or another report can't inherit it
	if(!upload || !valid_owner() || result?["kind"] == "accepted")
		busy = FALSE
		push_update()
		return
	var/path = bug_report_temporary_path("upload")
	if(!fcopy(upload, path))
		status = "Could not stage the screenshot. Choose it again."
		busy = FALSE
		push_update()
		return
	upload_staged_screenshot(path)

/// Opens BYOND's file prompt with its one-image upload allowance, returning the chosen file
/datum/bug_report/proc/prompt_screenshot()
	upload_until = world.time + 5 MINUTES
	. = input(owner, "Choose your screenshot (PNG, JPEG or WebP; maximum 10 MiB). F2 saves the map under BYOND/screenshots.", "Attach report screenshot") as null|file
	upload_until = 0

/**
 * Uploads a staged image to the bridge and deletes the file, whatever happens.
 *
 * Arguments:
 * * path - the generated file holding the image, or a capture's base64
 * * encoding - base64 for a capture, null for an image file
 */
/datum/bug_report/proc/upload_staged_screenshot(path, encoding)
	if(!valid_owner() || (result?["kind"] in list("accepted", "checking")) || !take_allowance("uploads"))
		fdel(path)
		busy = FALSE
		push_update()
		return
	busy = TRUE
	attachment_pending = TRUE
	pending_previous_id = attachment?["id"]
	forget_preview()
	attachment_until = world.time + 15 MINUTES
	var/list/response = attachment_call("upload", body_file = path, encoding = encoding)
	fdel(path)
	if(response?["attachment"])
		update_attachment(response["attachment"])
	else
		status = "Screenshot upload was not confirmed. Retry connection or choose it again; submission remains paused."
	busy = FALSE
	push_update()
	schedule_poll(restart = TRUE)

/**
 * Runs one attachment operation at the bridge.
 *
 * The request only ever names files we generated, never a path from the reporter.
 * Arguments:
 * * operation - upload, preview, remove or consent
 * * attachment_id - the attachment it acts on, which the bridge checks against the draft's
 * * body_file - the staged image an upload sends
 * * output_file - where a preview is saved
 * * public_consent - for consent, whether the image may go public with the issue
 * * encoding - base64 when an upload's file holds a capture's base64
 */
/datum/bug_report/proc/attachment_call(operation, attachment_id, body_file, output_file, public_consent = FALSE, encoding)
	return bridge_call(operation == "upload" ? "attachment" : "attachment/[operation]", "", list(
		"Content-Type" = "application/octet-stream",
		"x-report-ckey" = context["ckey"],
		"x-report-session" = session_id,
		"x-report-request" = request_id,
		"x-report-attachment" = attachment_id || "",
		"x-public-consent" = public_consent ? "true" : "false",
		"x-report-encoding" = encoding || "",
	), body_file, output_file, 30)

/// Takes the service's view of our attachment and moves the screenshot steps along with it
/datum/bug_report/proc/update_attachment(list/next_attachment)
	if(next_attachment?["id"] != attachment?["id"])
		forget_preview()
	attachment = next_attachment
	switch(attachment?["state"])
		if("ready")
			if(attachment["id"] != pending_previous_id)
				attachment_pending = FALSE
				pending_previous_id = null
				status = "Screenshot ready. Review its preview before choosing public sharing."
		if("failed")
			attachment_pending = TRUE
			status = "The screenshot could not be validated. Choose another image or remove it before submitting."
		if("processing")
			attachment_pending = TRUE
			attachment_until ||= world.time + 15 MINUTES
			status = "Screenshot saved; validating image."

/// Drops our copy of the preview, so only the report being written holds one
/datum/bug_report/proc/forget_preview()
	preview_id = null
	preview_src = null
	preview_confirmed = FALSE

/**
 * Answers the page asking for the attachment's preview.
 *
 * We send it as a data URL in a partial update, fetching it from the bridge only when we don't hold it.
 * Arguments:
 * * attachment_id - the attachment the page wants to show
 * * reload - fetch it again even if we hold it
 */
/datum/bug_report/proc/send_preview(attachment_id, reload)
	if(!attachment_id || attachment_id != attachment?["id"] || attachment["state"] != "ready")
		return
	if(preview_id == attachment_id && !reload)
		send_partial(list("preview" = list("id" = preview_id, "src" = preview_src)))
		return
	if(busy || !COOLDOWN_FINISHED(src, preview_cooldown))
		return
	COOLDOWN_START(src, preview_cooldown, 10 SECONDS)
	INVOKE_ASYNC(src, PROC_REF(load_preview), attachment_id)

/// Fetches the private preview PNG into a data URL - never browse_rsc, which keeps every image in the player's cache for good
/datum/bug_report/proc/load_preview(attachment_id)
	if(busy)
		return
	busy = TRUE
	push_update()
	var/path = bug_report_temporary_path("preview")
	if(attachment_call("preview", attachment_id, output_file = path) && attachment?["id"] == attachment_id && fexists(path))
		preview_id = attachment_id
		preview_src = "data:image/png;base64,[rustg_hash_file(RUSTG_HASH_BASE64, path)]"
		preview_confirmed = FALSE
	else if(valid_owner())
		status = "Preview unavailable. Reload the preview to try again."
	fdel(path)
	busy = FALSE
	push_update(preview_id == attachment_id ? list("preview" = list("id" = preview_id, "src" = preview_src)) : null)

/// Removes the attachment, asking the service first when an upload's reply was lost
/datum/bug_report/proc/remove_screenshot(expected_id)
	if(busy || !valid_owner() || (result?["kind"] in list("accepted", "checking")) || attachment?["id"] != expected_id)
		return
	busy = TRUE
	push_update()
	var/removed = FALSE
	if(!expected_id)
		// A lost upload reply leaves us without an id, and only the saved draft can tell no image from one we never heard of
		var/list/draft = bridge_action("read")?["draft"]
		if(draft && draft["intake"] != "submitted")
			var/list/saved = draft["attachment"]
			if(saved)
				expected_id = saved["id"]
				update_attachment(saved)
			else
				removed = TRUE
	if(expected_id)
		removed = !!attachment_call("remove", expected_id)
	if(removed)
		attachment = null
		attachment_pending = FALSE
		pending_previous_id = null
		attachment_until = 0
		forget_preview()
		status = "Screenshot removed."
	else
		status = "Screenshot removal was not confirmed. Retry connection; your image remains attached."
	busy = FALSE
	push_update()

/// Sets whether the attachment may go public with the issue, which needs its preview shown first
/datum/bug_report/proc/screenshot_consent(expected_id, public_consent)
	if(busy || !valid_owner() || !preview_confirmed || preview_id != expected_id || (result?["kind"] in list("accepted", "checking")) || attachment?["id"] != expected_id)
		return
	busy = TRUE
	push_update()
	var/list/response = attachment_call("consent", expected_id, public_consent = public_consent)
	if(response?["attachment"])
		update_attachment(response["attachment"])
	else
		status = "Sharing change was not confirmed. Retry connection to check its current state."
	busy = FALSE
	push_update()

#undef BUG_REPORT_TEMPORARY
