// THIS IS AN APHELION UI FILE
import { useAtom, useSetAtom } from 'jotai';
import { useEffect, useMemo, useRef, useState } from 'react';
import transparency_checkerboard from 'tgui/assets/transparency_checkerboard.svg';
import { useBackend } from 'tgui/backend';
import { Window } from 'tgui/layouts';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  Icon,
  Modal,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';
import { classes } from 'tgui-core/react';
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
import {
  toolHotkeys,
  toolTooltip,
} from '../SpriteEditor/useSpriteEditorHotkeys';
import { decodeCanvas } from './canvas';
import { CustomSpritePalette } from './Palette';
import { RegionOverlay } from './RegionOverlay';
import { coverPartAt, drawScanlines, regionAt, regionBounds } from './regions';
import type { CustomSpriteEditorData } from './types';

/** Steps through a list of options with wraparound, for the cycle arrows and rotate buttons. */
function cycleOption<T>(
  options: readonly T[] | null | undefined,
  current: T | null | undefined,
  step: number,
): T | null {
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
  disabled?: boolean;
}) {
  const { options, selected, onSelected, disabled } = props;
  const chevron = (step: number) => (
    <Stack.Item>
      <Button
        px={0.5}
        // A button is as tall as its line height, vertical padding being zero,
        // so this matches the 22px control height Dropdown sets for itself.
        lineHeight="22px"
        icon={step < 0 ? 'chevron-left' : 'chevron-right'}
        disabled={disabled || options.length <= 1}
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
          disabled={disabled}
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

/** Views in the order the character preview's clockwise rotation turns through them. */
const rotation = [Dir.SOUTH, Dir.WEST, Dir.NORTH, Dir.EAST];

const blendingTooltip = 'Uses Multiply blending on Custom colors.';
/** How long the cursor rests on covered paint before the tip names the part over it. */
const COVER_TIP_DELAY_MS = 400;

/** What the toolbar spreads onto each tool button; the hotkey rides along as a data attribute. */
type ToolButtonProps = ReturnType<
  NonNullable<Parameters<typeof SpriteEditor.Toolbar>[0]['perButtonProps']>
>;

/** Markings and tattoo window size, tall enough that the side panel doesn't scroll. */
const MARKINGS_WINDOW = [1100, 920] as const;
/** Wide enough that base marking names aren't cut short beside their buttons. */
const MARKINGS_PANEL_WIDTH = '26rem';

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
    canHideUnderwear,
    hideUnderwear,
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
    regions,
    regionZones,
    regionLabels,
    selectedZone: serverZone,
    focusRevision,
    regionMarkings,
    regionMarkingChoices,
    regionEmissive,
    lockedRegions,
    paletteNotice,
    backgrounds,
    defaultBackground,
    visibleView,
    coverMask,
    coverParts,
  } = data;
  const sprite = useMemo(
    () => decodeCanvas(editorData.sprite),
    [editorData.sprite],
  );
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
  const [background, setBackground] = useState(
    defaultBackground ?? 'Transparent',
  );
  const wide = sprite.width > 32;
  const tile = backgrounds?.find((entry) => entry.name === background);
  const tileUrl = tile ? (wide ? tile.wideUrl : tile.url) : null;
  const tileStyle = {
    backgroundImage: `url(${tileUrl ?? transparency_checkerboard})`,
  };
  const regionMode = target === 'markings' && !!regions;
  const zones = regionZones ?? [];
  const [selectedZone, setSelectedZone] = useState(serverZone ?? null);
  const [hoveredZone, setHoveredZone] = useState<string | null>(null);
  // The part hiding the paint under the cursor, shown as a tip once the cursor rests there.
  const [coverTip, setCoverTip] = useState<{
    x: number;
    y: number;
    label: string;
  } | null>(null);
  const coverTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const clearCoverTip = () => {
    if (coverTimer.current) {
      clearTimeout(coverTimer.current);
      coverTimer.current = null;
    }
    setCoverTip(null);
  };
  useEffect(() => clearCoverTip, []);
  useEffect(() => setSelectedZone(serverZone ?? null), [focusRevision]);
  const regionLabel = (selectedZone && regionLabels?.[selectedZone]) || '';
  // Regions the server won't change right now, each with the reason, such as clothing covering it.
  const lockReason = (zone?: string | null) =>
    (zone && lockedRegions?.[zone]) || null;
  const selectedLock = lockReason(selectedZone);
  // Base markings the selected region can take; regions without any, like a taur body, have no section.
  const regionChoices = selectedZone
    ? regionMarkingChoices?.[selectedZone]
    : undefined;
  const viewLabel =
    directions.find(([dir]) => dir === direction)?.[1] ?? 'Front';
  const regionRows = regions?.[direction];
  const selectedInView = !!regionBounds(regionRows, zones, selectedZone);
  const selectZone = (zone: string | null) => {
    if (!regionMode || !zone || zone === selectedZone || lockReason(zone))
      return;
    setSelectedZone(zone);
    act('selectRegion', { zone });
  };
  const selectRegionAt = (x: number, y: number) =>
    selectZone(regionAt(regionRows, zones, x, y));
  // The last region a drag crossed, so a drag released off the body still ends up somewhere sensible.
  const dragZone = useRef<string | null>(null);
  const pixelAt = (event: React.MouseEvent<HTMLDivElement>) => {
    const canvas = event.currentTarget.querySelector('canvas');
    if (!canvas) return null;
    const rect = canvas.getBoundingClientRect();
    const { width, height } = sprite;
    return [
      Math.floor(((event.clientX - rect.left) / rect.width) * width),
      Math.floor(((event.clientY - rect.top) / rect.height) * height),
    ] as const;
  };
  // A drag selects the region it is released over; released off the body, the last region it crossed.
  const selectRegionAtRelease = (event: React.MouseEvent<HTMLDivElement>) => {
    const last = dragZone.current;
    dragZone.current = null;
    if (!regionMode || event.button !== 0) return;
    const at = pixelAt(event);
    if (!at) return;
    const zone = regionAt(regionRows, zones, at[0], at[1]);
    selectZone(zone && !lockReason(zone) ? zone : last);
  };
  const trackHover = (event: React.MouseEvent<HTMLDivElement>) => {
    if (!regionMode) return;
    const at = pixelAt(event);
    if (!at) return;
    const [px, py] = at;
    const zone = regionAt(regionRows, zones, px, py);
    // Locked regions can't be picked, so they don't light up either.
    const hovered = lockReason(zone) ? null : zone;
    if (hovered !== hoveredZone) setHoveredZone(hovered);
    if (event.buttons && hovered) dragZone.current = hovered;
    // Only painted, covered pixels get the tip: the same pixels the overlay hatches. It waits for
    // the cursor to rest, so flicking across paint mid-stroke never puts anything in the way.
    const pixel = sprite.layers[0]?.data[direction]?.[py]?.[px];
    const label =
      pixel && !pixel.endsWith('00') && !event.buttons
        ? coverPartAt(coverMask?.[direction], coverParts, px, py)
        : null;
    if (!label) {
      clearCoverTip();
      return;
    }
    const box = event.currentTarget.getBoundingClientRect();
    const tip = {
      x: event.clientX - box.left + 14,
      y: event.clientY - box.top + 14,
      label,
    };
    if (coverTip?.label === label) {
      setCoverTip(tip);
      return;
    }
    clearCoverTip();
    coverTimer.current = setTimeout(() => {
      coverTimer.current = null;
      setCoverTip(tip);
    }, COVER_TIP_DELAY_MS);
  };
  const lastSaveRevision = useRef(saveRevision);
  const nextDrawingActivity = useRef(0);
  const paletteTint = colorMode === 'literal' ? null : displayTint;
  const takenMarkings = new Set(
    (baseMarkings ?? []).map((entry) => entry.name),
  );
  const salon = context === 'salon';
  const locked = (dir: Dir) => !!lockedDirections?.includes(String(dir));
  const rotate = (step: number) =>
    setDirection(cycleOption(rotation, direction, step) ?? direction);
  const savedLabel = salon ? 'Draft saved for this round' : 'Saved';
  const hairTarget = target === 'hair' || target === 'facial_hair';
  // Markings and tattoos stack base markings above the palette and preview, so they get more room.
  const markingsWindow = target === 'markings';
  const drawingName =
    target === 'hair'
      ? 'Custom Hair'
      : target === 'facial_hair'
        ? 'Custom Facial Hair'
        : bodyZoneLabel
          ? `Custom ${bodyZoneLabel} markings`
          : salon
            ? 'Custom Tattoo'
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
  // A reused window's view atom keeps its last view until the effect below resets it.
  const [viewReset, setViewReset] = useState(false);
  useEffect(() => {
    // The server draws guides and previews only for the view the window says it shows.
    if (
      viewReset &&
      visibleView !== undefined &&
      visibleView !== String(direction)
    ) {
      act('setView', { dir: String(direction) });
    }
  }, [direction, visibleView, viewReset]);
  useEffect(() => {
    setLayer(0);
    setDirection(Dir.SOUTH);
    setViewReset(true);
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
      width={markingsWindow ? MARKINGS_WINDOW[0] : 1000}
      height={markingsWindow ? MARKINGS_WINDOW[1] : 780}
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
                {candidate.regions?.length
                  ? `Replaces: ${candidate.regions.join(', ')}. `
                  : ''}
                {candidate.skipped?.length
                  ? `Skipped: ${candidate.skipped.join(', ')}. `
                  : ''}
                This replaces the current draft. You can undo it.
              </Box>
              <Stack justify="space-around" mb={1}>
                {directions.map(([dir, label]) => (
                  <Stack.Item
                    key={dir}
                    grow
                    basis={0}
                    minWidth={0}
                    textAlign="center"
                  >
                    {!!candidate.previews[dir] && (
                      <Box
                        inline
                        className="CustomSpriteEditor__tile"
                        style={tileStyle}
                      >
                        <img
                          src={candidate.previews[dir]}
                          alt={`${label} preview`}
                          width={96}
                          style={{
                            height: 'auto',
                            imageRendering: 'pixelated',
                          }}
                        />
                      </Box>
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
            <Stack align="center">
              <Stack.Item>
                <div className="CustomSpriteEditor__group">
                  {directions.map(([dir, label]) => {
                    const painted = !!edited[dir];
                    const pipLabel = painted
                      ? 'Has markings'
                      : 'No markings yet';
                    const pip = (
                      <span
                        className={classes([
                          'CustomSpriteEditor__pip',
                          painted && 'CustomSpriteEditor__pip--lit',
                        ])}
                        role="img"
                        aria-label={pipLabel}
                      />
                    );
                    return (
                      <Button
                        key={dir}
                        className="CustomSpriteEditor__viewTab"
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
                        {locked(dir) ? (
                          pip
                        ) : (
                          <Tooltip content={pipLabel}>{pip}</Tooltip>
                        )}
                      </Button>
                    );
                  })}
                </div>
              </Stack.Item>
              {regionMode && !!regionLabel && (
                <Stack.Item>
                  <Tooltip
                    content="Use any tool on a region to select it."
                    position="bottom-start"
                  >
                    <span className="CustomSpriteEditor__region">
                      <Icon name="bullseye" />
                      <b>{regionLabel}</b>
                      {!selectedInView && selectedZone ? (
                        <span className="CustomSpriteEditor__regionOff">
                          (not in this view)
                        </span>
                      ) : null}
                    </span>
                  </Tooltip>
                </Stack.Item>
              )}
              <Stack.Item grow />
              <Stack.Item>
                <div className="CustomSpriteEditor__tray">
                  <Button
                    color="transparent"
                    selected={showGuide}
                    aria-pressed={showGuide}
                    icon="user"
                    tooltip="Show the body behind your paint."
                    onClick={() => setShowGuide(!showGuide)}
                  >
                    Guide
                  </Button>
                  {!!canHideParts && (
                    <Button
                      color="transparent"
                      selected={!hideParts}
                      aria-pressed={!hideParts}
                      icon="paw"
                      tooltip="Show hair, wings, tails and other parts that cover the body in the guide. The preview always shows them."
                      onClick={() => act('toggleParts')}
                    >
                      Parts
                    </Button>
                  )}
                  {!!canHideUnderwear && (
                    <Button
                      color="transparent"
                      selected={!hideUnderwear}
                      aria-pressed={!hideUnderwear}
                      icon="shirt"
                      tooltip="Show underwear in the guide and the preview."
                      onClick={() => act('toggleUnderwear')}
                    >
                      Underwear
                    </Button>
                  )}
                  {!!hasGradient && (
                    <Button
                      color="transparent"
                      selected={!!showGradient}
                      aria-pressed={!!showGradient}
                      icon="palette"
                      tooltip="Show the base look's gradient in the guide, preview and palette."
                      onClick={() => act('toggleGradient')}
                    >
                      Gradient
                    </Button>
                  )}
                  <Button
                    color="transparent"
                    selected={showGrid}
                    aria-pressed={showGrid}
                    icon="border-all"
                    tooltip="Pixel grid over the canvas."
                    onClick={() => setShowGrid(!showGrid)}
                  >
                    Grid
                  </Button>
                </div>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item>
                <SpriteEditor.Toolbar
                  className="CustomSpriteEditor__group"
                  toolFlags={editorData.toolFlags}
                  perButtonProps={(tool) =>
                    ({
                      tooltip: toolTooltip(
                        tool,
                        tool === tools[2]
                          ? 'Alt+click with any tool'
                          : undefined,
                      ),
                      'data-hotkey': toolHotkeys[tool.name]?.toUpperCase(),
                    }) as ToolButtonProps
                  }
                />
              </Stack.Item>
              <Stack.Item className="CustomSpriteEditor__divider" />
              <Stack.Item>
                <SpriteEditor.Undo stack={editorData.undoStack} />
              </Stack.Item>
              <Stack.Item>
                <SpriteEditor.Redo stack={editorData.redoStack} />
              </Stack.Item>
              <Stack.Item className="CustomSpriteEditor__divider" />
              <Stack.Item>
                <Button
                  className="CustomSpriteEditor__clear"
                  icon="broom"
                  disabled={regionMode && (!selectedZone || !!selectedLock)}
                  tooltip={
                    !regionMode
                      ? 'Erase this view. Undo brings it back.'
                      : regionLabel
                        ? `Erase all ${regionLabel.toLowerCase()} paint in this view. Undo brings it back.`
                        : 'Choose a region to clear.'
                  }
                  onClick={() =>
                    regionMode
                      ? act('clear', {
                          dir: String(direction),
                          zone: selectedZone,
                        })
                      : act('clear', { dir: String(direction) })
                  }
                >
                  {!regionMode
                    ? 'Clear layer'
                    : regionLabel
                      ? `Clear ${regionLabel.toLowerCase()}`
                      : 'Clear region'}
                </Button>
              </Stack.Item>
              <Stack.Item grow />
              <Stack.Item>
                <div className="CustomSpriteEditor__group">
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
                </div>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item grow basis={0} minHeight={0}>
            <Stack fill>
              <Stack.Item grow minWidth={0} minHeight={0}>
                <Stack vertical fill>
                  <Stack.Item grow minHeight={0}>
                    <Box
                      className="CustomSpriteEditor__canvas"
                      height="100%"
                      backgroundColor="rgba(0, 0, 0, 0.2)"
                      p={1}
                      style={{ overflow: 'hidden', boxSizing: 'border-box' }}
                      onMouseDown={() => {
                        dragZone.current = null;
                      }}
                      onMouseMove={trackHover}
                      onMouseUp={selectRegionAtRelease}
                      onMouseLeave={() => {
                        setHoveredZone(null);
                        clearCoverTip();
                      }}
                    >
                      <SpriteEditor.Canvas
                        data={sprite}
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
                            act('sampleGuide', {
                              dir: String(direction),
                              x,
                              y,
                            });
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
                        background={tileUrl ? `url(${tileUrl})` : undefined}
                        shade={drawScanlines}
                        onPointerDown={selectRegionAt}
                        overlay={
                          regionMode
                            ? (canvasWidth, canvasHeight) => (
                                <RegionOverlay
                                  rows={regionRows}
                                  zones={zones}
                                  imageWidth={sprite.width}
                                  canvasWidth={canvasWidth}
                                  canvasHeight={canvasHeight}
                                  selected={selectedZone}
                                  hovered={hoveredZone}
                                  labels={regionLabels ?? {}}
                                  cover={coverMask?.[direction]}
                                  frame={sprite.layers[0]?.data[direction]}
                                />
                              )
                            : undefined
                        }
                      />
                      {!!coverTip && (
                        <div
                          className="CustomSpriteEditor__coverTip"
                          style={{ left: coverTip.x, top: coverTip.y }}
                        >
                          Hidden by {coverTip.label}
                        </div>
                      )}
                    </Box>
                  </Stack.Item>
                  {regionMode && !!selectedLock && (
                    <Stack.Item className="CustomSpriteEditor__status">
                      <Box color="average">{selectedLock}</Box>
                    </Stack.Item>
                  )}
                </Stack>
              </Stack.Item>
              <Stack.Item
                width={markingsWindow ? MARKINGS_PANEL_WIDTH : '18rem'}
                overflowY="auto"
              >
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
                  {regionMode && !!selectedZone && !!regionChoices && (
                    <Stack.Item>
                      <Section
                        title={
                          <Tooltip
                            content="Use any tool on a region to select it."
                            position="bottom-start"
                          >
                            <span>{`${regionLabel} base markings`}</span>
                          </Tooltip>
                        }
                      >
                        {(regionMarkings?.[selectedZone] ?? []).map(
                          (marking) => {
                            const taken = new Set(
                              (regionMarkings?.[selectedZone] ?? []).map(
                                (entry) => entry.name,
                              ),
                            );
                            const choices = regionChoices.filter(
                              (name) =>
                                name === marking.name || !taken.has(name),
                            );
                            return (
                              <Stack
                                key={marking.index}
                                mb={0.5}
                                align="center"
                              >
                                <Stack.Item grow style={{ minWidth: 0 }}>
                                  <CycleDropdown
                                    options={choices}
                                    disabled={!!selectedLock}
                                    selected={marking.name}
                                    onSelected={(name) =>
                                      act('setBaseMarking', {
                                        zone: selectedZone,
                                        index: marking.index,
                                        name,
                                      })
                                    }
                                  />
                                </Stack.Item>
                                <Stack.Item>
                                  <Button
                                    disabled={!!selectedLock}
                                    tooltip={`Color of ${marking.name}`}
                                    onClick={() =>
                                      act('pickBaseMarkingColor', {
                                        zone: selectedZone,
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
                                    disabled={!!selectedLock}
                                    color="bad"
                                    tooltip={`Remove ${marking.name}`}
                                    onClick={() =>
                                      act('removeBaseMarking', {
                                        zone: selectedZone,
                                        index: marking.index,
                                      })
                                    }
                                  />
                                </Stack.Item>
                              </Stack>
                            );
                          },
                        )}
                        {(regionMarkings?.[selectedZone]?.length ?? 0) <
                          (maxBaseMarkings ?? 0) && (
                          <Button
                            color="good"
                            disabled={!!selectedLock}
                            onClick={() =>
                              act('addBaseMarking', {
                                zone: selectedZone,
                              })
                            }
                          >
                            +
                          </Button>
                        )}
                      </Section>
                    </Stack.Item>
                  )}
                  {!!canChangeMarkings && (
                    <Stack.Item>
                      <Section title="Base markings">
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
                        {(baseMarkings?.length ?? 0) <
                          (maxBaseMarkings ?? 0) && (
                          <Button
                            color="good"
                            onClick={() => act('addBaseMarking')}
                          >
                            +
                          </Button>
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
                      checked={
                        regionMode
                          ? !!(
                              selectedZone &&
                              regionEmissive?.[selectedZone]?.[direction]
                            )
                          : emissive[direction]
                      }
                      disabled={
                        !emissiveAllowed ||
                        (regionMode && (!selectedZone || !!selectedLock))
                      }
                      tooltip={
                        !emissiveAllowed
                          ? 'Enable emissive appearance in character preferences.'
                          : 'Makes this direction glow in the dark.'
                      }
                      onClick={() =>
                        regionMode
                          ? act('setEmissive', {
                              zone: selectedZone,
                              dir: String(direction),
                              enabled:
                                !regionEmissive?.[selectedZone!]?.[direction],
                            })
                          : act('setEmissive', {
                              dir: String(direction),
                              enabled: !emissive[direction],
                            })
                      }
                    >
                      {regionMode
                        ? `Emissives - (${regionLabel}, ${viewLabel})`
                        : 'Emissive'}
                    </Button.Checkbox>
                  </Stack.Item>
                  <Stack.Item>
                    <Section title="Preview">
                      <Box textAlign="center">
                        {previews[direction] && (
                          <Box
                            inline
                            className="CustomSpriteEditor__tile"
                            style={tileStyle}
                          >
                            <img
                              src={previews[direction]}
                              alt="Character with your drawing"
                              width={128}
                              style={{
                                height: 'auto',
                                imageRendering: 'pixelated',
                              }}
                            />
                          </Box>
                        )}
                        {!!backgrounds?.length && (
                          <Stack
                            justify="center"
                            wrap
                            mt={1}
                            className="CustomSpriteEditor__swatches"
                          >
                            {[
                              { name: 'Transparent', url: '' },
                              ...backgrounds,
                            ].map((entry) => (
                              <Stack.Item key={entry.name}>
                                <Button
                                  className="SpriteEditor__plainSwatch CustomSpriteEditor__backgroundSwatch"
                                  width="24px"
                                  height="24px"
                                  aria-label={entry.name}
                                  aria-pressed={background === entry.name}
                                  tooltip={entry.name}
                                  onClick={() => setBackground(entry.name)}
                                  style={{
                                    backgroundImage: `url(${entry.url || transparency_checkerboard})`,
                                  }}
                                />
                              </Stack.Item>
                            ))}
                          </Stack>
                        )}
                        <Box mt={1}>
                          <Button
                            fontSize="22px"
                            icon="redo"
                            tooltip="Rotate Clockwise"
                            tooltipPosition="bottom"
                            onClick={() => rotate(1)}
                          />
                          <Button
                            fontSize="22px"
                            icon="undo"
                            tooltip="Rotate Counter-Clockwise"
                            tooltipPosition="bottom"
                            onClick={() => rotate(-1)}
                          />
                        </Box>
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
          {!!paletteNotice && (
            <Stack.Item color="average">{paletteNotice}</Stack.Item>
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
