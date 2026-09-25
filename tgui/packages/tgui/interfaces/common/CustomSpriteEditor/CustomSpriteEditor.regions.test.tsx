// THIS IS AN APHELION UI FILE
import { expect, it, spyOn } from 'bun:test';
import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  compactSprite,
  fixture,
  fixtureFrames,
  painted,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { currentToolAtom, dirAtom, tools } from '../SpriteEditor/atoms';
import { Dir } from '../SpriteEditor/Types/types';
import { CustomSpriteEditor } from './index';
import type { CustomSpriteEditorData } from './types';

setupEditorTests();

const regionRows = () => {
  const row = (chars: string) => chars.padEnd(32, '0');
  return [row('1122'), ...Array.from({ length: 31 }, () => row(''))];
};

const regionFixture = (): CustomSpriteEditorData => {
  const rows = regionRows();
  // The server sends the paintable mask as "1"/"0" rows: every owned pixel.
  const mask = rows.map((row) => row.replace(/[1-9]/g, '1'));
  return {
    ...fixture(),
    maxBaseMarkings: 3,
    drawMask: { 1: mask, 2: mask, 4: mask, 8: mask },
    regions: { 1: rows, 2: rows, 4: rows, 8: rows },
    regionZones: ['chest', 'l_arm'],
    regionLabels: { chest: 'Torso', l_arm: 'Left arm' },
    selectedZone: 'chest',
    focusRevision: 1,
    regionMarkings: {
      chest: [],
      l_arm: [{ index: 1, name: 'Tiger Stripe', color: '#112233' }],
    },
    regionMarkingChoices: {
      chest: ['Belly'],
      l_arm: ['Tiger Stripe', 'Spots'],
    },
    regionEmissive: {
      chest: { 1: false, 2: false, 4: false, 8: false },
      l_arm: { 1: false, 2: true, 4: false, 8: false },
    },
  };
};

const renderRegions = (data = regionFixture()) => {
  backendStore.set(gameDataAtom, data);
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="markings" />
    </Provider>
  );
  const view = render(editor());
  return { store, view, editor };
};

it.each([
  0, 1, 3, 4,
])('selects the region under the press with tool %i, and keeps it over unavailable pixels', (toolIndex) => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const { store, view } = renderRegions();
    act(() =>
      store.set(currentToolAtom, tools[toolIndex], {
        setPreviewLayer: () => {},
        setPreviewData: () => {},
      }),
    );
    const canvas = view.container.querySelector('canvas')!;
    send.mockClear();
    fireEvent.mouseDown(canvas, { clientX: 25, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 25, clientY: 5, button: 0 });
    expect(send).toHaveBeenCalledWith('selectRegion', { zone: 'l_arm' });
    expect(screen.getByText('Left arm base markings')).toBeTruthy();
    expect(screen.getByText('Clear left arm')).toBeTruthy();
    expect(screen.getByText('Emissives - (Left arm, Front)')).toBeTruthy();
    send.mockClear();
    fireEvent.mouseDown(canvas, { clientX: 105, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 105, clientY: 5, button: 0 });
    expect(send).not.toHaveBeenCalledWith('selectRegion', expect.anything());
    expect(screen.getByText('Left arm base markings')).toBeTruthy();
  } finally {
    getBounds.mockRestore();
  }
});

it('selects on Alt-click sampling too', () => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const { view } = renderRegions();
    const canvas = view.container.querySelector('canvas')!;
    fireEvent.mouseDown(canvas, {
      clientX: 25,
      clientY: 5,
      button: 0,
      altKey: true,
    });
    expect(send).toHaveBeenCalledWith('selectRegion', { zone: 'l_arm' });
  } finally {
    getBounds.mockRestore();
  }
});

