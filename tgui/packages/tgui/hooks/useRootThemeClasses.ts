// THIS IS AN APHELION UI FILE
import { useEffect, useRef } from 'react';
import { globalEvents } from 'tgui-core/events';

/** Apply renderer-owned themes without removing runtime classes. */
export function useRootThemeClasses(managedClasses: readonly string[]) {
  const managedClassKey = managedClasses.join(' ');
  const previousClassKey = useRef(managedClassKey);

  useEffect(() => {
    const root = document.documentElement;
    const nextManagedClasses = managedClassKey.split(' ').filter(Boolean);
    root.classList.add(...nextManagedClasses);

    if (previousClassKey.current !== managedClassKey) {
      previousClassKey.current = managedClassKey;
      // ByondUi debounces this event before measuring the new theme's layout.
      globalEvents.emit('window-geometry-finished');
    }

    return () => {
      root.classList.remove(...nextManagedClasses);
    };
  }, [managedClassKey]);
}
