/obj/item/bodypart
	/**
	 * How built this limb is drawn, from FITNESS_LEVEL_BASELINE (today's sprites) to FITNESS_LEVEL_MAX. Fixed by its type: each
	 * level of a limb is its own subtype, below. Clothing and underwear fitting read it per limb, so each arm and leg can differ.
	 */
	var/fitness_level = FITNESS_LEVEL_BASELINE

#define FITNESS_SHEET_HUMAN_1 'modular_aphelion/modules/fitness/icons/human_parts_fitness_1.dmi'
#define FITNESS_SHEET_HUMAN_2 'modular_aphelion/modules/fitness/icons/human_parts_fitness_2.dmi'
#define FITNESS_SHEET_HUMAN_3 'modular_aphelion/modules/fitness/icons/human_parts_fitness_3.dmi'
#define FITNESS_SHEET_HUMAN_4 'modular_aphelion/modules/fitness/icons/human_parts_fitness_4.dmi'
#define FITNESS_SHEET_HUMAN_5 'modular_aphelion/modules/fitness/icons/human_parts_fitness_5.dmi'
#define FITNESS_SHEET_HUMANOID_1 'modular_aphelion/modules/fitness/icons/humanoid_parts_fitness_1.dmi'
#define FITNESS_SHEET_HUMANOID_2 'modular_aphelion/modules/fitness/icons/humanoid_parts_fitness_2.dmi'
#define FITNESS_SHEET_HUMANOID_3 'modular_aphelion/modules/fitness/icons/humanoid_parts_fitness_3.dmi'
#define FITNESS_SHEET_HUMANOID_4 'modular_aphelion/modules/fitness/icons/humanoid_parts_fitness_4.dmi'
#define FITNESS_SHEET_HUMANOID_5 'modular_aphelion/modules/fitness/icons/humanoid_parts_fitness_5.dmi'

/**
 * Every limb type with fitness subtypes, and each of those subtypes -> its family: the base type, then its subtypes in level
 * order, so the family's type for a level is family[level + 1]. Read it through FITNESS_LIMB_TYPE().
 *
 * Built from the subtypes, which are all named base/fitness/level_N.
 */
GLOBAL_LIST_INIT(fitness_limb_families, init_fitness_limb_families())

/**
 * Returns GLOB.fitness_limb_families, built from the fitness subtypes.
 */
/proc/init_fitness_limb_families()
	. = list()
	for(var/obj/item/bodypart/fitness_type as anything in subtypesof(/obj/item/bodypart))
		var/level = fitness_type::fitness_level
		if(!level)
			continue
		var/obj/item/bodypart/group = fitness_type::parent_type
		var/obj/item/bodypart/base_type = group::parent_type
		var/list/family = .[base_type]
		if(!family)
			family = new /list(FITNESS_LEVEL_MAX + 1)
			family[1] = base_type
			.[base_type] = family
		family[level + 1] = fitness_type
		.[fitness_type] = family

/**
 * The plain sheets fitness limbs are drawn from -> their fitness sheets, in level order. See fitness_sheet().
 *
 * A human's digitigrade legs are the mammal ones, so their fitness art goes in the human fitness sheets, under the mammal
 * states. Skin tones off turn a human's limbs to the humanoid sheet, whose fitness sheets they then draw.
 */
GLOBAL_LIST_INIT(fitness_limb_sheets, init_fitness_limb_sheets())

/**
 * Returns GLOB.fitness_limb_sheets. Sheets are files, so it is built here rather than written as a list literal.
 */
/proc/init_fitness_limb_sheets()
	var/list/human = list(FITNESS_SHEET_HUMAN_1, FITNESS_SHEET_HUMAN_2, FITNESS_SHEET_HUMAN_3, FITNESS_SHEET_HUMAN_4, FITNESS_SHEET_HUMAN_5)
	var/list/humanoid = list(FITNESS_SHEET_HUMANOID_1, FITNESS_SHEET_HUMANOID_2, FITNESS_SHEET_HUMANOID_3, FITNESS_SHEET_HUMANOID_4, FITNESS_SHEET_HUMANOID_5)
	. = list()
	.[BODYPART_ICON_HUMAN] = human
	.[BODYPART_ICON_MAMMAL] = human
	.[BODYPART_ICON_HUMANOID] = humanoid

/**
 * Returns the sheet this limb draws in place of `sheet`: its fitness level's sheet when `sheet` has fitness sheets and that one
 * holds the state the limb draws, else `sheet` itself.
 *
 * The fitness sheets hold every plain limb's states and the digitigrade legs'. A state a level's sheet lacks keeps the limb
 * drawing today's sprite from its own sheet, never a missing state.
 *
 * Arguments:
 * - sheet: The greyscale sheet the limb would otherwise draw from.
 */
/obj/item/bodypart/proc/fitness_sheet(sheet)
	var/level_sheet = GLOB.fitness_limb_sheets[sheet]?[fitness_level]
	return (level_sheet && icon_exists(level_sheet, custom_sprite_limb_state(src))) ? level_sheet : sheet

/**
 * A fitness level's limb icon cache key, written out for the levels there are so a redraw doesn't build the text.
 */
