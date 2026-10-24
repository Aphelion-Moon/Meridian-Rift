// THIS IS AN APHELION UI FILE

import { expect, test } from 'bun:test';
import {
  copyMode,
  type Decision,
  mustWrite,
  selectorNeeds,
} from './style-copy';

const HTML = 'http://www.w3.org/1999/xhtml';
const SVG = 'http://www.w3.org/2000/svg';
const html = (tag: string) => ({ namespace: HTML, tag });

/** One property's decision, the SVG's own value the frame gave included */
const decision = (overrides: Partial<Decision>): Decision => ({
  name: 'color',
  live: 'rgb(240, 231, 206)',
  parent: 'rgb(240, 231, 206)',
  predicted: 'rgb(240, 231, 206)',
  ...overrides,
});

test('a rule is filed under its rightmost compound: its id, else a class, else its tag', () => {
  expect(selectorNeeds('.Button')).toEqual([
    { key: 'class:Button', part: 'self', nested: false },
  ]);
  expect(selectorNeeds('.theme-x .Section > .Section__title')[0].key).toBe(
    'class:Section__title',
  );
  expect(selectorNeeds('div#main.Window')[0].key).toBe('id:main');
  expect(selectorNeeds('TABLE tr')[0].key).toBe('tag:tr');
  expect(selectorNeeds('.a:not(.b):hover')[0].key).toBe('class:a');
  expect(selectorNeeds('[title="a > b"] .c')[0].key).toBe('class:c');
  expect(selectorNeeds('.a, .b').map((need) => need.key)).toEqual([
    'class:a',
    'class:b',
  ]);
});

test('a rule we cannot pin to one class, id or tag could match any element', () => {
  expect(selectorNeeds(':is(.a, .b)')[0].key).toBeNull();
  expect(selectorNeeds('*')[0].key).toBeNull();
  expect(selectorNeeds('[data-x]')[0].key).toBeNull();
  expect(selectorNeeds(':nth-child(2n+1 of .x)')[0].key).toBeNull();
  // Escapes and slotted elements are past what we parse, so they count for the element and both pseudo-elements
  expect(selectorNeeds('.\\31 23')[0]).toEqual({
    key: null,
    part: 'any',
    nested: false,
  });
  expect(selectorNeeds('::slotted(span)')[0].part).toBe('any');
});

test("a pseudo-element's rule is filed for that pseudo-element, the legacy one-colon spelling too", () => {
  expect(selectorNeeds('.Window::before')[0]).toEqual({
    key: 'class:Window',
    part: 'before',
    nested: false,
  });
  expect(selectorNeeds('.fa-check:before')[0].part).toBe('before');
  expect(selectorNeeds('.Tab::after:hover')[0].part).toBe('after');
  expect(selectorNeeds('.Input::placeholder')[0].part).toBe('other');
  expect(selectorNeeds('&:hover')[0]).toEqual({
    key: null,
    part: 'self',
    nested: true,
  });
});

test('a property the frame shows inherited is left out where it equals the parent, and written where it differs', () => {
  expect(mustWrite(decision({}))).toBe(false);
  expect(
    mustWrite(
      decision({ live: 'rgb(255, 0, 0)', predicted: decision({}).parent }),
    ),
  ).toBe(true);
});

test('a property the SVG would give its UA default is left out at that default and written anywhere else', () => {
  const display = { name: 'display', parent: 'flex', predicted: 'block' };
  expect(mustWrite(decision({ ...display, live: 'block' }))).toBe(false);
  expect(mustWrite(decision({ ...display, live: 'flex' }))).toBe(true);
});

test("a property the frame can't answer for is written", () => {
  expect(mustWrite(decision({ predicted: undefined }))).toBe(true);
});

test('a font size is left to inheritance only when the tag takes its parent font size unchanged', () => {
  const size = {
    name: 'font-size',
    live: '12px',
    parent: '12px',
    predicted: '12px',
  };
  expect(mustWrite(decision({ ...size, inheritsFontSize: true }))).toBe(false);
  // A form control's UA size can match its parent's without following it, and the SVG would draw it unshrunk
  expect(mustWrite(decision({ ...size, inheritsFontSize: false }))).toBe(true);
  expect(
    mustWrite(decision({ ...size, live: '10px', inheritsFontSize: true })),
  ).toBe(true);
});

test('a pseudo-element always carries its content and font size, and leaves out what its element gives it', () => {
  expect(
    mustWrite(decision({ name: 'content', live: '""', predicted: '""' }), true),
  ).toBe(true);
  expect(
    mustWrite(
      decision({
        name: 'font-size',
        live: '12px',
        parent: '12px',
        predicted: '12px',
        inheritsFontSize: true,
      }),
      true,
    ),
  ).toBe(true);
  expect(mustWrite(decision({}), true)).toBe(false);
});

test("a colour that follows the element's own colour is left out only while it still matches that colour", () => {
  const border = { name: 'border-top-color', predicted: 'rgb(1, 2, 3)' };
  expect(
    mustWrite(
      decision({ ...border, live: 'rgb(9, 9, 9)', ownColor: 'rgb(9, 9, 9)' }),
    ),
  ).toBe(false);
  expect(
    mustWrite(
      decision({ ...border, live: 'rgb(0, 0, 0)', ownColor: 'rgb(9, 9, 9)' }),
    ),
  ).toBe(true);
});

test("a border width the frame zeroed for its style none is written once the element's style isn't none", () => {
  const width = {
    name: 'border-top-width',
    live: '0px',
    parent: '0px',
    predicted: '0px',
    predictedStyle: 'none',
  };
  expect(mustWrite(decision({ ...width, ownStyle: 'none' }))).toBe(false);
  expect(mustWrite(decision({ ...width, ownStyle: 'solid' }))).toBe(true);
});

test('the root, an element in a UA state and a clone of another tag copy everything, as html-to-image did', () => {
  expect(copyMode(html('div'), 'div', null, false, false)).toBe('whole');
  expect(copyMode(html('div'), 'div', html('body'), true, false)).toBe('whole');
  expect(copyMode(html('img'), 'canvas', html('div'), false, false)).toBe(
    'whole',
  );
  expect(
    copyMode(
      { namespace: SVG, tag: 'path' },
      'path',
      html('div'),
      false,
      false,
    ),
  ).toBe('whole');
  expect(copyMode(html('tr'), 'tr', html('table'), false, false)).toBe('whole');
});

test('form controls, lists and cells of a table with presentational attributes write what styles them, unasked', () => {
  for (const tag of ['input', 'textarea', 'button', 'select', 'ul', 'ol'])
    expect(copyMode(html(tag), tag, html('div'), false, false)).toBe('as-is');
  expect(copyMode(html('td'), 'td', html('tr'), false, true)).toBe('as-is');
  expect(copyMode(html('td'), 'td', html('tr'), false, false)).toBe('predict');
  expect(
    copyMode({ namespace: SVG, tag: 'svg' }, 'svg', html('span'), false, false),
  ).toBe('predict');
  expect(copyMode(html('div'), 'div', html('div'), false, false)).toBe(
    'predict',
  );
});

test('a minimum size an author sets is written even where the frame reads the same, since only layout resolves auto', () => {
  expect(
    mustWrite(
      decision({
        name: 'min-width',
        live: '0px',
        parent: '0px',
        predicted: '0px',
      }),
    ),
  ).toBe(true);
});
