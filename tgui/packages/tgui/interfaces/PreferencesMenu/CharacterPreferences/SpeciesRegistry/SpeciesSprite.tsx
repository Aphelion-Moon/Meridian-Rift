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
  /** The square a species sprite fills at the viewer's scale, in pixels. */
  box: number;
};

/** A species sprite's frame, and a mob's own tile, in pixels. */
const TILE = 32;

/**
 * One facing of a drawn preview mob. Its own tile stands where a species
 * sprite would, centred on the box's floor, with parts that reach past it,
 * like wings and big ears, around it. It is scaled by the largest whole
 * number, up to a species sprite's, that keeps those parts in the box; only
 * what hangs below its feet may run over the floor.
 */
export function PreviewFrame(props: PreviewFrameProps) {
  const { preview, dir, box } = props;
  const { width, height, x, y } = preview;
  // From the tile's centre to the frame's farther side, and from its floor to the top.
  const reach = Math.max(x + TILE / 2, width - x - TILE / 2);
  const rise = height - y;
  const scale = Math.max(
    1,
    Math.min(
      Math.floor(box / TILE),
      Math.floor(box / 2 / reach),
      Math.floor(box / rise),
    ),
  );

  return (
    <Box
      className="SpeciesSprite SpeciesSprite--preview"
      style={{ width: box, height: box }}
    >
      <Box
        className="SpeciesSprite__frame"
        style={{
          left: `${box / 2 - (x + TILE / 2) * scale}px`,
          top: `${box - rise * scale}px`,
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
