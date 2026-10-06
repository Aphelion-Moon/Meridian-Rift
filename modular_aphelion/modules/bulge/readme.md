## Bulge

Module ID: BULGE

### Description:

A penis that is covered and at least half hard shows through what covers it: half hard a soft bulge, fully hard a
tent. The size follows the penis's length: sizes 1 to 4 under 5, 8 and 11 inches and from 11 up, and for the garments
that go further, sizes 5 to 8 from 37, 49, 57 and 65 inches, where the penis starts to show past the cloth. Every
look was drawn and approved in the preview pipeline first; the game draws it by the approved rules. A print is
derived from the sprite the game actually draws, so a recoloured or species-fitted garment carries its own print
(mal's decision D1), and a tentacle penis past size 4 draws the size-4 bulge (mal, 2026-10-03). The pixel corpus
(Checks, below) holds the game to those rules case by case.

Each garment names a family (`code/garment_families.dm`): boxers, loose boxers, briefs, jockstrap, jeans, long johns,
jumpsuits, khaki shorts, athletic shorts, track pants, two loincloths, and six skirt styles. A suit over the groin
hides the bulge unless it was reviewed to leave the groin clear (`bulge_suit_rule`). A chastity device, a sheath
(until fully hard), a husk, a taur body, "Never show" and "Above all clothing" draw none.

A garment covers the penis only when it is drawn in front of it. With Custom "Above underwear" the penis is drawn over
the underwear and undershirt as Nova draws it: no bulge on them and nothing cut, until the player layers it back
("Below underwear" or "Hidden by clothes"). A uniform or a suit over it still carries the bulge (mal, 2026-10-04).

Bulge interactions ask `has_bulge()` (Nova's `lewd_helpers/human.dm`), which is true exactly while a bulge look is
drawn: not under a suit that hides it, on a garment that draws none, on underwear the body does not draw, or with the
penis layered above its only cover. Whatever starts or ends a look (arousal, clothing, a device, layering, organs)
ends in the body update that resolves it, so the answer is current from that update on. `bulge_cover_name()` names
the garment the look is drawn on.

Layered above the underwear, the penis is exposed instead (mal, 2026-10-04): Nova's `covered_by_clothing()`
(`lewd_organs/_genital.dm`) does not count the undershirt, underwear or bra over a genital set to Custom "Above
underwear", which is drawn over them, so `is_exposed()` offers it to the plain interactions (and to portals, examine and
a breast bounce) while only underclothes are worn. A uniform or a suit over it still covers it. With only underclothes
on, such a penis has no bulge interaction and the plain penis interactions instead; every other layering is as before.

### How it draws

One renderer, on the penis's own bodypart overlay: a body update asks the overlay whether it draws, and a covered
penis resolves its look, keeps it, and resolves it again only when something it was resolved from has changed. The
look's key stands in for the penis's own render key, so the chest's limb icon cache holds a bulge like any limb image.

- **Plain garments:** the shape's kinds of cloth (cloth, light, highlight, shade, deep shade) as white masks, tinted
  on the client with the adaptive palette of the garment's cloth colour. The masks are derived once per shape; the
  colour is sampled once per sprite and tint, its palette computed once per colour. A garment drawn through a colour
  matrix or filter carries no print: its cloth is sampled from the untreated sprite and drawn through the same filter.
- **Printed garments** (mal's printed selections and every reviewed skirt): one patch derived on the server from the
  sprite the garment is drawn with, by the approved print rule, so it follows recolours, species fits and digitigrade
  sprites.
- **Revealing skirts and loincloths, when hard:** the cover is drawn with its lifted flap cut away (the uniform and
  underwear renders call `bulge_cut_worn()`), and the penis shows through it: under a loincloth's drape, or behind
  the skirt and over its cloth inside the skirt's clearance.
- **Sizes 5 to 8:** the penis shows over the cloth inside the shape's exposed mask. The large heart boxers draw their
  patch in place of the boxers' shape, over the same bare part of the penis: the patch drawn for that penis shape's
  profile where the sheet has one (and for its untoned sprites, where they differ), else the human penis's. The
  tentacles, and Nondescript (Alt), Tapered (Alt) and Hemi (Alt) past their `print_cap` (4), draw the size 4 shape
  and its print under them instead (mal, 2026-10-06).
- **Templates:** the shapes up to a family's small_cap, the skirts' clearances and flaps, and the large heart boxers'
  patches are read from the template sheets. Past small_cap the shapes, the anatomy each leaves bare, and a hard
  loincloth's drape and cut have no sheet: they are derived on the server from the game's own penis, testicle and
  loincloth sprites by the approved rule (`code/templates.dm`), each once, when a look first asks for it, and kept for
  the round. Nothing is derived at init.
- **Blood and dirt on the cover** draw over the cloth too, kept to its pixels. On a cover drawn cut they are cut with
  it, and the cloth carries them uncut.

### Files

- `code/bulge.dm`: the penis overlay's virtuals, the look's vars, the size rules, the images a look draws.
- `code/look.dm`: resolving a look: the cover, the suit's verdict, the cloth colour, printed or adaptive.
- `code/cut_cover.dm`: drawing a revealing cover cut. `code/redraw.dm`: redrawing on an erection or a new length.
- `code/print_derivation.dm`: the icons derived on the server: printed patches, kind masks, anatomy kept to a mask,
  cut covers, a cover's blood kept to the cloth.
- `code/templates.dm`: the template sheets, the derivation of everything past small_cap, and the accessors that find a
  shape, mask, flap, drape or cut by identity.
- `code/families.dm`: the families' data. `code/garment_families.dm`: each garment's family, print, suit rule and
  cloth layer.
- `code/colour_cache.dm`, `code/adaptive_colour.dm`: the cloth colour sampler and the adaptive palette.
- `code/interaction_text.dm`: the armpit interactions' pit-hair texts.
- `icons/templates/`: 5 sheets, 460 states: the shapes up to small_cap, the skirts' clearances and flaps and the large
  heart boxers, described in `icons/README.md`. `tools/bulge_assets.py` checks, re-encodes and previews them and
  names what is derived.
- Outside the module: `code/__DEFINES/~aphelion_defines/bulge.dm`; two calls to `bulge_cut_worn()` in
  `human_update_icons.dm`; the texture skip for the bulge's cloth in `_bodyparts.dm`; `bulge_cached_output_matches()`
  in `greyscale.dm`; `has_bulge()` and `bulge_cover_name()`, which bulge interactions ask, in Nova's
  `lewd_helpers/human.dm`; the uniform and suit redrawn after a leg swap, in `try_attach_limb()` (`dismemberment.dm`)
  and Nova's legs preference (`digitigrade_legs.dm`), without which they stay drawn for the old legs
  (`bulge_renderer/leg_swap`); a dyed mutant part drawn in its dye and keyed by it, in Nova's
  `mutant_bodypart_overlay.dm` and in pod hair's colouring (`pod.dm`); the Nude bra building no appearance (Nova's
  `bras.dm`) and the bra block adding only a built bra (`human_update_icons.dm`, inside Nova's markers);
  underclothes not covering a genital layered above them, in Nova's `covered_by_clothing()` (`_genital.dm`); and the
  bulge interaction requirements, `INTERACTION_REQUIRE_SELF_BULGE` and `INTERACTION_REQUIRE_TARGET_BULGE` in Nova's
  `~nova_defines/interactions.dm`, checked in Nova's `interaction_datum.dm`, which also fills in the
  `%[role]_BULGE_COVER%` token.

### Adding a garment

Give its type a block in `code/garment_families.dm` naming its family, and only what it needs beyond that:
`bulge_printed = TRUE` when its own print should carry onto the bulge, `bulge_cloth_layer` when its cloth is not its
first GAGS layer, `bulge_suit_rule` for a suit that leaves the groin clear. Subtypes inherit their parent's bulge, so
a new subtype of a listed garment either keeps it or gets a block of its own. A revealing skirt's hem class is chosen
with the tool's preview (`icons/README.md`). Then update the reviewed manifest (below).

Mind the type order: `garment_families.dm` lives in modular_aphelion, which compiles before modular_nova, so its
blocks declare Nova's garment types before Nova does and move them earlier in BYOND's type order (`typesof()` lists
them earlier, and create_and_destroy creates them earlier). The four map preview sheets that `ExportMapPreviews()`
writes in that order (`icons/map_icons/clothing/suit/_suit.dmi`, `under/_under.dmi`, `under/costume.dmi` and
`under/dress.dmi`) are committed as this tree generates them: their pixels equal upstream's, only the order of their
states differs. A new block for a garment with a map preview can reorder them again; a unit test run then reports
"Generated map icons were different than what is currently saved" and rewrites them: commit the rewritten sheets.
Upstream changes to these sheets will conflict with ours; take upstream's change, then regenerate.

### Adding or editing a shape

Up to a family's small_cap, draw it in its sheet under the name the accessors compute (`icons/README.md`), in the
five kind greys, and run `python tools/bulge_assets.py verify`, then `python tools/bulge_assets.py fix` if it reports a
sheet that is not an 8-bit palette PNG: Dream Maker re-saves sheets as 1-bit or 4-bit palette PNGs, which rust-g cannot
read. A garment look that no family's shapes give is a new family subtype in `code/families.dm`.

Past small_cap nothing is drawn: a family's shapes there follow from its vars (`top_row`, `hem`, `contained`,
`curtain`, `long`, `large_digi_forms`) and the penis sprites, and its loincloth drapes and cuts from its loincloth vars
and its own sprite. A change to those vars changes bulges on screen: `bulge_derivation` then fails against its frozen
record, and the full corpus shows what changed. Once mal has approved it, record the new value the test prints in
`BULGE_DERIVATION_RECORD` (`code/modules/unit_tests/~nova/bulge_templates.dm`).

### Adding a penis shape

A new penis shape (a `/datum/sprite_accessory/genital/penis` subtype) needs no bulge art. Past a family's small_cap
its bulges, the anatomy they leave bare and the loincloths' drapes are derived from its own sprites, so it needs:

- its sprites in its sprite accessory's icon: `m_penis_<icon_state>_<size>_<0|1>_FRONT_UNDER`, with `_s` before
  `_FRONT` for the skin-toned ones where it has skin tones (`has_skintone_shading`), and `_primary` at the end for a
  shape coloured by a matrix (`USE_MATRIXED_COLORS`), drawn inside the window a derivation reads of them
  (`BULGE_SPRITE_*` in `code/templates.dm`; `bulge_derivation/pin` fails a sprite that draws outside it);
- its caps: `max_sprite_size_affix`, and `skintone_max_sprite_size_affix` where its skin-toned sprites stop sooner;
- in `code/templates.dm`, `bulge_untoned = TRUE` when its untoned sprites draw differently, or `bulge_hyper = FALSE`,
  as the tentacles have, when it should draw the small_cap shape past small_cap and show no anatomy; and `print_cap`
  below 8 when past it the large heart boxers should draw it so too (their size 4 shape and its print).

Under the large heart boxers it draws the human penis's patch, unless `printed_patches.dmi` has patches named for its
icon state (and `_untoned` ones where its untoned sprites draw differently), hand-drawn for its profile
(`icons/README.md`).

The merge that adds it fails `bulge_derivation/pin`, `bulge_derivation` and `bulge_template_identities`, whose frozen
records count every penis shape. Review its bulges with the full corpus; once mal has approved them, record the new
values the tests print in `BULGE_DERIVATION_INPUTS`, `BULGE_DERIVATION_RECORD` and `BULGE_IDENTITIES_RECORD` in
`code/modules/unit_tests/~nova/bulge_templates.dm`.

### When the compiler fails in a file you did not touch

DM 516.1687 miscompiles depending on how many distinct variable names the whole tree declares (vars, proc locals and
arguments), `var/static` locals included (the compiler makes each one a global variable). One name more can make an
untouched file fail ("undefined var", "invalid variable"), warn falsely (an "unused_var" warning on a variable that is
used), or compile code that fails at run time: here one added name, and later one added `var/static` local, made
`_species.dm` warn that `basic_holder` was unused and fail at initialisation on `spoken_languages`. The effect does not
grow with the count; a count that builds cleanly can stop one name later and build again two names later.

So: reuse a name the tree already declares for any new variable (a local named like others elsewhere costs nothing),
add no `var/static` local you can do without, and read a build's whole warning list, not its count. When a build breaks
or warns somewhere you did not touch, look at the names your change added before suspecting the code: the lab's
`N5-closing/scripts/count_identifiers.py` lists them against another tree, and `frag_probe.py` builds a copy to check.

### Checks

- `python tools/bulge_assets.py verify`: every sheet (it prints each one's state count), name and identity, the names
  past small_cap that are derived, and that every sheet is an 8-bit palette PNG (only the tool checks that). Dream Maker
  re-saves sheets as 1-bit or 4-bit palette PNGs, which rust-g cannot read: then run `python tools/bulge_assets.py fix`,
  which re-encodes them at 8 bits with the same pixels and DMI metadata and prints the proof.
- The ordinary unit tests:
  - `bulge_manifest` pins every family's data, every sheet's MD5, and for every garment type with a bulge value what
    it inherits (family, print, suit rule, cloth layer) and what the renderer reads from its own definition (worn
    sprite and state, digitigrade sprite, GAGS configs and colours, groin coverage, worn layer, the sprites and GAGS
    configs it declares for a species' body; a suit's toggled state, offsets, dimensions, alpha and colour; an
    underclothes accessory's sprite, static colour, layer, GAGS colours, digitigrade state and groin coverage), against
    `code/modules/unit_tests/~nova/bulge_manifest.txt`. Reviewing a change: below.
  - `bulge_template_identities` resolves every identity the tool declares through the DM accessors and checks every
    sheet state it reaches as the tool's `verify` does: four directions, one frame, only kind greys or opaque white,
    nothing facing north. Past small_cap every identity must derive, and the identities resolved, by kind, must be its
    frozen record (`BULGE_IDENTITIES_RECORD`).
  - `bulge_derivation` derives every shape past small_cap, the anatomy each leaves bare, and every loincloth drape and
    cut, and holds them to a frozen record (`BULGE_DERIVATION_RECORD`: the states by kind, the shapes that cover the
    whole penis, and a digest of every pixel, the mask tiles and the cuts' keep masks included), taken from the sheet
    states they replaced, which they matched pixel for pixel. `bulge_derivation/pin` pins what they are derived from:
    the penis and testicle sprites, the loincloths' own sprites and the penis shapes' data. Either failing means bulges
    past small_cap look different on screen.
  - `bulge_palette` and `bulge_palette_hash` pin the adaptive palettes: every approved colour (the 4,096-colour grid
    and the 760 garment colours in `bulge_palette_colours.txt`, in three finishes) is hashed against the approved
    values. A failure means a change to the arithmetic moved an approved colour; the failing test writes the game's
    palettes to `data/bulge_palette_lines.txt` to compare.
  - `bulge_render_corpus/pixels` draws 29 cases of the pixel corpus (adaptive and printed garments, the large hearts,
    every skirt style half and hard, a loincloth reveal as underwear and as a uniform, digitigrade legs, a tall wearer,
    a suit, blood, a big tentacle, Custom above and below the underwear) and compares a hash of their pixels with the
    hash of the images the corpus comparator expects.
  - `bulge_templates`, `bulge_renderer/*`, `portal_test/bulge` and `bulge_cache_retention` test the approved special
    looks and the renderer's behaviour.
- The full pixel corpus: see below.

#### Reviewing a manifest change

`bulge_manifest` fails when a family's data, a sheet or a listed garment's own definition changes, and writes what it
found to `data/bulge_manifest.txt`. Before copying that over the committed file:

1. Diff the two. On a garment line, a new worn file or state is a re-sprite, `groin=0` means the garment no longer
   covers the groin (no bulge), a new `gags=` or `colours=` changes the colour the cloth is sampled from.
2. Look at it. `python tools/bulge_assets.py find <garment type>` prints the garment's family, `find <family type>` that
   family's `shapes=` name, and `find <that name>` the sheet states and derived templates named after it; then
   `python tools/bulge_assets.py preview <state> --output <folder> --garment <worn file>:<worn state>` draws a shape
   over the garment's sprite as the server derives it (printed, cut, clearance). Preview it over the old sprite
   (`git show`) and the new, side by side. For a family or sheet line, preview the states it changes.
3. Run `bulge_render_corpus/pixels`, and the full corpus for anything beyond a garment or two.
4. Then copy the file over and commit it with the change, saying what was reviewed.

#### The full pixel corpus

`bulge_render_corpus` draws every approved case (13,394 rows) when the server runs with
`-params bulge_render_corpus=full` and the case manifest in `data/bulge_render_corpus/manifest.json`, and writes what
the game draws to `data/bulge_render_corpus/out/`. The tables its expectation was built from are gone, so the
expectation and its comparator live in the lab run folder
`Meridian-Rift-BYOND-Lab/runs/bulge-system-20260929/continuation/fable-orchestration-20261002/`:

- `N4a-renderer/data/corpus/expect.json`: the frozen expectation;
- `N11-heart-patches-shapes/data/corpus/`: the case manifest, the rows added since (`expect-extra.json`) and the
  rows whose look changed on purpose (`intended.json`: Custom above the underwear, blood on a cut cover, the large
  heart boxers over the bare penis, and over a knotted or hemi penis in the patch drawn for its profile);
- `N11-heart-patches-shapes/harness/`: `make_copy.py <commit> <copy>` extracts a `git archive` of a commit into the
  lab, and `corpus_proof.py <copy> <commit> <label>` builds that copy focused on the corpus, runs it (one
  DreamDaemon, after the machine's memory guard), and compares every case pixel for pixel with `s10_compare.py`,
  which reads the sheets and the tool from this worktree, at that commit.

### Credits:

Shapes, prints and palettes: the bulge preview pipeline, approved by mal.
