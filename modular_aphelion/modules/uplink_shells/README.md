# Uplink Shells

Module ID: UPLINK_SHELLS

The [amended workplan](workplan.md) records the original design. The saved-body,
scrapping and AI control contracts below supersede its earlier restrictions.
Compilation and focused automated checks are separate from in-game acceptance
and release qualification.

## Implementation contracts

The registry belongs to the continuing mind; the core and current personal chassis
are bindings. Registration, active session and pending request have independent
generations. Death revokes live capabilities, not historical allocation. Medical
recovery never initiates a mind transfer. A canceled undelivered replacement retains
its deadline. Fresh construction is separate from live appearance application.

### Compatibility policy

| Category | Existing path and policy |
| --- | --- |
| Physiology | `/datum/species/synthetic`, oil and native synthetic organs, with compatible saved augments and quirks. No organic species powers. |
| Body shape | `body_type` preference and `bodypart.change_appearance`; retain presentation on synthetic limbs. Non-renderable anatomy falls back to the previewed humanoid chassis. |
| Colors/hair | Existing color, skin tone, hair and facial-hair preference applicators; preserve rendering values. |
| Markings | `preferences.body_markings` and per-limb styles are deep copied; native limb middleware runs only on fresh bodies. |
| External features | Existing mutant-choice/color applicators and visual organ regeneration install supported anatomy, including taur and wings. |
| Pronouns | `gender` preference; preserve. |
| Voice/presentation | Existing voice preferences; retain approved presentation without importing employment, banking or mind data. |
| Quirks | Enabled, species-compatible saved quirks. Visual quirks apply at publication; remaining effects initialize once after first connection. Datums stay on the body across reconnects. |
| Augments | Native compatibility checks and saved limb styles apply. AI brain, left power cord and right toolkit replace conflicting implants. |
| Middleware | Fresh-only `limbs_and_markings.apply_to_human`, visual organ regeneration and synthetic supplementary styling; no blanket `apply_prefs_to` or copied character mind. |
| Live customization | Apply appearance only to existing physical parts; no set_species, organ installation, outfit or resource initialization. |

### Baseline manifest

Initial and replacement construction consume one outfit/builder definition.

| Output | Slot/mount and starting resources | Salvage policy |
| --- | --- | --- |
| Synthetic chassis | `/datum/species/synthetic`, saved assembly and quirks, Uplink brain replacing synthetic brain | Retirement, body death, gibbing and dusting produce one scrap heap after returning control. Installed anatomy is dismantled. |
| Fuel cell | `/obj/item/organ/stomach/synth`, `NUTRITION_LEVEL_FULL` | Normal organ salvage and EMP damage; charging uses existing `COMSIG_PROCESS_BORGCHARGER_OCCUPANT`, no repair allowance. |
| Clothing | `/obj/item/clothing/under/color/grey`, uniform; `/obj/item/clothing/shoes/sneakers/black`, shoes | Transferable ordinary clothing. |
| Backpack | `/obj/item/storage/backpack/industrial`, back | Transferable; never copy old contents. |
| Toolkit | Narrow `/obj/item/organ/cyberimp/arm/toolkit/toolset` subtype, right arm | Six persistent cyborg tools; existing no-material handling, no exportable loose tool supply. Native welder fuel/refilling, no extra speed multiplier. |
| Power cord | `/obj/item/organ/cyberimp/arm/toolkit/power_cord/left_arm` | Native synthetic power arrangement. |
| Camera | Narrow `/obj/machinery/camera/silicon` subtype inside chassis, SS13 network | Current personal authorization only; dismantled with the body. No container visibility bypass. |
| Overflow | `/obj/item/storage/briefcase/empty` when needed | Transferable container; retains legitimate personal gear. |
| Physical credentials | None | No repeat-issued access card. Network authority remains the core's. |

### Control capabilities and source hooks

`ai_defines.dm` originally declares a robot-typed `deployed_shell`, while
`the_thing.dm` assigns a carbon and exposes `undeploy` only on its organ. The shared
session now owns deployment/return and endpoint-scoped cleanup. Ordinary robot
policy remains distinct from Uplink power/damage policy.

| State | Physical Uplink control | Network services | Return / issuance |
| --- | --- | --- | --- |
| Normal | Valid current session/body | Existing service permissions | Return allowed; issue only for entitled identity |
| Core damage, alive | Warn; keep control | Existing capability checks | Return separate from camera availability |
| Mains loss / restoration routine, backup usable | Keep control | Existing power restrictions | Return allowed; delivery blocked |
| Terminal death | End active session | Denied | Cancel requests, retain history; no resurrection |
| Ordinary core revival | Explicit revalidation | Normal existing rules | No automatic deployment or request resubmission |
| EMP / disabled wireless | End affected link | Denied | Safe return |
| Carding, mech/MOD transfer | End session through shared return | Existing transfer rules | No fresh entitlement |
| Brain removal/death while unattended | Change that body's availability only | No session authority | Never recall a different endpoint |

