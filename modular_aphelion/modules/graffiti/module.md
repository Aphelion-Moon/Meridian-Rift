## Graffiti

Module ID: GRAFFITI

### Description:

Players paint their own layered pixel-art graffiti onto the station's walls, floors and full-tile windows with a spray
can, keep their pieces in a library on their account, and the art stays on its map from round to round. A piece is
painted live on the wall in the graffiti editor (freehand), or prepared in the editor and sprayed on in stages from the
can. A tile stacks up to five pieces. Admins find, view and delete graffiti in the Graffiti Manager. Hung posters take
graffiti too, over their own pixels only, for the round.

#### Pieces and art

- **Pieces.** A library piece has a name, a description, a width of 32 or 64 pixels (one or two tiles), one palette of
  up to 63 colours (`GRAFFITI_MAX_COLORS`, alpha allowed) and one to four layers, each named and glowing or not. Layer
  grids use the custom sprites codec. `graffiti_validate_piece()` checks a piece strictly, as Import reads it, and
  `graffiti_encode_piece()` writes it out (`"format": "aphelion-graffiti"`, version 1); an exported or imported piece
  is at most 32 KiB. `graffiti_clean_text()` decodes entities before it trims and escapes names and descriptions, so
  cleaning twice changes nothing. Names and descriptions live in the library only: the Custom Graffiti tab edits them,
  and placed graffiti carries neither, though another map's file keeps those its placements were saved with until that
  map next loads, so examine and the Graffiti Manager show neither.
- **One tile or two.** A two-tile piece that paints nothing on its right tile is one tile wide: the editor saves it so
  though its canvas stays wide, `graffiti_validate_piece()` narrows it (`graffiti_trim_wide()`), so imports and library
  loads do, and the can paints it so. A library entry whose stored `thumb` has another width than its piece, as a load
  that narrowed the piece leaves, is flattened again.
- **Alpha.** Placed graffiti is drawn at most `GRAFFITI_ALPHA_CEILING` (204, 80%) opaque, so the surface shows through
  it, and translucent paint is never under `GRAFFITI_ALPHA_FLOOR` (51, 20%), so it still shows. `graffiti_color()`
  stores a colour whose alpha reaches the ceiling as opaque `#rrggbb`, raises an alpha under the floor to it and refuses
  0, so a stored colour's real alpha is the ceiling at seven characters and its own at nine, and a piece's palette keeps
  an alpha only for paint chosen below the ceiling. The windows draw each stored alpha as its share of the ceiling
  (`shownColor()`, owner's ruling 2026-10-19): the editor's canvas, its preview and the thumbnails show paint at the
  ceiling, stored opaque, fully opaque and 99% of it at 99%, as the alpha bar reads. Placed graffiti, its icons, sheets
  and glow masks, draws them at their real alpha and never above the ceiling, which art stored before the ceiling may
  pass at nine characters (`graffiti_drawn_colors()`).
- **Art.** Placed graffiti keeps no layers. `graffiti_flatten()` merges them into one art: its width (`w`), its palette
  packed into one string of `#rrggbbaa` entries (`pal`, opaque as `ff`), one flat grid (`grid`) and one glow mask
  (`glow`), each grid run-length encoded by `graffiti_encode_flat()`, a run taking a length character and its palette
  index in one character, or two once a merge passes 63 colours (up to `GRAFFITI_FLAT_MAX_COLORS`, 4,095). The topmost
  painted pixel decides each pixel's colour and glow: opaque paint replaces what is beneath, and translucent paint
  blends over it in the real alphas by the standard over operator (`graffiti_blend()`), a blend whose alpha reaches the
  ceiling stored opaque. `graffiti_art_hash()` is the md5 of the four fields, so identical art shares one hash, one
  record and one icon. A 64-wide piece splits into one art per tile (`graffiti_split_wide()`), each half keeping only
  its own colours, so a half hashes like an identical one-tile art. `graffiti_flatten_records()` flattens layers that
  are already decoded, a paint job's or the live editor's frames, without encoding them first. The
  `graffiti_flatten_bytes` test pins one piece's flattened bytes and hash (`dfb8008c48fd821254c6be4f72e292bc`): a change
  to them would make every stored art record and sheet look new. Blending in real alpha changed them on 2026-10-19,
  before the branch was merged; sheet files are named for the ceiling too, so every map's sheets were drawn again once.

#### The spray can

- Every spray can that paints has **Stencils** and **Custom Graffiti** tabs in its Crayon window, except the hellcan,
  lubecan and mimecan (`graffiti_enabled()`). Custom Graffiti shows the Unfinished slot (**Resume**, **Keep**,
  **Discard**), then the saved pieces, searchable and sortable, each with **Paint**, **Edit**, Export and Delete, and
  **New**, **Import** and **Freehand**. The library travels as static data only while the Custom Graffiti tab is open,
  as 50 pieces' thumbnails take 40 KB as typical art and up to 1.5 MB as adversarial art: opening the tab sends it, and
  it is sent again when its `revision` changes; a library purged and loaded again always takes a newer revision, so an
  open window never keeps a stale one. Its rows compare what they show (`sameRow()`), so a library sent again redraws
  only the rows that changed.
- **Renaming.** Clicking a saved piece's name opens its name and description for editing in its row; Enter or Save
  sends them (`graffitiRename`), Esc or Cancel doesn't, and text the library holds already, once trimmed and with an
  empty name read as "Untitled", sends nothing. `rename_piece()` cleans them, makes an empty name "Untitled", writes
  through as a save does and is paced as one. The row shows the text sent until the library's text for the piece
  changes; a rename the library hasn't taken within 2 s, as one the write pacing refused, goes back in the form, open
  again at once unless another piece's is, else the next time this one's is. The Unfinished slot's name isn't editable.
- **Arming.** Paint, Freehand and Resume arm the can (`graffiti_armed`: a piece id, `"freehand"` or `"unfinished"`), and
  its examine tells its holder what it is set to paint; anyone else reads only that it is set to paint a piece of
  graffiti, since the piece is from the holder's library. The next click on an adjacent wall, floor or full-tile window
  fastened down, on graffiti on one, or on a poster (see Posters), starts a paint job of the piece, opens a freehand
  session there, or resumes the Unfinished piece; a click on such a window stands for its tile, and an unarmed can still
  tints it. While the Unfinished piece's paint still shows on this map (`graffiti_resume_tile()`, found by its
  placement id), the armed can resumes it only there, a click on either tile of a two-tile piece standing for its left
  one: a click on any other surface is refused with "wrong wall!" ("wrong floor!", "wrong window!", "wrong poster!"),
  keeps the can armed and starts no cooldown.
  Each attempt waits out `GRAFFITI_START_COOLDOWN` (3 s) from the last, refused or not, and is refused before any costly
  work: by an empty can, a paint job already running, or a two-tile piece without a matching tile to its right (the can
  stays armed); a two-tile piece that paints nothing on its right tile paints one tile (`graffiti_trim_wide()`). A
  session or job that starts uses the arming up. A click on anything else disarms the can ("graffiti disarmed") and
  sprays as usual, and so do opening the can's window afresh, picking a stencil, and deleting, keeping or discarding the
  armed piece.

#### The graffiti editor

