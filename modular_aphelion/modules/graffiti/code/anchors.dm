/**
 * Records where a template loaded on a station level, such as a random room or a holodeck program: its turfs aren't the
 * station as the map built it, and take no graffiti (graffiti_static_station()). A template loaded where another one
 * was, as a holodeck program is, replaces that record.
 *
 * Arguments:
 * - origin: The turf it loads at.
 * - centered: Whether `origin` is its centre rather than its low corner.
 *
 * Returns:
 * - list: The loaded bounds, as the parent returns them.
 * - null: Nothing was loaded.
 */
/datum/map_template/load(turf/origin, centered = FALSE)
	. = ..()
	var/list/bounds = .
	// A load that placed nothing leaves its bounds infinite.
	if(!islist(bounds) || bounds[MAP_MINZ] < 1 || bounds[MAP_MINZ] > world.maxz || bounds[MAP_MINX] > bounds[MAP_MAXX] || bounds[MAP_MINY] > bounds[MAP_MAXY] || !is_station_level(bounds[MAP_MINZ]))
		return
	for(var/list/entry as anything in SSgraffiti.loaded_templates)
		if(entry["x"] == bounds[MAP_MINX] && entry["y"] == bounds[MAP_MINY] && entry["z"] == bounds[MAP_MINZ])
			SSgraffiti.loaded_templates -= list(entry)
			break
	SSgraffiti.loaded_templates += list(list("x" = bounds[MAP_MINX], "y" = bounds[MAP_MINY], "z" = bounds[MAP_MINZ], "w" = bounds[MAP_MAXX] - bounds[MAP_MINX] + 1, "h" = bounds[MAP_MAXY] - bounds[MAP_MINY] + 1))

/**
 * Whether a turf is the station as the map built it, the only place graffiti goes: a station level's turf in a station
 * area, neither a shuttle's nor the holodeck's, and outside every map template loaded on the station this round, such as
 * a random room. Other levels, bitrunning and reserved space, ruins and the like take none. A system that loads spaces
 * of its own, such as condos, registers an anchor resolver for them instead (graffiti_register_anchor_resolver()).
 *
 * Arguments:
 * - tile: The turf.
 *
 * Returns:
 * - TRUE/FALSE
 */
/proc/graffiti_static_station(turf/tile)
	if(!tile || !is_station_level(tile.z) || is_reserved_level(tile.z))
		return FALSE
	var/area/place = get_area(tile)
	if(!istype(place, /area/station) || istype(place, /area/station/holodeck))
		return FALSE
	for(var/list/entry as anything in SSgraffiti.loaded_templates)
		if(entry["z"] == tile.z && tile.x >= entry["x"] && tile.x < entry["x"] + entry["w"] && tile.y >= entry["y"] && tile.y < entry["y"] + entry["h"])
			return FALSE
	return TRUE

/**
 * Lets a system that loads its own spaces, such as condos, place graffiti in them: its anchors are resolved through
 * `callback`, called with the anchor and returning a turf or null.
 *
 * Arguments:
 * - kind: The anchor kind, such as GRAFFITI_ANCHOR_RESERVED.
 * - callback: The callback.
 */
/proc/graffiti_register_anchor_resolver(kind, datum/callback/callback)
	SSgraffiti.anchor_resolvers[kind] = callback

/**
 * Takes the graffiti of one unloading space off its tiles and keeps it dormant, still in the map file. Call it before
 * the space's turfs change: a decal whose turf stops taking graffiti first loses its graffiti for good.
 *
 * Arguments:
 * - kind: The anchor kind.
 * - key: The space's key in its anchors: their `owner`.
 */
/proc/graffiti_registry_release(kind, key)
	SSgraffiti.release(kind, key)

/**
 * Returns the station levels in ascending order.
 *
 * Returns:
 * - list: The z levels.
 */
/proc/graffiti_station_levels()
	var/list/levels = SSmapping.levels_by_trait(ZTRAIT_STATION)
	// A copy, since SSmapping keeps this list.
	return sortTim(levels.Copy(), GLOBAL_PROC_REF(cmp_numeric_asc))

/**
 * Returns where a z level falls among the station levels, which anchors keep instead of the z level itself.
 *
 * Arguments:
 * - z_level: The z level.
 *
 * Returns:
 * - number: Its position among the station levels in ascending order, 0 when it isn't one.
 */
/proc/graffiti_station_ordinal(z_level)
	var/list/levels = graffiti_station_levels()
	return levels.Find(z_level)

/**
 * Returns the station level at an anchor's ordinal.
 *
 * Arguments:
 * - index: The ordinal, a position among the station levels in ascending order.
 *
 * Returns:
 * - number: The z level, 0 when no station level is at that position.
 */
/proc/graffiti_station_z(index)
	var/list/levels = graffiti_station_levels()
	return isnum(index) && index >= 1 && index <= length(levels) && index == round(index) ? levels[index] : 0

/**
 * Returns where graffiti painted on a turf lives across rounds: a station anchor, the turf's coordinates and area, and
 * its graffiti_surface_kind() as its `surface`.
 *
 * Arguments:
 * - tile: The turf.
 *
 * Returns:
 * - list: The anchor.
 * - null: The turf isn't the static station (graffiti_static_station()), or the map is an admin-loaded custom one,
 *   whose graffiti lasts this round only.
 */
/proc/graffiti_anchor_for(turf/tile)
	if(!graffiti_static_station(tile) || SSmapping.current_map.map_path == CUSTOM_MAP_PATH)
		return null
	var/area/place = get_area(tile)
	return list("kind" = GRAFFITI_ANCHOR_STATION, "x" = tile.x, "y" = tile.y, "z" = graffiti_station_ordinal(tile.z), "area" = "[place.type]", "surface" = graffiti_surface_kind(tile))

/**
 * Returns the turf an anchor names this round, when it is still the kind of surface the graffiti was painted on.
 *
 * A station anchor needs its turf to be in the same area as before and still the static station
 * (graffiti_static_station()). Other kinds go through their registered resolver.
 *
 * Arguments:
 * - anchor: The anchor, as SSgraffiti.check_anchor() returns it.
 *
 * Returns:
 * - turf: The turf.
 * - null: It doesn't resolve, or the turf isn't the kind of surface the anchor records.
 */
/proc/graffiti_anchor_resolve(list/anchor)
	if(!islist(anchor))
		return null
	var/turf/tile
	switch(anchor["kind"])
		if(GRAFFITI_ANCHOR_STATION)
			tile = locate(anchor["x"], anchor["y"], graffiti_station_z(anchor["z"]))
			var/area/place = get_area(tile)
			if((place && "[place.type]" != anchor["area"]) || !graffiti_static_station(tile))
				tile = null
		else
			var/datum/callback/callback = SSgraffiti.anchor_resolvers[anchor["kind"]]
			tile = callback?.Invoke(anchor)
	var/surface = graffiti_surface_kind(tile)
	return (surface && surface == anchor["surface"]) ? tile : null

/**
 * Whether an anchor that doesn't resolve is only waiting, so the round isn't counted as a miss: no system has registered
 * a resolver for its kind this round.
 *
 * Arguments:
 * - anchor: The anchor.
 *
 * Returns:
 * - TRUE/FALSE
 */
/proc/graffiti_anchor_waits(list/anchor)
	if(!islist(anchor))
		return FALSE
	var/kind = anchor["kind"]
	return kind != GRAFFITI_ANCHOR_STATION && !SSgraffiti.anchor_resolvers[kind]
