import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {receive} from './receiver.js';
test('receiver waits for exact clean source and records failure without changing the active build',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-receiver-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));const inbox=path.join(root,'inbox');await fs.mkdir(inbox);
 const config={inbox,statusFile:path.join(root,'status.json')};const deployment=async()=>({commit:'a'.repeat(40),runtime:'516.1687',id:'tgs-1-71'});let writes=0;
 const publish=async()=>{writes++;return {active:'b'.repeat(64)};};assert.equal((await receive(config,{deployment,publish})).state,'awaiting-package');assert.equal(writes,0);
 await fs.mkdir(path.join(inbox,'review'));const manifest=path.join(inbox,'review','manifest.json');await fs.writeFile(manifest,JSON.stringify({source:{commit:'a'.repeat(40)},publicationReady:false,provenance:{dirty:true}}));assert.equal((await receive(config,{deployment,publish})).state,'awaiting-package');
 await fs.writeFile(manifest,JSON.stringify({source:{commit:'a'.repeat(40)},publicationReady:true,provenance:{dirty:false}}));assert.equal((await receive(config,{deployment,publish})).state,'published');assert.equal(writes,1);
 assert.equal((await receive(config,{deployment,publish:async()=>{throw new Error('private credential detail');}})).state,'failed');assert.ok(!(await fs.readFile(config.statusFile,'utf8')).includes('credential'));assert.equal(writes,1);
});
test('receiver excludes overlapping cycles and releases its lock after failure',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-lock-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const config={inbox:root,statusFile:path.join(root,'status.json')};let release;const pending=new Promise(resolve=>{release=resolve;});let entered;const ready=new Promise(resolve=>{entered=resolve;});
 const first=receive(config,{deployment:async()=>{entered();await pending;throw new Error('fixture');}});await ready;
 assert.equal((await receive(config,{deployment:async()=>{throw new Error('must not run');}})).state,'busy');release();assert.equal((await first).state,'failed');
 assert.equal((await receive(config,{deployment:async()=>({commit:'a'.repeat(40)})})).state,'awaiting-package');
});
test('receiver uses retrieved packages through the existing publisher and exposes bounded waiting reasons',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-receive-fetch-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));const inbox=path.join(root,'inbox');await fs.mkdir(inbox);
 const config={inbox,statusFile:path.join(root,'status.json'),artifactSource:{}};const deployment=async()=>({commit:'a'.repeat(40),testMerges:3});let writes=0;
 const publish=async()=>{writes++;return {active:'b'.repeat(64)};};
 const wait=await receive(config,{deployment,publish,retrieve:async()=>({state:'test-merge-build'})});assert.equal(wait.state,'awaiting-package');assert.equal(wait.artifactState,'test-merge-build');assert.equal(writes,0);
 const done=await receive(config,{deployment,publish,retrieve:async()=>({state:'downloaded',directory:path.join(inbox,'fixture')})});assert.equal(done.state,'published');assert.equal(writes,1);
 const review=await receive(config,{deployment,publish:async()=>({reviewRequired:'c'.repeat(64),active:'b'.repeat(64)}),retrieve:async()=>({state:'downloaded',directory:path.join(inbox,'fixture')})});assert.equal(review.state,'review-required');assert.equal(review.build,'c'.repeat(64));
});
test('receiver requests generation only for missing packages and preserves observable run status',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-request-cycle-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));const inbox=path.join(root,'inbox');await fs.mkdir(inbox);
 const config={inbox,statusFile:path.join(root,'status.json'),artifactSource:{},buildRequests:{enabled:true}};let requests=0;
 const dependencies={deployment:async()=>({commit:'a'.repeat(40),testMerges:1}),retrieve:async()=>({state:'no-matching-run'}),requestBuild:async()=>{requests++;return {state:'build-running',runId:7};},publish:async()=>({active:'b'.repeat(64)})};
 const pending=await receive(config,dependencies);assert.equal(pending.state,'awaiting-package');assert.equal(pending.artifactState,'build-running');assert.equal(pending.buildRunId,7);assert.equal(requests,1);
 await receive(config,{...dependencies,retrieve:async()=>({state:'credential-required'})});assert.equal(requests,1);
 const published=await receive(config,{...dependencies,retrieve:async()=>({state:'downloaded',directory:path.join(inbox,'package')})});assert.equal(published.state,'published');assert.equal(requests,1);
 await receive({...config,buildRequests:{enabled:false}},dependencies);assert.equal(requests,1);
});
