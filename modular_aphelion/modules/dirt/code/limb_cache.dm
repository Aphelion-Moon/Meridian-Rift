/// The images of the limbs drawn under a key carrying DIRT_PRIVATE_KEY, by body zone: list(key, images). One entry per
/// zone, kept here rather than in the static limb_icon_cache (limb_icons_for()). Null while it holds none, so a clean
/// body's update_body_parts() reads tg's cache without calling limb_icons_for() (DIRT_LIMB_ICONS_STEADY()).
/mob/living/carbon/var/alist/private_limb_icons

/**
 * Returns the images update_body_parts() draws a limb with under its render key. tg's limb_icon_cache, shared by every
 * body, serves the keys that come back. A key carrying DIRT_PRIVATE_KEY, a dirty limb's, almost never comes back, so
 * its images are kept on this mob instead, one entry per zone, built again when asked to or when the zone's stored key
 * differs. A zone drawn under any other key drops its private entry. update_body_parts() calls it only while this mob
 * holds private images, or for a key tg's cache can't serve (DIRT_LIMB_ICONS_STEADY(), DIRT_LIMB_ICONS_CHANGED()).
 *
 * Arguments:
 * - limb: The limb.
 * - key: Its render key (get_cache_key()).
 * - rebuild: Whether the zone's key changed since its last draw: its private images are built again.
 */
/mob/living/carbon/proc/limb_icons_for(obj/item/bodypart/limb, key, rebuild)
	RETURN_TYPE(/list)
	var/zone = limb.body_zone
	var/list/entry = private_limb_icons?[zone]
	// the steady draws: the zone's private entry under its key, or a key tg's cache holds, which is never private
	if(entry)
		if(!rebuild && entry[1] == key)
			return entry[2]
	else
		var/list/cached = limb_icon_cache[key]
		if(cached)
			return cached
	if(!findtextEx(key, DIRT_PRIVATE_KEY))
		if(entry)
			LAZYREMOVE(private_limb_icons, zone)
		limb_icon_cache[key] ||= limb.get_limb_icon(FALSE)
		return limb_icon_cache[key]
	private_limb_icons ||= alist()
	entry = list(key, limb.get_limb_icon(FALSE))
	private_limb_icons[zone] = entry
	return entry[2]

/**
 * Returns the images a zone's limb was last drawn with, from either store (limb_icons_for()), or null while it isn't
 * drawn.
 *
 * Arguments:
 * - zone: The body zone.
 */
/mob/living/carbon/proc/drawn_limb_icons(zone)
	RETURN_TYPE(/list)
	var/key = icon_render_keys[zone]
	if(isnull(key))
		return null
	if(!findtextEx(key, DIRT_PRIVATE_KEY))
		return limb_icon_cache[key]
	var/list/entry = private_limb_icons?[zone]
	return entry?[1] == key ? entry[2] : null

/// A limb leaving its body takes its private images with it, so a limb put in its place, even one drawn under the same
/// key before the body is drawn again (a species change swaps them so), is drawn from its own sprites.
/obj/item/bodypart/on_removal(mob/living/carbon/old_owner)
	. = ..()
	LAZYREMOVE(old_owner.private_limb_icons, body_zone)
