// APHELION EDIT CHANGE - ORIGINAL: import { useAtom, useAtomValue, useSetAtom } from 'jotai';
import { useAtom, useAtomValue, useSetAtom, useStore } from 'jotai';
// APHELION EDIT CHANGE - ORIGINAL: import { useEffect, useState } from 'react';
import { useEffect, useMemo } from 'react';
import { useBackend } from 'tgui/backend';
import { Button, Stack } from 'tgui-core/components'; // APHELION EDIT CHANGE - ORIGINAL: import { Box, Button, Floating, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { capitalize } from 'tgui-core/string';
import {
  colorsAtom,
  currentColorAtom,
  currentColorInternalAtom,
  currentToolAtom,
  dirAtom,
  layerAtom,
  onSelectServerColorAtom,
  previewDataAtom,
  previewLayerAtom,
  selectionBoundsAtom, // APHELION EDIT ADDITION
  selectionMaskAtom, // APHELION EDIT ADDITION
  tools,
} from './atoms';
import {
  AdvancedCanvas,
  type AdvancedCanvasPropsBase,
} from './Components/AdvancedCanvas';
import {
  ColorPicker as BaseColorPicker,
  type ColorPickerProps as BaseColorPickerProps,
} from './Components/ColorPicker';
import {
  LayerManager as BaseLayerManager,
  type LayerManagerProps as BaseLayerManagerProps,
} from './Components/LayerManager';
import {
  Palette as BasePalette,
  type PaletteProps as BasePaletteProps,
} from './Components/Palette';
import {
  colorsAreEqual,
  colorToHexString,
  parseHexColorString,
} from './colorSpaces';
// APHELION EDIT CHANGE - ORIGINAL: import { getFlattenedSpriteDir, localizeCoords } from './helpers';
import {
  getFlattenedSpriteDir,
  isTextEntryTarget,
  localizeCoords,
} from './helpers';
import { useSelectionCommands } from './selection'; // APHELION EDIT ADDITION
import type { Tool } from './Types/Tool';
import {
  type IncludeOrOmitEntireType,
  type SpriteData,
  SpriteEditorToolFlags,
} from './Types/types';
// APHELION EDIT ADDITION START
import {
  toolTooltip,
  useSpriteEditorHistory,
  useSpriteEditorHotkeys,
  useSpriteEditorToolHotkeys,
} from './useSpriteEditorHotkeys';

// APHELION EDIT ADDITION END
type ToolbarButtonProps = Omit<
  Parameters<typeof Button>[0],
  'icon' | 'onClick' | 'selected' | 'ellipsis'
>;

type ToolbarProps = {
  toolButtonProps?: ToolbarButtonProps;
  perButtonProps?: (tool: Tool, i: number) => ToolbarButtonProps;
  toolFlags?: SpriteEditorToolFlags;
} & Parameters<typeof Stack>[0];

type TransactionType = 'undo' | 'redo';

type HistoryButtonProps = {
  stack: string[];
  type: TransactionType;
};

