/// Where staged screenshot files wait for their upload
#define BUG_REPORT_TEMPORARY "data/bug-report-temporary/"
/// How long we keep polling for the service's check of a picture
#define BUG_REPORT_CHECK_WAIT (15 MINUTES)

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
	var/static/list/extensions = list("png" = TRUE, "jpg" = TRUE, "jpeg" = TRUE, "webp" = TRUE, "gif" = TRUE)
	return istext(filename) && extensions[LOWER_TEXT(copytext(filename, findlasttext(filename, ".") + 1))]

/**
 * One picture on a report - the in-game capture, a capture of one of the reporter's windows, or their own file.
 *
 * Its id stays the same through retakes, so the window keeps its card, while take counts the images.
 * The service holds the image itself, we only keep what the window shows about it.
 */
/datum/bug_report_picture
	/// The window's id for this picture, the same through retakes
	var/id
	/// Where it comes from - view, window or file
	var/source
	/// The captured window's title, for a window capture
	var/title
	/// Which image this is, counting retakes, so the window never shows the last one's preview
	var/take = 0
	/// When the current image was taken, in REALTIMEOFDAY
	var/taken_at
	/// What's happening to a new image the service doesn't have yet - rendering, waiting or uploading
	var/pending
	/// The service's state for the image it holds - processing, ready or failed
	var/image_state
	/// Why the picture failed, for the window's words - nothing, render, invalid or unconfirmed
	var/reason
	/// The service's id for the image it holds
	var/attachment_id
	/// Whether the reporter lets the image go public with the issue
	var/public_consent = FALSE
	/// Whether the window showed the reporter this image, which public sharing needs
	var/preview_seen = FALSE
	/// When we stop polling for the service's check of the image
	var/check_until = 0
	COOLDOWN_DECLARE(preview_cooldown)

/datum/bug_report_picture/New(id, source)
	src.id = id
	src.source = source
	taken_at = REALTIMEOFDAY

/// The picture as the window sees it, with how long ago it was taken in ms
/datum/bug_report_picture/proc/window_data()
	return list(
		"id" = id,
		"source" = source,
		"title" = title,
		"take" = take,
		"takenAgo" = (REALTIMEOFDAY - taken_at) * 100,
		"state" = pending || image_state || "failed",
		"reason" = reason,
		"publicConsent" = public_consent,
		"previewSeen" = preview_seen,
	)

/// What the window's card for this picture is made from - its age goes by when it was taken, which only a new take moves
/datum/bug_report_picture/proc/card_source()
	return "[id] [take] [source] [pending || image_state || "failed"] [reason] [public_consent] [preview_seen] [json_encode(title)]"

/// Takes the service's view of the image, returning whether it just became ready
/datum/bug_report_picture/proc/update_attachment(list/attachment)
	var/was_ready = image_state == "ready"
	attachment_id = attachment["id"]
	image_state = attachment["state"]
	public_consent = !!attachment["publicConsent"]
	reason = image_state == "failed" ? "invalid" : null
	if(image_state == "processing")
		check_until ||= world.time + BUG_REPORT_CHECK_WAIT
	return !was_ready && image_state == "ready"

/// Whether the service may hold an image this picture sent under an id we never heard, as a lost upload reply leaves it
/datum/bug_report_picture/proc/image_unclaimed()
	return take && !attachment_id

/// Forgets the image the service held, so the picture waits on a new one
/datum/bug_report_picture/proc/forget_image()
	attachment_id = null
	image_state = null
	public_consent = FALSE
	preview_seen = FALSE
	check_until = 0

/datum/bug_report
	/// The report's pictures in the order they were added, or null with none
	var/list/pictures
	/// Pictures made for this report, which numbers the next one's id
	var/pictures_made = 0
	/// Until when BYOND's file prompt may upload one image past the usual upload limit
	var/upload_until = 0

/// Finds one of the report's pictures by the window's id for it
/datum/bug_report/proc/find_picture(id)
	for(var/datum/bug_report_picture/picture as anything in pictures)
		if(picture.id == id)
			return picture

