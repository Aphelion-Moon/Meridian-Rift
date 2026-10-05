/**
 * The bulge template sheets (icons/templates), the templates derived at run time, and the accessors that find either
 * by identity.
 *
 * Every template is named for what it is, and the accessor computes the name from the identity: the garment's family
 * (families.dm), half or hard, the bulge size, plain or digitigrade legs, and past the family's small_cap the penis
 * shape (and whether it is drawn with skin tones). Where two families share shapes by design the family data says so;
 * nothing else maps one name to another.
 *
 * The sheets hold the shapes up to small_cap, the skirts' anatomy clearance and flaps, and the large heart boxers'
 * precoloured patches (made by the print rule). A kind map holds the whole shading of one bulge in one state: each kind
 * of pushed-out cloth in its fixed grey, the approved shading laid over mid-grey cloth, so a sheet opened in Dream Maker
 * shows the bulges as drawn on grey cloth. Masks (anatomy clearance, skirt flaps) are white. Each sheet is cropped to
 * one window, placed on the 32x32 tile by the pixel offsets defined below.
 *
 * Past small_cap the shapes, the anatomy they leave bare, the loincloths' drapes and their cuts have no sheet: they are
 * derived, by the approved rule, from the game's own penis, testicle and loincloth sprites (bulge_derive_large(),
 * bulge_derive_drape(), bulge_loincloth_cut()), under the names their sheet states had, and bulge_derivation holds them
 * to a frozen record of those states. The sprites are read once each, on first use; nothing is derived at init.
 *
 * A template is decoded or derived once and kept for the round; an identity asked for again is a few list reads.
 * Nothing here is on a per-pass path, and a renderer only asks when a wearer's look changes.
 */

// The sheets, and the pixel offsets (from the bottom left of the 32x32 tile) of each sheet's crop window.
#define BULGE_SHEET_CLOTH_SMALL 'modular_aphelion/modules/bulge/icons/templates/cloth_small.dmi'
#define BULGE_CLOTH_SMALL_X 7
#define BULGE_CLOTH_SMALL_Y 4
#define BULGE_SHEET_SKIRT_SHAPES 'modular_aphelion/modules/bulge/icons/templates/skirt_shapes.dmi'
#define BULGE_SKIRT_SHAPES_X 7
#define BULGE_SKIRT_SHAPES_Y 4
#define BULGE_SHEET_SKIRT_CLEARANCE 'modular_aphelion/modules/bulge/icons/templates/skirt_clearance.dmi'
#define BULGE_SKIRT_CLEARANCE_X 7
#define BULGE_SKIRT_CLEARANCE_Y 8
#define BULGE_SHEET_SKIRT_FLAPS 'modular_aphelion/modules/bulge/icons/templates/skirt_flaps.dmi'
#define BULGE_SKIRT_FLAPS_X 10
#define BULGE_SKIRT_FLAPS_Y 3
#define BULGE_SHEET_PRINTED_PATCHES 'modular_aphelion/modules/bulge/icons/templates/printed_patches.dmi'
#define BULGE_PRINTED_PATCHES_X 1
#define BULGE_PRINTED_PATCHES_Y 5

// The fixed grey of each kind in a kind map: the approved shading (BULGE_KIND_*) over cloth of #808080.
#define BULGE_GREY_CLOTH "#808080"
#define BULGE_GREY_LIGHT "#a3a3a3"
#define BULGE_GREY_HIGHLIGHT "#b7b7b7"
#define BULGE_GREY_SHADE "#646464"
#define BULGE_GREY_DEEP_SHADE "#4b4b4b"

/// A loincloth's cut never sits higher than this row: a drape that stays above it facing south takes the lifted hem.
#define BULGE_LOINCLOTH_TOP_HEM 22
// A loincloth's cut works in a window BULGE_LOINCLOTH_CUTS_SIZE pixels square, this far from the tile's left and bottom.
#define BULGE_LOINCLOTH_CUTS_X 11
#define BULGE_LOINCLOTH_CUTS_Y 3
#define BULGE_LOINCLOTH_CUTS_SIZE 10

// What the shapes past small_cap are derived from, besides the penis's own sprites (its sprite accessory's icon): the
// approved previews drew every penis over one pair of skin-toned testicles, tinted with one skin tone, caucasian2.
#define BULGE_TESTICLES_SPRITE 'modular_nova/master_files/icons/mob/sprite_accessory/genitals/testicles_onmob.dmi'
#define BULGE_TESTICLES_STATE "m_testicles_pair_3_s_FRONT_UNDER"
/// One channel of a sprite pixel tinted with that skin tone (#fcccb3), as the previews tinted it, rounded to nearest:
/// a whole number of 255ths, which never sits on a half.
#define BULGE_SKIN_TINT(value, tone) round((value) * (tone) / 255, 1)
// The window the penis and testicle sprites draw in, all that a derivation reads of them: rows 2 to 31 from the top, and
// columns 7 to 22 facing south, 15 to 31 facing east and 0 to 16 facing west. bulge_derivation/pin holds them to it.
#define BULGE_SPRITE_TOP 2
#define BULGE_SPRITE_SOUTH_LEFT 7
#define BULGE_SPRITE_SOUTH_RIGHT 22
#define BULGE_SPRITE_EAST_LEFT 15
#define BULGE_SPRITE_WEST_RIGHT 16
/// The row of a loincloth's flap facing south: its drape's top row there.
#define BULGE_DRAPE_TOP 21
/// A loincloth's drape follows the penis at most this many columns past its hinge facing east.
#define BULGE_DRAPE_REACH 5
/// From this sprite size a tentacle eclipses the drape: only a stub of it shows at the hinge.
#define BULGE_DRAPE_ECLIPSE 5

/// Memo slot of an identity with a penis shape: 1-64.
#define BULGE_SHAPE_SLOT(hard, size, digi, toned) (((hard) ? 32 : 0) + ((digi) ? 16 : 0) + ((toned) ? 8 : 0) + (size))
/// Memo slot of an identity without one: 1-32.
#define BULGE_FORM_SLOT(hard, size, digi) (((hard) ? 16 : 0) + ((digi) ? 8 : 0) + (size))
/// Memo slot of a drape: 1-112.
#define BULGE_DRAPE_SLOT(size, sprite_size, toned) ((((toned) ? 8 : 0) + (size) - 1) * 7 + (sprite_size))

/// A null alist global, created on first use.
#define BULGE_GLOBAL_ALIST(X) GLOBAL_RAW(/alist/##X); GLOBAL_UNMANAGED(X)

