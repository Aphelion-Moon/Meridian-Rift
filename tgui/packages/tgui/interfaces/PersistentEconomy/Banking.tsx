// THIS IS AN APHELION UI FILE
import { useState } from 'react';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
  Table,
  Tabs,
} from 'tgui-core/components';
import { useBackend } from '../../backend';
import { NtosWindow } from '../../layouts/NtosWindow';
import type { SavingsSettings } from '../PersistentSavings';

type Entry = { time: string; amount: number; description: string };
type BankingData = {
  holder: string | null;
  number: string;
  balance: number;
  cleared: number;
  offshore: number;
  shift_credit: number;
  debt: number;
  restricted: boolean;
  unavailable: boolean;
  settings: SavingsSettings;
  remaining: number;
  activity: Entry[];
  offshore_activity: Entry[];
};

function Statement(props: { entries: Entry[] }) {
  const entries = Array.isArray(props.entries) ? props.entries : [];
  return (
    <Section title="Account activity">
      <Table>
        <Table.Row header>
          <Table.Cell>Date</Table.Cell>
          <Table.Cell>Description</Table.Cell>
          <Table.Cell textAlign="right">Credits</Table.Cell>
        </Table.Row>
        {entries.map((entry, index) => (
          <Table.Row key={`${entry.time}-${index}`}>
            <Table.Cell color="label">{entry.time}</Table.Cell>
            <Table.Cell>{entry.description}</Table.Cell>
            <Table.Cell
              textAlign="right"
              color={entry.amount < 0 ? 'bad' : 'good'}
            >
              {entry.amount > 0 ? '+' : ''}
              {entry.amount}
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
      {!entries.length && (
        <Box mt={1} color="label">
          No transactions to display.
        </Box>
      )}
    </Section>
  );
}

export function Banking() {
  const { act, data } = useBackend<BankingData>();
  const [tab, setTab] = useState('current');
  const [amount, setAmount] = useState(100);
  if (!data.holder) {
    return (
      <NtosWindow title="NT Banking" width={650} height={700}>
        <NtosWindow.Content>
          <Section title="NT Banking">
            <NoticeBox>
              We could not verify an active account. Please contact your payroll
              office for assistance.
            </NoticeBox>
          </Section>
        </NtosWindow.Content>
      </NtosWindow>
    );
  }
  const blocked = data.unavailable || data.restricted || !data.settings.enabled;
  return (
    <NtosWindow title="NT Banking" width={650} height={740}>
      <NtosWindow.Content scrollable>
        <Section title="NT Banking">
          <Box fontSize={1.3} bold>
            {data.holder}
          </Box>
          <Box color="label">Personal banking · Account {data.number}</Box>
        </Section>
        {data.unavailable && (
          <NoticeBox danger>
            Banking services are temporarily unavailable. Please try again
            later.
          </NoticeBox>
        )}
        {data.restricted && (
          <NoticeBox danger>
            This account is restricted. Cleared funds and offshore transfers are
            unavailable.
          </NoticeBox>
        )}
        {!data.settings.enabled && (
          <NoticeBox>
            Settlement services are temporarily suspended. Shift credit remains
            available for local purchases.
          </NoticeBox>
        )}
        <Stack mb={1}>
          <Stack.Item grow>
            <Section title="Current account" fill>
              <Box fontSize={2} bold>
                {data.balance} cr
              </Box>
              <Box color="label">
                Available balance · Payroll and card payments
              </Box>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section title="Offshore account" fill>
              <Box fontSize={2} bold>
                {data.offshore} cr
              </Box>
              <Box color="label">Cleared balance</Box>
            </Section>
          </Stack.Item>
        </Stack>
        <Tabs>
          <Tabs.Tab
            selected={tab === 'current'}
            onClick={() => setTab('current')}
          >
            Current account
          </Tabs.Tab>
          <Tabs.Tab
            selected={tab === 'offshore'}
            onClick={() => setTab('offshore')}
          >
            Offshore account
          </Tabs.Tab>
          <Tabs.Tab selected={tab === 'terms'} onClick={() => setTab('terms')}>
            Terms and charges
          </Tabs.Tab>
        </Tabs>
        {tab === 'current' && (
          <>
            <Section title="Balance details">
              <LabeledList>
                <LabeledList.Item label="Cleared funds">
                  {data.cleared} cr
                </LabeledList.Item>
                <LabeledList.Item label="Shift credit">
                  {data.shift_credit} cr
                </LabeledList.Item>
                <LabeledList.Item label="Outstanding debt">
                  {data.debt} cr
                </LabeledList.Item>
                <LabeledList.Item label="Settlement allowance remaining">
                  {data.remaining} cr
                </LabeledList.Item>
              </LabeledList>
              <Box mt={1} color="label">
                Eligible payments clear automatically. Card payments use shift
                credit first, then cleared funds.
              </Box>
            </Section>
            <Statement entries={data.activity} />
          </>
        )}
        {tab === 'offshore' && (
          <>
            <Section title="Transfer to offshore account">
              <Box mb={1}>
                Transfer cleared funds from your current account at 1:1.
                Offshore transfers are final and cannot be returned to your
                current account.
              </Box>
              <Box mb={1} color="label">
                Available for transfer: {data.cleared} cr
              </Box>
              <NumberInput
                value={amount}
                minValue={1}
                maxValue={Math.max(1, data.cleared)}
                step={1}
                onChange={setAmount}
              />
              <Button.Confirm
                ml={1}
                icon="exchange-alt"
                disabled={blocked || amount < 1 || amount > data.cleared}
                onClick={() => act('convert', { amount })}
              >
                Transfer {amount} cr
              </Button.Confirm>
            </Section>
            <Statement entries={data.offshore_activity} />
          </>
        )}
        {tab === 'terms' && (
          <Section title="Account terms">
            <LabeledList>
              <LabeledList.Item label="Settlement limit per shift">
                {data.settings.round_cap} cr before charges
              </LabeledList.Item>
              <LabeledList.Item label="Settlement fee">
                {data.settings.deposit_fee}%
              </LabeledList.Item>
              <LabeledList.Item label="Cleared-funds limit">
                {data.settings.balance_cap} cr
              </LabeledList.Item>
              <LabeledList.Item label="Account maintenance">
                {data.settings.levy_rate}% on cleared balances above{' '}
                {data.settings.levy_threshold} cr, assessed on the first
                settlement of each active shift
              </LabeledList.Item>
            </LabeledList>
            <Box mt={2}>
              Cleared funds carry forward when your assignment ends. Shift
              credit, including your payroll advance and payments above the
              settlement limit, expires at shift close.
            </Box>
            <Box mt={1}>
              Outstanding debt or account restrictions may delay settlement.
              Charges are rounded up to the nearest credit. Offshore transfers
              require cleared funds.
            </Box>
          </Section>
        )}
      </NtosWindow.Content>
    </NtosWindow>
  );
}
