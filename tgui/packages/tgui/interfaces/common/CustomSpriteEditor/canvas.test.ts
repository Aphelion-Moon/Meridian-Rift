// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import {
  compactSprite,
  fixtureFrames,
} from '../../../__mocks__/customSpriteEditor';
import { Dir } from '../SpriteEditor/Types/types';
import {
  type CompactSprite,
  decodeCanvas,
  fillSentViews,
  fitsMiddleHalf,
  type SentView,
} from './canvas';

it('decodes the canvas the server sends for one painted pixel', () => {
  const sprite = decodeCanvas({
    width: 32,
    height: 32,
    dirs: 4,
    backdrop: '',
    canvas: {
      palette: ['#123456ff', '#00000000'],
      digits: 1,
      views: { 2: `0${'1'.repeat(1023)}`, 1: '1'.repeat(1024) },
    },
  });
  const front = sprite.layers[0].data[Dir.SOUTH]!;
  expect(front[0][0]).toBe('#123456ff');
  expect(front[0][1]).toBe('#00000000');
  expect(front[31][31]).toBe('#00000000');
  expect(sprite.layers[0].data[Dir.NORTH]![0][0]).toBe('#00000000');
  expect(sprite.layers[0].data[Dir.EAST]).toBeUndefined();
});

it('round-trips every view, including two-character codes past 64 values', () => {
  const frames = fixtureFrames(64, 32);
  for (let y = 0; y < 3; y++) {
    for (let x = 0; x < 32; x++) {
      frames[Dir.WEST][y][x] =
        `#${(y * 32 + x).toString(16).padStart(6, '0')}ff`;
    }
  }
  const sprite = compactSprite(64, 32, frames);
  expect(sprite.canvas.digits).toBe(2);
  const decoded = decodeCanvas(sprite);
  expect(decoded.width).toBe(64);
  for (const dir of [Dir.SOUTH, Dir.NORTH, Dir.EAST, Dir.WEST]) {
    expect(decoded.layers[0].data[dir]).toEqual(frames[dir]);
  }
});

it('shows a wide view at its middle half only while nothing paintable or painted lies outside it', () => {
  const clear = () =>
    Array.from({ length: 32 }, () => Array(64).fill('#00000000'));
  const middleMask = Array.from(
    { length: 32 },
    () => `${'0'.repeat(16)}${'1'.repeat(32)}${'0'.repeat(16)}`,
  );
  const frame = clear();
  frame[10][20] = '#ff0000ff';
  expect(fitsMiddleHalf(frame, middleMask)).toBe(true);
  const taurMask = [...middleMask];
  taurMask[20] = '1'.repeat(64);
  expect(fitsMiddleHalf(frame, taurMask)).toBe(false);
  const oldPaint = clear();
  oldPaint[5][60] = '#00ff00ff';
  expect(fitsMiddleHalf(oldPaint, middleMask)).toBe(false);
  expect(
    fitsMiddleHalf(
      Array.from({ length: 32 }, () => Array(32).fill('#00000000')),
      undefined,
    ),
  ).toBe(false);
});

it('keeps the graffiti views the server sends as unchanged, and asks again for one it never had or missed', () => {
  const sprite = (
    bottom: string | null,
    top: string | null,
    serials: Record<string, number>,
  ): CompactSprite => ({
    width: 32,
    height: 32,
    dirs: 1,
    backdrop: '',
    canvas: {
      palette: ['#00000000', '#123456ff'],
      digits: 1,
      views: { 2: bottom },
      viewsLayer: 'l1',
      appendages: { l2: { 2: top } },
      viewSerials: serials,
    },
  });
  const sent: Record<string, SentView> = {};
  const first = fillSentViews(
    sprite('0'.repeat(1024), '1'.repeat(1024), { l1: 1, l2: 2 }),
    sent,
  );
  expect(first.missing).toBe(false);
  // Only the bottom layer changed: the top one comes as null under its serial and is filled from what the window kept.
  const next = fillSentViews(
    sprite(`1${'0'.repeat(1023)}`, null, { l1: 3, l2: 2 }),
    sent,
  );
  expect(next.missing).toBe(false);
  expect(next.sprite.canvas.appendages?.l2[2]).toBe('1'.repeat(1024));
  expect(decodeCanvas(next.sprite).layers[0].data[2]![0][0]).toBe('#123456ff');
  // Two updates came before the window drew: it never saw the first, which gave the top layer new codes, so the
  // second's null for it carries a serial the window doesn't have.
  expect(
    fillSentViews(sprite(null, null, { l1: 3, l2: 4 }), sent).missing,
  ).toBe(true);
  // A window that kept nothing, as after a reload, finds the view missing.
  expect(fillSentViews(sprite(null, null, { l1: 3, l2: 2 }), {}).missing).toBe(
    true,
  );
});