### Service inventory and origin

The verified wireless rule is `get_dist(src, target) <= interaction_range` in
`code/_onclick/cyborg.dm`, with inherited silicon `interaction_range = 7`.
The Uplink adapter additionally requires same-z, shell-visible targets and a live
session; device AI-disable/power/wire checks still execute on the original device.
Physical clicks are the default; rejected network clicks never fall through.

| Operations | Existing owner/source | Viewer and origin |
| --- | --- | --- |
| Read/select/state laws | `state_laws_ui`, core laws and radio | Carbon viewer; authoritative law state and speech remain core-owned |
| Transceiver settings, transmit and receive | Core radio | Carbon viewer; core channels, on/listening settings and permissions. The brain implant receiver is disabled during control to avoid duplicate reception. |
| Integrated messaging | Core modular interface and messenger | Carbon viewer; existing sender identity, stored messages and permissions |
| Manifest and crew monitor | `GLOB.manifest`, `GLOB.crewmonitor.show(core, core)` | Carbon viewer; core z-level and sensor permissions; camera tracking requires AI View |
| VOX and emergency shuttle call | `core.announcement`, `core.ai_call_shuttle` | Carbon viewer prompts; original core authority, cooldowns and reason checks |
| Alarms | `station_alert`, core alarm manager | Carbon viewer; original alarm scope |
| Bot list/control/waypoint | `robot_control`, core `bot_ref` | Carbon viewer; core z-level list, local validated interface/waypoint targeting |
| Core/status display, hologram presentation | Core picker datums / AI preferences | Carbon viewer; core-owned presentation state |
| Sensor overlays/status | Existing HUD traits; registry diagnostics | Shell-visible local overlays; core/borg status from original owner |
| Photography, camera and light | Core `aicamera`; onboard `/camera/silicon/uplink` | Photo origin is the shell; onboard light uses the existing camera luminosity. Remote camera jumps, tracking and multicamera require AI View. |
| Acquired special/malf actions | Existing core actions/module picker | Preserve original owner, costs/cooldowns and target rules; never grant locked modules |

TGUI retains the original core as the authority and sends its window to the current
shell client. UI actions, text/list/color/number/alert prompts and radial selections
revalidate the originating session. Local network clicks run the existing AI click
handler after the shell range/visibility check. Already committed native ability
effects retain their existing timing and costs. Service portability still needs
in-game verification with an attached player client.

The existing AI keybinding category contains unbound entries for services, verbs,
camera bookmarks, connections and acquired abilities. Both hotkey modes start
unbound; existing saved mappings remain intact. `commands.dm` is shared by the
menu and bindings. Cyborg authority requires a matching control session, and its
stun/lock restrictions still apply. Camera controls return to AI View first;
local targeting stays within the occupied endpoint's visible wireless range.
Safe return, private laws and diagnostics remain available without core services.

## Build and validation

Repository entry point: `tools/build/build.bat`. `dm` compiles DM plus required icon
and behavior-tree build inputs; the default build also compiles TGUI/fonts.
New module `.dm` files require explicit `tgstation.dme` includes. Native regression
coverage is in `code/modules/unit_tests/~nova/uplink_shells.dm`; the issuance and
replacement UI tests are in `tgui/packages/tgui/interfaces/UplinkShell.test.tsx`.
`tgui/packages/tgui-panel/statbrowser.test.ts` executes the shipped statbrowser
and checks bounded full-refresh acknowledgements, incremental tab changes and
selection recovery when a body transfer removes a category.
Run runtime checks in an isolated test world with external integrations disabled.
The Windows build helper uses BYOND's `dd.exe` console runner so test execution
waits for world shutdown and preserves its output.

## Rollout and recovery

The feature is disabled by default. Uncomment `ENABLE_PERSONAL_UPLINK_SHELLS` in
`config/game_options.txt` to permit issuance. `UPLINK_REPLACEMENT_DELAY` is in
deciseconds (default 3000). Disabling issuance does not disable safe return or
remove delivered bodies.

Only the AI job spawn hook grants personal entitlement. The management action
follows the mind through control transfers. A snapshot is built privately for
preview; a separately owned native character preview retains size transforms and
height filters. Confirmation publishes the prepared body and contents in one allocation
commit. Before that commit, cleanup deletes only objects in the private delivery
container. The body is never reconstructed on confirmation. Preference or loadout
eligibility changes require a new preview. Replacement uses the frozen blueprint
with its saved assembly, quirks and baseline equipment. Ordinary quirk supplies
are first-issue only; the original heirloom and identity skill grant are retained.
No worn items, backpack contents or resource state
are copied from the old body.

