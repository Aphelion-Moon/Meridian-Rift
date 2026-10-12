/obj/item/clothing/glasses/hypno
	name = "hypnotic goggles"
	desc = "An all-in-one mnemonic impression repeater and vision tinter, used to entrance the wearer with a programmed phrase. Foam inserts, to boot."
	worn_icon = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_eyes.dmi'
	greyscale_colors = "#383840#dc7ef4"
	icon = 'icons/map_icons/clothing/_clothing.dmi'
	icon_state = "/obj/item/clothing/glasses/hypno"
	post_init_icon_state = "hypnogoggles"
	greyscale_config = /datum/greyscale_config/hypnogoggles
	greyscale_config_worn = /datum/greyscale_config/hypnogoggles/worn
	flags_1 = IS_PLAYER_COLORABLE_1
	obj_flags_nova = ERP_ITEM
	/// The hypnotic codephrase. Default always required otherwise things break.
	var/codephrase = "Obey."

/obj/item/clothing/glasses/hypno/Initialize(mapload)
	. = ..()
	if(check_holidays(APRIL_FOOLS))
		codephrase = "Become... video deliveryman!"

/obj/item/clothing/glasses/hypno/attack_self(mob/user)
	. = ..()
	var/new_codephrase = tgui_input_text(user, "Change The Hypnotic Phrase.", max_length = MAX_MESSAGE_LEN)
	if(!isnull(new_codephrase))
		codephrase = new_codephrase

/obj/item/clothing/glasses/hypno/equipped(mob/living/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_EYES))
		return
	if(!codephrase)
		codephrase = initial(codephrase) // DIE
	user.apply_status_effect(/datum/status_effect/hypnotic_phrase, src, codephrase)

/obj/item/clothing/glasses/hypno/dropped(mob/living/user)
	. = ..()
	user?.remove_status_effect(/datum/status_effect/hypnotic_phrase, src) // a microwave ejects them with no mob

/// A hypnotic device's phrase echoing in its wearer's head, for players who take sex toys - the hypnotic goggles' and
/// the MOD hypnotic visor's. It mimics the brain trauma - yes, brain trauma - these goggles used to give.
/datum/status_effect/hypnotic_phrase
	id = "hypnotic_phrase"
	status_type = STATUS_EFFECT_MULTIPLE // one for each device
	alert_type = null // the hypnosis alert is thrown for 30 seconds instead
	processing_speed = STATUS_EFFECT_NORMAL_PROCESS
	tick_interval = 2 SECONDS
	/// The device putting the phrase there - the effect ends when it is deleted.
	var/obj/item/source
	/// The phrase.
	var/phrase

/datum/status_effect/hypnotic_phrase/on_apply(obj/item/source, phrase)
	var/datum/client_interface/player = GET_CLIENT(owner)
	if(!iscarbon(owner) || !player?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy))
		return FALSE
	src.source = source
	src.phrase = phrase
	RegisterSignal(source, COMSIG_QDELETING, PROC_REF(on_source_deleted))
	log_game("[key_name(owner)] was hypnotized by [source] with the phrase '[phrase]'.")
	to_chat(owner, span_reallybig(span_hypnophrase(phrase)))
	to_chat(owner, span_notice(pick("You feel your thoughts focusing on this phrase... you can't seem to get it out of your head.",
									"Your head hurts, but this is all you can think of. It must be vitally important.",
									"You feel a part of your mind repeating this over and over. You need to follow these words.",
									"Something about this sounds... right, for some reason. You feel like you should follow these words.",
									"These words keep echoing in your mind. You find yourself completely fascinated by them.")))
	var/atom/movable/screen/alert/hypnosis/hypno_alert = owner.throw_alert(ALERT_HYPNOSIS, /atom/movable/screen/alert/hypnosis, timeout_override = 30 SECONDS)
	hypno_alert.desc = "\"[phrase]\"... your mind seems to be fixated on this concept."
	return TRUE

/datum/status_effect/hypnotic_phrase/before_remove(obj/item/removing_source)
	return removing_source == source

/datum/status_effect/hypnotic_phrase/on_remove()
	if(isnull(source)) // refused by on_apply(), which said nothing
		return
	log_game("[key_name(owner)] is no longer hypnotized by [source].")
	to_chat(owner, span_userdanger("You suddenly snap out of your hypnosis. The phrase '[phrase]' no longer feels important to you."))

/datum/status_effect/hypnotic_phrase/Destroy()
	. = ..() // on_remove() reads the source
	source = null

/datum/status_effect/hypnotic_phrase/tick(seconds_between_ticks)
	if(!ishuman(owner) || !SPT_PROB(1, seconds_between_ticks))
		return
	var/datum/client_interface/player = GET_CLIENT(owner)
	if(!player?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy)) // something is really fucked if they're wearing this at this point anyways
		return
	if(prob(50))
		to_chat(owner, span_hypnophrase("<i>...[LOWER_TEXT(phrase)]...</i>"))
	else
		owner.cause_hallucination(/datum/hallucination/chat, "[source]", force_radio = TRUE, specific_message = span_hypnophrase("[phrase]"))

/// The device is gone, and its phrase with it.
/datum/status_effect/hypnotic_phrase/proc/on_source_deleted(datum/deleted)
	SIGNAL_HANDLER
	qdel(src)
