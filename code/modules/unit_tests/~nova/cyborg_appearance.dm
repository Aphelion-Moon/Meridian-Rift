/// The native icon renderer must fulfill the authored preview manifest or static fallback.
/datum/unit_test/cyborg_independent_placement_groups/Run()
	var/list/store = cyborg_layout_default()
	store["active"]["penis"]["pixel_y"] = 15
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	store = cyborg_layout_action(store, list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "base", "direction" = EAST), "changes" = list("pixel_x" = 22, "pixel_y" = 7)), model_id)["store"]
	store = cyborg_layout_action(store, list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "base", "direction" = NORTH), "changes" = list("pixel_x" = 1, "pixel_y" = -3)), model_id)["store"]
	var/list/entry = store["active"]["penis"]
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, EAST, "idle", "none", FALSE, TRUE)["pixel_x"], 22, "North edits must not replace side placement.")
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, WEST, "idle", "none", TRUE, TRUE)["pixel_x"], -22, "Side placement must mirror west.")
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, NORTH, "idle", "none", FALSE, TRUE)["pixel_y"], -3, "North placement must remain independent.")
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, SOUTH, "idle", "none", FALSE, TRUE)["pixel_y"], 15, "Untouched south placement must retain legacy values.")
	store = cyborg_layout_action(store, list("operation" = "save", "name" = "Grouped"), null)["store"]
	TEST_ASSERT_EQUAL(store["presets"]["Grouped"]["penis"]["placement_groups"]["side"]["pixel_x"], 22, "Placement groups must survive preset normalization.")

