// THIS IS AN APHELION UI FILE

/**
 * Every word the capture overlay shows, keyed by its row in the design's strings sheet. A failed drawing's line is
 * the one the report window gets for the same reason (bug_reporting_capture.dm cancel_ui_capture)
 */
export const STRINGS = {
  'ov.title': 'Capture for your bug report',
  'ov.text':
    'This is a copy of this window. Drag a box to crop it, or add it as it is. Only staff see it unless you make it public in the report.',
  'ov.add': 'Add to report',
  'ov.clear': 'Clear crop',
  'ov.cancel': 'Cancel',
  'ov.close': 'Close',
  'ov.keys': 'Enter adds it · Esc cancels',
  'ov.preparing': 'Getting it ready…',
  'ov.sending': 'Sending… {n}%',
  'ov.sent': 'Added. Go back to the report window to see it.',
  'ov.stopped': 'Sending stopped. Go back to the report and try again.',
  'ov.tooBigCrop':
    "It's too big to send. Crop it smaller, or add your own screenshot instead.",
  'cap.too_big':
    "That window's too big to capture. Add your own screenshot instead.",
  'cap.empty': 'That window has nothing on screen to capture.',
  'cap.failed':
    "That window couldn't be captured. Add your own screenshot instead.",
  'cap.timed_out':
    'The capture took too long. Try again, or add your own screenshot.',
} as const;

export type StringId = keyof typeof STRINGS;

/** Returns a string with its {placeholders} filled in */
export function say(id: StringId, values?: Record<string, number>): string {
  const template: string = STRINGS[id];
  if (!values) return template;
  return template.replace(/\{(\w+)\}/g, (whole, key: string) =>
    key in values ? String(values[key]) : whole,
  );
}
