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
	var/obj/item/clothing/sextoy/chastity/device = allocate(/obj/item/clothing/sextoy/chastity)

	TEST_ASSERT(!device.can_lewd_attach(wearer, partner, ORGAN_SLOT_PENIS), "A cage fit someone who doesn't want chastity devices.")
	TEST_ASSERT(wearer_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/chastity], TRUE), "Could not turn on chastity devices.")
	TEST_ASSERT(device.can_lewd_attach(wearer, partner, ORGAN_SLOT_PENIS), "A cage didn't fit a willing wearer with a penis.")
	var/obj/item/clothing/sextoy/chastity/insert/insert = allocate(/obj/item/clothing/sextoy/chastity/insert)
	TEST_ASSERT(!insert.can_lewd_attach(wearer, partner, ORGAN_SLOT_VAGINA), "An insertable belt fit someone without a vagina.")

	// Fitted, the penis is closed off and the cage draws in its place.
	put_on(wearer, device, ORGAN_SLOT_PENIS)
	TEST_ASSERT_EQUAL(penis.blocked_by, device, "The cage didn't close the penis off.")
	var/datum/bodypart_overlay/mutant/genital/overlay = penis.bodypart_overlay
	TEST_ASSERT_EQUAL(overlay.device_state, "cage_standard", "The cage isn't drawn over the penis.")
	TEST_ASSERT(limb_draws(wearer, "cage_standard_m"), "The chest doesn't draw the cage.")
	var/obj/item/clothing/sextoy/chastity/belt/belt = allocate(/obj/item/clothing/sextoy/chastity/belt)
	TEST_ASSERT(!belt.can_lewd_attach(wearer, partner, ORGAN_SLOT_PENIS), "A second device fit over a caged penis.")

	var/datum/interaction/stroke = allocate(/datum/interaction)
	stroke.name = "Stroke"
	stroke.target_required_parts = list(ORGAN_SLOT_PENIS)
	TEST_ASSERT(!stroke.allow_act(partner, wearer), "A penis interaction reached a caged penis.")
	var/datum/interaction/interaction = allocate(/datum/interaction)
	interaction.name = "Tug cage"
	interaction.interaction_requires = list(INTERACTION_REQUIRE_TARGET_CAGED)
	TEST_ASSERT(interaction.allow_act(partner, wearer), "A caged-penis interaction was refused on a caged penis.")
	TEST_ASSERT(!interaction.allow_act(wearer, partner), "A caged-penis interaction was offered on someone uncaged.")
	TEST_ASSERT_EQUAL(interaction.format_message_for("%TARGET_DEVICE%", partner, wearer), device.name, "The device token named the wrong thing.")
	penis.aroused = AROUSAL_FULL
	wearer.underwear = "Boxers"
	TEST_ASSERT(!wearer.has_bulge(), "A caged penis made a bulge.")
	wearer.underwear = "Nude"

	// The key tucked inside turns it; locked, it won't come off.
	var/obj/item/key/chastity/key = locate() in device
	TEST_ASSERT_NOTNULL(key, "The cage came without its key.")
	TEST_ASSERT_EQUAL(key.key_id, REF(device), "The key doesn't match its cage.")
	device.set_locked(TRUE, partner)
	TEST_ASSERT(!device.can_lewd_remove(partner), "A locked cage came off.")
	device.set_locked(FALSE, partner)
	TEST_ASSERT(device.can_lewd_remove(partner), "An unlocked cage wouldn't come off.")
	device.broken_lock = TRUE
	TEST_ASSERT(!device.set_locked(TRUE, partner), "A broken lock caught.")

	// Off again, the penis is free.
	device.come_off(wearer)
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
	var/list/pair = make_portal_pair("wallstuck")
	var/obj/structure/lewd_portal/portal = pair[1]
	TEST_ASSERT(portal.relays_interaction(interaction), "A wall portal did not relay chastity play.")

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

/// Chastity ownership follows occupied slots, organ changes and the OOC removal path.
/datum/unit_test/portal_test/chastity/lifecycle
	abstract_type = /datum/unit_test/portal_test/chastity/lifecycle

