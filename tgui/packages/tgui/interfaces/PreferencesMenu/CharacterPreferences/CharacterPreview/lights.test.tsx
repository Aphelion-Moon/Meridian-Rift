// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { Provider } from 'jotai';
import type { ComponentProps } from 'react';

import { store } from '../../../../events/store';
import { CharacterPreview } from '.';
import { previewLightsOffAtom } from './lights';
import { previewTurnAtom } from './turn';

function renderPreview(
  props: Partial<ComponentProps<typeof CharacterPreview>> = {},
) {
  return render(
    <Provider store={store}>
      <CharacterPreview height="480px" {...props} />
    </Provider>,
  );
}

/** A press at (x, y) on `target`, dragged across the box to the right and let go. */
function dragAcross(target: Element, box: Element, x: number, y: number) {
  fireEvent.pointerDown(target, {
    button: 0,
    pointerId: 1,
    clientX: x,
    clientY: y,
  });
  fireEvent.pointerMove(box, { pointerId: 1, clientX: x + 200, clientY: y });
  fireEvent.pointerUp(box, { pointerId: 1, clientX: x + 200, clientY: y });
}

afterEach(() => {
  store.set(previewLightsOffAtom, false);
  store.set(previewTurnAtom, 0);
});

describe('the preview lights key', () => {
  it('is on the frame only where the tab asks for it', () => {
    renderPreview();
    expect(screen.queryByRole('button', { name: 'Lights off' })).toBeNull();
  });

  it('turns the lights off and back on, pressed while they are off', () => {
    renderPreview({ motif: 'mirror', lightKey: true });
    const key = screen.getByRole('button', { name: 'Lights off' });
    expect(key.getAttribute('aria-pressed')).toBe('false');

    fireEvent.click(key);
    expect(store.get(previewLightsOffAtom)).toBe(true);
    expect(key.getAttribute('aria-pressed')).toBe('true');

    fireEvent.click(key);
    expect(store.get(previewLightsOffAtom)).toBe(false);
    expect(key.getAttribute('aria-pressed')).toBe('false');
  });

  it('keeps a press on it from turning the character', () => {
    const { container } = renderPreview({ lightKey: true });
    const box = container.querySelector('.CharacterPreview');
    if (!box) {
      throw new Error('no preview box');
    }
    dragAcross(
      screen.getByRole('button', { name: 'Lights off' }),
      box,
      100,
      400,
    );
    expect(store.get(previewTurnAtom)).toBe(0);

    // The same drag from beside it turns the character as ever.
    dragAcross(box, box, 100, 400);
    expect(store.get(previewTurnAtom)).not.toBe(0);
  });
});
