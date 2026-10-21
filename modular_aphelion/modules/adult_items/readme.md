## Adult items

Module ID: ADULT_ITEMS

### Description:

Adult items ported from S.P.L.U.R.T. A new item family gets its own file in `code/` and icons in `icons/`; an addition
to an existing lewd family goes in that family's file. The lewd items config removes every item
(`_erp_disabled_item_enforcement.dm`), and the `adult_items_kill_switch` unit test checks the top types each family lists
in `adult_items_gated_types()` (`code/_gated_types.dm`). A new family adds its line there.

- **Medipens** (`code/medipens.dm`). Five single-use 30u medipens: crocin, hexacrocin, succubus milk, incubus draft, and
  the La Coom Bomb (10u each of the last three), plus a box with one of each. LustWish sells them (the hexacrocin pen,
  the La Coom Bomb and the box once hacked), and they're in the Erotic loadout.
- **Condom box** (`code/condom_box.dm`). Ten condom packs, and it only holds condom packs. LustWish and the Erotic
  loadout.
- **Bluespace fleshlight** (`fleshlight.dm`). Catches an immovable rod, which flings the user up to 12 tiles along its
  path to a soft landing. A wizard in rod form is set down unharmed. A premium LustWish item at ten command paychecks.
- **Leash** (`leash.dm`). The leashed follows the holder's route a step at a time: round corners and hazards, through
  doors, up and down stairs. Where they can't follow, the leash goes taut and holds the holder at two tiles. A leashed
  who falls drags their holder to the hole after a moment to let go. A dropped leash stays hooked and trails the leashed,
  and anyone their sex toy preference allows can pick it up. It unhooks when the holder uses it on the leashed, when the
  leashed breaks free, or with the safeword. A line in the strap's colour runs from the holding hand, or from the leash
  on the floor, while the two are in reach.
- **Pointe boots** (`lewd_shoes.dm`). Ballet heels with the feet held en pointe, GAGS, with digitigrade sprites.
  LustWish, the shoes loadout and the Grimoire Libidine NIFSoft.
- **Latex half-catsuit** (`code/latex_halfcatsuit.dm`). The latex catsuit without the legs. It picks its male or female
  sprite by body type, previews included, and has digitigrade, Vox, Vox Primalis and Teshari sprites. Unlike the
  catsuit, it doesn't bulge or hide the wearer's parts or taur body. LustWish, the under loadout and the Grimoire
  Libidine NIFSoft.
- **Paw mood and cat paws** (`lewd_gloves.dm`). Paw mittens give the paw mood while worn. The cat paws are bigger GAGS
  paw mittens with toe beans and a cuff tag. Both need the sex toy preference. LustWish and the Erotic loadout.
- **R.U.T.T.** (`code/rutt.dm`). A much stronger aphrodisiac than hexacrocin that can cause climaxes, behind the
  aphrodisiac preference. Mixes from crocin, dopamine, femcum and epinephrine at 322K. Dopamine, which only came from
  climaxing, now mixes from diethylamine, ephedrine, hydrogen and phenol at 373K. The bottle and pill are in a hacked
  LustWish and the Erotic loadout.
- **Denbu tincture** (`code/butt_enlarger.dm`). Grows the butt up to the largest pickable size, behind a new butt
  enlargement preference, and grows one on players who allow new genital growth. Clothes strain and hurt over the last
  two sizes. A camphor overdose moves the butt back to its preference size. Mixes from saline-glucose, sugar, silicon and
  crocin. LustWish and the Erotic loadout.
- **Bridle** (`code/bridle.dm`). A three-colour GAGS bridle. Lowered blinders darken sight like a welding mask, and a set
  bit muffles speech, emotes and spoken spells. Toggled with action buttons or alt-click, or from the strip menu by
  someone with ERP on, if the wearer has the sex toy preference on; that warns the wearer and is logged. Securing the
  straps locks it. LustWish and the Erotic loadout.
- **Lustwish MOD suit** (`code/lustwish_mod.dm`). The standard MOD suit in LustWish's skin, with a purple hardlight. The
  hypnotic visor module hypnotizes the wearer like the hypnotic goggles, while on, or always once its wire is cut. The
  remote control module comes with a remote that controls the suit from up to seven tiles away: activation, parts,
  modules, lock and forced emotes. The visor needs the wearer's sex toy preference; the remote needs that and the
  holder's ERP preference. Sold in LustWish's MOD Suit category.
  - Known issue: a forced emote starting with "says", "exclaims", "yells" or "asks" shows the wearer "Invalid emote."
    and tells the holder nothing, because the custom emote's own check (`emote_is_valid()`) judges the wearer.

### TG Proc/File Changes:

