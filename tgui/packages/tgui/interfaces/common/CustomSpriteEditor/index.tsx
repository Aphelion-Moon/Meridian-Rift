// THIS IS AN APHELION UI FILE
import { useAtom, useSetAtom } from 'jotai';
import { useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { Window } from 'tgui/layouts';
import { Box, Button, Collapsible, Section, Stack } from 'tgui-core/components';
import { SpriteEditor } from '../SpriteEditor';
import {
  currentToolAtom,
  dirAtom,
  layerAtom,
  previewDataAtom,
  previewLayerAtom,
  selectionBoundsAtom,
  tools,
} from '../SpriteEditor/atoms';
import { Dir } from '../SpriteEditor/Types/types';
import { CustomSpritePalette } from './Palette';
import type { CustomSpriteEditorData } from './types';

const directions = [
  [Dir.SOUTH, 'Front'],
  [Dir.NORTH, 'Back'],
  [Dir.EAST, 'Right'],
  [Dir.WEST, 'Left'],
] as const;

const blendingTooltip =
  'Uses Multiply blending on Custom colors for new strokes.';

export const CustomSpriteEditor = ({
  target,
}: {
  target: 'hair' | 'markings';
}) => {
  const { data, act } = useBackend<CustomSpriteEditorData>();
  const {
    bodyZoneLabel,
    editorData,
    colorMode,
    emissive,
    emissiveAllowed,
    saveRevision,
    saveError,
    customTint,
    displayTint,
    customPalette,
    availableColors,
    maxCustomColors,
    guides,
    previews,
    edited,
    drawBounds,
    drawMask,
    unsupportedZones,
  } = data;
  const [direction, setDirection] = useAtom(dirAtom);
  const setLayer = useSetAtom(layerAtom);
  const setCurrentTool = useSetAtom(currentToolAtom);
  const setPreviewData = useSetAtom(previewDataAtom);
  const setPreviewLayer = useSetAtom(previewLayerAtom);
  const setSelectionBounds = useSetAtom(selectionBoundsAtom);
  const [showGuide, setShowGuide] = useState(true);
  const guideUrl = showGuide ? guides[direction] : undefined;
  const [loadedGuide, setLoadedGuide] = useState<{
    url: string;
    image: HTMLImageElement;
  }>();
  const [showGrid, setShowGrid] = useState(false);
  const [saved, setSaved] = useState(false);
  const lastSaveRevision = useRef(saveRevision);
  const paletteTint = colorMode === 'literal' ? null : displayTint;
  SpriteEditor.syncBackend('selectColor', editorData.serverSelectedColor);
  useEffect(() => {
    if (!guideUrl || loadedGuide?.url === guideUrl) return;
    const image = new Image();
    image.onload = () => setLoadedGuide({ url: guideUrl, image });
    image.src = guideUrl;
    return () => {
      image.onload = null;
    };
  }, [guideUrl]);
  useEffect(() => {
    setLayer(0);
    setDirection(Dir.SOUTH);
    const cancelContext = {
      setPreviewLayer,
      setPreviewData,
      setSelectionBounds,
    };
    const resetTool = () => {
      setCurrentTool(tools[0], cancelContext);
      tools[0].cancel?.(cancelContext);
    };
    resetTool();
    return resetTool;
  }, []);
  useEffect(() => {
    if (saveError) setSaved(false);
  }, [saveError]);
  useEffect(() => {
    if (saveRevision === lastSaveRevision.current) {
      return;
    }
    lastSaveRevision.current = saveRevision;
    setSaved(saveRevision > 0);
    const timeout = setTimeout(() => setSaved(false), 2000);
    return () => clearTimeout(timeout);
  }, [saveRevision]);

  return (
    <Window
      width={900}
      height={780}
      title={
        target === 'hair'
          ? 'Custom Hair'
          : bodyZoneLabel
            ? `Custom ${bodyZoneLabel} markings`
            : 'Custom Markings'
      }
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
              </Stack.Item>
              <Stack.Item>
                <SpriteEditor.Redo stack={editorData.redoStack} />
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="bad"
                  icon="eraser"
                  onClick={() => act('clear', { dir: String(direction) })}
                >
                  Clear layer
                </Button>
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
                    onSave={() => act('saveDraft')}
                    onSampleBackdrop={(x, y) => {
                      if (showGuide) {
                        act('sampleGuide', { dir: String(direction), x, y });
                      }
                    }}
                    width="100%"
                    height="100%"
                    showGrid={showGrid}
                    drawBounds={drawBounds[direction] ?? [0, 0, -1, -1]}
                    drawMask={drawMask?.[direction]}
                    backgroundImage={
                      loadedGuide?.url === guideUrl
                        ? loadedGuide?.image
                        : undefined
                    }
                  />
                </Box>
              </Stack.Item>
              <Stack.Item width="15rem" overflowY="auto">
                <Stack vertical>
                  <Stack.Item>
                    <CustomSpritePalette
                      serverPalette={editorData.serverPalette}
                      customPalette={customPalette}
                      availableColors={availableColors}
                      maxCustomColors={maxCustomColors}
                      displayTint={paletteTint}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Section>
                      <Button.Checkbox
                        fluid
                        mb={1}
                        checked={emissive[direction]}
                        disabled={!emissiveAllowed}
                        tooltip={
                          !emissiveAllowed
                            ? 'Enable emissive appearance in character preferences.'
                            : 'Makes this direction glow in the dark.'
                        }
                        onClick={() =>
                          act('setEmissive', {
                            dir: String(direction),
                            enabled: !emissive[direction],
                          })
                        }
                      >
                        Emissive
                      </Button.Checkbox>
                      <Collapsible title="Color blending">
                        <Box color="label" mb={1}>
                          Blending affects Custom colors for new strokes.
                        </Box>
                        {target === 'hair' && (
                          <Button.Checkbox
                            fluid
                            checked={colorMode === 'hair'}
                            tooltip={blendingTooltip}
                            onClick={() =>
                              act('setColorMode', {
                                mode: colorMode === 'hair' ? 'literal' : 'hair',
                              })
                            }
                          >
                            Blend with hair color
                          </Button.Checkbox>
                        )}
                        <Stack align="center" mt={0.5}>
                          <Stack.Item grow>
                            <Button.Checkbox
                              fluid
                              checked={colorMode === 'tint'}
                              tooltip={blendingTooltip}
                              onClick={() =>
                                act('setColorMode', {
                                  mode:
                                    colorMode === 'tint' ? 'literal' : 'tint',
                                })
                              }
                            >
                              Blend with color
                            </Button.Checkbox>
                          </Stack.Item>
                          {colorMode === 'tint' && (
                            <Stack.Item>
                              <Button
                                className="SpriteEditor__plainSwatch"
                                width="2em"
                                height="2em"
                                aria-label="Choose blending color"
                                tooltip="Choose blending color"
                                onClick={() => act('pickTint')}
                                style={{
                                  backgroundImage: `linear-gradient(${customTint}, ${customTint})`,
                                }}
                              />
                            </Stack.Item>
                          )}
                        </Stack>
                      </Collapsible>
                    </Section>
                  </Stack.Item>
                  {!!unsupportedZones.length && (
                    <Stack.Item color="label">
                      Taur legs do not display custom markings. Unavailable
                      canvas rows are shaded.
                    </Stack.Item>
                  )}
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
                </Stack>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item color="label">
            Ctrl+S: save · Ctrl+Z: undo · Ctrl+Y / Ctrl+Shift+Z: redo. Shaded
            areas cannot be painted. Select: drag a box, then drag inside it to
            move. Escape: deselect.
          </Stack.Item>
          {!!saveError && (
            <Stack.Item color="bad">
              <div role="alert">{saveError}</div>
            </Stack.Item>
          )}
          <Stack.Item>
            <Stack align="center">
              <Stack.Item grow color="label">
                Closing saves your drawing to this character slot.
              </Stack.Item>
              <Stack.Item>
                <Box color="good">
                  <span role="status">{saved ? 'Saved' : null}</span>
                </Box>
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
