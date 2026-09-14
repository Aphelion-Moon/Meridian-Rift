# Custom hair and marking editors

Implements the approved Custom Hair & Custom Markings Pixel Editors workplan.
The two preference windows share SpriteEditor, a bounded palette-index codec,
and a lazily loaded `custom_sprites.json` sidecar. Existing drawings render even
when editing is disabled.

## Implementation

- Shared SpriteEditor validates transaction geometry, palettes and history metadata,
  clips strokes to bounds, supports history jumps and keyboard shortcuts, and exports
  generated icons without passing runtime files through the compiled-asset API.
- Pencil and eraser strokes include their release position and send one transaction.
  Changing direction cancels the previous optimistic preview.
- Each slot stores independent hair and marking drawings in a lazy sidecar. Drawings
  use a bounded palette-index RLE format with a flat fallback. Ordinary preference
  saves do not rewrite the sidecar; deletion and successful imports clear old data.
- Hair uses private, masked icons before colour and gradient processing, or a separate
  tint overlay. Markings clip to individual limbs and split across both leg layers.
  Content and body geometry participate in cache keys; detached limbs retain snapshots.
- Separate preference windows provide sampled shades, four directions, a guide,
  debounced previews, tint, clear, undo/redo, save-on-close and explicit discard.

`ALLOW_CUSTOM_SPRITE_EDITING` defaults to enabled. Set it to `0` in
`config/nova/config_nova.txt` to disable buttons and server actions while continuing
to render existing drawings. Character exports intentionally exclude drawings.

## Validation

Validated on 2026-09-14:

- Production entry point: completed; DreamMaker 516.1687 reported zero errors and
  zero warnings. The production TGUI bundle also compiled.
- Focused native build: zero errors, two existing test-build warnings
  (qdel reference tracking and disabled loop checks).
- Twelve focused native tests passed, including the existing paintings test.
  Native JSON results, natural shutdown and `clean_run.lk` containing `Success!`
  establish the result; the Windows process wrapper returned a nonzero code.
- Native coverage includes codec corruption, bounds/palette enforcement, history,
  per-limb and two-layer leg clipping, cache isolation, hat masking, DNA copies,
  detached/regenerated limbs, slot switching/deletion, sidecar reload/import cleanup,
  editor save/discard and rendering with editing disabled.
- All 37 frontend tests passed with Bun 1.3.5; TypeScript and scoped Biome checks
  passed. Modular include ordering and `git diff --check` passed.
- Browser qualification used native-generated guide/preview fixtures at 780 by 650.
  Both windows, continuous local drawing and direction isolation were inspected.

The initial icon-cutter run reported 40 existing missing PNG inputs. The final
build reused generated assets; this does not establish a clean regeneration of
the repository's entire sprite corpus.

Real-client acceptance remains: fast drags and keyboard shortcuts in BYOND; hair
colour/gradient/tint and hats; markings spanning limbs, digitigrade legs and species
or body changes; amputations and husks; save/relog, slot switch/delete, import/export;
and disabling editing while retaining saved appearances. Browser fixtures and
focused native tests do not replace these interaction checks or the full native suite.

Use this checkout's `BUILD.cmd` / `tools/build/build.bat` entry points. The plan's
`RIFT_BUILD.cmd` is not present in this checkout.
