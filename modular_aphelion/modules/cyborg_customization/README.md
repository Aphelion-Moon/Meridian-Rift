# Cyborg customization

Cyborg customization adds a character-setup page, shared RoboTact and interaction controls, and a visual appearance layer for player cyborgs. Character slots remain the unit of identity. Each slot stores up to ten appearance presets plus defaults keyed by model type and skin label. A preview model is an editor choice; it does not select a playable model or grant equipment, access, laws, or anatomy.

## Boundaries and ownership

| Concern | Owner |
| --- | --- |
| Layout schema, normalization, and import migration | `code/layout_schema.dm`, `code/persistence.dm`; native preference import sanitation |
| Editor draft and request lifetime | `code/middleware.dm`; the middleware owns a slot-bound draft and guards work with `context_generation` and `draft_revision` |
| Durable layout write | `code/persistence.dm`, `code/save_queue.dm`; the `cyborg_customization.json` sidecar beside `preferences.json`, written by `SScyborg_layout_saves` |
| Model catalog and preview | `code/model_catalog.dm`, `code/preview.dm`; `CyborgCharacterPage.tsx` |
| Live appearance and geometry | `code/appearance.dm`, `code/rendering.dm`; a per-owner image holder uses shared static resources |
| Applying preferences to a body | `transfer_silicon_prefs()`, beside the brain, emote, blooper and chat-color preferences |
| Accessory data | `code/accessories.dm`; cyborg-only standard and direct accessory catalogs |
| Animation and occlusion data | `code/animation.dm`, `animation_manifest.json`, `code/asset_resources.dm` (the family masks) |
| Identity and runtime controls | `code/identity.dm`, `code/robotact.dm` |
| Message interactions | `code/interactions.dm`; audited human/cyborg message-only adapter |

Static catalogs, profile tables, and generated resource paths are shared definitions. Owner-bound image holders, viewer image attachments, and animation state are runtime state. Do not put a transient owner or client object into shared catalog data.

## Saved data and policy

Layouts are stored in `cyborg_customization.json` beside the account's `preferences.json`, keyed `character<slot>` like the custom-sprite sidecar, each character as one compact save text. They are not character preferences and never enter `preferences.json`. The layout schema is version 1. Its top-level fields are `active`, `presets`, `preset_models`, `model_presets`, and `model_defaults`. Each visual part can store sprite choice, position, rotation, scale, sprite size, colors, and optional directional, pose, or arousal overrides. The six visual slots are penis, sheath, testicles, vagina, anus, and breasts. Imported known values are normalized and bounded. A future schema is preserved and the editor refuses to write it. A donor file's `silicon_genital_layout_presets` slot key is moved into the sidecar during import, with its key aliases migrated, and stripped from the imported `preferences.json`. This layout schema is separate from the generated animation-manifest format version.

Ordinary edits debounce for two seconds. Explicit collection changes, leaving the page and a retry ask for a save at once. Saves run in `SScyborg_layout_saves`, never inside an action or timer: accounts in the order they asked, each staging the draft as it is by then and writing the account file, at most once per account every two seconds. What a save runs past the end of its tick comes out of a budget all players share, so many accounts saving together spread over ticks. Final teardown writes at once, and a slot change stages the old draft at once. Idempotent saves avoid copying and rewriting an unchanged snapshot. Preset names are trimmed to 24 characters, overflow is refused, and overwrite is explicit. A write succeeds when rust-g returns no error text.

The save text (`code/codec.dm`) writes each field only when it differs from its default, by position rather than by name, and marks which overrides exist so an override left at its defaults still hides its direction's. Decoding rebuilds the nested tree and runs the same normalization as before, so a reload is unchanged. An ordinary character takes about 3 KB, against 19 KB as nested JSON. Each character is limited to 32 KB of save text and 30 model defaults. Copies that would pass the limit are refused, and edits that pass it stay unsaved, with only shrinking edits allowed, until the slot fits. The limit holds any single layout, every override filled. All of an account's characters share a 1 MiB limit, checked when a character is saved, so neither the file nor what the server holds for an account passes it; a larger file is neither written nor read. Older nested slots still load and are rewritten as save text on their next save; text from a newer format is kept and never opened. Only the character being edited or spawned is decoded. Staging encodes the draft, so the saved revision never shares a list with it, and an external write to the editor's slot makes the editor stage its draft again before acknowledging it. Staging and the size checks of copies reuse the save text of each part left unchanged since the last encode, keyed by the part's list: edits and copies make a new list for a part they change, and a raw draft update drops these texts.

