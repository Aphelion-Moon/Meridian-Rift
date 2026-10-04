// THIS IS AN APHELION UI FILE
import { getWindowPosition, setWindowPosition } from '../drag';

export type WindowSize = [number, number];
export type ContentSize = {
  content: HTMLElement;
  size: WindowSize;
};

/** Allow rounding noise, but do not leave a strip of controls clipped. */
export const FIT_TOLERANCE = 1;

function zoomOf(element: HTMLElement) {
  return element.offsetWidth
    ? element.getBoundingClientRect().width / element.offsetWidth
    : 1;
}

export function measureWindowContent(prompt = false): ContentSize | undefined {
  const content = document.querySelector<HTMLElement>(
    prompt ? '.MeridianContentFit .Window__content' : '.Window__content',
  );
  if (!content) return;
  const padding = content.querySelector<HTMLElement>('.Window__contentPadding');

  if (prompt) {
    if (!padding) return;
    const zoom = zoomOf(padding);
    const margin =
      Number.parseFloat(getComputedStyle(padding).marginBottom) || 0;
    return {
      content,
      size: [
        window.innerWidth,
        padding.getBoundingClientRect().bottom +
          (content.scrollTop + margin) * zoom +
          window.innerHeight -
          content.getBoundingClientRect().bottom,
      ],
    };
  }

  const zoom = zoomOf(content);
  // Inner scroll containers clip their descendants' overflow themselves. Measure
  // only the window and its gutter box, never a list's full scrollHeight.
  const overflow = (axis: 'Width' | 'Height') =>
    Math.max(
      0,
      content[`scroll${axis}`] - content[`client${axis}`],
      padding ? padding[`scroll${axis}`] - padding[`client${axis}`] : 0,
    ) * zoom;
  const scrolls = (value: string) => value === 'auto' || value === 'scroll';
  const scrollX = scrolls(content.style.overflowX || content.style.overflow);
  const scrollY =
    content.classList.contains('Layout__content--scrollable') ||
    scrolls(content.style.overflowY || content.style.overflow);
  return {
    content,
    size: [
      window.innerWidth + (scrollX ? 0 : overflow('Width')),
      window.innerHeight + (scrollY ? 0 : overflow('Height')),
    ],
  };
}

function setOverflow(content: HTMLElement, axis: 'x' | 'y', scroll: boolean) {
  const className = `Window__content--overflow-${axis}`;
  if (content.classList.contains(className) !== scroll) {
    content.classList.toggle(className, scroll);
  }
}

export function applyContentSize(
  { content, size }: ContentSize,
  allowShrink = false,
  blocked: readonly boolean[] = [false, false],
): WindowSize | undefined {
  const current: WindowSize = [window.innerWidth, window.innerHeight];
  const screen: WindowSize = [
    window.screen.availWidth,
    window.screen.availHeight,
  ];
  const target: WindowSize = [...current];
  for (const axis of [0, 1] as const) {
    if (!blocked[axis]) {
      target[axis] = Math.max(
        current[axis],
        Math.min(size[axis], screen[axis]),
      );
    }
    setOverflow(
      content,
      axis === 0 ? 'x' : 'y',
      size[axis] > target[axis] + FIT_TOLERANCE,
    );
  }
  // Only prompts may shrink, and only during their initial fit.
  if (allowShrink && !blocked[1] && size[1] >= 48 && size[1] < current[1] - 8) {
    target[1] = Math.min(size[1], screen[1]);
  }
  // A wider layout may wrap onto fewer lines. Let that resize land first.
  if (target[0] > current[0] + FIT_TOLERANCE) target[1] = current[1];
  if (
    target.every(
      (value, axis) => Math.abs(value - current[axis]) <= FIT_TOLERANCE,
    )
  )
    return;

  const ratio = window.devicePixelRatio || 1;
  const nativeSize = target.map((value) =>
    Math.ceil(value * ratio),
  ) as WindowSize;
  Byond.winset(Byond.windowId, { size: `${nativeSize[0]}x${nativeSize[1]}` });
  const position = getWindowPosition();
  const { availLeft = 0, availTop = 0 } = window.screen as Screen & {
    availLeft?: number;
    availTop?: number;
  };
  const nextPosition: WindowSize = [
    Math.min(position[0], (availLeft + screen[0]) * ratio - nativeSize[0]),
    Math.min(position[1], (availTop + screen[1]) * ratio - nativeSize[1]),
  ];
  if (nextPosition.some((value, axis) => value !== position[axis])) {
    setWindowPosition(nextPosition);
  }
  return nativeSize.map((value) => value / ratio) as WindowSize;
}
