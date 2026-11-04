// Generated policy v1; parity is verified from the web contract fixture.
export const PHRASES = [
  "doesn't work",
  'does not work',
  'not working',
  "it's broken",
  'its broken',
  'broken',
  'see title',
];
export function hasReproductionHint(value: string) {
  return PHRASES.includes(
    value
      .trim()
      .toLowerCase()
      .replace(/[’‘]/g, "'")
      .replace(/[.!?]+$/, '')
      .trim(),
  );
}
