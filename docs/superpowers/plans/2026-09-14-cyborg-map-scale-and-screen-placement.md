# Cyborg map scale and screen placement

The reported comparison used a newly spawned cyborg, with matching Working setup and Spawn preview layouts. An existing body's saved snapshot does not explain that comparison.

## Corrections

The old 1:1 camera used one CSS pixel per sprite pixel. DreamSeeker's map can automatically enlarge tiles to fill its control, so this was not the same apparent size as the game. The button now reads the map control's `view-size` and divides it by the current view's tile dimensions. It accounts for display pixel ratio and TGUI's optional body zoom that cancels OS scaling. Body size remains a separate multiplier. BYOND defines `view-size` as the displayed map area excluding letterboxing in its [skin parameter reference](https://www.byond.com/docs/ref/skinparams.html).

Measurement occurs once per click. An unavailable map uses the configured zoom, or source-pixel scale when automatic zoom cannot be measured. A late reply cannot replace a newer camera choice or update an unmounted preview. Click 1:1 again after resizing the map. Fit and manual zoom retain their existing behavior.

Live part placement and authored animation previously used `pixel_x` and `pixel_y`. Meridian uses `SIDE_MAP`, where those coordinates also participate in depth ordering. Cosmetic displacement now uses `pixel_w` and `pixel_z`, keeping the parts on the owner's depth row. Shared placement geometry, sprite transforms, body scaling, masks, and stored layout values are unchanged. See BYOND's [map format reference](https://www.byond.com/docs/ref/info.html#/world/var/map_format).

These are separate corrections. The map-scale error is reproduced by the old button and covered by the new frontend tests. The screen-coordinate correction removes a live/editor rendering contract discrepancy; automated tests do not establish that it resolves the exact remaining screenshot difference.

## Validation

- Frontend: 68 tests passed, 175 assertions. Coverage includes automatic map zoom, OS scaling with and without TGUI cancellation, body-size preservation, invalid map sizes, a single bridge request, and delayed replies after another camera choice.
- TypeScript, scoped Biome, and final production TGUI build passed.
- Production `BUILD.cmd`: zero DM errors or warnings. Focused native compilation: zero errors and two expected instrumentation warnings.
- All 30 focused native cyborg tests passed, including all-cardinal screen-coordinate origins, unchanged depth coordinates, mask order, inherited body transforms, and spawn snapshot isolation. This is native data/appearance verification, not DreamSeeker visual acceptance.
- The native run produced a clean-run marker and natural shutdown with no runtime-error, exception, or test-failure markers. The Windows launcher reported 19520; result JSON and shutdown artifacts establish success independently of that code. Original test results and browser fixture data were restored byte-for-byte, and temporary test files and processes were removed.
- Browser investigation used a temporary fixture with native sprite images and mocked actions. It checked CSS placement/scale; it did not render BYOND client images or prove native mask composition.

## Next playtest

Restart using the rebuilt server and reopen Setup Character. Spawn a fresh body from the same preset. With the game map visible, click 1:1 and compare the resting north-facing body and part directly. Check standing/resting/sitting in every direction, then toggle movement to check that parts remain behind their masks. Repeat 1:1 after resizing the game map. If the difference remains, capture the game alongside Spawn preview at 1:1 with matching pose, direction, and arousal.

No live-server restart, commit, or push was performed by this follow-up.