/// Shapes by identity: family -> penis shape (or the family) -> BULGE_SHAPE_SLOT -> template, or FALSE for none.
BULGE_GLOBAL_ALIST(bulge_shape_memo)
/// Exposed anatomy masks by identity, as bulge_shape_memo: a /datum/bulge_sheet_state or FALSE.
BULGE_GLOBAL_ALIST(bulge_exposed_memo)
/// Drapes by identity: family -> penis shape -> BULGE_DRAPE_SLOT -> template or FALSE.
BULGE_GLOBAL_ALIST(bulge_drape_memo)
/// Loincloth cuts by identity, as bulge_drape_memo: a /datum/bulge_sheet_state or FALSE.
BULGE_GLOBAL_ALIST(bulge_loincloth_cut_memo)
/// Skirt anatomy clearance by identity: family -> BULGE_FORM_SLOT (legs left out) -> /datum/bulge_sheet_state or FALSE.
BULGE_GLOBAL_ALIST(bulge_clearance_memo)
/// Skirt flaps by identity: family -> BULGE_FORM_SLOT (hard) -> template or FALSE.
BULGE_GLOBAL_ALIST(bulge_flap_memo)
/// Precoloured printed patches by identity: family -> BULGE_FORM_SLOT -> /datum/bulge_sheet_state or FALSE.
BULGE_GLOBAL_ALIST(bulge_printed_patch_memo)
/// Sheet states by "[sheet]|[state]", a derived state's sheet left empty: one /datum/bulge_sheet_state per state however
/// many identities draw it.
GLOBAL_LIST(bulge_sheet_states)

/datum/sprite_accessory/genital/penis
	/// Whether this penis shape has bulge shapes of its own past a family's small_cap (the cloth shapes per penis
	/// shape, and the flat tip of the leather loincloth's drape). A shape without them, the tentacles, draws the
	/// family's small_cap shape there (bulge_shape_size()): mal, 2026-10-03, "big tentacles should show the size 4 bulge".
	var/bulge_hyper = TRUE
	/// Whether this shape drawn without skin tones has bulge shapes of its own: its untoned sprites draw differently.
	var/bulge_untoned = FALSE

/datum/sprite_accessory/genital/penis/human/alt
	bulge_untoned = TRUE

/datum/sprite_accessory/genital/penis/hemi
	bulge_untoned = TRUE

/datum/sprite_accessory/genital/penis/hemi/alt
	bulge_untoned = FALSE

/datum/sprite_accessory/genital/penis/tentacle
	bulge_hyper = FALSE

/**
 * One state of a template sheet and where it sits: its sheet, its name and the pixel offsets of the sheet's window. A
 * state derived at run time (a shape past small_cap, which is also the anatomy it leaves bare, or a loincloth's cut) has
 * no sheet and sits on the whole tile: only its name, and its pixels are never read from a file.
 */
/datum/bulge_sheet_state
	/// The sheet; null for a derived state.
	var/icon
	/// The state's name.
	var/icon_state
	/// Offset of the sheet's window on the 32x32 tile, from its left.
	var/pixel_x = 0
	/// Offset of the sheet's window on the 32x32 tile, from its bottom.
	var/pixel_y = 0
	/// Whether the state has any opaque pixel, for a mask: null until bulge_mask_shows() reads it.
	var/shows_any

/// The one /datum/bulge_sheet_state for a sheet's state, or null when the sheet has no such state; with no sheet
/// (`icon_file` null), the one for the derived state of that name.
/proc/bulge_sheet_state(icon_file, icon_state, pixel_x, pixel_y)
	var/key = "[icon_file]|[icon_state]"
	var/datum/bulge_sheet_state/found = GLOB.bulge_sheet_states?[key]
	if(found)
		return found
	if(icon_file && !icon_exists(icon_file, icon_state))
		return null
	found = new
	found.icon = icon_file
	found.icon_state = icon_state
	found.pixel_x = pixel_x
	found.pixel_y = pixel_y
	LAZYSET(GLOB.bulge_sheet_states, key, found)
	return found

/**
 * Whether a mask shows anything. A skirt's anatomy clearance can be empty (the shaft shows behind the skirt and none of
 * it above), and anatomy masked by an empty one would be a fully transparent icon, derived and sent for nothing. Read
 * once per state, from its frames facing south, east and west (north is empty in every template sheet); a derived
 * mask has no sheet, and always shows something (bulge_exposed()).
 */
/proc/bulge_mask_shows(datum/bulge_sheet_state/mask)
	SHOULD_NOT_SLEEP(TRUE)
	if(!isnull(mask.shows_any))
		return mask.shows_any
	if(!mask.icon)
		CRASH("Bulge mask [mask.icon_state] is derived: it has no sheet to read whether it shows anything.")
	mask.shows_any = FALSE
	var/icon/frames = icon(mask.icon, mask.icon_state, null, 1, 0)
	var/width = frames.Width()
	var/height = frames.Height()
	for(var/facing in list(SOUTH, EAST, WEST))
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				if(frames.GetPixel(x, y, null, facing))
					mask.shows_any = TRUE
					return TRUE
	return FALSE

/// The slots list memo[first][second], created on first use with `slots` empty slots.
/proc/bulge_memo_slots(alist/memo, first, second, slots)
	var/alist/by_second = memo[first]
	if(!by_second)
		by_second = alist()
		memo[first] = by_second
	var/list/found = by_second[second]
	if(!found)
		found = new /list(slots)
		by_second[second] = found
	return found

/// The slots list memo[first], created on first use with `slots` empty slots.
/proc/bulge_memo_list(alist/memo, first, slots)
	var/list/found = memo[first]
	if(!found)
		found = new /list(slots)
		memo[first] = found
	return found

/**
 * Decodes a sheet state into a print template, once per sheet and state: each pixel facing south, east and west with
 * its kind, read from its fixed grey (a kind map), or as cloth (a mask, when `mask`). North is never read: it is empty
 * in every template sheet. A state saved with one direction is read facing south every way, as getFlatIcon() treats
 * one. The template's key names its sheet and state, so no two sheets can share a cached template.
 */
/proc/bulge_decode_template(datum/bulge_sheet_state/where, mask)
	SHOULD_NOT_SLEEP(TRUE)
	var/key = "[where.icon]|[where.icon_state]"
	var/datum/bulge_print_template/template = GLOB.bulge_print_templates?[key]
	if(template)
		return template
	var/static/list/facings = list(SOUTH, EAST, WEST)
	var/icon/frames = icon(where.icon, where.icon_state, null, 1, 0)
	var/width = frames.Width()
	var/height = frames.Height()
	var/one_way = !length(icon_states(icon(frames, null, EAST)))
	if(one_way)
		stack_trace("Bulge template [where.icon_state] in [where.icon] has one direction; template sheets hold four.")
	template = new
	template.key = key
	template.icon = where.icon
	template.icon_state = where.icon_state
	var/top = 32 - where.pixel_y
	for(var/facing in facings)
		var/read = one_way ? SOUTH : facing
		var/list/found
		for(var/y in 1 to height)
			var/row = top - y
			for(var/x in 1 to width)
				var/pixel = frames.GetPixel(x, y, null, read)
				if(!pixel)
					continue
				var/kind = BULGE_KIND_CLOTH
				if(!mask)
					switch(pixel)
						if(BULGE_GREY_CLOTH)
							kind = BULGE_KIND_CLOTH
						if(BULGE_GREY_LIGHT)
							kind = BULGE_KIND_LIGHT
						if(BULGE_GREY_HIGHLIGHT)
							kind = BULGE_KIND_HIGHLIGHT
						if(BULGE_GREY_SHADE)
							kind = BULGE_KIND_SHADE
						if(BULGE_GREY_DEEP_SHADE)
							kind = BULGE_KIND_DEEP_SHADE
						else
							stack_trace("Bulge template [where.icon_state] has [pixel] at [x],[y], which is no kind's grey.")
							continue
				LAZYADD(found, list(where.pixel_x + x - 1, row, kind))
		switch(facing)
			if(SOUTH)
				template.south = found
			if(EAST)
				template.east = found
			if(WEST)
				template.west = found
	LAZYSET(GLOB.bulge_print_templates, key, template)
	return template

