// THIS IS AN APHELION UI FILE
import type { ReactNode } from 'react';
import { type HsvaColor, hexToHsva } from 'tgui-core/color';
import { Box, Button, Stack } from 'tgui-core/components';

type MutantColorButtonsProps = {
  /** The character's three mutant colours, if the picker has a character to read them from. */
  colors?: string[] | null;
  /** The character's skin tone colour, when it uses a skin tone. */
  skinTone?: string | null;
  setColor: (color: HsvaColor) => void;
};

/** One button per mutant colour, and one for the skin tone when there is one, each setting the picker to its colour. */
export function MutantColorButtons(props: MutantColorButtonsProps) {
  const { colors, skinTone, setColor } = props;
  if (!colors?.length) {
    return null;
  }

  return (
    <Stack align="center">
      <Stack.Item color="label">Use mutant color</Stack.Item>
      {colors.map((color, index) => (
        <Stack.Item key={index}>
          <ColorButton color={color} setColor={setColor}>
            {index + 1}
          </ColorButton>
        </Stack.Item>
      ))}
      {!!skinTone && (
        <Stack.Item>
          <ColorButton color={skinTone} setColor={setColor}>
            Skin tone
          </ColorButton>
        </Stack.Item>
      )}
    </Stack>
  );
}

type ColorButtonProps = {
  color: string;
  setColor: (color: HsvaColor) => void;
  children: ReactNode;
};

/** A button with a swatch of `color`, setting the picker to it. */
function ColorButton(props: ColorButtonProps) {
  const { color, setColor, children } = props;

  return (
    <Button tooltip={color} onClick={() => setColor(hexToHsva(color))}>
      <Box className="MutantColorButtons__swatch" backgroundColor={color} />
      {children}
    </Button>
  );
}
