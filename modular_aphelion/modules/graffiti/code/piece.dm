/// Most colours a flattened art may hold: as many as two grid characters can index.
#define GRAFFITI_FLAT_MAX_COLORS 4095
/// The least alpha paint keeps, 20%, so translucent paint still shows: a lower one is raised to it, and 0 is refused.
#define GRAFFITI_ALPHA_FLOOR 51

/**
 * Returns a colour in its canonical graffiti form: lowercase `#rrggbb` when its alpha reaches GRAFFITI_ALPHA_CEILING,
 * the alpha placed graffiti draws opaque paint at, and `#rrggbbaa` below it, raised to GRAFFITI_ALPHA_FLOOR when lower.
 * So a stored colour's real alpha is the ceiling when it has seven characters, and its own alpha when it has nine.
 *
 * sanitize_hexcolor() can't widen six digits to eight, and it answers bad input with `#00000000` rather
 * than the null default, so opaque input is padded to eight digits first and the sanitized text must match
 * the input exactly.
 *
 * Arguments:
 * - color: `#rrggbb` or `#rrggbbaa` text, in either case.
 *
 * Returns:
 * - text: The canonical colour.
 * - null: Anything else, or an alpha of 0, which paints nothing.
 */
/proc/graffiti_color(color)
	if(!istext(color) || (length(color) != 7 && length(color) != 9))
		return null
	var/clean = LOWER_TEXT(color)
	if(length(clean) == 7)
		clean += "ff"
	if(sanitize_hexcolor(clean, 8, TRUE, null) != clean)
		return null
	var/alpha = hex2num(copytext(clean, 8))
	if(!alpha)
		return null
	if(alpha >= GRAFFITI_ALPHA_CEILING)
		return copytext(clean, 1, 8)
	return alpha < GRAFFITI_ALPHA_FLOOR ? "[copytext(clean, 1, 8)][num2hex(GRAFFITI_ALPHA_FLOOR, 2)]" : clean

/**
 * Packs canonical colours into one string of nine-character `#rrggbbaa` entries, the form placed art keeps
 * its palette in.
 *
 * Arguments:
 * - palette: Canonical colours, as graffiti_color() returns them.
 *
 * Returns:
 * - text: The packed palette. Opaque colours gain `ff`.
 */
/proc/graffiti_palette_pack(list/palette)
	var/list/entries = list()
	for(var/color in palette)
		entries += (length(color) == 7 ? "[color]ff" : color)
	return jointext(entries, "")

/**
 * Unpacks a palette graffiti_palette_pack() wrote. Only its lowercase spelling is read, so an art has one
 * packed form and one hash.
 *
 * Arguments:
 * - packed: Nine-character `#rrggbbaa` entries.
 *
 * Returns:
 * - list: The canonical colours in order, empty for an empty string.
 * - null: The length isn't a multiple of nine, or an entry isn't a lowercase colour.
 */
/proc/graffiti_palette_unpack(packed)
	if(!istext(packed) || length(packed) % 9)
		return null
	. = list()
	for(var/position = 1; position < length(packed); position += 9)
		var/color = copytext(packed, position, position + 9)
		if(copytext(color, 1, 2) != "#" || spantext(color, "0123456789abcdef", 2) != 8)
			return null
		. += (copytext(color, 8) == "ff" ? copytext(color, 1, 8) : color)

/**
 * Encodes palette indices as a flat art grid.
 *
 * A grid is `g1` or `g2`, the number of characters each index takes, then runs: a hex length (1-f) and
 * the run's index in CUSTOM_SPRITE_INDEX_ALPHABET characters, most significant first. Index 0 is
 * transparent. Palettes of up to GRAFFITI_MAX_COLORS colours take one character; larger ones, which only
 * merged art reaches, take two.
 *
 * Arguments:
 * - indices: One palette index per pixel, row by row from the top left.
 * - palette_size: How many colours the indices can reach. 0 allows only transparent pixels.
 *
 * Returns:
 * - text: The grid.
 * - null: The palette size is out of range, or an index isn't a number from 0 to `palette_size`.
 */
