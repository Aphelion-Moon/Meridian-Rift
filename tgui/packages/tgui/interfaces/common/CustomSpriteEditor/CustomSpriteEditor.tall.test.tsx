// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { render } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  fixture,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { CustomSpriteEditor } from './index';

setupEditorTests();

it('backs a tall hair canvas with the tall tile', () => {
  backendStore.set(gameDataAtom, {
    ...fixture(32, 48),
    backgrounds: [
      {
        name: 'Grass',
        url: 'grass.png',
        wideUrl: 'wide.png',
        tallUrl: 'tall.png',
      },
    ],
    defaultBackground: 'Grass',
  });
  const view = render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  const canvas = view.container.querySelector('canvas')!;
  expect(canvas.style.backgroundImage).toContain('tall.png');
});

it('stands pictures of a tall canvas on the plain tile, which repeats upward', () => {
  backendStore.set(gameDataAtom, {
    ...fixture(32, 48),
    previews: { 1: '', 2: 'front.png', 4: '', 8: '' },
    backgrounds: [
      {
        name: 'Grass',
        url: 'grass.png',
        wideUrl: 'wide.png',
        tallUrl: 'tall.png',
      },
    ],
    defaultBackground: 'Grass',
  });
  const view = render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  const picture = view.container.querySelector<HTMLElement>(
    '.CustomSpriteEditor__tile',
  )!;
  expect(picture.style.backgroundImage).toContain('grass.png');
});
