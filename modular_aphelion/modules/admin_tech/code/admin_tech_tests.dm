#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/** Verifies Admin-Tech parent types and storage variants expose their intended configuration. */
/datum/unit_test/admin_tech_configuration

/datum/unit_test/admin_tech_configuration/Run()
	if(/datum/design/admin::abstract_type != /datum/design/admin)
		Fail("The Admin-Tech design parent must not be instantiated as a printable design.", __FILE__, __LINE__)
	if(/obj/item/tank/internals/admin/mix::abstract_type != /obj/item/tank/internals/admin/mix)
		Fail("The admin mixed-gas tank parent must not be instantiated as an item.", __FILE__, __LINE__)

	var/obj/item/storage/belt/utility/admin/full/subspace/subspace_belt = allocate(/obj/item/storage/belt/utility/admin/full/subspace)
	if(subspace_belt.atom_storage.type != /datum/storage/admin/bag/subspace)
		Fail("The subspace utility belt must use subspace storage.", __FILE__, __LINE__)

/** Verifies Babel clothing only grants languages from a valid worn slot. */
/datum/unit_test/admin_tech_babel_clothing

/datum/unit_test/admin_tech_babel_clothing/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/admin/headset = allocate(/obj/item/radio/headset/admin)

	SEND_SIGNAL(headset, COMSIG_ITEM_EQUIPPED, wearer, ITEM_SLOT_HANDS)
	if(HAS_TRAIT(wearer, TRAIT_BABEL_LISTENER))
		Fail("Holding Babel clothing granted its language effects.", __FILE__, __LINE__)

	SEND_SIGNAL(headset, COMSIG_ITEM_EQUIPPED, wearer, ITEM_SLOT_EARS)
	if(!HAS_TRAIT(wearer, TRAIT_BABEL_LISTENER))
		Fail("Wearing Babel clothing did not grant its language effects.", __FILE__, __LINE__)

/datum/unit_test/admin_tech_walker_radio/Run()
	var/mob/living/silicon/robot/borg = allocate(/mob/living/silicon/robot)
	borg.model.transform_to(/obj/item/robot_model/admin, TRUE, FALSE)
	if(!borg.radio.channels[RADIO_CHANNEL_CENTCOM])
		Fail("Converting a station borg to a walker did not grant the CentCom channel.", __FILE__, __LINE__)
	if(!(borg.radio.special_channels & RADIO_SPECIAL_CENTCOM))
		Fail("The converted walker's CentCom radio cannot transmit independently of telecomms.", __FILE__, __LINE__)
	var/obj/item/radio/original_radio = borg.radio

	borg.model.transform_to(/obj/item/robot_model/admin/backline, TRUE, FALSE)
	if(borg.radio != original_radio)
		Fail("Switching walker models unnecessarily replaced the CentCom radio.", __FILE__, __LINE__)
	if(!borg.radio.channels[RADIO_CHANNEL_MEDICAL])
		Fail("The Backline walker did not gain its medical channel.", __FILE__, __LINE__)

	borg.model.transform_to(/obj/item/robot_model/admin/engineer, TRUE, FALSE)
	if(!borg.radio.channels[RADIO_CHANNEL_CENTCOM])
		Fail("Switching walker models lost the CentCom channel.", __FILE__, __LINE__)
	if(!borg.radio.channels[RADIO_CHANNEL_ENGINEERING])
		Fail("The Technical walker did not gain its engineering channel.", __FILE__, __LINE__)
	if(borg.radio.channels[RADIO_CHANNEL_MEDICAL])
		Fail("The Technical walker retained the previous model's medical channel.", __FILE__, __LINE__)

/datum/unit_test/admin_tech_response_pinpointer/Run()
	var/turf/here = run_loc_floor_bottom_left
	var/mob/living/carbon/human/carrier = allocate(/mob/living/carbon/human/consistent, here)
	var/obj/item/pinpointer/response_team_cyborg/pinpointer = allocate(/obj/item/pinpointer/response_team_cyborg, carrier)
	var/mob/living/carbon/human/nearby = allocate(/mob/living/carbon/human/consistent, locate(here.x + 4, here.y, here.z))
	var/mob/living/carbon/human/off_level = allocate(/mob/living/carbon/human/consistent, locate(here.x + 1, here.y, here.z == 1 ? 2 : 1))
	for(var/mob/living/carbon/human/responder in list(carrier, nearby, off_level))
		responder.mind_initialize()
		var/datum/antagonist/ert/responder_role = allocate(/datum/antagonist/ert)
		responder_role.owner = responder.mind

	pinpointer.scan_for_target()
	if(pinpointer.target != nearby)
		Fail("The pinpointer must ignore its carrier and responders on other z-levels, even when their x/y coordinates are closer.", __FILE__, __LINE__)

	nearby.death()
	pinpointer.scan_for_target()
	if(!isnull(pinpointer.target))
		Fail("The pinpointer should have no target when the only nearby responder is dead.", __FILE__, __LINE__)

