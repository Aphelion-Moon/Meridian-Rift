# scenegirlsimulator handoff for Codex (2026-09-26)

Purpose: give an agent with no prior context everything needed to continue work on the
`scenegirlsimulator` branch of Meridian-Rift (a tgstation/Nova-based SS13 codebase, BYOND DM +
TGUI). The branch adds the custom sprite editors: custom hair and facial hair, whole-body
markings, the salon tattoo/barber flow, and their server-side hardening.

## 1. Where things are

- Repository: `C:\Users\Pol\Documents\Meridian-Rift`. The branch lives in the linked worktree
  `C:\Users\Pol\Documents\Meridian-Rift\.worktrees\scenegirlsimulator`. Work there. Do not create
  new worktrees, do not switch branches; the main checkout is on another branch with its own
  uncommitted work.
- Branch `scenegirlsimulator`, merge-base with `master` = `da61a88cd96a`. HEAD at hand-off:
  `146d15b98c1f` ("updates"). `git diff --stat da61a88cd96a` = 151 files, +23,510 / -225.
  The working tree is clean apart from the untracked `docs/` folder (plans, specs, this file).
- Feature code: `modular_aphelion/modules/custom_sprites/code/` (8,375 lines):
  `salon.dm` 1512 (salon sessions, consent, donors, tattoo/barber editors), `editor.dm` 1274
  (`/datum/custom_sprite_editor` base: ui_data/ui_act, drafts, candidates, hairstyle window),
  `workspace.dm` 823 (sprite-editor workspace subtype: palette, history, strokes, placements,
  regions), `markings_editor.dm` 698 (whole-body markings editor over the region canvas),
  `transfer.dm` 533 (import/export of style files), `limits.dm` 496 (background subsystem
  `SScustom_sprite_work`, per-player pace, stroke budget/queue, caps), `appearance.dm` 472
  (rendering of paint on mobs: hair, markings, taur, emissives), `images.dm` 459 (flatten
  helpers, guides, cover rows, caches), `mirror.dm` 423 (mirror previews), `saved_styles.dm`
  369, `codec.dm` 350 (drawing encode/decode/validate, versions), `persistence.dm` 226
  (savefile sidecar), `composite.dm` 225, `regions.dm` 192 (region map/zones), `compose.dm` 159
  (markings previews composed from canvas + body layers), `tools.dm` 108, `achievements.dm`,
  `palette.dm` (account palette preference), `appendages.dm` (added 2026-09-27: hair appendage
  validation, rendering, the Try on hats and the editor's appendage actions).
- Defines: `code/__DEFINES/~aphelion_defines/custom_sprites.dm` (widths/heights, versions,
  colour limit 63, budget/pace constants).
- Nova-side salon items: `modular_nova/modules/salon/` (scissors, razors, hair tie, misc items)
  and `modular_nova/modules/hairbrush/`.
- TGUI: `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/` (`index.tsx` editor window,
  `Palette.tsx`, `RegionOverlay.tsx`, `regions.ts`, `canvas.ts`, `types.ts`; hair layers in
  `appendages.ts`, `LayerStrip.tsx`, `AppendagePanel.tsx`, `LayerCanvas.tsx`; tests beside them),
  the hair layer glyphs `tgui/packages/tgfont/icons/zaphelion-*.svg`,
  `tgui/packages/tgui/interfaces/common/SpriteEditor/` (shared canvas; upstream tgstation code
  with marked Aphelion edits; Aphelion-owned files carry the header
  `// THIS IS AN APHELION UI FILE`: `Types/Tools/Select.ts`, `selection.tsx`, `strokeMask.ts`,
  `drawBounds.ts`, `useSpriteEditorHotkeys.ts`, `useClaimedKeys.ts`, the tests),
  `tgui/packages/tgui/interfaces/CustomSpriteMirror.tsx`,
  `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx` (Nova UI
  file), styles in `tgui/packages/tgui/styles/interfaces/CustomSpriteEditor.scss`.
- DM tests: `code/modules/unit_tests/~nova/custom_sprites/*.dm` (appendages, appearance, blending, codec,
  composite, editor, hair_interactions, hardening, lifted_hair, markings_editor, palette,
  persistence, region_selection, regions, salon, save_compatibility, saved_styles,
  selection_placement, tall_hair, taur_paint, transfer, workspace), included from
  `code/modules/unit_tests/_unit_tests.dm` inside the existing NOVA EDIT block.
- Appendage harness (added 2026-09-27, not in any build): `tools/custom_sprite_harness/`
  (`harness.dm`, `run.sh`, `README.md`). `bash tools/custom_sprite_harness/run.sh` from the
  worktree root builds a copy of the game with `harness.dm` appended, runs it headless and prints
  `data/custom_sprite_harness/report.md`: the in-game checklist for hair appendages driven the way
  a window drives the editor, each step timed with its update and background work, then replayed
  as a hostile window at tgui's topic limit, with the procs behind anything over budget.
- Behaviour reference: `modular_aphelion/modules/custom_sprites/module.md` (about 1,130 lines).
  It describes intended behaviour, limits, file roles and tests. Keep it accurate when behaviour
  changes; never change behaviour to match a stale doc line without checking the code.
- Plans and ledgers from the previous passes: `docs/superpowers/plans/*.md` (the latest is
  `2026-09-25-scenegirlsimulator-hard-look.md`, 16 tasks) and the git-ignored
  `.superpowers/sdd/<plan-name>/progress.md` ledgers (per-task record with rulings).

## 2. Rules that apply (from the repository owner)

1. Edit markers. Every edit to an upstream file needs an inline marker:
   `// APHELION EDIT ADDITION`, `// APHELION EDIT CHANGE - ORIGINAL: <original line>`,
   `// APHELION EDIT REMOVAL`, with `START`/`END` variants for blocks. Upstream means anything
   under `code/` except tests under `code/modules/unit_tests/~nova/`, and any tgui file that does
   not start with `// THIS IS AN APHELION UI FILE`. Never put markers in `modular_aphelion/`,
   `modular_nova/` (vendored, treated as our own) or Aphelion-headed tgui files.
2. Prefer fixes inside the owning module over edits to tg files.
3. DM conventions: unit tests use `TEST_ASSERT`/`TEST_ASSERT_EQUAL` (only available in unit test
   scope) with cleanup in `Destroy()` or via `allocate()`; iterate with
   `for(var/key, value in list)` rather than `list[key]` lookups; assign a proc-call or
   list-index result to a typed local before calling a proc on it (DreamChecker static typing);
   terse inline comments; a `///` doc line on every proc, `/** */` blocks for complex ones.
4. No unit tests for wording, titles or tooltips; test behaviour only. Long tests (measured:
   more than about 2 s, or any real-time sleep/wait) declare `priority = TEST_LONGER` on the
   test datum.
5. TGUI: styling in SCSS classes (`CustomSpriteEditor.scss`), inline styles only for computed
   per-item values; format with biome; keep test files under 50 KB; DM sends 0/1, never compare a
   flag to `false` in TS (`BooleanLike`).
6. Deleting a DM test file: remove its `#include` from `_unit_tests.dm`. Deleting any other `.dm`:
   remove it from `tgstation.dme`. Deleting a tgui file: fix every import.
7. Do not commit, push, stash, reset or discard changes unless the owner asks. Leave changes in
   the working tree. Never read or edit `data/player_saves/`; seed test preferences in memory
   (`new /datum/json_savefile(null)`).
8. Old JSON savefiles must keep working 1:1. Any change to `persistence.dm`, `codec.dm`,
   `saved_styles.dm`, `transfer.dm` or the preferences middleware must keep the
   `custom_sprite_save_compat_*` tests green and must not add savefile keys, versions or defaults
   beyond the existing additive ones (drawing version 4 = 48-row tall canvas;
   `custom_sprite_palette` player preference).
9. Never kill a DreamDaemon (`dreamdaemon.exe`/`dd.exe`) or `dm.exe` you did not start; one may be
   the owner's live server. Two DreamDaemons in the same folder collide (exit 208).
10. A headless test run can rewrite `.dmi` files; check `git status -- "*.dmi"` after a run and
    revert those.

## 3. Verification recipe (all commands from the worktree root, Git Bash)

- TGUI (from `tgui/`): `bun test` (last known: 388 pass, 0 fail, 44 files), `bun run tgui:tsc`
  (silent when clean), `bun run tgui:build`; from the root `bun run tgui:lint` (exactly one
  pre-existing warning in `tgui/packages/tgfont/dist/tgfont.css`) and
  `bunx biome format --write <touched files>`.
- DM compile-only (about 2 min):
  `cp tgstation.dme tgstation.test.dme && "C:/Program Files (x86)/BYOND/bin/dm.exe" -DCBT -DCIBUILDING -DSKIP_LAVALAND -DSKIP_SPACE_LEVELS tgstation.test.dme | tail -3; rm -f tgstation.test.*`
  Expected `0 errors, 2 warnings` (pre-existing REFERENCE_TRACKING `#warn` and loop_checks).
- DM focused unit tests (about 2 min compile + 1 min run): write a focus file outside the repo
  containing, for each wanted test, `/datum/unit_test/<name>` followed by an indented
  `test_flags = UNIT_TEST_FOCUS`; copy `tgstation.dme` to `tgstation.test.dme` and append
  `#include "C:\absolute\path\focus.dm"`; compile as above; make sure `data/next_map.json` exists
  (copy `_maps/runtimestation.json`; delete afterwards); run
  `"C:/Program Files (x86)/BYOND/bin/dd.exe" tgstation.test.dmb -close -trusted -verbose -params "log-directory=<name>"`.
  Judge by `data/logs/<name>/clean_run.lk` containing `Success!` and
  `grep -E "FAIL|Runtime in" data/logs/<name>/runtime.log` being empty; `data/unit_tests.json`
  maps each test to a status (0 = pass). A non-zero process exit is normal for focused runs.
  The full custom-sprite set is every `/datum/unit_test/custom_sprite_*` and
  `custom_style_*` root plus `limb_markings_stay_unique`, `preferences_implement_everything`,
  `preferences_valid_savefile_key` (194 tests; last run all green on 2026-09-27).
- DreamChecker (SpacemanDMM): `dreamchecker.exe -e tgstation.dme` from the root; expected
  `Found 0 diagnostics`. A copy of the binary sits at
  `C:\Users\Pol\AppData\Local\Temp\claude\c--Users-Pol-Documents-Meridian-Rift\c7c1c3bd-93aa-488e-bdf5-90ac307afe42\scratchpad\dreamchecker.exe`
  (temporary location; SpacemanDMM releases provide it otherwise). Without `-e` it reports a
  meaningless 0.
- Other CI lints: `tools/ticked_file_enforcement` schemas, `tools/ci/check_grep.sh` (needs `rg`).
- Benchmarks: a unit-test harness pattern (temporary `zz_*.dm` with `world.Profile` JSON and
  rust-g timers, included via a scratch dme) was used for all numbers below; the tgui side was
  timed in headless Edge over CDP. byond-tracy captures were taken through the meridian-mcp
  server (`C:\Users\Pol\Documents\meridian-mcp`, tools `dm_tracy_*`; its registered config needs
  `MERIDIAN_MCP_STATE_DIR` set before it connects; helpers were built under
  `C:\mtb\meridian-tracy-rift`).

## 4. Architecture in brief

- Drawings are palette-indexed pixel grids: 32x32 (hair, facial hair, limb markings), 64x32
  (taur lower body, version 3), 32x48 (tall custom hair under the "Bald (Tall Canvas)" hairstyle,
  version 4, written only when paint reaches the extra rows). Versions 1-3 are legacy formats
  that must decode byte-identically (`custom_sprite_save_compat_drawings`). Max 63 colours plus
  transparent. Emissive and gradient metadata ride in the drawing sidecar.
- Persistence: a JSON sidecar next to the character save (`character[N].{hair, facial_hair,
  limb_markings, previous_styles}`), loaded by `load_custom_sprites()` and written by
  `store_custom_sprite_slot()`; the account palette is the `custom_sprite_palette` preference.
- Editors: `/datum/custom_sprite_editor` (hair/facial hair, canvas = the head's frame; a lifted
  hairstyle such as Afro (Huge) shifts paint and guide by its `y_offset`), `/markings` (whole-body
  region canvas; each region maps to a limb zone and layer; paint under mutant parts is shown
  hatched via the cover mask), `/markings/salon` and the salon hair editors (consent, donors,
  mirror previews). The window is `CustomSpriteEditor/index.tsx` over the shared `SpriteEditor`
  canvas; strokes are computed client-side and sent as compact masks; selection moves/pastes/
  rotations/mirrors are client-side and land as one placement transaction (about 3 KB).
- Hair appendages (added 2026-09-27; design approved by the owner through mockups, spec
  `docs/superpowers/specs/2026-09-26-hair-appendages-design.md`, plan beside it): up to three
  extra layers in the hair drawing (`appendages`, keyed "1"-"3", sharing palette and size) that
  render as a hairstyle's own `hair_appendages_inner`/`_outer` pieces. In the workspace they are
  `layers[2..]` with ids; strokes carry `layerId` and are refused if it doesn't match. The window
  hands the canvas only the chosen layer (`layerTarget`) and draws the others around it
  (`stackAround()`); merged copies compose the layers client-side (`mergeLayers`, a getter so it
  is never serialized) and ask the server only for native base pixels. Only the visible view of
  each appendage is sent. module.md "Hair appendages" has the behaviour.
- Rendering: `appearance.dm` applies paint as bodypart overlays; taur paint sits 0.001 above the
  taur organ's layers; hand paint uses the high bodyparts layer; guides and previews flatten
  through `custom_sprite_flat_icon()` with an explicit clip window (getFlatIcon growth is off when
  `clip_bounds` is passed, so the window must include lifted rows).
- Hardening (`limits.dm`): all preview/guide/rebuild rendering runs in `SScustom_sprite_work`
  (background subsystem, 0.1 s fires, yields to the tick); a per-player `/datum/custom_sprite_pace`
  on preferences allows 4 rebuilds 0.5 s apart then one per 1.5 s and paces Restore previous and
  new editors; base hairstyle changes apply at once and further picks inside 0.5 s coalesce to the
  last one; strokes are budgeted at 6,000 pixels per player per second, over-budget strokes queue
  (FIFO, cap 50) and are drained by the subsystem while only strokes and view switches are
  accepted and pushes are held; bucket fills charge their filled pixels; undo history keeps 100
  steps or 40,000 recorded points; new-body rebuilds span two fires with the old resources shown
  meanwhile; candidate previews (Restore previous, tall import) render in the background with a
  placeholder card; malformed acts fail fast (tests in `hardening.dm`).
- Measured effect (harness medians): Restore previous act 57.6 -> 0.3 ms; over-budget stroke act
  17.8 -> 0.06 ms; full tall stroke 17.7 -> 9.8 ms; largest rebuild fire 64 -> 33 ms; markings view
  switch after a refresh 45 -> 0.4 ms; server tick p95 under hostile spam 60 -> 5 ms (Tracy).
  Remaining ceilings per hostile player: about 65 ms/s of paced rebuilds, hairstyle spam about
  67 ms/s sustained, tall stroke floods within the budget about 50-150 ms/s.
- Appendage harness (2026-09-27, `tools/custom_sprite_harness/`), server time per second of a
  hostile window at the topic limit, first run -> final: base-style flips under three painted tall
  appendages 219.6 -> 44.7 ms/s (a `hairContext` step instead of a whole-layer replacement, the
  preview body kept); flips that resize the canvas 121.8 -> 70.7 (in-place `resize_height()`, a
  cheaper edited-view scan); whole-canvas pastes 52.8 -> 22.4 (placement check); whole-canvas
  strokes on four layers about 53 (the stroke budget's ceiling). Largest update 74 -> 60 KiB (hat
  masks as hex rows); opening the editor about 200 ms (paced). Window (headless Edge, three
  appendages and a fedora): update 4.1-4.3 ms, layer switch 3.4-3.9 ms, hat switch about 4.8 ms,
  after caching the overlay's theme colours and memoising the hat chips' tooltips.

## 5. Open decisions and known issues (owner's call)

- Decisions taken by agents that the owner may still revise: TEST_LONGER threshold 2.0 s;
  candidate previews arrive one 0.1 s fire after the card; the stroke-queue ignore window (only
  reachable past 6,000 px/s); new-body rebuilds cost one extra 0.1 s fire; hairstyle window 0.5 s;
  tall canvas height 48 and the style name "Bald (Tall Canvas)"; Select tool hotkeys R/Shift+R
  turn, Shift+H mirror, Enter drop, Ctrl+C/Ctrl+X/Ctrl+V clipboard (window lifetime, Select tool
  only), and the owner-approved Merged toggle and Ctrl+Shift+C for merged copies (Shift+C is gone);
  shaving/clipping/cutting to Bald removes custom hair paint for the round only.
- Pre-existing bugs found and deliberately left alone: `modular_nova/modules/salon/code/scissors.dm`
  lines ~53 and ~78 use `!x == "Bald"` / `!x == "Shaved"` (always false);
  `code/datums/diseases/advance/symptoms/shedding.dm` ~36 stage 3-4 check is inverted;
  `code/modules/clothing/head/wig.dm` ~87 copies named styles only (a custom-haired bald target
  gives the wig no style); a failed save during a slot switch strands the editor on its old slot;
  applying preferences twice to one body with the Aloof personality runtimes
  ("living_start_pulled overridden"). (`custom_style_parse_hostile` now builds its oversized
  string by doubling; tg's `repeat_string` is quadratic and took 2.4 s at the 32 KiB cap.)
- Possible follow-ups not done: merge the salon editor subtypes' nine duplicated hook overrides
  behind a session var (~45 lines, design trade-off); a per-editor stroke-pixel budget beyond the
  per-player one; packed undo-history storage; composed markings previews are still 32 rows, so a
  lifted afro is cut in that preview; golem/ghoul heads have a pre-existing +-1 px face offset the
  guide does not include; the canvas wire palette grows until a full rebuild (a 3-digit code path
  exists for that reason).
- Unrelated changes riding on the branch (not custom sprites): `tools/painting_store/*`,
  `tools/build/build.ts`, `tools/ticked_file_enforcement/ticked_file_enforcement.py`,
  `PlantAnalyzer/Tray.tsx` inline styles, `ghostcafeturf.dm`, `strapon.dm`,
  `modular_aphelion/modules/worn_emissives/`, and the character setup speed-up in
  `modular_nova/.../species_features/digitigrade_legs.dm` (with its test
  `code/modules/unit_tests/~nova/digitigrade_legs.dm`).
- On 2026-09-27 an agent drove a live client for the character setup preview (tall bodies, tall hair,
  the Quirks page's hidden preview); see the traps below for what that can and cannot show. The
  owner still tests in game. In-game checks worth doing after any change: open each editor (hair, tall hair, markings on a taur, salon), paint a
  long stroke then switch views quickly, Restore previous, import a style, rotate/mirror a
  selection, cut hair with scissors on a custom-haired bald character.

## 6. Traps learned the hard way

- DM sends 0/1 to tgui, never booleans; `=== false` checks silently fail.
- Runtime-generated icons stringify to `""`; never key a cache by `"[image.icon]"`.
- `getFlatIcon` returns null for an empty appearance and grows its canvas only when all four
  edges move; with `clip_bounds` it never grows, so lifted or wide overlays need the window
  moved explicitly.
- `compare_list(null, null)` is FALSE; `overlays -=` on a copied appearance is a no-op.
- `COMSIG_CARBON_GAIN_ORGAN` fires before the organ's overlay is added, so anything layered
  relative to that overlay must not rely on insertion order.
- `text2file` appends; use `rustg_file_write` for fixtures. tg's `read_preference()` writes a
  missing preference's default into the save on first read (additive).
- biome re-wraps JSX; anchor scripted edits on the formatted text. tgui splits acts over 2,048
  characters into chunks and each chunk counts against the 10-per-second topic limit, which is why
  strokes are sent as one compact mask.
- Focused runs need `data/next_map.json`; `dreamdaemon.exe` exits 152 from bash, use `dd.exe`.
- Neither `deep_copy_list()` nor `deep_copy_list_alt()` copies a frame (a plain list of row
  lists) row by row; copy rows explicitly when a copy must not share pixels.
- `tgfont:build` runs `svgo` over `tgui/packages/tgfont/icons` in place, and glyphs must be filled
  shapes: outline strokes first (Inkscape `object-stroke-to-path` then `path-union`), and check
  `git status` for rewritten icons afterwards.
- A stroke mask that names any bit past the canvas is refused whole. A whole 32x32 canvas is 170
  `_` then `f` (1,024 = 170 x 6 + 4), not 171 `_`; 32x48 is exactly 256 `_`. Tests build masks
  with `custom_sprite_hardening_mask()`; the harness with `custom_sprite_harness_full_mask()`.
- The workspace caches `used_colors()` until `pixels_changed()`, `layers_changed()` or
  `update_edited_direction()`; anything that writes frames directly (outside `transact()`) must
  call one of them afterwards.
- `can_transact()` copies the points it's given (the history writes each pixel's old colour into
  them, and callers may reuse theirs); only a decoded mask's points, which are its own, are kept.
- A new hairstyle never recolors paint (only a new colour on the same style maps shades), so
  `apply_hair_context()` records a `hairContext` step (old and new look only) instead of
  `replace_drawing()`, and the rebuild keeps the preview body (`request_rebuild(reuse_body = TRUE)`).
- Character setup's dummy is one `KEEP_TOGETHER` image, and its height filters apply to the whole
  body with tg's 32x32 maps on the body's own tile, so anything above the tile (tall paint, lifted
  hairstyles, tall hats) used to stay put and lose or repeat rows at the tile edge. The dummy's
  `apply_height()` override in `code/appearance.dm` carries each map 32 rows up and adds a
  transparent 64-row spacer, because the body is drawn only as far as its images reach and lifted
  rows are otherwise cut off. In game, hair takes only the head's pixel offset and never tore.
- DreamSeeker doesn't draw its maps while its windows are covered, so PrintWindow, BitBlt and
  Windows Graphics Capture all return black or blank maps from a background client. Use
  `client.RenderIcon()` for pixels: strip the emissive planes (their blockers paint black without
  plane masters), put the preview canvas on the body's plane, and zero the root's `pixel_x`.
  Posted clicks on a map control plus a `/client/Click` hook report the `screen-loc` under a
  point, which measures what a map shows without any capture.
- The Quirks page's hidden 1 px `CharacterPreview` is load-bearing: a recreated map control keeps
  the view size last computed for its id, so growing the canvas (Oversized) while no control exists
  leaves the preview zoomed for the old size. Measured with and without it on 2026-09-27.
- The preview resets DNA features before every render, so the legs preference always saw a change
  and rebuilt the whole body; its limb swaps now run as one render batch
  (`STOP_OVERLAY_UPDATE_BODY_PARTS`), taking warm preview updates from about 23 ms to 14 ms.
