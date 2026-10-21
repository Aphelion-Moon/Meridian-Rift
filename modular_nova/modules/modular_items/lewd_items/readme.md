# Portal items and structures

The handheld [device](code/lewd_items/portal_fleshlight.dm) and
[receiver](code/lewd_items/portal_panties.dm) connect two equipped endpoints. The
[portal bore](code/lewd_machinery/lewd_portals.dm) creates a pair of wall portals
and a body relay for their occupant. Both use the generic
[interaction route API](../../interaction_menu/readme.md).

## Controls

- Link the handheld device and receiver by using either item on the other.
- Put the receiver in a genital slot or the mouth slot through the interaction
  panel. It doesn't show on examine, and a mask can be worn over it.
- Activate the handheld device in hand to cycle the target used when selecting
  the groin. Other selected body zones choose their corresponding endpoint.
- Use the handheld device on yourself or someone else to put the part you aim at
  against it, the groin using the device's target. Ctrl-Shift-click it from up to
  a tile away to open the interaction panel of the receiver's wearer instead,
  listing everything your own parts can do through the portal. The wearer can do
  the same to reach their own receiver.
- Use one linked device on another to pick from the interactions between their
  two wearers. The device in your hand is the active side.
- Right-click the device or receiver to toggle that item's anonymity. Alt-click
  either linked item to unlink it.
- Use the bore on two supported walls to create its portal pair. Activate an
  empty bore to change modes; activate it after placement to collapse its portals.
- Right-click an unoccupied wall portal to change both endpoints' mode. Buckle
  into one endpoint to create the relay at its peer, then unbuckle to leave.
  A gloryhole relays the penis and balls, and a wallstuck portal everything below
  the waist. Interactions with the relayed half only work next to the relay, and
  the rest of the occupant only in person.

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

A worn receiver is always open: it sits on its part underneath any clothing, so
clothing, masks and sheaths never close it. The device end follows face to face
exposure rules through `portal_target_is_accessible()` in
[the human helpers](code/lewd_helpers/human.dm). Slot and link checks stay with
the items that own those relationships. Physical access and visible sprite state
are distinct: rendering checks native appearances separately and copies them
before filtering. The occupant's preferences are never changed: a gloryhole
occupant's penis overlay refuses to draw for the session, and a wallstuck occupant
has body layers stripped as they are applied. Both keep a rebuild between queued
refreshes from showing the hidden body for a tick.

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

Each part pairing lists one or more names, default first. A mapped definition must
be lewd, have `usage = "other"`, use a visible category, and may only require the
genitals at its own two endpoints.
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

# Adult items

A new item family gets its own file and icons here; an addition to an existing
family goes in that family's file. The lewd items config removes every item
([`_erp_disabled_item_enforcement.dm`](code/lewd_items/_erp_disabled_item_enforcement.dm)),
and the `adult_items_kill_switch` unit test checks the top types each family
lists in `adult_items_gated_types()` ([`_gated_types.dm`](code/lewd_items/_gated_types.dm)).
A new family adds its line there.

- **Medipens** ([medipens.dm](code/lewd_chemistry/items/medipens.dm)). Five
  single-use 30u medipens: crocin, hexacrocin, succubus milk, incubus draft, and
  the La Coom Bomb (10u each of the last three), plus a box with one of each.
  LustWish sells them (the hexacrocin pen, the La Coom Bomb and the box once
  hacked), and they're in the Erotic loadout.
- **Condom box** ([condom_box.dm](code/lewd_items/condom_box.dm)). Ten condom
  packs, and it only holds condom packs. LustWish and the Erotic loadout.
- **Bluespace fleshlight** ([fleshlight.dm](code/lewd_items/fleshlight.dm)).
  Catches an immovable rod, which flings the user up to 12 tiles along its path
  to a soft landing. A wizard in rod form is set down unharmed. A premium
  LustWish item at ten command paychecks.
- **Leash** ([leash.dm](code/lewd_items/leash.dm)). The leashed follows the
  holder's route a step at a time: round corners and hazards, through doors, up
  and down stairs. Where they can't follow, the leash goes taut and holds the
  holder at two tiles. A leashed who falls drags their holder to the hole after
  a moment to let go. A dropped leash stays hooked and trails the leashed, and
  anyone their sex toy preference allows can pick it up. It unhooks when the
  holder uses it on the leashed, when the leashed breaks free, or with the
  safeword. A line in the strap's colour runs from the holding hand, or from the
  leash on the floor, while the two are in reach.
