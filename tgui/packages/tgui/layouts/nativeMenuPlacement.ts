// THIS IS AN APHELION UI FILE
export type MenuBounds = {
  left: number;
  top: number;
  right: number;
  bottom: number;
};
export type MenuRect = {
  left: number;
  top: number;
  width: number;
  height: number;
};

export function preferredMenuRect(
  trigger: MenuBounds,
  size: { width: number; height: number },
  placement: string,
  gap: number,
): MenuRect {
  const [side, alignment] = placement.split('-');
  const vertical = side === 'top' || side === 'bottom';
  const align = (start: number, end: number, length: number) =>
    alignment === 'start'
      ? start
      : alignment === 'end'
        ? end - length
        : (start + end - length) / 2;
  return {
    ...size,
    left: vertical
      ? align(trigger.left, trigger.right, size.width)
      : side === 'left'
        ? trigger.left - size.width - gap
        : trigger.right + gap,
    top: !vertical
      ? align(trigger.top, trigger.bottom, size.height)
      : side === 'top'
        ? trigger.top - size.height - gap
        : trigger.bottom + gap,
  };
}

export function placeNativeMenu(
  bounds: MenuBounds,
  preferred: MenuRect,
  minimum: { width: number; height: number },
  obstacles: readonly MenuBounds[],
): MenuRect | null {
  let best: MenuRect | null = null;
  let bestArea = 0;
  let bestDistance = Infinity;
  const consider = (
    left: number,
    top: number,
    right: number,
    bottom: number,
  ) => {
    const width = Math.min(preferred.width, right - left);
    const height = Math.min(preferred.height, bottom - top);
    if (width < minimum.width || height < minimum.height) return;
    const x = Math.max(left, Math.min(preferred.left, right - width));
    const y = Math.max(top, Math.min(preferred.top, bottom - height));
    const area = width * height;
    const distance = (x - preferred.left) ** 2 + (y - preferred.top) ** 2;
    if (area > bestArea || (area === bestArea && distance < bestDistance)) {
      best = { left: x, top: y, width, height };
      bestArea = area;
      bestDistance = distance;
    }
  };

  const relevant = obstacles.filter(
    (rect) =>
      rect.right > bounds.left &&
      rect.left < bounds.right &&
      rect.bottom > bounds.top &&
      rect.top < bounds.bottom &&
      rect.right > rect.left &&
      rect.bottom > rect.top,
  );
  // Normal position is the cheap path, including windows without native UI.
  consider(bounds.left, bounds.top, bounds.right, bounds.bottom);
  const initial = best as MenuRect | null;
  if (
    !initial ||
    !relevant.some(
      (rect) =>
        rect.left < initial.left + initial.width &&
        rect.right > initial.left &&
        rect.top < initial.top + initial.height &&
        rect.bottom > initial.top,
    )
  )
    return initial;
  best = null;
  bestArea = 0;
  bestDistance = Infinity;

  // Every maximal free rectangle has horizontal edges at the window or an
  // obstacle. Scan vertical gaps in each such strip. This is bounded O(n^3),
  // avoiding the exponential rectangle splitting possible with multiple maps.
  relevant.sort((a, b) => a.top - b.top);
  const lefts = new Set([bounds.left, ...relevant.map((rect) => rect.right)]);
  const rights = new Set([bounds.right, ...relevant.map((rect) => rect.left)]);
  for (const left of lefts) {
    for (const right of rights) {
      if (
        left < bounds.left ||
        right > bounds.right ||
        right - left < minimum.width
      )
        continue;
      let top = bounds.top;
      for (const rect of relevant) {
        if (rect.left >= right || rect.right <= left) continue;
        consider(left, top, right, Math.min(rect.top, bounds.bottom));
        top = Math.max(top, rect.bottom);
        if (top >= bounds.bottom) break;
      }
      consider(left, top, right, bounds.bottom);
    }
  }
  return best;
}
