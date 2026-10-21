/// The layer of graffiti on a window: over the glass, under closed shutters and blast doors, which share tiles with
/// full-tile windows at 3.3 (SHUTTER_LAYER, CLOSED_BLASTDOOR_LAYER).
#define GRAFFITI_WINDOW_LAYER (ABOVE_OBJ_LAYER + 0.05)

/**
 * One tile's custom graffiti: a stack of placed pieces, oldest at the bottom, shown as one composite with its glow.
 *
 * SSgraffiti owns the placements and their art; the decal keeps the packed placements it shows and what it drew from
 * them. It lasts while the surface it was made on does, a wall, a floor with ground or a full-tile window's glass, and
 * it can't be painted over. A window's graffiti goes with the window, and a floor's stays under one fastened later.
 */
/obj/effect/decal/cleanable/crayon/custom
	name = "graffiti"
	// The paint carries its own colours.
	paint_colour = null
	/// The placements shown here, bottom to top, packed as SSgraffiti keeps them.
	var/list/stack
	/// graffiti_art_hash() of the merged stack, which names its sheet state and its drawn icon.
	var/stack_key
	/// list("base_art" = every piece but the top one merged, "art" = the whole stack merged, "kind" = its
	/// graffiti_art_glow_kind(), "mask" = its glow mask or the sheet holding it), plus "older", whether older paint shows
	/// beneath the top piece, once examined. The merges are kept only while someone paints the tile: a stack shown from
	/// its sheet, or left by its painters, keeps neither (release_merges()), and stack_merge() and base_merge() make them
	/// again.
	var/list/render_cache
	/// graffiti_surface_kind() of the tile the decal was made on, which the tile must stay: GRAFFITI_KIND_WALL, GRAFFITI_KIND_FLOOR or GRAFFITI_KIND_WINDOW.
	var/kind

/**
 * Sets the decal up on its surface, untinted and unpaintable. On a window it is drawn over the glass and follows the
 * window: it goes when the window is deleted or leaves the tile, and washes off with it.
 *
 * Arguments:
 * - mapload: Whether the map is loading.
 */
/obj/effect/decal/cleanable/crayon/custom/Initialize(mapload)
	// Set first: the decal base asks NeverShouldHaveComeHere() during ..().
	kind = graffiti_surface_kind(loc)
	. = ..(mapload)
	flags_1 |= UNPAINTABLE_1
	desc = null
	stack = list()
	if(kind != GRAFFITI_KIND_WINDOW)
		return
	// On the window's plane, over its glass.
	SET_PLANE_IMPLICIT(src, GAME_PLANE)
	layer = GRAFFITI_WINDOW_LAYER
	var/obj/structure/window/window = graffiti_window_of(loc)
	RegisterSignal(window, COMSIG_QDELETING, PROC_REF(window_gone))
	RegisterSignal(window, COMSIG_MOVABLE_MOVED, PROC_REF(window_moved))
	// Soap and sprays reach the window, which keeps them off its tile.
	RegisterSignal(window, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(window_washed))

/**
 * Drops the decal's placements from the registry for good: its surface was cleaned or is gone.
 */
/obj/effect/decal/cleanable/crayon/custom/Destroy()
	SSgraffiti.tile_gone(src)
	render_cache = null
	return ..()

/**
 * Whether the decal must go when its turf changes: the surface it was made on must still be there. A floor's is the
 * floor itself, which a window fastened over it later leaves, while a wall's or a window's tile must still offer one.
 *
 * Arguments:
 * - here_turf: The turf the decal is on now.
 *
 * Returns:
 * - TRUE/FALSE
 */
/obj/effect/decal/cleanable/crayon/custom/NeverShouldHaveComeHere(turf/here_turf)
	if(kind == GRAFFITI_KIND_FLOOR)
		return !isfloorturf(here_turf) || isgroundlessturf(here_turf)
	return !kind || graffiti_surface_kind(here_turf) != kind

/**
 * Goes for good with the window it is on, as it would with its wall.
 *
 * Arguments:
 * - source: The window, being deleted.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/window_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/**
 * Checks whether its window left the tile once the move is over: a shuttle moves the decal after its window.
 *
 * Arguments:
 * - source: The window.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/window_moved(obj/structure/window/source)
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(check_window), source), 0, TIMER_UNIQUE)

/**
 * Goes for good once its window has left the tile, as it would with its wall. Unfastening the window alone keeps it.
 *
 * Arguments:
 * - window: The window it was made on.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/check_window(obj/structure/window/window)
	if(QDELETED(window) || window.loc != loc)
		qdel(src)

/**
 * Washes off with its window.
 *
 * Arguments:
 * - source: The window.
 * - clean_types: The CLEAN_TYPE_ flags the window is washed with.
 *
 * Returns:
 * - The decal's wash() flags, which the window's wash() reports.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/window_washed(datum/source, clean_types)
	SIGNAL_HANDLER
	return wash(clean_types)

/**
 * Says it is graffiti, whether it outlasts the shift, and whether older graffiti still shows beneath its top piece.
 * Pieces' names and descriptions stay in their painters' libraries.
 *
 * Arguments:
 * - user: The examining mob.
 *
 * Returns:
 * - list: The examine lines.
 */
