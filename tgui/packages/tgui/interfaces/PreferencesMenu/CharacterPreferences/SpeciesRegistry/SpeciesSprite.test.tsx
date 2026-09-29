// THIS IS AN APHELION UI FILE
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { act, cleanup, render } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';

import { drawPreviewFacing, previewScale } from '../CharacterPreview/drawing';
import { SPECIES_SPRITESHEETS } from './constants';
import { PreviewFrame, SpeciesSprite } from './SpeciesSprite';

let speciesStyle: HTMLStyleElement;

beforeAll(async () => {
  const { css } = await compileAsync(
    join(import.meta.dir, '../../../../styles/meridianos/_species.scss'),
  );
  speciesStyle = document.createElement('style');
  speciesStyle.textContent = css;
  document.head.appendChild(speciesStyle);
});

afterEach(cleanup);

afterAll(() => speciesStyle.remove());

describe('SpeciesSprite', () => {
  it('scales a frame from either sheet crisply from its corner', () => {
    for (const [bare, sheet] of [
      [false, SPECIES_SPRITESHEETS.uniform],
      [true, SPECIES_SPRITESHEETS.body],
    ] as const) {
      const view = render(
        <SpeciesSprite icon="Lizardperson" bare={bare} scale={6} />,
      );
      const frame = view.container.querySelector(`.${sheet}`) as HTMLElement;
      const style = getComputedStyle(frame);

      expect(frame.className).toContain('Lizardperson-south');
      expect(style.transformOrigin, sheet).toBe('top left');
      expect(style.imageRendering, sheet).toBe('pixelated');
      view.unmount();
    }
  });
});

describe('PreviewFrame', () => {
  const frameOf = (view: ReturnType<typeof render>) =>
    view.container.querySelector('.SpeciesSprite__frame') as HTMLCanvasElement;

  it('stands a mob that fits its tile exactly where a species sprite stands', () => {
    const view = render(
      <PreviewFrame
        preview={{
          id: 1,
          species: 'human',
          image: 'data:image/png;base64,32x32',
          width: 32,
          height: 32,
          x: 0,
          y: 0,
          frames: { north: 0, south: 32, east: 64, west: 96 },
        }}
        dir="south"
        box={256}
      />,
    );
    const frame = frameOf(view);

    // Drawn at its own size and shown eight times larger.
    expect(frame.tagName).toBe('CANVAS');
    expect([frame.width, frame.height]).toEqual([32, 32]);
    expect(frame.style.width).toBe('256px');
    expect(frame.style.height).toBe('256px');
    expect(frame.style.left).toBe('0px');
    expect(frame.style.top).toBe('0px');
    expect(frame.style.transform).toBe('');
  });

  it('keeps wings and big ears in the box, centred on the mob, feet on the floor', () => {
    // Wings reaching 7px past each side, and ears drawn in a 48px frame that
    // starts 8px below the feet, as the game draws them.
    const view = render(
      <PreviewFrame
        preview={{
          id: 1,
          species: 'mammal',
          image: 'data:image/png;base64,45x48',
          width: 45,
          height: 48,
          x: 7,
          y: 8,
          frames: { north: 0, south: 45, east: 90, west: 135 },
        }}
        dir="west"
        box={256}
      />,
    );
    const frame = frameOf(view);
    const style = getComputedStyle(frame);

    // 23px from the tile's centre to the far wing tip fits 128px five times.
    expect(frame.style.width).toBe(`${45 * 5}px`);
    expect(frame.style.height).toBe(`${48 * 5}px`);
    // The tile's centre on the box's centre, and its floor on the box's floor.
    expect(frame.style.left).toBe(`${128 - (7 + 16) * 5}px`);
    expect(frame.style.top).toBe(`${256 - (48 - 8) * 5}px`);
    expect(style.position).toBe('absolute');
    expect(style.imageRendering).toBe('pixelated');
    // What hangs below the feet may show over the floor.
    expect(getComputedStyle(frame.parentElement as HTMLElement).overflow).toBe(
      'visible',
    );
  });

  it('grows a big character about its tile, feet kept on the floor, and fits the growth', () => {
    // Body size 1.25: the game scales about the tile's centre and lifts 4px
    // so the feet stay where they were.
    const view = render(
      <PreviewFrame
        preview={{
          id: 1,
          species: 'human',
          image: 'data:image/png;base64,32x32',
          width: 32,
          height: 32,
          x: 0,
          y: 0,
          frames: { north: 0, south: 32, east: 64, west: 96 },
          transform: [1.25, 0, 0, 0, 1.25, 4],
        }}
        dir="south"
        box={256}
      />,
    );
    const frame = frameOf(view);

    // 20px to each side and 40px above the floor fit six times, not eight.
    expect(frame.style.width).toBe(`${32 * 6}px`);
    expect(frame.style.transformOrigin).toBe('96px 96px');
    // The lift is upwards, which the page counts as negative.
    expect(frame.style.transform).toBe('matrix(1.25, 0, 0, 1.25, 0, -24)');
  });
});

describe('PreviewFrame fit', () => {
  it('fits a transform that is only float error the same as none', () => {
    // A body grown to 1.25 and shrunk back keeps a trace of float error.
    const tall = {
      id: 1,
      species: 'human',
      image: 'data:image/png;base64,32x64',
      width: 32,
      height: 64,
      x: 0,
      y: 0,
      frames: { north: 0, south: 32, east: 64, west: 96 },
    };
    const widths = [
      undefined,
      [1.0000000149, 0, 0, 0, 1.0000000149, -7.15e-7],
    ].map((transform) => {
      const view = render(
        <PreviewFrame
          preview={{ ...tall, transform } as never}
          dir="south"
          box={256}
        />,
      );
      const width = (view.container.querySelector('canvas') as HTMLElement)
        .style.width;
      view.unmount();
      return width;
    });

    // 64 rows fit the box four times either way.
    expect(widths).toEqual(['128px', '128px']);
  });
});