/datum/unit_test/portal_test/chastity/lifecycle/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Chastity lifecycle tests require enabled equipment preferences.")
		return
	check()

/// Runs one lifecycle regression with the normal equipment configuration.
/datum/unit_test/portal_test/chastity/lifecycle/proc/check()
	return

/// A wearer with explicit device permission and a deterministic primary organ.
/datum/unit_test/portal_test/chastity/lifecycle/proc/make_wearer()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/player = attach_portal_preferences(wearer)
	player.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/chastity], TRUE)
	return configure_test_penis(wearer) ? wearer : null

/// A secondary occupied slot must remain accessible instead of being trapped by a new device.
/datum/unit_test/portal_test/chastity/lifecycle/secondary_slots

/datum/unit_test/portal_test/chastity/lifecycle/secondary_slots/check()
	for(var/secondary_slot in list(ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS))
		var/mob/living/carbon/human/wearer = make_wearer()
		TEST_ASSERT_NOTNULL(wearer, "No wearer.")
		var/obj/item/organ/genital/secondary = secondary_slot == ORGAN_SLOT_VAGINA ? allocate(/obj/item/organ/genital/vagina) : allocate(/obj/item/organ/genital/anus)
		TEST_ASSERT(secondary.Insert(wearer, special = TRUE), "Could not insert secondary organ.")
		var/obj/item/clothing/sextoy/toy = allocate(/obj/item/clothing/sextoy)
		wearer.set_lewd_slot_item(secondary_slot, toy)
		toy.forceMove(wearer)
		toy.lewd_equipped(wearer, secondary_slot)
		var/obj/item/clothing/sextoy/chastity/device = secondary_slot == ORGAN_SLOT_VAGINA ? allocate(/obj/item/clothing/sextoy/chastity/belt) : allocate(/obj/item/clothing/sextoy/chastity/shielded)
		TEST_ASSERT(!device.can_lewd_attach(wearer, wearer, ORGAN_SLOT_PENIS), "A device fit over an occupied secondary slot [secondary_slot].")
		TEST_ASSERT_EQUAL(wearer.get_lewd_slot_item(secondary_slot), toy, "Refused fitting changed the existing item.")
		var/obj/item/clothing/sextoy/chastity/cage = allocate(/obj/item/clothing/sextoy/chastity)
		TEST_ASSERT(cage.can_lewd_attach(wearer, wearer, ORGAN_SLOT_PENIS), "An unrelated occupied slot prevented fitting.")
		TEST_ASSERT(wearer.dropItemToGround(toy, force = TRUE), "Could not remove the secondary item.")
		wearer.set_lewd_slot_item(secondary_slot, null)
		TEST_ASSERT(device.can_lewd_attach(wearer, wearer, ORGAN_SLOT_PENIS), "An empty secondary slot prevented fitting.")

/// An organ removed while covered cannot carry the old device's hidden state to its next body.
/datum/unit_test/portal_test/chastity/lifecycle/removed_cover

/datum/unit_test/portal_test/chastity/lifecycle/removed_cover/check()
	var/mob/living/carbon/human/wearer = make_wearer()
	TEST_ASSERT_NOTNULL(wearer, "No wearer.")
	var/obj/item/organ/genital/testicles/covered = allocate(/obj/item/organ/genital/testicles)
	TEST_ASSERT(covered.Insert(wearer, special = TRUE), "Could not insert covered organ.")
	var/datum/bodypart_overlay/mutant/genital/overlay = covered.bodypart_overlay
	var/obj/item/clothing/sextoy/chastity/belt/device = allocate(/obj/item/clothing/sextoy/chastity/belt)
	put_on(wearer, device, ORGAN_SLOT_PENIS)
	TEST_ASSERT(overlay.hidden_by_device, "The belt did not cover its secondary organ.")
	covered.Remove(wearer, special = TRUE)
	TEST_ASSERT(!overlay.hidden_by_device, "The removed organ retained the belt's hidden state.")
	TEST_ASSERT_EQUAL(device.wearer_ref?.resolve(), wearer, "Losing an optional covered organ unnecessarily removed the belt.")
	var/mob/living/carbon/human/recipient = make_wearer()
	TEST_ASSERT_NOTNULL(recipient, "No recipient.")
	TEST_ASSERT(covered.Insert(recipient, special = TRUE), "Could not transplant covered organ.")
	TEST_ASSERT(!overlay.hidden_by_device, "The transplanted organ inherited another body's belt.")
	var/obj/item/organ/genital/penis/primary = wearer.get_organ_slot(ORGAN_SLOT_PENIS)
	primary.Remove(wearer, special = TRUE)
	TEST_ASSERT_NULL(device.wearer_ref, "Losing the primary organ left the belt fitted.")
	TEST_ASSERT_NULL(primary.blocked_by, "The removed primary organ retained the belt's block.")

