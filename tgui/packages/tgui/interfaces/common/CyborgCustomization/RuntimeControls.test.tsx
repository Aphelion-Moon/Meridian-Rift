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
  fireEvent.click(screen.getByLabelText('Show penis'));
  fireEvent.click(screen.getByLabelText('Unaroused penis'));
  fireEvent.click(screen.getByLabelText('Partially aroused penis'));
  fireEvent.click(screen.getByLabelText('Fully aroused penis'));
  fireEvent.click(screen.getByText('Show cyborg parts to me'));
  expect(actions).toEqual([
    { operation: 'activate', slot: 'penis', value: false, character_slot: 2 },
    { operation: 'activate', slot: 'penis', value: true, character_slot: 2 },
    { operation: 'arousal', slot: 'penis', value: 'none', character_slot: 2 },
    { operation: 'arousal', slot: 'penis', value: 'partial', character_slot: 2 },
    { operation: 'arousal', slot: 'penis', value: 'full', character_slot: 2 },
    { operation: 'viewer', value: true, character_slot: 2 },
  ]);
});
