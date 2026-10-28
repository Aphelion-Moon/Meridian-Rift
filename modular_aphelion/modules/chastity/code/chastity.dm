/// Sends optional server-owned flavour text. A checkout without private config sends no message.
/proc/chastity_flavour(mob/recipient, key)
	var/directory = "[global.config.directory]/nova"
	if(!fexists("[directory]/chastity.json"))
		return FALSE
	to_chat(recipient, span_purple(pick(strings("chastity.json", key, directory))))
	return TRUE

/**
 * A lockable device worn in a lewd slot that closes genitals off: a chastity cage, belt or plate.
 *
 * It draws in place of the genital it sits over (see `device_state` on the genital's bodypart overlay), so clothing,
 * underwear and the genital's own visibility settings hide it exactly as they hide the genital. Genitals it closes
 * off refuse interactions and other toys until it comes off, and it only comes off unlocked: with the key that
 * comes tucked inside it, or with its lock picked. Fitting one needs the wearer's chastity preference.
 */
/obj/item/clothing/sextoy/chastity
	name = "chastity cage"
	desc = "A small steel cage that keeps a cock from getting hard. It locks with the key tucked inside it."
	icon = 'modular_aphelion/modules/chastity/icons/chastity.dmi'
	icon_state = "cage_standard"
	// Drawn in the genital's place rather than through the lewd slot, so the slot gets nothing to draw.
	worn_icon = 'icons/effects/effects.dmi'
	worn_icon_state = "nothing"
	w_class = WEIGHT_CLASS_SMALL
	lewd_slot_flags = LEWD_SLOT_PENIS
	/// The sheet its worn shapes come from.
	var/worn_sheet = 'modular_aphelion/modules/chastity/icons/chastity_worn.dmi'
	/// Its worn shape in that sheet, drawn as "[worn_shape]_m" or "_f" by body.
	var/worn_shape = "cage_standard"
	/// CHASTITY_* genitals it closes off.
	var/closes = CHASTITY_PENIS
	/// CHASTITY_* genitals hidden under it besides the one it's drawn over.
	var/covers = NONE
	/// CHASTITY_* genitals the wearer must have for it to fit.
	var/needs = CHASTITY_PENIS
	/// Whether it's locked shut.
	var/locked = FALSE
	/// A picked lock never catches again.
	var/broken_lock = FALSE
	/// The key that comes tucked inside it, or null for one that has no keyhole.
	var/key_path = /obj/item/key/chastity
	/// The tool that can pick its lock.
	var/pick_tool = TOOL_SCREWDRIVER
	/// Status lights that glow while it's locked, from "[state]_e" emissive states.
	var/status_lights = FALSE
	/// The genital slot it's drawn over while worn.
	var/drawn_over
	/// Whoever has it on.
	var/datum/weakref/wearer_ref
	COOLDOWN_DECLARE(flavour_cooldown)
	COOLDOWN_DECLARE(receive_cooldown)
	/// Genital slots by the CHASTITY_* flag that names them.
	var/static/list/genital_flags = list(
		ORGAN_SLOT_PENIS = CHASTITY_PENIS,
		ORGAN_SLOT_TESTICLES = CHASTITY_TESTICLES,
		ORGAN_SLOT_VAGINA = CHASTITY_VAGINA,
		ORGAN_SLOT_ANUS = CHASTITY_ANUS,
	)

/obj/item/clothing/sextoy/chastity/Initialize(mapload)
	. = ..()
	if(!key_path)
		return
	var/obj/item/key/chastity/key = new key_path(src)
	key.key_id = REF(src)
	key.name = "[key.name] ([name])"

/obj/item/clothing/sextoy/chastity/Destroy()
	unfit()
	return ..()

/obj/item/clothing/sextoy/chastity/update_overlays()
	. = ..()
	if(status_lights && locked)
		. += emissive_appearance(icon, "[icon_state]_e", src, alpha = src.alpha)

/obj/item/clothing/sextoy/chastity/examine(mob/user)
	. = ..()
	. += span_notice("It's [locked ? "locked" : "unlocked"][broken_lock ? ", and its lock is broken" : ""].")
	if(locate(/obj/item/key/chastity) in src)
		. += span_notice("Its key is tucked inside. Use it in hand to slide the key out.")