/**
 * The family whose shape, anatomy clearance or flap a family draws at a size up to its small_cap: itself, or the
 * family it names by design for that form (half_shapes_of, hard_shapes_of), except at the hard sizes in `own_sizes`,
 * the family's own of that kind (own_shape_sizes, own_clearance_sizes or own_flap_sizes).
 */
/proc/bulge_shape_owner(datum/bulge_family/family, hard, size, own_sizes)
	if(hard)
		var/datum/bulge_family/hard_owner = initial(family.hard_shapes_of)
		if(hard_owner && !(own_sizes & BULGE_SIZE_BIT(size)))
			return hard_owner
		return family
	return initial(family.half_shapes_of) || family

/// The size a family draws a bulge of `size` at: its own up to its cap for the form, the cap past it; 0 for none.
/proc/bulge_family_size(datum/bulge_family/family, hard, size)
	if(!ispath(family, /datum/bulge_family) || size < 1)
		return 0
	return min(size, hard ? initial(family.hard_cap) : initial(family.half_cap))

/**
 * The size whose shape a family draws for a bulge of `size` on a penis shape: bulge_family_size(), except that past the
 * family's small_cap, where shapes follow the penis shape, a shape with none of its own (bulge_hyper FALSE, the
 * tentacles) draws the family's small_cap shape, as any other shape draws at that size; 0 for none.
 */
/proc/bulge_shape_size(datum/bulge_family/family, hard, size, datum/sprite_accessory/genital/penis/shape)
	size = bulge_family_size(family, hard, size)
	if(!size)
		return 0
	var/small_cap = initial(family.small_cap)
	if(size > small_cap && ispath(shape, /datum/sprite_accessory/genital/penis) && !initial(shape.bulge_hyper))
		return small_cap
	return size

/**
 * Where a family's shape for an identity is (see bulge_shape()), or null when the family has none there. Where the
 * family has a precoloured printed patch (bulge_printed_patch()), the patch is drawn instead: no shape (the look shows
 * the anatomy the shape of large_shapes_of leaves bare, under the patch: bulge_resolve()). The sheet is
 * chosen by the garment's own family (a skirt reads skirt_shapes.dmi whichever family owns the shape), and a family
 * named by half_shapes_of, hard_shapes_of or large_shapes_of is followed one level only: it must own its shapes. Past
 * small_cap the shape has no sheet: the derived state named as bulge_large_name() names it.
 */
/proc/bulge_shape_where(datum/bulge_family/family, hard, size, digi, datum/sprite_accessory/genital/penis/shape, toned)
	size = bulge_shape_size(family, hard, size, shape)
	if(!size || (hard && initial(family.loincloth)))
		return null
	if(size > initial(family.small_cap) && initial(family.printed_patches) && size <= initial(family.print_cap))
		return null
	var/form = hard ? "hard" : "half"
	var/legs = digi ? "digi" : "plain"
	if(size <= initial(family.small_cap))
		var/datum/bulge_family/owner = bulge_shape_owner(family, hard, size, initial(family.own_shape_sizes))
		var/stem = initial(owner.shapes)
		if(isnull(stem))
			return null
		if(ispath(family, /datum/bulge_family/skirt))
			return bulge_sheet_state(BULGE_SHEET_SKIRT_SHAPES, "[stem]_[form]_[size]_[legs]", BULGE_SKIRT_SHAPES_X, BULGE_SKIRT_SHAPES_Y)
		return bulge_sheet_state(BULGE_SHEET_CLOTH_SMALL, "[stem]_[form]_[size]_[legs]", BULGE_CLOTH_SMALL_X, BULGE_CLOTH_SMALL_Y)
	var/name = bulge_large_name(initial(family.large_shapes_of) || family, hard, size, digi, shape, toned)
	if(isnull(name))
		return null
	return bulge_sheet_state(null, name, 0, 0)

/// The size whose shape a bulge past small_cap draws: past size 6, a penis whose sprite has stopped growing (its
/// size affix cap, with skin tones when toned) keeps size 6's shape.
/proc/bulge_large_size(size, datum/sprite_accessory/genital/penis/shape, toned)
	if(size <= 6)
		return size
	var/cap = initial(shape.max_sprite_size_affix)
	if(toned && initial(shape.skintone_max_sprite_size_affix))
		cap = initial(shape.skintone_max_sprite_size_affix)
	return max(6, min(size, cap + 1))

/**
 * The name of a shape past small_cap: "[shapes]_[form]_[size]_[legs]_[penis shape]", "_untoned" for a shape whose
 * untoned sprites have shapes of their own, drawn without skin tones; the size as bulge_large_size(). Legs are
 * digitigrade only where the family has digitigrade versions of that form.
 */
/proc/bulge_large_name(datum/bulge_family/owner, hard, size, digi, datum/sprite_accessory/genital/penis/shape, toned)
	var/stem = initial(owner.shapes)
	if(isnull(stem) || !ispath(shape, /datum/sprite_accessory/genital/penis) || !initial(shape.bulge_hyper))
		return null
	size = bulge_large_size(size, shape, toned)
	var/legs = digi && (initial(owner.large_digi_forms) & (hard ? BULGE_FORM_HARD : BULGE_FORM_HALF)) ? "digi" : "plain"
	var/untoned = !toned && initial(shape.bulge_untoned)
	return "[stem]_[hard ? "hard" : "half"]_[size]_[legs]_[initial(shape.icon_state)][untoned ? "_untoned" : ""]"

/**
 * One direction of a sprite the shapes past small_cap are derived from, frame 1, read once and kept for the round (as
 * many as the sprites have states and directions): its opaque pixels row by row from the top, as flat (index,
 * luminance) pairs. The index is row * 32 + column + 1, rows and columns from 0 at the top left; the luminance is that
 * of the pixel tinted with the skin tone, in thousandths, plus one. A penis or testicle sprite is read inside the window
 * those draw in (BULGE_SPRITE_*), a loincloth's (`whole`) all of it. Null where it has no opaque pixel, or no such state.
 */
