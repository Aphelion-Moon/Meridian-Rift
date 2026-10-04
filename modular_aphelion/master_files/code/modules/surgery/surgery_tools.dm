/obj/item/retractor
	worn_icon = null

/obj/item/hemostat
	worn_icon = null

/obj/item/cautery
	worn_icon = null

/obj/item/scalpel
	worn_icon = null

/obj/item/surgical_drapes
	worn_icon = null

/obj/item/shears/attack(mob/living/amputee, mob/living/user)
	if(iscarbon(amputee) && !user.combat_mode && user.zone_selected == BODY_ZONE_PRECISE_GROIN)
		var/mob/living/carbon/patient = amputee
		var/obj/item/organ/tail = patient.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
		if(tail?.organ_flags & ORGAN_UNREMOVABLE)
			to_chat(user, span_warning("[patient]'s [tail.name] is part of [patient.p_their()] body. You can't cut it off!"))
			return
	return ..()
