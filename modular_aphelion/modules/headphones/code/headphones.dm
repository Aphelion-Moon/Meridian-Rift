// tg's headphones also go on the neck, with a neck sprite of their own. There the band sits under hair, or over it
// after an alt-click, and an item action hides the music notes. The studio and neon sets build on this. Headphones
// without a neck sprite (space pods, Nova's cat-ear headphones) keep tg's behaviour: no neck sprite, no switches.
// While a song plays, the notes are one shared overlay (tg's own, icons/headphones.dmi) behind the worn sprite.

/obj/item/instrument/piano_synth/headphones
	slot_flags = ITEM_SLOT_EARS | ITEM_SLOT_HEAD | ITEM_SLOT_NECK
	// tg's inhand sprite gives these dark grey headphones red cups. The hands come from the studio headphones' GAGS inhand
	// configs instead, in tg's greys (items.dm runs update_greyscale() for inhand-only configs). The item and worn sprites
	// stay tg's own, and nothing here is recolourable: no IS_PLAYER_COLORABLE_1.
	inhand_icon_state = "studiophones"
	greyscale_config_inhand_left = /datum/greyscale_config/headphones_studio/inhand_left
	greyscale_config_inhand_right = /datum/greyscale_config/headphones_studio/inhand_right
	greyscale_colors = "#686868#3a3a3a#686868"
	/// Worn icon_state on the neck, under the notes overlay while they play. Null: no neck sprite and none of the switches.
	var/neck_icon_state = "headphones_neck"
	/// The file holding neck_icon_state, or null when worn_icon has it (the GAGS sets).
	var/neck_icon = 'modular_aphelion/modules/headphones/icons/headphones.dmi'
	/// The worn sprites on the head and ears leave the notes to the overlay too; tg's own have their notes drawn in.
	var/notes_overlay_on_head = FALSE
	/// The glow masks of the sets that glow, static and outside the GAGS configs.
	var/emissive_icon = 'modular_aphelion/modules/headphones/icons/headphones_emissive.dmi'
	/// On the neck, the band draws over hair (HEADPHONES_NECK_OVER_HAIR_LAYER) instead of under it
	/// (HEADPHONES_NECK_UNDER_HAIR_LAYER, which still draws over backpack straps).
	var/neck_over_hair = FALSE
	/// The music notes float around the headphones while a song plays.
	var/music_notes = TRUE

/obj/item/instrument/piano_synth/headphones/spacepods
	neck_icon_state = null
	neck_icon = null
	// held invisibly (tg's inhand_icon_state = null), so no GAGS inhands
	greyscale_config_inhand_left = null
	greyscale_config_inhand_right = null
	greyscale_colors = null

/obj/item/instrument/piano_synth/headphones/catear_headphone
	neck_icon_state = null
	neck_icon = null

/obj/item/instrument/piano_synth/headphones/Initialize(mapload)
	. = ..()
	if(neck_icon_state)
		add_item_action(/datum/action/item_action/toggle_music_notes)
		register_context()

/obj/item/instrument/piano_synth/headphones/examine(mob/user)
	. = ..()
	if(isnull(neck_icon_state))
		return
	. += span_notice("Worn on the neck, the band sits [neck_over_hair ? "over" : "under"] hair. <b>Alt-click</b> to switch.")
	if(!music_notes)
		. += span_notice("The music notes are hidden.")

/obj/item/instrument/piano_synth/headphones/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(isnull(neck_icon_state))
		return
	context[SCREENTIP_CONTEXT_ALT_LMB] = neck_over_hair ? "Band under hair" : "Band over hair"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/instrument/piano_synth/headphones/click_alt(mob/user)
	if(isnull(neck_icon_state))
		return NONE
	neck_over_hair = !neck_over_hair
	balloon_alert(user, "band [neck_over_hair ? "over" : "under"] hair")
	update_appearance()
	return CLICK_ACTION_SUCCESS

/obj/item/instrument/piano_synth/headphones/ui_action_click(mob/user, actiontype)
	if(!istype(actiontype, /datum/action/item_action/toggle_music_notes))
		return ..()
	music_notes = !music_notes
	balloon_alert(user, "notes [music_notes ? "shown" : "hidden"]")
	update_appearance()

/// The worn icon_state: one for the head and ears (tg's, with the notes drawn in while playing), and with on_neck the
/// neck's, which leaves the notes to the overlay.
/obj/item/instrument/piano_synth/headphones/proc/worn_state(on_neck)
	if(on_neck)
		return neck_icon_state
	var/base_state = post_init_icon_state || initial(icon_state)
	return song?.playing && music_notes ? "[base_state]_on" : base_state

/// The notes overlay's colour: null for tg's own navy notes, or a colour matrix taking their two shades elsewhere.
/// Coloured notes glow.
/obj/item/instrument/piano_synth/headphones/proc/notes_color()
	return null

/// Whether build_worn_icon() drew this worn appearance for the neck, which it puts on one of the two neck layers.
/obj/item/instrument/piano_synth/headphones/proc/drawn_on_neck(mutable_appearance/standing)
	return standing.layer == -HEADPHONES_NECK_UNDER_HAIR_LAYER || standing.layer == -HEADPHONES_NECK_OVER_HAIR_LAYER

/obj/item/instrument/piano_synth/headphones/build_worn_icon(
	default_layer = 0,
	default_icon_file = null,
	isinhands = FALSE,
	female_uniform = NO_FEMALE_UNIFORM,
	override_state = null,
	override_file = null,
	bodyshape = NONE,
)
	if(isinhands || isnull(neck_icon_state) || override_state || override_file)
		return ..()
	if(default_layer != NECK_LAYER)
		return ..(default_layer, default_icon_file, isinhands, female_uniform, worn_state(FALSE), override_file, bodyshape)
	// the neck has its own sprite, and only there does the band go over hair
	return ..(neck_over_hair ? HEADPHONES_NECK_OVER_HAIR_LAYER : HEADPHONES_NECK_UNDER_HAIR_LAYER, default_icon_file, isinhands, female_uniform, worn_state(TRUE), neck_icon, bodyshape)

/obj/item/instrument/piano_synth/headphones/worn_overlays(mutable_appearance/standing, isinhands = FALSE, icon_file, bodyshape = NONE)
	. = ..()
	if(isinhands || isnull(neck_icon_state) || !music_notes || !song?.playing)
		return
	var/on_neck = drawn_on_neck(standing)
	if(!on_neck && !notes_overlay_on_head)
		return
	// behind the headphones, whose sprites leave room for them, and so under the sprite's glow blocker too
	var/notes_state = on_neck ? "notes_neck" : "notes"
	var/mutable_appearance/notes = mutable_appearance('modular_aphelion/modules/headphones/icons/headphones.dmi', notes_state)
	notes.color = notes_color()
	standing.underlays += notes
	if(notes.color)
		standing.underlays += emissive_appearance('modular_aphelion/modules/headphones/icons/headphones.dmi', notes_state, src, alpha = src.alpha)

/// Hides or shows the music notes around headphones while they play; the song and any light animation go on.
/datum/action/item_action/toggle_music_notes
	name = "Toggle Music Notes"
	desc = "Show or hide the music notes floating around your headphones while they play."
