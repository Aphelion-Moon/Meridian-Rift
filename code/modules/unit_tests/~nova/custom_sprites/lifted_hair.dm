/// Runs the hair editor's actions without a connected client, keeping every picture it publishes.
/datum/custom_sprite_editor/lifted_hair_test
	/// Pictures published since the list was last cleared, in order.
	var/list/published = list()

/datum/custom_sprite_editor/lifted_hair_test/can_edit(mob/user)
	return !closing

/datum/custom_sprite_editor/lifted_hair_test/publish_icon(icon/rendered)
	published += rendered
	return ..()

/// The topmost painted pixel of a hairstyle's front view, as list(x, y) counted from the bottom left.
/proc/custom_sprite_lifted_hair_test_top(datum/sprite_accessory/hair/hairstyle)
	var/icon/sheet = icon(hairstyle.icon, hairstyle.icon_state, SOUTH)
	for(var/y in sheet.Height() to 1 step -1)
		for(var/x in 1 to sheet.Width())
			if(sheet.GetPixel(x, y))
				return list(x, y)
	return null

/// Whether a picture reaches row `y`, counted from the bottom, and has paint at that pixel.
/proc/custom_sprite_lifted_hair_test_shows(icon/picture, x, y)
	return picture && picture.Height() >= y && picture.GetPixel(x, y)

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
	var/icon/guide = editor.guide_icons["2"]
	TEST_ASSERT(guide.GetPixel(top[1], top[2]), "The guide should show the hairstyle's top row on the canvas row that paint there uses")
	TEST_ASSERT(editor.workspace.is_point_allowed(top[1] - 1, 32 - top[2], "2"), "The hairstyle's top row should be paintable")
	// A tall drawing over the same hairstyle keeps it on the same rows, with room above it.
	TEST_ASSERT(!preferences.commit_custom_style(custom_style_package("hair", null, custom_sprite_tall_hair_test_drawing(3, 2), null), preferences.default_slot), "The tall drawing should save")
	var/datum/custom_sprite_editor/lifted_hair_test/tall = allocate(/datum/custom_sprite_editor/lifted_hair_test, preferences, "hair")
	TEST_ASSERT_EQUAL(tall.workspace.height, 48, "A tall drawing should open the tall canvas")
	var/icon/tall_guide = tall.guide_icons["2"]
	TEST_ASSERT(tall_guide.GetPixel(top[1], top[2]) && !tall_guide.GetPixel(top[1], top[2] + 1), "The tall canvas should show the hairstyle on the same rows, lifted once")
	// Facial hair isn't lifted, so its guide keeps the body's own rows.
	var/datum/custom_sprite_editor/lifted_hair_test/facial = allocate(/datum/custom_sprite_editor/lifted_hair_test, preferences, "facial_hair")
	TEST_ASSERT(icon2base64(facial.guide_icons["2"]) == icon2base64(custom_sprite_flat_icon(facial.guide_appearance, SOUTH)), "A facial hair guide should keep the body's own rows")

/// Pictures of a body wearing a hairstyle drawn above its head, such as Afro (Huge), show the whole hairstyle.
/datum/unit_test/custom_sprite_lifted_hair_pictures/Run()
	var/datum/sprite_accessory/hair/afro = SSaccessories.hairstyles_list[/datum/sprite_accessory/hair/afro_huge::name]
	var/list/top = custom_sprite_lifted_hair_test_top(afro)
	TEST_ASSERT(top && top[2] + afro.y_offset > 32, "Afro (Huge) should reach above the tile the body stands on")
	var/lifted_y = top[2] + afro.y_offset
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/preference/hairstyle = GLOB.preference_entries[/datum/preference/choiced/hairstyle]
	preferences.write_preference(hairstyle, afro.name)
	var/datum/custom_sprite_editor/lifted_hair_test/editor = allocate(/datum/custom_sprite_editor/lifted_hair_test, preferences, "hair")
	editor.published.Cut()
	editor.render_preview("2")
	TEST_ASSERT(custom_sprite_lifted_hair_test_shows(editor.published[1], top[1], lifted_y), "The editor's preview should show the whole hairstyle")
	// An imported style's previews, from an editor whose own hairstyle isn't lifted.
	preferences.write_preference(hairstyle, "Bald")
	var/datum/custom_sprite_editor/lifted_hair_test/bald = allocate(/datum/custom_sprite_editor/lifted_hair_test, preferences, "hair")
	var/list/afro_hair = bald.workspace.hair_context.Copy()
	afro_hair["style"] = afro.name
	bald.published.Cut()
	TEST_ASSERT(bald.show_candidate(custom_style_package("hair", null, null, afro_hair), "import"), "The style should preview: [bald.transfer_error]")
	bald.run_deferred_work()
	// Views are published in GLOB.cardinals order, so the front view is the second.
	TEST_ASSERT(custom_sprite_lifted_hair_test_shows(bald.published[2], top[1], lifted_y), "An imported style's front preview should show the whole hairstyle")
	// The mirror's pictures.
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.set_hairstyle(afro.name, update = TRUE)
	var/icon/picture = custom_sprite_flat_icon(new /mutable_appearance(body.appearance), SOUTH, 32, custom_sprite_preview_height(body))
	TEST_ASSERT(custom_sprite_lifted_hair_test_shows(picture, top[1], lifted_y), "Pictures of a body should show the whole hairstyle")
