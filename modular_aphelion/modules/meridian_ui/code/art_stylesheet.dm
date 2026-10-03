/**
 * Art too big for tgui's bundle, which every window loads and the lobby inlines: textures and fonts sent as asset files,
 * with a stylesheet written when the asset registers that names them by the URLs the asset transport gives them. Each
 * texture becomes a custom property on `scope`, `property_prefix` and its file's name without the extension, and each
 * font a face. A page loads the stylesheet as soon as it hears of it (loadMappings).
 *
 * The URLs are written in because Chrome resolves a relative url() in a custom property against the stylesheet that
 * uses it, not the one that declares it.
 */
/datum/asset/simple/art_stylesheet
	abstract_type = /datum/asset/simple/art_stylesheet
	/// What the files' asset names start with.
	var/name_prefix = ""
	/// The selector the stylesheet declares the textures on.
	var/scope
	/// What the textures' custom properties start with.
	var/property_prefix
	/// The stylesheet's asset name.
	var/stylesheet
	/// The textures, by file name.
	var/list/textures
	/// The fonts, by file name: list(family, weight, file).
	var/list/fonts
	/// Files another art asset also sends, by file name: the asset name it gives them, which they keep here, so a client
	/// fetches and keeps each such file once.
	var/list/shared_names

/datum/asset/simple/art_stylesheet/register()
	for(var/file_name, texture in textures)
		assets[asset_name(file_name)] = texture
	for(var/file_name in fonts)
		var/list/face = fonts[file_name]
		assets[asset_name(file_name)] = face[3]
	..()
	var/list/properties = list()
	for(var/file_name in textures)
		properties += "[property_prefix][copytext(file_name, 1, findlasttext(file_name, "."))]:url('[asset_url(asset_name(file_name))]')"
	var/list/css = list("[scope]{[jointext(properties, ";")]}")
	for(var/file_name in fonts)
		var/list/face = fonts[file_name]
		css += "@font-face{font-family:'[face[1]]';font-weight:[face[2]];font-display:block;src:url('[asset_url(asset_name(file_name))]')}"
	var/filename = "data/[stylesheet]"
	fdel(filename)
	rustg_file_write(jointext(css, "\n"), filename)
	assets[stylesheet] = SSassets.transport.register_asset(stylesheet, fcopy_rsc(filename))
	fdel(filename)

/// The asset name one of the asset's files goes by.
/datum/asset/simple/art_stylesheet/proc/asset_name(file_name)
	return shared_names?[file_name] || "[name_prefix][file_name]"

/// The URL the asset transport gives one of the asset's files, by its asset name.
/datum/asset/simple/art_stylesheet/proc/asset_url(key)
	return SSassets.transport.get_asset_url(key, assets[key])

/**
 * Foundry's art, for every Foundry window and the lobby (`--mt-<file name>` on the theme): the forge markings room's
 * cave, steel, wear and hide, its torches, its title and label faces, and the theme's own smoke (a portrait's arrival)
 * and running text face.
 */
/datum/asset/simple/art_stylesheet/meridian_foundry
	name_prefix = "meridian_foundry."
	scope = ".theme-meridian_foundry"
	property_prefix = "--mt-"
	stylesheet = "meridian_foundry.css"
	textures = list(
		"foundry-cave.jpg" = 'modular_aphelion/modules/markings_room/assets/textures/foundry-cave.jpg',
		"foundry-steel.webp" = 'modular_aphelion/modules/markings_room/assets/textures/foundry-steel.webp',
		"forge-wear.webp" = 'modular_aphelion/modules/markings_room/assets/textures/forge-wear.webp',
		"foundry-hide.jpg" = 'modular_aphelion/modules/markings_room/assets/textures/foundry-hide.jpg',
		"px-torch-a.png" = 'tgui/packages/tgui/styles/meridianos/assets/markings/px-torch-a.png',
		"px-torch-b.png" = 'tgui/packages/tgui/styles/meridianos/assets/markings/px-torch-b.png',
		"foundry-smoke.webp" = 'modular_aphelion/modules/meridian_ui/assets/textures/foundry-smoke.webp',
	)
	fonts = list(
		"CaesarDressing-400.woff2" = list("Caesar Dressing", 400, 'modular_aphelion/modules/markings_room/assets/fonts/CaesarDressing-400.woff2'),
		"Macondo-400.woff2" = list("Macondo", 400, 'modular_aphelion/modules/markings_room/assets/fonts/Macondo-400.woff2'),
		"AlegreyaSans-400.woff2" = list("Alegreya Sans", 400, 'modular_aphelion/modules/meridian_ui/assets/fonts/AlegreyaSans-400.woff2'),
		"AlegreyaSans-700.woff2" = list("Alegreya Sans", 700, 'modular_aphelion/modules/meridian_ui/assets/fonts/AlegreyaSans-700.woff2'),
	)
	// The room's own files, under the names the room's asset (markings_room.dm) sends them by.
	shared_names = list(
		"foundry-cave.jpg" = "markings_room.foundry-cave.jpg",
		"foundry-steel.webp" = "markings_room.foundry-steel.webp",
		"forge-wear.webp" = "markings_room.forge-wear.webp",
		"foundry-hide.jpg" = "markings_room.foundry-hide.jpg",
		"CaesarDressing-400.woff2" = "markings_room.CaesarDressing-400.woff2",
		"Macondo-400.woff2" = "markings_room.Macondo-400.woff2",
	)

/**
 * Returns the art asset a MeridianOS theme draws with outside tgui's bundle, or null for a theme whose art is all in it.
 *
 * Arguments:
 * - theme: A MeridianOS theme ID (the meridian_theme preference's value).
 */
/proc/meridian_theme_art(theme)
	switch(theme)
		if("meridian_foundry")
			return get_asset_datum(/datum/asset/simple/art_stylesheet/meridian_foundry)
	return null

/**
 * Hands a client its MeridianOS theme's art: the files first, waiting for them to arrive, then their stylesheet to its
 * open windows and its lobby, which load it as they hear of it. For the lobby as it starts and for a theme picked while
 * windows are open; a window that opens later gets the art with its other assets (/datum/tgui/send_assets()).
 *
 * Arguments:
 * - client: The client to send to.
 * - theme: Its MeridianOS theme ID.
 */
/proc/deliver_meridian_theme_art(client/client, theme)
	set waitfor = FALSE
	var/datum/asset/art = meridian_theme_art(theme)
	if(!art || !client)
		return
	if(art.send(client))
		client.browse_queue_flush()
	if(!client)
		return
	for(var/datum/tgui/open_ui as anything in client.mob?.tgui_open_uis)
		open_ui.window?.send_asset(art)
	client.lobby_menu?.window?.send_asset(art)
