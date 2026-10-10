/// The surplus condom box comes with ten condom packs and nothing else, takes all ten back once they are out, refuses
/// an eleventh pack and an opened condom, and does not survive being made with lewd items disabled.
/datum/unit_test/condom_box

/datum/unit_test/condom_box/Run()
	var/lewd_items_disabled = CONFIG_GET(flag/disable_lewd_items)
	CONFIG_SET(flag/disable_lewd_items, TRUE)
	var/obj/item/storage/box/condoms/gated_box = allocate(/obj/item/storage/box/condoms)
	var/gated_box_survived = !QDELETED(gated_box)
	CONFIG_SET(flag/disable_lewd_items, FALSE)
	var/obj/item/storage/box/condoms/box = allocate(/obj/item/storage/box/condoms)
	var/obj/item/clothing/sextoy/condom/opened_condom = allocate(/obj/item/clothing/sextoy/condom)
	var/obj/item/condom_pack/spare_pack = allocate(/obj/item/condom_pack)
	CONFIG_SET(flag/disable_lewd_items, lewd_items_disabled)
	if(gated_box_survived)
		TEST_FAIL("With lewd items disabled, the surplus condom box still spawned.")

	var/list/packs = list()
	for(var/obj/item/content as anything in box)
		if(istype(content, /obj/item/condom_pack))
			packs += content
		else
			TEST_FAIL("The surplus condom box came with [content.type].")
	if(length(packs) != 10)
		TEST_FAIL("The surplus condom box came with [length(packs)] condom packs instead of ten.")

	for(var/obj/item/condom_pack/pack as anything in packs)
		pack.forceMove(run_loc_floor_bottom_left)
	if(box.atom_storage.can_insert(opened_condom, messages = FALSE))
		TEST_FAIL("The emptied surplus condom box would take an opened condom.")
	for(var/obj/item/condom_pack/pack as anything in packs)
		box.atom_storage.attempt_insert(pack, messages = FALSE)
	if(length(box.contents) != length(packs))
		TEST_FAIL("The emptied surplus condom box took back [length(box.contents)] of its [length(packs)] condom packs.")
	if(box.atom_storage.can_insert(spare_pack, messages = FALSE))
		TEST_FAIL("The full surplus condom box would take an eleventh condom pack.")
