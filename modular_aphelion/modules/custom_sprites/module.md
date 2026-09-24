## Custom hair and markings

Module ID: CUSTOM_SPRITES

### Description:

Adds pixel editors for custom hair and markings in character preferences. You can
add to an existing haircut or give individual body zones their own drawings. Barbers and tattoo artists can use the same editor on
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
have, and each row's dropdown leaves out names the other rows use, the same way
the editor's Base markings section does. The server refuses duplicates from either.
With a taur body selected and enabled, the legs have no paintable pixels and
their markings never show, so both leg sections swap their + and Custom buttons
for a **Taur body** button, and the server refuses new leg markings.
These pass `body_zone` to the same editor. Ordinary zone, hand and taur-zone
drawings stay separate.

Hands aren't limbs of their own: they're the arm's auxiliary zone. A hand drawing
covers the hand plus the three arm rows just above it, so it can't climb the arm,
and renders as its own overlay on that arm.

Hair and ordinary limb drawings use a 32 by 32 canvas. The Taur body editor uses
64 by 32. All have Front, Back, Right and Left
views; a dot beside a view means it contains paint. Hair and facial hair can be
drawn anywhere on their canvas, regardless of the base style. Markings use
the actual body or selected zone's
silhouette in each direction. The taur zone follows the external taur organ on
the chest; its invisible leg slots remain unavailable. Missing limbs and stumps
have no editable zone pixels.

The wide canvas adds 16 columns on each side of the ordinary body. Existing
32-pixel paint stays centered at the same physical position when opened on a
taur. Guides, paint and previews share that origin, including hair, which stays
32 by 32. Wide preview images retain their 64 by 32 proportions.

Uncomment `DISALLOW_CUSTOM_SPRITE_EDITING` at the end of
`config/nova/config_nova.txt` to hide the buttons and reject editing actions.
Saved drawings still render. Editors check the owning client, character slot,
target and optional body zone on the server, including after color-picker dialogs.

#### Tools and controls

- Select comes first in the toolbar. Drag a box, then drag inside it to move the
  selected paint. The box can start in a shaded area, and you can grab it there
  too. All painted pixels in the box move, including old paint left in a shaded
  area; every destination must be inside the drawing bounds and limb mask. The
  box stays inside the canvas.
- Pencil, eraser, eyedropper and fill use the same canvas. Pencil and eraser
  include the release position and send one transaction per stroke. Fill stops
  at holes in a zone's silhouette.
- Markings clip to the body instead. Paint stranded outside the current mask, by
  a changed body or zone, is dropped when the editor opens or its geometry is
  rebuilt, so what saves is what you can see. Imports that paint outside the
  destination are refused rather than trimmed.
- The eyedropper takes painted color first. If there is no paint at that pixel,
  it samples the visible guide. Sampling a color does not use a Custom slot.
- Undo and redo each step through one action in the current draft; they never
  open saved styles or other drafts. Editor shortcuts don't activate held items.
  A selection move is one action,
  including overlapping moves and pixels it replaces. Custom drawing history
  keeps up to 100 actions and lasts only for that editor session.
- Clear layer sits beside undo/redo and clears the current direction. It can
  also remove old paint outside bounds that changed with the character's body
  shape. It is undoable. Clearing an empty view leaves redo alone.
- Hide parts is available for markings, and Hide underwear for markings in
  character setup; it starts on when character setup previews the character
  naked. Gradient, Guide and Grid can be toggled where applicable. The
  guide shows the body as it is, underwear included unless hidden, and excludes
  the drawing being edited. Hide parts only changes the guide; the preview always
  shows hair and parts. Guide and paint share the same canvas and pixel grid.
  Preview comes last in the sidebar; its rotate buttons step through the views in
  the same order as the character preview's.
- The window opens at 900 by 780. Closing the window keeps the unsaved draft and
  its history; reopening continues it with the Pencil selected. Changing direction
  or using history cancels the current selection/drag.

| Shortcut | Action |
| --- | --- |
| Ctrl+S | Save without closing. Saved flashes after the server confirms success. |
| Ctrl+Z | Undo. |
| Ctrl+Y or Ctrl+Shift+Z | Redo. |
| Alt+left-click | Sample paint, or the visible guide underneath, without changing tools. |
| Mouse wheel over the canvas or swatches, or [ / ] | Previous / next palette color, wrapping through Palette and available Custom colors. |
| Escape | Deselect, or dismiss an open swatch menu. |
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
not remove painted pixels or colors still needed by undo/redo. If a drawing has
no room for another color, unavailable Custom swatches stay visible but disabled,
and the Custom title says why.
Themes cannot paint over the swatches; selection uses a border.

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

