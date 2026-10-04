// THIS IS A MODULAR NOVA SECTOR FILE - PERSONAL_CACHE
// Tiny bluespace matrices that live inside a survival box - "pouch" everywhere below is just the code's pet name for them.

/// Slaps TRAIT_LOADOUT_POUCH_ITEM on whatever it's stuck to, so the loadout matrix can recognize its own stuff on sight.
/datum/element/loadout_pouch_item
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY|ELEMENT_BESPOKE
	argument_hash_start_idx = 2
	/// The originating matrix's reference string, without retaining the matrix.
	var/matrix_signature

/datum/element/loadout_pouch_item/Attach(datum/target, matrix_signature)
	. = ..()
	if(!isitem(target))
		return ELEMENT_INCOMPATIBLE
	src.matrix_signature = matrix_signature
	ADD_TRAIT(target, TRAIT_LOADOUT_POUCH_ITEM, matrix_signature)

/datum/element/loadout_pouch_item/Detach(datum/source)
	REMOVE_TRAIT(source, TRAIT_LOADOUT_POUCH_ITEM, matrix_signature)
	return ..()

// Empty abstract matrix. If you want it.
/obj/item/storage/box/cache_pouch
	name = "bluespace matrix"
	desc = "A compact matrix of stabilized bluespace, tuned to store a specific category of gear."
	icon_state = "flat"
	inhand_icon_state = "flat"
	w_class = WEIGHT_CLASS_SMALL
	illustration = null
	foldable_result = null
	resistance_flags = FIRE_PROOF // a house fire shouldn't be able to delete someone's whole kit
	abstract_type = /obj/item/storage/box/cache_pouch
	/// Who gets first crack at something dropped into the cache. Low sorts first, high sorts last - see the CACHE_SORT_* defines and sort_into_matrix().
	var/sort_priority = CACHE_SORT_CATCHALL

// Nummies box.
/obj/item/storage/box/cache_pouch/rations
	name = "ration bluespace matrix"
	desc = "A bluespace matrix that automatically pulls in any food, drinks, condiments, or ration packs dropped into the cache."
	icon_state = "secbox"
	illustration = "fruit"
	storage_type = /datum/storage/box/cache_pouch/rations
	sort_priority = CACHE_SORT_RATIONS

// Where the box's stock tank/mask/medipen end up, plus any Cache tab tank/mask picks. See personal_cache_box.dm and loadout_cache.dm.
/obj/item/storage/box/cache_pouch/survival
	name = "survival bluespace matrix"
	desc = "A bluespace matrix that automatically pulls in any air tanks, masks, or medical supplies (pill bottles, syringes and patches included) dropped into the cache."
	icon_state = "medbox"
	illustration = "epipen"
	storage_type = /datum/storage/box/cache_pouch/survival
	sort_priority = CACHE_SORT_SURVIVAL

// The junk drawer. Holds anything small the pickier matrices turned down. See personal_cache_box.dm and loadout_cache.dm.
/obj/item/storage/box/cache_pouch/general
	name = "general bluespace matrix"
	icon_state = "cyber_implants"
	storage_type = /datum/storage/box/cache_pouch/general
	// no sort_priority - CACHE_SORT_CATCHALL is the default and this is the thing it was defaulted for

// Desc is built here so the slot count can't drift away from the storage datum the way hardcoding it did.
/obj/item/storage/box/cache_pouch/general/Initialize(mapload)
	. = ..()
	desc = "A bluespace matrix that scoops up anything small (up to [atom_storage.max_slots] items) the other matrices won't take - the cache's catch-all."

// Only spawned by the LOADOUT_OVERRIDE_CACHE_POUCH branch of equip_outfit_and_loadout() - see loadout_outfit_helpers.dm
/obj/item/storage/box/cache_pouch/loadout
	name = "loadout bluespace matrix"
	desc = "A bluespace matrix that only recognizes your own loadout gear by its bluespace signature - everything else, sorted or not, bounces right off."
	icon_state = "ghostcostuming"
	storage_type = /datum/storage/box/cache_pouch/loadout
	sort_priority = CACHE_SORT_IDENTITY // it only ever claims trait-tagged gear, so letting it ask first can't steal anything

// The discreet pouch equivalent of /obj/item/storage/box/erp - keeps Erotic picks tucked in the cache instead of loose in a pocket. See loadout_outfit_helpers.dm.
/obj/item/storage/box/cache_pouch/erp
	name = "love bluespace matrix"
	desc = "A discrete bluespace matrix full of mysteries. It knows exactly what it's here for, and it's not telling."
	icon_state = "hugbox"
	illustration = "heart"
	storage_type = /datum/storage/box/cache_pouch/erp
	sort_priority = CACHE_SORT_RESTRICTED // plenty of erp gear is technically a mask or a pill, so it gets asked before survival does

