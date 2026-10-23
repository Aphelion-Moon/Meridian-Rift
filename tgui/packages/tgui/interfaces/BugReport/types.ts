// THIS IS AN APHELION UI FILE

/** The report's text and choices as DM holds them, and as every act carrying the form sends them */
export type ReportFields = {
  title: string;
  expected: string;
  /** The steps as numbered lines, "1. ..." */
  reproduction: string;
  category: string;
  severity: string;
};

export type ReportLimits = {
  title: number;
  text: number;
  steps: number;
  reports: number;
  sends: number;
  uploads: number;
};

export type ReportChoice = { value: string; label: string; icon?: string };

export type PictureSource = 'view' | 'window' | 'file';

export type PictureState =
  | 'rendering'
  | 'waiting'
  | 'uploading'
  | 'processing'
  | 'ready'
  | 'failed';

export type ReportPicture = {
  /** Kept through retakes */
  id: number;
  source: PictureSource;
  /** The window's title for a window capture */
  title: string | null;
  /** Bumped by every new image, so a preview belongs to one take */
  take: number;
  /** How long ago it was taken, in ms when the update left */
  takenAgo: number;
  state: PictureState;
  reason: 'nothing' | 'render' | 'invalid' | 'unconfirmed' | null;
  publicConsent: boolean;
  previewSeen: boolean;
};

export type ReportFeedback = {
  field: 'title' | 'observed' | 'expected' | 'reproduction';
  message: string;
  quote?: string;
};

export type ReportReceipt = {
  reportId?: string;
  screening: string;
  publication: string;
  issueUrl?: string;
  issueNumber?: number;
  /** The wait until it tries publishing again, in ms from this update */
  nextAttemptIn?: number;
};

export type ReportResult = {
  kind: 'checking' | 'needs_revision' | 'limited' | 'accepted' | string;
  feedback?: ReportFeedback[] | null;
  reason?: string;
  receipt?: ReportReceipt;
};

export type ReportLimit = {
  kind: 'reports' | 'sends';
  /** The wait in ms from this update */
  retryIn: number;
};

export type CaptureTarget = { id: string; title: string };

export type ReportPreview = { id: number; take: number; src: string | null };

export type BugReportData = {
  // Static: sent when the window opens and when the server replaces the text
  reportId: string;
  enabled: boolean;
  fields: ReportFields;
  fieldsEpoch: number;
  limits: ReportLimits;
  maxPictures: number;
  kinds: ReportChoice[];
  impacts: ReportChoice[];
  // Each update
  status: string | null;
  busy: boolean;
  result: ReportResult | null;
  conflict: boolean;
  pollingPaused: boolean;
  unreachable: boolean;
  limit: ReportLimit | null;
  pictures: ReportPicture[] | null;
  uploadsLeft: number;
  captureTargets: CaptureTarget[] | null;
  // Only sent when the page asks, and kept until replaced
  preview?: ReportPreview | null;
};
