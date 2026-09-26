# Cyborg customization

Cyborg customization adds a character-setup page, shared RoboTact and interaction controls, and a visual appearance layer for player cyborgs. Character slots remain the unit of identity. Each slot stores up to ten appearance presets plus defaults keyed by model type and skin label. A preview model is an editor choice; it does not select a playable model or grant equipment, access, laws, or anatomy.

## Boundaries and ownership

| Concern | Owner |
| --- | --- |
| Layout schema, normalization, and import migration | `code/layout_schema.dm`, `code/preferences.dm`; native preference import sanitation |
| Editor draft and request lifetime | `code/middleware.dm`; the middleware owns a slot-bound draft and guards work with `context_generation` and `draft_revision` |
| Durable preference write | Native JSON preference save hooks; the middleware stages a revision and accepts only the save result |
| Model catalog and preview | `code/model_catalog.dm`, `code/preview.dm`; `CyborgCharacterPage.tsx` |
| Live appearance and geometry | `code/appearance.dm`, `code/rendering.dm`; a per-owner image holder uses shared static resources |
| Accessory data | `code/accessories.dm`, `code/direct_accessories.dm`; a cyborg-only catalog |
| Animation and occlusion data | `code/animation.dm`, `animation_manifest.json`, generated occlusion resource table |
| Identity and runtime controls | `code/identity.dm`, `code/robotact.dm` |
| Message interactions | `code/interactions.dm`; audited human/cyborg message-only adapter |

Static catalogs, profile tables, and generated resource paths are shared definitions. Owner-bound image holders, viewer image attachments, and animation state are runtime state. Do not put a transient owner or client object into shared catalog data.

## Saved data and policy

The character preference key is `silicon_genital_layout_presets`, schema version 1. Its top-level fields are `active`, `presets`, `preset_models`, `model_presets`, and `model_defaults`. Each visual part can store sprite choice, position, rotation, scale, sprite size, colors, and optional directional, pose, or arousal overrides. The six visual slots are penis, sheath, testicles, vagina, anus, and breasts. Imported known values are normalized and bounded. A future schema is preserved and the editor refuses to write it; donor key aliases are migrated only during import. This layout schema is separate from the generated animation-manifest format version.

Ordinary edits debounce for two seconds; explicit preset/default collection changes save immediately. Preset names are trimmed to 24 characters, overflow is refused, and overwrite is explicit. The pinned native writer is not atomic; success requires its empty error result and exact content readback.

The middleware binds edits and debounce timers to the active character slot, page context, and draft revision. It stages the current revision through the native preference save path and distinguishes `JSON_SAVE_FAILED`, `JSON_SAVE_WRITTEN`, and `JSON_SAVE_SESSION_ONLY`. Failure retains the dirty draft for retry. Session-only success is not durable file confirmation and must be shown as such. Slot replacement, delete/import replacement, close, export, and teardown follow their explicit draft lifecycle paths; test them rather than assuming every close is a save.

New presets snapshot selected sprites as well as layout. Older layout-only records keep their geometry and use current sprite preferences until resaved. Bound presets remember their chassis; legacy unbound presets and anonymous defaults remain loadable. The editor's model selection does not alter character model eligibility.

Configured appearance and size are captured for the body at spawn. Editor edits and reconnect do not replace that body configuration. Owner consent and the server ERP preference gate display; each viewer separately opts in through `see_cyborg_genitalia`, which defaults off. Runtime controls affect visibility and arousal, not the saved setup.

Visual slots do not create physical organs or grant anatomy-dependent actions. Supported message interactions are Cheer by cyborg actors and Cheer, Beckon, Headpat, and Pat by humans targeting cyborgs, under the audited distance and hand requirements. Surgery, insertion, vore, and anatomy-dependent sexual effects are not implied by visual configuration.

The optional second silicon portrait uses `silicon_headshot_nsfw`; the existing `silicon_headshot` remains canonical. The character fields `ooc_notes_silicon` and `ooc_notes_silicon_nsfw` stay separate from human notes; each falls back to its corresponding human field only when empty.

## Placement and preview contracts

Placement has North, South, and East/West groups for position and rotation. Unedited groups inherit legacy base values; ordinary controls edit the current group, while scale remains shared. `mirror_sides` mirrors side X and rotation westward. `reuse_south` can reuse south-facing art for north while retaining north placement and layer settings. Layer order compares accessory parts with one another and keeps them beneath authored body masks.

Fit recalculates preview bounds; Center moves the camera; 1:1 is intended to match the live DreamSeeker map zoom, against the fixed 32-pixel mannequin reference. Ordinary edits and rotation preserve framing. Preview zoom is independent of the saved body size. Requested base sizes are 0.75, 1, 1.6, 2, and 2.5; small chassis cannot shrink below 1, wide/tall chassis cap the base at 1.6, and unsupported special chassis use 1. Hardware scale remains a separate transform factor.

Wide bodies use independently authored North, South, and East/West placement. Animation anchors and view-specific offsets remain literal. Unsupported or ambiguous pose/movement sequences use the recorded fallback and do not borrow another family's animation.

