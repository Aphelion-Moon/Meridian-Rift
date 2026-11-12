// Shiptest wardrobe styles, on the game's own reskin component
// Every garment of a family keeps its type, protection and storage; a style only gives it the look of another
// garment of the family, by colour or by design.

/// A Shiptest garment's colour or design
/datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest
	change_base_icon_state = TRUE
	/// Design-only styles keep the wearer's colours
	var/preserve_palette = FALSE

// A colour style previews its garment's own sprite rather than a generated map icon
/datum/atom_skin/shiptest/get_preview_icon_state()
	if(!greyscale_item_path)
		return ..()
	return greyscale_item_path::icon_state

/datum/atom_skin/shiptest/get_preview_icon(atom/for_atom)
	if(!greyscale_item_path)
		return ..()
	return image(icon = greyscale_item_path::icon, icon_state = greyscale_item_path::icon_state)

// tg's apply swaps sprites only on garments without GAGS, so we bring the style garment's configs and colours
/datum/atom_skin/shiptest/apply(obj/item/apply_to, mob/user)
	if(!greyscale_item_path)
		// A fixed-colour style draws its own sprites, which tg's apply leaves alone while GAGS configs are set
		apply_to.greyscale_config = null
		apply_to.greyscale_config_worn = null
		apply_to.greyscale_config_worn_digi = null
		apply_to.greyscale_config_worn_vox = null
		apply_to.greyscale_config_worn_better_vox = null
		apply_to.greyscale_config_inhand_left = null
		apply_to.greyscale_config_inhand_right = null
		apply_to.greyscale_colors = null
	. = ..()
	if(greyscale_item_path)
		shiptest_wear_look(apply_to, greyscale_item_path, preserve_palette ? apply_to.greyscale_colors : null)

// Undoes what the style did, so a design leaves the wearer's colours on
/datum/atom_skin/shiptest/clear_skin(obj/item/clear_from, mob/user)
	. = ..()
	shiptest_wear_look(clear_from, clear_from.type, preserve_palette ? clear_from.greyscale_colors : null)

/**
 * Gives a garment the look of another garment of its family, keeping how it is worn
 *
 * Arguments:
 * * garment - the garment to restyle
 * * style_type - the garment type whose sprites, configs and palette it takes
 * * kept_colors - colours to keep on the channels both share, or null for the style's own palette
 */
/proc/shiptest_wear_look(obj/item/garment, obj/item/style_type, kept_colors)
	garment.icon = style_type::icon
	garment.worn_icon = style_type::worn_icon
	garment.worn_icon_state = style_type::worn_icon_state
	garment.worn_icon_digi = style_type::worn_icon_digi
	garment.worn_icon_vox = style_type::worn_icon_vox
	garment.worn_icon_better_vox = style_type::worn_icon_better_vox
	garment.inhand_icon_state = style_type::inhand_icon_state
	garment.lefthand_file = style_type::lefthand_file
	garment.righthand_file = style_type::righthand_file
	garment.greyscale_config = style_type::greyscale_config
	garment.greyscale_config_worn = style_type::greyscale_config_worn
	garment.greyscale_config_worn_digi = style_type::greyscale_config_worn_digi
	garment.greyscale_config_worn_vox = style_type::greyscale_config_worn_vox
	garment.greyscale_config_worn_better_vox = style_type::greyscale_config_worn_better_vox
	garment.greyscale_config_inhand_left = style_type::greyscale_config_inhand_left
	garment.greyscale_config_inhand_right = style_type::greyscale_config_inhand_right
	garment.greyscale_colors = shiptest_palette_for_style(style_type, kept_colors)
	// Buttons, visors and wraps adjust from the base state, and an opened garment stays open
	garment.base_icon_state = style_type::post_init_icon_state || style_type::icon_state
	garment.icon_state = garment.base_icon_state
	var/datum/component/toggle_icon/buttons = garment.GetComponent(/datum/component/toggle_icon)
	if(buttons?.toggled)
		garment.icon_state += "_t"
	var/datum/component/toggle_attached_clothing/hood = garment.GetComponent(/datum/component/toggle_attached_clothing)
	if(hood)
		if(hood.currently_deployed)
			garment.icon_state += hood.parent_icon_state_suffix
		garment.worn_icon_state = garment.icon_state
		shiptest_wear_hood_look(garment, hood, style_type)
	garment.update_greyscale()
	garment.update_appearance()

/// Gives a garment's hood the hood of its style, so a hood the garment makes later is the style's too
/proc/shiptest_wear_hood_look(obj/item/garment, datum/component/toggle_attached_clothing/hood, obj/item/style_type)
	var/obj/item/hood_type
	if(ispath(style_type, /obj/item/clothing/suit/hooded))
		var/obj/item/clothing/suit/hooded/hooded_style = style_type
		hood_type = hooded_style::hoodtype
	else if(ispath(style_type, /obj/item/clothing/neck/shiptest/poncho))
		var/obj/item/clothing/neck/shiptest/poncho/poncho_style = style_type
		hood_type = poncho_style::hoodtype
	if(!hood_type)
		return
	hood.deployable_type = hood_type
	var/obj/item/worn_hood = hood.deployable
	if(!worn_hood)
		return
	if(!HAS_TRAIT(worn_hood, TRAIT_WAS_RENAMED))
		worn_hood.name = hood_type::name
		worn_hood.desc = hood_type::desc
	shiptest_wear_look(worn_hood, hood_type, garment.greyscale_colors)
	worn_hood.update_slot_icon()

/// Puts a hooded coat's style state back after its hood goes up or down, which uses the type's own state
/proc/shiptest_keep_hooded_state(obj/item/garment)
	if(!garment.base_icon_state)
		return
	var/datum/component/toggle_attached_clothing/hood = garment.GetComponent(/datum/component/toggle_attached_clothing)
	garment.icon_state = "[garment.base_icon_state][hood?.currently_deployed ? hood.parent_icon_state_suffix : ""]"
	garment.worn_icon_state = garment.icon_state

/// Gives a garment's hood the garment's colours, as tg's tailored winter coat does
/proc/shiptest_hood_follows(obj/item/garment)
	var/datum/component/toggle_attached_clothing/hood = garment.GetComponent(/datum/component/toggle_attached_clothing)
	var/obj/item/hood_type = hood?.deployable_type
	if(!hood?.deployable || !hood_type::greyscale_colors || !garment.greyscale_colors)
		return
	hood.deployable.set_greyscale(shiptest_palette_for_style(hood_type, garment.greyscale_colors))
	hood.deployable.update_slot_icon()

/**
 * A style's palette with the wearer's colours kept on the channels both share
 *
 * A family's garments share their channel order, so the first channels carry over and any the style adds take
 * its own colours. Returns null for a style without colours.
 */
/proc/shiptest_palette_for_style(obj/item/style_type, kept_colors)
	var/own_palette = style_type::greyscale_colors
	if(!own_palette)
		return null
	var/list/result = SSgreyscale.ParseColorString(own_palette)
	var/list/kept = islist(kept_colors) ? kept_colors : (kept_colors ? SSgreyscale.ParseColorString(kept_colors) : null)
	for(var/channel in 1 to min(length(result), length(kept)))
		result[channel] = kept[channel]
	return result.Join("")

/// The style a loadout entry saved under this name, matched as tg's loadout matches it
/datum/loadout_item/proc/shiptest_saved_style(chosen_name)
	if(!chosen_name)
		return null
	for(var/datum/atom_skin/style as anything in valid_subtypesof(reskin_datum))
		if((style::new_name || style::preview_name) == chosen_name)
			return style
	return null

