// THIS IS AN APHELION UI FILE
import { Box, NoticeBox, Section } from 'tgui-core/components';

export type SavingsSettings = {
  enabled: boolean;
  round_cap: number;
  deposit_fee: number;
  balance_cap: number;
  levy_threshold: number;
  levy_rate: number;
};

export type SavingsAccount = {
  id: string;
  owner: string;
  name: string;
  regular: number;
  offshore: number;
  frozen: boolean;
  remaining: number;
  history: {
    time: string;
    round: string;
    currency: string;
    amount: number;
    reason: string;
  }[];
};

export function SavingsHistory(props: { account: SavingsAccount }) {
  const history = Array.isArray(props.account.history)
    ? props.account.history
    : [];
  return (
    <Section title="Recent transactions">
      {!Array.isArray(props.account.history) && (
        <NoticeBox>
          Older history records require recovery. The account balance is
          unaffected.
        </NoticeBox>
      )}
      {!history.length && <Box>No transactions yet.</Box>}
      {history.map((entry, index) => (
        <Box key={`${entry.time}-${index}`} mb={1}>
          <Box color="label">
            {entry.time} · {entry.currency}
          </Box>
          <Box color={entry.amount < 0 ? 'bad' : 'good'} inline mr={1}>
            {entry.amount > 0 ? '+' : ''}
            {entry.amount}
          </Box>
          {entry.reason}
        </Box>
      ))}
    </Section>
  );
}

export { Banking as PersistentSavings } from './PersistentEconomy/Banking';