- `icons/map_icons/clothing/shoes.dmi`, `_clothing.dmi` and `mask.dmi`: map icons for the pointe boots, cat paws and
  bridle.
- `tgui/packages/tgui/interfaces/StripMenu.tsx`: the "Adjust bridle" button.

### Modular Overrides:

- `modular_nova/master_files/code/modules/client/preferences/erp_preferences.dm`: the butt enlargement preference.
- `modular_nova/modules/GAGS/nsfw/gloves.dm`, `masks.dm` and `shoes.dm`, with new JSON configs: the cat paws', bridle's
  and pointe boots' GAGS configs.
- `modular_nova/modules/loadouts/loadout_items/loadout_datum_erp.dm`, `loadout_datum_shoes.dm` and
  `under/loadout_datum_under.dm`: loadout entries.
- `modular_nova/modules/modular_implants/code/nifsofts/dorms.dm`: the pointe boots and half-catsuit in the Grimoire
  Libidine NIFSoft.
- `modular_nova/modules/modular_items/lewd_items/code/clothing_pref_check.dm`: the paw mittens, cat paws and bridle need
  the sex toy preference.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_chemistry/reagents/_aphrodisiac.dm`: preference checks read
  the player through `GET_CLIENT`.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_chemistry/reagents/camphor.dm`: an overdose resets the butt
  size.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_chemistry/reagents/dopamine.dm`: the overdose message and mood
  only for players with aphrodisiacs on.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/hypnogoggles.dm`: the hypnosis is the
  `hypnotic_phrase` status effect, shared with the MOD visor. It ends when the goggles are deleted, and its hallucinated
  whisper is started properly.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/lewd_gloves.dm`: the paw mood and the cat paws.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_clothing/lewd_shoes.dm`: the pointe boots.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/_erp_disabled_item_enforcement.dm`: lewd items config
  entries for every new item.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/fleshlight.dm`: the bluespace fleshlight.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_items/leash.dm`: the leash's pull and line.
- `modular_nova/modules/modular_items/lewd_items/code/lewd_machinery/lustwish.dm`: the LustWish stock, with a MOD Suit
  category.
- `modular_nova/modules/modular_items/lewd_items/icons/`: GAGS templates for the cat paws (`lewd_gloves.dmi`), bridle
  (`lewd_masks.dmi`, `lewd_masks_muzzled.dmi`) and pointe boots (`lewd_shoes.dmi`, `lewd_shoes_digi.dmi`).
- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/game_preferences/nova/erp_preferences.tsx`: the
  butt enlargement toggle.

### Defines:

- N/A

### Included files that are not contained in this module:

- `code/modules/unit_tests/~nova/adult_items_kill_switch.dm`: the lewd items config test for every family.
- `tgui/packages/tgui/interfaces/MODsuitRemote.tsx`: the MOD remote's window.

### Credits:

Code is from S.P.L.U.R.T-tg (AGPL-3.0) and sprites are CC BY-SA 3.0, both at
[`ad77f89e2fa`](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/tree/ad77f89e2fafe5156601fe8224a662a31ed0d026) unless
noted.

