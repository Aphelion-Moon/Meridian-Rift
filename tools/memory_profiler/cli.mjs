#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { validate, parseCapture, summarize, compare, compatibility, csv, MAX_BYTES } from './analysis.mjs';

const limitations = [
  'Selected-root, weakly consistent interval; no whole-heap census or statistical extrapolation.',
  'Unrooted statics, live clients, builtin collection views and engine/native cache residency are unavailable.',
  'Equal-length mutation is invisible; null ordinary associations are indistinguishable from absent associations.',
  'Strong references prevent identity reuse but can temporarily retain gameplay graphs; bookkeeping limits are not a bound on retained gameplay bytes.',
  'Byte models describe fresh equivalent containers, not measured capacity or retained bytes. Footer write time is excluded from footer timing statistics.',
];
const read = name => { if (fs.statSync(name).size > MAX_BYTES) throw Error('Input exceeds 16 MiB.'); return fs.readFileSync(name, 'utf8'); };
const hash = text => crypto.createHash('sha256').update(text).digest('hex');

export function finalize(transport, source = 'transport.ndjson', model = null) {
  if (Buffer.byteLength(transport) > MAX_BYTES) throw Error('Transport exceeds 16 MiB.');
  const lines = transport.split(/\r?\n/).filter(l => l.trim());
  let header, footer, interrupted = false, sequence = 0;
  const nodes = [], edges = [], byId = new Map();
  for (let index = 0; index < lines.length; index++) {
    let r;
    try { r = JSON.parse(lines[index]); } catch (e) { if (index !== lines.length - 1) throw Error(`Malformed transport record ${index + 1}.`); interrupted = true; break; }
    if (r.sequence !== ++sequence || footer) throw Error('Transport sequence mismatch, duplicate capture or records after footer.');
    if (r.record === 'header') {
      if (header || sequence !== 1 || r.schema_version !== 1) throw Error('Unsupported or duplicate transport header.');
      header = r;
    } else if (!header) throw Error('Transport header missing.');
    else if (r.record === 'node') { const node = { ...r, estimated_bytes: null, estimate_reason: 'No compatible validated allocation model.' }; nodes.push(node); byId.set(r.id, node); }
    else if (r.record === 'edge') edges.push(r);
    else if (r.record === 'node_end') { if (!byId.has(r.id)) throw Error('Unknown node completion.'); byId.get(r.id).scan = r; }
    else if (r.record === 'footer') footer = r;
    else throw Error(`Unsupported transport record: ${String(r.record).slice(0, 60)}`);
  }
  if (!header) throw Error('No readable header.');
  if (footer && (footer.nodes !== nodes.length || footer.edges !== edges.length || footer.retained_references !== 0)) throw Error('Footer counts or reference cleanup disagree with transport.');
  const models = [];
  const sourceHints = {
    SSgreyscale: 'code/controllers/subsystem/processing/greyscale.dm',
    SSassets: 'code/controllers/subsystem/assets.dm', SStimer: 'code/controllers/subsystem/timer.dm',
    SSgarbage: 'code/controllers/subsystem/garbage.dm', GLOB: 'code/_globalvars/ (individual declarations require source search)',
  };
  for (const edge of edges) if (edge.owner === 0) {
    const source = sourceHints[edge.field.split('.')[0]];
    if (source) byId.get(edge.target).source_hint = { path: source, role: 'observed root / retention declaration, not allocation site', field: edge.field };
  }
  if (model) {
    if (model.schema_version !== 1 || model.byond !== header.provenance.byond || model.os !== header.provenance.os || model.architecture !== header.provenance.architecture || !Array.isArray(model.families)) throw Error('Incompatible allocation model.');
    for (const family of model.families) {
      for (const key of ['intercept', 'slope', 'min_length', 'max_length']) if (!Number.isFinite(family[key]) || family[key] < 0) throw Error('Invalid model coefficient.');
      if (family.kind !== 'list' || family.supported !== true) continue;
      for (const node of nodes) if (node.kind === 'list' && node.scan?.fully_scanned && node.scan.numeric_slots === node.length && node.length >= family.min_length && node.length <= family.max_length) {
        node.estimated_bytes = family.intercept + family.slope * node.length;
        node.estimate_reason = 'Fresh numeric/null container equivalent; actual capacity/history unknown.';
        node.model_id = model.model_id;
      }
    }
    models.push(model);
  }
  return validate({ schema_version: 1, collector_version: header.collector_version, provenance: header.provenance,
    settings: header.settings, coverage: { scope: header.scope, roots: header.roots, status: interrupted || !footer ? 'interrupted' : footer.status,
      reason: interrupted || !footer ? 'missing_or_incomplete_footer' : footer.reason, limitations,
      population: null, selection: 'bounded deterministic breadth-first selected roots; not a representative sample',
      mutations: footer?.mutations ?? null, deletions: footer?.deletions ?? null, skipped: footer?.skipped ?? null, truncations: footer?.truncations ?? null },
    quality: { ...(footer ?? {}), collector_bytes: null, collector_bytes_reason: 'No allocator API; use isolated process comparisons. Retained gameplay graphs excluded from modeled totals.', sampling_weights: null },
    observations: { nodes, edges }, models, comparison_context: { process_samples: [], markers: [], engine_heap_bytes: null },
    evidence: [{ artifact: path.basename(source), sha256: hash(transport), method: 'Dream Daemon structural observation transport', transport_records: sequence }] });
}

