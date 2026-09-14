# Cyborg customization

Adds a Cyborg page to character setup, shared usage controls in RoboTact and the interaction panel, and a visual appearance layer for player cyborgs. Character slots remain the unit of identity. Each slot stores up to ten appearance presets (selected sprites, placement, colors, and overrides) and defaults keyed by model type plus skin label. Preview selections never select a playable model or grant equipment, access or laws.

## Implementation boundaries

| Boundary | Entry point |
| --- | --- |
| Schema and import | `code/layout_schema.dm`; native preference import sanitation |
| Slot-bound drafts | `code/preferences.dm`; core preference save/load/close/destroy hooks |
| Eligible models | `code/model_catalog.dm`; robot model picker and recorded skin identity; cached declarations copied from transient null-location model items |
| Creator | `code/middleware.dm`, `code/preview.dm`; `CyborgCharacterPage.tsx` |
| Live appearance | `code/appearance.dm`; robot Login and Nova icon refresh |
| Shared geometry | `code/rendering.dm`; six visual slots with sparse pose/direction/arousal overrides |
| Art | `code/accessories.dm`, `code/direct_accessories.dm`; separate cyborg-only catalog |
| Animation | `code/animation.dm`, `animation_manifest.json`, generated occlusion resource table |
| Identity | `code/identity.dm`; examine panel, robot examine and character directory |
| Runtime controls | `code/robotact.dm`; mounted RoboTact and interaction self tabs |
| Interactions | `code/interactions.dm`; audited message-only human/cyborg adapter |

## Persistence and policy

`silicon_genital_layout_presets` is schema version 1: `active`, `presets`, and `model_defaults`. Known fields are normalized through bounded paths; unknown branches are ignored. Future-version imported data remains preserved and the editor refuses writes. Donor key aliases migrate only during import. Existing `silicon_headshot` remains canonical; the optional second portrait uses `silicon_headshot_nsfw` and existing portrait validation.

The draft timer is bound to both character slot and revision. Ordinary edits debounce for two seconds. Explicit preset/default collection changes save immediately. Slot changes, close, export and preferences destruction flush through native JSON saving; delete/import replacement discard the replaced draft. Preset names are trimmed to 24 characters, overflow is refused, and overwrite is explicit.

Configured visual parts start active on a new body. Owner master/character consent and the server ERP switch gate it. Viewers independently opt in through `see_cyborg_genitalia`, default off. The body captures appearance and size once at spawn; creator edits and reconnecting do not replace that configuration. Reconnecting preserves temporary activation and the body's profile binding. Runtime actions change visibility and arousal only; saved configuration remains in Setup Character.

Newly saved presets/defaults snapshot each part's `sprite`. Older layout-only entries retain their geometry and fall back to current character sprite preferences. Re-save them after selecting the desired parts to capture complete model setups. Loading a saved preset/default also restores the creator's sprite selectors.

Requested base sizes are 0.75, 1, 1.6, 2 and 2.5. Small chassis cannot shrink below 1; wide/tall chassis cap the base at 1.6; unsupported special chassis use 1. Existing hardware remains a separate transform factor. Preview zoom is independent.

The appearance catalog includes authored Syndicate and Ninja families separately from normal playable model eligibility. Preview 1:1 preserves body size at 100% world zoom, with a fixed 32-pixel mannequin reference. Fit recalculates bounds explicitly; ordinary part edits and rotation preserve framing. Center changes the camera position only.

Wide models use independent North, South, and East/West placement groups for position and rotation. Unedited groups inherit legacy base values; ordinary sliders, dragging, and nudges edit only the current group. Scale remains shared. Side X and rotation mirror in west-facing views (`mirror_sides`); authored animation anchors and view-specific offsets stay literal. Per-part `reuse_south` optionally supplies south-facing art to the north view while retaining north placement and layer settings. These additive schema fields persist with layouts and can be disabled independently. Layer order compares parts against one another, underneath authored body masks; selecting a part does not raise its render layer.

Visual slots do not create physical organs. Supported message interactions are Cheer for cyborg actors and Cheer/Beckon/Headpat/Pat for humans targeting cyborgs, subject to each audited contract and distance. Human-hand requirements still require a hand. Surgery, insertion, vore and anatomy-dependent sexual effects are not granted by visual configuration.

## Assets and provenance

Donor: [SPLURT PR 960](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960), pinned to [`090a9cb13722af449567867c720826eb6af215a5`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/090a9cb13722af449567867c720826eb6af215a5). It was open and unmerged when implementation began. Source adaptation follows the repository's AGPL-3.0 license; copied art is from the donor's CC-BY-SA-3.0 asset collection. Retain donor attribution and these source paths when redistributing or modifying the art.

