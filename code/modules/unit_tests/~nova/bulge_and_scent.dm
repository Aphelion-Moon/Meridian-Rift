/// A covered penis at least half hard is a bulge: bulge requirements, words and portals follow it.
/datum/unit_test/portal_test/bulge

/datum/unit_test/portal_test/bulge/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Bulges need genitals, which the ERP config disables.")
		return

	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/partner = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/penis/penis = configure_test_penis(owner)
	TEST_ASSERT_NOTNULL(penis, "The test penis could not be set up.")

	var/datum/interaction/rub = allocate(/datum/interaction)
	rub.name = "Rub bulge"
	rub.interaction_requires = list(INTERACTION_REQUIRE_TARGET_BULGE)
	var/datum/interaction/grind = allocate(/datum/interaction)
	grind.name = "Grind your bulge"
	grind.interaction_requires = list(INTERACTION_REQUIRE_SELF_BULGE)
	var/template = "%TARGET_CROTCH% %TARGET_BULGE_COVER%"

	// Hard but out in the open is no bulge.
	penis.aroused = AROUSAL_FULL
	TEST_ASSERT(!owner.has_bulge(), "An exposed penis was a bulge.")
	TEST_ASSERT(!rub.allow_act(partner, owner), "A bulge interaction was offered on an exposed penis.")

	var/obj/item/clothing/under/color/grey/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(owner.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Could not dress the test human.")
	TEST_ASSERT(owner.has_bulge(), "A hard penis under a jumpsuit was not a bulge.")
	TEST_ASSERT(rub.allow_act(partner, owner), "A bulge interaction was refused on a bulge.")
	TEST_ASSERT(!rub.allow_act(owner, partner), "A target bulge interaction checked the user's bulge.")
	TEST_ASSERT(grind.allow_act(owner, partner), "A self bulge interaction was refused on the user's bulge.")
	TEST_ASSERT(!grind.allow_act(partner, owner), "A self bulge interaction checked the target's bulge.")
	TEST_ASSERT_EQUAL(rub.format_message_for(template, partner, owner), "bulge [jumpsuit.name]", "Bulge words under a jumpsuit are wrong.")
	TEST_ASSERT_EQUAL(rub.format_message_for("%TARGET_CROTCH%", owner, partner), "crotch", "Someone without a bulge had one in the words.")

	penis.aroused = AROUSAL_PARTIAL
	TEST_ASSERT(owner.has_bulge(), "A half-hard penis under a jumpsuit was not a bulge.")
	penis.aroused = AROUSAL_NONE
	TEST_ASSERT(!owner.has_bulge(), "A soft penis was a bulge.")
	TEST_ASSERT_EQUAL(rub.format_message_for("%TARGET_CROTCH%", partner, owner), "crotch", "A soft penis read as a bulge.")
	penis.aroused = AROUSAL_FULL

	// The outermost cover names the bulge.
	var/obj/item/clothing/suit/apron/apron = allocate(/obj/item/clothing/suit/apron)
	TEST_ASSERT(owner.equip_to_slot_if_possible(apron, ITEM_SLOT_OCLOTHING), "Could not put a suit on the test human.")
	TEST_ASSERT_EQUAL(owner.bulge_cover_name(), apron.name, "A bulge under a suit showed through the uniform.")
	owner.dropItemToGround(apron)
	owner.dropItemToGround(jumpsuit)
	TEST_ASSERT(!owner.has_bulge(), "A bulge stayed after undressing.")

	owner.underwear = "Boxers"
	TEST_ASSERT(owner.has_bulge(), "A hard penis in underwear was not a bulge.")
	TEST_ASSERT_EQUAL(owner.bulge_cover_name(), "underwear", "A bulge in underwear showed through something else.")
	owner.undershirt = "Shirt - Leotard"
	TEST_ASSERT_EQUAL(owner.bulge_cover_name(), "leotard", "A groin-length undershirt did not name the bulge.")
	owner.undershirt = "Nude"

	// Drawn over clothes is exposed, and never shown has nothing to show.
	var/datum/bodypart_overlay/mutant/genital/overlay = penis.bodypart_overlay
	penis.visibility_preference = GENITAL_CUSTOM
	overlay.layer_mode = GENITAL_LAYER_ABOVE_ALL
	TEST_ASSERT(!owner.has_bulge(), "A penis drawn over clothing was a bulge.")
	overlay.layer_mode = GENITAL_LAYER_NORMAL
	TEST_ASSERT(owner.has_bulge(), "A custom-layered penis under underwear was not a bulge.")
	penis.visibility_preference = GENITAL_NEVER_SHOW
	TEST_ASSERT(!owner.has_bulge(), "A penis set to never show was a bulge.")
	penis.visibility_preference = GENITAL_HIDDEN_BY_CLOTHES

	// Both portal modes relay the penis, so they relay its bulge too, from either side.
	var/list/portals = make_portal_pair("wallstuck")
	var/obj/structure/lewd_portal/portal = portals[1]
	var/datum/interaction/headpat = allocate(/datum/interaction)
	headpat.name = "Headpat"
	TEST_ASSERT(portal.relays_interaction(rub), "A wall portal did not relay a bulge.")
	TEST_ASSERT(portal.relays_interaction(grind, as_user = TRUE), "A wall portal did not relay its occupant's own bulge.")
	TEST_ASSERT(!portal.relays_interaction(grind), "A wall portal relayed the other side's bulge.")
	TEST_ASSERT(!portal.relays_interaction(headpat), "A wall portal relayed an interaction with no lower body part.")
	portal.portal_mode = "gloryhole"
	TEST_ASSERT(portal.relays_interaction(rub), "A gloryhole did not relay a bulge.")

	// The bulge shows on the body: soft half hard, a tent fully hard, in the colour of what covers it.
	owner.underwear = "Nude"
	var/obj/item/clothing/under/color/grey/pants = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(owner.equip_to_slot_if_possible(pants, ITEM_SLOT_ICLOTHING), "Could not dress the test human again.")
	penis.aroused = AROUSAL_PARTIAL
	owner.update_body_parts()
	TEST_ASSERT(chest_draws(owner, "semi_1") && chest_draws(owner, "semi_1_fabric"), "A half-hard covered penis drew no soft bulge.")
	penis.aroused = AROUSAL_FULL
	owner.update_body_parts()
	TEST_ASSERT(chest_draws(owner, "tent_1"), "A hard covered penis drew no tent.")
	TEST_ASSERT_EQUAL(owner.get_groin_fabric_colour(), owner.get_groin_fabric_colour(), "The fabric colour isn't stable.")
	TEST_ASSERT_NOTEQUAL(owner.get_groin_fabric_colour(), "#808080", "The jumpsuit's colour wasn't sampled.")
	penis.genital_size = 12
	TEST_ASSERT_EQUAL(owner.get_bulge_look(), "tent_4", "A long penis didn't make the biggest tent.")
	var/obj/item/clothing/suit/apron/overapron = allocate(/obj/item/clothing/suit/apron)
	TEST_ASSERT(owner.equip_to_slot_if_possible(overapron, ITEM_SLOT_OCLOTHING), "Could not put the apron back on.")
	TEST_ASSERT_NULL(owner.get_bulge_look(), "A suit over the groin let a bulge show.")

/// Whether the human's chest draws an overlay with `state`.
/datum/unit_test/portal_test/bulge/proc/chest_draws(mob/living/carbon/human/owner, state)
	var/obj/item/bodypart/chest/chest = owner.get_bodypart(BODY_ZONE_CHEST)
	for(var/image/drawn in chest.get_limb_icon())
		if(drawn.icon_state == state)
			return TRUE
	return FALSE

/// Lewd interactions leave a giver's scent on a receiver until it fades or washes off.
/datum/unit_test/portal_test/scent_transfer

/datum/unit_test/portal_test/scent_transfer/Run()
	if(CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Scent transfer is an ERP preference, which the config disables.")
		return

	var/mob/living/carbon/human/consistent/giver = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/receiver = allocate(/mob/living/carbon/human/consistent)
	giver.dna.features[ERP_FLAVOR_DNA_SCENT] = "cedar and machine oil"
	receiver.dna.features[ERP_FLAVOR_DNA_SCENT] = "lavender"
	var/datum/client_interface/giver_client = attach_portal_preferences(giver)
	var/datum/client_interface/receiver_client = attach_portal_preferences(receiver)

	giver.leave_scent_on(receiver)
	TEST_ASSERT_NULL(receiver.has_status_effect(/datum/status_effect/scent_transfer), "A scent moved with neither preference on.")
	TEST_ASSERT(giver_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/scent_transfer_give], TRUE), "Could not turn on giving scents.")
	giver.leave_scent_on(receiver)
	TEST_ASSERT_NULL(receiver.has_status_effect(/datum/status_effect/scent_transfer), "A scent moved to someone who doesn't receive scents.")

	TEST_ASSERT(receiver_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/scent_transfer_receive], TRUE), "Could not turn on receiving scents.")
	giver.leave_scent_on(receiver)
	var/datum/status_effect/scent_transfer/left_on = receiver.has_status_effect(/datum/status_effect/scent_transfer)
	TEST_ASSERT_NOTNULL(left_on, "A giver's scent did not move to a receiver.")
	TEST_ASSERT_EQUAL(left_on.scent, "cedar and machine oil", "The receiver carries the wrong scent.")

	// It moves one way only: the receiver gives nothing, and the giver takes nothing.
	receiver.leave_scent_on(giver)
	TEST_ASSERT_NULL(giver.has_status_effect(/datum/status_effect/scent_transfer), "A scent moved against both preferences.")
	giver.leave_scent_on(giver)
	TEST_ASSERT_NULL(giver.has_status_effect(/datum/status_effect/scent_transfer), "Someone carried their own scent.")

	receiver.wash(CLEAN_WASH)
	TEST_ASSERT_NULL(receiver.has_status_effect(/datum/status_effect/scent_transfer), "Washing left a partner's scent behind.")

/// A bare *sniff goes to whoever the sniffer is pulling, else whoever stands in front of them.
/datum/unit_test/sniff_target

/datum/unit_test/sniff_target/Run()
	var/mob/living/carbon/human/consistent/sniffer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/faced = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))
	var/mob/living/carbon/human/consistent/pulled = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, NORTH))
	var/datum/emote/living/sniff/sniff
	for(var/datum/emote/living/sniff/emote in GLOB.emote_list["sniff"])
		sniff = emote
	TEST_ASSERT_NOTNULL(sniff, "There is no sniff emote.")

	sniffer.setDir(EAST)
	TEST_ASSERT_EQUAL(sniff.get_sniff_target(sniffer), faced, "A sniff missed the human in front.")
	sniffer.setDir(WEST)
	TEST_ASSERT_NULL(sniff.get_sniff_target(sniffer), "A sniff at nobody found a target.")
	sniffer.start_pulling(pulled)
	TEST_ASSERT_EQUAL(sniff.get_sniff_target(sniffer), pulled, "A sniff missed the human being pulled.")
