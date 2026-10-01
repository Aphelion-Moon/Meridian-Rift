// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';

import {
  bloomOffset,
  bloomReach,
  bloomSigma,
  bloomSize,
  bloomSource,
  DEFAULT_BLOOM,
  lightsOffPixels,
  tiledFloor,
} from './LightsOff';

/** A picture's channels, pixel after pixel. */
const pixels = (...channels: number[]) => new Uint8ClampedArray(channels);

/** An orange pixel: a tenth of it is (20, 10, 5). */
const ORANGE = [200, 100, 50, 255];

/** One pixel lit with the lights off, with its glow and the bloom's light on it. */
const lightOne = (
  glow?: number[],
  bloomLight?: number[],
  floor?: number[],
  picture = ORANGE,
) => [
  ...lightsOffPixels(
    pixels(...picture),
    glow && pixels(...glow),
    1,
    1,
    0,
    bloomLight && pixels(...bloomLight),
    floor && pixels(...floor),
  ),
];

describe('lightsOffPixels', () => {
  it('keeps only the dark room light where nothing glows', () => {
    expect(lightOne()).toEqual([20, 10, 5, 255]);
  });

  it('shows what glows in its own colour, through either channel', () => {
    expect(lightOne([255, 0, 0, 255])).toEqual(ORANGE);
    expect(lightOne([0, 255, 0, 255])).toEqual(ORANGE);
  });

  it('leaves the dark where a blocker covers the glow', () => {
    expect(lightOne([0, 0, 0, 255])).toEqual([20, 10, 5, 255]);
  });

  it('lights a pixel glow half covers half of the way from the dark', () => {
    // Half covered: 0.502 + 0.498 * 0.1 of its colour.
    expect(lightOne([128, 0, 0, 255])).toEqual([110, 55, 28, 255]);
    expect(lightOne([255, 0, 0, 128])).toEqual([110, 55, 28, 255]);
  });

  it("multiplies the bloom's light into what it falls on", () => {
    // Red light at 0.95 on top of the room's 0.1.
    expect(lightOne(undefined, [255, 0, 0, 255])).toEqual([210, 10, 5, 255]);
  });

  it('lights the floor where the bloom falls on it, and leaves it to the page elsewhere', () => {
    const clear = [0, 0, 0, 0];
    const grey = [100, 100, 100, 255];

    expect(lightOne(undefined, [0, 255, 0, 255], grey, clear)).toEqual([
      10, 105, 10, 255,
    ]);
    expect(lightOne(undefined, [0, 0, 0, 255], grey, clear)).toEqual(clear);
  });

  it('does not turn a transparent floor into an opaque halo', () => {
    expect(
      lightOne(undefined, [0, 255, 0, 255], [100, 100, 100, 0], [0, 0, 0, 0]),
    ).toEqual([0, 0, 0, 0]);
  });

  it('preserves translucent floor coverage under bloom and translucent art', () => {
    expect(
      lightOne(undefined, [0, 255, 0, 255], [100, 100, 100, 128], [0, 0, 0, 0]),
    ).toEqual([10, 105, 10, 128]);
    expect(
      lightOne(undefined, undefined, [100, 100, 100, 128], [200, 100, 50, 128]),
    ).toEqual([17, 10, 7, 192]);
  });

  it('pads the picture for the bloom', () => {
    const lit = lightsOffPixels(pixels(...ORANGE), undefined, 1, 1, 1);

    expect(lit.length).toBe(3 * 3 * 4);
    expect([...lit.slice(16, 20)]).toEqual([20, 10, 5, 255]);
    expect([...lit.slice(0, 4)]).toEqual([0, 0, 0, 0]);
  });
});

describe('bloomSource', () => {
  it('takes the colours under red glow, on black', () => {
    expect([
      ...(bloomSource(pixels(...ORANGE), pixels(255, 0, 0, 255)) ?? []),
    ]).toEqual(ORANGE);
  });

  it('has nothing where glow does not bloom or a blocker covers it', () => {
    expect(
      bloomSource(pixels(...ORANGE), pixels(0, 255, 0, 255)),
    ).toBeUndefined();
    expect(
      bloomSource(pixels(...ORANGE), pixels(0, 0, 0, 255)),
    ).toBeUndefined();
  });
});

describe('tiledFloor', () => {
  it('repeats a tile from where it starts', () => {
    const tile = pixels(1, 1, 1, 255, 2, 2, 2, 255);
    const floor = tiledFloor(tile, 2, 1, 3, 1, 1, 0);

    expect([floor[0], floor[4], floor[8]]).toEqual([2, 1, 2]);
  });
});

describe('bloom', () => {
  it("reads the player's setting as the game does", () => {
    expect(bloomSize(undefined)).toBe(DEFAULT_BLOOM);
    expect(bloomSize('2')).toBe(DEFAULT_BLOOM);
    expect(bloomSize(0)).toBe(0);
    expect(bloomSize(9)).toBe(5);
  });

  it("grows by the filter's offset and blurs 1.2 times its size across", () => {
    expect(bloomOffset(2)).toBe(1);
    expect(bloomOffset(5)).toBe(3);
    expect(bloomSigma(2)).toBeCloseTo(2.4);
  });

  it('reaches its offset and two and a half blurs past what blooms', () => {
    expect(bloomReach(0)).toBe(0);
    expect(bloomReach(2)).toBe(7);
    expect(bloomReach(5)).toBe(18);
  });
});
