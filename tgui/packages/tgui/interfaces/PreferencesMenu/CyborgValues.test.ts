import { expect, it } from 'bun:test';
import { cyborgPreferenceValues } from './CharacterPreferences/cyborgValues';

it('keeps pronouns and sprites when randomization repeats their preference keys', () => {
  const values = cyborgPreferenceValues({
    non_contextual: { silicon_gender: 'They/Them', cyborg_size: 1.6 },
    features: { silicon_penis_sprite: 'Plain' },
    randomization: { silicon_gender: 3, silicon_penis_sprite: 3 },
  });
  expect(values.silicon_gender).toBe('They/Them');
  expect(values.silicon_penis_sprite).toBe('Plain');
  expect(values.cyborg_size).toBe(1.6);
});
