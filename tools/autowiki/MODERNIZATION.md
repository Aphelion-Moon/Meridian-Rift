# Autowiki implementation and coverage

Status: implementation and review in progress. The human workshop and reviewed source-selection pipeline are deployed as a versioned adapter with guarded rollback. Changes in this branch require review before game deployment. A review package does not prove which version players are running.

## Implemented

- Immutable checksummed packages, shared Node/PHP schema, semantic comparisons, source/configuration/compiler/runtime provenance, attestation verification and guarded publication commands.
- Seventeen datasets: entities, research nodes, designs, reagents, reactions, crafting, cargo, jobs, outfits, vending, species, projectiles, materials, surgery, armor, scenarios and dictionaries.
- Six appearance profiles: initial south first frame, left-hand layer, right-hand layer, worn layer, initialized machine board and initialized vendor. Equipment layers exclude the wearer, species fitting, animation and runtime overlays.
- Human decisions as wiki revisions: evidence fingerprints, watched fields, typed corrections, retained rejections, assignment, issue states, bulk preview, stale-edit guards and projection recovery.
- Canonical identity opt-ins and historical source aliases. Imports and generated rollback preserve human revisions. Relevant source changes require revalidation; unrelated changes preserve applicability.
- Reusable guide components, visual-editor TemplateData, a component picker and exact links to affected embedded facts.
- Public visibility checks, contextual Typesense documents, server-side search, immediate exclusion of newly hidden records and reuse of unchanged embeddings with the same model and dimensions.
- Durable delivery, deduplicated MediaWiki jobs, retries, reconciliation, image provenance, manual-image conflict detection and retained attribution.
- Separate source detector lifecycle and human review: scoped recurrence, atomic complete scans, retained transition history, explicit source absence, and filtered cause groups (deployed).

## Measured coverage

Two consecutive isolated generations on 14 September 2026 produced **33,495 records** with zero semantic changes and identical image inventories. There are **44,795 image mappings**: 23,662 initial, 8,915 left-hand, 8,915 right-hand, 2,949 worn, 253 initialized-machine-board and 101 initialized-vendor mappings. Multiple mappings can share a PNG. There are 528 entities with an alternate equipment appearance but no initial appearance.

The workshop contains 3,841 legacy-image reconciliation entries and 33 previously reviewed Moonridden decisions. Unreviewed legacy files have not been indiscriminately replaced. A prepared search release contains 6,187 eligible documents; the next preparation reused 5,941 embeddings. Review packages remain unpublished until deployment evidence passes verification.

## Gameplay changes to review

Ballistic insertion and its documentation scenario share the magazine acceptance predicate. Chemistry selection and documentation checks share the start-condition predicate; an impossible out-of-range pH conjunction was corrected. Equilibrium processing already checked pH. Normal gameplay review remains necessary alongside documentation checks.

Randomized recipes and vendor stock are declared dynamic instead of publishing random samples as fixed facts. Bounded initialization captures registered definitions and vendor appearances, rather than instantiating every object. Generation still initializes substantial game machinery; a smaller dedicated documentation initialization profile remains desirable.

## Remaining work

| Area | Current behavior | Further work |
| --- | --- | --- |
| Deployment | TGS active-build evidence, source-default verification, bounded artifact retrieval and durable request handling run through the versioned receiver; separate hosted generation/signing workflows are staged and live dispatch is disabled | Dedicated GitHub credentials, reviewed builder pin and a hosted end-to-end release remain |
| Last good data | Authenticated failures enter review; native preservation and corrections are assessed against immutable source packages, with one approved view for facts, images, relationships and search | Validate a trusted actual game release and continue browser checks; see LAST-GOOD.md |
| Identity | Declared canonical IDs, historical aliases and revisioned human links preserve notes through source moves | Renew manual links when their identity evidence changes |
| Appearance | Six bounded profiles, profile-specific review evidence and separate rejection histories | More machinery states and animation |
| Behavior | Four executable magazine/chemistry/construction scenarios | More procedures, configuration cases, species interactions and runtime effects |
| Guides | Embeds and an invisible visual-editor dependency template register every affected section, including repeated uses of the same fact | Incremental legacy-guide migration |
| Operations | Durable jobs, running-build status, visible failures and recovery checks | Authenticated standard/narrow browser checks and hosted rollout; queue metrics and Discord failure/recovery notices are installed |
| Source art | Forty original authoring sheets recovered from Git; all 248 cutter inputs present | Keep the no-missing-source gate enforced |

Definitions do not substitute for gameplay, policy or canon. Procedural hooks, live configuration, upgrades, custom crafting checks, randomized contents and hidden content need explicit coverage or a scope limitation. Human correction and annotation controls make those limitations reviewable without rewriting game data.

The recovered sheets were removed by cleanup commit `8218b0e9e852a6e8ea5eef9d619783d1262007be`, while their cutter configurations and DMI outputs remained. Isolated recuts of all 40 matched the retained outputs across all states, directions, frames, timing and RGBA pixels. The original blobs and source revisions are recorded in `cutter-recovery.json`. No compiled DMI was replaced. The missing-source exception list is now empty.

