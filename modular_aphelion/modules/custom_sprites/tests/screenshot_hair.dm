#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// A real saved hair file must render the same buns before and after an editor save/reopen.
/datum/unit_test/custom_sprite_saved_hair_screenshot/Run()
	var/fixture_path = "modular_aphelion/modules/custom_sprites/tests/fixtures/leia_buns.json"
	var/datum/json_savefile/custom_sprites/source = allocate(/datum/json_savefile/custom_sprites, fixture_path)
	var/list/slot = source.get_entry("character1")
	var/list/drawing = custom_sprite_validate(slot?["hair"])
	if(!drawing || length(drawing["dirs"]) != 4)
		return Fail("The saved Leia bun fixture must load four valid directional drawings.", __FILE__, __LINE__)
	var/mob/living/carbon/human/human = make_subject()
	var/icon/without_buns = render_portraits(human)
	human.dna.custom_hair = deep_copy_list(drawing)
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/icon/first_render = render_portraits(human)
	for(var/view in 0 to 3)
		var/changed = FALSE
		for(var/x in (view * 32 + 1) to (view * 32 + 32))
			for(var/y in 1 to 16)
				if(first_render.GetPixel(x, y) != without_buns.GetPixel(x, y))
					changed = TRUE
		if(!changed)
			Fail("The file-loaded buns must visibly extend Short Hair in view [view + 1].", __FILE__, __LINE__)
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, drawing, drawing["palette"], null)
	var/list/serialized = custom_sprite_validate(workspace.serialize_drawing())
	if(!serialized || !custom_sprite_test_same_pixels(custom_sprite_paint_icon(drawing), custom_sprite_paint_icon(serialized)))
		return Fail("Hydrating and serializing the saved file must preserve every bun pixel.", __FILE__, __LINE__)
	var/roundtrip_path = "data/custom_sprite_checks/leia_buns_[REF(src)].json"
	var/datum/json_savefile/custom_sprites/saved = allocate(/datum/json_savefile/custom_sprites, roundtrip_path)
	saved.set_entry("character1", list("hair" = serialized))
	saved.save()
	var/datum/json_savefile/custom_sprites/reopened = allocate(/datum/json_savefile/custom_sprites, roundtrip_path)
	var/list/reopened_slot = reopened.get_entry("character1")
	var/list/reopened_drawing = custom_sprite_validate(reopened_slot?["hair"])
	saved.path = null
	reopened.path = null
	custom_sprite_test_remove_sidecar(roundtrip_path)
	if(!reopened_drawing)
		return Fail("The serialized bun drawing must reopen through the real sidecar reader.", __FILE__, __LINE__)
	var/mob/living/carbon/human/fresh_human = make_subject(reopened_drawing)
	if(!same_portraits(first_render, render_portraits(fresh_human)))
		Fail("A freshly loaded character must render identical bun pixels in all four views.", __FILE__, __LINE__)
	human.dna.custom_hair = null
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	if(!same_portraits(without_buns, render_portraits(human)))
		Fail("Removing the saved drawing must reveal the original short haircut without baked-in buns.", __FILE__, __LINE__)
	human.dna.custom_hair = deep_copy_list(reopened_drawing)
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	if(!same_portraits(first_render, render_portraits(human)))
		Fail("Reapplying the saved file with warm caches must restore the exact same hair.", __FILE__, __LINE__)
	test_screenshot("leia_buns", first_render)
	var/reference_path = "code/modules/unit_tests/screenshots/custom_sprite_saved_hair_screenshot_leia_buns.png"
	if(fexists(reference_path) && !same_portraits(first_render, icon(file(reference_path))))
		Fail("The file-loaded Leia bun portraits differ from the committed screenshot reference.", __FILE__, __LINE__)

/datum/unit_test/custom_sprite_saved_hair_screenshot/proc/make_subject(list/drawing)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/dummy/consistent)
	human.gender = FEMALE
	human.underwear_visibility = UNDERWEAR_HIDE_ALL
	human.set_hairstyle(/datum/sprite_accessory/hair/short::name, update = FALSE)
	human.set_haircolor("#583820", update = FALSE)
	human.dna.custom_hair = drawing ? deep_copy_list(drawing) : null
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	return human

/// A plain PNG atlas makes every facing visible to the normal screenshot comparison runner.
/datum/unit_test/custom_sprite_saved_hair_screenshot/proc/render_portraits(mob/living/carbon/human/human)
	var/icon/portraits = icon('icons/blanks/32x32.dmi', "nothing")
	portraits.Crop(1, 1, 128, 16)
	var/column = 0
	for(var/direction in list(SOUTH, NORTH, EAST, WEST))
		human.setDir(direction)
		var/icon/portrait = getFlatIcon(human, defdir = direction, no_anim = TRUE)
		portrait.Crop(1, 17, 32, 32)
		portraits.Blend(portrait, ICON_OVERLAY, column * 32 + 1, 1)
		column++
	return portraits

/datum/unit_test/custom_sprite_saved_hair_screenshot/proc/same_portraits(icon/first, icon/second)
	if(!first || !second || first.Width() != second.Width() || first.Height() != second.Height())
		return FALSE
	for(var/x in 1 to first.Width())
		for(var/y in 1 to first.Height())
			if(first.GetPixel(x, y) != second.GetPixel(x, y))
				return FALSE
	return TRUE

#endif
