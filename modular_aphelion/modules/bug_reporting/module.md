## Bug reports

Module ID: BUG_REPORTING

### Description:

**Report a bug** (OOC, and the escape menu's Report Bug) opens the in-game report window when
`USE_FANCY_BUG_REPORTING` is uncommented in `config/nova/config_nova.txt` and `BUG_REPORT_BRIDGE_URL` is the
reporting host's loopback address, `http://127.0.0.1:<port>`. Otherwise, and always for guests, it opens the GitHub
issue form as before. The flag ships commented out, and downstreams should leave it that way: the window
needs a reporting host on the same machine and three private settings (`BUG_REPORT_BRIDGE_URL`,
`BUG_REPORT_BRIDGE_TOKEN`, and `BUG_REPORT_SERVER_ID`, the name the host knows this server by). **View recent bug reports** (OOC) groups the last
20 reports from this connection into Drafts and Submitted, newest first. Drafts can be continued;
submitted reports only offer their GitHub issue, with Refresh for checks or publication still pending.
The list clears on disconnect. **Report a /tg/station bug** (OOC) opens /tg/station's GitHub form. The
bridge, the reporting service and their limits are documented with the backend; this module is the
game's side.

- **Four short pages**: Report title, Picture, Steps (numbered, with what should have happened, what
  it's about and how much it gets in the way) and Review report, then whatever the service answers:
  checking, sent back to the page it's about, too many this hour, couldn't reach the server, or sent
  with the GitHub link. The title, the steps and what should have happened are required, and the
  window and DM agree on empty: whitespace or a bare "1." counts as nothing.
- **Context is frozen when the window opens**: round, map, mob, area, versions, build and test merges,
  captured in `New()` before anything can yield. None of it goes to the window; the bridge gets it.
- **Typing never reaches the server.** Unsent text is kept in the browser's tgui storage per report,
  so it survives the window closing. The window sends its text only with Send, a picture or Keep,
  whole in one message (see below).
- **The bridge sees one request at a time per report and eight across the server**, so no number of
  reporters can pile up rust-g jobs. We skip SShttp on purpose, it logs the bearer token and the text.
- **The window costs nothing while it sits open.** Autoupdate is off. The whole data goes at open and
  after an act; any other update carries only the keys whose value changed, and nothing at all when
  nothing did. The list of open windows to capture goes at open, after an act, when the window gets
  focus and when a window capture ends. One poll timer runs while the report waits on the service,
  backing off from 2 s to a minute, and on the sent page at the receipt's own next try; it stops when
  the window closes.
- **Hourly allowances mirror the service**, per ckey for the round, so a reconnect doesn't refill them:
  5 accepted reports, 10 submissions with new text, 20 new reports (the service allows 30, and
  refusing one there stalls everyone's registration), 5 uploads of your own screenshots (spent once
  the file prompt gives one back), 30 captures and 60 saves of changed text. Acts that reach the
  bridge or check the text wait a second between them, Try again five, a picture's preview and a
  window capture ten, and an in-game capture thirty. Guests get the GitHub issue form instead, since
  every guest login is a new key with every allowance full again.
- **Pictures**, up to three a report (`BUG_REPORT_MAX_PICTURES`, the service's cap), each a tick box:
  - **In-game capture**: the server develops the reporter's view at its default size (a ghost's view
    range would cost several times more) the way the photo camera
    does (`/obj/item/camera/bug_report`, through tg's `camera_get_icon`, which yields between turfs
    for it), one render at a time per connection and two across the server.
  - **A window**: a snapshot of one of the reporter's other open TGUI windows, never a report window,
    named by its title, then its object's name, then "Untitled window". The window shows its copy in
    an overlay in its own theme: drag to crop, Enter adds it, Esc cancels. The report window comes
    forward when the picture arrives, which goes back in 32 KiB acknowledged chunks that DM appends
    to a generated file with rust-g.
  - **Your own screenshot**: BYOND's file prompt, PNG, JPEG, WebP or GIF to 10 MiB (`AllowUpload`
    lifts the limit for that one image).

  DM never decodes a file or a window's snapshot, it only stages their bytes; the in-game capture is
  the one picture it draws, and the bridge decodes and checks them all. The private preview comes
  back as a data URL (`rustg_hash_file`), never `browse_rsc`, which would keep every image in the
  player's BYOND cache for good. DM asks for a WebP on the preview call only and labels the data URL
  by the reply's `Content-Type`, so a bridge that only makes PNGs still works. New pictures default
  to public. **Keep this picture private** limits that picture to staff, even if its preview fails;
  switching back to public needs the preview. The choice survives refreshes and retakes and is sent with the report.
- **Snapshot limits**: the clone copies computed values, which already have every `var()` filled in,
  so CSS variables stay out (Aphelion's inherited base64 images made them 125 KB a node, and the
  Changelog's SVG 213 M characters, which killed its 32-bit renderer). `dom-snapshot.ts` refuses an SVG
  over `MAX_SVG_CHARS` (50 M characters; drawing costs about 20.5 bytes a character and the renderer
  dies near 2.5 GB) before its data URL exists, and a window over 5,000 nodes or 4,096 pixels a side
  the same way. A window refuses a second snapshot while it still draws one, even one whose
  capture the server already ended. The window sends `bug-report/capture-ready` once its overlay is
  up, with a preview or a failure, and the server ends a capture with no ready in 20 seconds, since a
  dead renderer takes the page's own 170-second timer with it. The 3-minute expiry stays for a capture
  left open.
- **Snapshot cost**: the clone writes only the properties a copy needs, what an author rule could set
  that the SVG wouldn't work out by itself (`capture/style-copy.ts`), and embeds only the font faces
  the page loaded, pseudo-elements' included, keeping a part-range face unless a drawn one covers its
  weight (`capture/font-faces.ts`). The copier was proven to change no pixel on a corpus of real
  windows, and the face filter only the boxes a pseudo-element draws, which now match the live page.
  A reused window's page keeps every face earlier interfaces loaded, so its snapshot can carry a few
  faces nothing on it draws: bigger, never different.
  Font Awesome goes out as WOFF2 (`modular_aphelion/master_files/html/font-awesome`), 170 thousand
  characters of a snapshot instead of 568.

**Why every tgui message is posted:** tgui's `Byond.call` sent any URL of 2048 characters or more as
an XHR GET, which DreamSeeker 516 answers with a 404, so the message never arrived (tgui's act chunking
exists because of it, and the topic limiter cuts chunked acts short). On a WebView2 client `Byond.call`
now posts every URL through `postMessage`, as BYOND's own page API does, measured byte-identical to
2.8 MB and in order, and `act()` skips
its chunking there. A client without WebView2 keeps the old path and the chunking. Since a posted
message can be any size, `tgui_Topic` drops one over 128 KiB before its JSON is decoded (the biggest
honest one is about 72 KB) and tells the player, the chunk assembler drops a chunked act past the same
128 KiB and checks its JSON first, and tgui-say counts a say's letters, not its bytes,
now that a long say in another alphabet arrives whole.

### TG Proc/File Changes:

Edits to existing files are marked `APHELION EDIT ... - BUG_REPORTING`; transport changes also
keep the `BYOND_POST_MESSAGE` descriptor. Changed lines retain their `ORIGINAL` code. Dedicated
shared files use `APHELION MODULE - BUG_REPORTING` headers. The include ownership lists sit before
`BEGIN_INCLUDE`, because Dream Maker manages that block and ticked-file enforcement requires exact
include lines. `helpers.min.js` is generated with `comments=false`; annotate `helpers.js` and rebuild
with `build:helpers`, without adding comments by hand to the generated copy.

The transport comes from `ac1a60cfe7f`, the shared Hephaestus display face from `debb86ecfa3`,
and the WOFF2 font override from `c80237473df`, all included in `2402f986f0a` (Aphelion SP4).
`5e94d7bfc1a` updates the report verb, and `e776cc919f1` adds the recent-report browser and its include.

| Existing file | Purpose |
| --- | --- |
| `interface/interface.dm` | Report a bug (OOC) opens the window when the bridge is set up (guests get the GitHub form), and reads "Report a bug" |
| `code/modules/escape_menu/escape_menu.dm` | Report Bug shows without a GitHub URL, in plain words |
| `code/modules/client/client_procs.dm` | `AllowUpload` takes one report screenshot past the upload limit |
| `code/modules/photography/camera/camera_image_capturing.dm` | `camera_get_icon` is protected, and can yield between turfs, for the in-game capture camera |
| `code/modules/tgui/external.dm` | capture messages are bounded before their JSON is decoded, and any message over 128 KiB is dropped |
| `code/modules/tgui/tgui_window.dm` | capture messages skip ui_act, closing the window ends its capture, and a chunked act past 128 KiB or with broken JSON is dropped |
| `code/modules/tgui_input/say_modal/speech.dm` | tgui-say counts letters, not bytes |
| `tgui/packages/tgui/events/listeners.ts`, `handlers/suspense.ts` | capture messages, and a suspended window cancels its capture |
| `tgui/packages/tgui-setup/helpers.js`, `tgui/public/helpers.min.js` | `Byond.call` posts every URL through WebView2's `postMessage` and sets `Byond.POST_MESSAGE`; the minified copy comes from the package's `build:helpers` |
| `tgui/packages/tgui/events/act.ts` | no act chunking when `Byond.POST_MESSAGE` is set |
| `tgui/global.d.ts`, `tgui/packages/tgui/__mocks__/byond.ts` | the flag's type and its mock |
| `tgui/packages/tgui/styles/meridianos/_index.scss` | loads the report and capture styles |
| `tgui/packages/tgui/styles/meridianos/_forge-materials.scss`, `_forge.scss` | shares Hephaestus's display face with report and capture headings |
| `tgui/packages/tgui/styles/meridianos/tests/selection-contrast.test.tsx` | report and capture readability checks |
| `tgstation.dme`, `code/modules/unit_tests/_unit_tests.dm` | includes, including recent-report history, the transport bound and the WOFF2 override |
| `biome.json` | excludes the vendored capture code; this strict JSON file carries no comment markers |

### Defines:

- `code/__DEFINES/~aphelion_defines/bug_reporting.dm`: `BUG_REPORT_UPLOAD_LIMIT` and
  `BUG_REPORT_CAPTURE_CHUNK`, which tg files read, and `BUG_REPORT_MAX_PICTURES`, which two of this
  module's files read.
- `code/__DEFINES/~aphelion_defines/tgui.dm`: `TGUI_MAX_PAYLOAD_BYTES`, the common bound for posted
  messages and assembled acts. Everything else is file-local.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/BugReport/`: the window.
- `tgui/packages/tgui/interfaces/BugReportHistory.tsx`: recent drafts and submitted reports.
- `tgui/packages/tgui/capture/`: the snapshot, its overlay, preview and transfer, the style copier
  and the font face filter, and the vendored html-to-image 1.11.13 (`vendor/`, our changes marked
  `Meridian:` and listed in its `README.md`).
- `tgui/packages/tgui/styles/meridianos/_bug-report.scss` (loaded by `_index.scss`): the window's styles
  in every theme; `_forge-materials.scss` names Hephaestus's display face and `_forge.scss` uses
  that same token for its existing headings.
- `modular_aphelion/master_files/code/modules/asset_cache/assets/fontawesome.dm` and
  `modular_aphelion/master_files/html/font-awesome/`: the WOFF2 override and generated font copies;
  the adjacent `README.md` records their source and regeneration steps.
- `tgui/packages/tgui-setup/helpers.test.ts`, `tgui/packages/tgui/events/act.test.ts`: every call posted
  once and verbatim on WebView2, the old paths without it, and a 30 KB act sent whole or chunked.
- `tgui/packages/tgui/styles/meridianos/tests/selection-contrast.test.tsx`: the window's text stays
  readable in every theme.
- `code/modules/unit_tests/~nova/tgui_say_cut.dm`: tgui-say's cut by letter.

The report window's own tests run against a scripted reporting service, and they're kept outside this repository.
