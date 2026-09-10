/** Whether a rating represents damage protection rather than biological or wound resistance. */
/proc/is_combat_armor_flag(armor_flag)
	return armor_flag in list(MELEE, BULLET, LASER, ENERGY, BOMB, FIRE, ACID, CONSUME)

/** Converts displayed armour pips to a flat damage block, rounding down like the protection label. */
/proc/combat_armor_flat_block(rating)
	return round(max(0, rating) / REFORM_COMBAT_ARMOR_RATING_PER_TIER) * REFORM_COMBAT_ARMOR_BLOCK_PER_TIER

/** Fraction of intercepted projectile damage also transferred to the wearer by AP. */
/proc/combat_armor_ap_transfer(rating, penetration)
	if(rating <= 0)
		return 1
	if(penetration < rating)
		return 0
	return clamp(0.25 + 0.75 * (penetration / rating - 1), 0.25, 1)

/** Selects one protective layer per bodypart. Ties prefer outerwear, then headwear. */
/mob/living/carbon/human/proc/get_combat_armor(obj/item/bodypart/bodypart)
	if(!bodypart)
		return null
	var/obj/item/clothing/best_armor
	var/best_tier = 0
	// Match the slots used by get_worn_bodypart_armor_value; held items and pockets do not protect.
	var/list/clothes = list(wear_suit, head, wear_mask, w_uniform, back, gloves, shoes, belt, s_store, glasses, ears, wear_id, wear_neck)
	for(var/obj/item/clothing/clothing in clothes)
		if(!(clothing.body_parts_covered & bodypart.body_part))
			continue
		var/tier = clothing.get_combat_armor_tier()
		if(tier > best_tier)
			best_armor = clothing
			best_tier = tier
	return best_armor

/** Flat protection of the selected garment. Broken outer armour does not uncover another layer. */
/mob/living/carbon/human/proc/get_combat_bodypart_block(obj/item/bodypart/bodypart, armor_flag)
	var/obj/item/clothing/armor = get_combat_armor(bodypart)
	if(!armor)
		return combat_armor_flat_block(inner_armor?.get_rating(armor_flag))
	return min(combat_armor_flat_block(armor.get_armor_rating(armor_flag)), armor.combat_armor_health)

/mob/living/carbon/human/getarmor(def_zone, type)
	. = ..()
	if(!is_combat_armor_flag(type))
		return .
	if(def_zone)
		var/obj/item/bodypart/bodypart = isbodypart(def_zone) ? def_zone : get_bodypart(check_zone(def_zone))
		return get_combat_bodypart_block(bodypart, type)
	var/total_block = 0
	var/list/parts = get_bodyparts()
	for(var/obj/item/bodypart/bodypart as anything in parts)
		total_block += get_combat_bodypart_block(bodypart, type)
	return total_block / max(1, length(parts))

/**
 * Human damage checks carry flat points in the existing numeric blocked argument.
 * The damage sink converts them to a percentage once the damage is available. No attack
 * caller needs a new argument, and no pending armour query can leak into a later hit.
 * Biological/wound checks and nonhuman mobs retain their original percentage contract.
 */
/mob/living/carbon/human/run_armor_check(def_zone = null, attack_flag = MELEE, absorb_text = null, soften_text = null, armour_penetration, penetrated_text, silent = FALSE, weak_against_armour = FALSE)
	if(!is_combat_armor_flag(attack_flag))
		return ..()
	SEND_SIGNAL(src, COMSIG_MOB_RUN_ARMOR)
	var/flat_block = getarmor(def_zone, attack_flag)
	if(weak_against_armour)
		flat_block *= ARMOR_WEAKENED_MULTIPLIER
	// Retain the melee/thrown penetration formula in rating units; projectiles use the AP curve below.
	if(armour_penetration)
		var/equivalent_rating = flat_block / REFORM_COMBAT_ARMOR_BLOCK_PER_TIER * REFORM_COMBAT_ARMOR_RATING_PER_TIER
		flat_block = max(0, PENETRATE_ARMOUR(equivalent_rating, armour_penetration)) / REFORM_COMBAT_ARMOR_RATING_PER_TIER * REFORM_COMBAT_ARMOR_BLOCK_PER_TIER
	if(flat_block > 0 && !silent)
		to_chat(src, span_notice("Your armour intercepts the attack."))
	return flat_block

/// A preview is stored on the projectile so embedding and the subsequent damage use the same hit.
/obj/projectile
	/// Garment intercepted by this hit, without retaining deleted clothing.
	var/datum/weakref/combat_armor_ref
	/// Target for which this preview was calculated.
	var/datum/weakref/combat_armor_target_ref
	/// Durability intercepted before AP transfers any of it to the wearer.
	var/combat_armor_wear = 0
	/// Percentage used by projectile effects and the existing no-embedding guard.
	var/combat_armor_blocked = 0
	/// Uncapped percentage, scoped to the next primary damage application during projectile effects.
	var/combat_armor_damage_block

