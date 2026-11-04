// THIS IS AN APHELION UI FILE
import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';

import * as actions from '../events/act';
import { gameDataAtom, store } from '../events/store';
import { GraffitiAdminPanel } from './GraffitiAdminPanel';

// One colour over the whole tile, as the registry keeps one-tile art.
const art = {
  w: 32,
  pal: '#ff0000ff',
  grid: `g1${'f1'.repeat(68)}41`,
  glow: `g1${'f0'.repeat(68)}40`,
};

// A row as SSgraffiti.admin_rows() sends it, the character name HTML-escaped.
const row = (pid: string, ckey: string, who: string) => ({
  pid,
  ckey,
  who,
  area: '/area/station/hallway/primary/central',
  x: 100,
  y: 120,
  z: 2,
  at: '1760000100',
  state: 'shown',
  art,
});

let sendAct: ReturnType<typeof spyOn<typeof actions, 'sendAct'>>;
let previousData: Record<string, unknown>;

const open = () => {
  store.set(gameDataAtom, {
    rows: [
      row('alice-1760000200-1234', 'alice', 'Alice Doe'),
      row('bob-1760000100-5678', 'bob', '&lt;b&gt;Bob&lt;/b&gt;'),
    ],
    total: 2,
    search: '',
    sort: 'date',
    page: 1,
    pageSize: 24,
    mapName: 'Box Station',
  });
  return render(<GraffitiAdminPanel />);
};

beforeEach(() => {
  previousData = store.get(gameDataAtom);
  sendAct = spyOn(actions, 'sendAct').mockImplementation(() => undefined);
});

afterEach(() => {
  sendAct.mockRestore();
  store.set(gameDataAtom, previousData);
});

describe('GraffitiAdminPanel', () => {
  it('lists a row per placement', () => {
    open();
    expect(screen.getByText('Alice Doe')).toBeTruthy();
    expect(screen.getByText('alice')).toBeTruthy();
    expect(screen.getAllByRole('checkbox')).toHaveLength(2);
  });

  it('deletes the checked rows', () => {
    open();
    fireEvent.click(screen.getByText('Delete selected'));
    expect(sendAct).not.toHaveBeenCalled();
    fireEvent.click(
      screen.getByRole('checkbox', { name: 'Select graffiti by <b>Bob</b>' }),
    );
    fireEvent.click(screen.getByText('Delete selected'));
    expect(sendAct).toHaveBeenCalledWith('delete', {
      pids: ['bob-1760000100-5678'],
    });
  });

  it('shows an escaped character name as text', () => {
    const { container } = open();
    expect(screen.getByText('<b>Bob</b>')).toBeTruthy();
    expect(container.querySelector('b')).toBeNull();
  });
});
