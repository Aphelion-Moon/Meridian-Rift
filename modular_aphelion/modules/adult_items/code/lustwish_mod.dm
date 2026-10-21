/// The standard MOD suit in LustWish's skin.
/datum/mod_theme/standard/lustwish
	name = "lustwish"
	desc = "A specialty designed lustwish themed modsuit which is based entirely off of earlier civilian modsuits."
	default_skin = "lustwish"
	ui_theme = "ntos_darkmode"
	hardlight_theme = "royal_purple" // ROYAL_PURPLE, which is file-local to the hardlight colours
	cerulean_tail_palette = null // Cerulean tails take the suit's colour, not the standard greys
	cerulean_flipper_palette = FLIPPERS
	variants = list(
		"lustwish" = list(
			MOD_ICON_OVERRIDE = 'modular_aphelion/modules/adult_items/icons/lustwish_mod.dmi',
			MOD_WORN_ICON_OVERRIDE = 'modular_aphelion/modules/adult_items/icons/lustwish_mod_worn.dmi',
			MOD_DIGITIGRADE_ICON_OVERRIDE = 'modular_aphelion/modules/adult_items/icons/lustwish_mod_worn_mutant.dmi',
			MOD_SNOUT_ICON_OVERRIDE = 'modular_aphelion/modules/adult_items/icons/lustwish_mod_worn_mutant.dmi',
			/obj/item/clothing/head/mod = list(
				UNSEALED_LAYER = NECK_LAYER,
				UNSEALED_CLOTHING = SNUG_FIT,
				SEALED_CLOTHING = THICKMATERIAL|STOPSPRESSUREDAMAGE|HEADINTERNALS,
				SEALED_INVISIBILITY = HIDEFACIALHAIR|HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE|HIDEHAIR|HIDESNOUT,
				SEALED_COVER = HEADCOVERSMOUTH|HEADCOVERSEYES|PEPPERPROOF,
				UNSEALED_MESSAGE = "slides open",
				SEALED_MESSAGE = "slides closed",
			),
			/obj/item/clothing/suit/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				SEALED_INVISIBILITY = HIDEJUMPSUIT,
				UNSEALED_MESSAGE = "spontaneously loosens",
				SEALED_MESSAGE = "squeezes snugly around your body",
			),
			/obj/item/clothing/gloves/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				CAN_OVERSLOT = TRUE,
				UNSEALED_MESSAGE = "relaxes from your hand",
				SEALED_MESSAGE = "clenches between each finger",
			),
			/obj/item/clothing/shoes/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				CAN_OVERSLOT = TRUE,
				UNSEALED_MESSAGE = "gives room to your feet",
				SEALED_MESSAGE = "squeezes tightly around your ankles",
			),
		),
	)

/obj/item/mod/construction/plating/lustwish
	icon = 'modular_aphelion/modules/adult_items/icons/lustwish_mod.dmi'
	icon_state = "lustwish-plating"
	theme = /datum/mod_theme/standard/lustwish

/// LustWish's MOD modules.
/obj/item/mod/module/lustwish
	abstract_type = /obj/item/mod/module/lustwish
	icon = 'modular_aphelion/modules/adult_items/icons/lustwish_mod.dmi'
	overlay_icon_file = 'modular_aphelion/modules/adult_items/icons/lustwish_mod_worn.dmi'

/// Hypnotizes the wearer with its phrase like the hypnotic goggles: while on, or whenever the helmet is sealed once its
/// control wire is cut. Draws a spiral on the lustwish helmet.
/obj/item/mod/module/lustwish/hypno_visor
	name = "\improper MOD hypnotic visor module"
	desc = "A module inserted into the visor of a suit in which commands can be processed."
	icon_state = "module_hypno"
	module_type = MODULE_TOGGLE
	incompatible_modules = list(/obj/item/mod/module/lustwish/hypno_visor)
	required_slots = list(ITEM_SLOT_HEAD)
	/// The phrase it hypnotizes with.
	var/hypno_message = "Obey"
	/// Whether the lustwish helmet draws the spiral.
	var/visor_effect = TRUE

/obj/item/mod/module/lustwish/hypno_visor/examine(mob/user)
	. = ..()
	. += span_info("It's currently programmed with the following directive: \"[hypno_message]\" Use it in-hand to rewrite it.")
	. += span_info("Its visor will [visor_effect ? "" : "<b>not</b> "]display an external hypnotic effect. Use a screwdriver to toggle.")
	var/wire = module_type == MODULE_TOGGLE ? "<b>intact,</b> allowing for on-the-fly configuration via the MOD UI" \
		: "<b>snipped,</b> forcing the module to be always-on when the helmet is activated"
	. += span_info("Its control wire is currently [wire]. Use wirecutters to toggle.")

/obj/item/mod/module/lustwish/hypno_visor/attack_self(mob/user)
	. = ..()
	rewrite_phrase(user)

