/** Personal authorization follows the owning mind even if another mind occupies its former core. */
/datum/unit_test/uplink_shell_authorization/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	operator.mind_initialize()
	var/mob/living/silicon/ai/core = allocate(/mob/living/silicon/ai, null, operator, null, null, TRUE)
	var/datum/mind/identity = core.mind
	var/datum/uplink_registry/registry = allocate(/datum/uplink_registry, identity, core)
	var/mob/living/carbon/human/uplink/body = allocate(/mob/living/carbon/human/uplink)
	body.set_species(/datum/species/synthetic)
	var/obj/item/organ/brain/cybernetic/ai/brain = new
	brain.Insert(body, movement_flags = DELETE_IF_REPLACED)
	body.registry = registry
	registry.observe_body(body)
	registry.refresh_binding()
	TEST_ASSERT(registry.authorize(body, brain, core), "The owning mind should be authorized for its registered shell.")

	identity.transfer_to(operator)
	TEST_ASSERT(!registry.authorize(body, brain, core), "An empty former core must not retain the departed mind's personal authorization.")
	identity.transfer_to(core)
	TEST_ASSERT(registry.authorize(body, brain, core), "Returning the owning mind should restore authorization without reissuing a shell.")

	var/mob/living/carbon/human/other_operator = allocate(/mob/living/carbon/human/consistent)
	other_operator.mind_initialize()
	other_operator.mind.transfer_to(core)
	TEST_ASSERT(!registry.authorize(body, brain, core), "A different mind in the core must not inherit the original mind's personal shell.")

/** Returning a cyborg shell preserves the native light and deployment cleanup. */
/datum/unit_test/uplink_cyborg_return/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	operator.mind_initialize()
	var/mob/living/silicon/ai/core = allocate(/mob/living/silicon/ai, null, operator, null, null, TRUE)
	var/datum/mind/identity = core.mind
	var/mob/living/silicon/robot/robot = allocate(/mob/living/silicon/robot)
	robot.make_shell(allocate(/obj/item/borg/upgrade/ai))
	robot.radio.recalculateChannels()
	var/initial_radio_channels = json_encode(robot.radio.channels)
	var/datum/ai_shell_session/session = new(core, robot)
	TEST_ASSERT(session.start(), "The fixture should deploy the AI mind into its cyborg shell.")
	robot.toggle_headlamp()
	TEST_ASSERT(robot.lamp_enabled, "The occupied shell must have a lit headlamp before return.")
	TEST_ASSERT(session.finish("Unit test return"), "The shell should return to its core.")
	TEST_ASSERT_EQUAL(identity.current, core, "The mind should return to its core.")
	TEST_ASSERT(!robot.deployed, "The cyborg must be marked unattended after return.")
	TEST_ASSERT(!robot.lamp_enabled, "Returning an AI must shut off the unattended cyborg's headlamp.")
	TEST_ASSERT_NULL(robot.mainframe, "Returning a cyborg must release its mainframe reference.")
	TEST_ASSERT_NULL(core.shell_session, "Return must clear the active session.")
	TEST_ASSERT_EQUAL(robot.builtInCamera.c_tag, robot.real_name, "Returning must restore the unattended camera tag.")
	TEST_ASSERT(!HAS_TRAIT(robot, TRAIT_LOUD_BINARY), "Returning must remove the deployed binary trait.")
	TEST_ASSERT_EQUAL(json_encode(robot.radio.channels), initial_radio_channels, "Returning must restore the cyborg's radio channels.")

	// The native fallback must use the same endpoint cleanup without requiring a session.
	robot.deploy_init(core)
	identity.transfer_to(robot)
	core.deployed_shell = robot
	ADD_TRAIT(robot, TRAIT_LOUD_BINARY, REF(core))
	robot.toggle_headlamp()
	robot.builtInCamera.c_tag = "Temporary camera tag"
	robot.undeploy()
	TEST_ASSERT_EQUAL(identity.current, core, "Native return must restore the AI mind.")
	TEST_ASSERT(!robot.deployed && !robot.lamp_enabled, "Native return must clear deployment and shut off the headlamp.")
	TEST_ASSERT_NULL(robot.mainframe, "Native return must release the mainframe after using it.")
	TEST_ASSERT_NULL(core.deployed_shell, "Native return must clear the core's shell binding.")
	TEST_ASSERT_EQUAL(robot.builtInCamera.c_tag, robot.real_name, "Native return must restore the camera tag.")
	TEST_ASSERT(!HAS_TRAIT(robot, TRAIT_LOUD_BINARY), "Native return must remove the deployed binary trait.")
	TEST_ASSERT_EQUAL(json_encode(robot.radio.channels), initial_radio_channels, "Native return must restore the cyborg's radio channels.")

