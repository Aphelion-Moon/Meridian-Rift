# Cyborg customization verification

Use this checklist for the final source revision. Record the exact commit/source SHA, environment, command or scenario, result, and log/screenshot artifact for each completed item. Leave unrun gates unchecked. Static/source inspection, automated tests, compilation, native runtime, hosted CI, measured performance, and human acceptance are separate evidence.

## Data and generated assets

- [ ] Run `python tools/cyborg_customization/build_assets.py` from the repository root and record the output.
- [ ] Run `python -m unittest discover -s tools/cyborg_customization -p "test_*.py"`.
- [ ] Confirm every model reference resolves to a profile, profile output is deterministic, identical full profiles deduplicate, and forced digest-prefix collisions remain distinct through canonical full-profile equality.
- [ ] Compare the generated model/state/direction frame data and fallback decisions to the pre-change baseline. Confirm the 36 model/state mappings and 27 fallback cases remain equivalent unless an intentional source change explains a difference.
- [ ] Compare generated DMI/PNG decoded pixels and DMI metadata to baseline. Raw container bytes can change with Pillow/compression settings; record the environment if byte identity is part of the check.
- [ ] Confirm the manifest format version is independent of the player layout schema and that this data-only format change does not rewrite saved preference data.

## Automated and build gates

- [ ] Run the focused DM tests covering draft revisions, character-slot changes, future-schema refusal/preservation, failed writes, written saves, and session-only saves.
- [ ] Run the focused TGUI tests for editor actions, export, open/edit/close, preview camera, directional/pose targeting, mirroring, south-art reuse, sprite selection, and input pacing.
- [ ] Run the production game build and record the exact command and exit result.
- [ ] Record applicable repository CI gates for the same source revision. Keep focused local checks separate from hosted CI and full release qualification; a partial, timed-out, or earlier-revision run does not close a required gate.

## Persistence and draft lifecycle

- [ ] Create/edit presets and model defaults in multiple character slots; switch slots during a pending debounce and verify a stale context or revision cannot save into the new slot.
- [ ] Verify `JSON_SAVE_WRITTEN` clears the saved revision only after native save acknowledgement.
- [ ] Exercise `JSON_SAVE_FAILED`; confirm the draft remains dirty, visible as failed, and retryable.
- [ ] Exercise `JSON_SAVE_SESSION_ONLY`; confirm the UI does not claim durable storage.
- [ ] Verify explicit export includes the latest edit, and verify close, teardown, slot switch, deletion, and import replacement follow their documented save/discard behavior.
- [ ] Load old layout-only records, old unbound presets, and future-version records; verify compatibility and refusal/preservation behavior without accidental migration or downgrade.

## Native visual and two-client acceptance

- [ ] In the production compiled game and real DreamSeeker, compare editor preview and live appearance for a standard and a wide body across north, south, east, west, standing/rest/sit poses, movement, and supported arousal states.
- [ ] Verify authored animation anchors, fallback/static cases, occlusion masks, body-mask order, per-part layer order, side mirroring, south-art reuse, and fit/center/1:1 framing.
- [ ] Confirm 1:1 matches the current DreamSeeker map zoom and remains correct after map resize; record the client resolution and map zoom used.
- [ ] Verify spawn captures the selected body setup, later editor edits do not mutate the spawned body, and reconnect preserves the expected body configuration and temporary activation.
- [ ] With two clients, verify owner consent and server policy gates, viewer opt-in default-off behavior, visibility changes, login/logout refresh, and no image leakage to a non-opted-in viewer.
- [ ] Exercise RoboTact and interaction controls, including disabled/no-owner states and return-to-character-slot behavior.

## Policy and interaction boundaries

- [ ] Verify supported message interactions and their distance/hand requirements in game.
- [ ] Confirm visual configuration does not create physical organs, grant equipment/access/laws, or enable surgery, insertion, vore, or other anatomy-dependent behavior.
- [ ] Verify model preview selection does not alter playable model/job eligibility.

## Performance, remaining human review, and evidence

- [ ] If performance qualification is required, run three paired baseline/feature measurements in the same build environment and data setup; include at least the planned 100 open/edit/close stabilization cycles. Record elapsed time and memory results, not just cache bounds.
- [ ] Attach representative DreamSeeker screenshots or short capture for editor/live comparison and two-client visibility. State which acceptance rows each artifact demonstrates.
- [ ] Record outstanding failures, unrun checks, or environmental limits explicitly. Do not infer a pass from source inspection, a builder run, or an isolated UI test.

## Evidence record

- Source revision:
- Environment/client versions:
- Commands and focused test results:
- Production build / native suite / hosted CI:
- Native two-client scenarios and artifacts:
- Performance method and results, if required:
- Remaining gaps:
