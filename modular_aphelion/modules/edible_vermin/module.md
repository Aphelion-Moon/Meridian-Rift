## Edible vermin

Module ID: EDIBLE_VERMIN

### Description:

You can eat live mice, cockroaches and frogs. Pick one up, then click yourself or someone else with it, as with food.
A cockroach that dies leaves a body that you can also eat.

- It goes down in one bite after a short struggle: 3 seconds for a mouse or frog, 1 for a roach, 3 to feed one to
  someone else. A mouse is meat, raw and gore, a frog is meat and raw, and a roach is bugs and raw. The critter is
  deleted, not killed, so it leaves no corpse, guts or blood. Dead frogs go down the same way.
- The holder is food only while someone tries to eat it. If they stop, or their mouth is covered, or they are too full,
  it becomes a plain holder again. So syringes, grinders, dishes, fridges and the DNA infuser cannot use it. If the
  holder is deleted, the critter goes free, as with any held mob.
- If the critter is alive, whoever feeds it is asked first whether they are sure. No answer in 10 seconds means no.
  A dead one, or a feeder with no player, skips the question.
- If a player controls the critter, they get a prompt next. "Wriggle free" lets it go. "Let them", or no answer in
  10 seconds, starts the meal. The critter can still escape by moving, or by a late "Wriggle free", until it is
  swallowed. The answer counts for one attempt: if the meal stops or cannot start, the next attempt asks again. If its
  player has left, it is eaten without a prompt and the player becomes a ghost where it was eaten.
- Pets cannot be eaten, even with a player in them. Pets are tamed critters, named ones (Tom, Peter Jr., Crazy Pete, or
  any critter given a name), and critters that belong to a person. Regal rat minions can be eaten. Shapeshifters cannot,
  because their real body is inside, and the eater gets no hint why. Pacifists do not eat or feed anything alive. The
  checks run again when the struggle ends, and a critter that fails them goes free before it is bitten.
- A cockroach that dies whole leaves a dead roach on its back where it died, or in the hand or pocket that held it,
  and no guts. Squashing, gibbing or a microwave leaves the usual guts and no body. A bloodroach bursts, so it leaves
  its blood and guts and no body. Pest spray leaves the roach's own body instead. A dead roach is one bite of bugs. It
  rots away on the floor like other food, and cleanbots clean it up. Random food, gifts and mystery boxes never roll
  one (`spawn_blacklisted`).

### TG Proc/File Changes:

- `code/modules/mob/living/inhand_holder.dm`:
  - `/obj/item/mob_holder/proc/on_mob_deleted()`: the player of a deleted held mob becomes a ghost where the holder is.
    The mob leaves the holder before the holder is deleted, so the mob is not deleted twice. A holder that is already
    being deleted is left alone.
  - `/obj/item/mob_holder/proc/release()`: the holder stops holding the mob before it moves the mob out. A bee's holder
    no longer deletes the bee it just let go, and a dropped critter uncurls once. If the carrier is in a locker, the mob
    goes into the locker instead of being deleted with the holder.
  - `/obj/item/mob_holder/Exited()`: if the mob gets out on its own, the holder stops holding it before the holder is
    deleted.
- `code/modules/spells/spell_types/shapeshift/_shape_status.dm`: `/datum/status_effect/shapechange_mob/proc/restore_caster()`
  lets a held form go first. The caster comes back where the form was held, not inside its deleted holder.
- `code/modules/mob/living/basic/bots/cleanbot/cleanbot.dm`: cleanbots clean up dead roaches, as they do dead mice.

### Modular Overrides:

- `code/edible_vermin.dm`: `inhand_holder_type` of `/mob/living/basic/mouse`, `/mob/living/basic/cockroach` and
  `/mob/living/basic/frog`, and `/mob/living/basic/cockroach/death()` for the dead roach, which also takes the guts
  `death_drops` off a roach that leaves its body.

### Defines:

- N/A

### Included files that are not contained in this module:

- `code/modules/unit_tests/~nova/edible_vermin.dm`, included from `code/modules/unit_tests/_unit_tests.dm` inside the
  existing `NOVA EDIT ADDITION` block. It tests what eating leaves behind, who is refused, attempts that end early, dead
  roaches, and the holder and shapeshift fixes (`mob_holder_fix`).
- `tgstation.dme`
