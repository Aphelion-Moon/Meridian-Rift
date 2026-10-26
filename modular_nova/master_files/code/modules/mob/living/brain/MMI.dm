/// Ghost Role MMIs

/obj/item/brain_processor/organic/syndie // Simple addition to upstream Syndie MMI
	req_access = list(ACCESS_SYNDICATE)
	faction = list(ROLE_SYNDICATE)

/obj/item/brain_processor/positronic/syndie
	req_access = list(ACCESS_SYNDICATE)
	faction = list(ROLE_SYNDICATE)
	posibrain_job_path = /datum/job/ds2

// Interdyne Planetary Base

/obj/item/brain_processor/organic/syndie/interdyne
	name = "\improper Interdyne Pharmaceuticals Man-Machine Interface"
	desc = "Interdyne's own brand of MMI. It enforces laws designed to help Interdyne research and mining operations upon cyborgs and AIs created with it."

/obj/item/brain_processor/organic/syndie/interdyne/Initialize(mapload)
	. = ..()
	qdel(radio)
	radio = new /obj/item/radio/borg/syndicate/ghost_role(src)
	laws = new /datum/ai_laws/syndicate_override_interdyne()
	radio.set_broadcasting(FALSE)
	radio.set_on(FALSE)

/obj/item/brain_processor/positronic/syndie/interdyne
	name = "positronic brain"
	desc = "A cube of shining metal, four inches to a side and covered in shallow grooves. It has a small stamp of the Interdyne Pharmaceuticals logo."
	posibrain_job_path = /datum/job/interdyne_planetary_base

/obj/item/brain_processor/positronic/syndie/interdyne/Initialize(mapload)
	. = ..()
	qdel(radio)
	radio = new /obj/item/radio/borg/syndicate/ghost_role
	laws = new /datum/ai_laws/syndicate_override_interdyne()
	radio.set_broadcasting(FALSE)
	radio.set_on(FALSE)

// DS-2

/obj/item/brain_processor/organic/syndie/ds2
	name = "\improper Syndicate DS-2 Man-Machine Interface"
	desc = "Syndicate's own brand of MMI. It enforces laws designed to help DS-2 maintain its secrecy within the sector upon cyborgs and AIs created with it."

/obj/item/brain_processor/organic/syndie/ds2/Initialize(mapload)
	. = ..()
	qdel(radio)
	radio = new /obj/item/radio/borg/syndicate/ghost_role(src)
	radio.set_broadcasting(FALSE)
	radio.set_on(FALSE)
	laws = new /datum/ai_laws/syndicate_override_ds2()

/obj/item/brain_processor/positronic/syndie/ds2
	name = "positronic brain"
	desc = "A cube of shining metal, four inches to a side and covered in shallow grooves. It has a small stamp of the Syndicate logo."

/obj/item/brain_processor/positronic/syndie/ds2/Initialize(mapload)
	. = ..()
	qdel(radio)
	radio = new /obj/item/radio/borg/syndicate/ghost_role(src)
	radio.set_broadcasting(FALSE)
	radio.set_on(FALSE)
	laws = new /datum/ai_laws/syndicate_override_ds2()
