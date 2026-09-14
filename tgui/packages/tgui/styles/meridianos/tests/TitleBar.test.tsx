// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import { Provider } from 'jotai';
import {
  configAtom,
  debugThemeAtom,
  meridianThemeAtom,
  store,
} from '../../../events/store';
import { TitleBar } from '../../../layouts/TitleBar';

const originalSendMessage = Byond.sendMessage;

beforeEach(() => {
  store.set(configAtom, (previous) => ({
    ...previous,
    meridianTheme: 'meridian_electra',
  }));
  store.set(debugThemeAtom, 'meridian_vector');
});

afterEach(() => {
  cleanup();
  Byond.sendMessage = originalSendMessage;
});

describe('TitleBar theme utilities', () => {
  it('keeps the gear beside development controls and sends the base preference', async () => {
    const sendMessage = mock(() => {});
    Byond.sendMessage = sendMessage as typeof Byond.sendMessage;
    const view = render(
      <Provider store={store}>
        <TitleBar canClose title="Test" />
      </Provider>,
    );

    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });
    const debug = screen.getByRole('button', {
      name: 'Toggle development showcase',
    });
    expect(trigger.closest('.TitleBar__utilities')).toBe(
      debug.closest('.TitleBar__utilities'),
    );
    expect(screen.getByRole('button', { name: 'Close window' })).toBeTruthy();

    await act(async () => {
      fireEvent.click(trigger);
    });
    await act(async () => {
      fireEvent.click(screen.getByRole('menuitemradio', { name: /Classic/i }));
    });
    await waitFor(() => expect(screen.queryAllByRole('menu').length).toBe(0));

    expect(store.get(meridianThemeAtom)).toBe('meridian_classic');
    expect(store.get(debugThemeAtom)).toBeNull();
    expect(sendMessage).toHaveBeenCalledWith('setMeridianTheme', {
      theme: 'meridian_classic',
    });
    expect(
      view.container.querySelectorAll('.TitleBar__utilityButton'),
    ).toHaveLength(1);
  });

  it('clears a debug override even when the saved theme is reselected', async () => {
    const sendMessage = mock(() => {});
    Byond.sendMessage = sendMessage as typeof Byond.sendMessage;
    render(
      <Provider store={store}>
        <TitleBar canClose title="Test" />
      </Provider>,
    );

    await act(async () => {
      fireEvent.click(
        screen.getByRole('button', {
          name: /change base interface theme/i,
        }),
      );
    });
    await act(async () => {
      fireEvent.click(screen.getByRole('menuitemradio', { name: /Electra/i }));
    });
    await waitFor(() => expect(screen.queryAllByRole('menu').length).toBe(0));

    expect(store.get(debugThemeAtom)).toBeNull();
    expect(sendMessage).toHaveBeenCalledWith('setMeridianTheme', {
      theme: 'meridian_electra',
    });
  });
});
