/// The poster the poster tests paint: its own pixels fill columns 6-27 of rows 5-28, so its margins take no paint.
#define GRAFFITI_POSTER_TEST_TYPE /obj/structure/sign/poster/official/nanotrasen_logo/directional/north

/**
 * Returns a one-pixel pencil stroke on the bottom layer, as the editor's window sends it.
 *
 * Arguments:
 * - column: The pixel's column.
 * - row: Its row, from the top.
 *
 * Returns:
 * - list: The spriteEditorCommand action's params.
 */
/proc/graffiti_poster_test_stroke(column, row)
	return list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = "#ff0000", "points" = list(list(column, row))))

/**
 * Freehand on a poster: the armed can opens the editor on the poster itself, whose canvas takes paint only on the
 * poster's own pixels, as the hair and markings editors keep paint to the body, with the poster beneath it. Closing it
 * charges the can, leaves the paint and keeps the piece as a plain draft. Taken down with wirecutters, the poster keeps
 * its graffiti out of sight, shows it again once hung, and washes it off.
 */
/datum/unit_test/graffiti_poster_freehand/Run()
	graffiti_editor_test_begin()
	var/list/turfs = graffiti_test_walls(1)
	TEST_ASSERT_EQUAL(length(turfs), 1, "The test room must have a wall between two floors to paint.")
	var/turf/wall = turfs[1]
	var/turf/floor = get_step(wall, SOUTH)
	var/obj/structure/sign/poster/poster = allocate(GRAFFITI_POSTER_TEST_TYPE, floor)
	var/list/held = graffiti_editor_test_painter(src, wall)
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	var/charges = can.charges_left
	var/list/look = graffiti_poster_look(poster)
	TEST_ASSERT(look && length(look["outside"]), "The test poster must show pixels and leave some clear.")
	can.graffiti_armed = "freehand"
	can.use_on(poster, painter, list())
	var/datum/custom_sprite_editor/graffiti/poster/editor = SSgraffiti.editors[painter.ckey]
	TEST_ASSERT(istype(editor) && editor.poster == poster && poster.graffiti_painter == editor, "A click on the poster with a can armed for freehand must open the editor on the poster.")
	var/list/static_data = editor.ui_static_data(painter)
	TEST_ASSERT_EQUAL(json_encode(static_data["drawMask"]), json_encode(look["mask"]), "The window must keep strokes to the poster's own pixels.")
	TEST_ASSERT_EQUAL(graffiti_art_hash(static_data["graffitiBackground"][1]), graffiti_art_hash(look["art"]), "The window must draw the poster beneath the canvas.")
	var/list/fields = editor.ui_data(painter)["graffiti"]
	TEST_ASSERT(fields["oneTile"] && fields["roundOnly"], "The window must show the poster's paint as one tile that lasts the round.")
	var/datum/tgui/ui = allocate(/datum/tgui, painter, editor, "GraffitiEditor")
	editor.ui_act("spriteEditorCommand", graffiti_poster_test_stroke(10, 10), ui, null)
	editor.ui_act("spriteEditorCommand", graffiti_poster_test_stroke(1, 1), ui, null)
	editor.run_deferred_work()
	TEST_ASSERT_EQUAL(editor.workspace.layers[1]["data"]["2"][2][2], "#00000000", "A stroke off the poster's pixels must be refused.")
	TEST_ASSERT(poster.graffiti && graffiti_art_pixels(poster.graffiti["art"]) == 1, "The first composite must show the one stroke on the poster.")
	// A window's stroke over the whole canvas, as a compact mask: 1,024 pixels, six a character.
	var/full = "[repeat_string(170, copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 64, 65))][copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 16, 17)]"
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = "#00ff00", "mask" = full)), ui, null)
	// Due now, whether it went in at once or waited for the stroke budget.
	COOLDOWN_RESET(editor, composite_cooldown)
	var/datum/custom_sprite_pace/pace = editor.pace()
	COOLDOWN_RESET(pace, spacing)
	COOLDOWN_RESET(pace, stroke_window)
	pace.stroke_pixels = 0
	editor.run_deferred_work()
	TEST_ASSERT(poster.graffiti && graffiti_art_pixels(poster.graffiti["art"]) == 1024 - length(look["outside"]), "A stroke over the whole canvas must paint the poster's own pixels and nothing else.")
	var/key = poster.graffiti["key"]
	TEST_ASSERT(SSgraffiti.art_icons[key], "The poster must draw its graffiti from the shared art icons.")
	editor.ui_close(painter)
	TEST_ASSERT_EQUAL(can.charges_left, charges - GRAFFITI_COST, "Ending the session must charge the can once.")
	TEST_ASSERT(poster.graffiti?["key"] == key && !poster.graffiti_painter, "The paint must stay on the poster, which no one paints now.")
	var/datum/graffiti_library/library = graffiti_library(painter.ckey)
	TEST_ASSERT(library.unfinished?["piece"] && isnull(library.unfinished["resume"]), "The unsaved piece must be kept as a plain draft, with nowhere to resume.")
	var/obj/item/poster/rolled = poster.roll_and_drop(floor, painter)
	var/obj/structure/sign/poster/carried = rolled?.poster_structure
	TEST_ASSERT(carried?.graffiti?["rolled"] && graffiti_art_hash(carried.graffiti["art"]) == key, "The rolled-up poster must carry the graffiti out of sight.")
	rolled.interact_with_atom(wall, painter, list())
	var/obj/structure/sign/poster/hung = locate() in floor
	TEST_ASSERT(hung == carried && hung.graffiti && !hung.graffiti["rolled"] && hung.graffiti["key"] == key, "Hung again, the poster must show the same graffiti.")
	hung.wash(CLEAN_WASH)
	TEST_ASSERT_NULL(hung.graffiti, "Washing the poster must take the graffiti off.")
	qdel(hung)

