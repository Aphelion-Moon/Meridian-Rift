/**
 * The bulge data the game resolves, against the reviewed manifest next to this file (bulge_manifest.txt): every
 * family's data (families.dm), the bytes of every template sheet (icons/templates), and every garment type that
 * carries a bulge value, with what it inherits: its family, whether its print carries onto the bulge, its suit rule
 * and its cloth layer (garment_families.dm), and what the renderer reads from the garment's own definition (its worn
 * sprite and state, digitigrade sprite, GAGS configs and colours, groin coverage and layer, the sprites it declares for
 * a species' body and their GAGS configs; a uniform's female body flags; a suit's toggled state, offsets, dimensions,
 * alpha and colour; an underclothes accessory's sprite, static colour, layer, GAGS colours, digitigrade state, groin
 * coverage and female body flags). A merge
 * that adds a subtype of a listed garment, re-sprites or re-points one, changes what it covers, an edit to the data or
 * a redrawn sheet changes a line, and fails here until someone has reviewed what it changes on screen (the module
 * readme says how).
 *
 * To accept a reviewed change, copy the manifest this test writes whenever the two differ, data/bulge_manifest.txt,
 * over code/modules/unit_tests/~nova/bulge_manifest.txt.
 */
#define BULGE_MANIFEST_REVIEWED "code/modules/unit_tests/~nova/bulge_manifest.txt"
#define BULGE_MANIFEST_CURRENT "data/bulge_manifest.txt"
#define BULGE_MANIFEST_SHEETS "modular_aphelion/modules/bulge/icons/templates/"

/datum/unit_test/bulge_manifest

/datum/unit_test/bulge_manifest/Run()
	var/list/current = list()
	for(var/line in manifest_lines())
		var/list/fields = splittext(line, " ")
		current["[fields[1]] [fields[2]]"] = line
	var/list/expected = list()
	var/file_text = file2text(BULGE_MANIFEST_REVIEWED) || ""
	for(var/line in splittext(file_text, regex(@"\r?\n")))
		if(!length(line) || copytext(line, 1, 2) == "#")
			continue
		var/list/fields = splittext(line, " ")
		expected["[fields[1]] [fields[2]]"] = line
	if(!length(expected))
		TEST_FAIL("[BULGE_MANIFEST_REVIEWED] is missing or empty.")
	var/list/changes = list()
	for(var/key, line in current)
		var/old = expected[key]
		if(isnull(old))
			changes += "new: [line]"
		else if(old != line)
			changes += "changed: [old]\n    now: [line]"
	for(var/key, line in expected)
		if(isnull(current[key]))
			changes += "gone: [line]"
	if(!length(changes))
		return
	var/list/written = list(
		"# The bulge data the game resolves, pinned for review by the bulge_manifest unit test: every family's data",
		"# (the base family's line lists every var, each other family's the ones it gives another value), every",
		"# template sheet's MD5, and every garment type that carries a bulge value, with what it inherits: its family",
		"# under /datum/bulge_family/, and its suit rule, print and cloth layer where they are not 0, 0 and 1; then what",
		"# the renderer reads from the garment's own definition (worn file:state, digi file, GAGS configs and colours,",
		"# groin coverage, worn layer, a suit's toggled state, offsets, dimensions, alpha and color, the species-fitted",
		"# sprites and GAGS configs it declares, a uniform's female body flags; an accessory's sprite, static colour,",
		"# layer, GAGS colours, digi state and female body flags).",
		"# Review a change on screen first (the module readme), then copy the data/bulge_manifest.txt the test writes over this file.",
	)
	for(var/key, line in current)
		written += line
	rustg_file_write(jointext(written, "\n") + "\n", BULGE_MANIFEST_CURRENT)
	var/shown = jointext(changes.Copy(1, min(length(changes), 40) + 1), "\n")
	TEST_FAIL("[length(changes)] line\s of the bulge data differ from the reviewed manifest:\n[shown]\n\
		Review what each changes on screen, then copy [BULGE_MANIFEST_CURRENT] over [BULGE_MANIFEST_REVIEWED].")

