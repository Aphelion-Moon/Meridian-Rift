/obj/item/storage/briefcase/secure/white/mcr_loadout
	name = "Microfusion Attachment Kit"

/obj/item/storage/briefcase/secure/white/mcr_loadout/hellfire
	name = "Microfusion Attachment Kit (Hellfire)"

/obj/item/storage/briefcase/secure/white/mcr_loadout/hellfire/PopulateContents()
	var/list/items_inside = list(
		/obj/item/microfusion_gun_attachment/barrel/hellfire = 1,
		/obj/item/microfusion_gun_attachment/rail = 1,
		/obj/item/microfusion_gun_attachment/grip = 1,
		)
	generate_items_inside(items_inside,src)

/obj/item/storage/briefcase/secure/white/mcr_loadout/scatter
	name = "Microfusion Attachment Kit (Scatter)"

/obj/item/storage/briefcase/secure/white/mcr_loadout/scatter/PopulateContents()
	var/list/items_inside = list(
		/obj/item/microfusion_gun_attachment/barrel/scatter = 1,
		/obj/item/microfusion_gun_attachment/rail = 1,
		/obj/item/microfusion_gun_attachment/grip = 1,
		)
	generate_items_inside(items_inside,src)

/obj/item/storage/briefcase/secure/white/mcr_loadout/lance
	name = "Microfusion Attachment Kit (Lance)"

/obj/item/storage/briefcase/secure/white/mcr_loadout/lance/PopulateContents()
	var/list/items_inside = list(
		/obj/item/microfusion_gun_attachment/barrel/lance = 1,
		/obj/item/microfusion_gun_attachment/scope = 1,
		/obj/item/microfusion_gun_attachment/heatsink = 1,
		)
	generate_items_inside(items_inside,src)

/obj/item/storage/briefcase/secure/white/mcr_loadout/repeater
	name = "Microfusion Attachment Kit (Repeater)"

/obj/item/storage/briefcase/secure/white/mcr_loadout/repeater/PopulateContents()
	var/list/items_inside = list(
		/obj/item/microfusion_gun_attachment/barrel/repeater = 1,
		/obj/item/microfusion_gun_attachment/rail = 1,
		/obj/item/microfusion_gun_attachment/heatsink = 1,
		)
	generate_items_inside(items_inside,src)

/obj/item/storage/briefcase/secure/white/mcr_loadout/tacticool
	name = "Microfusion Attachment Kit (Suppressor)"

/obj/item/storage/briefcase/secure/white/mcr_loadout/tacticool/PopulateContents()
	var/list/items_inside = list(
		/obj/item/microfusion_gun_attachment/barrel/suppressor = 1,
		/obj/item/microfusion_gun_attachment/rail = 1,
		/obj/item/microfusion_gun_attachment/grip = 1,
		/obj/item/microfusion_gun_attachment/camo = 1,
		)
	generate_items_inside(items_inside,src)

// Phase emitter and cell upgrades

/obj/item/storage/briefcase/secure/white/mcr_parts
	name = "Microfusion Parts Kit"

/obj/item/storage/briefcase/secure/white/mcr_parts/enhanced
	name = "Microfusion Parts Kit (Enhanced)"

/obj/item/storage/briefcase/secure/white/mcr_parts/enhanced/PopulateContents()
	var/list/items_inside = list(
		/obj/item/stock_parts/power_store/cell/microfusion/enhanced = 1,
		/obj/item/microfusion_phase_emitter/enhanced = 1,
		)
	generate_items_inside(items_inside,src)

/obj/item/storage/briefcase/secure/white/mcr_parts/advanced
	name = "Microfusion Parts Kit (Advanced)"

/obj/item/storage/briefcase/secure/white/mcr_parts/advanced/PopulateContents()
	var/list/items_inside = list(
		/obj/item/stock_parts/power_store/cell/microfusion/advanced = 1,
		/obj/item/microfusion_phase_emitter/advanced = 1,
		)
	generate_items_inside(items_inside,src)

/obj/item/storage/briefcase/secure/white/mcr_parts/bluespace
	name = "Microfusion Parts Kit (Bluespace)"

/obj/item/storage/briefcase/secure/white/mcr_parts/bluespace/PopulateContents()
	var/list/items_inside = list(
		/obj/item/stock_parts/power_store/cell/microfusion/bluespace = 1,
		/obj/item/microfusion_phase_emitter/bluespace = 1,
		)
	generate_items_inside(items_inside,src)
