import test from 'node:test';
import assert from 'node:assert/strict';
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { API_URL, GENERATED_TITLES, readConfig, loadManifest, buildPlan, writeReport, publishPlan } from './autowiki.js';

const config = { apiUrl: API_URL, sourceSha: 'a'.repeat(40) };
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jY9sAAAAASUVORK5CYII=', 'base64');
async function fixture(t) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'meridian-autowiki-'));
  t.after(async () => {
    const resolved = path.resolve(directory);
    if (path.dirname(resolved) !== path.resolve(os.tmpdir()) || !path.basename(resolved).startsWith('meridian-autowiki-')) throw new Error('Unsafe test cleanup path');
    await fs.rm(resolved, { recursive: true });
  });
  const images = path.join(directory, 'images');
  await fs.mkdir(images);
  const edits = path.join(directory, 'edits.jsonl');
  await fs.writeFile(edits, GENERATED_TITLES.map((title) => JSON.stringify({ title, text: `Data for ${title}` })).join('\n'));
  await fs.writeFile(path.join(images, 'test.png'), png);
  return { directory, images, edits };
}
function fakeWiki(manifest, { identical = false, groups = ['bot'], revision = 1 } = {}) {
  const writes = [];
  const records = new Map([
    ...manifest.pages.map((page) => [page.title, { title: page.title, revisions: [{ revid: revision, slots: { main: { content: identical ? page.text : 'old text' } } }] }]),
    ...manifest.images.map((image) => [image.title, { title: image.title, imageinfo: identical ? [{ sha1: image.sha1 }] : [] }]),
  ]);
  return {
    writes, records,
    request: async (params) => params.meta === 'userinfo'
      ? { query: { userinfo: { id: 8, name: 'MeridianAutowiki', groups } } }
      : { query: { pages: params.titles.split('|').map((title) => records.get(title)) } },
    upload: async (...args) => { writes.push(['upload', ...args]); return { result: 'Success' }; },
    save: async (...args) => { writes.push(['save', ...args]); return { result: 'Success', newrevid: 2 }; },
  };
}