/** Stowing a lit welder shuts down its combat properties immediately without restoring fuel. */
/datum/unit_test/uplink_toolkit_retraction/Run()
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/toolkit = allocate(/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink)
	var/obj/item/weldingtool/welder = locate() in toolkit
	TEST_ASSERT_NOTNULL(welder, "The issued toolkit should contain a welder.")
	welder.forceMove(run_loc_floor_bottom_left)
	toolkit.active_item = welder
	welder.switched_on(null)
	TEST_ASSERT(welder.welding, "The fixture's welder should be lit before retraction.")
	var/fuel_before = welder.get_fuel()
	TEST_ASSERT(toolkit.Retract(), "The extended tool should retract.")
	TEST_ASSERT(!welder.welding, "A stowed welder must stop welding.")
	TEST_ASSERT_EQUAL(welder.force, welder::force, "Retraction must restore the unlit force immediately.")
	TEST_ASSERT_EQUAL(welder.damtype, welder::damtype, "Retraction must restore the unlit damage type immediately.")
	TEST_ASSERT_EQUAL(welder.hitsound, welder::hitsound, "Retraction must restore the unlit hit sound.")
	TEST_ASSERT_EQUAL(welder.get_fuel(), fuel_before, "Retraction must not refill the welder.")

/** Live cosmetic changes replace prior presentation without replacing missing parts or consumed resources. */
/datum/unit_test/uplink_live_appearance/Run()
	var/datum/preferences/preferences = allocate(/datum/preferences, allocate(/datum/client_interface))
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	preferences.value_cache[/datum/preference/choiced/body_type] = MALE
	preferences.value_cache[/datum/preference/choiced/skin_tone] = "caucasian1"
	preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = TRUE
	preferences.value_cache[/datum/preference/toggle/mutant_toggle/tail] = TRUE
	preferences.value_cache[/datum/preference/choiced/mutant_choice/tail] = /datum/sprite_accessory/tails/felinid/cat::name
	var/datum/uplink_blueprint/blueprint = allocate(/datum/uplink_blueprint, preferences, "Test shell", FALSE)
	var/obj/effect/uplink_delivery/delivery = allocate(/obj/effect/uplink_delivery)
	var/mob/living/carbon/human/uplink/body = blueprint.build(delivery, null)
	TEST_ASSERT_NOTNULL(body, "A preview body must be constructed.")
	var/obj/item/bodypart/leg = body.get_bodypart(BODY_ZONE_L_LEG)
	leg.drop_limb(special = TRUE)
	var/obj/item/organ/brain/brain = body.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/organ/stomach = body.get_organ_slot(ORGAN_SLOT_STOMACH)
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink/toolkit = body.get_organ_by_type(/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink)
	var/obj/item/weldingtool/welder = locate() in toolkit
	welder.reagents.remove_reagent(/datum/reagent/fuel, 10)
	var/fuel_before = welder.get_fuel()
	body.nutrition = 123
	var/obj/item/organ/tail = body.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT_NOTNULL(tail, "The initial preview should have its selected tail.")

	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/synthetic
	preferences.value_cache[/datum/preference/choiced/mutant_choice/synth_chassis] = /datum/sprite_accessory/synth_chassis/human::name
	preferences.value_cache[/datum/preference/choiced/mutant_choice/synth_head] = /datum/sprite_accessory/synth_head/human::name
	preferences.value_cache[/datum/preference/color/mutant/synth_chassis] = "#ff0000"
	var/datum/uplink_blueprint/colored = allocate(/datum/uplink_blueprint, preferences, "Colored shell", FALSE)
	colored.apply_appearance(body)
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/bodypart/head = body.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_EQUAL(chest.color_overrides?["[LIMB_COLOR_SYNTH]"], "#ff0000", "The colored chassis should establish its selected presentation color.")

	preferences.value_cache[/datum/preference/choiced/mutant_choice/synth_chassis] = /datum/sprite_accessory/synth_chassis/bishopcyberkinetics::name
	preferences.value_cache[/datum/preference/choiced/mutant_choice/synth_head] = /datum/sprite_accessory/synth_head/bishopcyberkinetics::name
	preferences.value_cache[/datum/preference/choiced/mutant_choice/tail] = SPRITE_ACCESSORY_NONE
	var/datum/uplink_blueprint/updated = allocate(/datum/uplink_blueprint, preferences, "Updated shell", FALSE)
	updated.apply_appearance(body)
	TEST_ASSERT_EQUAL(chest.limb_id, "bshipc", "A human-styled synthetic chest must accept its new chassis style.")
	TEST_ASSERT_EQUAL(head.limb_id, "bshipc", "A human-styled synthetic head must accept its new head style.")
	TEST_ASSERT_NULL(chest.color_overrides?["[LIMB_COLOR_SYNTH]"], "A fixed-color chassis must clear the previous synthetic color override.")
	var/datum/mutant_bodypart/tail_part = body.dna.mutant_bodyparts[FEATURE_TAIL]
	TEST_ASSERT_EQUAL(tail_part.name, SPRITE_ACCESSORY_NONE, "Selecting None must clear the previous tail appearance.")
	TEST_ASSERT_EQUAL(tail.bodypart_overlay.sprite_datum.name, SPRITE_ACCESSORY_NONE, "An existing tail's overlay must hide after selecting None.")

	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	preferences.value_cache[/datum/preference/choiced/body_type] = FEMALE
	preferences.value_cache[/datum/preference/choiced/skin_tone] = "albino"
	var/datum/uplink_blueprint/human_style = allocate(/datum/uplink_blueprint, preferences, "Updated shell", FALSE)
	human_style.apply_appearance(body)
	TEST_ASSERT_EQUAL(chest.limb_gender, "f", "A live body type change must refresh existing limb render data.")
	TEST_ASSERT_EQUAL(chest.skin_tone, "albino", "A live skin tone change must refresh existing limb render data.")
	TEST_ASSERT_NULL(body.get_bodypart(BODY_ZONE_L_LEG), "Cosmetic changes must not restore missing limbs.")
	TEST_ASSERT_EQUAL(body.get_organ_slot(ORGAN_SLOT_BRAIN), brain, "Cosmetic changes must preserve the installed brain.")
	TEST_ASSERT_EQUAL(body.get_organ_slot(ORGAN_SLOT_STOMACH), stomach, "Cosmetic changes must preserve the installed fuel cell.")
	TEST_ASSERT_EQUAL(body.get_organ_by_type(/obj/item/organ/cyberimp/arm/toolkit/toolset/uplink), toolkit, "Cosmetic changes must preserve the toolkit.")
	TEST_ASSERT_EQUAL(body.nutrition, 123, "Cosmetic changes must not recharge the shell.")
	TEST_ASSERT_EQUAL(welder.get_fuel(), fuel_before, "Cosmetic changes must not refill the welder.")

