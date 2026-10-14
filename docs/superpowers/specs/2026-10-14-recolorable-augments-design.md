# Recolourable bulky augments: design

- **Date:** 2026-10-14. **Branch:** `bulge`. **Status:** approved. Pol asked for it to be built without his input, so a Fable
  max reviewer stood in for his approval: "approve with required changes", all eight applied, plus its optional
  `_paint`/`_glow` suffixes, `limb_id_override`, cached matrices and finish-only colour clearing.
- **Source request (Pol, 2026-10-14):** build the augment sprites from the handoff
  (`docs/handoffs/2026-10-14-bulge-fitness-augments.md`), add support and a way of customising them, every new style with
  recolourable emissive lights; a pop-up UI like the existing hair and markings ones, with preset colours; a palette icon in
  the augments menu's details (left side) when a finish is recolourable; fit the current UI, every theme and its vibe; as
  performant as the markings menus, with the icons as constant data sent once. Art in Aseprite through the MCP, reviewed by
  an Opus max art critic, using real references.

**Changes since approval.** These come from Pol during the build and supersede the sections below where they disagree. The
build ledger records each ruling.

- **Lights only where the design has them.** Silverhand, Ghostrunner, Maelstrom Wired, Maelstrom Brute and Synthflesh
  glow. Gorilla, Jet, Jet Boots, Maine, Automail and Synthskin have no lights channel and never glow. The generator writes
  a zone's `_e` only where that zone has light pixels, plus an empty mask for a lit arm's hand, because tg draws the hand's
  mask with the arm's.
- **An eleventh finish, Synthskin.** It is segmented synthetic flesh "like cyberpunk has it": the body's own skin cut into
  panels by recolourable seams, with no lights and no metal.
- **Jet Boots is the alternate of Jet.** Jet Plating is Pol's settled V3, and Jet Boots is the V4 boots with the knee-pad
  lip.
- **Maine's knee band wraps all the way round the leg.**
- **Protean regrowth carries the finish:** colours, glow, the Muscular fit and the bodyshape.
- **Drawing moved to an element.** `/datum/element/augment_paint` hooks the limb-icon and icon-key signals, instead of
  re-defining `/obj/item/bodypart` procs.
- **Spawned finished limbs take their owner's skin.** They get `update_limb(is_creating = TRUE)` after attaching.
- **Round 2, after Pol's first in-game look.**
  - Hovering any finish tries it on client side, as the markings room does. That covers brand styles (a brand section
    of the `augment_paint` sheet) and "None" (`default_style`).
  - A press outside a flyout closes it.
  - Recolourable rows carry a palette tag, and the scan has the light key.
  - Markers follow the scan's facing.
  - The fitness sleeve fill stays within the sleeve's own colours.
  - The ledger's `round-pol-2.md` has the full brief.

## 1. What ships

**Ten recolourable finishes** ("styles") for augment arms (with hands) and legs, all on the Muscular outline:

| # | Finish | Source | Status of the art |
|---|---|---|---|
| 1 | Jet Plating | `augment_jet.aseprite` frame 2, "V3" | settled by Pol; needs channel coding and lights |
| 2 | Silverhand | pass-5 candidate | approved ("pretty ok"); conversion only |
| 3 | Ghostrunner | pass-5 candidate | approved; conversion only |
| 4 | Maelstrom Wired | pass-5 candidate | approved; conversion only |
| 5 | Gorilla Arms | pass-5 candidate | approved; needs lights |
| 6 | Maelstrom Brute | pass-5 candidate | approved; conversion only |
| 7 | Synthflesh | `refs_synthflesh/` | new; the first attempt (2/10, "a rash") was dropped |
| 8 | Maine | `refs_maine/` | new. The references show full dark plate with a green edge glow, not "synthflesh with guards" as the handoff guessed; the references win |
| 9 | Automail | `refs_automail/` | new; steampunk/FMA |
| 10 | Jet Boots | `augment_jet.aseprite` frame 3, "V4" | Pol likes the vibe, "the rest needs work" |

Working names become the in-game names. A finish's name is its save key, so renaming one later drops it from saves; rename
before the branch merges if wanted.

**Not in this pass** (each is a follow-up, said so in the report):
- Digitigrade art. Like every brand finish today, these draw plantigrade legs on a digitigrade body
  (`bodyshape_override = BODYSHAPE_HUMANOID`, `has_digi = TRUE`), and the body's clothes follow its legs. The handoff listed
  digi legs as an owed design section; the report must say plainly that they are deferred. The Muscular digi outline exists
  (`mammal_*_leg_digi` in the size sheets); digi art later needs `_digi` states and each finish's `bodyshape_override`
  dropped.
