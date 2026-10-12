/// The lustwish MOD set, and the hypnotic phrase its visor shares with the hypnotic goggles.
/datum/unit_test/lustwish_mod
	parent_type = /datum/unit_test/portal_test // For attach_portal_preferences(), a mock player's preferences.
	abstract_type = /datum/unit_test/lustwish_mod

/// A test human whose mock player takes part in ERP, and takes sex toys or not.
/datum/unit_test/lustwish_mod/proc/player(takes_toys = TRUE)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent)
	attach_portal_preferences(person)
	set_pref(person, /datum/preference/toggle/erp/sex_toy, takes_toys)
	return person

/// Sets `person`'s mock player's `preference` toggle to `value`.
/datum/unit_test/lustwish_mod/proc/set_pref(mob/living/carbon/human/person, preference, value)
	if(!person.mock_client.prefs.write_preference(GLOB.preference_entries[preference], value))
		TEST_FAIL("Could not set [preference] to [value].")

/// Puts `person` in a powered, sealed MOD with the modules after it installed, and returns the MOD.
/datum/unit_test/lustwish_mod/proc/suit_up(mob/living/carbon/human/person, ...)
	var/obj/item/mod/control/mod = allocate(/obj/item/mod/control/pre_equipped/empty)
	for(var/obj/item/mod/module/module as anything in args.Copy(2))
		mod.install(module)
	TEST_ASSERT(person.equip_to_slot_if_possible(mod, ITEM_SLOT_BACK, disable_warning = TRUE), "Could not put the MOD on.")
	mod.quick_activation()
	return mod

/// The hypnotic phrase `source` gave `person`, if any.
/datum/unit_test/lustwish_mod/proc/phrase_from(mob/living/person, obj/item/source)
	for(var/datum/status_effect/hypnotic_phrase/phrase in person.status_effects)
		if(phrase.source == source)
			return phrase

/// Worn over the eyes, the goggles hypnotize a wearer who takes sex toys, show the phrase in the hypnosis alert for 30
/// seconds and let go when taken off or deleted; held, or on a wearer who does not take sex toys, they do nothing.
/datum/unit_test/lustwish_mod/hypnotic_goggles

/datum/unit_test/lustwish_mod/hypnotic_goggles/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/mob/living/carbon/human/person = player()
	var/obj/item/clothing/glasses/hypno/goggles = allocate(/obj/item/clothing/glasses/hypno)
	person.put_in_hands(goggles)
	TEST_ASSERT_NULL(phrase_from(person, goggles), "Goggles in a hand hypnotized their holder.")
	TEST_ASSERT(wear(person, goggles), "Could not put the goggles on.")
	var/datum/status_effect/hypnotic_phrase/phrase = phrase_from(person, goggles)
	TEST_ASSERT_NOTNULL(phrase, "Worn goggles did not hypnotize a wearer who takes sex toys.")
	TEST_ASSERT_EQUAL(phrase.phrase, goggles.codephrase, "The goggles hypnotized with another phrase than their own.")
	var/atom/movable/screen/alert/hypnosis/alert = person.alerts[ALERT_HYPNOSIS]
	TEST_ASSERT_EQUAL(alert?.desc, "\"[goggles.codephrase]\"... your mind seems to be fixated on this concept.", "The hypnosis alert does not show the phrase.")
	TEST_ASSERT_EQUAL(alert.timeout, world.time + 30 SECONDS - world.tick_lag, "The hypnosis alert does not last 30 seconds.")
	person.dropItemToGround(goggles)
	TEST_ASSERT_NULL(phrase_from(person, goggles), "Taking the goggles off did not end the hypnosis.")

	TEST_ASSERT(wear(person, goggles), "Could not put the goggles back on.")
	qdel(goggles)
	TEST_ASSERT_NULL(phrase_from(person, goggles), "Deleting worn goggles left their wearer hypnotized.")

	var/mob/living/carbon/human/unwilling = player(takes_toys = FALSE)
	var/obj/item/clothing/glasses/hypno/other = allocate(/obj/item/clothing/glasses/hypno)
	var/datum/log_category/game_log = logger.log_categories[LOG_CATEGORY_GAME]
	var/entries = game_log.entry_count
	TEST_ASSERT(wear(unwilling, other), "Could not put the other goggles on.")
	TEST_ASSERT_NULL(phrase_from(unwilling, other), "Goggles hypnotized a wearer who does not take sex toys.")
	TEST_ASSERT_NULL(unwilling.alerts[ALERT_HYPNOSIS], "Goggles alerted a wearer who does not take sex toys.")
	// A mock player gets no chat; the snap-out line is sent where this log line is written, so neither went out.
	TEST_ASSERT_EQUAL(game_log.entry_count, entries, "Goggles refused by their wearer logged a hypnosis ending.")

