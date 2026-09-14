import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {TgsClient,activeBuild,observe,sourceDeployment} from './tgs.js';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const directory='11111111-2222-3333-4444-555555555555';
const daemon=()=>({status:2,activeCompileJob:{id:10,directoryName:directory,revisionInformation:{commitSha:'a'.repeat(40),activeTestMerges:[]},engineVersion:{engine:0,version:'516.1687.0'},repositoryOrigin:'https://github.com/Aphelion-Moon/Meridian-Rift'},stagedCompileJob:{id:11,revisionInformation:{commitSha:'b'.repeat(40)}}});

test('TGS preserves exact merge heads and sorts the API collection by merge time',()=>{
 const response=daemon(),early={number:12,id:1,targetCommitSha:'c'.repeat(40),mergedAt:'2026-09-12T00:00:00Z'},late={number:13,id:2,targetCommitSha:'d'.repeat(40),mergedAt:'2026-09-12T00:01:00Z'};
 response.activeCompileJob.revisionInformation.originCommitSha='e'.repeat(40);response.activeCompileJob.revisionInformation.activeTestMerges=[late,early];
 const result=activeBuild(response,1);assert.equal(result.originCommit,'e'.repeat(40));assert.deepEqual(result.mergeIdentities.map(m=>m.commit),['c'.repeat(40),'d'.repeat(40)]);
 for(const invalid of [[early,early],[{...early,targetCommitSha:'moving-branch'}],[{...early,mergedAt:'invalid'}]]){response.activeCompileJob.revisionInformation.activeTestMerges=invalid;assert.throws(()=>activeBuild(response,1),/merge identity/);}
});
test('TGS selects active revision and refuses missing permissions or offline state',()=>{
 assert.equal(activeBuild(daemon(),1).commit,'a'.repeat(40));assert.equal(activeBuild(daemon(),1).byond,'516.1687');
 for(const changed of [{status:0},{activeCompileJob:null},{activeCompileJob:{...daemon().activeCompileJob,revisionInformation:{}}}])assert.throws(()=>activeBuild({...daemon(),...changed},1));
});
test('source-default evidence hashes the active Git object instead of local configuration',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-source-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const build=path.join(root,'Game',directory);await fs.mkdir(build,{recursive:true});await fs.symlink(build,path.join(root,'Game','Live'),'junction');
 const repository=path.join(root,'repo');await fs.mkdir(path.join(repository,'config'),{recursive:true});
 const git=args=>execFileSync('git',['-C',repository,...args],{stdio:['ignore','pipe','pipe']}).toString().trim();
 git(['init']);git(['config','core.autocrlf','false']);await fs.writeFile(path.join(repository,'config','defaults.txt'),'committed settings\n');git(['add','.']);git(['-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','fixture']);const commit=git(['rev-parse','HEAD']);
 await fs.writeFile(path.join(repository,'config','defaults.txt'),'different local settings\n');
 const credentialsFile=path.join(root,'credentials.txt');await fs.writeFile(credentialsFile,'username: fixture\npassword: fixture\n');
 const fetcher=async(url,options)=>({ok:true,json:async()=>options.method==='POST'?{bearer:'fixture'}:{...daemon(),activeCompileJob:{...daemon().activeCompileJob,revisionInformation:{commitSha:commit}}}});
 const receipt=await sourceDeployment({url:'http://127.0.0.1:5000/api',credentialsFile,instanceId:1,instancePath:root,repository},fetcher);
 const hash=bytes=>createHash('sha256').update(bytes).digest('hex');assert.equal(receipt.configurationDigest,hash(JSON.stringify([{name:'config/defaults.txt',sha256:hash('committed settings\n')}])));assert.equal(receipt.sourceTree,git(['rev-parse','HEAD^{tree}']));assert.equal(receipt.commit,commit);assert.equal(receipt.configurationScope,'source-defaults');
});
test('TGS client does not send credentials to cleartext remote hosts or expose response errors',async t=>{
 assert.throws(()=>new TgsClient({url:'http://example.com/api'}),/HTTPS/);
 const client=new TgsClient({url:'http://127.0.0.1:5000/api'},async()=>({ok:false,status:403,json:async()=>({secret:'never print this'})}));
 await assert.rejects(client.request('/Instance/List'),{message:'TGS /Instance/List returned HTTP 403'});
});
test('TGS observation authenticates locally, validates Live and remains ineligible for publication',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-tgs-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const build=path.join(root,'Game',directory,'A');await fs.mkdir(build,{recursive:true});await fs.symlink(build,path.join(root,'Game','Live'),'junction');
 const credentialsFile=path.join(root,'credentials.txt');await fs.writeFile(credentialsFile,'username: fixture\npassword: fixture-secret\n');let reads=0;const calls=[];
 const fetcher=async(url,options)=>{calls.push({url,method:options.method});return {ok:true,json:async()=>options.method==='POST'?{bearer:'fixture-token'}:(reads++,daemon())};};
 const config={url:'http://127.0.0.1:5000/api',credentialsFile,instanceId:1,instancePath:root};
 const result=await observe(config,fetcher);assert.equal(result.publicationReady,false);assert.equal(reads,2);assert.deepEqual(calls.map(c=>c.method),['POST','GET','GET']);assert.ok(!JSON.stringify(result).includes('fixture-secret'));
 let n=0;await assert.rejects(observe(config,async(url,options)=>({ok:true,json:async()=>options.method==='POST'?{bearer:'fixture-token'}:{...daemon(),activeCompileJob:{...daemon().activeCompileJob,id:10+n++}}})),/changed builds/);
});
