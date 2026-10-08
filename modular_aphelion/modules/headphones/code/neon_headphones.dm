/// Recolourable headphones with neon lights: a steady glow when on, animated while a song plays; switched off, dark
/// glass and tg's own notes. Alt-right-click switches the lights.
/obj/item/instrument/piano_synth/headphones/neon
	abstract_type = /obj/item/instrument/piano_synth/headphones/neon
	icon = 'icons/map_icons/items/_item.dmi'
	gender = PLURAL
	neck_icon = null
	notes_overlay_on_head = TRUE
	flags_1 = IS_PLAYER_COLORABLE_1
	/// The lights glow, and play their animation while a song plays.
	var/lights_on = TRUE
	/// While lit, the notes are this colour id (the light) for their navy, and for tg's grey highlight that colour
	/// through the GAGS glint the sprites use: floor(colour * notes_glint / 255) + notes_glint_add. From the lab's export.
	var/notes_channel
	/// See notes_channel.
	var/notes_glint
	/// See notes_channel.
	var/notes_glint_add

/obj/item/instrument/piano_synth/headphones/neon/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/gags_recolorable)
	update_appearance() // the glow and the mic overlay from the start, not only after a first update

/obj/item/instrument/piano_synth/headphones/neon/examine(mob/user)
	. = ..()
	. += span_notice("Its lights are [lights_on ? "on" : "off"]. <b>Alt-right-click</b> to switch them.")

/obj/item/instrument/piano_synth/headphones/neon/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	context[SCREENTIP_CONTEXT_ALT_RMB] = lights_on ? "Lights off" : "Lights on"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/instrument/piano_synth/headphones/neon/click_alt_secondary(mob/user)
	lights_on = !lights_on
	balloon_alert(user, "lights [lights_on ? "on" : "off"]")
	update_greyscale()
	update_appearance()

/**
 * How the lights go dark: null keeps dark copies of the sprites ("<state>_unlit"); otherwise the lit sprites redrawn
 * with each light colour darkened, as colour id = grey (out of 255). From the lab's export.
 */
/obj/item/instrument/piano_synth/headphones/neon/proc/unlit_greys()
	return null

/obj/item/instrument/piano_synth/headphones/neon/update_greyscale()
	. = ..()
	var/alist/greys = lights_on ? null : unlit_greys()
	if(isnull(greys) || !greyscale_colors)
		return
	// greyscale_colors keeps the player's colours: only the drawn icons are dark
	var/list/colors = SSgreyscale.ParseColorString(greyscale_colors)
	for(var/channel, grey in greys)
		var/list/light = rgb2num(colors[channel])
		colors[channel] = rgb(floor(light[1] * grey / 255), floor(light[2] * grey / 255), floor(light[3] * grey / 255))
	var/dark_colors = colors.Join()
	icon = SSgreyscale.GetColoredIconByType(greyscale_config, dark_colors)
	worn_icon = SSgreyscale.GetColoredIconByType(greyscale_config_worn, dark_colors)
	lefthand_file = SSgreyscale.GetColoredIconByType(greyscale_config_inhand_left, dark_colors)
	righthand_file = SSgreyscale.GetColoredIconByType(greyscale_config_inhand_right, dark_colors)

/obj/item/instrument/piano_synth/headphones/neon/worn_state(on_neck)
	var/base_state = on_neck ? neck_icon_state : base_icon_state
	if(!lights_on)
		return isnull(unlit_greys()) ? "[base_state]_unlit" : base_state
	return song?.playing ? "[base_state]_on" : base_state

