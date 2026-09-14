// THIS IS AN APHELION UI FILE
import { useCallback, useEffect, useRef } from 'react';
import {
  addScrollableNode,
  globalEvents,
  removeScrollableNode,
} from 'tgui-core/events';
import type { BooleanLike } from 'tgui-core/react';
import {
  applyContentSize,
  FIT_TOLERANCE,
  measureWindowContent,
  type WindowSize,
} from './windowSizing';

const promptInterfaces = new Set([
  'AlertModal',
  'TextInputModal',
  'NumberInputModal',
  'KeyComboModal',
]);
const choiceInterfaces = new Set(['ListInputWindow', 'CheckboxInput']);
type Geometry = { size: number[]; scale?: BooleanLike };
type BeforeShow = (
  cancelled: () => boolean,
  geometry: Geometry,
) => Promise<void>;

async function waitUntil(ready: () => boolean, cancelled: () => boolean) {
  // Native winset is asynchronous; a refused resize must not hide the UI forever.
  for (let attempt = 0; attempt < 25 && !cancelled(); attempt++) {
    if (ready()) return true;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  return !cancelled() && ready();
}

function sizeMatches(size: WindowSize) {
  return (
    Math.abs(window.innerWidth - size[0]) <= FIT_TOLERANCE &&
    Math.abs(window.innerHeight - size[1]) <= FIT_TOLERANCE
  );
}

export function useWindowSizing(interfaceName: string, suspended: unknown) {
  const prompt = promptInterfaces.has(interfaceName);
  const choices = choiceInterfaces.has(interfaceName);
  const naturalHeight = prompt || choices || interfaceName === 'GlassBlowing';
  const beforeShow = useRef<BeforeShow | undefined>(undefined);
  const fitBeforeShow = useCallback<BeforeShow>(
    async (cancelled, geometry) => {
      await beforeShow.current?.(cancelled, geometry);
    },
    [interfaceName],
  );

  useEffect(() => {
    if (suspended) return;
    let disposed = false;
    let ready = false;
    let manual = false;
    let generation = 0;
    let windowCancelled = () => false;
    let blocked = [false, false];
    let frame: number | undefined;
    let fitting: Promise<void> | undefined;
    let pendingGeometry: WindowSize | undefined;
    let dirty = false;
    let observationDirty = false;
    let fallbackNode: HTMLElement | undefined;
    const observed = new Set<Element>();

    function syncFallback(content: HTMLElement) {
      const fallback =
        content.matches(
          '.Window__content--overflow-x, .Window__content--overflow-y',
        ) && !content.classList.contains('Layout__content--scrollable')
          ? content
          : undefined;
      if (fallback === fallbackNode) return;
      if (fallbackNode) removeScrollableNode(fallbackNode);
      fallbackNode = fallback;
      if (fallbackNode) addScrollableNode(fallbackNode);
    }

    function applyScrollFallback() {
      const measurement = measureWindowContent(naturalHeight);
      if (!measurement) return;
      applyContentSize(measurement, false, [true, true]);
      syncFallback(measurement.content);
    }

    async function fit(cancelled: () => boolean, allowShrink = false) {
      let previous:
        | { size: WindowSize; overflow: WindowSize; axis: number }
        | undefined;
      for (let attempt = 0; attempt < 4 && !cancelled(); attempt++) {
        const measurement = measureWindowContent(naturalHeight);
        if (!measurement) return;
        const current: WindowSize = [window.innerWidth, window.innerHeight];
        const overflow = measurement.size.map(
          (value, axis) => value - current[axis],
        ) as WindowSize;
        if (previous && sizeMatches(previous.size)) {
          const axis = previous.axis;
          // Percentage-height layouts can overflow by the same amount at every
          // size. Stop if growth did not help, and leave that overflow scrollable.
          if (
            overflow[axis] > FIT_TOLERANCE &&
            overflow[axis] >= previous.overflow[axis] - FIT_TOLERANCE
          ) {
            blocked[axis] = true;
          }
        }
        const size = applyContentSize(
          measurement,
          allowShrink && attempt === 0,
          manual ? [true, true] : blocked,
        );
        syncFallback(measurement.content);
        if (!size) return;
        previous = {
          size,
          overflow,
          axis: size[0] > current[0] + FIT_TOLERANCE ? 0 : 1,
        };
        if (!(await waitUntil(() => sizeMatches(size), cancelled))) {
          if (!cancelled()) {
            blocked[previous.axis] = true;
            applyScrollFallback();
          }
          return;
        }
      }
    }

    async function runFit(allowShrink = false) {
      const currentGeneration = generation;
      const isCancelled = () =>
        disposed || generation !== currentGeneration || windowCancelled();
      const work = fit(isCancelled, allowShrink);
      fitting = work;
      try {
        await work;
      } finally {
        if (fitting === work) fitting = undefined;
        if (dirty && !isCancelled()) {
          dirty = false;
          schedule();
        }
      }
    }

    function schedule() {
      if (disposed || frame !== undefined) return;
      frame = requestAnimationFrame(() => {
        frame = undefined;
        if (observationDirty && !disposed) {
          observationDirty = false;
          observeContent();
        }
        if (disposed || !ready || windowCancelled()) return;
        if (pendingGeometry) {
          if (!sizeMatches(pendingGeometry)) {
            applyScrollFallback();
            return;
          }
          pendingGeometry = undefined;
        }
        if (fitting) {
          dirty = true;
          return;
        }
        void runFit();
      });
    }

    const observer = new ResizeObserver(schedule);
    const scrollContainerSelector =
      '.Section--scrollable, .Section--scrollableHorizontal, .Layout__content--scrollable';
    const contentDescendantSelector =
      '.Window__contentPadding, .Section, .Section__content, .Stack, .Flex';
    function observeContent() {
      const content = document.querySelector<HTMLElement>('.Window__content');
      const next = new Set<Element>(
        content
          ? [
              content,
              // Inside a scrolling aperture, only nested scroll containers
              // themselves survive the filter below. Select those directly.
              ...content.querySelectorAll(
                content.matches(scrollContainerSelector)
                  ? `:is(${contentDescendantSelector}):is(${scrollContainerSelector})`
                  : contentDescendantSelector,
              ),
            ]
          : [],
      );
      for (const node of next) {
        const scroller = node.closest(scrollContainerSelector);
        if (scroller && scroller !== node) {
          next.delete(node);
          continue;
        }
        if (!observed.has(node)) observer.observe(node);
      }
      for (const node of observed)
        if (!next.has(node)) observer.unobserve(node);
      observed.clear();
      for (const node of next) observed.add(node);
    }
    const mutationObserver = new MutationObserver((records) => {
      if (
        records.some(
          (record) =>
            record.type === 'childList' || record.attributeName === 'class',
        )
      )
        observationDirty = true;
      schedule();
    });
    const root = document.querySelector('.Window');
    if (root)
      mutationObserver.observe(root, {
        subtree: true,
        childList: true,
        characterData: true,
        attributes: true,
        attributeFilter: ['class', 'style'],
      });
    observeContent();

    beforeShow.current = async (cancelled, geometry) => {
      if (disposed || cancelled()) return;
      const currentGeneration = ++generation;
      const isCancelled = () =>
        disposed || currentGeneration !== generation || cancelled();
      windowCancelled = cancelled;
      ready = false;
      if (frame !== undefined) cancelAnimationFrame(frame);
      frame = undefined;
      dirty = false;
      manual = false;
      blocked = [false, false];
      pendingGeometry = undefined;
      await fitting;
      if (isCancelled()) return;
      if (document.querySelector('.Window__content')) {
        let fontsReady = !document.fonts?.ready;
        document.fonts?.ready?.then(
          () => {
            fontsReady = true;
          },
          () => {
            fontsReady = true;
          },
        );
        await waitUntil(() => fontsReady, isCancelled);
        const factor = geometry.scale ? 1 : window.devicePixelRatio || 1;
        const size: WindowSize = [
          Math.min(geometry.size[0] / factor, window.screen.availWidth),
          Math.min(geometry.size[1] / factor, window.screen.availHeight),
        ];
        if (await waitUntil(() => sizeMatches(size), isCancelled)) {
          await runFit(naturalHeight);
        } else if (!isCancelled()) {
          pendingGeometry = size;
          applyScrollFallback();
        }
      }
      if (!isCancelled()) {
        ready = true;
        if (observationDirty) schedule();
      }
    };

    const onGeometry = () => schedule();
    const onMouseDown = (event: MouseEvent) => {
      if (
        event.target instanceof Element &&
        event.target.closest(
          '.Window__resizeHandle__e, .Window__resizeHandle__s, .Window__resizeHandle__se',
        )
      ) {
        manual = true;
        schedule();
      }
    };
    window.addEventListener('resize', schedule);
    document.addEventListener('mousedown', onMouseDown, true);
    root?.addEventListener('load', schedule, true);
    document.fonts?.addEventListener('loadingdone', schedule);
    globalEvents.on('window-geometry-finished', onGeometry);
    return () => {
      disposed = true;
      beforeShow.current = undefined;
      if (frame !== undefined) cancelAnimationFrame(frame);
      observer.disconnect();
      mutationObserver.disconnect();
      if (fallbackNode) removeScrollableNode(fallbackNode);
      window.removeEventListener('resize', schedule);
      document.removeEventListener('mousedown', onMouseDown, true);
      root?.removeEventListener('load', schedule, true);
      document.fonts?.removeEventListener('loadingdone', schedule);
      globalEvents.off('window-geometry-finished', onGeometry);
    };
  }, [interfaceName, naturalHeight, suspended]);

  return {
    promptClass:
      naturalHeight &&
      `MeridianContentFit${prompt ? ' MeridianPrompt' : choices ? ' MeridianChoicePrompt' : ''}`,
    fitBeforeShow,
  };
}
