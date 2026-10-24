/// Most poster looks graffiti_poster_look() keeps: a look holds its poster as an art, about 10 KB decoded, and the
/// posters painted in a round share a few dozen icon states.
#define GRAFFITI_POSTER_LOOKS 32

/**
 * Graffiti sprayed over a poster, painted as on a wall, freehand or from the can, but only on the poster's own pixels.
 * It stays on the poster, never in the map's graffiti, so it lasts the round at most: it goes when the poster is ripped
 * or its wall comes down, washes off, and goes along when the poster is taken down with wirecutters, to show again
 * once it is hung.
 */
/obj/structure/sign/poster
	/// The graffiti sprayed over the poster this round, its pieces merged into one: list("art", "decoded" =
	/// graffiti_art_decode(), "key" = graffiti_art_hash(), "glow" = graffiti_art_glow_kind()), or list("art", "decoded",
	/// "rolled" = TRUE) while a rolled-up poster carries it to be hung. Null without any.
	var/list/graffiti
	/// The freehand session or paint job painting the poster: one at a time.
	var/datum/graffiti_painter
	/// The graffiti as it was when graffiti_painter began, which its paint goes over: list(art, decoded, key), or null.
	var/list/graffiti_base

/**
 * Also draws the graffiti from the icon every poster and wall showing that art shares, with its glow.
 *
 * Returns:
 * - list: The overlays.
 */
/obj/structure/sign/poster/update_overlays()
	. = ..()
	if(!graffiti || graffiti["rolled"])
		return
	var/icon/paint = graffiti_art_icon(graffiti["art"], graffiti["key"], TRUE, graffiti["decoded"])
	if(!paint)
		return
	. += mutable_appearance(paint)
	var/glow = graffiti["glow"]
	var/icon/mask = glow == GRAFFITI_GLOW_MIXED ? graffiti_glow_icon(graffiti["art"], graffiti["key"], TRUE, graffiti["decoded"]) : null
	. += graffiti_emissive_overlays(glow, src, paint, mask)

/obj/structure/sign/poster/examine(mob/user)
	. = ..()
	if(graffiti && !graffiti["rolled"])
		. += "Someone has sprayed graffiti over it."
		. += span_notice("It won't outlast the shift.")

/**
 * Also washes the graffiti off, as cleaning takes it off a wall. A piece being painted goes with it, which ends its
 * painter's work there.
 *
 * Arguments:
 * - clean_types: The CLEAN_TYPE_ flags the poster is washed with.
 *
 * Returns:
 * - The wash() flags.
 */
/obj/structure/sign/poster/wash(clean_types)
	. = ..()
	if(!graffiti || graffiti["rolled"] || !(clean_types & CLEAN_TYPE_LIGHT_DECAL))
		return
	graffiti_painter = null
	graffiti_base = null
	graffiti_show(null)
	. |= COMPONENT_CLEANED|COMPONENT_CLEANED_GAIN_XP

/**
 * Also takes the poster's finished graffiti along in the rolled-up poster, to show again once it is hung. A piece still
 * being painted stays behind: its painter's work there ends.
 *
 * Arguments:
 * - location: Where the rolled-up poster goes.
 * - user: Who took it down, whose hands it goes in.
 *
 * Returns:
 * - /obj/item/poster: The rolled-up poster.
 */
/obj/structure/sign/poster/roll_and_drop(atom/location, mob/user)
	var/list/kept = graffiti_painter ? graffiti_base : (graffiti && list(graffiti["art"], graffiti["decoded"]))
	graffiti_painter = null
	graffiti_base = null
	graffiti = null
	. = ..()
	var/obj/item/poster/rolled = .
	// A new poster, or this one for a poster that keeps itself, as a wanted poster does.
	var/obj/structure/sign/poster/carried = rolled?.poster_structure
	if(!kept || !carried)
		return
	carried.graffiti = list("art" = kept[1], "decoded" = kept[2], "rolled" = TRUE)
	carried.update_appearance(UPDATE_OVERLAYS)

/// Also shows the graffiti a rolled-up poster carried, now that it hangs.
/obj/structure/sign/poster/on_placed_poster(mob/user)
	. = ..()
	if(graffiti?["rolled"])
		graffiti_hang()

