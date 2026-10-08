import { expect, it } from 'bun:test';
import { mapPreviewZoom, previewDisplayScale } from './mapPreviewZoom';

it('accounts for TGUI window scaling being enabled or canceled by body zoom', () => {
  expect(previewDisplayScale(1.5, '')).toBe(1.5);
  expect(previewDisplayScale(2, '50%')).toBe(1);
  expect(previewDisplayScale(2, '0.5')).toBe(1);
  expect(previewDisplayScale(1.5, '66.66666666666667%')).toBeCloseTo(1);
  expect(
    mapPreviewZoom('1440x1440', [15, 15], previewDisplayScale(2, '50%')),
  ).toBe(3);
});

it('matches automatic map zoom and converts native pixels to CSS pixels', () => {
  expect(mapPreviewZoom('1440x1440', [15, 15])).toBe(3);
  expect(mapPreviewZoom({ x: 1440, y: 1440 }, [15, 15], 1.5)).toBe(2);
  expect(mapPreviewZoom('1680x960', [21, 12], 2)).toBe(1.25);
});

it('rejects unavailable, minimized, or malformed map dimensions', () => {
  for (const size of ['', '0x0', 'bad', {}, { x: 1 }, 'Infinityx480']) {
    expect(mapPreviewZoom(size, [15, 15])).toBeUndefined();
  }
  expect(mapPreviewZoom('480x480', [0, 15])).toBeUndefined();
  expect(mapPreviewZoom('480x480', [15, 15], 0)).toBeUndefined();
});
