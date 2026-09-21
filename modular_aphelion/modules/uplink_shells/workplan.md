# Meridian Rift — Uplink Shells V1
## Implementation workplan and agent handoff

**Prepared:** 21 September 2026  
**Repository:** `Aphelion-Moon/Meridian-Rift`  
**Inspection baseline:** `master` at `dd4b69bcc5f0d33a82b071d3f44fa75f332192f7`  
**Revision:** 1.1 — approved review amendments integrated, 21 September 2026.  
**Status:** Approved V1 product direction and review amendments consolidated into one implementation handoff. The inspection baseline and source register are retained from the original plan; this amendment pass did not re-inspect the repository. No implementation, compile, or in-game validation has been performed as part of this handoff.

## 1. Mandate and scope

Give a player who joins the AI job a personally configured **Uplink Shell**: a synthetic carbon body with ordinary hands, clothing, inventory, and medical interactions. The shell is another embodiment of the existing AI, not a second character. Provide reliable access to AI services while embodied, and a convenient transition into the normal AI eye interface.

The first shell is available without research, construction by another player, or another player's approval. A lost or retired personal shell can be replaced. There is at most one current personal-shell registration per AI identity, not a lifetime limit of one body. Existing cyborg shells and crew-built Uplink Shells remain usable through their normal acquisition paths.

V1 includes preference-based appearance, optional initial personal loadout, replacement handling, connection lifecycle repairs, interface parity, the agreed physical protections, existing synthetic charging, an implant-style engineering toolkit, player guidance, and narrowly scoped administrative recovery.

**Do not add:** a field notebook; new repair machinery, maintenance hardlines, or live-core repair systems; work-order management; autonomous shell movement, following, or patrols; a new holographic-annotation system; independent AI survival after terminal core failure; a second camera renderer; or a complete cyborg module inventory. Existing AI capabilities are retained and integrated; speculative extensions from the earlier research are not V1 requirements.

Preserve existing synthetic-carbon wound, organ, surgery, treatment, and revival behavior except for the explicitly requested protections and connection-lifecycle integration. Charging is not automatic repair.

### Implementation priorities

Implement in this order: identity and lifecycle correctness, including an early portable-service feasibility check; a complete basic issuance/deployment loop; shell physiology and tools; full portable interfaces; replacement integration and release checks. Do not ship a spawn button while leaving emergency return, duplicate issuance, or player-identity problems unresolved.

Use the repository's normal BYOND/client deployment target. This handoff does not authorize live-server changes or deployment to WUFF. Revalidate the implementation branch against the inspection baseline before editing.

### Applicability and control invariants

| Concern | V1 scope |
|---|---|
| Free issuance, replacement, blueprint, and personal-loadout ledger | The entitled AI's personal-shell registry only. Crew-built shells do not acquire these benefits. |
| Physical protections | The configured Uplink chassis. An Uplink brain does not confer these protections on arbitrary hosts. |
| Issued engineering-tool restrictions | The actual issued toolkit and its authorized controller; do not change ordinary acquired tools or unrelated implants. |
| Safe connection, return, resume, and viewer routing | Supported cyborg and Uplink endpoints through the shared connection interface. |
| Changed core-damage and power-failure policy | Uplink endpoints, including existing crew-built Uplink connections. Preserve ordinary cyborg-shell failure policy; a shared cleanup fix is not permission to change that policy. |
| Existing crew-built acquisition | Remains independent of personal issuance, retirement, and replacement. |

An AI may retain a personal registration while operating its core or a different supported endpoint. There is at most one actively controlled endpoint per AI, and at most one current personal registration; these are different limits.

**Endpoint events are local:** an endpoint event may terminate only the active session belonging to that endpoint and session generation. Damage, retirement, surgery, or a delayed callback from an unattended personal shell must not disconnect a currently controlled cyborg, overwrite its resume state, or move the AI's mind. Identity-wide events such as terminal core failure are handled separately through the authoritative identity. Explicit successful deployment may change the resume target through the shared transition; unrelated endpoint callbacks may not.

## 2. Locked V1 behavior

### 2.1 Job entitlement and initial issuance

Grant a **Manage Uplink Shell** action after successful AI-job spawning, including roundstart and supported latejoin. Do not grant entitlement on every AI initialization: special/admin-spawned AIs and unrelated transformation paths should not acquire free bodies accidentally. The inspected AI job has an `after_spawn()` integration point. [S2]

Entitlement follows the continuing player/AI identity for this round. It survives logout, reconnect, and legitimate core transfers. Neither a replacement brain nor a newly created core resets the allocation or personal-loadout ledger. Ownership must not be keyed by display name or only by the currently occupied mob.

Before issuance, display the selected body profile, loadout preset, body preview, compatibility changes, and an **Include personal loadout** toggle. Do not force deployment into the new body. Once delivered, provide a direct connect/resume action.

Deliver at a designated safe location associated with the relevant AI start/core. Prefer an existing non-destructive delivery primitive or a simple spawn effect, not a new machine. Never use a random camera target, occupied blocking tile, damaging supply drop, or turf from which the shell has no practical route out. Support all maps/start locations on which this feature is enabled; provide a safe same-area fallback and a clear failure message when no location is valid.

First issuance has no research, resource, or five-minute replacement gate. Deliver a healthy, intact baseline body with normal full starting charge and toolkit supplies. Use the single issuance commit in section 2.3; a failed preview, provisional construction, or blocked delivery spends neither the initial issuance nor the personal-loadout allowance.

### 2.2 Preferences and the shell blueprint

Use the existing character/profile and selected-loadout systems. Create a validated, immutable candidate snapshot first, render the final preview from that snapshot, and ask the player to confirm that exact configuration. Capture the preset and its customization metadata, the loadout toggle, and compatibility adjustments as part of the attempt. A change to the selected profile, loadout, or compatibility result requires a refreshed preview and confirmation, not a silent change to construction input. Store the approved replacement blueprint only when the initial issuance commits. Do not keep a live reference to mutable client preferences or serialize an entire mob/mind/inventory as the blueprint.

Build a supported synthetic-carbon chassis, then apply compatible appearance. Preserve supported body shape, colors, hair, markings, external features, pronouns, and presentation preferences. Do not retain an organic species' hidden mechanics merely to keep its appearance, or force every profile into a generic IPC screen-head appearance. Reuse existing rendering/customization machinery; explicitly report any unsupported features and offer a previewed fallback before committing.

Default public identity to the existing AI. Allow a sanitized shell display label and supported voice/presentation choices, but keep AI ownership unambiguous in examination and diagnostics. Do not import another character's employment record, bank account, job, objectives, antagonist state, or mind. Keep radio/binary identity consistent with the controlling AI.

Species powers, quirks, augments, and mechanical preferences require an explicit compatibility policy. Default to the shell's fixed physiology and approved presentation options, not blindly applying every saved mechanical trait. Reserve the necessary internal organs and engineering-tool mount; report conflicts instead of silently discarding a player's selected augment.

Never modify the saved character to make it compatible. The preferences application path includes middleware and is broader than an appearance copier. Review both ordinary preference application and middleware effects. [S8]

Before implementing the builder, record an initial compatibility matrix for the selected synthetic chassis. Cover body shape, colors, hair, markings, external features, pronouns, voice/presentation options, species mechanics, quirks, augments, and reserved organ/mount conflicts. For each category, name the existing application path and whether the value is preserved, normalized, or unsupported, with a previewed fallback where needed. This is a working-tree inspection deliverable, not a claim that every category already has a compatible rendering path. Use one shared compatibility policy; do not fork species mechanics to support cosmetics.

