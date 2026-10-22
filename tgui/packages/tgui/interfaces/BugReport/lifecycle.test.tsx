import { afterEach, beforeEach, expect, test, spyOn } from 'bun:test';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import * as actions from '../../events/act';
import { gameDataAtom, store } from '../../events/store';
import { BugReport } from './index';

const fields = {
  title: 'Original title',
  observed: 'Closed door',
  expected: 'Opens',
  reproduction: 'Click door',
  category: 'Other',
  severity: 'minor',
  incidentAt: null,
};
let send: ReturnType<typeof spyOn<typeof actions, 'sendAct'>>;
beforeEach(() => {
  store.set(gameDataAtom, {
    fields,
    reportId: 'one',
    fieldsEpoch: 0,
    revision: 0,
    status: 'Ready',
    busy: false,
  });
  send = spyOn(actions, 'sendAct').mockImplementation(() => undefined);
});
afterEach(() => {
  cleanup();
  send.mockRestore();
});

test('R8: authoritative epoch and report changes hydrate fields without replacing local edits on status refresh', () => {
  const view = render(<BugReport />);
  const title = () => screen.getAllByRole('textbox')[0] as HTMLInputElement;
  act(() =>
    store.set(gameDataAtom, {
      ...store.get(gameDataAtom),
      fields: { ...fields, title: 'Browser revision' },
      fieldsEpoch: 1,
      revision: 1,
    }),
  );
  view.rerender(<BugReport />);
  expect(title().value).toBe('Browser revision');
  fireEvent.input(title(), { target: { value: 'Unsaved local edit' } });
  expect(send).toHaveBeenLastCalledWith('draft', {
    fields: { ...fields, title: 'Unsaved local edit' },
    fieldsEpoch: 1,
  });
  act(() => store.set(gameDataAtom, { ...store.get(gameDataAtom), status: 'Polling attachment' }));
  view.rerender(<BugReport />);
  expect(title().value).toBe('Unsaved local edit');
  act(() =>
    store.set(gameDataAtom, {
      ...store.get(gameDataAtom),
      reportId: 'two',
      fieldsEpoch: 0,
      fields: { ...fields, title: 'Another incident' },
    }),
  );
  view.rerender(<BugReport />);
  expect(title().value).toBe('Another incident');
});

test('R8: divergent browser draft offers explicit load or keep-local resolution', () => {
  store.set(gameDataAtom, { ...store.get(gameDataAtom), conflict: true });
  render(<BugReport />);
  fireEvent.click(screen.getByText('Load browser draft'));
  expect(send).toHaveBeenLastCalledWith('reload');
  fireEvent.click(screen.getByText('Keep my local text'));
  expect(send).toHaveBeenLastCalledWith('keep', { fields, fieldsEpoch: 0 });
});

test('R9: a paused transport check leaves text editable and exposes explicit retry', () => {
  store.set(gameDataAtom, {
    ...store.get(gameDataAtom),
    result: { kind: 'checking' },
    pollingPaused: true,
  });
  render(<BugReport />);
  expect((screen.getAllByRole('textbox')[0] as HTMLInputElement).disabled).toBe(false);
  fireEvent.click(screen.getByText('Retry connection'));
  expect(send).toHaveBeenLastCalledWith('refresh');
});

test('approved context and optional incident time are visible and preserve exact UTC text', () => {
  store.set(gameDataAtom, {
    ...store.get(gameDataAtom),
    context: {
      roundId: '42',
      map: 'Fixture map',
      capturedAt: 'unix-seconds:1792672496.789',
      versions: {
        client: { version: 516, build: 1687 },
        server: { version: 516, build: 1688 },
        compiler: { version: 516, build: 1686 },
      },
      build: { commit: 'abc123', base: 'def456', testMerges: [{ number: 7, commit: 'feed123' }] },
    },
  });
  render(<BugReport />);
  expect(screen.getByText(/Round: 42/)).toBeTruthy();
  expect(screen.getByText(/Client: 516.1687/)).toBeTruthy();
  const time = screen.getByPlaceholderText('YYYY-MM-DDTHH:mm:ss.sssZ');
  fireEvent.input(time, { target: { value: '2026-10-22T12:34:56.789Z' } });
  expect(send).toHaveBeenLastCalledWith('draft', {
    fields: { ...fields, incidentAt: '2026-10-22T12:34:56.789Z' },
    fieldsEpoch: 0,
  });
});
