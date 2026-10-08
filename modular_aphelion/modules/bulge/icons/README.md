# Bulge template sheets

`templates/` holds the shapes a bulge is drawn from up to each family's `small_cap`, the skirts' clearances and flaps,
and the large heart boxers: 5 sheets, 656 states, each with four directions (north is empty) and one frame. Open them
in Dream Maker's icon editor. A state is named for what it is, and the code finds it by that name; nothing maps one
name to another.

Past `small_cap` nothing is read from a sheet. The shapes, the anatomy each leaves bare, and a hard loincloth's drape
and cut are derived at run time from the game's own penis, testicle and loincloth sprites by the approved rule
(`code/templates.dm`), under the names below, once each and kept for the round. They were drawn in sheets once
(1,576 states), and the unit test `bulge_derivation` holds what is derived to a frozen record of those states.

## What the sheets hold

| sheet | states | holds |
|---|---:|---|
| `cloth_small` | 162 | sizes 1 to 4 of every garment family, and jeans hard at size 5 |
| `skirt_shapes` | 186 | every skirt style, and each revealing skirt's own hem where it differs |
| `skirt_clearance` | 42 | where a skirt's shaft shows above the cloth; an empty state draws the anatomy behind the skirt only |
| `skirt_flaps` | 54 | the flap a revealing skirt lifts away when hard |
| `printed_patches` | 214 | the large heart boxers, sizes 5 to 8 (198 for the profiles of the other penis shapes), made by the print rule and approved by mal |

A shape is a kind map: each kind of pushed-out cloth in its own grey, the approved shading over mid-grey cloth, so a
sheet shows the bulges as they look on grey cloth. Cloth `#808080`, light `#a3a3a3`, highlight `#b7b7b7`, shade
`#646464`, deep shade `#4b4b4b`. Draw with exactly these five; nothing else is read. Masks are opaque white.

## Names

- Shapes up to a family's `small_cap`: `<shapes>_<half|hard>_<size>_<plain|digi>`, for example
  `briefs_hard_3_digi`.
- Past it, derived: `<shapes>_<half|hard>_<size>_<plain|digi>_<penis shape>`, with `_untoned` for a penis shape whose
  untoned sprites have shapes of their own (Human (Alt), Hemi), for example `boxers_hard_6_plain_knotted_alt`.
  Digitigrade versions exist only where the family says so (`large_digi_forms`); a penis whose sprite stops growing
  keeps size 6's shape at 7 and 8. The anatomy a shape leaves bare is derived with it, under the same name; a shape
  that covers the whole penis leaves none.
- A skirt's clearance: its shape's name without the legs, `<shapes>_<half|hard>_<size>`, as a clearance is the same on
  plain and digitigrade legs. Its flap has its hard shape's name.
