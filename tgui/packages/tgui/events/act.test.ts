// APHELION MODULE - BUG_REPORTING - BYOND_POST_MESSAGE
// THIS IS AN APHELION UI FILE

import { expect, type Mock, spyOn, test } from 'bun:test';
import { chunkingAtom, store } from './store';

/** The test setup swaps this module for a stub, and a query in the path loads the real one beside it */
const REAL_ACT = './act.ts?real';

/** A paper's worth of Cyrillic, about 30 KB once encoded for a URL */
const PAYLOAD = { text: 'ж'.repeat(5000) };

test('a 30 KB act is one message when calls are posted, and still goes in chunks when they are not', async () => {
  const { sendAct }: typeof import('./act') = await import(REAL_ACT);
  // Typed as sendAct calls it, since spyOn takes the last overload
  const sent = spyOn(Byond, 'sendMessage').mockImplementation(
    () => undefined,
  ) as Mock<(type: string, payload: object) => void>;
  const posting = Byond.POST_MESSAGE;
  const queues = store.get(chunkingAtom);
  try {
    Byond.POST_MESSAGE = true;
    sendAct('add_text', PAYLOAD);
    expect(sent.mock.calls).toEqual([['act/add_text', PAYLOAD]]);
    sent.mockClear();
    Byond.POST_MESSAGE = false;
    sendAct('add_text', PAYLOAD);
    expect(sent.mock.calls.length).toBe(1);
    const [type, request] = sent.mock.calls[0] as [
      string,
      { type: string; id: string; chunkCount: number },
    ];
    expect(type).toBe('oversizedPayloadRequest');
    expect(request.type).toBe('act/add_text');
    const chunks: string[] = store.get(chunkingAtom)[request.id];
    expect(chunks.length).toBe(request.chunkCount);
    expect(chunks.length > 1).toBe(true);
    expect(chunks.join('')).toBe(JSON.stringify(PAYLOAD));
  } finally {
    Byond.POST_MESSAGE = posting;
    store.set(chunkingAtom, queues);
    sent.mockRestore();
  }
});
