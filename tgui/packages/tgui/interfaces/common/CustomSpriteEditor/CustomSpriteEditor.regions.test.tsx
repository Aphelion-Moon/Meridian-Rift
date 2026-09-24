// THIS IS AN APHELION UI FILE
import { expect, it, spyOn } from 'bun:test';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  fixture,
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
  fireEvent.click(section.querySelectorAll('.Button')[0]);
  expect(send).toHaveBeenLastCalledWith('addBaseMarking', { zone: 'l_arm' });
  expect(screen.getByText('Click the body to choose a region.')).toBeTruthy();
});

it('says when a region has no base markings to offer', () => {
  renderRegions({
    ...regionFixture(),
    regionZones: ['chest', 'taur'],
    regionLabels: { chest: 'Torso', taur: 'Taur lower body' },
    selectedZone: 'taur',
  });
  expect(
    screen.getByText('Taur lower body has no base markings.'),
  ).toBeTruthy();
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

it('shows why new colors are refused when old markings use too many', () => {
  renderRegions({ ...regionFixture(), paletteNotice: 'Too many colors.' });
  expect(screen.getByText('Too many colors.')).toBeTruthy();
});

it('lists replaced and skipped regions when previewing an import', () => {
  renderRegions({
    ...regionFixture(),
    candidate: {
      source: 'import',
      previews: { 1: '', 2: '', 4: '', 8: '' },
      regions: ['Left arm'],
      skipped: ['Taur lower body'],
    },
  });
  expect(screen.getByText(/Replaces: Left arm\./)).toBeTruthy();
  expect(screen.getByText(/Skipped: Taur lower body/)).toBeTruthy();
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
