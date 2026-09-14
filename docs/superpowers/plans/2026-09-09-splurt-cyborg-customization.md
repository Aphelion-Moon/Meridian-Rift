# SPLURT Cyborg Customization Implementation Plan

> **Implementation authorized:** Work is on user-requested branch `cyborg-customizer`; no commits are authorized. Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` and the supplied model-role guidance. The checkboxes below remain acceptance gates; see [current source and verification status](2026-09-09-splurt-cyborg-customization-status.md) for delivered work and actual evidence.

**Goal:** Port SPLURT's character-creator cyborg customization, layout presets and required runtime infrastructure into Meridian-Rift while preserving its existing character data and gameplay rules.

**Architecture:** Build a modular cyborg appearance system with one validated layout schema and one model identity/catalog shared by the creator and live robots. Adapt it to Meridian's preference lifecycle, rendering and interaction APIs; use small hooks in existing code where inheritance alone cannot safely integrate the feature.

**Tech stack:** Dream Maker/BYOND, TGUI React/TypeScript, native JSON preferences, existing sprite-accessory and client-image-holder infrastructure, DMI assets and existing rust-g primitives. Current `dependencies.sh` pins BYOND 516.1687, rust-g 6.2.0 and Bun 1.3.5; recheck at implementation time.

**Spec:** [Source research, feature contract and donor evidence](../specs/2026-09-09-splurt-cyborg-customization-research.md). Read it first, especially the distinction between character slots, layout presets and temporary preview model selection.

## Global constraints

- Baselines: Meridian `aed808fbe309de11a14d574586745f6dad79a983`; donor PR #960 head `090a9cb13722af449567867c720826eb6af215a5`. Recheck source drift before editing.
- Preserve unrelated dirty work. Leave implementation uncommitted unless committing is separately authorized.
- Use existing character slots and savefile keys where possible. In particular, retain Meridian's `silicon_headshot`, not donor `headshot_silicon`.
- Presets contain layouts only. Preview department/model changes never grant jobs, modules, laws, access, AI links or privileged skins.
- Keep ordinary character, AI, physical-organ layering, headshot and preference-import behavior working.
- Keep new module code under `modular_aphelion/modules/cyborg_customization/`. Update `tgstation.dme` and the unit-test include list for new DM files.
- No production map edits, new database, service, rust-g upgrade or Dogmos changes are required by this plan.
- Use `BUILD.cmd` or the maintained build tool, which supplies `CBT`. Do not qualify a port using a bare `dm.exe tgstation.dme` compile.
- Source research completed; parser/static tools, compilation, tests, live UI, performance and hosted CI are all unrun for this port.

## Planned file boundaries

All paths are repository-relative. New names below are proposed implementation boundaries, not claims that these files already exist.

| New file or directory | Responsibility |
| --- | --- |
| `modular_aphelion/modules/cyborg_customization/code/layout_schema.dm` | Defaults, bounded deserialization, normalization, deep copies and legacy-key translation |
| `.../code/preferences.dm` | Silicon visual/identity preferences and draft lifecycle owner |
| `.../code/model_catalog.dm` | Allowed department/skin catalog, stable identities, pose metadata and safe snapshots |
| `.../code/middleware.dm` | Creator actions/data, page activation, draft updates and flush hook |
| `.../code/preview.dm` | Preview object lifecycle, compositing and bounded preview caches |
| `.../code/appearance.dm` | Live robot application, effective size, temporary activation and renderer invalidation |
| `.../code/rendering.dm` | Pure layout-to-appearance calculations and image-holder ownership |
| `.../code/animation.dm` | Authored anchors/masks, frame timing and bounded generated assets |
| `.../code/accessories.dm` | Cyborg-only accessory descriptors and asset registry integration |
| `.../code/identity.dm` | Silicon lore/headshot/OOC fallback and examine/directory integration |
| `.../code/robotact.dm` | Runtime self-management payload/actions; uses shared operations |
| `.../code/interactions.dm` | Human/cyborg participant capability adapter and silicon self-management integration |
| `.../icons/animation_markers/`, `.../icons/occlusion_masks/`, `.../icons/accessories/` | Selected donor assets with provenance and verified local mappings |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/CyborgCharacterPage.tsx` | Dedicated creator page |
| `tgui/packages/tgui/interfaces/common/CyborgCustomization/` | Shared typed layout controls, model selector and preview components |
| `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/character_preferences/aphelion/cyborg.tsx` | Frontend feature declarations using canonical preference keys |
| `code/modules/unit_tests/~nova/cyborg_customization.dm` | Persistence, model identity, lifecycle and rendering regression cases |

