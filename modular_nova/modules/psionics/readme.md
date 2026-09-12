## Title: Psionics

MODULE ID: PSIONICS

### Description:

Adds a standalone psionics system. Psions spend imprint points on disciplines, build strain when using them, and burn out if they push too hard.

Psionics are not spells. They do not use spell actions or antimagic checks; blocking and suppression go through psionic signals, psionic components, and `TRAIT_PSIONIC_DAMPENER`.

### Features:

- `Psionic Gift` quirk, with rank and manifestation color preferences.
- `Psionic Resonance` mutation, which awakens a rolled psionic rank.
- Psionic imprinting TGUI and strain HUD.
- Rank ladder from Lambda to Alpha. Delta and above start capped to Gamma by a psionic limiter implant when gained from the roundstart quirk.
- Individual power cooldowns, profile strain, burnout, and rank-specific power forms where needed.
- Strain decay pauses while a maintained power is active, so upkeep costs are never free.
- Heavy casting has visible tells (stutter and jitter near the strain ceiling); burnout carries a mood penalty, and repeated burnouts inflict mild brain traumas on top of the brain damage.
- A three-tier strain backlash ladder: mild backlashes from half strain, severe from three quarters, and a catastrophic one rolled alongside every burnout. Each tier is a weighted pick with its own spacing cooldown, and every backlash is exposed to the admin smite menu.
- Psionic dispel, which forcibly ends maintained powers, dispellable manifestations, and dispellable psionic status effects. Sourced only from psionics — nullrods and tg antimagic have no bearing on it.
- Psionic dampener cuffs, a charge-limited psionic nullification headband, a handheld psionic resonance scanner for non-psion detection, a researchable miniature reality anchor that pulses dispels and silences psions in an area, and reusable protection/restriction components.
- School commitment and anomaly-core attunement, both of which reduce strain in that school.
- The Psionic Dampener quirk only shields the mind (intrusive/sensory psionics); non-quirk `TRAIT_PSIONIC_DAMPENER` sources still suppress everything.
- ERP-gated lewd disciplines, hidden from imprinting and uncastable unless both parties have the ERP preference enabled.

### TG Proc/File Changes:

- `code/_onclick/telekinesis.dm`
  - Mutation telekinesis rejects targets controlled by another source of `TRAIT_TELEKINESIS_CONTROLLED`.
- `code/modules/mod/modules/module_kinesis.dm`
  - MOD kinesis rejects already controlled targets and adds/removes its own control trait when grabbing/releasing them.
  - Together with Telekinetic Hold, these checks prevent competing telekinetic systems from taking the same object.
- `code/modules/mob/mob.dm`
  - `can_interact_with()` accepts psionic reach only for Manipulate's exact connected target while the connection remains valid.
- `code/modules/mob/living/living.dm`
  - `can_perform_action()` accepts that scoped reach for adjacency checks. `FORBID_TELEKINESIS` and other action requirements still apply.
- `code/game/objects/items.dm`
  - `use_tool()` adds connection checks for Manipulate's current remote tool and target, preserving the caller's existing checks.
  - Timed tool work stops if the connection or tool placement becomes invalid.
- `code/modules/tgui/states.dm`
  - Living and human `shared_living_ui_distance()` checks allow remote UI interaction with Manipulate's exact connected target.
  - An invalid link returns `UI_CLOSE`, including for humans with the telekinesis mutation. `allow_tk = FALSE` retains its opt-out.
  - These hooks change distance eligibility only; normal machine locks, access checks, and power requirements still apply.
- `code/modules/tgui/tgui.dm`
  - `on_act_message()` refreshes UI status immediately before dispatching an action and requires `UI_INTERACTIVE`.
  - This recheck applies to all TGUI actions, preventing queued input from executing after interaction becomes unavailable.
- `tgstation.dme`
  - Includes the Telekinetic Hold and Manipulate power files.
- `modular_nova/master_files/code/datums/mind/_mind.dm`
  - Stores the mutation-sourced psionic rank on each mind.
- `modular_nova/master_files/code/game/turfs/closed/walls.dm`
  - Adds temporary psionic wall phasing used by Warp.
- `modular_nova/master_files/code/modules/research/anomaly/anomaly_core.dm`
  - Adds psionic anomaly-core attunement interaction and examine text.

### Modular Overrides / External Files:

- `code/__DEFINES/~nova_defines/psionic.dm`
  - Shared psionic ranks, sources, schools, strain defaults, flags, signals, HUD identifiers, and component return values.
- `code/__DEFINES/~nova_defines/vv.dm`
  - Adds the Give Psionics VV dropdown identifier.
- `modular_nova/modules/extra_vv/code/extra_vv.dm`
  - Adds the Give Psionics action to living mobs' VV dropdown.
- `modular_nova/master_files/code/modules/research/techweb/all_nodes.dm`
  - Adds `psionic_dampener_cuffs`, `psionic_nullification_headband`, `psionic_resonance_scanner`, and `psionic_reality_anchor` to riot suppression research.
- `modular_nova/modules/implants/code/medical_nodes.dm`
  - Adds `ci-psionic-limiter` to cybernetic implant research.
- `tgui/packages/tgui/interfaces/PsionicImprinting.tsx`
- `tgui/packages/tgui/styles/interfaces/PsionicImprinting.scss`
- `tgui/packages/tgui/styles/assets/psionic-*.svg`
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/nova/psionics.tsx`

### Defines:

- `code/__DEFINES/~nova_defines/psionic.dm`
  - Psionic ranks, sources, schools, strain defaults, flags, signal names, HUD identifiers, and component return values.

### Notes for adding powers:

Power files live in `code/power`. Keep each concrete power in its own file with its `/datum/psionic_power` entry, action type, rank variants if any, and owned helper objects or projectiles.

Most metadata lives on the action. The `/datum/psionic_power` entry exposes the action to the imprinting tree and declares tree-only requirements such as prerequisites or spent school points.

Use `mob/living/proc/awaken_psionics()` and `revoke_psionics()` for point-only sources. Sources that grant a rank must restore the previous rank when removed. Use psionic flags and `can_block_psionics()` / `can_cast_psionics()` for counters instead of spell or antimagic hooks.

A power whose effect ends with `stop_maintaining()` is already dispellable. A power that leaves an object or status effect behind is not, and needs `/datum/element/psionic_dispellable` on the object, or `parent_type = /datum/status_effect/psionic_dispellable` on the status effect.

New backlashes subtype `/datum/psionic_backlash/mild`, `/severe`, or `/catastrophic` in `code/backlash_events.dm` and are picked up automatically. Give each one a `/datum/smite/psionic_backlash` subtype so it stays testable, and never make the last always-succeeding backlash in a tier conditional.

### Credits:

N/A
