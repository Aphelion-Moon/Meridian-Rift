# Handover: fitness follow-ups and the bulky augment styles

- **Branch:** `bulge`.
- **Commit:** sections 1-2 are committed in `e06b0ab0401d` ("stuff", 2026-10-14 02:19). Section 3, the recolourable
  augment finishes, is uncommitted in the working tree (updated 2026-10-14).
- **Reader:** an agent picking this up without the earlier session's context.
- **SCRATCH** below means the earlier session's scratchpad:
  `C:\Users\Pol\AppData\Local\Temp\claude\c--Users-Pol-Documents-Meridian-Rift\597eba23-bdbe-493e-af54-24ccde0551bc\scratchpad`.
  It sits in Temp. Copy anything you depend on before it gets cleaned. The augment art in particular exists only there.

## How Pol works

- **Pol decides art by eye.**
  - Show options as hi-res mockups, then wait for a pick.
  - Change only what he flags and keep what he liked. Never swap technique unasked.
  - Critic scores are guardrails, not verdicts. Twice this session the blind-critic winner lost to Pol's eye.
- **Art is done in Aseprite**, live in Pol's window through the Aseprite MCP, using the aseprite plugin skills:
  `aseprite:studio` to route, then `fix`, `shade` or `draw`, then a review.
  - Judging goes to the `aseprite:pixel-critic` agent, which reads PNG exports only. Compare versions blind (coin-flipped
    `a`/`b`) rather than by score.
  - **One style at a time.**
  - If an Aseprite call times out, a modal dialog is open in Pol's window. Ask him to dismiss it; don't retry.
- **Git and edits:**
  - Don't commit, push, stage or discard.
  - `// APHELION EDIT` markers go only in tg files, never in `modular_aphelion/` or `modular_nova/`.
  - Prefer modular fixes.
- **Live server and builds:**
  - Never start DreamDaemon or `dd.exe`, and never compile, in a checkout where Pol's live server
    (`dreamdaemon.exe tgstation.dmb 1337`) runs. Its init and shutdown wipe `tmp/`; compiles fill a nearly full C: drive
    (16 GB free at handover).
  - Check `tasklist` for `dreamdaemon.exe` and `dd.exe`, and `df -h /c`, every time.
- **References** must be real art: official stills, renders, product photos. Never explicit images.
- **Files:** chat file links don't open on Pol's PC. Open files for him with
  `"/c/Users/Pol/AppData/Local/Programs/Microsoft VS Code/bin/code" -r <path>`.

## 1. Fitness (physique): done

Sizes (Normal, Athletic, Muscular) times definition steps (None, Toned, Defined, Shredded) are set in character setup
(`Muscles.tsx`). The module also covers:
- the female cut over pecs;
- straight tank tops over pecs;
- tops that animate with pec flexes;
- fitted underclothes and worn clothing.

Everything is documented in `modular_aphelion/modules/fitness/module.md`. Sheet generators and templates live in
`tools/fitness/`.

## 2. In-game review fixes: committed, tests never run, not seen in game

Pol approved each of these ("all that looks good to me"):

1. **Bulge, underwear restrains** (`modular_aphelion/modules/bulge/code/look.dm`: `bulge_restraint()`,
   `bulge_held_size()`; `cut_cover.dm`).
   - Underwear under a skirt, leotard or corset holds the penis in. The outer garment tents at the underwear's capped size,
     with no anatomy and no cut.
   - Chastity sprites and groin plating mean no bulge at all.
   - Swapping underwear updates the look.
2. **Pubic hair** (`modular_aphelion/modules/body_hair/code/body_hair.dm`).
   - Under the jockstrap (`male_kinky`) or mankini, the hair is clipped to bare skin outside the underwear.
   - It's cached once per round and keyed into the chest's cache key.
