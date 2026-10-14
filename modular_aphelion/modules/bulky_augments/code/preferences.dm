/**
 * Loads the augment colours from a save: each slot's colour string, kept only where the slot's finish is recolourable and the
 * string is valid. A bad, stale or hand-edited entry is dropped, never drawn.
 *
 * Arguments:
 * - save_data: The character's save data, its augment_limb_styles already loaded.
 */
/datum/preferences/proc/load_augment_colors(list/save_data)
	augment_limb_colors = list()
	var/list/styles = SANITIZE_LIST(save_data["augment_limb_styles"])
	for(var/slot, colors in SANITIZE_LIST(save_data["augment_limb_colors"]))
		var/clean = sanitize_augment_colors(colors)
		if(clean && istype(GLOB.robotic_styles_list[styles[slot]], /datum/robotic_style/recolorable))
			augment_limb_colors[slot] = clean

/**
 * The recolourable finishes' colours in character setup: their finishes and presets sent once with the rest of the constant
 * data, with the brand styles the finish picker tries on, each slot's colours, and the editor's two actions, each answered
 * with the colours alone. The preview's skin follows the preview mob as it is rebuilt (add_preview_answer()). The brand
 * styles' try-on sprites are sent only when the window asks for them (send_augment_brand_sprites()).
 */
/datum/preference_middleware/augment_paint
	action_delegations = list(
		"set_augment_colors" = PROC_REF(set_augment_colors),
		"copy_augment_colors" = PROC_REF(copy_augment_colors),
		"augment_brand_sprites" = PROC_REF(send_augment_brand_sprites),
	)
	/// The preview skin the page last got, as colour and ramp run together, so an answer sends it only when it changed.
	var/sent_skin

/**
 * Returns what the editor reads of every recolourable finish, by name, sent once with the rest of the constant data: its id,
 * its channels and their labels, its default and presets, and which zones its paint sheet has _paint and _glow states for;
 * the editor's quick swatches; and for the finish picker's try-on, every brand style's key and the zones it has sprites for,
 * by name (augment_brand_states()).
 */
/datum/preference_middleware/augment_paint/get_constant_data()
	var/list/finishes = list()
	var/list/brands = list()
	for(var/style_name, style in GLOB.robotic_styles_list)
		var/datum/robotic_style/recolorable/finish = style
		if(!istype(finish))
			var/datum/robotic_style/brand = style
			var/list/states = brand.augment_brand_states()
			if(length(states))
				brands[style_name] = list("key" = brand.augment_brand_key(), "zones" = assoc_to_keys(states))
			continue
		var/list/channels = list()
		for(var/channel, label in finish.channels)
			channels += list(list("key" = channel, "label" = label))
		var/list/presets = list()
		for(var/preset_name, colors in finish.presets)
			presets += list(list("name" = preset_name, "colors" = colors))
		var/list/zones = list()
		for(var/zone in BULKY_AUGMENT_ZONES)
			var/prefix = "[finish.limb_id_override]_[zone]"
			zones[zone] = list(
				"paint" = icon_exists(BULKY_AUGMENTS_PAINT_SHEET, "[prefix]_paint"),
				"glow" = icon_exists(BULKY_AUGMENTS_PAINT_SHEET, "[prefix]_glow"),
			)
		finishes[style_name] = list(
			"id" = finish.limb_id_override,
			"channels" = channels,
			"default" = finish.default_colors,
			"presets" = presets,
			"zones" = zones,
		)
	return list(
		"finishes" = finishes,
		"brands" = brands,
		// Quick swatches: metals and paints for paint, accent and frame, and light colours.
		"swatches" = list(
			"metal" = list("#e8eaee", "#c4c8d0", "#969ba8", "#5a5e66", "#26262b", "#c9a54a", "#b56b3c", "#b2202a", "#2e5fa8", "#3c7a4a", "#6a3fa0", "#e6e0d0"),
			"lights" = list("#46ebff", "#5fd4ff", "#3d7bff", "#9b5cff", "#ff3dcf", "#ff2d28", "#ff8a3d", "#ffcc33", "#b4ff3d", "#3dffb0", "#f4f8ff"),
		),
	)

/**
 * Returns each slot's colours, the skin the editor tints its preview's skin base with, and whether the character's lights
 * glow.
 */
/datum/preference_middleware/augment_paint/get_ui_data(mob/user)
	var/list/skin = preview_skin()
	sent_skin = "[skin["color"]][skin["humanoid"]]"
	return list(
		"augment_colors" = preferences.augment_limb_colors.Copy(),
		"augment_paint_skin" = skin,
		"augment_paint_emissive" = !!preferences.read_preference(/datum/preference/toggle/allow_emissives),
	)

