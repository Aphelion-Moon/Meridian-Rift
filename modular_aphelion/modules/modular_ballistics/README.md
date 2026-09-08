# Parallax modular ballistics

A magnetic accelerator assembled from physical, removable parts. Shared overlays
compose world and held sprites without a separate sprite for every configuration.

## Source layout

Production files are included explicitly in the root `tgstation.dme`.

| File in `code/`         | Responsibility                                                                                                 |
| ----------------------- | -------------------------------------------------------------------------------------------------------------- |
| `modular_ballistics.dm` | Frame defaults and sockets, initialization, cleanup, heatsink admission, and presets                           |
| `frames.dm`             | Alternative receiver definitions and their frame-specific modifiers                                            |
| `modules.dm`            | Part fields, point lookup/compatibility, physical ownership, nested installation/removal, and part examination |
| `barrels.dm`            | Barrel performance and suppressor mount coordinates                                                            |
| `accessories.dm`        | Controllers, stocks, optics, and suppressors                                                                   |
| `ammunition.dm`         | Metal shavings, heatsinks, cooling, automatic burnout and firing adapters                                      |
| `configuration.dm`      | Derived performance, suppression, scope behavior, firing guards, and aimed spread                              |
| `service.dm`            | Service latch, installation selection, removal menu, and gun examination                                       |
| `appearance.dm`         | Recursive overlays, loose/assembled appearance, held poses, and facing layers                                  |
| `supplies.dm`           | Kits, storage limits, and cargo packs                                                                          |

Add barrels in `barrels.dm` and accessory definitions in `accessories.dm`. Change
mount positions on the parent's `attachment_points`. Firing behavior belongs in
`configuration.dm` or `ammunition.dm`; player interactions belong in `service.dm`.
Update `supplies.dm` when adding kit contents.

### Changes outside the module

`tgstation.dme` includes the ten production files listed above. The shared Nova
gun HUD also has changes required by this module:

- `modular_nova/modules/gunhud/code/gun_hud_component.dm` adds the ballistic
  `update_custom_ammo_hud(hud)` hook. Returning `TRUE` skips the normal ammunition
  counter; the default returns `FALSE`. Energy and microfusion HUD updates clear
  managed overlays so switching weapons does not leave a stale heat indicator.
- `modular_nova/modules/gunhud/code/gun_hud.dm` adds an optional `custom_overlay`
  to `set_hud()`. It replaces the standard digit overlays when present and is
  cleared when the HUD turns off or is reset.

Preserve these hooks and resets when merging upstream gun HUD changes.

## Use

Order **Parallax Modular Ballistics Kit** from armory cargo, or spawn
`/obj/item/gun/ballistic/parallax`. Conversion kits include a suppressor.
Spare reusable heatsinks also have a separate cargo order.

1. Hold the gun and remove its heatsink by activating it in hand.
2. Open its service latch with a screwdriver.
3. Apply a part and choose a compatible parent if necessary. Alt-click to remove
   a part, including a nested attachment. Removing a parent carries its children.
4. Close the latch and insert a heatsink; no chambering is needed.

Servicing requires a fully unloaded, held gun outside a burst or firing cooldown.
The barrel and controller are required; stocks and optics are optional. Examine
the weapon and parts for current performance values.

Compact, compact heat-sink, and carbine barrels accept a suppressor. Suppression
uses the existing quiet-shot behavior and makes compact weapons bulky, without
changing damage or cycle time, but multiplies heat by 1.25. Assault, marksman and
shotgun barrels have no suppressor mount. Marksman and shotgun builds require
both hands. The shotgun fires six metal shavings with a fixed 20-degree pellet
spread that remains even when scoped.

## Receivers and performance

The standard receiver supports compact sidearms and all optional parts. Heavy
and bullpup receivers always require both hands and use the bulky rifle profile.
Their modifiers apply to every compatible assembly:

| Receiver | Dispersion | Recoil multiplier | Added shot cycle | Heat multiplier | Stock socket |
| -------- | ---------- | ----------------- | ---------------- | --------------- | ------------ |
| Standard | 0 | 1 | 0 s | 1 | Yes |
| Heavy | -2 | 0.55 | +0.1 s | 0.8 | Yes |
| Bullpup | -1 | 0.85 | -0.1 s | 1.25 | No; integrated stock |

Spawn `/obj/item/gun/ballistic/parallax/heavy` for an assault/automatic build or
`/obj/item/gun/ballistic/parallax/bullpup` for a carbine/automatic build. Both have
`/empty` variants. Standard-frame presets are `/machine_pistol`, `/carbine`,
`/assault`, `/shotgun` and `/marksman`, alongside the base sidearm and `/empty`.
Cargo supplies standard sidearms and conversion parts, not alternative receivers.

Barrel values below precede frame, controller and accessory modifiers. Damage
multiplies the projectile's base 20 damage; heat multiplies 5 heat per projectile.

| Accelerator | Shot cycle | Damage multiplier | Heat multiplier | Dispersion | Recoil |
| ----------- | ---------- | ----------------- | --------------- | ---------- | ------ |
| Compact | 0.5 s | 1 | 1 | 6 | 0.5 |
| Compact heat-sink | 0.3 s | 0.4 | 0.6 | 8 | 0.7 |
| Carbine | 0.3 s | 0.6 | 0.8 | 5 | 0.9 |
| Assault | 0.6 s | 1.2 | 1.6 | 6 | 1.2 |
| Marksman | 1.6 s | 2.25 | 6 | 4 | 2 |
| Shotgun (six projectiles) | 1.8 s | 0.4 per projectile | 0.8 | 4 | 1.6 |

