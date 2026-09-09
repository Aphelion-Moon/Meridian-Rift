/// Admin encryption key with basically every channel
/obj/item/encryptionkey/admin
	name = "subspace encryption key"
	desc = "Holding and looking at this little chip fills you with a sense of existential dread. The taste of metaknowledge fills your mouth. \
		It tastes salty. Like tears. Why do you know what tears taste like? \
		You're a badmin, of course you know what tears taste like. Those of your coworkers taste better."
	icon = 'icons/map_icons/items/encryptionkey.dmi'
	icon_state = "captain"
	post_init_icon_state = "cypherkey_cube"
	channels = list(// Debug Encryption Key and Headset, still manually populates the channel list because I am not a real coder, just a denthead
		RADIO_CHANNEL_AI_PRIVATE = 1,
		RADIO_CHANNEL_CENTCOM = 1,
		RADIO_CHANNEL_COMMAND = 1,
		RADIO_CHANNEL_CYBERSUN = 1,
		RADIO_CHANNEL_ENGINEERING = 1,
		RADIO_CHANNEL_ENTERTAINMENT = 1,
		RADIO_CHANNEL_FACTION = 1,
		RADIO_CHANNEL_GUILD = 1,
		RADIO_CHANNEL_INTERDYNE = 1,
		RADIO_CHANNEL_MEDICAL = 1,
		RADIO_CHANNEL_SCIENCE = 1,
		RADIO_CHANNEL_SECURITY = 1,
		RADIO_CHANNEL_SERVICE = 1,
		RADIO_CHANNEL_SOLFED = 1,
		RADIO_CHANNEL_SUPPLY = 1,
		RADIO_CHANNEL_SYNDICATE = 1,
		RADIO_CHANNEL_TARKON = 1,
	)
	greyscale_config = /datum/greyscale_config/encryptionkey_cube
	greyscale_colors = "#2b2793#dca01b"
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF

/obj/item/encryptionkey/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

// Our new headset.
/obj/item/radio/headset/admin
	name = "bluespace headset"
	desc = "Keeps you tuned in on the subspace data streams and threads, enabling you to communicate and act with ease."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "blue-headset"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "blue-headset"
	keyslot2 = null
	keyslot = /obj/item/encryptionkey/admin
	inhand_icon_state = null
	subspace_transmission = TRUE
	/// If true, subspace_transmission can be toggled at will.
	subspace_switchable = TRUE
	freerange = TRUE
	command = TRUE
	radio_noise = FALSE
	keylock = RADIO_KEYSLOT_LOCKED
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	w_class = WEIGHT_CLASS_TINY
	/// A cache of ghosts orbiting this item
	var/list/mob/dead/observer/spirits = list()
	/// Whether the debug-reach feature is currently toggled on
	var/admin_reach = FALSE
	/// Cooldown for pinging ghosts
	COOLDOWN_DECLARE(subspace_harmonic_signaller_cooldown)

/obj/item/radio/headset/admin/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/earprotection, EAR_PROTECTION_HEAVY)
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)
	AddElement(/datum/element/babel_clothing)

/obj/item/radio/headset/admin/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/radio/headset/admin/examine(mob/user)
	. = ..()
	. += span_notice("Ctrl-Shift-Click while wearing to ping your subspace harmonic signaller, which will notify all observers to come orbit you.")
	. += span_notice("Ctrl-Click while wearing to toggle Subspace Reach. Currently [admin_reach ? "active" : "inactive"].")

/obj/item/radio/headset/admin/item_ctrl_click(mob/user)
	. = CLICK_ACTION_BLOCKING
	// Subspace Reach hands out TRAIT_ADMIN_REACHABLE, which bypasses reach, machine and action checks. Gate it like every other admin toggle.
	if(!user.client?.holder)
		return
	if(user.get_item_by_slot(slot_flags) != src)
		to_chat(user, span_warning("You need to be wearing [src] to toggle it."))
		return
	if(admin_reach)
		turn_off(user)
	else
		turn_on(user)
	return CLICK_ACTION_SUCCESS

/obj/item/radio/headset/admin/proc/turn_on(mob/user)
	admin_reach = TRUE
	ADD_TRAIT(user, TRAIT_ADMIN_REACHABLE, ADMIN_GEAR_TRAIT)
	add_filter("admin_active_item", 1, outline_filter(1, "#cc00ff", OUTLINE_SQUARE))
	to_chat(user, span_notice("[src] tunnels through narrative continuity. Reach, interaction, and collision limits are bypassed."))
	update_appearance()

/obj/item/radio/headset/admin/proc/turn_off(mob/user)
	admin_reach = FALSE
	REMOVE_TRAIT(user, TRAIT_ADMIN_REACHABLE, ADMIN_GEAR_TRAIT)
	remove_filter("admin_active_item")
	to_chat(user, span_notice("[src] powers down and returns you to a non-reality warping state."))
	update_appearance()

// Safechecks
/obj/item/radio/headset/admin/dropped(mob/user, silent)
	. = ..()
	if(admin_reach)
		turn_off(user)