The markings editor owns that limb's own markings the same way. A **Base
markings** section adds, swaps, recolors and removes them, in layer order, with
the drawing on top. The Taur body editor has no such section, since the taur
body carries no native limb markings. These changes stay in the draft and support undo/redo. Saving
writes them with the drawing. Salon work uses the recipient's markings and waits
for their approval; it never edits the artist's character preferences.

**Blending options**, inside the Custom box, starts with both options off:

- Blend with hair color multiplies Custom colors by the effective hair color,
  or beard color in the facial hair editor.
- Blend with color multiplies them by a chosen color. Its picker starts at white.

The options are mutually exclusive. They use Multiply blending on Custom colors
for new strokes. Palette colors, guide samples and existing paint keep their
RGB. A gradient color saved into Custom follows the same blending rules as any
other Custom color. The selected brush updates after server acknowledgement.

#### Emissive drawings

Every drawing saves its own Emissive setting for each of the four views. The
checkbox edits the current view and defaults off. It is independent of the
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

Version 3 is fixed at 64 by 32; dimensions are not supplied by the file. It is
allowed only for taur-zone markings. Hair and ordinary limb zones
remain 32 by 32; the taur zone requires version 3. Only used colors are saved.
The decoder checks lengths, indexes and expanded size before accepting data.

Save and close and Ctrl+S save the drawing; Ctrl+S keeps editing. Closing the
window doesn't save: the draft stays open in memory until you save or discard it.
Slot switches, style or species changes, and closing character setup still save
open drafts, so work isn't silently lost. Discard drops changes since the last
successful save. Deleting a character slot discards its editor
and removes its drawings. Character exports exclude the drawing file;
successful preference imports remove old drawings and their recovery files.

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

Taur-zone paint is an overlay attached to the chest. It uses the external organ's native layers, directional silhouettes and
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

Each of these caches is shared server-wide and capped at 256 entries, with the
oldest inserted entry evicted first. Cached icons and lists are treated as
immutable. They are runtime caches; the JSON is what persists across restarts.
Drawing tint, marking opacity and emissive choices do not rebuild raw paint or
clipped pixels, but final appearance keys include settings that affect the result. Hair
still takes a private copy for its masks and final overlay assembly.

The editor renders strokes locally. Server previews wait for a 0.6-second pause
and skip unchanged drawings. Encoded pixels are cached until paint changes;
metadata changes reuse them. Guide and preview PNGs are editor-owned data URLs,
with no global asset/CDN registration. The browser reuses decoded guides, cached
shading geometry and unchanged drag previews. Only the opened drawing is sent
to its editor.

Idle windows don't resend drawings. Hairstyle and native-marking choices are
static UI data, and the sorted hairstyle lists are shared. Salon guides listen
for the recipient's worn-overlay changes, including adjusting clothes already
being worn. Related changes share one refresh and one UI update. Clothing changes
reuse the preview body; hair, anatomy and underwear changes rebuild it. Picking up or
dropping a mirror updates self-styling locks immediately. Those locks restrict
editing without clipping existing paint out of the draft.

Color scans collect distinct pixels before normalizing their RGB. Serialization
reuses each color's index and joins the encoded pixels once per direction. The
codec validates the full grid before falling back to the flat format, so an
invalid pixel at the end cannot slip through an early return. These changes keep
the existing palette order, run lengths and saved format.

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
| Drawing size | 32 by 32; the taur-zone canvas is 64 by 32. Four directions. |
| Drawings per character | Eight targets: hair, six limb zones and the taur zone. |
| Saved Custom swatches | 16 per account. |
| Colors in one drawing | 63 opaque colors, plus transparency. Undoable colors also reserve room. |
| Undo history | 100 actions per open custom editor. |
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
- You can use either tool on yourself. Working on your own body skips the request
  and the mirror approval, and applies as soon as the timed work finishes; it
  awards no achievements, the window drops the reminder to stand next to the
  recipient, and every message addresses you rather than naming you. A self haircut can also change your hairstyle and hair
  color from the editor's Base hair section.
