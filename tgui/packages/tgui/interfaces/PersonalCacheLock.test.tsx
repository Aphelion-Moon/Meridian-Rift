import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';

import * as actions from '../events/act';
import { gameDataAtom, store } from '../events/store';
import { PersonalCacheLock } from './PersonalCacheLock';

const sendAct = spyOn(actions, 'sendAct');
afterEach(() => sendAct.mockClear());

const planning = {
  grid: Array.from({ length: 36 }, (_, index) => ({
    index: index + 1,
    symbol: '1C',
    available: index < 6,
    used: false,
  })),
  grid_size: 6,
  targets: [
    ['1C', '55', '7A', 'BD'],
    ['7A', 'BD', 'E9', 'FF'],
  ],
  completed: [false, false],
  buffer: [],
  buffer_limit: 8,
  select_row: true,
  started: false,
  seconds_left: 75,
  can_stabilize: false,
  recovery_seconds: 15,
  self_test: false,
  revision: 0,
};

describe('Personal cache lock', () => {
  it('submits only available cells with the current server revision', () => {
    store.set(gameDataAtom, planning);
    render(<PersonalCacheLock />);

    fireEvent.click(screen.getByLabelText('Pulse 1C, row 2, column 1'));
    fireEvent.click(screen.getByText('Stabilize: +15s'));
    expect(sendAct).not.toHaveBeenCalled();

    fireEvent.click(screen.getByLabelText('Pulse 1C, row 1, column 3'));
    expect(sendAct).toHaveBeenCalledWith('pulse', { cell: 3, revision: 0 });
    expect(screen.getByText('Timer starts on first pulse.')).toBeDefined();
  });

  it('keeps uploaded signatures visible and sends recovery against the active revision', () => {
    store.set(gameDataAtom, {
      ...planning,
      buffer: ['1C', '55', '7A', 'BD'],
      completed: [true, false],
      started: true,
      can_stabilize: true,
      revision: 4,
      self_test: true,
    });
    render(<PersonalCacheLock />);

    expect(screen.getByText('Signature 1: uploaded')).toBeDefined();
    expect(screen.getByText('Signature 2: pending')).toBeDefined();
    expect(screen.queryByText(/causes a 30s lockout/)).toBeNull();
    fireEvent.click(screen.getByText('Stabilize: +15s'));
    expect(sendAct).toHaveBeenCalledWith('stabilize', { revision: 4 });
  });
});
