/**
 * A limb our code names keeps that name, every other limb takes tg's name for it - its limb_id, read as words, and its
 * zone - and no limb is named for its other side, wherever the name shows: examined, dropped, in repair and surgery
 * messages.
 */
/datum/unit_test/limb_names

/datum/unit_test/limb_names/Run()
	// A limb of each kind and the name it reads - ours by our names, tg's and ours that we name none by tg's
	var/list/names = list(
		/obj/item/bodypart/leg/left/robot/teshari = "cybernetic left raptoral hindlimb",
		/obj/item/bodypart/arm/right/robot/teshari_advanced = "advanced right raptoral forelimb",
		/obj/item/bodypart/leg/left/robot/advanced/digi = "advanced digitigrade left leg",
		/obj/item/bodypart/chest/synth/holosynth = "android torso",
		/obj/item/bodypart/leg/right/synth/taur = "taur right leg",
		/obj/item/bodypart/leg/left/synth/digitigrade = "synthliz left leg",
		/obj/item/bodypart/arm/left/robot = "robotic left arm",
		/obj/item/bodypart/leg/right/robot/surplus = "robotic right leg",
		/obj/item/bodypart/arm/right/robot/advanced = "robotic right arm",
		/obj/item/bodypart/chest/robot/android = "robotic chest",
		/obj/item/bodypart/leg/left/ghetto = "peg left leg",
		/obj/item/bodypart/arm/left/robot/weak = "robotic left arm",
		/obj/item/bodypart/head/mutant/vox_primalis = "vox primalis head",
		/obj/item/bodypart/arm/left/moth/inner = "left chest-arm",
		/obj/item/bodypart/arm/right/moth/inner = "right chest-arm",
	)
	var/list/other_sides = list(BODY_ZONE_L_ARM = "right", BODY_ZONE_L_LEG = "right", BODY_ZONE_R_ARM = "left", BODY_ZONE_R_LEG = "left")
	for(var/obj/item/bodypart/limb_type as anything in subtypesof(/obj/item/bodypart))
		if(limb_type::abstract_type == limb_type)
			continue
		var/obj/item/bodypart/limb = new limb_type()
		var/expected = names[limb_type] || (limb_type::keeps_type_name ? limb_type::name : "[replacetextEx(limb.limb_id, "_", " ")] [parse_zone(limb.body_zone)]")
		var/other_side = other_sides[limb.body_zone]
		if(findtextEx(limb.name, "_"))
			TEST_FAIL("[limb_type] is named \"[limb.name]\", with an underscore")
		else if(other_side && findtextEx(" [limb.name] ", " [other_side] "))
			TEST_FAIL("[limb_type] is named \"[limb.name]\", for its other side")
		else if(limb.name != expected && !(limb.bodypart_flags & BODYPART_STUMP)) // a stump names itself "stump"
			TEST_FAIL("[limb_type] is named \"[limb.name]\", not \"[expected]\"")
		qdel(limb)
