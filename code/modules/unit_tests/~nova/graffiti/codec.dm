/// A raw piece as Export writes it: an opaque and a translucent pixel at the top left of an unlit layer, under a glowing layer with one translucent pixel at the bottom right.
/proc/graffiti_test_piece(width = GRAFFITI_WIDE_WIDTH)
	var/pixel_count = width * GRAFFITI_HEIGHT
	return list("format" = GRAFFITI_FORMAT, "version" = GRAFFITI_FORMAT_VERSION, "name" = "Tom & Jerry", "description" = "Signed <b>J</b>", "width" = width, "palette" = list("#ff0000", "#39ff1480"), "layers" = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid("12[repeat_string(pixel_count - 2, "0")]", 2, pixel_count)),
		list("name" = "Drip", "glow" = TRUE, "grid" = custom_sprite_encode_grid("[repeat_string(pixel_count - 1, "0")]2", 2, pixel_count)),
	))

/// One pixel of an art as "colour|glow", or "|0" where nothing is painted.
/proc/graffiti_test_pixel(list/art, position)
	var/list/palette = graffiti_palette_unpack(art["pal"])
	var/pixel_count = art["w"] * GRAFFITI_HEIGHT
	var/list/indices = graffiti_decode_flat(art["grid"], length(palette), pixel_count)
	var/list/glow = graffiti_decode_flat(art["glow"], 1, pixel_count)
	if(!indices || !glow)
		return "unreadable"
	return "[indices[position] ? palette[indices[position]] : ""]|[glow[position]]"

/// Flat grids round-trip with one and with two index characters, and refuse an index past the palette, a wrong length and a wrong prefix.
/datum/unit_test/graffiti_flat_codec/Run()
	var/list/indices = list()
	for(var/position in 1 to 1024)
		indices += (position <= 512 ? position % 71 : 0)
	var/encoded = graffiti_encode_flat(indices, 70)
	TEST_ASSERT_EQUAL(copytext(encoded, 1, 3), "g2", "Seventy colours must take two index characters.")
	TEST_ASSERT_EQUAL(json_encode(graffiti_decode_flat(encoded, 70, 1024)), json_encode(indices), "A 70-colour grid must round-trip.")
	TEST_ASSERT_NULL(graffiti_decode_flat(encoded, 69, 1024), "An index past the palette must be refused.")
	indices.Cut()
	for(var/position in 1 to 1024)
		indices += round(position / 20) % 4
	encoded = graffiti_encode_flat(indices, 3)
	TEST_ASSERT_EQUAL(copytext(encoded, 1, 3), "g1", "Three colours must take one index character.")
	TEST_ASSERT_EQUAL(json_encode(graffiti_decode_flat(encoded, 3, 1024)), json_encode(indices), "A 3-colour grid must round-trip.")
	TEST_ASSERT_NULL(graffiti_decode_flat(encoded, 2, 1024), "An index past the palette must be refused.")
	for(var/bad in list(copytext(encoded, 1, length(encoded) - 1), copytext(encoded, 1, length(encoded)), "[encoded]11", "g2[copytext(encoded, 3)]", "r[copytext(encoded, 2)]"))
		TEST_ASSERT_NULL(graffiti_decode_flat(bad, 3, 1024), "Accepted a malformed grid: [copytext(bad, 1, 20)]")
	TEST_ASSERT_NULL(graffiti_decode_flat(encoded, 3, 2048), "A grid must cover exactly the canvas it is read for.")

