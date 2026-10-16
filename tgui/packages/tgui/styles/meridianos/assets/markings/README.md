# Markings room assets in the bundle

What the Augments+ rooms keep inline in tgui's stylesheet: the pixel props of a
kilobyte or so (`px-*.png`), and Hephaestus's frame (`hephaestus-frame.svg`, the
MeridianOS theme's own frame). Rspack embeds them, as it does the other theme
fonts and material tiles.

Everything larger, every room's textures and fonts, belongs to the markings_room
module (`modular_aphelion/modules/markings_room/assets/`, see its README). The
preferences window gets those with its other assets, so the bundle every tgui
window loads doesn't carry them.

The pixel props are original art, drawn for the room mockups by the lab's
`pixel_props.py`, and stored as lossless PNGs.