/** Abandoned private outputs are deleted together; published outputs survive container disposal. */
/datum/unit_test/uplink_provisional_cleanup/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	operator.mind_initialize()
	var/mob/living/silicon/ai/core = allocate(/mob/living/silicon/ai, null, operator, null, null, TRUE)
	var/datum/uplink_registry/registry = allocate(/datum/uplink_registry, core.mind, core)
	var/initial_outcome = registry.loadout_outcome
	var/obj/effect/uplink_delivery/delivery = allocate(/obj/effect/uplink_delivery)
	var/mob/living/carbon/human/uplink/body = new(delivery)
	var/obj/item/storage/briefcase/empty/overflow = new(delivery)
	var/obj/item/cane/item = new(overflow)
	registry.provisional_delivery = delivery
	registry.provisional_body = body
	registry.issuing = TRUE
	var/request_before = registry.request_generation
	registry.clear_candidate()
	TEST_ASSERT(!QDELETED(delivery) && !QDELETED(body), "Canceling during construction must let the builder release its own outputs.")
	TEST_ASSERT_EQUAL(registry.request_generation, request_before + 1, "Canceling during construction must invalidate its request token.")
	registry.issuing = FALSE
	registry.clear_candidate()
	TEST_ASSERT(QDELETED(body) && QDELETED(overflow) && QDELETED(item), "Abandoning a preview must delete all its private outputs.")
	TEST_ASSERT_NULL(registry.provisional_body, "Cleanup must release the preview body reference.")
	TEST_ASSERT_NULL(registry.provisional_delivery, "Cleanup must release the private container reference.")
	TEST_ASSERT_EQUAL(registry.loadout_outcome, initial_outcome, "Abandoning a preview must not spend the loadout decision.")

	delivery = allocate(/obj/effect/uplink_delivery)
	body = new(delivery)
	overflow = new(delivery)
	item = new(overflow)
	for(var/atom/movable/output as anything in delivery.contents.Copy())
		output.forceMove(run_loc_floor_bottom_left)
	qdel(delivery)
	TEST_ASSERT(!QDELETED(body) && !QDELETED(overflow) && !QDELETED(item), "Disposing an emptied delivery container must preserve published outputs and their contents.")

