import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {createHash} from 'node:crypto';
import {findArtifact,githubClient,retrieveArtifact,REPOSITORY} from './artifact-source.js';
const commit='a'.repeat(40);
const workflow={id:10,path:'.github/workflows/autowiki.yml',state:'active'};
const run={id:20,workflow_id:10,head_sha:commit,head_branch:'master',status:'completed',conclusion:'success',event:'push',repository:{full_name:REPOSITORY},head_repository:{full_name:REPOSITORY}};
const artifact={id:30,name:'autowiki-publication-'+commit,expired:false,expires_at:'2099-01-01T00:00:00Z',size_in_bytes:3,digest:'sha256:'+createHash('sha256').update('zip').digest('hex')};
function clientFor(runs=[run],artifacts=[artifact],wf=workflow){return {json:async endpoint=>endpoint.includes('/artifacts?')?{total_count:artifacts.length,artifacts}:endpoint.includes('/runs?')?{total_count:runs.length,workflow_runs:runs}:wf};}
test('artifact locator requires the exact successful trusted workflow source',async()=>{
 assert.equal((await findArtifact({commit},clientFor())).artifact.id,30);
 for(const changed of [{head_sha:'b'.repeat(40)},{head_branch:'feature'},{workflow_id:999},{status:'in_progress'},{conclusion:'failure'},{event:'pull_request'},{head_repository:{full_name:'fork/Meridian-Rift'}}])assert.equal((await findArtifact({commit},clientFor([{...run,...changed}]))).state,'no-matching-run');
 await assert.rejects(findArtifact({commit},clientFor([],[],{...workflow,path:'.github/workflows/other.yml'})),/workflow/);
 assert.equal((await findArtifact({commit,testMerges:3},{json:()=>{throw new Error('must not query master');}})).state,'test-merge-build');
});
test('artifact inventory rejects ambiguity and invalid digest and reports expiry',async()=>{
 assert.equal((await findArtifact({commit},clientFor([run],[]))).state,'no-package-artifact');
 assert.equal((await findArtifact({commit},clientFor([run],[{...artifact,expired:true}]))).state,'expired-artifact');
 for(const changed of [{digest:null},{size_in_bytes:2**31},{id:'30'},{expires_at:'invalid'}])await assert.rejects(findArtifact({commit},clientFor([run],[{...artifact,...changed}])));
 await assert.rejects(findArtifact({commit},clientFor([run],[artifact,{...artifact,id:31}])),/Ambiguous/);
 const many=clientFor();many.json=async endpoint=>endpoint.includes('/runs?')?{total_count:101,workflow_runs:[run]}:workflow;
 await assert.rejects(findArtifact({commit},many),/bound/);
});
test('download token stays at GitHub API and archive bytes must match digest',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-download-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const calls=[];const request=async(url,options)=>{calls.push({url:String(url),options});return String(url).startsWith('https://api.github.com/')?new Response(null,{status:302,headers:{location:'https://example.blob.core.windows.net/artifact?signed=yes'}}):new Response('zip');};
 await githubClient('fixture-secret',request).download(artifact,path.join(root,'good.zip'));
 assert.equal(calls[0].options.headers.Authorization,'Bearer fixture-secret');assert.equal(calls[1].options.headers,undefined);assert.equal(calls[1].options.redirect,'error');
 await assert.rejects(githubClient('fixture-secret',request).download({...artifact,digest:'sha256:'+'0'.repeat(64)},path.join(root,'bad.zip')),/checksum/);
 await assert.rejects(githubClient('fixture-secret',async()=>new Response(null,{status:302,headers:{location:'https://attacker.example/artifact'}})).download(artifact,path.join(root,'redirect.zip')),/storage host/);
 await assert.rejects(githubClient('',async()=>new Response('zip-too-long')).download(artifact,path.join(root,'large.zip')),/redirect/);
 const failure=githubClient('fixture-secret',async()=>{throw new Error('leaked signed URL');});await assert.rejects(failure.json('/repos/'+REPOSITORY+'/actions/workflows/autowiki.yml'),error=>!error.message.includes('leaked'));
});
test('retrieval promotes only complete matching packages and cleans failed downloads',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-retrieve-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));const inbox=path.join(root,'inbox');await fs.mkdir(inbox);
 const config={inbox,artifactSource:{python:path.join(root,'python')}};const client=clientFor();client.download=async(a,file)=>fs.writeFile(file,'zip');
 let manifest={source:{commit},publicationReady:true,provenance:{dirty:false}};
 const deps={client,extract:async(input,output)=>{await fs.mkdir(output);await fs.writeFile(path.join(output,'manifest.json'),JSON.stringify(manifest));},readPackage:async dir=>({manifest:JSON.parse(await fs.readFile(path.join(dir,'manifest.json'),'utf8'))})};
 const result=await retrieveArtifact({commit},config,deps);assert.equal(result.state,'downloaded');assert.equal((await fs.readdir(inbox)).length,1);assert.deepEqual(await fs.readdir(path.join(root,'artifact-downloads')),[]);
 assert.equal((await retrieveArtifact({commit},config,deps)).directory,result.directory);
 manifest={...manifest,source:{commit:'b'.repeat(40)}};await assert.rejects(retrieveArtifact({commit},config,deps),/deployment/);assert.equal((await fs.readdir(inbox)).length,1);assert.deepEqual(await fs.readdir(path.join(root,'artifact-downloads')),[]);
 await assert.rejects(retrieveArtifact({commit},config,{...deps,extract:async()=>{throw new Error('invalid archive');}}),/archive/);assert.deepEqual(await fs.readdir(path.join(root,'artifact-downloads')),[]);
});
