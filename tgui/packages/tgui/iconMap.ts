// THIS IS AN APHELION UI FILE
import { atom } from 'jotai';
import { store } from './events/store';
import { createLogger } from './logging';

type IconMapState = {
  url?: string;
  status: 'idle' | 'loading' | 'ready' | 'error';
};

export const iconMapStateAtom = atom<IconMapState>({ status: 'idle' });
const logger = createLogger('IconResources');
const ATTEMPT_TIMEOUT = 10_000;
const RETRY_DELAYS = [1_000, 3_000];
let active:
  | { url: string; controller: AbortController; promise: Promise<void> }
  | undefined;

function validateIconMap(value: unknown): Record<string, string> {
  if (
    !value ||
    typeof value !== 'object' ||
    Array.isArray(value) ||
    !Object.keys(value).length ||
    Object.values(value).some(
      (reference) => typeof reference !== 'string' || !reference,
    )
  ) {
    throw new Error('Invalid or empty icon reference map');
  }
  return value as Record<string, string>;
}

async function fetchMap(url: string, signal: AbortSignal, retry: boolean) {
  const controller = new AbortController();
  const abort = () => controller.abort();
  signal.addEventListener('abort', abort, { once: true });
  if (signal.aborted) controller.abort();
  const timeout = setTimeout(abort, ATTEMPT_TIMEOUT);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      cache: retry ? 'reload' : 'default',
    });
    if (!response.ok) {
      throw new Error(
        `HTTP ${response.status}; type=${response.headers.get('content-type')}; ray=${response.headers.get('cf-ray') ?? 'unavailable'}`,
      );
    }
    return validateIconMap(await response.json());
  } finally {
    clearTimeout(timeout);
    signal.removeEventListener('abort', abort);
  }
}

function waitForRetry(delay: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    const finish = () => {
      clearTimeout(timer);
      signal.removeEventListener('abort', finish);
      resolve();
    };
    const timer = setTimeout(finish, delay);
    signal.addEventListener('abort', finish, { once: true });
    if (signal.aborted) finish();
  });
}

async function runLoad(url: string, signal: AbortSignal) {
  for (let attempt = 0; attempt <= RETRY_DELAYS.length; attempt++) {
    if (signal.aborted) return;
    try {
      const map = await fetchMap(url, signal, attempt > 0);
      // An older request must never overwrite a map from a newer asset message.
      if (signal.aborted) return;
      Byond.iconRefMap = map;
      store.set(iconMapStateAtom, { url, status: 'ready' });
      return;
    } catch (error) {
      if (signal.aborted) return;
      if (attempt === RETRY_DELAYS.length) {
        store.set(iconMapStateAtom, { url, status: 'error' });
        logger.error(
          `Failed to load ${url} after ${attempt + 1} attempts`,
          error,
        );
        return;
      }
      await waitForRetry(RETRY_DELAYS[attempt], signal);
    }
  }
}

export function loadIconMap(url: string): Promise<void> {
  if (active?.url === url) return active.promise;
  const state = store.get(iconMapStateAtom);
  if (state.url === url && state.status === 'ready') return Promise.resolve();

  active?.controller.abort();
  const controller = new AbortController();
  store.set(iconMapStateAtom, { url, status: 'loading' });
  const promise = runLoad(url, controller.signal).finally(() => {
    if (active?.controller === controller) active = undefined;
  });
  active = { url, controller, promise };
  return promise;
}

export function retryIconMap(): void {
  const state = store.get(iconMapStateAtom);
  if (state.url && state.status === 'error') void loadIconMap(state.url);
}