/proc/bulge_sprite_pixels(icon_file, icon_state, facing, whole)
	var/static/alist/cache
	var/static/alist/lums
	var/key = "[icon_file]|[icon_state]|[facing]"
	var/found = cache?[key]
	if(!isnull(found))
		return found || null
	if(icon_exists(icon_file, icon_state))
		var/icon/frame = icon(icon_file, icon_state, facing, 1, 0)
		var/left = (whole || facing == WEST) ? 0 : (facing == EAST ? BULGE_SPRITE_EAST_LEFT : BULGE_SPRITE_SOUTH_LEFT)
		var/right = (whole || facing == EAST) ? 31 : (facing == WEST ? BULGE_SPRITE_WEST_RIGHT : BULGE_SPRITE_SOUTH_RIGHT)
		for(var/row in (whole ? 0 : BULGE_SPRITE_TOP) to 31)
			for(var/column in left to right)
				var/colour = frame.GetPixel(column + 1, 32 - row)
				if(!colour)
					continue
				var/lum = lums?[colour]
				if(!lum)
					var/list/channels = rgb2num(colour)
					lum = 1 + 299 * BULGE_SKIN_TINT(channels[1], 252) + 587 * BULGE_SKIN_TINT(channels[2], 204) + 114 * BULGE_SKIN_TINT(channels[3], 179)
					lums ||= alist()
					lums[colour] = lum
				LAZYADD(found, list(row * 32 + column + 1, lum))
	cache ||= alist()
	cache[key] = found || FALSE
	return found

/**
 * The state of a penis shape's sprite a shape past small_cap is derived from, as the approved previews chose it: drawn
 * in front, hard or half hard, skin-toned where the sprite has that and the shape is drawn toned, at `sprite_size` or
 * the largest smaller size the sprite has. Null where it has none.
 */
/proc/bulge_penis_state(datum/sprite_accessory/genital/penis/shape, sprite_size, hard, untoned)
	var/icon_file = initial(shape.icon)
	// A shape drawn in one colour (the human ones) has no colour channel in its states' names.
	var/channel = initial(shape.color_src) == USE_MATRIXED_COLORS ? "_primary" : ""
	for(var/size = sprite_size; size >= 1; size--)
		var/stem = "m_penis_[initial(shape.icon_state)]_[size]_[hard ? 1 : 0]"
		if(!untoned && icon_exists(icon_file, "[stem]_s_FRONT_UNDER[channel]"))
			return "[stem]_s_FRONT_UNDER[channel]"
		if(icon_exists(icon_file, "[stem]_FRONT_UNDER[channel]"))
			return "[stem]_FRONT_UNDER[channel]"
	return null

/**
 * Derives a shape past small_cap from the penis and testicle sprites by the approved rule (the preview pipeline's
 * hyper.py, ported exactly, in whole numbers): the cloth the bulge pushes out, as a kind map, or with `mask` the anatomy
 * it leaves bare, as a white mask (null where it covers the whole penis). Pixels facing south, east and west, in the
 * order bulge_decode_template() reads a sheet, as the sheet states it replaced held them. The kind map is kept for the
 * round, by its name, with the decoded templates; the mask is not (bulge_exposed() keeps the tile drawn from it).
 * Arguments as bulge_large_name(): `owner` is the family whose shapes past small_cap these are.
 */
