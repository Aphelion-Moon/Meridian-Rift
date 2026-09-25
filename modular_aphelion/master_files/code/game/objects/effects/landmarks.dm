/obj/effect/landmark/navigate_destination/cryo
	location = "Cryopods"

/obj/effect/landmark/navigate_destination/cryo/Initialize(mapload)
	. = ..()
	REGISTER_REQUIRED_MAP_ITEM(1, 1)
	stack_trace("where is the second of these coming from")

/obj/effect/landmark/navigate_destination/barber
	location = "Barber"
