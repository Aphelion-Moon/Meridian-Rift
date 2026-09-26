import { afterEach, expect, it } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { LayoutControls } from './LayoutControls';

afterEach(cleanup);

import {
  CYBORG_SLOTS,
  type Layout,
  type LayoutEntry,
  type LayoutStore,
} from './types';

it('edits the direction and pose currently shown in the creator preview', async () => {
  const store: LayoutStore = {
    schema_version: 1,
    active: Object.fromEntries<LayoutEntry>(
      CYBORG_SLOTS.map((slot) => [
        slot,
        {
          pixel_x: 0,
          pixel_y: 0,
          rotation: 0,
          scale: 1,
          colors: ['#ffffff', '#ffffff', '#ffffff'],
          advanced: {},
        },
      ]),
    ) as Layout,
    presets: {},
    model_defaults: {},
  };
  const actions: Record<string, unknown>[] = [];
  const previewChanges: Record<string, string>[] = [];
  await act(async () => {
    render(
      <LayoutControls
        store={store}
        onAction={(action) => actions.push(action)}
        preview={{
          direction: 'north',
          pose: 'rest',
          arousal: 'none',
          poses: ['idle', 'rest', 'sit'],
          onChange: (change) => previewChanges.push(change),
        }}
      />,
    );
  });
  fireEvent.click(screen.getByText('This pose'));
  await act(async () =>
    fireEvent.click(screen.getByText('Visible in this view')),
  );
  expect(actions[0]).toMatchObject({
    operation: 'set_placement',
    target: { scope: 'pose', direction: 'north', pose: 'rest' },
    changes: { visible: false },
  });
  await act(async () => fireEvent.click(screen.getByText('Resting')));
  expect(screen.queryByText('bellyup') === null).toBe(true);
  await act(async () => fireEvent.click(screen.getByText('Sitting')));
  expect(previewChanges).toEqual([{ pose: 'sit' }]);
  await act(async () => cleanup());
});

it.each([
  false,
  true,
])('preserves effective direction settings (explicit pose: %s)', async (explicitPose) => {
  const store: LayoutStore = {
    schema_version: 1,
    active: Object.fromEntries<LayoutEntry>(
      CYBORG_SLOTS.map((slot) => [
        slot,
        {
          pixel_x: 0,
          pixel_y: 0,
          rotation: 0,
          scale: 1,
          colors: ['#ffffff', '#ffffff', '#ffffff'],
          advanced: {
            south: {
              visible: false,
              pixel_x: 12,
              pixel_y: -4,
              rotation: 20,
              scale: 1.5,
              priority: 3,
              arousal: { full: { pixel_y: 8 } },
            },
          },
        },
      ]),
    ) as Layout,
    presets: {},
    model_defaults: {},
  };
  if (explicitPose) {
    store.active.penis.advanced.rest_south = {
      visible: true,
      pixel_x: 0,
      pixel_y: 7,
      rotation: 0,
      scale: 1,
      priority: 5,
    };
  }
  const actions: Record<string, unknown>[] = [];
  await act(async () => {
    render(
      <LayoutControls
        store={store}
        onAction={(action) => actions.push(action)}
      />,
    );
  });

  fireEvent.click(screen.getByText('This pose'));
  await act(async () => fireEvent.click(screen.getByText('Standing')));
  await act(async () => fireEvent.click(screen.getByText('Resting')));
  await act(async () =>
    fireEvent.click(screen.getByText('Visible in this view')),
  );

  expect(actions).toHaveLength(1);
  expect(actions[0]).toMatchObject({
    operation: 'set_placement',
    slot: 'penis',
    target: { scope: 'pose', direction: 'south', pose: 'rest' },
    changes: { visible: !explicitPose },
  });
  if (explicitPose) {
    expect(store.active.penis.advanced.rest_south.visible).toBe(true);
  } else {
    expect(store.active.penis.advanced.rest_south).toBeUndefined();
  }
  expect(store.active.penis.advanced.south.visible).toBe(false);
  await act(async () => cleanup());
});
