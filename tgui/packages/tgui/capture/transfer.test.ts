import { expect, test } from 'bun:test';

test('snapshot chunks wait for matching acknowledgments and stop on rejection', async () => {
  const module = await import('./transfer').catch(() => ({}) as any);
  expect(typeof module.SnapshotTransfer).toBe('function');
  const sent: any[] = [];
  const transfer = new module.SnapshotTransfer((type: string, payload: any) =>
    sent.push({ type, payload }),
  );
  transfer.start('nonce', 'A'.repeat(32768) + 'AAAA');
  expect(sent.length).toBe(1);
  expect(sent[0].payload.index).toBe(0);
  transfer.acknowledge({ nonce: 'wrong', index: 0, accepted: true });
  expect(sent.length).toBe(1);
  transfer.acknowledge({ nonce: 'nonce', index: 0, accepted: true });
  await new Promise((resolve) => setTimeout(resolve, 100));
  expect(sent.length).toBe(2);
  expect(sent[1].payload.data).toBe('AAAA');
  transfer.acknowledge({ nonce: 'nonce', index: 1, accepted: false });
  expect(transfer.active).toBe(false);
  transfer.acknowledge({ nonce: 'nonce', index: 1, accepted: true });
  await new Promise((resolve) => setTimeout(resolve, 100));
  expect(sent.length).toBe(2);
});

test('snapshot transfer bounds the entire image and rejects parallel capture', async () => {
  const module = await import('./transfer').catch(() => ({}) as any);
  expect(typeof module.SnapshotTransfer).toBe('function');
  const sent: any[] = [];
  const transfer = new module.SnapshotTransfer((type: string, payload: any) =>
    sent.push({ type, payload }),
  );
  expect(() => transfer.start('nonce', 'A'.repeat(2796208))).toThrow();
  expect(sent.length).toBe(0);
  transfer.start('nonce', 'AAAA');
  expect(() => transfer.start('another', 'AAAA')).toThrow();
  transfer.cancel();
  expect(sent.at(-1).type).toBe('bug-report/capture-cancel');
  expect(transfer.active).toBe(false);
});
