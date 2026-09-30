/// Hair with a High Ponytail-style pair as the branch writes it, built without codec procs: an under-hat ponytail (Back view, glowing) and an over-hat tip.
/proc/custom_sprite_appendage_fixture()
	return list(
		"version" = 1,
		"palette" = list("#ff0000", "#00ff00"),
		"tint" = "#ffffff",
		"dirs" = list("2" = "r1112[repeat_string(68, "f0")]20"),
		"emissive" = list("2" = FALSE, "1" = FALSE, "4" = FALSE, "8" = FALSE),
		"appendages" = list(
			"1" = list("name" = "Ponytail", "zone" = HAIR_APPENDAGE_REAR, "outer" = FALSE, "dirs" = list("1" = "r[repeat_string(68, "f0")]42"), "emissive" = list("2" = FALSE, "1" = TRUE, "4" = FALSE, "8" = FALSE)),
			"2" = list("name" = "Ponytail tip", "zone" = HAIR_APPENDAGE_REAR, "outer" = TRUE, "dirs" = list("1" = "r11[repeat_string(68, "f0")]30"), "emissive" = list("2" = FALSE, "1" = FALSE, "4" = FALSE, "8" = FALSE)),
		),
	)

/// Saved appendages load and write back byte for byte; bad ones go on their own, and only hair keeps any.
/datum/unit_test/custom_sprite_appendages_codec/Run()
	var/list/fixture = custom_sprite_appendage_fixture()
	TEST_ASSERT_EQUAL(json_encode(custom_sprite_validate(fixture, allow_appendages = TRUE)), json_encode(fixture), "A canonical drawing with appendages must write back byte for byte")
	TEST_ASSERT(!("appendages" in custom_sprite_validate(fixture)), "Facial hair and markings lose any appendages")
	var/list/bald = custom_sprite_appendage_fixture()
	bald["dirs"] = list()
	var/list/kept = custom_sprite_validate(bald, allow_appendages = TRUE)
	TEST_ASSERT(kept && !length(kept["dirs"]) && length(kept["appendages"]) == 2, "Appendages alone keep a drawing whose hair has no paint")
	TEST_ASSERT(isnull(custom_sprite_validate(bald)), "Without its appendages, hair with no paint is no drawing")
	var/list/mixed = custom_sprite_appendage_fixture()
	var/list/appendages = mixed["appendages"]
	appendages["1"]["zone"] = HAIR_APPENDAGE_TOP | HAIR_APPENDAGE_REAR
	appendages["3"] = list("name" = "Bun", "zone" = HAIR_APPENDAGE_TOP, "outer" = 2, "dirs" = list("2" = "r1112[repeat_string(68, "f0")]20"))
	appendages["4"] = list("name" = "Empty", "zone" = HAIR_APPENDAGE_TOP, "outer" = FALSE, "dirs" = list("2" = "r[repeat_string(68, "f0")]40"))
	appendages["5"] = list("name" = " <b>Big</b>\n  bun ", "zone" = HAIR_APPENDAGE_TOP, "outer" = FALSE, "dirs" = list("4" = "r1112[repeat_string(68, "f0")]20"))
	var/list/salvaged = custom_sprite_validate(mixed, allow_appendages = TRUE)["appendages"]
	TEST_ASSERT_EQUAL(length(salvaged), 2, "Two zones at once, an unknown kind and an unpainted appendage must each be dropped alone")
	TEST_ASSERT_EQUAL(salvaged["1"]["name"], "Ponytail tip", "Survivors keep their order, renumbered from 1")
	TEST_ASSERT_EQUAL(salvaged["2"]["name"], "Big bun", "Names lose tags and extra spaces")
	TEST_ASSERT_EQUAL(json_encode(salvaged["2"]["emissive"]), json_encode(list("2" = FALSE, "1" = FALSE, "4" = FALSE, "8" = FALSE)), "Missing emission settings load as off")
	var/list/crowded = custom_sprite_appendage_fixture()
	for(var/index in 3 to 5)
		crowded["appendages"]["[index]"] = list("name" = "Extra [index]", "zone" = HAIR_APPENDAGE_TOP, "outer" = FALSE, "dirs" = list("2" = "r1112[repeat_string(68, "f0")]20"))
	TEST_ASSERT_EQUAL(length(custom_sprite_validate(crowded, allow_appendages = TRUE)["appendages"]), CUSTOM_SPRITE_MAX_APPENDAGES, "Only the first [CUSTOM_SPRITE_MAX_APPENDAGES] appendages are kept")
	TEST_ASSERT_EQUAL(custom_hair_appendage_name("abcdefghijklmnopqrstuvwxyz"), "abcdefghijklmnopqrst", "Names stop at [CUSTOM_SPRITE_MAX_APPENDAGE_NAME] characters")
	TEST_ASSERT(isnull(custom_hair_appendage_name("  <i></i> ")), "A name with nothing left is no name")
	var/list/nameless = custom_sprite_appendage_fixture()
	nameless["appendages"]["2"]["name"] = list("not text")
	TEST_ASSERT_EQUAL(custom_sprite_validate(nameless, allow_appendages = TRUE)["appendages"]["2"]["name"], "Appendage 2", "An unusable name falls back to the appendage's number")

