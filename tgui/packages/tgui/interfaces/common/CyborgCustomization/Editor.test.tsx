import { afterEach, expect, it } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { AdjustmentSlider } from '../AdjustmentSlider';
import { CyborgCharacterEditor } from './CharacterEditor';
import { CyborgPreview } from './CyborgPreview';
import { LayoutControls } from './LayoutControls';
import { PresetControls } from './PresetControls';
import { PreviewPart } from './PreviewPart';
import { CYBORG_SLOTS, type LayoutStore } from './types';

afterEach(cleanup);

it('uses the same pose target for visual dragging and sliders without mirroring pose corrections', () => {
  const store = layoutStore();
  store.active.penis.pixel_x = 10;
  store.active.penis.advanced.rest_west = {
    visible: true,
    pixel_x: 5,
    pixel_y: 7,
    rotation: 0,
    scale: 1,
    priority: 8,
  };
  store.active.penis.advanced.sit_west = {
    visible: true,
    pixel_x: 21,
    pixel_y: 4,
    rotation: 0,
    scale: 1,
    priority: 3,
  };
  const data = {
    allowed: true,
    moving: false,
    model: 'test',
    models: [],
    body: null,
    body_width: 64,
    body_height: 32,
    body_scale: 1,
    wide: true,
    pose: 'rest',
    poses: ['idle', 'rest', 'sit'],
    direction: 8,
    arousal: 'partial',
    store,
    layers: [
      {
        slot: 'penis' as const,
        icon: '',
        x: -5,
        y: 7,
        rotation: 0,
        scale: 1,
        priority: 8,
        mirror_x: -1,
      },
    ],
  };
  const actions: Record<string, any>[] = [];
  const view = render(
    <CyborgCharacterEditor
      data={data}
      name="Test"
      values={{}}
      renderPreference={() => null}
      onName={() => {}}
      onPreview={() => {}}
      onLayout={(action) => actions.push(action)}
    />,
  );
  fireEvent.click(screen.getByText('Place parts'));
  fireEvent.click(screen.getByText('1:1'));
  const stage = view.container.querySelector(
    '.CyborgPreview__stage',
  ) as HTMLElement;
  stage.setPointerCapture = () => {};
  const dragPart = (x: number, y: number) => {
    fireEvent.pointerDown(view.container.querySelector('[data-part]')!, {
      clientX: 0,
      clientY: 0,
      pointerId: 1,
      button: 0,
    });
    fireEvent.pointerUp(stage, { clientX: x, clientY: y, pointerId: 1 });
  };
  dragPart(1, 0);
  expect(actions[0]).toMatchObject({
    operation: 'set_placement',
    target: { scope: 'pose', direction: 8, pose: 'rest' },
    changes: { pixel_x: 6, pixel_y: 7 },
  });
  expect(actions[0].value).toBeUndefined();
  expect(
    (
      screen.getByLabelText(
        'Override: Horizontal position exact value',
      ) as HTMLInputElement
    ).value,
  ).toBe('5');
  fireEvent.click(screen.getByText('This arousal'));
  dragPart(0, -1);
  expect(actions[1]).toMatchObject({
    target: { scope: 'arousal', arousal: 'partial' },
    changes: { pixel_y: 8 },
  });
  fireEvent.click(screen.getByText('Shared placement'));
  dragPart(1, 0);
  expect(actions[2]).toMatchObject({
    operation: 'set_placement',
    target: { scope: 'base', direction: 8 },
    changes: { pixel_x: 9 },
  });
});

it('freezes authored idle animation while parts are being placed', async () => {
  const data = {
    allowed: true,
    moving: false,
    model: 'test',
    models: [],
    body: 'body',
    body_width: 32,
    body_height: 32,
    body_scale: 1,
    pose: 'idle',
    poses: ['idle'],
    direction: 2,
    arousal: 'none',
    store: layoutStore(),
    animation: [
      { body: 'first', x: 0, y: 0, delay: 15 },
      { body: 'second', x: 2, y: 1, delay: 15 },
    ],
  };
  render(<CyborgPreview data={data} onLayout={() => {}} />);
  fireEvent.click(screen.getByText('Place parts'));
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 20));
  });
  expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toBe(
    'data:image/png;base64,first',
  );
});