/obj/item/radio/headset/admin/doStrip(mob/user, mob/stripped_mob)
	. = ..()
	if(admin_reach)
		turn_off(stripped_mob)

// Thank you, code\modules\mining\lavaland\mining_loot\megafauna\ash_drake.dm - /obj/item/melee/ghost_sword, very cool
/obj/item/radio/headset/admin/click_ctrl_shift(mob/user)//CtrlShift click as its a secondary function for this item.
	. = ..()
	if(!user.client?.holder)
		return

	if(!COOLDOWN_FINISHED(src, subspace_harmonic_signaller_cooldown))
		to_chat(user, span_warning("The subspace harmonic signaller is cooling down! Using this too frequently might upset the powers that be!"))
		return

	COOLDOWN_START(src, subspace_harmonic_signaller_cooldown, 5 SECONDS) // let's just assume the admin is responsible behind the wheel
	START_PROCESSING(SSobj, src)// keeps whoever turns up visible, and stops itself once they wander off
	to_chat(user, span_notice("The subspace harmonic signaller charges up and releases a pulse, notifying all the eyes-between-spaces of your activities!"))
	message_admins("[ADMIN_LOOKUPFLW(user)] alerted ghosts with their [name].")// Also tell admemes. I forgor what the admin follow thing is.
	notify_ghosts(
		"[user.real_name] has attenuated and pulsed the subspace harmonic signaller of [user.p_their()] [name], alerting the eyes-between-spaces of their activities!",
		source = user,
		ignore_key = POLL_IGNORE_SPECTRAL_BLADE, // we keep this because it's going to draw the same people—chronic observers
		header = "An Admin is trying to get the Ghosts attention!",
	)
	return CLICK_ACTION_SUCCESS

// Only ticks while there are ghosts to keep track of - see the signaller above. Scanning the turf forever would drag
// every passing orbiter onto the headset whether anyone asked for them or not.
/obj/item/radio/headset/admin/process()
	if(!ghost_check())
		STOP_PROCESSING(SSobj, src)

/obj/item/radio/headset/admin/proc/ghost_check()
	var/turf/cur_turf = get_turf(src)
	if(isnull(cur_turf))
		return 0
	var/list/current_spirits = list()
	for(var/atom/random_thing as anything in cur_turf.get_all_contents())
		random_thing.transfer_observers_to(src)

	for(var/mob/dead/observer/ghost in orbiters?.orbiter_list)
		ghost.SetInvisibility(INVISIBILITY_NONE, id = type, priority = INVISIBILITY_PRIORITY_BASIC_ANTI_INVISIBILITY)
		current_spirits |= ghost

	for(var/mob/dead/observer/ghost in spirits - current_spirits)
		ghost.RemoveInvisibility(type)

	spirits = current_spirits
	return length(spirits)

/obj/item/radio/headset/admin/subspace
	name = "subspace headset"
	desc = parent_type::desc + " This one has stopped bothering to pretend it is only a radio."
	icon_state = "sub-headset"
	worn_icon_state = "sub-headset"

//Hey check out this cancerous atompath.
//Squishes together Syndie Thermal Xrays, Debug Goggles, and the Engine Admin glasses.
//New trait code at modular_nova\master_files\code\datums\wires\_wires.dm to show all wires w/o needing to hold blueprints or abductor multitool
// TODO: sprites
//The one set of lenses to rule them all
//code\modules\clothing\glasses\engine_goggles.dm & code\modules\clothing\glasses\_glasses.dm

#define MODE_NONE ""
#define MODE_MESON "meson"
#define MODE_TRAY "t-ray"
#define MODE_SHUTTLE "shuttle"
#define MODE_PIPE_CONNECTABLE "connectable"
#define MODE_ATMOS_THERMAL "atmospheric-thermal"
#define MODE_AREA_BLUEPRINTS "area-blueprints"

