# Dogmos integration

This module initializes the in-process native gas registry, preserves controller recovery, schedules active turfs, and supplies gameplay and diagnostic adapters. Numerical state lives in the native engine inside DreamDaemon; DM retains scheduling and gameplay ownership.

Use [the in-process build contract](../../../docs/agent/dogmos-in-process.md), [integration ownership](../../../docs/agent/dogmos-integration.md) and [verification guide](../../../docs/agent/dogmos-verification.md). Native bindings and artifact defines are generated; never edit them by hand.


## Experimental mixture fusion

The `dogmos_mixture_fusion` startup flag is absent/off by default. Registration
requires the matching Aphelion native capability. It is a commissioning feature,
not a qualified recipe or an HFR replacement. The generated profile constants
come from the native `dogmos-core` fusion kernel. Native source documentation
`docs/agent/fusion-profile.md` records provisional values, provenance, accounting
and the remaining acceptance gates.

Eligible turfs, portable containers, tanks and pipelines use their existing
reaction processing. HFR-owned internal mixtures are explicitly excluded.
Hypernoblium and portable-container suppression retain their existing meaning.
One mixture admits at most one opportunity per two seconds, without catch-up;
existing processing owners remain awake while an eligible opportunity is waiting.
Changing the startup flag requires the normal shutdown/new-world lifecycle.

The gas analyzer reports current status and recent instability. Kennel's
on-demand inspection shows generic requirements, suppression/immutability,
holder status and the loaded profile/build identity. It never executes a reaction
body for inspection, and a requirement pass is not evidence of an earlier reaction.
No useful operating range or player recipe has yet been demonstrated.
