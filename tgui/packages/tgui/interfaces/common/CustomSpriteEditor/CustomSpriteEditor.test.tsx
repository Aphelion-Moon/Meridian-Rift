// THIS IS AN APHELION UI FILE

import { expect, it, jest, spyOn } from 'bun:test';
import { act, fireEvent, screen } from '@testing-library/react';
import { update } from 'tgui/events/handlers/update';
import {
  backendStateAtom,
  store as backendStore,
  gameDataAtom,
} from 'tgui/events/store';
import {
  compactSprite,
  fixture,
  fixtureFrames,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { renderEditor } from '../../../__mocks__/renderCustomSpriteEditor';
import {
  currentColorAtom,
  currentToolAtom,
  previewDataAtom,
  tools,
} from '../SpriteEditor/atoms';
import { colorToHexString } from '../SpriteEditor/colorSpaces';
import { Dir } from '../SpriteEditor/Types/types';
import type { CustomSpriteEditorData } from './types';

setupEditorTests();

it.each([
  'hair',
  'facial_hair',
  'markings',
] as const)('temporarily samples painted pixels and the guide with Alt+click in %s', (target) => {
  const frames = fixtureFrames();
  frames[Dir.SOUTH][0][0] = '#12abefff';
  frames[Dir.SOUTH][0][1] = '#00000000';
  const data = { ...fixture(), context: 'salon' };
  data.editorData.sprite = compactSprite(32, 32, frames);
  backendStore.set(gameDataAtom, data);
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const { store, view } = renderEditor(target);
    const canvas = view.container.querySelector('canvas')!;
    fireEvent.click(
      view.container.querySelector('.fa-eraser')!.closest('.Button')!,
    );
    const sample = (x: number) => {
      fireEvent.mouseDown(canvas, {
        clientX: x * 10 + 5,
        clientY: 5,
        button: 0,
        altKey: true,
      });
      // Releasing Alt during the gesture must not turn sampling into a stroke.
      fireEvent.mouseMove(window, { clientX: 35, clientY: 5 });
      fireEvent.mouseUp(window, { clientX: 35, clientY: 5, button: 0 });
    };
    send.mockClear();
    sample(0);
    expect(send.mock.calls).toEqual([['selectColor', { color: '#12abefff' }]]);
    expect(colorToHexString(store.get(currentColorAtom))).toBe('#12abefff');
    sample(1);
    expect(send).toHaveBeenLastCalledWith('sampleGuide', {
      dir: '2',
      x: 1,
      y: 0,
    });
    expect(send).toHaveBeenCalledTimes(2);
    expect(store.get(currentToolAtom)).toBe(tools[1]);
    expect(store.get(previewDataAtom)).toBeUndefined();
    fireEvent.click(screen.getByText('Guide'));
    sample(1);
    expect(send).toHaveBeenCalledTimes(2);
    fireEvent.mouseDown(canvas, { clientX: 5, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 5, clientY: 5, button: 0 });
    expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
      command: 'transaction',
      transaction: expect.objectContaining({ type: 'eraser' }),
    });
  } finally {
    getBounds.mockRestore();
  }
});

it('leaves form input, dialogs, modified shortcuts and scrolling outside color controls alone', () => {
  const data = fixture();
  data.editorData.serverPalette.push('#123456');
  data.availableColors.push('#123456');
  backendStore.set(gameDataAtom, data);
  const { view } = renderEditor('hair', {
    children: (
      <>
        <input aria-label="Name" />
        <textarea aria-label="Notes" />
        <select aria-label="Choice">
          <option>One</option>
        </select>
        <div contentEditable suppressContentEditableWarning>
          <span>Editable text</span>
        </div>
      </>
    ),
  });
  for (const target of [
    screen.getByLabelText('Name'),
    screen.getByLabelText('Notes'),
    screen.getByLabelText('Choice'),
    screen.getByText('Editable text'),
  ]) {
    expect(fireEvent.keyDown(target, { key: ']' })).toBe(true);
    expect(fireEvent.wheel(target, { deltaY: 100 })).toBe(true);
  }
  const canvas = view.container.querySelector('canvas')!;
  for (const modifier of ['ctrlKey', 'altKey', 'metaKey', 'shiftKey']) {
    expect(fireEvent.keyDown(document, { key: ']', [modifier]: true })).toBe(
      true,
    );
    const wheel = new WheelEvent('wheel', {
      deltaY: 100,
      bubbles: true,
      cancelable: true,
    });
    // Happy DOM's WheelEvent omits the inherited MouseEvent modifier fields.
    Object.defineProperty(wheel, modifier, { value: true });
    expect(fireEvent(canvas, wheel)).toBe(true);
  }
  expect(fireEvent.wheel(canvas, { deltaY: 0, deltaX: 100 })).toBe(true);
  expect(fireEvent.wheel(screen.getByText('Preview'), { deltaY: 100 })).toBe(
    true,
  );
  const dialog = document.createElement('div');
  dialog.className = 'Modal';
  document.body.appendChild(dialog);
  try {
    expect(fireEvent.keyDown(document, { key: ']' })).toBe(true);
    expect(fireEvent.wheel(canvas, { deltaY: 100 })).toBe(true);
  } finally {
    dialog.remove();
  }
  expect(send).not.toHaveBeenCalled();
  view.unmount();
  expect(fireEvent.keyDown(document, { key: ']' })).toBe(true);
  expect(send).not.toHaveBeenCalled();
});