/// Puts `goggles` over `person`'s eyes - by equip_to_slot(), as Nova's mob_can_equip() reads the sex-toy preference
/// of a real client for its pref-checked clothes (clothing_pref_check.dm), and a mock player has none.
/datum/unit_test/lustwish_mod/hypnotic_goggles/proc/wear(mob/living/carbon/human/person, obj/item/clothing/glasses/hypno/goggles)
	person.equip_to_slot(goggles, ITEM_SLOT_EYES)
	return person.glasses == goggles

/// The visor hypnotizes while toggled on, or while the helmet is sealed once its wire is snipped, and lets go when
/// turned off, uninstalled, deleted or unsealed.
/datum/unit_test/lustwish_mod/hypno_visor

/datum/unit_test/lustwish_mod/hypno_visor/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/mob/living/carbon/human/person = player()
	var/obj/item/mod/module/lustwish/hypno_visor/visor = allocate(/obj/item/mod/module/lustwish/hypno_visor)
	var/obj/item/mod/control/mod = suit_up(person, visor)
	TEST_ASSERT_NULL(phrase_from(person, visor), "The visor hypnotized before it was toggled on.")
	TEST_ASSERT(visor.activate(person), "The visor did not toggle on.")
	TEST_ASSERT_NOTNULL(phrase_from(person, visor), "The visor toggled on without hypnotizing its wearer.")
	mod.uninstall(visor)
	TEST_ASSERT_NULL(phrase_from(person, visor), "The visor was uninstalled while on but its wearer stayed hypnotized.")
	mod.install(visor)
	visor.activate(person)
	visor.deactivate(person)
	TEST_ASSERT_NULL(phrase_from(person, visor), "The visor toggled off but its wearer stayed hypnotized.")
	visor.activate(person)
	qdel(visor)
	TEST_ASSERT_NULL(phrase_from(person, visor), "The visor was deleted while on but its wearer stayed hypnotized.")

	var/obj/item/mod/module/lustwish/hypno_visor/snipped = allocate(/obj/item/mod/module/lustwish/hypno_visor)
	snipped.module_type = MODULE_PASSIVE
	mod.install(snipped)
	TEST_ASSERT_NOTNULL(phrase_from(person, snipped), "A snipped visor did not hypnotize in a sealed suit.")
	var/obj/item/clothing/head/mod/helmet = locate() in mod.get_parts()
	mod.retract(null, helmet, instant = TRUE)
	TEST_ASSERT_NULL(phrase_from(person, snipped), "The helmet was unsealed but its snipped visor kept hypnotizing.")
	mod.deploy(null, helmet, instant = TRUE)
	TEST_ASSERT_NOTNULL(phrase_from(person, snipped), "A snipped visor did not hypnotize again once the helmet resealed.")
	mod.uninstall(snipped)
	TEST_ASSERT_NULL(phrase_from(person, snipped), "A snipped visor was uninstalled but its wearer stayed hypnotized.")
	mod.install(snipped)
	qdel(snipped)
	TEST_ASSERT_NULL(phrase_from(person, snipped), "A snipped visor was deleted but its wearer stayed hypnotized.")

