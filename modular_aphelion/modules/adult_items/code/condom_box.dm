/obj/item/storage/box/condoms
	name = "surplus condom box"
	desc = "A large collection of condoms, suitable for the safest of sluts!"
	icon = 'modular_aphelion/modules/adult_items/icons/condom_box.dmi'
	icon_state = "condom_box"
	illustration = null
	storage_type = /datum/storage/box/condoms

/obj/item/storage/box/condoms/PopulateContents()
	for(var/i in 1 to 10)
		new /obj/item/condom_pack(src)

/datum/storage/box/condoms
	max_slots = 10

/datum/storage/box/condoms/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(/obj/item/condom_pack)
