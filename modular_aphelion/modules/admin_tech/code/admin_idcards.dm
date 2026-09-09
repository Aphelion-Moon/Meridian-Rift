//! Admin ID cards and ID trims

// NOVA MODULE ICSPAWNING https://github.com/Skyrat-SS13/Skyrat-tg/pull/104

/obj/item/card/id/advanced/debug/admin
	name = "\improper Admin ID"
	desc = "An Admin ID card. Has ALL the all access, you really shouldn't have this. Sec huds read it as static, and no threat assessment ever manages to hold an opinion about you."
	icon_state = "card_platinum"
	assigned_icon_state = "assigned_centcom"
	trim = /datum/id_trim/admin/bluespace
	wildcard_slots = WILDCARD_LIMIT_ADMIN
	w_class = WEIGHT_CLASS_TINY
	slot_flags = ITEM_SLOT_ADMIN
	resistance_flags = INDESTRUCTIBLE
	obj_flags = parent_type::obj_flags | ADMIN_OBJ_FLAGS
	obj_flags_nova = parent_type::obj_flags_nova | ADMIN_OBJ_FLAGS_NOVA

/obj/item/card/id/advanced/debug/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/card/id/advanced/debug/admin/bluespace
	name = "\improper Bluespace ID"
	desc = parent_type::desc + " This one is stamped for a Bluespace Technician."

/datum/id_trim/admin/bluespace
	assignment = "Bluespace Technician"
	trim_state = "trim_stationengineer"
	department_color = COLOR_CENTCOM_BLUE
	subdepartment_color = COLOR_ENGINEERING_ORANGE
	sechud_icon_state = SECHUD_SCRAMBLED
	threat_modifier = -INFINITY
	big_pointer = TRUE
	pointer_color = COLOR_BLUE

//Subspace Tech bits
/obj/item/card/id/advanced/debug/admin/subspace
	name = "\improper Subspace ID"
	desc = parent_type::desc + " This one is stamped for a Subspace Technician, which is not a real posting."
	icon_state = "card_carp"
	assigned_icon_state = "assigned_centcom"
	trim = /datum/id_trim/admin/subspace
	wildcard_slots = WILDCARD_LIMIT_ADMIN

/datum/id_trim/admin/subspace
	assignment = "Subspace Technician"
	trim_state = "trim_ert_commander"
	department_color = COLOR_CENTCOM_BLUE
	subdepartment_color = COLOR_ENGINEERING_ORANGE
	sechud_icon_state = SECHUD_SCRAMBLED
	threat_modifier = -INFINITY
	big_pointer = TRUE
	pointer_color = COLOR_PURPLE

//Additional admin ID stuff
/obj/item/card/id/advanced/debug/admin/centcom
	name = "\improper CentCom Master ID"
	desc = "A Master ID card from Central Command. Has ALL the all access, to a suspicious degree. Reads as static on sec huds and registers as no threat at all, which is the most suspicious part."
	icon_state = "card_centcom"
	assigned_icon_state = "assigned_centcom"
	trim = /datum/id_trim/admin/centcom
	wildcard_slots = WILDCARD_LIMIT_ADMIN

/datum/id_trim/admin/centcom
	assignment = "Central Command"
	trim_state = "trim_centcom"
	department_color = COLOR_CENTCOM_BLUE
	subdepartment_color = COLOR_ENGINEERING_ORANGE
	sechud_icon_state = SECHUD_SCRAMBLED
