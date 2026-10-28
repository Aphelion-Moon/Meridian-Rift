// THIS IS AN APHELION UI FILE
import { afterEach, expect, it, spyOn } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { useState } from 'react';
import { AdjustmentSlider } from './AdjustmentSlider';
import { CyborgCharacterEditor } from './CharacterEditor';
import { CyborgPreview } from './CyborgPreview';
import { EditorButton } from './controls';
import { LayoutControls } from './LayoutControls';
import { ModelPicker } from './ModelPicker';
import { PresetControls } from './PresetControls';
import { PreviewPart } from './PreviewPart';
import {
  CYBORG_SLOTS,
  type CyborgCustomizationData,
  type CyborgSlot,
  type LayoutStore,
} from './types';

afterEach(cleanup);

const baseControls = {
  slot: 'penis' as const,
  placementTarget: 'base' as const,
  onPlacementTarget: () => {},
  preview: { direction: 'south', pose: 'idle', arousal: 'none' },
};

it('closes the server gallery in the same request that changes model context', async () => {
  const actions: Record<string, unknown>[] = [];
  const view = render(
    <ModelPicker
      data={{
        allowed: true,
        moving: false,
        model: 'first',
        models: [
          { id: 'first', department: 'Service', skin: 'First chassis' },
          { id: 'second', department: 'Service', skin: 'Second chassis' },
        ],
        body: null,
        body_width: 32,
        body_height: 32,
        body_scale: 1,
        pose: 'idle',
        poses: ['idle'],
        direction: 2,
        arousal: 'none',
        store: layoutStore(),
      }}
      onPreview={(action) => actions.push(action)}
    />,
  );
  fireEvent.click(screen.getByLabelText('Choose preview model'));
  const model = await screen.findByText('Second chassis');
  expect(document.activeElement).toBe(
    screen.getByRole('searchbox', { name: 'Search skins' }),
  );
  fireEvent.click(model);
  view.unmount();
  expect(actions.find((action) => action.model === 'second')).toEqual({
    model: 'second',
    gallery_open: false,
  });
  expect(
    actions.filter((action) => action.gallery_open === false),
  ).toHaveLength(1);
});

it('does not send a gallery close when an unopened picker unmounts', () => {
  const actions: Record<string, unknown>[] = [];
  const view = render(
    <ModelPicker
      data={editablePreviewData()}
      onPreview={(action) => actions.push(action)}
    />,
  );
  view.unmount();
  expect(actions).toEqual([]);
});

it.each([
  true,
  false,
])('releases an open picker exactly once when explicitly closed: %s', (closeFirst) => {
  const actions: Record<string, unknown>[] = [];
  const view = render(
    <ModelPicker
      data={editablePreviewData()}
      onPreview={(action) => actions.push(action)}
    />,
  );
  fireEvent.click(screen.getByLabelText('Choose preview model'));
  if (closeFirst) fireEvent.click(screen.getByLabelText('Close model picker'));
  view.unmount();
  expect(
    actions.filter((action) => action.gallery_open === false),
  ).toHaveLength(1);
});

it('requests the current department when the catalog arrives after the picker opens', async () => {
  const actions: Record<string, unknown>[] = [];
  const data = editablePreviewData();
  const onPreview = (action: Record<string, unknown>) => actions.push(action);
  const view = render(<ModelPicker data={data} onPreview={onPreview} />);
  fireEvent.click(screen.getByLabelText('Choose preview model'));
  expect(actions).toEqual([{ gallery_open: true }]);
  const catalogData = {
    ...data,
    models: [{ id: 'test', department: 'Service', skin: 'Test chassis' }],
  };
  view.rerender(<ModelPicker data={catalogData} onPreview={onPreview} />);
  expect(actions).toEqual([
    { gallery_open: true },
    { gallery_open: true, gallery_department: 'Service' },
  ]);
  view.rerender(
    <ModelPicker data={{ ...catalogData }} onPreview={onPreview} />,
  );
  expect(actions).toHaveLength(2);
  await pause(5);
});