/// Shared matrix guts. allow_big_nesting is load-bearing: can_insert()'s nesting gate is a >= check against the holder's w_class, so without it every storage item these lists promise to take - pill bottles very much included - bounces straight off a same-sized matrix.
/datum/storage/box/cache_pouch
	allow_big_nesting = TRUE

// Controls what the food box holds. Siblings rather than the /cup parent, which also drags in beakers, buckets, jerrycans and soup pots - none of which are lunch.
/datum/storage/box/cache_pouch/rations
	max_specific_storage = WEIGHT_CLASS_NORMAL // ration packs are boxes, and boxes are NORMAL
	max_total_storage = WEIGHT_CLASS_NORMAL * 7
	can_hold_description = "food, drinks, condiments and ration packs"

/datum/storage/box/cache_pouch/rations/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(list(
		/obj/item/food,
		/obj/item/reagent_containers/condiment,
		/obj/item/reagent_containers/cup/glass, // drinking glasses and booze bottles both hang off this one
		/obj/item/reagent_containers/cup/soda_cans, // vendor cans hang off /cup directly, not off /cup/glass
		/obj/item/storage/box/ration,
		/obj/item/storage/box/colonial_rations,
	))

// Captures the survival holdables - anything you want in your hand five seconds after the hull opens. Deliberately capped at SMALL so medkits stay out; this is a survival box, not a medbay.
/datum/storage/box/cache_pouch/survival
	can_hold_description = "air tanks, masks and medical supplies"

/datum/storage/box/cache_pouch/survival/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(list(
		/obj/item/tank/internals,
		/obj/item/clothing/mask,
		/obj/item/healthanalyzer, // the mining box literally ships one and it's been falling through to general this whole time
		/obj/item/inhaler, // lives outside /reagent_containers, so it needs its own line
		/obj/item/reagent_containers/applicator, // pills AND patches - there's no /reagent_containers/pill, they're applicator/pill
		/obj/item/reagent_containers/blood,
		/obj/item/reagent_containers/chem_pack,
		/obj/item/reagent_containers/cup/bottle, // chem bottles. NOT drink bottles, those are /cup/glass/bottle - different tree entirely
		/obj/item/reagent_containers/hypospray,
		/obj/item/reagent_containers/medigel,
		/obj/item/reagent_containers/syringe,
		/obj/item/stack/medical,
		/obj/item/storage/pill_bottle,
	))

// No set_holdable() on purpose - a null can_hold is what makes this the catch-all. Don't "fix" it.
/datum/storage/box/cache_pouch/general
	max_slots = 21
	max_total_storage = WEIGHT_CLASS_SMALL * 21

// Digging through the junk drawer takes a beat. Message goes out from the mob, not the box - visible_message only hands self_message to src, and a box can't read.
/datum/storage/box/cache_pouch/general/remove_single(mob/removing, obj/item/thing, atom/remove_to_loc, silent)
	removing.visible_message(
		span_notice("[removing] starts fishing around inside [parent]."),
		span_notice("You start digging around in [parent] to try and pull something out."),
	)
	if(!do_after(removing, 0.5 SECONDS, parent))
		return FALSE

	return ..()

// Slightly special handling of erotic items
/datum/storage/box/cache_pouch/erp
	max_specific_storage = WEIGHT_CLASS_NORMAL // matches /datum/storage/box/erp - some erp items are bulkier than WEIGHT_CLASS_SMALL
	can_hold_description = "an assortment of strangely shaped playthings"

// Bless the globs
/datum/storage/box/cache_pouch/erp/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(GLOB.erp_items)

// Specialized storage. Does it make sense? No. But it's quality of life. (allow_big_nesting comes from the parent now.)
/datum/storage/box/cache_pouch/loadout
	max_slots = 21
	max_specific_storage = WEIGHT_CLASS_NORMAL
	max_total_storage = WEIGHT_CLASS_NORMAL * 21

// Bouncer at the door: no trait, no entry. Keeps this pouch honest even if some rando item shares a type with your gear.
/datum/storage/box/cache_pouch/loadout/can_insert(obj/item/to_insert, mob/user, messages = TRUE, force = STORAGE_NOT_LOCKED)
	. = ..()
	if(!.) // parent already said why - "too big!", "no room!", whatever - so don't talk over it
		return
	if(!HAS_TRAIT_FROM(to_insert, TRAIT_LOADOUT_POUCH_ITEM, REF(parent)))
		if(messages && user)
			user.balloon_alert(user, "not imprinted on this matrix!")
		return FALSE
