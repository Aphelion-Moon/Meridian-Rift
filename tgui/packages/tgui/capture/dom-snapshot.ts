// THIS IS AN APHELION UI FILE

import { drawnFontFaces } from './font-faces';
import type { Reason } from './overlay';
import { createStyleCopier } from './style-copy';
import { cloneNode } from './vendor/clone-node';
import { embedImages } from './vendor/embed-images';
import { embedWebFonts } from './vendor/embed-webfonts';
import type { Options } from './vendor/types';

/** A part of the snapshot, each side a fraction of the whole from 0 to 1 */
export type Crop = { x: number; y: number; width: number; height: number };

/** A snapshot turned down on purpose, with its reason for the overlay and the server to put in words */
export class SnapshotRefusal extends Error {
  constructor(readonly reason: Reason) {
    super(reason);
  }
}

export const MAX_NODES = 5000;
export const MAX_SIDE = 4096;
/**
 * Most characters of SVG a snapshot may build. Drawing it costs its renderer about 20.5 bytes a character
 * and a window's renderer dies near 2.5 GB, so this keeps a snapshot near 1 GB at its peak
 */
export const MAX_SVG_CHARS = 50_000_000;
const SVG_NS = 'http://www.w3.org/2000/svg';
/** The snapshot is drawn no bigger than this, plenty for a bug report */
const DRAWN_WIDTH = 1600;
const DRAWN_HEIGHT = 1200;
/** Lossless when it fits the server's limit, then WebP at falling quality */
const ENCODINGS: [string, number | undefined][] = [
  ['image/png', undefined],
  ['image/webp', 0.92],
  ['image/webp', 0.8],
  ['image/webp', 0.6],
];
/**
 * Computed properties a still picture can't show. html-to-image copies every other one onto every cloned node
 * (705 in Chromium 152), so leaving these out cut cloning and the SVG by about an eighth, pixel for pixel the same
 */
const STILL_IRRELEVANT =
  /^(-webkit-)?(animation|transition|will-change|cursor|caret|pointer-events|user-select|user-modify|user-drag|touch-action|scroll-(behavior|margin|padding|snap|timeline|initial-target|marker|target)|overscroll|view-transition|view-timeline|timeline-scope|speak|page-break|break-(after|before|inside)|orphans|widows|interactivity|interpolate-size|app-region|tap-highlight-color|print-color-adjust|anchor-name|anchor-scope|position-anchor|position-try|reading-flow|reading-order)/;
/**
 * Legacy shorthands Chromium lists among the computed longhands. Written back, `-webkit-border-image` means `fill`,
 * so the Scavenger frame's border image covered the whole snapshot with its texture
 */
const LEGACY_SHORTHANDS = new Set(['-webkit-border-image']);
const SCROLL_MARKER = 'data-meridian-report-scroll';
const LAYOUT_STYLES = [
  'display',
  'flex-direction',
  'flex-wrap',
  'align-items',
  'justify-content',
  'gap',
  'grid-template-columns',
  'grid-template-rows',
];

/** How many snapshots this window has started, so each marks its scrolled boxes with its own values */
let snapshots = 0;

/** One DOM reconstruction of the selected UI, drawn on a canvas. This is not an OS or window screenshot */
export async function renderUiSnapshot(
  root: HTMLElement,
): Promise<HTMLCanvasElement> {
  const nodes: HTMLElement[] = [root];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
  while (walker.nextNode()) {
    if (nodes.length >= MAX_NODES) throw new SnapshotRefusal('too_big');
    nodes.push(walker.currentNode as HTMLElement);
  }
  const bounds = root.getBoundingClientRect();
  const width = Math.ceil(bounds.width);
  const height = Math.ceil(bounds.height);
  if (width > MAX_SIDE || height > MAX_SIDE)
    throw new SnapshotRefusal('too_big');
  if (!width || !height) throw new SnapshotRefusal('empty');
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);
  const scrolling = nodes.filter((node) => node.scrollTop || node.scrollLeft);
  // A stuck snapshot can still be drawing, so we mark with values of our own and take off only the marks still ours
  const snapshot = ++snapshots;
  const marks = scrolling.map((_, index) => `${snapshot}-${index}`);
  // Computed values already have every var() filled in, so a variable only adds size, and the Aphelion
  // theme's inherited images made that 125 KB a node
  const names = Array.from(getComputedStyle(document.documentElement)).filter(
    (name) =>
      !name.startsWith('--') &&
      !STILL_IRRELEVANT.test(name) &&
      !LEGACY_SHORTHANDS.has(name),
  );
  // Each clone carries only what its SVG wouldn't compute anyway, which made the SVG about a tenth the size
  const copier = createStyleCopier(root, nodes, names);
  const options: Options = {
    width,
    height,
    pixelRatio: 1,
    includeStyleProperties: names,
    copier,
    // The page loads a face only to draw with it, so we leave out the faces it never loaded, about 90K characters.
    // This reads their statuses, so it stays right after the layout getBoundingClientRect forced above, as taking
    // off a sheet with @font-face makes every CSS face a new unloaded one until the next layout
    fontFaces: drawnFontFaces(document.fonts),
    fetchRequestInit: { signal: controller.signal, credentials: 'same-origin' },
    filter: (node) =>
      !['SCRIPT', 'IFRAME', 'VIDEO'].includes(node.tagName) &&
      !(node instanceof HTMLInputElement && node.type === 'password'),
  };
  try {
    for (const [index, node] of scrolling.entries()) {
      node.setAttribute(SCROLL_MARKER, marks[index]);
    }
    const clone = await cloneNode(root, options, true);
    if (!clone) throw new Error('Could not snapshot this UI.');
    // A clone drops scroll offsets, so we shift each scrolled box's contents in the clone only
    scrolling.forEach((source, index) => {
      const target =
        clone.getAttribute(SCROLL_MARKER) === marks[index]
          ? clone
          : clone.querySelector<HTMLElement>(
              `[${SCROLL_MARKER}="${marks[index]}"]`,
            );
      if (!target) return;
      const content = document.createElement('div');
      const style = getComputedStyle(source);
      for (const property of LAYOUT_STYLES) {
        content.style.setProperty(property, style.getPropertyValue(property));
      }
      content.style.width = `${source.scrollWidth}px`;
      content.style.transform = `translate(${-source.scrollLeft}px, ${-source.scrollTop}px)`;
      while (target.firstChild) content.appendChild(target.firstChild);
      target.appendChild(content);
      Object.assign(target.style, {
        display: 'block',
        overflow: 'hidden',
        width: `${source.offsetWidth}px`,
        height: `${source.offsetHeight}px`,
      });
    });
    Object.assign(clone.style, {
      margin: '0',
      width: `${width}px`,
      height: `${height}px`,
      overflow: 'hidden',
    });
    await embedWebFonts(clone, options);
    await embedImages(clone, options);
    if (controller.signal.aborted) throw new SnapshotRefusal('timed_out');
    const image = await decodeImage(svgDataUrl(clone, width, height));
    const scale = Math.min(1, DRAWN_WIDTH / width, DRAWN_HEIGHT / height);
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(width * scale));
    canvas.height = Math.max(1, Math.round(height * scale));
    const context = canvas.getContext('2d');
    if (!context) throw new Error('This client cannot draw a UI snapshot.');
    context.fillStyle =
      getComputedStyle(document.body).backgroundColor || '#171717';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    return canvas;
  } finally {
    copier?.release();
    clearTimeout(timeout);
    scrolling.forEach((node, index) => {
      if (node.getAttribute(SCROLL_MARKER) === marks[index]) {
        node.removeAttribute(SCROLL_MARKER);
      }
    });
  }
}

