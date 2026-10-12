## Adult items

Module ID: ADULT_ITEMS

### Description:

Adult items ported from S.P.L.U.R.T. A family with no Nova counterpart gets its own file in `code/`, with its own
icon sheets in `icons/`, while an addition to a Nova family goes in that family's Nova file. Each family has its own
line under Credits. Every item has an `Initialize()` stanza in Nova's `_erp_disabled_item_enforcement.dm`, so the
lewd-items config removes it, and every family that adds items lists its top types on one line of
`adult_items_gated_types()` in `code/_gated_types.dm` - a new family adds its line there. The
`adult_items_kill_switch` unit test makes every concrete type under them and fails on any that survives with lewd
items disabled or does not spawn with them enabled. Items that fit the box of love carry `obj_flags_nova = ERP_ITEM`,
as their Nova neighbours do, and each family reaches players through the same vendor or loadout as its Nova
neighbours.

- **Medipens** (`code/medipens.dm`). Five one-shot 30u medipens under the abstract
  `/obj/item/reagent_containers/hypospray/medipen/lewd`: crocin, hexacrocin, succubus milk, incubus draft, and the
  La Coom Bomb (10u each of hexacrocin, succubus milk and incubus draft). Each has a spent sprite. The lewd medipen
  box (`/obj/item/storage/box/medipens/lewd`) holds one of each; its sprite is Nova's medical box with its own
  illustration drawn on. LustWish sells the crocin, succubus milk and incubus draft pens beside its lewd bottles and,
  once hacked, the hexacrocin pen, the La Coom Bomb and the box beside its hexacrocin stock. Every pen and the box also
  has an entry in the Erotic loadout, beside the lewd bottles, pills and neuroware boxes.
- **Condom box** (`code/condom_box.dm`). The surplus condom box (`/obj/item/storage/box/condoms`) comes with ten of
  Nova's condom packs and holds only condom packs, ten at most. Its sprite is the box of love's body with a condom
  packet drawn on its label. LustWish sells it beside the condom packs, and it has an Erotic loadout entry beside
  theirs.