it('describes the actual placement scope and missing sprites, and restores camera mode when editing is disabled', () => {
  const data = {
    allowed: true,
    moving: false,
    model: 'test',
    models: [],
    body: null,
    body_width: 64,
    body_height: 32,
    body_scale: 1,
    wide: true,
    pose: 'idle',
    poses: ['idle'],
    direction: 2,
    arousal: 'none',
    store: layoutStore(),
    layers: [],
  };
  const props = { slot: 'breasts' as const, onLayout: () => {} };
  const view = render(<CyborgPreview data={data} {...props} />);
  fireEvent.click(screen.getByText('Place parts'));
  expect(
    screen.getByText('Placement applies to South only · Scroll to zoom'),
  ).toBeTruthy();
  expect(
    screen.getByText(
      'No visible sprite for Breasts in this view. Check its sprite and visibility settings.',
    ),
  ).toBeTruthy();
  view.rerender(<CyborgPreview data={{ ...data, direction: 4 }} {...props} />);
  expect(
    screen.getByText('Placement applies to East / West only · Scroll to zoom'),
  ).toBeTruthy();
  view.rerender(<CyborgPreview data={{ ...data, direction: 1 }} {...props} />);
  expect(
    screen.getByText('Placement applies to North only · Scroll to zoom'),
  ).toBeTruthy();
  view.rerender(<CyborgPreview data={{ ...data, wide: false }} {...props} />);
  expect(
    screen.getByText('Placement applies to all views · Scroll to zoom'),
  ).toBeTruthy();
  view.rerender(
    <CyborgPreview data={{ ...data, allowed: false }} {...props} />,
  );
  expect(screen.getByText('Drag to pan · Scroll to zoom')).toBeTruthy();
});

it('keeps world zoom and framing when rotating or changing sprite bounds', () => {
  const data = {
    allowed: true,
    moving: false,
    model: 'test',
    models: [],
    body: null,
    body_width: 64,
    body_height: 32,
    body_scale: 1.6,
    pose: 'idle',
    poses: ['idle'],
    direction: 2,
    arousal: 'none',
    store: layoutStore(),
    layers: [],
  };
  const view = render(<CyborgPreview data={data} />);
  fireEvent.click(screen.getByText('1:1'));
  const camera = () =>
    (view.container.querySelector('.CyborgPreview__stage > div') as HTMLElement)
      .style.transform;
  expect(camera()).toContain('scale(1.6)');
  const before = camera();
  view.rerender(
    <CyborgPreview
      data={{ ...data, direction: 8, body_width: 128, pose: 'rest' }}
    />,
  );
  expect(camera()).toBe(before);
});

it('matches the map display scale in 1:1 without changing body size or placement', async () => {
  const originalWinget = Byond.winget;
  const calls: unknown[][] = [];
  Byond.winget = (async (...args: unknown[]) => {
    calls.push(args);
    return '1440x1440';
  }) as typeof Byond.winget;
  try {
    const data = {
      allowed: true,
      moving: false,
      model: 'test',
      models: [],
      body: null,
      body_width: 64,
      body_height: 32,
      body_scale: 0.75,
      pose: 'idle',
      poses: ['idle'],
      direction: 2,
      arousal: 'none',
      store: layoutStore(),
      layers: [],
      map_view: [15, 15],
    };
    const view = render(<CyborgPreview data={data} />);
    await act(async () => fireEvent.click(screen.getByText('1:1')));
    expect(calls).toEqual([['map_screen.map', 'view-size']]);
    expect(
      (
        view.container.querySelector(
          '.CyborgPreview__stage > div',
        ) as HTMLElement
      ).style.transform,
    ).toContain('scale(2.25)');
    expect(data.store.active.penis.pixel_y).toBe(0);
  } finally {
    Byond.winget = originalWinget;
  }
});

