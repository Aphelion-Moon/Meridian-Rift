// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  mock,
  spyOn,
} from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import { ByondUi } from './ByondUi';
import { MeridianThemePicker } from './MeridianThemePicker';

let mapRect = { left: 220, top: 90, width: 610, height: 598 };
let nativeReads = 0;
let uiScale = 1;
const originalWidth = window.innerWidth;
const originalHeight = window.innerHeight;
const originalFontSize = document.documentElement.style.fontSize;
const originalOffsetWidth = Object.getOwnPropertyDescriptor(
  HTMLElement.prototype,
  'offsetWidth',
)!;
const rect = (left: number, top: number, width: number, height: number) =>
  ({
    left,
    top,
    width,
    height,
    right: left + width,
    bottom: top + height,
    x: left,
    y: top,
    toJSON: () => ({}),
  }) as DOMRect;

beforeEach(() => {
  window.innerWidth = 850;
  window.innerHeight = 708;
  document.documentElement.style.fontSize = '12px';
  mapRect = { left: 220, top: 90, width: 610, height: 598 };
  nativeReads = 0;
  uiScale = 1;
  spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockImplementation(
    function (this: HTMLElement) {
      if (this.hasAttribute('data-byond-ui')) {
        nativeReads++;
        return rect(
          mapRect.left * uiScale,
          mapRect.top * uiScale,
          mapRect.width * uiScale,
          mapRect.height * uiScale,
        );
      }
      if (this.classList.contains('MeridianThemePicker__trigger'))
        return rect(
          Math.min(800 * uiScale, window.innerWidth - 50 * uiScale),
          8 * uiScale,
          24 * uiScale,
          24 * uiScale,
        );
      if (this.classList.contains('MeridianThemePicker__heading'))
        return rect(0, 0, 264 * uiScale, 30 * uiScale);
      if (this.classList.contains('MeridianThemePicker__option'))
        return rect(0, 0, 250 * uiScale, 32 * uiScale);
      const floating = this.closest<HTMLElement>(
        '.MeridianThemePicker__floating',
      );
      if (floating) {
        const menu = floating.querySelector<HTMLElement>(
          '.MeridianThemePicker__menu',
        );
        return rect(
          (Number.parseFloat(floating.style.left) || 0) * uiScale,
          (Number.parseFloat(floating.style.top) || 0) * uiScale,
          (Number.parseFloat(floating.style.width) ||
            Math.min(264, window.innerWidth / uiScale - 16)) * uiScale,
          Math.min(
            520,
            window.innerHeight / uiScale - 66,
            Number.parseFloat(menu?.style.maxHeight || '') || 520,
          ) * uiScale,
        );
      }
      return rect(0, 0, 0, 0);
    },
  );
  Object.defineProperty(HTMLElement.prototype, 'offsetWidth', {
    configurable: true,
    get() {
      if (this.classList.contains('MeridianThemePicker__trigger')) return 24;
      if (this.closest('.MeridianThemePicker__floating'))
        return this.getBoundingClientRect().width / uiScale;
      return 0;
    },
  });
});

afterEach(() => {
  cleanup();
  mock.restore();
  Object.defineProperty(
    HTMLElement.prototype,
    'offsetWidth',
    originalOffsetWidth,
  );
  window.innerWidth = originalWidth;
  window.innerHeight = originalHeight;
  document.documentElement.style.fontSize = originalFontSize;
});

function Fixture({ tick = 0, native = true }) {
  return (
    <>
      <MeridianThemePicker value="meridian_aphelion" onChange={() => {}} />
      {native && <ByondUi params={{ id: 'camera_test', type: 'map' }} />}
      <span>{tick}</span>
      <button type="button">Another control</button>
    </>
  );
}

const trigger = () =>
  screen.getByRole('button', {
    name: /change base interface theme/i,
  }) as HTMLButtonElement;
const open = async () => {
  await act(async () => {
    fireEvent.click(trigger());
  });
};

