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
  expected: 'Opens',
  reproduction: '1. Click door',
  category: 'Other',
  severity: 'unspecified',
};
const staticData = {
  reportId: 'one',
  enabled: true,
  fields,
  fieldsEpoch: 0,
  limits: {
    title: 160,
    text: 8000,
    steps: 20,
    reports: 5,
    sends: 10,
    uploads: 5,
  },
  maxPictures: 3,
  kinds: [
    { value: 'Gameplay', label: 'Gameplay', icon: 'gamepad' },
    { value: 'Other', label: 'Something else', icon: 'circle-question' },
  ],
  impacts: [
    { value: 'critical', label: 'It stops me playing' },
    { value: 'minor', label: "It's small, or it just looks wrong" },
  ],
};
// What DM sends with nothing going on: lazy lists and the result arrive as null
const idle = {
  status: null,
  busy: false,
  result: null,
  conflict: false,
  pollingPaused: false,
  unreachable: false,
  limit: null,
  pictures: null,
  uploadsLeft: 5,
  captureTargets: null,
};
const picture = {
  id: 1,
  source: 'view',
  title: null,
  take: 1,
  takenAgo: 1000,
  state: 'ready',
  reason: null,
  publicConsent: false,
  previewSeen: false,
};
const wait = (ms: number) =>
  act(() => new Promise<void>((resolve) => setTimeout(resolve, ms)));
const button = (name: string | RegExp) => screen.getByRole('button', { name });
const hasButton = (name: string | RegExp) =>
  screen.queryAllByRole('button', { name }).length > 0;
const hasText = (text: string | RegExp) =>
  screen.queryAllByText(text).length > 0;
const field = (name: string | RegExp) =>
  screen.getByLabelText(name) as HTMLInputElement;
const steps = () =>
  screen.queryAllByLabelText(/^Step \d+$/) as HTMLInputElement[];
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
/** Sends the window an update, which tgui's root renders again for */
function setData(values: Record<string, unknown>) {
  act(() => store.set(gameDataAtom, { ...store.get(gameDataAtom), ...values }));
  shown?.rerender(<BugReport />);
}
let shown: ReturnType<typeof render> | undefined;
function show() {
  shown = render(<BugReport />);
  return shown;
}
/** Opens the window and walks it to a page, the form already filled */
function openAt(page: number) {
  const view = show();
  for (let at = 1; at < page; at++) fireEvent.click(button('Next'));
  return view;
}

beforeEach(() => {
  store.set(gameStaticDataAtom, staticData);
  store.set(gameDataAtom, idle);
  stored = undefined;
  shown = undefined;
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
  show();
  fireEvent.change(field('Report title'), {
    target: { value: 'Unsaved local edit' },
  });
  await wait(600);
  expect(send.mock.calls.length).toBe(0);
  expect(stored?.one?.fields.title).toBe('Unsaved local edit');
});

test('text typed before the window closed comes back when it reopens', async () => {
  const view = show();
  fireEvent.change(field('Report title'), {
    target: { value: 'Typed before closing' },
  });
  view.unmount();
  await wait(10);
  show();
  await wait(10);
  expect(field('Report title').value).toBe('Typed before closing');
});

test('the server replaces local text only with a new epoch or another report', () => {
  const view = show();
  act(() =>
    setStatic({ fields: { ...fields, title: 'Saved draft' }, fieldsEpoch: 1 }),
  );
  view.rerender(<BugReport />);
  expect(field('Report title').value).toBe('Saved draft');
  fireEvent.change(field('Report title'), {
    target: { value: 'Unsaved local edit' },
  });
  setData({ status: 'Picture added' });
  expect(field('Report title').value).toBe('Unsaved local edit');
  act(() =>
    setStatic({
      reportId: 'two',
      fieldsEpoch: 0,
      fields: { ...fields, title: 'Another incident' },
    }),
  );
  view.rerender(<BugReport />);
  expect(field('Report title').value).toBe('Another incident');
});

test('a blank title holds Next with a summary and the same words by the field', () => {
  setStatic({ fields: { ...fields, title: ' \u00a0\ufeff' } });
  show();
  fireEvent.click(button('Next'));
  expect(hasText('Fill these in first')).toBe(true);
  expect(screen.getAllByText('Give it a title.').length).toBe(2);
  expect(field('Report title').getAttribute('aria-invalid')).toBe('true');
  expect(hasText('Add a picture')).toBe(false);
  fireEvent.change(field('Report title'), { target: { value: 'Door' } });
  fireEvent.click(button('Next'));
  expect(hasText('Add a picture')).toBe(true);
});

