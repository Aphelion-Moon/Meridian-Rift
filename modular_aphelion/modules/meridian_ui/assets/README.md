# MeridianOS theme art

Art a MeridianOS theme draws with that is too big for tgui's bundle, which every window loads and the lobby inlines.
`/datum/asset/simple/art_stylesheet` (`code/art_stylesheet.dm`) sends a theme's files to its players' windows and lobby
with a stylesheet it writes when it registers, naming each texture as a custom property on the theme
(`--mt-<file name without extension>`) and each font as a face. Foundry's textures and its title and label faces are the
forge markings room's own files (`modular_aphelion/modules/markings_room/assets/`); what is here is the theme's own.

## Textures

| File | What | Source |
| --- | --- | --- |
| `textures/foundry-smoke.webp` | Foundry's arrival smoke: a soft-alpha plume of forge smoke lit warm from below, 128x176 | Original, procedural |

The smoke is value-noise fBm with a domain warp, stretched upward into wisps, densest low and in the middle, fading to
nothing at the edges, made with a fixed seed by the lab's foundry-theme run (`smoke/make_smoke.py`). Nothing
third-party goes into it. A portrait's arrival scales and drifts it while it fades (`_portrait-arrival.scss`), so it
is drawn small and soft.

## Fonts

| File | Family | Source | Licence |
| --- | --- | --- | --- |
| `fonts/AlegreyaSans-400.woff2`, `-700` | Alegreya Sans | Google Fonts, latin subset, unmodified | SIL OFL 1.1 (`fonts/licences/AlegreyaSans-OFL.txt`) |

Alegreya Sans is Foundry's running text (descriptions, notices, tooltips, logs, prose): a humanist sans from the
Alegreya superfamily, with the same calligraphic roots as the theme's Macondo and Caesar Dressing, compact enough to
take Macondo's place without reflowing windows, with lining figures for data. Retrieved 2026-10-03:

- `AlegreyaSans-400.woff2`, from <https://fonts.gstatic.com/s/alegreyasans/v28/5aUz9_-1phKLFgshYDvh6Vwt7VptvQ.woff2>,
  SHA-256 `b2a5a35a2563a2f9bf9fb91939fc6ea6c115e9811cda5c4a37d02f623c7c4dbe`.
- `AlegreyaSans-700.woff2`, from <https://fonts.gstatic.com/s/alegreyasans/v28/5aUu9_-1phKLFgshYDvh6Vwt5eFIqEp2iw.woff2>,
  SHA-256 `5acd19a588614d23e52b741a21dd8555178ab4932c3195c6d8fb4b296f84acae`.

Alegreya Sans is copyright 2013 The Alegreya Sans Project Authors (Huerta Tipográfica).
