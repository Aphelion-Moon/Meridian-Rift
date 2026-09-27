// THIS IS AN APHELION UI FILE
import { sendAct as act } from 'tgui/events/act';
import { clamp } from 'tgui-core/math';
import { colorsAreEqual, parseHexColorString } from '../../colorSpaces';
import {
  constrainToIconGrid,
  copyLayer,
  isPainted,
  isWithinDrawBounds,
} from '../../helpers';
import { strokeLayer } from '../../strokeMask';
import { Tool } from '../Tool';
import type {
  BaseCopyResult,
  Dir,
  SelectionBounds,
  SelectionMask,
  SpriteData,
  SpriteEditorToolCancelContext,
  SpriteEditorToolContext,
  StringLayer,
} from '../types';

const CLEAR = '#00000000';
/** The server's index characters: value N is character N, and dots mark pixels that stay. */
const CODES =
  '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';

/**
 * A finished frame as the server takes a placed selection: the box around every changed pixel, the
 * new values used in it, and the box as one or two index characters per pixel. A full canvas stays
 * within one small message, where a list of pixels would not.
 */
const encodePlacement = (source: StringLayer, frame: StringLayer) => {
  const area: SelectionBounds = [Infinity, Infinity, -1, -1];
  const values = new Map<string, number>();
  for (let y = 0; y < frame.length; y++) {
    for (let x = 0; x < frame[y].length; x++) {
      if (frame[y][x] === source[y][x]) continue;
      area[0] = Math.min(area[0], x);
      area[1] = Math.min(area[1], y);
      area[2] = Math.max(area[2], x);
      area[3] = Math.max(area[3], y);
      if (!values.has(frame[y][x])) values.set(frame[y][x], values.size);
    }
  }
  if (area[2] < 0) return undefined;
  const digits = values.size <= CODES.length ? 1 : 2;
  const codes: string[] = [];
  for (let y = area[1]; y <= area[3]; y++) {
    for (let x = area[0]; x <= area[2]; x++) {
      if (frame[y][x] === source[y][x]) {
        codes.push('.'.repeat(digits));
        continue;
      }
      const index = values.get(frame[y][x])!;
      codes.push(
        digits === 1
          ? CODES[index]
          : CODES[Math.floor(index / CODES.length)] +
              CODES[index % CODES.length],
      );
    }
  }
  return { area, palette: [...values.keys()], digits, codes: codes.join('') };
};

const framesEqual = (left: StringLayer, right: StringLayer) =>
  left.length === right.length &&
  left.every(
    (row, y) =>
      row.length === right[y].length &&
      row.every((pixel, x) => {
        if (pixel === right[y][x]) return true;
        const a = parseHexColorString(pixel);
        const b = parseHexColorString(right[y][x]);
        return (a.a === 0 && b.a === 0) || colorsAreEqual(a, b);
      }),
  );

/** A pixel as x, y and color. Selection paint is kept relative to the selection box's top-left. */
type Pixel = [number, number, string];

/** The painted pixels of a frame inside the box and its mask, relative to the box. */
const liftPixels = (
  frame: StringLayer,
  rect: SelectionBounds,
  mask?: SelectionMask,
) => {
  const [left, top, right, bottom] = rect;
  const pixels: Pixel[] = [];
  for (let y = Math.max(top, 0); y <= Math.min(bottom, frame.length - 1); y++) {
    const row = frame[y];
    for (let x = Math.max(left, 0); x <= Math.min(right, row.length - 1); x++) {
      if (mask && mask[y - top][x - left] !== '1') continue;
      if (isPainted(row[x])) pixels.push([x - left, y - top, row[x]]);
    }
  }
  return pixels;
};

/** A copy of the frame with the pixels drawn at left, top. Pixels that land off the canvas are left out. */
const stamp = (
  frame: StringLayer,
  pixels: Pixel[],
  left: number,
  top: number,
) => {
  const out = copyLayer(frame);
  for (const [px, py, color] of pixels) {
    const row = out[top + py];
    if (row && left + px >= 0 && left + px < row.length) row[left + px] = color;
  }
  return out;
};

/** A mask a quarter turn round: 1 clockwise, -1 counter-clockwise. */
const turnMask = (mask: SelectionMask, turn: 1 | -1): SelectionMask => {
  const height = mask.length;
  const width = mask[0].length;
  return Array.from({ length: width }, (_, y) =>
    Array.from({ length: height }, (_, x) =>
      turn > 0 ? mask[height - 1 - x][y] : mask[x][width - 1 - y],
    ).join(''),
  );
};