function editablePreviewData(): CyborgCustomizationData {
  return {
    allowed: true,
    moving: false,
    model: 'test',
    models: [],
    body: null,
    body_width: 32,
    body_height: 32,
    body_scale: 1,
    pose: 'idle',
    poses: ['idle', 'rest'],
    direction: 2,
    arousal: 'none',
    store: layoutStore(),
    layers: [
      {
        slot: 'penis',
        icon: '',
        x: 0,
        y: 0,
        rotation: 0,
        scale: 1,
        priority: 5,
      },
    ],
  };
}

it('reuses omitted frame images without dropping animation timing or offsets', async () => {
  const data: CyborgCustomizationData = {
    ...editablePreviewData(),
    body: 'first',
    occlusion: 'shared-mask',
    animation: [
      { x: 0, y: 0, delay: 10 },
      { body: 'second', x: 3, y: 2, delay: 60000 },
    ],
  };
  render(<CyborgPreview data={data} onLayout={() => {}} />);
  expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
    ',first',
  );
  expect(screen.getByAltText('Body occlusion').getAttribute('src')).toEndWith(
    ',shared-mask',
  );
  await pause(30);
  const body = screen.getByAltText('Cyborg preview');
  expect(body.getAttribute('src')).toEndWith(',second');
  expect((body.nextElementSibling as HTMLElement).style.left).toBe('3px');
  expect((body.nextElementSibling as HTMLElement).style.top).toBe('-2px');
  expect(screen.getByAltText('Body occlusion').getAttribute('src')).toEndWith(
    ',shared-mask',
  );
  fireEvent.click(screen.getByText('Place parts'));
  await pause(30);
  expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
    ',first',
  );
  expect(screen.getByAltText('Body occlusion').getAttribute('src')).toEndWith(
    ',shared-mask',
  );
});

it('catches up to the animation clock after a hidden page becomes visible', async () => {
  const hidden = Object.getOwnPropertyDescriptor(document, 'hidden');
  const now = spyOn(performance, 'now').mockReturnValue(0);
  Object.defineProperty(document, 'hidden', {
    configurable: true,
    value: true,
  });
  try {
    render(
      <CyborgPreview
        data={{
          ...editablePreviewData(),
          body: 'first',
          animation: [
            { delay: 10, x: 0, y: 0 },
            { body: 'second', delay: 20, x: 1, y: 0 },
            { body: 'third', delay: 60000, x: 2, y: 0 },
          ],
        }}
        onLayout={() => {}}
      />,
    );
    now.mockReturnValue(35);
    await pause(45);
    expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
      ',first',
    );
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
    act(() => document.dispatchEvent(new Event('visibilitychange')));
    expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
      ',third',
    );
  } finally {
    cleanup();
    now.mockRestore();
    if (hidden) Object.defineProperty(document, 'hidden', hidden);
    else Reflect.deleteProperty(document, 'hidden');
  }
});

it('keeps the animation clock when identical frame data is republished', () => {
  const hidden = Object.getOwnPropertyDescriptor(document, 'hidden');
  const now = spyOn(performance, 'now').mockReturnValue(0);
  Object.defineProperty(document, 'hidden', {
    configurable: true,
    value: false,
  });
  try {
    const data = {
      ...editablePreviewData(),
      body: 'first',
      animation: [
        { delay: 10, x: 0, y: 0 },
        { body: 'second', delay: 20, x: 1, y: 0 },
        { body: 'third', delay: 60000, x: 2, y: 0 },
      ],
    };
    const view = render(<CyborgPreview data={data} onLayout={() => {}} />);
    now.mockReturnValue(35);
    act(() => document.dispatchEvent(new Event('visibilitychange')));
    expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
      ',third',
    );
    view.rerender(
      <CyborgPreview
        data={{
          ...data,
          body_scale: 1.6,
          animation: data.animation.map((frame) => ({ ...frame })),
        }}
        onLayout={() => {}}
      />,
    );
    expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
      ',third',
    );
  } finally {
    cleanup();
    now.mockRestore();
    if (hidden) Object.defineProperty(document, 'hidden', hidden);
    else Reflect.deleteProperty(document, 'hidden');
  }
});

