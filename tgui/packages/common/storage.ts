/**
 * Browser-agnostic abstraction of key-value web storage.
 *
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

export const IMPL_HUB_STORAGE = 1;
export const IMPL_IFRAME_INDEXED_DB = 2;

export type StorageImplementation =
  | typeof IMPL_HUB_STORAGE
  | typeof IMPL_IFRAME_INDEXED_DB;

type StorageBackend = {
  impl: StorageImplementation;
  get(key: string): Promise<any>;
  set(key: string, value: any): Promise<void>;
  remove(key: string): Promise<void>;
  clear(): Promise<void>;
};

export type StorageDiagnostic = {
  level: 'info' | 'warn' | 'error';
  message: string;
};

const testGeneric = (testFn: () => boolean) => (): boolean => {
  try {
    return Boolean(testFn());
  } catch {
    return false;
  }
};

const testHubStorage = testGeneric(
  () => window.hubStorage && !!window.hubStorage.getItem,
);

const STORAGE_CDN_TIMEOUT = 5000;
const persistedStorageKeys = ['panel-settings', 'chat-state', 'chat-messages'];
const legacyHubMigrationKeys = ['panel-settings'];
// APHELION EDIT ADDITION START - CHAT_SETTINGS
/** What one try at a read returns if the iframe errored or didn't answer in time */
const NO_ANSWER = Symbol('no answer');
// APHELION EDIT ADDITION END

class HubStorageBackend implements StorageBackend {
  public impl: StorageImplementation;

  constructor() {
    this.impl = IMPL_HUB_STORAGE;
  }

  async get(key: string): Promise<any> {
    const value = await window.hubStorage.getItem(key);
    if (typeof value === 'string') {
      return JSON.parse(value);
    }
    return undefined;
  }

  async set(key: string, value: any): Promise<void> {
    window.hubStorage.setItem(key, JSON.stringify(value));
  }

  async remove(key: string): Promise<void> {
    window.hubStorage.removeItem(key);
  }

  async clear(): Promise<void> {
    window.hubStorage.clear();
  }
}

export class IFrameIndexedDbBackend implements StorageBackend { // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: class IFrameIndexedDbBackend implements StorageBackend {
  public impl: StorageImplementation;

  private documentElement: HTMLIFrameElement;
  private iframeWindow: Window;
  private onReadTimeout: (key: string) => void;
  // keys we asked for but never heard back about. this is like, so we can differientate them from "keys that just had no value at all"
  private unreadKeys = new Set<string>();
  // APHELION EDIT ADDITION START - CHAT_SETTINGS
  /** Whether a failed read gets a second try. Turned off after a read fails twice, since the store's likely down */
  private retryReads = true;
  // APHELION EDIT ADDITION END

  constructor(onReadTimeout: (key: string) => void) {
    this.impl = IMPL_IFRAME_INDEXED_DB;
    this.onReadTimeout = onReadTimeout;
  }

  async ready(): Promise<boolean | null> {
    const iframe = document.createElement('iframe');
    iframe.style.display = 'none';
    iframe.allow = 'storage-access';
    iframe.src = Byond.storageCdn;

    const completePromise: Promise<boolean> = new Promise((resolve) => {
      const listener = (message: MessageEvent) => {
        if (
          message.source === iframe.contentWindow &&
          message.data === 'ready'
        ) {
          resolveReady(true);
        }
      };
      const resolveReady = (ready: boolean) => {
        clearTimeout(timeout);
        window.removeEventListener('message', listener);
        resolve(ready);
      };
      const timeout = setTimeout(
        () => resolveReady(false),
        STORAGE_CDN_TIMEOUT,
      );

      fetch(Byond.storageCdn, { method: 'HEAD' })
        .then((response) => {
          if (response.status !== 200) {
            resolveReady(false);
          }
        })
        .catch(() => {
          resolveReady(false);
        });

      window.addEventListener('message', listener);
    });

    this.documentElement = document.body.appendChild(iframe);
    if (!this.documentElement.contentWindow) {
      return new Promise((res) => res(false));
    }

    this.iframeWindow = this.documentElement.contentWindow;

    return completePromise;
  }

