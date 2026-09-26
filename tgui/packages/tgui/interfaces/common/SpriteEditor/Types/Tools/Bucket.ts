import { sendAct as act } from 'tgui/events/act';
import { colorToHexString } from '../../colorSpaces';
// APHELION EDIT CHANGE - ORIGINAL: import { constrainToIconGrid } from '../../helpers';
import { constrainToIconGrid, isWithinDrawBounds } from '../../helpers';
import { Tool } from '../Tool';
import type { SpriteData, SpriteEditorToolContext } from '../types';

export class Bucket extends Tool {
  icon = 'fill-drip';
  name = 'Fill';

  onMouseDown(
    context: SpriteEditorToolContext,
    data: SpriteData,
    x: number,
    y: number,
    isRightClick?: boolean,
  ) {
    if (isRightClick) return undefined;
    const { selectedDir, selectedLayer, currentColor } = context;
    const { width, height } = data;
    const [px, py, inBounds] = constrainToIconGrid(x, y, width, height);
    // if (!inBounds) return undefined; // APHELION EDIT REMOVAL
    // APHELION EDIT ADDITION START
    if (
      !inBounds ||
      !isWithinDrawBounds(px, py, context.drawBounds, context.drawMask)
    )
      return undefined;
    context.onDraw?.(px, py);
    // APHELION EDIT ADDITION END
    act('spriteEditorCommand', {
      command: 'transaction',
      transaction: {
        type: 'bucket',
        name: 'Flood Fill',
        layer: selectedLayer + 1,
        dir: `${selectedDir}`,
        color: colorToHexString(currentColor),
        point: [px, py],
      },
    });
  }
}