/// Style files carry hair appendages both ways, and refuse malformed ones without echoing uploaded text.
/datum/unit_test/custom_sprite_appendages_transfer/Run()
	var/list/look = list("style" = "Bald", "color" = "#583820", "gradient_style" = "None", "gradient_color" = "#000000", "opacity" = null, "emissive" = FALSE)
	var/text = custom_style_export_text(custom_style_package("hair", null, custom_sprite_appendage_fixture(), look))
	var/list/parsed = custom_style_parse(text)
	TEST_ASSERT(!parsed["error"], "An exported hair style with appendages must import: [parsed["error"]]")
	TEST_ASSERT_EQUAL(json_encode(parsed["package"]["drawing"]), json_encode(custom_sprite_appendage_fixture()), "Imported appendages must match what was exported")
	var/list/envelope = json_decode(text)
	envelope["target"] = "facial_hair"
	TEST_ASSERT(findtext(custom_style_parse(json_encode(envelope))["error"], "unsupported field"), "Facial hair styles can't carry appendages")
	var/list/cases = list(
		"more than [CUSTOM_SPRITE_MAX_APPENDAGES]" = "crowded",
		"Appendage 1 is malformed" = "reordered",
		"name must be" = "markup",
		"missing its Left view" = "view",
		"unknown part of the head" = "zone",
		"under or over hats" = "kind",
		"has no paint" = "empty",
	)
	for(var/expected, variant in cases)
		envelope = json_decode(text)
		var/list/raw = envelope["drawing"]["appendages"]
		switch(variant)
			if("crowded")
				raw["3"] = raw["1"]
				raw["4"] = raw["2"]
			if("reordered")
				envelope["drawing"]["appendages"] = list("2" = raw["2"], "1" = raw["1"])
			if("markup")
				raw["1"]["name"] = "<script>x</script>"
			if("view")
				raw["1"]["dirs"] -= "8"
			if("zone")
				raw["1"]["zone"] = 3
			if("kind")
				raw["1"]["outer"] = 2
			if("empty")
				raw["1"]["dirs"]["1"] = raw["1"]["dirs"]["2"]
		var/error = custom_style_parse(json_encode(envelope))["error"]
		TEST_ASSERT(findtext(error, expected), "The [variant] case must be refused with \"[expected]\", got \"[error]\"")
		TEST_ASSERT(!findtext(error, "script"), "Refusals never repeat uploaded text")
	// The cap was raised so tall hair with three incompressible appendages still imports.
	var/list/palette = list()
	for(var/index in 1 to CUSTOM_SPRITE_MAX_COLORS)
		palette += rgb(index, 0, 0)
	var/noise = "f[repeat_string(768, "1_")]"
	var/list/views = list("2" = noise, "1" = noise, "4" = noise, "8" = noise)
	var/list/worst = list("version" = 4, "palette" = palette, "tint" = "#ffffff", "dirs" = views.Copy(), "emissive" = TRUE, "appendages" = list())
	for(var/index in 1 to CUSTOM_SPRITE_MAX_APPENDAGES)
		worst["appendages"]["[index]"] = list("name" = "Piece [index]", "zone" = HAIR_APPENDAGE_REAR, "outer" = FALSE, "dirs" = views.Copy(), "emissive" = TRUE)
	var/list/tall_look = look.Copy()
	tall_look["style"] = CUSTOM_SPRITE_TALL_HAIRSTYLE
	var/worst_text = custom_style_export_text(custom_style_package("hair", null, custom_sprite_validate(worst, allow_appendages = TRUE), tall_look))
	TEST_ASSERT(length(worst_text) <= CUSTOM_STYLE_MAX_BYTES && !custom_style_parse(worst_text)["error"], "Tall hair with [CUSTOM_SPRITE_MAX_APPENDAGES] incompressible appendages must fit the import cap ([length(worst_text)] bytes)")

