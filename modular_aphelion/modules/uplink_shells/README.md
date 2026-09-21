# Uplink Shells

Module ID: UPLINK_SHELLS

Implementation baseline: `dd4b69bcc5f0d33a82b071d3f44fa75f332192f7`, branch `ai-roundstart-uplinks`.
The supplied [amended workplan](workplan.md) is retained as design input. The user's
execution instruction is development and compilation only; automated tests, live
portability checks and the in-game acceptance matrix are deferred to the user.
Compilation is not evidence of runtime acceptance or release qualification.

## Implementation contracts

The registry belongs to the continuing mind; the core and current personal chassis
are bindings. Registration, active session and pending request have independent
generations. Death revokes live capabilities, not historical allocation. Medical
recovery never initiates a mind transfer. A canceled undelivered replacement retains
its deadline. Fresh construction is separate from live appearance application.

### Compatibility policy

| Category | Existing path and policy |
| --- | --- |
| Physiology | `/datum/species/synthetic`; fixed robotic limbs, oil and native synthetic organs. No organic species powers. |
| Body shape | `body_type` preference and `bodypart.change_appearance`; retain presentation on synthetic limbs. Non-renderable anatomy falls back to the previewed humanoid chassis. |
| Colors/hair | Existing color, skin tone, hair and facial-hair preference applicators; preserve rendering values. |
| Markings | `preferences.body_markings` to `dna.body_markings`, deep copied; do not run augment middleware. |
| External features | Existing mutant-choice/color applicators and mutant-bodypart renderer; preserve supported cosmetic parts. Mechanical external abilities are excluded. |
| Pronouns | `gender` preference; preserve. |
| Voice/presentation | Existing voice preferences; retain approved presentation without importing employment, banking or mind data. |
| Quirks | Not installed. Report normalization in preview. |
| Augments | Not installed. Explicitly report conflicts; brain, synthetic internal organs, left power cord and right toolkit are reserved. |
| Middleware | `limbs_and_markings.apply_to_human` installs augments and species middleware can change anatomy; do not invoke blanket `apply_prefs_to`. Apply an explicit appearance policy instead. |
| Live customization | Apply appearance only to existing physical parts; no set_species, organ installation, outfit or resource initialization. |

### Baseline manifest

Initial and replacement construction consume one outfit/builder definition.

| Output | Slot/mount and starting resources | Salvage policy |
| --- | --- | --- |
| Synthetic chassis | `/datum/species/synthetic`, its normal internal organs, Uplink brain replacing synthetic brain | Normal medical/salvage interactions; body is never deleted by retirement. |
| Fuel cell | `/obj/item/organ/stomach/synth`, `NUTRITION_LEVEL_FULL` | Normal organ salvage and EMP damage; charging uses existing `COMSIG_PROCESS_BORGCHARGER_OCCUPANT`, no repair allowance. |
| Clothing | `/obj/item/clothing/under/color/grey`, uniform; `/obj/item/clothing/shoes/sneakers/black`, shoes | Transferable ordinary clothing. |
| Backpack | `/obj/item/storage/backpack/industrial`, back | Transferable; never copy old contents. |
| Toolkit | Narrow `/obj/item/organ/cyberimp/arm/toolkit/toolset` subtype, right arm | Six persistent cyborg tools; existing no-material handling, no exportable loose tool supply. Native welder fuel/refilling, no extra speed multiplier. |
| Power cord | `/obj/item/organ/cyberimp/arm/toolkit/power_cord/left_arm` | Native synthetic power arrangement. |
| Camera | Narrow `/obj/machinery/camera/silicon` subtype inside chassis, SS13 network | Current personal authorization only; stop feed on retirement, retain hardware. No container visibility bypass. |
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
effects retain their existing timing and costs. Runtime portability and every
operation-level acceptance check remain unverified until the user's test pass.

## Build and validation

Repository entry point: `tools/build/build.bat`. `dm` compiles DM plus required icon
and behavior-tree build inputs; the default build also compiles TGUI/fonts. Do not
use `all`, `test`, `dm-test` or run a server during this implementation pass.
New module `.dm` files require explicit `tgstation.dme` includes.

## Rollout and recovery

The feature is disabled by default. Uncomment `ENABLE_PERSONAL_UPLINK_SHELLS` in
`config/game_options.txt` to permit issuance. `UPLINK_REPLACEMENT_DELAY` is in
deciseconds (default 3000). Disabling issuance does not disable safe return or
remove delivered bodies. No server has been started or configured for deployment.

