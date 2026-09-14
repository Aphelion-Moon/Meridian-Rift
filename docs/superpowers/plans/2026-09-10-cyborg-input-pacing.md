# Cyborg input pacing and control polish

Branch: `cyborg-customizer`. Changes remain uncommitted.

## Behavior

- Slider and palette changes update their controls locally, then submit after 350 ms without another change. Slider release, blur, and leaving the editing context flush the final value. A shared `useDebouncedCommit` hook owns the timer and captures the original action context.
- Color edits retain a local array across all channels so rapidly changing two channels cannot discard the first pending selection. Incomplete hexadecimal text does not submit an invalid color.
- Pixel positions round to the nearest whole number in exact entry, direct dragging, keyboard nudges, stored layouts, and pose/arousal overrides. Scale remains independent, with a 200% maximum. Loading an older fractional position now normalizes it to a whole pixel.
- Camera pointer gestures prevent browser default selection and focus the stage so the previous input releases keyboard focus. The stage also disables text/image selection with CSS; part handles retain keyboard focus for arrow-key nudging.
- Saved presets and model defaults have separate compact groups and hover explanations. Each action describes what it saves, loads, replaces, or deletes. Active layout and Model default share equal button margins and alignment.

## Investigation

The prior slider used a 100 ms throttle, which kept dispatching during continuous movement. The palette dispatched every change immediately. TGUI's existing expensive text input uses delayed updates; the Quirks page has a separate short action lock. The new hook uses a trailing delay with an explicit final flush so edits are retained when changing parts or closing the editor.

## Verification

- Regression tests first reproduced the slider/palette storms, fractional positions, and unprevented pointer selection. Pinned Bun 1.3.5: **49 tests passed**, 110 expectations. Includes slow continuous changes, final release, multichannel color preservation, context exit, camera focus, and whole-pixel base/override edits.
- TypeScript, scoped Biome checks, and SCSS formatting passed.
- Production `BUILD.cmd`: DM 516.1687 with CBT, **zero errors and zero warnings**, 1:47 compiler time; 129.058 seconds total. TGUI production bundle built successfully.
- Final frontend refresh after the camera-focus adjustment: TypeScript passed and the production TGUI bundle built successfully in 25.73 seconds.
- Browser fixture with actual components: Active layout and Model default both measured Y=349.53125 and height=20 pixels; the inspected sidebar had equal 725-pixel client/scroll heights. Stage `user-select` computed to `none`. Dragging over a preview part panned the camera by 45/25 screen pixels while the browser selection remained empty. Visual inspection confirmed the grouped controls fit and align. The temporary tab and fixture server were closed.
- Independent bounded source review found no actionable regression.
- Focused test build: DM 516.1687 with CBT/CIBUILDING, zero errors and two expected warnings (reference tracking and loop checks), 1:54 compiler time. **20/20 native cyborg tests passed**, including positive/negative base placement and saved directional/arousal offset rounding. Result JSON records 20 successful entries; `data/logs/cyborg-input-pacing-20260910/clean_run.lk` reads `Success!`, and the runtime log records completed shutdown with no runtime-error or unhandled-exception markers. Map initialization emitted shuttle warnings. Launcher exit 19264 is recorded separately from the clean test artifacts. The temporary test target was removed, and the preexisting test-output JSON was restored with a matching SHA-256.

The browser fixture simulates actions without player saves. Live BYOND performance under server load remains a separate acceptance check. Restart the server on the rebuilt artifacts and reopen Setup Character before retesting.