/**
 * Gets the picture a capture or upload is for - the one it retakes, or a new one if the report has room.
 *
 * Returns null when there's no such picture to retake or no room, saying so when the reporter can do
 * something about it. A new picture joins the report once its action really starts.
 * Arguments:
 * * replace - the id of the picture to retake, or null for a new one
 * * source - where the new image comes from, which a retake keeps
 */
/datum/bug_report/proc/picture_for(replace, source)
	if(!isnull(replace))
		var/datum/bug_report_picture/picture = find_picture(replace)
		if(picture?.source != source || picture.pending)
			return null
		return picture
	if(LAZYLEN(pictures) >= BUG_REPORT_MAX_PICTURES)
		status = "That's [BUG_REPORT_MAX_PICTURES] pictures, the most a report takes. Remove one to add another."
		return null
	return new /datum/bug_report_picture(++pictures_made, source)

/**
 * Ends a picture's new image before the service got it.
 *
 * A retake goes back to the image it had. A new picture shows why it failed, or goes when there's nothing to show.
 * Arguments:
 * * picture - the picture whose new image ended
 * * why - nothing or render for a render that didn't work, null to drop a new picture
 */
/datum/bug_report/proc/end_new_image(datum/bug_report_picture/picture, why)
	picture.pending = null
	if(picture.attachment_id)
		return
	if(why)
		picture.reason = why
	else
		LAZYREMOVE(pictures, picture)

/// Whether every picture's image is checked and ready to go with the report
/datum/bug_report/proc/pictures_ready()
	for(var/datum/bug_report_picture/picture as anything in pictures)
		if(picture.pending || picture.image_state != "ready")
			return FALSE
	return TRUE

/// The report's pictures as a submission names them, each image's id and whether it may go public
/datum/bug_report/proc/attachments_wire()
	// An empty list rather than null, the service reads [] as a report without pictures
	var/list/wire = list()
	for(var/datum/bug_report_picture/picture as anything in pictures)
		wire += list(list("id" = picture.attachment_id, "public" = picture.public_consent ? 1 : 0))
	return wire

/**
 * Lets the reporter pick a screenshot with BYOND's file prompt, then uploads it.
 *
 * Arguments:
 * * replace - the id of the picture it replaces, or null for a new one
 */
/datum/bug_report/proc/choose_screenshot(replace)
	if(busy || !valid_owner() || sealed_results[result?["kind"]])
		return
	if(!take_allowance("uploads", spend = FALSE))
		return finish_action()
	var/datum/bug_report_picture/picture = picture_for(replace, "file")
	if(!picture)
		return finish_action()
	busy = TRUE
	push_update()
	var/upload = save_fields() && prompt_screenshot()
	// The file is already on the server once the prompt gives it back, so it counts even if the reporter moved on
	if(upload && !take_allowance("uploads"))
		return finish_action()
	// The prompt yields, so a disconnected client or another report can't inherit it
	if(!upload || !valid_owner() || result?["kind"] == "accepted")
		return finish_action()
	var/path = bug_report_temporary_path("upload")
	if(!fcopy(upload, path))
		return finish_action("That picture couldn't be saved. Pick it again.")
	LAZYOR(pictures, picture)
	upload_picture(picture, path, spent = TRUE)

/// Opens BYOND's file prompt with its one-image upload allowance, returning the chosen file
/datum/bug_report/proc/prompt_screenshot()
	upload_until = world.time + 5 MINUTES
	. = input(owner, "A PNG, JPEG, WebP or GIF, up to 10 MB", "Add your own screenshot") as null|file
	upload_until = 0

/**
 * Uploads a picture's staged image to the bridge and deletes the file, whatever happens.
 *
 * A retake gives back the picture's last image first, or one a lost reply may have left with the service,
 * so the report never holds more than the service takes. The reporter's own files spend the hourly upload
 * allowance, captures the bigger capture one.
 * Arguments:
 * * picture - the picture the image is for, already on the report
 * * path - the generated file holding the image, or a capture's base64
 * * encoding - base64 for a capture, null for an image file
 * * spent - whether its allowance was spent already, as an in-game capture's is when its render starts and a file's when the prompt gives it back
 */
