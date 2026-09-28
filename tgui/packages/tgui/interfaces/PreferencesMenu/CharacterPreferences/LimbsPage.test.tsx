// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, expect, it, spyOn } from 'bun:test';
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import type { Marking, MarkingInfo, ServerData } from '../types';
import { ServerPrefs } from '../useServerPrefs';
import { LimbsPage } from './LimbsPage';

/** A marking's details as character setup sends them: meant for any species unless told otherwise. */
const markingInfo = (details: Partial<MarkingInfo> = {}): MarkingInfo => ({
  color_mode: 'follows_primary',
  gendered: 0,
  exclusion_group: null,
  leg_shapes: 3,
  recommended_species: null,
  ...details,
});

/** A row as character setup sends it. */
const row = (
  name: string,
  marking_id: string,
  details: Partial<Marking> = {},
): Marking => ({
  name,
  color: '#ffffff',
  marking_id,
  emissive: false,
  locked: false,
  ...details,
});

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
    marking_choices: { l_arm: ['Stripe', 'Spots', 'Dots', 'Freckles'] },
    marking_info: {
      Stripe: markingInfo(),
      Spots: markingInfo(),
      Dots: markingInfo(),
      Freckles: markingInfo(),
    },
    marking_icons: {
      l_arm: {
        Stripe: 'mark-stripe',
        Spots: 'mark-spots',
        Dots: 'mark-dots',
        Freckles: 'mark-freckles',
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
      row('Stripe', 'one'),
      row('Spots', 'two', { color: '#000000', emissive: true }),
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

const renderPage = (data = serverData) =>
  render(
    <ServerPrefs.Provider value={data}>
      <LimbsPage />
    </ServerPrefs.Provider>,
  );

type LimbsData = NonNullable<ServerData['limbs_and_markings']>;

/** The fixture's server data with some of its marking fields replaced. */
const withLimbs = (limbs: Partial<LimbsData>): ServerData => ({
  ...serverData,
  limbs_and_markings: { ...serverData.limbs_and_markings!, ...limbs },
});

/** The fixture's server data with some markings' details replaced. */
const withMarkingInfo = (details: Record<string, MarkingInfo>): ServerData =>
  withLimbs({
    marking_info: {
      ...serverData.limbs_and_markings!.marking_info,
      ...details,
    },
  });

/** The rows' own markings, with the fixture's other preferences. */
const setMarkings = (
  markings: Record<string, Marking[]>,
  other: Record<string, unknown> = {},
) => backendStore.set(gameDataAtom, { ...preferences, ...other, markings });

/** The row whose marking picker shows this name. */
const rowOf = (name: string) =>
  screen
    .getAllByLabelText('Select marking')
    .find((trigger) => trigger.textContent?.trim() === name)!
    .closest('.LimbsPage__markingRow') as HTMLElement;

/** A body part's section. */
const sectionOf = (label: string) =>
  screen.getByText(label).closest('.Section') as HTMLElement;

/** Lets a closing popover finish its animation, after which it must be gone. */
const settle = () =>
  act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 300));
  });

const isDisabled = (element: HTMLElement) =>
  element.classList.contains('Button--disabled');

it('opens one custom drawing per marking zone alongside existing markings', () => {
  renderPage();
  expect(screen.getAllByText('Custom')).toHaveLength(6);
  for (const [label, body_zone] of zones) {
    const section = within(sectionOf(label));
    fireEvent.click(section.getByText('Custom'));
    expect(send).toHaveBeenLastCalledWith('open_custom_sprite_editor', {
      target: 'markings',
      body_zone,
    });
    fireEvent.click(section.getByLabelText('Add a random marking'));
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
    const section = within(sectionOf(label));
    expect(section.queryByLabelText('Add a marking')).toBeNull();
    expect(section.queryByLabelText('Add a random marking')).toBeNull();
    expect(section.queryByText('Custom')).toBeNull();
    fireEvent.click(section.getByText('Taur body'));
    expect(send).toHaveBeenLastCalledWith('open_custom_sprite_editor', {
      target: 'markings',
      body_zone: 'taur',
    });
  }
  expect(screen.getAllByLabelText('Add a random marking')).toHaveLength(4);
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
  const leftArm = within(sectionOf('Left arm'));
  fireEvent.click(leftArm.getByLabelText('Add a random marking'));
  expect(send).toHaveBeenLastCalledWith('add_marking', {
    bodypart_slot: 'l_arm',
  });
});