- Views you can't see need a mirror: the Back view is locked unless you're
  holding a handheld mirror or standing within a tile of a mounted mirror. A hand
  mirror dropped at your feet doesn't count, and a wallframe still waiting to be
  hung isn't a mirror yet. Picking one up, putting it down or walking to a mirror
  locks and unlocks that view immediately, without reopening the editor, and the
  lock is rechecked when you finish, so losing the mirror mid-draft refuses that
  change rather than applying it. The barber locker and vendor stock one.
- `/obj/item/tattoo_machine`: use it on someone, then pick a body zone they
  actually have, including Taur lower body. Missing limbs, stumps and invisible
  taur leg slots aren't offered. It's reusable, needs no ink and works for anyone
  holding it. The barber locker has one and the barber vendor stocks three.

If the recipient has a previous round style for that target, the tool first asks
whether to draw something new or **Restore previous**.

The flow:

1. The recipient gets a prompt: **Continue** or **Decline**. When they already
   have a drawing there, **Export current style and continue** downloads it to
   the recipient first. Prompts expire after 120 seconds.
2. The artist's editor opens on the recipient's current look. Hair adds to the
   current haircut; a tattoo starts with that zone's current drawing and can
   only paint inside the selected zone's silhouette. The artist's guides and
   previews show the recipient's whole body, dressed as they are.
   Drawing, erasing or filling plays a work sound immediately, with a five-second
   cooldown for snips and twelve seconds for the pitch-varied tattoo needle.
   Tattoo ambience stays on while drawing and lingers for three seconds after
   the last brush movement. An idle window is quiet. Sounds come from the artist
   and stop when the editor closes. Brush activity sends at most one small
   message a second; it doesn't send pixels or trigger UI updates.
3. Drawing doesn't need the artist to stay nearby. Closing the window keeps the
   draft, and using the tool in hand (**Resume custom work**) reopens it with the
   Pencil selected. Ctrl+S shows "Draft saved for this round" and writes nothing
   to disk. Discard draft asks for confirmation.
4. **Finish** needs the artist next to the recipient, holding the tool. It opens
   the recipient's mirror: Front, Back, Right and Left, a draggable Before/After
   divider, **Accept for this round**, **Accept permanently**, **Export** and
   **Decline**. Export downloads the reviewed design without accepting it. The
   usual TGUI countdown bar shows the time left; expiry still declines on the
   server. The images are sent once, separately from the small countdown updates.
5. Accepting starts five seconds of finishing touches for custom hair, facial
   hair and tattoos alike. The drawing was the work. Snips or tattoo sounds and
   ambience play during these finishing touches too, and stop on completion or
   interruption. The change is applied only if everything still checks out when
   those five seconds finish. Ordinary haircut options keep their normal timings.
6. **Accept permanently** saves after successful application, using the same
   character-slot checks and safe save path as **Save for future rounds**. The
   replaced saved style is kept as the previous style. An interrupted application
   saves nothing. A failed save leaves the accepted look applied for this round
   and reports the error in chat. There's no second prompt for someone else's
   work: you already chose whether to save. Self-styling still shows **Save for
   future rounds** and **Done** afterwards, since it skips the approval mirror.
   Export belongs to the approval prompt; it isn't repeated here. The mirror
   uses your chosen UI theme.

The recipient must accept the start and the exact finished design. Closing or
letting the mirror expire declines. Any edit withdraws a pending mirror.
Declining, a failed check or an interrupted timed action returns to drafting with
the paint kept.

Each artist account keeps one draft per drawing for the round, including across
reconnects: hair, facial hair and each tattoo zone are separate, so starting a
tattoo never threatens a haircut. Starting the same drawing again asks whether to
keep that draft, export and discard it, or discard it; **Keep it** reopens that
exact drawing and zone without another picker. The
tool in hand decides what it can resume, and asks which when it matches more than
one. Preview bodies and guides are released while the window is closed and
rebuilt on resume.

`/datum/custom_sprite_salon` owns the session. It holds weak references to both
players, the tool and the bodypart, the starting appearance and the reviewed
proposal. Taur work binds to both the chest and the external taur organ. Its
states are drafting, awaiting approval, applying and completed.

