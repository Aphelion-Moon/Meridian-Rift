// THIS IS AN APHELION UI FILE
import { useState } from 'react';

import type { ShownPreview } from './drawing';

/** The drawing a view last showed, whose it was, and how many characters it has shown. */
export type Arrival = {
  image?: HTMLImageElement;
  slot?: number;
  species?: string | null;
  count: number;
};

/**
 * The view's count of characters once a drawing has loaded: a drawing for
 * another slot, or of another species, is another character's. Any other
 * drawing is the same character's, drawn again. Each drawing says whose it is,
 * so the count keeps in step with the picture, however its update and the
 * window's own arrive.
 */
export function nextArrival(last: Arrival, shown: ShownPreview): Arrival {
  const { image, preview } = shown;
  if (!image || image === last.image) {
    return last;
  }
  const another =
    !!last.image &&
    (preview.slot !== last.slot || preview.species !== last.species);
  return {
    image,
    slot: preview.slot,
    species: preview.species,
    count: last.count + (another ? 1 : 0),
  };
}

/**
 * Numbers the characters a view shows, for a key that makes the theme's
 * arrival play for each of them; see _portrait-arrival.scss.
 */
export function useArrival(shown: ShownPreview): number {
  const [last, setLast] = useState<Arrival>({ count: 0 });
  const next = nextArrival(last, shown);
  if (next !== last) {
    setLast(next);
  }
  return next.count;
}
