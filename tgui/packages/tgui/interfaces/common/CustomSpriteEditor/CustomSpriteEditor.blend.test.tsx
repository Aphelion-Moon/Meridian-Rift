// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { fireEvent, screen } from '@testing-library/react';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  fixture,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { renderEditor } from '../../../__mocks__/renderCustomSpriteEditor';

setupEditorTests();

it('lets markings, and only markings, blend Custom colors with the mutant color', () => {
  const { view } = renderEditor('markings');
  fireEvent.click(screen.getByText('Blending options'));
  fireEvent.click(screen.getByText('Blend with mutant color'));
  expect(send).toHaveBeenLastCalledWith('setColorMode', { mode: 'mutant' });
  view.unmount();
  backendStore.set(gameDataAtom, { ...fixture(), colorMode: 'mutant' });
  renderEditor('markings');
  fireEvent.click(screen.getByText('Blending options'));
  fireEvent.click(screen.getByText('Blend with mutant color'));
  expect(send).toHaveBeenLastCalledWith('setColorMode', { mode: 'literal' });
});

it('keeps hair editors on hair color blending', () => {
  renderEditor('hair');
  fireEvent.click(screen.getByText('Blending options'));
  expect(screen.getByText('Blend with hair color')).toBeTruthy();
  expect(screen.queryByText('Blend with mutant color')).toBeNull();
});
