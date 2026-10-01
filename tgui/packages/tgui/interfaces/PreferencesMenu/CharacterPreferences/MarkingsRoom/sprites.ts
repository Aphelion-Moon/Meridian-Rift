// THIS IS AN APHELION UI FILE
import { useEffect, useState, useSyncExternalStore } from 'react';

/**
 * Spritesheet cells drawn on canvases: a species body from its sheet, a
 * marking from the preferences sheet, tinted as the game tints it. A class
 * names a cell; its sheet and place are read off the class's own style, once
 * the sheet's stylesheet has loaded.
 */

/** Where a spritesheet class draws from: its sheet, and the cell's top left and size there. */
export type SpriteCell = {
  url: string;
  x: number;
  y: number;
  width: number;
  height: number;
};

const cells = new Map<string, SpriteCell>();
let probe: HTMLSpanElement | undefined;
const PROBE_STYLE =
  'position:absolute;left:-9999px;top:0;visibility:hidden;pointer-events:none';

/** A class's cell from a probe's computed style, kept; undefined while its stylesheet hasn't loaded. */
function readCell(className: string, style: CSSStyleDeclaration) {
  const url = /url\(["']?(.*?)["']?\)/.exec(style.backgroundImage)?.[1];
  if (!url) {
    return undefined;
  }
  const [x = 0, y = 0] = style.backgroundPosition
    .split(' ')
    .map((part) => -Number.parseFloat(part) || 0);
  const cell = {
    url,
    x,
    y,
    width: Number.parseFloat(style.width) || 32,
    height: Number.parseFloat(style.height) || 32,
  };
  cells.set(className, cell);
  return cell;
}

/** Where a spritesheet class draws from, or undefined while its stylesheet hasn't loaded. */
export function spriteCell(className: string): SpriteCell | undefined {
  const known = cells.get(className);
  if (known) {
    return known;
  }
  if (!probe) {
    probe = document.createElement('span');
    probe.setAttribute('aria-hidden', 'true');
    probe.style.cssText = PROBE_STYLE;
    document.body.appendChild(probe);
  }
  probe.className = className;
  return readCell(className, getComputedStyle(probe));
}

/**
 * Looks up many classes' cells at once, for a sheet of thumbnails about to be
 * drawn: one style pass for all of them, where spriteCell takes one each.
 */
export function primeSpriteCells(classNames: (string | undefined)[]) {
  const unknown = Array.from(
    new Set(
      classNames.filter((name): name is string => !!name && !cells.has(name)),
    ),
  );
  if (unknown.length < 2) {
    return;
  }
  const host = document.createElement('div');
  host.setAttribute('aria-hidden', 'true');
  host.style.cssText = PROBE_STYLE;
  const probes = unknown.map((name) => {
    const span = document.createElement('span');
    span.className = name;
    host.appendChild(span);
    return span;
  });
  document.body.appendChild(host);
  unknown.forEach((name, index) => {
    readCell(name, getComputedStyle(probes[index]));
  });
  host.remove();
}

// Stylesheets arriving: a sheet sent later, like the species bodies, brings its cells with it.
let sheets = 0;
const sheetListeners = new Set<() => void>();
let watching = false;

const sheetsChanged = () => {
  sheets++;
  for (const listener of sheetListeners) {
    listener();
  }
};

/**
 * A stylesheet loaded, wherever it is: tgui's asset loader adds its sheets to
 * the body, not the head. The loader turns a sheet on (its media to all) in
 * its own load handler, which runs after this one, so look once it has.
 */
function sheetLoaded(event: Event) {
  const node = event.target;
  if (node instanceof HTMLLinkElement && node.rel === 'stylesheet') {
    setTimeout(sheetsChanged);
  }
}

function watchSheets(listener: () => void) {
  sheetListeners.add(listener);
  if (!watching && typeof document !== 'undefined') {
    watching = true;
    // Load events don't bubble, but they can be caught on the way down.
    document.addEventListener('load', sheetLoaded, true);
    // Styles written into the page, as the dev server writes them.
    if (typeof MutationObserver !== 'undefined') {
      new MutationObserver((records) => {
        if (
          records.some((record) =>
            [...record.addedNodes].some(
              (node) => node instanceof HTMLStyleElement,
            ),
          )
        ) {
          sheetsChanged();
        }
      }).observe(document.head, { childList: true });
    }
  }
  return () => {
    sheetListeners.delete(listener);
  };
}

/** Counts the stylesheets that have loaded since the page opened, so a cell missing before can be looked for again. */
export const useSheets = () => useSyncExternalStore(watchSheets, () => sheets);

const images = new Map<string, HTMLImageElement>();
// Each sheet decoded off the page's thread, to draw from. Drawn from as an
// image, a sheet is decoded on the thread, all of it at once, the first time a
// thumbnail draws from it; so is an ImageBitmap made from the image. One made
// from the file decodes on a worker. A sheet is ready once it is decoded, or
// once that fails and it is drawn from the image after all.
const bitmaps = new Map<string, ImageBitmap>();
const decodings = new Map<string, Promise<unknown>>();

const loadedImage = (image: HTMLImageElement | undefined) =>
  !!image?.complete && image.naturalWidth > 0;

/** Whether a loaded sheet can be drawn from: decoded, or not decodable apart. */
function decoded(url: string, image: HTMLImageElement) {
  if (
    typeof createImageBitmap !== 'function' ||
    !(image instanceof HTMLImageElement) ||
    bitmaps.has(url)
  ) {
    return true;
  }
  if (!decodings.has(url)) {
    decodings.set(
      url,
      fetch(url)
        .then((response) =>
          response.ok ? response.blob() : Promise.reject(response.status),
        )
        .then((file) => createImageBitmap(file))
        .then(
          (bitmap) => bitmaps.set(url, bitmap),
          () => undefined,
        ),
    );
    return false;
  }
  // Settled without a bitmap: the image itself it is.
  return decodings.get(url) === settled;
}
const settled = Promise.resolve();

/** Sheets indexed by their own URL, once loaded and decoded; different native sizes have different sheets. */
function useSheetImages(urls: string[]) {
  const key = JSON.stringify(urls);
  const [, loaded] = useState(0);
  useEffect(() => {
    const wanted: string[] = JSON.parse(key);
    const pending: [HTMLImageElement, () => void][] = [];
    let alive = true;
    const done = () => {
      if (alive) {
        loaded((count) => count + 1);
      }
    };
    // Loaded: decoded next, then drawn.
    const decode = (url: string, image: HTMLImageElement) => {
      if (decoded(url, image)) {
        done();
        return;
      }
      decodings.get(url)?.then(() => {
        if (!bitmaps.has(url)) {
          decodings.set(url, settled);
        }
        done();
      });
    };
    for (const url of wanted) {
      let image = images.get(url);
      // Newly created images can finish synchronously from the browser cache;
      // images already in our cache were available during render.
      const fresh = !image;
      if (!image) {
        image = new Image();
        images.set(url, image);
        image.src = url;
      }
      const sheet = image;
      if (!loadedImage(sheet)) {
        const onLoad = () => decode(url, sheet);
        sheet.addEventListener('load', onLoad, { once: true });
        pending.push([sheet, onLoad]);
      } else if (fresh || !decoded(url, sheet)) {
        // Decoding (perhaps started during render): heard of once it is.
        decode(url, sheet);
      }
    }
    return () => {
      alive = false;
      for (const [image, onLoad] of pending) {
        image.removeEventListener('load', onLoad);
      }
    };
  }, [key]);
  return new Map(
    urls.map((url) => {
      const image = images.get(url);
      return [
        url,
        image && loadedImage(image) && decoded(url, image) ? image : undefined,
      ];
    }),
  );
}

/** A sheet's image, once it has loaded. */
export function useSheetImage(url: string | undefined) {
  return useSheetImages(url ? [url] : []).get(url ?? '');
}

/** The cells of these classes and their sheets' images, once all of them can be drawn. */
export function useSprites(classNames: (string | undefined)[]) {
  useSheets();
  const found = classNames.map((name) => (name ? spriteCell(name) : undefined));
  const urls = Array.from(
    new Set(found.flatMap((cell) => (cell ? [cell.url] : []))),
  );
  const sheets = useSheetImages(urls);
  return found.map((cell) => {
    const image = cell && sheets.get(cell.url);
    return cell && image
      ? { cell, image, source: bitmaps.get(cell.url) ?? image }
      : undefined;
  });
}

/** A cell and its sheet: the image, and what to draw from (the sheet decoded, or the image). */
export type Sprite = {
  cell: SpriteCell;
  image: HTMLImageElement;
  source?: CanvasImageSource;
};

const tinted = new Map<string, HTMLCanvasElement>();

/**
 * A cell coloured as the game colours a marking: the colour multiplied in,
 * the cell's own alpha kept. Kept for the next thumbnail of the same colour.
 */
export function tintedSprite(sprite: Sprite, color: string) {
  const { cell } = sprite;
  const image = sprite.source ?? sprite.image;
  const key = `${cell.url} ${cell.x} ${cell.y} ${color}`;
  const known = tinted.get(key);
  if (known) {
    return known;
  }
  const canvas = document.createElement('canvas');
  canvas.width = cell.width;
  canvas.height = cell.height;
  const context = canvas.getContext('2d');
  if (context) {
    context.imageSmoothingEnabled = false;
    context.drawImage(
      image,
      cell.x,
      cell.y,
      cell.width,
      cell.height,
      0,
      0,
      cell.width,
      cell.height,
    );
    context.globalCompositeOperation = 'multiply';
    context.fillStyle = color;
    context.fillRect(0, 0, cell.width, cell.height);
    context.globalCompositeOperation = 'destination-in';
    context.drawImage(
      image,
      cell.x,
      cell.y,
      cell.width,
      cell.height,
      0,
      0,
      cell.width,
      cell.height,
    );
  }
  if (tinted.size > 512) {
    tinted.clear();
  }
  tinted.set(key, canvas);
  return canvas;
}

const blanks = new Map<string, boolean>();
/** One canvas to read cells back on: a canvas each would cost more to set up than to read. */
let scratch: CanvasRenderingContext2D | null | undefined;

/**
 * Whether a cell draws nothing at all, as a marking drawn only on the back
 * does facing south. Undefined when its pixels can't be read.
 */
export function isBlankSprite(sprite: Sprite): boolean | undefined {
  const { cell } = sprite;
  const image = sprite.source ?? sprite.image;
  const key = `${cell.url} ${cell.x} ${cell.y}`;
  if (blanks.has(key)) {
    return blanks.get(key);
  }
  if (scratch === undefined) {
    scratch = document
      .createElement('canvas')
      .getContext('2d', { willReadFrequently: true });
  }
  const context = scratch;
  if (!context) {
    return undefined;
  }
  if (
    context.canvas.width < cell.width ||
    context.canvas.height < cell.height
  ) {
    context.canvas.width = Math.max(context.canvas.width, cell.width);
    context.canvas.height = Math.max(context.canvas.height, cell.height);
  }
  context.clearRect(0, 0, cell.width, cell.height);
  context.drawImage(
    image,
    cell.x,
    cell.y,
    cell.width,
    cell.height,
    0,
    0,
    cell.width,
    cell.height,
  );
  let blank: boolean;
  try {
    const { data } = context.getImageData(0, 0, cell.width, cell.height);
    blank = true;
    for (let alpha = 3; alpha < data.length; alpha += 4) {
      if (data[alpha]) {
        blank = false;
        break;
      }
    }
  } catch {
    // A sheet from another origin can be drawn but not read.
    return undefined;
  }
  blanks.set(key, blank);
  return blank;
}

/** Draws a whole cell at a whole-number zoom, optionally aligned to a tile's bottom instead of its top. */
export function drawSprite(
  context: CanvasRenderingContext2D,
  source: Sprite | HTMLCanvasElement,
  x: number,
  y: number,
  zoom: number,
  tileHeight?: number,
) {
  context.imageSmoothingEnabled = false;
  if (tileHeight !== undefined) {
    const height =
      source instanceof HTMLCanvasElement ? source.height : source.cell.height;
    y += (tileHeight - height) * zoom;
  }
  if (source instanceof HTMLCanvasElement) {
    context.drawImage(source, x, y, source.width * zoom, source.height * zoom);
    return;
  }
  const { cell } = source;
  context.drawImage(
    source.source ?? source.image,
    cell.x,
    cell.y,
    cell.width,
    cell.height,
    x,
    y,
    cell.width * zoom,
    cell.height * zoom,
  );
}
