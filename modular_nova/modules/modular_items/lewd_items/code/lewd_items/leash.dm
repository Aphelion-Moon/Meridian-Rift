/obj/item/clothing/erp_leash
	name = "leash"
	desc = "A guiding hand's best friend; in a sleek, semi-elastic package. Can either clip to a collar or be affixed to the neck on its own."
	worn_icon = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_belts.dmi'
	greyscale_colors = "#383840#dc7ef4#d1d3e0"
	icon = 'icons/map_icons/clothing/_clothing.dmi'
	icon_state = "/obj/item/clothing/erp_leash"
	post_init_icon_state = "neckleash"
	greyscale_config = /datum/greyscale_config/neckleash
	greyscale_config_worn = /datum/greyscale_config/neckleash/worn
	equip_sound = 'sound/items/equip/toolbelt_equip.ogg'
	drop_sound = 'sound/items/handling/toolbelt_drop.ogg'
	slot_flags = ITEM_SLOT_BELT
	obj_flags_nova = ERP_ITEM
	breakouttime = 3 SECONDS
	flags_1 = IS_PLAYER_COLORABLE_1

	/// Weakref to the leash component we're using, if it exists.
	var/datum/weakref/our_leash_component

	COOLDOWN_DECLARE(tug_cd)

/// HERE BE DRAGONS ///

/// Checks; leashing start
/obj/item/clothing/erp_leash/attack(mob/living/carbon/human/to_be_leashed, mob/living/user, params)
	var/datum/component/leash/erp/the_leash_component = our_leash_component?.resolve()
	if(the_leash_component)
		if(the_leash_component.parent == to_be_leashed) // We're hooked to them; and we have a component. Get 'em out!
			remove_leash(to_be_leashed)
			return
	else
		our_leash_component = null
	/// Check if we even CAN leash someone / if someone is leashing themselves. If so; prevent it.
	if(!istype(to_be_leashed) || user == to_be_leashed)
		return
	/// Check their ERP prefs; if they don't allow sextoys: BTFO
	if(!to_be_leashed.check_erp_prefs(/datum/preference/toggle/erp/sex_toy, user, src))
		to_chat(user, span_danger("[to_be_leashed] doesn't want you to do that."))
		return
	/// Actually start the leashing part here
	to_be_leashed.visible_message(span_warning("[user] raises the [src] to [to_be_leashed]'s neck!"),\
				span_userdanger("[user] starts to bring the [src] to your neck!"),\
				span_hear("You hear a light click as pressure builds in the air around your neck."))
	if(!do_after(user, 2 SECONDS, to_be_leashed))
		return
	create_leash(user, to_be_leashed)

/// Leash Initialization
/obj/item/clothing/erp_leash/proc/create_leash(mob/user, mob/ouppy)
	if(!istype(ouppy))
		return

	ouppy.AddComponent(/datum/component/leash/erp, src, 2)
	var/datum/component/leash/erp/hooked = our_leash_component?.resolve()
	if(hooked) // The component will immediately delete itself if there's an existing one; this sanity checks for feedback on if it failed.
		ouppy.balloon_alert(user, "leashed!")
		hooked.draw_line()
		return
	else to_chat(user, span_danger("There's a leash attached to [ouppy] already."))

/// Leash removal
/obj/item/clothing/erp_leash/proc/remove_leash(mob/free_bird)
	free_bird?.balloon_alert_to_viewers("unhooked")
	qdel(our_leash_component.resolve())

/*
	Leash Component
*/

/datum/component/leash/erp
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// The line from the hand holding the leash to the leashed
	var/datum/beam/held/vacuum/leash/line

// 'owner' refers the leash item, while 'parent' refers to the one it's affixed to.
/datum/component/leash/erp/RegisterWithParent()
	. = ..()
	// Owner Signals
	RegisterSignal(owner, COMSIG_ITEM_ATTACK_SELF, PROC_REF(on_item_attack_self))
	RegisterSignal(owner, COMSIG_ITEM_DROPPED, PROC_REF(on_item_dropped))
	// Parent Signals
	RegisterSignal(parent, COMSIG_LIVING_RESIST, PROC_REF(on_parent_resist))
	if(istype(owner, /obj/item/clothing/erp_leash))
		var/obj/item/clothing/erp_leash/our_leash = owner
		our_leash.our_leash_component = WEAKREF(src)

