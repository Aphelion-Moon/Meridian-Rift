/// A pixel of the taur canvas as an index, from its column and row, both from 0.
#define DIRT_BLOOD_INDEX(column, row) ((row) * DIRT_TAUR_WIDTH + (column) + 1)
/// Whether a pixel lies on the taur canvas and in a mask (a list TRUE or null per pixel). Pass it variables or sums.
#define DIRT_BLOOD_ON(pixels, column, row) ((column) >= 0 && (column) < DIRT_TAUR_WIDTH && (row) >= 0 && (row) < ICON_SIZE_Y && (pixels)[DIRT_BLOOD_INDEX(column, row)])
/// A taur canvas index's column.
#define DIRT_BLOOD_COLUMN(index) (((index) - 1) % DIRT_TAUR_WIDTH)
/// A taur canvas index's row.
#define DIRT_BLOOD_ROW(index) floor(((index) - 1) / DIRT_TAUR_WIDTH)
// These set the look, the reference's soaked band. Changing any of them reshapes every taur's blood.
/// The most runs in a view.
#define DIRT_BLOOD_RUNS 3
/// Two runs' starts lie at least this many columns apart.
#define DIRT_BLOOD_GAP 3
/// Out of 255: a run steps a column aside on a row where its hash byte is under this.
#define DIRT_BLOOD_WOBBLE 40
/// The most rows of the rider's own pixels, between the hem and the carrier, that a run draws over.
#define DIRT_BLOOD_DROP 2
/// A run ends at least this many rows above where its column reaches the ground.
#define DIRT_BLOOD_FEET 5
/// The soaked band under the seam is at most this many rows deep.
#define DIRT_BLOOD_BAND 3
/// Out of 255: a band column no run takes is drawn where its hash byte is under this.
#define DIRT_BLOOD_BAND_KEEP 215
/// How many rows above a run's bulb a film pixel widens the run.
#define DIRT_BLOOD_THICKEN 2
/// Facing south, how many rows under the hem a run is 2 px wide.
#define DIRT_BLOOD_LIP_WIDE 2
/// Out of 255: one more than the most a variant adds to a stain pixel's alpha to change which dense columns run.
#define DIRT_BLOOD_PICK_JITTER 96
/// The lead run's share, in percent, of the rows its column has under the seam: from this...
#define DIRT_BLOOD_SHARE_LOW 80
/// ...to this.
#define DIRT_BLOOD_SHARE_HIGH 100
/// The fewest rows the lead run keeps, if its column has that many.
#define DIRT_BLOOD_MIN_ROWS 5
/// Facing east or west, how many carrier pixels a run keeps between it and the outline, where the body is wide enough.
#define DIRT_BLOOD_SIDE_INSET 2
/// How many of the lead run's first rows under the hem are drawn darkest, if the stain pixel above is body or core.
#define DIRT_BLOOD_DARK_HEAD 2
/// How thick every pixel lies.
#define DIRT_BLOOD_THICKNESS 0.9
/// How many of the stain's rows its mass is read from (dirt_blood_mass()): the crop's last kept row and those over it.
#define DIRT_BLOOD_MASS_ROWS 6
/// Out of 255: a stain pixel this dense counts toward its mass.
#define DIRT_BLOOD_MASS_ALPHA 64
/// Out of 255: a run starts only by a mass pixel this dense.
/// tg's armour stain fades to 88, and its uniform trickle is 92.
#define DIRT_BLOOD_SEED_DENSE 90
/// Facing east or west, the most pixels a run takes round the bend where the body turns into a coil.
#define DIRT_BLOOD_BEND 3
/// Pixels the body must stretch behind a run, on the ground, for its front to count as turning. A leg is 7 at most.
#define DIRT_BLOOD_TURN_REACH 10

/**
 * Returns the last stain row a taur's waist crop keeps in a direction, read from the crop itself (taur_waist_crop()).
 * That's the last of the rows from the top that the crop keeps whole. It's read once a direction.
 *
 * Arguments:
 * - direction: The direction.
 */
/proc/dirt_blood_last_kept_row(direction)
	var/static/alist/rows = alist()
	. = rows["[direction]"]
	if(!isnull(.))
		return
	var/icon/crop = taur_waist_crop()
	. = -1
	for(var/row in 0 to ICON_SIZE_Y - 1)
		var/whole = TRUE
		for(var/column in 1 to ICON_SIZE_X)
			// GetPixel() writes an opaque pixel as "#rrggbb"
			if(length(crop.GetPixel(column, ICON_SIZE_Y - row, null, direction)) != 7)
				whole = FALSE
				break
		if(!whole)
			break
		. = row
	rows["[direction]"] = .

/**
 * Returns where a worn blood stain meets a taur's waist crop in a direction, from the stain's last two kept rows of
 * dirt_blood_sheet_rows(). It's a list of two lists, both indexed by tile column + 1. The first holds the alpha of
 * each column's stain pixel on the crop's last kept row, out of 255, or null. The second holds TRUE in each column the
 * stain reaches in its last two kept rows, or null.
 *
 * Arguments:
 * - state: The stain's state in icons/effects/blood.dmi ("coatblood").
 * - direction: The direction.
 */
/proc/dirt_blood_seeds(state, direction)
	RETURN_TYPE(/list)
	var/static/alist/read = alist()
	var/key = "[state]|[direction]"
	. = read[key]
	if(.)
		return
	var/list/alphas = new /list(ICON_SIZE_X)
	var/list/near = new /list(ICON_SIZE_X)
	var/last_kept = dirt_blood_last_kept_row(direction)
	for(var/list/sheet_pixel as anything in dirt_blood_sheet_rows(state, direction))
		var/row = sheet_pixel[2]
		if(row < last_kept - 1)
			continue
		var/column = sheet_pixel[1]
		near[column + 1] = TRUE
		if(row == last_kept)
			alphas[column + 1] = sheet_pixel[3]
	. = list(alphas, near)
	read[key] = .

/**
 * Returns a worn blood stain's own pixels from tg's sheet, on the rows its mass is read from: DIRT_BLOOD_MASS_ROWS of
 * them, down to the crop's last kept row. They're read once a state and direction, as list(list(tile column, row from
 * the top, alpha out of 255), ...).
 *
 * Arguments:
 * - state: The stain's state in icons/effects/blood.dmi.
 * - direction: The direction.
 */
/proc/dirt_blood_sheet_rows(state, direction)
	RETURN_TYPE(/list)
	var/static/alist/read = alist()
	var/key = "[state]|[direction]"
	. = read[key]
	if(.)
		return
	. = list()
	var/last_kept = dirt_blood_last_kept_row(direction)
	if(last_kept >= DIRT_BLOOD_MASS_ROWS - 1 && icon_exists('icons/effects/blood.dmi', state))
		var/icon/sheet = icon('icons/effects/blood.dmi', state)
		for(var/row in last_kept - DIRT_BLOOD_MASS_ROWS + 1 to last_kept)
			for(var/column in 0 to ICON_SIZE_X - 1)
				var/colour = sheet.GetPixel(column + 1, ICON_SIZE_Y - row, null, direction)
				if(!colour)
					continue
				var/list/channels = rgb2num(colour)
				var/alpha = length(channels) > 3 ? channels[4] : 255
				if(alpha)
					. += list(list(column, row, alpha))
	read[key] = .

/**
 * Returns what of a stain a taur's blood may hang from, as it's drawn on the taur canvas: the stain's alpha out of 255
 * on each such pixel, else null. That's its mass: the largest 8-connected piece of its pixels at least
 * DIRT_BLOOD_MASS_ALPHA dense on its own rows (dirt_blood_sheet_rows()). A tie goes to the piece reaching lowest, then
 * to the leftmost. The mass also takes every other such piece of 2 px or more that touches the rider's hands drawn
 * over it, as the stain going on behind a hand. A uniform's stain is drawn under the hands, which hide it, and a
 * suit's over them. At a height that stretches the rider, its pieces are found on the sheet's own rows, as an Average
 * rider wears it. They're then drawn where the height draws each row. A row drawn twice or not at all changes no
 * piece's size, so the same columns run at every height.
 *
 * Arguments:
 * - state: The stain's state in icons/effects/blood.dmi.
 * - direction: The direction.
 * - seam_row: The row its blood starts on, the first under its drawn end.
 * - rows: The row each row shows at the rider's height (dirt_height_rows()), or null. If null, the stain's last kept
 *   row lies on the row over the seam.
 * - hands: TRUE on the canvas pixels the rider's hands are drawn on over it, in the rider's own rows, or null.
 */
/proc/dirt_blood_mass(state, direction, seam_row, list/rows, list/hands)
	RETURN_TYPE(/list)
	var/pixel_count = DIRT_TAUR_WIDTH * ICON_SIZE_Y
	var/list/shown = new /list(pixel_count)
	var/last_kept = dirt_blood_last_kept_row(direction)
	// stretched, it's on the sheet's own rows, else its last kept row goes over the seam
	var/row_shift = rows ? 0 : seam_row - 1 - last_kept
	for(var/list/sheet_pixel as anything in dirt_blood_sheet_rows(state, direction))
		var/canvas_column = sheet_pixel[1] + DIRT_TAUR_INSET
		var/drawn_row = sheet_pixel[2] + row_shift
		if(drawn_row >= 0 && drawn_row < ICON_SIZE_Y && !hands?[DIRT_BLOOD_INDEX(canvas_column, drawn_row)])
			shown[DIRT_BLOOD_INDEX(canvas_column, drawn_row)] = sheet_pixel[3]
	// its dense pieces, row-major by their first pixel
	var/list/pieces = list()
	var/list/piece_of = new /list(pixel_count)
	for(var/start in 1 to pixel_count)
		if(shown[start] < DIRT_BLOOD_MASS_ALPHA || piece_of[start])
			continue
		pieces += list(dirt_blood_piece(shown, start, piece_of, DIRT_BLOOD_MASS_ALPHA))
	var/list/mass = new /list(pixel_count)
	var/list/main
	var/main_low = -1
	var/main_left = 0
	for(var/list/piece as anything in pieces)
		var/low = -1
		var/left = DIRT_TAUR_WIDTH
		for(var/index in piece)
			low = max(low, DIRT_BLOOD_ROW(index))
			left = min(left, DIRT_BLOOD_COLUMN(index))
		if(!main || length(piece) > length(main) || (length(piece) == length(main) && (low > main_low || (low == main_low && left < main_left))))
			main = piece
			main_low = low
			main_left = left
	for(var/list/piece as anything in pieces)
		var/kept = piece == main
		if(!kept && hands && length(piece) >= 2)
			for(var/index in piece)
				if(dirt_blood_touches(hands, index))
					kept = TRUE
					break
		if(kept)
			for(var/index in piece)
				mass[index] = shown[index]
	return rows ? dirt_blood_rows_drawn(mass, rows) : mass