/datum/bug_report/proc/upload_picture(datum/bug_report_picture/picture, path, encoding, spent = FALSE)
	if(!valid_owner() || sealed_results[result?["kind"]] || !(picture in pictures) || (!spent && !take_allowance(picture.source == "file" ? "uploads" : "captures")))
		fdel(path)
		end_new_image(picture)
		return finish_action()
	var/reason = picture.reason
	busy = TRUE
	picture.pending = "uploading"
	picture.reason = null
	push_update()
	if(picture.attachment_id ? !attachment_call("remove", picture.attachment_id) : (picture.image_unclaimed() && !remove_unclaimed()))
		fdel(path)
		picture.pending = null
		picture.reason = reason
		return finish_action(refused ? null : "Couldn't remove the picture, so it's still attached. Try again.")
	picture.forget_image()
	picture.take++
	picture.taken_at = REALTIMEOFDAY
	var/list/response = attachment_call("upload", body_file = path, encoding = encoding, source = picture.source)
	fdel(path)
	picture.pending = null
	if(response?["attachment"])
		if(picture.update_attachment(response["attachment"]))
			status = "Picture added"
	else if(refused)
		// The service kept nothing it turned down, and the status says why
		end_new_image(picture)
	else
		picture.reason = "unconfirmed"
		status = "Couldn't confirm the picture was added. Try again, or pick it again."
	finish_action()
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
 * * source - for an upload, where the image came from - view, window or file
 * * wanted_type - for a preview, the image type we'd rather have, which a bridge that can't make it ignores
 */
/datum/bug_report/proc/attachment_call(operation, attachment_id, body_file, output_file, public_consent = FALSE, encoding, source, wanted_type)
	var/list/headers = list(
		"Content-Type" = "application/octet-stream",
		"x-report-ckey" = context["ckey"],
		"x-report-session" = session_id,
		"x-report-request" = request_id,
		"x-report-attachment" = attachment_id || "",
		"x-public-consent" = public_consent ? "true" : "false",
		"x-report-encoding" = encoding || "",
		"x-report-source" = source || "",
	)
	if(wanted_type)
		headers["Accept"] = wanted_type
	return bridge_call(operation == "upload" ? "attachment" : "attachment/[operation]", "", headers, body_file, output_file, 30)

/// The service's pictures in a saved draft, from its list or from an older bridge's one attachment
/datum/bug_report/proc/draft_attachments(list/draft)
	var/list/attachments = draft["attachments"]
	if(islist(attachments))
		return attachments
	return draft["attachment"] ? list(draft["attachment"]) : null

/**
 * Takes the service's view of the draft's pictures, so their checks and sharing catch up.
 *
 * An image the service holds that we never heard back about goes to a picture whose upload went
 * unconfirmed. A picture whose image the service no longer holds says so.
 * Arguments:
 * * draft - the saved draft
 */
/datum/bug_report/proc/update_pictures(list/draft)
	var/list/held = list()
	for(var/list/attachment in draft_attachments(draft))
		if(istext(attachment["id"]))
			held[attachment["id"]] = attachment
	var/list/unclaimed = held.Copy()
	for(var/datum/bug_report_picture/picture as anything in pictures)
		if(picture.attachment_id)
			unclaimed -= picture.attachment_id
	for(var/datum/bug_report_picture/picture as anything in pictures)
		if(picture.pending)
			continue
		var/list/attachment = picture.attachment_id && held[picture.attachment_id]
		if(!picture.attachment_id && picture.reason == "unconfirmed" && length(unclaimed))
			attachment = unclaimed[unclaimed[1]]
			unclaimed.Cut(1, 2)
		if(attachment)
			if(picture.update_attachment(attachment))
				status = "Picture added"
		else if(picture.attachment_id)
			picture.forget_image()
			picture.reason = "unconfirmed"

/**
 * Removes a picture, giving back its image first.
 *
 * Arguments:
 * * picture_id - the window's id for the picture
 */
