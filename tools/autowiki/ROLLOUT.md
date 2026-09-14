# Autowiki rollout

The wiki adapter, human workshop and background receiver are installed. Generated data is available for review. Automatic publication is waiting for the repository and game rollout below; it is not currently enabled.

## What needs a human

1. **Review the staged `codex/autowiki-integration` branch in GitHub Desktop.** The changes include the game exporter, its shared gameplay helpers, the wiki adapter and GitHub workflows. Follow the project's normal review and merge process. Nothing has been committed, pushed or deployed to the game by this work.
2. **Deploy the reviewed game source through the normal TGS process.** The running game must contain the reviewed exporter. Autowiki verifies the exact running source, including test merges; it will not describe a different build as the running game. No further TGS permission changes are currently needed for source observation.
3. **Provide dedicated GitHub service access for `Aphelion-Moon/Meridian-Rift`.** Package retrieval needs repository Contents read and Actions read. Optional automatic generation needs a separate service credential with Contents read and Actions write. Store credentials in protected local files and configure their file paths; do not commit them or use a personal desktop token. See `TEST-MERGE-BUILDER.md` for the receiver configuration fields.
4. **Approve a fixed builder version after review.** Select the reviewed builder commit and a protected `autowiki-builder-...` release tag. The receiver checks both the tag and the exact approved commit. A moving branch alone is insufficient for unattended use. Tag creation and repository protection settings have not been changed.

With these prerequisites ready, validate one real hosted generation/signing run, verify its package against the current TGS source, inspect publication findings, and confirm the human decisions survive activation. Enable automatic requests only after this end-to-end check passes. Hosted workflows have been validated locally; they have not yet been executed or proven in GitHub.

## Routine review

Open **Special:Autowiki → Publications** for the current game identity, generation status, complete delivery totals and actionable service findings. Failed deliveries remain ahead of completed work. Correct their cause before retrying. A missing trusted package is shown as waiting; a failed generation, stale receiver or failed delivery requires attention.

Human notes, corrections, assignments, dismissals and source selections remain native wiki revisions. Imports and service-health checks do not overwrite them. Authenticated visual checks at standard and narrow widths still require an editor browser session; the automated DOM tests are not a substitute for that check.

The existing five-minute wiki job schedule runs reconciliation, delivery, source observation and service health. No extra scheduler was added. Local backup and restore are verified; off-server storage remains deferred. Actionable failure and recovery notices use the existing wiki Discord channel, alongside workshop health and task exit status. Normal waiting and repeated identical failures stay quiet.