/**
 * Shows the graffiti a rolled-up poster carried on the pixels the poster shows now, which a festive poster rolled up
 * plain may have changed.
 */
/obj/structure/sign/poster/proc/graffiti_hang()
	var/list/art = graffiti["art"]
	var/list/decoded = graffiti["decoded"]
	var/list/look = graffiti_poster_look(src)
	var/list/clipped = look && graffiti_clip_record(decoded, look["outside"])
	if(clipped && clipped != decoded)
		decoded = list()
		art = graffiti_flatten_records(list(clipped), GRAFFITI_WIDTH, 0, 0, decoded)
	graffiti_show(clipped && art, decoded)

/**
 * Shows an art as the poster's graffiti, or takes the graffiti off.
 *
 * Arguments:
 * - art: The merged art, or null. An art that paints nothing takes the graffiti off.
 * - decoded: The art's graffiti_art_decode().
 */
/obj/structure/sign/poster/proc/graffiti_show(list/art, list/decoded)
	var/old_key = graffiti?["key"]
	graffiti = length(art?["pal"]) ? list("art" = art, "decoded" = decoded, "key" = graffiti_art_hash(art), "glow" = graffiti_art_glow_kind(art, decoded)) : null
	update_appearance(UPDATE_OVERLAYS)
	// A painter's earlier composite, which nothing shows again, leaves the icon caches as a wall's replaced art does. The
	// graffiti beneath the piece, and art the map's graffiti uses, stay.
	if(graffiti_painter && old_key && old_key != graffiti?["key"] && old_key != graffiti_base?[3] && !SSgraffiti.art_refs[old_key])
		SSgraffiti.art_icons -= old_key
		SSgraffiti.glow_icons -= old_key

/**
 * Lets a freehand session or paint job paint over the poster, over the graffiti it shows now.
 *
 * Arguments:
 * - painter: The session or job.
 */
/obj/structure/sign/poster/proc/graffiti_begin(datum/painter)
	graffiti_painter = painter
	graffiti_base = graffiti && list(graffiti["art"], graffiti["decoded"], graffiti["key"])

/**
 * Shows a painter's piece merged over the graffiti beneath it.
 *
 * Arguments:
 * - painter: The session or job.
 * - art: The piece as far as it is painted, one tile wide.
 * - decoded: The art's graffiti_art_decode().
 *
 * Returns:
 * - TRUE/FALSE: Whether the poster shows the piece's paint: FALSE while the piece paints nothing, or once the painter
 *   isn't the poster's, as after a wash.
 */
/obj/structure/sign/poster/proc/graffiti_paint(datum/painter, list/art, list/decoded)
	if(graffiti_painter != painter)
		return FALSE
	if(!length(art["pal"]))
		graffiti_show(graffiti_base?[1], graffiti_base?[2])
		return FALSE
	if(graffiti_base)
		var/list/merged = list()
		art = graffiti_merge_arts(list(graffiti_base[1], art), GRAFFITI_WIDTH, null, list(graffiti_base[2], decoded), merged)
		decoded = merged
	graffiti_show(art, decoded)
	return TRUE

/**
 * Ends a painter's work on the poster.
 *
 * Arguments:
 * - painter: The session or job.
 * - keep: Whether its paint stays. Without it the poster shows what it did before the painter began.
 */
/obj/structure/sign/poster/proc/graffiti_end(datum/painter, keep = TRUE)
	if(graffiti_painter != painter)
		return
	if(!keep)
		graffiti_show(graffiti_base?[1], graffiti_base?[2])
	graffiti_painter = null
	graffiti_base = null

/**
 * Returns what a poster offers graffiti, read from its icon pixel by pixel: the pixels it shows, which alone take paint,
 * and the poster itself as an art, for the editor's window to draw beneath the canvas. Kept for each icon and state; a
 * poster drawn at runtime, as a wanted poster is, is read each time.
 *
 * Arguments:
 * - poster: The poster.
 *
 * Returns:
 * - list: "mask" and "bounds", the editor's draw mask and bounds for its one view; "mask_bits", the mask as a compact
 *   stroke mask's slots (custom_sprite_mask_points()'s `allowed`); "outside", the position of each pixel that takes no
 *   paint, row by row from the top left; "art" and "decoded", the poster as an art.
 * - null: The poster shows no pixels.
 */
