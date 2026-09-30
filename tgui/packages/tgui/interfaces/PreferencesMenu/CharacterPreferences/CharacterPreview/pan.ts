// THIS IS AN APHELION UI FILE
import type { RefObject } from 'react';

import { type PanBounds, TILE } from './drawing';

type Point = { x: number; y: number };

/** A pan, in the drawing's pixels, kept within its bounds. */
export const clampPan = (pan: Point, bounds: PanBounds): Point => ({
  x: Math.min(bounds.maxX, Math.max(bounds.minX, pan.x)),
  y: Math.min(bounds.maxY, Math.max(bounds.minY, pan.y)),
});

/** A length less whole tiles, from 0 up to a tile. */
const lessTiles = (length: number, tile: number) =>
  ((length % tile) + tile) % tile;

/** Moves an element by whole pixels, or puts it back. */
function translate(element: HTMLElement | null, x: number, y: number) {
  if (!element) {
    return;
  }
  if (x || y) {
    element.style.setProperty('translate', `${x}px ${y}px`);
  } else {
    element.style.removeProperty('translate');
  }
}

export type PreviewPan = {
  /** The drawing is shown at this scale, and may be panned this far. */
  place: (scale: number, bounds: PanBounds) => void;
  /** A pointer takes hold of the drawing here, in page pixels. */
  start: (x: number, y: number) => void;
  /** The pointer holding the drawing is here now. */
  move: (x: number, y: number) => void;
  /** The pointer let go. */
  end: () => void;
  /** Back to the middle. */
  reset: () => void;
};

/**
 * The view's pan: how far a drag has moved the drawing, in the drawing's
 * own pixels, so a zoom keeps what is at the box's middle there. A pan brings
 * any part of what the character draws to the middle, and no further, so the
 * character never leaves the box.
 *
 * It moves the parts it pans itself, each by its own inline `translate`: the
 * drawing and its floor. A pan re-renders nothing and restyles only those two,
 * and a move that changes no whole pixel writes nothing. The frame, the
 * scanner's rule included, stays where it is.
 */
export function createPreviewPan(
  box: RefObject<HTMLElement | null>,
): PreviewPan {
  let pan: Point = { x: 0, y: 0 };
  let placed: { scale: number; bounds: PanBounds } | undefined;
  // The pointer holding the drawing: where it took hold, the pan it took hold
  // of, and where it is.
  let grab: { from: Point; pan: Point; at: Point } | undefined;
  let parts: Record<'figure' | 'floor', HTMLElement | null> = {
    figure: null,
    floor: null,
  };
  let written = '';

  const write = () => {
    if (!placed) {
      return;
    }
    const tile = TILE * placed.scale;
    const x = Math.round(pan.x * placed.scale);
    const y = Math.round(pan.y * placed.scale);
    const shown = `${x} ${y} ${tile}`;
    if (shown === written) {
      return;
    }
    written = shown;
    translate(parts.figure, x, y);
    // The floor repeats every tile, so it moves by the pan less whole tiles.
    translate(parts.floor, lessTiles(x, tile), lessTiles(y, tile));
  };

  // Where the pointer is becomes where it took hold, of the pan as it is.
  const regrip = () => {
    if (grab) {
      grab = { from: grab.at, pan, at: grab.at };
    }
  };

  return {
    place(scale, bounds) {
      if (placed && placed.scale !== scale) {
        // A zoom mid-pan carries on from here, at the new scale.
        regrip();
      }
      placed = { scale, bounds };
      pan = clampPan(pan, bounds);
      // A render may have drawn the parts anew, so find them and move them again.
      const element = box.current;
      parts = {
        figure: element?.querySelector('.CharacterPreview__figure') ?? null,
        floor: element?.querySelector('.CharacterPreview__background') ?? null,
      };
      written = '';
      write();
    },
    start(x, y) {
      if (!placed) {
        return;
      }
      grab = { from: { x, y }, pan, at: { x, y } };
      box.current?.setAttribute('data-panning', '');
    },
    move(x, y) {
      if (!grab || !placed) {
        return;
      }
      const { from, pan: held } = grab;
      grab.at = { x, y };
      pan = clampPan(
        {
          x: held.x + (x - from.x) / placed.scale,
          y: held.y + (y - from.y) / placed.scale,
        },
        placed.bounds,
      );
      write();
    },
    end() {
      grab = undefined;
      box.current?.removeAttribute('data-panning');
    },
    reset() {
      pan = { x: 0, y: 0 };
      regrip();
      write();
    },
  };
}