// A style can change a garment's GAGS channels, so we put the style on before the saved colours, which win over its preset
/datum/loadout_item/on_equip_item(obj/item/equipped_item, list/item_details, mob/living/carbon/human/equipper, datum/outfit/outfit, visuals_only = FALSE)
	if(!ispath(reskin_datum, /datum/atom_skin/shiptest) || isnull(equipped_item))
		return ..()
	var/list/native_details = item_details?.Copy()
	if(native_details)
		native_details -= INFO_RESKIN
		native_details -= INFO_GREYSCALE
	. = ..(equipped_item, native_details, equipper, outfit, visuals_only)
	var/chosen_name = item_details?[INFO_RESKIN]
	var/saved_colors = (loadout_flags & LOADOUT_FLAG_GREYSCALING_ALLOWED) ? item_details?[INFO_GREYSCALE] : null
	if(!chosen_name && !saved_colors)
		return
	var/datum/atom_skin/chosen = shiptest_saved_style(chosen_name)
	if(chosen)
		var/list/atom_skins = get_atom_skins()
		var/datum/atom_skin/skin = atom_skins[chosen]
		skin.apply(equipped_item)
	var/obj/item/look = chosen ? chosen::greyscale_item_path : item_path
	// A new garment has no colours of its own to keep, so a design starts from its own palette
	if(look && equipped_item.greyscale_colors)
		equipped_item.set_greyscale(shiptest_palette_for_style(look, saved_colors))
	. |= equipped_item.slot_flags

// The colour editor shows the saved style, with that style's configs and channels
/datum/loadout_item/set_item_color(datum/preference_middleware/loadout/manager, mob/user)
	if(!ispath(reskin_datum, /datum/atom_skin/shiptest) || manager.menu)
		return ..()
	var/list/loadout = manager.get_current_loadout()
	var/datum/atom_skin/chosen = shiptest_saved_style(loadout?[item_path]?[INFO_RESKIN])
	var/obj/item/look = chosen ? chosen::greyscale_item_path : item_path
	if(!look || !look::greyscale_config)
		to_chat(user, span_notice("This style keeps its own colours."))
		return FALSE
	var/list/allowed_configs = list()
	for(var/config in list(look::greyscale_config, look::greyscale_config_worn, look::greyscale_config_worn_digi, look::greyscale_config_worn_vox, look::greyscale_config_inhand_left, look::greyscale_config_inhand_right))
		if(config)
			allowed_configs |= "[config]"
	var/datum/greyscale_modify_menu/menu = new(
		manager,
		user,
		allowed_configs,
		CALLBACK(src, PROC_REF(set_slot_greyscale), manager),
		starting_icon_state = look::post_init_icon_state || look::icon_state,
		starting_config = look::greyscale_config,
		starting_colors = shiptest_palette_for_style(look, loadout?[item_path]?[INFO_GREYSCALE]),
	)
	manager.register_greyscale_menu(menu)
	menu.ui_interact(user)
	return TRUE

// Track pants

/datum/atom_skin/shiptest_track_pants
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_track_pants
	greyscale_item_path = /obj/item/clothing/under/shiptest/track_pants/grey

/datum/atom_skin/shiptest_track_pants/grey
	preview_name = "track pants"
	new_name = "track pants"
	new_desc = "A pair of track pants, for the athletic."

/datum/atom_skin/shiptest_track_pants/blue
	preview_name = "blue track pants"
	new_name = "blue track pants"
	new_desc = "A pair of track pants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/track_pants/blue

/datum/atom_skin/shiptest_track_pants/pink
	preview_name = "pink track pants"
	new_name = "pink track pants"
	new_desc = "A pair of track pants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/track_pants/pink

/datum/atom_skin/shiptest_track_pants/purple
	preview_name = "purple track pants"
	new_name = "purple track pants"
	new_desc = "A pair of track pants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/track_pants/purple

/datum/atom_skin/shiptest_track_pants/red
	preview_name = "red track pants"
	new_name = "red track pants"
	new_desc = "A pair of track pants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/track_pants/red

/datum/atom_skin/shiptest_track_pants/teal
	preview_name = "teal track pants"
	new_name = "teal track pants"
	new_desc = "A pair of track pants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/track_pants/teal

/obj/item/clothing/under/shiptest/track_pants/grey/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_track_pants, TRUE)

/obj/item/clothing/under/shiptest/track_pants/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_track_pants, TRUE)

/obj/item/clothing/under/shiptest/track_pants/pink/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_track_pants, TRUE)

/obj/item/clothing/under/shiptest/track_pants/purple/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_track_pants, TRUE)

/obj/item/clothing/under/shiptest/track_pants/red/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_track_pants, TRUE)

/obj/item/clothing/under/shiptest/track_pants/teal/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_track_pants, TRUE)

// Sweatpants

/datum/atom_skin/shiptest_sweatpants
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_sweatpants
	greyscale_item_path = /obj/item/clothing/under/shiptest/sweatpants/black

/datum/atom_skin/shiptest_sweatpants/black
	preview_name = "sweatpants"
	new_name = "sweatpants"
	new_desc = "A pair of sweatpants, for the athletic."

/datum/atom_skin/shiptest_sweatpants/blue
	preview_name = "blue sweatpants"
	new_name = "blue sweatpants"
	new_desc = "A pair of sweatpants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/sweatpants/blue

/datum/atom_skin/shiptest_sweatpants/purple
	preview_name = "purple sweatpants"
	new_name = "purple sweatpants"
	new_desc = "A pair of sweatpants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/sweatpants/purple

/datum/atom_skin/shiptest_sweatpants/red
	preview_name = "red sweatpants"
	new_name = "red sweatpants"
	new_desc = "A pair of sweatpants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/sweatpants/red

/datum/atom_skin/shiptest_sweatpants/teal
	preview_name = "teal sweatpants"
	new_name = "teal sweatpants"
	new_desc = "A pair of sweatpants, for the athletic."
	greyscale_item_path = /obj/item/clothing/under/shiptest/sweatpants/teal

/obj/item/clothing/under/shiptest/sweatpants/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_sweatpants, TRUE)

/obj/item/clothing/under/shiptest/sweatpants/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_sweatpants, TRUE)

/obj/item/clothing/under/shiptest/sweatpants/purple/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_sweatpants, TRUE)

/obj/item/clothing/under/shiptest/sweatpants/red/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_sweatpants, TRUE)

/obj/item/clothing/under/shiptest/sweatpants/teal/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_sweatpants, TRUE)

// Cargo pants

/datum/atom_skin/shiptest_cargo_pants
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_cargo_pants
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_pants/grey

/datum/atom_skin/shiptest_cargo_pants/grey
	preview_name = "grey cargo pants"
	new_name = "grey cargo pants"
	new_desc = "A pocket for every need."

/datum/atom_skin/shiptest_cargo_pants/black
	preview_name = "black cargo pants"
	new_name = "black cargo pants"
	new_desc = "A pocket for every need."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_pants/black

/datum/atom_skin/shiptest_cargo_pants/brown
	preview_name = "brown cargo pants"
	new_name = "brown cargo pants"
	new_desc = "A pocket for every need."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_pants/brown

/datum/atom_skin/shiptest_cargo_pants/jean
	preview_name = "jean cargo pants"
	new_name = "jean cargo pants"
	new_desc = "A pocket for every need."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_pants/jean

/datum/atom_skin/shiptest_cargo_pants/khaki
	preview_name = "khaki cargo pants"
	new_name = "khaki cargo pants"
	new_desc = "A pocket for every need."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_pants/khaki

/datum/atom_skin/shiptest_cargo_pants/navy
	preview_name = "navy cargo pants"
	new_name = "navy cargo pants"
	new_desc = "A pocket for every need."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_pants/navy

/datum/atom_skin/shiptest_cargo_pants/olive
	preview_name = "olive cargo pants"
	new_name = "olive cargo pants"
	new_desc = "A pocket for every need."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_pants/olive

/obj/item/clothing/under/shiptest/cargo_pants/grey/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_pants, TRUE)

/obj/item/clothing/under/shiptest/cargo_pants/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_pants, TRUE)

/obj/item/clothing/under/shiptest/cargo_pants/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_pants, TRUE)

/obj/item/clothing/under/shiptest/cargo_pants/jean/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_pants, TRUE)

/obj/item/clothing/under/shiptest/cargo_pants/khaki/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_pants, TRUE)

/obj/item/clothing/under/shiptest/cargo_pants/navy/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_pants, TRUE)

/obj/item/clothing/under/shiptest/cargo_pants/olive/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_pants, TRUE)

// Athletic shorts

/datum/atom_skin/shiptest_athletic_shorts
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_athletic_shorts
	greyscale_item_path = /obj/item/clothing/under/shiptest/athletic_shorts/grey

