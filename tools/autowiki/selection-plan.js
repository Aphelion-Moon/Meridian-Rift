import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { canonical, parseExport, readPackage } from './data-contract.js';
import { gate, inspect } from './semantic-check.js';

const sha=value=>createHash('sha256').update(value).digest('hex');
const hash=value=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
const same=(a,b)=>JSON.stringify(canonical(a))===JSON.stringify(canonical(b));
const metadata=new Set(['documentation_id','documentation_family','documentation_visibility','parent','scope','appearance_scope','icon_source','icon_state','icon_file','deferred_fields','dynamic_fields','render_profiles','evidence','conditions','result']);
export const recordKey=r=>sha(r.kind+':'+(r.fields.documentation_id==null?r.id:'canonical:'+r.fields.documentation_id));

/** The bytes are emitted by trusted local MediaWiki maintenance, never a browser. */
export function decodeSelection(wrapper,build,expected) {
 if(!wrapper||wrapper.build!==build||!hash(wrapper.digest)||typeof wrapper.bytes!=='string'||wrapper.bytes.length>90*1024*1024)throw new Error('Invalid reviewed selection envelope');
 const bytes=Buffer.from(wrapper.bytes,'base64');if(sha(bytes)!==wrapper.digest)throw new Error('Reviewed selection bytes changed');
 const plan=JSON.parse(bytes.toString('utf8'));
 if(plan.version!==1||plan.build!==build||plan.expected!==expected||!hash(plan.reviewDigest)||(plan.expectedPublication!==''&&!hash(plan.expectedPublication)))throw new Error('Reviewed selection belongs to another publication state');
 if(!Array.isArray(plan.replacements)||!Array.isArray(plan.corrections)||!plan.previous||plan.previous.build!==expected)throw new Error('Incomplete reviewed selection');
 return {plan,bytes,digest:wrapper.digest};
}

/** Rebuild from immutable package records; never accept replacement record bodies as authority. */
export async function applySelection(pkg,selection,load) {
 if(!Array.isArray(selection.replacements)||!Array.isArray(selection.corrections)||selection.replacements.length+selection.corrections.length>200000)throw new Error('Invalid selection size');
 const records=new Map();for(const r of pkg.records){const key=recordKey(r);if(records.has(key))throw new Error('The original package contains a canonical collision');records.set(key,r);}
 const replaced=new Set(),sources=new Map();
 for(const choice of selection.replacements){
  if(!hash(choice.key)||!hash(choice.sourceBuild)||!hash(choice.sourceKey)||!hash(choice.publication)||replaced.has(choice.key)||choice.sourceBuild===selection.build)throw new Error('Invalid or repeated preserved source');
  if(!sources.has(choice.sourceBuild)){const source=await load(choice.sourceBuild),indexed=new Map();for(const r of source.records){const key=recordKey(r);if(indexed.has(key))throw new Error('Historical package contains a canonical collision');indexed.set(key,r);}sources.set(choice.sourceBuild,indexed);}
  const r=sources.get(choice.sourceBuild).get(choice.sourceKey),current=records.get(choice.key);
  if(!r||recordKey(r)!==choice.key||!same({kind:r.kind,id:r.id,fields:r.fields},choice.record))throw new Error('Preserved source differs from its immutable package');
  if(r.fields.documentation_visibility==='hidden'||current?.fields.documentation_visibility==='hidden')throw new Error('Preservation cannot bypass source hiding');
  records.set(choice.key,r);replaced.add(choice.key);
 }
 const corrected=new Set();
 for(const correction of selection.corrections){
  const r=records.get(correction.key),fields=correction.fields;
  if(!r||corrected.has(correction.key)||!fields||Array.isArray(fields)||typeof fields!=='object'||!Object.keys(fields).length)throw new Error('Invalid or repeated editorial correction');
  for(const field of Object.keys(fields))if(metadata.has(field)||!Object.hasOwn(r.fields,field))throw new Error('Editorial correction cannot rewrite source metadata');
  records.set(correction.key,{...r,fields:{...r.fields,...fields}});corrected.add(correction.key);
 }
 const rows=[...records.values()],counts=Object.fromEntries(Object.keys(pkg.counts).map(kind=>[kind,0]));for(const r of rows)counts[r.kind]=(counts[r.kind]||0)+1;
 // Reuse the export contract, including nested DM lists and dynamic-field rules.
 const checked=parseExport([pkg.header,...rows,{kind:'complete',counts}].map(r=>JSON.stringify(r)).join('\n'));
 return {...pkg,...checked};
}

export async function assessSelection(current,previous,selection,baseline,load) {
 const effective=await applySelection(current,selection,load);
 const prior=previous?await applySelection(previous,selection.previous,load):null;
 const report=gate(prior,effective,baseline);
 // Preservation cannot conceal structural identity defects in the new export.
 const collisions=inspect(current.records).filter(i=>i.rule==='duplicate-canonical-id');
 if(collisions.length){report.reasons.push(...collisions);report.ok=false;}
 return {report,effective,previous:prior};
}

export function sourceLoader(packageStore) {
 const pending=new Map();
 return async build=>{
  if(!hash(build))throw new Error('Invalid historical source build');
  if(!pending.has(build))pending.set(build,(async()=>{
   const root=path.join(packageStore,'packages',build),bytes=await fs.readFile(path.join(root,'manifest.json'));
   if(sha(bytes)!==build)throw new Error('Historical package identity changed');
   const pkg=await readPackage(root);if(!bytes.equals(await fs.readFile(path.join(root,'manifest.json'))))throw new Error('Historical package changed during validation');return pkg;
  })());return pending.get(build);
 };
}
