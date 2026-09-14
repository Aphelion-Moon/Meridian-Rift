# Cyborg live rendering and saved setup workflow

## Findings and research

The live holder copied `owner.transform` into two images already attached to that owner. It also copied the chassis X/Z offsets into the colored body mask. BYOND images inherit the attached atom's transform and displacements: repeating them moves/scales the mask away from the actual body. Its opaque regions then appear as duplicated body fragments. Part images also used a different canvas origin from the preview. The preview centers each part image, while the old live overlay used the image's bottom-left corner. [BYOND image, appearance flags, and pixel displacement reference](https://www.byond.com/docs/ref/info.html)

The renderer now lets the owner supply the transform and offsets once. A part's native offset is `x + (body_width - part_width) / 2`, `y + 16 - part_height / 2`, matching the preview's horizontal body center and vertical tile center. Animation deltas remain in local pixels and inherit body scaling once. The body mask remains attached to its owner at zero additional offset. No artwork or saved placement values are rewritten.

The setup confusion came from independent anonymous default copies, named layout presets with no chassis identity, and a single working appearance shown against arbitrary preview models. Saving a default did not establish a visible named relationship. The UI could not explain which preset would load on spawn because that relationship did not exist.

Lightroom separates applying a named preset from updating it with current settings, and offers organized user presets with identifiable previews. Blender's Asset Browser organizes named assets into catalogs, with preview and detail areas. The useful adaptation here is visible identity and explicit operations, rather than another collection of unlabeled save/load buttons. [Adobe preset workflow](https://helpx.adobe.com/lightroom/desktop/edit-photos/presets.html), [Blender Asset Browser](https://docs.blender.org/manual/en/4.4/editors/asset_browser.html)

Three approaches were considered: keep independent defaults and add labels (still creates diverging copies); replace everything with automatic per-model drafts (obscures reusable saved versions); or keep named setups with explicit spawn assignments. The third fits the existing creator and makes the relationship inspectable.

## Implemented design

1. **Working setup** is the automatically saved editing draft. It records the preview chassis across reopening. Editing it does not silently update a named preset.
2. **Saved presets** contain a chassis identity and appearance: selected parts, size variants, placement, colors, and overrides. Body size remains the character-wide size preference. Load restores both the appearance and preview chassis. Update preset explicitly replaces the saved version.
3. **Spawn appearance** displays the current chassis and `On spawn: <preset name>`. Use on spawn assigns the selected saved preset to that chassis. Updating an assigned preset also updates its future spawn snapshot. Clearing the assignment leaves the preset available.
4. **Legacy data** remains usable. Old presets without a model are labeled unbound; saving them again records the current model. Old anonymous defaults appear as Legacy saved appearance and can be loaded, saved as a named preset, and assigned. Deleting a named preset retains its last model-default snapshot with the legacy label, avoiding an unexpected loss of the spawn appearance.
5. **Runtime separation** freezes the appearance store, selected sprites, and requested size when the body first receives its profile. Setup edits and reconnecting do not alter that body's configuration. Actual chassis changes use the body's captured model defaults; viewer and content permissions still refresh immediately.

The gallery has one Syndicate family instead of Syndicate plus Marauder, and one Ninja family instead of Ninja/Medical/Saboteur. Their in-round roles remain distinct. Appearance IDs canonicalize the shared families; existing variant defaults migrate to the shared identity. An already saved canonical-family default takes precedence if both it and an old duplicate-family default exist.

Appearance/Profile share the same grid tracks and gap. Headshot section titles explain direct HTTPS JPEG/PNG links and the existing validator's Gyazo, Lensdump, Imgbox, and BYOND hosts. Preset action groups use equal-width two-column buttons.

## Verification

- Before fixes, the focused native run reproduced creator size mutation and missing preset-to-chassis binding. The new frontend assignment test also failed before implementation and passed afterward.
- Production `BUILD.cmd`: 0 DM errors and warnings; Rspack succeeded. The final stylesheet rebuild also passed.
- Full frontend suite: 56 passed, 0 failed, 131 expectations. TypeScript, scoped Biome (18 files), SCSS formatting, and `git diff --check` passed.
- All 27 focused native cases passed, including four-direction centered placement with a 1.6x hardware transform, no repeated mask offsets/transform, frozen body settings across reconnect, named model/preset binding and overwrite/delete behavior, and shared-family default migration. Native test compilation had zero errors and the two expected test-mode warnings.
- DreamDaemon shut down naturally, produced 27 successful JSON results and `clean_run.lk` containing `Success!`, and left no owned process alive. No runtime-error, exception, or failing-test markers appeared. Its Windows launcher exit was 20320; the result artifacts and shutdown log establish native completion. Focused build files were removed, and the pre-existing result JSON was restored with its SHA-256 verified.
- Browser fixture showed matching 342.5px sidebars at the 1200 by 940 target, both headshot help texts, aligned preset action grids, and successful restoration of a preset's model and Y placement after switching models. No browser warnings/errors were captured. Temporary browser and fixture server were closed.

## Next playtest

Restart the local server with the rebuilt artifacts and use a newly spawned body. Reopen Setup Character to load the new TGUI bundle.

- Use the same wide chassis and saved offsets from the four reported screenshots. Check all cardinal directions at normal size and a larger body size. Compare against the creator. Check standing/resting/sitting and movement for mask alignment and part offsets. Automated appearance assertions cannot establish the final DreamSeeker raster result.
- Save a named preset for a chassis and choose Use on spawn. Confirm the displayed name. Switch the preview chassis, then Load preset; both chassis and appearance should return. Update the assigned preset and verify the next matching body uses it.
- Load an old anonymous model default, save it under a name, and assign it. Legacy presets with no recorded model must be saved again to establish that association.
- Change character body size and part selections while already playing. The current body should remain unchanged, including after reconnecting. A new body should receive the updated configuration.
- Check the consolidated gallery, sidebar width when switching pages, and headshot help. Confirm runtime hide/show controls still work independently of each viewer's display preference.

No commit or push was made. Full native-suite qualification, multiplayer acceptance, and live DreamSeeker rendering acceptance remain separate gates.
