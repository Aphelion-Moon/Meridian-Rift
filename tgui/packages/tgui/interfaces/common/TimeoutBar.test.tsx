// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import { cleanup, render, screen } from '@testing-library/react';

import { TimeoutBar } from './TimeoutBar';

describe('TimeoutBar', () => {
  it('exposes normalized time remaining through progressbar semantics', () => {
    render(<TimeoutBar value={0.62} />);

    const progressbar = screen.getByRole('progressbar', {
      name: 'Time remaining',
    });
    expect(progressbar.getAttribute('aria-valuemin')).toBe('0');
    expect(progressbar.getAttribute('aria-valuemax')).toBe('1');
    expect(progressbar.getAttribute('aria-valuenow')).toBe('0.62');
    expect(progressbar.getAttribute('aria-valuetext')).toBe('62% remaining');
    expect(
      progressbar.querySelector<HTMLElement>('.TimeoutBar__progress')?.style
        .transform,
    ).toBe('scaleX(0.62)');

    cleanup();
  });

  it('clamps local visual and ARIA values without changing its input', () => {
    const input = { value: 1.75 };
    const view = render(<TimeoutBar value={input.value} />);
    const progressbar = screen.getByRole('progressbar');

    expect(progressbar.getAttribute('aria-valuenow')).toBe('1');
    expect(
      progressbar.querySelector<HTMLElement>('.TimeoutBar__progress')?.style
        .transform,
    ).toBe('scaleX(1)');
    expect(input.value).toBe(1.75);

    view.rerender(<TimeoutBar value={-0.5} />);
    expect(progressbar.getAttribute('aria-valuenow')).toBe('0');
    expect(
      progressbar.querySelector<HTMLElement>('.TimeoutBar__progress')?.style
        .transform,
    ).toBe('scaleX(0)');

    cleanup();
  });

  it('falls back safely for non-finite values and accepts a custom label', () => {
    render(<TimeoutBar ariaLabel="Selection timeout" value={Number.NaN} />);

    const progressbar = screen.getByRole('progressbar', {
      name: 'Selection timeout',
    });
    expect(progressbar.getAttribute('aria-valuenow')).toBe('0');
    expect(progressbar.getAttribute('aria-valuetext')).toBe('0% remaining');

    cleanup();
  });

  it('keeps the same element while descending', () => {
    const view = render(<TimeoutBar value={0.75} />);
    const progressbar = screen.getByRole('progressbar');

    view.rerender(<TimeoutBar value={0.25} />);

    expect(screen.getByRole('progressbar')).toBe(progressbar);
    expect(progressbar.getAttribute('aria-valuenow')).toBe('0.25');
    expect(
      progressbar.querySelector<HTMLElement>('.TimeoutBar__progress')?.style
        .transform,
    ).toBe('scaleX(0.25)');

    cleanup();
  });
});
