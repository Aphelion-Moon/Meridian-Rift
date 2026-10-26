/// The custom hair and tattoo awards' 76 by 76 icons.
#define CUSTOM_SPRITE_ACHIEVEMENTS 'modular_aphelion/modules/custom_sprites/icons/achievements.dmi'

/// The artist's award for applying someone else's accepted custom hair or facial hair.
/datum/award/achievement/misc/custom_style_given
	name = "Barberella"
	desc = "It's ok, it'll grow back..."
	database_id = "Custom Hairstyle Given"
	icon = CUSTOM_SPRITE_ACHIEVEMENTS
	icon_state = "custom_style_given"

/// The recipient's award for accepted custom hair or facial hair someone else applied.
/datum/award/achievement/misc/custom_style_received
	name = "I'm Just a Boy with a New Haircut"
	desc = "And That's a Pretty Nice Haircut!"
	database_id = "Custom Hairstyle Received"
	icon = CUSTOM_SPRITE_ACHIEVEMENTS
	icon_state = "custom_style_received"

/// The artist's award for applying someone else's accepted custom tattoo.
/datum/award/achievement/misc/custom_tattoo_given
	name = "Leave Your Mark"
	desc = "You've made a lasting impression."
	database_id = "Custom Tattoo Given"
	icon = CUSTOM_SPRITE_ACHIEVEMENTS
	icon_state = "custom_tattoo_given"

/// The recipient's award for an accepted custom tattoo someone else applied.
/datum/award/achievement/misc/custom_tattoo_received
	name = "Fresh Ink"
	desc = "Wait this is permanent?"
	database_id = "Custom Tattoo Received"
	icon = CUSTOM_SPRITE_ACHIEVEMENTS
	icon_state = "custom_tattoo_received"

#undef CUSTOM_SPRITE_ACHIEVEMENTS
