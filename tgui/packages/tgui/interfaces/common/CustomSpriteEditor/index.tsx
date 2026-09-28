// THIS IS AN APHELION UI FILE
import { useAtom, useAtomValue, useSetAtom } from 'jotai';
import {
  type ComponentProps,
  type CSSProperties,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
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
import {
  ChoicedSelectionDropdown,
  MARKING_PREVIEW_AREAS,
  type SpriteArea,
} from '../ChoicedSelection';
import { SpriteEditor } from '../SpriteEditor';
import {
  currentToolAtom,
  dirAtom,
  layerAtom,
  previewDataAtom,
  previewLayerAtom,
  selectionBoundsAtom,
  selectionMaskAtom,
  tools,
} from '../SpriteEditor/atoms';
import { useDimensions } from '../SpriteEditor/helpers';
import {
  MIRROR_SELECTION_KEY,
  mergedCopyAtom,
  ROTATE_SELECTION_KEY,
  receiveBaseCopy,
  SelectionTools,
  settleSelection,
} from '../SpriteEditor/selection';
import {
  Dir,
  type SpriteData,
  type SpriteDataLayer,
  type StringLayer,
} from '../SpriteEditor/Types/types';
import {
  toolHotkeys,
  toolTooltip,
} from '../SpriteEditor/useSpriteEditorHotkeys';
import { AppendagePanel } from './AppendagePanel';
import {
  type Appendage,
  drawOrder,
  expandHats,
  hatchedPixels,
  layerFate,
  type StackLayer,
  stackAround,
  type TryOnHat,
} from './appendages';
import {
  decodeAppendages,
  decodeCanvas,
  fitsMiddleHalf,
  pictureFitsMiddleHalf,
} from './canvas';
import { FinishingOverlay } from './FinishingOverlay';
import {
  composeBackground,
  composeWorn,
  hatChip,
  LayerOverlay,
  TryOn,
  useLoadedImages,
} from './LayerCanvas';
import { LayerStrip } from './LayerStrip';
import { CustomSpritePalette } from './Palette';
import { RegionOverlay } from './RegionOverlay';
import { coverIndexAt, drawScanlines, regionAt, regionBounds } from './regions';
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
  icons?: Record<string, string>;
  name?: string;
  previewArea?: SpriteArea;
}) {
  const { options, selected, onSelected, disabled, icons, name, previewArea } =
    props;
  const chevron = (step: number) => (
    <Stack.Item>
      <Button
        px={0.5}
        // A button is as tall as its line height, vertical padding being zero,
        // so this matches the 22px control height Dropdown sets for itself.
        lineHeight="22px"
        icon={step < 0 ? 'chevron-left' : 'chevron-right'}
        aria-label={`${step < 0 ? 'Previous' : 'Next'} ${name ?? 'hairstyle'}`}
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
      <Stack.Item grow minWidth={0}>
        {icons ? (
          <ChoicedSelectionDropdown
            name={name ?? 'hairstyle'}
            icons={icons}
            options={options}
            selected={selected ?? ''}
            onSelect={onSelected}
            disabled={disabled}
            previewArea={previewArea}
          />
        ) : (
          <Dropdown
            width="100%"
            disabled={disabled}
            options={options}
            menuWidth="max-content"
            selected={selected ?? undefined}
            displayText={selected ?? undefined}
            maxItems={8}
            onSelected={onSelected}
          />
        )}
      </Stack.Item>
      {chevron(1)}
    </Stack>
  );
}

/** A guide visibility control shares its pressed state with keyboard and screen-reader users. */
const GuideToggle = (props: ComponentProps<typeof Button>) => (
  <Button color="transparent" aria-pressed={!!props.selected} {...props} />
);

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

/** Room for the palette, blending controls, full preview and both rotation controls. */
const EDITOR_WINDOW = [1100, 920] as const;
/** Hair also fits its layer strip, the panel under the canvas and Try on, in every theme's frame. */
const HAIR_WINDOW = [1100, 960] as const;
/** A wide canvas (a taur's whole body) fits by its width, so it gets the width to grow into. */
const WIDE_WINDOW = [1400, 920] as const;
/** Shares palette rows across hair, markings and their salon editors. */
const EDITOR_PANEL_WIDTH = '26rem';
/** Hair's side panel is wider, so a wide (taur) body's preview has room to grow. */
const HAIR_PANEL_WIDTH = '30rem';