/**
 * Returns the 8-connected piece of the taur canvas that a pixel starts, as its indexes in the order they're found, and
 * marks each as taken.
 *
 * Arguments:
 * - pixels: A number or null per pixel. The piece takes the pixels holding at least `minimum`.
 * - start: The first pixel, which must hold at least `minimum`.
 * - piece_of: TRUE on the pixels already in a piece. It's changed in place.
 * - minimum: The least a pixel holds to be in the piece.
 */
/proc/dirt_blood_piece(list/pixels, start, list/piece_of, minimum)
	RETURN_TYPE(/list)
	var/list/piece = list(start)
	piece_of[start] = TRUE
	// the piece grows as it's walked, and every pixel goes in once
	for(var/position in 1 to length(pixels))
		if(position > length(piece))
			break
		var/column = DIRT_BLOOD_COLUMN(piece[position])
		var/row = DIRT_BLOOD_ROW(piece[position])
		for(var/near_row in row - 1 to row + 1)
			for(var/near_column in column - 1 to column + 1)
				if(near_column < 0 || near_column >= DIRT_TAUR_WIDTH || near_row < 0 || near_row >= ICON_SIZE_Y)
					continue
				var/near = DIRT_BLOOD_INDEX(near_column, near_row)
				if(pixels[near] >= minimum && !piece_of[near])
					piece_of[near] = TRUE
					piece += near
	return piece

/**
 * Returns whether a pixel of the taur canvas, or one of the eight round it, is in a mask.
 *
 * Arguments:
 * - pixels: TRUE or a value, or null, per pixel.
 * - index: The pixel.
 */
/proc/dirt_blood_touches(list/pixels, index)
	var/column = DIRT_BLOOD_COLUMN(index)
	var/row = DIRT_BLOOD_ROW(index)
	for(var/near_row in row - 1 to row + 1)
		for(var/near_column in column - 1 to column + 1)
			if(DIRT_BLOOD_ON(pixels, near_column, near_row))
				return TRUE
	return FALSE

/**
 * Returns the row of the 32 px tile, from the top, that a taur's blood starts on below its garment's stain, at the
 * rider's height. It's one under the stain's last drawn row: the last row showing one of the rows the crop keeps. The
 * stain is cut at the waist before the height filter stretches the rider. The stretch moves that row, while the taur
 * body under it stays put. The crop keeps the same rows facing every way. A stain moved for a species-shaped sheet
 * (/obj/item/var/worn_effect_offset) isn't counted, because no such species is a taur by default.
 *
 * Arguments:
 * - rows: The row each row shows at the rider's height (dirt_height_rows()), or null at a height that stretches nothing.
 */
/proc/dirt_blood_seam_row(list/rows)
	var/last_kept = dirt_blood_last_kept_row(SOUTH)
	. = last_kept + 1
	if(!rows)
		return
	for(var/drawn_row in ICON_SIZE_Y - 1 to 0 step -1)
		var/source_row = rows[drawn_row + 1]
		if(!isnull(source_row) && source_row <= last_kept)
			return drawn_row + 1

/**
 * Returns which row of a 32 px tall image each of its rows shows once a person's height stretches it, as their rider
 * and a taur-fitted garment are drawn (apply_height(), ENTIRE_BODY). The list is by row + 1, from the top, and holds
 * the row each row shows, or null where it shows none. Returns null at a height that stretches nothing. Each filter is
 * a displacement map whose green moves a row by up to its size (128 none, 0 a size up, 255 a size down), read at the
 * nearest row, in the filters' order. It's read once a height from the maps the game puts on.
 *
 * Arguments:
 * - body: The person.
 */
/proc/dirt_height_rows(mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	if(body.mob_height == HUMAN_HEIGHT_MEDIUM)
		return null
	var/static/alist/by_height = alist()
	var/height_key = "[body.mob_height]"
	. = by_height[height_key]
	if(.)
		return
	var/mutable_appearance/probe = new
	body.apply_height(probe, ENTIRE_BODY)
	var/list/shows
	for(var/list/filter_info as anything in probe.filter_data)
		if(filter_info["type"] != "displace")
			continue
		if(!shows)
			shows = list()
			for(var/row in 0 to ICON_SIZE_Y - 1)
				shows += row
		var/icon/map = filter_info["icon"]
		var/size = filter_info["size"]
		var/list/moved = new /list(ICON_SIZE_Y)
		for(var/row in 0 to ICON_SIZE_Y - 1)
			var/colour = map.GetPixel(floor(map.Width() / 2), ICON_SIZE_Y - row)
			var/source_row = colour ? floor(row + (rgb2num(colour)[2] - 128) / 127 * size + 0.5) : row
			if(source_row >= 0 && source_row < ICON_SIZE_Y)
				moved[row + 1] = shows[source_row + 1]
		shows = moved
	// a body that stretches nothing at this height (a preview's) isn't cached for other bodies
	if(shows)
		by_height[height_key] = shows
	return shows

/**
 * Returns a bloodied garment's blood as a material key, "blood#RRGGBB", in the colour its stain is drawn in.
 *
 * Arguments:
 * - garment: The garment.
 */
/proc/dirt_blood_material_key(obj/item/garment)
	var/list/channels = rgb2num(garment.get_blood_dna_color())
	return "[DIRT_MATERIAL_BLOOD][uppertext(rgb(channels[1], channels[2], channels[3]))]"

/**
 * Returns the variant a garment's blood draws in, 0 to DIRT_VARIANTS - 1. It's a hash of the garment's first blood
 * DNA, so two taurs bloodied by different people differ, and one taur's blood never flickers.
 *
 * Arguments:
 * - garment: The bloodied garment.
 */
/proc/dirt_blood_variant(obj/item/garment)
	var/list/blood = GET_ATOM_BLOOD_DECALS(garment)
	return length(blood) ? hex2num(copytext(md5("[blood[1]]"), 1, 7)) % DIRT_VARIANTS : 0

/**
 * Returns what a taur's blood below the waist is drawn from now, or null for none: list(the bloodied garments' stains,
 * the taur-fitted garment's sprite or null, whether the taur body draws, that garment's slot or null, the outermost
 * bloodied garment's slot). Each stain is list(its state in icons/effects/blood.dmi, its material key, its variant,
 * and for a uniform under a suit the suit's sprite and where its wrapper has the tile (dirt_worn_shift(), null where
 * it's on the tile), or null), with the suit's first. A garment counts while it's drawn and its stain is cut at the
 * waist (/obj/item/clothing/proc/cuts_effects_at_taur_waist()), on a taur that takes dirt (dirt_read_source()). A
 * garment's rips draw nothing. The outermost taur-fitted garment (dirt_taur_suit_sprite()) carries what lies on its
 * cloth, and the taur body, while it draws, carries the rest. It's read from the garments and the sprites drawn, so
 * it's never stored, and nothing changes when it goes.
 *
 * Arguments:
 * - wearer: The person.
 * - drawing: A garment being drawn now, whose sprite isn't in overlays_standing yet, or null.
 * - draw_target: That garment's sprite as worn.
 */
/proc/dirt_taur_blood_inputs(mob/living/carbon/human/wearer, obj/item/drawing = null, mutable_appearance/draw_target = null)
	RETURN_TYPE(/list)
	// as get_organ_slot(), but read from the slot list itself, because most bodies stop here
	var/obj/item/organ/taur_body/organ = wearer.organs_slot[ORGAN_SLOT_EXTERNAL_TAUR]
	if(!istype(organ))
		return null
	var/obj/item/clothing/suit/suit = wearer.wear_suit
	var/obj/item/clothing/under/uniform = wearer.w_uniform
	// most taurs' draws find no blood, so they stop here, at a plain length before the visible blood's list
	var/suit_bloodied = istype(suit) && GET_ATOM_BLOOD_DNA_LENGTH(suit) && GET_ATOM_BLOOD_DECAL_LENGTH(suit) && suit.cuts_effects_at_taur_waist(wearer) && !HAS_TRAIT(suit, TRAIT_NO_WORN_ICON)
	var/uniform_bloodied = istype(uniform) && GET_ATOM_BLOOD_DNA_LENGTH(uniform) && GET_ATOM_BLOOD_DECAL_LENGTH(uniform) && uniform.cuts_effects_at_taur_waist(wearer) && !HAS_TRAIT(uniform, TRAIT_NO_WORN_ICON) && !(wearer.obscured_slots & HIDEJUMPSUIT)
	if(!suit_bloodied && !uniform_bloodied)
		return null
	var/obj/item/bodypart/chest = wearer.get_bodypart(BODY_ZONE_CHEST)
	var/datum/bodypart_overlay/mutant/taur_body/taur = organ.bodypart_overlay
	if(!istype(taur) || !chest || !taur.dirt_read_source(chest))
		return null
	// each worn sprite as drawn: the one being built now, else the one drawn last
	var/image/suit_sprite
	if(wearer.wear_suit)
		suit_sprite = drawing == wearer.wear_suit ? draw_target : bulge_drawn_leaf(bulge_drawn_root(wearer.overlays_standing[SUIT_LAYER]))
	var/image/uniform_sprite
	if(wearer.w_uniform && !(wearer.obscured_slots & HIDEJUMPSUIT))
		uniform_sprite = drawing == wearer.w_uniform ? draw_target : bulge_drawn_leaf(bulge_drawn_root(wearer.overlays_standing[UNIFORM_LAYER]))
	var/list/stains = list()
	if(suit_bloodied)
		stains += list(list("[suit.blood_overlay_type]blood", dirt_blood_material_key(suit), dirt_blood_variant(suit), null, null, null))
	if(uniform_bloodied)
		var/list/stain = list("uniformblood", dirt_blood_material_key(uniform), dirt_blood_variant(uniform), null, null, null)
		// a suit drawn over it hides its stain where the suit's sprite reaches the crop's last row
		if(suit_sprite?.icon)
			var/list/shift = dirt_worn_shift(wearer.wear_suit)
			stain[4] = suit_sprite.icon
			stain[5] = suit_sprite.icon_state
			stain[6] = (shift[1] || shift[2]) ? shift : null
		stains += list(stain)
	var/list/cloth
	var/cloth_slot
	if(suit_sprite?.icon && dirt_taur_suit_sprite(suit_sprite.icon, wearer))
		cloth = list(suit_sprite.icon, suit_sprite.icon_state)
		cloth_slot = ITEM_SLOT_OCLOTHING
	else if(uniform_sprite?.icon && dirt_taur_suit_sprite(uniform_sprite.icon, wearer))
		cloth = list(uniform_sprite.icon, uniform_sprite.icon_state)
		cloth_slot = ITEM_SLOT_ICLOTHING
	var/body_draws = taur.can_draw_on_bodypart(chest, wearer)
	if(!body_draws && !cloth)
		return null
	return list(stains, cloth, body_draws, cloth_slot, suit_bloodied ? ITEM_SLOT_OCLOTHING : ITEM_SLOT_ICLOTHING)

/**
 * Returns whether the blood run down below a taur's waist onto a taur-fitted garment's cloth draws over that garment's
 * dirt. It does while the blood landed after the garment's newest dirt. On the outermost bloodied garment, that's its
 * own stain's side (dirt_stain_over()), so the run keeps that side across the hem. Blood run from another garment
 * landed when the person's carrier last saw blood land at the waist (waist_blood_landed). The taur body's share takes
 * its own side, against the body's own dirt (/datum/component/dirtiness/proc/waist_blood_over()).
 *
 * Arguments:
 * - wearer: The taur.
 * - inputs: From dirt_taur_blood_inputs().
 */
/proc/dirt_cloth_run_over(mob/living/carbon/human/wearer, list/inputs)
	var/obj/item/cloth = wearer.get_item_by_slot(inputs[4])
	if(inputs[4] == inputs[5])
		return dirt_stain_over(cloth)
	var/datum/component/dirtiness/cloth_carrier = cloth.GetComponent(/datum/component/dirtiness)
	if(!length(cloth_carrier?.mess_splats))
		return TRUE
	var/datum/component/dirtiness/wearer_carrier = wearer.GetComponent(/datum/component/dirtiness)
	return wearer_carrier?.waist_blood_landed > cloth_carrier.dirt_landed

/**
 * Returns whether the blood below a taur's waist draws over the dirt on their taur body. While the body holds dirt, it
 * does when blood last landed after that dirt (waist_blood_landed, taur_dirt_landed). The garments' own dirt plays no
 * part. So at the waist, a stain can draw under its garment's dirt while the run below it draws over the body's.
 */
/datum/component/dirtiness/proc/waist_blood_over()
	return (length(part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR]) || length(part_splats?[ORGAN_SLOT_EXTERNAL_TAUR])) && waist_blood_landed > taur_dirt_landed