- Head and chest. Arms, hands and legs only (`supported_slots = ARMS|LEGS` bits).
- The spraycan restyle bug (`crayons.dm` passes a `/datum/robotic_style` as an icon). It breaks every finish today, ours
  included; it is unrelated to colour and left for its own fix.
- In-round recolouring. Colours are set in character setup and travel with the limb.

## 2. Colour model

Every finish draws from up to **four player colours** plus fixed light and shine:

| Channel | What it is | Player-set |
|---|---|---|
| Paint | the main plating | yes |
| Accent | trim, panels, knuckle bars | yes |
| Frame | joints, inner structure, dark seams | yes |
| Lights | the emissive strips and clusters | yes; they glow while the character's `allow_emissives` is on, as all player-set glow does |
| Shine | small untinted specular kicks (`w` `#fafbff`, `x` `#c4c7d0`) | no |
| Skin | synthflesh, thighs above the join | the body's own skin or mutant colour |

A finish lists only the channels its art uses (Ghostrunner has no paint, for example), each with a label the UI shows.

Every finish carries a default colour set and **4-6 named presets** (Jet's are anime grey, gunmetal, champagne, blue steel,
black chrome, white). The UI also offers **quick swatches** per channel: metals and paints for paint/accent/frame, and the
classic light colours (cyan, red, green, amber, magenta, white, blue, violet) for lights.

Colours are stored **per augment slot**, so each limb can differ, with "copy to all parts" in the UI.

## 3. Art pipeline

### 3.1 Authoring in Aseprite

Each finish is one Aseprite document, 128x32 (S E N W), laid out as the Jet file is: `leg far`, `torso` (locked
reference), `legs`, `arms`, `hands`, `hair` (locked reference). The `arms` layer holds both arms in S/N and the near arm in
E/W (the far arm draws nothing there); `hands` holds both hands in every view (the far hand is a 3 px sliver); `legs` holds
both legs in S/N and the near leg in E/W; `leg far` holds the far leg in E/W.

Art is drawn **in the finish's default colours from a closed palette**: every palette entry is one channel at one shade,
plus skin-ramp entries for synthflesh in the document's sample skin tone. `paletteLock` keeps every pixel decodable. This
is WYSIWYG for Pol and the critic, and the generator inverts it exactly.

Glyph shades (from the workbench, `augbase.py`/`metal.py`): paint `1-5` = 255/212/168/124/84 and metal `L-T` =
255/238/220/186/165/158/128/98/80 (both the paint channel); accent `r s t` = 255/190/130; frame `a-d` = 230/170/115/70;
lights `*` = full light plus a white lift of 60, `+` = 150; shine `w` `x`; skin `B K D E J F G H I` (the human ramp).
New finishes may add shades; the generator only needs every palette colour to decode to one channel and value.

### 3.2 Rules carried over from the critique rounds

- Every style uses the Muscular outline and may only remove pixels from it, never add (no current design removes any).
- Legs are replaced from the knee down by default, under a skin thigh; the join is a lit lip over a dark gap, broken at the
  centre, never a full-width dark band.
- Flat sculpted planes per muscle, not the skin ramp mapped onto paint; no evenly spaced seams; no scattered single pixels;
  dark on the inner edge, never on the outline; one accent per limb, at joints; lights are 2-3 px strips with falloff;
  at most one bright shine kick per limb; a lit toe, not a black sole row.
- Pol's taste beats the metrics: keep what he approved, change only flagged spots, never swap technique unasked.

### 3.3 Review loop (new and reworked finishes)

The `aseprite:studio` procedure: references studied first, draw, `look`, `validate`, then an **Opus 5.5 max** critic
(the `opus-max` agent briefed as `aseprite:pixel-critic`, reading PNG exports only, since the critic agents have no Aseprite
tools). A draft ships at 7/10 with no BLOCKING finding; otherwise at most three fix rounds, each judged blind A/B
(coin-flipped `a.png`/`b.png`) against the snapshot, two rejected rounds in a row ending the loop. Approved candidates get a
production check only (lights added, all views present) and a blind A/B where anything changed.

### 3.4 Sources and generator

- `tools/bulky_augments/art/<finish>/`: the four layer strips exported from Aseprite (`arms.png`, `hands.png`, `legs.png`,
  `leg_far.png`) and `finish.json` (id, name, and the decode table: each colour used → its packed value or skin reshade).
  These are the committed sources; the `.aseprite` documents are working files. Presets, defaults and channel labels are
  game data and live on the finish datums (4.1).
