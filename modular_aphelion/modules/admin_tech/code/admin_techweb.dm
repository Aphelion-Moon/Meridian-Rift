/// Heres where the Administrative Fabricator and the Admin Techweb live

// techweb: modular_nova\master_files\code\modules\research\techweb\techweb_types.dm
// machine.dm define w/ nova edit code\__DEFINES\machines.dm
// TODO: sprites, flatpacks of common admin machines like the debug chem spawner, etc
/// Admin lathe, waow so cool, wow, wow so cool
/obj/machinery/rnd/production/colony_lathe/admin
	name = "administrative fabricator"
	desc = "A rapid construction fabricator with the feedstock stage removed entirely, which thermodynamics does not \
		ordinarily allow for. Everything it knows, it prints instantly and for free, and it knows every piece of \
		subspace equipment CentCom has ever quietly signed off on. Repacks into a flatpack."
	icon = 'modular_nova/modules/colony_fabricator/icons/machines.dmi'
	icon_state = "colony_lathe"
	base_icon_state = "colony_lathe"
	circuit = null
	production_animation = "colony_lathe_n"
	light_color = LIGHT_COLOR_BRIGHT_YELLOW
	light_power = 5
	allowed_buildtypes = ADMIN_TECHWEB | COLONY_FABRICATOR
	speedup_disabled = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	techweb_path = /datum/techweb/autounlocking/admin
	repacked_type = /obj/item/flatpacked_machine/admin

/obj/machinery/rnd/production/colony_lathe/admin/give_manufacturer_examine()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/machinery/rnd/production/colony_lathe/admin/can_interact(mob/user)
	return user.client?.holder && ..()

// Zero coefficient means has_materials() and use_materials() both ask for nothing, so everything prints free.
/obj/machinery/rnd/production/colony_lathe/admin/build_efficiency(datum/design/design)
	return 0

/obj/machinery/rnd/production/colony_lathe/admin/examine(mob/user)
	. = ..()
	. += span_notice("It needs no material feedstock - every design prints instantly, at no cost, in any quantity.")
	. += span_notice("Alongside the administrative catalogue it carries everything a rapid construction fabricator knows.")

/// Flat-packed version of the administrative fabricator
/obj/item/flatpacked_machine/admin
	name = "flat-packed administrative fabricator"
	/// For all flatpacked machines, set the desc to the type_to_deploy followed by ::desc to reuse the type_to_deploy's description
	desc = /obj/machinery/rnd/production/colony_lathe/admin::desc
	icon = 'modular_nova/modules/colony_fabricator/icons/packed_machines.dmi'
	icon_state = "colony_lathe_packed"
	/// What structure is created by this item.
	type_to_deploy = /obj/machinery/rnd/production/colony_lathe/admin
	/// How long it takes to create the structure in question.
	deploy_time = 4 SECONDS
	w_class = WEIGHT_CLASS_TINY
	slot_flags = ITEM_SLOT_ADMIN
	resistance_flags = INDESTRUCTIBLE
	obj_flags = parent_type::obj_flags | ADMIN_OBJ_FLAGS
	obj_flags_nova = parent_type::obj_flags_nova | ADMIN_OBJ_FLAGS_NOVA

/obj/item/flatpacked_machine/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/flatpacked_machine/admin/give_deployable_component()
	AddComponent(/datum/component/deployable/admin, deploy_time, type_to_deploy)

/** Restricts deployment of the administrative fabricator to active administrators. */
/datum/component/deployable/admin

/datum/component/deployable/admin/deploy(obj/source, mob/user, location, direction)
	var/turf/deploy_location
	var/new_direction

	if(user)
		if(!user.client?.holder || !user.is_holding(source))
			return
		deploy_location = get_step(user, user.dir)
		if(deploy_location.is_blocked_turf(TRUE, parent))
			source.balloon_alert(user, "insufficient room to deploy here.")
			return
		new_direction = user.dir
		source.balloon_alert(user, "deploying...")
		playsound(source, 'sound/items/tools/ratchet.ogg', 50, TRUE)
		if(!do_after(user, deploy_time))
			return
		if(QDELETED(source) || QDELETED(user) || !user.client?.holder || !user.is_holding(source))
			return
		deploy_location = get_step(user, user.dir)
		if(deploy_location.is_blocked_turf(TRUE, parent))
			source.balloon_alert(user, "insufficient room to deploy here.")
			return
		new_direction = user.dir
	else
		deploy_location = location
		new_direction = direction

	var/atom/deployed_object = new thing_to_be_deployed(deploy_location)
	if(direction_setting)
		deployed_object.setDir(new_direction)
		deployed_object.update_icon_state()

	deployments -= 1
	if(!multiple_deployments || deployments < 1)
		qdel(source)

