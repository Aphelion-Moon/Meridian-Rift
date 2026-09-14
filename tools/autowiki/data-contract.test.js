import test from 'node:test';
import assert from 'node:assert/strict';
import { parseExport, compareExports, DATASETS, packageExport, readPackage } from './data-contract.js';
import { inspectPng } from './png.js';
import contract from './contract.json' with { type: 'json' };
import { FIELDS } from './fields.js';
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFUlEQVR4nGP8z8Dwn4GBgYEJRIAwAB8XAgICR7MUAAAAAElFTkSuQmCC', 'base64');
const fields = {
 entity: { name: 'Wrench', description: 'A wrench.', parent: '/obj/item', icon_source: 'icons/obj/tools.dmi', icon_state: 'wrench', appearance_scope: 'initial', icon_file: `entity-${'a'.repeat(32)}.png` },
 research_node: { display_name: 'Tools', prerequisite_nodes: [], unlocked_designs: [], research_costs: [] },
 design: { name: 'Wrench', build_path: '/obj/item/wrench', materials: [], construction_time: 32, unlocked_by: [] },
 reagent: { name: 'Water', description: 'Water.', metabolization_rate: 0.4, overdose_threshold: 0 },
 reaction: { results: [], required_reagents: [], required_catalysts: [], required_temp: 100, reaction_flags: 0 },
 crafting_recipe: { name: 'Wrench', result: '/obj/item/wrench', reqs: [], time: 30, tool_paths: [], tool_behaviors: [] },
 supply_pack: { name: 'Tools', cost: 100, contains: [], order_flags: 0 },
 job: { title: 'Engineer', paycheck: 50, config_tag: 'ENGINEER', job_flags: 1 },
};
for (const kind of DATASETS) fields[kind] ??= {};
for (const [kind, schema] of Object.entries(FIELDS)) for (const [field, types] of Object.entries(schema)) {
 if (kind === 'entity' && contract.optionalEntity.includes(field)) continue;
 if (!(field in fields[kind])) fields[kind][field] = types.includes('array') ? [] : types.includes('number') ? 0 : types.includes('string') ? 'example' : null;
}
function fixture() { return [{ kind: 'header', schema_version: 2, profile: 'source-defaults', time_unit: 'decisecond', appearance_profile: 'initial-south-first-frame' }, ...DATASETS.map(kind => ({ kind, id: kind === 'entity' ? '/obj/item/wrench' : `/datum/${kind}/example`, fields: structuredClone(fields[kind]) })), { kind: 'complete', counts: Object.fromEntries(DATASETS.map(kind => [kind, 1])) }]; }
const encode = rows => rows.map(x => JSON.stringify(x)).join('\n');
test('rejects incomplete output, omitted datasets and false completion counts', () => {
 const rows = fixture(); assert.equal(parseExport(encode(rows)).records.length, DATASETS.length);
 assert.throws(() => parseExport(encode(rows.slice(0, -1))), /incomplete/);
 const omitted = rows.filter(x => x.kind !== 'reaction'); assert.throws(() => parseExport(encode(omitted)), /Incomplete dataset/);
 rows.at(-1).counts.entity = 2; assert.throws(() => parseExport(encode(rows)), /Incomplete dataset/);
});
test('rejects unknown versions, duplicate identities, missing fields and unsafe filenames', () => {
 let rows = fixture(); rows[0].schema_version = 99; assert.throws(() => parseExport(encode(rows)), /contract/);
 rows = fixture(); rows.splice(2, 0, structuredClone(rows[1])); assert.throws(() => parseExport(encode(rows)), /Duplicate/);
 rows = fixture(); delete rows[1].fields.name; assert.throws(() => parseExport(encode(rows)), /Missing/);
 rows = fixture(); rows[1].fields.icon_file = '../../secret.png'; assert.throws(() => parseExport(encode(rows)), /filename/);
 rows = fixture(); rows[1].fields.secret = 'unexpected'; assert.throws(() => parseExport(encode(rows)), /Unknown/);
 rows = fixture(); rows[2].fields.research_costs = [{key:'science', value:{unexpected:1}}]; assert.throws(() => parseExport(encode(rows)), /Unsupported/);
 rows = fixture(); rows[3].fields.materials = ['untyped']; assert.throws(() => parseExport(encode(rows)), /list entry/);
});
test('record ordering and field ordering do not create semantic changes', () => {
 const rows = fixture(), previous = parseExport(encode(rows));
 const swapped = [rows[0], ...rows.slice(1, -1).reverse(), rows.at(-1)];
 assert.deepEqual(compareExports(previous, parseExport(encode(swapped))), { added: [], removed: [], changed: [] });
 swapped.find(row => row.kind === 'job').fields.paycheck = 75;
 assert.deepEqual(compareExports(previous, parseExport(encode(swapped))).changed, ['job:/datum/job/example']);
});
test('validates PNG integrity beyond the header', () => {
 assert.deepEqual(inspectPng(png), { width: 2, height: 2 });
 assert.throws(() => inspectPng(png.subarray(0, 24)));
 const damaged = Buffer.from(png); damaged[45] ^= 1; assert.throws(() => inspectPng(damaged));
 assert.throws(() => inspectPng(Buffer.concat([png, Buffer.from('trailing')])));
 assert.throws(() => inspectPng(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jY9sAAAAASUVORK5CYII=', 'base64')));
});
test('packages only a complete asset inventory and never overwrites a prior package', async t => {
 const root = await fs.mkdtemp(path.join(os.tmpdir(), 'meridian-data-test-'));
 t.after(async () => { if (path.dirname(root) !== path.resolve(os.tmpdir()) || !path.basename(root).startsWith('meridian-data-test-')) throw new Error('Unsafe test cleanup'); await fs.rm(root, { recursive: true }); });
 const icons = path.join(root, 'icons'), input = path.join(root, 'data.jsonl'), output = path.join(root, 'package');
 await fs.mkdir(icons); await fs.writeFile(input, encode(fixture())); await fs.writeFile(path.join(icons, fields.entity.icon_file), png);
 const result = await packageExport(input, icons, output, 'a'.repeat(40)); assert.equal(result.icons, 1);
 const manifest = JSON.parse(await fs.readFile(path.join(output, 'manifest.json'))); assert.equal(manifest.datasets.length, DATASETS.length); assert.equal(manifest.units.time, 'decisecond');
 assert.equal(manifest.publicationReady, false);
 assert.deepEqual(await fs.readFile(path.join(output, 'icons', fields.entity.icon_file)), png);
 assert.equal((await readPackage(output)).records.length,DATASETS.length);
 const oldDataset=await fs.readFile(path.join(output,'job.jsonl'));
 await fs.appendFile(path.join(output,'job.jsonl'),' ');
 await assert.rejects(readPackage(output),/size/);
 await fs.writeFile(path.join(output,'job.jsonl'),oldDataset);
 await assert.rejects(packageExport(input, icons, output, 'a'.repeat(40)), /exist/);
 await fs.writeFile(path.join(icons, 'unexpected.png'), png);
 await assert.rejects(packageExport(input, icons, path.join(root, 'second'), 'a'.repeat(40)), /unmanifested/);
});

test('profile assets remain tied to qualified record metadata and complete image bytes', async t => {
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'meridian-profile-test-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const rows=fixture(),name='appearance-'+ 'b'.repeat(32)+'.png';
 rows[1].fields.render_profiles=[{key:'worn-layer-south',value:Object.entries({file:name,source:'icons/mob/clothing/test.dmi',state:'test',scope:'Equipment layer without wearer'}).map(([key,value])=>({key,value}))}];
 const icons=path.join(root,'icons'),input=path.join(root,'data.jsonl'),output=path.join(root,'package');await fs.mkdir(icons);await fs.writeFile(input,encode(rows));await fs.writeFile(path.join(icons,fields.entity.icon_file),png);await fs.writeFile(path.join(icons,name),png);
 assert.equal((await packageExport(input,icons,output,'a'.repeat(40))).icons,2);assert.equal((await readPackage(output)).manifest.icons.length,2);
 const manifestPath=path.join(output,'manifest.json'),manifest=JSON.parse(await fs.readFile(manifestPath));manifest.icons.find(i=>i.filename===name).scope='Unqualified replacement';await fs.writeFile(manifestPath,JSON.stringify(manifest));await assert.rejects(readPackage(output),/differs/);
 rows[1].fields.render_profiles.push(structuredClone(rows[1].fields.render_profiles[0]));assert.throws(()=>parseExport(encode(rows)),/profile/);
});
