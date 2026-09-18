/datum/outfit/job/roboticist
	backpack = /obj/item/storage/backpack/science/robo
	satchel = /obj/item/storage/backpack/satchel/science/robo
	duffelbag = /obj/item/storage/backpack/duffelbag/science/robo
	messenger = /obj/item/storage/backpack/messenger/science/robo

	glasses = /obj/item/clothing/glasses/hud/diagnostic
	gloves = /obj/item/clothing/gloves/color/black

	l_hand = /obj/item/storage/medkit/robotic_repair/preemo/stocked
/datum/outfit/job/roboticist/New()
	. = ..()

	LAZYINITLIST(backpack_contents)
	backpack_contents[/obj/item/clothing/head/utility/welding] = 1

/datum/job/roboticist/New()
	. = ..()

	mail_goodies += list(
		/obj/item/healthanalyzer/advanced = 15,
		/obj/item/screwdriver/power/science = 6,
		/obj/item/crowbar/power/science = 6,
		/obj/item/weldingtool/experimental = 2, // a lot rarer since it's relatively powerful
		/obj/item/scalpel/advanced = 6,
		/obj/item/retractor/advanced = 6,
		/obj/item/cautery/advanced = 6,
		/obj/item/storage/pill_bottle/liquid_solder = 6,
		/obj/item/storage/pill_bottle/system_cleaner = 6,
		/obj/item/storage/pill_bottle/nanite_slurry = 6,
		/obj/item/reagent_containers/spray/hercuri/chilled = 8,
		/obj/item/reagent_containers/spray/dinitrogen_plasmide = 8,
	)