/**
 * Base design for everything the administrative fabricator prints
 *
 * New printables in this module subtype this and declare only name, build_path, and a category if the default
 * does not fit. Two constraints the CI unit tests enforce: RND_CATEGORY_INITIAL must stay in the category list or an
 * autounlocking techweb will not pick the design up, and the material cost must not be empty, because a design with a
 * build_path and no cost at all fails the design test. Nothing is charged in practice - the fabricator overrides
 * build_efficiency() to zero.
 */
/datum/design/admin
	abstract_type = /datum/design/admin
	build_type = ADMIN_TECHWEB
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT)
	// The token cost must not be stamped onto what comes out, or a printed multitool ends up made of ten iron instead
	// of what it is normally made of. This also exempts these designs from the design_mats unit test, which otherwise
	// requires the design cost and the item's custom_materials to agree.
	inherit_materials = DESIGN_DONT_INHERIT_MATS
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_EQUIPMENT)

// Tools

/datum/design/admin/multitool
	name = "Subspace Multitool"
	build_path = /obj/item/multitool/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/welding_tool
	name = "Subspace Welding Tool"
	build_path = /obj/item/weldingtool/advanced/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/jaws_of_life
	name = "Subspace Jaws of Life"
	build_path = /obj/item/crowbar/power/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/hand_drill
	name = "Subspace Hand Drill"
	build_path = /obj/item/screwdriver/power/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/matter_manipulator
	name = "Subspace Matter Manipulator"
	build_path = /obj/item/construction/rcd/arcd/mattermanipulator/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/rld
	name = "Subspace Lighting Device"
	build_path = /obj/item/construction/rld/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/plumbing_constructor
	name = "Subspace Plumbing Constructor"
	build_path = /obj/item/construction/plumbing/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/part_replacer
	name = "Subspace Rapid Part Exchange Device"
	build_path = /obj/item/storage/part_replacer/bluespace/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/light_replacer
	name = "Subspace Light Replacer"
	build_path = /obj/item/lightreplacer/blue/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/forcefield_projector
	name = "Subspace Forcefield Projector"
	build_path = /obj/item/forcefield_projector/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/holosign_creator
	name = "Subspace Atmospheric Holofan Projector"
	build_path = /obj/item/holosign_creator/atmos/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/extinguisher
	name = "Subspace Fire Extinguisher"
	build_path = /obj/item/extinguisher/subspace
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/mop
	name = "Subspace Advanced Mop"
	build_path = /obj/item/mop/advanced/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/soap
	name = "Subspace Soap"
	build_path = /obj/item/soap/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/shears
	name = "Subspace Botanical Shears"
	build_path = /obj/item/shears/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/watering_can
	name = "Subspace Watering Can"
	build_path = /obj/item/reagent_containers/cup/watering_can/advanced/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

// Weaponry

/datum/design/admin/carbine
	name = "Subspace Carbine"
	build_path = /obj/item/gun/energy/modular_laser_rifle/carbine/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/pneumatic_cannon
	name = "Subspace Ballmatter Mass Projector"
	build_path = /obj/item/pneumatic_cannon/subspace
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/baseball_bat
	name = "Subspace Baseball Bat"
	build_path = /obj/item/melee/baseball_bat/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/dagenblicky
	name = "Subspace Mass Projector Pen"
	build_path = /obj/item/gun/magic/subspace/dagenblicky
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/fisher
	name = "Subspace Disruptor"
	build_path = /obj/item/gun/energy/recharge/fisher/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/medigun
	name = "Subspace Medigun"
	build_path = /obj/item/gun/energy/cell_loaded/medigun/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/reagent_gun
	name = "Subspace Reagent Gun"
	build_path = /obj/item/gun/chem/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/syringe_gun
	name = "Subspace Syringe Gun"
	build_path = /obj/item/gun/syringe/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

// Equipment

/datum/design/admin/pda
	name = "Subspace PDA"
	build_path = /obj/item/modular_computer/pda/admin

/datum/design/admin/headset
	name = "Bluespace Headset"
	build_path = /obj/item/radio/headset/admin

