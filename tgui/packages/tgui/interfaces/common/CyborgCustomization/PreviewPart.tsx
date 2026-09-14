import { useState } from 'react';
import { editorLabel } from './LayoutControls';
import { opaqueBounds, pngSize } from './previewGeometry';
import type { CyborgCustomizationData } from './types';

/** A transparent sprite's full canvas is often much larger than the part itself. */
export function PreviewPart({
  layer,
  x,
  y,
  placing,
  selected,
  onNudge,
}: {
  layer: NonNullable<CyborgCustomizationData['layers']>[number];
  x: number;
  y: number;
  placing: boolean;
  selected: boolean;
  onNudge: (x: number, y: number) => void;
}) {
  const [mask, setMask] = useState<{
    icon: string;
    bounds: ReturnType<typeof opaqueBounds>;
  } | null>(null);
  const { width, height } = pngSize(layer.icon);
  const bounds = mask?.icon === layer.icon ? mask.bounds : undefined;
  return (
    <div
      data-part={layer.slot}
      style={{
        position: 'absolute',
        left: x,
        top: -y,
        zIndex: layer.priority,
        transform: `rotate(${-layer.rotation}deg) scale(${layer.scale})`,
        pointerEvents: 'none',
      }}
    >
      <img
        draggable={false}
        alt={
          layer.slot
            ? `${editorLabel(layer.slot)} preview`
            : 'Customization layer'
        }
        src={`data:image/png;base64,${layer.icon}`}
        style={{ position: 'absolute', left: -width / 2, top: -height / 2 }}
        onLoad={(event) => {
          const canvas = document.createElement('canvas');
          canvas.width = event.currentTarget.naturalWidth;
          canvas.height = event.currentTarget.naturalHeight;
          const context = canvas.getContext('2d');
          if (!context) return;
          context.drawImage(event.currentTarget, 0, 0);
          setMask({
            icon: layer.icon,
            bounds: opaqueBounds(
              context.getImageData(0, 0, canvas.width, canvas.height).data,
              canvas.width,
              canvas.height,
            ),
          });
        }}
      />
      {placing && layer.slot && bounds && (
        <button
          type="button"
          aria-label={`Place ${editorLabel(layer.slot)}`}
          title="Drag to place; arrow keys move one pixel"
          className="CyborgPreview__partHandle"
          style={{
            position: 'absolute',
            left: bounds.left - width / 2 - 1,
            top: bounds.top - height / 2 - 1,
            width: bounds.width + 2,
            height: bounds.height + 2,
            pointerEvents: 'auto',
            boxShadow: selected ? '0 0 0 0.25px #69b8ed' : undefined,
          }}
          onKeyDown={(event) => {
            const delta = {
              ArrowLeft: [-1, 0],
              ArrowRight: [1, 0],
              ArrowUp: [0, 1],
              ArrowDown: [0, -1],
            }[event.key];
            if (delta) {
              event.preventDefault();
              onNudge(delta[0], delta[1]);
            }
          }}
        />
      )}
    </div>
  );
}
