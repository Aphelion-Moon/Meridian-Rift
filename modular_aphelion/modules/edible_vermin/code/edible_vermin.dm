/mob/living/basic/mouse
	inhand_holder_type = /obj/item/mob_holder/edible/mouse

/mob/living/basic/cockroach
	inhand_holder_type = /obj/item/mob_holder/edible/cockroach

/mob/living/basic/frog
	inhand_holder_type = /obj/item/mob_holder/edible/frog

/**
 * A held critter that can be eaten alive, in one bite, like any food.
 *
 * It is food only while someone tries to eat it. If the attempt ends without a swallow, it is a
 * plain holder again, so nothing else can use up the meal. Eating deletes the critter instead of
 * killing it, as mobs that eat vermin do, so it leaves no corpse, guts or splatter.
 *
 * Whoever feeds it is asked to confirm first, if it is alive. A critter with a player in it is
 * asked next, and no answer counts as a yes.
 */
/obj/item/mob_holder/edible
	abstract_type = /obj/item/mob_holder/edible
	/// Reagents the critter is worth, all swallowed in one bite
	var/list/food_reagents
	/// Food types, for food preferences
	var/foodtypes = NONE
	/// Tastes it leaves
	var/list/tastes
	/// Verbs for the eating messages, each taking a plain "s"
	var/list/eatverbs
	/// How long it takes to get down when eating it yourself
	var/eat_time = 3 SECONDS
	/// Who is trying to eat it right now
	var/datum/weakref/meal_eater
	/// Whether the critter's player is being asked right now
	var/asking = FALSE
	/// Number of the latest question to the critter's player, so a late answer is ignored
	var/prompt_id = 0
	/// Who the critter's player let eat it, for this attempt only
	var/datum/weakref/allowed_eater
	/// Who the critter's player let feed it to them, for this attempt only
	var/datum/weakref/allowed_feeder
	/// Whether the feeder is being asked to confirm right now
	var/confirming = FALSE

/obj/item/mob_holder/edible/mouse
	food_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/nutriment/vitamin = 2)
	foodtypes = GORE | MEAT | RAW
	tastes = list("fur" = 1, "raw meat" = 1)
	eatverbs = list("devour", "gulp", "swallow")

/obj/item/mob_holder/edible/cockroach
	food_reagents = list(/datum/reagent/consumable/nutriment/protein = 2)
	foodtypes = BUGS | RAW
	tastes = list("crunchy bug" = 1)
	eatverbs = list("chomp", "gobble")
	eat_time = 1 SECONDS

/obj/item/mob_holder/edible/frog
	food_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/nutriment/protein = 2)
	foodtypes = MEAT | RAW
	tastes = list("frog" = 1, "slime" = 1)
	eatverbs = list("devour", "gulp", "swallow")

/// Clicking someone with it outside combat mode feeds it to them, if it may be eaten.
/obj/item/mob_holder/edible/pre_attack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(. || user.combat_mode || !iscarbon(target))
		return
	. = TRUE
	user.changeNext_move(attack_speed)
	var/refusal = eat_refusal(user)
	if(refusal)
		balloon_alert(user, refusal)
		return
	if(asking)
		balloon_alert(user, "it squirms...")
		return
	// nobody to ask, or it's dead already
	if(!user.client || held_mob.stat == DEAD)
		try_meal(target, user)
		return
	if(confirming)
		return
	confirming = TRUE
	var/question = target == user ? "Are you sure you want to eat [held_mob]?" : "Are you sure you want to feed [held_mob] to [target]?"
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(confirm_edible_critter), WEAKREF(src), user, question, WEAKREF(target))

/**
 * Acts on the feeder's answer to whether they want to eat it or feed it to someone.
 *
 * Arguments:
 * - eater: Who would eat it, or null if they are gone.
 * - feeder: Who would feed it to them, the eater when eating it themselves.
 * - answer: The button pressed, or null for none.
 */
/obj/item/mob_holder/edible/proc/feeder_answered(mob/living/carbon/eater, mob/living/feeder, answer)
	confirming = FALSE
	if(answer != "Yes" || QDELETED(eater) || QDELETED(feeder))
		return
	if(!feeder.is_holding(src) || feeder.combat_mode || feeder.incapacitated || !feeder.Adjacent(eater))
		return
	try_meal(eater, feeder)

/**
 * Starts the meal, or asks the critter's player first. Says why when it may not be eaten.
 *
 * Arguments:
 * - eater: Who would eat it.
 * - feeder: Who would feed it to them, the eater when eating it themselves.
 */