- `/datum/custom_sprite_editor/graffiti` is the custom sprite editor's shell on a piece: the same canvas, tools, history
  and stroke pacing, with a layer panel, an inline colour picker with an alpha bar and a one- or two-tile width. A
  player has one editor at a time (`SSgraffiti.editors`). Library writes, the editor's saves included, are paced per
  account by their cost (see the library's write pacing).
- **Names.** The editor doesn't edit names: a new piece is "Untitled" with no description, and Save, Save As and the
  Unfinished piece a session leaves take the name and description the library holds for the piece
  (`take_library_names()`), so a rename in Custom Graffiti while the editor is open stays. The piece as last saved takes
  them too, so a rename alone is no unsaved change: Save writes nothing and the session leaves no Unfinished piece.
- **Studio sessions** (New, Edit) edit a piece for the library: Save writes it over its own id, Save As as a new piece.
  Keep saves the Unfinished piece directly to Custom Graffiti without opening the editor.
- **Updates.** The window keeps every layer's view it was sent, so an update carries only the views that changed since
  the last one (`sent_views`) and null for the rest, each view with the serial of its codes (`viewSerials`), which
  changes whenever they do. A window that finds a view missing, as after a reload, or a null under a serial it doesn't
  have, as when two updates come before it draws, asks for them all again (`canvasResync`, taken even while strokes
  wait, when the drain's update brings them). After a stroke on a two-tile four-layer piece an update is 5.5 KB rather
  than 11.2 KB.
- **Freehand controls.** Clear, eraser, selection, layer removal and undo/redo are unavailable during surface sessions.
  Paint stays once drawn; studio sessions retain their editing controls. A full surface stack refuses a new piece
  with "too much graffiti here!"; resuming a piece already in the stack still works.
- **Surface sessions** (Freehand) paint live on a wall, a floor or a window's glass, and one on a window names the
  window in its title rather than the floor beneath it. The piece goes on top of the tile's stack once it has paint and
  is recomposited there as costly work under `SScustom_sprite_work`'s overrun budget, at most every
  `GRAFFITI_COMPOSITE_SPACING` (1.5 s), or every `GRAFFITI_COMPOSITE_SLOW_SPACING` (10 s) once the player's
  `GRAFFITI_COMPOSITE_BUDGET` (600) composites for the round are spent, paint job steps included. Every painter's
  composites together, paint job steps included, take at most `GRAFFITI_COMPOSITE_SHARE` (100) ms a second of game time,
  and those waiting for room take it in the order they first asked: `SSgraffiti`'s `composite_turn()` keeps them in
  `composite_line`, `SScustom_sprite_work` asks for each waiting painter every tick it gets through its queue, and one
  that hasn't asked for `GRAFFITI_COMPOSITE_LINE_GRACE` (1 s), as one no longer due doesn't, gives up its place. A
  session's last composite and a job's finish never wait but count (`spend_composite()`). So with many painters each
  one's composites come further apart, in turn, instead of time dilating. The tile's older graffiti shows under the
  canvas. A session ends when its window closes, after `GRAFFITI_SESSION_LIMIT` (15 minutes), or when the painter no
  longer holds the uncapped can, walks away or can't act, or the surface or the paint on it is gone. Ending charges the
  can once, `GRAFFITI_COST` (5) charges, half for taggers, when paint is left on the surface; a resumed draft left
  unchanged costs nothing. Paint left on the surface also marks each of its tiles as the painter's work, as a finished
  paint job does: their hidden print, and the art element once. It also gives the painter the Tagging Up Turf
  achievement (`custom_graffiti_painted`). The editor's Stencils and Custom Graffiti tabs end the session the same way
  and reopen the can's window on that tab. A surface session can turn two tiles wide only before its first placement.
- **Unfinished.** A piece that changed since it was opened or last saved goes in the library's one Unfinished slot when
  its session ends. A freehand draft resumes only on its own tile, while every tile it painted still shows its paint
  (another surface is refused, as under Arming); a two-tile draft with nothing on its right tile leaves nothing there,
  and is kept and resumed one tile wide. A session ended by a pane loosened under it leaves none of its paint, on either
  tile of a two-tile piece, and its draft is kept as a plain draft, with no tile to resume on. Freehand drafts and
  stopped paint jobs share the slot.
- **Paste is refused on surfaces.** A surface piece is painted by hand, so the workspace's
  `prepare_selection_placement()` refuses, with a notice, a selection placement that lands more pixels of any colour
  than it lifts or covers. Surface sessions disable the selection tool altogether, and the window
  hides Ctrl+V (`noPaste`). The staged reveal can't be enforced against a modified client, whose stroke masks may carry
  any pixels, so prepared art can be drawn in a few strokes, one per colour. That is bounded by the stroke budget and
  the composite pacing, and the charge is taken regardless (accepted).
- **Colours.** The workspace counts the pixels of each colour as they change (`color_counts`), so checking a stroke
  against the 63-colour cap never reads the canvas. Paint whose alpha is 00 is refused, and a stroke, fill or paste
  lands its colours in `graffiti_color()`'s form, so one colour never takes two pixel values. The palette panel lists
  the colours in the order they entered the paint, then the picked ones the paint doesn't use. The inline picker paints
  with its colour as it changes and sends it (`addColor`) once an interaction ends, at a release, a hex commit or 300 ms
  after the last arrow key step, so a drag costs one act of the player's `MINUTE_TOPIC_LIMIT`, not one a move; a colour
  picked elsewhere meanwhile, a swatch or the eyedropper, drops the one not yet sent. Each `addColor` reply gives the
  brush the colour the server took (`syncBackend()`), so the picker lists the colours it sent until their replies come
  and refuses a reply a later pick overtook, putting the later pick back. Its alpha is a share of the ceiling: the alpha
  bar runs from the floor at its left end, 25%, to the ceiling at its right, 100%, sent as `#rrggbb`, so no interaction
  picks an alpha under the floor, and a fully see-through colour is never sent. On a piece whose paint uses all 63
  colours (`full`) the picker mixes without changing the brush, and its title's tooltip says why. It sits under the
  colours, which scroll, so a piece gaining colours never moves it. The editor keeps the last `GRAFFITI_PICKED_COLORS`
  (16) picks, and one more drops the oldest even if it is painted, since painted colours stay listed through the paint.
- **Placing.** A tile that refuses the paint, a new placement or more art for its placement, as a full map of
  connected painters' graffiti does, isn't asked again for `GRAFFITI_PLACE_RETRY` (10 s), and its refusal shows
  meanwhile; the session's last composite asks again.

#### Paint jobs

- `/datum/graffiti_paint_job` sprays a saved piece on in stages: a do_after while each layer appears from the bottom
  up, left to right in strips `GRAFFITI_REVEAL_STRIP` (4) pixels wide. It takes `GRAFFITI_REVEAL_BASE` (8 s) plus
  `GRAFFITI_REVEAL_PER_PIXEL` (0.05 s) for each painted pixel, half that for taggers, at the painter's action speed as
  the do_after does. Steps come at most every `GRAFFITI_REVEAL_MIN_STEP` (1 s), a quick piece revealing several strips
  a step. A player runs one job at a time (`SSgraffiti.paint_jobs`).
- The step timer only marks strips due. `SScustom_sprite_work` reveals them as costly work within its overrun budget, as
  it runs the editors' composites (both are `/datum/custom_sprite_work_owner`s), so under load a step comes late and
  shows every strip due by then; steps are never dropped. The last strip shows only at `finish()`, when the do_after
  ends. Each step counts against the painter's `GRAFFITI_COMPOSITE_BUDGET` as a freehand composite does, though only
  freehand composites slow down once it is spent, and waits, as they do, while every painter's composites together leave
  no room (`GRAFFITI_COMPOSITE_SHARE`).
- The can is charged once, never refused, as the piece's paint first shows (`charge()`), so a job stopped short of its
  last strip pays too and the job resuming it doesn't pay again. Finishing gives each decal `/datum/element/art`
  (`GOOD_ART`) once and the painter's hidden print, and the painter the Tagging Up Turf achievement. Stopping early keeps
  the paint revealed so far and puts the piece in the Unfinished slot with
  where to resume it: on the same map and tile, while that paint is still there, and a click on another surface is then
  refused (see Arming). Once that paint is gone it starts over wherever it is clicked. A job stopped by a pane loosened
  under it drops the paint it revealed for good, both halves of a two-tile piece, and its piece goes in the slot with
  nowhere to resume (`graffiti_drop_loose_paint()`).

#### Posters

- A hung poster that isn't ripped takes graffiti over its own pixels. An armed can paints it as it paints a wall:
  Freehand opens the editor on the poster, and Paint or Resume sprays the piece in stages. The static-station rule
  applies where the poster hangs. One painter works on a poster at a time ("someone's painting it!"). A two-tile piece
  is refused ("too wide!"), and so is a piece that paints none of the poster's pixels ("won't show on the poster!"); the
  can stays armed for the first.
- **Its own pixels.** `graffiti_poster_look()` reads a poster's icon state once, pixel by pixel, and keeps what it read
  for each icon and state (`GRAFFITI_POSTER_LOOKS`, 32; a wanted poster's runtime icon is read each time): the pixels
  it shows, as the editor's draw mask and bounds, and the poster itself as an art. The editor on a poster
  (`/datum/custom_sprite_editor/graffiti/poster`) puts them on its workspace, as the hair and markings editors keep paint
  to the body: the window shades the rest and its tools refuse it, and the workspace refuses it too
  (`is_point_allowed()`). The window draws the poster and its graffiti beneath the canvas, hides the width toggle
  (`oneTile`) and says the paint lasts the round. A paint job on a poster (`/datum/graffiti_paint_job/poster`) clips the
  piece's layers to the same pixels as it is set up (`graffiti_clip_record()`), so its time counts only the paint that
  shows.
- **On the poster, not the map.** The poster keeps its graffiti itself (`graffiti`): every piece painted on it merged
  into one art, a new piece over the older ones as on a wall's stack, without a stack cap. None of it goes in
  `SSgraffiti`'s registry, the map file, the sheets or the Graffiti Manager, so it lasts the round at most, as examine
  says. It draws from the art and glow icon caches the walls use, by art hash, so the same art on any number of posters
  and walls is drawn once. Its composites and job steps count against the painter's pace and every painter's composite
  share, as a wall's do.
- **Saving.** Save writes the piece to the library as on a wall. A piece left unsaved goes in the Unfinished slot as a
  plain draft, with nowhere to resume, so Resume sprays it again from the start.
- **Taken down and hung again.** Ripping the poster or taking down its wall deletes it with its graffiti. Taking it down
  with wirecutters rolls it up with the graffiti finished on it, out of sight (`"rolled"`), and hanging it again shows
  the graffiti once the poster is up (`on_placed_poster()`), clipped to the pixels the poster shows then. A piece still
  being painted stays behind, and its session or job ends. Cleaning washes poster graffiti off
  (`CLEAN_TYPE_LIGHT_DECAL`), which ends a painter's work there.

#### Tiles and stacks

- `/obj/effect/decal/cleanable/crayon/custom` is the graffiti on one surface of a tile: a stack of placements, oldest at
  the bottom, shown as one merged composite. `graffiti_surface_kind()` says which surface a tile offers
  (`GRAFFITI_KIND_*`): a wall, the glass of a full-tile window fastened down on it (`graffiti_window_of()`), or a floor
  with ground; `graffiti_surface_ok()` is whether it offers one. A loose full-tile window still covers its floor and
  takes no graffiti until it is fastened again, and a directional window changes nothing. The decal keeps the kind it
  was made on (`kind`), and `graffiti_tile_decal()` finds the decal of the kind its tile offers now, so a floor's
  graffiti stays beneath a window fastened over it later, as a decal of its own, through any turf change that leaves the
  floor. A two-tile piece needs both tiles to take it and to be of one kind, walls, floors or windows
  (`graffiti_wide_ok()`); its halves are two placements sharing one placement id.
- **Windows.** Graffiti on a window is drawn on the game plane at `GRAFFITI_WINDOW_LAYER` (3.25), over the glass and
  under closed shutters and blast doors, which share tiles with full-tile windows at 3.3, and follows its window: it
  goes for good when the window is deleted or leaves its tile, which is judged once the move is over, so a shuttle
  carries both, and it washes off with the window, which soap and sprays reach instead of its tile. Unfastening the
  window keeps finished graffiti, but a session or paint job painting the pane stops and its piece in progress goes for
  good, both halves of a two-tile one, as a cleaning takes it, with nothing to resume.
- At `GRAFFITI_STACK_CAP` (5) the tile refuses new pieces, preserving its existing paint. While someone paints a tile, its decal
  keeps the merge of everything beneath the top piece and of the whole stack, so a live update merges only two arts.
  A stack shown from its sheet, changed by a removal, or left by its painters (`graffiti_release_merges()`) keeps
  neither (`release_merges()`): the first composite there merges the pieces beneath again, and the editor's backdrop
  merges them with `base_merge()` and `stack_merge()`.
- Examining it says "A piece of graffiti.", "It won't outlast the shift." of a round-only top piece, and "Older
  graffiti shows through underneath." while an older piece still shows. Whether one does is merged once, when first
  examined, and kept until the stack changes, as merging five pieces takes tens of milliseconds.
- **Glow.** Paint on glowing layers lights on the emissive plane. A stack that glows everywhere gets an emissive of its
  icon, one with mixed paint an emissive blocker with an emissive of its glow mask just above it (the sheet's
  `<stack key>_g` state), and one that doesn't glow a blocker. The overlays take the decal's own layer, over the glass
  on a window; a floor's moves onto the emissive plane as `emissive_appearance()` moves topdown layers.
- **Cleaning.** Soap and other cleaning remove the decal, and the registry drops its placements for good. A decal also
  goes when its turf changes and the surface it was made on is gone (`NeverShouldHaveComeHere()`), as when a wall turns
  into a floor or a floor into space: a floor's needs only its floor, so it lasts under a window fastened over it later,
  and a window's goes with its window. Cleanbots set to clean drawings erase graffiti too (accepted: it is cleaning,
  behind an explicit bot setting).
- Decals loaded from the map file get no art element and no hidden prints: both belong to the round the paint went on.

#### The map registry (`SSgraffiti`)

- **Placements** are kept as one packed JSON string each (`json_encode()` of the anchor, the art hash, `ckey`, `who`,
  `at`, `pid`, `half` and `miss`; 691 bytes, against 1,155 as a list, measured while placements still carried a name and
  a description), read with `unpack()`. They carry no name or description. `placement_info` indexes what placement
  operations read (ckey, art, `at`, id, the painter's character name, round-only) without unpacking, and
  `ckey_placements` and `ckey_arts` index each account's placements, in eviction order, and its art.
- **Timestamps** (`at`, and `seen` for when an owner last connected) are ten-digit unix seconds kept as text
  (`graffiti_unix_time()`): BYOND numbers can't hold them (`json_encode(1792800001)` gives `1.7928e+09`), and ten-digit
  text sorts in time order.
- **Caps and eviction.** A map keeps `GRAFFITI_MAP_PLACEMENT_CAP` (4,000) placements of `GRAFFITI_MAP_UNIQUE_CAP`
  (2,000) unique arts of at most `GRAFFITI_MAP_ART_BYTES` (5 MiB) in all, and an account `GRAFFITI_CKEY_PLACEMENT_CAP`
  (400) placements of `GRAFFITI_CKEY_UNIQUE_CAP` (200) arts on each map. A new placement meets the map's caps first
  (`make_room()`), counting the account's own placements that its own caps take (`own_evictions()`, `map_fits()`): past
  them the lowest-ranked placement of an owner who isn't connected goes (`lowest_unconnected()`), and when every owner
  is connected the new paint is refused ("the walls here are caked in paint") and the account keeps all of its own.
  Only a placement that lands takes the account's oldest placements past its caps, and the painter is told, by the
  editor's notice or a paint job's balloon alert. New art for a placement, as a freehand session or a paint job reveals
  more of its piece, meets the same caps, the placement giving up its old art (art other placements share stays). It
  never evicts the placement itself, and when nothing can make room the placement keeps its old art: a paint job stops
  there, its piece going in the Unfinished slot, and a session's tile waits out `GRAFFITI_PLACE_RETRY`. `rank()` puts a
  connected owner first, then the owner seen most recently, then the newest placement, then file order; it also decides
  what a load drops past the placement and unique-art caps. So a full map can evict an offline player's oldest art.
- **Static station only.** Graffiti goes only on the station as the map built it (`graffiti_static_station()`): a
  station level's turf in a station area, neither a shuttle's nor the holodeck's, and outside every map template loaded
  on the station this round, such as a random room, which the `/datum/map_template/load()` override records
  (`SSgraffiti.loaded_templates`). Other levels, bitrunning and reserved space, ruins and maploaded rooms take none:
  `graffiti_surface_ok()` and `graffiti_wide_ok()` refuse them, so the armed can says "can't paint here!" and stays
  armed. Condos will take graffiti through an anchor resolver of their own (below).
- **Anchors.** `graffiti_anchor_for()` gives a static station turf a station anchor (its coordinates, its z level's
  place among the station levels and its area type), recording the turf's kind of surface as its `surface`. An anchor
  resolves only to a turf that is still the static station and offers the same kind of surface, so a window's graffiti
  counts a miss in a round its window isn't there, and a station anchor only in its old area. An anchor saved before
  windows took graffiti records `wall`, whether its surface is a wall, which `check_anchor()` reads as a wall or a
  floor, for a map file and for a stopped piece's resume data alike. Map templates took template anchors until
  2026-10-21; a file's placement that still has one is dropped as the file loads. Resume data keeps the anchor of the
  piece's left tile with the kind of surface its paint went on (`graffiti_resume_anchor()`), and a piece that stops
  while a tile of it offers no surface, as under a loosened pane, keeps none. Other anchor kinds go through resolvers
  registered with `graffiti_register_anchor_resolver()`.
- **Custom maps.** An admin-loaded custom map (`CUSTOM_MAP_PATH`) keeps no graffiti past the round, and its paint is the
  only round-only graffiti: the placement keeps its turf's coordinates and is never saved. Its name is whatever the
  admin typed and may be another map's, so `load_file()` gives its store no path: no map file is read or written, and
  `build_sheets()` deletes no sheet file. `graffiti_anchor_for()` gives its turfs no anchor, so all of its paint is
  round-only and the editor and examine say so.
- **Dormant placements.** A placement whose kind has no resolver this round waits without counting a miss. One whose
  anchor doesn't resolve otherwise counts a miss each round and is dropped once it has missed `GRAFFITI_MISS_LIMIT` (20)
  rounds in a row, as a station anchor does that the static station no longer covers. When an owner connects
  (`on_client_connect()`), their dormant placements whose anchors resolve now are shown. Everything within the caps
  shows (`GRAFFITI_DISPLAY_BUDGET`).
- `graffiti_registry_release()` takes one unloading space's graffiti off its tiles and keeps it dormant in the file.
  With `graffiti_register_anchor_resolver()` it is the integration point for condos and districts; neither has a caller
  yet.

#### Saving and loading

- **Loading in the background.** The map's graffiti loads once every subsystem has initialized and the game reaches the
  lobby (`COMSIG_TICKER_ENTER_PREGAME`), so it takes none of the server's startup: `load_in_background()` reads the
  file, places the stacks and draws the sheets a share of each tick at a time, at most `GRAFFITI_LOAD_SHARE` (20)
  percent of it (`load_yield()`, `load_share`), the largest piece in between being the file's one `json_decode()`, a
  tile's stack merged or one icon drawn. Decals show their art once their chunk's sheet is drawn. Until it has loaded
  (`loaded`) nothing is placed ("graffiti still loading!"), saved or deleted by an admin, and players who connect
  meanwhile are noted once it has. Unit tests load at once, with the whole tick (`load_share` 100), as they read the
  registry straight away.
- **The map file** is written `GRAFFITI_SAVE_DEBOUNCE` (60 s) after a change, with every change made meanwhile, and last
  at round end (`SSpersistence/collect_data()`, after which nothing is written) and in `Shutdown()`, for a reboot that
  skips the round end. `save_now()` writes nothing before the map's graffiti has loaded, so a shutdown during the load
  can't write a half-loaded file. Round-only placements and art without paint aren't saved, `seen` keeps owners only,
  and a map that never had lasting graffiti gets no file.
- The text is joined from the packed placements and from the art records, each encoded as the file is joined, so the
  registry keeps no second copy of its art between saves: the same text `json_encode()` would write. `write_text()`
  stages it (`.new`), makes the backup (`.bak`) hold the last verified revision, writes the primary, then copies it over
  the backup, and checks each file by its md5; only the md5 of the revision stays in memory. So once a save is written,
  graffiti cleaned before it is in neither the map file nor its backup (its sheet files go at the next load), and a
  write interrupted on the primary still recovers the last revision from the backup. Three backups are left holding an
  older revision until the file's next save: one written before saves refreshed their backups, one a crash leaves
  between writing the primary and refreshing the backup, and one kept for a primary deleted by hand. A map file edited
  by hand mid-round is kept as the backup until the next save and overwritten, with a log line. `json_encode()` writes
  non-ASCII as `\u` escapes, so map files are ASCII. A save that fails is logged, and the round's first failure is told
  to the admins (`message_admins()`), since the changes since the last save are lost unless a later save succeeds. A
  backup that can't be copied after the primary is written leaves the save standing, as the primary holds it, with a
  log line, and the next save copies the backup again, as the library's `save()` does.
- **Loading** keeps only valid one-tile art under its own hash and well-formed placements. An art under its own hash
  that keeps its glow kind (`k`) is taken as the server wrote it, without decoding it; one without is decoded, checked
  and given its kind. It cleans their painters' names again, reads an old anchor's `wall` as its `surface`, leaves out
  fields it doesn't keep, such as the names and descriptions placements once carried, drops exact duplicates and
  whatever is past the caps, the art bytes included, by rank, and logs one line for everything dropped. Map files are
  version 2 (`GRAFFITI_MAP_VERSION`), and version 1, whose anchors may record `wall` and whose placements may carry
  names and descriptions, loads too (`GRAFFITI_MAP_READ_VERSIONS`): its next save writes it as version 2, while the
  Graffiti Manager's edits of another map's file keep its version. A file that can't be read, or has another version,
  leaves the map's graffiti empty and unsaved for the round, so the file waits for an admin. **The stack cache.** The
  file also keeps, for every saved stack of several pieces, its key and glow kind under its signature (its pieces' art
  hashes, `stack_signature()`), beside a fingerprint of what merging gives (`graffiti_merge_fingerprint()`: the alpha
  ceiling and the hash of one fixed merge). While the fingerprint matches, the load shows such a stack under its cached
  key without merging it (`adopt_stack()`), and merges it only should its sheet need drawing or someone paint the tile;
  a changed merge sets the whole cache aside. A warm load of 1,548 dense pieces in stacks of five took 1.5 s against
  18.2 s merging, and in stacks of one 1.9 s against 9.2 s.
- **Sprite sheets.** As the map loads, every shown stack's composite and glow mask is drawn into per-chunk sheet files:
  decals sorted by z level, 16-tile chunk and position, up to `GRAFFITI_SHEET_STATES` (32) composites a sheet, each
  sheet named by the md5 of `GRAFFITI_ALPHA_CEILING` and its stack keys (`data/graffiti/sheets/<map key>/<hash>.dmi`),
  so a sheet drawn at another ceiling is drawn again. Decals show them through `fcopy_rsc(file())`, which holds 0 bytes
  of server memory, and an unchanged chunk reuses its file from an earlier round, which clients have cached: the live
  check saw unchanged sheets never downloaded again. Files no sheet uses are deleted after the build. Paint changed
  mid-round shows from per-tile icons in the art and glow caches (`SSgraffiti.art_icons` and `SSgraffiti.glow_icons`,
  `GRAFFITI_ICON_CACHE`, 128 each, the oldest going first); an art no placement uses any more leaves both at once
  (`release_art()`), while the composite of a stack of several pieces, which no placement names, only ages out, and
  clearing the map empties them. Sheets are drawn from fresh icons (`use_cache = FALSE`): BYOND refuses every further
  `Insert()` into a sheet once about twenty icons inserted into it are still held elsewhere, as the caches hold theirs
  (`graffiti_registry_sheet_chunk` covers it).
- **The decode cache.** During the load `SSgraffiti.decoded` keeps the decodes the load makes, of art without a kept
  glow kind, for the merges and sheets, within `GRAFFITI_DECODE_BUDGET` (8 MiB, about 400 dense one-tile arts); art past
  it is decoded again where needed. It is pruned to what the sheets draw once the stacks are placed and dropped once the
  sheets are drawn, or by a ten-minute timer should a runtime stop the load. The load's loops skip whatever changed
  while they waited for a tick.

#### The library

- `/datum/graffiti_library` holds an account's `GRAFFITI_LIBRARY_CAP` (50) pieces and the Unfinished slot in one file of
  at most 2 MiB. Each entry keeps its flattened art as `thumb`, so the tab never flattens fifty pieces to open. Every
  change is written through and undone when the write fails, so the library holds what its file doesn't only while a
  change waits for the write pacing. Export downloads a piece as a file and Import validates an uploaded one, sharing
  the custom sprites transfer slot and cooldowns.
- **Empty libraries.** A write that leaves the library with no pieces and no Unfinished piece deletes its file, backup
  and staged copy instead (`delete_files()`), as the admin purge does. The library stays loaded, `next_id` and all, and
  its next save writes the file again.
- **Unloading.** A library unloads as its owner disconnects (`graffiti_library_unload()`, from `/client/Destroy()`),
  unless an editor session or paint job of the account's, a write the pacing holds back, or an import or export still
  holds it. `/client/Destroy()` runs before the owner's windows close, so an editor or paint job that ends, and a held
  write once made, unload it while its owner is away; one an import or export held stays until the owner's next
  disconnect, or the reboot at the round's end. `graffiti_library()` loads it again when it is next wanted, under a
  newer revision.
- **Write pacing.** Each write rewrites and checks the whole file, 139 ms on average for 50 adversarial pieces, so it
  paces the account's next one by its cost (`graffiti_library_paced()`): a player's save, Save As, import, rename,
  delete, Keep or Discard waits at least a second after it, and `GRAFFITI_LIBRARY_WRITE_PACE` (20) times as long as it
  took (`graffiti_library_write_due()`), which holds one account's writes to a twentieth of the server's time. The
  changes the server makes are never refused: the Unfinished piece kept as a session or paint job ends, and a finished
  job emptying the slot, wait out the pacing and are written once by a timer with whatever else changed meanwhile. A
  player's write takes them along, and the round end and `Shutdown()` write whatever is still held
  (`graffiti_library_flush()`).
- `/datum/json_savefile/custom_sprites/graffiti` is the custom sprites store for graffiti files: it loads every
  top-level entry through the store's `load_entries()` hook, is held to its `size_limit` on reading and writing,
  decodes its file as hostile input, and keeps only the md5 of the last verified revision in memory. Its `save()`, which
  the Graffiti Manager's edits of other maps' files use too, writes each revision it verified over the backup as well,
  as `write_text()` does: a deleted piece or a discarded Unfinished piece is in no file once the write that drops it is
  done, and a file changed outside the server is kept as the backup until the next save. A backup it can't write after
  the primary leaves the save standing, as the primary holds it, so the library keeps the change, and the next save
  writes the backup again.

#### The Graffiti Manager

- The **Graffiti Manager** verb (`R_ADMIN`) opens `/datum/graffiti_manager`: the current map's placements, shown,
  dormant and round-only, `GRAFFITI_ADMIN_PAGE` (24) a page, sorted by date, ckey or area and searched by ckey or
  character name (`who`), each with a thumbnail and a larger view. **Jump** moves the admin onto the piece's own turf,
  which for a wall piece is inside the wall, as tg's Jump To Turf does. Deleting the selected pieces (a wide piece loses
  both halves), an account's graffiti on this map or everywhere (its library too), or this map's or every map's graffiti
  each asks first, re-checks `R_ADMIN`, and is logged and told to the admins with the count. Selected pieces and an
  account's leave the registry at once, and then each tile they leave is merged again once, yielding between tiles
  (`remove_placements()`), the pieces still stacked there keeping their order; editing the other maps' files yields
  between files. Deleting this map's graffiti, a piece, an account's or all of it, also ends what its painters have
  under way on it with nothing kept (`drop_work()`): a freehand session or paint job painting it stops without an
  Unfinished piece, and an Unfinished piece left to resume on it is discarded, an offline owner's too, whose library is
  loaded for it, yielding between them, and unloaded again. The bulk ckey target is the selection's single ckey, else
  the search text only when it is already a ckey. The window refreshes only after its own actions, since listing reads
  every placement.

#### Tests

`code/modules/unit_tests/~nova/graffiti/` holds 31 tests in seven files: the codec, piece validation, the alpha ceiling
and floor and the narrowing of two-tile pieces (`codec.dm`), surface and studio sessions (`editor.dm`), the library's
caps, write pacing and import, and the backup and files a deletion leaves (`library.dm`), the registry's round trip and
miss drops, map files whose placements still carry names, cleaning, cleaned art leaving the map file, its backup and the
icon caches, admin deletes, halves, rank with connected owners first, caps with burying and the byte budget, on loading
and on new art too, sheets and the static-station rule (`persistence.dm`), paint jobs, arming and window surfaces (`placement.dm`),
freehand and paint jobs on posters, kept to the poster's pixels, through a roll-up, a rehanging and a wash, two posters
sharing one art's icon (`poster.dm`), and the workspace's layers, colour counts and alpha-00 refusal (`workspace.dm`). `graffiti_registry_caps` and
`graffiti_library_caps`, about 1.1 s and 1.7 s, run with `TEST_LONGER`. The module adds type vars and globals, and
var-cap diagnostics are ignored. The unit-test build still tipped into a bogus `invalid variable` error three times. The
first was cleared by moving a new static into an existing one; each of the other two took one more `~nova` test file out
of the build, the repo's standing remedy: `liver_nova.dm`, then `symphony_moderation.dm`. Production builds are
unaffected.

#### Performance

Measured on BYOND 516.1687, Runtime Station. Adversarial art is random colours on every pixel, about 1,000 a tile and
2,047 across a two-tile piece; dense art paints every pixel; typical art uses a few dozen colours. Each pass compared
its own before and after runs, so the passes don't line up to the millisecond. BYOND never returns freed memory to the
OS, so every memory figure adds to the server's high-water mark.

Memory, files and drawing, from the memory benchmark, which set the budget defines:

| What | Measured |
| --- | --- |
| A placement in memory, with the name and description placements no longer carry | 1,155 B as a list, 933 B sharing its name strings, 691 B packed as one JSON string |
| An art record | 3,670 B dense, 680 B sparse, 7,197 B dense two tiles wide |
| A decal | 2,261 B, and 116 B more while it shows an icon |
| An icon held in memory | art 4,801 B dense, 553 B sparse, 10,355 B dense two tiles wide; glow mask 6,930 B; a sheet state as an `/icon` about 4.6 KB |
| A file-backed icon (`fcopy_rsc(file())`) | 0 B of server memory |
| Sheet file bytes a state | 1,791 B for random-colour art at 32 a sheet (largest sheet 113 KB), against about 654 B as separate icons; 420 B for default-palette art (24.7 KB, 36% smaller than separate icons); 128-state sheets reach 448 KB |
| Drawing | art icon 4.2 ms dense, 0.6 ms sparse, 8.1 ms dense two tiles wide, 29 µs cached; glow mask 4.0 ms; packing 32 states 5.9 ms |
| Merging five dense arts | 22.7 ms opaque, 45.7 ms translucent, mostly decoding at 1.2 ms a decode |
| An 8 MB map JSON of 10,000 placements | `json_decode()` 150 ms, `rustg_json_is_valid()` 59 ms |

As built, from the last run that measured each: the stroke and memory pass for the editor, paint jobs, libraries, the
hundred-painter scenarios and memory over repeated use, the registry pass for loads and the registry, and the load
benchmarks' first runs for file sizes:

| Work | As built |
| --- | --- |
| A composite: one tile typical / one tile adversarial / two tiles adversarial | 14.9 / 33.3 / 72.6 ms |
| A composite on a stack of three, the first after the map loads, which merges the pieces beneath again | 39.9 ms |
| A 300-pixel stroke on a two-tile four-layer piece, and its window update | 1.3 ms and 0.9 ms; the update 5.5 KB in default colours, 8.4 KB in 63 random ones |
| One painter at the client topic limit (an 1,800-pixel stroke every 0.3 s) | composites exactly 1.5 s apart, 27 ms/s of work, +0.4% time dilation |
| Twenty painters at the topic limit, adversarial art over four dense pieces a tile | 171 composites a minute, each painter's 6.9-7.0 s apart, 102 ms/s of composites and 188 ms/s of stroke handling, +0.8% time dilation; with the composite share held open on the same build, 798 a minute, 500 ms/s and +16.0% |
| A hundred studio editors at the topic limit (a 300-pixel stroke every 0.3 s, two tiles, four layers) | 736 ms/s of strokes and their window updates, 2.0 MB/s of updates, +2.0% time dilation |
| A hundred freehand sessions at the topic limit (one tile, four layers) | 546 composites a minute at 11.2 ms, each painter's 10 s apart, 102 ms/s of composites and 587 ms/s of strokes and updates, +3.0% time dilation; with the composite share held open on the same build, 3,867 a minute, 670 ms/s and +57.2% (+78% when first measured) |
| A paint job step: two tiles adversarial / two tiles dense / one tile adversarial / typical | 52.7 / 25.6 / 30.7 / 14.2 ms; setting a job up 8.2 ms |
| Posters, 2026-10-23, against a wall on the same build, one layer of 63 random colours: a stroke of 300 pixels on the poster / 300 anywhere, about half of them off it / every pixel | 0.80 / 0.54 / 1.12 ms against 0.77 / 0.81 / 1.96 ms; 1.81 / 1.45 / 4.29 ms while each point was checked, before strokes were cut down to the poster as they are read |
| Posters: a composite with nothing beneath / over a dense piece; a dense one-tile paint job step | 3.6 / 5.9 ms against 4.6 / 8.6 ms; 2.9 ms against 4.9 ms, setting the job up 1.9 ms on both |
| Posters: reading a poster's look; the editor's static data over a dense piece; hanging a rolled-up poster's graffiti on the look it was painted for / on a changed one; its overlays | 13 ms the first time for each icon state, 2 µs after; 2.5 ms, once as the editor opens; 0.27 / 1.8 ms; 35 µs with its icon cached, 14 µs without graffiti |
| Twenty two-tile adversarial paint jobs at once | 289 ms/s of step work in spare tick time, 13.4 ms/s past the tick limit, +1.8% time dilation |
| A library save, 50 pieces: typical / 49 dense and 1 adversarial / 50 adversarial | mean 33 / 68 / 150 ms, max 43 / 146 / 223 ms; files 94 KB / 744 KB / 1.70 MB; static data 97 KB / 343 KB / 1.49 MB |
| Memory over 50 cycles: 10 tiles painted and cleaned / 10 paint jobs finished or stopped / 10 studio editors of 20 strokes / 10 freehand sessions of 20 strokes | private bytes +0.07 / +0.17 / 0 / +1.9 MB from cycles 5-10 to 50, with every registry, editor, job and queue count back where it started each cycle; the freehand sessions' slow growth, about 4 KB a session, is in no list the module keeps |
| A studio editor at its full undo history (100 steps of 300 pixels) | 2.6-3.5 MB in the unit-test build, freed as it closes |
| A full map: 4,000 placements of 2,000 dense arts in stacks of three | map file 8.2 MB; load 9.6 s, placing 33.8 s, sheets 15.9 s cold; saves 467 / 440 ms |
| Loading a map, cold (sheets drawn) / warm decoding and merging / warm from the stack cache, 2026-10-21, work done in the background at a fifth of each tick: 400 dense one-tile stacks | 4.0 / 1.7 / 0.2 s |
| The same: 2,000 dense placements in stacks of five, of which the 5 MiB art budget keeps 1,548 | 20.7 / 18.2 / 1.5 s |
| The same: 2,000 dense one-tile stacks, of which it keeps 1,548 | 21.6 / 9.2 / 1.9 s; 59 sheet files |
| The same: 2,000 sparse one-tile stacks | 7.8 / 5.0 / 2.9 s; 66 sheet files |
| The decode cache on a cold load | 400-504 records, at most 7.99 MB, once the file has loaded; 0-400 once the stacks are placed; peak private bytes +15 MB |
| Writing the map file: 2,000 dense / 4,000 sparse placements | 353 / 113 ms, measured on a first write, which encoded every art as each write now does |
| Admin rows, first call on 2,000 placements: by date / ckey / area / a search | 10 / 27 / 30 / 8 ms |
| Adding a placement to a full map (4,000): refused / room / evicting | 0.02 / 0.33 / 0.42 ms; evicting 100 placements of one art at the unique-art cap 13.9 ms |
| A player who owns no graffiti connecting | 0.02 ms |

The passes that got there:

| Pass | Before → after |
| --- | --- |
| The load benchmarks' tuning: encode lookup, blends without `sanitize_hexcolor()`, cached layer arts for jobs | composite two tiles adversarial 312 → 222 ms, one tile adversarial 138 → 101 ms; job step two tiles adversarial 184 → 135 ms; twenty jobs 1,154 → 700 ms/s; in one run, encoding a flattened art 12.10 → 3.19 ms and merging four layers 187.5 → 97.6 ms, byte for byte the same |
| The registry pass: per-ckey index, decoding once at init within a cap, the map file joined from encoded records, a native backup copy | cold / warm init 400 dense 7.1 / 2.9 → 3.0 / 1.4 s, 2,000 dense in stacks of five 26.1 / 22.2 → 18.4 / 15.6 s, 2,000 dense one-tile 35.8 / 17.6 → 21.0 / 9.9 s, 2,000 sparse 8.2 / 5.7 → 6.1 / 3.6 s; writing 2,000 dense 1,116 → 353 ms; admin rows by date 1,690 → 10 ms, by area 930 → 30 ms; adding to a full map refused / room / evicting 577 / 105 / 536 → 0.02 / 0.33 / 0.42 ms; a non-owner connecting 74-91 → 0.02 ms |
| The editor and paint-job pass: job steps under the work budget, incremental colour counts, library saves that flatten only the changed piece, live composites flattened from frames | composite typical 26.8 → 12.3 ms, one tile adversarial 69.6 → 34.3 ms, two tiles adversarial 161.9 → 79.9 ms; a 300-pixel stroke 4.4 → 2.3 ms; twenty jobs 547 ms/s in `SStimer`, +9.6% → 277 ms/s under the work budget, +1.5%; setting a job up 113 → 6.8 ms; the Unfinished entry rebuilt on each push 64 → 0 ms |
| The stroke and memory pass: masks read by character code, no per-point checks on a canvas that takes every pixel, history counts kept on the steps, the window's canvas encoding only the pixels a stroke changed and updates carrying only changed views, layer records kept between composites, each art held once, merges kept only while a tile is painted; in the window, the canvas left alone by brush changes and Custom Graffiti's rows memoised | a hundred studio editors +65.5% → +2.0% time dilation, 1,431 → 736 ms/s; a stroke 2.68 → 1.32 ms and its update 1.59 → 0.87 ms; a two-tile update 11.2 → 5.5 KB; twenty painters at the topic limit +22.4% → +11.2%, stroke handling 361 → 222 ms/s; a hundred freehand sessions +123% → +78%; a composite's layer records after a stroke on one of four layers 3.2 → 0.8 ms; at the caps the art's save copy 6.9 million characters → 0 and the decals' merges 13.3 million → 0, worst-case memory at the caps about 33 → 22.5 MB with one tile each and 42 → 16.5 MB in stacks of three; in headless Edge, an editor update 5.3 → 2.2 ms, a brush change 1.7 → 0.04 ms, the spray can's window with 50 pieces 19.9 → 2.0 ms an update |

On a live server (the live check: Runtime Station, a real DreamDaemon and DreamSeeker, five rounds): strokes reached
the wall 0.08-1.09 s after they were drawn, composites came exactly 1.5 s apart, a 32-strip paint job stepped about
every 1.4 s with every step from `SScustom_sprite_work` and the last strip only at the finish, and `SSgraffiti`
initialized in 0-24 ms (11 ms reusing both sheets). Later rounds loaded the same placements onto the same tiles and
reused the sheet files unchanged.

Accepted worst cases: loading a map tagged edge to edge with dense art takes about 21 s of work the first time its
sheets are drawn and under 2 s on later rounds, done in the background from the lobby on at a fifth of each tick (about
110 s and 10 s), its one piece too large to split being the file's `json_decode()`, up to about 1 s for the largest
file; with every painter's composites held to `GRAFFITI_COMPOSITE_SHARE`, twenty players each sending an 1,800-pixel
stroke every 0.3 s (about three a second, the minute topic limit) dilate time by under 1% and a hundred painting
freehand at that pace by about 3%, their walls updating every 7 and 10 s rather than 1.5 s, where without the share they
dilated it by 16% and 57-78%, their composites and strokes together taking one and a half seconds of work a second
(planning in the studio, a hundred at once take 2%); the strokes themselves, about 600 ms/s for a hundred painters, are
what is left; a chunk of adversarial art downloads up to 903 KB of sheets, where realistic art takes tens of KB; there
is no colour cap per tile, so merged stacks may reach thousands of colours; and with every tick full, paint job steps
may come late but are never dropped.

### TG Proc/File Changes:

One tg proc gains a branch, inside the custom sprites module's existing `APHELION EDIT ADDITION` block:
`code/modules/sprite_editing/workspace.dm`'s `can_transact()` checks no point of a compact stroke mask on a canvas that
takes every pixel (`all_points_allowed()`), as graffiti's does. Upstream tgui files carry `APHELION EDIT` markers:

- `tgui/packages/tgui/interfaces/Crayon.tsx`: imports `CrayonGraffitiTabs` and draws it at the top of the window, and
  while the Custom Graffiti tab is open draws only it, so the stencil sections aren't rendered beneath it.
- `tgui/packages/tgui/interfaces/common/SpriteEditor/Types/types.ts`: `SpriteData.noPaste`, inside the existing
  `APHELION EDIT ADDITION` block.
- `tgui/packages/tgui/styles/main.scss`: loads `interfaces/Graffiti.scss`.
- `tgui/packages/tgui/interfaces/common/SpriteEditor/index.tsx`: the canvas reads the brush from the store as a tool
  acts, so the colour picker's drag doesn't re-render it.
- `tgui/packages/tgui/interfaces/common/SpriteEditor/Components/AdvancedCanvas.tsx`: `pixelColor`, the colour a pixel
  is drawn in when not its own, which graffiti's canvas sets to `shownColor()`, so the layer being painted and a
  stroke's preview draw alpha as the rest of the window does while the tools keep the stored colours.

tg procs overridden from this module's files carry no markers: `/datum/map_template/load()`,
`/datum/controller/subsystem/persistence/collect_data()` and `/client/Destroy()` (see Modular Overrides).

Registration:

- `tgstation.dme`: the module's code and its defines file.
- `code/modules/unit_tests/_unit_tests.dm`: the six graffiti test files, inside the existing `NOVA EDIT ADDITION` block
  of `~nova` tests. `liver_nova.dm` and `symphony_moderation.dm` join the `APHELION EDIT` block of tests disabled for
  the var cap, and `tools/ticked_file_enforcement/schemas/unit_tests.json` lists both in `forbidden_includes`.

### Modular Overrides:

- `code/anchors.dm`: `/datum/map_template/load()`, which records templates loaded on station levels, whose turfs take
  no graffiti.
- `code/registry.dm`: `/datum/controller/subsystem/persistence/collect_data()`, which makes the map file's round-end
  save; `/datum/json_savefile/custom_sprites/graffiti/map`, the map file, with `write_text()`.
- `code/spraycan.dm`: `/obj/item/toy/crayon/spraycan`'s `ui_static_data()`, `ui_data()`, `ui_interact()`, `ui_act()`,
  `use_on()` and `examine()`, and `graffiti_enabled()`, `FALSE` on `/obj/item/toy/crayon/spraycan/hellcan`, `lubecan`
  and `mimecan`.
- `code/decal.dm`: `/obj/effect/decal/cleanable/crayon/custom`, a subtype of tg's crayon decal: `Initialize()`,
  `Destroy()`, `NeverShouldHaveComeHere()`, `examine()` and `update_overlays()`.
- `code/library.dm`: `/datum/json_savefile/custom_sprites/graffiti`, the custom sprites store held to `size_limit`:
  `write_file()`, `read_snapshot()`, `load_entries()`, `load()` and `save()`; and `/client/Destroy()`, which unloads
  the disconnecting account's library unless something holds it.
- `code/editor.dm`: `/datum/custom_sprite_editor/graffiti`, the custom sprite editor in graffiti mode: `New()`,
  `Destroy()`, `initial_package()`, `create_workspace()`, `create_preview_body()`, `emissives_allowed()`,
  `window_title()`, `rebuild_resources()`, `refresh_preview()`, `draw_waiting_views()`, `can_hide_parts()`,
  `current_package()`, `can_edit()`, `ui_status()`, `ui_interact()`, `ui_static_data()`, `ui_data()`, `ui_act()`,
  `editor_act()`, `draft_edited()`, `save_drawing()`, `ui_close()`, `costly_work_due()` and `run_deferred_work()`.
- `code/workspace.dm`: `/datum/sprite_editor_workspace/custom_sprite/graffiti`, one view of uniform RGBA layers
  (`dirs = 1`, `color_mode = SPRITE_EDITOR_COLOR_MODE_RGBA`): `New()`, `apply_step()`, `pixels_changed()`,
  `layers_changed()`, `stroke_layer_matches()`, `layer_edited()`, `used_colors()`, `validate_palette_color()`,
  `prepare_selection_placement()`, `sanitize_transaction()`, `transact()` and `reverse_transact()`.
- `code/placement.dm`: `/datum/graffiti_paint_job`, a `/datum/custom_sprite_work_owner`: `costly_work_due()` and
  `run_deferred_work()`.
- `code/poster.dm`: `/obj/structure/sign/poster`'s `update_overlays()`, `examine()`, `wash()`, `roll_and_drop()` and
  `on_placed_poster()`; `/datum/custom_sprite_editor/graffiti/poster` and `/datum/graffiti_paint_job/poster`, the
  editor and the paint job on a poster, overriding their parents' surface hooks (`surface_problem()`, `place_art()`,
  `end_surface()`, `leave_surface()`, `tile_background()`; `piece_records()`, `surface_valid()`, `paint()`,
  `credit_surface()`, `release_surface()`, `stopped_resume()`) and `New()`, `Destroy()`, `window_title()`, `ui_data()`,
  `editor_act()` and `start()`.

### Defines:

`code/__DEFINES/~aphelion_defines/graffiti.dm` holds the defines more than one file uses, tests included. A define only
one file's code uses sits at the top of that file and is undefined at its end: the editor's pacing
(`GRAFFITI_COMPOSITE_SPACING`, `_BUDGET`, `_SLOW_SPACING`, `GRAFFITI_PLACE_RETRY`, `GRAFFITI_SESSION_LIMIT`,
`GRAFFITI_PICKED_COLORS`, `GRAFFITI_WORK_COMPOSITE`) in `editor.dm`; the composite share and line grace, the save
debounce, the sheet states, the per-ckey unique cap, the read versions and the decode budget in `registry.dm`; the
reveal's timing in `placement.dm`; the alpha floor and the flat colour cap in `piece.dm`; the start cooldown in
`spraycan.dm`, the spray length in `sounds.dm`, the library's size limit in `library.dm`, the icon caches' size in
`render.dm`, the window layer in `decal.dm` and the poster looks kept in `poster.dm`. The budget defines and where their
values come from:

- `GRAFFITI_MAP_UNIQUE_CAP` 2,000: 2,000 dense art records of 3,670 bytes take 7.3 MB.
- `GRAFFITI_MAP_ART_BYTES` 5 MiB: the bytes of art a map keeps, each unique art's `pal`, `grid` and `glow` text counted
  (`SSgraffiti.art_bytes`, kept as art comes and goes), held like the unique-art cap: `add_placement()` evicts by rank,
  then refuses, and a load keeps the best-ranked placements whose art fits. About 1,500 dense one-tile arts or 400
  translucent ones of 1,000 colours (12-14 KB a tile) fill it, while typical art meets `GRAFFITI_MAP_UNIQUE_CAP` first.
  The owner halved it from 10 MiB on 2026-10-20: 10 MiB of art and 4,000 placements wrote about 13.5 MB, so 5 MiB writes
  about 8 MB, and the arts held at the caps fall from at most 10.8 MB to about 5.4 MB (derived from the measured 10 MiB
  figures, not measured again). Art that grows as it is painted can pass the budget by what the pieces being painted
  add; the next new art evicts back under it.
- `GRAFFITI_MAP_PLACEMENT_CAP` 4,000: a placement packs to about 271 characters, 1.1 million for 4,000, which take about
  1.2 MB (measured on a full map), and their decals at 2,261 bytes take 9.0 MB at worst, one tile each, or 3.0 MB in
  stacks of three. At the map's caps the module holds, besides its placement indexes, which weren't measured, the arts
  (at most about 5.4 MB under `GRAFFITI_MAP_ART_BYTES`), the placements 1.2 MB, the decals as above and the two icon
  caches 1.5 MB, since sheet files keep every other icon at 0 bytes of server memory: about 17 MB with one tile each and
  11 MB in stacks of three, from 22.5 and 16.5 MB with 10 MiB of art. Before the stroke and memory pass the registry
  also kept each art's save record (`art_text`, about the art's size again) and every stacked decal its merges (13.3
  million characters for 1,334 three-high stacks of 6.8 MB of art): about 33 MB with one tile each and 42 MB in stacks
  of three. So the pass halved the stacked layout, 42 to 16.5 MB, but took one tile each only from 33 to 22.5 MB, short
  of half; what remained was the arts and decals the caps allow, which halving the art bytes took on.
  Each art is held once as its list and encoded at every save, about 50 ms more a save on a full map, rather than as its
  packed text decoded on demand, because a dense record takes 3,670 bytes as a list against about 3,500 as text, under
  0.5 MB at the caps, while every use would decode the text again: `json_decode()` of about 3.5 KB, about 0.07 ms going
  by the 150 ms an 8 MB map file takes, before the 1.2 ms grid decode a merge needs, or a decode cache holding about 20
  KB a dense art. A load adds up to `GRAFFITI_DECODE_BUDGET` (8 MiB) of decoded art while it runs.
