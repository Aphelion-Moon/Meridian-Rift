#define INTERACTION_JSON_FOLDER "config/nova/interactions/"

// Special values
#define INTERACTION_MAX_CHAR 255
#define INTERACTION_COOLDOWN 1 SECONDS

// If an interaction has this category it will not be shown to players
#define INTERACTION_CAT_HIDE "hide"

// If you add a new requirement you also need to implement its checking. See /datum/interaction/proc/allow_act
#define INTERACTION_REQUIRE_SELF_HAND "self_hand"
#define INTERACTION_REQUIRE_TARGET_HAND "target_hand"
/// A penis shown as a bulge: true while its bulge look is drawn (has_bulge()).
#define INTERACTION_REQUIRE_SELF_BULGE "self_bulge"
#define INTERACTION_REQUIRE_TARGET_BULGE "target_bulge"
/// A penis closed off by a worn device, like a chastity cage.
#define INTERACTION_REQUIRE_SELF_CAGED "self_caged"
#define INTERACTION_REQUIRE_TARGET_CAGED "target_caged"
/// A vagina closed off by a worn device, like a chastity belt.
#define INTERACTION_REQUIRE_SELF_BELTED "self_belted"
#define INTERACTION_REQUIRE_TARGET_BELTED "target_belted"
/// At least one arm, for armpit interactions.
#define INTERACTION_REQUIRE_SELF_ARM "self_arm"
#define INTERACTION_REQUIRE_TARGET_ARM "target_arm"

/// Sent to the target of someone else's lewd interaction as its effects land: (mob/living/carbon/human/user, datum/interaction/interaction)
#define COMSIG_HUMAN_LEWD_INTERACTION_RECEIVED "human_lewd_interaction_received"

// Interaction Types: Do we do it to ourself or someone else
#define INTERACTION_SELF "self"
#define INTERACTION_OTHER "other"
