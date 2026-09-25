/obj/effect/landmark/navigate_destination/cryo
	location = "Cryopods"

/obj/effect/landmark/navigate_destination/cryo/Initialize(mapload)
	. = ..()
	REGISTER_REQUIRED_MAP_ITEM(1, 1)

/obj/effect/landmark/navigate_destination/barber
	location = "Barber"
