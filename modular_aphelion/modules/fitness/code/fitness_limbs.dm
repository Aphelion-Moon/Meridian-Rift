/obj/item/bodypart
	/**
	 * How big this limb's muscles are drawn, a MUSCLE_SIZE_* define: MUSCLE_SIZE_NORMAL is today's sprites. Fixed by its type:
	 * each size of a limb is its own subtype, below. Clothing and underwear fitting read it per limb, so each arm and leg can
	 * differ.
	 */
	var/muscle_size = MUSCLE_SIZE_NORMAL
	/**
	 * How defined a fitness limb's muscles are drawn, from 0, none, to MUSCLE_DEFINITION_MAX: an overlay on the limb, under its
	 * markings. Null until the limb is first set up for an owner (update_limb()'s is_creating), when it takes the definition in
	 * the owner's DNA, then kept wherever the limb goes. Only fitness limbs read it.
	 */
	var/muscle_definition

#define FITNESS_SHEET_HUMAN_ATHLETIC 'modular_aphelion/modules/fitness/icons/human_parts_athletic.dmi'
#define FITNESS_SHEET_HUMAN_MUSCULAR 'modular_aphelion/modules/fitness/icons/human_parts_muscular.dmi'
#define FITNESS_SHEET_HUMANOID_ATHLETIC 'modular_aphelion/modules/fitness/icons/humanoid_parts_athletic.dmi'
#define FITNESS_SHEET_HUMANOID_MUSCULAR 'modular_aphelion/modules/fitness/icons/humanoid_parts_muscular.dmi'
#define FITNESS_DEFINITION_HUMAN 'modular_aphelion/modules/fitness/icons/human_definition.dmi'
#define FITNESS_DEFINITION_HUMANOID 'modular_aphelion/modules/fitness/icons/humanoid_definition.dmi'

/**
 * Every limb type with fitness subtypes, and each of those subtypes -> its family: the base type, which is Normal-sized with
 * no definition; the type drawn Normal-sized with a definition, the family's own fitness type, or the base type again for a
 * family that draws none, like the digitigrade legs; then the Athletic and Muscular subtypes. Read it through
 * FITNESS_LIMB_TYPE().
 *
 * Built from the size subtypes, which are all named base/fitness/<size>.
 */
GLOBAL_LIST_INIT(fitness_limb_families, init_fitness_limb_families())

/**
 * Returns GLOB.fitness_limb_families, built from the size subtypes.
 */
/proc/init_fitness_limb_families()
	. = list()
	for(var/obj/item/bodypart/fitness_type as anything in subtypesof(/obj/item/bodypart))
		var/size = fitness_type::muscle_size
		if(!size)
			continue
		var/obj/item/bodypart/group = fitness_type::parent_type
		var/obj/item/bodypart/base_type = group::parent_type
		var/list/family = .[base_type]
		if(!family)
			var/defined_type = group::abstract_type == group ? base_type : group
			family = list(base_type, defined_type, null, null)
			.[base_type] = family
			.[defined_type] = family
		family[size + 2] = fitness_type
		.[fitness_type] = family

/**
 * The plain sheets fitness limbs are drawn from -> their size sheets, Athletic then Muscular. See fitness_sheet().
 *
 * A human's digitigrade legs are the mammal ones, so their size art goes in the human size sheets, under the mammal states.
 * Skin tones off turn a human's limbs to the humanoid sheet, whose size sheets they then draw.
 */
GLOBAL_LIST_INIT(fitness_limb_sheets, init_fitness_limb_sheets())

/**
 * Returns GLOB.fitness_limb_sheets. Sheets are files, so it is built here rather than written as a list literal.
 */
