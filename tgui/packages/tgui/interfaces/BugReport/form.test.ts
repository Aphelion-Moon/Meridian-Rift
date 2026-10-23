// THIS IS AN APHELION UI FILE

import { describe, expect, test } from 'bun:test';
import {
  checkAll,
  checkPage,
  clockText,
  doneLine,
  fromWire,
  isBlank,
  joinSteps,
  type LocalFields,
  lengthOf,
  pictureLine,
  splitSteps,
  toWire,
  vagueSteps,
  waitText,
} from './form';

const limits = {
  title: 160,
  text: 8000,
  steps: 20,
  reports: 5,
  sends: 10,
  uploads: 5,
};
const filled: LocalFields = {
  title: 'Airlock stays shut',
  steps: ['Walk to the airlock', 'Click it'],
  expected: 'It opens',
  category: '',
  severity: '',
};

describe('what counts as empty', () => {
  // The same table DM's bug_report_blank() is tested with
  const empty = ['', ' ', '\t\r\n', ' ', '　', ' ', '﻿'];
  test('whitespace of every kind and the BOM are empty', () => {
    for (const text of [...empty, '\u0085'])
      expect([text, isBlank(text)]).toEqual([text, true]);
  });
  test('a letter or a zero-width space is something', () => {
    expect(isBlank('a')).toBe(false);
    expect(isBlank('​')).toBe(false);
  });
  test('every blank field holds its page, whatever the blank is made of', () => {
    for (const text of empty) {
      const fields = { ...filled, title: text, steps: [text], expected: text };
      expect(checkAll(fields, limits).map((error) => error.field)).toEqual([
        'title',
        'steps',
        'expected',
      ]);
    }
  });
});

describe('the steps on the wire', () => {
  test('they join as numbered lines without the blank ones', () => {
    expect(joinSteps(['Open the door', '  ', ' Walk in ', ''])).toBe(
      '1. Open the door\n2. Walk in',
    );
    expect(joinSteps(['', ' '])).toBe('');
  });
  test('a saved draft comes back as one field per step', () => {
    expect(splitSteps('1. Open the door\n2. Walk in', 20)).toEqual([
      'Open the door',
      'Walk in',
    ]);
    expect(splitSteps('', 20)).toEqual(['']);
    // Older free text keeps its words, in the step it follows
    expect(splitSteps('I opened it\nthen it broke\n2. Walk in', 20)).toEqual([
      'I opened it then it broke',
      'Walk in',
    ]);
    expect(splitSteps('1.\n2. Walk in', 20)).toEqual(['Walk in']);
  });
  test('no more fields come back than the window offers', () => {
    const lines = Array.from({ length: 22 }, (_, index) => `${index + 1}. s`);
    const steps = splitSteps(lines.join('\n'), 20);
    expect(steps.length).toBe(20);
    expect(steps[19]).toBe('s s s');
  });
  test('a round trip keeps the steps and leaves skipped questions to DM', () => {
    const wire = toWire(filled);
    expect(wire).toEqual({
      title: 'Airlock stays shut',
      expected: 'It opens',
      reproduction: '1. Walk to the airlock\n2. Click it',
      category: 'Other',
      severity: 'unspecified',
    });
    expect(fromWire(wire, 20)).toEqual(filled);
    expect(fromWire({ ...wire, category: 'UI' }, 20).category).toBe('UI');
  });
});

describe('page checks', () => {
  test('a filled form passes and only pages 1 and 3 check anything', () => {
    expect(checkAll(filled, limits)).toEqual([]);
    expect(checkPage(2, { ...filled, title: '' }, limits)).toEqual([]);
    expect(checkPage(4, { ...filled, title: '' }, limits)).toEqual([]);
  });
  test('over the limit says by how much, in characters as DM counts them', () => {
    const emoji = '\u{1F600}';
    expect(lengthOf(emoji.repeat(3))).toBe(3);
    expect(
      checkPage(1, { ...filled, title: emoji.repeat(160) }, limits),
    ).toEqual([]);
    expect(
      checkPage(1, { ...filled, title: 'x'.repeat(161) }, limits)[0]?.text,
    ).toBe("That's 1 character too long.");
    expect(
      checkPage(3, { ...filled, expected: 'x'.repeat(8012) }, limits)[0]?.text,
    ).toBe("That's 12 characters too long.");
  });
  test('only a whole known phrase as the steps asks for more', () => {
    expect(vagueSteps({ ...filled, steps: ["doesn't work", ''] })).toBe(
      "doesn't work",
    );
    expect(vagueSteps(filled)).toBe(null);
  });
});

describe('the sent page and the waits', () => {
  test('the receipt picks the most specific line', () => {
    const receipt = { screening: 'passed', publication: 'published' };
    expect(doneLine(null)).toBe('soon');
    expect(doneLine({ ...receipt, issueUrl: 'https://github.com/x/y/1' })).toBe(
      'issue',
    );
    expect(
      doneLine({ screening: 'waiting-ai-quota', publication: 'not-queued' }),
    ).toBe('queue');
    expect(
      doneLine({ screening: 'quarantine', publication: 'not-queued' }),
    ).toBe('staff');
    expect(
      doneLine({ ...receipt, publication: 'retryable', nextAttemptIn: 60000 }),
    ).toBe('retry');
    expect(doneLine({ screening: 'pending', publication: 'not-queued' })).toBe(
      'soon',
    );
  });
  test('waits read as people say them', () => {
    expect(waitText(20000)).toBe('under a minute');
    expect(waitText(70000)).toBe('a minute');
    expect(waitText(23 * 60000)).toBe('23 minutes');
    expect(clockText(new Date(2026, 9, 23, 9, 5))).toBe('09:05');
  });
  test('each picture state and refusal has its own line', () => {
    const line = (state: string, reason: string | null = null) =>
      pictureLine({ source: 'view', state, reason });
    expect(line('rendering')).toBe('shot.rendering');
    expect(line('processing')).toBe('shot.checking');
    expect(line('ready')).toBe(null);
    expect(line('failed', 'nothing')).toBe('view.nothing');
    expect(line('failed', 'render')).toBe('view.failed');
    expect(line('failed', 'unconfirmed')).toBe('shot.unconfirmed');
    expect(line('failed', 'invalid')).toBe('shot.failed');
  });
});
