import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { publish } from './publish.js';
import { packageExport, DATASETS } from './data-contract.js';
import { FIELDS } from './fields.js';
import contract from './contract.json' with { type: 'json' };
import {verifyRelease,SemanticReviewRequired} from './release.js';
const selection=f=>{const bytes=Buffer.from(JSON.stringify({version:1,build:f.build,expected:'',expectedPublication:'',reviewDigest:'f'.repeat(64),replacements:[],corrections:[],previous:{build:'',replacements:[],corrections:[]}}));return {build:f.build,bytes:bytes.toString('base64'),digest:createHash('sha256').update(bytes).digest('hex')};};
async function fixture(t) {
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-publish-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const rows=[{kind:'header',schema_version:2,profile:'source-defaults',time_unit:'decisecond',appearance_profile:'initial-south-first-frame'}];
 for(const kind of DATASETS){const fields={};for(const [field,types] of Object.entries(FIELDS[kind]).filter(([field]) => kind !== 'entity' || !contract.optionalEntity.includes(field)))fields[field]=types.includes('array')?[]:types.includes('number')?0:types.includes('null')?null:'example';if(kind==='entity'){fields.icon_file=null;fields.appearance_scope='initial';}rows.push({kind,id:kind==='entity'?'/obj/item/test':`/datum/${kind}/test`,fields});}
 rows.push({kind:'complete',counts:Object.fromEntries(DATASETS.map(kind=>[kind,1]))});
 const raw=path.join(root,'records.jsonl'),icons=path.join(root,'icons'),pkg=path.join(root,'package');await fs.mkdir(icons);await fs.writeFile(raw,rows.map(r=>JSON.stringify(r)).join('\n'));await packageExport(raw,icons,pkg,'a'.repeat(40));
 const build=createHash('sha256').update(await fs.readFile(path.join(pkg,'manifest.json'))).digest('hex');
 const config={php:path.join(root,'php'),maintenanceRunner:path.join(root,'run.php'),settings:path.join(root,'settings.php'),packageStore:path.join(root,'store'),deploymentFile:path.join(root,'deployment.json')};return {root,pkg,build,config};
}
test('versioned publication uses the exact installed extension and rejects relative bindings',async t=>{
 const f=await fixture(t);f.config.extensionDirectory=path.join(f.root,'release','extension');let entry,cwd;
 await assert.rejects(publish(f.pkg,f.config,{run:(exe,args,options)=>{entry=args[3];cwd=options.cwd;throw new Error('Stopped before publication');}}),/Stopped before publication/);
 assert.equal(entry,'./maintenance/State.php');assert.equal(cwd,f.config.extensionDirectory);
 f.config.extensionDirectory='relative/extension';
 await assert.rejects(publish(f.pkg,f.config,{run:()=>{throw new Error('Must not execute');}}),/absolute local path/);
});
test('publication verifies first, stages immutable content and supplies the active-build guard',async t=>{
 const f=await fixture(t),calls=[];
 const run=(exe,args)=>{calls.push(args);return args.includes('MeridianAutowiki:State')?'{"active":"","epoch":0}':args.includes('MeridianAutowiki:Selection')?JSON.stringify(selection(f)):args.some(a=>['MeridianAutowiki:Review','MeridianAutowiki:Assessment'].includes(a))?JSON.stringify({review:f.build}):JSON.stringify({active:f.build,delivery:'queued'});};
 let verified=0;const result=await publish(f.pkg,f.config,{run,verify:async(p,c)=>{verified++;assert.equal(calls.length,verified===1?1:3);assert.equal(Boolean(c.selectionPlan),verified===2);return {build:f.build};}});
 assert.equal(result.active,f.build);assert.ok(calls[1].includes('MeridianAutowiki:Review'));assert.deepEqual(calls[4].slice(-2),['--expected','none']);assert.ok(await fs.stat(path.join(f.config.packageStore,'packages',f.build,'manifest.json')));
});
test('untrusted provenance and invalid maintenance output never reach publication',async t=>{
 const f=await fixture(t);let calls=0;
 await assert.rejects(publish(f.pkg,f.config,{run:()=>{calls++;return '{"active":""}';},verify:async()=>{throw new Error('untrusted');}}),/untrusted/);assert.equal(calls,1);
 await assert.rejects(publish(f.pkg,f.config,{run:()=> 'Fatal maintenance error',verify:async()=>{throw new Error('must not verify');}}),/valid result/);
});
test('TGS publication rechecks deployment after preparation and refuses a switched game',async t=>{
 const f=await fixture(t);f.config.tgs={};let observations=0;const stages=[];
 const run=(exe,args)=>{const stage=args.find(a=>a.startsWith('MeridianAutowiki:'));stages.push(stage);return JSON.stringify(stage.endsWith(':State')?{active:''}:stage.endsWith(':Selection')?selection(f):stage.endsWith(':Review')||stage.endsWith(':Assessment')?{review:f.build}:stage.endsWith(':Publish')?{prepared:f.build}:{active:f.build});};
 const verify=async()=>{const d=JSON.parse(await fs.readFile(f.config.deploymentFile,'utf8'));if(d.commit!=='a'.repeat(40))throw new Error('Game changed');return {build:f.build};};
 await assert.rejects(publish(f.pkg,f.config,{run,verify,deployment:async()=>({commit:(observations++?'b':'a').repeat(40)})}),/Game changed/);
 assert.deepEqual(stages,['MeridianAutowiki:State','MeridianAutowiki:Review','MeridianAutowiki:Selection','MeridianAutowiki:Assessment','MeridianAutowiki:Publish','MeridianAutowiki:Selection']);
 stages.length=0;const result=await publish(f.pkg,f.config,{run,verify,deployment:async()=>({commit:'a'.repeat(40)})});assert.equal(result.active,f.build);assert.equal(stages.at(-1),'MeridianAutowiki:Activate');
});
test('authenticated semantic failures reach review without public approval or activation',async t=>{
 const f=await fixture(t),filename=path.join(f.pkg,'manifest.json');
 const manifest=JSON.parse(await fs.readFile(filename,'utf8'));
 manifest.publicationReady=true;manifest.provenance={dirty:false,configurationInputs:[]};manifest.execution={compiler:'516.1687',runtime:'516.1687'};
 // A syntactically valid fixture intentionally contains invalid documentation
 // visibility values. Mock only builder attestation, not semantic validation.
 await fs.writeFile(filename,JSON.stringify(manifest));f.build=createHash('sha256').update(await fs.readFile(filename)).digest('hex');
 await fs.writeFile(f.config.deploymentFile,JSON.stringify({version:1,id:'fixture-1',commit:'a'.repeat(40),configurationDigest:createHash('sha256').update('[]').digest('hex'),compiler:'516.1687',runtime:'516.1687'}));
 let attestations=0;const verifier=()=>{attestations++;};
 await assert.rejects(verifyRelease(f.pkg,f.config,()=>{throw new Error('Untrusted builder');}),/Untrusted builder/);
 await assert.rejects(fs.access(path.join(f.config.packageStore,'authenticated',f.build+'.json')));
 const approved=path.join(f.config.packageStore,'verified',f.build+'.json');await fs.mkdir(path.dirname(approved),{recursive:true});await fs.writeFile(approved,'old approval');
 await assert.rejects(verifyRelease(f.pkg,f.config,verifier),error=>error instanceof SemanticReviewRequired&&error.build===f.build);
 assert.equal(attestations,1);await assert.rejects(fs.access(approved));
 const receipt=JSON.parse(await fs.readFile(path.join(f.config.packageStore,'authenticated',f.build+'.json'),'utf8'));const report=await fs.readFile(path.join(f.config.packageStore,'review-reports',f.build+'.json'));
 assert.equal(receipt.reportDigest,createHash('sha256').update(report).digest('hex'));assert.equal(JSON.parse(report).report.ok,false);
 const stages=[];const result=await publish(f.pkg,f.config,{verify:(p,c)=>verifyRelease(p,c,verifier),run:(exe,args)=>{const stage=args.find(a=>a.startsWith('MeridianAutowiki:'));stages.push(stage);return JSON.stringify(stage.endsWith(':State')?{active:''}:stage.endsWith(':Selection')?selection(f):{review:f.build});}});
 assert.deepEqual(stages,['MeridianAutowiki:State','MeridianAutowiki:Review','MeridianAutowiki:Selection','MeridianAutowiki:Assessment']);assert.equal(result.reviewRequired,f.build);assert.equal(result.active,'');await assert.rejects(fs.access(approved));
 for(const dataset of manifest.datasets){const file=path.join(f.pkg,dataset.filename);const rows=(await fs.readFile(file,'utf8')).trim().split('\n').map(JSON.parse);for(const row of rows)if(Object.hasOwn(row.fields,'documentation_visibility'))row.fields.documentation_visibility='unknown';const bytes=rows.map(r=>JSON.stringify(r)).join('\n')+'\n';await fs.writeFile(file,bytes);dataset.bytes=Buffer.byteLength(bytes);dataset.sha256=createHash('sha256').update(bytes).digest('hex');}
 await fs.writeFile(filename,JSON.stringify(manifest));const passed=await verifyRelease(f.pkg,f.config,verifier);const passedReport=await fs.readFile(path.join(f.config.packageStore,'review-reports',passed.build+'.json'));assert.equal(JSON.parse(passedReport).report.ok,true);assert.equal(passed.assessmentDigest,createHash('sha256').update(passedReport).digest('hex'));
});

