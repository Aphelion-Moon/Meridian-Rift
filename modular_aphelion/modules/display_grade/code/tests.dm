#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/datum/unit_test/display_grade_model/Run()
	var/list/reference = display_grade_reference()
	if(display_grade_validate(list()))
		Fail("Incomplete settings must be rejected", __FILE__, __LINE__)
	var/list/invalid = reference.Copy()
	invalid["strength"] = 1.01
	if(display_grade_validate(invalid))
		Fail("Out-of-range settings must be rejected", __FILE__, __LINE__)
	invalid = reference.Copy()
	invalid["shadow_color"] = "#FFF"
	if(display_grade_validate(invalid))
		Fail("Only six-digit RGB colors are accepted", __FILE__, __LINE__)
	invalid["shadow_color"] = "#12345678"
	if(display_grade_validate(invalid))
		Fail("Alpha colors are not accepted", __FILE__, __LINE__)
	invalid = reference.Copy()
	invalid["brightness"] = "0"
	if(display_grade_validate(invalid))
		Fail("Numeric strings are not numbers", __FILE__, __LINE__)
	var/list/settings = display_grade_validate(reference)
	settings["strength"] = 0
	if(reference["strength"] != 1)
		Fail("Validation must copy settings", __FILE__, __LINE__)
	var/list/sample = list(0.2, 0.4, 0.9, 0.37)
	var/list/result = display_grade_sample(sample, settings)
	for(var/channel in 1 to 4)
		if(result[channel] != sample[channel])
			Fail("Zero strength must be identity", __FILE__, __LINE__)
	settings = reference.Copy()
	settings["saturation"] = 1
	settings["shadow_color"] = "#FF0000"
	settings["midtone_color"] = "#00FF00"
	settings["highlight_color"] = "#0000FF"
	settings["midtone_strength"] = 1
	for(var/anchor in 1 to 3)
		var/value = (anchor - 1) / 2
		result = display_grade_sample(list(value, value, value, 0.37), settings)
		for(var/channel in 1 to 3)
			if(abs(result[channel] - (channel == anchor ? 1 : 0)) >= 0.00001)
				Fail("Tonal anchors must have independent colors", __FILE__, __LINE__)
		if(result[4] != 0.37)
			Fail("Alpha must be unchanged", __FILE__, __LINE__)
	settings = reference.Copy()
	settings["shadow_strength"] = 0
	settings["midtone_strength"] = 0
	settings["highlight_strength"] = 0
	settings["saturation"] = 1.5
	settings["contrast"] = 0.5
	result = display_grade_sample(list(1, 0, 0, 1), settings)
	if(abs(result[1] - 0.94685) >= 0.00001)
		Fail("Adjustments must clamp only once", __FILE__, __LINE__)
	if(abs(result[2] - 0.19685) >= 0.00001)
		Fail("Adjustment matrix must use the agreed luma coefficients", __FILE__, __LINE__)
	test_preferences()
	test_editor()
	test_renderer_resources()

/datum/unit_test/display_grade_model/proc/test_preferences()
	var/datum/preference/choiced/display_grade_mode/mode = GLOB.preference_entries[/datum/preference/choiced/display_grade_mode]
	var/datum/preference/display_grade_custom/custom = GLOB.preference_entries[/datum/preference/display_grade_custom]
	if(mode.create_default_value() != "Off" || mode.deserialize("bogus") || mode.deserialize(list("Custom")))
		Fail("Mode must default to Off and reject unknown or structured input", __FILE__, __LINE__)
	if(mode.savefile_identifier != PREFERENCE_PLAYER || custom.savefile_identifier != PREFERENCE_PLAYER)
		Fail("Both preferences must belong to the account", __FILE__, __LINE__)
	var/datum/client_interface/owner = allocate(/datum/client_interface)
	var/test_path = "data/display-grade-test-[REF(src)].json"
	var/datum/preferences/display_grade_test/preferences = allocate(/datum/preferences/display_grade_test, owner, test_path)
	if(preferences.read_preference(mode.type) != "Off")
		Fail("A missing profile must initialize Off", __FILE__, __LINE__)
	var/list/settings = display_grade_reference()
	settings["shadow_color"] = "#123456"
	if(!preferences.apply_display_grade(settings))
		Fail("A valid full draft must save", __FILE__, __LINE__)
	settings["shadow_color"] = "#FFFFFF"
	if(preferences.read_preference(custom.type)["shadow_color"] != "#123456")
		Fail("Apply must own a validated copy", __FILE__, __LINE__)
	var/datum/preferences/display_grade_test/reconnected = allocate(/datum/preferences/display_grade_test, owner, test_path)
	if(reconnected.read_preference(mode.type) != "Custom" || reconnected.read_preference(custom.type)["shadow_color"] != "#123456")
		Fail("Both mode and profile must round-trip through the JSON savefile", __FILE__, __LINE__)
	for(var/selection in list("Off", "Reference", "Custom"))
		reconnected.update_preference(mode, selection)
		if(reconnected.read_preference(custom.type)["shadow_color"] != "#123456")
			Fail("Mode changes must preserve the saved custom profile", __FILE__, __LINE__)
	if(reconnected.apply_display_grade(list("strength" = 1)))
		Fail("Incomplete Apply must fail atomically", __FILE__, __LINE__)
	if(reconnected.read_preference(custom.type)["shadow_color"] != "#123456")
		Fail("Rejected Apply must not touch the cache", __FILE__, __LINE__)
	var/datum/preferences/display_grade_test/other = allocate(/datum/preferences/display_grade_test, owner, null)
	if(other.read_preference(mode.type) != "Off" || other.read_preference(custom.type)["shadow_color"] != "#2D2639")
		Fail("One account's profile must not mutate another account's defaults", __FILE__, __LINE__)
	var/datum/preference_middleware/display_grade/middleware = allocate(/datum/preference_middleware/display_grade, preferences)
	if(!middleware.pre_set_preference(null, "display_grade_custom", settings))
		Fail("Generic preference writes must not bypass the full-draft transaction", __FILE__, __LINE__)
	fdel(test_path)