it('shows failed saves without a success flash and allows retry', () => {
  const { view, editor } = renderEditor();
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 1 });
  view.rerender(editor());
  expect(screen.getByRole('status').textContent).toBe('Saved');
  const saveError = "Couldn't save to disk. Press Ctrl+S to retry.";
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 1, saveError });
  view.rerender(editor());
  expect(screen.queryByText('Saved')).toBeNull();
  expect(screen.getByRole('alert').textContent).toBe(saveError);
  fireEvent.keyDown(document, { key: 's', ctrlKey: true });
  expect(send).toHaveBeenLastCalledWith('saveDraft');
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 2 });
  view.rerender(editor());
  expect(screen.queryByRole('alert')).toBeNull();
  expect(screen.getByRole('status').textContent).toBe('Saved');
});

it('uses the selected direction limb silhouette to reject painting outside that limb', () => {
  const drawMask = {
    [Dir.SOUTH]: [
      '01000000000000000000000000000000',
      ...Array(31).fill('0'.repeat(32)),
    ],
    [Dir.NORTH]: [
      '00100000000000000000000000000000',
      ...Array(31).fill('0'.repeat(32)),
    ],
  };
  backendStore.set(gameDataAtom, {
    ...fixture(),
    drawMask,
  });
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const { view } = renderEditor('markings');
    const canvas = view.container.querySelector('canvas')!;
    const paint = (x: number) => {
      fireEvent.mouseDown(canvas, {
        clientX: x * 10 + 5,
        clientY: 5,
        button: 0,
      });
      fireEvent.mouseUp(window, { clientX: x * 10 + 5, clientY: 5, button: 0 });
    };
    send.mockClear();
    paint(0);
    expect(send).not.toHaveBeenCalled();
    paint(1);
    expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
      command: 'transaction',
      transaction: {
        type: 'pencil',
        name: 'Pencil',
        layer: 1,
        dir: '2',
        color: '#ffffffff',
        points: [[1, 0]],
      },
    });
    fireEvent.click(screen.getByText('Back'));
    send.mockClear();
    paint(1);
    expect(send).not.toHaveBeenCalled();
    paint(2);
    expect(send.mock.calls[0][1].transaction.dir).toBe('1');
    expect(send.mock.calls[0][1].transaction.points).toEqual([[2, 0]]);
  } finally {
    getBounds.mockRestore();
  }
});

it('covers a salon editor during the finishing touches, and fades out when they stop short', () => {
  jest.useFakeTimers();
  const data = {
    ...fixture(),
    context: 'salon',
    salonState: 'applying',
    applyDuration: 5000,
  };
  backendStore.set(gameDataAtom, data);
  const { view, editor } = renderEditor('hair');
  expect(screen.getByText('Applying finishing touches…')).toBeTruthy();
  backendStore.set(gameDataAtom, { ...data, salonState: 'drafting' });
  view.rerender(editor());
  expect(screen.getByText('Interrupted!')).toBeTruthy();
  act(() => jest.advanceTimersByTime(1300));
  expect(
    view.container.querySelector('.CustomSpriteEditor__finishing--fading'),
  ).not.toBeNull();
  act(() => jest.advanceTimersByTime(500));
  expect(
    view.container.querySelector('.CustomSpriteEditor__finishing'),
  ).toBeNull();
});

