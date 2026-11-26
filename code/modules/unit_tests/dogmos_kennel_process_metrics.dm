/** Shared sampling and demand-driven bounded browsing across zero, one and two viewers. */
/datum/unit_test/dogmos_kennel_process_metrics
	parent_type = /datum/unit_test/dogmos_diagnostics_fixture

/datum/unit_test/dogmos_kennel_process_metrics/Run()
	var/datum/dogmos_kennel/kennel = allocate(/datum/dogmos_kennel)
	var/mob/living/carbon/human/observer = allocate(/mob/living/carbon/human/consistent)
	observer.set_hud_used(new observer.hud_type(observer))
	var/list/data = kennel.ui_data(observer)
	var/list/payload = data["process_metrics"]
	TEST_ASSERT_EQUAL(length(payload), 1, "Only DreamDaemon owns native atmosphere memory.")
	for(var/key in list("private_bytes", "virtual_bytes", "working_set_bytes", "available"))
		TEST_ASSERT(key in payload["dreamdaemon"], "Missing host metric [key].")
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 0, "No viewer requested machinery.")
	TEST_ASSERT_EQUAL(kennel.producer_active_viewers, 0, "Unexpected viewer.")
	var/list/costs = data["dogmos_costs"]
	TEST_ASSERT_EQUAL(costs["mc_total"], SSair.cost, "Kennel differs from the MC counter.")
	TEST_ASSERT_EQUAL(costs["atmos_machinery"], SSair.cost_atmos_machinery, "Kennel differs from the machinery counter.")

	var/datum/tgui/dogmos_kennel/first_ui = allocate(/datum/tgui/dogmos_kennel, observer, kennel, "DogmosKennel")
	kennel.open_uis = list(first_ui)
	kennel.ui_data(observer)
	TEST_ASSERT_EQUAL(kennel.producer_active_viewers, 1, "Missing first viewer.")
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 0, "Overview scanned machinery.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.set_hud_used(new user.hud_type(user))
	var/datum/tgui/dogmos_kennel/second_ui = allocate(/datum/tgui/dogmos_kennel, user, kennel, "DogmosKennel")
	kennel.open_uis += second_ui
	kennel.ui_data(user)
	TEST_ASSERT_EQUAL(kennel.producer_process_metric_samples, 1, "Viewers multiplied routine sampling within one interval.")
	TEST_ASSERT_EQUAL(kennel.producer_active_viewers, 2, "Missing second viewer.")
	first_ui.selected_tab = "Structures/Machines"
	kennel.ui_data(observer)
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 1, "An explicit browse request did not build one page.")
	TEST_ASSERT(kennel.producer_machinery_candidates_inspected <= 250, "A page scanned over its candidate budget.")
	kennel.ui_data(observer)
	kennel.ui_data(user)
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 1, "An unchanged or hidden panel rescanned machinery.")
	first_ui.browse_search = "no matching machine in this fixture"
	first_ui.browse_page = 2
	first_ui.browse_result = null
	kennel.ui_data(observer)
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 2, "A changed request did not rebuild its page.")
	TEST_ASSERT(kennel.producer_machinery_candidates_inspected <= 500, "Filtering performed an unbounded count scan.")
	kennel.open_uis -= first_ui
	qdel(first_ui)
	kennel.ui_data(user)
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 2, "A closed browse panel still scanned.")
	kennel.open_uis.Cut()

/// A real machinery entry that asks the atmosphere scheduler to retire it.
/obj/machinery/dogmos_kennel_retiring_test/process_atmos()
	return PROCESS_KILL

/** Retiring a machine must also retire its measured cost. */
/datum/unit_test/dogmos_kennel_machine_retirement

/datum/unit_test/dogmos_kennel_machine_retirement/Run()
	var/obj/machinery/machine = allocate(/obj/machinery/dogmos_kennel_retiring_test)
	var/list/saved = SSair.atmos_machinery
	var/list/backup = SSair.currentrun
	var/list/previous = SSair.diagnostics.kennel_machine_cost_ewma
	var/old_state = SSair.state
	var/old_value = SSair.currentpart
	var/original_tick_limit = Master.current_ticklimit
	SSair.atmos_machinery = list()
	SSair.diagnostics.kennel_machine_cost_ewma = list()
	SSair.currentpart = SSAIR_ATMOSMACHINERY
	SSair.state = SS_RUNNING
	Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag
	SSair.start_processing_machine(machine)
	SSair.process_atmos_machinery()
	var/processing = machine.atmos_processing
	var/remaining = length(SSair.diagnostics.kennel_machine_cost_ewma)
	SSair.atmos_machinery = saved
	SSair.currentrun = backup
	SSair.diagnostics.kennel_machine_cost_ewma = previous
	SSair.currentpart = old_value
	SSair.state = old_state
	Master.current_ticklimit = original_tick_limit
	TEST_ASSERT(!processing, "The fixture did not retire from atmosphere processing.")
	TEST_ASSERT_EQUAL(remaining, 0, "Processing recreated the retired machine's Kennel cost entry.")

/** Cached cost identities must preserve REF's dynamic tag behavior. */
/datum/unit_test/dogmos_kennel_machine_identity

/datum/unit_test/dogmos_kennel_machine_identity/Run()
	var/obj/machinery/machine = allocate(/obj/machinery)
	var/list/previous = SSair.diagnostics.kennel_machine_cost_ewma
	SSair.diagnostics.kennel_machine_cost_ewma = list()
	SSair.diagnostics.check_kennel_machine_cost(machine, 0.1)
	var/first = REF(machine)
	machine.datum_flags |= DF_USE_TAG
	machine.tag = "kennel-cost-first"
	SSair.diagnostics.check_kennel_machine_cost(machine, 0.2)
	var/second = REF(machine)
	machine.tag = "kennel-cost-second"
	SSair.diagnostics.check_kennel_machine_cost(machine, 0.3)
	var/third = REF(machine)
	var/list/results = SSair.diagnostics.kennel_machine_cost_ewma
	SSair.diagnostics.kennel_machine_cost_ewma = previous
	machine.datum_flags &= ~DF_USE_TAG
	machine.tag = null
	TEST_ASSERT_EQUAL(results[first], 0.1, "The stable engine identity lost its cost sample.")
	TEST_ASSERT_EQUAL(results[second], 0.2, "A tagged machine used its cached engine identity.")
	TEST_ASSERT_EQUAL(results[third], 0.3, "Changing a machine tag did not update its cost identity.")
