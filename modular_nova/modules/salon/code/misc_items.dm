
/obj/item/storage/box/lipsticks
	name = "lipstick box"

/obj/item/storage/box/lipsticks/PopulateContents()
	..()
	new /obj/item/lipstick(src)
	new /obj/item/lipstick/purple(src)
	new /obj/item/lipstick/jade(src)
	new /obj/item/lipstick/black(src)

/obj/item/lipstick/quantum
	name = "quantum lipstick"

/obj/item/lipstick/quantum/attack(mob/attacked_mob, mob/user)
	if(!open || !ismob(attacked_mob))
		return

	if(!ishuman(attacked_mob))
		to_chat(user, span_warning("Where are the lips on that?"))
		return

	INVOKE_ASYNC(src, PROC_REF(async_set_color), attacked_mob, user)

/obj/item/lipstick/quantum/proc/async_set_color(mob/attacked_mob, mob/user)
	var/new_color = tgui_color_picker(
			user,
			"Select lipstick color",
			null,
			COLOR_WHITE,
		)

	var/mob/living/carbon/human/target = attacked_mob
	if(target.is_mouth_covered())
		to_chat(user, span_warning("Remove [ target == user ? "your" : "[target.p_their()]" ] mask!"))
		return
	if(target.lip_style) //if they already have lipstick on
		to_chat(user, span_warning("You need to wipe off the old lipstick first!"))
		return

	if(target == user)
		user.visible_message(span_notice("[user] does [user.p_their()] lips with \the [src]."), \
			span_notice("You take a moment to apply \the [src]. Perfect!"))
		target.update_lips("lipstick", new_color, lipstick_trait)
		return

	user.visible_message(span_warning("[user] begins to do [target]'s lips with \the [src]."), \
		span_notice("You begin to apply \the [src] on [target]'s lips..."))
	if(!do_after(user, 2 SECONDS, target = target))
		return
	user.visible_message(span_notice("[user] does [target]'s lips with \the [src]."), \
		span_notice("You apply \the [src] on [target]'s lips."))
	target.update_lips("lipstick", new_color, lipstick_trait)

/obj/item/hairbrush/comb
	name = "comb"
	desc = "A rather simple tool, used to straighten out hair and knots in it."
	icon = 'modular_nova/modules/salon/icons/items.dmi'
	icon_state = "blackcomb"

/obj/item/hairstyle_preview_magazine
	name = "hip hairstyles magazine"
	desc = "A magazine featuring a magnitude of hairsytles!"

/obj/item/hairstyle_preview_magazine/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	// A simple GUI with a list of hairstyles and a view, so people can choose a hairstyle!

// APHELION EDIT CHANGE START - GAGS hair trimmings that take the cut hair's colour.
// ORIGINAL:
// /obj/effect/decal/cleanable/hair
// 	name = "hair cuttings"
// 	icon = 'modular_nova/modules/salon/icons/items.dmi'
// 	icon_state = "cut_hair"

/// How far the sheen highlight is lifted towards white from the hair's own
/// colour. High enough that black hair still shows strands rather than reading
/// as one flat silhouette.
#define HAIR_TRIMMING_SHEEN_LIFT 0.65

/**
 * Resolves the colour this head's hair actually renders in.
 *
 * Mirrors the precedence in [/obj/item/bodypart/head/proc/set_overlay_hair_color],
 * so trimmings match the hair they came off even when something has overridden it.
 *
 * * facial - read the facial hair colour instead of the scalp's.
 */
/obj/item/bodypart/head/proc/get_rendered_hair_color(facial = FALSE)
	return override_hair_color || fixed_hair_color || (facial ? facial_hair_color : hair_color)

/**
 * Drops a pile of hair cuttings, coloured from the hair that was just cut off.
 *
 * * target_turf - where the pile lands. Does nothing if null.
 * * shorn - whoever got cut. A missing head just falls back to black.
 * * pile_size - 1 a light trim, 2 a restyle, 3 the whole lot coming off.
 * * facial - the cuttings came off a beard rather than a scalp.
 * * hairstyle - the style the hair came off, which decides whether the pile
 * falls in curls. Defaults to whatever the mob is wearing now, so callers that
 * restyle first should pass the old name.
 */
/proc/drop_hair_trimmings(turf/target_turf, mob/living/carbon/human/shorn, pile_size = 2, facial = FALSE, hairstyle)
	if(!target_turf)
		return
	var/obj/item/bodypart/head/noggin = shorn?.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(hairstyle))
		hairstyle = facial ? shorn?.facial_hairstyle : shorn?.hairstyle
	// Curly hair leaves curly clippings. findtext is case insensitive, so this
	// catches Curly, Curls, Royal Curls, Bobcurl and friends alike.
	var/shape = findtext(hairstyle, "curl") ? "curl" : null
	var/shade = noggin?.get_rendered_hair_color(facial) || COLOR_BLACK
	// More of the same hair falling on a tile grows the pile that's already
	// there rather than stacking a second one on top of it.
	for(var/obj/effect/decal/cleanable/hair/pile in target_turf)
		if(QDELETED(pile) || pile.trimming_color != shade)
			continue
		pile.grow_to(pile_size)
		return pile
	return new /obj/effect/decal/cleanable/hair(target_turf, null, shade, pile_size, shape)

