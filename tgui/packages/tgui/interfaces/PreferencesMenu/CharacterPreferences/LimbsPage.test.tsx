// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen, within } from '@testing-library/react';
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
    marking_choices: {},
    marking_presets: [],
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

it('opens one custom drawing per marking zone alongside existing markings and the whole-body editor', () => {
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
  fireEvent.click(screen.getByText('Custom marking drawing'));
  expect(send).toHaveBeenLastCalledWith('open_custom_sprite_editor', {
    target: 'markings',
  });
});

it('keeps ordinary marking controls when custom editing is unavailable', () => {
  backendStore.set(gameDataAtom, {
    ...preferences,
    allow_custom_sprite_editing: false,
  });
  renderPage();
  expect(screen.queryByText('Custom')).toBeNull();
  expect(screen.queryByText('Custom marking drawing')).toBeNull();
  const leftArm = within(screen.getByText('Left arm').closest('.Section')!);
  fireEvent.click(leftArm.getByText('+'));
  expect(send).toHaveBeenLastCalledWith('add_marking', {
    bodypart_slot: 'l_arm',
  });
});