/// The visor draws its spiral on the lustwish helmet only, and a snipped visor takes no settings.
/datum/unit_test/lustwish_mod/visor_spiral

/datum/unit_test/lustwish_mod/visor_spiral/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/obj/item/mod/control/lustwish = allocate(/obj/item/mod/control/pre_equipped/empty, null, /datum/mod_theme/standard/lustwish)
	var/obj/item/mod/module/lustwish/hypno_visor/visor = allocate(/obj/item/mod/module/lustwish/hypno_visor)
	visor.module_type = MODULE_PASSIVE // snipped, so it draws without a wearer to toggle it on
	lustwish.install(visor)
	TEST_ASSERT_EQUAL(visor.get_current_overlay_state(), "module_hypno_overlay", "The visor drew no spiral on the lustwish helmet.")
	visor.configure_edit("visor_effect", "0")
	TEST_ASSERT(visor.visor_effect, "A snipped visor took a setting.")
	lustwish.uninstall(visor)
	var/obj/item/mod/control/standard = allocate(/obj/item/mod/control/pre_equipped/empty)
	standard.install(visor)
	TEST_ASSERT_NULL(visor.get_current_overlay_state(), "The visor drew its spiral on another suit's helmet.")

/// The remote control module comes with its remote and holds nothing else, goes into a suit only once the remote is
/// out, and lets its remote go when it is deleted.
/datum/unit_test/lustwish_mod/remote_install

/datum/unit_test/lustwish_mod/remote_install/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/obj/item/mod/control/mod = allocate(/obj/item/mod/control/pre_equipped/empty)
	var/obj/item/mod/module/lustwish/remote_control/module = allocate(/obj/item/mod/module/lustwish/remote_control)
	var/obj/item/mod/remote/remote = locate() in module
	TEST_ASSERT_NOTNULL(remote, "The remote control module came without its remote.")
	TEST_ASSERT_EQUAL(remote.module, module, "The remote is not linked to its module.")
	mod.install(module)
	TEST_ASSERT_NULL(module.mod, "The remote control module went into a suit with its remote inside.")
	remote.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!module.atom_storage.can_insert(allocate(/obj/item/pen), messages = FALSE), "The remote control module took something other than its remote.")
	mod.install(module)
	TEST_ASSERT_EQUAL(module.mod, mod, "The remote control module did not go in once its remote was out.")
	qdel(module)
	TEST_ASSERT_NULL(remote.module, "The remote held on to its deleted module.")

/// The remote makes the suit's wearer emote only if they take sex toys, for a holder who takes part in ERP and is not
/// muted, sanitised as the me verb sanitises.
/datum/unit_test/lustwish_mod/forced_emote
	/// What the wearer emoted.
	var/list/emoted

/datum/unit_test/lustwish_mod/forced_emote/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/mob/living/carbon/human/person = player(takes_toys = FALSE)
	var/mob/living/carbon/human/holder = player()
	var/obj/item/mod/module/lustwish/remote_control/module = allocate(/obj/item/mod/module/lustwish/remote_control)
	var/obj/item/mod/remote/remote = locate() in module
	remote.forceMove(run_loc_floor_bottom_left)
	suit_up(person, module)
	RegisterSignal(person, COMSIG_MOB_EMOTE, PROC_REF(on_emote))
	TEST_ASSERT(!remote.force_emote(holder, "shivers."), "The remote reported an emote from a wearer who does not take sex toys.")
	set_pref(person, /datum/preference/toggle/erp/sex_toy, TRUE)
	set_pref(holder, /datum/preference/toggle/erp, FALSE)
	TEST_ASSERT(!remote.force_emote(holder, "shivers."), "A holder who does not take part in ERP made the wearer emote.")
	set_pref(holder, /datum/preference/toggle/erp, TRUE)
	holder.mock_client.prefs.muted |= MUTE_IC
	TEST_ASSERT(!remote.force_emote(holder, "shivers."), "A holder muted for IC messages made the wearer emote.")
	holder.mock_client.prefs.muted &= ~MUTE_IC
	TEST_ASSERT(!LAZYLEN(emoted), "A refused emote was emoted anyway.")
	TEST_ASSERT(remote.force_emote(holder, "<b>shivers.</b>"), "A wearer who takes sex toys could not be made to emote.")
	TEST_ASSERT_EQUAL(LAZYACCESS(emoted, 1), "&lt;b&gt;shivers.&lt;/b&gt;", "The forced emote was not sanitised.")

