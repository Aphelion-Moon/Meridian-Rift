## Adult items

Module ID: ADULT_ITEMS

### Description:

Adult items ported from S.P.L.U.R.T. One family per file in `code/`, with its own icon sheets in `icons/` and its own
line under Credits. Every item has an `Initialize()` stanza in Nova's `_erp_disabled_item_enforcement.dm`, so the
lewd-items config removes it. Items that fit the box of love carry `obj_flags_nova = ERP_ITEM`, as their Nova
neighbours do, and each family reaches players through the same vendor or loadout as its Nova neighbours.

- **Medipens** (`code/medipens.dm`). Five one-shot 30u medipens under the abstract
  `/obj/item/reagent_containers/hypospray/medipen/lewd`: crocin, hexacrocin, succubus milk, incubus draft, and the
  La Coom Bomb (10u each of hexacrocin, succubus milk and incubus draft). Each has a spent sprite. The lewd medipen
  box (`/obj/item/storage/box/medipens/lewd`) holds one of each; its sprite is Nova's medical box with its own
  illustration drawn on. LustWish sells the crocin, succubus milk and incubus draft pens beside its lewd bottles and,
  once hacked, the hexacrocin pen, the La Coom Bomb and the box beside its hexacrocin stock. Every pen and the box also
  has an entry in the Erotic loadout, beside the lewd bottles, pills and neuroware boxes.

### Modular Overrides:

- `modular_nova/modules/loadouts/loadout_items/loadout_datum_erp.dm`: the pens and the box in the Erotic loadout.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/_erp_disabled_item_enforcement.dm`: `Initialize()`
  of `/obj/item/reagent_containers/hypospray/medipen/lewd` and `/obj/item/storage/box/medipens/lewd`.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_machinery/lustwish.dm`: the pens and the box in the
  LustWish stock.

### Included files that are not contained in this module:

- `code/modules/unit_tests/~nova/lewd_medipens.dm`: the medipens' unit test.

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
