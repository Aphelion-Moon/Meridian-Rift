## Bulge

Module ID: BULGE

### Description:

A penis that is covered and at least half hard (`has_bulge()`, the same rule bulge interactions use) shows through
what covers it. Half hard it's a soft bulge that rounds out the crotch and, bigger, drops into the gap between the
thighs; fully hard it's a tent that drags the cloth forward into a peak. The size follows the penis's length in four
steps: under 5 inches, under 8, under 11, and 11 up.

Each look is two layers from `icons/bulge.dmi`: the cloth pushed out past the body (the `_fabric` state, tinted to
the garment) and translucent shading over it, so one sprite suits any colour. The garment's colour is sampled once
per worn sprite and tint from its crotch, facing south: the uniform, else a groin-length undershirt, else the
underwear. The penis's own bodypart overlay draws the bulge in place of the hidden penis, so it updates with
arousal and clothing like the genital does. A suit over the groin hides it, a chastity device prevents it, and a
penis set to never show has none.

The shapes are drawn for our bodies' crotch, which is the same on both.
