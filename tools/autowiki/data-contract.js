import { promises as fs } from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { appearanceProfiles } from './appearances.js';
import { inspectPng } from './png.js';
import { validateFields } from './fields.js';
import { verifyProvenance } from './provenance.js';

import contract from './contract.json' with { type: 'json' };
export const DATASETS = Object.keys(contract.fields);
const LEGACY = contract.legacyDatasets;
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
export function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  return value;
}
export function parseExport(raw) {
  if (Buffer.byteLength(raw) > 256 * 1024 * 1024) throw new Error('Export exceeds 256 MiB');
  const lines = raw.split(/\r?\n/).filter(x => x.trim()).map(x => JSON.parse(x));
  const header = lines.shift(), complete = lines.pop();
  if (header?.kind !== 'header' || ![1,2].includes(header.schema_version) || header.profile !== 'source-defaults' || header.time_unit !== 'decisecond' || header.appearance_profile !== 'initial-south-first-frame') throw new Error('Unknown export contract');
  if (complete?.kind !== 'complete' || !complete.counts || Array.isArray(complete.counts)) throw new Error('Export is incomplete');
  if (lines.length > 150000) throw new Error('Export record limit exceeded');
  const expectedDatasets = header.schema_version === 1 ? LEGACY : DATASETS;
  const counts = Object.fromEntries(expectedDatasets.map(kind => [kind, 0])), seen = new Set();
  for (const record of lines) {
    const { kind, id, fields } = record;
    if (!expectedDatasets.includes(kind) || typeof id !== 'string' || !id.startsWith('/') || id.length > 1024 || /[\x00-\x1f]/.test(id) || !fields || typeof fields !== 'object' || Array.isArray(fields)) throw new Error('Invalid data record');
    if (seen.has(`${kind}:${id}`)) throw new Error(`Duplicate data identity: ${kind}:${id}`);
    seen.add(`${kind}:${id}`); counts[kind]++;
    validateFields(kind, fields);if(kind==='entity')appearanceProfiles(record);
    if (kind === 'entity' && fields.icon_file !== null && !/^entity-[0-9a-f]{32}\.png$/.test(fields.icon_file)) throw new Error('Invalid entity asset filename');
    // Publication is data-only. Dynamic HTML, callbacks and live world objects are outside this contract.
    if (Buffer.byteLength(JSON.stringify(fields)) > 1024 * 1024) throw new Error(`Oversized record: ${id}`);
  }
  if (Object.keys(complete.counts).some(kind => !DATASETS.includes(kind))) throw new Error('Unknown trailer dataset');
  for (const kind of expectedDatasets) if (!counts[kind] || counts[kind] !== complete.counts[kind]) throw new Error(`Incomplete dataset: ${kind}`);
  return { header, counts, records: lines.map(canonical).sort((a, b) => `${a.kind}:${a.id}`.localeCompare(`${b.kind}:${b.id}`, 'en')) };
}

export function compareExports(previous, current) {
  const old = new Map(previous.records.map(r => [`${r.kind}:${r.id}`, r]));
  const next = new Map(current.records.map(r => [`${r.kind}:${r.id}`, r]));
  return {
    added: [...next.keys()].filter(id => !old.has(id)),
    removed: [...old.keys()].filter(id => !next.has(id)),
    changed: [...next.keys()].filter(id => old.has(id) && JSON.stringify(canonical(old.get(id))) !== JSON.stringify(canonical(next.get(id)))),
  };
}

