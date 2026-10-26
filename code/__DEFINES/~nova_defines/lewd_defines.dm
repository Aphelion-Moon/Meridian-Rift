#define GENITAL_SKIP_VISIBILITY 0
#define GENITAL_NEVER_SHOW 1
#define GENITAL_HIDDEN_BY_CLOTHES 2
/// Special layering defines beyond normal genital visibility modes.
#define GENITAL_LAYER_BELOW_UNDIES 4
#define GENITAL_LAYER_NORMAL 5
#define GENITAL_LAYER_ABOVE_UNDIES 6
#define GENITAL_LAYER_ABOVE_ALL 7
#define GENITAL_CUSTOM 8

#define GENITAL_STACK_STEP 0.01

/// To prevent an issue with stupidly low negative values.
#define AROUSAL_MINIMUM 0
#define AROUSAL_MINIMUM_DETECTABLE 10
#define AROUSAL_LOW 30
#define AROUSAL_MEDIUM 70
#define AROUSAL_HIGH 85
#define AROUSAL_AUTO_CLIMAX_THRESHOLD 90
#define AROUSAL_LIMIT 100

// Climax target strings built by climax.dm.
#define CLIMAX_TARGET_ASSHOLE "asshole"
#define CLIMAX_TARGET_MOUTH "mouth"

#define REQUIRE_GENITAL_EXPOSED 1
#define REQUIRE_GENITAL_UNEXPOSED 2
#define REQUIRE_GENITAL_ANY 3

#define BREAST_SIZE_FLATCHESTED "Flatchested"
#define BREAST_SIZE_A "A"
#define BREAST_SIZE_B "B"
#define BREAST_SIZE_C "C"
#define BREAST_SIZE_D "D"
// Ouch, my back.
#define BREAST_SIZE_E "E"
#define BREAST_SIZE_F "F"
#define BREAST_SIZE_G "G"
#define BREAST_SIZE_H "H"
#define BREAST_SIZE_I "I"
#define BREAST_SIZE_J "J"
#define BREAST_SIZE_K "K"
#define BREAST_SIZE_L "L"
#define BREAST_SIZE_M "M"
#define BREAST_SIZE_N "N"
#define BREAST_SIZE_O "O"
#define BREAST_SIZE_P "P"
#define BREAST_SIZE_HUGE "Huge"
#define BREAST_SIZE_GIGANTIC "Gigantic"
#define BREAST_SIZE_ENORMOUS "Enormous"
#define BREAST_SIZE_MASSIVE "Massive"
#define BREAST_SIZE_IMPOSSIBLE "Impossible"
#define BREAST_SIZE_BEYOND_MEASUREMENT "beyond measurement"

// Shibari stuff
#define SHIBARI_TIGHTNESS_LOW 1
#define SHIBARI_TIGHTNESS_MED 2
#define SHIBARI_TIGHTNESS_HIGH 3

#define PENIS_ICON_ALT 'modular_nova/master_files/icons/mob/sprite_accessory/genitals/penis_onmob_alt.dmi'
#define PENIS_ICON_TAUR 'modular_nova/master_files/icons/mob/sprite_accessory/genitals/taur_penis_onmob.dmi'
#define TESTICLES_ICON_ALT 'modular_nova/master_files/icons/mob/sprite_accessory/genitals/testicles_onmob_alt.dmi'
#define BREASTS_ICON_ALT 'modular_nova/master_files/icons/mob/sprite_accessory/genitals/breasts_onmob_alt.dmi'

/// Whether a lewd item a human wears hides their mutant parts: an inflated sleeping bag does when hide_if_sleeping_bag is set,
/// a latex catsuit worn without one does when hide_if_catsuit is. A macro on purpose: sprite accessories' is_hidden() asks it
/// for every part on every body update.
#define LEWD_ITEM_HIDES_PARTS(wearer, hide_if_catsuit, hide_if_sleeping_bag) (istype(wearer.wear_suit, /obj/item/clothing/suit/straight_jacket/kinky_sleepbag) \
	? ((hide_if_sleeping_bag) && astype(wearer.wear_suit, /obj/item/clothing/suit/straight_jacket/kinky_sleepbag)?.state_thing == "inflated") \
	: ((hide_if_catsuit) && istype(wearer.w_uniform, /obj/item/clothing/under/misc/latex_catsuit)))
