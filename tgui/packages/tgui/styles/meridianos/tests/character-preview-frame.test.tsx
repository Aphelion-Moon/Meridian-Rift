// THIS IS AN APHELION UI FILE
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { cleanup, render } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';

import {
  PreviewFrame,
  type PreviewMotif,
} from '../../../interfaces/PreferencesMenu/CharacterPreferences/CharacterPreview';

/** The stylesheets under test live one level up from this directory. */
const styleRoot = join(import.meta.dir, '..');
const MOTIFS = ['portrait', 'mirror', 'scanner'] as const;
let productionStyle: HTMLStyleElement;

beforeAll(async () => {
  productionStyle = document.createElement('style');
  productionStyle.textContent = (
    await compileAsync(join(styleRoot, '_character_preview.scss'))
  ).css;
  document.head.appendChild(productionStyle);
});

afterEach(cleanup);

afterAll(() => productionStyle.remove());

/** How many of each of the frame's parts show, in a theme's window, for a motif. */
function shownParts(themeClasses: string, motif: PreviewMotif) {
  const view = render(
    <div className={themeClasses}>
      <div className={`CharacterPreview CharacterPreview--${motif}`}>
        <span className="CharacterPreview__rule" />
        <PreviewFrame />
      </div>
    </div>,
  );
  const shown = (part: string) =>
    [...view.container.querySelectorAll(`.CharacterPreview__${part}`)].filter(
      (element) => getComputedStyle(element).display !== 'none',
    ).length;
  const parts = {
    marks: shown('mark'),
    clips: shown('clip'),
    glass: shown('glass'),
    rule: shown('rule'),
    trim: shown('trim'),
  };
  cleanup();
  return parts;
}

describe('character preview frame', () => {
  it('marks each tab with its own motif and no other', () => {
    expect(shownParts('theme-meridian_aphelion', 'portrait')).toEqual({
      marks: 4,
      clips: 0,
      glass: 0,
      rule: 0,
      trim: 1,
    });
    expect(shownParts('theme-meridian_aphelion', 'mirror')).toEqual({
      marks: 0,
      clips: 4,
      glass: 1,
      rule: 0,
      trim: 1,
    });
    expect(shownParts('theme-meridian_aphelion', 'scanner')).toEqual({
      marks: 0,
      clips: 0,
      glass: 0,
      rule: 1,
      trim: 1,
    });
  });

  it('keeps Classic and Highline to a plain edge on every tab', () => {
    for (const theme of [
      'theme-nanotrasen theme-meridian_classic',
      'theme-meridian_highline',
    ]) {
      for (const motif of MOTIFS) {
        expect(shownParts(theme, motif), `${theme} ${motif}`).toEqual({
          marks: 0,
          clips: 0,
          glass: 0,
          rule: 0,
          trim: 0,
        });
      }
    }
  });

  it('lets a fastened or shaped casing stand for the corners, and still measures and mirrors', () => {
    for (const theme of [
      'theme-meridian_hephaestus',
      'theme-meridian_foundry',
      'theme-meridian_wastelander',
    ]) {
      expect(shownParts(theme, 'portrait').marks, theme).toBe(0);
      expect(shownParts(theme, 'mirror').clips, theme).toBe(4);
      expect(shownParts(theme, 'scanner').rule, theme).toBe(1);
    }
    // Scavenger's corner marks are its casing's rivets, on every tab.
    for (const motif of MOTIFS) {
      expect(shownParts('theme-meridian_scavenger', motif).marks, motif).toBe(
        4,
      );
    }
    // Synapse's cut stands for its top right corner.
    expect(shownParts('theme-meridian_synapse', 'portrait').marks).toBe(3);
  });

  it('gives every other theme its four corners on the Character tab', () => {
    for (const theme of [
      'theme-meridian_augmentation',
      'theme-meridian_cyberpunk',
      'theme-meridian_diagnostic',
      'theme-meridian_electra',
      'theme-meridian_hotline',
      'theme-meridian_shadowbroker',
      'theme-meridian_vector',
    ]) {
      expect(shownParts(theme, 'portrait').marks, theme).toBe(4);
    }
  });
});