/obj/effect/decal/cleanable/crayon/custom/examine(mob/user)
	. = ..()
	var/count = length(stack)
	if(!count)
		return
	. += "A piece of graffiti."
	if(SSgraffiti.placement_info[stack[count]][GRAFFITI_INFO_ROUND_ONLY])
		. += span_notice("It won't outlast the shift.")
	if(count < 2 || !render_cache)
		return
	var/older = render_cache["older"]
	// Kept until the stack changes: merging a stack of five takes tens of milliseconds.
	if(isnull(older))
		var/list/arts = stack_arts()
		var/list/owners = list()
		graffiti_merge_arts(arts, GRAFFITI_WIDTH, owners)
		older = FALSE
		var/top = length(arts)
		for(var/owner in owners)
			if(owner && owner < top)
				older = TRUE
				break
		render_cache["older"] = older
	if(older)
		. += "Older graffiti shows through underneath."

/**
 * Lights the glowing paint and lets the rest block the glow of whatever lies beneath.
 *
 * Returns:
 * - list: The overlays.
 */
/obj/effect/decal/cleanable/crayon/custom/update_overlays()
	. = ..()
	if(render_cache)
		. += graffiti_emissive_overlays(render_cache["kind"], src, icon, render_cache["mask"], icon_state, icon_state && "[icon_state]_g")

