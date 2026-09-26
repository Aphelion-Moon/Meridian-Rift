// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';

import * as actions from '../events/act';
import { gameDataAtom, gameStaticDataAtom, store } from '../events/store';
import { TitleScreenManager } from './TitleScreenManager';

let sendAct: ReturnType<typeof spyOn<typeof actions, 'sendAct'>>;
let previousData: Record<string, unknown>;
let previousStaticData: Record<string, unknown>;

beforeEach(() => {
  previousData = store.get(gameDataAtom);
  previousStaticData = store.get(gameStaticDataAtom);
  store.set(gameStaticDataAtom, {});
  store.set(gameDataAtom, {
    screens: [
      {
        name: null,
        isDefault: true,
        isAlt: false,
        url: 'asset://title.png',
        variant: 'convex',
        bezel: 'rusty',
        texture: 'none',
        wordmark: true,
      },
    ],
    variants: [],
    textures: [],
    bezels: [
      { id: 'rusty', name: 'Rusty', desc: 'Weathered industrial metal' },
      { id: 'rusty-dark', name: 'Dark Brown', desc: 'Dark weathered metal' },
      {
        id: 'aphelion',
        name: 'Aphelion',
        desc: 'Warm brown fine-grain housing',
      },
      { id: 'classic', name: 'Classic', desc: 'The original monitor rim' },
      { id: 'none', name: 'None', desc: 'No monitor rim' },
    ],
    draftScreen: null,
    draftScreenChosen: true,
    draftVariant: 'convex',
    draftBezel: 'rusty',
    draftTexture: 'none',
    draftWordmark: true,
    pending: false,
  });
  sendAct = spyOn(actions, 'sendAct').mockImplementation(() => undefined);
});

afterEach(() => {
  cleanup();
  sendAct.mockRestore();
  store.set(gameDataAtom, previousData);
  store.set(gameStaticDataAtom, previousStaticData);
});

describe('TitleScreenManager bezel choices', () => {
  it('routes screen and scanline choices to their own draft fields', () => {
    store.set(gameDataAtom, (data) => ({
      ...data,
      variants: [
        { id: 'convex', name: 'Convex', desc: 'Curved screen' },
        { id: 'flat', name: 'Flat', desc: 'Flat screen' },
      ],
      textures: [
        { id: 'none', name: 'No scanlines', desc: 'Clear screen' },
        { id: 'scanlines-light', name: 'Original', desc: 'Original scanlines' },
      ],
    }));
    render(<TitleScreenManager />);

    expect(
      screen.getByRole('button', { name: 'Convex', pressed: true }),
    ).toBeDefined();
    expect(
      screen.getByRole('button', { name: 'No scanlines', pressed: true }),
    ).toBeDefined();
    fireEvent.click(
      screen.getByRole('button', { name: 'Flat', pressed: false }),
    );
    expect(sendAct).toHaveBeenLastCalledWith('set', { variant: 'flat' });
    fireEvent.click(
      screen.getByRole('button', { name: 'Original', pressed: false }),
    );
    expect(sendAct).toHaveBeenLastCalledWith('set', { texture: 'scanlines-light' });
    expect(sendAct).toHaveBeenCalledTimes(2);
  });

  it('sends each selected bezel ID to the draft without applying it', () => {
    render(<TitleScreenManager />);

    for (const [name, bezel] of [
      ['Rusty', 'rusty'],
      ['Dark Brown', 'rusty-dark'],
      ['Aphelion', 'aphelion'],
      ['Classic', 'classic'],
      ['None', 'none'],
    ]) {
      fireEvent.click(screen.getByRole('button', { name }));
      expect(sendAct).toHaveBeenLastCalledWith('set', { bezel });
    }
    expect(sendAct).toHaveBeenCalledTimes(5);
  });

  for (const { value, expected, name } of [
    { value: undefined, expected: 'rusty-dark', name: 'Dark Brown' },
    { value: 'rusty', expected: 'rusty', name: 'Rusty' },
    { value: 'rusty-dark', expected: 'rusty-dark', name: 'Dark Brown' },
    { value: 'aphelion', expected: 'aphelion', name: 'Aphelion' },
    { value: 'classic', expected: 'classic', name: 'Classic' },
    { value: 'none', expected: 'none', name: 'None' },
    { value: 1, expected: 'classic', name: 'Classic' },
    { value: 0, expected: 'none', name: 'None' },
  ]) {
    it(`previews ${expected} and selects its button for draft value ${value}`, () => {
      store.set(gameDataAtom, (data) => ({ ...data, draftBezel: value }));
      render(<TitleScreenManager />);

      expect(
        screen.getByRole('button', { name }).getAttribute('aria-pressed'),
      ).toBe('true');
      expect(screen.getAllByRole('button', { pressed: true })).toHaveLength(1);
      const artwork = document.querySelector(
        '.TitleScreenManager__preview .lobby-title-art',
      );
      expect(artwork?.getAttribute('data-bezel')).toBe(expected);
      expect(artwork?.classList.contains('lobby-title-art--bezel')).toBe(
        expected !== 'none',
      );
    });
  }
});