- Starting needs two different connected players, a human recipient, adjacency,
  the right tool in hand, and a reachable target. Hats that hide hair block
  hair work, so clothing never hides the part being worked on. Tattoos use worn clothing's coverage flags for that zone, so a
  rolled-up jumpsuit exposes the arms and gloves only cover the hands.
- Editing only checks that the artist's account owns the draft.
- Finish, accept and completion each recheck both players and their controlling
  accounts, consciousness, the held tool, adjacency, reachability, bodypart
  identity and the target's appearance since work started.
- Approval binds to a token for one immutable copy of the reviewed revision.
- One incoming prompt per recipient, and a ten-second cooldown per artist and
  recipient pair.
- A new haircut, replaced limb or taur organ, changed drawing, body transfer or
  different controlling player invalidates the work. The draft stays available
  to export.
- Completion runs once. Replayed or stale actions do nothing.

Unchanged submissions are rejected. Salon hair imports may change the style and
color, but keep the recipient's opacity, glow and gradients. Zone tattoo imports
may also carry that zone's native markings. Imported changes go through the same
draft, preview and approval as changes made in the editor.

Salon guides and previews show the whole body, wearing what the recipient is
actually wearing, so the artist works on the person in front of them. Dressing or
undressing rebuilds them shortly after. Marking guides leave hair, wings, tails and
other hanging parts out, so they can't cover the limb; a **Hide parts** toggle beside
Guide and Grid puts them back on. The preview body only loses them while the guides
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
recipient's worn appearances using the same layer set as worn-emissive rendering.

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

Application updates only the selected head or marking layer, leaving unrelated
donor parts alone. DNA also records the change for regenerated limbs. Each target
keeps one previous round style on the body, including an explicit empty drawing
and, for hair, the base look. Restoring swaps them, so it can be reversed the same
way. Restoring never saves; saving is still the recipient's separate choice.

Achievements go to both players after a successful, changed application between
different players. Imports, previews, restorations and failed attempts don't
count.

| Achievement | Database ID | Trigger |
| --- | --- | --- |
| A Cut Above | `Custom Hairstyle Given` | Apply an accepted custom hairstyle. |
| Just a Little Off the Top | `Custom Hairstyle Received` | Receive one. |
| Leave Your Mark | `Custom Tattoo Given` | Apply an accepted custom tattoo. |
| Fresh Ink | `Custom Tattoo Received` | Receive one. |

#### Import and export

Both editor contexts have **Import** and **Export**. Export downloads the current
draft without saving it. The recipient's approval mirror can export the reviewed
proposal without accepting it.

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

Import shows a preview first. **Replace draft** is one undoable action that also
covers the hair look; Cancel changes nothing. Strictly valid old drawing-only
files still import into the open editor and keep its current hair look. Their
emissive flags may be numeric 0/1, as written by the old save format.

The server enforces the import boundary:

- 16 KiB maximum, checked before the file is read. BYOND has already received the
  upload by then. The existing `/client/AllowUpload()` separately enforces
  `upload_limit` (512 KiB by default) or `upload_limit_admin` (5 MiB by default).
- `rustg_json_is_valid()` before `json_decode()`, so malformed or deeply nested
  JSON never reaches BYOND's decoder. The file must hold a top-level object.
- Exact field sets and value types. Emission flags may be true/false or 0/1.
  Account sidecars, other formats and versions, and unknown fields are refused.
- Four views at the drawing version's fixed size: 32 by 32 for versions 1/2,
  or 64 by 32 for version 3. Wide drawings are limited to taur-zone markings,
  and taur-zone drawings must be wide. Markings without a body zone are refused. The color and run limits remain
  strict. Nothing is salvaged: one bad view rejects the file. A non-null drawing
  with no paint is refused, so bad data can never act as Clear.
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
actually changes. Strokes, Ctrl+S and ordinary save and close don't.

**Restore previous saved style** opens the old package as a preview, the same way
as an import. It only appears while the draft differs from that style, so it
disappears once it has been restored and returns if you undo. Saving it swaps
current and previous. Deleting a slot removes its
previous styles; preference imports remove them with the rest of the sidecar.

A salon save writes to the character slot selected in character setup. A body that
records the slot it spawned with must have that slot selected; bodies created by an
admin record none and save normally. The slot must belong to the same character
name, have no open editor for that drawing, and have no unsaved changes to the
same base look in character setup, including hair opacity or that limb's native
markings. Otherwise the save explains why and
the round appearance stays.

