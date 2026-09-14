import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { DATASETS,parseExport } from './data-contract.js';
import { FIELDS } from './fields.js';
import contract from './contract.json' with { type: 'json' };
import { gate } from './semantic-check.js';
import { assessSelection,decodeSelection,recordKey } from './selection-plan.js';

const oldBuild='a'.repeat(64),build='b'.repeat(64),publication='c'.repeat(64),reviewDigest='d'.repeat(64);
function fixture(){
 const header={kind:'header',schema_version:2,profile:'source-defaults',time_unit:'decisecond',appearance_profile:'initial-south-first-frame'},records=[];
 for(const kind of DATASETS){const fields={};for(const [field,types] of Object.entries(FIELDS[kind]).filter(([field]) => kind !== 'entity' || !contract.optionalEntity.includes(field)))fields[field]=types.includes('array')?[]:types.includes('number')?0:types.includes('null')?null:'example';if(Object.hasOwn(fields,'documentation_visibility'))fields.documentation_visibility='public';if(kind==='entity')fields.icon_file=null;records.push({kind,id:kind==='entity'?'/obj/item/fixture':'/datum/'+kind+'/fixture',fields});}
 const pkg=parseExport([header,...records,{kind:'complete',counts:Object.fromEntries(DATASETS.map(kind=>[kind,1]))}].map(r=>JSON.stringify(r)).join('\n'));
 pkg.records.find(r=>r.kind==='vending').fields.default_price=5;return pkg;
}
function choice(record){return {key:recordKey(record),sourceKey:recordKey(record),sourceBuild:oldBuild,publication,record:structuredClone(record)};}
const plan=()=>({version:1,build,expected:oldBuild,expectedPublication:publication,reviewDigest,replacements:[],corrections:[],previous:{build:oldBuild,replacements:[],corrections:[]}});

test('a reviewed substitution fixes its source defect without mutating either package',async()=>{
 const previous=fixture(),current=structuredClone(previous),original=current.records.find(r=>r.kind==='vending');original.fields.default_price=-10;
 const selection=plan();selection.replacements=[choice(previous.records.find(r=>r.kind==='vending'))];
 assert.equal(gate(previous,current).ok,false);
 const result=await assessSelection(current,previous,selection,[],async id=>{assert.equal(id,oldBuild);return previous;});
 assert.equal(result.report.ok,true);assert.equal(result.effective.records.find(r=>r.kind==='vending').fields.default_price,5);assert.equal(original.fields.default_price,-10);
 current.records.find(r=>r.kind==='design').fields.construction_time=-1;
 assert.equal((await assessSelection(current,previous,selection,[],async()=>previous)).report.ok,false,'unrelated defects still block the release');
});

test('source hiding, altered source bodies and metadata corrections cannot be excused',async()=>{
 const previous=fixture(),current=structuredClone(previous),record=previous.records.find(r=>r.kind==='vending'),selection=plan();selection.replacements=[choice(record)];
 selection.replacements[0].record.fields.default_price=1000;await assert.rejects(assessSelection(current,previous,selection,[],async()=>previous),/immutable package/);
 selection.replacements=[choice(record)];current.records.find(r=>r.kind==='vending').fields.documentation_visibility='hidden';await assert.rejects(assessSelection(current,previous,selection,[],async()=>previous),/source hiding/);
 selection.replacements=[];selection.corrections=[{key:recordKey(record),fields:{documentation_visibility:'public'}}];await assert.rejects(assessSelection(current,previous,selection,[],async()=>previous),/source metadata/);
});

test('only explicitly retained missing identities are restored and relationships remain checked',async()=>{
 const previous=fixture(),record=previous.records.find(r=>r.kind==='vending'),extra={...structuredClone(record),id:record.id+'_second'};previous.records.push(extra);previous.counts.vending++;
 const current=structuredClone(previous);current.records=current.records.filter(r=>r.id!==record.id);current.counts.vending--;
 const selection=plan();selection.replacements=[choice(record)];assert.equal((await assessSelection(current,previous,selection,[],async()=>previous)).report.ok,true);
 const item=previous.records.find(r=>r.kind==='entity');record.fields.products=[{key:item.id,value:1}];selection.replacements=[choice(record)];
 current.records.find(r=>r.kind==='entity').id+='_renamed';
 const result=await assessSelection(current,previous,selection,[],async()=>previous);
 assert.equal(result.report.ok,false);assert.ok(result.report.reasons.some(r=>r.rule==='outside-export'),'retained relationships must resolve in the candidate set');
 assert.ok(result.report.reasons.some(r=>r.rule==='removed-identities'),'unexplained identity loss is not waived');
});

test('regression comparison uses the prior published selection and validates editorial values',async()=>{
 const original=fixture(),previous=structuredClone(original),current=structuredClone(original),selection=plan();previous.records.find(r=>r.kind==='vending').fields.default_price=-100;
 const retained=choice(original.records.find(r=>r.kind==='vending'));retained.sourceBuild='e'.repeat(64);selection.previous.replacements=[retained];
 const result=await assessSelection(current,previous,selection,[],async()=>original);assert.equal(result.report.ok,true);assert.deepEqual(result.report.diff.changed,[]);
 selection.corrections=[{key:recordKey(original.records.find(r=>r.kind==='vending')),fields:{default_price:-5}}];assert.equal((await assessSelection(current,previous,selection,[],async()=>original)).report.ok,false);
 selection.corrections[0].fields.default_price='wrong type';await assert.rejects(assessSelection(current,previous,selection,[],async()=>original),/invalid field/i);
});

test('review bytes and expected publication state are bound before assessment',()=>{
 const bytes=Buffer.from(JSON.stringify(plan())),wrapper={build,bytes:bytes.toString('base64'),digest:createHash('sha256').update(bytes).digest('hex')};
 assert.equal(decodeSelection(wrapper,build,oldBuild).plan.reviewDigest,reviewDigest);
 assert.throws(()=>decodeSelection({...wrapper,bytes:Buffer.from('{}').toString('base64')},build,oldBuild),/bytes changed/);
 assert.throws(()=>decodeSelection(wrapper,build,'f'.repeat(64)),/another publication state/);
});