/datum/atom_skin/shiptest_athletic_shorts/grey
	preview_name = "grey athletic shorts"
	new_name = "grey athletic shorts"
	new_desc = "95% Polyester, 5% Spandex!"

/datum/atom_skin/shiptest_athletic_shorts/black
	preview_name = "black athletic shorts"
	new_name = "black athletic shorts"
	new_desc = "95% Polyester, 5% Spandex!"
	greyscale_item_path = /obj/item/clothing/under/shiptest/athletic_shorts/black

/datum/atom_skin/shiptest_athletic_shorts/blue
	preview_name = "blue athletic shorts"
	new_name = "blue athletic shorts"
	new_desc = "95% Polyester, 5% Spandex!"
	greyscale_item_path = /obj/item/clothing/under/shiptest/athletic_shorts/blue

/datum/atom_skin/shiptest_athletic_shorts/green
	preview_name = "green athletic shorts"
	new_name = "green athletic shorts"
	new_desc = "95% Polyester, 5% Spandex!"
	greyscale_item_path = /obj/item/clothing/under/shiptest/athletic_shorts/green

/datum/atom_skin/shiptest_athletic_shorts/pink
	preview_name = "pink athletic shorts"
	new_name = "pink athletic shorts"
	new_desc = "95% Polyester, 5% Spandex!"
	greyscale_item_path = /obj/item/clothing/under/shiptest/athletic_shorts/pink

/obj/item/clothing/under/shiptest/athletic_shorts/grey/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_athletic_shorts, TRUE)

/obj/item/clothing/under/shiptest/athletic_shorts/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_athletic_shorts, TRUE)

/obj/item/clothing/under/shiptest/athletic_shorts/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_athletic_shorts, TRUE)

/obj/item/clothing/under/shiptest/athletic_shorts/green/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_athletic_shorts, TRUE)

/obj/item/clothing/under/shiptest/athletic_shorts/pink/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_athletic_shorts, TRUE)

// Cargo shorts

/datum/atom_skin/shiptest_cargo_shorts
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_cargo_shorts
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_shorts/grey

/datum/atom_skin/shiptest_cargo_shorts/grey
	preview_name = "cargo shorts"
	new_name = "cargo shorts"
	new_desc = "A pocket for every need on a hot day."

/datum/atom_skin/shiptest_cargo_shorts/brown
	preview_name = "brown cargo shorts"
	new_name = "brown cargo shorts"
	new_desc = "A pocket for every need on a hot day."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_shorts/brown

/datum/atom_skin/shiptest_cargo_shorts/jean
	preview_name = "jean cargo shorts"
	new_name = "jean cargo shorts"
	new_desc = "A pocket for every need on a hot day."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_shorts/jean

/datum/atom_skin/shiptest_cargo_shorts/olive
	preview_name = "olive cargo shorts"
	new_name = "olive cargo shorts"
	new_desc = "A pocket for every need on a hot day."
	greyscale_item_path = /obj/item/clothing/under/shiptest/cargo_shorts/olive

/obj/item/clothing/under/shiptest/cargo_shorts/grey/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_shorts, TRUE)

/obj/item/clothing/under/shiptest/cargo_shorts/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_shorts, TRUE)

/obj/item/clothing/under/shiptest/cargo_shorts/jean/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_shorts, TRUE)

/obj/item/clothing/under/shiptest/cargo_shorts/olive/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_cargo_shorts, TRUE)

// Compression shorts

/datum/atom_skin/shiptest_compression_shorts
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_compression_shorts
	greyscale_item_path = /obj/item/clothing/under/shiptest/compression_shorts/grey

/datum/atom_skin/shiptest_compression_shorts/grey
	preview_name = "compression shorts"
	new_name = "compression shorts"
	new_desc = "Short shorts made for blistering hot days and athletic use."

/datum/atom_skin/shiptest_compression_shorts/blue
	preview_name = "blue compression shorts"
	new_name = "blue compression shorts"
	new_desc = "Short shorts made for blistering hot days and athletic use."
	greyscale_item_path = /obj/item/clothing/under/shiptest/compression_shorts/blue

/datum/atom_skin/shiptest_compression_shorts/brown
	preview_name = "brown compression shorts"
	new_name = "brown compression shorts"
	new_desc = "Short shorts made for blistering hot days and athletic use."
	greyscale_item_path = /obj/item/clothing/under/shiptest/compression_shorts/brown

/obj/item/clothing/under/shiptest/compression_shorts/grey/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_compression_shorts, TRUE)

/obj/item/clothing/under/shiptest/compression_shorts/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_compression_shorts, TRUE)

/obj/item/clothing/under/shiptest/compression_shorts/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_compression_shorts, TRUE)

// Chore jackets

/datum/atom_skin/shiptest_chore_jacket
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_chore_jacket
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/white

/datum/atom_skin/shiptest_chore_jacket/white
	preview_name = "white chore jacket"
	new_name = "white chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."

/datum/atom_skin/shiptest_chore_jacket/black
	preview_name = "black chore jacket"
	new_name = "black chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/black

/datum/atom_skin/shiptest_chore_jacket/blue
	preview_name = "blue chore jacket"
	new_name = "blue chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/blue

/datum/atom_skin/shiptest_chore_jacket/brown
	preview_name = "brown chore jacket"
	new_name = "brown chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/brown

/datum/atom_skin/shiptest_chore_jacket/dark_blue
	preview_name = "dark blue chore jacket"
	new_name = "dark blue chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/dark_blue

/datum/atom_skin/shiptest_chore_jacket/dark_green
	preview_name = "dark green chore jacket"
	new_name = "dark green chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/dark_green

/datum/atom_skin/shiptest_chore_jacket/green
	preview_name = "green chore jacket"
	new_name = "green chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/green

/datum/atom_skin/shiptest_chore_jacket/grey
	preview_name = "grey chore jacket"
	new_name = "grey chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/grey

/datum/atom_skin/shiptest_chore_jacket/light_brown
	preview_name = "light brown chore jacket"
	new_name = "light brown chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/light_brown

/datum/atom_skin/shiptest_chore_jacket/maroon
	preview_name = "maroon chore jacket"
	new_name = "maroon chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/maroon

/datum/atom_skin/shiptest_chore_jacket/orange
	preview_name = "orange chore jacket"
	new_name = "orange chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/orange

/datum/atom_skin/shiptest_chore_jacket/pink
	preview_name = "pink chore jacket"
	new_name = "pink chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/pink

/datum/atom_skin/shiptest_chore_jacket/purple
	preview_name = "purple chore jacket"
	new_name = "purple chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/purple

/datum/atom_skin/shiptest_chore_jacket/red
	preview_name = "red chore jacket"
	new_name = "red chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/red

/datum/atom_skin/shiptest_chore_jacket/teal
	preview_name = "teal chore jacket"
	new_name = "teal chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/teal

/datum/atom_skin/shiptest_chore_jacket/yellow
	preview_name = "yellow chore jacket"
	new_name = "yellow chore jacket"
	new_desc = "A loose fitting jacket designed for labourers, featuring deep pockets and large buttons to enable easy access in work conditions."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/chore_jacket/yellow

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/white/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/dark_blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/dark_green/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/green/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/grey/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/light_brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/maroon/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/orange/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/pink/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/purple/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/red/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/teal/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/chore_jacket/yellow/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chore_jacket, TRUE)

// Hoodies

/datum/atom_skin/shiptest_hoodie
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_hoodie
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/hoodie/black

/datum/atom_skin/shiptest_hoodie/black
	preview_name = "black hoodie"
	new_name = "black hoodie"
	new_desc = "A hoodie that is black. It has a comfy pocket for keeping your hands warm."

/datum/atom_skin/shiptest_hoodie/blue
	preview_name = "blue hoodie"
	new_name = "blue hoodie"
	new_desc = "A hoodie that is blue. It has a comfy pocket for keeping your hands warm."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/hoodie/blue

/datum/atom_skin/shiptest_hoodie/brown
	preview_name = "brown hoodie"
	new_name = "brown hoodie"
	new_desc = "A hoodie that is brown. It has a comfy pocket for keeping your hands warm."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/hoodie/brown

