// THIS IS AN APHELION UI FILE
import { expect, it, mock } from 'bun:test';
import { act, render, screen } from '@testing-library/react';

import { AlphaBar } from './AlphaBar';

it('reports the alpha under the pointer through Interactive, from the floor at the left end', () => {
  const onChange = mock();
  render(
    <AlphaBar hsva={{ h: 0, s: 100, v: 100, a: 1 }} onChange={onChange} />,
  );
  const slider = screen.getByRole('slider', { name: 'Alpha' });
  slider.getBoundingClientRect = () =>
    ({ left: 0, top: 0, width: 200, height: 12 }) as DOMRect;
  // happy-dom's pointer events carry no pageX, which Interactive measures from.
  const press = new PointerEvent('pointerdown', {
    bubbles: true,
    pointerId: 1,
  });
  Object.defineProperties(press, {
    pageX: { value: 50 },
    pageY: { value: 6 },
  });
  act(() => {
    slider.dispatchEvent(press);
  });
  // A quarter of the way from the floor, 0.25, to opaque.
  expect(onChange).toHaveBeenCalledWith({ a: 0.4375 });
});