/** Whether every pixel, drawn with its box at left, top, lands on the canvas where paint is allowed. */
const landsAt = (
  context: SpriteEditorToolContext,
  data: SpriteData,
  pixels: Pixel[],
  left: number,
  top: number,
) =>
  pixels.every(([px, py]) => {
    const [x, y] = [left + px, top + py];
    return (
      x >= 0 &&
      y >= 0 &&
      x < data.width &&
      y < data.height &&
      isWithinDrawBounds(x, y, context.drawBounds, context.drawMask)
    );
  });

/** A mask mirrored left to right. */
const flipMask = (mask: SelectionMask): SelectionMask =>
  mask.map((row) => [...row].reverse().join(''));

/** Frames drawn over one another in order, later ones on top, as a merged copy sees them. */
const flatten = (frames: StringLayer[]) =>
  frames[0].map((row, y) =>
    row.map((_pixel, x) => {
      for (let index = frames.length - 1; index >= 0; index--) {
        const pixel = frames[index][y]?.[x];
        if (isPainted(pixel)) return pixel;
      }
      return CLEAR;
    }),
  );

/** The server layer paint goes to, as transactions name it. */
type LayerRef = ReturnType<typeof strokeLayer>;

const sameLayer = (a: LayerRef, b: LayerRef) =>
  a.layer === b.layer && a.layerId === b.layerId;

/**
 * The selection with a rectangle taken out of it, tightened around what's left: a plain box when
 * nothing inside it is missing. Undefined when nothing is left.
 */
const subtractRect = (
  rect: SelectionBounds,
  mask: SelectionMask | undefined,
  cut: SelectionBounds,
): [SelectionBounds, SelectionMask | undefined] | undefined => {
  const [left, top, right, bottom] = rect;
  const rows: string[] = [];
  const kept: SelectionBounds = [Infinity, Infinity, -Infinity, -Infinity];
  for (let y = top; y <= bottom; y++) {
    let row = '';
    for (let x = left; x <= right; x++) {
      const selected =
        (!mask || mask[y - top][x - left] === '1') &&
        !(x >= cut[0] && x <= cut[2] && y >= cut[1] && y <= cut[3]);
      row += selected ? '1' : '0';
      if (selected) {
        kept[0] = Math.min(kept[0], x);
        kept[1] = Math.min(kept[1], y);
        kept[2] = Math.max(kept[2], x);
        kept[3] = Math.max(kept[3], y);
      }
    }
    rows.push(row);
  }
  if (kept[2] < kept[0]) return undefined;
  const tight = rows
    .slice(kept[1] - top, kept[3] - top + 1)
    .map((row) => row.slice(kept[0] - left, kept[2] - left + 1));
  return [kept, tight.some((row) => row.includes('0')) ? tight : undefined];
};

/**
 * Paint that follows the selection box instead of sitting in the canvas: lifted off it by a move that
 * didn't all land on the canvas, pasted, or turned. It is written to the canvas only when dropped.
 */
type BaseCopy = {
  width: number;
  request: number;
  source: string;
  origin: [number, number];
  height: number;
};

type Floating = {
  dir: Dir;
  layer: number;
  target: LayerRef;
  /** The frame as it was when the paint was lifted or pasted; the drop is measured against it. */
  source: StringLayer;
  /** source without the lifted paint. */
  base: StringLayer;
  pixels: Pixel[];
  /** It floats only because a move didn't all land, so a drag that lands all of it writes it. */
  moved?: boolean;
  baseCopy?: BaseCopy;
};

type SelectionDrag = {
  dir: Dir;
  layer: number;
  target: LayerRef;
  origin: [number, number];
} & (
  | { mode: 'select'; bounds: SelectionBounds }
  | { mode: 'subtract'; bounds: SelectionBounds; rect: SelectionBounds }
  | {
      mode: 'move';
      rect: SelectionBounds;
      offset: [number, number];
      /** The paint this drag picked up off the canvas; floating paint already travels with the box. */
      lift?: { frame: StringLayer; pixels: Pixel[] };
      preview?: StringLayer;
    }
);