/obj/item/clothing/suit/shiptest/hooded/hoodie/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_hoodie, TRUE)

/obj/item/clothing/suit/shiptest/hooded/hoodie/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_hoodie, TRUE)

/obj/item/clothing/suit/shiptest/hooded/hoodie/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_hoodie, TRUE)

// Survivor suits

/datum/atom_skin/shiptest_survivor_suit
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_survivor_suit
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/survivor_suit/grey

/datum/atom_skin/shiptest_survivor_suit/grey
	preview_name = "grey-scarfed survivor suit"
	new_name = "grey-scarfed survivor suit"
	new_desc = "A ragged makeshift suit resembling the explorer suit, covered with the emblems of a failed revolution. It's been repaired so many times it's hard to tell if it's more suit or patch. The joints have been redesigned for quicker movement."

/datum/atom_skin/shiptest_survivor_suit/brown
	preview_name = "brown-scarfed survivor suit"
	new_name = "brown-scarfed survivor suit"
	new_desc = "A ragged makeshift suit resembling the explorer suit, covered with the emblems of a failed revolution. It's been repaired so many times it's hard to tell if it's more suit or patch. The joints have been redesigned for quicker movement."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/survivor_suit/brown

/datum/atom_skin/shiptest_survivor_suit/olive
	preview_name = "olive-scarfed survivor suit"
	new_name = "olive-scarfed survivor suit"
	new_desc = "A ragged makeshift suit resembling the explorer suit, covered with the emblems of a failed revolution. It's been repaired so many times it's hard to tell if it's more suit or patch. The joints have been redesigned for quicker movement."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/survivor_suit/olive

/datum/atom_skin/shiptest_survivor_suit/blue
	preview_name = "blue-scarfed survivor suit"
	new_name = "blue-scarfed survivor suit"
	new_desc = "A ragged makeshift suit resembling the explorer suit, covered with the emblems of a failed revolution. It's been repaired so many times it's hard to tell if it's more suit or patch. The joints have been redesigned for quicker movement."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/survivor_suit/blue

/datum/atom_skin/shiptest_survivor_suit/yellow
	preview_name = "yellow-scarfed survivor suit"
	new_name = "yellow-scarfed survivor suit"
	new_desc = "A ragged makeshift suit resembling the explorer suit, covered with the emblems of a failed revolution. It's been repaired so many times it's hard to tell if it's more suit or patch. The joints have been redesigned for quicker movement."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/survivor_suit/yellow

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/grey/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_survivor_suit, TRUE)

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_survivor_suit, TRUE)

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/olive/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_survivor_suit, TRUE)

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_survivor_suit, TRUE)

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/yellow/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_survivor_suit, TRUE)

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/grey/update_slot_icon()
	shiptest_keep_hooded_state(src)
	return ..()

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/brown/update_slot_icon()
	shiptest_keep_hooded_state(src)
	return ..()

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/olive/update_slot_icon()
	shiptest_keep_hooded_state(src)
	return ..()

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/blue/update_slot_icon()
	shiptest_keep_hooded_state(src)
	return ..()

/obj/item/clothing/suit/shiptest/hooded/survivor_suit/yellow/update_slot_icon()
	shiptest_keep_hooded_state(src)
	return ..()

// Leather coats

/datum/atom_skin/shiptest_leather_coat
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_leather_coat
	greyscale_item_path = /obj/item/clothing/suit/shiptest/leather_coat/black

/datum/atom_skin/shiptest_leather_coat/black
	preview_name = "black leather coat"
	new_name = "black leather coat"
	new_desc = "A shorter, clean leather coat. Far less sturdy than others, and easier to move around in."

/datum/atom_skin/shiptest_leather_coat/brown
	preview_name = "brown leather coat"
	new_name = "brown leather coat"
	new_desc = "A shorter, clean leather coat. Far less sturdy than others, and easier to move around in."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/leather_coat/brown

/datum/atom_skin/shiptest_leather_coat/navy
	preview_name = "navy leather coat"
	new_name = "navy leather coat"
	new_desc = "A shorter, clean leather coat. Far less sturdy than others, and easier to move around in."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/leather_coat/navy

/obj/item/clothing/suit/shiptest/leather_coat/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_leather_coat, TRUE)

/obj/item/clothing/suit/shiptest/leather_coat/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_leather_coat, TRUE)

/obj/item/clothing/suit/shiptest/leather_coat/navy/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_leather_coat, TRUE)

// Flight jackets

/datum/atom_skin/shiptest_flight_jacket
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_flight_jacket
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/flight_jacket/brown

/datum/atom_skin/shiptest_flight_jacket/brown
	preview_name = "flight jacket"
	new_name = "flight jacket"
	new_desc = "A large, comfy furred coat. Typically worn by showoff pilots."

/datum/atom_skin/shiptest_flight_jacket/black
	preview_name = "black flight jacket"
	new_name = "black flight jacket"
	new_desc = "A large, comfy furred coat. Typically worn by showoff pilots."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/flight_jacket/black

/obj/item/clothing/suit/shiptest/toggle/flight_jacket/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_flight_jacket, TRUE)

/obj/item/clothing/suit/shiptest/toggle/flight_jacket/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_flight_jacket, TRUE)

// Scarves

/datum/atom_skin/shiptest_scarf
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_scarf
	greyscale_item_path = /obj/item/clothing/neck/shiptest/scarf/black

/datum/atom_skin/shiptest_scarf/black
	preview_name = "black scarf"
	new_name = "black scarf"
	new_desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."

/datum/atom_skin/shiptest_scarf/blue
	preview_name = "blue scarf"
	new_name = "blue scarf"
	new_desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/scarf/blue

/datum/atom_skin/shiptest_scarf/brown
	preview_name = "brown scarf"
	new_name = "brown scarf"
	new_desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/scarf/brown

/datum/atom_skin/shiptest_scarf/dark_blue
	preview_name = "dark blue scarf"
	new_name = "dark blue scarf"
	new_desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/scarf/dark_blue

/datum/atom_skin/shiptest_scarf/dark_green
	preview_name = "dark green scarf"
	new_name = "dark green scarf"
	new_desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/scarf/dark_green

/obj/item/clothing/neck/shiptest/scarf/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_scarf, TRUE)

/obj/item/clothing/neck/shiptest/scarf/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_scarf, TRUE)

/obj/item/clothing/neck/shiptest/scarf/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_scarf, TRUE)

/obj/item/clothing/neck/shiptest/scarf/dark_blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_scarf, TRUE)

/obj/item/clothing/neck/shiptest/scarf/dark_green/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_scarf, TRUE)

// Ponchos

/datum/atom_skin/shiptest_poncho
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_poncho
	greyscale_item_path = /obj/item/clothing/neck/shiptest/poncho/black

/datum/atom_skin/shiptest_poncho/black
	preview_name = "black poncho"
	new_name = "black poncho"
	new_desc = "Perfect for a rainy night with jazz."

/datum/atom_skin/shiptest_poncho/blue
	preview_name = "blue poncho"
	new_name = "blue poncho"
	new_desc = "Perfect for a rainy night with jazz."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/poncho/blue

/datum/atom_skin/shiptest_poncho/brown
	preview_name = "brown poncho"
	new_name = "brown poncho"
	new_desc = "Perfect for a rainy night with jazz."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/poncho/brown

/datum/atom_skin/shiptest_poncho/dark_blue
	preview_name = "dark blue poncho"
	new_name = "dark blue poncho"
	new_desc = "Perfect for a rainy night with jazz."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/poncho/dark_blue

/datum/atom_skin/shiptest_poncho/dark_green
	preview_name = "dark green poncho"
	new_name = "dark green poncho"
	new_desc = "Perfect for a rainy night with jazz."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/poncho/dark_green

/obj/item/clothing/neck/shiptest/poncho/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_poncho, TRUE)

// Neckwraps

/datum/atom_skin/shiptest_neckwraps
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_neckwraps
	greyscale_item_path = /obj/item/clothing/neck/shiptest/neckwraps/black

