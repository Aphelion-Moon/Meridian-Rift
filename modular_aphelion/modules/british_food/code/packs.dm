/**
 * Grab-and-go food from Mrs. Luvvit's. You can eat it straight from its container, or use it in hand to
 * take the food out, which keeps the bites already taken and leaves the empty container.
 *
 * Vendor food is junky: less nutritious than the home-cooked dish, salted or sugared, and never handmade.
 */
/obj/item/food/british_pack
	abstract_type = /obj/item/food/british_pack
	icon = 'modular_aphelion/modules/british_food/icons/british_food.dmi'
	food_flags = FOOD_IN_CONTAINER | FOOD_FINGER_FOOD
	junkiness = 10
	/// The bare food inside, or null when it is only eaten from its container
	var/obj/item/food/unwrapped_type
	/// Whether it comes out of the vendor piping hot
	var/served_hot = TRUE

/obj/item/food/british_pack/examine(mob/user)
	. = ..()
	if(unwrapped_type)
		. += span_notice("Use it in hand to take the food out.")

/obj/item/food/british_pack/attack_self(mob/user, modifiers)
	. = ..()
	if(. || !unwrapped_type)
		return
	unwrap(user)
	return TRUE

/**
 * Takes the food out of its container. The bare food keeps what is left of this pack's reagents and
 * any heat it has left, and goes to the user's hands along with the empty container.
 *
 * Arguments:
 * - user: Who is unwrapping it.
 */
/obj/item/food/british_pack/proc/unwrap(mob/user)
	var/atom/spot = drop_location()
	var/obj/item/food/bare_food = new unwrapped_type(spot)
	bare_food.reagents.clear_reagents()
	reagents.trans_to(bare_food, reagents.total_volume)
	var/datum/component/piping_hot/heat = GetComponent(/datum/component/piping_hot)
	heat?.pass_to(bare_food)
	var/obj/item/empty_container = new trash_type(spot)
	to_chat(user, span_notice("You take [bare_food] out of its packaging."))
	qdel(src)
	user.put_in_hands(bare_food)
	user.put_in_hands(empty_container)

/obj/item/food/british_pack/hunters_chicken
	name = "hunter's chicken ready meal"
	desc = "Hunter's chicken in a plastic tray under clear film. The barbecue sauce has already claimed the corners."
	icon_state = "hunters_chicken_pack"
	trash_type = /obj/item/trash/british_pack/hunters_chicken
	unwrapped_type = /obj/item/food/hunters_chicken/vendor
	food_reagents = list(
		/datum/reagent/consumable/nutriment/protein = 5,
		/datum/reagent/consumable/nutriment/fat = 4,
		/datum/reagent/consumable/nutriment = 2,
		/datum/reagent/consumable/bbqsauce = 3,
		/datum/reagent/consumable/salt = 2,
	)
	tastes = list("chicken" = 3, "bacon" = 2, "barbecue sauce" = 2, "melted cheese" = 1)
	foodtypes = MEAT | DAIRY | JUNKFOOD
	custom_price = PAYCHECK_CREW * 1.8

/obj/item/food/hunters_chicken/vendor
	desc = "A chicken breast wrapped in bacon, smothered in barbecue sauce and melted cheese. A pub menu staple. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment/protein = 5,
		/datum/reagent/consumable/nutriment/fat = 4,
		/datum/reagent/consumable/nutriment = 2,
		/datum/reagent/consumable/bbqsauce = 3,
		/datum/reagent/consumable/salt = 2,
	)
	foodtypes = MEAT | DAIRY | JUNKFOOD
	junkiness = 10

/obj/item/food/british_pack/steak_ale_pie
	name = "packaged steak and ale pie"
	desc = "A whole steak and ale pie in a tray, sleeved in card. Serves five, or one very determined spacer."
	icon_state = "steak_ale_pie_pack"
	trash_type = /obj/item/trash/british_pack/steak_ale_pie
	unwrapped_type = /obj/item/food/pie/steak_ale_pie/vendor
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 10,
		/datum/reagent/consumable/nutriment/protein = 5,
		/datum/reagent/consumable/nutriment/fat = 3,
		/datum/reagent/consumable/salt = 2,
	)
	tastes = list("pastry" = 1, "beef" = 2, "ale gravy" = 2)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	w_class = WEIGHT_CLASS_NORMAL
	custom_price = PAYCHECK_CREW * 2

/obj/item/food/pie/steak_ale_pie/vendor
	desc = "Chunks of beef braised in dark ale and gravy under a golden pastry lid. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 10,
		/datum/reagent/consumable/nutriment/protein = 5,
		/datum/reagent/consumable/nutriment/fat = 3,
		/datum/reagent/consumable/salt = 2,
	)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	junkiness = 10
	slice_type = /obj/item/food/pieslice/steak_ale_pie/vendor

