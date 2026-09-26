// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { compileAsync, compileStringAsync } from 'sass-embedded';

import {
  MERIDIAN_THEMES,
  type MeridianThemePalette,
} from '../../../constants/theme';
/** The stylesheets under test live one level up from this directory. */
const styleRoot = join(import.meta.dir, '..');


const PALETTE_TOKENS = {
  canvas: 'surface-canvas',
  panel: 'surface-base',
  raised: 'surface-raised',
  recessed: 'surface-recessed',
  boundary: 'border-control',
  text: 'text-primary',
  mutedText: 'text-secondary',
  accent: 'interaction-accent',
  secondaryAccent: 'interaction-selected',
  focus: 'interaction-focus',
} satisfies Record<keyof MeridianThemePalette, string>;

describe('Meridian theme palettes', () => {
  it('emits a new palette by color name regardless of field order', async () => {
    const { css } = await compileStringAsync(
      `@use 'palette';
      .theme-example {
        @include palette.emit((
          focus: #101010,
          accent: #080808,
          secondaryAccent: #090909,
          text: #060606,
          mutedText: #070707,
          boundary: #050505,
          recessed: #040404,
          raised: #030303,
          panel: #020202,
          canvas: #010101,
        ));
      }`,
      { loadPaths: [styleRoot] },
    );

    const colors = [
      '#010101',
      '#020202',
      '#030303',
      '#040404',
      '#050505',
      '#060606',
      '#070707',
      '#080808',
      '#090909',
      '#101010',
    ];
    Object.values(PALETTE_TOKENS).forEach((token, index) => {
      expect(css).toContain(`--console-${token}: ${colors[index]};`);
    });
    expect(css).toContain('--console-surface-overlay: #030303;');
  });

  it('keeps every compiled theme consistent with its preview and contrast palette', async () => {
    const { css } = await compileAsync(join(styleRoot, '_themes.scss'));
    const palettes = new Map(
      Array.from(
        css.matchAll(/\.theme-([\w]+):root,\s*\.theme-\1\s*\{([^}]+)\}/g),
        ([, id, declarations]) => [id, declarations.toLowerCase()],
      ),
    );

    expect([...palettes.keys()].sort()).toEqual(
      MERIDIAN_THEMES.map(({ id }) => id).sort(),
    );
    for (const { id, palette } of MERIDIAN_THEMES) {
      for (const [color, token] of Object.entries(PALETTE_TOKENS)) {
        expect(palettes.get(id), `${id}: ${color}`).toContain(
          `--console-${token}: ${palette[color].toLowerCase()};`,
        );
      }
      expect(palettes.get(id)).toContain(
        `--console-surface-overlay: ${palette.raised.toLowerCase()};`,
      );
    }
  });
});
