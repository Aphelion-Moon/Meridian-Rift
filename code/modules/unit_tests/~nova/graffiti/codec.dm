/// A raw piece as Export writes it: an opaque and a translucent pixel at the top left of an unlit layer, under a glowing layer with one translucent pixel at the bottom right.
/proc/graffiti_test_piece(width = GRAFFITI_WIDE_WIDTH)
	var/pixel_count = width * GRAFFITI_HEIGHT
	return list("format" = GRAFFITI_FORMAT, "version" = GRAFFITI_FORMAT_VERSION, "name" = "Tom & Jerry", "description" = "Signed <b>J</b>", "width" = width, "palette" = list("#ff0000", "#39ff1480"), "layers" = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid("12[repeat_string(pixel_count - 2, "0")]", 2, pixel_count)),
		list("name" = "Drip", "glow" = TRUE, "grid" = custom_sprite_encode_grid("[repeat_string(pixel_count - 1, "0")]2", 2, pixel_count)),
	))

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
