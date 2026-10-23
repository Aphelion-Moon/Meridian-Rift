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

#endif