it.each([
  [1, 20, 20],
  [0.8, 16, 20],
  [2 / 3, 20, 30],
])('keeps part dragging and camera panning in the rendered coordinate space at CSS scale %s', (cssScale, pointerDelta, expectedOffset) => {
  const actions: Record<string, unknown>[] = [];
  const view = render(
    <CyborgPreview
      data={editablePreviewData()}
      onLayout={(action) => actions.push(action)}
    />,
  );
  const stage = view.container.querySelector(
    '.CyborgPreview__stage',
  ) as HTMLElement;
  // Happy DOM has no layout engine: supply only the measured DOM boundary.
  Object.defineProperty(stage, 'offsetWidth', { value: 300 });
  stage.getBoundingClientRect = () =>
    new DOMRect(0, 0, 300 * cssScale, 200 * cssScale);
  stage.setPointerCapture = () => {};
  fireEvent.click(screen.getByText('1:1'));
  fireEvent.pointerDown(stage, {
    button: 0,
    clientX: 100,
    clientY: 100,
    pointerId: 1,
  });
  fireEvent.pointerMove(stage, {
    clientX: 100 + pointerDelta,
    clientY: 100,
    pointerId: 1,
  });
  fireEvent.pointerUp(stage, {
    clientX: 100 + pointerDelta,
    clientY: 100,
    pointerId: 1,
  });
  expect((stage.firstElementChild as HTMLElement).style.transform).toContain(
    `translate(${expectedOffset}px, 0px)`,
  );
  expect(actions).toEqual([]);
  fireEvent.click(screen.getByText('Place parts'));
  fireEvent.pointerDown(screen.getByAltText('Penis preview'), {
    button: 0,
    clientX: 100,
    clientY: 100,
    pointerId: 2,
  });
  fireEvent.pointerUp(stage, {
    clientX: 100 + pointerDelta,
    clientY: 100 - pointerDelta,
    pointerId: 2,
  });
  expect(actions).toMatchObject([
    {
      operation: 'set_placement',
      changes: { pixel_x: expectedOffset, pixel_y: expectedOffset },
    },
  ]);
});

it('exposes keyboard-operated editor pages, placement scopes and named native choices', () => {
  const previews: Record<string, unknown>[] = [];
  render(
    <CyborgCharacterEditor
      data={editablePreviewData()}
      name="Keyboard character"
      values={{}}
      renderPreference={(key) => <textarea aria-label={key} />}
      onName={() => {}}
      onPreview={(action) => previews.push(action)}
      onLayout={() => {}}
    />,
  );
  expect(screen.getByRole('textbox', { name: 'Name' })).toBeTruthy();
  const profile = screen.getByRole('button', { name: 'Profile' });
  profile.focus();
  fireEvent.keyDown(profile, { key: 'Enter' });
  expect(screen.getByLabelText('ooc_notes_silicon')).toBeTruthy();
  expect(profile.getAttribute('aria-pressed')).toBe('true');
  fireEvent.keyDown(screen.getByRole('button', { name: 'Appearance' }), {
    key: ' ',
  });
  fireEvent.keyDown(screen.getByRole('button', { name: 'Shared placement' }), {
    key: 'Enter',
  });
  expect(
    screen.getByRole('slider', { name: 'Horizontal position' }),
  ).toBeTruthy();
  const pose = screen.getByRole('combobox', { name: 'Pose' });
  pose.focus();
  expect(document.activeElement).toBe(pose);
  fireEvent.change(pose, { target: { value: 'rest' } });
  expect(previews.at(-1)).toEqual({ pose: 'rest' });
  expect(screen.getByRole('combobox', { name: 'Arousal' })).toBeTruthy();
  expect(screen.getByRole('combobox', { name: 'Saved presets' })).toBeTruthy();
});