/obj/item/mob_holder/edible/proc/try_meal(mob/living/carbon/eater, mob/living/feeder)
	var/refusal = eat_refusal(feeder)
	if(refusal)
		balloon_alert(feeder, refusal)
		return
	if(!has_consent(eater, feeder))
		if(!asking)
			ask_critter(eater, feeder)
		balloon_alert(feeder, "it squirms...")
		return
	start_meal(eater, feeder)

/**
 * Says why the held critter can't be eaten.
 *
 * Arguments:
 * - feeder: Who is eating it or feeding it to someone, or null to ask only about the critter.
 *
 * Returns:
 * - text: A balloon alert, or null if it can be eaten.
 */
/obj/item/mob_holder/edible/proc/eat_refusal(mob/living/feeder)
	// a shapeshifter carries its real body inside, which would go with it
	if(locate(/datum/status_effect/shapechange_mob) in held_mob.status_effects)
		return "it squirms..."
	var/static/list/named_critters = typecacheof(list(/mob/living/basic/mouse/brown/tom, /mob/living/basic/frog/icemoon_facility))
	if(HAS_TRAIT(held_mob, TRAIT_TAMED) || is_type_in_typecache(held_mob, named_critters) || !has_stock_name())
		return "someone's pet!"
	for(var/ally_ref in held_mob.allies)
		var/mob/living/ally = locate(ally_ref)
		// owners are people other than regal rats
		if(ally != held_mob && istype(ally) && !QDELETED(ally) && ally.mind && !isregalrat(ally))
			return "someone's pet!"
	if(feeder && held_mob.stat != DEAD && HAS_TRAIT(feeder, TRAIT_PACIFISM))
		return "don't want to hurt it!"
	return null

/**
 * Returns whether the critter still has the name it was born with.
 *
 * That is its type's own name, or that name with the ice- prefix cockroaches get on ice levels.
 * A regal rat's riot keeps the old name of a roach it turns, so a minion may also have the ice-
 * name of the roach it was.
 */
/obj/item/mob_holder/edible/proc/has_stock_name()
	var/stock_name = initial(held_mob.name)
	if(held_mob.name == stock_name || held_mob.name == "ice-[stock_name]")
		return TRUE
	for(var/mob/living/basic/cockroach/roach_type as anything in typesof(/mob/living/basic/cockroach))
		if(initial(roach_type.minion_path) == held_mob.type && held_mob.name == "ice-[initial(roach_type.name)]")
			return TRUE
	return FALSE

/**
 * Returns whether the critter's player, if it has one, let this eater and feeder have it.
 *
 * An answer counts for one attempt, so the player is asked again on the next.
 *
 * Arguments:
 * - eater: Who would eat it.
 * - feeder: Who would feed it to them, the eater when eating it themselves.
 */
/obj/item/mob_holder/edible/proc/has_consent(mob/living/eater, mob/living/feeder)
	if(!held_mob.client)
		return TRUE
	return allowed_eater?.resolve() == eater && allowed_feeder?.resolve() == feeder

/**
 * Asks the critter's player whether they may be eaten, giving them 10 seconds to answer.
 *
 * Arguments:
 * - eater: Who would eat it.
 * - feeder: Who would feed it to them, the eater when eating it themselves.
 */
/obj/item/mob_holder/edible/proc/ask_critter(mob/living/carbon/eater, mob/living/feeder)
	asking = TRUE
	prompt_id++
	var/datum/weakref/eater_ref = WEAKREF(eater)
	var/datum/weakref/feeder_ref = WEAKREF(feeder)
	addtimer(CALLBACK(src, PROC_REF(critter_answered), prompt_id, eater_ref, feeder_ref, null), 10 SECONDS)
	var/question = eater == feeder ? "[feeder] is trying to eat you!" : "[feeder] is trying to feed you to [eater]!"
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(ask_edible_critter), WEAKREF(src), prompt_id, held_mob, question, eater_ref, feeder_ref)

/**
 * Acts on the answer from the critter's player, or on no answer after 10 seconds.
 *
 * Wriggling free lets the critter go. Any other answer lets this eater and feeder have it, for a
 * meal that starts now: the feeder must still hold it next to the eater and be able to click, as
 * if they clicked again. Only the first answer to the latest question counts.
 *
 * Arguments:
 * - prompt: Number of the question this answers.
 * - eater_ref: Who would eat it.
 * - feeder_ref: Who would feed it to them.
 * - answer: The button pressed, "closed" for a closed prompt, or null for no answer in time.
 */
