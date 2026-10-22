export type ReportFields = {
  title: string;
  observed: string;
  expected: string;
  reproduction: string;
  category: string;
  severity: string;
  incidentAt: string | null;
};
export type BugReportData = {
  reportId: string;
  fieldsEpoch: number;
  conflict?: boolean;
  pollingPaused?: boolean;
  fields: ReportFields;
  context?: {
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
  revision: number;
  status: string;
  busy: boolean;
  attachment?: { id: string; state: string; publicConsent: boolean };
  attachmentPending?: boolean;
  preview?: string;
  previewConfirmed?: boolean;
  captureTargets?: { id: string; title: string }[];
  result?: {
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
};