/datum/unit_test/display_grade_model/proc/test_editor()
	var/datum/display_grade_editor/display_grade_test/editor = allocate(/datum/display_grade_editor/display_grade_test)
	var/list/settings = display_grade_reference()
	if(editor.accept_preview("wrong-session", 1, settings, FALSE))
		Fail("A different editor session must not update this draft", __FILE__, __LINE__)
	if(!editor.accept_preview(editor.session, 1, settings, FALSE))
		Fail("Valid preview must be accepted", __FILE__, __LINE__)
	settings["strength"] = 0.25
	editor.accept_preview(editor.session, 2, settings, FALSE)
	settings["strength"] = 0.75
	editor.accept_preview(editor.session, 3, settings, FALSE)
	if(editor.published != 1)
		Fail("Drag updates must coalesce within 100 ms", __FILE__, __LINE__)
	if(editor.accept_preview(editor.session, 2, display_grade_reference(), FALSE))
		Fail("An older preview must not overwrite the latest drag", __FILE__, __LINE__)
	sleep(0.2 SECONDS)
	if(editor.published != 2 || editor.last_settings["strength"] != 0.75)
		Fail("The trailing preview must publish the final drag value", __FILE__, __LINE__)
	editor.accept_preview(editor.session, 4, settings, TRUE)
	if(editor.effective_settings())
		Fail("Before must bypass the entire grade", __FILE__, __LINE__)
	editor.accept_preview(editor.session, 5, display_grade_reference(), FALSE)
	if(editor.draft["strength"] != 1 || editor.draft["saturation"] != 0.72)
		Fail("Reset must restore the reference draft", __FILE__, __LINE__)
	editor.finish()
	var/published_before = editor.published
	if(editor.accept_preview(editor.session, 6, settings, FALSE))
		Fail("Finished editors must reject late previews", __FILE__, __LINE__)
	sleep(0.2 SECONDS)
	if(editor.published != published_before || !isnull(editor.preview_timer))
		Fail("Closing must cancel pending broadcasts", __FILE__, __LINE__)
	var/datum/display_grade_editor/next = allocate(/datum/display_grade_editor)
	if(next.session == editor.session || next.draft["strength"] != 1)
		Fail("A new editor must own a new session and independent draft", __FILE__, __LINE__)

/// These tests check graph ownership, not rendered pixels or mouse forwarding.
/datum/unit_test/display_grade_model/proc/test_renderer_resources()
	var/datum/client_interface/display_grade_test/viewer = allocate(/datum/client_interface/display_grade_test)
	var/datum/plane_master_group/group = allocate(/datum/plane_master_group/hudless)
	group.map = "display-grade-test"
	var/atom/movable/screen/plane_master/rendering_plate/master/master = group.get_plane(RENDER_PLANE_MASTER)
	var/old_target = master.render_target
	// Existing HUD tests use datum client mocks. Rendering hooks must keep supporting them.
	var/mob/living/carbon/human/observer = allocate(/mob/living/carbon/human/consistent)
	observer.canon_client = viewer
	master.show_to(observer)
	master.hide_from(observer)
	observer.canon_client = null
	viewer.screen.Cut()
	for(var/iteration in 1 to 20)
		var/datum/display_grade_renderer/renderer = new(viewer, master, display_grade_reference())
		viewer.display_grade_renderers[master] = renderer
		if(length(renderer.nodes) != 9 || length(viewer.screen) != 9)
			Fail("The graph must have nine owned resources without accumulation", __FILE__, __LINE__)
		for(var/atom/movable/render_plane_relay/node as anything in renderer.nodes)
			if(node.screen_loc != "display-grade-test:1,1")
				Fail("Every node must target the displayed secondary map", __FILE__, __LINE__)
		qdel(renderer)
		if(length(viewer.screen) || length(viewer.display_grade_renderers) || master.render_target != old_target)
			Fail("Removing the graph must release nodes and restore the master", __FILE__, __LINE__)

/// Use real preference/cache/save logic against a test-owned JSON file, without login side effects.
/datum/preferences/display_grade_test/New(client/parent, path)
	src.parent = parent
	src.path = path
	savefile = new /datum/json_savefile(path)

/datum/preferences/display_grade_test/Destroy()
	parent = null
	QDEL_NULL(savefile)
	return ..()

/datum/display_grade_editor/display_grade_test
	var/published = 0
	var/list/last_settings

/datum/display_grade_editor/display_grade_test/publish_preview()
	if(!finished)
		published++
		last_settings = draft.Copy()
	return ..()

/datum/client_interface/display_grade_test
	var/list/display_grade_renderers = list()

#endif