/// Resizing, recoloring and view signatures treat appendage views like the hair's own.
/datum/unit_test/custom_sprite_appendages_transforms/Run()
	var/list/fixture = custom_sprite_appendage_fixture()
	var/list/tall = custom_sprite_resize_drawing(fixture, 32, CUSTOM_SPRITE_TALL_HEIGHT)
	TEST_ASSERT_EQUAL(tall["version"], 4, "A tall drawing is version 4, appendages and all")
	TEST_ASSERT_EQUAL(custom_sprite_decode_grid(tall["appendages"]["1"]["dirs"]["1"], 2, 32 * CUSTOM_SPRITE_TALL_HEIGHT), "[repeat_string(1532, "0")]2222", "Appendage paint keeps its place at the bottom of the tall canvas")
	TEST_ASSERT_EQUAL(json_encode(fixture), json_encode(custom_sprite_appendage_fixture()), "Resizing must not change the drawing it was given")
	var/list/merged = custom_style_recolor_drawing(fixture, list("#00ff00" = "#ff0000"))
	TEST_ASSERT_EQUAL(json_encode(merged["palette"]), json_encode(list("#ff0000")), "Colours that meet after a recolor share one slot")
	TEST_ASSERT_EQUAL(custom_sprite_decode_grid(merged["appendages"]["1"]["dirs"]["1"], 1), "[repeat_string(1020, "0")]1111", "Appendage pixels follow the palette map")
	TEST_ASSERT_EQUAL(length(merged["appendages"]), 2, "A recolor keeps the appendages")
	var/list/changed = custom_sprite_appendage_fixture()
	changed["appendages"]["2"]["dirs"]["1"] = "r12[repeat_string(68, "f0")]30"
	TEST_ASSERT(custom_sprite_direction_signature(changed, "1") != custom_sprite_direction_signature(fixture, "1"), "Changing an appendage's Back view changes that view's signature")
	TEST_ASSERT_EQUAL(custom_sprite_direction_signature(changed, "2"), custom_sprite_direction_signature(fixture, "2"), "Other views keep theirs")

/// The head's visible hair overlays on `layer` whose icon has paint at the top left of the Back view.
/proc/custom_sprite_test_appendage_overlays(obj/item/bodypart/head/head, layer)
	. = list()
	for(var/image/overlay as anything in head.get_hair_overlays())
		if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE || overlay.layer != layer || !overlay.icon)
			continue
		var/icon/painted = icon(overlay.icon)
		if(painted.GetPixel(1, 32, "", NORTH))
			. += overlay

