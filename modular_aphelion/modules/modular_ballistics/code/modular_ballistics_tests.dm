#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
#define PARALLAX_ASSERT(condition, message) if(!(condition)) { return Fail(message, __FILE__, __LINE__) }
#define PARALLAX_ASSERT_EQUAL(actual, expected, message) PARALLAX_ASSERT((actual) == (expected), message)

/// Swapping real parts must recompute state and stop stale fire controllers.
/datum/unit_test/parallax_component_lifecycle

/datum/unit_test/parallax_component_lifecycle/Run()
	var/obj/item/gun/ballistic/parallax/empty/gun = allocate(/obj/item/gun/ballistic/parallax/empty)
	var/obj/item/ballistic_module/barrel/marksman/barrel = allocate(/obj/item/ballistic_module/barrel/marksman)
	var/obj/item/ballistic_module/control/automatic/controller = allocate(/obj/item/ballistic_module/control/automatic)
	PARALLAX_ASSERT(!gun.assembly_ready(), "An empty frame must not fire.")
	PARALLAX_ASSERT(gun.install_module(barrel), "Barrel should install into an empty socket.")
	PARALLAX_ASSERT(gun.install_module(controller), "Controller should install into an empty socket.")
	PARALLAX_ASSERT(gun.assembly_ready(), "A barrel and controller should complete the assembly.")
	PARALLAX_ASSERT(gun.controller_autofire, "Automatic controller must create the automatic-fire component.")
	PARALLAX_ASSERT_EQUAL(gun.fire_delay, 0.8 SECONDS, "Automatic fire must respect the marksman barrel cycle.")
	PARALLAX_ASSERT_EQUAL(gun.weapon_weight, WEAPON_HEAVY, "Marksman accelerator requires two hands.")
	var/original_damage = gun.projectile_damage_multiplier
	gun.rebuild_configuration()
	PARALLAX_ASSERT_EQUAL(gun.projectile_damage_multiplier, original_damage, "Rebuilding must not stack damage bonuses.")
	barrel.forceMove(run_loc_floor_bottom_left)
	PARALLAX_ASSERT(!gun.assembly_ready(), "Externally moving the barrel must disable the gun.")
	PARALLAX_ASSERT(!gun.controller_autofire, "Incomplete assemblies must stop automatic fire.")
	PARALLAX_ASSERT_EQUAL(length(gun.modules), 1, "Moved components must leave their socket.")
	gun.install_module(barrel)
	qdel(controller)
	PARALLAX_ASSERT(!gun.modules["controller"], "Deleted controllers must be forgotten immediately.")
	PARALLAX_ASSERT(!gun.controller_autofire, "Deleting a controller must remove automatic fire.")
	gun.firing_burst = TRUE
	PARALLAX_ASSERT(!gun.process_burst(null, null), "An incomplete gun must reject a queued burst callback.")
	PARALLAX_ASSERT(!gun.firing_burst, "Rejected burst callbacks must clear the firing flag.")

/// All stock/barrel/controller/optic combinations use the same resource contract.
/datum/unit_test/parallax_configuration_matrix

/datum/unit_test/parallax_configuration_matrix/Run()
	var/obj/item/gun/ballistic/parallax/empty/gun = allocate(/obj/item/gun/ballistic/parallax/empty)
	for(var/barrel_type in typesof(/obj/item/ballistic_module/barrel))
		var/obj/item/ballistic_module/barrel/barrel = new barrel_type(run_loc_floor_bottom_left)
		gun.install_module(barrel)
		for(var/control_type in typesof(/obj/item/ballistic_module/control))
			var/obj/item/ballistic_module/control/controller = new control_type(run_loc_floor_bottom_left)
			gun.install_module(controller)
			for(var/stock_type in list(null, /obj/item/ballistic_module/stock, /obj/item/ballistic_module/stock/precision))
				var/obj/item/ballistic_module/stock/stock
				if(stock_type)
					stock = new stock_type(run_loc_floor_bottom_left)
					gun.install_module(stock)
				for(var/optic_type in list(null, /obj/item/ballistic_module/optic, /obj/item/ballistic_module/optic/scope))
					var/obj/item/ballistic_module/optic/optic
					if(optic_type)
						optic = new optic_type(run_loc_floor_bottom_left)
						gun.install_module(optic)
					PARALLAX_ASSERT(gun.assembly_ready(), "Every supported combination must assemble.")
					PARALLAX_ASSERT(gun.spread >= 0, "Stacked optics and stock must not produce negative spread.")
					PARALLAX_ASSERT_EQUAL(gun.burst_size, controller.shots_per_burst, "Burst mode must follow the installed controller.")
					for(var/socket in gun.modules)
						var/obj/item/ballistic_module/part = gun.modules[socket]
						PARALLAX_ASSERT(part.overlay_state in icon_states(gun.icon), "World overlay missing for [part.type].")
						PARALLAX_ASSERT(part.overlay_state in icon_states(gun.lefthand_file), "Left-hand overlay missing for [part.type].")
						PARALLAX_ASSERT(part.overlay_state in icon_states(gun.righthand_file), "Right-hand overlay missing for [part.type].")
					QDEL_NULL(optic)
				QDEL_NULL(stock)
			qdel(controller)
		qdel(barrel)