/obj/item/clothing/glasses/meson/engine/admin/debug
	name = "subspace contacts"
	desc = "One of Central Command's best kept secrets, resting on the eyes of many of its officers, operatives, and technicians."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_items.dmi'
	icon_state = "contacts"
	inhand_icon_state = "trayson-"
	// The parent type's update_icon_state() (code/modules/clothing/glasses/engine_goggles.dm) overwrites icon_state,
	// inhand_icon_state and worn_icon_state to "trayson-[mode]" on every appearance update, so worn_icon has to be a
	// file that actually has those states - admin_items.dmi already does, being shared with the ground/inhand icon.
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/admin_items.dmi'
	base_icon_state = "trayson-"
	flags_cover = GLASSESCOVERSEYES// dont ask me why were doing this we just are
	flash_protect = FLASH_PROTECTION_WELDER//No need for the welding gas mask from before
	lighting_cutoff = LIGHTING_CUTOFF_HIGH// Slightly better vision just for wearing them, regardless of mode
	glass_colour_type = FALSE// Stop touching my icon omg
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	modes = list(MODE_NONE, MODE_MESON, MODE_TRAY, MODE_PIPE_CONNECTABLE, MODE_ATMOS_THERMAL, MODE_AREA_BLUEPRINTS, MODE_SHUTTLE)
	clothing_traits = list(
		TRAIT_SHOW_ALL_WIRES,
		TRAIT_REAGENT_SCANNER,
		TRAIT_MADNESS_IMMUNE,
		TRAIT_MEDICAL_HUD,
		TRAIT_SECURITY_HUD,
		TRAIT_DIAGNOSTIC_HUD,
		TRAIT_BOT_PATH_HUD,
		TRAIT_NEARSIGHTED_CORRECTED,
	)
	pickup_sound = SFX_GOGGLES_PICKUP
	drop_sound = SFX_GOGGLES_DROP
	equip_sound = SFX_GOGGLES_EQUIP
	// Sets up our ctrl shift click bonus feature
	/// 0 = normal sight, 1 = perfect sight (see/hear through walls, see ghosts), 2 = omniscience (also sees abstract things like landmarks).
	// You cannot set this to anything other than 1, because the switch updates are buried in the clickmod proc below. These wont process at initialize atm otherwise.
	// If you're bothered enough do stuff with init before you modify this
	var/vision_mode = 0

/obj/item/clothing/glasses/meson/engine/admin/debug/Initialize(mapload)
	. = ..()
	clothing_flags |= ADMIN_CLOTHING_FLAGS// set here rather than in the type def so the parent type's own clothing flags survive
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/clothing/glasses/meson/engine/admin/debug/examine(mob/user)
	. = ..()
	. += span_notice("Ctrl-Shift-Click to cycle vision modes. Currently: [vision_mode == 0 ? "normal" : vision_mode == 1 ? "perfect vision" : "omniscient"].")

// The actual click proc itself
/obj/item/clothing/glasses/meson/engine/admin/debug/click_ctrl_shift(mob/user)
	if(!ishuman(user))// sanity blocking if the click is somehow not coming from a human
		return CLICK_ACTION_BLOCKING
	if(!user.client?.holder)
		return CLICK_ACTION_BLOCKING
	var/mob/living/carbon/human/human_user = user
	if(human_user.get_item_by_slot(ITEM_SLOT_EYES) != src)// checks through a new system that we're human, and its on our eyeballs. because we just checked if theyre human, this is of course a human_user, so just call them that
		balloon_alert(user, "must be worn on your eyes!")// if not tell the dumbass
		return CLICK_ACTION_BLOCKING

	vision_mode = (vision_mode + 1) % 3//math. take your current vision mode and add one, up to a maximum of three, cycling

	switch(vision_mode)// the active switcher
		if(0)// normal sight. this switch disables everything when hit
			reset_vision(human_user)
			balloon_alert(user, "vision: normal")
		if(1)// perfect sight. Goldilocks land
			vision_flags |= (SEE_TURFS|SEE_MOBS|SEE_OBJS)
			attach_clothing_traits(TRAIT_XRAY_VISION)
			ADD_TRAIT(human_user, TRAIT_XRAY_HEARING, ADMIN_TRAIT)
			human_user.see_invisible = SEE_INVISIBLE_OBSERVER// primary diff between this and switch 2
			lighting_cutoff = LIGHTING_CUTOFF_FULLBRIGHT
			add_filter("admin_active_item", 1, outline_filter(1, "#cc00ff", OUTLINE_SQUARE))
			balloon_alert(user, "vision: perfect")
		if(2)// omniscience. pretty much the same as last, except for
			vision_flags |= (SEE_TURFS|SEE_MOBS|SEE_OBJS)
			attach_clothing_traits(TRAIT_XRAY_VISION)
			ADD_TRAIT(human_user, TRAIT_XRAY_HEARING, ADMIN_TRAIT)
			human_user.see_invisible = INVISIBILITY_ABSTRACT// show me weird things so i dont have to take out sdmm or vv
			lighting_cutoff = LIGHTING_CUTOFF_FULLBRIGHT
			add_filter("admin_active_item", 1, outline_filter(2, "#ff0000", OUTLINE_SQUARE))// its worth adding an active outline differentiating the state. pretty sure this is the only place i've done this so far, atow
			balloon_alert(user, "vision: omniscient")

	human_user.update_sight()
	return CLICK_ACTION_SUCCESS

/**
 * Winds the goggles back to mode 0 and strips everything the higher modes handed out.
 *
 * Shared by the mode cycle and by dropped(), so taking the goggles off in mode 1 or 2 can't leave the wearer
 * with wall-hearing and x-ray for the rest of the round. Does not call update_sight() - the callers do.
 * Arguments:
 * * wearer - whoever is currently wearing them. Non-humans only get the item-side state reset.
 */