/**
 * Selects a box, or a box with pixels taken out of it, and moves, copies, cuts, pastes and turns its
 * paint. Where the canvas shows one of several layers, each gesture keeps to the layer it began on.
 *
 * Dragging is free, even off the canvas. A move that lands entirely on paintable pixels is sent at
 * once, as one history step. Paint that doesn't fit, pasted paint and turned paint float with the box
 * instead, and only reach the canvas when the marquee goes away (release()): then anything off the
 * canvas or outside the paintable area is cut. Pointer movement stays in the window. Editors that
 * support temporary character previews receive one preview placement after a floating gesture;
 * only a finished move or drop changes the server's draft.
 */
export class Select extends Tool {
  icon = 'vector-square';
  name = 'Select';
  private selection?: SelectionBounds;
  private mask?: SelectionMask;
  private floating?: Floating;
  private drag?: SelectionDrag;
  private pending?: {
    dir: Dir;
    layer: number;
    target: LayerRef;
    source: StringLayer;
    frames: StringLayer[];
  };
  /** What Ctrl+C copied, where it came from, for pasting into any view. */
  private clipboard?: {
    rect: SelectionBounds;
    mask?: SelectionMask;
    pixels: Pixel[];
    baseCopy?: BaseCopy;
  };
  private copyRequest = 0;
  private pendingBaseCopy?: {
    request: number;
    source: string;
    rect: SelectionBounds;
    mask?: SelectionMask;
    frame: StringLayer;
  };
  /** The paintable area from the last full context, so a drop from a bare cancel context still cuts to it. */
  private area?: Pick<SpriteEditorToolContext, 'drawBounds' | 'drawMask'>;
  /** Whether the character thumbnail currently has a temporary floating-paint preview. */
  private serverPreview = false;

  private clearServerPreview() {
    if (!this.serverPreview) return;
    this.serverPreview = false;
    act('previewSelection', { transaction: null });
  }

  /** Previews a finished gesture without committing its floating paint or sending pointer moves. */
  private previewFloating(data: SpriteData) {
    const floating = this.floating;
    if (!data.selectionPreview || !floating || !this.selection) return;
    const frame = this.floatingFrame(floating, this.selection);
    const placement = encodePlacement(floating.source, frame);
    if (!placement) {
      this.clearServerPreview();
      return;
    }
    this.serverPreview = true;
    act('previewSelection', {
      transaction: {
        dir: String(floating.dir),
        ...placement,
        ...(floating.baseCopy && {
          baseCopy: floating.baseCopy.request,
          baseCopySource: floating.baseCopy.source,
        }),
      },
    });
  }

  /** The legal part of floating paint, exactly as dropping it would place it. */
  private floatingFrame(floating: Floating, selection: SelectionBounds) {
    const [left, top] = selection;
    const frame = copyLayer(floating.base);
    for (const [px, py, color] of floating.pixels) {
      const [x, y] = [left + px, top + py];
      if (
        frame[y]?.[x] !== undefined &&
        isWithinDrawBounds(x, y, this.area?.drawBounds, this.area?.drawMask)
      ) {
        frame[y][x] = color;
      }
    }
    return frame;
  }

  private reconcilePending(context: SpriteEditorToolContext, data: SpriteData) {
    this.area = { drawBounds: context.drawBounds, drawMask: context.drawMask };
    const source =
      data.layers[context.selectedLayer]?.data[context.selectedDir];
    const target = strokeLayer(data, context.selectedLayer);
    const pending = this.pending;
    if (pending) {
      if (
        !source ||
        pending.dir !== context.selectedDir ||
        pending.layer !== context.selectedLayer ||
        !sameLayer(pending.target, target)
      ) {
        this.pending = undefined;
        this.drag = undefined;
      } else if (!framesEqual(source, pending.source)) {
        const acknowledged = pending.frames.findLastIndex((frame) =>
          framesEqual(frame, source),
        );
        if (acknowledged === -1) {
          // Undo or an external edit supersedes the optimistic sequence.
          this.pending = undefined;
          this.drag = undefined;
        } else {
          pending.source = copyLayer(source);
          pending.frames = pending.frames.slice(acknowledged + 1);
          if (!pending.frames.length) this.pending = undefined;
        }
      }
    } else if (
      this.drag?.mode === 'move' &&
      this.drag.lift &&
      (!source || !framesEqual(source, this.drag.lift.frame))
    ) {
      this.drag = undefined;
    }
    // Floating paint belongs to the frame it came off; an edit that isn't one of ours throws it away.
    const floating = this.floating;
    const current = this.pending?.frames.at(-1) ?? source;
    if (
      floating &&
      (floating.dir !== context.selectedDir ||
        floating.layer !== context.selectedLayer ||
        !sameLayer(floating.target, target) ||
        !current ||
        !framesEqual(current, floating.source))
    ) {
      this.floating = undefined;
      this.drag = undefined;
      this.clearServerPreview();
      this.setSelection(context, undefined, undefined);
    }
  }