/proc/init_fitness_limb_sheets()
	var/list/human = list(FITNESS_SHEET_HUMAN_ATHLETIC, FITNESS_SHEET_HUMAN_MUSCULAR)
	var/list/humanoid = list(FITNESS_SHEET_HUMANOID_ATHLETIC, FITNESS_SHEET_HUMANOID_MUSCULAR)
	. = list()
	.[BODYPART_ICON_HUMAN] = human
	.[BODYPART_ICON_MAMMAL] = human
	.[BODYPART_ICON_HUMANOID] = humanoid

/**
 * Every sheet a fitness limb draws its definition over, plain or size -> the definition overlays drawn on it. See
 * draw_muscle_definition().
 */
GLOBAL_LIST_INIT(fitness_definition_sheets, init_fitness_definition_sheets())

/**
 * Returns GLOB.fitness_definition_sheets.
 */
/proc/init_fitness_definition_sheets()
	. = list()
	for(var/sheet in list(BODYPART_ICON_HUMAN, FITNESS_SHEET_HUMAN_ATHLETIC, FITNESS_SHEET_HUMAN_MUSCULAR))
		.[sheet] = FITNESS_DEFINITION_HUMAN
	for(var/sheet in list(BODYPART_ICON_HUMANOID, FITNESS_SHEET_HUMANOID_ATHLETIC, FITNESS_SHEET_HUMANOID_MUSCULAR))
		.[sheet] = FITNESS_DEFINITION_HUMANOID

/**
 * Returns the sheet this limb draws in place of `sheet`: its muscle size's sheet when `sheet` has size sheets and that one
 * holds the state the limb draws, else `sheet` itself. Only asked for a limb above the Normal size.
 *
 * The size sheets hold every plain limb's states and the digitigrade legs'. A state a size's sheet lacks keeps the limb
 * drawing today's sprite from its own sheet, never a missing state.
 *
 * Arguments:
 * - sheet: The greyscale sheet the limb would otherwise draw from.
 */
/obj/item/bodypart/proc/fitness_sheet(sheet)
	var/size_sheet = GLOB.fitness_limb_sheets[sheet]?[muscle_size]
	return (size_sheet && icon_exists(size_sheet, custom_sprite_limb_state(src))) ? size_sheet : sheet

/// The name a muscle size goes by in the definition overlays' states.
#define MUSCLE_SIZE_NAME(size) (size == MUSCLE_SIZE_MUSCULAR ? "muscular" : size == MUSCLE_SIZE_ATHLETIC ? "athletic" : "normal")

/**
 * Draws this limb's muscle definition into the images get_limb_icon() made: the definition overlay for the state the limb
 * draws, its size and its step, right above the limb's own image, both halves of a leg's, and so under its markings and
 * everything else on it. It's a copy of the limb's image drawing the overlay, so it's coloured, offset for height and textured
 * as the limb is, and a husk's is toned as the limb is.
 *
 * No icon is made for it: the overlay is its sheet's own state, the leg halves come from the masked leg cache
 * (handle_masking()) and a husk's tone from husk_toned_sheet().
 *
 * Nothing is drawn where the definition sheet has no state for what the limb draws: hands, digitigrade legs, and a limb drawn
 * from another sheet, like another species' look. Nor is anything drawn for a limb get_limb_icon() draws none of, like a
 * taur's hidden legs, nor an invisible one.
 *
 * Arguments:
 * - images: get_limb_icon()'s images, the limb's own first. Changed in place.
 * - dropped: Whether they're drawn for the limb lying on its own, which isn't split into leg halves.
 */
/obj/item/bodypart/proc/draw_muscle_definition(list/images, dropped)
	var/definition_sheet = GLOB.fitness_definition_sheets[icon_greyscale]
	if(!should_draw_greyscale || !definition_sheet || !length(images))
		return
	var/state = custom_sprite_limb_state(src)
	var/definition_state = "[state]_[MUSCLE_SIZE_NAME(muscle_size)]_[muscle_definition]"
	var/image/limb = images[1]
	if(limb.icon_state != state || !icon_exists(definition_sheet, definition_state))
		return
	if(is_husked)
		definition_sheet = husk_toned_sheet(definition_sheet)
	var/list/halves = dropped ? null : handle_masking(image(definition_sheet, definition_state))
	if(!halves)
		var/image/definition = new(limb)
		definition.icon = definition_sheet
		definition.icon_state = definition_state
		images.Insert(2, definition)
		return
	for(var/half in 1 to 2)
		var/image/limb_half = images[half]
		var/image/masked_half = halves[half]
		var/image/definition = new(limb_half)
		definition.icon = masked_half.icon
		definition.icon_state = definition_state
		images.Insert(2 + half, definition)