/proc/graffiti_encode_flat(list/indices, palette_size)
	if(!isnum(palette_size) || palette_size < 0 || palette_size > GRAFFITI_FLAT_MAX_COLORS)
		return null
	var/list/codes = graffiti_flat_codes()
	var/list/run_characters = codes[1]
	var/list/digit_characters = codes[2]
	var/digits = palette_size > GRAFFITI_MAX_COLORS ? 2 : 1
	var/list/runs = list("g[digits]")
	var/pixel_count = length(indices)
	for(var/position = 1; position <= pixel_count;)
		var/index = indices[position]
		if(!isnum(index) || index < 0 || index > palette_size)
			return null
		var/run = 1
		while(run < 15 && position + run <= pixel_count && indices[position + run] == index)
			run++
		runs += run_characters[run]
		// Most significant first, as custom_sprite_canvas_code() writes them.
		if(digits == 2)
			runs += digit_characters[round(index / 64) % 64 + 1]
		runs += digit_characters[index % 64 + 1]
		position += run
	return jointext(runs, "")

/**
 * Decodes a flat art grid that graffiti_encode_flat() wrote. Hostile input is refused before anything is
 * expanded, and decoding stops at `pixel_count` whatever the runs claim.
 *
 * Arguments:
 * - encoded: The grid.
 * - palette_size: How many colours its indices may reach.
 * - pixel_count: How many pixels it must cover, at most a wide canvas.
 *
 * Returns:
 * - list: `pixel_count` palette indices, 0 where transparent.
 * - null: The prefix doesn't fit the palette size, a run is malformed, an index is past the palette, or
 *   the runs cover another number of pixels.
 */
/proc/graffiti_decode_flat(encoded, palette_size, pixel_count)
	if(!istext(encoded) || !isnum(palette_size) || palette_size < 0 || palette_size > GRAFFITI_FLAT_MAX_COLORS || !isnum(pixel_count) || pixel_count < 1 || pixel_count > GRAFFITI_WIDE_WIDTH * GRAFFITI_HEIGHT)
		return null
	var/digits = palette_size > GRAFFITI_MAX_COLORS ? 2 : 1
	var/encoded_length = length(encoded)
	if(copytext(encoded, 1, 3) != "g[digits]" || (encoded_length - 2) % (digits + 1) || encoded_length > 2 + pixel_count * (digits + 1))
		return null
	var/list/values = custom_sprite_index_values()
	var/list/indices = new /list(pixel_count)
	var/decoded_length = 0
	for(var/position = 3; position < encoded_length; position += digits + 1)
		var/run = findtextEx("123456789abcdef", copytext(encoded, position, position + 1))
		var/index = values[copytext(encoded, position + 1, position + 2)]
		if(digits == 2 && !isnull(index))
			var/low = values[copytext(encoded, position + 2, position + 3)]
			index = isnull(low) ? null : index * 64 + low
		if(!run || isnull(index) || index > palette_size || decoded_length + run > pixel_count)
			return null
		for(var/offset in decoded_length + 1 to decoded_length + run)
			indices[offset] = index
		decoded_length += run
	return decoded_length == pixel_count ? indices : null

/**
 * Returns a fingerprint of what merging gives: the alpha ceiling and the hash of one fixed merge of opaque and
 * translucent paint, glowing and not, made once. The map file keeps it beside its stack cache, so a cache written
 * before merges changed is set aside rather than show stacks under keys today's merges wouldn't give.
 *
 * Returns:
 * - text: The fingerprint.
 */
