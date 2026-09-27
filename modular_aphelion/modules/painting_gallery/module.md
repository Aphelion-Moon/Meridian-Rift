## Art Galaxy and painting persistence

Module ID: PAINTING_GALLERY

### Description:

Art Galaxy is installed on standard PDAs. **Browse** and **My Artwork** open as
thumbnail lists with 24 paintings per page; selecting a painting opens its details with an uncropped,
pixel-scaled image that fits the available window space. Browse retains searches,
and both views support downloads and console printing. My Artwork lets the
signed-in player manage website visibility from either the list or the detail
view, regardless of who owns the PDA. Each viewer keeps separate navigation, so
another person inspecting the same PDA cannot reset their personal artwork view.
Every change checks `creator_ckey` on the server before saving.

Finalizing a canvas saves it privately to **My Artwork** immediately, without a
website prompt or a frame. Its author can publish or withdraw it using the
checkbox. Character signatures, including anonymous signatures, remain separate
from account ownership. **A Brush with Greatness** rewards successfully enabling
publication for an owned saved painting; imports and loading existing records do
not award it.

Accounts can store **500 unique paintings**, counting personal, framed, imported,
and website-public artwork together. Copies and additional frames do not consume
extra slots. The native transaction checks the final collection under its writer
lock; oversized imports fail in full with a player-facing explanation. Deleting
artwork frees capacity. Historical collections above the cap remain readable and
editable, including visibility changes and deletion, but cannot grow further.
Legacy migrations preserve their existing artwork.

Personal saves carry no station rotation tags. An archive-enabled frame adds its
tag immediately, including when framing an already saved or printed painting.
Display-only frames never add rotation tags. Round-end archiving remains a fallback;
failed saves report a warning and can be retried through an archive frame. General
in-game browsing and AI portraits exclude personal-only saves.

My Artwork shows current frame counts separately from station rotation membership.
Deleting an owned painting asks for confirmation, including a warning that it will
remove all displayed copies and future station spawns. Only a successful transaction
removes the metadata, image, and framed copies; failure preserves them. Deletion also
withdraws website publication on the next publisher pass. Player-facing timing
allows 30 minutes: a 15-minute interval, up to 10 minutes processing, and five
minutes shared caching; service outages can take longer. Current-round deletion
markers and saved-canvas checks prevent surviving loose copies from restoring it.

Painting JSON stays at **version 3**. Optional `show_in_webgallery` accepts only
decoded JSON `true` or numeric `1` as public and saves numeric `0`/`1`. Missing
values remain private without rewriting the collection. Historical dates and
unknown metadata are preserved; duplicate-only imports leave bytes, timestamps,
images, and backups unchanged. Website publication follows its separate publisher
schedule, so an in-game save is not immediately visible online.

#### Nova imports and consent

**Imports default off.** Leave `ENABLE_NOVA_PAINTING_IMPORT` commented out in
`config/nova/config_nova.txt` until the deployment has been validated. It gates
automatic offers, Retry, and the **Prompt Nova Painting Import** admin verb.
Website visibility controls work independently when painting storage is writable.

Opening Art Galaxy offers an import once per account. The hidden
`nova_painting_import_answer` is preserved during character/preferences uploads:

| Event | Saved answer | Result |
| --- | --- | --- |
| Missing preference | Unset | Eligible for an automatic offer |
| Valid source has no matching paintings | No, if previously unset | No more automatic offers |
| Explicit No | No | No more automatic offers |
| First prompt closes or disconnects | Unchanged | No import |
| Explicit Yes | Yes | Continue the confirmed import |
| Source unavailable or invalid | Unchanged | Report failure |
| Import fails after Yes | Yes | Offer manually confirmed Retry |

After confirmation, **Make these imported paintings public on the web gallery?**
offers **Yes / Let me choose individually**. Cancelling or disconnecting here
continues the authorized import with visibility off. Yes affects only new records.
One flow runs per ckey across devices. Existing records, pending canvases,
current-round deletions, and existing destination images take precedence.

An `R_ADMIN` administrator may prompt an online player again after a previous
answer. Fresh player confirmation is always required. Issuing a prompt starts
separate 60-second cooldowns for the administrator and target, retained through
reconnects within the round. Initiation and outcome are logged.