/obj/item/clothing/glasses/meson/engine/admin/debug/proc/reset_vision(mob/wearer)
	vision_mode = 0
	vision_flags &= ~(SEE_TURFS|SEE_MOBS|SEE_OBJS)
	detach_clothing_traits(TRAIT_XRAY_VISION)
	lighting_cutoff = LIGHTING_CUTOFF_HIGH
	remove_filter("admin_active_item")// clears outlines set by the higher modes
	if(!ishuman(wearer))
		return
	var/mob/living/carbon/human/human_wearer = wearer
	REMOVE_TRAIT(human_wearer, TRAIT_XRAY_HEARING, ADMIN_TRAIT)// wall ears
	human_wearer.see_invisible = initial(invis_view)// our actual see_invis processor

/obj/item/clothing/glasses/meson/engine/admin/debug/dropped(mob/user)
	. = ..()
	if(!vision_mode)
		return
	reset_vision(user)
	user.update_sight()

#undef MODE_NONE
#undef MODE_MESON
#undef MODE_TRAY
#undef MODE_SHUTTLE
#undef MODE_PIPE_CONNECTABLE
#undef MODE_ATMOS_THERMAL
#undef MODE_AREA_BLUEPRINTS

// Admin Helmet. Percepto has the most kit shoved in it, we will just steal that
// Now we get really magical. Eventually. I wanted the helmets to do something funny, but because its hidden under the modsuit... Needs to be less important.
// We love casting spells. Did you know the perceptomatrix counts for spell clothing? Aint that neat.
/obj/item/clothing/head/helmet/perceptomatrix/admin
	name = "bluespace visor"
	desc = "This exceptional piece of headgear seems to be one of the main reality-warping sources of the administrative kit. It feels nearly weightless on your head."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "blue-visor"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "blue-visor"
	base_icon_state = "blue-visor"
	inhand_icon_state = null
	core_installed = TRUE
	armor_type = /datum/armor/admin
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF

//Intercepts init icon state from parent, this might not be necessary. It also might not be working right, I dont know enough to know.
/obj/item/clothing/head/helmet/perceptomatrix/admin/Initialize(mapload)
	. = ..()
	clothing_flags |= ADMIN_CLOTHING_FLAGS// set here rather than in the type def so the parent type's own clothing flags survive
	AddComponent(/datum/component/hat_stabilizer, loose_hat = FALSE)
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/clothing/head/helmet/perceptomatrix/admin/subspace
	name = "subspace visor"
	desc = parent_type::desc + " This one stopped pretending to be armour and simply refuses to let anything reach you."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "sub-visor"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "sub-visor"
	base_icon_state = "sub-visor"
	armor_type = /datum/armor/admin/badmin

//Admin Gas Mask
//Creates a new filter
//code\modules\clothing\masks\gas_filter.dm
/obj/item/gas_filter/admin
	filter_status = 1000
	filter_strength_high = 10
	filter_efficiency = 1
	high_filtering_gases = list(
		/datum/gas/bz,
		/datum/gas/carbon_dioxide,
		/datum/gas/freon,
		/datum/gas/goblin,
		/datum/gas/halon,
		/datum/gas/healium,
		/datum/gas/hypernoblium,
		/datum/gas/miasma,
		/datum/gas/nitrous_oxide,
		/datum/gas/plasma,
		/datum/gas/proto_nitrate,
		/datum/gas/tritium,
		/datum/gas/zauker,
	)

//code\modules\clothing\masks\gasmask.dm
/obj/item/clothing/mask/gas/atmos/admin
	name = "bluespace mask"
	desc = "A proprietary filtration mask which route gasses that CentCom deems toxic directly into the space between dimensions.\
		Wasteful? Totally. Convenient? Extremely. Has the added side effect of partially displacing you into that dimension."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "blue-mask"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "blue-mask"
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON
	inhand_icon_state = null
	max_filters = 2
	starting_filter_type = /obj/item/gas_filter/admin
	armor_type = /datum/armor/admin
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	flags_inv = HIDEFACE|HIDEHAIR|HIDEFACIALHAIR|HIDEEARS|HIDEEYES|HIDESNOUT
	flags_cover = HEADCOVERSEYES | HEADCOVERSMOUTH | EARS_COVERED
	var/admin_phasing = FALSE

// Attempts to create a wall-phasing mode that you can enable with control clicking the helmet
/// Whether phasing is currently active
/obj/item/clothing/mask/gas/atmos/admin/item_ctrl_click(mob/user)
	if(!isliving(user))
		return CLICK_ACTION_BLOCKING
	if(!user.client?.holder)
		return NONE
	// Must be worn, not just held
	var/mob/living/wearer = user
	if(wearer.get_slot_by_item(src) != ITEM_SLOT_MASK)
		balloon_alert(user, "must be worn!")
		return CLICK_ACTION_BLOCKING

	admin_phasing = !admin_phasing
	if(admin_phasing)
		attach_clothing_traits(list(TRAIT_MOVE_PHASING, TRAIT_ADMIN_STEALTH, TRAIT_UNKNOWN_VOICE))
		add_filter("admin_active_item", 1, outline_filter(1, "#cc00ff", OUTLINE_SQUARE))
	else
		detach_clothing_traits(list(TRAIT_MOVE_PHASING, TRAIT_ADMIN_STEALTH, TRAIT_UNKNOWN_VOICE))
		remove_filter("admin_active_item")

	balloon_alert(user, "phasing [admin_phasing ? "enabled" : "disabled"]")
	return CLICK_ACTION_SUCCESS

