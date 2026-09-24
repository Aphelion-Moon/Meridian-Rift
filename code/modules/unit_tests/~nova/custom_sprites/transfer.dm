/proc/custom_style_test_hair(style = "Short Hair")
	return list("style" = style, "color" = "#583820", "gradient_style" = "None", "gradient_color" = "#000000", "opacity" = null, "emissive" = FALSE)

/proc/custom_style_test_export(target = "hair", zone = null, list/drawing = custom_sprite_test_drawing())
	return custom_style_export_text(custom_style_package(target, zone, custom_sprite_validate(drawing), target == "hair" ? custom_style_test_hair() : null))

/datum/unit_test/custom_style_transfer_round_trip/Run()
	for(var/zone in list(null, BODY_ZONE_L_ARM))
		var/target = zone ? "markings" : "hair"
		var/list/drawing = custom_sprite_test_drawing("2")
		drawing["emissive"] = custom_sprite_emissive_settings(list("4" = TRUE))
		var/list/package = custom_style_package(target, zone, custom_sprite_validate(drawing), zone ? null : custom_style_test_hair())
		var/text = custom_style_export_text(package)
		var/list/exported = json_decode(text)
		TEST_ASSERT(!(length(exported["drawing"]["dirs"]) != 4 || length(exported["drawing"]["emissive"]) != 4 || ("character1" in exported) || findtext(text, "data/")), "Exports must contain all four views and settings, without account or file data.")
		var/list/result = custom_style_parse(text)
		TEST_ASSERT(!(result["error"] || result["legacy"] || custom_style_package_hash(result["package"]) != custom_style_package_hash(package)), "A [target] export must import unchanged: [result["error"]]")
	var/list/empty = custom_style_parse(custom_style_export_text(custom_style_package("markings", BODY_ZONE_HEAD, null, null)))
	TEST_ASSERT(!(empty["error"] || !("drawing" in empty["package"]) || !isnull(empty["package"]["drawing"])), "Valid empty art must be an explicit null drawing.")
	var/list/legacy = custom_style_parse(json_encode(custom_sprite_test_drawing()))
	TEST_ASSERT(!(legacy["error"] || !legacy["legacy"] || !legacy["package"]["drawing"]), "A strictly valid legacy drawing-only file must be accepted.")

/datum/unit_test/custom_style_taur_transfer/Run()
	var/list/drawing = list("version" = 3, "palette" = list("#ffffff"), "tint" = null, "dirs" = list("2" = "f[repeat_string(2047, "0")]1"), "emissive" = custom_sprite_emissive_settings(FALSE))
	var/text = custom_style_export_text(custom_style_package("markings", "taur", drawing, null))
	var/list/result = custom_style_parse(text)
	TEST_ASSERT(!(result["error"] || result["package"]?["drawing"]?["version"] != 3), "Wide taur exports must round-trip: [result["error"]]")
	var/list/exported = json_decode(text)
	TEST_ASSERT(custom_sprite_decode_grid(exported["drawing"]["dirs"]["1"], 1, 2048) == repeat_string(2048, "0"), "Empty exported views must use the drawing's wide pixel count.")
	for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		TEST_ASSERT(custom_style_parse(custom_style_export_text(custom_style_package("markings", zone, drawing, null)))["error"], "Wide art must not import as an ordinary limb drawing.")
	TEST_ASSERT(custom_style_parse(custom_style_export_text(custom_style_package("hair", null, drawing, custom_style_test_hair())))["error"], "Wide art must not import as a hairstyle.")
	TEST_ASSERT(custom_style_parse(custom_style_test_export("markings", "taur"))["error"], "Nonempty taur-zone packages must require version 3.")
	TEST_ASSERT(custom_style_parse(custom_style_test_export("markings", null))["error"], "Markings without a body zone must be refused.")
	TEST_ASSERT(!custom_style_parse(custom_style_export_text(custom_style_package("markings", "taur", null, null)))["error"], "Explicit empty taur-zone art must remain valid.")
	var/list/envelope = json_decode(custom_style_export_text(custom_style_package("markings", "taur", drawing, null)))
	for(var/field in list("width", "height", "pixel_x", "pixel_y", "origin_x"))
		var/list/extra = deep_copy_list(envelope)
		extra["drawing"][field] = 64
		TEST_ASSERT(custom_style_parse(json_encode(extra))["error"], "Wide import must not allow custom dimensions or offsets.")
	var/list/bounds = list("2" = list(0, 0, 62, 31))
	TEST_ASSERT(custom_style_paint_outside(drawing, bounds, null) == "Front", "Import geometry checks must see paint in the last wide column.")
	bounds["2"] = list(0, 0, 63, 31)
	TEST_ASSERT(!custom_style_paint_outside(drawing, bounds, null), "Import geometry checks must accept allowed outer canvas paint.")
	var/list/palette = list()
	for(var/i in 1 to 63)
		palette += rgb(i, 0, 0)
	drawing["palette"] = palette
	for(var/direction in GLOB.custom_style_directions)
		drawing["dirs"][direction] = "f[repeat_string(1024, "1_")]"
	var/full_text = custom_style_export_text(custom_style_package("markings", "taur", drawing, null))
	TEST_ASSERT(!(length(full_text) > CUSTOM_STYLE_MAX_BYTES || custom_style_parse(full_text)["error"]), "All four worst-case wide views and 63 colors must fit the unchanged 16 KiB import cap.")
	drawing["palette"] += "#ffffff"
	TEST_ASSERT(custom_style_parse(custom_style_export_text(custom_style_package("markings", "taur", drawing, null)))["error"], "Version 3 must retain the 63-color import limit.")

