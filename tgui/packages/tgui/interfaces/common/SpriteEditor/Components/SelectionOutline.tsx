// THIS IS AN APHELION UI FILE
import type { SelectionBounds, SelectionMask } from '../Types/types';

/**
 * A selection's marching ants: around its box, or along the edge of just the selected pixels when
 * some have been taken out. The box may reach past the canvas while its paint floats.
 */
export const SelectionOutline = (props: {
  bounds: SelectionBounds;
  mask?: SelectionMask;
  /** Screen pixels per sprite pixel, across and down. */
  scaleX: number;
  scaleY: number;
}) => {
  const { bounds, mask, scaleX, scaleY } = props;
  const [left, top, right, bottom] = bounds;
  const width = (right - left + 1) * scaleX;
  const height = (bottom - top + 1) * scaleY;
  const style = { left: left * scaleX, top: top * scaleY, width, height };
  if (!mask) {
    return (
      <div
        className="SpriteEditor__selection"
        data-selection-bounds={bounds.join(',')}
        style={style}
      />
    );
  }
  const selected = (x: number, y: number) => mask[y]?.[x] === '1';
  // Every side a selected pixel shares with an unselected one.
  const edges: string[] = [];
  for (let y = 0; y < mask.length; y++) {
    for (let x = 0; x < mask[y].length; x++) {
      if (!selected(x, y)) continue;
      const [x0, y0] = [x * scaleX, y * scaleY];
      const [x1, y1] = [x0 + scaleX, y0 + scaleY];
      if (!selected(x, y - 1)) edges.push(`M${x0} ${y0}H${x1}`);
      if (!selected(x, y + 1)) edges.push(`M${x0} ${y1}H${x1}`);
      if (!selected(x - 1, y)) edges.push(`M${x0} ${y0}V${y1}`);
      if (!selected(x + 1, y)) edges.push(`M${x1} ${y0}V${y1}`);
    }
  }
  const path = edges.join('');
  return (
    <svg
      className="SpriteEditor__selection SpriteEditor__selection--mask"
      data-selection-bounds={bounds.join(',')}
      style={style}
      width={width}
      height={height}
    >
      <path className="SpriteEditor__selectionEdge" d={path} />
      <path className="SpriteEditor__selectionAnts" d={path} />
    </svg>
  );
};