/// A device reconciles new organs and its displayed shape without registering its signals twice.
/datum/unit_test/portal_test/chastity/lifecycle/gained_organs

/datum/unit_test/portal_test/chastity/lifecycle/gained_organs/check()
	for(var/device_type in list(/obj/item/clothing/sextoy/chastity/belt, /obj/item/clothing/sextoy/chastity/cursed))
		var/mob/living/carbon/human/wearer = make_wearer()
		TEST_ASSERT_NOTNULL(wearer, "No wearer.")
		var/obj/item/organ/genital/penis/new_primary = wearer.get_organ_slot(ORGAN_SLOT_PENIS)
		new_primary.Remove(wearer, special = TRUE)
		var/obj/item/organ/genital/vagina/original = allocate(/obj/item/organ/genital/vagina)
		TEST_ASSERT(original.Insert(wearer, special = TRUE), "Could not insert initial organ.")
		var/obj/item/clothing/sextoy/chastity/device = allocate(device_type)
		put_on(wearer, device, ORGAN_SLOT_VAGINA)
		TEST_ASSERT_EQUAL(original.blocked_by, device, "Initial organ was not blocked.")
		TEST_ASSERT(new_primary.Insert(wearer), "Could not insert new primary organ.")
		TEST_ASSERT_EQUAL(new_primary.blocked_by, device, "The new organ bypassed the worn device.")
		TEST_ASSERT_EQUAL(device.drawn_over, ORGAN_SLOT_PENIS, "The device did not reconcile its drawing slot.")
		var/datum/bodypart_overlay/mutant/genital/old_overlay = original.bodypart_overlay
		var/datum/bodypart_overlay/mutant/genital/new_overlay = new_primary.bodypart_overlay
		TEST_ASSERT_NULL(old_overlay.device_state, "The old drawing slot still draws the device.")
		TEST_ASSERT_EQUAL(new_overlay.device_state, device.get_worn_shape(wearer), "The new drawing slot has the wrong device shape.")
		TEST_ASSERT(limb_draws(wearer, "[device.get_worn_shape(wearer)]_m"), "Normal insertion did not redraw the device on the new organ.")
		var/obj/item/organ/genital/testicles/covered = allocate(/obj/item/organ/genital/testicles)
		TEST_ASSERT(covered.Insert(wearer, special = TRUE), "Could not insert new covered organ.")
		var/datum/bodypart_overlay/mutant/genital/covered_overlay = covered.bodypart_overlay
		TEST_ASSERT_EQUAL(covered_overlay.hidden_by_device, !!(device.covers & CHASTITY_TESTICLES), "New cover state differs from the device's contract.")
		if(istype(device, /obj/item/clothing/sextoy/chastity/cursed))
			TEST_ASSERT(device.locked, "Reconciling organs unlocked a cursed device.")
		device.come_off(wearer)
		TEST_ASSERT_NULL(new_primary.blocked_by, "Removal retained a block on the new organ.")
		TEST_ASSERT_NULL(original.blocked_by, "Removal retained a block on the original organ.")
		TEST_ASSERT(!covered_overlay.hidden_by_device, "Removal retained a cover on the new organ.")