/datum/bug_report/proc/remove_picture(picture_id)
	var/datum/bug_report_picture/picture = find_picture(picture_id)
	if(busy || !picture || picture.pending || !valid_owner() || sealed_results[result?["kind"]])
		return
	busy = TRUE
	push_update()
	var/removed = TRUE
	if(picture.attachment_id)
		removed = !!attachment_call("remove", picture.attachment_id)
	else if(picture.image_unclaimed())
		removed = remove_unclaimed()
	if(removed)
		LAZYREMOVE(pictures, picture)
		status = "Picture removed"
	else if(!refused)
		status = "Couldn't remove the picture, so it's still attached. Try again."
	finish_action()

/**
 * Gives back every image the service holds that none of our pictures claims, returning whether they all went.
 *
 * Arguments:
 * * draft - the saved draft as just read, or null to read it now
 */
/datum/bug_report/proc/remove_unclaimed(list/draft)
	// A lost upload reply leaves us without an id, and only the saved draft can tell no image from one we never heard of
	draft ||= bridge_action("read")?["draft"]
	if(!draft || draft["intake"] == "submitted")
		return FALSE
	for(var/list/attachment in draft_attachments(draft))
		var/claimed = FALSE
		for(var/datum/bug_report_picture/picture as anything in pictures)
			if(picture.attachment_id == attachment["id"])
				claimed = TRUE
				break
		if(!claimed && !attachment_call("remove", attachment["id"]))
			return FALSE
	return TRUE

/**
 * Sets whether a picture may go public with the issue, which needs its preview shown first.
 *
 * Arguments:
 * * picture_id - the window's id for the picture
 * * public_consent - whether it may go public
 */
/datum/bug_report/proc/picture_consent(picture_id, public_consent)
	var/datum/bug_report_picture/picture = find_picture(picture_id)
	if(busy || !picture?.preview_seen || picture.pending || picture.image_state != "ready" || !valid_owner() || sealed_results[result?["kind"]])
		return
	busy = TRUE
	push_update()
	var/list/response = attachment_call("consent", picture.attachment_id, public_consent = public_consent)
	if(response?["attachment"]?["id"] == picture.attachment_id)
		picture.update_attachment(response["attachment"])
	else if(!refused)
		status = "Couldn't change who can see the picture. Try again."
	finish_action()

/**
 * Answers the window asking for a picture's preview.
 *
 * We fetch it from the bridge each time and keep no copy, the window keeps it by id and take.
 * Arguments:
 * * picture_id - the window's id for the picture
 */
/datum/bug_report/proc/send_preview(picture_id)
	var/datum/bug_report_picture/picture = find_picture(picture_id)
	if(!picture || picture.pending || picture.image_state != "ready" || !COOLDOWN_FINISHED(picture, preview_cooldown))
		return
	COOLDOWN_START(picture, preview_cooldown, 10 SECONDS)
	INVOKE_ASYNC(src, PROC_REF(load_preview), picture)

/// Fetches a picture's private preview into a data URL, a WebP from a bridge that makes them and a PNG from any other - never browse_rsc, which keeps every image in the player's cache for good
/datum/bug_report/proc/load_preview(datum/bug_report_picture/picture)
	var/attachment_id = picture.attachment_id
	var/take = picture.take
	var/path = bug_report_temporary_path("preview")
	var/data_url
	// Only the reply itself means the preview was saved, a conflict's answer is a list
	var/datum/http_response/saved = attachment_call("preview", attachment_id, output_file = path, wanted_type = "image/webp")
	if(istype(saved, /datum/http_response) && fexists(path))
		var/content_type = saved.headers?["content-type"]
		content_type = istext(content_type) ? LOWER_TEXT(trim(copytext(content_type, 1, findtext(content_type, ";")))) : null
		// An older bridge ignores what we asked for and sends a PNG, so we show anything it doesn't call WebP as one
		data_url = "data:[content_type == "image/webp" ? content_type : "image/png"];base64,[rustg_hash_file(RUSTG_HASH_BASE64, path)]"
	fdel(path)
	// A retake while we waited makes this the last image's preview
	if(!valid_owner() || picture.attachment_id != attachment_id || picture.take != take)
		return
	// No src tells the window the preview didn't load
	send_partial(list("preview" = list("id" = picture.id, "take" = take, "src" = data_url)))

#undef BUG_REPORT_TEMPORARY
#undef BUG_REPORT_CHECK_WAIT