/obj/item/food/pieslice/steak_ale_pie/vendor
	desc = "A slice of steak and ale pie. The gravy is already making a break for it. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 2,
		/datum/reagent/consumable/nutriment/protein = 1,
		/datum/reagent/consumable/nutriment/fat = 0.6,
		/datum/reagent/consumable/salt = 0.4,
	)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	junkiness = 10

/obj/item/food/british_pack/steak_ale_pie_slice
	name = "packaged steak and ale pie slice"
	desc = "A single slice of steak and ale pie, sealed in film. The gravy pools at the bottom."
	icon_state = "steak_ale_pie_slice_pack"
	trash_type = /obj/item/trash/british_pack/steak_ale_pie_slice
	unwrapped_type = /obj/item/food/pieslice/steak_ale_pie/vendor
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 2,
		/datum/reagent/consumable/nutriment/protein = 1,
		/datum/reagent/consumable/nutriment/fat = 0.6,
		/datum/reagent/consumable/salt = 0.4,
	)
	tastes = list("pastry" = 1, "beef" = 2, "ale gravy" = 2)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.2

/obj/item/food/british_pack/pork_pie
	name = "packaged pork pie"
	desc = "A pork pie in a paper case. The label promises real pork."
	icon_state = "pork_pie_pack"
	trash_type = /obj/item/trash/british_pack/pork_pie
	unwrapped_type = /obj/item/food/pie/pork_pie/vendor
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 3,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/consumable/nutriment/fat = 2,
		/datum/reagent/consumable/salt = 1,
	)
	tastes = list("pastry" = 1, "pork" = 2, "savoury jelly" = 1)
	foodtypes = GRAIN | DAIRY | MEAT | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.6

/obj/item/food/pie/pork_pie/vendor
	desc = "A hand-raised pie of seasoned pork set in savoury jelly. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 3,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/consumable/nutriment/fat = 2,
		/datum/reagent/consumable/salt = 1,
	)
	foodtypes = GRAIN | DAIRY | MEAT | JUNKFOOD
	junkiness = 10
	slice_type = /obj/item/food/pieslice/pork_pie/vendor

/obj/item/food/pieslice/pork_pie/vendor
	desc = "A quarter of a pork pie. The jelly is load-bearing. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 0.75,
		/datum/reagent/consumable/nutriment/protein = 0.5,
		/datum/reagent/consumable/nutriment/fat = 0.5,
		/datum/reagent/consumable/salt = 0.25,
	)
	foodtypes = GRAIN | DAIRY | MEAT | JUNKFOOD
	junkiness = 10

/obj/item/food/british_pack/chicken_mushroom_pie
	name = "packaged chicken and mushroom pie"
	desc = "A chicken and mushroom pie in a paper case. Somewhere in there, a mushroom."
	icon_state = "chicken_mushroom_pie_pack"
	trash_type = /obj/item/trash/british_pack/chicken_mushroom_pie
	unwrapped_type = /obj/item/food/pie/chicken_mushroom_pie/vendor
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 3,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/consumable/nutriment/fat = 2,
		/datum/reagent/consumable/salt = 1,
	)
	tastes = list("pastry" = 1, "chicken" = 2, "mushroom" = 1, "cream" = 1)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.6

/obj/item/food/pie/chicken_mushroom_pie/vendor
	desc = "A small pie of chicken and mushrooms in a thick, creamy sauce. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 3,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/consumable/nutriment/fat = 2,
		/datum/reagent/consumable/salt = 1,
	)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	junkiness = 10
	slice_type = /obj/item/food/pieslice/chicken_mushroom_pie/vendor

/obj/item/food/pieslice/chicken_mushroom_pie/vendor
	desc = "A quarter of a chicken and mushroom pie, creamy filling and all. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 0.75,
		/datum/reagent/consumable/nutriment/protein = 0.5,
		/datum/reagent/consumable/nutriment/fat = 0.5,
		/datum/reagent/consumable/salt = 0.25,
	)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	junkiness = 10

/obj/item/food/british_pack/cornish_pasty
	name = "wrapped Cornish pasty"
	desc = "A Cornish pasty in a foil-lined paper sleeve. The crimping is suspiciously even."
	icon_state = "cornish_pasty_pack"
	trash_type = /obj/item/trash/british_pack/cornish_pasty
	unwrapped_type = /obj/item/food/cornish_pasty/vendor
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/consumable/nutriment/fat = 2,
		/datum/reagent/consumable/salt = 1,
	)
	tastes = list("pastry" = 2, "beef" = 1, "potato" = 1, "swede" = 1)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.6

