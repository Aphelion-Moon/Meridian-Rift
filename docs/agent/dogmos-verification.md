# Dogmos verification

Call `dm_parse_environment` before Meridian-MCP source analysis and reparse after changes. Use PowerShell and maintained entry points for DreamMaker, DreamDaemon, Rust and process measurements. Parser diagnostics are separate from compilation/runtime evidence.

Verify the installed native contract, compile with `BUILD.cmd` or the maintained test runner, execute focused integration checks, a fresh native-load boot and the full DM unit-test suite. Native source changes require pinned locked i686 Rust tests, strict Clippy, supported features and generated-artifact checks.

Bound test lifetimes and inspect fresh result/log artifacts and owned-process cleanup. Report focused/full tests, boot, shutdown, visual acceptance and performance separately. Record source and artifact identities; run whitespace and ownership-marker checks before handoff.