Human decision reads require the current unsuppressed wiki revision. If a save hook leaves a stale or missing projection, server-side public reference reads stop until reconciliation repairs it. Publication preparation performs that repair and verifies currency again before completion. This guard does not replace delivery/purging of already-cached guide HTML.

The separation of entities, activities and provenance is informed by [W3C PROV](https://www.w3.org/TR/prov-overview/); the manifest does not claim PROV serialization compliance.

## Machine construction coverage (branch data in review)

Initialized defaults expose 253 machine boards, circuit-board links from 761 machines, and 29 stock-part definitions with tier and energy rating. Component quantities, bluespace substitutions, constructed results, anchoring and scope are available to relationships and recipe embeds. Counts exclude the frame, wiring and board itself. Selected board modes and completion hooks can differ. Optional fields preserve compatibility with previous packages.

Manual insertion, RPED insertion and documentation now share the component-type resolver. RPED previously resolved stock-part datums to their base item type and could accept lower-tier parts for a tier-specific requirement. It now uses the same specified physical type as manual insertion. An executable BSA-frame fixture rejects a tier-one capacitor and accepts a tier-four capacitor, without constructing or operating the machine. This is a gameplay behavior fix requiring normal branch review.

Cached initialized board icons are serialized even when BYOND reports zero in-memory dimensions; PNG validation verifies the resulting assets. All 253 board profiles are present in both repeatable generations. One unresolved source relationship remains visible: the old computer points to an excluded abstract computer board. It has not been silently removed or baselined.

Validation: 53 Node tests, six profile-evidence checks, actual PHP package validation/import/rendering and two isolated compiler runs with zero errors or warnings. The repeat exports have identical records and image inventories. `maintenance/ConstructionTest.php --package <directory>` checks the real package in the disposable database on loopback port 3307, including the five-quadratic-capacitor edge and unchanged active publication. The matching wiki adapter is deployed and the construction package is available to editors as unpublished review data. The game changes remain staged for branch review; the package has not been presented as the deployed game.

The TGS client now retains exact merge heads and the active source tree. An isolated reconstruction matched all three live test merges without checking out or executing game code. [TEST-MERGE-BUILDER.md](TEST-MERGE-BUILDER.md) records the proof and the remaining trusted-builder boundary. This is staged source verification, not publication approval.

The normal master workflow now separates generation from signing. Its generation job cannot request an OIDC token or issue attestations. A fresh signing job validates package integrity and committed source inputs before signing, with pinned actions and no execution of downloaded code. The separate merged-source workflow signs a source binding whose manifest digest covers the data package. Receiver verification requires its approved builder release ref/commit and fresh matching TGS source evidence. A fixed builder release tag supports new game inputs without approving every master update. Durable request claims prevent automatic duplicate dispatches, including uncertain outcomes, while the workshop exposes sanitized run status. Retained run IDs avoid a growing-history lookup limit. These changes are staged, with 65 Node tests passing and both workflows passing Actionlint validation (shellcheck and pyflakes were unavailable). Hosted execution remains unverified; normal master exact-commit checks, semantic assessment and human revision guards remain enforced.

The matching wiki adapter and receiver are installed as immutable version `1194c952b088b62fdac3fa64db3c9db314f0c83c73280f1ac61a5a9661f3ce13`, after a real restored-database install/rollback/reinstall rehearsal and live health checks. All 30 aggregate comparisons, 33 human revisions and 16,657 managed images are unchanged. Dispatch is disabled. The game changes and hosted workflows remain staged for review.

## Operational health

Publications includes complete delivery totals and unresolved-first delivery rows, so older failures remain visible beyond the 100-row display limit. The existing five-minute job runner writes sanitized health to `<receiver statusFile>.operations.json`; no additional scheduler is required. `maintenance/Operations.php` reports queue age, failed deliveries, editorial reconciliation and receiver freshness, returning a nonzero exit status for failures. Waiting for publication prerequisites stays distinct from failed delivery, expired artifacts, failed generation or a stale heartbeat. Human decisions are never changed by this check. Failure and recovery transitions are connected to the existing Discord outbox. Stable failures and normal waiting stay quiet.

Validation: 65 Node tests and 52 DOM assertions pass. PHP checks cover queue-age boundaries and sanitized deployment failure states. A real isolated database test inserts an old failure behind 151 successes, verifies complete totals and ordering, and rolls back every fixture write. Real worker-wrapper checks distinguish waiting from stale status. The exact installed release passed install/rollback/reinstall with all 30 recovery aggregates unchanged.

Operations notifications use a protected transition journal, deterministic outbox IDs, disabled Discord mentions and fixed messages. Repeated checks do not enqueue repeats; interrupted queue insertion resumes before observing a new state. Delivery uses the existing worker retry/rate-limit policy. A crash between Discord accepting a notice and local acknowledgement can still duplicate delivery, as with the existing outbox; this is not an exactly-once transport guarantee. The fixture tests cover failures, recovery, recurrence, concurrency, corrupt state and interrupted queue acknowledgement without sending messages. The installed wrapper also queued fixture failure/recovery notices under isolated settings. Live waiting remained quiet with zero outbox records.
