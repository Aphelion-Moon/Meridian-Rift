GLOBAL_VAR_INIT(display_grade_session_serial, 0)

/// Owns preview state independently of the preference cache and the current mob.
/datum/display_grade_editor
	var/client/viewer
	var/session
	var/list/draft
	var/bypass = FALSE
	var/finished = FALSE
	var/sequence = 0
	var/preview_timer
	var/last_publish = -INFINITY

/datum/display_grade_editor/New(client/viewer)
	src.viewer = viewer
	session = "[++GLOB.display_grade_session_serial]"
	draft = display_grade_reference()
	if(viewer?.prefs && viewer.prefs.read_preference(/datum/preference/choiced/display_grade_mode) != "Reference")
		draft = display_grade_validate(viewer.prefs.read_preference(/datum/preference/display_grade_custom)) || draft
	if(viewer)
		RegisterSignal(viewer, COMSIG_QDELETING, PROC_REF(disconnected))

/datum/display_grade_editor/Destroy()
	finish()
	viewer = null
	return ..()

/datum/display_grade_editor/proc/disconnected()
	SIGNAL_HANDLER
	// No broadcasts or native allocation while the client is being destroyed.
	if(viewer)
		viewer.display_grade_editor = null
	viewer = null
	qdel(src)

/datum/display_grade_editor/proc/effective_settings()
	return bypass ? null : draft.Copy()

/// Complete payloads and monotonic session-local sequence numbers prevent stale drags.
/datum/display_grade_editor/proc/accept_preview(raw_session, raw_sequence, list/settings, raw_bypass)
	if(finished || raw_session != session || !isnum(raw_sequence) || !IS_FINITE(raw_sequence) || raw_sequence <= sequence || round(raw_sequence) != raw_sequence)
		return FALSE
	var/list/validated = display_grade_validate(settings)
	if(!validated || !(raw_bypass in list(TRUE, FALSE)))
		return FALSE
	sequence = raw_sequence
	draft = validated
	bypass = raw_bypass
	if(isnull(preview_timer))
		if(world.time >= last_publish + 0.1 SECONDS)
			publish_preview()
		else
			preview_timer = addtimer(CALLBACK(src, PROC_REF(publish_preview)), last_publish + 0.1 SECONDS - world.time, TIMER_STOPPABLE)
	return TRUE

/datum/display_grade_editor/proc/publish_preview()
	preview_timer = null
	if(finished)
		return
	last_publish = world.time
	viewer?.display_grade_refresh()

/datum/display_grade_editor/proc/finish()
	if(finished)
		return
	finished = TRUE
	if(!isnull(preview_timer))
		deltimer(preview_timer)
		preview_timer = null
	if(viewer?.display_grade_editor == src)
		viewer.display_grade_editor = null
		viewer.display_grade_refresh()
	SStgui.close_uis(src)

/datum/display_grade_editor/ui_state(mob/user)
	return GLOB.always_state

/datum/display_grade_editor/ui_status(mob/user, datum/ui_state/state)
	return !finished && user.client == viewer ? UI_INTERACTIVE : UI_CLOSE

/datum/display_grade_editor/ui_interact(mob/user, datum/tgui/ui)
	if(finished || user.client != viewer)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "DisplayGrade", "Display grade")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/display_grade_editor/ui_data(mob/user)
	return list("settings" = draft, "session" = session)

/datum/display_grade_editor/ui_close(mob/user)
	finish()
	qdel(src)

/datum/display_grade_editor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || finished || ui.user.client != viewer || params["session"] != session)
		return FALSE
	switch(action)
		if("preview")
			accept_preview(params["session"], params["sequence"], params["settings"], params["bypass"])
			return FALSE
		if("apply")
			// Apply is authoritative even if the final preview is still in flight.
			if(!viewer.prefs.apply_display_grade(params["settings"]))
				return FALSE
			finish()
		if("cancel")
			finish()
		else
			return FALSE
	return TRUE