Use the full module prefix for every `.../code/` entry. A separate repository-native test fixture file is appropriate only if tests need substantial reusable data. Avoid the donor's multi-thousand-line combined middleware and robot files.

## Shared contracts to settle in stage 1

These signatures and field names are the proposed integration contract. Implementers may rename them coherently before dependent stages; do not leave creator and robot implementations with separate schemas.

| Interface | Contract |
| --- | --- |
| `cyborg_layout_normalize(raw_store)` | Returns a new bounded list containing schema version, six active entries, ten or fewer presets and catalog-recognized model defaults. No UI, disk writes or robot construction. |
| `cyborg_appearance_model_id(model_type, skin_id)` | Canonical department/model-type plus explicit skin identity; identical in catalog, live selection, preset default lookup and migration. Never use display name on one side and icon state on the other. |
| `cyborg_catalog_for(preferences, context)` | Returns only supported, policy-eligible appearance descriptors. Pure descriptor reads after catalog construction; no grants or model transformation. |
| `cyborg_layout_set(preferences, slot, field, value, direction_key, state_key)` | Validates action payload and changes the current slot's draft; marks one appearance revision dirty. Missing/invalid identifiers produce no mutation. |
| `cyborg_layout_flush(preferences, expected_slot, persist)` | Commits only the matching draft, cancels its timer and uses native saving. Saving does not call back into flush recursively. |
| `apply_cyborg_customization(robot, preferences, reason)` | Copies validated preferences to a live appearance state; calculates effective size and appearance. Does not select a department or change gameplay capabilities. |
| `cyborg_build_appearance(descriptor, layout, runtime_state)` | Produces appearance layers from normalized data; shared by preview/live render paths. No preference reads, normalization or disk writes during ordinary movement. |
| `cyborg_part_capability(robot, slot)` | Returns configured/enabled/exposed information for supported visual parts. Does not masquerade as a physical organ or enable unrelated item insertion/surgery. |

Recommended storage shape, preserving donor payload semantics:

```text
silicon_genital_layout_presets = {
  schema_version: 1,
  active: { slot: LayoutEntry },
  presets: { name: { slot: LayoutEntry } },
  model_defaults: { canonical_model_id: { slot: LayoutEntry } }
}
LayoutEntry = {
  pixel_x, pixel_y, rotation, scale, colors[3],
  advanced: { direction_or_pose_key: {
    visible, pixel_x, pixel_y, rotation, priority,
    arousal: { none|partial|full: sparse_overrides }
  } }
}
```

Missing values use safe defaults. Existing unrelated character settings stay authoritative. New keys with safe defaults do not by themselves require raising Meridian's global savefile version (see `preferences_savefile.dm:12`).

## Stage 1: schema, preferences and lossless lifecycle

**Files:** Create `layout_schema.dm`, `preferences.dm` and the initial unit-test file. Modify `code/modules/client/preferences.dm`, `preferences_savefile.dm`, `preferences/middleware/_middleware.dm`; integrate with `modular_nova/modules/preferences_import/code/_sanitise.dm` and the player/admin import entry points. Add includes to `tgstation.dme` and `code/modules/unit_tests/_unit_tests.dm`.

**Consumes:** Existing typed preferences, JSON savefile and import pipeline. **Produces:** The shared layout schema and slot-bound flush contract.

