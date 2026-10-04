import { MAX_BYTES } from './analysis.mjs';
const $ = id => document.getElementById(id);
let worker = new Worker('./worker.mjs', { type: 'module' });
let page = 0, total = 0, sort = [{ key: 'score', direction: -1 }];
const number = value => value == null ? 'Unavailable' : value.toLocaleString(undefined, { maximumFractionDigits: 1 });
const tell = message => { $('message').textContent = message; };
function refresh() { worker.postMessage({ action: 'query', current: Number($('current').value), baseline: Number($('baseline').value), grouping: $('group').value, page, options: { search: $('search').value, prefix: $('prefix').value, kind: $('kind').value, root: $('root').value, confidence: $('confidence').value, sort } }); }
async function importFile(file) {
  if (file.size > MAX_BYTES) return tell(`${file.name}: exceeds 16 MiB.`);
  try { worker.postMessage({ action: 'import', text: await file.text() }); }
  catch (e) { tell(e.message); }
}
$('files').onchange = () => { for (const file of $('files').files) importFile(file); };
$('drop').ondragover = event => event.preventDefault();
$('drop').ondrop = event => { event.preventDefault(); for (const file of event.dataTransfer.files) importFile(file); };
$('sample').onclick = async () => { try { const r = await fetch('./examples/fixture.memory.json'); if (!r.ok) throw Error('Example unavailable; run the documented fixture/finalizer.'); worker.postMessage({ action: 'import', text: await r.text() }); } catch(e) { tell(e.message); } };
for (const id of ['current', 'baseline', 'group', 'search', 'prefix', 'kind', 'root', 'confidence']) $(id).oninput = () => { page = 0; refresh(); };
$('reset').onclick = () => { for (const id of ['search', 'prefix', 'kind', 'root', 'confidence']) $(id).value = ''; sort = [{ key: 'score', direction: -1 }]; page = 0; refresh(); };
for (const button of document.querySelectorAll('[data-sort]')) button.onclick = event => {
  const key = button.dataset.sort; const previous = sort.find(s => s.key === key);
  const rule = { key, direction: previous ? -previous.direction : -1 };
  sort = event.shiftKey ? [...sort.filter(s => s.key !== key), rule].slice(-3) : [rule]; page = 0; refresh();
};
$('previous').onclick = () => { if (page > 0) { page--; refresh(); } };
$('next').onclick = () => { if ((page + 1) * 75 < total) { page++; refresh(); } };
for (const format of ['json', 'csv']) $(format).onclick = () => worker.postMessage({ action: 'export', format });
worker.onerror = e => tell(`Analysis worker failed: ${e.message}. Reload to reset.`);
worker.onmessage = ({ data }) => {
  if (data.action === 'error') return tell(data.message);
  if (data.action === 'imported') {
    const oldBaseline = $('baseline').value;
    $('current').replaceChildren(); $('baseline').replaceChildren(new Option('None', '-1'));
    data.names.forEach((name, i) => { $('current').add(new Option(name, i)); $('baseline').add(new Option(name, i)); });
    $('current').value = data.names.length - 1; $('baseline').value = oldBaseline; page = 0; refresh();
  } else if (data.action === 'rows') {
    total = data.total;
    tell(`${data.coverage.status.toUpperCase()}: ${data.coverage.reason ?? 'selected scope completed'}. ${data.incompatible.length ? `Comparison warnings: ${data.incompatible.join(', ')}.` : ''}`);
    $('cards').replaceChildren();
    for (const [label, value] of [['Engine', data.provenance.byond], ['Evidence', data.provenance.evidence_class], ['Worst step (ms)', data.quality.worst_atomic_ms_before_footer], ['Retained after cleanup', data.quality.retained_references]]) {
      const card = document.createElement('div'); const small = document.createElement('small'); small.textContent = label; const strong = document.createElement('strong'); strong.textContent = typeof value === 'number' ? number(value) : value ?? 'Unavailable'; card.append(small, strong); $('cards').append(card);
    }
    $('scope').textContent = `Scope: ${data.coverage.scope}. ${data.coverage.limitations?.join(' ') ?? ''}`;
    $('timeline').textContent = `Capture series: ${data.timeline.map(t => `${t.id}: ${t.nodes} observed nodes (${t.status})`).join(' → ')}`;
    $('legacy').textContent = data.legacy ? JSON.stringify(data.legacy, null, 2).slice(0, 20000) : '';
    $('legacy-panel').hidden = !data.legacy;
    $('rows').replaceChildren();
    for (const row of data.rows) {
      const tr = document.createElement('tr'); const td = document.createElement('td'); const button = document.createElement('button'); button.className = 'row-link'; button.textContent = row.key; button.onclick = () => { worker.postMessage({ action: 'detail', current: row.detail_capture, ids: row.ids, summary: {key:row.key, distribution:row.distribution, paths:row.paths, estimate_coverage:`${row.count-row.unknown}/${row.count} objects`, evidence:row.evidence} }); }; td.append(button); tr.append(td);
      for (const key of ['count', 'estimated_bytes', 'slots', 'largest', 'empty', 'shared', 'delta', 'percent', 'byte_delta', 'score']) { const cell = document.createElement('td'); cell.textContent = key === 'percent' && row.baseline === 0 ? row.change : number(row[key]); cell.title = row[key] == null ? 'Unknown, not zero' : String(row[key]); tr.append(cell); }
      $('rows').append(tr);
    }
    $('count').textContent = `${total} matching rows`; $('page').textContent = `Page ${page + 1} of ${Math.max(1, Math.ceil(total / 75))}`; $('previous').disabled = page === 0; $('next').disabled = (page + 1) * 75 >= total;
  } else if (data.action === 'detail') { $('detail').textContent = JSON.stringify(data, null, 2); $('details').open = true; $('details').scrollIntoView({ behavior: 'smooth', block: 'nearest' }); }
  else if (data.action === 'export') { const url = URL.createObjectURL(new Blob([data.text], { type: data.format === 'csv' ? 'text/csv' : 'application/json' })); const a = document.createElement('a'); a.href = url; a.download = `memory-summary.${data.format}`; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
};