/** An explicit Uplink suitcase preserves the baseline outfit and preference values. */
/datum/unit_test/uplink_loadout_container/Run()
	var/datum/preferences/preferences = allocate(/datum/preferences, allocate(/datum/client_interface))
	preferences.value_cache[/datum/preference/choiced/loadout_override_preference] = LOADOUT_OVERRIDE_BACKPACK
	preferences.value_cache[/datum/preference/loadout_index] = "Uplink test"
	preferences.value_cache[/datum/preference/loadout] = list("Uplink test" = list(/obj/item/clothing/gloves/color/black = list(INFO_NAMED = "Shell gloves")))
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/storage/briefcase/empty/overflow = allocate(/obj/item/storage/briefcase/empty)
	body.equip_outfit_and_loadout(/datum/outfit/uplink_shell, preferences, equipping_job = SSjob.get_job_type(/datum/job/ai), uplink_container = overflow)
	TEST_ASSERT(locate(/obj/item/clothing/gloves/color/black) in overflow, "Selected personal items must go into the supplied suitcase regardless of the outfit override preference.")
	var/obj/item/clothing/gloves/selected_gloves = locate() in overflow
	TEST_ASSERT_EQUAL(selected_gloves.name, "Shell gloves", "Suitcase items must retain their selected preset's customizations.")
	TEST_ASSERT_NULL(body.gloves, "Suitcase delivery must not equip the selected personal gloves.")
	TEST_ASSERT(istype(body.w_uniform, /obj/item/clothing/under/color/grey), "Suitcase delivery must retain the baseline uniform.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/loadout_override_preference), LOADOUT_OVERRIDE_BACKPACK, "Explicit delivery must not rewrite the player's loadout preference.")

/** Camera reads reject unavailable bodies immediately, before the next camera update tick. */
/datum/unit_test/uplink_camera_availability/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	operator.mind_initialize()
	var/mob/living/silicon/ai/core = allocate(/mob/living/silicon/ai, null, operator, null, null, TRUE)
	var/datum/uplink_registry/registry = allocate(/datum/uplink_registry, core.mind, core)
	var/mob/living/carbon/human/uplink/body = allocate(/mob/living/carbon/human/uplink)
	body.registry = registry
	registry.observe_body(body)
	body.uplink_camera = new(body)
	body.nutrition = NUTRITION_LEVEL_FULL
	body.update_uplink_camera()
	TEST_ASSERT(body.uplink_camera.can_use(), "A live registered body on the floor should have an available camera.")
	body.nutrition = 0
	TEST_ASSERT(!body.uplink_camera.can_use(), "Exhausted power must deny camera use before the next update tick.")
	body.nutrition = NUTRITION_LEVEL_FULL
	body.stat = DEAD
	TEST_ASSERT(!body.uplink_camera.can_use(), "A dead body must deny camera use before the next update tick.")
	body.stat = initial(body.stat)
	body.retired = TRUE
	TEST_ASSERT(!body.uplink_camera.can_use(), "Retirement must immediately deny camera use.")
	body.retired = FALSE
	var/obj/effect/uplink_delivery/container = allocate(/obj/effect/uplink_delivery)
	body.forceMove(container)
	TEST_ASSERT(!body.uplink_camera.can_use(), "Contained bodies must not expose their surroundings through the camera.")
	body.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(body.uplink_camera.can_use(), "Returning an authorized body to the floor should restore its feed.")
	core.stat = DEAD
	TEST_ASSERT(!body.uplink_camera.can_use(), "Core death must immediately deny the personal feed.")

/** Saved synthetic assemblies retain external anatomy, body-changing quirks and limb-specific styles. */
/datum/unit_test/uplink_saved_assembly/Run()
	var/datum/client_interface/player = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences, player)
	player.prefs = preferences
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/synthetic
	preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = TRUE
	var/list/configurations = list(
		list("chassis" = "Lizard Chassis", "head" = "Lizard Head", "taur" = "Orca", "wings" = SPRITE_ACCESSORY_NONE),
		list("chassis" = "Lizard Chassis", "head" = "Mammal Head", "taur" = SPRITE_ACCESSORY_NONE, "wings" = "Dragon (Alt 2)"),
		list("chassis" = "Mammal Chassis", "head" = "Lizard Head", "taur" = "Big Legs, Stanced", "wings" = SPRITE_ACCESSORY_NONE),
	)
	for(var/index in 1 to length(configurations))
		var/list/configuration = configurations[index]
		preferences.value_cache[/datum/preference/choiced/mutant_choice/synth_chassis] = configuration["chassis"]
		preferences.value_cache[/datum/preference/choiced/mutant_choice/synth_head] = configuration["head"]
		preferences.value_cache[/datum/preference/choiced/mutant_choice/taur] = configuration["taur"]
		preferences.value_cache[/datum/preference/toggle/mutant_toggle/taur] = configuration["taur"] != SPRITE_ACCESSORY_NONE
		preferences.value_cache[/datum/preference/choiced/mutant_choice/wings] = configuration["wings"]
		preferences.value_cache[/datum/preference/toggle/mutant_toggle/wings] = configuration["wings"] != SPRITE_ACCESSORY_NONE
		preferences.value_cache[/datum/preference/choiced/digitigrade_legs] = index < 3 ? DIGITIGRADE_LEGS : NORMAL_LEGS
		preferences.value_cache[/datum/preference/numeric/body_size] = 1.5
		preferences.all_quirks = index < 3 ? list("Oversized", "Overweight", "Pseudobulbar Affect") : list("Pseudobulbar Affect")
		var/datum/uplink_blueprint/blueprint = allocate(/datum/uplink_blueprint, preferences, "Assembly fixture", FALSE)
		var/obj/effect/uplink_delivery/delivery = allocate(/obj/effect/uplink_delivery)
		var/mob/living/carbon/human/uplink/body = blueprint.build(delivery, null, player)
		TEST_ASSERT_NOTNULL(body, "Configuration [index] must build.")
		TEST_ASSERT_NOTNULL(blueprint.preview_view?.body, "Configuration [index] must retain a native visual-quirk preview.")
		body.forceMove(run_loc_floor_bottom_left)
		blueprint.apply_quirks(body, visual_only = TRUE)
		var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
		var/obj/item/bodypart/head = body.get_bodypart(BODY_ZONE_HEAD)
		var/datum/sprite_accessory/chassis_style = SSaccessories.sprite_accessories[FEATURE_SYNTH_CHASSIS][configuration["chassis"]]
		var/datum/sprite_accessory/head_style = SSaccessories.sprite_accessories[FEATURE_SYNTH_HEAD][configuration["head"]]
		TEST_ASSERT_EQUAL(chest.limb_id, chassis_style.icon_state, "The saved chassis must style the issued chest.")
		TEST_ASSERT_EQUAL(head.limb_id, head_style.icon_state, "The saved head must style the issued head independently.")
		TEST_ASSERT_EQUAL(!!body.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), configuration["taur"] != SPRITE_ACCESSORY_NONE, "The enabled taur must be installed as physical anatomy.")
		TEST_ASSERT_EQUAL(!!body.get_organ_slot(ORGAN_SLOT_EXTERNAL_WINGS), configuration["wings"] != SPRITE_ACCESSORY_NONE, "Enabled wings must be installed as physical anatomy.")
		TEST_ASSERT_EQUAL(body.dna.features["body_size"], index < 3 ? 2 : 1.5, "Oversized and the ordinary saved size must both survive assembly.")
		TEST_ASSERT_EQUAL(blueprint.preview_view.body.dna.current_body_size, body.dna.current_body_size, "The native preview must preserve the issued body's scale transform.")
		blueprint.apply_quirks(body)
		if(index < 3)
			TEST_ASSERT(body.has_quirk(SSquirks.quirks["Overweight"]), "Nonvisual quirks must also be installed.")
		var/obj/item/organ/brain/cybernetic/ai/brain = body.get_organ_slot(ORGAN_SLOT_BRAIN)
		TEST_ASSERT(brain.is_sufficiently_augmented(), "Saved anatomy and quirks must retain a compatible AI body.")
		qdel(body)

	preferences.augments = list(AUGMENT_SLOT_L_ARM = /datum/augment_item/limb/l_arm/cyborg)
	preferences.augment_limb_styles = list(AUGMENT_SLOT_L_ARM = "Security")
	var/datum/uplink_blueprint/styled = allocate(/datum/uplink_blueprint, preferences, "Styled fixture", FALSE)
	preferences.augment_limb_styles[AUGMENT_SLOT_L_ARM] = "Standard"
	TEST_ASSERT_EQUAL(styled.preferences.augment_limb_styles[AUGMENT_SLOT_L_ARM], "Security", "The limb-style snapshot must be detached.")
	TEST_ASSERT(!styled.matches_preferences(preferences), "Changing a limb style must invalidate an unconfirmed preview.")
	var/obj/effect/uplink_delivery/delivery = allocate(/obj/effect/uplink_delivery)
	var/mob/living/carbon/human/uplink/body = styled.build(delivery, null)
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_EQUAL(arm.current_style, "Security", "Fresh assembly must install the selected augment style.")

