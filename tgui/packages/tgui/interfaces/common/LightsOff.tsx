// THIS IS AN APHELION UI FILE
import { Button } from 'tgui-core/components';

/**
 * Previews with their lights off, to see what glows. Beside a picture, the
 * server draws its glow, only while a window has its lights off: the look's
 * emissive plane, red where something glows and blooms, green where it glows
 * without, and black where something drawn over it hides the glow. The page
 * lights the picture as the game's lighting plate does in an unlit room: every
 * pixel is multiplied by its light, which is the dark's own light plus the
 * bloom's falling on it, and a pixel that glows keeps its own colour. Matched
 * to the game's own render of a character in the dark (see the module doc).
 */

/** The light an unlit room leaves, as the game showed it for a character in the dark. */
export const LIGHTS_OFF_AMBIENT = 0.1;

/** The dark laid over what stands behind a picture, so it keeps the same light. */
export const LIGHTS_OFF_SHADE = `rgb(0 0 0 / ${Math.round((1 - LIGHTS_OFF_AMBIENT) * 100)}%)`;

/** The bloom the game draws for a player who hasn't picked one (DEFAULT_EMISSIVE_BLOOM_SIZE). */
export const DEFAULT_BLOOM = 2;

/** The largest bloom a player can pick (MAXIMUM_EMISSIVE_BLOOM_SIZE). */
const MAX_BLOOM = 5;

/**
 * The game's bloom filter, as its render showed it at size 2: what blooms grows
 * by the filter's offset, blurs with a Gaussian 1.2 times its size across, and
 * lights what it falls on at 0.95 of its colour.
 */
const BLOOM_SIGMA_PER_SIZE = 1.2;
const BLOOM_STRENGTH = 0.95;

/** A bloom setting as the game reads it, or the default when there's none. */
export const bloomSize = (value: unknown) =>
  typeof value === 'number'
    ? Math.min(MAX_BLOOM, Math.max(0, Math.round(value)))
    : DEFAULT_BLOOM;

/** How far the bloom grows what blooms before blurring it: the filter's offset. */
export const bloomOffset = (bloom: number) => Math.ceil(bloom / 2);

/** How widely the bloom blurs, as a Gaussian's standard deviation in picture pixels. */
export const bloomSigma = (bloom: number) => bloom * BLOOM_SIGMA_PER_SIZE;

/** How far a bloom's light reaches past what blooms, in picture pixels. */
export const bloomReach = (bloom: number) =>
  bloom > 0 ? bloomOffset(bloom) + Math.ceil(2.5 * bloomSigma(bloom)) : 0;

/**
 * What blooms: the picture's colours under red glow, as strongly as the glow
 * covers them, on opaque black, or undefined when nothing blooms. `glow` is the
 * picture's glow at the same size.
 */
export function bloomSource(
  picture: Uint8ClampedArray,
  glow: Uint8ClampedArray,
): Uint8ClampedArray<ArrayBuffer> | undefined {
  let source: Uint8ClampedArray<ArrayBuffer> | undefined;
  for (let index = 0; index < picture.length; index += 4) {
    const blooms = (glow[index] / 255) * (glow[index + 3] / 255);
    if (blooms <= 0 || !picture[index + 3]) {
      continue;
    }
    if (!source) {
      source = new Uint8ClampedArray(picture.length);
      for (let alpha = 3; alpha < source.length; alpha += 4) {
        source[alpha] = 255;
      }
    }
    source[index] = picture[index] * blooms;
    source[index + 1] = picture[index + 1] * blooms;
    source[index + 2] = picture[index + 2] * blooms;
  }
  return source;
}

/**
 * A tile repeated over an area as pixels, as a page's background tile shows
 * under it: the area's pixel at (x, y) shows the tile's at (x + left, y + top),
 * wrapped round the tile.
 */