it('only reports salon brush activity, immediately and at most once a second during a stroke', () => {
  const data = { ...fixture(), context: 'salon', salonState: 'drafting' };
  data.drawBounds[Dir.SOUTH] = [1, 0, 31, 31];
  backendStore.set(gameDataAtom, data);
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  let now = 1000;
  const clock = spyOn(Date, 'now').mockImplementation(() => now);
  try {
    const { view } = renderEditor('hair');
    const canvas = view.container.querySelector('canvas')!;
    send.mockClear();
    fireEvent.mouseDown(canvas, { clientX: 5, clientY: 5, button: 0 });
    expect(send).not.toHaveBeenCalled();
    fireEvent.mouseMove(window, { clientX: 15, clientY: 5 });
    expect(send).toHaveBeenCalledTimes(1);
    expect(send).toHaveBeenLastCalledWith('drawing', {
      dir: '2',
      x: 1,
      y: 0,
      erasing: false,
    });
    fireEvent.mouseMove(window, { clientX: 25, clientY: 5 });
    expect(send).toHaveBeenCalledTimes(1);
    now += 1000;
    fireEvent.mouseMove(window, { clientX: 35, clientY: 5 });
    expect(send).toHaveBeenCalledTimes(2);
    fireEvent.mouseUp(window, { clientX: 35, clientY: 5, button: 0 });
    expect(send).toHaveBeenLastCalledWith(
      'spriteEditorCommand',
      expect.anything(),
    );
    send.mockClear();
    now += 1000;
    fireEvent.mouseMove(window, { clientX: 45, clientY: 5 });
    fireEvent.click(
      view.container.querySelector('.fa-vector-square')!.closest('.Button')!,
    );
    fireEvent.mouseDown(canvas, { clientX: 15, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 25, clientY: 15, button: 0 });
    expect(send).not.toHaveBeenCalled();
  } finally {
    getBounds.mockRestore();
    clock.mockRestore();
  }
});

it.each([
  'preferences',
  'salon',
] as const)('changes base hair in %s when the backend permits it', (context) => {
  const hair = {
    context,
    ...fixture(),
    canChangeHair: true,
    hairStyle: 'Short Hair',
    hairStyles: ['Bald', 'Short Hair', 'Bedhead'],
    hairStyleIcons: {
      Bald: 'hair-bald',
      'Short Hair': 'hair-short',
      Bedhead: 'hair-bedhead',
    },
    hairColor: '#583820',
  };
  backendStore.set(gameDataAtom, hair);
  const { view, editor } = renderEditor();
  fireEvent.click(screen.getByText('Hair color'));
  expect(send).toHaveBeenLastCalledWith('pickHairColor');
  send.mockClear();
  fireEvent.click(screen.getByLabelText('Select hairstyle'));
  fireEvent.input(screen.getByPlaceholderText('Search...'), {
    target: { value: 'bed' },
  });
  expect(screen.queryByLabelText('Bald')).toBeNull();
  expect(send).not.toHaveBeenCalled();
  fireEvent.click(screen.getByLabelText('Bedhead'));
  expect(send).toHaveBeenLastCalledWith('setHairStyle', { style: 'Bedhead' });
  backendStore.set(gameDataAtom, {
    ...hair,
    context: 'salon',
    canChangeHair: false,
    recipientName: 'Leia',
  });
  view.rerender(editor());
  expect(screen.queryByText('Base hair')).toBeNull();
  expect(screen.queryByText('Hair color')).toBeNull();
});

it('sends import and export requests without saving and confirms a previewed candidate', () => {
  const { view, editor } = renderEditor();
  fireEvent.click(screen.getByText('Export'));
  expect(send).toHaveBeenLastCalledWith('exportStyle');
  fireEvent.click(screen.getByText('Import'));
  expect(send).toHaveBeenLastCalledWith('importStyle');
  expect(send).not.toHaveBeenCalledWith('saveDraft');
  backendStore.set(gameDataAtom, {
    ...fixture(),
    candidate: {
      source: 'import',
      summary: 'Short Hair, #583820',
      previews: { 1: 'data:b', 2: 'data:f', 4: 'data:r', 8: 'data:l' },
    },
  });
  view.rerender(editor());
  expect(screen.getByText('Import this style?')).toBeTruthy();
  expect(screen.getByAltText('Left preview').getAttribute('src')).toBe(
    'data:l',
  );
  fireEvent.click(screen.getByText('Cancel'));
  expect(send).toHaveBeenLastCalledWith('cancelCandidate');
  fireEvent.click(screen.getByText('Replace draft'));
  expect(send).toHaveBeenLastCalledWith('confirmCandidate');
  backendStore.set(gameDataAtom, {
    ...fixture(),
    transferError: 'The file repeats the field "target".',
  });
  view.rerender(editor());
  expect(screen.getByRole('alert').textContent).toBe(
    'The file repeats the field "target".',
  );
});

it('shows a candidate whose previews are still being drawn, then the previews', () => {
  backendStore.set(gameDataAtom, {
    ...fixture(),
    candidate: {
      source: 'restore',
      summary: 'Short Hair, #583820',
      previews: null,
    },
  });
  const { view, editor } = renderEditor();
  expect(screen.getByText('Restore previous saved style?')).toBeTruthy();
  expect(screen.getByText('Drawing the preview...')).toBeTruthy();
  expect(screen.queryByAltText('Front preview')).toBeNull();
  backendStore.set(gameDataAtom, {
    ...fixture(),
    candidate: {
      source: 'restore',
      summary: 'Short Hair, #583820',
      previews: { 1: 'data:b', 2: 'data:f', 4: 'data:r', 8: 'data:l' },
    },
  });
  view.rerender(editor());
  expect(screen.queryByText('Drawing the preview...')).toBeNull();
  expect(screen.getByAltText('Front preview').getAttribute('src')).toBe(
    'data:f',
  );
});

