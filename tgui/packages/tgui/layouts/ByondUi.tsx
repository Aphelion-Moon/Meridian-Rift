// THIS IS AN APHELION UI FILE
import { type ComponentProps, useEffect, useId, useRef } from 'react';
import { ByondUi as CoreByondUi } from 'tgui-core/components';
import { globalEvents } from 'tgui-core/events';
import { debounce } from 'tgui-core/timer';
import { computeBoxProps } from 'tgui-core/ui';
import { registerNativeUi } from './nativeUi';

type Props = ComponentProps<typeof CoreByondUi> & {
  /**
   * Keep the native control between one mount and the next with the same id,
   * moving it rather than destroying it and creating another. Pages that each
   * show the same preview then share one control. A new control shows the
   * system's pale window colour until BYOND first draws into it, and starts a
   * renderer of its own, so swapping one for another flashes and waits on
   * every switch. Only for an id that one component shows at a time.
   */
  persist?: boolean;
};

/** Keep native rendering owned by tgui-core; expose its existing placeholder. */
export function ByondUi(props: Props) {
  const { persist, ...rest } = props;
  const marker = useId();
  useEffect(() => {
    const element = document.querySelector<HTMLElement>(
      `[data-byond-ui="${marker}"]`,
    );
    if (element) return registerNativeUi(element);
  }, [marker]);
  if (persist && rest.params?.id) {
    return <PersistentByondUi {...rest} marker={marker} />;
  }
  return <CoreByondUi {...rest} data-byond-ui={marker} />;
}

/**
 * Persistent controls, by id, and whether a page shows each one now. A control
 * stays while the window lives: the server destroys every control a window
 * reported when that window closes.
 */
const persistent = new Map<string, boolean>();

/** Where an element sits, in the display pixels a winset takes. */
function placement(element: HTMLElement) {
  const ratio = window.devicePixelRatio ?? 1;
  const rect = element.getBoundingClientRect();
  return {
    pos: `${rect.left * ratio},${rect.top * ratio}`,
    size: `${(rect.right - rect.left) * ratio}x${(rect.bottom - rect.top) * ratio}`,
  };
}

type PersistentProps = ComponentProps<typeof CoreByondUi> & { marker: string };

function PersistentByondUi(props: PersistentProps) {
  const { params, phonehome = true, marker, ...rest } = props;
  const container = useRef<HTMLDivElement>(null);
  // ByondUi only persists controls with an id.
  const id = params?.id as string;

  useEffect(() => {
    const place = () => {
      if (!container.current) {
        return;
      }
      Byond.winset(id, {
        parent: Byond.windowId,
        ...params,
        ...placement(container.current),
        'is-visible': true,
      });
    };
    const replace = debounce(place, 100);

    if (phonehome) {
      // So the server destroys it with the window, whichever window this is.
      Byond.sendMessage('renderByondUi', { renderByondUi: id });
    }
    persistent.set(id, true);
    place();
    window.addEventListener('resize', replace);
    globalEvents.on('window-geometry-finished', replace);

    return () => {
      window.removeEventListener('resize', replace);
      globalEvents.off('window-geometry-finished', replace);
      persistent.set(id, false);
      // A page switch mounts the next page's preview in the same commit, and it
      // takes the control over before this runs. Otherwise nothing shows the
      // control, so it hides until something does.
      queueMicrotask(() => {
        if (!persistent.get(id)) {
          Byond.winset(id, { 'is-visible': false });
        }
      });
    };
  }, [id]);

  return (
    <div ref={container} data-byond-ui={marker} {...computeBoxProps(rest)}>
      <div style={{ minHeight: '22px' }} />
    </div>
  );
}