3. **Polo forearms** (`garment_fitting.dm` `bare_near_forearm()`, opt-in `bares_near_forearm()` on the four tg polos and
   Nova's polo). On Athletic and Muscular bodies the side-view forearm shows at the bigger arm's width. The Python
   reference is `SCRATCH/fitting_spec/fitref_v10.py`.
4. **First pec flex** (`garment_fit_styles.dm`): a top's flex fits for all four flex sheets are warmed in the background
   once it's drawn over pecs, so the first flex animates the top.
5. **Height rows** (`human_update_icons.dm` `apply_height_filter()`, `modular_aphelion/modules/fitness/icons/height_cuts.dmi`).
   tg duplicated sprite row 16, which is a pec crease. Humans now stretch and shrink below every pec shape:
   - Taller and Tallest draw row 18 twice;
   - Shortest drops row 18;
   - Dwarf drops rows 18 and 19.

   Monkeys keep tg's maps.

**Verified so far:**
- DreamChecker found 0 problems.
- Four compile configurations had 0 errors.
- Probe parity was 0 px against the Python references: 5,752 fit cases, 768 hair cases.

**To do first:**

1. Run the focused unit tests when no live server is running in this checkout.
   - Tests:
     - `portal_test/bulge_renderer` and its subtypes; `underwear_restrains` is new.
     - `breast_bounce` and its subtypes; `flexing_top` was rewritten and now requires motion from the first flex.
     - `fitted_garments` and subtypes.
     - `fitness_definition_follows_limb`, `fitness_sheet_states`.
     - `pec_states`, `breast_jiggle_states`.
     - `portal_test/body_hair`, `portal_test/bulge`.
     - `interaction_chest_words`.
   - **Recipe:**
     1. Copy `tgstation.dme` to `tgstation.test.dme` and append an absolute `#include` of a focus file that sets
        `test_flags = UNIT_TEST_FOCUS` on each test.
     2. Compile with `"/c/Program Files (x86)/BYOND/bin/dm.exe" -DCBT -DCIBUILDING tgstation.test.dme`.
     3. Run `dd.exe tgstation.test.dmb -close -trusted -verbose -params "log-directory=<name>"`. Use `dd.exe`;
        `dreamdaemon.exe` exits at once.
     4. Judge by `data/logs/<name>/clean_run.lk` and `data/unit_tests.json`, not by the exit code.
   - **Before running:**
     - Stash `.dmi` changes, since DreamDaemon can rewrite them.
     - Copy `data/` round-end files (RecentMaps.json, RandomizedChemRecipes.json, bunker_passthrough.json,
       custom_outfits.json, delamination_highscore.txt, engravings/) and restore them after.
     - Delete the `tgstation.test.*` outputs when done.
2. Ask Pol to check in game:
   - `*pflex`, together, alternating and slow, a few seconds after putting on a top over pecs, watching for a flicker on
     the first flex;
   - a hard skirt over briefs;
   - the leotard over a jockstrap at size 5+;
   - a chastity cage under a skirt or jumpsuit;
   - swapping underwear under a skirt;
   - pubic hair under the jockstrap and mankini in side views;
   - Athletic and Muscular polos in profile;
   - Taller, Tallest, Shortest and Dwarf characters flexing.

## 3. Recolourable augment finishes: built, uncommitted

**State (2026-10-14).** Built and verified in the working tree on `bulge` (nothing committed). Pol has had a first
in-game look, and his round 2 requests are built (below). His art adjustments are still open. Eleven finishes on the
Muscular outline:

| Finish | Lights | Notes |
|---|---|---|
| Jet Plating | no | Pol's settled V3 (front A greaves, back 1, side 1, sole border) |
| Jet Boots | no | V4, the alternate of Jet: knee pads, cuff points, strapped foot |
| Silverhand, Ghostrunner, Maelstrom Wired, Maelstrom Brute | yes | approved pass-5 designs |
| Gorilla Arms | no | approved pass-5 design (no lights in it) |
| Synthflesh | yes (small LEDs) | Detroit-style chassis inserts at elbows and knees |
| Maine | no | synthflesh plates, metal gauntlets, a knee band wrapping the leg (Pol) |
| Automail | no | FMA steel plates, brass rings, dark fists with a steel finger row |
| Synthskin | no | new (Pol): the body's skin cut into panels by recolourable seams, steel by default |

**How it works.** The authority for the design is the spec
`docs/superpowers/specs/2026-10-14-recolorable-augments-design.md`. Its "Changes since approval" note lists Pol's
mid-build overrides. In brief:
- Each finish has up to four player colours (paint, accent, frame, lights) plus the body's own skin.
- The sheets are generated: a skin base in two ramps, plus packed `_paint`/`_glow` states. They are tinted at draw time
  by numeric 4x4 colour matrices, so no icon is ever generated for a colour.
- `/datum/element/augment_paint` draws the copies and keys the limb icon cache, and only finished limbs carry it.
- Colours are saved per slot (`augment_limb_colors`).
- The editor is a flyout in the Augments room, with presets, channel pickers, Copy, Reset and a dark view.
- Everything is documented in `modular_aphelion/modules/bulky_augments/module.md`.

**Round 2 (Pol's first in-game look).** The brief is `round-pol-2.md` in the ledger folder.
- **Hover try-on.** It works the way the markings room's does: client side, with no server traffic until a pick.
  - `augments/tried.ts` is a store; `tryOn.tsx` draws the tried finish over the body scan.
  - The worn limb is masked out through the preview's region map (`regionsMask`). A far leg in profile stays behind the
    near one.
  - Brand styles try on from their own sheet, `augment_brands`: 680 sprites, about 141 KB.
    - Since round 3 it isn't sent with the window. The window asks for it once, in the background: after a short dwell on
      the Augments+ tab or the room's Augments button, or when the stage mounts and the window is idle.
    - Until it arrives, a brand try-on changes nothing.
  - "None" tries on the item's `default_style`: Cyborg or Surplus for the arms and legs, but never a leg on a
    digitigrade body. Heads and chests get nothing.
  - The finish a part already wears isn't tried on.
- **Click-away.** A press anywhere outside an open flyout closes it, except:
  - the window's drag and resize handles;
  - the scan's rotate buttons and lights key (Pol, round 3). They keep the flyout open, and a tried finish survives the
    trip to them, so it can be turned and lit.
- **Digitigrade bodies** are offered only the styles the server keeps, in every slot (round 3).
- **Palette tag and light key.** Recolourable rows carry a palette tag. The scan has the shared `PreviewLightKey`.
- **Markers.** They land on each zone's middle in every facing, and hold across redraws.
  - A zone hidden in that facing lands on its pair.
  - Taur legs land on the taur body.
  - A missing limb keeps its card's fixed port.
- **Fitness sleeve colours.** `garment_fitting.dm`: a widened sleeve's darkened edge now steps only among the sleeve's
  own colours, and within the darkened pixel's own family. This was v11 and then v12; the reference is `fitref_v12.py`.
  - It fixes the sailor dress's blue and the cowboy uniform's brown, plus a few hundred other states.
  - `longstripe_blue`'s edge changes by 4-8 px. Pol approved the new look after a zoomed before/after.
**Editing the art.**
- Sources: `tools/bulky_augments/art/<id>/`, four PNG strips plus `finish.json`. Regenerate with
  `python tools/bulky_augments/gen_augment_sheets.py`; `tools/bulky_augments/README.md` explains both.
- Working Aseprite docs (git-ignored, not in Temp): `.superpowers/sdd/bulky-augments/ase/<id>.aseprite`.
- Workbench, critique sheets and blind A/B keys: `.superpowers/sdd/bulky-augments/augwb/` and `critique/`.
- References: `.superpowers/sdd/bulky-augments/refs_*/`.

**Verified.**
- DreamChecker 0. Production compile 0 errors.
- Focused unit tests pass: the four `augment_paint` tests with `focus_only/invalid_emissives` on, plus the fitness,
  fitted garments, augment items and limb cache tests.
- The var-cap battery is 20/20 clean (see section 4).
- tgui: 412 tests, tsc, lint, build, and 90/90 headless hit-test probes across all 15 themes.
  - Round 2: 416 tests, mutation-checked, plus 165/165 headless probes and 30/30 pixel checks across the 15 themes.
- An in-game render harness covered every finish on pale, dark and lizard bodies, clothed, dropped and through the
  preview path. It caught and fixed white skin on spawned limbs.
  - Round 2's run also drew Pol's sailor and cowboy scene with Maine on the left arm and leg. The 11 finish sheets were
    pixel-identical to round 1's.
- The sleeve fix:
  - focused fitness tests pass;
  - an in-game dump of the fitted sprites diffs against the Python port at 0 px;
  - the `default_style` data matches the game's own draw for all 16 items, in 4 directions.
- Reviews: per-track reviews, scoped re-reviews, and a final whole-branch review on Fable ("ready to hand to Pol").
- Not done: a live DreamSeeker session with the tgui editor in a real client.

**Ledger.** `.superpowers/sdd/2026-10-14-recolorable-augments/progress.md` holds every ruling. Read its "Ruling:" lines
before changing a decision.

**Lessons that still apply:**
- Lights only where the design has them; never add lights for uniformity.
- Pixel critics without pixel tools misread by 1-2 px, so sample every claim before acting.
- Blind A/B between versions beat scores every time.
- A flat knee join or a black sole reads as boots, and a full-width dark band reads as a glove or boot.
- Lit lip over a dark gap at joins.
- Single dark pixels read as holes.
- Evenly spaced seams read as a ribbed sleeve.

## 4. Open items, later

- The Fitness Fit Review artifact page still shows the old fitness levels.
- A pre-existing husked-legs icon cache collision.
- The BYOND var cap: this branch disables 14 `~nova` test files (master's 13 plus `neuroware_chips.dm`) to keep the
  CITESTING Compile Maps jobs clean (20/20 battery, 2026-10-14). Expect a hand-resolved conflict with master's list.
  The next candidates if it tips again are `liver_nova`, `symphony_moderation`, `symphony_whitelist` and
  `world_topic_log_redaction`. The lasting fix is a BYOND bug report.
- Augment finishes: digitigrade art (finishes force plantigrade today), head and chest finishes, the spraycan restyle
  bug (`crayons.dm` passes a style datum as an icon), and shine highlights under glowing markings (parked).
- Digitigrade definition art.
- Bulge corpus rows for underwear under a cover, once Pol approves those looks.

## 5. Where things are

| What | Where |
|---|---|
| Fitness module doc | `modular_aphelion/modules/fitness/module.md` |
| Bulge module doc | `modular_aphelion/modules/bulge/readme.md` |
| Implementer briefs | `SCRATCH/briefs/physique_restructure_brief.md`, `SCRATCH/briefs/review_fixes_brief.md` |
| Review-fix probes and logs | `SCRATCH/review_fixes/` |
| Python reference fitter | `SCRATCH/fitting_spec/` (`fitref_v6.py`, `fitref_v10.py`, `fitref_v11.py` = each sleeve's own colours, `fitref_v12.py` = also the darkened pixel's own family, both 2026-10-14, `pecref.py`) |
| Height-row emulator and renders | `SCRATCH/defwb/height_flex.py`, `SCRATCH/heightrow/` |
| Augment finish module | `modular_aphelion/modules/bulky_augments/` (`module.md`) |
| Augment art sources and generator | `tools/bulky_augments/` |
| Augment Aseprite docs, workbench, critiques | `.superpowers/sdd/bulky-augments/` (`ase/`, `augwb/`, `critique/`) |
| Augment references | `.superpowers/sdd/bulky-augments/refs_*/` (the older ones also in `SCRATCH/refs_*`) |
| Augment spec, plan, ledger | `docs/superpowers/specs/`, `docs/superpowers/plans/` (2026-10-14), `.superpowers/sdd/2026-10-14-recolorable-augments/` |
