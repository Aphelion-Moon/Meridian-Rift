## Adult items

Module ID: ADULT_ITEMS

### Description:

Adult items ported from S.P.L.U.R.T. A family with no Nova counterpart gets its own file in `code/`, with its own
icon sheets in `icons/`, while an addition to a Nova family goes in that family's Nova file. Each family has its own
line under Credits. Every item has an `Initialize()` stanza in Nova's `_erp_disabled_item_enforcement.dm`, so the
lewd-items config removes it, and every family lists its top types on one line of `adult_items_gated_types()` in
`code/_gated_types.dm` - a new family adds its line there. The `adult_items_kill_switch` unit test makes every
concrete type under them and fails on any that survives with lewd items disabled or does not spawn with them enabled.
Items that fit the box of love carry `obj_flags_nova = ERP_ITEM`, as their Nova neighbours do, and each family
reaches players through the same vendor or loadout as its Nova neighbours.

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

### TG Proc/File Changes:

- `icons/map_icons/clothing/shoes.dmi`: the pointe boots' map icon, as `SSgreyscale_previews` generates it.

### Modular Overrides:

- `modular_nova/modules/GAGS/nsfw/shoes.dm` and
  `modular_nova/modules/GAGS/nsfw/json_configs/clothing/shoes/pointe_boots.json` (new): the pointe boots' GAGS
  configs, after the ballet heel's.
- `modular_nova/modules/loadouts/loadout_items/loadout_datum_erp.dm`: the pens, the medipen box and the condom box in
  the Erotic loadout.
- `modular_nova/modules/loadouts/loadout_items/loadout_datum_shoes.dm`: the pointe boots in the shoes loadout.
- `modular_nova/modules/modular_implants/code/nifsofts/dorms.dm`: the pointe boots in the Grimoire Libidine NIFSoft.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/lewd_shoes.dm`: the pointe boots.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/_erp_disabled_item_enforcement.dm`: `Initialize()`
  of `/obj/item/reagent_containers/hypospray/medipen/lewd`, `/obj/item/storage/box/medipens/lewd`,
  `/obj/item/storage/box/condoms` and `/obj/item/clothing/shoes/ballet_heels/pointe_boots`.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/fleshlight.dm`: the bluespace fleshlight.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/leash.dm`: the leash line.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_machinery/lustwish.dm`: the pens, the medipen box, the
  condom box, the bluespace fleshlight and the pointe boots in the LustWish stock.
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