/datum/design/admin/encryptionkey
	name = "Subspace Encryption Key"
	build_path = /obj/item/encryptionkey/admin

/datum/design/admin/contacts
	name = "Subspace Contacts"
	build_path = /obj/item/clothing/glasses/meson/engine/admin/debug

/datum/design/admin/laser_pointer
	name = "Subspace Laser Pointer"
	build_path = /obj/item/laser_pointer/admin

/datum/design/admin/door_remote
	name = "Subspace Door Remote"
	build_path = /obj/item/door_remote/admin

/datum/design/admin/emag
	name = "Subspace Cryptographic Sequencer"
	build_path = /obj/item/card/emag/admin

/datum/design/admin/target_locator
	name = "Subspace Target Locator"
	build_path = /obj/item/pinpointer/crew/admin

/datum/design/admin/vendor_beacon
	name = "Debug Vendor Beacon"
	build_path = /obj/item/summon_beacon/vendors/debug

/datum/design/admin/job_locker_beacon
	name = "Debug Job Locker Beacon"
	build_path = /obj/item/choice_beacon/job_locker/debug

/datum/design/admin/fan_capsule
	name = "Debug Tiny Fan Capsule"
	build_path = /obj/item/survivalcapsule/admin/fan

/datum/design/admin/fabricator
	name = "Flat-packed Administrative Fabricator"
	build_path = /obj/item/flatpacked_machine/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_CONSTRUCTION)

// Storage

/datum/design/admin/pocket
	name = "Bluespace Pocket"
	build_path = /obj/item/storage/bag/admin

/datum/design/admin/construction_bag
	name = "Bluespace Construction Bag"
	build_path = /obj/item/storage/bag/construction/admin

/datum/design/admin/pouch
	name = "Subspace Pouch"
	build_path = /obj/item/storage/subspace_pouch

/datum/design/admin/utility_belt
	name = "Bluespace Utility Belt"
	build_path = /obj/item/storage/belt/utility/admin/full

// Medical

/datum/design/admin/health_analyzer
	name = "Subspace Health Analyzer"
	build_path = /obj/item/healthanalyzer/advanced/admin

/datum/design/admin/surgery_tray
	name = "Subspace Surgical Tray"
	build_path = /obj/item/surgery_tray/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/hypospray
	name = "Subspace Hypospray"
	build_path = /obj/item/reagent_containers/hypospray/combat/subspace

/datum/design/admin/chem_synth
	name = "Handheld Debug Chemical Synthesiser"
	build_path = /obj/item/handheld_debug_chem_synth

/datum/design/admin/beaker
	name = "Subspace Beaker"
	build_path = /obj/item/reagent_containers/cup/beaker/admin

/datum/design/admin/syringe
	name = "Subspace Syringe"
	build_path = /obj/item/reagent_containers/syringe/admin

/datum/design/admin/scalpel
	name = "Subspace Laser Scalpel"
	build_path = /obj/item/scalpel/advanced/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/retractor
	name = "Subspace Mechanical Pinches"
	build_path = /obj/item/retractor/advanced/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/cautery
	name = "Subspace Searing Tool"
	build_path = /obj/item/cautery/advanced/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/blood_filter
	name = "Subspace Medical Combitool"
	build_path = /obj/item/blood_filter/advanced/alien/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/ph_meter
	name = "Subspace pH Meter"
	build_path = /obj/item/ph_meter/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)

/datum/design/admin/patch_applicator
	name = "Subspace Patch Applicator"
	build_path = /obj/item/reagent_containers/applicator/patch/admin

/datum/design/admin/pill_applicator
	name = "Subspace Pill Applicator"
	build_path = /obj/item/reagent_containers/applicator/pill/admin

/datum/design/admin/beaker_noreact
	name = "Subspace Cryostasis Beaker"
	build_path = /obj/item/reagent_containers/cup/beaker/admin/noreact

/datum/design/admin/beaker_small
	name = "Small Subspace Beaker"
	build_path = /obj/item/reagent_containers/cup/beaker/admin/small

// Internals

/datum/design/admin/tank_oxygen
	name = "Oxygen Subspace Tank"
	build_path = /obj/item/tank/internals/admin/oxygen

/datum/design/admin/tank_pluoxium
	name = "Pluoxium Subspace Tank"
	build_path = /obj/item/tank/internals/admin/pluoxium

