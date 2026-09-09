/obj/item/proc/get_gun_permit_iconstate()
	var/obj/item/card/id/id_card = GetID()

	if(!id_card)
		return null
	if(ACCESS_WEAPONS in id_card.GetAccess())
		return "hud_permit"
	return null