/proc/graffiti_merge_fingerprint()
	var/static/fingerprint
	if(fingerprint)
		return fingerprint
	var/pixel_count = GRAFFITI_WIDTH * GRAFFITI_HEIGHT
	var/list/lower = new /list(pixel_count)
	var/list/upper = new /list(pixel_count)
	var/list/lit = new /list(pixel_count)
	for(var/position in 1 to pixel_count)
		lower[position] = position % 3 ? 1 : 0
		upper[position] = position % 2
		lit[position] = position % 5 ? 0 : 1
	var/list/arts = list(
		list("w" = GRAFFITI_WIDTH, "pal" = "#c0392bff", "grid" = graffiti_encode_flat(lower, 1), "glow" = graffiti_encode_flat(lit, 1)),
		list("w" = GRAFFITI_WIDTH, "pal" = "#2e86c180", "grid" = graffiti_encode_flat(upper, 1), "glow" = graffiti_encode_flat(upper, 1)),
	)
	fingerprint = md5("[GRAFFITI_ALPHA_CEILING]|[graffiti_art_hash(graffiti_merge_arts(arts, GRAFFITI_WIDTH))]")
	return fingerprint

/**
 * Returns the characters a flat grid writes, built once, so encoding looks each run's characters up instead of cutting
 * text and calling custom_sprite_canvas_code() for every run, and the glow of art that glows nowhere at each width.
 *
 * Returns:
 * - list: The run length characters for 1 to 15, the index digit characters for 0 to 63, then graffiti_unlit_glow()
 *   for GRAFFITI_WIDTH and for GRAFFITI_WIDE_WIDTH.
 */
/proc/graffiti_flat_codes()
	var/static/list/codes
	if(codes)
		return codes
	var/list/run_characters = list()
	for(var/run in 1 to 15)
		run_characters += copytext("0123456789abcdef", run + 1, run + 2)
	var/list/digit_characters = list()
	for(var/value in 0 to 63)
		digit_characters += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, value + 1, value + 2)
	codes = list(run_characters, digit_characters)
	// Encoded with the characters above, which encoding finds in place now.
	for(var/width in list(GRAFFITI_WIDTH, GRAFFITI_WIDE_WIDTH))
		var/list/zeros = new /list(width * GRAFFITI_HEIGHT)
		for(var/position in 1 to length(zeros))
			zeros[position] = 0
		codes += list(list(graffiti_encode_flat(zeros, 1), zeros))
	return codes

/**
 * Returns an art's content identity, which tiles showing the same art share.
 *
 * Arguments:
 * - art: The art.
 *
 * Returns:
 * - text: An md5 of the width, palette, grid and glow.
 */
/proc/graffiti_art_hash(list/art)
	return md5("[art["w"]]|[art["pal"]]|[art["grid"]]|[art["glow"]]")

/**
 * Counts an art's painted pixels.
 *
 * Arguments:
 * - art: The art.
 *
 * Returns:
 * - number: Pixels with a colour, 0 when the art can't be decoded.
 */
/proc/graffiti_art_pixels(list/art)
	. = 0
	for(var/index in graffiti_decode_flat(art["grid"], length(art["pal"]) / 9, art["w"] * GRAFFITI_HEIGHT))
		if(index)
			. += 1

/**
 * Decodes an art, such as one read from a map file, when it can be drawn: a one- or two-tile width, a palette of 1
 * to GRAFFITI_FLAT_MAX_COLORS colours, and a grid and glow mask that both cover every pixel.
 *
 * Arguments:
 * - art: The art.
 *
 * Returns:
 * - list: list(palette, indices, glow): its canonical colours, then one palette index and one glow bit per pixel, row by
 *   row from the top left. Art that glows nowhere has graffiti_unlit_glow()'s glow. Never change them.
 * - null: It can't be drawn.
 */
/proc/graffiti_art_decode(list/art)
	if(!islist(art) || !(art["w"] in list(GRAFFITI_WIDTH, GRAFFITI_WIDE_WIDTH)) || !istext(art["pal"]) || length(art["pal"]) > GRAFFITI_FLAT_MAX_COLORS * 9)
		return null
	var/list/palette = graffiti_palette_unpack(art["pal"])
	if(!length(palette))
		return null
	var/pixel_count = art["w"] * GRAFFITI_HEIGHT
	var/list/indices = graffiti_decode_flat(art["grid"], length(palette), pixel_count)
	var/list/unlit = graffiti_unlit_glow(art["w"])
	var/list/glow = indices && (art["glow"] == unlit[1] ? unlit[2] : graffiti_decode_flat(art["glow"], 1, pixel_count))
	return glow ? list(palette, indices, glow) : null

