# Exact source for TGS test-merge builds

Status: source reconstruction, separate hosted generation/signing workflows, merged-source bindings, receiver verification/retrieval and durable unattended requests are implemented. The wiki adapter and receiver are installed as an immutable version, with dispatch disabled. Hosted workflow changes remain staged for review; hosted execution remains unverified. A matching Git tree alone does not authorize publication.

## Verified source identity

The current [TGS server repository](https://github.com/tgstation/tgstation-server) is the server-side reference for this integration. Its [revision model](https://github.com/tgstation/tgstation-server/blob/dev/src/Tgstation.Server.Api/Models/RevisionInformation.cs) exposes the active test merges; its [base revision model](https://github.com/tgstation/tgstation-server/blob/dev/src/Tgstation.Server.Api/Models/Internal/RevisionInformation.cs) separates the local revision from the most recent remote commit. Merge records include pinned target commits, timestamps and IDs. The API collection itself does not promise ordering.

The client now retains that information, validates each pinned commit, and orders the collection by merge timestamp and ID. It hashes the exact deployed Git tree as well as the source-default configuration. Missing identities remain unknown; malformed or ambiguous merge entries are refused.

`merge-source.js` creates a new isolated Git object store using local shared objects. It never checks out game files or runs the game, source build scripts, Git hooks, or configured merge drivers. Global/system Git configuration is disabled. Each pinned head is merged into the preceding result; the final tree must equal the tree independently read from the active TGS commit. A conflict or mismatch remains a failed proof. Do not replace this comparison with a name, PR number or branch match.

```powershell
node tools/autowiki/merge-source.js PRIVATE-RECEIVER-CONFIG NEW-ABSOLUTE-OUTPUT-DIRECTORY
```

On 14 September 2026, the real instance's job 71 reconstructed exactly:

| Input | Pinned commit |
| --- | --- |
| Remote origin | `da49ddcde780df92785bd86e08f53f60786d3c32` |
| PR 172 | `e93e4aeb5f390c1c897993e07a5d25b1d8ee5cf8` |
| PR 180 | `8f78285ebea189c66d9d59f522f0052f888e9fcb` |
| PR 181 | `6dd04be489dd727990792ead51c5adc543c25e4b` |

The reconstructed tree was `96923a5a02dc598e5800f387457d92c65dadb05f`, matching deployed commit `0e0b4ab463abe45e939a9782faaeeea3965b1744`. Synthetic reconstruction commits need not share TGS's timestamps or commit IDs. Their tree identity is the relevant content comparison. The result explicitly remains `publicationReady: false`.

## Hosted builder requirements

Use a protected workflow on the repository's default branch. Its data inputs should identify the origin, ordered pinned heads, expected tree and required BYOND version. Reconstruct from those remote Git objects and require the expected tree before generation. Never accept a moving PR head as a substitute when a pinned object cannot be retrieved.

Keep build execution and signing in separate hosted jobs. The job executing game code should have no signing permission or long-lived service secrets. The signing job must execute only trusted builder code, independently validate source identity and package contents, and bind the reconstructed tree, merge inputs, configuration, compiler/runtime and manifest digest. Do not trust a provenance file merely because the build job wrote it.

GitHub recommends trusted reusable builders when caller-controlled code could influence attestation. [GitHub CLI verification guidance](https://cli.github.com/manual/gh_attestation_verify) documents workflow identity, source constraints and rejection of self-hosted builders. [GitHub artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations) describe provenance as a link to the producing source and instructions, not proof that every generated fact is correct.

The existing verifier pins the master workflow's source commit directly to the game commit. A combined-build path needs a separate verified source binding; simply removing `--source-digest`, accepting any signed manifest, or allowing any self-hosted runner is insufficient. Artifact lookup must also use the verified tree/build context rather than pretending the synthetic TGS commit is a normal master workflow run.

Before activation, independently reobserve the live TGS identity and configuration, validate the source binding and attestation, run semantic/selected-source assessment, and retain existing publication guards. Test source mismatch, reordered or changed merge heads, conflicts, unavailable pinned objects, compiler/configuration drift, forged build metadata, and a game switch during preparation.

The current running source must itself contain the reviewed exporter. This work does not overlay new exporter code onto an old tree and then claim the result came from the unmodified deployed source. Game-branch review/deployment and dedicated GitHub service credentials remain external prerequisites. The normal master workflow's signing isolation is staged locally; no workflow has been dispatched and no TGS hook has changed.

## Staged master-build signing isolation

The normal generation job has read-only repository permissions and no OIDC or attestation permission. An unsigned, attempt-specific artifact passes to a separate hosted signing job. That job checks out the trusted workflow commit, downloads data into a separate directory, and runs `check-signing-input.js` from the checkout. It runs neither game binaries nor scripts from the artifact. Checkout credentials are not persisted, and the workflow's external actions are pinned to verified commit IDs.

The check validates every dataset and image through the shared package reader, rejects unexpected top-level files, and compares declared configuration and exporter hashes against committed Git blobs. It also requires clean provenance, the fixed hosted build options and the committed BYOND version. The compiler binary hash is required as recorded evidence; this check does not independently verify the compiler binary or reproduce generated facts. Source metadata can be checked independently without claiming the build's output is infallible. Semantic review and live deployment verification still apply after signing. This follows GitHub's distinction between provenance and correctness in its [artifact attestation guidance](https://docs.github.com/en/actions/concepts/security/artifact-attestations).

The normal master publication artifact retains the existing name and workflow identity, so its exact-commit receiver checks remain in force. Candidate names include the run attempt; rerun all jobs to regenerate a candidate after failure.

## Staged test-merge path

`autowiki-test-merges.yml` accepts a bounded JSON source plan with version 1, `originCommit`, `sourceTree`, and an ordered `merges` array of PR numbers and full commit hashes. Both jobs independently fetch the exact objects from the fixed Meridian repository. `prepare-merged-source.js` uses complete history, isolated Git configuration, disabled hooks and deterministic synthetic commits. A missing object, merge conflict or final tree mismatch stops the job. It checks out the resulting source only after proving the expected tree. Generation uses that source's exporter; the signing job reads source blobs and validates data without running its build scripts or binaries.

The generation job has no signing permission. A fresh signing job uses the trusted workflow checkout's `bind-merged-package.js` to check package integrity, clean provenance, compiler/runtime requirements, exporter/configuration hashes and generation parameters against independently reconstructed source. It adds reconstruction context to the manifest and writes `source-binding.json`, which binds the manifest digest, generated commit, complete plan, source tree, configuration digest, BYOND versions and trusted builder commit. The separate binding is attested. Its manifest digest covers the package's complete dataset/image inventory. These checks do not independently reproduce the facts or compiler executable; semantic assessment and human review still apply.

The receiver requires a private `testMergeBuilderCommit` setting containing the reviewed 40-character commit that owns the workflow. For unattended operation, set `testMergeBuilderRef` to an approved release tag under `refs/tags/autowiki-builder-...`. The default `refs/heads/master` remains compatible for initial testing but requires renewed approval when master advances. `gh attestation verify` checks the binding against `autowiki-test-merges.yml`, the exact approved source ref, that exact builder digest, and hosted runners. The receiver separately compares the signed plan/tree/configuration/engine with a fresh TGS observation. Normal master packages continue to require the exact game commit.

Artifact names contain the canonical plan's SHA256. Lookup only considers successful manual-dispatch runs of the pinned builder. A retained request journal supplies the exact run ID, avoiding any dependence on accumulated workflow history. Without one, lookup searches at most 20 candidate runs from the latest bounded 100-run inventory. A tag run can omit `head_branch`; lookup is not authorization, and signature verification still requires its exact approved ref and digest. The data-only extractor allows the binding as one additional flat JSON file, bounded to 64 KiB. Reconstruction context in the manifest distinguishes immutable packages produced under different builder commits or refs; old builder bindings are excluded from current candidate selection.

Preparation and activation retain the existing fresh TGS observation, semantic assessment, human-selection digest and active-publication guards. A local fixture exercises real Git reconstruction twice, package creation, source binding, immutable copying, repeated verification, source-selection assessment and refusal after a source switch during preparation. Only the external signature service and PHP maintenance calls are fixture adapters in this test. It is not evidence of a hosted run or a live merged-package activation.

Enabling unattended publication still requires review/publication of the branch, deployment of a game source that contains the reviewed exporter, dedicated GitHub service credentials, and approval of the builder's exact release tag and commit. No tag was created by this implementation. The live adapter and receiver are installed from the tested immutable inventory; dispatch remains disabled and no merged package has been activated. No workflow dispatch, game deployment or TGS hook change has occurred.

## Durable unattended generation requests

With `buildRequests.enabled` explicitly true, a missing merged-source package can trigger its own generation. The receiver computes the source plan from current TGS evidence. It requires a separate `buildRequests.githubTokenFile`, an absolute `buildRequests.directory`, and the approved `testMergeBuilderCommit`. It does not borrow the download credential or desktop GitHub login. The dispatch credential needs repository Actions write and Contents read permissions; retain the existing dedicated read credential for retrieval and verification.

`build-request.js` checks the active workflow and selected builder reference, then creates and flushes an exclusive journal claim before POSTing. The request ID hashes the builder commit, approved ref and canonical source plan (existing master request IDs remain compatible). A second cycle or concurrent claimant cannot issue a duplicate automatic POST. The workflow receives the approved builder commit/ref and a correlation ID; its jobs also require their own ref and commit to equal those inputs. If the ref moves during dispatch, the receiver will refuse a run from the wrong builder and signature verification remains pinned.

A reviewed release tag decouples the builder's update cycle from game changes. GitHub allows workflow dispatch by branch or tag; the receiver resolves both lightweight and annotated tags, checks the exact returned reference, follows at most five tag objects with cycle detection, and requires the approved commit. [Git references can move](https://docs.github.com/en/rest/git/refs#get-a-reference), so the tag name alone is never trusted. Protect builder tags through repository rules and issue a new approval only when the builder changes. The builder can fetch new pinned game inputs while its own reviewed code remains fixed. No branch change, tag creation or repository-rule mutation is performed by the receiver.

The [current GitHub dispatch API](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event) returns a workflow run ID. The client also handles older accepted responses without an ID. Lost responses, server errors, interrupted processes and malformed responses leave an uncertain claim. Reconciliation searches for the exact correlation title and validates workflow, builder commit, ref-related metadata, event and repository before following a run. Known IDs are polled directly. Uncertain lookups start five minutes before the recorded request; first-time lookups cover the preceding day. This bounds irrelevant history while retaining the uncertainty window. A timeout, missing response or absent result is never treated as proof that a recorded request failed to reach GitHub. The bounded run listing stops for operations review if it cannot establish absence.

The workshop shows requested, queued/running, finished, failed, uncertain, credential, builder-approval and request-rejection states. Run links are constructed from a validated numeric ID under the fixed repository URL. Generated status cannot inject URLs, private logs or error bodies, and it does not modify human decisions.

Keep the request directory under the backed-up operations tree, for example `D:/Services/MeridianWikiOps/autowiki-receiver/build-requests`; do not use the excluded `logs`, `staging` or `restore-test` directories. Retain its journal with the receiver configuration and package store. A completed failure requires investigating the linked GitHub run and rerunning all jobs after the cause is fixed. A definite HTTP rejection can be retried by an operator under the receiver's existing lock:

```text
node build-request.js retry-rejected PRIVATE-RECEIVER-CONFIG REQUEST-ID
```

This command only retries the exact rejected request for the currently observed source and approved builder; it preserves previous attempts. It runs a normal receiver cycle, so an already available package follows normal verification instead. It cannot retry an uncertain or running request. For uncertain requests, continue reconciliation or inspect GitHub manually; never erase the journal to manufacture a new automatic request.

Local tests cover durable claiming before dispatch, concurrent first observations, lost-response reconciliation, failed and rerun jobs, source/builder mismatch, missing dedicated credentials, bounded HTTP responses, explicit rejected-request recovery, and the receiver's missing-package trigger. They use fixture HTTP clients and do not prove a hosted run. Generation and signing remain disabled in live configuration until reviewed rollout.

## Adapter installation verification

The immutable adapter/receiver inventory `019eb0fb67d2e6ab39516765605016a63cec5897c7a3e6a6832997e2f9e02ce2` was installed on 14 September 2026 after a fresh backup and an actual disposable-database rehearsal of installation, rollback and reinstallation. All 30 recovery aggregates and all 33 human decision revisions remained identical. The installed receiver's module graph loads, the real PHP status test passes, and the live receiver successfully observes the existing three-merge TGS build while remaining in `awaiting-package`. Health checks confirm the intended code directory and web-service access. The live post-upgrade comparison preserves all 16,657 managed image hashes. This verifies the adapter rollout and data preservation; it does not replace hosted signing or a live game-aligned publication test.

A second full backup, `meridian-20260914T064448Z.zip`, was restored after installation. The recovered configuration loaded this exact adapter from the restored operations tree, and all 30 aggregates, 33 human revisions and 16,657 image hashes matched live again. The isolated database was shut down after checking its data directory. Recovery keeps external integrations disabled and must reconcile any GitHub requests newer than the archive before enabling the receiver.

The later operations-health upgrade is installed as `f9260c0a7bd1ed8e4b4c44dcd63b487951ba42197a137deb675bb67ca8df54c5`. Its full archive `meridian-20260914T070239Z.zip` was restored with the exact adapter and all 30 aggregates matching live. See `ROLLOUT.md` for the remaining human-controlled rollout steps.
