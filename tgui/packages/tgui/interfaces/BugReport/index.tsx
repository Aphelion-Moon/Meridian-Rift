import { useEffect, useState } from 'react';
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
  const checking = data.busy || (data.result?.kind === 'checking' && !data.pollingPaused);
  const receipt = data.result?.receipt;
  const context = data.context;
  const version = (name: 'client' | 'server' | 'compiler') => {
    const value = context?.versions?.[name];
    return value ? `${value.version}.${value.build}` : 'unavailable';
  };
  useEffect(() => {
    setFields(data.fields);
    setHint(false);
    setAcknowledged('');
    setError('');
  }, [data.reportId, data.fieldsEpoch]);
  function edit(next: ReportFields) {
    setFields(next);
    // Persist to the owning DM draft, without HTTP or inference on typing.
    act('draft', { fields: next, fieldsEpoch: data.fieldsEpoch });
  }
  function submit(asWritten = false) {
    if (
      fields.incidentAt &&
      (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(fields.incidentAt) ||
        !Number.isFinite(Date.parse(fields.incidentAt)) ||
        new Date(fields.incidentAt).toISOString() !== fields.incidentAt)
    ) {
      setError('Use the exact UTC format shown for incident time, or leave it blank.');
      return;
    }
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
    act('submit', { fields, fieldsEpoch: data.fieldsEpoch });
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
          <Section title="Frozen incident context">
            <Box>
              Round: {context?.roundId ?? 'unavailable'}; map: {context?.map ?? 'unavailable'}
            </Box>
            <Box>
              Client: {version('client')}; server: {version('server')}; compiler:{' '}
              {version('compiler')}
            </Box>
            <Box>
              Revision: {context?.build?.commit ?? 'unavailable'}; base:{' '}
              {context?.build?.base ?? 'unavailable'}
            </Box>
            <Box>
              Test merges:{' '}
              {context?.build?.testMerges
                ?.map((merge) => `#${merge.number} ${merge.commit ?? ''}`)
                .join(', ') || 'none recorded'}
            </Box>
          </Section>
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
                      onChange={(value) => edit({ ...fields, title: value })}
                    />
                  ) : (
                    <TextArea
                      fluid
                      height="6rem"
                      value={fields[field]}
                      maxLength={8000}
                      disabled={checking}
                      onChange={(value) => edit({ ...fields, [field]: value })}
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
                <Box bold>Optional incident time (UTC)</Box>
                <Input
                  fluid
                  value={fields.incidentAt ?? ''}
                  placeholder="YYYY-MM-DDTHH:mm:ss.sssZ"
                  maxLength={40}
                  disabled={checking}
                  onChange={(value) => edit({ ...fields, incidentAt: value || null })}
                />
                <Box>
                  Leave blank to use the captured time. An edited time is reporter-supplied; the
                  original context stays frozen.
                </Box>
              </Stack.Item>
              <Stack.Item>
                <Dropdown
                  options={['Other', 'UI', 'Gameplay', 'Crash', 'Performance', 'Map']}
                  selected={fields.category}
                  disabled={checking}
                  onSelected={(category) => edit({ ...fields, category })}
                />
                <Dropdown
                  options={['unspecified', 'minor', 'major', 'critical']}
                  selected={fields.severity}
                  disabled={checking}
                  onSelected={(severity) => edit({ ...fields, severity })}
                />
                <Button
                  disabled={checking}
                  onClick={() => act('screenshot', { fields, fieldsEpoch: data.fieldsEpoch })}
                >
                  Add screenshot
                </Button>
                <Button
                  disabled={checking}
                  onClick={() => act('browser', { fields, fieldsEpoch: data.fieldsEpoch })}
                >
                  Open in browser
                </Button>
                {!!data.attachment && (
                  <Box>
                    Screenshot: {data.attachment.state}. Processing images are excluded if you
                    submit now.
                  </Box>
                )}
              </Stack.Item>
              {data.conflict && (
                <Stack.Item>
                  <Box>
                    The browser has another saved version. Your local text is preserved. Choose
                    which version to continue editing.
                  </Box>
                  <Button disabled={checking} onClick={() => act('reload')}>
                    Load browser draft
                  </Button>
                  <Button
                    disabled={checking}
                    onClick={() => act('keep', { fields, fieldsEpoch: data.fieldsEpoch })}
                  >
                    Keep my local text
                  </Button>
                </Stack.Item>
              )}
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
                <Button disabled={checking || data.conflict} onClick={() => submit()}>
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
