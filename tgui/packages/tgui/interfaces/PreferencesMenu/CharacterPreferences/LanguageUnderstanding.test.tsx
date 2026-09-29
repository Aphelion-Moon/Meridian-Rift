// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { cleanup, render, within } from '@testing-library/react';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';

import type { Language } from '../types';
import { LanguagesPage } from './LanguagesMenu';
import { understandingLabel } from './LanguageUnderstanding';

const language = (name: string, speaking: boolean): Language => ({
  name,
  icon: name.toLowerCase().replace(/\s/g, '_'),
  description: `Words of ${name}.`,
  speaking,
});

describe('understandingLabel', () => {
  it('names how much of what is said gets through', () => {
    expect(understandingLabel(100)).toBe('all of it');
    expect(understandingLabel(95)).toBe('nearly all of it');
    expect(understandingLabel(75)).toBe('most of it');
    expect(understandingLabel(40)).toBe('some of it');
    expect(understandingLabel(25)).toBe('a few words');
  });
});

describe('Languages page understanding', () => {
  let previousData: unknown;

  beforeEach(() => {
    previousData = backendStore.get(gameDataAtom);
  });

  afterEach(() => {
    cleanup();
    backendStore.set(gameDataAtom, previousData as never);
  });

  const sectionOf = (view: ReturnType<typeof render>, name: string) =>
    [...view.container.querySelectorAll('.Section')].find(
      (section) =>
        section.querySelector('.Section__titleText')?.textContent?.trim() ===
        name,
    ) as HTMLElement;

  it('shows how much of a language only understood gets through, with a line as heard, and nothing for one spoken', () => {
    backendStore.set(gameDataAtom, {
      total_language_points: 3,
      selected_languages: [
        language('Sol Common', true),
        language('Draconic', false),
        language('Moffic', false),
      ],
      unselected_languages: [],
      language_understanding: { Draconic: 40 },
      language_understanding_samples: {
        Draconic: 'Could you tell me hsiss the medical bay is?',
        Moffic: 'Could you tell me where the medical bay is?',
      },
    } as never);
    const view = render(<LanguagesPage />);

    const draconic = within(sectionOf(view, 'Draconic'));
    expect(draconic.getByText('Follows')).toBeTruthy();
    expect(draconic.getByText('some of it')).toBeTruthy();
    expect(sectionOf(view, 'Draconic').textContent).toContain('40');
    expect(
      draconic.getByText('Could you tell me hsiss the medical bay is?'),
    ).toBeTruthy();

    // A language the server gave no level is followed in full.
    expect(
      within(sectionOf(view, 'Moffic')).getByText('all of it'),
    ).toBeTruthy();

    // Speaking a language means following it: no slider.
    expect(
      within(sectionOf(view, 'Sol Common')).queryByText('Follows'),
    ).toBeNull();
  });
});
