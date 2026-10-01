// THIS IS AN APHELION UI FILE
import { type HsvaColor, hexToHsva } from 'tgui-core/color';
import { Box, Button, Stack } from 'tgui-core/components';

type MutantColorButtonsProps = {
  /** The character's three mutant colours, if the picker has a character to read them from. */
  colors?: string[] | null;
  setColor: (color: HsvaColor) => void;
};

/** One button per mutant colour, setting the picker to it. */
export function MutantColorButtons(props: MutantColorButtonsProps) {
  const { colors, setColor } = props;
  if (!colors?.length) {
    return null;
  }

  return (
    <Stack align="center">
      <Stack.Item color="label">Use mutant color</Stack.Item>
      {colors.map((color, index) => (
        <Stack.Item key={index}>
          <Button tooltip={color} onClick={() => setColor(hexToHsva(color))}>
            <Box
              inline
              width="12px"
              height="12px"
              mr={0.5}
              backgroundColor={color}
              style={{
                verticalAlign: 'middle',
                border: '1px solid rgba(0, 0, 0, 0.5)',
              }}
            />
            {index + 1}
          </Button>
        </Stack.Item>
      ))}
    </Stack>
  );
}