/**
 * The manifest's lines in order: families, sheets, garments. The base family's line lists every var a family has, and
 * each other family the vars it gives another value. A garment lists its family (by its name under
 * /datum/bulge_family/) and, where they are not the defaults, its suit rule, its print and its cloth layer.
 */
/datum/unit_test/bulge_manifest/proc/manifest_lines()
	. = list()
	var/datum/bulge_family/probe = allocate(/datum/bulge_family)
	var/datum/blank = allocate(/datum)
	var/list/names = list()
	for(var/name in probe.vars)
		if(!(name in blank.vars))
			names += name
	sortTim(names, GLOBAL_PROC_REF(cmp_text_asc))
	for(var/family_type in typesof(/datum/bulge_family))
		var/datum/bulge_family/family = allocate(family_type)
		var/list/values = list()
		for(var/name in names)
			var/value = family.vars[name]
			if(family_type == /datum/bulge_family || value != probe.vars[name])
				values += "[name]=[isnull(value) ? "null" : value]"
		. += "family [family_type][length(values) ? " [jointext(values, " ")]" : ""]"
	var/list/sheets = list()
	for(var/file_name in flist(BULGE_MANIFEST_SHEETS))
		if(copytext(file_name, -4) == ".dmi")
			sheets += "sheet [file_name] [rustg_hash_file(RUSTG_HASH_MD5, BULGE_MANIFEST_SHEETS + file_name)]"
	sortTim(sheets, GLOBAL_PROC_REF(cmp_text_asc))
	. += sheets
	var/list/items = list()
	for(var/obj/item/clothing/garment as anything in typesof(/obj/item/clothing))
		var/list/values = list()
		var/rule = initial(garment.bulge_suit_rule)
		if(rule)
			values += "suit_rule=[rule]"
		if(ispath(garment, /obj/item/clothing/under))
			var/obj/item/clothing/under/uniform = garment
			var/printed = initial(uniform.bulge_printed)
			if(printed)
				values += "printed=[printed]"
			var/layer = initial(uniform.bulge_cloth_layer)
			if(layer != 1)
				values += "cloth_layer=[layer]"
		var/family = initial(garment.bulge_family)
		if(family != /datum/bulge_family/none || length(values))
			items += "garment [garment] [manifest_family(family)][length(values) ? " [jointext(values, " ")]" : ""] [manifest_worn(garment)]"
	for(var/datum/sprite_accessory/clothing/accessory as anything in typesof(/datum/sprite_accessory/clothing))
		var/family = initial(accessory.bulge_family)
		var/printed = initial(accessory.bulge_printed)
		if(family != /datum/bulge_family/none || printed)
			items += "garment [accessory] [manifest_family(family)][printed ? " printed=[printed]" : ""] [manifest_accessory(accessory)]"
	sortTim(items, GLOBAL_PROC_REF(cmp_text_asc))
	. += items

/**
 * What the renderer reads from a garment type's own definition, as the manifest writes it: its worn sprite and state
 * (worn=FILE:STATE, "default" for the slot's default file; for a GAGS garment the state it takes once made, not its
 * map preview's), its digitigrade sprite when it has one (digi=), its GAGS worn configs and colours, whether it covers
 * the groin (groin=), the layer it is worn at when not its slot's own (layer=); for a suit with a rule, its toggled
 * state (toggled=), worn offsets (offset=), worn dimensions (dimension=), alpha and colour (color=), which decide
 * whether it may show a bulge (bulge_suit_verdict()); the sprites it declares for a species' body (Teshari, Vox,
 * Vox Primalis), as files or as GAGS configs (teshari=, vox=, better_vox=, gags_teshari=, gags_vox=, gags_better_vox=);
 * and for a uniform how it is drawn on a female body (female=, its female_sprite_flags).
 */