/datum/unit_test/custom_style_legacy_emissives/Run()
	for(var/settings in list(FALSE, TRUE, list("2" = TRUE, "1" = FALSE, "4" = TRUE, "8" = FALSE)))
		var/list/drawing = custom_sprite_test_drawing()
		drawing["emissive"] = settings
		var/list/result = custom_style_parse(json_encode(drawing))
		TEST_ASSERT(!(result["error"] || json_encode(result["package"]?["drawing"]?["emissive"]) != json_encode(custom_sprite_emissive_settings(settings))), "Legacy persisted numeric flags must retain their directional emission: [result["error"]]")
	for(var/settings in list(2, -1, 0.5, "true", null, list("2" = 2), list("2" = "1")))
		var/list/drawing = custom_sprite_test_drawing()
		drawing["emissive"] = settings
		TEST_ASSERT(custom_style_parse(json_encode(drawing))["error"], "Legacy emission must reject values other than boolean or numeric 0/1 flags.")

/datum/unit_test/custom_style_import_canonical_drawing/Run()
	var/list/drawing = list(
		"version" = 2,
		"palette" = list("#ABCDEF"),
		"tint" = "#AaBbCc",
		"dirs" = list("2" = "f1[repeat_string(1023, "0")]", "1" = "f[repeat_string(1024, "0")]"),
	)
	var/list/result = custom_style_parse(json_encode(drawing))
	var/list/clean = result["package"]?["drawing"]
	TEST_ASSERT(!(result["error"] || !clean), "A valid flat legacy drawing must import: [result["error"]]")
	TEST_ASSERT(!(clean["version"] != 1 || clean["palette"][1] != "#abcdef" || clean["tint"] != "#aabbcc"), "Imports must canonicalize version and mixed-case colors.")
	TEST_ASSERT(!(length(clean["dirs"]) != 1 || clean["dirs"]["2"] != "r11[repeat_string(68, "f0")]30"), "Imports must omit empty views and canonicalize runs without changing pixel positions.")

/datum/unit_test/custom_style_parse_hostile/Run()
	var/valid = custom_style_test_export()
	var/list/cases = list(
		"trailing content" = "[valid] {}",
		"unterminated" = copytext(valid, 1, length(valid) - 2),
		"top-level array" = "\[[valid]]",
		"control character" = "{\"a\":\"x\ty\"}",
		"bad number" = "{\"version\":01}",
		"bad literal" = "{\"emissive\":fals}",
		"trailing comma" = "{\"a\":1,}",
		"deep nesting" = "{\"a\":" + repeat_string(200, "\[") + repeat_string(200, "]") + "}",
		"oversized" = "{\"a\":\"[repeat_string(CUSTOM_STYLE_MAX_BYTES, "a")]\"}",
		"empty" = "",
	)
	for(var/name in cases)
		TEST_ASSERT(custom_style_parse(cases[name])["error"], "The parser accepted hostile JSON: [name].")

