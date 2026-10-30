/obj/item/food/hunters_chicken
	name = "hunter's chicken"
	desc = "A chicken breast wrapped in bacon, smothered in barbecue sauce and melted cheese. A pub menu staple."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "hunters_chicken"
	food_reagents = list(
		/datum/reagent/consumable/nutriment/protein = 10,
		/datum/reagent/consumable/nutriment/fat = 6,
		/datum/reagent/consumable/nutriment/vitamin = 4,
		/datum/reagent/consumable/bbqsauce = 5,
	)
	tastes = list("chicken" = 3, "bacon" = 2, "barbecue sauce" = 2, "melted cheese" = 1)
	foodtypes = MEAT | DAIRY
	crafting_complexity = FOOD_COMPLEXITY_4
	custom_materials = list(/datum/material/meat = MEATSLAB_MATERIAL_AMOUNT + MEATDISH_MATERIAL_AMOUNT * 2)

/obj/item/food/beans_on_toast
	name = "beans on toast"
	desc = "Baked beans heaped on buttered toast."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "beans_on_toast"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 8,
		/datum/reagent/consumable/nutriment/protein = 8,
		/datum/reagent/consumable/nutriment/vitamin = 3,
		/datum/reagent/consumable/ketchup = 3,
	)
	tastes = list("baked beans" = 2, "buttered toast" = 1)
	foodtypes = GRAIN | DAIRY | VEGETABLES | BREAKFAST
	crafting_complexity = FOOD_COMPLEXITY_2

/obj/item/food/eton_mess
	name = "\improper Eton mess"
	desc = "Crushed meringue, whipped cream and berries in a glass."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "eton_mess_plate"
	trash_type = /obj/item/reagent_containers/cup/glass/drinkingglass
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/sugar = 4,
		/datum/reagent/consumable/nutriment/vitamin = 2,
		/datum/reagent/consumable/whipped_cream = 2,
	)
	tastes = list("meringue" = 2, "whipped cream" = 2, "berries" = 2)
	foodtypes = DAIRY | FRUIT | SUGAR
	crafting_complexity = FOOD_COMPLEXITY_4

/obj/item/food/scones
	name = "scones with jam and cream"
	desc = "Two split scones loaded with jam and clotted cream."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "scones"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 10,
		/datum/reagent/consumable/sugar = 4,
		/datum/reagent/consumable/nutriment/vitamin = 2,
	)
	tastes = list("scone" = 2, "jam" = 1, "clotted cream" = 1)
	foodtypes = GRAIN | DAIRY | FRUIT | SUGAR
	food_flags = FOOD_FINGER_FOOD
	crafting_complexity = FOOD_COMPLEXITY_3

/obj/item/food/sticky_toffee_pudding
	name = "sticky toffee pudding"
	desc = "A moist date sponge drowned in hot toffee sauce."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "sticky_toffee_pudding"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 8,
		/datum/reagent/consumable/sugar = 6,
		/datum/reagent/consumable/caramel = 4,
		/datum/reagent/consumable/nutriment/vitamin = 1,
	)
	tastes = list("sponge cake" = 2, "toffee" = 2, "dates" = 1)
	foodtypes = GRAIN | DAIRY | SUGAR | FRUIT
	crafting_complexity = FOOD_COMPLEXITY_4

/obj/item/food/deep_fried_mars_bar
	name = "deep fried Mars bar"
	desc = "Battered, deep fried and molten in the middle, each one closes an artery a little further."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "deep_fried_mars_bar"
	bite_consumption = 4
	// The same reagents crafting gives it: the chocolate bar's, the caramel and batter, and the fat from on_craft_completion().
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 2,
		/datum/reagent/consumable/sugar = 2,
		/datum/reagent/consumable/coco = 2,
		/datum/reagent/consumable/caramel = 2,
		/datum/reagent/consumable/ethanol/beerbatter = 5,
		/datum/reagent/consumable/nutriment/fat/saturated = 4,
	)
	tastes = list("chocolate" = 2, "caramel" = 1, "batter" = 1)
	foodtypes = JUNKFOOD | SUGAR | FRIED
	crafting_complexity = FOOD_COMPLEXITY_3

// Crafting replaces the declared reagents with the ingredients', which have no saturated fat.
/obj/item/food/deep_fried_mars_bar/on_craft_completion(list/components, datum/crafting_recipe/current_recipe, atom/crafter)
	. = ..()
	reagents.add_reagent(/datum/reagent/consumable/nutriment/fat/saturated, food_reagents[/datum/reagent/consumable/nutriment/fat/saturated])