/// Appendages render as a hairstyle's own pieces do: under-hat ones with the hair, trimmed only by masks that strictly cover them; over-hat ones above headwear, left out while strictly covered.
/datum/unit_test/custom_sprite_appendages_render/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.hairstyle = "Bald"
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	// Both pieces paint the top-left Back pixel, where every hat's mask trims.
	var/list/drawing = custom_sprite_appendage_fixture()
	drawing["dirs"] = list()
	// Neither white nor the hair colour, so the colour read back shows which one applied.
	drawing["tint"] = "#ff8800"
	drawing["appendages"]["1"]["dirs"] = list("1" = "r11[repeat_string(68, "f0")]30")
	drawing["appendages"]["2"]["dirs"] = list("1" = "r11[repeat_string(68, "f0")]30")
	human.dna.custom_hair = drawing
	head.copy_appearance_from(human)
	var/list/under = custom_sprite_test_appendage_overlays(head, -HAIR_LAYER)
	var/list/over = custom_sprite_test_appendage_overlays(head, -OUTER_HAIR_LAYER)
	TEST_ASSERT(length(under) == 1 && length(over) == 1, "Bald hair with only appendages must draw one on the hair layer and one above headwear")
	var/image/tip = over[1]
	TEST_ASSERT(tip.color == "#ff8800" && (tip.appearance_flags & RESET_COLOR), "Tinted appendages keep the drawing's filter, not the hair colour")
	var/found_glow = FALSE
	for(var/image/overlay as anything in head.get_hair_overlays())
		if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE && overlay.layer == -HAIR_LAYER && json_encode(overlay.color) == json_encode(GLOB.emissive_color))
			found_glow = TRUE
	TEST_ASSERT(found_glow, "The ponytail's own glowing Back view must add a glow mask")
	human.hair_masks = list(allocate(/datum/hair_mask/standard_hat_middle))
	TEST_ASSERT(length(custom_sprite_test_appendage_overlays(head, -HAIR_LAYER)) == 1, "A crown-only hat leaves the back of the head's under-hat piece whole")
	TEST_ASSERT(length(custom_sprite_test_appendage_overlays(head, -OUTER_HAIR_LAYER)) == 1, "A crown-only hat shows the back of the head's over-hat piece")
	human.hair_masks = list(allocate(/datum/hair_mask/standard_hat_low))
	TEST_ASSERT(!length(custom_sprite_test_appendage_overlays(head, -HAIR_LAYER)), "A hat that covers the back of the head trims its under-hat piece like hair")
	TEST_ASSERT(!length(custom_sprite_test_appendage_overlays(head, -OUTER_HAIR_LAYER)), "A hat that covers the back of the head hides its over-hat piece")
	head.custom_hair["appendages"]["1"]["zone"] = HAIR_APPENDAGE_HANGING_REAR
	TEST_ASSERT(length(custom_sprite_test_appendage_overlays(head, -HAIR_LAYER)) == 1, "Hair down the back stays whole under a fedora")
	human.hair_masks = list(allocate(/datum/hair_mask/winterhood))
	TEST_ASSERT(!length(custom_sprite_test_appendage_overlays(head, -HAIR_LAYER)), "A hood covers hair down the back")
	human.hair_masks = null
	head.custom_hair["tint"] = null
	head.hair_color = "#224466"
	var/list/untinted = custom_sprite_test_appendage_overlays(head, -OUTER_HAIR_LAYER)
	var/image/untinted_tip = length(untinted) ? untinted[1] : null
	TEST_ASSERT(untinted_tip && untinted_tip.color == "#224466" && !(untinted_tip.appearance_flags & RESET_COLOR), "Untinted appendages follow the hair colour")

