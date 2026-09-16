#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/proc/custom_style_test_hair(style = "Short Hair")
	return list("style" = style, "color" = "#583820", "gradient_style" = "None", "gradient_color" = "#000000", "opacity" = null, "emissive" = FALSE)

/proc/custom_style_test_export(target = "hair", zone = null, list/drawing = custom_sprite_test_drawing())
	return custom_style_export_text(custom_style_package(target, zone, custom_sprite_validate(drawing), target == "hair" ? custom_style_test_hair() : null))

/// Encode mutated fixtures without normalizing fields or converting their boolean markers to numbers.
/proc/custom_style_test_json(list/envelope)
	return replacetext(replacetext(json_encode(envelope), "\"[CUSTOM_STYLE_JSON_TRUE]\"", "true"), "\"[CUSTOM_STYLE_JSON_FALSE]\"", "false")

/datum/unit_test/custom_style_transfer_round_trip/Run()
	for(var/zone in list(null, BODY_ZONE_L_ARM))
		var/target = zone ? "markings" : "hair"
		var/list/drawing = custom_sprite_test_drawing("2")
		drawing["emissive"] = custom_sprite_emissive_settings(list("4" = TRUE))
		var/list/package = custom_style_package(target, zone, custom_sprite_validate(drawing), zone ? null : custom_style_test_hair())
		var/text = custom_style_export_text(package)
		var/list/exported = json_decode(text)
		if(length(exported["drawing"]["dirs"]) != 4 || length(exported["drawing"]["emissive"]) != 4 || ("character1" in exported) || findtext(text, "data/"))
			Fail("Exports must contain all four views and settings, without account or file data.", __FILE__, __LINE__)
		var/list/result = custom_style_parse(text)
		if(result["error"] || result["legacy"] || custom_style_package_hash(result["package"]) != custom_style_package_hash(package))
			Fail("A [target] export must import unchanged: [result["error"]]", __FILE__, __LINE__)
	var/list/empty = custom_style_parse(custom_style_export_text(custom_style_package("markings", BODY_ZONE_HEAD, null, null)))
	if(empty["error"] || !("drawing" in empty["package"]) || !isnull(empty["package"]["drawing"]))
		Fail("Valid empty art must be an explicit null drawing.", __FILE__, __LINE__)
	var/list/legacy = custom_style_parse(json_encode(custom_sprite_test_drawing()))
	if(legacy["error"] || !legacy["legacy"] || !legacy["package"]["drawing"])
		Fail("A strictly valid legacy drawing-only file must be accepted.", __FILE__, __LINE__)

