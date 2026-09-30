## Custom hair and markings

Module ID: CUSTOM_SPRITES

### Description:

Adds pixel editors for custom hair and markings in character preferences. You can
add to an existing haircut or give individual body zones their own drawings.
Markings are drawn on one whole-body canvas that saves each region into its own
per-zone drawing. Barbers and tattoo artists can use the same editor on
other players, with consent, a mirror preview and an optional save. Everything
uses the existing SpriteEditor.

#### Opening the editors

Custom hair drawing is in the hairstyle picker on the main character page, and
custom facial hair drawing is in the facial hairstyle picker. Both work exactly
alike: the same editor, tools, bounds, palette, base-look controls, import and
export, salon work and saved previous style. Facial hair is drawn on the lower
face and saved under its own key, so the two never touch each other.
Each marking section on the body customization page's Markings tab has a
**Custom** button, below its **+**:
Head, Torso, Left arm, Right arm, Left hand, Right hand, Left leg and Right leg.
Their tooltips say what each one draws over. A button is lit up, with a check
mark, once its drawing has paint; an empty canvas saves as no drawing, so it
stays plain. The **+** disappears once a limb has its three markings. A limb
can't wear the same marking twice: **+** picks at random from the ones it doesn't
have (without **Allow mismatched parts**, only those meant for the character's
species, as the dropdowns list), and each row's dropdown leaves out names the other rows use, the same way
the editor's Base markings section does. The server refuses duplicates from either.
Both pickers zoom each marking's icon to its body part over a grey checkerboard and
draw it at triple opacity, so dark and faint shading markings stay visible; the
zoom areas in `ChoicedSelection.tsx` were measured to fit every current marking.
With a taur body selected and enabled, the legs have no paintable pixels and
their markings never show, so both leg sections swap their + and Custom buttons
for a **Taur body** button, and the server refuses new leg markings.
Every Custom button, and the Taur body button, opens the same whole-body
**Custom Markings** window with that region selected. If the window is already
open, the button brings it forward and selects that region; a region the body
doesn't have leaves the selection alone and says so. Drawings are still stored
per zone: ordinary zone, hand and taur-zone drawings stay separate, and only the
editor shows them as one body.

Hands aren't limbs of their own: they're the arm's auxiliary zone. A hand drawing
covers the hand plus the three arm rows just above it, so it can't climb the arm,
and renders as its own overlay on that arm. On the whole-body canvas those three
rows belong to the arm, so the arm's region runs its whole length and the hand's
is just the hand. Hand paint already on them still shows, as it does in game;
painting over it moves it to the arm.

Hair and ordinary limb drawings are 32 by 32, taur-zone drawings 64 by 32, and
tall hair drawings 32 by 48 (see Tall custom hair).
The markings canvas is 64 by 32 whenever the body has a taur organ, even a hidden
one, so it doesn't change size with clothing; otherwise it's 32 by 32. All have
Front, Back, Right and Left views, switched with one framed group of buttons; the pip
after each view's name is a hollow ring when that view has no paint and a lit disc when
it does. Hair and facial hair can be
drawn anywhere on their canvas, regardless of the base style. Markings use
the actual body's silhouette in each direction, divided into regions (below).
The taur zone follows the external taur organ on
the chest; its invisible leg slots remain unavailable. Missing limbs and stumps
have no editable zone pixels, and a missing arm takes its hand with it.

#### Tall custom hair

The base hairstyle **Bald (Tall Canvas)** draws no hair of its own and never
spawns naturally. Custom hair (not facial hair) drawn over it gets a 32 by 48
canvas: the usual 32 rows with 16 more above them, for hair bigger than any base
hairstyle. The guide and the preview grow with it, with the body at the bottom as
in game, and the canvas backdrop continues its tile upward.

A drawing whose paint reaches into the extra rows saves as version 4 and renders
those rows above the head, the way the taur's wide icon reaches past the sides of
the tile. One that stays within the usual 32 rows saves exactly as a normal
drawing, so it works over any hairstyle. Opening a tall drawing always gives the
tall canvas, whatever the base style, so nothing is ever cut. Picking **Bald (Tall
Canvas)** in the editor's Base hair control, or leaving it when the paint fits in
32 rows, changes the canvas size and keeps the paint where it sits on the head.
Confirming an import or a restoration does the same, going by the style's own
base hairstyle and paint: short paint over the tall base grows a normal canvas
at once, and short paint over a normal base shrinks a tall one. The undo history
can't span two canvas sizes, so it starts over, and a notice says so. An import
or restoration of a tall drawing into a normal canvas is still refused until the
tall base is chosen, and tall drawings are refused for facial hair and markings.
Hair masks from hats and hair gradients carry on over the extra rows as their
top row does. The salon's hair editor and the mirror's pictures follow the same
rules.

Character setup's dummy is drawn as one piece with its height filters on the
whole body, and tg's 32 by 32 maps only cover the body's own tile. Anything drawn
above the tile, such as tall paint, a lifted hairstyle or a tall hat, stayed put
while a Short to Tallest body moved its head, so rows were lost or repeated
where the tile ends. `/mob/living/carbon/human/dummy/apply_height()` carries each
map on 32 rows upward as its top row, moved up so the map's own rows stay on the
tile, so everything above the tile moves as the head does. The body is drawn only
as far as its images reach, so a transparent spacer 64 rows tall keeps the rows
the maps lift from being cut off at the top. In game, hair only takes the head's
pixel offset and never tore; markings sit on their limbs and stretch with them in
both places. Character setup's preview is drawn whole however far up the head
reaches: its drawing grows to fit everything the body draws, and the page fits
what it draws, not the empty rows the spacer keeps (see the character preview
module).

#### Lifted hairstyles

Some base hairstyles are drawn above the head: Afro (Huge) sits 6 pixels up and
Mohawk (Tall) 2, and a species' hair offset moves hair too. Custom hair painted
over such a hairstyle is lifted with it, so the canvas's 32 rows are the
hairstyle's own rows and the whole hairstyle fits them; it needs no tall canvas.
The hair guide is flattened from that lifted window of the body, so it shows the
whole hairstyle, with the body lower down and its feet below the canvas, where
hair paint can't reach anyway. The preview, the previews of an import or a
restoration and the mirror's pictures grow upward as far as the hair reaches,
standing on the backdrop tile, which repeats upward. Facial hair isn't lifted,
so its guide keeps the body's own rows. The whole-body markings editor's composed
previews stay 32 rows, so a lifted hairstyle is cut there.

The wide canvas adds 16 columns on each side of the ordinary body. Existing
32-pixel paint stays centered at the same physical position when opened on a
taur. Guides, paint and previews share that origin, including hair, which stays
32 by 32. Wide preview images retain their 64 by 32 proportions.

Uncomment `DISALLOW_CUSTOM_SPRITE_EDITING` at the end of
`config/nova/config_nova.txt` to hide the buttons and reject editing actions.
Saved drawings still render. Editors check the owning client, character slot,
target and optional body zone on the server, including after color-picker dialogs.

#### Hair appendages

Custom hair can carry up to three appendage layers (`CUSTOM_SPRITE_MAX_APPENDAGES`)
besides the base hair, which behave as hairstyles' own `hair_appendages_inner` and
`hair_appendages_outer` pieces do:

- **Under hats** pieces draw with the hair, under headwear. A worn hair mask trims
  one only when the mask's `strict_coverage_zones` include where it attaches.
- **Over hats** pieces draw on `OUTER_HAIR_LAYER`, above headwear, and are never
  trimmed. While a worn mask strictly covers where one attaches, it isn't drawn.

A piece attaches at one `HAIR_APPENDAGE_*` zone, listed as Crown, Forehead, Left
side, Right side, Back of the head, Down the front and Down the back, names that
never reuse the view names. Berets and hard hats cover the crown; fedoras and
security helmets also cover the sides and the back of the head; winter hoods and
hoodies cover hair down the back as well. No hat covers the forehead or hair down
the front. Tint, gradients, alpha, lifts, species offsets and dropped heads follow
the base paint, and emission is set per layer and view.

The hair editor has a layer strip under the view switcher: **Base hair layer**, a
tab per appendage (its kind, name, zone and a pip for the view shown), **+
Appendage layer** while there's room for another, and the count. Long names are
shortened on their tabs, whose tooltips carry them whole. While the base hair is
chosen the canvas takes the whole column, and its tab's tooltip explains
appendages. An appendage gets a panel under the canvas that picks its kind and
zone, shows the try-on hats that cover each zone, and says in one sentence what
the tried-on hat does to it. The window crops those hat chips from the hats' front
views itself, since BYOND exports an icon smaller than a tile padded out to 32 by
32. The pencil beside its name renames it, 20 characters at most
(`CUSTOM_SPRITE_MAX_APPENDAGE_NAME`), cleaned as the server cleans names.
**Copy to over-hat layer** copies an under-hat piece to a new over-hat layer, for
a piece that should stay under headwear in some views and over it in others, and
**Remove** removes it. Clear, Emissive and the view pips act on the chosen layer.
Adding, removing, renaming, moving, changing kind and copying are undoable steps in
the one history, and every layer shares the drawing's 63 colors. The salon's hair
editors work the same way.

