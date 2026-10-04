// THIS IS AN APHELION UI FILE
import { Box } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import type { CharacterPreviewDrawing } from '../../types';
import {
  PreviewCanvas,
  previewScale,
  TILE,
  useShownPreview,
} from '../CharacterPreview/drawing';
import { type SpriteDir, speciesSpriteClasses } from './constants';

type Props = {
  icon: string;
  dir?: SpriteDir;
  bare?: boolean;
  /** Whole-number scale keeps the pixels square. */
  scale?: number;
  className?: string;
};

/** One frame of a whole-body species spritesheet, scaled up crisply. */
export function SpeciesSprite(props: Props) {
  const { icon, dir = 'south', bare = false, scale = 1, className } = props;
  const size = `${TILE * scale}px`;

  return (
    <Box
      className={classes(['SpeciesSprite', className])}
      style={{ width: size, height: size }}
    >
      <Box
        className={speciesSpriteClasses(icon, dir, bare)}
        style={{ transform: `scale(${scale})` }}
      />
    </Box>
  );
}

type PreviewFrameProps = {
  preview: CharacterPreviewDrawing;
  dir: SpriteDir;
  /** The square a species sprite fills at the viewer's scale, in pixels. */
  box: number;
};

/**
 * One facing of the character's own preview, where a species sprite would
 * stand: its tile centred on the box's floor, with parts that reach past it,
 * like wings and big ears, around it, scaled as large as everything it draws
 * fits the box; see previewScale().
 */
export function PreviewFrame(props: PreviewFrameProps) {
  const { dir, box } = props;
  const shown = useShownPreview(props.preview);
  const scale = previewScale(shown.preview, box, shown.bounds);

  return (
    <Box
      className="SpeciesSprite SpeciesSprite--preview"
      style={{ width: box, height: box }}
    >
      <PreviewCanvas
        className="SpeciesSprite__frame"
        shown={shown}
        dir={dir}
        scale={scale}
        x={box / 2}
        y={box}
      />
    </Box>
  );
}
