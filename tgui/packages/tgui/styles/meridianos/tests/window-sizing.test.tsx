// THIS IS AN APHELION UI FILE
import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { render } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';
import { ListInputModal } from '../../../interfaces/ListInputWindow/ListInputModal';

let style: HTMLStyleElement;

beforeAll(async () => {
  const root = join(import.meta.dir, '..');
  const sheets = await Promise.all(
    [
      '../../../../node_modules/tgui-core/styles/components/Section.scss',
      '../../../../node_modules/tgui-core/styles/components/Stack.scss',
      '_window-sizing.scss',
      '_decoration.scss',
      '../interfaces/ListInput.scss',
      '../layouts/Window.scss',
    ].map(async (path) => (await compileAsync(join(root, path))).css),
  );
  style = document.createElement('style');
  style.textContent = sheets.join('\n');
  document.head.append(style);
});

afterAll(() => style.remove());

describe('Prompt fill layout', () => {
  it('lets the teleport list fill a resized window after opening measurement', () => {
    const prompt = (measuring: boolean, height = 300) => (
      <div className="theme-console theme-meridian_aphelion">
        <div
          key={`${measuring}-${height}`}
          className={`Window MeridianContentFit MeridianChoicePrompt${measuring ? ' MeridianContentFit--measuring' : ''}`}
          style={{ height }}
        >
          <div className="Window__content">
            <div className="Window__contentPadding">
              <ListInputModal
                items={Array.from({ length: 30 }, (_, i) => `Area ${i}`)}
                default_item="Area 0"
                message="Area to jump to"
                on_selected={() => {}}
                on_cancel={() => {}}
              />
            </div>
          </div>
        </div>
      </div>
    );
    const view = render(prompt(true));
    const root = view.container.querySelector<HTMLElement>('.Window')!;
    const padding = root.querySelector<HTMLElement>('.Window__contentPadding')!;
    const list = root.querySelector<HTMLElement>('.Section--scrollable')!;
    expect(getComputedStyle(padding).height).toBe('auto');
    expect(getComputedStyle(list).height).toBe('192px');

    // Happy DOM checks the real cascade, not pixel layout or gutter calc().
    // Fresh fixtures avoid its stale descendant styles after ancestor changes.
    for (const height of [300, 600]) {
      view.rerender(prompt(false, height));
      const section = view.container.querySelector<HTMLElement>('.Section')!;
      const stack = view.container.querySelector<HTMLElement>('.Stack--fill')!;
      const list = view.container.querySelector<HTMLElement>(
        '.Section--scrollable',
      )!;
      expect(getComputedStyle(section).height).toBe('100%');
      expect(getComputedStyle(stack).height).toBe('100%');
      expect(getComputedStyle(list).height).toBe('100%');
      expect(
        getComputedStyle(list.querySelector('.Section__content')!).overflowY,
      ).toBe('auto');
    }
  });
});
