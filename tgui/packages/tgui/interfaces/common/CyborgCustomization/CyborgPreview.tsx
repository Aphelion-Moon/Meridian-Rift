import { useEffect, useMemo, useRef, useState } from 'react';
import { Box, Button, Dropdown } from 'tgui-core/components';
import { AdjustmentSlider } from '../AdjustmentSlider';
import { editorLabel } from './LayoutControls';
import { mapPreviewZoom, previewDisplayScale } from './mapPreviewZoom';
import { PreviewPart } from './PreviewPart';
import { placementBase, placementGroup } from './placementGroups';
import { type PlacementTarget, posePlacement } from './posePlacement';
import { dragPlacement, fitPreview, previewBounds } from './previewGeometry';
import {
  CYBORG_DIRECTIONS,
  type CyborgCustomizationData,
  type CyborgSlot,
  type LayoutAction,
  type PlacementCommand,
} from './types';

export function CyborgPreview({
  data,
  slot,
  onSelectSlot,
  onPreview,
  onLayout,
  placementTarget = 'base',
}: {
  data: CyborgCustomizationData;
  slot?: CyborgSlot;
  onSelectSlot?: (slot: CyborgSlot) => void;
  onPreview?: LayoutAction;
  onLayout?: LayoutAction;
  placementTarget?: PlacementTarget;
}) {
  const [mode, setMode] = useState<'camera' | 'parts'>('camera');
  const [anchor, setAnchor] = useState<{ x: number; y: number } | null>(null);
  const [draft, setDraft] = useState<{
    slot: CyborgSlot;
    x: number;
    y: number;
    baseX: number;
    baseY: number;
    mirrorX: number;
  } | null>(null);
  const editable = data.allowed && data.layout_source !== 'model_default';
  const placementScope = placementGroup(!!data.wide, data.direction);

  const editingPosition = (part: CyborgSlot) => {
    const entry = data.store.active[part];
    const pose = posePlacement(entry, data.direction, data.pose, data.arousal);
    const group = placementGroup(!!data.wide, data.direction);
    return {
      ...(placementTarget === 'base'
        ? placementBase(entry, group)
        : placementTarget === 'arousal'
          ? pose.effective
          : pose.directional),
      group,
      mirrorX:
        placementTarget === 'base'
          ? (data.layers?.find((layer) => layer.slot === part)?.mirror_x ?? 1)
          : 1,
    };
  };
  const place = (part: CyborgSlot, position: { x: number; y: number }) => {
    onLayout?.({
      operation: 'set_placement',
      slot: part,
      target: {
        scope: placementTarget,
        direction: data.direction,
        pose: data.pose,
        arousal: data.arousal,
      },
      changes: { pixel_x: position.x, pixel_y: position.y },
    } satisfies PlacementCommand);
  };

  const stage = useRef<HTMLDivElement>(null);
  const [viewport, setViewport] = useState({ width: 280, height: 300 });
  const [zoom, setZoomValue] = useState<number | null>(null);
  const [matchedZoom, setMatchedZoom] = useState(1);
  const zoomRequest = useRef(0);
  const setZoom = (value: number | null) => {
    zoomRequest.current++;
    setZoomValue(value);
  };
  useEffect(
    () => () => {
      zoomRequest.current++;
    },
    [],
  );
  const matchGameZoom = async () => {
    const displayScale = previewDisplayScale(
      window.devicePixelRatio,
      getComputedStyle(document.body).zoom,
    );
    const fallback = (data.map_zoom || 1) / displayScale;
    setZoom(fallback);
    setMatchedZoom(fallback);
    setAnchor(null);
    setPan({ x: 0, y: 0 });
    if (!data.map_view || typeof Byond === 'undefined' || !Byond.IS_BYOND)
      return;
    const request = zoomRequest.current;
    try {
      const size = await Byond.winget('map_screen.map', 'view-size');
      const measured = mapPreviewZoom(size, data.map_view, displayScale);
      if (request !== zoomRequest.current || measured === undefined) return;
      setZoomValue(measured);
      setMatchedZoom(measured);
    } catch {
      // The map can be unavailable in the lobby or while its window is closing.
    }
  };
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [background, setBackground] = useState('#30343a');
  const [showReference, setShowReference] = useState(true);
  const [framing, setFraming] = useState<ReturnType<typeof fitPreview> | null>(
    null,
  );
  const drag = useRef<{
    x: number;
    y: number;
    panX: number;
    panY: number;
    part?: CyborgSlot;
    baseX?: number;
    baseY?: number;
    scale: number;
    mirrorX?: number;
    group?: string;
  } | null>(null);
  const [frameIndex, setFrameIndex] = useState(0);
  const frames = data.animation;
  const frame = frames?.[frameIndex % (frames.length || 1)];
  useEffect(
    () => setFrameIndex(0),
    [data.model, data.direction, data.pose, data.moving, mode],
  );
  useEffect(() => {
    drag.current = null;
    setDraft(null);
  }, [
    data.context,
    data.model,
    data.pose,
    data.direction,
    data.arousal,
    editable,
    placementTarget,
    slot,
  ]);
  useEffect(() => {
    if (data.moving || !editable) setMode('camera');
  }, [data.moving, editable]);
  useEffect(() => {
    if (mode === 'parts' || !frames || frames.length < 2) return;
    const timer = setTimeout(
      () => setFrameIndex((index) => (index + 1) % frames.length),
      frame?.delay || 100,
    );
    return () => clearTimeout(timer);
  }, [frames, frameIndex, frame?.delay, mode]);
  useEffect(() => {
    const element = stage.current;
    if (!element) return;
    const measure = () =>
      setViewport({
        width: element.clientWidth || 280,
        height: element.clientHeight || 300,
      });
    measure();
    if (typeof ResizeObserver === 'undefined') {
      window.addEventListener('resize', measure);
      return () => window.removeEventListener('resize', measure);
    }
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  const bounds = useMemo(
    () =>
      previewBounds(
        data.body_width,
        data.body_height,
        data.layers || [],
        frames,
      ),
    [data.body_width, data.body_height, data.layers, frames],
  );
  const referenceX = data.body_width / 2 + 24 / data.body_scale;
  const fitBounds =
    showReference && data.reference
      ? {
          ...bounds,
          right: Math.max(bounds.right, referenceX + 16 / data.body_scale),
          top: Math.min(bounds.top, 16 - 32 / data.body_scale),
        }
      : bounds;
  const candidateFit = fitPreview(
    fitBounds,
    viewport.width,
    viewport.height,
    data.body_scale,
  );
  // Fit is an explicit framing operation, not a reaction to every edited PNG.
  const fit = framing ?? candidateFit;
  useEffect(() => {
    setFraming(candidateFit);
  }, [
    viewport.width,
    viewport.height,
    data.model,
    data.body_scale,
    showReference,
  ]);
  const scale = zoom === null ? fit.scale : zoom * data.body_scale;
  const center = anchor ?? { x: fit.x, y: fit.y };
  useEffect(() => {
    const element = stage.current;
    if (!element) return;
    const wheel = (event: WheelEvent) => {
      event.preventDefault();
      if (drag.current) return;
      setZoom(
        Math.max(
          0.1,
          Math.min(
            8,
            (zoom ?? fit.scale / data.body_scale) *
              (event.deltaY > 0 ? 0.9 : 1.1),
          ),
        ),
      );
    };
    element.addEventListener('wheel', wheel, { passive: false });
    return () => element.removeEventListener('wheel', wheel);
  }, [zoom, fit.scale, data.body_scale]);
  const fitCamera = () => {
    setFraming(candidateFit);
    setZoom(null);
    setAnchor(null);
    setPan({ x: 0, y: 0 });
  };
  return (
    <div className="CyborgPreview">
      <div
        ref={stage}
        className="CyborgPreview__stage"
        tabIndex={-1}
        style={{ background }}
        onPointerDown={(event) => {
          if (event.button !== 0) return;
          const part = (event.target as HTMLElement).closest<HTMLElement>(
            '[data-part]',
          )?.dataset.part as CyborgSlot | undefined;
          if (mode === 'parts' && (!editable || !part)) return;
          event.preventDefault();
          if (mode === 'parts')
            (event.target as HTMLElement).closest('button')?.focus();
          else event.currentTarget.focus();
          event.currentTarget.setPointerCapture(event.pointerId);
          drag.current = {
            x: event.clientX,
            y: event.clientY,
            panX: pan.x,
            panY: pan.y,
            scale,
          };
          if (mode === 'parts' && part) {
            onSelectSlot?.(part);
            setAnchor(center);
            setZoom(scale / data.body_scale);
            const entry = editingPosition(part);
            drag.current = {
              ...drag.current,
              part,
              baseX: entry.pixel_x,
              baseY: entry.pixel_y,
              group: entry.group,
              mirrorX: entry.mirrorX,
            };
            setDraft({
              slot: part,
              x: entry.pixel_x,
              y: entry.pixel_y,
              baseX: entry.pixel_x,
              baseY: entry.pixel_y,
              mirrorX: entry.mirrorX,
            });
          }
        }}
        onPointerMove={(event) => {
          const gesture = drag.current;
          if (!gesture) return;
          const dx = event.clientX - gesture.x;
          const dy = event.clientY - gesture.y;
          if (gesture.part) {
            setDraft({
              slot: gesture.part,
              ...dragPlacement(
                gesture.baseX!,
                gesture.baseY!,
                dx,
                dy,
                gesture.scale,
                gesture.mirrorX,
              ),
              baseX: gesture.baseX!,
              baseY: gesture.baseY!,
              mirrorX: gesture.mirrorX ?? 1,
            });
          } else setPan({ x: gesture.panX + dx, y: gesture.panY + dy });
        }}
        onPointerUp={(event) => {
          const gesture = drag.current;
          if (gesture?.part) {
            const position = dragPlacement(
              gesture.baseX!,
              gesture.baseY!,
              event.clientX - gesture.x,
              event.clientY - gesture.y,
              gesture.scale,
              gesture.mirrorX,
            );
            place(gesture.part, position);
          }
          drag.current = null;
          setDraft(null);
        }}
        onPointerCancel={() => {
          drag.current = null;
          setDraft(null);
        }}
        onLostPointerCapture={() => {
          drag.current = null;
          setDraft(null);
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            transform: `translate(${pan.x}px, ${pan.y}px) scale(${scale}) translate(${center.x}px, ${center.y}px)`,
            imageRendering: 'pixelated',
            pointerEvents: 'none',
          }}
        >
          {data.body && (
            <img
              draggable={false}
              alt="Cyborg preview"
              src={`data:image/png;base64,${frame?.body || data.body}`}
              style={{
                position: 'absolute',
                left: -data.body_width / 2,
                top: 16 - data.body_height,
              }}
            />
          )}
          {data.layers?.map((layer, index) => (
            <PreviewPart
              key={layer.slot || index}
              layer={layer}
              x={
                layer.x +
                (frame?.x || 0) +
                (draft && draft.slot === layer.slot
                  ? (draft.x - draft.baseX) * draft.mirrorX
                  : 0)
              }
              y={
                layer.y +
                (frame?.y || 0) +
                (draft && draft.slot === layer.slot ? draft.y - draft.baseY : 0)
              }
              placing={mode === 'parts' && editable}
              selected={layer.slot === slot}
              onNudge={(dx, dy) => {
                if (!layer.slot) return;
                onSelectSlot?.(layer.slot);
                const entry = editingPosition(layer.slot);
                place(
                  layer.slot,
                  dragPlacement(
                    entry.pixel_x,
                    entry.pixel_y,
                    dx,
                    -dy,
                    1,
                    entry.mirrorX,
                  ),
                );
              }}
            />
          ))}
          {(frame?.occlusion || data.occlusion) && (
            <img
              draggable={false}
              alt="Body occlusion"
              src={`data:image/png;base64,${frame?.occlusion || data.occlusion}`}
              style={{
                position: 'absolute',
                left: -data.body_width / 2,
                top: 16 - data.body_height,
                zIndex: 11,
              }}
            />
          )}
          {showReference && data.reference && (
            <div
              className="CyborgPreview__reference"
              style={{
                position: 'absolute',
                left: referenceX,
                top: 16,
                transform: `scale(${1 / data.body_scale})`,
              }}
            >
              <img
                draggable={false}
                alt="Normal-size human reference, 32 pixel tile"
                src={`data:image/png;base64,${data.reference}`}
                style={{
                  position: 'absolute',
                  width: 32,
                  height: 32,
                  left: -16,
                  top: -32,
                }}
              />
              <span>1 tile</span>
            </div>
          )}
        </div>
        {!data.body && <Box p={2}>No preview available for this model.</Box>}
      </div>
      <div className="CyborgPreview__camera">
        <div className="CyborgPreview__toolbar">
          <Button
            selected={zoom === null}
            onClick={fitCamera}
            tooltip="Fit the current body and parts. Framing stays fixed while editing; click again to refit."
          >
            Fit
          </Button>
          <Button
            selected={zoom === matchedZoom}
            tooltip="Match the current in-game map size, including its zoom. Click again after resizing the map. Body size is preserved."
            onClick={matchGameZoom}
          >
            1:1
          </Button>
          <span className="CyborgPreview__divider" />
          <Button
            color="teal"
            tooltip="Center the chassis without changing zoom."
            onClick={() => {
              setPan({ x: 0, y: 0 });
              setAnchor({ x: 0, y: data.body_height / 2 - 16 });
            }}
          >
            Center
          </Button>
          <span className="CyborgPreview__divider" />
          {Object.entries(CYBORG_DIRECTIONS).map(([label, direction]) => (
            <Button
              key={label}
              selected={data.direction === direction}
              tooltip={editorLabel(label)}
              onClick={() => onPreview?.({ direction })}
            >
              {label[0].toUpperCase()}
            </Button>
          ))}
          <Button
            icon="play"
            selected={data.moving}
            color={data.moving ? 'good' : 'default'}
            tooltip="Play the chassis movement animation. Stops part placement."
            onClick={() => onPreview?.({ moving: !data.moving })}
          >
            Movement
          </Button>
        </div>
        {!!onLayout && (
          <div className="CyborgPreview__toolbar">
            <Button
              icon="arrows-alt"
              selected={mode === 'camera'}
              onClick={() => setMode('camera')}
            >
              Move camera
            </Button>
            <Button
              icon="hand-pointer"
              disabled={!editable}
              selected={mode === 'parts'}
              onClick={() => {
                setMode('parts');
                onPreview?.({ moving: false });
              }}
            >
              Place parts
            </Button>
          </div>
        )}
        {mode === 'parts' && (
          <Box color="label" mt={0.5}>
            {slot && !data.layers?.some((layer) => layer.slot === slot)
              ? `No visible sprite for ${editorLabel(slot)} in this view. Check its sprite and visibility settings.`
              : slot
                ? `Drag a part to place it. Outlined: ${editorLabel(slot)}.`
                : 'Drag a visible part to place it.'}
          </Box>
        )}
        <Box color="label" mt={0.5}>
          {mode === 'camera'
            ? 'Drag to pan · Scroll to zoom'
            : placementTarget !== 'base'
              ? `Editing ${editorLabel(data.pose)} · ${editorLabel(Object.keys(CYBORG_DIRECTIONS).find((key) => CYBORG_DIRECTIONS[key] === data.direction) || 'south')} · ${placementTarget === 'arousal' ? editorLabel(data.arousal) : 'All arousal states'} · Preview paused`
              : `Placement applies to ${
                  placementScope === 'side'
                    ? 'East / West only'
                    : placementScope
                      ? `${editorLabel(placementScope)} only`
                      : 'all views'
                } · Scroll to zoom`}
        </Box>
        <details className="CyborgPreview__settings">
          <summary>Camera settings</summary>
          <Button.Checkbox
            checked={showReference}
            onClick={() => setShowReference(!showReference)}
            tooltip="A fixed normal-size human and 32-pixel tile, unaffected by cyborg body size."
          >
            Size reference
          </Button.Checkbox>
          <AdjustmentSlider
            label="Camera zoom"
            value={Math.round((zoom ?? fit.scale / data.body_scale) * 100)}
            min={10}
            max={800}
            step={10}
            unit="%"
            onChange={(value) => setZoom(value / 100)}
          />
          <Dropdown
            width="100%"
            selected={background}
            displayText={
              {
                '#30343a': 'Slate background',
                '#ffffff': 'White background',
                '#000000': 'Black background',
                '#5b6854': 'Green background',
              }[background]
            }
            options={[
              { value: '#30343a', displayText: 'Slate background' },
              { value: '#ffffff', displayText: 'White background' },
              { value: '#000000', displayText: 'Black background' },
              { value: '#5b6854', displayText: 'Green background' },
            ]}
            onSelected={setBackground}
          />
        </details>
      </div>
    </div>
  );
}