- [ ] Add schema-focused tests before the feature: missing/malformed roots; numeric array keys; invalid slot/direction/state names; invalid colors; out-of-range values; and deeply nested input. Assert no input-list mutation or cross-preset aliases.
- [ ] Implement bounded deserialization for this feature instead of copying the permissive donor blob abstraction. Retain only the six supported slots and recognized fields. Bound model-default count by the supported catalog; reject unknown future schema versions without rewriting an unrelated slot.
- [ ] Add independent silicon sprite choices, size and visibility preferences. Reuse current name, gender and silicon flavor keys. Add missing identity fields with explicit fallback to existing generic OOC/model lore where empty; do not copy human values into a new silicon field automatically.
- [ ] Standardize preset names to 24 trimmed characters, ten entries maximum, explicit overwrite of an existing name, and a visible refusal for an eleventh distinct name. Loading/deleting an unknown name or cancelling a prompt is a no-op. Revalidate slot/context after asynchronous name/color dialogs return.
- [ ] Bind each draft/timer to a character slot and revision. Flush before normal slot switch/UI close/export; cancel and discard when that slot is intentionally deleted/replaced. Cover direct `load_character`, new-slot reset, admin import, player import and client destruction rather than only `ui_act("change_slot")`.
- [ ] Adapt persistence to Meridian's non-sleeping, no-argument `save_character()` and JSON disk-save path; do not copy `save_character(TRUE)` as if it provided a force flag here. Keep disk writes debounced and verify durability after reconnect, not just value-cache changes.
- [ ] Add migration handling for donor aliases only at an explicit import boundary: `headshot_silicon` to `silicon_headshot`, old pose-wide direction entries to directional entries, and known model-key aliases. Do not guess when an icon-state alias maps to multiple skins; preserve/reject with an import notice.

**Acceptance:** Edit A, switch immediately to B, return to A, close/reconnect: only A changes and all edits survive. Deleting/import-replacing A cannot resurrect its pending draft. Ten presets round-trip independently. Existing preference-import tests remain green; no human profile resets occur.

## Stage 2: catalog and a safe body-only creator

**Files:** Create `model_catalog.dm`, `middleware.dm`, `preview.dm`, the creator page and shared model/preview controls. Modify `PreferencesMenu/CharacterPreferences/index.tsx`, `MainPage.tsx`, `names.tsx`, `PreferencesMenu/types.ts`; hook `code/modules/mob/living/silicon/robot/robot_model.dm` only if descriptor extraction requires it.

**Consumes:** Stage 1 lifecycle/schema. **Produces:** A navigable cyborg page and canonical catalog shared with later live application.

- [ ] Add tests that creator and live model selection produce the same canonical ID for two skins in different departments, including identical display names. Check unavailable/privileged models never enter a normal player's catalog.
- [ ] Extract Meridian's current selection list from `robot.dm:187` into a reusable provider. Preserve config gates and special-model restrictions. Do not add donor `/robot_model/sci`, security-job behavior or admin variants just because donor code lists them.
- [ ] Build snapshots from initialized skin declarations safely. First assess Meridian's existing null-location model-preview path; audit subtype initialization before relying on it. If a catalog host is necessary, define an explicit side-effect-free initialization/destruction contract rather than bypassing the entire mob lifecycle by copying flags.
- [ ] Register an explicit active-cyborg-page state. Create preview objects and generate data only while needed; destroy/unregister them on close and replacement. Opening normal character setup must not initialize all cyborg preview models.
- [ ] Add Visuals/Lore navigation, name/gender/flavor/headshot/OOC controls, and one canonical registry for which preferences appear there. Keep AI name, core, emote, hologram and brain controls reachable. Map `silicon_headshot` correctly and retain its existing validation.
- [ ] Add department/skin thumbnails, direction, pose, zoom, background and panning controls. Explain that model selection is for preview. Discover poses from actual local states, including Meridian's alternate rest/sit states; omit absent states without breaking the editor.
- [ ] Expose the five donor size options as requested size. Clearly distinguish zoom. Until stage 3 installs the live eligibility rule, do not claim selecting size affects a playable robot.

