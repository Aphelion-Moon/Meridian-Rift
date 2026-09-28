// THIS IS AN APHELION UI FILE
import { resolveAsset } from 'tgui/assets';
import { Box } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import type { SpeciesSelfPreview } from '../../types';
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
  const size = `${32 * scale}px`;

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
  preview: SpeciesSelfPreview;
  dir: SpriteDir;
  /** The square it fills, in pixels, as a species sprite at the same scale would. */
  box: number;
};

/**
 * One facing of a drawn preview mob. It is scaled by the largest whole number
 * that fits the box, so larger mobs still fit, and stands on the box's floor.
 */
export function PreviewFrame(props: PreviewFrameProps) {
  const { preview, dir, box } = props;
  const { width, height } = preview;
  const scale = Math.max(1, Math.floor(box / Math.max(width, height)));

  return (
    <Box className="SpeciesSprite" style={{ width: box, height: box }}>
      <Box
        className="SpeciesSprite__frame"
        style={{
          left: `${Math.floor((box - width * scale) / 2)}px`,
          top: `${box - height * scale}px`,
          width: `${width}px`,
          height: `${height}px`,
          backgroundImage: `url('${resolveAsset(preview.image)}')`,
          backgroundPosition: `-${preview.frames[dir]}px 0`,
          transform: `scale(${scale})`,
        }}
      />
    </Box>
  );
}
