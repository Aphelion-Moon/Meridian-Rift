# Cyborg runtime, placement, and profile audit

## Scope and decisions

Repair first-spawn/model-default application, separate wide-body placement by viewing group, move profile portraits to the sidebar, and align the model gallery. Runtime interaction and RoboTact panels expose usage controls only. Preserve existing human interaction behavior and authorization boundaries. Work remains on `cyborg-customizer`, without commits or sub-agents.

## Source research

SPLURT PR #960 remains open and unmerged at head `090a9cb13722af449567867c720826eb6af215a5`, verified through GitHub on 2026-09-13. It is a donor implementation reference, not a released feature contract. [PR #960](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960)

SPLURT replaces its upstream InteractionPanel with MobInteraction. The main content presents interactions, genital controls, character/content preferences, and items as separate tabs. Search applies to supported tabs; its negative bottom margins and always-present search row are implementation details unsuitable for copying into Meridian's existing panel. [MobInteraction MainContent](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/tgui/packages/tgui/interfaces/MobInteraction/MainContent.tsx)

The genital tab distinguishes physical organs from `is_simple` entries. Cyborg entries expose an active toggle and an optional three-state arousal control. The tab uses compact named rows and stateful icons rather than a placement editor. Its backend builds cyborg rows only from toggleable configured slots. Meridian can adapt that separation while retaining the local human panel's striped table and explicit visibility/arousal icon groups. [GenitalTab](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/tgui/packages/tgui/interfaces/MobInteraction/tabs/GenitalTab.tsx), [interaction data](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/modular_zzplurt/code/modules/lewd/interaction_component/interaction_component.dm#L177-L220)

SPLURT's surrounding mechanics depend on a broader interaction subsystem and simulated-genital/requirement APIs on living mobs. That infrastructure grants mechanical capabilities beyond appearance rendering. Meridian's current adapter intentionally supports audited message interactions only; making the UI similar does not justify importing those mechanics or bypassing human organ/hand checks. [Interaction component](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/modular_skyrat/modules/interaction_menu/code/interaction_component.dm), [living simulated anatomy](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/modular_zzplurt/code/modules/mob/living/living_lewd.dm)