it('offers keyboard camera pan buttons without editing a part', () => {
  const actions: Record<string, unknown>[] = [];
  const view = render(
    <CyborgPreview
      data={editablePreviewData()}
      onLayout={(action) => actions.push(action)}
    />,
  );
  fireEvent.keyDown(screen.getByRole('button', { name: 'Pan camera right' }), {
    key: 'Enter',
  });
  expect(
    (view.container.querySelector('.CyborgPreview__stage > div') as HTMLElement)
      .style.transform,
  ).toContain('translate(32px, 0px)');
  expect(actions).toEqual([]);
});

it('preserves confirmation and disabled behavior when tooltip controls receive keyboard activation', () => {
  let calls = 0;
  render(
    <>
      <EditorButton.Confirm
        tooltip="Delete saved appearance"
        onClick={() => calls++}
      >
        Delete
      </EditorButton.Confirm>
      <EditorButton tooltip="Unavailable" disabled onClick={() => calls++}>
        Disabled
      </EditorButton>
    </>,
  );
  fireEvent.keyDown(screen.getByRole('button', { name: 'Delete' }), {
    key: 'Enter',
  });
  expect(calls).toBe(0);
  fireEvent.keyDown(screen.getByRole('button', { name: 'Confirm?' }), {
    key: ' ',
  });
  expect(calls).toBe(1);
  fireEvent.keyDown(screen.getByRole('button', { name: 'Disabled' }), {
    key: 'Enter',
  });
  expect(calls).toBe(1);
});

it('keeps a coherent rendered preview while newer resources are pending and cancels placement', () => {
  const actions: Record<string, unknown>[] = [];
  const data = { ...editablePreviewData(), body: 'old-body' };
  const view = render(
    <CyborgPreview data={data} onLayout={(action) => actions.push(action)} />,
  );
  fireEvent.click(screen.getByText('1:1'));
  fireEvent.click(screen.getByText('Place parts'));
  const stage = view.container.querySelector(
    '.CyborgPreview__stage',
  ) as HTMLElement;
  stage.setPointerCapture = () => {};
  fireEvent.pointerDown(screen.getByAltText('Penis preview'), {
    button: 0,
    clientX: 0,
    clientY: 0,
    pointerId: 1,
  });
  const pending = {
    ...data,
    direction: 4,
    body_scale: 2,
    layers: data.layers?.map((layer) => ({ ...layer, x: 90 })),
    resources_pending: true,
    rendered_preview: {
      model: data.model,
      direction: 2,
      pose: data.pose,
      arousal: data.arousal,
      moving: false,
      body_scale: 1,
      layers: data.layers,
    },
  };
  view.rerender(
    <CyborgPreview
      data={pending}
      onLayout={(action) => actions.push(action)}
    />,
  );
  expect(screen.getByRole('status').textContent).toBe('Updating preview…');
  expect(
    screen.getByRole('button', { name: 'East' }).getAttribute('aria-pressed'),
  ).toBe('true');
  expect((stage.firstElementChild as HTMLElement).style.transform).toContain(
    'scale(1)',
  );
  expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
    ',old-body',
  );
  expect(screen.getByAltText('Penis preview').parentElement?.style.left).toBe(
    '0px',
  );
  fireEvent.pointerUp(stage, { clientX: 20, clientY: 20, pointerId: 1 });
  fireEvent.pointerDown(screen.getByAltText('Penis preview'), {
    button: 0,
    clientX: 0,
    clientY: 0,
    pointerId: 2,
  });
  fireEvent.pointerUp(stage, { clientX: 20, clientY: 20, pointerId: 2 });
  expect(actions).toEqual([]);
  view.rerender(
    <CyborgPreview
      data={{
        ...pending,
        resources_pending: false,
        rendered_preview: undefined,
        body: 'new-body',
      }}
      onLayout={(action) => actions.push(action)}
    />,
  );
  expect(screen.queryByRole('status')).toBeNull();
  expect((stage.firstElementChild as HTMLElement).style.transform).toContain(
    'scale(2)',
  );
  expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
    ',new-body',
  );
});

