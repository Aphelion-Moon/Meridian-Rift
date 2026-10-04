import { parseCapture, summarize, compare, query, compatibility, csv } from './analysis.mjs';
const captures = [];
let filtered = [];
self.onmessage = ({ data }) => {
  try {
    if (data.action === 'import') {
      if (captures.length >= 12) throw Error('At most 12 captures per session; reload to release memory.');
      captures.push(parseCapture(data.text));
      self.postMessage({ action: 'imported', names: captures.map(c => c.provenance.capture_id) });
    } else if (data.action === 'query') {
      const current = captures[data.current];
      if (!current) return;
      const baseline = captures[data.baseline];
      const rows = baseline && baseline !== current ? compare(baseline, current, data.grouping, data.options.kind) : summarize(current, data.grouping, data.options.kind);
      filtered = query(rows, { ...data.options, kind: '' });
      self.postMessage({ action: 'rows', rows: filtered.slice(data.page * 75, (data.page + 1) * 75).map(row => ({ ...row, detail_capture: row.comparison_source === 'baseline' ? data.baseline : data.current })), total: filtered.length,
        coverage: current.coverage, quality: current.quality, provenance: current.provenance,
        legacy: current.comparison_context?.legacy_rows?.slice(0, 100),
        incompatible: baseline && baseline !== current ? compatibility(baseline, current) : [],
        timeline: captures.map(c => ({ id: c.provenance.capture_id, nodes: c.observations.nodes.length, status: c.coverage.status })) });
    } else if (data.action === 'detail') {
      const c = captures[data.current]; const ids = new Set(data.ids.slice(0, 100));
      self.postMessage({ action: 'detail', capture_id: c.provenance.capture_id, summary: data.summary, nodes: c.observations.nodes.filter(n => ids.has(n.id)), edges: c.observations.edges.filter(e => ids.has(e.target)).slice(0, 200) });
    } else if (data.action === 'export') self.postMessage({ action: 'export', format: data.format, text: data.format === 'csv' ? csv(filtered) : JSON.stringify(filtered, null, 2) });
  } catch (error) { self.postMessage({ action: 'error', message: error.message }); }
};
