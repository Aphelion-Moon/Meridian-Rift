#define BULGE_FMOD(value, divisor) ((value) - (divisor) * floor((value) / (divisor)))

/// Python's round(): a half goes to the even neighbour.
/proc/bulge_round_half_even(value)
	var/whole = floor(value)
	var/fraction = value - whole
	if(fraction > 0.5)
		return whole + 1
	if(fraction < 0.5)
		return whole
	return (whole % 2) ? whole + 1 : whole

/// bulge_v4.rgb_to_hcy: colorsys hue in degrees, chroma and Rec. 601 luma in 0-100, from 0-255 channels.
/proc/bulge_rgb_to_hcy(red, green, blue)
	var/r = red / 255
	var/g = green / 255
	var/b = blue / 255
	var/maxc = max(r, g, b)
	var/minc = min(r, g, b)
	var/hue = 0
	if(minc != maxc)
		var/rangec = maxc - minc
		var/rc = (maxc - r) / rangec
		var/gc = (maxc - g) / rangec
		var/bc = (maxc - b) / rangec
		if(r == maxc)
			hue = bc - gc
		else if(g == maxc)
			hue = 2 + rc - bc
		else
			hue = 4 + gc - rc
		hue = BULGE_FMOD(hue / 6, 1)
	return list(hue * 360, (maxc - minc) * 100, (0.299 * r + 0.587 * g + 0.114 * b) * 100)

/// bulge_v4._hcy_raw: HCY to unclamped RGB fractions.
/proc/bulge_hcy_raw(hue, chroma, luma)
	chroma = chroma / 100
	luma = luma / 100
	var/hp = BULGE_FMOD(hue, 360) / 60
	var/x = chroma * (1 - abs(BULGE_FMOD(hp, 2) - 1))
	var/r1 = 0
	var/g1 = 0
	var/b1 = 0
	switch(floor(hp) % 6)
		if(0)
			r1 = chroma
			g1 = x
		if(1)
			r1 = x
			g1 = chroma
		if(2)
			g1 = chroma
			b1 = x
		if(3)
			g1 = x
			b1 = chroma
		if(4)
			r1 = x
			b1 = chroma
		if(5)
			r1 = chroma
			b1 = x
	var/m = luma - (0.299 * r1 + 0.587 * g1 + 0.114 * b1)
	return list(r1 + m, g1 + m, b1 + m)

/// bulge_v4.hcy_to_rgb: drops chroma by bisection until the colour fits, then rounds half to even.
/proc/bulge_hcy_to_rgb(hue, chroma, luma)
	luma = max(0, min(100, luma))
	var/lo = 0
	var/hi = max(0, chroma)
	var/list/rgb = bulge_hcy_raw(hue, hi, luma)
	if(min(rgb) < 0 || max(rgb) > 1)
		for(var/step in 1 to 24)
			var/mid = (lo + hi) / 2
			rgb = bulge_hcy_raw(hue, mid, luma)
			if(min(rgb) < 0 || max(rgb) > 1)
				hi = mid
			else
				lo = mid
		rgb = bulge_hcy_raw(hue, lo, luma)
	var/list/out = list()
	for(var/channel in rgb)
		var/scaled = channel * 255
		out += max(0, min(255, bulge_round_half_even(scaled)))
	return out

/// bulge_v4.toward: turns a hue toward a target by at most `amount` degrees.
/proc/bulge_toward(hue, target, amount)
	var/diff = BULGE_FMOD(target - hue + 540, 360) - 180
	return BULGE_FMOD(hue + max(-amount, min(amount, diff)), 360)

/**
 * bulge_v4.adaptive(cloth, finish, toned = TRUE): the five kinds f, h, H, s, d as lists of three channels.
 *
 * Arguments:
 * - fin_lift, fin_chroma, fin_shift: the finish (cloth 1/1.4/1, denim 0.75/0.75/0, leather 0.55/1/0).
 */
