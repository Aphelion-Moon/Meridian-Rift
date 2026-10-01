## Chastity devices

Module ID: CHASTITY

### Description:

Lockable chastity cages, belts and plates, ported from Ratwood-2.0 (less their spiked ones) and rebuilt on Nova's
lewd slots, plus chrome and industrial station designs. A device goes into the penis or vagina slot through the
interaction menu like any toy, and needs the wearer's "Chastity devices" preference.

While worn, a device:

- closes genitals off: interactions that need them are refused and no other toy fits them, and a caged penis
  can't make a bulge;
- draws in place of the genital it sits over, through `device_state` on the genital's bodypart overlay, so it shows,
  hides under clothes and underwear, and layers exactly as that genital would. Full belts and plates also cover the
  testicles;
- sends the wearer internal-monologue flavour text now and then while they're aroused, and when a partner does
  something lewd to them.

Each device comes with its key tucked inside (use the device in hand to slide it out); the key locks and unlocks it
on the wearer or in hand, like Nova's collar keys. A screwdriver on the wearer's groin can pick a locked device open,
breaking its lock, unless the wearer set "Chastity: key only". The cursed device has no keyhole: it clamps shut
when fitted and only a bible or null rod pressed to it lets it off.

Interactions can require `self_caged`/`target_caged` (penis closed off) or `self_belted`/`target_belted` (vagina
closed off), and use `%USER_DEVICE%`/`%TARGET_DEVICE%` for the device's name.

Flavour text lives in `strings/aphelion/chastity.json`.

### Credits:

Device sprites and flavour text: Ratwood-2.0 contributors (`modular/icons/obj/lewd/chastity*.dmi`,
`modular/code/game/objects/items/lewd/chastity/strings/`). Worn sprites refitted to our bodies.