/datum/component/dirtiness
	/// The suit whose blood DNA list is suit_blood_seen, as a weakref. So another suit holding the same list counts as
	/// blood landing (note_waist_blood()).
	var/datum/weakref/suit_blood_garment
	/// The uniform whose blood DNA list is uniform_blood_seen, as a weakref.
	var/datum/weakref/uniform_blood_garment

/**
 * Notes blood landing on the uniform or suit a taur wears, while its stain runs below the waist (dirt_waist_blood()).
 * Blood counts as landed now (waist_blood_landed) on a garment other than the one last seen in its slot. A blood DNA
 * list the garment didn't hold when last seen counts too, unless its merge added only blood that draws no stain
 * (dirt_waist_blood_landed()). A merge makes a new list, so the same DNA landing again counts too. A garment's first
 * blood is the list it was given, and another garment given that list holds it too. So each slot notes its garment
 * beside its list. A bloodied garment put on counts as its blood landing when it's first noted here. Taking a garment
 * off and putting it back on counts nothing, unless another bloodied one was worn in that slot meanwhile. It can be
 * called whenever blood may have landed, as blood lands or as a slot draws. Blood it has noted counts once. On a body
 * that isn't a taur, it returns at once.
 *
 * Arguments:
 * - body: The person this carrier is on.
 * - stamp: Whether blood not seen before counts as landed now. Otherwise it's only noted, as blood that landed before
 *   this carrier was made.
 */
/datum/component/dirtiness/proc/note_waist_blood(mob/living/carbon/human/body, stamp = TRUE)
	// only a taur's uniform or suit is cut at the waist (cuts_effects_at_taur_waist())
	if(!(body.bodyshape & BODYSHAPE_TAUR))
		return
	var/obj/item/clothing/suit = body.wear_suit
	var/obj/item/clothing/uniform = body.w_uniform
	var/list/suit_blood = dirt_waist_blood(suit, body)
	// a uniform the suit hides runs no blood until it shows, as dirt_taur_blood_inputs() reads it, but a new carrier
	// notes its blood all the same, as landed before the carrier
	var/list/uniform_blood = (!stamp || !(body.obscured_slots & HIDEJUMPSUIT)) && dirt_waist_blood(uniform, body)
	var/landed = dirt_waist_blood_landed(suit, suit_blood, suit_blood_seen, suit_blood_garment) || dirt_waist_blood_landed(uniform, uniform_blood, uniform_blood_seen, uniform_blood_garment)
	if(suit_blood)
		suit_blood_seen = suit_blood
		suit_blood_garment = WEAKREF(suit)
	if(uniform_blood)
		uniform_blood_seen = uniform_blood
		uniform_blood_garment = WEAKREF(uniform)
	if(landed && stamp)
		waist_blood_landed = SSdirt.next_serial()

/**
 * Returns whether a worn garment holds blood landed since note_waist_blood() last saw its slot. It does if it's another
 * garment than the one seen there, or its blood DNA list is new. A merge makes a new list. The merge counts when it
 * added blood that draws a stain on items, or added no DNA at all, as the same blood landing again. A merge that added
 * only blood that draws no stain counts nothing.
 *
 * Arguments:
 * - garment: The garment in the slot, or null.
 * - blood: Its list now (dirt_waist_blood()), or null.
 * - seen: The list last seen in its slot, or null.
 * - seen_garment: The garment that list was seen on, as a weakref, or null.
 */
/proc/dirt_waist_blood_landed(obj/item/garment, list/blood, list/seen, datum/weakref/seen_garment)
	if(!blood)
		return FALSE
	if(!seen || !seen_garment || seen_garment != garment.weak_reference)
		return TRUE
	if(blood == seen)
		return FALSE
	var/list/added = list()
	for(var/dna, blood_type in blood)
		if(!seen[dna])
			added[dna] = blood_type
	return !length(added) || has_blood_flag(added, BLOOD_COVER_ITEMS)

/**
 * Returns a worn garment's blood DNA as its forensics hold it, while the garment shows a stain cut at its taur wearer's
 * waist (/obj/item/clothing/proc/cuts_effects_at_taur_waist()). So its blood runs below the waist, as
 * dirt_taur_blood_inputs() reads it. Returns null otherwise, as for a garment whose blood draws no stain on items, or
 * one drawn with no sprite.
 *
 * Arguments:
 * - garment: The worn uniform or suit, or null.
 * - wearer: Who wears it.
 */
/proc/dirt_waist_blood(obj/item/clothing/garment, mob/living/carbon/human/wearer)
	RETURN_TYPE(/list)
	if(!istype(garment) || !GET_ATOM_BLOOD_DNA_LENGTH(garment) || !garment.cuts_effects_at_taur_waist(wearer) || HAS_TRAIT(garment, TRAIT_NO_WORN_ICON) || !GET_ATOM_BLOOD_DECAL_LENGTH(garment))
		return null
	return garment.forensics.blood_DNA

/**
 * Returns what a person's blood masks are made from, as a request holds it (/datum/dirt_mask_request/var/blood):
 * list(the stains, the taur-fitted garment's sprite or null, whether the taur body draws, the seam row, the rows the
 * rider and a taur-fitted garment show at the rider's height (dirt_height_rows()) or null). It's worked out as the game
 * draws it at that height. The taur body stays put, the rider and the garment stretch, and the blood starts where the
 * height puts the stain's end (dirt_blood_seam_row()). The taur body and the garment's cloth each keep their share of
 * the one shape, so a run crossing the garment's hem onto the body meets itself there. The cloth's share goes back to
 * the garment's own rows, where it starts on an Average rider's seam row (dirt_blood_rasterise()).
 *
 * Arguments:
 * - inputs: From dirt_taur_blood_inputs().
 * - body: The person.
 */
