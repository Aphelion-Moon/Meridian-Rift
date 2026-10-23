// THIS IS AN APHELION UI FILE

// Focus lands on these, from the pages, the summary and the notices
export const HEADING_ID = 'bug-report-heading';
export const SUMMARY_ID = 'bug-report-summary';
export const NOTICE_ID = 'bug-report-notice';
export const TITLE_ID = 'bug-report-title';
export const EXPECTED_ID = 'bug-report-expected';
export const stepId = (index: number) => `bug-report-step-${index}`;

/** Returns the key a picture's preview is kept under, since every retake brings a new one */
export const previewKey = (picture: { id: number; take: number }) =>
  `${picture.id}:${picture.take}`;
