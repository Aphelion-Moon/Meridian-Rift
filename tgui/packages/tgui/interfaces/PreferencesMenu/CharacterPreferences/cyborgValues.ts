/** Randomization uses the same keys as values, but contains numeric flags. */
export function cyborgPreferenceValues(
  categories: Record<string, object>,
): Record<string, unknown> {
  return Object.assign(
    {},
    ...Object.entries(categories)
      .filter(([category]) => category !== 'randomization')
      .map(([, values]) => values),
  );
}
