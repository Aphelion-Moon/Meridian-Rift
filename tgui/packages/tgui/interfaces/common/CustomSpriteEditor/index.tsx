// THIS IS AN APHELION UI FILE
import { useAtom, useSetAtom } from 'jotai';
import { useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { Window } from 'tgui/layouts';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  Modal,
  Section,
  Stack,
} from 'tgui-core/components';
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
import { toolTooltip } from '../SpriteEditor/useSpriteEditorHotkeys';
import { CustomSpritePalette } from './Palette';
import type { CustomSpriteEditorData } from './types';

/** Steps through a list of options with wraparound, for the cycle arrows. */
function cycleOption(
  options: readonly string[] | null | undefined,
  current: string | null | undefined,
  step: number,
): string | null {
  if (!options?.length) return null;
  const index = current == null ? -1 : options.indexOf(current);
  // Anything not in the list steps in from whichever end the arrow points at.
  if (index < 0) return step > 0 ? options[0] : options[options.length - 1];
  return options[(index + step + options.length) % options.length];
}

/** Dropdown with thin chevrons either side that step it along without opening it. */
function CycleDropdown(props: {
  options: string[];
  selected: string | null | undefined;
  onSelected: (value: string) => void;
}) {
  const { options, selected, onSelected } = props;
  const chevron = (step: number) => (
    <Stack.Item>
      <Button
        px={0.5}
        // A button is as tall as its line height, vertical padding being zero,
        // so this matches the 22px control height Dropdown sets for itself.
        lineHeight="22px"
        icon={step < 0 ? 'chevron-left' : 'chevron-right'}
        disabled={options.length <= 1}
        onClick={() => {
          const next = cycleOption(options, selected, step);
          if (next && next !== selected) onSelected(next);
        }}
      />
    </Stack.Item>
  );
  return (
    <Stack align="center">
      {chevron(-1)}
      <Stack.Item grow style={{ minWidth: 0 }}>
        <Dropdown
          width="100%"
          options={options}
          menuWidth="max-content"
          selected={selected ?? undefined}
          displayText={selected ?? undefined}
          searchInput
          maxItems={8}
          onSelected={onSelected}
        />
      </Stack.Item>
      {chevron(1)}
    </Stack>
  );
}

const directions = [
  [Dir.SOUTH, 'Front'],
  [Dir.NORTH, 'Back'],
  [Dir.EAST, 'Right'],
  [Dir.WEST, 'Left'],
] as const;

const blendingTooltip = 'Uses Multiply blending on Custom colors.';

