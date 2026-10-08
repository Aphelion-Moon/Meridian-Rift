export type PreviewLayer = {
  icon: string;
  x: number;
  y: number;
  rotation: number;
  scale: number;
};
export type Bounds = {
  left: number;
  right: number;
  top: number;
  bottom: number;
};

/** PNG IHDR dimensions avoid an image-load race when fitting a new appearance. */
export function pngSize(base64: string): { width: number; height: number } {
  try {
    const header = atob(base64.slice(0, 44));
    const numberAt = (offset: number) =>
      [0, 1, 2, 3].reduce(
        (value, byte) => value * 256 + header.charCodeAt(offset + byte),
        0,
      );
    const width = numberAt(16);
    const height = numberAt(20);
    if (header.slice(1, 4) === 'PNG' && width > 0 && height > 0)
      return { width, height };
  } catch {
    /* Missing previews use a tile-sized placeholder. */
  }
  return { width: 32, height: 32 };
}

export function previewBounds(
  width: number,
  height: number,
  layers: PreviewLayer[],
  frames: { x: number; y: number }[] = [],
): Bounds {
  const bounds = {
    left: -width / 2,
    right: width / 2,
    top: 16 - height,
    bottom: 16,
  };
  for (const layer of layers) {
    const size = pngSize(layer.icon);
    const angle = (layer.rotation * Math.PI) / 180;
    const halfWidth =
      ((Math.abs(Math.cos(angle)) * size.width +
        Math.abs(Math.sin(angle)) * size.height) *
        layer.scale) /
      2;
    const halfHeight =
      ((Math.abs(Math.sin(angle)) * size.width +
        Math.abs(Math.cos(angle)) * size.height) *
        layer.scale) /
      2;
    for (const frame of [{ x: 0, y: 0 }, ...frames]) {
      bounds.left = Math.min(bounds.left, layer.x + frame.x - halfWidth);
      bounds.right = Math.max(bounds.right, layer.x + frame.x + halfWidth);
      bounds.top = Math.min(bounds.top, -layer.y - frame.y - halfHeight);
      bounds.bottom = Math.max(bounds.bottom, -layer.y - frame.y + halfHeight);
    }
  }
  return bounds;
}

export function fitPreview(
  bounds: Bounds,
  width: number,
  height: number,
  bodyScale: number,
) {
  const scale = Math.min(
    4 * bodyScale,
    Math.max(1, width - 32) / Math.max(1, bounds.right - bounds.left),
    Math.max(1, height - 32) / Math.max(1, bounds.bottom - bounds.top),
  );
  return {
    scale,
    x: -(bounds.left + bounds.right) / 2,
    y: -(bounds.top + bounds.bottom) / 2,
  };
}
/** Screen Y is inverted; placement stays in unscaled BYOND pixels. */
export function dragPlacement(
  x: number,
  y: number,
  dx: number,
  dy: number,
  cameraScale: number,
  mirrorX = 1,
) {
  const bounded = (value: number) =>
    Math.round(Math.max(-128, Math.min(128, value)));
  return {
    x: bounded(x + (dx / cameraScale) * mirrorX),
    y: bounded(y - dy / cameraScale),
  };
}
export function opaqueBounds(
  pixels: Uint8ClampedArray,
  width: number,
  height: number,
) {
  let left = width,
    top = height,
    right = -1,
    bottom = -1;
  for (let y = 0; y < height; y++)
    for (let x = 0; x < width; x++) {
      if (pixels[(y * width + x) * 4 + 3]) {
        left = Math.min(left, x);
        right = Math.max(right, x);
        top = Math.min(top, y);
        bottom = Math.max(bottom, y);
      }
    }
  return right < 0
    ? undefined
    : { left, top, width: right - left + 1, height: bottom - top + 1 };
}