**Replacement blueprint:** reuse the blueprint committed with the first successfully delivered body. In-place Self-Actualization Device customization must remain functional and preserve ownership, but must not silently rewrite the replacement blueprint or reissue equipment. No additional mid-round blueprint editor is required in V1.

**Separate fresh construction from live customization.** Share compatibility validation and appropriate appearance application, not a general procedure that reinitializes a body. Fresh issuance may install intact organs and equipment and fill approved starting resources. Live customization must preserve wounds, damage, missing limbs/organs, medical state, charge, welder fuel, and removed or damaged equipment. It must not heal the shell, recreate an organ/toolkit, or refill resources as a side effect of appearance normalization. Reapply only configuration-dependent protection/appearance state that is required, without resetting the physical state.

### 2.3 Personal loadout and baseline equipment

Create a dedicated baseline Uplink Shell outfit, separate from the optional personal loadout. Reuse `equip_outfit_and_loadout()` with the AI job as the eligibility context, the captured active preset, and the normal item customization hooks. Preserve permitted names, colors, skins, and settings rather than instantiating bare typepaths. Inspect nested preset/detail lookups when integrating; do not assume the outer preference list contains the selected preset's item metadata. [S9]

Respect existing item eligibility, access, content, and role restrictions. Do not equip a second job outfit. Place legitimate overflow in a delivery container; never delete personal gear merely because a slot is occupied. Essential shell clothing/equipment must remain available when the optional loadout is declined.

#### Authoritative baseline manifest

Define the repeat-issued baseline once and make both initial and replacement construction consume it. During Phase 0, identify the concrete existing typepaths and behavior needed for this manifest; Phase 2 is not complete with unspecified default gear. For each entry record its slot or mount, starting quantity/resources, transferability or integrated status, and intentional salvage/export behavior. Cover the following without adding an unrelated equipment inventory:

| Manifest category | Required decision |
|---|---|
| Chassis and essential clothing | Exact supported chassis, normal required organs, clothing, and occupied slots. Keep these independent of optional loadout. |
| Power | Existing synthetic fuel-cell type and normal full starting charge; no second battery model. |
| Engineering toolkit | The mount and six tools in section 2.7, their persistent resources, and issued-equipment restrictions. |
| Camera and existing sensor/light support | Exact onboard camera type/mount, authorized coverage, and retirement behavior; identify existing hardware actually required by the retained scanner/light interfaces. Do not assume extra gear or a new module system. |
| Delivery/overflow container | Existing safe container type and whether baseline delivery or legitimate loadout overflow needs it. Include it in the repeat-output review. |
| Physical credentials, if any | Explicitly record either no credential or the existing item and exact access it receives. Do not copy another character/job's credentials or grant a repeat-issued transferable elevated-access card as a shortcut to network parity. |

The original handoff does not establish the exact clothing, camera, container, or credential typepaths. Resolve these from the working tree and record the manifest before construction, rather than inventing repository facts or letting callers choose different defaults. Prefer existing supported AI-authorized interaction paths; do not introduce a new credential framework. Physical access and service authority remain distinct.

#### One issuance coordinator and commit point

The personal loadout is a **one-time decision at the first successfully delivered body**. Use an explicit ledger state: `not_committed`, `issued`, or `declined_at_first_issue`. Declining at a successful initial delivery closes the claim permanently; it must not leave an unused boolean claim for a replacement. Replacement always supplies only the approved baseline, never personal belongings, acquired upgrades, reagents, backpack contents, or copied credentials. Approved baseline starting supplies are not copies of the previous body's contents.

Use one small issuance coordinator, not separate independently committing body and loadout operations. Track provisional body/equipment work and loadout preparation within the same attempt, then commit them together:

1. Validate entitlement, request/attempt identity, the approved candidate or stored blueprint, and the relevant capability checks. Reserve the attempt so concurrent or repeated requests cannot proceed separately.
2. Construct and validate the body, baseline equipment, optional initial loadout, and any delivery/overflow container while they remain provisional and unavailable for player interaction. Track only objects created by this attempt.
3. Revalidate identity, authorization, request generation, and a safe delivery location immediately before publication. Publish the complete delivery and commit its registration, blueprint where applicable, request completion, and loadout outcome as one guarded operation, with no interactable uncommitted gap.
4. Before commit, failure removes only provisional feature-created objects and leaves entitlements/claims unspent. After commit, notification or connection failure must recover the existing delivered body, not repeat issuance or delete possessions that may have changed hands. Delivery and deployment remain separate.

Keep the ledger terminal after initial commit, including when opt-in produces no eligible personal items. Replacement consumes the same builder with personal loadout disabled and leaves that terminal ledger untouched. This is an in-round guarded state transition, not a new persistence service or general transaction framework.

### 2.4 Replacement and retirement

Expose replacement through Manage Uplink Shell. Use a **five-minute delay from accepted replacement request** as the V1 default, stored as a named/configurable value. This is an initial tuning choice, not a measured balance result. No escalating delay or fixed lifetime replacement count is required. Use the same self-service delivery route; do not add a new materials-production system or require another player to approve replacements.

**Retirement is immediate when the replacement request is accepted, not when its timer finishes.** Present that consequence in the confirmation. If the personal shell is actively controlled, complete a safe return to the authoritative core first. If that return cannot complete, reject the request without revoking its registration or starting a partially accepted request. After return and final revalidation, atomically retire the old personal authorization and accept the replacement deadline. A request concerning an unattended personal shell must not return the AI from another endpoint.

| Condition | Required result |
|---|---|
| Shell genuinely destroyed | Replacement can be requested; retire any remaining current binding when the request is accepted. |
| Shell dead but repairable | Present repair as an option; allow explicit immediate retirement and delayed replacement. |
| Shell missing, stranded, inaccessible, or otherwise deliberately written off | Allow immediate retirement with confirmation. Do not make recovery of an unreachable object mandatory. |
| Shell merely damaged/discharged | Show treatment/charging guidance; never automatically replace it. Deliberate retirement still requires confirmation and the replacement delay. |
| Request pending | Reject duplicates and show remaining time. The retired body is unavailable for personal deployment during that delay. Other normally available endpoints remain usable. |
| Deadline reached but delivery blocked or temporarily ineligible | Keep one ready request and allow safe retry without restarting its deadline or creating duplicates. Revalidate all delivery capabilities at commit. |
| Request canceled | Stop automatic delivery and invalidate that request's callbacks. Do not restore retired authorization, reset loadout history, or clear its stored not-before deadline. |
| Canceled request resubmitted before delivery | Create a new request generation using the retained not-before deadline. Do not restart the delay or allow earlier delivery; after that deadline, delivery may retry immediately if valid. |
| Original recovered after retirement | Its old authorization remains invalid. Repairing it or transplanting its old brain does not restore personal entitlement. |
| AI core terminally failed | Cancel the request; no replacement is delivered as an AI resurrection mechanism. Retain registry history as specified below. |

Keep retirement irreversible for that old personal binding, including through cancellation, core revival, and removed/reinserted brains. Revoke its registration generation and issued tool/network authorization before activating another personal body. Distinguish personal-registration generation, control-session generation, and replacement-request generation as specified in section 3.1. A canceled request's old timer cannot complete a newer request.

