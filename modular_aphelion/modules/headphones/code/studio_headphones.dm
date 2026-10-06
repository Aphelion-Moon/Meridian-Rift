/// Studio headphones in tg's headphone shapes, recolourable, with a logo badge that can glow.
/obj/item/instrument/piano_synth/headphones/studio
	name = "studio headphones"
	desc = "Closed-back studio headphones: a glossy shell, soft cushions and a logo badge on each cup."
	icon = 'icons/map_icons/items/_item.dmi'
	icon_state = "/obj/item/instrument/piano_synth/headphones/studio"
	gender = PLURAL
	post_init_icon_state = "studiophones"
	inhand_icon_state = "studiophones"
	neck_icon_state = "studiophones_neck"
	neck_icon = null
	notes_overlay_on_head = TRUE
	greyscale_config = /datum/greyscale_config/headphones_studio
	greyscale_config_worn = /datum/greyscale_config/headphones_studio/worn
	greyscale_config_inhand_left = /datum/greyscale_config/headphones_studio/inhand_left
	greyscale_config_inhand_right = /datum/greyscale_config/headphones_studio/inhand_right
	greyscale_colors = "#c8202a#2b2b2b#f0f0f0"
	flags_1 = IS_PLAYER_COLORABLE_1
	/// The logo badge glows; alt-right-click switches it.
	var/badge_glow = FALSE

/obj/item/instrument/piano_synth/headphones/studio/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/gags_recolorable)

/obj/item/instrument/piano_synth/headphones/studio/examine(mob/user)
	. = ..()
	. += span_notice("Its badge glow is [badge_glow ? "on" : "off"]. <b>Alt-right-click</b> to switch it.")

/obj/item/instrument/piano_synth/headphones/studio/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	context[SCREENTIP_CONTEXT_ALT_RMB] = badge_glow ? "Badge glow off" : "Badge glow on"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/instrument/piano_synth/headphones/studio/click_alt_secondary(mob/user)
	badge_glow = !badge_glow
	balloon_alert(user, "badge glow [badge_glow ? "on" : "off"]")
	update_appearance()

/obj/item/instrument/piano_synth/headphones/studio/update_icon_state()
	. = ..()
	icon_state = post_init_icon_state // the item itself shows no notes

/obj/item/instrument/piano_synth/headphones/studio/worn_state(on_neck)
	return on_neck ? neck_icon_state : post_init_icon_state // the notes are the overlay

/obj/item/instrument/piano_synth/headphones/studio/update_overlays()
	. = ..()
	if(badge_glow)
		. += emissive_appearance(emissive_icon, "[post_init_icon_state]_obj_badge_emissive", src, alpha = src.alpha)

/obj/item/instrument/piano_synth/headphones/studio/worn_overlays(mutable_appearance/standing, isinhands = FALSE, icon_file, bodyshape = NONE)
	. = ..()
	if(badge_glow && !isinhands) // the badge faces away from the hand
		. += emissive_appearance(emissive_icon, "[drawn_on_neck(standing) ? neck_icon_state : post_init_icon_state]_badge_emissive", src, alpha = src.alpha)