Only the AI job spawn hook grants personal entitlement. The management action
follows the mind through control transfers. A snapshot is built privately for
preview; confirmation publishes that same body and its contents in one allocation
commit. Before that commit, cleanup deletes only objects in the private delivery
container. The body is never reconstructed on confirmation. Preference or loadout
eligibility changes require a new preview. Replacement uses the frozen blueprint
with baseline equipment only. No worn items, backpack contents or resource state
are copied from the old body.

Replacement acceptance safely returns only an occupied personal endpoint, retires
its registration immediately, and starts the retained deadline. Cancel/resubmit
uses the same not-before time. A blocked delivery can be retried after clearing a
connected floor tile in the core's area. A bounded flood search prefers a reachable
`/obj/effect/landmark/uplink_delivery`; no map files are changed. Map-specific
clearance and practical exit routes still require the deferred in-game check.

Core death cancels pending work while preserving allocation history and the
committed blueprint. Normal revival and compatible brain surgery restore
availability, never automatic control. Registry VV actions provide inspection,
safe return and retry of a ready request without resetting claims. Return/AI View
invalidates control callbacks but preserves personal body observation; retirement
invalidates personal tools and camera as well. A nearby crew member can request
attention from the body's examination link. Logout stows tools and closes service
interfaces; it does not issue or retire a body.

## Limits and intentional physical salvage

Supported cosmetic external categories are tail, ears, snout, horns, frills,
spines, fluff, synthetic chassis/head/screen/antenna and moth markings. Humanoid
synthetic limb mechanics are retained while supported species sprites, gender,
height, skin/color, hair, markings and voice settings are applied. Unsupported
body sprites/anatomy (including additional limb layouts), species mechanics,
quirks and saved augments are excluded and reported as normalization in preview.
Live Self-Actualization customization changes existing presentation only; missing
physical parts stay missing and the committed replacement blueprint is unchanged.

Retired bodies, synthetic organs/fuel cells, clothing, backpacks and overflow
containers remain normally salvageable. Camera hardware remains but loses the
personal feed; its ordinary dismantling can yield camera components. These are
intentional repeat-issued physical outputs behind the replacement delay. Issued
tools and the toolkit/camera have no raw custom materials; normal toolkit removal
and organ salvage remain possible. Approved fresh charge and welder fuel are
replacement supplies, not a refill of an existing body. The issued toolkit cannot
be used with stale authorization or emaged to add a weapon. No economy-wide
salvage rules or acquired items are modified.

The operation inventory above covers built-in AI services and already acquired
AI actions. Arbitrary third-party/downloaded computer programs are not guaranteed
to support a separate viewer; programs that require a directly attached client or
mind need individual runtime qualification. Camera tracking and remote camera
controls use normal AI View, not a shell renderer. Unsupported z-levels produce an
explicit core-view fallback; same-region uncovered locations retain camera masks.

## Validation record and shared-code scope

Changes are uncommitted on `ai-roundstart-uplinks`; HEAD remains the baseline SHA
above. There is no new implementation commit SHA yet. The workplan is design
input, not authorization to deploy or run its testing phases.

Source inspection covered registry/session boundaries, original cyborg deployment,
brain removal, core damage/power/death, job allocation, loadout eligibility,
synthetic organs/recharging, existing toolkit resources, TGUI ownership, AI click
range, radio delivery and built-in HUD service entry points. Early structural DM
compilation and an integrated default DM/TGUI build succeeded. The final compile
command is `tools/build/build.bat dm tgui-tsc tgui`; its output is retained locally
in `data/uplink-build/final-compile.log` (an ignored build artifact).
Final result: exit 0; BYOND 516.1687 compiled DM with 0 errors and 0 warnings;
TypeScript compilation and the Rspack TGUI bundle succeeded. `git diff --check`
also passed. No test target was invoked.

Shared hooks intentionally generalize `deployed_shell` and connect/return to living
endpoints. Damage/mains-loss persistence applies to Uplink brain sessions, while
ordinary cyborg failure policy remains. UI/radio adapters are conditional on active
Uplink sessions; shuttle availability uses the active controlled player's client.
Core-owned malf state survives shell transfers, and removal resolves its owner
back to the core. Loadout delivery adds an optional private container and corrects
the existing per-item details lookup to use the selected preset's nested list.
The AI job retains its existing initialization before granting the registry.

No automated tests, DreamDaemon runtime, multiplayer portability probes, or AC-01
through AC-17 acceptance scenarios have been run. All are deferred by the user's
explicit instruction. Compilation establishes syntax/type/build compatibility,
not runtime correctness, operation parity, visual accuracy or release acceptance.
