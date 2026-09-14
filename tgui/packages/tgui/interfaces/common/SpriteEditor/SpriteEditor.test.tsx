// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  mock,
  spyOn,
} from 'bun:test';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import * as actions from 'tgui/events/act';
import { NanopaintMenuBar } from '../../NtosNanopaint/NanopaintMenuBar';
import {
  currentColorInternalAtom,
  currentToolAtom,
  dirAtom,
  previewDataAtom,
  previewLayerAtom,
  selectionBoundsAtom,
  tools,
} from './atoms';
import { AdvancedCanvas } from './Components/AdvancedCanvas';
import { Palette } from './Components/Palette';
import { SpriteEditor } from './index';
import { Bucket } from './Types/Tools/Bucket';
import { Eraser } from './Types/Tools/Eraser';
import { Pencil } from './Types/Tools/Pencil';
import {
  Dir,
  type SpriteData,
  type SpriteEditorToolContext,
} from './Types/types';
import { useSpriteEditorHotkeys } from './useSpriteEditorHotkeys';

const Hotkeys = ({
  disabled = false,
  onSave,
}: {
  disabled?: boolean;
  onSave?: () => void;
}) => {
  useSpriteEditorHotkeys(disabled, onSave);
  return (
    <>
      <input aria-label="Text" />
      <div contentEditable suppressContentEditableWarning>
        <span>Editable</span>
      </div>
    </>
  );
};

