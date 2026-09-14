import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { act, fireEvent, render, screen } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { SpriteEditor } from './index';
import { Eraser } from './Types/Tools/Eraser';
import { Pencil } from './Types/Tools/Pencil';
import {
  Dir,
  type SpriteData,
  type SpriteEditorToolContext,
} from './Types/types';
import { useSpriteEditorHotkeys } from './useSpriteEditorHotkeys';

const Hotkeys = ({ disabled = false }: { disabled?: boolean }) => {
  useSpriteEditorHotkeys(disabled);
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

  it('jumps through the selected history entry, including that entry', async () => {
    const view = render(
      <SpriteEditor.Undo
        stack={['First stroke', 'Second stroke', 'Third stroke']}
      />,
    );
    await act(async () => {
      fireEvent.click(view.container.querySelectorAll('.Button')[1]);
    });
    await act(async () => {
      fireEvent.click(screen.getByText('Second stroke'));
    });
    expect(send).toHaveBeenLastCalledWith('spriteEditorCommand', {
      command: 'undo',
      count: 2,
    });
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
