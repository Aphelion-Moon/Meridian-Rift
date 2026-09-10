## Combat reform

Module ID: REFORM_COMBAT

### Description

This module combines humanoid health and damage slowdown tuning, flat armour
protection and durability, projectile AP transfer, stamina-based security baton
takedowns, and a miss penalty for projectiles aimed at arms or legs.
All balance settings live in `code/__DEFINES/~aphelion_defines/reform_combat.dm`.
Edit the defines and rebuild; no other file needs changing to tune these values.

| Define                                    | Default | Meaning                                                                    |
| ----------------------------------------- | ------- | -------------------------------------------------------------------------- |
| `REFORM_COMBAT_MAX_HEALTH`                | 150     | Standard humanoid maximum health; previously 135.                          |
| `REFORM_COMBAT_SOFT_CRIT_THRESHOLD`       | 0       | Remaining health at soft crit, before runtime modifiers.                   |
| `REFORM_COMBAT_HARD_CRIT_THRESHOLD`       | -30     | Remaining health at hard crit.                                             |
| `REFORM_COMBAT_MAX_STAMINA`               | 162     | Maximum humanoid stamina damage.                                           |
| `REFORM_COMBAT_STAMINA_CRIT_THRESHOLD`    | 135     | Stamina damage at incapacitation, before runtime modifiers.                |
| `REFORM_COMBAT_DAMAGE_SLOWDOWN_THRESHOLD` | 60      | Health or stamina damage at which movement slowdown starts; previously 40. |
| `REFORM_COMBAT_ARMOR_RATING_PER_TIER`     | 10      | Rating points per displayed armour pip.                                   |
| `REFORM_COMBAT_ARMOR_BLOCK_PER_TIER`      | 5       | Flat damage intercepted per pip.                                         |
| `REFORM_COMBAT_ARMOR_HEALTH_PER_TIER`     | 75      | Maximum armour durability per tier.                                      |
| `REFORM_COMBAT_ARMOR_REPAIR_TIME`         | 10 s    | Time to apply an armour repair kit.                                       |
| `REFORM_COMBAT_LIMB_MISS_CHANCE`          | 100     | Percentage of failed arm/leg accuracy rolls that miss carbon targets entirely; previously 0. |

Soft and hard crit are remaining-health values, not damage totals. Lower values
delay incapacitation. Keep hard crit below soft crit and above the existing death
threshold of -100. Maximum health and stamina must be positive.
These are compile-time settings, applied to humanoids on initialization.
Custom humanoid health offsets and existing runtime crit modifiers are preserved.

`REFORM_COMBAT_STAMINA_CRIT_THRESHOLD` is independent of the stamina damage cap.
Its default is 135. Keep it positive and at or below `REFORM_COMBAT_MAX_STAMINA`
so stamina damage can reach it. Changing the cap, maximum health, or configured
soft/hard crit thresholds does not change stamina incapacitation. Runtime soft-crit modifiers,
such as mood, still affect stamina as before. Temporary stamina-cap effects retain
their existing independent behavior; they do not change the configured threshold.

Stamina entry, recovery, and HUD scaling share one threshold proc. No baseline is
stored on each mob. The HUD scales to the actual threshold, including runtime
modifiers. Non-humanoids retain their original health-based threshold calculation.
The stamina effect's initial extra damage checks the mob's actual cap instead of
the old hardcoded 162. Stamina regeneration and diminishing returns are unchanged.

Humanoid damage slowdown starts at `REFORM_COMBAT_DAMAGE_SLOWDOWN_THRESHOLD`,
using the greater of health damage and stamina damage. The default raises its
onset from 40 to 60 damage. Once active, the original `damage / 75` movement-delay
contribution applies. The divisor controls the penalty's growth, independently
of its onset. The threshold is a cutoff, so at 60 damage the penalty starts at
0.8 rather than growing from zero. Other movement modifiers still apply normally.

Armour pips are rounded down using the existing protection-class convention.
Each pip blocks 5 damage. A garment's tier is its highest Melee, Bullet or Laser
class; each tier grants 75 durability. Bullet V therefore blocks 25 bullet damage
and provides at least 375 maximum durability. The highest-tier garment covering
each bodypart is the only protective layer used there. Equal tiers prefer outerwear,
then headwear. A broken higher-tier piece still occupies that layer until removed.

Armour intercepts the lesser of incoming damage, its flat block and its remaining
durability. It loses that intercepted amount, including on fully stopped hits.
At zero durability it stops protecting against damage and wounds. The garment is
retained for repair; biological sealing is preserved. Ordinary clothing repairs
do not replenish armour durability. Rating changes update maximum durability
while preserving wear and cannot restore broken armour.

Projectile AP transfers a fraction of the intercepted damage to the wearer:

- Below the rating for the projectile's damage category: 0% transfer.
- Equal to that rating: 25% transfer.
- Between one and two times that rating: linear scaling from 25% to 100%.
- At least twice that rating, or no protection: 100% transfer.

AP comparisons use the underlying rating, so Bullet V with rating 50 has its
thresholds at 50 and 100 AP. Pre-hit adjustments to AP are respected. The formula
above the first threshold is `clamp(0.25 + 0.75 * (AP / rating - 1), 0.25, 1)`.
Overflow always reaches the wearer. AP does not reduce durability wear:
`wearer damage = incoming - intercepted + intercepted * transfer`.

For a 40-damage bullet against intact Bullet V:

| Projectile AP | Wearer damage | Durability spent |
| ------------- | ------------- | ---------------- |
| 0 or 49       | 15            | 25               |
| 50            | 21.25         | 25               |
| 75            | 30.625        | 25               |
| 100 or more   | 40            | 25               |

The resulting blocked percentage also governs projectile effects and the existing
embedding guard. A completely stopped projectile cannot embed, dismember or leak damage
through the upstream 90% damage-reduction cap. Armour previews do not spend
durability; the actual hit spends it once. Shields prevent that wear when they
intercept the projectile first.

The bulky, single-use `/obj/item/armor_repair_kit` restores a garment to full
durability after ten seconds. Use it on the garment, on a wearer while targeting
the relevant bodypart, or on a MOD control unit to repair its chestplate. Cargo
can order three kits in the Security "Armour Repair Kits" crate. MOD pieces use
their runtime theme/module ratings and retain their wear through deployment,
retraction and changes to ratings. Examine shows tier, durability and breakage.

Human physical armour queries carry flat damage points in the existing numeric
`blocked` argument. `apply_damage` converts these to the equivalent percentage
once the incoming damage is known, then uses the normal damage and wound pipeline.
The bodypart damage sink performs the same conversion for armour-checked calls
which bypass `apply_damage`; ordinary damage passes zero there and is not blocked twice.
No damage argument or pending-check cache is added to `run_armor_check` or its
callers. Melee and thrown AP retain their original rating-based penetration
formula before conversion to flat points. Biological/wound queries and nonhuman
mobs retain their percentage calculations. Intrinsic armour supplies a fallback
where there is no tiered garment, without clothing durability.

Projectile checks already know the incoming damage, so they return a percentage.
A scoped, single-use value on the projectile carries this percentage past the
upstream cap during the primary damage application. It is restored when effects
finish, including nested hits, without changing upstream projectile or embedding
code. The pre-hit garment is held by weak reference until its wear is applied.

Security batons have no fixed knockdown duration. Their delayed collapse callback
is skipped when that duration is zero, so takedowns depend on accumulated stamina
damage. The existing 60 stamina damage and 2.5-second attack cooldown still apply.
At the default 135 stamina incapacitation threshold, a fresh target requires three
full-strength hits, taking at least five seconds from the first hit. Armor,
resistance, and runtime threshold modifiers can change this. Other baton types
retain their existing behavior.

Projectile arm and leg targeting uses the existing accuracy roll, including range,
projectile accuracy, and designated-target modifiers. At the default setting,
failure passes through carbon targets without damage, wounds, embedding, or hit
effects. The projectile continues and can hit other targets or obstacles. Each
target is recorded in the existing impact list, so a missed target cannot trigger
repeated rolls from the same passing projectile. Unsuppressed misses produce a
combat message.

With the standard accuracy values of 100 minus 7 per tile, arm/leg shots miss 14%
of the time at two tiles, 35% at five tiles, and 49% at seven tiles. These are
accuracy-roll probabilities, conditional on the projectile reaching a carbon
target; physical spread and obstructions still apply. Accuracy retains its
existing clamp of 5% to 100%. There is no new point-blank exemption.

`REFORM_COMBAT_LIMB_MISS_CHANCE` ranges from 0 to 100 and applies only after a
failed accuracy roll. At 50, half of those failures miss and half use the old
weighted random body-zone fallback. At 0, the original targeting probabilities
apply. Hands and feet count as their corresponding arms and legs. Chest, head,
and groin aim, non-carbon targets, and melee attacks retain their existing
targeting behavior. A random limb hit from chest/head aim does not incur this
penalty. Successful hits retain their original damage and wound behavior.

### TG Proc/File Changes

- `code/modules/projectiles/projectile.dm`: `impact` resolves the zone through the
  module; `process_hit_loop` passes missed carbon targets before pre-hit effects.
- `code/game/objects/items/weaponry/melee/baton.dm`: security baton delayed collapse
  is scheduled only when its knockdown duration is positive.
- `code/modules/mob/living/carbon/human/human.dm`: `Initialize` applies combat settings;
  `updatehealth` uses the configured damage slowdown threshold.
- `code/modules/mob/living/carbon/damage_procs.dm`: stamina entry uses the shared threshold.
- `code/datums/status_effects/debuffs/stamcrit.dm`: stamina recovery uses the shared
  threshold; initial extra stamina damage respects the actual cap.
- `code/modules/mob/living/living.dm`: the stamina HUD uses the shared threshold.
- `code/modules/mob/living/living_defense.dm`: the previous branch-specific AP
  changes are fully reverted; this file matches the pre-reform version.
- `tgstation.dme`: includes the defines and module code.

### Modular Overrides

- `code/baton.dm`: security baton knockdown duration is zero.
- `code/health.dm`: humanoid `get_stamina_crit_threshold` specializes the new living proc.
- `code/armor.dm`: human armour queries, damage conversion, projectile AP and shield
  interception. Existing upstream attack callers remain unchanged.
- `code/armor_durability.dm`: clothing durability, runtime rating updates, examine
  information, generic repair supplies and their cargo pack.

### Modular helpers

- `code/projectile_targeting.dm`: resolves limb accuracy failures and miss feedback,
  using the projectile's existing phasing and impact bookkeeping.

### Defines

All settings, including the independent stamina incapacitation threshold, are in
`code/__DEFINES/~aphelion_defines/reform_combat.dm`.

### Included files that are not contained in this module

- `code/__DEFINES/~aphelion_defines/reform_combat.dm`.

### Credits

Meridian contributors.