it.each([
  false,
  true,
])('keeps a new-part drag through metadata-only refresh (delivered before release: %s)', (deliverBeforeRelease) => {
  const actions: Record<string, unknown>[] = [];
  const data = editablePreviewData();
  data.layers!.push({ ...data.layers![0], slot: 'sheath', x: 24 });
  data.store.active.sheath.pixel_x = 24;
  function MetadataRefresh() {
    const [slot, setSlot] = useState<CyborgSlot>('penis');
    const [pending, setPending] = useState(false);
    return (
      <>
        <button onClick={() => setPending(false)}>Deliver metadata</button>
        <CyborgPreview
          data={{ ...data, resources_pending: pending, preview_pending: false }}
          slot={slot}
          onSelectSlot={(next) => {
            setSlot(next);
            setPending(true);
          }}
          onLayout={(action) => actions.push(action)}
        />
      </>
    );
  }
  const view = render(<MetadataRefresh />);
  fireEvent.click(screen.getByText('1:1'));
  fireEvent.click(screen.getByText('Place parts'));
  const stage = view.container.querySelector(
    '.CyborgPreview__stage',
  ) as HTMLElement;
  stage.setPointerCapture = () => {};
  fireEvent.pointerDown(screen.getByAltText('Sheath preview'), {
    button: 0,
    clientX: 0,
    clientY: 0,
    pointerId: 1,
  });
  fireEvent.pointerMove(stage, { clientX: 15, clientY: -5, pointerId: 1 });
  if (deliverBeforeRelease)
    fireEvent.click(screen.getByText('Deliver metadata'));
  fireEvent.pointerUp(stage, { clientX: 15, clientY: -5, pointerId: 1 });
  expect(actions).toMatchObject([
    {
      operation: 'set_placement',
      slot: 'sheath',
      changes: { pixel_x: 39, pixel_y: 5 },
    },
  ]);
});

it('cancels a part drag when its pixel resources change without a context or pose change', () => {
  const actions: Record<string, unknown>[] = [];
  const data = editablePreviewData();
  const view = render(
    <CyborgPreview data={data} onLayout={(action) => actions.push(action)} />,
  );
  fireEvent.click(screen.getByText('1:1'));
  fireEvent.click(screen.getByText('Place parts'));
  const stage = view.container.querySelector(
    '.CyborgPreview__stage',
  ) as HTMLElement;
  stage.setPointerCapture = () => {};
  fireEvent.pointerDown(screen.getByAltText('Penis preview'), {
    button: 0,
    clientX: 0,
    clientY: 0,
    pointerId: 1,
  });
  const store = structuredClone(data.store);
  store.active.penis.colors[0] = '#112233';
  view.rerender(
    <CyborgPreview
      data={{ ...data, store, resources_pending: true, preview_pending: true }}
      onLayout={(action) => actions.push(action)}
    />,
  );
  fireEvent.pointerUp(stage, { clientX: 15, clientY: -5, pointerId: 1 });
  expect(actions).toEqual([]);
});

it('advances accepted part sizes while rendered size metadata is still stale', () => {
  const actions: unknown[] = [];
  function AcceptedSize() {
    const [store, setStore] = useState(() => {
      const value = layoutStore();
      value.active.penis.sprite_size = 2;
      return value;
    });
    return (
      <LayoutControls
        {...baseControls}
        store={store}
        part={{
          sizes: [2, 3, 4].map((value) => ({ value, label: String(value) })),
          color_channels: [],
        }}
        onAction={(action) => {
          actions.push(action.value);
          setStore((current) => ({
            ...current,
            active: {
              ...current.active,
              penis: {
                ...current.active.penis,
                sprite_size: Number(action.value),
              },
            },
          }));
        }}
      />
    );
  }
  render(<AcceptedSize />);
  fireEvent.click(screen.getByRole('button', { name: 'Larger part size' }));
  expect(
    (screen.getByRole('combobox', { name: 'Part size' }) as HTMLSelectElement)
      .value,
  ).toBe('3');
  fireEvent.click(screen.getByRole('button', { name: 'Larger part size' }));
  expect(actions).toEqual([3, 4]);
  fireEvent.change(screen.getByRole('combobox', { name: 'Part size' }), {
    target: { value: '3' },
  });
  expect(
    (screen.getByRole('combobox', { name: 'Part size' }) as HTMLSelectElement)
      .value,
  ).toBe('3');
});