/obj/item/mob_holder/edible/proc/critter_answered(prompt, datum/weakref/eater_ref, datum/weakref/feeder_ref, answer)
	if(prompt != prompt_id)
		return
	// a late wriggle still lets it go
	if(!asking && answer != "Wriggle free")
		return
	asking = FALSE
	var/mob/living/carbon/eater = eater_ref.resolve()
	var/mob/living/feeder = feeder_ref.resolve()
	var/outcome
	switch(answer)
		if(null)
			outcome = "didn't answer"
		if("closed")
			outcome = "closed the prompt"
		else
			outcome = "chose \"[answer]\""
	var/fed_by = eater == feeder ? "" : ", fed by [key_name(feeder)]"
	held_mob.log_message("[outcome] on being eaten by [key_name(eater)][fed_by].", LOG_ATTACK)
	if(answer == "Wriggle free")
		release()
		return
	if(!eater || !feeder)
		return
	if(!feeder.is_holding(src) || feeder.combat_mode || feeder.incapacitated || !feeder.Adjacent(eater))
		return
	allowed_eater = eater_ref
	allowed_feeder = feeder_ref
	start_meal(eater, feeder)
	// no meal came of it, so they ask again next time
	if(!QDELETED(src) && !meal_eater)
		allowed_eater = null
		allowed_feeder = null

/**
 * Makes the holder food and has the eater try it, as clicking them with food does. Does nothing
 * while someone is trying already.
 *
 * Arguments:
 * - eater: Who eats it.
 * - feeder: Who feeds it to them, the eater when eating it themselves.
 */
/obj/item/mob_holder/edible/proc/start_meal(mob/living/carbon/eater, mob/living/feeder)
	if(meal_eater || DOING_INTERACTION(feeder, eater))
		return
	meal_eater = WEAKREF(eater)
	AddComponentFrom(\
		SOURCE_EDIBLE_INNATE,\
		/datum/component/edible,\
		initial_reagents = food_reagents,\
		foodtypes = foodtypes,\
		eat_time = eat_time,\
		tastes = tastes,\
		eatverbs = eatverbs,\
		bite_consumption = counterlist_sum(food_reagents),\
		on_consume = CALLBACK(src, PROC_REF(swallowed)),\
	)
	RegisterSignal(feeder, COMSIG_DO_AFTER_ENDED, PROC_REF(on_attempt_ended))
	attack(eater, feeder)
	if(!QDELETED(src) && !DOING_INTERACTION(feeder, eater))
		end_meal(feeder)

/**
 * When the feeder stops trying, lets go of a critter that may no longer be eaten, before it is
 * bitten. Otherwise the holder turns plain again a moment later, unless it was swallowed.
 *
 * Arguments:
 * - feeder: Whose action ended.
 */
/obj/item/mob_holder/edible/proc/on_attempt_ended(mob/living/feeder)
	SIGNAL_HANDLER
	var/mob/living/eater = meal_eater?.resolve()
	// another of the feeder's actions ended
	if(eater && DOING_INTERACTION(feeder, eater))
		return
	if(eat_refusal(feeder) || !has_consent(eater, feeder))
		release()
		return
	addtimer(CALLBACK(src, PROC_REF(end_meal), feeder), 1, TIMER_UNIQUE)

/**
 * Makes the holder plain again after an attempt that didn't end in a swallow, and forgets the
 * answer of the critter's player.
 *
 * Arguments:
 * - feeder: Who was feeding it.
 */
/obj/item/mob_holder/edible/proc/end_meal(mob/living/feeder)
	var/mob/living/eater = meal_eater?.resolve()
	if(eater && DOING_INTERACTION(feeder, eater))
		return
	UnregisterSignal(feeder, COMSIG_DO_AFTER_ENDED)
	meal_eater = null
	allowed_eater = null
	allowed_feeder = null
	RemoveComponentSource(SOURCE_EDIBLE_INNATE, /datum/component/edible)
	QDEL_NULL(reagents)

/**
 * Deletes the swallowed critter, which deletes the holder.
 *
 * Arguments:
 * - eater: Who swallowed it.
 * - feeder: Who fed it to them.
 */
/obj/item/mob_holder/edible/proc/swallowed(mob/living/eater, mob/living/feeder)
	var/state = held_mob.stat == DEAD ? "dead" : "alive"
	log_combat(eater, held_mob, "swallowed", addition = feeder == eater ? state : "[state], fed by [key_name(feeder)]")
	if(held_mob.mind)
		held_mob.investigate_log("has been eaten [state] by [key_name(eater)].", INVESTIGATE_DEATHS)
	to_chat(held_mob, span_userdanger("[eater] swallows you whole!"))
	qdel(held_mob)

/**
 * Asks whoever holds a live critter whether they really want to eat it or feed it to someone, and
 * passes the answer to its holder.
 *
 * It keeps only a weakref to the holder, so the holder can still be deleted while the question is up.
 *
 * Arguments:
 * - holder_ref: The holder the critter is in.
 * - feeder: Who is asked.
 * - question: What to ask.
 * - eater_ref: Who would eat it.
 */