it('does not let a delayed map measurement overwrite a newer camera choice', async () => {
  const originalWinget = Byond.winget;
  let respond: (size: string) => void = () => {};
  Byond.winget = (() =>
    new Promise<string>((resolve) => {
      respond = resolve;
    })) as unknown as typeof Byond.winget;
  try {
    const data = {
      allowed: true,
      moving: false,
      model: 'test',
      models: [],
      body: null,
      body_width: 64,
      body_height: 32,
      body_scale: 1,
      pose: 'idle',
      poses: ['idle'],
      direction: 2,
      arousal: 'none',
      store: layoutStore(),
      layers: [],
      map_view: [15, 15],
    };
    const view = render(<CyborgPreview data={data} />);
    fireEvent.click(screen.getByText('1:1'));
    fireEvent.click(screen.getByText('Fit'));
    const camera = () =>
      (
        view.container.querySelector(
          '.CyborgPreview__stage > div',
        ) as HTMLElement
      ).style.transform;
    const before = camera();
    await act(async () => respond('1440x1440'));
    expect(camera()).toBe(before);
  } finally {
    Byond.winget = originalWinget;
  }
});

it('keeps the authored layer order while a part is selected for placement', () => {
  const view = render(
    <PreviewPart
      layer={{
        slot: 'penis',
        icon: '',
        x: 0,
        y: 0,
        rotation: 0,
        scale: 1,
        priority: 2,
      }}
      x={0}
      y={0}
      placing
      selected
      onNudge={() => {}}
    />,
  );
  expect(
    (view.container.querySelector('[data-part]') as HTMLElement).style.zIndex,
  ).toBe('2');
});

const pause = (ms: number) =>
  act(() => new Promise<void>((resolve) => setTimeout(resolve, ms)));

it('keeps slow slider changes local until a pause or release', async () => {
  const changes: number[] = [];
  render(
    <AdjustmentSlider
      label="Offset"
      value={0}
      min={-128}
      max={128}
      onChange={(value) => changes.push(value)}
    />,
  );
  const slider = screen.getByRole('slider', { name: 'Offset' });
  fireEvent.pointerDown(slider);
  for (const value of [1, 2, 3, 4]) {
    fireEvent.change(slider, { target: { value: String(value) } });
    await pause(120);
  }
  expect(changes).toEqual([]);
  expect((slider as HTMLInputElement).value).toBe('4');
  fireEvent.pointerUp(slider);
  expect(changes).toEqual([4]);
  await pause(400);
  expect(changes).toEqual([4]);
});

it('coalesces palette changes across channels and preserves the final colors on unmount', async () => {
  const actions: Record<string, unknown>[] = [];
  const view = render(
    <LayoutControls
      store={layoutStore()}
      part={{ sizes: [], color_channels: [1, 2] }}
      onAction={(action) => actions.push(action)}
    />,
  );
  for (const value of ['#112233', '#223344', '#334455']) {
    fireEvent.change(screen.getByLabelText('Color channel 1'), {
      target: { value },
    });
    await pause(120);
  }
  fireEvent.change(screen.getByLabelText('Color channel 2'), {
    target: { value: '#abcdef' },
  });
  expect(actions).toEqual([]);
  await pause(400);
  expect(actions).toHaveLength(1);
  expect(actions[0].value).toEqual(['#334455', '#abcdef', '#ffffff']);
  fireEvent.change(screen.getByLabelText('Color channel 1'), {
    target: { value: '#556677' },
  });
  view.unmount();
  expect(actions.at(-1)).toMatchObject({
    slot: 'penis',
    field: 'colors',
    value: ['#556677', '#abcdef', '#ffffff'],
  });
});