/datum/atom_skin/shiptest_neckwraps/black
	preview_name = "black neckwraps"
	new_name = "black neckwraps"
	new_desc = "A fashionable piece of cloth cover your neck."

/datum/atom_skin/shiptest_neckwraps/blue
	preview_name = "blue neckwraps"
	new_name = "blue neckwraps"
	new_desc = "A fashionable piece of cloth cover your neck."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/neckwraps/blue

/datum/atom_skin/shiptest_neckwraps/brown
	preview_name = "brown neckwraps"
	new_name = "brown neckwraps"
	new_desc = "A fashionable piece of cloth cover your neck."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/neckwraps/brown

/obj/item/clothing/neck/shiptest/neckwraps/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_neckwraps, TRUE)

// Mantles

/datum/atom_skin/shiptest_mantle
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_mantle
	greyscale_item_path = /obj/item/clothing/neck/shiptest/mantle/black

/datum/atom_skin/shiptest_mantle/black
	preview_name = "black mantle"
	new_name = "black mantle"
	new_desc = "A big mantle for big shoulders."

/datum/atom_skin/shiptest_mantle/desert
	preview_name = "desert mantle"
	new_name = "desert mantle"
	new_desc = "A big mantle for big shoulders."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/mantle/desert

/obj/item/clothing/neck/shiptest/mantle/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_mantle, TRUE)

// Shemaghs

/datum/atom_skin/shiptest_shemagh
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_shemagh
	greyscale_item_path = /obj/item/clothing/neck/shiptest/shemagh/red

/datum/atom_skin/shiptest_shemagh/red
	preview_name = "red shemagh"
	new_name = "red shemagh"
	new_desc = "An oversized shemagh in blood red."

/datum/atom_skin/shiptest_shemagh/maroon
	preview_name = "maroon shemagh"
	new_name = "maroon shemagh"
	new_desc = "An oversized shemagh, in a dark maroon."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/shemagh/maroon

/obj/item/clothing/neck/shiptest/shemagh/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_shemagh, TRUE)

// Skirts

/datum/atom_skin/shiptest_skirt
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_skirt
	greyscale_item_path = /obj/item/clothing/under/shiptest/skirt/black

/datum/atom_skin/shiptest_skirt/black
	preview_name = "black skirt"
	new_name = "black skirt"
	new_desc = "A black, casual skirt."

/datum/atom_skin/shiptest_skirt/blue
	preview_name = "blue skirt"
	new_name = "blue skirt"
	new_desc = "A blue, casual skirt."
	greyscale_item_path = /obj/item/clothing/under/shiptest/skirt/blue

/datum/atom_skin/shiptest_skirt/purple
	preview_name = "purple skirt"
	new_name = "purple skirt"
	new_desc = "A purple, casual skirt."
	greyscale_item_path = /obj/item/clothing/under/shiptest/skirt/purple

/datum/atom_skin/shiptest_skirt/red
	preview_name = "red skirt"
	new_name = "red skirt"
	new_desc = "A red, casual skirt."
	greyscale_item_path = /obj/item/clothing/under/shiptest/skirt/red

/obj/item/clothing/under/shiptest/skirt/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_skirt, TRUE)

/obj/item/clothing/under/shiptest/skirt/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_skirt, TRUE)

/obj/item/clothing/under/shiptest/skirt/purple/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_skirt, TRUE)

/obj/item/clothing/under/shiptest/skirt/red/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_skirt, TRUE)

// Pinafores

/datum/atom_skin/shiptest_pinafore
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_pinafore
	greyscale_item_path = /obj/item/clothing/under/shiptest/pinafore/black

/datum/atom_skin/shiptest_pinafore/black
	preview_name = "black pinafore"
	new_name = "black pinafore"
	new_desc = "It's really just an apron that one wears over a shirt or dress. This one is black."

/datum/atom_skin/shiptest_pinafore/cerulean
	preview_name = "cerulean pinafore"
	new_name = "cerulean pinafore"
	new_desc = "It's really just an apron that one wears over a shirt or dress. This one is cerulean."
	greyscale_item_path = /obj/item/clothing/under/shiptest/pinafore/cerulean

/datum/atom_skin/shiptest_pinafore/maroon
	preview_name = "maroon pinafore"
	new_name = "maroon pinafore"
	new_desc = "It's really just an apron that one wears over a shirt or dress. This one is maroon."
	greyscale_item_path = /obj/item/clothing/under/shiptest/pinafore/maroon

/obj/item/clothing/under/shiptest/pinafore/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_pinafore, TRUE)

/obj/item/clothing/under/shiptest/pinafore/cerulean/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_pinafore, TRUE)

/obj/item/clothing/under/shiptest/pinafore/maroon/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_pinafore, TRUE)

// Plaid pinafores

/datum/atom_skin/shiptest_plaid_pinafore
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_plaid_pinafore
	greyscale_item_path = /obj/item/clothing/under/shiptest/plaid_pinafore/red

/datum/atom_skin/shiptest_plaid_pinafore/red
	preview_name = "red plaid pinafore"
	new_name = "red plaid pinafore"
	new_desc = "It's really just an apron that one wears over a shirt or dress. This one is in red plaid."

/datum/atom_skin/shiptest_plaid_pinafore/brown
	preview_name = "brown plaid pinafore"
	new_name = "brown plaid pinafore"
	new_desc = "It's really just an apron that one wears over a shirt or dress. This one is in brown plaid."
	greyscale_item_path = /obj/item/clothing/under/shiptest/plaid_pinafore/brown

/datum/atom_skin/shiptest_plaid_pinafore/green
	preview_name = "green plaid pinafore"
	new_name = "green plaid pinafore"
	new_desc = "It's really just an apron that one wears over a shirt or dress. This one is in green plaid."
	greyscale_item_path = /obj/item/clothing/under/shiptest/plaid_pinafore/green

/obj/item/clothing/under/shiptest/plaid_pinafore/red/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_plaid_pinafore, TRUE)

/obj/item/clothing/under/shiptest/plaid_pinafore/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_plaid_pinafore, TRUE)

/obj/item/clothing/under/shiptest/plaid_pinafore/green/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_plaid_pinafore, TRUE)

// Floral shirts

/datum/atom_skin/shiptest_floral_shirt
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_floral_shirt
	greyscale_item_path = /obj/item/clothing/suit/shiptest/floral_shirt/blue

/datum/atom_skin/shiptest_floral_shirt/blue
	preview_name = "blue floral shirt"
	new_name = "blue floral shirt"
	new_desc = "From grills to guns, this shirt's seen it all."

/datum/atom_skin/shiptest_floral_shirt/pink
	preview_name = "pink floral shirt"
	new_name = "pink floral shirt"
	new_desc = "From grills to guns, this shirt's seen it all."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/floral_shirt/pink

/datum/atom_skin/shiptest_floral_shirt/red
	preview_name = "red floral shirt"
	new_name = "red floral shirt"
	new_desc = "From grills to guns, this shirt's seen it all."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/floral_shirt/red

/obj/item/clothing/suit/shiptest/floral_shirt/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_floral_shirt, TRUE)

/obj/item/clothing/suit/shiptest/floral_shirt/pink/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_floral_shirt, TRUE)

/obj/item/clothing/suit/shiptest/floral_shirt/red/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_floral_shirt, TRUE)

// Pajama pants

/datum/atom_skin/shiptest_pajama_pants
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_pajama_pants
	greyscale_item_path = /obj/item/clothing/under/shiptest/pajama_pants/blue

/datum/atom_skin/shiptest_pajama_pants/blue
	preview_name = "blue pajama pants"
	new_name = "blue pajama pants"
	new_desc = "A comfy pair of pajamas. Probably not the best for work attire."

/datum/atom_skin/shiptest_pajama_pants/green
	preview_name = "green pajama pants"
	new_name = "green pajama pants"
	new_desc = "A comfy pair of pajamas. Probably not the best for work attire."
	greyscale_item_path = /obj/item/clothing/under/shiptest/pajama_pants/green

/obj/item/clothing/under/shiptest/pajama_pants/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_pajama_pants, TRUE)

/obj/item/clothing/under/shiptest/pajama_pants/green/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_pajama_pants, TRUE)

// Suspenders