export const CustomSpriteEditor = ({
  target,
}: {
  target: 'hair' | 'facial_hair' | 'markings';
}) => {
  const { data, act } = useBackend<CustomSpriteEditorData>();
  const {
    context = 'preferences',
    candidate,
    transferError,
    transferNotice,
    canRestorePrevious,
    canChangeHair,
    hasGradient,
    showGradient,
    canHideParts,
    hideParts,
    canChangeMarkings,
    baseMarkings,
    baseMarkingChoices,
    maxBaseMarkings,
    lockedDirections,
    hairStyle,
    hairStyles,
    hairColor,
    recipientName,
    selfWork,
    salonState,
    resourcesReady = true,
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
  const nextDrawingActivity = useRef(0);
  const paletteTint = colorMode === 'literal' ? null : displayTint;
  const takenMarkings = new Set(
    (baseMarkings ?? []).map((entry) => entry.name),
  );
  const salon = context === 'salon';
  const locked = (dir: Dir) => !!lockedDirections?.includes(String(dir));
  const savedLabel = salon ? 'Draft saved for this round' : 'Saved';
  const hairTarget = target === 'hair' || target === 'facial_hair';
  const drawingName =
    target === 'hair'
      ? 'Custom Hair'
      : target === 'facial_hair'
        ? 'Custom Facial Hair'
        : bodyZoneLabel
          ? `Custom ${bodyZoneLabel} ${salon ? 'tattoo' : 'markings'}`
          : 'Custom Markings';
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
      width={1000}
      height={780}
      title={salon ? `${drawingName} for ${recipientName}` : drawingName}
    >
      <Window.Content>
        {!!candidate && (
          <Modal width="30rem">
            <Section
              title={
                candidate.source === 'restore'
                  ? 'Restore previous saved style?'
                  : 'Import this style?'
              }
            >
              <Box color="label" mb={1}>
                {candidate.summary ? `Base hair: ${candidate.summary}. ` : ''}
                This replaces the current draft. You can undo it.
              </Box>
              <Stack justify="space-around" mb={1}>
                {directions.map(([dir, label]) => (
                  <Stack.Item key={dir} textAlign="center">
                    {!!candidate.previews[dir] && (
                      <img
                        src={candidate.previews[dir]}
                        alt={`${label} preview`}
                        width={96}
                        style={{ height: 'auto', imageRendering: 'pixelated' }}
                      />
                    )}
                    <Box color="label">{label}</Box>
                  </Stack.Item>
                ))}
              </Stack>
              <Stack justify="flex-end">
                <Stack.Item>
                  <Button onClick={() => act('cancelCandidate')}>Cancel</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button color="good" onClick={() => act('confirmCandidate')}>
                    Replace draft
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Modal>
        )}
        <Stack fill vertical>
          <Stack.Item>
            <Stack>
              {directions.map(([dir, label]) => (
                <Stack.Item key={dir} grow>
                  <Button
                    fluid
                    icon={locked(dir) ? 'lock' : undefined}
                    tooltip={
                      locked(dir)
                        ? 'You need a mirror to work on this view of your own body.'
                        : undefined
                    }
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
                  perButtonProps={(tool) => ({
                    tooltip: toolTooltip(
                      tool,
                      tool === tools[2] ? 'Alt+click with any tool' : undefined,
                    ),
                  })}
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
                <Button
                  icon="file-import"
                  tooltip="Preview a style file before replacing this draft."
                  onClick={() => act('importStyle')}
                >
                  Import
                </Button>
                <Button
                  icon="file-export"
                  tooltip="Download the current draft without saving it."
                  onClick={() => act('exportStyle')}
                >
                  Export
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button.Checkbox
                  checked={showGuide}
                  onClick={() => setShowGuide(!showGuide)}
                >
                  Guide
                </Button.Checkbox>
                {!!canHideParts && (
                  <Button.Checkbox
                    checked={!!hideParts}
                    tooltip="Move parts that would obstruct view out of the way."
                    onClick={() => act('toggleParts')}
                  >
                    Hide parts
                  </Button.Checkbox>
                )}
                {!!hasGradient && (
                  <Button.Checkbox
                    checked={!!showGradient}
                    tooltip="Show the base look's gradient in the guide, preview and palette."
                    onClick={() => act('toggleGradient')}
                  >
                    Gradient
                  </Button.Checkbox>
                )}
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
                  className="CustomSpriteEditor__canvas"
                  height="100%"
                  backgroundColor="rgba(0, 0, 0, 0.2)"
                  p={1}
                  style={{ overflow: 'hidden', boxSizing: 'border-box' }}
                >
                  <SpriteEditor.Canvas
                    data={editorData.sprite}
                    onSave={() => act('saveDraft')}
                    onDraw={
                      salon
                        ? (x, y, erasing = false) => {
                            const now = Date.now();
                            if (now < nextDrawingActivity.current) return;
                            nextDrawingActivity.current = now + 1000;
                            act('drawing', {
                              dir: String(direction),
                              x,
                              y,
                              erasing,
                            });
                          }
                        : undefined
                    }
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
              <Stack.Item width="18rem" overflowY="auto">
                <Stack vertical>
                  {!!canChangeHair && (
                    <Stack.Item>
                      <Section
                        title={
                          target === 'facial_hair'
                            ? 'Base facial hair'
                            : 'Base hair'
                        }
                      >
                        <Stack fill vertical>
                          <Stack.Item>
                            <CycleDropdown
                              options={hairStyles ?? []}
                              selected={hairStyle}
                              onSelected={(style) =>
                                act('setHairStyle', { style })
                              }
                            />
                          </Stack.Item>
                          <Stack.Item>
                            <Button
                              fluid
                              tooltip="Recoloring moves painted hair shades to the matching new shade."
                              onClick={() => act('pickHairColor')}
                            >
                              Hair color
                              <Box
                                inline
                                ml={1}
                                width="1rem"
                                height="0.8rem"
                                backgroundColor={hairColor ?? '#000000'}
                              />
                            </Button>
                          </Stack.Item>
                        </Stack>
                      </Section>
                    </Stack.Item>
                  )}
                  {!!canChangeMarkings && (
                    <Stack.Item>
                      <Section
                        title="Base markings"
                        buttons={
                          <Button
                            icon="plus"
                            disabled={
                              (baseMarkings?.length ?? 0) >=
                              (maxBaseMarkings ?? 0)
                            }
                            onClick={() => act('addBaseMarking')}
                          />
                        }
                      >
                        {(baseMarkings ?? []).map((marking) => {
                          // A limb takes each marking once, so a row offers only names no other row has claimed.
                          const choices = (baseMarkingChoices ?? []).filter(
                            (name) =>
                              name === marking.name || !takenMarkings.has(name),
                          );
                          return (
                            <Stack key={marking.index} mb={0.5} align="center">
                              <Stack.Item grow style={{ minWidth: 0 }}>
                                <CycleDropdown
                                  options={choices}
                                  selected={marking.name}
                                  onSelected={(name) =>
                                    act('setBaseMarking', {
                                      index: marking.index,
                                      name,
                                    })
                                  }
                                />
                              </Stack.Item>
                              <Stack.Item>
                                <Button
                                  tooltip={`Color of ${marking.name}`}
                                  onClick={() =>
                                    act('pickBaseMarkingColor', {
                                      index: marking.index,
                                    })
                                  }
                                >
                                  <Box
                                    inline
                                    width="1rem"
                                    height="0.8rem"
                                    backgroundColor={marking.color}
                                  />
                                </Button>
                              </Stack.Item>
                              <Stack.Item>
                                <Button
                                  icon="trash"
                                  color="bad"
                                  tooltip={`Remove ${marking.name}`}
                                  onClick={() =>
                                    act('removeBaseMarking', {
                                      index: marking.index,
                                    })
                                  }
                                />
                              </Stack.Item>
                            </Stack>
                          );
                        })}
                        {!baseMarkings?.length && (
                          <Box color="label">
                            This limb has no markings yet.
                          </Box>
                        )}
                      </Section>
                    </Stack.Item>
                  )}
                  <Stack.Item>
                    <CustomSpritePalette
                      blending={
                        <Collapsible title="Blending options">
                          {hairTarget && (
                            <Button.Checkbox
                              fluid
                              checked={colorMode === 'hair'}
                              tooltip={blendingTooltip}
                              onClick={() =>
                                act('setColorMode', {
                                  mode:
                                    colorMode === 'hair' ? 'literal' : 'hair',
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
                      }
                      serverPalette={editorData.serverPalette}
                      customPalette={customPalette}
                      availableColors={availableColors}
                      maxCustomColors={maxCustomColors}
                      displayTint={paletteTint}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button.Checkbox
                      fluid
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
                  </Stack.Item>
                  <Stack.Item>
                    <Section title="Preview">
                      <Box textAlign="center">
                        {previews[direction] && (
                          <img
                            src={previews[direction]}
                            alt="Character with your drawing"
                            width={128}
                            style={{
                              height: 'auto',
                              imageRendering: 'pixelated',
                            }}
                          />
                        )}
                      </Box>
                    </Section>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          {locked(direction) && (
            <Stack.Item color="average">
              You can&apos;t see this view of yourself. Hold a hand mirror, or
              stand next to a mirror, to work on it.
            </Stack.Item>
          )}
          {!resourcesReady && (
            <Stack.Item color="average">
              The preview isn&apos;t available right now. Your draft is kept,
              and you can still export it.
            </Stack.Item>
          )}
          {salon && salonState === 'awaiting approval' && (
            <Stack.Item color="average">
              Waiting for {recipientName} to approve the mirror preview. Any
              edit withdraws it.
            </Stack.Item>
          )}
          {!!saveError && (
            <Stack.Item color="bad">
              <div role="alert">{saveError}</div>
            </Stack.Item>
          )}
          {!!transferError && (
            <Stack.Item color="bad">
              <div role="alert">{transferError}</div>
            </Stack.Item>
          )}
          {!!transferNotice && !transferError && (
            <Stack.Item color="good">{transferNotice}</Stack.Item>
          )}
          <Stack.Item>
            <Stack align="center">
              <Stack.Item grow color="label">
                {salon && !selfWork
                  ? `Finish next to ${recipientName} with the tool in hand.`
                  : ''}
              </Stack.Item>
              <Stack.Item>
                <Box color="good">
                  <span role="status">{saved ? savedLabel : null}</span>
                </Box>
              </Stack.Item>
              {!!canRestorePrevious && (
                <Stack.Item>
                  <Button
                    tooltip="Preview the style this slot had before its last import, restoration or salon save."
                    onClick={() => act('restorePrevious')}
                  >
                    Restore previous saved style
                  </Button>
                </Stack.Item>
              )}
              <Stack.Item>
                {salon ? (
                  <Button.Confirm
                    confirmContent="Discard?"
                    onClick={() => act('discardDraft')}
                  >
                    Discard draft
                  </Button.Confirm>
                ) : (
                  <Button onClick={() => act('discard')}>Discard</Button>
                )}
              </Stack.Item>
              {salon && (
                <Stack.Item>
                  <Button onClick={() => act('closeEditor')}>Close</Button>
                </Stack.Item>
              )}
              <Stack.Item>
                <Button
                  color="good"
                  disabled={salon && salonState !== 'drafting'}
                  tooltip="Ctrl+S saves without closing."
                  onClick={() => act(salon ? 'finishWork' : 'save')}
                >
                  {salon ? 'Finish' : 'Save and close'}
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