- `GRAFFITI_DISPLAY_BUDGET`: `GRAFFITI_MAP_UNIQUE_CAP`, so everything within the caps shows.
- `GRAFFITI_CKEY_UNIQUE_CAP` 200 and `GRAFFITI_CKEY_PLACEMENT_CAP` 400: a tenth of the map's caps.
- `GRAFFITI_ICON_CACHE` 128: 128 dense art icons of 4,801 bytes take 0.6 MB, and 128 glow masks of 6,930 bytes 0.9 MB.
- `GRAFFITI_SHEET_STATES` 32: of the packings whose sheet files stay within 256 KiB, the one with the fewest bytes a
  state on worst-case art: 1,791 bytes at 32 (largest sheet 113 KB), 1,811 at 64 (225 KB), and 128 reach 448 KB.
- `GRAFFITI_DECODE_BUDGET` 8 MiB: about 400 dense one-tile arts at about 20 KB decoded, which bounds what a load adds
  to the high-water mark. Keeping every decode was estimated at 40-140 MB on a full map.
- `GRAFFITI_SAVE_DEBOUNCE` 1 minute: a full map of dense art takes about 440-470 ms to write, and the round-end save and
  `Shutdown()` still write the last changes.
- `GRAFFITI_PLACE_RETRY` 10 s: set when a refused placement on a full map read every placement (577 ms each, 2.1 s for
  the first composite after a load); the per-ckey index has since brought a refusal down to 0.02 ms.