export async function readPackage(directory) {
  const manifestFile=path.join(directory,'manifest.json'),manifestStat=await fs.lstat(manifestFile);if(!manifestStat.isFile()||manifestStat.size>64*1024*1024)throw new Error('Invalid manifest size');
  const manifest = JSON.parse(await fs.readFile(manifestFile, 'utf8'));
  if (![1,2].includes(manifest.schemaVersion) || manifest.profile !== 'source-defaults' || !/^[0-9a-f]{40}$/.test(manifest.source?.commit || '')) throw new Error('Invalid package manifest');
  if (!Array.isArray(manifest.datasets) || manifest.datasets.length !== (manifest.schemaVersion === 1 ? LEGACY : DATASETS).length) throw new Error('Incomplete package manifest');
  const records = [], counts = {}, seen = new Set(); let total = 0;
  for (const dataset of manifest.datasets) {
    if (!DATASETS.includes(dataset.kind) || seen.has(dataset.kind) || dataset.filename !== `${dataset.kind}.jsonl`) throw new Error('Invalid package dataset');
    seen.add(dataset.kind);
    const filename = path.join(directory, dataset.filename), stat = await fs.lstat(filename);
    total += stat.size;
    if (!stat.isFile() || total > 256 * 1024 * 1024 || stat.size !== dataset.bytes) throw new Error('Invalid package size');
    const bytes = await fs.readFile(filename);
    if (sha256(bytes) !== dataset.sha256) throw new Error('Dataset checksum mismatch');
    const lines = bytes.toString('utf8').trim().split('\n').map(line => JSON.parse(line));
    if (lines.some(record => record.kind !== dataset.kind)) throw new Error('Misfiled data record');
    records.push(...lines); counts[dataset.kind] = dataset.count;
  }
  const header = {kind:'header',schema_version:manifest.schemaVersion,profile:'source-defaults',time_unit:'decisecond',appearance_profile:'initial-south-first-frame'};
  const parsed = parseExport([header,...records,{kind:'complete',counts}].map(row=>JSON.stringify(row)).join('\n'));
  if (manifest.source.repository !== 'Aphelion-Moon/Meridian-Rift' || !Array.isArray(manifest.icons) || !Array.isArray(manifest.unresolvedIcons)) throw new Error('Invalid asset manifest');
  const assets = new Map(), profiles = new Map(parsed.records.filter(r=>r.kind==='entity').flatMap(appearanceProfiles).map(p=>[p.filename,p])), entities = new Map(parsed.records.filter(r => r.kind === 'entity').map(r => [r.id,r.fields]));
  if(profiles.size!==parsed.records.filter(r=>r.kind==='entity').flatMap(appearanceProfiles).length)throw new Error('Duplicate profile filename');
  for (const icon of manifest.icons) {
    const profile=profiles.get(icon.filename);
    if(assets.has(icon.filename))throw new Error('Duplicate asset identity');
    if(profile){if(['entity','appearanceProfile','source','state','scope'].some(field=>icon[field]!==profile[field]))throw new Error('Appearance identity differs from its record');}
    else if (!/^entity-[0-9a-f]{32}\.png$/.test(icon.filename) || entities.get(icon.entity)?.icon_file !== icon.filename || icon.appearanceProfile !== 'initial-south-first-frame') throw new Error('Invalid asset identity');
    const file = path.join(directory,'icons',icon.filename), stat = await fs.lstat(file);
    if (!stat.isFile() || stat.size > 4*1024*1024 || stat.size !== icon.bytes) throw new Error('Invalid asset size');
    const bytes = await fs.readFile(file), size = inspectPng(bytes);
    if (sha256(bytes) !== icon.sha256 || size.width !== icon.width || size.height !== icon.height) throw new Error('Asset checksum or dimensions mismatch');
    assets.set(icon.filename,icon);
  }
  for (const fields of entities.values()) if (fields.icon_file && !assets.has(fields.icon_file)) throw new Error('Missing referenced asset');
  for(const filename of profiles.keys())if(!assets.has(filename))throw new Error('Missing appearance asset');
  const actual = await fs.readdir(path.join(directory,'icons'));
  if (actual.length !== assets.size || actual.some(name => !assets.has(name))) throw new Error('Unmanifested package asset');
  return {manifest,...parsed};
}