The middleware binds edits and debounce timers to the draft's character slot, page context, and draft revision. The account sidecar owns staged snapshots and its place in the save queue across slot changes and editor close; a failed slot write cannot be lost when a different draft opens. Stale draft timers cannot write a replaced slot or revision. Backend Preferences close explicitly stages and releases the editor. Guests and dev preferences keep the sidecar in memory, which the UI shows as session-only. Deleting a character removes its layout and drops its draft; an import replaces the whole sidecar; teardown writes any pending draft. Preference export does not include layouts, as it does not include custom sprites.

New presets snapshot selected sprites as well as layout. Older layout-only records keep their geometry and use current sprite preferences until resaved. Bound presets remember their chassis; legacy unbound presets and anonymous defaults remain loadable. The editor's model selection does not alter character model eligibility.

Configured appearance and size are captured for the body when `transfer_silicon_prefs()` runs: job spawns, ghost cafe and mapped ghost roles, mind transfers, admin Give Direct Control, and a ghost accepting control offered to ghosts. The same player re-entering the body keeps its snapshot; editor edits and reconnect do not replace it. Owner consent and the server ERP preference gate display; each viewer separately opts in through `see_cyborg_genitalia`, which defaults off. Runtime controls affect visibility and arousal, not the saved setup.

Visual slots do not create physical organs or grant anatomy-dependent actions. Supported message interactions are Cheer by cyborg actors and Cheer, Beckon, Headpat, and Pat by humans targeting cyborgs, under the audited distance and hand requirements. Surgery, insertion, vore, and anatomy-dependent sexual effects are not implied by visual configuration.

The optional second silicon portrait uses `silicon_headshot_nsfw`; the existing `silicon_headshot` remains canonical. The character fields `ooc_notes_silicon` and `ooc_notes_silicon_nsfw` stay separate from human notes; each falls back to its corresponding human field only when empty.

## Placement and preview contracts

Placement has North, South, and East/West groups for position and rotation. Unedited groups inherit legacy base values; ordinary controls edit the current group, while scale remains shared. `mirror_sides` mirrors side X and rotation westward. `reuse_south` can reuse south-facing art for north while retaining north placement and layer settings. Layer order compares accessory parts with one another and keeps them beneath authored body masks.

Fit recalculates preview bounds; Center moves the camera; 1:1 is intended to match the live DreamSeeker map zoom, against the fixed 32-pixel mannequin reference. Ordinary edits and rotation preserve framing. Preview zoom is independent of the saved body size. Requested base sizes are 0.75, 1, 1.6, 2, and 2.5; small chassis cannot shrink below 1, wide/tall chassis cap the base at 1.6, and unsupported special chassis use 1. Hardware scale remains a separate transform factor.

Wide bodies use independently authored North, South, and East/West placement. Animation anchors and view-specific offsets remain literal. Poses without authored anchors keep static placement and do not borrow another family's animation.

The creator sends private image resources through native static UI data. Its preference values go there too, again only when one of them changes. Ordinary updates carry current transforms, save state, preset names and the selected model's assignment; its saved default layout is sent only while viewing that layout. Saved preset bodies stay on the server. Fixed sprite and size choices use the existing round-wide preference JSON asset. Public gallery metadata and per-department thumbnails use immutable content-addressed JSON assets, acquired only when needed and reused by the browser. Gallery generation and acquisition complete before private state is captured. An absent consent-bound descriptor immediately hides gallery data; unfinished requests are cancelled when their last consumer leaves, and failures expose an explicit retry.