- `GRAFFITI_LIBRARY_WRITE_PACE` 20: 50 adversarial pieces take 139 ms to write on average and 209 ms at most, 14-21% of
  the server's time at one write a second; twenty times a write's cost holds an account to 5%.
- `GRAFFITI_MAP_MAX_BYTES` 16 MiB (a full map of dense art writes 7.6 MB), `GRAFFITI_LIBRARY_MAX_BYTES` 2 MiB (50
  adversarial pieces write 1.74 MB) and `GRAFFITI_PIECE_MAX_BYTES` 32 KiB.
- Pacing: `GRAFFITI_COMPOSITE_SPACING` 1.5 s, `GRAFFITI_COMPOSITE_BUDGET` 600 and `GRAFFITI_COMPOSITE_SLOW_SPACING` 10
  s; `GRAFFITI_START_COOLDOWN` 3 s; `GRAFFITI_SESSION_LIMIT` 15 minutes. `GRAFFITI_COMPOSITE_SHARE` 100 ms a second,
  with a `GRAFFITI_COMPOSITE_SHARE_BURST` of 100 ms, of every painter's composites together: a typical one-tile
  composite takes 11-15 ms, so about ten painters keep the full spacing and more take turns. Set 2026-10-20 against the
  hundred-painter benchmark, which it took from +57.2% to +3.0% time dilation on one build (the share held open as the
  "before"), and twenty adversarial painters from +16.0% to +0.8%. `GRAFFITI_COMPOSITE_LINE_GRACE` 1 s: the composite
  line is first come first served, which without it gave twenty painters 3 to 11 composites a minute each and with it 8
  or 9; a painter that stops asking for a second gives up its place, so one no longer due never holds the line.

