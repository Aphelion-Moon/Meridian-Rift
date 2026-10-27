// THIS IS AN APHELION UI FILE
import { useLayoutEffect, useRef } from 'react';
import { classes } from 'tgui-core/react';
import type { StringLayer } from '../SpriteEditor/Types/types';
import { frameCanvas } from './appendages';
import {
  artToPixels,
  GRAFFITI_HEIGHT,
  GRAFFITI_WIDTH,
  shownAlpha,
} from './graffitiCodec';
import type { GraffitiArt } from './types';

/** How strongly what a stopped paint job hasn't reached yet shows. */
const GHOST_ALPHA = 0.35;

/**
 * Arts drawn lately at their own size, by width, palette and grid. The spray can resends its whole
 * library whenever any of it changes, so each thumbnail is decoded once rather than on every update.
 */
const artCanvases = new Map<string, HTMLCanvasElement>();
const ART_CANVASES_KEPT = 64;

/**
 * An art at its own size, transparent where it shows nothing, each alpha drawn as its share of the ceiling
 * (shownAlpha()). Callers treat it as read-only.
 */
export const artCanvas = (art: GraffitiArt): HTMLCanvasElement => {
  const key = `${art.w}|${art.pal}|${art.grid}`;
  const cached = artCanvases.get(key);
  if (cached) return cached;
  const canvas = document.createElement('canvas');
  canvas.width = art.w;
  canvas.height = GRAFFITI_HEIGHT;
  const context = canvas.getContext('2d');
  const pixels = context ? artToPixels(art) : [];
  if (context && pixels.length) {
    const image = context.createImageData(art.w, GRAFFITI_HEIGHT);
    // An art repeats a few colours many times over, so each is read once.
    const colors = new Map<string, number[]>();
    for (const [index, pixel] of pixels.entries()) {
      if (!pixel) continue;
      let color = colors.get(pixel);
      if (!color) {
        color = [1, 3, 5, 7].map((at) =>
          Number.parseInt(pixel.slice(at, at + 2), 16),
        );
        color[3] = shownAlpha(color[3]);
        colors.set(pixel, color);
      }
      image.data.set(color, index * 4);
    }
    context.putImageData(image, 0, 0);
  }
  artCanvases.set(key, canvas);
  if (artCanvases.size > ART_CANVASES_KEPT) {
    artCanvases.delete(artCanvases.keys().next().value!);
  }
  return canvas;
};

/** The graffiti already on a surface session's tiles, side by side at the canvas's size, or none while there is none. */
export const surfaceCanvas = (
  arts: (GraffitiArt | null)[] | null | undefined,
  width: number,
) => {
  if (!arts?.some(Boolean)) return undefined;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = GRAFFITI_HEIGHT;
  const context = canvas.getContext('2d');
  for (const [tile, art] of arts.entries()) {
    if (art) context?.drawImage(artCanvas(art), tile * GRAFFITI_WIDTH, 0);
  }
  return canvas;
};

type GraffitiThumbProps = {
  art: GraffitiArt;
  /** Screen pixels per art pixel. */
  scale: number;
  /** Draws the art faint, as what a stopped paint job hasn't reached yet. */
  ghost?: boolean;
  /** Drawn over the art at full strength: what a stopped paint job revealed. */
  over?: GraffitiArt | null;
  label?: string;
};

/** An art on a checkerboard, its pixels kept square. */
export const GraffitiThumb = (props: GraffitiThumbProps) => {
  const { art, scale, ghost, over, label } = props;
  const ref = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    const context = ref.current?.getContext('2d');
    if (!context) return;
    context.clearRect(0, 0, art.w, GRAFFITI_HEIGHT);
    context.globalAlpha = ghost ? GHOST_ALPHA : 1;
    context.drawImage(artCanvas(art), 0, 0);
    context.globalAlpha = 1;
    if (over) context.drawImage(artCanvas(over), 0, 0);
  }, [art.w, art.pal, art.grid, ghost, over?.w, over?.pal, over?.grid]);
  return (
    <canvas
      ref={ref}
      className="Graffiti__thumb"
      width={art.w}
      height={GRAFFITI_HEIGHT}
      style={{ width: art.w * scale, height: GRAFFITI_HEIGHT * scale }}
      role="img"
      aria-label={label}
    />
  );
};

type GraffitiPreviewProps = {
  width: number;
  /** The graffiti already on the surface, beneath the piece: a surfaceCanvas(). */
  backdrop?: HTMLCanvasElement;
  /** The piece's layers, bottom first, from shownFrame(). Kept while they don't change, as it draws again when they do. */
  frames: (StringLayer | undefined)[];
};

/** The piece on the surface at twice its size, on a wall's grey and over what is there already, as the canvas draws it. */
export const GraffitiPreview = (props: GraffitiPreviewProps) => {
  const { width, backdrop, frames } = props;
  const ref = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    const context = ref.current?.getContext('2d');
    if (!context) return;
    context.clearRect(0, 0, width, GRAFFITI_HEIGHT);
    if (backdrop) context.drawImage(backdrop, 0, 0);
    for (const frame of frames) {
      if (frame) context.drawImage(frameCanvas(frame), 0, 0);
    }
  }, [width, backdrop, frames]);
  return (
    <div className="Graffiti__preview">
      <canvas
        ref={ref}
        className={classes([
          'Graffiti__previewCanvas',
          width > GRAFFITI_WIDTH && 'Graffiti__previewCanvas--wide',
        ])}
        width={width}
        height={GRAFFITI_HEIGHT}
        role="img"
        aria-label="Your graffiti on the surface"
      />
    </div>
  );
};
