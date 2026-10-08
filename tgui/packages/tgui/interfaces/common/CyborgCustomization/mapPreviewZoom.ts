/** TGUI can cancel OS scaling with body zoom when window scaling is disabled. */
export function previewDisplayScale(pixelRatio: number, bodyZoom = '') {
  const zoom = Number.parseFloat(bodyZoom) / (bodyZoom.endsWith('%') ? 100 : 1);
  return (pixelRatio || 1) * (Number.isFinite(zoom) && zoom > 0 ? zoom : 1);
}

/** Native map pixels per tile, converted to the preview's CSS coordinates. */
export function mapPreviewZoom(
  size: unknown,
  view: number[],
  displayScale = 1,
) {
  const dimensions =
    typeof size === 'string'
      ? size.split('x').map(Number)
      : size && typeof size === 'object'
        ? [(size as { x: number }).x, (size as { y: number }).y]
        : [];
  const ratios = dimensions.map((pixels, index) => pixels / (view[index] * 32));
  if (
    ratios.length !== 2 ||
    !ratios.every((ratio) => Number.isFinite(ratio) && ratio > 0) ||
    !Number.isFinite(displayScale) ||
    displayScale <= 0
  )
    return undefined;
  return Math.min(...ratios) / displayScale;
}