/datum/unit_test/custom_style_taur_transfer/Run()
	var/list/drawing = list("version" = 3, "palette" = list("#ffffff"), "tint" = null, "dirs" = list("2" = "f[repeat_string(2047, "0")]1"), "emissive" = custom_sprite_emissive_settings(FALSE))
	for(var/zone in list(null, "taur"))
		var/list/package = custom_style_package("markings", zone, drawing, null)
		var/text = custom_style_export_text(package)
		var/list/result = custom_style_parse(text)
		if(result["error"] || result["package"]?["drawing"]?["version"] != 3)
			Fail("Wide whole-body and taur exports must round-trip: [result["error"]]", __FILE__, __LINE__)
		var/list/exported = json_decode(text)
		if(custom_sprite_decode_grid(exported["drawing"]["dirs"]["1"], 1, 2048) != repeat_string(2048, "0"))
			Fail("Empty exported views must use the drawing's wide pixel count.", __FILE__, __LINE__)
	for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		if(!custom_style_parse(custom_style_export_text(custom_style_package("markings", zone, drawing, null)))["error"])
			Fail("Wide art must not import as an ordinary limb drawing.", __FILE__, __LINE__)
	if(!custom_style_parse(custom_style_export_text(custom_style_package("hair", null, drawing, custom_style_test_hair())))["error"])
		Fail("Wide art must not import as a hairstyle.", __FILE__, __LINE__)
	if(!custom_style_parse(custom_style_test_export("markings", "taur"))["error"])
		Fail("Nonempty taur-zone packages must require version 3.", __FILE__, __LINE__)
	if(custom_style_parse(custom_style_test_export("markings", null))["error"] || custom_style_parse(custom_style_export_text(custom_style_package("markings", "taur", null, null)))["error"])
		Fail("Legacy whole-body art and explicit empty taur-zone art must remain valid.", __FILE__, __LINE__)
	var/list/envelope = json_decode(custom_style_export_text(custom_style_package("markings", null, drawing, null)))
	for(var/direction in envelope["drawing"]["emissive"])
		envelope["drawing"]["emissive"][direction] = CUSTOM_STYLE_JSON_FALSE
	for(var/field in list("width", "height", "pixel_x", "pixel_y", "origin_x"))
		var/list/extra = deep_copy_list(envelope)
		extra["drawing"][field] = 64
		if(!custom_style_parse(custom_style_test_json(extra))["error"])
			Fail("Wide import must not allow custom dimensions or offsets.", __FILE__, __LINE__)
	var/list/bounds = list("2" = list(0, 0, 62, 31))
	if(custom_style_paint_outside(drawing, bounds, null) != "Front")
		Fail("Import geometry checks must see paint in the last wide column.", __FILE__, __LINE__)
	bounds["2"] = list(0, 0, 63, 31)
	if(custom_style_paint_outside(drawing, bounds, null))
		Fail("Import geometry checks must accept allowed outer canvas paint.", __FILE__, __LINE__)
	var/list/palette = list()
	for(var/i in 1 to 63)
		palette += rgb(i, 0, 0)
	drawing["palette"] = palette
	for(var/direction in GLOB.custom_style_directions)
		drawing["dirs"][direction] = "f[repeat_string(1024, "1_")]"
	var/full_text = custom_style_export_text(custom_style_package("markings", "taur", drawing, null))
	if(length(full_text) > CUSTOM_STYLE_MAX_BYTES || custom_style_parse(full_text)["error"])
		Fail("All four worst-case wide views and 63 colors must fit the unchanged 16 KiB import cap.", __FILE__, __LINE__)
	drawing["palette"] += "#ffffff"
	if(!custom_style_parse(custom_style_export_text(custom_style_package("markings", "taur", drawing, null)))["error"])
		Fail("Version 3 must retain the 63-color import limit.", __FILE__, __LINE__)

/datum/unit_test/custom_style_legacy_emissives/Run()
	for(var/settings in list(FALSE, TRUE, list("2" = TRUE, "1" = FALSE, "4" = TRUE, "8" = FALSE)))
		var/list/drawing = custom_sprite_test_drawing()
		drawing["emissive"] = settings
		var/list/result = custom_style_parse(json_encode(drawing))
		if(result["error"] || json_encode(result["package"]?["drawing"]?["emissive"]) != json_encode(custom_sprite_emissive_settings(settings)))
			Fail("Legacy persisted numeric flags must retain their directional emission: [result["error"]]", __FILE__, __LINE__)
	for(var/settings in list(2, -1, 0.5, "true", null, list("2" = 2), list("2" = "1")))
		var/list/drawing = custom_sprite_test_drawing()
		drawing["emissive"] = settings
		if(!custom_style_parse(json_encode(drawing))["error"])
			Fail("Legacy emission must reject values other than boolean or numeric 0/1 flags.", __FILE__, __LINE__)

/datum/unit_test/custom_style_import_canonical_drawing/Run()
	var/list/drawing = list(
		"version" = 2,
		"palette" = list("#ABCDEF"),
		"tint" = "#AaBbCc",
		"dirs" = list("2" = "f1[repeat_string(1023, "0")]", "1" = "f[repeat_string(1024, "0")]"),
	)
	var/list/result = custom_style_parse(json_encode(drawing))
	var/list/clean = result["package"]?["drawing"]
	if(result["error"] || !clean)
		Fail("A valid flat legacy drawing must import: [result["error"]]", __FILE__, __LINE__)
		return
	if(clean["version"] != 1 || clean["palette"][1] != "#abcdef" || clean["tint"] != "#aabbcc")
		Fail("Imports must canonicalize version and mixed-case colors.", __FILE__, __LINE__)
	if(length(clean["dirs"]) != 1 || clean["dirs"]["2"] != "r11[repeat_string(68, "f0")]30")
		Fail("Imports must omit empty views and canonicalize runs without changing pixel positions.", __FILE__, __LINE__)

