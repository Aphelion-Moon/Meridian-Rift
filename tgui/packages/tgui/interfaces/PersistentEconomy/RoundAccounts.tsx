// THIS IS AN APHELION UI FILE
import { useState } from 'react';
import {
  Box,
  Button,
  Input,
  NumberInput,
  Section,
  Table,
} from 'tgui-core/components';
import { useBackend } from '../../backend';

export type RoundAccount = {
  id: string;
  name: string;
  owner: string | null;
  character_id: string | null;
  balance: number;
  debt: number;
  history: {
    time: string;
    amount: number;
    balance: number;
    reason: string;
    debt_collected: number;
  }[];
};

export function RoundAccountHistory(props: { account: RoundAccount }) {
  const { account } = props;
  const history = Array.isArray(account.history) ? account.history : [];
  return (
    <Section title={`Round transactions: ${account.name} (${account.id})`}>
      <Box mb={1}>
        Balance: {account.balance} credits · Debt: {account.debt} credits
      </Box>
      <Table>
        <Table.Row header>
          <Table.Cell>Time</Table.Cell>
          <Table.Cell>Change</Table.Cell>
          <Table.Cell>Balance after</Table.Cell>
          <Table.Cell>Reason</Table.Cell>
        </Table.Row>
        {history.map((entry, index) => (
          <Table.Row key={`${entry.time}-${index}`}>
            <Table.Cell>{entry.time}</Table.Cell>
            <Table.Cell color={entry.amount < 0 ? 'bad' : 'good'}>
              {entry.amount > 0 ? '+' : ''}
              {entry.amount}
            </Table.Cell>
            <Table.Cell>{entry.balance}</Table.Cell>
            <Table.Cell>
              {entry.reason}
              {entry.debt_collected > 0 && (
                <Box color="label">Debt withheld: {entry.debt_collected}</Box>
              )}
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
      {!history.length && <Box>No recorded transactions this round.</Box>}
    </Section>
  );
}

export function RoundAccounts(props: {
  accounts: RoundAccount[];
  departments?: boolean;
  reason: string;
}) {
  const { accounts, departments, reason } = props;
  const { act } = useBackend();
  const [query, setQuery] = useState('');
  const [selectedId, setSelectedId] = useState('');
  const [adjustment, setAdjustment] = useState(100);
  const selected = accounts.find((account) => account.id === selectedId);
  const matches = accounts.filter((account) =>
    `${account.id} ${account.name} ${account.owner || ''}`
      .toLowerCase()
      .includes(query.toLowerCase()),
  );
  return (
    <>
      <Section
        title={departments ? 'Department budgets' : 'Round bank accounts'}
      >
        <Box mb={1} color="label">
          {departments
            ? 'These are the live department budgets for this round. Changes use normal banking rules, including debt collection.'
            : 'Select an account to inspect its most recent 100 balance changes this round, including salaries, purchases, transfers, and savings deposits.'}
        </Box>
        <Input
          fluid
          placeholder={
            departments ? 'Search departments' : 'Search round accounts'
          }
          value={query}
          onChange={setQuery}
        />
        <Table mt={1}>
          <Table.Row header>
            <Table.Cell>{departments ? 'Department' : 'Account'}</Table.Cell>
            <Table.Cell>Balance</Table.Cell>
            <Table.Cell>Debt</Table.Cell>
          </Table.Row>
          {matches.map((account) => (
            <Table.Row key={account.id}>
              <Table.Cell>
                <Button
                  selected={selectedId === account.id}
                  onClick={() => setSelectedId(account.id)}
                >
                  {account.name} ({account.id})
                </Button>
                {account.owner && <Box color="label">{account.owner}</Box>}
              </Table.Cell>
              <Table.Cell>{account.balance}</Table.Cell>
              <Table.Cell>{account.debt}</Table.Cell>
            </Table.Row>
          ))}
        </Table>
        {!matches.length && <Box>No matching accounts.</Box>}
      </Section>
      {selected && departments && (
        <Section title={`Adjust ${selected.name}`}>
          <Box mb={1}>
            Use a positive amount to add credits or a negative amount to remove
            them.
          </Box>
          <NumberInput
            value={adjustment}
            minValue={-1000000}
            maxValue={1000000}
            step={1}
            onChange={setAdjustment}
          />
          <Button.Confirm
            ml={1}
            disabled={
              !reason.trim() || !adjustment || selected.balance + adjustment < 0
            }
            onClick={() =>
              act('adjust_department', {
                id: selected.id,
                amount: adjustment,
                reason,
              })
            }
          >
            Apply budget adjustment
          </Button.Confirm>
          <Box mt={1} color="label">
            The reason at the top of this panel is required. Changes are logged
            for administrators.
          </Box>
        </Section>
      )}
      {selected && <RoundAccountHistory account={selected} />}
    </>
  );
}
