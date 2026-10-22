// THIS IS AN APHELION UI FILE

import { afterEach, beforeEach, expect, spyOn, test } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { storage } from 'common/storage';
import * as actions from '../../events/act';
import { gameDataAtom, gameStaticDataAtom, store } from '../../events/store';
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
const wait = (ms: number) =>
  act(() => new Promise<void>((resolve) => setTimeout(resolve, ms)));
const title = () => screen.getAllByRole('textbox')[0] as HTMLInputElement;
let stored: any;
let spies: { mockRestore: () => void }[] = [];
let send: ReturnType<typeof spyOn<typeof actions, 'sendAct'>>;

/** The actions that went out with the form attached, the ones carrying its long text */
const formActions = () =>
  send.mock.calls
    .filter(([, payload]) => payload && 'fields' in payload)
    .map(([action]) => action);

function setStatic(values: Record<string, unknown>) {
  store.set(gameStaticDataAtom, {
    ...store.get(gameStaticDataAtom),
    ...values,
  });
}
function setData(values: Record<string, unknown>) {
  store.set(gameDataAtom, { ...store.get(gameDataAtom), ...values });
}

beforeEach(() => {
  store.set(gameStaticDataAtom, { reportId: 'one', fieldsEpoch: 0, fields });
  store.set(gameDataAtom, { status: 'Ready', busy: false });
  stored = undefined;
  send = spyOn(actions, 'sendAct').mockImplementation(() => undefined);
  spies = [
    send,
    spyOn(storage, 'get').mockImplementation(async () => stored),
    spyOn(storage, 'set').mockImplementation(async (_key, value) => {
      stored = value;
    }),
  ];
});
afterEach(() => {
  cleanup();
  for (const spy of spies) spy.mockRestore();
});

test('typing stays in the browser until an action sends the text', async () => {
  render(<BugReport />);
  fireEvent.input(title(), { target: { value: 'Unsaved local edit' } });
  await wait(600);
  expect(send).not.toHaveBeenCalled();
  expect(stored?.one?.fields.title).toBe('Unsaved local edit');
});

test('text typed before the window closed comes back when it reopens', async () => {
  const view = render(<BugReport />);
  fireEvent.input(title(), { target: { value: 'Typed before closing' } });
  view.unmount();
  await wait(10);
  render(<BugReport />);
  await wait(10);
  expect(title().value).toBe('Typed before closing');
});

test('the server replaces local text only with a new epoch or another report', () => {
  const view = render(<BugReport />);
  act(() =>
    setStatic({ fields: { ...fields, title: 'Saved draft' }, fieldsEpoch: 1 }),
  );
  view.rerender(<BugReport />);
  expect(title().value).toBe('Saved draft');
  fireEvent.input(title(), { target: { value: 'Unsaved local edit' } });
  act(() => setData({ status: 'Polling attachment' }));
  view.rerender(<BugReport />);
  expect(title().value).toBe('Unsaved local edit');
  act(() =>
    store.set(gameStaticDataAtom, {
      reportId: 'two',
      fieldsEpoch: 0,
      fields: { ...fields, title: 'Another incident' },
    }),
  );
  view.rerender(<BugReport />);
  expect(title().value).toBe('Another incident');
});

test('a submission sends all of its text in one message, however long', () => {
  const long = 'x'.repeat(8000);
  const full = {
    ...fields,
    observed: long,
    expected: long,
    reproduction: long,
  };
  setStatic({ fields: full });
  render(<BugReport />);
  fireEvent.click(screen.getByText('Submit report'));
  expect(send.mock.calls).toEqual([
    ['submit', { fields: full, fieldsEpoch: 0 }],
  ]);
});

test('a moved-on saved draft offers loading it or keeping the local text', () => {
  setData({ conflict: true });
  render(<BugReport />);
  fireEvent.click(screen.getByText('Load saved draft'));
  expect(send).toHaveBeenLastCalledWith('reload');
  fireEvent.click(screen.getByText('Keep my local text'));
  expect(send).toHaveBeenLastCalledWith('keep', {
    fields,
    fieldsEpoch: 0,
  });
});

