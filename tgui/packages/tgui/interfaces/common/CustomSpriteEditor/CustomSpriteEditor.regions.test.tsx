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
import { currentToolAtom, tools } from '../SpriteEditor/atoms';
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
  fireEvent.click(within(section).getByText('+').closest('.Button')!);
  expect(send).toHaveBeenLastCalledWith('addBaseMarking', { zone: 'l_arm' });
  expect(screen.queryByText(/Click the body to choose a region/)).toBeNull();
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

it('moves the selection to the region a drag is released over', () => {
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const { view, editor } = renderRegions();
    const canvas = view.container.querySelector('canvas')!;
    const box = view.container.querySelector('.CustomSpriteEditor__canvas')!;
    send.mockClear();
    // Pressed on the torso, released over the left arm.
    fireEvent.mouseDown(canvas, { clientX: 5, clientY: 5, button: 0 });
    fireEvent.mouseMove(box, { clientX: 25, clientY: 5, buttons: 1 });
    fireEvent.mouseUp(box, { clientX: 25, clientY: 5, button: 0 });
    // The stroke's own transaction follows the selection, so check the call, not the last one.
    expect(send).toHaveBeenCalledWith('selectRegion', { zone: 'l_arm' });
    expect(screen.getByText('Left arm base markings')).toBeTruthy();
    // Dragged off the body: the last region the drag crossed wins.
    backendStore.set(gameDataAtom, {
      ...regionFixture(),
      selectedZone: 'chest',
      focusRevision: 2,
    });
    view.rerender(editor());
    expect(screen.getByText('Torso base markings')).toBeTruthy();
    send.mockClear();
    fireEvent.mouseDown(canvas, { clientX: 5, clientY: 5, button: 0 });
    fireEvent.mouseMove(box, { clientX: 25, clientY: 5, buttons: 1 });
    fireEvent.mouseMove(box, { clientX: 105, clientY: 5, buttons: 1 });
    fireEvent.mouseUp(box, { clientX: 105, clientY: 5, button: 0 });
    // The stroke's own transaction follows the selection, so check the call, not the last one.
    expect(send).toHaveBeenCalledWith('selectRegion', { zone: 'l_arm' });
    expect(screen.getByText('Left arm base markings')).toBeTruthy();
    // A plain release over empty space, or with another button, changes nothing.
    send.mockClear();
    fireEvent.mouseUp(box, { clientX: 105, clientY: 5, button: 0 });
    fireEvent.mouseUp(box, { clientX: 5, clientY: 5, button: 2 });
    expect(send).not.toHaveBeenCalledWith('selectRegion', expect.anything());
    expect(screen.getByText('Left arm base markings')).toBeTruthy();
  } finally {
    getBounds.mockRestore();
  }
});