/**
 * The SVG as an image ready to draw, like html-to-image's createImage, except a decode that fails refuses the
 * snapshot where createImage would never settle
 */
function decodeImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () =>
      image.decode().then(
        () => requestAnimationFrame(() => resolve(image)),
        // Most likely a picture too big for the renderer to hold
        () => reject(new SnapshotRefusal('too_big')),
      );
    image.onerror = reject;
    image.crossOrigin = 'anonymous';
    image.decoding = 'async';
    image.src = url;
  });
}

/**
 * The clone in an SVG as a data URL, built the way html-to-image's nodeToDataURL builds it, refused before the
 * URL exists when the SVG is over the budget
 */
export function svgDataUrl(
  node: HTMLElement,
  width: number,
  height: number,
  budget = MAX_SVG_CHARS,
): string {
  const svg = document.createElementNS(SVG_NS, 'svg');
  const foreignObject = document.createElementNS(SVG_NS, 'foreignObject');
  svg.setAttribute('width', `${width}`);
  svg.setAttribute('height', `${height}`);
  svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  foreignObject.setAttribute('width', '100%');
  foreignObject.setAttribute('height', '100%');
  foreignObject.setAttribute('x', '0');
  foreignObject.setAttribute('y', '0');
  foreignObject.setAttribute('externalResourcesRequired', 'true');
  svg.appendChild(foreignObject);
  foreignObject.appendChild(node);
  const text = new XMLSerializer().serializeToString(svg);
  // The renderer would decode the whole thing at once and die partway, taking the window with it
  if (text.length > budget) throw new SnapshotRefusal('too_big');
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(text)}`;
}

/** The canvas, or the cropped part of it, as image base64 */
function encode(
  canvas: HTMLCanvasElement,
  type: string,
  quality?: number,
): Promise<string | null> {
  return new Promise((resolve) =>
    canvas.toBlob(
      (blob) => {
        // A browser without the type hands back a PNG, which was already tried
        if (!blob || blob.type !== type) return resolve(null);
        const reader = new FileReader();
        reader.onload = () => {
          const url = String(reader.result);
          resolve(url.slice(url.indexOf(',') + 1));
        };
        reader.onerror = () => resolve(null);
        reader.readAsDataURL(blob);
      },
      type,
      quality,
    ),
  );
}

/** Encodes the snapshot, or a crop of it, as base64 within the server's limit */
export async function encodeSnapshot(
  source: HTMLCanvasElement,
  limit: number,
  crop?: Crop,
): Promise<string> {
  let canvas = source;
  if (crop) {
    canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(crop.width * source.width));
    canvas.height = Math.max(1, Math.round(crop.height * source.height));
    canvas
      .getContext('2d')
      ?.drawImage(
        source,
        crop.x * source.width,
        crop.y * source.height,
        crop.width * source.width,
        crop.height * source.height,
        0,
        0,
        canvas.width,
        canvas.height,
      );
  }
  for (const [type, quality] of ENCODINGS) {
    const base64 = await encode(canvas, type, quality);
    if (base64 && base64.length <= limit) return base64;
  }
  throw new SnapshotRefusal('too_big');
}