it('sends the selected region with clear, emissive and base marking actions', () => {
  renderRegions({ ...regionFixture(), selectedZone: 'l_arm' });
  fireEvent.click(screen.getByText('Clear left arm'));
  expect(send).toHaveBeenLastCalledWith('clear', { dir: '2', zone: 'l_arm' });
  fireEvent.click(screen.getByText('Emissives - (Left arm, Front)'));
  expect(send).toHaveBeenLastCalledWith('setEmissive', {
    zone: 'l_arm',
    dir: '2',
    enabled: false,
  });
  const section = screen
    .getByText('Left arm base markings')
    .closest('.Section')! as HTMLElement;
  const add = within(section).getByText('+').closest('.Button')!;
  // Under the rows and green, as in character setup's markings list.
  expect(add).toBe([...section.querySelectorAll('.Button')].at(-1)!);
  expect(add.classList.contains('Button--color--good')).toBe(true);
  fireEvent.click(add);
  expect(send).toHaveBeenLastCalledWith('addBaseMarking', { zone: 'l_arm' });
  expect(screen.queryByText(/Click the body to choose a region/)).toBeNull();
});

it('leaves out the base markings section for a region that has none', () => {
  renderRegions({
    ...regionFixture(),
    regionZones: ['chest', 'taur'],
    regionLabels: { chest: 'Torso', taur: 'Taur lower body' },
    selectedZone: 'taur',
  });
  expect(screen.queryByText('Taur lower body base markings')).toBeNull();
  expect(screen.queryByText(/has no base markings/)).toBeNull();
});

it('follows the focus revision when character setup moves the selection', () => {
  const { view, editor } = renderRegions();
  expect(screen.getByText('Torso base markings')).toBeTruthy();
  backendStore.set(gameDataAtom, {
    ...regionFixture(),
    selectedZone: 'l_arm',
    focusRevision: 2,
  });
  view.rerender(editor());
  expect(screen.getByText('Left arm base markings')).toBeTruthy();
});

it('tags the selected region and keeps a selection that has no pixels in this view', () => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const empty = Array.from({ length: 32 }, () => '0'.repeat(32));
    const data = regionFixture();
    data.regions = { ...data.regions!, 4: empty };
    data.drawMask = { ...data.drawMask!, 4: empty };
    const { store, view, editor } = renderRegions(data);
    expect(screen.getByText('TORSO')).toBeTruthy();
    act(() => store.set(dirAtom, Dir.EAST));
    view.rerender(editor());
    expect(screen.queryByText('TORSO')).toBeNull();
    expect(screen.getByText('(not in this view)')).toBeTruthy();
  } finally {
    getBounds.mockRestore();
  }
});

it('shades unavailable pixels with scanlines', () => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    renderRegions();
    expect(painted).toContain('rgba(10, 12, 14, 0.62)');
    expect(painted).toContain('rgba(255, 255, 255, 0.07)');
    expect(painted).not.toContain('rgba(50, 50, 50, 0.75)');
  } finally {
    getBounds.mockRestore();
  }
});

it('selects regions with the primary button only', () => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const { view } = renderRegions();
    const canvas = view.container.querySelector('canvas')!;
    send.mockClear();
    fireEvent.mouseDown(canvas, { clientX: 25, clientY: 5, button: 2 });
    fireEvent.mouseUp(window, { clientX: 25, clientY: 5, button: 2 });
    expect(send).not.toHaveBeenCalledWith('selectRegion', expect.anything());
    expect(screen.getByText('Torso base markings')).toBeTruthy();
  } finally {
    getBounds.mockRestore();
  }
});

it('keeps the selection off locked regions and explains a locked selection', () => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const lockedRegions = { l_arm: "Leia's left arm is covered." };
    const { view, editor } = renderRegions({
      ...regionFixture(),
      lockedRegions,
    });
    const canvas = view.container.querySelector('canvas')!;
    send.mockClear();
    fireEvent.mouseDown(canvas, { clientX: 25, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 25, clientY: 5, button: 0 });
    expect(send).not.toHaveBeenCalledWith('selectRegion', expect.anything());
    expect(screen.getByText('Torso base markings')).toBeTruthy();
    // The server's selection can lock after it was made, when clothing goes on.
    backendStore.set(gameDataAtom, {
      ...regionFixture(),
      lockedRegions,
      selectedZone: 'l_arm',
      focusRevision: 2,
    });
    view.rerender(editor());
    expect(screen.getByText("Leia's left arm is covered.")).toBeTruthy();
    const disabled = (button?: Element | null) =>
      !!button?.classList.contains('Button--disabled');
    expect(
      disabled(screen.getByText('Clear left arm').closest('.Button')),
    ).toBe(true);
    expect(
      disabled(
        screen.getByText('Emissives - (Left arm, Front)').closest('.Button'),
      ),
    ).toBe(true);
    const section = screen
      .getByText('Left arm base markings')
      .closest('.Section')! as HTMLElement;
    expect(disabled(within(section).getByText('+').closest('.Button'))).toBe(
      true,
    );
    expect(
      disabled(section.querySelector('.fa-trash')?.closest('.Button')),
    ).toBe(true);
    send.mockClear();
    fireEvent.click(screen.getByText('Clear left arm'));
    expect(send).not.toHaveBeenCalled();
  } finally {
    getBounds.mockRestore();
  }
});

