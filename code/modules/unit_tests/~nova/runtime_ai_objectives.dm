/// Uses real AI initialization and minds; unrelated station AIs are excluded through the public blacklist.
/datum/unit_test/runtime_destroy_ai
	abstract_type = /datum/unit_test/runtime_destroy_ai
	/// Restore the server opt-in policy even when a test assertion returns early.
	var/previous_opt_in_disabled

/datum/unit_test/runtime_destroy_ai/New()
	. = ..()
	previous_opt_in_disabled = CONFIG_GET(flag/disable_antag_opt_in_preferences)
	CONFIG_SET(flag/disable_antag_opt_in_preferences, FALSE)

/datum/unit_test/runtime_destroy_ai/Destroy()
	CONFIG_SET(flag/disable_antag_opt_in_preferences, previous_opt_in_disabled)
	return ..()

/// Initializes an AI with a real transferred mind and an explicitly controlled opt-in level.
/datum/unit_test/runtime_destroy_ai/proc/create_ai(opt_in_level)
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.mind_initialize()
	var/mob/living/silicon/ai/target_ai = allocate(/mob/living/silicon/ai, run_loc_floor_bottom_left, donor, /datum/ai_laws/default/asimov, null, TRUE)
	target_ai.mind.assigned_role = null
	target_ai.mind.ideal_antag_opt_in_level = opt_in_level
	target_ai.mind.on_spawn_antag_opt_in_level = ANTAG_OPT_OUT
	return target_ai

/datum/unit_test/runtime_destroy_ai/valid_target/Run()
	var/mob/living/silicon/ai/target_ai = create_ai(ANTAG_OPT_IN_YES_KILL)
	var/datum/objective/destroy/objective = allocate(/datum/objective/destroy)
	TEST_ASSERT_EQUAL(objective.find_target(blacklist = GLOB.ai_list - target_ai), target_ai.mind, "An opted-in AI was not selected by its mind.")
	TEST_ASSERT_EQUAL(objective.target, target_ai.mind, "Target selection did not retain the AI mind.")
	TEST_ASSERT(findtext(objective.explanation_text, target_ai.mind.name), "The explanation did not identify the selected AI.")

/datum/unit_test/runtime_destroy_ai/opted_out/Run()
	var/mob/living/silicon/ai/target_ai = create_ai(ANTAG_OPT_OUT)
	var/datum/objective/destroy/objective = allocate(/datum/objective/destroy)
	TEST_ASSERT_NULL(objective.find_target(blacklist = GLOB.ai_list - target_ai), "An opted-out AI was selected.")
	TEST_ASSERT_NULL(objective.target, "A rejected AI remained the objective target.")
	TEST_ASSERT_EQUAL(objective.explanation_text, "Free objective.", "No eligible AI did not produce the normal empty-target explanation.")

/// Real AI transfers into MODsuits and intellicards must meet the same live full-AI contract.
/datum/unit_test/runtime_functional_ai/Run()
	var/mob/living/carbon/human/thief = allocate(/mob/living/carbon/human/consistent)
	thief.mind_initialize()
	var/datum/objective_item/steal/functionalai/target_info = allocate(/datum/objective_item/steal/functionalai)
	var/datum/objective/steal/objective = allocate(/datum/objective/steal)
	objective.owner = thief.mind
	objective.set_target(target_info)
	var/obj/item/mod/control/suit = allocate(/obj/item/mod/control/pre_equipped/medical, thief)
	TEST_ASSERT(suit.type in target_info.altitems, "MODsuits with full AIs must remain valid theft alternatives.")
	TEST_ASSERT(!objective.check_completion(), "An empty MODsuit completed the functional-AI objective.")

	var/obj/item/pai_card/pai_card = allocate(/obj/item/pai_card, suit)
	var/mob/living/silicon/pai/personal_ai = allocate(/mob/living/silicon/pai, pai_card)
	pai_card.set_personality(personal_ai)
	suit.on_gained_assistant(personal_ai)
	if(objective.check_completion())
		TEST_FAIL("A MODsuit with a pAI completed the full-AI objective.")
	suit.on_removed_assistant()

	var/obj/item/aicard/card = allocate(/obj/item/aicard, thief)
	TEST_ASSERT(!objective.check_completion(), "An empty intellicard completed the objective.")
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.mind_initialize()
	var/mob/living/silicon/ai/stolen_ai = allocate(/mob/living/silicon/ai, run_loc_floor_bottom_left, donor, /datum/ai_laws/default/asimov, null, TRUE)
	suit.ai_enter_mod(stolen_ai)
	TEST_ASSERT_EQUAL(suit.ai_assistant, stolen_ai, "The real AI admission did not install the assistant.")
	TEST_ASSERT_EQUAL(stolen_ai.loc, suit, "The real AI admission did not move the AI into the suit.")
	if(!objective.check_completion())
		TEST_FAIL("A MODsuit containing a living full AI failed the objective.")
	var/active_stat = stolen_ai.stat
	stolen_ai.stat = DEAD
	if(objective.check_completion())
		TEST_FAIL("A MODsuit containing a dead full AI completed the objective.")

	stolen_ai.stat = active_stat
	suit.ai_exit_mod(card)
	TEST_ASSERT_NULL(suit.ai_assistant, "The real AI transfer left a MOD assistant behind.")
	TEST_ASSERT_EQUAL(card.AI, stolen_ai, "The real AI transfer did not populate the intellicard.")
	TEST_ASSERT(objective.check_completion(), "An intellicard containing a living AI failed the objective.")
	stolen_ai.stat = DEAD
	TEST_ASSERT(!objective.check_completion(), "An intellicard containing a dead AI completed the objective.")
	card.AI = null
