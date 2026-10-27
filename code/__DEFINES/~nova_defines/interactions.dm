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
/// A bulge that still shows some of the penis: drawn over the cloth, or behind a cover cut or lifted for it
/// (bulge_pokes_out()).
#define INTERACTION_REQUIRE_SELF_POKES_OUT "self_pokes_out"
#define INTERACTION_REQUIRE_TARGET_POKES_OUT "target_pokes_out"
/// A penis closed off by a worn device, like a chastity cage.
#define INTERACTION_REQUIRE_SELF_CAGED "self_caged"
#define INTERACTION_REQUIRE_TARGET_CAGED "target_caged"
/// A vagina closed off by a worn device, like a chastity belt.
#define INTERACTION_REQUIRE_SELF_BELTED "self_belted"
#define INTERACTION_REQUIRE_TARGET_BELTED "target_belted"
/// At least one arm, for armpit interactions.
#define INTERACTION_REQUIRE_SELF_ARM "self_arm"
#define INTERACTION_REQUIRE_TARGET_ARM "target_arm"
/// A penis present, unblocked and at least half-hard (AROUSAL_PARTIAL or more).
#define INTERACTION_REQUIRE_SELF_HALF_HARD "self_half_hard"
#define INTERACTION_REQUIRE_TARGET_HALF_HARD "target_half_hard"
/// Visibly sweating (is_visibly_sweaty()), for interactions that sweat unlocks.
#define INTERACTION_REQUIRE_SELF_SWEATY "self_sweaty"
#define INTERACTION_REQUIRE_TARGET_SWEATY "target_sweaty"
/// A chest with nipples to play with: breasts present and not nippleless pecs.
#define INTERACTION_REQUIRE_SELF_NIPPLES "self_nipples"
#define INTERACTION_REQUIRE_TARGET_NIPPLES "target_nipples"

/// Sent to the target of someone else's lewd interaction as its effects land: (mob/living/carbon/human/user, datum/interaction/interaction)
#define COMSIG_HUMAN_LEWD_INTERACTION_RECEIVED "human_lewd_interaction_received"

// Interaction Types: Do we do it to ourself or someone else
#define INTERACTION_SELF "self"
#define INTERACTION_OTHER "other"
