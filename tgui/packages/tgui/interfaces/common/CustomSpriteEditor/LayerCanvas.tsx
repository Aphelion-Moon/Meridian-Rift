// THIS IS AN APHELION UI FILE
import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Tooltip } from 'tgui-core/components';
import {
  asWorn,
  drawOrder,
  drawStack,
  type Fate,
  frameCanvas,
  layerFate,
  type StackItem,
  type StackLayer,
  type TryOnHat,
} from './appendages';

/**
 * Images by URL, loaded once each for drawing on canvases. An image is in the record once it has
 * loaded, and the record is replaced only then.
 */
export const useLoadedImages = (urls: (string | undefined)[]) => {
  const [images, setImages] = useState<Record<string, HTMLImageElement>>({});
  useEffect(() => {
    let live = true;
    for (const url of urls) {
      if (!url || images[url]) continue;
      const image = new Image();
      image.onload = () => {
        if (live) setImages((current) => ({ ...current, [url]: image }));
      };
      image.src = url;
    }
    return () => {
      live = false;
    };
  }, [urls.join('\n')]);
  return images;
};

/**
 * A hat's front view cropped to its own pixels and doubled, for the "Hats that cover it" chips.
 * Undefined until the view has loaded.
 */
export const hatChip = (view: HTMLImageElement | undefined) => {
  if (!view?.naturalWidth) return undefined;
  const source = document.createElement('canvas');
  source.width = view.naturalWidth;
  source.height = view.naturalHeight;
  const context = source.getContext('2d');
  if (!context) return undefined;
  context.drawImage(view, 0, 0);
  const { data, width, height } = context.getImageData(
    0,
    0,
    source.width,
    source.height,
  );
  let [left, top, right, bottom] = [width, height, -1, -1];
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (!data[(y * width + x) * 4 + 3]) continue;
      left = Math.min(left, x);
      top = Math.min(top, y);
      right = Math.max(right, x);
      bottom = Math.max(bottom, y);
    }
  }
  if (right < 0) return undefined;
  const chip = document.createElement('canvas');
  chip.width = (right - left + 1) * 2;
  chip.height = (bottom - top + 1) * 2;
  const drawn = chip.getContext('2d');
  if (!drawn) return undefined;
  drawn.imageSmoothingEnabled = false;
  drawn.drawImage(
    source,
    left,
    top,
    right - left + 1,
    bottom - top + 1,
    0,
    0,
    chip.width,
    chip.height,
  );
  return chip.toDataURL();
};

/** The guide and the layers under the one being painted, drawn at the canvas's own size. */
export const composeBackground = (
  guide: CanvasImageSource | undefined,
  items: StackItem[],
  hatImage: CanvasImageSource | undefined,
  width: number,
  height: number,
) => {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) return canvas;
  context.imageSmoothingEnabled = false;
  if (guide) context.drawImage(guide, 0, 0, width, height);
  drawStack(context, items, width, height, hatImage);
  return canvas;
};

type LayerOverlayProps = {
  items: StackItem[];
  hatImage: CanvasImageSource | undefined;
  hatch: { cells: Set<number>; fate: Fate } | null;
  imageWidth: number;
  imageHeight: number;
  canvasWidth: number;
  canvasHeight: number;
  /** The row where the ordinary 32-row canvas begins on a tall one, dashed across. */
  tallRow?: number;
};

/** What the game draws over the layer being painted, and its hatching, without catching the pointer. */
/** The overlay's theme colours, and the root classes they were read under. */
let overlayColors: { theme: string; over: string; accent: string } | undefined;

/**
 * The theme's colours, as its stylesheet sets them for the layer controls. Reading them forces a
 * style recalculation, which every draw would pay, so they're kept until the theme changes.
 */
const themeColors = (canvas: HTMLCanvasElement) => {
  const theme = document.documentElement.className;
  if (overlayColors?.theme !== theme) {
    const style = getComputedStyle(canvas);
    const themed = (name: string, fallback: string) =>
      style.getPropertyValue(name).trim() || fallback;
    overlayColors = {
      theme,
      over: themed('--appendage-over', '#ffb547'),
      accent: themed('--appendage-accent', '#56d4dc'),
    };
  }
  return overlayColors;
};

