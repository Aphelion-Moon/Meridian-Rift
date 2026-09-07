# Parallax modular ballistics

An MCR-inspired ballistic platform with original Mass Effect-inspired ceramic
shells, dark structural parts, red insets and cyan indicators. Every configuration
is assembled from the same physical component objects and overlay states.

## Use

Order **Parallax Modular Ballistics Kit** from the armory cargo category, or spawn
`/obj/item/gun/ballistic/parallax`. The kit contains two sidearms, two complete
conversion kits, spare 24-round 6mm cassettes and a screwdriver. Ammo is also
available as a separate armory order.

1. Hold the weapon, remove its ammunition cassette and rack out the chambered round.
2. Use a screwdriver on it to open the service latch. Firing is disabled while open.
3. Alt-click to select and remove a component. Apply another component to its empty
   socket. Removed parts remain ordinary items and can be reused on another frame.
4. Close the latch with the screwdriver, insert a cassette and rack the weapon.

The barrel and controller are required. Stocks and optics are optional. Any barrel
works with any controller, stock and optic: **135 complete combinations**.
An occupied socket rejects another component; remove its current component first.

| Socket | Choices | Effect |
| --- | --- | --- |
| Barrel | Compact, compact heat-sink, carbine, assault, marksman | Cycle time, damage, dispersion, recoil and handling size |
| Controller | Semi, three-round burst, automatic | Trigger behavior; automatic mode fires while held |
| Stock | None, compact, precision | Lower recoil and dispersion; adds bulk; precision adds 0.1 seconds per shot |
| Optic | None, reflex, precision | Reflex improves all shots; precision enables right-click aiming with a hip-fire and cycle penalty |

Carbines cannot be fired akimbo. Marksman barrels require both hands. All builds
use the same ammunition, with barrel performance trading rate of fire for damage.
Automatic and burst controllers respect the barrel's cycle time plus installed
part cycle costs. The compact heat-sink accelerator trades a 0.35-second cycle
(instead of 0.3) for tighter grouping. The assault accelerator trades speed for
reduced recoil compared with the carbine.

Right-click with a complete precision-optic build to toggle the game's normal
scope view (range modifier 2). The optic adds 1 dispersion and 0.1 seconds per
shot, then subtracts 4 dispersion while aiming through that weapon's own scope.
The reflex optic instead subtracts 1 dispersion at all times with no cycle cost.
Precision stocks improve stability more than compact stocks but add 0.1 seconds
per shot. These costs also apply between burst rounds.

Examine a weapon for its fire mode, shot and trigger cycles, damage multiplier,
hip/scoped dispersion, recoil, handling, missing required parts and installed
modules. Examine a loose part for its modifiers. Opening the service latch,
removing the optic, or losing a required part removes the scope controls.

Presets are examples of installed parts, not separate mechanics or combined icons:
`parallax`, `parallax/machine_pistol`, `parallax/carbine`, `parallax/assault`,
`parallax/marksman`. `parallax/empty` is an unloaded bare frame.

## Sprite contract

- `icons/modular_ballistics.dmi`: 48×32 shared frame and installed part overlays.
- `icons/parts.dmi`: 32×32 centered loose component and cassette sprites.
- `icons/lefthand.dmi`, `icons/righthand.dmi`: 64×64, four directions per state.
  Rifle artwork uses approximately 66% of the ground-weapon scale, anchored at
  the grip. Canvas size is padding for placement, not the weapon's visible size.
- `icons/compact_lefthand.dmi`, `icons/compact_righthand.dmi`: the same per-part
  states in a small angled handgun pose with a separately refined grip, based on
  the standard `gun` pistol carry. Any stock or long barrel switches the complete
  assembly to the shallow-angle rifle pose.
- States: `frame`, `barrel_short`, `barrel_smg`, `barrel_carbine`, `barrel_assault`,
  `barrel_marksman`, `stock_compact`, `stock_precision`, `optic_reflex`,
  `optic_scope`, `control_semi`, `control_burst`, `control_auto`, `magazine`.

World and held appearances layer installed components dynamically. No complete
combination is baked into an icon state. New parts need a matching state in the
world and both pairs of held overlay atlases, plus a centered loose-item state.

Loose components have their own larger, detailed artwork rather than tiny copies
of installed overlays; the ammunition cassette occupies 18×22 pixels and the loose
receiver 26×22. The earlier detailed loose receiver artwork is restored.
Completely stripped frames use the loose receiver sprite. Held
weapons switch to `BODY_BEHIND_LAYER` when the wearer faces north and restore the
normal hand layer when turning away. The listener is cleared on drop/destruction.
Rifle carry placement follows the MMR-2543E (`infanterie`) in Carwo's inhand
atlases, with preserved grip depth below a slim receiver. Both held profiles
use horizontal east/west poses and opposite south/north tilts, rotating around
the same hand contact points.
`tools/rebuild_pose_sprites.py` regenerates the held overlays with explicit grip
contact anchors for each hand/direction, and preserves independent loose artwork.

## Artwork provenance

Original artwork generated with the built-in image tool, then extracted and
cleaned at native resolution: fixed color palette, structural joins, simplified
receiver and cassette, optical mounts, and hand-specific directional alignment.
No Mass Effect or gallery pixels were copied into the delivered weapon sprites.

Visual references inspected:

- MCR-01 and its separate attachments, in `modular_nova/modules/microfusion/icons`.
- Szot Dynamica Borb, Slonce, Gwiazda and Zashch in the local modular weapons atlas.
- DopplerShift gallery energy sprites, snapshot
  `81d8936562e0db994fa667c75dba4d667aed1312`.
- [Mass Effect weapon cards](https://me3tweaks.com/store_catalog/cards/weapons):
  Predator, Avenger, Mantis and Raptor silhouettes.

Selected generation source, exact generation prompt and working previews are
retained in ignored `.parallax-work/`. Run `tools/preview_sprites.py` with Python
and Pillow to regenerate the previews directly from the DMI files. The committed
DMI files are the authoritative game assets. The character preview uses the game's
`icons/mob/human/human.dmi`, `human_basic` state as a scale reference only.

## Verification

The focused tests cover component movement/deletion, removal of automatic fire,
queued burst rejection, non-stacking stats, all 135 configurations, matching
overlay states, the loaded/chambered service interlock, and north-facing layering
including turning and pickup/drop transitions. Test definitions live
in `code/modular_ballistics_tests.dm` and participate in UNIT_TESTS builds.
The pose-profile test verifies stock/barrel changes switch between compact and
rifle artwork, and that stripping a frame restores its large loose-item sprite.

Balance values are initial tuning and still need multiplayer playtesting.

Independent sprite review: **5/10 → 7/10 → 8/10**, after two refinement passes.
The final reviewer rated native readability, sci-fi identity, modular joins,
pixel quality and held silhouettes at 8/10 each. Static previews show no missing
parts, floating attachments or gross grip-placement failures. Live-client
movement and layering have not been visually verified.

Follow-up artwork review after the in-hand size, loose-part detail and north-facing
occlusion fixes: **8/10**. The loose SMG/assault housings were refined to match the
other detailed components. Direction transitions are covered by the runtime test;
the character-scale artwork preview models north-facing body occlusion.

![Runtime overlay compositions](preview.png)

![Larger loose components](parts_preview.png)

![Handgun and rifle held poses](inhand_preview.png)
