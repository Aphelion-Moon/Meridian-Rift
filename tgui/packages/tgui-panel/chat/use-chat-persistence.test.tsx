// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  mock,
  spyOn,
} from 'bun:test';
import { act, render } from '@testing-library/react';
import { storage } from 'common/storage';
import { Provider } from 'jotai';
import { store } from '../events/store';
import { settingsLoadedAtom, settingsReadAtom } from '../settings/atoms';
import { chatLoadedAtom, chatReadAtom } from './atom';
import { saveChatToStorage } from './helpers';
import { chatRenderer } from './renderer';
import { useChatPersistence } from './use-chat-persistence';

function Probe() {
  useChatPersistence();
  return null;
}

/** The chat keys written in a test. */
let chatWrites: string[];

/** Stubs storage. `read` answers each chat key, or rejects if the read fails. */
function stubStorage(read: (key: string) => Promise<unknown>) {
  chatWrites = [];
  spyOn(storage, 'read').mockImplementation(read);
  spyOn(storage, 'get').mockImplementation((key: string) =>
    read(key).catch(() => undefined),
  );
  spyOn(storage, 'set').mockImplementation(async (key: string) => {
    if (key === 'chat-state' || key === 'chat-messages') chatWrites.push(key);
  });
}

async function mountChat() {
  render(
    <Provider store={store}>
      <Probe />
    </Provider>,
  );
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 20));
  });
}

describe('chat persistence', () => {
  beforeEach(() => {
    store.set(settingsLoadedAtom, true);
    store.set(settingsReadAtom, true);
    store.set(chatLoadedAtom, false);
    store.set(chatReadAtom, false);
  });

  afterEach(() => {
    mock.restore();
  });

  /**
   * The lines put in chat while `load` runs that tell the player something of
   * theirs didn't load. The test world's own storage notes are left out.
   */
  async function notLoadedLines(load: () => Promise<void>): Promise<string[]> {
    const batches = spyOn(chatRenderer, 'processBatch').mockImplementation(
      () => {},
    );
    await load();
    return batches.mock.calls
      .flatMap(([batch]) => batch as { text?: string }[])
      .map((message) => message.text ?? '')
      .filter((text) => text.startsWith('[Storage] Your '));
  }

  it('says in chat what did not load, in plain words', async () => {
    store.set(settingsReadAtom, false);
    stubStorage(() => Promise.reject(new Error('storage did not answer')));
    const lines = await notLoadedLines(mountChat);

    expect(lines).toHaveLength(2);
    expect(lines[0]).toContain("Your chat settings didn't load");
    expect(lines[1]).toContain("Your chat tabs and history didn't load");
  });

  it('says nothing of the kind when everything loaded', async () => {
    stubStorage(async () => undefined);
    const lines = await notLoadedLines(mountChat);

    expect(lines).toEqual([]);
  });

  it('does not save over stored chat it could not read', async () => {
    stubStorage(() => Promise.reject(new Error('storage did not answer')));
    await mountChat();

    expect(store.get(chatLoadedAtom)).toBe(true);
    // What the periodic save and a round restart call.
    saveChatToStorage();
    expect(chatWrites).toEqual([]);
  });

  it('saves chat once the stored chat was read', async () => {
    stubStorage(async () => undefined);
    await mountChat();

    saveChatToStorage();
    expect(chatWrites).toEqual(['chat-messages', 'chat-state']);
  });
});
