/*
I'm creatively bankrupt so I recycle names from smarter people.
That's a trend, isn't it?  Wild.
*/
/datum/language/tradeband
	name = "Tradeband"
	desc = "The unified language of spacefaring Gypak is lost to the wider regions of space. \
	For bereft of their homeworld, so too did they abandon their native tongue. <br>\
	What remains is a language as confusing as it is hostile, intended for inter-fleet communication and establishing a common tongue with outsiders."
	key = "T"//Schechi does the same thing. Shut up. I'm stealing the uppercase.
	space_chance = 90
	sentence_chance = 35
	between_word_sentence_chance = 10
	between_word_space_chance = 75
	additional_syllable_low = 0
	additional_syllable_high = 6
	syllables = list(//We just make use of Bay's old Selenian list. Is this reused here? I 'unno! Sorry.
	"al", "an", "ar", "as", "at", "ed", "er", "ha", "he", "hi", "is", "le", "me", "on", "se", "ti",
		"ve", "wa", "are", "ent", "for", "had", "hat", "hin", "ch", "be", "abe", "die", "sch", "aus",
		"ber", "che", "que", "ait", "men", "ave", "con", "com", "eta", "eur", "est", "ing", "ver", "was",
		"hin", "deed", "accord", "caveat", "pledge", "rights", "et", "ex", "bono", "quo", "pro", "ad",
		"ek", "aur", "ki", "ki", "ke", "de", "ki", "ne", "ek", "aar", "ain", "ki", "me", "dei", "dekh"
	)
	icon = 'modular_nova/master_files/icons/misc/language.dmi'
	icon_state = "tradeband"//We just butcher some poor icon here.
	default_priority = 90

/datum/language/tradeband/get_random_name(
	gender = NEUTER,
	name_count = default_name_count,
	syllable_min = default_name_syllable_min,
	syllable_max = default_name_syllable_max,
	force_use_syllables = FALSE,
)
	if(force_use_syllables)
		return ..()

	var/newname = ""
	for(var/i in 1 to rand(2, 3))
		newname += pick(list("cer", "cas", "ko", "mi", "lo", "la", "lu", "di", "yi", "yu", "ri", "re", "ro", "ra", "ru"))
	return capitalize(newname)