/**
 * Adds the preview's skin to an answer when it changed since the page last got it. The answer comes once the preview mob has
 * been rebuilt for the changes it covers, while the window's own data, sent as each change is made, read the mob before
 * that. So the editor tints its skin base as the game draws the character.
 */
/datum/preference_middleware/augment_paint/add_preview_answer(list/update)
	var/list/skin = preview_skin()
	var/skin_key = "[skin["color"]][skin["humanoid"]]"
	if(skin_key == sent_skin)
		return
	sent_skin = skin_key
	update["augment_paint_skin"] = skin

/**
 * Returns the editor's sprites, the finishes' sheets cut up for its preview.
 */
/datum/preference_middleware/augment_paint/get_ui_assets()
	return list(get_asset_datum(/datum/asset/spritesheet_batched/augment_paint))

/**
 * Sends the brand styles' try-on sheet to the preferences window, when the window is about to need the Augments room rather
 * than whenever preferences open: the window asks for it once, in the background, ahead of the room.
 */
/datum/preference_middleware/augment_paint/proc/send_augment_brand_sprites(list/params, mob/user)
	var/datum/tgui/ui = SStgui.get_open_ui(user, preferences)
	if(isnull(ui))
		return FALSE
	var/datum/asset/sheet = get_asset_datum(/datum/asset/spritesheet_batched/augment_brands)
	// Getting the sheet can wait for it to finish generating, and the window or its client can go meanwhile.
	if(QDELETED(ui) || !user.client)
		return FALSE
	// The files have to arrive before the page hears of the stylesheet: once it has loaded that, it asks
	// for the image straight away, and an image that isn't there yet stays blank.
	if(sheet.send(user.client))
		user.client.browse_queue_flush()
	ui.send_asset(sheet)
	return FALSE

/**
 * Returns the skin the editor tints its preview's skin base with: the preview body's chest colour, and whether it is a mutant
 * colour, which the humanoid skin ramp draws.
 */
/datum/preference_middleware/augment_paint/proc/preview_skin()
	var/obj/item/bodypart/chest = preferences.character_preview_view?.body?.get_bodypart(BODY_ZONE_CHEST)
	return list("color" = chest?.draw_color || "#d9ae96", "humanoid" = !!chest?.species_color)

/**
 * Sets one slot's colours, or with no colours its finish's default. The slot's finish must be recolourable.
 *
 * Arguments:
 * - params: "slot", an augment slot, and "colors", a colour string or null.
 * - user: The player acting.
 *
 * Returns:
 * - FALSE: The window is sent the colours alone, or nothing for a refused action.
 */
/datum/preference_middleware/augment_paint/proc/set_augment_colors(list/params, mob/user)
	var/slot = params["slot"]
	if(!istext(slot) || !istype(GLOB.robotic_styles_list[preferences.augment_limb_styles[slot]], /datum/robotic_style/recolorable))
		return FALSE
	if(isnull(params["colors"]))
		preferences.augment_limb_colors -= slot
	else
		var/colors = sanitize_augment_colors(params["colors"])
		if(!colors)
			return FALSE
		preferences.augment_limb_colors[slot] = colors
	preferences.character_preview_view.update_body()
	return send_augment_colors(user)

/**
 * Gives every slot wearing a recolourable finish the colours `params["slot"]` draws, its default included.
 *
 * Arguments:
 * - params: "slot", the augment slot copied from, which must wear a recolourable finish.
 * - user: The player acting.
 *
 * Returns:
 * - FALSE: The window is sent the colours alone, or nothing for a refused action.
 */
/datum/preference_middleware/augment_paint/proc/copy_augment_colors(list/params, mob/user)
	var/slot = params["slot"]
	if(!istext(slot))
		return FALSE
	var/datum/robotic_style/recolorable/source = GLOB.robotic_styles_list[preferences.augment_limb_styles[slot]]
	if(!istype(source))
		return FALSE
	var/colors = preferences.augment_limb_colors[slot] || source.default_colors
	for(var/other_slot, style_name in preferences.augment_limb_styles)
		if(istype(GLOB.robotic_styles_list[style_name], /datum/robotic_style/recolorable))
			preferences.augment_limb_colors[other_slot] = colors
	preferences.character_preview_view.update_body()
	return send_augment_colors(user)

/**
 * Sends the open character setup window the augment colours.
 *
 * Returns:
 * - FALSE: Nothing else needs sending.
 */
/datum/preference_middleware/augment_paint/proc/send_augment_colors(mob/user)
	var/datum/tgui/ui = SStgui.get_open_ui(user, preferences)
	ui?.send_update(list("augment_colors" = preferences.augment_limb_colors.Copy()))
	return FALSE
