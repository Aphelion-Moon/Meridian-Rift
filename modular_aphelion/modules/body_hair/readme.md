## Body hair

Module ID: BODY_HAIR

### Description:

Facial hair styles and armpit and pubic hair, adapted from Ratwood-2.0 for our sprites.

**Beards.** New facial hair styles:

- Beard (Commodore), from their Knightly: a drooping horseshoe moustache over a pointed chin beard.
- Beard (Manly): a full, rounded beard that leaves the mouth clear.
- Beard (Twin Braids), from their Viking: a jaw frame closed under the chin, with two short braids.
- Sideburns (Short), from their Burns: three pixels of sideburn in front of each ear.

Their Stubble and Pipe are not here: Stubble is our Beard (Five o Clock Shadow) and Pipe is our Beard (Hipster)
with the sideburns a row higher. Ratwood's sheet is already in tg face coordinates, so the shapes sit on our heads
unmoved. Commodore, Twin Braids and Short Sideburns are lit from above; Manly uses the checker shading of our own
long beards.

**Armpit and pubic hair.** Character options under the secondary features: armpit hair (Trimmed, Natural,
Untamed) and pubic hair (the same three, plus Landing Strip, Heart and Arrow; only with ERP preferences and
genitals allowed). Both default to none. They take the hair colour and follow it while "Body hair matches hair
color" is on, which is the default; turned off, a colour picker appears for their own colour.

Each is a mutant bodypart like genitals: the choice goes into `dna.mutant_bodyparts`, species organ regeneration
grows a small hidden organ, and its overlay draws `<style>_<m|f>` from `icons/body_hair.dmi` over the skin and
under underwear, clothes and genitals, which cover it where they overlap. Ratwood's art is used as drawn, refitted
to our bodies (armpits a pixel lower on the male body and a pixel higher on the female one, pubic hair a pixel
lower on the male body); Untamed on the male body uses a softer, fuzzier take. Female Natural also sits a pixel
further out than the rest, in the armpit rather than the waist notch beside it, and female Trimmed's side view a
pixel lower, clear of pecs.

A razor used on the chest or groin (not in combat mode) trims them to any style or shaves them off, like a beard,
once clothing and underwear are out of the way. Trimming someone else's pubic hair needs their ERP preference.

Armpit interactions (in the staged interaction JSON) need only an arm, via the `target_arm` requirement, whether
or not there's hair.

### Credits:

Original shapes: Ratwood-2.0 contributors (`icons/mob/sprite_accessory/hair/human_facial_hair.dmi`,
`icons/mob/sprite_accessory/genitals/pits.dmi` and `pubes.dmi`).