/datum/design/admin/tank_plasma
	name = "Plasma Subspace Tank"
	build_path = /obj/item/tank/internals/admin/plasma

/datum/design/admin/tank_nitrogen
	name = "Nitrogen Subspace Tank"
	build_path = /obj/item/tank/internals/admin/nitrogen

/datum/design/admin/gas_filter
	name = "Subspace Gas Filter"
	build_path = /obj/item/gas_filter/admin

/datum/design/admin/tank_empty
	name = "Empty Subspace Tank"
	build_path = /obj/item/tank/internals/admin

/datum/design/admin/tank_tritium
	name = "Tritium Subspace Tank"
	build_path = /obj/item/tank/internals/admin/tritium

/datum/design/admin/tank_freon
	name = "Freon Subspace Tank"
	build_path = /obj/item/tank/internals/admin/freon

/datum/design/admin/tank_juggermol
	name = "'JUGGERMOL' Subspace Tank"
	build_path = /obj/item/tank/internals/admin/mix/juggermol

/datum/design/admin/tank_fusionfur
	name = "'Fusion-Fur' Subspace Tank"
	build_path = /obj/item/tank/internals/admin/mix/fusionfur

/datum/design/admin/tank_beeshead
	name = "'Bee's Head' Subspace Tank"
	build_path = /obj/item/tank/internals/admin/mix/beeshead

// Worn kit - the bluespace technician loadout

/datum/design/admin/techsuit
	name = "Bluespace Techsuit"
	build_path = /obj/item/clothing/under/admin

/datum/design/admin/letterman
	name = "Bluespace Letterman"
	build_path = /obj/item/clothing/suit/admin

/datum/design/admin/gauntlets
	name = "Bluespace Gauntlets"
	build_path = /obj/item/clothing/gloves/tackler/admin

/datum/design/admin/magboots
	name = "Bluespace Magboots"
	build_path = /obj/item/clothing/shoes/magboots/advance/admin

/datum/design/admin/visor
	name = "Bluespace Visor"
	build_path = /obj/item/clothing/head/helmet/perceptomatrix/admin

/datum/design/admin/gas_mask
	name = "Bluespace Mask"
	build_path = /obj/item/clothing/mask/gas/atmos/admin

/datum/design/admin/energy_shield
	name = "CentCom Tactical Shield Projector"
	build_path = /obj/item/clothing/accessory/energy_shield/admin

/datum/design/admin/cytotheca
	name = "Bluespace Cytotheca"
	build_path = /obj/item/storage/neck/admin/cytotheca

/datum/design/admin/armor_vest
	name = "Technician's Vest"
	build_path = /obj/item/clothing/suit/armor/vest/debug

// Identification

/datum/design/admin/id_admin
	name = "Admin ID"
	build_path = /obj/item/card/id/advanced/debug/admin

/datum/design/admin/id_bluespace
	name = "Bluespace ID"
	build_path = /obj/item/card/id/advanced/debug/admin/bluespace

/datum/design/admin/id_subspace
	name = "Subspace ID"
	build_path = /obj/item/card/id/advanced/debug/admin/subspace

/datum/design/admin/id_centcom
	name = "CentCom Master ID"
	build_path = /obj/item/card/id/advanced/debug/admin/centcom

// Kits - prepacked boxes, for when you would rather not print things one at a time

/datum/design/admin/debug_box
	name = "Subspace Box"
	build_path = /obj/item/storage/box/debug

/datum/design/admin/taser
	name = "Debug Taser"
	build_path = /obj/item/gun/energy/taser/debug
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

// MODsuits

/datum/design/admin/modsuit_bluespace
	name = "Bluespace MODsuit"
	build_path = /obj/item/mod/control/pre_equipped/bluespace
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUITS)

/datum/design/admin/modsuit_subspace
	name = "Subspace MODsuit"
	build_path = /obj/item/mod/control/pre_equipped/subspace
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUITS)

/datum/design/admin/module_storage
	name = "MOD Subspace Storage Module"
	build_path = /obj/item/mod/module/storage/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUIT_MODULES)

/datum/design/admin/module_dispenser
	name = "MOD Subspace Box Dispenser Module"
	build_path = /obj/item/mod/module/dispenser/subspacebox
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUIT_MODULES)

/datum/design/admin/module_infiltrator
	name = "MOD Subspace Infiltrator Module"
	build_path = /obj/item/mod/module/infiltrator/admin
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUIT_MODULES)

