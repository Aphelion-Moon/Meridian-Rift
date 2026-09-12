// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { act, cleanup, render } from '@testing-library/react';
import { Provider } from 'jotai';
import {
  backendStateAtom,
  configAtom,
  debugThemeAtom,
  kitchenSinkAtom,
  meridianThemeAtom,
  resetStore,
  store,
} from '../../../events/store';
import { Layout } from '../../../layouts/Layout';

beforeEach(() => {
  document.documentElement.className = '';
  store.set(configAtom, (previous) => ({
    ...previous,
    meridianTheme: 'meridian_electra',
  }));
  store.set(debugThemeAtom, null);
});

afterEach(() => {
  cleanup();
  document.documentElement.className = '';
  store.set(debugThemeAtom, null);
});

describe('Layout theme class management', () => {
  it('preserves route state on reselection while applying changed preferences', () => {
    const beforeConfig = store.get(configAtom);
    const beforeBackend = store.get(backendStateAtom);
    let notifications = 0;
    const unsubscribe = store.sub(backendStateAtom, () => notifications++);
    try {
      store.set(meridianThemeAtom, 'meridian_electra');
      expect(store.get(configAtom)).toBe(beforeConfig);
      expect(store.get(backendStateAtom)).toBe(beforeBackend);
      expect(notifications).toBe(0);

      store.set(meridianThemeAtom, 'meridian_foundry');
      expect(store.get(meridianThemeAtom)).toBe('meridian_foundry');
      expect(store.get(configAtom)).not.toBe(beforeConfig);
      expect(notifications).toBe(1);
    } finally {
      unsubscribe();
    }
  });

  it('preserves unrelated root classes while reconciling managed classes', () => {
    document.documentElement.classList.add('unrelated-runtime-class');
    const view = render(
      <Provider store={store}>
        <Layout theme="ntos">Electra</Layout>
      </Provider>,
    );

    expect(
      document.documentElement.classList.contains('unrelated-runtime-class'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-meridian_electra')).toBe(
      true,
    );
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      true,
    );

    view.rerender(
      <Provider store={store}>
        <Layout theme="paper">Paper</Layout>
      </Provider>,
    );

    expect(document.documentElement.classList.contains('theme-meridian_electra')).toBe(
      false,
    );
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      false,
    );
    expect(document.documentElement.classList.contains('theme-paper')).toBe(
      true,
    );
    expect(
      document.documentElement.classList.contains('unrelated-runtime-class'),
    ).toBe(true);
  });

  it('preserves multi-class specialty modifiers', () => {
    render(
      <Provider store={store}>
        <Layout theme="heretic heretic-theme-ascended">Ascended</Layout>
      </Provider>,
    );

    expect(document.documentElement.classList.contains('theme-heretic')).toBe(
      true,
    );
    expect(
      document.documentElement.classList.contains('heretic-theme-ascended'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      false,
    );
  });

  it('applies a window-local development override and cleans it on unmount', () => {
    store.set(debugThemeAtom, 'meridian_scavenger');
    const view = render(
      <Provider store={store}>
        <Layout theme="paper">Scavenger</Layout>
      </Provider>,
    );

    expect(
      document.documentElement.classList.contains('theme-meridian_scavenger'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-paper')).toBe(
      false,
    );

    view.unmount();
    expect(
      document.documentElement.classList.contains('theme-meridian_scavenger'),
    ).toBe(false);
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      false,
    );
  });

  it('discards development-only state when the TGUI window closes', () => {
    store.set(debugThemeAtom, 'meridian_synapse');
    store.set(kitchenSinkAtom, true);

    resetStore();

    expect(store.get(debugThemeAtom)).toBeNull();
    expect(store.get(kitchenSinkAtom)).toBe(false);
  });

  it('restores base TGUI classes for Classic', () => {
    store.set(meridianThemeAtom, 'meridian_classic');
    render(
      <Provider store={store}>
        <Layout>Classic</Layout>
      </Provider>,
    );

    expect(
      document.documentElement.classList.contains('theme-nanotrasen'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      false,
    );
  });

  it('applies Wastelander through the Meridian console layer', () => {
    store.set(meridianThemeAtom, 'meridian_wastelander');
    render(
      <Provider store={store}>
        <Layout>Wastelander</Layout>
      </Provider>,
    );

    expect(
      document.documentElement.classList.contains('theme-meridian_wastelander'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      true,
    );
    expect(
      document.documentElement.classList.contains('theme-nanotrasen'),
    ).toBe(false);
  });

  it('reconciles rapid base changes while specialty themes stay authoritative', () => {
    document.documentElement.classList.add('unrelated-runtime-class');
    const view = render(
      <Provider store={store}>
        <Layout theme="meridian_vector">Base</Layout>
      </Provider>,
    );

    act(() => store.set(meridianThemeAtom, 'meridian_classic'));
    expect(
      document.documentElement.classList.contains('theme-nanotrasen'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      false,
    );

    act(() => store.set(meridianThemeAtom, 'meridian_cyberpunk'));
    expect(
      document.documentElement.classList.contains('theme-meridian_cyberpunk'),
    ).toBe(true);
    expect(
      document.documentElement.classList.contains('theme-nanotrasen'),
    ).toBe(false);

    view.rerender(
      <Provider store={store}>
        <Layout theme="paper">Specialty</Layout>
      </Provider>,
    );
    act(() => store.set(meridianThemeAtom, 'meridian_foundry'));
    expect(document.documentElement.classList.contains('theme-paper')).toBe(
      true,
    );
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      false,
    );
    expect(
      document.documentElement.classList.contains('unrelated-runtime-class'),
    ).toBe(true);
  });
});