A hair package is the whole supported look: base hairstyle, hair color, gradient
style and color, hair opacity, base-hair emission, and the drawing with its own
emission settings. It doesn't include species, facial hair, equipment or any
other preference.

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

The native tests in `code/modules/unit_tests/~nova/custom_sprites/` cover codec validation, input/history validation,
selection overlap and shaded starts, limb masks, palette limits, drawing
ownership, directional glow/blockers, persistence failures and recovery, slot
changes, imports, save/reopen/erase, and preview caching. They also check exact
run encoding, mixed-case colors and all 63 colors across icon rows and directions.
Taur fixtures create a real Cow (Spotted) organ and compare native geometry in all
four directions, wide glow/blockers and guide alignment. Capacity
coverage fills all 100 slots with eight current targets and their previous styles.
Keep the shared painting and NanoPaint paths working when changing SpriteEditor.

`transfer.dm` covers hostile JSON, strict fields, RLE and palette abuse,
locked styles, account sidecars, geometry and transfer cooldowns. Mutation
fixtures pass unchanged, and check the relevant rejection reason. Legacy numeric flags and canonical pixel encoding have separate checks.
`saved_styles.dm` covers previous-style rotation, zone isolation, empty
styles, slot deletion, complete hair and native marking saves, a refused save
without a verified sidecar, preference-tab independence and pending opacity
changes. `appearance.dm` also covers hair shade maps, drawing recolors including
merged palette slots, in-game dyeing, and facial hair from its live look through
rendering, export and dyeing; `editor.dm` covers the base-hair controls with
undo, full-canvas hair painting and imports, markings clipping stranded paint,
the facial hair editor's save key, and the limb markings controls. `salon.dm` covers self-styling,
the mirror-locked back view without losing saved paint, self haircuts, native
marking ownership, and worn-item and underwear refreshes. Appearance tests also
check legacy colors, ambiguous shades, batched redraws and gradient opacity.
`salon.dm` covers consent, withdrawal, cooldowns, stale tokens,
distance, mirror closing, interrupted and replayed completion, achievements,
restoration, limb replacement, changed controlling players, salon import limits,
dressed guides, customized limb mask parity, closing and resuming, recipient saves,
and taur-organ replacement while the chest remains attached.
Donor tests attach real transplanted limbs and heads, check their appearance and
restoration history, and compare allowed hair-extension pixels in all four artist
and mirror views.

Tests use `TEST_ASSERT`, which stops at the first failure. Anything a later test
depends on is released in `Destroy()`: salon players and their registries, and
sidecar files registered through `/datum/custom_sprite_test_files`.

`screenshot_hair.dm` loads `fixtures/leia_buns.json` through the real
sidecar reader. It adds brown side buns to Short Hair (`#583820`), checks
save/reopen and cached rendering, and verifies that removal reveals the original
hair. The screenshot shows Front, Back, Right and Left. Its reference is
`code/modules/unit_tests/screenshots/custom_sprite_saved_hair_screenshot_leia_buns.png`.
Review the native output before replacing that baseline. The
[fixture notes](../../../code/modules/unit_tests/~nova/custom_sprites/fixtures/README.md) describe the sample artwork.

Use the repository's [native unit-test instructions](../../../code/modules/unit_tests/README.md)
and [screenshot test instructions](../../../code/modules/unit_tests/screenshots/README.md).
The tests are included from `code/modules/unit_tests/_unit_tests.dm`, which provides `TEST_ASSERT`. Temporary `TEST_FOCUS` entries
must stay out of committed source. `BUILD.cmd` is the normal Windows build entry
point; there is no separate build command for this module.

From `tgui/`, the focused UI checks are:

```powershell
bun test packages/tgui/interfaces/common/CustomSpriteEditor packages/tgui/interfaces/CustomSpriteMirror.test.tsx packages/tgui/interfaces/common/SpriteEditor packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.test.tsx packages/tgui/layouts/Window.test.tsx
bun run tgui:tsc
bun run tgui:build
```

The UI tests cover tool gestures, guide alignment, selection acknowledgement,
save feedback, color blending, swatch menus, theme styling and the zone buttons.
Native icon tests and browser fixtures do not cover every live-client case.
Check real drawing/dragging, hats, turning/resting, limb changes, save/relog and
slot/import behavior in DreamSeeker when changing those paths.

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
| `code/modules/modular_computers/file_system/programs/nanopaint.dm` | `/datum/computer_file/program/nanopaint/ui_act()` forwards history counts; `write_to_file()` and `save_file()` preserve the old image or remove a newly created empty file when export fails. |

