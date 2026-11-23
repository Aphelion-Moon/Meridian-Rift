## Title: Customization

MODULE ID: CUSTOMIZATION

### Description:

IF YOU WANT TO ADD AN EXTRA FEATURE TO SOMEONES DNA LOOK AT "`code\__DEFINES\~nova_defines\DNA.dm"`

Re-writes how mutant bodyparts exist and how they're handled. Adds in a per limb body marking system. Adds in loadout, with lots of clothing ported over. Adds in all the missing species. Adds in flavor text and OOC prefs. Adds in special rendering cases for digitigrades, taurs, snouts, voxes etc. Adds in changeable PDA ringtone message.

### Accessory canvases:

The final bodypart preparation in `modular_aphelion/modules/worn_emissives/` groups
standard emissive masks so their offsets rotate with the body, independently of DMI
canvas size. `dimension_x` and `dimension_y` control visible sprite placement; they
may intentionally differ from the canvas dimensions for existing artwork.

TG wings use `icons/mob/human/species/wings.dmi` with their original centering values.
Nova wings and the harpy reshade/dual-tone variants use their respective original
`wings.dmi` and `species/harpy_wings.dmi` sheets. No padded TG or harpy copies are
kept in the Nova wing sheet. Preserve the source sheet's positioning when changing
these paths; matching the canvas dimensions alone can move the artwork.

The corrected sheets in `modular_nova/master_files/icons/mob/sprite_accessory/` preserve
their original standing positions and animation metadata:

- `ears_big`, `horns_big`, `halo`, and `moogle_pom`: artwork shifted north eight pixels
  within the 32x48 canvas, paired with `center = TRUE` and `dimension_y = 48`.
- `moth_fluff`: unused top/right margins removed to make a 32x32 canvas. `moth_antennae`
  and `moth_markings` use similarly cropped copies of the upstream moth sheets.

Fish infusion tails and the xenomorph queen tail also retain their original TG sheets
and offsets, using the same final preparation for standard bodypart emissive masks.

When updating these assets from upstream, preserve the paired artwork and centering
changes. The upstream sheets remain available to their non-accessory consumers.

### TG Proc Changes:

`.\code\__HELPERS\global_lists.dm > \proc\make_datum_references_lists()`
`.\code\__HELPERS\mobs.dm > \proc\random_features()`
`.\code\controllers\subsystem\job.dm` > \datum\controller\subsystem\job\proc\EquipRank()
`.\code\datums\dna.dm` > \datum\dna\proc\initialize_dna() , \mob\living\carbon\set_species()
`.\code\modules\admin\create_mob.dm `> \proc\randomize_human()
`.\code\modules\client\preferences.dm` > ALMOST THE ENTIRETY OF THE FILE
`.\code\modules\client\preferences_savefile.dm` > ONCE AGAIN, THE ENTIRE FILE
`.\code\modules\mob\dead\new_player\preferences_setup.dm` > \datum\preferences\proc\random_character(), \datum\preferences\proc\random_species(), \datum\preferences\proc\update_preview_icon()
`.\code\modules\mob\living\carbon\carbon_update_icons.dm` > \mob\living\carbon\update_inv_wear_mask(), \mob\living\carbon\update_inv_head(), \mob\living\carbon\proc\update_body_parts(), `\mob\living\carbon\proc\generate_icon_render_key()`
`.\code\modules\mob\living\carbon\human\emote.dm` > \datum\emote\living\carbon\human\wag\run_emote(), \datum\emote\living\carbon\human\wag\can_run_emote()
`.\code\modules\mob\living\carbon\human\examine.dm` > \mob\living\carbon\human\examine()
`.\code\modules\mob\living\carbon\human\human_update_icons.dm` > \mob\living\carbon\human\update_inv_w_uniform(), \mob\living\carbon\human\update_inv_glasses(), \mob\living\carbon\human\update_inv_shoes(), `\mob\living\carbon\human\update_inv_wear_suit()`, \obj\item\proc\build_worn_icon(), \mob\living\carbon\human\generate_icon_render_key()
`.\code\modules\mob\living\carbon\human\human_update_icons.dm` > \mob\living\carbon\human\update_worn_undersuit(), \mob\living\carbon\human\update_worn_gloves(), \mob\living\carbon\human\update_worn_head(), \mob\living\carbon\human\update_worn_oversuit(), \mob\living\carbon\human\update_worn_mask() > call `fit_worn_effects()`, which places blood and rips drawn for a human body on a species-shaped sprite
`.\code\modules\mob\living\carbon\human\dummy.dm` > \mob\living\carbon\human\dummy\apply_height() > asks `stretches_each_image()`, so a dummy with a taur body stretches each image for its height and keeps the taur body its size. A Big Legs taur body stretches with the rider, so that dummy stretches in one piece
`.\code\modules\clothing\clothing.dm` > \obj\item\clothing\proc\get_blood_overlay() > returns the stain through `fit_worn_effect()`, which lines it up with the worn sprite and cuts it at a taur's waist
`.\code\modules\clothing\gloves\_gloves.dm` > \obj\item\clothing\gloves\worn_overlays() > the rip goes through `fit_worn_effect()`
`.\code\modules\clothing\head\_head.dm` > \obj\item\clothing\head\worn_overlays() > the rip goes through `fit_worn_effect()`
`.\code\modules\clothing\masks\_masks.dm` > \obj\item\clothing\mask\worn_overlays() > the rip goes through `fit_worn_effect()`
`.\code\modules\clothing\suits\_suits.dm` > \obj\item\clothing\suit\worn_overlays() > the rip goes through `fit_worn_effect()`, and each uniform accessory drawn above the suit through `fit_rider_overlay()`, which keeps it on a taur's rider
`.\code\modules\clothing\under\_under.dm` > \obj\item\clothing\under\worn_overlays() > the rip goes through `fit_worn_effect()`, and the accessories through `fit_rider_overlays()`
`.\code\modules\unit_tests\_unit_tests.dm` > includes `taur_height_stretch.dm` and `worn_stain_fit.dm`
`.\code\modules\mob\living\carbon\human\species.dm` > \datum\species\proc\on_species_gain(), \datum\species\proc\handle_body(), \datum\species\proc\handle_mutant_bodyparts(), \datum\species\proc\can_equip(), `\datum\species\proc\handle_hair()`
`.\code\modules\mob\living\carbon\human\species_types\felinid.dm` > the 5 procs related to wagging tail
`.\code\modules\mob\living\carbon\human\species_types\lizardpeople.dm` the 5 procs related to wagging tail and - \datum\species\lizard\on_species_gain()
`.\code\modules\surgery\bodyparts_bodyparts.dm` > \obj\item\bodypart\proc\get_limb_icon()
`.\code\modules\surgery\organs\ears.dm` > \obj\item\organ\ears\cat\Insert(), \obj\item\organ\ears\cat\Remove()
`.\code\modules\surgery\organs\tails.dm` > \obj\item\organ\tail\cat\Insert(), \obj\item\organ\tail\cat\Remove(), \obj\item\organ\tail\lizard\Initialize(mapload), \obj\item\organ\tail\lizard\Insert(), `\obj\item\organ\tail\lizard\Remove()`
`.\code\modules\surgery\bodyparts\dismemberment.dm` > \mob\living\carbon\regenerate_limb()
`.\code\modules\mob\living\carbon\human\status_procs.dm` > \mob\living\carbon\human\become_husk() > APPENDED
`.\code\modules\reagents\chemistry\holder.dm` > \datum\reagents\metabolize()
`.\code\modules\food_and_drinks\drinks\drinks\drinkingglass.dm` > \obj\item\reagent_containers\cup\glass\drinkingglass\on_reagent_change()
`.\code\modules\mob\living\carbon\human\human_defense.dm` > \mob\living\carbon\human\emp_act()
`.\code\modules\mob\living\carbon\human.dm` > \mob\living\carbon\human\revive() > APPENDED
`.\code\modules\reagents\chemistry\reagents\food_reagents.dm` > datum\reagent\consumable\on_mob_life()
`.\code\datums\traits\negative.dm` > \datum\quirk\prosthetic_limb
`.\code\modules\client.dm` > \client\proc\update_special_keybinds()
`.\code\datums\traits\negative.dm` > \datum\quirk\prosthetic_limb

`.\code\modules\mob\living\carbon\human\species.dm` > `\datum\species\regenerate_organs()` > `APPENDED`

`.\code\modules\mob\dead\new_player\new_player.dm` > `\mob\dead\new_player\proc\IsJobUnavailable()`, `\proc\get_job_unavailable_error_message()`

### Defines:

`.\code\modules\surgery\organs\tongue.dm > var\static\list\languages_possible_base` - added 2 languages
`.\code\modules\mob\living\carbon\human\species_types\lizardpeople.dm` > commented out "mutant_organs = list(\obj\item\organ\tail\lizard)"
`.\code\modules\mob\living\carbon\human\species_types\felinid.dm` > commented out "mutantears = \obj\item\organ\ears\cat" and "mutant_organs = list(\obj\item\organ\tail\cat)"
`.\code\modules\mob\living\carbon\human\species.dm` > var\list\list\mutant_bodyparts (added typed list type)
`.\code_globalvars\lists\flavor_misc.dm` > Removed accessory list defines
`.\code\datums\keybindings\living.dm` > \datum\keybinding\living\look_up > from L to P`

