## Bouncy Objects

Module ID: BOUNCY_OBJECTS

### Description:

Adds `/datum/element/bouncy`, a configurable bounce for thrown objects. After a throw hits a wall,
structure or mob, the object rebounds off it. After it lands on a hard floor, it can hop onward. Each
rebound keeps only part of the incoming distance, so the object settles after a few bounces. Rebounds of
a tile or more are thrown with a small hop arc; shorter ones become a decelerating slide within the
object's own tile, so a bounce never stops dead or twitches in place. Ejected
ammo casings also hop a tile away from ballistic guns, and a slimeperson's core pops away bouncing
when their body melts on death.

The player's own throw is unchanged, including its damage and catching. Rebounds that strike an
obstacle skip hitby(), so they deal no damage, push nothing and cannot be caught. Rebound landings on
the floor still reach the turf, so lava still ignites items. Soft or non-solid turfs (those without a
`bullet_bounce_sound`) absorb floor hops. There are no rebounds without gravity.

Element arguments, all optional:

- `restitution` - fraction (0 to 1) of the incoming distance each rebound keeps
- `max_bounces` - most rebounds one throw or ejection can chain into
- `floor_bounces` - whether hard floors hop the object onward
- `deflect_chance` - percent chance for a rebound to veer 45 degrees
- `bounce_sound`, `bounce_sound_volume` - extra sound at each rebound
- `eject_hop_range` - tiles the object travels in a random direction when ejected; listens to
  `COMSIG_CASING_EJECTED` and `COMSIG_MOVABLE_BOUNCY_EJECTED`

Profiles, in `code/bouncy_objects.dm`:

| Object | Restitution | Max bounces | Floor hops | Deflect | Notes |
| --- | --- | --- | --- | --- | --- |
| Tennis balls (`/obj/item/toy/tennis`) | 0.7 | 4 | Yes | 0% | Basketball bounce sound |
| Slimeperson cores (`/obj/item/organ/brain/slime`) | 0.85 | 6 | Yes | 15% | Boing sound; 4-tile pop on death |
| Slime extracts (`/obj/item/slime_extract`) | 0.35 | 1 | Yes | 25% | Splat sound |
| Ammo casings and live rounds (`/obj/item/ammo_casing`) | 0.5 | 2 | Yes | 50% | 1-tile ejection hop |
| Iron rods (`/obj/item/stack/rods`) | 0.3 | 2 | Yes | 50% | Existing metal landing sound |

Fired projectiles are not affected; they keep TG's ricochet system.

### TG Proc/File Changes:

- `code/game/objects/items.dm`: `/obj/item/throw_at()` - forwards its `throw_type_path` argument to the
  parent as `throw_datum_typepath`. It previously dropped it, so every item throw used the base
  `/datum/thrownthing` whatever the caller asked for. No existing item caller passes a custom type.
  Upstream candidate.
- `modular_nova/modules/customization/modules/mob/living/carbon/human/species/roundstartslime.dm`:
  `/obj/item/organ/brain/slime/proc/core_ejection()` - sends `COMSIG_MOVABLE_BOUNCY_EJECTED` so the core
  pops away when the body melts. A modular override cannot do this: `modular_aphelion` is included first,
  and Nova's definition does not call its parent.

### Modular Overrides:

- `code/bouncy_objects.dm`: `Initialize()` of `/obj/item/toy/tennis` (Nova-owned),
  `/obj/item/organ/brain/slime` (Nova-owned), `/obj/item/slime_extract`, `/obj/item/ammo_casing` and
  `/obj/item/stack/rods` - call the parent and attach `/datum/element/bouncy`

### Defines:

- `code/__DEFINES/~aphelion_defines/bouncy_objects.dm`: `COMSIG_MOVABLE_BOUNCY_EJECTED`
- File-local `BOUNCE_REBOUND_DELAY`, `BOUNCE_MINIMUM_DISTANCE`, `BOUNCE_SLIDE_PIXEL_LIMIT` and
  `BOUNCE_MAX_HOP_HEIGHT` in `code/bouncy_element.dm`

### Included files that are not contained in this module:

- N/A

### Credits:

- Moonridden
