import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import contract from './contract.json' with {type:'json'};
import {packageExport} from './data-contract.js';
import {signingSource,signingBuild} from './check-signing-input.js';
import {prepareMergedSource} from './prepare-merged-source.js';
import {bindMergedPackage} from './bind-merged-package.js';
import {planDigest,validateSourceBinding,matchesDeployment,testMergeArtifact} from './source-binding.js';
import {verifyRelease} from './release.js';
import {publish} from './publish.js';
import {findArtifact,REPOSITORY} from './artifact-source.js';
const hash=value=>createHash('sha256').update(value).digest('hex');

test('merged source is reproduced twice and authenticated independently of its synthetic commit label',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-binding-'));t.after(async()=>{if(path.dirname(root)!==path.resolve(os.tmpdir())||!path.basename(root).startsWith('autowiki-binding-'))throw new Error('Unsafe cleanup');await fs.rm(root,{recursive:true,force:true});});
 const repository=path.join(root,'repo');await fs.mkdir(path.join(repository,'config'),{recursive:true});await fs.mkdir(path.join(repository,'code/modules/autowiki'),{recursive:true});
 await fs.writeFile(path.join(repository,'dependencies.sh'),'export BYOND_MAJOR=516\nexport BYOND_MINOR=1687\n');await fs.writeFile(path.join(repository,'config/game.txt'),'defaults');await fs.writeFile(path.join(repository,'code/modules/autowiki/structured.dm'),'// fixture');
 const git=args=>execFileSync('git',['-C',repository,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgSign=false',...args],{stdio:['ignore','pipe','pipe']}).toString().trim();
 git(['init']);git(['config','core.autocrlf','false']);git(['add','.']);git(['commit','-m','origin']);const originCommit=git(['rev-parse','HEAD']);await fs.writeFile(path.join(repository,'new.txt'),'merged');git(['add','.']);git(['commit','-m','merge head']);const head=git(['rev-parse','HEAD']),tree=git(['rev-parse','HEAD^{tree}']);
 const plan={version:1,originCommit,sourceTree:tree,merges:[{number:12,commit:head}]};
 const before=git(['show-ref']);const generated=await prepareMergedSource(plan,path.join(root,'generation'),repository),checked=await prepareMergedSource(plan,path.join(root,'signing'),repository);assert.equal(generated.generatedCommit,checked.generatedCommit);assert.equal(git(['show-ref']),before);
 await assert.rejects(prepareMergedSource({...plan,sourceTree:'b'.repeat(40)},path.join(root,'wrong-tree'),repository),/requested tree/);
 await assert.rejects(prepareMergedSource({...plan,merges:[{number:12,commit:'master'}]},path.join(root,'moving-ref'),repository),/pinned/);
 const source=signingSource(path.join(root,'generation/source'),generated.generatedCommit);
 const records=Object.entries(contract.fields).map(([kind,fields])=>({kind,id:'/datum/'+kind+'/fixture',fields:Object.fromEntries(Object.entries(fields).filter(([field])=>kind!=='entity'||!contract.optionalEntity.includes(field)).map(([field,types])=>[field,types.includes('array')?[]:types.includes('number')?0:types.includes('string')?'example':null]))}));records.find(r=>r.kind==='entity').fields.icon_file=null;
 for(const record of records){if('documentation_id' in record.fields)record.fields.documentation_id=null;if('documentation_visibility' in record.fields)record.fields.documentation_visibility='unknown';}
 const rows=[{kind:'header',schema_version:2,profile:'source-defaults',time_unit:'decisecond',appearance_profile:'initial-south-first-frame',compiler:source.byond,runtime:source.byond},...records,{kind:'complete',counts:Object.fromEntries(records.map(r=>[r.kind,1]))}];
 const input=path.join(root,'input.jsonl'),icons=path.join(root,'icons'),candidate=path.join(root,'candidate');await fs.mkdir(icons);await fs.writeFile(input,rows.map(r=>JSON.stringify(r)).join('\n'));
 await packageExport(input,icons,candidate,generated.generatedCommit,undefined,{commit:generated.generatedCommit,dirty:false,configurationInputs:source.configurationInputs,exporterSha256:source.exporterSha256,workingDiffSha256:hash(''),untracked:[],build:signingBuild,compiler:{sha256:'a'.repeat(64)}});
 const pin='c'.repeat(40),binding=await bindMergedPackage(candidate,path.join(root,'signing/source'),plan,pin),manifestBytes=await fs.readFile(path.join(candidate,'manifest.json'));
 const deployment={version:1,id:'tgs-1-71',commit:'d'.repeat(40),originCommit,sourceTree:tree,testMerges:1,mergeIdentities:plan.merges,compiler:source.byond,runtime:source.byond,configurationScope:'source-defaults',configurationDigest:hash(JSON.stringify(source.configurationInputs)),observedAt:new Date().toISOString()};
 const config={testMergeBuilderCommit:pin,packageStore:path.join(root,'store'),deploymentFile:path.join(root,'deployment.json')};await fs.writeFile(config.deploymentFile,JSON.stringify(deployment));
 assert.equal(validateSourceBinding(binding,manifestBytes,deployment,config),binding);assert.equal(await matchesDeployment(candidate,JSON.parse(manifestBytes),deployment),true);
 for(const changed of [{sourceTree:'e'.repeat(40)},{originCommit:'e'.repeat(40)},{configurationDigest:'e'.repeat(64)},{runtime:'516.1'},{mergeIdentities:[{number:12,commit:originCommit}]}])assert.throws(()=>validateSourceBinding(binding,manifestBytes,{...deployment,...changed},config));
 assert.throws(()=>validateSourceBinding({...binding,manifestDigest:'e'.repeat(64)},manifestBytes,deployment,config));assert.throws(()=>validateSourceBinding(binding,manifestBytes,deployment,{testMergeBuilderCommit:'e'.repeat(40)}));
 let calls=0;const verify=args=>{calls++;assert.ok(args.includes(path.join(candidate,'source-binding.json')));assert.equal(args[args.indexOf('--source-digest')+1],pin);assert.equal(args[args.indexOf('--signer-workflow')+1],REPOSITORY+'/.github/workflows/autowiki-test-merges.yml');assert.ok(args.includes('--deny-self-hosted-runners'));};
 const receipt=await verifyRelease(candidate,config,verify);assert.equal(receipt.commit,deployment.commit);assert.equal(calls,1);assert.equal((await fs.readdir(path.join(config.packageStore,'authenticated'))).length,1);
 // Real copy, selection assessment, repeated signature validation and deployment checks;
 // only the external signature service and PHP maintenance boundary are fixture adapters.
 const stages=[],publicationConfig={...config,tgs:{},php:path.join(root,'php'),maintenanceRunner:path.join(root,'run.php'),settings:path.join(root,'settings.php')};
 const run=(exe,args)=>{const stage=args.find(a=>a.startsWith('MeridianAutowiki:'));stages.push(stage);if(stage.endsWith(':State'))return '{"active":""}';if(stage.endsWith(':Selection')){const bytes=Buffer.from(JSON.stringify({version:1,build:receipt.build,expected:'',expectedPublication:'',reviewDigest:'f'.repeat(64),replacements:[],corrections:[],previous:{build:'',replacements:[],corrections:[]}}));return JSON.stringify({build:receipt.build,bytes:bytes.toString('base64'),digest:hash(bytes)});}return JSON.stringify(stage.endsWith(':Publish')?{prepared:receipt.build}:stage.endsWith(':Activate')?{active:receipt.build}:{review:receipt.build});};
 const dependencies={run,deployment:async()=>deployment,verify:(dir,cfg)=>verifyRelease(dir,cfg,args=>assert.equal(path.basename(args[2]),'source-binding.json'))};
 assert.equal((await publish(candidate,publicationConfig,dependencies)).active,receipt.build);assert.ok(stages.includes('MeridianAutowiki:Activate'));assert.ok(await fs.stat(path.join(config.packageStore,'packages',receipt.build,'source-binding.json')));
 stages.length=0;let observations=0;await assert.rejects(publish(candidate,publicationConfig,{...dependencies,deployment:async()=>observations++?{...deployment,sourceTree:'e'.repeat(40)}:deployment}),/running merged source/);assert.ok(stages.includes('MeridianAutowiki:Publish'));assert.ok(!stages.includes('MeridianAutowiki:Activate'));
 await fs.writeFile(config.deploymentFile,JSON.stringify(deployment));
 const releaseRef='refs/tags/autowiki-builder-fixture',tagCandidate=path.join(root,'tag-candidate');await fs.cp(candidate,tagCandidate,{recursive:true});await fs.unlink(path.join(tagCandidate,'source-binding.json'));
 const tagBinding=await bindMergedPackage(tagCandidate,path.join(root,'signing/source'),plan,pin,releaseRef);assert.notEqual(tagBinding.manifestDigest,binding.manifestDigest,'Builder ref contributes to immutable package identity');
 await verifyRelease(tagCandidate,{...config,testMergeBuilderRef:releaseRef},args=>{assert.equal(args[args.indexOf('--source-ref')+1],releaseRef);assert.equal(args[args.indexOf('--source-digest')+1],pin);});
 await assert.rejects(verifyRelease(tagCandidate,config,()=>{throw Error('Must reject before signature verification');}),/reference differs/);
 await assert.rejects(verifyRelease(candidate,config,()=>{throw new Error('Attestation rejected');}),/Attestation rejected/);
 await assert.rejects(verifyRelease(candidate,config,()=>{execFileSync(process.execPath,['-e','require("fs").appendFileSync(process.argv[1]," ")',path.join(candidate,'source-binding.json')]);}),/binding changed/);
 // Order is part of source identity even when independent merges could share a tree.
 const multiple={...plan,merges:[...plan.merges,{number:13,commit:originCommit}]};assert.notEqual(planDigest(multiple),planDigest({...multiple,merges:[...multiple.merges].reverse()}));
});

test('test-merge locator pins the builder and finds only the exact source plan',async()=>{
 const pin='a'.repeat(40),deployment={commit:'b'.repeat(40),originCommit:'c'.repeat(40),sourceTree:'d'.repeat(40),testMerges:1,mergeIdentities:[{number:1,commit:'e'.repeat(40)}]};
 const workflow={id:1,path:'.github/workflows/autowiki-test-merges.yml',state:'active'},base={workflow_id:1,head_sha:pin,head_branch:'master',status:'completed',conclusion:'success',event:'workflow_dispatch',repository:{full_name:REPOSITORY},head_repository:{full_name:REPOSITORY}};
 const artifact={id:5,name:testMergeArtifact(deployment),expired:false,expires_at:'2099-01-01T00:00:00Z',size_in_bytes:100,digest:'sha256:'+'f'.repeat(64)};
 const client={json:async endpoint=>{if(endpoint.includes('/runs?')){assert.ok(endpoint.includes('head_sha='+pin));return {total_count:2,workflow_runs:[{...base,id:3},{...base,id:2}]};}if(endpoint.includes('/runs/3/artifacts'))return {total_count:0,artifacts:[]};if(endpoint.includes('/artifacts?'))return {total_count:1,artifacts:[artifact]};assert.ok(endpoint.endsWith('/autowiki-test-merges.yml'));return workflow;}};
 assert.equal((await findArtifact(deployment,client,{testMergeBuilderCommit:pin})).artifact.id,5);
 assert.equal((await findArtifact(deployment,{json:()=>{throw Error('should not query');}})).state,'test-merge-build');
 await assert.rejects(findArtifact(deployment,client,{testMergeBuilderCommit:'master'}),/pinned/);
 const tag='autowiki-builder-fixture',tagClient={json:async endpoint=>{if(endpoint.includes('/runs?')){assert.ok(!endpoint.includes('branch=master'));return {total_count:1,workflow_runs:[{...base,id:2,head_branch:tag}]};}return client.json(endpoint);}};
 assert.equal((await findArtifact(deployment,tagClient,{testMergeBuilderCommit:pin,testMergeBuilderRef:'refs/tags/'+tag})).artifact.id,5);
});
