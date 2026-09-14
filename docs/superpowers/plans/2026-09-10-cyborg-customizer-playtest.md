# Cyborg customizer playtest

Work on `cyborg-customizer` is uncommitted. Use the current production build, not a focused unit-test world. The [implementation status](2026-09-09-splurt-cyborg-customization-status.md) separates automated evidence from the remaining acceptance gates; the [module README](../../../modular_aphelion/modules/cyborg_customization/README.md) defines supported models and visual-only behavior.

## Preparation

1. Build from the repository root with `BUILD.cmd` (or the maintained `tools/build/build.bat build` target). Restart the test server on that build. Record the branch, base commit, build time, BYOND version, server configuration and runtime-log directory.
2. Connect two clients to a private test round. Client A owns the cyborg; client B observes it. Use distinct character slots A1/A2 with recognizable names and different saved layouts. Enable the server and owner character preferences needed for visual customization. Leave B's independent cyborg-display preference off initially.
3. Begin with Engineering / Drake, default hardware size and all visual parts inactive. Choose a visible accessory for one part. Keep screenshots of the creator and both clients, including the direction and pose being tested.

## First smoke pass

| Action | Expected result |
| --- | --- |
| Open ordinary character setup, visit other pages, then open Cyborg Character | Other pages remain usable, including AI settings. Cyborg data appears on its dedicated page. Closing/reopening leaves one usable editor. |
| Change a layout offset in A1 and immediately switch to A2, return, close and reconnect | A1 retains the edit; A2 is unchanged. The last slider value survives without waiting for the debounce interval. |
| Edit and immediately export preferences | The exported A1 JSON contains the last layout value. Import it into a separate test slot and verify a matching layout without changing another slot. |
| Delete or import-replace a slot immediately after editing it | The old pending draft never returns. A future schema produces a preservation notice and remains unchanged after close/export. |
| Set a south-direction offset, select an otherwise unset resting-pose override, then change only visibility | The editor shows the inherited placement and preserves the other values on the first edit. An explicit pose override takes precedence. |
| Save ten presets, attempt an eleventh, try an existing name, explicitly overwrite, then reload | Overflow and implicit overwrite give visible refusals. Explicit overwrite succeeds. Loading changes layout/colors only; name, sprites and size remain intact. |
| Save distinct Engineering/Drake and Medical/Drake defaults | Each department loads its own default despite the shared skin name. Preview selection does not select the playable chassis. |
| Enter a cyborg, open RoboTact and its self-interaction tab | Both show working controls bound to the owning body and character slot. Parts start inactive; activation is separate from saved layout. |
| Activate the configured part; toggle B's display preference on and off | Only opted-in viewers receive the art and visual examine description. A's independent display preference does not control B. |
| Disable owner character consent or the master preference, then reload configuration with ERP disabled while stationary | Existing art disappears immediately. Re-enabling permits eligible rendering again without duplicating holders. |
| Walk, turn, rest, tip, recover, die, reset model and apply/remove a disguise | Anchors follow supported animation; tipped/dead/disguised states hide the underlying customization. Recovery restores the eligible appearance. |
| Apply resizing hardware, change cosmetic size repeatedly, reconnect | Cosmetic size is idempotent and retains the hardware multiplier. Restricted wide/small/special models obey their documented limits. |
| Use Cheer between human/cyborg participants and human Headpat with/without an active hand | Only supported actions appear and execute. Hand requirements remain enforced. Existing human interaction and layering controls still work. |

Stop the smoke pass at the first reproducible runtime or persistence/visibility defect. Record exact actions, model, pose, direction, selected character slot and relevant runtime lines before changing the setup.

## Broader acceptance after the smoke pass

- Exercise normal roundstart, latejoin, converted, constructed and ghost-cafe cyborgs. Include client transfer/reconnect and switching the active preference slot while a body remains bound to another slot.
- Capture all six authored families (Drake, Borgi, Otie, Vale, Hound, Alina), every available pose and all four cardinal directions, idle and moving. Use the manifest's explicit static fallbacks; metadata compatibility alone does not establish correct placement. Include at least one skin using manual placement.
- Check hats, lights, held tools and body occlusion at several cosmetic/hardware sizes. Compare creator placement directly with the live body rather than accepting either image independently.
- Have B enter/leave view, become an observer, reconnect and transfer bodies. Check for stale or duplicate private images and confirm opted-out viewers never receive them.
- Repeat 100 actual creator open/edit/close cycles and bounded model cycling. Record before/after object counts, temporary files and cache/memory behavior after cleanup. The automated backend lifecycle test is not this client exercise.
- Run three matched baseline/feature pairs covering cold/warm open, sustained editing, idle owners and walking/turning owners. Keep map, population, scene, duration and hardware equal. Record server CPU, memory, tick usage and editor latency; define acceptable budgets from those observations before wider use.

## Evidence to retain

For each failure, retain the shortest reproduction plus both clients' preference states, screenshots and runtime-log timestamps. For each pass, record the tested creation route/model/pose/direction rather than a blanket feature pass. Keep full-suite failures and hosted CI status separate from client acceptance. Neither a successful smoke pass nor the focused automated suite is a release-readiness claim.
