/// A list of vars that shouldn't be tracked by persistence.
GLOBAL_LIST_INIT(modular_persistence_ignored_vars, list(
	"datum_flags",
	"_datum_components",
	"_listen_lookup",
	"tgui_shared_states",
	"gc_destroyed",
	"_active_timers",
	"_status_traits",
	"_signal_procs",
	"cached_ref",
	"weak_reference",
	"cooldowns",
	"__auxtools_weakref_id",
	"tag",
	"type",
	"parent_type",
	"owner_brain",
	"vars",
	"stored_character_slot_index",
	"stored_ckey", // Identity comes from admission, never saved JSON.
))

/// Normalizes an admitted or cryo account key, including aghost's prefix. An absent key has no save identity.
/proc/modular_persistence_account_key(account_key)
	if(!istext(account_key) || !length(account_key))
		return null
	return ckey(replacetext(account_key, "@", ""))

/obj/item/organ/brain
	/// The modular persistence data for a character.
	var/datum/modular_persistence/modular_persistence

/obj/item/organ/brain/Destroy(force)
	if(!QDELETED(modular_persistence))
		qdel(modular_persistence)
	modular_persistence = null
	return ..()

/// Saves the contents of the modular persistence datum for the player's client to their file.
/datum/controller/subsystem/persistence/proc/save_modular_persistence()
	for(var/mob/living/carbon/human/player in GLOB.human_list)
		player.save_individual_persistence()

/// Loads the contents of the player's modular_persistence file to their character.
/datum/controller/subsystem/persistence/proc/load_modular_persistence(obj/item/organ/brain/brain)
	if(!brain)
		return FALSE

	if(!ishuman(brain.owner))
		return FALSE

	var/mob/living/carbon/human/player = brain.owner
	var/account_key = modular_persistence_account_key(player.mind?.key)
	var/character_slot = player.mind?.original_character_slot_index
	if(!account_key || !isnum(character_slot) || character_slot < 1 || character_slot != round(character_slot))
		return FALSE
	// Loading the same admission twice must not discard its live data, or bind it to a different character.
	if(!QDELETED(brain.modular_persistence))
		return brain.modular_persistence.stored_ckey == account_key && brain.modular_persistence.stored_character_slot_index == character_slot

	var/json_file = file("data/player_saves/[account_key[1]]/[account_key]/modular_persistence.json")
	var/list/json = fexists(json_file) ? json_decode(file2text(json_file)) : null

	brain.modular_persistence = new(brain, islist(json) ? json["[character_slot]"] : null, account_key, character_slot)
	return TRUE

/// The master persistence datum. Add vars onto this in your own code. Just be aware that you'll need to use simple data types, such as strings, ints, and lists.
/datum/modular_persistence
	/// The human that this is attached to.
	var/datum/weakref/owner_brain
	/// The owner's character slot index.
	var/stored_character_slot_index
	/// Account admitted with this character slot; brain/body changes must not change the save destination.
	var/stored_ckey

/datum/modular_persistence/New(obj/item/organ/brain/brain, list/persistence_data, account_key, character_slot)
	owner_brain = WEAKREF(brain)
	. = ..()

	var/obj/item/organ/brain/our_brain = owner_brain?.resolve()
	if(!our_brain)
		owner_brain = null
		return

	stored_ckey = modular_persistence_account_key(account_key || our_brain.owner?.mind?.key)
	stored_character_slot_index = character_slot || our_brain.owner?.mind?.original_character_slot_index
	if(!stored_ckey || !isnum(stored_character_slot_index) || stored_character_slot_index < 1 || stored_character_slot_index != round(stored_character_slot_index))
		CRASH("Tried to create modular persistence without an admitted account and character slot!")

	if(!persistence_data)
		return

	for(var/var_name in vars)
		if(var_name in GLOB.modular_persistence_ignored_vars)
			continue

		var/var_entry = persistence_data[var_name]

		if(var_entry)
			vars[var_name] = var_entry
	if(findtext(nif_path, "/obj/item/organ/internal"))
		var/trimmed_nif_path = copytext(nif_path, length("/obj/item/organ/internal") + 1)
		nif_path = "/obj/item/organ[trimmed_nif_path]"
	if(!our_brain.owner)
		CRASH("Tried to load modular persistence on a brain with no owner! How did this happen?! (\ref[brain], [brain.brainmob?.ckey], [brain])")

	var/mob/living/carbon/human/human = our_brain.owner
	human.load_nif_data(src)

/datum/modular_persistence/Destroy(force)
	owner_brain = null
	return ..()

// On a base datum, this should be empty, at a glance.
/datum/modular_persistence/proc/serialize_contents_to_list()
	var/list/returned_list = list()

	var/obj/item/organ/brain/our_brain = owner_brain?.resolve()
	if(!our_brain)
		owner_brain = null
		return

	// A removed brain has no body to sample. A different character's implants cannot overwrite this record.
	if(ishuman(our_brain.owner))
		var/mob/living/carbon/human/human = our_brain.owner
		if(modular_persistence_account_key(human.mind?.key) == stored_ckey && human.mind.original_character_slot_index == stored_character_slot_index)
			human.save_nif_data(src)

	for(var/var_name in vars)
		if(var_name in GLOB.modular_persistence_ignored_vars)
			continue

		var/var_entry = vars[var_name]

		if(!isnull(var_entry))
			returned_list[var_name] = var_entry

	return returned_list

/// Saves the held persistence data to where it needs to go.
/datum/modular_persistence/proc/save_data(ckey)
	var/obj/item/organ/brain/our_brain = owner_brain?.resolve()
	if(!our_brain)
		owner_brain = null
		return

	// Cryo can supply the admitted key (including aghost's @ prefix), but cannot redirect another character's record.
	if(ckey && modular_persistence_account_key(ckey) != stored_ckey)
		return FALSE
	ckey = stored_ckey
	if(!ckey)
		CRASH("Modular persistence save called on a brain with no ckey! How did this happen?! (\ref[our_brain], [our_brain])")

	var/json_file = file("data/player_saves/[ckey[1]]/[ckey]/modular_persistence.json")
	var/list/json = fexists(json_file) ? json_decode(file2text(json_file)) : list()
	fdel(json_file)

	if(!islist(json))
		json = list()

	json["[stored_character_slot_index]"] = serialize_contents_to_list()
	WRITE_FILE(json_file, json_encode(json))
	return TRUE

/**
 * Moves this character's existing record to a replacement brain, retaining the admitted account and slot.
 * The destination must be unused and either detached or in the same body; unrelated records cannot be overwritten.
 */
/datum/modular_persistence/proc/transfer_to_brain(obj/item/organ/brain/new_brain)
	var/obj/item/organ/brain/old_brain = owner_brain?.resolve()
	if(!old_brain || old_brain.modular_persistence != src)
		CRASH("Modular persistence transfer called without its owning brain!")
	if(new_brain == old_brain)
		return TRUE
	if(QDELETED(new_brain) || new_brain.modular_persistence || (new_brain.owner && new_brain.owner != old_brain.owner))
		return FALSE
	old_brain.modular_persistence = null
	new_brain.modular_persistence = src
	owner_brain = WEAKREF(new_brain)
	return TRUE

/// Saves the persistence data for the owner.
/mob/living/carbon/human/proc/save_individual_persistence(ckey)
	var/obj/item/organ/brain/brain = get_organ_slot(ORGAN_SLOT_BRAIN)

	return brain?.modular_persistence?.save_data(ckey)
