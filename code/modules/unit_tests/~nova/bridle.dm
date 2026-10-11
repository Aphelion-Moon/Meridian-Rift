/// The bridle can't go on a player who does not take sex toys. Its bit muffles the wearer whether it is set before or
/// while the bridle is worn, covers their mouth, and frees them when it is loosened or the bridle comes off; its blinders
/// darken the wearer's sight while lowered; alt-click steps through none, blinders, bit and both; and secured straps
/// hold both where they are. The strip menu offers "Adjust bridle" on a worn bridle to a player who takes part in ERP
/// when its wearer takes sex toys - never on a bridle held in a hand, nor on a wearer with no player. Each check runs
/// on, so one run names every failure.
/datum/unit_test/bridle
	parent_type = /datum/unit_test/portal_test // For attach_portal_preferences(), a mock player's preferences.

/datum/unit_test/bridle/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/mob/living/carbon/human/consistent/wearer = allocate(__IMPLIED_TYPE__)
	var/obj/item/clothing/mask/bridle/bridle = allocate(__IMPLIED_TYPE__)
	if(bridle.mob_can_equip(wearer, ITEM_SLOT_MASK))
		TEST_FAIL("The bridle could go on a player who does not take sex toys.")
	wearer.equip_to_slot(bridle, ITEM_SLOT_MASK)
	press(bridle, wearer, /datum/action/item_action/bridle_bit)
	if(!is_muffled(wearer))
		TEST_FAIL("Setting the bit of a worn bridle did not muffle its wearer.")
	press(bridle, wearer, /datum/action/item_action/bridle_blinders)
	if(!wearer.screens["tint"])
		TEST_FAIL("Lowering the blinders of a worn bridle did not darken its wearer's sight.")
	press(bridle, wearer, /datum/action/item_action/bridle_blinders)
	if(wearer.screens["tint"])
		TEST_FAIL("Raising the blinders of a worn bridle left its wearer's sight dark.")

	var/mob/living/carbon/human/consistent/pony = allocate(__IMPLIED_TYPE__)
	var/obj/item/clothing/mask/bridle/bitted = allocate(__IMPLIED_TYPE__)
	press(bitted, pony, /datum/action/item_action/bridle_bit)
	pony.equip_to_slot(bitted, ITEM_SLOT_MASK)
	if(!is_muffled(pony) || !pony.is_mouth_covered())
		TEST_FAIL("Putting on a bitted bridle did not muffle its wearer and cover their mouth.")
	pony.dropItemToGround(bitted, force = TRUE)
	if(is_muffled(pony))
		TEST_FAIL("Taking off a bitted bridle left its wearer muffled.")
	pony.equip_to_slot(bitted, ITEM_SLOT_MASK)
	press(bitted, pony, /datum/action/item_action/bridle_bit)
	if(is_muffled(pony) || pony.is_mouth_covered())
		TEST_FAIL("Loosening the bit of a worn bridle left its wearer muffled or their mouth covered.")
	var/modes = ""
	for(var/i in 1 to 4)
		bitted.click_alt(pony)
		modes += "[bitted.mode]"
	if(modes != "1230")
		TEST_FAIL("Four alt-clicks stepped a bridle through modes [modes], not 1230.")

	var/obj/item/clothing/mask/bridle/secured = allocate(__IMPLIED_TYPE__)
	secured.attack_self(pony)
	press(secured, pony, /datum/action/item_action/bridle_bit)
	secured.click_alt(pony)
	if(secured.mode)
		TEST_FAIL("Secured straps let the bit or the blinders move.")

	attach_portal_preferences(wearer) // The adjuster's mock player first, so only the wearer's lack of one can refuse.
	if(strip_offered(pony, wearer))
		TEST_FAIL("The strip menu offered to adjust the bridle of a wearer with no player.")
	attach_portal_preferences(pony)
	if(!strip_offered(pony, wearer))
		TEST_FAIL("The strip menu did not offer to adjust a worn bridle.")
	wearer.put_in_l_hand(secured)
	if(strip_offered(wearer, pony, STRIPPABLE_ITEM_LHAND))
		TEST_FAIL("The strip menu offered to adjust a bridle held in a hand.")
	set_pref(pony, /datum/preference/toggle/erp/sex_toy, FALSE)
	if(strip_offered(pony, wearer))
		TEST_FAIL("The strip menu offered to adjust the bridle of a wearer who does not take sex toys.")
	set_pref(pony, /datum/preference/toggle/erp/sex_toy, TRUE)
	set_pref(wearer, /datum/preference/toggle/erp, FALSE)
	if(strip_offered(pony, wearer))
		TEST_FAIL("The strip menu let a player who does not take part in ERP adjust a bridle.")

/// Presses `bridle`'s action button of `action_type` for `user`.
/datum/unit_test/bridle/proc/press(obj/item/clothing/mask/bridle/bridle, mob/user, action_type)
	bridle.ui_action_click(user, locate(action_type) in bridle.actions)

/// Whether what `wearer` says comes out muffled.
/datum/unit_test/bridle/proc/is_muffled(mob/living/wearer)
	var/list/speech_args = new /list(SPEECH_MODS)
	speech_args[SPEECH_MESSAGE] = "Easy there"
	SEND_SIGNAL(wearer, COMSIG_MOB_SAY, speech_args)
	return speech_args[SPEECH_MESSAGE] != "Easy there"

/// Whether the strip menu offers `user` "Adjust bridle" on what `owner` has in the strip slot `key`.
/datum/unit_test/bridle/proc/strip_offered(mob/owner, mob/user, key = STRIPPABLE_ITEM_MASK)
	var/datum/strippable_item/strippable_item = GLOB.strippable_human_items[key]
	return ("adjust_bridle" in strippable_item.get_alternate_actions(owner, user, strippable_item.get_item(owner)))

/// Sets `player`'s mock `preference` to `value`.
/datum/unit_test/bridle/proc/set_pref(mob/player, preference, value)
	if(!player.mock_client.prefs.write_preference(GLOB.preference_entries[preference], value))
		TEST_FAIL("Could not set [preference] to [value].")