/datum/unit_test/parallax_service_interlock

/datum/unit_test/parallax_service_interlock/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/parallax/gun = allocate(/obj/item/gun/ballistic/parallax)
	var/obj/item/screwdriver/driver = allocate(/obj/item/screwdriver)
	user.put_in_hands(gun)
	PARALLAX_ASSERT(gun.can_shoot(), "The loaded sidearm must have a live chamber.")
	gun.screwdriver_act(user, driver)
	PARALLAX_ASSERT(!gun.service_open, "Loaded guns must refuse service access.")
	gun.magazine.forceMove(run_loc_floor_bottom_left)
	gun.screwdriver_act(user, driver)
	PARALLAX_ASSERT(!gun.service_open, "A chambered round must still block service after cassette removal.")
	gun.process_chamber(empty_chamber = TRUE, from_firing = FALSE, chamber_next_round = FALSE)
	gun.screwdriver_act(user, driver)
	PARALLAX_ASSERT(gun.service_open, "A held and completely unloaded gun should open for servicing.")
	PARALLAX_ASSERT(!gun.assembly_ready(), "An open service latch must disable firing.")
	var/obj/item/ballistic_module/barrel/duplicate = allocate(/obj/item/ballistic_module/barrel)
	PARALLAX_ASSERT(!gun.install_module(duplicate), "Occupied sockets must reject a second component.")
	PARALLAX_ASSERT(duplicate.loc != gun, "Rejected components must not be swallowed by the frame.")
	gun.screwdriver_act(user, driver)
	PARALLAX_ASSERT(gun.assembly_ready(), "Closing service access should restore the complete assembly.")

/// Every physical configuration must use one consistent pose across all parts.
/datum/unit_test/parallax_inhand_profile

/datum/unit_test/parallax_inhand_profile/Run()
	var/obj/item/gun/ballistic/parallax/empty/frame = allocate(/obj/item/gun/ballistic/parallax/empty)
	PARALLAX_ASSERT_EQUAL(frame.icon, 'modular_aphelion/modules/modular_ballistics/icons/parts.dmi', "A stripped frame must show the larger loose receiver.")
	var/obj/item/ballistic_module/barrel/frame_barrel = allocate(/obj/item/ballistic_module/barrel)
	frame.install_module(frame_barrel)
	PARALLAX_ASSERT_EQUAL(frame.icon, 'modular_aphelion/modules/modular_ballistics/icons/modular_ballistics.dmi', "An assembled frame must use the aligned overlay atlas.")
	qdel(frame_barrel)
	PARALLAX_ASSERT_EQUAL(frame.pixel_x, 0, "Stripping the frame must reset its ground-sprite centering.")
	var/obj/item/gun/ballistic/parallax/gun = allocate(/obj/item/gun/ballistic/parallax)
	var/compact_left = 'modular_aphelion/modules/modular_ballistics/icons/compact_lefthand.dmi'
	var/rifle_left = 'modular_aphelion/modules/modular_ballistics/icons/lefthand.dmi'
	PARALLAX_ASSERT_EQUAL(gun.lefthand_file, compact_left, "Sidearms must use the compact pistol pose.")
	var/obj/item/ballistic_module/stock/stock = allocate(/obj/item/ballistic_module/stock)
	gun.install_module(stock)
	PARALLAX_ASSERT_EQUAL(gun.lefthand_file, rifle_left, "Installing a stock must switch to the rifle pose.")
	stock.forceMove(run_loc_floor_bottom_left)
	PARALLAX_ASSERT_EQUAL(gun.lefthand_file, compact_left, "Removing the stock must restore the compact pose.")
	var/obj/item/ballistic_module/barrel/short_barrel = gun.modules["barrel"]
	short_barrel.forceMove(run_loc_floor_bottom_left)
	var/obj/item/ballistic_module/barrel/marksman/long_barrel = allocate(/obj/item/ballistic_module/barrel/marksman)
	gun.install_module(long_barrel)
	PARALLAX_ASSERT_EQUAL(gun.lefthand_file, rifle_left, "A long barrel must use the rifle pose without a stock.")
	qdel(long_barrel)
	gun.install_module(short_barrel)
	PARALLAX_ASSERT_EQUAL(gun.lefthand_file, compact_left, "Reinstalling the short barrel must restore the compact pose.")

