#ifdef DIRT_SOURCES
/// Game events land general dirt on humans in a round through dirt_source_land().
/datum/unit_test/dirt_sources
	/// The floor that check_wading() floods, which Destroy() drains as the test ends.
	var/turf/flooded_floor

/datum/unit_test/dirt_sources/Run()
	check_latch()
	check_slime_hits()
	check_hugs()
	check_tool_work()
	check_walk()
	check_blast()
	check_falls()
	check_splashes()
	check_climax_sweat()
	check_wading()
	check_rest()
	check_roll()

/datum/unit_test/dirt_sources/Destroy()
	if(flooded_floor?.liquids)
		qdel(flooded_floor.liquids, TRUE)
	flooded_floor = null
	return ..()

/// Returns the test room's floor so many tiles east and north of its bottom left corner.
/datum/unit_test/dirt_sources/proc/floor_at(east, north)
	return locate(run_loc_floor_bottom_left.x + east, run_loc_floor_bottom_left.y + north, run_loc_floor_bottom_left.z)

/// Returns the general deposits of a cause on a person's skin and on the cloth of what they wear.
/datum/unit_test/dirt_sources/proc/deposits_of(mob/living/carbon/human/body, cause)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/component/dirtiness/carrier as anything in dirt_carriers(body))
		for(var/datum/dirt_splat/splat as anything in carrier.mess_splats)
			if(splat.cause == cause)
				. += splat

/// Returns slime's material key in a colour, "#RRGGBB", as a splat stores it.
/datum/unit_test/dirt_sources/proc/slime_key(colour)
	var/datum/dirt_material/slime = dirt_material(DIRT_MATERIAL_SLIME, colour)
	return slime?.key

/// A blue slime letting go of a human slimes them in blue. Letting go of a monkey gives it the status but no slime.
/datum/unit_test/dirt_sources/proc/check_latch()
	var/blue = slime_key(/datum/slime_type/blue::rgb_code)
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/basic/slime/human_slime = allocate(/mob/living/basic/slime, human.loc, /datum/slime_type/blue)
	human_slime.start_feeding(human)
	TEST_ASSERT(human.has_status_effect(/datum/status_effect/slime_leech), "The slime didn't latch onto the human.")
	human_slime.stop_feeding()
	TEST_ASSERT(human.has_status_effect(/datum/status_effect/slimed), "The slime letting go of the human didn't slime them.")
	var/list/slimed = deposits_of(human, DIRT_CAUSE_SLIMED)
	TEST_ASSERT(length(slimed), "A slime letting go of a human landed no slime on them.")
	for(var/datum/dirt_splat/splat as anything in slimed)
		TEST_ASSERT_EQUAL(splat.material, blue, "A blue slime letting go of a human landed slime of another colour.")

	var/mob/living/carbon/human/species/monkey/monkey = allocate(/mob/living/carbon/human/species/monkey)
	var/mob/living/basic/slime/monkey_slime = allocate(/mob/living/basic/slime, monkey.loc, /datum/slime_type/blue)
	monkey_slime.start_feeding(monkey)
	TEST_ASSERT(monkey.has_status_effect(/datum/status_effect/slime_leech), "The slime didn't latch onto the monkey.")
	monkey_slime.stop_feeding()
	TEST_ASSERT(monkey.has_status_effect(/datum/status_effect/slimed), "The slime letting go of the monkey didn't slime it.")
	TEST_ASSERT(!length(deposits_of(monkey, DIRT_CAUSE_SLIMED)), "A slime letting go of a monkey landed slime on it.")

