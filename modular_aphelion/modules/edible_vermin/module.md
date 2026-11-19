## Edible vermin

Module ID: EDIBLE_VERMIN

### Description:

A cockroach that dies whole leaves a dead roach you can eat, as a mouse leaves a dead mouse. The body of a dead frog
becomes food when you pick it up. Live vermin cannot be eaten.

- A cockroach that dies whole leaves a dead roach on its back where it died, or in the hand or pocket that held it,
  and no guts. Squashing, gibbing or a microwave leaves the usual guts and no body. A bloodroach bursts, so it leaves
  its blood and guts and no body. Pest spray leaves the roach's own body instead. A dead roach is one bite of bugs. It
  rots away on the floor like other food, and cleanbots clean it up. Random food, gifts and mystery boxes never roll
  one (`spawn_blacklisted`).
- A frog keeps its body when it dies. When you pick the body up, it becomes a dead frog. A dead frog is a food item of
  raw meat that you eat in one bite. It is only food. You cannot revive it, butcher it or put it in the DNA infuser.
  You can still do these things to a body that stays on the floor.
  - A dead rare frog also gives a strong trip. A dead crazy frog, which is the frog that a regal rat makes of a rare
    frog, gives the same trip. Both frogs have mushroom hallucinogen in their bite.
  - The trip comes from 10 units of mushroom hallucinogen and 25 units of mindbreaker toxin. A sunshine pill holds 15
    units of each. Food reagents are half pure, so mushroom hallucinogen overdoses at 15 units, not 30. That is why
    the dead frog holds only 10 units of it.
  - A pet keeps its body, and you hold it as usual. A pet is a tamed frog, a frog with a name (Peter Jr. and Crazy
    Pete included) or a frog that belongs to a player. A frog that a player was in also keeps its body.
  - Random food, gifts and mystery boxes never roll a dead frog (`spawn_blacklisted`).
- Also fixes held mobs (picked-up critters, bees, drones and the like):
  - A held mob deleted in hand no longer breaks its holder.
  - Bees no longer die when dropped or thrown.
  - A shapeshifter turning back while held no longer ends up in nullspace.
  - Letting a held mob go quietly no longer prints "uncurls!".

### TG Proc/File Changes:

- `code/modules/mob/living/inhand_holder.dm`:
  - `/obj/item/mob_holder/proc/on_mob_deleted()`: the player of a deleted held mob becomes a ghost where the holder is.
    The mob leaves the holder before the holder is deleted, so the mob is not deleted twice. A holder that is already
    being deleted is left alone.
  - `/obj/item/mob_holder/proc/release()`: the holder stops holding the mob before it moves the mob out. A bee's holder
    no longer deletes the bee it just let go. Dropping the holder no longer releases the mob a second time, so a
    release with `display_messages = FALSE` stays quiet and a normal one says "uncurls!" once. If the carrier is in a
    locker, the mob goes into the locker instead of being deleted with the holder. If the carrier is in nullspace, the
    mob stays in the holder.
  - `/obj/item/mob_holder/Moved()`: does nothing while `release()` is dropping the holder (`releasing`).
  - `/obj/item/mob_holder/Exited()`: if the mob gets out on its own, the holder stops holding it before the holder is
    deleted.
- `code/modules/spells/spell_types/shapeshift/_shape_status.dm`: `/datum/status_effect/shapechange_mob/proc/restore_caster()`
  lets a held form go first. The caster comes back where the form was held, not inside its deleted holder.
- `code/modules/mob/living/basic/bots/cleanbot/cleanbot.dm`: cleanbots clean up dead roaches, as they do dead mice.

### Modular Overrides:

- `code/edible_vermin.dm`:
  - `/mob/living/basic/cockroach/death()` for the dead roach, which also takes the guts `death_drops` off a roach that
    leaves its body.
  - `/mob/living/basic/frog/mob_pickup()` for the dead frog.

### Defines:

- N/A

### Included files that are not contained in this module:

- `tgstation.dme`
