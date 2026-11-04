/datum/crafting_recipe/food/hunters_chicken
	name = "Hunter's chicken"
	reqs = list(
		/obj/item/food/meat/steak/chicken = 1,
		/obj/item/food/meat/bacon = 2,
		/obj/item/food/cheese/wedge = 1,
		/datum/reagent/consumable/bbqsauce = 5,
	)
	result = /obj/item/food/hunters_chicken
	removed_foodtypes = BREAKFAST
	dish_category = DISH_MEAT

/datum/crafting_recipe/food/steak_ale_pie
	name = "Steak and ale pie"
	reqs = list(
		/obj/item/food/pie/plain = 1,
		/obj/item/food/meat/steak/plain = 2,
		/obj/item/food/grown/onion = 1,
		/obj/item/food/grown/mushroom = 1,
		/datum/reagent/consumable/ethanol/ale = 10,
		/datum/reagent/consumable/salt = 1,
		/datum/reagent/consumable/blackpepper = 1,
	)
	result = /obj/item/food/pie/steak_ale_pie
	unit_test_spawn_extras = list(/obj/item/food/grown/mushroom/chanterelle = 1)
	dish_category = DISH_PIE

/datum/crafting_recipe/food/pork_pie
	name = "Pork pie"
	reqs = list(
		/obj/item/food/pastrybase = 1,
		/obj/item/food/meat/steak/plain/pig = 1,
		/datum/reagent/consumable/salt = 1,
		/datum/reagent/consumable/blackpepper = 1,
	)
	result = /obj/item/food/pie/pork_pie
	dish_category = DISH_PIE
	meal_category = MEAL_SNACK

/datum/crafting_recipe/food/chicken_mushroom_pie
	name = "Chicken and mushroom pie"
	reqs = list(
		/obj/item/food/pastrybase = 1,
		/obj/item/food/meat/cutlet/chicken = 1,
		/obj/item/food/grown/mushroom = 1,
		/datum/reagent/consumable/cream = 5,
	)
	result = /obj/item/food/pie/chicken_mushroom_pie
	unit_test_spawn_extras = list(/obj/item/food/grown/mushroom/chanterelle = 1)
	dish_category = DISH_PIE

/datum/crafting_recipe/food/cornish_pasty
	name = "Cornish pasty"
	reqs = list(
		/obj/item/food/pastrybase = 1,
		/obj/item/food/meat/cutlet/plain = 1,
		/obj/item/food/grown/potato = 1,
		/obj/item/food/grown/onion = 1,
		/obj/item/food/grown/whitebeet = 1,
		/datum/reagent/consumable/blackpepper = 1,
	)
	result = /obj/item/food/cornish_pasty
	dish_category = DISH_PASTRY

/datum/crafting_recipe/food/beans_on_toast
	name = "Beans on toast"
	reqs = list(
		/obj/item/food/griddle_toast = 1,
		/obj/item/food/butterslice = 1,
		/obj/item/food/canned/beans = 1,
	)
	result = /obj/item/food/beans_on_toast
	added_foodtypes = BREAKFAST
	dish_category = DISH_BREAD
	meal_category = MEAL_BREAKFAST

/datum/crafting_recipe/food/eton_mess
	name = "Eton mess"
	reqs = list(
		/obj/item/reagent_containers/cup/glass/drinkingglass = 1,
		/obj/item/food/cakeslice/pavlova = 1,
		/obj/item/food/grown/berries = 1,
		/datum/reagent/consumable/whipped_cream = 5,
	)
	result = /obj/item/food/eton_mess
	blacklist = list(/obj/item/reagent_containers/cup/glass/drinkingglass/shotglass)
	requirements_mats_blacklist = list(/obj/item/reagent_containers/cup/glass/drinkingglass)
	dish_category = DISH_CAKE
	meal_category = MEAL_DESSERT

/datum/crafting_recipe/food/scones
	name = "Scones with jam and cream"
	reqs = list(
		/obj/item/food/butterbiscuit = 2,
		/datum/reagent/consumable/cherryjelly = 5,
		/datum/reagent/consumable/cream = 5,
	)
	result = /obj/item/food/scones
	added_foodtypes = FRUIT | SUGAR
	removed_foodtypes = BREAKFAST
	dish_category = DISH_PASTRY
	meal_category = MEAL_SNACK

/datum/crafting_recipe/food/sticky_toffee_pudding
	name = "Sticky toffee pudding"
	reqs = list(
		/obj/item/food/cakeslice/plain = 1,
		/obj/item/food/no_raisin = 1,
		/datum/reagent/consumable/caramel = 5,
		/datum/reagent/consumable/cream = 5,
	)
	result = /obj/item/food/sticky_toffee_pudding
	removed_foodtypes = JUNKFOOD
	dish_category = DISH_CAKE
	meal_category = MEAL_DESSERT

/datum/crafting_recipe/food/deep_fried_mars_bar
	name = "Deep fried Mars bar"
	reqs = list(
		/obj/item/food/chocolatebar = 1,
		/datum/reagent/consumable/caramel = 2,
		/datum/reagent/consumable/ethanol/beerbatter = 5,
	)
	result = /obj/item/food/deep_fried_mars_bar
	added_foodtypes = FRIED
	dish_category = DISH_CANDY
	meal_category = MEAL_DESSERT

/datum/crafting_recipe/food/cheesy_bean_melt
	name = "Sausage, bean and cheese melt"
	reqs = list(
		/obj/item/food/pastrybase = 1,
		/obj/item/food/sausage = 1,
		/obj/item/food/canned/beans = 1,
		/obj/item/food/cheese/wedge = 1,
	)
	result = /obj/item/food/cheesy_bean_melt
	removed_foodtypes = BREAKFAST
	dish_category = DISH_PASTRY
	meal_category = MEAL_SNACK

/datum/crafting_recipe/food/reaction/soup/welsh_cawl
	reaction = /datum/chemical_reaction/food/soup/welsh_cawl
