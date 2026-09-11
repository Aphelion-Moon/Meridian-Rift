import { promises as fs } from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { Mwn } from 'mwn';

export const API_URL = 'https://meridian-wiki.a13.info/api.php';
export const GENERATED_TITLES = [
  'Fish', 'Fish/Bait', 'Fish/Evolution', 'Fish/Hook', 'Fish/Line',
  'Fish/Lure', 'Fish/Rod', 'Fish/Scan', 'Fish/Source', 'Fish/Trait',
  'SoupRecipes', 'StockParts', 'Surgeries', 'Techweb',
  'Techweb/Experimental', 'VendingMachines',
].map((name) => `Template:Autowiki/Content/${name}`);
const WARNING = '<noinclude><b>This page is automated by Autowiki. Do NOT edit it manually.</b></noinclude>';
const PNG_SIGNATURE = Buffer.from('89504e470d0a1a0a', 'hex');
const sha1 = (bytes) => createHash('sha1').update(bytes).digest('hex');
const normalizeTitle = (title) => title.replaceAll('_', ' ');
// Match MediaWiki TextContent normalization and Parser's removal of NULs.
const normalizeWikitext = (text) => text.replaceAll('\0', '').replace(/\r\n?/g, '\n').replace(/[ \t\n\v]+$/g, '');

export function readConfig(env, publish = false) {
  if (env.WIKI_API_URL !== API_URL) {
    throw new Error(`WIKI_API_URL must explicitly equal ${API_URL}`);
  }
  const sourceSha = env.SOURCE_SHA || env.GITHUB_SHA;
  if (!/^[a-f0-9]{40}$/i.test(sourceSha || '')) {
    throw new Error('SOURCE_SHA or GITHUB_SHA must identify the 40-character source commit');
  }
  if (publish && (!env.USERNAME || !env.PASSWORD)) {
    throw new Error('USERNAME and PASSWORD are required for publication');
  }
  return { apiUrl: API_URL, sourceSha: sourceSha.toLowerCase() };
}