The shared workspace's bounds, selection-patch and sanitization helpers live in
this module. Keeping the core calls in place preserves validation and history
ordering for every SpriteEditor user.

### Modular Overrides:

All paths here are relative to this module unless stated otherwise.

| File | Types, overrides and owned behavior |
| --- | --- |
| `code/editor.dm` | `/datum/config_entry/flag/disallow_custom_sprite_editing`; `/datum/preference_middleware/custom_sprites` implements `get_ui_data()`, `apply_to_human()`, `pre_set_preference()` and `on_new_character()`. `/datum/custom_sprite_editor` owns the window, draft, palette actions, guides, previews, import/export and candidates. It is the preferences context; its context hooks include `initial_package()`, `create_preview_body()`, `emissives_allowed()`, `hair_context_problem()`, `render_overlays()`, `draft_changed()`, `context_act()` and `context_ui_data()`. |
| `code/salon.dm` | `/datum/custom_sprite_salon` session, request/restore procs, live style packages and preview dummies, five-second round application, optional approved save and history on `/mob/living/carbon/human`. `/datum/custom_sprite_editor/salon` overrides the context hooks, `can_edit()` and UI lifecycle procs; validated brush activity starts cooldown-limited audio, and closing releases it. Recipient overlay signals coalesce guide refreshes; self-styling movement and equipment signals update mirror locks. |
| `code/mirror.dm` | `/datum/custom_sprite_mirror` approval countdown, static comparison images, approval-only export, result window and recipient saves. |
| `code/tools.dm` | `/obj/item/tattoo_machine`; `attack_self()` resume on it and `/obj/item/scissors`; the shared tool menu and timed salon sounds. |
| `code/transfer.dm` | Style package format, strict validation, export text, geometry checks and transfer helpers. |
| `code/saved_styles.dm` | Previous saved styles and complete hair and native marking saves. |
| `code/achievements.dm` | The four `/datum/award/achievement/misc/custom_*` awards. |
| `code/persistence.dm` | `/datum/json_savefile/custom_sprites` overrides `New()`, `load()`, `save()`, `set_entry()`, `remove_entry()` and `wipe()` for verified sidecar writes and recovery. Adds the preferences-owned drawing fields and load/save/close/delete helpers, plus `custom_sprites_after_import()`. |
| `code/palette.dm` | `/datum/preference/custom_sprite_palette` implements account storage, default/deserialize/serialize/validation and `is_accessible()`. Its UI is owned by the editor. |
| `code/workspace.dm` | `/datum/sprite_editor_workspace/custom_sprite` overrides `New()`, `is_point_allowed()`, `new_transaction()`, `preprocess_new_transaction()`, `transact()` and `reverse_transact()`. Owns palette validation, mask-aware fill, history limits, serialization, Clear, tint baking and undoable whole-drawing replacement. Adds shared `valid_point_pair()`, `is_point_allowed()`, `prepare_selection_move()` and `sanitize_transaction()` helpers. |
| `code/appearance.dm` | Adds DNA/head drawing fields, human synchronization and `/datum/component/custom_sprite_appearance` limb/organ signals. `/datum/bodypart_overlay/custom_marking` owns limb rendering; `/zone` keeps limb-zone paint separate, and `/taur` plus `/taur/zone` render the two lower-body snapshots on the chest. Adds the taur overlay's read-only `custom_sprite_layers()` accessor. Also owns hair and directional emission/blocker helpers. |
| `code/images.dm` | Palette sampling, bounded runtime caches, width-aware drawing hydration/icon generation, fixed-origin flattening, canvas bounds, native limb/taur silhouettes and directional editing masks. |
| `code/codec.dm` | Drawing and zone-map validation, palette-index encoding/decoding, fixed canvas dimensions, centered legacy expansion, emission normalization and content hashes. |

### Defines:

