import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {requestMissingBuild,dispatchBuild,approvedBuilderRef} from './build-request.js';
import {builderRef,testMergeArtifact} from './source-binding.js';
import {REPOSITORY,findArtifact} from './artifact-source.js';

async function fixture(t){
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-request-'));t.after(async()=>{if(path.dirname(root)!==path.resolve(os.tmpdir())||!path.basename(root).startsWith('autowiki-request-'))throw Error('Unsafe cleanup');await fs.rm(root,{recursive:true,force:true});});
 const tokenFile=path.join(root,'service-token');await fs.writeFile(tokenFile,'fixture_service_token_123456789');
 const pin='a'.repeat(40),config={testMergeBuilderCommit:pin,buildRequests:{enabled:true,directory:path.join(root,'requests'),githubTokenFile:tokenFile}};
 const deployment={commit:'b'.repeat(40),originCommit:'c'.repeat(40),sourceTree:'d'.repeat(40),testMerges:1,mergeIdentities:[{number:1,commit:'e'.repeat(40)}]};
 let runs=[],master=pin,posts=0,input,result={state:'accepted',runId:7};
 const client={json:async endpoint=>endpoint.endsWith('/git/ref/heads/master')?{ref:'refs/heads/master',object:{type:'commit',sha:master}}:endpoint.includes('/runs?')?{total_count:runs.length,workflow_runs:runs}:/\/runs\/\d+$/.test(endpoint)?runs.find(r=>endpoint.endsWith('/'+r.id)):{id:2,path:'.github/workflows/autowiki-test-merges.yml',state:'active'}};
 const dispatch=async value=>{posts++;input=value;const files=await fs.readdir(config.buildRequests.directory);assert.equal(files.length,1);const claim=JSON.parse(await fs.readFile(path.join(config.buildRequests.directory,files[0]),'utf8'));assert.equal(claim.state,'dispatching');assert.equal(claim.key,value.request_id);return result;};
 const run=(state='in_progress',conclusion=null)=>({id:7,workflow_id:2,head_sha:pin,head_branch:'master',event:'workflow_dispatch',display_title:'Autowiki source '+input.request_id,repository:{full_name:REPOSITORY},head_repository:{full_name:REPOSITORY},status:state,conclusion});
 return {root,config,deployment,client,dispatch,run,get posts(){return posts;},get input(){return input;},set runs(value){runs=value;},set master(value){master=value;},set result(value){result=value;}};
}

test('persistent requests dispatch once, follow actual runs and retain terminal failures',async t=>{
 const f=await fixture(t),deps={client:f.client,dispatch:f.dispatch};
 const first=await requestMissingBuild(f.deployment,f.config,deps);assert.equal(first.state,'build-requested');assert.equal(f.posts,1);assert.equal(f.input.builder_commit,f.config.testMergeBuilderCommit);
 f.runs=[f.run()];assert.equal((await requestMissingBuild(f.deployment,f.config,deps)).state,'build-running');assert.equal(f.posts,1);
 f.runs=[f.run('completed','failure')];assert.equal((await requestMissingBuild(f.deployment,f.config,deps)).state,'build-failed');assert.equal(f.posts,1);
 f.runs=[f.run('queued')];assert.equal((await requestMissingBuild(f.deployment,f.config,deps)).state,'build-running');
 f.runs=[f.run('completed','success')];assert.equal((await requestMissingBuild(f.deployment,f.config,deps)).state,'build-finished');assert.equal(f.posts,1);
 const original=f.client.json,artifact={id:9,name:testMergeArtifact(f.deployment),expired:false,expires_at:'2099-01-01T00:00:00Z',size_in_bytes:100,digest:'sha256:'+'a'.repeat(64)};
 const lookup={json:async endpoint=>{if(endpoint.includes('/artifacts?'))return {total_count:1,artifacts:[artifact]};if(endpoint.includes('/runs?'))throw Error('Known run must not depend on accumulated workflow history');return original(endpoint);}};
 assert.equal((await findArtifact(f.deployment,lookup,f.config)).artifact.id,9);
 f.runs=[{...f.run(),head_sha:'f'.repeat(40)}];await assert.rejects(requestMissingBuild(f.deployment,f.config,deps),/approved identity/);
});

test('lost response is reconciled without a second POST and rejected requests do not loop',async t=>{
 const f=await fixture(t),deps={client:f.client,dispatch:f.dispatch};f.result={state:'uncertain'};
 assert.equal((await requestMissingBuild(f.deployment,f.config,deps)).state,'build-uncertain');assert.equal((await requestMissingBuild(f.deployment,f.config,deps)).state,'build-uncertain');assert.equal(f.posts,1);
 f.runs=[f.run()];assert.equal((await requestMissingBuild(f.deployment,f.config,deps)).state,'build-running');assert.equal(f.posts,1);
 const rejected=await fixture(t);rejected.result={state:'rejected',httpStatus:403};const rejectDeps={client:rejected.client,dispatch:rejected.dispatch};assert.equal((await requestMissingBuild(rejected.deployment,rejected.config,rejectDeps)).state,'build-request-rejected');assert.equal((await requestMissingBuild(rejected.deployment,rejected.config,rejectDeps)).state,'build-request-rejected');assert.equal(rejected.posts,1);
 const retryKey=rejected.input.request_id;assert.equal((await requestMissingBuild(rejected.deployment,rejected.config,{...rejectDeps,retryRejected:'f'.repeat(64)})).state,'build-request-rejected');assert.equal(rejected.posts,1);rejected.result={state:'accepted',runId:7};assert.equal((await requestMissingBuild(rejected.deployment,rejected.config,{...rejectDeps,retryRejected:retryKey})).state,'build-requested');assert.equal(rejected.posts,2);assert.equal(JSON.parse(await fs.readFile(path.join(rejected.config.buildRequests.directory,retryKey+'.json'),'utf8')).previousAttempts.length,1);
});

