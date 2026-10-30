/**
 * Returns the colours the graffiti editor offers before a piece has its own: black and Endesga-32's greys, hues, browns
 * and skin tones, a few pastels, then neons for glow layers.
 *
 * Returns:
 * - list: The colours, made once. Never change it.
 */
/proc/graffiti_default_palette()
	RETURN_TYPE(/list)
	var/static/list/palette = list(
		"#000000", "#181425", "#262b44", "#3a4466", "#5a6988", "#8b9bb4", "#c0cbdc", "#ffffff",
		"#a22633", "#e43b44", "#ff0044", "#f77622", "#feae34", "#fee761", "#63c74d", "#3e8948", "#265c42",
		"#193c3e", "#124e89", "#0099db", "#2ce8f5", "#68386c", "#b55088", "#f6757a", "#3e2731", "#be4a2f",
		"#d77643", "#ead4aa", "#e4a672", "#b86f50", "#733e39", "#e8b796", "#c28569",
		"#ffcd75", "#eec39a", "#a7f070", "#73eff7", "#cbdbfc", "#d77bba",
		"#ff3131", "#ff5f1f", "#ffff33", "#39ff14", "#0ff0fc", "#1f51ff", "#9d00ff", "#ff10f0",
	)
	return palette
