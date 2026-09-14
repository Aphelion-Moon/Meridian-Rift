# Cyborg editor redesign status

Follow-up implementation and current evidence: [Cyborg editor refinements](2026-09-10-cyborg-editor-refinements.md). The results below describe the preceding redesign.

Branch: `cyborg-customizer`. Changes remain uncommitted.

Research and capability inventory: [design research](../specs/2026-09-10-cyborg-editor-design-research.md).

Delivered: grouped Appearance/Profile layout modeled on Augments+; independent side-panel scrolling and persistent preview; bounded placement/rotation/scale sliders with exact signed/fractional entry and keyboard navigation; color wells; synchronized selected part, pose and arousal; fitted preview with camera controls; readable labels; short model/URL inputs; confirmed preset operations; explicit read-only model-default preview; randomization/value collision fix; browser fixture and regression coverage.

Fresh evidence for this redesign:

- Pinned Bun 1.3.5 TGUI suite: 38 passed, zero failures, 78 expectations. Covers selected-part actions, readonly model preview, arousal context, inherited overrides, exact entry/clamping, presets and fitting animated/rotated/scaled bounds. Review exposed a pending-slider-value loss on unmount; the regression failed before the fix, then passed with layout-effect flushing before the editor's passive close cleanup.
- Direct pinned TypeScript check: passed. Maintained lint reports only the three existing warnings (generated tgfont CSS and two Nova imports).
- Supported production `BUILD.cmd`: DM 516.1687, zero errors and zero warnings, 1:57 compiler time; complete build 146.267 seconds. Final UI-only refinements are covered by the subsequent TGUI refresh recorded below.
- Focused backend compile: `-DCBT -DCIBUILDING`, zero errors, two expected test configuration warnings. Temporary-target DreamDaemon run: 19/19 cyborg tests passed, clean natural shutdown, `clean_run.lk = Success!`, no runtime-error/exception markers. One existing MetaStation engraving-load warning. Run-specific evidence: `data/logs/cyborg-layout-focus-20260910/`. Temporary DME/DMB/RSC removed; production target was not used for tests.
- Browser fixture: inspected actual editor components with repository sprites at ordinary, tall and compact editor dimensions. Verified negative fractional exact entry, Home/End-style keyboard adjustment, readonly placement controls, Profile sizing and maximum-offset fitting. At the standard size, both side panels had matching client/scroll widths (no horizontal overflow), and every preview image rectangle was contained within the stage. No browser console warnings/errors in the inspected fixture.
- Final refresh after the review fix: pinned Bun 1.3.5 TypeScript check passed; Rspack production TGUI build succeeded in 20.35 seconds; targeted Biome and SCSS formatting checks passed. The temporary fixture tab/server were closed. The possible interaction between wheel zoom and center-pane scrolling with expanded camera settings remains a native-client acceptance check, not a reproduced failure.

The fixture isolates presentation and simulates data/actions. It does not validate the live BYOND client, network latency, native renderer alignment or saved-profile reconnect behavior. Restart the game server and reopen Setup Character for the updated backend; use the real-client matrix in the research document for acceptance. Automatic +15 Y calibration remains deliberately unapplied pending model/part/pose comparison. Existing saved values are preserved.

No clean full DM suite, hosted CI, performance qualification or native visual acceptance is claimed. No commit, push or deployment was performed.