/datum/unit_test/custom_style_preflight_hostile/Run()
	var/valid = custom_style_test_export()
	var/list/cases = list(
		"trailing content" = "[valid] {}",
		"unterminated" = copytext(valid, 1, length(valid) - 2),
		"top-level array" = "\[[valid]]",
		"duplicate key" = "{\"version\":1,\"version\":1}",
		"escaped key" = "{\"t\\u0061rget\":1}",
		"control character" = "{\"a\":\"x\ty\"}",
		"non-ASCII" = "{\"a\":\"aphélion\"}",
		"bad number" = "{\"version\":01}",
		"leading plus" = "{\"version\":+1}",
		"bad literal" = "{\"emissive\":fals}",
		"bad escape" = "{\"format\":\"a\\q\"}",
		"missing comma" = "{\"a\":1 \"b\":2}",
		"trailing comma" = "{\"a\":1,}",
		"deep nesting" = "{\"a\":" + repeat_string(8, "\[") + repeat_string(8, "]") + "}",
		"too many tokens" = "{\"a\":\[[repeat_string(600, "1,")]1]}",
		"oversized" = "{\"a\":\"[repeat_string(CUSTOM_STYLE_MAX_BYTES, "a")]\"}",
		"empty" = "",
	)
	for(var/name in cases)
		var/list/result = custom_style_preflight(cases[name])
		if(!result["error"])
			Fail("Preflight accepted hostile JSON: [name].", __FILE__, __LINE__)
	var/list/depth_ok = custom_style_preflight("{\"a\":" + repeat_string(7, "\[") + repeat_string(7, "]") + "}")
	if(depth_ok["error"])
		Fail("Preflight must allow the documented nesting depth of 8.", __FILE__, __LINE__)
	var/list/types = custom_style_preflight(valid)["types"]
	if(types["drawing.emissive.2"] != "false" || types["drawing.palette\[]"] != "string" || types["hair.opacity"] != "null")
		Fail("Preflight must record JSON types by path for strict validation.", __FILE__, __LINE__)