/// A slime's hit on the left hand lands its colour on the left arm. Its chest hit from behind lands on the back.
/datum/unit_test/dirt_sources/proc/check_slime_hits()
	var/turf/behind = run_loc_floor_bottom_left
	var/turf/standing = locate(behind.x, behind.y + 1, behind.z)
	var/mob/living/basic/slime/slime = allocate(/mob/living/basic/slime, behind, /datum/slime_type/blue)
	// a slime with no player has its zone picked for every attack
	slime.RemoveElement(/datum/element/attack_zone_randomiser)

	var/mob/living/carbon/human/consistent/struck = allocate(/mob/living/carbon/human/consistent, standing)
	slime.zone_selected = BODY_ZONE_PRECISE_L_HAND
	TEST_ASSERT(slime.melee_attack(struck, ignore_cooldown = TRUE), "The slime's hit on the left hand did nothing.")
	var/list/on_arm = deposits_of(struck, DIRT_CAUSE_SLIMED_L_ARM)
	TEST_ASSERT(length(on_arm), "A slime's hit on the left hand landed no slime on the left arm.")
	var/datum/dirt_splat/arm_splat = on_arm[1]
	TEST_ASSERT_EQUAL(arm_splat.material, slime_key(/datum/slime_type/blue::rgb_code), "A blue slime's hit landed slime of another colour.")

	var/mob/living/carbon/human/consistent/turned = allocate(/mob/living/carbon/human/consistent, standing)
	turned.setDir(NORTH)
	slime.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(slime.melee_attack(turned, ignore_cooldown = TRUE), "The slime's hit on the chest did nothing.")
	TEST_ASSERT(length(deposits_of(turned, DIRT_CAUSE_SLIMED_BACK)), "A slime's chest hit from behind landed no slime on the back.")
	TEST_ASSERT(!length(deposits_of(turned, DIRT_CAUSE_SLIMED_CHEST)), "A slime's chest hit from behind landed slime on the chest.")

/// A slime person's hug lands slime in their colour on the chest of the one hugged. Their grab at someone's chest,
/// then a bear hug, lands both, the bear hug's level on top of the grab's. A human's hug lands none.
/datum/unit_test/dirt_sources/proc/check_hugs()
	var/colour = "#3FA86B"
	var/mob/living/carbon/human/consistent/slime_person = allocate(/mob/living/carbon/human/consistent)
	slime_person.set_species(/datum/species/jelly)
	slime_person.dna.features[FEATURE_MUTANT_COLOR] = colour
	var/mob/living/carbon/human/consistent/hugged = allocate(/mob/living/carbon/human/consistent)
	hugged.help_shake_act(slime_person)
	TEST_ASSERT(hugged.mob_mood.has_mood_of_category("hug"), "The slime person's hug didn't happen.")
	var/list/on_chest = deposits_of(hugged, DIRT_CAUSE_SLIMED_CHEST)
	TEST_ASSERT(length(on_chest), "A slime person's hug landed no slime on the chest of the one hugged.")
	var/datum/dirt_splat/chest_splat = on_chest[1]
	TEST_ASSERT_EQUAL(chest_splat.material, slime_key(colour), "A slime person's hug landed slime of another colour than theirs.")

	var/mob/living/carbon/human/consistent/squeezed = allocate(/mob/living/carbon/human/consistent)
	slime_person.start_pulling(squeezed)
	squeezed.grippedby(slime_person)
	TEST_ASSERT(slime_person.grab_state >= GRAB_AGGRESSIVE, "The slime person didn't grab the human aggressively, so the bear hug after it can't be checked.")
	squeezed.help_shake_act(slime_person)
	var/list/squeezed_chest = deposits_of(squeezed, DIRT_CAUSE_SLIMED_CHEST)
	TEST_ASSERT(length(squeezed_chest), "A slime person's grab and bear hug landed no slime on the chest.")
	var/datum/dirt_splat/squeezed_splat = squeezed_chest[1]
	TEST_ASSERT_EQUAL(squeezed_splat.material, slime_key(colour), "A slime person's bear hug landed slime of another colour than theirs.")
	TEST_ASSERT_EQUAL(squeezed_splat.level, min(/datum/dirt_source/slime/touch/grab::level + /datum/dirt_source/slime/touch/hug::bear_hug_level, dirt_cause_max_level(DIRT_CAUSE_SLIMED_CHEST)), "A slime person's bear hug after their grab at the chest didn't add the bear hug's level to the grab's slime.")

	var/mob/living/carbon/human/consistent/hugger = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/held = allocate(/mob/living/carbon/human/consistent)
	held.help_shake_act(hugger)
	TEST_ASSERT(held.mob_mood.has_mood_of_category("hug"), "The human's hug didn't happen.")
	TEST_ASSERT(!length(deposits_of(held, DIRT_CAUSE_SLIMED_CHEST)) && !length(deposits_of(hugger, DIRT_CAUSE_SLIMED_CHEST)), "A human's hug landed slime.")

