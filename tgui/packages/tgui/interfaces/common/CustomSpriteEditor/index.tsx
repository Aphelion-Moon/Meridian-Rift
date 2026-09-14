import { useAtom, useSetAtom } from 'jotai';
import { useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { Window } from 'tgui/layouts';
import { Box, Button, ColorBox, Section, Stack } from 'tgui-core/components';
import { SpriteEditor } from '../SpriteEditor';
import { dirAtom, layerAtom } from '../SpriteEditor/atoms';
import { Dir } from '../SpriteEditor/Types/types';
import type { CustomSpriteEditorData } from './types';

const directions = [
  [Dir.SOUTH, 'Front'],
  [Dir.NORTH, 'Back'],
  [Dir.EAST, 'Right'],
  [Dir.WEST, 'Left'],
] as const;

export const CustomSpriteEditor = ({
  target,
}: {
  target: 'hair' | 'markings';
}) => {
  const { data, act } = useBackend<CustomSpriteEditorData>();
  const {
    editorData,
    tint,
    guides,
    previews,
    edited,
    drawBounds,
    unsupportedZones,
  } = data;
  const [direction, setDirection] = useAtom(dirAtom);
  const setLayer = useSetAtom(layerAtom);
  const [showGuide, setShowGuide] = useState(true);
  const [showGrid, setShowGrid] = useState(false);
  SpriteEditor.syncBackend();
  useEffect(() => {
    setLayer(0);
    setDirection(Dir.SOUTH);
  }, []);

  return (
    <Window
      width={780}
      height={650}
      title={target === 'hair' ? 'Custom Hair' : 'Custom Markings'}
    >
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Stack>
              {directions.map(([dir, label]) => (
                <Stack.Item key={dir} grow>
                  <Button
                    fluid
                    selected={direction === dir}
                    onClick={() => setDirection(dir)}
                  >
                    {label}
                    {edited[dir] ? ' •' : ''}
                  </Button>
                </Stack.Item>
              ))}
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item>
                <SpriteEditor.Toolbar
                  toolFlags={editorData.toolFlags}
                  perButtonProps={(tool) => ({ tooltip: tool.name })}
                />
              </Stack.Item>
              <Stack.Item>
                <SpriteEditor.Undo stack={editorData.undoStack} />
                <SpriteEditor.Redo stack={editorData.redoStack} />
              </Stack.Item>
              <Stack.Item grow />
              <Stack.Item>
                <Button.Checkbox
                  checked={showGuide}
                  onClick={() => setShowGuide(!showGuide)}
                >
                  Guide
                </Button.Checkbox>
                <Button.Checkbox
                  checked={showGrid}
                  onClick={() => setShowGrid(!showGrid)}
                >
                  Grid
                </Button.Checkbox>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item grow basis={0} minHeight={0}>
            <Stack fill>
              <Stack.Item grow minWidth={0} minHeight={0}>
                <Box
                  height="100%"
                  backgroundColor="rgba(0, 0, 0, 0.2)"
                  p={1}
                  style={{ overflow: 'hidden', boxSizing: 'border-box' }}
                >
                  <SpriteEditor.Canvas
                    data={editorData.sprite}
                    width="100%"
                    height="100%"
                    showGrid={showGrid}
                    drawBounds={drawBounds[direction] ?? [0, 0, -1, -1]}
                    background={
                      showGuide && guides[direction]
                        ? `url("${guides[direction]}")`
                        : undefined
                    }
                  />
                </Box>
              </Stack.Item>
              <Stack.Item width="15rem">
                <Stack vertical>
                  <Stack.Item>
                    <SpriteEditor.Palette
                      serverPalette={editorData.serverPalette}
                      readOnly
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Section title="Drawing tint">
                      <Button fluid onClick={() => act('pickTint')}>
                        <ColorBox color={tint ?? '#ffffff'} mr={1} />
                        {tint ?? 'Choose a tint'}
                      </Button>
                      <Button
                        fluid
                        mt={0.5}
                        selected={!tint}
                        onClick={() => act('resetTint')}
                      >
                        {target === 'hair'
                          ? 'Follow hair colour'
                          : 'Use original shades'}
                      </Button>
                    </Section>
                  </Stack.Item>
                  <Stack.Item>
                    <Section title="Preview">
                      <Box textAlign="center">
                        {previews[direction] && (
                          <img
                            src={previews[direction]}
                            alt="Character with your drawing"
                            width={128}
                            height={128}
                            style={{ imageRendering: 'pixelated' }}
                          />
                        )}
                      </Box>
                    </Section>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      fluid
                      color="bad"
                      icon="eraser"
                      onClick={() => act('clear', { dir: String(direction) })}
                    >
                      Clear this direction
                    </Button>
                  </Stack.Item>
                  {!!unsupportedZones.length && (
                    <Stack.Item color="label">
                      Taur legs do not display custom markings. Unavailable
                      canvas rows are shaded.
                    </Stack.Item>
                  )}
                </Stack>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item color="label">
            Ctrl+Z: undo · Ctrl+Y / Ctrl+Shift+Z: redo. Shaded areas cannot be
            painted.
          </Stack.Item>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item grow color="label">
                Closing saves your drawing to this character slot.
              </Stack.Item>
              <Stack.Item>
                <Button onClick={() => act('discard')}>Discard</Button>
              </Stack.Item>
              <Stack.Item>
                <Button color="good" onClick={() => act('save')}>
                  Save and close
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