/// Across layers the topmost painted pixel decides the glow and a translucent one blends over what is beneath; a partial reveal stops at its column, and a wide art splits into its two tiles.
/datum/unit_test/graffiti_flatten_glow_alpha/Run()
	var/list/piece = list("name" = "Flatten", "description" = "", "width" = GRAFFITI_WIDTH, "palette" = list("#ff0000", "#39ff1480", "#ffffff"), "layers" = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid("111[repeat_string(1021, "0")]", 3, 1024)),
		list("name" = "Drip", "glow" = TRUE, "grid" = custom_sprite_encode_grid("23[repeat_string(1022, "0")]", 3, 1024)),
	))
	var/expected = graffiti_blend("#ff0000", "#39ff1480")
	var/list/art = graffiti_flatten(piece)
	TEST_ASSERT_EQUAL(graffiti_test_pixel(art, 1), "[expected]|1", "A translucent glowing pixel must blend over the pixel beneath and glow.")
	TEST_ASSERT_EQUAL(graffiti_test_pixel(art, 2), "#ffffff|1", "An opaque glowing pixel must replace the pixel beneath and glow.")
	TEST_ASSERT_EQUAL(graffiti_test_pixel(art, 3), "#ff0000|0", "A pixel only the unlit layer paints must keep its colour and stay unlit.")
	var/list/owners = list()
	// Each layer's record merged as graffiti_flatten_records() merges them: a stand-in art that names its width.
	graffiti_merge_arts(list(list("w" = GRAFFITI_WIDTH), list("w" = GRAFFITI_WIDTH)), GRAFFITI_WIDTH, owners, graffiti_layer_records(piece))
	TEST_ASSERT_EQUAL(json_encode(owners.Copy(1, 5)), json_encode(list(2, 2, 1, 0)), "Each pixel must belong to the topmost art that paints it.")
	art = graffiti_flatten(piece, 2, 1)
	TEST_ASSERT_EQUAL(graffiti_test_pixel(art, 1), "[expected]|1", "A partial reveal must show the top layer up to its column.")
	TEST_ASSERT_EQUAL(graffiti_test_pixel(art, 2), "#ff0000|0", "A partial reveal must not show the top layer past its column.")
	piece["width"] = GRAFFITI_WIDE_WIDTH
	piece["layers"] = list(list("name" = "Wide", "glow" = FALSE, "grid" = custom_sprite_encode_grid("1[repeat_string(95, "0")]3[repeat_string(1951, "0")]", 3, 2048)))
	art = graffiti_flatten(piece)
	var/list/sides = graffiti_split_wide(art)
	TEST_ASSERT(length(sides) == 2 && sides[1]["w"] == GRAFFITI_WIDTH && sides[2]["w"] == GRAFFITI_WIDTH && sides[1]["pal"] == "#ff0000ff" && sides[2]["pal"] == "#ffffffff", "A wide art must split into two one-tile arts, each keeping only the colours it shows.")
	TEST_ASSERT(graffiti_test_pixel(sides[1], 1) == "#ff0000|0" && graffiti_test_pixel(sides[2], 33) == "#ffffff|0", "Each half must keep its own columns of every row.")
	TEST_ASSERT_NOTEQUAL(graffiti_art_hash(sides[1]), graffiti_art_hash(sides[2]), "Halves that differ must hash differently.")

/**
 * Returns a fixed piece for the flattened-bytes test: an opaque red base on rows 1-30, a translucent green glowing layer
 * on rows 9-16 and a translucent white unlit one on rows 13-20, so it blends translucent over opaque and translucent
 * over translucent, and its glow is mixed.
 *
 * Returns:
 * - list: The piece, as graffiti_validate_piece() returns one.
 */
/proc/graffiti_test_golden_piece()
	return list("name" = "Golden", "description" = "", "width" = GRAFFITI_WIDTH, "palette" = list("#ff0000", "#00ff0080", "#ffffffc0"), "layers" = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid("[repeat_string(960, "1")][repeat_string(64, "0")]", 3, 1024)),
		list("name" = "Glaze", "glow" = TRUE, "grid" = custom_sprite_encode_grid("[repeat_string(256, "0")][repeat_string(256, "2")][repeat_string(512, "0")]", 3, 1024)),
		list("name" = "Shine", "glow" = FALSE, "grid" = custom_sprite_encode_grid("[repeat_string(384, "0")][repeat_string(256, "3")][repeat_string(384, "0")]", 3, 1024)),
	))

/**
 * A fixed piece still flattens to the same bytes, written down on 2026-10-19 once blends worked in the real alphas under
 * GRAFFITI_ALPHA_CEILING, which stored its blends opaque. Sheet files are named by the hashes of the stacks they hold and
 * map files keep art under its hash, so if these change, every map rebuilds all its sheets once and its clients download
 * them again, and art saved before counts as different art from the same art placed after (the unique-art caps). Change
 * them only for a deliberate change to the flattened form.
 */
/datum/unit_test/graffiti_flatten_bytes/Run()
	var/list/art = graffiti_flatten(graffiti_test_golden_piece())
	TEST_ASSERT_EQUAL(art["grid"], "g1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f111f2f2f2f2f2f2f2f282f3f3f3f3f3f3f3f383f4f4f4f4f4f4f4f484f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f151f0f0f0f040", "The fixed piece's flattened grid must keep its bytes.")
	TEST_ASSERT_EQUAL(art["pal"], "#ff0000ff#718e00ff#e1e8caff#ffcacaff", "The fixed piece's flattened palette must keep its bytes.")
	TEST_ASSERT_EQUAL(graffiti_art_hash(art), "dfb8008c48fd821254c6be4f72e292bc", "The fixed piece's flattened art must keep its hash.")