Pixel refreshes admit one latest state per second per editor; position, rotation and scale reuse current pixels. Metadata-only waiting does not freeze placement; pixel waiting preserves the old stage and matching geometry. A first model load has one weak completion per editor and keeps the public model picker available. Model completion rereads current state instead of retaining a draft. Revocation and slot replacement explicitly clear the static payload. Placement commands carry a context token and bounded base/pose/arousal targets; the server materializes inherited overrides and applies atomic coordinate changes. Frontend animation updates only the frame images and shared part anchor, leaving controls and part artwork outside the animation render loop. Frames omit byte-identical body or mask images and reuse the corresponding static image without changing delays or offsets. Elapsed-time playback catches up after a hidden page becomes visible and keeps its clock through unrelated resource updates; it introduces no periodic server requests.

The six cyborg profile text fields preserve their existing UTF-8 byte budgets without splitting characters. Their constant metadata advertises the actual inclusive limits, and the frontend enforces those limits after IME composition as well as ordinary input. Other text preferences retain their existing behavior.

## Assets, mapping, and provenance

`animation_manifest.json` holds the authored anchors. `models` maps each skin's `<chassis icon>#<base state>` to its family; `profiles.<family>["<pose>:<moving>"]` gives, per direction (`south`, `north`, `east`, `west`), one `{x, y, delay}` per frame of that chassis state. The server reads it from disk once (`GLOB.cyborg_animation_manifest`); it is not compiled into the .rsc, so `tools/deploy.sh` copies it. Six families cover 36 skins. Other skins, and any pose without an entry, keep static manual placement and no occlusion.

Live anchor motion uses a cached one-pixel native DMI per model, with the chassis's states, directions, movement variants and frame delays. Its private owner-relative image supplies a displacement filter on the composed parts. This preserves individual part transforms while BYOND selects movement frames and maintains their phase, including turns and stops. There is no server movement timeout or separate interpolated attachment loop. Transparent padding prevents edge clipping; a displacement size of 127 maps each color-channel step to one pixel. The creator also preserves authored sub-decisecond frame delays.

Occlusion draws the chassis's own sprite again above the parts and cuts it with an alpha filter. The filter's mask is the family's sheet in `icons/occlusion_masks/<family>mask.dmi`, shown to viewers only as a render target beside the motion map, so it follows the chassis's states, directions and movement frames natively. The masks are white; only their alpha counts. The editor preview multiplies the same mask frame into the body (`ICON_MULTIPLY`, cached with the other preview frames). `cyborg_occlusion_mask()` in `code/asset_resources.dm` maps each family to its mask icon and the mask's base state.

| Local skin labels | Donor family |
| --- | --- |
| Drake | drake |
| Borgi | borgi |
| Otie | otie |
| Vale, ValeDark | vale |
| Hound, Darkhound | hound |
| Alina | alina |

Catalog construction uses one transient null-location model item per allowed department, then deletes it; BYOND `initial()` does not return list-valued instance initializers. The audited null-host path creates no tools, storage or robot registrations; medical/miner overrides only append type paths before the guard. Cached descriptors hold copied lists and resources, never those items. The creator animates up to 32 frames locally; poses without anchors preview static. The live holder follows its owner and maintains viewer attachments through login/logout/preference events.

Caches are bounded: 512 body/occlusion preview frames with a 4 MiB encoded-data eviction budget; 128 standard accessory composites with a 2 MiB estimated byte budget; 32 direct-accessory frames. The public gallery creates one catalog JSON resource and one four-direction thumbnail resource per authored department, then releases its transient decoded thumbnail maps. The browser shares pending requests and reuses completed public data for its current catalog generation. Only the catalog and selected department are acquired; private editor updates carry descriptors instead of repeating the gallery. Creator size thumbnails are generated only for the selected part. The estimates exclude BYOND allocator overhead. They are bounds, not measured performance claims.

### Adding skins

A chassis state is `<base>` for idle and `<base>-<pose>` otherwise (`rest`, `sit`, `bellyup`, `rest_deep`, `rest_alt`, `sit_alt`); `<pose>:1` is its movement state, `<pose>:0` the still one.

A new skin of an existing family:

1. Add `"<chassis icon>#<base state>": "<family>"` to `models`, keys sorted.
2. Check the timing: every state the family's profile lists must exist in the skin's sheet with four directions and the same frame count and delays as the family's mask state (`<mask base>[-<pose>]`, same movement flag). `rustg_dmi_read_metadata()` or the PNG's `Description` text shows both. If any differ, or the parts sit wrong on it, the skin needs a family of its own.
3. Open the editor on the skin and turn it: the preview shows the parts placed and cut.

