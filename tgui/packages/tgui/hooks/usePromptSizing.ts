// THIS IS AN APHELION UI FILE
import { useCallback, useEffect } from 'react';
import { globalEvents } from 'tgui-core/events';
import type { BooleanLike } from 'tgui-core/react';
import { getWindowPosition, setWindowPosition } from '../drag';

const promptInterfaces = new Set([
  'AlertModal',
  'TextInputModal',
  'NumberInputModal',
  'KeyComboModal',
]);
const choiceInterfaces = new Set(['ListInputWindow', 'CheckboxInput']);

/** Ignore differences this small so a fit cannot re-trigger itself. */
const FIT_TOLERANCE = 8;
/** Below this a measurement is treated as not-yet-rendered, not a real height. */
const MIN_FIT_HEIGHT = 48;

/** Measure rendered prompt content, including theme chrome and wrapped actions. */
export function fitPromptWindow(
  cancelled: () => boolean = () => false,
  allowShrink = false,
) {
  const content = document.querySelector<HTMLElement>(
    '.MeridianContentFit .Window__content',
  );
  const padding = content?.querySelector<HTMLElement>(
    '.Window__contentPadding',
  );
  if (!content || !padding || cancelled()) {
    return;
  }

  const ratio = window.devicePixelRatio || 1;
  const contentRect = content.getBoundingClientRect();
  const paddingRect = padding.getBoundingClientRect();
  // DOM rectangles include BYOND's optional CSS zoom.
  const zoom = padding.offsetWidth
    ? paddingRect.width / padding.offsetWidth
    : 1;
  const margin = Number.parseFloat(getComputedStyle(padding).marginBottom) || 0;
  const height = Math.ceil(
    paddingRect.bottom +
      content.scrollTop +
      margin * zoom +
      window.innerHeight -
      contentRect.bottom,
  );
  const target = Math.min(height, window.screen.availHeight);
  // Shrinking is only offered before the window is shown; afterwards a larger
  // window is the user's, and the band keeps a fit from re-triggering itself.
  if (allowShrink) {
    if (
      target < MIN_FIT_HEIGHT ||
      Math.abs(target - window.innerHeight) <= FIT_TOLERANCE
    ) {
      return;
    }
  } else if (target <= window.innerHeight + 1) {
    return;
  }

  Byond.winset(Byond.windowId, {
    size: `${Math.round(window.innerWidth * ratio)}x${Math.ceil(target * ratio)}`,
  });
  const position = getWindowPosition();
  const { availTop = 0 } = window.screen as Screen & { availTop?: number };
  const bottom = (availTop + window.screen.availHeight) * ratio;
  if (position[1] + target * ratio > bottom) {
    setWindowPosition([position[0], bottom - target * ratio]);
  }
}

export function usePromptSizing(interfaceName: string, suspended: unknown) {
  const prompt = promptInterfaces.has(interfaceName);
  const choices = choiceInterfaces.has(interfaceName);
  const enabled = prompt || choices || interfaceName === 'GlassBlowing';
  const fitBeforeShow = useCallback(
    async (
      cancelled: () => boolean,
      geometry: { size: number[]; scale?: BooleanLike },
    ) => {
      if (!enabled || cancelled()) {
        return;
      }
      await document.fonts?.ready;
      const factor = geometry.scale ? 1 : window.devicePixelRatio || 1;
      const width = Math.min(
        geometry.size[0] / factor,
        window.screen.availWidth,
      );
      const height = Math.min(
        geometry.size[1] / factor,
        window.screen.availHeight,
      );
      // Native winset can finish after its call returns, including pooled windows.
      for (let attempt = 0; attempt < 25 && !cancelled(); attempt++) {
        if (
          Math.abs(window.innerWidth - width) <= 1 &&
          Math.abs(window.innerHeight - height) <= 1
        )
          break;
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
      fitPromptWindow(cancelled, true);
    },
    [enabled],
  );

  useEffect(() => {
    if (!enabled || suspended) {
      return;
    }
    const padding = document.querySelector<HTMLElement>(
      '.MeridianContentFit .Window__contentPadding',
    );
    if (!padding) {
      return;
    }
    let ready = false;
    let timer: ReturnType<typeof setTimeout>;
    const schedule = () => {
      if (!ready) return;
      clearTimeout(timer);
      timer = setTimeout(() => fitPromptWindow(), 0);
    };
    const onGeometry = () => {
      ready = true;
      schedule();
    };
    const observer = new ResizeObserver(schedule);
    observer.observe(padding);
    window.addEventListener('resize', schedule);
    globalEvents.on('window-geometry-finished', onGeometry);
    document.fonts?.addEventListener('loadingdone', schedule);
    return () => {
      clearTimeout(timer);
      observer.disconnect();
      window.removeEventListener('resize', schedule);
      globalEvents.off('window-geometry-finished', onGeometry);
      document.fonts?.removeEventListener('loadingdone', schedule);
    };
  }, [enabled, suspended]);

  return {
    promptClass:
      enabled &&
      `MeridianContentFit${prompt ? ' MeridianPrompt' : choices ? ' MeridianChoicePrompt' : ''}`,
    fitBeforeShow,
  };
}