/datum/unit_test/lustwish_mod/forced_emote/proc/on_emote(mob/source, datum/emote/emote, act, type_override, message, intentional)
	SIGNAL_HANDLER
	LAZYADD(emoted, message)

/// The remote runs the suit's activation, parts, modules and lock as its holder and nothing else of the suit's window,
/// only for a wearer who takes sex toys and a holder who takes part in ERP, and only in range - beyond it, its window
/// stays open but inert and says why.
/datum/unit_test/lustwish_mod/remote_relay
	/// The suit window's actions that reached the suit.
	var/list/relayed

/datum/unit_test/lustwish_mod/remote_relay/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/mob/living/carbon/human/person = player()
	var/mob/living/carbon/human/holder = player()
	var/obj/item/mod/module/lustwish/remote_control/module = allocate(/obj/item/mod/module/lustwish/remote_control)
	var/obj/item/mod/remote/remote = locate() in module
	remote.forceMove(run_loc_floor_bottom_left)
	var/obj/item/mod/control/mod = suit_up(person, module)
	RegisterSignal(mod, COMSIG_UI_ACT, PROC_REF(on_suit_act))
	RegisterSignal(mod, COMSIG_MOD_ACTIVATE, PROC_REF(on_suit_activate))
	var/datum/tgui/ui = allocate(/datum/tgui, holder, remote, "MODsuitRemote")
	for(var/action in list("activate", "deploy", "select", "configure", "lock", "call", "eject_pai", "pin"))
		remote.ui_act(action, list(), ui, ui.state)
	TEST_ASSERT_EQUAL(english_list(relayed), "activate, deploy, select, configure and lock", "The remote relayed other actions than the suit's activation, parts, modules and lock.")
	relayed = null
	set_pref(holder, /datum/preference/toggle/erp, FALSE)
	remote.ui_act("lock", list(), ui, ui.state)
	TEST_ASSERT_NULL(relayed, "A holder who does not take part in ERP drove the suit.")
	set_pref(holder, /datum/preference/toggle/erp, TRUE)
	set_pref(person, /datum/preference/toggle/erp/sex_toy, FALSE)
	remote.ui_act("lock", list(), ui, ui.state)
	TEST_ASSERT_NULL(relayed, "The suit of a wearer who does not take sex toys was driven.")
	set_pref(person, /datum/preference/toggle/erp/sex_toy, TRUE)
	ui.set_state(GLOB.always_state) // the remote's own bound alone: the default state shuts out a holder with no client
	ui.process_status()
	TEST_ASSERT_EQUAL(ui.status, UI_INTERACTIVE, "The remote could not drive a suit beside it.")
	remote.control_range = -1 // nobody is in range
	ui.process_status()
	TEST_ASSERT_EQUAL(ui.status, UI_UPDATE, "Out of range, the remote's window did not stay open and inert.")
	TEST_ASSERT_EQUAL(remote.ui_data(holder)["refusal"], "Out of Range", "Out of range, the remote's window did not say so.")
	remote.ui_act("lock", list(), ui, ui.state)
	TEST_ASSERT_NULL(relayed, "The remote drove a suit beyond its range.")

/datum/unit_test/lustwish_mod/remote_relay/proc/on_suit_act(datum/source, mob/user, action, list/params)
	SIGNAL_HANDLER
	LAZYADD(relayed, action)

/// Stops a relayed activation before its sequence starts.
/datum/unit_test/lustwish_mod/remote_relay/proc/on_suit_activate(datum/source, mob/user)
	SIGNAL_HANDLER
	return MOD_CANCEL_ACTIVATE