/**
 * Returns the glow of art that glows nowhere, as graffiti_encode_flat() writes it and decoded, which graffiti_flat_codes()
 * makes once for each width, so decoded arts that glow nowhere share one list.
 *
 * Arguments:
 * - width: GRAFFITI_WIDTH or GRAFFITI_WIDE_WIDTH.
 *
 * Returns:
 * - list: The encoded glow, then its pixels, all 0. Never change them.
 */
/proc/graffiti_unlit_glow(width)
	var/list/codes = graffiti_flat_codes()
	return codes[width == GRAFFITI_WIDE_WIDTH ? 4 : 3]

/**
 * Blends a colour over another as placed graffiti shows them, in their real alphas: GRAFFITI_ALPHA_CEILING for opaque
 * paint and its own for translucent paint. The standard "over" operator gives the alpha and the colour, and an alpha
 * that reaches the ceiling is stored opaque.
 *
 * Arguments:
 * - under: The canonical colour beneath.
 * - over: The canonical colour on top.
 *
 * Returns:
 * - text: The canonical blend.
 */
/proc/graffiti_blend(under, over)
	var/list/below = rgb2num(under)
	var/list/above = rgb2num(over)
	var/over_alpha = length(over) == 7 ? GRAFFITI_ALPHA_CEILING : above[4]
	var/under_alpha = length(under) == 7 ? GRAFFITI_ALPHA_CEILING : below[4]
	// In alpha bytes scaled by 255, so every sum and product is a whole number a BYOND float holds exactly.
	var/over_weight = over_alpha * 255
	var/under_weight = under_alpha * (255 - over_alpha)
	var/total = over_weight + under_weight
	var/alpha = round(total / 255, 1)
	var/red = round((above[1] * over_weight + below[1] * under_weight) / total, 1)
	var/green = round((above[2] * over_weight + below[2] * under_weight) / total, 1)
	var/blue = round((above[3] * over_weight + below[3] * under_weight) / total, 1)
	// rgb() text is always well formed, so graffiti_color()'s checks would only cost time.
	return LOWER_TEXT(alpha >= GRAFFITI_ALPHA_CEILING ? rgb(red, green, blue) : rgb(red, green, blue, alpha))

/**
 * Merges arts of one width into one, bottom to top.
 *
 * An opaque pixel replaces what is beneath it, a translucent one blends over it (graffiti_blend()), and a fully
 * transparent one leaves it alone. A pixel glows when the topmost art that paints it glows there. The merged palette
 * holds only the colours the result shows, in the order its pixels first use them, so arts that look alike merge to the
 * same art. Arts that aren't lists, have another width or can't be decoded are left out.
 *
 * Arguments:
 * - arts: The arts, bottom first.
 * - width: The width of every art.
 * - owner_out: When given, filled with one entry per pixel: the position in `arts` of the art whose paint
 *   is topmost there, 0 where nothing is painted.
 * - decoded: When given, each art's graffiti_art_decode() in the same order, so none is decoded again. A null
 *   entry is decoded here.
 * - decoded_out: When given, filled with the merged art's graffiti_art_decode(), from the merge itself.
 *
 * Returns:
 * - list: The merged art. With nothing painted, its palette is empty.
 * - null: The result needs more than GRAFFITI_FLAT_MAX_COLORS colours.
 */
