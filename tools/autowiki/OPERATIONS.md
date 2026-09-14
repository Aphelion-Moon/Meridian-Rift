# Autowiki operations

## Install and upgrade

The adapter targets MediaWiki 1.46, PHP 8.4 and MariaDB 11.4. Copy `mediawiki/MeridianAutowiki` into the wiki extensions directory, load it with `wfLoadExtension('MeridianAutowiki')`, and set `MeridianAutowikiPackageRoot` outside the web root. Reserve namespace 4300 for human decisions with capitalization disabled. Authenticated users can review; publication requires `autowiki-publish`. Bots cannot act as human reviewers.

Use the site's actual settings and `MW_WIKI` environment. Paths below are illustrative:

```sh
php maintenance/run.php MeridianAutowiki:Import --conf /private/wiki/LocalSettings.php --install
php maintenance/run.php MeridianAutowiki:InstallPages --conf /private/wiki/LocalSettings.php
php maintenance/run.php MeridianAutowiki:Import --conf /private/wiki/LocalSettings.php --package /private/autowiki/packages/BUILD
```

Install schema additions before serving code that uses them. The importer creates missing tables and backfills summaries. New manifests are compressed; older JSON manifests remain readable. The tested database recovery uses a 256 MiB packet limit.

For coordinated upgrades, `deploy-adapter.py` prepares a content-addressed directory containing the entire extension and receiver runtime. It acquires the receiver's existing lock, installs additive schema first, checks unchanged human/publication state and configuration bytes, then switches explicit local bindings. It retains prior versions. Protected journals contain the exact prior configuration bytes; restrict access to them as strictly as service configuration. The tool does not commit code, deploy the game or publish a package.

Its protected JSON configuration names absolute `source` (the Autowiki tool directory), `releases`, `journalRoot`, `extensionSettings`, `receiverConfig`, `php`, `maintenanceRunner`, `settings` and `currentExtension` paths. Optional `switches` hold checked text replacements in job scripts, with `{extension}` and `{runtime}` placeholders for the new version. Keep unrelated settings intact. On Windows, `webPrincipal` grants that service read/execute access only to the completed version; it grants no write access. Configure `healthUrl` to the HTTPS MediaWiki `action=query&meta=siteinfo&format=json` endpoint so web-service permissions are checked in addition to CLI loading. A failed health check restores bindings only if human/publication state and switched configuration remain unchanged. Schema additions and human revisions are never deleted by rollback.

```sh
python tools/autowiki/deploy-adapter.py /private/adapter-deploy.json
python tools/autowiki/deploy-adapter.py /private/adapter-deploy.json --rollback /private/deployments/JOURNAL.json
```

Refresh the checked switch plan against the currently installed bindings before another upgrade. A changed binding or occupied lock is a stop condition, not permission to overwrite it. Rollback after later human edits or a publication requires review; routine rollback refuses it. Maintenance stdout/stderr stays in protected deployment diagnostics. Test the filesystem/rollback behavior with `python tools/autowiki/deploy-adapter.test.py`, then exercise installation and rollback against a disposable wiki.

The receiver configuration's optional `extensionDirectory` pins all publisher maintenance commands to that complete version. MediaWiki's extension-qualified maintenance lookup otherwise resolves its default extensions directory, even when `wfLoadExtension` loads a different manifest. On Windows, use `./maintenance/COMMAND.php` with the selected extension as the working directory: a raw drive-letter script path can be interpreted as an extension prefix. Pin scheduled reconciliation and worker commands to the same version. Restore the archived configured version inside the isolated filesystem, rather than loading a production absolute path or an older default extension directory.

`InstallPages` creates missing templates/help pages but retains existing human-owned pages. Upgrade an existing template through a reviewed revision. The current Game Icon call is `{{#gameicon:{{{id|}}}|{{{profile|initial-south-first-frame}}}}}`; `profile` is optional in TemplateData.

## Validate

`npm test --prefix tools/autowiki` runs the Node checks. For DOM interactions, run `npm ci --ignore-scripts` inside `tools/autowiki/ui-tests`, then `node --test workshop.test.mjs`. The test uses actual Vue/Codex components; it does not replace browser layout checks.