/// Imports refuse unknown fields, five layers, odd widths, bad colours, short grids and empty pieces, and a valid piece survives Export and Import unchanged with its text escaped once.
/datum/unit_test/graffiti_piece_validation/Run()
	var/list/piece = graffiti_validate_piece(graffiti_test_piece())
	TEST_ASSERT(islist(piece), "A valid wide piece must be accepted: [piece]")
	TEST_ASSERT(!findtext(piece["description"], "<"), "Markup in a description must be escaped.")
	TEST_ASSERT_EQUAL(json_encode(graffiti_validate_piece(json_decode(graffiti_encode_piece(piece)))), json_encode(piece), "An exported piece must import unchanged.")
	var/list/cases = list()
	var/list/raw = graffiti_test_piece()
	raw["author"] = "Jane"
	cases["an unknown field"] = raw
	raw = graffiti_test_piece()
	raw["layers"] = list(raw["layers"][1], raw["layers"][1], raw["layers"][1], raw["layers"][1], raw["layers"][1])
	cases["five layers"] = raw
	cases["a 48-pixel width"] = graffiti_test_piece(48)
	raw = graffiti_test_piece()
	raw["palette"] = list("#ff0000", "#39ff14zz")
	cases["a colour with bad hex"] = raw
	raw = graffiti_test_piece()
	raw["layers"][2]["grid"] = custom_sprite_encode_grid(repeat_string(1024, "1"), 2, 1024)
	cases["a grid of the wrong length"] = raw
	raw = graffiti_test_piece()
	for(var/list/layer as anything in raw["layers"])
		layer["grid"] = custom_sprite_encode_grid(repeat_string(2048, "0"), 2, 2048)
	cases["a piece with no paint"] = raw
	for(var/label, variant in cases)
		TEST_ASSERT(istext(graffiti_validate_piece(variant)), "Accepted [label].")

/**
 * Placed graffiti is drawn at most GRAFFITI_ALPHA_CEILING opaque, and translucent paint never under GRAFFITI_ALPHA_FLOOR:
 * a colour from the ceiling up is stored opaque and drawn at the ceiling, one under the floor is raised to it, and a blend
 * works in those real alphas. A two-tile piece that paints nothing on its right tile narrows to one, Import included.
 */
/datum/unit_test/graffiti_alpha_ceiling/Run()
	TEST_ASSERT_EQUAL(graffiti_color("#FF8800F0"), "#ff8800", "An alpha past the ceiling must be stored opaque.")
	TEST_ASSERT_EQUAL(graffiti_color("#ff8800cb"), "#ff8800cb", "An alpha under the ceiling must be kept.")
	TEST_ASSERT_EQUAL(graffiti_color("#ff880010"), "#ff880033", "An alpha under the floor must be raised to it.")
	TEST_ASSERT_NULL(graffiti_color("#ff880000"), "A colour with no alpha must be refused.")
	var/list/piece = list("name" = "Ceiling", "description" = "", "width" = GRAFFITI_WIDTH, "palette" = list("#ff8800"), "layers" = list(
		list("name" = "Paint", "glow" = FALSE, "grid" = custom_sprite_encode_grid(repeat_string(1024, "1"), 1, 1024)),
	))
	var/list/art = graffiti_flatten(piece)
	TEST_ASSERT_EQUAL(art["pal"], "#ff8800ff", "Opaque paint must be stored opaque.")
	var/icon/drawn = graffiti_art_icon(art, null, FALSE)
	TEST_ASSERT_EQUAL(drawn?.GetPixel(1, 1), "#ff8800cc", "Opaque paint must be drawn at the ceiling.")
	piece["palette"] = list("#ff0000", "#0000ff80")
	piece["layers"] = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid("1[repeat_string(1023, "0")]", 2, 1024)),
		list("name" = "Wash", "glow" = FALSE, "grid" = custom_sprite_encode_grid("2[repeat_string(1023, "0")]", 2, 1024)),
	)
	TEST_ASSERT_EQUAL(graffiti_test_pixel(graffiti_flatten(piece), 1), "#71008e|0", "Half-alpha blue over opaque red must blend in real alpha (0.5 + 0.8 x 0.5 = 0.9, past the ceiling) and be stored opaque.")
	// Paint in the first row's 32 columns and the last row's 32nd.
	var/list/wide = list("name" = "Wide", "description" = "", "width" = GRAFFITI_WIDE_WIDTH, "palette" = list("#ff0000"), "layers" = list(
		list("name" = "Left", "glow" = FALSE, "grid" = custom_sprite_encode_grid("[repeat_string(32, "1")][repeat_string(1983, "0")]1[repeat_string(32, "0")]", 1, 2048)),
	))
	var/list/narrowed = graffiti_trim_wide(wide)
	TEST_ASSERT(narrowed["width"] == GRAFFITI_WIDTH && custom_sprite_decode_grid(narrowed["layers"][1]["grid"], 1, 1024) == "[repeat_string(32, "1")][repeat_string(991, "0")]1" && wide["width"] == GRAFFITI_WIDE_WIDTH, "A two-tile piece with nothing on its right tile must narrow to one tile of 32x32 grids, leaving the piece it was given as it was: [json_encode(narrowed)]")
	var/list/imported = graffiti_validate_piece(json_decode(graffiti_encode_piece(wide)))
	TEST_ASSERT(islist(imported) && imported["width"] == GRAFFITI_WIDTH, "An imported two-tile piece with nothing on its right tile must narrow to one: [json_encode(imported)]")
	wide["layers"] += list(list("name" = "Right", "glow" = FALSE, "grid" = custom_sprite_encode_grid("[repeat_string(32, "0")]1[repeat_string(2015, "0")]", 1, 2048)))
	TEST_ASSERT(graffiti_trim_wide(wide) == wide, "A two-tile piece with paint at column 33 on any layer must stay as it is.")