export async function packageExport(input, iconDirectory, output, sourceSha, repository = 'Aphelion-Moon/Meridian-Rift', provenance = null) {
  if (!/^[0-9a-f]{40}$/.test(sourceSha || '')) throw new Error('An exact source commit is required');
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository)) throw new Error('Invalid source repository');
  const parsed = parseExport(await fs.readFile(input, 'utf8'));
  const icons = new Map();
  const unresolved = [];
  for (const record of parsed.records.filter(r => r.kind === 'entity')) {
    const name = record.fields.icon_file;
    if (!name) { unresolved.push({ id: record.id, reason: record.fields.icon_status || 'no-exported-icon' }); continue; }
    if (icons.has(name)) throw new Error(`Duplicate entity icon identity: ${name}`);
    const filename = path.resolve(iconDirectory, name), stat = await fs.lstat(filename);
    if (!stat.isFile() || stat.size > 4 * 1024 * 1024) throw new Error(`Invalid asset: ${name}`);
    const bytes = await fs.readFile(filename);
    let dimensions;
    try { dimensions = inspectPng(bytes); } catch (error) { throw new Error(`Invalid asset ${name} (${record.id}): ${error.message}`); }
    icons.set(name, { filename: name, entity: record.id, sha256: sha256(bytes), bytes: bytes.length, ...dimensions, source: record.fields.icon_source, state: record.fields.icon_state, greyscaleConfig: record.fields.greyscale_config, greyscaleColors: record.fields.greyscale_colors, color: record.fields.color, appearanceProfile: parsed.header.appearance_profile });
  }
  for(const profile of parsed.records.filter(r=>r.kind==='entity').flatMap(appearanceProfiles)){
    if(icons.has(profile.filename))throw new Error('Duplicate profile asset');
    const filename=path.join(iconDirectory,profile.filename),stat=await fs.lstat(filename);if(!stat.isFile()||stat.size>4*1024*1024)throw new Error('Invalid profile file');
    const bytes=await fs.readFile(filename),dimensions=inspectPng(bytes);icons.set(profile.filename,{...profile,sha256:sha256(bytes),bytes:bytes.length,...dimensions});
  }
  const actual = (await fs.readdir(iconDirectory)).sort();
  if (actual.length !== icons.size || actual.some(name => !icons.has(name))) throw new Error('Entity icon directory contains unmanifested files');
  // Never overwrite a prior package; a completed manifest is the atomic publication marker.
  await fs.mkdir(output, { recursive: false });
  await fs.mkdir(path.join(output, 'icons'));
  for (const icon of icons.values()) {
    const bytes = await fs.readFile(path.join(iconDirectory, icon.filename));
    if (sha256(bytes) !== icon.sha256) throw new Error(`Asset changed during packaging: ${icon.filename}`);
    await fs.writeFile(path.join(output, 'icons', icon.filename), bytes);
  }
  const datasets = [];
  for (const kind of Object.keys(parsed.counts)) {
    const records = parsed.records.filter(r => r.kind === kind);
    const text = records.map(r => JSON.stringify(r)).join('\n') + '\n';
    const filename = `${kind}.jsonl`;
    await fs.writeFile(path.join(output, filename), text);
    datasets.push({ kind, filename, count: records.length, sha256: sha256(text), bytes: Buffer.byteLength(text) });
  }
  const manifest = { schemaVersion: parsed.header.schema_version, source: { repository, commit: sourceSha }, profile: parsed.header.profile, units: { time: 'decisecond', reactionTemperature: 'kelvin', reagentVolume: 'unit', cargoCost: 'base-credit-cost-before-economy-modifiers' }, datasets, icons: [...icons.values()], unresolvedIcons: unresolved, limitations: ['Initial entity appearances can differ after initialization, components, equipment, overlays, randomized variants and round state.', 'Reaction hooks, crafting checks and cargo fill overrides can add behavior beyond the exported fields.', 'Job defaults are not wiki policy or a guarantee of live server eligibility.'] };
  manifest.provenance = provenance;
  manifest.execution = { compiler: parsed.header.compiler ?? null, runtime: parsed.header.runtime ?? null };
  manifest.publicationReady = Boolean(provenance && provenance.commit === sourceSha && !provenance.dirty);
  await fs.writeFile(path.join(output, 'manifest.json'), JSON.stringify(canonical(manifest), null, 2) + '\n');
  return { counts: parsed.counts, icons: icons.size, unresolvedIcons: unresolved.length, output };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const [input, icons, output, provenanceFile] = process.argv.slice(2);
  if (!input || !icons || !output) throw new Error('Usage: node data-contract.js <data.jsonl> <entity-icons> <new-package-directory>');
  if (!provenanceFile) throw new Error('A generation provenance file is required');
  const provenance = verifyProvenance(provenanceFile);
  const sha = process.env.SOURCE_SHA || process.env.GITHUB_SHA || provenance.commit;
  if (sha !== provenance.commit) throw new Error('Requested commit differs from generation checkout');
  packageExport(input, icons, output, sha, process.env.GITHUB_REPOSITORY || 'Aphelion-Moon/Meridian-Rift', provenance).then(result => console.log(JSON.stringify(result))).catch(error => { console.error(error.message); process.exitCode = 1; });
}
