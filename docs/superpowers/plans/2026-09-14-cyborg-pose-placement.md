# Cyborg pose placement follow-up

## Research and design

[Godot animation documentation](https://docs.godotengine.org/en/4.5/tutorials/animation/introduction.html) separates reset values from animation-specific property tracks. [Blender pose libraries](https://docs.blender.org/manual/en/3.6/animation/armatures/posing/editing/pose_library.html) apply identifiable poses to a selected character context; the [Blender pose-library design discussion](https://code.blender.org/2021/05/pose-library-v2-0/) explains applying and blending poses. These are references for explicit editing context and stable baseline values, rather than dependencies to add to TGUI.

The repository already has pose/direction/arousal preview selection, saved placement overrides, sliders, and pointer/keyboard placement. The missing infrastructure was a single shared editing target. The implementation reuses those systems through `posePlacement.ts` and adds no animation editor, timeline, library dependency, or new server endpoint.

## Confirmed causes and corrections

- Visual dragging and nudging always called shared placement, regardless of the override editor's selected scope. A parent-owned target now drives both the preview and numeric controls: **Shared placement**, **This pose**, or **This arousal**. The creator starts on **This pose**. Changing pose, direction, state, or target cancels an unfinished drag.
- Standing used the same directional key as the fallback for every pose. New Standing edits use `idle_north`, `idle_south`, `idle_east`, or `idle_west`. The normalizer retains those keys and the native resolver prefers an explicit pose key before a legacy direction fallback. Existing directional saves retain their prior meaning; no destructive migration is needed.
- Authored idle animation continued during manual placement. Place parts now freezes frame zero until the user returns to camera mode. Movement still exits placement mode. The preview shows the active pose, direction, state target, and paused status.
- Pose/state corrections use screen coordinates. West-facing reflection applies only to shared east/west placement. Editing X/Y preserves layer order, visibility, rotation, scale, and other saved poses/states.
- State-specific values continue to override pose defaults. Inheritance is shown explicitly, and the pose editor explains when the visible state has its own overrides. The two inheritance actions clear only the selected pose or arousal scope; the existing three confirmed reset buttons remain separate.
- Saving/edit status is at the bottom of the left sidebar in Appearance and Profile. At compact sizes it remains inside the sidebar's contained scroll area.
- Size-stepper arrows and dropdown use an explicit matching height and zero component margins. The selected sprite remains centered between them.
- Profile headshot sections and image labels now use **SFW headshot** and **NSFW headshot**.

## Validation

- Frontend regression tests reproduced shared-placement writes from the pose editor and idle animation during manual placement before the fixes. Final frontend suite: 63 passed, zero failed, 155 assertions.
- Native isolated regression first failed with Standing X=13 instead of the expected 17. After adding explicit Standing keys and resolution, all 30 focused cyborg tests passed. The final run produced a clean-run marker, natural shutdown, and no runtime/exception/failure markers. The Windows launcher returned 20704; native result JSON and shutdown artifacts establish the test result independently of that launcher code.
- Production `BUILD.cmd`: zero DM errors or warnings. The focused test compile had zero errors and two expected instrumentation warnings. Final production TGUI build and TypeScript checks passed.
- Scoped Biome, SCSS formatting, and whitespace checks passed. Test artifacts were copied aside, the preexisting unit-test JSON was restored byte-for-byte, and temporary test binaries and fixture processes were removed.

Browser fixture evidence: Standing X=17 remained unchanged after switching to Resting and nudging that pose to X=1. An Unaroused-only Y=1 correction left Fully aroused at the inherited pose Y=0. Size arrows and the dropdown each measured 24 pixels high with the same top coordinate. Reviewed the full Appearance and Profile layouts at the 1200 by 940 target and the compact 920 by 940 layout. The fixture uses native-generated images with mocked actions; it does not prove live DreamSeeker pose animation or saved-player behavior.

## Next playtest

Restart with the rebuilt server and reopen Setup Character. On a wide chassis, use This pose and Place parts to position the same part independently while Standing, Resting, and Sitting. Switch through all directions and return to each pose. Confirm the position and layer persist. Use This arousal for one state, then confirm the other states retain their inherited positions. Save/update a preset, reopen the editor, and verify the same placement after spawning a new body. Check size-arrow alignment at the user's actual UI scale and both headshot labels.

No commit, push, or live-server restart is part of this follow-up.
