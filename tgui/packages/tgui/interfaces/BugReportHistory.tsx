// THIS IS AN APHELION UI FILE

import { useEffect, useState } from 'react';
import { Box, NoticeBox, Section, Stack } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { readDraftTitles } from './BugReport/draft';
import { ReportButton } from './BugReport/ReportButton';

type Report = {
  id: string;
  title: string;
  fieldsEpoch: number;
  startedAt: string;
  submitted: boolean;
  checking: boolean;
  canOpen: boolean;
  hasIssue: boolean;
};

type Data = {
  reports: Report[];
  refreshing: boolean;
  status: string | null;
};

export function BugReportHistory() {
  const { act, data } = useBackend<Data>();
  const [titles, setTitles] = useState<
    Awaited<ReturnType<typeof readDraftTitles>>
  >({});
  useEffect(() => {
    let current = true;
    const load = () => {
      readDraftTitles().then((saved) => {
        if (current) setTitles(saved);
      });
    };
    load();
    window.addEventListener('focus', load);
    return () => {
      current = false;
      window.removeEventListener('focus', load);
    };
  }, [data.reports]);

  function titleOf(report: Report) {
    const local = titles[report.id];
    const title =
      !report.submitted && local?.epoch === report.fieldsEpoch
        ? local.title
        : report.title;
    return title.trim() || 'Untitled report';
  }

  return (
    <Window title="View recent bug reports" width={620} height={560}>
      <Window.Content scrollable>
        <Section
          title="Your recent bug reports"
          buttons={
            <ReportButton
              icon="rotate"
              disabled={data.refreshing}
              onClick={() => act('refresh')}
            >
              {data.refreshing ? 'Refreshing…' : 'Refresh'}
            </ReportButton>
          }
        >
          Your last 20 reports from this connection, newest first. This list
          clears when you disconnect.
        </Section>
        {data.status && <NoticeBox>{data.status}</NoticeBox>}
        {[false, true].map((submitted) => {
          const reports = data.reports.filter(
            (report) => report.submitted === submitted,
          );
          return (
            <Section
              key={String(submitted)}
              title={`${submitted ? 'Submitted' : 'Drafts'} (${reports.length})`}
            >
              {reports.length === 0 && (
                <Box color="label">
                  {submitted ? 'No submitted reports yet.' : 'No drafts.'}
                </Box>
              )}
              <Stack vertical>
                {reports.map((report) => (
                  <Stack.Item key={report.id}>
                    <Stack align="center">
                      <Stack.Item grow>
                        <Box bold>{titleOf(report)}</Box>
                        <Box color="label" mt={0.5}>
                          {submitted ? 'Submitted' : 'Draft'} · Started{' '}
                          {report.startedAt}
                        </Box>
                        {submitted && !report.hasIssue && (
                          <Box color="label" mt={0.5}>
                            {report.checking
                              ? 'Checking report. Refresh to check again.'
                              : 'Awaiting GitHub link. Refresh to check again.'}
                          </Box>
                        )}
                      </Stack.Item>
                      <Stack.Item>
                        {submitted ? (
                          <ReportButton
                            icon="arrow-up-right-from-square"
                            disabled={!report.hasIssue}
                            aria-label={`Open GitHub issue: ${titleOf(report)}`}
                            onClick={() => act('issue', { id: report.id })}
                          >
                            Open GitHub issue
                          </ReportButton>
                        ) : (
                          <ReportButton
                            icon="pen"
                            disabled={!report.canOpen}
                            aria-label={`Continue draft: ${titleOf(report)}`}
                            onClick={() => act('open', { id: report.id })}
                          >
                            Continue draft
                          </ReportButton>
                        )}
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          );
        })}
      </Window.Content>
    </Window>
  );
}