/mob/living/carbon/human/check_projectile_armor(def_zone, obj/projectile/impacting_projectile, is_silent)
	impacting_projectile.combat_armor_ref = null
	impacting_projectile.combat_armor_target_ref = null
	impacting_projectile.combat_armor_wear = 0
	if(!is_combat_armor_flag(impacting_projectile.armor_flag))
		return ..()
	SEND_SIGNAL(src, COMSIG_MOB_RUN_ARMOR)
	var/obj/item/bodypart/bodypart = isbodypart(def_zone) ? def_zone : get_bodypart(check_zone(def_zone))
	var/obj/item/clothing/armor = get_combat_armor(bodypart)
	var/rating = armor ? armor.get_armor_rating(impacting_projectile.armor_flag) : inner_armor?.get_rating(impacting_projectile.armor_flag)
	var/flat_block = combat_armor_flat_block(rating)
	if(impacting_projectile.weak_against_armour)
		flat_block *= ARMOR_WEAKENED_MULTIPLIER
	if(armor)
		flat_block = min(flat_block, armor.combat_armor_health)
	var/intercepted = min(max(0, impacting_projectile.damage), flat_block)
	var/transferred = intercepted * combat_armor_ap_transfer(rating, impacting_projectile.armour_penetration)
	var/blocked = impacting_projectile.damage > 0 ? 100 * (intercepted - transferred) / impacting_projectile.damage : 0
	impacting_projectile.combat_armor_ref = armor ? WEAKREF(armor) : null
	impacting_projectile.combat_armor_target_ref = WEAKREF(src)
	impacting_projectile.combat_armor_wear = intercepted
	impacting_projectile.combat_armor_blocked = blocked
	if(intercepted > 0 && !is_silent)
		to_chat(src, blocked >= 100 ? span_notice("Your armour stops [impacting_projectile]!") : span_warning("Your armour absorbs part of [impacting_projectile]'s impact!"))
	return blocked

/** Carries the actual block around the upstream 90% cap without changing the upstream proc. */
/mob/living/carbon/human/apply_projectile_effects(obj/projectile/proj, def_zone, armor_check)
	var/previous_block = proj.combat_armor_damage_block
	var/previous_dismemberment = proj.dismemberment
	if(is_combat_armor_flag(proj.armor_flag))
		proj.combat_armor_damage_block = armor_check
		if(armor_check >= 100)
			proj.dismemberment = 0
	. = ..()
	proj.combat_armor_damage_block = previous_block
	proj.dismemberment = previous_dismemberment

/mob/living/carbon/human/check_block(atom/hit_by, damage, attack_text = "the attack", attack_type = MELEE_ATTACK, armour_penetration = 0, damage_type = BRUTE)
	. = ..()
	if(. == SUCCESSFUL_BLOCK && isprojectile(hit_by))
		var/obj/projectile/projectile = hit_by
		projectile.combat_armor_wear = 0

/mob/living/carbon/human/apply_damage(damage = 0, damagetype = BRUTE, def_zone = null, blocked = 0, forced = FALSE, spread_damage = FALSE, wound_bonus = 0, exposed_wound_bonus = 0, sharpness = NONE, attack_direction = null, attacking_item, wound_clothing = TRUE)
	if(forced || damage <= 0 || HAS_TRAIT(src, TRAIT_GODMODE) || !(damagetype in list(BRUTE, BURN, STAMINA)))
		return ..()
	if(isprojectile(attacking_item))
		var/obj/projectile/projectile = attacking_item
		if(!isnull(projectile.combat_armor_damage_block))
			blocked = projectile.combat_armor_damage_block
			projectile.combat_armor_damage_block = null
		if(projectile.combat_armor_target_ref?.resolve() == src)
			var/obj/item/clothing/armor = projectile.combat_armor_ref?.resolve()
			var/wear = projectile.combat_armor_wear
			projectile.combat_armor_wear = 0
			// A shield which supplies a stronger block intercepted this hit before the garment.
			if(blocked == projectile.combat_armor_blocked)
				armor?.damage_combat_armor(wear)
		return ..()
	if(blocked <= 0)
		return ..()
	var/absorbed = min(damage, blocked)
	if(spread_damage)
		var/list/parts = get_bodyparts()
		var/list/armor_coverage = list()
		var/covered_parts = 0
		for(var/obj/item/bodypart/bodypart as anything in parts)
			var/obj/item/clothing/armor = get_combat_armor(bodypart)
			if(!armor || armor.combat_armor_health <= 0)
				continue
			armor_coverage[armor] += 1
			covered_parts++
		if(covered_parts)
			var/actual_absorbed = 0
			for(var/obj/item/clothing/armor as anything in armor_coverage)
				actual_absorbed += armor.damage_combat_armor(absorbed * armor_coverage[armor] / covered_parts)
			absorbed = actual_absorbed
	else
		if(!isbodypart(def_zone))
			def_zone = get_bodypart(check_zone(def_zone || get_random_valid_zone(def_zone))) || get_bodypart()
		var/obj/item/clothing/armor = get_combat_armor(def_zone)
		if(armor)
			absorbed = armor.damage_combat_armor(absorbed)
	blocked = 100 * absorbed / damage
	return ..()

/** Adapts the second damage sink used by armour-checked take_bodypart_damage calls. */
/obj/item/bodypart/receive_damage(brute = 0, burn = 0, blocked = 0, updating_health = TRUE, forced = FALSE, required_bodytype = null, wound_bonus = 0, exposed_wound_bonus = 0, sharpness = NONE, attack_direction = null, damage_source, wound_clothing = TRUE)
	var/damage = max(0, brute) + max(0, burn)
	if(!ishuman(owner) || forced || blocked <= 0 || damage <= 0 || HAS_TRAIT(owner, TRAIT_GODMODE) || (required_bodytype && !(bodytype & required_bodytype)))
		return ..()
	var/mob/living/carbon/human/wearer = owner
	var/obj/item/clothing/armor = wearer.get_combat_armor(src)
	var/absorbed = min(damage, blocked)
	if(armor)
		absorbed = armor.damage_combat_armor(absorbed)
	blocked = 100 * absorbed / damage
	return ..()