it('falls back to the first authored size when the selected sprite cannot use the requested size', () => {
  const store = layoutStore();
  store.active.penis.sprite_size = 4;
  const view = render(
    <LayoutControls
      {...baseControls}
      store={store}
      part={{
        sizes: [2, 3, 4].map((value) => ({ value, label: String(value) })),
        color_channels: [],
      }}
      onAction={() => {}}
    />,
  );
  view.rerender(
    <LayoutControls
      {...baseControls}
      store={store}
      part={{
        sizes: [1, 5].map((value) => ({ value, label: String(value) })),
        color_channels: [],
      }}
      onAction={() => {}}
    />,
  );
  expect(
    (screen.getByRole('combobox', { name: 'Part size' }) as HTMLSelectElement)
      .value,
  ).toBe('1');
});

it('restores an invalid hex entry to the accepted color without sending a change', () => {
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      {...baseControls}
      store={layoutStore()}
      part={{ sizes: [], color_channels: [1] }}
      onAction={(action) => actions.push(action)}
    />,
  );
  const hex = screen.getAllByRole('textbox').at(-1) as HTMLInputElement;
  fireEvent.focus(hex);
  fireEvent.change(hex, { target: { value: '#zzzzzz' } });
  fireEvent.blur(hex);
  expect(hex.value).toBe('#ffffff');
  expect(actions).toEqual([]);
  expect(screen.getByRole('textbox', { name: 'Color channel 1 hex' })).toBe(
    hex,
  );
  fireEvent.change(hex, { target: { value: '#AABBCC' } });
  fireEvent.blur(hex);
  expect(actions.at(-1)).toMatchObject({
    field: 'colors',
    value: ['#AABBCC', '#ffffff', '#ffffff'],
  });
});

it('sends each held-key step independently of server replies, including mirrored west placement', () => {
  const canvas = spyOn(
    HTMLCanvasElement.prototype,
    'getContext',
  ).mockReturnValue({
    drawImage: () => {},
    getImageData: () => ({ data: new Uint8ClampedArray([0, 0, 0, 255]) }),
  } as unknown as CanvasRenderingContext2D);
  try {
    const actions: Record<string, unknown>[] = [];
    const data: CyborgCustomizationData = {
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
      direction: 8,
      arousal: 'none',
      store: layoutStore(),
      layers: [
        {
          slot: 'penis',
          icon: '',
          x: 0,
          y: 0,
          rotation: 0,
          scale: 1,
          priority: 5,
          mirror_x: -1,
        },
      ],
    };
    render(
      <CyborgPreview data={data} onLayout={(action) => actions.push(action)} />,
    );
    fireEvent.click(screen.getByText('Place parts'));
    const sprite = screen.getByAltText('Penis preview');
    Object.defineProperties(sprite, {
      naturalWidth: { value: 1 },
      naturalHeight: { value: 1 },
    });
    fireEvent.load(sprite);
    const handle = screen.getByRole('button', { name: 'Place Penis' });
    for (const key of ['ArrowRight', 'ArrowRight', 'ArrowUp'])
      fireEvent.keyDown(handle, { key });
    const final = actions.reduce<{ pixel_x: number; pixel_y: number }>(
      (position, action) => {
        const changes = action.changes as { pixel_x: number; pixel_y: number };
        return action.operation === 'nudge_placement'
          ? {
              pixel_x: position.pixel_x + changes.pixel_x,
              pixel_y: position.pixel_y + changes.pixel_y,
            }
          : changes;
      },
      { pixel_x: 0, pixel_y: 0 },
    );
    expect(final).toEqual({ pixel_x: -2, pixel_y: 1 });
    expect(actions.map((action) => action.operation)).toEqual([
      'nudge_placement',
      'nudge_placement',
      'nudge_placement',
    ]);
    expect(actions.map((action) => action.changes)).toEqual([
      { pixel_x: -1, pixel_y: 0 },
      { pixel_x: -1, pixel_y: 0 },
      { pixel_x: -0, pixel_y: 1 },
    ]);
    expect(data.store.active.penis.pixel_x).toBe(0);
  } finally {
    canvas.mockRestore();
  }
});

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
      {...baseControls}
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
  const props = {
    ...baseControls,
    store: layoutStore(),
    onAction: (action: Record<string, unknown>) => actions.push(action),
  };
  const view = render(<LayoutControls {...props} />);
  const horizontal = screen.getByLabelText('Horizontal position exact value');
  fireEvent.change(horizontal, { target: { value: '-15.6' } });
  fireEvent.blur(horizontal);
  expect(actions.at(-1)).toMatchObject({
    operation: 'set_placement',
    changes: { pixel_x: -16 },
  });
  view.rerender(<LayoutControls {...props} placementTarget="pose" />);
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
      {...baseControls}
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
      {...baseControls}
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

