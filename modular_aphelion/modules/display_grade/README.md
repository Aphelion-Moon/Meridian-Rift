# Account-wide display grade

**Implemented for local review; native acceptance remains pending.** The feature
defaults to **Off**. It has not been merged, deployed, or qualified against the
native visual/performance gates in [WORKPLAN.md](WORKPLAN.md). That file is the
supplied plan, retained verbatim. Its referenced comparison image was not supplied.

## Behavior

Game Preferences → DISPLAY → **Display grade** offers Off, Reference, Custom,
and Configure. There is one saved custom profile per account. Changing modes
preserves it. Configure starts from Reference when that mode is selected, and
otherwise from the saved custom profile (initially Reference).

The editor previews a separate client-owned draft across the world and open
interfaces. Apply validates and saves the whole profile with mode Custom in one
save operation. Cancel, window closure, forced closure, or disconnect discards
the draft. Reset restores the Reference draft; Before bypasses grading without
changing saved preferences. Controls and inline color pickers stay neutral;
only the After comparison is graded. Preview traffic uses a leading/trailing
100 ms throttle on both ends. Session tokens, sequence numbers, and timer
invalidation prevent late drags from reviving a finished preview.

Exact Reference parameters (proposed values, not measurements of the absent image):

| Control | Value |
|---|---|
| Overall strength | 100% |
| Saturation | 72% |
| Contrast | 100% |
| Brightness | 0% |
| Shadow | `#2D2639`, 100% |
| Midtone | `#718A83`, 40% |
| Highlight | `#D6C998`, 100% |

## Integration

- `code/model.dm` defines validation, normalized-sRGB coefficients, and a CPU
  acceptance oracle. The oracle is not used to recolor game sprites.
- `code/renderer.dm` owns nine native screen resources per displayed master:
  eight hidden intermediates and one output. It captures the completed master,
  weights opaque RGB branches, and restores source alpha once. Render targets
  are unique to the graph. Native raster and mouse behavior still need verification.
- `code/lifecycle.dm` attaches at displayed endpoints, excludes relaying/lower
  masters, handles map/HUD show/hide, and restores targets before floor relay
  changes. Clearing the screen, deleting a master, or disconnecting releases
  ownership. Off and zero strength remove native graph resources.
- `code/browser.dm` supplies revisioned `display/grade` settings during shared
  TGUI initialization, readiness/reload, and pooled-window reuse. This covers
  ordinary TGUI, chat, stat, lobby, speech, and escape windows.
- The common legacy wrapper and visible raw browse pages use the same bundle.
  Window generations are token-checked, updated live, and removed on close.
  Asset-cache transfer pages are not visible presentation surfaces.
- `tgui/packages/common/display-grade-bootstrap.ts` installs one sRGB SVG filter
  at the document root, including its background and portal content. Off, zero
  strength, and neutral editor windows remove the filter definition. Coefficients
  are reused until settings change. There are no recurring broadcasts or
  per-tick grading processors.

## Validation performed (2026-09-21)

- **Frontend:** 10 focused Bun tests pass, with 10,155 assertions. They cover
  the equations, validation, independent tonal anchors, grayscale continuity,
  alpha in the oracle, stale revisions, independent documents, neutral pooled
  windows, bounded SVG ownership, trailing preview updates, and cancellation.
- **Type/build:** TypeScript, focused Biome, TGUI production build, and full
  DreamMaker 516.1687 build with `DISPLAY_GRADE_PROOF` pass. The full DM build
  reports **0 errors, 0 warnings**.
- **DM runtime:** the focused `display_grade_model` RIFT test passes with a clean
  run marker. It exercises real JSON save/reload, defaults and mode preservation,
  rejected partial Apply, draft isolation, preview ordering/coalescing/bypass/reset,
  cancellation, and 20 native graph allocation/removal cycles. Its test build has
  two standard test-mode warnings (reference tracking and disabled loop checks).
- **Browser raster:** 132 SVG samples passed in Chromium earlier in this work:
  three profiles × eleven colors × four alpha values. The check uses canvas
  readback only in the acceptance harness, with 8-bit premultiplication tolerance.
  This is not evidence of DreamSeeker/browser parity.
- Aphelion include-order enforcement and diff whitespace checks pass.

Local logs are under `tmp/display-grade/`. RIFT summaries and preserved isolated
workspaces are under `data/rift-runs/`. The launcher used for validation was
retrieved from `origin/aphelion-agents` at
`98ceffea04b346eb8009e0f965cf97f6e7630950`; importing the launcher is not part of
the feature patch. No live server was modified.

### Reproduce focused checks

From `tgui/` with the repository's pinned Bun:

```text
bun test packages/common/display-grade.test.ts packages/common/display-grade-lifecycle.test.ts
bun run tgui:tsc --noEmit
```

From the repository root, with the qualified RIFT launcher available:

```text
RIFT.cmd test --profile ci --map _maps/runtimestation.json --focus /datum/unit_test/display_grade_model --network offline --keep-workspace
tools/build/build.bat build --define=DISPLAY_GRADE_PROOF
```

## Remaining native acceptance

DreamSeeker connected to an isolated RIFT server, but desktop control/capture
failed with access-denied/capture-service errors. Work continued without GUI
control at the user's request. No native captures or frame-time measurements
are claimed.

Before declaring the testmerge acceptance gates complete:

1. Compare matching native/browser swatches and a real scene, including source
   transparency, independent bands, gameplay filter ordering, and hit forwarding.
2. Exercise multiz, cameras, secondary maps, ghost/body changes, HUD rebuilds,
   emissives, lighting, pooled windows, tooltips, scrolling, and transparent overlays
   in DreamSeeker. Verify Apply/Cancel and reconnect against a real account.
3. Capture Before/After and check the intended plum/sage/cream relationship,
   red/amber/green distinction, and 4.5:1 text / 3:1 control contrast. Record existing
   failures separately. Obtain the missing approved reference image for comparison.
4. Measure three warmed-up 60-second runs of Off, Reference, and Custom at
   1080p and 1440p with zero, one, and four interfaces. Require ≤5% median and p95
   frame-time regression, no recurring stalls, and no accumulating resources.
   Include verified integrated graphics before making low-end suitability claims.

With the proof define enabled, set the saved grade to Off, close the editor, and
use **Debug → Display Grade Renderer Proof** with existing `R_DEBUG` rights.
It uses the production graph plus opaque/128-alpha diagnostic swatches on the
main map at offset zero. Swatches report clicks to chat. Changing the floor,
perspective, or HUD stops this diagnostic; regular preference attachments have
their own lifecycle. Regular builds expose no diagnostic verb.