/proc/bulge_derive_large(datum/bulge_family/owner, hard, size, digi, datum/sprite_accessory/genital/penis/shape, toned, mask)
	SHOULD_NOT_SLEEP(TRUE)
	var/static/list/facings = list(SOUTH, EAST, WEST)
	// A half-hard bulge pressed onto the thigh moves each pixel past the thigh's front to half its reach past it, rounded
	// half to even, at least one: the reach after, by the reach before (1 to 14).
	var/static/list/flattened = list(1, 1, 2, 2, 2, 3, 4, 4, 4, 5, 6, 6, 6, 7)
	// The 1.35 upscale's source of each pixel, round(anchor + (x - anchor) / 1.35) (no pixel sits within 0.0185 of a
	// half): by column about column 15, and by row about row 22 half hard (1 to 32) and about row 23 hard (33 to 64).
	var/static/list/scale_x = list(4, 5, 5, 6, 7, 8, 8, 9, 10, 11, 11, 12, 13, 14, 14, 15, 16, 16, 17, 18, 19, 19, 20, 21, 22, 22, 23, 24, 25, 25, 26, 27)
	var/static/list/scale_y = list(
		6, 6, 7, 8, 9, 9, 10, 11, 12, 12, 13, 14, 15, 15, 16, 17, 18, 18, 19, 20, 21, 21, 22, 23, 23, 24, 25, 26, 26, 27, 28, 29,
		6, 7, 7, 8, 9, 10, 10, 11, 12, 13, 13, 14, 15, 16, 16, 17, 18, 19, 19, 20, 21, 22, 22, 23, 24, 24, 25, 26, 27, 27, 28, 29,
	)
	var/name = bulge_large_name(owner, hard, size, digi, shape, toned)
	if(isnull(name))
		return null
	var/datum/bulge_print_template/template = mask ? null : GLOB.bulge_print_templates?[name]
	if(template)
		return template
	// The identity as bulge_large_name() names it.
	size = bulge_large_size(size, shape, toned)
	digi = digi && (initial(owner.large_digi_forms) & (hard ? BULGE_FORM_HARD : BULGE_FORM_HALF))
	var/untoned = !toned && initial(shape.bulge_untoned)
	// The sprite drawn at this size: one smaller, up to the shape's cap (its skin-toned sprites' own when toned).
	var/cap = initial(shape.max_sprite_size_affix)
	if(!untoned && initial(shape.has_skintone_shading) && initial(shape.skintone_max_sprite_size_affix))
		cap = initial(shape.skintone_max_sprite_size_affix)
	var/sprite_size = min(size - 1, cap)
	var/state = bulge_penis_state(shape, sprite_size, hard, untoned)
	if(!state)
		return null
	// The human penis at sprite size 4 facing south is its size 3 sprite drawn 1.35 times as large, about its root.
	var/scaled = (shape == /datum/sprite_accessory/genital/penis/human && sprite_size == 4) ? bulge_penis_state(shape, 3, hard, untoned) : null
	var/icon_file = initial(shape.icon)
	var/top = initial(owner.top_row)
	var/hem = initial(owner.hem)
	var/long = initial(owner.long)
	var/contained = long || (initial(owner.contained) & BULGE_SIZE_BIT(size))
	var/curtain = hard && (initial(owner.curtain) & BULGE_SIZE_BIT(size))
	// The thigh's front, in columns from the tile's west edge facing east (from its east edge facing west).
	var/front = digi ? 19 : 17
	template = new
	template.key = name
	template.icon_state = name
	var/anything = FALSE
	for(var/facing in facings)
		var/pressing = long && !hard && facing != SOUTH
		// What is drawn at each pixel, its luminance plus one: the testicles, then the penis over them, each pressed onto
		// the thigh when pressing (the first of its pixels to land on one stays). Where the penis is, and where either
		// was before pressing (the anatomy as it is drawn bare: `stacked`, unless pressing).
		var/list/stacked = new /list(1024)
		var/list/penis = new /list(1024)
		var/list/before = (pressing && mask) ? new /list(1024) : null
		for(var/layer in 1 to 2)
			var/list/pixels
			if(layer == 2 && scaled && facing == SOUTH)
				var/list/source = new /list(1024)
				pixels = bulge_sprite_pixels(icon_file, scaled, SOUTH)
				for(var/index = 1; index <= length(pixels); index += 2)
					source[pixels[index]] = pixels[index + 1]
				for(var/row in 0 to 31)
					for(var/column in 0 to 31)
						var/lum = source[scale_y[(hard ? 32 : 0) + row + 1] * 32 + scale_x[column + 1] + 1]
						if(lum)
							penis[row * 32 + column + 1] = TRUE
							stacked[row * 32 + column + 1] = lum
				continue
			pixels = layer == 1 ? bulge_sprite_pixels(BULGE_TESTICLES_SPRITE, BULGE_TESTICLES_STATE, facing) : bulge_sprite_pixels(icon_file, state, facing)
			for(var/index = 1; index <= length(pixels); index += 2)
				var/at = pixels[index]
				if(before)
					before[at] = TRUE
				if(pressing)
					var/column = (at - 1) & 31
					var/reach = facing == EAST ? column : 31 - column
					if(reach > front)
						reach = front + flattened[reach - front]
						at += (facing == EAST ? reach : 31 - reach) - column
				if(layer == 1)
					if(!stacked[at])
						stacked[at] = pixels[index + 1]
				else if(!penis[at])
					penis[at] = TRUE
					stacked[at] = pixels[index + 1]
		// The silhouette, with how far the penis reaches from the body (its tip, in columns from the tile's west edge
		// facing east and from its east edge facing west) and its lowest row.
		var/list/silhouette = list()
		var/tip = -1
		var/low = -1
		for(var/at in 1 to 1024)
			if(!stacked[at])
				continue
			silhouette += at
			if(penis[at])
				tip = max(tip, facing == WEST ? 31 - ((at - 1) & 31) : (at - 1) & 31)
				low = max(low, (at - 1) >> 5)
		// What the cloth covers: from top_row to the hem, or contained everything from top_row down but the penis's head,
		// its last three columns when hard facing east or west, or half hard (not in long legs) its two lowest rows when
		// they hang below the hem.
		var/list/grid = new /list(1024)
		for(var/at in silhouette)
			var/row = (at - 1) >> 5
			if(row < top)
				continue
			if(contained)
				if(penis[at])
					if(hard && facing != SOUTH)
						if((facing == WEST ? 31 - ((at - 1) & 31) : (at - 1) & 31) >= tip - 2)
							continue
					else if(!hard && !long && low > hem && row >= low - 1)
						continue
			else if(row > hem)
				continue
			grid[at] = TRUE
		var/list/found
		if(mask)
			// The bare anatomy: what the cloth leaves of the anatomy as drawn bare.
			for(var/row = 31; row >= 0; row--)
				for(var/column in 0 to 31)
					var/at = row * 32 + column + 1
					if(stacked[at] && !grid[at] && (before ? before[at] : TRUE))
						LAZYADD(found, list(column, row, BULGE_KIND_CLOTH))
		else
			// The cloth's kinds: its top edge light (the head of the penis under it highlit: hard, its last two columns
			// facing east or west and its top two rows facing south; half hard, its two lowest rows), its bottom edge in
			// shade, and inside it the luminance of what it covers, ranked between the darkest and the brightest:
			// light above 0.82, shade below 0.18, in whole numbers. The covered penis's reach, top and lowest row:
			var/lo = 0
			var/hi = 0
			var/outer = -1
			var/highest = 32
			var/lowest = -1
			for(var/at in silhouette)
				if(!grid[at])
					continue
				lo = lo ? min(lo, stacked[at]) : stacked[at]
				hi = max(hi, stacked[at])
				if(penis[at])
					outer = max(outer, facing == WEST ? 31 - ((at - 1) & 31) : (at - 1) & 31)
					highest = min(highest, (at - 1) >> 5)
					lowest = max(lowest, (at - 1) >> 5)
			var/span = max(1000, hi - lo)
			for(var/at in silhouette)
				if(!grid[at])
					continue
				var/row = (at - 1) >> 5
				var/kind
				if(row == 0 || !grid[at - 32])
					kind = BULGE_KIND_LIGHT
					if(penis[at])
						if(hard ? (facing == SOUTH ? row <= highest + 1 : abs((facing == WEST ? 31 - ((at - 1) & 31) : (at - 1) & 31) - outer) <= 1) : row >= lowest - 1)
							kind = BULGE_KIND_HIGHLIGHT
				else if(row == 31 || !grid[at + 32])
					kind = BULGE_KIND_SHADE
				else
					var/num = (stacked[at] - lo) * 50
					kind = num > 41 * span ? BULGE_KIND_LIGHT : (num < 9 * span ? BULGE_KIND_SHADE : BULGE_KIND_CLOTH)
				grid[at] = kind
			if(curtain && facing != SOUTH && outer >= 0)
				// A curtain: from the thigh's front at the hem (its base) to the tip, cloth hangs from what covers each column
				// (or from below the tip) down a curve to the hem; cloth off the covered penis at the curtain's outer side
				// or its bottom is in shade.
				var/sign = facing == EAST ? 1 : -1
				var/base = hem <= 21 ? 19 : (hem == 22 ? 18 : 17)
				var/list/pen = new /list(1024)
				var/deepest = -1 // The lowest row of the tip's column.
				for(var/at in silhouette)
					if(grid[at] && penis[at])
						pen[at] = TRUE
						if((facing == WEST ? 31 - ((at - 1) & 31) : (at - 1) & 31) == outer)
							deepest = max(deepest, (at - 1) >> 5)
				var/depth = hem - deepest
				if(outer > base + 1 && depth > 0)
					for(var/reach in base + 1 to outer)
						var/column = facing == EAST ? reach : 31 - reach
						var/start = deepest + 1
						for(var/row = 31; row >= 0; row--)
							if(grid[row * 32 + column + 1])
								start = row + 1
								break
						var/bottom = min(hem, deepest + round(depth * ((reach - base) / (outer - base)) ** 0.8, 1))
						for(var/row in start to bottom)
							if(!grid[row * 32 + column + 1])
								grid[row * 32 + column + 1] = BULGE_KIND_CLOTH
					for(var/at in 1 to 1024)
						if(grid[at] != BULGE_KIND_CLOTH || pen[at])
							continue
						var/side = ((at - 1) & 31) + sign
						if(side < 0 || side > 31 || !grid[at + sign] || at > 992 || !grid[at + 32])
							grid[at] = BULGE_KIND_SHADE
			for(var/row = 31; row >= top; row--)
				for(var/column in 0 to 31)
					var/kind = grid[row * 32 + column + 1]
					if(kind)
						LAZYADD(found, list(column, row, kind))
		switch(facing)
			if(SOUTH)
				template.south = found
			if(EAST)
				template.east = found
			if(WEST)
				template.west = found
		if(found)
			anything = TRUE
	if(mask)
		return anything ? template : null
	LAZYSET(GLOB.bulge_print_templates, name, template)
	return template

/**
 * The shape a garment of `family` bulges with, as a kind map (a /datum/bulge_print_template), or null where the family
 * has none. Decoded the first time, or past small_cap derived (bulge_derive_large()); then a few list reads.
 *
 * Arguments (positional; every one a scalar or a typepath):
 * * family - the garment's family typepath (its bulge_family).
 * * hard - TRUE when fully hard, FALSE when half hard.
 * * size - the bulge size, a whole number from 1 to 8; past the family's cap for the form, the cap's shape is drawn.
 * * digi - TRUE on digitigrade legs.
 * * shape - the penis shape's sprite accessory typepath; it matters past the family's small_cap.
 * * toned - whether the penis is drawn with skin tones (the organ's uses_skintones); it matters past small_cap.
 */
