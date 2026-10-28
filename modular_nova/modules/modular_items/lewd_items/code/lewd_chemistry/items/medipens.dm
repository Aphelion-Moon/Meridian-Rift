/// Single-use 30u aphrodisiac medipens.
/obj/item/reagent_containers/hypospray/medipen/lewd
	abstract_type = /obj/item/reagent_containers/hypospray/medipen/lewd
	icon = 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_items/medipens.dmi'
	lefthand_file = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_inhands/medipens_lefthand.dmi'
	righthand_file = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_inhands/medipens_righthand.dmi'
	volume = 30
	amount_per_transfer_from_this = 30
	custom_price = null // LustWish's default prices, like the lewd bottles
	custom_premium_price = null
	obj_flags_nova = ERP_ITEM

/obj/item/reagent_containers/hypospray/medipen/lewd/crocin
	name = "emergency aphrodisiac shot"
	desc = "A medipen made to treat people suffering from low libido, a terrible sickness no one should endure."
	icon_state = "crocinpen"
	inhand_icon_state = "crocinpen"
	base_icon_state = "crocinpen"
	list_reagents = list(/datum/reagent/drug/aphrodisiac/crocin = 30)

/// A crocin pen subtype to share its inhand sprite.
/obj/item/reagent_containers/hypospray/medipen/lewd/crocin/hexacrocin
	name = "shot of concentrated lust"
	desc = "Use this when a case of low libido can't be cured using conventional aphrodisiacs."
	icon_state = "hcrocinpen"
	base_icon_state = "hcrocinpen"
	list_reagents = list(/datum/reagent/drug/aphrodisiac/crocin/hexacrocin = 30)

/obj/item/reagent_containers/hypospray/medipen/lewd/succubus_milk
	name = "succubus milk autoinjector"
	desc = "A medipen used to create stable sources of milk in little time. Side effects <b>will</b> include mammary swelling."
	icon_state = "succupen"
	inhand_icon_state = "succupen"
	base_icon_state = "succupen"
	list_reagents = list(/datum/reagent/drug/aphrodisiac/succubus_milk = 30)

/obj/item/reagent_containers/hypospray/medipen/lewd/incubus_draft
	name = "incubus draft autoinjector"
	desc = "A medipen used to help with urgent cases of \"small cock\"."
	icon_state = "incupen"
	inhand_icon_state = "incupen"
	base_icon_state = "incupen"
	list_reagents = list(/datum/reagent/drug/aphrodisiac/incubus_draft = 30)

/obj/item/reagent_containers/hypospray/medipen/lewd/coom_bomb
	name = "La Coom Bomb"
	desc = "Someone forgot what reagent was supposed to go in this one, so they just mixed all the funny ones into its case... Oh my..."
	icon_state = "bombpen"
	inhand_icon_state = "bombpen"
	base_icon_state = "bombpen"
	list_reagents = list(
		/datum/reagent/drug/aphrodisiac/crocin/hexacrocin = 10,
		/datum/reagent/drug/aphrodisiac/succubus_milk = 10,
		/datum/reagent/drug/aphrodisiac/incubus_draft = 10,
	)

/obj/item/storage/box/medipens/lewd
	name = "lewd medipen box"
	desc = "A box full of medipens meant to cause interesting effects on people. None of them has anything close to a medical use."
	icon = 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_items/medipens.dmi'
	icon_state = "medbox_lewd"
	illustration = null

/obj/item/storage/box/medipens/lewd/PopulateContents()
	new /obj/item/reagent_containers/hypospray/medipen/lewd/crocin(src)
	new /obj/item/reagent_containers/hypospray/medipen/lewd/crocin/hexacrocin(src)
	new /obj/item/reagent_containers/hypospray/medipen/lewd/succubus_milk(src)
	new /obj/item/reagent_containers/hypospray/medipen/lewd/incubus_draft(src)
	new /obj/item/reagent_containers/hypospray/medipen/lewd/coom_bomb(src)