/proc/graffiti_merge_arts(list/arts, width, list/owner_out = null, list/decoded = null, list/decoded_out = null)
	var/pixel_count = width * GRAFFITI_HEIGHT
	var/list/pixels = new /list(pixel_count)
	var/list/glow = new /list(pixel_count)
	var/list/blends = list()
	if(owner_out)
		owner_out.Cut()
		owner_out.len = pixel_count
	for(var/spot in 1 to length(arts))
		var/list/art = arts[spot]
		if(!islist(art) || art["w"] != width)
			continue
		var/list/record = spot <= length(decoded) ? decoded[spot] : null
		var/list/palette
		var/list/indices
		var/list/glowing
		if(record)
			var/list/colors = record[1]
			// A copy, as transparent colours are blanked below.
			palette = colors.Copy()
			indices = record[2]
			glowing = record[3]
		else
			palette = graffiti_palette_unpack(art["pal"])
			indices = palette && graffiti_decode_flat(art["grid"], length(palette), pixel_count)
			glowing = indices && graffiti_decode_flat(art["glow"], 1, pixel_count)
		if(!glowing)
			continue
		for(var/position in 1 to length(palette))
			if(copytext(palette[position], 8) == "00")
				palette[position] = null
		for(var/position in 1 to pixel_count)
			var/index = indices[position]
			var/color = index && palette[index]
			if(!color)
				continue
			var/under = pixels[position]
			if(under && length(color) == 9)
				var/key = "[under][color]"
				if(!blends[key])
					blends[key] = graffiti_blend(under, color)
				color = blends[key]
			pixels[position] = color
			glow[position] = glowing[position]
			if(owner_out)
				owner_out[position] = spot
	var/list/new_palette = list()
	for(var/position in 1 to pixel_count)
		var/color = pixels[position]
		if(!color)
			pixels[position] = 0
			glow[position] = 0
			if(owner_out)
				owner_out[position] = 0
			continue
		var/index = new_palette[color]
		if(!index)
			if(length(new_palette) >= GRAFFITI_FLAT_MAX_COLORS)
				return null
			index = length(new_palette) + 1
			new_palette[color] = index
		pixels[position] = index
	if(decoded_out)
		var/list/colors = list()
		for(var/color in new_palette)
			colors += color
		decoded_out.Cut()
		decoded_out += list(colors, pixels, glow)
	return list("w" = width, "pal" = graffiti_palette_pack(new_palette), "grid" = graffiti_encode_flat(pixels, length(new_palette)), "glow" = graffiti_encode_flat(glow, 1))

/**
 * Flattens a piece's layers into one art, or only as much of them as a paint job has revealed.
 *
 * Arguments:
 * - piece: A canonical piece.
 * - upto_layer: The layer being revealed: every layer below it shows fully and none above it. 0 shows
 *   the whole piece.
 * - upto_x: How many columns of `upto_layer` show, counted from the left.
 *
 * Returns:
 * - list: The art, as graffiti_merge_arts() returns it.
 */
/proc/graffiti_flatten(list/piece, upto_layer = 0, upto_x = 0)
	return graffiti_flatten_records(graffiti_layer_records(piece, upto_layer), piece["width"], upto_layer, upto_x)

/**
 * Decodes a piece's layers for graffiti_merge_arts(), each against the piece's whole palette, glowing on every pixel or on
 * none. A paint job keeps its piece's records, so its steps never decode the layers again.
 *
 * Arguments:
 * - piece: A canonical piece.
 * - count: How many layers from the bottom, or 0 for every layer.
 *
 * Returns:
 * - list: A graffiti_art_decode() record for each layer, bottom first: the piece's palette, the layer's palette index for
 *   each pixel, and its glow on every pixel. Null for a layer whose grid can't be decoded. Never change them.
 */
/proc/graffiti_layer_records(list/piece, count = 0)
	var/width = piece["width"]
	var/pixel_count = width * GRAFFITI_HEIGHT
	// As a layer art carries the palette and the merge reads it back.
	var/list/palette = graffiti_palette_unpack(graffiti_palette_pack(piece["palette"]))
	var/list/values = custom_sprite_index_values()
	var/list/layers = piece["layers"]
	var/list/unlit = graffiti_unlit_glow(width)[2]
	var/list/lit
	. = list()
	for(var/index in 1 to (count ? min(count, length(layers)) : length(layers)))
		var/list/layer = layers[index]
		var/grid = palette && custom_sprite_decode_grid(layer["grid"], length(piece["palette"]), pixel_count)
		if(!grid)
			. += list(null)
			continue
		var/list/indices = new /list(pixel_count)
		for(var/position in 1 to pixel_count)
			indices[position] = values[copytext(grid, position, position + 1)]
		if(layer["glow"] && !lit)
			lit = new /list(pixel_count)
			for(var/position in 1 to pixel_count)
				lit[position] = 1
		. += list(list(palette, indices, layer["glow"] ? lit : unlit))