**Acceptance:** Every currently allowed department/skin has a nonblank preview; missing states fall back safely; preview browsing does not create tools, radio/cell, AI registrations or persistent world mobs. Opening/closing the page repeatedly returns temporary objects and client map registrations to baseline. Ordinary character and AI setup remain usable.

## Stage 3: live appearance state, identity and size policy

**Files:** Create `appearance.dm`, `identity.dm`; modify `code/modules/mob/living/silicon/robot/login.dm`, model-selection/reset hooks in `robot.dm`/`robot_model.dm`, `modular_nova/modules/borgs/code/robot_items.dm`, the current silicon examine/directory consumers and relevant preference frontend declarations. Review `code/game/objects/items/robot/robot_upgrades.dm` and `modular_nova/modules/borgs/code/robot_upgrade.dm` for size composition.

**Consumes:** Canonical catalog and validated preferences. **Produces:** Live copied appearance state with deterministic model/default/size behavior.

- [ ] Test model-default lookup using a creator-saved default and the corresponding actual live skin. Test rename, same-name/different-department and temporary disguise/restore paths. There must be no implicit save when applying a default for display.
- [ ] Record real model/skin identity on selection; represent temporary disguise appearance separately. Refresh layout/default application only when relevant identity or preference revision changes, retaining an unsaved active layout when no default exists.
- [ ] Apply once client/mind and model are ready for roundstart, latejoin, `Robotize`, constructed MMI/positronic borgs and ghost-cafe borgs. Reconnect must not repeatedly multiply scale, erase an in-round activation state, or rename a converted character unexpectedly.
- [ ] Define one size calculation using requested preference scale, chassis restrictions and actual hardware effects. Recommended rule: preference sets the base visual size on eligible player chassis; existing size hardware remains a separate bounded modifier. If hardware is instead retired, make that a separately reviewed gameplay change with item/design/save compatibility. Never fake hardware installation by setting `hasExpanded/hasShrunk` solely from a cosmetic preference.
- [ ] Introduce local size constants where needed; Meridian does not expose donor `RESIZE_*` definitions in its current defines. Preserve `TRAIT_NO_TRANSFORM`, small/wide model restrictions and admin-controlled special cases. Unsupported chassis use a documented effective fallback while retaining requested size in the save.
- [ ] Route silicon lore/headshots/OOC through our `mob_examine_panel` and character directory. Apply empty-field fallbacks consistently; respect existing visibility settings. Preserve human/AI behavior and corpse/clientless fallback where currently supported.

**Acceptance:** All creation routes use the intended slot; model reset/disguise/reconnect produces the expected layout and scale without changing lawsets, tools, jobs, AI ownership or upgrade inventory. New identity fields appear in both examine and directory. Scaling hardware still behaves according to the chosen policy.

## Stage 4: visual anatomy and shared rendering

**Files:** Create `accessories.dm`, `rendering.dm`, `animation.dm` and selected DMI assets; extend preview and appearance files. Modify `modular_nova/modules/borgs/code/update_icons.dm`, `robot.dm`, the accessory base/preferences where filtering is needed, and use existing `code/modules/hallucination/_hallucination.dm` APIs. Extend schema/render unit tests.

**Consumes:** Live/preview descriptors and normalized layout. **Produces:** Six visual slots with identical preview/live placement and per-viewer display filtering.

