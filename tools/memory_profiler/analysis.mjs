// Shared by the local worker, CLI and Node contract tests. No network or DOM access.
export const VERSION = 1;
export const MAX_BYTES = 16 * 1024 * 1024;
const integer = (v) => Number.isSafeInteger(v) && v >= 0;
const text = (v) => typeof v === 'string' && v.length <= 1024;
const fail = (s) => { throw new Error(s); };

export function validate(capture) {
  if (!capture || capture.schema_version !== VERSION) fail('Unsupported schema version; expected 1.');
  if (!capture.provenance || !text(capture.provenance.capture_id)) fail('Missing capture identity.');
  if (!capture.coverage || !['complete', 'partial', 'cancelled', 'error', 'interrupted'].includes(capture.coverage.status)) fail('Invalid coverage status.');
  if (!text(capture.coverage.scope) || !Array.isArray(capture.coverage.limitations) || capture.coverage.limitations.length > 64 || !capture.coverage.limitations.every(text)) fail('Invalid coverage metadata.');
  if (!capture.quality || typeof capture.quality !== 'object' || !Array.isArray(capture.models) || !Array.isArray(capture.evidence)) fail('Missing quality, models or evidence.');
  const { nodes, edges } = capture.observations ?? {};
  if (!Array.isArray(nodes) || nodes.length > 10000 || !Array.isArray(edges) || edges.length > 100000) fail('Invalid or oversized graph.');
  const ids = new Set();
  for (const node of nodes) {
    if (!integer(node.id) || !node.id || ids.has(node.id) || !text(node.type) || !text(node.kind)) fail('Invalid or duplicate node.');
    if (node.length !== null && (!integer(node.length) || node.length > 16777215)) fail('Invalid or inexact DM length.');
    if (node.estimated_bytes != null && (!Number.isFinite(node.estimated_bytes) || node.estimated_bytes < 0)) fail('Invalid byte estimate.');
    ids.add(node.id);
  }
  for (const edge of edges) {
    if (!ids.has(edge.target) || (edge.owner !== 0 && !ids.has(edge.owner)) || !text(edge.field)) fail('Invalid edge or missing node.');
  }
  return capture;
}

export function parseCapture(input) {
  if (new TextEncoder().encode(input).length > MAX_BYTES) fail('File exceeds the 16 MiB local import limit.');
  return validate(JSON.parse(input));
}

