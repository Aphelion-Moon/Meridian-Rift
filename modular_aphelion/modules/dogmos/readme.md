# Dogmos

Module ID: `DOGMOS`

This module initializes the Rust atmospherics library before turf construction and provides the
Dogmos-specific subsystem state and turf hooks that do not belong in the atmospherics core.

For a technically accessible explanation of Dogmos, its architecture, current status, and how it
differs from a non-Dogmos installation, see the [Dogmos Tech Memo](../../../docs/tech-memos/dogmos.md).

## Contents

- `AGENTS.md`: scoped instructions for agents changing the Dogmos boundary.
- `code/dogmos.dm`: Dogmos subsystem and integration state.
- `master_files/code/game/turfs/`: turf registration, temperature authority, adjacency, and space
  boundary overrides.
- `tgui/packages/tgui/interfaces/DogmosKennel/docs/`: Markdown source for the Kennel's About,
  Glossary, and Credits tabs.

The station-safe `/obj/item/clothing/glasses/meson/engine/dogmos` is research-buildable. Its modes
include breach alerts and reaction profiles backed by Kennel overlays. The `/admin` subtype adds
high-cost reaction profiling, structure pins, the full overlay set, and area-blueprint imaging; it
is not a station research design.

Related core includes are `code/__DEFINES/dogmos_defines.dm` and the generated
`code/__DEFINES/dogmos_bindings.dm`; they must remain in core for include-order compatibility. The
planned paired shim/service contract also generates `code/__DEFINES/dogmos_contract.dm`. Never
hand-edit either generated file.

The remaining gas and turf processing implementation stays in the core atmospherics files because it
must preserve their include order and existing call sites.

`code/modules/atmospherics/machinery/other/meter.dm` removes pipeline wakeup references only for
pipe targets during deletion; turf meters share the same cleanup path. Regression tests for both
target types live in `code/service_backend_test.dm` in this module.

## Ownership and process boundary

The fork-owned exception is limited to the forced implementation under
`code/modules/atmospherics/gasmixtures/**` and `code/modules/atmospherics/environmental/**`, plus the
two generated Dogmos define files named above. New Meridian
edits outside that exception use `APHELION EDIT`; inherited `NOVA EDIT` remains unchanged. Unrelated
atmos machinery under `code/modules/atmospherics/machinery/**`, gameplay, UI, subsystem, build, and
deployment files are not exempt.

The current `dogmos.dll` is a 32-bit in-process library, so its allocations consume DreamDaemon's
address space. The target architecture keeps only a bounded BYOND/IPC shim in-process and moves
growing simulation state to 64-bit `dogmosd`. DreamDaemon memory is the footprint target; service
memory is reported separately. See `docs/agent/dogmos-integration.md`,
`docs/agent/dogmos-gameplay-events.md`, `docs/agent/dogmos-service-lifecycle.md`, and
`docs/agent/native-artifacts.md` before changing the boundary.
