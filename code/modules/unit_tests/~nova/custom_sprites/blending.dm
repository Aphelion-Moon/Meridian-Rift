/// Runs the whole-body editor's actions without a connected client.
/datum/custom_sprite_editor/markings/blending_test/can_edit(mob/user)
	return !closing

/// Runs a hair editor's actions without a connected client.
/datum/custom_sprite_editor/blending_test/can_edit(mob/user)
	return !closing

/// Markings editors blend Custom brushes with the body's primary mutant color; hair editors keep blending with the hair color.
/datum/unit_test/custom_sprite_mutant_blend/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/markings/blending_test/markings = allocate(/datum/custom_sprite_editor/markings/blending_test, preferences, BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "markings", markings)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, markings, "CustomMarkingsEditor")
	markings.preview_body.dna.features[FEATURE_MUTANT_COLOR] = "#FF8000"
	markings.set_custom_palette(list("#808080"))
	TEST_ASSERT(markings.ui_act("setColorMode", list("mode" = "mutant"), ui, null), "Markings editors should accept mutant color blending")
	TEST_ASSERT(markings.ui_act("selectCustomColor", list("color" = "#808080"), ui, null), "A saved swatch should stay selectable under mutant color blending")
	TEST_ASSERT_EQUAL(markings.selected_color, "#804000", "The brush should be the swatch multiplied by the mutant color")
	var/list/point
	var/list/bounds = markings.workspace.draw_bounds["2"]
	for(var/y in bounds[2] to bounds[4])
		for(var/x in bounds[1] to bounds[3])
			if(!point && markings.workspace.is_point_allowed(x, y, "2"))
				point = list(x, y)
	TEST_ASSERT(point, "The body needs a paintable pixel in the Front view")
	TEST_ASSERT(markings.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[markings.selected_color]ff", "points" = list(point))), "A mutant-blended brush should paint")
	var/list/frame = markings.workspace.layers[1]["data"]["2"]
	TEST_ASSERT_EQUAL(frame[point[2] + 1][point[1] + 1], "#804000ff", "The stroke should keep the blended color")
	var/datum/custom_sprite_editor/blending_test/hair = allocate(/datum/custom_sprite_editor/blending_test, preferences, "hair")
	var/datum/tgui/hair_ui = allocate(/datum/tgui, mock_client.mob, hair, "CustomHairEditor")
	TEST_ASSERT(!hair.ui_act("setColorMode", list("mode" = "mutant"), hair_ui, null), "Hair editors should refuse mutant color blending")
