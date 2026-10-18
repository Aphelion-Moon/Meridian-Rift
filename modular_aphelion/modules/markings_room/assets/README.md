# Markings room assets

The textures and fonts of the Augments+ rooms, every theme's. They aren't in tgui's bundle, which every tgui window
loads. `/datum/asset/simple/markings_room` (`code/markings_room.dm`) sends them with the preferences window, together
with a stylesheet it writes when it registers. That stylesheet declares each texture as a custom property on the room,
`--mr-<file name without extension>`, and each font as a face. The rooms' styles (`tgui/.../styles/meridianos/`) read a
texture as `var(--mr-<name>, none)`. The few pixel props of a kilobyte or so stay inline in the bundle
(`styles/meridianos/assets/markings/`).

`code/markings_room_assets.dm` lists these files. The lab's themes-impl run writes both, with `tools/room_assets.py`,
from the rooms' styles.

The Foundry window theme draws with six of them: `foundry-cave.jpg`, `foundry-steel.webp`, `forge-wear.webp`,
`foundry-hide.jpg`, `CaesarDressing-400.woff2` and `Macondo-400.woff2`. Its art asset
(`meridian_ui/code/art_stylesheet.dm`) sends the same files under this asset's names, so a client fetches and keeps
each once: renaming or moving one means changing it there too.

## Textures

Everything in `textures/` is original and procedurally generated for the room mockups, from value noise with fixed
seeds: the club's tiles and grime by `club_textures.py`, every other theme's by `prep_themes.py`, and the pixel props
by `pixel_props.py` (all in the lab). Nothing third-party goes into them. The exceptions are `scavenger-rust.jpg` and
`hephaestus-gunmetal.jpg`, which are the MeridianOS theme textures of the same names
(`tgui/packages/tgui/styles/meridianos/assets/`).

A texture ships as whichever is smallest of three:

- its source;
- a lossless PNG or WebP;
- a WebP or re-encoded JPEG that keeps it: 42 dB PSNR against the source, and its fine detail within 5%.

Pixel art is only ever lossless.

## Fonts

| File | Family | Source | Licence |
| --- | --- | --- | --- |
| `Rye-Latin-Regular.woff2` | Rye | Google Fonts, latin subset, unmodified | SIL OFL 1.1, reserved name "Rye" (`licences/Rye-OFL.txt`) |
| `PermanentMarker-Latin-Regular.woff2` | Permanent Marker | Google Fonts, latin subset, unmodified | Apache 2.0 (`licences/PermanentMarker-LICENSE.txt`) |
| `CaesarDressing-400.woff2` | Caesar Dressing | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/CaesarDressing-OFL.txt`) |
| `AtkinsonHyperlegible-400.woff2`, `-700` | Atkinson Hyperlegible | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/AtkinsonHyperlegible-OFL.txt`) |
| `Macondo-400.woff2` | Macondo | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/Macondo-OFL.txt`) |
| `Michroma-400.woff2` | Michroma | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/Michroma-OFL.txt`) |
| `Monoton-400.woff2` | Monoton | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/Monoton-OFL.txt`) |
| `Neonderthaw-400.woff2` | Neonderthaw | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/Neonderthaw-OFL.txt`) |
| `Rajdhani-600.woff2`, `-700` | Rajdhani | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/Rajdhani-OFL.txt`) |
| `ShareTechMono-400.woff2` | Share Tech Mono | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/ShareTechMono-OFL.txt`) |
| `StardosStencil-700.woff2` | Stardos Stencil | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/StardosStencil-OFL.txt`) |
| `Syncopate-700.woff2` | Syncopate | Google Fonts, latin subset, unmodified | Apache 2.0 (`licences/Syncopate-LICENSE.txt`) |
| `VT323-400.woff2` | VT323 | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`licences/VT323-OFL.txt`) |
| `Aurebesh.ttf` | Aurebesh | SilvinoR, unmodified | SIL OFL 1.1 (`licences/Aurebesh-OFL.txt`) |
| `AurebeshBloopsAF.woff2` | Bloops | AurekFonts, as WOFF2 | CC0 |
| `AurebeshAF-CanonTech.woff2` | AF Canon Tech | AurekFonts, as WOFF2 | CC0 |
| `DroidobeshDepot-Regular.woff2` | Droid Depot | Vamplify and AurekFonts, as WOFF2 | CC0 |
| `OuterRimAF-Regular.woff2` | Outer Rim | AurekFonts, as WOFF2 | CC0 |
| `SithAF.woff2` | Sith | Ender Smith and AurekFonts, as WOFF2 | CC BY 3.0 US: "Sith" by Ender Smith, AurekFonts; converted from OpenType to WOFF2 |

The Google Fonts files were retrieved 2026-10-01 and 2026-10-02. The AurekFonts files were converted from their
OpenType originals with fontTools. Nothing else about them was changed.

The club's two came first, with the club mirror:

- `Rye-Latin-Regular.woff2`, from <https://fonts.gstatic.com/s/rye/v17/r05XGLJT86YzEZ7t.woff2>, SHA-256
  `00de26ff9e435fb8f9e3ad15877f9deb4b70f3945ae0abcf7f0ed278d593014b`. Rye is copyright 2011 Sorkin Type Co.
- `PermanentMarker-Latin-Regular.woff2`, from
  <https://fonts.gstatic.com/s/permanentmarker/v16/Fh4uPib9Iyv2ucM6pGQMWimMp004La2Cfw.woff2>, SHA-256
  `4884fec2c73aa52a2461073c1b87d1ceb80f400520391b43f97ca7d3c39eeb24`. Permanent Marker is by Font Diner.