For the same still-undelivered replacement cycle, cancellation, disconnect, and ordinary AI revival retain the accepted not-before deadline; none creates an earlier delivery or a free first issue. A later replacement of a successfully delivered new shell starts a fresh five-minute delay. A ready request does not automatically deploy its owner, whether they are in the core or another endpoint.

Retirement does not remotely delete the body, erase injuries or evidence, recover items from other players, or teleport possessions. A retired body remains available for existing medical/salvage interactions. It cannot quietly re-enter service with the retired personal registration. Any later ordinary reuse must follow the existing supported construction/authorization path, not reuse stale personal tokens.

**Camera retirement:** a valid unattended personal shell may retain its normal permitted onboard-camera coverage, including during AI View. On retirement, end that personal shell's feature-issued Uplink-authorized camera feed without deleting the camera/body. Replacements must not accumulate authorized camera nodes through retired bodies. Later camera reuse requires the ordinary supported authorization/construction path. This does not revoke an independently acquired camera's legitimate ordinary authorization.

Review all repeat-issued manifest outputs together: tools, clothing, containers, organs/fuel cells, starting consumables, and camera hardware. Generated standard tools must not become export/recycling or loose-item duplication sources; reuse their existing no-material handling. Record intentional physical salvage and any residual implications for the other outputs. Apply bounded anti-duplication handling only to issued equipment as necessary, never to items acquired legitimately during the round. Do not disable normal organ removal, delete retired bodies, or introduce an unrelated economy rewrite. Approved fresh-body starting charge and toolkit supplies are legitimate replacement replenishment; resetting an existing toolkit on retraction or reconnect is not.

Maintain the request while the client is disconnected and revalidate identity/delivery conditions before completing delivery; do not deploy an absent player. Terminal core failure ends live authority and cancels pending delivery, but does not destroy the registry, blueprint, loadout ledger, or retained replacement deadline. Ordinary permitted AI revival may recover that same history and revalidate a non-retired current binding; it does not revive retired authorization, auto-resubmit delivery, auto-deploy, or reset claims.

### 2.5 AI View — normal AI eye, centered on the shell

**AI View is ordinary AI operation, not a separate remote-camera implementation.** Transfer the existing mind/client back to the real AI core and reuse its normal eye, HUD, camera networks, movement, tracking, multicamera support, and permission checks. The inspected eye uses the core's client, which supports this approach. [S4]

**Mandatory launch behavior: whenever AI View is launched from a shell, the primary AI eye opens centered on that shell's location at the moment of the request.** It must not open at the core, the last camera, or a previous tracked person's location.

Implement the transition in this order:

1. Validate the requesting player, matching endpoint/session, current body, safe-return capability, and availability of normal AI View. Do not infer these from a core-client or generic incapacitation check.
2. Capture `get_turf(shell)` before moving the mind or changing/deleting any shell references. Resolve the containing turf for a shell in a locker, recharger, vehicle, or other container.
3. Reserve the same body as the resume target. Retract issued tools safely and cancel shell-only held-input/targeting operations without changing inventory, damage, charge, or medical state.
4. Transfer the mind/client through the shared disconnect/return path. End the old control session and invalidate its inputs/UI callbacks, while preserving the current personal registration and valid resume target.
5. After normal AI login/HUD initialization, cancel stale tracking and bring the primary AI eye into focus. A previously active multicamera panel or holopad must not steal the initial focus.
6. Center the primary eye on the captured shell turf and correct z-level using normal eye/camera updates. Apply visibility masks immediately; do not expose one frame of unrestricted vision.
7. Present **Resume Uplink Shell**, its location/status, and relevant body alerts. Preserve existing camera bookmarks and secondary views where possible without overriding the required initial center.
8. Clear any transient transfer flag and ensure subsequent movement keys control the AI eye only.

No camera coverage means no extra visibility: the eye may be centered on a masked location. A powered onboard shell camera can supply only its normal permitted coverage. Closed containers, disabled cameras, hidden areas, network limits, and inaccessible z-levels must not become camera-visibility bypasses. If a location cannot legally be represented, show a clear reason and use a safe permitted fallback; do not silently substitute the core for an otherwise valid shell location.

Resume moves the same AI back into the same valid, authorized shell at its **current** location, even if somebody moved it. Resuming a previously paired shell does not require a fresh camera click or camera coverage, although genuine link/body/core failures still prevent it.

The existing **View Core** camera action stays separate: it moves the eye to the core, rather than implementing shell departure. Full core operation remains possible without immediately resuming a shell.

In AI View, the body is unattended, not invulnerable or autonomous. Normal external movement, restraint, damage, treatment, and charging still apply. Send meaningful damage, low-power, destruction, and explicit attention-request alerts without dragging the player back automatically on every hit. Normal AI audio/radio/holopad behavior applies; do not build a second shell-audio system.

Keep this passive body-observation relationship separate from active-session input/UI subscriptions. It must survive departure into AI View and may report the registered personal body's condition while the AI operates another endpoint, without changing that endpoint's control or resume state. Rebind observers to the legitimate player after transfers/reconnects. Retirement/deletion detaches the relevant observers and releases stale references; passive observation must never authorize tool use or network UI actions.

### 2.6 Physical protections, power, and unchanged medical behavior

Apply the following to the supported Uplink Shell chassis through narrowly scoped traits/handlers. Do not change all synthetics or all carbon mobs globally.

| Requirement | V1 boundary |
|---|---|
| Electrical protection | Block ordinary electrocution damage/incapacitation. Do not make the body absorb unlimited electrical energy or implicitly immune to EMP. |
| Slip protection | Block slipping; retain deliberate lying down, buckling, operating-table positioning, and externally imposed physical restraint. |
| Stun protection | Block conventional stun, knockdown, paralysis, and stamina-incapacitation effects. Do not override death, mechanical critical failure, exhausted power, or essential medical state transitions. |
| Temperature protection | Prevent environmental hot/cold damage and incapacitation. Preserve direct weapon/burn injuries and existing medically relevant synthetic critical deterioration; do not zero all fire loss. |
| Chemical protection | Block ordinary organic poisoning/drug effects while keeping supported synthetic treatments, reagents required by existing physiology, and relevant direct corrosive/physical damage. Do not disable the complete reagent system. |
| Power and charging | Reuse the synthetic fuel-cell/power model and ordinary consumption, with clear charge display and recharge through existing cyborg rechargers. Keep shell charge separate from core backup power. |
| Medical interaction | Preserve existing limbs, wounds, oil/blood behavior, organ damage, surgical access, treatment, repair, and revival. Do not add regenerative healing or charger-driven cyborg repair. |

The synthetic fuel cell already subscribes to the cyborg-recharger signal. Its charging handler does not apply the station's repair allowance; the recharger accepts carbon/human occupants. Reuse that path rather than introducing a second battery or repair mechanism. [S10, S11]

The existing synthetic species has critical-state overheating/direct fire damage, and its fuel cell has EMP discharge/organ damage. Protect against ambient temperature and ordinary electricity without accidentally suppressing those separate medical/failure paths. [S10, S12]

Physical properties must not disappear simply because the AI enters AI View. Authorization-dependent network actions and issued-tool actions, by contrast, are available only to the authorized controller. The separately authorized, personally issued onboard camera may continue its normal permitted feed while the registration remains valid and the body is unattended; retirement or loss of its live authorization ends that feed. Avoid making the brain a universal protection upgrade for arbitrary organic hosts; use the defined shell chassis configuration. Medical recovery restores body viability, not player deployment or personal entitlement; use the surgery/revival rules in section 2.9.