test('steps are numbered fields that Enter adds to and Backspace takes away', () => {
  openAt(3);
  expect(steps().map((step) => step.value)).toEqual(['Click door']);
  fireEvent.keyDown(steps()[0], { key: 'Enter' });
  expect(steps().length).toBe(2);
  expect(document.activeElement === steps()[1]).toBe(true);
  fireEvent.change(steps()[1], { target: { value: 'Walk through' } });
  fireEvent.click(button('Add a step'));
  expect(steps().length).toBe(3);
  fireEvent.keyDown(steps()[2], { key: 'Backspace' });
  expect(steps().length).toBe(2);
  expect(document.activeElement === steps()[1]).toBe(true);
  fireEvent.click(button('Remove step 1'));
  expect(steps().map((step) => step.value)).toEqual(['Walk through']);
  expect(hasButton(/^Remove step/)).toBe(false);
});

test('the review lists the steps numbered and the send joins them into one field', () => {
  openAt(3);
  fireEvent.keyDown(steps()[0], { key: 'Enter' });
  fireEvent.change(steps()[1], { target: { value: 'Walk through' } });
  fireEvent.click(button('Add a step'));
  fireEvent.click(button('Next'));
  expect(hasText('Review report')).toBe(true);
  expect(hasText(/1\. Click door\s+2\. Walk through/)).toBe(true);
  fireEvent.click(button('Send report'));
  expect(send.mock.calls).toEqual([
    [
      'submit',
      {
        fields: { ...fields, reproduction: '1. Click door\n2. Walk through' },
        fieldsEpoch: 0,
      },
    ],
  ]);
});

test('sending checks every page again and opens the first with a problem', () => {
  openAt(4);
  fireEvent.click(button('Change title'));
  fireEvent.change(field('Report title'), { target: { value: '' } });
  fireEvent.click(button(/step 4, Review report/));
  fireEvent.click(button('Send report'));
  expect(formActions()).toEqual([]);
  expect(field('Report title').getAttribute('aria-invalid')).toBe('true');
  expect(screen.getAllByText('Give it a title.').length).toBe(2);
});