/obj/item/clothing/sextoy/chastity/attack_self(mob/user)
	var/obj/item/key/chastity/key = locate() in src
	if(!key)
		return ..()
	user.put_in_hands(key)
	to_chat(user, span_notice("You slide the key out of [src]."))
	return TRUE

/// The CHASTITY_* genitals `human` has.
/obj/item/clothing/sextoy/chastity/proc/genitals_of(mob/living/carbon/human/human)
	. = NONE
	for(var/genital_slot, flag in genital_flags)
		if(human.get_organ_slot(genital_slot))
			. |= flag

/// The genital it's drawn over on `human`: a penis it closes off, else a vagina.
/obj/item/clothing/sextoy/chastity/proc/draw_slot_for(mob/living/carbon/human/human)
	if((closes & CHASTITY_PENIS) && human.get_organ_slot(ORGAN_SLOT_PENIS))
		return ORGAN_SLOT_PENIS
	if((closes & CHASTITY_VAGINA) && human.get_organ_slot(ORGAN_SLOT_VAGINA))
		return ORGAN_SLOT_VAGINA
	return null

/// Its worn shape on `human`.
/obj/item/clothing/sextoy/chastity/proc/get_worn_shape(mob/living/carbon/human/human)
	return worn_shape

/obj/item/clothing/sextoy/chastity/can_lewd_attach(mob/living/carbon/human/target, mob/living/carbon/human/user, slot)
	var/datum/client_interface/target_client = GET_CLIENT(target)
	if(!target_client?.prefs?.read_preference(/datum/preference/toggle/erp/chastity))
		to_chat(user, span_warning("[target] doesn't want to wear chastity devices."))
		return FALSE
	if(locked)
		to_chat(user, span_warning("[src] is locked shut."))
		return FALSE
	var/has = genitals_of(target)
	if((has & needs) != needs || !(has & closes))
		to_chat(user, span_warning("[src] won't fit [target]."))
		return FALSE
	for(var/genital_slot, flag in genital_flags)
		if(!(closes & flag))
			continue
		var/obj/item/organ/genital/genital = target.get_organ_slot(genital_slot)
		var/obj/item/occupant = target.get_lewd_slot_item(genital_slot) || genital?.blocked_by
		if(occupant)
			to_chat(user, span_warning("[target] already has [occupant] on."))
			return FALSE
	return TRUE

/obj/item/clothing/sextoy/chastity/can_lewd_remove(mob/living/carbon/human/user)
	if(!locked)
		return TRUE
	to_chat(user, span_warning("[src] is locked shut."))
	if(user == wearer_ref?.resolve())
		chastity_flavour(user, key_path ? "lock_denial" : "cursed_lock")
	return FALSE

/obj/item/clothing/sextoy/chastity/lewd_equipped(mob/living/carbon/human/user, slot, initial)
	. = ..()
	fit(user)

/obj/item/clothing/sextoy/chastity/dropped(mob/user, silent)
	unfit()
	return ..()

/// Closes the wearer's genitals off and draws the device in place of the one it sits over.
/obj/item/clothing/sextoy/chastity/proc/fit(mob/living/carbon/human/wearer)
	wearer_ref = WEAKREF(wearer)
	refresh_organs(wearer)
	RegisterSignal(wearer, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(on_organ_lost))
	RegisterSignal(wearer, COMSIG_CARBON_GAIN_ORGAN, PROC_REF(on_organ_gained))
	RegisterSignal(wearer, COMSIG_ATOM_TOOL_ACT(pick_tool), PROC_REF(on_pick_tool))
	RegisterSignal(wearer, COMSIG_HUMAN_LEWD_INTERACTION_RECEIVED, PROC_REF(on_lewd_received))
	START_PROCESSING(SSobj, src)
	wearer.update_body_parts()

/// Reconciles the device's organ state without repeating fitting effects or signal registration.
/obj/item/clothing/sextoy/chastity/proc/refresh_organs(mob/living/carbon/human/wearer)
	for(var/genital_slot, flag in genital_flags)
		release(wearer.get_organ_slot(genital_slot), genital_slot == drawn_over, covers & flag)
	drawn_over = draw_slot_for(wearer)
	for(var/genital_slot, flag in genital_flags)
		var/obj/item/organ/genital/genital = wearer.get_organ_slot(genital_slot)
		if(!genital)
			continue
		if(closes & flag)
			genital.blocked_by = src
		var/datum/bodypart_overlay/mutant/genital/overlay = genital.bodypart_overlay
		if(!overlay)
			continue
		if(genital_slot == drawn_over)
			overlay.device_icon = worn_sheet
			overlay.device_state = get_worn_shape(wearer)
			overlay.device_glows = status_lights && locked
		else if(covers & flag)
			overlay.hidden_by_device = TRUE