/datum/unit_test/custom_style_parse_strict_fields/Run()
	var/list/base = json_decode(custom_style_test_export())
	var/list/baseline = custom_style_parse(json_encode(base))
	TEST_ASSERT(!baseline["error"], "The unchanged mutation fixture must be accepted: [baseline["error"]]")
	var/list/mutations = list(
		"wrong format" = list("format", "aphelion-custom-sprite", "custom style export"),
		"string version" = list("version", "1", "version"),
		"future version" = list("version", 2, "version"),
		"unknown target" = list("target", "tail", "target"),
		"unknown field" = list("slot", 1, "unsupported field"),
		"hair zone" = list("zone", BODY_ZONE_HEAD, "body zone"),
		"missing hair" = list("hair", null, "hair settings"),
	)
	for(var/name in mutations)
		var/list/envelope = deep_copy_list(base)
		var/list/change = mutations[name]
		envelope[change[1]] = change[2]
		var/error = custom_style_parse(json_encode(envelope))["error"]
		TEST_ASSERT(findtext(error, change[3]), "Import must reject [name] for the changed envelope field, got: [error]")
	var/list/drawing_mutations = list(
		"missing view" = list("dirs", list("2" = base["drawing"]["dirs"]["2"]), "Back view"),
		"invalid palette index" = list("dirs", list("2" = "r[repeat_string(68, "f9")]49", "1" = base["drawing"]["dirs"]["1"], "4" = base["drawing"]["dirs"]["4"], "8" = base["drawing"]["dirs"]["8"]), "Front view has invalid pixel"),
		"zero-length run" = list("dirs", list("2" = "r01[repeat_string(68, "f0")]30", "1" = base["drawing"]["dirs"]["1"], "4" = base["drawing"]["dirs"]["4"], "8" = base["drawing"]["dirs"]["8"]), "Front view has invalid pixel"),
		"overlong expansion" = list("dirs", list("2" = "r[repeat_string(70, "f1")]", "1" = base["drawing"]["dirs"]["1"], "4" = base["drawing"]["dirs"]["4"], "8" = base["drawing"]["dirs"]["8"]), "Front view has invalid pixel"),
		"repeated color" = list("palette", list("#ffffff", "#ffffff"), "palette"),
		"bad color" = list("palette", list("red"), "palette"),
		"bad tint" = list("tint", "#12345", "color filter"),
	)
	for(var/name in drawing_mutations)
		var/list/envelope = deep_copy_list(base)
		var/list/change = drawing_mutations[name]
		envelope["drawing"][change[1]] = change[2]
		var/error = custom_style_parse(json_encode(envelope))["error"]
		TEST_ASSERT(findtext(error, change[3]), "Import must reject [name] for the changed drawing field, got: [error]")
	var/list/too_many = list()
	for(var/i in 1 to CUSTOM_SPRITE_MAX_COLORS + 1)
		too_many += rgb(i, 1, 1)
	var/list/envelope = deep_copy_list(base)
	envelope["drawing"]["version"] = 2
	envelope["drawing"]["palette"] = too_many
	TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "Import must reject more than 63 colors.")
	envelope = deep_copy_list(base)
	for(var/direction in GLOB.custom_style_directions)
		envelope["drawing"]["dirs"][direction] = custom_sprite_encode_grid(repeat_string(1024, "0"), 1)
	TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "A non-null drawing with no paint must not be treated as Clear.")
	var/list/hair_mutations = list(
		"unknown style" = list("style", "Definitely Not A Hairstyle", "hairstyle"),
		"low opacity" = list("opacity", 30, "opacity"),
		"fractional opacity" = list("opacity", 100.5, "opacity"),
		"extra field" = list("facial_style", "Beard", "hair settings"),
	)
	for(var/name in hair_mutations)
		envelope = deep_copy_list(base)
		var/list/change = hair_mutations[name]
		envelope["hair"][change[1]] = change[2]
		var/error = custom_style_parse(json_encode(envelope))["error"]
		TEST_ASSERT(findtext(error, change[3]), "Import must reject [name] for the changed hair field, got: [error]")
	var/datum/sprite_accessory/hair/short = SSaccessories.hairstyles_list["Short Hair"]
	var/was_locked = short.locked
	short.locked = TRUE
	var/locked_error = custom_style_parse(json_encode(base))["error"]
	short.locked = FALSE
	var/unlocked_error = custom_style_parse(json_encode(base))["error"]
	short.locked = was_locked
	TEST_ASSERT(!(!findtext(locked_error, "hairstyle") || unlocked_error), "Only the locked fixture must fail hairstyle validation: locked=[locked_error], unlocked=[unlocked_error]")
	var/list/sidecar = list("character1" = list("hair" = custom_sprite_test_drawing()))
	TEST_ASSERT(findtext(custom_style_parse(json_encode(sidecar))["error"], "account drawing file"), "Account sidecars must be rejected with a clear reason.")
	var/list/legacy = custom_sprite_test_drawing()
	legacy["dirs"]["1"] = "r00"
	TEST_ASSERT(custom_style_parse(json_encode(legacy))["error"], "Legacy imports must reject a corrupt view instead of salvaging the rest.")

