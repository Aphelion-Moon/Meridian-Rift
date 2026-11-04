// THIS IS AN APHELION UI FILE

import { expect, test } from 'bun:test';
import { SnapshotTransfer } from './transfer';

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const timings = { chunk: 4, limit: 64, spacing: 40, ackTimeout: 120, tries: 2 };

function recorder() {
  const sent: { type: string; payload: any }[] = [];
  return {
    sent,
    send: (type: string, payload: any) => sent.push({ type, payload }),
  };
}

test('chunks go out in order, each after its acknowledgement and the spacing', async () => {
  const { sent, send } = recorder();
  const outcome: boolean[] = [];
  const transfer = new SnapshotTransfer(send, {
    ...timings,
    finished: (ok) => outcome.push(ok),
  });
  transfer.start('nonce', 'AAAABBBBCC==');
  await wait(10);
  expect(sent.length).toBe(1);
  expect(sent[0].payload).toEqual({
    nonce: 'nonce',
    index: 0,
    totalLength: 12,
    data: 'AAAA',
  });
  transfer.acknowledge({ nonce: 'wrong', index: 0 });
  transfer.acknowledge({ nonce: 'nonce', index: 1 });
  transfer.acknowledge({ nonce: 'nonce', index: 0 });
  await wait(10);
  // Acknowledged at once, but the spacing holds the next chunk back
  expect(sent.length).toBe(1);
  await wait(50);
  expect(sent.length).toBe(2);
  expect(sent[1].payload.data).toBe('BBBB');
  transfer.acknowledge({ nonce: 'nonce', index: 1 });
  await wait(60);
  expect(sent[2].payload.data).toBe('CC==');
  transfer.acknowledge({ nonce: 'nonce', index: 2 });
  expect(transfer.active).toBe(false);
  expect(outcome).toEqual([true]);
});

test('a lost acknowledgement sends the same chunk again, then the transfer gives up', async () => {
  const { sent, send } = recorder();
  const outcome: boolean[] = [];
  const transfer = new SnapshotTransfer(send, {
    ...timings,
    finished: (ok) => outcome.push(ok),
  });
  transfer.start('nonce', 'AAAABBBB');
  await wait(180);
  expect(sent.length).toBe(2);
  expect(sent[1].payload).toEqual(sent[0].payload);
  await wait(180);
  // The server reads why, which here is the chunks never arriving
  expect(sent.at(-1)).toEqual({
    type: 'bug-report/capture-cancel',
    payload: { nonce: 'nonce', reason: 'interrupted' },
  });
  expect(transfer.active).toBe(false);
  expect(outcome).toEqual([false]);
});

test('a cancel tells the server why, the player cancelling when nothing says otherwise', () => {
  const { sent, send } = recorder();
  for (const reason of [undefined, 'timed_out'] as const) {
    const transfer = new SnapshotTransfer(send, timings);
    transfer.start('nonce', 'AAAABBBB');
    transfer.cancel(reason);
  }
  expect(sent.map((item) => item.payload)).toEqual([
    { nonce: 'nonce', reason: 'cancelled' },
    { nonce: 'nonce', reason: 'timed_out' },
  ]);
});

test('an image over the limit, broken base64 or a second transfer is refused', () => {
  const { sent, send } = recorder();
  const transfer = new SnapshotTransfer(send, timings);
  expect(() => transfer.start('nonce', 'A'.repeat(68))).toThrow();
  expect(() => transfer.start('nonce', 'AAA')).toThrow();
  expect(() => transfer.start('nonce', 'AA~A')).toThrow();
  transfer.start('nonce', 'AAAA');
  expect(() => transfer.start('another', 'AAAA')).toThrow();
  transfer.cancel();
  transfer.cancel();
  expect(
    sent.filter((item) => item.type === 'bug-report/capture-cancel').length,
  ).toBe(1);
  expect(transfer.active).toBe(false);
});