/**
 * Returns the art of each piece in the stack that the registry still holds art for.
 *
 * Arguments:
 * - hashes: When given, filled with the hash of each art returned, in the same order.
 *
 * Returns:
 * - list: The arts, bottom to top.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/stack_arts(list/hashes = null)
	. = list()
	for(var/packed in stack)
		var/hash = SSgraffiti.art_of(packed)
		var/list/art = SSgraffiti.art[hash]
		if(!art)
			continue
		. += list(art)
		hashes?.Add(hash)

/**
 * Merges the stack again after it changed, then shows it.
 *
 * Only the top piece is merged over the cached merge of the ones beneath, unless `full` asks for the whole stack, as a
 * change below the top needs, or no merge of them is kept. The merge comes decoded, so its glow and icons never decode
 * it again.
 *
 * While the map loads, the arts come decoded from SSgraffiti's `decoded` as far as it keeps them, and it keeps the merge
 * decoded for its sheet while its budget allows. Nobody paints during the load, so only the whole stack's merge is kept,
 * for the sheet.
 *
 * Arguments:
 * - full: Whether the pieces beneath the top one changed.
 * - deferred: Whether to leave the icon for SSgraffiti.build_sheets() to set.
 * - top_record: The top piece's art decoded, when the caller has it, as a painter's composite does.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/refresh(full = FALSE, deferred = FALSE, list/top_record = null)
	var/list/decoded = deferred ? SSgraffiti.decoded : null
	var/list/hashes = decoded && list()
	var/list/arts = stack_arts(hashes)
	var/count = length(arts)
	// Nothing to draw: the decal goes once its stack is empty, and otherwise keeps what it shows.
	if(!count)
		if(!length(stack))
			qdel(src)
		return
	// Each art's graffiti_art_decode() while the map loads, else null.
	var/list/records
	if(decoded)
		records = list()
		for(var/hash in hashes)
			records += list(decoded[hash])
	var/list/top = arts[count]
	var/list/merged_record = records?[count] || top_record
	var/list/base = count > 1 && !full ? render_cache?["base_art"] : null
	var/list/base_record
	if(count > 1 && !base)
		if(count == 2)
			base = arts[1]
			base_record = records?[1]
		else
			base_record = records && list()
			base = graffiti_merge_arts(arts.Copy(1, count), GRAFFITI_WIDTH, null, records?.Copy(1, count), base_record)
	var/list/merged = top
	if(base)
		var/list/record = list()
		var/list/stacked = graffiti_merge_arts(list(base, top), GRAFFITI_WIDTH, null, list(length(base_record) ? base_record : null, merged_record), record)
		if(stacked)
			merged = stacked
			merged_record = record
	stack_key = graffiti_art_hash(merged)
	var/kind
	if(length(merged_record))
		if(deferred)
			SSgraffiti.keep_decoded(stack_key, merged_record, merged)
		kind = graffiti_art_glow_kind(merged, merged_record)
	else
		// The registry keeps each art's glow kind, so a stack of one piece shown by the load decodes nothing for it.
		kind = merged["k"]
		if(isnull(kind))
			kind = graffiti_art_glow_kind(merged)
	render_cache = list("base_art" = deferred ? null : base, "art" = merged, "kind" = kind, "mask" = null)
	if(!deferred)
		apply_icon(merged_record)

/**
 * Returns the stack's signature: its pieces' art hashes, bottom first, under which the map file caches its merge's key
 * and glow kind.
 *
 * Returns:
 * - text: The signature.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/stack_signature()
	var/list/hashes = list()
	for(var/packed in stack)
		hashes += SSgraffiti.art_of(packed)
	return jointext(hashes, "|")

/**
 * Shows the stack under the key and glow kind the map file cached for it, as the load does, without merging it: the
 * merges come once a sheet must be drawn or someone paints the tile (stack_merge(), base_merge()).
 *
 * Arguments:
 * - cached: list(the stack's key, its graffiti_art_glow_kind()), from SSgraffiti's stack_cache.
 *
 * Returns:
 * - TRUE/FALSE: Whether it took them. A malformed entry is left for refresh() to merge instead.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/adopt_stack(list/cached)
	if(!islist(cached) || length(cached) != 2 || !istext(cached[1]) || !(cached[2] in list(GRAFFITI_GLOW_NONE, GRAFFITI_GLOW_ALL, GRAFFITI_GLOW_MIXED)))
		return FALSE
	stack_key = cached[1]
	render_cache = list("base_art" = null, "art" = null, "kind" = cached[2], "mask" = null)
	return TRUE

/**
 * Returns the whole stack merged, as the decal shows it, merging it again when the decal keeps no merge of it.
 *
 * Returns:
 * - list: The merged art.
 * - null: The decal shows nothing.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/stack_merge()
	if(!render_cache)
		return null
	var/list/merged = render_cache["art"]
	if(merged)
		return merged
	var/list/arts = stack_arts()
	merged = length(arts) > 1 ? graffiti_merge_arts(arts, GRAFFITI_WIDTH) : (length(arts) ? arts[1] : null)
	render_cache["art"] = merged
	return merged

/**
 * Returns every piece of the stack but the top one merged, merging them again when the decal keeps no merge of them.
 *
 * Returns:
 * - list: The merged art.
 * - null: Nothing shows beneath the top piece.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/base_merge()
	if(!render_cache)
		return null
	var/list/base = render_cache["base_art"]
	if(base)
		return base
	var/list/arts = stack_arts()
	if(length(arts) < 2)
		return null
	arts.Cut(length(arts))
	base = length(arts) > 1 ? graffiti_merge_arts(arts, GRAFFITI_WIDTH) : arts[1]
	render_cache["base_art"] = base
	return base

/**
 * Lets go of the stack's merges once nobody paints on the tile: they are made again for the next painter, and what the
 * decal shows stays.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/release_merges()
	if(!render_cache)
		return
	render_cache["art"] = null
	render_cache["base_art"] = null

/**
 * Shows the merged stack from its sheet, or from an icon of its own when no sheet holds it.
 *
 * Arguments:
 * - decoded: The merged stack's graffiti_art_decode(), when the caller has it.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/apply_icon(list/decoded = null)
	if(!render_cache)
		return
	var/list/sheet = SSgraffiti.sheet_for(stack_key)
	if(sheet)
		icon = sheet[1]
		icon_state = stack_key
		render_cache["mask"] = sheet[2] ? sheet[1] : null
	else
		// A stack the load took from the map file's cache is merged only now, as no sheet holds it.
		var/list/art = stack_merge()
		icon = graffiti_art_icon(art, stack_key, TRUE, decoded)
		icon_state = ""
		render_cache["mask"] = render_cache["kind"] == GRAFFITI_GLOW_MIXED ? graffiti_glow_icon(art, stack_key, TRUE, decoded) : null
	update_appearance(UPDATE_OVERLAYS)

/**
 * Puts a placement on top of the stack. Past GRAFFITI_STACK_CAP, the oldest one is buried for good.
 *
 * Arguments:
 * - packed: The placement, packed as SSgraffiti keeps it.
 * - deferred: Whether to leave the merge for the caller, which refreshes once it has stacked everything.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/add_placement(packed, deferred = FALSE)
	// The stack so far becomes the base the new top merges over.
	if(!deferred && render_cache)
		render_cache["base_art"] = render_cache["art"]
	stack += packed
	if(length(stack) <= GRAFFITI_STACK_CAP)
		if(!deferred)
			refresh()
		return
	var/oldest = stack[1]
	stack.Cut(1, 2)
	SSgraffiti.remove_placement(oldest)
	if(!deferred)
		refresh(TRUE)

/**
 * Marks the decal as a painter's work as they finish a piece on it: their hidden print, and once only the art element,
 * which every piece stacked on the tile shares.
 *
 * Arguments:
 * - user: The painter.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/credit_painter(mob/user)
	add_hiddenprint(user)
	var/datum/element/art/element = SSdcs.GetElement(list(/datum/element/art, GOOD_ART))
	if(!element._signal_procs?[src])
		AddElement(/datum/element/art, GOOD_ART)

/**
 * Takes a placement off the stack, and the decal off its tile once nothing is left.
 *
 * Arguments:
 * - packed: The placement, packed as SSgraffiti keeps it.
 * - deferred: Whether to leave the merge for the caller, which refreshes once it has removed everything.
 */
