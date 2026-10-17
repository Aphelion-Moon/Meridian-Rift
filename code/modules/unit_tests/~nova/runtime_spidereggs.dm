/// Exercises admission before spider-egg allocation, including the basic aliens from the runtime report.
/datum/unit_test/runtime_spidereggs
	abstract_type = /datum/unit_test/runtime_spidereggs
	/// Eggs created during this test, including rejected insertions in nullspace.
	var/created_eggs = 0

/datum/unit_test/runtime_spidereggs/New()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_NEW_ITEM, PROC_REF(record_egg))

/datum/unit_test/runtime_spidereggs/Destroy()
	UnregisterSignal(SSdcs, COMSIG_GLOB_NEW_ITEM)
	return ..()

/datum/unit_test/runtime_spidereggs/proc/record_egg(datum/source, obj/item/item)
	SIGNAL_HANDLER
	if(!istype(item, /obj/item/organ/body_egg/spideregg_infection))
		return
	created_eggs++
	allocated += item

/datum/unit_test/runtime_spidereggs/basic_hosts/Run()
	var/datum/reagent/spidereggs/eggs = allocate(/datum/reagent/spidereggs)
	for(var/host_type in list(/mob/living/basic/alien/queen, /mob/living/basic/alien/drone, /mob/living/basic/alien/sentinel))
		var/mob/living/basic/host = allocate(host_type)
		host.ai_controller?.force_ai_off()
		eggs.expose_mob(host, INJECT, 2)
		TEST_ASSERT(!HAS_TRAIT(host, TRAIT_SPIDER_HOST), "A basic alien became a spider host: [host_type].")
	TEST_ASSERT_EQUAL(created_eggs, 0, "Unsupported hosts must be rejected before allocating an egg.")

/datum/unit_test/runtime_spidereggs/carbon_hosts/Run()
	var/datum/reagent/spidereggs/eggs = allocate(/datum/reagent/spidereggs)
	for(var/host_type in list(/mob/living/carbon/human/consistent, /mob/living/carbon/alien/larva))
		var/mob/living/carbon/host = allocate(host_type)
		host.ai_controller?.force_ai_off()
		eggs.expose_mob(host, INJECT, 2)
		var/obj/item/organ/body_egg/spideregg_infection/egg = host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG)
		TEST_ASSERT(istype(egg), "The supported carbon [host_type] did not receive a spider egg.")
		TEST_ASSERT_EQUAL(egg.owner, host, "The egg was not inserted into its host.")
		TEST_ASSERT(HAS_TRAIT(host, TRAIT_SPIDER_HOST), "The inserted egg did not establish its host trait.")
	TEST_ASSERT_EQUAL(created_eggs, 2, "Each supported carbon should receive exactly one egg.")

/datum/unit_test/runtime_spidereggs/duplicate_exposure/Run()
	var/datum/reagent/spidereggs/eggs = allocate(/datum/reagent/spidereggs)
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	eggs.expose_mob(host, INJECT, 2)
	var/obj/item/organ/body_egg/spideregg_infection/first_egg = host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG)
	TEST_ASSERT(istype(first_egg), "The initial exposure did not insert an egg.")
	eggs.expose_mob(host, INJECT, 2)
	TEST_ASSERT_EQUAL(host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG), first_egg, "Repeated exposure replaced the existing egg.")
	TEST_ASSERT_EQUAL(created_eggs, 1, "Repeated exposure allocated a second egg.")

/datum/unit_test/runtime_spidereggs/occupied_slot/Run()
	var/datum/reagent/spidereggs/eggs = allocate(/datum/reagent/spidereggs)
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/body_egg/existing_egg = allocate(/obj/item/organ/body_egg)
	existing_egg.Insert(host)
	eggs.expose_mob(host, INJECT, 2)
	TEST_ASSERT_EQUAL(host.get_organ_slot(ORGAN_SLOT_PARASITE_EGG), existing_egg, "Spider eggs replaced an existing parasite.")
	TEST_ASSERT_EQUAL(created_eggs, 0, "An occupied parasite slot allocated a spider egg.")
