import { afterEach, expect, it } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import {
  FeatureLongTextInput,
  FeatureShortTextInput,
} from './preferences/features/base';
import type { CharacterPreferencesData } from './types';

afterEach(cleanup);

for (const Component of [FeatureShortTextInput, FeatureLongTextInput]) {
  it.each([
    ['a'.repeat(100), 'a'.repeat(99)],
    ['é'.repeat(50), 'é'.repeat(49)],
    ['🦊'.repeat(25), '🦊'.repeat(24)],
    [`${'a'.repeat(98)}é`, 'a'.repeat(98)],
  ])(`${Component.name} preserves complete characters at the native byte limit: %s`, (input, expected) => {
    const changes: string[] = [];
    render(
      <Component
        featureId="cyborg_custom_species"
        label="Profile text"
        value=""
        serverData={{ maximum_length: 99, maximum_bytes: 99 }}
        character_preferences={{} as CharacterPreferencesData}
        handleSetValue={(value) => changes.push(value)}
      />,
    );
    const control = screen.getByRole('textbox', {
      name: 'Profile text',
    }) as HTMLInputElement;
    fireEvent.input(control, { target: { value: input } });
    expect(control.value).toBe(expected);
    fireEvent.blur(control);
    expect(changes).toEqual([expected]);
  });

  it(`${Component.name} finishes composition before applying the byte limit`, () => {
    const changes: string[] = [];
    render(
      <Component
        featureId="cyborg_custom_species"
        label="Profile text"
        value=""
        serverData={{ maximum_length: 99, maximum_bytes: 99 }}
        character_preferences={{} as CharacterPreferencesData}
        handleSetValue={(value) => changes.push(value)}
      />,
    );
    const control = screen.getByRole('textbox', {
      name: 'Profile text',
    }) as HTMLInputElement;
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

  it(`${Component.name} leaves character-only preferences unchanged`, () => {
    const changes: string[] = [];
    render(
      <Component
        featureId="another_preference"
        label="Profile text"
        value=""
        serverData={{ maximum_length: 99 }}
        character_preferences={{} as CharacterPreferencesData}
        handleSetValue={(value) => changes.push(value)}
      />,
    );
    const control = screen.getByRole('textbox', {
      name: 'Profile text',
    }) as HTMLInputElement;
    fireEvent.input(control, { target: { value: 'é'.repeat(50) } });
    fireEvent.blur(control);
    expect(changes).toEqual(['é'.repeat(50)]);
  });
}

it('keeps textarea tab insertion within the byte budget and permits replacing a selection', () => {
  const changes: string[] = [];
  const original = `${'é'.repeat(49)}a`;
  render(
    <FeatureLongTextInput
      featureId="cyborg_flavor_text"
      label="Profile text"
      value={original}
      serverData={{ maximum_length: 99, maximum_bytes: 99 }}
      character_preferences={{} as CharacterPreferencesData}
      handleSetValue={(value) => changes.push(value)}
    />,
  );
  const control = screen.getByRole('textbox', {
    name: 'Profile text',
  }) as HTMLTextAreaElement;
  control.setSelectionRange(original.length, original.length);
  fireEvent.keyDown(control, { key: 'Tab' });
  expect(control.value).toBe(original);
  control.setSelectionRange(0, 1);
  fireEvent.keyDown(control, { key: 'Tab' });
  expect(control.value).toBe(`\t${original.slice(1)}`);
  fireEvent.blur(control);
  expect(changes).toEqual([`\t${original.slice(1)}`]);
});
