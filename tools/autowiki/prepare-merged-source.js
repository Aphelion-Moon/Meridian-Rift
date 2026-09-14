import fs from 'node:fs/promises';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {sourcePlan,planDigest} from './source-binding.js';
import {signingSource} from './check-signing-input.js';

/** Fetch pinned objects into a new isolated repository. Never execute source scripts. */
export async function prepareMergedSource(input,directory,repository='https://github.com/Aphelion-Moon/Meridian-Rift.git') {
 const plan=sourcePlan(input);
 if(!path.isAbsolute(directory))throw new Error('Merged source directory must be absolute');
 if(repository!=='https://github.com/Aphelion-Moon/Meridian-Rift.git'&&!path.isAbsolute(repository))throw new Error('Unexpected source repository');
 await fs.mkdir(directory,{recursive:false});const empty=path.join(directory,'empty'),source=path.join(directory,'source');await fs.mkdir(empty);await fs.writeFile(path.join(empty,'config'),'');
 const env={...process.env};for(const key of Object.keys(env))if(key.startsWith('GIT_'))delete env[key];
 Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:path.join(empty,'config'),GIT_TERMINAL_PROMPT:'0',GIT_AUTHOR_NAME:'Autowiki verification',GIT_AUTHOR_EMAIL:'autowiki@example.invalid',GIT_COMMITTER_NAME:'Autowiki verification',GIT_COMMITTER_EMAIL:'autowiki@example.invalid',GIT_AUTHOR_DATE:'2000-01-01T00:00:00Z',GIT_COMMITTER_DATE:'2000-01-01T00:00:00Z'});
 const git=(args,cwd=source)=>execFileSync('git',['-c','core.hooksPath='+empty,'-c','init.templateDir='+empty,'-c','core.fsmonitor=false','-c','core.autocrlf=false',...args],{cwd,env,stdio:['ignore','pipe','pipe'],encoding:'utf8',timeout:180000,maxBuffer:16*1024*1024}).trim();
 try{
  git(['init',source],directory);
  // No shallow history: Git needs the real merge bases. Missing pinned objects fail.
  for(const value of new Set([plan.originCommit,...plan.merges.map(m=>m.commit)]))git(['fetch','--no-tags','--no-recurse-submodules','--',repository,value]);
  let current=plan.originCommit;const steps=[];
  for(const merge of plan.merges){const tree=git(['merge-tree','--write-tree','--no-messages',current,merge.commit]);if(!/^[a-f0-9]{40}$/.test(tree))throw new Error('Pinned merge did not yield one tree');current=git(['-c','commit.gpgSign=false','commit-tree',tree,'-p',current,'-p',merge.commit,'-m','Synthetic source verification']);steps.push({...merge,tree});}
  const tree=git(['rev-parse',current+'^{tree}']);if(tree!==plan.sourceTree)throw new Error('Reconstructed source does not match the requested tree');
  git(['checkout','--detach',current]);
  const result={version:1,plan,planDigest:planDigest(plan),sourceTree:tree,generatedCommit:current,byond:signingSource(source,current).byond,steps};
  await fs.writeFile(path.join(directory,'source.json'),JSON.stringify(result,null,2)+'\n');return result;
 }catch(error){throw new Error(error.status!==undefined?'Could not fetch or reconstruct conflict-free pinned source objects.':error.message);}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 try{const [file,directory]=process.argv.slice(2);const stat=await fs.stat(file);if(stat.size>65536)throw new Error('Source plan exceeds size limit');const result=await prepareMergedSource(JSON.parse(await fs.readFile(file,'utf8')),path.resolve(directory));if(process.env.GITHUB_OUTPUT){const [major,minor]=result.byond.split('.');await fs.appendFile(process.env.GITHUB_OUTPUT,`plan-digest=${result.planDigest}\nbyond-major=${major}\nbyond-minor=${minor}\n`);}console.log(JSON.stringify(result));}
 catch(error){console.error(error.code?'Source preparation failed; check input paths.':error.message);process.exitCode=1;}
}