/obj/effect/decal/cleanable/hair
	name = "hair cuttings"
	icon = 'modular_nova/modules/GAGS/icons/hair_trimmings.dmi'
	icon_state = "wisp_1"
	/// Shapes a pile falls in when nothing has asked for a particular one.
	/// The sheet also holds snip, clump and sweep; they're left out of the
	/// random pool on purpose rather than deleted.
	var/static/list/trimming_shapes = list("wisp", "tangle", "arc", "curl")
	/// The hair colour this pile was cut from, kept so piles can compare it
	/// without caring which of the two palettes they happened to roll.
	var/trimming_color = COLOR_BLACK
	/// The shape this pile fell in, held so it keeps it as the pile grows.
	var/trimming_shape
	/// How big the pile is now, 1 to 3.
	var/pile_size = 1

/obj/effect/decal/cleanable/hair/Initialize(mapload, list/datum/disease/diseases, hair_color, pile_size = 2, shape)
	// All of this has to happen before the parent call: /atom/Initialize is what
	// hands the config to SSgreyscale, and it only reads these once.
	trimming_shape = shape || pick(trimming_shapes)
	src.pile_size = clamp(round(pile_size), 1, 3)
	icon_state = "[trimming_shape]_[src.pile_size]"
	base_icon_state = icon_state
	trimming_color = hair_color || COLOR_BLACK
	// Half of all piles catch the light, so a salon floor doesn't end up looking
	// uniform. The sheen config lays a highlight over the frontmost strands.
	if(prob(50))
		greyscale_config = /datum/greyscale_config/hair_trimmings/sheen
		greyscale_colors = "[trimming_color][BlendRGB(trimming_color, COLOR_WHITE, HAIR_TRIMMING_SHEEN_LIFT)]"
	else
		greyscale_config = /datum/greyscale_config/hair_trimmings
		greyscale_colors = trimming_color
	return ..()

/**
 * Grows the pile a step, keeping the shape it fell in.
 *
 * The GAGS icon holds every size, so swapping icon_state is enough - no need
 * to regenerate anything. Returns TRUE only if the pile actually got bigger.
 */
/obj/effect/decal/cleanable/hair/proc/grow_to(new_size)
	new_size = clamp(round(new_size), 1, 3)
	if(new_size <= pile_size)
		return FALSE
	pile_size = new_size
	icon_state = "[trimming_shape]_[pile_size]"
	base_icon_state = icon_state
	return TRUE

/// Two people cut over the same tile should leave two colours of hair on it,
/// so only merge piles that came off the same head colour.
/obj/effect/decal/cleanable/hair/replace_decal(obj/effect/decal/cleanable/hair/other)
	if(other.trimming_color != trimming_color)
		return FALSE
	return ..()

#undef HAIR_TRIMMING_SHEEN_LIFT
// APHELION EDIT CHANGE END

/obj/item/razor
	name = "electric razor"
	desc = "The latest and greatest power razor born from the science of shaving."
	icon = 'modular_nova/modules/salon/icons/items.dmi'
	lefthand_file = 'modular_nova/modules/salon/icons/items_lefthand.dmi'
	righthand_file = 'modular_nova/modules/salon/icons/items_righthand.dmi'
	icon_state = "razor"
	inhand_icon_state = "razor"
	obj_flags = CONDUCTS_ELECTRICITY
	w_class = WEIGHT_CLASS_TINY
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 0.7)
	// How long do we take to shave someone's (facial) hair?
	var/shaving_time = 5 SECONDS

/obj/item/razor/suicide_act(mob/living/carbon/user)
	user.visible_message(span_suicide("[user] begins shaving [user.p_them()]self without the razor guard! It looks like [user.p_theyre()] trying to commit suicide!"))
	shave(user, BODY_ZONE_PRECISE_MOUTH)
	shave(user, BODY_ZONE_HEAD)//doesnt need to be BODY_ZONE_HEAD specifically, but whatever
	return BRUTELOSS

/obj/item/razor/proc/shave(mob/living/carbon/human/target_human, location = BODY_ZONE_PRECISE_MOUTH)
	if(location == BODY_ZONE_PRECISE_MOUTH)
		target_human.set_facial_hairstyle("Shaved", update = TRUE)
	else
		target_human.set_hairstyle("Bald", update = TRUE)

	playsound(loc, 'sound/items/unsheath.ogg', 20, TRUE)