/obj/item/mod/module/lustwish/hypno_visor/screwdriver_act(mob/living/user, obj/item/tool)
	visor_effect = !visor_effect
	playsound(src, 'sound/machines/click.ogg', 30, TRUE)
	balloon_alert(user, "visor effect [visor_effect ? "on" : "off"]")
	return ITEM_INTERACT_SUCCESS

/obj/item/mod/module/lustwish/hypno_visor/wirecutter_act(mob/living/user, obj/item/tool)
	module_type = module_type == MODULE_TOGGLE ? MODULE_PASSIVE : MODULE_TOGGLE
	playsound(src, 'sound/items/tools/wirecutter.ogg', 30, TRUE)
	balloon_alert(user, "control wire [module_type == MODULE_TOGGLE ? "mended" : "snipped"]")
	return ITEM_INTERACT_SUCCESS

/obj/item/mod/module/lustwish/hypno_visor/on_part_activation()
	if(module_type == MODULE_PASSIVE)
		hypnotize()

/obj/item/mod/module/lustwish/hypno_visor/on_part_deactivation(deleting = FALSE)
	mod.wearer?.remove_status_effect(/datum/status_effect/hypnotic_phrase, src)

/obj/item/mod/module/lustwish/hypno_visor/on_activation(mob/activator)
	hypnotize()

/obj/item/mod/module/lustwish/hypno_visor/on_deactivation(mob/activator, display_message = TRUE, deleting = FALSE)
	mod.wearer?.remove_status_effect(/datum/status_effect/hypnotic_phrase, src)

/// Applies the hypnotic phrase. Fails if the wearer has the sex toy preference off.
/obj/item/mod/module/lustwish/hypno_visor/proc/hypnotize()
	if(!mod.wearer.apply_status_effect(/datum/status_effect/hypnotic_phrase, src, hypno_message))
		to_chat(mod.wearer, span_warning("Mind resilient to hypnotic effects."))

/obj/item/mod/module/lustwish/hypno_visor/get_current_overlay_state()
	if(visor_effect && istype(mod.theme, /datum/mod_theme/standard/lustwish) && (active || module_type == MODULE_PASSIVE))
		return "module_hypno_overlay"

/obj/item/mod/module/lustwish/hypno_visor/get_configuration(mob/user)
	. = ..()
	if(module_type != MODULE_TOGGLE)
		return
	.["hypno_message"] = add_ui_configuration("Hypnotic Message", "button", "list")
	if(istype(mod.theme, /datum/mod_theme/standard/lustwish))
		.["visor_effect"] = add_ui_configuration("Visor Effect", "bool", visor_effect)

/obj/item/mod/module/lustwish/hypno_visor/configure_edit(key, value, datum/tgui/ui)
	if(module_type != MODULE_TOGGLE) // A cut wire locks the settings.
		return
	switch(key)
		if("hypno_message")
			if(rewrite_phrase(usr, ui) && active)
				balloon_alert(usr, "restart to finalize changes")
		if("visor_effect")
			visor_effect = text2num(value)
			update_clothing_slots()

/// Asks `user` for a new phrase; a blank one resets it. Returns TRUE if they set it while still allowed to, through
/// `ui` or holding the module.
/obj/item/mod/module/lustwish/hypno_visor/proc/rewrite_phrase(mob/user, datum/tgui/ui)
	var/obj/item/mod/control/suit = mod
	var/new_phrase = tgui_input_text(user, "Change the hypnotic phrase.", "Hypnotic Phrase", hypno_message, MAX_MESSAGE_LEN)
	if(isnull(new_phrase) || mod != suit)
		return FALSE
	if(ui) // The window that asked must still allow it.
		if(QDELETED(ui))
			return FALSE
		ui.process_status() // The prompt slept, so refresh the status.
		var/obj/item/mod/remote/remote = ui.src_object
		if(ui.status != UI_INTERACTIVE || (istype(remote) && (remote.module?.mod != suit || !remote.toy_wearer() || !remote.takes_part(user))))
			return FALSE
	else if(!user.is_holding(src))
		return FALSE
	hypno_message = new_phrase || initial(hypno_message)
	return TRUE

/// Comes with its remote, which has to be taken out before installing. The remote then controls the suit.
/obj/item/mod/module/lustwish/remote_control
	name = "\improper MOD remote control module"
	desc = "A module, once inserted, will allow anyone with its linked remote to control the suit from nearby. \
		Its remote has to come out before it goes in."
	icon_state = "module_remote"
	incompatible_modules = list(/obj/item/mod/module/lustwish/remote_control)
	required_slots = list(ITEM_SLOT_OCLOTHING)
	overlay_state_inactive = "module_remote_overlay"
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1.5)

/obj/item/mod/module/lustwish/remote_control/Initialize(mapload)
	. = ..()
	create_storage(storage_type = /datum/storage/pockets/small, canhold = /obj/item/mod/remote)
	new /obj/item/mod/remote(src, src)