/proc/confirm_edible_critter(datum/weakref/holder_ref, mob/living/feeder, question, datum/weakref/eater_ref)
	var/answer = tgui_alert(feeder, question, "Eat it alive", list("Yes", "No"), 10 SECONDS)
	var/obj/item/mob_holder/edible/holder = holder_ref.resolve()
	holder?.feeder_answered(eater_ref.resolve(), feeder, answer)

/**
 * Asks a critter's player whether they may be eaten, and passes the answer to its holder.
 *
 * It keeps only a weakref to the holder, so the holder can still be deleted while the question is up.
 *
 * Arguments:
 * - holder_ref: The holder the critter is in.
 * - prompt: Number of the question, given back with the answer.
 * - critter: The critter being asked.
 * - question: What to ask.
 * - eater_ref: Who would eat it.
 * - feeder_ref: Who would feed it to them.
 */
/proc/ask_edible_critter(datum/weakref/holder_ref, prompt, mob/living/critter, question, datum/weakref/eater_ref, datum/weakref/feeder_ref)
	var/asked_at = world.time
	var/answer = tgui_alert(critter, question, "Being eaten", list("Wriggle free", "Let them"), 10 SECONDS)
	if(!answer && world.time < asked_at + 10 SECONDS)
		answer = "closed"
	var/obj/item/mob_holder/edible/holder = holder_ref.resolve()
	holder?.critter_answered(prompt, eater_ref, feeder_ref, answer)

/**
 * A cockroach that dies whole leaves a dead roach and no guts, in the hand or pocket that held it,
 * unless it keeps its own body. A bloodroach bursts, so it leaves its usual mess and no body.
 */
/mob/living/basic/cockroach/death(gibbed)
	// no item when the body stays, a shapeshifter's caster comes back, or it bursts
	if(gibbed || stat == DEAD || !(basic_mob_flags & DEL_ON_DEATH) || (locate(/datum/status_effect/shapechange_mob) in status_effects) || istype(src, /mob/living/basic/cockroach/bloodroach))
		return ..()
	var/atom/corpse_spot = drop_location()
	var/mob/living/carrier
	var/hand_index
	var/pocket_slot
	var/obj/item/mob_holder/holder = loc
	if(istype(holder))
		corpse_spot = holder.loc
		if(isliving(corpse_spot))
			carrier = corpse_spot
			hand_index = carrier.get_held_index_of_item(holder)
			pocket_slot = carrier.get_slot_by_item(holder) & (ITEM_SLOT_LPOCKET | ITEM_SLOT_RPOCKET)
			corpse_spot = carrier.drop_location()
	if(istype(corpse_spot, /obj/machinery/microwave))
		return ..()
	var/obj/item/food/deadroach/corpse = new(corpse_spot)
	corpse.copy_corpse(src)
	// the guts are still in the body
	RemoveElement(/datum/element/death_drops, /obj/effect/decal/cleanable/insectguts)
	// deleting us takes the holder too, which frees its hand or pocket
	. = ..()
	if(hand_index)
		carrier.put_in_hand(corpse, hand_index)
	else if(pocket_slot)
		carrier.equip_to_slot_if_possible(corpse, pocket_slot, disable_warning = TRUE)

/// A cockroach that died whole, lying on its back
/obj/item/food/deadroach
	name = "dead cockroach"
	desc = "It lies on its back with its legs in the air."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "cockroach_no_animation"
	w_class = WEIGHT_CLASS_TINY
	food_reagents = list(/datum/reagent/consumable/nutriment/protein = 2)
	foodtypes = BUGS | RAW
	tastes = list("crunchy bug" = 1)
	eatverbs = list("chomp", "gobble")
	bite_consumption = 2
	eat_time = 1 SECONDS
	decomp_type = null
	// random food, gifts and mystery boxes don't roll one
	spawn_blacklisted = TRUE

/obj/item/food/deadroach/Initialize(mapload)
	. = ..()
	transform = transform.Scale(1, -1)

/**
 * Takes the dead roach's name, sprite and tint.
 *
 * Arguments:
 * - dead_roach: The cockroach this was.
 */
/obj/item/food/deadroach/proc/copy_corpse(mob/living/basic/cockroach/dead_roach)
	name = "dead [dead_roach.name]"
	icon = dead_roach.icon
	icon_state = dead_roach.icon_dead
	if(dead_roach.color)
		add_atom_colour(dead_roach.color, FIXED_COLOUR_PRIORITY)