A new family:

1. Markers: a sheet with the chassis state's directions, frames and delays, transparent except one (51, 255, 255, 255) pixel per frame where the parts anchor. In a sheet `width` pixels wide, a marker at one-based `(px, py)` from the bottom left gives `x = px - width / 2`, `y = py - 24`.
2. Profile: under `profiles.<family>`, `"<pose>:<moving>": {"south": [...], "north": [...], "east": [...], "west": [...]}` with `{"x": x, "y": y, "delay": delay}` per frame, the delay as the sheet has it (deciseconds). Leave out a pose whose markers or mask differ from the chassis's timing; a still pose whose chassis also has a movement state needs that state too.
3. Mask: `icons/occlusion_masks/<family>mask.dmi` at the sheet's size, with one state per pose the profile authors (`<mask base>` for idle, `<mask base>-<pose>` otherwise) and the movement states it authors, each with the chassis state's directions, frames and delays. Opaque where the chassis covers the parts, clear elsewhere, RGB white.
4. Add `"<family>" = list('<mask icon>', "<mask base>")` to `cyborg_occlusion_mask()` and the family's skins to `models`.

The current anchors were derived this way from the donor's marker sheets (`modular_zzplurt/icons/mob/cyborg_animation_markers` at the commit below).

Donor source: [SPLURT PR 960](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960), pinned to [`090a9cb13722af449567867c720826eb6af215a5`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/090a9cb13722af449567867c720826eb6af215a5), open and unmerged when implementation began. Source adaptation follows AGPL-3.0; copied art is from the donor's CC-BY-SA-3.0 collection. Preserve attribution and source paths when redistributing or modifying the art.

| Local directory | Donor directory | Treatment |
| --- | --- | --- |
| `icons/occlusion_masks` | `modular_zzplurt/icons/mob/cyborg_occlusion_sources` | Selected family masks; alpha kept, RGB set to white |
| `icons/accessories` | `modular_zzplurt/icons/mob/sprite_accessories/genitals` | Selected accessory sheets |
| `icons/accessories/anus.dmi` | `modular_zzplurt/icons/mob/human/genitals/anus.dmi` | Exact sheet; cyborg-only Donut/Squished choices |

Dogborg source suffixes expose authored size variants independently of the shared continuous layout scale. Asset metadata supplies matching size icons and only the color channels present in the chosen variant. The massive sheet is an explicit choice. These assets do not modify the human accessory registry. Meridian's non-rendering human anus entry is omitted from this visual catalog.

## Core integration inventory

Module ID: `CYBORG_CUSTOMIZATION`. The core preference save path is untouched; layout persistence lives in the module's sidecar.

| Core touchpoint | Reason |
| --- | --- |
| `code/modules/client/preferences_savefile.dm` | One line beside the custom-sprite call: deleting a character removes its layout |
| `modular_nova/modules/preferences_import/code/import_verb.dm`, `_sanitise.dm` | Carry imported layouts into the sidecar; strip them and donor identity aliases from `preferences.json` |
| `modular_nova/modules/synths/code/bodyparts/organs/internal/brain/silicon_alt_brains.dm` | Apply customization in `transfer_silicon_prefs()`; also run it on admin direct control; keep the brain preference from runtiming on positronic processors, which skipped every later step; add the interaction component |
| `code/modules/mob/living/silicon/robot/robot.dm`, `robot_model.dm` | Holder teardown and facing, shared model list, chosen skin |
| `code/modules/mob/mob_helpers.dm` | `offer_control()` sends the direct-control signal after a ghost takes the body, as the admin verb does, so silicon preferences apply |
| `tools/deploy.sh` | Also copy `modular_aphelion`'s `.json` files, so CI and Docker deployments have the manifest the server reads from disk |

Revert the targeted frontend/backend protocol together, the middleware with `code/persistence.dm`, and the manifest with its reader. Layouts live in their own sidecar, so rollback leaves `preferences.json` untouched. Shared controls with the separate custom-sprite editor are deferred until both real consumers can be integrated.