/**
 * A fitness limb's icon cache key, written out for the sizes and steps there are so a redraw doesn't build the text.
 */
#define FITNESS_ICON_KEY(size, definition) (size == MUSCLE_SIZE_MUSCULAR ? (definition == 3 ? "muscular_3" : definition == 2 ? "muscular_2" : definition == 1 ? "muscular_1" : "muscular") \
	: size == MUSCLE_SIZE_ATHLETIC ? (definition == 3 ? "athletic_3" : definition == 2 ? "athletic_2" : definition == 1 ? "athletic_1" : "athletic") \
	: (definition == 3 ? "normal_3" : definition == 2 ? "normal_2" : definition == 1 ? "normal_1" : "normal"))

/**
 * Gives a limb family's fitness subtypes (`family`/fitness and its sizes) the overrides they draw with. They sit on the fitness
 * subtypes rather than on /obj/item/bodypart, so a plain limb's redraw runs none of them.
 *
 * - update_limb() keeps the limb on its size's art whatever sheet it was last given: its type's own, the humanoid one skin
 *   tones off give it, or a reset's. A body's redraw runs it on each limb before making the limb's icon cache key. Only a
 *   plain sheet that has size sheets is looked up again; a limb already on its size's sheet keeps it. Set up for an owner
 *   (is_creating), a new limb takes the owner's definition, and a chest, whose male or female art is set then, refits its
 *   owner's garments to its glutes (update_garment_fit()).
 * - generate_icon_key() and generate_husk_key() key the limb by its size and definition: the size sheets share the plain
 *   sheets' state names, and the limb icon cache is shared by every body, so without it one's art would be served for another.
 * - get_limb_icon() draws the definition (draw_muscle_definition()).
 *
 * Arguments:
 * - family: The limb type the fitness subtypes are under, like /obj/item/bodypart/arm/left.
 */