/** Every destructive exit preserves belongings and safely returns the controlling AI. */
/datum/unit_test/uplink_scrap_contents/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	operator.mind_initialize()
	var/mob/living/silicon/ai/core = allocate(/mob/living/silicon/ai, null, operator, null, null, TRUE)
	var/datum/mind/identity = core.mind
	var/datum/uplink_registry/registry = allocate(/datum/uplink_registry, identity, core)
	for(var/exit_kind in list("retire", "death", "gib", "dust"))
		var/mob/living/carbon/human/uplink/body = allocate(/mob/living/carbon/human/uplink)
		body.set_species(/datum/species/synthetic)
		body.provisional = FALSE
		body.registry = registry
		body.registration_generation = registry.registration_generation
		var/obj/item/organ/brain/cybernetic/ai/brain = new
		brain.Insert(body, movement_flags = DELETE_IF_REPLACED)
		registry.observe_body(body)
		registry.refresh_binding()
		body.equipOutfit(/datum/outfit/uplink_shell)
		var/obj/item/storage/backpack/bag = body.back
		var/obj/item/cane/nested = new(bag)
		var/obj/item/cane/loose = new(body)
		var/obj/item/organ/stomach/carried_organ = new(body)
		var/obj/item/implant/storage/internal_bag = new
		internal_bag.implant(body, silent = TRUE, force = TRUE)
		var/obj/item/cane/internal_item = new(internal_bag)
		var/mob/living/carbon/human/occupant = allocate(/mob/living/carbon/human/consistent)
		occupant.forceMove(body)
		var/turf/floor = get_turf(body)
		var/datum/ai_shell_session/session = new(core, body, brain)
		TEST_ASSERT(session.start(), "The [exit_kind] fixture must be controlled before destruction.")
		switch(exit_kind)
			if("retire")
				body.retired = TRUE
				body.scrap_uplink()
			if("death")
				body.death()
				sleep(1 SECONDS)
			if("gib")
				body.gib()
			if("dust")
				body.dust()
		TEST_ASSERT(QDELETED(body), "[exit_kind] must dismantle the body.")
		TEST_ASSERT_EQUAL(identity.current, core, "[exit_kind] must return control before deletion.")
		TEST_ASSERT_NULL(core.uplink_resume_action, "[exit_kind] must leave no Resume action.")
		TEST_ASSERT(QDELETED(brain), "Installed control anatomy must not be duplicated as loose salvage.")
		for(var/atom/movable/item as anything in list(bag, loose, carried_organ, internal_item, occupant))
			TEST_ASSERT(!QDELETED(item) && item.loc == floor, "[exit_kind] must preserve [item] on the floor.")
		TEST_ASSERT(!QDELETED(nested) && nested.loc == bag, "Containers must retain their contents.")
		var/scrap_count = 0
		for(var/obj/effect/decal/remains/robot/uplink/scrap in floor)
			scrap_count++
			qdel(scrap)
		TEST_ASSERT_EQUAL(scrap_count, 1, "[exit_kind] must produce exactly one scrap heap.")

