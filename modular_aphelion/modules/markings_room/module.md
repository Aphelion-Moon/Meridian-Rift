## The markings rooms (Augments+)

Module ID: MARKINGS_ROOM

### Description:

In every MeridianOS theme, Augments+ is one fixed room, 900 by 820, that never resizes, after the theme's mockup. Its
header switches between the augments and the markings. The markings are a mirror in the theme's room: the club's
bathroom mirror in Cyberpunk and Augmentation (grimy subway tiles, a frameless glass held by clips, two neon tubes,
stickers among them the game's harm intent in the club's neon and a banana peel, and its drawers dark like its cards),
and each other theme's own room round its own glass, lamps and props. Each zone's markings are on a card stuck up
either side, and a counter of paints is below. The augments are a scan chamber. Windows without a MeridianOS theme
keep the columns.

- **The character is the preview every tab shows.** The mirror is the tabs' drawn preview (`character_preview`) in
  its `club` motif: no floor and no frame of its own, scaled up to 12x, turned, zoomed and panned as on every tab. It
  stands where the club's does in every room, its view reaching past the room's own glass, which clips it. The room
  only lights it: rim light from its lamps, screened onto the character's own pixels.
- **Pointing lights the part.** A card, one of its tiles or the body itself halos that zone on the character, glows
  outside it only, and dims the glass round it. The body is pointed at pixel for pixel: the room asks for the custom
  markings editor's region map of the preview body (`custom_sprite_region_map()`, cached by geometry), each facing
  laid on the drawing's frame with height's moved rows, so it lines up whatever the species, size or facing. A tile
  lights its marking on the body; the custom slot, its drawing. Clicking a part on the body opens its drawer, or
  selects its first marking when it is full.
- **Cards.** Each zone's card shows its markings as thumbnails, its empty slots dashed, and apart from them its
  custom drawing, which opens the custom markings editor on that zone (the taur body's on the legs of a taur). A
  thumbnail is the species' bare body from the species page's sheet, the marking's preference sprite over it in its
  colour, multiplied in as the game colours it, or the drawing's own pixels.
- **The drawer and the marking sets.** Adding or swapping a marking slides out a sticker sheet of the markings the
  zone offers, the species' own first, searchable; the ones it can't take now (worn, or of a worn marking's exclusion
  group) are greyed. A marking drawn only on the back says so. The pointer on one tries it on in the mirror. Marking
  Sets does the same for the presets, and asks before replacing markings, as the preset dropdown does.
- **The counter.** The selected marking's swap, glow (refused while the character doesn't allow emissives) and
  removal; paints for it, the first giving back the colour it starts in (the mutant colour it follows, or its own);
  one that opens character setup's colour picker; and Surprise me, which puts a whole new set of markings the species
  is meant to wear on every zone at once (`surprise_markings`), now and then in a paint and, when the character allows
  it, glowing.
- **Paint flies.** Paint, a marking or a look flies from what was clicked to the part it lands on, and the marking
  inks in at once, in its new colour, while the server draws it.
- **Lights off.** The header's switch is the tabs' lights-off switch: the room goes dark and the character is lit as
  the game lights it in the dark, so only what glows shows. The clubs, Aphelion, Hotline, Shadowbroker and Synapse
  hang a blacklight, which lights the character from above in its colour; under Shadowbroker's, a smiley sticker
  glows.
- **The augments.** A scan chamber with the character in it: each body part's slot card and each organ's, traces
  from the cards to the parts on the character, and a console totting up what is fitted. Pointing at a card lights
  its part on the character, masked by the same region map; a card's rows open a picker of the augments, finishes
  and implants that fit it, refusing what the character's quirk points can't pay for, and its part shows the pick
  while the pointer is on it. The internals switch shows the organs through an x-ray of the character.

### What the server sends

`/datum/preference_middleware/markings_room`:

- constant data, `markings_room.marking_defaults`: the colour each marking with one of its own starts in, by name;
  and `native_marking_icons`, each marking's full-size sprite for the mirror;
- static data, `markings_room_delam`: the engine's record, for Hephaestus's tag;
- ui data: `marking_fur_colors`, the preview body's three mutant colours, which every other marking follows;
  `custom_marking_views`, each zone's custom drawing as saved (its palette and every view's run-length code); and
  `markings_room_clock`, the station's time for Electra's clock, which the page ticks on from each update;
- `markings_room_regions` (action, answered in an update of its own): the region map for the drawing the page names;
- `surprise_markings` (action): Surprise me. Open custom sprite editors are finished first, as for every other marking
  action;
- assets, `/datum/asset/simple/markings_room`: every room's textures and fonts (`assets/`, see its README), and a
  stylesheet written when the asset registers, declaring each texture as a custom property on the room
  (`--mr-<name>`) and each font as a face, by the URLs the asset transport gives them. They aren't in tgui's bundle,
  which every window loads. `code/markings_room_assets.dm` lists them; the stylesheet is an art stylesheet's
  (`meridian_ui`'s `code/art_stylesheet.dm`), as is the Foundry theme's, which sends six of these files under the
  room's names.

The augments themselves are the limbs and markings middleware's (`set_bodypart_aug`, `set_bodypart_aug_style`,
`set_internal_implant_aug`).

### TGUI:

- `CharacterPreferences/MarkingsRoom/`: the room (`Room.tsx`), each theme's look (`themes.ts`) and props (`decor/`),
  the markings (`index.tsx`), the mirror and what it draws on the character (`Mirror.tsx`), cards, counter, drawer,
  what the drawer's pointer tries on (`tryOn.ts`), thumbnails (`Thumb.tsx`, `sprites.ts`), the region map on a frame
  (`regions.ts`), the character's own outline (`facing.ts`), drawings (`customs.ts`) and the augments stage
  (`augments/`). `LimbsPage.tsx` shows the room in the MeridianOS themes.
- `CharacterPreview`: the `club` and `chamber` motifs, `maxScale`, `lit`, an `overlay` drawn with the character
  (layers marked `data-preview-pan` pan with it) and `onTap`.
- `styles/meridianos/_markings-room.scss` (the club's room, the base of every other), `markings-room/` (each theme's
  changes), `_augments-stage.scss` and `_augments-overlay.scss`. The pixel props inline in the bundle are in
  `styles/meridianos/assets/markings/`.
- The room is marked `data-window-fit="fixed"`: what changes inside it never makes the window measure its content
  again (`hooks/useWindowSizing.ts`).

### Credits:

The fonts' sources and licences are in `assets/README.md`, their licence texts in `assets/fonts/licences/`. Sith is
by Ender Smith and AurekFonts, CC BY 3.0 US. The textures and pixel props are original, generated for the mockups.
