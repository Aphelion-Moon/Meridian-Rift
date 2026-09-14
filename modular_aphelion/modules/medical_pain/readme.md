# Medical pain

Module ID: `MEDICAL_PAIN`

## Description

Organic human bodies receive an owned medical-pain datum. Synthetic and other
nonorganic bodies retain the previous health-based movement penalty. Species can
set `medical_pain_capacity` to zero to opt out; ordinary capacity is 200, separate
from maximum health. Nova's preference-controlled roleplay pain is independent.

Pain equals organic limb brute damage plus 1.2 times burn damage, half toxin
damage, wound/surgery surcharges, and capped organ contributions. Oxygen loss and
stamina add no pain. Limb damage is deliberately unweighted by body damage
coefficients. Each limb uses its strongest wound/surgery surcharge. Wounds add
5/15/25 for moderate/severe/critical severity; bone wounds use the existing splint
factor. Incisions add 5/15/25 according to depth. Major organs contribute up to 20,
eyes and ears up to 10, normalized to their severe damage thresholds, with a
combined organ cap of 60. Brain tissue, cosmetic organs, implants, robotic organs
and stumps contribute zero.

Untreated fractures continue contributing after brute healing; splints reduce
that contribution without repairing the bone. An isolated healed fracture is
below the first general symptom threshold but still appears in the estimated
scanner score and retains its existing wound penalties.

Symptoms start at 20/30/40/60/70/80 percent. Life processing permits up to two
upward transitions every two seconds, so severe pain sets in faster without
shortening the life cadence. Recovery crosses five percentage points below
each onset boundary. Movement slowdown from no pain through overwhelming pain
is 0/0/0.3/0.8/1.5/2.25/3; the first symptom stage only informs the patient.
The existing `damage_slowdown` modifier uses the
strongest of pain, oxygen-plus-toxin deficiency, and exhaustion, preserving its
existing threshold of 40 and divisor of 75 for non-pain damage. Limping and other
physical wound/organ effects remain separate.

Hardcrit-range health keeps a minimum movement slowdown of 1.5 even under
analgesia, because near-death patients stay impaired whether or not they feel
it. The dead, godmode, stasis, and nonorganic bodies stay exempt, and the
modifier type is unchanged so stimulants, equipment, and ability exemptions
keep their broader behavior.

Health updates recalculate immediately without advancing symptoms. Life samples
all injury and treatment state on the existing two-second cadence, including
organ repair, surgery, splints, limb changes, and medicine removal that do not
update health. Those changes therefore take effect within one life tick. No new
global subsystem, per-patient processor, or duplicate injury ledger is used.
Death, stasis entry, species loss and pain-immunity changes clear or recalculate
symptoms immediately. Revival, full healing and species gain resample the body;
clearing a status alone cannot erase untreated pain. Scanner queries sample
current injuries and drugs without advancing stages or mutating the patient.

## Medicines and compatibility

Only active bloodstream metabolism supplies relief. Stomach contents, stopped
metabolism, stasis, death, and liver-blocked non-self-consuming reagents do not.
The strongest medicine wins; doses extend duration rather than add strength.

| Tier          | Relief | Examples                   |
| ------------- | -----: | -------------------------- |
| Mild          |     25 | Granibitaluri              |
| Moderate      |     40 | Miner's salve              |
| Determination |     60 | Existing wound second wind |
| Strong        |     80 | Morphine                   |
| Surgical      |    100 | Lidocaine                  |

Surgical adequacy is explicit and separate from the numeric score. Strong
analgesics, determination and lidocaine preserve surgical and fracture handling
numbing. Mild medicines no longer act as full anesthesia. Drug metabolism,
addiction and overdose behavior is retained. Determination's withdrawal stamina
damage is capped at 20 alongside returning pain.

Morphine no longer grants general damage-slowdown immunity. Other existing
mobility exemptions (stimulants, muscle stimulant, status buffs, equipment,
implants and abilities) retain their broader mobility behavior because the
modifier type is preserved. They may suppress movement impairment while the
pain alert remains.

Deliberate non-drug `TRAIT_ANALGESIA` sources remain full pain immunity: Numb,
mutations and special trauma/ability/equipment effects. Administrative medicines
and Monkey Dust's simian primal-trauma transformation also retain their special
immunity. Numb now costs zero points instead of granting four, and continues to
hide injury feedback without healing injury. Surgery and bone-wound consumers
use `has_surgical_analgesia()`; unrelated acute messages and mood/emote consumers
still require full immunity.

The initial version adds patient alerts and severe-pain examine feedback, with
estimated pain and active relief in health scans. It does not add blur, forced
speech, oxygen damage, paralysis, or persistent stump trauma. Injury collapse is
deferred until pain reaches full capacity, not removed; regional overflow adds
internal injury on head/chest hits taken while already in crit-range health.

## TG proc/file changes

- Human `Initialize`, `Destroy`, `updatehealth` and `Life`: ownership and sampling.
- Carbon `update_stat` with human `defers_injury_crit`: fresh-pain crit gate.
- Bodypart damage hook forwarding post-mitigation head/chest hits to human organ overflow.
- Reagent definitions: finite relief instead of binary drug analgesia.
- Morphine metabolism overrides: remove the general movement exemption.
- Determination end metabolism: cap withdrawal exhaustion.
- Surgery speed, messages and mood; bone-wound attack, recoil and gel treatment:
  explicit surgical analgesia queries.
- Numb: neutral point value and updated description.
- Unit-test include list and `tgstation.dme`: module wiring.

## Modular overrides

- `modular_aphelion/master_files/code/modules/mob/living/carbon/human/medical_pain.dm`:
  species capacity, human eligibility, combined movement calculation with the
  hardcrit-health floor, crit deferral query, and regional organ overflow.
- Bodypart overflow forwarding in `code/contributions.dm`.
- Existing Nova reagent and surgery files: finite relief and surgical adequacy.

## Defines

Shared balance constants are in
`code/__DEFINES/~aphelion_defines/medical_pain.dm`.
Contribution-specific constants are local to `code/contributions.dm`.

## Included files outside this module

- The human master file and shared defines above.
- `code/modules/unit_tests/medical_pain.dm` (under unit-test configuration).
- Existing `injury` alert artwork; no new assets. Crit deferral and regional
  overflow add no new includes or assets.

## Credits

N/A
