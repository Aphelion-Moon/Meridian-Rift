// THIS IS AN APHELION UI FILE

import { expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
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
import {
  currentColorAtom,
  currentToolAtom,
  previewDataAtom,
  tools,
} from '../SpriteEditor/atoms';
import { colorToHexString } from '../SpriteEditor/colorSpaces';
import { Dir } from '../SpriteEditor/Types/types';
import { CustomSpriteEditor } from './index';
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
    const store = createStore();
    const view = render(
      <Provider store={store}>
        <CustomSpriteEditor target={target} />
      </Provider>,
    );
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
  const view = render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
      <input aria-label="Name" />
      <textarea aria-label="Notes" />
      <select aria-label="Choice">
        <option>One</option>
      </select>
      <div contentEditable suppressContentEditableWarning>
        <span>Editable text</span>
      </div>
    </Provider>,
  );
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
  const store = createStore();
  const editor = (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const view = render(editor);
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 1 });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(screen.getByRole('status').textContent).toBe('Saved');
  const saveError = "Couldn't save to disk. Press Ctrl+S to retry.";
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 1, saveError });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(screen.queryByText('Saved')).toBeNull();
  expect(screen.getByRole('alert').textContent).toBe(saveError);
  fireEvent.keyDown(document, { key: 's', ctrlKey: true });
  expect(send).toHaveBeenLastCalledWith('saveDraft');
  backendStore.set(gameDataAtom, { ...fixture(), saveRevision: 2 });
  view.rerender(
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
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
    const view = render(
      <Provider store={createStore()}>
        <CustomSpriteEditor target="markings" />
      </Provider>,
    );
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
    const view = render(
      <Provider store={createStore()}>
        <CustomSpriteEditor target="hair" />
      </Provider>,
    );
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
  const store = createStore();
  const hair = {
    context,
    ...fixture(),
    canChangeHair: true,
    hairStyle: 'Short Hair',
    hairStyles: ['Bald', 'Short Hair', 'Bedhead'],
    hairColor: '#583820',
  };
  backendStore.set(gameDataAtom, hair);
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const view = render(editor());
  fireEvent.click(screen.getByText('Hair color'));
  expect(send).toHaveBeenLastCalledWith('pickHairColor');
  fireEvent.click(screen.getByPlaceholderText('Short Hair'));
  fireEvent.click(screen.getByText('Bedhead'));
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
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  const view = render(editor());
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
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
  backendStore.set(gameDataAtom, {
    ...fixture(),
    candidate: {
      source: 'restore',
      summary: 'Short Hair, #583820',
      previews: null,
    },
  });
  const view = render(editor());
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
  const store = createStore();
  const editor = () => (
    <Provider store={store}>
      <CustomSpriteEditor target="hair" />
    </Provider>
  );
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
  const view = render(editor());
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