- **Bluespace fleshlight** (in Nova's `fleshlight.dm`). The teal `/obj/item/clothing/sextoy/fleshlight/bluespace`
  cannot be recoloured, and one pass of it catches an immovable rod: the rod pops and its momentum flings the user up
  to twelve tiles along its path. The throw is gentle, so whatever ends it - usually a wall - stops the user without
  the stun and bruises of a crash, and a wizard in rod form is set down unharmed where the rod was. LustWish sells one
  as a premium item at ten command paychecks. Nova's sex-toy stanza removes it with the lewd-items config.
- **Leash** (in Nova's `leash.dm`). Nova's leash pulls like a real one. The leashed follows their holder a real step
  per step along the route the holder walked - round corners and any hole, chasm or lava the holder stepped round,
  along a lattice or catwalk over space without being pulled off it, through the door the holder opened, up and down
  stairs, out of deep water - and where they cannot follow (a wall, a door they lack access to, buckled or anchored)
  the leash pulls taut and holds the holder at its two tiles until they let go. A tug never pulls them onto a hole,
  chasm or lava, or off a lattice into space. A leashed who falls to a lower level or into a chasm drags their holder
  to the hole, a step every second and a half after a moment to let go, and on into the chasm after them; a buckled
  holder, or one over a hole they cannot fall through, is held near it instead. Dropping the leash leaves it hooked:
  it lies on the floor and trails the leashed, down a hole or a chasm too, light enough never to hold them back, and
  anyone the leashed's sex toy preference allows can pick it up and lead. Only the holder using it on the leashed, the
  leashed breaking free, or the safeword verb unhooks it. A ride on a shuttle or a lift together keeps it in hand, and
  two in one place - a locker shut on both, or a chasm's depths - stay hooked; a move that leaves the two out of reach
  (a teleport, a jaunt, the holder falling away) leaves it at the leashed's feet. A line in the colour of its strap
  runs straight to the leashed from the hand holding it, or from the leash where it lies, while the two are in reach -
  even across a hole, a wall corner or a window; it is blank while they are out of reach, or while either is inside
  something or on another z-level.
- **Pointe boots** (in Nova's `lewd_shoes.dm`). `/obj/item/clothing/shoes/ballet_heels/pointe_boots` are Nova's ballet
  heels with the feet held en pointe: they keep the heels' lace-up shaft, four heel sounds and default colour, and
  players colour them through a GAGS template of their own, digitigrade legs included. LustWish, the shoes loadout
  and the Grimoire Libidine NIFSoft offer them, as they offer the ballet heels.
- **Latex half-catsuit** (`code/latex_halfcatsuit.dm`). `/obj/item/clothing/under/misc/latex_halfcatsuit` is Nova's
  latex catsuit with the legs cut off. Like the catsuit, it takes six seconds to peel off yourself and has a male and
  a female sprite; it picks one by its wearer's body type, and unlike the catsuit's, its pick shows in the character
  preview. It has digitigrade, Vox, Vox Primalis and Teshari sprites of its own, the Vox ones with the catsuit's latex
  hand covers. A sibling of the catsuit, not its subtype, it does not bulge as the catsuit's long johns do, hides none
  of its wearer's parts and leaves a taur's body in sight: paw, hoof and snake taurs wear it cropped, and big-legged
  taurs wear the plain sprite. LustWish, the under loadout and the Grimoire Libidine NIFSoft offer it beside the
  catsuit.
- **Paw mood and cat paws** (in Nova's `lewd_gloves.dm`). Worn as gloves, Nova's paw mittens put their wearer in the
  paw mood ("So-ft... Ro-und... Use-less... Lo-ve it!"), which goes when they come off. The cat paws
  (`/obj/item/clothing/gloves/ball_mittens/paw_mittens/cat_paws`) are paw mittens of a bigger, rounder shape, with toe
  beans and a tag at the cuff, coloured in three parts through a GAGS template of their own; they restrain as the
  mittens do and bring the paw mood too. LustWish sells them beside the paw mittens, and the Erotic loadout offers
  both kinds beside the ball mittens. The sex-toy preference guards both as it guards the ball mittens - the paw
  mittens had slipped past it - and Nova's ball-mittens stanza removes them with the lewd-items config.
- **R.U.T.T.** (`code/rutt.dm`). `/datum/reagent/drug/aphrodisiac/rutt` is an aphrodisiac far stronger than
  hexacrocin, behind the aphrodisiac preference as crocin is: it arouses after ten cycles and brings pleasure that
  climbs to 15 a cycle after twenty-five; from the forty-fifth its taker drools, shivers and twitches, and now and
  then climaxes, if they let their body climax on its own. It mixes from crocin, dopamine, femcum and epinephrine at
  322 K, and dopamine, which only a climax made before, mixes from diethylamine, ephedrine, hydrogen and phenol at
  373 K; the ERP config removes both reactions, as it does Nova's. Once hacked, LustWish sells its bottle and its
  pill, which looks like the dopamine pill, beside the hexacrocin; the Erotic loadout offers both.
- **Denbu tincture** (`code/butt_enlarger.dm`). `/datum/reagent/drug/aphrodisiac/butt_enlarger` grows the butt a size
  every twenty cycles, up to the largest size a player can pick, for players who take butt enlargement - a preference
  beside breast enlargement - and first grows a size-1 butt on a player without one, if they take new genitalia. A
  butt in clothes strains and bruises from two sizes short of the largest until it gets there. Camphor's overdose
  moves a butt back to its preference size, as it does the other genitals. It mixes from saline-glucose, sugar,
  silicon and crocin; LustWish sells its bottle beside the succubus milk and incubus draft, and the Erotic loadout
  offers it.
- **Bridle** (`code/bridle.dm`). `/obj/item/clothing/mask/bridle` is a horse bridle that players colour in three parts
  (straps, blinders and fittings). Lowered, its blinders darken the wearer's sight as a welding mask does; set, its
  bit covers their mouth and muffles their speech, emotes and spoken spells through tg's `muffles_speech` element. The
  wearer moves each with an action button, and alt-click steps through none, blinders, bit and both. From the strip
  menu, a player who takes part in ERP takes that step on a wearer who takes sex toys, in the time it takes to strip a
  mask; the wearer and onlookers are warned first, and the step is logged. Secured in hand, the straps hold the
  blinders and the bit where they are. It has muzzled sprites of its own and can't be put on a player who does not
  take sex toys; LustWish and the Erotic loadout offer it beside the ring gag.
- **Lustwish MOD suit** (`code/lustwish_mod.dm`). `/datum/mod_theme/standard/lustwish` is the standard MOD suit - its
  stats, its seals and its lore - in LustWish's skin, with seal messages of its own and a purple hardlight, and
  `/obj/item/mod/construction/plating/lustwish` builds it. The MOD hypnotic visor,
  `/obj/item/mod/module/lustwish/hypno_visor`, fills its wearer's head with its phrase as Nova's hypnotic goggles do,
  through the one status effect both share, `/datum/status_effect/hypnotic_phrase`, for players who take sex toys:
  while it is toggled on, or whenever the helmet is sealed once its control wire is snipped. On the lustwish helmet it
  draws a spiral. The MOD remote control module, `/obj/item/mod/module/lustwish/remote_control`, holds its remote,
  `/obj/item/mod/remote`, and goes into a suit only once the remote is out; the remote then drives the suit while its
  wearer is within seven tiles on the same z-level (farther off, its window stays open but inert and says so), for a
  wearer who takes sex toys and a holder who takes part in ERP: the suit's activation, parts, modules and lock, run as
  the holder through the suit's own interface, and a forced emote, judged as the holder's own words. The two modules
  share the abstract parent `/obj/item/mod/module/lustwish`. LustWish sells the plating and the two modules in a MOD
  Suit category of their own. Known issue: the custom emote still runs its own check on the wearer (`emote_is_valid()`
  in `code/modules/mob/living/emote.dm`), so a forced emote that opens with "says", "exclaims", "yells" or "asks" puts
  "Invalid emote." in the wearer's chat and tells the holder nothing; that check judges whoever emotes, with no way to
  judge the holder instead, and a copy of its rule in the remote would drift from tg's.

### TG Proc/File Changes:

- `icons/map_icons/clothing/shoes.dmi`: the pointe boots' map icon, as `SSgreyscale_previews` generates it.
- `icons/map_icons/clothing/_clothing.dmi`: the cat paws' map icon, as `SSgreyscale_previews` generates it.
- `icons/map_icons/clothing/mask.dmi`: the bridle's map icon, as `SSgreyscale_previews` generates it.
- `tgui/packages/tgui/interfaces/StripMenu.tsx`: the strip menu's "Adjust bridle" button.

### Modular Overrides:

- `modular_nova/master_files/code/modules/client/preferences/erp_preferences.dm`: the butt enlargement preference,
  after breast shrinkage.
- `modular_nova/modules/GAGS/nsfw/gloves.dm` and
  `modular_nova/modules/GAGS/nsfw/json_configs/clothing/gloves/cat_paws.json` (new): the cat paws' GAGS configs,
  after the paw mittens'.
- `modular_nova/modules/GAGS/nsfw/masks.dm`, `modular_nova/modules/GAGS/nsfw/json_configs/clothing/masks/bridle.json`
  and `modular_nova/modules/GAGS/nsfw/json_configs/clothing/masks/bridle_worn.json` (both new): the bridle's world,
  worn and muzzled GAGS configs, after the choke gag's.
- `modular_nova/modules/GAGS/nsfw/shoes.dm` and
  `modular_nova/modules/GAGS/nsfw/json_configs/clothing/shoes/pointe_boots.json` (new): the pointe boots' GAGS
  configs, after the ballet heel's.
- `modular_nova/modules/loadouts/loadout_items/loadout_datum_erp.dm`: the pens, the medipen box, the condom box, the
  paw mittens, the cat paws, R.U.T.T., denbu tincture and the bridle in the Erotic loadout.
- `modular_nova/modules/loadouts/loadout_items/loadout_datum_shoes.dm`: the pointe boots in the shoes loadout.
- `modular_nova/modules/loadouts/loadout_items/under/loadout_datum_under.dm`: the latex half-catsuit in the under
  loadout, after the catsuit.
- `modular_nova/modules/modular_implants/code/nifsofts/dorms.dm`: the pointe boots and the latex half-catsuit in the
  Grimoire Libidine NIFSoft.
- `modular_nova/modules/modular_items/lewd_items/code/clothing_pref_check.dm`: Nova's paw mittens, the cat paws and
  the bridle in the sex-toy preference check.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_chemistry/reagents/_aphrodisiac.dm`: the aphrodisiacs'
  preference gates read the player through `GET_CLIENT`, so a unit test's mock player counts.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_chemistry/reagents/camphor.dm`: camphor's overdose moves a
  butt back to its preference size.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_chemistry/reagents/dopamine.dm`: a dopamine overdose's
  happy message and its mood only for players who take aphrodisiacs, now that anyone can mix enough dopamine to
  overdose.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/hypnogoggles.dm`: the goggles' hypnosis is the
  status effect `/datum/status_effect/hypnotic_phrase`, which the MOD hypnotic visor shares; it also ends when the
  goggles are deleted, its log lines name the device ("was hypnotized by" and "is no longer hypnotized by", where they
  read "was hypnogoggled" and "is no longer hypnogoggled"), and its hallucinated whisper now starts through
  `cause_hallucination()`, where the goggles' own was never started and stayed in `GLOB.all_ongoing_hallucinations`.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/lewd_gloves.dm`: the paw mood on the paw
  mittens, and the cat paws.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/lewd_shoes.dm`: the pointe boots.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/_erp_disabled_item_enforcement.dm`: `Initialize()`
  of `/obj/item/reagent_containers/hypospray/medipen/lewd`, `/obj/item/storage/box/medipens/lewd`,
  `/obj/item/storage/box/condoms`, `/obj/item/clothing/shoes/ballet_heels/pointe_boots`,
  `/obj/item/clothing/under/misc/latex_halfcatsuit`, `/obj/item/reagent_containers/cup/bottle/rutt`,
  `/obj/item/reagent_containers/applicator/pill/rutt`, `/obj/item/reagent_containers/cup/bottle/butt_enlarger`,
  `/obj/item/clothing/mask/bridle`, `/obj/item/mod/construction/plating/lustwish`, `/obj/item/mod/module/lustwish` and
  `/obj/item/mod/remote`.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/fleshlight.dm`: the bluespace fleshlight.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/leash.dm`: the leash's pull and its line.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_machinery/lustwish.dm`: the pens, the medipen box, the
  condom box, the bluespace fleshlight, the pointe boots, the latex half-catsuit, the cat paws, R.U.T.T., denbu
  tincture, the bridle and the lustwish MOD set (a MOD Suit category) in the LustWish stock.
- `modular_nova/modules/modular_items/lewd_items/icons/{obj,mob}/lewd_clothing/lewd_gloves.dmi`: the cat paws'
  greyscale template, states `catpaws`, `catpaws-pawpad` and `catpaws-tag`, after the existing states.
- `modular_nova/modules/modular_items/lewd_items/icons/{obj,mob}/lewd_clothing/lewd_masks.dmi` and
  `modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_masks_muzzled.dmi`: the bridle's
  greyscale template, states `bridle_strap`, `bridle_blinders_up`, `bridle_blinders_down` (worn only) and
  `bridle_fittings`, after the existing states.
- `modular_nova/modules/modular_items/lewd_items/icons/{obj,mob}/lewd_clothing/lewd_shoes.dmi` and
  `modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_shoes_digi.dmi`: the pointe boots'
  greyscale template, state `pointe_boots`, after the existing states.
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/game_preferences/nova/erp_preferences.tsx`: the
  butt enlargement toggle, after the breast toggles.

### Defines:

- N/A

### Included files that are not contained in this module:

- `code/modules/unit_tests/~nova/adult_items_kill_switch.dm`: the lewd-items config test for every family.
- `tgui/packages/tgui/interfaces/MODsuitRemote.tsx`: the MOD remote's window.

### Credits:

- **Medipens.**
  - Code and text from S.P.L.U.R.T-tg's `modular_zzplurt/code/modules/modular_items/lewd_items/code/medipens.dm`
    (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Pen and inhand sprites by MosleyTheMalO for S.P.L.U.R.T-Station-13
    ([PR #434](https://github.com/SPLURT-Station/S.P.L.U.R.T-Station-13/pull/434)), brought to S.P.L.U.R.T-tg by
    Krashly ([PR #65](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/65)), CC BY-SA 3.0. Taken from
    `modular_zzplurt/icons/obj/syringe.dmi` and
    `modular_zzplurt/icons/mob/inhands/equipment/medical_{left,right}hand.dmi`. The pens are recolours of
    [tg](https://github.com/tgstation/tgstation)'s medipen (CC BY-SA 3.0).
  - Box: [Nova Sector](https://github.com/NovaSector/NovaSector)'s `medbox` and its `epipen` illustration (tg's, as
    Nova places it), from `modular_nova/modules/aesthetics/storage/icons/storage.dmi` (CC BY-SA 3.0; that module
    credits TauCeti station and Gandalf2k15).
  - Modified: only the states these items use; the hexacrocin pen's inhand left out, being an exact copy of the
    crocin pen's; the pen bodies recoloured from S.P.L.U.R.T's magenta (`#ff66ff`, `#ff33ff`) to Nova's plum ramp
    (`#9764ab`, `#76428a`, from `lewd_portals.dmi`); the La Coom Bomb's seven-frame cycle started at its yellow-green
    frame and slowed to tg's delay 3; the `epipen` illustration recoloured as the crocin pen and drawn onto `medbox`
    as one state, `medbox_lewd`, so menus show the box with its illustration.
- **Condom box.**
  - Code and text from S.P.L.U.R.T-tg's `modular_zzplurt/code/modules/modular_items/lewd_items/code/condom_box.dm`
    (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Sprite: `icons/condom_box.dmi`, `condom_box` - [Nova Sector](https://github.com/NovaSector/NovaSector)'s `hugbox`
    (the box of love's body), from `modular_nova/modules/aesthetics/storage/icons/storage.dmi` (CC BY-SA 3.0; that
    module credits TauCeti station and Gandalf2k15), with an Aphelion-original face on its label: one condom foil
    packet with its ring, in the colours of Nova's condom pack. One state, so menus show the box with its face.
  - Modified: the storage is its own `/datum/storage/box/condoms`, as tg's matchbox has, and takes condom packs
    back - S.P.L.U.R.T's box set the storage's `can_hold` typecache to a plain list, which refuses every insertion.
- **Bluespace fleshlight.**
  - Code and text from S.P.L.U.R.T-tg's
    `modular_skyrat/modules/modular_items/lewd_items/code/lewd_items/fleshlight.dm` (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Nothing imported: it wears Nova's `fleshlight_teal` states and pops with tg's `cartoon_pop.ogg`.
  - Modified: the user is flung along the rod's path - S.P.L.U.R.T threw them at the next tile, which ends a throw
    after one step under gravity - and lands without a crash's stun and damage; a wizard in rod form is set down
    before the rod is deleted, where S.P.L.U.R.T deleted the wizard with it; menus show it teal; LustWish sells it as
    premium, where S.P.L.U.R.T hid it in contraband.
- **Leash.**
  - The pull, the hold, the drag to a hole and the leash left hooked on the floor are Meridian's own (mal, 2026-10-12):
    Nova's leash walked a pathfound route in one tick or teleported the leashed to the holder, and dropping it
    unhooked it.
  - The line's behaviour from S.P.L.U.R.T-tg's `modular_skyrat/modules/modular_items/lewd_items/code/lewd_items/leash.dm`
    (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Nothing imported: the line is tg's `fishing_line` beam state.
  - Modified: drawn on tg's held beam with the borg vacuum hose's hand offsets (`/datum/beam/held/vacuum`) instead of
    S.P.L.U.R.T's copy of the fishing line's beam with every offset at zero; coloured as the leash's strap, where
    S.P.L.U.R.T's was always purple; owned by the leash component, so it also goes when the leashed breaks free; and
    blank only while out of reach, inside something or on another z-level - S.P.L.U.R.T's never came back once the
    two were out of reach; drawn from the leash itself while it lies on the floor.
- **Pointe boots.**
  - Code from S.P.L.U.R.T-tg's `modular_skyrat/modules/modular_items/lewd_items/code/lewd_clothing/lewd_shoes.dm`
    (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026),
    where the boots are `/obj/item/clothing/shoes/latex_heels/ballet_heels`.
  - Sprites by KittenColony for Bubberstation ([PR #5044](https://github.com/Bubberstation/Bubberstation/pull/5044),
    "Add Ballet Heels"), merged upstream into S.P.L.U.R.T-tg as
    [`968de8f897`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/commit/968de8f8970833bbd0096e2362f3c6d3e98742a5),
    CC BY-SA 3.0. Taken from state `balletheels` of
    `modular_skyrat/modules/modular_items/lewd_items/icons/{obj,mob}/lewd_clothing/lewd_shoes.dmi` and
    `modular_skyrat/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_shoes_digi.dmi` at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
    The boot is drawn over the latex heels of the same sheets, the Skyrat art Nova's ballet heels are made from.
  - Modified: named pointe boots and described anew, as Nova's lace-up heel already carries the name ballet heels;
    a child of Nova's `ballet_heels` (S.P.L.U.R.T's `latex_heels`, renamed and made GAGS by
    [NovaSector #5022](https://github.com/NovaSector/NovaSector/pull/5022)), so they click and colour as the heels
    do. The shape kept to the pixel and made one GAGS greyscale template, state `pointe_boots` in Nova's three
    `lewd_shoes` sheets. Where the boot keeps the latex heels' pixels it takes the greys of Nova's `ballet_heels`
    template (BluBerry016); elsewhere each colour takes the grey Nova gave it, four pixels set by hand. Black stays
    black only in the creases, as on the heels: the toe platforms take the heels' darkest grey, so they colour with
    the rest. Default colour `#383840`, as the ballet heels.
- **Latex half-catsuit.**
  - Code and text from S.P.L.U.R.T-tg's `modular_zubbers/modules/lewd_clothing/latex_halfcatsuit.dm` (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026),
    where it came from Bubberstation ([PR #3508](https://github.com/Bubberstation/Bubberstation/pull/3508),
    CatoChristopherMrow).
  - Sprites by CatoChristopherMrow for Bubberstation
    ([PR #3508](https://github.com/Bubberstation/Bubberstation/pull/3508)), CC BY-SA 3.0: the latex catsuit's sprites
    (StrangeWeirdKitten, [Skyrat-tg #14527](https://github.com/Skyrat-SS13/Skyrat-tg/pull/14527)) with the legs cut
    away. Taken from states `latex_halfcatsuit_female` and `latex_halfcatsuit_male` of
    `modular_skyrat/modules/modular_items/lewd_items/icons/obj/lewd_clothing/lewd_uniform.dmi` and
    `modular_skyrat/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_uniform/lewd_uniform.dmi` at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026);
    the item sprites, the catsuit's own there, are cut to the worn half's V here, the new edges in the icon's outline
    colour.
  - Digitigrade sprites: [Nova Sector](https://github.com/NovaSector/NovaSector)'s digitigrade catsuit,
    `modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_uniform/lewd_uniform-digi.dmi` (CC
    BY-SA 3.0), cut as S.P.L.U.R.T cut the plain one: every row above the hem whole, the V where the plain half has
    it, and in side view the hem's ends on the digitigrade thigh's own front and back edges.
  - Vox and Vox Primalis sprites: the latex catsuit's Vox states by Bloop (Meridian-Rift, "Vox update", `fa441ada5a6`)
    in `modular_nova/master_files/icons/mob/clothing/species/vox/uniform.dmi` and
    `modular_nova/modules/better_vox/icons/clothing/uniform.dmi`, cut by the same rule with the V on each body's own
    crotch; the hand covers (`_hands`) are the catsuit's, unchanged.
  - Teshari sprites by aKromatopzia for Bubberstation
    ([PR #2925](https://github.com/Bubberstation/Bubberstation/pull/2925)), CC BY-SA 3.0: S.P.L.U.R.T's Teshari latex
    catsuit (`latex_catsuit_female` and `latex_catsuit_male` of
    `modular_skyrat/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_uniform/lewd_uniform_teshari.dmi` at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026)),
    cut by the same rule, the new edges in that sprite's own outline colour.
  - Modified: it covers no legs, and another player strips it off in one second, as Nova's catsuit
    ([NovaSector #4913](https://github.com/NovaSector/NovaSector/pull/4913)), where S.P.L.U.R.T's took eight; its
    sprite follows the wearer's body type in `visual_equipped()`, so previews show it. Left out: the breasts overlay,
    which never drew and which #4913 cut from Nova's catsuit; the drag-and-drop plug, as a worn uniform cannot be
    dragged off here; and the 64x32 taur sheet, drawn for Bubberstation's big-legged taurs (`worn_icon_taur_big` at
    the pin), who here wear the plain sprite.
- **Paw mood and cat paws.**
  - Code and text from S.P.L.U.R.T-tg's
    `modular_skyrat/modules/modular_items/lewd_items/code/lewd_clothing/lewd_gloves.dm` (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026),
    where the cat paws are the ball mittens' "Cat Paws" skin and its `loadout_paw` subtype - NanoCats' work for
    Bubberstation ([PR #5664](https://github.com/Bubberstation/Bubberstation/pull/5664), "Ball Mittens: Expanded and
    Enhanced"), merged upstream into S.P.L.U.R.T-tg as
    [`4f36062120`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/commit/4f36062120a254b92b651abc94dcbd97f133e06f).
  - Sprites credited to Onule in the same PR, which redrew the GAGS layers of the cat gloves theselfish added to
    Bubberstation ([PR #4692](https://github.com/Bubberstation/Bubberstation/pull/4692); its code calls them
    "seemingly by Taomayo of MonkeStation"), CC BY-SA 3.0. Taken from states `catglove`, `catglove_paws` and
    `catgloves_tag` of `modular_skyrat/modules/GAGS/icons/catglove{,_worn}.dmi` at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Modified: their own GAGS type, a child of Nova's paw mittens, named cat paws where S.P.L.U.R.T's were latex paw
    mittens. Not a reskin of the ball mittens, so they stay Nova's full restraint and players colour them as any
    GAGS item, without the skin's own spray-paint menu. No accent light: its switch, a link in the examine text,
    checked only that the paws were worn, so under Nova's full restraint it would either slip the restraint or never
    work. The three states renamed for Nova's sheets and their greys moved onto the paw mittens' ramp, the worn tag
    a plain state where S.P.L.U.R.T's was a movement state. The paw mood's text without its trailing line break.
- **R.U.T.T.**
  - Code and text from S.P.L.U.R.T-tg's `modular_zzplurt/code/modules/lewd/lewd_chemistry/reagents/rutt.dm` and the
    dopamine reaction in `modular_zzplurt/code/modules/lewd/lewd_chemistry/reagents/dopamine.dm` (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Nothing imported: the bottle is tg's, and the pill wears Nova's `dopamine` pill state.
  - Modified: its effects run in `life_effects()` behind the aphrodisiac preference, as Nova's crocin's do, in place
    of S.P.L.U.R.T's own preference checks; the 10u pill is named so, where S.P.L.U.R.T's said 25u; and "You can't
    stop cumming!" follows only a climax that went through at once, where S.P.L.U.R.T's also followed one the
    preferences refused. Left out: the flag that let R.U.T.T. be synthesized, which would put it in random pills and
    the Odysseus' syringe gun (Nova's aphrodisiacs go without it), and S.P.L.U.R.T's new name and description for
    dopamine, which Nova's own reagent keeps.
- **Denbu tincture.**
  - Code and text from S.P.L.U.R.T-tg's `modular_zzplurt/code/modules/lewd/lewd_chemistry/reagents/butt_enlarger.dm`,
    the butt parts of `modular_zzplurt/code/modules/lewd/lewd_chemistry/reagents/_aphrodisiac.dm` and
    `modular_zzplurt/code/modules/lewd/lewd_chemistry/reagents/camphor.dm`, the bottle in
    `modular_zzplurt/code/modules/lewd/lewd_chemistry/items/bottles.dm`, and the butt enlargement preference in
    `modular_zzplurt/code/modules/client/preferences/erp_preferences.dm` with its toggle in
    `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/game_preferences/splurt/erp_preferences.tsx`
    (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Nothing imported: the bottle is tg's, and a grown butt wears Nova's butt sprites.
  - Modified: a new butt is first named "Pair" in the DNA, as Nova's `create_breasts()` names its breasts, where
    S.P.L.U.R.T's left the DNA as it was, so a player's new butt kept the DNA's "None" and drew nothing (a mob with no
    entry got a random sprite); it starts at size 1, the smallest drawn, where S.P.L.U.R.T's started at 0, which draws
    nothing; the strain bruises the chest, where S.P.L.U.R.T's hit a random limb; and the growth message comes once to
    the taker and to onlookers with ERP on. Left out: the butt shrinkage preference and its procs, which nothing in
    S.P.L.U.R.T called.
- **Bridle.**
  - Code and text by ibexgoetia for Bubberstation
    ([PR #5162](https://github.com/Bubberstation/Bubberstation/pull/5162), "Horse bridles"), from S.P.L.U.R.T-tg's
    `modular_zubbers/code/modules/lewd_machinery/bridle.dm` and its button in
    `tgui/packages/tgui/interfaces/StripMenu.tsx` (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Sprites by ibexgoetia in the same PR, brought to S.P.L.U.R.T-tg in its upstream update
    ([PR #813](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/813)), CC BY-SA 3.0. Taken from
    `modular_zubbers/icons/obj/clothing/mask/mask.dmi` (`bridle`) and
    `modular_zubbers/icons/mob/clothing/mask/mask.dmi` (`bridle`, `bridle_blinders`) at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Modified: made GAGS in three colours, each state split into layers appended to Nova's `lewd_masks.dmi` pair
    (`bridle_strap`, `bridle_blinders_up`, `bridle_blinders_down`, `bridle_fittings`), the shapes kept to the pixel
    and the browns and steels moved onto Nova's template greys. The muzzled worn states in `lewd_masks_muzzled.dmi`
    are adapted from the plain ones: south and north unchanged, east and west with the cheek ring, drop strap and bit
    ring 2 px forward along the snout. The bit muffles through tg's `muffles_speech` element, which S.P.L.U.R.T
    copied, so it also stops spoken spells; S.P.L.U.R.T's pass for horse emotes is left out, as Nova has none. One
    mode serves the buttons, alt-click and the strip menu, and each move is told once, where some of S.P.L.U.R.T's
    were told twice. It can't be put on, or adjusted from the strip menu on, a player who does not take sex toys, nor
    adjusted there by one who does not take part in ERP, which S.P.L.U.R.T did not check; the strip-menu step warns
    the wearer and onlookers and is logged; and it is in the Erotic loadout, where S.P.L.U.R.T put it in the mask
    loadout.
- **Lustwish MOD suit.**
  - Code and text from S.P.L.U.R.T-tg (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026):
    `modular_zubbers/code/modules/mod/modules_lustwish.dm`, the lustwish theme in
    `modular_zubbers/code/modules/mod/mod_theme.dm` and `tgui/packages/tgui/interfaces/MODsuitremote.tsx`, which came
    from Bubberstation: StrangeWeirdKitten's [PR #4218](https://github.com/Bubberstation/Bubberstation/pull/4218) (the
    suit and the visor) and [PR #4328](https://github.com/Bubberstation/Bubberstation/pull/4328) (the remote),
    MintyPhresh's [PR #5110](https://github.com/Bubberstation/Bubberstation/pull/5110),
    [PR #5220](https://github.com/Bubberstation/Bubberstation/pull/5220) and
    [PR #5387](https://github.com/Bubberstation/Bubberstation/pull/5387) (the visor's toggle and settings), and
    NanoCats' [PR #6251](https://github.com/Bubberstation/Bubberstation/pull/6251) (the purple hardlight).
  - Sprites by Toriate, commissioned by StrangeWeirdKitten for Bubberstation
    ([PR #4218](https://github.com/Bubberstation/Bubberstation/pull/4218)), and the remote's, added with it in
    [PR #4328](https://github.com/Bubberstation/Bubberstation/pull/4328), which names no artist; CC BY-SA 3.0. Taken
    unchanged into `icons/lustwish_mod.dmi` and `icons/lustwish_mod_worn.dmi` from
    `modular_zubbers/icons/obj/clothing/modsuit/mod_lustwish.dmi`,
    `modular_zubbers/icons/mob/clothing/modsuit/mod_lustwish.dmi` and
    `modular_zubbers/icons/mob/clothing/modsuit/mod_modules.dmi` at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
    The remote's inhand is tg's `electronic`.
  - Digitigrade and snouted sprites drawn for this codebase, CC BY-SA 3.0, in `icons/lustwish_mod_worn_mutant.dmi`:
    `lustwish-helmet` and `lustwish-helmet-sealed` (snouted), `lustwish-chestplate`, `lustwish-chestplate-sealed`,
    `lustwish-boots` and `lustwish-boots-sealed` (digitigrade). Made from Toriate's plain states above, fitted to the
    digitigrade legs and snout of Nova's `civilian-*` states in
    `modular_nova/master_files/icons/mob/clothing/modsuit/mod_clothing_mutant.dmi`: the helmets' chin one row deeper
    in front (the civilian snouted helmet's muzzle cup); the boots on the digitigrade thighs and knee, and in side
    view as two boots on the spread legs, with the civilian digitigrade boots' feet. The chestplates are the plain
    states: the leotard ends above the legs.
  - Modified: the hypnosis is the goggles' status effect, where S.P.L.U.R.T's gave the `induced_hypnosis` brain trauma
    Nova removed, and is gated, as the goggles are, on the sex-toy preference, where S.P.L.U.R.T's also read a
    hypnosis preference this codebase lacks; the remote drives the suit only for a wearer who takes sex toys and a
    holder who takes part in ERP, checked on the server where S.P.L.U.R.T's only greyed out the emote field, only
    within seven tiles on the same z-level where S.P.L.U.R.T's reached anywhere, and only the suit's activation,
    parts, modules and lock, where S.P.L.U.R.T's passed on every action of the suit's window, its MODlink calls, pAI
    eject and pinned buttons included; its forced emote is refused as the me verb and the custom emote refuse the
    holder's own words (admin-disabled speech, an emote ban, an IC mute, the IC filters, which refuse a soft-filtered
    word where the custom emote asks, and an admin's words too) and sanitised as the me verb sanitises them; off the
    lustwish skin the visor keeps its spiral setting but draws nothing and hides the setting, where S.P.L.U.R.T's
    switched it off when installed, and a snipped visor takes no settings. Left out: the remote's Protean controls, as
    Nova's Protean has no such interface, and the pre-equipped lustwish suit, which nothing in S.P.L.U.R.T spawned.
