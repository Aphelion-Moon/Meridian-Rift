//Bell jingling squeak component for those collars that jingle-jangle-jingle.
/datum/component/squeak/collar_bell
	dupe_mode = COMPONENT_DUPE_SOURCES

/datum/component/squeak/collar_bell/on_equip(datum/source, mob/equipper, slot)
	. = ..()
	RegisterSignal(equipper, COMSIG_GENERAL_STEP_ACTION, PROC_REF(on_wearer_step), override = TRUE)

/datum/component/squeak/collar_bell/on_drop(datum/source, mob/user)
	UnregisterSignal(user, COMSIG_GENERAL_STEP_ACTION)
	return ..()

/datum/component/squeak/collar_bell/proc/on_wearer_step(mob/living/carbon/human/wearer)
	SIGNAL_HANDLER
	if(QDELETED(parent) || !istype(wearer) || wearer.wear_neck != parent)
		return
	step_squeak(parent)

//Base for all the tagged collars
/datum/atom_skin/collar
	abstract_type = /datum/atom_skin/collar
	greyscale_item_path = /obj/item/clothing/neck/collar/tagged
	/// Whether this gets a jingle squeak component added
	var/jingles = FALSE

/datum/atom_skin/collar/apply(atom/our_collar, mob/user)
	. = ..()

	if(!jingles)
		our_collar.RemoveComponentSource(
			REF(our_collar),
			/datum/component/squeak/collar_bell,
		)
		return

	var/datum/component/squeak/collar_bell/bell = our_collar.AddComponentFrom(REF(our_collar), /datum/component/squeak/collar_bell, list('sound/effects/jingle.ogg' = 1), 25, 50, 16)

	if(ismob(our_collar.loc) && bell.holder != our_collar.loc)
		bell.on_equip(our_collar, our_collar.loc)

/datum/atom_skin/collar/clear_skin(atom/clear_from, mob/user)
	. = ..()
	clear_from.RemoveComponentSource(REF(clear_from), /datum/component/squeak/collar_bell)

//Reskin list for the plain tagged collar
//Alphabetically sorted; the initial selection is Tagged (Thin)
/datum/atom_skin/collar/thin_bell
	preview_name = "Bell (Thin)"
	new_icon_state = "thin_bell_collar"
	jingles = TRUE

/datum/atom_skin/collar/thin_cowbell
	preview_name = "Cowbell (Thin)"
	new_icon_state = "thin_cowbell_collar"
	jingles = TRUE

/datum/atom_skin/collar/thin_cross
	preview_name = "Cross (Thin)"
	new_icon_state = "thin_cross_collar"

/datum/atom_skin/collar/thin_holo
	preview_name = "Holographic (Thin)"
	new_icon_state = "thin_holocollar"

/datum/atom_skin/collar/thin_tag
	preview_name = "Tagged (Thin)"
	new_icon_state = "thin_tagged_collar"

/datum/atom_skin/collar/thick_bell
	preview_name = "Bell (Thick)"
	new_icon_state = "thick_bell_collar"
	jingles = TRUE

/datum/atom_skin/collar/thick_cowbell
	preview_name = "Cowbell (Thick)"
	new_icon_state = "thick_cowbell_collar"
	jingles = TRUE

/datum/atom_skin/collar/thick_cross
	preview_name = "Cross (Thick)"
	new_icon_state = "thick_cross_collar"

/datum/atom_skin/collar/thick_holo
	preview_name = "Holographic (Thick)"
	new_icon_state = "thick_holocollar"

/datum/atom_skin/collar/thick_tag
	preview_name = "Tagged (Thick)"
	new_icon_state = "thick_tagged_collar"

/obj/item/clothing/neck/collar/tagged
	name = "tagged collar"
	desc = "A collar, fit with a locking buckle and adorned with an ornament."
	icon = 'icons/map_icons/clothing/neck.dmi'
	icon_state = "/obj/item/clothing/neck/collar/tagged"
	post_init_icon_state = "thin_tagged_collar"
	greyscale_config = /datum/greyscale_config/tagged_collar
	greyscale_config_worn = /datum/greyscale_config/tagged_collar/worn
	greyscale_colors = "#2d2d33#dead39"

/obj/item/clothing/neck/collar/tagged/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/collar, initial_skin = "Tagged (Thin)", blacklisted_subtypes = subtypesof(/datum/atom_skin/collar/leather))