Replacement acceptance safely returns only an occupied personal endpoint, retires
its registration immediately, scraps the body and starts the retained deadline. Cancel/resubmit
uses the same not-before time, shown even when delivery is canceled. Management
reopens at the core after retiring an occupied personal shell. A blocked delivery
retains the prepared preview and can be retried after clearing a connected floor
tile in the core's area. A bounded flood search prefers a reachable
`/obj/effect/landmark/uplink_delivery`; no map files are changed. Map-specific
clearance and practical exit routes still require the deferred in-game check.

Core death cancels pending work while preserving allocation history and the
committed blueprint. Core revival and compatible surgery on a living shell restore
availability, never automatic control. Registry VV actions provide inspection,
safe return and retry of a ready request without resetting claims. Return/AI View
invalidates control callbacks but preserves personal body observation; retirement
invalidates personal tools and camera as well. A nearby crew member can request
attention from the body's examination link. Logout stows tools and closes service
interfaces; it does not issue or retire a body.

## Body configuration and scrapping

Supported external categories are tail, taur, wings, ears, snout, horns, frills,
spines, fluff, synthetic chassis/head/screen/antenna and moth markings. Humanoid
synthetic limb mechanics are retained while supported species sprites, gender,
height, skin/color, hair, markings and voice settings are applied. Unsupported
body sprites and organic species mechanics use the shown synthetic fallback.
Live Self-Actualization customization changes existing presentation only; missing
physical parts stay missing and the committed replacement blueprint is unchanged.

Retirement and body death dismantle the shell into an Uplink scrap heap. Worn
gear, loose possessions, storage-implant contents and occupants are released onto
the floor; ordinary containers retain their contents. Installed organs, limbs,
camera and toolkit are disposed with the chassis. Private preview cleanup creates
no scrap or loose possessions. Resume is attached to its target's lifetime, hides
when the body cannot connect, and is removed when that body is deleted.
Normal surgery remains possible on a living shell. Fresh charge and welder fuel are
replacement supplies, not a refill of an existing body. The issued toolkit cannot
be used with stale authorization or emaged to add a weapon. No economy-wide
salvage rules or acquired items are modified.

The operation inventory above covers built-in AI services and already acquired
AI actions. Arbitrary third-party/downloaded computer programs are not guaranteed
to support a separate viewer; programs that require a directly attached client or
mind need individual runtime qualification. Camera tracking and remote camera
controls use normal AI View, not a shell renderer. Unsupported z-levels produce an
explicit core-view fallback; same-region uncovered locations retain camera masks.

## Shared-code scope

Shared hooks intentionally generalize `deployed_shell` and connect/return to living
endpoints. Damage/mains-loss persistence applies to Uplink brain sessions, while
ordinary cyborg failure policy remains. UI transport uses captured Uplink or
cyborg sessions; shuttle availability uses the active controlled player's client.
Alt-click inventory uses the active viewer's client; portrait actions use the
authoritative AI UI owner even when its client controls a shell. Core radio
forwarding accepts department channels. Core-owned malf state survives shell
transfers, and removal resolves its owner
back to the core. Loadout delivery adds an optional private container and corrects
the existing per-item details lookup to use the selected preset's nested list.
The AI job retains its existing initialization before granting the registry.

Shared ownership boundaries:

- `code/modules/mob/living/silicon/robot/robot.dm`: `end_shell_deployment` owns cyborg-local cleanup for both native `undeploy` and `ai_shell_session.finish`; callers retain mind transfer and mainframe lifetime.
- `modular_nova/modules/loadouts/loadout_ui/loadout_outfit_helpers.dm`: an explicit `uplink_container` selects suitcase delivery without changing the preference snapshot.
- `code/modules/tgui/tgui.dm`: `get_config` resolves one transport client for each payload while retaining the original UI user as authority.
- `blueprint.dm`: `uplink_camera_available` owns the live registration, location and power checks used for both camera updates and access.
- `registry.dm`: the private delivery container owns unpublished contents through normal movable destruction; publication moves them out before disposing the container.
- `commands.dm`, `keybindings.dm`, `services.dm`: shared AI command dispatch, unbound preference entries and captured-session transport. Core AI/robot keybinding files preserve existing saved names; the former hardcoded AI camera keys are removed.
- `code/_onclick/cyborg.dm`: emits the session click signal after native stun/lock checks. AI visibility/waypoint hooks and TGUI/chat/radial adapters accept either authenticated endpoint type.
- `code/modules/client/preferences.dm`: `char_preview.update_canvas` renders an already-configured dummy without reloading its job/species preferences. The Uplink candidate owns and disposes its view.
- `html/statbrowser.js`, `code/modules/client/client_procs.dm`: full tab refreshes use one validated list acknowledgement; incremental updates and real Topic limits are preserved.
- Native/Nova quirk gift helpers, Spacer and Family Heirloom: first-issuance supplies without skipping physical initialization. Skilled records its identity grant; Underworld cleanup tolerates a returned mind; Big Boned reads the frozen body preferences.

The full AC-01 through AC-17 acceptance matrix, multiplayer service portability,
and measured gameplay performance require separate qualification. Focused checks
do not establish those broader guarantees.