### 2.7 Engineering tools — reuse the implant toolkit

**Preferred base:** `/obj/item/organ/cyberimp/arm/toolkit/toolset` or a narrow Uplink-specific subtype. It already creates the six cyborg engineering hand tools and supplies a radial menu, extension/retraction, a bound hand, and drop-key retraction. [S5, S17]

| Tool | Existing starting type |
|---|---|
| Screwdriver | `/obj/item/screwdriver/cyborg` |
| Wrench | `/obj/item/wrench/cyborg` |
| Welder | `/obj/item/weldingtool/largetank/cyborg` |
| Crowbar | `/obj/item/crowbar/cyborg` |
| Wirecutters | `/obj/item/wirecutters/cyborg` |
| Multitool | `/obj/item/multitool/cyborg` |

Expose **Engineering Toolkit** as an Action with the existing radial selection pattern. An extended tool occupies a real hand; retracting restores normal hand use. Prefer the existing right-arm toolkit mount while preserving the standard synthetic power-cord arrangement. Conflicting mechanical preferences must be handled in the preview/normalization step.

Keep existing cyborg-variant tool speeds rather than adding a further speed multiplier. The inspected cyborg welder is already a faster industrial welder; it is not, merely by subtype name, an electric/infinite-fuel tool. Preserve its persistent fuel tank and ordinary refilling behavior. [S6]

Required behavior:

- Create persistent tool instances once per toolkit, not once per action click. Retraction, view changes, and reconnects do not refill fuel or reset item state.
- Use ordinary tool interaction, adjacency, operation times, resource checks, and crafting rules. An Action is a selection/deployment interface, not remote construction or repair.
- Require a functional compatible arm/hand and a valid controlling player. Missing limbs and damaged toolkit organs remain medical problems; do not recreate them automatically.
- Avoid unexpected item drops. The base implant can drop an occupied hand's item; guard that behavior for the issued toolkit with a clear occupied-hand message or an explicit user choice. Never delete held gear. [S5]
- Honor restraints and blocked hands even with stun/slip protection. Revalidate the endpoint, session, issued-tool authorization, and limb/hand state after the radial menu or another yielding operation.
- Safely turn off/stow issued active tools when leaving the body, retiring it, removing the implant, losing its required limb, or invalidating control. Do not leave a hidden lit welder operating inside an inactive body.
- Keep drop-key retraction and prevent pocketing, handing off, exporting, or repeatedly spawning issued tool instances. Do not delete unrelated player inventory during cleanup.
- Audit any robot-only power/model assumptions on chosen subtypes; use a narrow compatibility adapter if genuinely needed, not a fake cyborg identity or a second resource subsystem.

No RCD, RPD, infinite cable/sheets, full cyborg consumables inventory, weapons, or surgical toolset is included by default. Existing permitted items can still be acquired and used normally. Existing scanner/light interfaces are covered under interface parity, not a new module tree.

### 2.8 Interface parity while embodied

Retain the existing AI identity and service state. Add a compact Uplink interface or Actions that invoke those services with three explicit contexts: **viewer**, the shell/client presenting the interface; **authority**, the controlling core/AI identity; and **operation origin**, the location/entity from which that particular operation is allowed to act. Merely calling a core proc that opens a UI on an unoccupied core is insufficient. A local interaction uses the shell's permitted targeting origin; a core-centered ability remains core-centered. Do not substitute the viewer mob for all three.

| Service | Required embodied behavior |
|---|---|
| Laws | Current authoritative laws, read/state controls, and immediate relevant law-change notifications. No new permission to edit laws. |
| Communications | AI/binary identity, permitted radio channels and settings, integrated messaging/PDA continuity, and relevant direct notifications. Avoid doubled messages from core and shell feeds. |
| Status | Core health/backup, shell charge/damage, linked cyborg status, and current shell ownership/availability. |
| Station services | Existing alarms, crew monitor/manifest, bot controls, announcements, shuttle actions, and permitted display/hologram settings through authorized interfaces. |
| Sensors | Appropriate existing medical/security/diagnostic overlays and practical self-status. Retain visibility/privacy rules for information the AI is allowed to see. |
| Camera/photos | A real onboard shell camera and existing photography facilities, plus AI View for ordinary station-wide camera operation. No new incident notebook. |
| Existing special abilities | Preserve legitimately available AI abilities, including antagonist abilities where applicable, and their existing costs, permissions, cooldowns, and state. Do not grant locked abilities. |

Before full service integration, inventory the concrete existing player-facing operations at the implementation SHA, including legitimately available special/antagonist abilities. For each operation record its source implementation, authoritative state owner, viewer, spatial origin/targeting rules, permissions/range/visibility, costs and cooldowns, and availability under the core states in section 2.9. The table above defines required groups; the operation inventory defines their bounded completion checklist. Keep state/costs on their existing authority rather than cloning abilities onto the shell. Unsupported integration is a reported V1 gap, not silent removal of parity or permission to grant a locked ability.

Separate normal human physical clicks from a clearly indicated network-interaction modifier/toggle. **One input dispatches either a physical interaction or a network interaction, never both**, including a rejected network click; normal physical interaction is the default. Reset/cancel shell-only input modes when leaving the endpoint so stale input cannot cross control transitions.

Local network operation uses an existing approved cyborg-style wireless interaction rule and valid shell visibility; it is not unlimited camera-free access. Phase 0 must identify and record the actual predicate/constant, range, line-of-sight and target restrictions to reuse. The original handoff does not establish a numeric range: do not guess one or implement a separate widening of access. Share the verified rule through a narrow adapter as needed. Full remote camera operation uses AI View. Respect device AI-control disablement, wires, power, and permission checks in either route.

Do not globally change `isAI()`/`issilicon()` to include carbon shells. Resolve the controlling AI explicitly for service authorization. Every UI action and delayed callback revalidates the live viewer, matching endpoint/session, relevant registration, operation origin, service capability, permissions, target reach/visibility, and existing costs. Close or invalidate stale network interfaces after loss of authorization. Centralize these decisions in small shared helpers; avoid one-off privileged wrappers that reinterpret core state independently.

The existing Uplink code supplies only part of this integration; the core/silicon implementations contain the relevant authoritative services. [S1, S3, S13, S14]

### 2.9 Failure and unattended-body policy

**For Uplink endpoints, preserve the agreed policy below rather than TG's blanket emergency recall.** The inspected core requests disconnection on health loss/state change and mains-power failure, so implementing the agreed behavior requires deliberate changes at those call sites. Dispatch by endpoint policy: ordinary cyborg shells retain their existing failure behavior. [S7]

#### Core and connection capability contract

Use a centrally defined, small capability contract rather than a single `core_is_valid` boolean. Map actual existing core, power, transfer, and link states to these four decisions during Phase 0; report denial reasons that UI and lifecycle consumers can share. The contract derives from authoritative game state, not duplicated mutable status flags or the presence of a client on the core.