| File | Define | Purpose |
| --- | --- | --- |
| `code/__DEFINES/~aphelion_defines/custom_sprites.dm` at repository root | `CUSTOM_SPRITE_MAX_CUSTOM_COLORS`, `CUSTOM_SPRITE_MAX_COLORS` | 16 account swatches; 63 opaque drawing colors. |
| Same file | `CUSTOM_SPRITE_INDEX_ALPHABET` | `0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_`; index 0 is transparent. |
| Same file | `CUSTOM_SPRITE_TAUR_WIDTH`, `CUSTOM_MARKING_ZONE_TAUR` | 64-pixel canvas width and the `taur` zone key. |
| Same file | `CUSTOM_SPRITE_MAX_SIDECAR_BYTES`, `CUSTOM_STYLE_MAX_BYTES` | 16 MiB drawing-file limit; 16 KiB import limit. |
| `code/transfer.dm` | `CUSTOM_STYLE_FORMAT`, `CUSTOM_STYLE_VERSION` | `aphelion-custom-style`, version 1. |
| `code/transfer.dm` | `CUSTOM_STYLE_IMPORT_COOLDOWN`, `CUSTOM_STYLE_EXPORT_COOLDOWN` | 5 and 2 seconds. |
| `code/transfer.dm` | `CUSTOM_STYLE_EXPORT_DIRECTORY` | `data/custom_style_exports/`. |
| `code/workspace.dm` | `CUSTOM_SPRITE_MAX_UNDO` | 100 undo steps. File-local. |
| `code/salon.dm` | `SALON_*` | Session states, 120-second prompts, 10-second request cooldown, 5-second custom applications. File-local. |
| `code/mirror.dm` | `CUSTOM_SPRITE_MIRROR_TIMEOUT` | 120-second approval countdown and expiry. File-local. |
| `code/__DEFINES/sprite_editor.dm` at repository root | `SPRITE_EDITOR_TOOL_SELECT` | Shared Select tool bit, `1<<4`. |

### Included files that are not contained in this module:

Paths in this section are relative to the repository root. The core files above
are also required.

| File or directory | Use |
| --- | --- |
| `tgstation.dme` | Includes this module's code. |
| `code/modules/unit_tests/~nova/custom_sprites/`, `code/modules/unit_tests/_unit_tests.dm` | The native tests, their fixtures, and their includes. |
| `modular_nova/modules/salon/code/scissors.dm` | `/obj/item/scissors/attack()` offers Custom Style, including for bald and shaved targets. Ordinary cuts use the same timed snipping sounds. |
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
| `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/` | Shared custom window, palette/context menus, backend types and their tests. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/MainPage.tsx` | Hair editor button. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LimbsPage.tsx`, `LimbsPage.test.tsx` | Zone and taur marking buttons, and their tests. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts` | Editing-availability flag. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/index.tsx`, `atoms.ts`, `helpers.ts`, `Types/types.ts`, `Types/Tool.ts` | Shared editor state, rendering/context hooks, gesture cancellation and selection types. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/Components/AdvancedCanvas.tsx`, `Palette.tsx` | Canvas input/rendering and shared palette behavior. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/Types/Tools/` | Pencil, Eraser, Eyedropper and Bucket updates; the Select tool and focused tool tests. |
| `tgui/packages/tgui/interfaces/common/SpriteEditor/drawBounds.ts`, `useSpriteEditorHotkeys.ts`, `SpriteEditor.test.tsx` | Cached shading geometry, shared shortcuts/history cancellation and editor interaction tests. |
| `tgui/packages/tgui/interfaces/NtosNanopaint/NanopaintMenuBar.tsx` | Uses the same history cancellation as toolbar and keyboard actions. |
| `tgui/packages/tgui/layouts/Window.tsx`, `Window.test.tsx` | Current-event Alt handling and respecting gestures already claimed by a control. |
| `tgui/packages/tgui/styles/interfaces/CustomSpriteEditor.scss`, `tgui/packages/tgui/styles/main.scss` | Custom editor styling and its stylesheet registration. |
| `code/modules/unit_tests/screenshots/custom_sprite_saved_hair_screenshot_leia_buns.png` | Saved-hair screenshot reference. |
| `icons/blanks/32x32.dmi`, `icons/mob/leg_masks.dmi` | Existing blank frames and leg-layer masks. Hair/body/marking assets are resolved from the character's existing accessories and bodyparts. |

### Credits:

- ImogenOC.
- Built on the existing /tg/station SpriteEditor, painting canvas, NanoPaint and
  unit-test/screenshot infrastructure, plus Nova's character customization.
