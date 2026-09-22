// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import { placeNativeMenu, preferredMenuRect } from './nativeMenuPlacement';

const bounds = { left: 8, top: 40, right: 842, bottom: 700 };
const preferred = { left: 552, top: 44, width: 264, height: 520 };
const minimum = { width: 180, height: 138 };

describe('native menu placement', () => {
  it.each([
    ['bottom-end', 460, 344],
    ['top-start', 700, 196],
    ['left-start', 432, 300],
    ['right-end', 728, 240],
  ])('preserves requested anchor placement %s', (placement, left, top) => {
    expect(
      preferredMenuRect(
        { left: 700, top: 300, right: 724, bottom: 340 },
        { width: 264, height: 100 },
        placement as string,
        4,
      ),
    ).toEqual({ left, top, width: 264, height: 100 });
  });
  it('keeps the requested position when the native control does not cover it', () => {
    expect(
      placeNativeMenu(bounds, preferred, minimum, [
        { left: 10, top: 70, right: 200, bottom: 600 },
      ]),
    ).toEqual(preferred);
  });

  it('fits a scrollable, narrower menu beside the security camera viewport', () => {
    expect(
      placeNativeMenu(bounds, preferred, minimum, [
        { left: 220, top: 90, right: 830, bottom: 688 },
      ]),
    ).toEqual({ left: 8, top: 44, width: 212, height: 520 });
  });

  it('uses the opposite free side when a native control occupies the left', () => {
    expect(
      placeNativeMenu(bounds, { ...preferred, left: 8 }, minimum, [
        { left: 8, top: 40, right: 530, bottom: 700 },
      ]),
    ).toEqual({ left: 530, top: 44, width: 264, height: 520 });
  });

  it('disables placement when only unreadable slivers remain', () => {
    expect(
      placeNativeMenu(bounds, preferred, minimum, [
        { left: 100, top: 90, right: 842, bottom: 700 },
      ]),
    ).toBeNull();
  });

  it('finds space between multiple native controls and clamps the scroller height', () => {
    expect(
      placeNativeMenu(bounds, preferred, minimum, [
        { left: 8, top: 40, right: 290, bottom: 700 },
        { left: 554, top: 40, right: 842, bottom: 700 },
        { left: 290, top: 400, right: 554, bottom: 700 },
      ]),
    ).toEqual({ left: 290, top: 40, width: 264, height: 360 });
  });

  it('has the same result when every input is scaled for the displayed UI', () => {
    for (const scale of [0.6666667, 1.25, 1.5, 2]) {
      const scaled = <T extends object>(rect: T): T =>
        Object.fromEntries(
          Object.entries(rect).map(([key, value]) => [key, value * scale]),
        ) as T;
      const placed = placeNativeMenu(
        scaled(bounds),
        scaled(preferred),
        scaled(minimum),
        [scaled({ left: 220, top: 90, right: 830, bottom: 688 })],
      );
      expect(placed?.left).toBeCloseTo(8 * scale);
      expect(placed?.width).toBeCloseTo(212 * scale);
      expect(placed?.height).toBeCloseTo(520 * scale);
    }
  });
});
