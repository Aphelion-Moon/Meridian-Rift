// APHELION MODULE - BUG_REPORTING - smaller snapshot fonts
/// MD5s of tg's Font Awesome stylesheet and its regular, solid and v4 fonts as our WOFF2 copies were made from them
#define FONT_AWESOME_SOURCE_MD5S "2ec116e0bc3649cf5241a03e43616702,262525e2081311609d1fdab966c82bfc,269f971cec0d5dc864fe9ae080b19e23,4ed293ceaca9b5b2d9cd74a477963fae"

/**
 * Sends Font Awesome as WOFF2 instead of tg's TrueType fonts, under a third of the size for every window and for
 * every bug report snapshot that shows an icon.
 *
 * The copies in modular_aphelion/master_files/html/font-awesome only match the tg files they were made from, so once
 * a tg update changes those we send tg's own files until the copies are made again (the README there says how).
 */
/datum/asset/simple/namespaced/fontawesome/register()
	var/list/hashlist = list()
	for(var/source in list('html/font-awesome/css/all.min.css', 'html/font-awesome/webfonts/fa-regular-400.ttf', 'html/font-awesome/webfonts/fa-solid-900.ttf', 'html/font-awesome/webfonts/fa-v4compatibility.ttf'))
		hashlist += md5asfile(source)
	if(jointext(hashlist, ",") != FONT_AWESOME_SOURCE_MD5S)
		stack_trace("tg's Font Awesome files changed, so the WOFF2 copies in modular_aphelion/master_files/html/font-awesome need making again")
		return ..()
	assets -= list("fa-regular-400.ttf", "fa-solid-900.ttf", "fa-v4compatibility.ttf")
	assets["fa-regular-400.woff2"] = 'modular_aphelion/master_files/html/font-awesome/webfonts/fa-regular-400.woff2'
	assets["fa-solid-900.woff2"] = 'modular_aphelion/master_files/html/font-awesome/webfonts/fa-solid-900.woff2'
	assets["fa-v4compatibility.woff2"] = 'modular_aphelion/master_files/html/font-awesome/webfonts/fa-v4compatibility.woff2'
	parents = list("font-awesome.css" = 'modular_aphelion/master_files/html/font-awesome/css/all.min.css')
	return ..()

#undef FONT_AWESOME_SOURCE_MD5S
