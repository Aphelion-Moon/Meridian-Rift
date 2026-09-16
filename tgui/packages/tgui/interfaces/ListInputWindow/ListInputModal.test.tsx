import { afterAll, beforeAll, expect, it } from 'bun:test';
import { join } from 'node:path';
import { render, screen } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';

import { ListInputModal } from './ListInputModal';

let productionStyle: HTMLStyleElement;

beforeAll(async () => {
  const [componentCss, listInputCss] = await Promise.all([
    compileAsync(
      join(import.meta.dir, '../../styles/meridianos/_components.scss'),
    ),
    compileAsync(
      join(import.meta.dir, '../../styles/interfaces/ListInput.scss'),
    ),
  ]);
  productionStyle = document.createElement('style');
  productionStyle.textContent = componentCss.css + listInputCss.css;
  document.head.appendChild(productionStyle);
});

afterAll(() => productionStyle.remove());

it('wraps a long prompt instead of hiding it behind an ellipsis', () => {
  const message = 'Which custom work do you want to continue?';
  render(
    <div className="theme-console">
      <ListInputModal
        items={['Left arm tattoo for Tanner Stough']}
        default_item="Left arm tattoo for Tanner Stough"
        message={message}
        on_selected={() => undefined}
        on_cancel={() => undefined}
      />
    </div>,
  );

  const style = getComputedStyle(screen.getByText(message));
  expect(style.whiteSpace).toBe('normal');
  expect(style.overflow).toBe('visible');
  expect(style.textOverflow).toBe('clip');
});