/// Tool work on a machine rolls the engineer's chance for an engineer and the general one for anyone else.
/datum/unit_test/dirt_sources/proc/check_tool_work()
	var/obj/machinery/machine = allocate(/obj/machinery/seed_extractor)
	var/mob/living/carbon/human/consistent/assistant = allocate(/mob/living/carbon/human/consistent)
	assistant.mind_initialize()
	assistant.mind.set_assigned_role(SSjob.get_job_type(/datum/job/assistant))
	TEST_ASSERT(dirt_tool_work(assistant, machine, TOOL_SCREWDRIVER, 100, 0), "Tool work on a machine, its general chance forced, landed nothing on an assistant.")
	var/list/worked = deposits_of(assistant, DIRT_CAUSE_MACHINE)
	TEST_ASSERT(length(worked), "Tool work on a machine landed no machine work's dirt on an assistant.")
	var/datum/dirt_splat/work_splat = worked[1]
	TEST_ASSERT_EQUAL(work_splat.material, DIRT_MATERIAL_GREASE, "Tool work on a machine landed something other than grease.")

	var/mob/living/carbon/human/consistent/engineer = allocate(/mob/living/carbon/human/consistent)
	engineer.mind_initialize()
	engineer.mind.set_assigned_role(SSjob.get_job_type(/datum/job/station_engineer))
	TEST_ASSERT_EQUAL(dirt_tool_work(engineer, machine, TOOL_SCREWDRIVER, 100, 0), 0, "Tool work on a machine rolled the general chance for an engineer.")
	var/mob/living/carbon/human/consistent/greased_engineer = allocate(/mob/living/carbon/human/consistent)
	greased_engineer.mind_initialize()
	greased_engineer.mind.set_assigned_role(SSjob.get_job_type(/datum/job/station_engineer))
	TEST_ASSERT(dirt_tool_work(greased_engineer, machine, TOOL_SCREWDRIVER, 0, 100), "Tool work on a machine, its engineer's chance forced, landed nothing on an engineer.")

/// A walk over a dirt decal, its chance forced, lands grime once, and floor_check_interval holds off the next look. A
/// real step onto dirt spends the look, so one forced straight after lands nothing.
/datum/unit_test/dirt_sources/proc/check_walk()
	var/mob/living/carbon/human/consistent/walker = allocate(/mob/living/carbon/human/consistent)
	allocate(/obj/effect/decal/cleanable/dirt, walker.loc)
	var/datum/component/dirt_sources/sources = walker.GetComponent(/datum/component/dirt_sources)
	TEST_ASSERT(sources.check_floor(100, 100), "A walk over dirt, its chance forced, landed nothing.")
	TEST_ASSERT_EQUAL(sources.check_floor(100, 100), 0, "The next step over dirt within floor_check_interval landed again.")
	var/list/walked = deposits_of(walker, DIRT_CAUSE_WALK)
	TEST_ASSERT(length(walked), "A walk over dirt landed no walking dirt.")
	var/datum/dirt_splat/walk_splat = walked[1]
	TEST_ASSERT_EQUAL(walk_splat.material, DIRT_MATERIAL_GRIME, "A walk over a dirt decal landed something other than grime.")

	var/turf/start = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/dirty = get_step(start, EAST)
	var/obj/effect/decal/cleanable/dirt/dirt = allocate(/obj/effect/decal/cleanable/dirt, dirty)
	var/mob/living/carbon/human/consistent/stepper = allocate(/mob/living/carbon/human/consistent, start)
	stepper.Move(dirty, EAST)
	TEST_ASSERT(stepper.loc == dirty && !QDELETED(dirt), "The human didn't step onto the dirt, so a step looking at the floor can't be checked.")
	var/datum/component/dirt_sources/stepper_sources = stepper.GetComponent(/datum/component/dirt_sources)
	TEST_ASSERT_EQUAL(stepper_sources.check_floor(100, 100), 0, "A step onto dirt didn't look at the floor, so a look straight after landed.")

