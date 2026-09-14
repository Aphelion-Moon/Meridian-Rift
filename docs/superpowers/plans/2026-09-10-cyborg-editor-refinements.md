# Cyborg editor refinements

Follow-up fixes and current evidence: [Input pacing and control polish](2026-09-10-cyborg-input-pacing.md). The validation below records the preceding refinement pass; pixel positions now round to whole numbers.

Branch: `cyborg-customizer`. Changes remain uncommitted.

## Requested layout

- **Left / Identity:** name and model picker; pronouns and body size; pose and arousal; movement; active/model-default view; presets and saved defaults.
- **Center:** preview first. Fit, 1:1, Center and N/S/E/W share one toolbar with a divider. Camera/part-placement mode and optional camera settings are underneath.
- **Right:** six-part selector, sprite choice, separate authored sprite-size stepper and 25–200% scale slider, placement, supported colors, and pose/state overrides.
- Placement and overrides use inspector tabs so the normal and advanced views fit the same height. Three separate reset buttons require a second click: placement resets base position/rotation/scale, colors resets tint, overrides clears directional/pose/arousal customization.
- The Setup Character tab reads **Cyborg** and requests a 1200×940 window on entry; leaving restores the normal character or Augments+ dimensions. Smaller manually resized windows retain scrolling fallbacks.

## Supporting behavior

The model picker uses the existing floating gallery primitive with a DOM anchor, department filtering, skin search, selectable thumbnail tiles, and optional slow cardinal rotation. Rotation runs locally; additional direction images are only requested for the open department gallery.

Authored sprite size is persisted independently from continuous scale. Catalog metadata supplies available sizes, matching icons, the effective rendered size, and color channels actually used by the selected sprite. Unsupported sizes fall back to an authored variant. Legacy layout entries retain the previous default size; position defaults remain unchanged.

Part placement uses pointer capture, freezes the camera transform during a gesture, converts screen motion to unscaled world pixels with inverted Y, and submits X/Y atomically on release. Grab targets follow nontransparent sprite bounds, rather than the full padded image. Arrow keys nudge the focused part by one pixel. Read-only model-default views disable placement. Camera wheel events do not scroll surrounding panels.

## Validation

- Pinned Bun 1.3.5: **46 TGUI tests passed**, 97 expectations; TypeScript and production TGUI bundle build passed. Scoped Biome check and `git diff --check` passed. Preset/default confirmations reset if their target changes.
- Browser fixture: at the 1200×940 target, normal, override, and read-only panels had no internal overflow. The 740-pixel editor fallback retained reachable vertical scrolling without horizontal overflow. The model popup stayed within the viewport and all three representative chassis images loaded.
- Browser interactions: a 57-pixel diagonal drag at the fitted zoom saved X/Y as 9.89/9.89 world pixels; pressing Right on the focused part changed X to 10.89. The rotation toggle changed thumbnail frames. Unused color controls were absent; model-default placement controls were disabled. No browser errors or warnings were recorded. The fixture server/tab and temporary viewport override were cleaned up.
- Separate read-only frontend review found no actionable regression.
- Final production `BUILD.cmd`: pinned Bun 1.3.5, DM 516.1687 with CBT, **zero errors and zero warnings**; 1:52 compiler time, 135.821 seconds for the complete build.
- Final focused DM compile: DM 516.1687 with `CBT` and `CIBUILDING`, **zero errors**, two expected test-configuration warnings (reference tracking and loop checks), 2:01 compiler time. The temporary target selected exactly 20 cyborg tests.
- Final native run: **20/20 tests passed**, including authored sprite variants, the 200% scale ceiling, atomic placement, separate resets, global reset without a slot, and invalid-slot rejection. The result JSON contains 20 successful entries; `data/logs/cyborg-editor-final-20260910/clean_run.lk` reads `Success!`, and the runtime log records completed shutdown with no runtime-error or unhandled-exception markers. Map initialization emitted shuttle warnings. The Windows launcher reported exit 19040 despite clean test artifacts; the artifacts establish the result. Temporary focus/build files were removed, and the preexisting `data/unit_tests.json` was restored with a matching SHA-256.

Browser fixtures use repository DMI frames and real editor components, without player saves; they do not establish live BYOND window or persistence acceptance.

Reproduce the visual fixture after building TGUI:

```powershell
.\tools\bootstrap\.cache\python-3.11.0\python.exe tools/cyborg_customization/preview_fixtures.py
.\tools\bootstrap\.cache\bun-v1.3.5-x64\bun.exe tools/cyborg_customization/preview_editor.ts
```

Open the printed loopback URL. Check standard and narrow layouts, all inspector tabs, rotated model tiles, supported color counts, direct placement at different camera zooms, independent reset confirmations, and disabled model-default editing. Stop the fixture server afterward.

The running game must restart on the rebuilt DM/TGUI artifacts before checking the actual Setup Character tab. Live BYOND resizing and player-save round trips remain distinct from component, fixture, and focused DM test evidence.
