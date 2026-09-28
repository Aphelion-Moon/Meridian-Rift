// THIS IS AN APHELION UI FILE
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { cleanup, render } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';

import { SPECIES_SPRITESHEETS } from './constants';
import { SpeciesSprite } from './SpeciesSprite';

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
