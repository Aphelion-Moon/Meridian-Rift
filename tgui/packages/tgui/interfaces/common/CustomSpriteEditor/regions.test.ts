// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import {
  bracketBars,
  coveredPaint,
  drawCoveredPaint,
  drawScanlines,
  regionAt,
  regionBounds,
  regionOutline,
  tagPosition,
} from './regions';

const rows = ['0110', '0120', '0000'];
const zones = ['chest', 'l_arm'];

it('finds the region under a pixel', () => {
  expect(regionAt(rows, zones, 1, 0)).toBe('chest');
  expect(regionAt(rows, zones, 2, 1)).toBe('l_arm');
  expect(regionAt(rows, zones, 0, 0)).toBeNull();
  expect(regionAt(rows, zones, 9, 9)).toBeNull();
  expect(regionAt(undefined, zones, 1, 0)).toBeNull();
});

it('bounds a region in one view, or reports it absent', () => {
  expect(regionBounds(rows, zones, 'chest')).toEqual([1, 0, 2, 1]);
  expect(regionBounds(rows, zones, 'l_arm')).toEqual([2, 1, 2, 1]);
  expect(regionBounds(rows, zones, 'head')).toBeNull();
  expect(regionBounds(rows, zones, null)).toBeNull();
});

it('traces a region just outside its pixel edges', () => {
  expect(regionOutline(['1'], ['chest'], 'chest', 10)).toEqual([
    [-1, -1, 12, 1],
    [-1, 10, 12, 1],
    [-1, -1, 1, 12],
    [10, -1, 1, 12],
  ]);
  expect(regionOutline(['11'], ['chest'], 'chest', 10)).toHaveLength(6);
});

it('places brackets outside the box and the tag above, or below at the top edge', () => {
  const bars = bracketBars([0, 0, 0, 0], 10, 5, 9);
  expect(bars).toHaveLength(8);
  expect(bars[0]).toEqual([-5, -5, 9, 1]);
  expect(bars[3]).toEqual([14, -5, 1, 9]);
  expect(tagPosition([0, 5, 1, 6], 10, 13, 5)).toEqual([0, 30]);
  expect(tagPosition([0, 0, 1, 1], 10, 13, 5)).toEqual([0, 27]);
});

it('draws scanlines only inside the shaded areas, on every third screen row', () => {
  const calls: [string, number, number, number, number][] = [];
  const context = {
    fillStyle: '',
    fillRect(x: number, y: number, w: number, h: number) {
      calls.push([String(this.fillStyle), x, y, w, h]);
    },
  } as unknown as CanvasRenderingContext2D;
  drawScanlines(context, [[0, 0, 2, 1]], 3);
  expect(calls).toEqual([
    ['rgba(10, 12, 14, 0.62)', 0, 0, 6, 3],
    ['rgba(255, 255, 255, 0.07)', 0, 1, 6, 1],
  ]);
});

it('lists only painted pixels the cover rows mark, and tolerates short rows', () => {
  const cover = ['1100', '0010'];
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

it('washes and hatches each covered pixel with fill rects only', () => {
  const calls: [string, number, number, number, number][] = [];
  const context = {
    fillStyle: '',
    fillRect(x: number, y: number, w: number, h: number) {
      calls.push([this.fillStyle, x, y, w, h]);
    },
  } as unknown as CanvasRenderingContext2D;
  drawCoveredPaint(context, [[1, 2, 1, 1]], 10);
  expect(calls[0]).toEqual(['rgba(0, 0, 0, 0.45)', 10, 20, 10, 10]);
  expect(calls[1]).toEqual(['rgba(255, 255, 255, 0.55)', 10, 29, 1, 1]);
  expect(calls).toHaveLength(11);
});
