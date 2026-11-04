/obj/item/reagent_containers/cup/soda_cans/irn_bru
	name = "Irn-Bru"
	desc = "A luminous orange soda. Nobody has ever managed to name the flavour."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "irn_bru"
	icon_state_preview = "irn_bru"
	inhand_icon_state = "irn_bru"
	lefthand_file = 'modular_aphelion/modules/british_food/icons/british_food_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/british_food/icons/british_food_righthand.dmi'
	list_reagents = list(/datum/reagent/consumable/irn_bru = 30)
	drink_type = SUGAR
	crushed_icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	crushed_icon_state = "irn_bru_crushed"

/obj/item/reagent_containers/cup/soda_cans/dandelion_burdock
	name = "dandelion and burdock"
	desc = "A dark, fizzy root soda, sweet and herbal."
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	icon_state = "dandelion_burdock"
	icon_state_preview = "dandelion_burdock"
	inhand_icon_state = "dandelion_burdock"
	lefthand_file = 'modular_aphelion/modules/british_food/icons/british_food_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/british_food/icons/british_food_righthand.dmi'
	list_reagents = list(/datum/reagent/consumable/dandelion_burdock = 30)
	drink_type = SUGAR
	crushed_icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	crushed_icon_state = "dandelion_burdock_crushed"

/datum/reagent/consumable/irn_bru
	name = "Irn-Bru"
	description = "A luminous orange soda. Nobody has ever managed to name the flavour."
	color = "#F28C1C"
	taste_description = "hard labour and celtic heritage"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	randomized_spawns = REAGENT_SPAWN_ALL_RANDOM_SPAWNS

/datum/reagent/consumable/dandelion_burdock
	name = "Dandelion and Burdock"
	description = "A dark, fizzy root soda, sweet and herbal."
	color = "#3B2314"
	taste_description = "herbal sweetness and a spiffing proper beverage"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	randomized_spawns = REAGENT_SPAWN_ALL_RANDOM_SPAWNS