The canvas shows the chosen layer's every pixel. The others show as they'd be
worn, faded, in draw order: the base hair, under-hat pieces, the hat, over-hat
pieces. **Try on**, under the preview while an appendage is chosen, puts a hard
hat, a fedora or a winter hood (one per hair mask the game's hats use) on the
canvas at half strength and on the preview, and hatches the chosen layer's paint
that hat trims (white) or hides (in the over-hat colour); resting the cursor there
names the hat. The base hair is always painted with no hat on. The hats' masks and
placed sprites are static data built with the other resources, cached per canvas
height and lift. Each Meridian theme gives the layer kinds, the tried-on hat and
the layer controls colours from its own palette (`$appendage-themes` in
`CustomSpriteEditor.scss`), and the canvas reads them for its strikes and lines.

Strokes, fills and selection moves name their layer by index and id, so a stroke
meant for a layer that undo has just moved is refused instead of landing on
another. The window receives only the visible view of each appendage and waits
for a view it turns to before letting it be painted.

The hair drawing gains an optional `appendages` object keyed `"1"` to `"3"`, each
`{name, zone, outer, dirs, emissive}` in the drawing's palette, version and size;
a tall drawing's appendages are tall. A drawing without appendages saves exactly
as before. Loading drops a bad or empty appendage on its own and keeps the rest;
imports are strict. A drawing whose base hair is empty but whose appendages have
paint is valid. Unpainted appendage layers survive hairstyle changes and canvas
resizes but aren't saved. A canvas resize keeps every layer in its place under its
id, so the window stays on the layer it was painting. Facial hair and markings
never carry appendages. In
practice an appendage adds 1-2 KB to a slot; three incompressible tall ones fit
the 32 KiB single-target import limit.

#### Regions and selection

Every pixel of the markings canvas belongs to one region or none: Head, Torso,
Left arm, Right arm, Left hand, Right hand, Left leg, Right leg or Taur lower
body. The server builds a region map for each view. It fills every present
region's editing mask with an ID color, pushes it through that region's real
overlay type, and composes the results in the game's draw order: the body's limb
order, each hand above its arm, the leg layer split and the taur organ's native
layers. The region on top owns the pixel; a blended edge pixel goes to the
region that shows most in it. ID colors sit on a circle, so a blend of two
regions never reads as a third. Maps are cached by the geometry that produced
them, and building one leaves the shared icon caches alone.
Whenever an arm's drawing overlay is created again, its hand overlays move back
above it, so hand paint draws over arm paint on shared pixels, in game and on the
canvas.

- Pressing on the body with the primary button selects the region under the
  cursor, with any tool and with Alt-click sampling. Pressing unavailable space
  keeps the selection. The window highlights at once and tells the server, whose
  selection the region actions work on; an action naming any other region is
  refused. Region actions pass the same window checks as every other action.
- The selection drives the region's Base markings section ("Left arm base
  markings"), its Emissive checkbox (`Emissives - (Left arm, Front)`) and Clear
  ("Clear left arm"). A status line under the canvas names the region, adds
  "(not in this view)" when it has no pixels in the current view, and gives
  the reason when the region is locked.
- Fill floods only the region you click; other regions' pixels are boundaries.
  Every other tool follows the paintable mask, which is the union of all regions.
  Moved pixels belong to whichever region they land in.
- The canvas shows each region's saved paint at the pixels it owns. At an arm or
  hand pixel it shows the hand's paint when there is any, otherwise the arm's,
  as the game draws them. Paint hidden under a different limb isn't shown.

The overlays are black and white and drawn at screen resolution. They never cover
the highlighted region's own pixels: brackets, tag and outline sit just outside
it, at most over the edge of a neighbouring region. Unavailable pixels get a dark
wash with faint horizontal scanlines, in every custom editor. The selected region
gets target-lock corner brackets and a small name tag (`L. ARM`, `TORSO`) above
the top-left bracket, or below the box when there's no room. The tag shows for
a second and a half after a region is selected, then fades; the brackets stay.
Hovering another region outlines it faintly, just outside its pixels.

Paint that hair, a mutant part or underwear draws over in game (anything on a layer above
the marking layer: snouts, ears, tails, wings, hair, and the underwear, bra, undershirt and
socks piece by piece) is washed dark and struck through on the canvas, whether or not the
guide shows that part, and resting the cursor on such a pixel names the part on top:
"Hidden by snout" (the hair layer is always "hair"). On a tattoo, what the recipient wears
counts too, under the item's own name: over a region that clothing locks, the tip reads
"Blocked by the black jacket" whether or not the pixel is painted, and elsewhere clothing
only hides paint like any part. The server builds those pixels once per body geometry with
the guides (`custom_sprite_cover_looks()` stamped into rows by `custom_sprite_cover_rows()`,
lowest look first) and sends them as the static `coverMask` rows of marks with the
`coverParts` labels they index and `coverWorn` flags for worn items; hair editors send none. Nothing is recomputed per stroke. The rows are cached by what they were
flattened from (each part's render key and placement, the hair look, the body height and the
paint layer), so a Parts or Underwear toggle, a salon clothing refresh or a reopened editor
reuses them, and only the view's own drawable box, before any view lock, is read pixel by
pixel. Each region is judged against its own paint layer: hand paint sits above the body's
parts (`custom_sprite_merge_cover_rows()`), and the taur's paint is never covered.

A drag ends up in the region it is released over; released off the body, the last region
the drag crossed stays selected. A plain click off the body changes nothing.

#### Tools and controls

- The tools sit in one framed group, the active tool filled. Tools with a hotkey show
  the letter in their corner (M, B, E, G); tooltips keep the full name. Undo and redo
  follow, then Clear, each framed like any other button, with a thin rule between the
  groups. Import and Export stay in the toolbar as one framed pair.
- Select comes first in the toolbar. Drag a box, then drag inside the selection to
  move its paint. The box can start in a shaded area, and you can grab it there
  too. All painted pixels in the selection move, including old paint left in a
  shaded area. Dragging with the right button takes a rectangle out of the
  selection; its marching ants then follow the pixels left, and pressing a pixel
  taken out starts a new selection.
- Dragging is free, even partly off the canvas; part of the box always stays on it.
  A move whose paint all lands on paintable pixels is sent at once, as one action.
  Paint that doesn't all land floats with the box instead, until a later drag
  lands all of it, when it is sent the same way. Pasted, turned and mirrored paint
  floats wherever it lands. Floating paint is only written when the marquee goes
  away (a new selection, another tool or view, Enter, Ctrl+S, Save and close or
  Finish, or closing the editor), and whatever is then off the canvas or outside
  the paintable area is cut off. Escape and history throw floating paint away.
  On markings and tattoo canvases, finishing a drag, paste, turn or mirror also
  updates the character preview after its usual pause. That temporary picture
  shows the paint that would land on the body; floating pixels outside the body
  remain available to reposition. It does not change the draft, undo history,
  saves or exports. Cancelling restores the draft's preview. Hair previews still
  show floating paint when it is written.
- Ctrl+C copies the selection's shape and paint, floating or not. The copy lives
  in the tgui window rather than the editor, so an editor opened later in the same
  window can still paste it. Ctrl+X copies and takes the paint off in one step.
  Ctrl+V pastes it as floating paint where it was copied from, in whichever view
  and layer are showing, with part of it on the canvas. Where there is a native
  base or other layers to add, a **Copy all** toggle sits beside turn and mirror:
  while it's lit, Ctrl+C copies the selection as it shows, every layer's paint
  with the topmost winning and the native base hair or markings under it, and
  Ctrl+Shift+C does that once. The layers are composed in the window; only the
  base pixels come from the server, as one paced request. R turns
  the selection a quarter turn clockwise about its middle and Shift+R
  counter-clockwise; paint still on the canvas is lifted to float first. Shift+H
  mirrors it left to right the same way, as Shift+H flips horizontally in Aseprite
  (GIMP's flip tool is Shift+F). While there is a selection, turn and mirror buttons
  sit beside the tools and do the same, carrying their keys as the tools do. While
  Select is the current tool, a line beside the footer buttons lists its keys. All
  of this is worked out in the window: the server only receives the finished move,
  as one transaction, never anything per mouse movement.
- Pencil, eraser, eyedropper and fill use the same canvas. Pencil and eraser
  include the release position and send one transaction per stroke. Fill stops
  at holes in a zone's silhouette.
- Markings clip to the body instead. The whole-body canvas only holds paint
  inside its regions; saved paint outside them, or hidden under another limb,
  stays in the save untouched until Clear, an import or a restoration replaces
  that region (see Saving and loading). In the salon, regions the recipient
  can't be tattooed on right now are locked; see Custom haircuts and tattoos.
  Imports that paint outside the destination are refused rather than trimmed.
- The eyedropper takes painted color first. If there is no paint at that pixel,
  it samples the visible guide. Sampling a color does not use a Custom slot.
- Undo and redo each step through one action in the current draft; they never
  open saved styles or other drafts. Editor shortcuts don't activate held items.
  A selection move is one action,
  including overlapping moves and pixels it replaces. Custom drawing history
  keeps up to 100 actions and lasts only for that editor session.
- Clear is a framed button with a red icon in the theme's text that fills red on
  hover (Classic, which spaces grouped buttons in a recessed tray, draws it and
  Remove solid red), and clears the current direction. In the hair editors it reads **Clear direction**.
  With no region selected it reads **Clear region** and
  is disabled. It can
  also remove old paint outside bounds that changed with the character's body
  shape. It is undoable. Clearing an empty view leaves redo alone. In the
  markings editor it reads **Clear left arm** and clears only the selected region
  in the current view, including its saved paint other limbs cover there, which
  the canvas can't show.
- The visibility toggles sit in one recessed tray at the right of the first row and
  all mean *show*, lit when visible: Guide, Parts (markings only), Underwear (markings
  in character setup; it starts unlit when character setup previews the character
  naked), Gradient (hair only) and Grid. The server flags stay `hideParts` and
  `hideUnderwear`; the window inverts them. The guide shows the body as it is,
  underwear included unless hidden, and excludes the drawing being edited. Parts only
  changes the guide; the preview always shows hair and parts. Guide and paint share
  the same canvas and pixel grid.
- Markings editors name the selected region beside the view switcher, with
  "(not in this view)" when the region has no pixels in that view; the status line
  under the canvas keeps only a locked region's reason.
  Preview comes last in the sidebar; its rotate buttons step through the views in
  the same order as the character preview's.
- Tile swatches under the preview pick the backdrop behind the canvas, the
  preview and the import/restore previews: **Transparent** (the checkerboard),
  then Nova's `background_state` tiles, doubled side by side on a wide canvas.
  The row starts on the character's own background, or the artist's in the
  salon. The choice is never saved, since writing a preference would save and
  close the editor.
- The window opens at 1100 by 920, or 1100 by 960 for hair, whose wider side panel
  also fits its layer strip, the appendage panel and Try on, tall canvas included,
  in every theme's frame without scrolling. A wide canvas (a taur's whole body)
  opens at 1400 by 920, since it fits by its width. A view of it with nothing
  paintable or painted outside its middle half, as a taur's front and back are,
  shows just that half at twice the size; the canvas keeps its full width, so
  strokes and selections keep their places. The preview takes whatever height the
  side panel has left, Try on included, and grows by the largest whole number that
  fits, with its turn buttons under it as the canvas has; a wide picture that's
  clear outside its middle half shows just that half the same way.
  Closing the window keeps the unsaved draft and its history; reopening continues
  it with the Pencil selected. Changing direction drops a selection's floating
  paint onto the view it came from; using history cancels the selection and throws
  floating paint away. Pressing the canvas takes focus off the last button pressed,
  so Enter and the shortcuts reach the canvas.

| Shortcut | Action |
| --- | --- |
| Ctrl+S | Save without closing. Saved flashes after the server confirms success. |
| Ctrl+Z | Undo. |
| Ctrl+Y or Ctrl+Shift+Z | Redo. |
| Alt+left-click | Sample paint, or the visible guide underneath, without changing tools. |
| Mouse wheel over the canvas or swatches, or [ / ] | Previous / next palette color, wrapping through Palette and available Custom colors. |
| Escape | Deselect, throwing floating paint away, or dismiss an open swatch menu. |
| Ctrl+C / Ctrl+X / Ctrl+V | With Select: copy / cut the selection, or paste it as floating paint in the view and layer shown. Ctrl+C copies everything shown while Copy all is lit. |
| Ctrl+Shift+C | With Select: copy all of the selection as it shows (paint of every layer and the base), once. |
| R / Shift+R | With Select: turn the selection a quarter turn clockwise / counter-clockwise. |
| Shift+H | With Select: mirror the selection left to right. |
| Enter | With Select: drop the selection, writing any floating paint. |
| Delete while hovering a Custom swatch | Remove that saved color. |

Save and close, Undo, Redo and Eyedropper show their shortcuts in their tooltips.
Swatches have no tooltips, so nothing covers their right-click menus; the Palette
title explains color cycling instead. Scrolling elsewhere still scrolls the window.

The keyboard handlers leave text inputs alone. Canvas gestures claim their own
mouse events so drawing does not turn into dragging the window. The shared
window handler uses the mouse event's current Alt state, so a missed key release
cannot leave window dragging stuck on.

Select is also available in ordinary painting canvases and NanoPaint. Their
existing restrictions on tools, layers, colors and undo still apply.

#### Palette and color blending

Palette contains sampled colors. Hair uses the selected hairstyle's shades with
the character's effective hair color, plus its active gradient color. Markings
use all three mutant colors and sampled marking shades. Eyedropper picks are
also available here.

Custom holds up to 16 colors for the account, shared across character slots and
all custom editors. The + opens a color picker and disappears when full.
Right-click a Palette color, then click Save to keep it. Right-click a Custom
color, then click Edit to reopen the color picker at that color and adjust it, or
Remove to delete it (Delete while hovering does the same thing). An edited swatch
keeps its place, brushes using it follow it, and paint already drawn keeps the old
color; editing it into a color that's already saved merges the two.
The menus stay open while moving to the action; clicking outside or pressing
Escape dismisses them.

Custom colors save immediately through the normal account preference writer.
Discarding a drawing does not discard palette changes. Removing a swatch does
not remove painted pixels or colors still needed by undo/redo, including the
colors a moved or pasted selection puts down while it waits to be redone. If a drawing has
no room for another color, unavailable Custom swatches stay visible but disabled,
and the Custom title says why.
Themes cannot paint over the swatches; selection uses a border.

Sampled shades, then Custom colors, fill whatever room a drawing's own colors
leave, so a full drawing loses Custom swatches before shades.

The markings canvas shares one palette across every region. Regions may use more
than 63 colors between them, as old saves and imports can: the editor keeps them
all and base marking changes still work, but new colors wait until some are gone,
and a notice under the canvas says why. Each changed region is checked against
the 63-color limit when saving. A region over its own limit is named in that
notice before a save fails; export refuses it, and the preview keeps showing its
saved paint until it's back under.

Each hair editor also owns its base look. A **Base hair** (or **Base facial
hair**) section picks the style and color for this character; the drawing always
stays on top of it. Changing either rebuilds the guide and the palette.
Saving writes the base look with the drawing, so these are the same fields the
character's hairstyle picker sets.

Recoloring the hair moves painted hair shades to the matching shade of the new
color, so a drawing built from the character's own hair keeps its relationship to
it. Saved Custom swatches, and any paint that isn't a hair shade, keep the color
they were drawn with. A shade that can't be told apart from another under the old
color is left alone. Choosing a different hairstyle changes the palette and guide,
but never repaints: each hairstyle has its own shades.

Dyeing or recoloring hair in game does the same to that round's paint, on both the
character and the head itself. A temporary color override, which leaves the
character's own hair color alone, changes nothing. Salon editors also let you
change the base style and color, for yourself or someone else. Opacity, glow and
gradients stay as they were. Someone else's base look changes only after they
approve it in the mirror.

A hair gradient covers the drawing as well as the hairstyle underneath it, for
both hair and facial hair. A **Gradient** toggle appears beside Guide and Grid
whenever the base look has one: turning it off drops the gradient from the guide,
the sidebar preview and the sampled palette, leaving the plain style shades. It
changes nothing that gets saved.

The markings editor owns each region's native markings the same way. The
selected region's section, titled "Left arm base markings" (its tooltip says
"Use any tool on a region to select it."), adds, swaps, recolors and removes them,
in layer order, with the drawing on top. As in character setup, a green **+**
under the rows adds one until the limb is full. As there, without **Allow
mismatched parts** a region offers only markings meant for the body's species, and
the server refuses others; the salon follows the recipient's preference. The taur
region carries no native limb markings, so it has no section. These changes stay in the draft and
support undo/redo. Saving writes them with the drawings. The salon's tattoo
canvas has the same section. Salon work uses the recipient's markings and waits
for their approval; it never edits the artist's character preferences.

