## Bug reports

Module ID: BUG_REPORTING

### Description:

**report-issue** (and the escape menu's Report Bug) opens an in-game report form when
`BUG_REPORT_BRIDGE_URL` is the loopback reporting bridge, `http://127.0.0.1:18764`; any other value
leaves the old GitHub link. The bridge, the reporting service and their limits are documented with
the backend; this module is the game's side.

- **Context is frozen when the form opens**: round, map, mob, area, versions, build and test merges,
  captured in `New()` before anything can yield.
- **Typing never reaches the server.** Unsent text is kept in the browser's tgui storage per report,
  so it survives the window closing. The form sends its text only with Submit, a screenshot or a
  snapshot, whole in one message (`capture/topic.ts`, see below).
- **The bridge sees one request at a time per report and eight across the server**, so no number of
  reporters can pile up rust-g jobs. We skip SShttp on purpose, it logs the bearer token and the text.
- **The window costs nothing while it sits open.** Autoupdate is off, every change pushes its own
  partial update, and `fields`/`context` ride the static data. One poll timer runs while the window is
  open and the report waits on the service (a check, an issue link, an image), backing off from 2 s
  to a minute, and stops when the window closes.
- **Cooldowns and hourly allowances mirror the service**, per ckey for the round, so a reconnect
  doesn't refill them: 5 accepted reports, 10 submissions with new text, 10 screenshots and 20 new
  reports an hour (the service allows 30, and refusing one there stalls everyone's registration). Bridge
  actions wait a second between them, Retry connection five, a snapshot ten, a Discord code a minute.
- **Screenshots**: BYOND's file prompt (PNG, JPEG or WebP to 10 MiB; `AllowUpload` lifts the limit
  for that one image), or a snapshot of one of the reporter's other open TGUI windows. The window
  rebuilds itself with html-to-image, shows a preview to crop, and sends the image back in 32 KiB
  acknowledged chunks that DM appends to a generated file with rust-g, never decoding or holding it.
  The bridge decodes and validates. The private preview comes back as a data URL (`rustg_hash_file`),
  never `browse_rsc`, which would keep every image in the player's BYOND cache for good. Public sharing
  needs the reporter to have seen that attachment's preview.
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

**Why the page posts its own messages:** tgui's `Byond.call` sends any URL of 2048 characters or more
as an XHR GET, which DreamSeeker 516 answers with a 404, so the message never arrives (tgui's act
chunking exists because of it). `sendLargeMessage()` posts through WebView2's `postMessage`, measured
byte-identical to 2.8 MB (lab `runs/bug-reporting-20261022/hardening/ds-topic-probe`).

### TG Proc/File Changes:

Edits to tg files keep their original code in `APHELION EDIT` comments.

| Existing file | Purpose |
| --- | --- |
| `interface/interface.dm` | report-issue opens the form when the bridge is set up |
| `code/modules/escape_menu/escape_menu.dm` | Report Bug shows without a GitHub URL |
| `code/modules/client/client_procs.dm` | `AllowUpload` takes one report screenshot past the upload limit |
| `code/modules/tgui/external.dm` | capture messages are bounded before their JSON is decoded |
| `code/modules/tgui/tgui_window.dm` | capture messages skip ui_act, and closing the window ends its capture |
| `tgui/packages/tgui/events/listeners.ts`, `handlers/suspense.ts` | capture messages, and a suspended window cancels its capture |
| `tgstation.dme`, `code/modules/unit_tests/_unit_tests.dm` | includes |

### Defines:

- `code/__DEFINES/~aphelion_defines/bug_reporting.dm`: `BUG_REPORT_UPLOAD_LIMIT` and
  `BUG_REPORT_CAPTURE_CHUNK`, the two tg files read. Everything else is file-local.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/BugReport/`: the form.
- `tgui/packages/tgui/capture/`: the snapshot, its preview and transfer, `topic.ts`, and the vendored
  html-to-image 1.11.13 (`vendor/`, unmodified).
- `code/modules/unit_tests/~nova/bug_reporting.dm`: guards, the capture protocol and its ready wait,
  allowances, fields, polling, an unconfigured server and crash cleanup, against a scripted bridge.