- `tools/bulky_augments/gen_augment_sheets.py` decodes every pixel through the finish's table and writes the three game
  sheets (3.5). It asserts: every pixel decodes; no semi-transparent pixel; nothing outside the Muscular outline. It omits a
  zone's `_paint` or `_glow` state when the zone has none of those pixels.

### 3.5 Game sheets

All 32x32, four directions, state names `<id>_<zone>` (`zone` in r_arm, l_arm, r_hand, l_hand, r_leg, l_leg):

| Sheet | States | Content |
|---|---|---|
| `icons/bulky_augments.dmi` | `<id>_<zone>`, `<id>_<zone>_e` | skin base in the **human** skin ramp (the Muscular limb's own pixels, plus the design's skin reshades), and the lights mask |
| `icons/bulky_augments_humanoid.dmi` | the same names | the skin base through the **humanoid** ramp (the humanoid Muscular sheet's own pixels, the reshades mapped), and the same masks |
| `icons/bulky_augments_paint.dmi` | `<id>_<zone>_paint`, `<id>_<zone>_glow` | the packed channel images (3.6) |

The skin base covers the whole outline, so the limb's own emissive blocker covers the whole limb and its texture and alpha
behave as an organic limb's. Every zone has an `_e` state, empty where it has no lights (an empty mask costs one overlay a
zone, two per leg; accepted).

### 3.6 Channel packing

Each machine pixel lives in exactly one of two packed images, tinted on the client by a **colour matrix** in one draw:

- `_paint`: red = paint shade, green = accent shade, blue = frame shade.
- `_glow`: red = light shade, green = shine `w`, blue = shine `x`. A light core is red 255 plus green 61, the workbench's
  white lift of 60.

The matrices are **numeric 16-entry 4x4 lists**, built as `constrict.dm:222-236` builds its: each row `rgb2num("[colour]00")`,
the rows paint/accent/frame (or lights/`#fafbff`/`#c4c7d0`), the last row `0, 0, 0, alpha`, everything `/ 255`. The alpha row
carries a translucent species' limb alpha. Not BYOND's row-of-strings form: `map_colors_inferred()` sends every list to
`map_colors_rgba()` (`universal_icon.dm:107`, its `||` is always true), which would write the strings into the iconforge
recipe and break the drawn preview. Matrices are cached in a global list keyed by colour string and alpha.

So a zone draws at most **three sprites** (skin base, `_paint`, `_glow`) plus its emissive mask, whatever its colours, and
no icon is ever generated for a colour. Precedent: Nova's naga tail packs channels the same way. The drawn character preview
flattens numeric matrices (`get_flat_uni_icon` → `map_colors_inferred` → `map_colors_rgba`).

## 4. Game code (module `modular_aphelion/modules/bulky_augments`, ID `BULKY_AUGMENTS`)

### 4.1 The finish datum

`/datum/robotic_style/recolorable` (abstract), one subtype per finish, its data written as vars: `finish_id` (the state
prefix), `channels` (the channels its art uses, key → label), `default_colors` (a colour string, `"#rrggbb"` x4 in channel
order paint, accent, frame, lights), `presets` (name → colour string). As a robotic style it keeps `name`, `icon` (= the
human skin sheet), `limb_id_override = finish_id` (so Nova's `set_icon_greyscale()` screams at apply time on a missing
`<id>_<zone>` instead of drawing blank), `supported_slots` (arms and legs), `has_digi = TRUE` and
`bodyshape_override = BODYSHAPE_HUMANOID`, so it joins `GLOB.robotic_styles_list`, the finish picker and every existing style
path without special cases there.

### 4.2 Applying a finish

`apply_style_to_limb()` (Nova `limbs.dm`) hands a recolourable style to `apply_recolorable_finish(limb, style, colors, prefs)`,
and reports that it did, which sets up the limb whatever augment item it is on:

- `limb_id` = the finish id; `should_draw_greyscale = TRUE`; `icon_greyscale` = the human or humanoid skin sheet, by the
  owner's skin (`species_color` set → humanoid). `update_limb()` re-checks the sheet **after** `..()`, which sets
  `species_color` (`_bodyparts.dm:1277-1289`).
- `is_emissive` = the character's `allow_emissives` preference (read from the prefs `apply()` already receives, as body
  markings do, `limbs_and_markings.dm:20`); tg then draws `<state>_e` before the leg split, so masks split, offset and flag
  themselves. A limb made without prefs (admin spawn, map) glows.