/**
 * Flattens decoded layers into one art, or only as much of them as a paint job has revealed. Nothing is encoded or
 * decoded on the way, so it is graffiti_flatten() for layers already decoded.
 *
 * Arguments:
 * - records: Each layer's graffiti_art_decode() record, bottom first, as graffiti_layer_records() or a graffiti
 *   workspace's layer_records() make them. A null record is left out.
 * - width: The layers' width.
 * - upto_layer: The layer being revealed: every layer below it shows fully and none above it. 0 shows them all.
 * - upto_x: How many columns of `upto_layer` show, counted from the left.
 * - decoded_out: When given, filled with the art's graffiti_art_decode(), from the merge itself.
 *
 * Returns:
 * - list: The art, as graffiti_merge_arts() returns it.
 */
/proc/graffiti_flatten_records(list/records, width, upto_layer = 0, upto_x = 0, list/decoded_out = null)
	var/list/arts = list()
	var/list/kept = list()
	// graffiti_merge_arts() checks each art's width, then reads its record.
	var/list/stand_in = list("w" = width)
	for(var/index in 1 to (upto_layer ? min(upto_layer, length(records)) : length(records)))
		var/list/record = records[index]
		if(record && index == upto_layer)
			var/list/indices = record[2]
			// A copy, so the record stays whole for the next step.
			indices = indices.Copy()
			for(var/row_start = 0; row_start < length(indices); row_start += width)
				for(var/column in upto_x + 1 to width)
					indices[row_start + column] = 0
			record = list(record[1], indices, record[3])
		arts += list(record && stand_in)
		kept += list(record)
	return graffiti_merge_arts(arts, width, null, kept, decoded_out)

/**
 * Splits a wide art into the arts of its two tiles.
 *
 * Each half keeps only the colours it shows, in the order its pixels first use them, and glows only where it is
 * painted, as graffiti_merge_arts() would leave it. So a half hashes the same as a one-tile art that looks the
 * same, and two halves that look alike share one hash.
 *
 * Arguments:
 * - art: A GRAFFITI_WIDE_WIDTH art.
 * - decoded: The art's graffiti_art_decode(), when the caller has it.
 * - decoded_out: When given, filled with each half's graffiti_art_decode(), left first.
 *
 * Returns:
 * - list: The left tile's art, then the right one's, each GRAFFITI_WIDTH wide.
 * - null: The art isn't wide or can't be decoded.
 */
/proc/graffiti_split_wide(list/art, list/decoded = null, list/decoded_out = null)
	if(art?["w"] != GRAFFITI_WIDE_WIDTH)
		return null
	var/pixel_count = GRAFFITI_WIDE_WIDTH * GRAFFITI_HEIGHT
	var/list/palette = decoded ? decoded[1] : graffiti_palette_unpack(art["pal"])
	var/list/indices = decoded ? decoded[2] : (palette && graffiti_decode_flat(art["grid"], length(palette), pixel_count))
	var/list/glow = decoded ? decoded[3] : (indices && graffiti_decode_flat(art["glow"], 1, pixel_count))
	if(!glow)
		return null
	decoded_out?.Cut()
	. = list()
	for(var/offset in list(0, GRAFFITI_WIDTH))
		var/list/pixels = list()
		var/list/glowing = list()
		var/list/new_palette = list()
		for(var/row in 0 to GRAFFITI_HEIGHT - 1)
			var/start = row * GRAFFITI_WIDE_WIDTH + offset
			for(var/column in 1 to GRAFFITI_WIDTH)
				var/index = indices[start + column]
				if(index)
					var/color = palette[index]
					index = new_palette[color]
					if(!index)
						index = length(new_palette) + 1
						new_palette[color] = index
				pixels += index
				glowing += (index ? glow[start + column] : 0)
		. += list(list("w" = GRAFFITI_WIDTH, "pal" = graffiti_palette_pack(new_palette), "grid" = graffiti_encode_flat(pixels, length(new_palette)), "glow" = graffiti_encode_flat(glowing, 1)))
		if(decoded_out)
			var/list/colors = list()
			for(var/color in new_palette)
				colors += color
			decoded_out += list(list(colors, pixels, glowing))

