## Bouncy Objects

Module ID: BOUNCY_OBJECTS

### Description:

Adds `/datum/element/bouncy`, a configurable bounce for thrown objects. After a throw hits a wall,
structure or mob, the object rebounds off it. After it lands on a hard floor, it can hop onward. Each
rebound keeps only part of the incoming distance, so the object settles after a few bounces. Rebounds of
a tile or more are thrown with a small hop arc; shorter ones become a decelerating slide within the
object's own tile, so a bounce never stops dead or twitches in place. Casings ejected from a ballistic
gun's chamber also hop a tile away (bulk unloads, such as dumping a revolver, do not). A throw with no
thrower aimed at the object's own tile is a toss: it lands at once and the object pops away in a random
direction as far as the throw's range. A slimeperson's core is tossed this way when their body melts on death.

The player's own throw is unchanged, including its damage and catching. Rebounds never strike the
obstacles they run into (`/datum/thrownthing/bounce/finalize()` skips the impact), so they deal no damage,
push nothing, cannot be caught and set off no hit reactions or hit sounds. Rebound landings on the floor
still reach the turf. Lava and soft or non-solid turfs (those without a `bullet_bounce_sound`) absorb floor
hops. There are no rebounds, ejection hops or toss pops without gravity.

Mass throws are kept cheap by two limits. At most `BOUNCE_MAX_PER_TICK` (8) bounces start per server tick,
shared by every bouncy object, so an explosion scattering a pile of casings and rods, or several guns on full
auto, cannot flood the throwing subsystem, timers, clients or sound; objects past the budget settle where
they are. No single bounce travels further than `BOUNCE_MAX_DISTANCE` (8) tiles, which mostly trims
throws from mass drivers, explosions and the like.

Element arguments, all optional:

- `restitution` - fraction (0 to 1) of the incoming distance each rebound keeps
- `max_bounces` - most rebounds one throw or ejection can chain into
- `deflect_chance` - percent chance for a rebound to veer 45 degrees
- `bounce_sound`, `bounce_sound_volume` - extra sound at each rebound
- `eject_hop_range` - tiles the object travels in a random direction when ejected from a ballistic gun
  as a casing; listens to `COMSIG_CASING_EJECTED`

Profiles, in `code/bouncy_objects.dm`:

| Object | Restitution | Max bounces | Deflect | Notes |
| --- | --- | --- | --- | --- |
| Tennis balls (`/obj/item/toy/tennis`) | 0.7 | 4 | 0% | Basketball bounce sound |
| Slimeperson cores (`/obj/item/organ/brain/slime`) | 0.85 | 6 | 15% | Boing sound; tossed for a 4-tile pop on death |
| Slime extracts (`/obj/item/slime_extract`) | 0.35 | 1 | 25% | Splat sound |
| Ammo casings and live rounds (`/obj/item/ammo_casing`) | 0.5 | 2 | 50% | 1-tile ejection hop, landing silently, as the gun already plays the clatter |
| Iron rods (`/obj/item/stack/rods`) | 0.3 | 2 | 50% | Existing metal landing sound |

Fired projectiles are not affected; they keep TG's ricochet system.

### TG Proc/File Changes:

- `code/game/objects/items.dm`: `/obj/item/throw_at()` - forwards its `throw_type_path` argument to the
  parent as `throw_datum_typepath`. It previously dropped it, so every item throw used the base
  `/datum/thrownthing` whatever the caller asked for. No existing item caller passes a custom type.
  Upstream candidate.
- `modular_nova/modules/customization/modules/mob/living/carbon/human/species/roundstartslime.dm`:
  `/obj/item/organ/brain/slime/proc/core_ejection()` - tosses the core in place (a range 4 throw at its own
  tile) when the body melts, if it has gravity, so it pops away. A modular override cannot do this:
  `modular_aphelion` is included first, and Nova's definition does not call its parent.

### Modular Overrides:

- `code/bouncy_objects.dm`: `Initialize()` of `/obj/item/toy/tennis` (Nova-owned),
  `/obj/item/organ/brain/slime` (Nova-owned), `/obj/item/slime_extract`, `/obj/item/ammo_casing` and
  `/obj/item/stack/rods` - call the parent and attach `/datum/element/bouncy`

### Defines:

- File-local `BOUNCE_REBOUND_DELAY`, `BOUNCE_MINIMUM_DISTANCE`, `BOUNCE_SLIDE_PIXEL_LIMIT`,
  `BOUNCE_MAX_HOP_HEIGHT`, `BOUNCE_MAX_PER_TICK` and `BOUNCE_MAX_DISTANCE` in `code/bouncy_element.dm`

### Included files that are not contained in this module:

- N/A

### Credits:

- Moonridden