/datum/atom_skin/shiptest_suspenders
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_suspenders
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/suspenders/blue

/datum/atom_skin/shiptest_suspenders/blue
	preview_name = "blue suspenders"
	new_name = "blue suspenders"
	new_desc = "The symbol of hard labor and dirty jobs."

/datum/atom_skin/shiptest_suspenders/gray
	preview_name = "gray suspenders"
	new_name = "gray suspenders"
	new_desc = "The symbol of hard labor and dirty jobs."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/suspenders/gray

/obj/item/clothing/suit/shiptest/toggle/suspenders/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_suspenders, TRUE)

/obj/item/clothing/suit/shiptest/toggle/suspenders/gray/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_suspenders, TRUE)

// Rank capes

/datum/atom_skin/shiptest_rank_cape
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_rank_cape
	greyscale_item_path = /obj/item/clothing/neck/shiptest/cloak/rank_cape/command

/datum/atom_skin/shiptest_rank_cape/command
	preview_name = "command rank cape"
	new_name = "command rank cape"
	new_desc = "A flowing black cape with an officer's insignia."

/datum/atom_skin/shiptest_rank_cape/engineering
	preview_name = "engineering rank cape"
	new_name = "engineering rank cape"
	new_desc = "A flowing black cape with an engineering insignia."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/cloak/rank_cape/engineering

/obj/item/clothing/neck/shiptest/cloak/rank_cape/command/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_rank_cape, TRUE)

/obj/item/clothing/neck/shiptest/cloak/rank_cape/engineering/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_rank_cape, TRUE)

// Rank shoulder capes

/datum/atom_skin/shiptest_rank_shoulder_cape
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_rank_shoulder_cape
	greyscale_item_path = /obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/command

/datum/atom_skin/shiptest_rank_shoulder_cape/command
	preview_name = "command rank shoulder cape"
	new_name = "command rank shoulder cape"
	new_desc = "A flowing black cape with an officer's insignia."

/datum/atom_skin/shiptest_rank_shoulder_cape/engineering
	preview_name = "engineering rank shoulder cape"
	new_name = "engineering rank shoulder cape"
	new_desc = "A flowing black cape with an engineering insignia."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/engineering

/datum/atom_skin/shiptest_rank_shoulder_cape/medic
	preview_name = "medic rank shoulder cape"
	new_name = "medic rank shoulder cape"
	new_desc = "A flowing black cape with a medical insignia."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/medic

/datum/atom_skin/shiptest_rank_shoulder_cape/captain
	preview_name = "captain's rank shoulder cape"
	new_name = "captain's rank shoulder cape"
	new_desc = "A flowing black cape with a captain's insignia."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/captain

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/command/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_rank_shoulder_cape, TRUE)

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/engineering/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_rank_shoulder_cape, TRUE)

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/medic/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_rank_shoulder_cape, TRUE)

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/captain/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_rank_shoulder_cape, TRUE)

// Black rank capes, both cuts - designs, which keep the wearer's colours

/datum/atom_skin/shiptest_black_rank_cape
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_black_rank_cape
	greyscale_item_path = /obj/item/clothing/neck/shiptest/cloak/rank_cape/black
	preserve_palette = TRUE

/datum/atom_skin/shiptest_black_rank_cape/rank_cape
	preview_name = "black rank cape"
	new_name = "black rank cape"
	new_desc = "A flowing black cape with a military cut."

/datum/atom_skin/shiptest_black_rank_cape/rank_shoulder_cape
	preview_name = "black rank shoulder cape"
	new_name = "black rank shoulder cape"
	new_desc = "A folded black cape draped across one shoulder."
	greyscale_item_path = /obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/black

/obj/item/clothing/neck/shiptest/cloak/rank_cape/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_black_rank_cape, TRUE)

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_black_rank_cape, TRUE)

// Its own garment, without this family's styles
/obj/item/clothing/neck/shiptest/cloak/rank_cape/captain/setup_reskins()
	return

// Its own garment, without this family's styles
/obj/item/clothing/neck/shiptest/cloak/rank_cape/medic/setup_reskins()
	return

// Safety goggles - designs, which keep the wearer's colours

/datum/atom_skin/shiptest_safety_goggles
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_safety_goggles
	greyscale_item_path = /obj/item/clothing/glasses/shiptest/safety_goggles/skier
	preserve_palette = TRUE

/datum/atom_skin/shiptest_safety_goggles/skier
	preview_name = "safety goggles"
	new_name = "safety goggles"
	new_desc = "A pair of costume goggles with a broad, wraparound lens."

/datum/atom_skin/shiptest_safety_goggles/biker
	preview_name = "safety goggles (biker)"
	new_name = "safety goggles (biker)"
	new_desc = "A pair of costume goggles with a broad, wraparound lens."
	greyscale_item_path = /obj/item/clothing/glasses/shiptest/safety_goggles/biker

/obj/item/clothing/glasses/shiptest/safety_goggles/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_safety_goggles, TRUE)

// Tactical webbing

/datum/atom_skin/shiptest_tactical_webbing
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_tactical_webbing
	greyscale_item_path = /obj/item/storage/belt/shiptest/tactical_webbing/crimson

/datum/atom_skin/shiptest_tactical_webbing/crimson
	preview_name = "crimson tactical webbing"
	new_name = "crimson tactical webbing"
	new_desc = "Crimson tactical webbing with pale straps and small storage pouches."

/datum/atom_skin/shiptest_tactical_webbing/white
	preview_name = "white tactical webbing"
	new_name = "white tactical webbing"
	new_desc = "A set of white tactical webbing with small storage pouches."
	greyscale_item_path = null
	new_icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	new_icon_state = "tactical_webbing_white"

/datum/atom_skin/shiptest_tactical_webbing/orange_trimmed
	preview_name = "orange-trimmed tactical webbing"
	new_name = "orange-trimmed tactical webbing"
	new_desc = "A set of tactical webbing with orange trim and small storage pouches."
	greyscale_item_path = null
	new_icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	new_icon_state = "tactical_webbing_orange_trimmed"

/datum/atom_skin/shiptest_tactical_webbing/red_trimmed
	preview_name = "red-trimmed tactical webbing"
	new_name = "red-trimmed tactical webbing"
	new_desc = "Black webbing with red trim and small storage pouches."
	greyscale_item_path = null
	new_icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	new_icon_state = "tactical_webbing_red_trimmed"

/obj/item/storage/belt/shiptest/tactical_webbing/crimson/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_tactical_webbing, TRUE)

/obj/item/storage/belt/shiptest/tactical_webbing/white/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_tactical_webbing, TRUE)

/obj/item/storage/belt/shiptest/tactical_webbing/orange_trimmed/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_tactical_webbing, TRUE)

/obj/item/storage/belt/shiptest/tactical_webbing/red_trimmed/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_tactical_webbing, TRUE)

// Drop pouch harnesses

/datum/atom_skin/shiptest_drop_pouch_harness
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_drop_pouch_harness
	greyscale_item_path = /obj/item/storage/belt/shiptest/drop_pouch_harness/black_and_tan

/datum/atom_skin/shiptest_drop_pouch_harness/black_and_tan
	preview_name = "black and tan drop pouch harness"
	new_name = "black and tan drop pouch harness"
	new_desc = "A black harness with small tan pouches."

/datum/atom_skin/shiptest_drop_pouch_harness/tan
	preview_name = "tan drop pouch harness"
	new_name = "tan drop pouch harness"
	new_desc = "A tan harness with small storage pouches."
	greyscale_item_path = /obj/item/storage/belt/shiptest/drop_pouch_harness/tan

/obj/item/storage/belt/shiptest/drop_pouch_harness/black_and_tan/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_drop_pouch_harness, TRUE)

/obj/item/storage/belt/shiptest/drop_pouch_harness/tan/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_drop_pouch_harness, TRUE)

// Chest rigs - designs, which keep the wearer's colours

/datum/atom_skin/shiptest_chest_rig
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_chest_rig
	greyscale_item_path = /obj/item/storage/belt/shiptest/chest_rig/blue
	preserve_palette = TRUE

