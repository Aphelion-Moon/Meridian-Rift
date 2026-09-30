// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { cleanup, fireEvent, render, within } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';

import type { Language } from '../types';
import { LanguagesPage } from './LanguagesMenu';

const language = (name: string, speaking: boolean): Language => ({
  name,
  icon: name.toLowerCase().replace(/\s/g, '_'),
  description: `Words of ${name}.`,
  speaking,
});

describe('Languages page understanding', () => {
  let previousData: unknown;
  let send: ReturnType<typeof spyOn>;

  beforeEach(() => {
    previousData = backendStore.get(gameDataAtom);
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
    send = spyOn(actions, 'sendAct');
  });

  afterEach(() => {
    cleanup();
    send.mockRestore();
    backendStore.set(gameDataAtom, previousData as never);
  });

  const sectionOf = (view: ReturnType<typeof render>, name: string) =>
    [...view.container.querySelectorAll('.Section')].find(
      (section) =>
        section.querySelector('.Section__titleText')?.textContent?.trim() ===
        name,
    ) as HTMLElement;

  const sliderOf = (view: ReturnType<typeof render>, name: string) =>
    within(sectionOf(view, name)).getByRole('slider') as HTMLInputElement;

  it('sets a slider at the level of each language only understood, with a line as heard, and none for one spoken', () => {
    const view = render(<LanguagesPage />);

    expect(sliderOf(view, 'Draconic').value).toBe('40');
    expect(
      within(sectionOf(view, 'Draconic')).getByText(
        'Could you tell me hsiss the medical bay is?',
      ),
    ).toBeTruthy();

    // A language the server gave no level is understood in full.
    expect(sliderOf(view, 'Moffic').value).toBe('100');

    // Speaking a language means understanding all of it: no slider.
    expect(
      within(sectionOf(view, 'Sol Common')).queryByRole('slider'),
    ).toBeNull();
  });

  it('shows the level as the slider moves and sends it only when let go', () => {
    const view = render(<LanguagesPage />);
    const slider = sliderOf(view, 'Draconic');

    fireEvent.input(slider, { target: { value: '75' } });
    expect(sectionOf(view, 'Draconic').textContent).toContain('75%');
    expect(send).not.toHaveBeenCalled();

    fireEvent.change(slider);
    expect(send).toHaveBeenCalledTimes(1);
    expect(send).toHaveBeenLastCalledWith('set_language_understanding', {
      language_name: 'Draconic',
      level: 75,
    });
  });
});
