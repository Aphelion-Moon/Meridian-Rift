/obj/item/bodypart
	/// A recolourable finish's colours, "#rrggbb" four times: paint, accent, frame, lights. Null on every other limb. A limb
	/// with them carries /datum/element/augment_paint, which draws its paint and glow and keys its icons by them.
	var/augment_colors

/datum/preferences
	/// Each augment slot's recolourable finish's colours, slot name -> a colour string as /obj/item/bodypart/var/augment_colors.
	/// A slot without one draws its finish's default.
	var/list/augment_limb_colors = list()

/**
 * Sets a limb up to draw this finish, whatever augment item it is on: its skin base as its own greyscale image, its paint and
 * glow in `colors` (drawn by /datum/element/augment_paint), and its clothes fitted as a Muscular limb's. muscle_size is set
 * here at runtime: a typed one would make init_fitness_limb_families() take the limb type for a fitness family.
 *
 * The limb glows only where the finish's art has lights, the zone's lights mask, and while `prefs` allows emissives; one
 * made without prefs, like an admin spawn, glows. tg lights a limb's whole image and its hand's from is_emissive, so the
 * zone is checked here, once, and never as the limb is drawn; a lit arm's hand has a mask in the sheets too, empty where
 * the hand has no lights.
 *
 * Its skin parts take their colour from the limb's owner, which the limb learns as it is set up for one (update_limb()'s
 * is_creating); a limb put on a body for its finish is set up so (the spawn branch of /datum/augment_item/limb/apply()).
 *
 * The preview sets the same limb up again on every rebuild, after taking the last finish off (clear_augment_finish()), so
 * the element is added only to a limb wearing no finish yet: a second one would register its signals twice.
 *
 * Arguments:
 * - limb: The limb, already given this style's limb_id and icon.
 * - colors: The slot's colour string, already validated (load_augment_colors(), the editor's actions), or null for the
 *   finish's default.
 * - prefs: The preferences the limb is made from, if any.
 */
/datum/robotic_style/recolorable/proc/apply_to(obj/item/bodypart/limb, colors, datum/preferences/prefs)
	if(!limb.augment_colors)
		limb.AddElement(/datum/element/augment_paint)
	limb.should_draw_greyscale = TRUE
	limb.augment_colors = colors || default_colors
	limb.is_emissive = !!(channels["lights"] && icon_exists(BULKY_AUGMENTS_SHEET, "[limb_id_override]_[limb.body_zone]_e") && (prefs ? prefs.read_preference(/datum/preference/toggle/allow_emissives) : TRUE))
	limb.muscle_size = MUSCLE_SIZE_MUSCULAR
	limb.update_augment_skin_sheet()

/**
 * Takes a recolourable finish off a limb, if it had one, with its element: its colours go, and its glow and its fit go back to
 * its type's own.
 */
/obj/item/bodypart/proc/clear_augment_finish()
	if(augment_colors)
		RemoveElement(/datum/element/augment_paint)
	augment_colors = null
	is_emissive = initial(is_emissive)
	muscle_size = initial(muscle_size)

/**
 * Points a recolourable finish's limb at the skin sheet in its owner's skin ramp: the humanoid one under a mutant colour.
 */
/obj/item/bodypart/proc/update_augment_skin_sheet()
	icon_greyscale = species_color ? BULKY_AUGMENTS_SHEET_HUMANOID : BULKY_AUGMENTS_SHEET

/**
 * A recolourable finish's drawing, on the limbs wearing one: apply_to() adds it and clear_augment_finish() takes it off. The
 * colours stay on the limb (/obj/item/bodypart/var/augment_colors), so one element serves every finished limb, and a plain
 * limb, which never has it, redraws as it always has.
 */
/datum/element/augment_paint

