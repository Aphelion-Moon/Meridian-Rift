ES modules and types from `html-to-image@1.11.13` (MIT), with the Meridian changes below.

Source: https://github.com/bubkoo/html-to-image
Package: https://registry.npmjs.org/html-to-image/-/html-to-image-1.11.13.tgz
Verified SHA-512 (base64): `cuOPoI7WApyhBElTTb9oqsawRvZ0rHhaHwghRLlTuffoD1B2aDemlCruLeZrUIIdvG7gs9xeELEPm6PhuASqrg==`

Vendoring avoids changing the shared dependency installation. The adjacent
`dom-snapshot.ts` wrapper limits dimensions, nodes and output, and preserves
visible scroll offsets. This reconstructs the selected UI DOM; unsupported or
unavailable browser resources can differ from the screen. Always preview it.

## Meridian changes

Every change is marked `Meridian:` in a comment; nothing else differs from the package.

- `clone-node.js`: `cloneCSSStyle` asks `isInstanceOfElement(nativeNode, HTMLIFrameElement)` once a node, not once a
  property (it walked the prototype chain each time, a fifth of the clone's time). The iframe, font-size and `d`
  value fixes moved unchanged into `writeStyle`.
- `clone-node.js`: `cloneNode` takes the native parent a node inherits from (`parentNode`, null for a root and for
  an iframe body's children) and hands it to `decorate` and `cloneCSSStyle`; `decorate` tells the copier when a node
  is done.
- `clone-node.js`: with `options.copier`, `cloneCSSStyle` writes only the properties the copier lists and takes off
  the inline declarations it drops; without one, or when the copier answers null, it copies every kept property as
  before.
- `clone-pseudos.js`: with `options.copier`, a pseudo-element no style could give content is skipped without
  computing its style, and its rule holds only the properties the copier lists, in the same `name: value;` text.
- `types.d.ts`, `clone-node.d.ts`: the `copier` option and the `parentNode` argument.
- `embed-webfonts.js`: with `options.fontFaces`, `getWebFontCSS` takes the `@font-face` rules it picks and skips the
  walk over the clone's font families; without it, the walk picks them as before.
- `types.d.ts`: the `fontFaces` option.

The copier itself is ours, in `../style-copy.ts`, and so is the face filter, in `../font-faces.ts`.
Biome skips this folder (the root biome.json lists it), so upstream's code stays as it ships.
