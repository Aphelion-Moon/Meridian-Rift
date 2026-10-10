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
	var/mob/living/carbon/human/second_observer = allocate(/mob/living/carbon/human/consistent)
	second_observer.set_hud_used(new second_observer.hud_type(second_observer))
	var/datum/tgui/dogmos_kennel/second_ui = allocate(/datum/tgui/dogmos_kennel, second_observer, kennel, "DogmosKennel")
	kennel.open_uis += second_ui
	kennel.ui_data(second_observer)
	TEST_ASSERT_EQUAL(kennel.producer_process_metric_samples, 1, "Viewers multiplied routine sampling within one interval.")
	TEST_ASSERT_EQUAL(kennel.producer_active_viewers, 2, "Missing second viewer.")
	first_ui.selected_tab = "Structures/Machines"
	kennel.ui_data(observer)
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 1, "An explicit browse request did not build one page.")
	TEST_ASSERT(kennel.producer_machinery_candidates_inspected <= 250, "A page scanned over its candidate budget.")
	kennel.ui_data(observer)
	kennel.ui_data(second_observer)
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 1, "An unchanged or hidden panel rescanned machinery.")
	first_ui.browse_search = "no matching machine in this fixture"
	first_ui.browse_page = 2
	first_ui.browse_result = null
	kennel.ui_data(observer)
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 2, "A changed request did not rebuild its page.")
	TEST_ASSERT(kennel.producer_machinery_candidates_inspected <= 500, "Filtering performed an unbounded count scan.")
	kennel.open_uis -= first_ui
	qdel(first_ui)
	kennel.ui_data(second_observer)
	TEST_ASSERT_EQUAL(kennel.producer_browse_pages_built, 2, "A closed browse panel still scanned.")
	kennel.open_uis.Cut()

// APHELION EDIT ADDITION START - DOGMOS
/// A real machinery entry that asks the atmosphere scheduler to retire it.
/obj/machinery/dogmos_kennel_retiring_test/process_atmos()
	return PROCESS_KILL

/** Retiring a machine must also retire its measured cost. */
/datum/unit_test/dogmos_kennel_machine_retirement

/datum/unit_test/dogmos_kennel_machine_retirement/Run()
	var/obj/machinery/machine = allocate(/obj/machinery/dogmos_kennel_retiring_test)
	var/list/original_machinery = SSair.atmos_machinery
	var/list/original_currentrun = SSair.currentrun
	var/list/original_costs = SSair.diagnostics.kennel_machine_cost_ewma
	var/original_state = SSair.state
	var/original_part = SSair.currentpart
	var/original_tick_limit = Master.current_ticklimit
	SSair.atmos_machinery = list()
	SSair.diagnostics.kennel_machine_cost_ewma = list()
	SSair.currentpart = SSAIR_ATMOSMACHINERY
	SSair.state = SS_RUNNING
	Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag
	SSair.start_processing_machine(machine)
	SSair.process_atmos_machinery()
	var/still_processing = machine.atmos_processing
	var/remaining_costs = length(SSair.diagnostics.kennel_machine_cost_ewma)
	SSair.atmos_machinery = original_machinery
	SSair.currentrun = original_currentrun
	SSair.diagnostics.kennel_machine_cost_ewma = original_costs
	SSair.currentpart = original_part
	SSair.state = original_state
	Master.current_ticklimit = original_tick_limit
	TEST_ASSERT(!still_processing, "The fixture did not retire from atmosphere processing.")
	TEST_ASSERT_EQUAL(remaining_costs, 0, "Processing recreated the retired machine's Kennel cost entry.")

/** Cached cost identities must preserve REF's dynamic tag behavior. */
/datum/unit_test/dogmos_kennel_machine_identity

/datum/unit_test/dogmos_kennel_machine_identity/Run()
	var/obj/machinery/machine = allocate(/obj/machinery)
	var/list/original_costs = SSair.diagnostics.kennel_machine_cost_ewma
	SSair.diagnostics.kennel_machine_cost_ewma = list()
	SSair.diagnostics.check_kennel_machine_cost(machine, 0.1)
	var/engine_key = REF(machine)
	machine.datum_flags |= DF_USE_TAG
	machine.tag = "kennel-cost-first"
	SSair.diagnostics.check_kennel_machine_cost(machine, 0.2)
	var/first_tag_key = REF(machine)
	machine.tag = "kennel-cost-second"
	SSair.diagnostics.check_kennel_machine_cost(machine, 0.3)
	var/second_tag_key = REF(machine)
	var/list/sampled_costs = SSair.diagnostics.kennel_machine_cost_ewma
	SSair.diagnostics.kennel_machine_cost_ewma = original_costs
	machine.datum_flags &= ~DF_USE_TAG
	machine.tag = null
	TEST_ASSERT_EQUAL(sampled_costs[engine_key], 0.1, "The stable engine identity lost its cost sample.")
	TEST_ASSERT_EQUAL(sampled_costs[first_tag_key], 0.2, "A tagged machine used its cached engine identity.")
	TEST_ASSERT_EQUAL(sampled_costs[second_tag_key], 0.3, "Changing a machine tag did not update its cost identity.")
// APHELION EDIT ADDITION END
