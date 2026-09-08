// THIS IS AN APHELION UI FILE
import { beforeEach, describe, expect, it, mock } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';

import { gameDataAtom, store } from '../events/store';
import { Window } from '../layouts';

const sendAct = mock(() => {});
mock.module('../events/act', () => ({ sendAct }));
const TestWindow = Window;
mock.module('../layouts/Window', () => ({ Window: TestWindow }));
const { PersistentEconomyAdmin } = await import('./PersistentEconomyAdmin');
const { PersistentSavings } = await import('./PersistentSavings');

const settings = {
  enabled: 1,
  round_cap: 2000,
  deposit_fee: 10,
  balance_cap: 100000,
  levy_threshold: 20000,
  levy_rate: 1,
};
const account = {
  id: 'character-one',
  owner: 'testplayer',
  name: 'Test Character',
  regular: 900,
  offshore: 100,
  frozen: false,
  remaining: 1000,
  history: [],
};

function setData(overrides = {}) {
  store.set(gameDataAtom, {
    settings,
    accounts: [account],
    active_id: account.id,
    available: 500,
    remaining: 1000,
    storage_error: null,
    regular_total: 900,
    offshore_total: 100,
    audit: [],
    department_audit: [],
    round_accounts: [],
    departments: [],
    holder: 'Elena Ward',
    number: '123456',
    balance: 1250,
    cleared: 900,
    offshore: 100,
    shift_credit: 350,
    debt: 0,
    restricted: false,
    unavailable: false,
    activity: [],
    offshore_activity: [],
    ...overrides,
  });
}

beforeEach(() => {
  sendAct.mockClear();
  setData();
});

