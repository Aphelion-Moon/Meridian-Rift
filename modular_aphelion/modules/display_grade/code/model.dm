/// Display-grade controls use normalized sRGB and fractional strengths, not percentages.
/proc/display_grade_reference()
	return list(
		"strength" = 1,
		"saturation" = 0.72,
		"contrast" = 1,
		"brightness" = 0,
		"shadow_color" = "#2D2639",
		"shadow_strength" = 1,
		"midtone_color" = "#718A83",
		"midtone_strength" = 0.4,
		"highlight_color" = "#D6C998",
		"highlight_strength" = 1,
	)

/// Reject incomplete or invalid updates atomically. Never retain a caller-owned list.
/proc/display_grade_validate(list/settings)
	if(!islist(settings))
		return null
	var/list/result = display_grade_reference()
	var/list/ranges = list(
		"strength" = list(0, 1),
		"saturation" = list(0, 1.5),
		"contrast" = list(0.5, 1.5),
		"brightness" = list(-0.2, 0.2),
		"shadow_strength" = list(0, 1),
		"midtone_strength" = list(0, 1),
		"highlight_strength" = list(0, 1),
	)
	for(var/key in ranges)
		var/value = settings[key]
		var/list/bounds = ranges[key]
		if(!IS_FINITE(value) || value < bounds[1] || value > bounds[2])
			return null
		result[key] = value
	var/static/regex/rgb_hex = regex("^#\[0-9a-fA-F\]{6}$")
	for(var/key in list("shadow_color", "midtone_color", "highlight_color"))
		if(!istext(settings[key]) || length(settings[key]) != 7 || !rgb_hex.Find(settings[key]))
			return null
		result[key] = uppertext(settings[key])
	return result

/// BYOND matrices are input-major (SVG matrices are output-major).
/// Combine all three adjustments before clamping, so oversaturation is not clipped early.
/proc/display_grade_adjustment_matrix(list/settings)
	var/saturation = settings["saturation"]
	var/contrast = settings["contrast"]
	var/bias = (1 - contrast) / 2 + settings["brightness"]
	var/list/luma = list(0.2126, 0.7152, 0.0722)
	var/list/result = list()
	for(var/input_channel in 1 to 3)
		for(var/output_channel in 1 to 3)
			result += contrast * ((input_channel == output_channel ? saturation : 0) + (1 - saturation) * luma[input_channel])
		result += 0
	result += list(0, 0, 0, 1, bias, bias, bias, 0)
	return result

/// CPU oracle for acceptance swatches only; never used to recolor game sprites.
/proc/display_grade_sample(list/rgba, list/settings)
	var/list/adjustment = display_grade_adjustment_matrix(settings)
	var/list/adjusted = list()
	for(var/channel in 1 to 3)
		adjusted += clamp(rgba[1] * adjustment[channel] + rgba[2] * adjustment[channel + 4] + rgba[3] * adjustment[channel + 8] + adjustment[channel + 16], 0, 1)
	var/luma = adjusted[1] * 0.2126 + adjusted[2] * 0.7152 + adjusted[3] * 0.0722
	var/shadow = max(1 - 2 * luma, 0)
	var/highlight = max(2 * luma - 1, 0)
	var/list/weights = list("shadow" = shadow, "midtone" = 1 - shadow - highlight, "highlight" = highlight)
	var/list/graded = list(0, 0, 0)
	for(var/band in weights)
		var/list/tint = rgb2num(settings["[band]_color"])
		var/strength = settings["[band]_strength"]
		for(var/channel in 1 to 3)
			graded[channel] += weights[band] * (adjusted[channel] * (1 - strength) + tint[channel] / 255 * strength)
	var/list/result = list()
	for(var/channel in 1 to 3)
		result += rgba[channel] * (1 - settings["strength"]) + graded[channel] * settings["strength"]
	result += rgba[4]
	return result