describe('sprite editor interactions', () => {
  let send: ReturnType<typeof spyOn>;
  beforeEach(() => {
    send = spyOn(actions, 'sendAct');
  });
  afterEach(() => {
    send.mockRestore();
  });

  it('maps undo and both redo shortcuts to one command', () => {
    render(<Hotkeys />);
    for (const [key, shiftKey, command] of [
      ['z', false, 'undo'],
      ['y', false, 'redo'],
      ['z', true, 'redo'],
    ] as const) {
      const event = new KeyboardEvent('keydown', {
        key,
        ctrlKey: true,
        shiftKey,
        bubbles: true,
        cancelable: true,
      });
      act(() => {
        document.dispatchEvent(event);
      });
      expect(event.defaultPrevented).toBe(true);
      expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
        command,
        count: 1,
      });
    }
    expect(send).toHaveBeenCalledTimes(3);
  });

  it('leaves text editing and disabled canvases alone', () => {
    const view = render(<Hotkeys />);
    fireEvent.keyDown(screen.getByLabelText('Text'), {
      key: 'z',
      ctrlKey: true,
    });
    fireEvent.keyDown(screen.getByText('Editable'), {
      key: 'z',
      ctrlKey: true,
    });
    expect(send).not.toHaveBeenCalled();
    view.rerender(<Hotkeys disabled />);
    fireEvent.keyDown(document, { key: 'z', ctrlKey: true });
    expect(send).not.toHaveBeenCalled();
    view.unmount();
    fireEvent.keyDown(document, { key: 'z', ctrlKey: true });
    expect(send).not.toHaveBeenCalled();
  });

  it('saves without closing on Ctrl+S only when an active editor supplies a save action', () => {
    const onSave = () => actions.sendAct('saveDraft');
    const saveKey = () =>
      new KeyboardEvent('keydown', {
        key: 's',
        ctrlKey: true,
        bubbles: true,
        cancelable: true,
      });
    const view = render(<Hotkeys onSave={onSave} />);
    const save = saveKey();
    act(() => document.dispatchEvent(save));
    expect(save.defaultPrevented).toBe(true);
    expect(send).toHaveBeenCalledWith('saveDraft');
    for (const element of [
      screen.getByLabelText('Text'),
      screen.getByText('Editable'),
    ]) {
      const typing = saveKey();
      act(() => element.dispatchEvent(typing));
      expect(typing.defaultPrevented).toBe(false);
    }
    view.rerender(<Hotkeys disabled onSave={onSave} />);
    const disabled = saveKey();
    act(() => document.dispatchEvent(disabled));
    expect(disabled.defaultPrevented).toBe(false);
    view.rerender(<Hotkeys />);
    const unbound = saveKey();
    act(() => document.dispatchEvent(unbound));
    expect(unbound.defaultPrevented).toBe(false);
    view.rerender(<Hotkeys onSave={onSave} />);
    view.unmount();
    const unmounted = saveKey();
    act(() => document.dispatchEvent(unmounted));
    expect(unmounted.defaultPrevented).toBe(false);
    expect(send).toHaveBeenCalledTimes(1);
  });

  it('offers one button per history action and commits one step', () => {
    const view = render(
      <>
        <SpriteEditor.Undo stack={['First stroke', 'Second stroke']} />
        <SpriteEditor.Redo stack={['Third stroke']} />
      </>,
    );
    const buttons = view.container.querySelectorAll('.Button');
    expect(buttons).toHaveLength(2);
    for (const [index, command] of ['undo', 'redo'].entries()) {
      fireEvent.click(buttons[index]);
      expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
        command,
        count: 1,
      });
    }
    view.rerender(<SpriteEditor.Undo stack={[]} />);
    fireEvent.click(view.container.querySelector('.Button')!);
    expect(send).toHaveBeenCalledTimes(2);
  });

  it('keeps generic palette keyboard selection, Delete, and right-click selection', () => {
    const colors = [
      { r: 255, g: 255, b: 255 },
      { r: 128, g: 128, b: 128 },
    ];
    const select = mock(() => {});
    const remove = mock(() => {});
    const add = mock(() => {});
    const view = render(
      <Palette
        colors={colors}
        selectedColor={{ r: 0, g: 0, b: 0 }}
        onClickColor={select}
        onRemoveColor={remove}
        onClickAddColor={add}
        maxColors={3}
      />,
    );
    const buttons = view.container.querySelectorAll<HTMLElement>('.Button');
    expect(buttons).toHaveLength(3);
    expect(buttons[1].style.backgroundImage).toContain('#808080');
    fireEvent.mouseOver(buttons[1]);
    expect(document.activeElement).toBe(buttons[1]);
    fireEvent.keyDown(buttons[1], { key: 'Enter' });
    fireEvent.keyDown(buttons[1], { key: ' ' });
    expect(select).toHaveBeenCalledTimes(2);
    expect(select).toHaveBeenLastCalledWith(colors[1], false);
    fireEvent.keyDown(buttons[1], { key: 'Delete', keyCode: 46 });
    expect(remove).toHaveBeenCalledWith(2);
    expect(select).toHaveBeenCalledTimes(2);
    fireEvent.contextMenu(buttons[1]);
    expect(select).toHaveBeenLastCalledWith(colors[1], true);
    fireEvent.click(buttons[2]);
    expect(add).toHaveBeenCalledTimes(1);
  });

  it('paints literal pixels and preserves transparency and the guide', () => {
    const painted: string[] = [];
    const context = {
      fillStyle: '',
      clearRect: () => {},
      fillRect: () => painted.push(context.fillStyle),
    };
    const getContext = spyOn(
      HTMLCanvasElement.prototype,
      'getContext',
    ).mockReturnValue(context as unknown as CanvasRenderingContext2D);
    try {
      const data = [['#ffffffff', '#80808080', '#00000000']];
      const view = render(
        <AdvancedCanvas data={data} background="url(guide.png)" />,
      );
      expect(painted.slice(-3)).toEqual(data[0]);
      view.rerender(
        <AdvancedCanvas
          data={[['#ff8000ff', '#0080ff80', '#00000000']]}
          background="url(guide.png)"
        />,
      );
      expect(painted.slice(-3)).toEqual([
        '#ff8000ff',
        '#0080ff80',
        '#00000000',
      ]);
      expect(
        view.container.querySelector('canvas')!.style.backgroundImage,
      ).toContain('guide.png');
      expect(data).toEqual([['#ffffffff', '#80808080', '#00000000']]);
    } finally {
      getContext.mockRestore();
    }
  });

  it('draws the loaded guide beneath pixels on the same grid and refreshes it independently', () => {
    const operations: string[] = [];
    const context = {
      fillStyle: '',
      imageSmoothingEnabled: true,
      clearRect: () => {
        operations.length = 0;
      },
      drawImage: (
        image: HTMLImageElement,
        x: number,
        y: number,
        width: number,
        height: number,
      ) => {
        operations.push(
          `${image.src}:${x},${y},${width},${height}:${context.imageSmoothingEnabled}`,
        );
      },
      fillRect: () => operations.push(context.fillStyle),
    };
    const getContext = spyOn(
      HTMLCanvasElement.prototype,
      'getContext',
    ).mockReturnValue(context as unknown as CanvasRenderingContext2D);
    const getBounds = spyOn(
      HTMLElement.prototype,
      'getBoundingClientRect',
    ).mockReturnValue(new DOMRect(0, 0, 320, 320));
    try {
      const front = new Image();
      front.src = 'front.png';
      const back = new Image();
      back.src = 'back.png';
      const data = [
        ['#ffffffff', '#00000000'],
        ['#80808080', '#ff0000ff'],
      ];
      const view = render(
        <AdvancedCanvas data={data} backgroundImage={front} />,
      );
      expect(operations).toEqual([
        `${front.src}:0,0,320,320:false`,
        ...data.flat(),
      ]);
      view.rerender(<AdvancedCanvas data={data} backgroundImage={back} />);
      expect(operations).toEqual([
        `${back.src}:0,0,320,320:false`,
        ...data.flat(),
      ]);
      view.rerender(<AdvancedCanvas data={data} />);
      expect(operations).toEqual(data.flat());
    } finally {
      getContext.mockRestore();
      getBounds.mockRestore();
    }
  });

  it('shades exactly the forbidden pixels once using at most four rectangles', () => {
    type Bounds = [number, number, number, number];
    const rectangles: Bounds[] = [];
    const context = {
      fillStyle: '',
      clearRect: () => {
        rectangles.length = 0;
      },
      fillRect: (x: number, y: number, width: number, height: number) => {
        if (context.fillStyle === 'rgba(50, 50, 50, 0.75)') {
          rectangles.push([x / 10, y / 10, width / 10, height / 10]);
        }
      },
    };
    const getContext = spyOn(
      HTMLCanvasElement.prototype,
      'getContext',
    ).mockReturnValue(context as unknown as CanvasRenderingContext2D);
    const getBounds = spyOn(
      HTMLElement.prototype,
      'getBoundingClientRect',
    ).mockReturnValue(new DOMRect(0, 0, 320, 320));
    try {
      const data = Array.from({ length: 32 }, () =>
        Array(32).fill('#00000000'),
      );
      const cases: [Bounds | undefined, number, number, string[]?][] = [
        [[6, 0, 25, 20], 3, 604],
        [[2, 3, 28, 29], 4, 295],
        [[0, 0, -1, -1], 1, 1024],
        [[40, 40, 50, 50], 1, 1024],
        [[0, 0, 31, 31], 0, 0],
        [[-8, -8, 40, 40], 0, 0],
        [undefined, 0, 0],
        [
          undefined,
          33,
          1022,
          [`101${'0'.repeat(29)}`, ...Array(31).fill('0'.repeat(32))],
        ],
        [
          [1, 0, 31, 31],
          33,
          1023,
          [`101${'0'.repeat(29)}`, ...Array(31).fill('0'.repeat(32))],
        ],
      ];
      const view = render(<AdvancedCanvas data={data} />);
      for (const [bounds, rectangleCount, shadedPixels, mask] of cases) {
        view.rerender(
          <AdvancedCanvas data={data} drawBounds={bounds} drawMask={mask} />,
        );
        expect(rectangles).toHaveLength(rectangleCount);
        const coverage = Array.from({ length: 32 }, () => Array(32).fill(0));
        for (const [left, top, width, height] of rectangles) {
          expect(width).toBeGreaterThan(0);
          expect(height).toBeGreaterThan(0);
          expect(left).toBeGreaterThanOrEqual(0);
          expect(top).toBeGreaterThanOrEqual(0);
          expect(left + width).toBeLessThanOrEqual(32);
          expect(top + height).toBeLessThanOrEqual(32);
          for (let y = top; y < top + height; y++) {
            for (let x = left; x < left + width; x++) coverage[y][x]++;
          }
        }
        const expected = data.map((row, y) =>
          row.map((_, x) =>
            Number(
              (!!bounds &&
                (x < bounds[0] ||
                  y < bounds[1] ||
                  x > bounds[2] ||
                  y > bounds[3])) ||
                (!!mask && mask[y]?.[x] !== '1'),
            ),
          ),
        );
        expect(coverage).toEqual(expected);
        expect(coverage.flat().reduce((sum, value) => sum + value, 0)).toBe(
          shadedPixels,
        );
      }
    } finally {
      getContext.mockRestore();
      getBounds.mockRestore();
    }
  });

  it('echoes a gap-free fast drag locally and commits exactly once on release', () => {
    const frame = () =>
      Array.from({ length: 32 }, () => Array(32).fill('#00000000'));
    const data: SpriteData = {
      width: 32,
      height: 32,
      dirs: 1,
      backdrop: '',
      layers: [
        {
          name: 'Drawing',
          visible: true,
          data: {
            [Dir.SOUTH]: frame(),
            [Dir.NORTH]: undefined,
            [Dir.EAST]: undefined,
            [Dir.WEST]: undefined,
          },
        },
      ],
    };
    let preview: string[][] | undefined;
    const context: SpriteEditorToolContext = {
      currentColor: { r: 255, g: 255, b: 255 },
      selectedDir: Dir.SOUTH,
      selectedLayer: 0,
      setCurrentColor: () => {},
      setPreviewLayer: () => {},
      setPreviewData: (value) => {
        if (typeof value !== 'function') preview = value;
      },
    };
    const pencil = new Pencil();
    pencil.onMouseDown(context, data, 0, 0, false);
    pencil.onMouseMove(context, data, 31, 31);
    expect(send).not.toHaveBeenCalled();
    for (let pixel = 0; pixel < 32; pixel++)
      expect(preview?.[pixel][pixel]).toBe('#ffffffff');
    pencil.onMouseUp(context, data, 31, 31);
    expect(send).toHaveBeenCalledTimes(1);
    const transaction = send.mock.calls[0][1].transaction;
    expect(transaction.points).toHaveLength(32);
    expect(transaction.points[0]).toEqual([0, 0]);
    expect(transaction.points[31]).toEqual([31, 31]);
  });

  it.each([
    Pencil,
    Eraser,
  ])('skips duplicate preview work without losing release pixels for %p', (Tool) => {
    const frame = [Array(8).fill('#ffffffff')];
    const data: SpriteData = {
      width: 8,
      height: 1,
      dirs: 1,
      backdrop: '',
      layers: [
        {
          name: 'Drawing',
          visible: true,
          data: { 2: frame, 1: undefined, 4: undefined, 8: undefined },
        },
      ],
    };
    const setPreviewData = mock(() => {});
    const context: SpriteEditorToolContext = {
      currentColor: { r: 0, g: 0, b: 0 },
      selectedDir: Dir.SOUTH,
      selectedLayer: 0,
      setCurrentColor: () => {},
      setPreviewLayer: () => {},
      setPreviewData,
    };
    const tool = new Tool();
    tool.onMouseDown(context, data, 0, 0, false);
    for (let i = 0; i < 50; i++) tool.onMouseMove(context, data, 0.2, 0.3);
    expect(setPreviewData).toHaveBeenCalledTimes(1);
    tool.onMouseMove(context, data, 3, 0);
    tool.onMouseMove(context, data, 0, 0);
    expect(setPreviewData).toHaveBeenCalledTimes(2);
    tool.onMouseUp(context, data, 7, 0);
    expect(send).toHaveBeenCalledTimes(1);
    expect(send.mock.calls[0][1].transaction.points).toHaveLength(8);
    expect(frame[0]).toEqual(Array(8).fill('#ffffffff'));
  });

  it.each([
    Pencil,
    Eraser,
  ])('clips forbidden pixels from previews and transactions for %p', (Tool) => {
    const initial = Tool === Pencil ? '#00000000' : '#ffffffff';
    const data: SpriteData = {
      width: 32,
      height: 32,
      dirs: 1,
      backdrop: '',
      layers: [
        {
          name: 'Drawing',
          visible: true,
          data: {
            [Dir.SOUTH]: Array.from({ length: 32 }, () =>
              Array(32).fill(initial),
            ),
            [Dir.NORTH]: undefined,
            [Dir.EAST]: undefined,
            [Dir.WEST]: undefined,
          },
        },
      ],
    };
    let preview: string[][] | undefined;
    const context: SpriteEditorToolContext = {
      currentColor: { r: 255, g: 255, b: 255 },
      selectedDir: Dir.SOUTH,
      selectedLayer: 0,
      drawBounds: [8, 8, 23, 23],
      setCurrentColor: () => {},
      setPreviewLayer: () => {},
      setPreviewData: (value) => {
        if (typeof value !== 'function') preview = value;
      },
    };
    const tool = new Tool();
    tool.onMouseDown(context, data, 0, 0, false);
    tool.onMouseUp(context, data, 5, 5);
    expect(send).not.toHaveBeenCalled();
    expect(preview).toBeUndefined();
    tool.onMouseDown(context, data, 0, 0, false);
    tool.onMouseUp(context, data, 31, 31);
    expect(send).toHaveBeenCalledTimes(1);
    const points = send.mock.calls[0][1].transaction.points;
    expect(points).toHaveLength(16);
    expect(points[0]).toEqual([8, 8]);
    expect(points[15]).toEqual([23, 23]);
    expect(preview?.[0][0]).toBe(initial);
    expect(preview?.[31][31]).toBe(initial);
    context.drawMask = Array.from({ length: 32 }, (_, y) =>
      Array.from({ length: 32 }, (_, x) =>
        x === y && x !== 12 ? '1' : '0',
      ).join(''),
    );
    send.mockClear();
    const maskedTool = new Tool();
    maskedTool.onMouseDown(context, data, 8, 8, false);
    maskedTool.onMouseUp(context, data, 23, 23);
    expect(send.mock.calls[0][1].transaction.points).toHaveLength(15);
    expect(send.mock.calls[0][1].transaction.points).not.toContainEqual([
      12, 12,
    ]);
    expect(preview?.[12][12]).toBe(initial);
  });

  it('selects and moves through the toolbar and canvas without repainting the selection box', () => {
    const store = createStore();
    const frame = Array.from({ length: 8 }, () => Array(8).fill('#00000000'));
    frame[2][2] = '#ff0000ff';
    const data: SpriteData = {
      width: 8,
      height: 8,
      dirs: 4,
      backdrop: '',
      layers: [
        {
          name: 'Drawing',
          visible: true,
          data: { 2: frame, 1: frame, 4: frame, 8: frame },
        },
      ],
    };
    const fillRect = mock(() => {});
    const context = { fillStyle: '', clearRect: () => {}, fillRect };
    const getContext = spyOn(
      HTMLCanvasElement.prototype,
      'getContext',
    ).mockReturnValue(context as unknown as CanvasRenderingContext2D);
    const getBounds = spyOn(
      HTMLElement.prototype,
      'getBoundingClientRect',
    ).mockReturnValue(new DOMRect(0, 0, 80, 80));
    try {
      const view = render(
        <Provider store={store}>
          <SpriteEditor.Toolbar
            perButtonProps={(tool) => ({
              tooltip: tool.name,
              'aria-label': tool.name,
            })}
          />
          <SpriteEditor.Canvas data={data} />
        </Provider>,
      );
      expect(
        view.container.querySelector('.Button')?.getAttribute('aria-label'),
      ).toBe('Select');
      expect(
        screen.getByLabelText('Pencil').classList.contains('Button--selected'),
      ).toBe(true);
      fireEvent.click(screen.getByLabelText('Select'));
      const canvas = view.container.querySelector('canvas')!;
      const drag = (x: number, y: number, endX: number, endY: number) => {
        fireEvent.mouseDown(canvas, {
          clientX: x * 10 + 5,
          clientY: y * 10 + 5,
          button: 0,
          buttons: 1,
        });
        fireEvent.mouseMove(window, {
          clientX: endX * 10 + 5,
          clientY: endY * 10 + 5,
          buttons: 1,
        });
        fireEvent.mouseUp(window, {
          clientX: endX * 10 + 5,
          clientY: endY * 10 + 5,
          button: 0,
        });
      };
      const beforeSelection = fillRect.mock.calls.length;
      drag(2, 2, 4, 4);
      expect(store.get(selectionBoundsAtom)).toEqual([2, 2, 4, 4]);
      expect(
        view.container
          .querySelector('[data-selection-bounds]')
          ?.getAttribute('data-selection-bounds'),
      ).toBe('2,2,4,4');
      expect(fillRect).toHaveBeenCalledTimes(beforeSelection);
      expect(send).not.toHaveBeenCalled();
      drag(2, 2, 5, 3);
      expect(send).toHaveBeenCalledTimes(1);
      expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
        command: 'transaction',
        transaction: {
          type: 'move',
          name: 'Move selection',
          layer: 1,
          dir: '2',
          rect: [2, 2, 4, 4],
          offset: [3, 1],
        },
      });
      expect(store.get(selectionBoundsAtom)).toEqual([5, 3, 7, 5]);
      expect(frame[2][2]).toBe('#ff0000ff');
      fireEvent.keyDown(screen.getByLabelText('Select'), { key: 'Escape' });
      expect(store.get(selectionBoundsAtom)).toBeUndefined();
      drag(1, 1, 2, 2);
      act(() => store.set(dirAtom, Dir.NORTH));
      expect(store.get(selectionBoundsAtom)).toBeUndefined();
      expect(
        view.container.querySelector('[data-selection-bounds]'),
      ).toBeNull();
      act(() => store.set(dirAtom, Dir.SOUTH));
      drag(2, 2, 6, 6);
      data.width = data.height = 2;
      data.layers[0].data[Dir.SOUTH] = [
        ['#ff0000ff', '#00000000'],
        ['#00000000', '#00000000'],
      ];
      view.rerender(
        <Provider store={store}>
          <SpriteEditor.Toolbar
            perButtonProps={(tool) => ({
              tooltip: tool.name,
              'aria-label': tool.name,
            })}
          />
          <SpriteEditor.Canvas data={data} />
        </Provider>,
      );
      expect(store.get(selectionBoundsAtom)).toBeUndefined();
      view.unmount();
    } finally {
      getContext.mockRestore();
      getBounds.mockRestore();
    }
  });

  it('keeps multi-layer blending and detects changed pixels without repainting for brush colors', () => {
    const store = createStore();
    const layers = ['#ff0000ff', '#0000ff80'].map((color) => ({
      name: 'Drawing',
      visible: true,
      data: { 2: [[color]], 1: undefined, 4: undefined, 8: undefined },
    }));
    const data: SpriteData = {
      width: 1,
      height: 1,
      dirs: 1,
      backdrop: '',
      layers,
    };
    const painted: string[] = [];
    const context = {
      fillStyle: '',
      clearRect: () => {},
      fillRect: () => painted.push(context.fillStyle),
    };
    const getContext = spyOn(
      HTMLCanvasElement.prototype,
      'getContext',
    ).mockReturnValue(context as unknown as CanvasRenderingContext2D);
    try {
      const editor = () => (
        <Provider store={store}>
          <SpriteEditor.Canvas data={data} />
        </Provider>
      );
      const view = render(editor());
      expect(painted.at(-1)).toBe('#7f0080');
      const beforeColor = painted.length;
      act(() => store.set(currentColorInternalAtom, { r: 1, g: 2, b: 3 }));
      expect(painted).toHaveLength(beforeColor);
      layers[1].data[2][0][0] = '#00ff00ff';
      view.rerender(editor());
      expect(painted.at(-1)).toBe('#00ff00');
      view.unmount();
    } finally {
      getContext.mockRestore();
    }
  });

  it.each([
    'button',
    'keyboard',
    'NanoPaint menu',
  ])('clears a pending selection before %s history even without changed server pixels', async (entry) => {
    const store = createStore();
    const context = {
      setPreviewData: (value) => store.set(previewDataAtom, value),
      setPreviewLayer: (value) => store.set(previewLayerAtom, value),
      setSelectionBounds: (value) => store.set(selectionBoundsAtom, value),
    };
    store.set(currentToolAtom, tools[4], context);
    store.set(selectionBoundsAtom, [0, 0, 0, 0]);
    store.set(previewDataAtom, [['#ff0000ff']]);
    store.set(previewLayerAtom, 0);
    const view = render(
      <Provider store={store}>
        <Hotkeys />
        <SpriteEditor.Undo stack={['Move selection']} />
        <NanopaintMenuBar
          undoHistory={['Move selection']}
          redoHistory={[]}
          workspaceOpen
          zoom={1}
          minZoom={1}
          maxZoom={20}
          setZoom={() => {}}
        />
      </Provider>,
    );
    if (entry === 'button')
      fireEvent.click(view.container.querySelector('.Button')!);
    else if (entry === 'keyboard')
      fireEvent.keyDown(document, { key: 'z', ctrlKey: true });
    else {
      fireEvent.click(screen.getByText('Edit'));
      fireEvent.click(await screen.findByText('Undo Move selection'));
    }
    expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
      command: 'undo',
      count: 1,
    });
    expect(store.get(previewDataAtom)).toBeUndefined();
    expect(store.get(selectionBoundsAtom)).toBeUndefined();
    view.unmount();
    tools[4].cancel?.(context);
  });

  it('does not start a fill outside editable bounds', () => {
    const context: SpriteEditorToolContext = {
      currentColor: { r: 255, g: 255, b: 255 },
      selectedDir: Dir.SOUTH,
      selectedLayer: 0,
      drawBounds: [8, 8, 23, 23],
      setCurrentColor: () => {},
      setPreviewLayer: () => {},
      setPreviewData: () => {},
    };
    const data: SpriteData = {
      width: 32,
      height: 32,
      dirs: 1,
      backdrop: '',
      layers: [],
    };
    const bucket = new Bucket();
    bucket.onMouseDown(context, data, 0, 0);
    expect(send).not.toHaveBeenCalled();
    bucket.onMouseDown(context, data, 8, 8);
    expect(send.mock.calls[0][1].transaction.point).toEqual([8, 8]);
    send.mockClear();
    context.drawMask = Array(32).fill('0'.repeat(32));
    bucket.onMouseDown(context, data, 8, 8);
    expect(send).not.toHaveBeenCalled();
  });

  it.each([
    Pencil,
    Eraser,
  ])('includes the release position in a single committed stroke for %p', (Tool) => {
    const data: SpriteData = {
      width: 32,
      height: 32,
      dirs: 1,
      backdrop: '',
      layers: [
        {
          name: 'Drawing',
          visible: true,
          data: {
            [Dir.SOUTH]: Array.from({ length: 32 }, () =>
              Array(32).fill('#ffffffff'),
            ),
            [Dir.NORTH]: undefined,
            [Dir.EAST]: undefined,
            [Dir.WEST]: undefined,
          },
        },
      ],
    };
    const context: SpriteEditorToolContext = {
      currentColor: { r: 255, g: 255, b: 255 },
      selectedDir: Dir.SOUTH,
      selectedLayer: 0,
      setCurrentColor: () => {},
      setPreviewLayer: () => {},
      setPreviewData: () => {},
    };
    const tool = new Tool();
    tool.onMouseDown(context, data, 0, 0, false);
    tool.onMouseUp(context, data, 31, 31);
    expect(send).toHaveBeenCalledTimes(1);
    expect(send.mock.calls[0][1].transaction.points).toHaveLength(32);
  });
});