/datum/atom_skin/shiptest_chest_rig/chest_rig
	preview_name = "blue chest rig"
	new_name = "blue chest rig"
	new_desc = "A blue chest rig with rows of bulky pouches."

/datum/atom_skin/shiptest_chest_rig/belt_rig
	preview_name = "blue belt rig"
	new_name = "blue belt rig"
	new_desc = "A blue belt rig with rows of bulky pouches."
	greyscale_item_path = /obj/item/storage/belt/shiptest/belt_rig/blue

/obj/item/storage/belt/shiptest/chest_rig/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chest_rig, TRUE)

/obj/item/storage/belt/shiptest/belt_rig/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_chest_rig, TRUE)

// Segmented armor vests

/datum/atom_skin/shiptest_segmented_armor_vest
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_segmented_armor_vest
	greyscale_item_path = /obj/item/clothing/suit/shiptest/segmented_armor_vest/white

/datum/atom_skin/shiptest_segmented_armor_vest/white
	preview_name = "replica white segmented armor vest"
	new_name = "replica white segmented armor vest"
	new_desc = "A costume version of a white segmented armor vest. Its decorative panels provide no armor protection."

/datum/atom_skin/shiptest_segmented_armor_vest/teal
	preview_name = "replica teal segmented armor vest"
	new_name = "replica teal segmented armor vest"
	new_desc = "A costume version of a teal segmented armor vest. Its decorative panels provide no armor protection."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/segmented_armor_vest/teal

/datum/atom_skin/shiptest_segmented_armor_vest/crimson
	preview_name = "replica crimson segmented armor vest"
	new_name = "replica crimson segmented armor vest"
	new_desc = "A costume version of a crimson segmented armor vest. Its decorative panels provide no armor protection."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/segmented_armor_vest/crimson

/obj/item/clothing/suit/shiptest/segmented_armor_vest/white/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_segmented_armor_vest, TRUE)

/obj/item/clothing/suit/shiptest/segmented_armor_vest/teal/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_segmented_armor_vest, TRUE)

/obj/item/clothing/suit/shiptest/segmented_armor_vest/crimson/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_segmented_armor_vest, TRUE)

// Medical armor vests

/datum/atom_skin/shiptest_medical_armor_vest
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_medical_armor_vest
	greyscale_item_path = /obj/item/clothing/suit/shiptest/medical_armor_vest/white

/datum/atom_skin/shiptest_medical_armor_vest/white
	preview_name = "replica white medical armor vest"
	new_name = "replica white medical armor vest"
	new_desc = "A costume version of a white medical armor vest. Its decorative panels provide no armor protection."

/datum/atom_skin/shiptest_medical_armor_vest/teal
	preview_name = "replica teal medical armor vest"
	new_name = "replica teal medical armor vest"
	new_desc = "A costume version of a teal medical armor vest. Its decorative panels provide no armor protection."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/medical_armor_vest/teal

/datum/atom_skin/shiptest_medical_armor_vest/crimson
	preview_name = "replica crimson armor vest"
	new_name = "replica crimson armor vest"
	new_desc = "A costume version of a crimson armor vest. Its decorative panels provide no armor protection."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/medical_armor_vest/crimson

/obj/item/clothing/suit/shiptest/medical_armor_vest/white/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_medical_armor_vest, TRUE)

/obj/item/clothing/suit/shiptest/medical_armor_vest/teal/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_medical_armor_vest, TRUE)

/obj/item/clothing/suit/shiptest/medical_armor_vest/crimson/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_medical_armor_vest, TRUE)

// Light combat vests

/datum/atom_skin/shiptest_light_combat_vest
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_light_combat_vest
	greyscale_item_path = /obj/item/clothing/suit/shiptest/light_combat_vest/white

/datum/atom_skin/shiptest_light_combat_vest/white
	preview_name = "replica white light combat vest"
	new_name = "replica white light combat vest"
	new_desc = "A costume version of a white light combat vest. Its decorative panels provide no armor protection."

/datum/atom_skin/shiptest_light_combat_vest/teal
	preview_name = "replica teal light combat vest"
	new_name = "replica teal light combat vest"
	new_desc = "A costume version of a teal light combat vest. Its decorative panels provide no armor protection."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/light_combat_vest/teal

/datum/atom_skin/shiptest_light_combat_vest/crimson
	preview_name = "replica crimson light combat vest"
	new_name = "replica crimson light combat vest"
	new_desc = "A costume version of a crimson light combat vest. Its decorative panels provide no armor protection."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/light_combat_vest/crimson

/obj/item/clothing/suit/shiptest/light_combat_vest/white/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_light_combat_vest, TRUE)

/obj/item/clothing/suit/shiptest/light_combat_vest/teal/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_light_combat_vest, TRUE)

/obj/item/clothing/suit/shiptest/light_combat_vest/crimson/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_light_combat_vest, TRUE)

// Combat suits

/datum/atom_skin/shiptest_combat_suit
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_combat_suit
	greyscale_item_path = /obj/item/clothing/suit/shiptest/combat_suit/white

/datum/atom_skin/shiptest_combat_suit/white
	preview_name = "replica white combat suit"
	new_name = "replica white combat suit"
	new_desc = "A costume version of a white combat suit. Its decorative panels provide no armor protection."

/datum/atom_skin/shiptest_combat_suit/teal
	preview_name = "replica teal combat suit"
	new_name = "replica teal combat suit"
	new_desc = "A costume version of a teal combat suit. Its decorative panels provide no armor protection."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/combat_suit/teal

/obj/item/clothing/suit/shiptest/combat_suit/white/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_combat_suit, TRUE)

/obj/item/clothing/suit/shiptest/combat_suit/teal/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_combat_suit, TRUE)

// Winter coats - designs, which keep the wearer's colours

/datum/atom_skin/shiptest_winter_coat
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_winter_coat
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/winter_coat/brown
	preserve_palette = TRUE

/datum/atom_skin/shiptest_winter_coat/brown
	preview_name = "brown winter coat"
	new_name = "brown winter coat"
	new_desc = "An armored wintercoat with a golden shield for its zipper tab."

/datum/atom_skin/shiptest_winter_coat/brown_hooded
	preview_name = "brown hooded coat"
	new_name = "brown hooded coat"
	new_desc = "A hooded coat with a fur trim around the hood, comfy! It has a small emblem embroidered onto the shoulder."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hooded/winter_coat/brown_hooded

/obj/item/clothing/suit/shiptest/hooded/winter_coat/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_winter_coat, TRUE)

/obj/item/clothing/suit/shiptest/hooded/winter_coat/brown_hooded/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_winter_coat, TRUE)

/obj/item/clothing/suit/shiptest/hooded/winter_coat/brown/update_slot_icon()
	shiptest_keep_hooded_state(src)
	return ..()

/obj/item/clothing/suit/shiptest/hooded/winter_coat/brown_hooded/update_slot_icon()
	shiptest_keep_hooded_state(src)
	return ..()

// Trenchcoats

/datum/atom_skin/shiptest_trenchcoat
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_trenchcoat
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/trenchcoat/tan

/datum/atom_skin/shiptest_trenchcoat/tan
	preview_name = "heavy trenchcoat"
	new_name = "heavy trenchcoat"
	new_desc = "A heavy coat made from durable fabrics."

/datum/atom_skin/shiptest_trenchcoat/navy
	preview_name = "heavy navy trenchcoat"
	new_name = "heavy navy trenchcoat"
	new_desc = "A hard-boiled private investigator's grey trenchcoat."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/toggle/trenchcoat/navy

/obj/item/clothing/suit/shiptest/toggle/trenchcoat/tan/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_trenchcoat, TRUE)

/obj/item/clothing/suit/shiptest/toggle/trenchcoat/navy/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_trenchcoat, TRUE)

// Its own garment, without this family's styles
/obj/item/clothing/suit/shiptest/toggle/trenchcoat/deaf_mute/setup_reskins()
	return

// Its own garment, without this family's styles
/obj/item/clothing/suit/shiptest/toggle/trenchcoat/fur_collared_black/setup_reskins()
	return

// Pride ties

/datum/atom_skin/shiptest_pride_tie
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_pride_tie