/obj/item/instrument/piano_synth/headphones/neon/notes_color()
	if(!lights_on)
		return null
	var/list/colors = SSgreyscale.ParseColorString(greyscale_colors)
	var/list/light = rgb2num(colors[notes_channel])
	. = list(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	// per channel, tg's navy (0, 0, 51) goes to the light and tg's grey (77, 77, 77) to the light's glint
	for(var/channel in 1 to 3)
		var/navy = light[channel]
		var/glint = min(255, floor(navy * notes_glint / 255) + notes_glint_add)
		var/tg_navy = channel == 3 ? 51 : 0
		var/scale = (glint - navy) / (77 - tg_navy)
		.[channel * 4 - 3] = scale
		.[channel + 9] = (navy - scale * tg_navy) / 255

/obj/item/instrument/piano_synth/headphones/neon/update_icon_state()
	. = ..()
	var/dark_copies = !lights_on && isnull(unlit_greys())
	if(lights_on && song?.playing)
		icon_state = "[base_icon_state]_on"
	else
		icon_state = dark_copies ? "[base_icon_state]_unlit" : base_icon_state
	inhand_icon_state = dark_copies ? "[base_icon_state]_unlit" : base_icon_state

/obj/item/instrument/piano_synth/headphones/neon/update_overlays()
	. = ..()
	if(lights_on)
		. += emissive_appearance(emissive_icon, "[icon_state]_obj_emissive", src, alpha = src.alpha)

/obj/item/instrument/piano_synth/headphones/neon/worn_overlays(mutable_appearance/standing, isinhands = FALSE, icon_file, bodyshape = NONE)
	. = ..()
	if(lights_on)
		var/glow_state = isinhands ? "[inhand_icon_state]_inhand_[icon_file == lefthand_file ? "left" : "right"]" : worn_state(drawn_on_neck(standing))
		. += emissive_appearance(emissive_icon, "[glow_state]_emissive", src, alpha = src.alpha)

/obj/item/instrument/piano_synth/headphones/neon/streetjack
	name = "\improper Streetjack Cans"
	desc = "Chunky street cans: a split neon panel and a level meter on each cup, and a copper jack on the cable."
	icon_state = "/obj/item/instrument/piano_synth/headphones/neon/streetjack"
	post_init_icon_state = "streetcans"
	base_icon_state = "streetcans"
	inhand_icon_state = "streetcans"
	neck_icon_state = "streetcans_neck"
	greyscale_config = /datum/greyscale_config/headphones_streetjack
	greyscale_config_worn = /datum/greyscale_config/headphones_streetjack/worn
	greyscale_config_inhand_left = /datum/greyscale_config/headphones_streetjack/inhand_left
	greyscale_config_inhand_right = /datum/greyscale_config/headphones_streetjack/inhand_right
	greyscale_colors = "#40454f#9ba5b3#ff3a8c#ff8a66#3ff2d8"
	notes_channel = 3
	notes_glint = 99
	notes_glint_add = 157

/obj/item/instrument/piano_synth/headphones/neon/streetjack/unlit_greys()
	var/static/alist/greys = alist(3 = 91, 4 = 89, 5 = 81)
	return greys

/obj/item/instrument/piano_synth/headphones/neon/raid
	name = "\improper Raid Headset"
	desc = "A camo gaming headset with LED strips along the band and the inner ears, and a boom mic to call the shots."
	gender = NEUTER
	icon_state = "/obj/item/instrument/piano_synth/headphones/neon/raid"
	post_init_icon_state = "raid_headset" // the map icon and the recolour menu's first view: the item with its mic
	base_icon_state = "raid"
	inhand_icon_state = "raid"
	worn_icon_state = "raid"
	neck_icon_state = "raid_neck"
	greyscale_config = /datum/greyscale_config/headphones_raid
	greyscale_config_worn = /datum/greyscale_config/headphones_raid/worn
	greyscale_config_inhand_left = /datum/greyscale_config/headphones_raid/inhand_left
	greyscale_config_inhand_right = /datum/greyscale_config/headphones_raid/inhand_right
	greyscale_colors = "#304622#80a046#2ed3ff#3a3e46"
	notes_channel = 3
	notes_glint = 73
	notes_glint_add = 182
	/// The boom mic, drawn over the worn sprites (but not the inhands) and the item.
	var/boom_mic = TRUE
	/// The mic in the current pads colour, from its own GAGS config.
	var/mic_icon

/obj/item/instrument/piano_synth/headphones/neon/raid/unlit_greys()
	var/static/alist/greys = alist(3 = 91)
	return greys

/obj/item/instrument/piano_synth/headphones/neon/raid/update_greyscale()
	. = ..()
	if(boom_mic && greyscale_colors)
		var/list/colors = SSgreyscale.ParseColorString(greyscale_colors)
		mic_icon = SSgreyscale.GetColoredIconByType(/datum/greyscale_config/headphones_raid_mic, colors[4]) // the pads

/obj/item/instrument/piano_synth/headphones/neon/raid/set_greyscale(list/colors, new_config, new_worn_config, new_inhand_left, new_inhand_right)
	. = ..()
	update_appearance(UPDATE_OVERLAYS) // a recolour reaches the mic overlay too

/obj/item/instrument/piano_synth/headphones/neon/raid/update_overlays()
	. = ..()
	if(mic_icon)
		. += mutable_appearance(mic_icon, "raid_obj_mic")

/obj/item/instrument/piano_synth/headphones/neon/raid/worn_overlays(mutable_appearance/standing, isinhands = FALSE, icon_file, bodyshape = NONE)
	. = ..()
	if(isinhands || !mic_icon)
		return
	var/mic_state = drawn_on_neck(standing) ? "raid_neck_mic" : "raid_mic"
	. += mutable_appearance(mic_icon, mic_state)
	// the glow masks are Raid Headphones', lit where the mic would be: the mic hides that glow
	. += emissive_blocker(mic_icon, mic_state, src, alpha = src.alpha)

/// The Raid Headset without its boom mic.
/obj/item/instrument/piano_synth/headphones/neon/raid/no_mic
	name = "\improper Raid Headphones"
	desc = "The Raid Headset's camo shell and LED strips, without the boom mic."
	gender = PLURAL
	icon_state = "/obj/item/instrument/piano_synth/headphones/neon/raid/no_mic"
	post_init_icon_state = "raid"
	boom_mic = FALSE

/// The loadout's Raid Headphones, as they come or as the Raid Headset - one entry, with the boom mic as a reskin.
/datum/atom_skin/raid_headphones
	abstract_type = /datum/atom_skin/raid_headphones
	greyscale_item_path = /obj/item/instrument/piano_synth/headphones/neon/raid/no_mic
	change_worn_icon_state = FALSE // worn states follow base_icon_state, see worn_state()

/datum/atom_skin/raid_headphones/headphones
	preview_name = "Raid Headphones"
	new_icon_state = "raid"

/datum/atom_skin/raid_headphones/headset
	preview_name = "Raid Headset"
	new_desc = /obj/item/instrument/piano_synth/headphones/neon/raid::desc
	new_icon_state = "raid_headset" // the map icon with the mic

/datum/atom_skin/raid_headphones/headset/apply(obj/item/instrument/piano_synth/headphones/neon/raid/apply_to, mob/user)
	. = ..()
	// The headset's name here rather than as new_name, whose \improper would show in the loadout's reskin list.
	if(!HAS_TRAIT(apply_to, TRAIT_WAS_RENAMED))
		apply_to.name = /obj/item/instrument/piano_synth/headphones/neon/raid::name
	apply_to.gender = NEUTER
	apply_to.boom_mic = TRUE
	apply_to.update_greyscale() // makes the mic's icon
	apply_to.update_appearance()

/obj/item/instrument/piano_synth/headphones/neon/halo
	name = "\improper Halo Phones"
	desc = "Sleek headphones with a glowing ring round each cup, which spins while the music plays."
	icon_state = "/obj/item/instrument/piano_synth/headphones/neon/halo"
	post_init_icon_state = "halophones"
	base_icon_state = "halophones"
	inhand_icon_state = "halophones"
	neck_icon_state = "halophones_neck"
	greyscale_config = /datum/greyscale_config/headphones_halo
	greyscale_config_worn = /datum/greyscale_config/headphones_halo/worn
	greyscale_config_inhand_left = /datum/greyscale_config/headphones_halo/inhand_left
	greyscale_config_inhand_right = /datum/greyscale_config/headphones_halo/inhand_right
	greyscale_colors = "#6a568e#4ff2e2#22aeb0#ff9a3a"
	notes_channel = 4
	notes_glint = 115
	notes_glint_add = 140

/// Halo Phones in cherry-blossom colours: the same GAGS configs, its own default colours.
/obj/item/instrument/piano_synth/headphones/neon/halo/sakura
	name = "\improper Sakura Halo Phones"
	desc = "Halo Phones in cherry-blossom pinks."
	icon_state = "/obj/item/instrument/piano_synth/headphones/neon/halo/sakura"
	greyscale_colors = "#8e5675#ffb3d9#c9709a#ff5a8a"
