#define HALO_DMI 'modular_nova/master_files/icons/mob/sprite_accessory/halo.dmi'

/// Character setup's preview animates what animates, in patches of what moves: an icon state is read once a round for
/// which pixels change, a look shown before its states were read is drawn still and told when they have been, and a
/// halo's bob comes out as one patch a facing, the halo's own box.
/datum/unit_test/character_preview_animation/Run()
	// Reading: a halo bobs in every direction, an IPC's pink screen blinks but not from behind, and a still state is
	// never read.
	var/list/halo = read_state(HALO_DMI, "m_head_acc_halo_FRONT")
	TEST_ASSERT(islist(halo), "A halo must read as animated.")
	var/list/expected = list("1" = list(11, 36, 21, 39), "2" = list(11, 39, 21, 42), "4" = list(11, 38, 21, 42), "8" = list(12, 38, 22, 42))
	for(var/dir, box in expected)
		var/list/dir_result = halo["dirs"][dir]
		TEST_ASSERT(dir_result, "A halo must move facing [dir].")
		TEST_ASSERT_EQUAL(json_encode(dir_result["box"]), json_encode(box), "A halo's moving box facing [dir] must be its own.")
		TEST_ASSERT_EQUAL(json_encode(dir_result["changes"]), json_encode(list(TRUE, TRUE)), "Both of a halo's frames must differ from the one before.")
	TEST_ASSERT_EQUAL(json_encode(halo["delays"]), json_encode(list(500, 500)), "A halo's frames must show half a second each.")
	var/list/screen = read_state('modular_nova/master_files/icons/mob/sprite_accessory/ipc_screens.dmi', "m_ipc_screen_pink_FRONT_UNDER")
	TEST_ASSERT(islist(screen), "A blinking screen must read as animated.")
	TEST_ASSERT(isnull(screen["dirs"]["1"]), "A screen seen from behind must not move.")
	TEST_ASSERT_EQUAL(json_encode(screen["dirs"]["2"]["box"]), json_encode(list(14, 24, 18, 28)), "A screen's blink must be its moving box.")
	TEST_ASSERT_NULL(preview_animation_reading('icons/mob/human/bodyparts.dmi', "human_chest_m"), "A state with one frame must not be read.")

	steps()

	// A plain look draws nothing moving.
	var/mob/living/carbon/human/dummy/plain = character_preview_glow_test_body(src, FALSE)
	TEST_ASSERT_NULL(character_preview_walk(plain, animate = TRUE)["animation"], "A look with nothing animated must draw nothing moving.")

	// A halo's look, its states unread: drawn still, and waiting.
	var/mob/living/carbon/human/dummy/body = character_preview_glow_test_body(src, FALSE)
	body.dna.mutant_bodyparts[FEATURE_HEAD_ACCESSORY] = build_mutant_part("Halo", list("#ffcc33", "#ffcc33", "#ffcc33"))
	body.dna.species.regenerate_organs(body, visual_only = TRUE)
	body.update_body(is_creating = TRUE)
	for(var/state in list("m_head_acc_halo_FRONT", "m_head_acc_halo_BEHIND"))
		var/key = "[HALO_DMI]|[state]"
		GLOB.character_preview_animations -= key
		SScharacter_preview.readings -= key
	var/datum/preference_middleware/character_preview/drawing = new(null)
	var/list/walk = character_preview_walk(body, animate = TRUE)
	var/list/animation = walk["animation"]
	TEST_ASSERT(animation?["pending"], "A look whose animated states are unread must wait for them.")
	TEST_ASSERT_NULL(animation["json"], "A look whose animated states are unread must be drawn still.")
	SScharacter_preview.reading_waiters |= drawing
	SScharacter_preview.read_animations_now()
	TEST_ASSERT(drawing.animation_read, "A preview drawn still must be told once what it waited on has been read.")

	// Read, it moves: one region a facing, the halo's box, with one patch, the halo's frame 2.
	walk = character_preview_walk(body, animate = TRUE)
	animation = walk["animation"]
	TEST_ASSERT(!animation?["pending"], "A look whose states have been read must not wait.")
	var/list/moving_recipe = json_decode("{[jointext(animation["json"], "")]}")["moving"]
	TEST_ASSERT(moving_recipe, "What moves must come as one image's recipe.")
	var/list/laid = moving_recipe["transform"]
	TEST_ASSERT_EQUAL(length(laid), 1 + length(GLOB.character_preview_facings), "A halo must lay one patch for each facing into it, after sizing it.")
	for(var/index in 2 to length(laid))
		var/recipe_json = json_encode(laid[index]["icon"])
		TEST_ASSERT(findtext(recipe_json, "\"frame\":2"), "A halo's patch must show its second frame.")
		TEST_ASSERT(!findtext(recipe_json, "@"), "No mark may be left in a patch.")
		TEST_ASSERT(!findtext(recipe_json, "\"dir\":[UP]"), "Each patch must face its own way.")
	var/list/drawn = drawing.draw_preview(walk)
	TEST_ASSERT(drawn, "A moving drawing must come out.")
	var/list/moving = drawn["animation"]
	TEST_ASSERT(moving?["image"], "Patches unlike the facings in size must have an image of their own.")
	var/list/lefts = list()
	for(var/facing, regions in moving["facings"])
		TEST_ASSERT_EQUAL(length(regions), 1, "A halo's front and back must move as one region facing [facing].")
		var/list/region = regions[1]
		var/list/box = region["box"]
		TEST_ASSERT(box[1] >= 0 && box[2] >= 0 && box[1] + box[3] <= drawn["width"] && box[2] + box[4] <= drawn["height"], "A moving box must lie in the canvas (facing [facing]: [json_encode(box)]).")
		var/list/steps = region["steps"]
		TEST_ASSERT_EQUAL(json_encode(steps[1]), json_encode(list(-1, 500)), "A region's first step must be the facing as drawn.")
		TEST_ASSERT_EQUAL(steps[2][2], 500, "A halo's second step must show half a second.")
		lefts["[steps[2][1]]"] = TRUE
	TEST_ASSERT_EQUAL(length(lefts), length(GLOB.character_preview_facings), "Each facing's patch must be its own.")
	drawing.release_drawing(drawn["name"])
	qdel(drawing)