The donor applies preferences on Login, reads sprite choices separately from layout presets, explicitly initializes activation to false, and then applies a matching model default. Its layout/default system therefore does not itself mean visible parts on spawn. Meridian inherited these semantics, which conflict with the expected complete model setup. [Donor robot preference application](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/modular_zzplurt/code/modules/silicons/borgs/code/robot.dm#L675-L709)

## Confirmed local findings

1. `appearance.dm` initializes new bodies with empty activation state. Model defaults contain layout geometry but no chosen sprites; current character-wide sprite preferences supply every model. A matching saved default can therefore load coordinates while showing no configured art. Viewer visibility is independently off by default and the runtime UI does not explain that gate.
2. `CyborgPreview` and base sliders write shared `pixel_x/pixel_y/rotation`. Mirroring fixes east/west reflection but cannot make those coordinates suitable for north/south. Advanced view overrides exist but ordinary dragging bypasses them.
3. RuntimeControls embeds LayoutControls, sends full layout stores and size thumbnails on each UI refresh, shows six rows including absent parts, and exposes geometry/preset mutations through its backend. This violates the requested setup/runtime separation.
4. Interaction MainContent uses numeric `erp_interaction && JSX`, allowing a literal zero to render. It also shows an unusable search box on control tabs and uses fixed input width/negative content margins. The local human genital table already supplies the desired compact visual pattern.
5. The model gallery lacks an explicit image/label grid with propagated tile height. Its rotation toolbar inherits a bottom margin that shifts it three pixels above the department selector. Dedicated content rows, an explicit wrapper height, and a normalized toolbar row resolve these offsets.
6. The first-spawn regression exposed an obsolete multi-signal `RegisterSignal` call in the appearance holder. Switching it to `RegisterSignals` removes the runtime error at holder initialization.
7. Profile headshot inputs are mixed into the prose column and have no preview. Existing validated saved portrait URLs can feed sidebar previews with bounded dimensions and a load-failure state.

## Implementation and acceptance

- Add additive, bounded North/South/Side placement groups. Missing groups inherit existing base values, preserving legacy layouts until a group is edited. Side mirroring still composes with authored anchors and explicit pose/arousal overrides. Sliders, dragging, and nudges use the same group selection.
- Snapshot sprite choices into preset/default entries; retain preference fallback for older saves. Resolve choices consistently in creator previews and live model application. Start configured parts active on a new body, preserve explicit hiding across reconnects, and expose independent viewer-display status/control.
- Remove runtime layout writes server-side, reduce runtime payload to configured part states and visibility status, and share a compact usage table between InteractionPanel and RoboTact. Preserve actor/owner/slot checks and reject absent-part actions.
- Move both portraits to sidebar cards; use saved values for previews. Give gallery tiles dedicated image/label slots, aligned controls, and loading placeholders.
- Add regressions for independent placement, saved sprite/default application, runtime mutation refusal, numeric-boolean tabs, and usage-only controls. Validate production compilation, focused native tests, frontend checks, and browser fixtures. Live owner/viewer acceptance remains a separate playtest gate.

## Verification

- Production `BUILD.cmd`: 0 DM errors, 0 warnings; Rspack bundle succeeded after the signal correction.
- Full frontend suite: 55 passed, 0 failed, 128 expectations. TypeScript passed; scoped Biome (19 files), SCSS formatting, and `git diff --check` passed. Asset-builder tests: 3 passed.
- Browser fixtures use real local sprites and the actual InteractionPanel component. At 1200 by 940, both portraits fit in the sidebar. Gallery selector and rotation toolbar have identical top coordinates and 24-pixel height; tiles have 104-pixel content grids with aligned 32-pixel label rows.
- Browser editing confirmed that Side coordinates 22, 7 leave North at 0, 0; changing North Y to -3 leaves West at 22, 7. Native geometry tests check the corresponding west mirror sign.
- Cyborg and human runtime panel fixtures were visually reviewed. The cyborg fixture displays configured parts, usage buttons, and the independent viewer-off explanation without stray numeric text or a disabled search field. Human genital controls remain available. No browser warnings or errors were captured.
- Native focused rerun: all 24 cases passed, including independent placement and complete model-default spawn/render/usage/reconnect assertions. Compilation had 0 errors and the two expected test-mode warnings. The initial run passed 23 cases and caught the obsolete signal registration in the new spawn case; that finding was corrected before the successful rerun.
- DreamDaemon shut down naturally, wrote `clean_run.lk` with `Success!`, and left no owned test process alive. Its Windows launcher exit was 19920; qualification rests on the 24 successful JSON results, clean marker, and shutdown log. No runtime-error, exception, or failing-test markers appeared in the final run. Temporary focused build files were removed; the prior result JSON was restored and its SHA-256 verified. The browser fixture and temporary tab were closed.

## Next playtest and migration

Restart with the rebuilt production artifacts and reopen Setup Character. Existing defaults did not store sprite choices; this cannot be reconstructed automatically. Their geometry remains intact, and they use the current character selections until re-saved.

1. On Profile, set both portrait links and check their sidebar previews. Check an invalid/dead link produces the unavailable state without disturbing editing.
2. Browse a department with many skins; check tile labels, scrollbar clearance, manual rotation, and automatic rotation.
3. On a wide chassis, edit East/West placement, then North and South independently. Check rotation, dragging, nudges, and save/load persistence. The East/West group mirrors; North and South are independent.
4. Select the intended parts, load old positioning if needed, and Save default for that exact department/skin. Save a second model with different parts. Reopen setup to verify both saved choices.
5. Spawn and choose each matching chassis through the normal in-round model picker. Verify the correct parts and placement load without a runtime preset action. Preview model selection itself still does not grant a playable chassis.
6. Open your interaction panel and RoboTact. Enable “Show cyborg parts to me” if your display is off. Check configured rows, hide/show, and arousal. Confirm neither panel contains placement, colors, or preset editing.
7. Hide a part, reconnect, and verify it stays hidden. With another opted-in viewer, verify that owner's part visibility and each viewer's personal display preference work independently.

This is source, build, focused native, and browser-fixture qualification. Full native-suite, real-client visual acceptance, and multiplayer checks remain separate gates. Runtime payloads now omit layout stores and thumbnail generation; this is a structural reduction, not a measured server performance claim. Work remains uncommitted.