/* // APHELION EDIT REMOVAL START
const HistoryButton = (props: HistoryButtonProps) => {
  const { stack, type } = props;
  const { act } = useBackend();
  const [historyOpen, setHistoryOpen] = useState(false);
  const stackEmpty = stack.length < 1;
  const action = (count = 1) =>
    act(`spriteEditorCommand`, { command: type, count });
  return (
    <Floating
      handleOpen={historyOpen}
      disabled
      content={
        <Box backgroundColor="rgba(0, 0, 0, 33%)">
          <Stack vertical maxHeight="15rem" overflowY="scroll">
            {stack.map((transaction, i) => (
              <Stack.Item key={i} m={0}>
                <Button
                  mx="0.5rem"
                  color="transparent"
                  width="100%"
                  ellipsis
                  onClick={() => {
                    action(i);
                    setHistoryOpen(false);
                  }}
                >
                  {transaction}
                </Button>
              </Stack.Item>
            ))}
          </Stack>
        </Box>
      }
    >
      <Button
        inline
        mr={0}
        icon={type}
        disabled={stackEmpty}
        tooltip={`${capitalize(type)}${stackEmpty ? '' : ` ${stack[stack.length - 1]}`}`}
        onClick={() => action()}
        style={{
          borderTopRightRadius: 0,
          borderBottomRightRadius: 0,
          borderRight: '1px solid rgba(255, 255, 255, 0.33)',
        }}
      />
      <Button
        inline
        ml={0}
        icon={historyOpen ? 'chevron-up' : 'chevron-down'}
        disabled={stackEmpty}
        iconSize={0.5}
        onClick={() => setHistoryOpen(!historyOpen)}
        style={{
          borderTopLeftRadius: 0,
          borderBottomLeftRadius: 0,
        }}
      />
    </Floating>
  );
};

*/ // APHELION EDIT REMOVAL END
// APHELION EDIT ADDITION START
const HistoryButton = (props: HistoryButtonProps) => {
  const { stack, type } = props;
  const history = useSpriteEditorHistory();
  const stackEmpty = stack.length < 1;
  return (
    <Button
      icon={type}
      disabled={stackEmpty}
      tooltip={`${capitalize(type)} (${type === 'undo' ? 'Ctrl+Z' : 'Ctrl+Y or Ctrl+Shift+Z'})${stackEmpty ? '' : `: ${stack[stack.length - 1]}`}`}
      onClick={() => history(type)}
    />
  );
};
// APHELION EDIT ADDITION END
type ServerColorProps = {
  serverPalette: string[];
  /* // APHELION EDIT REMOVAL START
  maxServerColors: number;
  onAddServerColor: string;
  onRemoveServerColor: string;
  */ // APHELION EDIT REMOVAL END
  // APHELION EDIT ADDITION START
  maxServerColors?: number;
  onAddServerColor?: string;
  onRemoveServerColor?: string;
  // APHELION EDIT ADDITION END
};

type PaletteProps = IncludeOrOmitEntireType<
  ServerColorProps,
  Omit<
    BasePaletteProps,
    | 'colors'
    | 'selectedColor'
    | 'onClickColor'
    | 'onClickAddColor'
    | 'onRemoveColor'
    | 'canAddColor'
  >
>;

/* // APHELION EDIT REMOVAL START
const hasServerColorProps = (
  props: PaletteProps,
): props is PaletteProps & ServerColorProps => {
  return Object.hasOwn(props, 'serverPalette');
};

*/ // APHELION EDIT REMOVAL END
type CanvasProps = {
  data: SpriteData;
  disabled?: BooleanLike;
  // APHELION EDIT ADDITION START
  onSave?: () => void;
  onSampleBackdrop?: (x: number, y: number) => void;
  onDraw?: (x: number, y: number, erasing?: boolean) => void;
  onPointerDown?: (x: number, y: number) => void;
  // APHELION EDIT ADDITION END
} & Omit<AdvancedCanvasPropsBase, 'data' | 'backdropColor'>;

export namespace SpriteEditor {
  export const syncBackend = (
    onSelectServerColor?: string,
    serverSelectedColor?: string,
  ) => {
    // const [currentColor, setCurrentColor] = useAtom(currentColorInternalAtom); // APHELION EDIT REMOVAL
    // APHELION EDIT ADDITION START
    const store = useStore();
    const setCurrentColor = useSetAtom(currentColorInternalAtom);
    // APHELION EDIT ADDITION END
    const setOnSelectServerColor = useSetAtom(onSelectServerColorAtom);
    useEffect(
      () => setOnSelectServerColor(onSelectServerColor),
      [onSelectServerColor],
    );
    useEffect(() => {
      if (serverSelectedColor) {
        const parsedColor = parseHexColorString(serverSelectedColor);
        const currentColor = store.get(currentColorInternalAtom); // APHELION EDIT ADDITION
        if (!colorsAreEqual(parsedColor, currentColor)) {
          setCurrentColor(parsedColor);
        }
      }
    }, [serverSelectedColor]);
  };

