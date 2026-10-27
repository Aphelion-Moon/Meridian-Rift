// THIS IS AN APHELION UI FILE

import { expect, test } from 'bun:test';
import { type DrawnFace, drawnFontFaces } from './font-faces';

/** A face as the page's FontFaceSet holds it, its descriptors as a FontFace reads them back */
function face(
  family: string,
  status: FontFaceLoadStatus,
  weight = 'normal',
  style = 'normal',
  unicodeRange = 'U+0-10FFFF',
): DrawnFace {
  return { family, status, weight, style, stretch: 'normal', unicodeRange };
}

/** A @font-face rule's style, '' for every descriptor it leaves out as a CSSStyleDeclaration reads them */
function rule(descriptors: Record<string, string>) {
  return {
    style: { getPropertyValue: (name: string) => descriptors[name] ?? '' },
  };
}

/** Whether each rule goes in, so no DOM object ever reaches expect() */
function kept(faces: DrawnFace[], rules: ReturnType<typeof rule>[]) {
  const filter = drawnFontFaces(new Set(faces));
  return filter ? rules.map((each) => filter(each)) : 'no filter';
}

test("a face the page never loaded stays out, and one it loaded, is loading or couldn't load goes in", () => {
  const faces = [
    face('Icons', 'unloaded', '400'),
    face('Icons', 'loaded', '900'),
    face('Body', 'loading'),
    face('Broken', 'error'),
  ];
  const rules = [
    rule({ 'font-family': 'Icons', 'font-weight': '400' }),
    rule({ 'font-family': 'Icons', 'font-weight': '900' }),
    rule({ 'font-family': 'Body' }),
    rule({ 'font-family': 'Broken' }),
  ];
  expect(kept(faces, rules)).toEqual([false, true, true, true]);
});

test('a rule finds its face through quotes, spaces and the descriptors it leaves at their defaults', () => {
  const faces = [face('Font Awesome 6 Free', 'unloaded')];
  const rules = [
    rule({ 'font-family': ' "Font Awesome 6 Free"' }),
    rule({
      'font-family': "'Font Awesome 6 Free'",
      'font-weight': 'normal',
      'unicode-range': 'U+0-10FFFF',
    }),
  ];
  expect(kept(faces, rules)).toEqual([false, false]);
});

test('a rule no face answers goes in as before', () => {
  const faces = [face('Icons', 'unloaded', '400')];
  const rules = [
    rule({ 'font-family': 'Elsewhere' }),
    rule({ 'font-family': 'Icons', 'font-weight': '700' }),
    rule({
      'font-family': 'Icons',
      'font-weight': '400',
      'font-style': 'italic',
    }),
  ];
  expect(kept(faces, rules)).toEqual([true, true, true]);
});

test('rules with the same descriptors all go in when any face of theirs was loaded, whichever the set lists first', () => {
  const rules = [
    rule({ 'font-family': 'Twin' }),
    rule({ 'font-family': 'Twin' }),
  ];
  expect(
    kept([face('Twin', 'unloaded'), face('Twin', 'loaded')], rules),
  ).toEqual([true, true]);
  expect(
    kept([face('Twin', 'loaded'), face('Twin', 'unloaded')], rules),
  ).toEqual([true, true]);
});

test('faces of one family split by unicode-range are kept or left out each by its own load', () => {
  const faces = [
    face('Legacy', 'unloaded'),
    face('Legacy', 'loaded', 'normal', 'normal', 'U+F041, U+F047'),
    face('Legacy', 'unloaded', 'normal', 'normal', 'U+F003'),
  ];
  const rules = [
    rule({ 'font-family': 'Legacy' }),
    rule({ 'font-family': 'Legacy', 'unicode-range': 'U+F041, U+F047' }),
    rule({ 'font-family': 'Legacy', 'unicode-range': 'U+F003' }),
  ];
  expect(kept(faces, rules)).toEqual([false, true, false]);
});

test('an unloaded part-range face stays in unless a face of its style, weight and stretch drew', () => {
  const faces = [
    face('Pair', 'loaded', '400'),
    face('Pair', 'unloaded', '700', 'normal', 'U+400-4FF'),
    face('Pair', 'loaded', '900', 'normal', 'U+0-FF'),
    face('Pair', 'unloaded', '900', 'normal', 'U+100-24F'),
    face('Pair', 'unloaded', '900', 'italic', 'U+100-24F'),
  ];
  const rules = [
    rule({ 'font-family': 'Pair', 'font-weight': '400' }),
    rule({
      'font-family': 'Pair',
      'font-weight': '700',
      'unicode-range': 'U+400-4FF',
    }),
    rule({
      'font-family': 'Pair',
      'font-weight': '900',
      'unicode-range': 'U+0-FF',
    }),
    rule({
      'font-family': 'Pair',
      'font-weight': '900',
      'unicode-range': 'U+100-24F',
    }),
    rule({
      'font-family': 'Pair',
      'font-weight': '900',
      'font-style': 'italic',
      'unicode-range': 'U+100-24F',
    }),
  ];
  expect(kept(faces, rules)).toEqual([true, true, true, false, true]);
});

test('a family that drew nothing leaves out its part-range faces too', () => {
  const faces = [
    face('Legacy', 'unloaded'),
    face('Legacy', 'unloaded', 'normal', 'normal', 'U+F003'),
    face('Legacy', 'unloaded', '700', 'normal', 'U+F041'),
  ];
  const rules = [
    rule({ 'font-family': 'Legacy' }),
    rule({ 'font-family': 'Legacy', 'unicode-range': 'U+F003' }),
    rule({
      'font-family': 'Legacy',
      'font-weight': '700',
      'unicode-range': 'U+F041',
    }),
  ];
  expect(kept(faces, rules)).toEqual([false, false, false]);
});

test('without a FontFaceSet there is no filter', () => {
  expect(drawnFontFaces(undefined)).toBeNull();
});
