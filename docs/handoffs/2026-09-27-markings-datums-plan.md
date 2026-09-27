# Datumize body markings

Mirrors `dc3d0cc0055b` — "A small refactor of mutant parts backend" (Nova #6763).
Executed by a fable 5.1 orchestrator driving a **fresh** Opus 5.5 max implementer, so this document
and the repo handoff doc must stand alone — assume the implementer has zero session context.
§0 is the setup and the scope lock; **Context** below it is why this change exists. Read both before
touching anything.

## 0. Setup, base, and scope lock

### 0.1 Blocking gate — wait for the BENEATH_HAIR_LAYER work

**Do not start any part of this plan until the Codex chat agent working on `BENEATH_HAIR_LAYER` in
`.worktrees/scenegirlsimulator` has finished.** It is demonstrably live: the dirty-entry count went
**75 → 77** within a few minutes during planning. `BENEATH_HAIR_LAYER` is an existing define
([mobs.dm:862](code/__DEFINES/mobs.dm#L862), layer 8.1), so this is the hair-appendage
under/over-hat layering work — the same effort that owns the 77 uncommitted entries.

It is a **Codex** agent, not a Claude session, so it does not appear in `ListAgents` and cannot be
reached with `SendMessage`. Poll the worktree instead, **every 30 minutes**:

```
cd .worktrees/scenegirlsimulator
git rev-parse HEAD
git status --porcelain | wc -l
git diff | md5sum
git status --porcelain | md5sum
```

Do **not** use `find -newermt` across the repo — it exceeds the 120 s tool timeout here.

Baseline captured at planning time:

| | value |
|---|---|
| `HEAD` | `bfaf20397f364e0f06a4c7454da6fb794559487d` |
| dirty entries | 77 |
| `git diff` md5 | `ed43b098dd5b7a44025f18c1fe0ac522` |
| `git status --porcelain` md5 | `c2da02d368cb116ce0e2bf2badbb9cd4` |

**Act on either of these — they mean the work landed:**
* `HEAD` has advanced past `bfaf20397f36`, or
* `git status --porcelain` is empty.

**Do not act on this alone:** an unchanged diff hash. A quiet tree can just mean the agent is
thinking or compiling. If the hashes are unchanged for **three consecutive ticks (~90 minutes)**,
report that to Pol and ask whether to proceed — do not self-authorize the start.

When the gate clears, re-capture the fingerprint (the snapshot in §0.2 must be taken from the *final*
state, not the baseline above) and then run straight through §0.2 and §3 without pausing for further
approval.

### 0.2 Worktree, branch, and base

**New worktree, new branch.** Base is `scenegirlsimulator` @ `bfaf20397f36`
(merge-base with `master` = `da61a88cd96a`). If the gate cleared via a commit, base on the **new**
`scenegirlsimulator` HEAD instead and record that SHA.

```
git worktree add -b markings-datums .worktrees/markings-datums scenegirlsimulator
```

All work happens in `.worktrees/markings-datums`. Do **not** work in
`.worktrees/scenegirlsimulator` — another effort is live there — and do not switch its branch.

**Carrying the in-flight hair-appendage work.** If the gate cleared *without* a commit,
`.worktrees/scenegirlsimulator` still holds its uncommitted entries (77 at planning time: 51 tracked
at +2795/−488, plus new `appendages.dm` files and tgfont icons). A fresh worktree checks out the
*commit*, so that work is absent by default — but **two of those files are central to this
refactor**:

* `modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm` (+5/−2)
* `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx` (+34/−8)

Building the markings work on a base that lacks those edits guarantees conflicts later, so carry the
snapshot across and **record it as a single labelled commit on `markings-datums` before any markings
work starts**:

1. In `.worktrees/scenegirlsimulator`: `git diff > <scratch>/hair-wip.patch`, and copy the untracked
   paths (`.superpowers/`, `docs/`, `modular_aphelion/.../appendages.dm`,
   `code/modules/unit_tests/~nova/custom_sprites/appendages.dm`, the `zaphelion-*.svg` tgfont icons).
   Read the file list from `git status --porcelain` — do not hand-transcribe it.
2. In `.worktrees/markings-datums`: apply the patch, add the untracked files, and commit as
   `snapshot: in-flight hair-appendage work (not authored on this branch)`.
3. Record that commit's SHA in the handoff doc. **Every later measurement — diffs, reviews, benchmark
   baselines — is taken against that SHA, not against `bfaf20397f36`.**

This touches only the new branch. Nothing is committed to `scenegirlsimulator`, and that worktree is
left exactly as found. Note the snapshot is a *point-in-time copy*: if the hair effort moves on, the
two trees diverge, and the snapshot commit should be dropped on the eventual rebase.

**Scope lock.** The implementer may only modify files listed in §4. If a change seems to require
touching anything from the hair-appendage snapshot beyond the two files above, stop and ask rather than
editing it. Never `git add -A`.

**Handoff artefacts to write before implementation begins:**
* `docs/handoffs/2026-09-27-markings-datums-handoff.md` in the new worktree — self-contained, modelled
  on the existing `docs/handoffs/2026-09-26-scenegirlsimulator-codex-handoff.md` (which it should
  cross-reference for general branch/tooling context rather than duplicate). Must carry: the base and
  snapshot SHAs, the scope lock, the build/test/benchmark commands, and the §7 decisions.
* A `project`-type memory file in
  `C:\Users\Pol\.claude\projects\c--Users-Pol-Documents-Meridian-Rift\memory\` plus its one-line
  `MEMORY.md` pointer, so a later session can pick this up.

## Context

#6763 replaced the nested-list `dna.mutant_bodyparts` with `/datum/mutant_bodypart`, added immutable
`species_blueprint` singletons for species defaults, and cut per-entry list allocation down to a
globally shared 8-permutation emissive cache
([mutant_bodyparts.dm](modular_nova/modules/customization/datums/dna/mutant_bodyparts.dm)).
Body markings never got that treatment. They are still:

* **`zone -> (marking_name -> list(color, emissive))`** — 1 outer + up to 8 zone maps + up to 24
  two-element tuples = **up to 33 lists per character**, with every hand-off a *shallow* copy so the
  tuples are aliased across prefs → DNA → limb.
* **Re-copied every `update_limb()`** — `LAZYLISTDUPLICATE` per limb + aux
  ([_bodyparts.dm:1245-1249](code/modules/surgery/bodyparts/_bodyparts.dm#L1245)).
* **Re-stringified every `update_body_parts()`** — one fresh list plus one string concat per marking
  per limb in
  [generate_icon_key()](modular_nova/modules/customization/modules/surgery/bodyparts/_bodyparts.dm#L14),
  which runs on *every* call even on a cache hit.
* **Rendered by an inline loop, not a datum** —
  [append_base_marking_overlays()](modular_aphelion/modules/custom_sprites/code/base_marking_overlays.dm#L17),
  ~48 of a fully-marked human's ~68 limb appearances.
* **Carrying a pile of declared-but-unwired features**, and ~170 of ~191 concrete markings silently
  defaulting to `#FFFFFF` instead of the character's mutant colour.

Goal: the same datumization; list churn driven to near zero; the half-built features finished.
Savefiles come out **byte-identical** — verified achievable against the 374 real saves in the repo
(§2.6) — with one gated content migration for saves that hold invalid data.

---

## 1. Inventory of what exists (and what's broken)

### 1.1 Four marking systems, one of them live

| | Store | Render | Status |
|---|---|---|---|
| **A. Nova body markings** | `dna.body_markings`; `GLOB.body_markings` (~191 concrete instances, 204 type declarations), `GLOB.body_marking_sets` (72) | inline `append_base_marking_overlays()` at [_bodyparts.dm:1457](code/modules/surgery/bodyparts/_bodyparts.dm#L1457) | **live — this refactor's target** |
| **B. TG species markings** | `dna.features[FEATURE_MOTH_MARKINGS/FEATURE_LIZARD_MARKINGS]` | `/datum/bodypart_overlay/simple/body_marking` | **dead** — call sites commented out at [_species.dm:409](code/modules/mob/living/carbon/human/_species.dm#L409) and [:479](code/modules/mob/living/carbon/human/_species.dm#L479); `/datum/species/var/list/body_markings` commented out at [:98](code/modules/mob/living/carbon/human/_species.dm#L98) — then **redeclared with a completely different meaning** (zone→markings, not overlay-type→name) at [nova species.dm:8](modular_nova/modules/customization/modules/mob/living/carbon/human/species.dm#L8). The residual scan loop still runs every limb update at [_bodyparts.dm:1261](code/modules/surgery/bodyparts/_bodyparts.dm#L1261). |
| **C. `mutant_bodyparts[FEATURE_MARKING_GENERIC]`** | `dna.mutant_bodyparts["body_markings"]` | needs an organ with that `mutantpart_key` — **none exists** | **dead, but still written to DNA**: [lizard.dm:15](modular_nova/modules/customization/modules/mob/living/carbon/human/species/lizard.dm#L15) declares `MUTPART_BLUEPRINT("Light Belly")` and [unathi.dm:34](modular_nova/modules/customization/modules/mob/living/carbon/human/species/unathi.dm#L34) `MUTPART_BLUEPRINT("Smooth Belly")` — **and "Smooth Belly" does not exist as any accessory**, masked only by `is_randomizable = TRUE` (with `FALSE` it would `CRASH()`). |
| **D. Aphelion custom paint** | `dna.custom_limb_markings`, sidecar `custom_sprites.json` | `/datum/bodypart_overlay/custom_marking` — **already pre-composes and caches its icons** | live, out of scope except for parity |

### 1.2 Declared-but-dead / broken (all to be resolved)

| Thing | Where | State |
|---|---|---|
| `always_color_customizable` | [body_markings.dm:18](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_markings.dm#L18), set on 8 markings | **DEAD** except one read at [roundstartslime.dm:877](modular_nova/modules/customization/modules/mob/living/carbon/human/species/roundstartslime.dm#L877). Docstring promises "colour customization shows up despite pref settings" — never implemented. |
| `DEFAULT_MATRIXED` | [DNA.dm:44](code/__DEFINES/~nova_defines/DNA.dm#L44) | **BROKEN for markings** — `get_default_color()`'s switch handles 1/2/3/5 only; `4` falls to `else` and returns the integer `4` as a colour. |
| Default colour | `default_color` unset on ~170 of 204 markings → `New()` forces `#FFFFFF` ([body_markings.dm:22-24](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_markings.dm#L22)) | **WRONG DEFAULT** — only `/datum/body_marking/secondary` and `/tertiary` (and akula) declare a mutant-colour source. This is the "most markings should take your mutant colour" gap. |
| `recommended_species` | [:16](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_markings.dm#L16) | **SOFT ONLY, AND SELF-CONTRADICTORY — the worst of the lot.** See §1.2a. |
| `DEFAULT_SKIN_OR_PRIMARY` | [get_default_color():37-41](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_markings.dm#L37) | **DEAD (zero users) *and* INVERTED** — uses skin colour when the species does *not* have `TRAIT_USES_SKINTONES`. [DNA.dm:45](code/__DEFINES/~nova_defines/DNA.dm#L45) says the opposite. Same inversion duplicated at [sprite_accessories.dm:95](modular_nova/modules/customization/modules/mob/dead/new_player/sprite_accessories.dm#L95). |
| `get_default_color()` signature | same proc | Declares `var/list/colors` but always returns a **string** — copy-paste from the sprite-accessory version, which really does return a list. |
| `/datum/body_marking/New()` | [:22](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_markings.dm#L22) | Does not call `..()` (the set datum's `New()` does). |
| `body_marking_list` | [body_marking_sets.dm:5](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_marking_sets.dm#L5) | Typed as a bare `var`, not `var/list/`. Read in exactly one place. Never sent to the UI — a preset is an opaque name with no preview of its contents. **101 of 191 markings belong to no set at all** (all 13 moth greyscale, all 11 tattoos, all 8 Teshari, all of `/other`, the Synth set…). |
| Dropdown order | [global_lists.dm:43-56](modular_nova/modules/customization/__HELPERS/global_lists.dm#L43) | `GLOB.body_markings_per_limb` is **never sorted** — raw `subtypesof()` order, unlike the emote lists two lines away which `sort_list`. |

### 1.2a The headline breakage: species restriction contradicts itself

`/datum/body_marking`'s base default is `recommended_species = list(SPECIES_MAMMAL = TRUE)`
([body_markings.dm:16](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_markings.dm#L16)),
and **neither `/secondary` nor `/tertiary` overrides it**. `/datum/body_marking_set`'s default is a
*different, wider* `{mammal, tajaran, vulpkanin, aquatic, akula}`
([body_marking_sets.dm:7-13](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_marking_sets.dm#L7)).
So ~100 animal markings are invisible in the per-limb dropdown to every species except Mammal, while
the sets containing those same markings are offered to five species **and force-applied by
`get_random_body_markings()`**:

| Set | set allows | its markings allow | result |
|---|---|---|---|
| `Akula` | `{akula}` | inherits `{mammal}` | [akula.dm:156](modular_nova/modules/customization/modules/mob/living/carbon/human/species/akula.dm#L156) forces it on every Akula; **an Akula cannot re-pick its own species marking** |
| `Shark` | default incl. `aquatic` | `{mammal}` | same |
| `Tajaran`, `Fox`, … | default incl. `tajaran`/`vulpkanin` | `{mammal}` | same |
| `Synth Scutes` | `{synth}` | `null` (unrestricted) | **inverted** — markings open to all, set locked to Synth |
| Moth, Vox | `{moth}` / `{vox}` | `{moth}` / `{vox}` | the only two that agree |

Only 10 distinct species ids appear across every `recommended_species` in the game, out of ~60
declared species. And enforcement is one-sided: `add_marking` filters
([limbs_and_markings.dm:387](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L387)),
but `change_marking` checks zone membership and **not** species
([:409](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L409)),
so the restriction is a UI suggestion that any action call bypasses.
| Marking "groups" | — | **DOES NOT EXIST.** `body_marking_set` is only a randomiser/preset seed ([:476-491](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L476)); nothing keeps a set's members together, and nothing prevents mutually-exclusive markings from stacking. |
| Species pruning | — | **MISSING** — nothing clears or revalidates `preferences.body_markings` when the species pref changes. |
| Load validation | [update_markings()](modular_nova/master_files/code/modules/client/preferences_savefile.dm#L361) | Version-gateless, repairs only bare-string→tuple. Never checks names against `GLOB.body_markings`, zones against `GLOB.marking_zones`, or count against `MAXIMUM_MARKINGS_PER_LIMB`. |
| Dead marking prefs | [mutant_parts.dm:118-170](modular_nova/master_files/code/modules/client/preferences/mutant_parts.dm#L118) | Four prefs (`body_markings_toggle`, `feature_body_markings`, `body_markings_color`, `body_markings_emissive`) whose `is_accessible()`/`apply_to_human()` hard-return `FALSE`. Savefile keys still reserved; tgui components still registered in [species_features.tsx:203-226](tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/nova/species_features.tsx#L203). |
| `relevant_body_markings` | [_preference.dm:123](code/modules/client/preferences/_preference.dm#L123), matched at [_species.dm:1424](code/modules/mob/living/carbon/human/_species.dm#L1424) | Unreachable — compares a typepath against Nova's zone-keyed map. |
| Broken leftover from #6763 | [preferences_savefile.dm:270-279](modular_nova/master_files/code/modules/client/preferences_savefile.dm#L270) | `VERSION_SKRELL_HAIR_NAME_UPDATE` reads `save_data["mutant_bodyparts"]` (a key nothing writes any more) and casts raw JSON to `/datum/mutant_bodypart` to read `.name`. **Lesson: migrations must run on raw JSON, never on datums.** |

### 1.3 Real bugs the typed model removes structurally

1. **Bare-string writes** corrupt the tuple shape:
   [fur_dyer.dm:117](modular_nova/modules/salon/code/fur_dyer.dm#L117) and
   [roundstartslime.dm:879](modular_nova/modules/customization/modules/mob/living/carbon/human/species/roundstartslime.dm#L879)
   assign a hex string where `list(color, emissive)` belongs. Both in-game recolour paths. Only
   `update_markings()`'s ungated repair keeps saves loadable.
2. `fur_dyer` writes through a *shallow* `.Copy()` **before** its 20-second `do_after` resolves, so
   it mutates the target's live DNA (and, via the prefs alias, the player's saved prefs).
3. **`generate_icon_key()` omits `markings_alpha`** — species with different `markings_alpha`
   (slime = 130, [roundstartslime.dm:595](modular_nova/modules/customization/modules/mob/living/carbon/human/species/roundstartslime.dm#L595)) collide in `limb_icon_cache`.
4. **`generate_husk_key()` omits the marking fragment entirely** — husks with different emissive
   flags collide.
5. **No `icon_exists` guard** in `append_base_marking_overlays()` — a missing state silently renders
   the sheet's default frame.
6. **Dropped limbs don't force `dir = SOUTH` on markings** — the `image(…, dir = SOUTH)` wrap at
   [_bodyparts.dm:1477](code/modules/surgery/bodyparts/_bodyparts.dm#L1477) covers `bodypart_overlays`
   only, not the marking loop at `:1457`. A dropped limb's markings can face a different way than
   the limb.
7. **Leg markings are never leg-split** — appended after the split at
   [:1447-1454](code/modules/surgery/bodyparts/_bodyparts.dm#L1447), so they exist only at
   `-BODYPARTS_LAYER` and never in the `-BODYPARTS_LOW_LAYER` half. `custom_marking` compensates for
   itself ([appearance.dm:269-294](modular_aphelion/modules/custom_sprites/code/appearance.dm#L269));
   native markings do not.
8. **Native marking emissives ignore `markings_alpha`** (helper default `alpha = 255` at
   [base_marking_overlays.dm:43](modular_aphelion/modules/custom_sprites/code/base_marking_overlays.dm#L43))
   while the visible overlay honours it.
9. **7 near-identical `get_random_body_markings()` overrides** (akula, aquatic, mammal, moth,
   tajaran, vox, vulpkanin) — two distinct bodies of copy-paste, and **two of them mutate a list
   while iterating it**:
   [mammal.dm:85-90](modular_nova/modules/customization/modules/mob/living/carbon/human/species/mammal.dm#L85)
   and [moth.dm:22-27](modular_nova/modules/customization/modules/mob/living/carbon/human/species/moth.dm#L22)
   do `candidates -= candi` inside `for(var/candi in candidates)`. DM iterates by index, so every
   removal skips the next entry — species-locked sets (Vox tattoos, Synth plates, moth wings on a
   mammal) leak through roughly half the time.
10. **`set_preset` validates nothing** ([:476-491](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L476)):
   a bad `preset` string gives a null set and runtimes in
   [mobs.dm:33](modular_nova/modules/customization/__HELPERS/mobs.dm#L33); and it assigns the whole
   `body_markings` list, **silently wiping zones the set never touches**.
11. **`change_emissive_marking` ignores `/datum/preference/toggle/allow_emissives`**
   ([:443-459](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L443))
   and `apply_to_human` copies the flag straight through — unlike the Aphelion custom-sprite path,
   which does gate it.
12. **`markings_alpha` has no default** — `var/markings_alpha` (null) at
   [_mutant_bodyparts.dm:7](modular_nova/modules/bodyparts/code/_mutant_bodyparts.dm#L7), assigned
   only inside `if(is_creating && owner)`. A limb that never ran that branch renders its markings at
   `alpha = null` → 0. Should be `= 255`.
13. **`affected_bodyparts` is never checked against the art — and ~49 markings are wrong.** The
   picker substitutes a blank for a missing state and says so
   ([markings_picker.dm:24](modular_aphelion/modules/custom_sprites/code/markings_picker.dm#L24):
   *"Some existing choices advertise zones with no artwork"*); the renderer does not, so the sheet's
   default frame gets drawn instead. A scripted audit of all 721 zone-claims against the DMIs found
   **49 markings with at least one unbacked claim** (heuristic — the real check will refine it):
   * Most are legs with only *one* of the plantigrade / digitigrade pair, so exactly one leg shape
     renders garbage. `Protogen Leg - Digitigrade` has digi art only; `Belly Slim`, `Guilmon`,
     `Leopard`, `Insectoid Trim` likewise; `Akula`, `Burnt Off`, `Gothic`, `Jungle`, `Lovers`,
     `Moonfly`, `Oakworm`, `Poison`, `Ragged`, `Leg Band`, `Lightbearer`, `Deathhead` are
     plantigrade-only.
   * Some are simply absent: `Bee` and `Deer Hoof` claim hands with no hand states, and **`Eye Bags`
     — the first marking in the file — points at `bodypart_overlay_simple.dmi` state `"bags"`, so it
     renders `bags_head`, which does not exist.**
14. **Art duplication: the name-based reading is wrong, but a pixel audit finds real redundancy.**
   Hashing all 971 marking icon states (every dir, every frame) gives **884 distinct signatures — 87
   redundant states, and zero cross-file duplicates.** So:
   * **Not duplicates, leave alone:** the 13 `moth/grayscale/*` markings vs `moth/*`. They share
     icon_state names but sit on different sheets at different canvas sizes — `moth_markings.dmi` is
     **45×34**, `moth_grayscale_markings.dmi` is **32×32** — and a pixel diff of all 98 shared state
     names matches *nothing*. Two deliberate looks (baked-colour vs recolourable), both needed.
   * **Not mergeable:** the 3 protogen markings share `icon_state = "protogen"`, but the sheet only
     has `protogen_digitigrade_{l,r}_leg`, `protogen_{l,r}_arm`, `protogen_chest_{m,f}`. Merging them
     would offer digi-only leg art to plantigrade legs — it *creates* a broken overlay.
   * **The real win — `gendered` is a lie on 53 markings.** Of 116 chest states that ship both `_m`
     and `_f`, **53 are pixel-identical**: 15 in `moth`, 14 in `moth_grayscale`, 13 in `secondary`,
     3 each in `tertiary` and `vox_tertiary`, 2 in `other` and `synthliz_tertiary`, 1 in
     `synthliz_secondary`. Setting `gendered = FALSE` on those renders identically (the renderer then
     uses `_m`, which is byte-for-byte what `_f` already contains) and lets the 53 `_f` states be
     deleted — **~5.5% of the sheet, zero savefile impact, no name changes, no migration.**
   * **Two genuinely duplicate marking pairs**, fully pixel-identical across every zone they claim:
     `secondary:handsfeet == secondary:rat` (8 zones) and
     `vox_secondary:vox_digitigrade_1 == vox_digitigrade_2` (2 zones). Deleting either member removes
     a player-facing name, so these need Pol's call plus a rename migration — **report, don't
     auto-merge.**
   * **Dead code to delete outright:** `/datum/sprite_accessory/moth_markings` (16 entries) and
     `/datum/sprite_accessory/lizard_markings` (3), which nothing can reach. No names, no migration.
15. **Known oddity, leave alone:** the 45×34 moth sheet is drawn with no centering (`/datum/body_marking`
   has no `center`/`dimension_*` vars, unlike `/datum/sprite_accessory`), so those overlays anchor
   bottom-left and extend past the tile. Presumably intentional for wings. Do not "fix" it — it would
   break appearance parity.

### 1.4 UX gaps the backend already has data for (scope decision — see §7)

* **Markings are added at random, not chosen.** `LimbsPage.tsx:397` sends `add_marking` with no name;
  DM does `pick(choices)` ([:390](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L390)).
  The player then has to change it in the dropdown.
* **Colour picking leaves tgui** — `tgui_color_picker()` is a blocking DM modal
  ([:435](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L435)),
  unlike every other colour control in the prefs menu.
* **No "reset to default colour"** anywhere, despite `default_color` existing.
* **`recommended_species` is sent but discarded** — `LimbsPage.tsx` uses it as a filter predicate then
  `.map(choice => choice.name)`. No "recommended for X" label, no off-species warning.
* **`gendered`, `affected_bodyparts`, `body_marking_list`, `always_color_customizable` are never sent
  to the UI at all.**

---

## 2. Design

### 2.1 The datums

New file `modular_nova/modules/customization/datums/dna/body_markings.dm`, sitting beside
`mutant_bodyparts.dm` and following its shape (terse inline comments, full `/** */` blocks on proc
definitions, per [mutant_bodyparts.dm](modular_nova/modules/customization/datums/dna/mutant_bodyparts.dm)).

```
/datum/body_marking_entry                  // one worn marking on one zone
    VAR_FINAL/datum/body_marking/marking   // the GLOB singleton — resolved once, not per render
    VAR_FINAL/zone                         // the body zone string this entry sits on
    VAR_PROTECTED/color                    // literal hex; null only before seed_color() runs
    VAR_PROTECTED/emissive = FALSE
    VAR_PRIVATE/cached_key                 // "[marking.name]_[color]_[emissive]", nulled by setters
```

* **Zero lists per entry.** This is the whole point: today's `list(color, emissive)` becomes two var
  slots. Up to 24 tuples → 0.
* No `name` var — the `marking` reference *is* the identity, and `marking.name` is the key. This also
  removes the `GLOB.body_markings[key]` lookup that `append_base_marking_overlays()` does per marking
  per limb per render today.
* `color` is a **literal hex in steady state** (§2.2's resolve-once decision). `seed_color(features,
  species)` applies `marking.color_mode` at add / preset / reset time; `null` is only the pre-seed
  state, and `serialize()` must never emit it — seed or drop the entry first. Keep this distinct from
  `/datum/mutant_bodypart.colors`, whose `null` legitimately means "fall back to defaults at render".
* Setters (`set_color`, `set_emissive`) null `cached_key` and bump the owner collection's `version`.
  `set_color` refuses on `MARKING_COLOR_LOCKED`; `set_emissive` refuses when `allow_emissives` is off.

```
/datum/body_marking_collection             // one per dna, one per /datum/preferences
    VAR_PRIVATE/list/entries               // ONE flat ordered list of /datum/body_marking_entry
    VAR_PRIVATE/version                    // bumped on any structural or value change
    VAR_PRIVATE/list/zone_cache            // zone -> list(entries), built lazily, cleared on version bump
    VAR_PRIVATE/list/key_cache             // zone -> cache-key fragment string, same lifecycle
```

* Each entry carries its own zone, so `entries` is **one list for the whole character** instead of the
  1 + 8 maps today.
* Per-zone views and per-zone cache-key fragments are built **once per change**, not once per
  `update_body_parts()`. Steady state: 1 list + up to 8 small cached view lists + up to 8 cached
  strings, all reused by reference.
* Ordering: `entries` preserves insertion order, and a zone view is the order-preserving filter of
  it. That keeps the positional `marking_id = "[zone]_[n]"` contract
  ([limbs_and_markings.dm:370](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L370))
  and the order-sensitive assertions in
  [limb_markings.dm:30,34](code/modules/unit_tests/~nova/limb_markings.dm#L30) exact.
* Name-uniqueness per zone becomes an enforced invariant on `add_entry()` rather than an accident of
  assoc keys.
* `copy()` → deep (new entries); plain reference assignment → shared. Today's shallow copies share
  tuples all the way down, so **sharing entry datums is parity**; use `copy()` only where
  `deep_copy_list()` is used today ([salon.dm:150-156](modular_aphelion/modules/custom_sprites/code/salon.dm#L150)).

### 2.2 Colour: resolve once, three modes

**Decided: resolve-once, keeping savefile parity.** `default_color` is applied when a marking is added
or a preset is picked and then stored as a literal hex, exactly as today. No live re-tinting, no
sentinel in the colour slot, no shape change. To make the default reachable, add the
**reset-to-default-colour** control the backend has always implied and never exposed.

`default_color` is replaced by one `color_mode` var carrying three meanings, so "ink is always ink"
becomes expressible:

| mode | meaning | who |
|---|---|---|
| `MARKING_COLOR_FOLLOWS_PRIMARY` / `_SECONDARY` / `_TERTIARY` | seeded from `features[FEATURE_MUTANT_COLOR…]`, freely recolourable | the default for the root type, and for `/secondary` + `/tertiary` |
| `MARKING_COLOR_FIXED_DEFAULT` | seeded from a literal hex on the datum, freely recolourable | `/other`'s ~26 hardcoded hexes |
| `MARKING_COLOR_LOCKED` | seeded from a literal hex, **and the colour control is unavailable** | the new tattoo family, and wherever "always ink" is wanted |

This subsumes `always_color_customizable` entirely — drop the var and its 8 declarations. Its two
documented-but-dead behaviours land as: the colour control's availability is driven by `color_mode`
(not by `allow_advanced_colors`), and a colour reset re-seeds from `color_mode` rather than skipping
entries.

Hierarchy work, so the mode is declared once per family rather than 204 times:

* `/datum/body_marking` → `MARKING_COLOR_FOLLOWS_PRIMARY`. **This is the headline fix** — ~170
  markings stop defaulting to `#FFFFFF`.
* `/datum/body_marking/secondary`, `/tertiary` — already correct in spirit, restate as the new modes.
* `/datum/body_marking/other` → `MARKING_COLOR_FIXED_DEFAULT`, keeping its hexes.
* New `/datum/body_marking/tattoo` base for `tattoo_markings.dmi` → `MARKING_COLOR_LOCKED`, `#112222`.
* **Delete** `DEFAULT_MATRIXED` from the marking path (markings are single-colour; today it returns
  the integer `4` as a colour) and **delete** `DEFAULT_SKIN_OR_PRIMARY`, which has zero users and is
  inverted relative to its own docstring. `stack_trace()` on an unrecognised mode instead of falling
  through to a garbage colour. Fix the inverted twin at
  [sprite_accessories.dm:95](modular_nova/modules/customization/modules/mob/dead/new_player/sprite_accessories.dm#L95)
  too, or leave it and file it — but do not leave two copies disagreeing silently.
* Resolution is a plain `switch` on the mode returning one string, with **no list allocated** and the
  misleading `var/list/colors` local removed.

**Savefile impact: none.** Existing saves hold literal colours and keep them; a changed default only
affects a freshly added marking or an explicit reset. Verify against a fixture save.

### 2.3 Enforced groupings and recommended colours — done properly

Both are currently absent/soft. Implement them on the singleton, with no per-instance lists:

* **`exclusion_group`** — a single text token (or `/datum/body_marking_group` typepath) on
  `/datum/body_marking`. Two markings sharing a group cannot coexist **on the same zone**.
  Enforced in one place: `collection.add_entry()`. Interned via `string_assoc_list()` if a list is
  ever needed. Surfaced to tgui in `build_marking_choices()` so the picker greys out conflicts.
* **`recommended_colors`** — a *static shared* list of hex suggestions on the singleton (interned by
  `string_assoc_list()`, so the ~15 distinct palettes cost 15 lists total, not 204). Sent in
  `get_constant_data()` and offered as swatches next to the colour picker. This is what the
  half-written `always_color_customizable` docstring was reaching for.
* **`always_color_customizable`** → deleted, subsumed by `color_mode` (§2.2). Update its one live
  reader, [roundstartslime.dm:877](modular_nova/modules/customization/modules/mob/living/carbon/human/species/roundstartslime.dm#L877),
  to skip `MARKING_COLOR_LOCKED` entries instead.
* **`recommended_species`** → fix §1.2a and make it consistent. Stop hand-maintaining it on markings:
  **derive each marking's species set as the union of the sets that contain it**, computed once in
  `make_body_marking_references()` and interned with `string_assoc_list()`, with an explicit
  per-marking override for the set-less ~101. That makes "the Akula set is for Akula" and "the Akula
  marking is for Akula" true by construction instead of by two authors agreeing. Then enforce it at
  one choke point — `collection.validate_for_species(species, allow_mismatched)` — called from
  `add_marking`, `change_marking`, `set_preset`, on species change, and on load.
* **Marking sets** → give `/datum/body_marking_set` a `keep_together` flag so a set's members are
  added/removed as a unit when the player picks a preset, instead of decomposing into loose entries;
  and make `set_preset` merge into the zones the set touches instead of replacing the whole list
  (fix 10).
* **`allow_emissives`** → gate `set_emissive` on it in the collection, so every writer inherits the
  check (fix 11).

### 2.4 Collapse the copy-paste

* One `/datum/species/get_random_body_markings()` on the base class, driven by two new species vars:
  `default_marking_set` (a name, e.g. `"Akula"`) and `randomize_marking_set` (bool → pick among sets
  whose `recommended_species` includes this species). Delete all 7 overrides
  ([akula.dm:156](modular_nova/modules/customization/modules/mob/living/carbon/human/species/akula.dm#L156),
  `aquatic.dm:72`, `mammal.dm:83`, `moth.dm:20`, `tajaran.dm:75`, `vox.dm:74`, `vulpkanin.dm:68`).
* `assemble_body_markings_from_set()`
  ([mobs.dm:31-41](modular_nova/modules/customization/__HELPERS/mobs.dm#L31)) becomes a collection
  factory: iterate the set's members once and consult `marking.affected_bodyparts` directly instead
  of the current O(sets × zones) scan of `GLOB.body_markings_per_limb`.
* Extract the duplicated 4-key `features` snapshot built in both `add_marking()` and `set_preset()`
  ([limbs_and_markings.dm:393](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L393),
  [:482](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L482))
  into one helper.
* Dead-code deletion (Systems B and C, the eight dead prefs) is step 6 — kept out of this step so a
  parity regression bisects to the right commit.

### 2.5 Middleware and limb wiring — where the churn dies

| Today | After |
|---|---|
| Every UI action rebuilds the whole zone map to preserve order (`change_marking` [:411-419](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L411), `color_marking` [:427-439](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L427), `change_emissive_marking` [:448-457](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L448), `remove_marking` [:465-472](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L465)) | `entry.marking = …` / `entry.set_color(…)` / `entry.set_emissive(…)` / `entries -= entry`. Zero allocation. |
| `LAZYLISTDUPLICATE` per limb per `update_limb()` | `limb.markings = collection.entries_for_zone(zone)` — a **shared cached list**, rebuilt only when `collection.version` changes. Snapshot semantics for detached limbs are preserved because the limb keeps the list it last got. |
| N string concats per limb per `update_body_parts()` | `. += collection.cache_key_for_zone(zone)` — one cached string. Add `markings_alpha` to it (bug 3) and add the fragment to `generate_husk_key()` (bug 4). |
| `LAZYCOPY(preferences.body_markings)` into DNA ([:17](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm#L17)) | `target.dna.body_markings = preferences.body_markings.copy()` — one explicit choice, deep, replacing accidental aliasing. |

`append_base_marking_overlays()` moves to iterating typed entries, resolves
`GLOB.body_markings[key]` **never** (the entry holds the reference), and gains the missing
`icon_exists_or_scream` guard and the dropped-limb `dir = SOUTH` wrap.

### 2.6 Savefile parity + migration

**On-disk shape does not change.** `body_markings` stays
`{"zone": {"name": ["#rrggbb", 0|1]}}`. The collection gains:

* `/datum/body_marking_collection/proc/serialize()` → rebuilds that exact nested list.
* `/proc/body_marking_collection_from_list(list/raw)` → tolerant loader: accepts `list(color,
  emissive)`, a bare colour string (today's legacy shape), missing/extra fields, and drops unknown
  zones and unknown marking names.

This is mandatory, not optional: `save_data["body_markings"] = body_markings`
([preferences_savefile.dm:353](modular_nova/master_files/code/modules/client/preferences_savefile.dm#L353))
puts the live value **directly into the JSON tree** that `json_encode` writes
([json_savefile.dm:58-60](code/datums/json_savefile.dm#L58)). A datum there would serialise as a ref
string or fail outright.

**Byte-exact parity is achievable — verified against real saves.** An audit of all 374
`data/player_saves/*/*/preferences.json` in the repo (23 marking entries across them) shows the
on-disk shape is completely uniform, and `serialize()` must reproduce exactly three things:

1. **Emissive is always an integer `0`/`1`.** Not one `true`/`false` exists on disk — DM has no
   boolean type, so `FALSE` and `sanitize_integer(0)` both encode as `0`. Write `emissive ? 1 : 0`.
   (Do **not** "normalise to booleans"; that would needlessly rewrite every save.)
2. **An empty collection must serialise to an empty DM `list()`**, which encodes as `[]`, not `{}`.
   Real saves contain `"body_markings": []` for markingless characters (5 slots found). The loader
   must also accept `[]`.
3. **Colours are lowercase `#rrggbb`** — i.e. plain `sanitize_hexcolor` output. Do not change case
   or drop the crunch.

With those rules there is **no shape migration and no version bump for the shape**. A version bump
is needed only for the *content* pass below.

One further consequence to handle:

* **Aphelion's disk-vs-memory comparison.**
   [custom_style_pending_markings_problem()](modular_aphelion/modules/custom_sprites/code/saved_styles.dm#L289)
   compares `custom_style_marking_entries(disk["body_markings"][zone])` against the same call on the
   in-memory value. Teach `custom_style_marking_entries()` to accept either a raw list or a
   collection zone view, producing byte-identical ordered records. Same for
   `custom_style_markings_slot_data()`
   ([:324-331](modular_aphelion/modules/custom_sprites/code/saved_styles.dm#L324)), which
   `deep_copy_list()`s the whole character tree and would otherwise pass a datum through by
   reference.

**Version bump (content only):** add `VERSION_MARKING_DATUMS 21` and bump
`MODULAR_SAVEFILE_VERSION_MAX` to 21
([preferences_savefile.dm:6](modular_nova/master_files/code/modules/client/preferences_savefile.dm#L6))
for the one-time validation pass — drop unknown marking names and unknown zones, clamp to
`MAXIMUM_MARKINGS_PER_LIMB`, resolve exclusion-group conflicts. This is the only step that changes
save *content*, and it must be gated so it runs once. Note the ordering hazard:
`body_markings` is deserialised at
[:60](modular_nova/master_files/code/modules/client/preferences_savefile.dm#L60), **before**
`update_character_nova()` runs at
[:96](modular_nova/master_files/code/modules/client/preferences_savefile.dm#L96) — so the migration
must operate on the already-built collection, not on `save_data`. Fold the ungated
`update_markings()` repair into the loader and delete it.

While here: fix or delete the broken `VERSION_SKRELL_HAIR_NAME_UPDATE` block
([:270-279](modular_nova/master_files/code/modules/client/preferences_savefile.dm#L270)).

### 2.7 One overlay instead of many — feasible, with conditions

**First, a correction worth knowing:** the mob already nests marking appearances.
[prepare_bodypart_overlays()](modular_aphelion/modules/worn_emissives/code/worn_emissives.dm#L72)
collapses plain visible sprites sharing a layer into one holder, and plain emissive masks sharing
`plane|layer` into one boundary. Native markings qualify (they set no `appearance_flags`); custom
paint does not (`RESET_COLOR`). So **top-level overlay count is already solved** — do not redo it.

What is *not* solved is twofold. First, each marking is still its own appearance object at
`get_limb_icon()` time, and therefore still receives its own height filter set. Height is a
`displacement_map_filter` applied **per appearance** at
[_bodyparts.dm:1463-1467](code/modules/surgery/bodyparts/_bodyparts.dm#L1463) — 1–3 filters each,
for every non-`HUMAN_HEIGHT_MEDIUM` character. For a fully-marked tall character that is 48 marking
appearances × up to 3 filters. Second, the nesting pass itself runs **per mob, per update**:
`apply_overlay()` calls `prepare_worn_emissive_overlays()` on the whole `BODYPARTS_LAYER` list every
time ([carbon_update_icons.dm:39-43](code/modules/mob/living/carbon/carbon_update_icons.dm#L39)),
whereas `get_limb_icon()` output is cached globally in `limb_icon_cache`. Merging earlier moves that
work behind the cache.

So the merge worth doing is **icon pre-composition**, using the pattern this codebase already runs
for custom paint and leg masks:

* **Emissives: merge unconditionally, exactly — including on slimes.** All emitting markings in a zone
  become **one** `emissive_appearance` built from one blended icon. This is provably parity: the
  emissive colour is the `GLOB.emissive_color` matrix, identical for every marking and independent of
  tint; markings emit no blockers, so there is no occlusion to preserve; and marking emissives are
  always built at `alpha = 255` regardless of `markings_alpha`
  ([base_marking_overlays.dm:43](modular_aphelion/modules/custom_sprites/code/base_marking_overlays.dm#L43)),
  so the translucent-overlap problem below does not apply to them at all. Up to 16 appearances saved
  per character, on **every** species.
* **Visible: merge maximal runs of *consecutive same-colour* markings.** Merging non-adjacent
  same-colour markings would reorder occlusion against an intervening different-coloured one, so
  restrict to consecutive runs. Blend **uncoloured**, then apply the one colour — which makes the
  cache key colour-free and therefore shared across every player wearing that marking set. This is
  exactly the `pixel_render_key` vs `icon_render_key` split Aphelion already uses
  ([appearance.dm:245-250](modular_aphelion/modules/custom_sprites/code/appearance.dm#L245)).
  A husked limb collapses to a single `#888888` for every marking, so husks always merge fully.
* **Precondition for the *visible* merge only: `markings_alpha == 255`.** Two translucent layers at
  alpha `a` composite to `C·a(2−a) + (1−a)²X` where they overlap; one merged layer gives
  `C·a + (1−a)X`. Not equal, so overlapping markings cannot be flattened at reduced alpha — the same
  limitation already documented and enforced at
  [markings_copy.dm:16-18](modular_aphelion/modules/custom_sprites/code/markings_copy.dm#L16). Note
  the `KEEP_TOGETHER`-holder trick used for hair gradients
  ([head_hair_and_lips.dm:118-127](code/modules/surgery/bodyparts/head_hair_and_lips.dm#L118)) does
  **not** rescue this: it flattens children at full alpha then applies the parent's, which is a third
  result again. Today's double-darkening in the overlap *is* the look, and parity requires keeping it.

  **How to gate it, and why it's free:** `markings_alpha` is a plain integer on the limb, written once
  in `update_limb()` from the species ([_bodyparts.dm:1252](code/modules/surgery/bodyparts/_bodyparts.dm#L1252))
  or copied on transplant ([salon.dm:308](modular_aphelion/modules/custom_sprites/code/salon.dm#L308)).
  The test is `limb.markings_alpha == 255` — one comparison, evaluated inside `get_limb_icon()`, which
  only runs on a `limb_icon_cache` miss. Since step 2 puts `markings_alpha` into the cache key anyway
  (bug 3), the merge decision is baked into the cached appearance list and is **never re-evaluated per
  render**. Read it off the limb, not the species, so transplanted slime limbs are handled.

  **Scope of the exception: exactly one species.** A full sweep shows `markings_alpha` is declared on
  `/datum/species/jelly/roundstartslime` (130) and nowhere else — every other species inherits 255
  from [species.dm:18](modular_nova/modules/customization/modules/mob/living/carbon/human/species.dm#L18),
  including `/datum/species/jelly` and `/datum/species/jelly/slime`. `roundstartslime` has no
  subtypes. (Its `specific_alpha = 155` is separate — that lands on `limb.alpha`, not marking alpha.)
  Custom paint reads the same var but never writes it, so the custom-markings system adds no new
  reduced-alpha cases.

  **Optional refinement, only if the benchmark says slimes matter:** non-overlapping markings merge
  losslessly even at reduced alpha, and overlap is a colour-independent property of the icon-state
  set — so it caches forever under the same key as the merged icon. Cost: BYOND has no "is this icon
  blank" primitive, so an exact test needs an alpha-mask `ICON_MULTIPLY` plus a ~4096-call `GetPixel`
  scan per candidate set. Fine once per distinct set per round, never per render;
  [markings_copy.dm:41-66](modular_aphelion/modules/custom_sprites/code/markings_copy.dm#L41) already
  does this exact analysis and can be reused. Do **not** build this up front.
* **Group by icon dimensions.** `moth_markings.dmi` is **45×34**; everything else is 32×32. Never
  blend across sizes. Build the canvas with the existing
  [custom_sprite_blank_icon()](modular_aphelion/modules/custom_sprites/code/images.dm#L6), which
  already seeds all four cardinals at arbitrary W×H.
* **Skip blending for runs of length 1** — the common case then costs exactly nothing.
* **Cache** with the existing bounded FIFO
  [custom_sprite_cache_put()](modular_aphelion/modules/custom_sprites/code/images.dm#L52) (limit
  256), keyed `"[icon_file]|[state]|[state]…"`. Do **not** add an unbounded `GLOB` list;
  Aphelion notes at [appearance.dm:270](modular_aphelion/modules/custom_sprites/code/appearance.dm#L270)
  that content-addressed keys avoid the runtime-icon reuse hazard in `generate_masked_leg()`.
* **Do not merge across limbs.** Each limb owns its overlays and its `limb_icon_cache` entry; a
  mob-level merge would break on limb loss. Per-limb is the correct granularity.

All directional and rotational behaviour is unaffected: every marking state is `dirs = 4,
frames = 1`, nothing in the marking path assigns `transform`, and the lying-down matrix is applied
to the mob alone ([living_update_icons.dm:54](code/modules/mob/living/living_update_icons.dm#L54)).
Emissives must stay **top-level siblings** on `EMISSIVE_PLANE` with `EMISSIVE_APPEARANCE_FLAGS`
(`KEEP_APART|KEEP_TOGETHER|RESET_COLOR`) — nesting them under a visible parent puts them inside the
mob's `KEEP_TOGETHER` group and bakes the pose, per
[worn_emissives.dm:145-147](modular_aphelion/modules/worn_emissives/code/worn_emissives.dm#L145).
Pre-composing into a flat icon also avoids the double-filter trap at
[human_update_icons.dm:1245-1247](code/modules/mob/living/carbon/human/human_update_icons.dm#L1245).

**Ship this as the last phase, behind its own commit**, so it can be reverted without losing the
datumization.

---

## 3. Sequencing

Each step compiles and passes tests on its own.

1. **Datums + serialize/deserialize.** Add `body_markings.dm`; convert `dna.body_markings` and
   `preferences.body_markings`; keep the nested list only at the savefile boundary. Update every
   consumer in §1 and the tests. No behaviour change intended.
2. **Kill the churn.** Shared zone views, cached key fragments, `markings_alpha` in the icon key,
   marking fragment in the husk key, typed setters in the middleware.
3. **Fix the bugs (§1.3).** Bare-string writers (`fur_dyer`, `roundstartslime`), `fur_dyer`'s
   pre-`do_after` write-through, `icon_exists` guard, dropped-limb `dir`, leg-split for leg markings,
   emissive `markings_alpha`, `markings_alpha = 255` default, `set_preset` validation + merge,
   `allow_emissives` gate, the two mutate-while-iterating loops, the `deathmatch` typepath.
4. **Colour defaults + inheritance.** Root `DEFAULT_PRIMARY`, tattoo family, drop `DEFAULT_MATRIXED`
   and the inverted `DEFAULT_SKIN_OR_PRIMARY` from the marking switch, collapse the 7
   `get_random_body_markings()` overrides onto `default_marking_set` / `randomize_marking_set`.
5. **Finish the features.** Exclusion groups, recommended colours, `always_color_customizable`,
   derived-and-enforced `recommended_species` (§1.2a), `keep_together` sets — backend, middleware
   payload, and tgui together. Sort `body_markings_per_limb`.
6. **Delete the dead, and do the real art consolidation.** System B (`markings_bodypart_overlay.dm`,
   `add_body_markings`, `remove_body_markings`, `relevant_body_markings`, the species-level
   `body_markings` var); System C (`FEATURE_MARKING_GENERIC` blueprints on lizard/unathi, the dead
   `/datum/sprite_accessory/moth_markings` and `/lizard_markings` subtypes); the eight dead marking /
   moth-marking prefs; `update_markings()`. Then the audited consolidation from §1.3-14: set
   `gendered = FALSE` on the **53 markings whose `_chest_m` and `_chest_f` art is pixel-identical** and
   delete those 53 `_f` states. **No player-facing name changes and no migration** — verify with the
   appearance harness on both physiques before and after. Report the two genuinely duplicate marking
   pairs (`handsfeet`/`rat`, `vox_digitigrade_1`/`_2`) to Pol rather than merging them; deleting a name
   needs a rename migration and is a separate decision. **Own commit**, so a parity regression bisects
   cleanly.
7. **Art-integrity check** (in scope per §7). A `~nova` unit test that walks every
   `/datum/body_marking`, expands `affected_bodyparts` through the same icon-state formula the
   renderer uses (including `_m`/`_f` for gendered chests and both leg shapes), and fails on any
   claimed zone with no state. Expect **~49 initial failures** (§1.3-13). Resolve each by narrowing
   `affected_bodyparts`, adding a `requires_bodyshape` guard for the digi/plantigrade splits, or
   commissioning art — and only then turn the test on. Pair it with the missing
   `icon_exists_or_scream` in the renderer (step 3) so future gaps are loud.
8. **tgui UX** (in scope per §7). Choose-a-marking instead of `pick()`, in-panel colour picker
   replacing the blocking `tgui_color_picker`, reset-to-default-colour button, and surface
   `recommended_species` / `gendered` / preset contents / `color_mode` in the payload and the UI.
   Extend `build_marking_choices()` and `LimbsPage.tsx` together. Styling goes in the interface's
   Aphelion SCSS, not inline.
9. **Overlay merging** (§2.7). **Own commit**, revertable without losing the datumization.

## 4. Critical files (this is the scope lock — §0)

* **New:** `modular_nova/modules/customization/datums/dna/body_markings.dm`
* **Datums/model:** [body_markings.dm](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_markings.dm), [body_marking_sets.dm](modular_nova/modules/customization/modules/mob/dead/new_player/body_markings/body_marking_sets.dm), [dna.dm](modular_nova/modules/customization/datums/dna/dna.dm), [code/datums/dna/dna.dm:92-110,376,442-454](code/datums/dna/dna.dm#L92)
* **Render:** [base_marking_overlays.dm](modular_aphelion/modules/custom_sprites/code/base_marking_overlays.dm), [_bodyparts.dm:1243-1256,1457](code/modules/surgery/bodyparts/_bodyparts.dm#L1243), [nova _bodyparts.dm:9-20](modular_nova/modules/customization/modules/surgery/bodyparts/_bodyparts.dm#L9), [carbon_update_icons.dm:459-516](code/modules/mob/living/carbon/carbon_update_icons.dm#L459)
* **Prefs:** [limbs_and_markings.dm](modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm), [preferences.dm:13](modular_nova/master_files/code/modules/client/preferences.dm#L13), [preferences_savefile.dm](modular_nova/master_files/code/modules/client/preferences_savefile.dm), [mutant_parts.dm:118-170](modular_nova/master_files/code/modules/client/preferences/mutant_parts.dm#L118)
* **Helpers:** [mobs.dm:14-41](modular_nova/modules/customization/__HELPERS/mobs.dm#L14), [global_lists.dm:43-64](modular_nova/modules/customization/__HELPERS/global_lists.dm#L43)
* **Aphelion parity:** [salon.dm:131-156](modular_aphelion/modules/custom_sprites/code/salon.dm#L131), [saved_styles.dm:288-331](modular_aphelion/modules/custom_sprites/code/saved_styles.dm#L288), [transfer.dm:154-267](modular_aphelion/modules/custom_sprites/code/transfer.dm#L154), [editor.dm:973-992](modular_aphelion/modules/custom_sprites/code/editor.dm#L973), [markings_editor.dm](modular_aphelion/modules/custom_sprites/code/markings_editor.dm), [markings_copy.dm](modular_aphelion/modules/custom_sprites/code/markings_copy.dm), [markings_picker.dm](modular_aphelion/modules/custom_sprites/code/markings_picker.dm), [mirror.dm:409-421](modular_aphelion/modules/custom_sprites/code/mirror.dm#L409)
* **Consumers:** [fur_dyer.dm](modular_nova/modules/salon/code/fur_dyer.dm), [roundstartslime.dm:873-879,1097](modular_nova/modules/customization/modules/mob/living/carbon/human/species/roundstartslime.dm#L873), [changeling.dm:809](code/modules/antagonists/changeling/changeling.dm#L809), [deathmatch_loadouts.dm:74](modular_nova/modules/deathmatch/deathmatch_loadouts.dm#L74), `species/{akula,aquatic,mammal,moth,tajaran,vox,vulpkanin,insect,protean_species}.dm`
* **tgui:** [LimbsPage.tsx](tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx), [species_features.tsx:203-226](tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/nova/species_features.tsx#L203)
* **Tests to update:** [limb_markings.dm](code/modules/unit_tests/~nova/limb_markings.dm), [custom_sprites/{saved_styles,markings_editor,salon,transfer,save_compatibility,appearance}.dm](code/modules/unit_tests/~nova/custom_sprites/), [changeling.dm:92](code/modules/unit_tests/changeling.dm#L92)

## 5. Verification

**Savefile parity (the hard gate).**
1. Copy real multi-slot `preferences.json` files (and their `custom_sprites.json` sidecars) into a
   fixture dir. Load, save, **byte-diff**. Per §2.6 this must be a zero diff, including
   `"body_markings": []` for markingless slots and integer `0`/`1` emissives. The repo already has
   374 usable saves under `data/player_saves/` — 23 of them carry markings; seed the rest by hand.
2. Fixture saves covering: no markings; 3-per-zone on all 8 zones; legacy bare-string colours;
   unknown marking names; over-cap zones; slime (`markings_alpha = 130`); moth (45×34 sheets);
   akula/vox/synthliz sets; a saved custom-sprite style carrying native markings. Everything except
   the deliberately-invalid fixtures must byte-diff clean; the invalid ones exercise the §2.6
   content migration exactly once and then byte-diff clean on the second save.
3. Round-trip a save through the *old* build and the *new* build and diff appearance, not bytes.

**Appearance parity.** Use the native BYOND live-check harness (`dd.exe` + DreamSeeker, `PrintWindow`
on DreamSeeker's own HWND, prefs seeded via in-memory `json_savefile` — never edit `player_saves`).
Capture before/after per-frame renders for: all 4 facings standing; lying down, rotated, in darkness
(emissives); husked; dismembered limb on the floor; dwarf/tall/tallest (height filters); taur;
digitigrade; dimorphic chest both physiques; **a roundstartslime with 3 overlapping markings per zone**
(the `markings_alpha = 130` path, which must stay on the unmerged branch); and **both physiques on each
of the 53 `gendered = FALSE` conversions**. Compare pixel data, not `getbbox` —
`difference().getbbox()` misses colour-only changes.

**Unit tests.** `build.bat dm-test` with a temp `TEST_FOCUS`; judge by `clean_run.lk` (a non-zero
exit is expected). Run the existing marking suites plus new tests for: serialize/deserialize
round-trip; zone-view identity is stable across `update_body_parts()` (no reallocation); exclusion
groups reject conflicts; `validate_for_species` prunes on species change; cache-key fragment changes
with `markings_alpha` and with emissive flags on husks. No tests for wording or defaults-only
changes. Declare `priority = TEST_LONGER` on anything measured slow.

**Benchmarks.** Clone `tools/custom_sprite_harness/` (see its
[README](tools/custom_sprite_harness/README.md)) into a markings harness: build
`tgstation.harness.dme`, drive a fully-marked character through repeated `update_body_parts()`,
species changes, husking, dismemberment, height changes, and the full prefs-menu marking action set.
Report `world.Profile` JSON for `update_body_parts`, `get_limb_icon`, `generate_icon_key`,
`append_base_marking_overlays`, and allocation counts. Take a baseline on the current branch tip
**before** step 1. Targets: `generate_icon_key` cost for markings → ~0 on cache hits; zero list
allocations per `update_limb()`; appearance count and displacement-filter count per fully-marked tall
human down measurably after step 9. Finish with live `byond-tracy` traces via `meridian-mcp` (needs
`MERIDIAN_MCP_STATE_DIR`; the server failed to connect this session — reconnect before that step).

**tgui (step 8).** Verify layout, hit-testing and paint in headless Edge over CDP against the real
`LimbsPage` and compiled CSS, across every Meridian theme — the existing harness pattern. Watch the
`.Floating` portal: hiding Floating content leaves the portaled div catching clicks, so target it via
`:has()`, never blanket.

**Local CI.** DreamChecker (`-e tgstation.dme`), ticked-file schemas, `check_grep` with exported
`rg`, compile-only `dm.exe`. Stash `.dmi` changes before any DreamDaemon run — it rewrites DMI files.

## 6. Risks

* **`prepare_bodypart_overlays()` eligibility.** It merges only appearances with no
  `appearance_flags`. If a merged marking appearance gains flags, native markings silently drop out
  of that existing optimisation. Assert on it.
* **Aphelion package hashes.** `custom_style_package_hash()` and `custom_sprite_region_signature()`
  hash `json_encode` of marking records. Any record-shape drift silently invalidates every saved
  `previous_styles` entry. The record producers must stay byte-stable.
* **Aliasing is currently *tested* behaviour.** `saved_styles.dm:109-129` asserts both that pending
  edits on other limbs survive *and* that aliased pending edits are detected. Moving to explicit
  `copy()` changes both; those tests need deliberate rewriting, not silent relaxation.
* **Assoc-order dependence** is spread across the middleware, the editor's positional `index`, and
  the tests. The flat-list-plus-filter model preserves it, but it must be asserted.
* `deathmatch_loadouts.dm:74` passes a species **typepath** where an instance is expected — latent
  today because the Akula set never hits the `DEFAULT_SKIN_OR_PRIMARY` branch. Fix while converting.
* **Step 7 will look like a regression.** Turning on the art-integrity check surfaces ~49 pre-existing
  breakages at once. Resolve them before enabling the test, and keep that work in its own commit so it
  is not confused with the refactor.
* **Deriving `recommended_species` from sets widens ~100 markings' availability.** That is the point
  (§1.2a), but it is a *player-visible* change to the prefs menu, not a silent one. It cannot alter
  any existing character's appearance — saved markings render regardless of the filter.

## 7. Decisions already taken

Settled with Pol before this plan was written; the orchestrator should not re-open them.

| Question | Decision |
|---|---|
| Species-restriction contradiction (§1.2a) | **Derive each marking's species set as the union of the sets containing it**, with explicit overrides for the ~101 set-less markings. Enforce at one choke point. |
| Should marking colour track mutant colour live? | **No — resolve once, keep savefile parity.** Add the reset-to-default control instead. |
| `always_color_customizable` / fixed-colour markings | **Three `color_mode` modes** (follows a mutant colour / fixed default but recolourable / locked). Replaces the var. |
| Extra scope | **All four in scope**: overlay merging (step 9), tgui UX gaps (step 8), art consolidation (step 6) and the art-integrity CI check (step 7). |
| What art consolidation actually is | The name-based duplicates were a false lead. A pixel audit of all 971 states found 87 redundant ones and **zero** cross-file duplicates. The lossless, migration-free win is **53 `_chest_f` states whose art is identical to `_chest_m`** → `gendered = FALSE`. Two real duplicate marking pairs are reported for a separate call. |
| Reduced marking alpha | Blocks only the **visible** merge, never the emissive one, and affects **exactly one species** (`/datum/species/jelly/roundstartslime`, no subtypes). Gate on `limb.markings_alpha == 255` — one integer compare on a cache miss, and already folded into the cache key. Overlap-aware merging for slimes is an explicitly deferred refinement. |
| Worktree | **Use one** — `.worktrees/markings-datums`, branch `markings-datums` off `scenegirlsimulator` (§0). This overrides the usual "no new worktrees" rule for this task. |
| Base handling | Carry the hair-appendage work across as **one labelled snapshot commit** on the new branch, because `limbs_and_markings.dm` and `LimbsPage.tsx` are modified by both efforts. `scenegirlsimulator` is left untouched. |
| Execution | A fable 5.1 orchestrator drives a **fresh** Opus 5.5 max implementer. Both are launched from the planning session. |
| Start gate | **Blocked** until the `BENEATH_HAIR_LAYER` Codex agent finishes in `.worktrees/scenegirlsimulator` (§0.1). Poll every 30 min. Once it clears, run through without further approval. |
