## Edible vermin

Module ID: EDIBLE_VERMIN

### Description:

A cockroach that dies whole leaves a dead roach you can eat, as a mouse leaves a dead mouse. You can also eat a dead
frog. Live vermin cannot be eaten.

- A cockroach that dies whole leaves a dead roach on its back where it died, or in the hand or pocket that held it,
  and no guts. Squashing, gibbing or a microwave leaves the usual guts and no body. A bloodroach bursts, so it leaves
  its blood and guts and no body. Pest spray leaves the roach's own body instead. A dead roach is one bite of bugs. It
  rots away on the floor like other food, and cleanbots clean it up. Random food, gifts and mystery boxes never roll
  one (`spawn_blacklisted`).
- A frog keeps its body when it dies. Pick the body up, then click yourself or someone else with it, as with food. It
  goes down in one bite after 3 seconds, as raw meat, and the body is deleted. A live frog in the hand is not food.
  - The holder is food only while someone tries to eat it. If they stop, or their mouth is covered, or they are too
    full, it becomes a plain holder again. So grinders, syringes and dishes cannot use it.
  - A rare frog, or the crazy frog a regal rat makes of one, is also a strong trip. These frogs have mushroom
    hallucinogen in their bite. Eating one gives 10 units of it and 25 of mindbreaker toxin, the same two drugs as a
    sunshine pill (15 and 15). The mushroom dose stays low because food reagents are half pure, which halves its
    overdose point from 30 units to 15.
  - Pets cannot be eaten: tamed frogs, named ones (Peter Jr., Crazy Pete, or any frog given a name) and frogs that
    belong to a person. A shapeshifter's frog form cannot either, because the real body is inside. A frog that comes
    back to life before the bite goes free.
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
  - `inhand_holder_type` of `/mob/living/basic/frog`, `/mob/living/basic/frog/rare` and
    `/mob/living/basic/frog/crazy/rare`, for the holder that lets a dead frog be eaten.

### Defines:

- N/A

### Included files that are not contained in this module:

- `tgstation.dme`