/**
 * Narrows a two-tile piece to one tile when no layer paints its right tile, as a wide canvas left blank there saves.
 *
 * Arguments:
 * - piece: A canonical piece. It is never changed.
 * - grids: Its layers' grids decoded, as graffiti_validate_piece() has them, or null to decode them here.
 *
 * Returns:
 * - list: A new piece GRAFFITI_WIDTH wide, each layer's grid cut to its left columns.
 * - list: `piece` itself, when it is one tile wide, paints its right tile or can't be decoded.
 */
/proc/graffiti_trim_wide(list/piece, list/grids = null)
	if(piece?["width"] != GRAFFITI_WIDE_WIDTH)
		return piece
	var/list/palette = piece["palette"]
	var/list/layers = piece["layers"]
	var/list/narrow_grids = list()
	for(var/index in 1 to length(layers))
		var/grid = index <= length(grids) ? grids[index] : custom_sprite_decode_grid(layers[index]["grid"], length(palette), GRAFFITI_WIDE_WIDTH * GRAFFITI_HEIGHT)
		if(!grid)
			return piece
		var/list/rows = list()
		for(var/row_start = 1; row_start < length(grid); row_start += GRAFFITI_WIDE_WIDTH)
			// Counted from column 33, transparent pixels may run on into the next row: 32 of them clear this row's right tile.
			if(spantext(grid, "0", row_start + GRAFFITI_WIDTH) < GRAFFITI_WIDTH)
				return piece
			rows += copytext(grid, row_start, row_start + GRAFFITI_WIDTH)
		narrow_grids += jointext(rows, "")
	var/list/narrow_layers = list()
	for(var/index in 1 to length(layers))
		var/list/layer = layers[index]
		narrow_layers += list(list("name" = layer["name"], "glow" = layer["glow"], "grid" = custom_sprite_encode_grid(narrow_grids[index], length(palette), GRAFFITI_WIDTH * GRAFFITI_HEIGHT)))
	var/list/narrowed = piece.Copy()
	narrowed["width"] = GRAFFITI_WIDTH
	narrowed["palette"] = palette.Copy()
	narrowed["layers"] = narrow_layers
	return narrowed

/**
 * Strictly validates a library piece, as Export writes it and Import reads it. Nothing is salvaged, and
 * messages never repeat uploaded text.
 *
 * The `id`, `created` and `updated` keys the library keeps beside a piece are allowed and ignored. Names
 * and the description are cleaned rather than refused.
 *
 * Arguments:
 * - raw: The decoded piece.
 *
 * Returns:
 * - list: The canonical piece: `name`, `description`, `width`, `palette` and `layers`, each layer a
 *   `name`, `glow` and re-encoded `grid`. Its colours are graffiti_color()'s, and a two-tile piece that paints
 *   nothing on its right tile comes back one tile wide (graffiti_trim_wide()).
 * - text: Why the piece was refused, safe to show the player.
 */
