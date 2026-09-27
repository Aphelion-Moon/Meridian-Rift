// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { coveredPaint, coverIndexAt, regionAt } from './regions';

const rows = ['0110', '0120', '0000'];
const zones = ['chest', 'l_arm'];

it('finds the region under a pixel', () => {
  expect(regionAt(rows, zones, 1, 0)).toBe('chest');
  expect(regionAt(rows, zones, 2, 1)).toBe('l_arm');
  expect(regionAt(rows, zones, 0, 0)).toBeNull();
  expect(regionAt(rows, zones, 9, 9)).toBeNull();
  expect(regionAt(undefined, zones, 1, 0)).toBeNull();
});

it('lists only painted pixels the cover rows mark, and tolerates short rows', () => {
  // Each mark names the covering part; only "0" is clear.
  const cover = ['1200', '0010'];
  const frame = [
    ['#ff0000ff', '#00000000', '#ff0000ff', '#ff0000ff'],
    ['#ff0000ff', '#ff0000ff', '#ff0000ff', '#ff0000ff'],
    ['#ff0000ff', '#ff0000ff', '#ff0000ff', '#ff0000ff'],
  ];
  expect(coveredPaint(cover, frame)).toEqual([
    [0, 0, 1, 1],
    [2, 1, 1, 1],
  ]);
  expect(coveredPaint(undefined, frame)).toEqual([]);
  expect(coveredPaint(cover, undefined)).toEqual([]);
});

it('finds the part covering a pixel from the row mark', () => {
  const cover = ['123a0'];
  expect(coverIndexAt(cover, 0, 0)).toBe(0);
  expect(coverIndexAt(cover, 1, 0)).toBe(1);
  expect(coverIndexAt(cover, 2, 0)).toBe(2);
  expect(coverIndexAt(cover, 3, 0)).toBe(9);
  expect(coverIndexAt(cover, 4, 0)).toBeNull();
  expect(coverIndexAt(cover, 0, 5)).toBeNull();
  expect(coverIndexAt(undefined, 0, 0)).toBeNull();
});