/datum/unit_test/cyborg_wide_placement_and_sprite_reuse/Run()
	var/list/descriptor = cyborg_model_catalog()[cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")]
	var/list/entry = cyborg_layout_normalize_entry(list("pixel_x" = 12, "pixel_y" = 15, "rotation" = 20, "reuse_south" = TRUE, "advanced" = list("west" = list("pixel_x" = 3, "priority" = 2))))
	TEST_ASSERT(cyborg_mirror_placement(descriptor, entry, WEST), "Wide chassis must mirror base placement when facing west.")
	TEST_ASSERT(!cyborg_mirror_placement(descriptor, entry, EAST), "East is the unmirrored base view.")
	var/list/placement = cyborg_resolve_placement(entry, WEST, "idle", "none", TRUE)
	TEST_ASSERT_EQUAL(placement["pixel_x"], -9, "Mirrored base X must compose with literal view offsets.")
	TEST_ASSERT_EQUAL(placement["pixel_y"], 15, "Mirroring must not change Y.")
	TEST_ASSERT_EQUAL(placement["rotation"], -20, "Mirroring must reflect base rotation.")
	TEST_ASSERT_EQUAL(placement["priority"], 2, "Resolving placement must preserve layer order.")
	TEST_ASSERT_EQUAL(cyborg_part_sprite_direction(descriptor, entry, NORTH), SOUTH, "Opted-in north views must reuse south artwork.")
	entry["reuse_south"] = FALSE
	TEST_ASSERT_EQUAL(cyborg_part_sprite_direction(descriptor, entry, NORTH), NORTH, "Authored north art must remain available.")
	entry["mirror_sides"] = FALSE
	TEST_ASSERT(!cyborg_mirror_placement(descriptor, entry, WEST), "The per-part mirror opt-out must be honored.")
	var/list/store = cyborg_layout_default()
	store["active"]["vagina"] = entry
	store = cyborg_layout_action(store, list("operation" = "set", "slot" = "vagina", "field" = "reuse_south", "value" = TRUE), null)["store"]
	store = cyborg_layout_action(store, list("operation" = "save", "name" = "North reuse"), null)["store"]
	TEST_ASSERT(store["presets"]["North reuse"]["vagina"]["reuse_south"], "Sprite direction reuse must survive preset storage.")
	TEST_ASSERT(!store["presets"]["North reuse"]["vagina"]["mirror_sides"], "Mirror opt-out must survive preset storage.")
	var/list/metadata = cyborg_accessory_metadata("penis", "Dogborg Knotted", list("#ffffff", "#ffffff", "#ffffff"), "none", SOUTH, 2, FALSE)
	TEST_ASSERT_EQUAL(length(metadata["sizes"]), 7, "Skipping thumbnails must retain authored size choices.")
	for(var/list/size_entry as anything in metadata["sizes"])
		TEST_ASSERT_NULL(size_entry["icon"], "Hidden part inspectors must not generate size thumbnails.")

/datum/unit_test/cyborg_appearance_catalog_preserves_role_eligibility/Run()
	var/list/playable = cyborg_selectable_models()
	TEST_ASSERT_NULL(playable["Syndicate"], "Appearance support must not grant antagonist model selection.")
	TEST_ASSERT_NULL(playable["Ninja"], "Appearance support must not grant ninja model selection.")
	var/list/catalog = cyborg_model_catalog()
	var/syndicate_count = 0
	var/ninja_count = 0
	for(var/id in catalog)
		var/list/descriptor = catalog[id]
		if(descriptor["department"] == "Syndicate")
			syndicate_count++
		if(descriptor["department"] == "Ninja")
			ninja_count++
	TEST_ASSERT(syndicate_count > 0 && ninja_count > 0, "Both Syndicate and Ninja skin catalogs must be available for appearance previews.")
	TEST_NOTICE(src, "Appearance catalog: [length(catalog)] skins; Syndicate [syndicate_count], Ninja [ninja_count]. Closed galleries send zero thumbnails.")

/datum/unit_test/cyborg_creator_authored_animation_payloads/Run()
	var/list/catalog = cyborg_model_catalog()
	var/checked = 0
	for(var/id in catalog)
		var/list/descriptor = catalog[id]
		if(!cyborg_animation_anchor(descriptor, SOUTH, "idle"))
			continue // Other skins deliberately use manual placement and static previews.
		for(var/pose in descriptor["poses"])
			for(var/direction in GLOB.cardinals)
				for(var/moving in list(FALSE, TRUE))
					var/list/frames = cyborg_preview_animation(descriptor, direction, pose, moving, TRUE)
					if(!cyborg_animation_anchor(descriptor, direction, pose) || !length(cyborg_animation_frames(descriptor, direction, pose, moving)))
						TEST_ASSERT(!length(frames), "[id] [pose] borrowed an unauthored animation instead of using a static fallback.")
						TEST_ASSERT(findtext(cyborg_preview_body(descriptor, direction, pose), "iVBORw0KGgo") == 1, "[id] [pose] has no native PNG for its static fallback.")
						continue
					TEST_ASSERT(length(frames) && length(frames) <= 32, "[id] [pose] [dir2text(direction)] moving=[moving] has no bounded authored preview sequence.")
					for(var/list/frame as anything in frames)
						TEST_ASSERT(findtext(frame["body"], "iVBORw0KGgo") == 1, "[id] [pose] has no PNG body for an authored animation frame.")
						TEST_ASSERT(findtext(frame["occlusion"], "iVBORw0KGgo") == 1, "[id] [pose] has no PNG occlusion for an authored animation frame.")
						TEST_ASSERT(isnum(frame["x"]) && isnum(frame["y"]) && frame["delay"] > 0, "[id] [pose] has unusable preview anchor/timing data.")
					checked++
	TEST_ASSERT(checked > 0, "No authored models reached the real native preview renderer.")

/// Model defaults must survive display/disguise changes and remain department-specific.
/datum/unit_test/cyborg_model_identity_and_layout_defaults/Run()
	var/engineering_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/medical_id = cyborg_appearance_model_id(/obj/item/robot_model/medical, "Drake")
	var/list/catalog = cyborg_model_catalog()
	TEST_ASSERT(catalog[engineering_id] && catalog[medical_id], "The shared Drake fixture must be selectable for both engineering and medical models.")
	TEST_ASSERT_NOTEQUAL(engineering_id, medical_id, "Equal skin labels in different departments must not share defaults.")
	var/list/store = cyborg_layout_default()
	store["active"]["penis"]["pixel_x"] = 17
	var/list/result = cyborg_layout_action(store, list("operation" = "save_default"), engineering_id)
	TEST_ASSERT(result["store"], "An eligible model default should save.")
	store = result["store"]
	store["active"]["penis"]["pixel_x"] = 0
	result = cyborg_layout_action(store, list("operation" = "load_default"), engineering_id)
	TEST_ASSERT_EQUAL(result["store"]["active"]["penis"]["pixel_x"], 17, "A saved model default lost its slot layout.")
	// allocate() replaces a null atom location with the test turf. Exercise the
	// actual null-host catalog path and explicitly register fixture cleanup.
	var/obj/item/robot_model/engineering/model = new(null)
	allocated += model
	TEST_ASSERT_NULL(model.robot, "A catalog snapshot must not acquire a robot host.")
	TEST_ASSERT_NULL(model.atom_storage, "A catalog snapshot must not create model storage.")
	for(var/module in model.basic_modules)
		TEST_ASSERT(ispath(module), "A catalog snapshot instantiated equipment.")
	model.cyborg_customization_skin = "Drake"
	model.name = "Temporary disguise"
	model.cyborg_base_icon = "disguised"
	TEST_ASSERT_EQUAL(model.cyborg_customization_id(), engineering_id, "Mutable display fields changed the canonical identity.")

/datum/unit_test/cyborg_presets_refuse_overflow_and_implicit_overwrite/Run()
	var/list/store = cyborg_layout_default()
	for(var/index in 1 to 10)
		store["active"]["penis"]["pixel_x"] = index
		var/list/saved = cyborg_layout_action(store, list("operation" = "save", "name" = "Preset [index]"), null)
		store = saved["store"]
	var/list/rejected = cyborg_layout_action(store, list("operation" = "save", "name" = "Eleventh"), null)
	TEST_ASSERT(!rejected["store"], "An eleventh preset must be refused without dropping existing presets.")
	rejected = cyborg_layout_action(store, list("operation" = "save", "name" = "Preset 1"), null)
	TEST_ASSERT(!rejected["store"], "Overwriting a preset must be explicit.")
	var/list/loaded = cyborg_layout_action(store, list("operation" = "load", "name" = "Preset 1"), null)
	TEST_ASSERT_EQUAL(loaded["store"]["active"]["penis"]["pixel_x"], 1, "Later edits aliased the first preset.")
	TEST_ASSERT_EQUAL(length(loaded["store"]["presets"]), 10, "Loading a preset changed the preset library.")

/datum/unit_test/cyborg_pose_arousal_and_diagonal_fallback/Run()
	var/list/entry = cyborg_layout_normalize_entry(list("pixel_x" = 5, "pixel_y" = 3, "rotation" = 10,
		"advanced" = list("rest_alt_north" = list("pixel_x" = 2, "pixel_y" = 7, "rotation" = 20, "arousal" = list("full" = list("pixel_y" = -2, "visible" = FALSE))))))
	var/list/placement = cyborg_resolve_placement(entry, NORTHEAST, "rest_alt", "full")
	TEST_ASSERT_EQUAL(placement["pixel_x"], 7, "Base and directional offsets did not compose.")
	TEST_ASSERT_EQUAL(placement["pixel_y"], 1, "Sparse arousal override did not replace the directional value.")
	TEST_ASSERT_EQUAL(placement["rotation"], 30, "Base and pose rotations did not compose.")
	TEST_ASSERT(!placement["visible"], "A hidden directional arousal state became visible.")

/datum/unit_test/cyborg_size_preserves_hardware_and_is_idempotent/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	QDEL_NULL(robot.model)
	robot.model = new /obj/item/robot_model/engineering(robot)
	robot.model.cyborg_customization_skin = "Default - Treads"
	robot.cyborg_appearance_requested_size = 2
	robot.cyborg_customization_apply_size()
	robot.cyborg_customization_apply_size()
	TEST_ASSERT_EQUAL(robot.current_size, 2, "Repeated appearance application multiplied size.")
	robot.update_transform(1.25)
	robot.cyborg_customization_apply_size()
	TEST_ASSERT_EQUAL(robot.current_size, 2.5, "Appearance application erased or multiplied the hardware factor.")
	robot.cyborg_appearance_requested_size = 1.6
	robot.cyborg_customization_apply_size()
	TEST_ASSERT_EQUAL(robot.current_size, 2, "Changing the base size did not retain hardware.")
	TEST_ASSERT_EQUAL(cyborg_effective_base_size(2.5, list(TRAIT_R_WIDE)), 1.6, "Wide chassis base size must be capped.")
	TEST_ASSERT_EQUAL(cyborg_effective_base_size(0.75, list(TRAIT_R_SMALL)), 1, "Small chassis must not shrink further.")
	TEST_ASSERT_EQUAL(cyborg_effective_base_size(2, list(), FALSE), 1, "Special chassis must not inherit cosmetic size.")

/datum/unit_test/cyborg_visual_anatomy_capability_respects_exposure/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/list/descriptor = cyborg_model_catalog()[model_id]
	TEST_ASSERT(descriptor, "The visual anatomy fixture requires a real selectable model descriptor.")
	QDEL_NULL(robot.model)
	robot.model = new /obj/item/robot_model/engineering(robot)
	robot.model.cyborg_customization_skin = "Drake"
	robot.model.cyborg_base_icon = descriptor["icon_state"]
	robot.icon = descriptor["icon"]
	robot.icon_state = descriptor["icon_state"]
	robot.cyborg_appearance_model = model_id
	robot.cyborg_appearance_allowed = TRUE
	robot.cyborg_appearance_character_allowed = TRUE
	robot.cyborg_appearance_choices = list("penis" = "Visual Fixture")
	robot.cyborg_appearance_active = list("penis" = TRUE)
	robot.cyborg_appearance_arousal = list("penis" = "none")
	robot.cyborg_appearance_layout = cyborg_layout_default()["active"]
	var/list/capability = cyborg_part_capability(robot, "penis")
	TEST_ASSERT(cyborg_body_visuals_visible(robot), "The real active model fixture was not eligible for visual rendering.")
	TEST_ASSERT(capability["configured"] && capability["enabled"] && capability["exposed"], "An active visible configured display did not expose its visual capability.")
	TEST_ASSERT(length(cyborg_visual_anatomy_examine_lines(robot, TRUE)), "A viewer who opted in did not receive the exposed visual description.")
	TEST_ASSERT(!length(cyborg_visual_anatomy_examine_lines(robot, FALSE)), "A viewer who opted out received the visual description.")
	var/original_stat = robot.stat
	robot.stat = DEAD
	capability = cyborg_part_capability(robot, "penis")
	TEST_ASSERT(!capability["exposed"] && !length(cyborg_visual_anatomy_examine_lines(robot, TRUE)), "Dead cyborgs must hide visual anatomy descriptions.")
	robot.stat = original_stat
	TEST_ASSERT(cyborg_body_visuals_visible(robot), "Restoring living state did not restore visual eligibility.")
	ADD_TRAIT(robot, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	capability = cyborg_part_capability(robot, "penis")
	TEST_ASSERT(!capability["exposed"] && !length(cyborg_visual_anatomy_examine_lines(robot, TRUE)), "Immobilized cyborgs must hide visual anatomy descriptions.")
	REMOVE_TRAIT(robot, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(cyborg_body_visuals_visible(robot), "Removing immobilization did not restore visual eligibility.")
	robot.model.cyborg_base_icon = "disguised"
	capability = cyborg_part_capability(robot, "penis")
	TEST_ASSERT(!capability["exposed"] && !length(cyborg_visual_anatomy_examine_lines(robot, TRUE)), "A disguised cyborg must hide visual anatomy descriptions.")
	robot.model.cyborg_base_icon = descriptor["icon_state"]
	TEST_ASSERT(cyborg_body_visuals_visible(robot), "Restoring the model identity did not restore visual eligibility.")
	robot.cyborg_appearance_layout["penis"]["advanced"]["north"] = list("visible" = FALSE)
	robot.dir = NORTH
	capability = cyborg_part_capability(robot, "penis")
	TEST_ASSERT(!capability["exposed"], "A hidden directional display remained exposed.")
	TEST_ASSERT(!length(cyborg_visual_anatomy_examine_lines(robot, TRUE)), "A hidden directional display appeared in examine text.")

/datum/unit_test/cyborg_direct_accessory_states_and_cardinals/Run()
	var/list/colors = list("#ffffff", "#ffffff", "#ffffff")
	for(var/slot in cyborg_layout_supported_slots())
		var/list/catalog = cyborg_direct_accessories(slot)
		for(var/name in catalog)
			var/list/descriptor = catalog[name]
			var/list/states = icon_states(descriptor["icon"], 1)
			var/list/arousal_states = findtext(descriptor["state"], "AROUSAL") ? list("none", "partial", "full") : list("none")
			for(var/sprite_size in descriptor["sizes"])
				for(var/arousal in arousal_states)
					var/state = replacetext(descriptor["state"], "SIZE", "[sprite_size]")
					state = replacetext(state, "AROUSAL", arousal == "full" ? "2" : (arousal == "partial" ? "1" : "0"))
					var/list/channels = descriptor["channels"]
					var/found = FALSE
					if(channels)
						for(var/channel in channels)
							if("[state]_[channel]" in states)
								found = TRUE
					else
						found = (state in states)
					TEST_ASSERT(found, "[slot] direct accessory [name] size [sprite_size] declares no authored state for [arousal].")
					for(var/direction in list(NORTH, SOUTH, EAST, WEST))
						TEST_ASSERT(cyborg_direct_accessory_render(descriptor, colors, arousal, direction, sprite_size), "[slot] direct accessory [name] size [sprite_size] did not render [dir2text(direction)].")
	// The smallest alternate pair is authored with only its secondary color layer.
	var/list/alternate_channels = cyborg_accessory_color_channels("testicles", "Dogborg Pair (Alt)", 1, "none")
	TEST_ASSERT_EQUAL(length(alternate_channels), 1, "An unused primary color channel was exposed for the smallest alternate pair.")
	TEST_ASSERT_EQUAL(alternate_channels[1], 2, "The actual secondary channel lost its color index.")

/datum/unit_test/cyborg_isolated_pose_placement/Run()
	var/list/entry = cyborg_layout_normalize_entry(list("pixel_x" = 10, "advanced" = list(
		"south" = list("pixel_x" = 3),
		"idle_south" = list("pixel_x" = 7, "arousal" = list("full" = list("pixel_x" = 9))),
		"sit_south" = list("pixel_x" = 12),
	)))
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, SOUTH, "idle", "none")["pixel_x"], 17, "Standing edits must resolve their own pose key instead of changing the shared direction fallback.")
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, SOUTH, "rest", "none")["pixel_x"], 13, "Unedited poses must retain the legacy shared correction.")
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, SOUTH, "sit", "none")["pixel_x"], 22, "Another explicit pose must remain independent.")
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, SOUTH, "idle", "full")["pixel_x"], 19, "Arousal edits must resolve inside the selected pose.")
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(entry, SOUTH, "rest", "full")["pixel_x"], 13, "Arousal edits must not leak into other poses.")