**Blending options**, inside the Custom box right under its swatches, starts
collapsed with both options off. Collapsed, its header draws no rule of its own;
opening it adds one between the header and the options.

- Blend with hair color, in the hair editors, multiplies Custom colors by the
  effective hair color, or beard color in the facial hair editor.
- Blend with mutant color, in the markings and tattoo editors, multiplies them by
  the body's primary mutant color.
- Blend with color multiplies them by a chosen color. Its picker starts at white.

The options are mutually exclusive. They use Multiply blending on Custom colors
for new strokes. Palette colors, guide samples and existing paint keep their
RGB. A gradient color saved into Custom follows the same blending rules as any
other Custom color. The selected brush updates after server acknowledgement.

#### Emissive drawings

Every drawing saves its own Emissive setting for each of the four views. The
checkbox edits the current view and defaults off. In the markings editor each
region keeps its own settings, and the checkbox reads `Emissives - (Left arm,
Front)` for the selected region and view; a region with no paint saves as no
drawing, so its settings only count once it has paint. It is independent of the
normal hair emissive preference. The master emissive appearance preference can
suppress glow without changing these saved choices.

Emissive views get glow masks; non-emissive views get blockers. Both use the
paint's masking, clipping, opacity and placement. Unused directions have explicit
blank frames, so a South-only drawing cannot show its mask in every direction.
Attached masks inherit the character's facing and pose through the existing
worn-emissive grouping. Dropped hair uses the dropped head's South-facing path.

#### Saving and loading

Drawings live in `custom_sprites.json` beside the account's `preferences.json`.
The file is loaded lazily and held by the preferences datum. Switching slots
validates and selects that slot's drawings from the loaded data.

| Stored value | Scope and contents |
| --- | --- |
| `characterN.hair` | One custom hair drawing for that character slot. |
| `characterN.limb_markings` | Drawings keyed by `head`, `chest`, `l_arm`, `r_arm`, `l_leg`, `r_leg` and `taur`. Unknown zones are discarded. |
| `custom_sprite_palette` in `preferences.json` | The account's Custom swatches, separate from drawing data. |

A drawing stores `version`, `palette`, `dirs`, `tint` and optional `emissive`
metadata. Direction keys are BYOND's `"2"` (Front/South), `"1"` (Back/North),
`"4"` (Right/East) and `"8"` (Left/West). Missing directions are empty canvases.

Each direction stores palette indexes row by row from the top left. Index `0`
is transparent. An `r` prefix uses run-length encoding: a hexadecimal run length
from 1 to 15 followed by an index character. An `f` prefix stores the flat grid
when compression would be larger.

| Drawing version | Canvas | Opaque colors | Maximum encoded direction |
| --- | --- | --- | --- |
| 1 | 32 by 32, 1,024 pixels | 15 | 1,025 characters |
| 2 | 32 by 32, 1,024 pixels | 63 | 1,025 characters |
| 3 | 64 by 32, 2,048 pixels | 63 | 2,049 characters |
| 4 | 32 by 48, 1,536 pixels | 63 | 1,537 characters |

Version 3 is fixed at 64 by 32 and version 4 at 32 by 48; dimensions are not
supplied by the file. Version 3 is allowed only for taur-zone markings, and
version 4 only for hair, where it always has an explicit color filter. Other zones
remain 32 by 32; the taur zone requires version 3. Only used colors are saved.
The decoder checks lengths, indexes and expanded size before accepting data.

Save and close and Ctrl+S save the drawing; Ctrl+S keeps editing. Closing the
window doesn't save: the draft stays open in memory until you save or discard it.
Slot switches, style or species changes, and closing character setup still save
open drafts, so work isn't silently lost. Markings, augment and randomize actions
in character setup also save and close open editors first, as preference changes
do, so an open draft can't write stale base markings back afterwards. If an open
drawing can't be saved, the change waits: the setting or tab action isn't made,
the editor keeps its error, and chat says why. Discard drops changes since the last
successful save. Deleting a character slot discards its editor
and removes its drawings. Character exports exclude the drawing file;
successful preference imports remove old drawings and their recovery files.

The markings editor saves regions, not a canvas. Opening it composes the canvas
from every region's saved drawing and keeps that composite as the baseline.
Saving splits the canvas back into regions. A pixel is edited when it differs
from the baseline, and for each region:

| Pixel | The region's result |
| --- | --- |
| Not edited | Its saved value, byte for byte, including paint hidden under another limb or outside every region. |
| Edited, and the region owns it | The canvas value. |
| Edited, and the region's arm or hand partner owns it | Cleared, so it can't draw over the new value. |
| Edited, and another limb owns it | Its saved value; that paint is hidden there. |

Clear, an import or a restoration replaces a region outright in the views it
touches: the region's saved paint under other limbs or outside every region goes
too, so it saves exactly what the canvas showed.

A region whose result has no paint saves as no drawing, which is how Clear and
erasing a region's pixels work. Only regions whose pixels, base markings or
emissive settings (while it has paint) differ from their save are written; the
rest aren't validated, rewritten or rotated. Every changed region is validated
first, then all of them are applied with one sidecar write. If that write fails,
every region rolls back and the draft stays open. Their base markings are then
published, and the character and `preferences.json` are saved once. Previous
saved styles still rotate per zone (`markings:l_arm`), and only for regions an
import or restoration changed. The saved canvas becomes the next baseline.

The sidecar writer uses rust-g and caps the file at 16 MiB. This accommodates the
100-slot account limit with all nine drawing targets and a previous saved style
for each, including both wide marking targets. A clean, unchanged save does no
disk write. For a changed file it:

1. Writes the new JSON to `.new` and reads it back to verify the full contents.
2. Makes sure `.bak` contains the last verified revision.
3. Writes and verifies the main JSON file.
4. Removes deleted slot entries from the backup before reporting success, then
   clears the dirty state and removes the staging file.

Loading a missing or unreadable main file falls back to `.bak`. If neither copy
is readable, saving is refused so the existing files are left intact. Failed
saves keep the draft in the editor and show an error instead of Saved. The saved
drawing and history in preferences are restored. Retry the draft to save it;
saving a different drawing cannot accidentally publish the rejected draft.

Replacement is not atomic. A crash during a write can recover the previous
revision, so the last attempted edit is not guaranteed to survive. These checks
apply to the drawing sidecar; Custom swatches use the existing preference writer.

#### Rendering and caching