export function tiledFloor(
  tile: Uint8ClampedArray,
  tileWidth: number,
  tileHeight: number,
  width: number,
  height: number,
  left: number,
  top: number,
): Uint8ClampedArray<ArrayBuffer> {
  const floor = new Uint8ClampedArray(width * height * 4);
  const wrap = (value: number, size: number) => ((value % size) + size) % size;
  for (let y = 0; y < height; y++) {
    const row = wrap(y + top, tileHeight) * tileWidth;
    for (let x = 0; x < width; x++) {
      const from = (row + wrap(x + left, tileWidth)) * 4;
      const to = (y * width + x) * 4;
      floor[to] = tile[from];
      floor[to + 1] = tile[from + 1];
      floor[to + 2] = tile[from + 2];
      floor[to + 3] = tile[from + 3];
    }
  }
  return floor;
}

/**
 * A picture lit with its lights off, padded `reach` pixels on every side: each
 * pixel's colour times its light, as the game's lighting plate multiplies it.
 * Its light is the dark's own (`ambient`) plus the bloom's falling on it; a
 * pixel that glows has its light raised to full as far as its glow covers it,
 * keeping its own colour. `bloomLight` is the bloom's light at each padded
 * pixel, 255 for its full colour. Where the picture is clear, `floor` (padded,
 * as `tiledFloor()` makes it) shows lit by the bloom, so the halo falls on it
 * as it does on the floor in game; elsewhere the page's own dark shows.
 */
export function lightsOffPixels(
  picture: Uint8ClampedArray,
  glow: Uint8ClampedArray | undefined,
  width: number,
  height: number,
  reach = 0,
  bloomLight?: Uint8ClampedArray,
  floor?: Uint8ClampedArray,
  ambient = LIGHTS_OFF_AMBIENT,
): Uint8ClampedArray<ArrayBuffer> {
  const paddedWidth = width + 2 * reach;
  const paddedHeight = height + 2 * reach;
  const lit = new Uint8ClampedArray(paddedWidth * paddedHeight * 4);
  const light = [ambient, ambient, ambient];
  for (let y = 0; y < paddedHeight; y++) {
    for (let x = 0; x < paddedWidth; x++) {
      const index = (y * paddedWidth + x) * 4;
      const pictureX = x - reach;
      const pictureY = y - reach;
      const inside =
        pictureX >= 0 && pictureY >= 0 && pictureX < width && pictureY < height;
      const from = inside ? (pictureY * width + pictureX) * 4 : -1;
      const alpha = inside ? picture[from + 3] / 255 : 0;
      const floorAlpha = floor ? floor[index + 3] / 255 : 0;
      if (!alpha && !floorAlpha) {
        continue;
      }
      let bloomed = false;
      for (let channel = 0; channel < 3; channel++) {
        const bloom = bloomLight
          ? (bloomLight[index + channel] / 255) * BLOOM_STRENGTH
          : 0;
        light[channel] = ambient + bloom;
        bloomed ||= bloom >= 1 / 255;
      }
      // The emissive plate lights red and green alike; a blocker covers nothing.
      const cover =
        inside && glow
          ? Math.min(1, (glow[from] + glow[from + 1]) / 255) *
            (glow[from + 3] / 255)
          : 0;
      const showsFloor = floorAlpha > 0 && alpha < 1 && (bloomed || alpha > 0);
      const underAlpha = showsFloor ? floorAlpha * (1 - alpha) : 0;
      const combinedAlpha = alpha + underAlpha;
      for (let channel = 0; channel < 3; channel++) {
        const shine = cover + (1 - cover) * light[channel];
        const own = inside ? picture[from + channel] * shine * alpha : 0;
        const under = showsFloor
          ? floor![index + channel] * light[channel] * underAlpha
          : 0;
        lit[index + channel] =
          combinedAlpha > 0 ? (own + under) / combinedAlpha : 0;
      }
      lit[index + 3] = combinedAlpha * 255;
    }
  }
  return lit;
}

/** A canvas of a size, and its context. */
function scratch(width: number, height: number) {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d', { willReadFrequently: true });
  return context ? { canvas, context } : undefined;
}