The rest set the piece format (`GRAFFITI_MAX_*`, the widths and height, `GRAFFITI_FLAT_MAX_COLORS`, `GRAFFITI_FORMAT*`),
stacks and costs (`GRAFFITI_STACK_CAP`, `GRAFFITI_LIBRARY_CAP`, `GRAFFITI_COST`), the reveal (`GRAFFITI_REVEAL_*`),
anchors (`GRAFFITI_ANCHOR_*`, `GRAFFITI_MISS_LIMIT`), map file versions (`GRAFFITI_MAP_VERSION`,
`GRAFFITI_MAP_READ_VERSIONS`), surfaces (`GRAFFITI_KIND_*`), the layer of graffiti on windows (`GRAFFITI_WINDOW_LAYER`),
glow kinds (`GRAFFITI_GLOW_*`), paths (`GRAFFITI_*_DIRECTORY`), the placement index (`GRAFFITI_INFO_*`),
`GRAFFITI_WORK_COMPOSITE`, `GRAFFITI_SPRAY_LENGTH`, the editor's picked colours (`GRAFFITI_PICKED_COLORS`) and
`GRAFFITI_ADMIN_PAGE`. The alpha ceiling and floor (`GRAFFITI_ALPHA_CEILING` 204 and `GRAFFITI_ALPHA_FLOOR` 51, 80% and
20%) mean every piece of graffiti lets the wall show through, a piece keeps an alpha only for paint chosen below the
ceiling, and no paint is too faint to see.