describe('theme picker around native UI', () => {
  it('moves left of the native camera and preserves keyboard focus', async () => {
    render(<Fixture />);
    await open();
    await waitFor(() => {
      const menu = screen.getByRole('menu');
      const box = menu.getBoundingClientRect();
      expect(box.right).toBeLessThanOrEqual(214);
      expect(box.width).toBeGreaterThanOrEqual(180);
      expect(
        document.activeElement === screen.getAllByRole('menuitemradio')[0],
      ).toBe(true);
    });
  });

  it('disables when no readable region fits and recovers after native UI unmounts', async () => {
    mapRect = { left: 80, top: 50, width: 770, height: 658 };
    const view = render(<Fixture />);
    await open();
    await waitFor(() => expect(trigger().disabled).toBe(true));
    expect(screen.queryAllByRole('menu').length).toBe(0);
    view.rerender(<Fixture native={false} />);
    await waitFor(() => expect(trigger().disabled).toBe(false));
    await open();
    expect(screen.getByRole('menu')).toBeTruthy();
  });

  it('does no native measurements on ordinary closed-menu backend updates', async () => {
    const view = render(<Fixture />);
    const readsAfterMount = nativeReads;
    for (let tick = 1; tick <= 100; tick++)
      view.rerender(<Fixture tick={tick} />);
    await act(async () => {});
    expect(nativeReads).toBe(readsAfterMount);
  });

  it('makes no extra native-control calls and stops measuring after dismissal', async () => {
    const winset = spyOn(Byond, 'winset');
    const view = render(<Fixture />);
    await open();
    const callsAfterMount = winset.mock.calls.length;
    await act(async () => {
      fireEvent.keyDown(screen.getByRole('menu'), { key: 'Escape' });
    });
    await waitFor(() => expect(screen.queryAllByRole('menu').length).toBe(0));
    expect(winset.mock.calls.length).toBe(callsAfterMount);
    const readsAfterClose = nativeReads;
    view.rerender(<Fixture tick={1} />);
    await act(async () => {});
    expect(nativeReads).toBe(readsAfterClose);
    winset.mockRestore();
  });

  it.each([
    2 / 3,
    1.25,
    1.5,
    2,
  ])('avoids the native viewport at CSS scale %p', async (scale) => {
    uiScale = scale;
    window.innerWidth = 850 * scale;
    window.innerHeight = 708 * scale;
    render(<Fixture />);
    await open();
    const box = screen.getByRole('menu').getBoundingClientRect();
    expect(box.right).toBeCloseTo(214 * scale);
    expect(box.left).toBeCloseTo(8 * scale);
    expect(box.width).toBeCloseTo(206 * scale);
  });

  it('coalesces a resize burst, closes the menu and recovers without extra winsets', async () => {
    const winset = spyOn(Byond, 'winset');
    render(<Fixture />);
    await open();
    const reads = nativeReads;
    const calls = winset.mock.calls.length;
    await act(async () => {
      for (let i = 0; i < 20; i++) window.dispatchEvent(new Event('resize'));
    });
    expect(trigger().getAttribute('aria-expanded')).toBe('false');
    await waitFor(() => expect(trigger().disabled).toBe(false));
    // One existing core resize render and one placement check, not 20 checks.
    expect(nativeReads - reads).toBe(2);
    expect(winset.mock.calls.length - calls).toBe(1);
    await open();
    expect(screen.queryAllByRole('menu').length).toBe(1);
  });

  it('re-enables a blocked picker when a resize creates enough room', async () => {
    mapRect = { left: 80, top: 50, width: 770, height: 658 };
    render(<Fixture />);
    await open();
    expect(trigger().disabled).toBe(true);
    mapRect = { left: 220, top: 90, width: 610, height: 598 };
    await act(async () => {
      window.dispatchEvent(new Event('resize'));
    });
    await waitFor(() => expect(trigger().disabled).toBe(false));
    await open();
    expect(
      screen.getByRole('menu').getBoundingClientRect().right,
    ).toBeLessThanOrEqual(214);
  });

  it('cancels a pending placement check on unmount', async () => {
    const view = render(<Fixture />);
    await open();
    await act(async () => {
      window.dispatchEvent(new Event('resize'));
    });
    view.unmount();
    const reads = nativeReads;
    await new Promise((resolve) => setTimeout(resolve, 200));
    expect(nativeReads).toBe(reads);
  });

  it('recovers when the first opening measured a menu clamped below readable size', async () => {
    window.innerWidth = 150;
    window.innerHeight = 120;
    render(<Fixture />);
    await open();
    expect(trigger().disabled).toBe(true);
    window.innerWidth = 850;
    window.innerHeight = 708;
    await act(async () => {
      window.dispatchEvent(new Event('resize'));
    });
    await waitFor(() => expect(trigger().disabled).toBe(false));
    await open();
    expect(screen.queryAllByRole('menu').length).toBe(1);
  });

  it('returns keyboard focus after automatic closure and recovery', async () => {
    render(<Fixture />);
    await open();
    await act(async () => {
      window.dispatchEvent(new Event('resize'));
    });
    await waitFor(() => expect(trigger().disabled).toBe(false));
    expect(document.activeElement === trigger()).toBe(true);
  });

  it('does not steal focus if another control was focused during recovery', async () => {
    render(<Fixture />);
    await open();
    await act(async () => {
      window.dispatchEvent(new Event('resize'));
    });
    const other = screen.getByRole('button', { name: 'Another control' });
    other.focus();
    await waitFor(() => expect(trigger().disabled).toBe(false));
    expect(document.activeElement === other).toBe(true);
  });

  it('returns focus when a newly mounted viewport blocks an already open menu', async () => {
    const view = render(<Fixture native={false} />);
    await open();
    mapRect = { left: 80, top: 50, width: 770, height: 658 };
    view.rerender(<Fixture />);
    await waitFor(() => expect(trigger().disabled).toBe(true));
    await waitFor(() =>
      expect(screen.queryAllByRole('menu', { hidden: true }).length).toBe(0),
    );
    view.rerender(<Fixture native={false} />);
    expect(trigger().disabled).toBe(false);
    expect(document.activeElement === trigger()).toBe(true);
  });

  it('waits for an already pending native resize before revealing a newly opened menu', async () => {
    render(<Fixture />);
    await act(async () => {
      window.dispatchEvent(new Event('resize'));
    });
    await open();
    expect(screen.queryAllByRole('menu').length).toBe(0);
    await waitFor(() => expect(screen.queryAllByRole('menu').length).toBe(1));
    expect(
      screen.getByRole('menu').getBoundingClientRect().right,
    ).toBeLessThanOrEqual(214);
  });
});