  export const ColorPicker = (
    props: Omit<BaseColorPickerProps, 'initialColor' | 'onSelectColor'>,
  ) => {
    const [currentColor, setCurrentColor] = useAtom(currentColorAtom);
    return (
      <BaseColorPicker
        initialColor={currentColor ?? { v: 1 }}
        onSelectColor={setCurrentColor}
        {...props}
      />
    );
  };

  export const Palette = (props: PaletteProps) => {
    const [colors, setColors] = useAtom(colorsAtom);
    const [currentColor, setCurrentColor] = useAtom(currentColorAtom);
    const {
      serverPalette,
      maxServerColors,
      onAddServerColor,
      onRemoveServerColor,
      // } = hasServerColorProps(props) ? props : {}; // APHELION EDIT REMOVAL
      // APHELION EDIT ADDITION START
      ...rest
    } = props as PaletteProps & Partial<ServerColorProps>;
    // APHELION EDIT ADDITION END
    const { act } = useBackend();
    const parsedServerColors = serverPalette?.map(parseHexColorString);
    useEffect(() => {
      if (!parsedServerColors) {
        return;
      }
      if (
        !parsedServerColors.find((serverColor) =>
          colorsAreEqual(serverColor, currentColor),
        )
      ) {
        setCurrentColor(parsedServerColors[0]);
      }
    }, [JSON.stringify(parsedServerColors)]);
    return (
      <BasePalette
        colors={parsedServerColors ?? colors}
        selectedColor={currentColor}
        onClickColor={setCurrentColor}
        onClickAddColor={() => {
          if (onAddServerColor) {
            act(onAddServerColor, { color: colorToHexString(currentColor) });
          } else {
            setColors((colors) => [...colors, currentColor]);
          }
        }}
        onRemoveColor={(index) => {
          if (onRemoveServerColor) {
            act(onRemoveServerColor, { index });
          } else {
            setColors(colors.toSpliced(index, 1));
          }
        }}
        maxColors={maxServerColors}
        {...rest} // APHELION EDIT CHANGE - ORIGINAL: {...props}
      />
    );
  };

  export const Undo = (props: Pick<HistoryButtonProps, 'stack'>) => {
    const { stack } = props;
    return <HistoryButton stack={stack} type="undo" />;
  };

  export const Redo = (props: Pick<HistoryButtonProps, 'stack'>) => {
    const { stack } = props;
    return <HistoryButton stack={stack} type="redo" />;
  };