/// Appendage layers load, paint, save and undo as one draft with the hair.
/datum/unit_test/custom_sprite_appendages_workspace/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, custom_sprite_appendage_fixture(), list())
	TEST_ASSERT_EQUAL(length(workspace.layers), 3, "The hair and its two appendages load as three layers")
	TEST_ASSERT_EQUAL(json_encode(workspace.serialize_drawing()), json_encode(custom_sprite_appendage_fixture()), "The layers save back as the drawing they came from")
	var/list/ponytail = workspace.layers[2]
	var/list/tip = workspace.layers[3]
	var/list/stroke = list("type" = "pencil", "layer" = 3, "layerId" = ponytail["id"], "dir" = "2", "color" = "#ff0000ff", "points" = list(list(5, 5)))
	TEST_ASSERT(!workspace.new_transaction(stroke.Copy()), "A stroke naming another layer's id is refused")
	stroke["layerId"] = tip["id"]
	TEST_ASSERT(workspace.new_transaction(stroke), "A stroke naming its layer lands")
	TEST_ASSERT(tip["data"]["2"][6][6] == "#ff0000ff" && tip["edited"]["2"], "It paints that layer and marks the view painted")
	TEST_ASSERT(!workspace.new_transaction(list("type" = "pencil", "layer" = 4, "layerId" = "a9", "dir" = "2", "color" = "#ff0000ff", "points" = list(list(1, 1)))), "A layer that doesn't exist is refused")
	var/copy_id = workspace.copy_appendage_over(2)
	var/list/copy = workspace.layers[3]
	TEST_ASSERT(copy_id && copy["outer"] && copy["zone"] == HAIR_APPENDAGE_REAR && copy["name"] == "Ponytail (over)" && workspace.layers[4] == tip, "Copy to over-hat layer puts an over-hat copy right after the piece")
	TEST_ASSERT_EQUAL(json_encode(copy["data"]), json_encode(ponytail["data"]), "The copy has the same pixels")
	copy["data"]["1"][32][32] = "#00000000"
	TEST_ASSERT(ponytail["data"]["1"][32][32] != "#00000000", "The copy's pixels are its own")
	TEST_ASSERT(isnull(workspace.add_appendage()) && isnull(workspace.copy_appendage_over(2)), "No more than [CUSTOM_SPRITE_MAX_APPENDAGES] appendages")
	TEST_ASSERT_EQUAL(workspace.step_points(workspace.last_transaction()), workspace.width * workspace.height * 4, "A layer kept whole in the history counts all its pixels")
	workspace.undo()
	TEST_ASSERT(length(workspace.layers) == 3 && !workspace.layer_index(copy_id), "Undo takes the copy away")
	var/added_id = workspace.add_appendage()
	TEST_ASSERT(added_id && length(workspace.layers) == 4, "Adding an appendage adds an empty layer")
	TEST_ASSERT_EQUAL(length(workspace.serialize_drawing()["appendages"]), 2, "An unpainted appendage isn't saved")
	workspace.undo()
	workspace.redo()
	TEST_ASSERT_EQUAL(workspace.layer_index(added_id), 4, "Redo puts it back under the same id")
	TEST_ASSERT(workspace.set_appendage(2, "zone", HAIR_APPENDAGE_HANGING_REAR) && workspace.serialize_drawing()["appendages"]["1"]["zone"] == HAIR_APPENDAGE_HANGING_REAR, "Moving an appendage changes where it saves as attached")
	TEST_ASSERT(!workspace.set_appendage(2, 1, "x"), "Only name, zone and kind can be set")
	workspace.undo()
	TEST_ASSERT_EQUAL(ponytail["zone"], HAIR_APPENDAGE_REAR, "Undo moves it back")
	TEST_ASSERT(workspace.remove_appendage(2) && workspace.layers[2] == tip, "Removing drops the layer, and the ones after it move up")
	workspace.undo()
	TEST_ASSERT(workspace.layers[2] == ponytail && workspace.layers[3] == tip, "Undo puts it back where it was")
	TEST_ASSERT(workspace.clear_direction("1", 2) && !ponytail["edited"]["1"] && workspace.edited_directions["2"] && tip["edited"]["1"], "Clear empties one layer's view and leaves the others")

/// A new base hairstyle under painted appendages is one small step: the paint and the history before it stay, and the window's canvas isn't encoded again.
/datum/unit_test/custom_sprite_appendages_restyle/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Bald")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	workspace.update_palette(workspace.palette | "#12ab34")
	var/mask = custom_sprite_hardening_mask(custom_sprite_hardening_all_points(workspace.width, workspace.height), workspace.width, workspace.height)
	for(var/i in 1 to 3)
		var/id = workspace.add_appendage()
		for(var/direction in GLOB.custom_style_directions)
			workspace.new_transaction(list("type" = "pencil", "layer" = workspace.layer_index(id), "layerId" = id, "dir" = direction, "color" = "#12ab34ff", "mask" = mask))
	editor.ui_data(mock_client.mob)
	var/list/hair_views = workspace.canvas_views["hair"]
	TEST_ASSERT_EQUAL(length(workspace.canvas_views[workspace.layers[2]["id"]]), 1, "An appendage layer's canvas carries only the view the window shows")
	var/steps = length(workspace.undo_stack)
	var/painted = custom_sprite_hash(workspace.serialize_drawing())
	TEST_ASSERT(editor.apply_hairstyle(/datum/sprite_accessory/hair/bedhead::name) && editor.workspace == workspace, "Changing to a hairstyle of the same canvas size failed: [editor.transfer_error]")
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps + 1, "A new hairstyle is one more step, and the steps before it stay")
	TEST_ASSERT_EQUAL(workspace.step_points(workspace.last_transaction()), 0, "The step keeps no pixels")
	TEST_ASSERT_EQUAL(custom_sprite_hash(workspace.serialize_drawing()), painted, "The paint stays exactly as it was")
	editor.ui_data(mock_client.mob)
	TEST_ASSERT(workspace.canvas_views["hair"] == hair_views, "The window's canvas isn't encoded again for a new hairstyle")
	workspace.undo()
	TEST_ASSERT_EQUAL(workspace.hair_context["style"], "Bald", "Undo brings the old hairstyle back")
	workspace.redo()
	TEST_ASSERT_EQUAL(workspace.hair_context["style"], /datum/sprite_accessory/hair/bedhead::name, "Redo brings the new one back")
	TEST_ASSERT(workspace.remove_appendage(2), "The first appendage comes off")
	editor.ui_data(mock_client.mob)
	TEST_ASSERT(workspace.canvas_views["hair"] == hair_views, "Removing an appendage leaves the rest of the window's canvas as encoded")
	editor.finish(FALSE)