  /** Shows the drag, then floating paint, then moves the server hasn't confirmed yet. */
  private showPreview(context: SpriteEditorToolCancelContext) {
    const moving = this.drag?.mode === 'move' ? this.drag : undefined;
    const floating = this.floating;
    let layer = moving?.layer;
    let preview = moving?.preview;
    if (!preview && floating && this.selection) {
      layer = floating.layer;
      preview = stamp(
        floating.base,
        floating.pixels,
        this.selection[0],
        this.selection[1],
      );
    }
    if (!preview && this.pending) {
      layer = this.pending.layer;
      preview = this.pending.frames.at(-1);
    }
    context.setPreviewLayer(preview ? layer : undefined);
    context.setPreviewData(preview);
  }

  reconcile(context: SpriteEditorToolContext, data: SpriteData) {
    this.reconcilePending(context, data);
    this.showPreview(context);
  }

  private setSelection(
    context: SpriteEditorToolCancelContext,
    selection?: SelectionBounds,
    mask?: SelectionMask,
  ) {
    const sameBox =
      selection === this.selection ||
      (!!selection &&
        !!this.selection &&
        selection.every((value, i) => value === this.selection![i]));
    const sameMask = mask === this.mask;
    this.selection = selection;
    this.mask = mask;
    if (!sameBox) context.setSelectionBounds?.(selection);
    if (!sameMask) context.setSelectionMask?.(mask);
  }

  /** Whether a canvas pixel is inside the selection: in its box, and in its mask when it has one. */
  private selects(x: number, y: number) {
    const rect = this.selection;
    if (!rect || x < rect[0] || y < rect[1] || x > rect[2] || y > rect[3]) {
      return false;
    }
    return !this.mask || this.mask[y - rect[1]][x - rect[0]] === '1';
  }

  /** The frame a new edit applies to: the latest optimistic move, or the server's frame. */
  private currentFrame(context: SpriteEditorToolContext, data: SpriteData) {
    const source =
      data.layers[context.selectedLayer]?.data[context.selectedDir];
    return source && copyLayer(this.pending?.frames.at(-1) ?? source);
  }

  /** Sends a finished frame as one history step and shows it until the server confirms it. */
  private commitFrame(
    dir: Dir,
    layer: number,
    target: LayerRef,
    source: StringLayer,
    frame: StringLayer,
    baseCopy?: BaseCopy,
  ) {
    const placement = encodePlacement(source, frame);
    if (!placement) return;
    if (
      this.pending?.dir !== dir ||
      this.pending.layer !== layer ||
      !sameLayer(this.pending.target, target)
    ) {
      this.pending = { dir, layer, target, source, frames: [] };
    }
    this.pending.frames.push(frame);
    act('spriteEditorCommand', {
      command: 'transaction',
      transaction: {
        type: 'move',
        name: 'Move selection',
        ...target,
        dir: String(dir),
        ...placement,
        ...(baseCopy && {
          baseCopy: baseCopy.request,
          baseCopySource: baseCopy.source,
        }),
      },
    });
  }

  /**
   * Writes floating paint into its frame, cutting whatever lands off the canvas or the paintable area.
   *
   * Returns whether there was floating paint, so callers can show the frame it left behind.
   */
  private drop(context: SpriteEditorToolCancelContext) {
    this.clearServerPreview();
    const floating = this.floating;
    this.floating = undefined;
    if (!floating || !this.selection) return false;
    const frame = this.floatingFrame(floating, this.selection);
    this.commitFrame(
      floating.dir,
      floating.layer,
      floating.target,
      floating.source,
      frame,
      floating.baseCopy,
    );
    return true;
  }

