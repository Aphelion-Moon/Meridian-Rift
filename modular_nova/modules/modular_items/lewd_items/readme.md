# Portal items and structures

The handheld [device](code/lewd_items/portal_fleshlight.dm) and
[receiver](code/lewd_items/portal_panties.dm) connect two equipped endpoints. The
[portal bore](code/lewd_machinery/lewd_portals.dm) creates a pair of wall portals
and a body relay for their occupant. Both use the generic
[interaction route API](../../interaction_menu/readme.md).

## Controls

- Link the handheld device and receiver by using either item on the other.
- Equip the receiver in a specific genital slot through the interaction panel,
  or equip it as a mask for the mouth endpoint.
- Activate the handheld device in hand to cycle the target used when selecting
  the groin. Other selected body zones choose their corresponding endpoint.
- Right-click the device or receiver to toggle that item's anonymity. Alt-click
  either linked item to unlink it.
- Use the bore on two supported walls to create its portal pair. Activate an
  empty bore to change modes; activate it after placement to collapse its portals.
- Right-click an unoccupied wall portal to change both endpoints' mode. Buckle
  into one endpoint to create the relay at its peer, then unbuckle to leave.

## Ownership and validation

The handheld device and receiver are linked peers. Neither owns the other:
unlinking or deleting one clears the surviving item's reciprocal reference.
Equipped receiver authority comes from its exact inventory slot, not its location
inside a mob's contents or its cached target alone.

The bore owns its wall endpoints. Removing either endpoint collapses the pair.
The occupied endpoint owns its relay and borrows the occupant; teardown deletes
the relay and restores the occupant's presentation. The interaction component
only observes the relay through a weak reference. Keep teardown idempotent because
endpoint, occupant, and relay deletion can enter the same cleanup path.

Participant access checks belong in `portal_target_is_accessible()` in
[the human helpers](code/lewd_helpers/human.dm). Slot and link checks stay with
the items that own those relationships. Physical access and visible sprite state
are distinct: rendering checks native appearances separately and copies them
before filtering. A temporary visibility change used during a render is restored
within that render; it is not a session-long preference snapshot.

Routes in [portal_interaction_routes.dm](code/lewd_machinery/portal_interaction_routes.dm)
bind interactions to their current endpoints using weak references. Revalidate
after prompts or delays so unlinking, equipment changes, preference changes, or a
replacement session cannot authorize an old action. Both participants must allow
ERP and sex-toy use.

## Deployment configuration

Handheld interactions resolve the names in the device's `interaction_map` through
`GLOB.interaction_instances`. A deployment must supply the corresponding JSON
definitions under `config/nova/interactions/` in the server's working directory.
The repository's example interaction files do not supply that complete set.

Each mapped definition must be lewd, have `usage = "other"`, use a visible category,
and declare the exact genital requirements associated with its two endpoints.
The validator rejects absent or incompatible definitions. JSON filenames do not
form the contract; the loaded interaction names and metadata do. See the
[interaction datum](../../interaction_menu/code/interaction_datum.dm) for loading
and message-template fields.

## Tests

`code/modules/unit_tests/~nova/portal_device.dm`, `portal_lifecycle.dm`, and
`portal_routes.dm` cover equipment authority, rendering invalidation, ownership,
route execution, and message formatting. Shared fixtures live in
`portal_test_helpers.dm`. Default tests install temporary real interaction datums
and use neutral message templates, so the ordinary CI deployment can run them
without production interaction JSON. Each test restores any registry entries it
replaces.

Run the DM suite from the repository root with `tools/build/build.bat dm-test`
on Windows or `tools/build/build.sh dm-test` on Linux. For a focused local run,
temporarily add `TEST_FOCUS(/datum/unit_test/portal_device)` and
`TEST_FOCUS(/datum/unit_test/portal_lifecycle)` after the test includes; remove
those focus declarations when finished.

To check a deployment's complete interaction configuration as well, place its
JSON files in `config/nova/interactions/` and add `-DTEST_PORTAL_LIVE_CONFIG` to
the DM test command. This explicitly enables the optional configuration test,
which checks the mapped definitions and their private message templates. Merely
having an interaction directory does not enable this test.