The creator sends private image resources through native static UI data and sends current transforms and save state through ordinary updates. Model, pose, direction, movement, part artwork, gallery and permission changes invalidate resources; position, rotation and scale edits reuse them. Revocation explicitly clears the static payload. Placement commands carry a context token and bounded base/pose/arousal targets; the server materializes inherited overrides and applies atomic coordinate changes.

## Assets, mapping, and provenance

The offline builder accepts explicitly named local animation families with compatible dimensions, directions, frame counts, and delays, and requires exactly one cyan marker per frame. The generated `animation_manifest.json` uses format version 1: model/state keys reference deduplicated complete animation profiles. Profile IDs are generated deterministically; full canonical profile data resolves digest-prefix collisions. The runtime reader resolves the model reference through the profile table.

| Local skin labels | Donor family |
| --- | --- |
| Drake | drake |
| Borgi | borgi |
| Otie | otie |
| Vale, ValeDark | vale |
| Hound, Darkhound | hound |
| Alina | alina |

Catalog construction uses one transient null-location model item per allowed department, then deletes it; BYOND `initial()` does not return list-valued instance initializers. The audited null-host path creates no tools, storage or robot registrations; medical/miner overrides only append type paths before the guard. Cached descriptors hold copied lists and resources, never those items. The creator animates up to 32 frames locally; fallback previews remain static. The live holder follows its owner and maintains viewer attachments through login/logout/preference events.

Caches are bounded: 512 body/occlusion preview frames with a 4 MiB encoded-data eviction budget; 128 standard accessory composites with a 2 MiB estimated byte budget; 32 direct-accessory frames. Closed galleries omit thumbnails; open galleries supply four directions for the selected department only. Creator size thumbnails are generated only for the selected part. The estimates exclude BYOND allocator overhead. They are bounds, not measured performance claims.

Current source maps 36 model/state pairs to six unique animation profiles and records 27 fallback cases. These are data-compatibility counts, not visual acceptance. Other catalog skins use manual placement. The builder also derives occlusion sheets from the selected donor masks and local body colors. Runtime does not scan marker pixels, write temporary DMIs, or require Pillow.

Run from the repository root:

```text
python tools/cyborg_customization/build_assets.py
python -m unittest discover -s tools/cyborg_customization -p "test_*.py"
```

Generated data and resources must be committed with their source inputs and reader changes. PNG/DMI container bytes can vary with Pillow/compression versions; when comparing outputs across environments, compare decoded pixels and DMI metadata as well as normalized manifest data.

Donor source: [SPLURT PR 960](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960), pinned to [`090a9cb13722af449567867c720826eb6af215a5`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/090a9cb13722af449567867c720826eb6af215a5), open and unmerged when implementation began. Source adaptation follows AGPL-3.0; copied art is from the donor's CC-BY-SA-3.0 collection. Preserve attribution and source paths when redistributing or modifying the art.

| Local directory | Donor directory | Treatment |
| --- | --- | --- |
| `icons/animation_markers` | `modular_zzplurt/icons/mob/cyborg_animation_markers` | Selected family sheets |
| `icons/occlusion_masks` | `modular_zzplurt/icons/mob/cyborg_occlusion_sources` | Selected family masks |
| `icons/accessories` | `modular_zzplurt/icons/mob/sprite_accessories/genitals` | Selected accessory sheets |
| `icons/accessories/anus.dmi` | `modular_zzplurt/icons/mob/human/genitals/anus.dmi` | Exact sheet; cyborg-only Donut/Squished choices |
| `icons/occlusion_generated` | Derived locally | Meridian body colors combined with donor masks |

Dogborg source suffixes expose authored size variants independently of the shared continuous layout scale. Asset metadata supplies matching size icons and only the color channels present in the chosen variant. The massive sheet is an explicit choice. These assets do not modify the human accessory registry. Meridian's non-rendering human anus entry is omitted from this visual catalog.

## Core integration inventory

Module ID: `CYBORG_CUSTOMIZATION`. Core preference hooks are narrow lifecycle adapters; session policy remains in the cyborg middleware.

| Core touchpoint | Reason |
| --- | --- |
| `code/__DEFINES/preferences.dm`, `code/datums/json_savefile.dm` | Explicit failed/written/session-only outcomes and complete-write readback |
| `code/modules/client/preferences/middleware/_middleware.dm` | Staging, write acknowledgement, slot veto and replacement hooks |
| `code/modules/client/preferences_savefile.dm` | Stage before saving/exporting; veto failed slot transitions before initialization |
| `code/modules/client/preferences.dm` | Native close/destroy save boundary and visible slot-transition failure |
| `modular_nova/modules/preferences_import/code/import_verb.dm` | Invalidate the replaced character's draft during import |

Revert the targeted frontend/backend protocol together, the middleware lifecycle with its callers, and the generated manifest with its reader. Player layout schema remains version 1, so rollback requires no save reset. Shared controls with the separate custom-sprite editor are deferred until both real consumers can be integrated.

## Verification

Use [VERIFICATION.md](VERIFICATION.md) for the current evidence checklist. Asset generation, focused tests, TGUI/build checks, native compilation, two-client visual acceptance, hosted CI, and matched performance evidence are distinct. A passing asset builder or UI test does not establish native visual acceptance or release readiness. Cache limits and estimated byte budgets are bounds, not measured performance claims.
