/// Runs the hair editor's actions without a connected client.
/datum/custom_sprite_editor/lifted_hair_test/can_edit(mob/user)
	return !closing

/// The topmost painted pixel of a hairstyle's front view, as list(x, y) counted from the bottom left.
/proc/custom_sprite_lifted_hair_test_top(datum/sprite_accessory/hair/hairstyle)
	var/icon/sheet = icon(hairstyle.icon, hairstyle.icon_state, SOUTH)
	for(var/y in sheet.Height() to 1 step -1)
		for(var/x in 1 to sheet.Width())
			if(sheet.GetPixel(x, y))
				return list(x, y)
	return null

/// Custom hair is lifted with a hairstyle drawn above the head, such as Afro (Huge), so the guide shows that hairstyle's own rows, whole.
/datum/unit_test/custom_sprite_lifted_hair_guide/Run()
	var/datum/sprite_accessory/hair/afro = SSaccessories.hairstyles_list[/datum/sprite_accessory/hair/afro_huge::name]
	var/list/top = custom_sprite_lifted_hair_test_top(afro)
	TEST_ASSERT(top && top[2] + afro.y_offset > 32, "Afro (Huge) should reach above the tile the body stands on")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], afro.name)
	var/datum/custom_sprite_editor/lifted_hair_test/editor = allocate(/datum/custom_sprite_editor/lifted_hair_test, preferences, "hair")
	TEST_ASSERT_EQUAL(editor.workspace.height, 32, "A lifted hairstyle should keep the normal canvas")
	var/icon/guide = editor.guide_icon("2")
	TEST_ASSERT(guide.GetPixel(top[1], top[2]), "The guide should show the hairstyle's top row on the canvas row that paint there uses")
	TEST_ASSERT(editor.workspace.is_point_allowed(top[1] - 1, 32 - top[2], "2"), "The hairstyle's top row should be paintable")
	// A tall drawing over the same hairstyle keeps it on the same rows, with room above it.
	TEST_ASSERT(!preferences.commit_custom_style(custom_style_package("hair", null, custom_sprite_tall_hair_test_drawing(3, 2), null), preferences.default_slot), "The tall drawing should save")
	var/datum/custom_sprite_editor/lifted_hair_test/tall = allocate(/datum/custom_sprite_editor/lifted_hair_test, preferences, "hair")
	TEST_ASSERT_EQUAL(tall.workspace.height, 48, "A tall drawing should open the tall canvas")
	var/icon/tall_guide = tall.guide_icon("2")
	TEST_ASSERT(tall_guide.GetPixel(top[1], top[2]) && !tall_guide.GetPixel(top[1], top[2] + 1), "The tall canvas should show the hairstyle on the same rows, lifted once")
	// Facial hair isn't lifted, so its guide keeps the body's own rows.
	var/datum/custom_sprite_editor/lifted_hair_test/facial = allocate(/datum/custom_sprite_editor/lifted_hair_test, preferences, "facial_hair")
	TEST_ASSERT(facial.guide_urls["2"] == custom_sprite_render_views(facial.guide_appearance, 32)["2"], "A facial hair guide should keep the body's own rows")
