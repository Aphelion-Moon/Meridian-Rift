/datum/wound/blunt/robotic/moderate
	simple_treat_text = "Splinting the wound will reduce the impact until its <b>screws are secured</b>."

// RCD and plunger repair of a collapsed superstructure.

/// RCD matter spent reforming a collapsed superstructure.
#define ROBOTIC_BLUNT_T3_RCD_COST 25
/// The cost when the RCD draws from a linked silo.
#define ROBOTIC_BLUNT_T3_RCD_SILO_COST (ROBOTIC_BLUNT_T3_RCD_COST / 4)

/datum/wound/blunt/robotic/critical
	treat_text = "Bind the affected limb with gauze or a splint. Repair surgically, or reform the superstructure with an RCD."
	treat_text_short = "Repair surgically, reform with an RCD, or burn the limb and use a crowbar or plunger to reduce severity."
	simple_treat_text = "Repair with surgery or an RCD."
	homemade_treat_text = "The metal can be made malleable by repeated harmful application of any heated instrument until it carries a burn. \
	Afterwards, a crowbar or plunger can reset the metal, reducing the severity of the wound. A plunger also works on badly scorched metal."
	treatable_by = list(/obj/item/construction/rcd, /obj/item/plunger)

/**
 * Reforms the superstructure with an RCD, turning this into a severe wound.
 *
 * Always works. The matter is spent before the reform, so an RCD that can't pay fixes nothing. If you do it on
 * yourself without a diagnostic HUD, it takes longer than the base time and deals 10 brute.
 *
 * Arguments:
 * - treating_rcd: The RCD, which pays from its silo when linked to one.
 * - user: Whoever is using it.
 */
/datum/wound/blunt/robotic/critical/proc/rcd_superstructure(obj/item/construction/rcd/treating_rcd, mob/user)
	if (!treating_rcd.tool_start_check())
		return TRUE
	var/matter_cost = (treating_rcd.silo_link ? ROBOTIC_BLUNT_T3_RCD_SILO_COST : ROBOTIC_BLUNT_T3_RCD_COST)
	if (!treating_rcd.useResource(matter_cost, user, dry_run = TRUE))
		return TRUE

	var/their_or_other = (user == victim ? "[user.p_their()]" : "[victim]'s")
	var/your_or_other = (user == victim ? "your" : "[victim]'s")

	var/base_time = 7 SECONDS
	var/delay_mult = 1
	if (victim == user)
		delay_mult *= 2
	if (HAS_TRAIT(src, TRAIT_WOUND_SCANNED))
		delay_mult *= 0.75
	if (HAS_TRAIT(user, TRAIT_DIAGNOSTIC_HUD))
		delay_mult *= 0.5

	var/final_time = (base_time * delay_mult)
	var/misused = (final_time > base_time) // if we damage the limb when we're done

	var/misused_text = (misused ? "<b>unsteadily</b> " : "")
	var/message = "[user]'s RCD whirs to life as it begins [misused_text]replacing the damaged superstructure of [their_or_other] [limb.plaintext_zone]..."
	var/self_message = "Your RCD whirs to life as it begins [misused_text]replacing the damaged superstructure of [your_or_other] [limb.plaintext_zone]..."
	if (misused)
		user.visible_message(span_danger(message), span_danger(self_message))
	else
		user.visible_message(span_notice(message), span_notice(self_message))

	if (!treating_rcd.use_tool(target = victim, user = user, delay = final_time, volume = 50, extra_checks = CALLBACK(src, PROC_REF(still_exists))))
		return TRUE
	if (!victim) // the limb came off mid-repair, so don't charge for it
		return TRUE
	if (!treating_rcd.useResource(matter_cost, user))
		return TRUE
	playsound(get_turf(treating_rcd), 'sound/machines/ping.ogg', 75) // celebration! we did it

	misused_text = (misused ? ", though it replaced a bit more than it should've..." : "!")
	message = "[user]'s RCD lets out a small ping as it finishes replacing the superstructure of [their_or_other] [limb.plaintext_zone][misused_text]"
	self_message = "Your RCD lets out a small ping as it finishes replacing the superstructure of [your_or_other] [limb.plaintext_zone][misused_text]"
	if (misused)
		user.visible_message(span_danger(message), span_danger(self_message))
		limb.receive_damage(brute = 10, damage_source = treating_rcd, wound_bonus = CANT_WOUND)
	else
		user.visible_message(span_green(message), span_green(self_message))
	to_chat(user, span_green("The superstructure has been reformed! Your next step is to secure the internals via a screwdriver/wrench."))
	replace_wound(new /datum/wound/blunt/robotic/severe)
	return TRUE