- `augment_colors` = the slot's colour string, or the finish default;
- `muscle_size = MUSCLE_SIZE_MUSCULAR` **at runtime**, so clothing and underclothes fit Muscular. Never as a type var:
  `init_fitness_limb_families()` would take a typed robot limb for a fitness family.

`limbs.dm:53` sets `should_draw_greyscale = uses_greyscale` after the style; it becomes `uses_greyscale || <recolourable
applied>`, or a Cyborg/Prosthetic arm would draw the skin sheet raw.

**Restoring** (`muscle_size = initial(muscle_size)`, `is_emissive = initial(is_emissive)`, `augment_colors = null`) runs at
both preview sites: `limbs.dm:47-53`, where the slot keeps an augment and its finish is a brand finish or none, and
`limbs_and_markings.dm:60-67`, where the slot has no augment. The spawned-limb path needs none. The preview also sets a
brand-finished augment's `muscle_size` to what the spawned limb will have (Normal), fixing the handoff's preview mismatch.

### 4.3 Drawing

Three same-type re-definitions on `/obj/item/bodypart`, in a module file the .dme includes after tg's and Nova's (Nova's
`generate_icon_key()` on the base type, `modular_nova/.../surgery/bodyparts/_bodyparts.dm:26`, is the pattern), each
`. = ..()` first:

- `get_limb_icon()`: then, only when `augment_colors` is set, `draw_augment_paint(., dropped)`. Like
  `draw_muscle_definition()` it inserts, right after the limb's own image (and after each leg half, from `handle_masking()`
  of the packed states), a copy of that image (`new(limb)`) drawing `_paint` and one drawing `_glow`, each with its matrix,
  and the same for the hand (`aux`, `images[2]` on an arm). Copies keep the limb's layer, height, textures and direction. A
  zone without a `_glow` (or `_paint`) state draws no copy for it; the lookup is `icon_exists()`, cached per sheet.
- `generate_icon_key()`: appends `augment_colors` when set (the limb cache is shared by every body, so colours must key
  it), and the skin sheet when humanoid.
- `update_limb()`: re-checks the skin sheet after `..()` (4.2).

Overlay budget: a fully augmented body adds at most 16 sprites and 8 masks over a stock one, counting leg halves; the
worn-emissive pass groups plain sprites and masks per layer, so the top-level count (`MAX_ATOM_OVERLAYS` 180) barely moves.

### 4.4 Preferences

- `/datum/preferences/var/list/augment_limb_colors`: slot name → colour string. Saved as `save_data["augment_limb_colors"]`;
  on load each entry must be a known slot with a valid string (`^(#[0-9a-f]{6}){4}$`, lowercased), else dropped. Text
  values survive the prefs import sanitiser; it gets the key added.
- A new middleware, `/datum/preference_middleware/augment_paint` (modular; key `augment_paint`):
  - `get_constant_data()`: per recolourable finish `{name, id, channels, default, presets, glow_zones}` (glow zones read
    from the paint sheet), plus the shared swatches. Ships once in `preferences.json`.
  - `get_ui_data()`: `augment_colors` (slot → string), the preview skin `{color, humanoid}` from the prefs, and
    `allow_emissives`, so the editor can say when the lights won't glow.
  - `get_ui_assets()`: the `augment_paint` batched spritesheet (4.5).
  - Actions: `set_augment_colors {slot, colors}` (validated slot with a recolourable finish, validated string, or null to
    reset), `copy_augment_colors {slot}` (to every slot whose finish is recolourable). Each saves the prefs entry, refreshes
    the preview body (`character_preview_view.update_body()`), and sends a partial update.
- Changing a slot's finish to another finish clears its colours, so the new finish starts at its own default; changing the
  augment item with the finish kept keeps them.

### 4.5 The editor's sprites

`/datum/asset/spritesheet_batched/augment_paint`: per finish and zone, 128x32 strips (S E N W side by side) of the skin base
(both ramps), `_paint` and `_glow`, plus one strip of the Muscular body as a silhouette. Built by iconforge from the game
sheets and cached across rounds by the batched spritesheet's smart cache, so it is made once per sheet change, not per round
or per player. About 250 strips. The plan checks once how iconforge pads a 32x32 state placed into a 128x32 canvas.

## 5. The UI

All in the Augments+ room (`MarkingsRoom/augments/`), styled with the room's `--aug-*` tokens in a new Aphelion partial
`styles/meridianos/_augments-paint.scss`, so every theme gets it in its own colours. No `theme` prop, no inline styles
except per-item computed values (swatch colours, filter ids).

### 5.1 Where the palette appears