/proc/bulge_shape(family, hard, size, digi, shape, toned)
	SHOULD_NOT_SLEEP(TRUE)
	if(size < 1 || size > 8 || !ISINTEGER(size))
		return null
	if(shape && !ispath(shape, /datum/sprite_accessory/genital/penis))
		stack_trace("Bulge shape asked for with [shape], which is no penis shape typepath.")
		return null
	var/second = shape || family
	var/slot = BULGE_SHAPE_SLOT(hard, size, digi, toned)
	var/known = GLOB.bulge_shape_memo?[family]?[second]?[slot]
	if(!isnull(known))
		return known || null
	var/datum/bulge_family/family_type = family
	var/datum/bulge_sheet_state/where = bulge_shape_where(family, hard, size, digi, shape, toned)
	var/datum/bulge_print_template/template
	if(where)
		var/drawn = bulge_shape_size(family, hard, size, shape)
		if(drawn > initial(family_type.small_cap))
			template = bulge_derive_large(initial(family_type.large_shapes_of) || family, hard, drawn, digi, shape, toned, FALSE)
		else
			template = bulge_decode_template(where, FALSE)
	GLOB.bulge_shape_memo ||= alist()
	var/list/slots = bulge_memo_slots(GLOB.bulge_shape_memo, family, second, 64)
	slots[slot] = template || FALSE
	return template

/**
 * The anatomy a bulge past the family's small_cap leaves bare, as a white mask (a /datum/bulge_sheet_state): the
 * derived state of the bulge_shape() of the same identity, its tile drawn from the pixels bulge_derive_large() derives
 * for it. Null where nothing shows, the shape covering the whole penis. Arguments as bulge_shape().
 */
/proc/bulge_exposed(family, hard, size, digi, shape, toned)
	SHOULD_NOT_SLEEP(TRUE)
	if(size < 1 || size > 8 || !ISINTEGER(size))
		return null
	if(shape && !ispath(shape, /datum/sprite_accessory/genital/penis))
		stack_trace("Bulge exposed anatomy asked for with [shape], which is no penis shape typepath.")
		return null
	var/second = shape || family
	var/slot = BULGE_SHAPE_SLOT(hard, size, digi, toned)
	var/known = GLOB.bulge_exposed_memo?[family]?[second]?[slot]
	if(!isnull(known))
		return known || null
	var/datum/bulge_family/family_type = family
	var/datum/bulge_sheet_state/where = bulge_shape_where(family, hard, size, digi, shape, toned)
	var/drawn = bulge_shape_size(family, hard, size, shape)
	var/datum/bulge_sheet_state/exposed = (where && drawn > initial(family_type.small_cap)) ? where : null
	// Derived once per name: an identity whose name has its tile drawn (bulge_mask_tile()) shows it.
	if(exposed && !GLOB.bulge_mask_tiles?["[exposed.icon]|[exposed.icon_state]"])
		// Null where the shape covers the whole penis.
		var/datum/bulge_print_template/pixels = bulge_derive_large(initial(family_type.large_shapes_of) || family, hard, drawn, digi, shape, toned, TRUE)
		if(pixels)
			bulge_mask_tile(exposed, pixels) // Its tile, drawn from the derived pixels.
		else
			exposed = null
	GLOB.bulge_exposed_memo ||= alist()
	var/list/slots = bulge_memo_slots(GLOB.bulge_exposed_memo, family, second, 64)
	slots[slot] = exposed || FALSE
	return exposed

/**
 * Where a skirt's shaft shows through the cloth: the anatomy clearance mask (a /datum/bulge_sheet_state) for an
 * identity, or null when the family has none there. Named as the skirt's shape without its legs, in
 * skirt_clearance.dmi: a clearance is the same on plain and digitigrade legs. With a clearance the anatomy is drawn
 * behind the skirt and, inside the mask, above its cloth; an empty mask shows none of it above.
 */
/proc/bulge_clearance(family, hard, size)
	SHOULD_NOT_SLEEP(TRUE)
	if(size < 1 || size > 8 || !ISINTEGER(size))
		return null
	var/slot = BULGE_FORM_SLOT(hard, size, FALSE)
	var/known = GLOB.bulge_clearance_memo?[family]?[slot]
	if(!isnull(known))
		return known || null
	var/datum/bulge_family/family_type = family
	var/datum/bulge_sheet_state/clearance
	var/drawn = bulge_family_size(family, hard, size)
	if(drawn && initial(family_type.clearance))
		var/datum/bulge_family/owner = bulge_shape_owner(family, hard, drawn, initial(family_type.own_clearance_sizes))
		clearance = bulge_sheet_state(BULGE_SHEET_SKIRT_CLEARANCE, "[initial(owner.shapes)]_[hard ? "hard" : "half"]_[drawn]", BULGE_SKIRT_CLEARANCE_X, BULGE_SKIRT_CLEARANCE_Y)
	GLOB.bulge_clearance_memo ||= alist()
	var/list/slots = bulge_memo_list(GLOB.bulge_clearance_memo, family, 32)
	slots[slot] = clearance || FALSE
	return clearance

/**
 * The flap a revealing skirt cuts away from its cover when hard, as a decoded mask (a /datum/bulge_print_template,
 * every pixel cloth) for bulge_cut_cover_flap(), or null when the family cuts none. Named as the skirt's hard shape,
 * in skirt_flaps.dmi.
 */
/proc/bulge_flap(family, size, digi)
	SHOULD_NOT_SLEEP(TRUE)
	if(size < 1 || size > 8 || !ISINTEGER(size))
		return null
	var/slot = BULGE_FORM_SLOT(TRUE, size, digi)
	var/known = GLOB.bulge_flap_memo?[family]?[slot]
	if(!isnull(known))
		return known || null
	var/datum/bulge_family/family_type = family
	var/datum/bulge_print_template/flap
	var/drawn = bulge_family_size(family, TRUE, size)
	if(drawn && initial(family_type.flaps))
		var/datum/bulge_family/owner = bulge_shape_owner(family, TRUE, drawn, initial(family_type.own_flap_sizes))
		var/datum/bulge_sheet_state/where = bulge_sheet_state(BULGE_SHEET_SKIRT_FLAPS, "[initial(owner.shapes)]_hard_[drawn]_[digi ? "digi" : "plain"]", BULGE_SKIRT_FLAPS_X, BULGE_SKIRT_FLAPS_Y)
		if(where)
			flap = bulge_decode_template(where, TRUE)
	GLOB.bulge_flap_memo ||= alist()
	var/list/slots = bulge_memo_list(GLOB.bulge_flap_memo, family, 32)
	slots[slot] = flap || FALSE
	return flap

/**
 * The name of a loincloth's drape: "[drapes]_[penis shape]_[sprite size]", "_untoned" as bulge_large_name(), and
 * "_flat" from the family's flat_tip_from on a shape that grows past size 4.
 */
