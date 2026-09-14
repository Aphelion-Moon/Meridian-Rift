import { readPackage, compareExports } from './data-contract.js';
import { relationshipKind } from './fields.js';
import contract from './contract.json' with { type: 'json' };
import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function inspect(records) {
 const issues = [], identities = new Set(records.map(r => r.kind + ':' + r.id));
 const stable = new Map();
 for (const r of records) {
  const f = r.fields;
  if (r.kind === 'entity') {
   const issue = (rule,field) => issues.push({kind:r.kind,rule,target:r.id,field});
   for (const field of ['construction_components','construction_alternatives']) {
    const seen = new Set();
    for (const {key,value} of f[field] || []) {
     if (typeof key !== 'string' || !key.startsWith('/obj/item/')) issue('invalid-construction-component',field);
     if (!Number.isSafeInteger(value) || value <= 0) issue('invalid-construction-quantity',field);
     if (seen.has(key)) issue('duplicate-construction-component',field);
     seen.add(key);
    }
   }
   if ('stock_part_tier' in f && (!Number.isSafeInteger(f.stock_part_tier) || f.stock_part_tier < 1)) issue('invalid-stock-part-tier','stock_part_tier');
   if ('stock_part_energy_rating' in f && (!Number.isFinite(f.stock_part_energy_rating) || f.stock_part_energy_rating <= 0)) issue('invalid-stock-part-energy-rating','stock_part_energy_rating');
   for (const field of ['construction_needs_anchored','construction_specific_parts']) if (field in f && ![0,1].includes(f[field])) issue('invalid-construction-flag',field);
  }
  if (f.documentation_id) {
   if (stable.has(f.documentation_id)) issues.push({ kind:r.kind, rule:'duplicate-canonical-id', target:r.id, related:stable.get(f.documentation_id) });
   stable.set(f.documentation_id,r.id);
  }
  if (f.documentation_visibility && !['unknown','public','hidden','historical'].includes(f.documentation_visibility)) issues.push({kind:r.kind,rule:'invalid-visibility',target:r.id});
  for (const field of ['time','construction_time','cost','default_price','extra_price','result_amount','max_ammo']) if (typeof f[field] === 'number' && f[field] < 0) issues.push({kind:r.kind,rule:'negative-' + field,target:r.id});
  for (const [field, targetKind] of Object.entries(contract.relations[r.kind] || {})) {
   const values = Array.isArray(f[field]) ? f[field].map(p=>p.key) : [f[field]];
   for (const value of values) {
    if (typeof value !== 'string' || !value.startsWith('/')) continue;
    const kind = relationshipKind(targetKind,value);
    if (!identities.has(kind+':'+value)) issues.push({kind:r.kind,rule:'outside-export',target:r.id,field,related:kind+':'+value});
   }
  }
 }
 return issues;
}
export function gate(previous,current,baseline=[]) {
 const old = new Set(baseline.map(i=>JSON.stringify(i))), issues=inspect(current.records);
 const additions=issues.filter(i=>!old.has(JSON.stringify(i)));
 const diff=previous?compareExports(previous,current):{added:[],removed:[],changed:[]};
 const reasons=additions.filter(i=>i.rule!=='outside-export');
 if(previous) {
  for(const kind of Object.keys(previous.counts)) if((current.counts[kind]||0)<previous.counts[kind]*0.95) reasons.push({rule:'dataset-shrink',target:kind});
  if(diff.removed.length) reasons.push({rule:'removed-identities',count:diff.removed.length});
  const priorMissing=new Set(inspect(previous.records).filter(i=>i.rule==='outside-export').map(i=>JSON.stringify(i)));
  reasons.push(...additions.filter(i=>i.rule==='outside-export'&&!priorMissing.has(JSON.stringify(i))));
 }
 return {ok:reasons.length===0,reasons,issues,diff};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 const [currentPath,output,previousPath,baselinePath]=process.argv.slice(2);
 const current=await readPackage(currentPath),previous=previousPath?await readPackage(previousPath):null;
 const baseline=baselinePath?JSON.parse(await fs.readFile(baselinePath,'utf8')):[];
 const report=gate(previous,current,baseline);await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');
 if(!report.ok)process.exitCode=1;
}
