/// Independent protection durability; ordinary clothing integrity repairs do not replenish it.
/obj/item/clothing
	/// Remaining armour durability. Null until armour ratings have first been resolved.
	var/combat_armor_health
	/// Maximum durability at the last rating update.
	var/combat_armor_max_health = 0
	/// Whether the durability examine handler has been installed.
	var/combat_armor_examine_registered = FALSE

/obj/item/clothing/Initialize(mapload)
	. = ..()
	get_armor()

/obj/item/clothing/get_armor()
	RETURN_TYPE(/datum/armor)
	. = ..()
	update_combat_armor_health(.)

/obj/item/clothing/set_armor(datum/armor/armor)
	. = ..()
	get_armor()

/** Synchronizes durability with runtime armour changes, including MOD theme/module updates. */
/obj/item/clothing/proc/update_combat_armor_health(datum/armor/ratings)
	var/tier = round(max(0, ratings.get_rating(MELEE), ratings.get_rating(BULLET), ratings.get_rating(LASER)) / REFORM_COMBAT_ARMOR_RATING_PER_TIER)
	var/new_max_health = tier * REFORM_COMBAT_ARMOR_HEALTH_PER_TIER
	if(isnull(combat_armor_health))
		if(!new_max_health)
			return
		combat_armor_health = new_max_health
	else if(new_max_health != combat_armor_max_health)
		// Rating changes preserve accumulated wear, and cannot repair broken plates.
		combat_armor_health = combat_armor_health > 0 ? clamp(combat_armor_health + new_max_health - combat_armor_max_health, 0, new_max_health) : 0
	combat_armor_max_health = new_max_health
	if(!combat_armor_examine_registered && new_max_health)
		RegisterSignal(src, COMSIG_ATOM_EXAMINE, PROC_REF(examine_combat_armor))
		combat_armor_examine_registered = TRUE

/obj/item/clothing/get_armor_rating(damage_type)
	. = ..()
	if(combat_armor_max_health && combat_armor_health <= 0 && damage_type != BIO)
		return 0

/** Returns the highest displayed melee, bullet or laser tier, even when broken. */
/obj/item/clothing/proc/get_combat_armor_tier()
	get_armor()
	return combat_armor_max_health / REFORM_COMBAT_ARMOR_HEALTH_PER_TIER

/** Spends armour durability without shredding the garment or destroying a MOD part. */
/obj/item/clothing/proc/damage_combat_armor(amount)
	get_armor()
	if(amount <= 0 || combat_armor_health <= 0)
		return 0
	var/absorbed = min(amount, combat_armor_health)
	combat_armor_health -= absorbed
	if(combat_armor_health <= 0 && isliving(loc))
		to_chat(loc, span_userdanger("The armour on your [name] breaks! It no longer protects you from damage."))
	return absorbed

/** Restores protection durability; only an armour repair kit calls this during gameplay. */
/obj/item/clothing/proc/repair_combat_armor()
	get_armor()
	if(!combat_armor_max_health || combat_armor_health >= combat_armor_max_health)
		return FALSE
	combat_armor_health = combat_armor_max_health
	return TRUE

/obj/item/clothing/proc/examine_combat_armor(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	get_armor()
	examine_list += span_notice("Armour tier [get_combat_armor_tier()]: [round(combat_armor_health, 0.1)]/[combat_armor_max_health] durability. Each protection pip blocks [REFORM_COMBAT_ARMOR_BLOCK_PER_TIER] damage.")
	if(combat_armor_health <= 0)
		examine_list += span_warning("Its armour is broken and provides no damage protection. Use an armour repair kit to restore it.")
	else if(combat_armor_health < combat_armor_max_health)
		examine_list += span_notice("An armour repair kit can restore its durability.")

/** Bulky, single-use supplies for restoring any armoured garment, including MOD chestplates. */
/obj/item/armor_repair_kit
	name = "armour repair kit"
	desc = "A bulky kit of replacement plates, patches and fasteners. Repairs the protection of one armoured garment or MOD chestplate."
	icon = 'icons/obj/storage/toolbox.dmi'
	icon_state = "maint_kit"
	inhand_icon_state = "ammobox"
	lefthand_file = 'icons/mob/inhands/equipment/toolbox_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/toolbox_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	/// Prevents concurrent repairs from consuming one kit more than once.
	var/repairing = FALSE

/obj/item/armor_repair_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	. = ..()
	if(. & ITEM_INTERACT_ANY_BLOCKER)
		return .
	var/obj/item/clothing/armor = interacting_with.get_combat_armor_repair_target(user)
	if(!armor)
		return NONE
	if(!armor.get_combat_armor_tier())
		balloon_alert(user, "no armour to repair!")
		return ITEM_INTERACT_BLOCKING
	if(repairing || armor.combat_armor_health >= armor.combat_armor_max_health)
		balloon_alert(user, repairing ? "already repairing!" : "already repaired!")
		return ITEM_INTERACT_BLOCKING
	repairing = TRUE
	to_chat(user, span_notice("You begin repairing the armour on [armor]..."))
	var/completed = do_after(user, REFORM_COMBAT_ARMOR_REPAIR_TIME, interacting_with)
	repairing = FALSE
	if(!completed || QDELETED(src) || QDELETED(armor) || interacting_with.get_combat_armor_repair_target(user) != armor || !armor.repair_combat_armor())
		return ITEM_INTERACT_BLOCKING
	to_chat(user, span_notice("You restore the armour on [armor] to full durability."))
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/** Resolves the armour accessible through a repair-kit target. */
/atom/proc/get_combat_armor_repair_target(mob/living/user)
	return null

/obj/item/clothing/get_combat_armor_repair_target(mob/living/user)
	return src

/obj/item/mod/control/get_combat_armor_repair_target(mob/living/user)
	return get_part_from_slot(ITEM_SLOT_OCLOTHING)

/mob/living/carbon/human/get_combat_armor_repair_target(mob/living/user)
	return get_combat_armor(get_bodypart(check_zone(user.zone_selected)))

/** Makes generic repair supplies obtainable without editing vendors or maps. */
/datum/supply_pack/security/armor_repair_kits
	name = "Armour Repair Kits"
	desc = "Three bulky, single-use repair kits for armour and MOD chestplates."
	cost = CARGO_CRATE_VALUE * 3
	contains = list(/obj/item/armor_repair_kit = 3)
	crate_name = "armour repair kits crate"
