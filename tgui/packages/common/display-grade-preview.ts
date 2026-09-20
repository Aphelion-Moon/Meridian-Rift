/** Leading/trailing throttle; closing permanently invalidates pending work. */
export function createGradePreview<T>(
  send: (value: T, sequence: number) => void,
) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  let lastSent = -Infinity;
  let latest: T;
  let sequence = 0;
  let closed = false;
  const flush = () => {
    timer = undefined;
    if (closed) return;
    lastSent = Date.now();
    send(latest, ++sequence);
  };
  return {
    queue(value: T) {
      if (closed) return;
      latest = value;
      if (timer !== undefined) return;
      const remaining = 100 - (Date.now() - lastSent);
      if (remaining <= 0) flush();
      else timer = setTimeout(flush, remaining);
    },
    close() {
      closed = true;
      clearTimeout(timer);
      timer = undefined;
    },
  };
}
