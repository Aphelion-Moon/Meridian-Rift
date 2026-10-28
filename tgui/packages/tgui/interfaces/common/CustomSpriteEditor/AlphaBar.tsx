// THIS IS AN APHELION UI FILE
import { memo, useRef } from 'react';
import { type HsvaColor, hsvaToHslaString } from 'tgui-core/color';
import { type Interaction, Interactive, Pointer } from 'tgui-core/components';
import { clamp } from 'tgui-core/math';
import { classes } from 'tgui-core/react';
import { GRAFFITI_ALPHA_CEILING, GRAFFITI_ALPHA_FLOOR } from './graffitiCodec';

type AlphaBarProps = {
  className?: string;
  hsva: HsvaColor;
  onChange: (color: Partial<HsvaColor>) => void;
};

/** The alpha at the bar's left end: the floor, as a share of the ceiling its right end stands for. */
const FLOOR = GRAFFITI_ALPHA_FLOOR / GRAFFITI_ALPHA_CEILING;

/**
 * The colour's alpha as a bar over a checkerboard, built as ColorPickerModal's Hue is. It spans only the alphas paint
 * may have, from the floor at its left end to opaque at its right, so no move or key step goes under the floor.
 */
export const AlphaBar = memo((props: AlphaBarProps) => {
  const { className, hsva, onChange } = props;
  const containerRef = useRef<HTMLDivElement>(null);
  const handleMove = (interaction: Interaction) =>
    onChange({ a: FLOOR + (1 - FLOOR) * interaction.left });
  const handleKey = (offset: Interaction) =>
    onChange({ a: clamp(hsva.a + offset.left, FLOOR, 1) });
  return (
    <div className={classes(['react-colorful__alpha', className])}>
      <div
        className="react-colorful__alpha-gradient"
        style={{
          backgroundImage: `linear-gradient(to right, ${hsvaToHslaString({ ...hsva, a: FLOOR })}, ${hsvaToHslaString({ ...hsva, a: 1 })})`,
        }}
      />
      <Interactive
        containerRef={containerRef}
        onMove={handleMove}
        onKey={handleKey}
        aria-label="Alpha"
        aria-valuenow={Math.round(hsva.a * 100)}
        aria-valuemax={100}
        aria-valuemin={Math.round(FLOOR * 100)}
      >
        <Pointer
          className="react-colorful__alpha-pointer"
          left={clamp((hsva.a - FLOOR) / (1 - FLOOR), 0, 1)}
          color={hsvaToHslaString(hsva)}
        />
      </Interactive>
    </div>
  );
});
