import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { finalize } from './cli.mjs';
import { validate, summarize, compare, query, csv } from './analysis.mjs';

const capture = () => ({ schema_version: 1, provenance: { capture_id: 'test' }, coverage: { status: 'complete', scope: 'test', limitations: [] }, quality: {}, models: [], evidence: [], observations: { nodes: [
  { id: 1, kind: 'datum', type: '/datum/a', length: 2, estimated_bytes: null },
  { id: 2, kind: 'list', type: '/list', length: 10, estimated_bytes: 100 },
  { id: 3, kind: 'list', type: '/list', length: 10, estimated_bytes: 100 },
], edges: [{ owner: 0, target: 1, field: 'ROOT' }, { owner: 1, target: 2, field: 'a' }, { owner: 1, target: 2, field: 'b' }, { owner: 1, target: 3, field: 'equal-independent' }] } });

test('shared identity contributes once; equal independent lists remain separate', () => {
  const lists = summarize(capture()).find(r => r.key === '/list');
  assert.equal(lists.count, 2); assert.equal(lists.shared, 1); assert.equal(lists.estimated_bytes, 200);
  assert.equal(summarize(capture(), 'field').filter(r => r.key.endsWith('.a'))[0].count, 1);
});
test('numeric sort, nulls last, zero baseline and capture-local removed IDs', () => {
  assert.deepEqual(query([{ key: 'a', paths: [], count: 20 }, { key: 'b', paths: [], count: 100 }, { key: 'c', paths: [], count: null }], { sort: [{ key: 'count', direction: -1 }] }).map(r => r.key), ['b', 'a', 'c']);
  const a = capture(), b = capture(); b.observations.nodes[0].type = '/datum/new';
  const delta = compare(a, b); assert.equal(delta.find(r => r.key === '/datum/new').percent, null);
  assert.equal(delta.find(r => r.key === '/datum/a').comparison_source, 'baseline');
});
test('malformed graphs and unsupported versions rejected; future fields accepted', () => {
  assert.throws(() => validate({ ...capture(), schema_version: 5 }), /Unsupported/);
  const c = capture(); c.observations.edges[0].target = 99; assert.throws(() => validate(c), /edge/);
  assert.throws(() => validate({ ...capture(), quality: null }), /quality/);
  assert.doesNotThrow(() => validate({ ...capture(), future_field: true }));
});
test('pathological path amplification is bounded and cycles terminate offline', () => {
  const c = capture(); c.observations.nodes = []; c.observations.edges = [];
  for (let id = 1; id <= 10000; id++) { c.observations.nodes.push({ id, type: '/datum/chain', kind: 'datum', length: 1, estimated_bytes: null }); c.observations.edges.push({ owner: id - 1, target: id, field: 'x'.repeat(1000) }); }
  c.observations.edges.push({ owner: 10000, target: 1, field: 'cycle' });
  const rows = summarize(c, 'instance'); assert.equal(rows.length, 10000); assert.ok(rows.every(r => r.paths[0].length <= 512));
});
test('interrupted output remains readable, sequence and footer mismatches rejected', () => {
  const header = JSON.stringify({ record: 'header', schema_version: 1, sequence: 1, provenance: { capture_id: 'transport' }, scope: 'test', roots: [] });
  assert.equal(finalize(header + '\n{"record":').coverage.status, 'interrupted');
  assert.throws(() => finalize(header + '\n' + header), /sequence/);
  assert.throws(() => finalize(header + '\n' + JSON.stringify({ record: 'footer', sequence: 2, nodes: 1, edges: 0, retained_references: 0 })), /counts/);
});
test('CSV neutralizes spreadsheet formulas', () => assert.match(csv([{ key: '=HYPERLINK("x")' }]), /'=/));

const actual = process.env.MEMORY_FIXTURE;
test('actual BYOND fixture: identity, list keys and values, numeric alists, privacy and cleanup', { skip: !actual }, () => {
  const raw = fs.readFileSync(actual, 'utf8'); const c = finalize(raw);
  assert.equal(c.quality.retained_references, 0);
  assert.equal(c.coverage.status, 'partial'); assert.equal(c.coverage.reason, 'bounded_scope');
  assert.ok(!raw.includes('private game text') && !raw.includes('secret key') && !raw.includes('secret value'));
  const edges = c.observations.edges;
  const shared = edges.filter(e => e.field === 'shared'); assert.equal(shared.length, 2); assert.equal(shared[0].target, shared[1].target);
  assert.notEqual(edges.find(e => e.field === 'equal_independent').target, shared[0].target);
  const cycle = edges.find(e => e.field === 'self_cycle').target; assert.ok(edges.some(e => e.owner === cycle && e.target === cycle));
  const keyed = edges.find(e => e.field === 'keys_and_values').target;
  assert.ok(edges.some(e => e.owner === keyed && e.field.endsWith(':key')));
  assert.ok(edges.some(e => e.owner === keyed && e.field.endsWith(':value')));
  const alist = edges.find(e => e.field === 'numeric_keys').target; assert.ok(edges.some(e => e.owner === alist && e.field.endsWith(':value')));
});
