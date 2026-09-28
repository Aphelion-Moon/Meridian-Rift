// THIS IS AN APHELION UI FILE
import { Box } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

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