it('selects an unselected part while dragging and sends one atomic placement, while camera panning never edits', () => {
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
  function SelectablePreview({ data }: { data: CyborgCustomizationData }) {
    const [slot, setSlot] = useState<CyborgSlot>('sheath');
    return (
      <CyborgPreview
        data={data}
        slot={slot}
        onSelectSlot={setSlot}
        onLayout={(action) => actions.push(action)}
      />
    );
  }
  const view = render(<SelectablePreview data={data} />);
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
    <SelectablePreview data={{ ...data, context: 2, model: 'replacement' }} />,
  );
  fireEvent.pointerUp(stage, { clientX: 60, clientY: 50, pointerId: 3 });
  expect(actions).toHaveLength(1);
});

it('offers bounded placement sliders and sends the final numeric offset', () => {
  const actions: Record<string, unknown>[] = [];
  render(
    <LayoutControls
      {...baseControls}
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
    <PresetControls
      store={store}
      onAction={(action) => actions.push(action)}
    />,
  );
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
    <PresetControls
      store={store}
      onAction={(action) => actions.push(action)}
    />,
  );
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
      {...baseControls}
      placementTarget="arousal"
      store={layoutStore()}
      onAction={(action) => actions.push(action)}
      preview={{
        direction: 'east',
        pose: 'sit',
        arousal: 'full',
      }}
    />,
  );
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

it('keeps compact preset summaries loadable, assignable, and deletable', () => {
  const actions: Record<string, unknown>[] = [];
  render(
    <PresetControls
      store={{
        ...layoutStore(),
        presets: { Workshop: true },
        preset_models: { Workshop: 'drake' },
      }}
      model="drake"
      onAction={(action) => actions.push(action)}
    />,
  );
  fireEvent.change(screen.getByPlaceholderText('Preset name'), {
    target: { value: 'Workshop' },
  });
  for (const label of ['Load preset', 'Use on spawn', 'Delete preset']) {
    fireEvent.click(screen.getByText(label));
    fireEvent.click(screen.getByText('Confirm?'));
  }
  expect(actions).toEqual([
    { operation: 'load', name: 'Workshop' },
    { operation: 'assign_default', name: 'Workshop' },
    { operation: 'delete', name: 'Workshop' },
  ]);
});

it('keeps spawn controls usable when the unused default layout is omitted', () => {
  const actions: Record<string, unknown>[] = [];
  const view = render(
    <PresetControls
      store={layoutStore()}
      model="drake"
      modelDefaultAvailable
      onAction={(action) => actions.push(action)}
    />,
  );
  expect(screen.getByText('On spawn: Legacy saved appearance')).toBeTruthy();
  for (const label of ['Load spawn appearance', 'Clear assignment']) {
    fireEvent.click(screen.getByText(label));
    fireEvent.click(screen.getByText('Confirm?'));
  }
  expect(actions).toEqual([
    { operation: 'load_default' },
    { operation: 'delete_default' },
  ]);
  view.rerender(
    <PresetControls
      store={layoutStore()}
      model="drake"
      modelDefaultAvailable={false}
      onAction={(action) => actions.push(action)}
    />,
  );
  expect(screen.queryByText('Load spawn appearance')).toBeNull();
  expect(
    screen
      .getByRole('button', { name: 'Clear assignment' })
      .getAttribute('aria-disabled'),
  ).toBe('true');
  fireEvent.click(screen.getByText('Clear assignment'));
  expect(actions).toHaveLength(2);
});

