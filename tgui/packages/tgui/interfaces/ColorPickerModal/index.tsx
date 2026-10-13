/**
 * @file
 * @copyright 2023 itsmeow
 * @license MIT
 */
import type React from 'react';
import { useEffect, useState } from 'react';
import { type HsvaColor, hexToHsva } from 'tgui-core/color';
import { Autofocus, Box, Section, Stack } from 'tgui-core/components';
import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { Loader } from '../common/Loader';
import { ColorSelector } from './ColorSetter';
import { MutantColorButtons } from './MutantColorButtons'; // APHELION EDIT ADDITION - mutant colour shortcuts

interface ColorPickerData {
  autofocus: boolean;
  buttons: string[];
  message: string;
  large_buttons: boolean;
  swapped_buttons: boolean;
  timeout: number;
  title: string;
  default_color: string;
  mutant_colors?: string[] | null; // APHELION EDIT ADDITION - mutant colour shortcuts
  skin_tone?: string | null; // APHELION EDIT ADDITION - skin tone shortcut
}

type ColorPickerModalProps = any;

export const ColorPickerModal: React.FC<ColorPickerModalProps> = () => {
  const { data } = useBackend<ColorPickerData>();
  const { timeout, message, autofocus, default_color = '#000000' } = data;
  let { title } = data;

  const [selectedColor, setSelectedColor] = useState<HsvaColor>(
    hexToHsva(default_color),
  );

  useEffect(() => {
    setSelectedColor(hexToHsva(default_color));
  }, [default_color]);

  if (!title) {
    title = 'Colour Editor';
  }

  return (
    <Window
      height={(message ? 465 : 430) + (data.mutant_colors?.length ? 30 : 0)} // APHELION EDIT CHANGE - ORIGINAL: height={message ? 465 : 430}
      title={title}
      width={700}
      theme="generic"
    >
      {!!timeout && <Loader value={timeout} />}
      <Window.Content>
        <Stack fill vertical>
          {!!autofocus && <Autofocus />}
          {/* APHELION EDIT ADDITION START - mutant colour shortcuts */}
          {!!data.mutant_colors?.length && (
            <Stack.Item>
              <MutantColorButtons
                colors={data.mutant_colors}
                skinTone={data.skin_tone}
                setColor={setSelectedColor}
              />
            </Stack.Item>
          )}
          {/* APHELION EDIT ADDITION END */}
          {message && (
            <Stack.Item>
              <Section fill>
                <Box color="label" overflow="hidden">
                  {message}
                </Box>
              </Section>
            </Stack.Item>
          )}
          <Stack.Item grow>
            <Section fill>
              <ColorSelector
                color={selectedColor}
                setColor={setSelectedColor}
                defaultColor={default_color}
              />
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