test('the map capture and the file prompt never navigate the browser', () => {
  const command = spyOn(Byond, 'command').mockImplementation(() => undefined);
  try {
    render(<BugReport />);
    fireEvent.click(screen.getByText('Capture game map (F2)'));
    expect(command).toHaveBeenCalledWith('.screenshot auto');
    expect(screen.queryByText(/If no image was saved, press F2/) !== null).toBe(
      true,
    );
    fireEvent.click(screen.getByText('Choose screenshot'));
    expect(send).toHaveBeenLastCalledWith('screenshot', {
      fields,
      fieldsEpoch: 0,
    });
  } finally {
    command.mockRestore();
  }
});

test('a snapshot names only the picked window, and focus or the refresh button asks for the window list again', () => {
  setData({ captureTargets: [{ id: 'tgui_2', title: 'Machine controls' }] });
  render(<BugReport />);
  expect(screen.queryAllByText('Machine controls').length > 0).toBe(true);
  fireEvent.click(screen.getByText('Snapshot selected TGUI'));
  expect(send).toHaveBeenLastCalledWith('capture_ui', {
    windowId: 'tgui_2',
    fields,
    fieldsEpoch: 0,
  });
  fireEvent.focus(window);
  expect(send).toHaveBeenLastCalledWith('targets');
  send.mockClear();
  const refresh = document
    .querySelector('[class*="fa-sync"]')
    ?.closest('.Button');
  expect(!!refresh).toBe(true);
  fireEvent.click(refresh!);
  expect(send).toHaveBeenLastCalledWith('targets');
});

test('a pending screenshot holds submission, and a ready one asks for its preview once', () => {
  setData({
    attachmentPending: true,
    attachment: { id: 'one', state: 'processing', publicConsent: false },
  });
  const view = render(<BugReport />);
  fireEvent.click(screen.getByText('Submit report'));
  expect(formActions()).toEqual([]);
  fireEvent.click(screen.getByText('Remove screenshot'));
  expect(send).toHaveBeenLastCalledWith('remove_screenshot', {
    attachmentId: 'one',
  });
  act(() =>
    setData({
      attachmentPending: false,
      attachment: { id: 'one', state: 'ready', publicConsent: false },
    }),
  );
  view.rerender(<BugReport />);
  expect(send).toHaveBeenLastCalledWith('preview', { attachmentId: 'one' });
  act(() =>
    setData({ preview: { id: 'one', src: 'data:image/png;base64,AAAA' } }),
  );
  view.rerender(<BugReport />);
  fireEvent.load(screen.getByAltText('Selected report screenshot'));
  expect(send).toHaveBeenLastCalledWith('preview_loaded', {
    attachmentId: 'one',
  });
  act(() => setData({ previewConfirmed: true }));
  view.rerender(<BugReport />);
  fireEvent.click(
    screen.getByText('Publish this screenshot with the GitHub issue'),
  );
  expect(send).toHaveBeenLastCalledWith('screenshot_consent', {
    attachmentId: 'one',
    publicConsent: true,
  });
  expect(
    send.mock.calls.filter(([action]) => action === 'preview').length,
  ).toBe(1);
});

test('a paused check leaves the text editable and offers a retry', () => {
  setData({ result: { kind: 'checking' }, pollingPaused: true });
  render(<BugReport />);
  expect(title().disabled).toBe(false);
  fireEvent.click(screen.getByText('Retry connection'));
  expect(send).toHaveBeenLastCalledWith('refresh');
});

test('the frozen context shows, and the incident time goes out as exact UTC text', () => {
  setStatic({
    context: {
      roundId: '42',
      map: 'Fixture map',
      capturedAt: 'unix-seconds:1792672496.789',
      versions: {
        client: { version: 516, build: 1687 },
        server: { version: 516, build: 1688 },
        compiler: { version: 516, build: 1686 },
      },
      build: {
        commit: 'abc123',
        base: 'def456',
        testMerges: [{ number: 7, commit: 'feed123' }],
      },
    },
  });
  render(<BugReport />);
  expect(screen.queryByText(/Round: 42/) !== null).toBe(true);
  expect(screen.queryByText(/Client: 516.1687/) !== null).toBe(true);
  const time = screen.getByPlaceholderText('YYYY-MM-DDTHH:mm:ss.sssZ');
  fireEvent.input(time, { target: { value: '2026-10-22T12:34:56.789Z' } });
  fireEvent.click(screen.getByText('Submit report'));
  expect(send).toHaveBeenLastCalledWith('submit', {
    fields: { ...fields, incidentAt: '2026-10-22T12:34:56.789Z' },
    fieldsEpoch: 0,
  });
});