- **Pointe boots** ([lewd_shoes.dm](code/lewd_clothing/lewd_shoes.dm)). Ballet
  heels with the feet held en pointe, GAGS, with digitigrade sprites. LustWish,
  the shoes loadout and the Grimoire Libidine NIFSoft.
- **Latex half-catsuit** ([latex_halfcatsuit.dm](code/lewd_clothing/latex_halfcatsuit.dm)).
  The latex catsuit without the legs. It picks its male or female sprite by body
  type, previews included, and has digitigrade, Vox, Vox Primalis and Teshari
  sprites. Unlike the catsuit, it doesn't bulge or hide the wearer's parts or
  taur body. LustWish, the under loadout and the Grimoire Libidine NIFSoft.
- **Paw mood and cat paws** ([lewd_gloves.dm](code/lewd_clothing/lewd_gloves.dm)).
  Paw mittens give the paw mood while worn. The cat paws are bigger GAGS paw
  mittens with toe beans and a cuff tag. Both need the sex toy preference.
  LustWish and the Erotic loadout.
- **R.U.T.T.** ([rutt.dm](code/lewd_chemistry/reagents/rutt.dm)). A much
  stronger aphrodisiac than hexacrocin that can cause climaxes, behind the
  aphrodisiac preference. Mixes from crocin, dopamine, femcum and epinephrine at
  322K. Dopamine, which only came from climaxing, now mixes from diethylamine,
  ephedrine, hydrogen and phenol at 373K. The bottle, pill and Rut-Kit neuroware
  are in a hacked LustWish; the bottle and pill are also in the Erotic loadout.
- **Denbu tincture** ([butt_enlarger.dm](code/lewd_chemistry/reagents/butt_enlarger.dm)).
  Grows the butt up to the largest pickable size, behind the butt enlargement
  preference, and grows one on players who allow new genital growth. Clothes
  strain and hurt over the last two sizes. A camphor overdose moves the butt back
  to its preference size. Mixes from saline-glucose, sugar, silicon and crocin.
  LustWish and the Erotic loadout.
- **Bridle** ([bridle.dm](code/lewd_clothing/bridle.dm)). A three-colour GAGS
  bridle. Lowered blinders darken sight like a welding mask, and a set bit
  muffles speech, emotes and spoken spells. Toggled with action buttons or
  alt-click, or from the strip menu by someone with ERP on, if the wearer has the
  sex toy preference on; that warns the wearer and is logged. Securing the straps
  locks it. LustWish and the Erotic loadout.
- **Lustwish MOD suit** ([lustwish_mod.dm](code/lewd_clothing/lustwish_mod.dm)).
  The standard MOD suit in LustWish's skin, with a purple hardlight. The hypnotic
  visor module hypnotizes the wearer like the hypnotic goggles, while on, or
  always once its wire is cut. The remote control module comes with a remote
  that controls the suit from up to seven tiles away: activation, parts, modules,
  lock and forced emotes. The visor needs the wearer's sex toy preference; the
  remote needs that and the holder's ERP preference. Sold in LustWish's MOD Suit
  category.
  - Known issue: a forced emote starting with "says", "exclaims", "yells" or
    "asks" shows the wearer "Invalid emote." and tells the holder nothing,
    because the custom emote's own check (`emote_is_valid()`) judges the wearer.

## Files outside this module

- `icons/map_icons/clothing/shoes.dmi`, `_clothing.dmi` and `mask.dmi`: map
  icons for the pointe boots, cat paws and bridle.
- `tgui/packages/tgui/interfaces/StripMenu.tsx`: the "Adjust bridle" button.
- `tgui/packages/tgui/interfaces/MODsuitRemote.tsx`: the MOD remote's window.
- `modular_nova/master_files/code/modules/client/preferences/erp_preferences.dm`
  and `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/game_preferences/nova/erp_preferences.tsx`:
  the butt enlargement preference and its toggle.
- `modular_nova/modules/GAGS/nsfw/gloves.dm`, `masks.dm` and `shoes.dm`, with
  their JSON configs: the cat paws', bridle's and pointe boots' GAGS configs.
- `modular_nova/modules/loadouts/loadout_items/loadout_datum_erp.dm`,
  `loadout_datum_shoes.dm` and `under/loadout_datum_under.dm`: loadout entries.
- `modular_nova/modules/modular_implants/code/nifsofts/dorms.dm`: the pointe
  boots and half-catsuit in the Grimoire Libidine NIFSoft.
- `code/modules/unit_tests/~nova/adult_items_kill_switch.dm`: the lewd items
  config test for every family.