/// Two distinct native markings make order, independent field types and duplicate checks observable.
/proc/custom_style_test_markings(zone = BODY_ZONE_L_ARM)
	var/list/choices = GLOB.body_markings_per_limb[zone]
	return list(
		list("name" = choices[1], "color" = "#123456", "emissive" = FALSE),
		list("name" = choices[2], "color" = "#abcdef", "emissive" = TRUE),
	)

/datum/unit_test/custom_style_native_markings_transfer/Run()
	var/list/markings = custom_style_test_markings()
	var/list/package = custom_style_package("markings", BODY_ZONE_L_ARM, null, null, markings)
	var/list/copied = custom_style_copy_package(package)
	copied["markings"][1]["color"] = "#654321"
	TEST_ASSERT(!(package["markings"][1]["color"] != "#123456" || markings[1]["color"] != "#123456"), "Copied packages must own their nested marking records without aliasing the draft or source.")
	var/text = custom_style_export_text(package)
	var/list/result = custom_style_parse(text)
	TEST_ASSERT(!(result["error"] || custom_style_package_hash(result["package"]) != custom_style_package_hash(package)), "Native markings must export and import with their exact order, colors and boolean emission: [result["error"]]")
	var/list/clear = custom_style_package("markings", BODY_ZONE_L_ARM, null, null, list())
	result = custom_style_parse(custom_style_export_text(clear))
	TEST_ASSERT(!(result["error"] || !("markings" in result["package"]) || length(result["package"]["markings"])), "An empty marking array must survive import as explicit native Clear.")
	var/list/legacy = custom_style_package("markings", BODY_ZONE_L_ARM, null, null)
	var/legacy_hash = md5(json_encode(list(legacy["target"], legacy["zone"], custom_sprite_hash(legacy["drawing"]), legacy["hair"])))
	TEST_ASSERT(!(custom_style_package_hash(legacy) != legacy_hash || custom_style_package_hash(legacy) == custom_style_package_hash(clear)), "Absent native markings must retain old package hashes and remain distinct from Clear.")
	TEST_ASSERT(!(!custom_style_matches(legacy, package) || !custom_style_matches(legacy, clear) || custom_style_matches(clear, package) || custom_style_matches(package, clear) || ("markings" in legacy)), "Legacy comparisons must preserve current native markings without changing the source or treating explicit Clear as unchanged.")
	var/list/base = json_decode(custom_style_export_text(package))
	var/list/mutations = list(
		"unknown name" = list("name", "Not A Native Marking"),
		"named color" = list("color", "red"),
		"alpha color" = list("color", "#11223344"),
		"string boolean" = list("emissive", "false"),
		"null boolean" = list("emissive", null),
		"extra field" = list("icon", "injected.dmi"),
	)
	for(var/name in mutations)
		var/list/envelope = json_decode(json_encode(base))
		var/list/change = mutations[name]
		envelope["markings"][1][change[1]] = change[2]
		TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "Native import must reject [name] in an earlier array entry even when the later entry is valid.")
	for(var/field in GLOB.custom_style_marking_keys)
		var/list/envelope = json_decode(json_encode(base))
		envelope["markings"][1] -= field
		TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "Every native marking must carry its own required [field] field.")
	var/list/envelope = json_decode(json_encode(base))
	var/list/entry = envelope["markings"][1]
	envelope["markings"] = list(entry, entry.Copy())
	TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "Native markings must reject repeated preset names.")
	envelope["markings"] = list()
	for(var/index in 1 to MAXIMUM_MARKINGS_PER_LIMB + 1)
		envelope["markings"] += list(entry.Copy())
	TEST_ASSERT(findtext(custom_style_parse(json_encode(envelope))["error"], "limit"), "Native marking imports must enforce the per-limb limit before processing entries.")
	envelope["markings"] = list("entry" = entry)
	TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "Native markings must be an array rather than an object.")
	envelope = json_decode(json_encode(base))
	envelope["markings"] = null
	result = custom_style_parse(json_encode(envelope))
	TEST_ASSERT(!(result["error"] || ("markings" in result["package"])), "Null native markings must canonicalize to preservation rather than Clear.")
	for(var/zone in list(null, CUSTOM_MARKING_ZONE_TAUR))
		envelope = json_decode(json_encode(base))
		envelope["zone"] = zone
		TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "Whole-body and taur packages must not carry native limb presets.")
	envelope = json_decode(custom_style_test_export("hair", null, null))
	envelope["markings"] = list()
	TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "Hair packages must reject native markings, including an empty clear request.")
	var/wrong_limb
	for(var/marking in GLOB.body_markings)
		if(!(marking in GLOB.body_markings_per_limb[BODY_ZONE_L_ARM]))
			wrong_limb = marking
			break
	TEST_ASSERT(wrong_limb, "The wrong-limb fixture requires a marking unavailable on the left arm.")
	envelope = json_decode(json_encode(base))
	envelope["markings"][1]["name"] = wrong_limb
	TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "Native imports must enforce the selected limb's marking allowlist.")