#define FITNESS_ICON_KEY(level) (level == 1 ? "fitness_1" : level == 2 ? "fitness_2" : level == 3 ? "fitness_3" : level == 4 ? "fitness_4" : level == 5 ? "fitness_5" : "fitness_[level]")

/**
 * Gives a limb family's fitness subtypes (`family`/fitness/level_N) the overrides they draw with. They sit on the fitness
 * subtypes rather than on /obj/item/bodypart, so a plain limb's redraw runs none of them.
 *
 * - update_limb() keeps the limb on its level's art whatever sheet it was last given: its type's own, the humanoid one skin
 *   tones off give it, or a reset's. A body's redraw runs it on each limb before making the limb's icon cache key. Only a
 *   plain sheet that has fitness sheets is looked up again; a limb already on its level's sheet keeps it.
 * - generate_icon_key() and generate_husk_key() key the limb by its level: the fitness sheets share the plain sheets' state
 *   names, and the limb icon cache is shared by every body, so without it a level's art and today's would be served for each
 *   other. A husk is toned from the sheet the limb draws.
 *
 * Arguments:
 * - family: The limb type the fitness subtypes are under, like /obj/item/bodypart/arm/left.
 */
#define FITNESS_LIMB_DRAWING(family) \
family/fitness/update_limb(dropping_limb = FALSE, is_creating = FALSE) { \
	. = ..(); \
	if(should_draw_greyscale && GLOB.fitness_limb_sheets[icon_greyscale]) { \
		icon_greyscale = fitness_sheet(icon_greyscale); \
	} \
} \
family/fitness/generate_icon_key() { \
	. = ..(); \
	. += FITNESS_ICON_KEY(fitness_level); \
} \
family/fitness/generate_husk_key() { \
	. = ..(); \
	. += FITNESS_ICON_KEY(fitness_level); \
}

FITNESS_LIMB_DRAWING(/obj/item/bodypart/chest)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/arm/left)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/arm/right)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/leg/left)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/leg/right)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/leg/left/digitigrade)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/leg/right/digitigrade)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/chest/humanoid)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/arm/left/humanoid)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/arm/right/humanoid)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/leg/left/humanoid)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/leg/right/humanoid)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/leg/left/digitigrade/human/humanoid)
FITNESS_LIMB_DRAWING(/obj/item/bodypart/leg/right/digitigrade/human/humanoid)

// One subtype per level of each limb drawn from the human or humanoid sheet, and of the digitigrade legs those limbs turn into.
// A subtype differs from its base only in the art it draws.
/obj/item/bodypart/chest/fitness
	abstract_type = /obj/item/bodypart/chest/fitness

/obj/item/bodypart/chest/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMAN_1

/obj/item/bodypart/chest/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMAN_2

/obj/item/bodypart/chest/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMAN_3

/obj/item/bodypart/chest/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMAN_4

/obj/item/bodypart/chest/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMAN_5

/obj/item/bodypart/arm/left/fitness
	abstract_type = /obj/item/bodypart/arm/left/fitness

/obj/item/bodypart/arm/left/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMAN_1

/obj/item/bodypart/arm/left/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMAN_2

/obj/item/bodypart/arm/left/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMAN_3

/obj/item/bodypart/arm/left/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMAN_4

/obj/item/bodypart/arm/left/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMAN_5

/obj/item/bodypart/arm/right/fitness
	abstract_type = /obj/item/bodypart/arm/right/fitness

/obj/item/bodypart/arm/right/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMAN_1

/obj/item/bodypart/arm/right/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMAN_2

/obj/item/bodypart/arm/right/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMAN_3

/obj/item/bodypart/arm/right/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMAN_4

/obj/item/bodypart/arm/right/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMAN_5

/obj/item/bodypart/leg/left/fitness
	abstract_type = /obj/item/bodypart/leg/left/fitness

/obj/item/bodypart/leg/left/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMAN_1
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/fitness/level_1

/obj/item/bodypart/leg/left/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMAN_2
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/fitness/level_2

/obj/item/bodypart/leg/left/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMAN_3
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/fitness/level_3

/obj/item/bodypart/leg/left/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMAN_4
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/fitness/level_4

/obj/item/bodypart/leg/left/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMAN_5
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/fitness/level_5

/obj/item/bodypart/leg/right/fitness
	abstract_type = /obj/item/bodypart/leg/right/fitness

/obj/item/bodypart/leg/right/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMAN_1
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/fitness/level_1

/obj/item/bodypart/leg/right/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMAN_2
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/fitness/level_2

/obj/item/bodypart/leg/right/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMAN_3
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/fitness/level_3

/obj/item/bodypart/leg/right/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMAN_4
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/fitness/level_4

/obj/item/bodypart/leg/right/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMAN_5
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/fitness/level_5

/obj/item/bodypart/leg/left/digitigrade/fitness
	abstract_type = /obj/item/bodypart/leg/left/digitigrade/fitness

/obj/item/bodypart/leg/left/digitigrade/fitness/level_1
	fitness_level = 1

/obj/item/bodypart/leg/left/digitigrade/fitness/level_2
	fitness_level = 2