Preferences copy drawings onto DNA. Hair gets its own head snapshot; each marking
zone gets its own overlay on its limb. DNA copies use independent
lists. Limb update signals handle regenerated or replaced parts, while detached
parts retain their appearance. Ordinary markings clip to limb geometry and split
across the normal leg layers. They do not draw on husks or invisible taur legs.

Taur-zone paint is an overlay attached to the chest. It draws just above each of
the external organ's native layers, so the organ never covers it whichever of the
two the chest took last, and uses the organ's directional silhouettes and
visibility rules, with a 64 by 32 icon centered at offset -16. Matrixed accessory
layers contribute their original alpha to the mask. Glow and blocker masks keep
the same width, layers and offset. Organ gain/loss signals update these snapshots.

On the first render of a drawing, its pixel data is decoded and painted directly
into a BYOND icon as horizontal runs. This needs no temporary workspace or files.
All four views are present, including blank ones. Later renders reuse the icon
by its content hash. Turning uses the icon's existing direction frames.

| Cache | Key |
| --- | --- |
| Raw paint icons | Canvas width, palette and encoded direction data. |
| Clipped limb, taur and split-leg icons | Paint content, native geometry and relevant layer. Taur keys include the organ's current render key and chest gender. |
| Directional glow/blocker icons | Paint/mask geometry and the enabled directions. |
| Sampled palettes | Source icon file and state. |
| Body/zone editing masks | Canvas width, zone and contributing limb geometry; taur geometry includes the organ's current render key and chest gender. |
| Region maps | Canvas width, the present regions, each region's editing mask and the taur organ's render key. |

Each of these caches is shared server-wide and capped at 256 entries, with the
oldest inserted entry evicted first. Cached icons and lists are treated as
immutable. They are runtime caches; the JSON is what persists across restarts.
Drawing tint, marking opacity and emissive choices do not rebuild raw paint or
clipped pixels, but final appearance keys include settings that affect the result. Hair
still takes a private copy for its masks and final overlay assembly.

The editor renders strokes locally. Server previews wait for a 0.6-second pause
and skip unchanged drawings. Guides and previews are drawn for all four views
from one flatten of the look (a universal icon walk, stamped with each view),
which iconforge draws as a PNG per view in a few tenths of a millisecond each.
The view the window shows is drawn in the action that changed it, and the other
three in the subsystem's next run, so turning to another view shows its picture
at once. The recipient's approval mirror draws all four views when it captures
the look, and import and restore previews draw all four too. Encoded pixels
are cached until paint changes; metadata changes reuse them. Guide and preview PNGs are
editor-owned data URLs, with no global asset/CDN registration. Each editor keeps
its pictures' files in `tmp/` under its own name, overwriting them with each new
drawing, since making and deleting a file costs more than drawing the picture,
and deletes them when it closes. The browser
reuses decoded guides, cached shading geometry and unchanged drag previews. Only
the opened drawing is sent to its editor. The canvas travels as a palette of its
pixel values and one index string per view: one character per pixel, or two once
a canvas holds more than 64 values. A stroke re-encodes only its own view. An
appendage layer is encoded only in the view the window shows, and adding or
removing one leaves the other layers' index strings as they are.

Idle windows don't resend drawings. Hairstyle and native-marking choices,
guides, the paintable mask and the region map are static UI data, and the sorted
hairstyle lists are shared. A rebuild or a lock change sends them in one full
update. So does showing a view for the first time after the window opens or
rebuilds, because its guide is static data. Picking a palette color or a region doesn't update the window, which
already shows it. Refreshes never bring the window forward; only opening it
does. Salon guides listen for the recipient's worn-overlay changes, including
adjusting clothes already being worn. Changes within a second share one refresh
and one UI update. Held items are left out of salon guides and mirror pictures,
so picking things up or dropping them redraws nothing. Equipment changes still
relock regions and views at once. Clothing changes reuse the preview body; hair,
anatomy and underwear changes rebuild it. Picking up or dropping a mirror
updates self-styling locks immediately. Those locks restrict editing without
clipping existing paint out of the draft.

#### Server load and hostile windows

`SScustom_sprite_work` draws the guides, previews and resource rebuilds noted
above every 0.1 seconds, using tick time other subsystems leave over. Actions
only change the draft and mark work; bursts draw once for their final state.
The per-view cache and 0.6-second preview pause described above still apply.

Whole-body markings previews are composed rather than flattened. Each view of the
body without paint is flattened once per rebuild into three slices: under body
paint, between body and hand paint, and over hand paint. A preview is those
slices with the canvas pixels between them, each at its limb's marking opacity,
which matches flattening the painted body exactly. The slices and the paint go
to iconforge as one recipe per view, the paint as boxes of colour. Only views
whose pixels changed are drawn again. A taur, a tinted or translucent body, or a canvas over
the shared colour limit falls back to flattening the painted body.

Floating selection previews reuse those same rendering paths. The window sends
one compact placement when a gesture finishes, never on pointer movement. The
server retains only the latest request, capped at the canvas's pixel and palette
sizes, and validates colors, coordinates and region locks through the ordinary
selection-placement validator after the 0.6-second pause. It copies only the
changed view for the preview; authoritative pixels and history stay untouched.
A new gesture, cancellation, a real draft edit, a view change or changed region
locks clears the temporary picture.

Toggling parts, underwear or the gradient, changing the base hair, base markings,
undo or redo across a base look change, confirming an import and the salon's
clothing refresh apply their change at once and rebuild resources in the
background; changes that come while a rebuild waits end on their latest state.

Rebuilds, new editors and Restore previous saved style previews cost tens of
milliseconds each, so they share one pace per player, across all their editors.
Up to four run half a second apart, and each one used comes back after a second
and a half. A few changes in a row never wait more than half a second, while
changes that keep coming faster than that get one rebuild every second and a
half, always for the latest state. An editor opened too soon opens by itself
when the pace allows, and reopening a window then rebuilds in the background.

A rebuild that needs a new preview body takes two of the subsystem's runs: the
first builds the body, the second draws the guides and the preview on it, so
neither run holds the server for long. Until the second run the window keeps the
pictures it had; nothing goes blank. A change that arrives between the two runs
makes the second build again on the latest state, when the pace allows.

