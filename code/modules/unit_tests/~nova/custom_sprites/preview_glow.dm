/// Pixels of a picture that light what is under them on the emissive plane, red or green, as list("x,y").
/proc/custom_sprite_test_lit_pixels(icon/picture)
	. = list()
	for(var/x in 1 to picture.Width())
		for(var/y in 1 to picture.Height())
			var/pixel = picture.GetPixel(x, y)
			if(!pixel)
				continue
			var/list/channels = rgb2num(pixel)
			if(channels[1] || channels[2])
				. += "[x],[y]"

/// The middle of a region's pixels in a view that nothing drawn over the body covers, as list(x, y), or null.
/proc/custom_sprite_test_open_region_pixel(datum/custom_sprite_editor/markings/editor, zone, direction = "2")
	var/index = "[editor.region_zones.Find(zone)]"
	var/list/rows = editor.region_map[direction]
	var/list/covers = editor.cover_rows[direction]
	var/list/open = list()
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			if(copytext(rows[y], x, x + 1) == index && (!covers || copytext(covers[y], x, x + 1) == "0"))
				open += list(list(x - 1, y - 1))
	return length(open) ? open[round((length(open) + 1) / 2)] : null

/// The editors draw their preview's glow only while the window has the lights off, none for a look with nothing that
/// glows, and drop it when the preview changes with the lights on. A composed markings preview's glow lights its
/// glowing paint and nothing else.
/datum/unit_test/custom_sprite_preview_glow/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	// Previewed naked, so no underwear covers the markings fixture's paint.
	preferences.preview_pref = PREVIEW_PREF_NAKED

	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))), "The hair fixture must paint a pixel.")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(editor.preview_urls["2"], "The hair fixture must have a preview picture.")
	TEST_ASSERT(!length(editor.glow_urls), "With the lights on, an editor must draw no glow.")
	TEST_ASSERT(isnull(editor.ui_data(mock_client.mob)["glows"]), "With the lights on, the window must be sent no glows.")
	TEST_ASSERT(editor.ui_act("previewLights", list("off" = TRUE), ui, null), "Turning the preview's lights off must update the window.")
	TEST_ASSERT_EQUAL(editor.glow_urls["2"], "", "A preview with nothing that glows must draw no glow picture.")
	TEST_ASSERT(editor.ui_act("setEmissive", list("dir" = "2", "enabled" = TRUE), ui, null), "The fixture's hair must be able to glow.")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(findtext(editor.glow_urls["2"], "data:image/png;base64,") == 1, "Glowing paint must draw a glow picture with the lights off.")
	TEST_ASSERT_EQUAL(editor.ui_data(mock_client.mob)["glows"]?["2"], editor.glow_urls["2"], "With the lights off, the window must be sent the glows.")
	TEST_ASSERT(editor.ui_act("previewLights", list("off" = FALSE), ui, null), "Turning the preview's lights on again must update the window.")
	TEST_ASSERT(isnull(editor.ui_data(mock_client.mob)["glows"]), "With the lights on again, the window must be sent no glows.")
	TEST_ASSERT(editor.ui_act("setEmissive", list("dir" = "2", "enabled" = FALSE), ui, null), "The fixture's hair must be able to stop glowing.")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(isnull(editor.glow_urls["2"]), "With the lights on, a new preview picture must draw no glow.")
	editor.finish(FALSE)

	var/datum/custom_sprite_editor/markings/unified_test/markings = new(preferences, BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "markings", markings)
	var/datum/tgui/markings_ui = allocate(/datum/tgui, mock_client.mob, markings, "CustomMarkingsEditor")
	markings.ui_act("selectRegion", list("zone" = BODY_ZONE_CHEST), markings_ui, null)
	var/list/point = custom_sprite_test_open_region_pixel(markings, BODY_ZONE_CHEST)
	TEST_ASSERT(point, "The markings fixture needs a chest pixel nothing covers.")
	TEST_ASSERT(markings.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[markings.workspace.palette[1]]ff", "points" = list(point))), "The markings fixture must paint the chest.")
	markings.refresh_preview(push = FALSE)
	TEST_ASSERT(markings.preview_composed, "A plain body's markings preview must be composed.")
	TEST_ASSERT(markings.ui_act("previewLights", list("off" = TRUE), markings_ui, null), "Turning the markings preview's lights off must update the window.")
	TEST_ASSERT_EQUAL(markings.glow_urls["2"], "", "Paint that doesn't glow, on a body with nothing that glows, must draw no glow picture.")
	TEST_ASSERT(markings.ui_act("setEmissive", list("zone" = BODY_ZONE_CHEST, "dir" = "2", "enabled" = TRUE), markings_ui, null), "The chest's front must be able to glow.")
	TEST_ASSERT(findtext(markings.glow_urls["2"], "data:image/png;base64,") == 1, "Making paint glow must draw its composed glow at once, though no pixel changed.")
	var/list/lit = custom_sprite_test_lit_pixels(custom_sprite_picture_icon(custom_sprite_picture_path("[markings.picture_name]_glow", "2", "32x32")))
	TEST_ASSERT_EQUAL(json_encode(lit), json_encode(list("[point[1] + 1],[32 - point[2]]")), "The composed glow must light the glowing paint's pixel and nothing else.")
	markings.finish(FALSE)