test('requires the exact destination and a source revision before any network work', () => {
  for (const url of [undefined, 'https://wiki.tgstation13.org/api.php', API_URL + '?redirect=1', 'http://meridian-wiki.a13.info/api.php']) {
    assert.throws(() => readConfig({ WIKI_API_URL: url, SOURCE_SHA: config.sourceSha }), /WIKI_API_URL/);
  }
  assert.throws(() => readConfig({ WIKI_API_URL: API_URL }), /source commit/);
  assert.deepEqual(readConfig({ WIKI_API_URL: API_URL, SOURCE_SHA: config.sourceSha }), config);
  assert.throws(() => readConfig({ WIKI_API_URL: API_URL, SOURCE_SHA: config.sourceSha }, true), /USERNAME and PASSWORD/);
});
test('validates a complete manifest; rejects missing and duplicate datasets', async (t) => {
  const f = await fixture(t);
  assert.equal((await loadManifest(f.edits, f.images)).pages.length, 16);
  const text = await fs.readFile(f.edits, 'utf8');
  await fs.writeFile(f.edits, text.split('\n').slice(1).join('\n'));
  await assert.rejects(loadManifest(f.edits, f.images), /Incomplete/);
  await fs.writeFile(f.edits, text + '\n' + text.split('\n')[0]);
  await assert.rejects(loadManifest(f.edits, f.images), /duplicate/);
});
test('rejects human-page targets and invalid image data', async (t) => {
  const f = await fixture(t);
  const text = await fs.readFile(f.edits, 'utf8');
  await fs.writeFile(f.edits, text.replace(GENERATED_TITLES[0], 'Main Page'));
  await assert.rejects(loadManifest(f.edits, f.images), /Unexpected/);
  await fs.writeFile(f.edits, text);
  await fs.writeFile(path.join(f.images, 'test.png'), '<html>not a PNG</html>');
  await assert.rejects(loadManifest(f.edits, f.images), /not a PNG/);
});
test('dry-run produces review files and performs no writes', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest);
  const plan = await buildPlan(bot, manifest, config);
  const summary = await writeReport(plan, f.directory);
  assert.equal(summary.changedPages, 16);
  assert.equal(summary.changedImages, 1);
  assert.equal(bot.writes.length, 0);
  assert.equal(JSON.parse(await fs.readFile(path.join(f.directory, 'plan.json'))).sourceSha, config.sourceSha);
});
test('skips unchanged content and images', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest, { identical: true });
  await publishPlan(bot, await buildPlan(bot, manifest, config), f.directory);
  assert.deepEqual(bot.writes, []);
});
test('uploads files before pages and supplies revision conflict guards', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest);
  const result = await publishPlan(bot, await buildPlan(bot, manifest, config), f.directory);
  assert.equal(bot.writes[0][0], 'upload');
  assert.ok(bot.writes.slice(1).every(([action, title, text, summary, options]) => action === 'save' && options.baserevid === 1 && options.nocreate && summary.includes(config.sourceSha)));
  assert.equal(result.pages.length, 16);
  assert.ok(result.finishedAt);
});
test('rejects administrator or non-bot credentials without writing', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  for (const groups of [['user'], ['bot', 'sysop'], ['bot', 'bureaucrat'], ['bot', 'interface-admin']]) {
    const bot = fakeWiki(manifest, { groups });
    await assert.rejects(publishPlan(bot, await buildPlan(bot, manifest, config), f.directory), /dedicated non-administrator/);
    assert.equal(bot.writes.length, 0);
  }
});
test('refuses stale page plans before uploading', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest);
  const plan = await buildPlan(bot, manifest, config);
  bot.records.get(manifest.pages[0].title).revisions[0].revid++;
  await assert.rejects(publishPlan(bot, plan, f.directory), /changed since planning/);
  assert.equal(bot.writes.length, 0);
});
test('refuses modified local images after preview', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest);
  const plan = await buildPlan(bot, manifest, config);
  await fs.appendFile(path.join(f.images, 'test.png'), 'changed');
  await assert.rejects(publishPlan(bot, plan, f.directory), /Image changed since planning/);
  assert.equal(bot.writes.length, 0);
});
test('upload errors prevent page publication and leave a progress record', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest);
  bot.upload = async () => { throw new Error('upload failed'); };
  await assert.rejects(publishPlan(bot, await buildPlan(bot, manifest, config), f.directory), /upload failed/);
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(f.directory, 'published.json'))).pages, []);
});
test('CLI failures are nonzero and do not dump credentials', () => {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('./autowiki.js', import.meta.url)), '--publish'], {
    env: { ...process.env, WIKI_API_URL: 'https://wrong.example/api.php', PASSWORD: 'private-test-value' },
    encoding: 'utf8', windowsHide: true,
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /WIKI_API_URL/);
  assert.ok(!result.stderr.includes('private-test-value'));
});

test('refuses conflicting remote image changes before uploading', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest);
  const plan = await buildPlan(bot, manifest, config);
  bot.records.get(manifest.images[0].title).imageinfo = [{ sha1: 'different-editor-image' }];
  await assert.rejects(publishPlan(bot, plan, f.directory), /Image changed on wiki/);
  assert.equal(bot.writes.length, 0);
});

test('creates missing pages without overwriting a page created concurrently', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest, { revision: 0 });
  await publishPlan(bot, await buildPlan(bot, manifest, config), f.directory);
  assert.ok(bot.writes.filter(([action]) => action === 'save').every((entry) => entry[4].createonly && !entry[4].baserevid));
});

test('a non-success upload response stops publication', async (t) => {
  const f = await fixture(t);
  const manifest = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(manifest);
  bot.upload = async () => ({ result: 'Warning' });
  await assert.rejects(publishPlan(bot, await buildPlan(bot, manifest, config), f.directory), /Upload did not succeed/);
  assert.equal(bot.writes.length, 0);
});

test('MediaWiki whitespace normalization does not cause repeated publication', async (t) => {
  const f = await fixture(t);
  const original = await loadManifest(f.edits, f.images);
  const bot = fakeWiki(original, { identical: true });
  const input = (await fs.readFile(f.edits, 'utf8')).split('\n').map(line => {
    const page = JSON.parse(line);
    page.text += '\0\r\n \t';
    return JSON.stringify(page);
  }).join('\n');
  await fs.writeFile(f.edits, input);
  const manifest = await loadManifest(f.edits, f.images);
  const plan = await buildPlan(bot, manifest, config);
  assert.ok(plan.pages.every(page => !page.changed));
  await publishPlan(bot, plan, f.directory);
  assert.deepEqual(bot.writes, []);
});
