import { afterEach, expect, it } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import {
  FeatureLongTextInput,
  FeatureValueInput,
} from './preferences/features/base';
import {
  ooc_notes_silicon,
  ooc_notes_silicon_nsfw,
} from './preferences/features/character_preferences/aphelion/cyborg';
import type { CharacterPreferencesData, ServerData } from './types';
import { ServerPrefs } from './useServerPrefs';

afterEach(cleanup);

it.each([
  ['ooc_notes_silicon', ooc_notes_silicon, 'SFW'],
  ['ooc_notes_silicon_nsfw', ooc_notes_silicon_nsfw, 'NSFW'],
] as const)('passes %s fallback guidance through the real preference renderer', (key, feature, label) => {
  render(
    <ServerPrefs.Provider
      value={{ [key]: { maximum_length: 1024 } } as unknown as ServerData}
    >
      <FeatureValueInput featureId={key} feature={feature} value="" />
    </ServerPrefs.Provider>,
  );
  expect(
    (
      screen.getByPlaceholderText(
        `Leave blank to use your human ${label} OOC notes.`,
      ) as HTMLTextAreaElement
    ).value,
  ).toBe('');
});

it('shows fallback guidance as a placeholder and saves only what the user enters', () => {
  const changes: string[] = [];
  render(
    <FeatureLongTextInput
      featureId="ooc_notes_silicon"
      value=""
      placeholder="Leave blank to use your human SFW OOC notes."
      serverData={{ maximum_length: 1024 }}
      character_preferences={{} as CharacterPreferencesData}
      handleSetValue={(value) => changes.push(value)}
    />,
  );
  const input = screen.getByPlaceholderText(
    'Leave blank to use your human SFW OOC notes.',
  ) as HTMLTextAreaElement;
  expect(input.value).toBe('');
  fireEvent.input(input, { target: { value: 'My cyborg notes' } });
  fireEvent.blur(input);
  expect(changes).toEqual(['My cyborg notes']);
});