  export const Toolbar = (props: ToolbarProps) => {
    const [currentTool, setCurrentTool] = useAtom(currentToolAtom);
    const setPreviewLayer = useSetAtom(previewLayerAtom);
    const setPreviewData = useSetAtom(previewDataAtom);
    // const cancelContext = { setPreviewLayer, setPreviewData }; // APHELION EDIT REMOVAL
    // APHELION EDIT ADDITION START
    const setSelectionBounds = useSetAtom(selectionBoundsAtom);
    const setSelectionMask = useSetAtom(selectionMaskAtom);
    const cancelContext = {
      setPreviewLayer,
      setPreviewData,
      setSelectionBounds,
      setSelectionMask,
    };
    // APHELION EDIT ADDITION END
    const {
      toolButtonProps,
      perButtonProps,
      toolFlags = SpriteEditorToolFlags.All,
      ...rest
    } = props;
    useSpriteEditorToolHotkeys(toolFlags); // APHELION EDIT ADDITION
    useEffect(() => {
      if (!(toolFlags & (1 << tools.indexOf(currentTool)))) {
        setCurrentTool(
          tools.find((_, i) => toolFlags & (1 << i))!,
          cancelContext,
        );
      }
    }, [toolFlags]);
    return (
      <Stack {...rest}>
        {/* APHELION EDIT REMOVAL START
        {tools.map(
          (tool, i) =>
            !!(toolFlags & (1 << i)) && (
              <Stack.Item key={i}>
                <Button
                  icon={tool.icon}
                  selected={currentTool === tool}
                  onClick={() => setCurrentTool(tool, cancelContext)}
                  {...toolButtonProps}
                  {...perButtonProps?.(tool, i)}
                />
              </Stack.Item>
            ),
        )}
        APHELION EDIT REMOVAL END */}
        {/* APHELION EDIT ADDITION START - Display order does not change tool flags. */}
        {[tools[4], ...tools.slice(0, 4)].map((tool) => {
          const i = tools.indexOf(tool);
          return (
            !!(toolFlags & (1 << i)) && (
              <Stack.Item key={i}>
                <Button
                  icon={tool.icon}
                  selected={currentTool === tool}
                  tooltip={toolTooltip(tool)}
                  onClick={() => setCurrentTool(tool, cancelContext)}
                  {...toolButtonProps}
                  {...perButtonProps?.(tool, i)}
                />
              </Stack.Item>
            )
          );
        })}
        {/* APHELION EDIT ADDITION END */}
      </Stack>
    );
  };