#define FITNESS_LIMB_DRAWING(family) \
family/fitness/update_limb(dropping_limb = FALSE, is_creating = FALSE) { \
	. = ..(); \
	if(should_draw_greyscale && GLOB.fitness_limb_sheets[icon_greyscale] && muscle_size) { \
		icon_greyscale = fitness_sheet(icon_greyscale); \
	} \
	if(!.) { \
		return; \
	} \
	if(isnull(muscle_definition)) { \
		muscle_definition = owner.dna?.features[FEATURE_MUSCLE_DEFINITION] || 0; \
	} \
	if(body_zone == BODY_ZONE_CHEST && ishuman(owner)) { \
		var/mob/living/carbon/human/body = owner; \
		body.update_garment_fit(); \
	} \
} \
family/fitness/generate_icon_key() { \
	. = ..(); \
	. += FITNESS_ICON_KEY(muscle_size, muscle_definition); \
} \
family/fitness/generate_husk_key() { \
	. = ..(); \
	. += FITNESS_ICON_KEY(muscle_size, muscle_definition); \
} \
family/fitness/get_limb_icon(dropped) { \
	. = ..(); \
	if(muscle_definition) { \
		draw_muscle_definition(., dropped); \
	} \
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

// Each limb drawn from the human or humanoid sheet, and each digitigrade leg those limbs turn into, has a fitness type, drawn
// at the Normal size with a definition, and a subtype of it for each bigger size. The digitigrade legs draw no definition, so
// theirs is only the sizes' parent. A subtype differs from its base only in the art it draws.
/obj/item/bodypart/chest/fitness

/obj/item/bodypart/chest/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMAN_ATHLETIC

/obj/item/bodypart/chest/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMAN_MUSCULAR

/obj/item/bodypart/arm/left/fitness

/obj/item/bodypart/arm/left/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMAN_ATHLETIC

/obj/item/bodypart/arm/left/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMAN_MUSCULAR

/obj/item/bodypart/arm/right/fitness

/obj/item/bodypart/arm/right/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMAN_ATHLETIC

/obj/item/bodypart/arm/right/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMAN_MUSCULAR

/obj/item/bodypart/leg/left/fitness

/obj/item/bodypart/leg/left/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMAN_ATHLETIC
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/fitness/athletic

/obj/item/bodypart/leg/left/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMAN_MUSCULAR
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/fitness/muscular

/obj/item/bodypart/leg/right/fitness

/obj/item/bodypart/leg/right/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMAN_ATHLETIC
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/fitness/athletic

/obj/item/bodypart/leg/right/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMAN_MUSCULAR
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/fitness/muscular

/obj/item/bodypart/leg/left/digitigrade/fitness
	abstract_type = /obj/item/bodypart/leg/left/digitigrade/fitness

/obj/item/bodypart/leg/left/digitigrade/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC

/obj/item/bodypart/leg/left/digitigrade/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR

/obj/item/bodypart/leg/right/digitigrade/fitness
	abstract_type = /obj/item/bodypart/leg/right/digitigrade/fitness

/obj/item/bodypart/leg/right/digitigrade/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC

/obj/item/bodypart/leg/right/digitigrade/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR

/obj/item/bodypart/chest/humanoid/fitness

/obj/item/bodypart/chest/humanoid/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMANOID_ATHLETIC

/obj/item/bodypart/chest/humanoid/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMANOID_MUSCULAR

/obj/item/bodypart/arm/left/humanoid/fitness

/obj/item/bodypart/arm/left/humanoid/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMANOID_ATHLETIC

/obj/item/bodypart/arm/left/humanoid/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMANOID_MUSCULAR

/obj/item/bodypart/arm/right/humanoid/fitness

/obj/item/bodypart/arm/right/humanoid/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMANOID_ATHLETIC

/obj/item/bodypart/arm/right/humanoid/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMANOID_MUSCULAR

/obj/item/bodypart/leg/left/humanoid/fitness

/obj/item/bodypart/leg/left/humanoid/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMANOID_ATHLETIC
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/athletic

/obj/item/bodypart/leg/left/humanoid/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMANOID_MUSCULAR
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/muscular

/obj/item/bodypart/leg/right/humanoid/fitness

/obj/item/bodypart/leg/right/humanoid/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC
	icon_greyscale = FITNESS_SHEET_HUMANOID_ATHLETIC
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/athletic

/obj/item/bodypart/leg/right/humanoid/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR
	icon_greyscale = FITNESS_SHEET_HUMANOID_MUSCULAR
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/muscular

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness
	abstract_type = /obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC

/obj/item/bodypart/leg/left/digitigrade/human/humanoid/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness
	abstract_type = /obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/athletic
	muscle_size = MUSCLE_SIZE_ATHLETIC

/obj/item/bodypart/leg/right/digitigrade/human/humanoid/fitness/muscular
	muscle_size = MUSCLE_SIZE_MUSCULAR

#undef FITNESS_ICON_KEY
#undef FITNESS_LIMB_DRAWING
#undef MUSCLE_SIZE_NAME
#undef FITNESS_SHEET_HUMAN_ATHLETIC
#undef FITNESS_SHEET_HUMAN_MUSCULAR
#undef FITNESS_SHEET_HUMANOID_ATHLETIC
#undef FITNESS_SHEET_HUMANOID_MUSCULAR
#undef FITNESS_DEFINITION_HUMAN
#undef FITNESS_DEFINITION_HUMANOID
