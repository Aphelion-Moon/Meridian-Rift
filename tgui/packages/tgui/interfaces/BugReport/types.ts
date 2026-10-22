// THIS IS AN APHELION UI FILE

export type ReportFields = {
  title: string;
  observed: string;
  expected: string;
  reproduction: string;
  category: string;
  severity: string;
  incidentAt: string | null;
};

export type ReportContext = {
  roundId: string | null;
  map: string | null;
  capturedAt: string;
  versions: Record<
    'client' | 'server' | 'compiler',
    { version: number; build: number } | null
  >;
  build: {
    commit: string | null;
    base: string | null;
    testMerges: { number: number; commit: string | null }[];
  };
};

export type ReportAttachment = {
  id: string;
  state: string;
  publicConsent: boolean;
};

export type ReportResult = {
  kind: string;
  feedback?: { field: string; message: string }[];
  retryAt?: number;
  receipt?: {
    reportId: string;
    screening: string;
    publication: string;
    issueUrl?: string;
    issueNumber?: number;
    nextAttemptAt?: number;
  };
};

export type BugReportData = {
  // Static: sent when the window opens and when the server replaces the text
  reportId: string;
  fieldsEpoch: number;
  fields: ReportFields;
  context?: ReportContext;
  // Each update
  status: string;
  busy: boolean;
  conflict?: boolean;
  pollingPaused?: boolean;
  result?: ReportResult | null;
  attachment?: ReportAttachment | null;
  attachmentPending?: boolean;
  previewConfirmed?: boolean;
  captureTargets?: { id: string; title: string }[] | null;
  // Only sent when the page asks, and kept until replaced
  preview?: { id: string; src: string } | null;
};
