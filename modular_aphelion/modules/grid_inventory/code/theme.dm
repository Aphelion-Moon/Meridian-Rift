/// Native HUD storage/back colors, with accents from code/modules/tooltip/tooltip.html.
/// ui_style is a HUD icon resource, as passed to storage interfaces. Returned palettes are shared and read-only.
/proc/grid_inventory_theme(ui_style)
	var/static/list/themes = list(
		'icons/hud/screen_midnight.dmi' = list(
			"background" = "#16161a",
			"grid" = "#27272d",
			"border" = "#5a7a8f",
			"header" = "#384f5a",
			"text" = "#ffffff",
			"accent" = "#6087a0",
		),
		'icons/hud/screen_retro.dmi' = list(
			"background" = "#003366",
			"grid" = "#003481",
			"border" = "#009900",
			"header" = "#005e00",
			"text" = "#ffffff",
			"accent" = "#33cc00",
		),
		'icons/hud/screen_plasmafire.dmi' = list(
			"background" = "#11111f",
			"grid" = "#21213d",
			"border" = "#c88100",
			"header" = "#9f4900",
			"text" = "#ffffff",
			"accent" = "#ffa800",
		),
		'icons/hud/screen_slimecore.dmi' = list(
			"background" = "#161c1a",
			"grid" = "#2b3834",
			"border" = "#3c804e",
			"header" = "#2a543a",
			"text" = "#ffffff",
			"accent" = "#6ea161",
		),
		'icons/hud/screen_operative.dmi' = list(
			"background" = "#13121b",
			"grid" = "#282831",
			"border" = "#610633",
			"header" = "#3f1329",
			"text" = "#a0a0a4",
			"accent" = "#b01232",
		),
		'icons/hud/screen_clockwork.dmi' = list(
			"background" = "#170800",
			"grid" = "#2d1400",
			"border" = "#8a6819",
			"header" = "#523c15",
			"text" = "#cfbc47",
			"accent" = "#b18e25",
		),
		'icons/hud/screen_glass.dmi' = list(
			"background" = "#1f252b",
			"grid" = "#344b58",
			"border" = "#48687a",
			"header" = "#374e5f",
			"text" = "#ffffff",
			"accent" = "#75a4c4",
		),
		'icons/hud/screen_trasenknox.dmi' = list(
			"background" = "#151417",
			"grid" = "#1e1d21",
			"border" = "#998e81",
			"header" = "#19493f",
			"text" = "#bfb4a6",
			"accent" = "#3ce375",
		),
		'icons/hud/screen_detective.dmi' = list(
			"background" = "#221c1a",
			"grid" = "#372e2b",
			"border" = "#796755",
			"header" = "#49241a",
			"text" = "#c7b08b",
			"accent" = "#a08662",
		),
	)
	return themes[ui_style] || themes['icons/hud/screen_midnight.dmi']

/// Shared read-only panel icon. Cell origins are 4px from the panel's left/bottom, with a 24px pitch.
/proc/grid_inventory_panel_icon(columns, rows, ui_style, header_height = 24)
	var/static/list/panel_cache = list()
	var/list/theme = grid_inventory_theme(ui_style)
	var/list/style_cache = panel_cache[theme]
	if(isnull(style_cache))
		style_cache = list()
		panel_cache[theme] = style_cache
	var/size_key = "[columns]x[rows]x[header_height]"
	var/icon/panel = style_cache[size_key]
	if(panel)
		return panel

	var/width = columns * 24 + 8
	var/height = rows * 24 + 8 + header_height
	panel = icon('icons/blanks/32x32.dmi', "nothing")
	panel.Crop(1, 1, width, height)
	panel.DrawBox(theme["border"], 1, 1, width, height)
	panel.DrawBox(theme["background"], 3, 3, width - 2, height - 2)
	panel.DrawBox(theme["header"], 3, rows * 24 + 8, width - 2, height - 2)
	// Draw shared 1px boundaries, keeping every cell interior flat and unshaded.
	panel.DrawBox(theme["grid"], 5, 5, columns * 24 + 4, rows * 24 + 4)
	panel.DrawBox(theme["background"], 6, 6, columns * 24 + 3, rows * 24 + 3)
	for(var/column in 1 to columns - 1)
		var/grid_x = column * 24 + 4
		panel.DrawBox(theme["grid"], grid_x, 5, grid_x, rows * 24 + 4)
	for(var/row in 1 to rows - 1)
		var/grid_y = row * 24 + 4
		panel.DrawBox(theme["grid"], 5, grid_y, columns * 24 + 4, grid_y)
	style_cache[size_key] = panel
	return panel

/// Shared read-only cell feedback. Translucent fills leave the grid visible beneath the item art.
/proc/grid_inventory_cell_icon(color, filled = FALSE)
	var/static/list/cell_cache = list()
	var/cache_key = "[color]-[filled]"
	var/icon/cell = cell_cache[cache_key]
	if(cell)
		return cell
	cell = icon('icons/blanks/32x32.dmi', "nothing")
	cell.Crop(1, 1, 24, 24)
	cell.DrawBox(color, 1, 1, 24, 24)
	if(!filled)
		cell.DrawBox(null, 2, 2, 23, 23)
	cell_cache[cache_key] = cell
	return cell

/// Shared read-only tooltip backing; width/height are pixel dimensions chosen by the interface.
/proc/grid_inventory_tooltip_icon(width, height, ui_style)
	var/static/list/tooltip_cache = list()
	var/list/theme = grid_inventory_theme(ui_style)
	var/list/style_cache = tooltip_cache[theme]
	if(isnull(style_cache))
		style_cache = list()
		tooltip_cache[theme] = style_cache
	var/size_key = "[width]x[height]"
	var/icon/background = style_cache[size_key]
	if(background)
		return background
	background = icon('icons/blanks/32x32.dmi', "nothing")
	background.Crop(1, 1, width, height)
	background.DrawBox(theme["border"], 1, 1, width, height)
	background.DrawBox(theme["background"], 3, 3, width - 2, height - 2)
	style_cache[size_key] = background
	return background

/// Shared read-only title mouse target; its opaque fill merges with the panel's flat header.
/proc/grid_inventory_title_icon(width, ui_style, height = 23)
	var/static/list/title_cache = list()
	var/list/theme = grid_inventory_theme(ui_style)
	var/list/style_cache = title_cache[theme]
	if(isnull(style_cache))
		style_cache = list()
		title_cache[theme] = style_cache
	var/size_key = "[width]x[height]"
	var/icon/title = style_cache[size_key]
	if(title)
		return title
	title = icon('icons/blanks/32x32.dmi', "nothing")
	title.Crop(1, 1, width, height)
	title.DrawBox(theme["header"], 1, 1, width, height)
	style_cache[size_key] = title
	return title

/// Shared read-only 16px close glyph, centered inside the panel's header by the interface.
/proc/grid_inventory_close_icon(ui_style)
	var/static/list/close_cache = list()
	var/list/theme = grid_inventory_theme(ui_style)
	var/icon/close = close_cache[theme]
	if(close)
		return close
	close = icon('icons/blanks/32x32.dmi', "nothing")
	close.Crop(1, 1, 16, 16)
	for(var/pixel in 4 to 13)
		close.DrawBox(theme["text"], pixel, pixel)
		close.DrawBox(theme["text"], pixel, 17 - pixel)
	close_cache[theme] = close
	return close