### Included files that are not contained in this module:

Data, all under `data/graffiti/`:

- `maps/<map key>.json`, with `.bak` and `.new`: `version`, `art` (hash -> `w`, `pal`, `grid`, `glow`, `k`), `stacks`
  (`print`, `keys`: signature -> stack key and glow kind), `placements` and `seen` (ckey -> ten-digit unix seconds). The
  map key is the map's name in lowercase with `_` for anything but letters and digits (`graffiti_file_key()`).
- `sheets/<map key>/<hash>.dmi`: the map's sprite sheets.
- `library/<first letter of the ckey>/<ckey>.json`, with `.bak` and `.new`: `version`, `next_id`, `pieces` (id ->
  `piece`, `created`, `updated`, `thumb`) and `unfinished`. An empty library has none of the three.

Custom sprites code changed for this module (Aphelion's own, unmarked):

- `modular_aphelion/modules/custom_sprites/code/persistence.dm`: `load()` copies entries through
  `/datum/json_savefile/custom_sprites/proc/load_entries()`, whose default keeps the character slots, so the graffiti
  store reuses the parent's recovery and copies its own entries. That store overrides `write_file()`,
  `read_snapshot()`, `load_entries()`, `load()` and `save()`.
- `modular_aphelion/modules/custom_sprites/code/limits.dm`: `/datum/custom_sprite_work_owner`, the parent of the custom
  sprite editors and of the paint job, with `costly_work_due()`, `costly_work_waits()` and `run_deferred_work()`.
  `SScustom_sprite_work` queues owners, and an editor's `costly_work_waits()` keeps the rule that a rebuild's drawing
  never waits once its body is built. `/datum/custom_sprite_pace` gains `graffiti_composites`.
- `modular_aphelion/modules/custom_sprites/code/workspace.dm`: `/datum/sprite_editor_workspace/custom_sprite` declares
  `dirs = 4` and `color_mode = SPRITE_EDITOR_COLOR_MODE_RGB` as type defaults, which its `New()` passes on, so the
  graffiti workspace sets its own. For the stroke path: `all_points_allowed()`, each history step's recorded
  pixels kept on the step, and the window's canvas encoding only the pixels a step changed (`pixels_changed()` takes the
  step's points; `canvas_code_lists`, `canvas_patches`). A view keeps the points of at most
  `CUSTOM_SPRITE_MAX_PATCH_STEPS` (16, `code/__DEFINES/~aphelion_defines/custom_sprites.dm`) steps, and no more points
  than it has pixels, before it is encoded whole, so a hair appendage's hidden view, which the window isn't sent, holds
  no more however long a modified client paints it.
- `modular_aphelion/modules/custom_sprites/code/limits.dm`: compact stroke masks read by character code through
  `custom_sprite_mask_tables()`, and cut down to the slots a canvas allows as they are read
  (`custom_sprite_mask_points()`'s `allowed`, from the workspace's `stroke_mask_slots()`, null but on a poster's
  canvas), so a poster's strokes need no check of each point.

Used as they are:

- `modular_aphelion/modules/custom_sprites/code/`: the editor and workspace it builds on; `codec.dm`
  (`custom_sprite_encode_grid()`, `custom_sprite_decode_grid()`, `custom_sprite_index_values()`,
  `custom_sprite_canvas_code()`); `images.dm` (`custom_sprite_cache_put()`); `transfer.dm`
  (`custom_style_unknown_key()`, `custom_style_transfer_begin()`, `custom_style_transfer_end()`,
  `custom_style_send_text()`, `GLOB.custom_style_transfers`).
- `icons/blanks/32x32.dmi`, `sound/effects/spray.ogg` and the module's `sound/paintcan_shake.ogg`.

Tests and tgui:

- `code/modules/unit_tests/~nova/graffiti/`: `codec.dm`, `editor.dm`, `library.dm`, `persistence.dm`, `placement.dm`,
  `poster.dm` and `workspace.dm`.
- `tgui/packages/tgui/interfaces/CrayonGraffitiTab.tsx` (the spray can's tabs), `GraffitiEditor.tsx` (the editor in
  graffiti mode) and `GraffitiAdminPanel.tsx` (the Graffiti Manager), with tests of the first and last.
- `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/`: `AlphaBar.tsx`, `GraffitiFields.tsx`,
  `GraffitiThumb.tsx`, `InlineColorPicker.tsx`, `LayerPanel.tsx`, `LayerStrip.tsx` and `graffitiCodec.ts`, with tests
  of `AlphaBar`, `InlineColorPicker` and the codec; the shared editor's `index.tsx`, `Palette.tsx` and `types.ts` gain
  its graffiti mode, and its `canvas.ts` the views an update leaves out (`fillSentViews()`, tested in
  `canvas.test.ts`).
- `tgui/packages/tgui/interfaces/common/SpriteEditor/Types/Tools/Select.ts`: `paste()` does nothing on a canvas with
  `noPaste`.
- `tgui/packages/tgui/styles/interfaces/Graffiti.scss`.
