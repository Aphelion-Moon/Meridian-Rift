import { afterEach, expect, it } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { RuntimeControls } from './RuntimeControls';

afterEach(cleanup);

it('exposes only configured usage controls and reports the independent viewer gate', () => {
  const actions: unknown[] = [];
  const view = render(
    <RuntimeControls
      data={{
        parts: [
          {
            slot: 'penis',
            choice: 'Dogborg Knotted',
            active: 1,
            arousal: 'none',
            can_arouse: 1,
          },
        ],
        character_slot: 2,
        allowed: 1,
        viewer_enabled: 0,
        body_visible: 1,
        model_name: 'Engineering / Drake',
        model_default: 1,
      }}
      onAction={(p) => actions.push(p)}
    />,
  );
  expect(
    screen.getByText(
      'Your display is off. Active parts remain hidden from you.',
    ),
  ).toBeTruthy();
  expect(view.container.querySelectorAll('input[type="range"]').length).toBe(0);
  expect(screen.queryByText('Save default')).toBeNull();
  expect(screen.queryByText('Sheath')).toBeNull();
  fireEvent.click(screen.getByLabelText('Hide penis'));
  expect(actions).toEqual([
    { operation: 'activate', slot: 'penis', value: false, character_slot: 2 },
  ]);
});