/obj/item/clothing/mask/gas/atmos/admin/dropped(mob/user)
	. = ..()
	if(admin_phasing)
		admin_phasing = FALSE
		// detach_clothing_traits is already called by the parent unequip logic, but we reset our state variable here

//Informs our silly staff that they can do this, if they bothered to inspect
/obj/item/clothing/mask/gas/atmos/admin/examine(mob/user)
	. = ..()
	. += span_notice("Ctrl-Click while wearing to toggle phasing. Currently [admin_phasing ? "active" : "inactive"].")


/obj/item/clothing/mask/gas/atmos/admin/Initialize(mapload)
	. = ..()
	clothing_flags |= ADMIN_CLOTHING_FLAGS// set here rather than in the type def so the parent type's own clothing flags survive
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/clothing/mask/gas/atmos/admin/subspace
	name = "subspace mask"
	desc = parent_type::desc + " This one displaces rather more of you, and rather more permanently."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "sub-mask"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "sub-mask"
	armor_type = /datum/armor/admin/badmin

// Glorious Stable Slime Management System
// Cytotheca is greek!
// TODO: sprites
/obj/item/storage/neck/admin/cytotheca
	name = "bluespace cytotheca"
	desc = "Why is it squishy?"
	worn_icon = 'modular_nova/modules/tarkon/icons/mob/clothing/neck.dmi'
	icon = 'modular_nova/modules/tarkon/icons/obj/clothing/neck.dmi'
	icon_state = "armplate_shemaugh"
	slot_flags = ITEM_SLOT_NECK | ITEM_SLOT_POCKETS
	storage_type = /datum/storage/admin/cytotheca
	w_class = WEIGHT_CLASS_TINY
	resistance_flags = INDESTRUCTIBLE
	obj_flags = parent_type::obj_flags | ADMIN_OBJ_FLAGS
	obj_flags_nova = parent_type::obj_flags_nova | ADMIN_OBJ_FLAGS_NOVA
	var/admin_godmode = TRUE

/obj/item/storage/neck/admin/cytotheca/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)
	if(admin_godmode)
		add_filter("admin_active_item", 1, outline_filter(1, "#cc00ff", OUTLINE_SQUARE))//We are only doing this because admin_godmode is currently defaulting to true.

// Creates a storage on the cytotheca, which acts as our base level storage for stablizied slime cores to interact with our mob
// We populate with a subspace_pouch
/obj/item/storage/neck/admin/cytotheca/PopulateContents()
	new /obj/item/storage/subspace_pouch/cytotheca(src)

// TRAIT_GODMODE must use REF(src) in all three of dropped(), equipped() and item_ctrl_click() - a REMOVE_TRAIT with a
// mismatched source silently does nothing.
/obj/item/storage/neck/admin/cytotheca/dropped(mob/user)
	. = ..()
	if(isnull(user))
		return
	REMOVE_TRAIT(user, TRAIT_GODMODE, REF(src))

/obj/item/storage/neck/admin/cytotheca/equipped(mob/user, slot, initial = TRUE)
	. = ..()
	if(admin_godmode && slot == ITEM_SLOT_NECK)
		ADD_TRAIT(user, TRAIT_GODMODE, REF(src))

/// Whether godmode is currently active
/obj/item/storage/neck/admin/cytotheca/item_ctrl_click(mob/user)
	. = ..()
	if(!user.client?.holder)
		return NONE
	if(!isliving(user))
		return CLICK_ACTION_BLOCKING
	// Must be worn, not just held
	var/mob/living/wearer = user
	if(wearer.get_slot_by_item(src) != ITEM_SLOT_NECK)
		balloon_alert(user, "must be worn!")
		return CLICK_ACTION_BLOCKING
	admin_godmode = !admin_godmode
	if(admin_godmode)
		ADD_TRAIT(wearer, TRAIT_GODMODE, REF(src))
		add_filter("admin_active_item", 1, outline_filter(1, "#cc00ff", OUTLINE_SQUARE))
	else
		REMOVE_TRAIT(wearer, TRAIT_GODMODE, REF(src))
		remove_filter("admin_active_item")
	balloon_alert(user, "godmode [admin_godmode ? "enabled" : "disabled"]")
	return CLICK_ACTION_SUCCESS

// Informs our silly staff that they can do this, if they bothered to inspect
/obj/item/storage/neck/admin/cytotheca/examine(mob/user)
	. = ..()
	. += span_notice("Ctrl-Click while wearing to toggle godmode. Currently [admin_godmode ? "active" : "inactive"].")

