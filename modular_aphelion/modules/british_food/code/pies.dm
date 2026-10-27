/obj/item/food/pie/steak_ale_pie
	name = "steak and ale pie"
	desc = "Chunks of beef braised in dark ale and gravy under a golden pastry lid."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "steak_ale_pie"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 12,
		/datum/reagent/consumable/nutriment/protein = 10,
		/datum/reagent/consumable/nutriment/vitamin = 5,
		/datum/reagent/consumable/nutriment/fat = 3,
	)
	tastes = list("pastry" = 1, "beef" = 2, "ale gravy" = 2)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES
	slice_type = /obj/item/food/pieslice/steak_ale_pie
	crafting_complexity = FOOD_COMPLEXITY_5
	custom_materials = list(/datum/material/meat = MEATSLAB_MATERIAL_AMOUNT * 2)

/obj/item/food/pieslice/steak_ale_pie
	name = "steak and ale pie slice"
	desc = "A slice of steak and ale pie. The gravy is already making a break for it."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "steak_ale_pie_slice"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 2.4,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/consumable/nutriment/vitamin = 1,
		/datum/reagent/consumable/nutriment/fat = 0.6,
	)
	tastes = list("pastry" = 1, "beef" = 2, "ale gravy" = 2)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES
	crafting_complexity = FOOD_COMPLEXITY_5
	custom_materials = list(/datum/material/meat = MEATSLAB_MATERIAL_AMOUNT * 2 / 5)

/obj/item/food/pie/pork_pie
	name = "pork pie"
	desc = "A hand-raised pie of seasoned pork set in savoury jelly. Best eaten cold, with mustard."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "pork_pie"
	w_class = WEIGHT_CLASS_SMALL
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/nutriment/protein = 4,
		/datum/reagent/consumable/nutriment/fat = 3,
		/datum/reagent/consumable/nutriment/vitamin = 1,
	)
	tastes = list("pastry" = 1, "pork" = 2, "savoury jelly" = 1)
	foodtypes = GRAIN | DAIRY | MEAT
	food_flags = FOOD_FINGER_FOOD
	slice_type = /obj/item/food/pieslice/pork_pie
	yield = 4
	crafting_complexity = FOOD_COMPLEXITY_4
	custom_materials = list(/datum/material/meat = MEATSLAB_MATERIAL_AMOUNT)

/obj/item/food/pieslice/pork_pie
	name = "pork pie quarter"
	desc = "A quarter of a pork pie. The jelly is load-bearing."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "pork_pie_slice"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 1,
		/datum/reagent/consumable/nutriment/protein = 1,
		/datum/reagent/consumable/nutriment/fat = 0.75,
		/datum/reagent/consumable/nutriment/vitamin = 0.25,
	)
	tastes = list("pastry" = 1, "pork" = 2, "savoury jelly" = 1)
	foodtypes = GRAIN | DAIRY | MEAT
	food_flags = FOOD_FINGER_FOOD
	crafting_complexity = FOOD_COMPLEXITY_4
	custom_materials = list(/datum/material/meat = MEATSLAB_MATERIAL_AMOUNT / 4)

/obj/item/food/pie/chicken_mushroom_pie
	name = "chicken and mushroom pie"
	desc = "A small pie of chicken and mushrooms in a thick, creamy sauce."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "chicken_mushroom_pie"
	w_class = WEIGHT_CLASS_SMALL
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 5,
		/datum/reagent/consumable/nutriment/protein = 3,
		/datum/reagent/consumable/nutriment/vitamin = 2,
		/datum/reagent/consumable/nutriment/fat = 2,
	)
	tastes = list("pastry" = 1, "chicken" = 2, "mushroom" = 1, "cream" = 1)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES
	food_flags = FOOD_FINGER_FOOD
	slice_type = /obj/item/food/pieslice/chicken_mushroom_pie
	yield = 4
	crafting_complexity = FOOD_COMPLEXITY_4
	custom_materials = list(/datum/material/meat = MEATDISH_MATERIAL_AMOUNT)

/obj/item/food/pieslice/chicken_mushroom_pie
	name = "chicken and mushroom pie quarter"
	desc = "A quarter of a chicken and mushroom pie, creamy filling and all."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "chicken_mushroom_pie_slice"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 1.25,
		/datum/reagent/consumable/nutriment/protein = 0.75,
		/datum/reagent/consumable/nutriment/vitamin = 0.5,
		/datum/reagent/consumable/nutriment/fat = 0.5,
	)
	tastes = list("pastry" = 1, "chicken" = 2, "mushroom" = 1, "cream" = 1)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES
	food_flags = FOOD_FINGER_FOOD
	crafting_complexity = FOOD_COMPLEXITY_4
	custom_materials = list(/datum/material/meat = MEATDISH_MATERIAL_AMOUNT / 4)

/obj/item/food/cornish_pasty
	name = "\improper Cornish pasty"
	desc = "Beef, potato, swede and onion baked in a crimped pastry case."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "cornish_pasty"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 6,
		/datum/reagent/consumable/nutriment/protein = 3,
		/datum/reagent/consumable/nutriment/vitamin = 3,
		/datum/reagent/consumable/nutriment/fat = 1,
	)
	tastes = list("pastry" = 2, "beef" = 1, "potato" = 1, "swede" = 1)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES
	food_flags = FOOD_FINGER_FOOD
	crafting_complexity = FOOD_COMPLEXITY_4
	custom_materials = list(/datum/material/meat = MEATDISH_MATERIAL_AMOUNT)

/obj/item/food/cheesy_bean_melt
	name = "sausage, bean and cheese melt"
	desc = "Sausage, baked beans and molten cheese sealed in the sacred flaky puff pastry."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "cheesy_bean_melt"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 7,
		/datum/reagent/consumable/nutriment/protein = 10,
		/datum/reagent/consumable/nutriment/fat = 3,
		/datum/reagent/consumable/nutriment/vitamin = 2,
		/datum/reagent/consumable/ketchup = 3,
	)
	tastes = list("puff pastry" = 2, "sausage" = 1, "baked beans" = 1, "molten cheese" = 1)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES
	food_flags = FOOD_FINGER_FOOD
	crafting_complexity = FOOD_COMPLEXITY_4
	custom_materials = list(/datum/material/meat = MEATSLAB_MATERIAL_AMOUNT)

/obj/item/food/cheesy_bean_melt/make_edible()
	. = ..()
	AddComponentFrom(SOURCE_EDIBLE_INNATE, /datum/component/edible, after_eat = CALLBACK(src, PROC_REF(show_bite)))

/// Swaps in the bitten sprite once someone has had a go at it.
/obj/item/food/cheesy_bean_melt/proc/show_bite(mob/living/eater, mob/living/feeder, bitecount)
	icon_state = "cheesy_bean_melt_bitten"