| Decision | Required inputs/boundary |
|---|---|
| May this AI control this endpoint? | Authoritative identity, endpoint/session binding, relevant current registration, actual link and body state, and the endpoint-specific core-failure policy. Core camera unavailability does not alone disable Uplink actuators. |
| May this AI use this service/operation? | The particular operation's existing permission/state/cost rules, viewer/origin, target limits, and core/network availability. Shell control does not imply every service remains available. |
| Can the mind safely return to its authoritative core? | A legitimate receiving core and the game's supported transfer/consent/re-entry semantics. Check independently of physical shell control and camera-interface availability. |
| May this personal-shell request be accepted or delivered? | Check the relevant stage separately: entitlement, registry/request generation, retirement prerequisites, core availability, deadline, and safe delivery/identity conditions. Acceptance is not irrevocable permission for a later callback to deliver. |

Record explicit mappings for normal operation, mains loss with operational backup, power-restoration mode, terminal core failure and ordinary revival, EMP/link failure, core carding, and supported mech/MOD transfers. Identify which existing state constitutes a real control-link failure instead of using temporary absent references or camera-incapacitation flags as substitutes. These mappings must be backed by the working tree; this handoff does not claim the exact implementation fields have already been verified.

| Event | Required Uplink policy |
|---|---|
| Ordinary core damage | Immediate warning; do not automatically remove shell control while the AI remains operational. |
| Core mains loss with operational backup | Keep the physical shell controllable. Existing unavailable core camera/network functions remain unavailable. Show backup warnings. |
| Core power-restoration mode | Do not confuse its camera-interface/incapacitation flags with a terminal processor failure and disable all shell actuators by accident. Evaluate shell control, services, and safe return separately. |
| Shell low power | Warn; allow safe return to a valid core. Keep the body and charge state for existing recharging. |
| Shell incapacitation/death/brain removal | End/return only that endpoint's matching active session where possible; preserve the medical condition. If it is unattended, update availability/alerts without recalling the AI from another endpoint. |
| EMP | Retain existing relevant synthetic/organ consequences. Damage or real link failure may require return; ordinary electrical protection is not universal EMP immunity. |
| Terminal core death/destruction | End live identity-wide authority and affected sessions; return/ghost safely through existing death semantics. Revoke issued network/tool access and cancel delivery. Retain registry history; do not use a body or request to resurrect the AI. |
| Both core and controlled shell invalid | Resolve the player to an appropriate observer/death state, never a deleted mob or orphaned client. An invalid unattended body is not proof that the player has no valid endpoint. |
| Logout/reconnect | Preserve allocation, blueprint, registration, loadout ledger, and accepted replacement deadline. Recover one legitimate control state; no auto-issuance or reuse of stale session callbacks. |
| Voluntary ghosting/admin transfer | Respect normal consent/re-entry semantics; do not force a departed player back or duplicate their mind. |
| Ordinary permitted AI revival | Recover the same registry/history and revalidate any non-retired binding. Restore live capabilities only under normal revival/re-entry rules; no automatic deployment or reset of claims/retirement. |

Core carding, mech/MOD transfers, brain surgery, transformations, and the Self-Actualization Device must use the shared connection transition when they affect authority, binding, or control. A purely cosmetic change must not be treated as a new deployment. A temporary absent/changed reference is not proof that a free replacement is due. Preserve valid unattended-body alerts separately from active-session subscriptions.

#### Medical recovery is not control recovery

Shell treatment, repair, and revival restore physical viability using existing medical behavior. They do not retrieve the AI from its core, cyborg, or another endpoint, create another controlling mind, or restore retired personal authority. Reconnection is a separate, authorized player-control transition. Keep this rule even when the body is revived while its AI is disconnected or operating another endpoint.

| Brain/body change | Personal-registration and control result |
|---|---|
| Current brain removed from the current chassis | Safely end only its matching active session, invalidate the live organ binding, and mark the endpoint unavailable. Preserve the registry and physical medical state; surgery alone neither retires the chassis nor grants replacement. |
| Same compatible brain reinserted into that still-current chassis | Revalidate identity, chassis registration, and organ binding. The endpoint may become available again, but must not auto-deploy or reuse stale control callbacks. |
| Legitimate compatible replacement brain in the same current chassis | Refresh the binding through the authoritative registry, invalidate old organ authorization, and preserve that chassis's entitlement/blueprint/loadout history. Do not rely on the new organ to claim ownership. |
| Brain transplanted into another chassis | No implicit transfer of personal registration, entitlement, or chassis protections. Preserve any supported ordinary shell connection through its distinct authorized acquisition/binding path. |
| Retired brain/body recovered or revived | Physical recovery remains possible; old personal authorization remains invalid. Ordinary authorized reuse is distinct from restoring the retired registration. |

A refreshed organ binding may require a new personal-authorization generation without constituting issuance or replacing the chassis. Invalidate old tokens explicitly; never let the organ itself be the entitlement ledger. Keep the identity-wide terminal-failure rules separate from endpoint-specific medical events.

Route core consent prompts and warnings to the actual controlling player. Permit the AI to authorize its own supported existing core interactions through the correct identity checks; do not implement new live-core repair mechanics.

### 2.10 Recognition, logs, and support

Audit the systems that interpret an AI with no client on its core as absent. Preserve job credit, availability, relevant shuttle-caller logic, laws, antagonist state, reporting, and administrative identity across embodiments. The inspected shuttle availability path is one concrete review target; it separately checks the core client after considering a deployed shell. Treat this as a code concern to validate, not an already reproduced runtime bug. [S15]

Make personal ownership and active/inactive/retired status clear in examination and diagnostics. Apply deliberate recognition to existing safety/access systems without granting blanket immunity to every hostile entity or restricted area.

Provide short first-use guidance and actionable failure messages. Log issuance, completed delivery, retirement/replacement, ownership changes, and forced recovery with reason codes. Do not log every movement or battery tick. Administrative recovery should locate the body, inspect registration, force a safe return, or repair a failed request without resetting valid loadout claims or creating duplicate minds.

## 3. Architecture and source integration

### 3.1 Keep three responsibilities separate

**Per-AI round registry:** owns job entitlement, committed blueprint, current personal registration/generation, replacement state/deadline, and the one-time loadout ledger. It refers to the authoritative AI/mind through explicit lifecycle handling, not a name match or disposable organ field. A small registry-owned issuance coordinator controls provisional work and the single commit. Revoking live authority does not destroy this history; ordinary permitted core revival/transfer must reconnect to the same registry.

**Connection session/endpoint:** connects, disconnects, resumes, reports status, routes authorized viewers, and handles endpoint-specific failure for cyborg and Uplink endpoints. Reuse or extend a suitable existing mechanism where practical. Keep the core/service capability contract in small shared helpers, not a new generic permissions framework. Distinguish passive registered-body observation from active-session input/UI hooks. This is not a mandate to rewrite all remote possession systems.

**Physical chassis/toolkit:** owns appearance, limbs/organs, protection behavior, charge, equipment, injuries, and the actual toolkit implant. The authoritative baseline manifest describes fresh construction only. Appearance updates do not re-run construction or resource initialization. No shell becomes an independent AI character.

Keep personal ownership, active deployment, and resume target as distinct state. During AI View the core has the client, the personal shell remains registered, and no active shell is falsely advertised as occupied. Retaining a personal registration does not block ordinary cyborg/crew-built shell use. Never put a carbon mob into a robot-only field and assume every downstream proc will work.

