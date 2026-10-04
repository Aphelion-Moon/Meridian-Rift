// THIS IS AN APHELION UI FILE
import {
  type CSSProperties,
  type RefObject,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from 'react';
import { globalEvents } from 'tgui-core/events';
import { placeNativeMenu, preferredMenuRect } from './nativeMenuPlacement';
import {
  getNativeUiElements,
  getNativeUiRevision,
  NATIVE_UI_SETTLE_MS,
  nativeUiSettleDelay,
  subscribeNativeUi,
} from './nativeUi';

type Metrics = {
  width: number;
  height: number;
  minimumHeight: number;
  heading: number;
};
type Layout = { floating: CSSProperties; menu: CSSProperties };
const measuring: CSSProperties = {
  position: 'fixed',
  left: 0,
  top: 0,
  visibility: 'hidden',
};

export function useNativeMenuPlacement(
  isOpen: boolean,
  triggerRef: RefObject<HTMLButtonElement | null>,
  close: () => void,
  placement: string,
) {
  const revision = useSyncExternalStore(subscribeNativeUi, getNativeUiRevision);
  const native = getNativeUiElements().size > 0;
  const [menu, setMenu] = useState<HTMLDivElement | null>(null);
  const [layout, setLayout] = useState<Layout | null>(null);
  const [blocked, setBlocked] = useState(false);
  const metrics = useRef<Metrics | null>(null);
  const restoreFocus = useRef(false);

  function measure() {
    const trigger = triggerRef.current;
    if (!trigger) return null;
    const triggerRect = trigger.getBoundingClientRect();
    // getBoundingClientRect already includes CSS zoom. Work in viewport CSS
    // pixels, converting back only when assigning styles; never apply DPR twice.
    const zoom = trigger.offsetWidth
      ? triggerRect.width / trigger.offsetWidth
      : 1;
    const rem =
      Number.parseFloat(getComputedStyle(document.documentElement).fontSize) ||
      12;
    const unit = rem / 12;
    const scale = zoom * unit;
    if (scale <= 0) return null;
    const gap = 6 * scale;
    if (menu && isOpen && !layout) {
      const rect = menu.getBoundingClientRect();
      const heading = menu
        .querySelector('.MeridianThemePicker__heading')!
        .getBoundingClientRect().height;
      const row = menu
        .querySelector('.MeridianThemePicker__option')!
        .getBoundingClientRect().height;
      const minimumHeight = (heading + row * 3) / scale + 12;
      metrics.current = {
        // A tiny viewport may clamp the initial measurement below the minimum.
        // Keep recovery metrics usable after enlargement while the menu is gone.
        width: Math.max(180, rect.width / scale),
        height: Math.max(minimumHeight, rect.height / scale),
        minimumHeight,
        heading: heading / scale + 2,
      };
    }
    const size = metrics.current;
    if (!size) return null;
    const obstacles = Array.from(getNativeUiElements(), (element) => {
      const rect = element.getBoundingClientRect();
      return {
        left: rect.left - gap,
        top: rect.top - gap,
        right: rect.right + gap,
        bottom: rect.bottom + gap,
      };
    });
    const windowContent = trigger
      .closest('.Window')
      ?.querySelector('.Window__content');
    const content = windowContent?.getBoundingClientRect();
    // The content aperture accounts for every theme's frame/title-bar insets.
    const bounds =
      content && content.width > 0 && content.height > 0
        ? {
            left: content.left + gap,
            top: content.top + gap,
            right: content.right - gap,
            bottom: content.bottom - gap,
          }
        : {
            left: 8 * scale,
            top: 8 * scale,
            right: window.innerWidth - 8 * scale,
            bottom: window.innerHeight - 8 * scale,
          };
    const preferred = preferredMenuRect(
      triggerRect,
      {
        width: size.width * scale,
        height: size.height * scale,
      },
      placement,
      4 * scale,
    );
    return {
      rect: placeNativeMenu(
        bounds,
        preferred,
        { width: 180 * scale, height: size.minimumHeight * scale },
        obstacles,
      ),
      zoom,
      scale,
      size,
    };
  }

  useLayoutEffect(() => {
    if (!native) {
      setBlocked(false);
      setLayout(null);
      return;
    }
    if (!isOpen || !menu) return;
    const floating = menu.parentElement!;
    function place() {
      const result = measure();
      if (!result?.rect) {
        restoreFocus.current ||= !!menu?.contains(document.activeElement);
        setBlocked(true);
        close();
        return;
      }
      const { rect, zoom, scale, size } = result;
      const origin = floating.getBoundingClientRect();
      // Account for the portal's actual origin as well as zoom. On first mount
      // it is fixed at 0,0 and hidden, so no eclipsed frame is painted.
      const left =
        (Number.parseFloat(floating.style.left) || 0) +
        (rect.left - origin.left) / zoom;
      const top =
        (Number.parseFloat(floating.style.top) || 0) +
        (rect.top - origin.top) / zoom;
      setLayout({
        floating: { position: 'fixed', left, top, width: rect.width / zoom },
        menu: {
          width: '100%',
          maxHeight: rect.height / zoom,
          '--native-menu-options-height': `${(rect.height - size.heading * scale) / zoom}px`,
        } as CSSProperties,
      });
      setBlocked(false);
    }
    const delay = nativeUiSettleDelay();
    if (delay > 0) {
      // Preserve recovery metrics if another geometry event closes the hidden
      // menu before this pending native move finishes.
      measure();
      const timer = setTimeout(place, delay);
      return () => clearTimeout(timer);
    }
    place();
  }, [isOpen, menu, revision, placement]);

  useEffect(() => {
    if (!isOpen) setLayout(null);
  }, [isOpen]);

  useEffect(() => {
    if (blocked || !restoreFocus.current) return;
    restoreFocus.current = false;
    if (document.activeElement === document.body) triggerRef.current?.focus();
  }, [blocked]);

  useEffect(() => {
    if (!native || (!isOpen && !blocked)) return;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let frame: number | undefined;
    let disposed = false;
    function schedule() {
      if (disposed) return;
      if (isOpen) {
        restoreFocus.current ||= !!menu?.contains(document.activeElement);
        close();
        setBlocked(true);
      }
      clearTimeout(timer);
      if (frame !== undefined) cancelAnimationFrame(frame);
      timer = setTimeout(() => {
        frame = requestAnimationFrame(() => {
          if (!disposed) setBlocked(!measure()?.rect);
        });
      }, NATIVE_UI_SETTLE_MS);
    }
    function onScroll(event: Event) {
      if (event.target instanceof Node && menu?.contains(event.target)) return;
      schedule();
    }
    // Observe only while open or blocked. The first observer delivery reports
    // existing sizes, not a change; subsequent deliveries invalidate placement.
    let initialDelivery = true;
    const observer = new ResizeObserver(() => {
      if (initialDelivery) {
        initialDelivery = false;
        return;
      }
      schedule();
    });
    for (const element of getNativeUiElements()) observer.observe(element);
    if (triggerRef.current) observer.observe(triggerRef.current);
    window.addEventListener('resize', schedule);
    document.addEventListener('scroll', onScroll, true);
    globalEvents.on('window-geometry-finished', schedule);
    if (blocked) schedule();
    return () => {
      disposed = true;
      clearTimeout(timer);
      if (frame !== undefined) cancelAnimationFrame(frame);
      observer.disconnect();
      window.removeEventListener('resize', schedule);
      document.removeEventListener('scroll', onScroll, true);
      globalEvents.off('window-geometry-finished', schedule);
    };
  }, [isOpen, blocked, native, revision, menu, close]);

  return {
    setMenu,
    disabled: native && blocked,
    ready: !!menu && (!native || !!layout),
    floatingStyle: native ? (layout?.floating ?? measuring) : undefined,
    menuStyle: native ? layout?.menu : undefined,
  };
}
