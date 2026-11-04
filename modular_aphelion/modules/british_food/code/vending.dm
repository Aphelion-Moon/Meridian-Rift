/obj/machinery/vending/imported/luvvits
	name = "Mrs. Luvvit's Pie & Mash"
	desc = "Sourced locally!"
	icon = 'modular_aphelion/modules/british_food/icons/british_vendor.dmi'
	icon_state = "luvvits"
	light_mask = "luvvits-light-mask"
	light_color = LIGHT_COLOR_FIRE
	product_slogans = "Fresh pies! Hot out of the oven!;Proper pies, proper pasties, proper puddings!;The finest pies on the station!;Locally sourced!"
	vend_reply = "A customer! Here, eat it while it's hot!"
	product_categories = list(
		list(
			"name" = "Meals",
			"icon" = "pizza-slice",
			"products" = list(
				/obj/item/food/british_pack/hunters_chicken = 6,
				/obj/item/food/british_pack/steak_ale_pie = 3,
				/obj/item/food/british_pack/steak_ale_pie_slice = 6,
				/obj/item/food/british_pack/pork_pie = 6,
				/obj/item/food/british_pack/chicken_mushroom_pie = 6,
				/obj/item/food/british_pack/cornish_pasty = 6,
				/obj/item/food/british_pack/cheesy_bean_melt = 6,
				/obj/item/food/british_pack/welsh_cawl = 6,
			),
		),
		list(
			"name" = "Puddings",
			"icon" = "ice-cream",
			"products" = list(
				/obj/item/food/british_pack/scones = 6,
				/obj/item/food/british_pack/eton_mess = 6,
				/obj/item/food/british_pack/sticky_toffee_pudding = 6,
			),
		),
		list(
			"name" = "Drinks",
			"icon" = "bottle-water",
			"products" = list(
				/obj/item/reagent_containers/cup/soda_cans/irn_bru = 6,
				/obj/item/reagent_containers/cup/soda_cans/dandelion_burdock = 6,
			),
		),
	)
	refill_canister = /obj/item/vending_refill/snack/imported/luvvits
	allow_custom = TRUE

/obj/machinery/vending/imported/luvvits/on_dispense(obj/item/vended_item, dispense_returned = FALSE)
	if(dispense_returned)
		return
	var/obj/item/food/british_pack/pack = vended_item
	if(istype(pack) && pack.served_hot)
		pack.AddComponent(/datum/component/piping_hot, rand(10 SECONDS, 30 SECONDS))

/obj/item/vending_refill/snack/imported/luvvits
	machine_name = "Mrs. Luvvit's Pie & Mash"
