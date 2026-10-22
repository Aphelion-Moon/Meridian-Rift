export type ReportFields = {
  title: string;
  observed: string;
  expected: string;
  reproduction: string;
  category: string;
  severity: string;
  incidentAt: number | null;
};
export type BugReportData = {
  fields: ReportFields;
  revision: number;
  status: string;
  busy: boolean;
  attachment?: { state: string };
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