/// Lets the wearer's genitals go again. Safe to call when it isn't worn.
/obj/item/clothing/sextoy/chastity/proc/unfit()
	var/mob/living/carbon/human/wearer = wearer_ref?.resolve()
	var/drawn_slot = drawn_over
	wearer_ref = null
	drawn_over = null
	STOP_PROCESSING(SSobj, src)
	if(!wearer)
		return
	UnregisterSignal(wearer, list(COMSIG_CARBON_LOSE_ORGAN, COMSIG_CARBON_GAIN_ORGAN, COMSIG_ATOM_TOOL_ACT(pick_tool), COMSIG_HUMAN_LEWD_INTERACTION_RECEIVED))
	for(var/genital_slot, flag in genital_flags)
		release(wearer.get_organ_slot(genital_slot), genital_slot == drawn_slot, covers & flag)
	wearer.update_body_parts()

/// Clears what the device set on one genital: its block, the device drawn over it, or its cover.
/obj/item/clothing/sextoy/chastity/proc/release(obj/item/organ/genital/genital, drawn, covered)
	if(!genital)
		return
	if(genital.blocked_by == src)
		genital.blocked_by = null
	var/datum/bodypart_overlay/mutant/genital/overlay = genital.bodypart_overlay
	if(!overlay)
		return
	if(drawn)
		overlay.device_icon = null
		overlay.device_state = null
		overlay.device_glows = FALSE
	else if(covered)
		overlay.hidden_by_device = FALSE

/// A genital it holds came off the body (surgery, a lost limb), so the device drops off with nothing to hold.
/obj/item/clothing/sextoy/chastity/proc/on_organ_lost(mob/living/carbon/human/source, obj/item/organ/genital/lost, special)
	SIGNAL_HANDLER
	if(!istype(lost))
		return
	var/held = lost.blocked_by == src || lost.slot == drawn_over
	release(lost, lost.slot == drawn_over, covers & genital_flags[lost.slot])
	if(held)
		come_off(source)

/// Newly inserted organs acquire the worn device's restrictions and drawing state.
/obj/item/clothing/sextoy/chastity/proc/on_organ_gained(mob/living/carbon/human/source, obj/item/organ/genital/gained, special)
	SIGNAL_HANDLER
	if(istype(gained) && ((closes | covers) & genital_flags[gained.slot]))
		refresh_organs(source) // Insert() redraws the body once the organ is on its limb

/// Takes it off the wearer whether locked or not, and drops it at their feet.
/obj/item/clothing/sextoy/chastity/proc/come_off(mob/living/carbon/human/wearer)
	wearer.drop_lewd_slot_item(current_equipped_slot)
	wearer.update_inv_lewd()

