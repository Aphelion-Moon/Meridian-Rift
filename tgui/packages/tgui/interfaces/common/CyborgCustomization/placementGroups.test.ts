import { expect, it } from 'bun:test';
import { placementBase, placementGroup } from './placementGroups';
import type { LayoutEntry } from './types';

it('separates front/back placement from mirrored sides, retaining legacy fallback', () => {
  const entry = {
    pixel_x: 4,
    pixel_y: 15,
    rotation: 0,
    scale: 1,
    colors: ['#ffffff', '#ffffff', '#ffffff'],
    advanced: {},
    placement_groups: { side: { pixel_x: 20, pixel_y: 7, rotation: 10 } },
  } as LayoutEntry;
  expect(placementGroup(true, 4)).toBe(placementGroup(true, 8));
  expect(placementBase(entry, placementGroup(true, 1)).pixel_x).toBe(4);
  expect(placementBase(entry, placementGroup(true, 2)).pixel_y).toBe(15);
  expect(placementBase(entry, placementGroup(true, 8)).pixel_x).toBe(20);
  expect(placementBase(entry, placementGroup(false, 8)).pixel_x).toBe(4);
});
