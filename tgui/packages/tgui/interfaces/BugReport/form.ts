// THIS IS AN APHELION UI FILE

import { hasReproductionHint } from './form-hints';
import { type StringId, say } from './strings';
import type { ReportFields, ReportLimits, ReportReceipt } from './types';

/** The form as the window edits it - the steps one per field, '' for a question left unanswered */
export type LocalFields = {
  title: string;
  steps: string[];
  expected: string;
  category: string;
  severity: string;
};

/** Changes the form through a function of what it was */
export type EditFields = (
  change: (previous: LocalFields) => LocalFields,
) => void;

export type Page = 1 | 2 | 3 | 4;

export type FieldName = 'title' | 'steps' | 'expected';

export type FieldError = { field: FieldName; page: Page; text: string };

// Only Unicode White_Space and the BOM count as nothing, as DM's trimtext() does
const BLANK = /^[\p{White_Space}﻿]*$/u;
// The numbering DM counts steps by, and the one joinSteps() writes
const NUMBERED = /^[ \t]*\d{1,3}\.[ \t]?(.*)$/;
// The answers the cloud reads as staff's to look at, whichever of the two it names
const STAFF_STATES = new Set([
  'quarantine',
  'configuration-error',
  'ambiguous',
]);

/** Whether the text holds nothing a reader would see */
export function isBlank(text: string) {
  return BLANK.test(text);
}

/** Returns the length in characters, the way DM's length_char() counts them */
export function lengthOf(text: string) {
  let count = 0;
  for (const _character of text) count++;
  return count;
}

/** Returns the steps as the numbered lines DM keeps, leaving out the blank ones */
export function joinSteps(steps: string[]) {
  return steps
    .filter((step) => !isBlank(step))
    .map((step, index) => `${index + 1}. ${step.trim()}`)
    .join('\n');
}

/** Returns the step fields for saved numbered lines, with one empty field when there are none */
export function splitSteps(text: string, max: number) {
  const steps: string[] = [];
  for (const line of text.split(/\r?\n/)) {
    if (isBlank(line)) continue;
    const numbered = NUMBERED.exec(line);
    if (numbered && isBlank(numbered[1])) continue;
    if (numbered && steps.length < max) {
      steps.push(numbered[1].trim());
    } else if (steps.length) {
      // Lines that aren't steps of their own belong to the one before
      steps[steps.length - 1] += ` ${(numbered?.[1] ?? line).trim()}`;
    } else {
      steps.push(line.trim());
    }
  }
  return steps.length ? steps : [''];
}

/** Returns the form as DM takes it */
export function toWire(fields: LocalFields): ReportFields {
  return {
    title: fields.title,
    expected: fields.expected,
    reproduction: joinSteps(fields.steps),
    category: fields.category || 'Other',
    severity: fields.severity || 'unspecified',
  };
}

/** Returns DM's copy of the form as the window edits it */
export function fromWire(fields: ReportFields, maxSteps: number): LocalFields {
  return {
    title: fields?.title ?? '',
    steps: splitSteps(fields?.reproduction ?? '', maxSteps),
    expected: fields?.expected ?? '',
    // DM keeps these defaults for a skipped question, so they show as unanswered
    category: fields?.category === 'Other' ? '' : (fields?.category ?? ''),
    severity:
      fields?.severity === 'unspecified' ? '' : (fields?.severity ?? ''),
  };
}

/** Returns the error for text over its limit, or null */
function tooLong(length: number, limit: number) {
  const over = length - limit;
  if (over <= 0) return null;
  return over === 1 ? say('err.tooLong.one') : say('err.tooLong', { n: over });
}

/** Returns what stops a page going on, in the order the page shows its fields */
export function checkPage(
  page: Page,
  fields: LocalFields,
  limits: ReportLimits,
): FieldError[] {
  const errors: FieldError[] = [];
  const add = (field: FieldName, text: string | null) => {
    if (text) errors.push({ field, page, text });
  };
  if (page === 1) {
    add(
      'title',
      isBlank(fields.title)
        ? say('err.title')
        : tooLong(lengthOf(fields.title), limits.title),
    );
  } else if (page === 3) {
    const steps = joinSteps(fields.steps);
    add(
      'steps',
      steps ? tooLong(lengthOf(steps), limits.text) : say('err.steps'),
    );
    add(
      'expected',
      isBlank(fields.expected)
        ? say('err.expected')
        : tooLong(lengthOf(fields.expected), limits.text),
    );
  }
  return errors;
}

/** Returns every page's problems, which sending checks again before anything goes */
export function checkAll(fields: LocalFields, limits: ReportLimits) {
  return [...checkPage(1, fields, limits), ...checkPage(3, fields, limits)];
}

/** Returns the steps' words when they're only a phrase like "doesn't work", or null */
export function vagueSteps(fields: LocalFields) {
  const text = fields.steps
    .filter((step) => !isBlank(step))
    .map((step) => step.trim())
    .join(' ');
  return text && hasReproductionHint(text) ? text : null;
}

export type DoneLine = 'issue' | 'queue' | 'staff' | 'retry' | 'soon';

/** Returns which line the sent page shows for the receipt, the most specific first */
export function doneLine(receipt?: ReportReceipt | null): DoneLine {
  if (!receipt) return 'soon';
  if (receipt.issueUrl) return 'issue';
  const states = [receipt.screening, receipt.publication];
  if (states.includes('waiting-ai-quota')) return 'queue';
  if (states.some((state) => STAFF_STATES.has(state))) return 'staff';
  if (
    receipt.publication === 'retryable' &&
    receipt.nextAttemptIn !== undefined
  )
    return 'retry';
  return 'soon';
}

/** Returns a wait as the limit notices say it */
export function waitText(ms: number) {
  if (ms < 60000) return say('time.wait.less');
  const minutes = Math.round(ms / 60000);
  return minutes <= 1 ? say('time.wait.one') : say('time.wait', { n: minutes });
}

/** Returns a time of day as the player's clock shows it */
export function clockText(date: Date) {
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** Returns the id of the line a picture's card shows, or null for one that's ready */
export function pictureLine(picture: {
  source: string;
  state: string;
  reason: string | null;
}): StringId | null {
  switch (picture.state) {
    case 'rendering':
      return 'shot.rendering';
    case 'waiting':
      return 'shot.waiting';
    case 'uploading':
      return 'shot.uploading';
    case 'processing':
      return 'shot.checking';
    case 'ready':
      return null;
  }
  if (picture.reason === 'nothing') return 'view.nothing';
  if (picture.reason === 'render') return 'view.failed';
  if (picture.reason === 'unconfirmed') return 'shot.unconfirmed';
  return 'shot.failed';
}

/** Whether a picture is still on its way, which holds sending */
export function onTheWay(picture: { state: string }) {
  return picture.state !== 'ready' && picture.state !== 'failed';
}
