//! Admin tech storage belts

/// The base admin bluespace satchel (belt).
/// This one is empty, subtypes should use [/obj/item/storage/belt/utility/admin/full]
/// to consistently implement the same amount of items.
/obj/item/storage/belt/utility/admin
	name = "bluespace satchel"
	desc = "This bad boy can fit all your bus in one place. Why do you have this?!"
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_clothing.dmi'
	icon_state = "admeme_satchel"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "admeme_satchel"
	storage_type = /datum/storage/admin
	w_class = WEIGHT_CLASS_TINY
	slot_flags = ITEM_SLOT_ADMIN
	resistance_flags = INDESTRUCTIBLE
	obj_flags = parent_type::obj_flags | ADMIN_OBJ_FLAGS
	obj_flags_nova = parent_type::obj_flags_nova | ADMIN_OBJ_FLAGS_NOVA

/obj/item/storage/belt/utility/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/storage/belt/utility/admin/full

/obj/item/storage/belt/utility/admin/full/PopulateContents()
	new	/obj/item/blueprints(src)
	new	/obj/item/construction/plumbing/admin(src)
	new	/obj/item/bodybag/bluespace(src)
	new	/obj/item/teleport_rod/admin(src)
	new /obj/item/soap/admin(src)
	new /obj/item/airlock_painter/decal/debug(src)
	new	/obj/item/holosign_creator/atmos/admin(src)
	new	/obj/item/forcefield_projector/admin(src)
	new /obj/item/healthanalyzer/advanced/admin(src)
	new	/obj/item/lightreplacer/blue/admin(src)
	new	/obj/item/construction/rld/admin(src)
	new	/obj/item/rwd/admin(src)
	new /obj/item/extinguisher/subspace(src)
	new	/obj/item/analyzer/ranged(src)
	new	/obj/item/construction/rtd/admin(src)
	new	/obj/item/construction/rcd/arcd/mattermanipulator/admin(src)
	new	/obj/item/multitool/admin(src)
	new	/obj/item/weldingtool/advanced/admin(src)
	new	/obj/item/crowbar/power/alien/admin(src)
	new	/obj/item/screwdriver/power/alien/admin(src)
	new	/obj/item/pipe_dispenser/bluespace(src)
	new /obj/item/door_remote/admin(src)
	new	/obj/item/storage/part_replacer/bluespace/admin(src)

/obj/item/storage/belt/utility/admin/full/bluespace
	name = "bluespace technician's satchel"
	desc = "A hand crafted satchel made of the finest materials, processes, and a creatively integrated bluespace anomaly core. \
		This one was carefully prestocked and organized by a Central Command Quartermaster to service an engineering aligned technician."

/obj/item/storage/belt/utility/admin/full/subspace
	name = "subspace technician's satchel"
	storage_type = /datum/storage/admin/bag/subspace
	desc = "A hand crafted satchel made of the finest materials, processes, and a creatively integrated bluespace anomaly core. \
		This one was prestocked by a Central Command Quartermaster who was told to stop asking what any of it was for."

/obj/item/storage/belt/utility/admin/full/subspace/PopulateContents()
	new	/obj/item/blueprints(src)
	new	/obj/item/construction/plumbing/admin(src)
	new	/obj/item/hand_labeler(src)
	new	/obj/item/universal_scanner(src)
	new	/obj/item/laser_pointer/admin(src)
	new /obj/item/reagent_containers/cup/watering_can/advanced/admin(src)
	new	/obj/item/melee/skateboard/hoverboard/admin(src)
	new	/obj/item/bodybag/bluespace(src)
	new	/obj/item/toy/crayon/spraycan/infinite(src)
	new	/obj/item/teleport_rod/admin(src)
	new	/obj/item/fishing_rod/telescopic/master(src)
	new /obj/item/gun/magic/hook/debug(src)
	new	/obj/item/gun/energy/recharge/fisher/admin(src)
	new /obj/item/gun/chem/admin(src)
	new /obj/item/melee/baseball_bat/admin(src)
	new	/obj/item/mop/advanced/admin(src)
	new /obj/item/reagent_containers/hypospray/combat/subspace(src)
	new /obj/item/airlock_painter/decal/debug(src)
	new	/obj/item/forcefield_projector/admin(src)
	new	/obj/item/holosign_creator/atmos/admin(src)
	new /obj/item/healthanalyzer/advanced/admin(src)
	new	/obj/item/lightreplacer/blue/admin(src)
	new	/obj/item/construction/rld/admin(src)
	new	/obj/item/rwd/admin(src)
	new /obj/item/extinguisher/subspace(src)
	new	/obj/item/analyzer/ranged(src)
	new	/obj/item/construction/rtd/admin(src)
	new	/obj/item/construction/rcd/arcd/mattermanipulator/admin(src)
	new	/obj/item/multitool/admin(src)
	new	/obj/item/weldingtool/advanced/admin(src)
	new	/obj/item/crowbar/power/alien/admin(src)
	new	/obj/item/screwdriver/power/alien/admin(src)
	new	/obj/item/pipe_dispenser/bluespace(src)
	new	/obj/item/rpd_upgrade/unwrench(src)
	new /obj/item/door_remote/admin(src)
	new	/obj/item/storage/part_replacer/bluespace/admin(src)
