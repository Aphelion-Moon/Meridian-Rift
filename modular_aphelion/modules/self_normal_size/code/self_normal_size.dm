/// The scale a body must pass for its owner to be shown it at normal size: anything resized up at all.
#define SELF_NORMAL_SIZE_MIN_SCALE 1.001
/// The owner's view's key among the body's alternate appearances.
#define SELF_NORMAL_SIZE_KEY "self_normal_size"

/**
 * Shows the owner of a resized-up body their own body at normal size, and only them. Everyone else, and anything that
 * copies the body's look (mirrors, photos, afterimages), still sees it as it is. The owner's view is a one-person
 * alternate appearance: an image that overrides their mob with a copy of its own appearance, turned as the body is but
 * without its size, so the owner can click what the body covers on the tiles round it (an Oversized body's head covers
 * the tile above) and still click themselves on their own tile. tg's alternate appearance shows it to the owner alone,
 * keeps it on the body's z-level's planes and holds the image, so this component keeps no state of its own.
 *
 * The copy is made again the tick after the body's look changes, so changes made together are copied once, and on
 * every Life() tick for whatever changes without a signal. What the game only animates on the body (a jitter, a flip, a
 * fade) the copy doesn't play: the owner sees where it ends up.
 */
/datum/component/self_normal_size

/datum/component/self_normal_size/Initialize()
	if (!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/self_normal_size/RegisterWithParent()
	RegisterSignals(parent, list(
		COMSIG_CARBON_APPLY_OVERLAY,
		COMSIG_CARBON_REMOVE_OVERLAY,
		COMSIG_ATOM_UPDATED_ICON,
		COMSIG_LIVING_POST_UPDATE_TRANSFORM,
		COMSIG_LIVING_DEATH,
		COMSIG_LIVING_LIFE,
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
		COMSIG_LIVING_LIFE,
		COMSIG_ATOM_DIR_CHANGE,
		COMSIG_MOB_LOGOUT,
	))
	var/atom/owner = parent
	owner.remove_alt_appearance(SELF_NORMAL_SIZE_KEY)

/// Copies the body's look again next tick.
/datum/component/self_normal_size/proc/queue_refresh()
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(refresh)), 0, TIMER_UNIQUE)

/**
 * Copies the body's look into the owner's view, showing it to the owner if it isn't yet. A body something hides behind
 * a render target (dusting, a hologram's effects) shows its owner what everyone sees instead.
 */
/datum/component/self_normal_size/proc/refresh()
	var/mob/living/carbon/human/owner = parent
	var/datum/atom_hud/alternate_appearance/basic/one_person/shown = LAZYACCESS(owner.alternate_appearances, SELF_NORMAL_SIZE_KEY)
	if (!owner.client || owner.render_target)
		if (shown)
			owner.remove_alt_appearance(SELF_NORMAL_SIZE_KEY)
		return
	var/image/view = shown ? shown.image : image(loc = owner)
	var/matrix/transform_matrix = owner.transform
	var/scale = sqrt(transform_matrix.a ** 2 + transform_matrix.d ** 2)
	view.appearance = owner.appearance
	view.override = TRUE
	view.loc = owner
	// Turned as the body is (lying down), about its tile's centre, but at normal size, which needs no offset.
	view.transform = matrix(
		transform_matrix.a / scale, transform_matrix.b / scale, 0,
		transform_matrix.d / scale, transform_matrix.e / scale, 0,
	)
	if (!shown)
		owner.add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/one_person, SELF_NORMAL_SIZE_KEY, view, NONE, owner)

/// Turns the view with the body at once, rather than a tick later.
/datum/component/self_normal_size/proc/on_dir_change(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	var/atom/owner = parent
	var/datum/atom_hud/alternate_appearance/basic/one_person/shown = LAZYACCESS(owner.alternate_appearances, SELF_NORMAL_SIZE_KEY)
	if (shown)
		shown.image.dir = new_dir

/// The owner's client has left; their next mob's Login() clears its images.
/datum/component/self_normal_size/proc/on_logout()
	SIGNAL_HANDLER
	qdel(src)

/**
 * Shows this body's owner their own body at normal size while it is resized up and the "See yourself at normal size"
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

#undef SELF_NORMAL_SIZE_KEY
#undef SELF_NORMAL_SIZE_MIN_SCALE
