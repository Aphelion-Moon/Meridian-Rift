// THIS IS AN APHELION UI FILE
import { useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Table,
  Tabs,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type RoundAccount,
  RoundAccountHistory,
  RoundAccounts,
} from './PersistentEconomy/RoundAccounts';
import {
  type SavingsAccount,
  SavingsHistory,
  type SavingsSettings,
} from './PersistentSavings';

type AdminData = {
  settings: SavingsSettings;
  accounts: SavingsAccount[];
  regular_total: number;
  offshore_total: number;
  storage_error: string | null;
  history_recovery_notice?: string;
  round_accounts: RoundAccount[];
  departments: RoundAccount[];
  department_audit: AdminData['audit'];
  audit: { time: string; actor: string; action: string; reason: string }[];
};

const policyFields = [
  ['round_cap', 'Gross round settlement cap', 1000000],
  ['deposit_fee', 'Settlement fee (%)', 100],
  ['balance_cap', 'Savings ceiling per ckey', 1000000],
  ['levy_threshold', 'Wealth levy exemption', 1000000],
  ['levy_rate', 'Active-round levy (%)', 100],
] as const;

export function PersistentEconomyAdmin() {
  const { act, data } = useBackend<AdminData>();
  const [search, setSearch] = useState('');
  const [selectedKey, setSelectedKey] = useState('');
  const [currency, setCurrency] = useState('regular');
  const [amount, setAmount] = useState(100);
  const [reason, setReason] = useState('');
  const [draft, setDraft] = useState<SavingsSettings | null>(null);
  const [tab, setTab] = useState('savings');
  const [resetConfirmation, setResetConfirmation] = useState('');
  const audit = [
    ...(Array.isArray(data.audit) ? data.audit : []),
    ...(Array.isArray(data.department_audit) ? data.department_audit : []),
  ].sort((a, b) => b.time.localeCompare(a.time));
  const roundAccounts = data.round_accounts || [];
  const settings = draft || data.settings;
  const selected = data.accounts.find(
    (account) => `${account.owner}/${account.id}` === selectedKey,
  );
  const matches = data.accounts.filter((account) =>
    `${account.owner} ${account.name}`
      .toLowerCase()
      .includes(search.toLowerCase()),
  );
  const disabled = !reason.trim() || !!data.storage_error;
  const accountAction = (action: string) =>
    act(action, {
      owner: selected?.owner,
      id: selected?.id,
      currency,
      amount,
      reason,
    });

  return (
    <Window title="Manage Persistent Economy" width={900} height={800}>
      <Window.Content scrollable>
        {data.storage_error && (
          <NoticeBox danger>{data.storage_error}</NoticeBox>
        )}
        {data.history_recovery_notice && (
          <NoticeBox>{data.history_recovery_notice}</NoticeBox>
        )}
        {!Array.isArray(data.audit) && (
          <NoticeBox>
            Some saved audit records are unreadable. Restart with the
            history-recovery update to repair them.
          </NoticeBox>
        )}
        <Section title="Economy overview">
          <Box>
            {data.accounts.length} character accounts · Current (cleared):{' '}
            {data.regular_total} · Offshore: {data.offshore_total} · Total:{' '}
            {data.regular_total + data.offshore_total}
          </Box>
          <Input
            fluid
            mt={1}
            placeholder="Required reason for any administrative change"
            value={reason}
            onChange={setReason}
          />
        </Section>
        <Tabs>
          {[
            ['savings', 'Savings and policy'],
            ['round', 'Round accounts'],
            ['departments', 'Departments'],
            ['audit', 'Admin audit'],
          ].map(([key, label]) => (
            <Tabs.Tab
              key={key}
              selected={tab === key}
              onClick={() => setTab(key)}
            >
              {label}
            </Tabs.Tab>
          ))}
        </Tabs>
        {tab === 'savings' && (
          <>
            <Section title="Monetary policy">
              <LabeledList>
                <LabeledList.Item label="Transactions">
                  <Button.Checkbox
                    checked={!!settings.enabled}
                    onClick={() =>
                      setDraft({ ...settings, enabled: !settings.enabled })
                    }
                  >
                    {settings.enabled ? 'Enabled' : 'Paused'}
                  </Button.Checkbox>
                </LabeledList.Item>
                {policyFields.map(([key, label, maximum]) => (
                  <LabeledList.Item key={key} label={label}>
                    <NumberInput
                      value={settings[key]}
                      minValue={0}
                      maxValue={maximum}
                      step={1}
                      onChange={(value) =>
                        setDraft({ ...settings, [key]: value })
                      }
                    />
                  </LabeledList.Item>
                ))}
              </LabeledList>
              <Box my={1} color="label">
                Earning and wealth limits combine all characters and both
                currencies for each ckey. Zero caps stop settlement; excess
                income remains shift credit. Lowering the savings ceiling does
                not confiscate existing funds. Admin adjustments bypass earning
                limits, freezes, and the economy pause, and are audited.
              </Box>
              <Button.Confirm
                disabled={disabled || !draft}
                onClick={() => {
                  act('settings', {
                    settings: {
                      ...settings,
                      enabled: Number(settings.enabled),
                    },
                    reason,
                  });
                  setDraft(null);
                }}
              >
                Save policy
              </Button.Confirm>
              <Button onClick={() => setDraft(null)} disabled={!draft}>
                Discard edits
              </Button>
            </Section>
            <Section title="Reset persistent economy">
              <NoticeBox danger>
                Clears everyone's regular and offshore savings, transaction
                histories, purchase receipts, freezes, and round earning
                counters. Policy settings and the admin audit are retained.
                Cleared funds are removed from active payroll accounts. Shift
                credit and department budgets are retained.
              </NoticeBox>
              <Input
                fluid
                placeholder="Type RESET ECONOMY to confirm"
                value={resetConfirmation}
                onChange={setResetConfirmation}
              />
              <Button.Confirm
                mt={1}
                color="bad"
                icon="trash"
                confirmContent="Confirm reset for everyone?"
                disabled={disabled || resetConfirmation !== 'RESET ECONOMY'}
                onClick={() => {
                  act('reset', { reason, confirmation: resetConfirmation });
                  setResetConfirmation('');
                }}
              >
                Reset everyone's savings
              </Button.Confirm>
            </Section>
            <Section title="Character accounts">
              <Input
                fluid
                placeholder="Search by ckey or character name"
                value={search}
                onChange={setSearch}
              />
              <Table mt={1}>
                <Table.Row header>
                  <Table.Cell>Owner / character</Table.Cell>
                  <Table.Cell>Current (cleared)</Table.Cell>
                  <Table.Cell>Offshore</Table.Cell>
                  <Table.Cell>Round allowance left</Table.Cell>
                </Table.Row>
                {matches.map((account) => (
                  <Table.Row key={`${account.owner}/${account.id}`}>
                    <Table.Cell>
                      <Button
                        selected={selected === account}
                        onClick={() =>
                          setSelectedKey(`${account.owner}/${account.id}`)
                        }
                      >
                        {account.owner} / {account.name}
                        {account.frozen ? ' (frozen)' : ''}
                      </Button>
                    </Table.Cell>
                    <Table.Cell>{account.regular}</Table.Cell>
                    <Table.Cell>{account.offshore}</Table.Cell>
                    <Table.Cell>{account.remaining}</Table.Cell>
                  </Table.Row>
                ))}
              </Table>
              {!matches.length && <Box>No matching accounts.</Box>}
            </Section>
            {selected && (
              <>
                <Section title={`${selected.owner} / ${selected.name}`}>
                  <Dropdown
                    options={['regular', 'offshore']}
                    selected={currency}
                    onSelected={setCurrency}
                  />
                  <NumberInput
                    ml={1}
                    value={amount}
                    minValue={-1000000}
                    maxValue={1000000}
                    step={1}
                    onChange={setAmount}
                  />
                  <Button.Confirm
                    ml={1}
                    disabled={disabled || !amount}
                    onClick={() => accountAction('adjust')}
                  >
                    Adjust balance
                  </Button.Confirm>
                  <Button.Confirm
                    disabled={disabled}
                    color={selected.frozen ? 'good' : 'bad'}
                    onClick={() => accountAction('freeze')}
                  >
                    {selected.frozen ? 'Unfreeze' : 'Freeze'} account
                  </Button.Confirm>
                </Section>
                <SavingsHistory account={selected} />
                {roundAccounts
                  .filter(
                    (bank) =>
                      bank.owner === selected.owner &&
                      bank.character_id === selected.id,
                  )
                  .map((bank) => (
                    <RoundAccountHistory key={bank.id} account={bank} />
                  ))}
              </>
            )}
          </>
        )}
        {tab === 'round' && (
          <RoundAccounts key="round" accounts={roundAccounts} reason={reason} />
        )}
        {tab === 'departments' && (
          <RoundAccounts
            key="departments"
            accounts={data.departments || []}
            departments
            reason={reason}
          />
        )}
        {tab === 'audit' && (
          <Section title="Administrative audit">
            {audit.map((entry, index) => (
              <Box key={`${entry.time}-${index}`} mb={1}>
                <Box color="label">
                  {entry.time} · {entry.actor}
                </Box>
                {entry.action}. Reason: {entry.reason}
              </Box>
            ))}
            {!audit.length && <Box>No administrative changes yet.</Box>}
          </Section>
        )}
      </Window.Content>
    </Window>
  );
}
