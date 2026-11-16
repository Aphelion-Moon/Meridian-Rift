import { type StorageDiagnostic, storage } from 'common/storage';
import DOMPurify from 'dompurify';
import { useAtom, useAtomValue } from 'jotai';
import { useEffect } from 'react';
import { store } from '../events/store'; // APHELION EDIT ADDITION - CHAT_SETTINGS
import { settingsLoadedAtom, settingsReadAtom } from '../settings/atoms'; // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: import { settingsLoadedAtom } from '../settings/atoms';
import { chatLoadedAtom, chatReadAtom, versionAtom } from './atom'; // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: import { chatLoadedAtom, versionAtom } from './atom';
import { MESSAGE_SAVE_INTERVAL } from './constants';
import { saveChatToStorage } from './helpers';
import { startChatStateMigration } from './migration';
import { createMessage } from './model';
import { chatRenderer } from './renderer';

// List of blacklisted tags
const FORBID_TAGS = ['a', 'iframe', 'link', 'video'];

/**
 * Custom hook that initializes chat from local storage and periodically saves
 * it back
 */
export function useChatPersistence() {
  const version = useAtomValue(versionAtom);

  const [loaded, setLoaded] = useAtom(chatLoadedAtom);
  const settingsLoaded = useAtomValue(settingsLoadedAtom);

  /** Loads chat + chat settings */
  useEffect(() => {
    if (!loaded && settingsLoaded) {
      async function fetchChat(): Promise<void> {
        console.log('Initializing chat');
        await loadChatFromStorage();

        setLoaded(true);
        chatRenderer.onStateLoaded();
      }

      fetchChat();
    }
  }, [loaded, settingsLoaded, setLoaded]);

  /** Periodically saves chat + chat settings */
  useEffect(() => {
    let saveInterval: NodeJS.Timeout;

    if (loaded) {
      saveInterval = setInterval(saveChatToStorage, MESSAGE_SAVE_INTERVAL);
    }

    return () => clearInterval(saveInterval);
  }, [loaded]);

  async function loadChatFromStorage(): Promise<void> {
    /* // APHELION EDIT REMOVAL START - CHAT_SETTINGS
    const [state, messages] = await Promise.all([
      storage.get('chat-state'),
      storage.get('chat-messages'),
    ]);
    */ // APHELION EDIT REMOVAL END
    // APHELION EDIT ADDITION START - CHAT_SETTINGS
    let state: any;
    let messages: any;
    try {
      [state, messages] = await Promise.all([
        storage.read('chat-state'),
        storage.read('chat-messages'),
      ]);
      store.set(chatReadAtom, true);
    } catch (error) {
      // Default tabs this session, and nothing saved over the player's chat.
      console.error('Failed to load chat from storage:', error);
    }
    // What didn't load, said in chat so the player knows it's kept.
    const notLoaded: StorageDiagnostic[] = [];
    if (!store.get(settingsReadAtom)) {
      notLoaded.push({
        level: 'warn',
        message:
          "Your chat settings didn't load, so this session uses the defaults and doesn't save changes. Your saved settings are kept and come back next time.",
      });
    }
    if (!store.get(chatReadAtom)) {
      notLoaded.push({
        level: 'warn',
        message:
          "Your chat tabs and history didn't load, so this session starts fresh and isn't saved. Your saved ones are kept and come back next time.",
      });
    }
    // APHELION EDIT ADDITION END

    surfaceStorageDiagnostics([...storage.diagnostics, ...notLoaded]); // APHELION EDIT CHANGE - CHAT_SETTINGS - ORIGINAL: surfaceStorageDiagnostics(storage.diagnostics);

    if (messages) {
      handleMessages(messages);
    }

    // Empty settings, set defaults
    if (!state) {
      console.log('Initialized chat with default settings');
    } else if (state && 'version' in state && state.version === version) {
      console.log('Loaded chat state from storage:', state);
      startChatStateMigration(state);
    } else {
      // Discard incompatible versions
      console.log('Discarded incompatible chat state from storage:', state);
    }
  }

  function surfaceStorageDiagnostics(diagnostics: StorageDiagnostic[]) {
    const hasIssues = diagnostics.some((d) => d.level !== 'info');
    if (!hasIssues) return;

    const batch = diagnostics
      .filter((d) => d.level !== 'info')
      .map((d) =>
        createMessage({
          type: 'internal/storage',
          text: `[Storage] ${d.message}`,
        }),
      );

    if (batch.length) {
      chatRenderer.processBatch(batch, {
        prepend: true,
        suppressHighlightSound: true,
      });
    }
  }

  function handleMessages(messages: any[]): void {
    for (const message of messages) {
      if (message.html) {
        message.html = DOMPurify.sanitize(message.html, {
          FORBID_TAGS,
        });
      }
    }

    const batch = [
      ...messages,
      createMessage({
        type: 'internal/reconnected',
      }),
    ];

    chatRenderer.processBatch(batch, {
      prepend: true,
      suppressHighlightSound: true,
    });

    console.log(`Restored chat with ${messages.length} messages`);
  }
}