describe('previewScale', () => {
  // A Tallest character: its frame keeps 64 rows, the top ones empty headroom
  // for rows lifted above the tile, and it draws 36 rows above the floor.
  const tallest = {
    id: 1,
    species: 'human',
    image: 'data:image/png;base64,32x64',
    width: 32,
    height: 64,
    x: 0,
    y: 0,
    frames: { north: 0, south: 32, east: 64, west: 96 },
  };
  const drawn = [6, 28, 26, 64] as [number, number, number, number];

  it('fits what the drawing shows, not its empty rows', () => {
    // Until its pixels are known, the whole frame: 64 rows fit 256 four times.
    expect(previewScale(tallest, 256)).toBe(4);
    // 36 rows above the floor fit seven times.
    expect(previewScale(tallest, 256, drawn)).toBe(7);
  });

  it('fits what the drawing shows after body size', () => {
    // At 1.25 about the tile's centre, lifted 4: 45 rows above the floor.
    expect(
      previewScale(
        { ...tallest, transform: [1.25, 0, 0, 0, 1.25, 4] },
        256,
        drawn,
      ),
    ).toBe(5);
  });

  it("never goes past a species sprite's scale", () => {
    expect(previewScale(tallest, 256, [12, 50, 20, 64])).toBe(8);
  });
});

describe('PreviewFrame swaps', () => {
  /** Images that load only when a test says so. */
  class HeldImage extends EventTarget {
    static made: HeldImage[] = [];
    src = '';
    constructor() {
      super();
      HeldImage.made.push(this);
    }
  }
  const RealImage = globalThis.Image;

  beforeAll(() => {
    globalThis.Image = HeldImage as never;
  });

  afterAll(() => {
    globalThis.Image = RealImage;
  });

  it('keeps the drawing it shows until the next one has loaded', () => {
    HeldImage.made = [];
    const first = {
      id: 1,
      species: 'human',
      image: 'data:image/png;base64,first',
      width: 32,
      height: 32,
      x: 0,
      y: 0,
      frames: { north: 0, south: 32, east: 64, west: 96 },
    };
    const second = {
      ...first,
      id: 2,
      image: 'data:image/png;base64,second',
      width: 45,
      height: 48,
      x: 7,
      y: 8,
    };
    const frame = (view: ReturnType<typeof render>) =>
      view.container.querySelector('canvas') as HTMLCanvasElement;
    const view = render(<PreviewFrame preview={first} dir="south" box={256} />);
    act(() => {
      HeldImage.made[0].dispatchEvent(new Event('load'));
    });
    expect([frame(view).width, frame(view).height]).toEqual([32, 32]);

    view.rerender(<PreviewFrame preview={second} dir="south" box={256} />);
    // Its frames only fit its own image, so the first stays until that loads.
    expect(HeldImage.made[1].src).toBe(second.image);
    expect([frame(view).width, frame(view).height]).toEqual([32, 32]);

    act(() => {
      HeldImage.made[1].dispatchEvent(new Event('load'));
    });
    expect([frame(view).width, frame(view).height]).toEqual([45, 48]);
  });
});

describe('drawPreviewFacing', () => {
  const recorder = () => {
    const calls: unknown[][] = [];
    return {
      calls,
      context: {
        imageSmoothingEnabled: true,
        clearRect: (...args: number[]) => calls.push(['clear', ...args]),
        drawImage: (...args: unknown[]) =>
          calls.push(['draw', ...args.slice(1)]),
      },
    };
  };

  it('draws the facing, then each moved run from the rows it shows', () => {
    const { calls, context } = recorder();
    drawPreviewFacing(
      context as never,
      {} as CanvasImageSource,
      {
        id: 1,
        species: 'human',
        image: 'data:image/png;base64,45x64',
        width: 45,
        height: 64,
        x: 7,
        y: 0,
        frames: { north: 0, south: 45, east: 90, west: 135 },
        // Tallest: rows over the knees shown one lower, the chest two, the head three.
        rows: [
          [32, 26, 35],
          [58, 1, -1],
        ],
      },
      'east',
    );

    expect(context.imageSmoothingEnabled).toBe(false);
    expect(calls).toEqual([
      ['clear', 0, 0, 45, 64],
      ['draw', 90, 0, 45, 64, 0, 0, 45, 64],
      // Only the tile's columns move.
      ['clear', 7, 32, 32, 26],
      ['draw', 97, 35, 32, 26, 7, 32, 32, 26],
      // A run with nothing to show is left empty.
      ['clear', 7, 58, 32, 1],
    ]);
  });

  it('leaves a character without a height as drawn', () => {
    const { calls, context } = recorder();
    drawPreviewFacing(
      context as never,
      {} as CanvasImageSource,
      {
        id: 1,
        species: 'human',
        image: 'data:image/png;base64,32x32',
        width: 32,
        height: 32,
        x: 0,
        y: 0,
        frames: { north: 0, south: 32, east: 64, west: 96 },
      },
      'south',
    );

    expect(calls).toEqual([
      ['clear', 0, 0, 32, 32],
      ['draw', 32, 0, 32, 32, 0, 0, 32, 32],
    ]);
  });
});
