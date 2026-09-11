# Verification matrix

| Evidence | Use | Completion boundary |
| --- | --- | --- |
| Static inspection | `rg`, Meridian-MCP navigation, review | Discovery only |
| Fast compiler gate | PowerShell invokes `C:\Program Files (x86)\BYOND\bin\dm.exe tgstation.dme` | DreamMaker acceptance only |
| Authoritative full build | PowerShell invokes `BUILD.cmd` | Repository build; inspect `$LASTEXITCODE` |
| Agent full-build wrapper | PowerShell invokes `RIFT_BUILD.cmd` or configured Meridian-MCP `rift_compile` | Report separately from the human entry point |
| Focused unit tests | Existing targeted harness/configuration | Named iteration evidence only |
| Full unit suite | CI-equivalent complete configuration | Required for applicable DM behavior completion |
| TGUI | Checked-in lint/typecheck/test entry point | Required for frontend changes |
| Maps | Mapmerge/maplint plus automapper validation | Required for map/automapper changes |
| Rust/Dogmos | Exact toolchain, targets, tests, bindings, artifacts, DM integration | Both native process roles and DM must pass |
| Real entry point | Shipped command, binary, browser route, container, or TGS path | Required for changed integration behavior |

Use PowerShell for Windows build/test orchestration and inspect `$LASTEXITCODE` after native commands. Do not describe parser success, process liveness, a direct compiler gate, or focused tests as equivalent to the complete repository path.

Any proposed edit to `BUILD.cmd`, inherited bootstrap/build implementation, workflows, release/deployment scripts, Docker, TGS, or native artifact authority requires a new exact-file/effect explanation and explicit approval. Prefer a Meridian-owned wrapper that delegates to the human entry point and detects contract drift.

Report:

```text
Command:
Platform/tool version:
Scope: focused | subsystem | full
Result and exit code:
Artifacts/log marker:
Warnings/runtime signatures:
Required gates not run:
```

Dogmos adds target, native-load, process-lifecycle, contract, and memory evidence; follow [Dogmos verification](dogmos-verification.md).
