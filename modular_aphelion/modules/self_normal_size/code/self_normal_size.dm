/// The scale a body must pass for its owner to click it as at normal size: anything resized up at all.
#define SELF_NORMAL_SIZE_MIN_SCALE 1.001
/// The owner's hitbox's key among the body's alternate appearances.
#define SELF_NORMAL_SIZE_KEY "self_normal_size"
/// The key of the image that holds the owner's view, among the body's alternate appearances.
#define SELF_NORMAL_SIZE_VIEW_KEY "self_normal_size_view"
/// The hitbox's alpha - next to nothing shows, and clicks go by its icons' pixels, not its alpha.
#define SELF_NORMAL_SIZE_HITBOX_ALPHA 1

/// What the owner of a resized-up body sees of it: a copy of its look that the mouse goes straight through
/obj/effect/abstract/self_normal_size_view
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/// Routes standard overlay-helper updates to both of the component's appearance copies.
/datum/atom_hud/alternate_appearance/basic/one_person/self_normal_size
	/// The component owns this appearance; the callback must not keep that component alive.
	var/datum/weakref/component_ref

/datum/atom_hud/alternate_appearance/basic/one_person/self_normal_size/New(key, image/I, options, mob/living/seer, datum/component/self_normal_size/component)
	component_ref = WEAKREF(component)
	// The initial appearance is already complete. basic.New() would copy overlays directly onto I.
	. = ..(key, I, options & ~AA_MATCH_TARGET_OVERLAYS, seer)
	transfer_overlays = TRUE

/datum/atom_hud/alternate_appearance/basic/one_person/self_normal_size/Destroy()
	component_ref = null
	return ..()

/datum/atom_hud/alternate_appearance/basic/one_person/self_normal_size/copy_overlays(atom/other, cut_old)
	var/datum/component/self_normal_size/component = component_ref?.resolve()
	component?.queue_refresh()

/**
 * Lets the owner of a resized-up body click as if it were at normal size, and only them. They see it at its true size, as
 * everyone does. Their view is two one-person alternate appearances: an image that overrides their mob with a hitbox, a
 * copy of its look at normal size, turned as the body is, too faint to see but not to click (clicks go by its icons' pixels,
 * whatever its alpha), and an image with no look of its own holding, in its vis_contents, an object wearing a copy of the
 * body's look at its true size with the mouse turned off. An image's own mouse_opacity counts for nothing, an object's
 * does, and an override image doesn't draw its vis_contents. Both sit on the body's own plane and layer, so the body draws
 * in front of and behind everything else as it always does. So the owner can click what
 * the body covers on the tiles round it (an Oversized body's head covers the tile above) and what shows through the gaps of
 * its normal-size outline (an item at their feet), and still click themselves on that outline. Everyone else, and anything
 * that copies the body's look (mirrors, photos, afterimages), clicks and sees it as it is. tg's alternate appearance shows
 * the images to the owner alone, keeps them on the body's z-level's planes and holds them.
 *
 * The copies are made again the tick after the body's look changes (an overlay helper, an icon update, its transform, offsets or
 * colour, its death), so changes made together are copied once; a change with no signal of its own, like a filter or an
 * alpha set directly, shows with the next copy. What the game only animates on the body (a jitter, a flip, a fade) the
 * view doesn't play: the owner sees where it ends up.
 */
/datum/component/self_normal_size
	/// The object in the view image's vis_contents that shows the owner their body at its true size
	var/obj/effect/abstract/self_normal_size_view/view

/datum/component/self_normal_size/Initialize()
	if (!ishuman(parent))
		return COMPONENT_INCOMPATIBLE
	view = new

/datum/component/self_normal_size/RegisterWithParent()
	RegisterSignals(parent, list(
		COMSIG_CARBON_APPLY_OVERLAY,
		COMSIG_CARBON_REMOVE_OVERLAY,
		COMSIG_ATOM_UPDATED_ICON,
		COMSIG_LIVING_POST_UPDATE_TRANSFORM,
		COMSIG_LIVING_DEATH,
		COMSIG_ATOM_COLOR_UPDATED,
		COMSIG_LIVING_UPDATE_OFFSETS,
	), PROC_REF(queue_refresh))
	RegisterSignal(parent, COMSIG_ATOM_DIR_CHANGE, PROC_REF(on_dir_change))
	RegisterSignal(parent, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))
	refresh()

/datum/component/self_normal_size/UnregisterFromParent()
	UnregisterSignal(parent, list(
		COMSIG_CARBON_APPLY_OVERLAY,
		COMSIG_CARBON_REMOVE_OVERLAY,
		COMSIG_ATOM_UPDATED_ICON,
		COMSIG_LIVING_POST_UPDATE_TRANSFORM,
		COMSIG_LIVING_DEATH,
		COMSIG_ATOM_COLOR_UPDATED,
		COMSIG_LIVING_UPDATE_OFFSETS,
		COMSIG_ATOM_DIR_CHANGE,
		COMSIG_MOB_LOGOUT,
	))
	var/atom/owner = parent
	owner.remove_alt_appearance(SELF_NORMAL_SIZE_KEY)
	owner.remove_alt_appearance(SELF_NORMAL_SIZE_VIEW_KEY)