it('does not render a native zero availability flag as spawn content', () => {
  render(
    <PresetControls
      store={layoutStore()}
      model="drake"
      modelDefaultAvailable={0}
      onAction={() => {}}
    />,
  );
  expect(screen.queryByText('0', { exact: true }) !== null).toBe(false);
  expect(screen.queryByText('Load spawn appearance')).toBeNull();
});

it('advances animated images and pauses at the first frame for placement', async () => {
  const data = {
    allowed: true,
    moving: false,
    model: 'test',
    models: [],
    body: 'first',
    body_width: 64,
    body_height: 32,
    body_scale: 1,
    pose: 'idle',
    poses: ['idle'],
    direction: 2,
    arousal: 'none',
    store: layoutStore(),
    animation: [
      { body: 'first', occlusion: 'mask-first', x: 0, y: 0, delay: 10 },
      { body: 'second', occlusion: 'mask-second', x: 3, y: 2, delay: 60000 },
    ],
  };
  render(<CyborgPreview data={data} onLayout={() => {}} />);
  await pause(30);
  expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
    ',second',
  );
  expect(screen.getByAltText('Body occlusion').getAttribute('src')).toEndWith(
    ',mask-second',
  );
  fireEvent.click(screen.getByText('Place parts'));
  await pause(30);
  expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
    ',first',
  );
  expect(screen.getByAltText('Body occlusion').getAttribute('src')).toEndWith(
    ',mask-first',
  );
  fireEvent.click(screen.getByText('Move camera'));
  await pause(30);
  expect(screen.getByAltText('Cyborg preview').getAttribute('src')).toEndWith(
    ',second',
  );
});

it.each([
  'model',
  'context',
  'permission',
] as const)('replaces pending slider and color drafts when the %s changes', async (changed) => {
  const actions: Record<string, unknown>[] = [];
  const data: CyborgCustomizationData = {
    allowed: true,
    moving: false,
    context: 1,
    model: 'first',
    models: [],
    body: null,
    body_width: 32,
    body_height: 32,
    body_scale: 1,
    pose: 'idle',
    poses: ['idle'],
    direction: 2,
    arousal: 'none',
    store: layoutStore(),
    parts: { penis: { sizes: [], color_channels: [1] } },
  };
  const editor = (data: CyborgCustomizationData) => (
    <CyborgCharacterEditor
      data={data}
      name="Test"
      values={{}}
      renderPreference={() => null}
      onName={() => {}}
      onPreview={() => {}}
      onLayout={(action) =>
        actions.push({ ...action, context: data.context, model: data.model })
      }
    />
  );
  const view = render(editor(data));
  fireEvent.click(screen.getByText('Shared placement'));
  fireEvent.change(
    screen.getByRole('slider', { name: 'Horizontal position' }),
    {
      target: { value: '99' },
    },
  );
  fireEvent.change(screen.getByLabelText('Color channel 1'), {
    target: { value: '#112233' },
  });
  const replacement = structuredClone(data);
  if (changed === 'context') replacement.context = 2;
  else if (changed === 'model') replacement.model = 'second';
  else replacement.allowed = false;
  if (changed !== 'permission') {
    replacement.store.active.penis.pixel_x = 4;
    replacement.store.active.penis.colors[0] = '#abcdef';
  }
  view.rerender(editor(replacement));
  expect(
    (
      screen.getByLabelText(
        'Horizontal position exact value',
      ) as HTMLInputElement
    ).value,
  ).toBe(String(replacement.store.active.penis.pixel_x));
  expect(
    (screen.getByLabelText('Color channel 1') as HTMLInputElement).value,
  ).toBe(replacement.store.active.penis.colors[0]);
  await pause(400);
  expect(actions).toHaveLength(2);
  expect(
    actions.every((action) => action.context === 1 && action.model === 'first'),
  ).toBe(true);
});
