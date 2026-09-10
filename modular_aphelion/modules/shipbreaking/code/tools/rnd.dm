/datum/design/demo_remote
	name = "Demolition Vac-Charge Clacker"
	build_type = PROTOLATHE | AWAY_LATHE | COLONY_FABRICATOR
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4.75,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 1.8,
		/datum/material/nanocarbon = HALF_SHEET_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/demo_charge_detonator
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_CARGO

/datum/design/demo_charge
	name = "Low-Pyrotechnic Shaped Demolition Vac-Charge"
	build_type = PROTOLATHE | AWAY_LATHE | COLONY_FABRICATOR
	materials = list(
		/datum/material/titanium = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/aluminum = HALF_SHEET_MATERIAL_AMOUNT / 2,
		/datum/material/plasma = SMALL_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/grenade/c4/demo_charge
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_CARGO

/datum/design/salvage_cutter
	name = "Salvage Cutter"
	build_type = PROTOLATHE | AWAY_LATHE | COLONY_FABRICATOR
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/aluminum = HALF_SHEET_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/weldingtool/salvage_cutter
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_CARGO

/datum/design/salvage_wrench
	name = "Salvage Wrench"
	build_type = PROTOLATHE | AWAY_LATHE | COLONY_FABRICATOR
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/aluminum = HALF_SHEET_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/wrench/salvage_wrench
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_CARGO

/datum/techweb_node/plasma_mining/New()
	unlocked_designs += list(
		/datum/design/demo_remote,
		/datum/design/demo_charge,
		/datum/design/salvage_cutter,
		/datum/design/salvage_wrench,
	)
	return ..()