/datum/atom_skin/shiptest_pride_tie/ally
	preview_name = "ally tie"
	new_name = "ally tie"
	new_desc = "A neosilk clip-on tie. This one is in the colors of the ally flag."
	new_icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	new_icon_state = "pride_tie_ally"

/datum/atom_skin/shiptest_pride_tie/asexual
	preview_name = "asexual tie"
	new_name = "asexual tie"
	new_desc = "A neosilk clip-on tie. This one is in the colors of the asexual flag."
	new_icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	new_icon_state = "pride_tie_asexual"

/datum/atom_skin/shiptest_pride_tie/bisexual
	preview_name = "bisexual tie"
	new_name = "bisexual tie"
	new_desc = "A neosilk clip-on tie. This one is in the colors of the bisexual flag."
	new_icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	new_icon_state = "pride_tie_bisexual"

/obj/item/clothing/neck/shiptest/pride_tie/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_pride_tie, TRUE)

// Tinted goggles

/datum/atom_skin/shiptest_tinted_goggles
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_tinted_goggles
	greyscale_item_path = /obj/item/clothing/glasses/shiptest/tinted_goggles/red

/datum/atom_skin/shiptest_tinted_goggles/red
	preview_name = "red-tinted goggles"
	new_name = "red-tinted goggles"
	new_desc = "Decorative red-tinted goggles with a broad wraparound lens."

/datum/atom_skin/shiptest_tinted_goggles/green
	preview_name = "green-tinted goggles"
	new_name = "green-tinted goggles"
	new_desc = "Decorative green-tinted goggles with a broad wraparound lens."
	greyscale_item_path = /obj/item/clothing/glasses/shiptest/tinted_goggles/green

/obj/item/clothing/glasses/shiptest/tinted_goggles/red/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_tinted_goggles, TRUE)

/obj/item/clothing/glasses/shiptest/tinted_goggles/green/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_tinted_goggles, TRUE)

// Ballistic goggles

/datum/atom_skin/shiptest_ballistic_goggles
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_ballistic_goggles
	greyscale_item_path = /obj/item/clothing/glasses/shiptest/ballistic_goggles/orange

/datum/atom_skin/shiptest_ballistic_goggles/orange
	preview_name = "orange-tinted goggles"
	new_name = "orange-tinted goggles"
	new_desc = "Decorative orange-tinted goggles with a broad wraparound lens."

/datum/atom_skin/shiptest_ballistic_goggles/amber
	preview_name = "ballistic goggles"
	new_name = "ballistic goggles"
	new_desc = "Decorative eyewear styled after ballistic goggles."
	greyscale_item_path = /obj/item/clothing/glasses/shiptest/ballistic_goggles/amber

/obj/item/clothing/glasses/shiptest/ballistic_goggles/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_ballistic_goggles, TRUE)

// Balaclavas

/datum/atom_skin/shiptest_balaclava
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_balaclava
	greyscale_item_path = /obj/item/clothing/mask/shiptest/balaclava/combat

/datum/atom_skin/shiptest_balaclava/combat
	preview_name = "combat balaclava"
	new_name = "combat balaclava"
	new_desc = "A comfortable fabric balaclava with a decorative mouthpiece."

/datum/atom_skin/shiptest_balaclava/ribbed_black
	preview_name = "ribbed black balaclava"
	new_name = "ribbed black balaclava"
	new_desc = "A comfortable fabric balaclava with a decorative mouthpiece."
	greyscale_item_path = /obj/item/clothing/mask/shiptest/balaclava/ribbed_black

/obj/item/clothing/mask/shiptest/balaclava/combat/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_balaclava, TRUE)

/obj/item/clothing/mask/shiptest/balaclava/ribbed_black/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_balaclava, TRUE)

// Composite respirators

/datum/atom_skin/shiptest_composite_respirator
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_composite_respirator
	greyscale_item_path = /obj/item/clothing/mask/shiptest/breath/composite_respirator/olive

/datum/atom_skin/shiptest_composite_respirator/olive
	preview_name = "olive composite respirator replica"
	new_name = "olive composite respirator replica"
	new_desc = "A costume replica of an olive composite respirator, with decorative fittings."

/datum/atom_skin/shiptest_composite_respirator/blue
	preview_name = "blue composite respirator replica"
	new_name = "blue composite respirator replica"
	new_desc = "A costume replica of a blue composite respirator, with decorative fittings."
	greyscale_item_path = /obj/item/clothing/mask/shiptest/breath/composite_respirator/blue

/obj/item/clothing/mask/shiptest/breath/composite_respirator/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_composite_respirator, TRUE)

// Surgical smocks

/datum/atom_skin/shiptest_surgical_smock
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_surgical_smock
	greyscale_item_path = /obj/item/clothing/suit/shiptest/surgical_smock/cream

/datum/atom_skin/shiptest_surgical_smock/cream
	preview_name = "cream surgical smock"
	new_name = "cream surgical smock"
	new_desc = "A cream surgical smock with overlapping fabric panels."

/datum/atom_skin/shiptest_surgical_smock/blue
	preview_name = "surgical smock"
	new_name = "surgical smock"
	new_desc = "A thick blue surgical smock with a smooth, fluid-repelling finish."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/surgical_smock/blue

/obj/item/clothing/suit/shiptest/surgical_smock/cream/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_surgical_smock, TRUE)

/obj/item/clothing/suit/shiptest/surgical_smock/blue/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_surgical_smock, TRUE)

// Hazard vests

/datum/atom_skin/shiptest_hazard_vest
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_hazard_vest
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hazard_vest/white

/datum/atom_skin/shiptest_hazard_vest/white
	preview_name = "white hazard vest"
	new_name = "white hazard vest"
	new_desc = "A white high-visibility work vest. Safety first!"

/datum/atom_skin/shiptest_hazard_vest/blood_red
	preview_name = "blood-red hazard vest"
	new_name = "blood-red hazard vest"
	new_desc = "A blood-red high-visibility work vest."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/hazard_vest/blood_red

/obj/item/clothing/suit/shiptest/hazard_vest/white/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_hazard_vest, TRUE)

/obj/item/clothing/suit/shiptest/hazard_vest/blood_red/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_hazard_vest, TRUE)

// Leather dusters

/datum/atom_skin/shiptest_leather_duster
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_leather_duster
	greyscale_item_path = /obj/item/clothing/suit/shiptest/leather_duster/brown

/datum/atom_skin/shiptest_leather_duster/brown
	preview_name = "leather duster"
	new_name = "leather duster"
	new_desc = "A long, utilitarian leather coat. Ideal for protecting its wearer from rain, sun, and dust."

/datum/atom_skin/shiptest_leather_duster/officer
	preview_name = "officer's duster"
	new_name = "officer's duster"
	new_desc = "A long, supple leather coat. Ideal for protecting its wearer from rain, sun, dust, and paperwork."
	greyscale_item_path = /obj/item/clothing/suit/shiptest/leather_duster/officer

/obj/item/clothing/suit/shiptest/leather_duster/brown/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_leather_duster, TRUE)

/obj/item/clothing/suit/shiptest/leather_duster/officer/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_leather_duster, TRUE)

// Leather bandoliers

/datum/atom_skin/shiptest_leather_bandolier
	parent_type = /datum/atom_skin/shiptest
	abstract_type = /datum/atom_skin/shiptest_leather_bandolier
	greyscale_item_path = /obj/item/storage/belt/shiptest/leather_bandolier/medical

/datum/atom_skin/shiptest_leather_bandolier/medical
	preview_name = "leather medical bandolier"
	new_name = "leather medical bandolier"
	new_desc = "A rudimentary leather bandolier painted white and fitted with small pouches."

/datum/atom_skin/shiptest_leather_bandolier/plain
	preview_name = "leather bandolier"
	new_name = "leather bandolier"
	new_desc = "A rudimentary leather bandolier slung diagonally from shoulder to waist."
	greyscale_item_path = /obj/item/storage/belt/shiptest/leather_bandolier/plain

/obj/item/storage/belt/shiptest/leather_bandolier/medical/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_leather_bandolier, TRUE)

/obj/item/storage/belt/shiptest/leather_bandolier/plain/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/shiptest_leather_bandolier, TRUE)