it('opens cached marking icons and shows markings other rows wear as unavailable', async () => {
  renderPage();
  const trigger = screen.getAllByLabelText('Select marking')[0];
  expect(trigger.textContent).toContain('Stripe');
  expect(trigger.querySelector('.preferences32x32')).toBeNull();
  await act(async () => fireEvent.click(trigger));
  expect(isDisabled(screen.getByLabelText('Stripe'))).toBe(false);
  // Another row wears it, so it is shown but can't be picked.
  expect(isDisabled(screen.getByLabelText('Spots'))).toBe(true);
  fireEvent.click(screen.getByLabelText('Spots'));
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

it('offers a zone only the markings meant for the species, unless mismatched parts are allowed', async () => {
  const data = withMarkingInfo({
    Dots: markingInfo({ recommended_species: 'moth,insect' }),
  });
  const offersDots = async (overrides: Record<string, unknown>) => {
    backendStore.set(gameDataAtom, { ...preferences, ...overrides });
    const view = renderPage(data);
    await act(async () =>
      fireEvent.click(screen.getAllByLabelText('Select marking')[0]),
    );
    const offered = !!screen.queryByLabelText('Dots');
    view.unmount();
    return offered;
  };
  expect(await offersDots({})).toBe(false);
  expect(
    await offersDots({ character_preferences: { misc: { species: 'moth' } } }),
  ).toBe(true);
  expect(await offersDots({ allow_mismatched_parts: true })).toBe(true);
  expect(send).not.toHaveBeenCalled();
});

it('adds the marking picked from its zone, and shows the ones the zone cannot take with why', async () => {
  // Stripe is worn, and Dots shares its exclusion group.
  renderPage(
    withMarkingInfo({
      Stripe: markingInfo({ exclusion_group: 'coat' }),
      Dots: markingInfo({ exclusion_group: 'coat' }),
    }),
  );
  const leftArm = within(sectionOf('Left arm'));
  await act(async () =>
    fireEvent.click(leftArm.getByLabelText('Add a marking')),
  );
  const chooser = screen
    .getByText('Select marking')
    .closest('.ChoicedSelection') as HTMLElement;
  for (const name of ['Stripe', 'Spots', 'Dots']) {
    const option = within(chooser).getByLabelText(name);
    expect(isDisabled(option)).toBe(true);
    fireEvent.click(option);
  }
  expect(send).not.toHaveBeenCalled();
  // Its reason names the marking that keeps it off.
  await act(async () =>
    fireEvent.mouseMove(within(chooser).getByLabelText('Dots')),
  );
  expect(await screen.findByText(/^Dots: .*Stripe/)).toBeTruthy();
  fireEvent.click(within(chooser).getByLabelText('Freckles'));
  expect(send).toHaveBeenCalledTimes(1);
  expect(send).toHaveBeenLastCalledWith('add_marking', {
    bodypart_slot: 'l_arm',
    marking_name: 'Freckles',
  });
  await settle();
  expect(document.querySelector('.ChoicedSelection')).toBeNull();
});

it("lets a row become another marking of its own exclusion group, but not of another row's", async () => {
  renderPage(
    withMarkingInfo({
      Stripe: markingInfo({ exclusion_group: 'coat' }),
      Dots: markingInfo({ exclusion_group: 'coat' }),
    }),
  );
  await act(async () =>
    fireEvent.click(within(rowOf('Stripe')).getByLabelText('Select marking')),
  );
  expect(isDisabled(screen.getByLabelText('Dots'))).toBe(false);
  await act(async () => fireEvent.keyDown(document.body, { key: 'Escape' }));
  await settle();
  await act(async () =>
    fireEvent.click(within(rowOf('Spots')).getByLabelText('Select marking')),
  );
  expect(isDisabled(screen.getByLabelText('Dots'))).toBe(true);
  expect(isDisabled(screen.getByLabelText('Freckles'))).toBe(false);
});

it('picks a row colour in place and sends it once, on Apply, leaving nothing open', async () => {
  renderPage();
  const colorButton = within(rowOf('Stripe')).getByLabelText('Marking color');
  await act(async () => fireEvent.click(colorButton));
  const picker = document.querySelector('.LimbsPage__colorPicker')!;
  expect(picker.querySelector('.react-colorful')).toBeTruthy();
  const apply = within(picker as HTMLElement)
    .getByText('Apply')
    .closest('.Button') as HTMLElement;
  // Nothing picked yet, so there is nothing to apply.
  expect(isDisabled(apply)).toBe(true);
  fireEvent.click(apply);
  expect(send).not.toHaveBeenCalled();
  fireEvent.input(picker.querySelector('input')!, {
    target: { value: '12AB34' },
  });
  expect(isDisabled(apply)).toBe(false);
  fireEvent.click(apply);
  expect(send).toHaveBeenCalledTimes(1);
  expect(send).toHaveBeenLastCalledWith('color_marking', {
    bodypart_slot: 'l_arm',
    marking_id: 'one',
    color: '#12ab34',
  });
  // A closed picker leaves no portaled element behind to catch clicks.
  await settle();
  expect(document.querySelector('.LimbsPage__colorPicker')).toBeNull();
});

it('keeps a locked row in its own colour, with no picker to open', async () => {
  setMarkings({ l_arm: [row('Stripe', 'one', { locked: true })] });
  renderPage();
  const colorButton = within(rowOf('Stripe')).getByLabelText('Marking color');
  expect(isDisabled(colorButton)).toBe(true);
  await act(async () => fireEvent.click(colorButton));
  expect(document.querySelector('.LimbsPage__colorPicker')).toBeNull();
  expect(send).not.toHaveBeenCalled();
});

it('sends a suggested colour as soon as it is picked', async () => {
  renderPage(
    withMarkingInfo({
      Stripe: markingInfo({ recommended_colors: ['#aa0000', '#00aa00'] }),
    }),
  );
  expect(
    within(rowOf('Spots')).queryByLabelText('Suggested color #aa0000'),
  ).toBeNull();
  await act(async () =>
    fireEvent.click(within(rowOf('Stripe')).getByLabelText('Marking color')),
  );
  fireEvent.click(screen.getByLabelText('Suggested color #00aa00'));
  expect(send).toHaveBeenCalledTimes(1);
  expect(send).toHaveBeenLastCalledWith('color_marking', {
    bodypart_slot: 'l_arm',
    marking_id: 'one',
    color: '#00aa00',
  });
  await settle();
  expect(document.querySelector('.LimbsPage__colorPicker')).toBeNull();
});

it('resets any row to the colour its marking starts in, locked ones included', () => {
  setMarkings({
    l_arm: [row('Stripe', 'one'), row('Spots', 'two', { locked: true })],
  });
  renderPage();
  for (const [name, marking_id] of [
    ['Stripe', 'one'],
    ['Spots', 'two'],
  ]) {
    fireEvent.click(within(rowOf(name)).getByLabelText('Reset marking color'));
    expect(send).toHaveBeenLastCalledWith('reset_marking_color', {
      bodypart_slot: 'l_arm',
      marking_id,
    });
  }
});

it('marks a row meant for other species, on a leg of the wrong shape, or following physique', () => {
  const notes = (name: string) =>
    Array.from(
      rowOf(name).querySelectorAll<HTMLElement>('.LimbsPage__markingNote'),
    );
  const warnings = (name: string) =>
    notes(name).filter((note) =>
      note.classList.contains('LimbsPage__markingNote--warning'),
    );
  const data = withLimbs({
    marking_choices: {
      l_arm: ['Stripe', 'Spots'],
      l_leg: ['Hoof', 'Sock'],
      chest: ['Belly', 'Chest Fur'],
    },
    marking_info: {
      Stripe: markingInfo(),
      Spots: markingInfo({ recommended_species: 'moth' }),
      Hoof: markingInfo({ leg_shapes: 1 }),
      Sock: markingInfo(),
      Belly: markingInfo({ gendered: 1 }),
      'Chest Fur': markingInfo(),
    },
    marking_icons: {
      l_arm: { Stripe: 'a', Spots: 'b' },
      l_leg: { Hoof: 'c', Sock: 'd' },
      chest: { Belly: 'e', 'Chest Fur': 'f' },
    },
  });
  const worn = {
    l_arm: [row('Stripe', 'l_arm_1'), row('Spots', 'l_arm_2')],
    l_leg: [row('Hoof', 'l_leg_1'), row('Sock', 'l_leg_2')],
    chest: [row('Belly', 'chest_1'), row('Chest Fur', 'chest_2')],
  };
  setMarkings(worn);
  const view = renderPage(data);
  // A human wearing a moth marking.
  expect(warnings('Spots')).toHaveLength(1);
  expect(notes('Stripe')).toHaveLength(0);
  // A plantigrade-only marking says so on plantigrade legs...
  expect(notes('Hoof')).toHaveLength(1);
  expect(warnings('Hoof')).toHaveLength(0);
  expect(notes('Sock')).toHaveLength(0);
  // ...and that the chest follows physique.
  expect(notes('Belly')).toHaveLength(1);
  expect(notes('Chest Fur')).toHaveLength(0);
  view.unmount();
  // On digitigrade legs it draws nothing, which is a warning; and a moth is who the moth marking is for.
  setMarkings(worn, {
    digi_legs: true,
    character_preferences: { misc: { species: 'moth' } },
  });
  renderPage(data);
  expect(warnings('Hoof')).toHaveLength(1);
  expect(warnings('Spots')).toHaveLength(0);
});

it('asks before a preset, saying what it puts on and whether it replaces every marking or only the body parts it covers', async () => {
  const presets = [
    { name: 'None', markings: null, keep_together: 0 },
    { name: 'Coat', markings: ['Stripe', 'Dots'], keep_together: 0 },
    { name: 'Suit', markings: ['Stripe'], keep_together: 1 },
  ].map((preset) => ({ ...preset, recommended_species: null }));
  const data = withLimbs({
    marking_choices: {
      l_arm: ['Stripe', 'Spots', 'Dots', 'Freckles'],
      head: ['Dots'],
      chest: ['Belly'],
    },
    marking_presets: presets,
  });
  const pick = async (name: string) => {
    const view = renderPage(data);
    await act(async () =>
      fireEvent.click(screen.getByPlaceholderText('Apply a preset...')),
    );
    await act(async () => fireEvent.click(screen.getByText(name)));
    return view;
  };
  let view = await pick('Coat');
  const scope = document.querySelector('.LimbsPage__presetScope')!;
  expect(scope.classList.contains('LimbsPage__presetScope--zones')).toBe(true);
  // The body parts it covers, and not the others.
  expect(scope.textContent).toContain('Left arm');
  expect(scope.textContent).toContain('Head');
  expect(scope.textContent).not.toContain('Chest');
  const contents = document.querySelector('.LimbsPage__presetMarkings')!;
  expect(contents.textContent).toContain('Stripe');
  expect(contents.textContent).toContain('Dots');
  expect(send).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Apply Preset'));
  expect(send).toHaveBeenLastCalledWith('set_preset', { preset: 'Coat' });
  view.unmount();
  for (const name of ['None', 'Suit']) {
    view = await pick(name);
    expect(document.querySelector('.LimbsPage__presetScope--all')).toBeTruthy();
    expect(!!document.querySelector('.LimbsPage__presetMarkings')).toBe(
      name === 'Suit',
    );
    fireEvent.click(screen.getByText('Cancel'));
    view.unmount();
  }
  expect(send).toHaveBeenCalledTimes(1);
});

it('keeps a saved row whose zone no longer takes its marking, named and removable', () => {
  setMarkings({
    l_arm: [
      row('Stripe', 'l_arm_1'),
      row('Old Band', 'l_arm_2', { color: '#123456' }),
    ],
  });
  renderPage(withMarkingInfo({ 'Old Band': markingInfo() }));
  const narrowed = rowOf('Old Band');
  expect(
    narrowed.querySelectorAll('.LimbsPage__markingNote--warning'),
  ).toHaveLength(1);
  expect(
    rowOf('Stripe').querySelectorAll('.LimbsPage__markingNote'),
  ).toHaveLength(0);
  fireEvent.click(within(narrowed).getByText('-'));
  expect(send).toHaveBeenLastCalledWith('remove_marking', {
    bodypart_slot: 'l_arm',
    marking_id: 'l_arm_2',
  });
});