// Complete validation precedes login and every write. Inputs belong only to the generator.
export async function loadManifest(editFilename, imageDirectory) {
  const raw = await fs.readFile(editFilename, 'utf8');
  if (Buffer.byteLength(raw) > 16 * 1024 * 1024) throw new Error('Page manifest exceeds 16 MiB');
  const seen = new Set();
  const pages = raw.split(/\r?\n/).filter((line) => line.trim()).map((line) => {
    const page = JSON.parse(line);
    if (!GENERATED_TITLES.includes(page.title) || seen.has(page.title)) {
      throw new Error(`Unexpected or duplicate generated title: ${page.title}`);
    }
    if (typeof page.text !== 'string' || !page.text.trim() || Buffer.byteLength(page.text) > 2 * 1024 * 1024) {
      throw new Error(`Invalid generated content: ${page.title}`);
    }
    seen.add(page.title);
    return { title: page.title, text: normalizeWikitext(WARNING + page.text) };
  });
  if (seen.size !== GENERATED_TITLES.length) throw new Error('Incomplete generated page manifest');
  const names = (await fs.readdir(imageDirectory)).sort();
  if (!names.length || names.length > 5000) throw new Error('Unexpected generated image count');
  const images = [];
  const imageNames = new Set();
  for (const name of names) {
    if (!name.endsWith('.png') || /[\x00-\x1f<>:"/\\|?*]/.test(name)) {
      throw new Error(`Invalid generated image name: ${name}`);
    }
    const filename = path.resolve(imageDirectory, name);
    const stat = await fs.lstat(filename);
    if (!stat.isFile() || stat.size > 1024 * 1024) throw new Error(`Invalid generated image: ${name}`);
    const bytes = await fs.readFile(filename);
    if (bytes.length < 24 || !bytes.subarray(0, 8).equals(PNG_SIGNATURE)) {
      throw new Error(`Image is not a PNG: ${name}`);
    }
    const title = `File:Autowiki-${name}`;
    const key = normalizeTitle(title);
    if (imageNames.has(key)) throw new Error(`Duplicate normalized image name: ${name}`);
    imageNames.add(key);
    images.push({ title, filename, sha1: sha1(bytes), size: bytes.length });
  }
  return { pages, images };
}

export async function snapshot(bot, titles) {
  const records = new Map();
  for (let offset = 0; offset < titles.length; offset += 50) {
    const result = await bot.request({
      action: 'query', titles: titles.slice(offset, offset + 50).join('|'),
      prop: 'revisions|imageinfo', rvprop: 'ids|content', rvslots: 'main',
      iiprop: 'sha1', formatversion: 2,
    });
    if (!Array.isArray(result.query?.pages)) throw new Error('Invalid wiki snapshot response');
    for (const page of result.query.pages) {
      records.set(normalizeTitle(page.title), {
        revision: page.revisions?.[0]?.revid || 0,
        text: page.revisions?.[0]?.slots?.main?.content || '',
        sha1: page.imageinfo?.[0]?.sha1 || null,
      });
    }
  }
  return records;
}

export async function buildPlan(bot, manifest, config) {
  const current = await snapshot(bot, [...manifest.pages, ...manifest.images].map((entry) => entry.title));
  const before = (title) => {
    const entry = current.get(normalizeTitle(title));
    if (!entry) throw new Error(`Wiki omitted requested title: ${title}`);
    return entry;
  };
  return {
    version: 1, apiUrl: config.apiUrl, sourceSha: config.sourceSha,
    checkedAt: new Date().toISOString(),
    pages: manifest.pages.map((page) => ({ ...page, before: before(page.title), changed: page.text !== before(page.title).text })),
    images: manifest.images.map((image) => ({ ...image, before: before(image.title), changed: image.sha1 !== before(image.title).sha1 })),
  };
}

export async function writeReport(plan, reportDirectory) {
  await fs.mkdir(reportDirectory, { recursive: true });
  await fs.writeFile(path.join(reportDirectory, 'plan.json'), JSON.stringify(plan, null, 2) + '\n');
  const changedPages = plan.pages.filter((page) => page.changed);
  const diff = changedPages.map((page) => [
    `--- before/${page.title}`, `+++ after/${page.title}`,
    `@@ -1,${page.before.text.split('\n').length} +1,${page.text.split('\n').length} @@`,
    ...page.before.text.split('\n').map((line) => `-${line}`),
    ...page.text.split('\n').map((line) => `+${line}`),
  ].join('\n')).join('\n\n');
  await fs.writeFile(path.join(reportDirectory, 'pages.diff'), diff + '\n');
  const summary = {
    sourceSha: plan.sourceSha, pages: plan.pages.length, images: plan.images.length,
    changedPages: changedPages.length, changedImages: plan.images.filter((image) => image.changed).length,
  };
  await fs.writeFile(path.join(reportDirectory, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
  return summary;
}

export async function publishPlan(bot, plan, reportDirectory) {
  if (plan.apiUrl !== API_URL) throw new Error('Invalid publication destination');
  const identity = (await bot.request({ action: 'query', meta: 'userinfo', uiprop: 'groups|rights' })).query.userinfo;
  if (!identity?.id || !identity.groups?.includes('bot') || identity.groups.some((group) => ['sysop', 'bureaucrat', 'interface-admin'].includes(group))) {
    throw new Error('Publication requires a dedicated non-administrator account in the bot group');
  }
  // Recheck every planned page before uploading anything. API baserevid protects each subsequent edit.
  const latest = await snapshot(bot, plan.pages.map((page) => page.title));
  for (const page of plan.pages) {
    if (latest.get(normalizeTitle(page.title))?.revision !== page.before.revision) {
      throw new Error(`Page changed since planning: ${page.title}`);
    }
  }
  const completed = { sourceSha: plan.sourceSha, username: identity.name, images: [], pages: [] };
  const record = () => fs.writeFile(path.join(reportDirectory, 'published.json'), JSON.stringify(completed, null, 2) + '\n');
  await record();
  // Files first. Their revision history preserves replaced images if a later operation fails.
  for (const image of plan.images.filter((entry) => entry.changed)) {
    const bytes = await fs.readFile(image.filename);
    if (sha1(bytes) !== image.sha1) throw new Error(`Image changed since planning: ${image.title}`);
    const latestImage = (await snapshot(bot, [image.title])).get(normalizeTitle(image.title));
    if (latestImage.sha1 === image.sha1) continue;
    if (latestImage.sha1 !== image.before.sha1) throw new Error(`Image changed on wiki: ${image.title}`);
    const upload = await bot.upload(image.filename, image.title.substring('File:'.length),
      `Generated from Meridian-Rift commit ${plan.sourceSha}.`, {
        comment: `Autowiki image from ${plan.sourceSha}`, ignorewarnings: true, assert: 'user',
      });
    if (upload.result !== 'Success') throw new Error(`Upload did not succeed: ${image.title}`);
    completed.images.push(image.title);
    await record();
  }
  for (const page of plan.pages.filter((entry) => entry.changed)) {
    const result = await bot.save(page.title, page.text, `Autowiki data from ${plan.sourceSha}`, {
      bot: true, assert: 'user', watchlist: 'nochange',
      ...(page.before.revision ? { baserevid: page.before.revision, nocreate: true } : { createonly: true }),
    });
    if (result.result !== 'Success') throw new Error(`Edit did not succeed: ${page.title}`);
    completed.pages.push({ title: page.title, revision: result.newrevid });
    await record();
  }
  completed.finishedAt = new Date().toISOString();
  await record();
  return completed;
}

export async function main(args = process.argv.slice(2), env = process.env) {
  const publish = args.includes('--publish');
  const config = readConfig(env, publish || args.includes('--check-config'));
  if (args.includes('--check-config')) return;
  const positional = args.filter((arg) => !['--publish', '--dry-run'].includes(arg));
  if (positional.length !== 3) throw new Error('Usage: node autowiki.js <edits.jsonl> <image-directory> <report-directory> [--dry-run|--publish]');
  if (args.includes('--publish') && args.includes('--dry-run')) throw new Error('Choose either dry-run or publish');
  const manifest = await loadManifest(positional[0], positional[1]);
  const bot = new Mwn({
    apiUrl: config.apiUrl, silent: true, maxRetries: 3, retryPause: 5000,
    userAgent: 'MeridianAutowiki/2.0 (https://github.com/Aphelion-Moon/Meridian-Rift)',
    defaultParams: { maxlag: 5, formatversion: 2 },
    ...(publish ? { username: env.USERNAME, password: env.PASSWORD } : {}),
  });
  bot.setRequestOptions({ timeout: 30000, maxRedirects: 0 });
  if (publish) await bot.login();
  const plan = await buildPlan(bot, manifest, config);
  console.log(JSON.stringify(await writeReport(plan, positional[2])));
  if (publish) await publishPlan(bot, plan, positional[2]);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    // Do not dump client error objects: they can contain request headers and credentials.
    let message = error.code ? `API error: ${error.code}` : error.message;
    for (const secret of [process.env.PASSWORD, process.env.USERNAME].filter(Boolean)) message = message.replaceAll(secret, '[redacted]');
    console.error(message);
    process.exitCode = 1;
  });
}
