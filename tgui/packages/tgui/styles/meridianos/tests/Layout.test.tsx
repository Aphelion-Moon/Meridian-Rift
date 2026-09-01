// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { act, cleanup, render } from '@testing-library/react';
import { Provider } from 'jotai';
import {
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
    meridianTheme: 'meridian',
  }));
  store.set(debugThemeAtom, null);
});

afterEach(() => {
  cleanup();
  document.documentElement.className = '';
  store.set(debugThemeAtom, null);
});

describe('Layout theme class management', () => {
  it('preserves unrelated root classes while reconciling managed classes', () => {
    document.documentElement.classList.add('unrelated-runtime-class');
    const view = render(
      <Provider store={store}>
        <Layout theme="ntos">Standard</Layout>
      </Provider>,
    );

    expect(
      document.documentElement.classList.contains('unrelated-runtime-class'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-meridian')).toBe(
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

    expect(document.documentElement.classList.contains('theme-meridian')).toBe(
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
    store.set(debugThemeAtom, 'meridian_bastion');
    const view = render(
      <Provider store={store}>
        <Layout theme="paper">Bastion</Layout>
      </Provider>,
    );

    expect(
      document.documentElement.classList.contains('theme-meridian_bastion'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-paper')).toBe(
      false,
    );

    view.unmount();
    expect(
      document.documentElement.classList.contains('theme-meridian_bastion'),
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

  it('restores base TGUI classes for Classic NT', () => {
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
    store.set(meridianThemeAtom, 'meridian_pipboy');
    render(
      <Provider store={store}>
        <Layout>Wastelander</Layout>
      </Provider>,
    );

    expect(
      document.documentElement.classList.contains('theme-meridian_pipboy'),
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
