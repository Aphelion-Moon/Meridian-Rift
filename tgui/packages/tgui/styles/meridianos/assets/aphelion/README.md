# Aphelion website assets

## Typography update — 2026-09-07

Aphelion now uses the user-selected Meridian typography: Behavior for headings,
Atkinson Hyperlegible Next for body text and controls, and Telematic for the lobby access heading.
The three regular font binaries are unchanged copies of the user-provided files
in `C:\Users\mal\fonts`; their original source and license notices are bundled
alongside them. Rspack embeds OTF and TTF assets in the cached stylesheet.
IBM Plex Mono remains the small telemetry face, as in the selected website preview.

| Active local file                                   | Weight  | Role                                      |
| --------------------------------------------------- | ------- | ----------------------------------------- |
| Behavior-Regular.otf                                | 400     | Page and section headings                 |
| AtkinsonHyperlegibleNext-Latin-Variable.woff2       | 200–800 | Body, buttons, labels, and other controls |
| AtkinsonHyperlegibleNext-Latin-VariableItalic.woff2 | 400     | Italic body text                          |
| Neuromax-Regular.otf                                | 400     | Retained interface accent face            |
| Telematic-Regular.ttf                               | 400     | Lobby access heading                      |

The reading face is the exact Latin WOFF2 subset from the approved option 04.
Its original copyright and SIL Open Font License are in
`AtkinsonHyperlegibleNext-OFL.txt`; `AtkinsonHyperlegibleNext-source.json` records
the source URLs and SHA-256 hashes. No control dimensions or section-header
styles were changed for this readability pass. The normal face supports real
bold weights and the separate italic face supports real italics.

## Fonts

| File                               | Weight  | Role              | License               |
| ---------------------------------- | ------- | ----------------- | --------------------- |
| ibm-plex-mono-latin-400.woff2      | 400     | Labels/telemetry  | OFL-IBM-Plex-Mono.txt |
| ibm-plex-mono-latin-600.woff2      | 600     | Emphasized labels | OFL-IBM-Plex-Mono.txt |

The original copyright statements and complete SIL Open Font License 1.1
texts are bundled alongside the font files, retrieved from Google Fonts:

- [OFL-IBM-Plex-Mono.txt](https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/OFL.txt)

Fontsource sources recorded by the website's Astro font cache:

- https://cdn.jsdelivr.net/fontsource/fonts/ibm-plex-mono@latest/latin-400-normal.woff2
- https://cdn.jsdelivr.net/fontsource/fonts/ibm-plex-mono@latest/latin-600-normal.woff2

## Provenance and integrity

These content-addressed website URLs identify the exact copied assets;
SHA-256 values make provenance independent of future website changes.

- [ibm-plex-mono-latin-400.woff2](https://meridian.a13.info/_astro/fonts/a3a0a8110b9e369d.woff2)
  - SHA-256: `08949f728dc52d528e69b1667d15c89a5686a4ee9a296ff90983985f99c380f7`
- [ibm-plex-mono-latin-600.woff2](https://meridian.a13.info/_astro/fonts/9be50d119b1fd79e.woff2)
  - SHA-256: `0d1f0b8d0722224e32e9f28261bdc86c79115be73444ae5eceb73976a1bcdf83`
- [aphelion-grain-blue-noise-512.png](https://meridian.a13.info/_astro/grain-blue-noise-512.BHVQ2Vs9.png)
  - SHA-256: `37c6396a769482fbba0268c9075ce336d4c688ef4428fbd2e2198664ef9fb99e`
