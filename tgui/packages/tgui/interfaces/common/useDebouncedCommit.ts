import { useCallback, useLayoutEffect, useRef } from 'react';

/** Keep high-frequency edits local until quiet; flush on commit or context exit. */
export function useDebouncedCommit<T>(
  onCommit: (value: T) => void,
  delay = 350,
) {
  const pending = useRef(false);
  const queued = useRef<(() => void) | undefined>(undefined);
  const callback = useRef(onCommit);
  callback.current = onCommit;
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const flush = useCallback(() => {
    clearTimeout(timer.current);
    timer.current = undefined;
    const commit = queued.current;
    queued.current = undefined;
    pending.current = false;
    commit?.();
  }, []);
  const schedule = useCallback(
    (value: T) => {
      clearTimeout(timer.current);
      // Bind the action to the editing context that produced it, even on unmount.
      const commit = callback.current;
      queued.current = () => commit(value);
      pending.current = true;
      timer.current = setTimeout(flush, delay);
    },
    [delay, flush],
  );
  // Run before ancestor passive cleanup closes the backend editor session.
  useLayoutEffect(() => flush, [flush]);
  return { pending, schedule, flush };
}
