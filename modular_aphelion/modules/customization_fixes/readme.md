# Customization CI repairs

Module ID: CUSTOMIZATION_CI_FIXES

Repairs the primitive-kobold accessory and sparse matrixed-emissive failures observed in PR 138. Primitive kobolds share the existing reptilian snout set. Missing color channels retain their indexing but do not generate emissive masks. Existing sprites, colors and species names are unchanged.

## Inherited edits

- `modular_nova/modules/customization/modules/mob/dead/new_player/sprite_accessories/snout.dm`: admit the primitive-kobold species ID.
- `modular_nova/master_files/code/datums/bodypart_overlays/mutant_bodypart_overlay.dm`: skip absent matrixed sprite channels in `add_emissives`.

These narrow marked edits avoid copying the inherited accessory list or overlay procedure. Remove them when the corresponding Nova implementation includes the same fixes. No artwork is added or modified.

## Verification

`code/regressions.dm` is enabled only for `UNIT_TESTS`. It covers randomized primitive-kobold parts and the existing dual-color angler horn's sparse front layer.