- [ ] Inventory donor marker/mask/direct-overlay assets against Meridian's actual DMI states and dimensions. Record each asset's source SHA/license attribution and supported families. Add only matching assets; use a static/manual placement fallback for unsupported families instead of guessing donor path-based family detection.
- [ ] Separate configured, active, pose-visible and viewer-visible state. Start newly created cyborg anatomy inactive as in the donor. A viewer hiding the art must not alter another player's saved layout or interaction capability.
- [ ] Implement the six choices and three-layer color/transform schema with `None` support. Exclude cyborg-only accessories from human selectors. Use existing organ defines; do not redefine them or add physical organs to a robot just to render an icon.
- [ ] Share placement calculations between creator and live rendering, including base-pixel offsets, body scale, priority, rest state and arousal overrides. Preserve hat/light/tool/wreck/tipped overlays, which Meridian rebuilds and sometimes clears.
- [ ] Add client image holders with explicit owner/seer cleanup for logout, login, client replacement, ghosting, z transfer and robot deletion. Avoid scanning all players for each movement update; update membership on relevant lifecycle/display-setting changes.
- [ ] Port authored anchors and occlusion by descriptor metadata. Handle all eight directions with deterministic cardinal fallback when assets lack diagonals. Verify idle and movement delays, rest variants, tipped and wreck states; never return a blank layer only because direction is diagonal.
- [ ] Move expensive generation away from movement and slider hot paths. Normalize on input/load/save, cache immutable render inputs, coalesce revisions, cap preview caches (256 images/128 rendered entries or tighter measured limits), and cap shared caches by both entry count and bytes. Avoid unbounded per-pixel DM work; first evaluate existing native scaling primitives for equivalent output.
- [ ] Make temporary DMI names unique and cleanup reliable on success/failure/cancel; prevent partial generated files becoming cache hits. Reuse the existing pinned rust-g; native API availability is source evidence only until the real build exercises it.
- [ ] Evaluate whether shared spritesheet generation needs a fix after a reproducible overlap case. If it does, add a separate regression test and a failure-safe generation state; do not copy donor `UNTIL(!generation_in_progress)` without proving every error path releases waiters.

**Acceptance:** Captures for 32x32, wide, tall and small representatives match preview/live in four cardinals plus diagonal fallback, moving and every supported pose. Repeated slider edits/reopen/delete leave no stale image holders, files or uncapped caches. Opted-out viewers never receive these overlays.

## Stage 5: presets, complete runtime controls and interactions

**Files:** Finish creator shared layout controls and middleware actions. Create `robotact.dm`, `interactions.dm`; modify `code/modules/modular_computers/file_system/programs/robotact.dm` only for necessary hooks, `tgui/packages/tgui/interfaces/NtosRobotact.jsx`, `modular_nova/modules/interaction_menu/code/interaction_component.dm`, `interaction_datum.dm`, and `tgui/packages/tgui/interfaces/InteractionPanel/`.

**Consumes:** Shared schema, live appearance state and capabilities. **Produces:** Usable layout presets/defaults in creator and live UI, plus deliberately supported silicon interactions.

- [ ] Finish all six slots' global/directional/pose/arousal controls, reset actions, ten named layout presets and per-model defaults. Use the same operations in creator and live UI. Preserve sprite choices/name/size when loading a layout preset.
- [ ] Implement and mount RoboTact controls, including backend `reproductionManagement` data and every action used by the UI. Require the actor to own the current silicon tablet/body; reject arbitrary robot/organ references. The donor frontend helper alone is not an implementation.
- [ ] Introduce explicit participant capabilities for human and cyborg actors. Generalize the human-only component entry checks, UI data and interaction preconditions through that adapter. Audit action/effect bodies, not just parameter types; keep human organs, toys, clothing, species/DNA and insertion operations behind their physical-body checks.
- [ ] Connect silicon self-management to our `InteractionPanel` while preserving `GenitalLayeringTab` and underwear controls for humans. Avoid transplanting donor `MobInteraction/GenitalTab` or generalizing every living mob unnecessarily.
- [ ] Recheck config/master preferences on server actions and import/application boundaries. Viewer art visibility is distinct from consent/interaction opt-in. Restrict the supported interaction set to actions whose requirements/effects are implemented for both participants; unavailable operations remain absent.
- [ ] Add examine descriptions through existing silicon examine hooks without generating/destroying physical organs on every unrelated examine if cached descriptor text suffices.

