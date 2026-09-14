// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render } from '@testing-library/react';
import { DiagnosticLoader } from './DiagnosticLoader';

const setDocumentHidden = (hidden: boolean) => {
  Object.defineProperty(document, 'hidden', {
    configurable: true,
    value: hidden,
  });
};

beforeEach(() => setDocumentHidden(false));
afterEach(() => setDocumentHidden(false));

describe('DiagnosticLoader', () => {
  it('preserves the base layers and a single progressbar with decorative linework', () => {
    const view = render(<DiagnosticLoader />);
    const progressbar = view.getByRole('progressbar');

    expect(view.getByText('Please wait…')).toBeDefined();
    expect(progressbar.getAttribute('aria-valuenow')).toBeNull();
    expect(progressbar.getAttribute('aria-valuemin')).toBeNull();
    expect(progressbar.getAttribute('aria-valuemax')).toBeNull();
    expect(progressbar.parentElement?.classList).toContain(
      'DiagnosticLoader--indeterminate',
    );

    const light = progressbar.querySelector('.DiagnosticLoader__light');
    expect(light?.getAttribute('aria-hidden')).toBe('true');
    expect(light?.querySelector('[role], [id], [tabindex]')).toBeNull();
    const acquisition = progressbar.querySelector(
      '.DiagnosticLoader__acquisition',
    );
    expect(acquisition?.getAttribute('aria-hidden')).toBe('true');
    expect(acquisition?.getAttribute('focusable')).toBe('false');
    expect(
      acquisition?.querySelector('[role], [id], [tabindex], text'),
    ).toBeNull();
    expect(view.getAllByRole('progressbar')).toHaveLength(1);
    const layers = Array.from(progressbar.children).filter(
      (layer) => layer !== light && layer !== acquisition,
    );
    expect(layers).toHaveLength(8);
    expect(layers.map((layer) => layer.className)).toEqual([
      'DiagnosticLoader__tickCrown',
      'DiagnosticLoader__outerCage',
      'DiagnosticLoader__progressTrack',
      'DiagnosticLoader__progressFill',
      'DiagnosticLoader__innerMarks',
      'DiagnosticLoader__nodes',
      'DiagnosticLoader__origin',
      'DiagnosticLoader__core',
    ]);
  });

  it('clamps determinate visual and ARIA values without changing the range', () => {
    const view = render(
      <DiagnosticLoader value={125} minValue={0} maxValue={100} />,
    );
    const progressbar = view.getByRole('progressbar');

    expect(progressbar.getAttribute('aria-valuemin')).toBe('0');
    expect(progressbar.getAttribute('aria-valuemax')).toBe('100');
    expect(progressbar.getAttribute('aria-valuenow')).toBe('100');
    expect(
      progressbar.style.getPropertyValue('--diagnostic-loader-progress'),
    ).toBe('1');
    expect(
      progressbar.style.getPropertyValue('--diagnostic-loader-angle'),
    ).toBe('360deg');

    view.rerender(<DiagnosticLoader value={-25} minValue={0} maxValue={100} />);
    expect(progressbar.getAttribute('aria-valuenow')).toBe('0');
    expect(
      progressbar.style.getPropertyValue('--diagnostic-loader-progress'),
    ).toBe('0');
  });

  it('uses the conventional zero-to-one range when bounds are omitted', () => {
    const view = render(<DiagnosticLoader value={0.5} />);
    const progressbar = view.getByRole('progressbar');

    expect(progressbar.getAttribute('aria-valuemin')).toBe('0');
    expect(progressbar.getAttribute('aria-valuemax')).toBe('1');
    expect(progressbar.getAttribute('aria-valuenow')).toBe('0.5');
    expect(
      progressbar.style.getPropertyValue('--diagnostic-loader-progress'),
    ).toBe('0.5');
  });

  it('falls back to indeterminate semantics for non-finite or invalid data', () => {
    const cases = [
      <DiagnosticLoader key="missing" />,
      <DiagnosticLoader key="nan" value={Number.NaN} />,
      <DiagnosticLoader key="infinity" value={Number.POSITIVE_INFINITY} />,
      <DiagnosticLoader key="minimum" value={1} minValue={Number.NaN} />,
      <DiagnosticLoader key="maximum" value={1} maxValue={Infinity} />,
      <DiagnosticLoader key="equal" value={1} minValue={1} maxValue={1} />,
      <DiagnosticLoader key="reversed" value={1} minValue={2} maxValue={1} />,
    ];

    for (const component of cases) {
      const view = render(component);
      const progressbar = view.getByRole('progressbar');
      expect(progressbar.getAttribute('aria-valuenow')).toBeNull();
      expect(progressbar.parentElement?.classList).toContain(
        'DiagnosticLoader--indeterminate',
      );
      view.unmount();
    }
  });

  it('supports sizing, custom content, accessible naming, and extra classes', () => {
    const view = render(
      <DiagnosticLoader
        ariaLabel="Recalibrating navigation array"
        className="custom-loader"
        detail={<span>Stage 2 of 4</span>}
        label={<strong>Calibration</strong>}
        size="large"
      />,
    );
    const root = view.getByRole('progressbar').parentElement!;
    const progressbar = view.getByLabelText('Recalibrating navigation array');
    const detail = view.getByText('Stage 2 of 4');

    expect(root.classList).toContain('DiagnosticLoader--large');
    expect(root.classList).toContain('custom-loader');
    expect(progressbar.getAttribute('aria-labelledby')).toBeNull();
    expect(progressbar.getAttribute('aria-describedby')).toBe(
      detail.parentElement!.id,
    );
    expect(view.getByText('Calibration')).toBeDefined();
  });

  it('keeps real determinate progress in the explicit reduced-motion study state', () => {
    const view = render(
      <DiagnosticLoader
        className="DiagnosticLoader--motion-reduced"
        value={50}
        minValue={0}
        maxValue={100}
      />,
    );
    const progressbar = view.getByRole('progressbar');
    const root = progressbar.parentElement!;

    expect(root.classList).toContain('DiagnosticLoader--motion-reduced');
    expect(progressbar.getAttribute('aria-valuenow')).toBe('50');
    expect(
      progressbar.style.getPropertyValue('--diagnostic-loader-angle'),
    ).toBe('180deg');
  });

  it('pauses motion while hidden and removes its visibility listener', () => {
    const addListener = spyOn(document, 'addEventListener');
    const removeListener = spyOn(document, 'removeEventListener');
    const view = render(<DiagnosticLoader />);
    const root = view.getByRole('progressbar').parentElement!;
    const registration = addListener.mock.calls.find(
      ([eventName]) => eventName === 'visibilitychange',
    );

    expect(registration).toBeDefined();
    expect(root.dataset.motion).toBe('running');

    setDocumentHidden(true);
    fireEvent(document, new Event('visibilitychange'));
    expect(root.dataset.motion).toBe('paused');

    setDocumentHidden(false);
    fireEvent(document, new Event('visibilitychange'));
    expect(root.dataset.motion).toBe('running');

    view.unmount();
    expect(removeListener).toHaveBeenCalledWith(
      'visibilitychange',
      registration![1],
    );

    addListener.mockRestore();
    removeListener.mockRestore();
  });
});