/** Brain surgery may temporarily hide Resume; deleting the body must delete the action itself. */
/datum/unit_test/uplink_resume_lifetime/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	operator.mind_initialize()
	var/mob/living/silicon/ai/core = allocate(/mob/living/silicon/ai, null, operator, null, null, TRUE)
	var/datum/uplink_registry/registry = allocate(/datum/uplink_registry, core.mind, core)
	var/mob/living/carbon/human/uplink/body = allocate(/mob/living/carbon/human/uplink)
	body.set_species(/datum/species/synthetic)
	body.registry = registry
	var/obj/item/organ/brain/cybernetic/ai/brain = new
	brain.Insert(body, movement_flags = DELETE_IF_REPLACED)
	registry.observe_body(body)
	registry.refresh_binding()
	var/datum/ai_shell_session/session = new(core, body, brain)
	TEST_ASSERT(session.start() && session.finish("Resume fixture"), "The fixture must complete a shell round trip.")
	var/datum/action/innate/uplink_resume/resume = core.uplink_resume_action
	TEST_ASSERT_NOTNULL(resume, "A surviving shell must have a Resume candidate.")
	TEST_ASSERT_EQUAL(resume.owner, core, "A usable body must expose Resume.")
	brain.Remove(body, special = TRUE)
	resume.refresh()
	TEST_ASSERT_NULL(resume.owner, "A brainless body must not expose Resume.")
	brain.Insert(body)
	registry.refresh_binding()
	TEST_ASSERT_EQUAL(resume.owner, core, "Compatible brain repair must restore Resume.")
	qdel(body)
	TEST_ASSERT(QDELETED(resume), "The action's target lifetime must follow the deleted body.")
	TEST_ASSERT_NULL(core.uplink_resume_action, "The core must not retain a stale action.")
	TEST_ASSERT_NULL(core.uplink_resume, "The core must not retain a stale resume reference.")