#### Backup staging

Paths are relative to the game working directory:

| Purpose | Path |
| --- | --- |
| Live metadata and images | `data/paintings.json`, `data/paintings/images/<md5>.png` |
| Private recovery state | `data/paintings/.store/` |
| Read-only Nova source | `config/nova/paintings.json`, `config/nova/paintings/images/<md5>.png` |

Stage into an offline checkout using the actual extracted backup paths:

```powershell
powershell.exe -NoProfile -File tools/painting_store/stage-nova.ps1 `
  -BackupMetadata 'D:\verified-backup\data\paintings.json' `
  -BackupImageRoot 'D:\verified-backup\data\paintings\images' `
  -RepositoryRoot 'C:\Meridian-Rift'
```

The script copies exact metadata and referenced PNGs into Git-ignored, read-only
files. It rejects links and divergent destinations, preserves matching files and
unrelated `config/nova` contents, and publishes metadata last. An interrupted
initial copy can be rerun. Never commit the real backup or stage into a running
server's source tree. Restrict filesystem access to trusted operators.

The native helper validates the complete source and decoded PNG pixels before
importing. Limits are 64 MiB/100,000 metadata records and 1 MiB per PNG; supported
sizes are 11x11, 19x19, 23x19, 23x23, 24x24, 36x24, and 45x27. The game's MD5
identifies artwork; it is not a checksum of the PNG file.

#### Native dependency and deployment

BYOND needs a **32-bit** painting-store library on both Windows and Linux.
Rust is pinned to 1.89.0; use the checked-in lockfile. Build from the repository root:

```powershell
# Windows: Visual Studio C++ tools with x86 libraries and the Windows SDK
rustup toolchain install 1.89.0 --profile minimal
rustup target add --toolchain 1.89.0 i686-pc-windows-msvc
./tools/painting_store/build.ps1
```

```sh
# Linux: gcc-multilib and 32-bit glibc development/runtime support
rustup toolchain install 1.89.0 --profile minimal
rustup target add --toolchain 1.89.0 i686-unknown-linux-gnu
bash tools/painting_store/build.sh
```

The scripts run native tests and place the DLL or `.so` beside the game DMB.
Windows deployments verify the committed `meridian_painting_store.dll` against
`binary-manifest.json`; rebuilding changes the manifest, so commit source,
manifest, and binary together. Linux builds from locked source; use the oldest
supported glibc runner for releases. Deploy the library with the next game compile,
never replace one loaded by a running DreamDaemon.

Full builds, server runs, DM tests, TGS, and packaged CI artifacts include the
helper. Compile-only `dm` and map jobs do not. AutoWiki skips painting persistence.
Missing/incompatible libraries or failed verification must stop deployment or
disable writes visibly, without reverting to the old file writer.

#### Transactions and recovery

All painting mutations use one subsystem queue after player dialogs finish.
The native worker locks storage and checks the expected snapshot SHA-256, stages
verified JSON/images, writes a durable journal, promotes images without overwrite,
then atomically replaces JSON as the commit point. Deletions commit metadata
before removing images; unfinished cleanup is retried. Explicit field changes
preserve untouched native JSON values and unknown fields. Nova commits recheck
the confirmed source hash and copy original records with only visibility changed.

Recovery runs before loading paintings. It completes committed cleanup or restores
the verified prior snapshot, using transaction-owned image evidence. An unexpected
valid database change stops writes for investigation. A damaged collection is
never replaced with an empty one. `data` resolves once for TGS junctions; descendant
links are rejected. Keep resolved roots stable while the game runs. These guarantees
require local storage with atomic replacement, durable flushes, and hardlinks
(NTFS/ext4); keep normal external backups as well.

If recovery fails, stop the affected runtime before manual changes. Preserve an
external copy of the JSON, images, complete `.store` directory, and logs. Diagnose
the journal and hashes; do not delete the journal to bypass a check. `last-good.json`
contains the previous exact bytes and their SHA-256. Verify any restoration with
its associated images and rerun recovery on an isolated copy before service resumes.

For protocol changes, see [the API entrypoint](../../../tools/painting_store/src/lib.rs)
and [transaction implementation](../../../tools/painting_store/src/store.rs).
API 1 exposes `info`, `snapshot`, `submit_commit`, `poll`, and `cancel` through
`painting_store_call`; filesystem work runs off the BYOND thread. Successful
commits with pending cleanup still require runtime state to refresh. Failed polls
cancel collection; unpolled jobs expire after one minute. Queued abandoned jobs
are skipped, while a running transaction finishes under the same writer lock.
Late results report `expired`, requiring a fresh snapshot before retrying. Up to
four completed results remain collectible for five minutes, outside the active-job
limit; successful polls remove their result immediately.

#### Maintenance and validation

TGUI receives only the active thumbnail page or one detail record, with no unused
image dimensions or hidden-tab collection. Dates and medium are sent only for
owned details, and only the visible page or detail image assets are sent to the client. Optional state and owner payloads are lazy. Commits invalidate search/owner caches;
status changes refresh only open Art Galaxy views. Portrait assets are registered
when new images appear. Keep this separation when adding UI features.

Before activation, run the native build/tests on each supported platform, focused
DM gallery tests, TGUI typechecking/build, and
`tools/painting_store/tests/stage-nova.tests.ps1`. Use isolated data to check duplicate
no-ops, mixed imports, interrupted recovery, ownership, and both cancelled prompts.
In BYOND, verify PDA installation, reconnects/admin cooldowns, changes across two
open galleries, and midround image availability. Confirm website consent handling
before enabling imports in the intended runtime; leave the branch default off.

The approved moth artwork is `icons/achievements.dmi`, state `public_painter`.
Preserve its native 76x76 size and the exact symmetrical Misc achievement frame
from `icons/ui/achievements/achievements.dmi`; do not redraw or scale the circle.

### TG Proc/File Changes:

These integration edits retain their original code in `APHELION EDIT` comments; replacement behavior lives in this module where possible.

| Existing file | Purpose |
| --- | --- |
| `code/controllers/subsystem/persistent_paintings.dm` | Load consent/raw metadata, initialize recovery, and route saves/migrations through the queue |
| `code/modules/art/paintings.dm` | Track pending canvases; save finished canvases privately; transact archive, patronage, and frame changes |
| `code/modules/admin/painting_manager.dm` | Transact edits/deletions after dialogs |
| `code/modules/modular_computers/file_system/programs/portrait_printer.dm` | Add authenticated owner data/actions and validate stale selections |
| `code/modules/modular_computers/computers/item/pda.dm` | Install Art Galaxy once, including curator PDAs |
| `code/modules/asset_cache/assets/portraits.dm` | Keep portrait assets available when the collection starts empty |
| `modular_nova/modules/preferences_import/code/_sanitise.dm` | Preserve the local account import answer |
| `tgstation.dme`, `code/modules/unit_tests/_unit_tests.dm`, include schemas | Register production code and conditional tests |
| Build/CI/TGS scripts | Build, verify, and package the native runtime dependency |

### Modular Overrides:

- [code/art_galaxy.dm](code/art_galaxy.dm): portrait printer `New`, `Destroy`, `ui_interact`, and `ui_close`.
- The remaining `code/` files add subsystem, canvas, preference, admin, asset, and
  achievement helpers; [painting_gallery.dm](../../../code/modules/unit_tests/~nova/painting_gallery.dm) isolates
  consent, migration, and transaction behavior.

### Defines:

- `code/__DEFINES/paintings.dm`: `PAINTINGS_DATA_FORMAT_VERSION` and
  `NOVA_PAINTING_IMPORT_ANSWER`.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/ArtGalaxy/`: frontend; `NtosPortraitPrinter.tsx`
  remains the interface discovery entrypoint.
- `code/datums/achievements/painting_achievements.dm`: definition discoverable by
  the existing website catalog; award logic and icon remain in this module.
- `tools/painting_store/`: native helper, build/verification scripts, and staging
  tool; `meridian_painting_store.dll`: Windows runtime dependency.
- `config/nova/config_nova.txt`: disabled import flag; `.gitignore`: private backup
  and native build-output exclusions.
