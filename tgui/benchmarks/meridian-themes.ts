/** Run from tgui/: bun benchmarks/meridian-themes.ts [output-directory] [bundle-directory] */
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { cpus } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { gzipSync } from 'node:zlib';
import { compileAsync } from 'sass-embedded';
import {
  MERIDIAN_BASE_THEME_IDS,
  resolveMeridianTheme,
} from '../packages/tgui/constants/meridian-theme';
import { getLobbyMenuTheme } from '../packages/tgui-lobby/menuTheme';

const root = resolve(import.meta.dir, '..');
const output = resolve(Bun.argv[2] ?? '../tmp/meridian-theme-bench/current');
const bundleRoot = resolve(Bun.argv[3] ?? join(root, 'public'));
const samples = 7;
await mkdir(output, { recursive: true });

function distribution(values: number[]) {
  const sorted = [...values].sort((a, b) => a - b);
  return {
    min: sorted[0],
    median: sorted[Math.floor(sorted.length / 2)],
    max: sorted.at(-1),
    samples: values,
  };
}

function sizes(text: string) {
  return {
    bytes: Buffer.byteLength(text),
    gzipBytes: gzipSync(text).byteLength,
  };
}

// Timing deliberately excludes reporting, gzip, imports, and setup.
function measure(operation: (index: number) => number) {
  const iterations = 100_000;
  let checksum = 0;
  const times: number[] = [];
  for (let sample = -1; sample < samples; sample++) {
    const started = performance.now();
    for (let index = 0; index < iterations; index++)
      checksum += operation(index);
    if (sample >= 0)
      times.push(((performance.now() - started) * 1_000) / iterations);
  }
  return { microsecondsPerCall: distribution(times), iterations, checksum };
}

const runtime = {
  resolution: measure((index) => {
    const result = resolveMeridianTheme({
      requested: index % 3 ? 'nanotrasen' : 'paper extra-class',
      preferred:
        MERIDIAN_BASE_THEME_IDS[index % MERIDIAN_BASE_THEME_IDS.length],
    });
    return result.base.length + result.classes.length;
  }),
  lobbyMetadata: measure((index) => {
    const theme =
      MERIDIAN_BASE_THEME_IDS[index % MERIDIAN_BASE_THEME_IDS.length];
    const menu = getLobbyMenuTheme(theme);
    return menu.heading.length + Number(menu.treatment === 'instrument');
  }),
};

const styles: Record<string, unknown> = {};
for (const bundle of ['tgui', 'tgui-lobby']) {
  const times: number[] = [];
  let css = '';
  for (let sample = -1; sample < samples; sample++) {
    const started = performance.now();
    const result = await compileAsync(
      join(root, 'packages', bundle, 'styles/main.scss'),
      {
        importers: [
          {
            findFileUrl(url) {
              if (!url.startsWith('~')) return null;
              return pathToFileURL(
                join(
                  root,
                  'node_modules',
                  url === '~tgui-core/styles'
                    ? 'tgui-core/styles/main.scss'
                    : url.slice(1),
                ),
              );
            },
          },
        ],
      },
    );
    if (sample >= 0) times.push(performance.now() - started);
    css = result.css;
  }
  await writeFile(join(output, `${bundle}.css`), css);
  styles[bundle] = { compileMilliseconds: distribution(times), ...sizes(css) };
}

const bundles: Record<string, unknown> = {};
for (const name of ['tgui', 'tgui-lobby']) {
  for (const extension of ['css', 'js']) {
    const filename = `${name}.bundle.${extension}`;
    const text = await readFile(join(bundleRoot, filename), 'utf8');
    await writeFile(join(output, filename), text);
    if (extension === 'js') {
      bundles[filename] = sizes(text);
      continue;
    }
    const urls = [...text.matchAll(/url\((['"]?)(data:[^\s)]*?)\1\)/g)].map(
      (match) => match[2],
    );
    const occurrences = new Map<string, number>();
    for (const url of urls)
      occurrences.set(url, (occurrences.get(url) ?? 0) + 1);
    const uniqueBytes = [...occurrences.keys()].reduce(
      (total, url) => total + Buffer.byteLength(url),
      0,
    );
    const inlineBytes = urls.reduce(
      (total, url) => total + Buffer.byteLength(url),
      0,
    );
    bundles[filename] = {
      ...sizes(text),
      inlineBytes,
      repeatedInlineBytes: inlineBytes - uniqueBytes,
      inlineOccurrences: urls.length,
      uniqueInlineAssets: occurrences.size,
      largestInlineAssets: [...occurrences]
        .map(([url, count]) => ({
          mime: url.slice(
            5,
            url.indexOf(';') > 0 ? url.indexOf(';') : url.indexOf(','),
          ),
          bytes: Buffer.byteLength(url),
          count,
        }))
        .sort((a, b) => b.bytes * b.count - a.bytes * a.count)
        .slice(0, 8),
    };
  }
}

const report = {
  date: new Date().toISOString(),
  bun: Bun.version,
  cpu: cpus()[0]?.model,
  platform: process.platform,
  samples,
  note: 'One warm-up per case. Sass timings include compiler startup. Production bundles must be freshly built. Gzip is a size comparison, not a claim about BYOND transport. No browser rendering is measured.',
  runtime,
  styles,
  bundles,
};
await writeFile(
  join(output, 'results.json'),
  `${JSON.stringify(report, null, 2)}\n`,
);
console.log(JSON.stringify(report, null, 2));