/proc/graffiti_validate_piece(list/raw)
	var/list/required = list("format", "version", "name", "description", "width", "palette", "layers")
	if(!islist(raw))
		return "The graffiti piece is malformed."
	if(custom_style_unknown_key(raw, required + list("id", "created", "updated")))
		return "The graffiti piece has an unsupported field."
	for(var/key in required)
		if(!(key in raw))
			return "The graffiti piece is missing \"[key]\"."
	if(raw["format"] != GRAFFITI_FORMAT)
		return "That isn't a graffiti piece."
	if(raw["version"] != GRAFFITI_FORMAT_VERSION)
		return "The graffiti piece uses an unsupported version."
	var/width = raw["width"]
	if(!(width in list(GRAFFITI_WIDTH, GRAFFITI_WIDE_WIDTH)))
		return "A graffiti piece must be [GRAFFITI_WIDTH] or [GRAFFITI_WIDE_WIDTH] pixels wide."
	var/list/raw_palette = raw["palette"]
	if(!islist(raw_palette) || !length(raw_palette) || length(raw_palette) > GRAFFITI_MAX_COLORS)
		return "The graffiti piece's palette is invalid or has more than [GRAFFITI_MAX_COLORS] colors."
	var/list/palette = list()
	for(var/raw_color, associated in raw_palette)
		var/color = graffiti_color(raw_color)
		if(!color || (color in palette) || !isnull(associated))
			return "The graffiti piece's palette has an invalid or repeated color."
		palette += color
	var/list/raw_layers = raw["layers"]
	if(!islist(raw_layers) || !length(raw_layers) || length(raw_layers) > GRAFFITI_MAX_LAYERS)
		return "A graffiti piece must have 1 to [GRAFFITI_MAX_LAYERS] layers."
	var/pixel_count = width * GRAFFITI_HEIGHT
	var/painted = FALSE
	var/list/layers = list()
	// Each layer's grid decoded, for graffiti_trim_wide().
	var/list/grids = list()
	for(var/entry in raw_layers)
		var/label = "Layer [length(layers) + 1]"
		var/list/layer = entry
		if(!islist(layer) || length(layer) != 3 || custom_style_unknown_key(layer, list("name", "glow", "grid")))
			return "[label] must have exactly a name, a glow setting and a grid."
		if(!(layer["glow"] in list(TRUE, FALSE)))
			return "[label]'s glow setting must be true or false."
		var/grid = custom_sprite_decode_grid(layer["grid"], length(palette), pixel_count)
		if(!grid)
			return "[label] has invalid pixel data."
		painted ||= spantext(grid, "0") != pixel_count
		layers += list(list("name" = graffiti_clean_text(layer["name"], GRAFFITI_MAX_LAYER_NAME) || "Untitled", "glow" = layer["glow"], "grid" = custom_sprite_encode_grid(grid, length(palette), pixel_count)))
		grids += grid
	if(!painted)
		return "The graffiti piece has no paint."
	return graffiti_trim_wide(list("name" = graffiti_clean_text(raw["name"], GRAFFITI_MAX_NAME) || "Untitled", "description" = graffiti_clean_text(raw["description"], GRAFFITI_MAX_DESCRIPTION), "width" = width, "palette" = palette, "layers" = layers), grids)

/**
 * Cleans player text for a piece's name, description or layer names, so that cleaning it again changes
 * nothing.
 *
 * Entities are decoded first so escaped text isn't escaped twice, and the text is cut to `max_length`
 * characters before it is escaped so the cut can't split an entity.
 *
 * Arguments:
 * - text: The player's text.
 * - max_length: Most characters kept.
 *
 * Returns:
 * - text: The trimmed, escaped text, "" when nothing is left. Callers supply their own default.
 */
/proc/graffiti_clean_text(text, max_length)
	if(!istext(text))
		return ""
	return html_encode(trim(html_decode(text), max_length + 1))

/**
 * Returns a canonical piece as the text Export writes, `format` and `version` first.
 *
 * Arguments:
 * - piece: A canonical piece.
 *
 * Returns:
 * - text: The piece's JSON.
 */
/proc/graffiti_encode_piece(list/piece)
	return json_encode(list("format" = GRAFFITI_FORMAT, "version" = GRAFFITI_FORMAT_VERSION, "name" = piece["name"], "description" = piece["description"], "width" = piece["width"], "palette" = piece["palette"], "layers" = piece["layers"]))

#undef GRAFFITI_FLAT_MAX_COLORS
#undef GRAFFITI_ALPHA_FLOOR