// Special pouch full of stabilized slimes! This replaces the stabilized extracts box
/obj/item/storage/subspace_pouch/cytotheca
	icon = 'modular_nova/master_files/icons/obj/clothing/belts.dmi'
	worn_icon = 'modular_nova/master_files/icons/mob/clothing/belt.dmi'
	name = "slimy subspace pouch"
	desc = span_notice("Gross. Click to open the pouch.")
	icon_state = "storage_pouch_icon"
	worn_icon_state = "storage_pouch_icon"
	storage_type = /datum/storage/admin/cytotheca

// Highway robbery off the stable slime box, idk if this is current for all available stables or not
/obj/item/storage/subspace_pouch/cytotheca/PopulateContents()
	new /obj/item/slimecross/stabilized/adamantine(src)
	new /obj/item/slimecross/stabilized/black(src)
	new /obj/item/slimecross/stabilized/blue(src)
	new /obj/item/slimecross/stabilized/bluespace(src)
	new /obj/item/slimecross/stabilized/cerulean(src)
	new /obj/item/slimecross/stabilized/darkblue(src)
	new /obj/item/slimecross/stabilized/darkpurple(src)
	new /obj/item/slimecross/stabilized/gold(src)
	new /obj/item/slimecross/stabilized/green(src)
	new /obj/item/slimecross/stabilized/grey(src)
	new /obj/item/slimecross/stabilized/lightpink(src)
	new /obj/item/slimecross/stabilized/metal(src)
	new /obj/item/slimecross/stabilized/oil(src)
	new /obj/item/slimecross/stabilized/orange(src)
	new /obj/item/slimecross/stabilized/pink(src)
	new /obj/item/slimecross/stabilized/purple(src)
	new /obj/item/slimecross/stabilized/pyrite(src)
	new /obj/item/slimecross/stabilized/rainbow(src)
	new /obj/item/slimecross/stabilized/red(src)
	new /obj/item/slimecross/stabilized/sepia(src)
	new /obj/item/slimecross/stabilized/silver(src)
	new /obj/item/slimecross/stabilized/yellow(src)

// Keeping it thematic
// TODO: sprites
/obj/item/storage/neck/admin/cytotheca/subspace
	name = "subspace cytotheca"
	desc = "How is this squishier?"
	worn_icon = 'modular_nova/modules/tarkon/icons/mob/clothing/neck.dmi'
	icon = 'modular_nova/modules/tarkon/icons/obj/clothing/neck.dmi'
	icon_state = "armplate_shemaugh"

// New admin undersuit
/obj/item/clothing/under/admin
	name = "bluespace techsuit"
	desc = "A perfectly tailored and customized skin suit made specifically for this technician. \
	Composed of experimental textiles, and assembled with the legendary Bluespace Sewing Machine, it fits the body with perfect comfort, and carries an air of security."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "blue-techsuit"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "blue-techsuit"
	worn_icon_digi = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing_digi.dmi'
	inhand_icon_state = null
	has_sensor = NO_SENSORS//admin techs should NEVER be on sensors
	resistance_flags = INDESTRUCTIBLE
	body_parts_covered = CHEST|GROIN|LEGS|FEET|ARMS|HANDS
	armor_type = /datum/armor/clothing_under/admin
	cold_protection = CHEST | GROIN | LEGS | FEET | ARMS | HANDS
	min_cold_protection_temperature = SPACE_SUIT_MIN_TEMP_PROTECT
	heat_protection = CHEST|GROIN|LEGS|FEET|ARMS|HANDS
	max_heat_protection_temperature = SPACE_SUIT_MAX_TEMP_PROTECT
	// It took a while to curate this trait list and I dont think its done. If you find anything else useful you should throw it on here.
	clothing_traits = list(TRAIT_CLEANBOT_WHISPERER, TRAIT_AI_ACCESS, TRAIT_BLOB_ALLY, TRAIT_TENACIOUS, TRAIT_UNBREAKABLE, TRAIT_UNOBSERVANT, TRAIT_INVISIBLE_TO_CAMERA, TRAIT_NO_STRIP, TRAIT_TURF_IGNORE_SLIPPERY, TRAIT_TURF_IGNORE_SLOWDOWN, TRAIT_OVERWATCH_IMMUNE, TRAIT_TENTACLE_IMMUNE, TRAIT_WEATHER_IMMUNE, TRAIT_LAVA_IMMUNE, TRAIT_KNOW_ENGI_WIRES, TRAIT_FERAL_BITER, TRAIT_ADAMANTINE_EXTRACT_ARMOR, TRAIT_ROCK_EATER, TRAIT_SUPERMATTER_SOOTHER, TRAIT_UNNATURAL_RED_GLOWY_EYES, TRAIT_QUICKER_CARRY, TRAIT_NO_STAGGER, TRAIT_IGNORESLOWDOWN, TRAIT_NO_BLOOD_OVERLAY, TRAIT_NODISMEMBER, TRAIT_NOSOFTCRIT, TRAIT_NOHARDCRIT, TRAIT_NODEATH)