/// Locks or unlocks it, from close by or through a remote. Returns FALSE if a broken lock won't catch.
/obj/item/clothing/sextoy/chastity/proc/set_locked(to_lock, mob/user, remote = FALSE)
	if(to_lock && broken_lock)
		to_chat(user, span_warning("The lock on [src] is broken and won't catch."))
		return FALSE
	locked = to_lock
	playsound(src, 'sound/machines/click.ogg', 25, TRUE, SILENCED_SOUND_EXTRARANGE)
	var/mob/living/carbon/human/wearer = wearer_ref?.resolve()
	if(user && user != wearer)
		to_chat(user, span_notice("You [locked ? "lock" : "unlock"] [wearer ? "[wearer]'s [name]" : src]."))
	if(wearer)
		chastity_flavour(wearer, "[remote ? "remote_" : ""][locked ? "lock" : "unlock"]")
	if(status_lights)
		update_appearance(UPDATE_OVERLAYS)
		var/obj/item/organ/genital/drawn_genital = wearer?.get_organ_slot(drawn_over)
		var/datum/bodypart_overlay/mutant/genital/overlay = drawn_genital?.bodypart_overlay
		if(overlay)
			overlay.device_glows = locked
			wearer.update_body_parts()
	return TRUE

/// Turns its key, on the wearer or in hand.
/obj/item/clothing/sextoy/chastity/proc/turn_key(mob/living/user)
	var/mob/living/carbon/human/wearer = wearer_ref?.resolve()
	if(wearer && wearer != user && !do_after(user, 2 SECONDS, wearer))
		return
	set_locked(!locked, user)

/obj/item/clothing/sextoy/chastity/proc/on_pick_tool(mob/living/carbon/human/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	// Someone prepped for surgery gets the surgery, not the lock.
	if(!locked || user.zone_selected != BODY_ZONE_PRECISE_GROIN || HAS_TRAIT(source, TRAIT_READY_TO_OPERATE))
		return NONE
	INVOKE_ASYNC(src, PROC_REF(pick_lock), user, source, tool)
	return ITEM_INTERACT_SUCCESS

/// Works the lock with a screwdriver (a multitool for smart locks), like a locked collar's. It breaks open a third of the time.
/obj/item/clothing/sextoy/chastity/proc/pick_lock(mob/living/user, mob/living/carbon/human/wearer, obj/item/tool)
	var/datum/client_interface/wearer_client = GET_CLIENT(wearer)
	if(!key_path || wearer_client?.prefs?.read_preference(/datum/preference/toggle/erp/chastity_key_only))
		to_chat(user, span_warning("The lock on [src] won't give to anything but its key."))
		return
	to_chat(user, span_warning("You work [tool] into the lock on [src]..."))
	if(!do_after(user, 5 SECONDS, wearer) || !locked || wearer_ref?.resolve() != wearer)
		return
	if(!prob(33))
		to_chat(user, span_warning("You can't quite get the lock to give."))
		return
	broken_lock = TRUE
	set_locked(FALSE, user)
	to_chat(user, span_notice("The lock on [src] pops open, and won't catch again."))

/obj/item/clothing/sextoy/chastity/process(seconds_per_tick)
	var/mob/living/carbon/human/wearer = wearer_ref?.resolve()
	if(!wearer || loc != wearer)
		return PROCESS_KILL
	if(wearer.arousal < AROUSAL_LOW || IS_UNCONSCIOUS_OR_CRIT(wearer))
		return
	if(COOLDOWN_FINISHED(src, flavour_cooldown))
		COOLDOWN_START(src, flavour_cooldown, rand(90, 180) SECONDS)
		chastity_flavour(wearer, arousal_line_key(wearer))

/// A partner did something lewd to the wearer; now and then, the wearer thinks about what the device keeps from them.
/obj/item/clothing/sextoy/chastity/proc/on_lewd_received(mob/living/carbon/human/source, mob/living/carbon/human/user, datum/interaction/interaction)
	SIGNAL_HANDLER
	if(!COOLDOWN_FINISHED(src, receive_cooldown))
		return
	COOLDOWN_START(src, receive_cooldown, rand(45, 90) SECONDS)
	var/held = closes & genitals_of(source)
	var/bank = "receive_vagina"
	if((held & (CHASTITY_PENIS|CHASTITY_VAGINA)) == (CHASTITY_PENIS|CHASTITY_VAGINA))
		bank = "receive_intersex"
	else if(held & CHASTITY_PENIS)
		bank = "receive_penis"
	chastity_flavour(source, bank)

/// Which arousal flavour bank fits the wearer and what the device holds.
/obj/item/clothing/sextoy/chastity/proc/arousal_line_key(mob/living/carbon/human/wearer)
	var/held = closes & genitals_of(wearer)
	if((held & (CHASTITY_PENIS|CHASTITY_VAGINA)) == (CHASTITY_PENIS|CHASTITY_VAGINA))
		return "arousal_intersex"
	if(!(held & CHASTITY_PENIS))
		return "arousal_vagina"
	if(wearer.arousal >= AROUSAL_HIGH && prob(50))
		return "arousal_edge"
	var/obj/item/organ/genital/penis/penis = wearer.get_organ_slot(ORGAN_SLOT_PENIS)
	if(penis?.genital_size >= 8 && prob(40))
		return "arousal_large"
	return "arousal_penis"
