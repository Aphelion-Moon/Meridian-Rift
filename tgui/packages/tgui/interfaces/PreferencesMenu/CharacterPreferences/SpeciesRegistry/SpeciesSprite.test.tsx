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
  it('fits a larger mob by a whole number and stands it on the floor', () => {
    const view = render(
      <PreviewFrame
        preview={{
          species: 'human',
          image: 'species_self_test_64x48.png',
          width: 64,
          height: 48,
          frames: { north: 0, south: 64, east: 128, west: 192 },
        }}
        dir="west"
        box={256}
      />,
    );
    const frame = view.container.querySelector(
      '.SpeciesSprite__frame',
    ) as HTMLElement;
    const style = getComputedStyle(frame);

    // 256 / 64 is 4: the width fills the box, and the height leaves 64px above.
    expect(frame.style.transform).toBe('scale(4)');
    expect(frame.style.left).toBe('0px');
    expect(frame.style.top).toBe('64px');
    expect(frame.style.backgroundImage).toContain(
      'species_self_test_64x48.png',
    );
    expect(frame.style.backgroundPosition).toStartWith('-192px');
    expect(style.position).toBe('absolute');
    expect(style.transformOrigin).toBe('top left');
    expect(style.imageRendering).toBe('pixelated');
  });
});