/// Growing and shrinking the canvas keeps every appendage layer in its place under its id, painted or not, and the paint where it sits on the head.
/datum/unit_test/custom_sprite_appendages_resize/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Bald")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	workspace.update_palette(workspace.palette | "#12ab34")
	var/unpainted = workspace.add_appendage()
	var/painted = workspace.add_appendage()
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 3, "layerId" = painted, "dir" = "2", "color" = "#12ab34ff", "points" = list(list(4, 31)))), "The second appendage takes paint")
	var/saved = json_encode(workspace.serialize_drawing())
	TEST_ASSERT(editor.apply_hairstyle(CUSTOM_SPRITE_TALL_HAIRSTYLE), "Picking the tall base failed: [editor.transfer_error]")
	TEST_ASSERT(editor.workspace == workspace && workspace.height == CUSTOM_SPRITE_TALL_HEIGHT, "The draft grows where it is")
	TEST_ASSERT(workspace.layer_index(unpainted) == 2 && workspace.layer_index(painted) == 3, "Each appendage keeps its place and id, painted or not")
	TEST_ASSERT(!endswith(workspace.layers[3]["data"]["2"][CUSTOM_SPRITE_TALL_HEIGHT][5], "00"), "The paint keeps its place on the head")
	TEST_ASSERT(!length(workspace.undo_stack), "History starts over")
	TEST_ASSERT(editor.apply_hairstyle("Bald") && workspace.height == 32, "Paint that fits shrinks the canvas back")
	TEST_ASSERT_EQUAL(json_encode(workspace.serialize_drawing()), saved, "Back on the normal canvas, the draft saves exactly as it did")
	editor.finish(FALSE)