/obj/item/clothing/under/admin/examine(mob/user)
	. = ..()
	. += span_notice("Ctrl-Shift-Click while worn to teleport to a player, area, landmark, or point of interest.")

// Attempts to replace the teleport menu as observer with an IC solution.
/obj/item/clothing/under/admin/click_ctrl_shift(mob/user)
	if(!isliving(user))// If they're dead
		return CLICK_ACTION_BLOCKING// go home ur dead
	if(!user.client?.holder)// if they arent holding admin perms
		to_chat(user, span_warning("Absolutely not! Go apply for Staff!"))// sass the dumbass
		return CLICK_ACTION_BLOCKING// go home pleb
	var/mob/living/living_user = user// setup a var with our user
	if(living_user.get_item_by_slot(ITEM_SLOT_ICLOTHING) != src)// if our living user is not wearing this in our jumpsuit slot
		balloon_alert(user, "must be worn!")// give them a light reminder
		return CLICK_ACTION_BLOCKING// try again buddy

	var/list/destinations = list()// begins setting up our list of destinations. this might be too costly to keep depending on how this works on livetime

	for(var/mob/player_mob as anything in GLOB.player_list)// for player mobs from anything the global player list
		if(!player_mob.client)
			continue
		destinations["\[Player\] [player_mob.name] ([player_mob.key])"] = player_mob//anything inside brackets will be checked as a var so regulate it with \ \ to stop that behavior

	var/static/list/area_destinations
	if(isnull(area_destinations))
		area_destinations = list()
		for(var/area/possible_area as anything in get_sorted_areas())// populates possible areas from this sexy fucking proc that exists UGH look at that
			area_destinations["\[Area\] [possible_area.name]"] = possible_area// follow our standard set above
	destinations += area_destinations

	for(var/obj/effect/landmark/marker as anything in GLOB.landmarks_list)// landmarks are mapped things, usually
		destinations["\[Landmark\] [marker.name]"] = marker

	for(var/datum/point_of_interest/mob_poi/mob_poi as anything in SSpoints_of_interest.mob_points_of_interest)// looks for interesting mobs
		if(!mob_poi.target)
			continue
		destinations["\[POI\] [mob_poi.target.name]"] = mob_poi.target

	for(var/datum/point_of_interest/other_poi as anything in SSpoints_of_interest.other_points_of_interest)// looks for novel pois
		if(!other_poi.target)
			continue
		destinations["\[POI\] [other_poi.target.name]"] = other_poi.target

	var/picked = tgui_input_list(user, "Select a destination", "Subspace Teleport", sort_list(destinations))// sets up our option list. sortlist is also sexy.
	if(isnull(picked))// sanity cancelling out
		return CLICK_ACTION_BLOCKING// thanks for wasting all of the above resources :')
	if(QDELETED(src) || !user.client?.holder || living_user.get_item_by_slot(ITEM_SLOT_ICLOTHING) != src)
		return CLICK_ACTION_BLOCKING

	var/atom/target = destinations[picked]// sets up our target from the selection through our destinations
	if(QDELETED(target))
		return CLICK_ACTION_BLOCKING
	var/turf/target_turf = get_turf(target)// checks the turf at our target. this does some kinda funny stuff if you sniff further in. dont, it's ok
	if(isnull(target_turf))
		return CLICK_ACTION_BLOCKING

	living_user.abstract_move(target_turf)// Poof!
	log_admin("[key_name(user)] teleported via subspace techsuit to [picked].")// Log this shit because like lol lmao
	message_admins("[ADMIN_LOOKUPFLW(user)] teleported via subspace techsuit to [picked].")// Also tell admemes. I forgor what the admin follow thing is.
	return CLICK_ACTION_SUCCESS// thanks for wasting all of the above resources :')

/obj/item/clothing/under/admin/subspace
	name = "subspace techsuit"
	desc = parent_type::desc + " The tailoring on this one accounts for damage it has not taken yet."
	icon_state = "sub-techsuit"
	worn_icon_state = "sub-techsuit"
	armor_type = /datum/armor/clothing_under/admin/badmin

//Admeme jackets. Oh so comfortable. And shiny
/obj/item/clothing/suit/admin
	name = "bluespace letterman"
	desc = "Hand-stitched by legendary tailors, these jackets are made specifically for each technician. Using the same advanced fabrics and techniques as the rest of their soft kit, the comfort of these coats is unrivaled."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "blue-jacket"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "blue-jacket"
	worn_icon_digi = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing_digi.dmi'
	inhand_icon_state = null
	body_parts_covered = CHEST|GROIN|LEGS|ARMS
	armor_type = /datum/armor/admin
	strip_delay = 3 SECONDS
	equip_delay_other = 4 SECONDS
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	var/hit_reflect_chance = 50

/obj/item/clothing/suit/admin/Initialize(mapload)
	. = ..()
	clothing_flags |= ADMIN_CLOTHING_FLAGS// set here rather than in the type def so the parent type's own clothing flags survive
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/clothing/suit/admin/IsReflect(def_zone)
	if (prob(hit_reflect_chance))
		return TRUE

