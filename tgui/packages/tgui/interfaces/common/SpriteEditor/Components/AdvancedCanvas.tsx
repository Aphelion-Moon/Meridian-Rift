// APHELION EDIT CHANGE - ORIGINAL: import { useLayoutEffect, useRef, useState } from 'react';
import { useLayoutEffect, useMemo, useRef, useState } from 'react';
import transparency_checkerboard from 'tgui/assets/transparency_checkerboard.svg';
import {
  type BooleanStyleMap,
  computeBoxProps,
  type StringStyleMap,
} from 'tgui-core/ui';
import { colorToCssString } from '../colorSpaces';
import { getShadedAreas, type ShadeRenderer } from '../drawBounds'; // APHELION EDIT ADDITION
import { useClickAndDragEventHandler, useDimensions } from '../helpers';
import type {
  BorderStyleProps,
  EditorColor,
  IncludeOrOmitEntireType,
  InlineStyle,
  Layer,
  SelectionBounds, // APHELION EDIT ADDITION
  SelectionMask, // APHELION EDIT ADDITION
  StringLayer,
} from '../Types/types';
import { SelectionOutline } from './SelectionOutline'; // APHELION EDIT ADDITION

type AdvancedCanvasMouseEventHandler = (
  event: MouseEvent,
  ref: React.RefObject<HTMLCanvasElement | null>,
) => void;

type AdvancedCanvasClickHandler = {
  onClick: AdvancedCanvasMouseEventHandler;
};
type AdvancedCanvasClickAndDragHandlers = Partial<{
  onMouseDown: AdvancedCanvasMouseEventHandler;
  onMouseMove: AdvancedCanvasMouseEventHandler;
  onMouseUp: AdvancedCanvasMouseEventHandler;
}>;

type AdvancedCanvasEventHandlers =
  | AdvancedCanvasClickHandler
  | AdvancedCanvasClickAndDragHandlers;

export type AdvancedCanvasPropsBase = {
  data: Layer | StringLayer;
  showGrid?: boolean;
  border?: BorderStyleProps;
  background?: string | string[];
  backgroundImage?: HTMLImageElement; // APHELION EDIT ADDITION
  backdropColor?: string;
  drawBounds?: [number, number, number, number]; // APHELION EDIT ADDITION
  drawMask?: string[]; // APHELION EDIT ADDITION
  selectionBounds?: SelectionBounds; // APHELION EDIT ADDITION
  selectionMask?: SelectionMask; // APHELION EDIT ADDITION
  shade?: ShadeRenderer; // APHELION EDIT ADDITION
  overlay?: (canvasWidth: number, canvasHeight: number) => React.ReactNode; // APHELION EDIT ADDITION
} & Partial<BooleanStyleMap & StringStyleMap & InlineStyle>;

type AdvancedCanvasProps = IncludeOrOmitEntireType<
  AdvancedCanvasEventHandlers,
  AdvancedCanvasPropsBase
>;

const propsHaveClickHandler = (
  props: AdvancedCanvasProps,
): props is AdvancedCanvasPropsBase & AdvancedCanvasClickHandler =>
  Object.keys(props).includes('onClick');
const propsHaveClickAndDragHandlers = (
  props: AdvancedCanvasProps,
): props is AdvancedCanvasPropsBase & AdvancedCanvasClickAndDragHandlers => {
  const keys = Object.keys(props);
  return keys.includes('onMouseMove') || keys.includes('onMouseUp');
};

const extractBaseProps = (props: AdvancedCanvasProps) => {
  switch (true) {
    case propsHaveClickHandler(props): {
      const { onClick, ...rest } = props;
      return { ...rest };
    }
    case propsHaveClickAndDragHandlers(props): {
      const { onMouseDown, onMouseMove, onMouseUp, ...rest } = props;
      return { ...rest };
    }
    default:
      return props;
  }
};

