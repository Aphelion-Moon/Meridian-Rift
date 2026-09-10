/// Standard humanoid maximum health. Original: 135. Custom subtype health offsets are preserved.
#define REFORM_COMBAT_MAX_HEALTH 150
/// Remaining health at which humanoids enter soft crit. Original: 0. Lower values delay crit.
#define REFORM_COMBAT_SOFT_CRIT_THRESHOLD 0
/// Remaining health at which humanoids enter hard crit. Original: -30. Keep below soft crit and above death (-100).
#define REFORM_COMBAT_HARD_CRIT_THRESHOLD -30
/// Humanoid stamina damage cap. Original: 162. Independent of maximum health.
#define REFORM_COMBAT_MAX_STAMINA 162

/// Stamina damage at incapacitation before runtime modifiers. Original: 135. Independent of the cap; keep positive and at or below it.
#define REFORM_COMBAT_STAMINA_CRIT_THRESHOLD 135
/// Health or stamina damage at which humanoid movement slowdown starts. Original: 40. Higher values delay slowdown.
#define REFORM_COMBAT_DAMAGE_SLOWDOWN_THRESHOLD 60
/// Rating points represented by one displayed armour pip.
#define REFORM_COMBAT_ARMOR_RATING_PER_TIER 10
/// Damage stopped by each armour pip.
#define REFORM_COMBAT_ARMOR_BLOCK_PER_TIER 5
/// Maximum durability per tier, using the highest melee, bullet or laser rating.
#define REFORM_COMBAT_ARMOR_HEALTH_PER_TIER 75
/// Time needed to apply a generic armour repair kit.
#define REFORM_COMBAT_ARMOR_REPAIR_TIME (10 SECONDS)
/// Percentage of failed arm/leg accuracy rolls that miss carbon targets entirely. Original: 0. Range: 0 to 100.
#define REFORM_COMBAT_LIMB_MISS_CHANCE 100