  /** Lifts the selected paint off the canvas so it floats with the box. */
  private float(context: SpriteEditorToolContext, data: SpriteData) {
    const source = this.currentFrame(context, data);
    if (!source || !this.selection) return false;
    const pixels = liftPixels(source, this.selection, this.mask);
    const base = copyLayer(source);
    for (const [px, py] of pixels) {
      base[this.selection[1] + py][this.selection[0] + px] = CLEAR;
    }
    this.floating = {
      dir: context.selectedDir,
      layer: context.selectedLayer,
      target: strokeLayer(data, context.selectedLayer),
      source,
      base,
      pixels,
    };
    return true;
  }

  onMouseDown(
    context: SpriteEditorToolContext,
    data: SpriteData,
    x: number,
    y: number,
    isRightClick = false,
  ) {
    this.reconcilePending(context, data);
    const { width, height } = data;
    const [px, py, inBounds] = constrainToIconGrid(x, y, width, height);
    if (!inBounds) return;
    this.clearServerPreview();
    const bounds: SelectionBounds = [0, 0, width - 1, height - 1];
    const base = {
      dir: context.selectedDir,
      layer: context.selectedLayer,
      target: strokeLayer(data, context.selectedLayer),
      origin: [px, py] as [number, number],
    };
    if (isRightClick) {
      // The right button takes pixels out of the selection. Floating paint is dropped first.
      if (!this.selection) return;
      if (this.drop(context)) this.showPreview(context);
      this.drag = { ...base, mode: 'subtract', bounds, rect: [px, py, px, py] };
      this.showSubtraction(context);
      return true;
    }
    if (this.selects(px, py)) {
      const rect = this.selection!;
      if (this.floating) {
        this.drag = { ...base, mode: 'move', rect, offset: [0, 0] };
        return true;
      }
      // A following drag may begin before the previous move is acknowledged.
      const frame = this.currentFrame(context, data);
      if (!frame) return;
      this.drag = {
        ...base,
        mode: 'move',
        rect,
        offset: [0, 0],
        lift: { frame, pixels: liftPixels(frame, rect, this.mask) },
      };
      return true;
    }
    // A new marquee drops any floating paint where it is.
    if (this.drop(context)) this.showPreview(context);
    this.drag = { ...base, mode: 'select', bounds };
    this.setSelection(context, [px, py, px, py], undefined);
    return true;
  }

  /** Shows the selection as it will be once the dragged rectangle is taken out of it. */
  private showSubtraction(context: SpriteEditorToolCancelContext) {
    if (this.drag?.mode !== 'subtract' || !this.selection) return;
    const result = subtractRect(this.selection, this.mask, this.drag.rect);
    context.setSelectionBounds?.(result?.[0]);
    context.setSelectionMask?.(result?.[1]);
  }

  onMouseMove(
    context: SpriteEditorToolContext,
    data: SpriteData,
    x: number,
    y: number,
  ) {
    const drag = this.drag;
    if (!drag) return;
    if (
      drag.dir !== context.selectedDir ||
      drag.layer !== context.selectedLayer ||
      !sameLayer(drag.target, strokeLayer(data, context.selectedLayer))
    ) {
      this.cancel(context);
      return;
    }
    const [ox, oy] = drag.origin;
    if (drag.mode !== 'move') {
      const [left, top, right, bottom] = drag.bounds;
      const px = clamp(Math.floor(x), left, right);
      const py = clamp(Math.floor(y), top, bottom);
      const rect: SelectionBounds = [
        Math.min(ox, px),
        Math.min(oy, py),
        Math.max(ox, px),
        Math.max(oy, py),
      ];
      if (drag.mode === 'select') {
        this.setSelection(context, rect, undefined);
      } else if (rect.some((value, i) => value !== drag.rect[i])) {
        drag.rect = rect;
        this.showSubtraction(context);
      }
      return;
    }
    const [sx, sy, ex, ey] = drag.rect;
    // Free to leave the canvas, but part of the box always stays on it so it can be grabbed again.
    const dx = clamp(Math.floor(x) - ox, -ex, data.width - 1 - sx);
    const dy = clamp(Math.floor(y) - oy, -ey, data.height - 1 - sy);
    if (dx === drag.offset[0] && dy === drag.offset[1]) return;
    drag.offset = [dx, dy];
    this.setSelection(context, [sx + dx, sy + dy, ex + dx, ey + dy], this.mask);
    const lift = drag.lift;
    if (!lift || (!dx && !dy) || !lift.pixels.length) {
      drag.preview = undefined;
      this.showPreview(context);
      return;
    }
    const preview = copyLayer(lift.frame);
    for (const [px, py] of lift.pixels) preview[sy + py][sx + px] = CLEAR;
    drag.preview = stamp(preview, lift.pixels, sx + dx, sy + dy);
    this.showPreview(context);
  }

