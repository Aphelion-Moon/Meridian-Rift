/// Sampled cloth colours by sprite, state and tints (sample_fabric_colour()).
GLOBAL_DATUM_INIT(bulge_sample_cache, /datum/bulge_bounded_cache/samples, new)
/// Adaptive palettes by colour and finish (get_bulge_palette()).
GLOBAL_DATUM_INIT(bulge_palette_cache, /datum/bulge_bounded_cache/palettes, new)

/// A cache of at most `limit` entries that drops the oldest first. A dropped entry only costs its computation again.
/datum/bulge_bounded_cache
	/// Most entries kept.
	var/limit
	/// Key -> value. Lazy.
	var/list/entries
	/// Keys in the order they were stored, for dropping the oldest. Lazy.
	var/list/keys
	/// Where the next key goes once the cache is full: the oldest.
	var/cursor = 1

/datum/bulge_bounded_cache/samples
	limit = 256

/datum/bulge_bounded_cache/palettes
	limit = 512

/// The value stored for `key`, or null.
/datum/bulge_bounded_cache/proc/fetch(key)
	return LAZYACCESS(entries, key)

/// Stores `value` for `key` unless one is stored already, and returns the stored one.
/datum/bulge_bounded_cache/proc/store_value(key, value)
	if(isnull(key) || isnull(value))
		return value
	if(!isnull(LAZYACCESS(entries, key)))
		return LAZYACCESS(entries, key)
	if(LAZYLEN(keys) < limit)
		LAZYADD(keys, key)
	else
		var/old_key = keys[cursor]
		entries -= old_key
		keys[cursor] = key
		cursor = (cursor % limit) + 1
	LAZYSET(entries, key, value)
	return value

/// Empties the cache.
/datum/bulge_bounded_cache/proc/clear()
	entries = null
	keys = null
	cursor = 1

/datum/bulge_bounded_cache/Destroy()
	clear()
	return ..()

/// The adaptive palette of a cloth colour in a finish (BULGE_FINISH_*): five "#rrggbb" strings, cloth, light,
/// highlight, shade and deep shade, or null for no colour. One shared list per (colour, finish): never change it.
/proc/get_bulge_palette(colour, finish)
	if(isnull(colour))
		return null
	var/key = "[colour]|[finish]"
	var/list/cached = GLOB.bulge_palette_cache.fetch(key)
	if(cached)
		return cached
	var/list/channels = rgb2num(colour)
	var/list/palette = bulge_palette_exception(channels[1], channels[2], channels[3], finish)
	if(palette)
		return GLOB.bulge_palette_cache.store_value(key, palette)
	var/list/raw
	switch(finish)
		if(BULGE_FINISH_DENIM)
			raw = bulge_adaptive(channels[1], channels[2], channels[3], 0.75, 0.75, 0)
		if(BULGE_FINISH_LEATHER)
			raw = bulge_adaptive(channels[1], channels[2], channels[3], 0.55, 1, 0)
		else
			raw = bulge_adaptive(channels[1], channels[2], channels[3], 1, 1.4, 1)
	palette = list()
	for(var/list/channels_out as anything in raw)
		palette += rgb(channels_out[1], channels_out[2], channels_out[3])
	return GLOB.bulge_palette_cache.store_value(key, palette)

/**
 * The cloth colour of a worn sprite, as the approved previews sample it: every opaque pixel of rows 21-24, columns
 * 12-18 facing south (GetPixel() x 13-19, y 11-8), tinted (each tint rounds half to even), stable-sorted by Rec. 601
 * luma; the upper median. Cached by file, state, tints and source revision; a sprite that is neither a file nor text
 * is sampled without being cached. Null when nothing opaque is there.
 */
/proc/sample_fabric_colour(file, state, tint, outer_tint = null, source_revision = null)
	var/key
	if((isfile(file) || istext(file)) && length("[file]"))
		var/file_text = "[file]"
		key = "[length(file_text)]:[file_text][length(state)]:[state]|[tint]|[outer_tint]|[source_revision]"
		if(length(key) > 1024)
			key = null // Bound retained key payload as well as entry count.
		var/cached = isnull(key) ? null : GLOB.bulge_sample_cache.fetch(key)
		if(!isnull(cached))
			return cached
	if(!file || !state || !icon_exists(file, state))
		return null
	var/icon/sprite = icon(file, state, SOUTH, 1)
	var/list/tint_channels = istext(tint) ? rgb2num(tint) : null
	var/list/outer_channels = istext(outer_tint) ? rgb2num(outer_tint) : null
	var/list/pixels = list()
	var/list/lumas = list()
	for(var/y = 11; y >= 8; y--)
		for(var/x in 13 to 19)
			var/pixel = sprite.GetPixel(x, y)
			if(!pixel)
				continue
			var/list/channels = rgb2num(pixel)
			if(length(channels) > 3 && !channels[4])
				continue
			for(var/channel in 1 to 3)
				if(tint_channels)
					channels[channel] = bulge_round_half_even(channels[channel] * tint_channels[channel] / 255)
				if(outer_channels)
					channels[channel] = bulge_round_half_even(channels[channel] * outer_channels[channel] / 255)
			var/luma = 0.299 * channels[1] + 0.587 * channels[2] + 0.114 * channels[3]
			var/position = 1
			while(position <= length(lumas) && lumas[position] <= luma)
				position++
			pixels.Insert(position, rgb(channels[1], channels[2], channels[3]))
			lumas.Insert(position, luma)
	if(!length(pixels))
		return null
	var/result = pixels[floor(length(pixels) / 2) + 1]
	return isnull(key) ? result : GLOB.bulge_sample_cache.store_value(key, result)