- **Medipens.** Code: `modular_zzplurt/code/modules/modular_items/lewd_items/code/medipens.dm`. Pen and inhand sprites by
  MosleyTheMalO (S.P.L.U.R.T-Station-13 [#434](https://github.com/SPLURT-Station/S.P.L.U.R.T-Station-13/pull/434),
  brought over by Krashly in [#65](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/65)), recolours of tg's
  medipen. The box is `medbox` and the `epipen` illustration from
  `modular_nova/modules/aesthetics/storage/icons/storage.dmi` (TauCeti station and Gandalf2k15). Modified: pens
  recoloured to the lewd portals' plum, the La Coom Bomb's animation retimed, and the illustration drawn onto the box as
  `medbox_lewd`.
- **Condom box.** Code: `modular_zzplurt/code/modules/modular_items/lewd_items/code/condom_box.dm`. Sprite: `hugbox` from
  `modular_nova/modules/aesthetics/storage/icons/storage.dmi` (TauCeti station and Gandalf2k15) with an original condom
  label. Modified: its own storage datum, so it takes condom packs back.
- **Bluespace fleshlight.** Code: `modular_skyrat/modules/modular_items/lewd_items/code/lewd_items/fleshlight.dm`. No
  sprites imported. Modified: the user is flung along the rod's path and lands softly, a wizard in rod form is set down
  instead of deleted, and it's a premium item instead of contraband.
- **Leash.** The pull, hold, drag and dropped leash are original (mal, 2026-10-12). The line is from
  `modular_skyrat/modules/modular_items/lewd_items/code/lewd_items/leash.dm`, drawn with tg's `fishing_line` beam.
  Modified: it leaves the holding hand, takes the strap's colour, goes with the leash component and comes back once in
  reach.
- **Pointe boots.** Code: `modular_skyrat/modules/modular_items/lewd_items/code/lewd_clothing/lewd_shoes.dm`. Sprites by
  KittenColony (Bubberstation [#5044](https://github.com/Bubberstation/Bubberstation/pull/5044)), state `balletheels`.
  Modified: renamed pointe boots and made a GAGS subtype of the ballet heels, on the greys of BluBerry016's heels
  template.
- **Latex half-catsuit.** Code: `modular_zubbers/modules/lewd_clothing/latex_halfcatsuit.dm`, from Bubberstation
  [#3508](https://github.com/Bubberstation/Bubberstation/pull/3508) (CatoChristopherMrow). Sprites by
  CatoChristopherMrow, cut from StrangeWeirdKitten's latex catsuit (Skyrat-tg
  [#14527](https://github.com/Skyrat-SS13/Skyrat-tg/pull/14527)). The digitigrade, Vox and Vox Primalis sprites are cut
  from the catsuit's the same way (Vox by Bloop); Teshari sprites by aKromatopzia (Bubberstation
  [#2925](https://github.com/Bubberstation/Bubberstation/pull/2925)). Modified: strips in one second, and picks its
  sprite by body type. Left out: the breasts overlay, the drag-and-drop plug and the big taur sheet.
- **Paw mood and cat paws.** Code: `modular_skyrat/modules/modular_items/lewd_items/code/lewd_clothing/lewd_gloves.dm`,
  NanoCats' work for Bubberstation [#5664](https://github.com/Bubberstation/Bubberstation/pull/5664). Sprites credited
  to Onule there, redrawn from theselfish's cat gloves (Bubberstation
  [#4692](https://github.com/Bubberstation/Bubberstation/pull/4692)). Modified: a GAGS paw mittens subtype instead of a
  ball mittens reskin, on the paw mittens' greys, without the accent light.
- **R.U.T.T.** Code: `modular_zzplurt/code/modules/lewd/lewd_chemistry/reagents/rutt.dm` and the dopamine reaction in
  `dopamine.dm`. No sprites imported. Modified: behind the aphrodisiac preference, the pill labelled 10u, and "You can't
  stop cumming!" only after a real climax. Left out: making it synthesizable, and the dopamine rename.
- **Denbu tincture.** Code: `modular_zzplurt/code/modules/lewd/lewd_chemistry/reagents/butt_enlarger.dm`, the butt parts
  of `_aphrodisiac.dm` and `camphor.dm`, the bottle, and the butt enlargement preference with its toggle. No sprites
  imported. Modified: a new butt is set to "Pair" and starts at size 1 so it draws, strain hurts the groin, and the
  growth message shows once. Left out: the unused butt shrinkage preference.
- **Bridle.** Code by ibexgoetia (Bubberstation [#5162](https://github.com/Bubberstation/Bubberstation/pull/5162)), from
  `modular_zubbers/code/modules/lewd_machinery/bridle.dm` and its `StripMenu.tsx` button. Sprites by ibexgoetia
  (S.P.L.U.R.T-tg [#813](https://github.com/SPLURT-Station/S.P.L.U.R.T-tg/pull/813)). Modified: three-colour GAGS with
  muzzled sprites, one mode for the buttons, alt-click and strip menu, preference checks, strip menu warnings and logs,
  and moved to the Erotic loadout. Left out: the horse emote passthrough.
- **Lustwish MOD suit.** Code: `modular_zubbers/code/modules/mod/modules_lustwish.dm`, the theme in `mod_theme.dm` and
  `MODsuitremote.tsx`, from Bubberstation: StrangeWeirdKitten
  ([#4218](https://github.com/Bubberstation/Bubberstation/pull/4218),
  [#4328](https://github.com/Bubberstation/Bubberstation/pull/4328)), MintyPhresh
  ([#5110](https://github.com/Bubberstation/Bubberstation/pull/5110),
  [#5220](https://github.com/Bubberstation/Bubberstation/pull/5220),
  [#5387](https://github.com/Bubberstation/Bubberstation/pull/5387)) and NanoCats
  ([#6251](https://github.com/Bubberstation/Bubberstation/pull/6251)). Sprites by Toriate, commissioned by
  StrangeWeirdKitten (#4218); the remote's are from #4328, artist unnamed. The digitigrade and snouted sprites in
  `lustwish_mod_worn_mutant.dmi` were drawn here from Toriate's, fitted to the civilian suit's mutant sprites. Modified:
  the hypnosis uses the goggles' status effect and preference, and the remote checks preferences on the server, has a
  seven tile range, only reaches activation, parts, modules and lock, and follows the me verb's rules for emotes. Left
  out: the remote's Protean controls and the unused pre-equipped suit.
