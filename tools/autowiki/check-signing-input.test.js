import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import contract from './contract.json' with {type:'json'};
import {packageExport} from './data-contract.js';
import {signingSource,signingBuild,checkSigningInput,validateSigningIdentity} from './check-signing-input.js';

test('independent signing check binds real committed inputs and rejects tampered packages',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-signing-'));
 t.after(async()=>{if(path.dirname(root)!==path.resolve(os.tmpdir())||!path.basename(root).startsWith('autowiki-signing-'))throw new Error('Unsafe fixture cleanup');await fs.rm(root,{recursive:true,force:true});});
 const repository=path.join(root,'source');await fs.mkdir(path.join(repository,'config'),{recursive:true});await fs.mkdir(path.join(repository,'code/modules/autowiki'),{recursive:true});
 await fs.writeFile(path.join(repository,'dependencies.sh'),'export BYOND_MAJOR=516\nexport BYOND_MINOR=1687\n');
 await fs.writeFile(path.join(repository,'config/game_options.txt'),'default\n');await fs.writeFile(path.join(repository,'code/modules/autowiki/structured.dm'),'// fixture\n');
 const git=args=>execFileSync('git',['-C',repository,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgSign=false',...args],{stdio:['ignore','pipe','pipe']}).toString().trim();
 git(['init']);git(['config','core.autocrlf','false']);git(['add','.']);git(['commit','-m','fixture']);const commit=git(['rev-parse','HEAD']);
 const source=signingSource(repository,commit);
 // Local changes must never substitute for the trusted Git blobs.
 await fs.writeFile(path.join(repository,'config/game_options.txt'),'local change\n');assert.deepEqual(signingSource(repository,commit),source);
 const records=Object.entries(contract.fields).map(([kind,fields])=>({kind,id:'/datum/'+kind+'/fixture',fields:Object.fromEntries(Object.entries(fields).filter(([field])=>kind!=='entity'||!contract.optionalEntity.includes(field)).map(([field,types])=>[field,types.includes('array')?[]:types.includes('number')?0:types.includes('string')?'example':null]))}));
 const entity=records.find(r=>r.kind==='entity');entity.fields.icon_file=null;
 const header={kind:'header',schema_version:2,profile:'source-defaults',time_unit:'decisecond',appearance_profile:'initial-south-first-frame',compiler:source.byond,runtime:source.byond};
 const trailer={kind:'complete',counts:Object.fromEntries(records.map(r=>[r.kind,1]))};
 const input=path.join(root,'data.jsonl'),icons=path.join(root,'icons'),output=path.join(root,'package');await fs.mkdir(icons);await fs.writeFile(input,[header,...records,trailer].map(r=>JSON.stringify(r)).join('\n'));
 const provenance={commit,dirty:false,configurationInputs:source.configurationInputs,exporterSha256:source.exporterSha256,workingDiffSha256:createHash('sha256').update('').digest('hex'),untracked:[],build:signingBuild,compiler:{sha256:'a'.repeat(64)}};
 await packageExport(input,icons,output,commit,undefined,provenance);
 const result=await checkSigningInput(output,repository,commit);assert.equal(result.records,17);assert.equal(result.tree,source.tree);
 const manifest=JSON.parse(await fs.readFile(path.join(output,'manifest.json'),'utf8'));
 for(const change of [m=>m.source.commit='b'.repeat(40),m=>m.provenance.configurationInputs=[],m=>m.provenance.exporterSha256='b'.repeat(64),m=>m.provenance.build.defines.push('EXTRA'),m=>m.provenance.dirty=true,m=>m.execution.runtime='516.1',m=>delete m.provenance.compiler]){
  const changed=structuredClone(manifest);change(changed);assert.throws(()=>validateSigningIdentity(changed,source));
 }
 await assert.rejects(checkSigningInput(output,repository,'b'.repeat(40)),/checkout differs/);
 await fs.writeFile(path.join(output,'run-me.js'),'throw new Error("must never execute");');await assert.rejects(checkSigningInput(output,repository,commit),/Unexpected files/);await fs.unlink(path.join(output,'run-me.js'));
 await fs.appendFile(path.join(output,'job.jsonl'),'tamper');await assert.rejects(checkSigningInput(output,repository,commit),/size|checksum/);
});
