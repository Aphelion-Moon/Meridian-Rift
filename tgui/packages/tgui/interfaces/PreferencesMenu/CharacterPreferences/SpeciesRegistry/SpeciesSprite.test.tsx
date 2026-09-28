// THIS IS AN APHELION UI FILE
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { cleanup, render } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';

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
    view.container.querySelector('.SpeciesSprite__frame') as HTMLElement;

  it('stands a mob that fits its tile exactly where a species sprite stands', () => {
    const view = render(
      <PreviewFrame
        preview={{
          species: 'human',
          image: 'species_self_test_32x32.png',
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

    expect(frame.style.transform).toBe('scale(8)');
    expect(frame.style.left).toBe('0px');
    expect(frame.style.top).toBe('0px');
  });

  it('keeps wings and big ears in the box, centred on the mob, feet on the floor', () => {
    // Wings reaching 7px past each side, and ears drawn in a 48px frame that
    // starts 8px below the feet, as the game draws them.
    const view = render(
      <PreviewFrame
        preview={{
          species: 'mammal',
          image: 'species_self_test_45x48.png',
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
    expect(frame.style.transform).toBe('scale(5)');
    // The tile's centre on the box's centre, and its floor on the box's floor.
    expect(frame.style.left).toBe(`${128 - (7 + 16) * 5}px`);
    expect(frame.style.top).toBe(`${256 - (48 - 8) * 5}px`);
    expect(frame.style.backgroundImage).toContain(
      'species_self_test_45x48.png',
    );
    expect(frame.style.backgroundPosition).toStartWith('-135px');
    expect(style.position).toBe('absolute');
    expect(style.transformOrigin).toBe('top left');
    expect(style.imageRendering).toBe('pixelated');
    // What hangs below the feet may show over the floor.
    expect(getComputedStyle(frame.parentElement as HTMLElement).overflow).toBe(
      'visible',
    );
  });
});