/** New AI controls register without defaults and cannot derive authority from ordinary cyborg linkage. */
/datum/unit_test/uplink_ai_controls
	var/robot_clicks = 0

/datum/unit_test/uplink_ai_controls/Run()
	for(var/name in GLOB.keybindings_by_name)
		var/datum/keybinding/binding = GLOB.keybindings_by_name[name]
		if(binding.category != CATEGORY_AI)
			continue
		TEST_ASSERT_EQUAL(json_encode(binding.hotkey_keys), json_encode(list(UNBOUND_KEY)), "[name] must have no default hotkey.")
		TEST_ASSERT_EQUAL(json_encode(binding.classic_keys), json_encode(list(UNBOUND_KEY)), "[name] must have no default classic key.")
	TEST_ASSERT_NOTNULL(GLOB.keybindings_by_name["ai_services"], "The shared service binding must be registered.")
	TEST_ASSERT_NOTNULL(GLOB.keybindings_by_name["ai_camera_save_9"], "Camera bookmarks must be preference entries.")
	TEST_ASSERT_NOTNULL(GLOB.keybindings_by_name["ai_ability_overload"], "Acquired powers must be preference entries.")
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	operator.mind_initialize()
	var/mob/living/silicon/ai/core = allocate(/mob/living/silicon/ai, null, operator, null, null, TRUE)
	TEST_ASSERT_EQUAL(core.ai_controller(), core, "The controlling core must resolve itself.")
	var/mob/living/silicon/robot/robot = allocate(/mob/living/silicon/robot)
	robot.make_shell(allocate(/obj/item/borg/upgrade/ai))
	robot.connected_ai = core
	TEST_ASSERT_NULL(robot.ai_controller(), "Ordinary linkage must not grant access to AI commands.")
	var/datum/ai_shell_session/session = new(core, robot)
	TEST_ASSERT(session.start(), "The AI must deploy into the cyborg fixture.")
	TEST_ASSERT_EQUAL(robot.ai_controller(), core, "An active cyborg session must resolve its authoritative core.")
	core.shell_session_generation++
	TEST_ASSERT_NULL(robot.ai_controller(), "Stale session generations must not grant command authority.")
	core.shell_session_generation--
	RegisterSignal(robot, COMSIG_MOB_CLICKON, PROC_REF(robot_clicked))
	robot.next_click = world.time - 1
	robot.ClickOn(run_loc_floor_bottom_left, "")
	TEST_ASSERT_EQUAL(robot_clicks, 1, "Real cyborg ClickOn must emit the session interaction signal.")
	robot.lockcharge = TRUE
	robot.next_click = world.time - 1
	robot.ClickOn(run_loc_floor_bottom_left, "")
	TEST_ASSERT_EQUAL(robot_clicks, 1, "Locked cyborgs must not dispatch network clicks.")
	robot.lockcharge = FALSE
	core.control_disabled = TRUE
	TEST_ASSERT(core.run_ai_command("Return to core"), "Safe return must remain usable when services are unavailable.")
	TEST_ASSERT_EQUAL(core.mind?.current, core, "The shared return command must restore control.")