/// The OOC removal action bypasses gameplay locks and releases every device-owned resource.
/datum/unit_test/portal_test/chastity/lifecycle/safeword

/datum/unit_test/portal_test/chastity/lifecycle/safeword/check()
	for(var/device_type in list(/obj/item/clothing/sextoy/chastity, /obj/item/clothing/sextoy/chastity/cursed))
		var/mob/living/carbon/human/wearer = make_wearer()
		TEST_ASSERT_NOTNULL(wearer, "No wearer.")
		var/obj/item/organ/genital/penis/primary = wearer.get_organ_slot(ORGAN_SLOT_PENIS)
		var/datum/bodypart_overlay/mutant/genital/overlay = primary.bodypart_overlay
		var/obj/item/clothing/sextoy/chastity/device = allocate(device_type)
		put_on(wearer, device, ORGAN_SLOT_PENIS)
		device.set_locked(TRUE, wearer)
		TEST_ASSERT(!device.can_lewd_remove(wearer), "The test device was not locked.")
		wearer.__gvb_safeword()
		TEST_ASSERT_NULL(wearer.get_lewd_slot_item(ORGAN_SLOT_PENIS), "The OOC removal action left a locked device fitted.")
		TEST_ASSERT_NULL(device.wearer_ref, "The removed device retained its wearer.")
		TEST_ASSERT_NULL(primary.blocked_by, "The OOC removal action left an organ blocked.")
		TEST_ASSERT_NULL(overlay.device_state, "The OOC removal action left the device drawn.")
		TEST_ASSERT(!(device in SSobj.processing), "The removed device is still processing.")

/// Every lewd slot uses its item's normal removal lifecycle, including processing and worn overlays.
/datum/unit_test/portal_test/chastity/lifecycle/safeword_all_slots

/datum/unit_test/portal_test/chastity/lifecycle/safeword_all_slots/check()
	var/mob/living/carbon/human/wearer = make_wearer()
	TEST_ASSERT_NOTNULL(wearer, "No wearer.")
	var/list/slot_layers = list(
		ORGAN_SLOT_PENIS = PENIS_CLOTHING_LAYER,
		ORGAN_SLOT_VAGINA = VAGINA_CLOTHING_LAYER,
		ORGAN_SLOT_ANUS = ANUS_CLOTHING_LAYER,
		ORGAN_SLOT_NIPPLES = NIPPLES_CLOTHING_LAYER,
	)
	var/list/installed = list()
	for(var/slot, worn_layer in slot_layers)
		var/obj/item/clothing/sextoy/eggvib/toy = allocate(/obj/item/clothing/sextoy/eggvib)
		TEST_ASSERT(wearer.set_lewd_slot_item(slot, toy), "Could not install an item in [slot].")
		toy.forceMove(wearer)
		toy.lewd_equipped(wearer, slot)
		installed[slot] = toy
		TEST_ASSERT(toy in SSobj.processing, "The item in [slot] did not start processing.")
		wearer.overlays_standing[worn_layer] = mutable_appearance(toy.icon, toy.icon_state, worn_layer)
		TEST_ASSERT_NOTNULL(wearer.overlays_standing[worn_layer], "No worn overlay was available for [slot].")
	var/turf/expected_drop = wearer.drop_location()
	wearer.__gvb_safeword()
	for(var/slot, worn_layer in slot_layers)
		var/obj/item/clothing/sextoy/eggvib/toy = installed[slot]
		TEST_ASSERT_NULL(wearer.get_lewd_slot_item(slot), "The OOC removal action left [slot] occupied.")
		TEST_ASSERT_EQUAL(toy.loc, expected_drop, "The removed item from [slot] was not dropped at the wearer.")
		TEST_ASSERT(!(toy in SSobj.processing), "The removed item from [slot] is still processing.")
		TEST_ASSERT_NULL(wearer.overlays_standing[worn_layer], "The removed item from [slot] left a worn overlay.")
	wearer.__gvb_safeword()
	for(var/slot in slot_layers)
		TEST_ASSERT_NULL(wearer.get_lewd_slot_item(slot), "Repeating the OOC removal action restored [slot].")
