/// Bumped whenever a worn marking changes colour or glow. Entries can be shared by several collections, so a
/// collection checks this before trusting its key cache instead of waiting on its own version.
GLOBAL_VAR_INIT(body_marking_entry_revision, 0)

/datum/body_marking_entry
	/// The GLOB.body_markings singleton worn here. Its name is this entry's identity.
	VAR_FINAL/datum/body_marking/marking
	/// The marking zone this entry sits on, one of GLOB.marking_zones.
	VAR_FINAL/zone
	/// Literal lowercase #rrggbb, exactly what sanitize_hexcolor() returns.
	VAR_PROTECTED/color
	/// 1 when the marking glows, else 0: the same integer the savefile holds.
	VAR_PROTECTED/emissive = FALSE
	/// "[marking.name]_[color]_[emissive]", rebuilt after a setter clears it.
	VAR_PRIVATE/cached_key

/datum/body_marking_entry/New(datum/body_marking/marking, zone, color, emissive = FALSE)
	. = ..()
	src.marking = marking
	src.zone = zone
	src.color = sanitize_hexcolor(color)
	src.emissive = emissive ? TRUE : FALSE

/**
 * Returns this entry's colour.
 *
 * Returns:
 * - string: a lowercase #rrggbb colour.
 */
/datum/body_marking_entry/proc/get_color()
	return color

/**
 * Returns whether this entry glows.
 *
 * Returns:
 * - number: 1 when it glows, else 0.
 */
/datum/body_marking_entry/proc/get_emissive()
	return emissive

/**
 * Recolours this entry, for every collection and limb holding it.
 *
 * Refuses nothing yet: the locked-colour refusal arrives with the marking colour modes (markings plan
 * step 4/5).
 *
 * Arguments:
 * - new_color: any colour sanitize_hexcolor() accepts. It is stored sanitized.
 */
/datum/body_marking_entry/proc/set_color(new_color)
	new_color = sanitize_hexcolor(new_color)
	if(new_color == color)
		return
	color = new_color
	cached_key = null
	// A shared entry has no single owning collection to bump, so every collection's key cache checks this.
	GLOB.body_marking_entry_revision++

/**
 * Turns this entry's glow on or off, for every collection and limb holding it.
 *
 * Refuses nothing yet: the allow_emissives refusal arrives with the marking bug fixes (markings plan step 3).
 *
 * Arguments:
 * - new_emissive: truthy to glow. It is stored as 0 or 1.
 */
/datum/body_marking_entry/proc/set_emissive(new_emissive)
	new_emissive = new_emissive ? TRUE : FALSE
	if(new_emissive == emissive)
		return
	emissive = new_emissive
	cached_key = null
	GLOB.body_marking_entry_revision++

/**
 * Returns this entry's part of a limb icon cache key.
 *
 * Returns:
 * - string: "[marking.name]_[color]_[emissive]", cached until a setter changes a field.
 */
/datum/body_marking_entry/proc/cache_key()
	if(isnull(cached_key))
		cached_key = "[marking.name]_[color]_[emissive]"
	return cached_key

/**
 * Returns a new entry wearing the same marking on the same zone, in the same colour and glow.
 *
 * Returns:
 * - /datum/body_marking_entry: the new entry.
 */
/datum/body_marking_entry/proc/copy()
	RETURN_TYPE(/datum/body_marking_entry)
	return new /datum/body_marking_entry(marking, zone, color, emissive)

/datum/body_marking_collection
	/// Every worn entry in the order it was added. A zone's markings are this list filtered by zone.
	VAR_PRIVATE/list/entries
	/// Zones in the order they first appeared. An emptied zone keeps its place, as the nested map kept its key.
	VAR_PRIVATE/list/zones
	/// Bumped by every structural change: a zone or an entry added, an entry removed or replaced.
	VAR_PRIVATE/version = 0
	/// zone -> that zone's entries in order, for every zone in zones. Built on first use after a version bump
	/// and always replaced rather than edited, so a list handed out earlier stays a stable snapshot.
	VAR_PRIVATE/list/zone_cache
	/// The version zone_cache was built at.
	VAR_PRIVATE/zone_cache_version = -1
	/// zone -> cache key fragment. Dropped on a version bump or a new entry revision.
	VAR_PRIVATE/list/key_cache
	/// The version key_cache was built at.
	VAR_PRIVATE/key_cache_version = -1
	/// The entry revision key_cache was built at.
	VAR_PRIVATE/key_cache_revision = -1

