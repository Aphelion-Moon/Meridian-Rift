/**
 * Browser-agnostic abstraction of key-value web storage.
 *
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

export const IMPL_HUB_STORAGE = 1;
export const IMPL_IFRAME_INDEXED_DB = 2;

type StorageImplementation =
  | typeof IMPL_HUB_STORAGE
  | typeof IMPL_IFRAME_INDEXED_DB;

type StorageBackend = {
  impl: StorageImplementation;
  get(key: string): Promise<any>;
  // APHELION EDIT ADDITION START - CHAT_SETTINGS
  /**
   * The stored value, or undefined when nothing is stored. Rejects when the
   * store can't answer, so a caller never takes a failed read for an empty
   * store and saves defaults over what is there.
   */
  read(key: string): Promise<any>;
  // APHELION EDIT ADDITION END
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

  // APHELION EDIT ADDITION START - CHAT_SETTINGS
  async read(key: string): Promise<any> {
    return this.get(key);
  }

  // APHELION EDIT ADDITION END
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
  // APHELION EDIT ADDITION START - CHAT_SETTINGS
  /** How long a read waits for the iframe before it counts as failed, in ms. */
  private timeout: number;
  // APHELION EDIT ADDITION END

  constructor(timeout = STORAGE_CDN_TIMEOUT) { // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: constructor() {
    this.impl = IMPL_IFRAME_INDEXED_DB;
    this.timeout = timeout; // APHELION EDIT ADDITION - CHAT_SETTINGS
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
  async get(key: string): Promise<any> {
    return this.read(key).catch(() => undefined);
  }

  // APHELION EDIT ADDITION END
  async read(key: string): Promise<any> { // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: async get(key: string): Promise<any> {
    const promise = new Promise((resolve, reject) => { // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: const promise = new Promise((resolve) => {
      const listener = (message: MessageEvent) => {
        if (
          message.source === this.iframeWindow &&
          message.data.key &&
          message.data.key === key
        ) {
          clearTimeout(timeout);
          window.removeEventListener('message', listener);
          // APHELION EDIT CHANGE START - CHAT_SETTINGS - ORIGINAL: resolve(message.data.value);
          if (message.data.error) {
            reject(
              new Error(
                `Storage couldn't read '${key}': ${message.data.error}`,
              ),
            );
          } else {
            resolve(message.data.value);
          }
          // APHELION EDIT CHANGE END
        }
      };
      const timeout = setTimeout(() => {
        window.removeEventListener('message', listener);
        // APHELION EDIT CHANGE START - CHAT_SETTINGS - ORIGINAL: resolve(undefined);
        reject(
          new Error(`Storage didn't answer for '${key}' in ${this.timeout} ms`),
        );
        // APHELION EDIT CHANGE END
      }, this.timeout); // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: }, STORAGE_CDN_TIMEOUT);

      window.addEventListener('message', listener);
    });

    this.iframeWindow.postMessage({ type: 'get', key: key }, '*');
    return promise;
  }

  async set(key: string, value: any): Promise<void> {
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
export class StorageProxy implements StorageBackend { // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: class StorageProxy implements StorageBackend {
  private backendPromise: Promise<StorageBackend>;
  public impl: StorageImplementation = IMPL_IFRAME_INDEXED_DB;
  public diagnostics: StorageDiagnostic[] = [];

  private log(level: StorageDiagnostic['level'], message: string) {
    this.diagnostics.push({ level, message });
  }

  constructor(createIframe = () => new IFrameIndexedDbBackend()) { // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: constructor() {
    this.backendPromise = (async () => {
      // Prefer the configured iframe storage when available. hubStorage may
      // already be enabled by another window/server, but the iframe origin is
      // the server-configured storage boundary.
      if (Byond.storageCdn) {
        const iframe = createIframe(); // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: const iframe = new IFrameIndexedDbBackend();

        if ((await iframe.ready()) === true) {
          this.log('info', `Using iframe storage (${Byond.storageCdn})`);

          /* // APHELION EDIT REMOVAL START - CHAT_SETTINGS
          if (await iframe.get('byondstorage-migrated')) return iframe;

          const iframeHasPersistedStorage = (
            await Promise.all(
              persistedStorageKeys.map((setting) => iframe.get(setting)),
            )
          ).some((settings) => settings !== undefined);
          */ // APHELION EDIT REMOVAL END
          // APHELION EDIT ADDITION START - CHAT_SETTINGS
          // Only a store that answers it is empty takes byondstorage's copy:
          // one that can't answer may hold the player's own settings.
          let iframeHasPersistedStorage: boolean;
          try {
            if (await iframe.read('byondstorage-migrated')) return iframe;

            iframeHasPersistedStorage = (
              await Promise.all(
                persistedStorageKeys.map((setting) => iframe.read(setting)),
              )
            ).some((settings) => settings !== undefined);
          } catch {
            this.log(
              'warn',
              "Couldn't read iframe storage, so nothing was imported from byondstorage",
            );
            return iframe;
          }
          // APHELION EDIT ADDITION END

          if (!iframeHasPersistedStorage) {
            this.log('info', 'No existing iframe data, migrating from byondstorage');
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
                  this.log('warn', `Failed to migrate '${setting}' from byondstorage`);
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

        this.log('warn', `Iframe storage failed to load from ${Byond.storageCdn}`);
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

  async get(key: string): Promise<any> {
    const backend = await this.backendPromise;
    return backend.get(key);
  }

  // APHELION EDIT ADDITION START - CHAT_SETTINGS
  async read(key: string): Promise<any> {
    const backend = await this.backendPromise;
    try {
      return await backend.read(key);
    } catch (error) {
      this.log('error', `Couldn't read '${key}' from storage`);
      throw error;
    }
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