  // APHELION EDIT ADDITION START - CHAT_SETTINGS
  /** Returns the saved value, or undefined if nothing's saved or the store didn't answer */
  async get(key: string): Promise<any> {
    // the key counts as unread until we get an answer, so nothing saves over it while we wait
    this.unreadKeys.add(key);
    let value = await this.ask(key);
    // a store that was only slow usually answers the second time
    if (value === NO_ANSWER && this.retryReads) value = await this.ask(key);
    if (value === NO_ANSWER) {
      // warn only the first time a read fails both tries
      if (this.retryReads) this.onReadTimeout(key);
      this.retryReads = false;
      return undefined;
    }
    this.unreadKeys.delete(key);
    return value;
  }

  /** Whether we asked for `key` and never got an answer */
  isUnread(key: string): boolean {
    return this.unreadKeys.has(key);
  }

  /** Lets `key` be saved even though it couldn't be read */
  markRead(key: string): void {
    this.unreadKeys.delete(key);
  }

  // APHELION EDIT ADDITION END
  private async ask(key: string): Promise<any> { // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: async get(key: string): Promise<any> {
    const promise = new Promise((resolve) => {
      const listener = (message: MessageEvent) => {
        if (
          message.source === this.iframeWindow &&
          message.data.key &&
          message.data.key === key
        ) {
          clearTimeout(timeout);
          window.removeEventListener('message', listener);
          // this.unreadKeys.delete(key); // APHELION EDIT REMOVAL - CHAT_SETTINGS
          resolve('error' in message.data ? NO_ANSWER : message.data.value); // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: resolve(message.data.value);
        }
      };
      const timeout = setTimeout(() => {
        window.removeEventListener('message', listener);
        /* // APHELION EDIT REMOVAL START - CHAT_SETTINGS
        this.unreadKeys.add(key);
        this.onReadTimeout(key);
        */ // APHELION EDIT REMOVAL END
        resolve(NO_ANSWER); // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: resolve(undefined);
      }, STORAGE_CDN_TIMEOUT);

      window.addEventListener('message', listener);
    });

    this.iframeWindow.postMessage({ type: 'get', key: key }, '*');
    return promise;
  }

  async set(key: string, value: any): Promise<void> {
    if (this.unreadKeys.has(key)) return;
    this.iframeWindow.postMessage({ type: 'set', key: key, value: value }, '*');
  }

  async remove(key: string): Promise<void> {
    this.iframeWindow.postMessage({ type: 'remove', key: key }, '*');
  }

  async clear(): Promise<void> {
    this.iframeWindow.postMessage({ type: 'clear' }, '*');
  }

  async destroy(): Promise<void> {
    document.body.removeChild(this.documentElement);
  }
}

/**
 * Web Storage Proxy object, which selects the best backend available
 * depending on the environment.
 */
export class StorageProxy { // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: class StorageProxy {
  private backendPromise: Promise<StorageBackend>;
  private diagnostics: StorageDiagnostic[] = [];
  private listener?: (diagnostic: StorageDiagnostic) => void;

  private log(level: StorageDiagnostic['level'], message: string) {
    const diagnostic = { level, message };
    this.diagnostics.push(diagnostic);
    this.listener?.(diagnostic);
  }

  /** Calls `listener` with every diagnostic logged so far, then with each new one as it happens. */
  subscribe(listener: (diagnostic: StorageDiagnostic) => void): void {
    this.listener = listener;
    for (const diagnostic of this.diagnostics) {
      listener(diagnostic);
    }
  }