/obj/item/bodypart/leg/left/digitigrade/fitness/level_3
	fitness_level = 3

/obj/item/bodypart/leg/left/digitigrade/fitness/level_4
	fitness_level = 4

/obj/item/bodypart/leg/left/digitigrade/fitness/level_5
	fitness_level = 5

/obj/item/bodypart/leg/right/digitigrade/fitness
	abstract_type = /obj/item/bodypart/leg/right/digitigrade/fitness

/obj/item/bodypart/leg/right/digitigrade/fitness/level_1
	fitness_level = 1

/obj/item/bodypart/leg/right/digitigrade/fitness/level_2
	fitness_level = 2

/obj/item/bodypart/leg/right/digitigrade/fitness/level_3
	fitness_level = 3

/obj/item/bodypart/leg/right/digitigrade/fitness/level_4
	fitness_level = 4

/obj/item/bodypart/leg/right/digitigrade/fitness/level_5
	fitness_level = 5

/obj/item/bodypart/chest/humanoid/fitness
	abstract_type = /obj/item/bodypart/chest/humanoid/fitness

/obj/item/bodypart/chest/humanoid/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMANOID_1

/obj/item/bodypart/chest/humanoid/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMANOID_2

/obj/item/bodypart/chest/humanoid/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMANOID_3

/obj/item/bodypart/chest/humanoid/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMANOID_4

/obj/item/bodypart/chest/humanoid/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMANOID_5

/obj/item/bodypart/arm/left/humanoid/fitness
	abstract_type = /obj/item/bodypart/arm/left/humanoid/fitness

/obj/item/bodypart/arm/left/humanoid/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMANOID_1

/obj/item/bodypart/arm/left/humanoid/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMANOID_2

/obj/item/bodypart/arm/left/humanoid/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMANOID_3

/obj/item/bodypart/arm/left/humanoid/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMANOID_4

/obj/item/bodypart/arm/left/humanoid/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMANOID_5

/obj/item/bodypart/arm/right/humanoid/fitness
	abstract_type = /obj/item/bodypart/arm/right/humanoid/fitness

/obj/item/bodypart/arm/right/humanoid/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMANOID_1

/obj/item/bodypart/arm/right/humanoid/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMANOID_2

/obj/item/bodypart/arm/right/humanoid/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMANOID_3

/obj/item/bodypart/arm/right/humanoid/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMANOID_4

/obj/item/bodypart/arm/right/humanoid/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMANOID_5

/obj/item/bodypart/leg/left/humanoid/fitness
	abstract_type = /obj/item/bodypart/leg/left/humanoid/fitness

/obj/item/bodypart/leg/left/humanoid/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMANOID_1
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_1

/obj/item/bodypart/leg/left/humanoid/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMANOID_2
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_2

/obj/item/bodypart/leg/left/humanoid/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMANOID_3
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_3

/obj/item/bodypart/leg/left/humanoid/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMANOID_4
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_4

/obj/item/bodypart/leg/left/humanoid/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMANOID_5
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_5

/obj/item/bodypart/leg/right/humanoid/fitness
	abstract_type = /obj/item/bodypart/leg/right/humanoid/fitness

/obj/item/bodypart/leg/right/humanoid/fitness/level_1
	fitness_level = 1
	icon_greyscale = FITNESS_SHEET_HUMANOID_1
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_1

/obj/item/bodypart/leg/right/humanoid/fitness/level_2
	fitness_level = 2
	icon_greyscale = FITNESS_SHEET_HUMANOID_2
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_2

/obj/item/bodypart/leg/right/humanoid/fitness/level_3
	fitness_level = 3
	icon_greyscale = FITNESS_SHEET_HUMANOID_3
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_3

/obj/item/bodypart/leg/right/humanoid/fitness/level_4
	fitness_level = 4
	icon_greyscale = FITNESS_SHEET_HUMANOID_4
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_4

/obj/item/bodypart/leg/right/humanoid/fitness/level_5
	fitness_level = 5
	icon_greyscale = FITNESS_SHEET_HUMANOID_5
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_5

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness
	abstract_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_1
	fitness_level = 1

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_2
	fitness_level = 2

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_3
	fitness_level = 3

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_4
	fitness_level = 4

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/level_5
	fitness_level = 5

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness
	abstract_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_1
	fitness_level = 1

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_2
	fitness_level = 2

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_3
	fitness_level = 3

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_4
	fitness_level = 4

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/level_5
	fitness_level = 5

#undef FITNESS_ICON_KEY
#undef FITNESS_LIMB_DRAWING
#undef FITNESS_SHEET_HUMAN_1
#undef FITNESS_SHEET_HUMAN_2
#undef FITNESS_SHEET_HUMAN_3
#undef FITNESS_SHEET_HUMAN_4
#undef FITNESS_SHEET_HUMAN_5
#undef FITNESS_SHEET_HUMANOID_1
#undef FITNESS_SHEET_HUMANOID_2
#undef FITNESS_SHEET_HUMANOID_3
#undef FITNESS_SHEET_HUMANOID_4
#undef FITNESS_SHEET_HUMANOID_5
