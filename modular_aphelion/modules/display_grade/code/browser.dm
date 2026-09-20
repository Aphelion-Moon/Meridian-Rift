/datum/asset/simple/display_grade
	keep_local_name = FALSE
	assets = list("display-grade.bundle.js" = "tgui/public/display-grade.bundle.js")

/client
	/// Legacy window ID -> registration token. TGUI already owns its window registry.
	var/list/display_grade_browsers = list()
	var/display_grade_browser_serial = 0

/client/proc/display_grade_payload(neutral = FALSE)
	return list("revision" = ++display_grade_revision, "settings" = display_grade_settings, "neutral" = neutral)

/datum/tgui_window/proc/display_grade_update()
	if(status != TGUI_WINDOW_CLOSED)
		send_message("display/grade", client.display_grade_payload(locked_by?.interface in list("DisplayGrade", "DisplayGradeProof")))

/client/proc/display_grade_update_browsers()
	for(var/key in tgui_windows)
		var/datum/tgui_window/window = tgui_windows[key]
		window.display_grade_update()
	for(var/id in display_grade_browsers)
		var/list/registration = display_grade_browsers[id]
		if(registration["ready"])
			src << output(url_encode(json_encode(display_grade_payload())), "[registration["target"]]:displayGradeUpdate")

/// Called after the page body exists, before the window announces readiness.
/client/proc/display_grade_bootstrap(neutral = FALSE, legacy_id)
	var/datum/asset/asset = get_asset_datum(/datum/asset/simple/display_grade)
	asset.send(src)
	var/url = asset.get_url_mappings()["display-grade.bundle.js"]
	var/initial_data = json_encode(display_grade_payload(neutral))
	var/ready_script = ""
	if(legacy_id)
		var/token = "[++display_grade_browser_serial]"
		display_grade_browsers[legacy_id] = list("token" = token, "ready" = FALSE)
		ready_script = "<script>location.href='byond://?src=[REF(src)];display_grade_ready=[url_encode(legacy_id)];display_grade_token=[token]';</script>"
	return "<script>window.displayGradeInitial=[initial_data];</script><script src='[url]'></script>[ready_script]"

/client/proc/display_grade_html(html, id)
	if(isfile(html))
		html = file2text(html)
	if(!istext(html) || !id)
		return html
	var/bootstrap = display_grade_bootstrap(legacy_id = id)
	var/body_end = findlasttext(html, "</body>")
	return body_end ? "[copytext(html, 1, body_end)][bootstrap][copytext(html, body_end)]" : "[html][bootstrap]"

/client/proc/display_grade_browser_ready(id, token)
	var/list/registration = display_grade_browsers[id]
	if(!registration || registration["token"] != token)
		return
	var/control_type = winexists(src, id)
	if(display_grade_browsers[id] != registration || !control_type)
		return
	registration["target"] = control_type == "BROWSER" ? id : "[id].browser"
	registration["ready"] = TRUE
	src << output(url_encode(json_encode(display_grade_payload())), "[registration["target"]]:displayGradeUpdate")

/// Visible raw browse pages share the same transport as /datum/browser.
/proc/display_grade_browse(receiver, html, options)
	var/client/viewer = istype(receiver, /client) ? receiver : (ismob(receiver) ? receiver:client : null)
	if(!viewer)
		return
	var/list/parsed = params2list(options)
	var/id = parsed["window"] || "browser"
	if(isnull(html))
		viewer.display_grade_browsers -= id
	else
		html = viewer.display_grade_html(html, id)
	viewer << browse(html, options)
	if(!isnull(html) && viewer.mob)
		onclose(viewer.mob, id)
