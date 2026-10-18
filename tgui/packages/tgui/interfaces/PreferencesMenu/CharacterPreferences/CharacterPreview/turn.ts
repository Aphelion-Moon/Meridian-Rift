// THIS IS AN APHELION UI FILE
import { atom } from 'jotai';

import { SPRITE_DIRS } from '../SpeciesRegistry/constants';

/** Quarter turns of the character preview, shared by every tab so a turn on one holds on the next. */
export const previewTurnAtom = atom(0);

/** The facing a number of quarter turns shows. */
export const previewFacing = (turn: number) =>
  SPRITE_DIRS[
    ((turn % SPRITE_DIRS.length) + SPRITE_DIRS.length) % SPRITE_DIRS.length
  ];

/** Turns the preview clockwise, or back. */
export const turnPreview = atom(null, (get, set, backwards: boolean) =>
  set(previewTurnAtom, get(previewTurnAtom) + (backwards ? -1 : 1)),
);

/** Turns the preview by some quarter turns, clockwise from above. */
export const turnPreviewBy = atom(null, (get, set, turns: number) =>
  set(previewTurnAtom, get(previewTurnAtom) + turns),
);
