// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { coveredPaint, coverPartAt, regionAt } from './regions';

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

it('names the part covering a pixel from the row mark', () => {
  const cover = ['1230'];
  const parts = ['hair', 'snout', 'wings'];
  expect(coverPartAt(cover, parts, 0, 0)).toBe('hair');
  expect(coverPartAt(cover, parts, 1, 0)).toBe('snout');
  expect(coverPartAt(cover, parts, 2, 0)).toBe('wings');
  expect(coverPartAt(cover, parts, 3, 0)).toBeNull();
  expect(coverPartAt(cover, parts, 0, 5)).toBeNull();
  expect(coverPartAt(['a'], parts, 0, 0)).toBeNull();
  expect(coverPartAt(undefined, parts, 0, 0)).toBeNull();
  expect(coverPartAt(cover, undefined, 0, 0)).toBeNull();
});
