// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
  spyOn,
} from 'bun:test';
import { act, fireEvent, render, screen, within } from '@testing-library/react';

import * as actions from '../events/act';
import { gameDataAtom, gameStaticDataAtom, store } from '../events/store';
import { CrayonGraffitiTab } from './CrayonGraffitiTab';

// One colour over the whole tile, as library.dm's thumbs are flattened art.
const art = (w = 32) => ({
  w,
  pal: '#ff0000ff',
  grid: `g1${'f1'.repeat((w * 32 - 4) / 15)}41`,
  glow: `g1${'f0'.repeat((w * 32 - 4) / 15)}40`,
});

const entry = (
  id: string,
  name: string,
  description: string,
  created: string,
  width = 32,
) => ({
  id,
  name,
  description,
  width,
  created,
  updated: created,
  glow: false,
  layers: 1,
  thumb: art(width),
});

// The spray can's static data, names and descriptions HTML-escaped as library.dm sends them.
const library = (unfinished: unknown) => ({
  entries: [
    entry('g2', 'Harbour tag', 'Gulls over the water', '1760000200'),
    entry('g1', 'Crane', 'By the dock &amp; the cranes', '1760000100', 64),
  ],
  unfinished,
  count: 2,
  cap: 50,
  defaultPalette: [],
});

const stoppedJob = {
  ...entry('', 'Half done', '', '1760000300'),
  id: null,
  resume: {
    map: 'Box Station',
    anchor: null,
    pid: 'p1',
    progress: 3,
    width: 32,
  },
  progress: 3,
  revealed: art(),
};

let sendAct: ReturnType<typeof spyOn<typeof actions, 'sendAct'>>;
let previousData: Record<string, unknown>;
let previousStaticData: Record<string, unknown>;

const open = (unfinished: unknown = null) => {
  store.set(gameDataAtom, {
    graffiti: { armed: null, armedName: null, tab: 'graffiti', hasEditor: 0 },
  });
  store.set(gameStaticDataAtom, { graffitiLibrary: library(unfinished) });
  return render(<CrayonGraffitiTab />);
};

const rows = () =>
  within(screen.getByRole('list', { name: 'Custom Graffiti' })).getAllByRole(
    'listitem',
  );

beforeEach(() => {
  previousData = store.get(gameDataAtom);
  previousStaticData = store.get(gameStaticDataAtom);
  sendAct = spyOn(actions, 'sendAct').mockImplementation(() => undefined);
});

afterEach(() => {
  jest.useRealTimers();
  sendAct.mockRestore();
  store.set(gameDataAtom, previousData);
  store.set(gameStaticDataAtom, previousStaticData);
});

describe('CrayonGraffitiTab', () => {
  it('pins the Unfinished slot above the saved pieces', () => {
    open(stoppedJob);
    const slot = screen.getByRole('group', { name: 'Unfinished' });
    expect(within(slot).getByText('Half done')).toBeTruthy();
    const list = screen.getByRole('list', { name: 'Custom Graffiti' });
    expect(
      slot.compareDocumentPosition(list) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
  });

  it('searches the decoded descriptions too', () => {
    open();
    expect(screen.queryByRole('group', { name: 'Unfinished' })).toBeNull();
    expect(rows()).toHaveLength(2);
    // The search box is the tab's one text box while no rename is open.
    fireEvent.change(screen.getByRole('textbox'), {
      target: { value: 'DOCK & the' },
    });
    expect(rows()).toHaveLength(1);
    expect(within(rows()[0]).getByText('Crane')).toBeTruthy();
  });

  it('arms the can with the piece Paint is pressed on', () => {
    open();
    const crane = rows().find((row) => within(row).queryByText('Crane'))!;
    fireEvent.click(within(crane).getByText('Paint'));
    expect(sendAct).toHaveBeenCalledWith('graffitiArm', { id: 'g1' });
  });

  it('shows a rename as it is sent, and puts its text back in the form when the library never takes it', () => {
    jest.useFakeTimers();
    const { rerender } = open();
    // Newest first: the crane is the second row.
    const crane = () => rows()[1];
    const rename = (from: string, to: string) => {
      fireEvent.click(within(crane()).getByText(from));
      const name = within(crane()).getByPlaceholderText('Untitled');
      fireEvent.change(name, { target: { value: to } });
      fireEvent.keyDown(name, { key: 'Enter' });
    };
    rename('Crane', 'Gantry');
    expect(sendAct).toHaveBeenLastCalledWith('graffitiRename', {
      id: 'g1',
      name: 'Gantry',
      description: 'By the dock & the cranes',
    });
    expect(within(crane()).getByText('Gantry')).toBeTruthy();
    const renamed = library(null);
    renamed.entries[1].name = 'Gantry';
    // The window draws each update afresh, as useBackend() doesn't subscribe.
    store.set(gameStaticDataAtom, { graffitiLibrary: renamed });
    rerender(<CrayonGraffitiTab />);
    act(() => jest.advanceTimersByTime(2000));
    expect(within(crane()).queryByPlaceholderText('Untitled')).toBeNull();
    // Refused, as the library's write pacing does, with a balloon and no update.
    rename('Gantry', 'Jib');
    expect(within(crane()).getByText('Jib')).toBeTruthy();
    act(() => jest.advanceTimersByTime(2000));
    expect(
      (within(crane()).getByPlaceholderText('Untitled') as HTMLInputElement)
        .value,
    ).toBe('Jib');
  });
});
