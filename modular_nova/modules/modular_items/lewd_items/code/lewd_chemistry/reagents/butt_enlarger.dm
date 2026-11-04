/// Grows the butt a size every 20 cycles, up to the largest size players can pick, or grows a new one if the mob allows
/// new genital growth. Clothes strain and hurt over the last two sizes.
/datum/reagent/drug/aphrodisiac/butt_enlarger
	name = "denbu tincture"
	description = "A mixture of natural vitamins and valentines plant extract, causing butt enlargement in humanoids."
	color = "#e8ff1b"
	taste_description = "butter with a sweet aftertaste"
	overdose_threshold = 17
	metabolization_rate = 0.25
	life_pref_datum = /datum/preference/toggle/erp/butt_enlargement

/datum/reagent/drug/aphrodisiac/butt_enlarger/life_effects(mob/living/carbon/human/exposed_mob)
	var/obj/item/organ/genital/butt/butt = exposed_mob.get_organ_slot(ORGAN_SLOT_BUTT)
	if(!butt)
		create_butt(exposed_mob)
		return
	var/largest = /datum/preference/numeric/butt_size::maximum
	if(butt.genital_size >= largest) // Fully grown: no more growth or strain.
		return
	enlargement_amount += enlarger_increase_step
	if(enlargement_amount >= enlargement_threshold)
		enlargement_amount = 0
		butt.genital_size++
		update_appearance(exposed_mob, butt)
		var/adjective = butt.genital_size >= largest - 2 ? "[pick("huge", "massive", "jiggly", "hefty", "plump", "thick", "bubbling")] " : ""
		exposed_mob.visible_message(
			span_notice("[exposed_mob]'s [adjective]bottom [pick("expands outward.", "seems to grow larger.", "appears more plump than before.", "suddenly swells up.")]"),
			span_purple("Your [adjective]bottom [pick("expands outward", "grows out", "begins to plump up, growing", "suddenly expands", "swells out")] to size [butt.genital_size]."),
			visible_message_flags = ALWAYS_SHOW_SELF_MESSAGE,
			pref_to_check = /datum/preference/toggle/erp,
		)
	if(butt.genital_size >= largest - 2 && (exposed_mob.w_uniform || exposed_mob.wear_suit) && prob(damage_chance))
		to_chat(exposed_mob, span_danger("Your bottom strains against your clothes!"))
		exposed_mob.apply_damage(1, BRUTE, BODY_ZONE_PRECISE_GROIN)

/// Gives the mob a size 1 butt if they allow new genital growth, setting the DNA's butt to "Pair" so it draws.
/datum/reagent/drug/aphrodisiac/butt_enlarger/proc/create_butt(mob/living/carbon/human/exposed_mob)
	if(CONFIG_GET(flag/disable_lewd_items)) // A new genital would delete itself.
		return
	var/datum/client_interface/player = GET_CLIENT(exposed_mob)
	if(!player?.prefs?.read_preference(/datum/preference/toggle/erp/new_genitalia_growth))
		return
	var/datum/mutant_bodypart/butt_part = exposed_mob.dna.mutant_bodyparts[FEATURE_BUTT]
	if(isnull(butt_part))
		exposed_mob.dna.mutant_bodyparts[FEATURE_BUTT] = build_mutant_part(
			/datum/sprite_accessory/genital/butt/pair::name,
			player.prefs.read_preference(/datum/preference/tri_color/genital/butt),
			player.prefs.read_preference(/datum/preference/tri_bool/genital/butt),
		)
	else if(butt_part.name == SPRITE_ACCESSORY_NONE)
		butt_part.name = /datum/sprite_accessory/genital/butt/pair::name
	var/obj/item/organ/genital/butt/new_butt = new
	new_butt.build_from_dna(exposed_mob.dna, ORGAN_SLOT_BUTT)
	new_butt.Insert(exposed_mob, FALSE, FALSE)
	new_butt.genital_size = 1
	update_appearance(exposed_mob, new_butt)
	to_chat(exposed_mob, span_purple("Your bottom feels warm as it begins to expand outward."))

/obj/item/reagent_containers/cup/bottle/butt_enlarger
	name = "denbu tincture bottle"
	desc = "A bottle of natural vitamins and valentines plant extract that causes butt enlargement."
	list_reagents = list(/datum/reagent/drug/aphrodisiac/butt_enlarger = 30)
	obj_flags_nova = ERP_ITEM

/datum/chemical_reaction/butt_enlarger
	results = list(/datum/reagent/drug/aphrodisiac/butt_enlarger = 8)
	required_reagents = list(
		/datum/reagent/medicine/salglu_solution = 1,
		/datum/reagent/consumable/sugar = 2,
		/datum/reagent/silicon = 3,
		/datum/reagent/drug/aphrodisiac/crocin = 2,
	)
	mix_message = "the reaction gives off a sweet buttery aroma."
	erp_reaction = TRUE
	reaction_tags = REACTION_TAG_CHEMICAL | REACTION_TAG_HARD | REACTION_TAG_ORGAN