/**
 * Adds a zone with no markings yet, where a new key of the nested map would have gone: at the end.
 *
 * Arguments:
 * - zone: one of GLOB.marking_zones. Anything else is ignored.
 *
 * Returns:
 * - TRUE if the zone was added, FALSE if it was already present or is not a marking zone.
 */
/datum/body_marking_collection/proc/add_zone(zone)
	if(!(zone in GLOB.marking_zones) || (zone in zones))
		return FALSE
	LAZYADD(zones, zone)
	version++
	return TRUE

/**
 * Returns whether a zone is present, with markings or emptied.
 *
 * Arguments:
 * - zone: the zone to look for.
 */
/datum/body_marking_collection/proc/has_zone(zone)
	return (zone in zones)

/**
 * Returns how many zones are present, emptied ones included.
 */
/datum/body_marking_collection/proc/zone_count()
	return length(zones)

/**
 * Returns how many entries there are across every zone.
 */
/datum/body_marking_collection/proc/entry_count()
	return length(entries)

/**
 * Returns how many entries one zone wears.
 *
 * Arguments:
 * - zone: the zone to count.
 */
/datum/body_marking_collection/proc/zone_length(zone)
	return length(entries_for_zone(zone))

/**
 * Returns every zone's entries, in zone order.
 *
 * The returned list and the lists inside it are shared and must not be edited. A structural change builds
 * new ones, so a list already handed out keeps what it held.
 *
 * Returns:
 * - list: zone -> list of entries, emptied zones included, or null when no zone is present.
 */
/datum/body_marking_collection/proc/zone_views()
	RETURN_TYPE(/list)
	if(zone_cache_version != version)
		var/list/views
		for(var/zone in zones)
			LAZYSET(views, zone, list())
		for(var/datum/body_marking_entry/entry as anything in entries)
			var/list/zone_entries = views[entry.zone]
			zone_entries += entry
		zone_cache = views
		zone_cache_version = version
	return zone_cache

/**
 * Returns one zone's entries in order.
 *
 * Arguments:
 * - zone: the zone to read.
 *
 * Returns:
 * - list: a shared, read-only list of entries, empty for an emptied zone, or null when the zone is absent.
 */
/datum/body_marking_collection/proc/entries_for_zone(zone)
	RETURN_TYPE(/list)
	if(!istext(zone))
		return null
	var/list/views = zone_views()
	return views?[zone]

/**
 * Returns the names one zone wears, in order.
 *
 * Arguments:
 * - zone: the zone to read.
 *
 * Returns:
 * - list: a new list of marking names.
 */
/datum/body_marking_collection/proc/marking_names(zone)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/body_marking_entry/entry as anything in entries_for_zone(zone))
		. += entry.marking.name

/**
 * Returns the entry wearing a marking on a zone.
 *
 * Arguments:
 * - zone: the zone to look on.
 * - name: the marking's name.
 *
 * Returns:
 * - /datum/body_marking_entry, or null when the zone doesn't wear that marking.
 */
/datum/body_marking_collection/proc/find_entry(zone, name)
	RETURN_TYPE(/datum/body_marking_entry)
	for(var/datum/body_marking_entry/entry as anything in entries)
		if(entry.zone == zone && entry.marking.name == name)
			return entry
	return null

/**
 * Adds an entry after every entry already on its zone, adding the zone first when it is absent.
 *
 * A zone wears each marking at most once, which the name-keyed nested map used to guarantee.
 *
 * Arguments:
 * - entry: the entry to add. It is held by reference, not copied.
 *
 * Returns:
 * - TRUE if added. FALSE for an entry without a marking or off the marking zones, or one repeating a
 *   marking its zone already wears.
 */
/datum/body_marking_collection/proc/add_entry(datum/body_marking_entry/entry)
	if(!entry?.marking || !(entry.zone in GLOB.marking_zones) || find_entry(entry.zone, entry.marking.name))
		return FALSE
	LAZYADD(entries, entry)
	LAZYOR(zones, entry.zone)
	version++
	return TRUE

/**
 * Removes an entry. Its zone stays present, emptied or not.
 *
 * Arguments:
 * - entry: the entry to remove.
 *
 * Returns:
 * - TRUE if the entry was held here and is now gone.
 */
/datum/body_marking_collection/proc/remove_entry(datum/body_marking_entry/entry)
	if(!LAZYFIND(entries, entry))
		return FALSE
	LAZYREMOVE(entries, entry)
	version++
	return TRUE