export const AdvancedCanvas = (props: AdvancedCanvasProps) => {
  const {
    data,
    showGrid,
    border: borderProps,
    background,
    backgroundImage, // APHELION EDIT ADDITION
    backdropColor,
    drawBounds, // APHELION EDIT ADDITION
    drawMask, // APHELION EDIT ADDITION
    selectionBounds, // APHELION EDIT ADDITION
    selectionMask, // APHELION EDIT ADDITION
    shade, // APHELION EDIT ADDITION
    overlay, // APHELION EDIT ADDITION
    ...rest
  } = extractBaseProps(props);
  const { onClick } = propsHaveClickHandler(props) ? props : {};
  const imageHeight = data.length;
  const imageWidth = data.at(0)?.length ?? 0;
  // APHELION EDIT ADDITION START
  const shadedAreas = useMemo(
    () => getShadedAreas(imageWidth, imageHeight, drawBounds, drawMask),
    [
      imageWidth,
      imageHeight,
      JSON.stringify(drawBounds),
      JSON.stringify(drawMask),
    ],
  );
  // APHELION EDIT ADDITION END
  const parentRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [parentWidth, parentHeight] = useDimensions(parentRef);
  const [[canvasWidth, canvasHeight], setCanvasDimensions] = useState<
    [number, number]
  >([0, 0]);
  const mouseDownHandler = propsHaveClickAndDragHandlers(props)
    ? useClickAndDragEventHandler(
        canvasRef,
        props.onMouseDown,
        props.onMouseMove,
        props.onMouseUp,
      )
    : undefined;
  useLayoutEffect(() => {
    const parent = parentRef.current;
    if (!parent) return;
    const { width: parentWidth, height: parentHeight } =
      parent.getBoundingClientRect();
    const scalingFactor = Math.floor(
      Math.min(parentWidth / imageWidth, parentHeight / imageHeight),
    );
    setCanvasDimensions([
      imageWidth * scalingFactor,
      imageHeight * scalingFactor,
    ]);
  }, [imageWidth, imageHeight, parentWidth, parentHeight, parentRef]);
  useLayoutEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) {
      return;
    }
    const scalingFactor = canvasWidth / imageWidth;
    const context = canvas.getContext('2d')!;
    context.clearRect(0, 0, canvasWidth, canvasHeight);
    // APHELION EDIT ADDITION START
    if (backgroundImage) {
      context.imageSmoothingEnabled = false;
      context.drawImage(backgroundImage, 0, 0, canvasWidth, canvasHeight);
    }
    // APHELION EDIT ADDITION END
    if (backdropColor) {
      context.fillStyle = backdropColor;
      context.fillRect(0, 0, canvasWidth, canvasHeight);
    }
    data.forEach((row: string[] | EditorColor[], y) => {
      row.forEach((pixel: string | EditorColor, x) => {
        context.fillStyle =
          typeof pixel === 'string' ? pixel : colorToCssString(pixel);
        context.fillRect(
          x * scalingFactor,
          y * scalingFactor,
          scalingFactor,
          scalingFactor,
        );
      });
    });
    // APHELION EDIT ADDITION START
    if (shadedAreas.length) {
      if (shade) {
        shade(context, shadedAreas, scalingFactor);
      } else {
        context.fillStyle = 'rgba(50, 50, 50, 0.75)';
        for (const [x, y, width, height] of shadedAreas) {
          context.fillRect(
            x * scalingFactor,
            y * scalingFactor,
            width * scalingFactor,
            height * scalingFactor,
          );
        }
      }
    }
    // APHELION EDIT ADDITION END
    if (showGrid && scalingFactor >= 5) {
      context.beginPath();
      context.strokeStyle = 'black';
      context.lineWidth = 2;
      for (let y = 0; y <= canvasHeight; y += scalingFactor) {
        context.moveTo(0, y);
        context.lineTo(canvasWidth, y);
      }
      for (let x = 0; x <= canvasWidth; x += scalingFactor) {
        context.moveTo(x, 0);
        context.lineTo(x, canvasHeight);
      }
      context.stroke();
    }
  }, [
    JSON.stringify(data),
    canvasWidth,
    canvasHeight,
    canvasRef,
    showGrid,
    backdropColor,
    backgroundImage, // APHELION EDIT ADDITION
    shadedAreas, // APHELION EDIT ADDITION
    shade, // APHELION EDIT ADDITION
  ]);
  return (
    <div
      ref={parentRef}
      {...computeBoxProps({
        ...rest,
        inline: true,
        align: 'center',
        verticalAlign: 'middle',
      })}
    >
      {/* APHELION EDIT ADDITION START */}
      <div
        style={{
          position: 'relative',
          display: 'inline-block',
          width: canvasWidth,
          height: canvasHeight,
        }}
      >
        {/* APHELION EDIT ADDITION END */}
        <canvas
          width={canvasWidth}
          height={canvasHeight}
          ref={canvasRef}
          onClick={onClick && ((ev) => onClick(ev.nativeEvent, canvasRef))}
          onMouseDown={mouseDownHandler}
          style={{
            backgroundImage: [
              ...(Array.isArray(background)
                ? background
                : background
                  ? [background]
                  : []),
              `url(${transparency_checkerboard})`,
            ].join(','),
            // APHELION EDIT ADDITION START
            backgroundSize:
              background || backgroundImage ? '100% 100%' : undefined,
            backgroundRepeat:
              background || backgroundImage ? 'no-repeat' : undefined,
            imageRendering: 'pixelated',
            // APHELION EDIT ADDITION END
            outline: '2px solid black',
            ...borderProps,
          }}
        />
        {/* APHELION EDIT ADDITION START */}
        {selectionBounds && (
          <SelectionOutline
            bounds={selectionBounds}
            mask={selectionMask}
            scaleX={canvasWidth / imageWidth}
            scaleY={canvasHeight / imageHeight}
          />
        )}
        {overlay?.(canvasWidth, canvasHeight)}
      </div>
      {/* APHELION EDIT ADDITION END */}
    </div>
  );
};
