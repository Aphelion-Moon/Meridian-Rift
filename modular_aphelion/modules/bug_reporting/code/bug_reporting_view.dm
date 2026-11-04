/// How long a reporter waits between in-game captures
#define BUG_REPORT_VIEW_COOLDOWN (30 SECONDS)
/// In-game captures rendering at once across the server
#define BUG_REPORT_RENDERS_MAX 2

/// In-game captures rendering across the server, held under BUG_REPORT_RENDERS_MAX
GLOBAL_VAR_INIT(bug_report_renders, 0)

/**
 * The camera behind in-game captures, which develops a reporter's whole view the way photos are developed.
 *
 * Each capture makes one in nullspace and deletes it after, so two renders at once never share its settings.
 * It never flashes, prints or describes anything, and lighting comes out as it does on photos.
 */
/obj/item/camera/bug_report
	name = "bug report camera"
	desc = "Takes the in-game captures of bug reports. You shouldn't be holding this."
	flash_enabled = FALSE
	silent = TRUE
	print_picture_on_snap = FALSE

/**
 * Finds the turfs a viewer sees over their whole view, or returns null when there are none.
 *
 * Works like a photo stretched over the view - turfs past walls stay out unless the viewer is a ghost,
 * a camera eye sees only what cameras see, and open space shows the level below.
 * Arguments:
 * * center - the turf the viewer's eye is on
 * * width - tiles across, as getviewsize() gives them
 * * height - tiles up
 * * observing - whether the viewer is a ghost, who sees past walls
 * * cameranet - whether the viewer looks through the camera network, like an AI
 */
/obj/item/camera/bug_report/proc/seen_turfs(turf/center, width, height, observing, cameranet)
	var/list/seen
	if(!observing && !cameranet)
		seen = list()
		for(var/turf/visible as anything in get_hear_turfs(round(max(width, height) / 2), center))
			seen[visible] = TRUE
	var/list/turfs
	for(var/turf/tile as anything in CORNER_BLOCK_OFFSET(center, width, height, -round(width / 2), -round(height / 2)))
		if(seen && !seen[tile])
			continue
		if(cameranet && !SScameras.is_visible_by_cameras(tile))
			continue
		// Open space and glass floors show the level below, like on photos
		while(tile)
			LAZYADD(turfs, tile)
			if(!isopenspaceturf(tile) && !istype(tile, /turf/open/floor/glass))
				break
			tile = GET_TURF_BELOW(tile)
	return turfs

/**
 * Develops turfs into one flat icon the size of the view, or returns null when no room could be reserved for it.
 *
 * It yields between turfs and atoms, so a big view spreads over ticks.
 * Arguments:
 * * turfs - the turfs to draw, from seen_turfs()
 * * center - the turf the view is centered on
 * * width - tiles across
 * * height - tiles up
 * * observing - whether ghosts show, as they do to a ghost
 */
/obj/item/camera/bug_report/proc/render_turfs(list/turfs, turf/center, width, height, observing)
	var/datum/turf_reservation/clone_area = SSmapping.request_turf_block_reservation(width, height, 1)
	if(!clone_area)
		return null
	see_ghosts = observing ? CAMERA_SEE_GHOSTS_BASIC : CAMERA_NO_GHOSTS
	var/icon/rendered
	try
		rendered = camera_get_icon(turfs, center, clone_area, yield_while_cloning = TRUE)
	catch(var/exception/error)
		// The reservation would otherwise stay taken for the rest of the round
		qdel(clone_area)
		throw error
	qdel(clone_area)
	rendered.Blend("#000", ICON_UNDERLAY)
	return rendered

/datum/bug_report
	/// Whether this report is rendering an in-game capture, which holds every report of its connection
	var/rendering = FALSE
	/// Spaces in-game captures, held across every report of the connection
	COOLDOWN_DECLARE(view_cooldown)