`.\code\__DEFINES\~nova_defines\DNA.dm` > A TON of defines`
`.\code\_\_DEFINES\~nova_defines\obj_flags.dm` > Organ flags`
`.\code\__DEFINES\~nova_defines\say.dm` > MAX_FLAVOR_LEN`
`.\code\_\_DEFINES\~nova_defines\traits.dm` > TRAIT_NO_HUSK`

.\modular_nova\modules\customization\modules\reagents\chemistry\reagents.dm > var\process_flags

### Master file additions

.\modular_nova\master_files\icons\mob\clothing\eyes_vox.dmi
.\modular_nova\master_files\icons\mob\clothing\feet_digi.dmi
.\modular_nova\master_files\icons\mob\clothing\head_muzzled.dmi
.\modular_nova\master_files\icons\mob\clothing\head_vox.dmi
.\modular_nova\master_files\icons\mob\clothing\mask_muzzled.dmi
.\modular_nova\master_files\icons\mob\clothing\mask_vox.dmi
.\modular_nova\master_files\icons\mob\clothing\suit_digi.dmi
.\modular_nova\master_files\icons\mob\clothing\suit_taur_hoof.dmi
.\modular_nova\master_files\icons\mob\clothing\suit_taur_paw.dmi
.\modular_nova\master_files\icons\mob\clothing\suit_taur_snake.dmi
.\modular_nova\master_files\icons\mob\clothing\uniform_digi.dmi
.\modular_nova\master_files\icons\mob\clothing\under\uniform_digi.dmi
.\modular_nova\master_files\icons\mob\clothing\under\uniform_taur_hoof.dmi
.\modular_nova\master_files\icons\mob\clothing\under\uniform_taur_paw.dmi
.\modular_nova\master_files\icons\mob\clothing\under\uniform_taur_snake.dmi

.\modular_nova\master_files\icons\obj\drinks.dmi

### Included files that are not contained in this module:

- `code/modules/unit_tests/~nova/taur_height_stretch.dm`: height stretches a taur-fitted suit, never the taur body under it or the paint on that body
- `code/modules/unit_tests/~nova/worn_stain_fit.dm`: blood and rips follow a taur-fitted suit and a species-shaped uniform

### Credits:

Azarak
