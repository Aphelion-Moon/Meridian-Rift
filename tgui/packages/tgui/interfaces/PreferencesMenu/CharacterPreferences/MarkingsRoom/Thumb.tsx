// THIS IS AN APHELION UI FILE
import { memo, useLayoutEffect, useRef } from 'react';

import { drawPainted, type PaintedPixel } from './customs';
import {
  drawSprite,
  isBlankSprite,
  type Sprite,
  tintedSprite,
  useSprites,
} from './sprites';

/** A marking to draw over the body: its preferences sprite class, in its colour. */
export type ThumbMarking = {
  icon: string;
  color: string;
  /** The full-size mirror sprite, when the picker uses a scaled thumbnail. */
  nativeIcon?: string;
};

type Props = {
  /** The tile's size in pixels; the canvas fills it. */
  size: number;
  /** How many times the 32px sprite is drawn up. */
  zoom: number;
  /** The sprite pixel the tile centres on. */
  centre: [number, number];
  /** The species body's sprite class, under everything. */
  body?: string;
  markings?: ThumbMarking[];
  /** A custom drawing's pixels, on a canvas `width` wide centred on the tile. */
  painted?: { pixels: PaintedPixel[]; width: number };
  className?: string;
};

/** Where a sprite's top left goes in a tile, centring `centre` at a zoom. */
export const thumbOrigin = (
  size: number,
  zoom: number,
  centre: [number, number],
) =>
  [
    Math.round(size / 2 - centre[0] * zoom),
    Math.round(size / 2 - centre[1] * zoom),
  ] as const;

/**
 * A zone of the body drawn up in a tile: the species' bare body, the
 * markings over it in their colours, and a custom drawing on top, as the
 * mirror's cards and drawer show them. Pixels stay square at any zoom.
 */
export const Thumb = memo(function Thumb(props: Props) {
  const { size, zoom, centre, body, markings = [], painted, className } = props;
  const canvas = useRef<HTMLCanvasElement>(null);
  const [bodySprite, ...markingSprites] = useSprites([
    body,
    ...markings.map((marking) => marking.icon),
  ]);
  // Drawn once its markings can be, and again with the body once its sheet comes.
  const ready = markingSprites.every((sprite) => !!sprite);
  const key = markings.map((marking) => `${marking.icon}:${marking.color}`);

  useLayoutEffect(() => {
    const context = canvas.current?.getContext('2d');
    if (!context) {
      return;
    }
    context.clearRect(0, 0, size, size);
    if (!ready) {
      return;
    }
    const [x, y] = thumbOrigin(size, zoom, centre);
    if (bodySprite) {
      drawSprite(context, bodySprite, x, y, zoom);
    }
    markings.forEach((marking, index) => {
      const sprite = markingSprites[index] as Sprite;
      drawSprite(context, tintedSprite(sprite, marking.color), x, y, zoom);
    });
    if (painted) {
      drawPainted(
        context,
        painted.pixels,
        x - ((painted.width - 32) / 2) * zoom,
        y,
        zoom,
      );
    }
  }, [
    ready,
    !!bodySprite,
    size,
    zoom,
    centre[0],
    centre[1],
    body,
    key.join(),
    painted?.pixels,
    painted?.width,
  ]);

  return (
    <canvas
      ref={canvas}
      className={className}
      width={size}
      height={size}
      aria-hidden="true"
    />
  );
}, samePicture);

/** Callers rebuild the small marking arrays while hovering; compare their drawing inputs. */
function samePicture(previous: Props, next: Props) {
  if (
    previous.size !== next.size ||
    previous.zoom !== next.zoom ||
    previous.centre[0] !== next.centre[0] ||
    previous.centre[1] !== next.centre[1] ||
    previous.body !== next.body ||
    previous.className !== next.className ||
    previous.painted?.width !== next.painted?.width ||
    previous.painted?.pixels !== next.painted?.pixels
  ) {
    return false;
  }
  const before = previous.markings ?? [];
  const after = next.markings ?? [];
  return (
    before.length === after.length &&
    before.every(
      (marking, index) =>
        marking.icon === after[index].icon &&
        marking.color === after[index].color &&
        marking.nativeIcon === after[index].nativeIcon,
    )
  );
}

/** Whether a marking draws nothing facing south, as one drawn only on the back; undefined until known. */
export function useBlankMarking(icon: string | undefined) {
  const [sprite] = useSprites([icon]);
  return sprite ? isBlankSprite(sprite) : undefined;
}