/proc/bulge_adaptive(red, green, blue, fin_lift, fin_chroma, fin_shift)
	var/list/hcy = bulge_rgb_to_hcy(red, green, blue)
	var/hue = hcy[1]
	var/chroma = hcy[2]
	var/luma = hcy[3]
	var/colourful = max(0, min(1, (chroma - 6) / 14))
	var/lift = min(0.3 * (100 - luma), 8 + 8 * colourful) * fin_lift
	var/c_hi = (fin_chroma > 1) ? (chroma * (1 + (fin_chroma - 1) * colourful)) : (chroma * fin_chroma)
	lift *= 1 - 0.45 * max(0, min(1, (chroma - 25) / 25))
	c_hi = min(c_hi, chroma + 8)
	var/shift = 6 * colourful * fin_shift
	var/y_sh = max(0, min(luma * 0.78, luma - 3))
	var/y_deep = max(0, min(luma * 0.58, luma - 6))
	var/list/light = bulge_hcy_to_rgb(bulge_toward(hue, 60, shift), c_hi, luma + lift)
	var/list/brightest = bulge_hcy_to_rgb(bulge_toward(hue, 60, shift * 1.6), c_hi, luma + lift * 1.7)
	var/list/shade = bulge_hcy_to_rgb(bulge_toward(hue, 240, shift * 0.8), luma ? (chroma * y_sh / luma) : 0, y_sh)
	var/list/deepest = bulge_hcy_to_rgb(bulge_toward(hue, 240, shift * 1.2), luma ? (chroma * y_deep / luma) : 0, y_deep)
	return list(list(red, green, blue), light, brightest, shade, deepest)

/**
 * The palettes this float32 port computes one off in a channel from the approved values (computed in float64), with the
 * approved palette to use instead: 71 channels in 38 (colour, finish) pairs, all where float64 lands on the other side
 * of a half (#afafaf's shade is exactly 136.5). Found by sweeping every colour the approved palettes were made for, the
 * 4,096-colour grid of multiples of 17 and 760 garment colours, natively against them; every other one of their 218,520
 * channels the float32 computation gives exactly. A change to the arithmetic above needs that sweep again. Null when
 * the computation stands.
 */