/datum/unit_test/admin_tech_multitool_buffers
	var/removal_notifications = 0

/datum/unit_test/admin_tech_multitool_buffers/Run()
	var/obj/item/multitool/admin/tool = allocate(/obj/item/multitool/admin)
	var/datum/first = allocate(/datum)
	var/datum/second = allocate(/datum)
	RegisterSignal(tool, COMSIG_MULTITOOL_REMOVE_BUFFER, PROC_REF(on_buffer_removed))
	tool.set_buffer(first)
	tool.set_buffer(first)
	tool.active_slot = "Slot 2"
	tool.buffer = tool.buffer_slots[tool.active_slot]
	tool.set_buffer(first)
	tool.set_buffer(second)
	qdel(first)
	if(tool.buffer_slots["Slot 1"] || tool.buffer != second)
		Fail("Deleting an inactive shared buffer must clear its slot and preserve the active buffer.", __FILE__, __LINE__)
	qdel(second)
	if(tool.buffer || tool.buffer_slots["Slot 2"])
		Fail("Deleting the active buffer must clear both its slot and the active mirror.", __FILE__, __LINE__)
	if(removal_notifications != 3)
		Fail("Replacing or deleting the active buffer must preserve the standard removal notification.", __FILE__, __LINE__)

	var/datum/shared = allocate(/datum)
	tool.set_buffer(shared)
	tool.active_slot = "Slot 1"
	tool.buffer = tool.buffer_slots[tool.active_slot]
	tool.set_buffer(shared)
	tool.set_buffer(null)
	qdel(shared)
	if(tool.buffer_slots["Slot 2"])
		Fail("Clearing one slot must keep deletion tracking for another slot containing the same buffer.", __FILE__, __LINE__)

	var/datum/retained = allocate(/datum)
	tool.set_buffer(retained)
	qdel(tool)
	if(retained._listen_lookup?[COMSIG_QDELETING])
		Fail("Deleting the multitool left a buffer deletion listener registered.", __FILE__, __LINE__)

/datum/unit_test/admin_tech_multitool_buffers/proc/on_buffer_removed(datum/source, datum/removed_buffer)
	SIGNAL_HANDLER
	removal_notifications++

/datum/unit_test/admin_tech_walker_lifecycle/Run()
	var/mob/living/silicon/robot/model/admin/backline/borg = allocate(/mob/living/silicon/robot/model/admin/backline)
	var/obj/item/radio/original_radio = borg.radio
	// Unit-test builds skip the model subtype's automatic transform_to().
	borg.model.transform_to(borg.set_model, TRUE, FALSE)
	if(borg.radio != original_radio || !borg.radio.channels[RADIO_CHANNEL_CENTCOM] || !borg.radio.channels[RADIO_CHANNEL_MEDICAL])
		Fail("Setting up a Backline walker must preserve its CentCom radio and add its medical channel.", __FILE__, __LINE__)
	var/datum/action/cooldown/borg_crew_monitor/monitor = locate() in borg.actions
	if(!monitor)
		Fail("The Backline walker did not receive its crew monitor action.", __FILE__, __LINE__)
		return
	var/obj/item/pinpointer/response_team_cyborg/pinpointer = locate() in borg.model.modules
	if(!pinpointer || !borg.activate_module(pinpointer))
		Fail("The Backline walker could not equip its response pinpointer.", __FILE__, __LINE__)
		return
	pinpointer.attack_self(borg)
	if(!pinpointer.active)
		Fail("The equipped response pinpointer did not activate.", __FILE__, __LINE__)
	borg.deactivate_module(pinpointer)
	if(pinpointer.active || (pinpointer in SSfastprocess.processing))
		Fail("Stowing the response pinpointer must stop its processing.", __FILE__, __LINE__)

	borg.model.transform_to(/obj/item/robot_model/admin/engineer, TRUE, FALSE)
	if(!QDELETED(monitor) || (locate(/datum/action/cooldown/borg_crew_monitor) in borg.actions))
		Fail("Leaving Backline must delete its crew monitor action and remove its button.", __FILE__, __LINE__)
	var/obj/item/shuttle_blueprints/borg/blueprints = locate() in borg.model.modules
	if(!blueprints || !borg.activate_module(blueprints))
		Fail("The Technical walker could not equip its cyborg shuttle blueprints.", __FILE__, __LINE__)
		return
	borg.deactivate_module(blueprints)

	borg.model.transform_to(/obj/item/robot_model/admin/backline, TRUE, FALSE)
	var/monitor_count = 0
	for(var/datum/action/cooldown/borg_crew_monitor/action in borg.actions)
		monitor_count++
		monitor = action
	if(monitor_count != 1)
		Fail("Returning to Backline must grant exactly one crew monitor action.", __FILE__, __LINE__)
	qdel(borg)
	if(!QDELETED(monitor))
		Fail("Deleting the walker must delete its crew monitor action.", __FILE__, __LINE__)

#endif