describe('Persistent savings controls', () => {
  it('uses bank language and exposes no manual deposit or development information', () => {
    const { container } = render(<PersistentSavings />);
    expect(screen.getByText('1250 cr')).toBeDefined();
    expect(screen.getByText('900 cr')).toBeDefined();
    expect(screen.getByText('Elena Ward')).toBeDefined();
    expect(container.textContent).not.toMatch(
      /planned|black market|character|ckey|round|persistent|future/i,
    );
    expect(screen.queryByText(/Deposit/)).toBeNull();
    fireEvent.click(screen.getByText('Terms and charges'));
    expect(container.textContent).not.toMatch(
      /planned|black market|character|ckey|round earnings|persistent|future/i,
    );
    expect(screen.getByText(/Settlement fee/)).toBeDefined();
    expect(sendAct).not.toHaveBeenCalled();
  });

  it('confirms an offshore transfer without submitting an account identity', () => {
    render(<PersistentSavings />);
    fireEvent.click(screen.getAllByText('Offshore account').at(-1)!);
    fireEvent.click(screen.getByText('Transfer 100 cr'));
    expect(sendAct).not.toHaveBeenCalled();
    fireEvent.click(screen.getByText('Confirm?'));
    expect(sendAct).toHaveBeenCalledWith('convert', { amount: 100 });
  });

  it('blocks offshore transfers while the account is restricted', () => {
    setData({ restricted: true });
    render(<PersistentSavings />);
    fireEvent.click(screen.getAllByText('Offshore account').at(-1)!);
    fireEvent.click(screen.getByText('Transfer 100 cr'));
    expect(screen.queryByText('Confirm?')).toBeNull();
    expect(sendAct).not.toHaveBeenCalled();
  });

  it('does not display other characters when the current account cannot be verified', () => {
    setData({ holder: null });
    render(<PersistentSavings />);
    expect(
      screen.getByText(/could not verify an active account/),
    ).toBeDefined();
    expect(screen.queryByText('Test Character')).toBeNull();
    expect(screen.queryByText('Transfer 100 cr')).toBeNull();
  });

  it('uses a bank service notice instead of exposing storage errors', () => {
    setData({
      unavailable: true,
      storage_error: 'JSON disk failure; ask an administrator to restart',
    });
    render(<PersistentSavings />);
    expect(
      screen.getByText(/Banking services are temporarily unavailable/),
    ).toBeDefined();
    expect(screen.queryByText(/JSON/)).toBeNull();
    fireEvent.click(screen.getAllByText('Offshore account').at(-1)!);
    fireEvent.click(screen.getByText('Transfer 100 cr'));
    expect(screen.queryByText('Confirm?')).toBeNull();
    expect(sendAct).not.toHaveBeenCalled();
  });

  it('requires an administrative reason before adjusting balances', () => {
    render(<PersistentEconomyAdmin />);
    fireEvent.click(screen.getByText('testplayer / Test Character'));
    fireEvent.click(screen.getByText('Adjust balance'));
    expect(screen.queryByText('Confirm?')).toBeNull();
    expect(sendAct).not.toHaveBeenCalled();
  });

  it('keeps the admin panel usable with the legacy corrupted audit payload', () => {
    setData({ audit: { '/list': null } });
    render(<PersistentEconomyAdmin />);
    fireEvent.click(screen.getByText('Admin audit'));
    expect(
      screen.getByText(/Some saved audit records are unreadable/),
    ).toBeDefined();
    expect(screen.getByText('No administrative changes yet.')).toBeDefined();
  });

  it('renders every saved policy audit record after multiple updates', () => {
    setData({
      audit: [
        {
          time: '2026-09-08 12:00:01',
          actor: 'testadmin',
          action: 'Second policy save',
          reason: 'Second reason',
        },
        {
          time: '2026-09-08 12:00:00',
          actor: 'testadmin',
          action: 'First policy save',
          reason: 'First reason',
        },
      ],
    });
    render(<PersistentEconomyAdmin />);
    fireEvent.click(screen.getByText('Admin audit'));
    expect(screen.getByText(/Second policy save/)).toBeDefined();
    expect(screen.getByText(/First policy save/)).toBeDefined();
  });

  it('renders a selected round account with net transaction amounts and debt withholding', () => {
    setData({
      round_accounts: [
        {
          id: '123456',
          name: 'Test Character',
          owner: 'testplayer',
          character_id: account.id,
          balance: 490,
          debt: 0,
          history: [
            {
              time: '00:10:00',
              amount: 90,
              balance: 490,
              reason: 'Salary with debt',
              debt_collected: 10,
            },
          ],
        },
      ],
    });
    render(<PersistentEconomyAdmin />);
    fireEvent.click(screen.getByText('Round accounts'));
    fireEvent.click(screen.getByText('Test Character (123456)'));
    expect(screen.getByText('Salary with debt')).toBeDefined();
    expect(screen.getByText('Debt withheld: 10')).toBeDefined();
    expect(screen.getByText('+90')).toBeDefined();
  });

  it('requires a reason and confirmation to change the selected department budget', () => {
    setData({
      departments: [
        {
          id: 'ENG',
          name: 'Engineering Budget',
          owner: null,
          character_id: null,
          balance: 1000,
          debt: 0,
          history: [],
        },
      ],
    });
    render(<PersistentEconomyAdmin />);
    fireEvent.click(screen.getByText('Departments'));
    fireEvent.click(screen.getByText('Engineering Budget (ENG)'));
    fireEvent.click(screen.getByText('Apply budget adjustment'));
    expect(screen.queryByText('Confirm?')).toBeNull();
    fireEvent.change(
      screen.getByPlaceholderText(
        'Required reason for any administrative change',
      ),
      { target: { value: 'Repair budget' } },
    );
    fireEvent.click(screen.getByText('Apply budget adjustment'));
    expect(sendAct).not.toHaveBeenCalled();
    fireEvent.click(screen.getByText('Confirm?'));
    expect(sendAct).toHaveBeenCalledWith('adjust_department', {
      id: 'ENG',
      amount: 100,
      reason: 'Repair budget',
    });
  });

  it('does not crash when the legacy character history has the same corrupted shape', () => {
    setData({ accounts: [{ ...account, history: { '/list': null } }] });
    render(<PersistentEconomyAdmin />);
    fireEvent.click(screen.getByText('testplayer / Test Character'));
    expect(
      screen.getByText(/Older history records require recovery/),
    ).toBeDefined();
    expect(screen.getByText('900')).toBeDefined();
  });

  it('provides the PDA exit control', () => {
    setData({ PC_showexitprogram: 1 });
    const { container } = render(<PersistentSavings />);
    const close = container
      .querySelector('.NtosHeader .fa-window-close')
      ?.closest('.Button');
    expect(close).toBeDefined();
    fireEvent.click(close!);
    expect(sendAct).toHaveBeenCalledWith('PC_exit');
  });

  it('requires a reason, exact reset phrase, and final confirmation before resetting savings', () => {
    render(<PersistentEconomyAdmin />);
    const reset = screen.getByText("Reset everyone's savings");
    fireEvent.click(reset);
    expect(screen.queryByText('Confirm reset for everyone?')).toBeNull();
    fireEvent.change(
      screen.getByPlaceholderText('Type RESET ECONOMY to confirm'),
      {
        target: { value: 'RESET ECONOMY' },
      },
    );
    fireEvent.click(reset);
    expect(screen.queryByText('Confirm reset for everyone?')).toBeNull();
    fireEvent.change(
      screen.getByPlaceholderText(
        'Required reason for any administrative change',
      ),
      {
        target: { value: 'Start a new economy season' },
      },
    );
    fireEvent.change(
      screen.getByPlaceholderText('Type RESET ECONOMY to confirm'),
      {
        target: { value: 'RESET' },
      },
    );
    fireEvent.click(reset);
    expect(screen.queryByText('Confirm reset for everyone?')).toBeNull();
    fireEvent.change(
      screen.getByPlaceholderText('Type RESET ECONOMY to confirm'),
      {
        target: { value: 'RESET ECONOMY' },
      },
    );
    fireEvent.click(reset);
    expect(sendAct).not.toHaveBeenCalled();
    fireEvent.click(screen.getByText('Confirm reset for everyone?'));
    expect(sendAct).toHaveBeenCalledWith('reset', {
      reason: 'Start a new economy season',
      confirmation: 'RESET ECONOMY',
    });
    expect(
      (
        screen.getByPlaceholderText(
          'Type RESET ECONOMY to confirm',
        ) as HTMLInputElement
      ).value,
    ).toBe('');
  });
});
