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
- **Leash line** (in Nova's `leash.dm`). While Nova's leash is hooked, a line in the colour of its strap runs from the
  hand holding it to the leashed. It is blank while a wall or a window stands between the two, or while either is
  inside something or on another z-level, and drawn again once they are back in reach; unhooking takes it away.
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

### TG Proc/File Changes:

- `icons/map_icons/clothing/shoes.dmi`: the pointe boots' map icon, as `SSgreyscale_previews` generates it.
- `icons/map_icons/clothing/_clothing.dmi`: the cat paws' map icon, as `SSgreyscale_previews` generates it.

### Modular Overrides:

- `modular_nova/modules/GAGS/nsfw/gloves.dm` and
  `modular_nova/modules/GAGS/nsfw/json_configs/clothing/gloves/cat_paws.json` (new): the cat paws' GAGS configs,
  after the paw mittens'.
- `modular_nova/modules/GAGS/nsfw/shoes.dm` and
  `modular_nova/modules/GAGS/nsfw/json_configs/clothing/shoes/pointe_boots.json` (new): the pointe boots' GAGS
  configs, after the ballet heel's.
- `modular_nova/modules/loadouts/loadout_items/loadout_datum_erp.dm`: the pens, the medipen box, the condom box, the
  paw mittens and the cat paws in the Erotic loadout.
- `modular_nova/modules/loadouts/loadout_items/loadout_datum_shoes.dm`: the pointe boots in the shoes loadout.
- `modular_nova/modules/loadouts/loadout_items/under/loadout_datum_under.dm`: the latex half-catsuit in the under
  loadout, after the catsuit.
- `modular_nova/modules/modular_implants/code/nifsofts/dorms.dm`: the pointe boots and the latex half-catsuit in the
  Grimoire Libidine NIFSoft.
- `modular_nova/modules/modular_items/lewd_items/code/clothing_pref_check.dm`: Nova's paw mittens and the cat paws
  in the sex-toy preference check.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/lewd_gloves.dm`: the paw mood on the paw
  mittens, and the cat paws.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/lewd_shoes.dm`: the pointe boots.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/_erp_disabled_item_enforcement.dm`: `Initialize()`
  of `/obj/item/reagent_containers/hypospray/medipen/lewd`, `/obj/item/storage/box/medipens/lewd`,
  `/obj/item/storage/box/condoms`, `/obj/item/clothing/shoes/ballet_heels/pointe_boots` and
  `/obj/item/clothing/under/misc/latex_halfcatsuit`.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/fleshlight.dm`: the bluespace fleshlight.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/leash.dm`: the leash line.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_machinery/lustwish.dm`: the pens, the medipen box, the
  condom box, the bluespace fleshlight, the pointe boots, the latex half-catsuit and the cat paws in the LustWish
  stock.
- `modular_nova/modules/modular_items/lewd_items/icons/{obj,mob}/lewd_clothing/lewd_gloves.dmi`: the cat paws'
  greyscale template, states `catpaws`, `catpaws-pawpad` and `catpaws-tag`, after the existing states.
- `modular_nova/modules/modular_items/lewd_items/icons/{obj,mob}/lewd_clothing/lewd_shoes.dmi` and
  `modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_shoes_digi.dmi`: the pointe boots'
  greyscale template, state `pointe_boots`, after the existing states.

### Defines:

- `code/__DEFINES/~aphelion_defines/adult_items.dm`: `TEST_SKIP_IF_LEWD_ITEMS_DISABLED`, the first line of every
  family's unit test - it ends the test with a notice when lewd items are disabled.

### Included files that are not contained in this module:

- `code/modules/unit_tests/~nova/adult_items_kill_switch.dm`: the lewd-items config test for every family.
- `code/modules/unit_tests/~nova/lewd_medipens.dm`: the medipens' unit test.
- `code/modules/unit_tests/~nova/condom_box.dm`: the condom box's unit test.
- `code/modules/unit_tests/~nova/bluespace_fleshlight.dm`: the bluespace fleshlight's unit test.
- `code/modules/unit_tests/~nova/leash_line.dm`: the leash line's unit test.
- `code/modules/unit_tests/~nova/latex_halfcatsuit.dm`: the latex half-catsuit's unit test.
- `code/modules/unit_tests/~nova/paw_mittens_mood.dm`: the paw mood's unit test.

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
- **Leash line.**
  - Behaviour from S.P.L.U.R.T-tg's `modular_skyrat/modules/modular_items/lewd_items/code/lewd_items/leash.dm`
    (AGPL-3.0), at
    [`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026).
  - Nothing imported: the line is tg's `fishing_line` beam state.
  - Modified: drawn on tg's held beam with the borg vacuum hose's hand offsets (`/datum/beam/held/vacuum`) instead of
    S.P.L.U.R.T's copy of the fishing line's beam with every offset at zero; coloured as the leash's strap, where
    S.P.L.U.R.T's was always purple; owned by the leash component, so it also goes when the leashed breaks free; and
    blank only while out of reach, inside something or on another z-level - S.P.L.U.R.T's never came back once the
    two were out of reach.
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