it('outlines hovered regions, but not locked ones', () => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    for (const [lockedRegions, outlined] of [
      [undefined, true],
      [{ l_arm: 'Covered.' }, false],
    ] as const) {
      const { view } = renderRegions({ ...regionFixture(), lockedRegions });
      const box = view.container.querySelector('.CustomSpriteEditor__canvas')!;
      fireEvent.mouseMove(box, { clientX: 25, clientY: 5 });
      expect(painted.includes('rgba(255, 255, 255, 0.35)')).toBe(outlined);
      view.unmount();
    }
  } finally {
    getBounds.mockRestore();
  }
});

it('washes and hatches painted pixels that a part covers', () => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const data = regionFixture();
    const frames = fixtureFrames();
    frames[Dir.SOUTH][0][1] = '#00000000';
    data.editorData.sprite = compactSprite(32, 32, frames);
    const cover = [
      '11'.padEnd(32, '0'),
      ...Array.from({ length: 31 }, () => '0'.repeat(32)),
    ];
    data.coverMask = { 2: cover };
    const { view } = renderRegions(data);
    // The drawing canvas clears the shared paint log after the overlay draws, so hover a region to
    // redraw the overlay on its own. Two covered pixels, one of them transparent: exactly one wash.
    const canvas = view.container.querySelector('canvas')!;
    fireEvent.mouseMove(canvas, { clientX: 25, clientY: 5 });
    expect(
      painted.filter((fill) => fill === 'rgba(0, 0, 0, 0.45)'),
    ).toHaveLength(1);
    expect(painted).toContain('rgba(255, 255, 255, 0.55)');
  } finally {
    getBounds.mockRestore();
  }
});

it('names the selected region beside the view and drops the chip when nothing is selected', () => {
  const { view, editor } = renderRegions();
  const chip = screen.getByText('Torso').closest('.CustomSpriteEditor__region');
  expect(chip).toBeTruthy();
  expect(screen.queryByText(/Click the body to choose a region/)).toBeNull();
  backendStore.set(gameDataAtom, {
    ...regionFixture(),
    selectedZone: null,
    focusRevision: 2,
  });
  view.rerender(editor());
  expect(
    view.container.querySelector('.CustomSpriteEditor__region'),
  ).toBeNull();
  // With nothing selected, Clear says what to do instead of naming an empty region.
  const clear = screen.getByText('Clear region').closest('.Button')!;
  expect(clear.classList).toContain('Button--disabled');
});

it('shows the layering notice until it is dismissed for the account, and reopens it from the info button', () => {
  // The server sends 0 and 1, never JS booleans.
  const { view, editor } = renderRegions({
    ...regionFixture(),
    layerTipSeen: 0,
  });
  expect(
    screen.getByText(/Markings layer beneath mutant parts \(like snouts\)/),
  ).toBeTruthy();
  fireEvent.click(screen.getByText('Got it'));
  expect(send).toHaveBeenLastCalledWith('dismissLayerTip');
  backendStore.set(gameDataAtom, { ...regionFixture(), layerTipSeen: 1 });
  view.rerender(editor());
  expect(screen.queryByText(/Markings layer beneath mutant parts/)).toBeNull();
  // The info button brings the message back for keyboard and mouse users alike; closing it sends nothing.
  send.mockClear();
  fireEvent.click(screen.getByLabelText('How markings layer with parts'));
  expect(screen.getByText(/Markings layer beneath mutant parts/)).toBeTruthy();
  fireEvent.click(screen.getByText('Got it'));
  expect(screen.queryByText(/Markings layer beneath mutant parts/)).toBeNull();
  expect(send).not.toHaveBeenCalledWith('dismissLayerTip');
});
