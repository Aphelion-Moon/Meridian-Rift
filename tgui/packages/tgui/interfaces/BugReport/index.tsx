// THIS IS AN APHELION UI FILE

import { storage } from 'common/storage';
import { memo, useCallback, useEffect, useRef, useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Input,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';
import { useBackend } from '../../backend';
import { sendLargeAct } from '../../capture/topic';
import { Window } from '../../layouts';
import { hasReproductionHint } from './form-hints';
import type {
  BugReportData,
  ReportAttachment,
  ReportContext,
  ReportFields,
  ReportResult,
} from './types';

/** Unsent text per report, kept in the browser so typing never touches the server */
const DRAFTS_KEY = 'bug-report-drafts';
const KEPT_DRAFTS = 5;
const TEXT_FIELDS = {
  title: 'Title',
  observed: 'What happened',
  expected: 'Expected result',
  reproduction: 'Reproduction: what did you do before the problem?',
} as const;
type TextField = keyof typeof TEXT_FIELDS;
const CATEGORIES = ['Other', 'UI', 'Gameplay', 'Crash', 'Performance', 'Map'];
const SEVERITIES = ['unspecified', 'minor', 'major', 'critical'];
const UTC_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

type StoredDraft = { epoch: number; fields: ReportFields; at: number };

async function storeDraft(
  reportId: string,
  epoch: number,
  fields: ReportFields | null,
) {
  const drafts: Record<string, StoredDraft> =
    (await storage.get(DRAFTS_KEY)) ?? {};
  if (fields) drafts[reportId] = { epoch, fields, at: Date.now() };
  else delete drafts[reportId];
  const newest = Object.entries(drafts)
    .sort(([, a], [, b]) => b.at - a.at)
    .slice(0, KEPT_DRAFTS);
  storage.set(DRAFTS_KEY, Object.fromEntries(newest));
}

/** The form's text: the server's copy, then any newer unsent text this browser kept for the same report */
function useDraft(reportId: string, epoch: number, serverFields: ReportFields) {
  const [fields, setFields] = useState(serverFields);
  const latest = useRef(fields);
  latest.current = fields;
  const pending = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  // The server's text wins whenever it replaces it (a new epoch) or the report changes
  useEffect(() => {
    let current = true;
    setFields(serverFields);
    storage.get(DRAFTS_KEY).then((drafts) => {
      const kept: StoredDraft | undefined = drafts?.[reportId];
      if (current && kept?.epoch === epoch) setFields(kept.fields);
    });
    return () => {
      current = false;
    };
  }, [reportId, epoch]);

  // Whatever is still waiting to be kept goes when the window closes
  useEffect(
    () => () => {
      if (pending.current === undefined) return;
      clearTimeout(pending.current);
      storeDraft(reportId, epoch, latest.current);
    },
    [reportId, epoch],
  );

  const edit = useCallback(
    (name: keyof ReportFields, value: string | null) => {
      setFields((previous) => ({ ...previous, [name]: value }));
      clearTimeout(pending.current);
      pending.current = setTimeout(() => {
        pending.current = undefined;
        storeDraft(reportId, epoch, latest.current);
      }, 500);
    },
    [reportId, epoch],
  );
  return [fields, edit] as const;
}

const version = (
  context: ReportContext | undefined,
  name: 'client' | 'server' | 'compiler',
) => {
  const value = context?.versions?.[name];
  return value ? `${value.version}.${value.build}` : 'unavailable';
};

const ContextSection = memo(function ContextSection(props: {
  context?: ReportContext;
}) {
  const { context } = props;
  return (
    <Section title="Frozen incident context">
      <Box>
        Round: {context?.roundId ?? 'unavailable'}; map:{' '}
        {context?.map ?? 'unavailable'}
      </Box>
      <Box>
        Client: {version(context, 'client')}; server:{' '}
        {version(context, 'server')}; compiler: {version(context, 'compiler')}
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
  );
});

const ReceiptSection = memo(function ReceiptSection(props: {
  receipt: NonNullable<ReportResult['receipt']>;
}) {
  const { act } = useBackend();
  const { receipt } = props;
  return (
    <Section title="Report received">
      <Box>Reference: {receipt.reportId}</Box>
      <Box>
        Screening: {receipt.screening}; publication: {receipt.publication}
      </Box>
      {receipt.screening === 'waiting-ai-quota' && (
        <Box>
          Your report is saved and waiting for free AI allowance. You do not
          need to submit again.
        </Box>
      )}
      {!!receipt.nextAttemptAt && (
        <Box>Next attempt: {new Date(receipt.nextAttemptAt).toUTCString()}</Box>
      )}
      {!!receipt.issueUrl && (
        <Button onClick={() => act('issue')}>
          GitHub #{receipt.issueNumber}
        </Button>
      )}
      <Button onClick={() => act('new')}>Report another issue</Button>
    </Section>
  );
});

const TextFields = memo(function TextFields(props: {
  fields: ReportFields;
  edit: (name: keyof ReportFields, value: string | null) => void;
  checking: boolean;
  feedback?: ReportResult['feedback'];
}) {
  const { fields, edit, checking, feedback } = props;
  return (
    <>
      {(Object.keys(TEXT_FIELDS) as TextField[]).map((field) => (
        <Stack.Item key={field}>
          <Box bold mb={0.5}>
            {TEXT_FIELDS[field]}
          </Box>
          {field === 'title' ? (
            <Input
              fluid
              value={fields.title}
              maxLength={160}
              disabled={checking}
              onChange={(value) => edit('title', value)}
            />
          ) : (
            <TextArea
              fluid
              height="6rem"
              value={fields[field]}
              maxLength={8000}
              disabled={checking}
              onChange={(value) => edit(field, value)}
            />
          )}
          {feedback
            ?.filter((item) => item.field === field)
            .map((item) => (
              <Box key={item.message} color="bad">
                {item.message}
              </Box>
            ))}
        </Stack.Item>
      ))}
    </>
  );
});

const ScreenshotSection = memo(function ScreenshotSection(props: {
  attachment?: ReportAttachment | null;
  attachmentPending?: boolean;
  blocked: boolean;
  checking: boolean;
  preview?: { id: string; src: string };
  previewConfirmed?: boolean;
}) {
  const { act } = useBackend();
  const { attachment, blocked, checking, preview, previewConfirmed } = props;
  return (
    <Section title="Screenshot">
      <Box>{attachment?.state ?? 'Upload not yet confirmed'}</Box>
      {blocked && (
        <Box>
          Waiting for your screenshot. Submission stays paused until it is ready
          or you remove it.
        </Box>
      )}
      {!!preview && (
        <img
          key={preview.id}
          src={preview.src}
          alt="Selected report screenshot"
          style={{ maxWidth: '100%', maxHeight: '24rem' }}
          onLoad={() => act('preview_loaded', { attachmentId: preview.id })}
        />
      )}
      <Button
        disabled={checking || attachment?.state !== 'ready'}
        onClick={() =>
          act('preview', { attachmentId: attachment?.id, reload: true })
        }
      >
        Reload preview
      </Button>
      <Button
        disabled={checking}
        onClick={() =>
          act('remove_screenshot', { attachmentId: attachment?.id })
        }
      >
        Remove screenshot
      </Button>
      <Button.Checkbox
        checked={!!attachment?.publicConsent}
        disabled={
          checking || !previewConfirmed || attachment?.state !== 'ready'
        }
        onClick={() =>
          act('screenshot_consent', {
            attachmentId: attachment?.id,
            publicConsent: !attachment?.publicConsent,
          })
        }
      >
        Publish this screenshot with the GitHub issue
      </Button.Checkbox>
      <Box>
        The screenshot stays private unless you select public sharing after
        previewing it.
      </Box>
    </Section>
  );
});

export const BugReport = () => {
  const { act, data } = useBackend<BugReportData>();
  const [fields, edit] = useDraft(data.reportId, data.fieldsEpoch, data.fields);
  const [hint, setHint] = useState(false);
  const [acknowledged, setAcknowledged] = useState('');
  const [error, setError] = useState('');
  const [captureRequested, setCaptureRequested] = useState(false);
  const [captureTarget, setCaptureTarget] = useState('');
  const checking =
    data.busy || (data.result?.kind === 'checking' && !data.pollingPaused);
  const attachmentBlocked =
    !!data.attachmentPending ||
    (!!data.attachment && data.attachment.state !== 'ready');
  const receipt = data.result?.receipt;
  const readyId =
    data.attachment?.state === 'ready' ? data.attachment.id : undefined;
  const preview =
    (readyId && data.preview?.id === readyId && data.preview) || undefined;
  const targets = data.captureTargets ?? [];
  const target = targets.some((item) => item.id === captureTarget)
    ? captureTarget
    : targets[0]?.id;

  useEffect(() => {
    setHint(false);
    setAcknowledged('');
    setError('');
  }, [data.reportId, data.fieldsEpoch]);

  // The text is in the report now, so this browser can forget it
  useEffect(() => {
    if (receipt) storeDraft(data.reportId, 0, null);
  }, [!!receipt]);

  // The preview comes once per attachment, only when the page asks for it
  useEffect(() => {
    if (readyId && !preview && !data.busy)
      act('preview', { attachmentId: readyId });
  }, [readyId, !!preview, data.busy]);

  // Other windows open and close without telling this one, so look again on focus
  useEffect(() => {
    const refreshTargets = () => act('targets');
    window.addEventListener('focus', refreshTargets);
    return () => window.removeEventListener('focus', refreshTargets);
  }, []);

  /** Sends an action carrying the form whole, past tgui's 2 KB chunking and its chunk cap */
  function actWithFields(action: string, extra: Record<string, unknown> = {}) {
    sendLargeAct(action, { ...extra, fields, fieldsEpoch: data.fieldsEpoch });
  }

  function submit(asWritten = false) {
    if (attachmentBlocked) {
      setError(
        'Wait for your screenshot to finish, retry it, or remove it before submitting.',
      );
      return;
    }
    if (
      fields.incidentAt &&
      (!UTC_TIME.test(fields.incidentAt) ||
        !Number.isFinite(Date.parse(fields.incidentAt)) ||
        new Date(fields.incidentAt).toISOString() !== fields.incidentAt)
    ) {
      setError(
        'Use the exact UTC format shown for incident time, or leave it blank.',
      );
      return;
    }
    if (
      (Object.keys(TEXT_FIELDS) as TextField[]).some(
        (key) => !fields[key].trim(),
      )
    ) {
      setError(
        'Fill each required field. Describe what you did before the problem happened.',
      );
      return;
    }
    const content = JSON.stringify(fields);
    if (
      !asWritten &&
      acknowledged !== content &&
      hasReproductionHint(fields.reproduction)
    ) {
      setHint(true);
      return;
    }
    setAcknowledged(content);
    setHint(false);
    setError('');
    actWithFields('submit');
  }

  return (
    <Window title="Report a Meridian bug" width={700} height={760}>
      <Window.Content scrollable>
        <Section title="Report an issue">
          <Box mb={1}>
            Staff receive private diagnostics. Your report normally becomes a
            public GitHub issue automatically; no GitHub account is needed.
          </Box>
          <ContextSection context={data.context} />
          {receipt ? (
            <ReceiptSection receipt={receipt} />
          ) : (
            <Stack vertical>
              <TextFields
                fields={fields}
                edit={edit}
                checking={checking}
                feedback={data.result?.feedback}
              />
              <Stack.Item>
                <Box bold>Optional incident time (UTC)</Box>
                <Input
                  fluid
                  value={fields.incidentAt ?? ''}
                  placeholder="YYYY-MM-DDTHH:mm:ss.sssZ"
                  maxLength={40}
                  disabled={checking}
                  onChange={(value) => edit('incidentAt', value || null)}
                />
                <Box>
                  Leave blank to use the captured time. An edited time is
                  reporter-supplied; the original context stays frozen.
                </Box>
              </Stack.Item>
              <Stack.Item>
                <Dropdown
                  options={CATEGORIES}
                  selected={fields.category}
                  disabled={checking}
                  onSelected={(category) => edit('category', category)}
                />
                <Dropdown
                  options={SEVERITIES}
                  selected={fields.severity}
                  disabled={checking}
                  onSelected={(severity) => edit('severity', severity)}
                />
                <Button
                  disabled={checking || !target}
                  onClick={() =>
                    actWithFields('capture_ui', { windowId: target })
                  }
                >
                  Snapshot selected TGUI
                </Button>
                <Dropdown
                  options={targets.map((item) => ({
                    value: item.id,
                    displayText: item.title,
                  }))}
                  selected={target}
                  disabled={checking || !target}
                  placeholder="Open another TGUI to snapshot it"
                  onClick={() => act('targets')}
                  onSelected={setCaptureTarget}
                />
                <Box>
                  Snapshot one of your open TGUI windows, then preview and
                  optionally crop it there. Bug-report windows are excluded.
                  This is a UI reconstruction; check that its contents look
                  correct.
                </Box>
                <Button
                  disabled={checking}
                  onClick={() => {
                    Byond.command('.screenshot auto');
                    setCaptureRequested(true);
                  }}
                >
                  Capture game map (F2)
                </Button>
                <Button
                  disabled={checking}
                  onClick={() => actWithFields('screenshot')}
                >
                  Choose screenshot
                </Button>
                <Box>
                  Choose a PNG, JPEG or WebP image, up to 10 MiB. Use an OS
                  snipping tool for TGUI or other windows; F2 captures only the
                  game map into BYOND/screenshots.
                </Box>
                {captureRequested && (
                  <Box>
                    Capture requested. If no image was saved, press F2. Then
                    choose the saved screenshot.
                  </Box>
                )}
                {(!!data.attachment || data.attachmentPending) && (
                  <ScreenshotSection
                    attachment={data.attachment}
                    blocked={attachmentBlocked}
                    checking={checking}
                    preview={preview}
                    previewConfirmed={data.previewConfirmed}
                  />
                )}
              </Stack.Item>
              {data.conflict && (
                <Stack.Item>
                  <Box>
                    The service has another saved version. Your local text is
                    preserved. Choose which version to continue editing.
                  </Box>
                  <Button disabled={checking} onClick={() => act('reload')}>
                    Load saved draft
                  </Button>
                  <Button
                    disabled={checking}
                    onClick={() => actWithFields('keep')}
                  >
                    Keep my local text
                  </Button>
                </Stack.Item>
              )}
              {hint && (
                <Stack.Item>
                  <Box>
                    What did you do immediately before the problem? Add an
                    action or any setup that matters.
                  </Box>
                  <Button onClick={() => setHint(false)}>Add details</Button>
                  <Button onClick={() => submit(true)}>
                    Submit as written
                  </Button>
                </Stack.Item>
              )}
              <Stack.Item>
                <Button
                  disabled={checking || data.conflict || attachmentBlocked}
                  onClick={() => submit()}
                >
                  {checking ? 'Checking report…' : 'Submit report'}
                </Button>
              </Stack.Item>
              {data.result?.kind === 'limited' && (
                <Box color="average">
                  Limit reached. Next available:{' '}
                  {new Date(data.result.retryAt ?? 0).toUTCString()}
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