test('disabled requests, missing dedicated credentials and unapproved master cannot dispatch',async t=>{
 const f=await fixture(t),deps={client:f.client,dispatch:f.dispatch};
 assert.equal((await requestMissingBuild(f.deployment,{...f.config,buildRequests:{enabled:false}},deps)).state,'disabled');
 assert.equal((await requestMissingBuild(f.deployment,{...f.config,githubTokenFile:f.config.buildRequests.githubTokenFile,buildRequests:{...f.config.buildRequests,githubTokenFile:undefined}},deps)).state,'request-credential-required');
 f.master='f'.repeat(40);assert.equal((await requestMissingBuild(f.deployment,f.config,deps)).state,'builder-update-required');assert.equal(f.posts,0);
});

test('simultaneous first observations share an exclusive durable dispatch claim',async t=>{
 const f=await fixture(t);f.result={state:'uncertain'};const original=f.client.json;let arrived=0,release;const ready=new Promise(resolve=>release=resolve);
 f.client.json=async endpoint=>{if(endpoint.includes('/runs?')){if(++arrived===2)release();await ready;}return original(endpoint);};
 const results=await Promise.all([requestMissingBuild(f.deployment,f.config,{client:f.client,dispatch:f.dispatch}),requestMissingBuild(f.deployment,f.config,{client:f.client,dispatch:f.dispatch})]);assert.equal(f.posts,1);assert.ok(results.every(r=>r.state==='build-uncertain'));
});

test('dispatch accepts current run IDs, bounds responses and does not leak credentials or raw errors',async()=>{
 let seen;const input={source_plan:'{}',builder_commit:'a'.repeat(40),request_id:'b'.repeat(64)};
 const value=await dispatchBuild('fixture-secret',input,async(url,options)=>{seen={url,options};return new Response(JSON.stringify({workflow_run_id:42,html_url:'https://untrusted.invalid'}));});assert.deepEqual(value,{state:'accepted',runId:42});assert.equal(seen.options.method,'POST');assert.equal(seen.options.redirect,'error');assert.deepEqual(JSON.parse(seen.options.body),{ref:'master',inputs:input});assert.ok(seen.url.endsWith('/actions/workflows/autowiki-test-merges.yml/dispatches'));
 assert.deepEqual(await dispatchBuild('secret',input,async()=>new Response(null,{status:204})),{state:'accepted'});
 assert.deepEqual(await dispatchBuild('secret',input,async()=>new Response('private rejection',{status:403})),{state:'rejected',httpStatus:403});
 for(const fetcher of [async()=>{throw Error('private token or response');},async()=>new Response('x'.repeat(9000)),async()=>new Response('private failure',{status:502})])assert.deepEqual(await dispatchBuild('secret',input,fetcher),{state:'uncertain'});
});

test('approved builder releases keep working when master advances and moving tags are refused',async t=>{
 const f=await fixture(t),ref='refs/tags/autowiki-builder-fixture',pin=f.config.testMergeBuilderCommit;f.config.testMergeBuilderRef=ref;f.master='f'.repeat(40);
 const original=f.client.json;f.client.json=async endpoint=>{if(endpoint.endsWith('/git/ref/heads/master'))throw Error('Frozen builder must not depend on master');if(endpoint.endsWith('/git/ref/tags/autowiki-builder-fixture'))return {ref,object:{type:'tag',sha:'1'.repeat(40)}};if(endpoint.endsWith('/git/tags/'+'1'.repeat(40)))return {sha:'1'.repeat(40),object:{type:'commit',sha:pin}};return original(endpoint);};
 const result=await requestMissingBuild(f.deployment,f.config,{client:f.client,dispatch:f.dispatch});assert.equal(result.state,'build-requested');assert.equal(f.input.builder_ref,ref);f.runs=[{...f.run(),head_branch:'autowiki-builder-fixture'}];assert.equal((await requestMissingBuild(f.deployment,f.config,{client:f.client,dispatch:f.dispatch})).state,'build-running');assert.equal(f.posts,1);
 assert.equal(await approvedBuilderRef({json:async()=>({ref,object:{type:'commit',sha:'f'.repeat(40)}})},f.config),false);
 const cycle={json:async endpoint=>endpoint.includes('/git/ref/')?{ref,object:{type:'tag',sha:'1'.repeat(40)}}:{sha:'1'.repeat(40),object:{type:'tag',sha:'1'.repeat(40)}}};assert.equal(await approvedBuilderRef(cycle,f.config),false);
 let body;await dispatchBuild('fixture-secret',f.input,async(url,options)=>{body=JSON.parse(options.body);return new Response(JSON.stringify({workflow_run_id:7}));});assert.equal(body.ref,'autowiki-builder-fixture');
 for(const invalid of ['refs/heads/feature','refs/tags/arbitrary','refs/tags/autowiki-builder-../escape','refs/tags/autowiki-builder-v1.lock','refs/tags/autowiki-builder-v1?query'])assert.throws(()=>builderRef({testMergeBuilderRef:invalid}));
});