Extension maintenance tests include `Test.php`, `ExtendedTest.php`, `FeatureTest.php`, `ApiTest.php`, `ComponentTest.php`, `IssueFilterTest.php`, `AssetProfileTest.php`, `DeploymentStatusTest.php`, `ProjectionTest.php` and `ReleaseTest.php`. Database fixtures require disposable loopback-3307 settings; FeatureTest also requires isolated uploads. Run InstallPages before ComponentTest. ProjectionTest requires external search disabled. ReleaseTest requires verified releases enabled and a fresh receipt path under the isolated restore directory. Fixtures modify pages and images. Invoke the source script explicitly to avoid testing an older installed maintenance file:

```sh
php /wiki/maintenance/run.php ./tools/autowiki/mediawiki/MeridianAutowiki/maintenance/FeatureTest.php --conf /private/isolated-settings.php
```

Inspect output as well as exit status: MediaWiki can print a fatal exception and still return zero. Generation requires an explicit completion marker. Compare consecutive complete packages; never edit generated inventories to force acceptance.

## TGS handoff

The wiki must identify the build players are using. TGS distinguishes the active compile job from the next staged job in its [installed-version DreamDaemon response](https://github.com/tgstation/tgstation-server/blob/tgstation-server-v6.19.2/src/Tgstation.Server.Api/Models/Response/DreamDaemonResponse.cs). The current browser client is [tgstation-server-webpanel](https://github.com/tgstation/tgstation-server-webpanel); the archived desktop ControlPanel is not the source for its labels. A successful compile or master push alone does not establish the active build.

Local inspection found the `tgstation-server` service, `C:/tgs/instances/meridian-rift-main/Game/Live`, and existing PreCompile/PostCompile scripts. Autowiki has not changed the running-game scripts/settings. TGS 6.19.2 / API 10.14.1 accepts the supplied service login. Live validation succeeded for instance 1: the reader obtained the active compile job and BYOND identity and confirmed the local Live directory, with an unchanged job on its second read. Instance discovery additionally requires global Instance Manager `Read`; `List` across every instance is unnecessary. Alternatively, configure the known numeric instance ID. The instance itself needs DreamDaemon `ReadRevision` and `ReadMetadata`. In the installed web interface, open the instance Permissions page, select the account and the **Server** tab, enable **View Current Compile Jobs** and **Read Settings**, then click **Save Tab**.

`tgs.js` reads the active job twice, checks the local Live directory against that job, and emits only selected build metadata. Its private configuration contains `url` (locally `http://127.0.0.1:5000/api`), `credentialsFile`, `instancePath` and either exact `instanceName` or numeric `instanceId`. The credentials file uses separate `username:` and `password:` lines. Tokens stay in memory; HTTP outside literal loopback and redirects are rejected.

```sh
node tools/autowiki/tgs.js /private/tgs-reader.json
```

The basic observation remains ineligible for publication. `sourceDeployment()` adds independent evidence for the supported **source-defaults** export: it reads configuration blobs from the exact active Git object in the TGS repository, hashes their inventory in deterministic filename order and rechecks TGS. Add the absolute `repository` path and optionally an absolute `git` executable to the TGS configuration. It ignores current working-tree configuration. This evidence authorizes source defaults only; it does not establish round configuration, server overrides or runtime effects.

The private deployment receipt has `version: 1`, `id`, `commit`, `configurationDigest`, `configurationScope`, `compiler`, `runtime` and `observedAt`. Configuration digest is SHA-256 of the ordered configuration-input inventory. Compiler/runtime values and the exact commit must match the package. Observations expire after two minutes. Test-merged game commits need their own trusted matching packages; an attested master package cannot stand in for them. Never copy a package's claimed digest into an allegedly independent receipt.

`publish.js` takes a package directory and private JSON configuration with absolute `php`, `maintenanceRunner`, `settings`, `packageStore` and `deploymentFile` paths, plus optional `wiki`, `gh` and `baseline`. The GitHub CLI must support the attestation flags in `release.js`. Protect deployment and verified receipts from web-service write access.

```sh
node tools/autowiki/publish.js /private/downloaded-package /private/autowiki-publisher.json
```

With `tgs` configured, the command checks the active wiki release, obtains current deployment evidence, validates attestation and semantics, copies immutable files, imports images and prepares search. It then refreshes TGS evidence and verifies again before activation with an expected-current-build guard. A game switch during preparation prevents activation. A repeated request for the already-active package performs no publication writes. Retain previous packages in `packageStore/packages/BUILD`.

`receiver.js` runs one bounded inbox cycle using the publisher configuration plus absolute `inbox` and `statusFile` paths. It selects exactly one clean package for the observed commit, refuses ambiguous candidates and writes sanitized status for the workshop. A complete manually supplied package must arrive only after its download finishes.

Set `artifactSource.python` to a protected absolute Python 3 runtime to enable automatic GitHub retrieval when no matching inbox package exists. `githubTokenFile` is an optional absolute path to a dedicated service token; a matching downloadable package requires it, and attestation verification always requires an explicit service credential. Use a fine-grained token scoped to this repository with Actions read access; private repositories also need the appropriate attestation read access. The receiver never borrows a desktop login. GitHub documents the [artifact API and its read permission](https://docs.github.com/en/rest/actions/artifacts) and the [attestation verification constraints](https://cli.github.com/manual/gh_attestation_verify).

The locator accepts the latest successful run of the designated workflow on master for the exact active commit, from the same repository and a push, schedule or manual workflow event. Its separate `autowiki-publication-COMMIT` artifact contains only the package and is retained for 90 days, subject to repository limits. Failed runs, fork sources and test-merged game builds are ineligible for this builder path. Missing, expired and unavailable packages receive specific dashboard explanations. Test merges need their own trusted builder design before automatic publication can support them.

Downloads have time and size bounds, verify the archive's GitHub SHA-256 digest and send the API token only to api.github.com. Signed storage receives no API credential. The standard-library extractor rejects links, traversal, duplicate paths, unexpected files and excessive expansion. Complete package checks run before an atomic inbox promotion. Downloads remain untrusted until the existing publisher verifies manifest attestation, semantics and fresh deployment evidence. Temporary extraction directories are removed on failure; no downloaded code is executed. `extract-artifact.test.py` tests the archive boundary and runs in CI alongside the Node tests.

Deploy a protected runtime copy; do not schedule a mutable checkout as SYSTEM. `run-receiver.ps1` can be called at the end of the existing wiki job runner. The Meridian installation now does this under its existing five-minute task, which uses IgnoreNew and a 30-minute execution limit. Runtime configuration and the TGS credential copy are restricted to SYSTEM, local administrators and Moonridden. The web account can read only sanitized status and publication evidence. GitHub CLI 2.100.0 is installed in the protected runtime and its required attestation flags were checked.

Set `MeridianAutowikiReceiverStatus` to `statusFile` and `MeridianAutowikiDeploymentFile` to `deploymentFile`. The Publications view reports waiting, failed and stale checks with the active game identity. A directory lock prevents concurrent receiver cycles. After an interrupted process, confirm no receiver or child publication process is still running before removing that exact lock directory; never clear it automatically based only on age. Status becomes stale after 15 minutes. Receiver failures retain the prior public release and a bounded private log.

The live receiver has successfully observed TGS and completed through the existing SYSTEM task. Automatic retrieval is installed with a protected Python standard-library runtime. It currently reports `awaiting-package` with the test-merge explanation; the Autowiki branch remains uncommitted and no dedicated GitHub service credential has been configured. No dirty review package was activated. A complete trusted release remains to be tested after the branch and matching game build are reviewed and deployed through their normal process.

## Authenticated publication review

Builder authentication and semantic approval are separate. After validating a clean package, matching deployment evidence and builder attestation, the receiver writes a protected origin receipt and complete assessment under `authenticated/BUILD.json` and `review-reports/BUILD.json`. A failed semantic assessment withdraws any prior public approval for that package before replacing the review report. An origin receipt permits inspection only.

`MeridianAutowiki:Review --package PATH` validates the origin/report digest, imports the immutable data and images, and materializes generated findings in `maw_gate` and `maw_gate_finding`. These tables are separate from human revisions. The command neither activates a release nor prepares its public search. Repeated identical assessments do not rewrite findings; failed replacements roll back. Install the additive tables before deploying the new code.

The receiver reports `review-required` for authenticated semantic failures. In Publications, select the build and open **Publication Findings**. Findings are searchable and paginated, with links to current or retained historical source records. Dataset-qualified identities distinguish, for example, an entity from a vending record at the same source address. Passing reassessments clear generated findings without resolving or rewriting human decisions.

Public receipts bind the exact passing assessment digest as well as the deployment receipt. MediaWiki rechecks both before activation; older public receipts without assessment evidence need fresh verification. Only current source/deployment verification plus a passing semantic gate can authorize publication. Reviewed partial preservation uses native decisions and an assessed source-selection snapshot; [LAST-GOOD.md](LAST-GOOD.md) describes the resolver, visibility, provenance and activation requirements.

`GateReviewTest.php` checks authentication, complete pagination, qualified identities, idempotence, replacement rollback and retained human state. `ApiTest.php` checks reviewer access and anonymous denial for findings. Publisher tests exercise semantic failure admission without public approval; the separate local integration fixture runs the real Node publisher and MediaWiki review import against the disposable database, mocking only external builder attestation.

## Human guide and appearance reviews

`Game Dependency` provides visual-editor parameters for a fact or tested scenario used by human prose. Its `id` is required; `field` and the guide's actual section URL anchor are optional. Blank section links to the page. Saving and removing the template registers and clears the dependency without inserting content or rewriting instructions. The raw `gamedependency` parser function is equivalent. The `maw_guide_use` table retains every distinct section and the actual suffixed anchors of repeated rendered facts. Purge dependencies remain deduplicated. Its additive schema migration backfills older anchors without replacing current multi-section uses; run the updated schema before deploying code that reads this table.

`UpgradeGuideHelp` updates the recognized original dependency paragraph and inserts the missing identity-reconciliation section with a parent-revision guard. Existing custom dependency text or an ambiguous insertion point causes it to stop for review; an existing identity section is retained. Imports do not invoke the upgrade. `InstallPages` creates a missing Game Dependency template and retains existing pages.

New alternate-appearance reviews fingerprint only their selected profile. Unrelated profiles and metadata ordering do not invalidate them. Existing reviews retain their original meaning until explicitly updated. Rejections use separate revision identities per candidate and profile, and the picker labels previously rejected profiles without hiding an item's other appearances.

Decision reads ignore outdated or suppressed projections. While an unsuppressed human revision awaits projection, server-side public record reads fail closed, the workshop reports processing and publication cannot activate. Search preparation reconciles first and checks both current projections and the human revision epoch before completion. Existing cached guide HTML is updated by normal dependency delivery and purging.

Missing source identities can be reconciled through the workshop's historical-source comparison. The `relink` decision stores the prior build and selected current candidate as a native human revision. It is limited to a missing address and a present record of the same kind. Names, descriptions, parent and declared documentation identity are watched; unrelated changes do not discard the judgment. A link never rewrites source rows or retargets existing human revisions. Both sets of notes participate in normal applicability and conflict checks, and inherited-note edits keep their original targets.

Current source addresses take precedence over historical links. Conflicting applicable links resolve to neither candidate. Revocation separates the identities and refreshes dependencies on both sides. Links resolve directly to present source records; another move requires renewed evidence rather than an unchecked chain. Guide impact also finds uses of the former address before those pages are reparsed. `RelinkTest.php` exercises historical inspection, coexistence of notes, revision identity, guide sections, source changes, reappearance, conflicts and revocation against the isolated database.

## Source sheet recovery

All 248 cutter configurations currently have their authoring inputs; `cutter-debt.json` has no exceptions. `cutter-recovery.json` records the original Git blobs, source revisions, removal commit and full DMI signatures for the 40 restored sheets. No generated DMI changed during restoration.

`verify-cutter.py OUTPUT --cutter EXECUTABLE` copies every tracked configuration and input to a new review directory, runs the cutter there and compares all generated outputs. Both full DMI semantics and whole-file bytes are checked. The current 248 configurations passed both checks. This command does not write game files.

For future investigated deletions, `recover-cutter-sources.py` prepares a new immutable review directory from explicitly pinned debt entries. It runs the repository's cutter in isolation and compares every state, direction and frame, including timing, movement, looping, hotspots and pixels. `--apply` restores only verified missing source files with exclusive creation and current configuration/output hash guards. Keep the review report; remove a resolved exception so the same source cannot disappear unnoticed again. Never treat a name match or approximate image match as an original source recovery.

## Jobs and recovery

Run `./maintenance/Reconcile.php` through the MediaWiki maintenance runner, with the configured immutable extension as the working directory and the intended wiki settings passed with `--conf`. The receiver configuration's `extensionDirectory` identifies that version. Do not use the `MeridianAutowiki:Reconcile` shorthand on this installation: it can resolve the older default extension directory. Reconciliation runs before the existing MediaWiki job runner, rebuilding missed human-decision projections and queuing pending durable work. Avoid competing schedulers. The worker uses a private lock, repeatable processing and retained failures. Publications shows failures and offers retry after the cause is fixed.

The receiver wrapper runs `./maintenance/Operations.php --notify` after its deployment check. Complete queue totals and stale/failed work appear in Publications and the sanitized operations status file. Failure/recovery transitions use the existing private Discord outbox when `MeridianAutowikiOperationsNotifications` is enabled. Preserve its configured state directory alongside the outbox. Stable failures and ordinary waiting produce no repeated notices; webhook retry and rate limiting remain the existing worker's responsibility. Run `Operations.php` without `--notify` for a read-only diagnostic. Fixture notice tests use an isolated outbox and never send messages.

Back up the database, wiki configuration/extensions/uploads, Autowiki images, retained packages and protected operational configuration together. Restore into a disposable database/filesystem with email, Discord, OAuth, Cloudflare and search integrations disabled. Compare human revisions and attribution, decisions, issues, source identities and all referenced image hashes. Hash compressed manifest bytes before putting them into JSON audit output.

Verify the isolated data directory before shutdown or replacement and wait for the database process to exit before restarting. An intact archive is not a recovery test until it has been restored and compared.

Retain the active release until a replacement is fully verified and prepared. Reverting generated data must not revert human decisions. MediaWiki has no transaction spanning all page/image/search writes: retain journals, guard image hashes and page revisions, and inspect partial failures before retrying. Off-server storage remains deferred.

## Detector lifecycle and human review

Complete source scans maintain generated detection state separately from native human triage and assignment revisions. `maw_issue_detection` records the latest checked build and result; `maw_issue_event` retains state or evidence transitions. Identical scans do not append duplicate events. Both tables are included in recovery auditing. Install the additive schema before switching the adapter; Health requires both tables.

The source-appearance detector distinguishes an image that is now present from a source identity absent from the scanned package. The source-decisions detector checks current unsuppressed human revisions against watched source fields and selected image profiles. Its fingerprint includes expected and observed scope, not unrelated source values or a generic error string. Evidence previews are bounded; the full watched-field hash remains authoritative. Existing generic conflict dismissals can require one revalidation when this more precise evidence is first recorded.

A completed scan can report `not-detected`; it never resolves or deletes a human decision. Same-evidence recurrence retains an applicable dismissal; changed watched evidence requires review. Reader reports, legacy image matching and image publication conflicts remain separately managed and are not cleared by source scans. Pending human projections defer the decision scan. Reimporting an existing package refreshes detector results; normal delivery refreshes decision findings for the active build after native edits.

The workshop displays the last scan's build and time explicitly. This is the latest completed assessment, which can concern a draft; it is not a claim about the deployed game. Needs Attention excludes findings no longer detected while preserving All History, human resolution filters, and a No Longer Detected filter. Cause counts use the same query, state and assignee filters. Detector history is paginated and read-only, including safely rendered observed evidence.

`IssueLifecycleTest.php` exercises disappearance, reappearance, same-evidence dismissal, relevant versus unrelated changes, revalidated decisions, repeated imports, retained history pagination, reader-report separation and failed-scan rollback in the disposable database. `IssueFilterTest.php` checks queue/group agreement; `ApiTest.php` checks reviewer history access and anonymous denial. The source detector adapter is deployed through the versioned installer. Its latest scan identifies the unpublished construction review package explicitly; human revisions and public publication state were unchanged.