/// A heavy and a light explosion each land their blast at their severity once SSdirt fires.
/datum/unit_test/dirt_sources/proc/check_blast()
	var/mob/living/carbon/human/consistent/heavily_blasted = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/mob/living/carbon/human/consistent/lightly_blasted = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	EX_ACT(heavily_blasted, EXPLODE_HEAVY)
	EX_ACT(lightly_blasted, EXPLODE_LIGHT)
	SSdirt.finish_all()
	var/list/heavy_blast = deposits_of(heavily_blasted, DIRT_CAUSE_BLAST)
	TEST_ASSERT(length(heavy_blast), "A heavy explosion landed no blast.")
	var/datum/dirt_splat/heavy_splat = heavy_blast[1]
	TEST_ASSERT_EQUAL(heavy_splat.level, EXPLODE_HEAVY, "A heavy explosion's blast landed at a level other than its severity.")
	var/list/light_blast = deposits_of(lightly_blasted, DIRT_CAUSE_BLAST)
	TEST_ASSERT(length(light_blast), "A light explosion landed no blast.")
	var/datum/dirt_splat/light_splat = light_blast[1]
	TEST_ASSERT_EQUAL(light_splat.level, EXPLODE_LIGHT, "A light explosion's blast landed at a level other than its severity.")

/// A fall onto a dirt decal lands its grime once SSdirt fires, and a fall onto a clean floor lands nothing.
/datum/unit_test/dirt_sources/proc/check_falls()
	var/turf/dirty = get_step(run_loc_floor_top_right, WEST)
	allocate(/obj/effect/decal/cleanable/dirt, dirty)
	var/mob/living/carbon/human/consistent/dirty_faller = allocate(/mob/living/carbon/human/consistent, dirty)
	var/mob/living/carbon/human/consistent/clean_faller = allocate(/mob/living/carbon/human/consistent, floor_at(4, 3))
	dirty_faller.Knockdown(1 SECONDS)
	clean_faller.Knockdown(1 SECONDS)
	SSdirt.finish_all()
	var/list/fell = deposits_of(dirty_faller, DIRT_CAUSE_FALL)
	TEST_ASSERT(length(fell), "A fall onto dirt landed nothing.")
	var/datum/dirt_splat/fall_splat = fell[1]
	TEST_ASSERT_EQUAL(fall_splat.material, DIRT_MATERIAL_GRIME, "A fall onto a dirt decal landed something other than grime.")
	TEST_ASSERT(!length(deposits_of(clean_faller, DIRT_CAUSE_FALL)), "A fall onto a clean floor landed something.")

/// Oil splashed on someone lands oil once SSdirt fires, and water lands nothing.
/datum/unit_test/dirt_sources/proc/check_splashes()
	var/mob/living/carbon/human/consistent/oiled = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/cup/beaker/oil_beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	oil_beaker.reagents.add_reagent(/datum/reagent/fuel/oil, 30)
	oil_beaker.reagents.expose(oiled, TOUCH)
	var/mob/living/carbon/human/consistent/watered = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/cup/beaker/water_beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	water_beaker.reagents.add_reagent(/datum/reagent/water, 30)
	water_beaker.reagents.expose(watered, TOUCH)
	SSdirt.finish_all()
	var/list/splashed = deposits_of(oiled, DIRT_CAUSE_SPLASH)
	TEST_ASSERT(length(splashed), "Oil splashed on someone landed nothing.")
	var/datum/dirt_splat/splash_splat = splashed[1]
	TEST_ASSERT_EQUAL(splash_splat.material, DIRT_MATERIAL_OIL, "Oil splashed on someone landed something other than oil.")
	TEST_ASSERT(!length(deposits_of(watered, DIRT_CAUSE_SPLASH)), "Water splashed on someone landed something.")

/// A climax leaves a dressed person reading as sweaty, and washing them clears it.
/datum/unit_test/dirt_sources/proc/check_climax_sweat()
	var/mob/living/carbon/human/consistent/climaxer = allocate(/mob/living/carbon/human/consistent)
	climaxer.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(climaxer), ITEM_SLOT_ICLOTHING)
	climaxer.apply_status_effect(/datum/status_effect/climax)
	TEST_ASSERT(climaxer.is_visibly_sweaty(), "A dressed person's climax didn't leave them reading as sweaty.")
	climaxer.wash(CLEAN_WASH)
	TEST_ASSERT(!climaxer.is_visibly_sweaty(), "Washing a sweaty person left them reading as sweaty.")

