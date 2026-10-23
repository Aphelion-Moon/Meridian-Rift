import type { DirectionEntry, LayoutEntry } from './types';

export type PlacementTarget = 'base' | 'pose' | 'arousal';

export function placementGroup(wide: boolean, direction: number | string) {
  if (!wide) return undefined;
  if (direction === 1 || direction === 'north') return 'north';
  if (direction === 2 || direction === 'south') return 'south';
  return 'side';
}

export function placementBase(entry: LayoutEntry, group?: string) {
  return { ...entry, ...(group ? entry.placement_groups?.[group] : {}) };
}

/** Legacy direction entries remain shared fallbacks; every pose gets its own key. */
export function posePlacement(
  entry: LayoutEntry,
  direction: string | number,
  pose: string,
  arousal: string,
) {
  const facing =
    typeof direction === 'number'
      ? ({ 1: 'north', 2: 'south', 4: 'east', 8: 'west' }[direction] ?? 'south')
      : direction;
  const key = `${pose}_${facing}`;
  const saved: Partial<DirectionEntry> =
    entry.advanced[key] ?? entry.advanced[facing] ?? {};
  const directional: DirectionEntry = {
    visible: true,
    pixel_x: 0,
    pixel_y: 0,
    rotation: 0,
    scale: 1,
    priority: 5,
    ...saved,
  };
  return {
    key,
    directional,
    effective: { ...directional, ...directional.arousal?.[arousal] },
  };
}