/proc/graffiti_poster_look(obj/structure/sign/poster/poster)
	// Icon resource and state -> look. An icon an atom was given at runtime, as a wanted poster's, is a resource of its
	// own, with no file name, so resources go by their ref.
	var/static/list/looks = list()
	var/key = isfile(poster.icon) ? "\ref[poster.icon]|[poster.icon_state]" : null
	if(key && (key in looks))
		return looks[key]
	var/icon/source = icon(poster.icon, poster.icon_state, SOUTH, 1)
	var/list/rows = list()
	var/list/outside = list()
	var/list/colors = list()
	// Colour -> its index in colors.
	var/list/found = list()
	var/list/indices = new /list(GRAFFITI_WIDTH * GRAFFITI_HEIGHT)
	// The pixels that take paint as a compact stroke mask's slots, six pixels each, lowest bit first.
	var/list/bits = new /list(CEILING(GRAFFITI_WIDTH * GRAFFITI_HEIGHT / 6, 1))
	for(var/slot in 1 to length(bits))
		bits[slot] = 0
	var/position = 0
	// Icon rows count up from the bottom.
	for(var/row in GRAFFITI_HEIGHT to 1 step -1)
		var/list/marks = list()
		for(var/column in 1 to GRAFFITI_WIDTH)
			position++
			var/color = graffiti_color(source.GetPixel(column, row))
			if(!color)
				indices[position] = 0
				outside += position
				marks += "0"
				continue
			var/index = found[color]
			if(!index)
				colors += color
				index = length(colors)
				found[color] = index
			indices[position] = index
			bits[1 + round((position - 1) / 6)] |= 1 << ((position - 1) % 6)
			marks += "1"
		rows += jointext(marks, "")
	var/list/look
	if(length(colors))
		var/list/mask = list("2" = rows)
		var/list/decoded = list()
		var/list/art = graffiti_flatten_records(list(list(colors, indices, graffiti_unlit_glow(GRAFFITI_WIDTH)[2])), GRAFFITI_WIDTH, 0, 0, decoded)
		look = list("mask" = mask, "bounds" = custom_sprite_mask_bounds(mask, GRAFFITI_WIDTH), "mask_bits" = bits, "outside" = outside, "art" = art, "decoded" = decoded)
	if(key)
		custom_sprite_cache_put(looks, key, look, GRAFFITI_POSTER_LOOKS)
	return look

/**
 * Returns a decoded art or layer with paint left only where a poster takes it.
 *
 * Arguments:
 * - decoded: Its graffiti_art_decode() record, one tile wide.
 * - outside: graffiti_poster_look()'s "outside": the pixels that take no paint.
 *
 * Returns:
 * - list: A new record sharing the colours and glow, or `decoded` itself when it paints none of those pixels.
 */
/proc/graffiti_clip_record(list/decoded, list/outside)
	var/list/indices = decoded[2]
	var/list/clipped
	for(var/position in outside)
		if(!indices[position])
			continue
		clipped ||= indices.Copy()
		clipped[position] = 0
	return clipped ? list(decoded[1], clipped, decoded[3]) : decoded

/**
 * The graffiti editor on a poster: a freehand session whose canvas takes paint only on the poster's own pixels, as the
 * hair and markings editors keep paint to the body, with the poster and its graffiti beneath the canvas. The piece goes
 * on the poster rather than in the map's graffiti, one tile wide, and resumes nowhere: an unsaved piece is kept as a
 * plain draft.
 */
/datum/custom_sprite_editor/graffiti/poster
	/// The poster painted.
	var/obj/structure/sign/poster/poster
	/// Whether the poster shows the piece's paint, as the last composite left it.
	var/painted = FALSE

/**
 * Opens a freehand session on a poster.
 *
 * Arguments:
 * - preferences: The owner's preferences, or null.
 * - piece: The canonical piece to open, or null for a blank one.
 * - piece_id: The library piece it is, or null.
 * - can: The spray can it was opened from.
 * - surface: The poster's tile.
 * - poster: The poster.
 */
/datum/custom_sprite_editor/graffiti/poster/New(datum/preferences/preferences, list/piece, piece_id, obj/item/toy/crayon/spraycan/can, turf/surface, obj/structure/sign/poster/poster)
	src.poster = poster
	..()
	var/list/look = graffiti_poster_look(poster)
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	canvas.draw_mask = look?["mask"]
	canvas.draw_bounds = look?["bounds"]
	canvas.draw_mask_bits = look?["mask_bits"]
	poster.graffiti_begin(src)
	RegisterSignal(poster, COMSIG_QDELETING, PROC_REF(poster_gone))