/datum/design/admin/module_carbine
	name = "MOD Subspace Carbine Module"
	build_path = /obj/item/mod/module/admin/carbine
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUIT_MODULES)

// Cyborg

/datum/design/admin/borg_frontline
	name = "Cyborg Upgrade: Frontline Walker"
	build_path = /obj/item/borg/upgrade/transform/admin/frontline
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MECHFAB_CYBORG_MODULES)

/datum/design/admin/borg_backline
	name = "Cyborg Upgrade: Backline Walker"
	build_path = /obj/item/borg/upgrade/transform/admin/backline
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MECHFAB_CYBORG_MODULES)

/datum/design/admin/borg_engineer
	name = "Cyborg Upgrade: Engineering Walker"
	build_path = /obj/item/borg/upgrade/transform/admin/engineer
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MECHFAB_CYBORG_MODULES)

// Subspace tier - the badmin variants of the above. Same slots, fewer manners.

/datum/design/admin/headset_subspace
	name = "Subspace Headset"
	build_path = /obj/item/radio/headset/admin/subspace

/datum/design/admin/techsuit_subspace
	name = "Subspace Techsuit"
	build_path = /obj/item/clothing/under/admin/subspace

/datum/design/admin/letterman_subspace
	name = "Subspace Letterman"
	build_path = /obj/item/clothing/suit/admin/subspace

/datum/design/admin/gauntlets_subspace
	name = "Subspace Gauntlets"
	build_path = /obj/item/clothing/gloves/tackler/admin/subspace

/datum/design/admin/magboots_subspace
	name = "Subspace Magboots"
	build_path = /obj/item/clothing/shoes/magboots/advance/admin/subspace

/datum/design/admin/visor_subspace
	name = "Subspace Visor"
	build_path = /obj/item/clothing/head/helmet/perceptomatrix/admin/subspace

/datum/design/admin/gas_mask_subspace
	name = "Subspace Mask"
	build_path = /obj/item/clothing/mask/gas/atmos/admin/subspace

/datum/design/admin/energy_shield_bluespace
	name = "Bluespace Shield Projector"
	build_path = /obj/item/clothing/accessory/energy_shield/admin/bluespace

/datum/design/admin/energy_shield_subspace
	name = "Subspace Shield Projector"
	build_path = /obj/item/clothing/accessory/energy_shield/admin/subspace

/datum/design/admin/cytotheca_subspace
	name = "Subspace Cytotheca"
	build_path = /obj/item/storage/neck/admin/cytotheca/subspace

/datum/design/admin/pocket_subspace
	name = "Subspace Pocket"
	build_path = /obj/item/storage/bag/admin/subspace

/datum/design/admin/construction_bag_subspace
	name = "Subspace Construction Bag"
	build_path = /obj/item/storage/bag/construction/admin/subspace

/datum/design/admin/utility_belt_empty
	name = "Technician's Satchel"
	build_path = /obj/item/storage/belt/utility/admin

/datum/design/admin/utility_belt_bluespace
	name = "Bluespace Technician's Satchel"
	build_path = /obj/item/storage/belt/utility/admin/full/bluespace

/datum/design/admin/utility_belt_subspace
	name = "Subspace Technician's Satchel"
	build_path = /obj/item/storage/belt/utility/admin/full/subspace

/datum/design/admin/pouch_cytotheca
	name = "Slimy Subspace Pouch"
	build_path = /obj/item/storage/subspace_pouch/cytotheca

/datum/design/admin/debug_box_schrodinger
	name = "Schrodinger's Subspace Box"
	build_path = /obj/item/storage/box/debug/schrodinger

/datum/design/admin/patch_applicator_instant
	name = "Instant Subspace Patch Applicator"
	build_path = /obj/item/reagent_containers/applicator/patch/admin/instant

/datum/design/admin/pill_applicator_xr
	name = "Extended Release Subspace Pill Applicator"
	build_path = /obj/item/reagent_containers/applicator/pill/admin/xr

/datum/design/admin/annihilator
	name = "Annihilator"
	build_path = /obj/item/gun/energy/pulse/destroyer/annihilator
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_WEAPONS)

/datum/design/admin/modsuit_danger
	name = "Bluespace MODsuit (Danger Modules)"
	build_path = /obj/item/mod/control/pre_equipped/bluespace/danger_module_debug
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_MODSUITS)