it('rounds exact pixel positions to whole numbers in base and override controls', () => {
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      store={layoutStore()}
      onAction={(action) => actions.push(action)}
    />,
  );
  const horizontal = screen.getByLabelText('Horizontal position exact value');
  fireEvent.change(horizontal, { target: { value: '-15.6' } });
  fireEvent.blur(horizontal);
  expect(actions.at(-1)).toMatchObject({
    operation: 'set_placement',
    changes: { pixel_x: -16 },
  });
  fireEvent.click(screen.getByText('This pose'));
  const vertical = screen.getByLabelText(
    'Override: Vertical position exact value',
  );
  fireEvent.change(vertical, { target: { value: '15.6' } });
  fireEvent.blur(vertical);
  expect(actions.at(-1)).toMatchObject({
    operation: 'set_placement',
    target: { scope: 'pose', pose: 'idle', direction: 'south' },
    changes: { pixel_y: 16 },
  });
});

function layoutStore(): LayoutStore {
  return {
    schema_version: 1,
    active: Object.fromEntries(
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
    ) as LayoutStore['active'],
    presets: {},
    model_defaults: {},
  };
}

it('separates authored sprite sizes from a 200 percent maximum scale and filters color channels', () => {
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      store={layoutStore()}
      part={{
        sizes: [
          { value: 1, label: 'Small' },
          { value: 2, label: 'Medium' },
        ],
        color_channels: [2],
      }}
      onAction={(action) => actions.push(action)}
    />,
  );
  expect(
    screen.getByRole('slider', { name: 'Part scale' }).getAttribute('max'),
  ).toBe('200');
  fireEvent.click(screen.getByLabelText('Smaller part size'));
  expect(actions.at(-1)).toMatchObject({
    operation: 'set',
    field: 'sprite_size',
    value: 1,
  });
  expect(screen.queryByLabelText('Color channel 1')).toBeNull();
  expect(screen.getByLabelText('Color channel 2')).toBeTruthy();
  expect(screen.queryByLabelText('Color channel 3')).toBeNull();
});

it.each([
  'placement',
  'colors',
  'overrides',
])('confirms reset %s independently', (kind) => {
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      store={layoutStore()}
      onAction={(action) => actions.push(action)}
    />,
  );
  fireEvent.click(screen.getByText(`Reset ${kind}`));
  expect(actions).toEqual([]);
  fireEvent.click(screen.getByText('Confirm?'));
  expect(actions).toEqual([
    {
      operation: `reset_${kind === 'placement' ? 'position' : kind}`,
      slot: 'penis',
    },
  ]);
});

it('drags parts in world pixels and sends one atomic placement, while camera panning never edits', () => {
  const actions: Record<string, unknown>[] = [];
  const data = {
    allowed: true,
    moving: false,
    model: 'test',
    models: [],
    body: null,
    body_width: 64,
    body_height: 32,
    body_scale: 1,
    pose: 'idle',
    poses: ['idle'],
    direction: 2,
    arousal: 'none',
    store: layoutStore(),
    layers: [
      {
        slot: 'penis' as const,
        icon: '',
        x: 0,
        y: 0,
        rotation: 0,
        scale: 1,
        priority: 5,
      },
    ],
  };
  const view = render(
    <CyborgPreview
      data={data}
      slot="penis"
      onLayout={(action) => actions.push(action)}
    />,
  );
  const stage = view.container.querySelector(
    '.CyborgPreview__stage',
  ) as HTMLElement;
  stage.setPointerCapture = () => {};
  fireEvent.click(screen.getByText('1:1'));
  const cameraDown = new PointerEvent('pointerdown', {
    bubbles: true,
    cancelable: true,
    button: 0,
    clientX: 20,
    clientY: 20,
    pointerId: 1,
  });
  fireEvent(screen.getByAltText('Penis preview'), cameraDown);
  expect(cameraDown.defaultPrevented).toBe(true);
  expect(document.activeElement === stage).toBe(true);
  fireEvent.pointerUp(stage, { clientX: 30, clientY: 10, pointerId: 1 });
  expect(actions).toEqual([]);
  fireEvent.click(screen.getByText('Place parts'));
  fireEvent.pointerDown(screen.getByAltText('Penis preview'), {
    button: 0,
    clientX: 20,
    clientY: 20,
    pointerId: 2,
  });
  fireEvent.pointerMove(stage, { clientX: 35, clientY: 5, pointerId: 2 });
  expect(actions).toEqual([]);
  fireEvent.pointerUp(stage, { clientX: 35, clientY: 5, pointerId: 2 });
  expect(actions).toMatchObject([
    {
      operation: 'set_placement',
      slot: 'penis',
      changes: { pixel_x: 15, pixel_y: 15 },
    },
  ]);
  fireEvent.pointerDown(screen.getByAltText('Penis preview'), {
    button: 0,
    clientX: 20,
    clientY: 20,
    pointerId: 3,
  });
  view.rerender(
    <CyborgPreview
      data={{ ...data, context: 2, model: 'replacement' }}
      slot="penis"
      onLayout={(action) => actions.push(action)}
    />,
  );
  fireEvent.pointerUp(stage, { clientX: 60, clientY: 50, pointerId: 3 });
  expect(actions).toHaveLength(1);
});

