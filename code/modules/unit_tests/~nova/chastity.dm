/// Fitting, blocking, drawing, locking and removing a chastity device.
/datum/unit_test/portal_test/chastity

/datum/unit_test/portal_test/chastity/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Chastity devices need genitals, which the ERP config disables.")
		return

	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/partner = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/wearer_client = attach_portal_preferences(wearer)
	attach_portal_preferences(partner)
	var/obj/item/organ/genital/penis/penis = configure_test_penis(wearer)
	TEST_ASSERT_NOTNULL(penis, "The test penis could not be set up.")
	var/obj/item/clothing/sextoy/chastity/cage = allocate(/obj/item/clothing/sextoy/chastity)

	TEST_ASSERT(!cage.can_lewd_attach(wearer, partner, ORGAN_SLOT_PENIS), "A cage fit someone who doesn't want chastity devices.")
	TEST_ASSERT(wearer_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/chastity], TRUE), "Could not turn on chastity devices.")
	TEST_ASSERT(cage.can_lewd_attach(wearer, partner, ORGAN_SLOT_PENIS), "A cage didn't fit a willing wearer with a penis.")
	var/obj/item/clothing/sextoy/chastity/insert/insert = allocate(/obj/item/clothing/sextoy/chastity/insert)
	TEST_ASSERT(!insert.can_lewd_attach(wearer, partner, ORGAN_SLOT_VAGINA), "An insertable belt fit someone without a vagina.")

	// Fitted, the penis is closed off and the cage draws in its place.
	put_on(wearer, cage, ORGAN_SLOT_PENIS)
	TEST_ASSERT_EQUAL(penis.blocked_by, cage, "The cage didn't close the penis off.")
	var/datum/bodypart_overlay/mutant/genital/overlay = penis.bodypart_overlay
	TEST_ASSERT_EQUAL(overlay.device_state, "cage_standard", "The cage isn't drawn over the penis.")
	TEST_ASSERT(limb_draws(wearer, "cage_standard_m"), "The chest doesn't draw the cage.")
	var/obj/item/clothing/sextoy/chastity/belt/belt = allocate(/obj/item/clothing/sextoy/chastity/belt)
	TEST_ASSERT(!belt.can_lewd_attach(wearer, partner, ORGAN_SLOT_PENIS), "A second device fit over a caged penis.")

	var/datum/interaction/stroke = allocate(/datum/interaction)
	stroke.name = "Stroke"
	stroke.target_required_parts = list(ORGAN_SLOT_PENIS)
	TEST_ASSERT(!stroke.allow_act(partner, wearer), "A penis interaction reached a caged penis.")
	var/datum/interaction/tug = allocate(/datum/interaction)
	tug.name = "Tug cage"
	tug.interaction_requires = list(INTERACTION_REQUIRE_TARGET_CAGED)
	TEST_ASSERT(tug.allow_act(partner, wearer), "A caged-penis interaction was refused on a caged penis.")
	TEST_ASSERT(!tug.allow_act(wearer, partner), "A caged-penis interaction was offered on someone uncaged.")
	TEST_ASSERT_EQUAL(tug.format_message_for("%TARGET_DEVICE%", partner, wearer), cage.name, "The device token named the wrong thing.")
	penis.aroused = AROUSAL_FULL
	wearer.underwear = "Boxers"
	TEST_ASSERT(!wearer.has_bulge(), "A caged penis made a bulge.")
	wearer.underwear = "Nude"

	// The key tucked inside turns it; locked, it won't come off.
	var/obj/item/key/chastity/key = locate() in cage
	TEST_ASSERT_NOTNULL(key, "The cage came without its key.")
	TEST_ASSERT_EQUAL(key.key_id, REF(cage), "The key doesn't match its cage.")
	cage.set_locked(TRUE, partner)
	TEST_ASSERT(!cage.can_lewd_remove(partner), "A locked cage came off.")
	cage.set_locked(FALSE, partner)
	TEST_ASSERT(cage.can_lewd_remove(partner), "An unlocked cage wouldn't come off.")
	cage.broken_lock = TRUE
	TEST_ASSERT(!cage.set_locked(TRUE, partner), "A broken lock caught.")

	// Off again, the penis is free.
	cage.come_off(wearer)
	TEST_ASSERT_NULL(penis.blocked_by, "The penis stayed closed off after the cage came off.")
	TEST_ASSERT_NULL(overlay.device_state, "The cage kept drawing after it came off.")
	TEST_ASSERT_NULL(wearer.get_lewd_slot_item(ORGAN_SLOT_PENIS), "The cage stayed in the lewd slot.")
	TEST_ASSERT(stroke.allow_act(partner, wearer), "The penis stayed out of reach after the cage came off.")

	// The cursed device clamps shut by itself and takes the shape of what it holds.
	var/obj/item/clothing/sextoy/chastity/cursed/cursed = allocate(/obj/item/clothing/sextoy/chastity/cursed)
	TEST_ASSERT_NULL(locate(/obj/item/key/chastity) in cursed, "The cursed device came with a key.")
	put_on(wearer, cursed, ORGAN_SLOT_PENIS)
	TEST_ASSERT(cursed.locked, "The cursed device didn't lock itself.")
	TEST_ASSERT(!cursed.can_lewd_remove(partner), "The cursed device came off.")
	TEST_ASSERT_EQUAL(overlay.device_state, "cage_cursed_cock", "The cursed device took the wrong shape on a penis.")
	cursed.come_off(wearer)
	TEST_ASSERT(!cursed.locked, "The cursed device stayed locked off its wearer.")

	// A smart lock answers its remote from anywhere, and its status light follows the lock.
	var/obj/item/clothing/sextoy/chastity/chrome/chrome = allocate(/obj/item/clothing/sextoy/chastity/chrome)
	var/obj/item/key/chastity/remote/remote = locate() in chrome
	TEST_ASSERT_NOTNULL(remote, "The chrome cage came without its remote.")
	remote.forceMove(run_loc_floor_top_right)
	put_on(wearer, chrome, ORGAN_SLOT_PENIS)
	remote.attack_self(partner)
	TEST_ASSERT(chrome.locked, "The remote didn't lock its cage.")
	TEST_ASSERT(overlay.device_glows, "The chrome cage's light stayed off while locked.")
	remote.attack_self(partner)
	TEST_ASSERT(!chrome.locked, "The remote didn't unlock its cage.")
	TEST_ASSERT(!overlay.device_glows, "The chrome cage's light stayed on while unlocked.")
	chrome.come_off(wearer)

	// Wall portals relay chastity play wherever they relay the penis.
	var/list/portals = make_portal_pair("wallstuck")
	var/obj/structure/lewd_portal/portal = portals[1]
	TEST_ASSERT(portal.relays_interaction(tug), "A wall portal did not relay chastity play.")

