# Meridian Autowiki

Autowiki exports versioned game definitions, qualified appearances and executable documentation checks. The MediaWiki adapter imports immutable packages. People own explanations, policy, image mappings and editorial decisions in normal wiki revision history.

The [Autowiki Workshop](https://meridian-wiki.a13.info/wiki/Special:Autowiki) provides record inspection, image comparison, assignment, bulk review, human history, guide impact and publication status. Imports retain human decisions. See [coverage and remaining work](MODERNIZATION.md) and [operations](OPERATIONS.md).

## Generate and validate

Use Node 24 (minimum 22), the BYOND version in `dependencies.sh`, and the repository build prerequisites. Set `DM_EXE` to the compiler. Never enable `AUTOWIKI` on the running game; this target starts a dedicated process that exits on completion.

```sh
npm ci --ignore-scripts --prefix tools/autowiki
npm test --prefix tools/autowiki
node tools/autowiki/sync-contract.js
node tools/autowiki/generate-contract.js --check
node tools/autowiki/check-cutter.js data/autowiki-cutter-report.json
tools/build/build.sh --ci autowiki
node tools/autowiki/data-contract.js data/autowiki-data.jsonl data/autowiki-entity-icons data/autowiki-package data/autowiki-provenance.json
node tools/autowiki/semantic-check.js data/autowiki-package data/autowiki-report/semantic.json
```

On Windows use `tools/build/build` and BYOND's CLI `dd.exe`. Use a new package destination and keep source files unchanged between generation and packaging. Packages record source changes, configuration hashes, compiler/runtime identity, counts and full image checksums. Dirty checkouts produce review packages that cannot become authoritative public releases.

`contract.json`, `fields.js` and `appearances.js` define the consumer contract. `sync-contract.js` copies it into the extension; `generate-contract.js` produces [CONTRACT.md](CONTRACT.md) and `record.schema.json`. Update the exporter and both consumers together.

## Inspect and use

```sh
node tools/autowiki/coverage.js data/autowiki-package data/autowiki-report/coverage.json
node tools/autowiki/explore.js data/autowiki-package data/autowiki-report/review.html
```

Readers validate integrity before using records. Relationships outside the exported scope remain visible debt. Null, deferred, runtime-dependent and missing values must not silently become zero or invented gameplay claims.

There are 17 structured datasets and five appearance profiles. Existing generation of 16 legacy presentation templates remains compatible. `catalog_icons.py`, `icon-crosswalk.py` and the reviewed alias catalogue support incremental image migration. Pixel equality is candidate evidence, not permission to overwrite artwork.

Human guides use `Game Fact`, `Game Item`, `Game Icon`, `Game Recipe` and `Game Table`. `Game Dependency` tracks facts or scenarios used by human-written instructions without inserting visible content. Saved components register anchors and dependencies. Imports preserve surrounding prose and review history.

## Publication

The workflow runs on master pushes, daily at 04:05 UTC, and manual dispatch. It validates and preserves packages; master builds receive a GitHub artifact attestation. CI does not directly update the wiki when a build completes.

`publish.js` verifies the attestation and independently produced TGS active-deployment evidence, compares the previous package, stages immutable files, imports and prepares the release, then rechecks TGS before guarded activation. A protected inbox receiver now runs through the existing wiki job schedule and reports its status in Publications. Trusted artifact retrieval and a clean end-to-end release remain outstanding; see [the handoff](OPERATIONS.md#tgs-handoff).

The legacy `autowiki.js` defaults to a dry run and accepts only allowlisted generated templates and `Autowiki-` PNGs. It requires an exact `WIKI_API_URL` and source SHA. Its optional write mode requires a restricted bot account and revision/hash checks. It is retained for compatibility; the current workflow does not invoke that write mode. Do not enable competing publication paths for the same content.
