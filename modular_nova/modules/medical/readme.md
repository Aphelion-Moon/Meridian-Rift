<!-- This should be copy-pasted into the root of your module folder as readme.md -->

https://github.com/Skyrat-SS13/Skyrat-tg/pull/2336
https://github.com/Skyrat-SS13/Skyrat-tg/pull/23733

## Skyrat Medical Update <!--Title of your addition.-->

Module ID: SKYRAT_MEDICAL_UPDATE <!-- Uppercase, UNDERSCORE_CONNECTED name of your module, that you use to mark files. This is so people can case-sensitive search for your edits, if any. -->

### Description:

Various changes to the medical system, from adding bandage overlays, to new wounds, to modularized procs.

Robotic blunt and burn wounds and the dinitrogen plasmide coolant come from tg (tgstation/tgstation#97033, `code/datums/wounds/robot/`). Of the synthetic wounds, this module only keeps electrical damage (robotic slash and pierce) and robotic muscle wounds.

<!-- Here, try to describe what your PR does, what features it provides and any other directly useful information. -->

### TG Proc/File Changes:

- `code/__DEFINES/wounds.dm`: Added the muscle and electrical damage wound series, added them to the global list of wound series. The metal blunt/burn series are tg's
- `code/datums/wounds/robot/robotic_blunt.dm`: marked edits fix tg's bugs. `/critical/treat` finds the burn by its type, drops the 700 K check, adds start and finish messages, and hands RCDs and plungers to our procs. `/severe/restart` makes a scanned reboot faster, not slower. `/severe/crowbar_open` shocks only when `can_shock()` says so, and shows the tear-open text without a shock. These three and `/moderate/receive_damage` stop if the limb came off and has no victim
- `code/datums/wounds/robot/robotic_burns.dm`: `/datum/wound/burn/robotic/handle_process` keeps body heating under the heat-wound limit
- cat2_medicine_reagents.dm: /datum/reagent/medicine/c2/hercuri/on_mob_life, Allowed hercuri to affect synthetics, also changed hercuri process flags for this purpose
- quirks.dm: Commented out the quadruple_amputee/frail blacklist as frail can now apply to prosthetics
- `code/__DEFINES/bodyparts.dm`: BIO_METAL, BIO_WIRED, BIO_JOINTED and BIO_ROBOTIC docs match our synth wounds
<!-- If you edited any core procs, you should list them here. You should specify the files and procs you changed.
E.g:
- `code/modules/mob/living.dm`: `proc/overriden_proc`, `var/overriden_var`
  -->

### Modular Overrides:

- `code/wounds/synth/robotic_blunt_tg.dm`: adds RCD and plunger repair to `/datum/wound/blunt/robotic/critical` and its treatment text, and fixes `/moderate`'s `simple_treat_text`. Also adds metal scars, and lets Loosened Screws roll on the chest, from 30 on every limb.
- `code/wounds/synth/robotic_burns_tg.dm`: adds metal scars.
- `code/wounds/medicine_reagents.dm`: adds the dinitrogen plasmide slowdown, moves its overdose to 60u and lets synths process it.
- `code/sprays.dm`: the coolant spray's description warns about the slowdown.

These files set tg vars, so they hide upstream changes to them. When a commit picked from tg touches `code/datums/wounds/robot/`, diff the vars these files set.
<!-- If you added a new modular override (file or code-wise) for your module, you should list it here. Code files should specify what procs they changed, in case of multiple modules using the same file.
E.g:
- `modular_nova/master_files/sound/my_cool_sound.ogg`
- `modular_nova/master_files/code/my_modular_override.dm`: `proc/overriden_proc`, `var/overriden_var`
  -->

### Defines:

- Many local synthetic wound defines
<!-- If you needed to add any defines, mention the files you added those defines in, along with the name of the defines. -->

### Included files that are not contained in this module:

- strings/wounds/metal_scar_desc.json -- Required to be here for \_string_lists.dm usage
<!-- Likewise, be it a non-modular file or a modular one that's not contained within the folder belonging to this specific module, it should be mentioned here. Good examples are icons or sounds that are used between multiple modules, or other such edge-cases. -->

### Credits:

Azarak - Original medical update, muscle wounds, bandage overlays
Niko - Synthetic wounds
TG coding/Nova coding channels and community - Support, ideas, reviews

<!-- Here go the credits to you, dear coder, and in case of collaborative work or ports, credits to the original source of the code. -->