/**
 * The preview at the largest whole number that fits the room the side panel has left for it, which
 * it measures, so its pixels stay square and even. It stands on the chosen background tile. A wide
 * (taur) picture with nothing outside its middle half, as a front or back view is, shows just that
 * half, on the narrow tile.
 */
const FittedPicture = (props: {
  src: string;
  alt: string;
  tileStyle: CSSProperties;
  narrowTileStyle: CSSProperties;
}) => {
  const box = useRef<HTMLDivElement>(null);
  const [boxWidth, boxHeight] = useDimensions(box);
  const [natural, setNatural] = useState<[number, number]>();
  const [half, setHalf] = useState(false);
  const shownWidth = natural ? (half ? natural[0] / 2 : natural[0]) : 0;
  const scale =
    natural && boxWidth > 0 && boxHeight > 0
      ? Math.max(
          1,
          Math.floor(Math.min(boxWidth / shownWidth, boxHeight / natural[1])),
        )
      : 1;
  return (
    <div ref={box} className="CustomSpriteEditor__previewFit">
      <Box
        inline
        className={classes([
          'CustomSpriteEditor__tile',
          half && 'CustomSpriteEditor__tile--half',
        ])}
        style={
          half
            ? { ...props.narrowTileStyle, width: shownWidth * scale }
            : props.tileStyle
        }
      >
        <img
          src={props.src}
          alt={props.alt}
          width={natural ? natural[0] * scale : undefined}
          style={half ? { marginLeft: (-shownWidth * scale) / 2 } : undefined}
          onLoad={(event) => {
            const image = event.currentTarget;
            setNatural([image.naturalWidth, image.naturalHeight]);
            setHalf(pictureFitsMiddleHalf(image));
          }}
        />
      </Box>
    </div>
  );
};

const NO_APPENDAGES: Appendage[] = [];
const NO_HATS: Record<string, TryOnHat> = {};

/** A view of nothing, while an appendage's view is on its way from the server. */
const blankFrame = (width: number, height: number): StringLayer =>
  Array.from({ length: height }, () => Array(width).fill('#00000000'));

/** Both canvases turn the same view, through the same control. */
const ViewRotation = ({ onRotate }: { onRotate: (step: number) => void }) => (
  <span className="CustomSpriteEditor__turnButtons">
    <Button
      fontSize="22px"
      icon="redo"
      aria-label="Rotate Clockwise"
      tooltip="Rotate Clockwise"
      tooltipPosition="bottom"
      onClick={() => onRotate(1)}
    />
    <Button
      fontSize="22px"
      icon="undo"
      aria-label="Rotate Counter-Clockwise"
      tooltip="Rotate Counter-Clockwise"
      tooltipPosition="bottom"
      onClick={() => onRotate(-1)}
    />
  </span>
);

/** A small colour sample beside a button's label. */
const ColorChip = ({ color, ml }: { color: string; ml?: number }) => (
  <Box inline ml={ml} width="1rem" height="0.8rem" backgroundColor={color} />
);