/datum/unit_test/custom_style_geometry_and_limits/Run()
	var/list/drawing = custom_sprite_validate(custom_sprite_test_drawing())
	var/list/bounds = list("2" = list(0, 0, 31, 31), "1" = list(0, 0, 31, 31), "4" = list(0, 0, 31, 31), "8" = list(0, 0, 31, 31))
	TEST_ASSERT(!custom_style_paint_outside(drawing, bounds, null), "Paint inside the bounds must be accepted.")
	bounds["2"] = list(5, 5, 31, 31)
	TEST_ASSERT(custom_style_paint_outside(drawing, bounds, null) == "Front", "Paint outside the bounds must name the offending view.")
	var/list/mask = list("2" = list(), "1" = list(), "4" = list(), "8" = list())
	for(var/direction in mask)
		for(var/y in 1 to 32)
			mask[direction] += repeat_string(32, "0")
	TEST_ASSERT(custom_style_paint_outside(drawing, null, mask) == "Front", "Paint outside a limb silhouette must be rejected.")
	var/test_key = "customstyletransfer[REF(src)]"
	TEST_ASSERT(!(custom_style_transfer_begin(test_key, "import") || !custom_style_transfer_begin(test_key, "export")), "Only one transfer may run per account.")
	custom_style_transfer_end(test_key)
	TEST_ASSERT(custom_style_transfer_begin(test_key, "import"), "A finished or failed import must still consume its cooldown.")
	TEST_ASSERT(!custom_style_transfer_begin(test_key, "export"), "Import and export cooldowns are independent.")
	custom_style_transfer_end(test_key)
	GLOB.custom_style_transfers -= test_key

/datum/unit_test/custom_style_body_transfer/Run()
	// Exports always carry per-view emission, so the fixture does too for an exact round trip.
	var/list/drawing = custom_sprite_test_drawing()
	drawing["emissive"] = custom_sprite_emissive_settings(FALSE)
	var/list/regions = list(
		BODY_ZONE_L_ARM = custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_validate(drawing), null, list(list("name" = GLOB.body_markings_per_limb[BODY_ZONE_L_ARM][1], "color" = "#123456", "emissive" = FALSE))),
		BODY_ZONE_HEAD = custom_style_package("markings", BODY_ZONE_HEAD, null, null),
	)
	var/text = custom_style_body_export_text(regions)
	var/list/result = custom_style_parse(text)
	TEST_ASSERT(!(result["error"] || result["legacy"] || length(result["body"]) != 2), "A whole-body export must import: [result["error"]]")
	for(var/zone in regions)
		TEST_ASSERT(custom_style_package_hash(result["body"][zone]) == custom_style_package_hash(regions[zone]), "Each region must round-trip unchanged: [zone].")
	var/list/envelope = json_decode(text)
	envelope["regions"]["tail"] = envelope["regions"][BODY_ZONE_HEAD]
	TEST_ASSERT(findtext(custom_style_parse(json_encode(envelope))["error"], "unknown region"), "Unknown regions must be refused.")
	envelope = json_decode(text)
	envelope["regions"][BODY_ZONE_L_ARM]["drawing"]["palette"] = list("not a color")
	TEST_ASSERT(findtext(custom_style_parse(json_encode(envelope))["error"], "Left arm:"), "Region errors must name the region.")
	envelope = json_decode(text)
	envelope["regions"] = list()
	TEST_ASSERT(custom_style_parse(json_encode(envelope))["error"], "A whole-body file needs at least one region.")
	var/padding = repeat_string(CUSTOM_STYLE_MAX_BYTES, " ")
	var/list/single = json_decode(custom_style_export_text(regions[BODY_ZONE_L_ARM]))
	TEST_ASSERT(findtext(custom_style_parse("[json_encode(single)][padding]")["error"], "16 KiB"), "Single-region files keep their 16 KiB cap.")
	TEST_ASSERT(findtext(custom_style_parse(repeat_string(CUSTOM_STYLE_MAX_BODY_BYTES + 1, " "))["error"], "160 KiB"), "Every file keeps the 160 KiB cap.")
