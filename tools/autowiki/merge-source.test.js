import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {reproduceSource} from './merge-source.js';

test('isolated merge reconstruction matches source content without changing repository refs or files',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'autowiki-merge-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const repository=path.join(root,'repo');await fs.mkdir(repository);
 const git=args=>execFileSync('git',['-C',repository,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgSign=false',...args],{stdio:['ignore','pipe','pipe']}).toString().trim();
 git(['init']);git(['config','core.autocrlf','false']);await fs.writeFile(path.join(repository,'base.txt'),'base\n');git(['add','.']);git(['commit','-m','base']);const origin=git(['rev-parse','HEAD']);
 git(['checkout','-b','first']);await fs.writeFile(path.join(repository,'one.txt'),'one\n');git(['add','.']);git(['commit','-m','one']);const first=git(['rev-parse','HEAD']);
 git(['checkout','-b','second',origin]);await fs.writeFile(path.join(repository,'two.txt'),'two\n');git(['add','.']);git(['commit','-m','two']);const second=git(['rev-parse','HEAD']);
 git(['checkout','-b','combined',origin]);git(['merge','--no-ff','--no-edit',first]);git(['merge','--no-ff','--no-edit',second]);const commit=git(['rev-parse','HEAD']),tree=git(['rev-parse','HEAD^{tree}']);
 await fs.writeFile(path.join(repository,'local-only.txt'),'Uncommitted local file must not affect reconstruction.');
 const refs=git(['show-ref']),status=git(['status','--porcelain']);
 const deployment={id:'fixture',commit,sourceTree:tree,originCommit:origin,testMerges:2,mergeIdentities:[{number:1,commit:first},{number:2,commit:second}]};
 const result=await reproduceSource(deployment,repository,path.join(root,'verified'));assert.equal(result.matches,true);assert.equal(result.publicationReady,false);assert.equal(result.steps.length,2);
 assert.equal(git(['show-ref']),refs);assert.equal(git(['status','--porcelain']),status);
 const wrong=await reproduceSource({...deployment,mergeIdentities:deployment.mergeIdentities.slice(0,1),testMerges:1},repository,path.join(root,'mismatch'));assert.equal(wrong.matches,false);
 await assert.rejects(reproduceSource({...deployment,sourceTree:'f'.repeat(40)},repository,path.join(root,'false-observation')),/differs from observation/);
 await assert.rejects(reproduceSource({...deployment,mergeIdentities:[{number:1,commit:'main'}],testMerges:1},repository,path.join(root,'unsafe')),/Invalid pinned merge/);
});