/proc/bulge_drape_name(datum/bulge_family/family, size, sprite_size, datum/sprite_accessory/genital/penis/shape, toned)
	var/stem = initial(family.drapes)
	if(isnull(stem) || !ispath(shape, /datum/sprite_accessory/genital/penis))
		return null
	var/untoned = !toned && initial(shape.bulge_untoned)
	var/flat_from = initial(family.flat_tip_from)
	var/flat = flat_from && size >= flat_from && initial(shape.bulge_hyper)
	return "[stem]_[initial(shape.icon_state)]_[sprite_size][untoned ? "_untoned" : ""][flat ? "_flat" : ""]"

/**
 * Derives a loincloth's drape, as bulge_drape_name() names it, by the approved rule (the preview pipeline's drape()
 * and reveal_frame(), preview_v7.py, and hyper.py's flat tip): facing east the flap's top edge follows the penis from
 * its hinge, up to BULGE_DRAPE_REACH columns, then the rest of the flap hangs past the tip or, from a penis reaching
 * further, drops over its side; facing west the same, mirrored; facing south the flap's top and hem rows where the
 * loincloth's own sprite has cloth. Kept for the round, by its name, with the decoded templates; pixels in the order
 * bulge_decode_template() reads a sheet. Arguments as bulge_drape_name().
 */
/proc/bulge_derive_drape(datum/bulge_family/family, size, sprite_size, datum/sprite_accessory/genital/penis/shape, toned)
	SHOULD_NOT_SLEEP(TRUE)
	var/name = bulge_drape_name(family, size, sprite_size, shape, toned)
	if(isnull(name))
		return null
	var/datum/bulge_print_template/template = GLOB.bulge_print_templates?[name]
	if(template)
		return template
	var/start_x = initial(family.start_x)
	var/start_y = initial(family.start_y)
	var/list/grid = new /list(1024) // Facing east.
	var/list/pixels
	var/hem
	if(!initial(shape.bulge_hyper) && sprite_size >= BULGE_DRAPE_ECLIPSE)
		grid[start_y * 32 + start_x + 1] = BULGE_KIND_LIGHT
		grid[start_y * 32 + start_x + 2] = BULGE_KIND_HIGHLIGHT
		hem = BULGE_DRAPE_TOP + 1
	else
		var/state = bulge_penis_state(shape, sprite_size, TRUE, !toned && initial(shape.bulge_untoned))
		if(!state)
			return null
		// The penis's top row in each column it reaches (by column, 0 to 31), and its tip, the last of them.
		var/list/columns = new /list(32)
		var/tip = -1
		pixels = bulge_sprite_pixels(initial(shape.icon), state, EAST)
		for(var/index = 1; index <= length(pixels); index += 2)
			var/column = (pixels[index] - 1) & 31
			if(isnull(columns[column + 1]))
				columns[column + 1] = (pixels[index] - 1) >> 5
			tip = max(tip, column)
		if(tip < 0)
			tip = start_x
		var/reach = min(tip, start_x + BULGE_DRAPE_REACH)
		var/row = start_y
		for(var/column in start_x to reach)
			if(!isnull(columns[column + 1]))
				row = min(columns[column + 1] - 1, 30)
			grid[row * 32 + column + 1] = BULGE_KIND_LIGHT
		grid[row * 32 + reach + 1] = BULGE_KIND_HIGHLIGHT
		if(tip <= start_x + BULGE_DRAPE_REACH)
			// The rest of the flap hangs past the tip, its last pixel in shade.
			var/depth = max(1, initial(family.drop) - (tip - start_x))
			if(tip < 31)
				for(var/index in 0 to depth - 1)
					if(row + index <= 30)
						grid[(row + index) * 32 + tip + 2] = (index == depth - 1 && depth > 1) ? BULGE_KIND_SHADE : BULGE_KIND_CLOTH
			hem = BULGE_DRAPE_TOP + depth
		else
			if(row < 31)
				grid[(row + 1) * 32 + reach + 1] = BULGE_KIND_CLOTH
			if(row < 30)
				grid[(row + 2) * 32 + reach + 1] = BULGE_KIND_SHADE
			hem = BULGE_DRAPE_TOP + 1
	var/flat_from = initial(family.flat_tip_from)
	if(flat_from && size >= flat_from && initial(shape.bulge_hyper))
		// A stiff flap's flat tip: in its last column, from BULGE_DRAPE_REACH past the hinge, only its top pixel stays.
		var/last = -1
		for(var/at in 1 to 1024)
			if(grid[at])
				last = max(last, (at - 1) & 31)
		if(last >= start_x + BULGE_DRAPE_REACH)
			var/kept = FALSE
			for(var/row in 0 to 31)
				if(grid[row * 32 + last + 1])
					if(kept)
						grid[row * 32 + last + 1] = null
					kept = TRUE
	template = new
	template.key = name
	template.icon_state = name
	var/list/garment = new /list(1024)
	pixels = bulge_sprite_pixels(initial(family.worn_icon), initial(family.worn_icon_state), SOUTH, TRUE)
	for(var/index = 1; index <= length(pixels); index += 2)
		garment[pixels[index]] = TRUE
	for(var/row in list(hem, BULGE_DRAPE_TOP))
		for(var/column in initial(family.first_column) to initial(family.last_column))
			if(garment[row * 32 + column + 1])
				LAZYADD(template.south, list(column, row, row == BULGE_DRAPE_TOP ? BULGE_KIND_LIGHT : BULGE_KIND_SHADE))
	for(var/row = 31; row >= 0; row--)
		for(var/column in 0 to 31)
			var/kind = grid[row * 32 + column + 1]
			if(kind)
				LAZYADD(template.east, list(column, row, kind))
			kind = grid[row * 32 + 31 - column + 1]
			if(kind)
				LAZYADD(template.west, list(column, row, kind))
	LAZYSET(GLOB.bulge_print_templates, name, template)
	return template

/**
 * The drape a hard loincloth hangs over the penis, as a kind map derived the first time (bulge_derive_drape()), or null
 * where it has none.
 *
 * Arguments (positional):
 * * family - the loincloth's family typepath.
 * * size - the bulge size, 1 to 8.
 * * sprite_size - the size of the penis sprite as the game draws it (its size affix, 1 to 7).
 * * shape - the penis shape's sprite accessory typepath.
 * * toned - whether the penis is drawn with skin tones.
 */
/proc/bulge_drape(family, size, sprite_size, shape, toned)
	SHOULD_NOT_SLEEP(TRUE)
	if(size < 1 || size > 8 || sprite_size < 1 || sprite_size > 7 || !ISINTEGER(size) || !ISINTEGER(sprite_size))
		return null
	var/second = shape || family
	var/slot = BULGE_DRAPE_SLOT(size, sprite_size, toned)
	var/known = GLOB.bulge_drape_memo?[family]?[second]?[slot]
	if(!isnull(known))
		return known || null
	var/datum/bulge_print_template/drape = ispath(family, /datum/bulge_family) ? bulge_derive_drape(family, size, sprite_size, shape, toned) : null
	GLOB.bulge_drape_memo ||= alist()
	var/list/slots = bulge_memo_slots(GLOB.bulge_drape_memo, family, second, 112)
	slots[slot] = drape || FALSE
	return drape

