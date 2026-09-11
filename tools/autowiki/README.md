# Meridian Autowiki publisher

Autowiki generates 16 data templates and their PNG icons from the checked-out game source. The [wiki reference hub](https://meridian-wiki.a13.info/wiki/Meridian_Rift:Autowiki) connects these datasets to the practical guides. Presentation templates live on the wiki; generated `Template:Autowiki/Content/*` pages are replaced by the workflow.

## Configuration and deployment

Use Node 24 (minimum 22) and `npm ci --ignore-scripts` in this directory. `npm test` exercises planning, validation, conflict detection, and failure handling without contacting a wiki.

The workflow requires these repository settings:

| Setting | Value |
| --- | --- |
| Actions variable `WIKI_API_URL` | `https://meridian-wiki.a13.info/api.php` exactly |
| Actions secret `AUTOWIKI_USERNAME` | A dedicated bot's BotPassword login, such as `MeridianAutowiki@Autowiki` |
| Actions secret `AUTOWIKI_PASSWORD` | That BotPassword, never the administrator password |

Before activating this publisher, create the dedicated wiki account, add only the `bot` group, and issue a [BotPassword](https://www.mediawiki.org/wiki/Manual:Bot_passwords) with the `basic`, `highvolume`, `editpage`, `createeditmovepage`, and `uploadeditmovefile` grants. Verify its effective rights include `edit`, `createpage`, `upload`, and `reupload`. Grant scopes are still limited by the account's actual rights. No administrator, interface-editor, delete, user-management, or site-configuration rights are needed. Test the BotPassword login and update both Actions secrets before merging; the publisher deliberately refuses administrator and non-bot accounts. Do not revoke the old automation credential until the replacement has completed a successful run and no other consumer needs it.

The schedule remains 04:05 UTC daily. The workflow only runs in `Aphelion-Moon/Meridian-Rift`, allows one publication at a time, and preserves generated inputs, preview, and progress artifacts for 14 days. Only `master` can reach the publication step; manual runs on other branches stop after generation and preview. Do not enable `AUTOWIKI` in a live TGS world: the build target runs a dedicated generation process that exits when complete.

## Preview and publication

Supply `WIKI_API_URL` and the 40-character `SOURCE_SHA` for the exact commit used to generate the inputs (`GITHUB_SHA` is used in Actions). Credentials are unnecessary for a preview:

```sh
node tools/autowiki/autowiki.js data/autowiki_edits.txt data/autowiki_files/ data/autowiki-report/preview --dry-run
```

The default is also a dry run. Review `summary.json`, `pages.diff`, and `plan.json`. The plan records previous page text/revisions and image hashes, proposed changes, destination, and source commit. Images must be PNGs and are always uploaded under `Autowiki-`; only the 16 explicitly listed generated page titles are accepted. A new dataset requires an intentional allowlist update.

To publish, also supply `USERNAME` and `PASSWORD` through the process environment and replace `--dry-run` with `--publish`. Publication builds a fresh plan, checks the bot identity, rechecks page revisions, uploads changed images, and then saves changed pages with revision guards. Identical content and image hashes are skipped. Errors exit nonzero; `published.json` records each completed write and the source commit. Logs and artifacts do not contain credentials.

## Recovery and limitations

MediaWiki does not provide a transaction spanning multiple pages and files. A failed run can have completed earlier writes. Inspect `published.json`, resolve the failure, and rerun the same generated inputs; completed identical changes will be skipped. Wiki history retains replaced content. For rollback, compare current revisions to the recorded publication and restore the previous revisions only after checking for intervening edits. Image writes have a final hash check, but MediaWiki's upload API has no atomic compare-and-swap guard; avoid concurrent manual changes to managed `Autowiki-` files.

The publisher validates the manifest and file headers, not gameplay semantics or every rendered wiki template. Review new generator output and rendered pages before rollout. Hidden fishing results intentionally use question-mark icons. The wiki's surgery tool wrapper temporarily retains the curated heat-source icon until the generated lighter replacement is visually verified. Core game compilation and generation should run in CI rather than consume the production host's resources.
