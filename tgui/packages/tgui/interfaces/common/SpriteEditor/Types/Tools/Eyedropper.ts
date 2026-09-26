import { parseHexColorString } from '../../colorSpaces';
import { constrainToIconGrid, getDataPixel } from '../../helpers';
import { Tool } from '../Tool';
import type { SpriteData, SpriteEditorToolContext } from '../types';

export class Eyedropper extends Tool {
  icon = 'eye-dropper';
  name = 'Eyedropper';

  onMouseDown(
    context: SpriteEditorToolContext,
    data: SpriteData,
    x: number,
    y: number,
    isRightClick?: boolean,
  ) {
    if (isRightClick) return undefined;
    // const { selectedDir, selectedLayer, setCurrentColor } = context; // APHELION EDIT REMOVAL
    // APHELION EDIT ADDITION START
    const { selectedDir, selectedLayer, setCurrentColor, onSampleBackdrop } =
      context;
    // APHELION EDIT ADDITION END
    const { width, height } = data;
    const [px, py, inBounds] = constrainToIconGrid(x, y, width, height);
    if (!inBounds) return undefined;
    /* // APHELION EDIT REMOVAL START
    setCurrentColor(
      parseHexColorString(
        getDataPixel(data, selectedLayer, selectedDir, px, py),
      ),
    );
    */ // APHELION EDIT REMOVAL END
    // APHELION EDIT ADDITION START
    const painted = parseHexColorString(
      getDataPixel(data, selectedLayer, selectedDir, px, py),
    );
    if (painted.a !== 0) {
      setCurrentColor(painted);
    } else if (onSampleBackdrop) {
      onSampleBackdrop(px, py);
    } else {
      setCurrentColor(
        data.backdrop ? parseHexColorString(data.backdrop) : painted,
      );
    }
    // APHELION EDIT ADDITION END
  }
}