test('a human selection change during preparation stops activation even when the game is unchanged',async t=>{
 const f=await fixture(t);f.config.tgs={};const stages=[];let selections=0,verifications=0;
 const run=(exe,args)=>{const stage=args.find(a=>a.startsWith('MeridianAutowiki:'));stages.push(stage);
  if(stage.endsWith(':State'))return '{"active":""}';
  if(stage.endsWith(':Selection')){const value=selection(f);if(selections++){const plan=JSON.parse(Buffer.from(value.bytes,'base64'));plan.reviewDigest='e'.repeat(64);const bytes=Buffer.from(JSON.stringify(plan));value.bytes=bytes.toString('base64');value.digest=createHash('sha256').update(bytes).digest('hex');}return JSON.stringify(value);}
  return JSON.stringify(stage.endsWith(':Publish')?{prepared:f.build}:{review:f.build});
 };
 await assert.rejects(publish(f.pkg,f.config,{run,deployment:async()=>({commit:'a'.repeat(40)}),verify:async()=>{verifications++;return {build:f.build};}}),/Human selection or active publication changed/);
 assert.equal(verifications,2);assert.ok(stages.includes('MeridianAutowiki:Publish'));assert.ok(!stages.includes('MeridianAutowiki:Activate'));
});

test('an active build is unchanged only when its publication contains the current human revisions',async t=>{
 const f=await fixture(t),destination=path.join(f.config.packageStore,'packages',f.build);await fs.mkdir(path.dirname(destination),{recursive:true});await fs.cp(f.pkg,destination,{recursive:true});
 const pub='1'.repeat(64);let priorDigest='f'.repeat(64);const stages=[];
 const run=(exe,args)=>{const stage=args.find(a=>a.startsWith('MeridianAutowiki:'));stages.push(stage);
  if(stage.endsWith(':State'))return JSON.stringify({active:f.build,publication:{id:pub,reviewDigest:priorDigest}});
  if(stage.endsWith(':Selection')){const value=selection(f),plan=JSON.parse(Buffer.from(value.bytes,'base64'));plan.expected=f.build;plan.expectedPublication=pub;plan.previous.build=f.build;const bytes=Buffer.from(JSON.stringify(plan));return JSON.stringify({...value,bytes:bytes.toString('base64'),digest:createHash('sha256').update(bytes).digest('hex')});}
  return JSON.stringify(stage.endsWith(':Publish')?{active:f.build,delivery:'queued'}:{review:f.build});
 };
 const dependencies={run,verify:async()=>({build:f.build})};assert.equal((await publish(f.pkg,f.config,dependencies)).delivery,'unchanged');assert.ok(!stages.includes('MeridianAutowiki:Publish'));
 stages.length=0;priorDigest='e'.repeat(64);assert.equal((await publish(f.pkg,f.config,dependencies)).delivery,'queued');assert.ok(stages.includes('MeridianAutowiki:Publish'));
});
