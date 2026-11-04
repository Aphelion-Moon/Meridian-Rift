/datum/reagent/consumable/nutriment/soup/welsh_cawl
	name = "Welsh Cawl"
	description = "A slow-simmered broth of lamb, leek, potato and swede. New Wales' national dish, and better the day after."
	data = list("lamb broth" = 1, "leek" = 1, "root vegetables" = 1)
	glass_price = FOOD_PRICE_NORMAL
	color = "#B07C26"

/datum/glass_style/has_foodtype/soup/welsh_cawl
	required_drink_type = /datum/reagent/consumable/nutriment/soup/welsh_cawl
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "welsh_cawl_plate"
	drink_type = MEAT | VEGETABLES

/datum/chemical_reaction/food/soup/welsh_cawl
	required_reagents = list(/datum/reagent/water = 50)
	required_ingredients = list(
		/obj/item/food/meat/cutlet = 2,
		/obj/item/food/grown/potato = 1,
		/obj/item/food/grown/carrotlike/carrot = 1,
		/obj/item/food/grown/onion = 1,
		/obj/item/food/grown/whitebeet = 1,
	)
	results = list(
		/datum/reagent/consumable/nutriment/soup/welsh_cawl = 30,
		/datum/reagent/water = 10,
	)