/**
 * Ends the test's editor, puts the registry and the library back.
 */
/datum/unit_test/graffiti_poster_freehand/Destroy()
	graffiti_editor_test_end()
	return ..()

/**
 * A paint job on a poster sprays a saved piece over the poster's own pixels only, and charges the can once. The same
 * art on two posters is one art, drawn from one icon.
 */
/datum/unit_test/graffiti_poster_paint_job/Run()
	graffiti_editor_test_begin()
	var/list/turfs = graffiti_test_walls(2)
	TEST_ASSERT_EQUAL(length(turfs), 2, "The test room must have two walls side by side between floors.")
	var/obj/structure/sign/poster/first = allocate(GRAFFITI_POSTER_TEST_TYPE, get_step(turfs[1], SOUTH))
	var/obj/structure/sign/poster/second = allocate(GRAFFITI_POSTER_TEST_TYPE, get_step(turfs[2], SOUTH))
	var/list/held = graffiti_editor_test_painter(src, turfs[1])
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	var/charges = can.charges_left
	// Red on every pixel of the canvas, margins and all.
	var/list/piece = graffiti_validate_piece(list("format" = GRAFFITI_FORMAT, "version" = GRAFFITI_FORMAT_VERSION, "name" = "Cover", "description" = "", "width" = GRAFFITI_WIDTH, "palette" = list("#ff0000"), "layers" = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid(repeat_string(1024, "1"), 1, 1024)),
	)))
	for(var/obj/structure/sign/poster/poster as anything in list(first, second))
		var/datum/graffiti_paint_job/poster/job = allocate(/datum/graffiti_paint_job/poster, painter, can, poster.loc, graffiti_copy_piece(piece), null, null, poster)
		// A test human's do_after ends at once, so the job finishes as it starts.
		TEST_ASSERT(job.start() && QDELETED(job), "The paint job must start and finish.")
	TEST_ASSERT(first.graffiti && second.graffiti, "Both posters must show the piece.")
	var/list/look = graffiti_poster_look(first)
	TEST_ASSERT_EQUAL(graffiti_art_pixels(first.graffiti["art"]), 1024 - length(look["outside"]), "The piece must cover the poster's own pixels and nothing else.")
	TEST_ASSERT_EQUAL(can.charges_left, charges - 2 * GRAFFITI_COST, "Each finished job must charge the can once.")
	TEST_ASSERT(second.graffiti["key"] == first.graffiti["key"] && SSgraffiti.art_icons[first.graffiti["key"]], "Two posters showing the same art must share its icon.")

/**
 * Puts the registry and the library back.
 */
/datum/unit_test/graffiti_poster_paint_job/Destroy()
	graffiti_editor_test_end()
	return ..()

#undef GRAFFITI_POSTER_TEST_TYPE