/// Puts `device` into `slot` on `wearer` the way the interaction menu does.
/datum/unit_test/portal_test/chastity/proc/put_on(mob/living/carbon/human/wearer, obj/item/clothing/sextoy/chastity/device, slot)
	wearer.set_lewd_slot_item(slot, device)
	device.forceMove(wearer)
	device.lewd_equipped(wearer, slot)
	wearer.update_inv_lewd()

/// Whether the wearer's chest draws an overlay with `state`.
/datum/unit_test/portal_test/chastity/proc/limb_draws(mob/living/carbon/human/wearer, state)
	var/obj/item/bodypart/chest/chest = wearer.get_bodypart(BODY_ZONE_CHEST)
	for(var/image/drawn in chest.get_limb_icon())
		if(drawn.icon_state == state)
			return TRUE
	return FALSE

/// Every chastity device has its icon, both bodies' worn shapes, and the flavour text it can ask for.
/datum/unit_test/chastity_sprites

/datum/unit_test/chastity_sprites/Run()
	for(var/obj/item/clothing/sextoy/chastity/device_type as anything in typesof(/obj/item/clothing/sextoy/chastity))
		var/list/shapes = list(device_type::worn_shape)
		if(ispath(device_type, /obj/item/clothing/sextoy/chastity/cursed))
			shapes = list("cage_cursed_cock", "cage_cursedb", "cage_cursed_intersex")
		TEST_ASSERT(icon_exists(device_type::icon, device_type::icon_state), "[device_type] has no icon state [device_type::icon_state].")
		if(device_type::status_lights)
			TEST_ASSERT(icon_exists(device_type::icon, "[device_type::icon_state]_e"), "[device_type] has no light state [device_type::icon_state]_e.")
		for(var/shape in shapes)
			for(var/body in list("m", "f"))
				TEST_ASSERT(icon_exists(device_type::worn_sheet, "[shape]_[body]"), "[device_type] has no worn state [shape]_[body].")
				if(device_type::status_lights)
					TEST_ASSERT(icon_exists(device_type::worn_sheet, "[shape]_[body]_e"), "[device_type] has no worn light state [shape]_[body]_e.")
	for(var/obj/item/key/chastity/key_type as anything in typesof(/obj/item/key/chastity))
		TEST_ASSERT(icon_exists(key_type::icon, key_type::icon_state), "[key_type] has no icon.")
	TEST_ASSERT(icon_exists(/obj/item/key/chastity/remote::icon, "chastity_remote_e"), "The chastity remote has no light state.")
	for(var/lock in list("remote_lock", "remote_unlock"))
		TEST_ASSERT(length(strings("chastity.json", lock, "strings/aphelion")), "The chastity flavour bank [lock] is empty.")
	var/list/banks = list("arousal_penis", "arousal_edge", "arousal_large", "arousal_vagina", "arousal_intersex", "lock", "unlock",
		"lock_denial", "cursed_lock", "receive_penis", "receive_vagina", "receive_intersex")
	for(var/bank in banks)
		TEST_ASSERT(length(strings("chastity.json", bank, "strings/aphelion")), "The chastity flavour bank [bank] is empty.")