/// Only layers, zones, kinds, names and hats the window may name reach the draft; the preview wears a tried-on hat.
/datum/unit_test/custom_sprite_appendages_editor/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/hair_context = editor.workspace.hair_context
	QDEL_NULL(editor.workspace)
	editor.workspace = new(null, list("#ffffff"), null)
	editor.workspace.hair_context = hair_context
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/list/hats = editor.ui_static_data(mock_client.mob)["tryOnHats"]
	TEST_ASSERT_EQUAL(length(hats), length(GLOB.custom_hair_try_on_hats), "Every Try on hat reaches the window")
	TEST_ASSERT_EQUAL(length(hats["fedora"]["masks"]["2"]), editor.workspace.height, "Each hat's mask rows cover the canvas")
	TEST_ASSERT_EQUAL(hats["fedora"]["strict"], HAIR_APPENDAGE_TOP | HAIR_APPENDAGE_LEFT | HAIR_APPENDAGE_RIGHT | HAIR_APPENDAGE_REAR, "The fedora's coverage comes from its mask")
	var/palette_color = "#ffffffff"
	TEST_ASSERT(editor.ui_act("addAppendage", list(), ui, null), "Adding an appendage layer updates the window")
	var/list/data = editor.ui_data(mock_client.mob)
	var/list/appendages = data["appendages"]
	TEST_ASSERT(length(appendages) == 1 && data["focusLayer"] == appendages[1]["id"], "The new layer is listed and the window switches to it")
	TEST_ASSERT(isnull(editor.ui_data(mock_client.mob)["focusLayer"]), "The switch is asked for once")
	var/id = appendages[1]["id"]
	for(var/list/bad in list(list("id" = "a99", "name" = "x"), list("id" = 2, "name" = "x"), list("id" = id, "name" = repeat_string(300, "a")), list("id" = id, "name" = "<b></b>")))
		TEST_ASSERT(!editor.ui_act("renameAppendage", bad, ui, null), "A rename of an unknown layer or to an unusable name is refused")
	TEST_ASSERT(editor.ui_act("renameAppendage", list("id" = id, "name" = "  Big   bun "), ui, null) && editor.workspace.layers[2]["name"] == "Big bun", "A rename is cleaned up")
	TEST_ASSERT(!editor.ui_act("setAppendageZone", list("id" = id, "zone" = HAIR_APPENDAGE_TOP | HAIR_APPENDAGE_REAR), ui, null) && !editor.ui_act("setAppendageZone", list("id" = id, "zone" = "16"), ui, null), "A zone must be one known bit")
	TEST_ASSERT(editor.ui_act("setAppendageZone", list("id" = id, "zone" = HAIR_APPENDAGE_TOP), ui, null), "A known zone is taken")
	TEST_ASSERT(!editor.ui_act("setAppendageKind", list("id" = id, "outer" = 2), ui, null), "An appendage sits under or over hats, nothing else")
	TEST_ASSERT(!editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 2, "layerId" = "hair", "dir" = "2", "color" = palette_color, "points" = list(list(0, 0)))), ui, null) || !editor.workspace.layers[2]["edited"]["2"], "A stroke naming the wrong layer changes nothing")
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 2, "layerId" = id, "dir" = "2", "color" = palette_color, "points" = list(list(0, 0)))), ui, null)
	TEST_ASSERT(editor.workspace.layers[2]["edited"]["2"], "A stroke naming its layer paints it")
	editor.set_try_on(1)
	TEST_ASSERT(isnull(editor.try_on), "A hat named by position is refused")
	editor.ui_act("setTryOn", list("hat" = "fedora"), ui, null)
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(editor.try_on == "fedora" && findtext(editor.preview_hash, "fedora"), "The preview wears the tried-on hat")
	TEST_ASSERT(!length(editor.preview_body.hair_masks), "The hat comes off the preview body again, so guides never show it")
	TEST_ASSERT(editor.ui_act("saveDraft", list(), ui, null), "The draft saves")
	TEST_ASSERT(preferences.custom_hair?["appendages"]?["1"]?["name"] == "Big bun", "The saved hair carries the appendage")
	editor.finish(FALSE)
	var/datum/custom_sprite_editor/facial = new /datum/custom_sprite_editor/optimization_test(preferences, "facial_hair")
	var/datum/tgui/facial_ui = allocate(/datum/tgui, mock_client.mob, facial, "CustomFacialHairEditor")
	TEST_ASSERT(!facial.ui_act("addAppendage", list(), facial_ui, null) && length(facial.workspace.layers) == 1, "Facial hair takes no appendages")
	facial.finish(FALSE)

/// A saved slot's hair keeps its appendages through loading, saving and reaching the body; facial hair drops them.
/datum/unit_test/custom_sprite_appendages_persistence/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	var/test_path = "tmp/custom_sprite_appendages_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	rustg_file_write(json_encode(list("character1" = list("hair" = custom_sprite_appendage_fixture(), "facial_hair" = custom_sprite_appendage_fixture()))), test_path)
	var/datum/json_savefile/custom_sprites/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_custom_sprites()
	TEST_ASSERT_EQUAL(json_encode(preferences.custom_hair), json_encode(custom_sprite_appendage_fixture()), "Hair must load with its appendages, byte for byte")
	TEST_ASSERT(preferences.custom_facial_hair && !("appendages" in preferences.custom_facial_hair), "Facial hair must load without appendages")
	preferences.store_custom_sprite_slot(1)
	TEST_ASSERT_EQUAL(json_encode(store.get_entry("character1")["hair"]), json_encode(custom_sprite_appendage_fixture()), "Writing back must reproduce the hair and its appendages")
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_EQUAL(json_encode(head.custom_hair?["appendages"]), json_encode(custom_sprite_appendage_fixture()["appendages"]), "The head must carry the appendages as saved")
	head.custom_hair["appendages"]["1"]["name"] = "Changed"
	TEST_ASSERT_EQUAL(body.dna.custom_hair["appendages"]["1"]["name"], "Ponytail", "The head's copy must be its own")
	var/list/dimmed = custom_sprite_appearance_drawing(custom_sprite_appendage_fixture(), FALSE)
	TEST_ASSERT(!dimmed["appendages"]["1"]["emissive"]["1"], "With emissives disallowed, appendages don't glow either")
	store.path = null
	qdel(store)
