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
import { Tool } from '../Tool';
import type {
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
type Floating = {
  dir: Dir;
  layer: number;
  /** The frame as it was when the paint was lifted or pasted; the drop is measured against it. */
  source: StringLayer;
  /** source without the lifted paint. */
  base: StringLayer;
  pixels: Pixel[];
  /** It floats only because a move didn't all land, so a drag that lands all of it writes it. */
  moved?: boolean;
};

type SelectionDrag = {
  dir: Dir;
  layer: number;
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
 * Selects a box, or a box with pixels taken out of it, and moves, copies, pastes and turns its paint.
 *
 * Dragging is free, even off the canvas. A move that lands entirely on paintable pixels is sent at
 * once, as one history step. Paint that doesn't fit, pasted paint and turned paint float with the box
 * instead, and only reach the canvas when the marquee goes away (release()): then anything off the
 * canvas or outside the paintable area is cut. Everything happens here in the window; the server only
 * receives the finished move.
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
    source: StringLayer;
    frames: StringLayer[];
  };
  /** What Ctrl+C copied, where it came from, for pasting into any view. */
  private clipboard?: {
    rect: SelectionBounds;
    mask?: SelectionMask;
    pixels: Pixel[];
  };
  /** The paintable area from the last full context, so a drop from a bare cancel context still cuts to it. */
  private area?: Pick<SpriteEditorToolContext, 'drawBounds' | 'drawMask'>;

  private reconcilePending(context: SpriteEditorToolContext, data: SpriteData) {
    this.area = { drawBounds: context.drawBounds, drawMask: context.drawMask };
    const source =
      data.layers[context.selectedLayer]?.data[context.selectedDir];
    const pending = this.pending;
    if (pending) {
      if (
        !source ||
        pending.dir !== context.selectedDir ||
        pending.layer !== context.selectedLayer
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
        !current ||
        !framesEqual(current, floating.source))
    ) {
      this.floating = undefined;
      this.drag = undefined;
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
    source: StringLayer,
    frame: StringLayer,
  ) {
    const placement = encodePlacement(source, frame);
    if (!placement) return;
    if (this.pending?.dir !== dir || this.pending.layer !== layer) {
      this.pending = { dir, layer, source, frames: [] };
    }
    this.pending.frames.push(frame);
    act('spriteEditorCommand', {
      command: 'transaction',
      transaction: {
        type: 'move',
        name: 'Move selection',
        layer: layer + 1,
        dir: String(dir),
        ...placement,
      },
    });
  }

  /**
   * Writes floating paint into its frame, cutting whatever lands off the canvas or the paintable area.
   *
   * Returns whether there was floating paint, so callers can show the frame it left behind.
   */
  private drop(context: SpriteEditorToolCancelContext) {
    const floating = this.floating;
    this.floating = undefined;
    if (!floating || !this.selection) return false;
    const [left, top] = this.selection;
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
    this.commitFrame(floating.dir, floating.layer, floating.source, frame);
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
    const bounds: SelectionBounds = [0, 0, width - 1, height - 1];
    const base = {
      dir: context.selectedDir,
      layer: context.selectedLayer,
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
      drag.layer !== context.selectedLayer
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
      return;
    }
    const changed = drag.preview?.some((row, py) =>
      row.some((pixel, px) => pixel !== lift.frame[py][px]),
    );
    if (!changed) {
      this.showPreview(context);
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
        source: lift.frame,
        base,
        pixels: lift.pixels,
        moved: true,
      };
      this.showPreview(context);
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
      this.commitFrame(drag.dir, drag.layer, lift.frame, drag.preview!);
      this.showPreview(context);
      return;
    }
    this.pending ??= {
      dir: drag.dir,
      layer: drag.layer,
      source: lift.frame,
      frames: [],
    };
    this.pending.frames.push(drag.preview!);
    act('spriteEditorCommand', {
      command: 'transaction',
      transaction: {
        type: 'move',
        name: 'Move selection',
        layer: drag.layer + 1,
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
    this.drop(context);
    const source = this.currentFrame(context, data);
    if (!source) return false;
    const [left, top, right, bottom] = clip.rect;
    const x = clamp(left, left - right, data.width - 1);
    const y = clamp(top, top - bottom, data.height - 1);
    this.floating = {
      dir: context.selectedDir,
      layer: context.selectedLayer,
      source,
      base: copyLayer(source),
      pixels: clip.pixels.map((pixel) => [...pixel] as Pixel),
    };
    this.setSelection(
      context,
      [x, y, x + right - left, y + bottom - top],
      clip.mask,
    );
    this.showPreview(context);
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
