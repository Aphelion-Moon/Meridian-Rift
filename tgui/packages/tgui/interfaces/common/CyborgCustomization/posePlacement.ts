import type { DirectionEntry, LayoutEntry } from './types';

export type PlacementTarget = 'base' | 'pose' | 'arousal';

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

/** Shared by numeric edits, pointer placement, and keyboard nudges. */
export function updatePosePlacement(
  entry: LayoutEntry,
  direction: string | number,
  pose: string,
  arousal: string,
  onlyArousal: boolean,
  changes: Partial<DirectionEntry>,
) {
  const { key, directional } = posePlacement(entry, direction, pose, arousal);
  return {
    ...entry.advanced,
    [key]: onlyArousal
      ? {
          ...directional,
          arousal: {
            ...directional.arousal,
            [arousal]: { ...directional.arousal?.[arousal], ...changes },
          },
        }
      : { ...directional, ...changes },
  };
}