Across players, the subsystem charges that costly work (building a body, drawing
on it, a restore's previews) for what it runs past the ends of ticks, and while
that has come to more than 150 ms of each second, new costly work waits for the
budget to refill, which it does whatever the server does, so waiting work always
gets its turn. Work that ends inside its tick costs nothing, so a lone editor
never waits on it. A body's drawing goes on the very next run, since a body left
waiting would be thrown away for any change after it; what it runs over is
charged too. Measured in DreamDaemon with every player's whole-body editor open,
painting a stroke a second and changing the base look every 3 seconds for 20
seconds, far more than players do: 60 editors on humans ran the server at 1.11x
with 246 of 400 ticks over without the budget, and at 1.06x with 93 over with
it, their base looks catching up in a median 1.0 s rather than 1.9 s; 60 fully
painted lizards, 1.19x without it and 1.15x with it, the most it allows. What
still runs over is the windows' updates and preview refreshes, which it doesn't
count. Up to 30 fully painted editors keep the server within 3% either way, and
one editor's base look still redraws in about 0.2 s.

iconforge keeps each picture it draws, about 28 KB of one, until it is told to
let go (measured replaying 3,000 of the editors' recipes). The pictures count a
tenth of a character preview's drawing each toward the letting go that the
character preview does (`iconforge_drawn()`), so painting alone never makes
the server's memory grow for good. The first pictures after it cost about half
a millisecond more.

A restore that has to wait says "Wait a moment before trying that again."; restores
also wait while a preview is waiting for an answer.

An import or a restoration shows its card at once and draws its previews in the
background, so the window says "Drawing the preview..." for a moment before
they appear. Previews are kept per editor for the last few candidates drawn on
the same body, so restoring the same style again shows them at once.

Undo and redo take at most ten steps per action; windows only ever send one.
The history keeps its last 100 steps or its last 40,000 recorded pixels,
whichever runs out first, so whole-canvas pastes can't hold megabytes of history
each. Ctrl+S on a draft that hasn't changed since its last save is acknowledged
without writing. Imports and exports keep their own cooldowns.

A base hairstyle change applies at once. Styles picked in the half second after
one applies wait, and only the latest applies when that half second ends, so a
burst of picks lands at most twice and skips the styles in between, such as
growing into the tall canvas and straight out again. The style list shows the
latest pick throughout, and anything else the window does, closing it or
saving included, first applies the pick that is waiting. The half second is the
rebuild spacing, so the preview never updates less often than it already could;
picks half a second apart or slower all apply at once. A player's hair and
facial hair editors share the window. A new hairstyle never recolors paint (only
a new color on the same style does), so its undo step records just the old and
new look: the paint, its appendage layers, the window's canvas and the rest of
the history stay as they are.

Pencil and eraser strokes travel as a bit mask of the canvas, one character per
six pixels, so a stroke across a whole view is a single short message instead of
a point list split into many (a long stroke used to be cut off by the per-second
message limit). The server refuses a mask whose length doesn't match the canvas
or that marks a pixel past its end. A placed selection can't bring more values
than pixels it covers, and each distinct value is checked once however often it
repeats. Every action's parameters are validated before any icon work, and
malformed input is refused without drawing anything.

A player's strokes and placements apply inside the action while they stay under
6,000 pixels a second, four full tall-canvas strokes, far more than a hand
paints; a fill counts the pixels it filled. Past that they wait in order for the
background subsystem, which applies them within its tick budget; the canvas
already shows them, and the window gets no update until they're all in, so
nothing it shows is ever overwritten by an older picture. Only a queue of fifty
strokes, which no person reaches, refuses further strokes, with a quiet notice
until the queue drains. While strokes wait, the server takes only two things
from the window, more strokes (moves, pastes and fills included) and view
switches, which the drain's update then shows, so history and saves keep their
order: anything else it asks for, such as undo, Clear, the eyedropper, Save or a
base look change, is ignored until the update the drain sends shows where things
stand. If character setup saves the editor meanwhile, for a setting change or a
slot switch, the editor keeps its draft unsaved, as after a failed save, and
says "Your last strokes are still going in. Save again in a moment." Under the
budget none of this happens.

#### Older saves and limits

Version 1 and 2 drawings still load at 32 by 32. Wide paint is never silently
shrunk into a narrow editor. The whole-body marking was removed: a slot's old
`markings` drawing and its previous style are ignored on load and dropped the
next time that slot's drawings are saved. A legacy
single emissive boolean applies to all four views; missing emission settings
default off. Explicit saved whole-drawing
tints are baked into the editor's literal colors on opening, preserving their
rendered result. They are written back only through the usual save path.

Legacy hair with no explicit `tint` still goes through the old hair color and
gradient rendering path. It has not been automatically converted: gradients can
produce more colors than the 63-color format allows. New paint in one of those
old drawings can still inherit that filter. New drawings use literal colors.

| Limit | Value |
| --- | --- |
| Drawing size | 32 by 32; the taur-zone canvas is 64 by 32 and tall hair 32 by 48. Four directions. |
| Drawings per character | Eight targets: hair, six limb zones and the taur zone. |
| Saved Custom swatches | 16 per account. |
| Colors in one drawing | 63 opaque colors, plus transparency. Undoable colors also reserve room. |
| Undo history | 100 actions or 40,000 recorded pixels per open custom editor, whichever runs out first (about 25 whole-canvas placements); one undo or redo action takes at most 10 steps. |
| Background work | A player's rebuilds, new editors and previous-style previews share one pace: up to four half a second apart, each coming back after 1.5 seconds, so nonstop work gets one per 1.5 seconds. Across players, what such work runs past the ends of ticks stays within 150 ms of each second. |
| Drawing sidecar | 16 MiB per account, supporting up to 100 slots with all targets and their previous saved styles. |
| Animation and extra canvas layers | Not supported by the custom editors. |

#### Custom haircuts and tattoos

Players can also draw hair and tattoos for each other. Both use the same editor,
tools, palette, history and renderer as character preferences; only the context
changes.

- Scissors: aim at the head and pick **Custom Style**, then hair or facial hair.
  Ordinary haircuts and facial hair are unchanged. Bald heads and shaved faces can
  get custom drawing too, and the scissors offer it directly for someone with
  neither.
- Custom hair is hair, and custom facial hair is facial hair, even over a Bald or
  Shaved base style: brushing, hair ties, scissors, razors, a mirror's beard shave,
  the shearing rod, and radiation or shedding hair loss all treat them that way.
  Shaving, a cut down to Bald or Shaved (scissors or the syndicate mirror), the
  shearing rod and hair loss take the drawing off for the round with the hair; any
  other cut leaves the paint on top of the new style. Wigs copy named hairstyles
  only, so a wig can't copy custom hair.
- You can use either tool on yourself. Working on your own body skips the request
  and the mirror approval, and applies as soon as the timed work finishes; it
  awards no achievements, the window drops the reminder to stand next to the
  recipient, and every message addresses you rather than naming you. A self haircut can also change your hairstyle and hair
  color from the editor's Base hair section.
- Views you can't see need a mirror: the Back view is locked unless you're
  holding a handheld mirror or standing within a tile of a mounted mirror. A hand
  mirror dropped at your feet doesn't count, and a wallframe still waiting to be
  hung isn't a mirror yet. Picking one up, putting it down or walking to a mirror
  locks and unlocks that view immediately, without reopening the editor. The
  lock is rechecked when you finish and again when the finishing touches end, so
  putting the mirror down refuses that change rather than applying it. The barber
  locker and vendor stock one.
- `/obj/item/tattoo_machine`: use it on someone to open the whole-body canvas on
  their current look. There's no zone to pick: draw anywhere on the body, and only
  the regions you change are proposed. It's reusable, needs no ink and works for
  anyone holding it. The barber locker has one and the barber vendor stocks three.

If the recipient has a previous round style for that target, the tool first asks
whether to draw something new or **Restore previous**. For a tattoo with more than
one region to restore, it then asks whether to restore the whole body or one
region. The whole body leaves out regions that can't be tattooed right now, such
as covered ones, tells the artist which and why, and restores the rest.
Restoring only such a region is refused with the reason.

The flow:

1. The recipient gets a prompt: **Continue** or **Decline**. When they already
   have a drawing there, **Export current style and continue** downloads it to
   the recipient first. Prompts expire after 120 seconds.
2. The artist's editor opens on the recipient's current look. Hair adds to the
   current haircut; a tattoo starts with every region's current paint and base
   markings, read from the body. The artist's guides and previews show the
   recipient's whole body, dressed as they are. The window is titled for the
   work and the person, such as "Custom Tattoo for Leia", from the moment it
   opens.
   Drawing, erasing or filling plays a work sound immediately, with a five-second
   cooldown for snips and twelve seconds for the pitch-varied tattoo needle.
   Tattoo ambience stays on while drawing and lingers for three seconds after
   the last brush movement. An idle window is quiet. Sounds come from the artist
   and stop when the editor closes. Brush activity sends at most one small
   message a second; it doesn't send pixels or trigger UI updates.

   Regions the recipient can't be tattooed on right now are greyed out under
   scanlines and can't be selected, painted, cleared or given base markings. That
   means regions their clothing covers, husked limbs, a hidden taur body, limbs
   that are missing or were replaced since work started, and regions whose look
   changed on the body since then. The window's status line gives the reason for
   a greyed-out selection. Putting clothes on or taking them off, or rolling a
   jumpsuit up or down, updates this at once.
   Paint already drafted in a region stays there, visible under the scanlines,
   until it's free again. Undo and redo still step through your own history, and
   finishing never applies a region that's greyed out. The canvas keeps the
   regions it opened with, so a limb attached later needs a new draft.
3. Drawing doesn't need the artist to stay nearby. Closing the window keeps the
   draft, and using the tool in hand (**Resume custom work**) reopens it with the
   Pencil selected. Ctrl+S shows "Draft saved for this round" and writes nothing
   to disk. Discard draft asks for confirmation.
4. **Finish** needs the artist next to the recipient, holding the tool. It opens
   the recipient's mirror: Front, Back, Right and Left, a draggable Before/After
   divider, **Accept for this round**, **Accept permanently**, **Export** and
   **Decline**. For a tattoo it also names the regions that change, for example
   "This changes: Torso, Left arm." Export downloads the reviewed design without
   accepting it. The
   usual TGUI countdown bar shows the time left; expiry still declines on the
   server. The images are sent separately from the small countdown updates, and
   redrawn when the recipient's look changes while they decide, so both pictures
   show them as they are.
5. Accepting starts five seconds of finishing touches for custom hair, facial
   hair and tattoos alike. The drawing was the work. Snips or tattoo sounds and
   ambience play during these finishing touches too, and stop on completion or
   interruption. The recipient is told "Try not to move!", since moving
   interrupts them. The artist's editor stays open under the theme's loader,
   which fills over the five seconds under "Applying finishing touches…". Finished
   work closes the window; work cut short says "Interrupted!", fades, and leaves
   the drawing as it was. The change is applied only if everything still checks out
   when those five seconds finish. Ordinary haircut options keep their normal
   timings.
6. **Accept permanently** saves after successful application, using the same
   character-slot checks and safe save path as **Save for future rounds**. The
   replaced saved style is kept as the previous style. An interrupted application
   saves nothing. A successful save says nothing more; a failed one leaves the
   accepted look applied for this round and reports the error in chat. There's
   no second prompt for someone else's work: you already chose whether to save.
   Self-styling still shows **Save for future rounds** and **Done** afterwards,
   since it skips the approval mirror. Export belongs to the approval prompt; it
   isn't repeated here. The mirror uses your chosen UI theme.

The recipient must accept the start and the exact finished design. Closing or
letting the mirror expire declines. Any edit withdraws a pending mirror.
Declining, a failed check or an interrupted timed action returns to drafting with
the paint kept.

Each artist account keeps one draft per drawing target and person for the round,
including across reconnects: hair, facial hair and tattoos are separate, and so
is each person, so starting a tattoo never threatens a haircut or someone else's
tattoo. Starting the same drawing on the same person again asks whether to keep
that draft, export and discard it, or discard it; **Keep it** reopens that exact
draft. The tool in hand decides what it can resume, and asks which when it
matches more than one. Preview bodies and guides are released while the window is closed and
rebuilt on resume.

`/datum/custom_sprite_salon` owns the session. It holds weak references to both
players and the tool, the reviewed proposal, and each drawing's starting look and
bodypart: one for hair, one per region for a tattoo. The taur region also binds to
the external taur organ. A tattoo's proposal carries a package for each region the
draft changes (a touched region); regions it doesn't touch may change freely. Its
states are drafting, awaiting approval, applying and completed.

- Starting needs two different connected players, a human recipient, adjacency,
  the right tool in hand, and a reachable target. Hats that hide hair block
  hair work, so clothing never hides the part being worked on. Tattoos use worn
  clothing's coverage flags per region, so a rolled-up jumpsuit exposes the arms
  and gloves only cover the hands. A tattoo can start while any region can take
  one.
- Editing only checks that the artist's account owns the draft.
- Finish, accept and completion each recheck both players and their controlling
  accounts, consciousness, the held tool, adjacency, reachability, bodypart
  identity and the target's appearance since work started. For a tattoo these
  checks cover only the touched regions.
- Approval binds to a token for one immutable copy of the reviewed revision.
- One incoming prompt per recipient, and a ten-second cooldown per artist and
  recipient pair.
- A new haircut, replaced limb or taur organ, changed drawing, body transfer or
  different controlling player invalidates the work. The draft stays available
  to export.
- Completion runs once. Replayed or stale actions do nothing.

Unchanged submissions are rejected. Salon hair imports may change the style and
color, but keep the recipient's opacity, glow and gradients. Tattoo imports use
the same Whole body or region prompts as character setup, may carry native
markings, and skip regions that are greyed out, naming them. Imported changes go
through the same draft, preview and approval as changes made in the editor.

Salon guides and previews show the whole body, wearing what the recipient is
actually wearing, so the artist works on the person in front of them. Dressing or
undressing rebuilds them within a second. Marking guides leave hair, wings, tails and
other hanging parts out, so they can't cover the limb; the **Parts** toggle in the
visibility tray puts them back on. The preview body only loses them while the guides
are drawn, so previews always show the whole look. Hair editors keep those parts
visible and don't offer this toggle.
A taur body always stays, since
it carries a drawing of its own. The area that can be painted still follows the
drawing's own bounds, which are taken from the limb itself and don't change with
this toggle.

Preview bodies are private dummies built from the recipient's live appearance:
species, features, bodyparts (including customized limb sprite files), markings,
hair and underwear settings. Tattoo masks use that same full limb geometry as
character setup. They don't
use `generate_dummy_lookalike()`, which reapplies saved preferences, and they
don't copy inventory, minds, quirks or effects. Guides and mirrors add the
recipient's worn appearances using the same layer set as worn-emissive
rendering, except held items.

Donor parts keep their own skin, native markings and drawing snapshots in the
preview. Taur dummies copy the actual organ's accessory, colors, visibility and
pose, then the chest's independent taur-zone paint snapshot.
Drafts, exports and history read the attached head, limb or taur-zone overlay's
drawing. Hair also uses the head's visible gradient and opacity.
Native species opacity stays implicit; an opaque donor head keeps its explicit
255 opacity even on a naturally translucent recipient.

The artist's hair preview masks the body before adding the prepared hair layer.
Buns and other allowed extensions remain visible outside the original hairstyle,
with the same color, opacity and placement as the recipient's preview. Guides
temporarily hide paint, redraw the limbs without it, and then restore the existing
snapshots.

Application updates only the head layer, or only the touched tattoo regions,
leaving unrelated donor parts alone. A tattoo's regions go on together, with one
redraw of the body. DNA also records the change for regenerated
limbs. Each drawing keeps one previous round style on the body: hair under its
target, each tattoo region under its own key (`markings:l_arm`), including an
explicit empty drawing and, for hair, the base look. Restoring swaps them, so it
can be reversed the same way. Restoring never saves; saving is still the
recipient's separate choice.

Achievements go to both players after a successful, changed application between
different players, once per application however many regions it changes.
Imports, previews, restorations and failed attempts don't count.

| Achievement | Database ID | Trigger |
| --- | --- | --- |
| Barberella | `Custom Hairstyle Given` | Apply an accepted custom hairstyle. |
| I'm Just a Boy with a New Haircut | `Custom Hairstyle Received` | Receive one. |
| Leave Your Mark | `Custom Tattoo Given` | Apply an accepted custom tattoo. |
| Fresh Ink | `Custom Tattoo Received` | Receive one. |

#### Import and export

Both editor contexts have **Import** and **Export**. Export downloads the current
draft without saving it. The recipient's approval mirror can export the reviewed
proposal without accepting it.

In the markings editor, **Export** asks whether you mean the whole body or just
the selected region, naming it. A region export is the single-target file below,
holding that region's would-be-saved drawing and base markings. **Restore previous
saved style** asks the same: every region whose previous style differs, or just the
selected one. Both then use the usual preview.

A file holds one drawing target:

```json
{
  "format": "aphelion-custom-style",
  "version": 1,
  "target": "markings",
  "zone": "l_arm",
  "drawing": { "version": 1, "palette": [...], "dirs": { "2": ..., "1": ..., "4": ..., "8": ... }, "tint": "#ffffff", "emissive": { "2": 0, ... } }
}
```

Hair files use `"target": "hair"`, have no zone, and add `hair`: `style`, `color`,
`gradient_style`, `gradient_color`, `opacity` (40-255, or null) and `emissive`.
`drawing` is null for empty art. Exports never contain account names, slots,
paths, runtime references, other preferences or recovery history.

A whole-body file wraps region packages under `"target": "body"`:

```json
{
  "format": "aphelion-custom-style",
  "version": 1,
  "target": "body",
  "regions": { "l_arm": { "drawing": { ... }, "markings": [ ... ] } }
}
```

Each region entry validates exactly like a single-target package for that zone.
Importing one replaces the regions it contains; the preview lists them, and lists
regions this body doesn't have, or that are greyed out in the salon, as skipped,
with the reason. A single-target file replaces its
own region, and a legacy drawing-only file goes into the selected region; the
taur region centres an old 32-wide one, as its single-zone editor did.
Confirmed regions replace the old ones outright: neither the file's paint nor the
old paint under other limbs on this body is kept. Hair editors refuse one.

Import shows a preview first. **Replace draft** is one undoable action that also
covers the hair look; Cancel changes nothing. Strictly valid old drawing-only
files still import into the open editor and keep its current hair look. Their
emissive flags may be numeric 0/1, as written by the old save format.

The server enforces the import boundary:

- 160 KiB maximum, checked before the file is read, and 32 KiB for anything but
  a whole-body file. BYOND has already received the upload by then. The existing `/client/AllowUpload()` separately enforces
  `upload_limit` (512 KiB by default) or `upload_limit_admin` (5 MiB by default).
- `rustg_json_is_valid()` before `json_decode()`, so malformed or deeply nested
  JSON never reaches BYOND's decoder. The file must hold a top-level object.
- Exact field sets and value types. Emission flags may be true/false or 0/1.
  Account sidecars, other formats and versions, and unknown fields are refused.
- Four views at the drawing version's fixed size: 32 by 32 for versions 1/2,
  64 by 32 for version 3, or 32 by 48 for version 4. Wide drawings are limited to
  taur-zone markings, and taur-zone drawings must be wide; tall drawings are
  limited to hair. Markings without a body zone are refused. The color and run limits remain
  strict. Nothing is salvaged: one bad view rejects the file. A non-null drawing
  with no paint is refused, so bad data can never act as Clear.
- Hair files may carry up to three appendages, numbered from 1 in order, each
  with exactly its five fields, a name already in its cleaned form, one known
  zone, a 0/1 kind, paint in the drawing's palette and its own emissive flags.
  Errors name the appendage by number, never by its uploaded name.
- Registered, unlocked hairstyles and gradients, character/species eligibility,
  opacity access, and the destination's emissive setting. The last preferences
  tab opened does not affect eligibility.
- Paint outside the destination's bounds or limb silhouette is refused, naming
  the view.
- One transfer per account at a time. Imports have a five-second cooldown and
  exports two seconds; failed attempts use the cooldown too.
- Owner, slot, session and draft revision are checked again after the file
  dialog returns.

Exports use a server-generated name in `data/custom_style_exports/` and are
deleted immediately. Logs record the account, byte count and rejection reason,
never file contents.

#### Previous saved styles and complete hair saves

Each character slot keeps one previous saved package per drawing target in the
sidecar's `previous_styles`. Only import, **Restore previous saved style** in the
preferences editor, and a salon save replace it, and only when the saved style
actually changes. Strokes, Ctrl+S and ordinary save and close don't, and neither
does an import or restoration that was undone before saving. Undoing one also
leaves emission changes made since on other regions alone.

**Restore previous saved style** opens the old package as a preview, the same way
as an import. It only appears while the draft differs from that style, so it
disappears once it has been restored and returns if you undo. The offer is
worked out with the preview after a pause and after saving, not on every window
update. Saving it swaps current and previous. Deleting a slot removes its
previous styles; preference imports remove them with the rest of the sidecar.

A salon save writes to the character slot selected in character setup. A tattoo
save writes only the regions the tattoo changed, in one write. A body that
records the slot it spawned with must have that slot selected; bodies created by an
admin record none and save normally. The slot must belong to the same character
name, have no open editor for that drawing (for markings, the whole-body editor), and have no unsaved changes to the
same base look in character setup, including hair opacity or that limb's native
markings. Otherwise the save explains why and
the round appearance stays.

Hair packages contain the complete hair look listed under [Import and export](#import-and-export),
including the drawing's emission. Species, facial hair and equipment are excluded.

A supported limb or hand package can also contain `markings`: an ordered array
of known marking names, hex colors and boolean emission flags. It uses the
existing per-limb limit and rejects duplicate names or unknown fields. An empty
array clears that zone's native markings. Older files without the field keep the
destination's current markings. Previous styles retain the native markings too.
Changing the base look writes two files. The drawing goes to `custom_sprites.json`
first, through the verified sidecar writer above; if that fails, nothing changes.
The base look is then published to the character and written to
`preferences.json`. A crash between the two writes can only leave the new drawing
on the old base look, and saving again fixes it.

#### Tests and maintenance

Native tests live in `code/modules/unit_tests/~nova/custom_sprites/` and are
included from `code/modules/unit_tests/_unit_tests.dm`, which provides
`TEST_ASSERT` (it stops at the first failure, so anything a later test depends
on is released in `Destroy()` or through `allocate()`). One file per area:
`codec.dm`, `save_compatibility.dm` (old-format drawings and sidecars load and
write back exactly as before), `persistence.dm`, `saved_styles.dm`,
`transfer.dm`, `composite.dm`, `regions.dm`, `workspace.dm`, `editor.dm`,
`markings_editor.dm`, `appearance.dm`, `salon.dm`, `tall_hair.dm`,
`lifted_hair.dm`, `region_selection.dm`, `selection_placement.dm`,
`blending.dm`, `taur_paint.dm`, `hair_interactions.dm`, `palette.dm`,
`appendages.dm` and `hardening.dm` (deferred drawing, the per-player pace, the
hairstyle window, stroke masks, placements, kept colours and the safeguards in
Server load and hostile windows). Each test's `///` says what it pins. Keep
temporary `TEST_FOCUS` entries out of committed source; there is no separate
build command for this module, `BUILD.cmd` is the normal Windows entry point.

`tools/custom_sprite_harness/` is not part of any build. Its `run.sh` builds the
game with `harness.dm` appended and walks the in-game checklist for hair
appendages the way a window drives the editor, then replays each step as a
hostile window at tgui's topic limit, and writes what each step and attack cost,
with the procs behind anything over budget, to
`data/custom_sprite_harness/report.md`. Its README gives the budgets.

From `tgui/`, the focused UI checks are:

```powershell
bun test packages/tgui/interfaces/common/CustomSpriteEditor packages/tgui/interfaces/CustomSpriteMirror.test.tsx packages/tgui/interfaces/common/SpriteEditor packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.test.tsx packages/tgui/layouts/Window.test.tsx
bun run tgui:tsc
bun run tgui:build
```

The UI tests sit beside the code they cover: the Select tool and its keys,
stroke masks, the editor window (sampling, saves, views, regions, blending,
the tall canvas, closing with floating paint), the palette menus, the mirror
and the character setup buttons. Keep each tgui test file under 50 KB: Bun
1.3.13 serves larger files from its runtime transpiler cache and then parses
`transparency_checkerboard.svg` as JSX from the second run on.
`tgui/packages/tgui/__mocks__/` holds the shared editor fixture, setup and
rendering helpers. They sit outside `interfaces/` because the interface bundle
takes in every non-test file there. Native icon tests and
browser fixtures do not cover every live-client case: check real drawing and
dragging, hats, turning and resting, limb changes, save/relog and slot/import
behaviour in DreamSeeker when changing those paths.

### TG Proc/File Changes:

These are the core hooks this module needs. Existing-file edits use
`APHELION EDIT` markers with their original code retained. New UI files start with
`// THIS IS AN APHELION UI FILE`.

| File | Procs or declarations changed |
| --- | --- |
| `code/__DEFINES/sprite_editor.dm` | Adds `SPRITE_EDITOR_TOOL_SELECT`. |
| `code/__HELPERS/icons.dm` | `getFlatIcon()` accepts optional `clip_bounds` in appearance coordinates. The custom editor fixes the output origin and size even with nested wide overlays; callers that omit it keep the existing behavior. |
| `code/datums/dna/dna.dm` | `/datum/dna/copy_dna()` copies all three drawing fields and synchronizes the recipient. |
| `code/modules/client/preferences.dm` | `/datum/preferences/Destroy()` closes editors and deletes the sidecar datum; `ui_close()` saves editors before removing the preview. |
| `code/modules/client/preferences_savefile.dm` | `switch_to_slot()` finishes the old slot's editors; `remove_current_slot()` discards editors and removes that slot's drawings. |
| `code/modules/mob/living/carbon/carbon_update_icons.dm` | `/mob/living/carbon/update_body_parts()` still reaches forced hair/eye refreshes when the limb icons themselves are unchanged. |
| `code/modules/surgery/bodyparts/head_hair_and_lips.dm` | `/obj/item/bodypart/head/copy_appearance_from()` snapshots hair and facial hair paint; `get_base_hair_overlays()` and `get_base_facial_hair_overlays()` apply it without modifying the shared accessory icon, add its separate masks, and use `custom_sprite_hair_accessory()`/`custom_sprite_facial_hair_accessory()` so bald heads and shaved faces can carry paint. Nova's emissive hair glows from the hair overlay's own state; hair sheets have no `_e` states. `/mob/living/carbon/human/set_haircolor()` and `set_facial_haircolor()` are overridden in `code/appearance.dm` to recolor painted shades. |
| `code/modules/sprite_editing/workspace.dm` | `/datum/sprite_editor_workspace/copy()`, `new_transaction()`, `undo()`, `redo()`, `can_transact()`, `preprocess_new_transaction()`, `transact()`, `reverse_transact()` and `to_icon()`: preserve workspace configuration, validate/sanitize commands, support selection patches, repair layer/history handling and safely export runtime icons. |
| `code/modules/art/paintings.dm` | `/obj/item/canvas/Initialize()` enables Select alongside its existing tools. |
| `code/modules/mob/living/carbon/human/_species.dm` | `/datum/species/handle_radiation()` counts custom hair as hair to lose; `go_bald()` takes custom hair and facial hair off. |
| `code/datums/diseases/advance/symptoms/shedding.dm` | `/datum/symptom/shedding/Activate()` counts custom hair at its last stage; `baldify()` takes it off when going fully bald. |
| `code/game/objects/structures/mirror.dm` | `/obj/structure/mirror/change_beard()` offers to shave custom facial hair and takes it off. |
| `code/modules/projectiles/guns/magic/wands/wand_bald.dm` | The shearing rod's `do_suicide()` and `/obj/projectile/magic/bald/on_hit()` count custom hair; a hit shears it off. |
| `code/modules/modular_computers/file_system/programs/nanopaint.dm` | `/datum/computer_file/program/nanopaint/ui_act()` forwards history counts; `write_to_file()` and `save_file()` preserve the old image or remove a newly created empty file when export fails. |

The shared workspace's bounds, selection-patch and sanitization helpers live in
this module. Keeping the core calls in place preserves validation and history
ordering for every SpriteEditor user.

### Modular Overrides:

All paths here are relative to this module unless stated otherwise.

| File | Types, overrides and owned behavior |
| --- | --- |
| `code/editor.dm` | `/datum/config_entry/flag/disallow_custom_sprite_editing`; `/datum/preference_middleware/custom_sprites` implements `get_ui_data()`, `apply_to_human()`, `pre_set_preference()` and `on_new_character()`. `/datum/custom_sprite_editor` owns the window, draft, palette actions, guides, previews, import/export and candidates. It is the preferences context; its context hooks include `initial_package()`, `create_preview_body()`, `emissives_allowed()`, `hair_context_problem()`, `render_overlays()`, `draft_changed()`, `context_act()`, `context_ui_data()` and `update_restorable()`. Markings requests go to the whole-body editor through `markings_editor()`, and static data carries the background tiles. Guides and previews are drawn for every view from one walk: `render_guide()` and `render_preview()` draw the view the window shows and leave the others to `draw_waiting_views()` in the next deferred run, `draw_previews()` draws a set of views, `publish_picture()` makes a drawn file the window's data URL, and `guide_icon()` loads a guide for reading its pixels. `setView` calls `request_view()`, and `run_deferred_work()` dispatches `render_guide()` and `render_preview()`. Guides, the mask and the region map are static data, sent when `static_dirty`. Captures `cover_appearance` in `rebuild_resources()` and publishes `cover_rows` as the static `coverMask` with each view's guide. |
| `code/markings_editor.dm` | `/datum/custom_sprite_editor/markings`: the whole-body window, region selection and focus, per-region emissive, Clear and base markings, changed-region saves, previews, export/restore prompts and region imports. Also `custom_sprite_apply_region_results()`. Context hooks `reference_packages()`, `locked_regions()` and `map_follows_body()`; region locks shade and refuse locked regions. |
| `code/regions.dm` | Present regions in draw order, region ID colors, the cached per-view region map composed through the real overlay types, region lookup and the paintable mask. `custom_sprite_merge_cover_rows()` blends body and hand covers by region owner. |
| `code/composite.dm` | Composes region drawings into one canvas and splits an edited canvas back into per-region drawings by the save rule. |
| `code/salon.dm` | `/datum/custom_sprite_salon` session over a set of drawings (one for hair, one per region for a tattoo), request/restore procs including the whole-body-or-region restore choice, live style packages and preview dummies, five-second round application of the touched drawings, optional approved save and per-drawing history on `/mob/living/carbon/human`. Brush sounds and the salon's window actions live on the session. `/datum/custom_sprite_editor/salon` (hair) and `/datum/custom_sprite_editor/markings/salon` (the tattoo canvas, which locks regions the recipient can't be tattooed on) inherit shared context, authorization and lifecycle hooks through the base editor's optional typed `session`; permanent salon context guards detached sessions. They specialize initial packages, region mapping and hair constraints. Recipient overlay signals coalesce guide refreshes; equipment signals resync region and mirror locks at once. |
| `code/mirror.dm` | `/datum/custom_sprite_mirror` approval countdown, static comparison images, every view drawn when the look is captured (`custom_sprite_render_views()`; the `setView` action only turns the window), approval-only export, result window and recipient saves, the tattoo change list and one-write saves of every applied region. `custom_sprite_cover_looks()` gathers the hair and each mutant part drawn on the body as labelled looks, lowest layer first, keyed by `custom_sprite_hair_cover_key()`, each part's render key and `custom_sprite_placement_key()`. |
| `code/tools.dm` | `/obj/item/tattoo_machine`, which opens the tool menu on the whole body; `attack_self()` resume on it and `/obj/item/scissors`; the shared tool menu and timed salon sounds. |
| `code/transfer.dm` | Style package format, strict validation, export text, geometry checks and transfer helpers, including the whole-body `"target": "body"` file. |
| `code/saved_styles.dm` | Previous saved styles and complete hair and native marking saves. `commit_custom_styles()` validates and writes several regions in one sidecar write. |
| `code/achievements.dm` | The four `/datum/award/achievement/misc/custom_*` awards. |
| `code/persistence.dm` | `/datum/json_savefile/custom_sprites` overrides `New()`, `load()`, `save()`, `set_entry()`, `remove_entry()` and `wipe()` for verified sidecar writes and recovery. Adds the preferences-owned drawing fields and load/save/close/delete helpers, plus `custom_sprites_after_import()`. |
| `code/palette.dm` | `/datum/preference/custom_sprite_palette` implements account storage, default/deserialize/serialize/validation and `is_accessible()`. Its UI is owned by the editor. |
| `code/workspace.dm` | `/datum/sprite_editor_workspace/custom_sprite` overrides `New()`, `is_point_allowed()`, `new_transaction()`, `preprocess_new_transaction()`, `transact()`, `reverse_transact()` and `sprite_editor_ui_data()`. Owns palette validation, mask-aware fill, history limits, serialization, the window's compact canvas (`canvas_ui_data()`), Clear, tint baking and undoable whole-drawing replacement. Adds shared `valid_point_pair()`, `is_point_allowed()`, `prepare_selection_move()` (a box and offset, or a placed selection's final pixels through `prepare_selection_placement()`) and `sanitize_transaction()` helpers. A tall hair canvas saves as a normal drawing until paint reaches its extra rows. `/datum/sprite_editor_workspace/custom_sprite/regions` bounds fill by region, clears one region and replaces frames as one undoable step. The region canvas refuses locked regions for every tool and selection move. |
| `code/appearance.dm` | Adds DNA/head drawing fields, human synchronization and `/datum/component/custom_sprite_appearance` limb/organ signals. `/datum/bodypart_overlay/custom_marking` owns limb rendering; `/zone` keeps limb-zone paint separate, and `/taur` plus `/taur/zone` render the two lower-body snapshots on the chest, just above the organ's own layers. Adds the taur overlay's read-only `custom_sprite_layers()` accessor. Also owns hair and directional emission/blocker helpers, and the human's `has_custom_hair()` and `remove_custom_hair()` for hair interactions. Re-creating an arm's zone overlay moves its hand overlays back above it. `/mob/living/carbon/human/dummy/apply_height()` carries the preview dummy's height maps above its tile and gives it room for what they lift. |
| `code/images.dm` | Palette sampling, bounded runtime caches, width-aware drawing hydration/icon generation, fixed-origin flattening, canvas and mask bounds, native limb/taur silhouettes, directional editing masks and the background tiles. `custom_sprite_cover_rows()` stamps one view of those looks into rows of marks above a paint layer, cached by the cover key and read only inside the drawable box; `custom_sprite_cover_char()` and `custom_sprite_cover_labels()` name the marks. The pictures: `custom_sprite_view_recipes()` walks a look once, crops it to the editor's window and stamps it with each view; `custom_sprite_draw_recipes()` draws a PNG per view with iconforge, kept under a name and overwritten, or deleted once published, each counting toward iconforge letting go of what it keeps; `custom_sprite_picture_path()`, `custom_sprite_forget_pictures()`, `custom_sprite_picture_url()` and `custom_sprite_picture_icon()`. |
| `code/codec.dm` | Drawing and zone-map validation, palette-index encoding/decoding, fixed canvas dimensions, centered legacy expansion, emission normalization, content hashes, arm/hand partners and zone widths. |
| `code/limits.dm` | `SScustom_sprite_work` and the editor's deferred work: `request_view()`, `request_rebuild()`, `request_refresh()` and `run_deferred_work()`, the per-player `/datum/custom_sprite_pace` (on `/datum/preferences` as `custom_sprite_pace`), `rebuild_for_opening()`, the middleware's `open_deferred()` for new editors, `act_blocked()` for restore previews, the hairstyle window (`request_hairstyle()`, `apply_pending_hairstyle()`, `apply_hairstyle()`), `save_unchanged()`, `custom_sprite_mask_points()` for compact strokes and `custom_sprite_history_jump()`. The stroke budget and queue: the pace's `stroke_fits()`, `take_stroke()`, `drain_strokes()`, `push()` (an update that waits while strokes do) and `custom_sprite_transaction_pixels()`; `request_candidate()` for candidate previews, and `request_other_views()` for the views the window isn't showing, drawn after a candidate and only once no refresh is waiting. `costly_work_due()` tells the subsystem which work the overrun budget holds back while it is spent. |
| `code/appendages.dm` | Hair appendages: name cleaning, lenient and strict validation, export, content hash; the head's `custom_appendage_masks()` and `append_custom_appendage_overlays()` with a bounded masked-icon cache; the Try on hats (`GLOB.custom_hair_try_on_hats`), their cached mask rows and placed views, and the preview hat; the editor's `appendage_act()`, `set_try_on()`, `appendage_ui_data()` and `set_appendage_emissive()`; the workspace's layer id check `stroke_layer_matches()` and unpainted-layer carry-over when a recolor also resizes. The workspace's layer steps and `resize_height()` live in `code/workspace.dm`. |
| `code/compose.dm` | Whole-body markings previews composed from paint-free slices and the canvas: `can_compose_previews()`, `refresh_composed_previews()`, `composed_recipe()`, `view_slice_recipes()`, `capture_paintless_look()`, `slice_look()`, `paint_recipes()`, `custom_sprite_boxes_recipe()`, and the markings `render_preview()` override, which draws every view whose pixels changed. |

### Defines:

| File | Define | Purpose |
| --- | --- | --- |
| `code/__DEFINES/~aphelion_defines/custom_sprites.dm` at repository root | `CUSTOM_SPRITE_MAX_CUSTOM_COLORS`, `CUSTOM_SPRITE_MAX_COLORS` | 16 account swatches; 63 opaque drawing colors. |
| Same file | `CUSTOM_SPRITE_INDEX_ALPHABET` | `0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_`; index 0 is transparent. |
| Same file | `CUSTOM_SPRITE_TAUR_WIDTH`, `CUSTOM_MARKING_ZONE_TAUR` | 64-pixel canvas width and the `taur` zone key. |
| Same file | `CUSTOM_SPRITE_TALL_HEIGHT`, `CUSTOM_SPRITE_TALL_HAIRSTYLE` | 48-row tall hair canvas and the name of the bald base that opens it. |
| Same file | `CUSTOM_SPRITE_MAX_SIDECAR_BYTES`, `CUSTOM_STYLE_MAX_BYTES` | 16 MiB drawing-file limit; 32 KiB single-target import limit. |
| Same file | `CUSTOM_SPRITE_MAX_APPENDAGES`, `CUSTOM_SPRITE_MAX_APPENDAGE_NAME` | 3 hair appendage layers; 20-character appendage names. |
| Same file | `CUSTOM_STYLE_MAX_BODY_BYTES` | 160 KiB whole-body import limit, checked before any file is read. |
| `code/transfer.dm` | `CUSTOM_STYLE_FORMAT`, `CUSTOM_STYLE_VERSION` | `aphelion-custom-style`, version 1. |
| `code/transfer.dm` | `CUSTOM_STYLE_IMPORT_COOLDOWN`, `CUSTOM_STYLE_EXPORT_COOLDOWN` | 5 and 2 seconds. |
| `code/transfer.dm` | `CUSTOM_STYLE_EXPORT_DIRECTORY` | `data/custom_style_exports/`. |
| `code/workspace.dm` | `CUSTOM_SPRITE_MAX_UNDO`, `CUSTOM_SPRITE_MAX_UNDO_POINTS` | 100 undo steps; 40,000 recorded pixels across them. File-local. |
| `code/limits.dm` | `CUSTOM_SPRITE_WORK_*`, `CUSTOM_SPRITE_REBUILD_SPACING`, `CUSTOM_SPRITE_BURST`, `CUSTOM_SPRITE_REFILL`, `CUSTOM_SPRITE_HAIRSTYLE_WINDOW`, `CUSTOM_SPRITE_MAX_HISTORY_JUMP`, `CUSTOM_SPRITE_STROKE_BUDGET`, `CUSTOM_SPRITE_STROKE_QUEUE`, `CUSTOM_SPRITE_OVERRUN_BUDGET`, `CUSTOM_SPRITE_OVERRUN_BURST` | Deferred work flags; the pace's half-second spacing, four-piece burst and 1.5-second refill; the half-second hairstyle window; ten history steps per action; 6,000 stroke pixels a second applied inside actions; fifty strokes waiting at most; 150 ms a second, and as much at once, for costly work running past the ends of ticks. File-local. |
| `code/salon.dm` | `SALON_*` | Session states, 120-second prompts, 10-second request cooldown, 5-second custom applications. File-local. |
| `code/mirror.dm` | `CUSTOM_SPRITE_MIRROR_TIMEOUT` | 120-second approval countdown and expiry. File-local. |
| `code/__DEFINES/sprite_editor.dm` at repository root | `SPRITE_EDITOR_TOOL_SELECT` | Shared Select tool bit, `1<<4`. |

### Included files that are not contained in this module:

Paths in this section are relative to the repository root. The core files above
are also required.

| File or directory | Use |
| --- | --- |
| `tgstation.dme` | Includes this module's code. |
| `code/modules/unit_tests/~nova/custom_sprites/`, `code/modules/unit_tests/_unit_tests.dm` | The native tests and their includes. |
| `modular_nova/modules/salon/code/scissors.dm` | `/obj/item/scissors/attack()` offers Custom Style, including for bald and shaved targets. Ordinary cuts use the same timed snipping sounds. A head or face with custom hair has something to cut, and cutting to Bald or Shaved takes the drawing off. |
| `modular_nova/modules/salon/code/misc_items.dm`, `straight_razor.dm`, `hair_tie.dm`, `modular_nova/modules/hairbrush/code/hairbrush.dm`, `modular_nova/modules/moretraitoritems/code/syndiemirror.dm` | Razors, hair ties, the hairbrush and the syndicate mirror count custom hair as hair through `has_custom_hair()`; shaving and cuts to Bald or Shaved call `remove_custom_hair()`. |
| `modular_nova/modules/salon/code/barber.dm`, `barbervend.dm` | Barber locker and vendor stock the tattoo machine and Nova's handheld mirror. |
| `tgui/packages/tgui/interfaces/CustomSpriteMirror.tsx`, `CustomSpriteMirror.test.tsx`, `tgui/packages/tgui/styles/interfaces/CustomSpriteMirror.scss` | The recipient's mirror and its tests. |
| `modular_aphelion/modules/custom_sprites/icons/` | The 76 by 76 achievement icons. |
| `modular_nova/modules/salon/icons/items.dmi` | Salon item sprites, including the tattoo machine. |
| `modular_nova/modules/salon/icons/items_lefthand.dmi`, `items_righthand.dmi` | Angled in-hands in all four directions for the tattoo machine, scissors, electric razor, hairspray and straight razor. |
| `modular_nova/modules/salon/sound/haircut.ogg`, `tattoo_ambience.ogg`, `tattoo1.ogg` | Hair snips, looping machine ambience and the occasional pitch-varied needle sound. |
| `config/nova/config_nova.txt` | Documents the editing switch. |
| `modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm` | Refuses new leg markings while a taur body replaces the legs, and markings a limb already wears. Sends the per-limb marking cap. |
| `code/modules/unit_tests/~nova/limb_markings.dm` | Adding and renaming limb markings never duplicates one. |
| `modular_nova/modules/preferences_import/code/import_verb.dm` | `prefs_import_invalidate_cache()` calls the drawing cleanup after a successful import. |
| `modular_aphelion/modules/worn_emissives/code/worn_emissives.dm` | Existing final appearance grouping keeps paint masks aligned with the character's pose. |
| `tgui/packages/tgui/interfaces/CustomHairEditor.tsx`, `CustomMarkingsEditor.tsx` | The two interface entry points. |
| `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/` | Shared custom window, palette/context menus, the region overlay (`regions.ts`, `RegionOverlay.tsx`), the salon's finishing-touches overlay (`FinishingOverlay.tsx`), backend types and their tests. |
| `tgui/packages/tgui/__mocks__/customSpriteEditor.ts`, `renderCustomSpriteEditor.tsx` | Shared editor fixtures, per-test setup and rendering with isolated or deliberately reused stores. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/MainPage.tsx` | Hair editor button. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx`, `LimbsPage.test.tsx` | Zone and taur marking buttons, and their tests. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts` | Editing-availability flag. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/index.tsx`, `atoms.ts`, `helpers.ts`, `Types/types.ts`, `Types/Tool.ts` | Shared editor state, rendering/context hooks, gesture cancellation and selection types. The canvas's `onPointerDown` reports where every press lands, whatever the tool. The tool objects outlive any one canvas, so an unmounting canvas drops floating paint and then resets them. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/Components/AdvancedCanvas.tsx`, `Palette.tsx` | Canvas input/rendering and shared palette behavior. `shade` replaces the flat grey over unavailable pixels, and `overlay` draws over the canvas at its size. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/strokeMask.ts`, `strokeMask.test.ts` | Compact strokes: the Pencil and Eraser send a stroke as one bit per canvas pixel when the canvas data sets `compactStrokes`, as the custom editors' workspaces do, and their tests. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/Types/Tools/` | Pencil, Eraser, Eyedropper and Bucket updates, naming the canvas's `layerTarget` where it has one; the Select tool (moving, floating, copying, cutting, merged copying, pasting, taking out and turning selections, each gesture kept to the layer it began on) and focused tool tests. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/selection.tsx`, `Components/SelectionOutline.tsx` | The Select tool's keys (Ctrl+C, Ctrl+X, Ctrl+Shift+C, Ctrl+V, R, Shift+R, Shift+H, Enter), the turn and mirror buttons and the Copy all toggle, dropping floating paint before a save, and the marching ants around a box or a selection with pixels taken out. |
| `tgui/packages/tgfont/icons/zaphelion-*.svg` | Hair layer glyphs: the base hair wig, Under hats, Over hats, the Copy all stack, and the zone pictograms as a grey head (`head-side`, `head-back`) under a lit `zone-*` part. Outlined from the design's strokes. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/drawBounds.ts`, `useSpriteEditorHotkeys.ts`, `SpriteEditor.test.tsx` | Cached shading geometry and the `ShadeRenderer` type, shared shortcuts/history cancellation and editor interaction tests. |
| `tgui/packages/tgui/interfaces/NtosNanopaint/NanopaintMenuBar.tsx` | Uses the same history cancellation as toolbar and keyboard actions. |
| `tgui/packages/tgui/layouts/Window.tsx`, `Window.test.tsx` | Current-event Alt handling and respecting gestures already claimed by a control. |
| `tgui/packages/tgui/styles/interfaces/CustomSpriteEditor.scss`, `tgui/packages/tgui/styles/main.scss` | Custom editor styling and its stylesheet registration. |
| `icons/blanks/32x32.dmi`, `icons/mob/leg_masks.dmi` | Existing blank frames and leg-layer masks. Hair/body/marking assets are resolved from the character's existing accessories and bodyparts. |

### Credits:

- ImogenOC.
- Built on the existing /tg/station SpriteEditor, painting canvas, NanoPaint and
  unit-test/screenshot infrastructure, plus Nova's character customization.