/datum/unit_test/bulge_manifest/proc/manifest_worn(obj/item/clothing/garment)
	var/list/values = list()
	var/state = initial(garment.worn_icon_state) || initial(garment.post_init_icon_state) || initial(garment.icon_state)
	values += "worn=[initial(garment.worn_icon) || "default"]:[state]"
	if(initial(garment.supports_variations_flags) & CLOTHING_DIGITIGRADE_VARIATION)
		values += "digi=[initial(garment.worn_icon_digi) || "default"]"
	if(initial(garment.greyscale_config_worn))
		values += "gags=[initial(garment.greyscale_config_worn)]"
	if(initial(garment.greyscale_config_worn_digi))
		values += "gags_digi=[initial(garment.greyscale_config_worn_digi)]"
	if(initial(garment.greyscale_colors))
		values += "colours=[initial(garment.greyscale_colors)]"
	values += "groin=[(initial(garment.body_parts_covered) & GROIN) ? 1 : 0]"
	if(initial(garment.alternate_worn_layer))
		values += "layer=[initial(garment.alternate_worn_layer)]"
	if(initial(garment.bulge_suit_rule))
		values += "toggled=[initial(garment.base_icon_state) || initial(garment.post_init_icon_state) || initial(garment.icon_state)]_t"
		values += "offset=[initial(garment.worn_x_offset)],[initial(garment.worn_y_offset)]"
		values += "dimension=[initial(garment.worn_x_dimension)],[initial(garment.worn_y_dimension)]"
		values += "alpha=[initial(garment.alpha)]"
		values += "color=[initial(garment.color) || "null"]"
	if(initial(garment.worn_icon_teshari))
		values += "teshari=[initial(garment.worn_icon_teshari)]"
	if(initial(garment.worn_icon_vox))
		values += "vox=[initial(garment.worn_icon_vox)]"
	if(initial(garment.worn_icon_better_vox))
		values += "better_vox=[initial(garment.worn_icon_better_vox)]"
	if(initial(garment.greyscale_config_worn_teshari))
		values += "gags_teshari=[initial(garment.greyscale_config_worn_teshari)]"
	if(initial(garment.greyscale_config_worn_vox))
		values += "gags_vox=[initial(garment.greyscale_config_worn_vox)]"
	if(initial(garment.greyscale_config_worn_better_vox))
		values += "gags_better_vox=[initial(garment.greyscale_config_worn_better_vox)]"
	if(ispath(garment, /obj/item/clothing/under))
		var/obj/item/clothing/under/uniform = garment
		values += "female=[initial(uniform.female_sprite_flags)]"
	return jointext(values, " ")

/// What the renderer reads from an underclothes accessory's own definition: its sprite and state, whether its colour is
/// static, its layer, its GAGS config, its own digitigrade sprite, for an undershirt whether it covers the groin, its
/// GAGS colours (colours=, also the colours its digitigrade legs are drawn in), its digitigrade state (digi_state=) and
/// how it is drawn on a female body (female=, its female_sprite_flags).
/datum/unit_test/bulge_manifest/proc/manifest_accessory(datum/sprite_accessory/clothing/accessory)
	var/list/values = list("icon=[initial(accessory.icon)]:[initial(accessory.icon_state)]", "static=[initial(accessory.use_static) ? 1 : 0]", "layer=[initial(accessory.layer)]")
	if(initial(accessory.greyscale_config))
		values += "gags=[initial(accessory.greyscale_config)]"
	if(initial(accessory.has_custom_digi_sprite))
		values += "digi=1"
	if(ispath(accessory, /datum/sprite_accessory/clothing/undershirt))
		var/datum/sprite_accessory/clothing/undershirt/shirt = accessory
		values += "groin=[initial(shirt.hides_groin) ? 1 : 0]"
	if(initial(accessory.greyscale_colors))
		values += "colours=[initial(accessory.greyscale_colors)]"
	if(initial(accessory.digi_icon_state))
		values += "digi_state=[initial(accessory.digi_icon_state)]"
	values += "female=[initial(accessory.female_sprite_flags)]"
	return jointext(values, " ")

/// A garment's family as the manifest writes it: "family=" and its name under /datum/bulge_family/ ("jumpsuits",
/// "skirt/short_reveal/hem_24"), or its whole typepath when it is not under it.
/datum/unit_test/bulge_manifest/proc/manifest_family(family)
	var/text = "[family]"
	return findtext(text, "/datum/bulge_family/") == 1 ? "family=[copytext(text, 21)]" : "family=[text]"

#undef BULGE_MANIFEST_REVIEWED
#undef BULGE_MANIFEST_CURRENT
#undef BULGE_MANIFEST_SHEETS
