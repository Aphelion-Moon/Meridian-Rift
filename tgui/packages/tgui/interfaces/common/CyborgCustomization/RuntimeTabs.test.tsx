// THIS IS AN APHELION UI FILE
import { afterEach, expect, it } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { gameDataAtom, resetStore, store } from '../../../events/store';
import { MainContent } from '../../InteractionPanel/MainContent';

afterEach(() => {
  cleanup();
  resetStore();
});

it("puts a borg's own parts in the interaction panel, without a stray zero", () => {
  store.set(gameDataAtom, {
    erp_interaction: 0,
    cyborg_runtime: {
      parts: [],
      character_slot: 1,
      allowed: 1,
      viewer_enabled: 0,
      body_visible: 1,
      model_name: 'Service / Drake',
      model_default: 0,
    },
  });
  const view = render(<MainContent />);
  expect(view.container.textContent).not.toContain('0');
  fireEvent.click(screen.getByText('Genital Options'));
  expect(
    screen.getByText('No parts configured for this chassis.').textContent,
  ).toBe('No parts configured for this chassis.');
});
