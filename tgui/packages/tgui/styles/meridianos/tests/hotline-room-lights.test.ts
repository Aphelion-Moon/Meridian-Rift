// THIS IS AN APHELION UI FILE
import { beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { compileAsync } from 'sass-embedded';

/** The stylesheets under test live one level up from this directory. */
const styleRoot = join(import.meta.dir, '..');

/**
 * WCAG 2.3.1: nothing flashes more than three times in any one second. A flash
 * is a pair of opposite changes, so no lit or dark step of a light may be
 * shorter than a sixth of a second.
 */
const SHORTEST_STEP_MS = 1000 / 6;

/** Each @keyframes' offsets (0 to 1) at which it sets an opacity, in order. */
function opacityOffsets(css: string) {
  const found = new Map<string, number[]>();
  for (const [, name, body] of css.matchAll(
    /@keyframes\s+([\w-]+)\s*\{((?:[^{}]*\{[^{}]*\})*)\s*\}/g,
  )) {
    const offsets = new Set<number>();
    for (const [, selectors, declarations] of body.matchAll(
      /([^{}]+)\{([^{}]*)\}/g,
    )) {
      if (!/(?:^|[;\s])opacity\s*:/.test(declarations)) {
        continue;
      }
      for (const selector of selectors.split(',').map((s) => s.trim())) {
        offsets.add(
          selector === 'from'
            ? 0
            : selector === 'to'
              ? 1
              : Number.parseFloat(selector) / 100,
        );
      }
    }
    found.set(
      name,
      [...offsets].sort((a, b) => a - b),
    );
  }
  return found;
}

/** A time in ms, from `1.44s`, `.4s` or `680ms`. */
const msOf = (time: string) =>
  time.endsWith('ms')
    ? Number.parseFloat(time)
    : Number.parseFloat(time) * 1000;

let css: string;

beforeAll(async () => {
  css = (await compileAsync(join(styleRoot, 'markings-room', '_hotline.scss')))
    .css;
});

describe("Hotline's markings room", () => {
  it('lights its neons no faster than three flashes a second', () => {
    const keyframes = opacityOffsets(css);
    // Every layer of every animation the room plays that steps its opacity.
    const played = [...css.matchAll(/(?:^|[;\s{])animation\s*:\s*([^;}]+)/g)]
      .flatMap(([, animation]) => animation.split(/,(?![^(]*\))/))
      .flatMap((layer) => {
        const words = layer.trim().split(/\s+/);
        const name = words.find((word) => keyframes.has(word)) ?? '';
        const offsets = keyframes.get(name) ?? [];
        const time = words.find((word) => /^[\d.]+m?s$/.test(word));
        return offsets.length > 1 && time
          ? [{ name, offsets, duration: msOf(time) }]
          : [];
      });
    expect(played.length).toBeGreaterThan(0);
    for (const { name, offsets, duration } of played) {
      const shortest = Math.min(
        ...offsets.slice(1).map((offset, i) => offset - offsets[i]),
      );
      expect(shortest * duration, name).toBeGreaterThanOrEqual(
        SHORTEST_STEP_MS,
      );
    }
  });
});