/// Reads a state at once, as SScharacter_preview reads it a frame at a time.
/datum/unit_test/character_preview_animation/proc/read_state(file, state)
	var/datum/preview_animation_reading/reading = preview_animation_reading(file, state)
	if(!reading)
		return null
	while(!reading.read_next())
		continue
	return reading.result()

/// Steps: leaves come round together, frames that look the same make no step, and a cap keeps fewer evenly.
/datum/unit_test/character_preview_animation/proc/steps()
	var/list/four = list("leaf" = 1, "frames" = list(1, 2, 3, 4), "starts" = list(0, 100, 200, 300), "shows" = list(TRUE, TRUE, TRUE, TRUE), "cycle" = 400)
	var/list/two = list("leaf" = 2, "frames" = list(1, 2), "starts" = list(0, 300), "shows" = list(TRUE, TRUE), "cycle" = 600)
	var/list/steps = preview_animation_steps(list(four, two))
	TEST_ASSERT_EQUAL(length(steps), 12, "Loops of 400 and 600 ms must come round together after 1200 ms, a step every 100 ms.")
	TEST_ASSERT_EQUAL(json_encode(steps[1]), json_encode(list(0, 100)), "The first step must start at once.")
	TEST_ASSERT_EQUAL(json_encode(steps[12]), json_encode(list(1100, 100)), "The last step must end as the loops come round.")
	var/alist/frames = preview_animation_frames_at(list(four, two), 0)
	TEST_ASSERT(frames[1] == 1 && frames[2] == 1, "The first step must be every first frame.")
	frames = preview_animation_frames_at(list(four, two), 300)
	TEST_ASSERT(frames[1] == 4 && frames[2] == 2, "At 300 ms the loops must show frames 4 and 2, not [frames[1]] and [frames[2]].")
	var/list/repeats = list("leaf" = 1, "frames" = list(1, 2, 3, 4), "starts" = list(0, 100, 200, 300), "shows" = list(TRUE, FALSE, TRUE, FALSE), "cycle" = 400)
	steps = preview_animation_steps(list(repeats))
	TEST_ASSERT_EQUAL(json_encode(steps), json_encode(list(list(0, 200), list(200, 200))), "Frames that look like the one before must make no step of their own.")
	TEST_ASSERT_EQUAL(preview_animation_frames_at(list(repeats), 200)[1], 3, "A step must show the frame it starts on.")
	var/list/many = list()
	for(var/index in 1 to 9)
		many += list(list(index, 10 * index))
	var/list/fewer = preview_animation_fewer_steps(many, 3)
	TEST_ASSERT_EQUAL(length(fewer), 4, "Kept to three steps after the first, there must be four.")
	TEST_ASSERT_EQUAL(json_encode(fewer[1]), json_encode(many[1]), "The first step must stay.")
	var/total = 0
	for(var/list/step_data as anything in fewer)
		total += step_data[2]
	TEST_ASSERT_EQUAL(total, 450, "Fewer steps must take as long in all.")

#undef HALO_DMI
