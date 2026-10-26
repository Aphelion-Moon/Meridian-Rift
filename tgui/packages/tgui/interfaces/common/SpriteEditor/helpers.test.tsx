// THIS IS AN APHELION UI FILE
import { expect, it, mock, spyOn } from 'bun:test';
import { fireEvent, render } from '@testing-library/react';
import { useRef } from 'react';
import { AdvancedCanvas } from './Components/AdvancedCanvas';
import { useClickAndDragEventHandler } from './helpers';

const DragTarget = ({ move, up, label = 'Drag' }) => {
  const ref = useRef<HTMLButtonElement>(null);
  const start = useClickAndDragEventHandler(ref, undefined, move, up);
  return (
    <button ref={ref} onMouseDown={start}>
      {label}
    </button>
  );
};

it('keeps an active drag through rerenders and removes both listeners on unmount', () => {
  const move = mock();
  const up = mock();
  const view = render(<DragTarget move={move} up={up} />);
  fireEvent.mouseDown(view.getByRole('button'));
  view.rerender(<DragTarget move={move} up={up} label="Still dragging" />);
  fireEvent.mouseMove(window);
  expect(move).toHaveBeenCalledTimes(1);
  view.unmount();
  fireEvent.mouseMove(window);
  fireEvent.mouseUp(window);
  expect(move).toHaveBeenCalledTimes(1);
  expect(up).not.toHaveBeenCalled();
});

it('detaches listeners before invoking the release callback', () => {
  const move = mock();
  const up = mock(() => fireEvent.mouseMove(window));
  const view = render(<DragTarget move={move} up={up} />);
  fireEvent.mouseDown(view.getByRole('button'));
  fireEvent.mouseUp(window);
  expect(up).toHaveBeenCalledTimes(1);
  expect(move).not.toHaveBeenCalled();
  fireEvent.mouseUp(window);
  expect(up).toHaveBeenCalledTimes(1);
});

it('keeps hook order and click behavior when a canvas changes interaction mode', () => {
  const context = spyOn(
    HTMLCanvasElement.prototype,
    'getContext',
  ).mockReturnValue({
    clearRect: mock(),
    fillRect: mock(),
  } as unknown as CanvasRenderingContext2D);
  const click = mock();
  const move = mock();
  const data = [['#ffffffff']];
  try {
    const view = render(<AdvancedCanvas data={data} onClick={click} />);
    const canvas = view.container.querySelector('canvas')!;
    expect(fireEvent.mouseDown(canvas)).toBe(true);
    fireEvent.click(canvas);
    expect(click).toHaveBeenCalledTimes(1);
    view.rerender(<AdvancedCanvas data={data} onMouseMove={move} />);
    fireEvent.mouseDown(canvas);
    fireEvent.mouseMove(window);
    fireEvent.mouseUp(window);
    expect(move).toHaveBeenCalledTimes(1);
    view.rerender(<AdvancedCanvas data={data} onClick={click} />);
    fireEvent.click(canvas);
    expect(click).toHaveBeenCalledTimes(2);
  } finally {
    context.mockRestore();
  }
});
