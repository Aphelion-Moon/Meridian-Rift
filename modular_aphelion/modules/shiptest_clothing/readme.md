# Shiptest clothing

Clothing from Shiptest, as cosmetic garments. Replica armour, HUD lenses, gas masks and camouflage cloaks look the part but have none of their Shiptest abilities; jackets still open, hoods go up, masks adjust, the shemagh ties into a face wrap, the headlamp lights, and webbing, bags and coat pockets hold things.

Source: [Shiptest](https://github.com/shiptest-ss13/Shiptest/tree/9847a9e95648c4959c19910357a2a3abe8f37da2), commit `9847a9e95648c4959c19910357a2a3abe8f37da2`, by Shiptest's contributors and the upstream artists credited in that repository. The trenchcoats and capsule jacket come from [PR #6985](https://github.com/shiptest-ss13/Shiptest/pull/6985), authored by Erikafox with changelog credits to Erika and Imaginos. Source code is AGPL-3.0; artwork is [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) per [Shiptest's asset license](https://github.com/shiptest-ss13/Shiptest/blob/9847a9e95648c4959c19910357a2a3abe8f37da2/README.md#license). The artwork here stays under that license.

- Loadout - every garment is in the loadout (`code/loadout.dm`); garments that differ only in colour or design share one entry, named after the garment.
- Styles - those garments are styles of each other on tg's reskin component (`code/styles.dm`), picked with Alt-click or in the loadout; the recolourable ones take any colour in the GAGS editor (`code/greyscale.dm`).
- Vending - every garment is also its own product in the ClothesMate, AutoDrobe or MediDrobe (`modular_nova/modules/modular_vending/code/`).