/**
 * The cut a hard loincloth takes under its drape (a derived /datum/bulge_sheet_state named "[drapes]_cut_[hem]", whose
 * keep mask says what of the garment stays inside the cut window), or null.
 * The cut follows the drape: at the lowest row its drape reaches facing south, or, for a drape that stays above the
 * hem rows there (a tentacle's stub), the family's lifted_hem. Its keep mask (bulge_patch_keep()) is cut from the
 * loincloth's own sprite as the approved previews cut it: facing south the flap's columns below the hem go, facing east
 * and west the flap's two columns from its hinge row down, facing north nothing. Arguments as bulge_drape().
 */
/proc/bulge_loincloth_cut(family, size, sprite_size, shape, toned)
	SHOULD_NOT_SLEEP(TRUE)
	var/static/list/facings = list(SOUTH, NORTH, EAST, WEST)
	if(size < 1 || size > 8 || sprite_size < 1 || sprite_size > 7 || !ISINTEGER(size) || !ISINTEGER(sprite_size))
		return null
	var/second = shape || family
	var/slot = BULGE_DRAPE_SLOT(size, sprite_size, toned)
	var/known = GLOB.bulge_loincloth_cut_memo?[family]?[second]?[slot]
	if(!isnull(known))
		return known || null
	var/datum/bulge_sheet_state/cut
	var/datum/bulge_print_template/drape = bulge_drape(family, size, sprite_size, shape, toned)
	if(drape)
		var/hem = -1
		var/list/south = drape.south
		for(var/index = 2; index <= length(south); index += 3)
			hem = max(hem, south[index])
		var/datum/bulge_family/family_type = family
		if(hem < BULGE_LOINCLOTH_TOP_HEM)
			hem = initial(family_type.lifted_hem)
		cut = bulge_sheet_state(null, "[initial(family_type.drapes)]_cut_[hem]", 0, 0)
		if(cut && !GLOB.bulge_patch_keeps?["[cut.icon]|[cut.icon_state]"])
			var/top = 32 - BULGE_LOINCLOTH_CUTS_Y - BULGE_LOINCLOTH_CUTS_SIZE
			// The flap's two columns facing east start one before its hinge.
			var/edge_x = initial(family_type.start_x) - 1
			var/edge_y = initial(family_type.start_y)
			var/list/erased = list()
			for(var/facing in facings)
				var/list/kept = new /list(1024)
				var/list/pixels = bulge_sprite_pixels(initial(family_type.worn_icon), initial(family_type.worn_icon_state), facing, TRUE)
				for(var/index = 1; index <= length(pixels); index += 2)
					kept[pixels[index]] = TRUE
				var/list/gone = list()
				for(var/row in top to top + BULGE_LOINCLOTH_CUTS_SIZE - 1)
					for(var/column in BULGE_LOINCLOTH_CUTS_X to BULGE_LOINCLOTH_CUTS_X + BULGE_LOINCLOTH_CUTS_SIZE - 1)
						var/at = row * 32 + column + 1
						switch(facing)
							if(SOUTH)
								if(row > hem && column >= initial(family_type.first_column) && column <= initial(family_type.last_column))
									kept[at] = FALSE
							if(EAST)
								if(row >= edge_y && column >= edge_x)
									kept[at] = FALSE
							if(WEST)
								if(row >= edge_y && column <= 31 - edge_x)
									kept[at] = FALSE
						if(!kept[at])
							gone += at
				erased += list(gone)
			bulge_patch_keep(cut, erased)
	GLOB.bulge_loincloth_cut_memo ||= alist()
	var/list/slots = bulge_memo_slots(GLOB.bulge_loincloth_cut_memo, family, second, 112)
	slots[slot] = cut || FALSE
	return cut

/**
 * A printed garment's precoloured patch past its family's small_cap (a /datum/bulge_sheet_state, drawn as it is),
 * or null when its prints there are derived or it has none. Arguments as bulge_shape(), without the penis shape.
 */
/proc/bulge_printed_patch(family, hard, size, digi)
	SHOULD_NOT_SLEEP(TRUE)
	if(size < 1 || size > 8 || !ISINTEGER(size))
		return null
	var/slot = BULGE_FORM_SLOT(hard, size, digi)
	var/known = GLOB.bulge_printed_patch_memo?[family]?[slot]
	if(!isnull(known))
		return known || null
	var/datum/bulge_family/family_type = family
	var/datum/bulge_sheet_state/patch
	if(ispath(family, /datum/bulge_family) && initial(family_type.printed_patches) && size > initial(family_type.small_cap) && size <= initial(family_type.print_cap))
		patch = bulge_sheet_state(BULGE_SHEET_PRINTED_PATCHES, "[initial(family_type.printed_patches)]_[hard ? "hard" : "half"]_[size]_[digi ? "digi" : "plain"]", BULGE_PRINTED_PATCHES_X, BULGE_PRINTED_PATCHES_Y)
	GLOB.bulge_printed_patch_memo ||= alist()
	var/list/slots = bulge_memo_list(GLOB.bulge_printed_patch_memo, family, 32)
	slots[slot] = patch || FALSE
	return patch

#undef BULGE_SHEET_CLOTH_SMALL
#undef BULGE_CLOTH_SMALL_X
#undef BULGE_CLOTH_SMALL_Y
#undef BULGE_SHEET_SKIRT_SHAPES
#undef BULGE_SKIRT_SHAPES_X
#undef BULGE_SKIRT_SHAPES_Y
#undef BULGE_SHEET_SKIRT_CLEARANCE
#undef BULGE_SKIRT_CLEARANCE_X
#undef BULGE_SKIRT_CLEARANCE_Y
#undef BULGE_SHEET_SKIRT_FLAPS
#undef BULGE_SKIRT_FLAPS_X
#undef BULGE_SKIRT_FLAPS_Y
#undef BULGE_LOINCLOTH_CUTS_X
#undef BULGE_LOINCLOTH_CUTS_Y
#undef BULGE_SHEET_PRINTED_PATCHES
#undef BULGE_PRINTED_PATCHES_X
#undef BULGE_PRINTED_PATCHES_Y
#undef BULGE_GREY_CLOTH
#undef BULGE_GREY_LIGHT
#undef BULGE_GREY_HIGHLIGHT
#undef BULGE_GREY_SHADE
#undef BULGE_GREY_DEEP_SHADE
#undef BULGE_LOINCLOTH_TOP_HEM
#undef BULGE_LOINCLOTH_CUTS_SIZE
#undef BULGE_TESTICLES_SPRITE
#undef BULGE_TESTICLES_STATE
#undef BULGE_SKIN_TINT
#undef BULGE_SPRITE_TOP
#undef BULGE_SPRITE_SOUTH_LEFT
#undef BULGE_SPRITE_SOUTH_RIGHT
#undef BULGE_SPRITE_EAST_LEFT
#undef BULGE_SPRITE_WEST_RIGHT
#undef BULGE_DRAPE_TOP
#undef BULGE_DRAPE_REACH
#undef BULGE_DRAPE_ECLIPSE
#undef BULGE_SHAPE_SLOT
#undef BULGE_FORM_SLOT
#undef BULGE_DRAPE_SLOT
#undef BULGE_GLOBAL_ALIST