/obj/item/razor/attack(mob/attacked_mob, mob/living/user)
	if(!ishuman(attacked_mob))
		return ..()

	var/mob/living/carbon/human/target_human = attacked_mob
	var/location = user.zone_selected
	var/obj/item/bodypart/head/noggin = target_human.get_bodypart(BODY_ZONE_HEAD)
	var/static/list/head_zones = list(BODY_ZONE_PRECISE_MOUTH, BODY_ZONE_HEAD)

	if(!noggin && (location in head_zones))
		to_chat(user, span_warning("[target_human] doesn't have a head!"))
		return

	if(!(location in head_zones) && !user.combat_mode)
		to_chat(user, span_warning("You stop, look down at what you're currently holding and ponder to yourself, \"This is probably to be used on their hair or their facial hair.\""))
		return

	if(location == BODY_ZONE_PRECISE_MOUTH)
		if(!(noggin.head_flags & HEAD_FACIAL_HAIR))
			to_chat(user, span_warning("There is no facial hair to shave!"))
			return

		var/covering = target_human.is_mouth_covered()
		if(covering)
			to_chat(user, span_warning("[covering] is in the way!"))
			return

		if(HAS_TRAIT(target_human, TRAIT_SHAVED))
			to_chat(user, span_warning("[target_human] is just way too shaved. Like, really really shaved."))
			return

		if(target_human.facial_hairstyle == "Shaved")
			to_chat(user, span_warning("Already clean-shaven!"))
			return

		var/self_shaving = target_human == user // Shaving yourself?
		user.visible_message(span_notice("[user] starts to shave [self_shaving ? user.p_their() : "[target_human]'s"] hair with [src]."), \
			span_notice("You take a moment to shave [self_shaving ? "your" : "[target_human]'s" ] hair with [src]..."))

		if(do_after(user, shaving_time, target = target_human))
			user.visible_message(span_notice("[user] shaves [self_shaving ? user.p_their() : "[target_human]'s"] hair clean with [src]."), \
				span_notice("You finish shaving [self_shaving ? "your" : " [target_human]'s"] hair with [src]. Fast and clean!"))

			shave(target_human, location)

	else if(location == BODY_ZONE_HEAD)
		if(!(noggin.head_flags & HEAD_HAIR))
			to_chat(user, span_warning("There is no hair to shave!"))
			return

		if(!target_human.is_location_accessible(location))
			to_chat(user, span_warning("The headgear is in the way!"))
			return

		if(target_human.hairstyle == "Bald" || target_human.hairstyle == "Balding Hair" || target_human.hairstyle == "Skinhead")
			to_chat(user, span_warning("There is not enough hair left to shave!"))
			return

		if(HAS_TRAIT(target_human, TRAIT_SHAVED))
			to_chat(user, span_warning("[target_human] is just way too shaved. Like, really really shaved."))
			return

		var/self_shaving = target_human == user // Shaving yourself?
		user.visible_message(span_notice("[user] starts to shave [self_shaving ? user.p_their() : "[target_human]'s"] hair with [src]."), \
			span_notice("You take a moment to shave [self_shaving ? "your" : "[target_human]'s" ] hair with [src]..."))

		if(do_after(user, shaving_time, target = target_human))
			user.visible_message(span_notice("[user] shaves [self_shaving ? user.p_their() : "[target_human]'s"] hair clean with [src]."), \
				span_notice("You finish shaving [self_shaving ? "your" : " [target_human]'s"] hair with [src]. Fast and clean!"))

			shave(target_human, location)

		return

	return ..()

/obj/structure/sign/barber
	name = "barbershop sign"
	desc = "A glowing red-blue-white stripe you won't mistake for any other!"
	icon = 'modular_nova/modules/salon/icons/items.dmi'
	icon_state = "barber"
	buildable_sign = FALSE // Don't want them removed, they look too jank.

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/sign/barber, 13)

/obj/structure/sign/barber/Initialize(mapload)
	. = ..()
	if(mapload)
		find_and_mount_on_atom()

/obj/structure/sign/barber/get_turfs_to_mount_on()
	return list(get_step(src, dir))

/obj/item/storage/box/perfume
	name = "box of perfumes"

/obj/item/storage/box/perfume/PopulateContents()
	new /obj/item/perfume/cologne(src)
	new /obj/item/perfume/wood(src)
	new /obj/item/perfume/rose(src)
	new /obj/item/perfume/jasmine(src)
	new /obj/item/perfume/mint(src)
	new /obj/item/perfume/vanilla(src)
	new /obj/item/perfume/pear(src)
	new /obj/item/perfume/strawberry(src)
	new /obj/item/perfume/cherry(src)
	new /obj/item/perfume/amber(src)