/**
 * Puts a replacement in an entry's place, so it keeps its position on the zone.
 *
 * Arguments:
 * - old_entry: the entry to replace.
 * - replacement: the entry taking its place. It must sit on the same zone and not wear a marking another
 *   entry on that zone already wears.
 *
 * Returns:
 * - TRUE if replaced.
 */
/datum/body_marking_collection/proc/replace_entry(datum/body_marking_entry/old_entry, datum/body_marking_entry/replacement)
	var/index = LAZYFIND(entries, old_entry)
	if(!index || !replacement?.marking || replacement.zone != old_entry.zone)
		return FALSE
	var/datum/body_marking_entry/worn = find_entry(replacement.zone, replacement.marking.name)
	if(worn && worn != old_entry)
		return FALSE
	entries[index] = replacement
	version++
	return TRUE

/**
 * Replaces everything on one zone. An absent zone is added at the end, a present one keeps its place.
 *
 * Arguments:
 * - zone: one of GLOB.marking_zones.
 * - zone_entries: the zone's new entries, in order. They are held by reference. Entries for another zone
 *   and repeats of a marking are skipped.
 *
 * Returns:
 * - TRUE if the zone was set.
 */
/datum/body_marking_collection/proc/set_zone_entries(zone, list/zone_entries)
	if(!(zone in GLOB.marking_zones))
		return FALSE
	var/list/kept = list()
	for(var/datum/body_marking_entry/entry as anything in entries)
		if(entry.zone != zone)
			kept += entry
	var/list/worn = list()
	for(var/datum/body_marking_entry/entry as anything in zone_entries)
		if(!entry?.marking || entry.zone != zone || worn[entry.marking])
			continue
		worn[entry.marking] = TRUE
		kept += entry
	entries = length(kept) ? kept : null
	LAZYOR(zones, zone)
	version++
	return TRUE

/**
 * Replaces everything on one zone from the nested shape a savefile holds, with new entries.
 *
 * Arguments:
 * - zone: one of GLOB.marking_zones.
 * - raw_zone: marking name -> list(color, emissive), read as body_marking_entries_from_list() reads it.
 *
 * Returns:
 * - TRUE if the zone was set.
 */
/datum/body_marking_collection/proc/set_zone_from_list(zone, list/raw_zone)
	return set_zone_entries(zone, body_marking_entries_from_list(zone, raw_zone))

/**
 * Gives every zone another collection holds that collection's entries, as assigning its zone maps did.
 *
 * A zone present here keeps its place and a new one goes at the end. The entries are shared, not copied.
 *
 * Arguments:
 * - other: the collection whose zones win.
 */
/datum/body_marking_collection/proc/overwrite_zones_from(datum/body_marking_collection/other)
	for(var/zone, zone_entries in other?.zone_views())
		set_zone_entries(zone, zone_entries)

/**
 * Returns a new collection with new entries in the same zones and order, colours and glow. Nothing is shared.
 *
 * Returns:
 * - /datum/body_marking_collection: the copy.
 */
/datum/body_marking_collection/proc/copy()
	RETURN_TYPE(/datum/body_marking_collection)
	var/datum/body_marking_collection/duplicate = new
	duplicate.zones = zones?.Copy()
	for(var/datum/body_marking_entry/entry as anything in entries)
		LAZYADD(duplicate.entries, entry.copy())
	return duplicate

/**
 * Returns a new collection holding these same entries.
 *
 * Adding, removing or replacing entries on one leaves the other alone, but a recoloured entry changes in
 * both: the sharing the nested lists' shallow Copy() gave, kept until each copy site is decided on.
 *
 * Returns:
 * - /datum/body_marking_collection: the copy.
 */
/datum/body_marking_collection/proc/shallow_copy()
	RETURN_TYPE(/datum/body_marking_collection)
	var/datum/body_marking_collection/duplicate = new
	duplicate.zones = zones?.Copy()
	duplicate.entries = entries?.Copy()
	return duplicate

/**
 * Rebuilds the nested shape preferences.json stores: zone -> (marking name -> list(color, emissive)).
 *
 * Zones and entries keep their order, an emptied zone writes as [], colours are the stored lowercase #rrggbb
 * and emissive is the integer 0 or 1, so a loaded save writes back byte for byte. With no zones this is an
 * empty list, which json_encode() writes as [].
 *
 * Returns:
 * - list: a new nested list the caller owns.
 */
/datum/body_marking_collection/proc/serialize()
	RETURN_TYPE(/list)
	. = list()
	for(var/zone, zone_entries in zone_views())
		.[zone] = body_marking_entries_to_list(zone_entries)

