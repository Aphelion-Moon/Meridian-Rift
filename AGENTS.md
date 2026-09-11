# Meridian-Rift agent instructions

Meridian-Rift is a BYOND/DreamMaker SS13 codebase downstream of Nova Sector and tgstation. Be direct, inspect existing implementations before editing, preserve unrelated work, and do not commit, push, reset, checkout, merge, or change branches without explicit authorization.

## Required reading

- All DM work: [.github/guides/STYLE.md](.github/guides/STYLE.md), [.github/guides/AUTODOC.md](.github/guides/AUTODOC.md), and [.github/guides/STANDARDS.md](.github/guides/STANDARDS.md).
- Routing: [docs/agent/README.md](docs/agent/README.md) and [docs/agent/source-authority.md](docs/agent/source-authority.md).
- Placement: [docs/agent/placement-and-markers.md](docs/agent/placement-and-markers.md) and [modular_nova/readme.md](modular_nova/readme.md).
- General gates: [docs/agent/verification.md](docs/agent/verification.md), [docs/agent/meridian-mcp.md](docs/agent/meridian-mcp.md), [docs/agent/rift-controller.md](docs/agent/rift-controller.md), [docs/agent/generated-content.md](docs/agent/generated-content.md), and [docs/agent/upstream-drift.md](docs/agent/upstream-drift.md).
- Dogmos ownership: [docs/agent/dogmos-integration.md](docs/agent/dogmos-integration.md), [docs/agent/dogmos-gameplay-events.md](docs/agent/dogmos-gameplay-events.md), and [docs/agent/dogmos-service-lifecycle.md](docs/agent/dogmos-service-lifecycle.md).
- Dogmos measurement and gates: [docs/agent/dogmos-performance-and-memory.md](docs/agent/dogmos-performance-and-memory.md) and [docs/agent/dogmos-verification.md](docs/agent/dogmos-verification.md).
- Native contract: [docs/agent/native-artifacts.md](docs/agent/native-artifacts.md).

Read [.github/guides/HARDDELETES.md](.github/guides/HARDDELETES.md) before `Destroy()` or reference-ownership changes, and [.github/guides/VISUALS.md](.github/guides/VISUALS.md) before planes, layers, filters, overlays, or visual systems.

## High-frequency rules

New Meridian-owned work belongs under `modular_aphelion` and uses canonical `APHELION EDIT` markers. Preserve inherited `modular_nova` paths and `NOVA EDIT`; do not convert them in bulk. Dogmos has one narrow fork-owned atmosphere exception documented in [Dogmos integration](docs/agent/dogmos-integration.md). It does not exempt unrelated machinery, gameplay, UI, or subsystem files.

Use Meridian-MCP for DreamMaker parsing, discovery, exact symbol inspection, references, diagnostics, and Tracy after `dm_parse_environment`; reparse after DM changes. Use PowerShell for DreamMaker, DreamDaemon, Rust, Docker, process measurement, and test entry points. Focused tests are iteration evidence, never a completion claim.

Treat human-authored creative work as protected. Agents may implement technical systems and mechanically integrate user-approved material, but do not author or materially rewrite art, sound, lore, flavor text, descriptions, or user-facing names. Present properly licensed external candidates for human selection before importing them.

Human-authored critical infrastructure is also protected. Before changing `BUILD.cmd`, `RIFT_BUILD.cmd`, bootstrap/build implementation, `.github/workflows/`, dependency or native-artifact authority, release tooling, Docker files, TGS scripts, or deployment configuration, name the exact file and effect, explain why a separate Meridian-owned extension is insufficient, and obtain explicit user approval. Broad feature or plan approval does not authorize these files.

Dogmos optimization targets DreamDaemon's constrained address space. Rust allocations in the currently loaded 32-bit DLL are DreamDaemon allocations. The planned 64-bit `dogmosd` service is measured separately; do not add its memory to DreamDaemon or optimize stable service RSS as a footprint goal.