The marksman's configured projectile velocity multiplier is 1.5; other barrels
use 1. Projectiles are weak against armour, have a -10 wound bonus and a 0.1
demolition multiplier.

Semi-automatic controllers multiply heat by 0.8. Burst controllers fire three
shots, reduce dispersion by 1 and add 0.3 seconds of recovery after the burst.
Automatic controllers add 2 dispersion and sustain fire while held. Burst and
automatic controllers use a heat multiplier of 1.

Compact stocks reduce dispersion by 2 and recoil by 0.3. Precision stocks reduce
hip dispersion by 1, scoped dispersion by a further 3 and recoil by 0.6, adding
0.1 seconds per shot. Both make the weapon bulky. Reflex optics reduce dispersion
by 1; precision optics add 2 hip dispersion and 0.1 seconds per shot, but enable
right-click scoping with 4 scoped accuracy and a scope range modifier of 2.
Scoped bonuses apply only while using this gun's own scope.

Shot cycles include frame and part costs, with a minimum of 0.15 seconds.
Burst trigger cycles use three shot cycles plus burst recovery. Dispersion is
clamped to zero; summed recoil is multiplied by the frame modifier with a 0.1 floor.

## Heat and burnout

The gun slices rice-sized pieces from an effectively inexhaustible metal block
and accelerates them magnetically. There are no ammunition refills or ejected
cartridges. The old magazine type path and socket remain for compatibility.

Heatsinks hold 100 heat and dissipate 1 heat per second, both installed and loose
(100 seconds to cool from full). Heat per successful shot or volley is
`5 * projectile count * frame heat multiplier * all installed part heat multipliers`,
including nested attachments. For example, a standard compact semi-auto produces
4 heat per shot, while the standard shotgun with a semi-auto controller produces
19.2 heat per six-projectile volley, before passive cooling.
The shot that reaches or crosses capacity permanently ruins the sink without
burning the shooter. Starting with the next shot, firing inflicts 5 burn damage
only on the arm holding the receiver, including when the other hand supports it,
even after cooling. Firing remains enabled; there is no safety toggle.
Let an intact sink cool before it reaches capacity to reuse it indefinitely.
Replace a ruined sink to stop the burns. A missing sink still prevents firing.
Examine the gun or sink for heat and condition. The HUD replaces ammunition digits
with a flame warning that fills from bottom to top in 20 steps (`coil_0` through
`coil_20`). A missing sink uses `coil_missing`; a ruined sink stays at `coil_20`
even after cooling. All heat/damage defaults are configurable.

Shot pitch rises with heat from 1x to 1.25x, including suppressed shots. Burnout
plays `sound/overheat.ogg` once and permanently retains the high warning pitch
for that sink. The barrel determines the firing report and volume independently
of stocks and optics.

Four finned heatsink states are shared by loose, world and held artwork:
`heatsink_cool` below one-third capacity, `heatsink_warm` from one-third,
`heatsink_hot` from two-thirds, and `heatsink_ruined` after burnout. Ruined sinks
remain scorched with a flickering glowing fracture even after their heat falls.

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
cycle cost, aimed accuracy and handling, plus multiplicative heat modifiers.
Primary barrel/controller/optic roles
remain on the frame. Suppression comes from the primary barrel's silencer.
Heatsinks use the magazine point for compatibility and visual placement.
The gun creates internal firing adapters without storing physical ammunition.

## Sprite contract

| Asset                                                       | Canvas and purpose                   |
| ----------------------------------------------------------- | ------------------------------------ |
| `icons/modular_ballistics.dmi`                              | 48×32 frame and installed overlays   |
| `icons/parts.dmi`                                           | 32×32 loose parts and heatsink       |
| `icons/lefthand.dmi`, `icons/righthand.dmi`                 | 64×64 rifle poses, four directions   |
| `icons/compact_lefthand.dmi`, `icons/compact_righthand.dmi` | 64×64 compact poses, four directions |
| `icons/ammunition.dmi`                                      | Cartridge and projectile artwork     |
| `icons/heat_hud.dmi`                                        | Custom heat warning HUD states       |

New visual parts use their `icon_state` in the world, loose and four held atlases.
Preserve unrelated pixels and DMI metadata. Use at most 16 visible
colors per finished sprite across directions and animation frames.

Heatsink indicators show cool, warm, hot and ruined states. Held overlays refresh
on turns and assembly changes; north-facing guns render behind the wearer.
Completely stripped frames use the larger loose receiver artwork.

The DMI files are authoritative. Historical generation scripts and previews in
ignored `.parallax-work/` may predate manual edits; do not regenerate blindly.

## Validation and provenance

This branch does not contain `code/modules/unit_tests/parallax.dm`. Runtime
validation should cover component removal, receiver and part modifiers, the
burnout boundary, cooldown, holding-arm damage, sink replacement, missing sinks,
cartridge-free firing adapters and HUD resets when switching weapon types.
Check heat-dependent pitch and the one-time burnout sound as well. Compilation
is separate from runtime tests and does not establish in-game alignment or
multiplayer balance.

Original artwork was generated and refined at native resolution using Mass Effect
silhouettes and local SS13 sprites as references. No Mass Effect or gallery pixels
were copied. Generation sources, prompts and previews are retained in ignored
`.parallax-work/` where available.

The finned heatsink redesign uses built-in image generation followed by native
pixel cleanup. All four states, animation frames and atlas contexts share 15
visible colors. Source artwork, prompt, backups, previews and validation are in
`.parallax-work/heatsinks/`; unrelated atlas cells retain their original pixels.
