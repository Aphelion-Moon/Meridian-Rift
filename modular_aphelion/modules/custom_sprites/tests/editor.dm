#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// Preserve native previews for browser qualification without a live client or asset delivery.
/datum/custom_sprite_editor/qualification/publish_icon(icon/rendered)
	var/list/asset = generate_and_hash_rsc_file(rendered)
	var/name = "custom-sprite-[asset[2]].png"
	fcopy(asset[1], "data/custom_sprite_checks/[name]")
	return "/native/[name]"

/datum/unit_test/custom_sprite_editor_lifecycle/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	for(var/target in list("hair", "markings"))
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/qualification(preferences, target)
		preferences.custom_sprite_editors[target] = editor
		if(length(editor.guide_urls) != 4 || length(editor.preview_urls) != 4)
			Fail("Each editor must publish all four guides and previews.", __FILE__, __LINE__)
		var/list/bounds = editor.workspace.draw_bounds["2"]
		if(!bounds)
			Fail("The preview body needs editable bounds.", __FILE__, __LINE__)
			continue
		var/list/stroke = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(list(bounds[1], bounds[2])))
		if(!editor.workspace.new_transaction(stroke))
			Fail("The editor rejected a sampled shade within its own bounds.", __FILE__, __LINE__)
		editor.draft = editor.workspace.serialize_drawing()
		editor.draft_hash = custom_sprite_hash(editor.draft)
		editor.refresh_preview()
		rustg_file_write(json_encode(editor.ui_data(mock_client.mob)), "data/custom_sprite_checks/[target].json")
		editor.finish(TRUE)
		var/list/saved = target == "hair" ? preferences.custom_hair : preferences.custom_markings
		if(!saved || preferences.custom_sprite_editors[target])
			Fail("Closing must save the drawing and release its editor.", __FILE__, __LINE__)
		var/saved_hash = custom_sprite_hash(saved)
		editor = new /datum/custom_sprite_editor/qualification(preferences, target)
		preferences.custom_sprite_editors[target] = editor
		editor.workspace.clear_direction("2")
		editor.finish(FALSE)
		if(saved_hash != custom_sprite_hash(target == "hair" ? preferences.custom_hair : preferences.custom_markings))
			Fail("Discard must preserve the last saved drawing.", __FILE__, __LINE__)
	var/old_gate = CONFIG_GET(flag/allow_custom_sprite_editing)
	CONFIG_SET(flag/allow_custom_sprite_editing, FALSE)
	var/datum/preference_middleware/custom_sprites/middleware = locate() in preferences.middleware
	var/list/ui_data = middleware.get_ui_data(mock_client.mob)
	if(ui_data["allow_custom_sprite_editing"] || !custom_sprite_paint_icon(preferences.custom_hair))
		Fail("Disabling editing must hide controls while saved drawings still render.", __FILE__, __LINE__)
	CONFIG_SET(flag/allow_custom_sprite_editing, old_gate)

#endif