export function summarize(capture, grouping = 'type', kindFilter = '') {
  validate(capture);
  const nodes = new Map(capture.observations.nodes.map(n => [n.id, n]));
  const owners = new Map();
  const rootNames = new Map();
  const paths = new Map();
  // Bounded fixed-point root propagation is intentionally absent: first observed
  // paths are examples, not exhaustive reachability or retained ownership.
  for (const e of capture.observations.edges) {
    if (!owners.has(e.target)) owners.set(e.target, []);
    owners.get(e.target).push(e);
    if (!paths.has(e.target)) {
      paths.set(e.target, (e.owner === 0 ? e.field : `${paths.get(e.owner) ?? `#${e.owner}`}.${e.field}`).slice(0, 512));
      rootNames.set(e.target, e.owner === 0 ? e.field : rootNames.get(e.owner) ?? 'unresolved');
    }
  }
  const rows = new Map();
  for (const node of nodes.values()) {
    if (kindFilter && node.kind !== kindFilter) continue;
    const incoming = owners.get(node.id) ?? [];
    let keys;
    if (grouping === 'field') keys = [...new Set(incoming.map(e => `${e.owner === 0 ? 'root' : nodes.get(e.owner).type}.${e.field.startsWith('slot:') ? '[]' : e.field}`))];
    else if (grouping === 'root') keys = [rootNames.get(node.id) ?? 'unresolved'];
    else if (grouping === 'instance') keys = [`#${node.id} ${node.type}`];
    else keys = [node.type];
    for (const key of keys) {
      let row = rows.get(key);
      if (!row) { row = { key, kind: node.kind, count: 0, slots: 0, empty: 0, largest: 0, shared: 0, known_bytes: 0, unknown: 0, confidence: 'count-only', ids: [], paths: [], distribution: { empty: 0, '1-8': 0, '9-32': 0, '33-128': 0, '129+': 0, unavailable: 0 }, root: rootNames.get(node.id) ?? 'unresolved' }; rows.set(key, row); }
      row.count++;
      row.slots += node.length ?? 0;
      row.largest = Math.max(row.largest, node.length ?? 0);
      row.distribution[node.length == null ? 'unavailable' : node.length === 0 ? 'empty' : node.length <= 8 ? '1-8' : node.length <= 32 ? '9-32' : node.length <= 128 ? '33-128' : '129+']++;
      row.empty += Number(node.length === 0 && ['list', 'alist'].includes(node.kind));
      row.shared += Number(new Set(incoming.map(e => `${e.owner}:${e.field}`)).size > 1);
      if (node.estimated_bytes == null) row.unknown++;
      else { row.known_bytes += node.estimated_bytes; row.confidence = 'estimated'; }
      row.ids.push(node.id);
      if (row.paths.length < 8) row.paths.push(paths.get(node.id) ?? `#${node.id}`);
    }
  }
  return [...rows.values()].map(row => ({ ...row, estimated_bytes: row.unknown === row.count ? null : row.known_bytes,
    // Model estimates are ranked only where supported. Count signals are separate.
    evidence: row.unknown ? 'Some or all bytes unavailable; investigate observed size/sharing.' : 'Calibrated model; retention and allocation site unknown.',
    score: row.known_bytes || row.largest + row.empty,
  }));
}

export function compatibility(a, b) {
  const differences = [];
  for (const key of ['byond', 'os', 'architecture', 'commit', 'map', 'workload']) {
    if (a.provenance[key] !== b.provenance[key]) differences.push(key);
  }
  if (a.coverage.scope !== b.coverage.scope || JSON.stringify(a.coverage.roots) !== JSON.stringify(b.coverage.roots) || JSON.stringify(a.settings) !== JSON.stringify(b.settings)) differences.push('scope/settings');
  if (JSON.stringify(a.models ?? []) !== JSON.stringify(b.models ?? [])) differences.push('models');
  if (a.coverage.status !== 'complete' || b.coverage.status !== 'complete') differences.push('partial coverage: deltas are observations only');
  return differences;
}

export function compare(a, b, grouping = 'type', kindFilter = '') {
  const old = new Map(summarize(a, grouping, kindFilter).map(r => [r.key, r]));
  const current = new Map(summarize(b, grouping, kindFilter).map(r => [r.key, r]));
  return [...new Set([...old.keys(), ...current.keys()])].map(key => {
    const before = old.get(key); const after = current.get(key);
    const baseline = before?.count ?? 0; const count = after?.count ?? 0;
    return { ...(after ?? before), key, count, baseline, comparison_source: after ? 'current' : 'baseline', delta: count - baseline, percent: baseline === 0 ? null : (count - baseline) / baseline * 100,
      change: baseline === 0 ? (count ? 'newly observed' : 'unchanged') : 'observed delta',
      byte_delta: before?.estimated_bytes != null && after?.estimated_bytes != null && JSON.stringify(a.models) === JSON.stringify(b.models) ? after.estimated_bytes - before.estimated_bytes : null };
  });
}

export function query(rows, options = {}) {
  const { search = '', prefix = '', kind = '', root = '', confidence = '', sort = [{ key: 'score', direction: -1 }] } = options;
  const found = rows.filter(r => (!search || `${r.key} ${r.paths.join(' ')}`.toLowerCase().includes(search.toLowerCase())) && (!prefix || r.key.startsWith(prefix)) && (!kind || r.kind === kind) && (!root || r.root === root) && (!confidence || r.confidence === confidence));
  return found.sort((a, b) => {
    for (const rule of sort.slice(0, 3)) {
      const av = a[rule.key], bv = b[rule.key];
      if (av == null && bv != null) return 1;
      if (bv == null && av != null) return -1;
      const d = typeof av === 'number' && typeof bv === 'number' ? av - bv : String(av ?? '').localeCompare(String(bv ?? ''));
      if (d) return d * rule.direction;
    }
    return a.key.localeCompare(b.key);
  });
}

export function csv(rows) {
  const columns = ['key', 'kind', 'count', 'slots', 'empty', 'largest', 'shared', 'estimated_bytes', 'unknown', 'delta', 'percent', 'byte_delta'];
  const cell = v => { let s = v == null ? '' : String(v); if (/^[=+@\-\t\r]/.test(s)) s = `'${s}`; return `"${s.replaceAll('"', '""')}"`; };
  return [columns.join(','), ...rows.map(r => columns.map(c => cell(r[c])).join(','))].join('\r\n');
}