/obj/item/food/cornish_pasty/vendor
	desc = "Beef, potato, swede and onion baked in a crimped pastry case. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/consumable/nutriment/fat = 2,
		/datum/reagent/consumable/salt = 1,
	)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	junkiness = 10

/obj/item/food/british_pack/welsh_cawl
	name = "\improper Welsh cawl pouch"
	desc = "Welsh cawl in a pouch you eat straight from. Mostly broth, with the odd lump of lamb."
	icon_state = "welsh_cawl_pack"
	trash_type = /obj/item/trash/british_pack/welsh_cawl
	food_reagents = list(
		/datum/reagent/consumable/nutriment/soup/welsh_cawl = 6,
		/datum/reagent/consumable/salt = 2,
	)
	tastes = list("lamb broth" = 2, "leek" = 1, "salt" = 1)
	foodtypes = MEAT | VEGETABLES | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.6

/obj/item/food/british_pack/eton_mess
	name = "\improper Eton mess pot"
	desc = "A plastic pot of Eton mess under a peel-off foil lid."
	icon_state = "eton_mess_pack"
	trash_type = /obj/item/trash/british_pack/eton_mess
	served_hot = FALSE
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 2,
		/datum/reagent/consumable/sugar = 6,
	)
	tastes = list("meringue" = 2, "whipped cream" = 2, "berries" = 1)
	foodtypes = DAIRY | FRUIT | SUGAR | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.2

/obj/item/food/british_pack/scones
	name = "boxed scones"
	desc = "Two scones in a carton topped with jam and cream."
	icon_state = "scones_pack"
	trash_type = /obj/item/trash/british_pack/scones
	unwrapped_type = /obj/item/food/scones/vendor
	served_hot = FALSE
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 6,
		/datum/reagent/consumable/sugar = 5,
	)
	tastes = list("scone" = 2, "jam" = 1, "clotted cream" = 1)
	foodtypes = GRAIN | DAIRY | FRUIT | SUGAR | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.2

/obj/item/food/scones/vendor
	desc = "Two split scones loaded with jam and clotted cream. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 6,
		/datum/reagent/consumable/sugar = 5,
	)
	foodtypes = GRAIN | DAIRY | FRUIT | SUGAR | JUNKFOOD
	junkiness = 10

/obj/item/food/british_pack/sticky_toffee_pudding
	name = "sticky toffee pudding tub"
	desc = "A sealed tub of sticky toffee pudding, the sauce already soaking in."
	icon_state = "sticky_toffee_pudding_pack"
	trash_type = /obj/item/trash/british_pack/sticky_toffee_pudding
	unwrapped_type = /obj/item/food/sticky_toffee_pudding/vendor
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/sugar = 8,
		/datum/reagent/consumable/caramel = 2,
	)
	tastes = list("sponge cake" = 2, "toffee" = 2, "dates" = 1)
	foodtypes = GRAIN | DAIRY | SUGAR | FRUIT | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.6

/obj/item/food/sticky_toffee_pudding/vendor
	desc = "A moist date sponge drowned in hot toffee sauce. Pudding in the oldest, truest sense. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/sugar = 8,
		/datum/reagent/consumable/caramel = 2,
	)
	foodtypes = GRAIN | DAIRY | SUGAR | FRUIT | JUNKFOOD
	junkiness = 10

/obj/item/food/british_pack/cheesy_bean_melt
	name = "bagged sausage, bean and cheese melt"
	desc = "A sausage, bean and cheese melt in a paper bag."
	icon_state = "cheesy_bean_melt_pack"
	trash_type = /obj/item/trash/british_pack/cheesy_bean_melt
	unwrapped_type = /obj/item/food/cheesy_bean_melt/vendor
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/nutriment/protein = 4,
		/datum/reagent/consumable/nutriment/fat = 3,
		/datum/reagent/consumable/salt = 1,
	)
	tastes = list("puff pastry" = 2, "sausage" = 1, "baked beans" = 1, "molten cheese" = 1)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	custom_price = PAYCHECK_LOWER * 1.6

/obj/item/food/cheesy_bean_melt/vendor
	desc = "Sausage, baked beans and molten cheese sealed in sacred flaky puff pastry. This one came out of a packet."
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/nutriment/protein = 4,
		/datum/reagent/consumable/nutriment/fat = 3,
		/datum/reagent/consumable/salt = 1,
	)
	foodtypes = GRAIN | DAIRY | MEAT | VEGETABLES | JUNKFOOD
	junkiness = 10
