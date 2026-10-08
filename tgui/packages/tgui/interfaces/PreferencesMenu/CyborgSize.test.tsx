import { expect, it } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { cyborg_size } from './preferences/features/character_preferences/aphelion/cyborg';
import { Gender } from './preferences/gender';
import {
  type CharacterPreferencesData,
  JoblessRole,
  RandomSetting,
} from './types';

const characterPreferences: CharacterPreferencesData = {
  clothing: {},
  features: {},
  game_preferences: {},
  non_contextual: { random_body: RandomSetting.Disabled, cyborg_size: 1 },
  secondary_features: {},
  supplemental_features: {},
  manually_rendered_features: {},
  names: {},
  vocals: {},
  erp: {},
  randomization: {},
  misc: {
    gender: Gender.Male,
    joblessrole: JoblessRole.ReturnToLobby,
    species: 'human',
    loadout_lists: { loadouts: [], loadout: [] },
    job_clothes: false,
    loadout_index: '',
    background_state: '',
  },
};

it('renders numeric cyborg size choices and submits a numeric size', async () => {
  const SizeInput = cyborg_size.component;
  const changes: number[] = [];
  await act(async () => {
    render(
      <SizeInput
        featureId="cyborg_size"
        value={1}
        serverData={{ choices: [0.75, 1, 1.6, 2, 2.5] }}
        character_preferences={characterPreferences}
        handleSetValue={(value) => changes.push(value)}
      />,
    );
  });
  await act(async () => fireEvent.click(screen.getByText('1')));
  for (const size of ['0.75', '1.6', '2', '2.5']) {
    expect(screen.queryByText(size) !== null).toBe(true);
  }
  await act(async () => fireEvent.click(screen.getByText('1.6')));
  expect(changes).toEqual([1.6]);
  await act(async () => cleanup());
});