/obj/item/clothing/suit/admin/subspace
	name = "subspace letterman"
	desc = parent_type::desc + " This one returns every shot fired at it to sender, without exception."
	icon_state = "sub-jacket"
	worn_icon_state = "sub-jacket"
	armor_type = /datum/armor/admin/badmin
	hit_reflect_chance = 100

// Worlds most comfortable gloves, great for tickling spacetime
/obj/item/clothing/gloves/tackler/admin
	name = "bluespace gauntlets"
	desc = "Extraordinarily lightweight and pleasantly comfortable gauntlets packed full of useful technology. You feel perfectly capable of defending yourself."
	siemens_coefficient = 0
	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_TEMP_PROTECT
	heat_protection = HANDS
	max_heat_protection_temperature = GLOVES_MAX_TEMP_PROTECT
	w_class = WEIGHT_CLASS_TINY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	clothing_traits = list()
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "blue-gauntlets"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	// Gloves carrying anything past bio/acid/fire armour must declare the arms too, same as the punch mitts.
	body_parts_covered = HANDS|ARMS
	armor_type = /datum/armor/admin

/obj/item/clothing/gloves/tackler/admin/Initialize(mapload)
	. = ..()
	clothing_flags |= ADMIN_CLOTHING_FLAGS// set here rather than in the type def so the parent type's own clothing flags survive
	AddComponent(/datum/component/martial_art_giver, /datum/martial_art/kaza_ruk)
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/clothing/gloves/tackler/admin/subspace
	name = "subspace gauntlets"
	desc = parent_type::desc + " You feel perfectly capable of defending yourself from things that have not happened."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "sub-gauntlets"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	armor_type = /datum/armor/admin/badmin

//Debug magbooties
//Spacewalking toggle

/obj/item/clothing/shoes/magboots/advance/admin//code\modules\clothing\shoes\magboots.dm
	name = "bluespace magboots"
	desc = "Exotic hand manufactured booties made of the finest alloys the Frontier has to offer. The bluespace crystals powering each boot gleam threateningly."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	base_icon_state = "blue-magboots"
	icon_state = "blue-magboots0"// My first icon, I am very sorry. This should probably be replaced, but watch it just stick around for a long time.
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_digi = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing_digi.dmi'
	slowdown_active = -0.25
	magpulse_fishing_modifier = 10
	fishing_modifier = 10
	w_class = WEIGHT_CLASS_TINY
	// Same rule for boots and the legs.
	body_parts_covered = FEET|LEGS
	armor_type = /datum/armor/admin
	var/admin_spacewalk = FALSE

/obj/item/clothing/shoes/magboots/advance/admin/item_ctrl_click(mob/user)
	if(!isliving(user))
		return CLICK_ACTION_BLOCKING
	if(!user.client?.holder)
		return NONE
	// Must be worn, not just held
	var/mob/living/wearer = user
	if(wearer.get_slot_by_item(src) != ITEM_SLOT_FEET)
		balloon_alert(user, "must be worn!")
		return CLICK_ACTION_BLOCKING

	admin_spacewalk = !admin_spacewalk
	if(admin_spacewalk)
		attach_clothing_traits(TRAIT_SPACEWALK)
		add_filter("admin_active_item", 1, outline_filter(1, "#cc00ff", OUTLINE_SQUARE))
	else
		detach_clothing_traits(TRAIT_SPACEWALK)
		remove_filter("admin_active_item")

	balloon_alert(user, "spacewalking [admin_spacewalk ? "enabled" : "disabled"]")
	return CLICK_ACTION_SUCCESS

/obj/item/clothing/shoes/magboots/advance/admin/dropped(mob/user)
	. = ..()
	if(admin_spacewalk)
		admin_spacewalk = FALSE
		// detach_clothing_traits is already called by the parent unequip logic,
		// but we reset our state variable here

/obj/item/clothing/shoes/magboots/advance/admin/examine(mob/user)
	. = ..()
	. += span_notice("Ctrl-Click while wearing to toggle spacewalking. Currently [admin_spacewalk ? "active" : "inactive"].")

/obj/item/clothing/shoes/magboots/advance/admin/Initialize(mapload)// Give them pockets, damnit
	. = ..()
	clothing_flags |= ADMIN_CLOTHING_FLAGS// set here rather than in the type def so the parent type's own clothing flags survive
	create_storage(storage_type = /datum/storage/admin/pockets)//big pockets,,,
	AddElement(/datum/element/ignites_matches)
	AddComponent(/datum/component/squeak, list('sound/effects/jingle.ogg'=1), 25, 50, 16)
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/clothing/shoes/magboots/advance/admin/subspace
	name = "subspace magboots"
	desc = parent_type::desc + " These ones gleam a good deal more threateningly."
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	base_icon_state = "sub-magboots"
	icon_state = "sub-magboots0"// My first icon, I am very sorry. This should probably be replaced, but watch it just stick around for a long time.
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	armor_type = /datum/armor/admin/badmin