- Drapes, derived: `<drapes>_<penis shape>_<sprite size>`, with `_untoned`, and `_flat` from the family's
  `flat_tip_from`. Cuts, derived: `<drapes>_cut_<hem>`, the hem being the lowest row the drape reaches facing south
  (the family's `lifted_hem` for a drape that stays above the hem rows).
- The large heart boxers' patches: `<printed_patches>_<half|hard>_<size>_<plain|digi>` for the human penis, drawn by
  every penis shape without a patch of its own; a shape's own patch is named the same with the penis shape's icon state
  appended, for example `heart_boxers_hard_7_plain_knotted`, and `_untoned` after that for a shape drawn without skin
  tones whose untoned sprites draw differently (`bulge_untoned`), where its untoned profile needs a patch of its own:
  Human (Alt) half and hard 6 to 8, for example `heart_boxers_hard_7_plain_human_alt_untoned`; untoned at 5 it draws
  its skin-toned patch. Every other penis shape has its own (198 states) where its profile facing east and west needs
  one: drawn there along the anatomy the shape leaves bare, north and south copied from the human patch. Where the
  penis reaches below the hem (the shaft's underside, hard 6 to 8, in the knotted, barbknot, flared, hemiknot and
  tapered profiles), the cloth covers it too, as the boxers' leg hangs over it, and at hard 5 the cloth ends at the
  shaft's lower outline, with no curtain below it (mal, 2026-10-06); knotted hard 6 has its own patch for that row
  (mal, 2026-10-08). The tentacles, and Nondescript (Alt), Tapered (Alt) and Hemi (Alt), whose `print_cap` is 4
  (`code/templates.dm`; mal, 2026-10-06), have none: in every family they draw the family's small_cap shape past it,
  and under the heart boxers its print, at every size. Each frame is 32x10, the tile's whole width from row 20 to row
  29 counted from the top (the patches reach row 28).

`<shapes>` and `<drapes>` are the family's vars in `code/families.dm`. A family that draws another family's shapes
by design names it there (`half_shapes_of`, `hard_shapes_of`, `large_shapes_of`); a garment whose approved look
differs from its family's has a subtype of the family, as the revealing skirts' hems do, whose `own_shape_sizes`,
`own_clearance_sizes` and `own_flap_sizes` say at which hard sizes it has its own. Where two families' shapes
merely happen to look the same, both are stored.

Each sheet is cropped to one window; the pixel offsets that place it on the 32x32 tile are defined in
`code/templates.dm` next to the accessors. Keep a sheet's frame size, or change its offsets with it.

## Revealing skirts

The common revealing skirt, `/datum/bulge_family/skirt/short_reveal` (92 skirts), is hemmed at row 25 of the 32x32
tile facing south, counting rows from 0 at the top. `hem_24` (40 skirts) and `hem_23` (14) are hemmed one and two rows
higher; the miniskirts, the lone skirts and eleven single garments have subtypes of their own, because their hems
differ at some sizes (`code/families.dm` says which). Which class fits cannot be read off a sprite by any simple rule, so place a new
revealing skirt by eye:

1. Preview the common class over the garment's worn sprite at each hard size, on plain and digitigrade legs:
   `python tools/bulge_assets.py preview short_reveal_hard_3_plain --output preview-output --garment FILE:STATE`.
   `_cut.png` shows the garment with its flap cut away and its print carried onto the bulge; `_clearance.png` shows
   in magenta where the shaft shows over the cloth. A GAGS garment has no worn file: preview its greyscale state in
   its config's sheet.
2. Where the flap cuts above or below the garment's lifted hem, try `short_reveal_hem_24_*` and
   `short_reveal_hem_23_*`, then the single garments' classes.
3. Give the garment a block in `code/garment_families.dm`: `bulge_family` the class that fits, and
   `bulge_printed = TRUE`, as every reviewed skirt is printed from its own sprite.
4. If no class fits, the skirt needs a family subtype with its own shapes, clearance and flaps where they differ, which
   is new art for mal to review.

## Tools

From the repository root (`python -m pip install -r tools/bulge_assets_requirements.txt` once):

```powershell
python tools/bulge_assets.py verify
python tools/bulge_assets.py fix
python tools/bulge_assets.py find hem_24
python tools/bulge_assets.py find boxers_hard_6_plain
python tools/bulge_assets.py preview briefs_hard_3_digi --output preview-output
python tools/bulge_assets.py preview short_reveal_hem_24_hard_1_plain --output preview-output --garment icons/mob/clothing/under/color.dmi:jumpskirt
```

`verify` checks every sheet (an 8-bit palette PNG, four directions and one frame, only the kind greys or white, names
that follow the convention, the window inside the tile), that every identity the families declare finds its state in a
sheet or, past `small_cap`, a name to be derived under that follows the convention, and that no sheet state is left
that nothing reaches; it prints each sheet's state count and how many templates are derived. The unit test
`bulge_template_identities` resolves the same identities through the game's own accessors, and `bulge_derivation`
checks what is derived. `find` lists sheet states, derived templates (marked "derived at run time"), families and
garments. `preview` writes a sheet state's directions scaled up, a kind map also with its kinds in colours, and with
`--garment` laid over that worn sprite with the approved print rule, as the server derives a printed patch, and for a
revealing skirt also cut by its flap and with its clearance. A skirt's shape and its flap share a name, and its
clearance drops the legs from it: write `skirt_flaps:<name>` for another sheet than the kind map. A derived template
has no sheet state: `preview` says so, and the pixel corpus shows what the server draws.

A changed sheet also changes its MD5 in the reviewed manifest the `bulge_manifest` unit test checks: once the change
is reviewed, copy the `data/bulge_manifest.txt` the failing test writes over
`code/modules/unit_tests/~nova/bulge_manifest.txt`.

Save sheets from Dream Maker, then run `verify`, and `fix` where it says so. Dream Maker re-saves a sheet of few
colours as a 1-bit or 4-bit palette PNG, which rust-g's DMI reader, behind tg's `icon_exists()`, cannot read: `verify`
reports every sheet that is not an 8-bit palette PNG, and `fix` re-encodes those as 8-bit palette PNGs with the same
pixels and DMI metadata, and prints the proof (both files decode to the same RGBA pixels and the same metadata text).
It leaves an 8-bit palette sheet as it is. A re-encoded sheet has a new MD5 for the manifest, as above. Do not run
ZopfliPNG or other PNG optimisers over the sheets: rust-g's DMI reader failed on their output too (PNGs of fewer than
eight bits per sample, Zopfli streams).