/datum/custom_sprite_editor/graffiti/poster/Destroy()
	// The window closes first, which ends the session on the poster.
	SStgui.close_uis(src)
	poster?.graffiti_end(src)
	poster = null
	return ..()

/// Lets go of the poster as it is deleted, as ripping or rolling it up does: the session ends at its next check.
/datum/custom_sprite_editor/graffiti/poster/proc/poster_gone()
	SIGNAL_HANDLER
	poster = null

/datum/custom_sprite_editor/graffiti/poster/window_title()
	return "Graffiti editor on the poster"

/// Also says the paint lasts the round at most, on one tile.
/datum/custom_sprite_editor/graffiti/poster/ui_data(mob/user)
	. = ..()
	var/list/fields = .["graffiti"]
	fields["roundOnly"] = TRUE
	fields["oneTile"] = TRUE

/// A poster takes one tile, so the width never changes.
/datum/custom_sprite_editor/graffiti/poster/editor_act(action, list/params, datum/tgui/ui)
	if(action == "setWidth")
		notify("A poster takes one tile of graffiti.")
		return TRUE
	return ..()

/**
 * Returns why the poster can't take the session's paint any more.
 *
 * Returns:
 * - text: Why the session ends, to tell the painter.
 * - null: It still takes it.
 */
/datum/custom_sprite_editor/graffiti/poster/surface_problem()
	if(QDELETED(poster) || poster.loc != surface)
		return "The poster is gone."
	if(poster.graffiti_painter != src)
		return "Your graffiti is gone from the poster."
	return null

/**
 * Returns the poster as it shows beneath the session's piece, its graffiti over it, which the window draws under the
 * canvas.
 *
 * Arguments:
 * - tile: The poster's tile.
 * - packed: Unused: a poster's graffiti has no placements.
 *
 * Returns:
 * - list: The art.
 * - null: The poster is gone.
 */
/datum/custom_sprite_editor/graffiti/poster/tile_background(turf/tile, packed)
	var/list/look = poster && graffiti_poster_look(poster)
	var/list/base = poster?.graffiti_base
	if(!look || !base)
		return look?["art"]
	return graffiti_merge_arts(list(look["art"], base[1]), GRAFFITI_WIDTH, null, list(look["decoded"], base[2]))

/// Shows the piece over the poster's graffiti.
/datum/custom_sprite_editor/graffiti/poster/place_art(mob/user, list/art, list/decoded, list/evicted)
	painted = poster?.graffiti_paint(src, art, decoded) || FALSE

/**
 * Ends the session on the poster: a kept piece stays there (leave_surface()), and none resumes there.
 *
 * Arguments:
 * - user: The painter.
 * - piece: The piece as it ends, or null when nothing is painted.
 * - keep: Whether the piece is kept.
 *
 * Returns:
 * - null: A poster's piece resumes nowhere.
 */
/datum/custom_sprite_editor/graffiti/poster/end_surface(mob/user, list/piece, keep)
	if(keep)
		leave_surface(user, piece)
	else
		poster?.graffiti_end(src, FALSE)
	return null

/**
 * Leaves the piece over the poster as the session ends, composited one last time, as on a wall: with paint left, the can
 * is charged once, the poster is marked as the painter's work and the painter given the graffiti achievement. A piece
 * that paints nothing leaves the poster as it was.
 *
 * Arguments:
 * - user: The painter.
 * - piece: The piece as it ends, or null when nothing is painted.
 *
 * Returns:
 * - list: Empty: no placement holds a poster's piece.
 */
/datum/custom_sprite_editor/graffiti/poster/leave_surface(mob/user, list/piece)
	if(piece && !surface_problem())
		apply_live(user)
	. = list()
	if(!piece || !painted || surface_problem())
		poster?.graffiti_end(src, FALSE)
		log_game("[key_name(user)] ended a freehand graffiti session on a poster at [AREACOORD(surface)] without leaving paint")
		return
	poster.graffiti_end(src)
	can?.use_charges(user, GRAFFITI_COST * (HAS_TRAIT(user, TRAIT_TAGGER) ? 0.5 : 1), FALSE)
	graffiti_credit_painter(poster, user)
	user.client?.give_award(/datum/award/achievement/misc/custom_graffiti_painted, user)
	log_game("[key_name(user)] painted freehand graffiti on [poster] at [AREACOORD(surface)]")