/datum/unit_test/custom_style_parse_strict_fields/Run()
	var/list/base = json_decode(custom_style_test_export())
	for(var/direction in base["drawing"]["emissive"])
		base["drawing"]["emissive"][direction] = CUSTOM_STYLE_JSON_FALSE
	base["hair"]["emissive"] = CUSTOM_STYLE_JSON_FALSE
	var/list/baseline = custom_style_parse(custom_style_test_json(base))
	if(baseline["error"])
		Fail("The unchanged mutation fixture must be accepted: [baseline["error"]]", __FILE__, __LINE__)
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
		var/error = custom_style_parse(custom_style_test_json(envelope))["error"]
		if(!findtext(error, change[3]))
			Fail("Import must reject [name] for the changed envelope field, got: [error]", __FILE__, __LINE__)
	var/list/drawing_mutations = list(
		"numeric emissive" = list("emissive", list("2" = 1, "1" = 0, "4" = 0, "8" = 0), "emissive"),
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
		var/error = custom_style_parse(custom_style_test_json(envelope))["error"]
		if(!findtext(error, change[3]))
			Fail("Import must reject [name] for the changed drawing field, got: [error]", __FILE__, __LINE__)
	var/list/too_many = list()
	for(var/i in 1 to CUSTOM_SPRITE_MAX_COLORS + 1)
		too_many += rgb(i, 1, 1)
	var/list/envelope = deep_copy_list(base)
	envelope["drawing"]["version"] = 2
	envelope["drawing"]["palette"] = too_many
	if(!custom_style_parse(custom_style_test_json(envelope))["error"])
		Fail("Import must reject more than 63 colors.", __FILE__, __LINE__)
	envelope = deep_copy_list(base)
	for(var/direction in GLOB.custom_style_directions)
		envelope["drawing"]["dirs"][direction] = custom_sprite_encode_grid(repeat_string(1024, "0"), 1)
	if(!custom_style_parse(custom_style_test_json(envelope))["error"])
		Fail("A non-null drawing with no paint must not be treated as Clear.", __FILE__, __LINE__)
	var/list/hair_mutations = list(
		"unknown style" = list("style", "Definitely Not A Hairstyle", "hairstyle"),
		"low opacity" = list("opacity", 30, "opacity"),
		"fractional opacity" = list("opacity", 100.5, "opacity"),
		"numeric emissive" = list("emissive", 1, "hair emissive"),
		"extra field" = list("facial_style", "Beard", "hair settings"),
	)
	for(var/name in hair_mutations)
		envelope = deep_copy_list(base)
		var/list/change = hair_mutations[name]
		envelope["hair"][change[1]] = change[2]
		var/error = custom_style_parse(custom_style_test_json(envelope))["error"]
		if(!findtext(error, change[3]))
			Fail("Import must reject [name] for the changed hair field, got: [error]", __FILE__, __LINE__)
	var/datum/sprite_accessory/hair/short = SSaccessories.hairstyles_list["Short Hair"]
	var/was_locked = short.locked
	short.locked = TRUE
	var/locked_error = custom_style_parse(custom_style_test_json(base))["error"]
	short.locked = FALSE
	var/unlocked_error = custom_style_parse(custom_style_test_json(base))["error"]
	short.locked = was_locked
	if(!findtext(locked_error, "hairstyle") || unlocked_error)
		Fail("Only the locked fixture must fail hairstyle validation: locked=[locked_error], unlocked=[unlocked_error]", __FILE__, __LINE__)
	var/list/sidecar = list("character1" = list("hair" = custom_sprite_test_drawing()))
	if(!findtext(custom_style_parse(json_encode(sidecar))["error"], "account drawing file"))
		Fail("Account sidecars must be rejected with a clear reason.", __FILE__, __LINE__)
	var/list/legacy = custom_sprite_test_drawing()
	legacy["dirs"]["1"] = "r00"
	if(!custom_style_parse(json_encode(legacy))["error"])
		Fail("Legacy imports must reject a corrupt view instead of salvaging the rest.", __FILE__, __LINE__)

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
	if(package["markings"][1]["color"] != "#123456" || markings[1]["color"] != "#123456")
		Fail("Copied packages must own their nested marking records without aliasing the draft or source.", __FILE__, __LINE__)
	var/text = custom_style_export_text(package)
	var/list/result = custom_style_parse(text)
	if(result["error"] || custom_style_package_hash(result["package"]) != custom_style_package_hash(package))
		return Fail("Native markings must export and import with their exact order, colors and boolean emission: [result["error"]]", __FILE__, __LINE__)
	var/list/types = custom_style_preflight(text)["types"]
	if(types["markings\[1].emissive"] != "false" || types["markings\[2].emissive"] != "true")
		Fail("Preflight must retain separate field types for each native marking record.", __FILE__, __LINE__)
	var/list/clear = custom_style_package("markings", BODY_ZONE_L_ARM, null, null, list())
	result = custom_style_parse(custom_style_export_text(clear))
	if(result["error"] || !("markings" in result["package"]) || length(result["package"]["markings"]))
		Fail("An empty marking array must survive import as explicit native Clear.", __FILE__, __LINE__)
	var/list/legacy = custom_style_package("markings", BODY_ZONE_L_ARM, null, null)
	var/legacy_hash = md5(json_encode(list(legacy["target"], legacy["zone"], custom_sprite_hash(legacy["drawing"]), legacy["hair"])))
	if(custom_style_package_hash(legacy) != legacy_hash || custom_style_package_hash(legacy) == custom_style_package_hash(clear))
		Fail("Absent native markings must retain old package hashes and remain distinct from Clear.", __FILE__, __LINE__)
	if(!custom_style_matches(legacy, package) || !custom_style_matches(legacy, clear) || custom_style_matches(clear, package) || custom_style_matches(package, clear) || ("markings" in legacy))
		Fail("Legacy comparisons must preserve current native markings without changing the source or treating explicit Clear as unchanged.", __FILE__, __LINE__)
	var/list/base = json_decode(custom_style_export_text(package))
	base["markings"][1]["emissive"] = CUSTOM_STYLE_JSON_FALSE
	base["markings"][2]["emissive"] = CUSTOM_STYLE_JSON_TRUE
	var/list/mutations = list(
		"unknown name" = list("name", "Not A Native Marking"),
		"named color" = list("color", "red"),
		"alpha color" = list("color", "#11223344"),
		"numeric boolean" = list("emissive", 0),
		"string boolean" = list("emissive", "false"),
		"null boolean" = list("emissive", null),
		"extra field" = list("icon", "injected.dmi"),
	)
	for(var/name in mutations)
		var/list/envelope = json_decode(json_encode(base))
		var/list/change = mutations[name]
		envelope["markings"][1][change[1]] = change[2]
		if(!custom_style_parse(custom_style_test_json(envelope))["error"])
			Fail("Native import must reject [name] in an earlier array entry even when the later entry is valid.", __FILE__, __LINE__)
	for(var/field in GLOB.custom_style_marking_keys)
		var/list/envelope = json_decode(json_encode(base))
		envelope["markings"][1] -= field
		if(!custom_style_parse(custom_style_test_json(envelope))["error"])
			Fail("Every native marking must carry its own required [field] field.", __FILE__, __LINE__)
	var/list/envelope = json_decode(json_encode(base))
	var/list/entry = envelope["markings"][1]
	envelope["markings"] = list(entry, entry.Copy())
	if(!custom_style_parse(custom_style_test_json(envelope))["error"])
		Fail("Native markings must reject repeated preset names.", __FILE__, __LINE__)
	envelope["markings"] = list()
	for(var/index in 1 to MAXIMUM_MARKINGS_PER_LIMB + 1)
		envelope["markings"] += list(entry.Copy())
	if(!findtext(custom_style_parse(custom_style_test_json(envelope))["error"], "limit"))
		Fail("Native marking imports must enforce the per-limb limit before processing entries.", __FILE__, __LINE__)
	envelope["markings"] = list("entry" = entry)
	if(!custom_style_parse(custom_style_test_json(envelope))["error"])
		Fail("Native markings must be an array rather than an object.", __FILE__, __LINE__)
	envelope = json_decode(json_encode(base))
	envelope["markings"] = null
	result = custom_style_parse(custom_style_test_json(envelope))
	if(result["error"] || ("markings" in result["package"]))
		Fail("Null native markings must canonicalize to preservation rather than Clear.", __FILE__, __LINE__)
	for(var/zone in list(null, CUSTOM_MARKING_ZONE_TAUR))
		envelope = json_decode(json_encode(base))
		envelope["zone"] = zone
		if(!custom_style_parse(custom_style_test_json(envelope))["error"])
			Fail("Whole-body and taur packages must not carry native limb presets.", __FILE__, __LINE__)
	envelope = json_decode(custom_style_test_export("hair", null, null))
	envelope["hair"]["emissive"] = CUSTOM_STYLE_JSON_FALSE
	envelope["markings"] = list()
	if(!custom_style_parse(custom_style_test_json(envelope))["error"])
		Fail("Hair packages must reject native markings, including an empty clear request.", __FILE__, __LINE__)
	var/wrong_limb
	for(var/marking in GLOB.body_markings)
		if(!(marking in GLOB.body_markings_per_limb[BODY_ZONE_L_ARM]))
			wrong_limb = marking
			break
	if(!wrong_limb)
		return Fail("The wrong-limb fixture requires a marking unavailable on the left arm.", __FILE__, __LINE__)
	envelope = json_decode(json_encode(base))
	envelope["markings"][1]["name"] = wrong_limb
	if(!custom_style_parse(custom_style_test_json(envelope))["error"])
		Fail("Native imports must enforce the selected limb's marking allowlist.", __FILE__, __LINE__)

/datum/unit_test/custom_style_geometry_and_limits/Run()
	var/list/drawing = custom_sprite_validate(custom_sprite_test_drawing())
	var/list/bounds = list("2" = list(0, 0, 31, 31), "1" = list(0, 0, 31, 31), "4" = list(0, 0, 31, 31), "8" = list(0, 0, 31, 31))
	if(custom_style_paint_outside(drawing, bounds, null))
		Fail("Paint inside the bounds must be accepted.", __FILE__, __LINE__)
	bounds["2"] = list(5, 5, 31, 31)
	if(custom_style_paint_outside(drawing, bounds, null) != "Front")
		Fail("Paint outside the bounds must name the offending view.", __FILE__, __LINE__)
	var/list/mask = list("2" = list(), "1" = list(), "4" = list(), "8" = list())
	for(var/direction in mask)
		for(var/y in 1 to 32)
			mask[direction] += repeat_string(32, "0")
	if(custom_style_paint_outside(drawing, null, mask) != "Front")
		Fail("Paint outside a limb silhouette must be rejected.", __FILE__, __LINE__)
	var/test_key = "customstyletransfer[REF(src)]"
	if(custom_style_transfer_begin(test_key, "import") || !custom_style_transfer_begin(test_key, "export"))
		Fail("Only one transfer may run per account.", __FILE__, __LINE__)
	custom_style_transfer_end(test_key)
	if(!custom_style_transfer_begin(test_key, "import"))
		Fail("A finished or failed import must still consume its cooldown.", __FILE__, __LINE__)
	if(custom_style_transfer_begin(test_key, "export"))
		Fail("Import and export cooldowns are independent.", __FILE__, __LINE__)
	custom_style_transfer_end(test_key)
	GLOB.custom_style_transfers -= test_key

#endif
