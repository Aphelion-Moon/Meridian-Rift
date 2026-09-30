// SVGO settings for our own SVG art, such as the MeridianOS theme assets. From tgui/, run for example:
//   bunx svgo -r -f packages/tgui/styles/meridianos/assets
// Leave upstream SVGs, such as packages/tgui/assets/transparency_checkerboard.svg, as they are.
//
// The output renders pixel for pixel like its source: the viewBox stays (CSS scales and slices these images), zero-length
// path segments stay (they draw round-capped dots), and overlapping paths stay separate (merging them changes how their
// edges blend).
module.exports = {
  multipass: true,
  plugins: [
    {
      name: 'preset-default',
      params: {
        overrides: {
          removeViewBox: false,
          convertPathData: {
            removeUseless: false,
            applyTransformsStroked: false,
          },
          mergePaths: false,
        },
      },
    },
  ],
};
