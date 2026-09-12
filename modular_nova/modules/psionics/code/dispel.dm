/**
 * Forcibly ends the psionic effects riding on this atom.
 *
 * Deliberately separate from tg antimagic: psionics are not spells, so nullrods and
 * `can_block_magic()` have no bearing here. Only psionic sources dispel.
 * Returns TRUE if anything was actually ended.
 * Arguments:
 * * dispeller - The atom responsible, for feedback and attribution.
 */
/atom/proc/psionic_dispel(atom/dispeller)
	var/dispelled = !!(SEND_SIGNAL(src, COMSIG_ATOM_PSIONIC_DISPEL, dispeller) & COMPONENT_PSIONIC_DISPELLED)
	if(dispelled)
		playsound(src, 'sound/effects/magic/magic_block_mind.ogg', 40, TRUE)
	return dispelled

/// As above, plus every effect the psion is currently holding up themselves.
/mob/living/psionic_dispel(atom/dispeller)
	var/dispelled = ..()

	var/maintained_dispelled = FALSE
	var/datum/component/psionic_profile/profile = get_psionic_profile()
	for(var/action_type in profile?.granted_actions)
		var/datum/action/cooldown/psionic/psionic_action = profile.granted_actions[action_type]
		if(psionic_action?.is_maintaining() && psionic_action.stop_maintaining(src))
			maintained_dispelled = TRUE

	// The parent only makes noise for signal handlers, so cover the case where the maintained
	// teardown was the only thing that actually did anything.
	if(maintained_dispelled && !dispelled)
		playsound(src, 'sound/effects/magic/magic_block_mind.ogg', 40, TRUE)

	dispelled ||= maintained_dispelled
	if(dispelled)
		to_chat(src, span_warning("Something wrenches your psionic focus apart."))
	return dispelled

/// Attach to a manifestation that outlives the cast which spawned it, so a dispel can unmake it.
/// Effects torn down by their action's stop_maintaining() do not need this.
/datum/element/psionic_dispellable

/datum/element/psionic_dispellable/Attach(datum/target)
	. = ..()
	if(!isatom(target))
		return ELEMENT_INCOMPATIBLE

	RegisterSignal(target, COMSIG_ATOM_PSIONIC_DISPEL, PROC_REF(on_dispelled))

/datum/element/psionic_dispellable/Detach(datum/target)
	UnregisterSignal(target, COMSIG_ATOM_PSIONIC_DISPEL)
	return ..()

/datum/element/psionic_dispellable/proc/on_dispelled(atom/source, atom/dispeller)
	SIGNAL_HANDLER

	source.visible_message(span_warning("[source] unravels into nothing!"))
	qdel(source)
	return COMPONENT_PSIONIC_DISPELLED

/// Status effect base that ends itself when its owner is dispelled. Set as a `parent_type`
/// so dispellable psionic status effects keep their own type path.
/datum/status_effect/psionic_dispellable
	id = STATUS_EFFECT_ID_ABSTRACT

/datum/status_effect/psionic_dispellable/on_apply()
	. = ..()
	if(!.)
		return

	RegisterSignal(owner, COMSIG_ATOM_PSIONIC_DISPEL, PROC_REF(on_dispelled))

/datum/status_effect/psionic_dispellable/on_remove()
	UnregisterSignal(owner, COMSIG_ATOM_PSIONIC_DISPEL)
	return ..()

/datum/status_effect/psionic_dispellable/proc/on_dispelled(atom/source, atom/dispeller)
	SIGNAL_HANDLER

	qdel(src)
	return COMPONENT_PSIONIC_DISPELLED