it('offers bounded placement sliders and sends the final numeric offset', () => {
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      store={layoutStore()}
      onAction={(action) => actions.push(action)}
    />,
  );
  const vertical = screen.getByRole('slider', { name: 'Vertical position' });
  expect(vertical.getAttribute('min')).toBe('-128');
  expect(vertical.getAttribute('max')).toBe('128');
  fireEvent.change(vertical, { target: { value: '15' } });
  fireEvent.pointerUp(vertical);
  expect(actions.at(-1)).toMatchObject({
    operation: 'set_placement',
    slot: 'penis',
    changes: { pixel_y: 15 },
  });
});

it('does not delete a named preset on the first click', () => {
  const store = layoutStore();
  store.presets.Example = store.active;
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      store={store}
      onAction={(action) => actions.push(action)}
    />,
  );
  fireEvent.click(screen.getByText('Presets'));
  fireEvent.change(screen.getByPlaceholderText('Preset name'), {
    target: { value: 'Example' },
  });
  fireEvent.click(screen.getByText('Delete preset'));
  expect(actions).toEqual([]);
});

it('requires a fresh confirmation after changing the targeted preset', () => {
  const store = layoutStore();
  store.presets.First = store.active;
  store.presets.Second = store.active;
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      store={store}
      onAction={(action) => actions.push(action)}
    />,
  );
  fireEvent.click(screen.getByText('Presets'));
  fireEvent.change(screen.getByPlaceholderText('Preset name'), {
    target: { value: 'First' },
  });
  fireEvent.click(screen.getByText('Delete preset'));
  fireEvent.change(screen.getByPlaceholderText('Preset name'), {
    target: { value: 'Second' },
  });
  fireEvent.click(screen.getByText('Delete preset'));
  expect(actions).toEqual([]);
});

it('accepts signed fractional exact input and clamps out-of-range values', () => {
  const changes: number[] = [];
  render(
    <AdjustmentSlider
      label="Offset"
      value={0}
      min={-128}
      max={128}
      onChange={(value) => changes.push(value)}
    />,
  );
  const input = screen.getByLabelText('Offset exact value');
  fireEvent.focus(input);
  fireEvent.change(input, { target: { value: '-15.25' } });
  expect(changes).toEqual([]);
  fireEvent.blur(input);
  expect(changes).toEqual([-15.25]);
  fireEvent.change(input, { target: { value: '999' } });
  fireEvent.blur(input);
  expect(changes.at(-1)).toBe(128);
});

