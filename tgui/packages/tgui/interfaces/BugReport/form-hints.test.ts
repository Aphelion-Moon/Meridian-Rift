import { describe, expect, test } from 'bun:test';
import { hasReproductionHint } from './form-hints';
describe('report phrase hints', () => {
  test('only entire known phrases prompt', () => {
    expect(hasReproductionHint(' DOESN’T WORK!!! ')).toBe(true);
    expect(hasReproductionHint('Press F2; the client crashes.')).toBe(false);
    expect(hasReproductionHint('Click the "not working" button.')).toBe(false);
    expect(hasReproductionHint('nie działa')).toBe(false);
  });
});
