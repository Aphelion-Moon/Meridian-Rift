# Parallax modular ballistics

A ballistic weapon assembled from physical, removable parts. Shared overlays
compose world and held sprites without a separate sprite for every configuration.

## Source layout

Production files are included explicitly in the root `tgstation.dme`.

| File in `code/`               | Responsibility                                                                                                 |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `modular_ballistics.dm`       | Frame defaults and sockets, initialization, cleanup, magazine admission, and presets                           |
| `frames.dm`                   | Alternative receiver definitions and their frame-specific modifiers                                            |
| `modules.dm`                  | Part fields, point lookup/compatibility, physical ownership, nested installation/removal, and part examination |
| `barrels.dm`                  | Barrel performance and suppressor mount coordinates                                                            |
| `accessories.dm`              | Controllers, stocks, optics, and suppressors                                                                   |
| `ammunition.dm`               | Projectile, cartridge, six-round volley, and cassette indicators                                               |
| `configuration.dm`            | Derived performance, suppression, scope behavior, firing guards, and aimed spread                              |
| `service.dm`                  | Service latch, installation selection, removal menu, and gun examination                                       |
| `appearance.dm`               | Recursive overlays, loose/assembled appearance, held poses, and facing layers                                  |
| `supplies.dm`                 | Kits, storage limits, and cargo packs                                                                          |
| `modular_ballistics_tests.dm` | Existing tests, gated by `UNIT_TESTS` or `SPACEMAN_DMM`                                                        |

Add barrels in `barrels.dm` and accessory definitions in `accessories.dm`. Change
mount positions on the parent's `attachment_points`. Firing behavior belongs in
`configuration.dm` or `ammunition.dm`; player interactions belong in `service.dm`.
Update `supplies.dm` when adding kit contents.

## Use

Order **Parallax Modular Ballistics Kit** from armory cargo, or spawn
`/obj/item/gun/ballistic/parallax`. Conversion kits include a suppressor.
Spare ammunition cassettes also have a separate cargo order.

1. Hold the gun, remove its cassette, and rack out the chambered cartridge.
2. Open its service latch with a screwdriver.
3. Apply a part and choose a compatible parent if necessary. Alt-click to remove
   a part, including a nested attachment. Removing a parent carries its children.
4. Close the latch, insert a cassette, and chamber a round.

Servicing requires a fully unloaded, held gun outside a burst or firing cooldown.
The barrel and controller are required; stocks and optics are optional. Examine
the weapon and parts for current performance values.

Compact, compact heat-sink, and carbine barrels accept a suppressor. Suppression
uses the existing quiet-shot behavior and makes compact weapons bulky, without
changing damage or cycle time. Marksman and shotgun builds require both hands.
The shotgun fires six pellets and consumes six live cassette rounds per volley.

## Attachment model

The frame's `modules` and each part's `attachments` hold physical children keyed
by socket. Both frames and parts define `attachment_points`. A child's `socket`
selects a point; the point's `type` restricts accepted subtypes. Missing points
mean unsupported. Missing coordinates mean zero offset.

Contexts are `world`, `loose`, `compact_left`, `compact_right`, `rifle_left` and
`rifle_right`. Each context accepts `default` coordinates and held-direction
overrides. Use quoted numeric direction keys in constant declarations:
`"1"` north, `"2"` south, `"4"` east, `"8"` west.

```dm
attachment_points = list(
    "silencer" = list(
        "type" = /obj/item/ballistic_module/silencer,
        "world" = list("default" = list(8, 0)),
        "rifle_left" = list("4" = list(5, 0), "8" = list(-5, 0)),
    ),
)
```

Coordinates translate the authored sprite: positive x is right and positive y is
up. Child offsets accumulate through their parents. They do not automatically
mirror, rotate or detect a muzzle. The standard frame uses zero offsets because
the existing artwork already contains its attachment placement.

Treat point tables as read-only subtype configuration. Install through
`install_module()` or `install_attachment()` to maintain ownership signals and
configuration updates. Player service additionally enforces the latch restrictions.

`rebuild_configuration()` derives values from the current tree rather than
stacking previous bonuses. Nested parts contribute additive dispersion, recoil,
cycle cost, aimed accuracy and handling. Primary barrel/controller/optic roles
remain on the frame. Suppression comes from the primary barrel's silencer.
Magazines retain ballistic loading/chambering behavior while using their named
point for compatibility and visual placement.

## Sprite contract

| Asset                                                       | Canvas and purpose                   |
| ----------------------------------------------------------- | ------------------------------------ |
| `icons/modular_ballistics.dmi`                              | 48×32 frame and installed overlays   |
| `icons/parts.dmi`                                           | 32×32 loose parts and cassette       |
| `icons/lefthand.dmi`, `icons/righthand.dmi`                 | 64×64 rifle poses, four directions   |
| `icons/compact_lefthand.dmi`, `icons/compact_righthand.dmi` | 64×64 compact poses, four directions |
| `icons/ammunition.dmi`                                      | Cartridge and projectile artwork     |

New visual parts need matching states in the world and four held atlases, plus
loose artwork. Preserve unrelated pixels and DMI metadata. Use at most 16 visible
colors per finished sprite across directions and animation frames.

Cassette indicators show full, partial and empty ammunition. Held overlays refresh
on turns and assembly changes; north-facing guns render behind the wearer.
Completely stripped frames use the larger loose receiver artwork.

The DMI files are authoritative. Historical generation scripts and previews in
ignored `.parallax-work/` may predate manual edits; do not regenerate blindly.

## Validation and provenance

Existing tests cover component lifecycle, configuration combinations, service
restrictions, held profiles and north-facing layering. Compilation is separate
from runtime tests and does not establish in-game alignment or multiplayer balance.

Original artwork was generated and refined at native resolution using Mass Effect
silhouettes and local SS13 sprites as references. No Mass Effect or gallery pixels
were copied. Generation sources, prompts and previews are retained in ignored
`.parallax-work/` where available.