export function serve(port = 8765) {
  const root = path.dirname(fileURLToPath(import.meta.url));
  const mime = { '.html': 'text/html', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };
  const server = http.createServer((req, res) => {
    try {
      if (req.method !== 'GET') { res.writeHead(405); res.end(); return; }
      const relative = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
      const file = path.resolve(root, `.${relative === '/' ? '/index.html' : relative}`);
      if (!file.startsWith(root + path.sep) || !mime[path.extname(file)] || !fs.statSync(file).isFile() || fs.statSync(file).size > MAX_BYTES) throw Error('Not found');
      res.writeHead(200, { 'Content-Type': `${mime[path.extname(file)]}; charset=utf-8`, 'X-Content-Type-Options': 'nosniff', 'Cache-Control': 'no-store' });
      fs.createReadStream(file).pipe(res);
    } catch { res.writeHead(404); res.end('Not found'); }
  });
  server.listen(port, '127.0.0.1', () => console.log(`Memory viewer: http://127.0.0.1:${port}`));
  return server;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [command, ...args] = process.argv.slice(2);
    const option = name => { const i = args.indexOf(name); return i < 0 ? null : args[i + 1]; };
    if (command === 'serve') serve(Number(args[0] ?? 8765));
    else if (command === 'finalize') {
      const input = args[0]; const output = option('--out') ?? input.replace(/\.ndjson$/i, '') + '.memory.json';
      const capture = finalize(read(input), input, option('--model') ? JSON.parse(read(option('--model'))) : null);
      if (option('--telemetry')) capture.comparison_context = JSON.parse(read(option('--telemetry')));
      fs.writeFileSync(output, JSON.stringify(capture, null, 2) + '\n'); console.log(`${output}: ${capture.coverage.status}, ${capture.observations.nodes.length} nodes`);
    } else if (command === 'validate') { const c = parseCapture(read(args[0])); console.log(`Valid schema 1: ${c.coverage.status}`); }
    else if (command === 'summary') console.log(csv(summarize(parseCapture(read(args[0])), option('--group') ?? 'type')));
    else if (command === 'compare') { const a = parseCapture(read(args[0])), b = parseCapture(read(args[1])); console.error(`Compatibility: ${compatibility(a, b).join(', ') || 'same declared scope'}`); console.log(csv(compare(a, b))); }
    else throw Error('Commands: serve [port] | finalize input.ndjson [--out capture.memory.json] [--model model.json] [--telemetry context.json] | validate file | summary file [--group type|field|root|instance] | compare baseline current');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
