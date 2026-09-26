// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import {
  compactSprite,
  fixtureFrames,
} from '../../../__mocks__/customSpriteEditor';
import { Dir } from '../SpriteEditor/Types/types';
import { decodeCanvas } from './canvas';

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