- **Part card, FINISH row (left side of the row):** when the slot's finish is recolourable, a palette button sits at the row's
  left edge, before "FINISH / <name>", and opens the editor for that slot. It is its own button laid over the row (rows are
  buttons and can't nest one). The FINISH row still opens the finish list.
- **Readout (the console's details panel, bottom left):** for a hovered or open slot with a recolourable finish, a line with
  the palette icon and its colours as chips; for a finish under the pointer in the list, "Recolourable" with the icon. The
  icon is a button that opens the editor whenever the readout's target is a slot a picker or the editor is open on (the
  Readout follows the pointer, `target = open?.slot ?? hover`, so it can only be clicked then); while the editor is open the
  Readout shows that slot's chips. The card's button stays the primary opener because it is always reachable.
- **Finish list:** recolourable finishes carry a palette tag.

### 5.2 The editor flyout

Opened from the palette button, it unfolds over the card's side of the stage like the finish list (`.fly`, 300 x 564), so the
chamber's live character stays in view. Closing it, Escape, or the scrim closes it.

1. **Header:** kicker "RIGHT ARM · FINISH", title the finish name, close button.
2. **Scan preview:** the part (arm with hand, or leg) in S E N W at 2x over a dim silhouette of the body, recoloured on the
   client as colours change; a lights toggle shows it in the dark with the lights glowing.
3. **Presets:** tiles of the finish's presets and its default, each a four-colour bar and a name; one click applies.
4. **Channels:** a row per channel the finish uses (label, swatch, hex). Clicking a row opens its picker inline: saturation-
   value square, hue strip and hex input (the components `MarkingColor` uses), the channel's quick swatches, and Apply /
   Cancel. While picking, only the flyout's preview changes; Apply sends the colours.
5. **Footer:** "Copy to all parts", "Reset to default", and the one-line status ("Saved"), sharing the footer as the custom
   sprite editors' status does. With `allow_emissives` off, the lights row says the lights won't glow until it is on.

### 5.3 Client-side recolouring

The preview stacks the strips and recolours each with an inline SVG `feColorMatrix` filter built from the current colours:
the skin strip multiplied by the skin colour, `_paint` by the paint/accent/frame matrix, `_glow` by the light/shine matrix.
In the lights-off view a second `_glow` layer keeps only the red channel as alpha in the light colour with a `drop-shadow`
glow.
Filters run on the GPU; no server round trip happens until Apply or a preset.

## 6. Performance

- **No icon generation at runtime**, for any colour: colours are appearance matrices, the drawn preview flattens them
  through iconforge as it does every other colour.
- **The limb cache** keys colours, so each body and colour set builds its images once; a colour change rebuilds one limb.
- **Constant data once:** finishes, presets and swatches in `preferences.json`; the sprites in one smart-cached spritesheet.
- **The editor** recolours on the GPU and talks to the server only on Apply, a preset, copy or reset; each answer is a
  partial update of `augment_colors`.
- **The room:** the palette button and Readout chips are props on the memoised cards and readout, so nothing else draws
  again.

## 7. Tests and verification

**Unit tests** (in `code/modules/unit_tests/~nova`, TEST_ASSERT, only regress-prone cross-system cases):
- `augment_paint_cache`: two bodies, one finish, different colours: their limb images differ (the shared cache must not
  serve one body's colours to the other), and a colour change rebuilds the limb.
- `augment_paint_fit`: a body with a recolourable arm fits worn clothing at Muscular on that arm, both spawned and in the
  character setup preview, and a brand finish's preview fits at its spawned size.
- `augment_paint_sheets`: every recolourable finish has every state it draws in all three sheets (the fitness sheet test's
  twin; missing states only show up at runtime).

**tgui:** the existing stage and picker tests keep passing; one test for the palette button showing only on recolourable
finishes and opening the editor, and the Readout's icon opening it while its slot is open; `bun run tgui:lint`,
`tgui:tsc`, `tgui:test`.

**Verification at the end:** DreamChecker, a compile, the focused tests (dd.exe recipe, only with no live server), the
headless Edge harness rendering the room and editor in every Meridian theme (hit tests on the palette button, the
flyout's controls), and a live in-game check through the native BYOND harness: each finish in two colour sets, in light and
in the dark (emissives), dropped, and with clothes.

## 8. Risks

- **A 16-entry matrix with a limb alpha below 255** (translucent species) is unverified in BYOND; checked in game.
- **Leg halves order:** `draw_muscle_definition()` relies on the leg halves being the first two images after `..()`; this
  design relies on the same and is covered by the in-game check.
- **The art is the long pole:** four new or reworked finishes go through the critic loop; the code is built in parallel
  against the converted finishes and takes the rest as they land.
