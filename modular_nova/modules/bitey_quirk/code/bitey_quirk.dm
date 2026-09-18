/*
 * Bitey quirk - gives you cat fangs, resulting in bonus bite damage, 50% chance of unarmed attacks being bites,
 * and the ability to make every attack a bite
 */
/datum/quirk/bitey
	name = "Bitey"
	desc = "You can toggle whether you bite instead of doing unarmed attacks. This ability is independent of other feline traits."
	gain_text = span_notice("You feel like you could bite someone if you wanted to.")
	lose_text = span_notice("You no longer feel the urge to bite.")
	medical_record_text = "Patient has a tendency to bite when agitated."
	value = 0
	icon = FA_ICON_TOOTH

/datum/quirk/bitey/add_to_holder(mob/living/new_holder, quirk_transfer = FALSE, client/client_source, unique = TRUE, announce = TRUE)
	if(!new_holder)
		return FALSE
	var/mob/living/carbon/human/human_holder = new_holder
	if(!ishuman(human_holder))
		return FALSE

	// Avoid giving this quirk to someone who already has built-in feline biting.
	if(istype(human_holder.get_organ_slot(ORGAN_SLOT_TONGUE), /obj/item/organ/tongue/cat) || isfelinid(human_holder))
		return FALSE

	return ..()

/*
 * Called when the quirk is first added to a mob.
 * Checks if the holder already has a cat tongue and removes the quirk if so.
 */
/datum/quirk/bitey/add_unique(client/client_source)
	var/mob/living/carbon/human/human_holder = quirk_holder
	if(!ishuman(human_holder))
		return

	var/obj/item/organ/fangs/cat/fangs = new
	fangs.Insert(human_holder, special = TRUE, movement_flags = DELETE_IF_REPLACED)

/datum/quirk/bitey/remove()
	if(isfelinid(quirk_holder))
		return // They should have cat fangs anyways
	qdel(quirk_holder.get_organ_slot(ORGAN_SLOT_FANGS))