/obj/item/mod/module/lustwish/remote_control/attack_self(mob/user)
	. = ..()
	atom_storage.open_storage(user)

/obj/item/mod/module/lustwish/remote_control/can_install(obj/item/mod/control/mod)
	return !(locate(/obj/item/mod/remote) in src) && ..()

/// Controls its module's suit from within `control_range` tiles: activation, parts, modules, lock and forced emotes.
/// Needs the wearer's sex toy preference and the holder's ERP preference.
/obj/item/mod/remote
	name = "\improper MOD remote"
	desc = "A remote that allows control of a modsuit once its paired module is inserted."
	icon = 'modular_aphelion/modules/adult_items/icons/lustwish_mod.dmi'
	icon_state = "remote_item"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	/// The module whose suit this controls.
	var/obj/item/mod/module/lustwish/remote_control/module
	/// How many tiles away, on the same z-level, the wearer can be controlled from.
	var/control_range = 7

/obj/item/mod/remote/Initialize(mapload, obj/item/mod/module/lustwish/remote_control/module)
	. = ..()
	if(!module)
		return
	src.module = module
	RegisterSignal(module, COMSIG_QDELETING, PROC_REF(on_module_deleted))

/obj/item/mod/remote/Destroy(force)
	module = null
	return ..()

/// Drops the module when it's deleted.
/obj/item/mod/remote/proc/on_module_deleted(datum/source)
	SIGNAL_HANDLER
	module = null

/obj/item/mod/remote/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MODsuitRemote")
		ui.open()

/obj/item/mod/remote/ui_status(mob/user, datum/ui_state/state)
	return in_reach(user) ? ..() : min(..(), UI_UPDATE) // Out of reach, the window stays open but can't act.

/obj/item/mod/remote/ui_data(mob/user)
	var/obj/item/mod/control/mod = module?.mod
	if(!toy_wearer() || !takes_part(user))
		return list("refusal" = !mod ? "Not Installed" : !mod.wearer ? "MODsuit Not Worn" : "Control Refused")
	if(!in_reach(user))
		return list("refusal" = "Out of Range")
	// Static data too, since the module can be installed while the window is open.
	var/list/data = mod.ui_data(user) + mod.ui_static_data(user)
	data["refusal"] = null
	return data

/obj/item/mod/remote/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !toy_wearer() || !takes_part(ui.user))
		return
	switch(action)
		if("emote")
			force_emote(ui.user, params["emote"])
		if("activate", "deploy", "select", "configure", "lock")
			return module.mod.ui_act(action, params, ui, state)
		if("call", "eject_pai", "pin") // Wearer only.
			balloon_alert(ui.user, "not from a remote!")

/// Returns the suit's wearer if they have the sex toy preference on.
/obj/item/mod/remote/proc/toy_wearer()
	var/mob/living/carbon/human/wearer = module?.mod?.wearer
	if(!wearer)
		return null
	var/datum/client_interface/player = GET_CLIENT(wearer)
	return player?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy) ? wearer : null

/// Whether `holder` has the ERP preference on.
/obj/item/mod/remote/proc/takes_part(mob/holder)
	var/datum/client_interface/player = GET_CLIENT(holder)
	return player?.prefs?.read_preference(/datum/preference/toggle/erp)

/// Whether `user` is within `control_range` of the wearer, or nobody wears the suit.
/obj/item/mod/remote/proc/in_reach(mob/user)
	return !module?.mod?.wearer || IN_GIVEN_RANGE(user, module.mod.wearer, control_range)

/// Makes the wearer emote `message` for `user`. `user`'s mutes, emote ban and the IC filters apply, as for the me verb.
/obj/item/mod/remote/proc/force_emote(mob/user, message)
	var/mob/living/carbon/human/wearer = toy_wearer()
	if(!wearer || !takes_part(user) || !istext(message))
		return FALSE
	if(GLOB.say_disabled)
		to_chat(user, span_danger("Speech is currently admin-disabled."))
		return FALSE
	if(!isnull(user.ckey) && is_banned_from(user.ckey, "Emote"))
		to_chat(user, span_boldwarning("You cannot send custom emotes (banned)."))
		return FALSE
	var/datum/client_interface/player = GET_CLIENT(user)
	if(player?.prefs?.muted & MUTE_IC)
		to_chat(user, span_boldwarning("You cannot send IC messages (muted)."))
		return FALSE
	message = trim(copytext_char(sanitize(message), 1, MAX_MESSAGE_LEN))
	if(!message)
		return FALSE
	// Filtered here, soft filters and admins included: the emote's own check would ask the wearer, not `user`.
	var/list/filter_result = is_ic_filtered(message) || is_soft_ic_filtered(message)
	if(filter_result)
		REPORT_CHAT_FILTER_TO_USER(user, filter_result)
		log_filter("IC Emote", message, filter_result)
		return FALSE
	user.log_message("made [key_name(wearer)] emote with [src]: [message]", LOG_EMOTE)
	return wearer.emote("me", NONE, message, TRUE)
