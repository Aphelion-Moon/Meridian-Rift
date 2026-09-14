// THIS IS AN APHELION UI FILE
import { sendAct as act } from 'tgui/events/act';
import { clamp } from 'tgui-core/math';
import { colorsAreEqual, parseHexColorString } from '../../colorSpaces';
import {
  constrainToIconGrid,
  copyLayer,
  isWithinDrawBounds,
} from '../../helpers';
import { Tool } from '../Tool';
import type {
  Dir,
  SelectionBounds,
  SpriteData,
  SpriteEditorToolCancelContext,
  SpriteEditorToolContext,
  StringLayer,
} from '../types';

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

type SelectionDrag = {
  dir: Dir;
  layer: number;
  origin: [number, number];
  bounds: SelectionBounds;
  rect: SelectionBounds;
} & (
  | { mode: 'select' }
  | {
      mode: 'move';
      frame: StringLayer;
      pixels: [number, number, string][];
      limits: SelectionBounds;
      offset: [number, number];
      preview?: StringLayer;
    }
);

export class Select extends Tool {
  icon = 'vector-square';
  name = 'Select';
  private selection?: SelectionBounds;
  private drag?: SelectionDrag;
  private pending?: {
    dir: Dir;
    layer: number;
    source: StringLayer;
    frames: StringLayer[];
  };

  private reconcilePending(context: SpriteEditorToolContext, data: SpriteData) {
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
      (!source || !framesEqual(source, this.drag.frame))
    ) {
      this.drag = undefined;
    }
  }

  private restorePendingPreview(context: SpriteEditorToolContext) {
    const moving = this.drag?.mode === 'move' ? this.drag : undefined;
    const preview = moving?.preview ?? this.pending?.frames.at(-1);
    context.setPreviewLayer(
      preview ? (moving?.layer ?? this.pending?.layer) : undefined,
    );
    context.setPreviewData(preview);
  }

  reconcile(context: SpriteEditorToolContext, data: SpriteData) {
    this.reconcilePending(context, data);
    this.restorePendingPreview(context);
  }

  private setSelection(
    context: SpriteEditorToolContext,
    selection: SelectionBounds,
  ) {
    if (selection.every((value, i) => value === this.selection?.[i])) return;
    this.selection = selection;
    context.setSelectionBounds?.(selection);
  }

  onMouseDown(
    context: SpriteEditorToolContext,
    data: SpriteData,
    x: number,
    y: number,
    isRightClick = false,
  ) {
    if (isRightClick) return;
    this.reconcilePending(context, data);
    const source =
      data.layers[context.selectedLayer]?.data[context.selectedDir];
    const { width, height } = data;
    const [px, py, inBounds] = constrainToIconGrid(x, y, width, height);
    if (!inBounds) return;
    const bounds: SelectionBounds = [0, 0, width - 1, height - 1];
    const base = {
      dir: context.selectedDir,
      layer: context.selectedLayer,
      origin: [px, py] as [number, number],
      bounds,
    };
    if (this.selection && isWithinDrawBounds(px, py, this.selection)) {
      if (!source) return;
      // A following drag may begin before the previous move is acknowledged.
      const frame = copyLayer(this.pending?.frames.at(-1) ?? source);
      const pixels: [number, number, string][] = [];
      const [left, top, right, bottom] = this.selection;
      const paintBounds = context.drawBounds ?? bounds;
      const limits: SelectionBounds = [
        -left,
        -top,
        width - 1 - right,
        height - 1 - bottom,
      ];
      for (let sy = top; sy <= bottom; sy++) {
        for (let sx = left; sx <= right; sx++) {
          const color = frame[sy][sx];
          if (
            isWithinDrawBounds(sx, sy, paintBounds, context.drawMask) &&
            (parseHexColorString(color).a ?? 1) > 0
          ) {
            pixels.push([sx, sy, color]);
            // Shaded margins can be selected; only painted pixels must stay within drawing bounds.
            limits[0] = Math.max(limits[0], paintBounds[0] - sx);
            limits[1] = Math.max(limits[1], paintBounds[1] - sy);
            limits[2] = Math.min(limits[2], paintBounds[2] - sx);
            limits[3] = Math.min(limits[3], paintBounds[3] - sy);
          }
        }
      }
      this.drag = {
        ...base,
        mode: 'move',
        rect: this.selection,
        frame,
        pixels,
        limits,
        offset: [0, 0],
      };
    } else {
      const rect: SelectionBounds = [px, py, px, py];
      this.drag = { ...base, mode: 'select', rect };
      this.setSelection(context, rect);
    }
    return true;
  }

  onMouseMove(
    context: SpriteEditorToolContext,
    _data: SpriteData,
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
    const [left, top, right, bottom] = drag.bounds;
    const [ox, oy] = drag.origin;
    if (drag.mode === 'select') {
      const px = clamp(Math.floor(x), left, right);
      const py = clamp(Math.floor(y), top, bottom);
      this.setSelection(context, [
        Math.min(ox, px),
        Math.min(oy, py),
        Math.max(ox, px),
        Math.max(oy, py),
      ]);
      return;
    }
    const [sx, sy, ex, ey] = drag.rect;
    const dx = clamp(Math.floor(x) - ox, drag.limits[0], drag.limits[2]);
    const dy = clamp(Math.floor(y) - oy, drag.limits[1], drag.limits[3]);
    if (dx === drag.offset[0] && dy === drag.offset[1]) return;
    if (
      context.drawMask &&
      drag.pixels.some(
        ([px, py]) =>
          !isWithinDrawBounds(
            px + dx,
            py + dy,
            context.drawBounds,
            context.drawMask,
          ),
      )
    )
      return;
    drag.offset = [dx, dy];
    this.setSelection(context, [sx + dx, sy + dy, ex + dx, ey + dy]);
    if ((!dx && !dy) || !drag.pixels.length) {
      drag.preview = undefined;
      this.restorePendingPreview(context);
      return;
    }
    const preview = copyLayer(drag.frame);
    for (const [px, py] of drag.pixels) preview[py][px] = '#00000000';
    for (const [px, py, color] of drag.pixels) {
      preview[py + dy][px + dx] = color;
    }
    drag.preview = preview;
    context.setPreviewLayer(drag.layer);
    context.setPreviewData(preview);
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
    if (drag?.mode !== 'move') return;
    const changed = drag.preview?.some((row, py) =>
      row.some((pixel, px) => pixel !== drag.frame[py][px]),
    );
    if (!changed) {
      this.restorePendingPreview(context);
      return;
    }
    this.pending ??= {
      dir: drag.dir,
      layer: drag.layer,
      source: drag.frame,
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

  cancel(context: SpriteEditorToolCancelContext) {
    this.drag = undefined;
    this.selection = undefined;
    this.pending = undefined;
    context.setPreviewLayer(undefined);
    context.setPreviewData(undefined);
    context.setSelectionBounds?.(undefined);
  }
}
