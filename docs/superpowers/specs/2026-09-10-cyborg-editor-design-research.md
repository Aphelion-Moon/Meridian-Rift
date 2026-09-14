# Cyborg character editor: reference research and implementation

Research date: 2026-09-10. Implements the approved usability audit on `cyborg-customizer`. Existing player layouts remain authoritative; no automatic placement migration or account changes.

## References and adaptation

| Reference | Relevant pattern | Application here |
| --- | --- | --- |
| [Reallusion Character Creator: Morphs tab](https://manual.reallusion.com/Character-Creator-4/Content/ENU/4.0/04_Introducing_the_User_Interface/Modify_Morphs_Tab.htm) | Parameters grouped by body region; filtering/search; reset within the editing panel | Part selector and selected-part inspector; searchable chassis selection; scoped resets |
| [Epic MetaHuman: navigating the creator](https://dev.epicgames.com/documentation/metahuman/navigating-metahuman-creator-in-unreal-engine) | Persistent live viewport; tools grouped by purpose; separate camera/environment and animation controls; framing presets | Central preview; shared pose/arousal context; Fit, Center, 1:1, drag-pan and wheel zoom; named backgrounds |
| [Apple HIG: sliders](https://developer.apple.com/design/human-interface-guidelines/sliders) | Bounded adjustment with familiar minimum-to-maximum direction; optional exact entry; live feedback | Visible range tracks and endpoints plus compact exact-value fields; bounded update rate during dragging |
| [W3C slider pattern](https://www.w3.org/WAI/ARIA/apg/patterns/slider/) | Keyboard navigation, accessible label, meaningful value text | Native range input, associated label and unit text; Arrow/Home/End behavior |

These references describe 3D mesh morphing, skeletal rigs, materials, lighting and Unreal/desktop docking systems. Meridian uses DM preference datums, React/TGUI and layered 2D PNG sprites with authored pose anchors. A 3D renderer, mesh sculpting, rigging or a new UI framework is unnecessary for these goals. We adapt organization and interaction patterns, not those rendering technologies. No third-party art or code is copied.

## Capability inventory

Already available:

- Augments+ (`LimbsPage.tsx`): persistent preview, separate scrolling panels, searchable selections and color affordances.
- TGUI core: Section/Stack/Tabs/Dropdown/Input, confirmation buttons, slider and color components. Its installed slider uses drag-to-adjust and click-to-type; it does not expose a native keyboard slider.
- Cyborg backend: bounded placement schema, colors, directional/pose/arousal overrides, drafts, presets, model defaults, animation frames and layered previews.

Added or reorganized:

- Reusable `AdjustmentSlider`: labeled native range, endpoints, exact signed/fractional entry, server-bound clamping, throttled updates and final release delivery. Used by creator and runtime placement inspectors.
- Extracted `CyborgCharacterEditor`, `CyborgPreview` and `PresetControls`, keeping backend wiring separate from presentation and enabling a real-component browser fixture.
- Three-column editor with independent side scrolling; two-column compact arrangement; separate Profile page; single-line model name and portrait URLs.
- Preview bounds from actual PNG dimensions, rotation, scale and the union of animation excursions; responsive fitting and camera reset/pan/zoom.
- A single selected part and shared direction/pose/arousal context. Advanced edits explicitly distinguish all arousal states from the currently previewed state.
- Read-only model-default preview with explicit load into active layout. Viewing a saved default never silently replaces an autosaved draft.
- Correct preference category merging: randomization flags must never overwrite actual values. This is the verified source of gender displaying `3`.
- Explicit preset load/delete/overwrite confirmation and trimmed-name consistency.
- Local browser fixture using repository sprites, and focused geometry/component/backend regressions.

## Placement defaults

The reported +15 Y for penis/sheath on wider quadrupeds is a calibration candidate, not a universal default. The renderer already adds authored anchors to user offsets. Model, part, direction, pose, movement and arousal must be compared in the creator and live BYOND renderer before encoding a recommended placement. Zero is a valid saved custom offset, not evidence of an untouched field. Preserve existing layouts and saved defaults.

Current safe workflow: inspect a model, enter +15 Y explicitly, compare all views and save a model default when satisfied. Model-default preview now supports checking that result without replacing the active draft. An automatic family-default registry should be populated only with visually accepted values; this change does not invent that calibration data.

## Validation and visual fixture

From repository root, use the checked-in bootstrap/build entry points:

```text
tools/build/build.bat tgui-lint
tools/build/build.bat tgui-test
tools/build/build.bat tgui
tools/bootstrap/python.bat tools/cyborg_customization/preview_fixtures.py
tools/bootstrap/javascript.bat tools/cyborg_customization/preview_editor.ts
BUILD.cmd
```

The fixture prints a loopback URL. It uses actual editor components and compiled TGUI CSS, with local extracted chassis frames and simulated preference/layout actions. It cannot prove BYOND rendering parity, saved-profile persistence, live activation or network performance. It serves only explicit fixture routes, binds to loopback and never reads player saves. Stop the process after checking it. Generated data lives under ignored `data/cyborg-editor-preview/`.

Acceptance matrix: ordinary and wide chassis; 920×780 and 920×940 creator windows; compact width; initial pronoun labels; negative/fractional exact entry; Arrow/Home/End range navigation; offset and scale extremes; Profile field sizing; selected part and state synchronization; read-only default preview and explicit loading. Native playtest must additionally cover all authored poses and arousal states, animated occlusion, reconnect/save persistence and actual creator/runtime alignment before placement calibration is accepted.

Fresh verification results are recorded in the companion implementation status document; prior build/test results are not evidence for this redesign.