  onMouseUp(
    context: SpriteEditorToolContext,
    data: SpriteData,
    x: number,
    y: number,
  ) {
    this.onMouseMove(context, data, x, y);
    const drag = this.drag;
    this.drag = undefined;
    if (drag?.mode === 'subtract') {
      const result = this.selection
        ? subtractRect(this.selection, this.mask, drag.rect)
        : undefined;
      // The drag showed each step, so the marquee is set outright.
      this.selection = result?.[0];
      this.mask = result?.[1];
      context.setSelectionBounds?.(this.selection);
      context.setSelectionMask?.(this.mask);
      return;
    }
    if (drag?.mode !== 'move') return;
    const lift = drag.lift;
    const [dx, dy] = drag.offset;
    const floating = this.floating;
    if (!lift) {
      // Paint that floats only because a move didn't all land is written once a drag lands all of it.
      if (
        floating?.moved &&
        (dx || dy) &&
        this.selection &&
        landsAt(
          context,
          data,
          floating.pixels,
          this.selection[0],
          this.selection[1],
        )
      ) {
        this.drop(context);
      }
      this.showPreview(context);
      this.previewFloating(data);
      return;
    }
    const changed = drag.preview?.some((row, py) =>
      row.some((pixel, px) => pixel !== lift.frame[py][px]),
    );
    if (!changed) {
      this.showPreview(context);
      this.previewFloating(data);
      return;
    }
    const [sx, sy, ex, ey] = drag.rect;
    if (!landsAt(context, data, lift.pixels, sx + dx, sy + dy)) {
      // Paint that doesn't all land on the canvas floats with the box until it's dropped.
      const base = copyLayer(lift.frame);
      for (const [px, py] of lift.pixels) base[sy + py][sx + px] = CLEAR;
      this.floating = {
        dir: drag.dir,
        layer: drag.layer,
        target: drag.target,
        source: lift.frame,
        base,
        pixels: lift.pixels,
        moved: true,
      };
      this.showPreview(context);
      this.previewFloating(data);
      return;
    }
    if (
      this.mask ||
      sx + dx < 0 ||
      sy + dy < 0 ||
      ex + dx >= data.width ||
      ey + dy >= data.height
    ) {
      // Only a whole box on the canvas can travel as a box and offset.
      this.commitFrame(
        drag.dir,
        drag.layer,
        drag.target,
        lift.frame,
        drag.preview!,
      );
      this.showPreview(context);
      return;
    }
    this.pending ??= {
      dir: drag.dir,
      layer: drag.layer,
      target: drag.target,
      source: lift.frame,
      frames: [],
    };
    this.pending.frames.push(drag.preview!);
    act('spriteEditorCommand', {
      command: 'transaction',
      transaction: {
        type: 'move',
        name: 'Move selection',
        ...drag.target,
        dir: String(drag.dir),
        rect: drag.rect,
        offset: drag.offset,
      },
    });
  }

  /**
   * Ctrl+C: keeps the selection's shape and paint, floating or not, for pasting into any view.
   *
   * Returns whether there was a selection to copy.
   */
  copy(context: SpriteEditorToolContext, data: SpriteData) {
    this.pendingBaseCopy = undefined;
    this.reconcilePending(context, data);
    const rect = this.selection;
    if (!rect || this.drag) return false;
    const pixels = this.floating
      ? this.floating.pixels
      : liftPixels(this.currentFrame(context, data) ?? [], rect, this.mask);
    this.clipboard = {
      rect: [...rect],
      mask: this.mask,
      pixels: pixels.map((pixel) => [...pixel] as Pixel),
      baseCopy: this.floating?.baseCopy,
    };
    return true;
  }

