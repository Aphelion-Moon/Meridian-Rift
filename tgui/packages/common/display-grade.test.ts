import { describe, expect, it } from 'bun:test';
import {
  displayGradeFilter,
  displayGradeSample,
  DISPLAY_GRADE_REFERENCE as reference,
  validateDisplayGrade,
} from './display-grade';

const neutral = {
  ...reference,
  saturation: 1,
  shadow_strength: 0,
  midtone_strength: 0,
  highlight_strength: 0,
};

describe('Aphelion display grade', () => {
  it('preserves every channel at zero strength and with neutral controls', () => {
    for (const rgba of [
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [1, 0, 0, 0.5],
      [0, 1, 0.25, 0.01],
      [0.2, 0.4, 0.9, 0.8],
    ]) {
      expect(displayGradeSample(rgba, { ...reference, strength: 0 })).toEqual(
        rgba,
      );
      displayGradeSample(rgba, neutral).forEach((value, index) => {
        expect(value).toBeCloseTo(rgba[index], 12);
      });
    }
    expect(displayGradeFilter('proof', { ...reference, strength: 0 })).toBe('');
  });

  it('assigns independent colors to the three tonal anchors', () => {
    const settings = {
      ...reference,
      saturation: 1,
      shadow_color: '#FF0000',
      midtone_color: '#00FF00',
      highlight_color: '#0000FF',
      midtone_strength: 1,
    };
    expect(displayGradeSample([0, 0, 0, 0.25], settings)).toEqual([
      1, 0, 0, 0.25,
    ]);
    expect(displayGradeSample([0.5, 0.5, 0.5, 0.5], settings)).toEqual([
      0, 1, 0, 0.5,
    ]);
    expect(displayGradeSample([1, 1, 1, 0.75], settings)).toEqual([
      0, 0, 1, 0.75,
    ]);
    expect(
      displayGradeSample([0, 0, 0, 1], { ...settings, shadow_strength: 0 }),
    ).toEqual([0, 0, 0, 1]);
    expect(
      displayGradeSample([0.5, 0.5, 0.5, 1], {
        ...settings,
        midtone_strength: 0,
      }),
    ).toEqual([0.5, 0.5, 0.5, 1]);
    expect(
      displayGradeSample([1, 1, 1, 1], { ...settings, highlight_strength: 0 }),
    ).toEqual([1, 1, 1, 1]);
  });

  it('uses the exact proposed Reference endpoint colors', () => {
    const black = displayGradeSample([0, 0, 0, 1], reference);
    const white = displayGradeSample([1, 1, 1, 1], reference);
    [45, 38, 57].forEach((value, index) => {
      expect(black[index]).toBeCloseTo(value / 255, 12);
    });
    [214, 201, 152].forEach((value, index) => {
      expect(white[index]).toBeCloseTo(value / 255, 12);
    });
  });

  it('clamps after saturation, contrast, and brightness as one operation', () => {
    // Red after 150% saturation is 1.3937. At 50% contrast it is
    // 0.94685, not 0.75 (the result of incorrectly clipping saturation first).
    const result = displayGradeSample([1, 0, 0, 0.1], {
      ...neutral,
      saturation: 1.5,
      contrast: 0.5,
    });
    expect(result[0]).toBeCloseTo(0.94685, 10);
    expect(result[1]).toBeCloseTo(0.19685, 10);
    expect(result[2]).toBeCloseTo(0.19685, 10);
    expect(result[3]).toBe(0.1);
  });

  it('has continuous grayscale transitions, bounded RGB, and unchanged alpha', () => {
    let previous = displayGradeSample([0, 0, 0, 0.37], reference);
    for (let step = 1; step <= 1000; step++) {
      const value = step / 1000;
      const current = displayGradeSample(
        [value, value, value, 0.37],
        reference,
      );
      for (let channel = 0; channel < 3; channel++) {
        expect(current[channel]).toBeGreaterThanOrEqual(0);
        expect(current[channel]).toBeLessThanOrEqual(1);
        expect(Math.abs(current[channel] - previous[channel])).toBeLessThan(
          0.003,
        );
      }
      expect(current[3]).toBe(0.37);
      previous = current;
    }
  });

  it('rejects malformed settings atomically and copies valid settings', () => {
    for (const bad of [
      null,
      {},
      { ...reference, strength: NaN },
      { ...reference, contrast: Infinity },
      { ...reference, saturation: 1.51 },
      { ...reference, brightness: -0.21 },
      { ...reference, shadow_color: '#fff' },
      { ...reference, highlight_color: '#12345678' },
      { ...reference, midtone_color: '<script>' },
    ]) {
      expect(validateDisplayGrade(bad)).toBeNull();
    }
    const result = validateDisplayGrade(reference)!;
    result.strength = 0;
    expect(reference.strength).toBe(1);
  });

  it('builds an sRGB SVG graph with one final source-alpha mask', () => {
    const container = document.createElement('div');
    container.innerHTML = `<svg>${displayGradeFilter('proof', reference)}</svg>`;
    const filter = container.querySelector('filter')!;
    expect(filter.getAttribute('color-interpolation-filters')).toBe('sRGB');
    expect(filter.querySelectorAll('[in2="SourceAlpha"]').length).toBe(1);
    expect(filter.lastElementChild?.getAttribute('operator')).toBe('in');
    expect(
      filter.querySelectorAll('[operator="arithmetic"][k1="1"]').length,
    ).toBe(3);
    expect(() => displayGradeFilter('bad"id', reference)).toThrow();
    expect(() =>
      displayGradeFilter('proof', { ...reference, shadow_color: '"/>' }),
    ).toThrow();
  });
});
