## Species page

Module ID: SPECIES_PAGE

### Description:

Replaces Character Preferences > Species with a character-select style page. The inspected species
stands in a large turning specimen chamber at the top, and below it the family tabs sit over a
roster of every species with search. Nothing changes the character until **Select species** is
pressed; clicking a tile only inspects it. Everything above the inspected species' description keeps
its height from species to species, so browsing never moves the page under the pointer.

- **Families and lineages.** `GLOB.species_page_families` files each species type under a
  `/datum/species_family`, and a subtype takes its nearest listed parent's; `/datum/species/proc/get_species_family()`
  looks it up. Families give their own name, icon and order, the way quirks give their icons, and reach the page
  with the static preference data from `/datum/preference_middleware/species_page`. A species is a variant of its parent type when
  the page offers that parent too (Felinid of Human, Ash Walker of Lizardperson), Vox Primalis is filed
  with the Vox, and Kobolds with the Lizardpeople. Variants in another family, like the holiday Vampire,
  stand on their own there and still name their parent. The template species, bases for players' own
  creations (Humanoid, Anthromorph, Anthromorphic Insect, Aquatic, Synthetic Humanoid), are filed last,
  under Generic. The roster puts every tile on one grid of columns, and each lineage's box sits in the
  gaps around its tiles, at the start of its row.
- **Holiday species** can be picked in character setup all year and are joinable during their
  holiday. `/datum/species/proc/get_holiday()` names the holiday that makes a species a roundstart
  race, mirroring `check_roundstart_eligible()`; jobs already refuse species that are not roundstart
  races, so joining needs no new check. While they wait for their holiday they are filed under the
  Holiday family whatever their own, and the page hides them behind a **Show holiday species** toggle
  unless their holiday is on, or the character already is one.
- **No placeholder text.** Placeholder and "fill this in" descriptions and lore are left out of the
  page's data, and the page draws nothing in their place.
- **Specimen chamber.** The inspected species turns in four directions, in uniform or without, from
  `/datum/asset/spritesheet_batched/species_full` and
  `/datum/asset/spritesheet_batched/species_full/body`, which replace the old 64x64 head sheet. Each
  species stands as tall as it does in the round: its dummy takes its height as one filter over the whole
  body, as character setup's does, and since a flatten leaves filters out, the rows the filter moves are
  moved in the render itself, from bands of it (`species_page_height()`), so Kobolds and Dwarves are
  short. Every MeridianOS theme dresses the chamber from its own materials, and Classic follows stock
  tgui. The chamber's motion pauses while the window is hidden or unfocused.
- **The character itself.** While the chamber shows the character's own species, it shows the
  character: the drawing of the preferences preview mob that every tab of character setup shows (see
  the character preview module), with its height and body size, standing where a species sprite
  stands, its own tile on the chamber floor, scaled down only as far as parts that reach past that
  tile, like big ears and wings, need. It never shows the drawing for a species that has since
  replaced it, and the chamber's loader stays up while a newer drawing is on its way.
- **Sprites cost nothing until they are wanted.** Neither sheet draws anything during init: both are
  drawn in one pass when either is first realized, by `SSasset_loading` in the lobby or by the first
  player to open the page, with one walk per species and outfit rather than one per facing. The
  preferences window no longer carries a species sheet; the page asks for the uniform sheet when it
  opens, and for the body sheet only once someone turns a specimen to its body. Every file reaches
  the client before the page hears of it: a stylesheet whose image hasn't arrived stays blank.
- Akula (Generic) is renamed Aquatic, and Aquatic and Unathi get previews that read as themselves.
  The id is unchanged, so saves need no migration.

Everything the page shows about species is static: the species preference's constant data and
the species page middleware's families, both in the cached preferences JSON asset
(`useServerPrefs()`). Only the character's species and Nova Star status come from `useBackend()`,
choosing a species is the usual `set_preference` act, the sheets come from the middleware's
`species_page_sprites` act, and the character's own preview is the character preview's drawing in
the window's data. Browsing, the family tabs, search and the holiday toggle are local UI state.

### TG Proc/File Changes:

- `code/modules/client/preferences/species.dm`: `/datum/preference/choiced/species/init_possible_values()`
  offers holiday species; `/datum/preference/choiced/species/compile_constant_data()` sends the
  species page's species, text without placeholders, family, lineage and restrictions
- `code/modules/client/preferences/middleware/species.dm`: the preferences window no longer sends a
  species sheet, and `/datum/asset/spritesheet_batched/species` is commented out
- `modular_nova/modules/customization/modules/mob/living/carbon/human/species/aquatic.dm`: renamed
  to Aquatic
- `code/modules/asset_cache/spritesheet/batched/universal_icon.dm`: `/proc/get_flat_uni_icon()` writes
  each runtime icon out once instead of on every flatten, which was most of a flatten's cost, and
  `uni_icon_facings_json()` stamps one walk with each facing, so one walk serves all four. The character
  preview module shares these edits.
- `code/modules/asset_cache/spritesheet/batched/batched_spritesheet.dm`: `realize_spritesheets()` lets one
  caller generate a sheet (`generate_spritesheets()`) while any other waits for it
  (`generation_in_progress`), and a consumed rust-g job's `job_id` is cleared, so the lobby's loader and the
  page asking for its sheet can't race and lose a job's result; `spritesheet_concurrent_loading` in
  `code/modules/unit_tests/spritesheets.dm` covers it
- `tgui/packages/tgui/interfaces/PreferencesMenu/index.tsx`: the window is 40px taller while the
  species page shows, for two whole rows of its roster under the chamber

### Modular Overrides:

- `modular_aphelion/modules/species_page/code/species_previews.dm`:
  `/datum/species/aquatic/prepare_human_for_preview()`, `/datum/species/unathi/prepare_human_for_preview()`

### Defines:

- N/A

### Included files that are not contained in this module:

- `modular_aphelion/modules/character_preview/code/`: the renders use its `character_preview_rows()`,
  `character_preview_flat_box()` and `GLOB.character_preview_facings`
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/SpeciesRegistry/` (the page)
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/SpeciesPage.tsx` (the old page, commented out)
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/index.tsx` (imports the new page,
  and tells the window while it shows)
- `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts`
- `tgui/packages/tgui/interfaces/PreferencesMenu/useServerPrefs.ts`
- `tgui/packages/tgui/styles/meridianos/_species.scss`
- `tgui/packages/tgui/styles/meridianos/_preferences.scss` (loads it)
- `tgui/packages/tgui/styles/meridianos/assets/species/cyberpunk-glyph-pylons.svg`
- `tgui/packages/tgfont/icons/zaphelion-alien.svg`, `zaphelion-orange.svg`, `zaphelion-pineapple.svg`
- `code/modules/unit_tests/screenshots/screenshot_humanoids__datum_species_aquatic.png`,
  `screenshot_humanoids__datum_species_unathi.png` (the humanoid screenshots, with the new previews)

### Credits:

- mal