  /**
   * Ctrl+X: copies the selection, then takes its paint off the canvas in one history step. Floating
   * paint goes too: lifted paint has already left the canvas, and pasted paint never reached it. The
   * marquee stays.
   *
   * Returns whether there was a selection to cut.
   */
  cut(context: SpriteEditorToolContext, data: SpriteData) {
    if (!this.copy(context, data)) return false;
    const rect = this.selection!;
    const floating = this.floating;
    if (floating) {
      this.floating = undefined;
      this.clearServerPreview();
      this.commitFrame(
        floating.dir,
        floating.layer,
        floating.target,
        floating.source,
        floating.base,
      );
    } else {
      const source = this.currentFrame(context, data);
      if (!source) return true;
      const frame = copyLayer(source);
      for (const [px, py] of liftPixels(source, rect, this.mask)) {
        frame[rect[1] + py][rect[0] + px] = CLEAR;
      }
      this.commitFrame(
        context.selectedDir,
        context.selectedLayer,
        strokeLayer(data, context.selectedLayer),
        source,
        frame,
      );
    }
    this.showPreview(context);
    return true;
  }

  /**
   * Ctrl+Shift+C, or Ctrl+C while Merged is lit: copies the selection as the view shows it, the
   * view's other paint layers included. The layers are composed here; only the native base pixels
   * are asked of the server, and a canvas with no base to copy is copied at once.
   *
   * Returns whether there was a selection to copy.
   */
  copyMerged(context: SpriteEditorToolContext, data: SpriteData) {
    this.reconcilePending(context, data);
    const rect = this.selection;
    if (!rect || this.drag) return false;
    const own = this.floating
      ? this.floatingFrame(this.floating, rect)
      : this.currentFrame(context, data);
    if (!own) return false;
    const merge = data.mergeLayers?.();
    const frame =
      merge?.dir === context.selectedDir
        ? flatten([...merge.below, own, ...merge.above])
        : own;
    if (!data.baseCopyInfo) {
      this.pendingBaseCopy = undefined;
      this.clipboard = {
        rect: [...rect],
        mask: this.mask,
        pixels: liftPixels(frame, rect, this.mask),
      };
      return true;
    }
    this.copyRequest = (this.copyRequest % 1000000000) + 1;
    const request = this.copyRequest;
    this.pendingBaseCopy = {
      request,
      source: data.baseCopyInfo.source,
      rect: [...rect],
      mask: this.mask?.slice(),
      frame,
    };
    act('copyBaseLayer', {
      request,
      dir: String(context.selectedDir),
      rect: [...rect],
      mask: this.mask,
    });
    return true;
  }

  /** An old or cancelled response cannot overwrite a newer clipboard. */
  receiveBaseCopy(result: BaseCopyResult) {
    const pending = this.pendingBaseCopy;
    if (!pending || result.request !== pending.request) return false;
    this.pendingBaseCopy = undefined;
    if (
      result.error ||
      result.source !== pending.source ||
      result.height !== pending.frame.length ||
      result.width !== pending.frame[0]?.length ||
      result.codes.length !== result.width * result.height
    ) {
      return false;
    }
    const frame = copyLayer(pending.frame);
    for (let y = 0; y < result.height; y++) {
      for (let x = 0; x < result.width; x++) {
        if (!isPainted(frame[y][x])) {
          frame[y][x] =
            result.palette[CODES.indexOf(result.codes[y * result.width + x])];
        }
      }
    }
    this.clipboard = {
      rect: pending.rect,
      mask: pending.mask,
      pixels: liftPixels(frame, pending.rect, pending.mask),
      baseCopy: {
        width: result.width,
        request: result.request,
        source: result.source,
        origin: result.origin,
        height: result.height,
      },
    };
    return true;
  }

  /**
   * Ctrl+V: floats the copied paint in this view where it was copied from, with part of it kept on
   * the canvas. Floating paint already here is dropped first.
   *
   * Returns whether there was anything to paste.
   */
  paste(context: SpriteEditorToolContext, data: SpriteData) {
    this.reconcilePending(context, data);
    const clip = this.clipboard;
    if (!clip || this.drag) return false;
    const [left, top, right, bottom] = clip.rect;
    const base = clip.baseCopy;
    const destination = data.baseCopyInfo;
    if (base && base.source !== destination?.source) {
      act('baseCopyProblem', { problem: 'context' });
      return true;
    }
    const x = base
      ? left +
        (data.width - base.width) / 2 +
        base.origin[0] -
        destination!.origin[0]
      : clamp(left, left - right, data.width - 1);
    const y = base
      ? top +
        data.height -
        base.height -
        base.origin[1] +
        destination!.origin[1]
      : clamp(top, top - bottom, data.height - 1);
    if (
      base &&
      clip.pixels.some(
        ([px, py]) =>
          x + px < 0 ||
          x + px >= data.width ||
          y + py < 0 ||
          y + py >= data.height ||
          !isWithinDrawBounds(
            x + px,
            y + py,
            context.drawBounds,
            context.drawMask,
          ),
      )
    ) {
      act('baseCopyProblem', { problem: 'bounds' });
      return true;
    }
    this.drop(context);
    const source = this.currentFrame(context, data);
    if (!source) return false;
    this.floating = {
      dir: context.selectedDir,
      layer: context.selectedLayer,
      target: strokeLayer(data, context.selectedLayer),
      source,
      base: copyLayer(source),
      pixels: clip.pixels.map((pixel) => [...pixel] as Pixel),
      baseCopy: clip.baseCopy,
    };
    this.setSelection(
      context,
      [x, y, x + right - left, y + bottom - top],
      clip.mask,
    );
    this.showPreview(context);
    this.previewFloating(data);
    return true;
  }