| Lifetime/token | What invalidates it | What must survive independently |
|---|---|---|
| Personal-registration/authorization generation | Retirement or replacement of the authorized binding; refresh it as necessary for legitimate organ rebinding. | AI entitlement, committed blueprint, terminal loadout outcome, and replacement history. Core revival cannot reinstate retired tokens. |
| Active control-session generation | Deployment/return, authority loss, or another control transition ending that session. | A still-current personal registration and legitimate passive observation/resume state. Entering AI View must not retire the body. |
| Replacement-request/issuance-attempt generation | Cancellation, completion, terminal-failure cancellation, or supersession of that request/attempt. | The retained not-before deadline for an undelivered replacement cycle and committed entitlement/loadout history. Resubmission uses a new request token. |

These are distinct lifetimes, not three names for one global counter. Delayed work validates the identities/tokens relevant to its purpose after any yield. A timer from a canceled request cannot fulfill a newer one; a UI callback from a departed shell cannot operate another endpoint. A legitimate new session may target the same still-authorized personal chassis.

Use one guarded transition path for normal and emergency returns. Make cleanup idempotent, signal registration/removal symmetrical, and stale callbacks harmless. Scope endpoint cleanup to that endpoint's matching session; route terminal core failure through the identity-wide path. Do not duplicate mind transfers in individual UI actions. Keep body-observation bindings alive for the intended registration lifetime and detach them on retirement/deletion so they cannot leak stale alerts, authority, or references.

### 3.2 Existing source points

Place new feature-owned logic under the existing Aphelion module layout, preferably a new `modular_aphelion/modules/uplink_shells/` module. This is a proposed new module, not a claim that it already exists. `modular_aphelion/modules` and `master_files` were verified. [S16]

| Area | Existing source to inspect/reuse |
|---|---|
| AI job entitlement | `code/modules/jobs/job_types/ai.dm` [S2] |
| Uplink brain lifecycle | `code/modules/mining/lavaland/mining_loot/megafauna/the_thing.dm` [S1] |
| Nova organ compatibility | `modular_nova/modules/ai_uplink_upload/the_thing.dm` [S18] |
| AI selection/return and core hooks | `code/modules/mob/living/silicon/ai/ai.dm`; inspect its defines and relevant callers [S3] |
| Normal AI eye | `code/modules/mob/living/silicon/ai/freelook/eye.dm` [S4] |
| Implant toolkit | `code/modules/surgery/organs/internal/cyberimp/augments_arms.dm` [S5] |
| Tool resource behavior | `code/game/objects/items/tools/engineering/weldingtool.dm` and chosen tool subtypes [S6] |
| Core failure policy | `code/modules/mob/living/silicon/ai/life.dm` and `ai_defense.dm` [S7, S19] |
| Preferences/loadout | `code/modules/client/preferences.dm`; `modular_nova/modules/loadouts/loadout_ui/loadout_outfit_helpers.dm` [S8, S9] |
| Charging/physiology | Synthetic species and fuel-cell paths; `code/game/machinery/rechargestation.dm` [S10–S12] |
| Native silicon/cyborg services | `code/modules/mob/living/silicon/silicon.dm`; `robot/robot.dm` [S13, S14] |
| AI-presence checks | `code/controllers/subsystem/shuttle.dm`, plus relevant job/report/admin consumers [S15] |
| In-place customization | `modular_nova/modules/self_actualization_device/code/self_actualization_device.dm` [S20] |

Use narrow hooks in shared code where required; do not copy hundreds of lines into replacement procs just to add one branch. Preserve legacy typepaths, map instances, and ordinary crew-built brains. Document each intentional shared-code behavior change and dispatch by the applicability table in section 1. Keep personal-only issuance/retirement separate from Uplink-wide failure behavior and shared cyborg/Uplink connection safety; do not scatter inconsistent personal-shell exceptions across core hooks.

## 4. Implementation sequence

### Phase 0 — Rebase the handoff to the working tree

Read the current repository/contributor and local agent instructions that actually exist, inspect applicable module conventions, and compare touched systems with the pinned baseline. Confirm the build/include pipeline and existing focused tests. Record the actual implementation SHA.

Inspect the specific unsafe boundaries: robot-typed deployed-shell fields/calls, core/client assumptions, brain signal cleanup, nested loadout metadata, toolkit arm conflicts, and organic/synthetic preference middleware. Do not broaden this into a repository-wide cleanup.

Produce a compact source map with the four implementation inventories required above: the chassis/appearance compatibility matrix; one concrete baseline equipment/access/output manifest; the player-facing service-operation inventory with viewer/authority/origin and verified wireless rule; and the core/endpoint capability mappings, including carding, transfers, EMP, and revival. Distinguish source-confirmed behavior from the new required behavior and identify the narrow hooks needed. These may be sections of one module design note, not separate frameworks or a large documentation project.

**Exit:** the implementation SHA, source map, concrete inventories, dependency list, and focused validation commands are recorded. Resolve repository-specific typepaths/rules at this gate; do not invent them or reopen approved product decisions. Record a genuine compatibility blocker explicitly rather than silently dropping parity or changing scope.

### Phase 1 — Registry and safe control transitions

Implement the per-AI registry and endpoint/session abstraction, independent lifetimes, and small capability helpers. Make connect/return/resume atomic from the player's perspective, enforce ownership after yields, and preserve ordinary cyborg-shell behavior. Integrate shell death/removal, core failure, ordinary revival, and legacy direct disconnect callers. Unattended-body callbacks must never terminate another endpoint's session.

Resolve the existing brain-organ versus shell-mob `undeploy()` mismatch through the shared interface rather than adding an untyped call in each consumer. [S1, S3, S14]

Perform an early structural build and a focused lifecycle/portability check using a manually supplied compatible carbon shell. Exercise one representative read-only AI service and one state-changing service through the intended viewer/authority/operation-origin path. Demonstrate that authoritative state, permission checks, and target origin are correct before committing to the full service integration. Reuse those paths in Phase 5; this is not a disposable service framework or a requirement to implement all parity here.

**Exit:** a compatible carbon shell and an ordinary cyborg shell both connect and return safely; passive personal-shell events cannot disturb the other endpoint; the two representative services work from a real embodied client. The AI never has two active bodies or loses its mind/client during a transition.

### Phase 2 — Chassis builder, preview, and initial issue

Implement candidate snapshot, preview, final confirmation, and committed blueprint capture in that order. Build fresh synthetic bodies from the resolved compatibility matrix and single baseline manifest. Integrate optional initial loadout, AI-job entitlement, safe delivery locations, and explicit physical-credential policy. Share compatibility validation and appearance application with supported in-place customization, not fresh-body organ/equipment/resource initialization.

Implement the one issuance coordinator with provisional body/equipment/container ownership and one commit point. Use explicit `not_committed` / `issued` / `declined_at_first_issue` loadout outcomes. Before commit, clean up only the attempt's provisional objects and leave claims unspent; after commit, recover the delivered body rather than repeating or rolling back public delivery. Do not disturb saved preferences or existing inventory.

**Exit:** a roundstart and latejoin AI can obtain and use the exact previewed shell; opt-out is terminal on successful first issue; baseline/access are consistent; failed, repeated, or partially completed attempts cannot duplicate gear or consume an uncommitted allowance. Live customization does not heal, refill, or reinstall missing equipment.

### Phase 3 — Protections, charging, and implant tools

Implement the scoped protections against existing synthetic physiology, reusing native charging without cyborg healing. Install the issued toolkit subtype/action, persistent tool instances, safe hand behavior, fuel continuity, and limb/removal cleanup.

