/// Exercises the fennec producer through the real breeding signal and cooldown timer.
/datum/unit_test/runtime_fennec_breeding/Run()
	var/mob/living/basic/pet/cat/fennec/parent_fox = allocate(/mob/living/basic/pet/cat/fennec)
	var/mob/living/basic/pet/cat/fennec/partner = allocate(/mob/living/basic/pet/cat/fennec)
	var/mob/living/basic/pet/cat/other_species = allocate(/mob/living/basic/pet/cat)
	parent_fox.ai_controller.force_ai_off()
	partner.ai_controller.force_ai_off()
	other_species.ai_controller.force_ai_off()
	parent_fox.gender = FEMALE
	partner.gender = FEMALE
	other_species.gender = MALE
	parent_fox.set_combat_mode(FALSE)
	var/datum/component/breed/breeding = parent_fox.GetComponent(/datum/component/breed)
	TEST_ASSERT_NOTNULL(breeding, "The fennec did not register its breeding component.")
	breeding.breed_timer = 1 SECONDS

	SEND_SIGNAL(parent_fox, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, partner)
	TEST_ASSERT_EQUAL(length(offspring(parent_fox, partner)), 0, "Same-sex fennecs produced an offspring.")
	SEND_SIGNAL(parent_fox, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, other_species)
	TEST_ASSERT_EQUAL(length(offspring(parent_fox, partner)), 0, "A fennec bred with an unsupported species.")
	TEST_ASSERT(breeding.ready_to_breed, "An ineligible partner consumed the breeding cooldown.")

	partner.gender = MALE
	parent_fox.set_combat_mode(TRUE)
	SEND_SIGNAL(parent_fox, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, partner)
	TEST_ASSERT_EQUAL(length(offspring(parent_fox, partner)), 0, "A fennec in combat mode produced an offspring.")
	parent_fox.set_combat_mode(FALSE)

	TEST_ASSERT(SEND_SIGNAL(parent_fox, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, partner) & COMPONENT_HOSTILE_NO_ATTACK, "Breeding did not consume the attack.")
	var/list/babies = offspring(parent_fox, partner)
	TEST_ASSERT_EQUAL(length(babies), 1, "An eligible pair did not produce exactly one fennec.")
	var/mob/living/basic/pet/cat/fennec/baby = babies[1]
	baby.ai_controller.force_ai_off()
	TEST_ASSERT_EQUAL(baby.type, /mob/living/basic/pet/cat/fennec, "Fennec breeding produced the wrong species.")
	TEST_ASSERT_EQUAL(get_turf(baby), get_turf(parent_fox), "The offspring was not born beside its parent.")
	TEST_ASSERT(!breeding.ready_to_breed, "Birth did not start the cooldown.")
	TEST_ASSERT(!parent_fox.ai_controller.blackboard[BB_BREED_READY], "The AI remained ready to breed during cooldown.")
	SEND_SIGNAL(parent_fox, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, partner)
	TEST_ASSERT_EQUAL(length(offspring(parent_fox, partner)), 1, "A second offspring was produced during cooldown.")

	var/deadline = world.time + 5 SECONDS
	while(!breeding.ready_to_breed && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT(breeding.ready_to_breed, "The real cooldown timer did not restore breeding eligibility.")
	TEST_ASSERT(parent_fox.ai_controller.blackboard[BB_BREED_READY], "The cooldown did not restore AI breeding readiness.")

/// Returns actual offspring on the delivery turf, excluding the two test parents.
/datum/unit_test/runtime_fennec_breeding/proc/offspring(mob/living/basic/pet/cat/fennec/parent_fox, mob/living/basic/pet/cat/fennec/partner)
	. = list()
	for(var/mob/living/basic/pet/cat/fennec/baby in get_turf(parent_fox))
		if(baby != parent_fox && baby != partner)
			. += baby