/**
 * A paint job spraying a saved piece over a poster: its paint lands only on the poster's own pixels, over the poster's
 * graffiti, and a stopped piece resumes nowhere.
 */
/datum/graffiti_paint_job/poster
	/// The poster painted.
	var/obj/structure/sign/poster/poster

/**
 * Sets a job up on a poster. A stopped piece starts over, as a poster keeps nothing to resume on.
 *
 * Arguments:
 * - user: The painter.
 * - can: The spray can, in the painter's hand.
 * - surface: The poster's tile.
 * - piece: A copy of the one-tile canonical piece to paint.
 * - resume: Unused.
 * - piece_id: The library piece painted, or "unfinished" for the Unfinished slot's piece.
 * - poster: The poster.
 */
/datum/graffiti_paint_job/poster/New(mob/living/user, obj/item/toy/crayon/spraycan/can, turf/surface, list/piece, list/resume = null, piece_id = null, obj/structure/sign/poster/poster)
	src.poster = poster
	..(user, can, surface, piece, null, piece_id)
	RegisterSignal(poster, COMSIG_QDELETING, PROC_REF(poster_gone))

/datum/graffiti_paint_job/poster/Destroy()
	poster?.graffiti_end(src)
	poster = null
	return ..()

/// Lets go of the poster as it is deleted, as ripping or rolling it up does: the job stops at its next check.
/datum/graffiti_paint_job/poster/proc/poster_gone()
	SIGNAL_HANDLER
	poster = null

/// Each layer with paint left only on the poster's own pixels, so the job's time counts only the paint that shows.
/datum/graffiti_paint_job/poster/piece_records(list/piece)
	var/list/outside = graffiti_poster_look(poster)?["outside"]
	var/list/records = ..()
	. = list()
	for(var/list/record as anything in records)
		. += list(record && graffiti_clip_record(record, outside))

/**
 * Starts painting the poster, as its painter. A piece that paints none of the poster's pixels is refused.
 *
 * Returns:
 * - TRUE/FALSE: Whether the job started.
 */
/datum/graffiti_paint_job/poster/start()
	var/shows = FALSE
	for(var/list/record as anything in layer_records)
		for(var/index in record?[2])
			if(index)
				shows = TRUE
				break
		if(shows)
			break
	if(!shows)
		poster.balloon_alert(user, "won't show on the poster!")
		return FALSE
	poster.graffiti_begin(src)
	. = ..()
	if(!.)
		poster.graffiti_end(src)

/// Whether the poster still hangs where the job started, with the job its painter.
/datum/graffiti_paint_job/poster/surface_valid()
	return !QDELETED(poster) && poster.loc == surface && poster.graffiti_painter == src

/**
 * Shows the piece over the poster's graffiti as far as `progress` reveals it. Its time counts against every painter's
 * composites (SSgraffiti's spend_composite()).
 *
 * Arguments:
 * - progress: Strips revealed, at least 1.
 *
 * Returns:
 * - TRUE/FALSE: FALSE once the poster is gone or its graffiti washed off, which stops the job.
 */
/datum/graffiti_paint_job/poster/paint(progress)
	if(!surface_valid())
		return FALSE
	var/started = TICK_USAGE_REAL
	var/list/records = list()
	var/list/arts = tile_arts(progress, records)
	poster.graffiti_paint(src, arts[1], records[1])
	SSgraffiti.spend_composite(started)
	return TRUE

/// Marks the poster as the painter's work.
/datum/graffiti_paint_job/poster/credit_surface()
	graffiti_credit_painter(poster, user)

/// Lets go of the poster, its paint staying.
/datum/graffiti_paint_job/poster/release_surface()
	poster?.graffiti_end(src)

/**
 * Returns where a stopped piece resumes: nowhere, as a poster keeps nothing to resume on.
 *
 * Returns:
 * - null
 */
/datum/graffiti_paint_job/poster/stopped_resume()
	return null

#undef GRAFFITI_POSTER_LOOKS