/** What a source shows at a size, as pixels. */
export function pixelsOf(
  source: CanvasImageSource,
  width: number,
  height: number,
) {
  const drawn = scratch(width, height);
  if (!drawn) {
    return undefined;
  }
  drawn.context.imageSmoothingEnabled = false;
  drawn.context.drawImage(source, 0, 0, width, height);
  return drawn.context.getImageData(0, 0, width, height).data;
}

/**
 * The bloom's light over a picture padded `reach` pixels on every side, as the
 * game's bloom filter spreads it: what blooms, grown by the filter's offset,
 * then blurred. Undefined when nothing blooms or the bloom is off.
 */
function bloomLightOf(
  picture: Uint8ClampedArray,
  glow: Uint8ClampedArray,
  width: number,
  height: number,
  bloom: number,
  reach: number,
) {
  const source = bloom > 0 ? bloomSource(picture, glow) : undefined;
  const sourceCanvas = source && scratch(width, height);
  const paddedWidth = width + 2 * reach;
  const paddedHeight = height + 2 * reach;
  const grown = scratch(paddedWidth, paddedHeight);
  const blurred = scratch(paddedWidth, paddedHeight);
  if (!source || !sourceCanvas || !grown || !blurred) {
    return undefined;
  }
  sourceCanvas.context.putImageData(new ImageData(source, width, height), 0, 0);
  grown.context.fillStyle = '#000';
  grown.context.fillRect(0, 0, paddedWidth, paddedHeight);
  // The offset grows what blooms by its brightest neighbours.
  grown.context.globalCompositeOperation = 'lighten';
  const offset = bloomOffset(bloom);
  for (let x = -offset; x <= offset; x++) {
    for (let y = -offset; y <= offset; y++) {
      grown.context.drawImage(sourceCanvas.canvas, reach + x, reach + y);
    }
  }
  blurred.context.filter = `blur(${bloomSigma(bloom)}px)`;
  blurred.context.drawImage(grown.canvas, 0, 0);
  return blurred.context.getImageData(0, 0, paddedWidth, paddedHeight).data;
}

/**
 * Draws a picture lit with its lights off onto `target`, padded `reach` pixels
 * on every side so the bloom has room; see lightsOffPixels(). `glow` is the
 * picture's glow at the same size, or undefined when nothing in it glows, and
 * `floor` what lies under it, padded the same, or undefined for none.
 * `ambient` is the room's own light, the dark's by default.
 */
export function drawLightsOff(
  target: CanvasRenderingContext2D,
  picture: CanvasImageSource,
  glow: CanvasImageSource | undefined,
  width: number,
  height: number,
  bloom: number,
  reach = 0,
  floor?: Uint8ClampedArray,
  ambient = LIGHTS_OFF_AMBIENT,
) {
  target.clearRect(0, 0, target.canvas.width, target.canvas.height);
  const pixels = pixelsOf(picture, width, height);
  if (!pixels) {
    return;
  }
  const glowPixels = glow && pixelsOf(glow, width, height);
  const bloomLight =
    glowPixels && bloomLightOf(pixels, glowPixels, width, height, bloom, reach);
  const lit = lightsOffPixels(
    pixels,
    glowPixels,
    width,
    height,
    reach,
    bloomLight,
    floor,
    ambient,
  );
  target.putImageData(
    new ImageData(lit, width + 2 * reach, height + 2 * reach),
    0,
    0,
  );
}

type LightsButtonProps = {
  /** Whether the lights are off. */
  off: boolean;
  onToggle: () => void;
  fontSize?: string;
  tooltipPosition?: 'top' | 'bottom';
};

/** Turns a preview's lights off, to see what glows, or on again. Lit while they're off. */
export function LightsButton(props: LightsButtonProps) {
  const { off, onToggle, fontSize, tooltipPosition = 'bottom' } = props;
  const label = off ? 'Lights on' : 'Lights off: see what glows';
  return (
    <Button
      fontSize={fontSize}
      icon="lightbulb"
      selected={off}
      aria-label={label}
      aria-pressed={off}
      tooltip={label}
      tooltipPosition={tooltipPosition}
      onClick={onToggle}
    />
  );
}