**Acceptance:** Creator-saved presets/defaults work live; live layout edits survive creator reopen/reconnect. Cyborg self-controls, human-to-cyborg, cyborg-to-human and cyborg-to-cyborg supported interactions work in a two-client test. Unsupported physical-organ operations remain unavailable. Existing human interaction/layering behavior is unchanged. All runtime controls are mounted, have handlers and provide visible feedback.

## Stage 6: qualification and handoff

**Files:** Extend `code/modules/unit_tests/~nova/cyborg_customization.dm` and relevant TGUI tests; add module documentation with asset provenance and the supported-model matrix. Update the existing changelog format when implementation is ready.

- [ ] Run focused schema/default/import/lifecycle tests and targeted TGUI tests as stages land. Use repository `TEST_FOCUS` only temporarily for local DM runs, then remove it before final qualification; it intentionally fails CI if left enabled.
- [ ] Run `tools/build/build.bat tgui-lint`, `tools/build/build.bat tgui-test`, and `BUILD.cmd` from the repository root. These are proposed implementation checks, not commands run during this research. Record actual tool versions and logs.
- [ ] Run DM tests through `tools/build/build.bat dm-test` after appropriate preparation. This target compiles with `CBT`/`CIBUILDING`, runs DreamDaemon and checks the clean-run artifact. It clears the CI-log directory, so archive needed earlier evidence first. Record focused versus full-suite results explicitly, including `data/unit_tests.json` and runtime logs.
- [ ] Run relevant checked-in CI checks: ticked-file enforcement for the DME/module/unit-test includes, define sanity, DreamChecker and applicable icon/asset checks. Use the maintained workflow commands from `.github/workflows/run_linters.yml`; do not substitute a parser result for compilation.
- [ ] Perform real two-client acceptance covering all stages, including immediate slot switching, player/admin import, normal roundstart, latejoin, constructed/converted borgs, ghost cafe, reset/disguise, reconnect, observer arrival and display toggles. Save captures for the agreed model/pose matrix and preserve runtime logs.
- [ ] Measure cold editor open, warm open, sustained slider dragging, model/pose changes, idle borgs and walking/turning borgs with matched server populations and scenes. Use at least three paired baseline/feature runs; record wall time, DreamDaemon CPU/memory, tick usage/time dilation, render-cache hit/miss/bytes and temporary object/file counts. Set explicit budgets from that baseline before enabling widely; investigate reproducible editing-induced stalls. No speedup/readiness claim follows from static caching alone.
- [ ] Confirm that 100 repeated open/edit/close cycles and bounded model cycling stabilize cache size and temporary-object counts after cleanup. Record per-model exceptions rather than marking all skins supported from a single screenshot.
- [ ] Review final scope: no transplanted security firmware changes, resize-design removal, unrelated content edits or donor dependency upgrades. Retain attribution and remove temporary focus flags/generated test assets.
- [ ] Hand off source diff, source revisions, migration rules, supported-model matrix, exact commands/results and remaining unrun gates. Hosted CI and human acceptance are separate from local qualification. Deployment/commit/push remain outside this research request.

## Order and completion criteria

Proceed 1 → 2 → 3 → 4 → 5 → 6. Identity/lore and the body-only preview can be reviewed before the advanced renderer. The interaction adapter is a distinct infrastructure review because it touches a human-only system. Shared spritesheet changes, if proven necessary, receive their own review.

The first implementation slice should be **schema + lifecycle + body-only creator**. It establishes persistence and catalog correctness without relying on unfinished donor rendering. Full feature parity is not complete until the renderer, live controls, supported interactions and performance gates also pass.

No implementation-blocking clarification is needed to begin that first slice once implementation is authorized. Broader changes such as full-identity presets, automatic spawn chassis selection, every donor skin, generalized interactions for all living mobs or retirement of resizing hardware are separate scope decisions, not hidden prerequisites.