  export const Canvas = (props: CanvasProps) => {
    const {
      data,
      disabled,
      onSave,
      onSampleBackdrop,
      onDraw,
      onPointerDown,
      ...rest
    } = props; // APHELION EDIT CHANGE - ORIGINAL: const { data, disabled, ...rest } = props;
    useSpriteEditorHotkeys(!!disabled, onSave); // APHELION EDIT ADDITION
    const { width, height, backdrop } = data;
    const [currentColor, setCurrentColor] = useAtom(currentColorAtom);
    const currentTool = useAtomValue(currentToolAtom);
    const selectedDir = useAtomValue(dirAtom);
    const selectedLayer = useAtomValue(layerAtom);
    const [previewLayer, setPreviewLayer] = useAtom(previewLayerAtom);
    const [previewData, setPreviewData] = useAtom(previewDataAtom);
    // APHELION EDIT ADDITION START
    const [selectionBounds, setSelectionBounds] = useAtom(selectionBoundsAtom);
    const [selectionMask, setSelectionMask] = useAtom(selectionMaskAtom);
    const spriteKey = JSON.stringify(data);
    const renderedData = useMemo(() => {
      // These editors normally have one layer; no pixel compositing is needed.
      if (
        data.layers.length === 1 &&
        (data.layers[0].visible || selectedLayer === 0)
      ) {
        return previewLayer === 0
          ? previewData!
          : data.layers[0].data[selectedDir]!;
      }
      return getFlattenedSpriteDir(
        data,
        selectedDir,
        selectedLayer,
        previewLayer,
        previewData,
      );
    }, [spriteKey, selectedDir, selectedLayer, previewLayer, previewData]);
    // APHELION EDIT ADDITION END
    const toolContext = {
      // APHELION EDIT ADDITION START
      drawBounds: props.drawBounds,
      drawMask: props.drawMask,
      onSampleBackdrop,
      onDraw,
      setSelectionBounds,
      setSelectionMask,
      // APHELION EDIT ADDITION END
      currentColor,
      setCurrentColor,
      selectedDir,
      selectedLayer,
      setPreviewLayer,
      setPreviewData,
    };
    useEffect(() => {
      if (disabled) {
        currentTool.cancel?.(toolContext);
      }
    }, [disabled]);
    // APHELION EDIT ADDITION START
    useSelectionCommands(currentTool, toolContext, data, !!disabled);
    // Changing tool, view or bounds takes a selection's marquee away, dropping any floating paint.
    useEffect(
      () => () => {
        if (currentTool.release) currentTool.release(toolContext);
        else currentTool.cancel?.(toolContext);
      },
      [
        currentTool,
        selectedDir,
        selectedLayer,
        width,
        height,
        JSON.stringify(props.drawBounds),
        JSON.stringify(props.drawMask),
      ],
    );
    // The tools outlive this canvas, so on unmount (after the release above) they forget what it held.
    useEffect(
      () => () => {
        for (const tool of tools) tool.cancel?.(toolContext);
      },
      [],
    );
    // APHELION EDIT ADDITION END
    useEffect(() => {
      setPreviewLayer(undefined);
      setPreviewData(undefined);
      currentTool.reconcile?.(toolContext, data); // APHELION EDIT ADDITION
    }, [spriteKey, selectedDir, selectedLayer]); // APHELION EDIT CHANGE - ORIGINAL: }, [JSON.stringify(data)]);
    // APHELION EDIT ADDITION START
    useEffect(() => {
      if (disabled || !selectionBounds) return;
      const deselect = (event: KeyboardEvent) => {
        if (event.key !== 'Escape' || isTextEntryTarget(event.target)) return;
        currentTool.cancel?.(toolContext);
        event.preventDefault();
      };
      document.addEventListener('keydown', deselect);
      return () => document.removeEventListener('keydown', deselect);
    }, [disabled, !!selectionBounds, currentTool]);
    // APHELION EDIT ADDITION END
    return (
      <AdvancedCanvas
        /* APHELION EDIT REMOVAL START
        data={getFlattenedSpriteDir(
          data,
          selectedDir,
          selectedLayer,
          previewLayer,
          previewData,
        )}
        APHELION EDIT REMOVAL END */
        // APHELION EDIT ADDITION START
        data={renderedData}
        selectionBounds={selectionBounds}
        selectionMask={selectionMask}
        // APHELION EDIT ADDITION END
        backdropColor={backdrop}
        {...(disabled
          ? {}
          : {
              onMouseDown: (ev, ref) => {
                const [x, y] = localizeCoords(ev, ref, width, height);
                // APHELION EDIT ADDITION START
                // Pressing the canvas takes focus off the last control pressed, so Enter and shortcuts reach the canvas.
                if (document.activeElement instanceof HTMLElement) {
                  document.activeElement.blur();
                }
                // Region pickers learn where every primary press lands, whatever the tool.
                if (ev.button === 0) {
                  onPointerDown?.(Math.floor(x), Math.floor(y));
                }
                // Eyedropper prevents drag setup without changing the selected tool.
                if (ev.altKey && ev.button === 0) {
                  tools[2].onMouseDown(toolContext, data, x, y);
                  ev.preventDefault();
                  return;
                }
                // APHELION EDIT ADDITION END
                if (
                  !currentTool.onMouseDown(
                    toolContext,
                    data,
                    x,
                    y,
                    ev.button === 2,
                  )
                ) {
                  ev.preventDefault();
                }
              },
              onMouseMove: (ev, ref) => {
                const [x, y] = localizeCoords(ev, ref, width, height);
                currentTool.onMouseMove?.(toolContext, data, x, y);
              },
              onMouseUp: (ev, ref) => {
                const [x, y] = localizeCoords(ev, ref, width, height);
                currentTool.onMouseUp?.(toolContext, data, x, y);
              },
            })}
        {...rest}
      />
    );
  };

  export const LayerManager = (
    props: Omit<
      BaseLayerManagerProps,
      | 'context'
      | 'selectedDir'
      | 'setSelectedDir'
      | 'selectedLayer'
      | 'setSelectedLayer'
    >,
  ) => {
    const [selectedDir, setSelectedDir] = useAtom(dirAtom);
    const [selectedLayer, setSelectedLayer] = useAtom(layerAtom);
    return (
      <BaseLayerManager
        {...props}
        selectedDir={selectedDir}
        setSelectedDir={setSelectedDir}
        selectedLayer={selectedLayer}
        setSelectedLayer={setSelectedLayer}
      />
    );
  };
}