/proc/dirt_taur_blood_data(list/inputs, mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	var/list/rows = dirt_height_rows(body)
	return list(inputs[1], inputs[2], inputs[3], dirt_blood_seam_row(rows), rows)

/**
 * Returns blood masks' data as one line of text, to key the masks by and to tell when the data changes. Given the taur
 * body, it starts with the body's shape, as a drawing of the blood checks it (/datum/dirt_drawing/var/parts_key).
 *
 * Arguments:
 * - blood: From dirt_taur_blood_data().
 * - source: The taur body as dirt reads it, or null.
 * - materials: Whether it holds each stain's material. Without them it keys what blood's shape alone depends on.
 */
/proc/dirt_taur_blood_key(list/blood, datum/dirt_taur_source/source = null, materials = TRUE)
	var/list/parts = source ? list(source.shape_key()) : list()
	for(var/list/stain as anything in blood[1])
		var/list/shift = stain[6]
		parts += "[stain[1]]:[materials ? stain[2] : ""]:[stain[3]][stain[4] ? ":[dirt_sprite_key(stain[4])]:[stain[5]][shift ? ":[shift[1]],[shift[2]]" : ""]" : ""]"
	var/list/cloth = blood[2]
	parts += cloth ? "cloth:[dirt_sprite_key(cloth[1])]:[cloth[2]]" : "bare"
	parts += "body:[blood[3] ? 1 : 0]|seam:[blood[4]]"
	// an Average rider's key leaves the rows out
	if(blood[5])
		parts += "rows:[jointext(blood[5], ",")]"
	return jointext(parts, "|")

/**
 * Returns what the taur canvas holds for blood in one direction, as the game draws it at the rider's height. It's a
 * list of five. The first, its owners, is what each pixel shows, as dirt_taur_owners() stacks the game's own draw order
 * (dirt_taur_drawn_stack()). The second is the carriers' pixels: the taur body's (while it draws) and the taur-fitted
 * garment's. The third is those of them that show, the fourth the rider's pixels that show off them, and the fifth the
 * rider's hands, drawn over a uniform, in the rider's own rows (dirt_blood_mass()). The last four are masks, each a
 * list TRUE or null per pixel. The rider and the garment are drawn stretched by the height (the data's rows), and the
 * taur body where it is. Its owners are a list of its own. Facing north, where blood draws nothing
 * (dirt_blood_continuation()), the owners are empty and the masks null.
 *
 * Arguments:
 * - source: The taur body as dirt reads it.
 * - rider: The rider's surface in that direction, or null.
 * - direction: The direction.
 * - blood: From dirt_taur_blood_data().
 */
/proc/dirt_blood_carriers(datum/dirt_taur_source/source, datum/dirt_surface/rider, direction, list/blood)
	RETURN_TYPE(/list)
	if(direction == NORTH)
		return list(new /list(DIRT_TAUR_WIDTH * ICON_SIZE_Y), null, null, null, null)
	var/static/list/hidden_stack = list(DIRT_TAUR_RIDER, DIRT_TAUR_CLOTH)
	var/list/cloth = blood[2]
	var/list/rows = blood[5]
	var/list/cloth_pixels = cloth ? dirt_sprite_pixels(cloth[1], cloth[2], direction, DIRT_TAUR_WIDTH, ICON_SIZE_Y) : null
	if(cloth_pixels && rows)
		cloth_pixels = dirt_blood_stretched(cloth_pixels, rows)
	var/body_draws = blood[3]
	var/list/owners = dirt_taur_owners(source, rider, direction, body_draws ? dirt_taur_drawn_stack() : hidden_stack, cloth_pixels, rows)
	var/list/surface = new /list(length(owners))
	for(var/index in cloth_pixels)
		surface[index] = TRUE
	if(body_draws)
		for(var/layer_key in source.stack)
			if(layer_key == DIRT_TAUR_RIDER)
				continue
			var/sheet = source.sheet_of(layer_key)
			for(var/state in source.layer_states[layer_key])
				for(var/index in dirt_sprite_pixels(sheet, state, direction, DIRT_TAUR_WIDTH, ICON_SIZE_Y))
					surface[index] = TRUE
	var/list/visible = new /list(length(owners))
	var/list/rider_shown = new /list(length(owners))
	for(var/index in 1 to length(owners))
		var/shown = owners[index]
		if(!shown)
			continue
		if(shown != DIRT_TAUR_RIDER)
			visible[index] = TRUE
		else if(!surface[index])
			rider_shown[index] = TRUE
	var/list/hands = new /list(length(owners))
	if(rider)
		var/list/zones = dirt_pixel_zones()
		var/left_hand = zones[BODY_ZONE_PRECISE_L_HAND]
		var/right_hand = zones[BODY_ZONE_PRECISE_R_HAND]
		var/list/flags_of = rider.flags_of
		for(var/row in 0 to ICON_SIZE_Y - 1)
			for(var/column in 0 to ICON_SIZE_X - 1)
				var/zone = DIRT_PIXEL_ZONE(flags_of[row * ICON_SIZE_X + column + 1])
				if(zone == left_hand || zone == right_hand)
					hands[DIRT_BLOOD_INDEX(column + DIRT_TAUR_INSET, row)] = TRUE
	return list(owners, surface, visible, rider_shown, hands)

/**
 * Returns a sprite's pixels on the taur canvas as its height filter draws them. Each row shows the row of the sprite
 * it's drawn from.
 *
 * Arguments:
 * - pixels: The sprite's pixels as indexes, as dirt_sprite_pixels() reads them.
 * - rows: The row each row shows (dirt_height_rows()).
 */
/proc/dirt_blood_stretched(list/pixels, list/rows)
	RETURN_TYPE(/list)
	var/list/held = new /list(DIRT_TAUR_WIDTH * ICON_SIZE_Y)
	for(var/index in pixels)
		held[index] = TRUE
	var/list/drawn = dirt_blood_rows_drawn(held, rows)
	. = list()
	for(var/index in 1 to length(drawn))
		if(drawn[index])
			. += index

/**
 * Returns what a list on the taur canvas holds once its height filter draws it. Each row holds what the row it shows
 * holds. A row that shows none holds nothing.
 *
 * Arguments:
 * - values: A value or null per pixel.
 * - rows: The row each row shows (dirt_height_rows()).
 */
/proc/dirt_blood_rows_drawn(list/values, list/rows)
	RETURN_TYPE(/list)
	. = new /list(DIRT_TAUR_WIDTH * ICON_SIZE_Y)
	for(var/drawn_row in 0 to ICON_SIZE_Y - 1)
		var/source_row = rows[drawn_row + 1]
		if(isnull(source_row))
			continue
		for(var/column in 0 to DIRT_TAUR_WIDTH - 1)
			.[DIRT_BLOOD_INDEX(column, drawn_row)] = values[DIRT_BLOOD_INDEX(column, source_row)]

/**
 * Returns blood worked out in the rows the game draws a taur-fitted garment at its wearer's height, put back in the
 * garment's own rows. The garment's height filter stretches them again as it draws. Each pixel goes on the row its row
 * shows. Where the stretch draws one row twice, the pixels of both go on it, so no run breaks.
 *
 * Arguments:
 * - drawn: The blood in the rows drawn, on the taur canvas.
 * - rows: The row each row shows (dirt_height_rows()).
 */
/proc/dirt_blood_unstretched(datum/dirt_pixels/drawn, list/rows)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/own = new(DIRT_TAUR_WIDTH, ICON_SIZE_Y)
	own.drawn_indexes = list()
	var/list/ranks = dirt_role_ranks()
	for(var/index in drawn.drawn_indexes)
		var/role = drawn.roles[index]
		var/source_row = role ? rows[DIRT_BLOOD_ROW(index) + 1] : null
		if(isnull(source_row))
			continue
		var/target = DIRT_BLOOD_INDEX(DIRT_BLOOD_COLUMN(index), source_row)
		var/held = own.roles[target]
		if(!held || ranks[role] > ranks[held])
			own.put_index(target, role, drawn.thicknesses[index])
	return own

/**
 * Returns the lattice hash of a point as a whole number from 0 to 255: dirt_noise_hash() times 255. Blood is never
 * drawn while drafting, so it's the permutation table's entry.
 *
 * Arguments:
 * - column, row: The point.
 * - seed: The field's seed, a whole number.
 */
/proc/dirt_blood_hash_byte(column, row, seed)
	return floor(dirt_noise_hash(column, row, seed) * 255 + 0.5)

/**
 * Returns the role whose alpha is nearest a stain pixel's, out of haze, film, body and core. A run's first pixel
 * continues that stain pixel.
 *
 * Arguments:
 * - alpha: The stain pixel's alpha, out of 255.
 */
/proc/dirt_blood_nearest_role(alpha)
	// blood's tints' alphas out of 255, by DIRT_ROLE_* define, the same in every colour
	var/static/list/role_alphas
	if(!role_alphas)
		role_alphas = list()
		for(var/list/tint as anything in dirt_blood_tints("#000000"))
			role_alphas += floor(tint[2] * 255 + 0.5)
	. = DIRT_ROLE_HAZE
	var/nearest = abs(role_alphas[DIRT_ROLE_HAZE] - alpha)
	for(var/role in DIRT_ROLE_FILM to DIRT_ROLE_CORE)
		var/gap = abs(role_alphas[role] - alpha)
		if(gap < nearest)
			nearest = gap
			. = role

/**
 * Returns a role a tone lighter: core to body, body to film, film and haze to haze.
 *
 * Arguments:
 * - role: A DIRT_ROLE_* define, haze to core.
 */
/proc/dirt_blood_lighter(role)
	var/static/list/lighter = list(DIRT_ROLE_HAZE, DIRT_ROLE_HAZE, DIRT_ROLE_FILM, DIRT_ROLE_BODY)
	return lighter[role]

/**
 * Returns whether a pixel lies on the carrier's outline: the pixel left or right of it isn't the carrier's.
 *
 * Arguments:
 * - surface: The carrier's pixels.
 * - column, row: The pixel.
 */
/proc/dirt_blood_edge(list/surface, column, row)
	return !DIRT_BLOOD_ON(surface, column - 1, row) || !DIRT_BLOOD_ON(surface, column + 1, row)

/**
 * Returns how many carrier pixels lie between a pixel and the outline, to its left or right, whichever is nearer. The
 * pixel itself counts, and the most is 6.
 *
 * Arguments:
 * - surface: The carrier's pixels.
 * - column, row: The pixel.
 */
/proc/dirt_blood_depth(list/surface, column, row)
	for(var/reach in 1 to 6)
		if(!DIRT_BLOOD_ON(surface, column - reach, row) || !DIRT_BLOOD_ON(surface, column + reach, row))
			return reach
	return 6

/**
 * Returns the lowest row a run may reach in a column. That's DIRT_BLOOD_FEET rows above the ground where the column
 * reaches the ground, else one row above the column's lowest pixel (a belly's underside).
 *
 * Arguments:
 * - lowest: Each column's lowest carrier row, by column + 1, or null.
 * - carrier_floor: The carrier's lowest row.
 * - column: The column.
 */
/proc/dirt_blood_last_row(list/lowest, carrier_floor, column)
	var/bottom = (column >= 0 && column < DIRT_TAUR_WIDTH) ? lowest[column + 1] : null
	if(isnull(bottom))
		bottom = -1
	return bottom >= carrier_floor - 2 ? bottom - DIRT_BLOOD_FEET : bottom - 1

/**
 * Returns where a run starts in a canvas column: list(the first row at or under the seam that the carrier is on, the
 * rider's own pixels between, which it draws over, at most DIRT_BLOOD_DROP), or null where anything else comes first.
 *
 * Arguments:
 * - surface: The carrier's pixels.
 * - rider: The rider's pixels that show off the carrier, or null.
 * - column: The canvas column.
 * - seam_row: The seam row.
 * - carrier_floor: The carrier's lowest row.
 */
/proc/dirt_blood_start(list/surface, list/rider, column, seam_row, carrier_floor)
	RETURN_TYPE(/list)
	var/list/bridge = list()
	for(var/row in seam_row to carrier_floor - 1)
		if(DIRT_BLOOD_ON(surface, column, row))
			return list(row, bridge)
		if(!rider || !DIRT_BLOOD_ON(rider, column, row) || length(bridge) >= DIRT_BLOOD_DROP)
			return null
		bridge += DIRT_BLOOD_INDEX(column, row)
	return null

/**
 * Returns a run's pixels, one a row, as indexes. The run goes straight down the carrier, and steps a column aside
 * where its hash byte is under DIRT_BLOOD_WOBBLE, though never on two rows running or in its first two steps. It also
 * steps aside where the carrier's edge turns under it. A step onto the outline goes a column in, if that column isn't
 * on the outline, else the run ends. Within `inset` of the outline a step goes a column further in, `inset` + 1
 * columns in all. The run stops where what it may take ends, at its column's last row (dirt_blood_last_row()), or
 * beside another run. Facing east or west, a run stopped on its last row where the body turns into a coil behind it
 * (dirt_blood_turns()) rounds the bend. Its last two rows give way to a curve back along the coil: a column back and a
 * row down, twice, then one more column back on the same row. The curve is DIRT_BLOOD_BEND px at most and at least 2,
 * each pixel on what the run may take.
 *
 * Arguments:
 * - surface: The carrier's pixels.
 * - ground: The pixels it may take: the carrier's pixels that show.
 * - taken: The pixels other runs hold.
 * - lowest, carrier_floor: As dirt_blood_last_row()'s.
 * - column, row: Its first pixel.
 * - run_length: The most pixels it takes.
 * - seed: The view's noise seed.
 * - inset: How many carrier pixels it keeps between it and the outline, or 0.
 * - direction: The direction.
 * - bent: Given the curve's pixels where it rounds the bend. Changed.
 */
/proc/dirt_blood_walk(list/surface, list/ground, list/taken, list/lowest, carrier_floor, column, row, run_length, seed, inset, direction, list/bent)
	RETURN_TYPE(/list)
	var/list/path = list(DIRT_BLOOD_INDEX(column, row))
	var/straight = 0
	var/drift = 0
	for(var/turn in 1 to run_length)
		if(length(path) >= run_length)
			break
		var/step_row = row + 1
		var/list/options = list(column)
		if(straight >= 2 && dirt_blood_hash_byte(column, row, seed) < DIRT_BLOOD_WOBBLE)
			options.Insert(1, (dirt_blood_hash_byte(column, row, seed + 1) % 2) ? column + 1 : column - 1)
		if(straight >= 1)
			options += list(column - 1, column + 1)
		var/step_column
		for(var/option in options)
			if(DIRT_BLOOD_ON(ground, option, step_row) && !taken[DIRT_BLOOD_INDEX(option, step_row)] && step_row <= dirt_blood_last_row(lowest, carrier_floor, option))
				step_column = option
				break
		if(!isnull(step_column) && dirt_blood_edge(surface, step_column, step_row))
			var/inner = step_column + (DIRT_BLOOD_ON(surface, step_column + 1, step_row) ? 1 : -1)
			var/inner_ok = abs(inner - column) <= 1 && DIRT_BLOOD_ON(ground, inner, step_row) && !taken[DIRT_BLOOD_INDEX(inner, step_row)] && !dirt_blood_edge(surface, inner, step_row)
			step_column = (inner_ok && step_row <= dirt_blood_last_row(lowest, carrier_floor, inner)) ? inner : null
		if(!isnull(step_column) && inset && drift <= inset)
			var/here = dirt_blood_depth(surface, step_column, step_row)
			if(here <= inset)
				var/list/towards = dirt_blood_depth(surface, step_column - 1, step_row) >= dirt_blood_depth(surface, step_column + 1, step_row) ? list(-1, 1) : list(1, -1)
				for(var/toward in towards)
					var/inner = step_column + toward
					if(abs(inner - column) <= 1 && DIRT_BLOOD_ON(ground, inner, step_row) && !taken[DIRT_BLOOD_INDEX(inner, step_row)] && step_row <= dirt_blood_last_row(lowest, carrier_floor, inner) && dirt_blood_depth(surface, inner, step_row) > here)
						step_column = inner
						drift++
						break
		if(isnull(step_column))
			break
		straight = step_column == column ? straight + 1 : 0
		column = step_column
		row = step_row
		path += DIRT_BLOOD_INDEX(column, row)
	if((direction != EAST && direction != WEST) || length(path) < 3 || row < dirt_blood_last_row(lowest, carrier_floor, column))
		return path
	var/back = direction == EAST ? -1 : 1
	var/bend_column = DIRT_BLOOD_COLUMN(path[length(path) - 2])
	var/bend_row = DIRT_BLOOD_ROW(path[length(path) - 2])
	if(!dirt_blood_turns(ground, lowest, carrier_floor, bend_column, bend_row + 2, back))
		return path
	var/static/list/curve_steps = list(list(1, 1), list(2, 2), list(3, 2))
	var/list/curve = list()
	for(var/position in 1 to min(DIRT_BLOOD_BEND, length(curve_steps)))
		var/list/curve_step = curve_steps[position]
		var/curve_column = bend_column + back * curve_step[1]
		var/curve_row = bend_row + curve_step[2]
		if(!DIRT_BLOOD_ON(ground, curve_column, curve_row) || taken[DIRT_BLOOD_INDEX(curve_column, curve_row)] || curve_row > dirt_blood_last_row(lowest, carrier_floor, curve_column))
			break
		curve += DIRT_BLOOD_INDEX(curve_column, curve_row)
	if(length(curve) >= 2)
		path.Cut(length(path) - 1)
		path += curve
		bent += curve
	return path

/**
 * Returns whether the carrier turns at a pixel. It does if, from that pixel toward `back`, the carrier goes on for
 * DIRT_BLOOD_TURN_REACH px or more on that row, and every one of those columns reaches the ground. A coil lying behind
 * its front does that, and a leg or a belly doesn't.
 *
 * Arguments:
 * - ground: The carrier's pixels that show.
 * - lowest, carrier_floor: As dirt_blood_last_row()'s.
 * - column, row: The pixel.
 * - back: -1 toward the west, 1 toward the east.
 */
/proc/dirt_blood_turns(list/ground, list/lowest, carrier_floor, column, row, back)
	for(var/reach in 1 to DIRT_BLOOD_TURN_REACH)
		var/beyond = column + back * reach
		if(!DIRT_BLOOD_ON(ground, beyond, row) || isnull(lowest[beyond + 1]) || lowest[beyond + 1] < carrier_floor - 2)
			return FALSE
	return TRUE

/**
 * Puts a role on a pixel unless a role that outranks it is there.
 *
 * Arguments:
 * - roles: The roles drawn, a DIRT_ROLE_* define or null per pixel. Changed.
 * - index: The pixel.
 * - role: A DIRT_ROLE_* define.
 */
/proc/dirt_blood_put(list/roles, index, role)
	var/list/ranks = dirt_role_ranks()
	var/held = roles[index]
	if(!held || ranks[role] >= ranks[held])
		roles[index] = role

/**
 * Marks pixels and every pixel round them as taken, so runs never touch.
 *
 * Arguments:
 * - taken: TRUE or null per pixel. Changed.
 * - pixels: The indexes.
 */
/proc/dirt_blood_hold(list/taken, list/pixels)
	for(var/index in pixels)
		var/column = DIRT_BLOOD_COLUMN(index)
		var/row = DIRT_BLOOD_ROW(index)
		for(var/near_row in row - 1 to row + 1)
			for(var/near_column in column - 1 to column + 1)
				if(near_column >= 0 && near_column < DIRT_TAUR_WIDTH && near_row >= 0 && near_row < ICON_SIZE_Y)
					taken[DIRT_BLOOD_INDEX(near_column, near_row)] = TRUE

/**
 * Returns the 4-neighbours of a pixel that hold a role, as their roles.
 *
 * Arguments:
 * - roles: A DIRT_ROLE_* define or null per pixel.
 * - index: The pixel.
 */
/proc/dirt_blood_neighbour_roles(list/roles, index)
	RETURN_TYPE(/list)
	. = list()
	var/column = DIRT_BLOOD_COLUMN(index)
	var/row = DIRT_BLOOD_ROW(index)
	if(column < DIRT_TAUR_WIDTH - 1 && roles[index + 1])
		. += roles[index + 1]
	if(column > 0 && roles[index - 1])
		. += roles[index - 1]
	if(row < ICON_SIZE_Y - 1 && roles[index + DIRT_TAUR_WIDTH])
		. += roles[index + DIRT_TAUR_WIDTH]
	if(row > 0 && roles[index - DIRT_TAUR_WIDTH])
		. += roles[index - DIRT_TAUR_WIDTH]

/**
 * Returns the blood a taur's garment stain runs down onto the carrier below its seam, in one direction, on the taur
 * canvas: the reference's soaked band. Each stain pixel on the crop's last row (dirt_blood_seeds()) can seed a run. The
 * run starts on the carrier's first row at or under the seam, crossing up to DIRT_BLOOD_DROP rows of the rider's own
 * pixels between. There are up to DIRT_BLOOD_RUNS runs, kept apart, the densest first, and the variant shifts which
 * (DIRT_BLOOD_PICK_JITTER). The first run leads. It takes a share of the rows its column has, at least
 * DIRT_BLOOD_MIN_ROWS, and it's darkest under the hem. The rest are at most half its length and a tone lighter, and
 * the second is short. Each walks down what shows of the carrier, off its outline, and ends in a 2 px bulb above the
 * ground. Facing south, its first rows are 2 px wide. Under every seed column the carrier takes, a ragged band lies a
 * few rows deep. No dark pixel stands alone, no row runs level, and nothing floats off the seam. North draws nothing,
 * because lines up a taur's back onto the rider defy logic. Random draws come from the "blood:<DIRECTION>:<variant>"
 * stream, four a tile column, and from the lattice hash as a byte. Below another garment's blood, its runs keep off
 * that blood and the pixels round it, and start nowhere it holds.
 *
 * A run leaves only a seed column whose seam pixel is in the stain's mass (dirt_blood_mass()), with a mass pixel at
 * least DIRT_BLOOD_SEED_DENSE dense in it or beside it on the stain's last two rows. A view where no column does draws
 * nothing, and at the end every piece touching none of the mass goes. Facing east or west, a run reaching its last row
 * where the body turns into a coil rounds the bend (dirt_blood_walk()). It's kept whole and one pixel wide round the
 * bend, with a film tip and no bulb.
 *
 * Arguments:
 * - surface: The carrier's pixels, TRUE or null per pixel of the taur canvas.
 * - visible: Those that show.
 * - state: The stain's state in icons/effects/blood.dmi.
 * - direction: The direction.
 * - seam_row: The row it starts on, the first under the stain's drawn end.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - mass: The stain's alpha on the pixels its blood may hang from (dirt_blood_mass()).
 * - rider: The rider's own pixels that show off the carrier, or null.
 * - hidden: TRUE by tile column + 1 where something drawn over the stain hides it at the seam, or null.
 * - outer: TRUE on the pixels that the blood of a garment worn over this one holds, and on those round them, or null.
 */
/proc/dirt_blood_continuation(list/surface, list/visible, state, direction, seam_row, variant, list/mass, list/rider = null, list/hidden = null, list/outer = null)
	RETURN_TYPE(/datum/dirt_pixels)
	var/static/list/run_lengths = list(list(7, 10), list(3, 4), list(5, 7))
	var/datum/dirt_pixels/drawn = new(DIRT_TAUR_WIDTH, ICON_SIZE_Y)
	drawn.drawn_indexes = list()
	if(direction == NORTH)
		return drawn
	var/list/seed_read = dirt_blood_seeds(state, direction)
	var/list/stain_alphas = seed_read[1]
	var/list/near_seam = seed_read[2]
	var/list/seed_columns = list()
	for(var/column in 0 to ICON_SIZE_X - 1)
		if(stain_alphas[column + 1] && !hidden?[column + 1])
			seed_columns += column
	var/pixel_count = length(surface)
	var/carrier_floor = -1
	var/surface_count = 0
	var/list/lowest = new /list(DIRT_TAUR_WIDTH)
	for(var/index in 1 to pixel_count)
		if(!surface[index])
			continue
		surface_count++
		var/row = DIRT_BLOOD_ROW(index)
		carrier_floor = max(carrier_floor, row)
		lowest[DIRT_BLOOD_COLUMN(index) + 1] = row
	if(!length(seed_columns) || !surface_count)
		return drawn
	// a run leaves only where the stain's mass reaches the seam densely
	var/list/run_seeds = new /list(ICON_SIZE_X)
	var/run_seed_count = 0
	for(var/column in seed_columns)
		var/canvas_column = column + DIRT_TAUR_INSET
		if(!mass[DIRT_BLOOD_INDEX(canvas_column, seam_row - 1)])
			continue
		for(var/near_column in canvas_column - 1 to canvas_column + 1)
			if(mass[DIRT_BLOOD_INDEX(near_column, seam_row - 1)] >= DIRT_BLOOD_SEED_DENSE || mass[DIRT_BLOOD_INDEX(near_column, seam_row - 2)] >= DIRT_BLOOD_SEED_DENSE)
				run_seeds[column + 1] = TRUE
				run_seed_count++
				break
	if(!run_seed_count)
		return drawn
	var/list/ground = new /list(pixel_count)
	for(var/index in 1 to pixel_count)
		if(surface[index] && visible[index])
			ground[index] = TRUE
	// four random draws a tile column, whether it seeds a run or not, then the noise seed
	var/datum/dirt_random/stream = new("blood:[uppertext(dir2text(direction))]:[variant]")
	var/list/blocks = list()
	for(var/column in 1 to ICON_SIZE_X)
		var/length_draw = stream.draw()
		// read by nothing, but drawn to keep the stream's place
		stream.draw()
		var/side_draw = stream.draw()
		blocks += list(list(length_draw, side_draw, stream.draw()))
	var/seed = stream.randrange(65536)
	var/list/starts = new /list(ICON_SIZE_X)
	var/list/bridges = new /list(ICON_SIZE_X)
	for(var/column in seed_columns)
		var/list/found = dirt_blood_start(surface, rider, column + DIRT_TAUR_INSET, seam_row, carrier_floor)
		starts[column + 1] = found?[1]
		bridges[column + 1] = found ? found[2] : list()
	// densest first with the variant's jitter added, ties by the keep draw, then by the column
	var/list/order = list()
	var/list/order_keys = list()
	for(var/column in seed_columns)
		var/list/block = blocks[column + 1]
		var/list/sort_key = list(-stain_alphas[column + 1] - floor(block[3] / 256) % DIRT_BLOOD_PICK_JITTER, block[3], column)
		var/position = length(order) + 1
		for(var/placed in 1 to length(order))
			if(dirt_blood_sorts_before(sort_key, order_keys[placed]))
				position = placed
				break
		order.Insert(position, column)
		order_keys.Insert(position, list(sort_key))
	var/list/picked = list()
	for(var/column in order)
		if(!run_seeds[column + 1] || isnull(starts[column + 1]) || length(picked) >= DIRT_BLOOD_RUNS)
			continue
		if(outer)
			var/list/start_bridge = bridges[column + 1]
			if(outer[DIRT_BLOOD_INDEX(column + DIRT_TAUR_INSET, starts[column + 1])] || (length(start_bridge) && outer[start_bridge[1]]))
				continue
		var/apart = TRUE
		for(var/other in picked)
			if(abs(column - other) < DIRT_BLOOD_GAP)
				apart = FALSE
				break
		if(apart)
			picked += column
	var/list/roles = new /list(pixel_count)
	var/list/taken = outer ? outer.Copy() : new /list(pixel_count)
	var/list/own = new /list(pixel_count)
	var/list/over = new /list(pixel_count)
	var/list/ends = list()
	var/list/run_lengths_taken = list()
	// each bend pixel's role, because a curve's pixels touch corner to corner and softening would read them as dots
	var/list/curves = new /list(pixel_count)
	var/list/curve_indexes = list()
	var/side_inset = (direction == EAST || direction == WEST) ? DIRT_BLOOD_SIDE_INSET : 0
	for(var/rank in 1 to length(picked))
		var/column = picked[rank]
		var/list/block = blocks[column + 1]
		var/canvas_column = column + DIRT_TAUR_INSET
		var/row = starts[column + 1]
		var/list/bounds = run_lengths[min(rank, length(run_lengths))]
		var/run_length = bounds[1] + block[1] % (bounds[2] - bounds[1] + 1)
		if(rank == 1)
			// walked as far as the body under it lets it, then cut to its share
			run_length = 32
		if(rank == 2)
			run_length = min(run_length, max(2, run_lengths_taken[1] - 3))
		if(rank > 1)
			run_length = min(run_length, max(2, floor(run_lengths_taken[1] / 2)))
		// under the rider's rows a run may start a column in, still touching them
		if(row > seam_row && dirt_blood_edge(surface, canvas_column, row))
			var/side_in = DIRT_BLOOD_ON(surface, canvas_column + 1, row) ? 1 : -1
			if(DIRT_BLOOD_ON(ground, canvas_column + side_in, row) && !dirt_blood_edge(surface, canvas_column + side_in, row))
				canvas_column += side_in
		var/list/run_bridge = bridges[column + 1]
		var/list/bent = list()
		var/list/path = run_bridge + dirt_blood_walk(surface, ground, taken, lowest, carrier_floor, canvas_column, row, max(1, run_length - length(run_bridge)), seed, side_inset, direction, bent)
		// a run round the bend is kept whole
		if(rank == 1 && !length(bent))
			// its share of the rows the body gave it, which the body's own size moves, rounding halves up
			var/share = DIRT_BLOOD_SHARE_LOW + (block[1] % (DIRT_BLOOD_SHARE_HIGH - DIRT_BLOOD_SHARE_LOW + 1) + surface_count % (DIRT_BLOOD_SHARE_HIGH - DIRT_BLOOD_SHARE_LOW + 1)) % (DIRT_BLOOD_SHARE_HIGH - DIRT_BLOOD_SHARE_LOW + 1)
			var/kept = max(min(length(path), DIRT_BLOOD_MIN_ROWS), floor((length(path) * share + 50) / 100))
			path.Cut(kept + 1)
		for(var/index in run_bridge)
			over[index] = TRUE
		// two runs ending on one row near each other read as a level row, so the later one ends a row higher
		for(var/turn in 1 to length(path))
			if(length(path) <= 2 || !dirt_blood_ends_level(path[length(path)], ends))
				break
			path.Cut(length(path))
		// no two runs' lengths within 2 rows of each other
		for(var/turn in 1 to length(path))
			if(length(path) <= 2)
				break
			var/matched = FALSE
			for(var/other in run_lengths_taken)
				if(abs(length(path) - other) < 2)
					matched = TRUE
					break
			if(!matched)
				break
			path.Cut(length(path))
		ends += path[length(path)]
		run_lengths_taken += length(path)
		for(var/index in path)
			own[index] = TRUE
		bent &= path
		// round the bend its tip is the curve's end, with no bulb
		var/head_rows = (length(path) >= 2 && !length(bent)) ? min(2, length(path) - 1) : 0
		var/side = (block[2] % 2) ? 1 : -1
		if(side_inset)
			// the bulb widens toward the inside
			var/tip = path[length(path)]
			var/inner_right = dirt_blood_depth(surface, DIRT_BLOOD_COLUMN(tip) + 1, DIRT_BLOOD_ROW(tip))
			var/inner_left = dirt_blood_depth(surface, DIRT_BLOOD_COLUMN(tip) - 1, DIRT_BLOOD_ROW(tip))
			if(inner_right != inner_left)
				side = inner_right > inner_left ? 1 : -1
		var/follower = rank > 1
		var/stain_alpha = stain_alphas[column + 1]
		var/stain_role = dirt_blood_nearest_role(stain_alpha)
		var/list/drawn_pixels = list()
		for(var/step_number in 0 to length(path) - 1)
			var/index = path[step_number + 1]
			var/pixel_column = DIRT_BLOOD_COLUMN(index)
			var/pixel_row = DIRT_BLOOD_ROW(index)
			var/from_end = length(path) - 1 - step_number
			var/role
			var/beside_role
			if(from_end < head_rows)
				// the bulb: its darkest pixel at the bottom, beside a second
				role = from_end ? DIRT_ROLE_BODY : DIRT_ROLE_CORE
				beside_role = from_end ? null : DIRT_ROLE_BODY
			else if(!step_number)
				// it continues the stain pixel above: its nearest role, film to body
				role = clamp(stain_role, DIRT_ROLE_FILM, DIRT_ROLE_BODY)
			else
				role = DIRT_ROLE_BODY
				beside_role = from_end < head_rows + DIRT_BLOOD_THICKEN ? DIRT_ROLE_FILM : null
			if(!follower && step_number < DIRT_BLOOD_DARK_HEAD && from_end >= head_rows && stain_role >= DIRT_ROLE_BODY)
				role = DIRT_ROLE_CORE
			if(index in bent)
				// round the bend, one pixel wide, thinning to a film tip
				role = from_end ? DIRT_ROLE_BODY : DIRT_ROLE_FILM
				beside_role = null
				curves[index] = follower ? dirt_blood_lighter(role) : role
				curve_indexes += index
			var/beside
			if(beside_role)
				for(var/beside_column in list(pixel_column + side, pixel_column - side))
					if(DIRT_BLOOD_ON(surface, beside_column, pixel_row) && !taken[DIRT_BLOOD_INDEX(beside_column, pixel_row)] && !dirt_blood_edge(surface, beside_column, pixel_row) && pixel_row <= dirt_blood_last_row(lowest, carrier_floor, beside_column))
						beside = DIRT_BLOOD_INDEX(beside_column, pixel_row)
						break
			if(role == DIRT_ROLE_CORE && !beside && from_end < head_rows)
				role = DIRT_ROLE_BODY
			if(follower && step_number)
				role = dirt_blood_lighter(role)
				beside_role = beside_role && dirt_blood_lighter(beside_role)
			dirt_blood_put(roles, index, role)
			drawn_pixels += index
			if(beside)
				dirt_blood_put(roles, beside, beside_role)
				drawn_pixels += beside
			if(step_number < DIRT_BLOOD_LIP_WIDE && direction == SOUTH && from_end >= head_rows && ground[index])
				for(var/wide_column in list(pixel_column + side, pixel_column - side))
					if(!DIRT_BLOOD_ON(ground, wide_column, pixel_row) || taken[DIRT_BLOOD_INDEX(wide_column, pixel_row)] || dirt_blood_edge(surface, wide_column, pixel_row))
						continue
					var/crowded = FALSE
					for(var/other in picked)
						if(other != column && abs(wide_column - other - DIRT_TAUR_INSET) < 2)
							crowded = TRUE
							break
					if(crowded)
						continue
					// under the hem the run is 2 px wide, the stain feeding it
					var/wide_role = step_number ? DIRT_ROLE_FILM : DIRT_ROLE_BODY
					dirt_blood_put(roles, DIRT_BLOOD_INDEX(wide_column, pixel_row), follower ? dirt_blood_lighter(wide_role) : wide_role)
					drawn_pixels += DIRT_BLOOD_INDEX(wide_column, pixel_row)
					break
			if(!step_number && stain_alpha >= 150)
				// a dense stain pixel's lip spreads a pixel either side, under the stain only
				for(var/spread_column in list(pixel_column - 1, pixel_column + 1))
					var/tile_column = spread_column - DIRT_TAUR_INSET
					if(DIRT_BLOOD_ON(surface, spread_column, pixel_row) && !taken[DIRT_BLOOD_INDEX(spread_column, pixel_row)] && tile_column >= 0 && tile_column < ICON_SIZE_X && near_seam[tile_column + 1])
						dirt_blood_put(roles, DIRT_BLOOD_INDEX(spread_column, pixel_row), DIRT_ROLE_FILM)
						drawn_pixels += DIRT_BLOOD_INDEX(spread_column, pixel_row)
		dirt_blood_hold(taken, drawn_pixels)
	// the soaked band under every seed column the carrier is under, each column its own depth, some left out
	for(var/column in seed_columns)
		var/row = starts[column + 1]
		var/alpha = stain_alphas[column + 1]
		var/canvas_column = column + DIRT_TAUR_INSET
		// under a seed too faint to see, a band pixel reads as starting a row low
		if(isnull(row) || alpha < 24 || (!(column in picked) && dirt_blood_hash_byte(canvas_column, seam_row, seed) >= DIRT_BLOOD_BAND_KEEP))
			continue
		var/list/band_bridge = bridges[column + 1]
		var/depth = length(band_bridge) + 1 + floor(blocks[column + 1][2] / 256) % DIRT_BLOOD_BAND
		var/top = min(dirt_blood_nearest_role(alpha), DIRT_ROLE_BODY)
		for(var/band_row in 0 to depth - 1)
			var/cell
			if(band_row < length(band_bridge))
				cell = band_bridge[band_row + 1]
			else if(row + band_row - length(band_bridge) < ICON_SIZE_Y)
				cell = DIRT_BLOOD_INDEX(canvas_column, row + band_row - length(band_bridge))
			if(!cell || outer?[cell] || (!surface[cell] && !(cell in band_bridge)) || DIRT_BLOOD_ROW(cell) > dirt_blood_last_row(lowest, carrier_floor, DIRT_BLOOD_COLUMN(cell)))
				break
			if(DIRT_BLOOD_ROW(cell) > seam_row && surface[cell] && dirt_blood_edge(surface, DIRT_BLOOD_COLUMN(cell), DIRT_BLOOD_ROW(cell)))
				break
			dirt_blood_put(roles, cell, band_row ? (band_row < depth - 1 ? DIRT_ROLE_FILM : DIRT_ROLE_HAZE) : top)
			if(cell in band_bridge)
				over[cell] = TRUE
	// no dark pixel stands alone: a core with no body or core beside it softens to body, then a body alone to film
	var/list/softened = roles.Copy()
	for(var/index in 1 to pixel_count)
		if(roles[index] != DIRT_ROLE_CORE && roles[index] != DIRT_ROLE_FLECK)
			continue
		var/list/near = dirt_blood_neighbour_roles(roles, index)
		if(!(DIRT_ROLE_BODY in near) && !(DIRT_ROLE_CORE in near))
			softened[index] = DIRT_ROLE_BODY
	for(var/index in 1 to pixel_count)
		if(softened[index] == DIRT_ROLE_BODY && !length(dirt_blood_neighbour_roles(softened, index)))
			softened[index] = DIRT_ROLE_FILM
	// round the bend each pixel keeps its role
	for(var/index in curve_indexes)
		if(softened[index])
			softened[index] = curves[index]
	// drawn where the carrier shows, and over the rider where a run crosses it
	for(var/index in 1 to pixel_count)
		if(softened[index] && !visible[index] && !over[index])
			softened[index] = null
	dirt_blood_break_level(softened, own, seed, seam_row)
	dirt_blood_keep_hung(softened, mass)
	for(var/index in 1 to pixel_count)
		if(softened[index])
			drawn.put_index(index, softened[index], DIRT_BLOOD_THICKNESS)
	return drawn

/**
 * Drops every piece (8-connected) of blood touching none of its stain's mass, so nothing hangs from nothing.
 *
 * Arguments:
 * - roles: A DIRT_ROLE_* define or null per pixel of the taur canvas. Changed.
 * - mass: The stain's alpha on the pixels its blood may hang from (dirt_blood_mass()).
 */
/proc/dirt_blood_keep_hung(list/roles, list/mass)
	var/list/piece_of = new /list(length(roles))
	for(var/start in 1 to length(roles))
		if(!roles[start] || piece_of[start])
			continue
		var/list/piece = dirt_blood_piece(roles, start, piece_of, DIRT_ROLE_HAZE)
		var/hung = FALSE
		for(var/index in piece)
			if(dirt_blood_touches(mass, index))
				hung = TRUE
				break
		if(!hung)
			for(var/index in piece)
				roles[index] = null

/**
 * Returns whether one sort key comes before another, comparing the lists item by item.
 *
 * Arguments:
 * - first, second: The keys, lists of numbers as long as each other.
 */
/proc/dirt_blood_sorts_before(list/first, list/second)
	for(var/position in 1 to length(first))
		if(first[position] != second[position])
			return first[position] < second[position]
	return FALSE

/**
 * Returns whether a run's last pixel ends on the row of another run's end within 4 columns of it.
 *
 * Arguments:
 * - tip: The run's last pixel.
 * - ends: The other runs' last pixels.
 */
/proc/dirt_blood_ends_level(tip, list/ends)
	for(var/other in ends)
		if(DIRT_BLOOD_ROW(tip) == DIRT_BLOOD_ROW(other) && abs(DIRT_BLOOD_COLUMN(tip) - DIRT_BLOOD_COLUMN(other)) <= 4)
			return TRUE
	return FALSE

/**
 * Breaks every level row of blood. In a row, while 3 px or more lie side by side, the pixel of that run nearest its
 * middle that isn't a run's own goes. Ties go by its hash byte, then to the leftmost. A level run of a run's own pixels
 * stays. Then any piece (8-connected) without a pixel on the seam row goes, so nothing floats off the stain. So does
 * any single pixel left alone, which reads as a dot.
 *
 * Arguments:
 * - roles: A DIRT_ROLE_* define or null per pixel of the taur canvas. Changed.
 * - own: TRUE on each run's own pixels.
 * - seed: The view's noise seed.
 * - seam_row: The seam row.
 */
/proc/dirt_blood_break_level(list/roles, list/own, seed, seam_row)
	for(var/row in 0 to ICON_SIZE_Y - 1)
		for(var/turn in 1 to DIRT_TAUR_WIDTH)
			var/span_start = -1
			var/span_end = -1
			var/run_start = -1
			// one past the last column ends the last run
			for(var/column in 0 to DIRT_TAUR_WIDTH)
				if(column < DIRT_TAUR_WIDTH && roles[DIRT_BLOOD_INDEX(column, row)])
					if(run_start < 0)
						run_start = column
					continue
				if(run_start >= 0 && column - run_start >= 3)
					span_start = run_start
					span_end = column - 1
					break
				run_start = -1
			if(span_start < 0)
				break
			var/middle = (span_start + span_end) / 2
			var/dropped = -1
			var/list/dropped_key
			for(var/column in span_start to span_end)
				if(own[DIRT_BLOOD_INDEX(column, row)])
					continue
				var/list/drop_key = list(abs(column - middle), dirt_blood_hash_byte(column, row, seed), column)
				if(!dropped_key || dirt_blood_sorts_before(drop_key, dropped_key))
					dropped = column
					dropped_key = drop_key
			if(dropped < 0)
				break
			roles[DIRT_BLOOD_INDEX(dropped, row)] = null
	var/list/piece_of = new /list(length(roles))
	for(var/start in 1 to length(roles))
		if(!roles[start] || piece_of[start])
			continue
		var/list/piece = dirt_blood_piece(roles, start, piece_of, DIRT_ROLE_HAZE)
		var/on_seam = FALSE
		for(var/index in piece)
			if(DIRT_BLOOD_ROW(index) == seam_row)
				on_seam = TRUE
				break
		if(!on_seam || length(piece) == 1)
			for(var/index in piece)
				roles[index] = null

/**
 * Returns one carrier's blood in one direction of a mask job: each stain's continuation (dirt_blood_continuation())
 * on what the canvas holds there (dirt_blood_carriers()), kept to that carrier's own pixels. A uniform's stain is left
 * out where the suit drawn over it reaches the crop's last row. Its runs keep off the suit's blood, which is worked out
 * first. Each continuation hangs from its stain's mass (dirt_blood_mass()). On the taur body, the pixels a run crosses
 * over the rider are drawn by the bridge layer, the body's lowest layer that the game draws over the rider. On a
 * taur-fitted garment, only the pixels on its cloth are kept, back in its own rows (dirt_blood_unstretched()).
 *
 * A continuation is the same for both carriers and in any colour. So SSdirt.rasters keeps each one whole, under an MD5
 * of the taur body's shape, the rider's template and the blood's data without its materials (dirt_taur_blood_key()).
 * The key adds the stain's place in the list. That key holds everything the continuation reads, so nothing has to
 * forget it. The cache's bound (DIRT_RASTER_CACHE_SIZE) lets the oldest go.
 *
 * Arguments:
 * - blood: From dirt_taur_blood_data().
 * - carriers: From dirt_blood_carriers() in the direction. Its owners are changed: the rider's pixels the blood crosses
 *   become the bridge layer's.
 * - source: The taur body.
 * - direction: The direction.
 * - on_cloth: Whether the carrier is the taur-fitted garment, else the taur body.
 * - rider_key: The key of the rider's template the carriers were read on (/datum/dirt_template/var/key).
 *
 * Returns a list of /datum/dirt_pixels, one for each stain, in its order.
 */
/proc/dirt_blood_rasterise(list/blood, list/carriers, datum/dirt_taur_source/source, direction, on_cloth, rider_key)
	RETURN_TYPE(/list)
	. = list()
	var/list/owners = carriers[1]
	var/bridge_layer
	if(!on_cloth)
		var/list/stack = dirt_taur_drawn_stack()
		for(var/position in stack.Find(DIRT_TAUR_RIDER) + 1 to length(stack))
			if(length(source.layer_states[stack[position]]))
				bridge_layer = stack[position]
				break
	var/last_kept = dirt_blood_last_kept_row(direction)
	var/list/rows = blood[5]
	var/list/stains = blood[1]
	var/runs_key = "blood|[md5("[source.shape_key()]|[rider_key]|[dirt_taur_blood_key(blood, null, FALSE)]")]"
	// what the stains worked out so far hold, the suit's first, so the next one's runs never touch them
	var/list/outer
	for(var/stain_number in 1 to length(stains))
		var/list/stain = stains[stain_number]
		var/raster_key = "[runs_key]|[stain_number]"
		var/kept = SSdirt.rasters.fetch_direction(raster_key, direction)
		var/datum/dirt_pixels/drawn
		if(kept)
			drawn = dirt_pixels_from_drawn(kept, DIRT_TAUR_WIDTH, ICON_SIZE_Y)
		else
			var/list/hidden
			if(stain[4] && direction != NORTH)
				hidden = new /list(ICON_SIZE_X)
				var/list/seam_pixels = list()
				for(var/column in 1 to ICON_SIZE_X)
					seam_pixels += last_kept * ICON_SIZE_X + column
				for(var/index in dirt_sprite_zone_pixels(stain[4], stain[5], "taur_seam_[last_kept]", seam_pixels, direction, stain[6]))
					hidden[index - last_kept * ICON_SIZE_X] = TRUE
			// the rider's hands hide a uniform's stain but not a suit's, which draws over them, and north draws none
			var/list/mass = direction == NORTH ? null : dirt_blood_mass(stain[1], direction, blood[4], rows, stain[1] == "uniformblood" ? carriers[5] : null)
			drawn = dirt_blood_continuation(carriers[2], carriers[3], stain[1], direction, blood[4], stain[3], mass, carriers[4], hidden, outer)
			SSdirt.rasters.store_direction(raster_key, direction, drawn.drawn())
		// held whole, before either carrier takes its share, so the body's and the cloth's agree
		outer ||= new /list(length(owners))
		dirt_blood_hold(outer, drawn.drawn_indexes)
		for(var/index in drawn.drawn_indexes)
			var/shown = owners[index]
			if(on_cloth ? shown != DIRT_TAUR_CLOTH : shown == DIRT_TAUR_CLOTH)
				drawn.put_index(index, null, null)
			else if(shown == DIRT_TAUR_RIDER)
				if(bridge_layer)
					owners[index] = bridge_layer
				else
					drawn.put_index(index, null, null)
		. += (on_cloth && rows) ? dirt_blood_unstretched(drawn, rows) : drawn

/**
 * Returns the masks of a person's blood below a taur's waist on its taur body, drawn with the body's own images, or
 * null while there are none to draw. It asks for them as ready_skin_masks() does. It's called as the taur body's key is
 * made, and with no blood to draw there, the drawing goes. Masks made for another rider are dropped and made again. A
 * change to the blood, the garments or the height has them made again, with the old ones drawn meanwhile. The key and
 * the draw read which side of the taur body's dirt the blood draws on (waist_blood_over()). A change of that side
 * never has them made again.
 *
 * Arguments:
 * - taur: The taur body's overlay.
 * - limb: The chest it's drawn on.
 */
/datum/component/dirtiness/proc/ready_taur_blood_masks(datum/bodypart_overlay/mutant/taur_body/taur, obj/item/bodypart/limb)
	RETURN_TYPE(/datum/dirt_masks)
	var/mob/living/carbon/human/body = parent
	var/list/inputs = istype(body) ? dirt_taur_blood_inputs(body) : null
	var/datum/dirt_taur_source/source = inputs?[3] && taur.dirt_read_source(limb)
	if(!source)
		drop_taur_blood()
		return null
	var/list/blood = dirt_taur_blood_data(inputs, body)
	var/blood_key = dirt_taur_blood_key(blood, source)
	taur_blood ||= new
	if(taur_blood.request && !dirt_zone_sources_match(body, taur_blood.request.zone_sources))
		taur_blood.forget(TRUE)
	else if(taur_blood.request && taur_blood.parts_key != blood_key)
		taur_blood.forget(FALSE)
	if(!taur_blood.request)
		taur_blood.start(new /datum/dirt_mask_request(DIRT_MASKS_TAUR, dirt_zone_sources(body), DIRT_SURFACE_SKIN, null, shape_source = source, blood = blood), blood_key)
	return taur_blood.current(body, DIRT_REDRAW_BODY)

/**
 * Returns the masks of the blood below a taur's waist lying on a taur-fitted garment's cloth, drawn inset in its worn
 * wrapper. Returns null while there are none to draw. The garment must be the one dirt_taur_blood_inputs() names. Its
 * rows are the wrapper's, which stretch with the rider. With no blood to draw there, the drawing goes. While it draws,
 * taking the garment off stops it (on_dropped()). Which side of the garment's dirt it draws on is noted in
 * cloth_run_over as the garment draws. That draw is this proc's only caller.
 *
 * Arguments:
 * - garment: The item.
 * - wearer: Who wears it.
 * - draw_target: Its sprite as worn, being built now.
 */
/datum/component/dirtiness/proc/ready_taur_blood_cloth_masks(obj/item/garment, mob/living/carbon/human/wearer, mutable_appearance/draw_target)
	RETURN_TYPE(/datum/dirt_masks)
	// only a uniform or suit carries it, so every other worn draw stops here
	if(garment != wearer.w_uniform && garment != wearer.wear_suit)
		drop_taur_blood()
		return null
	var/list/inputs = dirt_taur_blood_inputs(wearer, garment, draw_target)
	var/cloth_slot = inputs?[4]
	var/datum/dirt_taur_source/source = (cloth_slot && garment == (cloth_slot == ITEM_SLOT_OCLOTHING ? wearer.wear_suit : wearer.w_uniform)) ? dirt_taur_source(wearer) : null
	if(!source)
		drop_taur_blood()
		return null
	var/list/blood = dirt_taur_blood_data(inputs, wearer)
	var/blood_key = dirt_taur_blood_key(blood, source)
	if(!taur_blood)
		taur_blood = new
		RegisterSignal(garment, COMSIG_ITEM_DROPPED, PROC_REF(on_dropped))
	cloth_run_over = dirt_cloth_run_over(wearer, inputs)
	if(taur_blood.request && !dirt_zone_sources_match(wearer, taur_blood.request.zone_sources))
		taur_blood.forget(TRUE)
	else if(taur_blood.request && taur_blood.parts_key != blood_key)
		taur_blood.forget(FALSE)
	if(!taur_blood.request)
		taur_blood.start(new /datum/dirt_mask_request(DIRT_MASKS_TAUR, dirt_zone_sources(wearer), DIRT_SURFACE_CLOTH, null, shape_source = source, blood = blood), blood_key)
	return taur_blood.current(wearer, cloth_slot == ITEM_SLOT_OCLOTHING ? DIRT_REDRAW_SUIT : DIRT_REDRAW_UNIFORM)

/**
 * Stops drawing blood below a taur's waist. It drops the job making its masks if no other body waits for them, as a
 * wash drops a carrier's jobs (drop_drawing_jobs()). On a garment it stops watching for the garment being taken off.
 *
 * Arguments:
 * - waiter: Who waited for the masks, or null for the person this carrier is on or who wears it.
 */
/datum/component/dirtiness/proc/drop_taur_blood(mob/living/carbon/human/waiter = null)
	if(!taur_blood)
		return
	if(!waiter)
		var/atom/movable/holder = parent
		waiter = ishuman(holder) ? holder : holder.loc
	if(ishuman(waiter))
		SSdirt.drop_mask_job(taur_blood.key, waiter)
	taur_blood = null
	cloth_run_over = FALSE
	if(isitem(parent))
		UnregisterSignal(parent, COMSIG_ITEM_DROPPED)

/**
 * Stops a taur-fitted garment drawing the blood below its wearer's waist as it's taken off, and deletes its carrier if
 * that leaves it holding nothing (holds_nothing()).
 *
 * Arguments:
 * - source: The garment.
 * - user: Who wore it.
 */
/datum/component/dirtiness/proc/on_dropped(obj/item/source, mob/user)
	SIGNAL_HANDLER
	drop_taur_blood(user)
	if(holds_nothing())
		qdel(src)

/**
 * Has a taur's blood below the waist drawn again where what it's drawn from changed since it was asked for. It's also
 * drawn again where it was drawn on the other side of the dirt from the one it takes. It does this for the taur body's
 * images and for the taur-fitted garment's. The two sides are decided apart, as they lie on different dirt. The taur
 * body's side is read against the chest's drawn key (waist_blood_over()). The garment's is read against what its last
 * draw noted (dirt_cloth_run_over()). So a key or an image read for anything else can't hide a side left undrawn. That
 * garment gets a carrier of its own to draw the blood through, made here, outside any render. This runs at every cover
 * check (check_cover()), on anyone, taur or not. It deletes any carrier that holds nothing (holds_nothing()), whatever
 * made it. Unless the uniform or the suit carries the blood now, its carrier first drops any blood it drew, then is
 * deleted if it holds nothing. So is this carrier, once no worn garment's blood would draw below a taur's waist. Its
 * taur body is then drawn again without any blood it drew.
 *
 * Returns whether the taur body's images need drawing again.
 */
/datum/component/dirtiness/proc/check_taur_blood()
	var/mob/living/carbon/human/body = parent
	var/list/inputs = dirt_taur_blood_inputs(body)
	// what the masks are asked for by, on the taur body and on a taur-fitted garment alike
	var/blood_key
	if(inputs)
		var/datum/dirt_taur_source/source = dirt_taur_source(body)
		blood_key = dirt_taur_blood_key(dirt_taur_blood_data(inputs, body), source)
	var/obj/item/cloth = inputs?[4] && body.get_item_by_slot(inputs[4])
	// typed, so an empty slot is skipped
	for(var/obj/item/garment in list(body.w_uniform, body.wear_suit))
		var/datum/component/dirtiness/garment_carrier = garment.GetComponent(/datum/component/dirtiness)
		if(garment == cloth)
			if(!garment_carrier || garment_carrier.taur_blood?.parts_key != blood_key || garment_carrier.cloth_run_over != dirt_cloth_run_over(body, inputs))
				garment.LoadComponent(/datum/component/dirtiness)
				garment.update_slot_icon()
			continue
		if(!garment_carrier)
			continue
		var/garment_drew = !!garment_carrier.taur_blood
		garment_carrier.drop_taur_blood()
		if(garment_carrier.holds_nothing())
			qdel(garment_carrier)
		if(garment_drew)
			garment.update_slot_icon()
	if(inputs?[3])
		if(taur_blood?.parts_key != blood_key)
			return TRUE
		var/drawn_key = body.icon_render_keys[BODY_ZONE_CHEST]
		return waist_blood_over() != !!(drawn_key && findtextEx(drawn_key, DIRT_TAUR_BLOOD_OVER_KEY))
	var/drew = !!taur_blood
	drop_taur_blood()
	// while a taur-fitted garment carries the blood, this carrier follows it
	if(inputs || !holds_nothing())
		return drew
	qdel(src)
	if(drew)
		body.update_body_parts()
	return FALSE

/**
 * Notes a taur whose uniform or suit effect was just cut at the waist (/obj/item/clothing/proc/fit_worn_effect()). If
 * it's a blood stain and the taur has no carrier of dirt yet, SSdirt makes one at its next fire, outside the render, so
 * the blood below the waist draws. A taur with a carrier follows its garments already
 * (/datum/component/dirtiness/proc/on_overlay_changed()). Rips draw nothing below the waist.
 *
 * Arguments:
 * - wearer: The taur.
 * - effect: The effect cut: a stain or a rip.
 */
/proc/dirt_note_taur_stain(mob/living/carbon/human/wearer, mutable_appearance/effect)
	if(effect.icon == 'icons/effects/blood.dmi' && !wearer.GetComponent(/datum/component/dirtiness))
		SSdirt.redraw_later(wearer, DIRT_REDRAW_COVER)

#undef DIRT_BLOOD_INDEX
#undef DIRT_BLOOD_ON
#undef DIRT_BLOOD_COLUMN
#undef DIRT_BLOOD_ROW
#undef DIRT_BLOOD_RUNS
#undef DIRT_BLOOD_GAP
#undef DIRT_BLOOD_WOBBLE
#undef DIRT_BLOOD_DROP
#undef DIRT_BLOOD_FEET
#undef DIRT_BLOOD_BAND
#undef DIRT_BLOOD_BAND_KEEP
#undef DIRT_BLOOD_THICKEN
#undef DIRT_BLOOD_LIP_WIDE
#undef DIRT_BLOOD_PICK_JITTER
#undef DIRT_BLOOD_SHARE_LOW
#undef DIRT_BLOOD_SHARE_HIGH
#undef DIRT_BLOOD_MIN_ROWS
#undef DIRT_BLOOD_SIDE_INSET
#undef DIRT_BLOOD_DARK_HEAD
#undef DIRT_BLOOD_THICKNESS
#undef DIRT_BLOOD_MASS_ROWS
#undef DIRT_BLOOD_MASS_ALPHA
#undef DIRT_BLOOD_SEED_DENSE
#undef DIRT_BLOOD_BEND
#undef DIRT_BLOOD_TURN_REACH
