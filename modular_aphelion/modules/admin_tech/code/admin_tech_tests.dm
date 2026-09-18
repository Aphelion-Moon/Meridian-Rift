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

#endif
