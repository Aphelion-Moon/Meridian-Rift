import type { LayoutEntry } from './types';

export function placementGroup(wide: boolean, direction: number | string) {
  if (!wide) return undefined;
  if (direction === 1 || direction === 'north') return 'north';
  if (direction === 2 || direction === 'south') return 'south';
  return 'side';
}

export function placementBase(entry: LayoutEntry, group?: string) {
  return { ...entry, ...(group ? entry.placement_groups?.[group] : {}) };
}