/proc/bulge_palette_exception(red, green, blue, finish)
	switch(red * 65536 + green * 256 + blue)
		if(0x198019)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#198019", "#3e8b3e", "#4e9b4e", "#146414", "#0f4a0f")
				if(BULGE_FINISH_LEATHER)
					return list("#198019", "#299029", "#359c35", "#146414", "#0f4a0f")
		if(0x25374B)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#25374b", "#424f5e", "#536170", "#1d2b3b", "#15202c")
				if(BULGE_FINISH_LEATHER)
					return list("#25374b", "#37495d", "#44566a", "#1d2b3b", "#15202c")
		if(0x3F2219)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#3f2219", "#533d36", "#644e48", "#311b14", "#25140e")
				if(BULGE_FINISH_LEATHER)
					return list("#3f2219", "#51342b", "#5e4138", "#311b14", "#25140e")
		if(0x4B1515)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#4b1515", "#603838", "#764d4d", "#3b1010", "#2c0c0c")
				if(BULGE_FINISH_LEATHER)
					return list("#4b1515", "#612b2b", "#713b3b", "#3b1010", "#2c0c0c")
		if(0x4B2D4D)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#4b2d4d", "#5d475f", "#6d566e", "#3b233c", "#2b1a2d")
				if(BULGE_FINISH_LEATHER)
					return list("#4b2d4d", "#5b3d5d", "#674969", "#3b233c", "#2b1a2d")
		if(0x4B6946)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#4b6946", "#677e63", "#788e74", "#3b5237", "#2c3d29")
				if(BULGE_FINISH_LEATHER)
					return list("#4b6946", "#5c7a57", "#698764", "#3b5237", "#2c3d29")
		if(0x4B9497)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#4b9497", "#72a9ab", "#85bcbe", "#3b7376", "#2c5658")
				if(BULGE_FINISH_LEATHER)
					return list("#4b9497", "#5ea7aa", "#6cb5b8", "#3b7376", "#2c5658")
		if(0x521B19)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#521b19", "#673e3c", "#7c5352", "#401513", "#30100e")
				if(BULGE_FINISH_LEATHER)
					return list("#521b19", "#68312f", "#78413f", "#401513", "#30100e")
		if(0x5A4B2C)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#5a4b2c", "#736850", "#877c64", "#463b22", "#342c1a")
				if(BULGE_FINISH_LEATHER)
					return list("#5a4b2c", "#6f6041", "#7d6e4f", "#463b22", "#342c1a")
		if(0x664B1E)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#664b1e", "#7d6947", "#917d5b", "#503b17", "#3b2c11")
				if(BULGE_FINISH_LEATHER)
					return list("#664b1e", "#7b6033", "#8a6f42", "#503b17", "#3b2c11")
		if(0x664B32)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#664b32", "#7f6b58", "#95806e", "#503b27", "#3b2c1d")
				if(BULGE_FINISH_LEATHER)
					return list("#664b32", "#7c6148", "#8c7158", "#503b27", "#3b2c1d")
		if(0x695A4B)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#695a4b", "#7c7065", "#8b7f74", "#52463a", "#3d342b")
				if(BULGE_FINISH_LEATHER)
					return list("#695a4b", "#796a5b", "#847566", "#52463a", "#3d342b")
		if(0x7DA4AB)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#7da4ab", "#9bb8bd", "#abc8cd", "#628085", "#485f63")
				if(BULGE_FINISH_LEATHER)
					return list("#7da4ab", "#8eb5bc", "#9ac1c8", "#628085", "#485f63")
		if(0x837D80)
			switch(finish)
				if(BULGE_FINISH_CLOTH)
					return list("#837d80", "#979194", "#a6a0a3", "#666264", "#4c484a")
				if(BULGE_FINISH_DENIM)
					return list("#837d80", "#918d8f", "#9c989a", "#666264", "#4c484a")
				if(BULGE_FINISH_LEATHER)
					return list("#837d80", "#8e888b", "#969093", "#666264", "#4c484a")
		if(0x9C957D)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#9c957d", "#b0ab99", "#c0baa8", "#7a7462", "#5a5648")
				if(BULGE_FINISH_LEATHER)
					return list("#9c957d", "#aca58d", "#b7b098", "#7a7462", "#5a5648")
		if(0xAF4947)
			switch(finish)
				if(BULGE_FINISH_DENIM)
					return list("#af4947", "#b36665", "#c27674", "#883937", "#652a29")
				if(BULGE_FINISH_LEATHER)
					return list("#af4947", "#bf5957", "#ca6462", "#883937", "#652a29")
		if(0xAFAFAF)
			switch(finish)
				if(BULGE_FINISH_CLOTH)
					return list("#afafaf", "#c3c3c3", "#d2d2d2", "#888888", "#656565")
				if(BULGE_FINISH_DENIM)
					return list("#afafaf", "#bebebe", "#c9c9c9", "#888888", "#656565")
				if(BULGE_FINISH_LEATHER)
					return list("#afafaf", "#bababa", "#c2c2c2", "#888888", "#656565")
		if(0xF4FAFF)
			switch(finish)
				if(BULGE_FINISH_CLOTH)
					return list("#f4faff", "#f7fbff", "#fafdff", "#bec3c7", "#8e9194")
		if(0xFFFFFA)
			switch(finish)
				if(BULGE_FINISH_CLOTH)
					return list("#fffffa", "#fffffc", "#fffffd", "#c7c7c3", "#949491")
	return null

#undef BULGE_FMOD
