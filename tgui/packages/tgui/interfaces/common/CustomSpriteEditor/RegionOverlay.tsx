// THIS IS AN APHELION UI FILE
import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { classes } from 'tgui-core/react';
import {
  bracketBars,
  regionBounds,
  regionOutline,
  regionTag,
  tagPosition,
} from './regions';

/** How long a newly selected region's tag stays up before it fades. */
const TAG_SHOWN_MS = 1500;

type RegionOverlayProps = {
  rows?: string[];
  zones: string[];
  imageWidth: number;
  canvasWidth: number;
  canvasHeight: number;
  selected?: string | null;
  hovered?: string | null;
  labels: Record<string, string>;
};

/**
 * The selected region's target-lock brackets and name tag, and the hovered region's faint outline.
 * Everything is black and white and sits outside region pixels, so paint is never tinted or covered.
 * The tag names a region as it's selected, then fades so it isn't in the way while drawing.
 */
export const RegionOverlay = (props: RegionOverlayProps) => {
  const {
    rows,
    zones,
    imageWidth,
    canvasWidth,
    canvasHeight,
    selected,
    hovered,
    labels,
  } = props;
  const ref = useRef<HTMLCanvasElement>(null);
  const scale = imageWidth ? canvasWidth / imageWidth : 0;
  const bounds = regionBounds(rows, zones, selected);
  const [tagFaded, setTagFaded] = useState(false);
  useEffect(() => {
    setTagFaded(false);
    const timeout = setTimeout(() => setTagFaded(true), TAG_SHOWN_MS);
    return () => clearTimeout(timeout);
  }, [selected]);
  useLayoutEffect(() => {
    const context = ref.current?.getContext('2d');
    if (!context || !scale) return;
    context.clearRect(0, 0, canvasWidth, canvasHeight);
    if (hovered && hovered !== selected) {
      context.fillStyle = 'rgba(255, 255, 255, 0.35)';
      for (const [x, y, w, h] of regionOutline(rows, zones, hovered, scale)) {
        context.fillRect(x, y, w, h);
      }
    }
    if (!bounds) return;
    for (const [color, shift] of [
      ['rgba(0, 0, 0, 0.9)', 1],
      ['#ffffff', 0],
    ] as const) {
      context.fillStyle = color;
      for (const [x, y, w, h] of bracketBars(bounds, scale)) {
        context.fillRect(x + shift, y + shift, w, h);
      }
    }
  }, [
    JSON.stringify(rows),
    zones.join(),
    selected,
    hovered,
    canvasWidth,
    canvasHeight,
    scale,
  ]);
  const tag = bounds && scale ? tagPosition(bounds, scale) : null;
  return (
    <>
      <canvas
        ref={ref}
        className="CustomSpriteEditor__overlay"
        width={canvasWidth}
        height={canvasHeight}
      />
      {!!tag && !!selected && (
        <div
          className={classes([
            'CustomSpriteEditor__regionTag',
            tagFaded && 'CustomSpriteEditor__regionTag--faded',
          ])}
          style={{ left: tag[0], top: tag[1] }}
        >
          {regionTag(selected, labels[selected] ?? selected)}
        </div>
      )}
    </>
  );
};
