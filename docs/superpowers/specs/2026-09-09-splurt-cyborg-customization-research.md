# SPLURT cyborg customization: source research and port specification

Research date: 2026-09-09. This document records source inspection, not compile, runtime, UI, or performance qualification. The companion [workplan](../plans/2026-09-09-splurt-cyborg-customization.md) defines implementation stages.

## Source identity and history

The requested character-creator feature is in **SPLURT PR #960**, not the checked-out SPLURT master. Its original title describes a narrower anatomy feature; the current patch adds a dedicated **Cyborg Character** page, preview renderer, layout presets, and runtime support.

| Source | Inspected revision / status |
| --- | --- |
| Meridian-Rift working tree | `aed808fbe309de11a14d574586745f6dad79a983`; no reported file changes before this research |
| Local SPLURT master | `d18c64e0980de5ba5ba3cb0c40e7ba6a1aea31d4`, September 6; feature files absent |
| [SPLURT PR #960](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960) | Open, unmerged, head `090a9cb13722af449567867c720826eb6af215a5`; API reported 77 changed files, 8,602 additions, 211 deletions and merge conflicts |
| Remote master lookup | `53a3e55966d0f25e084a24e8f3097398cb1062d9`; identified for freshness only, not the source snapshot analyzed |

The PR's current commit list starts with a rebuild on merged upstream, then replaces the earlier animation system and iterates on anchoring, alignment, layering and generated icons. Especially relevant are `d580b43e` (preview alignment), `78a7d4a9` (preview layering), and `7d409cea` (generated-icon cleanup). Port the pinned final source selectively; the original patch and intermediate commits are not independent, ready-to-apply features.

The [deployment-history comment](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960#issuecomment-4320543013) records test merges beginning April 25 and the last listed removal July 29. This establishes historical deployment, not current live deployment or acceptance. The [June performance report](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960#issuecomment-4728909807) alleges substantial time dilation while editing. The [August optimization proposal](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960#issuecomment-5186923495) calls for cached live state and normalization only at input/load/save boundaries. Those are reports and proposals, not measured results from this research.

Supporting lineage in master includes [PR #92](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/92), which generalized interactions to living mobs; [PR #312](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/312), addressing silicon interaction/examine initialization; and [PR #555](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/555), the older hardware resizer that #960 substantially removes. These explain dependencies; they are not instructions to transplant those whole systems.

## What the feature actually contains

### Three distinct kinds of saved or temporary state

1. **Character slot:** existing `PREFERENCE_CHARACTER` storage holds the cyborg name, silicon identity/lore preferences, six silicon sprite choices, `cyborg_size`, and `silicon_genital_layout_presets`.
2. **Layout presets within that slot:** the layout blob has `active`, up to ten named `presets`, and `model_defaults`. A preset copies only the six-slot layout. It does **not** copy name, lore, sprite choices, size, department, job preference or chassis selection. It is not an additional full-character slot.
3. **Editor session:** department, skin/model, preview pose, direction and preview arousal live on `/datum/preferences` as temporary preview variables. Choosing a department/model browses appearance; it does not set a saved spawn chassis or assign a job. Preview arousal does not activate the live robot's anatomy.

This distinction is a required UI contract for the port. A complete named cyborg identity library or automatic spawn-model selector would be an extension beyond the inspected donor behavior.

### Creator and controls

- `PreferencesMenu/CharacterPreferences/index.tsx` adds a top-level **Cyborg Character** page beside the ordinary character page. The implementation is a shared SPLURT component, re-exported through the interface folder.
- Two inner pages: **Visuals** and **Lore**. Identity includes cyborg name, silicon gender and custom model/species text. Lore includes silicon flavor text, optional adult flavor text, headshots, OOC notes and model lore.
- Visuals provides department and skin selectors with thumbnails, supported pose selection, cardinal rotation, zoom, panning/scrolling, background and body size.
- Body size snaps to five values: 75%, 100%, 160%, 200%, 250%. This is distinct from preview zoom and from each anatomy overlay's scale. The numeric preference declares finer steps, but middleware/runtime snap to the discrete list.
- Six configurable visual slots: penis, sheath, testicles, vagina, anus and breasts. Sprite selection has a `None` option and supports ordinary accessory assets plus cyborg-only sheets. Catalog choices are filtered by the donor's ERP settings.
- Each layout entry has base X/Y, rotation, scale and up to three color overrides. Advanced entries hold visibility, X/Y, rotation and layer priority per cardinal direction and supported rest pose; selected slots can also override these by arousal state.
- Donor limits: X/Y -128..128 in 0.01 increments; rotation -180..180 degrees; overlay scale 0.25..16; priority 1..10. There are reset, save/load/delete preset, and save/load/clear model-default actions.
- The creator supports idle/moving, rest, sit, belly-up and deep-rest where the skin actually supplies the states. Meridian additionally has alternate rest/sit states that need explicit handling.

### Persistence and application

- Creator layout changes use a deep-copied draft, dirty bit and a 20-decisecond delayed commit. Explicit preset saves persist immediately. A new middleware `flush_ui_state()` hook is called before UI slot change, duplication and close; cleanup deletes timers and preview objects.
- The blob base type only verifies that the input is a list. Feature-specific normalization handles nested layout shapes, numeric ranges, colors and the ten-preset limit. Normalization exists twice, in creator and robot code.
- Robot `Login()` loads sprite preferences and size, resets activation state, loads active layout, attempts a model-default lookup, and refreshes appearance. Live activation begins disabled for the configured slots; the interaction panel exposes toggles and arousal controls.
- Runtime methods provide preset/default operations and layout editing. Movement, direction changes and icon updates refresh/synchronize anatomy overlays; destruction deletes client image holders.

### Rendering and infrastructure

- A lightweight preview robot/catalog host bypasses normal robot initialization. Robot-model initialization also gains a special preview-host path to avoid constructing the normal tool inventory.
- Model snapshots read dynamically initialized `borg_skins`, icon overrides, states and size traits. The donor adds Research and special security availability logic that Meridian does not currently share.
- Preview combines a map-view object with composited image layers and base64 thumbnail/image data. It reuses live rendering calculations and owns bounded caches: 256 preview images and 128 rendered anatomy entries.
- Live overlays use `/obj/effect/client_image_holder` to show anatomy only to viewers with the player-level `see_cyborg_genitalia` preference enabled. Visibility, slot capability and viewer display preference are different states.
- Dedicated DMI animation markers and occlusion masks locate body anchors and let chassis pixels cover selected overlays. Family mapping is based on donor names, states and paths; it is not a universal renderer for arbitrary new borg art.
- Runtime includes DMI metadata reading/injection through rust-g, generated animation templates, frame timing, nearest-neighbor scaling, color composition, directional layering and caches. Some generation writes temporary DMI files.
- The PR changes batched spritesheet realization to guard concurrent generation. This is shared infrastructure with consequences outside the feature and needs separate review.
- Examine descriptions and the donor interaction panel consume configured anatomy. This rests on SPLURT's existing simulated-anatomy and living-mob interaction APIs.

## Donor gaps to repair or explicitly resolve

These are source findings at the pinned revision, except where marked as historical reports.

| Finding | Evidence and consequence |
| --- | --- |
| Model-default keys disagree | Creator saves `lowercase(department#skin)` at middleware lines 1315/1579; runtime reads `lowercase(cyborg_base_icon)` at robot lines 2248-2276. Use one identity function for both; creator-saved defaults otherwise do not match normal runtime lookup. |
| RoboTact is unfinished | `NtosRobotact.jsx:963` defines `RobotactReproductionManagement`, but the complete file contains no mounted use. The PR-head `code/modules/modular_computers/file_system/programs/robotact.dm` supplies no reproduction data/actions. Treat this as scaffolding, not working donor parity. |
| Creator/runtime preset rules diverge | Creator prompts for 24 characters and normalizes excess presets by truncation; runtime accepts 32 and explicitly refuses an eleventh new entry. Standardize names, overwrite semantics, limits and cancellation behavior. |
| Expensive work can run outside the cyborg page | Middleware `get_ui_data()` gates on the entire character-preferences window, not the active inner page. It prepares catalog/previews even for ordinary character editing. Add an explicit active-page/dirty-state protocol. |
| Rendering has high-cost paths | Runtime lines 3089-3114 perform nested pixel loops; layout reads normalize/deep-copy stores, image refresh scans players, animation generation reads/writes DMI metadata. Profile and bound these paths before claiming readiness; the existing caches alone do not establish acceptable performance. |
| Duplicated layout schema | Creator and live robot each define defaults, sanitation and normalization. Shared helpers are needed to prevent drift in fields, poses and fallback rules. |
| Visibility refresh needs lifecycle coverage | Getter scans `GLOB.player_list`; preference update triggers global refresh, while image holders have their own seer lifecycle. Verify new viewers, client replacement, ghosting, reconnect, deletion and display-toggle changes explicitly. |
| UI filtering is incomplete | The creator's hidden-pref set omits `silicon_anus_sprite` while the page renders it. Derive filtering from a single registry. Do not remove AI controls with the donor's removed Silicon Preferences tab. |
| Preview/default matching is not robust to arbitrary skins | Catalog and family detection depend on initialized names, suffixes and file paths. Historical reports mention unavailable Dullahan selection and disappearing diagonal overlays. Test current Meridian skins and all eight directions; do not claim those reports reproduce at this head. |
| Resizing is a gameplay change | #960 replaces the old resize-module workflow and directly adjusts size/upgrade flags on login. Meridian has shrink/expand restrictions and special models. Keep an explicit eligibility rule; arbitrary imported size must not bypass it. |

## Meridian entry points and compatibility map

Paths below are relative to the Meridian repository and were inspected at the revision above.

| Concern | Current entry points | Port consequence |
| --- | --- | --- |
| Character UI | `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/index.tsx`, `MainPage.tsx`, `names.tsx`; `PreferencesMenu/types.ts` | Add the dedicated page and typed payload. Adapt to our existing tabs and preference buckets; preserve AI and ordinary character controls. |
| Preference dispatch | `code/modules/client/preferences.dm:179` (`ui_data`), `:236` (`ui_act`), `:379` (`ui_close`); `code/modules/client/preferences/middleware/_middleware.dm` | Middleware is already discovered/used by preferences. Add explicit cyborg-page activity and a flush contract; avoid unconditional preview generation. |
| Save/load lifecycle | `code/modules/client/preferences_savefile.dm:372`, `:437`, `:478`, `:501`; Nova save hooks in `modular_nova/master_files/code/modules/client/preferences_savefile.dm` | Slot changes, deletion, new slots, imports, UI close and destruction must flush/discard the correct draft. Meridian `save_character()` has no donor force argument and is non-sleeping. |
| Native import | `modular_nova/modules/preferences_import/code/_sanitise.dm:58`, `:186`, `:243`; `import_verb.dm`; `modular_nova/modules/admin/code/preferences_loadverb.dm`; `code/modules/unit_tests/~nova/preferences_import.dm` | A list-only blob validator is insufficient. Normalize on deserialization as well as UI writes, enforce nesting/count bounds, and include native player/admin import tests. |
| Existing identity | `code/modules/client/preferences/names.dm:103`, `silicon_gender.dm:6`; Nova `preferences/flavor_text.dm:21`, `:32`; `preferences/headshot.dm:61` | Reuse existing keys. Our headshot key is **`silicon_headshot`**, donor uses **`headshot_silicon`**. Silicon-specific OOC/custom-model lore and optional second headshot need new entries/fallbacks. |
| Current examine/directory | `modular_nova/master_files/code/modules/mob/living/examine_tgui.dm:112`; `modular_nova/modules/customization/modules/mob/living/silicon/examine.dm`, `topic.dm`; `modular_nova/modules/character_directory/code/character_directory.dm:256` | Our type is `/datum/examine_panel`, accessed via `mob_examine_panel`, not donor `examine_panel` calls. Preserve existing headshot validation and viewer display settings. |
| Preview and sprites | `code/modules/mob/dead/new_player/preferences_setup.dm`; `code/modules/asset_cache/spritesheet/batched/batched_spritesheet.dm`; `code/__HELPERS/icons.dm:1187`; `code/__DEFINES/rust_g.dm:190` | Map-view, sprite accessories and rust-g metadata primitives already exist. A borg preview/catalog still needs a safe lifecycle and asset-generation policy. |
| Actual borg model selection | `code/modules/mob/living/silicon/robot/robot.dm:187`; `robot_model.dm:58`, `:246`; `modular_nova/modules/borgs/code/robot_model.dm` | Share eligibility/catalog data with live selection. Record a stable skin identity at selection, since model display names/icon states are mutable. Do not add donor Research/security rules or admin models accidentally. |
| Borg rendering | `modular_nova/modules/borgs/code/update_icons.dm:1`, `:16`; `robot.dm:1`; `robot_model.dm:11`, `:31`; `code/__DEFINES/~nova_defines/robot_defines.dm` | Meridian uses `update_quadborg()`, not donor `update_quadruped()/update_lightweight()/update_robot_rest()`. Preserve overlays cleared/rebuilt during rest, tip, wreck, light and hat updates. |
| Robot application | `code/modules/mob/living/silicon/robot/login.dm:2`; job, robotize, MMI, positronic and ghost-cafe paths | Apply after client/mind and actual appearance exist; refresh after model reset/skin change. Do not assume roundstart is the only path. |
| Disguises and special borgs | `modular_nova/modules/borgs/code/robot_items.dm:678`; `modular_nova/modules/ghostcafe/code/robot_ghostcafe.dm`; `modular_aphelion/modules/admin_tech/code/admin_robots.dm` | Temporary disguises change name/icon. Define display versus real model identity and restore without overwriting saved defaults or changing role capabilities. |
| Interactions | `modular_nova/modules/interaction_menu/code/interaction_component.dm:6`, `:16`, `:50`, `:79`, `:217`; `interaction_datum.dm:56`, `:92`, `:156` | Current component and action/effect code are human-specific. No `simulated_genitals` implementation was found. Generalize only through explicit participant capabilities and retain physical-organ-only operations behind human checks. |
| Existing anatomy | `modular_nova/master_files/code/modules/client/preferences/genitals.dm`; `modular_nova/modules/customization/modules/mob/dead/new_player/sprite_accessories/genitals.dm`; `modular_nova/modules/modular_items/lewd_items/code/lewd_organs`; `code/__DEFINES/~nova_defines/_organ_defines.dm` | Reuse accessory registry and existing slot defines, including sheath/anus. A defined slot is not an implemented silicon capability. Preserve our physical-organ visibility/layering controls. |
| Viewer images / runtime UI | `code/modules/hallucination/_hallucination.dm:90`; `code/modules/modular_computers/file_system/programs/robotact.dm`; `tgui/packages/tgui/interfaces/NtosRobotact.jsx` | Reuse image-holder lifecycle and RoboTact owner lookup. Both runtime UI payload and handlers must be implemented and tested. |
| Includes and tests | `tgstation.dme:7320`; `code/modules/unit_tests/_unit_tests.dm`; `tools/ticked_file_enforcement/schemas/modular_aphelion.json` | Put new module files in the DME and focused tests in the unit-test include list. No dedicated new native service is required by the inspected design. |

## Scope and design requirements

- Deliver the creator, silicon identity/lore fields, six visual slots, layout presets/defaults, size selection, live activation/rendering and interaction support as separately qualified stages.
- Keep storage within the existing character slots. Use a versioned, bounded layout schema; no database service or extra account-wide profile store is required.
- Keep donor semantics explicit: layouts are presets; department/model selection is preview-only. No job/loadout/law/AI-access changes are part of this feature.
- Preserve existing saved preferences and unrelated dirty work. Source/assets must be attributed to pinned donor revisions. New files belong under `modular_aphelion/modules/cyborg_customization/` with narrowly scoped core hooks.
- Start with Meridian's existing model catalog. Add required marker/mask/overlay assets for that catalog; do not transplant every Bubber/SPLURT skin or their department content.
- Repair the identified persistence/default/UI integration gaps during adaptation. Do not port the shared spritesheet lock or donor living-mob interaction system wholesale without an isolated reason and validation.
- Qualify performance on real BYOND. Source inspection, OpenDream, compilation and historical test-merge deployment are separate evidence classes.

## Pinned donor source index

- [Creator middleware and layout storage](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/modular_zzplurt/code/modules/client/preferences/middleware/cyborg_character.dm): catalog 1-222/412-603; schema 842-1081; actions/data 1236-1628; preview 1630-1957.
- [Preference lifecycle fields](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/modular_zzplurt/code/modules/client/preferences/cyborg_character_preferences.dm) and [silicon preference declarations](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/modular_zzplurt/code/modules/client/preferences/silicon_genitals.dm).
- [Creator UI](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/tgui/packages/tgui/splurt_components/CyborgCharacterPage.tsx): layout controls 431-844; page 873-1387.
- [Runtime, image holders, animation and layout operations](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/modular_zzplurt/code/modules/silicons/borgs/code/robot.dm): image holder 1-617; application 660-728; viewers 818-842; schema/defaults 2034-2276; rendering/scaling 2357-3372; runtime operations 3373-3672; overlay/direction hooks 3674-3772.
- [RoboTact UI scaffolding](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/tgui/packages/tgui/interfaces/NtosRobotact.jsx) and [RoboTact backend](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/blob/090a9cb13722af449567867c720826eb6af215a5/code/modules/modular_computers/file_system/programs/robotact.dm).
- [Changed-file inventory](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/960/files) includes DMI marker/mask assets, accessory flags, preference filtering, interaction bridges, examine changes and the spritesheet guard. This URL can drift; the source links above are pinned.
