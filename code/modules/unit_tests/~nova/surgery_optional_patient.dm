/// Detached-limb operations have no patient; active stasis must still block attached patients.
/datum/unit_test/surgery_optional_patient
	var/uses = 0

/datum/unit_test/surgery_optional_patient/proc/observe_tool_use(obj/item/source, datum/surgery_operation/operation, atom/movable/operating_on, mob/living/surgeon)
	SIGNAL_HANDLER
	uses++
	// Observe reaching the real downstream hook, then avoid do_after or random surgery outcomes.
	return ITEM_INTERACT_BLOCKING

/datum/unit_test/surgery_optional_patient/Run()
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm/left/detached_arm = allocate(/obj/item/bodypart/arm/left)
	var/obj/item/knife/shiv/tool = allocate(/obj/item/knife/shiv)
	TEST_ASSERT(surgeon.put_in_active_hand(tool), "Surgeon must hold the real shiv")
	var/datum/surgery_operation/limb/incise_skin/operation = GLOB.operations.operations_by_typepath[/datum/surgery_operation/limb/incise_skin]
	var/list/operation_args = list(OPERATION_TARGET_ZONE = BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(operation, "Real incision operation must be registered")
	TEST_ASSERT(isnull(detached_arm.owner) && isnull(operation.get_patient(detached_arm)), "Detached arm must have no patient")
	TEST_ASSERT(operation.operation_flags & OPERATION_NO_PATIENT_REQUIRED, "Incision must support detached limbs")
	TEST_ASSERT(operation.check_availability(null, detached_arm, surgeon, tool, BODY_ZONE_L_ARM), "Detached-arm incision must be available with the real shiv")
	RegisterSignal(tool, COMSIG_ITEM_USED_IN_SURGERY, PROC_REF(observe_tool_use))
	operation.try_perform(detached_arm, surgeon, tool, operation_args)
	TEST_ASSERT(uses == 1, "Detached-arm surgery must reach the tool hook without dereferencing an absent patient")

	// These controls are reached only after the detached-arm regression passes.
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/attached_arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	patient.set_body_position(LYING_DOWN)
	TEST_ASSERT(operation.get_patient(attached_arm) == patient, "An attached arm must resolve its living patient")
	TEST_ASSERT(operation.check_availability(patient, attached_arm, surgeon, tool, BODY_ZONE_L_ARM), "Attached-arm fixture must allow incision before stasis")
	operation.try_perform(attached_arm, surgeon, tool, operation_args)
	TEST_ASSERT(uses == 2, "An ordinary attached patient must reach the tool hook")

	var/obj/machinery/stasis/bed = allocate(/obj/machinery/stasis)
	TEST_ASSERT(bed.buckle_mob(patient, force = TRUE), "Patient must buckle to the real stasis bed")
	TEST_ASSERT(patient.buckled == bed && bed.stasis_enabled, "Stasis fixture must start enabled and buckled")
	TEST_ASSERT(operation.check_availability(patient, attached_arm, surgeon, tool, BODY_ZONE_L_ARM), "Stasis case must reach the specific guard rather than fail availability")
	var/blocked = operation.try_perform(attached_arm, surgeon, tool, operation_args)
	TEST_ASSERT(blocked == ITEM_INTERACT_BLOCKING && uses == 2, "Enabled stasis must block before the tool hook")

	bed.click_alt(surgeon)
	TEST_ASSERT(!bed.stasis_enabled && patient.buckled == bed, "Disabling stasis must preserve the buckled patient")
	operation.try_perform(attached_arm, surgeon, tool, operation_args)
	TEST_ASSERT(uses == 3, "Disabled stasis must allow the normal surgery tool hook")
	UnregisterSignal(tool, COMSIG_ITEM_USED_IN_SURGERY)
