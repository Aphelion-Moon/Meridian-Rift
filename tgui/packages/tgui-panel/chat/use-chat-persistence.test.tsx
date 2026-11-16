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
import { settingsLoadedAtom } from '../settings/atoms';
import { chatLoadedAtom, chatReadAtom } from './atom';
import { saveChatToStorage } from './helpers';
import { useChatPersistence } from './use-chat-persistence';

function Probe() {
  useChatPersistence();
  return null;
}

/** The chat keys written during a test. */
let chatWrites: string[];

/** Stubs storage: `read` answers each chat key, or rejects when it can't. */
function stubStorage(read: (key: string) => Promise<unknown>) {
  chatWrites = [];
  Object.assign(storage, { read: mock(read) });
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
    store.set(chatLoadedAtom, false);
    store.set(chatReadAtom, false);
  });

  afterEach(() => {
    mock.restore();
    Object.assign(storage, { read: undefined });
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