/// Ankle-deep oil touching someone as its pool ticks lands as wading, and oil splashed on them there lands as a splash.
/datum/unit_test/dirt_sources/proc/check_wading()
	flooded_floor = floor_at(0, 4)
	flooded_floor.add_liquid(/datum/reagent/fuel/oil, 100, no_react = TRUE)
	TEST_ASSERT_EQUAL(flooded_floor.liquids?.liquid_state, LIQUID_STATE_ANKLES, "100 units of oil didn't come up to the ankles, so wading can't be checked.")
	var/mob/living/carbon/human/consistent/wader = allocate(/mob/living/carbon/human/consistent, flooded_floor)
	wader.apply_status_effect(/datum/status_effect/water_affected)
	var/datum/status_effect/water_affected/wading = wader.has_status_effect(/datum/status_effect/water_affected)
	wading.tick(1)
	var/obj/item/reagent_containers/cup/beaker/oil_beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	oil_beaker.reagents.add_reagent(/datum/reagent/fuel/oil, 30)
	oil_beaker.reagents.expose(wader, TOUCH)
	SSdirt.finish_all()
	var/list/waded = deposits_of(wader, DIRT_CAUSE_WALK)
	TEST_ASSERT(length(waded), "Wading in ankle-deep oil landed no walking marks.")
	var/datum/dirt_splat/wade_splat = waded[1]
	TEST_ASSERT_EQUAL(wade_splat.material, DIRT_MATERIAL_OIL, "Wading in oil landed something other than oil.")
	TEST_ASSERT(length(deposits_of(wader, DIRT_CAUSE_SPLASH)), "Oil splashed on someone wading in oil landed no splash.")

/// Lying down by choice on a dirt decal lands its crawling marks, and lying down again within the cooldown adds none.
/datum/unit_test/dirt_sources/proc/check_rest()
	var/turf/dirty = floor_at(1, 3)
	allocate(/obj/effect/decal/cleanable/dirt, dirty)
	var/mob/living/carbon/human/consistent/rester = allocate(/mob/living/carbon/human/consistent, dirty)
	rester.set_resting(TRUE, instant = TRUE)
	var/list/rested = deposits_of(rester, DIRT_CAUSE_CRAWL)
	TEST_ASSERT(length(rested), "Lying down on dirt landed no crawling marks.")
	var/datum/dirt_splat/rest_splat = rested[1]
	var/first_level = rest_splat.level
	rester.set_resting(FALSE, instant = TRUE)
	rester.set_resting(TRUE, instant = TRUE)
	TEST_ASSERT_EQUAL(rest_splat.level, first_level, "Lying down on dirt again within the cooldown raised the crawling marks.")
	TEST_ASSERT_EQUAL(length(deposits_of(rester, DIRT_CAUSE_CRAWL)), length(rested), "Lying down on dirt again within the cooldown landed more crawling marks.")

/// Stopping, dropping and rolling on a dirt decal lands a fall's marks in its grime on the first turn.
/datum/unit_test/dirt_sources/proc/check_roll()
	var/turf/dirty = floor_at(2, 4)
	allocate(/obj/effect/decal/cleanable/dirt, dirty)
	var/mob/living/carbon/human/consistent/roller = allocate(/mob/living/carbon/human/consistent, dirty)
	roller.apply_status_effect(/datum/status_effect/stop_drop_roll)
	TEST_ASSERT(roller.has_status_effect(/datum/status_effect/stop_drop_roll), "The human didn't start rolling, so a roll can't be checked.")
	// the drop's own fall waits for SSdirt, so only the first turn of rolling landed
	var/list/rolled = deposits_of(roller, DIRT_CAUSE_FALL)
	TEST_ASSERT(length(rolled), "Rolling on dirt landed no marks.")
	var/datum/dirt_splat/roll_splat = rolled[1]
	TEST_ASSERT_EQUAL(roll_splat.material, DIRT_MATERIAL_GRIME, "Rolling on a dirt decal landed something other than grime.")
	SSdirt.finish_all()
#endif
