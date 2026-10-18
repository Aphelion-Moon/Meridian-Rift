// THIS IS AN APHELION UI FILE
import { beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { compileAsync } from 'sass-embedded';

import { MERIDIAN_BASE_THEME_IDS } from '../../../constants/theme';

/** The stylesheets under test live one level up from this directory. */
const styleRoot = join(import.meta.dir, '..');

type Rule = {
  selectors: string[];
  body: string;
  /** The at-rule the rule sits in, if any. */
  within?: string;
};

/** The rules of compiled CSS, with the at-rule each sits in; keyframe steps come out as rules too. */
function rulesOf(css: string): Rule[] {
  const rules: Rule[] = [];
  const blocks: { prelude: string; start: number }[] = [];
  let preludeStart = 0;
  for (let at = 0; at < css.length; at++) {
    if (css[at] === '{') {
      blocks.push({
        prelude: css.slice(preludeStart, at).trim(),
        start: at + 1,
      });
      preludeStart = at + 1;
    } else if (css[at] === '}') {
      const block = blocks.pop();
      if (block && !block.prelude.startsWith('@')) {
        rules.push({
          selectors: block.prelude
            .split(',')
            .map((selector) => selector.trim()),
          body: css.slice(block.start, at),
          within: blocks.at(-1)?.prelude,
        });
      }
      preludeStart = at + 1;
    } else if (css[at] === ';' && blocks.length === 0) {
      preludeStart = at + 1;
    }
  }
  return rules;
}

const declared = (rule: Rule, property: string) =>
  rule.body.match(new RegExp(`(?:^|[;\\s])${property}:\\s*([^;]+);`))?.[1];

let arrivalRules: Rule[];
let keyframes: Set<string>;
let preferencesRules: Rule[];

beforeAll(async () => {
  const [arrival, preferences] = await Promise.all(
    ['_portrait-arrival.scss', '_preferences.scss'].map(
      async (file) => (await compileAsync(join(styleRoot, file))).css,
    ),
  );
  arrivalRules = rulesOf(arrival);
  keyframes = new Set(
    [...arrival.matchAll(/@keyframes\s+([\w-]+)/g)].map((match) => match[1]),
  );
  preferencesRules = rulesOf(preferences);
});

describe('portrait arrivals', () => {
  it('give every theme an arrival for both the species chamber and the character preview', () => {
    for (const id of MERIDIAN_BASE_THEME_IDS) {
      const rule = arrivalRules.find(
        (candidate) =>
          !candidate.within &&
          candidate.selectors.includes(
            `.theme-${id} .SpecimenViewer__figure`,
          ) &&
          candidate.selectors.includes(
            `.theme-${id} .CharacterPreview__arrival`,
          ),
      );
      expect(rule, id).toBeDefined();
      // Highline is accessibility first, and stays still on purpose.
      const animation = declared(rule as Rule, 'animation');
      expect(animation === 'none', id).toBe(id === 'meridian_highline');
    }
  });

  it('hold every portrait on its last frame, which letting go moves at fractional zoom', () => {
    const portraits = arrivalRules.filter(
      (rule) =>
        !rule.within &&
        rule.selectors.some((selector) =>
          selector.endsWith(' .CharacterPreview__arrival'),
        ),
    );
    for (const rule of portraits) {
      const animation = declared(rule, 'animation') ?? '';
      if (animation === 'none') {
        continue;
      }
      for (const layer of animation.split(/,(?![^(]*\))/)) {
        expect(layer.trim().split(/\s+/), rule.selectors[0]).toContain('both');
      }
    }
  });

  it('only play keyframes that exist', () => {
    const played = arrivalRules.flatMap((rule) => {
      const animation =
        declared(rule, 'animation') ?? declared(rule, 'animation-name');
      if (!animation || animation.startsWith('none')) {
        return [];
      }
      // Each layer's name is its one word that isn't a time, a fill or a timing function.
      return animation.split(/,(?![^(]*\))/).map((layer) =>
        layer
          .replace(/\([^)]*\)/g, '')
          .trim()
          .split(/\s+/)
          .find((word) => keyframes.has(word)),
      );
    });
    expect(played.length).toBeGreaterThan(MERIDIAN_BASE_THEME_IDS.length);
    expect(played).not.toContain(undefined);
  });

  it('never animate the preview canvas, which the pan moves and body size transforms', () => {
    const canvasRules = preferencesRules.filter((rule) =>
      rule.selectors.some((selector) =>
        /\.CharacterPreview__figure$/.test(selector),
      ),
    );
    for (const rule of canvasRules) {
      expect(
        declared(rule, 'animation'),
        rule.selectors.join(', '),
      ).toBeUndefined();
    }
  });

  it('stand still for reduced motion', () => {
    const still = arrivalRules.find(
      (rule) =>
        rule.within === '@media (prefers-reduced-motion: reduce)' &&
        rule.selectors.includes('.CharacterPreview__arrival') &&
        rule.selectors.includes('.SpecimenViewer__figure') &&
        rule.selectors.includes('.CharacterPreview__sweep::before'),
    );
    expect(still && declared(still, 'animation')).toBe('none !important');
  });
});
