/obj/item/storage/box/erp/portal_fleshlight
	name = "Portal Device and Underwear"
	desc = "A small silver box with LustWish Co embossed."
	icon = 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_items/portal.dmi'
	icon_state = "box"
	illustration = null
	custom_price = 15
	storage_type = /datum/storage/box/erp/portal_fleshlight

/datum/storage/box/erp/portal_fleshlight
	max_specific_storage = WEIGHT_CLASS_SMALL
	max_total_storage = 10
	max_slots = 3

/obj/item/storage/box/erp/portal_fleshlight/PopulateContents()
	new /obj/item/clothing/sextoy/portal_fleshlight(src)
	new /obj/item/clothing/sextoy/portal_panties(src)
	new /obj/item/paper/fluff/portal_fleshlight(src)

/obj/item/paper/fluff/portal_fleshlight
	name = "Portal Device Instructions"
	default_raw_text = {"Thank you for purchasing the Lustwish Portal Fleshlight / Dildo!<br>\
	To use, link the portal device with the provided receiver by using either item on the other. Equip the receiver in a specific genital slot through the interaction panel, or as a mask to connect to the mouth.<br>\
	Activate the portal device in hand to cycle the target used when selecting the groin. Other selected body zones choose their corresponding endpoint.<br>\
	Both the fleshlight and underwear can be toggled to anonymous mode by right-clicking them.<br>\
	Have fun lovers,<br>\
	<br>\
	LustWish Corporation."}