/datum/element/augment_paint/Attach(datum/target)
	. = ..()
	if(!isbodypart(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_BODYPART_GET_LIMB_ICON, PROC_REF(on_limb_icon))
	RegisterSignal(target, COMSIG_BODYPART_GENERATE_ICON_KEY, PROC_REF(on_icon_key))

/datum/element/augment_paint/Detach(datum/source)
	. = ..()
	UnregisterSignal(source, list(COMSIG_BODYPART_GET_LIMB_ICON, COMSIG_BODYPART_GENERATE_ICON_KEY))

/**
 * Draws the finish's paint and glow over the limb (draw_augment_paint()). Sent at the end of get_limb_icon(), after the leg
 * split, height and textures, with the images as keys of a list to their flags: the copies only need to be keys too.
 */
/datum/element/augment_paint/proc/on_limb_icon(obj/item/bodypart/source, list/limb_icons, dropped)
	SIGNAL_HANDLER
	source.draw_augment_paint(limb_icons, dropped)

/**
 * Keys the limb by what its paint and glow draw: its colours, whether it glows, its alpha, which the matrices carry, and its
 * skin ramp. The limb icon cache is shared by every body, so without them one body's arm would be served to another.
 *
 * First it points the limb at the skin sheet in its owner's ramp (update_augment_skin_sheet()). update_body_parts() keys a
 * limb after update_limb(), which learns species_color as the limb is set up for an owner, and before get_limb_icon(), so
 * the sheet drawn is the one keyed. COMSIG_BODYPART_UPDATED comes too early for it, before update_limb() sets
 * species_color. A dropped limb, drawn without a key, keeps the sheet it had when it was last keyed or set up.
 */
/datum/element/augment_paint/proc/on_icon_key(obj/item/bodypart/source, list/icon_keys)
	SIGNAL_HANDLER
	source.update_augment_skin_sheet()
	icon_keys += "[source.augment_colors][source.is_emissive ? "e" : ""][source.alpha][source.species_color ? "h" : ""]"

/**
 * Draws a recolourable finish's paint and glow into the images get_limb_icon() made: for the limb's own image and its hand's,
 * copies drawing the finish's _paint and _glow states through their colour matrices, added above everything the limb drew
 * (its markings too, which the plates cover where they cover skin). Copies of the limb's images, they keep its layer, height,
 * texture and facing; a leg's are split into the leg's two halves through the masked leg cache (handle_masking()), as
 * draw_muscle_definition() splits definition.
 *
 * Anything else the limb lights, like a glowing marking, would light the plates over it in the dark, so then each _paint copy
 * also gets an emissive blocker, a copy of the limb's own. A limb with nothing else lit gets none: only an emissive counts,
 * told by its colour matrix, never the emissive blockers its overlays bring along. The finish's own lights masks, the limb's
 * and its hand's, are never under a _paint pixel, so they stay lit.
 *
 * Nothing is drawn for a limb get_limb_icon() drew none of its own image for: a stump, an invisible limb, a taur's legs. Nor
 * for a zone whose packed state the sheet doesn't hold: a finish with no lights on a hand has no _glow there.
 *
 * Arguments:
 * - images: get_limb_icon()'s images as keys, the limb's own first (on a split leg, its two halves; on an arm, then its hand).
 *   Changed in place.
 * - dropped: Whether they're drawn for the limb lying on its own, which isn't split into leg halves.
 */
/obj/item/bodypart/proc/draw_augment_paint(list/images, dropped)
	if(!length(images))
		return
	var/image/own = images[1]
	if(own.icon_state != "[limb_id]_[body_zone]")
		return
	var/hand_state = aux_zone ? "[limb_id]_[aux_zone]" : null
	// The limb's own emissive blockers, by state and layer, and whether anything but the finish's lights glows on it.
	var/list/block_templates = list()
	var/other_glow = FALSE
	for(var/image/drawn as anything in images)
		if(PLANE_TO_TRUE(drawn.plane) != EMISSIVE_PLANE)
			continue
		var/state = drawn.icon_state
		if(state == own.icon_state || state == hand_state)
			block_templates["[state] [drawn.layer]"] = drawn
		else if(!other_glow && state != "[own.icon_state]_e" && state != "[hand_state]_e")
			// A glow lights its matrix's constant row (_EMISSIVE_COLOR()); a blocker's is zero or reads back as a colour.
			var/list/color_matrix = drawn.color
			if(islist(color_matrix) && length(color_matrix) >= 20)
				other_glow = color_matrix[17] || color_matrix[18] || color_matrix[19]
	var/list/matrices = list(
		"paint" = augment_paint_matrix(augment_colors, FALSE, alpha),
		"glow" = augment_paint_matrix(augment_colors, TRUE, alpha),
	)
	var/split = !dropped && istype(src, /obj/item/bodypart/leg)
	var/list/copies = list()
	for(var/packed, matrix in matrices)
		var/list/templates = (other_glow && packed == "paint") ? block_templates : null
		var/state = "[limb_id]_[body_zone]_[packed]"
		if(icon_exists(BULKY_AUGMENTS_PAINT_SHEET, state))
			if(split)
				var/list/halves = handle_masking(image(BULKY_AUGMENTS_PAINT_SHEET, state))
				for(var/half in 1 to 2)
					var/image/masked = halves[half]
					copies += paint_copy(images[half], masked.icon, state, matrix, templates)
			else
				copies += paint_copy(own, BULKY_AUGMENTS_PAINT_SHEET, state, matrix, templates)
		if(hand_state && length(images) >= 2)
			var/hand_packed = "[hand_state]_[packed]"
			if(icon_exists(BULKY_AUGMENTS_PAINT_SHEET, hand_packed))
				copies += paint_copy(images[2], BULKY_AUGMENTS_PAINT_SHEET, hand_packed, matrix, templates)
	images += copies

/**
 * Returns a copy of `base`, one of a limb's own images, drawing `state` from `sheet` in `matrix`, and with `block_templates`,
 * an emissive blocker for it: a copy of the limb's own blocker for `base`, so it sits on the emissive plane as that does.
 *
 * Arguments:
 * - base: The image copied: its layer, height filter, texture and facing are kept.
 * - sheet: The sheet `state` is drawn from, or a masked leg half's icon.
 * - state: A finish's packed state, <id>_<zone>_paint or <id>_<zone>_glow.
 * - matrix: The state's colour matrix (augment_paint_matrix()).
 * - block_templates: The limb's own emissive blockers, "<state> <layer>" -> blocker, or null for no blocker.
 *
 * Returns:
 * - list: The copy, then its blocker if it has one.
 */
/obj/item/bodypart/proc/paint_copy(image/base, sheet, state, list/matrix, list/block_templates)
	var/image/copy = new(base)
	copy.icon = sheet
	copy.icon_state = state
	copy.color = matrix
	. = list(copy)
	var/image/template = block_templates?["[base.icon_state] [base.layer]"]
	if(!template)
		return
	var/image/blocker = new(template)
	blocker.icon = sheet
	blocker.icon_state = state
	. += blocker
