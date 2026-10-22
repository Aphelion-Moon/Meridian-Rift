import { useState } from 'react';
import { Box, Button, Dropdown, Input, Section, Stack, TextArea } from 'tgui-core/components';
import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { hasReproductionHint } from './form-hints';
import type { BugReportData, ReportFields } from './types';

export const BugReport = () => {
  const { act, data } = useBackend<BugReportData>();
  const [fields, setFields] = useState<ReportFields>(data.fields);
  const [hint, setHint] = useState(false);
  const [acknowledged, setAcknowledged] = useState('');
  const [error, setError] = useState('');
  const checking = data.busy || data.result?.kind === 'checking';
  const receipt = data.result?.receipt;
  function submit(asWritten = false) {
    if (['title', 'observed', 'expected', 'reproduction'].some((key) => !fields[key].trim())) {
      setError('Fill each required field. Describe what you did before the problem happened.');
      return;
    }
    const content = JSON.stringify(fields);
    if (!asWritten && acknowledged !== content && hasReproductionHint(fields.reproduction)) {
      setHint(true);
      return;
    }
    setAcknowledged(content);
    setHint(false);
    setError('');
    act('submit', { fields });
  }
  const labels = {
    title: 'Title',
    observed: 'What happened',
    expected: 'Expected result',
    reproduction: 'Reproduction: what did you do before the problem?',
  };
  return (
    <Window title="Report a Meridian bug" width={700} height={760}>
      <Window.Content scrollable>
        <Section title="Report an issue">
          <Box mb={1}>
            Staff receive private diagnostics. Your report normally becomes a public GitHub issue
            automatically; no GitHub account is needed.
          </Box>
          {receipt ? (
            <Section title="Report received">
              <Box>Reference: {receipt.reportId}</Box>
              <Box>
                Screening: {receipt.screening}; publication: {receipt.publication}
              </Box>
              {receipt.screening === 'waiting-ai-quota' && (
                <Box>
                  Your report is saved and waiting for free AI allowance. You do not need to submit
                  again.
                </Box>
              )}
              {!!receipt.nextAttemptAt && (
                <Box>Next attempt: {new Date(receipt.nextAttemptAt).toUTCString()}</Box>
              )}
              {!!receipt.issueUrl && (
                <Button onClick={() => act('issue')}>GitHub #{receipt.issueNumber}</Button>
              )}
              <Button onClick={() => act('new')}>Report another issue</Button>
            </Section>
          ) : (
            <Stack vertical>
              {Object.entries(labels).map(([field, label]) => (
                <Stack.Item key={field}>
                  <Box bold mb={0.5}>
                    {label}
                  </Box>
                  {field === 'title' ? (
                    <Input
                      fluid
                      value={fields.title}
                      maxLength={160}
                      disabled={checking}
                      onChange={(value) => setFields({ ...fields, title: value })}
                    />
                  ) : (
                    <TextArea
                      fluid
                      height="6rem"
                      value={fields[field]}
                      maxLength={8000}
                      disabled={checking}
                      onChange={(value) => setFields({ ...fields, [field]: value })}
                    />
                  )}
                  {data.result?.feedback
                    ?.filter((feedback) => feedback.field === field)
                    .map((feedback) => (
                      <Box key={feedback.message} color="bad">
                        {feedback.message}
                      </Box>
                    ))}
                </Stack.Item>
              ))}
              <Stack.Item>
                <Dropdown
                  options={['Other', 'UI', 'Gameplay', 'Crash', 'Performance', 'Map']}
                  selected={fields.category}
                  disabled={checking}
                  onSelected={(category) => setFields({ ...fields, category })}
                />
                <Dropdown
                  options={['unspecified', 'minor', 'major', 'critical']}
                  selected={fields.severity}
                  disabled={checking}
                  onSelected={(severity) => setFields({ ...fields, severity })}
                />
                <Button disabled={checking} onClick={() => act('screenshot', { fields })}>
                  Add screenshot
                </Button>
                <Button disabled={checking} onClick={() => act('browser', { fields })}>
                  Open in browser
                </Button>
                {!!data.attachment && (
                  <Box>
                    Screenshot: {data.attachment.state}. Processing images are excluded if you
                    submit now.
                  </Box>
                )}
              </Stack.Item>
              {hint && (
                <Stack.Item>
                  <Box>
                    What did you do immediately before the problem? Add an action or any setup that
                    matters.
                  </Box>
                  <Button onClick={() => setHint(false)}>Add details</Button>
                  <Button onClick={() => submit(true)}>Submit as written</Button>
                </Stack.Item>
              )}
              <Stack.Item>
                <Button disabled={checking} onClick={() => submit()}>
                  {checking ? 'Checking report…' : 'Submit report'}
                </Button>
              </Stack.Item>
              {data.result?.kind === 'limited' && (
                <Box color="average">
                  Limit reached. Next available: {new Date(data.result.retryAt ?? 0).toUTCString()}
                </Box>
              )}
              {error && <Box color="bad">{error}</Box>}
            </Stack>
          )}
          <Box mt={1}>{data.status}</Box>
          <Button onClick={() => act('refresh')}>Retry connection</Button>
        </Section>
      </Window.Content>
    </Window>
  );
};
