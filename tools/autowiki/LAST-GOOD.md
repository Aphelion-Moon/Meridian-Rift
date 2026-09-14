# Reviewed partial releases

The reviewed preservation path passes isolated end-to-end publication and public-consumer checks. The matching extension, schema and receiver are installed as an immutable version; production backup restoration and aggregate verification pass. A trusted package for the actual running game remains required before public activation.

## Implementation status

The authenticated review path is live. The branch also contains a tested publication ledger, native preservation decisions, a side-by-side dashboard, and a candidate source resolver. The preservation additions and independent revocation repair are installed: editors can withdraw a decision after its watched source field disappears, without changing its original evidence or history.

Publication ledger entries are written in the activation transaction, not during import. Prepared publication evidence binds both the exact human revision digest and public payload digest. A failed activation, changed payload, or changed review state cannot create publication history. `SourceSelection` resolves candidate records with explicit original build, commit, identity and reviewed publication provenance; it does not authorize public reads or publication.

The staged publisher now obtains a local MediaWiki selection snapshot after authenticated import. It rebuilds selected records from immutable historical packages, checks the supplied source evidence, applies allowed editorial corrections, and runs the existing contract and semantic gates against the prior published selection. Its receipt and assessment bind the exact selection bytes. MediaWiki rechecks current human revisions and the expected active publication before consuming that approval. The publisher rechecks the selection after long preparation and does not treat an unchanged build ID as an unchanged publication when human revisions differ. A compressed, hashed selection snapshot is stored with each successful publication.

The real Node/PHP integration fixture proves ordinary publication, failed-package admission to review, passing reassessment after native preservation, matching PHP approval, and withdrawal after native revocation. Only external builder attestation is mocked. It now activates the preserved selection, verifies the original public value, and proves that revocation withdraws the record without publishing its replacement.

`PublicView` checks the immutable published selection, source ledger and current native decisions for all public readers. References, guide components, API responses, images and search use the approved original fields and provenance. Retained records carry an older-documentation marker. Revoked, changed or conflicting preservation and corrections become unavailable until reassessment; ordinary annotations can update immediately. Reviewers must explicitly request an image preview to see an unapproved replacement.

Candidate catalogue rows and relationships are separate from their published projections. Activation copies them transactionally after approval checks. Background refresh checks the published selection, human revisions and prepared payload before changing search or catalogue data. Search validates each returned document against current fields and relationships. Guide cache invalidation precedes external delivery, including when indexing fails.

`PublicViewTest.php` exercises real MediaWiki rendering, anonymous and reviewer APIs, image bytes, relations, actual Typesense search, preservation/correction revocation, same-build preparation and search-outage cache invalidation. The source schema installer is additive and repeatable, including upgrades to existing preparation-evidence columns. Run it before installing code that uses new schema; do not infer prior publication history for legacy data. Versioned installation, CLI/web health, actual receiver observation and full backup restoration with the new schema pass. Authenticated browser visual checks and a trusted actual-game publication remain outstanding.

Run `npm test` in `tools/autowiki` and in `tools/autowiki/ui-tests`. Run `PreservationTest.php`, `SelectionTest.php`, `PublicViewTest.php`, `RevocationTest.php` and `ApiTest.php` only against the disposable MediaWiki database. `ReleaseTest.php` additionally requires disposable verified-release settings. `PublicationFixture.php` is a database-isolated integration helper, never an operational reset command. `AuditRecovery.php` includes the new ledger, immutable selection snapshots and preparation-evidence tables; use the matching schema when verifying a restore.

## Required behavior

1. Authenticate a clean package against the designated builder and exact observed game build before admitting it to automated review. Authentication permits inspection; it does not authorize public activation.
2. Import an authenticated package and expose complete, paginated publication findings even when semantic checks fail. Generated findings are separate from human decisions and are refreshed without rewriting human history.
3. Let an editor preserve an explicitly identified record from an actually published source build for one specified replacement build. Show current and retained evidence side by side. Require an explanation and a native revision guard. Revocation must be possible.
4. Preserve original package bytes and source rows. Materialize the public view from the reviewed source record and retain its original source build, commit, images and relationships. Public references must plainly identify retained data as older documentation.
5. Evaluate the resulting record set through the same semantic checks. Preservation cannot excuse an invalid package, canonical collision, unexplained dataset loss, incompatible relationship or changed runtime/configuration evidence.
6. Check current visibility as well as retained-source visibility. Source hiding and current human restrictions must not be bypassed by preservation. Changed evidence, ambiguous judgments or missing projections stop applicability.
7. Bind semantic approval to the complete human revision state and expected active build. Recheck before activation. Search, guide rendering, image delivery and direct public API reads must agree on the effective record and its provenance.
8. Preserve all human revisions during import, publication, revocation and generated rollback. A later source build requires renewed preservation evidence; do not silently chain old snapshots.

## Sequence

First separate authenticated review from public approval and expose generated publication findings. Then implement the human preservation decision and one shared effective-record resolver. Finally integrate effective package comparison, provenance presentation, search/images and activation guards, with isolated end-to-end tests of partial releases and revocation.

Production uses the tested selection pipeline and matching schema/runtime. It still refuses public activation without trusted evidence for the exact running game build.