it('flushes the last slider change before unmounting its editing context', () => {
  const changes: number[] = [];
  const view = render(
    <AdjustmentSlider
      label="Offset"
      value={0}
      min={-128}
      max={128}
      onChange={(value) => changes.push(value)}
    />,
  );
  fireEvent.change(screen.getByRole('slider', { name: 'Offset' }), {
    target: { value: '15' },
  });
  view.unmount();
  expect(changes).toEqual([15]);
});

it('edits the selected part and disables placement while inspecting a model default', () => {
  const store = layoutStore();
  store.model_defaults.example = structuredClone(store.active);
  const actions: Record<string, unknown>[] = [];
  const data = {
    allowed: true,
    moving: false,
    model: 'example',
    models: [{ id: 'example', department: 'Service', skin: 'Wide chassis' }],
    poses: ['idle'],
    pose: 'idle',
    direction: 2,
    arousal: 'full',
    body: null,
    body_width: 64,
    body_height: 32,
    body_scale: 1,
    store,
    layout_source: 'active' as const,
    model_default_available: true,
  };
  const props = {
    data,
    name: 'Example',
    values: { cyborg_size: 1 },
    renderPreference: (key: string) => <span>{key}</span>,
    onName: () => {},
    onPreview: () => {},
    onLayout: (action: Record<string, unknown>) => actions.push(action),
  };
  const view = render(<CyborgCharacterEditor {...props} />);
  fireEvent.click(screen.getByText('Sheath', { exact: true }));
  fireEvent.click(screen.getByText('Shared placement'));
  expect(screen.getByText('silicon_sheath_sprite')).toBeTruthy();
  fireEvent.change(screen.getByRole('slider', { name: 'Vertical position' }), {
    target: { value: '15' },
  });
  fireEvent.pointerUp(
    screen.getByRole('slider', { name: 'Vertical position' }),
  );
  expect(actions.at(-1)?.slot).toBe('sheath');
  view.rerender(
    <CyborgCharacterEditor
      {...props}
      data={{ ...data, layout_source: 'model_default' }}
    />,
  );
  expect(
    (
      screen.getByRole('slider', {
        name: 'Vertical position',
      }) as HTMLInputElement
    ).disabled,
  ).toBe(true);
});

it('applies an arousal override to the state visible in the preview', () => {
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      store={layoutStore()}
      onAction={(action) => actions.push(action)}
      preview={{
        direction: 'east',
        pose: 'sit',
        poses: ['idle', 'sit'],
        arousal: 'full',
        onChange: () => {},
      }}
    />,
  );
  fireEvent.click(screen.getByText('This pose', { exact: true }));
  fireEvent.click(screen.getByText('This arousal'));
  fireEvent.change(
    screen.getByRole('slider', { name: 'Override: Vertical position' }),
    { target: { value: '15' } },
  );
  fireEvent.pointerUp(
    screen.getByRole('slider', { name: 'Override: Vertical position' }),
  );
  expect(actions.at(-1)).toMatchObject({
    operation: 'set_placement',
    target: {
      scope: 'arousal',
      pose: 'sit',
      direction: 'east',
      arousal: 'full',
    },
    changes: { pixel_y: 15 },
  });
});

it('shows the named spawn assignment and keeps it separate from loading a preset', () => {
  const store = {
    ...layoutStore(),
    preset_models: { Workshop: 'drake' },
    model_presets: { drake: 'Workshop' },
  };
  store.presets.Workshop = store.active;
  const actions: Record<string, unknown>[] = [];
  render(
    <PresetControls
      embedded
      store={store}
      model="drake"
      onAction={(action) => actions.push(action)}
    />,
  );
  expect(screen.getByText('On spawn: Workshop')).toBeTruthy();
  fireEvent.change(screen.getByPlaceholderText('Preset name'), {
    target: { value: 'Workshop' },
  });
  fireEvent.click(screen.getByText('Use on spawn'));
  expect(actions).toEqual([]);
  fireEvent.click(screen.getByText('Confirm?'));
  expect(actions).toEqual([{ operation: 'assign_default', name: 'Workshop' }]);
});