test('a vague step asks once, and Keep it goes on as written', () => {
  setStatic({ fields: { ...fields, reproduction: '1. broken' } });
  openAt(3);
  fireEvent.click(button('Next'));
  expect(hasText(/won't help anyone find it/)).toBe(true);
  fireEvent.click(button('Keep it'));
  expect(hasText('Review report')).toBe(true);
});

test('a send-back opens the steps with the checker’s words under them', () => {
  openAt(4);
  setData({
    result: {
      kind: 'needs_revision',
      feedback: [
        {
          field: 'reproduction',
          message: 'Which airlock was it?',
          quote: 'Click door',
        },
      ],
    },
  });
  expect(hasText('Your report needs a little more')).toBe(true);
  expect(hasText('You wrote: "Click door"')).toBe(true);
  expect(screen.getAllByText(/Which airlock was it\?/).length).toBe(2);
  fireEvent.click(button('Next'));
  expect(hasButton('Send it again')).toBe(true);
});

test('an hourly limit shows the clock from limit, never the result’s stale wait', async () => {
  openAt(4);
  setData({
    result: { kind: 'limited', reason: 'admission', retryIn: 3_000_000 },
    limit: { kind: 'reports', retryIn: 5 * 60000 },
  });
  expect(
    hasText(
      /which is the limit\. You can send this one at \d\d:\d\d, in about 5 minutes/,
    ),
  ).toBe(true);
  expect(hasButton('Send report')).toBe(false);
  setData({ limit: { kind: 'sends', retryIn: 50 } });
  expect(hasText(/You've tried to send 10 times this hour/)).toBe(true);
  await wait(120);
  expect(hasButton('Send report')).toBe(true);
});

test('an unreachable server offers Try again, which asks DM to refresh', () => {
  openAt(4);
  setData({ unreachable: true, status: "Couldn't reach the report server." });
  expect(hasText("Couldn't reach the report server")).toBe(true);
  fireEvent.click(button('Try again'));
  expect(send).toHaveBeenLastCalledWith('refresh');
});

test('the sent page names the issue and opens it, or starts the next report', () => {
  show();
  setData({
    result: {
      kind: 'accepted',
      receipt: {
        screening: 'passed',
        publication: 'published',
        issueUrl: 'https://github.com/example/repo/issues/42',
        issueNumber: 42,
      },
    },
  });
  expect(hasText("Thanks. It's on GitHub as issue #42.")).toBe(true);
  fireEvent.click(button('Open it on GitHub'));
  expect(send).toHaveBeenLastCalledWith('issue');
  fireEvent.click(button('Report something else'));
  expect(send).toHaveBeenLastCalledWith('new');
});

test('a paused check offers Try again', () => {
  show();
  setData({ result: { kind: 'checking' }, pollingPaused: true });
  expect(hasText(/Lost touch with the report server/)).toBe(true);
  fireEvent.click(button('Try again'));
  expect(send).toHaveBeenLastCalledWith('refresh');
});

test('a moved-on saved draft offers loading it or keeping the local text', () => {
  setData({ conflict: true });
  show();
  fireEvent.click(button('Use the saved one'));
  expect(send).toHaveBeenLastCalledWith('reload');
  fireEvent.click(button('Keep mine'));
  expect(send).toHaveBeenLastCalledWith('keep', { fields, fieldsEpoch: 0 });
});

test('each tick takes its picture, and a window capture names only its window', () => {
  setData({ captureTargets: [{ id: 'tgui_2', title: 'Machine controls' }] });
  openAt(2);
  fireEvent.click(screen.getByRole('checkbox', { name: /In-game capture/ }));
  expect(send).toHaveBeenLastCalledWith('capture_view', {
    fields,
    fieldsEpoch: 0,
  });
  fireEvent.click(screen.getByRole('checkbox', { name: /Machine controls/ }));
  expect(send).toHaveBeenLastCalledWith('capture_ui', {
    windowId: 'tgui_2',
    fields,
    fieldsEpoch: 0,
  });
  fireEvent.click(
    screen.getByRole('checkbox', { name: /Your own screenshot/ }),
  );
  expect(send).toHaveBeenLastCalledWith('screenshot', {
    fields,
    fieldsEpoch: 0,
  });
  fireEvent.focus(window);
  expect(send).toHaveBeenLastCalledWith('targets');
  fireEvent.click(button('Look again'));
  expect(send).toHaveBeenLastCalledWith('targets');
});

test('at the most pictures a report takes, the free ticks take nothing', () => {
  setData({
    pictures: [
      picture,
      { ...picture, id: 2, source: 'file' },
      { ...picture, id: 3, source: 'window', title: 'Machine controls' },
    ],
    captureTargets: [{ id: 'tgui_4', title: 'Crafting' }],
  });
  openAt(2);
  send.mockClear();
  fireEvent.click(screen.getByRole('checkbox', { name: /Crafting/ }));
  expect(formActions()).toEqual([]);
  expect(hasText(/That's 3 pictures, the most a report takes/)).toBe(true);
});

test('a ready picture asks for its preview once a take, and goes public only once seen', () => {
  setData({ pictures: [picture] });
  const view = openAt(2);
  const previews = () =>
    send.mock.calls.filter(([action]) => action === 'preview');
  expect(previews()).toEqual([['preview', { pictureId: 1 }]]);
  const share = screen.getByRole('checkbox', {
    name: /Show it on the public GitHub issue/,
  });
  expect(share.getAttribute('aria-disabled')).toBe('true');
  fireEvent.click(share);
  expect(
    send.mock.calls.some(([action]) => action === 'screenshot_consent'),
  ).toBe(false);
  setData({ preview: { id: 1, take: 1, src: 'data:image/png;base64,AAAA' } });
  fireEvent.load(screen.getByAltText('In-game capture of your view'));
  expect(send).toHaveBeenLastCalledWith('preview_loaded', {
    pictureId: 1,
    take: 1,
  });
  setData({ pictures: [{ ...picture, previewSeen: true }] });
  view.rerender(<BugReport />);
  fireEvent.click(
    screen.getByRole('checkbox', {
      name: /Show it on the public GitHub issue/,
    }),
  );
  expect(send).toHaveBeenLastCalledWith('screenshot_consent', {
    pictureId: 1,
    publicConsent: true,
  });
  setData({ pictures: [{ ...picture, take: 2 }] });
  expect(previews().length).toBe(2);
  fireEvent.click(button(/^Remove In-game capture/));
  expect(send).toHaveBeenLastCalledWith('remove_screenshot', { pictureId: 1 });
});

test('a picture on the way holds sending and says why', () => {
  setData({ pictures: [{ ...picture, state: 'processing' }] });
  openAt(4);
  expect(hasText('Wait for the picture to finish, or remove it.')).toBe(true);
  expect(hasButton('Send report')).toBe(false);
});
