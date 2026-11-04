// THIS IS AN APHELION UI FILE
import { afterEach, expect, it, spyOn } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import * as actions from '../../../events/act';
import {
  gameDataAtom,
  gameStaticDataAtom,
  resetStore,
  store,
} from '../../../events/store';
import { CyborgEditorContent } from '../../CyborgEditor';
import { ProfileField } from './ProfileFields';
import { CYBORG_SLOTS, type LayoutStore } from './types';

afterEach(() => {
  cleanup();
  resetStore();
});

function textField(featureId: string, changes: unknown[], value = '') {
  render(
    <ProfileField
      featureId={featureId}
      label="Profile text"
      value={value}
      serverData={{ maximum_length: 99, maximum_bytes: 99 }}
      onChange={(next) => changes.push(next)}
    />,
  );
  return screen.getByRole('textbox', { name: 'Profile text' }) as
    | HTMLInputElement
    | HTMLTextAreaElement;
}

for (const featureId of ['custom_species_silicon', 'silicon_flavor_text']) {
  it.each([
    ['a'.repeat(100), 'a'.repeat(99)],
    ['é'.repeat(50), 'é'.repeat(49)],
    ['🦊'.repeat(25), '🦊'.repeat(24)],
    [`${'a'.repeat(98)}é`, 'a'.repeat(98)],
  ])(`${featureId} keeps whole characters at the native byte limit: %s`, (input, expected) => {
    const changes: unknown[] = [];
    const control = textField(featureId, changes);
    fireEvent.input(control, { target: { value: input } });
    expect(control.value).toBe(expected);
    fireEvent.blur(control);
    expect(changes).toEqual([expected]);
  });

  it(`${featureId} lets a composition finish before the byte limit`, () => {
    const changes: unknown[] = [];
    const control = textField(featureId, changes);
    fireEvent.compositionStart(control);
    fireEvent.input(control, {
      target: { value: 'é'.repeat(50) },
      isComposing: true,
    });
    expect(control.value).toBe('é'.repeat(50));
    fireEvent.compositionEnd(control);
    expect(control.value).toBe('é'.repeat(49));
    fireEvent.blur(control);
    expect(changes).toEqual(['é'.repeat(49)]);
  });
}

it('keeps textarea tab insertion within the byte budget and permits replacing a selection', () => {
  const changes: unknown[] = [];
  const original = `${'é'.repeat(49)}a`;
  const control = textField(
    'silicon_flavor_text',
    changes,
    original,
  ) as HTMLTextAreaElement;
  control.setSelectionRange(original.length, original.length);
  fireEvent.keyDown(control, { key: 'Tab' });
  expect(control.value).toBe(original);
  control.setSelectionRange(0, 1);
  fireEvent.keyDown(control, { key: 'Tab' });
  expect(control.value).toBe(`\t${original.slice(1)}`);
  fireEvent.blur(control);
  expect(changes).toEqual([`\t${original.slice(1)}`]);
});

it.each([
  ['ooc_notes_silicon', 'SFW'],
  ['ooc_notes_silicon_nsfw', 'NSFW'],
])('shows %s fallback guidance as a placeholder and saves only what the player enters', (featureId, label) => {
  const changes: unknown[] = [];
  render(
    <ProfileField
      featureId={featureId}
      label="Notes"
      value=""
      serverData={{ maximum_length: 1024 }}
      onChange={(next) => changes.push(next)}
    />,
  );
  const input = screen.getByPlaceholderText(
    `Leave blank to use your human ${label} OOC notes.`,
  ) as HTMLTextAreaElement;
  expect(input.value).toBe('');
  fireEvent.input(input, { target: { value: 'My cyborg notes' } });
  fireEvent.blur(input);
  expect(changes).toEqual(['My cyborg notes']);
});

function layoutStore(): LayoutStore {
  return {
    schema_version: 1,
    active: Object.fromEntries(
      CYBORG_SLOTS.map((slot) => [
        slot,
        {
          pixel_x: 0,
          pixel_y: 0,
          rotation: 0,
          scale: 1,
          colors: ['#ffffff', '#ffffff', '#ffffff'],
          advanced: {},
        },
      ]),
    ) as LayoutStore['active'],
    presets: {},
    model_defaults: {},
  };
}

it('runs the editor window from its own backend before any resources arrive', () => {
  // The test setup stands sendAct in for the real one, so we watch it
  const sendAct = spyOn(actions, 'sendAct');
  try {
    store.set(gameStaticDataAtom, {
      cyborg_resources: null,
      preference_data: { cyborg_size: { choices: [0.75, 1, 1.6, 2, 2.5] } },
    });
    store.set(gameDataAtom, {
      cyborg_customization: {
        allowed: true,
        moving: false,
        context: 3,
        model: 'first',
        models: [],
        pose: 'idle',
        poses: ['idle'],
        direction: 2,
        arousal: 'none',
        body_scale: 1,
        store: layoutStore(),
        layers: null,
      },
      name: 'Unit',
      values: { cyborg_size: 1 },
      active_slot: 2,
    });
    render(<CyborgEditorContent />);
    // A preference the character can't have is left out of the values
    expect(
      screen.getAllByText('Unavailable for this character.').length > 0,
    ).toBe(true);
    fireEvent.change(screen.getByRole('combobox', { name: 'Body size' }), {
      target: { value: '1.6' },
    });
    const set = sendAct.mock.calls.find(
      ([action]) => action === 'set_preference',
    );
    expect(set?.[1]).toEqual({ preference: 'cyborg_size', value: 1.6 });
  } finally {
    sendAct.mockRestore();
  }
});