/// Facing changes must move the whole composed weapon behind the body, and drop
/// or transfer must not leave a listener attached to the previous wearer.
/datum/unit_test/parallax_inhand_layering

/datum/unit_test/parallax_inhand_layering/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/parallax/gun = allocate(/obj/item/gun/ballistic/parallax)
	user.setDir(SOUTH)
	user.put_in_hands(gun)
	PARALLAX_ASSERT_EQUAL(gun.inhand_wearer, user, "Held gun must track its wearer.")
	var/mutable_appearance/front = gun.build_worn_icon(default_layer = HANDS_LAYER, default_icon_file = gun.lefthand_file, isinhands = TRUE)
	PARALLAX_ASSERT_EQUAL(front.layer, -HANDS_LAYER, "South-facing weapon belongs in the normal hand layer.")
	user.setDir(NORTH)
	var/mutable_appearance/behind = gun.build_worn_icon(default_layer = HANDS_LAYER, default_icon_file = gun.lefthand_file, isinhands = TRUE)
	PARALLAX_ASSERT_EQUAL(behind.layer, -BODY_BEHIND_LAYER, "North-facing weapon must render behind the body.")
	PARALLAX_ASSERT(behind.layer < -BODYPARTS_LAYER, "North-facing weapon must be below the body parts.")
	var/list/expected_states = list("magazine")
	for(var/socket in gun.modules)
		var/obj/item/ballistic_module/part = gun.modules[socket]
		expected_states += part.overlay_state
	// The parent also supplies an emissive blocker; check the actual part states
	// rather than assuming every child is a visible weapon component.
	for(var/image/part_overlay as anything in behind.overlays)
		if(!(part_overlay.icon_state in expected_states))
			continue
		PARALLAX_ASSERT_EQUAL(part_overlay.layer, FLOAT_LAYER, "Part overlays must inherit the weapon's rear layer.")
		PARALLAX_ASSERT_EQUAL(part_overlay.plane, FLOAT_PLANE, "Part overlays must remain on the weapon's plane.")
		expected_states -= part_overlay.icon_state
	PARALLAX_ASSERT(!length(expected_states), "Every installed part and the cassette must be present in the rear-layer assembly.")
	user.setDir(EAST)
	PARALLAX_ASSERT_EQUAL(gun.alternate_worn_layer, initial(gun.alternate_worn_layer), "Turning away from north must restore the front layer.")
	user.setDir(NORTH)
	user.dropItemToGround(gun)
	PARALLAX_ASSERT(!gun.inhand_wearer, "Dropping must clear the tracked wearer.")
	user.setDir(SOUTH)
	PARALLAX_ASSERT_EQUAL(gun.alternate_worn_layer, initial(gun.alternate_worn_layer), "Dropped guns must not retain a north-facing layer.")
	user.setDir(NORTH)
	user.put_in_hands(gun)
	PARALLAX_ASSERT_EQUAL(gun.alternate_worn_layer, BODY_BEHIND_LAYER, "Picking up while already north-facing must use the rear layer.")

#undef PARALLAX_ASSERT
#undef PARALLAX_ASSERT_EQUAL
#endif