  /**
   * Turns the selection a quarter turn about its middle: 1 clockwise, -1 counter-clockwise. Paint
   * still on the canvas is lifted to float with the box first.
   *
   * Returns whether there was a selection to turn.
   */
  rotate(context: SpriteEditorToolContext, data: SpriteData, turn: 1 | -1) {
    this.reconcilePending(context, data);
    const rect = this.selection;
    if (!rect || this.drag || (!this.floating && !this.float(context, data))) {
      return false;
    }
    const floating = this.floating!;
    // Turned paint floats until the marquee goes away, wherever it lands.
    floating.moved = false;
    const width = rect[2] - rect[0] + 1;
    const height = rect[3] - rect[1] + 1;
    floating.pixels = floating.pixels.map(([x, y, color]) =>
      turn > 0 ? [height - 1 - y, x, color] : [y, width - 1 - x, color],
    );
    // Truncating both ways keeps four turns, or a turn and its reverse, where they started.
    const left = clamp(
      rect[0] + Math.trunc((width - height) / 2),
      1 - height,
      data.width - 1,
    );
    const top = clamp(
      rect[1] + Math.trunc((height - width) / 2),
      1 - width,
      data.height - 1,
    );
    this.setSelection(
      context,
      [left, top, left + height - 1, top + width - 1],
      this.mask && turnMask(this.mask, turn),
    );
    this.showPreview(context);
    this.previewFloating(data);
    return true;
  }

  /**
   * Mirrors the selection left to right about its middle. Paint still on the canvas is lifted to
   * float with the box first.
   *
   * Returns whether there was a selection to mirror.
   */
  flip(context: SpriteEditorToolContext, data: SpriteData) {
    this.reconcilePending(context, data);
    const rect = this.selection;
    if (!rect || this.drag || (!this.floating && !this.float(context, data))) {
      return false;
    }
    const floating = this.floating!;
    // Mirrored paint floats until the marquee goes away, wherever it lands.
    floating.moved = false;
    const width = rect[2] - rect[0] + 1;
    floating.pixels = floating.pixels.map(([x, y, color]) => [
      width - 1 - x,
      y,
      color,
    ]);
    this.setSelection(context, [...rect], this.mask && flipMask(this.mask));
    this.showPreview(context);
    this.previewFloating(data);
    return true;
  }

  /** Whether there is a marquee for Enter to take away. */
  hasSelection() {
    return !!this.selection;
  }

  /** Whether there is floating paint that dropping the selection would write. */
  isFloating() {
    return !!this.floating;
  }

  /**
   * The marquee goes away, as when the tool or view changes, Enter is pressed or the editor closes:
   * floating paint is dropped onto its canvas, and moves already sent stay shown until confirmed.
   */
  release(context: SpriteEditorToolCancelContext) {
    this.drag = undefined;
    this.drop(context);
    this.selection = undefined;
    this.mask = undefined;
    context.setSelectionBounds?.(undefined);
    context.setSelectionMask?.(undefined);
    this.showPreview(context);
  }

  /** Escape and history: the selection and any floating paint are thrown away. */
  cancel(context: SpriteEditorToolCancelContext) {
    this.pendingBaseCopy = undefined;
    this.clearServerPreview();
    this.drag = undefined;
    this.selection = undefined;
    this.mask = undefined;
    this.floating = undefined;
    this.pending = undefined;
    context.setPreviewLayer(undefined);
    context.setPreviewData(undefined);
    context.setSelectionBounds?.(undefined);
    context.setSelectionMask?.(undefined);
  }
}
