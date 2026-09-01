# Lobby menu styles

[\_menu-common.scss](_menu-common.scss) supplies geometry and behavior for all
fifteen HTML menus: placement, size limits, scrolling, text wrapping, heading
alignment, stable pointer/focus markers, and nonanimated poll indicators. These
39 declarations previously appeared in each of the four layout stylesheets.
The common selectors are deliberately less specific than the theme profiles.

[\_themed-menus.scss](_themed-menus.scss) supplies the default instrument layout,
native-control states, and keyboard focus treatment for twelve menus.
[\_instrument-menus.scss](_instrument-menus.scss) supplies eight instrument
profiles; [\_signal-menus.scss](_signal-menus.scss) supplies Cyberpunk,
Augmentation, Synapse, and Hotline. Profiles set `--menu-*` colors, frame
weights, edge rules, and hover surfaces. Keep compound backgrounds opaque and
decoration at the casing edges, clear of text and hit boxes.

The distinct Wastelander, Highline, and Aphelion layouts remain in
[\_wastelander.scss](_wastelander.scss), [\_highline.scss](_highline.scss), and
[\_aphelion-theme.scss](_aphelion-theme.scss). They do not receive the shared
`data-menu-treatment="instrument"` layout.

Menu heading and body type are shared: `--menu-heading-font` and
`--menu-body-font` are defined once in `_themed-menus.scss` and profiles no
longer override them. Keep control height and padding, heading proportions,
surface textures, frame weights, focus colors, and accessibility palette
overrides in their profiles. For example, Highline's ceramic header, Wastelander's worn glass, and
Aphelion's spectrum rule must not become a single generic panel. HTML actions,
disabled controls, headings, and scanline composition already share React
components; duplicating those per theme is unnecessary.

[menuTheme.ts](../../menuTheme.ts) maps each saved theme ID to its menu heading and
identifies which menus use the shared layout. `AphelionLobbyMenu` uses the same
mapping to place menus beneath the selected scanline glass. The separate
[\_menu-scanlines.scss](_menu-scanlines.scss) layer is decorative and ignores
pointer input. Choosing no scanlines suppresses it; increased contrast and
forced colors hide it. Startup and transparent lobbies keep their existing
overlay gates.

| Theme        | Material and construction                                                                      |
| ------------ | ---------------------------------------------------------------------------------------------- |
| Electra      | Navy inset panel, thin frame, segmented teal rule.                                             |
| Classic      | Subdued purple-to-blue CRT surface, pixel lettering, shallow stepped rim.                      |
| Vector       | Blue calibration ticks, precise double frame, monospaced labels.                               |
| Foundry      | Hammered bronze casing, engraved frame, cast-metal heading, and recessed ember-lit controls.   |
| Diagnostic   | Dark green readout, narrow side brackets, short registration ticks.                            |
| Hephaestus   | Blue-grey gunmetal casing, aged bronze frame, recessed controls, and smoked green phase glass. |
| Shadowbroker | Manufactured shell, lower reinforcement, fasteners, orange/cyan rule.                          |
| Scavenger    | Gold slab frame, asymmetric edge weights, broad registration rail.                             |
| Cyberpunk    | Dark red housing, broken red rails, cyan state accents.                                        |
| Augmentation | Cyan module frame, balanced segments, central red registration mark.                           |
| Synapse      | Violet sign rule, teal offset edge, sparse contrasting accents.                                |
| Hotline      | Dark plum housing, reflective pink controls, textured neon glass, and red accents.             |

Menu decoration combines CSS with original SVG framing and theme-owned material
textures. No artwork from the reference games is bundled into these menus.