/datum/unit_test/cyborg_shared_catalog_family_defaults/Run()
	var/list/models = cyborg_appearance_models()
	TEST_ASSERT_NULL(models["Syndicate Marauder"], "Identical Syndicate art must have one gallery department.")
	TEST_ASSERT_NULL(models["Ninja Medical"], "Ninja Medical must reuse the Ninja gallery.")
	TEST_ASSERT_NULL(models["Ninja Saboteur"], "Ninja Saboteur must reuse the Ninja gallery.")
	var/canonical = cyborg_appearance_model_id(/obj/item/robot_model/ninja, "Assault")
	TEST_ASSERT_EQUAL(cyborg_appearance_model_id(/obj/item/robot_model/ninja_saboteur, "Assault"), canonical, "In-round variants must resolve to the shared appearance identity.")
	var/list/store = cyborg_layout_default()
	var/old_id = "/obj/item/robot_model/ninja_saboteur#Assault"
	store["model_defaults"][old_id] = cyborg_layout_default_slots()
	store["model_defaults"][old_id]["penis"]["pixel_x"] = 19
	store = cyborg_layout_normalize(store)
	TEST_ASSERT_EQUAL(store["model_defaults"]?[canonical]?["penis"]?["pixel_x"], 19, "Existing duplicate-family defaults must migrate without losing placement.")
