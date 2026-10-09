// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';

import type { CharacterPreviewDrawing } from '../../types';
import { type Arrival, nextArrival } from './arrival';
import {
  animationStep,
  type DrawnBounds,
  previewBodyFit,
  previewFit,
  previewFramePoint,
  previewFrameStyle,
  previewMovedY,
  type ShownPreview,
} from './drawing';

const tile: CharacterPreviewDrawing = {
  id: 1,
  species: 'human',
  slot: 1,
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

describe('previewBodyFit', () => {
  // The augments stage's view: 332 x 520, a body's tile at most 12x.
  const stage = [332, 520] as const;
  const taur = { ...tile, width: 64, x: 16 };

  it('stands a taur by its tile, at the scale any body stands at', () => {
    // A human drawn 8px each side of its tile's centre, and a taur whose lower
    // body runs 16px past each side of its tile.
    const human = previewBodyFit(tile, ...stage, [8, 2, 24, 32], 0, 12);
    const body = previewBodyFit(taur, ...stage, [0, 2, 64, 32], 0, 12);

    expect(previewFit(taur, ...stage, [0, 2, 64, 32], 0, 12).scale).toBe(5);
    expect(body.scale).toBe(12);
    expect(body.scale).toBe(human.scale);
    // Its tile's centre and floor where the human's are, so a point of the
    // tile lands in the same place on both.
    expect([body.x, body.y]).toEqual([human.x, human.y]);
    expect(
      previewFramePoint(taur, body.scale, body.x, body.y, 16 + 13, 2.5),
    ).toEqual(previewFramePoint(tile, human.scale, human.x, human.y, 13, 2.5));
  });

  it('fits a body no larger than its tile as previewFit does', () => {
    const bounds: DrawnBounds = [4, 2, 28, 32];

    expect(previewBodyFit(tile, ...stage, bounds, 0, 12)).toEqual(
      previewFit(tile, ...stage, bounds, 0, 12),
    );
  });

  it('centres what a taur draws inside its tile, before its image has loaded too', () => {
    // Drawn up to 24 rows above its floor inside its tile: those rows centred,
    // whatever its lower body draws past the tile.
    const short = previewBodyFit(taur, ...stage, [0, 8, 64, 32], 0, 12);
    expect(short.y).toBe(260 + (24 / 2) * 12);
    // No bounds yet: the whole tile.
    expect(previewBodyFit(taur, ...stage, undefined, 0, 12).y).toBe(
      260 + 16 * 12,
    );
  });
});

describe('previewFramePoint', () => {
  it("puts a frame pixel where the frame's own placement does", () => {
    const style = previewFrameStyle(tile, 12, 166, 446);
    // The frame's top left, and its pixel 16 across and 8 down.
    expect([style.left, style.top]).toEqual(['-26px', '62px']);
    expect(previewFramePoint(tile, 12, 166, 446, 0, 0)).toEqual([-26, 62]);
    expect(previewFramePoint(tile, 12, 166, 446, 16, 8)).toEqual([166, 158]);
  });

  it("grows about the tile's centre with body size", () => {
    const grown = {
      ...tile,
      transform: [
        1.25, 0, 0, 0, 1.25, 4,
      ] as CharacterPreviewDrawing['transform'],
    };
    // The tile's centre stays; a pixel a tile's quarter from it moves out a
    // quarter more, and the whole lifts 4px.
    expect(previewFramePoint(grown, 1, 16, 32, 16, 16)).toEqual([16, 12]);
    expect(previewFramePoint(grown, 1, 16, 32, 24, 16)).toEqual([26, 12]);
  });
});

describe('previewMovedY', () => {
  it('moves a row with the run height shows it in', () => {
    // A shorter body: its top 20 rows shown a row lower, the row they left
    // empty, its legs where they were.
    const short = {
      ...tile,
      rows: [
        [0, 1, -1],
        [1, 20, 0],
      ] as CharacterPreviewDrawing['rows'],
    };
    expect(previewMovedY(short, 5.5)).toBe(6.5);
    expect(previewMovedY(short, 0)).toBe(1);
    expect(previewMovedY(short, 27.5)).toBe(27.5);

    // A taller one: its top 18 rows shown 2 rows higher.
    const tall = {
      ...tile,
      rows: [[0, 18, 2]] as CharacterPreviewDrawing['rows'],
    };
    expect(previewMovedY(tall, 6.5)).toBe(4.5);
    expect(previewMovedY(tall, 1.5)).toBe(1.5);
  });

  it('leaves every row where it is without height', () => {
    expect(previewMovedY(tile, 13.5)).toBe(13.5);
  });
});

describe('nextArrival', () => {
  const picture = () => ({}) as HTMLImageElement;
  const shown = (
    image: HTMLImageElement | undefined,
    { slot = 1, species = 'human' as string | null } = {},
  ): ShownPreview => ({ preview: { ...tile, slot, species }, image });
  const opened: Arrival = { count: 0 };

  it('waits for a drawing to load, and takes the first as the one the view opened on', () => {
    expect(nextArrival(opened, shown(undefined))).toBe(opened);
    expect(nextArrival(opened, shown(picture())).count).toBe(0);
  });

  it('takes a new drawing of the same character in place', () => {
    const first = nextArrival(opened, shown(picture()));
    expect(nextArrival(first, shown(picture())).count).toBe(0);
  });

  it("counts a drawing for another slot by the drawing's own slot, whenever the window's update comes", () => {
    const first = nextArrival(opened, shown(picture()));
    // Still loading: the drawing shown stays as it is.
    expect(nextArrival(first, shown(first.image, { slot: 2 }))).toBe(first);
    const next = nextArrival(first, shown(picture(), { slot: 2 }));
    expect(next.count).toBe(1);
    expect(nextArrival(next, shown(picture(), { slot: 2 })).count).toBe(1);
  });

  it("counts a drawing of another species, or a silicon job's", () => {
    const first = nextArrival(opened, shown(picture()));
    const lizard = nextArrival(first, shown(picture(), { species: 'lizard' }));
    expect(lizard.count).toBe(1);
    expect(nextArrival(lizard, shown(picture(), { species: null })).count).toBe(
      2,
    );
  });
});

describe('animationStep', () => {
  // A halo's bob: the facing as drawn for half a second, then its patch.
  const halo: [number, number][] = [
    [-1, 500],
    [0, 500],
  ];

  it('starts on the facing as drawn', () => {
    expect(animationStep(halo, 0)).toEqual({ index: 0, wait: 500 });
  });

  it('moves on when a step has had its time, waiting only what is left of it', () => {
    expect(animationStep(halo, 499)).toEqual({ index: 0, wait: 1 });
    expect(animationStep(halo, 500)).toEqual({ index: 1, wait: 500 });
    expect(animationStep(halo, 750)).toEqual({ index: 1, wait: 250 });
  });

  it('loops, so a page hidden for a while comes back where the loop has got to', () => {
    expect(animationStep(halo, 1000)).toEqual({ index: 0, wait: 500 });
    expect(animationStep(halo, 10_600)).toEqual({ index: 1, wait: 400 });
  });

  it('keeps steps of their own lengths', () => {
    const uneven: [number, number][] = [
      [-1, 80],
      [12, 240],
      [24, 80],
    ];
    expect(animationStep(uneven, 100).index).toBe(1);
    expect(animationStep(uneven, 330)).toEqual({ index: 2, wait: 70 });
  });
});