| Local directory | Donor directory | Treatment |
| --- | --- | --- |
| `icons/animation_markers` | `modular_zzplurt/icons/mob/cyborg_animation_markers` | Exact selected family sheets |
| `icons/occlusion_masks` | `modular_zzplurt/icons/mob/cyborg_occlusion_sources` | Exact selected family masks |
| `icons/accessories` | `modular_zzplurt/icons/mob/sprite_accessories/genitals` | Exact penis/testicles/massive dogborg sheets |
| `icons/accessories/anus.dmi` | `modular_zzplurt/icons/mob/human/genitals/anus.dmi` | Exact sheet, cyborg-only Donut/Squished choices |
| `icons/occlusion_generated` | Derived locally | Meridian body colors combined with donor masks offline |

Dogborg source suffixes expose their authored size variants independently of the shared 25–200% continuous layout scale. Metadata supplies matching size icons and only the color channels present in the chosen variant. The massive sheet is an explicit choice. These assets do not modify the human accessory registry. All six slots have rendering choices; Meridian's non-rendering human anus entry is omitted from this visual catalog.

## Authored mapping and fallback

The offline builder accepts only explicitly named local families with matching dimensions, directions, frame counts and delays. It requires exactly one cyan marker in each frame. `animation_manifest.json` is the detailed model/state/direction matrix; it records every accepted mapping and rejected pose or movement mapping.

| Local skin labels | Donor family |
| --- | --- |
| Drake | drake |
| Borgi | borgi |
| Otie | otie |
| Vale, ValeDark | vale |
| Hound, Darkhound | hound |
| Alina | alina |

Current generation yields 36 distinct icon/state mappings, seven generated sheets and 27 recorded fallback cases. These are metadata compatibility results, **not visual acceptance**. Other catalog skins use manual placement. Unsupported or ambiguous pose/movement sequences do not borrow a different family's animation.

Preview and live appearance share geometry and authored anchors. Catalog construction uses one transient null-location model item per allowed department, then deletes it; BYOND `initial()` does not return list-valued instance initializers. The audited null-host path creates no tools, storage or robot registrations; medical/miner overrides only append type paths before the guard. Cached descriptors hold copied lists and resources, never those items. The creator animates a bounded sequence of up to 32 frames locally; fallback previews remain static. The live holder follows its owner, maintains viewers through login/logout/preference events, and uses client-side pixel animation. Ordinary movement does not normalize saves, scan marker pixels, write temporary DMI files or scan the player list.

Caches are bounded: 512 body/occlusion preview frames with a 4 MiB encoded-data eviction budget; 128 standard accessory composites with a 2 MiB estimated byte budget; 32 direct-accessory frames. Closed galleries omit thumbnails; open galleries supply four directions for the selected department only. Creator size thumbnails are generated only for the selected part. The estimates exclude BYOND allocator overhead. They are bounds, not measured performance claims.

Regenerate with Python and Pillow from the repository root:

```text
python tools/cyborg_customization/build_assets.py
python -m unittest discover -s tools/cyborg_customization -p "test_*.py"
```

The script has no network access and processes checked-in inputs. Commit generated resources with their source changes. Runtime does not require Pillow.

## Qualification

See [implementation status and verification](../../../docs/superpowers/plans/2026-09-09-splurt-cyborg-customization-status.md). Compilation, DM tests, two-client visual acceptance and matched performance runs are distinct gates. Do not infer release readiness from a successful asset build or TGUI test run.

The [two-client playtest checklist](../../../docs/superpowers/plans/2026-09-10-cyborg-customizer-playtest.md) covers the wider acceptance matrix. The [latest playtest fixes and branch audit](../../../docs/superpowers/plans/2026-09-13-cyborg-playtest-audit.md) records current checks and the next focused playtest. Automated creator coverage includes immediate export, repeated open/edit/close, future-schema preservation, native preview/static-fallback PNGs, UI direction/pose targeting, numeric size selection, mirrored placement, sprite reuse, camera stability, and input pacing.

The [runtime, placement, and profile audit](../../../docs/superpowers/plans/2026-09-13-cyborg-runtime-and-profile.md) covers the latest donor research, fixes, validation, and migration playtest.

Named presets now record their chassis. Load restores that preview model; Use on spawn assigns the saved preset to its model, and Update preset refreshes the assignment. Old unbound presets and anonymous defaults remain loadable. See the [rendering and saved setups audit](../../../docs/superpowers/plans/2026-09-13-cyborg-rendering-and-saved-setups.md).

The [inspect and occlusion follow-up](../../../docs/superpowers/plans/2026-09-13-cyborg-inspect-and-occlusion.md) covers explicit live image ordering, fitted inspect portraits, and independent SFW/NSFW OOC notes with human-field fallbacks.

The [pose placement follow-up](../../../docs/superpowers/plans/2026-09-14-cyborg-pose-placement.md) documents shared editing targets, isolated Standing overrides, paused manual placement, and saved-data compatibility.

The [map scale and screen placement follow-up](../../../docs/superpowers/plans/2026-09-14-cyborg-map-scale-and-screen-placement.md) covers matching 1:1 to DreamSeeker map zoom, screen-space live offsets, and the remaining native visual comparison.