it.each([
  ['import', 'Cancel', 'cancelCandidate'],
  ['import', 'Replace draft', 'confirmCandidate'],
  ['restore', 'Cancel', 'cancelCandidate'],
  ['restore', 'Replace draft', 'confirmCandidate'],
] as const)('dismisses the %s preview after %s receives a backend update', (source, button, action) => {
  const applyUpdate = (data: CustomSpriteEditorData) => {
    update({ ...backendStore.get(backendStateAtom), data, static_data: {} });
  };
  applyUpdate({
    ...fixture(),
    candidate: {
      source,
      summary: 'Short Hair, #583820',
      previews: { 1: 'data:b', 2: 'data:f', 4: 'data:r', 8: 'data:l' },
    },
  });
  const { view, editor } = renderEditor();
  expect(screen.getByAltText('Left preview')).toBeTruthy();
  fireEvent.click(screen.getByText(button));
  expect(send).toHaveBeenLastCalledWith(action);
  // The server owns dismissal. Exercise TGUI's merging update handler, which
  // retains a previous candidate if the next UI payload omits that field.
  view.rerender(editor());
  expect(screen.getByAltText('Left preview')).toBeTruthy();
  applyUpdate(fixture());
  view.rerender(editor());
  expect(screen.queryAllByAltText('Left preview')).toHaveLength(0);
  expect(screen.queryAllByText('Replace draft')).toHaveLength(0);
});

it('documents Ctrl+Shift+C and receives its one-off hair copy before a Bald paste', () => {
  const data = fixture();
  const frames = fixtureFrames();
  for (const frame of Object.values(frames))
    for (const row of frame) row.fill('#00000000');
  frames[Dir.SOUTH][0][1] = '#ff0000ff';
  data.editorData.sprite = compactSprite(32, 32, frames);
  data.hairStyle = 'Test hair';
  data.baseCopyInfo = {
    source: 'hair-editor',
    style: 'Test hair',
    origin: [0, 0],
    height: 32,
  };
  backendStore.set(gameDataAtom, data);
  const getBounds = spyOn(
    HTMLElement.prototype,
    'getBoundingClientRect',
  ).mockReturnValue(new DOMRect(0, 0, 320, 320));
  try {
    const { view, editor } = renderEditor('hair');
    fireEvent.keyDown(document, { key: 'm' });
    fireEvent.keyUp(document, { key: 'm' });
    expect(screen.queryByText('Ctrl+Shift+C')).toBeNull();
    const canvas = view.container.querySelector('canvas')!;
    fireEvent.mouseDown(canvas, { clientX: 5, clientY: 5, button: 0 });
    fireEvent.mouseUp(window, { clientX: 15, clientY: 5, button: 0 });
    expect(screen.getByText('Ctrl+Shift+C')).toBeTruthy();
    send.mockClear();
    fireEvent.keyDown(document, { key: 'C', ctrlKey: true, shiftKey: true });
    fireEvent.keyUp(document, { key: 'C', ctrlKey: true, shiftKey: true });
    const request = send.mock.calls[0][1].request;
    expect(send.mock.calls[0][0]).toBe('copyBaseLayer');
    act(() =>
      update({
        ...backendStore.get(backendStateAtom),
        static_data: {},
        data: {
          baseCopyResult: {
            request,
            source: 'hair-editor',
            origin: [0, 0],
            width: 32,
            height: 32,
            palette: ['#00000000', '#0000ffff'],
            codes: `11${'0'.repeat(1022)}`,
          },
        },
      }),
    );
    view.rerender(editor());
    act(() =>
      update({
        ...backendStore.get(backendStateAtom),
        static_data: {},
        data: {
          hairStyle: 'Bald',
          baseCopyInfo: {
            source: 'hair-editor',
            style: 'Bald',
            origin: [0, 0],
            height: 32,
          },
        },
      }),
    );
    view.rerender(editor());
    send.mockClear();
    fireEvent.keyDown(document, { key: 'v', ctrlKey: true });
    fireEvent.keyUp(document, { key: 'v', ctrlKey: true });
    expect(send).not.toHaveBeenCalled();
    fireEvent.keyDown(document, { key: 'Enter' });
    fireEvent.keyUp(document, { key: 'Enter' });
    expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
      command: 'transaction',
      transaction: expect.objectContaining({
        baseCopy: request,
        baseCopySource: 'hair-editor',
        palette: ['#0000ffff'],
        codes: '0',
        area: [0, 0, 0, 0],
      }),
    });
  } finally {
    getBounds.mockRestore();
  }
});