**Exit:** electrical/slip/stun/environmental/organic-chemical protection works; direct injury, organ failure, surgery, treatment, and revival still work without automatic player redeployment; the recharger adds charge without healing; the six engineering tools behave like usable implant tools. View changes and live customization do not reset existing toolkit resources; ordinary treatment and legitimate organ replacement retain their existing physical effects without auto-deploying the AI.

### Phase 4 — AI View and resume

Implement the explicit capture-transfer-focus-center sequence. Reuse the true AI eye and client. End the old input/UI session without retiring the registration; add a persistent resume action and separately owned unattended-body alerts. Handle movement, z-levels, containers, prior tracking, and multicamera state without cross-endpoint callbacks or stale input.

**Exit:** launching from the shell visibly opens the primary AI eye at that shell, every time under valid conditions; resuming returns to the same body without a camera reacquisition requirement or stale inputs.

### Phase 5 — Portable services and recognition

Complete the operation inventory required by section 2.8 using proper viewer/authority/operation-origin separation and the Phase 1 integration paths. Add the local network-interaction control with mutually exclusive input dispatch and the verified existing range rule. Integrate the personally issued onboard camera under its valid current-registration authorization; independently acquired camera hardware keeps its ordinary rules. Route core prompts and alerts to the actual player, preserve communications/laws and ability state/costs, and fix relevant presence/reporting checks.

Do not mark a feature complete because an Action exists: open and exercise the real UI from an embodied carbon client and verify that its actions execute under the intended authority and origin. Apply the per-operation capability rules rather than treating physical shell control as permission to use every core service.

**Exit:** the concrete existing operations in every required service group are accounted for and available in the agreed modes; costs, cooldowns, target limits, and permissions remain correct; AI presence remains correctly reported while embodied. No input performs both physical and network actions.

### Phase 6 — Retirement and replacement

Add the section 2.4 sequence: confirmed safe return when necessary, immediate retirement and request acceptance, five-minute scheduling, ready/blocked retry, and independent request generations. Preserve accepted deadlines through cancellation/resubmission, disconnect, and ordinary permitted core revival. Reuse the Phase 2 coordinator/builder with `include_personal_loadout = false` and no change to committed loadout history.

Guard against old-brain reinstallation, recovered shells, and stale pending callbacks. End the retired personal camera feed and relevant observers without deleting the body or unrelated belongings. Review the actual repeated baseline outputs and document allowed salvage and bounded anti-duplication treatment; do not implement an unrelated economy or medical rewrite.

**Exit:** destroyed or retired bodies can be replaced; retirement occurs at request acceptance; cancellation never restores authority or shortens the retained deadline; only the current personal binding is authorized. Legitimate other-endpoint operation is undisturbed, old belongings remain where they were, retired bodies do not accumulate authorized camera coverage, and no request resurrects a terminally failed AI.

### Phase 7 — Focused validation, support, and rollout

Complete the acceptance matrix below, first-use text, module README, configuration notes, and small admin recovery surface. Add a changelog. After the early Phase 1 structural build/check, compile the integrated changes and perform the combined smoke sequence and mandatory repository gates. Phase exits that require runtime evidence may use necessary incremental builds; this is not an instruction to defer the first compile until Phase 7. Reuse recorded evidence for unchanged paths and rerun only affected or failed checks, plus mandatory release gates, rather than broad suites after every edit.

Use a feature switch or equivalent controlled rollout. Disabling new issuance must not strand an already connected player; safe return/cleanup must remain available. Any rollback must first resolve active sessions normally, not delete occupied bodies or the owning mind. Keep database, external-service, and unrelated map migrations out unless genuinely required.

**Exit:** the release checklist is satisfied, validation results are recorded honestly, and changes are ready for normal maintainer review—not automatically deployed.

## 5. Focused validation and acceptance criteria

Favor existing tests and fixtures. Add narrowly scoped automated coverage only where missing for the high-risk areas: issuance/replacement idempotency, mind/ownership transitions, preview/loadout consistency, and toolkit resource/cleanup behavior. A small number of parameterized cases is preferable to a new suite per proc.

Perform one integrated, combined in-game smoke sequence covering presentation and interactions that are not well tested at the datum level; the narrow early Phase 1 feasibility check is additional, not another full smoke suite. Include a second AI identity for AC-15/AC-16 and an ordinary cyborg endpoint for cross-endpoint isolation. Use a second representative map/start configuration to exercise a materially different enabled delivery boundary, not to repeat the entire sequence. Do not run unrelated broad suites, large gameplay benchmarks, or repeated expensive builds by default. Preserve mandatory repository release checks.

Fold the following cross-state scenarios into the existing criteria, rather than creating separate suites: damage/repair/revival of an unattended personal shell while its AI controls a different endpoint; cancellation/interruption at the replacement deadline with disconnect and ordinary AI revival; and live customization of an injured, partially discharged body with altered equipment and partially used toolkit fuel.

| ID | Acceptance criterion |
|---|---|
| AC-01 | Roundstart and latejoin grant entitlement once; unrelated AI creation does not. Core transfer or ordinary revival reuses the same identity/registry rather than resetting claims. |
| AC-02 | Candidate preview and created body match the exact confirmed snapshot, including metadata/compatibility changes; supported appearance follows the recorded matrix and required synthetic organs/protections exist. Saved preferences remain byte-for-byte unchanged by shell creation. |
| AC-03 | Initial loadout opt-in/opt-out, active-preset metadata, item restrictions, baseline manifest/access, and overflow behave correctly. Opt-out commits a terminal declined state. Failure before the single commit spends nothing; retries or notification failures after commit recover the existing delivery rather than duplicating it or deleting public gear. |
| AC-04 | Toolkit offers all six specified tools through an Action/radial; hand use, tool speed, fuel/refilling, retraction, restraints, and severed-arm behavior are correct. View changes/reconnects do not recreate tools or refill an existing tank. Approved starting supplies on a legitimately issued replacement are allowed, not misclassified as duplication. |
| AC-05 | Each requested protection works on the configured chassis and does not spread through brain transplantation. Direct wounds, critical deterioration, organ damage, medical positioning, treatment/surgery, and revival remain valid. Repair/revival of an unattended personal shell while its AI controls a cyborg restores only body viability, without moving the player or restoring retired authority. |
| AC-06 | A standard and an upgraded cyborg recharger charge the shell without applying cyborg body repairs. View changes/reconnects do not reset charge or recharge the core. |
| AC-07 | From multiple shell positions and a different valid z-level, AI View centers the primary eye on the captured shell turf after normal initialization. Previous tracking/multicam does not override it; return ends the old control session without retiring the personal registration. |
| AC-08 | Test AI View from a container/recharger and a camera-blind position. No wall/container/hidden-area visibility leak or unrestricted first frame occurs; exceptional fallback is explained. The valid unattended camera retains only normal permitted coverage. |
| AC-09 | Resume returns to the same registered body at its current location even after movement outside camera coverage. Camera inputs never move/use the shell; stale shell actions cannot execute after departure. Passive damage/power/attention alerts survive AI View without forced return and detach on retirement/deletion. |
| AC-10 | Every inventoried portable operation has its viewer, authority, origin, permissions, costs/cooldowns, and core-state availability checked; representative real UIs are exercised in each group. The verified local network range is used and one input takes exactly one physical/network route. Unauthorized or stale requests cannot act through another endpoint or AI. |
| AC-11 | Uplink core damage/mains loss on operational backup warn without blanket forced recall; ordinary cyborg failure policy remains unchanged. Power-restoration mode separates physical control, individual services, safe return, and delivery. Shell depletion, EMP/real link failure, and terminal core failure follow their recorded mappings. |
| AC-12 | Shell death, brain removal/reinsertion/replacement/transplantation, core/shell deletion order, carding, supported transfers, ghosting, ordinary revival, and reconnect preserve one legitimate player/mind state. An event from an unattended personal shell cannot terminate another endpoint session. Registration, session, and request generations remain independent; ordinary cyborg transitions still work. |
| AC-13 | Self-Actualization Device use preserves registration/protections and the stored replacement blueprint. On an injured, partially discharged shell with missing/altered equipment and partly used welder fuel, customization itself does not heal, refill, restore organs/limbs, reinstall equipment, or redeploy the player. |
| AC-14 | Accepted replacement immediately retires the old personal binding after any required safe return; failed return leaves it unretired and the request unaccepted. The five-minute default, cancellation/resubmission, ready/blocked retry, reconnect, and ordinary core revival preserve the correct deadline/history. Interruptions at the deadline cannot duplicate delivery, repeat loadout, or restore retired authority. |
| AC-15 | Recovered/repaired retired shells or brains cannot restore stale personal authority or their retired Uplink camera feed. The repeat-issued baseline outputs have an explicit salvage/anti-duplication review without deleting bodies or disabling normal surgery. A second AI cannot seize another AI's current registration through a forged link, organ, or delayed UI action. |
| AC-16 | Relevant AI-availability/job/report/admin consumers identify the embodied AI correctly. With two AI identities present, allocations, radios, resume targets, passive alerts, and replacement callbacks remain isolated. One AI's personal-shell registration/events do not disrupt that AI's legitimate ordinary-shell operation. |
| AC-17 | Player help explains preview normalization, loadout opt-out, immediate retirement, retained replacement timing, and blocked delivery. Denied-action reasons, administrator recovery, logs, and safe feature-disable behavior are understandable and functional; recovery never resets valid claims or creates duplicate minds. |