/datum/component/leash/erp/UnregisterFromParent()
	if(owner) // Destroy() sets owner to null
		UnregisterSignal(owner, list(COMSIG_ITEM_ATTACK_SELF, COMSIG_ITEM_DROPPED))
		UnregisterSignal(parent, COMSIG_LIVING_RESIST)
	return ..()

/datum/component/leash/erp/Destroy() // Have to do this here too
	UnregisterSignal(owner, list(COMSIG_ITEM_ATTACK_SELF, COMSIG_ITEM_DROPPED))
	QDEL_NULL(line)
	if(istype(owner, /obj/item/clothing/erp_leash))
		var/obj/item/clothing/erp_leash/our_leash = owner
		our_leash.our_leash_component = null
	return ..()

/// Draws the line from the hand holding the leash to the leashed, in the colour of the leash's strap
/datum/component/leash/erp/proc/draw_line()
	var/mob/holder = owner.loc
	if(!ismob(holder))
		return
	line = new(holder, parent, icon_state = "fishing_line", beam_color = SSgreyscale.ParseColorString(owner.greyscale_colors)[1], emissive = FALSE)
	line.lefthand = IS_LEFT_INDEX(holder.get_held_index_of_item(owner))
	RegisterSignal(line, COMSIG_QDELETING, PROC_REF(on_line_deleted))
	INVOKE_ASYNC(line, TYPE_PROC_REF(/datum/beam, Start))

/// The line is deleted with either of its ends
/datum/component/leash/erp/proc/on_line_deleted(datum/source)
	SIGNAL_HANDLER
	line = null

/datum/component/leash/erp/proc/on_item_attack_self(datum/source, mob/user)
	SIGNAL_HANDLER

	if(istype(source, /obj/item/clothing/erp_leash))
		var/obj/item/clothing/erp_leash/leash_hookin = source
		if(!COOLDOWN_FINISHED(leash_hookin, tug_cd))
			return
		if(istype(parent, /mob/living))
			var/mob/living/yoinked = parent
			yoinked.Move(get_step_towards(yoinked,user))
			yoinked.adjust_stamina_loss(10)
			yoinked.visible_message(span_warning("[yoinked] is pulled in as [user] tugs the [source]!"),\
					span_userdanger("[user] suddenly tugs the [source], pulling you closer!"),\
					span_userdanger("A sudden tug against your neck pulls you ahead!"))
			COOLDOWN_START(leash_hookin, tug_cd, 1 SECONDS)

/datum/component/leash/erp/proc/on_item_dropped(datum/source, mob/user)
	SIGNAL_HANDLER

	if(istype(parent, /mob))
		var/mob/our_parent = parent
		our_parent.balloon_alert_to_viewers("unhooked")
	qdel(src)

/datum/component/leash/erp/proc/on_parent_resist(datum/source, mob/user)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(do_resist))

/datum/component/leash/erp/proc/do_resist(datum/source, mob/user)
	if(istype(parent, /mob) && istype(owner,/obj/item))
		var/mob/our_parent = parent
		var/obj/item/our_owner = owner
		our_parent.visible_message(span_warning("[our_parent] attempts to unhook [our_parent.p_them()]self from the leash!"), \
			span_userdanger("You start to unhook yourself from the leash..."), \
			span_userdanger("You fumble in the dark, looking to unhook the leash..."))
		if(do_after(our_parent, our_owner.breakouttime, target = our_parent))
			to_chat(our_parent, span_notice("You unhook yourself from the leash."))
			qdel(src)
	else qdel(src) // If they're not an item; something is very wrong - qdel anyways without the breakout time.

/// The leash's line - it leaves the hand where the borg vacuum's hose does, and is blank while the two are out of reach
/datum/beam/held/vacuum/leash

/// Blanks the line, where a beam would delete itself, while an end is inside something or on another z-level
/datum/beam/held/vacuum/leash/redrawing(atom/movable/mover, atom/oldloc, direction)
	if(QDELETED(origin) || QDELETED(target) || (isturf(origin.loc) && isturf(target.loc) && origin.z == target.z))
		return ..()
	Draw()

/// Each draw runs `CheckToolReach` - a dummy obj, up to six `Move()` calls and a `qdel` - as tg's fishing line does
/datum/beam/held/vacuum/leash/Draw(atom/movable/mover, atom/oldloc)
	// 6 is past the leash's 2 tiles, so a leashed being pulled along keeps the line
	if(isturf(origin.loc) && isturf(target.loc) && CheckToolReach(origin, target, 6))
		return ..()
	QDEL_LIST(elements)
	last_draw_valid = FALSE // back in reach, the line is drawn where the two are instead of gliding from where it was