/// Whether the reporter's in-game captures are held, since one of their reports is rendering or rendered too recently
/datum/bug_report/proc/render_held()
	for(var/datum/bug_report/report as anything in owner.bug_report_history)
		if(report.rendering || !COOLDOWN_FINISHED(report, view_cooldown))
			return TRUE
	return FALSE

/**
 * Renders the reporter's whole view on the server and adds it to the report as a picture.
 *
 * It's sliced over ticks, so a big view costs the server some time but never stalls it, and it's held to
 * one render a reporter every BUG_REPORT_VIEW_COOLDOWN, whichever report they're in, and BUG_REPORT_RENDERS_MAX
 * across the server. The render spends the captures allowance when it starts, so one dropped on the way still counts.
 * Arguments:
 * * replace - the id of the picture it retakes, or null for a new one
 */
/datum/bug_report/proc/begin_view_capture(replace)
	if(busy || !valid_owner() || sealed_results[result?["kind"]])
		return
	if(render_held())
		return finish_action("Give it a few seconds before the next capture.")
	if(!take_allowance("captures", spend = FALSE))
		return finish_action()
	var/datum/bug_report_picture/picture = picture_for(replace, "view")
	if(!picture)
		return finish_action()
	busy = TRUE
	push_update()
	if(!save_fields())
		return finish_action()
	// Saving yields, so we only look for a free render after it, and the reporter may have started one elsewhere meanwhile
	if(render_held())
		return finish_action("Give it a few seconds before the next capture.")
	if(GLOB.bug_report_renders >= BUG_REPORT_RENDERS_MAX)
		return finish_action("Lots of captures are running right now. Try again in a moment.")
	if(!take_allowance("captures"))
		return finish_action()
	COOLDOWN_START(src, view_cooldown, BUG_REPORT_VIEW_COOLDOWN)
	var/obj/item/camera/bug_report/camera
	var/list/turfs
	var/path
	var/exception/thrown
	try
		// Set inside the try, so nothing breaking after them leaves the report, the reporter or the server rendering
		rendering = TRUE
		GLOB.bug_report_renders++
		LAZYOR(pictures, picture)
		picture.pending = "rendering"
		picture.reason = null
		status = null
		push_update()
		camera = new
		var/turf/center = get_turf(owner.eye)
		// A ghost's view range can make the view several times bigger and the layer sort is quadratic, so we render the default view
		var/list/view_size = getviewsize(owner.view_size?.default || owner.view)
		turfs = center && camera.seen_turfs(center, view_size[1], view_size[2], isobserver(owner.mob), istype(owner.eye, /mob/eye/camera))
		var/icon/rendered = turfs && camera.render_turfs(turfs, center, view_size[1], view_size[2], isobserver(owner.mob))
		if(rendered && valid_owner())
			// The PNG encode can't be split, so it gets a tick of its own
			stoplag()
			path = bug_report_temporary_path("upload")
			if(!fcopy(rendered, path))
				fdel(path)
				path = null
	catch(var/exception/error)
		thrown = error
	// However the render ended, it gives back its slot and stops holding the reporter's other captures
	GLOB.bug_report_renders--
	rendering = FALSE
	qdel(camera)
	if(thrown)
		if(path)
			fdel(path)
		end_new_image(picture, "render")
		finish_action(picture.attachment_id ? "The in-game capture didn't work. Try again, or add your own screenshot." : null)
		throw thrown
	if(!valid_owner())
		if(path)
			fdel(path)
		end_new_image(picture)
		return finish_action()
	if(!turfs)
		end_new_image(picture, "nothing")
		return finish_action(picture.attachment_id ? "There's nothing to see from where you are." : null)
	if(!path)
		end_new_image(picture, "render")
		return finish_action(picture.attachment_id ? "The in-game capture didn't work. Try again, or add your own screenshot." : null)
	upload_picture(picture, path, spent = TRUE)

#undef BUG_REPORT_VIEW_COOLDOWN
#undef BUG_REPORT_RENDERS_MAX