/obj/effect/decal/cleanable/crayon/custom/proc/remove_placement(packed, deferred = FALSE)
	var/position = stack.Find(packed)
	if(!position)
		return
	stack.Cut(position, position + 1)
	if(deferred)
		return
	if(length(stack))
		refresh(TRUE)
		// No painter asked for this merge: one painting the tile has its next composite merge again.
		release_merges()
	else
		qdel(src)

/**
 * Returns the custom graffiti decal of the surface a turf offers now.
 *
 * Arguments:
 * - tile: The turf.
 * - create: Whether to make the decal when that surface has none.
 *
 * Returns:
 * - /obj/effect/decal/cleanable/crayon/custom: The decal.
 * - null: The turf takes no graffiti, or its surface has no decal and none could be made.
 */
/proc/graffiti_tile_decal(turf/tile, create = FALSE)
	var/kind = graffiti_surface_kind(tile)
	if(!kind)
		return null
	// A floor's graffiti stays under a window fastened over it later, so a tile may hold one decal of each.
	for(var/obj/effect/decal/cleanable/crayon/custom/decal in tile)
		if(decal.kind == kind)
			return decal
	if(!create)
		return null
	var/obj/effect/decal/cleanable/crayon/custom/made = new(tile)
	return QDELETED(made) ? null : made

/**
 * Returns the kind of surface a turf offers graffiti: a wall, the glass of a full-tile window fastened down on it, or a
 * floor with ground. A loose full-tile window still covers its floor, and a directional window changes nothing.
 *
 * Arguments:
 * - tile: The turf.
 *
 * Returns:
 * - GRAFFITI_KIND_WALL, GRAFFITI_KIND_WINDOW or GRAFFITI_KIND_FLOOR
 * - null: The turf takes no graffiti.
 */
/proc/graffiti_surface_kind(turf/tile)
	if(iswallturf(tile))
		return GRAFFITI_KIND_WALL
	// Without ground, the decal base would drop a window's graffiti through open space.
	if(isgroundlessturf(tile))
		return null
	for(var/obj/structure/window/window in tile)
		if(window.fulltile)
			return window.anchored ? GRAFFITI_KIND_WINDOW : null
	return isfloorturf(tile) ? GRAFFITI_KIND_FLOOR : null

/**
 * Returns the full-tile window fastened down on a turf, whose glass takes graffiti. Directional windows never do.
 *
 * Arguments:
 * - tile: The turf.
 *
 * Returns:
 * - /obj/structure/window: The window.
 * - null: No anchored full-tile window is on the turf.
 */
/proc/graffiti_window_of(turf/tile)
	for(var/obj/structure/window/window in tile)
		if(window.fulltile && window.anchored)
			return window
	return null

/**
 * Whether a turf takes graffiti: a wall, a floor with ground, or a full-tile window fastened down on it, on the static
 * station (graffiti_static_station()).
 *
 * Arguments:
 * - tile: The turf.
 *
 * Returns:
 * - TRUE/FALSE
 */
/proc/graffiti_surface_ok(turf/tile)
	return graffiti_surface_kind(tile) && graffiti_static_station(tile) ? TRUE : FALSE

/**
 * Whether a two-tile piece fits with its left half on a turf: the turf and the one to its east both take graffiti, on
 * the static station, and are of one kind, both walls, both floors or both windows, which draw their graffiti
 * differently.
 *
 * Arguments:
 * - tile: The left tile.
 *
 * Returns:
 * - TRUE/FALSE
 */
/proc/graffiti_wide_ok(turf/tile)
	var/turf/east = get_step(tile, EAST)
	var/kind = graffiti_surface_kind(tile)
	return (kind && kind == graffiti_surface_kind(east) && graffiti_static_station(tile) && graffiti_static_station(east)) ? TRUE : FALSE

#undef GRAFFITI_WINDOW_LAYER