export const LayerOverlay = (props: LayerOverlayProps) => {
  const {
    items,
    hatImage,
    hatch,
    imageWidth,
    imageHeight,
    canvasWidth,
    canvasHeight,
    tallRow,
  } = props;
  const ref = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    const canvas = ref.current;
    const context = canvas?.getContext('2d');
    if (!canvas || !context || !imageWidth || !imageHeight) return;
    context.clearRect(0, 0, canvasWidth, canvasHeight);
    const scale = canvasWidth / imageWidth;
    const colors = themeColors(canvas);
    drawStack(
      context,
      items,
      canvasWidth,
      canvasHeight,
      hatImage,
      hatch
        ? {
            ...hatch,
            columns: imageWidth,
            scale,
            hiddenColor: colors.over,
          }
        : undefined,
    );
    if (tallRow) {
      context.save();
      context.setLineDash([6, 4]);
      context.globalAlpha = 0.45;
      context.strokeStyle = colors.accent;
      context.beginPath();
      context.moveTo(0, tallRow * scale + 0.5);
      context.lineTo(canvasWidth, tallRow * scale + 0.5);
      context.stroke();
      context.restore();
    }
  }, [
    items,
    hatImage,
    hatch,
    imageWidth,
    imageHeight,
    canvasWidth,
    canvasHeight,
    tallRow,
  ]);
  return (
    <canvas
      ref={ref}
      className="CustomSpriteEditor__overlay"
      width={canvasWidth}
      height={canvasHeight}
    />
  );
};

/**
 * One view as worn under `hat`, at the canvas's own size: the guide, the hair and under-hat pieces
 * trimmed as the hat trims them, the hat, then the over-hat pieces it doesn't hide.
 */
export const composeWorn = (
  guide: CanvasImageSource | undefined,
  layers: StackLayer[],
  hat: TryOnHat | null,
  hatImage: CanvasImageSource | undefined,
  dir: string,
  width: number,
  height: number,
) => {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) return canvas;
  context.imageSmoothingEnabled = false;
  if (guide) context.drawImage(guide, 0, 0, width, height);
  let hatDrawn = false;
  const drawHat = () => {
    if (hatImage && !hatDrawn) context.drawImage(hatImage, 0, 0, width, height);
    hatDrawn = true;
  };
  for (const layer of drawOrder(layers)) {
    if (layer.appendage?.outer) drawHat();
    const frame = asWorn(
      layer.frame,
      layerFate(layer.appendage, hat),
      hat?.masks[dir],
    );
    if (frame) context.drawImage(frameCanvas(frame), 0, 0, width, height);
  }
  drawHat();
  return canvas;
};

/** The head's box on the canvas, which the Try on thumbnails show. */
const thumbnailBox = (height: number) =>
  [8, Math.max(0, height - 32 - (height > 32 ? 6 : 0)), 16, 16] as const;

const TryOnThumbnail = (props: { view: HTMLCanvasElement }) => {
  const ref = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    const context = ref.current?.getContext('2d');
    if (!context) return;
    context.imageSmoothingEnabled = false;
    context.clearRect(0, 0, 48, 48);
    const [x, y, w, h] = thumbnailBox(props.view.height);
    context.drawImage(props.view, x, y, w, h, 0, 0, 48, 48);
  }, [props.view]);
  return <canvas ref={ref} width={48} height={48} />;
};

type TryOnProps = {
  hats: Record<string, TryOnHat>;
  selected: string | null;
  /** Hat key, or '' for no hat -> the view as worn. */
  views: Record<string, HTMLCanvasElement>;
  onSelect: (hat: string | null) => void;
};

/** Hats to preview the appendages under, each shown on the head in the view being painted. */
export const TryOn = (props: TryOnProps) => {
  const { hats, selected, views, onSelect } = props;
  const options: [string | null, string, string][] = [
    [null, 'No hat', 'Take the hat off'],
    ...Object.entries(hats).map(
      ([key, hat]) => [key, hat.label, hat.group] as [string, string, string],
    ),
  ];
  return (
    <div className="CustomSpriteEditor__tryOn">
      <div className="CustomSpriteEditor__subhead">Try on</div>
      <div className="CustomSpriteEditor__hats">
        {options.map(([key, label, title]) => (
          <Tooltip key={key ?? ''} content={title}>
            <button
              type="button"
              className="CustomSpriteEditor__hat"
              aria-pressed={selected === key}
              onClick={() => onSelect(key)}
            >
              {!!views[key ?? ''] && <TryOnThumbnail view={views[key ?? '']} />}
              <span>{label}</span>
            </button>
          </Tooltip>
        ))}
      </div>
    </div>
  );
};
