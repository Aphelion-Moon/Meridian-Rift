/// A bulge is the bulge look a covered penis draws (mal, 2026-10-04): bulge requirements, words and portals follow it.
/// Each change goes through the writers the game uses, which end in the body update that draws (or clears) the look.
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
	var/datum/interaction/stroke = allocate(/datum/interaction)
	stroke.name = "Stroke"
	stroke.target_required_parts = list(ORGAN_SLOT_PENIS)
	var/template = "%TARGET_CROTCH% %TARGET_BULGE_COVER%"

	// Hard but out in the open is no bulge.
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
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

	TEST_ASSERT(penis.apply_arousal_label("Partly aroused"), "The half-hard writer was unavailable.")
	TEST_ASSERT(owner.has_bulge(), "A half-hard penis under a jumpsuit was not a bulge.")
	TEST_ASSERT(penis.apply_arousal_label("Not aroused"), "The soft writer was unavailable.")
	TEST_ASSERT(!owner.has_bulge(), "A soft penis was a bulge.")
	TEST_ASSERT_EQUAL(rub.format_message_for("%TARGET_CROTCH%", partner, owner), "crotch", "A soft penis read as a bulge.")
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")

	// A suit that hides the bulge leaves none to interact with; one that leaves the groin clear names the garment the
	// bulge is drawn on, and one that is itself the cover names itself.
	var/obj/item/clothing/suit/apron/worn_suit = allocate(/obj/item/clothing/suit/apron)
	TEST_ASSERT(owner.equip_to_slot_if_possible(worn_suit, ITEM_SLOT_OCLOTHING), "Could not put a suit on the test human.")
	TEST_ASSERT(!owner.has_bulge(), "A suit that hides the bulge left one to interact with.")
	TEST_ASSERT(!rub.allow_act(partner, owner), "A bulge interaction was offered under a suit that hides the bulge.")
	owner.dropItemToGround(worn_suit)
	var/obj/item/clothing/suit/armor/hos/trenchcoat/coat = allocate(/obj/item/clothing/suit/armor/hos/trenchcoat)
	TEST_ASSERT(owner.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "Could not put the open coat on.")
	TEST_ASSERT(owner.has_bulge(), "An open coat hid the bulge it leaves clear.")
	TEST_ASSERT_EQUAL(owner.bulge_cover_name(), jumpsuit.name, "A bulge under an open coat was not named for the jumpsuit it is drawn on.")
	owner.dropItemToGround(coat)
	var/obj/item/clothing/suit/apron/overalls/suit = allocate(/obj/item/clothing/suit/apron/overalls)
	TEST_ASSERT(owner.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Could not put the overalls on.")
	TEST_ASSERT(owner.has_bulge(), "Overalls that are the cover drew no bulge.")
	TEST_ASSERT_EQUAL(owner.bulge_cover_name(), suit.name, "A bulge on the overalls was not named for them.")
	owner.dropItemToGround(suit)
	owner.dropItemToGround(jumpsuit)
	TEST_ASSERT(!owner.has_bulge(), "A bulge stayed after undressing.")

	// A garment over the groin that draws no bulge (the mummy wrapping has no bulge family) leaves none.
	var/obj/item/clothing/under/costume/mummy/uniform = allocate(/obj/item/clothing/under/costume/mummy)
	TEST_ASSERT(owner.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Could not put the mummy wrapping on.")
	TEST_ASSERT(uniform.body_parts_covered & GROIN, "The mummy wrapping does not cover the groin: the test needs one that does.")
	TEST_ASSERT(!owner.has_bulge(), "A garment that draws no bulge left one to interact with.")
	owner.dropItemToGround(uniform)

	owner.underwear = "Boxers"
	owner.update_body()
	TEST_ASSERT(owner.has_bulge(), "A hard penis in underwear was not a bulge.")
	TEST_ASSERT_EQUAL(owner.bulge_cover_name(), "underwear", "A bulge in underwear showed through something else.")
	owner.undershirt = "Shirt - Leotard"
	owner.update_body()
	TEST_ASSERT_EQUAL(owner.bulge_cover_name(), "leotard", "A groin-length undershirt did not name the bulge.")
	owner.undershirt = "Nude"
	owner.update_body()

	// Underwear the body does not draw (the trait a species without underwear has) shows no bulge.
	ADD_TRAIT(owner, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
	owner.update_body()
	TEST_ASSERT(!owner.has_bulge(), "Underwear the body does not draw left a bulge to interact with.")
	REMOVE_TRAIT(owner, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
	owner.update_body()
	TEST_ASSERT(owner.has_bulge(), "Underwear drawn again did not bring the bulge back.")

	// Hidden by the underwear, a penis is no penis to interact with. Drawn over clothes it is exposed. Above the underwear
	// it is drawn over its only cover, so it is exposed with no bulge: the penis interactions reach it and the bulge ones
	// do not, until it is layered below the underwear again (mal, 2026-10-04). Never shown has nothing to show.
	TEST_ASSERT(!penis.is_exposed(), "A penis hidden by the underwear was exposed.")
	TEST_ASSERT(!stroke.allow_act(partner, owner), "A penis interaction reached a penis hidden by the underwear.")
	TEST_ASSERT(penis.apply_visibility_label("Custom") && penis.apply_layering_label("Above all clothing"), "The layering writers were unavailable.")
	TEST_ASSERT(!owner.has_bulge(), "A penis drawn over clothing was a bulge.")
	TEST_ASSERT(penis.is_exposed(), "A penis drawn over clothing was not exposed.")
	TEST_ASSERT(penis.apply_layering_label("Above underwear"), "The layering writer was unavailable.")
	TEST_ASSERT(!owner.has_bulge(), "A penis layered above its only cover, the underwear, was a bulge.")
	TEST_ASSERT(penis.is_exposed(), "A penis layered above its only cover, the underwear, was not exposed.")
	TEST_ASSERT(stroke.allow_act(partner, owner), "A penis interaction was refused on a penis layered above the underwear.")
	TEST_ASSERT(!rub.allow_act(partner, owner), "A bulge interaction was offered on a penis layered above the underwear.")
	// The uniform is checked before the layer: a jumpsuit over the groin still covers it. Set back to Hidden by clothes,
	// it keeps its layer setting, but what counts is the layer it is drawn at, and the underwear covers it again.
	TEST_ASSERT(owner.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "Could not dress the test human again.")
	TEST_ASSERT(!penis.is_exposed(), "A jumpsuit did not cover a penis layered above the underwear.")
	TEST_ASSERT(!stroke.allow_act(partner, owner), "A penis interaction reached a penis under a jumpsuit, layered above the underwear.")
	owner.dropItemToGround(jumpsuit)
	TEST_ASSERT(penis.apply_visibility_label("Hidden by clothes"), "The visibility writer was unavailable.")
	TEST_ASSERT(!penis.is_exposed(), "The underwear did not cover a penis set back to Hidden by clothes.")
	TEST_ASSERT(penis.apply_visibility_label("Custom"), "The visibility writer was unavailable.")
	TEST_ASSERT(penis.is_exposed(), "A penis set to Custom again was not layered above the underwear.")
	TEST_ASSERT(penis.apply_layering_label("Below underwear"), "The layering writer was unavailable.")
	TEST_ASSERT(owner.has_bulge(), "A penis layered below the underwear was not a bulge.")
	TEST_ASSERT(!penis.is_exposed(), "A penis layered below the underwear was exposed.")
	TEST_ASSERT(!stroke.allow_act(partner, owner), "A penis interaction reached a penis layered below the underwear.")
	TEST_ASSERT(rub.allow_act(partner, owner), "A bulge interaction was refused on a penis layered below the underwear.")
	TEST_ASSERT(penis.apply_layering_label("Normal"), "The layering writer was unavailable.")
	TEST_ASSERT(owner.has_bulge(), "A custom-layered penis under underwear was not a bulge.")
	TEST_ASSERT(penis.apply_visibility_label("Never show"), "The visibility writer was unavailable.")
	TEST_ASSERT(!owner.has_bulge(), "A penis set to never show was a bulge.")
	TEST_ASSERT(penis.apply_visibility_label("Hidden by clothes"), "The visibility writer was unavailable.")

	// Both portal modes relay the penis, so they relay its bulge too, from either side.
	var/list/pair = make_portal_pair("wallstuck")
	var/obj/structure/lewd_portal/portal = pair[1]
	var/datum/interaction/headpat = allocate(/datum/interaction)
	headpat.name = "Headpat"
	TEST_ASSERT(portal.relays_interaction(rub), "A wall portal did not relay a bulge.")
	TEST_ASSERT(portal.relays_interaction(grind, as_user = TRUE), "A wall portal did not relay its occupant's own bulge.")
	TEST_ASSERT(!portal.relays_interaction(grind), "A wall portal relayed the other side's bulge.")
	TEST_ASSERT(!portal.relays_interaction(headpat), "A wall portal relayed an interaction with no lower body part.")
	portal.portal_mode = "gloryhole"
	TEST_ASSERT(portal.relays_interaction(rub), "A gloryhole did not relay a bulge.")

	// The penis's own overlay draws the bulge: the jumpsuit's shape, tinted from the jumpsuit's cloth.
	owner.underwear = "Nude"
	var/obj/item/clothing/under/color/grey/pants = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(owner.equip_to_slot_if_possible(pants, ITEM_SLOT_ICLOTHING), "Could not dress the test human again.")
	penis.set_size(4)
	TEST_ASSERT(penis.apply_arousal_label("Partly aroused"), "The half-hard writer was unavailable.")
	var/missing = bulge_missing(owner, penis, FALSE, 1)
	TEST_ASSERT(!missing, "A half-hard covered penis drew no bulge: [missing]")
	TEST_ASSERT(penis.apply_arousal_label("Very aroused"), "The hard writer was unavailable.")
	missing = bulge_missing(owner, penis, TRUE, 1)
	TEST_ASSERT(!missing, "A hard covered penis drew no bulge: [missing]")
	var/datum/bodypart_overlay/mutant/genital/penis/drawing = penis.bodypart_overlay
	TEST_ASSERT(drawing.bulge_cloth && drawing.bulge_cloth != "#808080", "The jumpsuit's colour wasn't sampled.")
	penis.set_size(12)
	missing = bulge_missing(owner, penis, TRUE, 4)
	TEST_ASSERT(!missing, "A long penis did not draw its size 4 bulge: [missing]")
	var/obj/item/clothing/suit/apron/overapron = allocate(/obj/item/clothing/suit/apron)
	TEST_ASSERT(owner.equip_to_slot_if_possible(overapron, ITEM_SLOT_OCLOTHING), "Could not put the apron back on.")
	TEST_ASSERT_NULL(drawing.bulge_key, "A hiding suit left the bulge drawn.")

/// What the chest is missing of the jumpsuit's bulge shape for this form and size, in its white kind masks; null when
/// it draws it.
/datum/unit_test/portal_test/bulge/proc/bulge_missing(mob/living/carbon/human/owner, obj/item/organ/genital/penis/penis, hard, size)
	var/datum/bodypart_overlay/mutant/genital/penis/drawing = penis.bodypart_overlay
	var/datum/bulge_print_template/shape = bulge_shape(/datum/bulge_family/jumpsuits, hard, size, FALSE, /datum/sprite_accessory/genital/penis/human, penis.uses_skintones)
	if(!shape)
		return "no jumpsuit shape"
	if(!drawing.bulge_key)
		return "no look"
	if(drawing.bulge_template != shape)
		return "the look's shape is [drawing.bulge_template?.key], not [shape.key]"
	var/mask = shape.mask_cloth || shape.mask_light || shape.mask_highlight || shape.mask_shade || shape.mask_deep_shade
	if(!mask)
		return "the shape has no kind masks"
	for(var/image/drawn as anything in owner.limb_icon_cache[owner.icon_render_keys[BODY_ZONE_CHEST]])
		if(drawn.icon == mask)
			return null
	return "the chest does not draw the shape's masks; chest key [owner.icon_render_keys[BODY_ZONE_CHEST]]"

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
	var/datum/emote/living/sniff/found
	for(var/datum/emote/living/sniff/emote in GLOB.emote_list["sniff"])
		found = emote
	TEST_ASSERT_NOTNULL(found, "There is no sniff emote.")

	sniffer.setDir(EAST)
	TEST_ASSERT_EQUAL(found.get_sniff_target(sniffer), faced, "A sniff missed the human in front.")
	sniffer.setDir(WEST)
	TEST_ASSERT_NULL(found.get_sniff_target(sniffer), "A sniff at nobody found a target.")
	sniffer.start_pulling(pulled)
	TEST_ASSERT_EQUAL(found.get_sniff_target(sniffer), pulled, "A sniff missed the human being pulled.")
