import { describe, expect, it } from 'bun:test';
import { DISPLAY_GRADE_REFERENCE as reference } from './display-grade';
import { installDisplayGrade } from './display-grade-bootstrap';
import { createGradePreview } from './display-grade-preview';

describe('display grade window lifecycle', () => {
  it('grades the whole document once, bypasses neutral editors, and removes resources', () => {
    const page = document.implementation.createHTMLDocument();
    page.body.innerHTML = '<main>content</main><div id="portal">tooltip</div>';
    const update = installDisplayGrade(page);
    expect(page.querySelector('svg')).toBeNull();
    for (let revision = 0; revision < 20; revision++) {
      expect(update({ revision, settings: reference })).toBe(true);
      expect(page.querySelectorAll('filter').length).toBe(1);
      expect(page.documentElement.style.filter).toContain(
        'aphelion-display-grade-root',
      );
      expect(page.querySelector('#portal')?.parentElement).toBe(page.body);
    }
    update({ revision: 20, settings: reference, neutral: true });
    expect(page.querySelector('svg')).toBeNull();
    expect(page.documentElement.style.filter).toBe('');
    // A pooled editor becomes an ordinary UI again at a later revision.
    update({ revision: 21, settings: reference });
    expect(page.querySelectorAll('filter').length).toBe(1);
    expect(update({ revision: 20, settings: null })).toBe(false);
    update({ revision: 22, settings: { ...reference, strength: 0 } });
    expect(page.querySelector('svg')).toBeNull();
    update({ revision: 23, settings: null });
    expect(page.documentElement.style.filter).toBe('');
  });

  it('rejects malformed packets without consuming a valid revision or affecting another page', () => {
    const first = document.implementation.createHTMLDocument();
    const second = document.implementation.createHTMLDocument();
    const update = installDisplayGrade(first);
    installDisplayGrade(second);
    expect(
      update({
        revision: 1,
        settings: { ...reference, shadow_color: '<script>' },
      }),
    ).toBe(false);
    expect(update({ revision: NaN, settings: reference })).toBe(false);
    expect(update({ revision: 1, settings: reference })).toBe(true);
    expect(update({ revision: 1, settings: null })).toBe(false);
    expect(second.querySelector('svg')).toBeNull();
    expect(second.documentElement.style.filter).toBe('');
  });
});

describe('display grade preview lifecycle', () => {
  it('coalesces drags, sends the final value, and invalidates pending work on close', async () => {
    const sent: [number, number, number][] = [];
    const preview = createGradePreview<number>((value, sequence) =>
      sent.push([value, sequence, Date.now()]),
    );
    preview.queue(1);
    preview.queue(2);
    preview.queue(3);
    expect(sent.map(([value]) => value)).toEqual([1]);
    await Bun.sleep(120);
    expect(sent.map(([value, sequence]) => [value, sequence])).toEqual([
      [1, 1],
      [3, 2],
    ]);
    expect(sent[1][2] - sent[0][2]).toBeGreaterThanOrEqual(95);
    preview.queue(4);
    preview.close();
    preview.queue(5);
    await Bun.sleep(120);
    expect(sent.length).toBe(2);
  });
});