/**
 * Returns a string standing for one zone's markings, in order, with their colours and glow.
 *
 * Arguments:
 * - zone: the zone to describe.
 *
 * Returns:
 * - string: each entry's cache_key() joined by "-", or "" for none. Cached until the zone or an entry changes.
 */
/datum/body_marking_collection/proc/cache_key_for_zone(zone)
	if(!istext(zone))
		return ""
	if(key_cache_version != version || key_cache_revision != GLOB.body_marking_entry_revision)
		key_cache = null
		key_cache_version = version
		key_cache_revision = GLOB.body_marking_entry_revision
	var/cached = key_cache?[zone]
	if(!isnull(cached))
		return cached
	var/list/keys = list()
	for(var/datum/body_marking_entry/entry as anything in entries_for_zone(zone))
		keys += entry.cache_key()
	cached = jointext(keys, "-")
	LAZYSET(key_cache, zone, cached)
	return cached

/**
 * Counts the lists this collection holds right now, caches included. The markings benchmark reports it.
 *
 * Returns:
 * - number: the list count.
 */
/datum/body_marking_collection/proc/count_lists()
	. = 0
	for(var/list/held as anything in list(entries, zones, zone_cache, key_cache))
		if(held)
			.++
	. += length(zone_cache)

/**
 * The tolerant loader for the nested shape preferences.json stores: zone -> (marking name -> list(color, emissive)).
 *
 * A marking stored as a bare colour, the legacy shape, loads as that colour without glow; a missing colour
 * or glow reads as sanitize_hexcolor()'s default and 0, and extra fields are ignored. Zones outside
 * GLOB.marking_zones, zones that aren't lists and names missing from GLOB.body_markings are dropped.
 * Anything that isn't a list, null included, loads as no markings.
 *
 * Arguments:
 * - raw: the decoded "body_markings" value.
 *
 * Returns:
 * - /datum/body_marking_collection: always a new collection.
 */
/proc/body_marking_collection_from_list(list/raw)
	RETURN_TYPE(/datum/body_marking_collection)
	var/datum/body_marking_collection/collection = new
	if(!islist(raw))
		return collection
	for(var/zone in raw)
		if(!istext(zone) || !(zone in GLOB.marking_zones))
			continue
		var/list/raw_zone = raw[zone]
		if(islist(raw_zone))
			collection.set_zone_from_list(zone, raw_zone)
	return collection

/**
 * Builds new entries for one zone from its nested shape: marking name -> list(color, emissive).
 *
 * Arguments:
 * - zone: the zone the entries sit on.
 * - raw_zone: the zone's markings, read as body_marking_collection_from_list() documents.
 *
 * Returns:
 * - list: new entries in the zone's order.
 */
/proc/body_marking_entries_from_list(zone, list/raw_zone)
	RETURN_TYPE(/list)
	. = list()
	if(!islist(raw_zone))
		return
	var/list/worn = list()
	for(var/name in raw_zone)
		if(!istext(name) || worn[name])
			continue
		var/datum/body_marking/marking = GLOB.body_markings[name]
		if(!marking)
			continue
		worn[name] = TRUE
		var/value = raw_zone[name]
		// A bare colour reads as that colour without glow, the repair update_markings() used to make.
		var/color = value
		var/emissive = FALSE
		if(islist(value))
			var/list/fields = value
			color = length(fields) >= MARKING_INDEX_COLOR ? fields[MARKING_INDEX_COLOR] : null
			emissive = length(fields) >= MARKING_INDEX_EMISSIVE ? fields[MARKING_INDEX_EMISSIVE] : FALSE
		. += new /datum/body_marking_entry(marking, zone, color, emissive)

/**
 * Rebuilds one zone's nested shape from its entries: marking name -> list(color, emissive).
 *
 * Arguments:
 * - zone_entries: the entries, in order.
 *
 * Returns:
 * - list: a new list, empty when there are no entries.
 */
/proc/body_marking_entries_to_list(list/zone_entries)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/body_marking_entry/entry as anything in zone_entries)
		.[entry.marking.name] = list(entry.get_color(), entry.get_emissive())

/**
 * Copies a list of entries into new ones, as deep_copy_list() copied the nested shape.
 *
 * Arguments:
 * - zone_entries: the entries to copy.
 *
 * Returns:
 * - list: new entries in the same order, or null for null.
 */
/proc/body_marking_entries_copy(list/zone_entries)
	RETURN_TYPE(/list)
	if(isnull(zone_entries))
		return null
	. = list()
	for(var/datum/body_marking_entry/entry as anything in zone_entries)
		. += entry.copy()