/** One of the mutually exclusive blending modes: on when current, back to literal colours when pressed again. */
const BlendToggle = (props: {
  mode: 'hair' | 'mutant' | 'tint';
  current: string;
  label: string;
  act: ReturnType<typeof useBackend>['act'];
}) => (
  <Button.Checkbox
    fluid
    checked={props.current === props.mode}
    tooltip={blendingTooltip}
    onClick={() =>
      props.act('setColorMode', {
        mode: props.current === props.mode ? 'literal' : props.mode,
      })
    }
  >
    {props.label}
  </Button.Checkbox>
);

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
    maxBaseMarkings,
    lockedDirections,
    hairStyle,
    hairStyles,
    hairStyleIcons,
    hairColor,
    recipientName,
    selfWork,
    salonState,
    applyDuration,
    resourcesReady = true,
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
    regionMarkingIcons,
    regionEmissive,
    lockedRegions,
    paletteNotice,
    strokeNotice,
    backgrounds,
    defaultBackground,
    visibleView,
    coverMask,
    coverParts,
    coverWorn,
    appendages: serverAppendages,
    maxAppendages = 3,
    maxAppendageName = 20,
    tryOn,
    focusLayer,
    tryOnHats,
  } = data;
  const sprite = useMemo(
    () => ({
      ...decodeCanvas(editorData.sprite),
      baseCopyInfo:
        data.baseCopyInfo &&
        (target === 'markings' || data.baseCopyInfo.style === data.hairStyle) &&
        data.baseCopyInfo.height === editorData.sprite.height
          ? data.baseCopyInfo
          : undefined,
    }),
    [editorData.sprite, data.baseCopyInfo, data.hairStyle, target],
  );
  useEffect(() => {
    if (data.baseCopyResult) receiveBaseCopy(data.baseCopyResult);
  }, [data.baseCopyResult]);
  const [direction, setDirection] = useAtom(dirAtom);
  const setLayer = useSetAtom(layerAtom);
  const setMergedCopy = useSetAtom(mergedCopyAtom);
  const setCurrentTool = useSetAtom(currentToolAtom);
  const selecting = useAtomValue(currentToolAtom).name === 'Select';
  const selectionBounds = useAtomValue(selectionBoundsAtom);
  const setPreviewData = useSetAtom(previewDataAtom);
  const setPreviewLayer = useSetAtom(previewLayerAtom);
  const setSelectionBounds = useSetAtom(selectionBoundsAtom);
  const setSelectionMask = useSetAtom(selectionMaskAtom);
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
  // The tall hair canvas reaches above the tile the body stands on.
  const tall = sprite.height > 32;
  const tile = backgrounds?.find((entry) => entry.name === background);
  const tileUrl = tile
    ? wide
      ? tile.wideUrl
      : tall
        ? tile.tallUrl
        : tile.url
    : null;
  // Pictures stand on the plain tile, which repeats upward as far as they reach.
  const pictureTileUrl = tile ? (wide ? tile.wideUrl : tile.url) : null;
  const tileStyle = {
    backgroundImage: `url(${pictureTileUrl ?? transparency_checkerboard})`,
  };
  const narrowTileStyle = {
    backgroundImage: `url(${tile?.url ?? transparency_checkerboard})`,
  };
  // Hair is painted a layer at a time: the base hair, or one of its appendages.
  const layered = target === 'hair';
  const windowSize = layered ? HAIR_WINDOW : wide ? WIDE_WINDOW : EDITOR_WINDOW;
  const appendages = (layered && serverAppendages) || NO_APPENDAGES;
  const [layerId, setLayerId] = useState('hair');
  const chosen = appendages.find((entry) => entry.id === layerId) ?? null;
  const chosenId = chosen?.id ?? 'hair';
  useEffect(() => {
    if (focusLayer) setLayerId(focusLayer);
  }, [focusLayer]);
  const view = String(direction);
  // A taur's front and back only use the middle of its wide canvas, so those views fill the box with it.
  const halfView = useMemo(
    () =>
      !layered &&
      fitsMiddleHalf(sprite.layers[0]?.data[direction], drawMask?.[direction]),
    [layered, sprite, drawMask, direction],
  );
  const appendageFrames = useMemo(
    () => decodeAppendages(editorData.sprite),
    [editorData.sprite],
  );
  const stackLayers = useMemo<StackLayer[]>(
    () =>
      layered
        ? [
            {
              id: 'hair',
              appendage: null,
              frame: sprite.layers[0]?.data[direction],
            },
            ...appendages.map((appendage) => ({
              id: appendage.id,
              appendage,
              frame: appendageFrames[appendage.id]?.[view],
            })),
          ]
        : [],
    [layered, sprite, appendages, appendageFrames, direction],
  );
  const hats = useMemo(
    () => (layered && tryOnHats ? expandHats(tryOnHats) : NO_HATS),
    [layered, tryOnHats],
  );
  const [chosenHat, setChosenHat] = useState<string | null>(null);
  // The Base hair layer is always painted with no hat on.
  const wornKey = chosen && chosenHat && hats[chosenHat] ? chosenHat : null;
  const wornHat = wornKey ? hats[wornKey] : null;
  // Measured against what was last sent, not the server's echo, which can lag a quick change back.
  const sentTryOn = useRef(tryOn ?? null);
  useEffect(() => {
    if (!layered || sentTryOn.current === wornKey) return;
    sentTryOn.current = wornKey;
    act('setTryOn', { hat: wornKey });
  }, [wornKey]);
  const hatImages = useLoadedImages(
    Object.values(hats).flatMap((hat) => [
      hat.views[view],
      hat.views[Dir.SOUTH],
    ]),
  );
  const hatImage = wornHat ? hatImages[wornHat.views[view]] : undefined;
  // "Hats that cover it" chips, cropped here from each hat's front view.
  const chips = useMemo(
    () =>
      Object.fromEntries(
        Object.entries(hats).map(([key, hat]) => [
          key,
          hatChip(hatImages[hat.views[Dir.SOUTH]]),
        ]),
      ),
    [hats, hatImages],
  );
  const guideImage =
    loadedGuide?.url === guideUrl ? loadedGuide?.image : undefined;
  const stack = useMemo(
    () => (layered ? stackAround(stackLayers, chosenId, wornHat, view) : null),
    [layered, stackLayers, chosenId, wornHat, view],
  );
  const canvasBackground = useMemo(
    () =>
      stack?.below.length
        ? composeBackground(
            guideImage,
            stack.below,
            hatImage,
            sprite.width,
            sprite.height,
          )
        : guideImage,
    [stack, guideImage, hatImage, sprite.width, sprite.height],
  );
  const hatch = useMemo(() => {
    if (!chosen || !wornHat) return null;
    const fate = layerFate(chosen, wornHat);
    const frame = appendageFrames[chosen.id]?.[view];
    return {
      cells: hatchedPixels(frame, fate, wornHat.masks[view]),
      fate,
      hat: wornHat.label.toLowerCase(),
    };
  }, [chosen, wornHat, appendageFrames, view]);
  // Each Try on choice drawn on the head, as the view being painted would be worn.
  const tryOnViews = useMemo(() => {
    const views: Record<string, HTMLCanvasElement> = {};
    if (!chosen) return views;
    for (const key of ['', ...Object.keys(hats)]) {
      const hat = key ? hats[key] : null;
      const image = hat ? hatImages[hat.views[view]] : undefined;
      views[key] = composeWorn(
        guideImage,
        stackLayers,
        hat,
        image,
        view,
        sprite.width,
        sprite.height,
      );
    }
    return views;
  }, [!!chosen, hats, hatImages, guideImage, stackLayers, view, sprite]);
  // The window hands the canvas only the chosen layer; the others are drawn around it.
  const canvasSprite = useMemo((): SpriteData => {
    if (!layered) return sprite;
    const layerTarget = {
      layer: chosen ? appendages.indexOf(chosen) + 2 : 1,
      layerId: chosenId,
    };
    // Composed only when a merged copy is made, so ordinary updates don't carry every layer.
    const mergeLayers = () => {
      const ordered = drawOrder(stackLayers);
      const index = ordered.findIndex((layer) => layer.id === chosenId);
      const frames = (part: StackLayer[]) =>
        part.flatMap((layer) => (layer.frame ? [layer.frame] : []));
      return {
        dir: direction,
        below: frames(ordered.slice(0, index)),
        above: frames(ordered.slice(index + 1)),
      };
    };
    if (!chosen) return { ...sprite, layerTarget, mergeLayers };
    const frame =
      appendageFrames[chosen.id]?.[view] ??
      blankFrame(sprite.width, sprite.height);
    const layer = {
      name: chosen.name,
      visible: true,
      data: { [direction]: frame },
    } as unknown as SpriteDataLayer;
    return { ...sprite, layers: [layer], layerTarget, mergeLayers };
  }, [
    layered,
    sprite,
    chosen,
    chosenId,
    appendages,
    appendageFrames,
    stackLayers,
    view,
    direction,
  ]);
  // An appendage's other views come from the server as the window turns to them.
  const layerLoading = !!chosen && !appendageFrames[chosen.id]?.[view];
  const layerName = chosen ? chosen.name : 'Base hair layer';
  // Copy all adds the base and the other layers, so it's offered only where there are some.
  const copiedByAll = sprite.baseCopyInfo
    ? target === 'markings'
      ? 'the custom markings and the base markings'
      : 'the custom hair and the base hair'
    : 'the paint of every layer';
  const mergedTooltip =
    sprite.baseCopyInfo || appendages.length
      ? `While lit, Ctrl+C copies ${copiedByAll}.`
      : undefined;
  const mergedHint = `Copies ${copiedByAll}.`;
  const regionMode = target === 'markings' && !!regions;
  const zones = regionZones ?? [];
  const [selectedZone, setSelectedZone] = useState(serverZone ?? null);
  const [hoveredZone, setHoveredZone] = useState<string | null>(null);
  // What hides or trims the paint under the cursor, shown as a tip once the cursor rests there.
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
  useEffect(clearCoverTip, [chosenId, wornKey]);
  useEffect(() => setSelectedZone(serverZone ?? null), [focusRevision]);
  const regionLabel = (selectedZone && regionLabels?.[selectedZone]) || '';
  const actionTarget = {
    dir: String(direction),
    ...(regionMode ? { zone: selectedZone } : chosen && { layer: chosen.id }),
  };
  const currentEmissive = regionMode
    ? !!(selectedZone && regionEmissive?.[selectedZone]?.[direction])
    : !!(chosen ? chosen.emissive : emissive)[direction];
  // Regions the server won't change right now, each with the reason, such as clothing covering it.
  const lockReason = (zone?: string | null) =>
    (zone && lockedRegions?.[zone]) || null;
  const selectedLock = lockReason(selectedZone);
  // Base markings the selected region can take; regions without any, like a taur body, have no section.
  const regionChoices = selectedZone
    ? regionMarkingChoices?.[selectedZone]
    : undefined;
  const markingRows = selectedZone
    ? (regionMarkings?.[selectedZone] ?? [])
    : [];
  // A limb takes each marking once, so a row offers only names no other row has claimed.
  const takenMarkings = new Set(markingRows.map((entry) => entry.name));
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
    if (!regionMode && !hatch?.cells.size) {
      if (coverTip) clearCoverTip();
      return;
    }
    const at = pixelAt(event);
    if (!at) return;
    const [px, py] = at;
    let label: string | null = null;
    // Only hatched pixels get the tip. It waits for the cursor to rest, so flicking across paint
    // mid-stroke never puts anything in the way.
    if (regionMode) {
      const zone = regionAt(regionRows, zones, px, py);
      // Locked regions can't be picked, so they don't light up either.
      const hovered = lockReason(zone) ? null : zone;
      if (hovered !== hoveredZone) setHoveredZone(hovered);
      if (event.buttons && hovered) dragZone.current = hovered;
      const pixel = sprite.layers[0]?.data[direction]?.[py]?.[px];
      const index = event.buttons
        ? null
        : coverIndexAt(coverMask?.[direction], px, py);
      const part = index === null ? null : coverParts?.[index];
      if (part) {
        // Clothing over a region it keeps from being worked on blocks it, painted or not; anything
        // else only hides paint.
        if (coverWorn?.[index!] && lockReason(zone)) {
          label = `Blocked by ${part}`;
        } else if (pixel && !pixel.endsWith('00')) {
          label = `Hidden by ${part}`;
        }
      }
    } else if (
      hatch &&
      !event.buttons &&
      px >= 0 &&
      px < sprite.width &&
      hatch.cells.has(py * sprite.width + px)
    ) {
      label = `${hatch.fate === 'hidden' ? 'Hidden' : 'Trimmed'} by the ${hatch.hat}`;
    }
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
  const salon = context === 'salon';
  const locked = (dir: Dir) => !!lockedDirections?.includes(String(dir));
  const rotate = (step: number) =>
    setDirection(cycleOption(rotation, direction, step) ?? direction);
  const savedLabel = salon ? 'Draft saved for this round' : 'Saved';
  const hairTarget = target === 'hair' || target === 'facial_hair';
  // Hair blends Custom colors with the hair color, markings with the body's primary mutant color.
  const bodyBlend = hairTarget ? 'hair' : 'mutant';
  const drawingName =
    target === 'hair'
      ? 'Custom Hair'
      : target === 'facial_hair'
        ? 'Custom Facial Hair'
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
    setMergedCopy(false);
    setDirection(Dir.SOUTH);
    setViewReset(true);
    const cancelContext = {
      setPreviewLayer,
      setPreviewData,
      setSelectionBounds,
      setSelectionMask,
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
      width={windowSize[0]}
      height={windowSize[1]}
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
              {!candidate.previews && (
                <Box color="label" mb={1}>
                  Drawing the preview...
                </Box>
              )}
              <Stack justify="space-around" mb={1}>
                {directions.map(([dir, label]) => (
                  <Stack.Item
                    key={dir}
                    grow
                    basis={0}
                    minWidth={0}
                    textAlign="center"
                  >
                    {!!candidate.previews?.[dir] && (
                      <Box
                        inline
                        className="CustomSpriteEditor__tile"
                        style={tileStyle}
                      >
                        <img
                          src={candidate.previews[dir]}
                          alt={`${label} preview`}
                          width={96}
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
                    const painted = !!(chosen ? chosen.edited : edited)[dir];
                    const pipLabel = layered
                      ? painted
                        ? `${layerName} has paint in this view`
                        : `No ${layerName.toLowerCase()} paint in this view yet`
                      : painted
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
                  <GuideToggle
                    selected={showGuide}
                    icon="user"
                    tooltip="Show the body behind your paint."
                    onClick={() => setShowGuide(!showGuide)}
                  >
                    Guide
                  </GuideToggle>
                  {!!canHideParts && (
                    <GuideToggle
                      selected={!hideParts}
                      icon="paw"
                      tooltip="Show hair, wings, tails and other parts that cover the body in the guide. The preview always shows them."
                      onClick={() => act('toggleParts')}
                    >
                      Parts
                    </GuideToggle>
                  )}
                  {!!canHideUnderwear && (
                    <GuideToggle
                      selected={!hideUnderwear}
                      icon="shirt"
                      tooltip="Show underwear in the guide and the preview."
                      onClick={() => act('toggleUnderwear')}
                    >
                      Underwear
                    </GuideToggle>
                  )}
                  {!!hasGradient && (
                    <GuideToggle
                      selected={!!showGradient}
                      icon="palette"
                      tooltip="Show the base look's gradient in the guide, preview and palette."
                      onClick={() => act('toggleGradient')}
                    >
                      Gradient
                    </GuideToggle>
                  )}
                  <GuideToggle
                    selected={showGrid}
                    icon="border-all"
                    tooltip="Pixel grid over the canvas."
                    onClick={() => setShowGrid(!showGrid)}
                  >
                    Grid
                  </GuideToggle>
                </div>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          {layered && (
            <Stack.Item>
              <LayerStrip
                appendages={appendages}
                selected={chosenId}
                hairPainted={!!edited[direction]}
                direction={view}
                maxAppendages={maxAppendages}
                onSelect={setLayerId}
                onAdd={() => act('addAppendage')}
              />
            </Stack.Item>
          )}
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
              <Stack.Item className="CustomSpriteEditor__turns">
                <SelectionTools
                  className="CustomSpriteEditor__group"
                  mergedTooltip={mergedTooltip}
                />
              </Stack.Item>
              <Stack.Item className="CustomSpriteEditor__divider" />
              <Stack.Item>
                <SpriteEditor.Undo
                  stack={editorData.undoStack}
                  icon="backward"
                />
              </Stack.Item>
              <Stack.Item>
                <SpriteEditor.Redo
                  stack={editorData.redoStack}
                  icon="forward"
                />
              </Stack.Item>
              <Stack.Item className="CustomSpriteEditor__divider" />
              <Stack.Item>
                <Button
                  className="CustomSpriteEditor__clear"
                  icon="broom"
                  disabled={regionMode && (!selectedZone || !!selectedLock)}
                  tooltip={
                    layered
                      ? `Erase ${chosen ? chosen.name.toLowerCase() : 'the base hair layer'} in this view. Undo brings it back.`
                      : !regionMode
                        ? 'Erase this view. Undo brings it back.'
                        : regionLabel
                          ? `Erase all ${regionLabel.toLowerCase()} paint in this view. Undo brings it back.`
                          : 'Choose a region to clear.'
                  }
                  onClick={() => act('clear', actionTarget)}
                >
                  {chosen
                    ? `Clear ${chosen.name.toLowerCase()}`
                    : !regionMode
                      ? 'Clear direction'
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
          <Stack.Item grow basis={0}>
            <Stack fill>
              <Stack.Item grow minWidth={0} minHeight={0}>
                <Stack vertical fill>
                  <Stack.Item grow minHeight={0}>
                    <Box
                      className="CustomSpriteEditor__canvas"
                      height="100%"
                      backgroundColor="rgba(0, 0, 0, 0.2)"
                      p={1}
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
                      {/* A view that only uses the middle of a wide canvas lays it out twice as wide; this box clips the sides. */}
                      <div
                        className={classes([
                          'CustomSpriteEditor__canvasFrame',
                          halfView && 'CustomSpriteEditor__canvasFrame--half',
                        ])}
                      >
                        <SpriteEditor.Canvas
                          data={canvasSprite}
                          disabled={layerLoading}
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
                          backgroundImage={canvasBackground}
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
                              : stack
                                ? (canvasWidth, canvasHeight) => (
                                    <LayerOverlay
                                      items={stack.above}
                                      hatImage={hatImage}
                                      hatch={hatch}
                                      imageWidth={sprite.width}
                                      imageHeight={sprite.height}
                                      canvasWidth={canvasWidth}
                                      canvasHeight={canvasHeight}
                                      tallRow={
                                        tall ? sprite.height - 32 : undefined
                                      }
                                    />
                                  )
                                : undefined
                          }
                        />
                      </div>
                      {!!coverTip && (
                        <div
                          className="CustomSpriteEditor__coverTip"
                          style={{ left: coverTip.x, top: coverTip.y }}
                        >
                          {coverTip.label}
                        </div>
                      )}
                    </Box>
                  </Stack.Item>
                  <Stack.Item
                    textAlign="center"
                    className="CustomSpriteEditor__canvasRotation"
                  >
                    <ViewRotation onRotate={rotate} />
                  </Stack.Item>
                  {regionMode && !!selectedLock && (
                    <Stack.Item className="CustomSpriteEditor__status">
                      <Box color="average">{selectedLock}</Box>
                    </Stack.Item>
                  )}
                  {!!chosen && (
                    <Stack.Item>
                      <AppendagePanel
                        key={chosen.id}
                        appendage={chosen}
                        hats={hats}
                        chips={chips}
                        hat={wornKey}
                        maxName={maxAppendageName}
                        canAdd={appendages.length < maxAppendages}
                        onRename={(name) =>
                          act('renameAppendage', { id: chosenId, name })
                        }
                        onZone={(zone) =>
                          act('setAppendageZone', { id: chosenId, zone })
                        }
                        onKind={(outer) =>
                          act('setAppendageKind', { id: chosenId, outer })
                        }
                        onCopy={() => {
                          // The copy takes the layer as the server has it, floating paint included.
                          settleSelection();
                          act('copyToOverHat', { id: chosenId });
                        }}
                        onRemove={() =>
                          act('removeAppendage', { id: chosenId })
                        }
                      />
                    </Stack.Item>
                  )}
                </Stack>
              </Stack.Item>
              <Stack.Item
                width={layered ? HAIR_PANEL_WIDTH : EDITOR_PANEL_WIDTH}
                className="CustomSpriteEditor__sidebar"
              >
                <Stack vertical fill>
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
                              icons={hairStyleIcons}
                              name={
                                target === 'facial_hair'
                                  ? 'facial hairstyle'
                                  : 'hairstyle'
                              }
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
                              <ColorChip
                                ml={1}
                                color={hairColor ?? '#000000'}
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
                        {markingRows.map((marking) => {
                          const choices = regionChoices.filter(
                            (name) =>
                              name === marking.name || !takenMarkings.has(name),
                          );
                          return (
                            <Stack key={marking.index} mb={0.5} align="center">
                              <Stack.Item grow minWidth={0}>
                                <CycleDropdown
                                  options={choices}
                                  icons={regionMarkingIcons?.[selectedZone]}
                                  previewArea={
                                    MARKING_PREVIEW_AREAS[selectedZone]
                                  }
                                  name={`${regionLabel.toLowerCase()} marking`}
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
                                  // A locked marking always wears its own colour.
                                  disabled={!!selectedLock || !!marking.locked}
                                  tooltip={
                                    marking.locked
                                      ? `${marking.name} is ink: it always keeps its own color.`
                                      : `Color of ${marking.name}`
                                  }
                                  aria-label={`Color of ${marking.name}`}
                                  onClick={() =>
                                    act('pickBaseMarkingColor', {
                                      zone: selectedZone,
                                      index: marking.index,
                                    })
                                  }
                                >
                                  <ColorChip color={marking.color} />
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
                        })}
                        {markingRows.length < (maxBaseMarkings ?? 0) && (
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
                  <Stack.Item>
                    <CustomSpritePalette
                      blending={
                        <div className="CustomSpriteEditor__blending">
                          <Collapsible title="Blending options">
                            <BlendToggle
                              mode={bodyBlend}
                              current={colorMode}
                              act={act}
                              label={
                                hairTarget
                                  ? 'Blend with hair color'
                                  : 'Blend with mutant color'
                              }
                            />
                            <Stack align="center" mt={0.5}>
                              <Stack.Item grow>
                                <BlendToggle
                                  mode="tint"
                                  current={colorMode}
                                  act={act}
                                  label="Blend with color"
                                />
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
                        </div>
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
                      checked={currentEmissive}
                      disabled={
                        !emissiveAllowed ||
                        (regionMode && (!selectedZone || !!selectedLock))
                      }
                      tooltip={
                        !emissiveAllowed
                          ? 'Enable emissive appearance in character preferences.'
                          : layered
                            ? 'Makes this layer glow in the dark in this view.'
                            : 'Makes this direction glow in the dark.'
                      }
                      onClick={() =>
                        act('setEmissive', {
                          ...actionTarget,
                          enabled: !currentEmissive,
                        })
                      }
                    >
                      {regionMode
                        ? `Emissives - (${regionLabel}, ${viewLabel})`
                        : layered
                          ? `Emissive - (${layerName}, ${viewLabel})`
                          : 'Emissive'}
                    </Button.Checkbox>
                  </Stack.Item>
                  {/* The preview takes whatever height the panel has left, Try on included. */}
                  <Stack.Item grow basis={0} minHeight="10rem">
                    <Section title="Preview" fill>
                      <div className="CustomSpriteEditor__preview">
                        {previews[direction] ? (
                          <FittedPicture
                            src={previews[direction]}
                            alt="Character with your drawing"
                            tileStyle={tileStyle}
                            narrowTileStyle={narrowTileStyle}
                          />
                        ) : (
                          <div className="CustomSpriteEditor__previewFit" />
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
                          <ViewRotation onRotate={rotate} />
                        </Box>
                        {!!chosen && Object.keys(hats).length > 0 && (
                          <TryOn
                            hats={hats}
                            selected={wornKey}
                            views={tryOnViews}
                            onSelect={setChosenHat}
                          />
                        )}
                      </div>
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
          {!!strokeNotice && (
            <Stack.Item color="average">{strokeNotice}</Stack.Item>
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
                {selecting && (
                  <div className="CustomSpriteEditor__selectHint">
                    <kbd>Ctrl+C</kbd> copy · <kbd>Ctrl+X</kbd> cut ·{' '}
                    <kbd>Ctrl+V</kbd>{' '}
                    {appendages.length ? 'paste into this layer' : 'paste'} ·{' '}
                    {!!mergedTooltip && !!selectionBounds && (
                      <Tooltip content={mergedHint}>
                        <span>
                          <kbd>Ctrl+Shift+C</kbd> copy all ·{' '}
                        </span>
                      </Tooltip>
                    )}
                    <kbd>{ROTATE_SELECTION_KEY.toUpperCase()}</kbd> /{' '}
                    <kbd>Shift+{ROTATE_SELECTION_KEY.toUpperCase()}</kbd> turn ·{' '}
                    <kbd>Shift+{MIRROR_SELECTION_KEY.toUpperCase()}</kbd> mirror
                    · <kbd>Right-drag</kbd> subtract · <kbd>Enter</kbd> drop ·{' '}
                    <kbd>Esc</kbd> cancel
                  </div>
                )}
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
                  <Button
                    onClick={() => {
                      // The salon keeps the draft, floating paint included.
                      settleSelection();
                      act('closeEditor');
                    }}
                  >
                    Close
                  </Button>
                </Stack.Item>
              )}
              <Stack.Item>
                <Button
                  color="good"
                  disabled={salon && salonState !== 'drafting'}
                  tooltip="Ctrl+S saves without closing."
                  onClick={() => {
                    // Floating paint is part of the drawing being saved or finished.
                    settleSelection();
                    act(salon ? 'finishWork' : 'save');
                  }}
                >
                  {salon ? 'Finish' : 'Save and close'}
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
        <FinishingOverlay
          applying={salon && salonState === 'applying'}
          duration={applyDuration ?? 5000}
        />
      </Window.Content>
    </Window>
  );
};
