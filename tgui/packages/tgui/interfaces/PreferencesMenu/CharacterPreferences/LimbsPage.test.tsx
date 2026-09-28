// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it, spyOn } from 'bun:test';
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import type { ServerData } from '../types';
import { ServerPrefs } from '../useServerPrefs';
import { LimbsPage } from './LimbsPage';

const zones = [
  ['Head', 'head'],
  ['Chest', 'chest'],
  ['Left arm', 'l_arm'],
  ['Right arm', 'r_arm'],
  ['Left leg', 'l_leg'],
  ['Right leg', 'r_leg'],
] as const;

const serverData: ServerData = {
  jobs: { departments: {}, jobs: {}, jobs_sorted: [] },
  names: { types: {} },
  quirks: {
    max_positive_quirks: -1,
    quirk_info: {},
    quirk_blacklist: [],
    points_enabled: false,
  },
  personality: { personalities: [], personality_incompatibilities: {} },
  random: { randomizable: [] },
  loadout: { loadout_tabs: [] },
  species: {},
  species_families: [],
  background_state: { choices: [] },
  limbs_and_markings: {
    robotic_styles: [],
    augment_items: zones.map(([slot, body_zone]) => ({
      slot,
      body_zone,
      is_bodypart: true,
      aug_options: [],
      implant_options: [],
    })),
    marking_choices: {
      l_arm: ['Stripe', 'Spots', 'Dots'].map((name) => ({
        name,
        recommended_species: null,
      })),
    },
    marking_icons: {
      l_arm: {
        Stripe: 'mark-stripe',
        Spots: 'mark-spots',
        Dots: 'mark-dots',
        Unavailable: 'mark-unavailable',
      },
    },
    marking_presets: [],
    max_markings: 3,
  },
};

const preferences = {
  character_preview_view: 'custom-markings-test',
  character_preferences: { misc: { species: 'human' } },
  markings: {
    l_arm: [
      { name: 'Stripe', color: '#ffffff', marking_id: 'one', emissive: false },
      { name: 'Spots', color: '#000000', marking_id: 'two', emissive: true },
    ],
  },
  augments: {},
  augment_styles: {},
  allow_mismatched_parts: false,
  allow_custom_sprite_editing: true,
  digi_legs: false,
  taur_legs: false,
  quirk_points_enabled: 0,
  quirks_balance: 0,
  ckey: 'custom-markings-test',
};

let previousData: Record<string, unknown>;
let send: ReturnType<typeof spyOn>;
beforeEach(() => {
  previousData = backendStore.get(gameDataAtom);
  backendStore.set(gameDataAtom, preferences);
  send = spyOn(actions, 'sendAct');
});
afterEach(() => {
  send.mockRestore();
  backendStore.set(gameDataAtom, previousData);
});

const renderPage = () =>
  render(
    <ServerPrefs.Provider value={serverData}>
      <LimbsPage />
    </ServerPrefs.Provider>,
  );

it('opens one custom drawing per marking zone alongside existing markings', () => {
  renderPage();
  expect(screen.getAllByText('Custom')).toHaveLength(6);
  for (const [label, body_zone] of zones) {
    const section = within(screen.getByText(label).closest('.Section')!);
    fireEvent.click(section.getByText('Custom'));
    expect(send).toHaveBeenLastCalledWith('open_custom_sprite_editor', {
      target: 'markings',
      body_zone,
    });
    fireEvent.click(section.getByText('+'));
    expect(send).toHaveBeenLastCalledWith('add_marking', {
      bodypart_slot: body_zone,
    });
  }
  expect(screen.queryByText('Full body marking')).toBeNull();
  expect(screen.queryByText('Taur body')).toBeNull();
});

it('swaps adding and drawing leg markings for the taur drawing on taur legs', () => {
  backendStore.set(gameDataAtom, { ...preferences, taur_legs: true });
  renderPage();
  for (const label of ['Left leg', 'Right leg']) {
    const section = within(screen.getByText(label).closest('.Section')!);
    expect(section.queryByText('+')).toBeNull();
    expect(section.queryByText('Custom')).toBeNull();
    fireEvent.click(section.getByText('Taur body'));
    expect(send).toHaveBeenLastCalledWith('open_custom_sprite_editor', {
      target: 'markings',
      body_zone: 'taur',
    });
  }
  expect(screen.getAllByText('+')).toHaveLength(4);
  expect(screen.getAllByText('Custom')).toHaveLength(4);
});

it('keeps ordinary marking controls when custom editing is unavailable', () => {
  backendStore.set(gameDataAtom, {
    ...preferences,
    allow_custom_sprite_editing: false,
    taur_legs: true,
  });
  renderPage();
  expect(screen.queryByText('Custom')).toBeNull();
  expect(screen.queryByText('Taur body')).toBeNull();
  const leftArm = within(screen.getByText('Left arm').closest('.Section')!);
  fireEvent.click(leftArm.getByText('+'));
  expect(send).toHaveBeenLastCalledWith('add_marking', {
    bodypart_slot: 'l_arm',
  });
});

it('opens cached marking icons and filters duplicates before local search', async () => {
  renderPage();
  const trigger = screen.getAllByLabelText('Select marking')[0];
  expect(trigger.textContent).toContain('Stripe');
  expect(trigger.querySelector('.preferences32x32')).toBeNull();
  await act(async () => fireEvent.click(trigger));
  expect(screen.getByLabelText('Stripe')).toBeTruthy();
  expect(screen.queryByLabelText('Spots')).toBeNull();
  expect(screen.queryByLabelText('Unavailable')).toBeNull();
  expect(
    screen.getByLabelText('Dots').querySelector('.mark-dots'),
  ).toBeTruthy();
  fireEvent.input(screen.getByPlaceholderText('Search...'), {
    target: { value: 'dots' },
  });
  expect(screen.queryByLabelText('Stripe')).toBeNull();
  expect(send).not.toHaveBeenCalled();
  fireEvent.click(screen.getByLabelText('Dots'));
  expect(send).toHaveBeenCalledTimes(1);
  expect(send).toHaveBeenLastCalledWith('change_marking', {
    bodypart_slot: 'l_arm',
    marking_id: 'one',
    marking_name: 'Dots',
  });
});
