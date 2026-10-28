// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { CANVAS_ALPHABET } from './canvas';
import { artToPixels, decodeFlat, shownColor } from './graffitiCodec';

/** graffiti_encode_flat(), for building grids by hand: runs of up to 15, each index in `digits` characters. */
const encodeFlat = (indices: number[], digits: 1 | 2) => {
  let grid = `g${digits}`;
  for (let at = 0; at < indices.length; ) {
    let run = 1;
    while (run < 15 && indices[at + run] === indices[at]) run++;
    const index = indices[at];
    grid += '0123456789abcdef'[run];
    if (digits === 2) grid += CANVAS_ALPHABET[Math.floor(index / 64)];
    grid += CANVAS_ALPHABET[index % 64];
    at += run;
  }
  return grid;
};

it('round-trips a two-character grid, and refuses what graffiti_decode_flat() refuses', () => {
  // Past 63 colours an index takes two characters: 99 is "1z", 64 is "10".
  expect(encodeFlat([0, 0, 99, 64], 2)).toBe('g220011z110');
  const indices = [...Array(20).fill(0), 99, 64, 64, ...Array(1001).fill(1)];
  const grid = encodeFlat(indices, 2);
  expect(decodeFlat(grid, 100, 1024)).toEqual(indices);
  // The prefix must fit the palette, indices stay inside it, and the runs cover every pixel.
  expect(decodeFlat(`g1${grid.slice(2)}`, 100, 1024)).toBeNull();
  expect(decodeFlat(grid, 98, 1024)).toBeNull();
  expect(decodeFlat(grid, 100, 1025)).toBeNull();
  // The wire contract's worked example, one character an index.
  expect(decodeFlat('g12021', 1, 4)).toEqual([0, 0, 1, 1]);
});

it('expands an art with two painted pixels to #rrggbbaa, empty where transparent', () => {
  const pixels = artToPixels({
    w: 32,
    pal: '#ff0000ff#00ff0080',
    grid: encodeFlat([1, 2, ...Array(1022).fill(0)], 1),
    glow: encodeFlat(Array(1024).fill(0), 1),
  });
  expect(pixels).toHaveLength(1024);
  expect(pixels.slice(0, 3)).toEqual(['#ff0000ff', '#00ff0080', '']);
  expect(pixels.filter(Boolean)).toHaveLength(2);
});

it('draws alpha as its share of the ceiling, so paint at the ceiling draws opaque', () => {
  // The ceiling is cc: 99% of it, cb, draws at 99%, the floor, 33, at a quarter, and opaque paint as it is.
  expect(shownColor('#123456cb')).toBe('#123456fe');
  expect(shownColor('#12345633')).toBe('#12345640');
  expect(shownColor('#123456ff')).toBe('#123456ff');
  expect(shownColor('#123456')).toBe('#123456');
  expect(shownColor('#00000000')).toBe('#00000000');
});