/datum/component/self_normal_size/Destroy()
	// After the parent's teardown, whose view image holds the view in its vis_contents until it goes
	. = ..()
	QDEL_NULL(view)

/// Copies the body's look again next tick, once however many signals come before it.
/datum/component/self_normal_size/proc/queue_refresh()
	SIGNAL_HANDLER
	// Its only timer is the refresh, so a pending timer is a refresh already queued. Checked here rather than by
	// TIMER_UNIQUE, which hashes the callback on every call (~14.5 us), once per overlay in a burst like a new outfit.
	if (_active_timers)
		return
	addtimer(CALLBACK(src, PROC_REF(refresh)), 0)

/**
 * Copies the body's look into the owner's hitbox and view, showing them to the owner if they aren't yet. A body something
 * hides behind a render target (dusting, a hologram's effects) shows its owner what everyone sees instead.
 */
/datum/component/self_normal_size/proc/refresh()
	var/mob/living/carbon/human/owner = parent
	var/datum/atom_hud/alternate_appearance/basic/one_person/shown = LAZYACCESS(owner.alternate_appearances, SELF_NORMAL_SIZE_KEY)
	if (!owner.client || owner.render_target)
		if (shown)
			owner.remove_alt_appearance(SELF_NORMAL_SIZE_KEY)
			owner.remove_alt_appearance(SELF_NORMAL_SIZE_VIEW_KEY)
		return
	// Built as mutable appearances and written to the image and the view once each, rather than var by var.
	var/mutable_appearance/copy = new(owner.appearance)
	// An override image would otherwise take on the body's own colour, alpha and transform as well as the copies of them.
	copy.appearance_flags |= RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	// An image drawn at the body takes on its offsets (lying down, on a table) as well as the copies of them.
	copy.pixel_x = 0
	copy.pixel_y = 0
	copy.pixel_w = 0
	copy.pixel_z = 0
	var/mutable_appearance/hitbox = new(copy)
	copy.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	view.appearance = copy
	hitbox.override = TRUE
	hitbox.alpha = SELF_NORMAL_SIZE_HITBOX_ALPHA
	var/matrix/transform_matrix = owner.transform
	// Upright, the hitbox needs no transform of its own at all.
	if (!transform_matrix.b && !transform_matrix.d && transform_matrix.a > 0 && transform_matrix.e > 0)
		hitbox.transform = null
	else
		// Turned as the body is (lying down), about its tile's centre, but at normal size, which needs no offset.
		var/scale = sqrt(transform_matrix.a ** 2 + transform_matrix.d ** 2)
		hitbox.transform = matrix(
			transform_matrix.a / scale, transform_matrix.b / scale, 0,
			transform_matrix.d / scale, transform_matrix.e / scale, 0,
		)
	if (shown)
		shown.image.appearance = hitbox
		return
	var/image/hitbox_image = image(loc = owner)
	hitbox_image.appearance = hitbox
	owner.add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/one_person/self_normal_size, SELF_NORMAL_SIZE_KEY, hitbox_image, NONE, owner, src)
	// Drawn on the body's plane and layer, as an image's are by default, and never written again, so it keeps the view.
	var/image/view_image = image(loc = owner)
	view_image.vis_contents += view
	owner.add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/one_person, SELF_NORMAL_SIZE_VIEW_KEY, view_image, NONE, owner)

/// Turns the hitbox and the view with the body at once, rather than a tick later.
/datum/component/self_normal_size/proc/on_dir_change(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	var/atom/owner = parent
	var/datum/atom_hud/alternate_appearance/basic/one_person/shown = LAZYACCESS(owner.alternate_appearances, SELF_NORMAL_SIZE_KEY)
	if (!shown)
		return
	shown.image.dir = new_dir
	view.dir = new_dir

/// The owner's client has left; their next mob's Login() clears its images.
/datum/component/self_normal_size/proc/on_logout()
	SIGNAL_HANDLER
	qdel(src)

/**
 * Lets this body's owner click it as at normal size while it is resized up and the "Body Size Click-Through (Self)"
 * preference is on, or stops. Called when the owner logs in, the preference changes or the body's size does.
 */
/mob/living/carbon/human/proc/update_self_normal_size()
	var/matrix/transform_matrix = transform
	var/wanted = client?.prefs?.read_preference(/datum/preference/toggle/see_self_normal_size) \
		&& sqrt(transform_matrix.a ** 2 + transform_matrix.d ** 2) > SELF_NORMAL_SIZE_MIN_SCALE
	var/datum/component/self_normal_size/shown = GetComponent(/datum/component/self_normal_size)
	if (!wanted)
		qdel(shown)
	else if (shown)
		shown.refresh()
	else
		AddComponent(/datum/component/self_normal_size)

/mob/living/carbon/human/Login()
	. = ..()
	update_self_normal_size()

#undef SELF_NORMAL_SIZE_HITBOX_ALPHA
#undef SELF_NORMAL_SIZE_KEY
#undef SELF_NORMAL_SIZE_VIEW_KEY
#undef SELF_NORMAL_SIZE_MIN_SCALE
