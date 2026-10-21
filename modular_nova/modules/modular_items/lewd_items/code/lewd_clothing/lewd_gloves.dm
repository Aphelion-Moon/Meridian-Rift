/obj/item/clothing/gloves/ball_mittens
	name = "ball mittens"
	desc = "A pair of spherical mitts; made to suppress the wearer's hands and prevent fine motor control."
	worn_icon = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_gloves.dmi'
	greyscale_colors = "#383840"
	icon = 'icons/map_icons/clothing/_clothing.dmi'
	icon_state = "/obj/item/clothing/gloves/ball_mittens"
	post_init_icon_state = "ball_mittens"
	greyscale_config = /datum/greyscale_config/ball_mittens
	greyscale_config_worn = /datum/greyscale_config/ball_mittens/worn
	flags_1 = IS_PLAYER_COLORABLE_1
	obj_flags_nova = ERP_ITEM
	breakouttime = 1 SECONDS
	resist_cooldown = CLICK_CD_SLOW

/// Reinforce the breakout time on this, if that's your thing
/obj/item/clothing/gloves/ball_mittens/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	. = ..()
	if(.)
		return
	if(!istype(tool, /obj/item/restraints/handcuffs) || !initial(breakouttime))
		return
	to_chat(user, span_notice("You reinforce the belts on [src] with [tool]."))
	name = "reinforced [initial(name)]"
	ADD_TRAIT(src, TRAIT_DANGEROUS_EQUIP, INNATE_TRAIT)
	breakouttime = 100 SECONDS
	qdel(tool)
	return ITEM_INTERACT_SUCCESS

/obj/item/clothing/gloves/ball_mittens/examine(mob/user)
	. = ..()
	if(breakouttime == initial(breakouttime))
		. += span_notice("You could probably reinforce it with a pair of [span_bold("handcuffs")]...")

/// Ball mittens shaped like paws. Wearing them gives the paw mood.
/obj/item/clothing/gloves/ball_mittens/paw_mittens
	name = "paw mittens"
	desc = "Mittens that compress the hand into a tight space, and restrict fine motor control."
	greyscale_colors = "#383840#dc7ef4"
	icon = 'icons/map_icons/clothing/_clothing.dmi'
	icon_state = "/obj/item/clothing/gloves/ball_mittens/paw_mittens"
	post_init_icon_state = "paw_mittens"
	greyscale_config = /datum/greyscale_config/paw_mittens
	greyscale_config_worn = /datum/greyscale_config/paw_mittens/worn

/// Gives the paw mood while worn as gloves. Keyed to the pair, so dropping a held pair doesn't clear a worn one's.
/obj/item/clothing/gloves/ball_mittens/paw_mittens/equipped(mob/living/user, slot)
	. = ..()
	if(slot & ITEM_SLOT_GLOVES)
		user.add_mood_event(REF(src), /datum/mood_event/paw_mittens)

/obj/item/clothing/gloves/ball_mittens/paw_mittens/dropped(mob/living/user)
	. = ..()
	if(isliving(user))
		user.clear_mood_event(REF(src))

/datum/mood_event/paw_mittens
	description = span_purple("So-ft... Ro-und... Use-less... Lo-ve it!")

/// Bigger, rounder paw mittens with toe beans and a cuff tag.
/obj/item/clothing/gloves/ball_mittens/paw_mittens/cat_paws
	name = "cat paws"
	desc = "A pair of inflatable latex mittens shaped like rounded paws. Helpless AND humiliating."
	greyscale_colors = "#242329#7b48a6#15b1bf"
	icon_state = "/obj/item/clothing/gloves/ball_mittens/paw_mittens/cat_paws"
	post_init_icon_state = "cat_paws"
	greyscale_config = /datum/greyscale_config/cat_paws
	greyscale_config_worn = /datum/greyscale_config/cat_paws/worn


/// Long (Formerly Latex) Gloves
/obj/item/clothing/gloves/long_gloves
	name = "long gloves"
	desc = "Sleek gloves that go up towards the shoulder."
	w_class = WEIGHT_CLASS_SMALL
	worn_icon = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_gloves.dmi'
	greyscale_colors = "#383840"
	icon = 'icons/map_icons/clothing/_clothing.dmi'
	icon_state = "/obj/item/clothing/gloves/long_gloves"
	post_init_icon_state = "long_gloves"
	greyscale_config = /datum/greyscale_config/long_gloves
	greyscale_config_worn = /datum/greyscale_config/long_gloves/worn
	flags_1 = IS_PLAYER_COLORABLE_1
