## Species page

Module ID: SPECIES_PAGE

### Description:

Replaces Character Preferences > Species with a character-select style page. The inspected species
stands in a large turning specimen chamber at the top, and below it the family tabs sit over a
roster of every species with search. Nothing changes the character until **Select species** is
pressed; clicking a tile only inspects it. Everything above the inspected species' description keeps
its height from species to species, so browsing never moves the page under the pointer.

- **Families and lineages.** Each species names its family through
  `/datum/species/proc/get_species_family()`, a `/datum/species_family` typepath. Families give
  their own name, icon and order, the way quirks give their icons, and reach the page with the
  static preference data from `/datum/preference_middleware/species_page`. A species is a
  variant of its parent type when the page offers that parent too (Felinid of Human, Ash Walker of
  Lizardperson), and Vox Primalis is filed with the Vox. Variants in another family, like the
  holiday Vampire, stand on their own there and still name their parent. The template species, bases
  for players' own creations (Humanoid, Anthromorph, Anthromorphic Insect, Aquatic, Synthetic
  Humanoid), are filed last, under Generic. The roster puts every tile on one grid of columns, and
  each lineage's box sits in the gaps around its tiles, at the start of its row.
- **Holiday species** can be picked in character setup all year and are joinable during their
  holiday. `/datum/species/proc/get_holiday()` names the holiday that makes a species a roundstart
  race, mirroring `check_roundstart_eligible()`; jobs already refuse species that are not roundstart
  races, so joining needs no new check. While they wait for their holiday they are filed under the
  Holiday family whatever their own, and the page hides them behind a **Show holiday species** toggle
  unless their holiday is on, or the character already is one.
- **No placeholder text.** Placeholder and "fill this in" descriptions and lore are left out of the
  page's data, and the page draws nothing in their place.
- **Specimen chamber.** The inspected species turns in four directions, in uniform or without, from
  `/datum/asset/spritesheet_batched/species_full` and `/datum/asset/spritesheet_batched/species_full/body`,
  which replace the old 64x64 head sheet. Every MeridianOS theme dresses the chamber from its own
  materials, and Classic follows stock tgui. The chamber's motion pauses while the window is hidden
  or unfocused.
- **The character itself.** While the chamber shows the character's own species, it shows the
  character: the preferences preview mob, as the preview shows it, drawn facing each way when the page
  opens, and only if it has changed since it was last drawn. One `get_flat_uni_icon()` walk serves all
  four facings (`uni_icon_facings_json()`), iconforge draws the strip off the main thread, the same
  look is drawn once however many share it, and each drawing goes to a client once. A drawing is kept
  only while some character shows it, so there is at most one per character that opened the page. The
  walk grows its canvas to fit parts that reach past the mob's tile, like big ears and wings, and the
  page stands the mob's own tile where a species sprite stands, scaled down only as far as those
  parts need.
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
`species_page_sprites` act, and the character's own preview from its `species_page_self` act and its
ui data. Browsing, the family tabs, search and the holiday toggle are local UI state.

### TG Proc/File Changes:

- `code/modules/client/preferences/species.dm`: `/datum/preference/choiced/species/init_possible_values()`
  offers holiday species; `/datum/preference/choiced/species/compile_constant_data()` sends the
  species page's species, text without placeholders, family, lineage and restrictions
- `code/modules/client/preferences/middleware/species.dm`: the preferences window no longer sends a
  species sheet, and `/datum/asset/spritesheet_batched/species` is commented out
- `modular_nova/modules/customization/modules/mob/living/carbon/human/species/aquatic.dm`: renamed
  to Aquatic
- `code/modules/asset_cache/spritesheet/batched/universal_icon.dm`: `/proc/get_flat_uni_icon()` writes
  each runtime icon out once instead of on every flatten, which was most of a flatten's cost, and takes
  `grow`: the canvas then fits every overlay, nested flattens placed where their own grown canvases
  really start, and the result's new `flat_x1`/`flat_y1`/`flat_width`/`flat_height` vars say where the
  appearance sits in it. Without `grow` it flattens exactly as before.
- `tgui/packages/tgui/interfaces/PreferencesMenu/index.tsx`: the window is 40px taller while the
  species page shows, for two whole rows of its roster under the chamber

### Modular Overrides:

- `modular_aphelion/modules/species_page/code/species_previews.dm`:
  `/datum/species/aquatic/prepare_human_for_preview()`, `/datum/species/unathi/prepare_human_for_preview()`

### Defines:

- N/A

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/SpeciesRegistry/` (the page)
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/SpeciesPage.tsx` (the old page, commented out)
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/index.tsx` (imports the new page,
  and tells the window while it shows)
- `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts`
- `tgui/packages/tgui/interfaces/PreferencesMenu/useServerPrefs.ts`
- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.test.tsx`
- `tgui/packages/tgui/styles/meridianos/_species.scss`
- `tgui/packages/tgui/styles/meridianos/_preferences.scss` (loads it; the old page's rules commented out)
- `tgui/packages/tgui/styles/meridianos/tests/control-contract.test.tsx` (the old species button case commented out)
- `tgui/packages/tgui/styles/meridianos/assets/species/cyberpunk-glyph-pylons.svg`
- `tgui/packages/tgfont/icons/zaphelion-alien.svg`, `zaphelion-orange.svg`, `zaphelion-pineapple.svg`

### Credits:

- mal