/**
 * Pops the superstructure back into shape with a plunger, turning this into a severe wound.
 *
 * The metal has to be malleable, which takes a robotic burn wound on the limb or burn damage of at least 80% of
 * its max. A failed plunge deals 5 brute that can't roll a new wound.
 *
 * Arguments:
 * - treating_plunger: The plunger. A reinforced one works faster.
 * - user: Whoever is plunging.
 */
/datum/wound/blunt/robotic/critical/proc/plunge(obj/item/plunger/treating_plunger, mob/user)
	if (!limb.get_wound_type(/datum/wound/burn/robotic) && limb.burn_dam < limb.max_damage * 0.8)
		to_chat(user, span_warning("The metal isn't soft enough to plunge back into place!"))
		return TRUE
	if (!treating_plunger.tool_start_check())
		return TRUE

	var/their_or_other = (user == victim ? "[user.p_their()]" : "[victim]'s")
	var/your_or_other = (user == victim ? "your" : "[victim]'s")
	user.visible_message(span_notice("[user] begins plunging at the dents on [their_or_other] [limb.plaintext_zone] with [treating_plunger]..."), \
		span_green("You begin plunging at the dents on [your_or_other] [limb.plaintext_zone] with [treating_plunger]..."))

	var/delay_mult = treating_plunger.plunge_mod
	if (HAS_TRAIT(src, TRAIT_WOUND_SCANNED))
		delay_mult *= 0.75

	if (!treating_plunger.use_tool(target = victim, user = user, delay = 6 SECONDS * delay_mult, volume = 50, extra_checks = CALLBACK(src, PROC_REF(still_exists))))
		return TRUE
	if (!victim) // the limb came off mid-repair
		return TRUE

	var/success_chance = 80
	if (victim == user)
		success_chance *= 0.6
	if (HAS_TRAIT(user, TRAIT_DIAGNOSTIC_HUD))
		success_chance *= 1.25
	if (HAS_TRAIT(src, TRAIT_WOUND_SCANNED))
		success_chance *= 1.5

	if (!prob(success_chance))
		user.visible_message(span_danger("[victim]'s [limb.plaintext_zone] splinters from [treating_plunger]'s plunging!"), \
			span_danger("[capitalize(your_or_other)] [limb.plaintext_zone] splinters from your [treating_plunger]'s plunging!"))
		limb.receive_damage(brute = 5, damage_source = treating_plunger, wound_bonus = CANT_WOUND)
		return TRUE

	user.visible_message(span_green("[victim]'s [limb.plaintext_zone] lets out a sharp POP as [treating_plunger] forces it into its normal position!"), \
		span_green("[victim]'s [limb.plaintext_zone] lets out a sharp POP as your [treating_plunger] forces it into its normal position!"))
	to_chat(user, span_green("[capitalize(your_or_other)] [limb.plaintext_zone]'s structure has been reset to its proper position! Your next step is to secure it with a screwdriver/wrench, though bone gel would also work."))
	replace_wound(new /datum/wound/blunt/robotic/severe)
	return TRUE

#undef ROBOTIC_BLUNT_T3_RCD_COST
#undef ROBOTIC_BLUNT_T3_RCD_SILO_COST

// Loosened Screws on the chest and every limb, from 30. BIO_METAL alone still keeps organic limbs out.
/datum/wound_pregen_data/blunt_metal/loose_screws
	required_limb_biostate = BIO_METAL
	viable_zones = list(BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	threshold_minimum = 30

// Metal scars from the severe and critical tiers.
/datum/wound/blunt/robotic
	can_scar = TRUE
	default_scar_file = METAL_SCAR_FILE

/datum/wound/blunt/robotic/moderate
	can_scar = FALSE

/datum/wound/blunt/robotic/severe
	scar_keyword = "bluntsevere"

/datum/wound/blunt/robotic/critical
	scar_keyword = "bluntcritical"

/datum/wound_pregen_data/blunt_metal/generate_scar_priorities()
	return list("[BIO_METAL]")
