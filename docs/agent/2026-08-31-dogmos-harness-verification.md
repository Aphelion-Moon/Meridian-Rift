# Dogmos RIFT migration verification

Date: 2026-08-31

## Controller gates

| Gate | Result |
| --- | --- |
| Biome check for `tools/rift` | Passed |
| Bun controller tests | 92 passed, 0 failed |
| `RIFT.cmd doctor --profile dogmos --network offline` | Passed, run `20260831T133624Z-bac3955a` |
| `RIFT_BUILD.cmd` | Passed full build, run `20260831T135815Z-bf35283c` |
| Focused Dogmos test on MetaStation | Passed 1/1, run `20260831T134606Z-106a9fec` |
| 30-second Dogmos soak on full RuntimeStation | Passed, run `20260831T135116Z-bec0d18c` |

The first focused RIFT attempt, `20260831T133752Z-5de22dc3`, exposed that this checkout's unit-test JSON includes `duration` and `runtimes`. The parser was repaired to validate that five-field schema, covered by regression tests, and the identical focused command passed on rerun.

## Native gates

Pinned toolchain: `rustc 1.98.0 (88d9e12ae 2026-08-18)`.

The following passed in the clean `aphelion-dogmos` checkout at revision `26ab4fd1bf7bf9605309c0fc7ed7d2100366a2cc`:

- `cargo +1.98.0 fmt --all -- --check`
- `cargo +1.98.0 clippy --workspace --locked --target i686-pc-windows-msvc --all-targets -- -D warnings`
- `cargo +1.98.0 test --workspace --locked --target i686-pc-windows-msvc`
- `cargo +1.98.0 test --locked --target x86_64-pc-windows-msvc -p dogmos-core -p dogmos-protocol -p dogmos-server -p dogmos-process-metrics -p dogmos-identity`
- `cargo +1.98.0 build -p dogmos-byond --release --locked --target i686-pc-windows-msvc`
- `cargo +1.98.0 build -p dogmos-server --bin dogmosd --release --locked --target x86_64-pc-windows-msvc`

These source gates do not assert that the newly built binaries are the game's installed release. RIFT verified and ran the checked-in game contract at source revision `c42f3eb14f3bcb90b3c232ce0db3a58672a43f26`; arbitrary overlay bytes are rejected unless they match that installed contract.

## Matched old/new runtime evidence

Both paths used the checked-in native pair, repository configuration, full RuntimeStation, and a 30-second post-readiness window.

| Measurement | RIFT | Legacy PowerShell |
| --- | ---: | ---: |
| Initialization marker | 210.019 s | 211.947 s |
| Runtime signatures | 0 | 0 |
| Stage conflicts | 0 | 0 |
| Malformed responses | 0 | 0 |
| Pending mismatches | 0 | 0 |
| Lifecycle rejections | 0 | 0 |
| DreamDaemon private-byte maximum | 1,876,303,872 | 1,840,893,952 |
| `dogmosd` private-byte maximum | 138,280,960 | 138,412,032 |

The memory values are single-run observations, not a performance claim. RIFT used six bounded-window samples and additionally reported working-set maxima without combining the two process roles. The legacy run regenerated `icons/obj/fluff/map_previews.dmi`; it was restored exactly from the current HEAD after the test. RIFT's isolated workspace did not modify that repository file.

The matched legacy focused MetaStation command also passed one Dogmos lifecycle test with zero runtime signatures. Existing PowerShell scripts remain checked in for fallback and further parity work; this migration does not delete them.
