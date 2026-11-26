/datum/quirk/system_shock
	name = "System Shock"
	desc = "You and electricity have a volatile relationship. One spark's liable to forcefully reboot your systems. Note: This quirk only works on synths."
	gain_text = span_danger("You start feeling nervous around plug sockets.")
	lose_text = span_notice("You feel normal about sparks.")
	medical_record_text = "Patient's processors are unusually uninsulated."
	value = -8
	mob_trait = TRAIT_SYSTEM_SHOCK
	icon = FA_ICON_PLUG_CIRCLE_XMARK
	quirk_flags = QUIRK_HUMAN_ONLY
	// So we don't have silicons being stunlocked forever.
	COOLDOWN_DECLARE(system_shock_cooldown)

/datum/quirk/system_shock/add(client/client_source)
	if(issynthetic(quirk_holder))
		RegisterSignal(quirk_holder, COMSIG_LIVING_ELECTROCUTE_ACT, PROC_REF(on_electrocute))
		RegisterSignal(quirk_holder, COMSIG_LIVING_MINOR_SHOCK, PROC_REF(try_system_shock))

/datum/quirk/system_shock/remove()
	UnregisterSignal(quirk_holder, list(COMSIG_LIVING_ELECTROCUTE_ACT, COMSIG_LIVING_MINOR_SHOCK))

/datum/quirk/system_shock/is_species_appropriate(datum/species/mob_species)
	if (!ispath(mob_species, /datum/species/synthetic))
		return FALSE
	return ..()

/**
 * Reboots us on a shock that electrocute_act() lets through.
 *
 * The signal is sent before electrocute_act() checks anything, so we repeat its checks here. We don't reboot if
 * our insulated gloves stop the shock, if we're immune to it, or if it's too weak to hurt us. You should keep
 * these checks in step with electrocute_act().
 */
/datum/quirk/system_shock/proc/on_electrocute(mob/living/source, shock_damage, shock_source, siemens_coeff = 1, flags = NONE)
	SIGNAL_HANDLER

	if((flags & SHOCK_TESLA) && HAS_TRAIT(source, TRAIT_TESLA_SHOCKIMMUNE))
		return
	if(!(flags & SHOCK_IGNORE_IMMUNITY) && HAS_TRAIT(source, TRAIT_SHOCKIMMUNE))
		return
	if(shock_damage * siemens_coeff * GET_PHYSIOLOGY(source, PHYS_COEFF_ELEC_CONDUCTIVITY) < 1)
		return
	try_system_shock()

/// Reboots us unless we're on cooldown. Batons, tasers and other minor shocks come straight here
/datum/quirk/system_shock/proc/try_system_shock()
	SIGNAL_HANDLER

	if(COOLDOWN_FINISHED(src, system_shock_cooldown))
		do_system_shock()

/// Apply our visual effect and knock the silicon out
/datum/quirk/system_shock/proc/do_system_shock()
	var/knockout_length = rand(8 SECONDS, 10 SECONDS)
	quirk_holder.set_static_vision(knockout_length)
	quirk_holder.balloon_alert(quirk_holder, "system rebooting")
	to_chat(quirk_holder, span_danger("POWER INSTABILITY: SYSTEM RECALIBRATING."))
	addtimer(CALLBACK(src, PROC_REF(knock_out), knockout_length - 0.4 SECONDS), 2 SECONDS)
	//The intent with the 0.4 seconds is so that the visual static effect lasts longer than the actual knockout/sleeping effect.
	COOLDOWN_START(src, system_shock_cooldown, knockout_length + 5 SECONDS)

/datum/quirk/system_shock/proc/knock_out(length)
	quirk_holder.Sleeping(length)