  constructor() {
    this.backendPromise = (async () => {
      // Prefer the configured iframe storage when available. hubStorage may
      // already be enabled by another window/server, but the iframe origin is
      // the server-configured storage boundary.
      if (Byond.storageCdn) {
        const iframe = new IFrameIndexedDbBackend(() => // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: const iframe = new IFrameIndexedDbBackend((key) =>
          this.log(
            'warn',
            "Some of your saved chat data didn't load in time. Using defaults for now, and not saving over what you had.", // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: `Timed out reading '${key}'. Using defaults for now, and not saving over what you had.`,
          ),
        );

        if ((await iframe.ready()) === true) {
          this.log('info', `Using iframe storage (${Byond.storageCdn})`);

          if (await iframe.get('byondstorage-migrated')) return iframe;
          // APHELION EDIT ADDITION START - CHAT_SETTINGS
          // only import into a store that answered, since one that didn't can still hold the player's settings
          if (iframe.isUnread('byondstorage-migrated')) return iframe;
          // APHELION EDIT ADDITION END

          const iframeHasPersistedStorage = (
            await Promise.all(
              persistedStorageKeys.map((setting) => iframe.get(setting)),
            )
          ).some((settings) => settings !== undefined);
          // APHELION EDIT ADDITION START - CHAT_SETTINGS
          if (persistedStorageKeys.some((key) => iframe.isUnread(key))) {
            return iframe;
          }
          // APHELION EDIT ADDITION END

          if (!iframeHasPersistedStorage) {
            this.log(
              'info',
              'No existing iframe data, migrating from byondstorage',
            );
            const hubStorageWasEnabled = testHubStorage();
            if (!hubStorageWasEnabled) {
              Byond.winset(null, 'browser-options', '+byondstorage');

              await new Promise<void>((resolve) => {
                document.addEventListener(
                  'byondstorageupdated',
                  () => {
                    // This event is emitted *before* byondstorage is actually
                    // created, so we have to wait a little bit before using it.
                    setTimeout(resolve, 1);
                  },
                  { once: true },
                );
              });
            }

            const hub = new HubStorageBackend();

            // Migrate safe legacy settings from byondstorage to the IFrame.
            // Chat history may contain server-specific HTML/components from
            // other codebases that shared the old byondstorage namespace.
            await Promise.all(
              legacyHubMigrationKeys.map(async (setting) => {
                try {
                  const settings = await hub.get(setting);
                  if (settings !== undefined) {
                    await iframe.set(setting, settings);
                    this.log('info', `Migrated '${setting}' from byondstorage`);
                  }
                } catch {
                  this.log(
                    'warn',
                    `Failed to migrate '${setting}' from byondstorage`,
                  );
                }
              }),
            );

            if (!hubStorageWasEnabled) {
              Byond.winset(null, 'browser-options', '-byondstorage');
            }
          }

          await iframe.set('byondstorage-migrated', true);

          return iframe;
        }

        this.log(
          'warn',
          `Iframe storage failed to load from ${Byond.storageCdn}`,
        );
        iframe.destroy();
      } else {
        this.log('info', 'No storage CDN configured');
      }

      if (testHubStorage()) {
        this.log('warn', 'Falling back to hubStorage (byondstorage)');
        return new HubStorageBackend();
      }

      // IFrame hasn't worked out for us, we'll need to enable byondstorage
      this.log('warn', 'Enabling byondstorage as last resort');
      Byond.winset(null, 'browser-options', '+byondstorage');

      return new Promise((resolve) => {
        const listener = () => {
          document.removeEventListener('byondstorageupdated', listener);

          // This event is emitted *before* byondstorage is actually created
          // so we have to wait a little bit before we can use it
          setTimeout(() => resolve(new HubStorageBackend()), 1);
        };

        document.addEventListener('byondstorageupdated', listener);
      });
    })();
  }

  async getImpl(): Promise<StorageImplementation> {
    return (await this.backendPromise).impl;
  }

  async get(key: string): Promise<any> {
    const backend = await this.backendPromise;
    try {
      return await backend.get(key);
    } catch {
      // usually a save that got cut off halfway, so it isn't valid json anymore. nothing in there to rescue, and letting it throw leaves chat dead on every join
      this.log(
        'warn',
        `Your saved '${key}' was unreadable, so it's starting fresh.`,
      );
      return undefined;
    }
  }

  // APHELION EDIT ADDITION START - CHAT_SETTINGS
  /** Lets `keys` be saved even if they couldn't be read, like when the player imports a settings file */
  async allowSaving(...keys: string[]): Promise<void> {
    const backend = await this.backendPromise;
    if (!(backend instanceof IFrameIndexedDbBackend)) return;
    for (const key of keys) backend.markRead(key);
  }

  // APHELION EDIT ADDITION END
  async set(key: string, value: any): Promise<void> {
    const backend = await this.backendPromise;
    return backend.set(key, value);
  }

  async remove(key: string): Promise<void> {
    const backend = await this.backendPromise;
    return backend.remove(key);
  }

  async clear(): Promise<void> {
    const backend = await this.backendPromise;
    return backend.clear();
  }
}

export const storage = new StorageProxy();