Tests should distinguish shell loss from normal brain replacement, a disconnected client, and a merely missing weak reference. Distinguish body revival from player re-entry, and terminal authority revocation from registry destruction. Use representative high-risk combinations rather than an exhaustive cross-product of all states. Verify actual player-facing behavior; do not replace these checks with assertions that the right trait names are present.

For performance, use event-driven ownership/status updates and existing mob/power processing. Avoid polling the entire mob/camera list per frame, reconstructing tool radials/previews continuously, or reapplying all preferences on reconnect. A targeted leak/duplicate-action check after repeated transfers is sufficient unless profiling exposes a real problem.

## 6. Delivery and completion report

Deliver feature code and minimal shared hooks; required safe delivery landmarks/fallbacks; UI/actions and short first-use guidance; targeted tests/fixtures where justified; configuration/rollout notes; and a changelog. The module README or one linked design note must explain applicability, the three state lifetimes, single issuance commit, cancellation/resubmission timing, medical/control recovery, and authority revocation versus registry retention. Include the resolved compatibility matrix, baseline/access/output manifest, service-operation inventory and wireless rule, and core capability mappings; keep these aligned with the actual implementation rather than scattering competing defaults.

The completion report must state the implemented SHA, source files changed, the early structural/portability check and integrated validation results, which acceptance checks were not run and why, unsupported appearance combinations or service-operation gaps, intentional salvage behavior, and any real remaining defects. Identify intentional shared-code policy changes and confirm their endpoint scope. Do not describe source inspection or successful compilation as proof of runtime behavior. Do not introduce deferred speculative features to compensate for an unfinished V1 requirement.

**Definition of done:** an AI can issue the exact previewed body, make its one-time personal-loadout decision, perform physical engineering work with implant-style tools, use its existing AI services under the correct viewer/authority/origin rules, enter the normal AI eye centered on the shell, resume that same body, charge and receive ordinary synthetic medical treatment, and retire its personal shell immediately for a delayed replacement without duplicating authority, player identity, or personal belongings. Medical recovery does not seize player control; live customization does not initialize fresh organs, equipment, or supplies. Valid ordinary endpoints remain usable and isolated throughout.

## 7. Source register

Sources below establish the inspected implementation and reuse points. They do not establish that the proposed V1 behavior already exists. Repository links are pinned to the inspection commit; the implementing agent must reconcile subsequent changes.

- **S1 — Existing Uplink brain:** [the_thing.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/mining/lavaland/mining_loot/megafauna/the_thing.dm).
- **S2 — AI job:** [job_types/ai.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/jobs/job_types/ai.dm).
- **S3 — Core control and shell selection:** [silicon/ai/ai.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/mob/living/silicon/ai/ai.dm).
- **S4 — AI eye and focus:** [freelook/eye.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/mob/living/silicon/ai/freelook/eye.dm).
- **S5 — Existing arm/toolset implants:** [augments_arms.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/surgery/organs/internal/cyberimp/augments_arms.dm).
- **S6 — Cyborg welder variant and fuel behavior:** [weldingtool.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/game/objects/items/tools/engineering/weldingtool.dm).
- **S7 — Existing core power/health recall:** [silicon/ai/life.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/mob/living/silicon/ai/life.dm).
- **S8 — Preferences and middleware:** [preferences.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/client/preferences.dm).
- **S9 — Selected loadout/outfit integration:** [loadout_outfit_helpers.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/modular_nova/modules/loadouts/loadout_ui/loadout_outfit_helpers.dm).
- **S10 — Synthetic fuel cell:** [stomach/stomach.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/modular_nova/modules/synths/code/bodyparts/organs/internal/stomach/stomach.dm).
- **S11 — Existing recharger:** [rechargestation.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/game/machinery/rechargestation.dm).
- **S12 — Synthetic physiology and critical states:** [species/synthetic.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/modular_nova/modules/synths/code/species/synthetic.dm).
- **S13 — Native silicon services:** [silicon.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/mob/living/silicon/silicon.dm).
- **S14 — Cyborg shell lifecycle:** [robot/robot.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/mob/living/silicon/robot/robot.dm).
- **S15 — AI availability review target:** [subsystem/shuttle.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/controllers/subsystem/shuttle.dm).
- **S16 — Existing Aphelion module layout:** [modular_aphelion](https://github.com/Aphelion-Moon/Meridian-Rift/tree/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/modular_aphelion).
- **S17 — Supplemental upstream toolkit documentation:** [/tg/ toolkit codedocs](https://codedocs.tgstation13.org/obj/item/organ/cyberimp/arm/toolkit.html), checked 21 September 2026. Use the pinned Meridian code, not this moving upstream reference, as implementation authority.
- **S18 — Nova Uplink organ/AI-controller adjustments:** [ai_uplink_upload/the_thing.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/modular_nova/modules/ai_uplink_upload/the_thing.dm).
- **S19 — Core EMP and maintenance-consent interactions:** [ai_defense.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/code/modules/mob/living/silicon/ai/ai_defense.dm).
- **S20 — Existing in-place body customization:** [self_actualization_device.dm](https://github.com/Aphelion-Moon/Meridian-Rift/blob/dd4b69bcc5f0d33a82b071d3f44fa75f332192f7/modular_nova/modules/self_actualization_device/code/self_actualization_device.dm).
