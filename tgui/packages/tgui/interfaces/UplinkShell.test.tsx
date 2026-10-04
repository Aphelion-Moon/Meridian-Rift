import { describe, expect, it, spyOn } from 'bun:test';
import { act, fireEvent, render, screen } from '@testing-library/react';
import * as backendActions from '../events/act';
import { gameDataAtom, store } from '../events/store';
import { UplinkShell } from './UplinkShell';

const baseData = {
  loadout: 'issued',
  includeLoadout: true,
  initial: false,
  pending: false,
  replacementStarted: false,
  replacementDelay: 300,
  remaining: 0,
  hasBody: true,
  controllingShell: false,
  control: 'AI core',
  body: 'Personal shell — AI satellite',
  core: 'AI core — integrity 100/100',
};

function show(data: Record<string, unknown>) {
  store.set(gameDataAtom, { ...baseData, ...data });
  act(() => render(<UplinkShell />));
}

describe('Uplink issuance and replacement', () => {
  it('keeps first delivery unavailable until a body preview exists', () => {
    show({ initial: true, hasBody: false });
    expect(screen.getByText('Create body preview')).toBeDefined();
    expect(screen.queryByText('Confirm preview and deliver')).toBeNull();
    expect(screen.queryByText('Retire and replace shell')).toBeNull();
  });

  it('keeps the retained deadline visible after replacement cancellation', () => {
    show({ hasBody: false, replacementStarted: true, remaining: 142 });
    expect(screen.getByText(/142 seconds/)).toBeDefined();
    expect(screen.getByText('Resume replacement request')).toBeDefined();
    expect(screen.queryByText('Retire and replace shell')).toBeNull();
  });

  it('delivers a reviewed preview with one explicit confirmation', () => {
    const sendAct = spyOn(backendActions, 'sendAct');
    try {
      show({ initial: true, hasBody: false, preview: 'preview-image' });
      fireEvent.click(screen.getByText('Confirm preview and deliver'));
      expect(sendAct).toHaveBeenCalledWith('issue');
    } finally {
      sendAct.mockRestore();
    }
  });

  it('offers return while a shell is controlled instead of a dead-end connect action', () => {
    show({ controllingShell: true, control: 'Personal shell' });
    expect(screen.getByText('Return to AI view')).toBeDefined();
    expect(screen.queryByText('Connect to personal shell')).toBeNull();
  });

  it('does not claim a destroyed shell has completed a wait that was never started', () => {
    show({ hasBody: false });
    expect(screen.getByText('Schedule replacement')).toBeDefined();
    expect(screen.queryByText('Replacement wait complete.')).toBeNull();
  });
});
