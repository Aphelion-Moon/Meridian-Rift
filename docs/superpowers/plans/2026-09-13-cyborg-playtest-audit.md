# Cyborg playtest fixes and branch audit

Scope: the existing `cyborg-customizer` branch, uncommitted. No sub-agents.

## Implementation sequence

1. Separate appearance catalogs from playable model eligibility; include authored Syndicate and Ninja families without granting hardware or changing in-round selection.
2. Keep camera zoom/anchor stable through direction, pose, and sprite changes; define 1:1 as 100% world zoom with body scale preserved. Add a fixed 32-pixel human reference, separate Center, manual gallery rotation, and movement beside direction controls.
3. Preserve part draw order while editing. Explain that layer order compares parts, while authored body masks stay above them.
4. Mirror base X and rotation on west-facing wide chassis; keep view-specific offsets explicit. Convert direct manipulation through the same mirrored coordinate system. Provide per-part opt-out and north-facing south-art reuse; persist both with layouts/presets/defaults.
5. Audit lifecycle, permissions, caching, and draft correctness across the branch. Remove unnecessary gallery/size-thumbnail generation on ordinary edits. Add focused regression coverage and use production/native/browser checks.

## Confirmed findings before edits

- PreviewPart raises selected parts to z-index 12, above both their saved priority and the body mask (11).
- The preview effect resets zoom/anchor on every direction/pose/arousal update, cancelling 1:1 and causing apparent repositioning.
- The 1:1 button divides out body scale, concealing the configured body size.
- Base placement has no east/west reflection. Animation anchors already differ by direction and must remain authored.
- Every UI update renders every model's south thumbnail, despite the gallery being closed; a 128-entry FIFO can churn across a larger catalog.
- Every update creates size thumbnails for all six parts, although only one inspector is visible.

## Implemented behavior

- Manual quarter-turn buttons and optional automatic rotation share the model gallery controls. The appearance catalog includes authored Syndicate and Ninja families; normal in-round eligibility is unchanged.
- 1:1 means 100% world zoom (32 CSS pixels per normal tile), preserving the cyborg body multiplier. A fixed-size mannequin provides a comparison. Center is a separate teal control; Movement is a colored toggle after the direction buttons.
- Camera framing stays stable while rotating, changing pose, or editing sprites. Fit explicitly recalculates bounds. Model/body-size changes and viewport resizing can recalculate Fit framing.
- Selecting a part never changes its saved layer order. Help explains that 1–10 orders parts against each other; authored body masks stay above them. Placement actions preserve view/arousal overrides.
- Wide chassis mirror base X and rotation in the west view. Authored animation anchors and per-view offsets retain their original coordinates. Direct dragging and keyboard nudges convert through the same mirror sign. Existing layouts default to mirroring; per-part opt-out is available.
- Optional per-part south-art reuse affects north-facing artwork only; north placement, pose, arousal, and layering still apply. Both settings persist through presets/defaults. No new directional artwork was authored.
- Closed galleries send no thumbnails. Open galleries generate four directions only for the selected department. Size thumbnails are generated only for the selected creator part; selecting an already selected part sends no redundant request. Body PNG caching is bounded to 512 entries with a 4 MiB encoded-data eviction budget.

## Branch audit

Reviewed the layout schema and action protocol, creator lifecycle, draft save/flush/discard boundaries, runtime actor/slot checks, appearance/model identity, viewer gating, native/preview placement, animation anchors, caches, and frontend draft controls. The findings above were corrected. Normal role selection remains separate from the expanded appearance catalog. Appearance previews use hostless model snapshots and immutable icon resources.

Additive layout fields use existing normalization/copy/preset infrastructure. Existing saved coordinates may look different in west views because mirroring now defaults on; the opt-out is intentional. Reusing south art is a workaround for missing directional artwork and still needs an aesthetic playtest.

This is a focused branch audit, not a full server performance benchmark or full native unit-suite qualification. No multiplayer or live BYOND browser session was automated.

## Validation

- Full frontend suite: 52 passed, 0 failed, 114 expectations (Bun 1.3.5).
- TypeScript check, scoped Biome/SCSS formatting, and `git diff --check`: passed.
- Final production `BUILD.cmd`: 0 errors, 0 warnings; TGUI bundle built successfully.
- Browser fixture with real local sprites: manual gallery rotation changes artwork, mannequin stays 32 CSS pixels at 1:1, rotation retains the camera transform, camera dragging over parts produces the expected pan without text selection, Movement uses selected/green state, and no console warnings/errors were captured.
- At the 1200×940 target, the inspector fits its 725-pixel area and Fit/1:1/Center/directions/Movement have identical top coordinates. At the compact 920×940 fixture, the existing two-column fallback has no horizontal overflow and keeps identity independently scrollable.
- Native focused suite: all 22 cases passed. The final test compile had 0 errors and the two expected test-mode warnings (reference tracking and loop checks). The catalog contained 317 skins, including 20 in Syndicate and 15 in Ninja; normal-role eligibility remained unchanged. Native PNG, animation, geometry, preset/import, ownership, future-schema, lifecycle, and cleanup assertions passed.
- DreamDaemon shut down naturally, wrote `clean_run.lk` with `Success!`, and left no owned test process alive. Its Windows launcher exit was 19888; qualification uses the 22 successful JSON results, clean marker, and shutdown log rather than that exit value. No runtime-error/exception/failing-test markers were found. Temporary focused DME/DMB/RSC files were removed, results retained under local scratch, and the pre-existing result JSON was restored with its SHA-256 verified.
- Python asset-builder tests: 3 passed.

## Next playtest

Restart the local server with the rebuilt production artifacts, then reopen Setup Character → Cyborg.

1. Browse Syndicate and Ninja departments; check manual and automatic model rotation and a selection from each.
2. Compare a standard biped and a wide Drake/raptor at several body sizes using Fit and 1:1. Rotate repeatedly and change pose; verify no unexpected zoom or positional drift. Center should recenter without changing zoom.
3. Move a wide-model part in east and west views. Check mirrored placement, then its opt-out. Existing west-view offsets may need retuning after enabling mirroring.
4. Enable south-art reuse for a blank north-facing selection, especially vagina. Check north placement and masking through standing/resting/sitting and arousal states.
5. Give overlapping parts different layer orders, move them, rotate, and toggle Movement. Confirm their ordering stays correct without needing the toggle to repair it.
6. Slowly drag position and color controls, then switch parts/tabs and save/load a preset/default. Confirm final whole-pixel positions, colors, mirror/reuse settings, and overrides survive reconnecting.

Work remains uncommitted on `cyborg-customizer`.
