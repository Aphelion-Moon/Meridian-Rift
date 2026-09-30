// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';

import type { CharacterPreviewDrawing } from '../../types';
import { type DrawnBounds, previewFit } from './drawing';

const tile: CharacterPreviewDrawing = {
  id: 1,
  species: 'human',
  image: 'data:image/png;base64,tile',
  width: 32,
  height: 32,
  x: 0,
  y: 0,
  frames: { north: 0, south: 32, east: 64, west: 96 },
};

describe('previewFit', () => {
  it('stands a character as large as the box is wide, all it draws centred', () => {
    // Drawn from its feet to 2px under the top of its tile.
    const fit = previewFit(tile, 272, 480, [8, 2, 24, 32]);

    expect(fit.scale).toBe(8);
    // The tile's centre across the middle; its floor 15 rows of 8 below the
    // middle, so the 30 drawn rows sit centred.
    expect(fit.x).toBe(136);
    expect(fit.y).toBe(240 + 15 * 8);
  });

  it('fits a wide character by how far it reaches from its tile', () => {
    // A taur: 16px past each side of its tile.
    const taur = { ...tile, width: 64, x: 16 };

    expect(previewFit(taur, 272, 480, [0, 0, 64, 32]).scale).toBe(4);
  });

  it("fits what a tall character draws, not its frame's empty headroom", () => {
    const tallest = { ...tile, height: 64 };

    expect(previewFit(tallest, 272, 300).scale).toBe(4);
    expect(previewFit(tallest, 272, 300, [8, 30, 24, 64]).scale).toBe(8);
  });

  it('fits a grown character by what it draws once grown', () => {
    // Body size 1.25: 20px each side of the tile's centre, 40px tall.
    const grown = {
      ...tile,
      transform: [
        1.25, 0, 0, 0, 1.25, 4,
      ] as CharacterPreviewDrawing['transform'],
    };

    expect(previewFit(grown, 272, 480, [0, 0, 32, 32]).scale).toBe(6);
  });

  it('zooms a whole step at a time, from 1x to twice the fit, still centred', () => {
    const bounds = [8, 2, 24, 32] as const;
    const closer = previewFit(tile, 272, 480, [...bounds], 1);

    expect(closer.fitScale).toBe(8);
    expect(closer.scale).toBe(9);
    expect(closer.y).toBe(240 + 15 * 9);
    expect(previewFit(tile, 272, 480, [...bounds], 100).scale).toBe(16);
    expect(previewFit(tile, 272, 480, [...bounds], -100).scale).toBe(1);
  });

  it('pans as far as brings any part of what it draws to the middle, at any zoom', () => {
    const bounds: DrawnBounds = [8, 2, 24, 32];
    // 8px each side of the tile's centre, and 30 rows centred up and down.
    const across = { minX: -8, maxX: 8, minY: -15, maxY: 15 };

    expect(previewFit(tile, 272, 480, bounds).panBounds).toEqual(across);
    expect(previewFit(tile, 272, 480, bounds, 1).panBounds).toEqual(across);
    // A taur drawn from 32px left of its tile's centre to 8px right of it.
    const taur = { ...tile, width: 64, x: 16 };
    const wide = previewFit(taur, 272, 480, [0, 0, 40, 32]).panBounds;
    expect([wide.minX, wide.maxX]).toEqual([-8, 32]);
  });
});
