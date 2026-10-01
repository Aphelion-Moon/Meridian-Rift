// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it } from 'bun:test';
import { act, renderHook } from '@testing-library/react';

import { setTried, useIsTried, useTried } from './tryOn';

afterEach(() => {
  act(() => setTried(null));
});

describe('what the drawer tries on', () => {
  it('tells everything that shows it', () => {
    const shown = renderHook(() => useTried());
    expect(shown.result.current).toBeNull();
    act(() => setTried('Fox'));
    expect(shown.result.current).toBe('Fox');
    act(() => setTried(null));
    expect(shown.result.current).toBeNull();
  });

  it('draws a pick again only when it starts or stops being tried on', () => {
    let foxRenders = 0;
    let stripeRenders = 0;
    let otherRenders = 0;
    const fox = renderHook(() => {
      foxRenders++;
      return useIsTried('Fox');
    });
    const stripe = renderHook(() => {
      stripeRenders++;
      return useIsTried('Back Stripe');
    });
    renderHook(() => {
      otherRenders++;
      return useIsTried('Socks');
    });
    act(() => setTried('Fox'));
    act(() => setTried('Back Stripe'));
    expect(fox.result.current).toBe(false);
    expect(stripe.result.current).toBe(true);
    // Fox went on and off; Back Stripe went on; Socks never moved.
    expect(foxRenders).toBe(3);
    expect(stripeRenders).toBe(2);
    expect(otherRenders).toBe(1);
  });
});