/datum/unit_test/uplink_ai_controls/proc/robot_clicked()
	SIGNAL_HANDLER
	robot_clicks++
	return COMSIG_MOB_CANCEL_CLICKON

/** Physical quirk initialization is retained on replacement while ordinary gifts remain single-issue. */
/datum/unit_test/uplink_quirk_persistence/Run()
	var/datum/preferences/preferences = allocate(/datum/preferences, allocate(/datum/client_interface))
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/synthetic
	preferences.value_cache[/datum/preference/choiced/prosthetic] = "Left Arm"
	preferences.all_quirks = list("Pseudobulbar Affect", "Prosthetic Limb", "Overweight")
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	operator.mind_initialize()
	var/mob/living/silicon/ai/core = allocate(/mob/living/silicon/ai, null, operator, null, null, TRUE)
	var/datum/uplink_registry/registry = allocate(/datum/uplink_registry, core.mind, core)
	registry.blueprint = new(preferences, "Quirk fixture", FALSE)
	for(var/initial_body in list(TRUE, FALSE))
		var/obj/effect/uplink_delivery/delivery = allocate(/obj/effect/uplink_delivery)
		var/mob/living/carbon/human/uplink/body = registry.blueprint.build(delivery, registry)
		body.forceMove(run_loc_floor_bottom_left)
		body.provisional = FALSE
		body.issue_quirk_items = initial_body
		body.registry = registry
		body.registration_generation = registry.registration_generation
		registry.observe_body(body)
		registry.refresh_binding()
		var/obj/item/organ/brain/cybernetic/ai/brain = body.get_organ_slot(ORGAN_SLOT_BRAIN)
		var/datum/ai_shell_session/session = new(core, body, brain)
		TEST_ASSERT(session.start(), "The quirk fixture must connect.")
		var/datum/quirk/prosthetic_limb/prosthetic = locate() in body.quirks
		TEST_ASSERT_NOTNULL(prosthetic?.limb_zone, "Replacement must run physical add_unique setup.")
		TEST_ASSERT(body.has_quirk(SSquirks.quirks["Overweight"]), "The body must receive ordinary saved quirks.")
		var/obj/item/bodypart/limb = body.get_bodypart(prosthetic.limb_zone)
		TEST_ASSERT(istype(limb, /obj/item/bodypart/arm/left/robot/surplus), "The saved prosthetic selection must be installed.")
		var/list/original_quirks = body.quirks.Copy()
		TEST_ASSERT(session.finish("Quirk fixture"), "Disconnect should preserve the body's quirks.")
		session = new(core, body, brain)
		TEST_ASSERT(session.start(), "Reconnect should reuse the physical body.")
		TEST_ASSERT_EQUAL(length(body.quirks), length(original_quirks), "Reconnect must not reapply quirks.")
		for(var/datum/quirk/quirk as anything in original_quirks)
			TEST_ASSERT(quirk in body.quirks, "Reconnect must preserve each quirk datum.")
		var/gift_count = 0
		for(var/obj/item/paper/joker/card in body.get_all_contents())
			gift_count++
		TEST_ASSERT_EQUAL(gift_count, initial_body ? 1 : 0, "The disability card must be issued only with the first body.")
		body.scrap_uplink()
		for(var/datum/quirk/quirk as anything in original_quirks)
			TEST_ASSERT(QDELETED(quirk), "Scrapping must stop and delete body-owned quirks.")
