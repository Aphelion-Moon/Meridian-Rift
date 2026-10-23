// THIS IS AN APHELION UI FILE
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { compileAsync } from 'sass-embedded';
import { Button } from 'tgui-core/components';
import { MERIDIAN_THEME_IDS } from '../../../constants/theme';
import { MeridianThemePicker } from '../../../layouts/MeridianThemePicker';
/** The stylesheets under test live one level up from this directory. */
const styleRoot = join(import.meta.dir, '..');


let productionStyle: HTMLStyleElement;
let previousRootClasses: string;

beforeAll(async () => {
  const nodeModules = join(styleRoot, '../../../../node_modules');
  const { css } = await compileAsync(join(styleRoot, '../main.scss'), {
    importers: [
      {
        findFileUrl(url) {
          if (!url.startsWith('~')) {
            return null;
          }
          // Mirror the package's styles entry point; Sass resolves extensions
          // on the remaining webpack-style imports itself.
          return pathToFileURL(
            join(
              nodeModules,
              url === '~tgui-core/styles'
                ? 'tgui-core/styles/main.scss'
                : url.slice(1),
            ),
          );
        },
      },
    ],
  });
  productionStyle = document.createElement('style');
  productionStyle.textContent = css;
  document.head.appendChild(productionStyle);
  previousRootClasses = document.documentElement.className;
});

afterEach(() => {
  cleanup();
  document.documentElement.className = previousRootClasses;
});

afterAll(() => productionStyle.remove());

function luminance(color: string): number {
  const channels = color.startsWith('#')
    ? color
        .slice(1)
        .match(/.{2}/g)
        ?.map((channel) => Number.parseInt(channel, 16))
    : color.match(/[\d.]+/g)?.map(Number);
  if (channels?.length !== 3) {
    throw new Error(`Expected a computed opaque RGB color, received ${color}`);
  }
  return channels.reduce((total, channel, index) => {
    const value = channel / 255;
    const linear =
      value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    return total + linear * [0.2126, 0.7152, 0.0722][index];
  }, 0);
}

function contrast(foreground: string, background: string): number {
  const first = luminance(foreground);
  const second = luminance(background);
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

describe('MeridianOS selected control readability', () => {
  for (const theme of MERIDIAN_THEME_IDS) {
    it(`keeps the selected picker name and description readable in ${theme}`, async () => {
      document.documentElement.className = `theme-console theme-${theme}`;
      render(<MeridianThemePicker onChange={() => {}} value={theme} />);
      await act(async () => {
        fireEvent.click(
          screen.getByRole('button', {
            name: /change base interface theme/i,
          }),
        );
        await Promise.resolve();
      });

      const selected = screen.getByRole('menuitemradio', { checked: true });
      const background = getComputedStyle(selected).backgroundColor;
      // Read the real rendered descendants and the compiled production
      // cascade, including the description's own color declaration.
      for (const label of selected.querySelectorAll(
        '.MeridianThemePicker__label strong, .MeridianThemePicker__label span',
      )) {
        expect(
          contrast(getComputedStyle(label).color, background),
        ).toBeGreaterThanOrEqual(4.5);
      }
    });

    it(`uses the on-accent foreground for filled selected buttons in ${theme}`, () => {
      document.documentElement.className = `theme-console theme-${theme}`;
      render(
        <>
          <Button selected>Selected action</Button>
          <Button.Checkbox checked color="default">
            Checked action
          </Button.Checkbox>
        </>,
      );
      const canvas = getComputedStyle(document.documentElement).backgroundColor;
      for (const label of ['Selected action', 'Checked action']) {
        const control = screen.getByText(label).closest('.Button')!;
        expect(getComputedStyle(control).color).toBe(canvas);
      }
    });
  }
});

describe('Report window readability', () => {
  const token = (name: string) =>
    getComputedStyle(document.documentElement).getPropertyValue(name).trim();

  for (const theme of MERIDIAN_THEME_IDS) {
    it(`keeps the report window's hints, notices and choices readable in ${theme}`, () => {
      document.documentElement.className = `theme-console theme-${theme}`;
      render(
        <div className="BugReport">
          <div className="BugReport__hint">A brief overview of the issue</div>
          <div className="BugReport__error">Give it a title.</div>
          <div className="BugReport__notice BugReport__notice--warning">
            <span className="BugReport__noticeIcon">!</span>
          </div>
          <div className="BugReport__notice BugReport__notice--danger">
            <span className="BugReport__noticeIcon">!</span>
          </div>
          <div className="BugReport__notice BugReport__notice--info">
            <span className="BugReport__noticeIcon">i</span>
          </div>
          <span className="BugReport__chip BugReport__chip--on">Lag</span>
        </div>,
      );
      const base = token('--console-surface-base');
      const raised = token('--console-surface-raised');
      const color = (selector: string, property = 'color') =>
        getComputedStyle(document.querySelector(selector)!).getPropertyValue(
          property,
        );
      // Hints sit on the page and inside cards and notices
      for (const background of [base, raised])
        expect(
          contrast(color('.BugReport__hint'), background),
        ).toBeGreaterThanOrEqual(4.5);
      expect(contrast(color('.BugReport__error'), base)).toBeGreaterThanOrEqual(
        4.5,
      );
      expect(
        contrast(color('.BugReport__error', 'border-left-color'), base),
      ).toBeGreaterThanOrEqual(3);
      // A notice's bar and icon carry its tone, beside words that say it too
      for (const tone of ['warning', 'danger', 'info']) {
        const notice = `.BugReport__notice--${tone}`;
        expect(
          contrast(color(notice, 'border-left-color'), raised),
        ).toBeGreaterThanOrEqual(3);
        expect(
          contrast(color(`${notice} .BugReport__noticeIcon`), raised),
        ).toBeGreaterThanOrEqual(3);
      }
      expect(
        contrast(color('.BugReport__chip--on', 'border-top-color'), raised),
      ).toBeGreaterThanOrEqual(3);
    });
  }
});
